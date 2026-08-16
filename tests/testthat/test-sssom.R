sssom_test_text <- function(
    mapping_set_id = "https://example.org/mappings/psc-to-gcdfo",
    mapping_set_version = "2026-07-31",
    object_source = "https://w3id.org/gcdfo/salmon",
    object_source_version = "0.0.8",
    rows = NULL,
    extra_prefixes = character(),
    extra_metadata = character()) {
  if (is.null(rows)) {
    rows <- paste(
      "psc:PSC-CV-000001",
      "Net",
      "skos:exactMatch",
      "gcdfo:FixedSiteCensusManual",
      "Fixed Site Census (Manual)",
      "semapv:ManualMappingCuration",
      sep = "\t"
    )
  }

  prefixes <- c(
    "#   psc: https://w3id.org/psc/vocab/concept/",
    "#   gcdfo: https://w3id.org/gcdfo/salmon#",
    "#   skos: http://www.w3.org/2004/02/skos/core#",
    "#   semapv: https://w3id.org/semapv/vocab/",
    "#   sssom: https://w3id.org/sssom/",
    extra_prefixes
  )

  paste0(
    paste(
      c(
        "# sssom_version: 1.1",
        paste0("# mapping_set_id: ", mapping_set_id),
        paste0("# mapping_set_version: ", mapping_set_version),
        "# license: https://creativecommons.org/licenses/by/4.0/",
        "# subject_source: https://w3id.org/psc/vocab/",
        "# subject_source_version: v0.2.0",
        paste0("# object_source: ", object_source),
        paste0("# object_source_version: ", object_source_version),
        extra_metadata,
        "# curie_map:",
        prefixes,
        paste(
          "subject_id",
          "subject_label",
          "predicate_id",
          "object_id",
          "object_label",
          "mapping_justification",
          sep = "\t"
        ),
        rows
      ),
      collapse = "\n"
    ),
    "\n"
  )
}

sssom_test_write_raw <- function(path, text) {
  writeBin(charToRaw(enc2utf8(text)), path)
  invisible(path)
}

sssom_test_manifest <- function(path) {
  jsonlite::read_json(path, simplifyVector = FALSE)
}

test_that("read_sssom_mapping_set reads and validates SSSOM 1.1 embedded TSV", {
  root <- withr::local_tempdir()
  path <- file.path(root, "psc-to-gcdfo.sssom.tsv")
  sssom_test_write_raw(path, sssom_test_text())

  result <- read_sssom_mapping_set(path)

  expect_s3_class(result, "metasalmon_sssom_mapping_set")
  expect_identical(result$metadata$sssom_version, "1.1")
  expect_identical(
    result$metadata$curie_map$psc,
    "https://w3id.org/psc/vocab/concept/"
  )
  expect_s3_class(result$mappings, "tbl_df")
  expect_identical(nrow(result$mappings), 1L)
  expect_identical(result$mappings$predicate_id, "skos:exactMatch")
  expect_true(isTRUE(validate_sdp_sssom(path)))
})

test_that("SSSOM validation supports an explicit 1:0 no-match record", {
  root <- withr::local_tempdir()
  path <- file.path(root, "psc-to-sdo-gaps.sssom.tsv")
  row <- paste(
    "psc:PSC-CV-000101",
    "Effective female spawner abundance",
    "skos:relatedMatch",
    "sssom:NoTermFound",
    "",
    "semapv:ManualMappingCuration",
    "1:0",
    sep = "\t"
  )
  text <- sssom_test_text(
    mapping_set_id = "https://example.org/mappings/psc-to-sdo-gaps",
    object_source = "https://w3id.org/smn/",
    object_source_version = "2026-07-31",
    rows = row
  )
  text <- sub(
    "mapping_justification\n",
    "mapping_justification\tmapping_cardinality\n",
    text,
    fixed = TRUE
  )
  sssom_test_write_raw(path, text)

  result <- read_sssom_mapping_set(path)

  expect_identical(result$mappings$object_id, "sssom:NoTermFound")
  expect_identical(result$mappings$mapping_cardinality, "1:0")

  invalid_path <- file.path(root, "invalid-gap.sssom.tsv")
  sssom_test_write_raw(invalid_path, sub("\t1:0\n", "\t1:1\n", text, fixed = TRUE))
  expect_error(
    read_sssom_mapping_set(invalid_path),
    "NoTermFound.*1:0|1:0.*NoTermFound"
  )
})

test_that("NoTermFound is scoped, versioned, and cannot contradict a match", {
  root <- withr::local_tempdir()

  missing_version_path <- file.path(root, "missing-object-version.sssom.tsv")
  missing_version <- sub(
    "# object_source_version: 0.0.8\n",
    "",
    sssom_test_text(),
    fixed = TRUE
  )
  sssom_test_write_raw(missing_version_path, missing_version)
  expect_error(
    read_sssom_mapping_set(missing_version_path),
    "object_source_version"
  )

  misplaced_path <- file.path(root, "misplaced-sentinel.sssom.tsv")
  misplaced <- sub(
    "skos:exactMatch",
    "sssom:NoTermFound",
    sssom_test_text(),
    fixed = TRUE
  )
  sssom_test_write_raw(misplaced_path, misplaced)
  expect_error(
    read_sssom_mapping_set(misplaced_path),
    "NoTermFound.*subject_id.*object_id|subject_id.*object_id.*NoTermFound"
  )

  contradiction_path <- file.path(root, "contradictory-gap.sssom.tsv")
  positive <- paste(
    "psc:PSC-CV-000001",
    "Net",
    "skos:exactMatch",
    "gcdfo:FixedSiteCensusManual",
    "Fixed Site Census (Manual)",
    "semapv:ManualMappingCuration",
    "1:1",
    sep = "\t"
  )
  gap <- paste(
    "psc:PSC-CV-000001",
    "Net",
    "skos:relatedMatch",
    "sssom:NoTermFound",
    "",
    "semapv:ManualMappingCuration",
    "1:0",
    sep = "\t"
  )
  contradiction <- sssom_test_text(rows = paste(positive, gap, sep = "\n"))
  contradiction <- sub(
    "mapping_justification\n",
    "mapping_justification\tmapping_cardinality\n",
    contradiction,
    fixed = TRUE
  )
  sssom_test_write_raw(contradiction_path, contradiction)
  expect_error(
    read_sssom_mapping_set(contradiction_path),
    "NoTermFound.*positive|positive.*NoTermFound|contradict"
  )
})

test_that("SSSOM validation refuses invalid byte and delimiter formats", {
  root <- withr::local_tempdir()
  valid <- sssom_test_text()

  bom_path <- file.path(root, "bom.sssom.tsv")
  writeBin(c(as.raw(c(0xef, 0xbb, 0xbf)), charToRaw(valid)), bom_path)
  expect_error(read_sssom_mapping_set(bom_path), "BOM")

  crlf_path <- file.path(root, "crlf.sssom.tsv")
  sssom_test_write_raw(crlf_path, gsub("\n", "\r\n", valid, fixed = TRUE))
  expect_error(read_sssom_mapping_set(crlf_path), "LF|carriage")

  comma_path <- file.path(root, "comma.sssom.tsv")
  sssom_test_write_raw(comma_path, gsub("\t", ",", valid, fixed = TRUE))
  expect_error(read_sssom_mapping_set(comma_path), "tab")
})

test_that("SSSOM validation refuses unknown prefixes and missing required fields", {
  root <- withr::local_tempdir()

  unknown_path <- file.path(root, "unknown-prefix.sssom.tsv")
  unknown <- sub(
    "gcdfo:FixedSiteCensusManual",
    "mystery:Term",
    sssom_test_text(),
    fixed = TRUE
  )
  sssom_test_write_raw(unknown_path, unknown)
  expect_error(read_sssom_mapping_set(unknown_path), "unknown CURIE prefix.*mystery")

  missing_path <- file.path(root, "missing-required.sssom.tsv")
  missing <- gsub("\tmapping_justification", "", sssom_test_text(), fixed = TRUE)
  missing <- gsub("\tsemapv:ManualMappingCuration", "", missing, fixed = TRUE)
  sssom_test_write_raw(missing_path, missing)
  expect_error(read_sssom_mapping_set(missing_path), "mapping_justification")
})

test_that("SSSOM mapping sets cannot carry decompositions or literal assignments", {
  root <- withr::local_tempdir()

  decomposition_path <- file.path(root, "decomposition.sssom.tsv")
  decomposition <- sub(
    "mapping_justification\n",
    "mapping_justification\tcomponent_id\n",
    sssom_test_text(),
    fixed = TRUE
  )
  decomposition <- sub(
    "semapv:ManualMappingCuration\n",
    "semapv:ManualMappingCuration\tsmn:SpawnerStageContext\n",
    decomposition,
    fixed = TRUE
  )
  sssom_test_write_raw(decomposition_path, decomposition)
  expect_error(read_sssom_mapping_set(decomposition_path), "decomposition|component_id")

  literal_path <- file.path(root, "literal.sssom.tsv")
  literal <- sub(
    "mapping_justification\n",
    "mapping_justification\tobject_type\n",
    sssom_test_text(extra_prefixes =
      "#   rdfs: http://www.w3.org/2000/01/rdf-schema#"),
    fixed = TRUE
  )
  literal <- sub(
    "semapv:ManualMappingCuration\n",
    "semapv:ManualMappingCuration\trdfs literal\n",
    literal,
    fixed = TRUE
  )
  sssom_test_write_raw(literal_path, literal)
  expect_error(read_sssom_mapping_set(literal_path), "literal")
})

test_that("write_sdp_sssom writes deterministic mapping sets and manifest provenance", {
  source_root <- withr::local_tempdir()
  first_source <- file.path(source_root, "z-gaps.sssom.tsv")
  second_source <- file.path(source_root, "a-approved.sssom.tsv")
  sssom_test_write_raw(
    first_source,
    sssom_test_text(
      mapping_set_id = "https://example.org/mappings/z-gaps",
      object_source = "https://w3id.org/smn/",
      object_source_version = "2026-07-31"
    )
  )
  sssom_test_write_raw(
    second_source,
    sssom_test_text(
      mapping_set_id = "https://example.org/mappings/a-approved"
    )
  )

  first_sdp <- withr::local_tempdir()
  second_sdp <- withr::local_tempdir()
  first_manifest_path <- write_sdp_sssom(
    first_sdp,
    mapping_sets = c(first_source, second_source)
  )
  second_manifest_path <- write_sdp_sssom(
    second_sdp,
    mapping_sets = c(second_source, first_source)
  )

  expect_identical(
    first_manifest_path,
    file.path(
      normalizePath(first_sdp, winslash = "/", mustWork = TRUE),
      "metadata",
      "semantic",
      "mapping-sets.json"
    )
  )
  first_files <- sort(list.files(
    file.path(first_sdp, "metadata", "semantic"),
    full.names = FALSE
  ))
  second_files <- sort(list.files(
    file.path(second_sdp, "metadata", "semantic"),
    full.names = FALSE
  ))
  expect_identical(first_files, second_files)
  for (file in first_files) {
    expect_identical(
      readBin(
        file.path(first_sdp, "metadata", "semantic", file),
        what = "raw",
        n = file.info(file.path(first_sdp, "metadata", "semantic", file))$size
      ),
      readBin(
        file.path(second_sdp, "metadata", "semantic", file),
        what = "raw",
        n = file.info(file.path(second_sdp, "metadata", "semantic", file))$size
      )
    )
  }

  manifest <- sssom_test_manifest(first_manifest_path)
  expect_identical(manifest$schema_version, "1.0")
  expect_identical(manifest$sssom_version, "1.1")
  expect_identical(
    vapply(manifest$mapping_sets, `[[`, character(1), "mapping_set_id"),
    sort(vapply(manifest$mapping_sets, `[[`, character(1), "mapping_set_id"))
  )
  expect_true(all(vapply(
    manifest$mapping_sets,
    function(entry) grepl(
      "^metadata/semantic/[A-Za-z0-9._-]+\\.sssom\\.tsv$",
      entry$path
    ),
    logical(1)
  )))
  expect_true(all(vapply(
    manifest$mapping_sets,
    function(entry) grepl("^[0-9a-f]{64}$", entry$sha256),
    logical(1)
  )))
  expect_true(all(vapply(
    manifest$mapping_sets,
    function(entry) identical(entry$row_count, 1L),
    logical(1)
  )))
  expect_identical(
    manifest$provenance$generated_by,
    "metasalmon::write_sdp_sssom"
  )
  expect_false(grepl(source_root, paste(readLines(first_manifest_path), collapse = ""), fixed = TRUE))
  expect_true(isTRUE(validate_sdp_sssom(first_sdp)))
})

test_that("write_sdp_sssom is explicit, non-inventive, and overwrite-safe", {
  sdp <- withr::local_tempdir()

  expect_null(write_sdp_sssom(sdp, mapping_sets = NULL))
  expect_false(file.exists(file.path(sdp, "metadata", "semantic")))

  source <- file.path(withr::local_tempdir(), "approved.sssom.tsv")
  sssom_test_write_raw(source, sssom_test_text())
  manifest_path <- write_sdp_sssom(sdp, mapping_sets = source)
  before <- readBin(manifest_path, "raw", n = file.info(manifest_path)$size)

  expect_error(
    write_sdp_sssom(sdp, mapping_sets = source),
    "already exists|overwrite"
  )
  expect_identical(
    write_sdp_sssom(sdp, mapping_sets = source, overwrite = TRUE),
    manifest_path
  )
  after <- readBin(manifest_path, "raw", n = file.info(manifest_path)$size)
  expect_identical(after, before)
})

test_that("validate_sdp_sssom detects unsafe paths and manifest drift", {
  source <- file.path(withr::local_tempdir(), "approved.sssom.tsv")
  sssom_test_write_raw(source, sssom_test_text())

  unsafe_sdp <- withr::local_tempdir()
  unsafe_manifest_path <- write_sdp_sssom(unsafe_sdp, mapping_sets = source)
  unsafe_manifest <- sssom_test_manifest(unsafe_manifest_path)
  unsafe_manifest$mapping_sets[[1]]$path <- "metadata/semantic/../outside.sssom.tsv"
  writeLines(
    jsonlite::toJSON(unsafe_manifest, auto_unbox = TRUE, pretty = TRUE),
    unsafe_manifest_path,
    useBytes = TRUE
  )
  expect_error(validate_sdp_sssom(unsafe_sdp), "safe relative|unsafe")

  drift_sdp <- withr::local_tempdir()
  drift_manifest_path <- write_sdp_sssom(drift_sdp, mapping_sets = source)
  drift_manifest <- sssom_test_manifest(drift_manifest_path)
  drift_manifest$mapping_sets[[1]]$sha256 <- paste(rep("0", 64L), collapse = "")
  writeLines(
    jsonlite::toJSON(drift_manifest, auto_unbox = TRUE, pretty = TRUE),
    drift_manifest_path,
    useBytes = TRUE
  )
  expect_error(validate_sdp_sssom(drift_sdp), "SHA-256|hash")
})

test_that("SSSOM public entry points are exported", {
  expect_true("read_sssom_mapping_set" %in% getNamespaceExports("metasalmon"))
  expect_true("write_sdp_sssom" %in% getNamespaceExports("metasalmon"))
  expect_true("validate_sdp_sssom" %in% getNamespaceExports("metasalmon"))
})

test_that("the validator accepts a metasalmonpy-written manifest provenance", {
  # Parity-deviations register row 11: the Python mirror writes
  # byte-identical mapping-set artifacts and honestly names itself in the
  # manifest provenance. Rejecting that provenance would make every
  # Python-written SDP fail R validation for no data reason.
  sdp <- withr::local_tempdir()
  source <- file.path(withr::local_tempdir(), "approved.sssom.tsv")
  sssom_test_write_raw(source, sssom_test_text())
  write_sdp_sssom(sdp, mapping_sets = source, overwrite = TRUE)

  manifest_path <- file.path(sdp, "metadata", "semantic", "mapping-sets.json")
  manifest <- jsonlite::read_json(manifest_path, simplifyVector = FALSE)
  manifest$provenance <- list(
    generated_by = "metasalmonpy.write_sdp_sssom",
    metasalmonpy_version = "0.1.7"
  )
  writeLines(
    jsonlite::toJSON(manifest, auto_unbox = TRUE, pretty = TRUE, null = "null"),
    manifest_path
  )

  expect_true(isTRUE(validate_sdp_sssom(sdp)))

  # An unknown generator, or a known one missing its version, stays rejected.
  manifest$provenance <- list(generated_by = "someone-else", version = "1")
  writeLines(
    jsonlite::toJSON(manifest, auto_unbox = TRUE, pretty = TRUE, null = "null"),
    manifest_path
  )
  expect_error(validate_sdp_sssom(sdp), "provenance is incomplete")
  manifest$provenance <- list(generated_by = "metasalmonpy.write_sdp_sssom")
  writeLines(
    jsonlite::toJSON(manifest, auto_unbox = TRUE, pretty = TRUE, null = "null"),
    manifest_path
  )
  expect_error(validate_sdp_sssom(sdp), "provenance is incomplete")
})
