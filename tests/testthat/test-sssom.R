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

# sssom_test_text()'s mapping set, written in the canonical SSSOM/TSV form
# (https://mapping-commons.github.io/sssom/1.0/spec-formats-tsv/#canonical-sssomtsv-format):
# no space between `#` and the YAML, slots in the order of the MappingSet
# "Slots" table (so `curie_map` second), plain scalars except `sssom_version`,
# which plain style would read back as a number, and a CURIE map holding only
# the prefixes the set uses, sorted, with no built-in prefix in it, because a
# canonical writer "MUST NOT include in the CURIE map the prefix names that are
# considered 'built-in'". So `skos` and `semapv` are used and never declared.
sssom_test_canonical_text <- function(
    curie_map = c(
      "#  gcdfo: https://w3id.org/gcdfo/salmon#",
      "#  psc: https://w3id.org/psc/vocab/concept/"
    ),
    predicate_id = "skos:exactMatch") {
  paste0(
    paste(
      c(
        "#sssom_version: \"1.1\"",
        "#curie_map:",
        curie_map,
        "#mapping_set_id: https://example.org/mappings/psc-to-gcdfo",
        "#mapping_set_version: 2026-07-31",
        "#license: https://creativecommons.org/licenses/by/4.0/",
        "#subject_source: https://w3id.org/psc/vocab/",
        "#subject_source_version: v0.2.0",
        "#object_source: https://w3id.org/gcdfo/salmon",
        "#object_source_version: 0.0.8",
        paste(
          "subject_id",
          "subject_label",
          "predicate_id",
          "object_id",
          "object_label",
          "mapping_justification",
          sep = "\t"
        ),
        paste(
          "psc:PSC-CV-000001",
          "Net",
          predicate_id,
          "gcdfo:FixedSiteCensusManual",
          "Fixed Site Census (Manual)",
          "semapv:ManualMappingCuration",
          sep = "\t"
        )
      ),
      collapse = "\n"
    ),
    "\n"
  )
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

# Hub B-233. The SSSOM model lets a mapping set omit the built-in prefixes from
# its curie_map and requires any it declares to keep the built-in IRI prefix:
# "By exception, prefix names listed in the table found in the IRI prefixes
# section are considered 'built-in'. As such, they MAY be omitted from the
# curie_map. If they are not omitted, they MUST point to the same IRI prefixes
# as in the aforementioned table."
# (https://mapping-commons.github.io/sssom/1.0/spec-model/#identifiers; the same
# words on the 1.1 draft at https://mapping-commons.github.io/sssom/dev/spec-model/).
# The reader used to demand every prefix in the curie_map, so it refused every
# canonical file, which never declares `skos` or `semapv`.
test_that("read_sssom_mapping_set reads a canonical SSSOM/TSV file that omits the built-in prefixes", {
  root <- withr::local_tempdir()
  path <- file.path(root, "psc-to-gcdfo.sssom.tsv")
  sssom_test_write_raw(path, sssom_test_canonical_text())

  result <- read_sssom_mapping_set(path)

  expect_identical(names(result$metadata$curie_map), c("gcdfo", "psc"))
  expect_identical(result$mappings$predicate_id, "skos:exactMatch")
  expect_identical(
    result$mappings$mapping_justification,
    "semapv:ManualMappingCuration"
  )
  expect_true(isTRUE(validate_sdp_sssom(path)))
})

test_that("each SSSOM built-in prefix may be omitted from the curie_map", {
  # The table in the IRI prefixes section of the specification, in its order
  # (https://mapping-commons.github.io/sssom/1.0/spec-intro/#iri-prefixes,
  # unchanged on the 1.1 draft).
  builtin <- c(
    owl = "http://www.w3.org/2002/07/owl#",
    rdf = "http://www.w3.org/1999/02/22-rdf-syntax-ns#",
    rdfs = "http://www.w3.org/2000/01/rdf-schema#",
    semapv = "https://w3id.org/semapv/vocab/",
    skos = "http://www.w3.org/2004/02/skos/core#",
    sssom = "https://w3id.org/sssom/",
    xsd = "http://www.w3.org/2001/XMLSchema#",
    linkml = "https://w3id.org/linkml/"
  )

  # The local name is a placeholder that nothing dereferences: the reader
  # checks that a prefix resolves, not what a term means.
  root <- withr::local_tempdir()
  for (prefix in names(builtin)) {
    path <- file.path(root, paste0(prefix, ".sssom.tsv"))
    sssom_test_write_raw(
      path,
      sssom_test_canonical_text(predicate_id = paste0(prefix, ":placeholder"))
    )
    expect_no_error(read_sssom_mapping_set(path))
  }

  # Pinned because the reader's table is copied from the specification rather
  # than derived from anything.
  expect_identical(metasalmon:::.ms_sssom_builtin_prefixes, builtin)
})

test_that("an undeclared prefix that is not a built-in is still refused", {
  # SSSOM/TSV: "parsers MUST reject a file with undeclared, non-built-in prefix
  # names". `dcterms` is in the SSSOM LinkML schema's own `prefixes:` block and
  # is not built-in, which is the distinction this pins; `SKOS` differs from a
  # built-in only in case, and prefix names are case-sensitive.
  root <- withr::local_tempdir()
  for (prefix in c("dcterms", "SKOS")) {
    path <- file.path(root, paste0(prefix, ".sssom.tsv"))
    sssom_test_write_raw(
      path,
      sssom_test_canonical_text(predicate_id = paste0(prefix, ":placeholder"))
    )
    expect_error(
      read_sssom_mapping_set(path),
      paste0("unknown CURIE prefix.*", prefix)
    )
  }

  undeclared_path <- file.path(root, "undeclared-subject.sssom.tsv")
  sssom_test_write_raw(
    undeclared_path,
    sssom_test_canonical_text(
      curie_map = "#  gcdfo: https://w3id.org/gcdfo/salmon#"
    )
  )
  expect_error(
    read_sssom_mapping_set(undeclared_path),
    "unknown CURIE prefix.*psc"
  )
})

test_that("a curie_map entry may repeat a built-in prefix but not redefine it", {
  # Every prefix the set uses is declared in each file below, so the reader
  # before hub B-233, which knew no built-ins, accepted all three: the two
  # redefinitions were read as ordinary declarations.
  root <- withr::local_tempdir()
  declared <- c(
    "#  gcdfo: https://w3id.org/gcdfo/salmon#",
    "#  psc: https://w3id.org/psc/vocab/concept/",
    "#  semapv: https://w3id.org/semapv/vocab/"
  )

  repeated_path <- file.path(root, "repeated.sssom.tsv")
  sssom_test_write_raw(
    repeated_path,
    sssom_test_canonical_text(curie_map = c(
      declared,
      "#  skos: http://www.w3.org/2004/02/skos/core#"
    ))
  )
  expect_identical(
    read_sssom_mapping_set(repeated_path)$metadata$curie_map$skos,
    "http://www.w3.org/2004/02/skos/core#"
  )

  # The scheme alone is enough to make a different IRI prefix.
  https_path <- file.path(root, "https-skos.sssom.tsv")
  sssom_test_write_raw(
    https_path,
    sssom_test_canonical_text(curie_map = c(
      declared,
      "#  skos: https://www.w3.org/2004/02/skos/core#"
    ))
  )
  expect_error(
    read_sssom_mapping_set(https_path),
    "redefines built-in prefix.*skos"
  )

  # The rule is on the declaration, so it holds for a prefix nothing uses.
  unused_path <- file.path(root, "unused-owl.sssom.tsv")
  sssom_test_write_raw(
    unused_path,
    sssom_test_canonical_text(curie_map = c(
      declared,
      "#  owl: https://example.org/owl#",
      "#  skos: http://www.w3.org/2004/02/skos/core#"
    ))
  )
  expect_error(
    read_sssom_mapping_set(unused_path),
    "redefines built-in prefix.*owl"
  )
})

test_that("write_sdp_sssom packages a canonical mapping set", {
  source <- file.path(withr::local_tempdir(), "psc-to-gcdfo.sssom.tsv")
  sssom_test_write_raw(source, sssom_test_canonical_text())

  sdp <- withr::local_tempdir()
  write_sdp_sssom(sdp, mapping_sets = source)

  expect_true(isTRUE(validate_sdp_sssom(sdp)))
  written <- read_sssom_mapping_set(
    file.path(sdp, "metadata", "semantic", "psc-to-gcdfo.sssom.tsv")
  )
  expect_identical(names(written$metadata$curie_map), c("gcdfo", "psc"))
})

test_that("write_sdp_sssom refuses an in-memory set that redefines a built-in prefix", {
  # A parsed set handed to the writer never passes back through the file
  # parser, so the rule has to hold on the in-memory path as well, and before
  # anything is written.
  source <- file.path(withr::local_tempdir(), "approved.sssom.tsv")
  sssom_test_write_raw(source, sssom_test_text())
  redefined <- read_sssom_mapping_set(source)
  redefined$metadata$curie_map$skos <- "https://example.org/skos#"

  sdp <- withr::local_tempdir()
  expect_error(
    write_sdp_sssom(sdp, mapping_sets = redefined),
    "redefines built-in prefix.*skos"
  )
  expect_false(file.exists(file.path(sdp, "metadata", "semantic")))
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

test_that("validate_salmon_datapackage refuses a corrupt SSSOM artifact", {
  # #49 (hub B-49). The end-to-end validator reported success over a
  # mapping-set manifest whose SHA-256 no longer matched its bytes; only the
  # KNB publication and archive paths ran validate_sdp_sssom(). Presence is
  # detected the way those two paths detect it -- by the manifest, never by
  # scanning metadata/semantic -- so an unapproved draft there stays local.
  root <- withr::local_tempdir()
  make_eml_test_sdp(root)
  source <- file.path(withr::local_tempdir(), "approved.sssom.tsv")
  sssom_test_write_raw(source, sssom_test_text())
  manifest_path <- write_sdp_sssom(root, mapping_sets = source)
  expect_no_error(
    suppressWarnings(suppressMessages(validate_salmon_datapackage(root)))
  )

  manifest <- sssom_test_manifest(manifest_path)
  manifest$mapping_sets[[1]]$sha256 <- paste(rep("0", 64L), collapse = "")
  writeLines(
    jsonlite::toJSON(manifest, auto_unbox = TRUE, pretty = TRUE),
    manifest_path,
    useBytes = TRUE
  )
  expect_error(
    suppressWarnings(suppressMessages(validate_salmon_datapackage(root))),
    "SHA-256|hash"
  )
})

test_that("validate_salmon_datapackage never evaluates an !expr tag in SSSOM metadata", {
  # Codex security review of #111 (P1 advisory). Because the validator now
  # reaches the SSSOM reader during routine validation of a collaborator's
  # package, the reader's `yaml::yaml.load()` on the embedded metadata block
  # must never evaluate R: `mapping_set_title: !expr system("...")` would run
  # before any field or hash check, and none of those checks authenticates
  # the file's author. yaml's own default is `getOption("yaml.eval.expr",
  # FALSE)`, so the worst case is a session that turned the option on; the
  # reader passes `eval.expr = FALSE` explicitly so that option cannot reach
  # it. The tag is installed by patching the bytes the manifest already
  # binds (and its SHA-256) so the only reader that meets it is the
  # validator's. The reader must refuse the tag rather than return its
  # unevaluated payload as a metadata value.
  root <- withr::local_tempdir()
  make_eml_test_sdp(root)
  source <- file.path(withr::local_tempdir(), "approved.sssom.tsv")
  sssom_test_write_raw(
    source,
    sssom_test_text(extra_metadata = "# mapping_set_title: Approved mappings")
  )
  manifest_path <- write_sdp_sssom(root, mapping_sets = source)
  manifest <- sssom_test_manifest(manifest_path)
  installed <- file.path(root, manifest$mapping_sets[[1]]$path)

  sentinel <- file.path(withr::local_tempdir(), "evaluated")
  expression_title <- sprintf("file.create(\"%s\")", sentinel)
  # The writer renders scalars double-quoted; the patch replaces that line.
  text <- rawToChar(readBin(installed, "raw", file.info(installed)$size))
  benign_line <- "# mapping_set_title: \"Approved mappings\""
  expect_match(text, benign_line, fixed = TRUE)
  text <- sub(
    benign_line,
    paste0("# mapping_set_title: !expr ", expression_title),
    text,
    fixed = TRUE
  )
  sssom_test_write_raw(installed, text)
  manifest$mapping_sets[[1]]$sha256 <- digest::digest(
    charToRaw(enc2utf8(text)),
    algo = "sha256",
    serialize = FALSE
  )
  writeLines(
    jsonlite::toJSON(manifest, auto_unbox = TRUE, pretty = TRUE),
    manifest_path,
    useBytes = TRUE
  )

  withr::local_options(yaml.eval.expr = TRUE)
  expect_error(
    suppressWarnings(suppressMessages(validate_salmon_datapackage(root))),
    "explicit YAML tags"
  )
  expect_false(file.exists(sentinel))
  expect_error(
    suppressWarnings(read_sssom_mapping_set(installed)),
    paste0(basename(installed), ".*explicit YAML tags")
  )
  expect_false(file.exists(sentinel))
})

test_that("SSSOM metadata refuses YAML node tags and keeps exclamation text", {
  root <- withr::local_tempdir()
  tagged <- c(
    "!foo X",
    "!foo'bar X",
    "!!str X",
    "&a !foo X",
    "!<tag:yaml.org,2002:str> X",
    "!<tag:example.org,2026:foo'bar> X",
    "[!foo X]",
    "[!foo'bar X]",
    '["!foo", !foo\'bar X]',
    "{item: !foo X}",
    "{item: !foo'bar X}",
    "[&a !foo X]",
    '{"item":!foo X}',
    "{? !foo x: y}",
    "[? !foo x: y]",
    "{? &a !foo x: y}"
  )
  for (i in seq_along(tagged)) {
    path <- file.path(root, sprintf("tagged-%02d.sssom.tsv", i))
    sssom_test_write_raw(
      path,
      sssom_test_text(extra_metadata = paste0("# mapping_set_title: ", tagged[[i]]))
    )
    expect_error(
      read_sssom_mapping_set(path),
      paste0(basename(path), ".*explicit YAML tags"),
      info = tagged[[i]]
    )
  }

  nested <- sub(
    "#   psc: https://w3id.org/psc/vocab/concept/",
    "#   psc: !foo https://w3id.org/psc/vocab/concept/",
    sssom_test_text(),
    fixed = TRUE
  )
  nested_path <- file.path(root, "nested-tag.sssom.tsv")
  sssom_test_write_raw(nested_path, nested)
  expect_error(
    read_sssom_mapping_set(nested_path),
    paste0(basename(nested_path), ".*explicit YAML tags")
  )

  multiline <- list(
    c("# mapping_set_title: [", "#   Good,", "#   !foo X", "# ]"),
    c("# mapping_set_title: {", "#   item: !foo X", "# }")
  )
  for (i in seq_along(multiline)) {
    path <- file.path(root, sprintf("multiline-%02d.sssom.tsv", i))
    sssom_test_write_raw(path, sssom_test_text(extra_metadata = multiline[[i]]))
    expect_error(
      read_sssom_mapping_set(path),
      paste0(basename(path), ".*explicit YAML tags")
    )
  }

  ordinary <- c(
    '"!foo X"' = "!foo X",
    "\"!foo'bar X\"" = "!foo'bar X",
    "'!!str X'" = "!!str X",
    "'? !foo X'" = "? !foo X",
    '["!foo X"]' = "!foo X",
    "[\"!foo'bar X\"]" = "!foo'bar X",
    "Good !foo title" = "Good !foo title",
    "Good [!foo] title" = "Good [!foo] title",
    "[https:!text]" = "https:!text",
    "[Good ? !foo]" = "Good ? !foo"
  )
  for (i in seq_along(ordinary)) {
    path <- file.path(root, sprintf("ordinary-%02d.sssom.tsv", i))
    sssom_test_write_raw(
      path,
      sssom_test_text(extra_metadata = paste0("# mapping_set_title: ", names(ordinary)[[i]]))
    )
    expect_identical(
      read_sssom_mapping_set(path)$metadata$mapping_set_title,
      unname(ordinary[[i]])
    )
  }

  block_path <- file.path(root, "block-text.sssom.tsv")
  sssom_test_write_raw(
    block_path,
    sssom_test_text(extra_metadata = c("# mapping_set_title: |", "#   !foo X"))
  )
  expect_identical(
    read_sssom_mapping_set(block_path)$metadata$mapping_set_title,
    "!foo X"
  )

  # Quoting may span physical YAML lines. A leading exclamation mark on the
  # next line is still part of the quoted scalar, not a node tag.
  for (quote in c('"', "'")) {
    path <- file.path(root, paste0("multiline-quoted-", charToRaw(quote), ".sssom.tsv"))
    sssom_test_write_raw(
      path,
      sssom_test_text(extra_metadata = c(
        paste0("# mapping_set_title: ", quote),
        paste0("#   !foo X", quote)
      ))
    )
    expect_identical(
      read_sssom_mapping_set(path)$metadata$mapping_set_title,
      "!foo X"
    )
  }

  # A quote or tag-looking token inside earlier plain text, a YAML comment,
  # or a block scalar cannot hide a real tag or become one itself.
  preceding_values <- c("a:'", 'a:"', "Good # note:'", '"!foo"', "'!foo'")
  for (i in seq_along(preceding_values)) {
    preceding <- preceding_values[[i]]
    path <- file.path(root, sprintf("tag-after-text-%02d.sssom.tsv", i))
    sssom_test_write_raw(
      path,
      sssom_test_text(extra_metadata = c(
        paste0("# mapping_set_description: ", preceding),
        "# mapping_set_title: !foo X"
      ))
    )
    expect_error(read_sssom_mapping_set(path), "explicit YAML tags")
  }

  explicit_key_path <- file.path(root, "explicit-mapping-key-tag.sssom.tsv")
  explicit_key <- sub(
    "#   psc: https://w3id.org/psc/vocab/concept/",
    paste("#   ? psc", "#   : !foo https://w3id.org/psc/vocab/concept/", sep = "\n"),
    sssom_test_text(),
    fixed = TRUE
  )
  sssom_test_write_raw(explicit_key_path, explicit_key)
  expect_error(read_sssom_mapping_set(explicit_key_path), "explicit YAML tags")

  tag_directive_path <- file.path(root, "primary-tag-directive.sssom.tsv")
  sssom_test_write_raw(
    tag_directive_path,
    paste0(
      "# %TAG ! tag:example.org,2026:\n",
      "# ---\n",
      sssom_test_text(extra_metadata = "# mapping_set_title: !foo X")
    )
  )
  expect_error(read_sssom_mapping_set(tag_directive_path), "explicit YAML tags")

  # A verbatim-tag-looking literal must not consume a later real tag in the
  # disposable probe, even when YAML has no whitespace around a flow comma.
  verbatim_literal_cases <- list(
    c('# mapping_set_description: "!<text" # > later',
      "# mapping_set_title: !foo X"),
    '# mapping_set_title: ["!<text", !foo X>]',
    '# mapping_set_title: [Good !<text,!foo,more>]'
  )
  for (i in seq_along(verbatim_literal_cases)) {
    path <- file.path(root, sprintf("verbatim-looking-text-%02d.sssom.tsv", i))
    sssom_test_write_raw(
      path,
      sssom_test_text(extra_metadata = verbatim_literal_cases[[i]])
    )
    expect_error(read_sssom_mapping_set(path), "explicit YAML tags")
  }

  literal_bang_key_path <- file.path(root, "literal-bang-key-tag.sssom.tsv")
  sssom_test_write_raw(
    literal_bang_key_path,
    sssom_test_text(extra_metadata = "# mapping_set_title: {a!text: !foo X}")
  )
  expect_error(read_sssom_mapping_set(literal_bang_key_path), "explicit YAML tags")

  continuations <- list(
    c("# mapping_set_title: Good", "#   !foo"),
    c("# mapping_set_title: Good", "#   - !foo")
  )
  for (i in seq_along(continuations)) {
    path <- file.path(root, sprintf("plain-continuation-%02d.sssom.tsv", i))
    sssom_test_write_raw(path, sssom_test_text(extra_metadata = continuations[[i]]))
    expect_identical(
      read_sssom_mapping_set(path)$metadata$mapping_set_title,
      c("Good !foo", "Good - !foo")[[i]]
    )
  }

  flow_text_path <- file.path(root, "flow-text.sssom.tsv")
  sssom_test_write_raw(
    flow_text_path,
    sssom_test_text(extra_metadata = '# mapping_set_title: [Good "text":!foo]')
  )
  expect_identical(
    read_sssom_mapping_set(flow_text_path)$metadata$mapping_set_title,
    'Good "text":!foo'
  )

  sequence_block_path <- file.path(root, "sequence-block-text.sssom.tsv")
  sssom_test_write_raw(
    sequence_block_path,
    sssom_test_text(extra_metadata = c("# creator_label:", "#   - |", "#     !foo"))
  )
  expect_identical(
    read_sssom_mapping_set(sequence_block_path)$metadata$creator_label,
    "!foo"
  )
})
