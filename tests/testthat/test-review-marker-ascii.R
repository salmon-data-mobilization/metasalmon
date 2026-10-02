# Q63 / B-344: one locale-independent spelling for every REVIEW IRI reader.
# The shape checks from B-342 own values that this narrower marker excludes.

test_that("the REVIEW marker and strip use ASCII spaces, tabs and case only", {
  original <- Sys.getlocale("LC_CTYPE")
  on.exit(suppressWarnings(Sys.setlocale("LC_CTYPE", original)), add = TRUE)
  locales <- c("C", "en_US.UTF-8", "C.UTF-8")
  reached <- character()
  for (locale in locales) {
    selected <- suppressWarnings(Sys.setlocale("LC_CTYPE", locale))
    if (!nzchar(selected) || (grepl("UTF-8", selected, fixed = TRUE) &&
                             any(grepl("UTF-8", reached, fixed = TRUE)))) {
      next
    }
    reached <- c(reached, selected)

    admitted <- c(
      "REVIEW:x", "  rEvIeW\t : \t x", "\tREVIEW:x",
      paste0("REVIEW:", intToUtf8(0x00A0L), "x"), "REVIEW:\nx"
    )
    stripped <- c("x", "x", "x", paste0(intToUtf8(0x00A0L), "x"), "\nx")
    expect_true(all(vapply(admitted, .ms_is_review_iri, logical(1))), info = locale)
    expect_identical(unname(.ms_strip_review_iri(admitted)), stripped, info = locale)

    excluded <- c(
      "\nREVIEW:x", "\fREVIEW:x", "\vREVIEW:x", "\rREVIEW:x",
      paste0(intToUtf8(0x00A0L), "REVIEW:x"),
      "REVIEW\n:x", "REVIEW\f:x", "REVIEW\v:x",
      paste0("REV", intToUtf8(0x0131L), "EW:x")
    )
    expect_false(any(vapply(excluded, .ms_is_review_iri, logical(1))), info = locale)
    expect_identical(unname(.ms_strip_review_iri(excluded)), excluded, info = locale)
  }
  expect_true("C" %in% reached)
  expect_true(any(grepl("UTF-8", reached, fixed = TRUE)))
})

test_that("dictionary and table IRI scans agree on the ASCII marker boundary", {
  values <- c("\nREVIEW:https://example.org/a", "Review :https://example.org/b")
  table <- tibble::tibble(custom_thing_iri = values)
  review_issues <- .ms_collect_review_iri_issues(table, "metadata/tables.csv")
  malformed_issues <- .ms_collect_malformed_table_iri_issues(table, "metadata/tables.csv")
  expect_equal(nrow(review_issues), 1L)
  if (nrow(review_issues) == 1L) {
    expect_match(review_issues$message[[1]], "row 2", fixed = TRUE)
  }
  expect_equal(nrow(malformed_issues), 1L)
  if (nrow(malformed_issues) == 1L) {
    expect_match(malformed_issues$message[[1]], "row 1", fixed = TRUE)
  }

  expect_true(.ms_constraint_iri_has_review_marker(
    "https://example.org/a; REVIEW :https://example.org/b"
  ))
  expect_false(.ms_constraint_iri_has_review_marker(
    "https://example.org/a; REVIEW\n:https://example.org/b"
  ))

  placements <- tibble::tibble(method_iri = rev(values))
  placement_issues <- .ms_collect_placement_iri_issues(
    placements, "metadata/tables.csv", id_fields = character()
  )
  expect_equal(nrow(placement_issues), 1L)
  if (nrow(placement_issues) == 1L) {
    expect_match(placement_issues$message[[1]], "row 2", fixed = TRUE)
  }
})

test_that("strict validation rejects a former marker as a malformed IRI", {
  root <- make_eml_test_sdp(withr::local_tempdir())
  path <- file.path(root, "metadata", "column_dictionary.csv")
  dict <- readr::read_csv(path, show_col_types = FALSE)
  count <- dict$column_name == "count"
  dict$term_iri[count] <- "\nREVIEW:https://example.org/term"
  readr::write_csv(dict, path, na = "")

  expect_false(.ms_is_review_iri(dict$term_iri[count]))
  expect_error(
    suppressMessages(suppressWarnings(
      validate_salmon_datapackage(root, require_iris = TRUE)
    )),
    "term_iri is not an absolute IRI"
  )
})

test_that("both serialized XML guards refuse markers in emitted IRI fields", {
  skip_if_not_installed("emld")
  root <- make_eml_test_sdp(withr::local_tempdir())
  built <- suppressMessages(write_eml_from_sdp(root))
  eml <- xml2::read_xml(built$path)
  value_iri <- xml2::xml_find_first(eml, "//*[local-name()='annotation']/*[local-name()='valueURI']")
  xml2::xml_set_attr(value_iri, "label", "Review: a useful term label")
  original_iri <- xml2::xml_text(value_iri)
  dictionary <- .ms_read_metadata_csv(file.path(root, "metadata", "column_dictionary.csv"))
  expect_no_error(.ms_eml_validate_document_links(eml, dictionary, "demo-salmon-2026"))
  xml2::xml_set_text(value_iri, "Review :unresolved")
  expect_error(
    .ms_eml_validate_document_links(eml, dictionary, "demo-salmon-2026"),
    "unresolved.*REVIEW"
  )
  xml2::xml_set_text(value_iri, original_iri)
  user_id <- xml2::xml_find_first(eml, "//*[local-name()='userId']")
  expect_false(inherits(user_id, "xml_missing"))
  xml2::xml_set_attr(user_id, "directory", "Review\t:unresolved")
  expect_match(as.character(eml), "Review&#9;:unresolved", fixed = TRUE)
  expect_error(
    .ms_eml_validate_document_links(eml, dictionary, "demo-salmon-2026"),
    "unresolved.*REVIEW"
  )

  config <- list(resolver = "https://example.org/resolve/")
  members <- list(
    list(role = "metadata", pid = "urn:example:metadata", path = "metadata/eml.xml"),
    list(role = "data", pid = "urn:example:data", path = "data/counts.csv")
  )
  ore <- .ms_knb_build_ore(
    "urn:example:resource-map", "urn:example:metadata", "2026-01-01",
    members, config
  )
  creator <- xml2::xml_find_first(ore, "//*[local-name()='creator']")
  expect_false(inherits(creator, "xml_missing"))
  xml2::xml_set_attr(creator, "rdf:resource", "Review\t:unresolved")
  expect_match(as.character(ore), "Review&#9;:unresolved", fixed = TRUE)
  expect_error(
    .ms_knb_validate_ore(ore, "urn:example:resource-map", members, config),
    "local/review marker"
  )
})

test_that("the XML guard inspects only emitter IRI locations", {
  skip_if_not_installed("emld")
  root <- make_eml_test_sdp(withr::local_tempdir())
  built <- suppressMessages(write_eml_from_sdp(root))
  eml <- xml2::read_xml(built$path)
  eml_root <- xml2::xml_root(eml)
  namespace <- "https://eml.ecoinformatics.org/eml-2.2.0"
  original_location <- xml2::xml_attr(eml_root, "schemaLocation")

  # schemaLocation has two URI tokens. The second is checked without erasing
  # an excluded newline or non-ASCII prefix before the marker.
  for (second_uri in c("Review :unresolved", "Review\t:unresolved")) {
    xml2::xml_set_attr(
      eml_root, "xsi:schemaLocation", paste(namespace, second_uri)
    )
    expect_true(.ms_document_has_review_iri(eml, "eml"))
  }
  for (first_prefix in c(" ", "\t")) {
    xml2::xml_set_attr(
      eml_root, "xsi:schemaLocation",
      paste0(first_prefix, namespace, " Review\t:unresolved")
    )
    expect_true(.ms_document_has_review_iri(eml, "eml"))
    xml2::xml_set_attr(
      eml_root, "xsi:schemaLocation",
      paste0(first_prefix, "Review :unresolved ", namespace)
    )
    expect_true(.ms_document_has_review_iri(eml, "eml"))
  }
  for (second_uri in c("\nReview:unresolved", paste0(intToUtf8(0x00A0L), "Review:unresolved"))) {
    xml2::xml_set_attr(
      eml_root, "xsi:schemaLocation", paste(namespace, second_uri)
    )
    expect_false(.ms_document_has_review_iri(eml, "eml"))
  }
  xml2::xml_set_attr(eml_root, "xsi:schemaLocation", original_location)
  for (xpath in c(
    "//*[local-name()='annotation']/*[local-name()='propertyURI']",
    "//*[local-name()='distribution']/*[local-name()='online']/*[local-name()='url']",
    "//*[local-name()='userId'][@directory='https://orcid.org']"
  )) {
    node <- xml2::xml_find_first(eml, xpath)
    expect_false(inherits(node, "xml_missing"), info = xpath)
    original <- xml2::xml_text(node)
    xml2::xml_set_text(node, "Review :unresolved")
    expect_true(.ms_document_has_review_iri(eml, "eml"), info = xpath)
    xml2::xml_set_text(node, original)
  }
  ordinary_id <- xml2::xml_find_first(
    eml, "//*[local-name()='dataset']/*[local-name()='alternateIdentifier']"
  )
  original_id <- xml2::xml_text(ordinary_id)
  xml2::xml_set_text(ordinary_id, "Review :ordinary dataset ID")
  expect_false(.ms_document_has_review_iri(eml, "eml"))
  xml2::xml_set_text(ordinary_id, original_id)

  dataset_node <- xml2::xml_find_first(eml, "//*[local-name()='dataset']")
  code_definition <- xml2::xml_add_child(dataset_node, "codeDefinition")
  .ms_eml_add_text(code_definition, "source", "Review :unresolved")
  expect_true(.ms_document_has_review_iri(eml, "eml"))
  xml2::xml_remove(code_definition)
  other_entity <- xml2::xml_add_child(dataset_node, "otherEntity")
  .ms_eml_add_text(
    other_entity, "alternateIdentifier", "Review :unresolved",
    attrs = c(system = "DataONE")
  )
  expect_true(.ms_document_has_review_iri(eml, "eml"))
  xml2::xml_remove(other_entity)

  original_package_id <- xml2::xml_attr(eml_root, "packageId")
  xml2::xml_set_attr(eml_root, "packageId", "Review :unresolved")
  expect_true(.ms_document_has_review_iri(eml, "eml"))
  xml2::xml_set_attr(eml_root, "packageId", original_package_id)

  config <- list(resolver = "https://example.org/resolve/")
  members <- list(
    list(role = "metadata", pid = "urn:example:metadata", path = "metadata/eml.xml"),
    list(role = "data", pid = "urn:example:data", path = "data/counts.csv")
  )
  ore <- .ms_knb_build_ore(
    "urn:example:resource-map", "urn:example:metadata", "2026-01-01",
    members, config
  )
  description <- xml2::xml_find_first(ore, "//*[local-name()='Description']")
  original_about <- xml2::xml_attr(description, "about")
  xml2::xml_set_attr(description, "rdf:about", "Review :unresolved")
  expect_true(.ms_document_has_review_iri(ore, "ore"))
  xml2::xml_set_attr(description, "rdf:about", original_about)
  identifier <- xml2::xml_find_first(ore, "//*[local-name()='identifier']")
  xml2::xml_set_attr(identifier, "rdf:datatype", "Review\t:unresolved")
  expect_true(.ms_document_has_review_iri(ore, "ore"))
})

test_that("ordinary review narratives survive public EML export", {
  skip_if_not_installed("emld")
  root <- make_eml_test_sdp(withr::local_tempdir())
  dataset_path <- file.path(root, "metadata", "dataset.csv")
  dataset <- readr::read_csv(dataset_path, show_col_types = FALSE)
  title <- "Review: annual salmon counts"
  narrative <- "Review: counts were independently checked. Peer review: complete."
  dataset$title <- title
  dataset$description <- narrative
  readr::write_csv(dataset, dataset_path, na = "")

  built <- suppressMessages(write_eml_from_sdp(root))
  expect_true(file.exists(built$path))
  eml <- xml2::read_xml(built$path)
  expect_match(as.character(eml), title, fixed = TRUE)
  expect_match(as.character(eml), narrative, fixed = TRUE)
})

test_that("ordinary review narratives survive the ORE output guard", {
  narrative <- "Peer review: counts were cross-checked; data preview: complete."
  config <- list(resolver = "https://example.org/resolve/")
  members <- list(
    list(role = "metadata", pid = "urn:example:metadata", path = "metadata/eml.xml"),
    list(role = "data", pid = "urn:example:data", path = "data/counts.csv")
  )
  ore <- .ms_knb_build_ore(
    "urn:example:resource-map", "urn:example:metadata", "2026-01-01",
    members, config
  )
  modified <- xml2::xml_find_first(ore, "//*[local-name()='modified']")
  xml2::xml_set_text(modified, narrative)
  expect_no_error(.ms_knb_validate_ore(
    ore, "urn:example:resource-map", members, config
  ))

  # The inherited case-sensitive serialized fallback still refuses this exact
  # literal even when it appears inside a longer text value.
  xml2::xml_set_text(modified, "Peer REVIEW: unresolved")
  expect_error(
    .ms_knb_validate_ore(ore, "urn:example:resource-map", members, config),
    "local/review marker"
  )
})

test_that("bundle selected IRIs inspect raw marker spelling before ordinary trim", {
  assessments <- .ms_empty_llm_assessments()
  row <- tibble::tibble(term_iri = "Review :https://example.org/term")
  selected <- .ms_semantic_bundle_current_selected_iris(assessments, row)
  expect_true(is.na(selected[["variable"]]))

  row$term_iri <- "\nREVIEW:https://example.org/term"
  selected <- .ms_semantic_bundle_current_selected_iris(assessments, row)
  expect_identical(selected[["variable"]], "REVIEW:https://example.org/term")
})

test_that("create_sdp checklist uses the same raw prefill boundary", {
  resources <- list(counts = tibble::tibble(count = c(1L, 2L)))
  base <- infer_salmon_datapackage_artifacts(
    resources, dataset_id = "q63-checklist", seed_semantics = FALSE,
    seed_verbose = FALSE
  )
  count <- base$dict$column_name == "count"
  cases <- c(admitted = "Review :https://example.org/term",
             excluded = "\nREVIEW:https://example.org/term")
  for (case in names(cases)) {
    value <- cases[[case]]
    artifacts <- base
    artifacts$dict$term_iri[count] <- value
    root <- withr::local_tempdir()
    suppressMessages(suppressWarnings(testthat::with_mocked_bindings(
      infer_salmon_datapackage_artifacts = function(...) artifacts,
      create_sdp(
        resources, path = root, dataset_id = "q63-checklist",
        seed_semantics = FALSE, seed_verbose = FALSE,
        check_updates = FALSE, overwrite = TRUE
      )
    )))
    readme <- paste(readLines(file.path(root, "README-review.txt")), collapse = "\n")
    expect_identical(grepl("a draft this package wrote for you", readme, fixed = TRUE),
                     identical(case, "admitted"))
  }
})
