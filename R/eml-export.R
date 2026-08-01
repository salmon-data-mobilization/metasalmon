# EML export ---------------------------------------------------------------
#
# EML is deliberately a reviewed, derived representation of a Salmon Data
# Package (SDP). `create_sdp()` produces a review-ready package; this exporter
# starts only after the package passes strict semantic validation and a human
# has supplied the EML-specific facts that cannot be inferred safely.

.ms_eml_version <- "2.2.0"
.ms_eml_namespace <- "https://eml.ecoinformatics.org/eml-2.2.0"
.ms_eml_format_id <- .ms_eml_namespace
.ms_eml_system <- "knb"
.ms_eml_url_namespace_uuid <- "6ba7b811-9dad-11d1-80b4-00c04fd430c8"
.ms_eml_knb_object_endpoint <-
  "https://knb.ecoinformatics.org/knb/d1/mn/v2/object/"

.ms_eml_knb_object_url <- function(pid) {
  # Keep the URN colons literal: MetacatUI matches an EML distribution to its
  # DataONE object by finding the unescaped PID as a substring of this URL.
  encoded_pid <- utils::URLencode(pid, reserved = TRUE)
  encoded_pid <- gsub("%3A", ":", encoded_pid, fixed = TRUE)
  paste0(
    .ms_eml_knb_object_endpoint,
    encoded_pid
  )
}

.ms_eml_measurement_predicates <- c(
  variable_topic = "http://purl.org/dc/terms/subject",
  unit = "http://qudt.org/schema/qudt/hasUnit"
)

.ms_eml_measurement_term_annotation <- function(dictionary_row,
                                                vocabulary = NULL) {
  term_type <- tolower(trimws(as.character(
    dictionary_row$term_type[[1]] %||% ""
  )))
  if (!term_type %in% c("owl_class", "skos_concept")) {
    cli::cli_abort(
      "EML export requires measurement {.field term_type} to be {.val owl_class} or {.val skos_concept}; found {.val {term_type}}."
    )
  }

  if (!is.null(vocabulary)) {
    term_iri <- trimws(as.character(dictionary_row$term_iri[[1]]))
    vocabulary_row <- vocabulary[
      !is.na(vocabulary$iri) & vocabulary$iri == term_iri,
      ,
      drop = FALSE
    ]
    if (nrow(vocabulary_row) != 1L) {
      cli::cli_abort(
        "Reviewed vocabulary evidence for measurement term {.url {term_iri}} is missing or duplicated."
      )
    }
    type_evidence <- tolower(paste(
      vocabulary_row$native_type[[1]] %||% "",
      vocabulary_row$resource_kind[[1]] %||% "",
      vocabulary_row$type_iris[[1]] %||% ""
    ))
    evidence_is_skos <- grepl("skos[:/#].*concept|\\bconcept\\b", type_evidence)
    evidence_is_owl <- grepl("owl[:/#].*class|\\bclass\\b", type_evidence)
    if (
      (identical(term_type, "skos_concept") && !evidence_is_skos) ||
        (identical(term_type, "owl_class") && !evidence_is_owl) ||
        (evidence_is_skos && evidence_is_owl)
    ) {
      cli::cli_abort(
        "Measurement {.field term_type} for {.url {term_iri}} conflicts with reviewed vocabulary native-type evidence."
      )
    }
  }

  list(
    iri = unname(.ms_eml_measurement_predicates[["variable_topic"]]),
    label = "Subject"
  )
}

.ms_eml_nonempty <- function(x) {
  if (is.null(x) || length(x) == 0L || is.na(x[[1]])) {
    return(FALSE)
  }
  nzchar(trimws(as.character(x[[1]])))
}

.ms_eml_scalar <- function(x, field, required = TRUE) {
  value <- x[[field]]
  if (!.ms_eml_nonempty(value)) {
    if (isTRUE(required)) {
      cli::cli_abort(
        "EML mapping field {.field {field}} must contain one non-empty value."
      )
    }
    return(NA_character_)
  }
  if (length(value) != 1L) {
    cli::cli_abort(
      "EML mapping field {.field {field}} must contain exactly one value."
    )
  }
  trimws(as.character(value[[1]]))
}

.ms_eml_revision_key <- function(mapping, required = FALSE) {
  if (length(required) != 1L || !is.logical(required) || is.na(required)) {
    cli::cli_abort(
      "Internal EML export argument {.arg required} must be one logical value."
    )
  }

  key <- .ms_eml_scalar(
    mapping$publication,
    "revision_key",
    required = required
  )
  if (is.na(key)) {
    return(NA_character_)
  }
  if (nchar(key, type = "bytes") > 128L ||
      !grepl("^[A-Za-z0-9][A-Za-z0-9._-]*$", key)) {
    cli::cli_abort(
      "EML mapping {.field publication.revision_key} must be 1-128 ASCII letters, numbers, periods, underscores, or hyphens, starting with a letter or number."
    )
  }
  key
}

.ms_eml_split_iris <- function(x) {
  if (is.null(x) || length(x) == 0L) {
    return(character())
  }
  values <- unlist(strsplit(as.character(x), ";", fixed = TRUE), use.names = FALSE)
  values <- trimws(values)
  unique(values[!is.na(values) & nzchar(values)])
}

.ms_eml_uuid_raw <- function(uuid) {
  hex <- gsub("-", "", tolower(uuid), fixed = TRUE)
  if (!grepl("^[0-9a-f]{32}$", hex)) {
    cli::cli_abort("Internal UUID namespace {.val {uuid}} is invalid.")
  }
  as.raw(strtoi(substring(hex, seq(1L, 31L, 2L), seq(2L, 32L, 2L)), 16L))
}

.ms_eml_uuid5 <- function(name,
                          namespace = .ms_eml_url_namespace_uuid) {
  if (!.ms_eml_nonempty(name)) {
    cli::cli_abort("A non-empty name is required to construct a UUIDv5.")
  }

  namespace_raw <- .ms_eml_uuid_raw(namespace)
  name_raw <- charToRaw(enc2utf8(as.character(name[[1]])))
  hash <- digest::digest(
    c(namespace_raw, name_raw),
    algo = "sha1",
    serialize = FALSE,
    raw = TRUE
  )[seq_len(16L)]

  # RFC 9562 UUIDv5: version is 0101 and the variant is 10xx.
  hash[[7]] <- as.raw(bitwOr(bitwAnd(as.integer(hash[[7]]), 0x0fL), 0x50L))
  hash[[9]] <- as.raw(bitwOr(bitwAnd(as.integer(hash[[9]]), 0x3fL), 0x80L))
  hex <- paste(sprintf("%02x", as.integer(hash)), collapse = "")

  paste(
    substr(hex, 1L, 8L),
    substr(hex, 9L, 12L),
    substr(hex, 13L, 16L),
    substr(hex, 17L, 20L),
    substr(hex, 21L, 32L),
    sep = "-"
  )
}

.ms_eml_id <- function(prefix, name) {
  paste0(prefix, "-", gsub("-", "", .ms_eml_uuid5(name), fixed = TRUE))
}

.ms_eml_attribute_id <- function(dataset_id, table_id, column_name) {
  .ms_eml_id(
    "attribute",
    paste(dataset_id, table_id, column_name, sep = ":")
  )
}

.ms_eml_add_text <- function(parent, name, value, attrs = NULL) {
  if (!.ms_eml_nonempty(value)) {
    return(invisible(NULL))
  }
  node <- xml2::xml_add_child(parent, name)
  xml2::xml_set_text(node, as.character(value[[1]]))
  if (!is.null(attrs) && length(attrs) > 0L) {
    xml2::xml_set_attrs(node, attrs)
  }
  invisible(node)
}

.ms_eml_add_para <- function(parent, name, value) {
  if (!.ms_eml_nonempty(value)) {
    return(invisible(NULL))
  }
  node <- xml2::xml_add_child(parent, name)
  .ms_eml_add_text(node, "para", value)
  invisible(node)
}

.ms_eml_add_party <- function(parent,
                              element,
                              party,
                              id_name) {
  if (!is.list(party)) {
    cli::cli_abort(
      "Each {.field {element}} entry in the EML mapping must be a mapping."
    )
  }

  surname <- .ms_eml_scalar(party, "surname", required = FALSE)
  given_name <- .ms_eml_scalar(party, "given_name", required = FALSE)
  organization <- .ms_eml_scalar(
    party,
    "organization_name",
    required = FALSE
  )
  position <- .ms_eml_scalar(party, "position_name", required = FALSE)

  has_individual <- .ms_eml_nonempty(surname)
  if (.ms_eml_nonempty(given_name) && !has_individual) {
    cli::cli_abort(
      "An EML party with {.field given_name} must also provide {.field surname}."
    )
  }
  if (!has_individual &&
      !.ms_eml_nonempty(organization) &&
      !.ms_eml_nonempty(position)) {
    cli::cli_abort(
      "Each EML party must provide {.field surname}, {.field organization_name}, or {.field position_name}."
    )
  }

  node <- xml2::xml_add_child(parent, element)
  xml2::xml_set_attr(node, "id", .ms_eml_id("party", id_name))

  if (has_individual) {
    individual <- xml2::xml_add_child(node, "individualName")
    .ms_eml_add_text(individual, "givenName", given_name)
    .ms_eml_add_text(individual, "surName", surname)
  }
  .ms_eml_add_text(node, "organizationName", organization)
  .ms_eml_add_text(node, "positionName", position)

  email <- party$email
  if (!is.null(email)) {
    for (value in as.character(unlist(email, use.names = FALSE))) {
      .ms_eml_add_text(node, "electronicMailAddress", value)
    }
  }

  orcid <- .ms_eml_scalar(party, "orcid", required = FALSE)
  if (.ms_eml_nonempty(orcid)) {
    if (!grepl(
      "^https://orcid\\.org/[0-9]{4}-[0-9]{4}-[0-9]{4}-[0-9]{3}[0-9X]$",
      orcid
    )) {
      cli::cli_abort(
        "EML party {.field orcid} must be a full https://orcid.org/ URI."
      )
    }
    .ms_eml_add_text(
      node,
      "userId",
      orcid,
      attrs = c(directory = "https://orcid.org")
    )
  }

  invisible(node)
}

.ms_eml_default_mapping_path <- function(path) {
  yml <- file.path(path, "metadata", "eml-mapping.yml")
  yaml <- file.path(path, "metadata", "eml-mapping.yaml")
  if (file.exists(yml) && file.exists(yaml)) {
    cli::cli_abort(
      "Both {.file eml-mapping.yml} and {.file eml-mapping.yaml} exist. Keep one canonical sidecar; {.file eml-mapping.yml} is the default."
    )
  }
  yml
}

.ms_eml_attribute_configs <- function(mapping, dictionary) {
  tables <- mapping$tables
  if (!is.list(tables) || is.null(names(tables))) {
    cli::cli_abort(
      "EML mapping {.field tables} must be keyed by table ID."
    )
  }

  expected_tables <- unique(as.character(dictionary$table_id))
  actual_tables <- names(tables)
  if (!setequal(expected_tables, actual_tables)) {
    cli::cli_abort(c(
      "EML mapping {.field tables} must describe exactly the SDP tables.",
      "i" = "Expected: {.val {sort(expected_tables)}}.",
      "i" = "Found: {.val {sort(actual_tables)}}."
    ))
  }

  configs <- vector("list", nrow(dictionary))
  for (i in seq_len(nrow(dictionary))) {
    table_id <- as.character(dictionary$table_id[[i]])
    column_name <- as.character(dictionary$column_name[[i]])
    table_entry <- tables[[table_id]]
    if (!is.list(table_entry)) {
      cli::cli_abort(
        "EML mapping {.field tables.{table_id}} must be a mapping."
      )
    }
    table_mapping <- table_entry$attributes
    if (!is.list(table_mapping) || is.null(names(table_mapping))) {
      cli::cli_abort(
        "EML mapping {.field tables.{table_id}.attributes} must be keyed by column name."
      )
    }

    expected_columns <- as.character(
      dictionary$column_name[dictionary$table_id == table_id]
    )
    if (!setequal(expected_columns, names(table_mapping))) {
      cli::cli_abort(c(
        "EML mapping {.field tables.{table_id}.attributes} must describe exactly the SDP columns.",
        "i" = "Expected: {.val {sort(expected_columns)}}.",
        "i" = "Found: {.val {sort(names(table_mapping))}}."
      ))
    }

    config <- table_mapping[[column_name]]
    if (!is.list(config)) {
      cli::cli_abort(
        "EML mapping for {.field {table_id}.{column_name}} must be a mapping."
      )
    }
    configs[[i]] <- config
  }
  configs
}

.ms_eml_validate_mapping_schema <- function(mapping) {
  if (!requireNamespace("jsonvalidate", quietly = TRUE)) {
    cli::cli_abort(
      "Package {.pkg jsonvalidate} is required to validate the EML mapping sidecar."
    )
  }
  schema <- system.file(
    "extdata",
    "schema",
    "eml-mapping.schema.json",
    package = "metasalmon"
  )
  if (!nzchar(schema)) {
    cli::cli_abort(
      "Could not locate the bundled EML mapping JSON Schema."
    )
  }

  # `jsonlite` cannot infer that a length-one character vector came from a YAML
  # sequence. Preserve this one explicitly array-valued field for validation.
  schema_value <- mapping
  schema_value$intellectual_rights$paragraphs <- as.list(
    schema_value$intellectual_rights$paragraphs
  )
  json <- jsonlite::toJSON(
    schema_value,
    auto_unbox = TRUE,
    null = "null",
    na = "null"
  )
  valid <- jsonvalidate::json_validate(
    json,
    schema,
    verbose = TRUE,
    greedy = TRUE,
    engine = "ajv"
  )
  if (!isTRUE(valid)) {
    errors <- attr(valid, "errors")
    detail <- if (is.null(errors)) {
      "Unknown JSON Schema validation error."
    } else {
      paste(utils::head(utils::capture.output(print(errors)), 12L), collapse = "\n")
    }
    cli::cli_abort(c(
      "EML mapping sidecar failed the bundled JSON Schema.",
      "x" = detail
    ))
  }
  invisible(TRUE)
}

.ms_eml_unit_crosswalk <- function() {
  path <- system.file(
    "extdata",
    "eml-unit-crosswalk.csv",
    package = "metasalmon"
  )
  if (!nzchar(path) || !file.exists(path)) {
    cli::cli_abort(
      "Could not locate the bundled reviewed EML unit crosswalk."
    )
  }
  crosswalk <- readr::read_csv(
    path,
    col_types = readr::cols(.default = readr::col_character()),
    show_col_types = FALSE
  )
  required <- c(
    "unit_iri",
    "eml_standard_unit",
    "review_status",
    "profile_version"
  )
  if (!identical(names(crosswalk), required) ||
      nrow(crosswalk) == 0L ||
      anyNA(crosswalk) ||
      any(!nzchar(trimws(as.matrix(crosswalk)))) ||
      any(crosswalk$review_status != "reviewed") ||
      anyDuplicated(crosswalk$unit_iri)) {
    cli::cli_abort(
      "The bundled EML unit crosswalk is malformed or contains unreviewed/duplicate entries."
    )
  }
  crosswalk
}

.ms_eml_validate_mapping <- function(mapping,
                                     pkg,
                                     require_final = TRUE) {
  if (!is.list(mapping)) {
    cli::cli_abort("The EML mapping sidecar must contain a YAML mapping.")
  }
  .ms_eml_validate_mapping_schema(mapping)
  if (!identical(as.integer(mapping$version), 1L)) {
    cli::cli_abort("EML mapping {.field version} must be 1.")
  }
  status <- .ms_eml_scalar(mapping, "status")
  if (isTRUE(require_final) && !identical(status, "final")) {
    cli::cli_abort(
      "EML mapping {.field status} must be {.val final} before export."
    )
  }

  dataset_id <- .ms_eml_scalar(mapping, "dataset_id")
  package_dataset_id <- trimws(as.character(pkg$dataset$dataset_id[[1]]))
  if (!identical(dataset_id, package_dataset_id)) {
    cli::cli_abort(
      "EML mapping {.field dataset_id} {.val {dataset_id}} does not match SDP dataset ID {.val {package_dataset_id}}."
    )
  }

  .ms_eml_scalar(mapping, "series_key")
  system <- .ms_eml_scalar(mapping, "system")
  if (!identical(system, .ms_eml_system)) {
    cli::cli_abort(
      "EML mapping {.field system} must be {.val {.ms_eml_system}} for the KNB publication profile."
    )
  }
  .ms_eml_scalar(mapping, "language")
  publication_date <- .ms_eml_scalar(mapping, "publication_date")
  if (!grepl("^[0-9]{4}(-[0-9]{2}-[0-9]{2})?$", publication_date)) {
    cli::cli_abort(
      "EML mapping {.field publication_date} must be YYYY or YYYY-MM-DD."
    )
  }
  if (is.na(as.Date(
    if (nchar(publication_date) == 4L) {
      paste0(publication_date, "-01-01")
    } else {
      publication_date
    }
  ))) {
    cli::cli_abort(
      "EML mapping {.field publication_date} is not a valid calendar date."
    )
  }

  if (!is.list(mapping$publisher)) {
    cli::cli_abort("EML mapping {.field publisher} must be a party mapping.")
  }
  rights <- mapping$intellectual_rights
  if (!is.list(rights) ||
      !is.character(rights$paragraphs) ||
      length(rights$paragraphs) == 0L ||
      anyNA(rights$paragraphs) ||
      any(!nzchar(trimws(rights$paragraphs)))) {
    cli::cli_abort(
      "EML mapping {.field intellectual_rights.paragraphs} must contain non-empty text."
    )
  }
  methods <- mapping$methods
  if (!is.list(methods) || length(methods) == 0L) {
    cli::cli_abort(
      "EML mapping {.field methods} must contain at least one method-step mapping."
    )
  }
  for (method in methods) {
    if (!is.list(method)) {
      cli::cli_abort("Each EML method step must be a mapping.")
    }
    .ms_eml_scalar(method, "description")
  }

  semantic_vocabulary <- mapping$semantic_vocabulary
  if (!is.list(semantic_vocabulary)) {
    cli::cli_abort(
      "EML mapping {.field semantic_vocabulary} must be a path/hash mapping."
    )
  }
  vocabulary_path <- .ms_eml_scalar(semantic_vocabulary, "path")
  if (!identical(vocabulary_path, "metadata/semantic_vocabulary.csv")) {
    cli::cli_abort(
      "EML mapping {.field semantic_vocabulary.path} must be {.file metadata/semantic_vocabulary.csv}."
    )
  }
  vocabulary_sha256 <- .ms_eml_scalar(semantic_vocabulary, "sha256")
  if (!grepl("^[0-9a-f]{64}$", vocabulary_sha256)) {
    cli::cli_abort(
      "EML mapping {.field semantic_vocabulary.sha256} must be a lowercase SHA-256 digest."
    )
  }

  semantic_review <- mapping$semantic_review
  if (!is.list(semantic_review)) {
    cli::cli_abort(
      "EML mapping {.field semantic_review} must be a path/hash mapping."
    )
  }
  review_path <- .ms_eml_scalar(semantic_review, "path")
  if (!identical(review_path, "reviewed_semantic_selections.csv")) {
    cli::cli_abort(
      "EML mapping {.field semantic_review.path} must be {.file reviewed_semantic_selections.csv}."
    )
  }
  review_sha256 <- .ms_eml_scalar(semantic_review, "sha256")
  if (!grepl("^[0-9a-f]{64}$", review_sha256)) {
    cli::cli_abort(
      "EML mapping {.field semantic_review.sha256} must be a lowercase SHA-256 digest."
    )
  }

  publication <- mapping$publication
  if (!is.list(publication) ||
      length(publication$public) != 1L ||
      !is.logical(publication$public) ||
      is.na(publication$public)) {
    cli::cli_abort(
      "EML mapping {.field publication.public} must be one explicit logical value."
    )
  }
  invisible(.ms_eml_revision_key(mapping))

  rights_authorization <- mapping$rights_authorization
  if (!is.list(rights_authorization) ||
      !.ms_eml_scalar(rights_authorization, "status") %in%
        c("unconfirmed", "confirmed")) {
    cli::cli_abort(
      "EML mapping {.field rights_authorization.status} must be {.val unconfirmed} or {.val confirmed}."
    )
  }
  .ms_eml_scalar(rights_authorization, "evidence")

  source_provenance <- mapping$source_provenance
  if (!is.list(source_provenance)) {
    cli::cli_abort(
      "EML mapping {.field source_provenance} must be a structured mapping."
    )
  }
  source_citation <- .ms_eml_scalar(
    source_provenance,
    "source_citation"
  )
  provenance_note <- .ms_eml_scalar(
    source_provenance,
    "provenance_note"
  )
  package_source_citation <- trimws(as.character(
    pkg$dataset$source_citation[[1]]
  ))
  package_provenance_note <- trimws(as.character(
    pkg$dataset$provenance_note[[1]]
  ))
  if (!identical(source_citation, package_source_citation)) {
    cli::cli_abort(
      "EML mapping {.field source_provenance.source_citation} does not match SDP {.field source_citation}."
    )
  }
  if (!identical(provenance_note, package_provenance_note)) {
    cli::cli_abort(
      "EML mapping {.field source_provenance.provenance_note} does not match SDP {.field provenance_note}."
    )
  }
  supporting_document <- source_provenance$supporting_document
  if (!is.list(supporting_document)) {
    cli::cli_abort(
      "EML mapping {.field source_provenance.supporting_document} must be a citation/URL/hash mapping."
    )
  }
  .ms_eml_scalar(supporting_document, "citation")
  supporting_url <- .ms_eml_scalar(supporting_document, "url")
  if (!grepl("^https?://", supporting_url)) {
    cli::cli_abort(
      "EML mapping {.field source_provenance.supporting_document.url} must be an HTTP(S) URL."
    )
  }
  supporting_sha256 <- .ms_eml_scalar(supporting_document, "sha256")
  if (!grepl("^[0-9a-f]{64}$", supporting_sha256)) {
    cli::cli_abort(
      "EML mapping {.field source_provenance.supporting_document.sha256} must be a lowercase SHA-256 digest."
    )
  }

  for (field in c("creators", "metadata_providers", "contacts")) {
    parties <- mapping[[field]]
    if (!is.list(parties) || length(parties) == 0L) {
      cli::cli_abort(
        "EML mapping {.field {field}} must contain at least one party."
      )
    }
  }

  geographic <- mapping$geographic_coverage
  if (!is.null(geographic)) {
    if (!is.list(geographic)) {
      cli::cli_abort(
        "EML mapping {.field geographic_coverage} must be a mapping."
      )
    }
    .ms_eml_scalar(geographic, "description")
    bounds <- c("west", "east", "south", "north")
    numeric_bounds <- vapply(bounds, function(field) {
      value <- suppressWarnings(as.numeric(geographic[[field]]))
      if (length(value) != 1L || is.na(value) || !is.finite(value)) {
        cli::cli_abort(
          "EML mapping {.field geographic_coverage.{field}} must be one finite number."
        )
      }
      value
    }, numeric(1))
    if (numeric_bounds[["west"]] > numeric_bounds[["east"]] ||
        numeric_bounds[["south"]] > numeric_bounds[["north"]] ||
        any(numeric_bounds[c("west", "east")] < -180) ||
        any(numeric_bounds[c("west", "east")] > 180) ||
        any(numeric_bounds[c("south", "north")] < -90) ||
        any(numeric_bounds[c("south", "north")] > 90)) {
      cli::cli_abort(
        "EML {.field geographic_coverage} bounds are out of range or reversed."
      )
    }
  }

  configs <- .ms_eml_attribute_configs(mapping, pkg$dictionary)
  valid_scales <- c("nominal", "ordinal", "interval", "ratio", "dateTime")
  valid_number_types <- c("natural", "whole", "integer", "real")
  unit_crosswalk <- .ms_eml_unit_crosswalk()

  for (i in seq_along(configs)) {
    config <- configs[[i]]
    field <- paste0(
      pkg$dictionary$table_id[[i]],
      ".",
      pkg$dictionary$column_name[[i]]
    )
    scale <- .ms_eml_scalar(config, "measurement_scale")
    if (!scale %in% valid_scales) {
      cli::cli_abort(
        "EML mapping {.field {field}.measurement_scale} must be one of {.val {valid_scales}}."
      )
    }

    if (scale %in% c("interval", "ratio")) {
      value_type <- as.character(pkg$dictionary$value_type[[i]])
      if (!value_type %in% c("integer", "number")) {
        cli::cli_abort(
          "EML {.val {scale}} scale for {.field {field}} requires SDP {.field value_type} {.val integer} or {.val number}, not {.val {value_type}}."
        )
      }
      unit <- .ms_eml_scalar(config, "eml_unit")
      unit_iri <- .ms_eml_scalar(
        as.list(pkg$dictionary[i, , drop = FALSE]),
        "unit_iri"
      )
      crosswalk_row <- unit_crosswalk[
        unit_crosswalk$unit_iri == unit_iri,
        ,
        drop = FALSE
      ]
      if (nrow(crosswalk_row) != 1L) {
        cli::cli_abort(c(
          "No reviewed EML standard-unit mapping exists for canonical unit IRI {.val {unit_iri}} on {.field {field}}.",
          "i" = "Add and review an exact crosswalk entry before extending the exporter."
        ))
      }
      expected_unit <- crosswalk_row$eml_standard_unit[[1]]
      if (!identical(unit, expected_unit)) {
        cli::cli_abort(
          "EML mapping {.field {field}.eml_unit} must be {.val {expected_unit}} for canonical unit IRI {.val {unit_iri}}, not {.val {unit}}."
        )
      }
      number_type <- .ms_eml_scalar(config, "number_type")
      if (!number_type %in% valid_number_types) {
        cli::cli_abort(
          "EML mapping {.field {field}.number_type} must be one of {.val {valid_number_types}}."
        )
      }

      minimum <- config$minimum
      maximum <- config$maximum
      has_minimum <- !is.null(minimum)
      has_maximum <- !is.null(maximum)
      if (has_minimum) {
        minimum <- suppressWarnings(as.numeric(minimum))
        if (length(minimum) != 1L ||
            is.na(minimum) ||
            !is.finite(minimum)) {
          cli::cli_abort(
            "EML mapping {.field {field}.minimum} must be one finite number."
          )
        }
      }
      if (has_maximum) {
        maximum <- suppressWarnings(as.numeric(maximum))
        if (length(maximum) != 1L ||
            is.na(maximum) ||
            !is.finite(maximum)) {
          cli::cli_abort(
            "EML mapping {.field {field}.maximum} must be one finite number."
          )
        }
      }
      for (bound in c("minimum", "maximum")) {
        exclusive_field <- paste0(bound, "_exclusive")
        exclusive <- config[[exclusive_field]]
        if (!is.null(exclusive) &&
            (length(exclusive) != 1L ||
              !is.logical(exclusive) ||
              is.na(exclusive))) {
          cli::cli_abort(
            "EML mapping {.field {field}.{exclusive_field}} must be one logical value."
          )
        }
        if (!is.null(exclusive) && is.null(config[[bound]])) {
          cli::cli_abort(
            "EML mapping {.field {field}.{exclusive_field}} requires {.field {field}.{bound}}."
          )
        }
      }
      if (has_minimum &&
          has_maximum &&
          (
            minimum > maximum ||
              (
                identical(minimum, maximum) &&
                  (
                    isTRUE(config$minimum_exclusive) ||
                      isTRUE(config$maximum_exclusive)
                  )
              )
          )) {
        cli::cli_abort(
          "EML mapping {.field {field}.minimum} must not exceed {.field {field}.maximum} or define an empty exclusive interval."
        )
      }
    }

    if (identical(scale, "dateTime")) {
      value_type <- as.character(pkg$dictionary$value_type[[i]])
      if (!value_type %in%
          c("string", "integer", "number", "date", "datetime")) {
        cli::cli_abort(
          "EML {.val dateTime} scale for {.field {field}} is incompatible with SDP {.field value_type} {.val {value_type}}."
        )
      }
      format_string <- .ms_eml_scalar(config, "format_string")
      if (!format_string %in% c("YYYY", "YYYY-MM-DD")) {
        cli::cli_abort(
          "EML mapping {.field {field}.format_string} must currently be {.val YYYY} or {.val YYYY-MM-DD} so actual values can be validated exactly."
        )
      }
    }

    if (!is.null(config$precision)) {
      precision <- suppressWarnings(as.numeric(config$precision))
      if (length(precision) != 1L || is.na(precision) || precision <= 0) {
        cli::cli_abort(
          "EML mapping {.field {field}.precision} must be a positive, evidence-backed measurement repeatability value."
        )
      }
    }
  }

  invisible(configs)
}

.ms_eml_canonical_measurement_iris <- function(dictionary) {
  measurement <- dictionary[
    !is.na(dictionary$column_role) &
      dictionary$column_role == "measurement",
    ,
    drop = FALSE
  ]
  fields <- c(
    "term_iri", "property_iri", "entity_iri",
    "constraint_iri", "method_iri", "unit_iri"
  )
  unique(unlist(
    lapply(fields, function(field) {
      .ms_eml_split_iris(measurement[[field]])
    }),
    use.names = FALSE
  ))
}

.ms_eml_canonical_review_targets <- function(pkg) {
  role_fields <- c(
    term_iri = "variable",
    property_iri = "property",
    entity_iri = "entity",
    constraint_iri = "constraint",
    method_iri = "method",
    unit_iri = "unit"
  )
  measurement <- pkg$dictionary[
    !is.na(pkg$dictionary$column_role) &
      pkg$dictionary$column_role == "measurement",
    ,
    drop = FALSE
  ]
  column_targets <- purrr::map_dfr(
    seq_len(nrow(measurement)),
    function(i) {
      purrr::map_dfr(names(role_fields), function(field) {
        iris <- .ms_eml_split_iris(measurement[[field]][[i]])
        if (length(iris) == 0L) {
          return(tibble::tibble())
        }
        tibble::tibble(
          dataset_id = as.character(measurement$dataset_id[[i]]),
          table_id = as.character(measurement$table_id[[i]]),
          column_name = as.character(measurement$column_name[[i]]),
          target_scope = "column",
          target_sdp_field = field,
          dictionary_role = unname(role_fields[[field]]),
          iri = iris
        )
      })
    }
  )

  table_targets <- purrr::map_dfr(seq_len(nrow(pkg$tables)), function(i) {
    iris <- .ms_eml_split_iris(pkg$tables$observation_unit_iri[[i]])
    if (length(iris) == 0L) {
      return(tibble::tibble())
    }
    tibble::tibble(
      dataset_id = as.character(pkg$tables$dataset_id[[i]]),
      table_id = as.character(pkg$tables$table_id[[i]]),
      column_name = "",
      target_scope = "table",
      target_sdp_field = "observation_unit_iri",
      dictionary_role = "entity",
      iri = iris
    )
  })

  dplyr::distinct(dplyr::bind_rows(table_targets, column_targets))
}

.ms_eml_read_semantic_review <- function(path, pkg, mapping) {
  review_path <- .ms_eml_resource_path(
    path,
    mapping$semantic_review$path
  )
  actual_sha256 <- digest::digest(
    file = review_path,
    algo = "sha256",
    serialize = FALSE
  )
  if (!identical(actual_sha256, mapping$semantic_review$sha256)) {
    cli::cli_abort(
      "The semantic-review ledger SHA-256 does not match the reviewed EML mapping sidecar."
    )
  }

  review <- readr::read_csv(
    review_path,
    col_types = readr::cols(.default = readr::col_character()),
    show_col_types = FALSE,
    progress = FALSE
  )
  required <- c(
    "dataset_id", "table_id", "column_name", "target_scope",
    "target_sdp_field", "dictionary_role", "decision", "confidence",
    "review_rationale", "iri"
  )
  missing <- setdiff(required, names(review))
  if (length(missing) > 0L) {
    cli::cli_abort(
      "The semantic-review ledger is missing required column{?s}: {.field {missing}}."
    )
  }
  review[required] <- lapply(review[required], function(values) {
    values <- trimws(as.character(values))
    values[is.na(values)] <- ""
    values
  })
  nonempty_fields <- setdiff(required, "column_name")
  if (any(!nzchar(as.matrix(review[nonempty_fields])))) {
    cli::cli_abort(
      "The semantic-review ledger must provide non-empty target, decision, and IRI fields on every row."
    )
  }

  expected <- .ms_eml_canonical_review_targets(pkg)
  unresolved_rows <- review[review$decision != "accepted", , drop = FALSE]
  if (nrow(unresolved_rows) > 0L) {
    unresolved_labels <- unique(paste0(
      unresolved_rows$table_id,
      ifelse(
        nzchar(unresolved_rows$column_name),
        paste0(".", unresolved_rows$column_name),
        ""
      ),
      ".",
      unresolved_rows$target_sdp_field
    ))
    cli::cli_abort(
      "The semantic-review ledger contains non-accepted decision {.val {unique(unresolved_rows$decision)}} for target(s) {.field {unresolved_labels}}; a final ledger must contain accepted decisions only."
    )
  }

  target_fields <- c(
    "dataset_id", "table_id", "column_name", "target_scope",
    "target_sdp_field", "dictionary_role", "iri"
  )
  target_key <- function(data) {
    do.call(
      paste,
      c(unname(data[target_fields]), list(sep = "\r"))
    )
  }
  expected_keys <- target_key(expected)
  review_keys <- target_key(review)

  for (i in seq_len(nrow(expected))) {
    target <- expected[i, , drop = FALSE]
    matches <- review[
      review$dataset_id == target$dataset_id[[1]] &
        review$table_id == target$table_id[[1]] &
        review$column_name == target$column_name[[1]] &
        review$target_scope == target$target_scope[[1]] &
        review$target_sdp_field == target$target_sdp_field[[1]] &
        review$dictionary_role == target$dictionary_role[[1]] &
        review$iri == target$iri[[1]],
      ,
      drop = FALSE
    ]
    unresolved <- unique(matches$decision[matches$decision != "accepted"])
    target_label <- paste0(
      target$table_id[[1]],
      if (nzchar(target$column_name[[1]])) {
        paste0(".", target$column_name[[1]])
      } else {
        ""
      },
      ".",
      target$target_sdp_field[[1]]
    )
    if (length(unresolved) > 0L) {
      cli::cli_abort(
        "The semantic-review ledger contains unresolved decision {.val {unresolved}} for required semantic target {.field {target_label}} and IRI {.url {target$iri[[1]]}}."
      )
    }
    if (nrow(matches) != 1L ||
        !identical(matches$decision[[1]], "accepted")) {
      cli::cli_abort(
        "The semantic-review ledger must contain exactly one accepted row for required semantic target {.field {target_label}} and IRI {.url {target$iri[[1]]}}."
      )
    }
  }

  unexpected <- unique(review_keys[!review_keys %in% expected_keys])
  if (length(unexpected) > 0L ||
      nrow(review) != nrow(expected) ||
      anyDuplicated(review_keys)) {
    unexpected_rows <- review[review_keys %in% unexpected, , drop = FALSE]
    unexpected_labels <- if (nrow(unexpected_rows) > 0L) {
      unique(paste0(
        unexpected_rows$table_id,
        ifelse(
          nzchar(unexpected_rows$column_name),
          paste0(".", unexpected_rows$column_name),
          ""
        ),
        ".",
        unexpected_rows$target_sdp_field,
        "=",
        unexpected_rows$iri
      ))
    } else {
      "duplicate canonical target rows"
    }
    cli::cli_abort(c(
      "The final semantic-review ledger must equal the canonical non-empty table and measurement semantic target set exactly.",
      "x" = "Unexpected or duplicate row(s): {.val {unexpected_labels}}."
    ))
  }
  review
}

.ms_eml_vocabulary_snapshot_sha256 <- function(row) {
  fields <- c(
    "iri",
    "label",
    "definition",
    "source",
    "ontology",
    "resource_kind",
    "type_iris",
    "native_type",
    "source_url",
    "source_artifact_sha256"
  )
  missing <- setdiff(fields, names(row))
  if (length(missing) > 0L) {
    cli::cli_abort(
      "Cannot hash reviewed vocabulary snapshot; missing field{?s}: {.field {missing}}."
    )
  }
  values <- vapply(fields, function(field) {
    value <- row[[field]][[1]]
    if (length(value) == 0L || is.null(value) || is.na(value)) {
      return("")
    }
    as.character(value)
  }, character(1))
  digest::digest(
    paste(values, collapse = "\r"),
    algo = "sha256",
    serialize = FALSE
  )
}

.ms_eml_read_vocabulary <- function(path, dictionary, mapping) {
  vocabulary_path <- .ms_eml_resource_path(
    path,
    mapping$semantic_vocabulary$path
  )
  if (!file.exists(vocabulary_path)) {
    cli::cli_abort(
      "Required reviewed vocabulary file {.path {vocabulary_path}} does not exist."
    )
  }

  vocabulary <- readr::read_csv(
    vocabulary_path,
    col_types = readr::cols(.default = readr::col_character()),
    show_col_types = FALSE,
    progress = FALSE
  )
  required <- c(
    "iri", "label", "definition", "source", "ontology", "resource_kind",
    "type_iris", "native_type", "source_url", "source_artifact_sha256",
    "reviewed_snapshot_sha256"
  )
  missing <- setdiff(required, names(vocabulary))
  if (length(missing) > 0L) {
    cli::cli_abort(
      "{.file semantic_vocabulary.csv} is missing required column{?s}: {.field {missing}}."
    )
  }

  vocabulary$iri <- trimws(as.character(vocabulary$iri))
  vocabulary$label <- trimws(as.character(vocabulary$label))
  if (anyNA(vocabulary$iri) ||
      any(!nzchar(vocabulary$iri)) ||
      anyDuplicated(vocabulary$iri)) {
    cli::cli_abort(
      "{.file semantic_vocabulary.csv} must contain one unique, non-empty row per IRI."
    )
  }
  if (anyNA(vocabulary$label) || any(!nzchar(vocabulary$label))) {
    cli::cli_abort(
      "{.file semantic_vocabulary.csv} must provide a non-empty label for every IRI."
    )
  }
  evidence_fields <- c(
    "definition",
    "source",
    "ontology",
    "resource_kind",
    "native_type",
    "source_url",
    "reviewed_snapshot_sha256"
  )
  for (field in evidence_fields) {
    values <- trimws(as.character(vocabulary[[field]]))
    if (anyNA(values) || any(!nzchar(values))) {
      cli::cli_abort(
        "{.file semantic_vocabulary.csv} must provide non-empty {.field {field}} evidence for every IRI."
      )
    }
  }
  if (any(!grepl("^https?://", vocabulary$source_url))) {
    cli::cli_abort(
      "{.file semantic_vocabulary.csv} {.field source_url} values must be HTTP(S) URLs."
    )
  }
  source_artifact_sha256 <- trimws(as.character(
    vocabulary$source_artifact_sha256
  ))
  source_artifact_sha256[
    is.na(source_artifact_sha256)
  ] <- ""
  if (any(
    nzchar(source_artifact_sha256) &
      !grepl("^[0-9a-f]{64}$", source_artifact_sha256)
  )) {
    cli::cli_abort(
      "{.file semantic_vocabulary.csv} non-empty {.field source_artifact_sha256} values must be lowercase SHA-256 digests."
    )
  }
  reviewed_snapshot_sha256 <- trimws(as.character(
    vocabulary$reviewed_snapshot_sha256
  ))
  if (any(!grepl("^[0-9a-f]{64}$", reviewed_snapshot_sha256))) {
    cli::cli_abort(
      "{.file semantic_vocabulary.csv} {.field reviewed_snapshot_sha256} values must be lowercase SHA-256 digests."
    )
  }
  expected_snapshot_sha256 <- vapply(
    seq_len(nrow(vocabulary)),
    function(row_number) {
      .ms_eml_vocabulary_snapshot_sha256(
        vocabulary[row_number, , drop = FALSE]
      )
    },
    character(1)
  )
  if (!identical(reviewed_snapshot_sha256, expected_snapshot_sha256)) {
    cli::cli_abort(
      "{.file semantic_vocabulary.csv} contains a reviewed vocabulary snapshot hash that does not match its row."
    )
  }
  actual_sha256 <- digest::digest(
    file = vocabulary_path,
    algo = "sha256",
    serialize = FALSE
  )
  if (!identical(actual_sha256, mapping$semantic_vocabulary$sha256)) {
    cli::cli_abort(
      "{.file semantic_vocabulary.csv} SHA-256 does not match the reviewed EML mapping sidecar."
    )
  }

  expected <- sort(.ms_eml_canonical_measurement_iris(dictionary))
  actual <- sort(unique(vocabulary$iri))
  if (!identical(expected, actual)) {
    cli::cli_abort(c(
      "{.file semantic_vocabulary.csv} must describe exactly the canonical measurement IRI set.",
      "i" = "Missing: {.val {setdiff(expected, actual)}}.",
      "i" = "Unexpected: {.val {setdiff(actual, expected)}}."
    ))
  }
  vocabulary
}

.ms_eml_vocabulary_label <- function(vocabulary, iri) {
  label <- vocabulary$label[match(iri, vocabulary$iri)]
  if (length(label) != 1L || is.na(label) || !nzchar(label)) {
    cli::cli_abort(
      "No reviewed vocabulary label exists for canonical IRI {.url {iri}}."
    )
  }
  label
}

.ms_eml_resource_path <- function(package_path, file_name) {
  package_root <- normalizePath(package_path, mustWork = TRUE)
  candidate <- file.path(package_root, file_name)
  if (!file.exists(candidate)) {
    cli::cli_abort("SDP data object {.path {candidate}} does not exist.")
  }
  resolved <- normalizePath(candidate, mustWork = TRUE)
  prefix <- paste0(package_root, .Platform$file.sep)
  if (!startsWith(resolved, prefix)) {
    cli::cli_abort(
      "SDP resource {.path {file_name}} resolves outside the package directory."
    )
  }
  resolved
}

.ms_eml_data_objects <- function(path, pkg, mapping) {
  purrr::map_dfr(seq_len(nrow(pkg$tables)), function(i) {
    row <- pkg$tables[i, , drop = FALSE]
    table_id <- as.character(row$table_id[[1]])
    file_name <- as.character(row$file_name[[1]])
    file_path <- .ms_eml_resource_path(path, file_name)
    checksum <- digest::digest(
      file = file_path,
      algo = "sha256",
      serialize = FALSE
    )
    pid <- paste0(
      "urn:uuid:",
      .ms_eml_uuid5(paste(
        "data",
        mapping$dataset_id,
        table_id,
        basename(file_name),
        checksum,
        sep = ":"
      ))
    )
    tibble::tibble(
      table_id = table_id,
      file_name = file_name,
      path = file_path,
      pid = pid,
      format_id = "text/csv",
      checksum_algorithm = "SHA-256",
      checksum = checksum,
      size = unname(file.info(file_path)$size)
    )
  })
}

.ms_eml_empty_supplementary_objects <- function() {
  tibble::tibble(
    path = character(),
    pid = character(),
    format_id = character(),
    checksum_algorithm = character(),
    checksum = character(),
    size = numeric(),
    object_name = character(),
    entity_name = character(),
    description = character(),
    online_url = character()
  )
}

.ms_eml_supplementary_objects <- function(objects) {
  if (is.null(objects)) {
    return(.ms_eml_empty_supplementary_objects())
  }
  if (!is.data.frame(objects)) {
    cli::cli_abort(
      "{.arg supplementary_objects} must be a data frame with one row per supplementary object."
    )
  }
  if (nrow(objects) == 0L) {
    return(.ms_eml_empty_supplementary_objects())
  }

  required <- c(
    "path", "pid", "format_id", "checksum", "object_name",
    "entity_name", "description"
  )
  allowed <- c(required, "size")
  missing <- setdiff(required, names(objects))
  unexpected <- setdiff(names(objects), allowed)
  if (length(missing) > 0L) {
    cli::cli_abort(
      "{.arg supplementary_objects} is missing required column{?s}: {.field {missing}}."
    )
  }
  if (length(unexpected) > 0L) {
    cli::cli_abort(
      "{.arg supplementary_objects} has unexpected column{?s}: {.field {unexpected}}."
    )
  }

  values <- lapply(required, function(field) {
    column <- objects[[field]]
    if (!is.atomic(column) || length(column) != nrow(objects)) {
      cli::cli_abort(
        "Supplementary-object {.field {field}} must be one atomic value per row."
      )
    }
    trimws(as.character(column))
  })
  names(values) <- required
  if (any(vapply(values, function(value) {
    anyNA(value) || any(!nzchar(value)) || any(grepl("[[:cntrl:]]", value))
  }, logical(1)))) {
    cli::cli_abort(
      "Every required supplementary-object field must contain a non-empty value without control characters."
    )
  }

  if (any(!grepl("^[A-Za-z][A-Za-z0-9+.-]*:[^[:space:]]+$", values$pid))) {
    cli::cli_abort(
      "Every supplementary-object {.field pid} must be an absolute URI without whitespace."
    )
  }
  if (any(values$format_id != "application/zip")) {
    cli::cli_abort(
      "Canonical SDP supplementary objects must use {.val application/zip} as {.field format_id}."
    )
  }
  if (any(!grepl("^[0-9a-f]{64}$", values$checksum))) {
    cli::cli_abort(
      "Every supplementary-object {.field checksum} must be a lowercase SHA-256 digest."
    )
  }
  unsafe_name <- grepl("[/\\\\]", values$object_name) |
    values$object_name %in% c(".", "..") |
    !grepl("\\.zip$", values$object_name, ignore.case = TRUE)
  if (any(unsafe_name)) {
    cli::cli_abort(
      "Every supplementary-object {.field object_name} must be a basename ending in {.file .zip}."
    )
  }
  if (anyDuplicated(values$pid) || anyDuplicated(values$object_name)) {
    cli::cli_abort(
      "Supplementary-object {.field pid} and {.field object_name} values must each be unique."
    )
  }

  paths <- vapply(values$path, function(candidate) {
    candidate <- path.expand(candidate)
    if (!file.exists(candidate) || isTRUE(file.info(candidate)$isdir)) {
      cli::cli_abort(
        "Supplementary object {.path {candidate}} is not a readable file."
      )
    }
    normalizePath(candidate, mustWork = TRUE)
  }, character(1), USE.NAMES = FALSE)
  actual_sizes <- unname(file.info(paths)$size)
  if (anyNA(actual_sizes) || any(!is.finite(actual_sizes))) {
    cli::cli_abort("Could not determine supplementary-object file size.")
  }
  if ("size" %in% names(objects)) {
    if (!is.atomic(objects$size) || length(objects$size) != nrow(objects)) {
      cli::cli_abort(
        "Supplementary-object {.field size} must be one atomic value per row."
      )
    }
    supplied_sizes <- suppressWarnings(as.numeric(objects$size))
    invalid_size <- is.na(supplied_sizes) |
      !is.finite(supplied_sizes) |
      supplied_sizes < 0 |
      supplied_sizes != floor(supplied_sizes)
    if (any(invalid_size) || any(supplied_sizes != actual_sizes)) {
      cli::cli_abort(
        "Supplementary-object {.field size} must exactly match the file size in bytes."
      )
    }
  }

  actual_checksums <- vapply(paths, function(file_path) {
    digest::digest(
      file = file_path,
      algo = "sha256",
      serialize = FALSE
    )
  }, character(1), USE.NAMES = FALSE)
  checksum_mismatch <- actual_checksums != unname(values$checksum)
  if (any(checksum_mismatch)) {
    mismatched <- values$object_name[checksum_mismatch]
    cli::cli_abort(
      "Supplementary-object SHA-256 does not match file bytes for {.file {mismatched}}."
    )
  }

  tibble::tibble(
    path = paths,
    pid = values$pid,
    format_id = values$format_id,
    checksum_algorithm = "SHA-256",
    checksum = values$checksum,
    size = actual_sizes,
    object_name = values$object_name,
    entity_name = values$entity_name,
    description = values$description,
    online_url = .ms_eml_knb_object_url(values$pid)
  ) |>
    dplyr::arrange(.data$object_name, .data$pid)
}

.ms_eml_add_coverage <- function(dataset, dataset_meta, mapping) {
  temporal_start <- dataset_meta$temporal_start[[1]]
  temporal_end <- dataset_meta$temporal_end[[1]]
  geographic <- mapping$geographic_coverage
  has_geographic <- is.list(geographic)
  taxon <- mapping$taxonomic_coverage
  has_taxon <- is.list(taxon) &&
    .ms_eml_nonempty(taxon$scientific_name)

  if (!has_geographic &&
      !.ms_eml_nonempty(temporal_start) &&
      !.ms_eml_nonempty(temporal_end) &&
      !has_taxon) {
    return(invisible(NULL))
  }

  coverage <- xml2::xml_add_child(dataset, "coverage")
  if (has_geographic) {
    geographic <- xml2::xml_add_child(coverage, "geographicCoverage")
    .ms_eml_add_text(
      geographic,
      "geographicDescription",
      mapping$geographic_coverage$description
    )
    bounding <- xml2::xml_add_child(geographic, "boundingCoordinates")
    .ms_eml_add_text(
      bounding,
      "westBoundingCoordinate",
      as.character(mapping$geographic_coverage$west)
    )
    .ms_eml_add_text(
      bounding,
      "eastBoundingCoordinate",
      as.character(mapping$geographic_coverage$east)
    )
    .ms_eml_add_text(
      bounding,
      "northBoundingCoordinate",
      as.character(mapping$geographic_coverage$north)
    )
    .ms_eml_add_text(
      bounding,
      "southBoundingCoordinate",
      as.character(mapping$geographic_coverage$south)
    )
  }

  if (.ms_eml_nonempty(temporal_start) ||
      .ms_eml_nonempty(temporal_end)) {
    if (!.ms_eml_nonempty(temporal_start) ||
        !.ms_eml_nonempty(temporal_end)) {
      cli::cli_abort(
        "EML temporal coverage requires both {.field temporal_start} and {.field temporal_end}."
      )
    }
    temporal <- xml2::xml_add_child(coverage, "temporalCoverage")
    range <- xml2::xml_add_child(temporal, "rangeOfDates")
    begin <- xml2::xml_add_child(range, "beginDate")
    .ms_eml_add_text(begin, "calendarDate", as.character(temporal_start))
    end <- xml2::xml_add_child(range, "endDate")
    .ms_eml_add_text(end, "calendarDate", as.character(temporal_end))
  }

  if (has_taxon) {
    taxonomic <- xml2::xml_add_child(coverage, "taxonomicCoverage")
    classification <- xml2::xml_add_child(
      taxonomic,
      "taxonomicClassification"
    )
    .ms_eml_add_text(
      classification,
      "taxonRankName",
      .ms_eml_scalar(taxon, "rank", required = FALSE)
    )
    .ms_eml_add_text(
      classification,
      "taxonRankValue",
      .ms_eml_scalar(taxon, "scientific_name")
    )
    .ms_eml_add_text(
      classification,
      "commonName",
      .ms_eml_scalar(taxon, "common_name", required = FALSE)
    )
  }
  invisible(coverage)
}

.ms_eml_code_rows <- function(pkg, table_id, column_name) {
  if (is.null(pkg$codes) || nrow(pkg$codes) == 0L) {
    return(tibble::tibble())
  }
  pkg$codes[
    pkg$codes$table_id == table_id &
      pkg$codes$column_name == column_name,
    ,
    drop = FALSE
  ]
}

.ms_eml_add_non_numeric_domain <- function(scale_node,
                                           config,
                                           dictionary_row,
                                           pkg) {
  domain <- xml2::xml_add_child(scale_node, "nonNumericDomain")
  table_id <- as.character(dictionary_row$table_id[[1]])
  column_name <- as.character(dictionary_row$column_name[[1]])
  codes <- .ms_eml_code_rows(pkg, table_id, column_name)

  if (nrow(codes) == 0L) {
    text_domain <- xml2::xml_add_child(domain, "textDomain")
    .ms_eml_add_text(
      text_domain,
      "definition",
      paste0("Values documented by the ", column_name, " attribute definition.")
    )
    return(invisible(domain))
  }

  enumerated <- xml2::xml_add_child(domain, "enumeratedDomain")
  scale <- .ms_eml_scalar(config, "measurement_scale")
  order_map <- config$code_order
  if (identical(scale, "ordinal")) {
    if (is.null(order_map) || is.null(names(order_map))) {
      cli::cli_abort(
        "Ordinal EML attribute {.field {table_id}.{column_name}} requires named {.field code_order} values."
      )
    }
    code_values <- as.character(codes$code_value)
    if (!setequal(code_values, names(order_map))) {
      cli::cli_abort(
        "Ordinal {.field code_order} for {.field {table_id}.{column_name}} must name exactly the SDP code values."
      )
    }
  }

  for (i in seq_len(nrow(codes))) {
    value <- as.character(codes$code_value[[i]])
    label <- as.character(codes$code_label[[i]])
    description <- as.character(codes$code_description[[i]])
    definition <- if (.ms_eml_nonempty(description)) {
      description
    } else if (.ms_eml_nonempty(label)) {
      label
    } else {
      paste("Code value", value)
    }
    code <- xml2::xml_add_child(enumerated, "codeDefinition")
    if (identical(scale, "ordinal")) {
      order <- suppressWarnings(as.integer(order_map[[value]]))
      if (length(order) != 1L || is.na(order)) {
        cli::cli_abort(
          "Ordinal order for code {.val {value}} in {.field {table_id}.{column_name}} must be an integer."
        )
      }
      xml2::xml_set_attr(code, "order", as.character(order))
    }
    .ms_eml_add_text(code, "code", value)
    .ms_eml_add_text(code, "definition", definition)
    if (.ms_eml_nonempty(codes$vocabulary_iri[[i]])) {
      .ms_eml_add_text(code, "source", codes$vocabulary_iri[[i]])
    }
  }
  invisible(domain)
}

.ms_eml_add_measurement_scale <- function(attribute,
                                          config,
                                          dictionary_row,
                                          pkg) {
  measurement_scale <- xml2::xml_add_child(attribute, "measurementScale")
  scale <- .ms_eml_scalar(config, "measurement_scale")
  scale_node <- xml2::xml_add_child(measurement_scale, scale)

  if (scale %in% c("nominal", "ordinal")) {
    .ms_eml_add_non_numeric_domain(
      scale_node,
      config,
      dictionary_row,
      pkg
    )
  } else if (scale %in% c("interval", "ratio")) {
    unit <- xml2::xml_add_child(scale_node, "unit")
    .ms_eml_add_text(unit, "standardUnit", config$eml_unit)
    if (!is.null(config$precision)) {
      .ms_eml_add_text(scale_node, "precision", as.character(config$precision))
    }
    numeric_domain <- xml2::xml_add_child(scale_node, "numericDomain")
    .ms_eml_add_text(numeric_domain, "numberType", config$number_type)

    has_minimum <- !is.null(config$minimum) &&
      length(config$minimum) == 1L &&
      !is.na(config$minimum)
    has_maximum <- !is.null(config$maximum) &&
      length(config$maximum) == 1L &&
      !is.na(config$maximum)
    if (has_minimum || has_maximum) {
      bounds <- xml2::xml_add_child(numeric_domain, "bounds")
      if (has_minimum) {
        exclusive <- isTRUE(config$minimum_exclusive)
        .ms_eml_add_text(
          bounds,
          "minimum",
          as.character(config$minimum),
          attrs = c(exclusive = tolower(as.character(exclusive)))
        )
      }
      if (has_maximum) {
        exclusive <- isTRUE(config$maximum_exclusive)
        .ms_eml_add_text(
          bounds,
          "maximum",
          as.character(config$maximum),
          attrs = c(exclusive = tolower(as.character(exclusive)))
        )
      }
    }
  } else if (identical(scale, "dateTime")) {
    .ms_eml_add_text(scale_node, "formatString", config$format_string)
  }

  invisible(measurement_scale)
}

.ms_eml_missing_values <- function(config) {
  values <- config$missing_values
  if (is.null(values)) {
    return(list())
  }
  if (is.list(values) && .ms_eml_nonempty(values$code)) {
    values <- list(values)
  }
  if (!is.list(values)) {
    cli::cli_abort(
      "EML {.field missing_values} must be a list of code/explanation mappings."
    )
  }
  values
}

.ms_eml_read_raw_csv_tokens <- function(path, table_id) {
  raw <- readr::read_csv(
    path,
    col_types = readr::cols(.default = readr::col_character()),
    na = character(),
    trim_ws = FALSE,
    name_repair = "minimal",
    locale = readr::locale(encoding = "UTF-8"),
    progress = FALSE,
    show_col_types = FALSE
  )
  parse_problems <- readr::problems(raw)
  if (nrow(parse_problems) > 0L) {
    first <- parse_problems[1, , drop = FALSE]
    cli::cli_abort(c(
      "Could not audit the exact CSV tokens for EML table {.val {table_id}}.",
      "x" = "The first parse problem is at row {first$row[[1]]}, column {first$col[[1]]}: {first$expected[[1]]}."
    ))
  }
  raw
}

.ms_eml_validate_raw_table <- function(raw, parsed, table_id) {
  if (!identical(names(raw), names(parsed))) {
    cli::cli_abort(c(
      "Raw-token audit and parsed SDP table {.val {table_id}} have different columns.",
      "i" = "Raw CSV: {.field {names(raw)}}.",
      "i" = "Parsed SDP: {.field {names(parsed)}}."
    ))
  }
  if (!identical(nrow(raw), nrow(parsed))) {
    cli::cli_abort(
      "Raw-token audit found {nrow(raw)} row{?s} for EML table {.val {table_id}}, but the parsed SDP resource has {nrow(parsed)}."
    )
  }
  invisible(raw)
}

.ms_eml_add_missing_values <- function(attribute,
                                       config,
                                       parsed_values,
                                       raw_values,
                                       field) {
  values <- .ms_eml_missing_values(config)
  if (length(parsed_values) != length(raw_values)) {
    cli::cli_abort(
      "Internal EML export error: parsed and raw values differ in length for {.field {field}}."
    )
  }

  codes <- character()
  for (value in values) {
    if (!is.list(value)) {
      cli::cli_abort(
        "Each {.field missing_values} entry for {.field {field}} must be a mapping."
      )
    }
    code <- .ms_eml_scalar(value, "code")
    codes <- c(codes, code)
  }
  duplicates <- unique(codes[duplicated(codes)])
  if (length(duplicates) > 0L) {
    cli::cli_abort(
      "EML attribute {.field {field}} declares duplicate missing-value code{?s}: {.val {duplicates}}."
    )
  }

  absent <- setdiff(codes, unique(raw_values))
  if (length(absent) > 0L) {
    cli::cli_abort(
      "EML attribute {.field {field}} declares missing-value code{?s} {.val {absent}} that {?does/do} not occur in the raw CSV bytes."
    )
  }

  parsed_missing <- is.na(parsed_values)
  declared_but_present <- unique(
    raw_values[
      raw_values %in% codes &
        !parsed_missing
    ]
  )
  if (length(declared_but_present) > 0L) {
    cli::cli_abort(
      "EML attribute {.field {field}} declares missing-value code{?s} {.val {declared_but_present}} where the parsed value is not missing."
    )
  }
  undeclared <- unique(
    raw_values[
      parsed_missing &
        nzchar(raw_values) &
        !raw_values %in% codes
    ]
  )
  if (length(undeclared) > 0L) {
    cli::cli_abort(c(
      "EML attribute {.field {field}} contains undeclared non-empty missing token{?s}: {.val {undeclared}}.",
      "i" = "Empty CSV fields are treated as implicit absence and do not require a fabricated EML missing-value code."
    ))
  }

  for (value in values) {
    code <- .ms_eml_scalar(value, "code")
    explanation <- .ms_eml_scalar(value, "explanation")
    node <- xml2::xml_add_child(attribute, "missingValueCode")
    .ms_eml_add_text(node, "code", code)
    .ms_eml_add_text(node, "codeExplanation", explanation)
  }
  invisible(attribute)
}

.ms_eml_validate_observed_domain <- function(config,
                                             dictionary_row,
                                             parsed_values,
                                             raw_values,
                                             pkg,
                                             field) {
  scale <- .ms_eml_scalar(config, "measurement_scale")
  missing_codes <- vapply(
    .ms_eml_missing_values(config),
    function(value) .ms_eml_scalar(value, "code"),
    character(1)
  )
  observed_tokens <- nzchar(raw_values) & !raw_values %in% missing_codes

  if (scale %in% c("nominal", "ordinal")) {
    table_id <- as.character(dictionary_row$table_id[[1]])
    column_name <- as.character(dictionary_row$column_name[[1]])
    codes <- .ms_eml_code_rows(pkg, table_id, column_name)
    if (nrow(codes) > 0L) {
      code_values <- as.character(codes$code_value)
      exact_tokens <- unique(as.character(raw_values[observed_tokens]))
      undeclared <- setdiff(exact_tokens, code_values)
      if (length(undeclared) > 0L) {
        cli::cli_abort(c(
          "EML enumerated domain for {.field {field}} does not contain exact raw CSV token{?s}: {.val {undeclared}}.",
          "i" = "Code values are lexically significant after CSV parsing; leading or trailing whitespace must not be normalized silently."
        ))
      }
    }
  }

  if (scale %in% c("interval", "ratio")) {
    tokens <- raw_values[observed_tokens]
    numeric_values <- suppressWarnings(as.numeric(tokens))
    if (anyNA(numeric_values) || any(!is.finite(numeric_values))) {
      offending <- unique(tokens[is.na(numeric_values) |
        !is.finite(numeric_values)])
      cli::cli_abort(
        "EML numeric domain for {.field {field}} contains non-numeric or non-finite observed value{?s}: {.val {offending}}."
      )
    }

    number_type <- .ms_eml_scalar(config, "number_type")
    non_integer <- numeric_values != floor(numeric_values)
    if (number_type %in% c("natural", "whole", "integer") &&
        any(non_integer)) {
      offending <- unique(numeric_values[non_integer])
      cli::cli_abort(
        "EML {.val {number_type}} number type for {.field {field}} requires integer-valued observations, but found {.val {offending}}."
      )
    }
    if (identical(number_type, "natural") &&
        any(numeric_values <= 0)) {
      offending <- unique(numeric_values[numeric_values <= 0])
      cli::cli_abort(
        "EML {.val natural} number type for {.field {field}} requires strictly positive observations, but found {.val {offending}}."
      )
    }
    if (identical(number_type, "whole") &&
        any(numeric_values < 0)) {
      offending <- unique(numeric_values[numeric_values < 0])
      cli::cli_abort(
        "EML {.val whole} number type for {.field {field}} requires nonnegative observations, but found {.val {offending}}."
      )
    }

    if (!is.null(config$minimum)) {
      minimum <- as.numeric(config$minimum)
      violates <- if (isTRUE(config$minimum_exclusive)) {
        numeric_values <= minimum
      } else {
        numeric_values < minimum
      }
      if (any(violates)) {
        offending <- unique(numeric_values[violates])
        qualifier <- if (isTRUE(config$minimum_exclusive)) {
          "exclusive minimum"
        } else {
          "minimum"
        }
        cli::cli_abort(
          "EML numeric domain for {.field {field}} has observed value{?s} {.val {offending}} outside {qualifier} {.val {minimum}}."
        )
      }
    }
    if (!is.null(config$maximum)) {
      maximum <- as.numeric(config$maximum)
      violates <- if (isTRUE(config$maximum_exclusive)) {
        numeric_values >= maximum
      } else {
        numeric_values > maximum
      }
      if (any(violates)) {
        offending <- unique(numeric_values[violates])
        qualifier <- if (isTRUE(config$maximum_exclusive)) {
          "exclusive maximum"
        } else {
          "maximum"
        }
        cli::cli_abort(
          "EML numeric domain for {.field {field}} has observed value{?s} {.val {offending}} outside {qualifier} {.val {maximum}}."
        )
      }
    }
  }

  if (identical(scale, "dateTime")) {
    format_string <- .ms_eml_scalar(config, "format_string")
    tokens <- as.character(raw_values[observed_tokens])
    valid <- if (identical(format_string, "YYYY")) {
      grepl("^[0-9]{4}$", tokens)
    } else {
      syntactic <- grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", tokens)
      parsed_dates <- suppressWarnings(as.Date(tokens, format = "%Y-%m-%d"))
      syntactic &
        !is.na(parsed_dates) &
        format(parsed_dates, "%Y-%m-%d") == tokens
    }
    if (any(!valid)) {
      offending <- unique(tokens[!valid])
      cli::cli_abort(
        "EML {.field {field}.format_string} {.val {format_string}} does not match observed calendar value{?s} {.val {offending}}."
      )
    }
  }
  invisible(TRUE)
}

.ms_eml_add_annotation <- function(parent,
                                   predicate,
                                   predicate_label,
                                   value,
                                   value_label) {
  annotation <- xml2::xml_add_child(parent, "annotation")
  .ms_eml_add_text(
    annotation,
    "propertyURI",
    predicate,
    attrs = c(label = predicate_label)
  )
  .ms_eml_add_text(
    annotation,
    "valueURI",
    value,
    attrs = c(label = value_label)
  )
  invisible(annotation)
}

.ms_eml_add_attribute <- function(attribute_list,
                                  dictionary_row,
                                  config,
                                  data,
                                  raw_data,
                                  pkg,
                                  vocabulary,
                                  dataset_id) {
  table_id <- as.character(dictionary_row$table_id[[1]])
  column_name <- as.character(dictionary_row$column_name[[1]])
  field <- paste0(table_id, ".", column_name)
  attribute <- xml2::xml_add_child(attribute_list, "attribute")
  xml2::xml_set_attr(
    attribute,
    "id",
    .ms_eml_attribute_id(dataset_id, table_id, column_name)
  )
  .ms_eml_add_text(attribute, "attributeName", column_name)
  .ms_eml_add_text(
    attribute,
    "attributeLabel",
    dictionary_row$column_label[[1]]
  )
  .ms_eml_add_text(
    attribute,
    "attributeDefinition",
    dictionary_row$column_description[[1]]
  )

  storage_type <- c(
    string = "string",
    integer = "integer",
    number = "double",
    boolean = "boolean",
    date = "date",
    datetime = "dateTime"
  )[[as.character(dictionary_row$value_type[[1]])]]
  .ms_eml_add_text(attribute, "storageType", storage_type)
  .ms_eml_validate_observed_domain(
    config,
    dictionary_row,
    data[[column_name]],
    raw_data[[column_name]],
    pkg,
    field
  )
  .ms_eml_add_measurement_scale(attribute, config, dictionary_row, pkg)

  .ms_eml_add_missing_values(
    attribute,
    config,
    data[[column_name]],
    raw_data[[column_name]],
    field
  )

  if (identical(as.character(dictionary_row$column_role[[1]]), "measurement")) {
    term_iri <- as.character(dictionary_row$term_iri[[1]])
    unit_iri <- as.character(dictionary_row$unit_iri[[1]])
    term_annotation <- .ms_eml_measurement_term_annotation(
      dictionary_row,
      vocabulary
    )
    .ms_eml_add_annotation(
      attribute,
      term_annotation$iri,
      term_annotation$label,
      term_iri,
      .ms_eml_vocabulary_label(vocabulary, term_iri)
    )
    .ms_eml_add_annotation(
      attribute,
      .ms_eml_measurement_predicates[["unit"]],
      "has unit",
      unit_iri,
      .ms_eml_vocabulary_label(vocabulary, unit_iri)
    )
  }
  invisible(attribute)
}

.ms_eml_add_primary_key <- function(data_table,
                                    table_row,
                                    dictionary,
                                    dataset_id) {
  primary_key <- table_row$primary_key[[1]]
  if (!.ms_eml_nonempty(primary_key)) {
    return(invisible(NULL))
  }
  columns <- trimws(unlist(
    strsplit(as.character(primary_key), ",", fixed = TRUE),
    use.names = FALSE
  ))
  table_id <- as.character(table_row$table_id[[1]])
  known <- as.character(
    dictionary$column_name[dictionary$table_id == table_id]
  )
  unknown <- setdiff(columns, known)
  if (length(unknown) > 0L) {
    cli::cli_abort(
      "EML primary key for table {.val {table_id}} names unknown column{?s}: {.field {unknown}}."
    )
  }

  constraint <- xml2::xml_add_child(data_table, "constraint")
  key_node <- xml2::xml_add_child(constraint, "primaryKey")
  .ms_eml_add_text(
    key_node,
    "constraintName",
    paste0("PrimaryKey_", table_id)
  )
  key <- xml2::xml_add_child(key_node, "key")
  for (column in columns) {
    .ms_eml_add_text(
      key,
      "attributeReference",
      .ms_eml_attribute_id(dataset_id, table_id, column)
    )
  }
  invisible(constraint)
}

.ms_eml_add_not_null <- function(data_table,
                                 table_id,
                                 dictionary,
                                 dataset_id) {
  table_dictionary <- dictionary[
    dictionary$table_id == table_id,
    ,
    drop = FALSE
  ]
  required <- !is.na(table_dictionary$required) &
    table_dictionary$required
  columns <- as.character(table_dictionary$column_name[required])
  if (length(columns) == 0L) {
    return(invisible(NULL))
  }

  constraint <- xml2::xml_add_child(data_table, "constraint")
  not_null <- xml2::xml_add_child(constraint, "notNullConstraint")
  .ms_eml_add_text(
    not_null,
    "constraintName",
    paste0("NotNull_", table_id)
  )
  key <- xml2::xml_add_child(not_null, "key")
  for (column in columns) {
    .ms_eml_add_text(
      key,
      "attributeReference",
      .ms_eml_attribute_id(dataset_id, table_id, column)
    )
  }
  invisible(constraint)
}

.ms_eml_add_supplementary_objects <- function(dataset,
                                               objects,
                                               mapping) {
  if (nrow(objects) == 0L) {
    return(invisible(NULL))
  }

  for (i in seq_len(nrow(objects))) {
    object <- objects[i, , drop = FALSE]
    id_key <- paste(mapping$dataset_id, object$pid[[1]], sep = ":")

    other_entity <- xml2::xml_add_child(dataset, "otherEntity")
    xml2::xml_set_attr(
      other_entity,
      "id",
      .ms_eml_id("other-entity", id_key)
    )
    .ms_eml_add_text(
      other_entity,
      "alternateIdentifier",
      object$pid[[1]],
      attrs = c(system = "DataONE")
    )
    .ms_eml_add_text(other_entity, "entityName", object$entity_name[[1]])
    .ms_eml_add_text(
      other_entity,
      "entityDescription",
      object$description[[1]]
    )

    physical <- xml2::xml_add_child(other_entity, "physical")
    xml2::xml_set_attr(
      physical,
      "id",
      .ms_eml_id("physical", paste(id_key, object$checksum[[1]], sep = ":"))
    )
    .ms_eml_add_text(physical, "objectName", object$object_name[[1]])
    .ms_eml_add_text(
      physical,
      "size",
      as.character(object$size[[1]]),
      attrs = c(unit = "byte")
    )
    .ms_eml_add_text(
      physical,
      "authentication",
      object$checksum[[1]],
      attrs = c(method = object$checksum_algorithm[[1]])
    )
    .ms_eml_add_text(physical, "compressionMethod", "zip")
    data_format <- xml2::xml_add_child(physical, "dataFormat")
    external_format <- xml2::xml_add_child(
      data_format,
      "externallyDefinedFormat"
    )
    .ms_eml_add_text(
      external_format,
      "formatName",
      object$format_id[[1]]
    )
    distribution <- xml2::xml_add_child(physical, "distribution")
    online <- xml2::xml_add_child(distribution, "online")
    .ms_eml_add_text(
      online,
      "onlineDescription",
      paste("Download", object$entity_name[[1]])
    )
    .ms_eml_add_text(online, "url", object$online_url[[1]])

    .ms_eml_add_text(
      other_entity,
      "entityType",
      "Salmon Data Package archive"
    )
  }
  invisible(NULL)
}

.ms_eml_build_document <- function(path,
                                   pkg,
                                   mapping,
                                   configs,
                                   vocabulary,
                                   data_objects,
                                   supplementary_objects) {
  root <- xml2::read_xml(paste0(
    '<eml:eml xmlns:eml="', .ms_eml_namespace, '" ',
    'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" ',
    'xsi:schemaLocation="', .ms_eml_namespace, " ",
    .ms_eml_namespace, '/eml.xsd"/>'
  ))
  root <- xml2::xml_root(root)
  revision_key <- .ms_eml_revision_key(mapping)
  package_id_preimage <- c(
    "metasalmon-eml-profile-1",
    mapping$system,
    mapping$dataset_id
  )
  if (!is.na(revision_key)) {
    package_id_preimage <- c(
      package_id_preimage,
      "revision",
      revision_key
    )
  }
  package_id <- paste0(
    "urn:uuid:",
    .ms_eml_uuid5(paste(package_id_preimage, collapse = ":"))
  )
  series_id <- paste0(
    "urn:uuid:",
    .ms_eml_uuid5(paste("series", mapping$series_key, sep = ":"))
  )
  xml2::xml_set_attr(root, "packageId", package_id)
  xml2::xml_set_attr(root, "system", mapping$system)

  dataset <- xml2::xml_add_child(root, "dataset")
  xml2::xml_set_attr(
    dataset,
    "id",
    .ms_eml_id("dataset", mapping$dataset_id)
  )
  .ms_eml_add_text(dataset, "alternateIdentifier", mapping$dataset_id)
  .ms_eml_add_text(dataset, "title", pkg$dataset$title[[1]])

  for (i in seq_along(mapping$creators)) {
    .ms_eml_add_party(
      dataset,
      "creator",
      mapping$creators[[i]],
      paste(mapping$dataset_id, "creator", i, sep = ":")
    )
  }
  for (i in seq_along(mapping$metadata_providers)) {
    .ms_eml_add_party(
      dataset,
      "metadataProvider",
      mapping$metadata_providers[[i]],
      paste(mapping$dataset_id, "metadata-provider", i, sep = ":")
    )
  }
  .ms_eml_add_text(dataset, "pubDate", mapping$publication_date)
  .ms_eml_add_text(dataset, "language", mapping$language)
  .ms_eml_add_para(dataset, "abstract", pkg$dataset$description[[1]])

  keywords <- .ms_eml_split_iris(gsub(
    ",",
    ";",
    as.character(pkg$dataset$keywords[[1]]),
    fixed = TRUE
  ))
  if (length(keywords) > 0L) {
    keyword_set <- xml2::xml_add_child(dataset, "keywordSet")
    for (keyword in keywords) {
      .ms_eml_add_text(keyword_set, "keyword", keyword)
    }
    .ms_eml_add_text(keyword_set, "keywordThesaurus", "None")
  }

  supporting_document <- mapping$source_provenance$supporting_document
  additional_info <- xml2::xml_add_child(dataset, "additionalInfo")
  provenance_lines <- c(
    paste(
      "Source citation:",
      mapping$source_provenance$source_citation
    ),
    paste(
      "Provenance note:",
      mapping$source_provenance$provenance_note
    ),
    paste(
      "Supporting document citation:",
      supporting_document$citation
    ),
    paste(
      "Supporting document URL:",
      supporting_document$url
    ),
    paste(
      "Supporting document SHA-256:",
      supporting_document$sha256
    )
  )
  for (line in provenance_lines) {
    .ms_eml_add_text(additional_info, "para", line)
  }

  intellectual_rights <- xml2::xml_add_child(
    dataset,
    "intellectualRights"
  )
  for (paragraph in mapping$intellectual_rights$paragraphs) {
    .ms_eml_add_text(intellectual_rights, "para", paragraph)
  }
  .ms_eml_add_coverage(dataset, pkg$dataset, mapping)

  for (i in seq_along(mapping$contacts)) {
    .ms_eml_add_party(
      dataset,
      "contact",
      mapping$contacts[[i]],
      paste(mapping$dataset_id, "contact", i, sep = ":")
    )
  }
  .ms_eml_add_party(
    dataset,
    "publisher",
    mapping$publisher,
    paste(mapping$dataset_id, "publisher", sep = ":")
  )

  methods <- xml2::xml_add_child(dataset, "methods")
  for (method in mapping$methods) {
    method_step <- xml2::xml_add_child(methods, "methodStep")
    description <- xml2::xml_add_child(method_step, "description")
    .ms_eml_add_text(description, "para", method$description)
  }

  for (table_index in seq_len(nrow(pkg$tables))) {
    table_row <- pkg$tables[table_index, , drop = FALSE]
    table_id <- as.character(table_row$table_id[[1]])
    data_object <- data_objects[data_objects$table_id == table_id, , drop = FALSE]
    if (nrow(data_object) != 1L) {
      cli::cli_abort(
        "Internal EML export error: expected one data object for table {.val {table_id}}."
      )
    }
    data <- pkg$resources[[table_id]]
    if (is.null(data)) {
      cli::cli_abort(
        "SDP table {.val {table_id}} has no loaded data resource."
      )
    }
    raw_data <- .ms_eml_read_raw_csv_tokens(
      data_object$path[[1]],
      table_id
    )
    .ms_eml_validate_raw_table(raw_data, data, table_id)

    data_table <- xml2::xml_add_child(dataset, "dataTable")
    xml2::xml_set_attr(
      data_table,
      "id",
      .ms_eml_id(
        "table",
        paste(mapping$dataset_id, table_id, sep = ":")
      )
    )
    .ms_eml_add_text(data_table, "alternateIdentifier", table_id)
    .ms_eml_add_text(data_table, "entityName", table_row$table_label[[1]])
    .ms_eml_add_text(
      data_table,
      "entityDescription",
      table_row$description[[1]]
    )

    physical <- xml2::xml_add_child(data_table, "physical")
    xml2::xml_set_attr(
      physical,
      "id",
      .ms_eml_id(
        "physical",
        paste(mapping$dataset_id, table_id, sep = ":")
      )
    )
    .ms_eml_add_text(
      physical,
      "objectName",
      basename(data_object$file_name[[1]])
    )
    .ms_eml_add_text(
      physical,
      "size",
      as.character(data_object$size[[1]]),
      attrs = c(unit = "byte")
    )
    .ms_eml_add_text(
      physical,
      "authentication",
      data_object$checksum[[1]],
      attrs = c(method = "SHA-256")
    )
    .ms_eml_add_text(physical, "characterEncoding", "UTF-8")
    data_format <- xml2::xml_add_child(physical, "dataFormat")
    text_format <- xml2::xml_add_child(data_format, "textFormat")
    .ms_eml_add_text(text_format, "numHeaderLines", "1")
    .ms_eml_add_text(
      text_format,
      "recordDelimiter",
      .ms_eml_record_delimiter(data_object$path[[1]])
    )
    .ms_eml_add_text(text_format, "attributeOrientation", "column")
    delimited <- xml2::xml_add_child(text_format, "simpleDelimited")
    .ms_eml_add_text(delimited, "fieldDelimiter", ",")
    .ms_eml_add_text(delimited, "quoteCharacter", '"')
    distribution <- xml2::xml_add_child(physical, "distribution")
    online <- xml2::xml_add_child(distribution, "online")
    .ms_eml_add_text(
      online,
      "url",
      .ms_eml_knb_object_url(data_object$pid[[1]])
    )

    attribute_list <- xml2::xml_add_child(data_table, "attributeList")
    xml2::xml_set_attr(
      attribute_list,
      "id",
      .ms_eml_id(
        "attributes",
        paste(mapping$dataset_id, table_id, sep = ":")
      )
    )
    rows <- which(pkg$dictionary$table_id == table_id)
    for (row_index in rows) {
      .ms_eml_add_attribute(
        attribute_list,
        pkg$dictionary[row_index, , drop = FALSE],
        configs[[row_index]],
        data,
        raw_data,
        pkg,
        vocabulary,
        mapping$dataset_id
      )
    }
    .ms_eml_add_primary_key(
      data_table,
      table_row,
      pkg$dictionary,
      mapping$dataset_id
    )
    .ms_eml_add_not_null(
      data_table,
      table_id,
      pkg$dictionary,
      mapping$dataset_id
    )
    .ms_eml_add_text(data_table, "numberOfRecords", as.character(nrow(data)))
  }

  .ms_eml_add_supplementary_objects(
    dataset,
    supplementary_objects,
    mapping
  )

  list(
    document = root,
    package_id = package_id,
    series_id = series_id
  )
}

.ms_eml_read_bytes <- function(path) {
  readBin(path, what = "raw", n = file.info(path)$size)
}

.ms_eml_record_delimiter <- function(path) {
  bytes <- .ms_eml_read_bytes(path)
  line_feeds <- which(bytes == as.raw(0x0a))
  if (length(line_feeds) == 0L) {
    cli::cli_abort(
      "CSV resource {.path {path}} has no detectable record delimiter."
    )
  }
  first <- line_feeds[[1]]
  if (first > 1L && identical(bytes[[first - 1L]], as.raw(0x0d))) {
    return("\\r\\n")
  }
  "\\n"
}

.ms_eml_validation_errors <- function(validation) {
  errors <- attr(validation, "errors")
  if (is.null(errors) || length(errors) == 0L) {
    return("Unknown EML schema validation error.")
  }
  paste(utils::head(as.character(errors), 10L), collapse = "\n")
}

.ms_eml_validate_document_links <- function(document, dictionary, dataset_id) {
  nodes_with_ids <- xml2::xml_find_all(document, "//*[@id]")
  ids <- xml2::xml_attr(nodes_with_ids, "id")
  if (anyDuplicated(ids)) {
    duplicates <- unique(ids[duplicated(ids)])
    cli::cli_abort(
      "Generated EML contains duplicate XML ID{?s}: {.val {duplicates}}."
    )
  }

  references <- xml2::xml_text(xml2::xml_find_all(
    document,
    "//*[local-name()='attributeReference']"
  ))
  unknown <- setdiff(references, ids)
  if (length(unknown) > 0L) {
    cli::cli_abort(
      "Generated EML contains dangling attribute reference{?s}: {.val {unknown}}."
    )
  }

  annotations <- xml2::xml_find_all(
    document,
    "//*[local-name()='annotation']"
  )
  annotated_parents <- xml2::xml_parent(annotations)
  missing_subject_ids <- is.na(xml2::xml_attr(annotated_parents, "id"))
  if (any(missing_subject_ids)) {
    cli::cli_abort(
      "Every EML semantic annotation subject must have a unique XML ID."
    )
  }

  measurement <- dictionary[
    dictionary$column_role == "measurement" &
      !is.na(dictionary$column_role),
    ,
    drop = FALSE
  ]
  expected_measurement_ids <- vapply(seq_len(nrow(measurement)), function(i) {
    .ms_eml_attribute_id(
      dataset_id,
      measurement$table_id[[i]],
      measurement$column_name[[i]]
    )
  }, character(1))
  actual_measurement_ids <- unique(xml2::xml_attr(
    annotated_parents,
    "id"
  ))
  if (!setequal(expected_measurement_ids, actual_measurement_ids)) {
    cli::cli_abort(
      "Generated EML annotation subjects do not exactly match the SDP measurement columns."
    )
  }

  for (i in seq_along(expected_measurement_ids)) {
    attribute_id <- expected_measurement_ids[[i]]
    xpath <- paste0(
      "//*[@id='",
      attribute_id,
      "']/*[local-name()='annotation']/*[local-name()='propertyURI']"
    )
    predicates <- xml2::xml_text(xml2::xml_find_all(document, xpath))
    term_annotation <- .ms_eml_measurement_term_annotation(
      measurement[i, , drop = FALSE]
    )
    expected_predicates <- c(
      term_annotation$iri,
      unname(.ms_eml_measurement_predicates[["unit"]])
    )
    if (!identical(
      predicates,
      expected_predicates
    )) {
      cli::cli_abort(
        "Generated EML attribute {.val {attribute_id}} does not contain exactly the approved semantic predicates in profile order."
      )
    }
  }

  xml_text <- as.character(document)
  if (grepl("REVIEW:", xml_text, fixed = TRUE)) {
    cli::cli_abort("Generated EML contains an unresolved {.val REVIEW:} marker.")
  }
  if (grepl("usedProcedure", xml_text, fixed = TRUE)) {
    cli::cli_abort(
      "The initial EML profile must not emit a procedure annotation."
    )
  }
  invisible(TRUE)
}

#' Write reviewed EML 2.2.0 metadata from a Salmon Data Package
#'
#' Builds deterministic EML 2.2.0 XML from a strictly valid Salmon Data
#' Package and an explicit EML mapping sidecar. The sidecar is required because
#' EML concepts such as measurement scale, structured parties, methods, and
#' rights cannot be inferred defensibly from the canonical SDP tables.
#'
#' Measurement attributes receive exactly two semantic annotations in the
#' initial profile. Both reviewed OWL measurement-datum classes and SKOS
#' compound-variable concepts use Dublin Core Terms `subject` with the reviewed
#' `term_iri`, followed by QUDT `hasUnit` using the reviewed `unit_iri`. The
#' broader topic predicate is intentional: an OWL class is not necessarily an
#' OBOE `MeasurementType`, and schema-valid EML must not silently assert that
#' unsupported range. The exporter deliberately does not project incomplete
#' I-ADOPT roles or procedure annotations into EML.
#'
#' @param path Directory containing a Salmon Data Package.
#' @param output_path Output XML path. Defaults to `metadata/eml.xml` inside
#'   `path`.
#' @param mapping_path Reviewed YAML mapping. Defaults to
#'   `metadata/eml-mapping.yml` inside `path`.
#' @param overwrite Logical; replace a different existing output only when
#'   `TRUE`. An identical existing file is treated as an idempotent success.
#' @param supplementary_objects Optional data frame describing canonical SDP
#'   archives to expose as EML `otherEntity` elements. Required columns are
#'   `path`, `pid`, `format_id`, `checksum`, `object_name`, `entity_name`, and
#'   `description`; optional `size`, when supplied, must match the file. The
#'   initial profile accepts `application/zip` objects with lowercase SHA-256
#'   checksums. `publish_sdp_to_knb()` supplies this archive plan
#'   automatically; ordinary standalone EML export leaves the argument `NULL`.
#' @param require_revision_key Logical; when `TRUE`, require a reviewed
#'   `publication.revision_key` in the EML mapping sidecar. The key creates a
#'   new deterministic metadata package ID without changing the series ID.
#'
#' @return Invisibly returns a list containing the XML text, normalized output
#'   path, EML version, metadata package ID, stable series ID, validation
#'   result, revision key, and deterministic data and supplementary-object
#'   plans.
#' @export
#'
#' @examples
#' \dontrun{
#' write_eml_from_sdp("path/to/reviewed-sdp")
#' }
write_eml_from_sdp <- function(path,
                               output_path = NULL,
                               mapping_path = NULL,
                               overwrite = FALSE,
                               supplementary_objects = NULL,
                               require_revision_key = FALSE) {
  if (length(require_revision_key) != 1L ||
      !is.logical(require_revision_key) ||
      is.na(require_revision_key)) {
    cli::cli_abort(
      "{.arg require_revision_key} must be one logical value."
    )
  }
  if (!requireNamespace("emld", quietly = TRUE)) {
    cli::cli_abort(
      "Package {.pkg emld} is required to validate EML. Install it before exporting."
    )
  }
  if (!dir.exists(path)) {
    cli::cli_abort("SDP directory {.path {path}} does not exist.")
  }

  path <- normalizePath(path, mustWork = TRUE)
  if (is.null(mapping_path)) {
    mapping_path <- .ms_eml_default_mapping_path(path)
  }
  if (!file.exists(mapping_path)) {
    cli::cli_abort("EML mapping sidecar {.path {mapping_path}} does not exist.")
  }
  mapping_path <- normalizePath(mapping_path, mustWork = TRUE)

  if (is.null(output_path)) {
    output_path <- file.path(path, "metadata", "eml.xml")
  }
  output_path <- path.expand(output_path)
  output_dir <- dirname(output_path)
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  }
  if (!dir.exists(output_dir)) {
    cli::cli_abort(
      "Could not create EML output directory {.path {output_dir}}."
    )
  }
  output_path <- file.path(
    normalizePath(output_dir, mustWork = TRUE),
    basename(output_path)
  )

  validation <- validate_salmon_datapackage(path, require_iris = TRUE)
  pkg <- validation$package
  if (nrow(pkg$dataset) != 1L) {
    cli::cli_abort("EML export requires exactly one SDP dataset row.")
  }

  mapping <- yaml::read_yaml(mapping_path)
  configs <- .ms_eml_validate_mapping(mapping, pkg)
  revision_key <- .ms_eml_revision_key(
    mapping,
    required = require_revision_key
  )
  invisible(.ms_eml_read_semantic_review(path, pkg, mapping))
  vocabulary <- .ms_eml_read_vocabulary(path, pkg$dictionary, mapping)
  data_objects <- .ms_eml_data_objects(path, pkg, mapping)
  supplementary_objects <- .ms_eml_supplementary_objects(
    supplementary_objects
  )
  built <- .ms_eml_build_document(
    path,
    pkg,
    mapping,
    configs,
    vocabulary,
    data_objects,
    supplementary_objects
  )
  .ms_eml_validate_document_links(
    built$document,
    pkg$dictionary,
    mapping$dataset_id
  )

  temporary <- tempfile(
    pattern = ".metasalmon-eml-",
    tmpdir = output_dir,
    fileext = ".xml"
  )
  on.exit(unlink(temporary), add = TRUE)
  xml2::write_xml(
    built$document,
    temporary,
    options = "format",
    encoding = "UTF-8"
  )

  eml_schema <- system.file(
    "xsd",
    "eml-2.2.0",
    "eml.xsd",
    package = "emld"
  )
  if (!nzchar(eml_schema)) {
    cli::cli_abort(
      "Could not locate the bundled EML 2.2.0 schema in {.pkg emld}."
    )
  }
  eml_validation <- emld::eml_validate(temporary, schema = eml_schema)
  if (!isTRUE(eml_validation)) {
    cli::cli_abort(c(
      "Generated EML 2.2.0 failed schema validation.",
      "x" = .ms_eml_validation_errors(eml_validation)
    ))
  }

  if (file.exists(output_path)) {
    identical_bytes <- identical(
      .ms_eml_read_bytes(output_path),
      .ms_eml_read_bytes(temporary)
    )
    if (identical_bytes) {
      unlink(temporary)
    } else if (!isTRUE(overwrite)) {
      cli::cli_abort(
        "EML output {.path {output_path}} already exists with different bytes; set {.arg overwrite = TRUE} to replace it."
      )
    }
  }

  if (file.exists(temporary) && !file.rename(temporary, output_path)) {
    cli::cli_abort(
      "Could not atomically move validated EML into {.path {output_path}}."
    )
  }

  result <- list(
    xml = paste(readLines(output_path, warn = FALSE), collapse = "\n"),
    path = normalizePath(output_path, mustWork = TRUE),
    eml_version = .ms_eml_version,
    format_id = .ms_eml_format_id,
    package_id = built$package_id,
    series_id = built$series_id,
    revision_key = revision_key,
    public = mapping$publication$public,
    validation = eml_validation,
    data_objects = data_objects,
    supplementary_objects = supplementary_objects
  )
  cli::cli_alert_success(
    "Validated EML {.val {result$eml_version}} written to {.path {result$path}}"
  )
  invisible(result)
}
