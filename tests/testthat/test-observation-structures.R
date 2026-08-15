test_that("paired observation structures round-trip deterministically", {
  first <- withr::local_tempdir()
  second <- withr::local_tempdir()
  make_structure_test_sdp(first)
  make_structure_test_sdp(second)

  first_paths <- write_sdp_observation_structures(
    first,
    structure_test_rows()[2:1, ],
    component_test_rows()[nrow(component_test_rows()):1, ]
  )
  second_paths <- write_sdp_observation_structures(
    second,
    structure_test_rows(),
    component_test_rows()
  )

  expect_identical(names(first_paths), c("structures", "components"))
  expect_identical(
    lapply(first_paths, function(path) readBin(path, "raw", file.info(path)$size)),
    lapply(second_paths, function(path) readBin(path, "raw", file.info(path)$size))
  )
  expect_identical(
    read_sdp_observation_structures(first),
    read_sdp_observation_structures(second)
  )
  expect_true(isTRUE(validate_sdp_observation_structures(first)))

  descriptor <- jsonlite::read_json(
    file.path(first, "datapackage.json"),
    simplifyVector = FALSE
  )
  expect_identical(
    descriptor$sdp$metadata$observationStructures,
    "metadata/structure/observation_structures.csv"
  )
  expect_identical(
    descriptor$sdp$metadata$observationComponents,
    "metadata/structure/observation_components.csv"
  )
})

test_that("observation structures enforce bindings, order, and required dimensions", {
  root <- withr::local_tempdir()
  make_structure_test_sdp(root)

  duplicate_order <- component_test_rows()
  duplicate_order$component_order[duplicate_order$observation_structure_id ==
    "recruits_by_age"] <- c(1L, 2L, 2L, 4L, 5L, 6L)
  expect_error(
    write_sdp_observation_structures(
      root,
      structure_test_rows(),
      duplicate_order
    ),
    "component_order.*unique"
  )

  dictionary_path <- file.path(root, "metadata", "column_dictionary.csv")
  dictionary <- readr::read_csv(dictionary_path, show_col_types = FALSE)
  dictionary$column_role[dictionary$column_name == "recruits"] <- "attribute"
  readr::write_csv(dictionary, dictionary_path, na = "")
  expect_error(
    write_sdp_observation_structures(
      root,
      structure_test_rows(),
      component_test_rows()
    ),
    "measure component.*measurement"
  )
  dictionary$column_role[dictionary$column_name == "recruits"] <- "measurement"
  readr::write_csv(dictionary, dictionary_path, na = "")

  optional_dimension <- component_test_rows()
  optional_dimension$required_when_observed[
    optional_dimension$observation_structure_id == "recruits_by_age" &
      optional_dimension$column_name == "age"
  ] <- FALSE
  expect_error(
    write_sdp_observation_structures(
      root,
      structure_test_rows(),
      optional_dimension
    ),
    "Measure and dimension.*required_when_observed"
  )

  no_dimensions <- component_test_rows()
  no_dimensions$component_role[
    no_dimensions$observation_structure_id == "total_spawners_by_brood" &
      no_dimensions$component_role == "dimension"
  ] <- "attribute"
  expect_error(
    write_sdp_observation_structures(
      root,
      structure_test_rows(),
      no_dimensions
    ),
    "at least one dimension"
  )

  unknown_column <- component_test_rows()
  unknown_column$column_name[[1]] <- "another_table_column"
  expect_error(
    write_sdp_observation_structures(
      root,
      structure_test_rows(),
      unknown_column
    ),
    "same declared table"
  )

  uncovered_components <- component_test_rows()[
    component_test_rows()$observation_structure_id == "recruits_by_age",
    ,
    drop = FALSE
  ]
  uncovered_structures <- structure_test_rows()[
    structure_test_rows()$observation_structure_id == "recruits_by_age",
    ,
    drop = FALSE
  ]
  expect_error(
    write_sdp_observation_structures(
      root,
      uncovered_structures,
      uncovered_components
    ),
    "every measurement column|not bound as a measure"
  )
})

test_that("table-level static procedures must be absolute shared-vocabulary IRIs", {
  # sdp-0.3.0 replaced the per-package registry with direct shared-vocabulary
  # references: a table-constant procedure in tables.csv$method_iri is
  # validated by IRI shape, not registry membership.
  root <- withr::local_tempdir()
  make_structure_test_sdp(root)
  tables_path <- file.path(root, "metadata", "tables.csv")
  tables <- readr::read_csv(tables_path, show_col_types = FALSE)
  tables$method_iri <- "methods/spawning-ground-survey"
  readr::write_csv(tables, tables_path, na = "")

  expect_error(
    write_sdp_observation_structures(
      root,
      structure_test_rows(),
      component_test_rows()
    ),
    "table-level.*method_iri.*absolute shared-vocabulary IRI"
  )
})

test_that("a leftover sdp-0.2.0 methods registry points at migrate_sdp_methods", {
  root <- withr::local_tempdir()
  make_structure_test_sdp(root)
  write_sdp_observation_structures(
    root,
    structure_test_rows(),
    component_test_rows()
  )
  readr::write_csv(
    tibble::tibble(
      dataset_id = "structure-test",
      method_iri = "https://example.org/methods/spawning-ground-survey",
      method_label = "Spawning-ground survey",
      method_description = "Estimates total spawner abundance.",
      method_version = NA_character_,
      protocol_iri = NA_character_,
      citation = NA_character_
    ),
    file.path(root, "metadata", "methods.csv"),
    na = ""
  )

  expect_error(
    metasalmon:::.ms_validate_optional_sdp_observation_metadata(root),
    "Run.*migrate_sdp_methods"
  )
  expect_error(
    suppressMessages(validate_salmon_datapackage(root, require_iris = FALSE)),
    "Run.*migrate_sdp_methods"
  )
})

test_that("observation structures reject conflicting repeated coarse-grain values", {
  root <- withr::local_tempdir()
  make_structure_test_sdp(root, inconsistent_spawners = TRUE)
  expect_error(
    write_sdp_observation_structures(
      root,
      structure_test_rows(),
      component_test_rows()
    ),
    "dimension grain.*not invariant"
  )
})

test_that("required_when_observed is conditional on a populated measure", {
  root <- withr::local_tempdir()
  make_structure_test_sdp(root)
  data_path <- file.path(root, "data", "stock_recruit.csv")
  data <- readr::read_csv(data_path, show_col_types = FALSE)
  data$age[[1]] <- NA_integer_
  readr::write_csv(data, data_path, na = "")
  expect_error(
    write_sdp_observation_structures(
      root,
      structure_test_rows(),
      component_test_rows()
    ),
    "required observation component is empty.*age"
  )

  data$recruits[[1]] <- NA_real_
  readr::write_csv(data, data_path, na = "")
  expect_no_error(write_sdp_observation_structures(
    root,
    structure_test_rows(),
    component_test_rows()
  ))
})

test_that("row-varying procedures resolve through codes to the shared vocabulary", {
  # sdp-0.3.0: an enumerated sosa:usedProcedure code resolves through
  # codes.csv$term_iri straight to the shared vocabulary, so the check is
  # absolute-IRI shape, not membership in a per-package registry.
  root <- withr::local_tempdir()
  make_structure_test_sdp(root)
  codes_path <- file.path(root, "metadata", "codes.csv")
  codes <- readr::read_csv(codes_path, show_col_types = FALSE)
  codes$term_iri[codes$code_value == "mark_recapture"] <-
    "methods/mark-recapture"
  readr::write_csv(codes, codes_path, na = "")
  expect_error(
    write_sdp_observation_structures(
      root,
      structure_test_rows(),
      component_test_rows()
    ),
    "must resolve to an absolute shared-vocabulary IRI"
  )

  codes$term_iri[codes$code_value == "mark_recapture"] <- NA_character_
  readr::write_csv(codes, codes_path, na = "")
  expect_error(
    write_sdp_observation_structures(
      root,
      structure_test_rows(),
      component_test_rows()
    ),
    "resolve through exactly one.*codes.csv"
  )
})

test_that("all enumerated procedure codes resolve even when currently unobserved", {
  root <- withr::local_tempdir()
  make_structure_test_sdp(root)
  codes_path <- file.path(root, "metadata", "codes.csv")
  codes <- readr::read_csv(codes_path, show_col_types = FALSE)
  codes <- dplyr::bind_rows(
    codes,
    tibble::tibble(
      dataset_id = "structure-test",
      table_id = "stock_recruit",
      column_name = "estimate_method",
      code_value = "unused_method",
      code_label = "Unused method",
      code_description = "Enumerated but absent from current data rows",
      vocabulary_iri = NA_character_,
      # Relative reference: enumerated-but-unobserved codes must still carry
      # an absolute shared-vocabulary IRI under sdp-0.3.0.
      term_iri = "methods/not-a-shared-vocabulary-iri",
      term_type = "owl_named_individual"
    )
  )
  readr::write_csv(codes, codes_path, na = "")
  expect_error(
    write_sdp_observation_structures(
      root,
      structure_test_rows(),
      component_test_rows()
    ),
    "must resolve to an absolute shared-vocabulary IRI"
  )
})

test_that("grain and invariance comparisons honor dictionary value_type", {
  root <- withr::local_tempdir()
  make_structure_test_sdp(root)
  data_path <- file.path(root, "data", "stock_recruit.csv")
  data <- readr::read_csv(data_path, show_col_types = FALSE)
  data$brood_year <- c("02019", "2019", "2020")
  data$total_spawners[[2]] <- 101
  readr::write_csv(data, data_path, na = "")
  expect_error(
    write_sdp_observation_structures(
      root,
      structure_test_rows(),
      component_test_rows()
    ),
    "dimension grain.*not invariant"
  )

  data$total_spawners[[2]] <- 100
  data$age <- c("03", "3", "4")
  readr::write_csv(data, data_path, na = "")
  components <- component_test_rows()
  components <- dplyr::bind_rows(
    components,
    tibble::tibble(
      dataset_id = "structure-test",
      table_id = "stock_recruit",
      observation_structure_id = "total_spawners_by_brood",
      component_order = 4L,
      column_name = "age",
      component_role = "attribute",
      component_relation_iri = NA_character_,
      required_when_observed = TRUE
    )
  )
  expect_no_error(write_sdp_observation_structures(
    root,
    structure_test_rows(),
    components
  ))
  normalized <- extract_sdp_observations(
    root,
    observation_structure_id = "total_spawners_by_brood"
  )[[1]]
  expect_equal(nrow(normalized), 2L)
  expect_equal(normalized$brood_year, c(2019L, 2020L))
  expect_equal(normalized$age, c(3L, 4L))
})

test_that("normalized extraction preserves each declared grain", {
  root <- withr::local_tempdir()
  make_structure_test_sdp(root)
  write_sdp_observation_structures(
    root,
    structure_test_rows(),
    component_test_rows()
  )

  observations <- extract_sdp_observations(root)
  expect_identical(
    names(observations),
    c(
      "stock_recruit::recruits_by_age",
      "stock_recruit::total_spawners_by_brood"
    )
  )
  expect_identical(
    names(observations[["stock_recruit::recruits_by_age"]]),
    c(
      "stock_id", "brood_year", "return_year", "age", "recruits",
      "estimate_method"
    )
  )
  expect_equal(nrow(observations[["stock_recruit::recruits_by_age"]]), 3L)
  expect_identical(
    names(observations[["stock_recruit::total_spawners_by_brood"]]),
    c("stock_id", "brood_year", "total_spawners")
  )
  expect_equal(
    nrow(observations[["stock_recruit::total_spawners_by_brood"]]),
    2L
  )

  selected <- extract_sdp_observations(
    root,
    table_id = "stock_recruit",
    observation_structure_id = "total_spawners_by_brood"
  )
  expect_length(selected, 1L)
  expect_error(
    extract_sdp_observations(root, observation_structure_id = "not_here"),
    "No observation structure matches"
  )
})

test_that("observation-structure files are paired and symlink-safe", {
  root <- withr::local_tempdir()
  make_structure_test_sdp(root)
  write_sdp_observation_structures(
    root,
    structure_test_rows(),
    component_test_rows()
  )
  expect_error(
    write_sdp_observation_structures(
      root,
      structure_test_rows(),
      component_test_rows()
    ),
    "already exists.*overwrite"
  )

  components_path <- file.path(
    root,
    "metadata", "structure", "observation_components.csv"
  )
  unlink(components_path)
  expect_error(
    read_sdp_observation_structures(root),
    "must be present together"
  )

  outside <- tempfile(fileext = ".csv")
  writeLines("outside", outside)
  if (!file.symlink(outside, components_path)) {
    skip("Filesystem does not permit symlink creation")
  }
  expect_error(
    write_sdp_observation_structures(
      root,
      structure_test_rows(),
      component_test_rows(),
      overwrite = TRUE
    ),
    "symlink"
  )
  expect_identical(readLines(outside), "outside")
})

test_that("failed observation-structure writes preserve the whole file set", {
  root <- withr::local_tempdir()
  make_structure_test_sdp(root)
  paths <- write_sdp_observation_structures(
    root,
    structure_test_rows(),
    component_test_rows()
  )
  descriptor_path <- file.path(root, "datapackage.json")
  before_structures <- readBin(
    paths[["structures"]],
    "raw",
    n = file.info(paths[["structures"]])$size
  )
  before_components <- readBin(
    paths[["components"]],
    "raw",
    n = file.info(paths[["components"]])$size
  )

  writeLines("{ malformed descriptor", descriptor_path)
  before_descriptor <- readBin(
    descriptor_path,
    "raw",
    n = file.info(descriptor_path)$size
  )
  changed_structures <- structure_test_rows()
  changed_structures$structure_label[[1]] <- "Changed label"

  expect_error(
    write_sdp_observation_structures(
      root,
      changed_structures,
      component_test_rows(),
      overwrite = TRUE
    ),
    "Could not parse.*datapackage.json"
  )
  expect_identical(
    readBin(
      paths[["structures"]],
      "raw",
      n = file.info(paths[["structures"]])$size
    ),
    before_structures
  )
  expect_identical(
    readBin(
      paths[["components"]],
      "raw",
      n = file.info(paths[["components"]])$size
    ),
    before_components
  )
  expect_identical(
    readBin(descriptor_path, "raw", n = file.info(descriptor_path)$size),
    before_descriptor
  )

  linked <- withr::local_tempdir()
  make_structure_test_sdp(linked)
  linked_paths <- write_sdp_observation_structures(
    linked,
    structure_test_rows(),
    component_test_rows()
  )
  linked_descriptor <- file.path(linked, "datapackage.json")
  descriptor_target <- tempfile(fileext = ".json")
  expect_true(file.copy(linked_descriptor, descriptor_target))
  unlink(linked_descriptor)
  if (!file.symlink(descriptor_target, linked_descriptor)) {
    skip("Filesystem does not permit descriptor symlink creation")
  }
  before_linked <- lapply(linked_paths, function(path) {
    readBin(path, "raw", n = file.info(path)$size)
  })
  before_target <- readBin(
    descriptor_target,
    "raw",
    n = file.info(descriptor_target)$size
  )

  expect_error(
    write_sdp_observation_structures(
      linked,
      changed_structures,
      component_test_rows(),
      overwrite = TRUE
    ),
    "symlinked.*datapackage.json"
  )
  expect_identical(
    lapply(linked_paths, function(path) {
      readBin(path, "raw", n = file.info(path)$size)
    }),
    before_linked
  )
  expect_identical(
    readBin(
      descriptor_target,
      "raw",
      n = file.info(descriptor_target)$size
    ),
    before_target
  )
  expect_true(nzchar(Sys.readlink(linked_descriptor)))
})

test_that("whole-package validation includes optional methods and structures", {
  root <- withr::local_tempdir()
  make_structure_test_sdp(root)
  write_sdp_observation_structures(
    root,
    structure_test_rows(),
    component_test_rows()
  )
  expect_no_error(
    suppressMessages(validate_salmon_datapackage(root, require_iris = FALSE))
  )

  data_path <- file.path(root, "data", "stock_recruit.csv")
  data <- readr::read_csv(data_path, show_col_types = FALSE)
  data$total_spawners[[2]] <- 999
  readr::write_csv(data, data_path, na = "")
  expect_error(
    suppressMessages(validate_salmon_datapackage(root, require_iris = FALSE)),
    "dimension grain.*not invariant"
  )
})
