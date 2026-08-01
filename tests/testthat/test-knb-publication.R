make_knb_test_sdp <- function(path, dataset_id = "demo-salmon-2026") {
  make_eml_test_sdp(path, dataset_id = dataset_id)
}

make_knb_test_sssom <- function(path) {
  source_path <- tempfile(fileext = ".sssom.tsv")
  lines <- c(
    "# sssom_version: 1.1",
    "# mapping_set_id: https://example.org/mappings/psc-to-sdo-gaps",
    "# mapping_set_version: 2026-07-31",
    "# license: https://creativecommons.org/licenses/by/4.0/",
    "# subject_source: https://w3id.org/psc/vocab/",
    "# subject_source_version: review-candidate-2026-07-31",
    "# object_source: https://w3id.org/smn/",
    "# object_source_version: 2026-07-31",
    "# curie_map:",
    "#   psc: https://w3id.org/psc/vocab/concept/",
    "#   skos: http://www.w3.org/2004/02/skos/core#",
    "#   semapv: https://w3id.org/semapv/vocab/",
    "#   sssom: https://w3id.org/sssom/",
    paste(
      "subject_id",
      "subject_label",
      "predicate_id",
      "object_id",
      "mapping_justification",
      "mapping_cardinality",
      sep = "\t"
    ),
    paste(
      "psc:PSC-CV-000035",
      "Effective female spawner abundance",
      "skos:relatedMatch",
      "sssom:NoTermFound",
      "semapv:ManualMappingCuration",
      "1:0",
      sep = "\t"
    )
  )
  writeBin(
    charToRaw(enc2utf8(paste0(paste(lines, collapse = "\n"), "\n"))),
    source_path
  )
  write_sdp_sssom(path, mapping_sets = source_path)
}

make_knb_test_measurement_decompositions <- function(path) {
  decompositions <- tibble::tribble(
    ~dataset_id, ~table_id, ~column_name, ~measurement_concept_iri,
    ~component_order, ~component_role, ~component_status,
    ~component_relation, ~related_component_order, ~component_iri,
    ~component_label, ~rationale, ~source, ~source_version, ~source_url,
    ~provenance,
    "demo-salmon-2026", "counts", "count",
    "https://w3id.org/smn/ObservedRateOrAbundance",
    1L, "property", "matched", "", NA_integer_,
    "http://qudt.org/vocab/quantitykind/Count", "Count",
    "The dictionary property is preserved in the ordered decomposition.",
    "qudt", "3.1.1", "https://qudt.org/3.1.1/vocab/quantitykind/",
    "Reviewed fixture component.",
    "demo-salmon-2026", "counts", "count",
    "https://w3id.org/smn/ObservedRateOrAbundance",
    2L, "entity", "matched", "", NA_integer_,
    "https://w3id.org/smn/Stock", "Stock",
    "The dictionary entity is preserved in the ordered decomposition.",
    "smn", "2026-07-31", "https://w3id.org/smn/",
    "Reviewed fixture component.",
    "demo-salmon-2026", "counts", "count",
    "https://w3id.org/smn/ObservedRateOrAbundance",
    3L, "unit", "matched", "", NA_integer_,
    "http://qudt.org/vocab/unit/COUNT", "Count",
    "The dictionary unit is preserved in the ordered decomposition.",
    "qudt", "3.1.1", "https://qudt.org/3.1.1/vocab/unit/",
    "Reviewed fixture component."
  )

  write_sdp_measurement_decompositions(
    path,
    decompositions = decompositions
  )
}

test_that("KNB dry run writes an exact offline manifest and deterministic ORE", {
  skip_if_not_installed("emld")

  package_path <- make_knb_test_sdp(withr::local_tempdir())
  manifest_path <- file.path(package_path, "publication", "knb-manifest.json")
  adapter_accessed <- FALSE
  withr::local_options(list(
    metasalmon.knb_adapter = function() {
      adapter_accessed <<- TRUE
      stop("the adapter must not be constructed during a dry run")
    }
  ))

  result <- publish_sdp_to_knb(
    package_path,
    public = TRUE,
    manifest_path = manifest_path,
    dry_run = TRUE
  )

  expect_false(adapter_accessed)
  expect_equal(result$status, "dry_run")
  expect_true(file.exists(manifest_path))
  expect_true(file.exists(result$resource_map_path))

  manifest <- jsonlite::read_json(manifest_path, simplifyVector = TRUE)
  expect_equal(manifest$schema_version, 2L)
  expect_equal(manifest$environment, "PROD")
  expect_equal(manifest$node_id, "urn:node:KNB")
  expect_true(manifest$public)
  expect_identical(
    manifest$replication_policy$replication_allowed,
    TRUE
  )
  expect_equal(manifest$replication_policy$number_replicas, 3L)
  expect_length(manifest$replication_policy$preferred_member_nodes, 0L)
  expect_length(manifest$replication_policy$blocked_member_nodes, 0L)
  expect_equal(
    manifest$expected_subject,
    "https://orcid.org/0000-0001-9317-0364"
  )
  expect_match(manifest$plan_sha256, "^[0-9a-f]{64}$")
  expect_equal(
    unname(vapply(
      .ms_knb_manifest_objects(manifest),
      function(object) as.character(object$role),
      character(1)
    )),
    c(
      "data",
      rep("sdp_artifact", 8L),
      "metadata",
      "resource_map"
    )
  )
  expect_equal(
    unname(vapply(
      .ms_knb_manifest_objects(manifest),
      function(object) as.character(object$path),
      character(1)
    )),
    c(
      "data/counts.csv",
      "datapackage.json",
      "metadata/codes.csv",
      "metadata/column_dictionary.csv",
      "metadata/dataset.csv",
      "metadata/eml-mapping.yml",
      "metadata/semantic_vocabulary.csv",
      "metadata/tables.csv",
      "reviewed_semantic_selections.csv",
      "metadata/eml.xml",
      "publication/resource-map.rdf"
    )
  )
  manifest_objects <- .ms_knb_manifest_objects(manifest)
  manifest_paths <- vapply(
    manifest_objects,
    function(object) as.character(object$path),
    character(1)
  )
  manifest_roles <- vapply(
    manifest_objects,
    function(object) as.character(object$role),
    character(1)
  )
  manifest_pids <- vapply(
    manifest_objects,
    function(object) as.character(object$pid),
    character(1)
  )
  expect_false(any(startsWith(manifest_paths, "/")))
  expect_false(any(grepl("..", manifest_paths, fixed = TRUE)))
  expect_false(any(grepl(
    normalizePath(package_path, mustWork = TRUE),
    paste(readLines(manifest_path, warn = FALSE), collapse = "\n"),
    fixed = TRUE
  )))

  ore <- xml2::read_xml(result$resource_map_path)
  aggregates <- xml2::xml_attr(
    xml2::xml_find_all(ore, "//*[local-name()='aggregates']"),
    "resource"
  )
  expect_setequal(
    aggregates,
    paste0(
      "https://cn.dataone.org/cn/v2/resolve/",
      utils::URLencode(
        manifest_pids[manifest_roles != "resource_map"],
        reserved = TRUE
      )
    )
  )
  resource_map_url <- paste0(
    "https://cn.dataone.org/cn/v2/resolve/",
    utils::URLencode(manifest$resource_map_pid, reserved = TRUE)
  )
  aggregation_url <- paste0(resource_map_url, "#aggregation")
  expect_equal(
    xml2::xml_attr(
      xml2::xml_find_first(ore, "//*[local-name()='describes']"),
      "resource"
    ),
    aggregation_url
  )
  expect_equal(
    xml2::xml_attr(
      xml2::xml_find_first(
        ore,
        "//*[local-name()='type' and contains(@rdf:resource, 'Aggregation')]/../*[local-name()='isDescribedBy']",
        ns = c(rdf = "http://www.w3.org/1999/02/22-rdf-syntax-ns#")
      ),
      "resource"
    ),
    resource_map_url
  )
  expect_equal(
    length(xml2::xml_find_all(ore, "//*[local-name()='documents']")),
    1L
  )
  expect_equal(
    length(xml2::xml_find_all(ore, "//*[local-name()='isDocumentedBy']")),
    1L
  )
  identifiers <- xml2::xml_text(
    xml2::xml_find_all(ore, "//*[local-name()='identifier']")
  )
  expect_setequal(
    identifiers,
    c(
      manifest_pids,
      paste0(manifest$resource_map_pid, "#aggregation")
    )
  )
  metadata_url <- paste0(
    "https://cn.dataone.org/cn/v2/resolve/",
    utils::URLencode(manifest$metadata_pid, reserved = TRUE)
  )
  expect_false(any(
    xml2::xml_attr(
      xml2::xml_find_all(ore, "//*[local-name()='documents']"),
      "resource"
    ) == metadata_url
  ))
  expect_equal(
    length(xml2::xml_find_all(ore, "//*[local-name()='isAggregatedBy']")),
    length(aggregates)
  )
  expect_false(grepl(
    normalizePath(package_path, mustWork = TRUE),
    as.character(ore),
    fixed = TRUE
  ))
})

test_that("KNB dry-run artifacts are path-independent and ignore decoy files", {
  skip_if_not_installed("emld")

  first_path <- file.path(withr::local_tempdir(), "first")
  second_path <- file.path(withr::local_tempdir(), "second")
  make_knb_test_sdp(first_path)
  make_knb_test_sdp(second_path)
  writeLines("not part of the package", file.path(first_path, "secret.txt"))
  writeLines("also excluded", file.path(second_path, "metadata", "notes.txt"))

  first <- publish_sdp_to_knb(first_path, public = TRUE, dry_run = TRUE)
  second <- publish_sdp_to_knb(second_path, public = TRUE, dry_run = TRUE)

  first_manifest <- jsonlite::read_json(
    first$manifest_path,
    simplifyVector = TRUE
  )
  second_manifest <- jsonlite::read_json(
    second$manifest_path,
    simplifyVector = TRUE
  )
  expect_identical(first_manifest, second_manifest)
  expect_identical(
    readBin(
      first$resource_map_path,
      "raw",
      n = file.info(first$resource_map_path)$size
    ),
    readBin(
      second$resource_map_path,
      "raw",
      n = file.info(second$resource_map_path)$size
    )
  )
  expect_false(any(grepl(
    "secret|notes",
    vapply(
      .ms_knb_manifest_objects(first_manifest),
      function(object) as.character(object$path),
      character(1)
    )
  )))
})

test_that("KNB includes only manifest-declared SSSOM supplements", {
  skip_if_not_installed("emld")

  package_path <- make_knb_test_sdp(withr::local_tempdir())
  make_knb_test_sssom(package_path)
  decoy_path <- file.path(
    package_path,
    "metadata",
    "semantic",
    "unlisted-secret.sssom.tsv"
  )
  writeLines("not a declared mapping set", decoy_path)

  result <- publish_sdp_to_knb(
    package_path,
    public = TRUE,
    dry_run = TRUE
  )
  objects <- .ms_knb_manifest_objects(result$manifest)
  paths <- vapply(objects, function(object) object$path, character(1))
  formats <- stats::setNames(
    vapply(objects, function(object) object$format_id, character(1)),
    paths
  )
  media_types <- stats::setNames(
    vapply(objects, function(object) object$media_type, character(1)),
    paths
  )

  expect_true("metadata/semantic/mapping-sets.json" %in% paths)
  expect_true(any(grepl("[.]sssom[.]tsv$", paths)))
  expect_false("metadata/semantic/unlisted-secret.sssom.tsv" %in% paths)
  expect_identical(
    formats[["metadata/semantic/mapping-sets.json"]],
    "application/json"
  )
  expect_true(all(
    formats[grepl("[.]sssom[.]tsv$", names(formats))] ==
      "text/tsv"
  ))
  expect_true(all(
    media_types[grepl("[.]sssom[.]tsv$", names(media_types))] ==
      "text/tab-separated-values"
  ))
})

test_that("KNB refuses a tampered manifest-declared SSSOM supplement", {
  skip_if_not_installed("emld")

  package_path <- make_knb_test_sdp(withr::local_tempdir())
  make_knb_test_sssom(package_path)
  mapping_path <- list.files(
    file.path(package_path, "metadata", "semantic"),
    pattern = "[.]sssom[.]tsv$",
    full.names = TRUE
  )
  write("tampered", mapping_path, append = TRUE)

  expect_error(
    publish_sdp_to_knb(
      package_path,
      public = TRUE,
      dry_run = TRUE
    ),
    "SSSOM.*SHA-256|SHA-256.*SSSOM"
  )
})

test_that("KNB includes only manifest-declared measurement decompositions", {
  skip_if_not_installed("emld")

  package_path <- make_knb_test_sdp(withr::local_tempdir())
  make_knb_test_measurement_decompositions(package_path)
  semantic_path <- file.path(package_path, "metadata", "semantic")
  writeLines(
    "not a declared decomposition",
    file.path(semantic_path, "unlisted-secret-decomposition.csv")
  )
  writeLines(
    "not a declared manifest",
    file.path(semantic_path, "unlisted-secret-decomposition.json")
  )

  result <- publish_sdp_to_knb(
    package_path,
    public = TRUE,
    dry_run = TRUE
  )
  objects <- .ms_knb_manifest_objects(result$manifest)
  paths <- vapply(objects, function(object) object$path, character(1))
  formats <- stats::setNames(
    vapply(objects, function(object) object$format_id, character(1)),
    paths
  )
  media_types <- stats::setNames(
    vapply(objects, function(object) object$media_type, character(1)),
    paths
  )

  decomposition_paths <- paths[grepl(
    "metadata/semantic/.*decomposition",
    paths
  )]
  expect_setequal(
    decomposition_paths,
    c(
      "metadata/semantic/measurement-decompositions.csv",
      "metadata/semantic/measurement-decompositions.json"
    )
  )
  expect_identical(
    formats[["metadata/semantic/measurement-decompositions.csv"]],
    "text/csv"
  )
  expect_identical(
    media_types[["metadata/semantic/measurement-decompositions.csv"]],
    "text/csv"
  )
  expect_identical(
    formats[["metadata/semantic/measurement-decompositions.json"]],
    "application/json"
  )
  expect_identical(
    media_types[["metadata/semantic/measurement-decompositions.json"]],
    "application/json"
  )
})

test_that("KNB refuses hash drift in a declared measurement decomposition", {
  skip_if_not_installed("emld")

  package_path <- make_knb_test_sdp(withr::local_tempdir())
  make_knb_test_measurement_decompositions(package_path)
  csv_path <- file.path(
    package_path,
    "metadata",
    "semantic",
    "measurement-decompositions.csv"
  )
  csv_text <- readChar(csv_path, nchars = file.info(csv_path)$size)
  writeBin(
    charToRaw(sub(
      "Reviewed fixture component.",
      "Tampered fixture component.",
      csv_text,
      fixed = TRUE
    )),
    csv_path
  )

  expect_error(
    publish_sdp_to_knb(
      package_path,
      public = TRUE,
      dry_run = TRUE
    ),
    "decomposition.*SHA-256|SHA-256.*decomposition"
  )
})

test_that("KNB refuses measurement decompositions reached through a symlink", {
  skip_if_not_installed("emld")
  skip_on_os("windows")

  source_path <- make_knb_test_sdp(withr::local_tempdir())
  package_path <- make_knb_test_sdp(withr::local_tempdir())
  make_knb_test_measurement_decompositions(source_path)
  expect_true(file.symlink(
    file.path(source_path, "metadata", "semantic"),
    file.path(package_path, "metadata", "semantic")
  ))

  expect_error(
    publish_sdp_to_knb(
      package_path,
      public = TRUE,
      dry_run = TRUE
    ),
    "symlink|outside.*SDP|unsafe"
  )
})

test_that("KNB publication requires explicit access and live confirmation", {
  skip_if_not_installed("emld")

  package_path <- make_knb_test_sdp(withr::local_tempdir())
  adapter_accessed <- FALSE
  withr::local_options(list(
    metasalmon.knb_adapter = function() {
      adapter_accessed <<- TRUE
      stop("adapter accessed")
    }
  ))

  expect_error(
    publish_sdp_to_knb(package_path, dry_run = TRUE),
    "public"
  )
  expect_false(adapter_accessed)

  expect_error(
    publish_sdp_to_knb(
      package_path,
      public = TRUE,
      dry_run = FALSE
    ),
    "explicit.*confirm"
  )
  expect_false(adapter_accessed)
})

test_that("KNB publication binds authentication to an EML metadata-provider ORCID", {
  skip_if_not_installed("emld")

  package_path <- make_knb_test_sdp(withr::local_tempdir())
  mapping_path <- file.path(package_path, "metadata", "eml-mapping.yml")
  mapping <- yaml::read_yaml(mapping_path)
  mapping$metadata_providers[[1]]$orcid <- NULL
  yaml::write_yaml(mapping, mapping_path)

  expect_error(
    publish_sdp_to_knb(
      package_path,
      public = TRUE,
      dry_run = TRUE
    ),
    "exactly one metadata-provider ORCID"
  )
})

test_that("KNB dry run refuses a changed plan at an existing manifest", {
  skip_if_not_installed("emld")

  package_path <- make_knb_test_sdp(withr::local_tempdir())
  manifest_path <- file.path(package_path, "publication", "knb-manifest.json")
  publish_sdp_to_knb(
    package_path,
    public = TRUE,
    manifest_path = manifest_path,
    dry_run = TRUE
  )
  manifest <- jsonlite::read_json(
    manifest_path,
    simplifyVector = FALSE
  )
  manifest$plan_sha256 <- paste(rep("0", 64L), collapse = "")
  jsonlite::write_json(
    manifest,
    manifest_path,
    auto_unbox = TRUE,
    pretty = TRUE
  )

  expect_error(
    publish_sdp_to_knb(
      package_path,
      public = TRUE,
      manifest_path = manifest_path,
      dry_run = TRUE
    ),
    "existing publication manifest.*different plan"
  )
})

test_that("KNB publication access must match the reviewed EML sidecar", {
  skip_if_not_installed("emld")

  package_path <- make_knb_test_sdp(withr::local_tempdir())
  mapping_path <- file.path(package_path, "metadata", "eml-mapping.yml")
  mapping <- yaml::read_yaml(mapping_path)
  mapping$publication$public <- FALSE
  yaml::write_yaml(mapping, mapping_path)

  expect_error(
    publish_sdp_to_knb(
      package_path,
      public = TRUE,
      dry_run = TRUE
    ),
    "publication\\.public.*public"
  )
})

test_that("only an authoritative 404 means a DataONE identifier is absent", {
  expect_identical(
    .ms_knb_lookup_http_status(404L, "urn:uuid:missing", "PID"),
    "absent"
  )
  expect_identical(
    .ms_knb_lookup_http_status(200L, "urn:uuid:present", "PID"),
    "present"
  )
  for (status in c(403L, 500L, 502L, 504L)) {
    expect_error(
      .ms_knb_lookup_http_status(status, "urn:uuid:ambiguous", "PID"),
      "ambiguous.*HTTP"
    )
  }
})

test_that("anonymous KNB requests never inherit DataONE credentials", {
  withr::local_options(list(
    dataone_token = paste0(
      "eyJhbGciOiJSUzI1NiJ9.",
      "eyJzdWIiOiJhbm9ueW1vdXMtdGVzdCJ9.",
      "signature"
    )
  ))
  request <- .ms_knb_public_request("https://example.invalid")
  expect_length(request$headers, 0L)
  expect_false(any(tolower(names(request$headers)) %in% c(
    "authorization",
    "cookie"
  )))
  expect_false(any(tolower(names(request$options)) %in% c(
    "sslcert",
    "sslkey",
    "cookie",
    "cookiefile",
    "cookiejar"
  )))
})

test_that("KNB capabilities pin node identity, endpoint, storage, and writability", {
  capabilities <- xml2::read_xml(
    paste0(
      '<node xmlns="http://ns.dataone.org/service/types/v1">',
      "<identifier>urn:node:KNB</identifier>",
      "<baseURL>https://example.invalid/knb/d1/mn</baseURL>",
      "<services>",
      '<service name="MNStorage" version="v2" available="true"/>',
      "</services>",
      "<properties>",
      '<property key="read_only_mode">false</property>',
      "</properties>",
      "</node>"
    )
  )
  expect_silent(.ms_knb_validate_live_capabilities(
    capabilities,
    "https://example.invalid/knb/d1/mn/v2",
    "urn:node:KNB"
  ))
  expect_error(
    .ms_knb_validate_live_capabilities(
      capabilities,
      "https://example.invalid/other/mn/v2",
      "urn:node:KNB"
    ),
    "unexpected service endpoint"
  )
  expect_error(
    .ms_knb_validate_live_capabilities(
      capabilities,
      "https://example.invalid/knb/d1/mn/v2",
      "urn:node:OTHER"
    ),
    "did not identify"
  )
})

test_that("default KNB connection validates anonymous capabilities before authentication", {
  skip_if_not_installed("dataone")
  skip_if_not_installed("datapack")
  skip_if_not_installed("XML")

  adapter <- .ms_knb_default_adapter()
  client <- adapter$connect("PROD", "urn:node:KNB")
  expect_true(is.environment(client))
  expect_identical(client$endpoint, .ms_knb_mn_endpoint)
  expect_null(client$d1_client)

  withr::local_options(list(dataone_token = NULL))
  observed <- character()
  expect_error(
    with_mocked_bindings(
      .ms_knb_anonymous_capabilities = function(endpoint) {
        observed <<- c(observed, paste0("capabilities:", endpoint))
        stop("capability sentinel")
      },
      adapter$preflight(client),
      .package = "metasalmon"
    ),
    "capability sentinel"
  )
  expect_identical(
    observed,
    paste0("capabilities:", .ms_knb_mn_endpoint)
  )
  expect_null(client$d1_client)
})

test_that("default catalog graph lookup uses the authenticated client boundary", {
  skip_if_not_installed("dataone")
  skip_if_not_installed("datapack")
  skip_if_not_installed("XML")

  adapter <- .ms_knb_default_adapter()
  pid <- "urn:uuid:11111111-1111-5111-8111-111111111111"
  plan <- list(objects = list(list(pid = pid)))
  authenticated_client <- new.env(parent = emptyenv())
  calls <- character()
  body <- jsonlite::toJSON(
    list(response = list(docs = list(list(id = pid)))),
    auto_unbox = TRUE
  )
  response <- structure(
    list(
      content = charToRaw(body),
      headers = list(`content-type` = "application/json"),
      status_code = 200L,
      url = "https://cn.dataone.org/cn/v2/query/solr/"
    ),
    class = "response"
  )

  records <- with_mocked_bindings(
    .ms_knb_authenticated_client = function(client) {
      calls <<- c(calls, "authenticated-client")
      authenticated_client
    },
    .ms_knb_authenticated_catalog_request = function(client, value) {
      calls <<- c(calls, "authenticated-catalog")
      expect_identical(client, authenticated_client)
      expect_identical(value, plan)
      response
    },
    .ms_knb_public_request = function(url) {
      stop("credential-free request used for authenticated catalog")
    },
    adapter$catalog_lookup(new.env(parent = emptyenv()), plan),
    .package = "metasalmon"
  )

  expect_identical(calls, c(
    "authenticated-client",
    "authenticated-catalog"
  ))
  expect_identical(records[[1]]$id, pid)
})

test_that("default PID lookup checks both KNB and the Coordinating Node", {
  skip_if_not_installed("dataone")

  member_node <- methods::new("MNode")
  member_node@identifier <- "urn:node:KNB"
  coordinating_node <- dataone::CNode("PROD")
  client <- methods::new(
    "D1Client",
    mn = member_node,
    cn = coordinating_node
  )
  observed <- character()
  result <- with_mocked_bindings(
    .ms_knb_authenticated_client = function(value) client,
    .ms_knb_lookup_node_system_metadata = function(node,
                                                   identifier,
                                                   kind) {
      observed <<- c(observed, node@identifier)
      NULL
    },
    .ms_knb_lookup_pid_default(new.env(), "urn:uuid:absent"),
    .package = "metasalmon"
  )

  expect_null(result)
  expect_identical(
    observed,
    c("urn:node:KNB", coordinating_node@identifier)
  )
})

test_that("publication paths are contained, distinct, and owned", {
  skip_if_not_installed("emld")

  package_path <- make_knb_test_sdp(withr::local_tempdir())
  outside_parent <- file.path(
    dirname(package_path),
    paste0(basename(package_path), "-outside"),
    "new"
  )
  outside_manifest <- file.path(outside_parent, "manifest.json")
  expect_error(
    publish_sdp_to_knb(
      package_path,
      public = TRUE,
      manifest_path = outside_manifest,
      dry_run = TRUE
    ),
    "inside the SDP directory"
  )
  expect_false(dir.exists(outside_parent))

  expect_error(
    publish_sdp_to_knb(
      package_path,
      eml_path = file.path(package_path, "data", "counts.csv"),
      public = TRUE,
      dry_run = TRUE
    ),
    "path collision"
  )
  expect_error(
    publish_sdp_to_knb(
      package_path,
      manifest_path = file.path(package_path, "metadata", "eml.xml"),
      public = TRUE,
      dry_run = TRUE
    ),
    "path collision"
  )
  expect_error(
    publish_sdp_to_knb(
      package_path,
      manifest_path = file.path(
        package_path,
        "publication",
        "resource-map.rdf"
      ),
      public = TRUE,
      dry_run = TRUE
    ),
    "path collision"
  )

  resource_map_path <- file.path(
    package_path,
    "publication",
    "resource-map.rdf"
  )
  dir.create(dirname(resource_map_path), recursive = TRUE)
  writeLines("unowned sentinel", resource_map_path)
  expect_error(
    publish_sdp_to_knb(
      package_path,
      public = TRUE,
      dry_run = TRUE
    ),
    "pre-existing.*resource map.*not owned"
  )
  expect_identical(readLines(resource_map_path), "unowned sentinel")
})

test_that("dot segments in declared data paths are rejected", {
  skip_if_not_installed("emld")

  package_path <- make_knb_test_sdp(withr::local_tempdir())
  tables_path <- file.path(package_path, "metadata", "tables.csv")
  tables <- readr::read_csv(tables_path, show_col_types = FALSE)
  tables$file_name[[1]] <- "data/../data/counts.csv"
  readr::write_csv(tables, tables_path, na = "")

  expect_error(
    publish_sdp_to_knb(
      package_path,
      public = TRUE,
      dry_run = TRUE
    ),
    "dot path segment"
  )
})

test_that("dot segments in publication artifact paths are rejected", {
  skip_if_not_installed("emld")

  package_path <- make_knb_test_sdp(withr::local_tempdir())
  expect_error(
    publish_sdp_to_knb(
      package_path,
      manifest_path = file.path(
        package_path,
        "publication",
        "..",
        "publication",
        "knb-manifest.json"
      ),
      public = TRUE,
      dry_run = TRUE
    ),
    "dot path segment"
  )
})

make_knb_memory_adapter <- function(manifest_path,
                                    state = NULL,
                                    fail_role = NULL,
                                    preflight_error = NULL,
                                    preflight_warning = NULL,
                                    anonymous_private_status = NULL,
                                    anonymous_private_metadata_status =
                                      anonymous_private_status,
                                    subject =
                                      "http://orcid.org/0000-0001-9317-0364") {
  if (is.null(state)) {
    state <- new.env(parent = emptyenv())
    state$objects <- list()
    state$series <- list()
    state$calls <- character()
    state$catalog <- TRUE
  }

  record <- function(value) {
    state$calls <- c(state$calls, value)
  }
  catalog_records <- function(plan, setting) {
    if (is.list(setting)) {
      return(setting)
    }
    if (!isTRUE(setting)) {
      return(list())
    }
    data_pids <- vapply(
      plan$objects[vapply(
        plan$objects,
        function(object) identical(object$role, "data"),
        logical(1)
      )],
      function(object) object$pid,
      character(1)
    )
    records <- list(
      list(id = plan$resource_map_pid),
      list(
        id = plan$metadata_pid,
        resourceMap = plan$resource_map_pid,
        documents = data_pids
      )
    )
    c(
      records,
      lapply(data_pids, function(pid) {
        list(
          id = pid,
          resourceMap = plan$resource_map_pid,
          isDocumentedBy = plan$metadata_pid
        )
      }),
      lapply(
        setdiff(
          vapply(
            plan$objects,
            function(object) object$pid,
            character(1)
          ),
          c(plan$resource_map_pid, plan$metadata_pid, data_pids)
        ),
        function(pid) {
          list(
            id = pid,
            resourceMap = plan$resource_map_pid
          )
        }
      )
    )
  }
  normalize_system_metadata <- function(object, subject, public) {
    list(
      serial_version = 1,
      identifier = object$pid,
      format_id = object$format_id,
      size = object$size,
      checksum = object$sha256,
      checksum_algorithm = "SHA-256",
      submitter = subject,
      rights_holder = subject,
      access = if (isTRUE(public)) {
        list(list(subject = "public", permission = "read"))
      } else {
        list()
      },
      replication_allowed = object$replication_policy$replication_allowed,
      number_replicas = object$replication_policy$number_replicas,
      preferred_member_nodes =
        object$replication_policy$preferred_member_nodes,
      blocked_member_nodes =
        object$replication_policy$blocked_member_nodes,
      series_id = .ms_knb_optional_scalar(object$series_id),
      media_type = object$media_type,
      file_name = basename(object$path),
      archived = FALSE,
      obsoletes = NA_character_,
      obsoleted_by = NA_character_,
      date_uploaded = "2026-07-31T00:00:00Z",
      date_sys_metadata_modified = "2026-07-31T00:00:00Z",
      origin_member_node = "urn:node:KNB",
      authoritative_member_node = "urn:node:KNB"
    )
  }

  adapter <- list(
    connect = function(environment, node_id) {
      manifest <- jsonlite::read_json(manifest_path, simplifyVector = TRUE)
      state$connect_manifest_statuses <- c(
        state$connect_manifest_statuses,
        manifest$status
      )
      record(paste("connect", environment, node_id, sep = ":"))
      list(endpoint = "https://example.invalid/mn/v2")
    },
    preflight = function(client) {
      record("preflight")
      if (!is.null(preflight_error)) {
        stop(preflight_error)
      }
      if (!is.null(preflight_warning)) {
        warning(preflight_warning, call. = FALSE)
      }
      list(
        subject = subject,
        endpoint = client$endpoint,
        node_id = "urn:node:KNB"
      )
    },
    list_formats = function(client) {
      record("formats")
      manifest <- jsonlite::read_json(
        manifest_path,
        simplifyVector = TRUE
      )
      unique(vapply(
        .ms_knb_manifest_objects(manifest),
        function(object) as.character(object$format_id),
        character(1)
      ))
    },
    lookup_system_metadata = function(client, pid) {
      record(paste0("lookup:", pid))
      object <- state$objects[[pid]]
      if (is.null(object)) NULL else object$system_metadata
    },
    lookup_series_id = function(client, series_id) {
      record(paste0("series:", series_id))
      state$series[[series_id]]
    },
    create_object = function(client, object_spec, subject, public) {
      record(paste0("create:", object_spec$role))
      if (!is.null(fail_role) &&
          identical(object_spec$role, fail_role) &&
          !isTRUE(state$failed_once)) {
        state$failed_once <- TRUE
        stop("injected create failure")
      }
      state$objects[[object_spec$pid]] <- list(
        bytes = object_spec$bytes,
        system_metadata = normalize_system_metadata(
          object_spec,
          subject,
          public
        )
      )
      series_id <- .ms_knb_optional_scalar(object_spec$series_id)
      if (!is.na(series_id)) {
        state$series[[series_id]] <-
          state$objects[[object_spec$pid]]$system_metadata
      }
      object_spec$pid
    },
    get_bytes = function(client, pid) {
      record(paste0("bytes:", pid))
      state$objects[[pid]]$bytes
    },
    get_system_metadata = function(client, pid) {
      record(paste0("metadata:", pid))
      state$objects[[pid]]$system_metadata
    },
    get_checksum = function(client, pid, algorithm) {
      record(paste0("checksum:", pid))
      state$objects[[pid]]$system_metadata$checksum
    },
    get_anonymous_bytes = function(endpoint, pid) {
      record(paste0("anonymous-bytes:", pid))
      object <- state$objects[[pid]]
      if (!is.null(anonymous_private_status) &&
          length(object$system_metadata$access) == 0L) {
        condition <- structure(
          list(message = "anonymous access denied", call = NULL),
          class = c(
            paste0("httr2_http_", anonymous_private_status),
            "error",
            "condition"
          )
        )
        stop(condition)
      }
      object$bytes
    },
    get_anonymous_system_metadata = function(endpoint, pid) {
      record(paste0("anonymous-metadata:", pid))
      object <- state$objects[[pid]]
      if (!is.null(anonymous_private_metadata_status) &&
          length(object$system_metadata$access) == 0L) {
        condition <- structure(
          list(message = "anonymous access denied", call = NULL),
          class = c(
            paste0(
              "httr2_http_",
              anonymous_private_metadata_status
            ),
            "error",
            "condition"
          )
        )
        stop(condition)
      }
      object$system_metadata
    },
    catalog_lookup = function(client, plan) {
      record(paste0("catalog:", plan$metadata_pid))
      catalog_records(plan, state$catalog)
    },
    anonymous_catalog_lookup = function(plan) {
      record(paste0("anonymous-catalog:", plan$metadata_pid))
      setting <- state$anonymous_catalog
      if (is.null(setting)) {
        setting <- isTRUE(plan$public)
      }
      catalog_records(plan, setting)
    }
  )
  list(adapter = adapter, state = state)
}

review_knb_plan <- function(package_path,
                            manifest_path,
                            public = TRUE) {
  publish_sdp_to_knb(
    package_path,
    public = public,
    manifest_path = manifest_path,
    dry_run = TRUE
  )
}

test_that("private-review publication refuses anonymously readable objects", {
  skip_if_not_installed("emld")

  package_path <- make_knb_test_sdp(withr::local_tempdir())
  mapping_path <- file.path(package_path, "metadata", "eml-mapping.yml")
  mapping <- yaml::read_yaml(mapping_path)
  mapping$publication$public <- FALSE
  mapping$rights_authorization$status <- "unconfirmed"
  mapping$rights_authorization$evidence <-
    "Redistribution authority is unresolved; this fixture tests access only."
  yaml::write_yaml(mapping, mapping_path)

  manifest_path <- file.path(
    package_path,
    "publication",
    "knb-manifest.json"
  )
  review_knb_plan(package_path, manifest_path, public = FALSE)
  memory <- make_knb_memory_adapter(manifest_path)
  withr::local_options(list(metasalmon.knb_adapter = memory$adapter))

  expect_error(
    publish_sdp_to_knb(
      package_path,
      public = FALSE,
      manifest_path = manifest_path,
      dry_run = FALSE,
      confirm = TRUE
    ),
    "Anonymous byte access unexpectedly succeeded"
  )
  expect_true(any(startsWith(
    memory$state$calls,
    "anonymous-bytes:"
  )))
})

test_that("private-review publication verifies anonymous non-disclosure for every object", {
  skip_if_not_installed("emld")

  package_path <- make_knb_test_sdp(withr::local_tempdir())
  mapping_path <- file.path(package_path, "metadata", "eml-mapping.yml")
  mapping <- yaml::read_yaml(mapping_path)
  mapping$publication$public <- FALSE
  mapping$rights_authorization$status <- "unconfirmed"
  mapping$rights_authorization$evidence <-
    "Redistribution authority is unresolved; this fixture tests access only."
  yaml::write_yaml(mapping, mapping_path)

  manifest_path <- file.path(
    package_path,
    "publication",
    "knb-manifest.json"
  )
  review_knb_plan(package_path, manifest_path, public = FALSE)
  memory <- make_knb_memory_adapter(
    manifest_path,
    anonymous_private_status = 403L
  )
  withr::local_options(list(metasalmon.knb_adapter = memory$adapter))

  result <- publish_sdp_to_knb(
    package_path,
    public = FALSE,
    manifest_path = manifest_path,
    dry_run = FALSE,
    confirm = TRUE
  )

  expect_equal(result$status, "published")
  manifest <- jsonlite::read_json(manifest_path, simplifyVector = FALSE)
  objects <- .ms_knb_manifest_objects(manifest)
  expect_equal(manifest$status, "complete")
  expect_false(isTRUE(manifest$public))
  expect_true(manifest$catalog_evidence$authenticated$verified)
  expect_true(manifest$catalog_evidence$anonymous$verified)
  expect_length(
    manifest$catalog_evidence$anonymous$matching_pids,
    0L
  )
  expect_equal(
    sum(startsWith(memory$state$calls, "anonymous-bytes:")),
    length(objects)
  )
  expect_equal(
    sum(startsWith(memory$state$calls, "anonymous-metadata:")),
    length(objects)
  )
})

test_that("private-review plans and SystemMetadata explicitly disable replication", {
  skip_if_not_installed("emld")
  skip_if_not_installed("datapack")

  package_path <- make_knb_test_sdp(withr::local_tempdir())
  mapping_path <- file.path(package_path, "metadata", "eml-mapping.yml")
  mapping <- yaml::read_yaml(mapping_path)
  mapping$publication$public <- FALSE
  yaml::write_yaml(mapping, mapping_path)
  manifest_path <- file.path(
    package_path,
    "publication",
    "knb-manifest.json"
  )
  dry_run <- review_knb_plan(
    package_path,
    manifest_path,
    public = FALSE
  )
  expected_policy <- list(
    replication_allowed = FALSE,
    number_replicas = 0L,
    preferred_member_nodes = list(),
    blocked_member_nodes = list()
  )
  expect_identical(
    dry_run$manifest$replication_policy,
    expected_policy
  )
  altered_plan <- dry_run$manifest
  altered_plan$replication_policy$number_replicas <- 1L
  expect_false(identical(
    .ms_knb_plan_fingerprint(altered_plan),
    dry_run$manifest$plan_sha256
  ))

  object <- dry_run$manifest$objects[[1]]
  system_metadata <- .ms_knb_new_system_metadata(
    object,
    "https://orcid.org/0000-0001-9317-0364",
    public = FALSE,
    node_id = "urn:node:KNB",
    replication_policy = dry_run$manifest$replication_policy
  )
  xml <- datapack::serializeSystemMetadata(
    system_metadata,
    version = "v2"
  ) |>
    xml2::read_xml()
  policy <- xml2::xml_find_first(
    xml,
    "//*[local-name()='replicationPolicy']"
  )

  expect_identical(xml2::xml_attr(policy, "replicationAllowed"), "false")
  expect_identical(xml2::xml_attr(policy, "numberReplicas"), "0")
  expect_length(
    xml2::xml_find_all(policy, "./*[local-name()='preferredMemberNode']"),
    0L
  )
  expect_length(
    xml2::xml_find_all(policy, "./*[local-name()='blockedMemberNode']"),
    0L
  )
})

test_that("private-review resume rejects permissive remote replication", {
  skip_if_not_installed("emld")

  package_path <- make_knb_test_sdp(withr::local_tempdir())
  mapping_path <- file.path(package_path, "metadata", "eml-mapping.yml")
  mapping <- yaml::read_yaml(mapping_path)
  mapping$publication$public <- FALSE
  yaml::write_yaml(mapping, mapping_path)
  manifest_path <- file.path(
    package_path,
    "publication",
    "knb-manifest.json"
  )
  review_knb_plan(package_path, manifest_path, public = FALSE)
  memory <- make_knb_memory_adapter(
    manifest_path,
    anonymous_private_status = 403L
  )
  withr::local_options(list(
    metasalmon.knb_adapter = function() memory$adapter
  ))
  published <- publish_sdp_to_knb(
    package_path,
    public = FALSE,
    manifest_path = manifest_path,
    dry_run = FALSE,
    confirm = TRUE
  )

  first_pid <- published$manifest$objects[[1]]$pid
  memory$state$objects[[first_pid]]$system_metadata$replication_allowed <- TRUE
  memory$state$objects[[first_pid]]$system_metadata$number_replicas <- 3
  memory$state$calls <- character()

  expect_error(
    publish_sdp_to_knb(
      package_path,
      public = FALSE,
      manifest_path = manifest_path,
      dry_run = FALSE,
      confirm = TRUE
    ),
    "replication_allowed|number_replicas"
  )
  expect_false(any(startsWith(memory$state$calls, "create:")))
})

test_that("private-review publication refuses anonymously readable SystemMetadata", {
  skip_if_not_installed("emld")

  package_path <- make_knb_test_sdp(withr::local_tempdir())
  mapping_path <- file.path(package_path, "metadata", "eml-mapping.yml")
  mapping <- yaml::read_yaml(mapping_path)
  mapping$publication$public <- FALSE
  yaml::write_yaml(mapping, mapping_path)

  manifest_path <- file.path(
    package_path,
    "publication",
    "knb-manifest.json"
  )
  review_knb_plan(package_path, manifest_path, public = FALSE)
  memory <- make_knb_memory_adapter(
    manifest_path,
    anonymous_private_status = 403L,
    anonymous_private_metadata_status = NULL
  )
  withr::local_options(list(metasalmon.knb_adapter = memory$adapter))

  expect_error(
    publish_sdp_to_knb(
      package_path,
      public = FALSE,
      manifest_path = manifest_path,
      dry_run = FALSE,
      confirm = TRUE
    ),
    "Anonymous SystemMetadata access unexpectedly succeeded"
  )
  expect_true(any(startsWith(
    memory$state$calls,
    "anonymous-metadata:"
  )))
})

test_that("private-review publication refuses anonymously discoverable catalog objects", {
  skip_if_not_installed("emld")

  package_path <- make_knb_test_sdp(withr::local_tempdir())
  mapping_path <- file.path(package_path, "metadata", "eml-mapping.yml")
  mapping <- yaml::read_yaml(mapping_path)
  mapping$publication$public <- FALSE
  yaml::write_yaml(mapping, mapping_path)

  manifest_path <- file.path(
    package_path,
    "publication",
    "knb-manifest.json"
  )
  review_knb_plan(package_path, manifest_path, public = FALSE)
  memory <- make_knb_memory_adapter(
    manifest_path,
    anonymous_private_status = 403L
  )
  memory$state$anonymous_catalog <- TRUE
  withr::local_options(list(metasalmon.knb_adapter = memory$adapter))

  expect_error(
    publish_sdp_to_knb(
      package_path,
      public = FALSE,
      manifest_path = manifest_path,
      dry_run = FALSE,
      confirm = TRUE
    ),
    "Anonymous catalog unexpectedly exposed private-review PID"
  )
  expect_equal(
    sum(startsWith(memory$state$calls, "catalog:")),
    1L
  )
  expect_equal(
    sum(startsWith(memory$state$calls, "anonymous-catalog:")),
    1L
  )
  manifest <- jsonlite::read_json(
    manifest_path,
    simplifyVector = FALSE
  )
  expect_equal(manifest$status, "published_pending_catalog")
  expect_false(manifest$catalog_verified)
  expect_setequal(
    unlist(
      manifest$catalog_evidence$anonymous$matching_pids,
      use.names = FALSE
    ),
    vapply(
      manifest$objects,
      function(object) object$pid,
      character(1)
    )
  )
})

test_that("live KNB publication requires an exact pre-existing dry run", {
  skip_if_not_installed("emld")

  package_path <- make_knb_test_sdp(withr::local_tempdir())
  manifest_path <- file.path(package_path, "publication", "knb-manifest.json")
  adapter_accessed <- FALSE
  withr::local_options(list(
    metasalmon.knb_adapter = function() {
      adapter_accessed <<- TRUE
      stop("adapter accessed")
    }
  ))

  expect_error(
    publish_sdp_to_knb(
      package_path,
      public = TRUE,
      manifest_path = manifest_path,
      dry_run = FALSE,
      confirm = TRUE
    ),
    "matching reviewed dry-run manifest"
  )
  expect_false(adapter_accessed)
})

test_that("live private publication requires the reviewed schema-v2 policy", {
  skip_if_not_installed("emld")

  package_path <- make_knb_test_sdp(withr::local_tempdir())
  mapping_path <- file.path(package_path, "metadata", "eml-mapping.yml")
  mapping <- yaml::read_yaml(mapping_path)
  mapping$publication$public <- FALSE
  yaml::write_yaml(mapping, mapping_path)
  manifest_path <- file.path(package_path, "publication", "knb-manifest.json")
  review_knb_plan(package_path, manifest_path, public = FALSE)

  manifest <- jsonlite::read_json(manifest_path, simplifyVector = FALSE)
  manifest$schema_version <- 1L
  manifest$replication_policy <- NULL
  jsonlite::write_json(
    manifest,
    manifest_path,
    auto_unbox = TRUE,
    null = "null",
    pretty = TRUE
  )
  adapter_accessed <- FALSE
  withr::local_options(list(
    metasalmon.knb_adapter = function() {
      adapter_accessed <<- TRUE
      stop("adapter accessed")
    }
  ))

  expect_error(
    publish_sdp_to_knb(
      package_path,
      public = FALSE,
      manifest_path = manifest_path,
      dry_run = FALSE,
      confirm = TRUE
    ),
    "schema version 2.*replication policy"
  )
  expect_false(adapter_accessed)
})

test_that("confirm approves the plan but does not substitute for rights evidence", {
  skip_if_not_installed("emld")

  package_path <- make_knb_test_sdp(withr::local_tempdir())
  mapping_path <- file.path(package_path, "metadata", "eml-mapping.yml")
  mapping <- yaml::read_yaml(mapping_path)
  mapping$rights_authorization$status <- "unconfirmed"
  mapping$rights_authorization$evidence <-
    "Redistribution authorization has not yet been confirmed."
  yaml::write_yaml(mapping, mapping_path)
  manifest_path <- file.path(package_path, "publication", "knb-manifest.json")
  review_knb_plan(package_path, manifest_path)
  adapter_accessed <- FALSE
  withr::local_options(list(
    metasalmon.knb_adapter = function() {
      adapter_accessed <<- TRUE
      stop("adapter accessed")
    }
  ))

  expect_error(
    publish_sdp_to_knb(
      package_path,
      public = TRUE,
      manifest_path = manifest_path,
      dry_run = FALSE,
      confirm = TRUE
    ),
    "confirmed redistribution rights"
  )
  expect_false(adapter_accessed)
})

test_that("live KNB path writes pending first, uploads in order, and verifies", {
  skip_if_not_installed("emld")

  package_path <- make_knb_test_sdp(withr::local_tempdir())
  manifest_path <- file.path(package_path, "publication", "knb-manifest.json")
  review_knb_plan(package_path, manifest_path)
  memory <- make_knb_memory_adapter(manifest_path)
  withr::local_options(list(
    metasalmon.knb_adapter = function() memory$adapter
  ))

  result <- publish_sdp_to_knb(
    package_path,
    public = TRUE,
    manifest_path = manifest_path,
    dry_run = FALSE,
    confirm = TRUE
  )

  expect_equal(result$status, "published")
  expect_equal(
    memory$state$calls[startsWith(memory$state$calls, "create:")],
    paste0(
      "create:",
      vapply(result$manifest$objects, function(object) {
        object$role
      }, character(1))
    )
  )
  first_create <- which(startsWith(memory$state$calls, "create:"))[[1]]
  lookup_positions <- which(startsWith(memory$state$calls, "lookup:"))
  format_position <- which(memory$state$calls == "formats")[[1]]
  expect_equal(
    length(lookup_positions),
    length(result$manifest$objects)
  )
  expect_true(all(format_position < lookup_positions))
  expect_true(all(lookup_positions < first_create))
  expect_true(
    which(startsWith(memory$state$calls, "series:"))[[1]] <
      first_create
  )
  manifest <- jsonlite::read_json(manifest_path, simplifyVector = TRUE)
  expect_equal(manifest$status, "complete")
  expect_true(manifest$catalog_verified)
  expect_true(all(manifest$objects$state == "verified"))
  expect_equal(
    length(memory$state$objects),
    length(result$manifest$objects)
  )
  expect_equal(
    sum(startsWith(memory$state$calls, "anonymous-bytes:")),
    length(result$manifest$objects)
  )
  expect_equal(
    sum(startsWith(memory$state$calls, "anonymous-metadata:")),
    length(result$manifest$objects)
  )
  expect_equal(
    sum(startsWith(memory$state$calls, "catalog:")),
    1L
  )
  expect_equal(
    sum(startsWith(memory$state$calls, "anonymous-catalog:")),
    1L
  )
  expect_equal(memory$state$connect_manifest_statuses[[1]], "pending")
})

test_that("identical completed retry verifies remotely and creates nothing", {
  skip_if_not_installed("emld")

  package_path <- make_knb_test_sdp(withr::local_tempdir())
  manifest_path <- file.path(package_path, "publication", "knb-manifest.json")
  review_knb_plan(package_path, manifest_path)
  memory <- make_knb_memory_adapter(manifest_path)
  withr::local_options(list(
    metasalmon.knb_adapter = function() memory$adapter
  ))
  publish_sdp_to_knb(
    package_path,
    public = TRUE,
    manifest_path = manifest_path,
    dry_run = FALSE,
    confirm = TRUE
  )
  creates_before <- sum(startsWith(memory$state$calls, "create:"))

  result <- publish_sdp_to_knb(
    package_path,
    public = TRUE,
    manifest_path = manifest_path,
    dry_run = FALSE,
    confirm = TRUE
  )

  expect_equal(result$status, "already_published")
  expect_equal(
    sum(startsWith(memory$state$calls, "create:")),
    creates_before
  )
})

test_that("partial KNB failure is recoverable with the same immutable PIDs", {
  skip_if_not_installed("emld")

  package_path <- make_knb_test_sdp(withr::local_tempdir())
  manifest_path <- file.path(package_path, "publication", "knb-manifest.json")
  reviewed <- review_knb_plan(package_path, manifest_path)
  memory <- make_knb_memory_adapter(
    manifest_path,
    fail_role = "metadata"
  )
  withr::local_options(list(
    metasalmon.knb_adapter = function() memory$adapter
  ))

  expect_error(
    publish_sdp_to_knb(
      package_path,
      public = TRUE,
      manifest_path = manifest_path,
      dry_run = FALSE,
      confirm = TRUE
    ),
    "injected create failure"
  )
  failed_manifest <- jsonlite::read_json(
    manifest_path,
    simplifyVector = TRUE
  )
  expect_equal(
    failed_manifest$objects$state,
    ifelse(
      seq_along(failed_manifest$objects$role) <
        match("metadata", failed_manifest$objects$role),
      "verified",
      "planned"
    )
  )

  result <- publish_sdp_to_knb(
    package_path,
    public = TRUE,
    manifest_path = manifest_path,
    dry_run = FALSE,
    confirm = TRUE
  )
  expect_equal(result$status, "published")
  expect_equal(
    memory$state$calls[startsWith(memory$state$calls, "create:")],
    c(
      paste0(
        "create:",
        vapply(reviewed$manifest$objects, function(object) {
          object$role
        }, character(1))[
          seq_len(match(
            "metadata",
            vapply(reviewed$manifest$objects, function(object) {
              object$role
            }, character(1))
          ))
        ]
      ),
      "create:metadata",
      "create:resource_map"
    )
  )
})

test_that("preflight failures make no creates and redact JWT-like secrets", {
  skip_if_not_installed("emld")

  package_path <- make_knb_test_sdp(withr::local_tempdir())
  manifest_path <- file.path(package_path, "publication", "knb-manifest.json")
  review_knb_plan(package_path, manifest_path)
  sentinel <- paste0(
    "eyJhbGciOiJSUzI1NiJ9.",
    "eyJzdWIiOiJzZWNyZXQtc3ViamVjdCJ9.",
    "signatureSecret"
  )
  memory <- make_knb_memory_adapter(
    manifest_path,
    preflight_error = paste("authentication failed for", sentinel)
  )
  withr::local_options(list(
    metasalmon.knb_adapter = function() memory$adapter
  ))

  error <- expect_error(
    publish_sdp_to_knb(
      package_path,
      public = TRUE,
      manifest_path = manifest_path,
      dry_run = FALSE,
      confirm = TRUE
    )
  )
  expect_false(grepl(sentinel, conditionMessage(error), fixed = TRUE))
  expect_false(any(startsWith(memory$state$calls, "create:")))
  expect_false(grepl(
    sentinel,
    paste(readLines(manifest_path, warn = FALSE), collapse = "\n"),
    fixed = TRUE
  ))
})

test_that("remote error text is never evaluated as a cli template", {
  skip_if_not_installed("emld")

  package_path <- make_knb_test_sdp(withr::local_tempdir())
  manifest_path <- file.path(package_path, "publication", "knb-manifest.json")
  review_knb_plan(package_path, manifest_path)
  fake_secret <- "TEST_ONLY_DATAONE_TOKEN_SECRET"
  memory <- make_knb_memory_adapter(
    manifest_path,
    preflight_error = 'remote {getOption("dataone_token")}'
  )
  withr::local_options(list(
    dataone_token = fake_secret,
    metasalmon.knb_adapter = function() memory$adapter
  ))

  error <- expect_error(
    publish_sdp_to_knb(
      package_path,
      public = TRUE,
      manifest_path = manifest_path,
      dry_run = FALSE,
      confirm = TRUE
    )
  )
  message <- conditionMessage(error)
  expect_false(grepl(fake_secret, message, fixed = TRUE))
  expect_match(
    message,
    '\\{getOption\\("dataone_token"\\)\\}'
  )
  expect_false(any(startsWith(memory$state$calls, "create:")))
})

test_that("live adapter warnings abort without leaking token material", {
  skip_if_not_installed("emld")

  package_path <- make_knb_test_sdp(withr::local_tempdir())
  manifest_path <- file.path(package_path, "publication", "knb-manifest.json")
  review_knb_plan(package_path, manifest_path)
  sentinel <- paste0(
    "eyJhbGciOiJSUzI1NiJ9.",
    "eyJzdWIiOiJ3YXJuaW5nLXNlY3JldCJ9.",
    "warningSignature"
  )
  memory <- make_knb_memory_adapter(
    manifest_path,
    preflight_warning = paste("warning contains", sentinel)
  )
  withr::local_options(list(
    metasalmon.knb_adapter = function() memory$adapter
  ))

  error <- expect_error(
    publish_sdp_to_knb(
      package_path,
      public = TRUE,
      manifest_path = manifest_path,
      dry_run = FALSE,
      confirm = TRUE
    )
  )
  expect_false(grepl(sentinel, conditionMessage(error), fixed = TRUE))
  expect_false(any(startsWith(memory$state$calls, "create:")))
})

test_that("live publication preflights every planned DataONE format ID", {
  skip_if_not_installed("emld")

  package_path <- make_knb_test_sdp(withr::local_tempdir())
  manifest_path <- file.path(package_path, "publication", "knb-manifest.json")
  review_knb_plan(package_path, manifest_path)
  memory <- make_knb_memory_adapter(manifest_path)
  memory$adapter$list_formats <- function(client) {
    c(
      "application/json",
      "text/csv",
      "text/plain",
      "https://eml.ecoinformatics.org/eml-2.2.0"
    )
  }
  withr::local_options(list(
    metasalmon.knb_adapter = function() memory$adapter
  ))

  expect_error(
    publish_sdp_to_knb(
      package_path,
      public = TRUE,
      manifest_path = manifest_path,
      dry_run = FALSE,
      confirm = TRUE
    ),
    "format registry lacks.*openarchives"
  )
  expect_false(any(startsWith(memory$state$calls, "create:")))
})

test_that("server-verified identity must match the EML metadata provider", {
  skip_if_not_installed("emld")

  package_path <- make_knb_test_sdp(withr::local_tempdir())
  manifest_path <- file.path(package_path, "publication", "knb-manifest.json")
  review_knb_plan(package_path, manifest_path)
  memory <- make_knb_memory_adapter(
    manifest_path,
    subject = "http://orcid.org/0000-0002-1825-0097"
  )
  withr::local_options(list(
    metasalmon.knb_adapter = function() memory$adapter
  ))

  expect_error(
    publish_sdp_to_knb(
      package_path,
      public = TRUE,
      manifest_path = manifest_path,
      dry_run = FALSE,
      confirm = TRUE
    ),
    "server-verified DataONE subject.*metadata-provider ORCID"
  )
  expect_false(any(startsWith(memory$state$calls, "create:")))
})

test_that("a remote PID collision stops before any new object is created", {
  skip_if_not_installed("emld")

  package_path <- make_knb_test_sdp(withr::local_tempdir())
  manifest_path <- file.path(package_path, "publication", "knb-manifest.json")
  dry_run <- publish_sdp_to_knb(
    package_path,
    public = TRUE,
    manifest_path = manifest_path,
    dry_run = TRUE
  )
  first <- dry_run$manifest$objects[[1]]
  memory <- make_knb_memory_adapter(manifest_path)
  memory$state$objects[[first$pid]] <- list(
    bytes = raw(),
    system_metadata = list(
      identifier = first$pid,
      format_id = "application/octet-stream",
      size = first$size,
      checksum = first$sha256,
      checksum_algorithm = "SHA-256",
      rights_holder = "https://orcid.org/0000-0001-9317-0364",
      access = list(list(subject = "public", permission = "read")),
      series_id = NA_character_
    )
  )
  withr::local_options(list(
    metasalmon.knb_adapter = function() memory$adapter
  ))

  expect_error(
    publish_sdp_to_knb(
      package_path,
      public = TRUE,
      manifest_path = manifest_path,
      dry_run = FALSE,
      confirm = TRUE
    ),
    "collides.*format_id"
  )
  expect_false(any(startsWith(memory$state$calls, "create:")))
})

test_that("a later PID collision is found before any object is created", {
  skip_if_not_installed("emld")

  package_path <- make_knb_test_sdp(withr::local_tempdir())
  manifest_path <- file.path(package_path, "publication", "knb-manifest.json")
  dry_run <- review_knb_plan(package_path, manifest_path)
  last <- dry_run$manifest$objects[[
    length(dry_run$manifest$objects)
  ]]
  memory <- make_knb_memory_adapter(manifest_path)
  memory$state$objects[[last$pid]] <- list(
    bytes = raw(),
    system_metadata = list(
      identifier = last$pid,
      format_id = "application/octet-stream",
      size = last$size,
      checksum = last$sha256,
      checksum_algorithm = "SHA-256",
      rights_holder = "https://orcid.org/0000-0001-9317-0364",
      access = list(list(subject = "public", permission = "read")),
      series_id = NA_character_
    )
  )
  withr::local_options(list(
    metasalmon.knb_adapter = function() memory$adapter
  ))

  expect_error(
    publish_sdp_to_knb(
      package_path,
      public = TRUE,
      manifest_path = manifest_path,
      dry_run = FALSE,
      confirm = TRUE
    ),
    "collides.*format_id"
  )
  expect_false(any(startsWith(memory$state$calls, "create:")))
  expect_equal(
    sum(startsWith(memory$state$calls, "lookup:")),
    length(dry_run$manifest$objects)
  )
})

test_that("metadata series collisions are found before any create", {
  skip_if_not_installed("emld")

  package_path <- make_knb_test_sdp(withr::local_tempdir())
  manifest_path <- file.path(package_path, "publication", "knb-manifest.json")
  dry_run <- review_knb_plan(package_path, manifest_path)
  memory <- make_knb_memory_adapter(manifest_path)
  memory$state$series[[dry_run$manifest$series_id]] <- list(
    identifier = "urn:uuid:a-different-metadata-object",
    series_id = dry_run$manifest$series_id
  )
  withr::local_options(list(
    metasalmon.knb_adapter = function() memory$adapter
  ))

  expect_error(
    publish_sdp_to_knb(
      package_path,
      public = TRUE,
      manifest_path = manifest_path,
      dry_run = FALSE,
      confirm = TRUE
    ),
    "series identifier.*different metadata PID"
  )
  expect_false(any(startsWith(memory$state$calls, "create:")))
})

test_that("catalog lag remains recoverable without re-upload", {
  skip_if_not_installed("emld")

  package_path <- make_knb_test_sdp(withr::local_tempdir())
  manifest_path <- file.path(package_path, "publication", "knb-manifest.json")
  review_knb_plan(package_path, manifest_path)
  memory <- make_knb_memory_adapter(manifest_path)
  memory$state$catalog <- FALSE
  withr::local_options(list(
    metasalmon.knb_adapter = function() memory$adapter
  ))

  pending <- publish_sdp_to_knb(
    package_path,
    public = TRUE,
    manifest_path = manifest_path,
    dry_run = FALSE,
    confirm = TRUE
  )
  expect_equal(pending$status, "published_pending_catalog")
  creates <- sum(startsWith(memory$state$calls, "create:"))

  memory$state$catalog <- TRUE
  complete <- publish_sdp_to_knb(
    package_path,
    public = TRUE,
    manifest_path = manifest_path,
    dry_run = FALSE,
    confirm = TRUE
  )
  expect_equal(complete$status, "published")
  expect_equal(sum(startsWith(memory$state$calls, "create:")), creates)
})

test_that("public catalog completion requires an anonymous full graph", {
  skip_if_not_installed("emld")

  package_path <- make_knb_test_sdp(withr::local_tempdir())
  manifest_path <- file.path(package_path, "publication", "knb-manifest.json")
  review_knb_plan(package_path, manifest_path)
  memory <- make_knb_memory_adapter(manifest_path)
  memory$state$anonymous_catalog <- FALSE
  withr::local_options(list(
    metasalmon.knb_adapter = function() memory$adapter
  ))

  result <- publish_sdp_to_knb(
    package_path,
    public = TRUE,
    manifest_path = manifest_path,
    dry_run = FALSE,
    confirm = TRUE
  )

  expect_equal(result$status, "published_pending_catalog")
  expect_true(result$manifest$catalog_evidence$authenticated$verified)
  expect_false(result$manifest$catalog_evidence$anonymous$verified)
  expect_equal(
    sum(startsWith(memory$state$calls, "catalog:")),
    1L
  )
  expect_equal(
    sum(startsWith(memory$state$calls, "anonymous-catalog:")),
    1L
  )
})

test_that("forged local catalog evidence cannot bypass a fresh failed check", {
  skip_if_not_installed("emld")

  package_path <- make_knb_test_sdp(withr::local_tempdir())
  manifest_path <- file.path(package_path, "publication", "knb-manifest.json")
  review_knb_plan(package_path, manifest_path)
  forged <- jsonlite::read_json(
    manifest_path,
    simplifyVector = FALSE
  )
  forged$catalog_verified <- TRUE
  forged$catalog_evidence <- list(
    verified = TRUE,
    indexed_pids = "forged-local-evidence"
  )
  jsonlite::write_json(
    forged,
    manifest_path,
    auto_unbox = TRUE,
    pretty = TRUE
  )

  memory <- make_knb_memory_adapter(manifest_path)
  memory$state$catalog <- FALSE
  withr::local_options(list(
    metasalmon.knb_adapter = function() memory$adapter
  ))

  result <- publish_sdp_to_knb(
    package_path,
    public = TRUE,
    manifest_path = manifest_path,
    dry_run = FALSE,
    confirm = TRUE
  )

  expect_equal(result$status, "published_pending_catalog")
  expect_equal(result$manifest$status, "published_pending_catalog")
  expect_false(result$manifest$catalog_verified)
  expect_false(
    identical(
      result$manifest$catalog_evidence$authenticated$indexed_pids,
      "forged-local-evidence"
    )
  )
  expect_equal(
    sum(startsWith(memory$state$calls, "catalog:")),
    1L
  )
})

test_that("catalog completion requires every PID and package relationship", {
  skip_if_not_installed("emld")

  missing_relationship_cases <- c(
    "missing_pid",
    "missing_resource_map",
    "missing_documents",
    "missing_documented_by",
    "supplemental_documented_by"
  )
  for (case in missing_relationship_cases) {
    package_path <- make_knb_test_sdp(withr::local_tempdir())
    manifest_path <- file.path(
      package_path,
      "publication",
      "knb-manifest.json"
    )
    reviewed <- review_knb_plan(package_path, manifest_path)
    memory <- make_knb_memory_adapter(manifest_path)
    objects <- reviewed$manifest$objects
    roles <- vapply(objects, function(object) object$role, character(1))
    pids <- vapply(objects, function(object) object$pid, character(1))
    data_pid <- pids[roles == "data"]
    supplemental_pids <- pids[roles == "sdp_artifact"]
    metadata_pid <- reviewed$manifest$metadata_pid
    resource_map_pid <- reviewed$manifest$resource_map_pid
    records <- c(
      list(
        list(id = resource_map_pid),
        list(
          id = metadata_pid,
          resourceMap = resource_map_pid,
          documents = data_pid
        ),
        list(
          id = data_pid,
          resourceMap = resource_map_pid,
          isDocumentedBy = metadata_pid
        )
      ),
      lapply(supplemental_pids, function(pid) {
        list(id = pid, resourceMap = resource_map_pid)
      })
    )
    if (identical(case, "missing_pid")) {
      records <- records[-1]
    } else if (identical(case, "missing_resource_map")) {
      records[[2]]$resourceMap <- NULL
    } else if (identical(case, "missing_documents")) {
      records[[2]]$documents <- NULL
    } else if (identical(case, "missing_documented_by")) {
      records[[3]]$isDocumentedBy <- NULL
    } else {
      record_ids <- vapply(
        records,
        function(record) as.character(record$id),
        character(1)
      )
      supplemental_index <- match(supplemental_pids[[1]], record_ids)
      records[[supplemental_index]]$isDocumentedBy <- metadata_pid
    }
    memory$state$catalog <- records
    withr::local_options(list(
      metasalmon.knb_adapter = function() memory$adapter
    ))

    result <- publish_sdp_to_knb(
      package_path,
      public = TRUE,
      manifest_path = manifest_path,
      dry_run = FALSE,
      confirm = TRUE
    )
    expect_equal(result$status, "published_pending_catalog", info = case)
    expect_false(result$manifest$catalog_verified, info = case)
  }
})

test_that("completed manifest evidence is monotonic across retries", {
  skip_if_not_installed("emld")

  package_path <- make_knb_test_sdp(withr::local_tempdir())
  manifest_path <- file.path(package_path, "publication", "knb-manifest.json")
  review_knb_plan(package_path, manifest_path)
  memory <- make_knb_memory_adapter(manifest_path)
  withr::local_options(list(
    metasalmon.knb_adapter = function() memory$adapter
  ))
  completed <- publish_sdp_to_knb(
    package_path,
    public = TRUE,
    manifest_path = manifest_path,
    dry_run = FALSE,
    confirm = TRUE
  )
  expect_true(completed$manifest$catalog_verified)
  expect_true(length(completed$manifest$catalog_evidence) > 0L)

  dry <- publish_sdp_to_knb(
    package_path,
    public = TRUE,
    manifest_path = manifest_path,
    dry_run = TRUE
  )
  expect_equal(dry$manifest$status, "complete")
  expect_true(dry$manifest$catalog_verified)
  expect_identical(
    dry$manifest$catalog_evidence,
    completed$manifest$catalog_evidence
  )
  expect_true(all(vapply(
    dry$manifest$objects,
    function(object) identical(object$state, "verified"),
    logical(1)
  )))

  failing <- make_knb_memory_adapter(
    manifest_path,
    state = memory$state,
    preflight_error = "retry preflight failed"
  )
  withr::local_options(list(
    metasalmon.knb_adapter = function() failing$adapter
  ))
  expect_error(
    publish_sdp_to_knb(
      package_path,
      public = TRUE,
      manifest_path = manifest_path,
      dry_run = FALSE,
      confirm = TRUE
    ),
    "retry preflight failed"
  )
  after_failure <- jsonlite::read_json(
    manifest_path,
    simplifyVector = TRUE
  )
  expect_equal(after_failure$status, "complete")
  expect_true(after_failure$catalog_verified)
  expect_identical(
    after_failure$catalog_evidence,
    completed$manifest$catalog_evidence
  )
})

test_that("uploaded allowlist reconstructs the SDP and retains measurement IRIs", {
  skip_if_not_installed("emld")

  package_path <- make_knb_test_sdp(withr::local_tempdir())
  writeLines("decoy", file.path(package_path, "do-not-upload.txt"))
  manifest_path <- file.path(package_path, "publication", "knb-manifest.json")
  reviewed <- review_knb_plan(package_path, manifest_path)
  expect_true(
    "reviewed_semantic_selections.csv" %in%
      vapply(reviewed$manifest$objects, function(object) {
        object$path
      }, character(1))
  )
  expect_false(any(vapply(reviewed$manifest$objects, function(object) {
    identical(object$path, "do-not-upload.txt")
  }, logical(1))))

  memory <- make_knb_memory_adapter(manifest_path)
  withr::local_options(list(
    metasalmon.knb_adapter = function() memory$adapter
  ))
  published <- publish_sdp_to_knb(
    package_path,
    public = TRUE,
    manifest_path = manifest_path,
    dry_run = FALSE,
    confirm = TRUE
  )

  reconstructed <- file.path(withr::local_tempdir(), "reconstructed")
  dir.create(reconstructed)
  for (object in published$manifest$objects) {
    if (!object$role %in% c("data", "sdp_artifact")) {
      next
    }
    destination <- file.path(reconstructed, object$path)
    dir.create(dirname(destination), recursive = TRUE, showWarnings = FALSE)
    writeBin(memory$state$objects[[object$pid]]$bytes, destination)
  }
  rebuilt <- read_salmon_datapackage(reconstructed)
  measurement <- rebuilt$dictionary[
    rebuilt$dictionary$column_role == "measurement",
    ,
    drop = FALSE
  ]
  expect_equal(nrow(measurement), 1L)
  expect_identical(
    measurement$term_iri[[1]],
    "https://w3id.org/smn/ObservedRateOrAbundance"
  )
})

test_that("default adapter SystemMetadata contract serializes as DataONE v2", {
  skip_if_not_installed("datapack")
  skip_if_not_installed("XML")

  object <- list(
    role = "metadata",
    path = "metadata/eml.xml",
    pid = "urn:uuid:11111111-1111-5111-8111-111111111111",
    format_id = "https://eml.ecoinformatics.org/eml-2.2.0",
    media_type = "application/xml",
    size = 42,
    sha256 = paste(rep("a", 64), collapse = ""),
    series_id = "urn:uuid:22222222-2222-5222-8222-222222222222"
  )
  subject <- "https://orcid.org/0000-0001-9317-0364"
  system_metadata <- .ms_knb_new_system_metadata(
    object,
    subject,
    public = TRUE,
    node_id = "urn:node:KNB",
    replication_policy = .ms_knb_replication_policy(TRUE)
  )
  xml <- datapack::serializeSystemMetadata(
    system_metadata,
    version = "v2"
  )
  parsed <- xml2::read_xml(xml)
  replication_policy <- xml2::xml_find_first(
    parsed,
    "//*[local-name()='replicationPolicy']"
  )
  expect_identical(
    xml2::xml_attr(replication_policy, "replicationAllowed"),
    "true"
  )
  expect_identical(
    xml2::xml_attr(replication_policy, "numberReplicas"),
    "3"
  )
  expect_length(xml2::xml_children(replication_policy), 0L)

  for (server_field in c(
    "serialVersion",
    "archived",
    "dateUploaded",
    "dateSysMetadataModified",
    "originMemberNode",
    "authoritativeMemberNode"
  )) {
    expect_length(
      xml2::xml_find_all(
        parsed,
        paste0("//*[local-name()='", server_field, "']")
      ),
      0L
    )
  }
  expect_equal(
    xml2::xml_text(xml2::xml_find_first(
      parsed,
      "//*[local-name()='identifier']"
    )),
    object$pid
  )
  expect_equal(
    xml2::xml_text(xml2::xml_find_first(
      parsed,
      "//*[local-name()='formatId']"
    )),
    object$format_id
  )
  expect_equal(
    xml2::xml_text(xml2::xml_find_first(
      parsed,
      "//*[local-name()='seriesId']"
    )),
    object$series_id
  )
  expect_equal(
    xml2::xml_attr(xml2::xml_find_first(
      parsed,
      "//*[local-name()='allow'][*[local-name()='subject' and text()='public']]/*[local-name()='permission']"
    ), "permission"),
    NA_character_
  )
  expect_equal(
    xml2::xml_text(xml2::xml_find_first(
      parsed,
      "//*[local-name()='allow'][*[local-name()='subject' and text()='public']]/*[local-name()='permission']"
    )),
    "read"
  )
})

test_that("CN credential echo verifies the locally parsed JWT subject", {
  credentials <- list(
    person = list(
      subject = "CN=Example Person,DC=dataone,DC=org",
      equivalentIdentity = "http://orcid.org/0000-0001-9317-0364",
      verified = "true"
    ),
    person = list(
      subject = "http://orcid.org/0000-0001-9317-0364",
      equivalentIdentity = "CN=Example Person,DC=dataone,DC=org",
      verified = "false"
    )
  )

  expect_identical(
    .ms_knb_server_verified_subject(
      credentials,
      "https://orcid.org/0000-0001-9317-0364"
    ),
    "http://orcid.org/0000-0001-9317-0364"
  )
  expect_error(
    .ms_knb_server_verified_subject(
      credentials,
      "https://orcid.org/0000-0002-1825-0097"
    ),
    "Coordinating Node did not verify"
  )
  expect_error(
    .ms_knb_server_verified_subject(
      NA_character_,
      "https://orcid.org/0000-0001-9317-0364"
    ),
    "Coordinating Node did not verify"
  )

  expect_error(
    .ms_knb_server_verified_subject(
      list(person = list(
        subject = "http://orcid.org/0000-0001-9317-0364",
        verified = "false"
      )),
      "https://orcid.org/0000-0001-9317-0364"
    ),
    "Coordinating Node did not verify"
  )
  expect_error(
    .ms_knb_server_verified_subject(
      list(person = list(
        subject = "CN=Example Person,DC=dataone,DC=org",
        equivalentIdentity =
          "http://orcid.org/0000-0001-9317-0364"
      )),
      "https://orcid.org/0000-0001-9317-0364"
    ),
    "Coordinating Node did not verify"
  )
})

test_that("read-back requires valid server-owned SystemMetadata fields", {
  subject <- "https://orcid.org/0000-0001-9317-0364"
  object <- list(
    pid = "urn:uuid:11111111-1111-5111-8111-111111111111",
    path = "data/counts.csv",
    format_id = "text/csv",
    media_type = "text/csv",
    size = 4,
    sha256 = paste(rep("a", 64), collapse = ""),
    series_id = NA_character_
  )
  remote <- list(
    serial_version = 1,
    identifier = object$pid,
    format_id = object$format_id,
    size = object$size,
    checksum = object$sha256,
    checksum_algorithm = "SHA-256",
    submitter = "http://orcid.org/0000-0001-9317-0364",
    rights_holder = subject,
    access = list(list(subject = "public", permission = "read")),
    replication_allowed = TRUE,
    number_replicas = 3,
    preferred_member_nodes = list(),
    blocked_member_nodes = list(),
    series_id = NA_character_,
    media_type = object$media_type,
    file_name = basename(object$path),
    archived = FALSE,
    obsoletes = NA_character_,
    obsoleted_by = NA_character_,
    date_uploaded = "2026-07-31T00:00:00Z",
    date_sys_metadata_modified = "2026-07-31T00:00:00.123+00:00",
    origin_member_node = "urn:node:KNB",
    authoritative_member_node = "urn:node:KNB"
  )

  expect_silent(.ms_knb_validate_system_metadata(
    remote,
    object,
    subject,
    public = TRUE,
    replication_policy = .ms_knb_replication_policy(TRUE)
  ))

  # DataONE defines serialVersion as xs:unsignedLong, and production KNB
  # returns zero for a newly-created object before any SystemMetadata update.
  zero_serial_version <- remote
  zero_serial_version$serial_version <- 0
  expect_silent(.ms_knb_validate_system_metadata(
    zero_serial_version,
    object,
    subject,
    public = TRUE,
    replication_policy = .ms_knb_replication_policy(TRUE)
  ))

  invalid_values <- list(
    submitter = "https://orcid.org/0000-0002-1825-0097",
    origin_member_node = "urn:node:OTHER",
    authoritative_member_node = "urn:node:OTHER",
    media_type = "application/octet-stream",
    file_name = "wrong.csv",
    archived = TRUE,
    obsoletes = "urn:uuid:old",
    obsoleted_by = "urn:uuid:new",
    checksum_algorithm = "MD5",
    serial_version = -1,
    date_uploaded = "not-a-timestamp",
    date_sys_metadata_modified = "2026-02-30T00:00:00Z",
    replication_allowed = FALSE,
    number_replicas = 0,
    preferred_member_nodes = list("urn:node:OTHER"),
    blocked_member_nodes = list("urn:node:OTHER")
  )
  for (field in names(invalid_values)) {
    invalid <- remote
    invalid[[field]] <- invalid_values[[field]]
    expect_error(
      .ms_knb_validate_system_metadata(
        invalid,
        object,
        subject,
        public = TRUE,
        replication_policy = .ms_knb_replication_policy(TRUE)
      ),
      field
    )
  }
})
