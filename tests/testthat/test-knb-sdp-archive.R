make_sdp_archive_sssom <- function(path) {
  source_directory <- tempfile(pattern = "sssom-source-")
  dir.create(source_directory, recursive = TRUE, showWarnings = FALSE)
  source <- file.path(source_directory, "psc-to-sdo-gaps.sssom.tsv")
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
    source
  )
  write_sdp_sssom(path, mapping_sets = source)
}

make_sdp_archive_decompositions <- function(path) {
  rows <- tibble::tribble(
    ~dataset_id, ~table_id, ~column_name, ~measurement_concept_iri,
    ~component_order, ~component_role, ~component_status,
    ~component_relation, ~related_component_order, ~component_iri,
    ~component_label, ~rationale, ~source, ~source_version, ~source_url,
    ~provenance,
    "demo-salmon-2026", "counts", "count",
    "https://w3id.org/smn/ObservedRateOrAbundance",
    1L, "property", "matched", "", NA_integer_,
    "http://qudt.org/vocab/quantitykind/Count", "Count",
    "The reviewed dictionary property is retained.",
    "qudt", "3.1.1", "https://qudt.org/3.1.1/vocab/quantitykind/",
    "Reviewed fixture component.",
    "demo-salmon-2026", "counts", "count",
    "https://w3id.org/smn/ObservedRateOrAbundance",
    2L, "entity", "matched", "", NA_integer_,
    "https://w3id.org/smn/Stock", "Stock",
    "The reviewed dictionary entity is retained.",
    "smn", "2026-07-31", "https://w3id.org/smn/",
    "Reviewed fixture component.",
    "demo-salmon-2026", "counts", "count",
    "https://w3id.org/smn/ObservedRateOrAbundance",
    3L, "unit", "matched", "", NA_integer_,
    "http://qudt.org/vocab/unit/COUNT", "Count",
    "The reviewed dictionary unit is retained.",
    "qudt", "3.1.1", "https://qudt.org/3.1.1/vocab/unit/",
    "Reviewed fixture component."
  )

  write_sdp_measurement_decompositions(path, decompositions = rows)
}

test_that("SDP ZIP construction is bound to the reviewed zip implementation", {
  expect_silent(.ms_knb_require_zip_version("3.0.1"))
  expect_error(
    .ms_knb_require_zip_version("2.3.3"),
    "zip 3[.]0[.]1.*found 2[.]3[.]3"
  )
})

test_that("canonical SDP ZIP has one closed, valid, friendly inventory", {
  package_path <- make_eml_test_sdp(withr::local_tempdir())
  dir.create(
    file.path(package_path, "metadata", "semantic"),
    recursive = TRUE,
    showWarnings = FALSE
  )
  dir.create(
    file.path(package_path, "publication"),
    recursive = TRUE,
    showWarnings = FALSE
  )
  writeBin(
    charToRaw("EML is a publication object, not an SDP ZIP member."),
    file.path(package_path, "metadata", "eml.xml")
  )
  writeBin(
    charToRaw("unlisted semantic review note"),
    file.path(package_path, "metadata", "semantic", "review-note.txt")
  )
  writeBin(
    charToRaw("mutable upload receipt"),
    file.path(package_path, "publication", "knb-manifest.json")
  )
  writeBin(
    charToRaw("unlisted root decoy"),
    file.path(package_path, "private-note.txt")
  )

  expected <- c(
    "data/counts.csv",
    "datapackage.json",
    "metadata/codes.csv",
    "metadata/column_dictionary.csv",
    "metadata/dataset.csv",
    "metadata/semantic_vocabulary.csv",
    "metadata/tables.csv",
    "reviewed_semantic_selections.csv"
  )
  inventory <- .ms_knb_sdp_archive_inventory(package_path)
  expect_identical(names(inventory), expected)
  expect_true(all(file.exists(unname(inventory))))

  archive <- .ms_knb_write_sdp_archive(package_path)
  expect_identical(
    archive$file_name,
    "demo-salmon-2026-salmon-data-package.zip"
  )
  expect_identical(archive$members, expected)
  expect_identical(archive$format_id, "application/zip")
  expect_identical(archive$media_type, "application/zip")
  expect_match(archive$sha256, "^[0-9a-f]{64}$")
  expect_equal(archive$size, file.info(archive$path)$size)

  zip_inventory <- zip::zip_list(archive$path)
  expect_identical(as.character(zip_inventory$filename), expected)
  expect_false(any(grepl("(^|/)publication/|metadata/eml\\.xml$", expected)))
  expect_false("metadata/eml-mapping.yml" %in% expected)
  expect_false(any(grepl("review-note|private-note", expected)))
  expect_equal(unique(as.character(zip_inventory$permissions)), "644")
  expect_length(unique(as.numeric(zip_inventory$timestamp)), 1L)

  extracted <- withr::local_tempdir()
  utils::unzip(archive$path, exdir = extracted)
  validation <- suppressMessages(
    suppressWarnings(validate_salmon_datapackage(
      extracted,
      require_iris = FALSE
    ))
  )
  expect_type(validation, "list")
  expect_false(file.exists(file.path(extracted, "metadata", "eml.xml")))
  expect_false(dir.exists(file.path(extracted, "publication")))
})

test_that("canonical SDP ZIP bytes ignore source roots, mtimes, and modes", {
  first_path <- make_eml_test_sdp(withr::local_tempdir())
  second_path <- make_eml_test_sdp(withr::local_tempdir())

  first_members <- list.files(first_path, recursive = TRUE, full.names = TRUE)
  second_members <- list.files(second_path, recursive = TRUE, full.names = TRUE)
  Sys.setFileTime(first_members, as.POSIXct("2004-02-03", tz = "UTC"))
  Sys.setFileTime(second_members, as.POSIXct("2026-07-31", tz = "UTC"))
  Sys.chmod(first_members, mode = "0600", use_umask = FALSE)
  Sys.chmod(second_members, mode = "0644", use_umask = FALSE)

  first <- .ms_knb_write_sdp_archive(first_path)
  second <- .ms_knb_write_sdp_archive(second_path)
  expect_identical(first$sha256, second$sha256)
  expect_identical(
    readBin(first$path, what = "raw", n = file.info(first$path)$size),
    readBin(second$path, what = "raw", n = file.info(second$path)$size)
  )

  # Replanning accepts an archive owned by the same exact source bytes even
  # when overwrite remains FALSE.
  repeated <- .ms_knb_write_sdp_archive(first_path)
  expect_identical(repeated$sha256, first$sha256)

  changed <- c(
    readBin(first$path, what = "raw", n = file.info(first$path)$size),
    as.raw(0L)
  )
  writeBin(changed, first$path)
  expect_error(
    .ms_knb_write_sdp_archive(first_path),
    "different bytes.*overwrite"
  )
  restored <- .ms_knb_write_sdp_archive(first_path, overwrite = TRUE)
  expect_identical(restored$sha256, second$sha256)
})

test_that("SDP ZIP accepts only manifest-bound semantic artifacts", {
  package_path <- make_eml_test_sdp(withr::local_tempdir())
  make_sdp_archive_sssom(package_path)
  make_sdp_archive_decompositions(package_path)
  writeBin(
    charToRaw("not declared by either manifest"),
    file.path(package_path, "metadata", "semantic", "unlisted-secret.csv")
  )

  inventory <- .ms_knb_sdp_archive_inventory(package_path)
  expect_true(all(c(
    "metadata/semantic/mapping-sets.json",
    "metadata/semantic/psc-to-sdo-gaps.sssom.tsv",
    "metadata/semantic/measurement-decompositions.csv",
    "metadata/semantic/measurement-decompositions.json"
  ) %in% names(inventory)))
  expect_false(
    "metadata/semantic/unlisted-secret.csv" %in% names(inventory)
  )
  archive <- .ms_knb_write_sdp_archive(package_path)
  expect_identical(archive$members, names(inventory))
})

test_that("SDP ZIP refuses tampered semantic manifests and members", {
  sssom_path <- make_eml_test_sdp(withr::local_tempdir())
  make_sdp_archive_sssom(sssom_path)
  mapping_path <- file.path(
    sssom_path,
    "metadata",
    "semantic",
    "psc-to-sdo-gaps.sssom.tsv"
  )
  writeBin(
    c(
      readBin(mapping_path, what = "raw", n = file.info(mapping_path)$size),
      charToRaw("# tampered\n")
    ),
    mapping_path
  )
  expect_error(
    .ms_knb_sdp_archive_inventory(sssom_path),
    "SSSOM.*SHA-256|SHA-256.*SSSOM"
  )

  decomposition_path <- make_eml_test_sdp(withr::local_tempdir())
  make_sdp_archive_decompositions(decomposition_path)
  csv_path <- file.path(
    decomposition_path,
    "metadata",
    "semantic",
    "measurement-decompositions.csv"
  )
  csv_text <- readChar(
    csv_path,
    nchars = file.info(csv_path)$size,
    useBytes = TRUE
  )
  csv_text <- sub(
    "The reviewed dictionary property is retained.",
    "The altered dictionary property is retained.",
    csv_text,
    fixed = TRUE
  )
  writeBin(
    charToRaw(enc2utf8(csv_text)),
    csv_path
  )
  expect_error(
    .ms_knb_sdp_archive_inventory(decomposition_path),
    "SHA-256|does not match"
  )
})

test_that("SDP ZIP refuses symlinked members and output", {
  skip_on_os("windows")

  member_path <- make_eml_test_sdp(withr::local_tempdir())
  declared <- file.path(member_path, "data", "counts.csv")
  target <- file.path(member_path, "data", "counts-source.csv")
  expect_true(file.rename(declared, target))
  if (!file.symlink(basename(target), declared)) {
    skip("Symbolic links are unavailable in this test environment.")
  }
  expect_error(
    .ms_knb_sdp_archive_inventory(member_path),
    "symbolic-link"
  )

  output_path <- make_eml_test_sdp(withr::local_tempdir())
  publication <- file.path(output_path, "publication")
  dir.create(publication, recursive = TRUE, showWarnings = FALSE)
  outside <- tempfile(fileext = ".zip")
  writeBin(charToRaw("not an SDP ZIP"), outside)
  archive_link <- file.path(
    publication,
    .ms_knb_sdp_archive_filename("demo-salmon-2026")
  )
  expect_true(file.symlink(outside, archive_link))
  expect_error(
    .ms_knb_write_sdp_archive(output_path),
    "symbolic-link"
  )
})

test_that("SDP ZIP rejects reserved paths even when declared as data", {
  package_path <- make_eml_test_sdp(withr::local_tempdir())
  writeBin(
    charToRaw("publication metadata"),
    file.path(package_path, "metadata", "eml.xml")
  )
  tables_path <- file.path(package_path, "metadata", "tables.csv")
  tables <- readr::read_csv(tables_path, show_col_types = FALSE)
  tables$file_name <- "metadata/eml.xml"
  readr::write_csv(tables, tables_path)

  expect_error(
    .ms_knb_sdp_archive_inventory(package_path),
    "reserved publication path.*metadata/eml.xml"
  )
})

test_that("friendly SDP ZIP filename is stable and filesystem-safe", {
  expect_identical(
    .ms_knb_sdp_archive_filename("Fraser Sockeye / Detailed 2026"),
    "fraser-sockeye-detailed-2026-salmon-data-package.zip"
  )
  expect_error(.ms_knb_sdp_archive_filename(NA_character_), "non-empty")
  expect_error(.ms_knb_sdp_archive_filename(character()), "non-empty")
})

test_that("the reviewed zip version is installable under the DESCRIPTION requirement", {
  # `.ms_knb_zip_version` and DESCRIPTION's `zip` requirement are independent
  # literals. DESCRIPTION must admit the reviewed version, and must not pin an
  # exact one (CRAN moves ahead, which would make metasalmon uninstallable).
  desc <- read.dcf(system.file("DESCRIPTION", package = "metasalmon"))
  imports <- desc[1, "Imports"]
  zip_spec <- regmatches(imports, regexpr("zip\\s*\\([^)]*\\)", imports))

  expect_length(zip_spec, 1L)
  expect_false(grepl("==", zip_spec, fixed = TRUE))
  expect_true(grepl(">=", zip_spec, fixed = TRUE))
  expect_true(grepl(.ms_knb_zip_version, zip_spec, fixed = TRUE))
})
