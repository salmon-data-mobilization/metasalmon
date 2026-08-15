# migrate_sdp_methods(): sdp-0.2.0 -> sdp-0.3.0 method relocation ------------
#
# sdp-0.3.0 removed the metadata/methods.csv registry, the registry APIs
# (write_sdp_methods / read_sdp_methods / validate_sdp_methods), and the
# column-dictionary method_iri field. The migration tool is the only surviving
# methods API. Fixtures are made with the current writers and then hand-edited
# back into the legacy sdp-0.2.0 shape the migration accepts as input.

read_file_bytes <- function(path) {
  readBin(path, "raw", n = file.info(path)$size)
}

migration_metadata_paths <- function(root) {
  c(
    tables = file.path(root, "metadata", "tables.csv"),
    dictionary = file.path(root, "metadata", "column_dictionary.csv"),
    dataset = file.path(root, "metadata", "dataset.csv"),
    descriptor = file.path(root, "datapackage.json"),
    registry = file.path(root, "metadata", "methods.csv")
  )
}

legacy_registry_rows <- function() {
  tibble::tibble(
    dataset_id = "methods-test",
    method_iri = "https://ex.org/m/mark-recapture",
    method_label = "Mark-recapture estimate",
    method_description = "Estimates abundance from marked and recaptured fish.",
    method_version = "2026",
    protocol_iri = "https://ex.org/protocols/mark-recapture",
    citation = "Example Program. 2026."
  )
}

make_migration_test_sdp <- function(path) {
  # A real, current package with two measurement columns in one table, so
  # per-table method agreement and disagreement are both expressible.
  resources <- list(
    stock_recruit = tibble::tibble(
      stock_id = c("fraser", "fraser"),
      brood_year = c(2019L, 2020L),
      abundance = c(100, 120),
      density = c(0.5, 0.6)
    )
  )
  suppressMessages(create_sdp(
    resources,
    path = path,
    dataset_id = "methods-test",
    seed_semantics = FALSE,
    seed_verbose = FALSE,
    check_updates = FALSE,
    overwrite = TRUE
  ))
  invisible(path)
}

# Hand-add the legacy dictionary method_iri column: `bindings` is a named
# character vector of column_name -> method IRI; unbound columns stay blank.
add_legacy_dictionary_methods <- function(root, bindings) {
  dictionary_path <- file.path(root, "metadata", "column_dictionary.csv")
  dictionary <- readr::read_csv(
    dictionary_path,
    col_types = readr::cols(.default = readr::col_character()),
    na = "",
    show_col_types = FALSE
  )
  dictionary$method_iri <- unname(bindings[dictionary$column_name])
  readr::write_csv(dictionary, dictionary_path, na = "")
  invisible(dictionary_path)
}

add_legacy_registry <- function(root, rows = legacy_registry_rows()) {
  registry_path <- file.path(root, "metadata", "methods.csv")
  readr::write_csv(rows, registry_path, na = "")
  invisible(registry_path)
}

# Rewind the descriptor to its sdp-0.2.0 shape: a declared registry resource,
# the metadata pointer, the v0.2 identity, and optionally per-field custom
# `iAdopt:methodIri` bindings (`field_methods` is column_name -> method IRI).
add_legacy_descriptor_state <- function(root, field_methods = NULL) {
  descriptor_path <- file.path(root, "datapackage.json")
  descriptor <- jsonlite::read_json(descriptor_path, simplifyVector = FALSE)
  descriptor$profile <- paste0(
    "https://salmon-data-mobilization.github.io/smn-data-pkg/",
    "profiles/salmon-data-package/v0.2/profile.json"
  )
  descriptor$sdp$specVersion <- "sdp-0.2.0"
  descriptor$resources[[length(descriptor$resources) + 1L]] <- list(
    name = "sdp_methods",
    path = "metadata/methods.csv",
    profile = "tabular-data-resource",
    schema = paste0(
      "https://salmon-data-mobilization.github.io/smn-data-pkg/",
      "schema/frictionless/metadata/methods.schema.json"
    )
  )
  descriptor$sdp$metadata$methods <- "metadata/methods.csv"
  if (!is.null(field_methods)) {
    descriptor$resources <- lapply(descriptor$resources, function(resource) {
      if (!is.list(resource$schema)) {
        return(resource)
      }
      fields <- resource$schema$fields
      if (is.null(fields)) {
        return(resource)
      }
      resource$schema$fields <- lapply(fields, function(field) {
        name <- field$name
        if (!is.null(name) && name %in% names(field_methods)) {
          field$custom <- c(
            field$custom,
            list("iAdopt:methodIri" = unname(field_methods[[name]]))
          )
        }
        field
      })
      resource
    })
  }
  writeBin(
    metasalmon:::.ms_sdp_extension_json_bytes(descriptor),
    descriptor_path
  )
  invisible(descriptor_path)
}

set_dataset_spec_version <- function(root, version) {
  dataset_path <- file.path(root, "metadata", "dataset.csv")
  dataset <- readr::read_csv(
    dataset_path,
    col_types = readr::cols(.default = readr::col_character()),
    na = "",
    show_col_types = FALSE
  )
  dataset$spec_version <- version
  readr::write_csv(dataset, dataset_path, na = "")
  invisible(dataset_path)
}

test_that("an agreeing legacy package migrates end-to-end", {
  root <- withr::local_tempdir()
  make_migration_test_sdp(root)
  set_dataset_spec_version(root, "sdp-0.2.0")
  add_legacy_dictionary_methods(root, c(
    abundance = "https://ex.org/m/mark-recapture",
    density = "https://ex.org/m/mark-recapture"
  ))
  add_legacy_registry(root)
  add_legacy_descriptor_state(root)

  report <- suppressMessages(migrate_sdp_methods(root))

  expect_named(report, c("tables", "dropped_review", "registry"))
  expect_equal(report$tables$table_id, "stock_recruit")
  expect_equal(report$tables$method_iri, "https://ex.org/m/mark-recapture")
  expect_equal(nrow(report$dropped_review), 0L)
  expect_equal(report$registry$method_iri, "https://ex.org/m/mark-recapture")

  # tables.csv carries the relocated table-constant method in v0.3 order.
  tables <- readr::read_csv(
    file.path(root, "metadata", "tables.csv"),
    show_col_types = FALSE
  )
  expect_identical(
    names(tables),
    c(
      "dataset_id", "table_id", "file_name", "table_label", "description",
      "observation_unit", "observation_unit_iri", "primary_key",
      "protocol_iri", "protocol_citation", "method_iri"
    )
  )
  expect_equal(
    tables$method_iri[tables$table_id == "stock_recruit"],
    "https://ex.org/m/mark-recapture"
  )

  # The dictionary lost method_iri and is aligned to the v0.3 order ending in
  # statistical_modifier_iri.
  dictionary <- readr::read_csv(
    file.path(root, "metadata", "column_dictionary.csv"),
    show_col_types = FALSE
  )
  expect_identical(
    names(dictionary),
    c(
      "dataset_id", "table_id", "column_name", "column_label",
      "column_description", "column_role", "value_type", "required",
      "unit_label", "unit_iri", "term_iri", "term_type", "property_iri",
      "entity_iri", "constraint_iri", "statistical_modifier_iri"
    )
  )

  # dataset.csv advances the spec pin.
  dataset <- readr::read_csv(
    file.path(root, "metadata", "dataset.csv"),
    show_col_types = FALSE
  )
  expect_equal(dataset$spec_version, "sdp-0.3.0")

  # The descriptor loses the registry resource and pointer and carries the
  # v0.3 identity.
  descriptor <- jsonlite::read_json(
    file.path(root, "datapackage.json"),
    simplifyVector = FALSE
  )
  resource_names <- vapply(
    descriptor$resources,
    function(resource) if (is.character(resource$name)) resource$name else "",
    character(1)
  )
  expect_false("sdp_methods" %in% resource_names)
  resource_paths <- vapply(
    descriptor$resources,
    function(resource) if (is.character(resource$path)) resource$path else "",
    character(1)
  )
  expect_false("metadata/methods.csv" %in% resource_paths)
  expect_null(descriptor$sdp$metadata$methods)
  expect_identical(
    descriptor$profile,
    paste0(
      "https://salmon-data-mobilization.github.io/smn-data-pkg/",
      "profiles/salmon-data-package/v0.3/profile.json"
    )
  )
  expect_identical(descriptor$sdp$specVersion, "sdp-0.3.0")
  expect_identical(
    descriptor$sdp$rules,
    "https://salmon-data-mobilization.github.io/smn-data-pkg/schema/sdp.rules.yaml"
  )

  # The registry file itself is gone, and the migrated package validates.
  expect_false(file.exists(file.path(root, "metadata", "methods.csv")))
  expect_no_error(
    suppressWarnings(
      suppressMessages(validate_salmon_datapackage(root, require_iris = FALSE))
    )
  )
  # A successful migration leaves no scratch behind. The rollback path
  # deliberately preserves a backup when a restore fails, so the success
  # path needs its own assertion that it does not.
  expect_length(
    list.files(
      file.path(root, "metadata"),
      pattern = "^[.].*(backup|stage)",
      all.files = TRUE
    ),
    0L
  )
})

test_that("method disagreement stops the migration with nothing changed", {
  root <- withr::local_tempdir()
  make_migration_test_sdp(root)
  add_legacy_dictionary_methods(root, c(
    abundance = "https://ex.org/m/a",
    density = "https://ex.org/m/b"
  ))
  add_legacy_registry(root)
  add_legacy_descriptor_state(root)

  paths <- migration_metadata_paths(root)
  before <- lapply(paths, read_file_bytes)

  error <- expect_error(
    migrate_sdp_methods(root),
    "disagree about their table's method"
  )
  # Stop AND report: the abort lists every conflicting IRI.
  expect_match(conditionMessage(error), "https://ex.org/m/a", fixed = TRUE)
  expect_match(conditionMessage(error), "https://ex.org/m/b", fixed = TRUE)

  expect_identical(lapply(paths, read_file_bytes), before)
  expect_true(file.exists(paths[["registry"]]))
})

test_that("an existing tables.csv method claim that disagrees also stops", {
  root <- withr::local_tempdir()
  make_migration_test_sdp(root)
  add_legacy_dictionary_methods(root, c(
    abundance = "https://ex.org/m/a",
    density = "https://ex.org/m/a"
  ))
  add_legacy_registry(root)

  tables_path <- file.path(root, "metadata", "tables.csv")
  tables <- readr::read_csv(
    tables_path,
    col_types = readr::cols(.default = readr::col_character()),
    na = "",
    show_col_types = FALSE
  )
  tables$method_iri <- "https://ex.org/m/already-claimed"
  readr::write_csv(tables, tables_path, na = "")

  paths <- migration_metadata_paths(root)
  before <- lapply(paths, read_file_bytes)

  error <- expect_error(
    migrate_sdp_methods(root),
    "tables.csv already claims"
  )
  expect_match(
    conditionMessage(error),
    "https://ex.org/m/already-claimed",
    fixed = TRUE
  )
  expect_match(conditionMessage(error), "https://ex.org/m/a", fixed = TRUE)

  expect_identical(lapply(paths, read_file_bytes), before)
})

test_that("unresolved REVIEW bindings are dropped and reported, not migrated", {
  root <- withr::local_tempdir()
  make_migration_test_sdp(root)
  add_legacy_dictionary_methods(root, c(
    abundance = "REVIEW: https://ex.org/m/a"
  ))
  add_legacy_registry(root)

  report <- suppressMessages(migrate_sdp_methods(root))

  expect_equal(nrow(report$tables), 0L)
  expect_equal(nrow(report$dropped_review), 1L)
  expect_equal(report$dropped_review$column_name, "abundance")
  expect_equal(report$dropped_review$method_iri, "REVIEW: https://ex.org/m/a")

  # Nothing was placed at the table level, the dictionary slot is gone, and
  # the registry was still removed.
  tables <- readr::read_csv(
    file.path(root, "metadata", "tables.csv"),
    show_col_types = FALSE
  )
  expect_true(all(is.na(tables$method_iri)))
  dictionary <- readr::read_csv(
    file.path(root, "metadata", "column_dictionary.csv"),
    show_col_types = FALSE
  )
  expect_false("method_iri" %in% names(dictionary))
  expect_false(file.exists(file.path(root, "metadata", "methods.csv")))
})

test_that("dry_run reports the migration without touching any file", {
  root <- withr::local_tempdir()
  make_migration_test_sdp(root)
  set_dataset_spec_version(root, "sdp-0.2.0")
  add_legacy_dictionary_methods(root, c(
    abundance = "https://ex.org/m/mark-recapture",
    density = "https://ex.org/m/mark-recapture"
  ))
  add_legacy_registry(root)
  add_legacy_descriptor_state(root)

  paths <- migration_metadata_paths(root)
  before <- lapply(paths, read_file_bytes)

  messages <- testthat::capture_messages(
    report <- migrate_sdp_methods(root, dry_run = TRUE)
  )
  expect_match(
    paste(messages, collapse = "\n"),
    "Dry run: no files were changed.",
    fixed = TRUE
  )

  expect_equal(report$tables$table_id, "stock_recruit")
  expect_equal(report$tables$method_iri, "https://ex.org/m/mark-recapture")
  expect_identical(lapply(paths, read_file_bytes), before)
  expect_true(file.exists(paths[["registry"]]))
})

test_that("descriptor-only iAdopt:methodIri bindings migrate", {
  # A descriptor-first sdp-0.2.0 package bound methods through the per-field
  # custom key with no dictionary method_iri column and no registry.
  root <- withr::local_tempdir()
  make_migration_test_sdp(root)
  add_legacy_descriptor_state(root, field_methods = c(
    abundance = "https://ex.org/m/expanded-count",
    density = "https://ex.org/m/expanded-count"
  ))
  # The descriptor still declared the registry resource; the file itself was
  # never written, which the migration must tolerate.
  expect_false(file.exists(file.path(root, "metadata", "methods.csv")))

  report <- suppressMessages(migrate_sdp_methods(root))

  expect_equal(report$tables$table_id, "stock_recruit")
  expect_equal(report$tables$method_iri, "https://ex.org/m/expanded-count")
  expect_null(report$registry)

  tables <- readr::read_csv(
    file.path(root, "metadata", "tables.csv"),
    show_col_types = FALSE
  )
  expect_equal(
    tables$method_iri[tables$table_id == "stock_recruit"],
    "https://ex.org/m/expanded-count"
  )

  descriptor_text <- readLines(file.path(root, "datapackage.json"))
  expect_false(any(grepl("iAdopt:methodIri", descriptor_text, fixed = TRUE)))
  expect_false(any(grepl("sdp_methods", descriptor_text, fixed = TRUE)))
})

test_that("the migration rejects only a symlinked package root", {
  target <- withr::local_tempdir()
  link_parent <- withr::local_tempdir()
  make_migration_test_sdp(target)
  add_legacy_dictionary_methods(target, c(
    abundance = "https://ex.org/m/mark-recapture",
    density = "https://ex.org/m/mark-recapture"
  ))
  add_legacy_registry(target)
  linked_root <- file.path(link_parent, "linked-sdp")
  if (!file.symlink(target, linked_root)) {
    skip("Filesystem does not permit directory symlink creation")
  }

  expect_error(
    migrate_sdp_methods(linked_root),
    "path.*symlink|unsafe"
  )
  expect_error(
    migrate_sdp_methods(paste0(linked_root, "/")),
    "path.*symlink|unsafe"
  )
  # The refusal happened before any work: the legacy registry is untouched.
  expect_true(file.exists(file.path(target, "metadata", "methods.csv")))

  # On macOS the temporary directory is commonly spelled through the harmless
  # /var -> /private/var system alias. Only the supplied package-root entry,
  # not its ancestors, is part of this trust boundary.
  expect_no_error(suppressMessages(migrate_sdp_methods(target)))
  expect_false(file.exists(file.path(target, "metadata", "methods.csv")))
})

test_that("a package with nothing to migrate is reported as a no-op", {
  root <- withr::local_tempdir()
  make_migration_test_sdp(root)

  paths <- migration_metadata_paths(root)
  paths <- paths[names(paths) != "registry"]
  before <- lapply(paths, read_file_bytes)

  expect_message(
    report <- migrate_sdp_methods(root),
    "Nothing to migrate"
  )
  expect_equal(nrow(report$tables), 0L)
  expect_equal(nrow(report$dropped_review), 0L)
  expect_null(report$registry)
  expect_identical(lapply(paths, read_file_bytes), before)
})

test_that("a package with only REVIEW: bindings still migrates to the v0.3 shape", {
  root <- withr::local_tempdir()
  make_migration_test_sdp(root)
  dictionary_path <- file.path(root, "metadata", "column_dictionary.csv")
  dictionary <- readr::read_csv(
    dictionary_path,
    col_types = readr::cols(.default = readr::col_character()),
    na = "",
    show_col_types = FALSE
  )
  dictionary$method_iri[dictionary$column_role == "measurement"] <-
    "REVIEW: https://example.org/methods/unresolved"
  readr::write_csv(dictionary, dictionary_path, na = "")

  report <- suppressMessages(migrate_sdp_methods(root))

  expect_gt(nrow(report$dropped_review), 0L)
  migrated <- readr::read_csv(
    dictionary_path,
    col_types = readr::cols(.default = readr::col_character()),
    na = "",
    show_col_types = FALSE
  )
  expect_false("method_iri" %in% names(migrated))
  expect_true("statistical_modifier_iri" %in% names(migrated))
})

test_that("migration aborts before any writes when the descriptor cannot be parsed", {
  root <- withr::local_tempdir()
  make_migration_test_sdp(root)
  add_legacy_dictionary_methods(
    root,
    c(abundance = "https://example.org/methods/weir-count")
  )
  add_legacy_registry(root)
  descriptor_path <- file.path(root, "datapackage.json")
  writeLines("{ not json", descriptor_path)
  dictionary_path <- file.path(root, "metadata", "column_dictionary.csv")
  before <- readBin(dictionary_path, "raw", n = file.info(dictionary_path)$size)

  expect_error(
    suppressMessages(migrate_sdp_methods(root)),
    "Could not parse"
  )

  after <- readBin(dictionary_path, "raw", n = file.info(dictionary_path)$size)
  expect_identical(before, after)
  expect_true(file.exists(file.path(root, "metadata", "methods.csv")))
})

test_that("migration aborts before any writes on a symlinked descriptor", {
  root <- withr::local_tempdir()
  make_migration_test_sdp(root)
  add_legacy_dictionary_methods(
    root,
    c(abundance = "https://example.org/methods/weir-count")
  )
  add_legacy_registry(root)
  descriptor_path <- file.path(root, "datapackage.json")
  real_descriptor <- file.path(root, "datapackage-real.json")
  file.rename(descriptor_path, real_descriptor)
  file.symlink(real_descriptor, descriptor_path)

  expect_error(
    suppressMessages(migrate_sdp_methods(root)),
    "symlink"
  )
  expect_true(file.exists(file.path(root, "metadata", "methods.csv")))
})

test_that("a failed metadata rewrite restores the methods registry", {
  # The registry is renamed aside before the atomic write set; a rewrite
  # failure must put it back so the package is left exactly as found.
  root <- withr::local_tempdir()
  make_migration_test_sdp(root)
  add_legacy_dictionary_methods(
    root,
    c(
      abundance = "https://example.org/methods/weir-count",
      density = "https://example.org/methods/weir-count"
    )
  )
  add_legacy_registry(root)
  registry_path <- file.path(root, "metadata", "methods.csv")
  registry_before <- readBin(
    registry_path, "raw", n = file.info(registry_path)$size
  )
  # A symlinked dataset.csv reads fine during the rewrite but makes the
  # atomic writer refuse the replacement, failing the transaction mid-flight.
  dataset_path <- file.path(root, "metadata", "dataset.csv")
  real_dataset <- file.path(root, "metadata", "dataset-real.csv")
  file.rename(dataset_path, real_dataset)
  file.symlink(real_dataset, dataset_path)

  expect_error(suppressMessages(migrate_sdp_methods(root)))

  expect_true(file.exists(registry_path))
  registry_after <- readBin(
    registry_path, "raw", n = file.info(registry_path)$size
  )
  expect_identical(registry_before, registry_after)
})

test_that("dry_run rejects non-logical input instead of migrating", {
  # isTRUE(1) is FALSE, so a truthy non-logical would have taken the
  # destructive branch from a caller who plainly asked for a preview.
  root <- withr::local_tempdir()
  make_migration_test_sdp(root)
  add_legacy_dictionary_methods(
    root,
    c(abundance = "https://example.org/methods/weir-count")
  )
  add_legacy_registry(root)

  expect_error(migrate_sdp_methods(root, dry_run = 1), "must be TRUE or FALSE")
  expect_error(migrate_sdp_methods(root, dry_run = "TRUE"), "must be TRUE or FALSE")
  expect_true(file.exists(file.path(root, "metadata", "methods.csv")))
})

test_that("two carriers disagreeing about one column stop the migration", {
  # The dictionary used to win silently, which erased the descriptor's IRI
  # from the package while the contract promises stop-and-report.
  root <- withr::local_tempdir()
  make_migration_test_sdp(root)
  add_legacy_dictionary_methods(
    root,
    c(abundance = "https://example.org/methods/weir-count")
  )
  add_legacy_descriptor_state(
    root,
    field_methods = c(abundance = "https://example.org/methods/aerial-survey")
  )

  expect_error(
    suppressMessages(migrate_sdp_methods(root)),
    "two carriers disagree"
  )
  dictionary <- readr::read_csv(
    file.path(root, "metadata", "column_dictionary.csv"),
    col_types = readr::cols(.default = readr::col_character()),
    na = "",
    show_col_types = FALSE
  )
  expect_true("method_iri" %in% names(dictionary))
})

test_that("a binding naming an undeclared table stops before any writes", {
  root <- withr::local_tempdir()
  make_migration_test_sdp(root)
  dictionary_path <- file.path(root, "metadata", "column_dictionary.csv")
  dictionary <- readr::read_csv(
    dictionary_path,
    col_types = readr::cols(.default = readr::col_character()),
    na = "",
    show_col_types = FALSE
  )
  dictionary$method_iri <- NA_character_
  dictionary$method_iri[[1]] <- "https://example.org/methods/weir-count"
  dictionary$table_id[[1]] <- "not_a_declared_table"
  readr::write_csv(dictionary, dictionary_path, na = "")
  before <- readBin(dictionary_path, "raw", n = file.info(dictionary_path)$size)

  expect_error(
    suppressMessages(migrate_sdp_methods(root)),
    "does not declare"
  )
  expect_identical(
    before,
    readBin(dictionary_path, "raw", n = file.info(dictionary_path)$size)
  )
})

test_that("the legacy reader refuses a symlinked methods registry", {
  # Kept from the pre-0.3.0 hardening: the migration reads and then deletes
  # this path, so following a symlink would delete through it.
  root <- withr::local_tempdir()
  make_migration_test_sdp(root)
  registry_path <- file.path(root, "metadata", "methods.csv")
  outside <- file.path(withr::local_tempdir(), "outside-methods.csv")
  readr::write_csv(legacy_registry_rows(), outside, na = "")
  file.symlink(outside, registry_path)

  expect_error(
    suppressMessages(migrate_sdp_methods(root)),
    "symlink"
  )
  expect_true(file.exists(outside))
})

test_that("migration rewrites the nested descriptor profile too", {
  # The writer emits the profile URI twice (top level and under `sdp`);
  # updating one leaves a descriptor contradicting itself.
  root <- withr::local_tempdir()
  make_migration_test_sdp(root)
  add_legacy_dictionary_methods(
    root,
    c(
      abundance = "https://example.org/methods/weir-count",
      density = "https://example.org/methods/weir-count"
    )
  )
  add_legacy_registry(root)
  descriptor_path <- file.path(root, "datapackage.json")
  descriptor <- jsonlite::read_json(descriptor_path, simplifyVector = FALSE)
  legacy_profile <- paste0(
    "https://salmon-data-mobilization.github.io/smn-data-pkg/",
    "profiles/salmon-data-package/v0.2/profile.json"
  )
  descriptor$profile <- legacy_profile
  descriptor$sdp$profile <- legacy_profile
  descriptor$sdp$specVersion <- "sdp-0.2.0"
  jsonlite::write_json(
    descriptor, descriptor_path,
    auto_unbox = TRUE, pretty = TRUE, null = "null", na = "null"
  )

  suppressMessages(migrate_sdp_methods(root))

  migrated <- jsonlite::read_json(descriptor_path, simplifyVector = FALSE)
  expect_match(migrated$profile, "v0.3", fixed = TRUE)
  expect_match(migrated$sdp$profile, "v0.3", fixed = TRUE)
  expect_identical(migrated$sdp$specVersion, "sdp-0.3.0")
})

test_that("the placement report is in canonical order regardless of input order", {
  build <- function(order) {
    root <- withr::local_tempdir(.local_envir = parent.frame())
    make_migration_test_sdp(root)
    dictionary_path <- file.path(root, "metadata", "column_dictionary.csv")
    dictionary <- readr::read_csv(
      dictionary_path,
      col_types = readr::cols(.default = readr::col_character()),
      na = "",
      show_col_types = FALSE
    )
    dictionary$method_iri <- NA_character_
    dictionary$method_iri[dictionary$column_name == "abundance"] <-
      "https://example.org/methods/weir-count"
    dictionary$method_iri[dictionary$column_name == "density"] <-
      "https://example.org/methods/weir-count"
    readr::write_csv(dictionary[order, , drop = FALSE], dictionary_path, na = "")
    suppressMessages(migrate_sdp_methods(root, dry_run = TRUE))$tables
  }
  forward <- build(seq_len(4))
  reversed <- build(rev(seq_len(4)))
  expect_identical(forward$table_id, reversed$table_id)
  expect_identical(forward$method_iri, reversed$method_iri)
  expect_identical(forward$columns, reversed$columns)
})

test_that("a backup whose restore fails survives the cleanup that follows", {
  # Regression: the rollback branch used to leave the failed-restore backup
  # on the cleanup list, so the on-exit unlink destroyed the only surviving
  # copy of the original bytes.
  directory <- withr::local_tempdir()
  target <- file.path(directory, "keep.csv")
  writeLines("original", target)

  writes <- list(charToRaw("replacement\n"))
  names(writes) <- target

  # Fail validation so the writer rolls back, and make the restore itself
  # fail by replacing the destination with a directory the rename cannot
  # overwrite.
  expect_error(suppressWarnings(
    metasalmon:::.ms_sdp_extension_atomic_write_set(
      writes,
      validate = function() {
        unlink(target)
        dir.create(target)
        stop("forced validation failure")
      }
    )
  ))

  # The backup is a dot-prefixed sibling in the same directory.
  leftovers <- list.files(
    directory,
    pattern = "^\\.keep[.]csv-backup-",
    all.files = TRUE,
    full.names = TRUE
  )
  expect_length(leftovers, 1L)
  expect_identical(readLines(leftovers[[1]]), "original")
})

test_that("a method bound to only some measurement columns stops the migration", {
  # Promotion claims the method for the WHOLE table, so a measurement column
  # with no resolved binding — including one whose binding was dropped as
  # REVIEW: — is a judgement call, not silent agreement.
  root <- withr::local_tempdir()
  make_migration_test_sdp(root)
  add_legacy_dictionary_methods(
    root,
    c(abundance = "https://example.org/methods/weir-count")
  )
  dictionary_path <- file.path(root, "metadata", "column_dictionary.csv")
  before <- readBin(dictionary_path, "raw", n = file.info(dictionary_path)$size)

  expect_error(
    suppressMessages(migrate_sdp_methods(root)),
    "carries no resolved method binding"
  )
  expect_identical(
    before,
    readBin(dictionary_path, "raw", n = file.info(dictionary_path)$size)
  )

  # The REVIEW-shadow variant: one resolved, one just dropped.
  root2 <- withr::local_tempdir()
  make_migration_test_sdp(root2)
  add_legacy_dictionary_methods(root2, c(
    abundance = "https://example.org/methods/weir-count",
    density = "REVIEW: https://example.org/methods/aerial-survey"
  ))
  expect_error(
    suppressMessages(migrate_sdp_methods(root2)),
    "carries no resolved method binding"
  )
})
