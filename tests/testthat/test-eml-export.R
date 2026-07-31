test_that("write_eml_from_sdp creates valid deterministic annotated EML 2.2.0", {
  skip_if_not_installed("emld")

  package_path <- make_eml_test_sdp(withr::local_tempdir())
  output_path <- file.path(package_path, "metadata", "eml.xml")

  result <- write_eml_from_sdp(package_path, output_path = output_path)

  expect_true(file.exists(output_path))
  expect_true(isTRUE(emld::eml_validate(output_path)))
  expect_equal(result$eml_version, "2.2.0")
  expect_equal(result$path, normalizePath(output_path, mustWork = TRUE))
  expect_match(result$package_id, "^urn:uuid:")
  expect_match(result$series_id, "^urn:uuid:")
  expect_true(result$public)
  expect_equal(result$data_objects$format_id, "text/csv")
  expect_match(result$data_objects$checksum, "^[0-9a-f]{64}$")

  doc <- xml2::read_xml(output_path)
  root <- xml2::xml_root(doc)
  expect_equal(
    xml2::xml_ns(root)[["eml"]],
    "https://eml.ecoinformatics.org/eml-2.2.0"
  )
  expect_equal(xml2::xml_attr(root, "system"), "knb")
  expect_equal(xml2::xml_attr(root, "packageId"), result$package_id)
  expect_equal(
    xml2::xml_attr(root, "schemaLocation"),
    paste(
      "https://eml.ecoinformatics.org/eml-2.2.0",
      "https://eml.ecoinformatics.org/eml-2.2.0/eml.xsd"
    )
  )

  count_attribute <- xml2::xml_find_first(
    doc,
    ".//*[local-name()='attribute'][*[local-name()='attributeName' and text()='count']]"
  )
  expect_false(inherits(count_attribute, "xml_missing"))
  expect_match(xml2::xml_attr(count_attribute, "id"), "^attribute-")
  expect_equal(
    xml2::xml_text(
      xml2::xml_find_first(
        count_attribute,
        ".//*[local-name()='ratio']/*[local-name()='unit']/*[local-name()='standardUnit']"
      )
    ),
    "number"
  )
  expect_equal(
    xml2::xml_text(
      xml2::xml_find_first(
        count_attribute,
        ".//*[local-name()='numericDomain']/*[local-name()='numberType']"
      )
    ),
    "whole"
  )

  annotations <- xml2::xml_find_all(
    count_attribute,
    "./*[local-name()='annotation']"
  )
  expect_equal(length(annotations), 2L)
  expect_equal(
    xml2::xml_text(xml2::xml_find_all(annotations, "./*[local-name()='propertyURI']")),
    c(
      "http://purl.org/dc/terms/subject",
      "http://qudt.org/schema/qudt/hasUnit"
    )
  )
  expect_equal(
    xml2::xml_text(xml2::xml_find_all(annotations, "./*[local-name()='valueURI']")),
    c(
      "https://w3id.org/smn/ObservedRateOrAbundance",
      "http://qudt.org/vocab/unit/COUNT"
    )
  )
  expect_false(any(grepl("usedProcedure", as.character(doc), fixed = TRUE)))
  expect_false(any(grepl(
    "http://qudt.org/vocab/quantitykind/Count",
    as.character(doc),
    fixed = TRUE
  )))
  expect_false(any(grepl(
    "https://w3id.org/smn/Stock",
    as.character(doc),
    fixed = TRUE
  )))

  ids <- xml2::xml_attr(xml2::xml_find_all(doc, "//*[@id]"), "id")
  expect_equal(anyDuplicated(ids), 0L)
  references <- xml2::xml_text(xml2::xml_find_all(
    doc,
    "//*[local-name()='attributeReference']"
  ))
  expect_true(all(references %in% ids))
  not_null_references <- xml2::xml_text(xml2::xml_find_all(
    doc,
    "//*[local-name()='notNullConstraint']//*[local-name()='attributeReference']"
  ))
  expect_setequal(
    not_null_references,
    xml2::xml_attr(
      xml2::xml_find_all(
        doc,
        ".//*[local-name()='attribute'][*[local-name()='attributeName' and (text()='record_id' or text()='year' or text()='count')]]"
      ),
      "id"
    )
  )
  expect_equal(
    xml2::xml_text(xml2::xml_find_all(
      doc,
      "//*[local-name()='textFormat']//*[local-name()='fieldDelimiter']"
    )),
    ","
  )

  literal_missing_attribute <- xml2::xml_find_first(
    doc,
    ".//*[local-name()='attribute'][*[local-name()='attributeName' and text()='literal_missing']]"
  )
  expect_equal(
    xml2::xml_text(xml2::xml_find_all(
      literal_missing_attribute,
      "./*[local-name()='missingValueCode']/*[local-name()='code']"
    )),
    "NA"
  )
  blank_only_attribute <- xml2::xml_find_first(
    doc,
    ".//*[local-name()='attribute'][*[local-name()='attributeName' and text()='blank_only']]"
  )
  expect_length(
    xml2::xml_find_all(
      blank_only_attribute,
      "./*[local-name()='missingValueCode']"
    ),
    0L
  )

  additional_info <- xml2::xml_text(xml2::xml_find_all(
    doc,
    "//*[local-name()='dataset']/*[local-name()='additionalInfo']//*[local-name()='para']"
  ))
  expect_true(any(grepl(
    "Source citation: Example Salmon Program. 2026. Demonstration counts.",
    additional_info,
    fixed = TRUE
  )))
  expect_true(any(grepl(
    "Provenance note: Counts were compiled from a documented monitoring program.",
    additional_info,
    fixed = TRUE
  )))
  expect_true(any(grepl(
    "Supporting document citation: Example Salmon Program. 2026. Demonstration count documentation.",
    additional_info,
    fixed = TRUE
  )))
  expect_true(any(grepl(
    "Supporting document URL: https://example.org/demonstration-count-documentation.pdf",
    additional_info,
    fixed = TRUE
  )))
  expect_true(any(grepl(
    paste0("Supporting document SHA-256: ", paste(rep("4", 64), collapse = "")),
    additional_info,
    fixed = TRUE
  )))
})

test_that("SKOS compound variables use a topic predicate instead of OBOE MeasurementType", {
  skip_if_not_installed("emld")

  package_path <- make_eml_test_sdp(
    withr::local_tempdir(),
    measurement_term_iri =
      "https://w3id.org/psc/vocab/concept/PSC-CV-000035",
    measurement_term_label = "Effective female spawner abundance",
    measurement_term_type = "skos_concept",
    measurement_native_type = "skos:Concept",
    measurement_type_iris =
      "http://www.w3.org/2004/02/skos/core#Concept",
    measurement_resource_kind = "Concept",
    measurement_source = "psc",
    measurement_source_url = "https://w3id.org/psc/vocab/"
  )

  result <- write_eml_from_sdp(package_path)
  document <- xml2::read_xml(result$path)
  attribute <- xml2::xml_find_first(
    document,
    ".//*[local-name()='attribute'][*[local-name()='attributeName' and text()='count']]"
  )
  annotations <- xml2::xml_find_all(
    attribute,
    "./*[local-name()='annotation']"
  )

  expect_equal(
    xml2::xml_text(xml2::xml_find_all(
      annotations,
      "./*[local-name()='propertyURI']"
    )),
    c(
      "http://purl.org/dc/terms/subject",
      "http://qudt.org/schema/qudt/hasUnit"
    )
  )
  expect_equal(
    xml2::xml_text(xml2::xml_find_first(
      annotations[[1]],
      "./*[local-name()='propertyURI']"
    )),
    "http://purl.org/dc/terms/subject"
  )
  expect_equal(
    xml2::xml_attr(xml2::xml_find_first(
      annotations[[1]],
      "./*[local-name()='propertyURI']"
    ), "label"),
    "Subject"
  )
  expect_false(grepl(
    "containsMeasurementsOfType",
    as.character(document),
    fixed = TRUE
  ))
})

test_that("EML bytes and identifiers do not depend on the absolute SDP path", {
  skip_if_not_installed("emld")

  first_path <- file.path(withr::local_tempdir(), "first")
  second_path <- file.path(withr::local_tempdir(), "second")
  make_eml_test_sdp(first_path)
  make_eml_test_sdp(second_path)

  first <- write_eml_from_sdp(first_path)
  second <- write_eml_from_sdp(second_path)

  expect_identical(
    readBin(first$path, "raw", n = file.info(first$path)$size),
    readBin(second$path, "raw", n = file.info(second$path)$size)
  )
  expect_identical(first$package_id, second$package_id)
  expect_identical(first$series_id, second$series_id)
  expect_identical(first$data_objects$pid, second$data_objects$pid)
})

test_that("EML mapping uses one canonical sidecar and exact table-qualified columns", {
  skip_if_not_installed("emld")

  package_path <- make_eml_test_sdp(withr::local_tempdir())
  yml_path <- file.path(package_path, "metadata", "eml-mapping.yml")
  yaml_path <- file.path(package_path, "metadata", "eml-mapping.yaml")
  file.copy(yml_path, yaml_path)

  expect_error(
    write_eml_from_sdp(package_path),
    "Both.*eml-mapping.yml.*eml-mapping.yaml"
  )

  unlink(yaml_path)
  mapping <- yaml::read_yaml(yml_path)
  mapping$tables$counts$attributes$year <- NULL
  yaml::write_yaml(mapping, yml_path)

  expect_error(
    write_eml_from_sdp(package_path),
    "exactly the SDP columns"
  )
})

test_that("EML export rejects unreviewed unit crosswalks and vocabulary drift", {
  skip_if_not_installed("emld")

  package_path <- make_eml_test_sdp(withr::local_tempdir())
  mapping_path <- file.path(package_path, "metadata", "eml-mapping.yml")
  mapping <- yaml::read_yaml(mapping_path)
  mapping$tables$counts$attributes$count$eml_unit <- "count"
  yaml::write_yaml(mapping, mapping_path)

  expect_error(
    write_eml_from_sdp(package_path),
    "eml_unit.*must be.*number"
  )

  package_path <- make_eml_test_sdp(withr::local_tempdir())
  vocabulary_path <- file.path(
    package_path,
    "metadata",
    "semantic_vocabulary.csv"
  )
  write("\n", file = vocabulary_path, append = TRUE)

  expect_error(
    write_eml_from_sdp(package_path),
    "SHA-256 does not match"
  )
})

test_that("EML units require an exact reviewed canonical-IRI crosswalk", {
  skip_if_not_installed("emld")

  package_path <- make_eml_test_sdp(withr::local_tempdir())
  dictionary_path <- file.path(
    package_path,
    "metadata",
    "column_dictionary.csv"
  )
  dictionary <- readr::read_csv(
    dictionary_path,
    col_types = readr::cols(.default = readr::col_character()),
    show_col_types = FALSE
  )
  dictionary$unit_iri[dictionary$column_name == "count"] <-
    "http://qudt.org/vocab/unit/M"
  readr::write_csv(dictionary, dictionary_path, na = "")

  vocabulary_path <- file.path(
    package_path,
    "metadata",
    "semantic_vocabulary.csv"
  )
  vocabulary <- readr::read_csv(
    vocabulary_path,
    col_types = readr::cols(.default = readr::col_character()),
    show_col_types = FALSE
  )
  vocabulary$iri[
    vocabulary$iri == "http://qudt.org/vocab/unit/COUNT"
  ] <- "http://qudt.org/vocab/unit/M"
  readr::write_csv(vocabulary, vocabulary_path, na = "")

  mapping_path <- file.path(package_path, "metadata", "eml-mapping.yml")
  mapping <- yaml::read_yaml(mapping_path)
  mapping$semantic_vocabulary$sha256 <- digest::digest(
    file = vocabulary_path,
    algo = "sha256",
    serialize = FALSE
  )
  yaml::write_yaml(mapping, mapping_path)

  expect_error(
    write_eml_from_sdp(package_path),
    "No reviewed EML standard-unit mapping.*unit/M"
  )
})

test_that("EML missing-value declarations are checked against raw CSV tokens", {
  skip_if_not_installed("emld")

  package_path <- make_eml_test_sdp(withr::local_tempdir())
  mapping_path <- file.path(package_path, "metadata", "eml-mapping.yml")
  mapping <- yaml::read_yaml(mapping_path)
  mapping$tables$counts$attributes$literal_missing$missing_values[[1]]$code <-
    "MISSING"
  yaml::write_yaml(mapping, mapping_path)

  expect_error(
    write_eml_from_sdp(package_path),
    "declares missing-value code.*MISSING.*does not occur"
  )

  package_path <- make_eml_test_sdp(withr::local_tempdir())
  mapping_path <- file.path(package_path, "metadata", "eml-mapping.yml")
  mapping <- yaml::read_yaml(mapping_path)
  mapping$tables$counts$attributes$literal_missing$missing_values <- NULL
  yaml::write_yaml(mapping, mapping_path)

  expect_error(
    write_eml_from_sdp(package_path),
    "undeclared non-empty missing token.*NA"
  )

  package_path <- make_eml_test_sdp(withr::local_tempdir())
  mapping_path <- file.path(package_path, "metadata", "eml-mapping.yml")
  mapping <- yaml::read_yaml(mapping_path)
  mapping$tables$counts$attributes$count$missing_values <- list(
    list(code = "0", explanation = "Incorrectly declared zero as missing.")
  )
  yaml::write_yaml(mapping, mapping_path)

  expect_error(
    write_eml_from_sdp(package_path),
    "missing-value code.*0.*parsed value is not missing"
  )
})

test_that("EML enumerated domains preserve exact raw categorical tokens", {
  skip_if_not_installed("emld")

  package_path <- make_eml_test_sdp(withr::local_tempdir())
  data_path <- file.path(package_path, "data", "counts.csv")
  lines <- readLines(data_path, warn = FALSE)
  data_row <- grep(",observed,", lines, fixed = TRUE)
  expect_length(data_row, 1L)
  lines[[data_row]] <- sub(
    ",observed,",
    '," observed ",',
    lines[[data_row]],
    fixed = TRUE
  )
  writeLines(lines, data_path, useBytes = TRUE)

  codes <- tibble::tibble(
    dataset_id = "demo-salmon-2026",
    table_id = "counts",
    column_name = "literal_missing",
    code_value = "observed",
    code_label = "Observed",
    code_description = "An observed categorical value.",
    vocabulary_iri = NA_character_,
    term_iri = NA_character_,
    term_type = NA_character_
  )
  readr::write_csv(
    codes,
    file.path(package_path, "metadata", "codes.csv"),
    na = ""
  )

  expect_error(
    write_eml_from_sdp(package_path),
    "enumerated domain.*exact raw CSV token.* observed "
  )
})

test_that("EML export is gated by an exact hashed semantic-review ledger", {
  skip_if_not_installed("emld")

  package_path <- make_eml_test_sdp(withr::local_tempdir())
  mapping_path <- file.path(package_path, "metadata", "eml-mapping.yml")
  review_path <- file.path(
    package_path,
    "reviewed_semantic_selections.csv"
  )
  review <- readr::read_csv(
    review_path,
    col_types = readr::cols(.default = readr::col_character()),
    show_col_types = FALSE
  )
  review <- review[
    !(review$target_scope == "column" &
        review$target_sdp_field == "unit_iri"),
    ,
    drop = FALSE
  ]
  readr::write_csv(review, review_path, na = "")
  mapping <- yaml::read_yaml(mapping_path)
  mapping$semantic_review$sha256 <- digest::digest(
    file = review_path,
    algo = "sha256",
    serialize = FALSE
  )
  yaml::write_yaml(mapping, mapping_path)

  expect_error(
    write_eml_from_sdp(package_path),
    "semantic-review ledger.*exactly one accepted row.*unit_iri"
  )

  package_path <- make_eml_test_sdp(withr::local_tempdir())
  mapping_path <- file.path(package_path, "metadata", "eml-mapping.yml")
  review_path <- file.path(
    package_path,
    "reviewed_semantic_selections.csv"
  )
  review <- readr::read_csv(
    review_path,
    col_types = readr::cols(.default = readr::col_character()),
    show_col_types = FALSE
  )
  review$decision[
    review$target_scope == "column" &
      review$target_sdp_field == "term_iri"
  ] <- "pending_user_confirmation"
  readr::write_csv(review, review_path, na = "")
  mapping <- yaml::read_yaml(mapping_path)
  mapping$semantic_review$sha256 <- digest::digest(
    file = review_path,
    algo = "sha256",
    serialize = FALSE
  )
  yaml::write_yaml(mapping, mapping_path)

  expect_error(
    write_eml_from_sdp(package_path),
    "semantic-review ledger.*pending_user_confirmation.*term_iri"
  )

  package_path <- make_eml_test_sdp(withr::local_tempdir())
  review_path <- file.path(
    package_path,
    "reviewed_semantic_selections.csv"
  )
  write("\n", file = review_path, append = TRUE)
  expect_error(
    write_eml_from_sdp(package_path),
    "semantic-review ledger SHA-256 does not match"
  )

  package_path <- make_eml_test_sdp(withr::local_tempdir())
  mapping_path <- file.path(package_path, "metadata", "eml-mapping.yml")
  review_path <- file.path(
    package_path,
    "reviewed_semantic_selections.csv"
  )
  review <- readr::read_csv(
    review_path,
    col_types = readr::cols(.default = readr::col_character()),
    show_col_types = FALSE
  )
  extra <- review[review$target_sdp_field == "term_iri", , drop = FALSE]
  extra$iri <- "https://example.org/unexpected-semantic"
  review <- dplyr::bind_rows(review, extra)
  readr::write_csv(review, review_path, na = "")
  mapping <- yaml::read_yaml(mapping_path)
  mapping$semantic_review$sha256 <- digest::digest(
    file = review_path,
    algo = "sha256",
    serialize = FALSE
  )
  yaml::write_yaml(mapping, mapping_path)

  expect_error(
    write_eml_from_sdp(package_path),
    "final semantic-review ledger must equal.*exactly"
  )
})

test_that("review and draft sidecars are valid states but cannot be exported", {
  skip_if_not_installed("emld")

  for (status in c("review", "draft")) {
    package_path <- make_eml_test_sdp(
      withr::local_tempdir(),
      mapping_status = status
    )
    mapping <- yaml::read_yaml(
      file.path(package_path, "metadata", "eml-mapping.yml")
    )
    expect_silent(.ms_eml_validate_mapping_schema(mapping))
    expect_error(
      write_eml_from_sdp(package_path),
      "status.*must be.*final.*before export"
    )
  }
})

test_that("numeric EML domains are compatible with SDP types and observed values", {
  skip_if_not_installed("emld")

  package_path <- make_eml_test_sdp(
    withr::local_tempdir(),
    count_values = c("0", "12"),
    count_value_type = "string"
  )
  expect_error(
    write_eml_from_sdp(package_path),
    "ratio.*requires SDP value_type.*integer.*number"
  )

  package_path <- make_eml_test_sdp(withr::local_tempdir())
  mapping_path <- file.path(package_path, "metadata", "eml-mapping.yml")
  mapping <- yaml::read_yaml(mapping_path)
  mapping$tables$counts$attributes$count$minimum <- 13
  mapping$tables$counts$attributes$count$maximum <- 12
  yaml::write_yaml(mapping, mapping_path)
  expect_error(
    write_eml_from_sdp(package_path),
    "minimum.*must not exceed.*maximum"
  )

  package_path <- make_eml_test_sdp(withr::local_tempdir())
  mapping_path <- file.path(package_path, "metadata", "eml-mapping.yml")
  mapping <- yaml::read_yaml(mapping_path)
  mapping$tables$counts$attributes$count$maximum <- 10
  yaml::write_yaml(mapping, mapping_path)
  expect_error(
    write_eml_from_sdp(package_path),
    "observed value.*12.*maximum.*10"
  )

  package_path <- make_eml_test_sdp(withr::local_tempdir())
  mapping_path <- file.path(package_path, "metadata", "eml-mapping.yml")
  mapping <- yaml::read_yaml(mapping_path)
  mapping$tables$counts$attributes$count$maximum <- 12
  mapping$tables$counts$attributes$count$maximum_exclusive <- TRUE
  yaml::write_yaml(mapping, mapping_path)
  expect_error(
    write_eml_from_sdp(package_path),
    "observed value.*12.*exclusive maximum.*12"
  )

  package_path <- make_eml_test_sdp(withr::local_tempdir())
  mapping_path <- file.path(package_path, "metadata", "eml-mapping.yml")
  mapping <- yaml::read_yaml(mapping_path)
  mapping$tables$counts$attributes$count$number_type <- "natural"
  yaml::write_yaml(mapping, mapping_path)
  expect_error(
    write_eml_from_sdp(package_path),
    "natural.*strictly positive.*0"
  )

  package_path <- make_eml_test_sdp(
    withr::local_tempdir(),
    count_values = c(0, 12.5)
  )
  expect_error(
    write_eml_from_sdp(package_path),
    "whole.*integer-valued.*12.5"
  )
})

test_that("dateTime EML formats are checked against actual calendar values", {
  skip_if_not_installed("emld")

  package_path <- make_eml_test_sdp(
    withr::local_tempdir(),
    year_values = c(2024.5, 2025)
  )
  expect_error(
    write_eml_from_sdp(package_path),
    "format_string.*YYYY.*2024.5"
  )

  package_path <- make_eml_test_sdp(
    withr::local_tempdir(),
    year_values = c("2024-02-28", "2025-01-01"),
    year_value_type = "string"
  )
  data_path <- file.path(package_path, "data", "counts.csv")
  data_lines <- readLines(data_path, warn = FALSE)
  data_lines <- sub(
    "2024-02-28",
    "2024-02-30",
    data_lines,
    fixed = TRUE
  )
  writeLines(data_lines, data_path, useBytes = TRUE)
  mapping_path <- file.path(package_path, "metadata", "eml-mapping.yml")
  mapping <- yaml::read_yaml(mapping_path)
  mapping$tables$counts$attributes$year$format_string <- "YYYY-MM-DD"
  yaml::write_yaml(mapping, mapping_path)
  expect_error(
    suppressWarnings(write_eml_from_sdp(package_path)),
    "format_string.*YYYY-MM-DD.*2024-02-30"
  )
})

test_that("source-document provenance is exact and bound to SDP metadata", {
  skip_if_not_installed("emld")

  package_path <- make_eml_test_sdp(withr::local_tempdir())
  mapping_path <- file.path(package_path, "metadata", "eml-mapping.yml")
  mapping <- yaml::read_yaml(mapping_path)
  mapping$source_provenance$source_citation <- "Different citation."
  yaml::write_yaml(mapping, mapping_path)

  expect_error(
    write_eml_from_sdp(package_path),
    "source_provenance.source_citation.*does not match SDP"
  )
})

test_that("EML output is idempotent and different bytes require overwrite", {
  skip_if_not_installed("emld")

  package_path <- make_eml_test_sdp(withr::local_tempdir())
  first <- write_eml_from_sdp(package_path)
  first_bytes <- readBin(first$path, "raw", n = file.info(first$path)$size)

  second <- write_eml_from_sdp(package_path)
  expect_identical(
    first_bytes,
    readBin(second$path, "raw", n = file.info(second$path)$size)
  )

  mapping_path <- file.path(package_path, "metadata", "eml-mapping.yml")
  mapping <- yaml::read_yaml(mapping_path)
  mapping$intellectual_rights$paragraphs[[1]] <- "Updated reviewed rights."
  yaml::write_yaml(mapping, mapping_path)

  expect_error(
    write_eml_from_sdp(package_path),
    "already exists with different bytes"
  )
  expect_identical(
    first_bytes,
    readBin(first$path, "raw", n = file.info(first$path)$size)
  )

  replaced <- write_eml_from_sdp(package_path, overwrite = TRUE)
  expect_false(identical(
    first_bytes,
    readBin(replaced$path, "raw", n = file.info(replaced$path)$size)
  ))
  expect_true(isTRUE(emld::eml_validate(replaced$path)))
})

test_that("UUIDv5 construction follows the URL namespace standard", {
  expect_identical(
    .ms_eml_uuid5("demo"),
    "966aaed4-cfe6-5120-89f0-64d6c459770b"
  )
})

test_that("write_eml_from_sdp refuses unresolved canonical measurement semantics", {
  skip_if_not_installed("emld")

  package_path <- make_eml_test_sdp(withr::local_tempdir())
  dictionary_path <- file.path(
    package_path,
    "metadata",
    "column_dictionary.csv"
  )
  dictionary <- readr::read_csv(dictionary_path, show_col_types = FALSE)
  dictionary$term_iri[dictionary$column_name == "count"] <- NA_character_
  readr::write_csv(dictionary, dictionary_path, na = "")

  expect_error(
    write_eml_from_sdp(package_path),
    "term_iri"
  )
})

test_that("write_eml_from_sdp requires vocabulary labels for the exact canonical IRI set", {
  skip_if_not_installed("emld")

  package_path <- make_eml_test_sdp(withr::local_tempdir())
  vocabulary_path <- file.path(
    package_path,
    "metadata",
    "semantic_vocabulary.csv"
  )
  vocabulary <- readr::read_csv(
    vocabulary_path,
    col_types = readr::cols(.default = readr::col_character()),
    show_col_types = FALSE
  )
  vocabulary <- vocabulary[
    vocabulary$iri != "http://qudt.org/vocab/unit/COUNT",
    ,
    drop = FALSE
  ]
  readr::write_csv(vocabulary, vocabulary_path, na = "")
  mapping_path <- file.path(package_path, "metadata", "eml-mapping.yml")
  mapping <- yaml::read_yaml(mapping_path)
  mapping$semantic_vocabulary$sha256 <- digest::digest(
    file = vocabulary_path,
    algo = "sha256",
    serialize = FALSE
  )
  yaml::write_yaml(mapping, mapping_path)

  expect_error(
    write_eml_from_sdp(package_path),
    "semantic_vocabulary.*exactly"
  )
})

test_that("write_eml_from_sdp verifies reviewed vocabulary row snapshots", {
  skip_if_not_installed("emld")

  package_path <- make_eml_test_sdp(withr::local_tempdir())
  vocabulary_path <- file.path(
    package_path,
    "metadata",
    "semantic_vocabulary.csv"
  )
  vocabulary <- readr::read_csv(
    vocabulary_path,
    col_types = readr::cols(.default = readr::col_character()),
    show_col_types = FALSE
  )
  vocabulary$definition[[1]] <- paste(
    vocabulary$definition[[1]],
    "Unreviewed change."
  )
  readr::write_csv(vocabulary, vocabulary_path, na = "")

  mapping_path <- file.path(package_path, "metadata", "eml-mapping.yml")
  mapping <- yaml::read_yaml(mapping_path)
  mapping$semantic_vocabulary$sha256 <- digest::digest(
    file = vocabulary_path,
    algo = "sha256",
    serialize = FALSE
  )
  yaml::write_yaml(mapping, mapping_path)

  expect_error(
    write_eml_from_sdp(package_path),
    "reviewed vocabulary snapshot hash"
  )
})
