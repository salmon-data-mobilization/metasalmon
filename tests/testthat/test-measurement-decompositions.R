measurement_decomposition_test_concept <-
  "https://w3id.org/psc/vocab/PSC-CV-000035"

measurement_decomposition_test_columns <- c(
  "dataset_id",
  "table_id",
  "column_name",
  "measurement_concept_iri",
  "component_order",
  "component_role",
  "component_status",
  "component_relation",
  "related_component_order",
  "component_iri",
  "component_label",
  "rationale",
  "source",
  "source_version",
  "source_url",
  "provenance"
)

make_measurement_decomposition_test_sdp <- function(path) {
  make_eml_test_sdp(
    path,
    measurement_term_iri = measurement_decomposition_test_concept,
    measurement_term_label = "Effective female spawner abundance",
    measurement_term_type = "skos_concept",
    measurement_native_type = "skos:Concept",
    measurement_type_iris =
      "http://www.w3.org/2004/02/skos/core#Concept",
    measurement_resource_kind = "Concept",
    measurement_source = "psc",
    measurement_source_url = "https://w3id.org/psc/vocab/"
  )

  dictionary_path <- file.path(path, "metadata", "column_dictionary.csv")
  dictionary <- readr::read_csv(
    dictionary_path,
    show_col_types = FALSE,
    progress = FALSE
  )
  measurement_row <-
    dictionary$table_id == "counts" & dictionary$column_name == "count"
  dictionary$constraint_iri[measurement_row] <-
    "https://w3id.org/smn/SpawnerStageContext"
  readr::write_csv(dictionary, dictionary_path, na = "")

  invisible(path)
}

measurement_decomposition_test_rows <- function() {
  tibble::tribble(
    ~dataset_id, ~table_id, ~column_name, ~measurement_concept_iri,
    ~component_order, ~component_role, ~component_status, ~component_relation,
    ~related_component_order, ~component_iri, ~component_label, ~rationale,
    ~source, ~source_version, ~source_url, ~provenance,
    "demo-salmon-2026", "counts", "count",
    measurement_decomposition_test_concept,
    1L, "property", "matched", "", NA_integer_,
    "http://qudt.org/vocab/quantitykind/Count", "Count", "",
    "QUDT", "3.1.1", "https://qudt.org/3.1.1/vocab/quantitykind/",
    "Reviewed against the pinned QUDT vocabulary release.",
    "demo-salmon-2026", "counts", "count",
    measurement_decomposition_test_concept,
    2L, "entity", "matched", "", NA_integer_,
    "https://w3id.org/smn/Stock", "Stock", "",
    "SMN", "2026-07-31", "https://w3id.org/smn/",
    "Reviewed against the pinned Salmon Domain Ontology source.",
    "demo-salmon-2026", "counts", "count",
    measurement_decomposition_test_concept,
    3L, "constraint", "matched", "", NA_integer_,
    "https://w3id.org/smn/SpawnerStageContext", "Spawner stage context", "",
    "SMN", "2026-07-31", "https://w3id.org/smn/",
    "Reviewed against the pinned Salmon Domain Ontology source.",
    "demo-salmon-2026", "counts", "count",
    measurement_decomposition_test_concept,
    4L, "constraint", "gap", "", NA_integer_, "", "Female sex constraint",
    "No compatible governed female-sex term was found in the pinned source.",
    "SMN", "2026-07-31", "https://w3id.org/smn/",
    "Manual bounded search of the pinned Salmon Domain Ontology source.",
    "demo-salmon-2026", "counts", "count",
    measurement_decomposition_test_concept,
    5L, "method", "gap", "", NA_integer_, "", "Enumeration method",
    "The source data do not identify one stable governed method term.",
    "SMN", "2026-07-31", "https://w3id.org/smn/",
    "Source documentation and the pinned ontology were reviewed manually.",
    "demo-salmon-2026", "counts", "count",
    measurement_decomposition_test_concept,
    6L, "unit", "matched", "", NA_integer_,
    "http://qudt.org/vocab/unit/COUNT", "Count", "",
    "QUDT", "3.1.1", "https://qudt.org/3.1.1/vocab/unit/",
    "Reviewed against the pinned QUDT vocabulary release."
  )
}

measurement_decomposition_dimension_rows <- function() {
  dimension_iri <-
    "https://w3id.org/gcdfo/salmon#FreshwaterAgeDimension"
  value_iri <- "https://w3id.org/gcdfo/salmon#Age1YearClass"
  rows <- measurement_decomposition_test_rows()
  rows$component_iri[[3]] <- dimension_iri
  rows$component_label[[3]] <- "Freshwater age dimension"
  rows$source[[3]] <- "GCDFO"
  rows$source_url[[3]] <- "https://w3id.org/gcdfo/salmon"
  rows$component_status[[4]] <- "matched"
  rows$component_relation[[4]] <- "value_of_dimension"
  rows$related_component_order[[4]] <- 3L
  rows$component_iri[[4]] <- value_iri
  rows$component_label[[4]] <- "Freshwater age-1 class"
  rows$rationale[[4]] <- ""
  rows$source[[4]] <- "GCDFO"
  rows$source_url[[4]] <- "https://w3id.org/gcdfo/salmon"
  rows$provenance[[4]] <-
    "Reviewed against the pinned Salmon Domain Ontology source."
  rows
}

make_measurement_dimension_test_sdp <- function(path) {
  make_measurement_decomposition_test_sdp(path)
  dictionary_path <- file.path(path, "metadata", "column_dictionary.csv")
  dictionary <- readr::read_csv(
    dictionary_path,
    show_col_types = FALSE,
    progress = FALSE
  )
  measurement_row <-
    dictionary$table_id == "counts" & dictionary$column_name == "count"
  dictionary$constraint_iri[measurement_row] <- paste(
    "https://w3id.org/gcdfo/salmon#FreshwaterAgeDimension",
    "https://w3id.org/gcdfo/salmon#Age1YearClass",
    sep = ";"
  )
  readr::write_csv(dictionary, dictionary_path, na = "")
  invisible(path)
}

measurement_decomposition_test_csv_path <- function(root) {
  file.path(
    root,
    "metadata",
    "semantic",
    "measurement-decompositions.csv"
  )
}

measurement_decomposition_test_manifest_path <- function(root) {
  file.path(
    root,
    "metadata",
    "semantic",
    "measurement-decompositions.json"
  )
}

measurement_decomposition_test_read_raw <- function(path) {
  readBin(path, "raw", file.info(path)$size)
}

measurement_decomposition_test_write_manifest <- function(manifest, path) {
  json <- jsonlite::toJSON(
    manifest,
    auto_unbox = TRUE,
    pretty = TRUE,
    null = "null"
  )
  writeBin(charToRaw(enc2utf8(paste0(json, "\n"))), path)
  invisible(path)
}

measurement_decomposition_test_rehash <- function(root) {
  csv_path <- measurement_decomposition_test_csv_path(root)
  manifest_path <- measurement_decomposition_test_manifest_path(root)
  manifest <- jsonlite::read_json(manifest_path, simplifyVector = FALSE)
  manifest$artifact$sha256 <- digest::digest(
    file = csv_path,
    algo = "sha256",
    serialize = FALSE
  )
  measurement_decomposition_test_write_manifest(manifest, manifest_path)
  invisible(manifest_path)
}

test_that("measurement decomposition artifacts round-trip deterministically", {
  first_root <- withr::local_tempdir()
  second_root <- withr::local_tempdir()
  make_measurement_decomposition_test_sdp(first_root)
  make_measurement_decomposition_test_sdp(second_root)
  rows <- measurement_decomposition_test_rows()

  first_manifest <- write_sdp_measurement_decompositions(
    first_root,
    rows[sample(seq_len(nrow(rows))), ]
  )
  second_manifest <- write_sdp_measurement_decompositions(second_root, rows)

  first_csv <- file.path(
    first_root,
    "metadata",
    "semantic",
    "measurement-decompositions.csv"
  )
  second_csv <- file.path(
    second_root,
    "metadata",
    "semantic",
    "measurement-decompositions.csv"
  )
  expect_identical(
    basename(first_manifest),
    "measurement-decompositions.json"
  )
  expect_identical(readBin(first_csv, "raw", file.info(first_csv)$size),
                   readBin(second_csv, "raw", file.info(second_csv)$size))
  expect_identical(
    readBin(first_manifest, "raw", file.info(first_manifest)$size),
    readBin(second_manifest, "raw", file.info(second_manifest)$size)
  )

  result <- read_sdp_measurement_decompositions(first_root)
  expect_s3_class(result, "tbl_df")
  expect_identical(names(result), measurement_decomposition_test_columns)
  expect_identical(result$component_order, seq_len(nrow(rows)))
  expect_identical(
    result$component_label[[4]],
    "Female sex constraint"
  )
  expect_true(isTRUE(validate_sdp_measurement_decompositions(first_root)))

  manifest <- attr(result, "manifest", exact = TRUE)
  expect_identical(manifest$schema_version, "1.0")
  expect_identical(
    manifest$artifact$path,
    "metadata/semantic/measurement-decompositions.csv"
  )
  expect_identical(manifest$artifact$row_count, 6L)
  expect_match(manifest$artifact$sha256, "^[0-9a-f]{64}$")
  expect_identical(
    manifest$provenance$generated_by,
    "metasalmon::write_sdp_measurement_decompositions"
  )
  expect_match(
    manifest$provenance$semantic_profile,
    "I-ADOPT-informed.*not native I-ADOPT conformance"
  )
})

test_that("NULL decompositions are an explicit no-op", {
  root <- withr::local_tempdir()
  make_measurement_decomposition_test_sdp(root)

  result <- write_sdp_measurement_decompositions(root, NULL)

  expect_null(result)
  expect_false(file.exists(file.path(
    root,
    "metadata",
    "semantic",
    "measurement-decompositions.csv"
  )))
  expect_false(file.exists(file.path(
    root,
    "metadata",
    "semantic",
    "measurement-decompositions.json"
  )))
})

test_that("matched and gap rows obey the closed component-state contract", {
  cases <- list(
    list(
      mutate = function(rows) {
        rows$component_status[[1]] <- "review"
        rows
      },
      message = "component_status.*matched.*gap"
    ),
    list(
      mutate = function(rows) {
        rows$component_role[[1]] <- "variable"
        rows
      },
      message = "component_role.*property.*entity.*constraint.*method.*unit"
    ),
    list(
      mutate = function(rows) {
        rows$component_iri[[1]] <- "qudt:Count"
        rows
      },
      message = "matched.*absolute.*IRI"
    ),
    list(
      mutate = function(rows) {
        rows$component_iri[[4]] <- "https://example.org/Female"
        rows
      },
      message = "gap.*blank.*component_iri"
    ),
    list(
      mutate = function(rows) {
        rows$component_label[[4]] <- ""
        rows
      },
      message = "gap.*component_label"
    ),
    list(
      mutate = function(rows) {
        rows$rationale[[4]] <- ""
        rows
      },
      message = "gap.*rationale"
    ),
    list(
      mutate = function(rows) {
        rows$source[[1]] <- ""
        rows
      },
      message = "source.*non-empty"
    ),
    list(
      mutate = function(rows) {
        rows$source_version[[1]] <- ""
        rows
      },
      message = "source_version.*non-empty"
    ),
    list(
      mutate = function(rows) {
        rows$source_url[[1]] <- "qudt.example/vocab"
        rows
      },
      message = "source_url.*absolute.*IRI"
    ),
    list(
      mutate = function(rows) {
        rows$provenance[[1]] <- ""
        rows
      },
      message = "provenance.*non-empty"
    )
  )

  for (case in cases) {
    root <- withr::local_tempdir()
    make_measurement_decomposition_test_sdp(root)
    expect_error(
      write_sdp_measurement_decompositions(
        root,
        case$mutate(measurement_decomposition_test_rows())
      ),
      case$message
    )
  }
})

test_that("component order is contiguous and semantic components are unique", {
  duplicate_order <- measurement_decomposition_test_rows()
  duplicate_order$component_order[[6]] <- 5L
  duplicate_root <- withr::local_tempdir()
  make_measurement_decomposition_test_sdp(duplicate_root)
  expect_error(
    write_sdp_measurement_decompositions(duplicate_root, duplicate_order),
    "component_order.*unique|duplicate.*component_order"
  )

  skipped_order <- measurement_decomposition_test_rows()
  skipped_order$component_order[[6]] <- 7L
  skipped_root <- withr::local_tempdir()
  make_measurement_decomposition_test_sdp(skipped_root)
  expect_error(
    write_sdp_measurement_decompositions(skipped_root, skipped_order),
    "component_order.*contiguous|contiguous.*component_order"
  )

  duplicate_component <- dplyr::bind_rows(
    measurement_decomposition_test_rows(),
    dplyr::mutate(
      measurement_decomposition_test_rows()[1, ],
      component_order = 7L
    )
  )
  component_root <- withr::local_tempdir()
  make_measurement_decomposition_test_sdp(component_root)
  expect_error(
    write_sdp_measurement_decompositions(component_root, duplicate_component),
    "[Dd]uplicate semantic component|semantic components.*unique"
  )
})

test_that("decompositions are closed over the exact SDP dictionary binding", {
  missing_root <- withr::local_tempdir()
  make_measurement_decomposition_test_sdp(missing_root)
  missing <- measurement_decomposition_test_rows()
  missing$column_name <- "not_a_column"
  expect_error(
    write_sdp_measurement_decompositions(missing_root, missing),
    "bound measurement.*does not exist.*dictionary|not found.*dictionary"
  )

  concept_root <- withr::local_tempdir()
  make_measurement_decomposition_test_sdp(concept_root)
  wrong_concept <- measurement_decomposition_test_rows()
  wrong_concept$measurement_concept_iri <-
    "https://w3id.org/psc/vocab/PSC-CV-000036"
  expect_error(
    write_sdp_measurement_decompositions(concept_root, wrong_concept),
    "measurement_concept_iri.*term_iri"
  )

  property_root <- withr::local_tempdir()
  make_measurement_decomposition_test_sdp(property_root)
  wrong_property <- measurement_decomposition_test_rows()
  wrong_property$component_iri[[1]] <-
    "https://example.org/quantity-kind/EstimatedCount"
  expect_error(
    write_sdp_measurement_decompositions(property_root, wrong_property),
    "property_iri.*matched property|matched property.*property_iri"
  )

  role_root <- withr::local_tempdir()
  make_measurement_decomposition_test_sdp(role_root)
  dictionary_path <- file.path(
    role_root,
    "metadata",
    "column_dictionary.csv"
  )
  dictionary <- readr::read_csv(
    dictionary_path,
    show_col_types = FALSE,
    progress = FALSE
  )
  measurement_row <-
    dictionary$table_id == "counts" & dictionary$column_name == "count"
  dictionary$column_role[measurement_row] <- "attribute"
  readr::write_csv(dictionary, dictionary_path, na = "")
  expect_error(
    write_sdp_measurement_decompositions(
      role_root,
      measurement_decomposition_test_rows()
    ),
    "bound.*column_role.*measurement|not a measurement"
  )
})

test_that("semicolon dictionary constraints expand to ordered matched rows", {
  root <- withr::local_tempdir()
  make_measurement_decomposition_test_sdp(root)
  dictionary_path <- file.path(root, "metadata", "column_dictionary.csv")
  dictionary <- readr::read_csv(
    dictionary_path,
    show_col_types = FALSE,
    progress = FALSE
  )
  measurement_row <-
    dictionary$table_id == "counts" & dictionary$column_name == "count"
  age_constraint <- "https://w3id.org/gcdfo/salmon#Age1YearClass"
  dictionary$constraint_iri[measurement_row] <- paste(
    "https://w3id.org/smn/SpawnerStageContext",
    age_constraint,
    sep = "; "
  )
  readr::write_csv(dictionary, dictionary_path, na = "")

  rows <- measurement_decomposition_test_rows()
  rows$component_order[rows$component_order >= 4L] <-
    rows$component_order[rows$component_order >= 4L] + 1L
  age_row <- rows[3, ]
  age_row$component_order <- 4L
  age_row$component_iri <- age_constraint
  age_row$component_label <- "Freshwater age-1 class"
  age_row$source <- "GCDFO"
  age_row$source_version <- "2026-07-31"
  age_row$source_url <- "https://w3id.org/gcdfo/salmon"
  age_row$provenance <-
    "Reviewed against the pinned Salmon Domain Ontology source."
  rows <- dplyr::bind_rows(rows, age_row)

  manifest <- write_sdp_measurement_decompositions(root, rows)
  result <- read_sdp_measurement_decompositions(root)

  expect_true(file.exists(manifest))
  expect_identical(
    result$component_iri[result$component_role == "constraint"],
    c(
      "https://w3id.org/smn/SpawnerStageContext",
      age_constraint,
      ""
    )
  )
})

test_that("dimension-value relations target an earlier matched constraint", {
  root <- withr::local_tempdir()
  make_measurement_dimension_test_sdp(root)
  rows <- measurement_decomposition_dimension_rows()

  write_sdp_measurement_decompositions(root, rows)
  result <- read_sdp_measurement_decompositions(root)

  expect_identical(result$component_relation[[4]], "value_of_dimension")
  expect_identical(result$related_component_order[[4]], 3L)
  expect_true(all(is.na(result$related_component_order[-4])))

  cases <- list(
    list(
      mutate = function(value) {
        value$related_component_order[[4]] <- NA_integer_
        value
      },
      message = "component_relation.*related_component_order|blank together"
    ),
    list(
      mutate = function(value) {
        value$component_relation[[4]] <- ""
        value
      },
      message = "related_component_order.*component_relation|blank together"
    ),
    list(
      mutate = function(value) {
        value$component_relation[[4]] <- "part_of"
        value
      },
      message = "component_relation.*value_of_dimension"
    ),
    list(
      mutate = function(value) {
        value$related_component_order[[4]] <- 4L
        value
      },
      message = "earlier.*same measurement|must target an earlier"
    ),
    list(
      mutate = function(value) {
        value$related_component_order[[4]] <- 2L
        value
      },
      message = "matched constraint"
    )
  )

  for (case in cases) {
    invalid_root <- withr::local_tempdir()
    make_measurement_dimension_test_sdp(invalid_root)
    expect_error(
      write_sdp_measurement_decompositions(
        invalid_root,
        case$mutate(measurement_decomposition_dimension_rows())
      ),
      case$message
    )
  }
})

test_that("decomposition CSV bytes are UTF-8 with LF and no BOM", {
  valid_root <- withr::local_tempdir()
  make_measurement_decomposition_test_sdp(valid_root)
  rows <- measurement_decomposition_test_rows()
  rows$component_label[[4]] <- "Female / post-spawn, age-1 (review) — é"
  write_sdp_measurement_decompositions(valid_root, rows)
  valid_path <- measurement_decomposition_test_csv_path(valid_root)
  valid_bytes <- measurement_decomposition_test_read_raw(valid_path)
  valid_text <- rawToChar(valid_bytes)

  expect_false(identical(
    valid_bytes[seq_len(min(3L, length(valid_bytes)))],
    as.raw(c(0xef, 0xbb, 0xbf))
  ))
  expect_false(any(valid_bytes == as.raw(0x0d)))
  expect_identical(tail(valid_bytes, 1L), as.raw(0x0a))
  expect_true(validUTF8(valid_text))
  expect_identical(
    read_sdp_measurement_decompositions(valid_root)$component_label[[4]],
    "Female / post-spawn, age-1 (review) — é"
  )

  cases <- list(
    list(
      mutate = function(bytes) {
        c(as.raw(c(0xef, 0xbb, 0xbf)), bytes)
      },
      message = "BOM"
    ),
    list(
      mutate = function(bytes) {
        charToRaw(gsub("\n", "\r\n", rawToChar(bytes), fixed = TRUE))
      },
      message = "LF|carriage"
    ),
    list(
      mutate = function(bytes) {
        bytes[[match(as.raw(0xc3), bytes)]] <- as.raw(0xff)
        bytes
      },
      message = "UTF-8"
    ),
    list(
      mutate = function(bytes) {
        bytes[-length(bytes)]
      },
      message = "final LF|newline"
    )
  )

  for (case in cases) {
    root <- withr::local_tempdir()
    make_measurement_decomposition_test_sdp(root)
    write_sdp_measurement_decompositions(root, rows)
    csv_path <- measurement_decomposition_test_csv_path(root)
    bytes <- measurement_decomposition_test_read_raw(csv_path)
    writeBin(case$mutate(bytes), csv_path)
    measurement_decomposition_test_rehash(root)

    expect_error(
      validate_sdp_measurement_decompositions(root),
      case$message
    )
  }
})

test_that("the decomposition manifest is a closed exact-byte contract", {
  hash_root <- withr::local_tempdir()
  make_measurement_decomposition_test_sdp(hash_root)
  write_sdp_measurement_decompositions(
    hash_root,
    measurement_decomposition_test_rows()
  )
  csv_path <- measurement_decomposition_test_csv_path(hash_root)
  csv_text <- rawToChar(measurement_decomposition_test_read_raw(csv_path))
  writeBin(
    charToRaw(sub("Female sex", "Female SEX", csv_text, fixed = TRUE)),
    csv_path
  )
  expect_error(
    validate_sdp_measurement_decompositions(hash_root),
    "SHA-256"
  )

  cases <- list(
    list(
      mutate = function(manifest) {
        manifest$artifact$path <- "../measurement-decompositions.csv"
        manifest
      },
      message = "path|unsafe|artifact binding"
    ),
    list(
      mutate = function(manifest) {
        manifest$artifact$row_count <- "6"
        manifest
      },
      message = "row_count.*whole number|row count.*integer"
    ),
    list(
      mutate = function(manifest) {
        manifest$schema_version <- "9.9"
        manifest
      },
      message = "schema version"
    ),
    list(
      mutate = function(manifest) {
        manifest$provenance$generated_by <- "another-writer"
        manifest
      },
      message = "writer provenance"
    ),
    list(
      mutate = function(manifest) {
        manifest$provenance$metasalmon_version <- ""
        manifest
      },
      message = "writer provenance"
    )
  )

  for (case in cases) {
    root <- withr::local_tempdir()
    make_measurement_decomposition_test_sdp(root)
    write_sdp_measurement_decompositions(
      root,
      measurement_decomposition_test_rows()
    )
    manifest_path <- measurement_decomposition_test_manifest_path(root)
    manifest <- jsonlite::read_json(manifest_path, simplifyVector = FALSE)
    measurement_decomposition_test_write_manifest(
      case$mutate(manifest),
      manifest_path
    )

    expect_error(
      validate_sdp_measurement_decompositions(root),
      case$message
    )
  }
})

test_that("overwrite is explicit and cannot escape through a semantic symlink", {
  root <- withr::local_tempdir()
  make_measurement_decomposition_test_sdp(root)
  rows <- measurement_decomposition_test_rows()
  write_sdp_measurement_decompositions(root, rows)

  expect_error(
    write_sdp_measurement_decompositions(root, rows),
    "already exists.*overwrite"
  )
  rows$component_label[[4]] <- "Female constraint requiring review"
  write_sdp_measurement_decompositions(root, rows, overwrite = TRUE)
  expect_identical(
    read_sdp_measurement_decompositions(root)$component_label[[4]],
    "Female constraint requiring review"
  )

  skip_on_os("windows")
  linked_root <- withr::local_tempdir()
  outside <- withr::local_tempdir()
  make_measurement_decomposition_test_sdp(linked_root)
  semantic_path <- file.path(linked_root, "metadata", "semantic")
  expect_true(file.symlink(outside, semantic_path))

  expect_error(
    write_sdp_measurement_decompositions(
      linked_root,
      measurement_decomposition_test_rows()
    ),
    "symlink|outside.*SDP|unsafe"
  )
  expect_false(file.exists(file.path(
    outside,
    "measurement-decompositions.csv"
  )))

  source_root <- withr::local_tempdir()
  read_root <- withr::local_tempdir()
  make_measurement_decomposition_test_sdp(source_root)
  make_measurement_decomposition_test_sdp(read_root)
  write_sdp_measurement_decompositions(
    source_root,
    measurement_decomposition_test_rows()
  )
  expect_true(file.symlink(
    file.path(source_root, "metadata", "semantic"),
    file.path(read_root, "metadata", "semantic")
  ))
  expect_error(
    validate_sdp_measurement_decompositions(read_root),
    "symlink|outside.*SDP|unsafe"
  )
})
