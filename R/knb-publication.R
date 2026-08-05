# KNB/DataONE publication ---------------------------------------------------
#
# The local planner is intentionally independent of DataONE credentials and
# client packages. It creates the exact immutable-object plan, deterministic
# OAI-ORE resource map, and recovery manifest before any network boundary is
# constructed.

.ms_knb_environment <- "PROD"
.ms_knb_node_id <- "urn:node:KNB"
.ms_knb_mn_endpoint <- "https://knb.ecoinformatics.org/knb/d1/mn/v2"
.ms_knb_ore_format_id <- "http://www.openarchives.org/ore/terms"
.ms_knb_ore_media_type <- "application/rdf+xml"
.ms_knb_resolver <- "https://cn.dataone.org/cn/v2/resolve/"
.ms_knb_ore_profile <- "metasalmon-dataone-ore-v2"

.ms_knb_replication_policy <- function(public) {
  .ms_knb_validate_flag(public, "public")

  # Private review is deliberately KNB-only. Public deposits retain DataONE's
  # current three-replica preservation policy, but it is made explicit and is
  # therefore part of the exact reviewed plan instead of an unreviewed client
  # default.
  list(
    replication_allowed = isTRUE(public),
    number_replicas = if (isTRUE(public)) 3L else 0L,
    preferred_member_nodes = list(),
    blocked_member_nodes = list()
  )
}

.ms_knb_require_replication_policy <- function(policy, public) {
  expected <- .ms_knb_replication_policy(public)
  if (!identical(policy, expected)) {
    cli::cli_abort(
      "The publication plan has an invalid replication policy for the selected {.arg public} value."
    )
  }

  invisible(expected)
}

.ms_knb_validate_flag <- function(value, field, allow_null = FALSE) {
  if (isTRUE(allow_null) && is.null(value)) {
    return(invisible(NULL))
  }
  if (length(value) != 1L || !is.logical(value) || is.na(value)) {
    cli::cli_abort(
      "{.arg {field}} must be one explicit, non-missing logical value."
    )
  }
  invisible(value)
}

.ms_knb_lexical_absolute_path <- function(path) {
  path <- path.expand(as.character(path))
  if (length(path) != 1L || is.na(path) || !nzchar(path)) {
    cli::cli_abort("Publication paths must be non-empty scalar values.")
  }
  slash_path <- gsub("\\", "/", path, fixed = TRUE)
  is_absolute <- startsWith(slash_path, "/") ||
    grepl("^[A-Za-z]:/", slash_path)
  if (!is_absolute) {
    slash_path <- paste(
      gsub("\\", "/", getwd(), fixed = TRUE),
      slash_path,
      sep = "/"
    )
  }

  drive <- if (grepl("^[A-Za-z]:/", slash_path)) {
    substr(slash_path, 1L, 2L)
  } else {
    ""
  }
  without_root <- if (nzchar(drive)) {
    substring(slash_path, 4L)
  } else {
    sub("^/+", "", slash_path)
  }
  parts <- strsplit(without_root, "/", fixed = TRUE)[[1]]
  collapsed <- character()
  for (part in parts) {
    if (!nzchar(part) || identical(part, ".")) {
      next
    }
    if (identical(part, "..")) {
      if (length(collapsed) > 0L) {
        collapsed <- collapsed[-length(collapsed)]
      }
      next
    }
    collapsed <- c(collapsed, part)
  }
  prefix <- if (nzchar(drive)) paste0(drive, "/") else "/"
  paste0(prefix, paste(collapsed, collapse = "/"))
}

.ms_knb_package_root <- function(path) {
  lexical <- .ms_knb_lexical_absolute_path(path)
  if (!dir.exists(lexical)) {
    cli::cli_abort("SDP directory {.path {path}} does not exist.")
  }
  if (.ms_sdp_extension_is_symlink(lexical)) {
    cli::cli_abort("The SDP directory itself must not be a symbolic link.")
  }
  normalizePath(lexical, mustWork = TRUE)
}

.ms_knb_resolve_target_path <- function(path, must_work = TRUE) {
  lexical <- .ms_knb_lexical_absolute_path(path)
  if (isTRUE(must_work)) {
    if (!file.exists(lexical)) {
      cli::cli_abort(
        "Publication path {.path {path}} does not exist."
      )
    }
    return(normalizePath(lexical, mustWork = TRUE))
  }

  ancestor <- lexical
  suffix <- character()
  while (!file.exists(ancestor)) {
    parent <- dirname(ancestor)
    if (identical(parent, ancestor)) {
      cli::cli_abort(
        "Could not resolve an existing ancestor for publication path {.path {path}}."
      )
    }
    suffix <- c(basename(ancestor), suffix)
    ancestor <- parent
  }
  resolved <- normalizePath(ancestor, mustWork = TRUE)
  if (length(suffix) > 0L) {
    resolved <- do.call(file.path, as.list(c(resolved, suffix)))
  }
  resolved
}

.ms_knb_inside_path <- function(root, target, must_work = TRUE) {
  root <- normalizePath(root, mustWork = TRUE)
  lexical <- .ms_knb_lexical_absolute_path(target)
  # Recover the caller's lexical spelling of the package root before deriving
  # the package-relative name. This preserves declared names across harmless
  # platform aliases such as macOS /var -> /private/var without normalizing an
  # in-package artifact symlink to its target name.
  ancestor <- lexical
  lexical_root <- NULL
  repeat {
    if (file.exists(ancestor) && identical(
      normalizePath(ancestor, mustWork = TRUE),
      root
    )) {
      lexical_root <- ancestor
      break
    }
    parent <- dirname(ancestor)
    if (identical(parent, ancestor)) {
      break
    }
    ancestor <- parent
  }
  if (is.null(lexical_root)) {
    cli::cli_abort(
      "Publication artifact {.path {target}} must remain inside the SDP directory."
    )
  }
  lexical_prefix <- paste0(lexical_root, .Platform$file.sep)
  if (!startsWith(lexical, lexical_prefix)) {
    cli::cli_abort(
      "Publication artifact {.path {target}} must remain inside the SDP directory."
    )
  }
  relative <- substring(lexical, nchar(lexical_prefix) + 1L)
  candidate <- file.path(root, relative)
  parts <- strsplit(
    gsub("\\", "/", relative, fixed = TRUE),
    "/",
    fixed = TRUE
  )[[1]]
  candidates <- file.path(
    root,
    vapply(
      seq_along(parts),
      function(index) paste(parts[seq_len(index)], collapse = "/"),
      character(1)
    )
  )
  links <- Sys.readlink(candidates)
  link_present <- !is.na(links) & nzchar(links)
  existing_candidates <- candidates[file.exists(candidates) | link_present]
  existing_links <- Sys.readlink(existing_candidates)
  symlinks <- existing_candidates[
    !is.na(existing_links) & nzchar(existing_links)
  ]
  if (length(symlinks) > 0L) {
    cli::cli_abort(
      "Publication artifacts cannot be reached through a symlink: {.file {symlinks}}."
    )
  }
  resolved <- .ms_knb_resolve_target_path(candidate, must_work = must_work)
  prefix <- paste0(root, .Platform$file.sep)
  if (!startsWith(resolved, prefix)) {
    cli::cli_abort(
      "Publication artifact {.path {target}} must remain inside the SDP directory."
    )
  }
  candidate
}

.ms_knb_relative_path <- function(root, target, must_work = TRUE) {
  root <- normalizePath(root, mustWork = TRUE)
  target <- .ms_knb_inside_path(root, target, must_work = must_work)
  prefix <- paste0(root, .Platform$file.sep)
  if (!startsWith(target, prefix)) {
    cli::cli_abort(
      "Publication object {.path {target}} resolves outside the SDP directory."
    )
  }
  gsub(
    "\\",
    "/",
    substring(target, nchar(prefix) + 1L),
    fixed = TRUE
  )
}

.ms_knb_reject_dot_segments <- function(path, field) {
  parts <- strsplit(
    gsub("\\", "/", as.character(path), fixed = TRUE),
    "/",
    fixed = TRUE
  )[[1]]
  if (any(parts %in% c(".", ".."))) {
    cli::cli_abort(
      "Publication path {.val {path}} in {.field {field}} contains a forbidden dot path segment."
    )
  }
  invisible(path)
}

.ms_knb_declared_data_paths <- function(path) {
  tables_path <- .ms_locate_metadata_file(path, "tables.csv")
  if (is.na(tables_path)) {
    cli::cli_abort(
      "KNB publication requires canonical {.file metadata/tables.csv}."
    )
  }
  tables <- .ms_read_metadata_csv(tables_path)
  if (!"file_name" %in% names(tables) || nrow(tables) == 0L) {
    cli::cli_abort(
      "KNB publication requires non-empty {.field tables.csv$file_name} values."
    )
  }
  file_names <- as.character(tables$file_name)
  for (file_name in file_names) {
    .ms_knb_reject_dot_segments(file_name, "tables.csv$file_name")
  }
  paths <- vapply(
    file_names,
    function(file_name) .ms_eml_resource_path(path, file_name),
    character(1)
  )
  names(paths) <- paste0("data:", file_names)
  paths
}

.ms_knb_sdp_artifact_paths <- function(path) {
  required <- c(
    "datapackage.json",
    "metadata/dataset.csv",
    "metadata/tables.csv",
    "metadata/column_dictionary.csv",
    "metadata/codes.csv",
    "metadata/semantic_vocabulary.csv"
  )
  missing <- required[!file.exists(file.path(path, required))]
  if (length(missing) > 0L) {
    cli::cli_abort(
      "KNB publication requires canonical SDP artifact{?s}: {.file {missing}}."
    )
  }

  # The v0.2 extended layout keeps reviewed selections with the workflow,
  # provenance, and source records they qualify. Retain the root-level ledger
  # only as a compatibility path for already reviewed packages. A canonical
  # reproducibility tree is valid only when its exact contents are declared by
  # the checksum-bound manifest; publication never discovers extra files.
  reproducibility_manifest <- file.path(
    path,
    "reproducibility",
    "manifest.json"
  )
  mapping <- yaml::read_yaml(file.path(path, "metadata", "eml-mapping.yml"))
  mapped_review <- as.character(mapping$semantic_review$path %||% "")
  reproducibility_relative <- character()
  if (file.exists(reproducibility_manifest)) {
    validate_sdp_reproducibility_manifest(path)
    manifest <- read_sdp_reproducibility_manifest(path, validate = FALSE)
    declared_paths <- vapply(
      manifest$artifacts,
      function(artifact) as.character(artifact$path),
      character(1)
    )
    canonical_review <-
      "reproducibility/reviewed_semantic_selections.csv"
    if (!canonical_review %in% declared_paths) {
      cli::cli_abort(
        "KNB publication requires the canonical reviewed-selection ledger to be declared by {.file reproducibility/manifest.json}."
      )
    }
    if (!identical(mapped_review, canonical_review)) {
      cli::cli_abort(
        "EML mapping {.field semantic_review.path} must bind the reviewed ledger declared by the reproducibility manifest."
      )
    }
    reproducibility_relative <- c(
      "reproducibility/manifest.json",
      declared_paths
    )
  } else {
    legacy_review <- "reviewed_semantic_selections.csv"
    if (!file.exists(file.path(path, legacy_review))) {
      cli::cli_abort(c(
        "KNB publication requires a reviewed semantic-selection ledger.",
        "i" = "Use the extended {.file reproducibility/manifest.json} layout or the legacy root-level ledger."
      ))
    }
    if (!identical(mapped_review, legacy_review)) {
      cli::cli_abort(
        "Legacy KNB packages must bind the root-level reviewed ledger in EML mapping {.field semantic_review.path}."
      )
    }
    reproducibility_relative <- legacy_review
  }

  # SSSOM supplements are optional, but when present they are closed by the
  # metasalmon-generated manifest. Validate that manifest and include only the
  # files it names; never scan the semantic directory and accidentally publish
  # an editor backup, private review note, or unapproved mapping draft.
  semantic_manifest <- file.path(
    path,
    "metadata",
    "semantic",
    "mapping-sets.json"
  )
  semantic_relative <- character()
  if (file.exists(semantic_manifest)) {
    validate_sdp_sssom(path)
    manifest <- jsonlite::fromJSON(
      semantic_manifest,
      simplifyVector = FALSE
    )
    mapping_paths <- vapply(
      manifest$mapping_sets,
      function(mapping_set) as.character(mapping_set$path),
      character(1)
    )
    semantic_relative <- c(
      "metadata/semantic/mapping-sets.json",
      mapping_paths
    )
  }

  # Ordered measurement decompositions use their own closed manifest because
  # they are semantic components, not SSSOM term mappings. As with SSSOM,
  # validate the exact manifest binding and publish only the declared CSV plus
  # its manifest; unrelated files in metadata/semantic remain local.
  decomposition_manifest <- file.path(
    path,
    "metadata",
    "semantic",
    "measurement-decompositions.json"
  )
  decomposition_relative <- character()
  if (file.exists(decomposition_manifest)) {
    validate_sdp_measurement_decompositions(path)
    manifest <- jsonlite::fromJSON(
      decomposition_manifest,
      simplifyVector = FALSE
    )
    decomposition_relative <- c(
      "metadata/semantic/measurement-decompositions.json",
      as.character(manifest$artifact$path)
    )
  }

  # Methods and mixed-grain observation structures are optional SDP v0.2
  # metadata. When present they are validated as one complete contract and
  # become named objects in the expanded representation.
  methods_relative <- character()
  if (file.exists(file.path(path, "metadata", "methods.csv"))) {
    validate_sdp_methods(path)
    methods_relative <- "metadata/methods.csv"
  }
  structure_files <- c(
    "metadata/structure/observation_structures.csv",
    "metadata/structure/observation_components.csv"
  )
  structure_present <- file.exists(file.path(path, structure_files))
  structure_relative <- character()
  if (any(structure_present)) {
    if (!all(structure_present)) {
      cli::cli_abort(
        "KNB publication requires both canonical observation-structure files when either is present."
      )
    }
    validate_sdp_observation_structures(path)
    structure_relative <- structure_files
  }

  relative <- sort(c(
    required,
    reproducibility_relative,
    semantic_relative,
    decomposition_relative,
    methods_relative,
    structure_relative
  ))
  paths <- vapply(
    relative,
    function(item) .ms_knb_inside_path(
      path,
      file.path(path, item),
      must_work = TRUE
    ),
    character(1)
  )
  names(paths) <- paste0("sdp_artifact:", relative)
  paths
}

.ms_knb_publication_paths <- function(path, eml_path, manifest_path) {
  .ms_knb_reject_dot_segments(eml_path, "eml_path")
  .ms_knb_reject_dot_segments(manifest_path, "manifest_path")
  eml_path <- .ms_knb_inside_path(
    path,
    eml_path,
    must_work = file.exists(eml_path)
  )
  manifest_path <- .ms_knb_inside_path(
    path,
    manifest_path,
    must_work = file.exists(manifest_path)
  )
  resource_map_path <- .ms_knb_inside_path(
    path,
    file.path(dirname(manifest_path), "resource-map.rdf"),
    must_work = file.exists(
      file.path(dirname(manifest_path), "resource-map.rdf")
    )
  )
  archive_candidate <- file.path(
    path,
    "publication",
    .ms_knb_sdp_archive_filename(
      .ms_knb_sdp_archive_dataset_id(path)
    )
  )
  archive_path <- .ms_knb_inside_path(
    path,
    archive_candidate,
    must_work = file.exists(archive_candidate)
  )
  data_paths <- .ms_knb_declared_data_paths(path)
  all_paths <- c(
    data_paths,
    eml = eml_path,
    manifest = manifest_path,
    resource_map = resource_map_path,
    archive = archive_path
  )
  duplicated_paths <- unique(all_paths[
    duplicated(all_paths) | duplicated(all_paths, fromLast = TRUE)
  ])
  if (length(duplicated_paths) > 0L) {
    colliding_labels <- names(all_paths)[all_paths %in% duplicated_paths]
    cli::cli_abort(
      "KNB publication path collision among {.field {colliding_labels}}."
    )
  }
  list(
    eml_path = eml_path,
    manifest_path = manifest_path,
    resource_map_path = resource_map_path,
    archive_path = archive_path,
    data_paths = unname(data_paths)
  )
}

.ms_knb_object_bytes <- function(path) {
  readBin(path, what = "raw", n = file.info(path)$size)
}

.ms_knb_sha256_raw <- function(bytes) {
  digest::digest(bytes, algo = "sha256", serialize = FALSE)
}

.ms_knb_sha256_text <- function(value) {
  digest::digest(
    charToRaw(enc2utf8(as.character(value))),
    algo = "sha256",
    serialize = FALSE
  )
}

.ms_knb_resolve_url <- function(pid) {
  paste0(.ms_knb_resolver, utils::URLencode(pid, reserved = TRUE))
}

.ms_knb_resource_map_pid <- function(package_id,
                                     publication_date,
                                     member_objects) {
  member_lines <- vapply(member_objects, function(object) {
    paste(
      object$role,
      object$path,
      object$pid,
      object$format_id,
      object$size,
      object$sha256,
      sep = "\t"
    )
  }, character(1))
  preimage <- paste(
    c(
      .ms_knb_ore_profile,
      package_id,
      publication_date,
      sort(member_lines)
    ),
    collapse = "\n"
  )
  paste0(
    "urn:uuid:",
    .ms_eml_uuid5(paste("resource-map", preimage, sep = ":"))
  )
}

.ms_knb_add_resource <- function(parent, name, resource) {
  node <- xml2::xml_add_child(parent, name)
  xml2::xml_set_attr(node, "rdf:resource", resource)
  invisible(node)
}

.ms_knb_add_identifier <- function(parent, identifier) {
  node <- .ms_eml_add_text(parent, "dcterms:identifier", identifier)
  xml2::xml_set_attr(
    node,
    "rdf:datatype",
    "http://www.w3.org/2001/XMLSchema#string"
  )
  invisible(node)
}

.ms_knb_build_ore <- function(resource_map_pid,
                              package_id,
                              publication_date,
                              member_objects) {
  root <- xml2::read_xml(paste0(
    '<rdf:RDF ',
    'xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" ',
    'xmlns:ore="http://www.openarchives.org/ore/terms/" ',
    'xmlns:cito="http://purl.org/spar/cito/" ',
    'xmlns:prov="http://www.w3.org/ns/prov#" ',
    'xmlns:dcterms="http://purl.org/dc/terms/" ',
    'xmlns:xsd="http://www.w3.org/2001/XMLSchema#"/>'
  ))
  root <- xml2::xml_root(root)
  resource_map_url <- .ms_knb_resolve_url(resource_map_pid)
  aggregation_pid <- paste0(resource_map_pid, "#aggregation")
  aggregation_url <- paste0(resource_map_url, "#aggregation")
  metadata_url <- .ms_knb_resolve_url(package_id)

  resource_map <- xml2::xml_add_child(root, "rdf:Description")
  xml2::xml_set_attr(resource_map, "rdf:about", resource_map_url)
  .ms_knb_add_identifier(resource_map, resource_map_pid)
  .ms_knb_add_resource(
    resource_map,
    "rdf:type",
    "http://www.openarchives.org/ore/terms/ResourceMap"
  )
  .ms_knb_add_resource(resource_map, "ore:describes", aggregation_url)
  .ms_knb_add_resource(
    resource_map,
    "dcterms:creator",
    "https://github.com/salmon-data-mobilization/metasalmon"
  )
  .ms_eml_add_text(
    resource_map,
    "dcterms:modified",
    publication_date
  )

  aggregation <- xml2::xml_add_child(root, "rdf:Description")
  xml2::xml_set_attr(aggregation, "rdf:about", aggregation_url)
  .ms_knb_add_identifier(aggregation, aggregation_pid)
  .ms_knb_add_resource(
    aggregation,
    "rdf:type",
    "http://www.openarchives.org/ore/terms/Aggregation"
  )
  .ms_knb_add_resource(
    aggregation,
    "ore:isDescribedBy",
    resource_map_url
  )
  role_order <- c(
    "metadata",
    "data",
    "sdp_archive",
    # Retain the legacy expanded representation as a readable plan shape.
    # New plans use one named archive; old manifests can still be audited.
    "sdp_artifact"
  )
  ordered_members <- member_objects[order(match(
    vapply(member_objects, function(x) x$role, character(1)),
    role_order
  ))]
  for (object in ordered_members) {
    .ms_knb_add_resource(
      aggregation,
      "ore:aggregates",
      .ms_knb_resolve_url(object$pid)
    )
  }

  metadata <- xml2::xml_add_child(root, "rdf:Description")
  xml2::xml_set_attr(metadata, "rdf:about", metadata_url)
  .ms_knb_add_identifier(metadata, package_id)
  .ms_knb_add_resource(
    metadata,
    "ore:isAggregatedBy",
    aggregation_url
  )
  .ms_eml_add_text(metadata, "prov:atLocation", member_objects[[which(
    vapply(
      member_objects,
      function(object) identical(object$role, "metadata"),
      logical(1)
    )
  )]]$path)

  documented_objects <- member_objects[vapply(
    member_objects,
    function(x) x$role %in% c("data", "sdp_archive", "sdp_artifact"),
    logical(1)
  )]
  for (object in documented_objects) {
    object_url <- .ms_knb_resolve_url(object$pid)
    .ms_knb_add_resource(metadata, "cito:documents", object_url)
    object_description <- xml2::xml_add_child(root, "rdf:Description")
    xml2::xml_set_attr(object_description, "rdf:about", object_url)
    .ms_knb_add_resource(
      object_description,
      "cito:isDocumentedBy",
      metadata_url
    )
    .ms_knb_add_identifier(object_description, object$pid)
    .ms_knb_add_resource(
      object_description,
      "ore:isAggregatedBy",
      aggregation_url
    )
    .ms_eml_add_text(
      object_description,
      "prov:atLocation",
      object$path
    )
  }
  root
}

.ms_knb_xml_bytes <- function(document, output_dir) {
  temporary <- tempfile(
    pattern = ".metasalmon-ore-render-",
    tmpdir = output_dir,
    fileext = ".rdf"
  )
  on.exit(unlink(temporary), add = TRUE)
  xml2::write_xml(
    document,
    temporary,
    options = "format",
    encoding = "UTF-8"
  )
  .ms_knb_object_bytes(temporary)
}

.ms_knb_validate_ore <- function(document,
                                 resource_map_pid,
                                 member_objects) {
  aggregates <- xml2::xml_attr(
    xml2::xml_find_all(document, "//*[local-name()='aggregates']"),
    "resource"
  )
  expected <- vapply(
    member_objects,
    function(x) .ms_knb_resolve_url(x$pid),
    character(1)
  )
  if (!setequal(aggregates, expected) ||
      anyDuplicated(aggregates) ||
      length(aggregates) != length(expected)) {
    cli::cli_abort(
      "Generated OAI-ORE aggregate set does not exactly match the planned EML/data objects."
    )
  }

  resource_map_url <- .ms_knb_resolve_url(resource_map_pid)
  aggregation_url <- paste0(resource_map_url, "#aggregation")
  descriptions <- xml2::xml_find_all(
    document,
    "//*[local-name()='Description']"
  )
  about <- xml2::xml_attr(descriptions, "about")
  expected_identifiers <- c(
    stats::setNames(resource_map_pid, resource_map_url),
    stats::setNames(
      paste0(resource_map_pid, "#aggregation"),
      aggregation_url
    ),
    stats::setNames(
      vapply(member_objects, function(x) x$pid, character(1)),
      expected
    )
  )
  for (url in names(expected_identifiers)) {
    matches <- descriptions[about == url]
    identifiers <- xml2::xml_text(xml2::xml_find_all(
      matches,
      "./*[local-name()='identifier']"
    ))
    if (length(matches) != 1L ||
        length(identifiers) != 1L ||
        !identical(identifiers[[1]], expected_identifiers[[url]])) {
      cli::cli_abort(
        "Generated OAI-ORE lacks the exact DataONE identifier for represented resource {.url {url}}."
      )
    }
  }

  described_by <- xml2::xml_attr(
    xml2::xml_find_all(
      document,
      "//*[@rdf:about][*[local-name()='type' and @rdf:resource='http://www.openarchives.org/ore/terms/Aggregation']]/*[local-name()='isDescribedBy']",
      ns = c(rdf = "http://www.w3.org/1999/02/22-rdf-syntax-ns#")
    ),
    "resource"
  )
  if (!identical(described_by, resource_map_url)) {
    cli::cli_abort(
      "Generated OAI-ORE aggregation must be described by its resource map."
    )
  }

  documented_objects <- member_objects[vapply(
    member_objects,
    function(x) x$role %in% c("data", "sdp_archive", "sdp_artifact"),
    logical(1)
  )]
  documented_urls <- vapply(
    documented_objects,
    function(x) .ms_knb_resolve_url(x$pid),
    character(1)
  )
  metadata_object <- member_objects[vapply(
    member_objects,
    function(x) identical(x$role, "metadata"),
    logical(1)
  )][[1]]
  metadata_url <- .ms_knb_resolve_url(metadata_object$pid)
  documents <- xml2::xml_attr(
    xml2::xml_find_all(
      document,
      "//*[local-name()='documents']"
    ),
    "resource"
  )
  documented_by <- xml2::xml_attr(
    xml2::xml_find_all(
      document,
      "//*[local-name()='isDocumentedBy']"
    ),
    "resource"
  )
  aggregated_by <- xml2::xml_attr(
    xml2::xml_find_all(
      document,
      "//*[local-name()='isAggregatedBy']"
    ),
    "resource"
  )
  locations <- xml2::xml_text(xml2::xml_find_all(
    document,
    "//*[local-name()='atLocation']"
  ))
  expected_locations <- vapply(
    member_objects,
    function(object) object$path,
    character(1)
  )
  if (!setequal(documents, documented_urls) ||
      length(documents) != length(documented_urls) ||
      length(documented_by) != length(documented_urls) ||
      !all(documented_by == metadata_url) ||
      length(aggregated_by) != length(expected) ||
      !all(aggregated_by == aggregation_url) ||
      !setequal(locations, expected_locations) ||
      length(locations) != length(expected_locations) ||
      anyDuplicated(locations)) {
    cli::cli_abort(
      "Generated OAI-ORE package relationships do not match the publication profile."
    )
  }

  xml <- as.character(document)
  if (grepl("file:", xml, fixed = TRUE) ||
      grepl("REVIEW:", xml, fixed = TRUE) ||
      !grepl(
        utils::URLencode(resource_map_pid, reserved = TRUE),
        xml,
        fixed = TRUE
      )) {
    cli::cli_abort(
      "Generated OAI-ORE contains a local/review marker or does not identify its resource map."
    )
  }
  invisible(TRUE)
}

.ms_knb_atomic_write_raw <- function(bytes, path) {
  directory <- dirname(path)
  if (!dir.exists(directory)) {
    dir.create(directory, recursive = TRUE, showWarnings = FALSE)
  }
  if (!dir.exists(directory)) {
    cli::cli_abort(
      "Could not create publication artifact directory {.path {directory}}."
    )
  }
  temporary <- tempfile(
    pattern = ".metasalmon-write-",
    tmpdir = directory
  )
  on.exit(unlink(temporary), add = TRUE)
  writeBin(bytes, temporary)

  if (file.exists(path) &&
      identical(.ms_knb_object_bytes(path), bytes)) {
    unlink(temporary)
    return(invisible(path))
  }
  if (!file.rename(temporary, path)) {
    cli::cli_abort(
      "Could not atomically replace publication artifact {.path {path}}."
    )
  }
  invisible(path)
}

.ms_knb_json_bytes <- function(value) {
  json <- jsonlite::toJSON(
    value,
    auto_unbox = TRUE,
    null = "null",
    na = "null",
    pretty = TRUE
  )
  charToRaw(paste0(json, "\n"))
}

.ms_knb_fingerprint_object <- function(object) {
  scalar <- function(field) {
    value <- unlist(object[[field]], use.names = FALSE)
    if (length(value) == 0L) {
      return(NA_character_)
    }
    as.character(value[[1]])
  }

  size <- unlist(object$size, use.names = FALSE)
  if (length(size) == 0L) {
    size <- NA_real_
  } else {
    size <- as.numeric(size[[1]])
  }

  # jsonlite represents a column containing only JSON null values as a
  # zero-column data frame when a user reads and rewrites a manifest. Reduce
  # every fingerprint field to its wire-level scalar so harmless JSON
  # round-trips cannot invalidate an otherwise exact reviewed plan.
  list(
    role = scalar("role"),
    path = scalar("path"),
    pid = scalar("pid"),
    format_id = scalar("format_id"),
    media_type = scalar("media_type"),
    size = size,
    sha256 = scalar("sha256"),
    obsoletes = .ms_knb_optional_scalar(object$obsoletes)
  )
}

.ms_knb_plan_fingerprint <- function(plan) {
  fingerprint <- list(
    schema_version = 3L,
    environment = plan$environment,
    node_id = plan$node_id,
    public = plan$public,
    replication_policy = plan$replication_policy,
    expected_subject = plan$expected_subject,
    rights_authorization = plan$rights_authorization,
    package_id = plan$package_id,
    series_id = plan$series_id,
    representation = plan$representation,
    revision_of = if (
      is.null(plan$revision_of) || length(plan$revision_of) == 0L
    ) {
      NULL
    } else {
      plan$revision_of
    },
    ore_profile = .ms_knb_ore_profile,
    objects = lapply(plan$objects, .ms_knb_fingerprint_object)
  )
  .ms_knb_sha256_raw(.ms_knb_json_bytes(fingerprint))
}

.ms_knb_status_rank <- function(status) {
  ranks <- c(
    dry_run = 1L,
    pending = 2L,
    published_pending_catalog = 3L,
    complete = 4L
  )
  value <- unname(ranks[as.character(status)])
  if (length(value) != 1L || is.na(value)) 0L else value
}

.ms_knb_advance_status <- function(current, candidate) {
  if (.ms_knb_status_rank(current) >= .ms_knb_status_rank(candidate)) {
    current
  } else {
    candidate
  }
}

.ms_knb_manifest <- function(plan, status = "dry_run", previous = NULL) {
  objects <- unname(lapply(plan$objects, function(object) {
    state <- "planned"
    if (!is.null(previous) &&
        !is.null(previous$objects) &&
        length(previous$objects) > 0L) {
      previous_objects <- previous$objects
      if (is.data.frame(previous_objects)) {
        index <- match(object$pid, previous_objects$pid)
        if (!is.na(index)) {
          state <- previous_objects$state[[index]]
        }
      } else {
        previous_pids <- vapply(
          previous_objects,
          function(x) x$pid,
          character(1)
        )
        index <- match(object$pid, previous_pids)
        if (!is.na(index)) {
          state <- previous_objects[[index]]$state
        }
      }
    }
    c(
      object[c(
        "role", "path", "pid", "format_id", "media_type",
        "size", "sha256", "obsoletes"
      )],
      list(state = state)
    )
  }))
  previous_status <- if (is.null(previous)) {
    NA_character_
  } else {
    as.character(previous$status)
  }
  durable_status <- if (
    .ms_knb_status_rank(previous_status) >
      .ms_knb_status_rank(status)
  ) {
    previous_status
  } else {
    status
  }
  previous_catalog_verified <- !is.null(previous) &&
    isTRUE(previous$catalog_verified)
  previous_catalog_evidence <- if (
    is.null(previous) ||
      is.null(previous$catalog_evidence)
  ) {
    list()
  } else {
    previous$catalog_evidence
  }
  list(
    schema_version = 3L,
    status = durable_status,
    environment = plan$environment,
    node_id = plan$node_id,
    public = plan$public,
    replication_policy = plan$replication_policy,
    expected_subject = plan$expected_subject,
    rights_authorization = plan$rights_authorization,
    package_id = plan$package_id,
    series_id = plan$series_id,
    representation = plan$representation,
    revision_of = plan$revision_of,
    plan_sha256 = plan$plan_sha256,
    metadata_pid = plan$metadata_pid,
    resource_map_pid = plan$resource_map_pid,
    objects = objects,
    catalog_verified = previous_catalog_verified,
    catalog_evidence = previous_catalog_evidence
  )
}

.ms_knb_existing_manifest <- function(path) {
  if (!file.exists(path)) {
    return(NULL)
  }
  tryCatch(
    jsonlite::read_json(path, simplifyVector = TRUE),
    error = function(error) {
      cli::cli_abort(
        "Existing publication manifest {.path {path}} is not valid JSON: {conditionMessage(error)}"
      )
    }
  )
}

.ms_knb_manifest_objects <- function(manifest) {
  if (is.null(manifest) || is.null(manifest$objects)) {
    return(list())
  }
  if (is.data.frame(manifest$objects)) {
    return(lapply(seq_len(nrow(manifest$objects)), function(i) {
      as.list(manifest$objects[i, , drop = FALSE])
    }))
  }
  manifest$objects
}

.ms_knb_manifest_fingerprint <- function(manifest) {
  schema_version <- suppressWarnings(as.integer(manifest$schema_version))
  objects <- .ms_knb_manifest_objects(manifest)
  if (identical(schema_version, 2L)) {
    fingerprint <- list(
      schema_version = 2L,
      environment = manifest$environment,
      node_id = manifest$node_id,
      public = manifest$public,
      replication_policy = manifest$replication_policy,
      expected_subject = manifest$expected_subject,
      rights_authorization = manifest$rights_authorization,
      package_id = manifest$package_id,
      series_id = manifest$series_id,
      ore_profile = .ms_knb_ore_profile,
      objects = lapply(objects, function(object) {
        object[c(
          "role", "path", "pid", "format_id", "media_type",
          "size", "sha256"
        )]
      })
    )
    return(.ms_knb_sha256_raw(.ms_knb_json_bytes(fingerprint)))
  }
  if (identical(schema_version, 3L)) {
    candidate <- manifest
    candidate$objects <- objects
    return(.ms_knb_plan_fingerprint(candidate))
  }
  NA_character_
}

.ms_knb_revision_manifest <- function(path) {
  if (is.null(path)) {
    return(NULL)
  }
  .ms_knb_reject_dot_segments(path, "revision_manifest")
  if (!file.exists(path) || dir.exists(path)) {
    cli::cli_abort(
      "Prior KNB revision manifest {.path {path}} does not exist."
    )
  }
  manifest <- .ms_knb_existing_manifest(normalizePath(path, mustWork = TRUE))
  schema_version <- suppressWarnings(as.integer(manifest$schema_version))
  status <- as.character(manifest$status)
  objects <- .ms_knb_manifest_objects(manifest)
  roles <- vapply(objects, function(object) {
    as.character(object$role)
  }, character(1))
  states <- vapply(objects, function(object) {
    as.character(object$state)
  }, character(1))
  valid <- length(schema_version) == 1L &&
    !is.na(schema_version) &&
    schema_version %in% c(2L, 3L) &&
    length(status) == 1L &&
    status %in% c("published_pending_catalog", "complete") &&
    identical(as.character(manifest$environment), .ms_knb_environment) &&
    identical(as.character(manifest$node_id), .ms_knb_node_id) &&
    length(objects) > 0L &&
    sum(roles == "metadata") == 1L &&
    sum(roles == "resource_map") == 1L &&
    all(states == "verified") &&
    identical(
      .ms_knb_manifest_fingerprint(manifest),
      as.character(manifest$plan_sha256)
    )
  if (!isTRUE(valid)) {
    cli::cli_abort(
      paste(
        "A KNB revision requires a verified schema-version 2 or 3",
        "published manifest with an intact plan fingerprint."
      )
    )
  }
  manifest$objects <- objects
  manifest
}

.ms_knb_revision_context <- function(prior, plan) {
  if (is.null(prior)) {
    return(NULL)
  }
  if (!identical(isTRUE(prior$public), isTRUE(plan$public))) {
    cli::cli_abort(
      "KNB revision planning cannot also change public/private access."
    )
  }
  if (!identical(as.character(prior$series_id), plan$series_id)) {
    cli::cli_abort(
      "The prior KNB manifest belongs to a different metadata series."
    )
  }
  prior_metadata <- prior$objects[vapply(
    prior$objects,
    function(object) identical(as.character(object$role), "metadata"),
    logical(1)
  )][[1L]]
  prior_resource_map <- prior$objects[vapply(
    prior$objects,
    function(object) identical(
      as.character(object$role),
      "resource_map"
    ),
    logical(1)
  )][[1L]]
  list(
    schema_version = as.integer(prior$schema_version),
    plan_sha256 = as.character(prior$plan_sha256),
    metadata_pid = as.character(prior_metadata$pid),
    resource_map_pid = as.character(prior_resource_map$pid)
  )
}

.ms_knb_require_new_revision_pids <- function(revision,
                                              metadata_pid,
                                              resource_map_pid) {
  if (is.null(revision)) {
    return(invisible(TRUE))
  }

  reused <- c(
    metadata = identical(revision$metadata_pid, metadata_pid),
    `resource-map` = identical(
      revision$resource_map_pid,
      resource_map_pid
    )
  )
  reused_roles <- names(reused)[reused]
  if (length(reused_roles) == 0L) {
    return(invisible(TRUE))
  }

  role_text <- if (length(reused_roles) == 2L) {
    paste(reused_roles, collapse = " and ")
  } else {
    reused_roles[[1]]
  }
  cli::cli_abort(c(
    "KNB revision planning would reuse the prior {role_text} PID{?s}.",
    "i" = "Choose a new {.field publication.revision_key} so the revision mints new immutable metadata and resource-map PIDs."
  ))
}

.ms_knb_assert_resource_map_owned <- function(plan, previous) {
  if (!file.exists(plan$resource_map_path)) {
    return(invisible(TRUE))
  }
  previous_objects <- .ms_knb_manifest_objects(previous)
  resource_maps <- previous_objects[vapply(
    previous_objects,
    function(object) identical(
      as.character(object$role),
      "resource_map"
    ),
    logical(1)
  )]
  owned <- !is.null(previous) &&
    identical(as.character(previous$plan_sha256), plan$plan_sha256) &&
    length(resource_maps) == 1L &&
    identical(
      as.character(resource_maps[[1]]$path),
      .ms_knb_relative_path(plan$package_path, plan$resource_map_path)
    ) &&
    identical(
      as.character(resource_maps[[1]]$pid),
      plan$resource_map_pid
    ) &&
    identical(
      as.character(resource_maps[[1]]$sha256),
      .ms_knb_sha256_raw(.ms_knb_object_bytes(plan$resource_map_path))
    ) &&
    identical(
      .ms_knb_object_bytes(plan$resource_map_path),
      plan$resource_map_bytes
    )
  if (!isTRUE(owned)) {
    cli::cli_abort(
      "The pre-existing resource map file is not owned by the exact matching publication manifest."
    )
  }
  invisible(TRUE)
}

.ms_knb_require_reviewed_manifest <- function(previous, plan) {
  reviewed <- previous
  if (!is.null(reviewed)) {
    reviewed$objects <- .ms_knb_manifest_objects(reviewed)
  }
  reviewed_fingerprint <- tryCatch(
    .ms_knb_plan_fingerprint(reviewed),
    error = function(error) NA_character_
  )
  schema_version <- suppressWarnings(as.integer(previous$schema_version))
  status <- as.character(previous$status)
  valid <- !is.null(previous) &&
    length(schema_version) == 1L &&
    !is.na(schema_version) &&
    schema_version == 3L &&
    length(status) == 1L &&
    status %in% c(
      "dry_run",
      "pending",
      "published_pending_catalog",
      "complete"
    ) &&
    identical(previous$replication_policy, plan$replication_policy) &&
    identical(as.character(previous$plan_sha256), plan$plan_sha256) &&
    identical(reviewed_fingerprint, plan$plan_sha256)

  if (!isTRUE(valid)) {
    cli::cli_abort(
      paste(
        "Live KNB publication requires a reviewed schema version 3 manifest",
        "with the exact replication policy and recomputed plan fingerprint."
      )
    )
  }
  invisible(TRUE)
}

.ms_knb_require_rights_authorization <- function(plan) {
  if (!isTRUE(plan$public)) {
    return(invisible(TRUE))
  }
  authorization <- plan$rights_authorization
  status <- if (is.list(authorization)) {
    .ms_knb_optional_scalar(authorization$status)
  } else {
    NA_character_
  }
  evidence <- if (is.list(authorization)) {
    unlist(authorization$evidence, use.names = FALSE)
  } else {
    character()
  }
  evidence <- trimws(as.character(evidence))
  evidence <- evidence[!is.na(evidence) & nzchar(evidence)]
  if (!identical(status, "confirmed") || length(evidence) == 0L) {
    cli::cli_abort(c(
      "Public KNB publication requires confirmed redistribution rights in the reviewed EML sidecar.",
      "i" = "{.arg confirm = TRUE} approves the exact plan; it is not rights evidence."
    ))
  }
  invisible(TRUE)
}

.ms_knb_reject_review_candidate_annotations <- function(path) {
  vocabulary_path <- file.path(
    path,
    "metadata",
    "semantic_vocabulary.csv"
  )
  vocabulary <- readr::read_csv(
    vocabulary_path,
    col_types = readr::cols(.default = readr::col_character()),
    show_col_types = FALSE,
    progress = FALSE
  )
  required <- c("iri", "source", "ontology")
  if (!all(required %in% names(vocabulary))) {
    cli::cli_abort(
      "KNB publication requires semantic_vocabulary.csv fields: {.field {required}}."
    )
  }

  status_text <- tolower(paste(
    vocabulary$source,
    vocabulary$ontology
  ))
  candidate <- grepl(
    "(^|[^a-z])(candidate|review[ _-]?candidate)([^a-z]|$)",
    status_text,
    perl = TRUE
  )
  candidate_iris <- unique(trimws(as.character(vocabulary$iri[candidate])))
  candidate_iris <- candidate_iris[
    !is.na(candidate_iris) & nzchar(candidate_iris)
  ]
  if (length(candidate_iris) == 0L) {
    return(invisible(TRUE))
  }

  semantic_inputs <- c(
    file.path(path, "metadata", "dataset.csv"),
    file.path(path, "metadata", "tables.csv"),
    file.path(path, "metadata", "column_dictionary.csv"),
    file.path(path, "metadata", "codes.csv")
  )
  text <- paste(vapply(semantic_inputs, function(input) {
    paste(readLines(input, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  }, character(1)), collapse = "\n")
  referenced <- candidate_iris[vapply(
    candidate_iris,
    grepl,
    logical(1),
    x = text,
    fixed = TRUE
  )]
  if (length(referenced) > 0L) {
    cli::cli_abort(c(
      "KNB publication cannot emit annotations to review-candidate vocabulary IRIs: {.url {referenced}}.",
      "i" = "Publish those concepts in a governed provisional/stable vocabulary release, rebuild the SDP against that release, or remove the annotations."
    ))
  }
  invisible(TRUE)
}

.ms_knb_sdp_artifact_object <- function(local_path,
                                        path,
                                        dataset_id) {
  relative <- .ms_knb_relative_path(path, local_path)
  extension <- tolower(tools::file_ext(relative))
  format_id <- switch(
    extension,
    csv = "text/csv",
    json = "application/json",
    tsv = "text/tsv",
    yml = "text/plain",
    yaml = "text/plain",
    "application/octet-stream"
  )
  media_type <- switch(
    extension,
    csv = "text/csv",
    json = "application/json",
    tsv = "text/tab-separated-values",
    yml = "text/plain",
    yaml = "text/plain",
    "application/octet-stream"
  )
  bytes <- .ms_knb_object_bytes(local_path)
  sha256 <- .ms_knb_sha256_raw(bytes)
  list(
    role = "sdp_artifact",
    path = relative,
    local_path = local_path,
    pid = paste0(
      "urn:uuid:",
      .ms_eml_uuid5(paste(
        "sdp-artifact",
        dataset_id,
        relative,
        sha256,
        sep = ":"
      ))
    ),
    format_id = format_id,
    media_type = media_type,
    size = as.numeric(length(bytes)),
    sha256 = sha256,
    series_id = NA_character_
  )
}

.ms_knb_sdp_archive_object <- function(archive, path, dataset_id) {
  relative <- .ms_knb_relative_path(path, archive$path)
  list(
    role = "sdp_archive",
    path = relative,
    local_path = archive$path,
    pid = paste0(
      "urn:uuid:",
      .ms_eml_uuid5(paste(
        "sdp-archive",
        dataset_id,
        archive$sha256,
        sep = ":"
      ))
    ),
    format_id = archive$format_id,
    media_type = archive$media_type,
    size = as.numeric(archive$size),
    sha256 = archive$sha256,
    series_id = NA_character_,
    obsoletes = NA_character_,
    obsoleted_by = NA_character_
  )
}

.ms_knb_sdp_artifact_objects <- function(path, dataset_id) {
  artifact_paths <- unname(.ms_knb_sdp_artifact_paths(path))
  lapply(
    artifact_paths,
    function(local_path) {
      object <- .ms_knb_sdp_artifact_object(
        local_path,
        path,
        dataset_id
      )
      object$obsoletes <- NA_character_
      object$obsoleted_by <- NA_character_
      object
    }
  )
}

.ms_knb_supplementary_object_plan <- function(objects) {
  if (length(objects) == 0L) {
    return(NULL)
  }
  tibble::tibble(
    path = vapply(objects, function(object) object$local_path, character(1)),
    pid = vapply(objects, function(object) object$pid, character(1)),
    format_id = vapply(
      objects,
      function(object) object$format_id,
      character(1)
    ),
    checksum = vapply(objects, function(object) object$sha256, character(1)),
    object_name = vapply(
      objects,
      function(object) {
        if (identical(object$role, "sdp_archive")) {
          basename(object$path)
        } else {
          object$path
        }
      },
      character(1)
    ),
    entity_name = vapply(
      objects,
      function(object) {
        if (identical(object$role, "sdp_archive")) {
          "Canonical Salmon Data Package"
        } else {
          paste("Salmon Data Package artifact:", object$path)
        }
      },
      character(1)
    ),
    description = vapply(
      objects,
      function(object) {
        if (identical(object$role, "sdp_archive")) {
          paste(
            "A complete, validated Salmon Data Package containing the source data,",
            "canonical SDP metadata, reviewed semantic selections, SSSOM mapping",
            "sets, and measurement-decomposition artifacts."
          )
        } else {
          paste(
            "Canonical file from the expanded Salmon Data Package at",
            paste0("'", object$path, "'.")
          )
        }
      },
      character(1)
    ),
    size = vapply(objects, function(object) object$size, numeric(1)),
    entity_type = vapply(
      objects,
      function(object) {
        if (identical(object$role, "sdp_archive")) {
          "Salmon Data Package archive"
        } else {
          "Salmon Data Package artifact"
        }
      },
      character(1)
    )
  )
}

.ms_knb_build_plan <- function(path,
                               eml_path,
                               manifest_path,
                               public,
                               representation = c("archive", "expanded"),
                               prior_manifest = NULL,
                               resource_map_path = file.path(
                                 dirname(manifest_path),
                                 "resource-map.rdf"
                               )) {
  representation <- match.arg(representation)
  .ms_knb_reject_review_candidate_annotations(path)
  mapping <- yaml::read_yaml(
    file.path(path, "metadata", "eml-mapping.yml")
  )
  archive <- NULL
  package_objects <- if (identical(representation, "archive")) {
    archive <- .ms_knb_write_sdp_archive(path)
    list(.ms_knb_sdp_archive_object(
      archive,
      path,
      mapping$dataset_id
    ))
  } else {
    .ms_knb_sdp_artifact_objects(path, mapping$dataset_id)
  }
  supplementary_objects <- .ms_knb_supplementary_object_plan(
    package_objects
  )
  eml <- write_eml_from_sdp(
    path,
    output_path = eml_path,
    supplementary_objects = supplementary_objects,
    require_revision_key = !is.null(prior_manifest)
  )
  if (!identical(eml$public, public)) {
    cli::cli_abort(
      "Reviewed sidecar {.field publication.public} must exactly equal {.arg public}."
    )
  }
  eml_document <- xml2::read_xml(eml$path)
  metadata_provider_orcids <- unique(trimws(xml2::xml_text(
    xml2::xml_find_all(
      eml_document,
      "//*[local-name()='metadataProvider']/*[local-name()='userId' and @directory='https://orcid.org']"
    )
  )))
  metadata_provider_orcids <- metadata_provider_orcids[
    nzchar(metadata_provider_orcids)
  ]
  if (length(metadata_provider_orcids) != 1L ||
      is.na(.ms_knb_orcid_key(metadata_provider_orcids[[1]]))) {
    cli::cli_abort(
      "Live-publication EML must identify exactly one metadata-provider ORCID URI for authenticated-subject verification."
    )
  }
  expected_subject <- metadata_provider_orcids[[1]]

  data_objects <- lapply(
    order(eml$data_objects$file_name),
    function(i) {
      data <- eml$data_objects[i, , drop = FALSE]
      list(
        role = "data",
        path = .ms_knb_relative_path(
          path,
          as.character(data$path[[1]])
        ),
        local_path = as.character(data$path[[1]]),
        pid = as.character(data$pid[[1]]),
        format_id = as.character(data$format_id[[1]]),
        media_type = "text/csv",
        size = as.numeric(data$size[[1]]),
        sha256 = as.character(data$checksum[[1]]),
        series_id = NA_character_,
        obsoletes = NA_character_,
        obsoleted_by = NA_character_
      )
    }
  )

  revision_context <- .ms_knb_revision_context(
    prior_manifest,
    list(public = public, series_id = eml$series_id)
  )

  eml_bytes <- .ms_knb_object_bytes(eml$path)
  metadata_object <- list(
    role = "metadata",
    path = .ms_knb_relative_path(path, eml$path),
    local_path = eml$path,
    pid = eml$package_id,
    format_id = eml$format_id,
    media_type = "application/xml",
    size = as.numeric(length(eml_bytes)),
    sha256 = .ms_knb_sha256_raw(eml_bytes),
    series_id = eml$series_id,
    obsoletes = if (is.null(revision_context)) {
      NA_character_
    } else {
      revision_context$metadata_pid
    },
    obsoleted_by = NA_character_
  )
  members <- c(data_objects, package_objects, list(metadata_object))

  resource_map_pid <- .ms_knb_resource_map_pid(
    eml$package_id,
    mapping$publication_date,
    members
  )
  .ms_knb_require_new_revision_pids(
    revision_context,
    eml$package_id,
    resource_map_pid
  )
  ore <- .ms_knb_build_ore(
    resource_map_pid,
    eml$package_id,
    mapping$publication_date,
    members
  )
  .ms_knb_validate_ore(ore, resource_map_pid, members)

  resource_map_path <- .ms_knb_inside_path(
    path,
    resource_map_path,
    must_work = FALSE
  )
  ore_bytes <- .ms_knb_xml_bytes(ore, dirname(resource_map_path))
  resource_map_object <- list(
    role = "resource_map",
    path = .ms_knb_relative_path(
      path,
      file.path(
        normalizePath(dirname(resource_map_path), mustWork = TRUE),
        basename(resource_map_path)
      ),
      must_work = FALSE
    ),
    local_path = resource_map_path,
    pid = resource_map_pid,
    format_id = .ms_knb_ore_format_id,
    media_type = .ms_knb_ore_media_type,
    size = as.numeric(length(ore_bytes)),
    sha256 = .ms_knb_sha256_raw(ore_bytes),
    series_id = NA_character_,
    obsoletes = if (is.null(revision_context)) {
      NA_character_
    } else {
      revision_context$resource_map_pid
    },
    obsoleted_by = NA_character_
  )

  plan <- list(
    package_path = path,
    environment = .ms_knb_environment,
    node_id = .ms_knb_node_id,
    public = public,
    replication_policy = .ms_knb_replication_policy(public),
    expected_subject = expected_subject,
    rights_authorization = mapping$rights_authorization %||% list(
      status = "unconfirmed",
      evidence = list()
    ),
    package_id = eml$package_id,
    series_id = eml$series_id,
    representation = representation,
    revision_of = revision_context,
    prior_manifest = prior_manifest,
    metadata_pid = eml$package_id,
    resource_map_pid = resource_map_pid,
    objects = unname(c(
      data_objects,
      package_objects,
      list(metadata_object, resource_map_object)
    )),
    resource_map_document = ore,
    resource_map_bytes = ore_bytes,
    resource_map_path = resource_map_path,
    sdp_archive_path = if (is.null(archive)) NULL else archive$path,
    eml = eml
  )
  plan$plan_sha256 <- .ms_knb_plan_fingerprint(plan)
  plan
}

.ms_knb_adapter <- function() {
  adapter <- getOption("metasalmon.knb_adapter")
  if (is.null(adapter)) {
    return(.ms_knb_default_adapter())
  }
  if (is.function(adapter)) {
    adapter <- adapter()
  }
  if (!is.list(adapter)) {
    cli::cli_abort(
      "Private option {.code metasalmon.knb_adapter} must provide an adapter list or constructor."
    )
  }
  adapter
}

.ms_knb_required_adapter_methods <- function() {
  c(
    "connect",
    "preflight",
    "list_formats",
    "lookup_system_metadata",
    "lookup_series_id",
    "create_object",
    "update_object",
    "get_bytes",
    "get_system_metadata",
    "get_checksum",
    "get_anonymous_bytes",
    "get_anonymous_system_metadata",
    "catalog_lookup",
    "anonymous_catalog_lookup"
  )
}

.ms_knb_validate_adapter <- function(adapter) {
  required <- .ms_knb_required_adapter_methods()
  missing <- required[
    !vapply(required, function(name) {
      is.function(adapter[[name]])
    }, logical(1))
  ]
  if (length(missing) > 0L) {
    cli::cli_abort(
      "KNB adapter is missing method{?s}: {.field {missing}}."
    )
  }
  invisible(adapter)
}

.ms_knb_redact <- function(value) {
  value <- as.character(value)
  value <- gsub(
    "(?i)Bearer[[:space:]]+[A-Za-z0-9._~-]+",
    "Bearer [REDACTED]",
    value,
    perl = TRUE
  )
  value <- gsub(
    "eyJ[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+",
    "[REDACTED JWT]",
    value,
    perl = TRUE
  )
  value <- gsub(
    "(?i)(dataone_token|authorization|cookie)[=:][^[:space:]]+",
    "\\1=[REDACTED]",
    value,
    perl = TRUE
  )
  value
}

.ms_knb_abort_safe <- function(error) {
  safe <- .ms_knb_redact(conditionMessage(error))
  # `conditionMessage(error)` can contain braces supplied by an untrusted
  # remote service. Passing that text to cli as a template would evaluate the
  # brace expression after redaction. Abort with an ordinary, non-interpolating
  # message so external text always remains data.
  rlang::abort(
    paste0("KNB publication failed: ", safe),
    call = NULL
  )
}

.ms_knb_nonempty_scalar <- function(value, field) {
  if (is.null(value) ||
      length(value) != 1L ||
      is.na(value) ||
      !nzchar(trimws(as.character(value)))) {
    cli::cli_abort(
      "KNB adapter preflight returned invalid {.field {field}}."
    )
  }
  trimws(as.character(value))
}

.ms_knb_normalize_access <- function(access) {
  if (is.null(access) || length(access) == 0L) {
    return(data.frame(
      subject = character(),
      permission = character(),
      stringsAsFactors = FALSE
    ))
  }
  if (is.data.frame(access)) {
    out <- access
  } else if (is.list(access)) {
    rows <- lapply(access, function(rule) {
      if (!is.list(rule)) {
        cli::cli_abort("Remote access policy has an invalid rule.")
      }
      data.frame(
        subject = as.character(rule$subject),
        permission = as.character(rule$permission),
        stringsAsFactors = FALSE
      )
    })
    out <- do.call(rbind, rows)
  } else {
    cli::cli_abort("Remote access policy has an unsupported representation.")
  }
  if (!all(c("subject", "permission") %in% names(out))) {
    cli::cli_abort(
      "Remote access policy lacks subject/permission fields."
    )
  }
  out <- unique(data.frame(
    subject = as.character(out$subject),
    permission = tolower(as.character(out$permission)),
    stringsAsFactors = FALSE
  ))
  out[order(out$subject, out$permission), , drop = FALSE]
}

.ms_knb_normalize_member_nodes <- function(nodes) {
  if (is.null(nodes) || length(nodes) == 0L) {
    return(character())
  }
  values <- trimws(as.character(unlist(nodes, use.names = FALSE)))
  if (anyNA(values) || any(!nzchar(values))) {
    cli::cli_abort(
      "Remote replication policy has an invalid member-node reference."
    )
  }

  sort(unique(values))
}

.ms_knb_optional_scalar <- function(value) {
  if (is.null(value) ||
      length(value) == 0L ||
      is.na(value[[1]]) ||
      !nzchar(trimws(as.character(value[[1]])))) {
    return(NA_character_)
  }
  as.character(value[[1]])
}

.ms_knb_valid_timestamp <- function(value) {
  value <- .ms_knb_optional_scalar(value)
  if (is.na(value) ||
      !grepl(
        paste0(
          "^[0-9]{4}-[0-9]{2}-[0-9]{2}T",
          "[0-9]{2}:[0-9]{2}:[0-9]{2}",
          "(\\.[0-9]+)?(Z|[+-][0-9]{2}:[0-9]{2})$"
        ),
        value
      )) {
    return(FALSE)
  }
  normalized <- sub("Z$", "+0000", value)
  normalized <- sub(
    "([+-][0-9]{2}):([0-9]{2})$",
    "\\1\\2",
    normalized
  )
  parsed <- suppressWarnings(tryCatch(
    as.POSIXct(
      normalized,
      format = "%Y-%m-%dT%H:%M:%OS%z",
      tz = "UTC"
    ),
    error = function(error) as.POSIXct(NA_character_)
  ))
  length(parsed) == 1L && !is.na(parsed)
}

.ms_knb_validate_system_metadata <- function(remote,
                                             object,
                                             subject,
                                             public,
                                             replication_policy) {
  if (!is.list(remote)) {
    cli::cli_abort(
      "Remote SystemMetadata for {.val {object$pid}} is missing or malformed."
    )
  }
  .ms_knb_require_replication_policy(replication_policy, public)
  expected <- list(
    identifier = object$pid,
    format_id = object$format_id,
    size = as.numeric(object$size),
    checksum = tolower(object$sha256),
    checksum_algorithm = "SHA-256",
    rights_holder = subject,
    series_id = .ms_knb_optional_scalar(object$series_id),
    media_type = object$media_type,
    file_name = basename(object$path),
    archived = FALSE,
    replication_allowed = replication_policy$replication_allowed,
    number_replicas = as.numeric(replication_policy$number_replicas),
    preferred_member_nodes = .ms_knb_normalize_member_nodes(
      replication_policy$preferred_member_nodes
    ),
    blocked_member_nodes = .ms_knb_normalize_member_nodes(
      replication_policy$blocked_member_nodes
    ),
    obsoletes = .ms_knb_optional_scalar(object$obsoletes),
    obsoleted_by = .ms_knb_optional_scalar(object$obsoleted_by),
    origin_member_node = .ms_knb_node_id,
    authoritative_member_node = .ms_knb_node_id
  )
  actual <- list(
    identifier = .ms_knb_optional_scalar(remote$identifier),
    format_id = .ms_knb_optional_scalar(remote$format_id),
    size = suppressWarnings(as.numeric(remote$size)),
    checksum = tolower(.ms_knb_optional_scalar(remote$checksum)),
    checksum_algorithm = toupper(.ms_knb_optional_scalar(
      remote$checksum_algorithm
    )),
    rights_holder = .ms_knb_optional_scalar(remote$rights_holder),
    series_id = .ms_knb_optional_scalar(remote$series_id),
    media_type = .ms_knb_optional_scalar(remote$media_type),
    file_name = .ms_knb_optional_scalar(remote$file_name),
    archived = if (
      length(remote$archived) == 1L &&
        !is.na(remote$archived)
    ) {
      isTRUE(remote$archived)
    } else {
      NA
    },
    replication_allowed = if (
      is.logical(remote$replication_allowed) &&
        length(remote$replication_allowed) == 1L &&
        !is.na(remote$replication_allowed)
    ) {
      remote$replication_allowed
    } else {
      NA
    },
    number_replicas = {
      value <- suppressWarnings(as.numeric(remote$number_replicas))
      if (length(value) == 1L &&
          !is.na(value) &&
          is.finite(value) &&
          value >= 0 &&
          value == floor(value)) {
        value
      } else {
        NA_real_
      }
    },
    preferred_member_nodes = .ms_knb_normalize_member_nodes(
      remote$preferred_member_nodes
    ),
    blocked_member_nodes = .ms_knb_normalize_member_nodes(
      remote$blocked_member_nodes
    ),
    obsoletes = .ms_knb_optional_scalar(remote$obsoletes),
    obsoleted_by = .ms_knb_optional_scalar(remote$obsoleted_by),
    origin_member_node = .ms_knb_optional_scalar(
      remote$origin_member_node
    ),
    authoritative_member_node = .ms_knb_optional_scalar(
      remote$authoritative_member_node
    )
  )
  mismatches <- character()
  for (field in names(expected)) {
    matches <- if (identical(field, "size")) {
      length(actual[[field]]) == 1L &&
        !is.na(actual[[field]]) &&
        identical(actual[[field]], expected[[field]])
    } else if (identical(field, "checksum_algorithm")) {
      identical(gsub("-", "", actual[[field]], fixed = TRUE), "SHA256")
    } else {
      identical(actual[[field]], expected[[field]])
    }
    if (!matches) {
      mismatches <- c(mismatches, field)
    }
  }
  if (!.ms_knb_same_subject(remote$submitter, subject)) {
    mismatches <- c(mismatches, "submitter")
  }
  serial_version <- suppressWarnings(as.numeric(
    .ms_knb_optional_scalar(remote$serial_version)
  ))
  if (length(serial_version) != 1L ||
      is.na(serial_version) ||
      !is.finite(serial_version) ||
      serial_version < 0 ||
      serial_version != floor(serial_version)) {
    mismatches <- c(mismatches, "serial_version")
  }
  if (!.ms_knb_valid_timestamp(remote$date_uploaded)) {
    mismatches <- c(mismatches, "date_uploaded")
  }
  if (!.ms_knb_valid_timestamp(remote$date_sys_metadata_modified)) {
    mismatches <- c(mismatches, "date_sys_metadata_modified")
  }
  if (length(mismatches) > 0L) {
    cli::cli_abort(
      "Remote PID {.val {object$pid}} collides on SystemMetadata field{?s}: {.field {mismatches}}."
    )
  }

  access <- .ms_knb_normalize_access(remote$access)
  expected_access <- if (isTRUE(public)) {
    data.frame(
      subject = "public",
      permission = "read",
      stringsAsFactors = FALSE
    )
  } else {
    data.frame(
      subject = character(),
      permission = character(),
      stringsAsFactors = FALSE
    )
  }
  rownames(access) <- NULL
  rownames(expected_access) <- NULL
  if (!identical(access, expected_access)) {
    cli::cli_abort(
      "Remote PID {.val {object$pid}} has a different access policy."
    )
  }
  invisible(TRUE)
}

.ms_knb_anonymous_denial_status <- function(condition) {
  class_names <- class(condition)
  status_class <- grep(
    "http_[0-9]{3}$",
    class_names,
    value = TRUE
  )
  if (length(status_class) > 0L) {
    return(suppressWarnings(as.integer(sub(
      ".*http_([0-9]{3})$",
      "\\1",
      status_class[[1]]
    ))))
  }
  response <- condition$response
  if (!is.null(response) && requireNamespace("httr2", quietly = TRUE)) {
    status <- suppressWarnings(tryCatch(
      httr2::resp_status(response),
      error = function(error) NA_integer_
    ))
    if (length(status) == 1L && !is.na(status)) {
      return(as.integer(status))
    }
  }
  NA_integer_
}

.ms_knb_verify_anonymous_denial <- function(adapter, endpoint, object) {
  probes <- list(
    byte = function() {
      adapter$get_anonymous_bytes(endpoint, object$pid)
    },
    SystemMetadata = function() {
      adapter$get_anonymous_system_metadata(endpoint, object$pid)
    }
  )
  for (kind in names(probes)) {
    probe <- tryCatch(
      list(
        disclosed = TRUE,
        value = probes[[kind]](),
        condition = NULL
      ),
      error = function(condition) {
        list(disclosed = FALSE, value = NULL, condition = condition)
      }
    )
    if (isTRUE(probe$disclosed)) {
      cli::cli_abort(
        "Anonymous {kind} access unexpectedly succeeded for private-review PID {.val {object$pid}}."
      )
    }
    status <- .ms_knb_anonymous_denial_status(probe$condition)
    if (!status %in% c(401L, 403L, 404L)) {
      cli::cli_abort(
        "Anonymous {kind} non-disclosure could not be verified for private-review PID {.val {object$pid}}."
      )
    }
  }
  invisible(TRUE)
}

.ms_knb_verify_object <- function(adapter,
                                  client,
                                  endpoint,
                                  object,
                                  bytes,
                                  subject,
                                  public,
                                  replication_policy) {
  remote_bytes <- adapter$get_bytes(client, object$pid)
  if (!is.raw(remote_bytes) || !identical(remote_bytes, bytes)) {
    cli::cli_abort(
      "Remote byte read-back failed for PID {.val {object$pid}}."
    )
  }
  remote_metadata <- adapter$get_system_metadata(client, object$pid)
  .ms_knb_validate_system_metadata(
    remote_metadata,
    object,
    subject,
    public,
    replication_policy
  )
  remote_checksum <- adapter$get_checksum(
    client,
    object$pid,
    "SHA-256"
  )
  if (!identical(
    tolower(.ms_knb_optional_scalar(remote_checksum)),
    tolower(object$sha256)
  )) {
    cli::cli_abort(
      "Independent remote checksum failed for PID {.val {object$pid}}."
    )
  }

  if (isTRUE(public)) {
    anonymous_bytes <- adapter$get_anonymous_bytes(endpoint, object$pid)
    if (!is.raw(anonymous_bytes) || !identical(anonymous_bytes, bytes)) {
      cli::cli_abort(
        "Anonymous byte read-back failed for public PID {.val {object$pid}}."
      )
    }
    anonymous_metadata <- adapter$get_anonymous_system_metadata(
      endpoint,
      object$pid
    )
    .ms_knb_validate_system_metadata(
      anonymous_metadata,
      object,
      subject,
      public,
      replication_policy
    )
  } else {
    .ms_knb_verify_anonymous_denial(adapter, endpoint, object)
  }
  invisible(TRUE)
}

.ms_knb_manifest_set_state <- function(manifest, pid, state) {
  index <- match(
    pid,
    vapply(manifest$objects, function(x) x$pid, character(1))
  )
  if (is.na(index)) {
    cli::cli_abort(
      "Internal manifest error: PID {.val {pid}} is not in the plan."
    )
  }
  manifest$objects[[index]]$state <- state
  manifest
}

.ms_knb_persist_manifest <- function(manifest, path) {
  .ms_knb_atomic_write_raw(.ms_knb_json_bytes(manifest), path)
  manifest
}

.ms_knb_local_object_spec <- function(object) {
  bytes <- .ms_knb_object_bytes(object$local_path)
  if (length(bytes) != object$size ||
      !identical(.ms_knb_sha256_raw(bytes), object$sha256)) {
    cli::cli_abort(
      "Local publication object {.path {object$path}} changed after planning."
    )
  }
  object$bytes <- bytes
  object$series_id <- .ms_knb_optional_scalar(object$series_id)
  object
}

.ms_knb_catalog_records <- function(records) {
  if (is.null(records) || length(records) == 0L) {
    return(list())
  }
  if (is.data.frame(records)) {
    return(lapply(seq_len(nrow(records)), function(i) {
      as.list(records[i, , drop = FALSE])
    }))
  }
  if (!is.list(records)) {
    return(list())
  }
  records
}

.ms_knb_catalog_values <- function(record, field) {
  values <- record[[field]]
  if (is.null(values)) {
    return(character())
  }
  values <- trimws(as.character(unlist(values, use.names = FALSE)))
  sort(unique(values[!is.na(values) & nzchar(values)]))
}

.ms_knb_catalog_evidence <- function(plan, records) {
  records <- .ms_knb_catalog_records(records)
  ids <- unname(vapply(
    records,
    function(record) .ms_knb_optional_scalar(record$id),
    character(1)
  ))
  indexed_ids <- ids[!is.na(ids)]
  expected_pids <- unname(vapply(
    plan$objects,
    function(object) object$pid,
    character(1)
  ))
  member_objects <- plan$objects[vapply(
    plan$objects,
    function(object) !identical(object$role, "resource_map"),
    logical(1)
  )]
  member_pids <- unname(vapply(
    member_objects,
    function(object) object$pid,
    character(1)
  ))
  record_for <- function(pid) {
    matches <- records[!is.na(ids) & ids == pid]
    if (length(matches) != 1L) list() else matches[[1]]
  }
  resource_map_members <- member_pids[vapply(
    member_pids,
    function(pid) {
      plan$resource_map_pid %in%
        .ms_knb_catalog_values(record_for(pid), "resourceMap")
    },
    logical(1)
  )]
  metadata_record <- record_for(plan$metadata_pid)
  metadata_documents <- .ms_knb_catalog_values(
    metadata_record,
    "documents"
  )
  documented_pids <- unname(vapply(
    plan$objects[vapply(
      plan$objects,
      function(object) {
        object$role %in% c("data", "sdp_archive", "sdp_artifact")
      },
      logical(1)
    )],
    function(object) object$pid,
    character(1)
  ))
  documented_objects <- documented_pids[vapply(
    documented_pids,
    function(pid) {
      plan$metadata_pid %in%
        .ms_knb_catalog_values(record_for(pid), "isDocumentedBy")
    },
    logical(1)
  )]
  verified <- setequal(indexed_ids, expected_pids) &&
    length(indexed_ids) == length(expected_pids) &&
    length(unique(indexed_ids)) == length(expected_pids) &&
    setequal(resource_map_members, member_pids) &&
    length(resource_map_members) == length(member_pids) &&
    identical(sort(metadata_documents), sort(documented_pids)) &&
    setequal(documented_objects, documented_pids) &&
    length(documented_objects) == length(documented_pids)
  list(
    verified = isTRUE(verified),
    indexed_pids = sort(unique(indexed_ids)),
    resource_map_pid = plan$resource_map_pid,
    resource_map_members = sort(resource_map_members),
    metadata_pid = plan$metadata_pid,
    metadata_documents = sort(metadata_documents),
    documented_data_pids = sort(documented_objects),
    supplemental_relations_clean = TRUE
  )
}

.ms_knb_result_archive_path <- function(plan) {
  if (is.null(plan$sdp_archive_path)) {
    return(NULL)
  }
  normalizePath(plan$sdp_archive_path, mustWork = TRUE)
}

.ms_knb_anonymous_catalog_evidence <- function(plan, records) {
  if (isTRUE(plan$public)) {
    return(.ms_knb_catalog_evidence(plan, records))
  }
  records <- .ms_knb_catalog_records(records)
  indexed_ids <- unname(vapply(
    records,
    function(record) .ms_knb_optional_scalar(record$id),
    character(1)
  ))
  indexed_ids <- sort(unique(indexed_ids[!is.na(indexed_ids)]))
  planned_pids <- unname(vapply(
    plan$objects,
    function(object) object$pid,
    character(1)
  ))
  matching_pids <- sort(intersect(indexed_ids, planned_pids))
  list(
    verified = length(matching_pids) == 0L,
    matching_pids = matching_pids
  )
}

.ms_knb_prior_object_spec <- function(plan, pid, obsoleted_by = NULL) {
  prior <- plan$prior_manifest
  if (is.null(prior)) {
    cli::cli_abort("Internal KNB revision error: no prior manifest is bound.")
  }
  objects <- .ms_knb_manifest_objects(prior)
  matches <- objects[vapply(objects, function(object) {
    identical(as.character(object$pid), pid)
  }, logical(1))]
  if (length(matches) != 1L) {
    cli::cli_abort(
      "The prior KNB manifest does not identify revision source PID {.val {pid}} exactly once."
    )
  }
  object <- matches[[1L]]
  object$series_id <- if (identical(as.character(object$role), "metadata")) {
    as.character(prior$series_id)
  } else {
    NA_character_
  }
  object$obsoletes <- .ms_knb_optional_scalar(object$obsoletes)
  object$obsoleted_by <- .ms_knb_optional_scalar(obsoleted_by)
  object
}

.ms_knb_validate_revision_source <- function(remote,
                                             plan,
                                             old_pid,
                                             new_pid,
                                             subject) {
  if (is.null(remote)) {
    cli::cli_abort(
      "KNB revision source PID {.val {old_pid}} does not exist at KNB."
    )
  }
  linked_to <- .ms_knb_optional_scalar(remote$obsoleted_by)
  if (!is.na(linked_to) && !identical(linked_to, new_pid)) {
    cli::cli_abort(
      "KNB revision source PID {.val {old_pid}} is already obsoleted by a different PID."
    )
  }
  prior_object <- .ms_knb_prior_object_spec(
    plan,
    old_pid,
    obsoleted_by = linked_to
  )
  .ms_knb_validate_system_metadata(
    remote,
    prior_object,
    subject,
    plan$public,
    plan$replication_policy
  )
  invisible(linked_to)
}

.ms_knb_validate_series_binding <- function(remote,
                                            metadata_object,
                                            subject,
                                            public,
                                            replication_policy,
                                            plan = NULL) {
  if (is.null(remote)) {
    return(invisible(TRUE))
  }
  remote_pid <- .ms_knb_optional_scalar(remote$identifier)
  revision_source <- .ms_knb_optional_scalar(metadata_object$obsoletes)
  allowed <- if (is.na(revision_source)) {
    metadata_object$pid
  } else {
    c(revision_source, metadata_object$pid)
  }
  if (!remote_pid %in% allowed) {
    cli::cli_abort(
      "The metadata series identifier is already bound to a different metadata PID."
    )
  }
  if (!is.na(revision_source) && identical(remote_pid, revision_source)) {
    if (is.null(plan)) {
      cli::cli_abort("Internal KNB revision error: no plan is available.")
    }
    .ms_knb_validate_revision_source(
      remote,
      plan,
      revision_source,
      metadata_object$pid,
      subject
    )
    return(invisible(TRUE))
  }
  .ms_knb_validate_system_metadata(
    remote,
    metadata_object,
    subject,
    public,
    replication_policy
  )
  invisible(TRUE)
}

.ms_knb_run_publication <- function(plan,
                                    manifest,
                                    manifest_path,
                                    adapter,
                                    previous_status = NA_character_) {
  tryCatch(
    withCallingHandlers({
      # Freeze and re-hash every local byte stream before constructing a
      # client or observing any remote state. Nothing below this boundary
      # re-reads a local publication object.
      object_specs <- lapply(
        plan$objects,
        function(object) {
          specification <- .ms_knb_local_object_spec(object)
          specification$replication_policy <- plan$replication_policy
          specification
        }
      )
      .ms_knb_require_replication_policy(
        plan$replication_policy,
        plan$public
      )

      .ms_knb_validate_adapter(adapter)
      client <- adapter$connect(plan$environment, plan$node_id)
      preflight <- adapter$preflight(client)
      if (!is.list(preflight)) {
        cli::cli_abort("KNB adapter preflight returned no result.")
      }
      subject <- .ms_knb_nonempty_scalar(preflight$subject, "subject")
      endpoint <- .ms_knb_nonempty_scalar(preflight$endpoint, "endpoint")
      preflight_node_id <- .ms_knb_nonempty_scalar(
        preflight$node_id,
        "node_id"
      )
      if (!identical(preflight_node_id, plan$node_id)) {
        cli::cli_abort(
          "KNB preflight returned a different DataONE node identifier."
        )
      }
      if (!.ms_knb_same_subject(subject, plan$expected_subject)) {
        cli::cli_abort(
          "The server-verified DataONE subject does not match the EML metadata-provider ORCID."
        )
      }
      available_formats <- unique(trimws(as.character(
        adapter$list_formats(client)
      )))
      planned_formats <- unique(vapply(
        object_specs,
        function(object) object$format_id,
        character(1)
      ))
      missing_formats <- setdiff(planned_formats, available_formats)
      if (length(missing_formats) > 0L) {
        cli::cli_abort(
          "The live DataONE format registry lacks planned format ID{?s}: {.val {missing_formats}}."
        )
      }

      # Scan every immutable PID, including independent checksum evidence for
      # existing objects, before the first create. A collision on the last
      # planned object therefore cannot orphan earlier creates.
      remote_objects <- vector("list", length(object_specs))
      revision_sources <- vector("list", length(object_specs))
      for (i in seq_along(object_specs)) {
        object <- object_specs[[i]]
        remote <- adapter$lookup_system_metadata(client, object$pid)
        if (!is.null(remote)) {
          .ms_knb_validate_system_metadata(
            remote,
            object,
            subject,
            plan$public,
            plan$replication_policy
          )
          checksum <- adapter$get_checksum(
            client,
            object$pid,
            "SHA-256"
          )
          if (!identical(
            tolower(.ms_knb_optional_scalar(checksum)),
            tolower(object$sha256)
          )) {
            cli::cli_abort(
              "Remote PID {.val {object$pid}} collides on independent checksum."
            )
          }
        }
        update_of <- .ms_knb_optional_scalar(object$obsoletes)
        if (!is.na(update_of)) {
          source_remote <- adapter$lookup_system_metadata(
            client,
            update_of
          )
          linked_to <- .ms_knb_validate_revision_source(
            source_remote,
            plan,
            update_of,
            object$pid,
            subject
          )
          source_checksum <- adapter$get_checksum(
            client,
            update_of,
            "SHA-256"
          )
          prior_object <- .ms_knb_prior_object_spec(
            plan,
            update_of,
            obsoleted_by = linked_to
          )
          if (!identical(
            tolower(.ms_knb_optional_scalar(source_checksum)),
            tolower(prior_object$sha256)
          )) {
            cli::cli_abort(
              "KNB revision source PID {.val {update_of}} collides on independent checksum."
            )
          }
          if (is.null(remote) && !is.na(linked_to)) {
            cli::cli_abort(
              "KNB revision source PID {.val {update_of}} names the planned successor, but that successor cannot be read."
            )
          }
          if (!is.null(remote) && is.na(linked_to)) {
            cli::cli_abort(
              "The planned revision PID exists, but its predecessor does not link to it."
            )
          }
          revision_sources[i] <- list(source_remote)
        }
        remote_objects[i] <- list(remote)
      }

      metadata_index <- which(vapply(
        object_specs,
        function(object) identical(object$role, "metadata"),
        logical(1)
      ))
      metadata_object <- object_specs[[metadata_index]]
      series_remote <- adapter$lookup_series_id(
        client,
        plan$series_id
      )
      .ms_knb_validate_series_binding(
        series_remote,
        metadata_object,
        subject,
        plan$public,
        plan$replication_policy,
        plan = plan
      )
      if (!is.null(remote_objects[[metadata_index]]) &&
          is.null(series_remote)) {
        cli::cli_abort(
          "The existing metadata PID has an unresolved metadata series identifier."
        )
      }

      for (i in seq_along(object_specs)) {
        object <- object_specs[[i]]
        remote <- remote_objects[[i]]
        if (is.null(remote)) {
          create_error <- NULL
          tryCatch(
            {
              update_of <- .ms_knb_optional_scalar(object$obsoletes)
              if (is.na(update_of)) {
                adapter$create_object(
                  client,
                  object,
                  subject,
                  plan$public
                )
              } else {
                adapter$update_object(
                  client,
                  update_of,
                  object,
                  subject,
                  plan$public
                )
              }
            },
            error = function(error) {
              create_error <<- error
            }
          )
          if (!is.null(create_error)) {
            # A timed-out create may have committed. Only an authoritative
            # follow-up lookup can resolve that ambiguity.
            remote <- adapter$lookup_system_metadata(
              client,
              object$pid
            )
            if (is.null(remote)) {
              stop(create_error)
            }
            .ms_knb_validate_system_metadata(
              remote,
              object,
              subject,
              plan$public,
              plan$replication_policy
            )
          }
        }

        .ms_knb_verify_object(
          adapter,
          client,
          endpoint,
          object,
          object$bytes,
          subject,
          plan$public,
          plan$replication_policy
        )
        update_of <- .ms_knb_optional_scalar(object$obsoletes)
        if (!is.na(update_of)) {
          source_remote <- adapter$lookup_system_metadata(
            client,
            update_of
          )
          linked_to <- .ms_knb_validate_revision_source(
            source_remote,
            plan,
            update_of,
            object$pid,
            subject
          )
          if (!identical(linked_to, object$pid)) {
            cli::cli_abort(
              "KNB did not link revision source PID {.val {update_of}} to its planned successor."
            )
          }
        }
        manifest <- .ms_knb_manifest_set_state(
          manifest,
          object$pid,
          "verified"
        )
        manifest <- .ms_knb_persist_manifest(
          manifest,
          manifest_path
        )
      }

      authenticated_evidence <- .ms_knb_catalog_evidence(
        plan,
        adapter$catalog_lookup(client, plan)
      )
      anonymous_evidence <- .ms_knb_anonymous_catalog_evidence(
        plan,
        adapter$anonymous_catalog_lookup(plan)
      )
      evidence <- list(
        authenticated = authenticated_evidence,
        anonymous = anonymous_evidence
      )
      # A local manifest is a recovery aid, not a signed attestation. Always
      # bind completion of this live call to the fresh catalog response; a
      # stale or edited `catalog_verified = true` value must never bypass a
      # failed current graph check.
      manifest$catalog_verified <-
        isTRUE(authenticated_evidence$verified) &&
        isTRUE(anonymous_evidence$verified)
      manifest$catalog_evidence <- evidence
      if (!isTRUE(plan$public) &&
          !isTRUE(anonymous_evidence$verified)) {
        manifest$status <- "published_pending_catalog"
        manifest <- .ms_knb_persist_manifest(
          manifest,
          manifest_path
        )
        cli::cli_abort(
          "Anonymous catalog unexpectedly exposed private-review PID{?s}: {.val {anonymous_evidence$matching_pids}}."
        )
      }
      if (!isTRUE(manifest$catalog_verified)) {
        manifest$status <- "published_pending_catalog"
        manifest <- .ms_knb_persist_manifest(
          manifest,
          manifest_path
        )
        return(invisible(list(
          status = "published_pending_catalog",
          package_id = plan$package_id,
          series_id = plan$series_id,
          resource_map_pid = plan$resource_map_pid,
          manifest_path = normalizePath(
            manifest_path,
            mustWork = TRUE
          ),
          resource_map_path = normalizePath(
            plan$resource_map_path,
            mustWork = TRUE
          ),
          sdp_archive_path = .ms_knb_result_archive_path(plan),
          representation = plan$representation,
          manifest = manifest
        )))
      }

      manifest$status <- "complete"
      manifest <- .ms_knb_persist_manifest(
        manifest,
        manifest_path
      )
      status <- if (identical(previous_status, "complete")) {
        "already_published"
      } else {
        "published"
      }
      result <- list(
        status = status,
        package_id = plan$package_id,
        series_id = plan$series_id,
        resource_map_pid = plan$resource_map_pid,
        manifest_path = normalizePath(
          manifest_path,
          mustWork = TRUE
        ),
        resource_map_path = normalizePath(
          plan$resource_map_path,
          mustWork = TRUE
        ),
        sdp_archive_path = .ms_knb_result_archive_path(plan),
        representation = plan$representation,
        manifest = manifest
      )
      cli::cli_alert_success(
        "KNB publication verified for metadata PID {.val {plan$metadata_pid}}"
      )
      invisible(result)
    }, warning = function(warning) {
      rlang::abort(
        paste0(
          "Live KNB adapter warning: ",
          .ms_knb_redact(conditionMessage(warning))
        ),
        call = NULL
      )
    }),
    error = .ms_knb_abort_safe
  )
}

.ms_knb_system_metadata_list <- function(system_metadata) {
  if (is.null(system_metadata) ||
      !methods::is(system_metadata, "SystemMetadata")) {
    return(NULL)
  }
  list(
    serial_version = system_metadata@serialVersion,
    identifier = system_metadata@identifier,
    format_id = system_metadata@formatId,
    size = system_metadata@size,
    checksum = system_metadata@checksum,
    checksum_algorithm = system_metadata@checksumAlgorithm,
    submitter = system_metadata@submitter,
    rights_holder = system_metadata@rightsHolder,
    access = system_metadata@accessPolicy,
    replication_allowed = system_metadata@replicationAllowed,
    number_replicas = system_metadata@numberReplicas,
    preferred_member_nodes = system_metadata@preferredNodes,
    blocked_member_nodes = system_metadata@blockedNodes,
    series_id = system_metadata@seriesId,
    media_type = system_metadata@mediaType,
    file_name = system_metadata@fileName,
    archived = system_metadata@archived,
    obsoletes = system_metadata@obsoletes,
    obsoleted_by = system_metadata@obsoletedBy,
    date_uploaded = system_metadata@dateUploaded,
    date_sys_metadata_modified = system_metadata@dateSysMetadataModified,
    origin_member_node = system_metadata@originMemberNode,
    authoritative_member_node = system_metadata@authoritativeMemberNode
  )
}

.ms_knb_new_system_metadata <- function(object,
                                        subject,
                                        public,
                                        node_id,
                                        replication_policy) {
  .ms_knb_require_replication_policy(replication_policy, public)
  system_metadata <- methods::new("SystemMetadata")
  # `datapack::SystemMetadata()` supplies local defaults for several fields
  # that the DataONE service owns.  Do not serialize those invented values.
  # `dataone::createObject()` will add authoritativeMemberNode immediately
  # before its supported upload boundary; KNB remains authoritative for the
  # resulting server-side value.  submitter is retained because datapack's
  # serializer always emits that element, even when its slot is missing.
  system_metadata@serialVersion <- as.numeric(NA)
  system_metadata@archived <- as.logical(NA)
  system_metadata@dateUploaded <- NA_character_
  system_metadata@dateSysMetadataModified <- NA_character_
  system_metadata@originMemberNode <- NA_character_
  system_metadata@authoritativeMemberNode <- NA_character_
  system_metadata@identifier <- object$pid
  system_metadata@formatId <- object$format_id
  system_metadata@size <- as.numeric(object$size)
  system_metadata@checksum <- object$sha256
  system_metadata@checksumAlgorithm <- "SHA-256"
  system_metadata@submitter <- subject
  system_metadata@rightsHolder <- subject
  system_metadata@replicationAllowed <-
    replication_policy$replication_allowed
  system_metadata@numberReplicas <-
    as.numeric(replication_policy$number_replicas)
  system_metadata@preferredNodes <-
    replication_policy$preferred_member_nodes
  system_metadata@blockedNodes <-
    replication_policy$blocked_member_nodes
  system_metadata@mediaType <- object$media_type
  system_metadata@fileName <- basename(object$path)
  series_id <- .ms_knb_optional_scalar(object$series_id)
  if (!is.na(series_id)) {
    system_metadata@seriesId <- series_id
  }
  obsoletes <- .ms_knb_optional_scalar(object$obsoletes)
  if (!is.na(obsoletes)) {
    system_metadata@obsoletes <- obsoletes
  }
  obsoleted_by <- .ms_knb_optional_scalar(object$obsoleted_by)
  if (!is.na(obsoleted_by)) {
    system_metadata@obsoletedBy <- obsoleted_by
  }
  if (isTRUE(public)) {
    system_metadata <- datapack::addAccessRule(
      system_metadata,
      "public",
      permission = "read"
    )
  }
  system_metadata
}

.ms_knb_orcid_key <- function(subject) {
  subject <- trimws(as.character(subject))
  matched <- regexec(
    "^https?://orcid\\.org/([0-9]{4}-[0-9]{4}-[0-9]{4}-[0-9]{3}[0-9X])/?$",
    subject,
    ignore.case = TRUE
  )
  parts <- regmatches(subject, matched)[[1]]
  if (length(parts) == 2L) {
    return(toupper(parts[[2]]))
  }
  NA_character_
}

.ms_knb_same_subject <- function(left, right) {
  left <- trimws(as.character(left))
  right <- trimws(as.character(right))
  if (length(left) != 1L ||
      length(right) != 1L ||
      is.na(left) ||
      is.na(right) ||
      !nzchar(left) ||
      !nzchar(right)) {
    return(FALSE)
  }
  if (identical(left, right)) {
    return(TRUE)
  }
  left_orcid <- .ms_knb_orcid_key(left)
  right_orcid <- .ms_knb_orcid_key(right)
  !is.na(left_orcid) &&
    !is.na(right_orcid) &&
    identical(left_orcid, right_orcid)
}

.ms_knb_echo_subjects <- function(credentials) {
  if (!is.list(credentials) || length(credentials) == 0L) {
    return(character())
  }
  people <- credentials[names(credentials) == "person"]
  subjects <- unlist(lapply(people, function(person) {
    if (!is.list(person) || is.null(names(person))) {
      return(character())
    }
    verified <- unname(unlist(
      person[names(person) == "verified"],
      use.names = FALSE
    ))
    explicitly_verified <- length(verified) > 0L &&
      all(tolower(trimws(as.character(verified))) == "true")
    if (length(verified) > 0L && !isTRUE(explicitly_verified)) {
      return(character())
    }
    primary <- unname(unlist(
      person[names(person) == "subject"],
      use.names = FALSE
    ))
    equivalent <- if (isTRUE(explicitly_verified)) {
      unname(unlist(
        person[names(person) == "equivalentIdentity"],
        use.names = FALSE
      ))
    } else {
      character()
    }
    c(primary, equivalent)
  }), use.names = FALSE)
  subjects <- trimws(as.character(subjects))
  unique(subjects[!is.na(subjects) & nzchar(subjects)])
}

.ms_knb_server_verified_subject <- function(credentials, token_subject) {
  token_subject <- .ms_knb_nonempty_scalar(token_subject, "subject")
  server_subjects <- .ms_knb_echo_subjects(credentials)
  matches <- vapply(
    server_subjects,
    .ms_knb_same_subject,
    logical(1),
    right = token_subject
  )
  if (!any(matches)) {
    cli::cli_abort(
      "The DataONE Coordinating Node did not verify the JWT subject."
    )
  }
  server_subjects[[which(matches)[[1]]]]
}

.ms_knb_capabilities_document <- function(capabilities) {
  if (inherits(capabilities, "XMLInternalDocument") ||
      inherits(capabilities, "XMLInternalElementNode")) {
    return(xml2::read_xml(XML::saveXML(capabilities)))
  }
  if (inherits(capabilities, c("xml_document", "xml_node"))) {
    return(capabilities)
  }
  if (is.character(capabilities) && length(capabilities) == 1L) {
    return(xml2::read_xml(capabilities))
  }
  cli::cli_abort("KNB returned an unreadable capabilities document.")
}

.ms_knb_public_request <- function(url) {
  httr2::request(url) |>
    httr2::req_timeout(30)
}

.ms_knb_anonymous_capabilities <- function(endpoint) {
  url <- paste0(sub("/+$", "", endpoint), "/node")
  response <- .ms_knb_public_request(url) |>
    httr2::req_perform()
  .ms_knb_capabilities_document(
    rawToChar(httr2::resp_body_raw(response))
  )
}

.ms_knb_validate_live_capabilities <- function(document,
                                               endpoint,
                                               node_id) {
  identifier <- trimws(xml2::xml_text(xml2::xml_find_all(
    document,
    "/*[local-name()='node']/*[local-name()='identifier']"
  )))
  if (length(identifier) != 1L || !identical(identifier, node_id)) {
    cli::cli_abort(
      "Direct unauthenticated KNB capabilities did not identify {.val {node_id}}."
    )
  }
  base_url <- trimws(xml2::xml_text(xml2::xml_find_all(
    document,
    "/*[local-name()='node']/*[local-name()='baseURL']"
  )))
  expected_endpoint <- if (length(base_url) == 1L) {
    paste0(sub("/+$", "", base_url), "/v2")
  } else {
    NA_character_
  }
  if (!identical(
    sub("/+$", "", endpoint),
    sub("/+$", "", expected_endpoint)
  )) {
    cli::cli_abort(
      "Direct KNB capabilities returned an unexpected service endpoint."
    )
  }

  storage <- xml2::xml_find_all(
    document,
    "//*[local-name()='service' and @name='MNStorage' and @available='true']"
  )
  versions <- xml2::xml_attr(storage, "version")
  if (length(storage) == 0L ||
      !any(grepl("(^|/)v?2($|/)", versions))) {
    cli::cli_abort(
      "Direct KNB capabilities do not advertise available MNStorage v2."
    )
  }
  read_only <- xml2::xml_text(xml2::xml_find_all(
    document,
    "//*[@key='read_only_mode']"
  ))
  if (length(read_only) == 0L ||
      !all(tolower(trimws(read_only)) == "false")) {
    cli::cli_abort(
      "Direct KNB capabilities do not explicitly report read_only_mode=false."
    )
  }
  invisible(TRUE)
}

.ms_knb_preflight_default <- function(client) {
  endpoint <- if (is.environment(client)) {
    .ms_knb_nonempty_scalar(client$endpoint, "endpoint")
  } else {
    .ms_knb_nonempty_scalar(client@mn@endpoint, "endpoint")
  }
  document <- .ms_knb_anonymous_capabilities(endpoint)
  .ms_knb_validate_live_capabilities(
    document,
    endpoint,
    .ms_knb_node_id
  )

  token <- getOption("dataone_token")
  if (!.ms_eml_nonempty(token)) {
    cli::cli_abort(
      "A short-lived DataONE JWT is required in the process-local {.code dataone_token} option."
    )
  }

  # Constructing a D1Client resolves its Member Node through the Coordinating
  # Node and can therefore attach configured credentials. Do this only after
  # the direct anonymous capabilities document has pinned KNB's identity and
  # endpoint.
  d1_client <- if (is.environment(client)) {
    dataone::D1Client(client$environment, client$node_id)
  } else {
    client
  }
  d1_endpoint <- .ms_knb_nonempty_scalar(
    d1_client@mn@endpoint,
    "endpoint"
  )
  d1_node_id <- .ms_knb_nonempty_scalar(
    d1_client@mn@identifier,
    "node_id"
  )
  if (!identical(sub("/+$", "", d1_endpoint), sub("/+$", "", endpoint)) ||
      !identical(d1_node_id, .ms_knb_node_id)) {
    cli::cli_abort(
      "The authenticated DataONE client did not resolve to the pinned KNB node and endpoint."
    )
  }
  if (!isTRUE(dataone::ping(d1_client@mn))) {
    cli::cli_abort("Direct KNB MN ping did not succeed.")
  }

  manager <- dataone::AuthenticationManager()
  is_auth_valid <- utils::getFromNamespace("isAuthValid", "dataone")
  get_auth_subject <- utils::getFromNamespace("getAuthSubject", "dataone")
  if (!isTRUE(suppressMessages(
    is_auth_valid(manager, d1_client@cn)
  ))) {
    cli::cli_abort(
      "The process-local DataONE JWT is absent, expired, or invalid for KNB."
    )
  }
  token_subject <- suppressMessages(
    get_auth_subject(manager, d1_client@cn)
  )

  # AuthenticationManager checks token claims locally but does not verify the
  # JWT signature.  The CN diagnostic endpoint performs the server-side
  # authentication check and echoes only identities accepted for the session.
  credentials <- dataone::echoCredentials(d1_client@cn)
  subject <- .ms_knb_server_verified_subject(
    credentials,
    token_subject
  )
  if (is.environment(client)) {
    client$d1_client <- d1_client
  }
  list(
    subject = .ms_knb_nonempty_scalar(subject, "subject"),
    endpoint = endpoint,
    node_id = .ms_knb_node_id
  )
}

.ms_knb_authenticated_client <- function(client) {
  if (methods::is(client, "D1Client")) {
    return(client)
  }
  if (is.environment(client) &&
      !is.null(client$d1_client) &&
      methods::is(client$d1_client, "D1Client")) {
    return(client$d1_client)
  }
  cli::cli_abort(
    "The default KNB client has not completed authenticated preflight."
  )
}

.ms_knb_anonymous_request <- function(endpoint, route, pid) {
  url <- paste(
    sub("/+$", "", endpoint),
    route,
    utils::URLencode(pid, reserved = TRUE),
    sep = "/"
  )
  .ms_knb_public_request(url) |>
    httr2::req_perform()
}

.ms_knb_lookup_http_status <- function(status, identifier, kind) {
  status <- suppressWarnings(as.integer(status))
  if (identical(status, 200L)) {
    return("present")
  }
  if (identical(status, 404L)) {
    return("absent")
  }
  cli::cli_abort(
    "DataONE {kind} existence for {.val {identifier}} is ambiguous after HTTP {status}; no create is safe."
  )
}

.ms_knb_lookup_node_system_metadata <- function(node,
                                                identifier,
                                                kind) {
  url <- paste(
    sub("/+$", "", node@endpoint),
    "meta",
    utils::URLencode(identifier, reserved = TRUE),
    sep = "/"
  )
  auth_get <- utils::getFromNamespace("auth_get", "dataone")
  response <- auth_get(url, node = node)
  state <- .ms_knb_lookup_http_status(
    response$status_code,
    identifier,
    kind
  )
  if (identical(state, "absent")) {
    return(NULL)
  }
  raw <- httr::content(response, as = "raw")
  parsed <- XML::xmlParse(rawToChar(raw))
  .ms_knb_system_metadata_list(
    datapack::SystemMetadata(XML::xmlRoot(parsed))
  )
}

.ms_knb_lookup_series_default <- function(client, series_id) {
  client <- .ms_knb_authenticated_client(client)
  results <- list(
    member_node = .ms_knb_lookup_node_system_metadata(
      client@mn,
      series_id,
      "series identifier at KNB"
    ),
    coordinating_node = .ms_knb_lookup_node_system_metadata(
      client@cn,
      series_id,
      "series identifier at the Coordinating Node"
    )
  )
  present <- results[!vapply(results, is.null, logical(1))]
  if (length(present) == 0L) {
    return(NULL)
  }
  pids <- unique(vapply(
    present,
    function(metadata) .ms_knb_optional_scalar(metadata$identifier),
    character(1)
  ))
  if (length(pids) != 1L || is.na(pids[[1]])) {
    cli::cli_abort(
      "The metadata series identifier has an ambiguous DataONE binding."
    )
  }
  present[[1]]
}

.ms_knb_lookup_pid_default <- function(client, pid) {
  client <- .ms_knb_authenticated_client(client)
  results <- list(
    member_node = .ms_knb_lookup_node_system_metadata(
      client@mn,
      pid,
      "PID at KNB"
    ),
    coordinating_node = .ms_knb_lookup_node_system_metadata(
      client@cn,
      pid,
      "PID at the Coordinating Node"
    )
  )
  present <- results[!vapply(results, is.null, logical(1))]
  if (length(present) == 0L) {
    return(NULL)
  }
  identifiers <- unique(vapply(
    present,
    function(metadata) .ms_knb_optional_scalar(metadata$identifier),
    character(1)
  ))
  if (length(identifiers) != 1L ||
      !identical(identifiers[[1]], pid)) {
    cli::cli_abort(
      "The planned PID has an ambiguous DataONE binding."
    )
  }
  present[[1]]
}

.ms_knb_list_formats_default <- function(client) {
  client <- .ms_knb_authenticated_client(client)
  endpoint <- sub("/+$", "", client@cn@endpoint)
  response <- .ms_knb_public_request(paste0(endpoint, "/formats")) |>
    httr2::req_perform()
  document <- xml2::read_xml(rawToChar(httr2::resp_body_raw(response)))
  formats <- unique(trimws(xml2::xml_text(xml2::xml_find_all(
    document,
    "//*[local-name()='formatId']"
  ))))
  formats[!is.na(formats) & nzchar(formats)]
}

.ms_knb_solr_quote <- function(value) {
  value <- gsub("\\", "\\\\", as.character(value), fixed = TRUE)
  gsub('"', '\\"', value, fixed = TRUE)
}

.ms_knb_catalog_url <- function(plan) {
  pids <- vapply(
    plan$objects,
    function(object) object$pid,
    character(1)
  )
  query <- paste0(
    'id:"',
    .ms_knb_solr_quote(pids),
    '"',
    collapse = " OR "
  )
  httr::modify_url(
    "https://cn.dataone.org/cn/v2/query/solr/",
    query = list(
      q = query,
      fl = "id,resourceMap,documents,isDocumentedBy",
      rows = length(pids),
      wt = "json"
    )
  )
}

.ms_knb_catalog_docs <- function(body) {
  if (!is.list(body$response) ||
      !is.list(body$response$docs)) {
    return(list())
  }
  body$response$docs
}

.ms_knb_authenticated_catalog_request <- function(client, plan) {
  auth_get <- utils::getFromNamespace("auth_get", "dataone")
  auth_get(
    .ms_knb_catalog_url(plan),
    node = client@cn
  )
}

.ms_knb_default_adapter <- function() {
  dependencies <- c("dataone", "datapack", "XML")
  missing <- dependencies[
    !vapply(dependencies, requireNamespace, logical(1), quietly = TRUE)
  ]
  if (length(missing) > 0L) {
    cli::cli_abort(
      "Live KNB publication requires package{?s}: {.pkg {missing}}."
    )
  }

  list(
    connect = function(environment, node_id) {
      if (!identical(environment, .ms_knb_environment) ||
          !identical(node_id, .ms_knb_node_id)) {
        cli::cli_abort(
          "The default publisher only supports production KNB."
        )
      }
      client <- new.env(parent = emptyenv())
      client$environment <- environment
      client$node_id <- node_id
      client$endpoint <- .ms_knb_mn_endpoint
      client$d1_client <- NULL
      client
    },
    preflight = .ms_knb_preflight_default,
    list_formats = .ms_knb_list_formats_default,
    lookup_system_metadata = .ms_knb_lookup_pid_default,
    lookup_series_id = .ms_knb_lookup_series_default,
    create_object = function(client, object_spec, subject, public) {
      client <- .ms_knb_authenticated_client(client)
      system_metadata <- .ms_knb_new_system_metadata(
        object_spec,
        subject,
        public,
        client@mn@identifier,
        object_spec$replication_policy
      )
      dataone::createObject(
        client@mn,
        object_spec$pid,
        sysmeta = system_metadata,
        dataobj = object_spec$bytes
      )
    },
    update_object = function(client,
                             old_pid,
                             object_spec,
                             subject,
                             public) {
      client <- .ms_knb_authenticated_client(client)
      system_metadata <- .ms_knb_new_system_metadata(
        object_spec,
        subject,
        public,
        client@mn@identifier,
        object_spec$replication_policy
      )
      dataone::updateObject(
        client@mn,
        pid = old_pid,
        newpid = object_spec$pid,
        sysmeta = system_metadata,
        dataobj = object_spec$bytes
      )
    },
    get_bytes = function(client, pid) {
      client <- .ms_knb_authenticated_client(client)
      dataone::getObject(client@mn, pid)
    },
    get_system_metadata = function(client, pid) {
      client <- .ms_knb_authenticated_client(client)
      .ms_knb_system_metadata_list(
        dataone::getSystemMetadata(client@mn, pid)
      )
    },
    get_checksum = function(client, pid, algorithm) {
      client <- .ms_knb_authenticated_client(client)
      dataone::getChecksum(
        client@mn,
        pid,
        checksumAlgorithm = algorithm
      )
    },
    get_anonymous_bytes = function(endpoint, pid) {
      response <- .ms_knb_anonymous_request(endpoint, "object", pid)
      httr2::resp_body_raw(response)
    },
    get_anonymous_system_metadata = function(endpoint, pid) {
      response <- .ms_knb_anonymous_request(endpoint, "meta", pid)
      raw <- httr2::resp_body_raw(response)
      parsed <- XML::xmlParse(rawToChar(raw))
      .ms_knb_system_metadata_list(
        datapack::SystemMetadata(XML::xmlRoot(parsed))
      )
    },
    catalog_lookup = function(client, plan) {
      client <- .ms_knb_authenticated_client(client)
      response <- .ms_knb_authenticated_catalog_request(client, plan)
      status <- suppressWarnings(as.integer(response$status_code))
      if (length(status) != 1L ||
          is.na(status) ||
          !identical(status, 200L)) {
        cli::cli_abort(
          "Authenticated DataONE catalog lookup failed after HTTP {status}."
        )
      }
      body <- jsonlite::fromJSON(
        rawToChar(httr::content(response, as = "raw")),
        simplifyVector = FALSE
      )
      .ms_knb_catalog_docs(body)
    },
    anonymous_catalog_lookup = function(plan) {
      response <- .ms_knb_public_request(
        .ms_knb_catalog_url(plan)
      ) |>
        httr2::req_perform()
      .ms_knb_catalog_docs(httr2::resp_body_json(
        response,
        simplifyVector = FALSE
      ))
    }
  )
}

#' Publish a reviewed Salmon Data Package to production KNB
#'
#' Plans an immutable DataONE package containing the original data resources
#' named by `tables.csv`, one validated EML 2.2.0 metadata object, and a
#' deterministic OAI-ORE resource map. The `expanded` representation publishes
#' each allowlisted canonical SDP artifact as a named, EML-documented DataONE
#' object and records its package-relative path with PROV-O `atLocation`; it
#' does not create a ZIP or duplicate the source table. The compatibility
#' `archive` representation publishes one deterministic SDP ZIP. The default
#' operation is a credential-free, network-free dry run. Live
#' publication requires a pre-existing exact dry-run manifest and an explicitly
#' supplied `confirm = TRUE` approving that plan. Redistribution authority is
#' recorded separately in the reviewed EML sidecar.
#'
#' DataONE credentials are read only inside the live adapter. Use a short-lived
#' DataONE JWT through the supported `dataone_token` runtime option; credentials
#' are never accepted as function arguments or written to the manifest.
#'
#' A live restricted deposit is the KNB review/staging mechanism; KNB does not
#' expose a separate server-side draft state. The persistent object identifiers
#' remain even while access is private. This function does not call KNB's
#' separate Publish action and never mints a DOI. If a reviewed dataset should
#' receive a DOI, request it for the science-metadata version through KNB when
#' making that version public. The DOI identifies the metadata version, not each
#' raw or supplementary object.
#'
#' Revisions must be built in a fresh versioned SDP directory. Keep the prior
#' package and its verified manifest unchanged, write the corrected SDP to a
#' new directory with a new `publication.revision_key`, and choose a new local
#' manifest path there. If KNB's separate Publish action later creates a
#' DOI-bearing metadata version, that KNB-created version is not automatically
#' imported into a metasalmon manifest; do not plan another metasalmon revision
#' from the older pre-DOI manifest.
#'
#' Publication currently materializes object bytes in memory for exact hashing
#' and readback. It is intended for modest tabular SDPs; large packages should
#' be tested in a dry run and may require a future streaming adapter.
#'
#' @param path Directory containing the reviewed Salmon Data Package.
#' @param eml_path Validated EML output path. Defaults to `metadata/eml.xml`
#'   inside `path`; it is rebuilt deterministically before planning.
#' @param public Explicit logical access decision. `TRUE` requests anonymous
#'   read access for every DataONE object and explicitly requests three DataONE
#'   preservation replicas. `FALSE` creates a restricted KNB-only production
#'   deposit, explicitly disables peer replication, and requires authenticated
#'   exact-byte/SystemMetadata verification plus anonymous denial for every
#'   object and zero anonymous catalog matches. The replication policy is part
#'   of the exact reviewed manifest and is verified on remote readback. There
#'   is no implicit access default.
#' @param manifest_path Recovery manifest path inside `path`. Defaults to
#'   `publication/knb-manifest.json`.
#' @param dry_run Logical; when `TRUE` (the default), write only local plan
#'   artifacts and never construct a DataONE adapter or read credentials.
#' @param confirm Explicit approval of the pre-existing exact dry-run plan and
#'   live mutation. Its interactive default can never authorize a live call:
#'   live mode requires that the argument was supplied and is exactly `TRUE`.
#' @param revision_manifest Optional path to the verified manifest for the
#'   preceding KNB version. Supplying it plans an immutable DataONE revision:
#'   the reviewed sidecar must contain a new `publication.revision_key`, the
#'   metadata series stays stable, and the new EML/resource-map objects
#'   obsolete their predecessors. Access cannot change in the same operation.
#' @param representation Publication representation. `"expanded"` publishes
#'   the closed SDP artifact inventory as individually named objects whose
#'   relative paths can reconstruct the package. `"archive"` (the compatibility
#'   default) publishes one deterministic ZIP in addition to each source data
#'   object. Neither mode scans arbitrary package files.
#'
#' @return Invisibly returns publication status, identifiers, normalized
#'   manifest and resource-map paths, the optional SDP-archive path, the
#'   representation, and the manifest.
#' @export
#'
#' @examples
#' \dontrun{
#' publish_sdp_to_knb(
#'   "path/to/reviewed-sdp",
#'   public = FALSE,
#'   dry_run = TRUE
#' )
#' }
publish_sdp_to_knb <- function(path,
                               eml_path = NULL,
                               public = NULL,
                               manifest_path = NULL,
                               dry_run = TRUE,
                               confirm = interactive(),
                               revision_manifest = NULL,
                               representation = c("archive", "expanded")) {
  confirm_missing <- missing(confirm)
  representation <- match.arg(representation)
  .ms_knb_validate_flag(public, "public")
  .ms_knb_validate_flag(dry_run, "dry_run")
  if (!isTRUE(dry_run) &&
      (confirm_missing || !isTRUE(confirm))) {
    cli::cli_abort(c(
      "Live KNB publication requires an explicit {.code confirm = TRUE}.",
      "i" = "This approves the pre-existing exact dry-run manifest; redistribution authority is recorded separately."
    ))
  }
  if (!dir.exists(path)) {
    cli::cli_abort("SDP directory {.path {path}} does not exist.")
  }
  path <- .ms_knb_package_root(path)
  prior_manifest <- .ms_knb_revision_manifest(revision_manifest)
  if (!is.null(prior_manifest)) {
    prior_manifest_path <- normalizePath(revision_manifest, mustWork = TRUE)
    package_prefix <- paste0(path, .Platform$file.sep)
    if (startsWith(prior_manifest_path, package_prefix)) {
      cli::cli_abort(c(
        "A KNB revision requires a fresh versioned SDP directory.",
        "i" = "Keep the preceding package and verified manifest unchanged; build the revised SDP and its new manifest in a different directory."
      ))
    }
  }

  if (is.null(eml_path)) {
    eml_path <- file.path(path, "metadata", "eml.xml")
  }

  if (is.null(manifest_path)) {
    manifest_path <- file.path(
      path,
      "publication",
      "knb-manifest.json"
    )
  }
  publication_paths <- .ms_knb_publication_paths(
    path,
    eml_path,
    manifest_path
  )
  eml_path <- publication_paths$eml_path
  manifest_path <- publication_paths$manifest_path
  resource_map_path <- publication_paths$resource_map_path
  previous <- .ms_knb_existing_manifest(manifest_path)
  if (!isTRUE(dry_run) && is.null(previous)) {
    cli::cli_abort(
      "Live KNB publication requires a pre-existing exact matching reviewed dry-run manifest."
    )
  }

  manifest_parent <- dirname(manifest_path)
  if (!dir.exists(manifest_parent)) {
    dir.create(manifest_parent, recursive = TRUE, showWarnings = FALSE)
  }
  if (!dir.exists(manifest_parent)) {
    cli::cli_abort(
      "Could not create publication artifact directory {.path {manifest_parent}}."
    )
  }

  plan <- .ms_knb_build_plan(
    path,
    eml_path,
    manifest_path,
    public,
    representation = representation,
    prior_manifest = prior_manifest,
    resource_map_path = resource_map_path
  )
  if (!is.null(previous) &&
      !identical(as.character(previous$plan_sha256), plan$plan_sha256)) {
    cli::cli_abort(c(
      "The existing publication manifest describes a different plan.",
      "i" = "DataONE PIDs are immutable. Supply revision_manifest and a new manifest_path for a reviewed revision."
    ))
  }
  if (!isTRUE(dry_run)) {
    .ms_knb_require_reviewed_manifest(previous, plan)
    .ms_knb_require_rights_authorization(plan)
  }

  .ms_knb_assert_resource_map_owned(plan, previous)
  .ms_knb_atomic_write_raw(
    plan$resource_map_bytes,
    plan$resource_map_path
  )
  manifest_status <- if (isTRUE(dry_run)) "dry_run" else "pending"
  manifest <- .ms_knb_manifest(
    plan,
    status = manifest_status,
    previous = previous
  )
  .ms_knb_atomic_write_raw(
    .ms_knb_json_bytes(manifest),
    manifest_path
  )

  if (isTRUE(dry_run)) {
    result <- list(
      status = "dry_run",
      package_id = plan$package_id,
      series_id = plan$series_id,
      resource_map_pid = plan$resource_map_pid,
      manifest_path = normalizePath(manifest_path, mustWork = TRUE),
      resource_map_path = normalizePath(
        plan$resource_map_path,
        mustWork = TRUE
      ),
      sdp_archive_path = .ms_knb_result_archive_path(plan),
      representation = plan$representation,
      manifest = manifest
    )
    cli::cli_alert_success(
      "KNB dry-run manifest written to {.path {result$manifest_path}}"
    )
    return(invisible(result))
  }

  # The live state machine is implemented below this pure planning boundary.
  adapter <- .ms_knb_adapter()
  .ms_knb_run_publication(
    plan,
    manifest,
    manifest_path,
    adapter,
    previous_status = if (is.null(previous)) {
      NA_character_
    } else {
      as.character(previous$status)
    }
  )
}
