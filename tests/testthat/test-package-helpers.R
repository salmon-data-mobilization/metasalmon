test_that("write_salmon_datapackage creates valid package", {
  # Create test data
  resources <- list(
    main_table = tibble::tibble(
      species = c("Coho", "Chinook"),
      count = c(100L, 200L)
    )
  )

  dataset_meta <- tibble::tibble(
    dataset_id = "test-1",
    title = "Test Dataset",
    description = "A test dataset for validation",
    creator = "Test Author",
    contact_name = NA_character_,
    contact_email = NA_character_,
    license = "MIT",
    temporal_start = NA_character_,
    temporal_end = NA_character_,
    spatial_extent = NA_character_,
    dataset_type = NA_character_,
    source_citation = NA_character_
  )

  table_meta <- tibble::tibble(
    dataset_id = "test-1",
    table_id = "main_table",
    file_name = "data/main_table.csv",
    table_label = "Main Table",
    description = "Main data table",
    observation_unit = NA_character_,
    observation_unit_iri = NA_character_,
    primary_key = NA_character_
  )

  dict <- infer_dictionary(
    resources$main_table,
    dataset_id = "test-1",
    table_id = "main_table"
  )
  dict <- fill_measurement_components(dict)
  validate_dictionary(dict)

  # Create package in temp directory
  temp_dir <- withr::local_tempdir()
  pkg_path <- write_salmon_datapackage(
    resources,
    dataset_meta,
    table_meta,
    dict,
    path = temp_dir,
    format = "csv",
    overwrite = TRUE
  )

  expect_true(dir.exists(pkg_path))
  expect_true(file.exists(file.path(pkg_path, "metadata", "dataset.csv")))
  expect_true(file.exists(file.path(pkg_path, "metadata", "tables.csv")))
  expect_true(file.exists(file.path(pkg_path, "metadata", "column_dictionary.csv")))
  expect_true(file.exists(file.path(pkg_path, "datapackage.json")))
  expect_true(file.exists(file.path(pkg_path, "data", "main_table.csv")))
  expect_false(file.exists(file.path(pkg_path, "dataset.csv")))
  expect_false(file.exists(file.path(pkg_path, "tables.csv")))
  expect_false(file.exists(file.path(pkg_path, "column_dictionary.csv")))
})

test_that("create_sdp creates valid package", {
  resources <- list(
    catches = tibble::tibble(
      station_id = c("A", "B"),
      species = c("Coho", "Chinook"),
      count = c(10L, 20L),
      sample_date = as.Date(c("2024-01-01", "2024-01-02"))
    ),
    stations = tibble::tibble(
      station_id = c("A", "B"),
      lat = c(50.12, 50.34),
      lon = c(-125.5, -125.6),
      habitat = c("estu", "river")
    )
  )

  temp_dir <- withr::local_tempdir()
  pkg_path <- create_sdp(
    resources,
    path = file.path(temp_dir, "package"),
    dataset_id = "mt-demo",
    seed_semantics = FALSE,
    overwrite = TRUE
  )

  expect_true(dir.exists(pkg_path))
  expect_true(dir.exists(file.path(pkg_path, "metadata")))
  expect_true(dir.exists(file.path(pkg_path, "data")))
  expect_true(file.exists(file.path(pkg_path, "metadata", "dataset.csv")))
  expect_true(file.exists(file.path(pkg_path, "metadata", "tables.csv")))
  expect_true(file.exists(file.path(pkg_path, "metadata", "column_dictionary.csv")))
  expect_true(file.exists(file.path(pkg_path, "metadata", "codes.csv")))
  expect_true(file.exists(file.path(pkg_path, "datapackage.json")))
  expect_false(file.exists(file.path(pkg_path, "metadata", "metadata-edh-hnap.xml")))

  dataset <- readr::read_csv(file.path(pkg_path, "metadata", "dataset.csv"), show_col_types = FALSE)
  tables <- readr::read_csv(file.path(pkg_path, "metadata", "tables.csv"), show_col_types = FALSE)

  expect_equal(dataset$dataset_id[[1]], "mt-demo")
  expect_setequal(tables$table_id, c("catches", "stations"))
  expect_true(all(startsWith(tables$file_name, "data/")))

  seed_dataset_meta <- tibble::tibble(
    dataset_id = "mt-demo2",
    title = "MT Demo 2",
    description = "Two table demo with explicit metadata",
    creator = "Test",
    contact_name = NA_character_,
    contact_email = NA_character_,
    license = "MIT",
    temporal_start = NA_character_,
    temporal_end = NA_character_,
    spatial_extent = NA_character_
  )

  pkg_path_with_edh <- create_sdp(
    resources,
    path = file.path(temp_dir, "package-with-edh"),
    dataset_id = "mt-demo2",
    seed_semantics = FALSE,
    seed_dataset_meta = seed_dataset_meta,
    include_edh_xml = TRUE,
    overwrite = TRUE
  )

  expect_true(file.exists(file.path(pkg_path_with_edh, "metadata", "metadata-edh-hnap.xml")))
})

test_that("create_sdp flags create-time EDH XML as a draft when review markers remain", {
  temp_dir <- withr::local_tempdir()
  df <- data.frame(
    site = c("A", "B", "C"),
    count = c(1L, 2L, 3L),
    stringsAsFactors = FALSE
  )

  pkg_path <- NULL
  warns <- testthat::capture_warnings(
    pkg_path <- create_sdp(
      df,
      path = file.path(temp_dir, "draft-edh"),
      dataset_id = "draft-edh",
      table_id = "obs",
      seed_semantics = FALSE,
      include_edh_xml = TRUE,
      check_updates = FALSE,
      overwrite = TRUE
    )
  )

  # Metadata is review-ready (MISSING placeholders remain), so the create-time XML
  # is a draft and must say so, even though write_edh_xml_from_sdp() would refuse.
  expect_match(warns, "DRAFT EDH", all = FALSE)
  expect_true(file.exists(file.path(pkg_path, "metadata", "metadata-edh-hnap.xml")))
})

test_that("factor-scope code selection keys on dataset_id and does not cross-match datasets", {
  resources <- list(
    survey = data.frame(
      status = c("alive", "dead", "alive", "dead", "alive", "dead"),
      stringsAsFactors = FALSE
    )
  )
  codes <- tibble::tibble(
    dataset_id = c("d1", "d2"),
    table_id = c("survey", "survey"),
    column_name = c("status", "status"),
    code_value = c("alive", "alive"),
    code_label = c("Alive", "Alive"),
    code_description = c("", ""),
    term_iri = c(NA_character_, NA_character_)
  )

  selected <- metasalmon:::.ms_select_semantic_seed_codes(
    codes,
    resources,
    scope = "factor",
    dataset_id = "d1"
  )

  # Only the current dataset's code row is selected; the d2 row sharing the same
  # table_id/column_name is not cross-matched.
  expect_equal(nrow(selected), 1L)
  expect_equal(selected$dataset_id, "d1")
})

test_that("create_sdp falls back to deterministic suggestions when LLM assessment fails", {
  fake_search <- function(query, role, sources) {
    tibble::tibble(
      label = c(paste(role, "best"), paste(role, "alt")),
      iri = c(
        paste0("https://example.org/", role, "/best"),
        paste0("https://example.org/", role, "/alt")
      ),
      source = c("smn", "smn"),
      ontology = c("demo", "demo"),
      role = c(role, role),
      match_type = c("label_partial", "label_partial"),
      definition = c("Best match from retrieved shortlist", "Alternative match from retrieved shortlist"),
      score = c(0.9, 0.5)
    )
  }

  failing_request <- function(messages, config) {
    stop("HTTP 402 Payment Required.")
  }

  temp_dir <- withr::local_tempdir()
  resources <- list(main = tibble::tibble(species = c("Coho", "Chinook"), count = c(1L, 2L)))

  pkg_path <- with_mocked_bindings(
    find_terms = fake_search,
    {
      out <- NULL
      expect_warning(
        out <- create_sdp(
          resources,
          path = file.path(temp_dir, "package-llm-fallback"),
          dataset_id = "llm-fallback-demo",
          seed_semantics = TRUE,
          semantic_sources = "smn",
          semantic_max_per_role = 2,
          seed_verbose = FALSE,
          llm_assess = TRUE,
          llm_provider = "openrouter",
          llm_model = "openai/gpt-5.4-mini",
          llm_api_key = "dummy-key",
          llm_top_n = 2,
          llm_request_fn = failing_request,
          check_updates = FALSE,
          overwrite = TRUE
        ),
        "falling back to deterministic semantic suggestions only"
      )
      out
    }
  )

  expect_true(dir.exists(pkg_path))
  expect_true(file.exists(file.path(pkg_path, "semantic_suggestions.csv")))

  dict <- readr::read_csv(file.path(pkg_path, "metadata", "column_dictionary.csv"), show_col_types = FALSE)
  suggestions <- readr::read_csv(file.path(pkg_path, "semantic_suggestions.csv"), show_col_types = FALSE)
  iri_cols <- grep("_iri$", names(dict), value = TRUE)
  iri_values <- unlist(dict[iri_cols], use.names = FALSE)

  expect_gt(nrow(suggestions), 0)
  expect_false(any(startsWith(names(suggestions), "llm_")))
  expect_true(any(grepl("https://example.org/", iri_values, fixed = TRUE), na.rm = TRUE))
})

test_that("create_sdp rejects parsed data frames passed as llm_context_files", {
  temp_dir <- withr::local_tempdir()
  resources <- list(main = tibble::tibble(species = c("Coho", "Chinook"), count = c(1L, 2L)))
  parsed_context <- tibble::tibble(
    field = c("species", "count"),
    description = c("Species name", "Number of fish")
  )

  expect_error(
    create_sdp(
      resources,
      path = file.path(temp_dir, "package-parsed-context"),
      dataset_id = "parsed-context-demo",
      seed_semantics = FALSE,
      llm_context_files = parsed_context,
      check_updates = FALSE,
      overwrite = TRUE
    ),
    "llm_context_files.*character vector of local file paths"
  )
})

test_that("create_sdp warns when context files are supplied without llm_assess", {
  temp_dir <- withr::local_tempdir()
  context_path <- file.path(temp_dir, "context.csv")
  readr::write_csv(
    tibble::tibble(
      field = c("species", "count"),
      description = c("Species name", "Number of fish")
    ),
    context_path
  )
  resources <- list(main = tibble::tibble(species = c("Coho", "Chinook"), count = c(1L, 2L)))
  fake_search <- function(query, role, sources) {
    tibble::tibble()
  }

  pkg_path <- NULL
  with_mocked_bindings(
    find_terms = fake_search,
    {
      expect_warning(
        pkg_path <- create_sdp(
          resources,
          path = file.path(temp_dir, "package-context-no-llm"),
          dataset_id = "context-no-llm-demo",
          seed_semantics = TRUE,
          seed_verbose = FALSE,
          semantic_sources = "smn",
          llm_context_files = context_path,
          check_updates = FALSE,
          overwrite = TRUE
        ),
        "llm_context_files.*ignored.*llm_assess = TRUE"
      )
    },
    .package = "metasalmon"
  )

  suggestions_path <- file.path(pkg_path, "semantic_suggestions.csv")
  if (file.exists(suggestions_path)) {
    suggestions <- readr::read_csv(suggestions_path, show_col_types = FALSE)
    expect_false(any(startsWith(names(suggestions), "llm_")))
  }

  expect_true(dir.exists(pkg_path))
})

test_that("create_sdp rejects parsed data frames passed as llm_context_files with llm_assess", {
  temp_dir <- withr::local_tempdir()
  resources <- list(main = tibble::tibble(species = c("Coho", "Chinook"), count = c(1L, 2L)))
  parsed_context <- tibble::tibble(
    field = c("species", "count"),
    description = c("Species name", "Number of fish")
  )

  expect_error(
    create_sdp(
      resources,
      path = file.path(temp_dir, "package-parsed-context-llm"),
      dataset_id = "parsed-context-llm-demo",
      seed_semantics = TRUE,
      seed_verbose = FALSE,
      semantic_sources = "smn",
      llm_assess = TRUE,
      llm_provider = "openrouter",
      llm_api_key = "dummy-key",
      llm_context_files = parsed_context,
      check_updates = FALSE,
      overwrite = TRUE
    ),
    "llm_context_files.*character vector of local file paths"
  )
})

test_that("create_sdp auto-enables EDH XML export when legacy edh_profile is supplied", {
  temp_dir <- withr::local_tempdir()
  resources <- list(main = tibble::tibble(species = c("Coho"), count = c(1L)))
  seed_dataset_meta <- tibble::tibble(
    dataset_id = "edh-auto",
    title = "EDH Auto",
    description = "EDH auto-enable test",
    creator = "Test",
    contact_name = NA_character_,
    contact_email = NA_character_,
    license = "MIT",
    temporal_start = NA_character_,
    temporal_end = NA_character_,
    spatial_extent = NA_character_
  )

  expect_warning(
    expect_message(
      pkg_path <- create_sdp(
        resources,
        path = file.path(temp_dir, "package-auto-edh"),
        dataset_id = "edh-auto",
        seed_semantics = FALSE,
        check_updates = FALSE,
        seed_dataset_meta = seed_dataset_meta,
        edh_profile = "dfo_edh_hnap",
        overwrite = TRUE
      ),
      "include_edh_xml = TRUE",
      fixed = TRUE
    ),
    "deprecated"
  )

  expect_true(file.exists(file.path(pkg_path, "metadata", "metadata-edh-hnap.xml")))
})

test_that("create_sdp accepts deprecated EDH_Profile alias", {
  temp_dir <- withr::local_tempdir()
  resources <- list(main = tibble::tibble(species = c("Coho"), count = c(1L)))
  seed_dataset_meta <- tibble::tibble(
    dataset_id = "edh-alias",
    title = "EDH Alias",
    description = "EDH alias test",
    creator = "Test",
    contact_name = NA_character_,
    contact_email = NA_character_,
    license = "MIT",
    temporal_start = NA_character_,
    temporal_end = NA_character_,
    spatial_extent = NA_character_
  )

  expect_warning(
    expect_message(
      pkg_path <- create_sdp(
        resources,
        path = file.path(temp_dir, "package-alias-edh"),
        dataset_id = "edh-alias",
        seed_semantics = FALSE,
        check_updates = FALSE,
        seed_dataset_meta = seed_dataset_meta,
        EDH_Profile = "dfo_edh_hnap",
        overwrite = TRUE
      ),
      "include_edh_xml = TRUE",
      fixed = TRUE
    ),
    "deprecated"
  )

  expect_true(file.exists(file.path(pkg_path, "metadata", "metadata-edh-hnap.xml")))
})

test_that("normalized dictionary column order is preserved when writing package", {
  resources <- list(main = tibble::tibble(species = c("Coho"), count = c(1L)))
  dict <- infer_dictionary(resources$main, dataset_id = "ord-1", table_id = "main")

  dataset_meta <- tibble::tibble(
    dataset_id = "ord-1",
    title = "Order check",
    description = "Order check",
    creator = NA_character_,
    contact_name = NA_character_,
    contact_email = NA_character_,
    license = NA_character_
  )
  table_meta <- tibble::tibble(
    dataset_id = "ord-1",
    table_id = "main",
    file_name = "data/main.csv",
    table_label = "Main",
    description = NA_character_
  )

  pkg_path <- write_salmon_datapackage(
    resources = resources,
    dataset_meta = dataset_meta,
    table_meta = table_meta,
    dict = dict,
    path = withr::local_tempdir(),
    overwrite = TRUE
  )

  written <- readr::read_csv(file.path(pkg_path, "metadata", "column_dictionary.csv"), show_col_types = FALSE)
  expect_equal(
    names(written),
    metasalmon:::.ms_dictionary_cols()
  )
})

test_that("create_sdp defaults path in getwd using dataset_id slug", {
  withr::local_tempdir() -> tmp
  withr::local_dir(tmp)

  df <- tibble::tibble(
    species = c("Coho", "Chinook"),
    count = c(10L, 20L)
  )

  pkg_path <- create_sdp(
    df,
    dataset_id = "Fraser Coho 2024",
    table_id = "escapement",
    seed_semantics = FALSE,
    overwrite = TRUE
  )

  expect_equal(normalizePath(pkg_path), normalizePath(file.path(getwd(), "fraser-coho-2024-sdp")))
  expect_true(file.exists(file.path(pkg_path, "README-review.txt")))
  expect_true(file.exists(file.path(pkg_path, "data", "escapement.csv")))
})

test_that("create_sdp requires overwrite=TRUE to write into an existing directory", {
  withr::local_tempdir() -> tmp
  output_dir <- file.path(tmp, "existing-package")
  dir.create(output_dir)
  # any existing file should still block and avoid running semantic inference
  readr::write_csv(tibble::tibble(a = 1), file.path(output_dir, "already.csv"))

  called <- 0L
  fake_suggest <- function(...) {
    called <<- called + 1L
    stop("should not run")
  }

  with_mocked_bindings(
    suggest_semantics = fake_suggest,
    {
      expect_error(
        create_sdp(
          tibble::tibble(col = 1:2),
          path = output_dir,
          dataset_id = "dup-test",
          table_id = "t1",
          overwrite = FALSE
        ),
        "already exists"
      )
    }
  )

  expect_equal(called, 0L)
})

test_that("create_sdp exposes seed_table_meta and seed_dataset_meta defaults as TRUE", {
  expect_true(identical(formals(create_sdp)$seed_table_meta, TRUE))
  expect_true(identical(formals(infer_salmon_datapackage_artifacts)$seed_table_meta, TRUE))
  expect_true(identical(formals(create_sdp)$seed_dataset_meta, TRUE))
  expect_true(identical(formals(infer_salmon_datapackage_artifacts)$seed_dataset_meta, TRUE))
})

test_that("create_sdp handles NuSEDS-style DD-MON-YY dates in built-in sample", {
  withr::local_tempdir() -> tmp

  sample_path <- system.file("extdata", "nuseds-fraser-coho-sample.csv", package = "metasalmon")
  fraser_coho <- readr::read_csv(sample_path, show_col_types = FALSE)

  pkg_path <- create_sdp(
    fraser_coho,
    path = file.path(tmp, "nuseds-sample"),
    dataset_id = "fraser-coho-2024",
    table_id = "escapement",
    seed_semantics = FALSE,
    overwrite = TRUE
  )

  dataset_written <- readr::read_csv(file.path(pkg_path, "metadata", "dataset.csv"), show_col_types = FALSE)
  expect_equal(as.character(dataset_written$temporal_start[[1]]), "1997-12-03")
  expect_equal(as.character(dataset_written$temporal_end[[1]]), "2024-11-20")
  expect_true(file.exists(file.path(pkg_path, "data", "escapement.csv")))
})

test_that("create_sdp writes review files and auto-applies compatible table suggestions", {
  resources <- list(
    catches = tibble::tibble(
      species = c("Coho", "Chinook"),
      count = c(10L, 20L)
    )
  )
  seed_table_meta <- tibble::tibble(
    dataset_id = "review-demo",
    table_id = "catches",
    file_name = "data/catches.csv",
    table_label = "Catches",
    description = "Catch records for survey events.",
    observation_unit = "Catch record",
    observation_unit_iri = NA_character_,
    primary_key = NA_character_
  )

  fake_suggest <- function(df, dict, sources = c("smn", "gcdfo", "ols", "nvs"),
                           include_dwc = FALSE, max_per_role = 3,
                           search_fn = find_terms, codes = NULL,
                           table_meta = NULL, dataset_meta = NULL) {
    dict$property_iri[dict$column_name == "count"] <- "https://example.org/property-existing"
    attr(dict, "semantic_suggestions") <- tibble::tibble(
      column_name = c("count", "count", "species", NA_character_),
      dictionary_role = c("variable", "property", "entity", "entity"),
      table_id = c("catches", "catches", "catches", "catches"),
      dataset_id = c("review-demo", "review-demo", "review-demo", "review-demo"),
      target_scope = c("column", "column", "code", "table"),
      target_sdp_file = c("column_dictionary.csv", "column_dictionary.csv", "codes.csv", "tables.csv"),
      target_sdp_field = c("term_iri", "property_iri", "term_iri", "observation_unit_iri"),
      target_row_key = c("review-demo/catches/count", "review-demo/catches/count", "review-demo/catches/species/POP1", "review-demo/catches"),
      target_query_basis = c(NA_character_, NA_character_, NA_character_, "observation_unit"),
      target_query_context = c(NA_character_, NA_character_, NA_character_, "Catch record Catches catches"),
      code_value = c(NA_character_, NA_character_, "POP1", NA_character_),
      code_label = c(NA_character_, NA_character_, "POP1", NA_character_),
      code_description = c(NA_character_, NA_character_, NA_character_, NA_character_),
      iri = c("https://example.org/term-top", "https://example.org/property-top", "https://example.org/pop1", "https://example.org/table-unit"),
      label = c("Count term", "Count property", "Population One", "Catch record"),
      source = c("smn", "smn", "smn", "smn"),
      ontology = c("demo", "demo", "demo", "demo"),
      role = c("variable", "property", "entity", "entity"),
      match_type = c("label_exact", "label_exact", "label_exact", "label_exact"),
      definition = c(NA_character_, NA_character_, NA_character_, NA_character_)
    )
    dict
  }

  pkg_path <- NULL
  expect_no_warning(
    expect_message(
      expect_message(
        expect_message(
          with_mocked_bindings(
            suggest_semantics = fake_suggest,
            {
              pkg_path <- create_sdp(
                resources,
                path = file.path(withr::local_tempdir(), "review-package"),
                dataset_id = "review-demo",
                seed_semantics = TRUE,
                seed_table_meta = seed_table_meta,
                overwrite = TRUE
              )
            }
          ),
          regexp = "Review-ready metadata includes draft",
          fixed = TRUE
        ),
        regexp = "Some measurement semantic IRI fields are still blank in this review-ready package.",
        fixed = TRUE
      ),
      regexp = "Prefilled semantic values were written directly into the metadata CSVs",
      fixed = TRUE
    )
  )

  expect_true(file.exists(file.path(pkg_path, "README-review.txt")))
  expect_true(file.exists(file.path(pkg_path, "semantic_suggestions.csv")))

  review_lines <- readLines(file.path(pkg_path, "README-review.txt"), warn = FALSE)
  expect_true(any(grepl("Salmon Data Package Review Checklist", review_lines, fixed = TRUE)))
  expect_true(any(grepl("Review the package in Excel", review_lines, fixed = TRUE)))
  expect_true(any(grepl("[ ] 1. Start in metadata/*.csv", review_lines, fixed = TRUE)))
  expect_true(any(grepl("metadata/column_dictionary.csv and metadata/tables.csv first", review_lines, fixed = TRUE)))
  expect_true(any(grepl("Use semantic_suggestions.csv only as a fallback shortlist", review_lines, fixed = TRUE)))
  expect_true(any(grepl("salmon-domain-ontology/issues/new/choose", review_lines, fixed = TRUE)))
  expect_true(any(grepl("dfo-salmon-ontology/issues/new/choose", review_lines, fixed = TRUE)))
  expect_true(any(grepl("Share the whole package folder", review_lines, fixed = TRUE)))
  expect_true(any(grepl("read_salmon_datapackage(pkg_path)", review_lines, fixed = TRUE)))
  if (file.exists(file.path(pkg_path, "metadata", "codes.csv"))) {
    expect_true(any(grepl("If metadata/codes.csv exists", review_lines, fixed = TRUE)))
  }
  expect_true(any(grepl("already lives there", review_lines, fixed = TRUE)))

  suggestions_written <- readr::read_csv(file.path(pkg_path, "semantic_suggestions.csv"), show_col_types = FALSE)
  expect_setequal(unique(suggestions_written$target_scope), c("column", "table"))

  dict_written <- readr::read_csv(file.path(pkg_path, "metadata", "column_dictionary.csv"), show_col_types = FALSE)
  count_row <- dict_written[dict_written$column_name == "count", , drop = FALSE]
  expect_equal(count_row$term_iri[[1]], paste0(metasalmon:::.ms_review_iri_prefix(), "https://example.org/term-top"))
  expect_equal(count_row$property_iri[[1]], "https://example.org/property-existing")
  expect_true(startsWith(count_row$column_description[[1]], "MISSING DESCRIPTION:"))

  tables_written <- readr::read_csv(file.path(pkg_path, "metadata", "tables.csv"), show_col_types = FALSE)
  expect_true(all(startsWith(tables_written$file_name, "data/")))
  expect_equal(tables_written$description[[1]], "Catch records for survey events.")
  expect_equal(tables_written$observation_unit_iri[[1]], paste0(metasalmon:::.ms_review_iri_prefix(), "https://example.org/table-unit"))
  expect_equal(tables_written$observation_unit[[1]], "Catch record")

  dataset_written <- readr::read_csv(file.path(pkg_path, "metadata", "dataset.csv"), show_col_types = FALSE)
  expect_true(startsWith(dataset_written$creator[[1]], "MISSING METADATA:"))
  expect_true(startsWith(dataset_written$contact_name[[1]], "MISSING METADATA:"))
  expect_true(startsWith(dataset_written$contact_email[[1]], "MISSING METADATA:"))
  expect_true(startsWith(dataset_written$license[[1]], "MISSING METADATA:"))
})

test_that("create_sdp auto-applies strong table-label observation-unit suggestions by default", {
  resources <- list(
    escapement = tibble::tibble(
      species = c("Coho", "Chinook"),
      count = c(10L, 20L)
    )
  )

  fake_suggest <- function(df, dict, sources = c("smn", "gcdfo", "ols", "nvs"),
                           include_dwc = FALSE, max_per_role = 3,
                           search_fn = find_terms, codes = NULL,
                           table_meta = NULL, dataset_meta = NULL) {
    attr(dict, "semantic_suggestions") <- tibble::tibble(
      column_name = NA_character_,
      dictionary_role = "entity",
      table_id = "escapement",
      dataset_id = "review-demo",
      target_scope = "table",
      target_sdp_file = "tables.csv",
      target_sdp_field = "observation_unit_iri",
      target_row_key = "review-demo/escapement",
      target_query_basis = "table_label",
      target_query_context = "Escapement escapement",
      code_value = NA_character_,
      code_label = NA_character_,
      code_description = NA_character_,
      iri = "https://example.org/observation-unit",
      label = "Escapement observation",
      source = "smn",
      ontology = "demo",
      role = "entity",
      match_type = "label_exact",
      definition = NA_character_,
      score = 2
    )
    dict
  }

  pkg_path <- NULL
  with_mocked_bindings(
    suggest_semantics = fake_suggest,
    {
      pkg_path <- create_sdp(
        resources,
        path = file.path(withr::local_tempdir(), "review-package-top-table-unit"),
        dataset_id = "review-demo",
        seed_semantics = TRUE,
        overwrite = TRUE
      )
    }
  )

  tables_written <- readr::read_csv(file.path(pkg_path, "metadata", "tables.csv"), show_col_types = FALSE)
  expect_equal(
    tables_written$observation_unit_iri[[1]],
    paste0(metasalmon:::.ms_review_iri_prefix(), "https://example.org/observation-unit")
  )
  expect_equal(tables_written$observation_unit[[1]], "Escapement observation")
})

test_that("create_sdp leaves weak or bogus table observation-unit suggestions as review only", {
  resources <- list(
    catches = tibble::tibble(
      species = c("Coho", "Chinook"),
      count = c(10L, 20L)
    )
  )

  fake_suggest <- function(df, dict, sources = c("smn", "gcdfo", "ols", "nvs"),
                           include_dwc = FALSE, max_per_role = 3,
                           search_fn = find_terms, codes = NULL,
                           table_meta = NULL, dataset_meta = NULL) {
    attr(dict, "semantic_suggestions") <- tibble::tibble(
      column_name = NA_character_,
      dictionary_role = "entity",
      table_id = "catches",
      dataset_id = "review-demo",
      target_scope = "table",
      target_sdp_file = "tables.csv",
      target_sdp_field = "observation_unit_iri",
      target_row_key = "review-demo/catches",
      target_query_basis = "table_label",
      target_query_context = "Catches catches",
      code_value = NA_character_,
      code_label = NA_character_,
      code_description = NA_character_,
      iri = "https://example.org/bad-table-unit",
      label = "Metadata note",
      source = "smn",
      ontology = "demo",
      role = "entity",
      match_type = "label_exact",
      definition = NA_character_,
      score = 2
    )
    dict
  }

  pkg_path <- NULL
  with_mocked_bindings(
    suggest_semantics = fake_suggest,
    {
      pkg_path <- create_sdp(
        resources,
        path = file.path(withr::local_tempdir(), "review-package-bad-table-unit"),
        dataset_id = "review-demo",
        seed_semantics = TRUE,
        overwrite = TRUE
      )
    }
  )

  tables_written <- readr::read_csv(file.path(pkg_path, "metadata", "tables.csv"), show_col_types = FALSE)
  expect_true(is.na(tables_written$observation_unit_iri[[1]]) || tables_written$observation_unit_iri[[1]] == "")
  expect_true(startsWith(tables_written$observation_unit[[1]], "MISSING METADATA:"))
})

test_that("create_sdp writes selected LLM table suggestions back to tables.csv as review drafts", {
  resources <- list(
    escapement = tibble::tibble(species = c("Coho", "Chinook"), count = c(10L, 20L)),
    age_composition = tibble::tibble(age = c("2", "3"), proportion = c(0.4, 0.6))
  )

  fake_suggest <- function(df, dict, ..., codes = NULL, table_meta = NULL, dataset_meta = NULL) {
    attr(dict, "semantic_suggestions") <- tibble::tibble(
      column_name = NA_character_,
      dictionary_role = "entity",
      table_id = "escapement",
      dataset_id = "review-demo",
      target_scope = "table",
      target_sdp_file = "tables.csv",
      target_sdp_field = "observation_unit_iri",
      target_row_key = "review-demo/escapement",
      target_query_basis = "table_label",
      target_query_context = "Escapement escapement",
      code_value = NA_character_,
      code_label = NA_character_,
      code_description = NA_character_,
      iri = "https://example.org/observation-unit",
      label = "Escapement observation",
      source = "smn",
      ontology = "demo",
      role = "entity",
      match_type = "label_exact",
      definition = NA_character_,
      llm_decision = "select",
      llm_confidence = 0.91,
      llm_selected = TRUE,
      llm_candidate_rank = 1L
    )
    dict
  }

  pkg_path <- NULL
  with_mocked_bindings(
    suggest_semantics = fake_suggest,
    {
      pkg_path <- create_sdp(
        resources,
        path = file.path(withr::local_tempdir(), "review-package-llm-table-unit"),
        dataset_id = "review-demo",
        seed_semantics = TRUE,
        llm_assess = TRUE,
        check_updates = FALSE,
        overwrite = TRUE
      )
    }
  )

  suggestions_written <- readr::read_csv(file.path(pkg_path, "semantic_suggestions.csv"), show_col_types = FALSE)
  expect_equal(suggestions_written$target_query_basis[[1]], "table_label")
  expect_true(isTRUE(suggestions_written$llm_selected[[1]]))

  tables_written <- readr::read_csv(file.path(pkg_path, "metadata", "tables.csv"), show_col_types = FALSE)
  escapement_row <- tables_written[tables_written$table_id == "escapement", , drop = FALSE]
  age_row <- tables_written[tables_written$table_id == "age_composition", , drop = FALSE]

  expect_equal(
    escapement_row$observation_unit_iri[[1]],
    paste0(metasalmon:::.ms_review_iri_prefix(), "https://example.org/observation-unit")
  )
  expect_equal(escapement_row$observation_unit[[1]], "Escapement observation")
  expect_true(is.na(age_row$observation_unit_iri[[1]]) || age_row$observation_unit_iri[[1]] == "")
})

test_that("create_sdp only auto-writes role-compatible LLM suggestions for safer semantic roles", {
  resources <- list(main = tibble::tibble(weight_kg = c(1, 2)))

  fake_suggest <- function(df, dict, ...) {
    suggestions <- tibble::tibble(
      column_name = rep("weight_kg", 6),
      dictionary_role = c("variable", "property", "entity", "unit", "method", "constraint"),
      table_id = rep("main", 6),
      dataset_id = rep("review-demo", 6),
      target_scope = rep("column", 6),
      target_sdp_file = rep("column_dictionary.csv", 6),
      target_sdp_field = c("term_iri", "property_iri", "entity_iri", "unit_iri", "method_iri", "constraint_iri"),
      iri = c(
        "https://example.org/term/weight",
        "https://example.org/property/weight",
        "https://example.org/entity/fish-weight",
        "http://qudt.org/vocab/unit/KiloGM",
        "https://example.org/method/fork-length",
        "https://example.org/constraint/catch-context"
      ),
      label = c(
        "Weight variable",
        "Fish weight",
        "Fish weight",
        "Kilogram",
        "Fork-length field method",
        "Catch context"
      ),
      source = rep("smn", 6),
      ontology = rep("demo", 6),
      role = c("variable", "property", "entity", "unit", "method", "constraint"),
      match_type = rep("label_partial", 6),
      definition = NA_character_,
      search_query = c("weight kg", "fish weight kg", "fish weight kg", "kg", "fish weight method", "fish weight context"),
      target_label = rep("Weight kg", 6),
      target_description = rep("Fish weight in kilograms", 6),
      llm_provider = rep("openrouter", 6),
      llm_model = rep("openai/gpt-5.4-mini", 6),
      llm_decision = c("review", rep("accept", 5)),
      llm_confidence = c(0.89, 0.93, 0.91, 0.95, 0.99, 0.99),
      llm_selected_candidate_index = c(NA_integer_, rep(1L, 5)),
      llm_selected_iri = c(
        NA_character_,
        "https://example.org/property/weight",
        "https://example.org/entity/fish-weight",
        "http://qudt.org/vocab/unit/KiloGM",
        "https://example.org/method/fork-length",
        "https://example.org/constraint/catch-context"
      ),
      llm_selected_label = c(
        NA_character_,
        "Fish weight",
        "Fish weight",
        "Kilogram",
        "Fork-length field method",
        "Catch context"
      ),
      llm_rationale = rep("Selected for test coverage.", 6),
      llm_missing_context = rep(NA_character_, 6),
      llm_context_sources = rep("Data_Dictionary_EN_FR.csv", 6),
      llm_error = rep(NA_character_, 6),
      llm_candidate_rank = rep(1L, 6),
      llm_selected = c(FALSE, rep(TRUE, 5))
    )
    attr(dict, "semantic_suggestions") <- suggestions
    attr(dict, "semantic_llm_assessments") <- suggestions[, c(
      "dataset_id", "table_id", "column_name", "dictionary_role",
      "target_scope", "target_sdp_file", "target_sdp_field", "search_query",
      "llm_provider", "llm_model", "llm_decision", "llm_confidence",
      "llm_selected_candidate_index", "llm_selected_iri", "llm_selected_label",
      "llm_rationale", "llm_missing_context", "llm_context_sources", "llm_error"
    )]
    dict
  }

  pkg_path <- NULL
  with_mocked_bindings(
    suggest_semantics = fake_suggest,
    {
      pkg_path <- create_sdp(
        resources,
        path = file.path(withr::local_tempdir(), "review-package-llm-guardrails"),
        dataset_id = "review-demo",
        table_id = "main",
        seed_semantics = TRUE,
        llm_assess = TRUE,
        check_updates = FALSE,
        overwrite = TRUE,
        seed_verbose = FALSE
      )
    },
    .package = "metasalmon"
  )

  dict_written <- readr::read_csv(file.path(pkg_path, "metadata", "column_dictionary.csv"), show_col_types = FALSE)
  weight_row <- dict_written[dict_written$column_name == "weight_kg", , drop = FALSE]

  expect_true(is.na(weight_row$term_iri[[1]]) || weight_row$term_iri[[1]] == "")
  expect_equal(weight_row$property_iri[[1]], paste0(metasalmon:::.ms_review_iri_prefix(), "https://example.org/property/weight"))
  expect_equal(weight_row$entity_iri[[1]], paste0(metasalmon:::.ms_review_iri_prefix(), "https://example.org/entity/fish-weight"))
  expect_equal(weight_row$unit_iri[[1]], paste0(metasalmon:::.ms_review_iri_prefix(), "http://qudt.org/vocab/unit/KiloGM"))
  expect_true(is.na(weight_row$method_iri[[1]]) || weight_row$method_iri[[1]] == "")
  expect_true(is.na(weight_row$constraint_iri[[1]]) || weight_row$constraint_iri[[1]] == "")
})

test_that("create_sdp seed note explains slower semantic lookup", {
  note <- metasalmon:::.ms_create_sdp_seed_note(
    seed_semantics = TRUE,
    seed_verbose = TRUE,
    semantic_code_scope = "factor"
  )

  expect_match(note, "may take a few minutes")
  expect_match(note, "factor and low-cardinality character columns")
  expect_null(metasalmon:::.ms_create_sdp_seed_note(seed_semantics = FALSE))
  expect_null(metasalmon:::.ms_create_sdp_seed_note(seed_semantics = TRUE, seed_verbose = FALSE))
})

test_that("infer_salmon_datapackage_artifacts warns when LLM options are ignored", {
  resources <- list(main = tibble::tibble(spawner_count = 1L))
  context_path <- file.path(withr::local_tempdir(), "context.html")
  writeLines("<html><body><p>Spawner abundance dictionary</p></body></html>", context_path)

  expect_warning(
    artifacts <- infer_salmon_datapackage_artifacts(
      resources = resources,
      dataset_id = "demo-dataset",
      table_id = "main",
      seed_semantics = FALSE,
      llm_assess = TRUE,
      llm_provider = "chapi",
      llm_api_key = "dummy-key",
      llm_context_files = context_path
    ),
    "seed_semantics = FALSE"
  )

  expect_null(artifacts$semantic_suggestions)
  expect_null(artifacts$semantic_llm_assessments)
})

test_that("create_sdp default code-level semantic seeding includes low-cardinality character columns but skips free-text fields", {
  resources <- list(
    catches = tibble::tibble(
      run = factor(c("early", "late")),
      station = c("A", "B"),
      survey_comment = c("looks odd", "double check"),
      count = c(10L, 20L)
    )
  )

  seen_codes <- NULL
  fake_suggest <- function(df, dict, sources = c("smn", "gcdfo", "ols", "nvs"),
                           include_dwc = FALSE, max_per_role = 3,
                           search_fn = find_terms, codes = NULL,
                           table_meta = NULL, dataset_meta = NULL) {
    seen_codes <<- codes
    attr(dict, "semantic_suggestions") <- tibble::tibble()
    dict
  }

  with_mocked_bindings(
    suggest_semantics = fake_suggest,
    {
      create_sdp(
        resources,
        path = file.path(withr::local_tempdir(), "factor-code-scope"),
        dataset_id = "scope-demo",
        seed_semantics = TRUE,
        seed_verbose = FALSE,
        overwrite = TRUE
      )
    }
  )

  expect_s3_class(seen_codes, "tbl_df")
  expect_setequal(unique(seen_codes$column_name), c("run", "station"))
})

test_that("create_sdp prefills legacy estimate-method code IRIs without overwriting explicit values", {
  resources <- list(
    escapement = tibble::tibble(
      ESTIMATE_METHOD = c("Area Under the Curve", "Not Applicable", "Sonar-ARIS"),
      RUN_TYPE = c("EARLY", "LATE", "EARLY"),
      count = c(10L, 20L, 30L)
    )
  )
  seed_codes <- tibble::tibble(
    dataset_id = rep("scope-demo", 4),
    table_id = rep("escapement", 4),
    column_name = c("ESTIMATE_METHOD", "ESTIMATE_METHOD", "ESTIMATE_METHOD", "RUN_TYPE"),
    code_value = c("Area Under the Curve", "Not Applicable", "Sonar-ARIS", "EARLY"),
    code_label = c("Area Under the Curve", "Not Applicable", "Sonar-ARIS", "Early"),
    code_description = c("Legacy estimate method", "Administrative value", "Legacy estimate method", "Run timing"),
    vocabulary_iri = NA_character_,
    term_iri = c(NA_character_, NA_character_, "https://example.org/custom-sonar", NA_character_),
    term_type = NA_character_
  )

  artifacts <- infer_salmon_datapackage_artifacts(
    resources,
    dataset_id = "scope-demo",
    seed_codes = seed_codes,
    seed_semantics = FALSE
  )
  pkg_path <- create_sdp(
    resources,
    path = file.path(withr::local_tempdir(), "estimate-method-prefill"),
    dataset_id = "scope-demo",
    seed_codes = seed_codes,
    seed_semantics = FALSE,
    check_updates = FALSE,
    overwrite = TRUE
  )

  est_rows_seen <- artifacts$codes[artifacts$codes$column_name == "ESTIMATE_METHOD", , drop = FALSE]
  est_rows_written <- readr::read_csv(file.path(pkg_path, "metadata", "codes.csv"), show_col_types = FALSE)
  est_rows_written <- est_rows_written[est_rows_written$column_name == "ESTIMATE_METHOD", , drop = FALSE]

  expect_equal(
    est_rows_seen$term_iri[est_rows_seen$code_value == "Area Under the Curve"],
    "https://w3id.org/gcdfo/salmon#AreaUnderTheCurve"
  )
  expect_true(
    is.na(est_rows_seen$term_iri[est_rows_seen$code_value == "Not Applicable"]) ||
      est_rows_seen$term_iri[est_rows_seen$code_value == "Not Applicable"] == ""
  )
  expect_equal(
    est_rows_seen$term_iri[est_rows_seen$code_value == "Sonar-ARIS"],
    "https://example.org/custom-sonar"
  )
  expect_true(
    is.na(artifacts$codes$term_iri[artifacts$codes$column_name == "RUN_TYPE"]) ||
      artifacts$codes$term_iri[artifacts$codes$column_name == "RUN_TYPE"] == ""
  )

  expect_equal(
    est_rows_written$term_iri[est_rows_written$code_value == "Area Under the Curve"],
    "https://w3id.org/gcdfo/salmon#AreaUnderTheCurve"
  )
  expect_true(
    is.na(est_rows_written$term_iri[est_rows_written$code_value == "Not Applicable"]) ||
      est_rows_written$term_iri[est_rows_written$code_value == "Not Applicable"] == ""
  )
  expect_equal(
    est_rows_written$term_iri[est_rows_written$code_value == "Sonar-ARIS"],
    "https://example.org/custom-sonar"
  )
})

test_that("create_sdp filters bad non-measurement term IRIs before auto-apply", {
  fuller_path <- system.file("extdata", "nuseds-fraser-coho-2023-2024.csv", package = "metasalmon")
  fraser_coho_fuller <- readr::read_csv(fuller_path, show_col_types = FALSE)

  fake_suggest <- function(df, dict, sources = c("smn", "gcdfo", "ols", "nvs"),
                           include_dwc = FALSE, max_per_role = 3,
                           search_fn = find_terms, codes = NULL,
                           table_meta = NULL, dataset_meta = NULL) {
    attr(dict, "semantic_suggestions") <- tibble::tibble(
      dataset_id = c("fraser-coho-2023-2024", "fraser-coho-2023-2024", "fraser-coho-2023-2024", "fraser-coho-2023-2024"),
      table_id = c("escapement", "escapement", "escapement", "escapement"),
      column_name = c("AREA", "SPECIES", "RUN_TYPE", "WATERBODY"),
      dictionary_role = c("variable", "variable", "variable", "variable"),
      target_scope = c("column", "column", "column", "column"),
      target_sdp_file = c("column_dictionary.csv", "column_dictionary.csv", "column_dictionary.csv", "column_dictionary.csv"),
      target_sdp_field = c("term_iri", "term_iri", "term_iri", "term_iri"),
      search_query = c("Area", "Species", "Run type", "Waterbody"),
      column_label = c("AREA", "SPECIES", "RUN_TYPE", "WATERBODY"),
      label = c("In River Mortality Rate", "Ampharete lindstroemi", "Fish Length Measurement Type", "Waterbody"),
      iri = c(
        "https://example.org/in-river-mortality-rate",
        "https://example.org/ampharete-lindstroemi",
        "https://example.org/fish-length-measurement-type",
        "https://example.org/waterbody"
      ),
      match_type = c("label_exact", "label_exact", "label_exact", "label_exact"),
      score = c(0.95, 0.95, 0.95, 0.95)
    )
    dict
  }

  pkg_path <- with_mocked_bindings(
    suggest_semantics = fake_suggest,
    {
      create_sdp(
        fraser_coho_fuller,
        path = file.path(withr::local_tempdir(), "fraser-coho-fuller-seeded"),
        dataset_id = "fraser-coho-2023-2024",
        table_id = "escapement",
        seed_semantics = TRUE,
        seed_verbose = FALSE,
        check_updates = FALSE,
        overwrite = TRUE
      )
    }
  )

  dict_written <- readr::read_csv(file.path(pkg_path, "metadata", "column_dictionary.csv"), show_col_types = FALSE)
  expect_true(is.na(dict_written$term_iri[dict_written$column_name == "AREA"]) || dict_written$term_iri[dict_written$column_name == "AREA"] == "")
  expect_true(is.na(dict_written$term_iri[dict_written$column_name == "SPECIES"]) || dict_written$term_iri[dict_written$column_name == "SPECIES"] == "")
  expect_true(is.na(dict_written$term_iri[dict_written$column_name == "RUN_TYPE"]) || dict_written$term_iri[dict_written$column_name == "RUN_TYPE"] == "")
  expect_equal(dict_written$term_iri[dict_written$column_name == "WATERBODY"], paste0(metasalmon:::.ms_review_iri_prefix(), "https://example.org/waterbody"))
})

test_that("create_sdp keeps broad physical measurement matches review-only but still applies unit hits", {
  resources <- list(
    hydro = tibble::tibble(
      water_level = c(1.2, 1.3),
      spawner_count = c(10L, 20L)
    )
  )

  fake_suggest <- function(df, dict, sources = c("smn", "gcdfo", "ols", "nvs"),
                           include_dwc = FALSE, max_per_role = 3,
                           search_fn = find_terms, codes = NULL,
                           table_meta = NULL, dataset_meta = NULL) {
    attr(dict, "semantic_suggestions") <- tibble::tibble(
      dataset_id = c(rep("hydro-demo", 5), rep("hydro-demo", 2)),
      table_id = c(rep("hydro", 5), rep("hydro", 2)),
      column_name = c(rep("water_level", 5), rep("spawner_count", 2)),
      dictionary_role = c("variable", "property", "entity", "method", "unit", "variable", "property"),
      target_scope = "column",
      target_sdp_file = "column_dictionary.csv",
      target_sdp_field = c("term_iri", "property_iri", "entity_iri", "method_iri", "unit_iri", "term_iri", "property_iri"),
      search_query = c("water level", "water level", "water level", "water level", "meter", "adult spawner count", "count"),
      column_label = c(rep("Water Level (m)", 5), rep("Spawner Count", 2)),
      label = c("Escapement", "Mainstem phase", "Population", "uses observation procedure", "Meter", "Spawner abundance", "count"),
      iri = c(
        "https://w3id.org/smn/Escapement",
        "https://w3id.org/smn/MainstemPhase",
        "https://w3id.org/smn/Population",
        "https://w3id.org/smn/usesObservationProcedure",
        "http://qudt.org/vocab/unit/M",
        "https://w3id.org/gcdfo/salmon#SpawnerAbundance",
        "http://purl.obolibrary.org/obo/STATO_0000047"
      ),
      source = c("smn", "smn", "smn", "smn", "qudt", "gcdfo", "ols"),
      ontology = c("smn", "smn", "smn", "smn", "qudt", "gcdfo", "stato"),
      role = c("variable", "property", "entity", "method", "unit", "variable", "property"),
      match_type = c("class", "concept", "class", "objectproperty", "unit", "class", "label_exact"),
      definition = NA_character_,
      score = c(8, 8, 8, 8, 4.4, 3, 0.8)
    )
    dict
  }

  pkg_path <- with_mocked_bindings(
    suggest_semantics = fake_suggest,
    {
      create_sdp(
        resources,
        path = file.path(withr::local_tempdir(), "hydro-review-only"),
        dataset_id = "hydro-demo",
        seed_semantics = TRUE,
        seed_verbose = FALSE,
        check_updates = FALSE,
        overwrite = TRUE
      )
    }
  )

  dict_written <- readr::read_csv(file.path(pkg_path, "metadata", "column_dictionary.csv"), show_col_types = FALSE)
  water_row <- dict_written[dict_written$column_name == "water_level", , drop = FALSE]
  count_row <- dict_written[dict_written$column_name == "spawner_count", , drop = FALSE]

  expect_true(is.na(water_row$term_iri[[1]]) || water_row$term_iri[[1]] == "")
  expect_true(is.na(water_row$property_iri[[1]]) || water_row$property_iri[[1]] == "")
  expect_true(is.na(water_row$entity_iri[[1]]) || water_row$entity_iri[[1]] == "")
  expect_true(is.na(water_row$method_iri[[1]]) || water_row$method_iri[[1]] == "")
  expect_equal(water_row$unit_iri[[1]], paste0(metasalmon:::.ms_review_iri_prefix(), "http://qudt.org/vocab/unit/M"))

  expect_equal(count_row$term_iri[[1]], paste0(metasalmon:::.ms_review_iri_prefix(), "https://w3id.org/gcdfo/salmon#SpawnerAbundance"))
  expect_equal(count_row$property_iri[[1]], paste0(metasalmon:::.ms_review_iri_prefix(), "http://purl.obolibrary.org/obo/STATO_0000047"))
})

test_that("create_sdp keeps camelCase physical DwC property suggestions review-only but still applies unit hits", {
  resources <- list(
    event = tibble::tibble(
      minimumDepthInMeters = c(12.4, 15.1)
    )
  )

  fake_find_terms <- function(query, role = NA_character_, sources = c("smn", "gcdfo", "ols", "nvs"), ...) {
    query <- tolower(query)

    if (identical(role, "unit") && identical(query, "meter")) {
      return(tibble::tibble(
        label = "Meter",
        iri = "http://qudt.org/vocab/unit/M",
        source = "qudt",
        ontology = "qudt",
        role = "unit",
        match_type = "label_exact",
        definition = "Length unit",
        score = 4.5
      ))
    }

    if (identical(role, "variable") && grepl("minimum depth", query, fixed = TRUE)) {
      return(tibble::tibble(
        label = "Minimum Depth In Meters",
        iri = "http://rs.tdwg.org/dwc/terms/minimumDepthInMeters",
        source = "ols",
        ontology = "dwc",
        role = "variable",
        match_type = "dataProperty",
        definition = "Darwin Core publication property",
        score = 2.5
      ))
    }

    if (identical(role, "property") && grepl("minimum depth", query, fixed = TRUE)) {
      return(tibble::tibble(
        label = "Total length measurement",
        iri = "https://w3id.org/smn/TotalLengthMeasurement",
        source = "smn",
        ontology = "smn",
        role = "property",
        match_type = "class",
        definition = "Wrong fish-length property candidate",
        score = 6.8
      ))
    }

    if (identical(role, "entity") && grepl("minimum depth", query, fixed = TRUE)) {
      return(tibble::tibble(
        label = "Minimum Depth In Meters",
        iri = "http://rs.tdwg.org/dwc/terms/minimumDepthInMeters",
        source = "ols",
        ontology = "dwc",
        role = "entity",
        match_type = "dataProperty",
        definition = "Darwin Core publication property",
        score = 2.5
      ))
    }

    if (identical(role, "method") && grepl("minimum depth", query, fixed = TRUE)) {
      return(tibble::tibble(
        label = "Enumeration method",
        iri = "https://w3id.org/smn/EnumerationMethod",
        source = "smn",
        ontology = "smn",
        role = "method",
        match_type = "class",
        definition = "Generic method class",
        score = 6.1
      ))
    }

    tibble::tibble()
  }

  pkg_path <- with_mocked_bindings(
    find_terms = fake_find_terms,
    {
      create_sdp(
        resources,
        path = file.path(withr::local_tempdir(), "dwc-camel-guard"),
        dataset_id = "dwc-depth-demo",
        seed_semantics = TRUE,
        seed_verbose = FALSE,
        check_updates = FALSE,
        overwrite = TRUE
      )
    }
  )

  dict_written <- readr::read_csv(file.path(pkg_path, "metadata", "column_dictionary.csv"), show_col_types = FALSE)
  depth_row <- dict_written[dict_written$column_name == "minimumDepthInMeters", , drop = FALSE]

  expect_equal(depth_row$column_role[[1]], "measurement")
  expect_true(is.na(depth_row$term_iri[[1]]) || depth_row$term_iri[[1]] == "")
  expect_true(is.na(depth_row$property_iri[[1]]) || depth_row$property_iri[[1]] == "")
  expect_true(is.na(depth_row$entity_iri[[1]]) || depth_row$entity_iri[[1]] == "")
  expect_true(is.na(depth_row$method_iri[[1]]) || depth_row$method_iri[[1]] == "")
  expect_equal(depth_row$unit_iri[[1]], paste0(metasalmon:::.ms_review_iri_prefix(), "http://qudt.org/vocab/unit/M"))
})

test_that("create_sdp paired value/unit measurements auto-apply only the unit hit", {
  resources <- list(
    event = tibble::tibble(
      sampleSizeValue = c(2046.33, 131340.85),
      sampleSizeUnit = c("square metre", "square metre"),
      eventType = c("deployment", "deployment")
    )
  )

  fake_find_terms <- function(query, role = NA_character_, sources = c("smn", "gcdfo", "ols", "nvs"), ...) {
    query <- tolower(query)

    if (identical(role, "unit") && identical(query, "square meter")) {
      return(tibble::tibble(
        label = "Square Meter",
        iri = "http://qudt.org/vocab/unit/M2",
        source = "qudt",
        ontology = "qudt",
        role = "unit",
        match_type = "label_exact",
        definition = "Area unit",
        score = 4.8
      ))
    }

    if (identical(role, "variable") && grepl("sample size", query, fixed = TRUE)) {
      return(tibble::tibble(
        label = "Sample size",
        iri = "http://example.org/sample-size",
        source = "ols",
        ontology = "demo",
        role = "variable",
        match_type = "label_exact",
        definition = "Still too generic to auto-apply safely here",
        score = 3.2
      ))
    }

    if (identical(role, "property") && grepl("sample size", query, fixed = TRUE)) {
      return(tibble::tibble(
        label = "collection size",
        iri = "http://example.org/collection-size",
        source = "ols",
        ontology = "demo",
        role = "property",
        match_type = "label_exact",
        definition = "Generic size property",
        score = 3.2
      ))
    }

    tibble::tibble()
  }

  pkg_path <- with_mocked_bindings(
    find_terms = fake_find_terms,
    {
      create_sdp(
        resources,
        path = file.path(withr::local_tempdir(), "paired-value-unit"),
        dataset_id = "paired-value-demo",
        seed_semantics = TRUE,
        seed_verbose = FALSE,
        check_updates = FALSE,
        overwrite = TRUE
      )
    }
  )

  dict_written <- readr::read_csv(file.path(pkg_path, "metadata", "column_dictionary.csv"), show_col_types = FALSE)
  sample_row <- dict_written[dict_written$column_name == "sampleSizeValue", , drop = FALSE]

  expect_equal(sample_row$column_role[[1]], "measurement")
  expect_true(is.na(sample_row$term_iri[[1]]) || sample_row$term_iri[[1]] == "")
  expect_true(is.na(sample_row$property_iri[[1]]) || sample_row$property_iri[[1]] == "")
  expect_true(is.na(sample_row$entity_iri[[1]]) || sample_row$entity_iri[[1]] == "")
  expect_equal(sample_row$unit_iri[[1]], paste0(metasalmon:::.ms_review_iri_prefix(), "http://qudt.org/vocab/unit/M2"))
})

test_that("create_sdp uses the matching table context when semantic seeding multi-table resources", {
  resources <- list(
    catches = tibble::tibble(
      species = c("Coho", "Chinook"),
      count = c(10L, 20L)
    ),
    event = tibble::tibble(
      sampleSizeValue = c(2046.33, 131340.85),
      sampleSizeUnit = c("square metre", "square metre"),
      eventType = c("deployment", "deployment")
    )
  )

  fake_find_terms <- function(query, role = NA_character_, sources = c("smn", "gcdfo", "ols", "nvs"), ...) {
    query <- tolower(query)

    if (identical(role, "unit") && identical(query, "square meter")) {
      return(tibble::tibble(
        label = "Square Meter",
        iri = "http://qudt.org/vocab/unit/M2",
        source = "qudt",
        ontology = "qudt",
        role = "unit",
        match_type = "label_exact",
        definition = "Area unit",
        score = 4.8
      ))
    }

    if (identical(role, "variable") && grepl("sample size", query, fixed = TRUE)) {
      return(tibble::tibble(
        label = "Sample size",
        iri = "http://example.org/sample-size",
        source = "ols",
        ontology = "demo",
        role = "variable",
        match_type = "label_exact",
        definition = "Still too generic to auto-apply safely here",
        score = 3.2
      ))
    }

    if (identical(role, "property") && grepl("sample size", query, fixed = TRUE)) {
      return(tibble::tibble(
        label = "collection size",
        iri = "http://example.org/collection-size",
        source = "ols",
        ontology = "demo",
        role = "property",
        match_type = "label_exact",
        definition = "Generic size property",
        score = 3.2
      ))
    }

    tibble::tibble()
  }

  pkg_path <- with_mocked_bindings(
    find_terms = fake_find_terms,
    {
      create_sdp(
        resources,
        path = file.path(withr::local_tempdir(), "paired-value-unit-multi-table"),
        dataset_id = "paired-value-multi-demo",
        seed_semantics = TRUE,
        seed_verbose = FALSE,
        check_updates = FALSE,
        overwrite = TRUE
      )
    }
  )

  dict_written <- readr::read_csv(file.path(pkg_path, "metadata", "column_dictionary.csv"), show_col_types = FALSE)
  sample_row <- dict_written[dict_written$table_id == "event" & dict_written$column_name == "sampleSizeValue", , drop = FALSE]

  expect_equal(sample_row$column_role[[1]], "measurement")
  expect_true(is.na(sample_row$term_iri[[1]]) || sample_row$term_iri[[1]] == "")
  expect_true(is.na(sample_row$property_iri[[1]]) || sample_row$property_iri[[1]] == "")
  expect_true(is.na(sample_row$entity_iri[[1]]) || sample_row$entity_iri[[1]] == "")
  expect_equal(sample_row$unit_iri[[1]], paste0(metasalmon:::.ms_review_iri_prefix(), "http://qudt.org/vocab/unit/M2"))
})

test_that("create_sdp unit seeding can use role-augmented unit sources", {
  resources <- list(
    hydro = tibble::tibble(
      `Water Level / Niveau d'eau (m)` = c(1.2, 1.3),
      temperature_degree_c = c(6.1, 6.4)
    )
  )

  calls <- list()
  fake_find_terms <- function(query, role = NA_character_, sources = c("smn", "gcdfo", "ols", "nvs"), ...) {
    calls[[length(calls) + 1]] <<- tibble::tibble(
      query = query,
      role = role,
      sources = list(sources)
    )

    if (identical(role, "unit")) {
      if ("qudt" %in% sources) {
        if (identical(query, "degree celsius")) {
          return(tibble::tibble(
            label = "Degree Celsius",
            iri = "http://qudt.org/vocab/unit/DEG_C",
            source = "qudt",
            ontology = "qudt",
            role = "unit",
            match_type = "label_exact",
            definition = "Temperature unit",
            score = 4.5
          ))
        }
        return(tibble::tibble(
          label = "Meter",
          iri = "http://qudt.org/vocab/unit/M",
          source = "qudt",
          ontology = "qudt",
          role = "unit",
          match_type = "label_exact",
          definition = "Length unit",
          score = 4.5
        ))
      }
      return(tibble::tibble(
        label = "Degrees Celsius kilogram per square metre",
        iri = "http://vocab.nerc.ac.uk/collection/P06/current/UFAKE/",
        source = "nvs",
        ontology = "P06",
        role = "unit",
        match_type = "label_partial",
        definition = "Bad blended candidate",
        score = 0.1
      ))
    }

    tibble::tibble(
      label = "Escapement",
      iri = paste0("https://example.org/", role),
      source = "ols",
      ontology = "demo",
      role = role,
      match_type = "label_partial",
      definition = "Generic candidate",
      score = 0.2
    )
  }

  pkg_path <- with_mocked_bindings(
    find_terms = fake_find_terms,
    {
      create_sdp(
        resources,
        path = file.path(withr::local_tempdir(), "hydro-unit-sources"),
        dataset_id = "hydro-unit-demo",
        seed_semantics = TRUE,
        seed_verbose = FALSE,
        check_updates = FALSE,
        overwrite = TRUE
      )
    }
  )

  dict_written <- readr::read_csv(file.path(pkg_path, "metadata", "column_dictionary.csv"), show_col_types = FALSE)
  water_row <- dict_written[dict_written$column_name == "Water Level / Niveau d'eau (m)", , drop = FALSE]
  temp_row <- dict_written[dict_written$column_name == "temperature_degree_c", , drop = FALSE]

  expect_equal(water_row$unit_iri[[1]], paste0(metasalmon:::.ms_review_iri_prefix(), "http://qudt.org/vocab/unit/M"))
  expect_true(is.na(water_row$term_iri[[1]]) || water_row$term_iri[[1]] == "")
  expect_true(is.na(water_row$property_iri[[1]]) || water_row$property_iri[[1]] == "")
  expect_equal(temp_row$unit_iri[[1]], paste0(metasalmon:::.ms_review_iri_prefix(), "http://qudt.org/vocab/unit/DEG_C"))
  expect_true(is.na(temp_row$term_iri[[1]]) || temp_row$term_iri[[1]] == "")
  expect_true(is.na(temp_row$property_iri[[1]]) || temp_row$property_iri[[1]] == "")

  call_df <- dplyr::bind_rows(calls)
  unit_sources <- call_df$sources[call_df$role == "unit"][[1]]
  expect_identical(unit_sources, sources_for_role("unit"))
})

test_that("create_sdp treats explicit semantic sources as a strict allowlist", {
  source_calls <- list()
  fake_find_terms <- function(query, role, sources, ...) {
    source_calls[[length(source_calls) + 1L]] <<- sources
    tibble::tibble()
  }

  with_mocked_bindings(
    find_terms = fake_find_terms,
    {
      create_sdp(
        tibble::tibble(count = c(1L, 2L)),
        path = file.path(withr::local_tempdir(), "strict-source-allowlist"),
        seed_semantics = TRUE,
        semantic_sources = "smn",
        seed_verbose = FALSE,
        check_updates = FALSE,
        overwrite = TRUE
      )
    }
  )

  expect_true(length(source_calls) > 0L)
  expect_true(all(vapply(
    source_calls,
    identical,
    logical(1),
    y = "smn"
  )))
  expect_false(any(vapply(
    source_calls,
    function(sources) "qudt" %in% sources,
    logical(1)
  )))
})

test_that("create_sdp can broaden code-level semantic seeding and optionally check for updates", {
  resources <- list(
    catches = tibble::tibble(
      run = factor(c("early", "late")),
      station = c("A", "B"),
      count = c(10L, 20L)
    )
  )

  seen_codes <- NULL
  update_calls <- 0L
  fake_suggest <- function(df, dict, sources = c("smn", "gcdfo", "ols", "nvs"),
                           include_dwc = FALSE, max_per_role = 3,
                           search_fn = find_terms, codes = NULL,
                           table_meta = NULL, dataset_meta = NULL) {
    seen_codes <<- codes
    attr(dict, "semantic_suggestions") <- tibble::tibble()
    dict
  }
  fake_check_for_updates <- function(...) {
    update_calls <<- update_calls + 1L
    structure(
      list(
        status = "update_available",
        update_available = TRUE,
        latest_version = "9.9.9",
        install_command = "remotes::install_github('salmon-data-mobilization/metasalmon')"
      ),
      class = "metasalmon_update_check"
    )
  }

  with_mocked_bindings(
    suggest_semantics = fake_suggest,
    check_for_updates = fake_check_for_updates,
    {
      create_sdp(
        resources,
        path = file.path(withr::local_tempdir(), "all-code-scope"),
        dataset_id = "scope-demo-all",
        seed_semantics = TRUE,
        seed_verbose = FALSE,
        semantic_code_scope = "all",
        check_updates = TRUE,
        overwrite = TRUE
      )

      create_sdp(
        resources,
        path = file.path(withr::local_tempdir(), "no-update-check"),
        dataset_id = "scope-demo-no-update",
        seed_semantics = TRUE,
        seed_verbose = FALSE,
        semantic_code_scope = "all",
        check_updates = FALSE,
        overwrite = TRUE
      )
    }
  )

  expect_setequal(unique(seen_codes$column_name), c("run", "station"))
  expect_equal(update_calls, 1L)
})

test_that("read_salmon_datapackage reads package correctly", {
  # Create test package
  resources <- list(
    main_table = tibble::tibble(
      species = c("Coho", "Chinook"),
      count = c(100L, 200L)
    )
  )

  dataset_meta <- tibble::tibble(
    dataset_id = "test-1",
    title = "Test Dataset",
    description = "A test dataset",
    creator = "Test Author",
    contact_name = NA_character_,
    contact_email = NA_character_,
    license = "MIT",
    temporal_start = NA_character_,
    temporal_end = NA_character_,
    spatial_extent = NA_character_,
    dataset_type = NA_character_,
    source_citation = NA_character_
  )

  table_meta <- tibble::tibble(
    dataset_id = "test-1",
    table_id = "main_table",
    file_name = "data/main_table.csv",
    table_label = "Main Table",
    description = "Main data table",
    observation_unit = NA_character_,
    observation_unit_iri = NA_character_,
    primary_key = NA_character_
  )

  dict <- infer_dictionary(
    resources$main_table,
    dataset_id = "test-1",
    table_id = "main_table"
  )
  dict <- fill_measurement_components(dict)
  validate_dictionary(dict)

  temp_dir <- withr::local_tempdir()
  write_salmon_datapackage(
    resources,
    dataset_meta,
    table_meta,
    dict,
    path = temp_dir,
    format = "csv",
    overwrite = TRUE
  )

  # Read it back
  pkg <- read_salmon_datapackage(temp_dir)

  expect_true("dataset" %in% names(pkg))
  expect_true("tables" %in% names(pkg))
  expect_true("dictionary" %in% names(pkg))
  expect_true("resources" %in% names(pkg))

  expect_equal(nrow(pkg$dataset), 1)
  expect_equal(pkg$dataset$dataset_id, "test-1")
  expect_equal(pkg$dataset$title, "Test Dataset")

  expect_true("main_table" %in% names(pkg$resources))
  expect_equal(nrow(pkg$resources$main_table), 2)
  expect_equal(ncol(pkg$resources$main_table), 2)
})

test_that("read_salmon_datapackage prefers canonical CSV metadata when datapackage.json is absent", {
  resources <- list(
    main_table = tibble::tibble(
      species = c("Coho", "Chinook"),
      count = c(100L, 200L)
    )
  )

  dataset_meta <- tibble::tibble(
    dataset_id = "test-1",
    title = "Test Dataset",
    description = "A test dataset",
    creator = "Test Author",
    contact_name = NA_character_,
    contact_email = NA_character_,
    license = "MIT"
  )

  table_meta <- tibble::tibble(
    dataset_id = "test-1",
    table_id = "main_table",
    file_name = "data/main_table.csv",
    table_label = "Main Table",
    description = "Main data table"
  )

  dict <- infer_dictionary(
    resources$main_table,
    dataset_id = "test-1",
    table_id = "main_table"
  )
  dict <- fill_measurement_components(dict)
  validate_dictionary(dict)

  temp_dir <- withr::local_tempdir()
  write_salmon_datapackage(
    resources,
    dataset_meta,
    table_meta,
    dict,
    path = temp_dir,
    format = "csv",
    overwrite = TRUE
  )

  unlink(file.path(temp_dir, "datapackage.json"))

  pkg <- read_salmon_datapackage(temp_dir)

  expect_equal(pkg$dataset$dataset_id, "test-1")
  expect_equal(pkg$tables$table_id, "main_table")
  expect_equal(pkg$dictionary$column_name, c("species", "count"))
  expect_true("main_table" %in% names(pkg$resources))
})

test_that("read_salmon_datapackage still reads legacy root-level metadata CSVs", {
  resources <- list(
    main_table = tibble::tibble(
      species = c("Coho", "Chinook"),
      count = c(100L, 200L)
    )
  )

  dataset_meta <- tibble::tibble(
    dataset_id = "legacy-1",
    title = "Legacy Dataset",
    description = "Legacy layout test",
    creator = "Test Author",
    contact_name = NA_character_,
    contact_email = NA_character_,
    license = "MIT"
  )

  table_meta <- tibble::tibble(
    dataset_id = "legacy-1",
    table_id = "main_table",
    file_name = "data/main_table.csv",
    table_label = "Main Table",
    description = "Main data table"
  )

  dict <- infer_dictionary(
    resources$main_table,
    dataset_id = "legacy-1",
    table_id = "main_table"
  )
  dict <- fill_measurement_components(dict)
  validate_dictionary(dict)

  temp_dir <- withr::local_tempdir()
  write_salmon_datapackage(
    resources,
    dataset_meta,
    table_meta,
    dict,
    path = temp_dir,
    format = "csv",
    overwrite = TRUE
  )

  file.copy(file.path(temp_dir, "metadata", "dataset.csv"), file.path(temp_dir, "dataset.csv"), overwrite = TRUE)
  file.copy(file.path(temp_dir, "metadata", "tables.csv"), file.path(temp_dir, "tables.csv"), overwrite = TRUE)
  file.copy(file.path(temp_dir, "metadata", "column_dictionary.csv"), file.path(temp_dir, "column_dictionary.csv"), overwrite = TRUE)
  unlink(file.path(temp_dir, "metadata"), recursive = TRUE)

  pkg <- read_salmon_datapackage(temp_dir)

  expect_equal(pkg$dataset$dataset_id, "legacy-1")
  expect_equal(pkg$tables$table_id, "main_table")
  expect_true("main_table" %in% names(pkg$resources))
})

test_that("write_salmon_datapackage round-trip preserves data", {
  # Create test data
  original_df <- tibble::tibble(
    species = c("Coho", "Chinook", "Sockeye"),
    count = c(100L, 200L, 150L),
    date = as.Date(c("2024-01-01", "2024-01-02", "2024-01-03"))
  )

  resources <- list(main_table = original_df)

  dataset_meta <- tibble::tibble(
    dataset_id = "test-1",
    title = "Test Dataset",
    description = "A test dataset",
    creator = "Test Author",
    contact_name = NA_character_,
    contact_email = NA_character_,
    license = "MIT",
    temporal_start = NA_character_,
    temporal_end = NA_character_,
    spatial_extent = NA_character_,
    dataset_type = NA_character_,
    source_citation = NA_character_
  )

  table_meta <- tibble::tibble(
    dataset_id = "test-1",
    table_id = "main_table",
    file_name = "data/main_table.csv",
    table_label = "Main Table",
    description = "Main data table",
    observation_unit = NA_character_,
    observation_unit_iri = NA_character_,
    primary_key = NA_character_
  )

  dict <- infer_dictionary(
    original_df,
    dataset_id = "test-1",
    table_id = "main_table"
  )
  dict <- fill_measurement_components(dict)
  validate_dictionary(dict)

  temp_dir <- withr::local_tempdir()
  write_salmon_datapackage(
    resources,
    dataset_meta,
    table_meta,
    dict,
    path = temp_dir,
    format = "csv",
    overwrite = TRUE
  )

  # Read it back
  pkg <- read_salmon_datapackage(temp_dir)
  read_df <- pkg$resources$main_table

  # Compare data (column names may differ due to renaming)
  expect_equal(nrow(read_df), nrow(original_df))
  expect_equal(ncol(read_df), ncol(original_df))

  # Check that data values are preserved (may need to account for renaming)
  # This is a basic check; full round-trip would require applying dictionary
})

test_that("I-ADOPT fields round-trip through datapackage.json", {
  resources <- list(
    main_table = tibble::tibble(
      count = c(1L, 2L)
    )
  )

  dataset_meta <- tibble::tibble(
    dataset_id = "test-1",
    title = "Test Dataset",
    description = "A test dataset",
    creator = "Test Author",
    contact_name = NA_character_,
    contact_email = NA_character_,
    license = "MIT",
    temporal_start = NA_character_,
    temporal_end = NA_character_,
    spatial_extent = NA_character_,
    dataset_type = NA_character_,
    source_citation = NA_character_
  )

  table_meta <- tibble::tibble(
    dataset_id = "test-1",
    table_id = "main_table",
    file_name = "data/main_table.csv",
    table_label = "Main Table",
    description = "Main data table",
    observation_unit = NA_character_,
    observation_unit_iri = NA_character_,
    primary_key = NA_character_
  )

  dict <- tibble::tibble(
    dataset_id = "test-1",
    table_id = "main_table",
    column_name = c("count"),
    column_label = c("count"),
    column_description = c("Example count"),
    column_role = c("measurement"),
    value_type = c("integer"),
    unit_label = c("Individual"),
    unit_iri = c("https://qudt.org/vocab/unit/INDIV"),
    term_iri = c("https://w3id.org/example/term"),
    term_type = c("skos_concept"),
    required = FALSE,
    property_iri = c("https://example.org/property/abundance"),
    entity_iri = c("https://w3id.org/example/entity"),
    constraint_iri = c("https://w3id.org/example/constraint"),
    method_iri = c("https://w3id.org/example/method")
  )

  temp_dir <- withr::local_tempdir()
  write_salmon_datapackage(
    resources,
    dataset_meta,
    table_meta,
    dict,
    path = temp_dir,
    format = "csv",
    overwrite = TRUE
  )

  pkg <- read_salmon_datapackage(temp_dir)

  expect_true(all(c("property_iri", "entity_iri", "constraint_iri", "method_iri", "unit_iri") %in% names(pkg$dictionary)))
  expect_equal(pkg$dictionary$property_iri, dict$property_iri)
  expect_equal(pkg$dictionary$entity_iri, dict$entity_iri)
  expect_equal(pkg$dictionary$constraint_iri, dict$constraint_iri)
  expect_equal(pkg$dictionary$method_iri, dict$method_iri)
  expect_equal(pkg$dictionary$unit_iri, dict$unit_iri)
})

test_that("write_salmon_datapackage errors on existing path without overwrite", {
  temp_dir <- withr::local_tempdir()

  # Create a file in the directory
  writeLines("test", file.path(temp_dir, "test.txt"))

  resources <- list(main_table = tibble::tibble(x = 1))
  dataset_meta <- tibble::tibble(
    dataset_id = "test-1",
    title = "Test",
    description = "Test",
    creator = NA_character_,
    contact_name = NA_character_,
    contact_email = NA_character_,
    license = NA_character_,
    temporal_start = NA_character_,
    temporal_end = NA_character_,
    spatial_extent = NA_character_,
    dataset_type = NA_character_,
    source_citation = NA_character_
  )
  table_meta <- tibble::tibble(
    dataset_id = "test-1",
    table_id = "main_table",
    file_name = "data/main_table.csv",
    table_label = "Main",
    description = NA_character_,
    observation_unit = NA_character_,
    observation_unit_iri = NA_character_,
    primary_key = NA_character_
  )
  dict <- infer_dictionary(resources$main_table, dataset_id = "test-1", table_id = "main_table")
  dict <- fill_measurement_components(dict)

  expect_error(
    write_salmon_datapackage(
      resources,
      dataset_meta,
      table_meta,
      dict,
      path = temp_dir,
      overwrite = FALSE
    ),
    "already exists"
  )
})

test_that("write_salmon_datapackage refuses overwrite for non-metasalmon directories", {
  temp_dir <- withr::local_tempdir()
  writeLines("do not delete", file.path(temp_dir, "keep.txt"))

  resources <- list(main_table = tibble::tibble(x = 1))
  dataset_meta <- tibble::tibble(
    dataset_id = "test-1",
    title = "Test",
    description = "Test",
    creator = NA_character_,
    contact_name = NA_character_,
    contact_email = NA_character_,
    license = NA_character_,
    temporal_start = NA_character_,
    temporal_end = NA_character_,
    spatial_extent = NA_character_,
    dataset_type = NA_character_,
    source_citation = NA_character_
  )
  table_meta <- tibble::tibble(
    dataset_id = "test-1",
    table_id = "main_table",
    file_name = "data/main_table.csv",
    table_label = "Main",
    description = NA_character_,
    observation_unit = NA_character_,
    observation_unit_iri = NA_character_,
    primary_key = NA_character_
  )
  dict <- infer_dictionary(resources$main_table, dataset_id = "test-1", table_id = "main_table")
  dict <- fill_measurement_components(dict)

  expect_error(
    write_salmon_datapackage(
      resources,
      dataset_meta,
      table_meta,
      dict,
      path = temp_dir,
      overwrite = TRUE
    ),
    "Refusing to overwrite non-metasalmon directory"
  )
  expect_true(file.exists(file.path(temp_dir, "keep.txt")))
})

test_that("write_salmon_datapackage can overwrite an existing metasalmon package", {
  temp_dir <- withr::local_tempdir()

  resources <- list(main_table = tibble::tibble(x = 1))
  dataset_meta <- tibble::tibble(
    dataset_id = "test-1",
    title = "Test",
    description = "Test",
    creator = NA_character_,
    contact_name = NA_character_,
    contact_email = NA_character_,
    license = NA_character_,
    temporal_start = NA_character_,
    temporal_end = NA_character_,
    spatial_extent = NA_character_,
    dataset_type = NA_character_,
    source_citation = NA_character_
  )
  table_meta <- tibble::tibble(
    dataset_id = "test-1",
    table_id = "main_table",
    file_name = "data/main_table.csv",
    table_label = "Main",
    description = NA_character_,
    observation_unit = NA_character_,
    observation_unit_iri = NA_character_,
    primary_key = NA_character_
  )
  dict <- infer_dictionary(resources$main_table, dataset_id = "test-1", table_id = "main_table")
  dict <- fill_measurement_components(dict)

  write_salmon_datapackage(
    resources,
    dataset_meta,
    table_meta,
    dict,
    path = temp_dir,
    overwrite = TRUE
  )
  writeLines("stale", file.path(temp_dir, "stale.txt"))

  write_salmon_datapackage(
    resources,
    dataset_meta,
    table_meta,
    dict,
    path = temp_dir,
    overwrite = TRUE
  )

  # Rewriting is now an in-place update: unmanaged files survive by default.
  expect_true(file.exists(file.path(temp_dir, "stale.txt")))
  expect_true(file.exists(file.path(temp_dir, ".metasalmon-package")))
  expect_true(file.exists(file.path(temp_dir, "metadata", "dataset.csv")))

  write_salmon_datapackage(
    resources,
    dataset_meta,
    table_meta,
    dict,
    path = temp_dir,
    overwrite = TRUE,
    prune = TRUE
  )

  expect_false(file.exists(file.path(temp_dir, "stale.txt")))
  expect_true(file.exists(file.path(temp_dir, ".metasalmon-package")))
  expect_true(file.exists(file.path(temp_dir, "metadata", "dataset.csv")))
})

test_that("a license URL remains distinct from an arbitrary rights statement", {
  license_url <- "https://example.org/data-terms/"

  expect_equal(
    .ms_license_descriptor(license_url),
    list(path = license_url)
  )
  expect_error(
    .ms_license_descriptor(
      paste(
        "Copyright Example Commission. Reuse is subject to prior consent.",
        license_url
      )
    ),
    "Unknown SDP publication license"
  )
  for (malformed_url in c(
    "https://>",
    "https://[bad",
    "https://?query",
    "https://example.org/>"
  )) {
    expect_error(
      .ms_license_descriptor(malformed_url),
      "Unknown SDP publication license"
    )
  }
})

test_that("validate_salmon_datapackage validates a CU/composite-style package", {
  resources <- list(
    cu_composite_escapement = tibble::tibble(
      cu_id = c("CU-001", "CU-002"),
      year = c(2023L, 2024L),
      escapement = c(1250, 1325),
      estimate_type = c("point", "point")
    )
  )

  dataset_meta <- tibble::tibble(
    dataset_id = "cu-composite-demo",
    title = "CU composite escapement demo",
    description = "Package-first CU/composite escapement example",
    creator = "Test Author",
    contact_name = "Test Contact",
    contact_email = "test@example.org",
    license = "Open Government Licence - Canada"
  )

  table_meta <- tibble::tibble(
    dataset_id = "cu-composite-demo",
    table_id = "cu_composite_escapement",
    file_name = "data/cu_composite_escapement.csv",
    table_label = "CU Composite Escapement",
    description = "One row per CU-year estimate.",
    observation_unit = "CU-year escapement estimate",
    observation_unit_iri = "https://w3id.org/smn/Observation",
    primary_key = "cu_id,year"
  )

  dict <- infer_dictionary(
    resources$cu_composite_escapement,
    dataset_id = "cu-composite-demo",
    table_id = "cu_composite_escapement"
  )
  dict <- fill_measurement_components(dict)
  dict$column_description <- c(
    "Conservation unit identifier.",
    "Observation year.",
    "Escapement estimate value.",
    "Estimate type code."
  )

  codes <- tibble::tibble(
    dataset_id = "cu-composite-demo",
    table_id = "cu_composite_escapement",
    column_name = "estimate_type",
    code_value = "point",
    code_label = "Point estimate",
    code_description = "Single-value escapement estimate.",
    vocabulary_iri = NA_character_,
    term_iri = NA_character_,
    term_type = NA_character_
  )

  temp_dir <- withr::local_tempdir()
  write_salmon_datapackage(
    resources,
    dataset_meta,
    table_meta,
    dict,
    codes = codes,
    path = temp_dir,
    overwrite = TRUE
  )

  result <- suppressMessages(validate_salmon_datapackage(temp_dir, require_iris = TRUE))

  expect_true(is.list(result))
  expect_equal(nrow(result$issues), 0)
  expect_true("cu_composite_escapement" %in% names(result$package$resources))
  expect_equal(nrow(result$semantic_validation$issues), 0)
})

test_that("validate_salmon_datapackage catches missing codes.csv values", {
  resources <- list(
    cu_composite_escapement = tibble::tibble(
      cu_id = c("CU-001", "CU-002"),
      year = c(2023L, 2024L),
      escapement = c(1250, 1325),
      estimate_type = c("point", "provisional")
    )
  )

  dataset_meta <- tibble::tibble(
    dataset_id = "cu-composite-demo",
    title = "CU composite escapement demo",
    description = "Package-first CU/composite escapement example",
    creator = "Test Author",
    contact_name = "Test Contact",
    contact_email = "test@example.org",
    license = "Open Government Licence - Canada"
  )

  table_meta <- tibble::tibble(
    dataset_id = "cu-composite-demo",
    table_id = "cu_composite_escapement",
    file_name = "data/cu_composite_escapement.csv",
    table_label = "CU Composite Escapement",
    description = "One row per CU-year estimate.",
    observation_unit = "CU-year escapement estimate",
    observation_unit_iri = "https://w3id.org/smn/Observation",
    primary_key = "cu_id,year"
  )

  dict <- infer_dictionary(
    resources$cu_composite_escapement,
    dataset_id = "cu-composite-demo",
    table_id = "cu_composite_escapement"
  )
  dict <- fill_measurement_components(dict)

  codes <- tibble::tibble(
    dataset_id = "cu-composite-demo",
    table_id = "cu_composite_escapement",
    column_name = "estimate_type",
    code_value = "point",
    code_label = "Point estimate",
    code_description = "Single-value escapement estimate.",
    vocabulary_iri = NA_character_,
    term_iri = NA_character_,
    term_type = NA_character_
  )

  temp_dir <- withr::local_tempdir()
  write_salmon_datapackage(
    resources,
    dataset_meta,
    table_meta,
    dict,
    codes = codes,
    path = temp_dir,
    overwrite = TRUE
  )

  expect_error(
    suppressMessages(validate_salmon_datapackage(temp_dir, require_iris = FALSE)),
    "not listed in codes.csv"
  )
})

.ms_write_semantic_validation_fixture <- function(
    dict_term_iri = "https://example.org/variable",
    table_observation_unit_iri = "https://w3id.org/smn/Observation",
    dataset_description = "Fixture for semantic validation regression tests.",
    dataset_creator = "Test Author",
    table_description = "One row per record.",
    table_observation_unit = "record",
    escapement_column_description = "Escapement count"
) {
  resources <- list(
    main = tibble::tibble(
      id = "A",
      escapement = 1250
    )
  )

  dataset_meta <- tibble::tibble(
    dataset_id = "semantic-validation-demo",
    title = "Semantic validation demo",
    description = dataset_description,
    creator = dataset_creator,
    contact_name = "Test Contact",
    contact_email = "test@example.org",
    license = "Open Government Licence - Canada"
  )

  table_meta <- tibble::tibble(
    dataset_id = "semantic-validation-demo",
    table_id = "main",
    file_name = "data/main.csv",
    table_label = "Main",
    description = table_description,
    observation_unit = table_observation_unit,
    observation_unit_iri = table_observation_unit_iri,
    primary_key = "id"
  )

  dict <- infer_dictionary(
    resources$main,
    dataset_id = "semantic-validation-demo",
    table_id = "main"
  )
  dict <- fill_measurement_components(dict)
  dict$term_iri[dict$column_name == "escapement"] <- dict_term_iri
  dict$column_description[dict$column_name == "escapement"] <- escapement_column_description
  # Every column gets a description, so the only defect in a given test is the
  # one that test injects. Leaving `id` blank meant the metadata defaults filled
  # it with a `MISSING DESCRIPTION:` placeholder, and once unresolved
  # placeholders became a validation issue (#77) that fired first and masked the
  # failure each test was actually asserting.
  dict$column_description[dict$column_name == "id"] <- "Record identifier." 

  temp_dir <- tempfile("semantic-validation-")
  dir.create(temp_dir, recursive = TRUE)
  write_salmon_datapackage(
    resources,
    dataset_meta,
    table_meta,
    dict,
    path = temp_dir,
    overwrite = TRUE
  )

  temp_dir
}

test_that("validate_salmon_datapackage warns cleanly for semantic issues without crashing cli pluralization", {
  pkg_path <- .ms_write_semantic_validation_fixture(
    dict_term_iri = "http://w3id.org/salmon/SpawnerAbundance"
  )

  expect_warning(
    result <- suppressMessages(validate_salmon_datapackage(pkg_path, require_iris = FALSE)),
    "reported 1 semantic issue"
  )

  expect_true(is.list(result))
  expect_true(any(grepl("legacy SMN namespace", result$semantic_validation$issues$message, fixed = TRUE)))
})

test_that("validate_salmon_datapackage fails final validation when tables.csv keeps REVIEW-prefixed IRIs", {
  pkg_path <- .ms_write_semantic_validation_fixture(
    table_observation_unit_iri = "REVIEW: https://w3id.org/smn/Observation"
  )

  expect_error(
    suppressMessages(validate_salmon_datapackage(pkg_path, require_iris = TRUE)),
    "REVIEW-prefixed IRI"
  )
})

test_that("validate_salmon_datapackage fails final validation on unresolved metadata placeholders", {
  pkg_path <- .ms_write_semantic_validation_fixture(
    dataset_description = "MISSING DESCRIPTION: describe the dataset before final review.",
    dataset_creator = "MISSING METADATA: add creator, team, or originating program.",
    table_description = "MISSING DESCRIPTION: describe what each row means.",
    table_observation_unit = "MISSING METADATA: describe the observation unit.",
    escapement_column_description = "MISSING DESCRIPTION: define what 'escapement' means."
  )

  expect_error(
    suppressMessages(validate_salmon_datapackage(pkg_path, require_iris = TRUE)),
    "unresolved review placeholder"
  )
})

test_that("validate_salmon_datapackage fails final validation when tables.csv observation_unit_iri is blank", {
  pkg_path <- .ms_write_semantic_validation_fixture(
    table_observation_unit_iri = ""
  )

  expect_error(
    suppressMessages(validate_salmon_datapackage(pkg_path, require_iris = TRUE)),
    "observation_unit_iri is blank"
  )
})

test_that("validate_salmon_datapackage keeps review-ready placeholder packages valid in non-strict mode", {
  pkg_path <- .ms_write_semantic_validation_fixture(
    table_observation_unit_iri = "",
    dataset_description = "MISSING DESCRIPTION: describe the dataset before final review.",
    table_observation_unit = "MISSING METADATA: describe the observation unit.",
    escapement_column_description = "MISSING DESCRIPTION: define what 'escapement' means."
  )

  expect_no_error(
    suppressMessages(validate_salmon_datapackage(pkg_path, require_iris = FALSE))
  )
})

.ms_write_composite_guardrail_fixture <- function(
    route_value = NULL,
    datapackage_route_value = NULL,
    populate_signal_column = FALSE
) {
  resources <- list(
    cu_timeseries = tibble::tibble(
      cu_id = c("CU-001", "CU-002"),
      year = c(2023L, 2024L),
      escapement = c(1250, 1325),
      SPN_ABD_WILD = if (populate_signal_column) c("present", NA_character_) else c(NA_character_, NA_character_),
      SPN_TREND_WILD = c(NA_character_, NA_character_),
      RAPID_STATUS = c(NA_character_, NA_character_)
    )
  )

  dataset_meta <- tibble::tibble(
    dataset_id = "cu-composite-guardrail",
    title = "CU composite guardrail demo",
    description = "Fixture for composite-intent package validation.",
    creator = "Test Author",
    contact_name = "Test Contact",
    contact_email = "test@example.org",
    license = "Open Government Licence - Canada"
  )
  if (!is.null(route_value)) {
    dataset_meta$route <- route_value
  }

  table_meta <- tibble::tibble(
    dataset_id = "cu-composite-guardrail",
    table_id = "cu_timeseries",
    file_name = "data/cu_timeseries.csv",
    table_label = "CU Timeseries",
    description = "CU timeseries values for validation tests.",
    observation_unit = "CU-year observation",
    observation_unit_iri = "https://w3id.org/smn/Observation",
    primary_key = "cu_id,year"
  )

  dict <- infer_dictionary(
    resources$cu_timeseries,
    dataset_id = "cu-composite-guardrail",
    table_id = "cu_timeseries"
  )
  dict <- fill_measurement_components(dict)

  temp_dir <- tempfile("composite-guardrail-")
  dir.create(temp_dir, recursive = TRUE)
  write_salmon_datapackage(
    resources,
    dataset_meta,
    table_meta,
    dict,
    path = temp_dir,
    overwrite = TRUE
  )

  if (!is.null(datapackage_route_value)) {
    datapackage_path <- file.path(temp_dir, "datapackage.json")
    datapackage <- jsonlite::read_json(datapackage_path, simplifyVector = FALSE)
    datapackage$route <- datapackage_route_value
    jsonlite::write_json(
      datapackage,
      datapackage_path,
      pretty = TRUE,
      auto_unbox = TRUE,
      null = "null"
    )
  }

  temp_dir
}

test_that("validate_salmon_datapackage catches explicit composite route metadata without WSP signals", {
  pkg_path <- .ms_write_composite_guardrail_fixture(route_value = "cu_composite")

  expect_error(
    suppressMessages(validate_salmon_datapackage(pkg_path, require_iris = FALSE)),
    "Explicit composite route intent detected"
  )
})

test_that("validate_salmon_datapackage allows explicit composite route metadata when WSP signals are populated", {
  pkg_path <- .ms_write_composite_guardrail_fixture(
    route_value = "cu_composite",
    populate_signal_column = TRUE
  )

  result <- suppressWarnings(
    suppressMessages(validate_salmon_datapackage(pkg_path, require_iris = FALSE))
  )

  expect_equal(nrow(result$issues), 0)
  expect_true("cu_timeseries" %in% names(result$package$resources))
})

test_that("validate_salmon_datapackage does not require WSP signals without explicit composite intent", {
  pkg_path <- .ms_write_composite_guardrail_fixture()

  result <- suppressWarnings(
    suppressMessages(validate_salmon_datapackage(pkg_path, require_iris = FALSE))
  )

  expect_equal(nrow(result$issues), 0)
})

test_that("validate_salmon_datapackage catches datapackage route hints without WSP signals", {
  pkg_path <- .ms_write_composite_guardrail_fixture(
    datapackage_route_value = "cu_composite"
  )

  expect_error(
    suppressMessages(validate_salmon_datapackage(pkg_path, require_iris = FALSE)),
    "Explicit composite route intent detected"
  )
})

test_that("write_salmon_datapackage scopes the descriptor schema to its own dataset", {
  # `dplyr::filter(.data$dataset_id == dataset_id)` with a same-named local is
  # a data-mask no-op, so another dataset's columns leaked into
  # datapackage.json for any table_id shared across datasets.
  temp_dir <- withr::local_tempdir()

  dict <- dplyr::bind_rows(
    test_dictionary(
      dataset_id = "keep-me", table_id = "obs",
      column_name = "count", column_label = "count",
      column_role = "measurement", value_type = "integer"
    ),
    test_dictionary(
      dataset_id = "other-dataset", table_id = "obs",
      column_name = "leaked_column", column_label = "leaked_column",
      column_role = "measurement", value_type = "integer"
    )
  )
  dict <- fill_measurement_components(dict)

  dataset_meta <- tibble::tibble(
    dataset_id = "keep-me",
    title = "Scoped dataset",
    description = "Scoped dataset description",
    spec_version = NA_character_
  )
  table_meta <- tibble::tibble(
    dataset_id = "keep-me",
    table_id = "obs",
    table_label = "Observations",
    table_description = "Observation rows",
    file_name = NA_character_,
    observation_unit = NA_character_,
    observation_unit_iri = NA_character_,
    primary_key = NA_character_
  )

  write_salmon_datapackage(
    resources = list(obs = data.frame(count = 1:2)),
    dataset_meta = dataset_meta,
    table_meta = table_meta,
    dict = dict,
    path = temp_dir,
    overwrite = TRUE
  )

  descriptor <- jsonlite::read_json(file.path(temp_dir, "datapackage.json"))
  obs <- Filter(function(r) identical(r$name, "obs"), descriptor$resources)[[1]]
  field_names <- vapply(obs$schema$fields, function(f) f$name, character(1))

  expect_true("count" %in% field_names)
  expect_false("leaked_column" %in% field_names)
})

test_that("descriptor profile and rules URIs come from the loaded schema bundle", {
  temp_dir <- withr::local_tempdir()
  schema <- metasalmon:::.ms_load_sdp_schema(quiet = TRUE)

  df <- data.frame(count = 1:2)
  dict <- fill_measurement_components(
    infer_dictionary(df, dataset_id = "uri-1", table_id = "obs")
  )

  write_salmon_datapackage(
    resources = list(obs = df),
    dataset_meta = tibble::tibble(
      dataset_id = "uri-1", title = "URI test",
      description = "Descriptor identity", spec_version = NA_character_
    ),
    table_meta = tibble::tibble(
      dataset_id = "uri-1", table_id = "obs", table_label = "Observations",
      table_description = "Rows", file_name = NA_character_,
      observation_unit = NA_character_, observation_unit_iri = NA_character_,
      primary_key = NA_character_
    ),
    dict = dict,
    path = temp_dir,
    overwrite = TRUE
  )

  descriptor <- jsonlite::read_json(file.path(temp_dir, "datapackage.json"))
  expect_identical(descriptor$profile, schema$profile_uri)
  expect_identical(descriptor$sdp$profile, schema$profile_uri)
  expect_identical(descriptor$sdp$rules, schema$rules_uri)

  # dataset.csv and datapackage.json must agree on the spec version; they used
  # to read different bundles.
  dataset_csv <- readr::read_csv(
    file.path(temp_dir, "metadata", "dataset.csv"),
    col_types = readr::cols(.default = readr::col_character()),
    show_col_types = FALSE
  )
  expect_identical(dataset_csv$spec_version[1], descriptor$sdp$specVersion)
})

test_that("a package declaring the legacy SDP profile URI still validates", {
  # Packages written before the upstream identifier migration must keep reading
  # and validating cleanly.
  temp_dir <- withr::local_tempdir()
  df <- data.frame(count = 1:2)
  dict <- fill_measurement_components(
    infer_dictionary(df, dataset_id = "legacy-1", table_id = "obs")
  )

  write_salmon_datapackage(
    resources = list(obs = df),
    dataset_meta = tibble::tibble(
      dataset_id = "legacy-1", title = "Legacy URI",
      description = "Legacy profile identifier", spec_version = NA_character_
    ),
    table_meta = tibble::tibble(
      dataset_id = "legacy-1", table_id = "obs", table_label = "Observations",
      table_description = "Rows", file_name = NA_character_,
      observation_unit = NA_character_, observation_unit_iri = NA_character_,
      primary_key = NA_character_
    ),
    dict = dict,
    path = temp_dir,
    overwrite = TRUE
  )

  legacy_uri <- paste0(
    "https://dfo-pacific-science.github.io/smn-data-pkg/profiles/",
    "salmon-data-package/v0.2/profile.json"
  )
  descriptor_path <- file.path(temp_dir, "datapackage.json")
  descriptor <- jsonlite::read_json(descriptor_path)
  descriptor$profile <- legacy_uri
  descriptor$sdp$profile <- legacy_uri
  jsonlite::write_json(descriptor, descriptor_path, auto_unbox = TRUE, pretty = TRUE)

  result <- validate_salmon_datapackage(temp_dir)
  expect_equal(nrow(result$issues), 0L)
})

# Shared fixture for the rewrite-preservation tests below.
.ms_test_write_minimal_package <- function(path, tables = c("obs"), codes = NULL) {
  resources <- stats::setNames(
    lapply(tables, function(x) data.frame(count = 1:2)),
    tables
  )
  dict <- dplyr::bind_rows(lapply(tables, function(tbl) {
    fill_measurement_components(
      infer_dictionary(data.frame(count = 1:2), dataset_id = "keep-1", table_id = tbl)
    )
  }))
  table_meta <- tibble::tibble(
    dataset_id = "keep-1",
    table_id = tables,
    table_label = tables,
    table_description = "Rows",
    file_name = NA_character_,
    observation_unit = NA_character_,
    observation_unit_iri = NA_character_,
    primary_key = NA_character_
  )
  write_salmon_datapackage(
    resources = resources,
    dataset_meta = tibble::tibble(
      dataset_id = "keep-1", title = "Preservation",
      description = "Sidecar preservation", spec_version = NA_character_
    ),
    table_meta = table_meta,
    dict = dict,
    codes = codes,
    path = path,
    overwrite = TRUE
  )
}

test_that("rewriting a package preserves reviewed sidecars", {
  temp_dir <- withr::local_tempdir()
  .ms_test_write_minimal_package(temp_dir)

  sidecars <- c(
    "metadata/semantic/example.sssom.tsv",
    "metadata/semantic/mapping-sets.json",
    "metadata/semantic/measurement-decompositions.csv",
    "metadata/semantic/measurement-decompositions.json",
    "metadata/semantic_vocabulary.csv",
    "metadata/eml-mapping.yml",
    "metadata/eml.xml",
    "metadata/metadata-edh-hnap.xml",
    "reviewed_semantic_selections.csv",
    "README-review.txt",
    "publication/knb-manifest.json"
  )
  for (relative in sidecars) {
    full <- file.path(temp_dir, relative)
    dir.create(dirname(full), recursive = TRUE, showWarnings = FALSE)
    writeLines(paste("reviewed content for", relative), full)
  }
  before <- vapply(sidecars, function(r) {
    digest::digest(file.path(temp_dir, r), file = TRUE)
  }, character(1))

  .ms_test_write_minimal_package(temp_dir)

  after <- vapply(sidecars, function(r) {
    if (!file.exists(file.path(temp_dir, r))) return(NA_character_)
    digest::digest(file.path(temp_dir, r), file = TRUE)
  }, character(1))

  expect_identical(after, before)
})

test_that("prune = TRUE restores the full wipe and requires overwrite", {
  temp_dir <- withr::local_tempdir()
  .ms_test_write_minimal_package(temp_dir)
  dir.create(file.path(temp_dir, "metadata", "semantic"), recursive = TRUE, showWarnings = FALSE)
  writeLines("reviewed", file.path(temp_dir, "metadata", "semantic", "example.sssom.tsv"))

  expect_error(
    .ms_prepare_package_write_dir(temp_dir, overwrite = FALSE, prune = TRUE),
    "requires"
  )

  resources <- list(obs = data.frame(count = 1:2))
  dict <- fill_measurement_components(
    infer_dictionary(data.frame(count = 1:2), dataset_id = "keep-1", table_id = "obs")
  )
  write_salmon_datapackage(
    resources = resources,
    dataset_meta = tibble::tibble(
      dataset_id = "keep-1", title = "Preservation",
      description = "Sidecar preservation", spec_version = NA_character_
    ),
    table_meta = tibble::tibble(
      dataset_id = "keep-1", table_id = "obs", table_label = "obs",
      table_description = "Rows", file_name = NA_character_,
      observation_unit = NA_character_, observation_unit_iri = NA_character_,
      primary_key = NA_character_
    ),
    dict = dict,
    path = temp_dir,
    overwrite = TRUE,
    prune = TRUE
  )

  expect_false(file.exists(file.path(temp_dir, "metadata", "semantic", "example.sssom.tsv")))
})

test_that("rewriting drops a data resource no longer declared in tables.csv", {
  temp_dir <- withr::local_tempdir()
  .ms_test_write_minimal_package(temp_dir, tables = c("obs", "extra"))
  expect_true(file.exists(file.path(temp_dir, "data", "extra.csv")))

  expect_message(
    .ms_test_write_minimal_package(temp_dir, tables = "obs"),
    "no longer declared"
  )

  expect_false(file.exists(file.path(temp_dir, "data", "extra.csv")))
  expect_true(file.exists(file.path(temp_dir, "data", "obs.csv")))
})

test_that("dropping codes removes a stale codes.csv and leaves validation clean", {
  temp_dir <- withr::local_tempdir()
  codes <- tibble::tibble(
    dataset_id = "keep-1",
    table_id = "obs",
    column_name = "count",
    code_value = c("1", "2"),
    code_label = c("One", "Two"),
    code_description = NA_character_
  )
  .ms_test_write_minimal_package(temp_dir, codes = codes)
  expect_true(file.exists(file.path(temp_dir, "metadata", "codes.csv")))

  .ms_test_write_minimal_package(temp_dir, codes = NULL)

  expect_false(file.exists(file.path(temp_dir, "metadata", "codes.csv")))
  expect_equal(nrow(validate_salmon_datapackage(temp_dir)$issues), 0L)
})

test_that("create_sdp accepts prune without tripping the dots validator", {
  temp_dir <- file.path(withr::local_tempdir(), "pkg")
  expect_no_error(
    suppressMessages(suppressWarnings(create_sdp(
      data.frame(count = 1:2),
      path = temp_dir,
      dataset_id = "prune-1",
      table_id = "obs",
      seed_semantics = FALSE,
      check_updates = FALSE,
      overwrite = TRUE,
      prune = FALSE
    )))
  )
})

test_that("read_salmon_datapackage honours the declared value_type", {
  temp_dir <- withr::local_tempdir()
  df <- data.frame(
    pct = c("0.10", "0.25"),
    big = c("100000", "250000"),
    flag = c(TRUE, FALSE),
    day = as.Date(c("2026-01-01", "2026-02-01")),
    stamp = as.POSIXct(c("2026-01-01 08:30:00", "2026-02-01 09:45:00"), tz = "UTC"),
    blank = NA_character_,
    stringsAsFactors = FALSE
  )
  dict <- fill_measurement_components(
    infer_dictionary(df, dataset_id = "types-1", table_id = "obs")
  )

  write_salmon_datapackage(
    resources = list(obs = df),
    dataset_meta = tibble::tibble(
      dataset_id = "types-1", title = "Types", description = "Type round trip",
      spec_version = NA_character_
    ),
    table_meta = tibble::tibble(
      dataset_id = "types-1", table_id = "obs", table_label = "obs",
      table_description = "Rows", file_name = NA_character_,
      observation_unit = NA_character_, observation_unit_iri = NA_character_,
      primary_key = NA_character_
    ),
    dict = dict,
    path = temp_dir,
    overwrite = TRUE
  )

  back <- suppressMessages(read_salmon_datapackage(temp_dir))$resources$obs

  # Character columns stay exactly as written; readr guessing turned these into
  # 0.1 and 1e+05.
  expect_identical(back$pct, c("0.10", "0.25"))
  expect_identical(back$big, c("100000", "250000"))
  expect_type(back$flag, "logical")
  expect_s3_class(back$day, "Date")
  expect_s3_class(back$stamp, "POSIXct")
  # An all-NA character column is declared "string", so it must not become logical.
  expect_type(back$blank, "character")
})

test_that("validate_salmon_datapackage compares code values through the declared type", {
  temp_dir <- withr::local_tempdir()
  df <- data.frame(depth_code = c("0.10", "0.20"), stringsAsFactors = FALSE)
  dict <- fill_measurement_components(
    infer_dictionary(df, dataset_id = "codes-1", table_id = "obs")
  )
  dict$column_role <- "categorical"

  codes <- tibble::tibble(
    dataset_id = "codes-1", table_id = "obs", column_name = "depth_code",
    code_value = c("0.10", "0.20"),
    code_label = c("Shallow", "Deep"),
    code_description = NA_character_
  )

  write_salmon_datapackage(
    resources = list(obs = df),
    dataset_meta = tibble::tibble(
      dataset_id = "codes-1", title = "Codes", description = "Typed code compare",
      spec_version = NA_character_
    ),
    table_meta = tibble::tibble(
      dataset_id = "codes-1", table_id = "obs", table_label = "obs",
      table_description = "Rows", file_name = NA_character_,
      observation_unit = NA_character_, observation_unit_iri = NA_character_,
      primary_key = NA_character_
    ),
    dict = dict,
    codes = codes,
    path = temp_dir,
    overwrite = TRUE
  )

  expect_equal(nrow(validate_salmon_datapackage(temp_dir)$issues), 0L)
})

test_that("canonical value tokens are symmetric across declared types", {
  canon <- metasalmon:::.ms_canonical_value_tokens

  expect_identical(canon(c(0.1, 100000), "number"), c("0.1", "100000"))
  expect_identical(canon(c("0.10", "1e+05"), "number"), c("0.1", "100000"))
  expect_identical(canon(100000L, "integer"), "100000")
  expect_identical(canon(c(TRUE, FALSE), "boolean"), c("TRUE", "FALSE"))
  expect_identical(canon(c("true", "F"), "boolean"), c("TRUE", "FALSE"))
  expect_identical(canon(as.Date("2026-01-02"), "date"), "2026-01-02")
  expect_identical(canon("2026-01-02", "date"), "2026-01-02")
  # Strings are untouched, and unparseable values keep their original text so a
  # real mismatch still reads as one.
  expect_identical(canon(c(" a ", "b"), "string"), c("a", "b"))
  expect_identical(canon("unknown", "number"), "unknown")

  # Element-wise formatting: a vector-wise format() would render 0.5 differently
  # depending on what else is in the vector.
  expect_identical(canon(c(0.5, 1 / 3), "number")[[1]], canon(0.5, "number"))
})

test_that("a dictionary column missing from the data file reads without a parser warning", {
  temp_dir <- withr::local_tempdir()
  df <- data.frame(count = 1:2)
  dict <- fill_measurement_components(
    infer_dictionary(data.frame(count = 1:2, absent = c(1.5, 2.5)),
                     dataset_id = "spec-1", table_id = "obs")
  )

  write_salmon_datapackage(
    resources = list(obs = df),
    dataset_meta = tibble::tibble(
      dataset_id = "spec-1", title = "Spec", description = "Absent column",
      spec_version = NA_character_
    ),
    table_meta = tibble::tibble(
      dataset_id = "spec-1", table_id = "obs", table_label = "obs",
      table_description = "Rows", file_name = NA_character_,
      observation_unit = NA_character_, observation_unit_iri = NA_character_,
      primary_key = NA_character_
    ),
    dict = dict,
    path = temp_dir,
    overwrite = TRUE
  )

  expect_no_warning(suppressMessages(read_salmon_datapackage(temp_dir)))

  # The structured issue must still fire; it is reported as an abort.
  expect_error(
    validate_salmon_datapackage(temp_dir),
    "missing dictionary columns"
  )
})

test_that("a value that fails its declared type is preserved and reported", {
  # Regression: reading with the declared collector turned the offending token
  # into NA with only a readr warning, validation dropped the NA as blank, and a
  # data value absent from codes.csv reached "validation passed".
  temp_dir <- withr::local_tempdir()
  df <- data.frame(depth_code = c("0.10", "0.20", "unknown"), stringsAsFactors = FALSE)
  dict <- fill_measurement_components(
    infer_dictionary(df, dataset_id = "mismatch-1", table_id = "obs")
  )
  dict$value_type <- "number"
  dict$column_role <- "categorical"

  codes <- tibble::tibble(
    dataset_id = "mismatch-1", table_id = "obs", column_name = "depth_code",
    code_value = c("0.10", "0.20"), code_label = c("Shallow", "Deep"),
    code_description = NA_character_
  )

  suppressWarnings(write_salmon_datapackage(
    resources = list(obs = df),
    dataset_meta = tibble::tibble(
      dataset_id = "mismatch-1", title = "Mismatch",
      description = "Declared type not satisfied", spec_version = NA_character_
    ),
    table_meta = tibble::tibble(
      dataset_id = "mismatch-1", table_id = "obs", table_label = "obs",
      table_description = "Rows", file_name = NA_character_,
      observation_unit = NA_character_, observation_unit_iri = NA_character_,
      primary_key = NA_character_
    ),
    dict = dict,
    codes = codes,
    path = temp_dir,
    overwrite = TRUE
  ))

  back <- suppressMessages(suppressWarnings(read_salmon_datapackage(temp_dir)))
  # The raw token survives, so the code-value check can still see it.
  expect_true("unknown" %in% as.character(back$resources$obs$depth_code))

  # Both the declaration mismatch and the unlisted value are reported.
  expect_error(validate_salmon_datapackage(temp_dir), "unparseable as that type")
  expect_error(validate_salmon_datapackage(temp_dir), "not listed in codes.csv")
})

test_that("a declared integer beyond exact double precision keeps its exact token", {
  # 9007199254740993 and 9007199254740992 both round to 2^53 as doubles, so the
  # first was returned as the second and the codes comparison saw one value.
  temp_dir <- withr::local_tempdir()
  df <- data.frame(
    tag_id = c("9007199254740993", "9007199254740992"),
    stringsAsFactors = FALSE
  )
  dict <- fill_measurement_components(
    infer_dictionary(df, dataset_id = "big-1", table_id = "obs")
  )
  dict$value_type <- "integer"
  dict$column_role <- "categorical"
  codes <- tibble::tibble(
    dataset_id = "big-1", table_id = "obs", column_name = "tag_id",
    code_value = "9007199254740992", code_label = "Known",
    code_description = NA_character_
  )

  suppressWarnings(write_salmon_datapackage(
    resources = list(obs = df),
    dataset_meta = tibble::tibble(
      dataset_id = "big-1", title = "Big ids",
      description = "Beyond 2^53", spec_version = NA_character_
    ),
    table_meta = tibble::tibble(
      dataset_id = "big-1", table_id = "obs", table_label = "obs",
      table_description = "Rows", file_name = NA_character_,
      observation_unit = NA_character_, observation_unit_iri = NA_character_,
      primary_key = NA_character_
    ),
    dict = dict, codes = codes, path = temp_dir, overwrite = TRUE
  ))

  back <- suppressMessages(suppressWarnings(read_salmon_datapackage(temp_dir)))
  expect_identical(as.character(back$resources$obs$tag_id), df$tag_id)
  expect_error(validate_salmon_datapackage(temp_dir), "9007199254740993")
})

test_that("a data column literally named .default does not abort the reader", {
  temp_dir <- withr::local_tempdir()
  df <- data.frame(a = c("x", "y"), n = c(1, 2), stringsAsFactors = FALSE)
  names(df) <- c(".default", "n")
  dict <- fill_measurement_components(
    infer_dictionary(df, dataset_id = "dflt-1", table_id = "obs")
  )

  suppressWarnings(write_salmon_datapackage(
    resources = list(obs = df),
    dataset_meta = tibble::tibble(
      dataset_id = "dflt-1", title = "Reserved name",
      description = "Column named .default", spec_version = NA_character_
    ),
    table_meta = tibble::tibble(
      dataset_id = "dflt-1", table_id = "obs", table_label = "obs",
      table_description = "Rows", file_name = NA_character_,
      observation_unit = NA_character_, observation_unit_iri = NA_character_,
      primary_key = NA_character_
    ),
    dict = dict, path = temp_dir, overwrite = TRUE
  ))

  back <- suppressMessages(suppressWarnings(read_salmon_datapackage(temp_dir)))
  expect_true(".default" %in% names(back$resources$obs))
  # This fixture declares `string`, so character is the declared type -- the
  # numeric case is covered by the direct-reader test below.
  expect_identical(dict$value_type[dict$column_name == ".default"], "string")
  expect_type(back$resources$obs$.default, "character")
})

test_that("a .default column still reports a value that fails its declared type", {
  # The first fix for the `cols()` name collision excluded this column from the
  # spec, which silently exempted it from type checking too.
  file_path <- withr::local_tempfile(fileext = ".csv")
  writeLines(c(".default,n", "1.5,1", "unknown,2"), file_path)
  table_dict <- tibble::tibble(
    column_name = c(".default", "n"),
    value_type = c("number", "number")
  )

  parsed <- suppressWarnings(.ms_read_resource_csv(file_path, table_dict))

  expect_type(parsed$.default, "character")          # raw token preserved
  expect_true("unknown" %in% parsed$.default)
  # And with a clean numeric column the reserved spelling does get its declared
  # type, rather than being dropped to the character fallback.
  clean <- withr::local_tempfile(fileext = ".csv")
  writeLines(c(".default,n", "1.5,1", "2.5,2"), clean)
  expect_type(.ms_read_resource_csv(clean, table_dict)$.default, "double")
  mismatches <- attr(parsed, "ms_value_type_mismatches")
  expect_length(mismatches, 1L)
  expect_identical(mismatches[[1]]$column, ".default")
  expect_identical(mismatches[[1]]$declared, "number")
})

test_that("a previously declared resource outside data/ is removed at its real path", {
  # Forcing prior declarations through .ms_force_data_subdir() left the true
  # orphan behind and targeted an unrelated data/ file of the same basename.
  temp_dir <- withr::local_tempdir()
  .ms_test_write_minimal_package(temp_dir)

  tables_path <- file.path(temp_dir, "metadata", "tables.csv")
  tables <- readr::read_csv(
    tables_path,
    col_types = readr::cols(.default = readr::col_character()),
    show_col_types = FALSE
  )
  tables$file_name <- "exports/old.csv"
  readr::write_csv(tables, tables_path, na = "")
  dir.create(file.path(temp_dir, "exports"), showWarnings = FALSE)
  writeLines("a\n1", file.path(temp_dir, "exports", "old.csv"))

  expect_identical(.ms_previous_declared_data_paths(temp_dir), "exports/old.csv")
})

test_that("rewriting refuses to delete through a symlinked managed directory", {
  # file.exists() follows links, so a `metadata/` replaced by a symlink made
  # every managed child resolve outside the package and unlink() delete the
  # target. The KNB archive already fails closed on symlinked path components;
  # the writer must too.
  skip_on_os("windows")
  base <- withr::local_tempdir()
  pkg <- file.path(base, "pkg")
  outside <- file.path(base, "outside")
  dir.create(file.path(pkg, "data"), recursive = TRUE)
  dir.create(outside, recursive = TRUE)
  writeLines("metasalmon-owned", file.path(pkg, ".metasalmon-package"))
  writeLines(c("dataset_id", "d1"), file.path(outside, "dataset.csv"))
  writeLines("precious external file", file.path(outside, "tables.csv"))
  file.symlink(outside, file.path(pkg, "metadata"))

  managed <- .ms_package_managed_paths(pkg)
  expect_error(
    .ms_prepare_package_write_dir(pkg, overwrite = TRUE, managed_paths = managed),
    "symbolic-link path component"
  )
  expect_true(file.exists(file.path(outside, "tables.csv")))
})

test_that("an ordinary package directory is still updated in place", {
  # The symlink guard must not block the normal managed-update path.
  base <- withr::local_tempdir()
  pkg <- file.path(base, "pkg")
  dir.create(file.path(pkg, "metadata"), recursive = TRUE)
  writeLines("metasalmon-owned", file.path(pkg, ".metasalmon-package"))
  writeLines(c("dataset_id", "d1"), file.path(pkg, "metadata", "dataset.csv"))
  writeLines("keep me", file.path(pkg, "README-review.txt"))

  managed <- .ms_package_managed_paths(pkg)
  expect_no_error(
    .ms_prepare_package_write_dir(pkg, overwrite = TRUE, managed_paths = managed)
  )
  expect_false(file.exists(file.path(pkg, "metadata", "dataset.csv")))
  expect_true(file.exists(file.path(pkg, "README-review.txt")))
})

test_that("a fractional token in a declared integer column is reported", {
  # `col_double()` backs a declared `integer` (because `col_integer()` NAs past
  # 2^31), so `1.5` parses cleanly and readr raises no problem. Nothing else
  # checked wholeness, so it reached "validation passed" even with 1.5 listed
  # in codes.csv.
  file_path <- withr::local_tempfile(fileext = ".csv")
  writeLines(c("n", "1.5", "2"), file_path)
  table_dict <- tibble::tibble(column_name = "n", value_type = "integer")

  parsed <- suppressWarnings(.ms_read_resource_csv(file_path, table_dict))

  expect_type(parsed$n, "character")           # exact token preserved
  mismatches <- attr(parsed, "ms_value_type_mismatches")
  expect_length(mismatches, 1L)
  expect_identical(mismatches[[1]]$reason, "not a whole number")
  expect_identical(mismatches[[1]]$examples, "1.5")
})

test_that("valid integer columns are not flagged as mismatches", {
  # The wholeness check must not fire on ordinary data, including blanks and
  # negatives, and must not apply to a declared `number`.
  table_dict <- tibble::tibble(column_name = "n", value_type = "integer")
  whole <- withr::local_tempfile(fileext = ".csv")
  writeLines(c("n", "1", "-3", "", "0"), whole)
  parsed <- .ms_read_resource_csv(whole, table_dict)
  expect_type(parsed$n, "double")
  expect_null(attr(parsed, "ms_value_type_mismatches"))

  decimal <- withr::local_tempfile(fileext = ".csv")
  writeLines(c("n", "1.5"), decimal)
  parsed_number <- .ms_read_resource_csv(
    decimal,
    tibble::tibble(column_name = "n", value_type = "number")
  )
  expect_type(parsed_number$n, "double")
  expect_null(attr(parsed_number, "ms_value_type_mismatches"))
})

test_that("a number column beyond exact precision keeps its exact token", {
  # `number` shares the double collector with `integer`, so it collapses the
  # same way past 2^53. The declaration does not make that acceptable when the
  # value is also a code.
  file_path <- withr::local_tempfile(fileext = ".csv")
  writeLines(c("n", "9007199254740993", "9007199254740992"), file_path)

  parsed <- .ms_read_resource_csv(
    file_path,
    tibble::tibble(column_name = "n", value_type = "number")
  )

  expect_identical(parsed$n, c("9007199254740993", "9007199254740992"))
  mismatches <- attr(parsed, "ms_value_type_mismatches")
  expect_length(mismatches, 1L)
  expect_identical(mismatches[[1]]$reason, "beyond exact numeric precision")
})

test_that("datetime tokens finer than the representation keep their exact text", {
  # POSIXct is a double, so `col_datetime()` discards sub-resolution digits
  # before any value-level check could run. Declared datetime columns are
  # therefore collected as text and converted only when that is faithful.
  fine <- withr::local_tempfile(fileext = ".csv")
  writeLines(
    c("t", "2026-01-01T00:00:00.100000000Z", "2026-01-01T00:00:00.100000010Z"),
    fine
  )
  table_dict <- tibble::tibble(column_name = "t", value_type = "datetime")

  parsed <- .ms_read_resource_csv(fine, table_dict)
  expect_type(parsed$t, "character")
  expect_identical(parsed$t[[2]], "2026-01-01T00:00:00.100000010Z")
  expect_identical(
    attr(parsed, "ms_value_type_mismatches")[[1]]$reason,
    "finer than the datetime representation can hold"
  )

  # Ordinary timestamps, including microseconds and blanks, still become POSIXct.
  ordinary <- withr::local_tempfile(fileext = ".csv")
  writeLines(c("t", "2026-01-01T08:30:00Z", "2026-01-01T09:00:00.123456Z", ""), ordinary)
  clean <- .ms_read_resource_csv(ordinary, table_dict)
  expect_s3_class(clean$t, "POSIXct")
  expect_null(attr(clean, "ms_value_type_mismatches"))
})

test_that("an unparseable datetime token is still reported", {
  # Holding datetime columns as text also bypasses readr's problem reporting,
  # so this needs its own detection or the value silently becomes NA.
  file_path <- withr::local_tempfile(fileext = ".csv")
  writeLines(c("t", "not-a-date"), file_path)

  parsed <- .ms_read_resource_csv(
    file_path,
    tibble::tibble(column_name = "t", value_type = "datetime")
  )

  expect_identical(parsed$t, "not-a-date")
  expect_identical(
    attr(parsed, "ms_value_type_mismatches")[[1]]$reason,
    "unparseable as that type"
  )
})

test_that("declared-type fidelity is enforced from the raw token, uniformly", {
  # One mechanism replaces four special-case detectors: the column is read as
  # text and converted only when the conversion is faithful, judged against the
  # original token. This table is the contract.
  check <- function(tokens, value_type) {
    file_path <- withr::local_tempfile(fileext = ".csv")
    writeLines(c("v", tokens), file_path)
    parsed <- .ms_read_resource_csv(
      file_path,
      tibble::tibble(column_name = "v", value_type = value_type)
    )
    mismatches <- attr(parsed, "ms_value_type_mismatches")
    if (is.null(mismatches)) NA_character_ else mismatches[[1]]$reason
  }

  # Precision a double cannot hold, at any magnitude — not just past 2^53.
  expect_identical(check(c("0.10000000000000001", "0.1"), "number"), "beyond exact numeric precision")
  expect_identical(check("9007199254740993", "number"), "beyond exact numeric precision")
  expect_identical(check("9007199254740993", "integer"), "beyond exact numeric precision")
  expect_identical(check(c("1.5", "2"), "integer"), "not a whole number")
  expect_identical(check("2026-01-01T00:00:00.100000010Z", "datetime"),
                   "finer than the datetime representation can hold")
  # Unparseable tokens, including types the earlier detectors never covered.
  expect_identical(check(c("1.5", "unknown"), "number"), "unparseable as that type")
  expect_identical(check("not-a-date", "datetime"), "unparseable as that type")
  expect_identical(check("yes-ish", "boolean"), "unparseable as that type")

  # Ordinary data must not be flagged. Trailing and leading zeros, exponent
  # form, blanks, and exactly 15 significant digits are all fine.
  expect_true(is.na(check(c("1", "-3", "", "0"), "integer")))
  expect_true(is.na(check(c("1.5", "0.10", "100000", "1e5"), "number")))
  expect_true(is.na(check("123456789.123456", "number")))
  expect_true(is.na(check(c("2026-01-01T08:30:00Z", "2026-01-01T09:00:00.123456Z", ""), "datetime")))
  expect_true(is.na(check(c("2026-01-01", ""), "date")))
  expect_true(is.na(check(c("TRUE", "false", ""), "boolean")))
})

test_that("create_sdp-owned outputs are containment-checked before writing", {
  # These are deliberately absent from managed_paths so a rewrite preserves
  # them, which also meant they escaped the symlink check: a symlinked
  # README-review.txt was followed and an external file truncated.
  skip_on_os("windows")
  base <- withr::local_tempdir()
  pkg <- file.path(base, "pkg")
  outside <- file.path(base, "outside")
  dir.create(pkg, recursive = TRUE)
  dir.create(outside, recursive = TRUE)
  target <- file.path(outside, "precious.txt")
  writeLines("PRECIOUS EXTERNAL CONTENT", target)
  writeLines("metasalmon-owned", file.path(pkg, ".metasalmon-package"))
  file.symlink(target, file.path(pkg, "README-review.txt"))

  expect_error(
    .ms_assert_managed_path_contained(
      pkg,
      file.path(pkg, c("README-review.txt", "semantic_suggestions.csv"))
    ),
    "symbolic-link path component"
  )
  expect_identical(readLines(target)[[1]], "PRECIOUS EXTERNAL CONTENT")
})

test_that("declared-type fidelity accounts for magnitude, not just digit count", {
  # Digit count alone is a proxy. `1e-400` has one significant digit and still
  # does not survive (readr clamps it to 1e-307), and six fractional seconds
  # stop being representable as the epoch magnitude grows.
  check <- function(tokens, value_type) {
    file_path <- withr::local_tempfile(fileext = ".csv")
    writeLines(c("v", tokens), file_path)
    parsed <- .ms_read_resource_csv(
      file_path,
      tibble::tibble(column_name = "v", value_type = value_type)
    )
    mismatches <- attr(parsed, "ms_value_type_mismatches")
    if (is.null(mismatches)) NA_character_ else mismatches[[1]]$reason
  }

  expect_identical(check(c("1e-400", "0"), "number"), "beyond exact numeric precision")
  expect_identical(check("1e400", "number"), "beyond exact numeric precision")
  # 9e308 overflows even though its exponent is 308 — an exponent bound alone
  # missed it.
  expect_identical(check("9e308", "number"), "beyond exact numeric precision")
  expect_identical(
    check(c("2243-01-01T00:00:00.000001Z", "2243-01-01T00:00:00.000002Z"), "datetime"),
    "finer than the datetime representation can hold"
  )

  # Representable magnitudes must not be flagged. In particular milliseconds at
  # year 2243 are fine while microseconds there are not — the threshold moves
  # with the magnitude rather than being fixed.
  # Magnitudes outside the representable band are covered by their own test;
  # 1e-290 and 1e290 sit just inside it.
  expect_true(is.na(check("1e-290", "number")))
  expect_true(is.na(check("1e290", "number")))
  # 16 digits but below 2^53, so exactly representable. A digit-count cutoff
  # flagged this and would have rejected valid data — the failure mode that
  # matters most here, since it breaks working packages.
  expect_true(is.na(check("1234567890123456", "integer")))
  expect_true(is.na(check(c("-12.750", "0.001"), "number")))
  expect_true(is.na(check("2243-01-01T00:00:00.123Z", "datetime")))
  expect_true(is.na(check("2026-01-01T00:00:00.123456Z", "datetime")))
  expect_true(is.na(check("1970-01-01T00:00:00.123456Z", "datetime")))
})

test_that("an extreme exponent is rejected without materialising its expansion", {
  # `1e1000000000` would ask strrep() for a billion zeros inside the decimal
  # normalizer and take the process down. Magnitude now decides before any
  # string expansion happens.
  file_path <- withr::local_tempfile(fileext = ".csv")
  writeLines(c("v", "1e1000000000", "1"), file_path)

  elapsed <- system.time({
    parsed <- .ms_read_resource_csv(
      file_path,
      tibble::tibble(column_name = "v", value_type = "number")
    )
  })[["elapsed"]]

  expect_lt(elapsed, 5)
  expect_type(parsed$v, "character")
  expect_identical(
    attr(parsed, "ms_value_type_mismatches")[[1]]$reason,
    "beyond exact numeric precision"
  )
})

test_that("magnitudes outside the representable band keep their exact text", {
  # Deliberately a fixed band rather than "can this platform verify it?".
  # macOS cannot round-trip 1e-300 through any of 15..17 significant digits and
  # readr disagrees with as.numeric there, while Linux converts it cleanly — so
  # asking the platform would make the same package validate in one place and
  # fail in another. The band costs only tokens no salmon dataset carries.
  read_one <- function(token) {
    file_path <- withr::local_tempfile(fileext = ".csv")
    writeLines(c("v", token), file_path)
    .ms_read_resource_csv(
      file_path,
      tibble::tibble(column_name = "v", value_type = "number")
    )
  }

  for (token in c("1e-300", "1e308")) {
    parsed <- read_one(token)
    expect_identical(parsed$v, token)
    expect_length(attr(parsed, "ms_value_type_mismatches"), 1L)
  }

  # Just inside the band, in both directions, converts and is not flagged.
  for (token in c("1e-290", "1e290")) {
    parsed <- read_one(token)
    expect_type(parsed$v, "double")
    expect_null(attr(parsed, "ms_value_type_mismatches"))
  }
})

test_that("a hard-linked create-owned output is replaced, not written through", {
  # `Sys.readlink()` sees only symbolic links, so the containment check passes
  # for a hard link and the write would truncate the shared inode outside the
  # package. The pre-0.2.0 full-directory wipe unlinked these entries first;
  # preserving the directory removed that protection.
  skip_on_os("windows")
  base <- withr::local_tempdir()
  pkg <- file.path(base, "pkg")
  outside <- file.path(base, "outside")
  dir.create(pkg, recursive = TRUE)
  dir.create(outside, recursive = TRUE)
  target <- file.path(outside, "precious.txt")
  writeLines("PRECIOUS EXTERNAL CONTENT", target)
  writeLines("metasalmon-owned", file.path(pkg, ".metasalmon-package"))
  skip_if_not(file.link(target, file.path(pkg, "README-review.txt")), "hard links unsupported")

  .ms_write_sdp_review_readme(pkg_path = pkg, dataset_id = "d1", has_suggestions = FALSE)

  expect_identical(readLines(target)[[1]], "PRECIOUS EXTERNAL CONTENT")
  expect_true(any(grepl("Review Checklist", readLines(file.path(pkg, "README-review.txt")))))
})

test_that("codes.csv values are fidelity-checked against their declared type", {
  # Only the data resource was checked. A code token carrying more precision
  # than its declared type can hold canonicalizes onto a different data value,
  # so the comparison succeeded while the actual data value was absent.
  temp_dir <- withr::local_tempdir()
  df <- data.frame(v = "0.1", stringsAsFactors = FALSE)
  dict <- fill_measurement_components(
    infer_dictionary(df, dataset_id = "ct", table_id = "obs")
  )
  dict$value_type <- "number"
  dict$column_role <- "categorical"
  codes <- tibble::tibble(
    dataset_id = "ct", table_id = "obs", column_name = "v",
    code_value = "0.10000000000000001", code_label = "A",
    code_description = NA_character_
  )

  suppressWarnings(write_salmon_datapackage(
    resources = list(obs = df),
    dataset_meta = tibble::tibble(
      dataset_id = "ct", title = "Codes", description = "Lossy code token",
      spec_version = NA_character_
    ),
    table_meta = tibble::tibble(
      dataset_id = "ct", table_id = "obs", table_label = "obs",
      table_description = "Rows", file_name = NA_character_,
      observation_unit = NA_character_, observation_unit_iri = NA_character_,
      primary_key = NA_character_
    ),
    dict = dict, codes = codes, path = temp_dir, overwrite = TRUE
  ))

  expect_error(validate_salmon_datapackage(temp_dir), "codes.csv value")
})

test_that("a symlinked metadata path is rejected before it is read", {
  # `.ms_package_managed_paths()` parses the previous tables.csv, so the
  # containment check has to run first or an external target is read — a FIFO
  # would block, a huge file would be parsed — before the guard fires.
  skip_on_os("windows")
  base <- withr::local_tempdir()
  pkg <- file.path(base, "pkg")
  outside <- file.path(base, "outside")
  dir.create(file.path(pkg, "data"), recursive = TRUE)
  dir.create(outside, recursive = TRUE)
  writeLines("metasalmon-owned", file.path(pkg, ".metasalmon-package"))
  writeLines(c("dataset_id,table_id,file_name", "d1,t1,data/x.csv"),
             file.path(outside, "tables.csv"))
  file.symlink(outside, file.path(pkg, "metadata"))

  expect_error(
    .ms_assert_managed_path_contained(pkg, .ms_metadata_path(pkg, "tables.csv")),
    "symbolic-link path component"
  )
})

test_that("a large token with few significant digits is still checked", {
  # Stripping trailing zeros made `90071992547409900` look like 15 significant
  # digits, so it took the fast path and was returned as 90071992547409904.
  # The fast path is now bounded above by the exact integer range too.
  check <- function(tokens, value_type = "integer") {
    file_path <- withr::local_tempfile(fileext = ".csv")
    writeLines(c("v", tokens), file_path)
    parsed <- .ms_read_resource_csv(
      file_path,
      tibble::tibble(column_name = "v", value_type = value_type)
    )
    list(values = parsed$v, reason = attr(parsed, "ms_value_type_mismatches"))
  }

  altered <- check("90071992547409900")
  expect_identical(altered$values, "90071992547409900")
  expect_length(altered$reason, 1L)

  # Values above 1e15 that ARE exactly representable must still convert.
  for (token in c("10000000000000000", "9007199254740992", "1234567890123456")) {
    exact <- check(token)
    expect_type(exact$values, "double")
    expect_null(exact$reason)
  }
})

test_that("the pre-read containment check covers legacy root-level metadata", {
  # `.ms_locate_metadata_file()` accepts a root-level shadow, so
  # `.ms_previous_declared_data_paths()` reads a root `tables.csv` when
  # `metadata/tables.csv` is absent. Checking only the `metadata/` copies left
  # that path unguarded — the external target was parsed before the guard ran.
  skip_on_os("windows")
  base <- withr::local_tempdir()
  pkg <- file.path(base, "pkg")
  outside <- file.path(base, "outside")
  dir.create(file.path(pkg, "data"), recursive = TRUE)
  dir.create(outside, recursive = TRUE)
  writeLines("metasalmon-owned", file.path(pkg, ".metasalmon-package"))
  writeLines(c("dataset_id,table_id,file_name", "d1,t1,data/x.csv"),
             file.path(outside, "tables.csv"))
  file.symlink(file.path(outside, "tables.csv"), file.path(pkg, "tables.csv"))

  metadata_names <- c("dataset.csv", "tables.csv", "column_dictionary.csv", "codes.csv")
  expect_error(
    .ms_assert_managed_path_contained(
      pkg,
      c(.ms_metadata_path(pkg, metadata_names), file.path(pkg, metadata_names))
    ),
    "symbolic-link path component"
  )
})

test_that("a symlinked package root is refused", {
  # The per-component walk starts at `path`, so it never inspected `path`
  # itself: a symlinked root left every child looking contained, and
  # `prune = TRUE` would empty the link's target.
  skip_on_os("windows")
  base <- withr::local_tempdir()
  real <- file.path(base, "real")
  dir.create(file.path(real, "metadata"), recursive = TRUE)
  writeLines("metasalmon-owned", file.path(real, ".metasalmon-package"))
  writeLines("precious", file.path(real, "metadata", "dataset.csv"))
  link <- file.path(base, "link")
  file.symlink(real, link)

  expect_error(
    .ms_assert_managed_path_contained(link, .ms_metadata_path(link, "dataset.csv")),
    "package root is a symbolic link"
  )
  # The real directory is still writable, and an ancestor that is itself a link
  # (macOS `/tmp` -> `/private/tmp`) must not trip the check.
  expect_silent(.ms_assert_managed_path_contained(real, .ms_metadata_path(real, "dataset.csv")))
})

test_that("a symlinked root is refused however the path is spelled", {
  # `Sys.readlink("link/.")` reads the `.` entry inside the resolved target and
  # returns "", so the trailing-dot spelling walked straight past the root check.
  skip_on_os("windows")
  base <- withr::local_tempdir()
  real <- file.path(base, "real")
  dir.create(file.path(real, "metadata"), recursive = TRUE)
  writeLines("metasalmon-owned", file.path(real, ".metasalmon-package"))
  link <- file.path(base, "link")
  file.symlink(real, link)

  for (spelling in c(link, paste0(link, "/"), paste0(link, "/."),
                     paste0(link, "/./"), paste0(link, "//"))) {
    expect_error(
      .ms_assert_managed_path_contained(spelling, .ms_metadata_path(spelling, "dataset.csv")),
      "package root is a symbolic link",
      info = spelling
    )
  }

  # The same spellings of a real directory must still be accepted.
  for (spelling in c(real, paste0(real, "/"), paste0(real, "/."))) {
    expect_silent(
      .ms_assert_managed_path_contained(spelling, .ms_metadata_path(spelling, "dataset.csv"))
    )
  }
})

test_that("a package root ending in .. is refused", {
  # `link/..` resolves `link` as an intermediate component and then reads `..`
  # inside the target, so the symlink check sees nothing while the root denotes
  # the target's parent -- potentially an unrelated package.
  skip_on_os("windows")
  base <- withr::local_tempdir()
  real <- file.path(base, "outer", "inner")
  dir.create(real, recursive = TRUE)
  link <- file.path(base, "link")
  file.symlink(real, link)

  for (spelling in c(paste0(link, "/.."), paste0(link, "/../"), paste0(link, "/../."))) {
    expect_error(
      .ms_assert_managed_path_contained(spelling, .ms_metadata_path(spelling, "dataset.csv")),
      "ends in",
      info = spelling
    )
  }

  # `..` anywhere but last is fine: readlink resolves all but the final
  # component, so the check still inspects the right directory.
  dir.create(file.path(base, "outer", "sibling"))
  ok <- file.path(base, "outer", "inner", "..", "sibling")
  expect_silent(.ms_assert_managed_path_contained(ok, .ms_metadata_path(ok, "dataset.csv")))
})

test_that("literal NA and other adversarial tokens survive the round trip", {
  # #54. readr's defaults disagree with each other: it *writes* a missing value
  # as the two characters `NA` and *reads* `c("", "NA")` as missing. "NA" is a
  # real fisheries gear code, so a literal "NA" and a genuinely missing value
  # produced identical bytes -- the distinction was destroyed at write time,
  # where no reader could recover it.
  path <- file.path(withr::local_tempdir(), "pkg")
  data <- data.frame(
    site = c("s1", "s2", "s3", "s4", "s5"),
    gear_code = c("NA", "GN", NA, "N/A", "null"),
    note = c("has, comma", "has \"quote\"", "line\nbreak", "näägel", "ok"),
    stringsAsFactors = FALSE
  )

  suppressMessages(create_sdp(
    data, path = path, dataset_id = "na-rt", table_id = "obs", seed_semantics = FALSE
  ))
  back <- suppressMessages(read_salmon_datapackage(path))$resources[[1]]

  # The literal tokens are values, not missingness.
  expect_identical(back$gear_code[[1]], "NA")
  expect_identical(back$gear_code[[4]], "N/A")
  expect_identical(back$gear_code[[5]], "null")
  # And a genuinely missing value is still missing.
  expect_true(is.na(back$gear_code[[3]]))

  # Quoting, embedded newlines, and non-ASCII survive unchanged.
  expect_identical(back$note, data$note)

  # The bytes themselves must distinguish the two cases -- asserting only on the
  # parsed result would pass even if the reader were guessing.
  bytes <- readLines(list.files(file.path(path, "data"), full.names = TRUE), warn = FALSE)
  expect_true(any(grepl("^s1,NA,", bytes)))
  expect_true(any(grepl("^s3,,", bytes)))
})

test_that("a literal NA code value validates against its codes.csv entry", {
  # The comparison reads both sides through the same missing-value contract, so
  # a declared code of "NA" must match the data rather than reading as absent.
  path <- file.path(withr::local_tempdir(), "pkg")
  data <- data.frame(
    site = c("s1", "s2"),
    gear_code = c("NA", "GN"),
    stringsAsFactors = FALSE
  )

  suppressMessages(create_sdp(
    data, path = path, dataset_id = "na-codes", table_id = "obs", seed_semantics = FALSE
  ))
  codes <- tibble::tibble(
    dataset_id = "na-codes",
    table_id = "obs",
    column_name = "gear_code",
    code_value = c("NA", "GN"),
    code_label = c("Not applicable gear", "Gill net")
  )
  readr::write_csv(codes, .ms_metadata_path(path, "codes.csv"), na = "")

  issues <- validate_salmon_datapackage(path)
  expect_false(any(grepl("not listed in codes", issues$message %||% character(), ignore.case = TRUE)))
})

test_that("a declared primary key must actually identify a row", {
  # #77. `primary_key` was declared in tables.csv and read by nothing that
  # tested it, so a table could claim a key and ship duplicates — the tidy
  # principle "each observation forms a row" going unchecked.
  path <- file.path(withr::local_tempdir(), "pkg")
  data <- data.frame(site = c("a", "a"), count = c(1L, 2L), stringsAsFactors = FALSE)
  suppressMessages(create_sdp(
    data, path = path, dataset_id = "pk", table_id = "obs", seed_semantics = FALSE
  ))
  tables <- .ms_read_metadata_csv(.ms_metadata_path(path, "tables.csv"))
  tables$primary_key <- "site"
  readr::write_csv(tables, .ms_metadata_path(path, "tables.csv"), na = "")

  expect_error(
    suppressWarnings(suppressMessages(validate_salmon_datapackage(path))),
    "primary key"
  )

  # A key that does identify rows passes.
  unique_data <- data.frame(site = c("a", "b"), count = c(1L, 2L), stringsAsFactors = FALSE)
  ok <- file.path(withr::local_tempdir(), "ok")
  suppressMessages(create_sdp(
    unique_data, path = ok, dataset_id = "pk", table_id = "obs", seed_semantics = FALSE
  ))
  ok_tables <- .ms_read_metadata_csv(.ms_metadata_path(ok, "tables.csv"))
  ok_tables$primary_key <- "site"
  readr::write_csv(ok_tables, .ms_metadata_path(ok, "tables.csv"), na = "")
  expect_no_error(suppressWarnings(suppressMessages(validate_salmon_datapackage(ok))))
})

test_that("value-like column names are reported as a warning, not an error", {
  # The SDP may accept untidy data; it must stop implying it checked. So this is
  # a warning by design — an error would reject packages the spec allows.
  expect_identical(
    .ms_detect_wide_columns(c("site", "1998", "1999", "2000")),
    c("1998", "1999", "2000")
  )
  expect_identical(
    .ms_detect_wide_columns(c("site", "count_1998", "count_1999", "count_2000")),
    c("count_1998", "count_1999", "count_2000")
  )

  # Deliberately not flagged: fewer than three, and ordinary names.
  expect_identical(.ms_detect_wide_columns(c("site", "x2", "x3")), character())
  expect_identical(.ms_detect_wide_columns(c("site", "depth_1", "depth_2")), character())
  expect_identical(.ms_detect_wide_columns(c("site", "year", "count")), character())
})

test_that("placeholders warn in the default mode and error under require_iris", {
  # The strict path already reported these; the default path returned zero
  # issues and said nothing, so a package could look clean while advertising in
  # its own metadata that its metadata was missing. Only the warning half is
  # new — the error channel stays `.ms_collect_review_placeholder_issues()`.
  path <- file.path(withr::local_tempdir(), "pkg")
  data <- data.frame(site = c("a", "b"), count = c(1L, 2L), stringsAsFactors = FALSE)
  suppressMessages(create_sdp(
    data, path = path, dataset_id = "ph", table_id = "obs", seed_semantics = FALSE
  ))

  expect_warning(
    suppressMessages(validate_salmon_datapackage(path)),
    "placeholder"
  )
  # The strict path is covered by "fails final validation on unresolved metadata
  # placeholders" above; asserting it here would need a fixture with complete
  # semantics, since a missing term_iri errors first.
})

test_that("a primary key with missing values is rejected", {
  # A row whose key is NA has no identity, but `paste()` renders NA as the
  # string "NA", which rarely collides — so the duplicate test alone passed it.
  path <- file.path(withr::local_tempdir(), "pkg")
  data <- data.frame(site = c("a", "b"), count = c(1L, 2L), stringsAsFactors = FALSE)
  suppressMessages(create_sdp(
    data, path = path, dataset_id = "pk", table_id = "obs", seed_semantics = FALSE
  ))
  data_file <- list.files(file.path(path, "data"), full.names = TRUE)[[1]]
  readr::write_csv(
    data.frame(site = c("a", NA), count = c(1L, 2L), stringsAsFactors = FALSE),
    data_file, na = ""
  )
  tables <- .ms_read_metadata_csv(.ms_metadata_path(path, "tables.csv"))
  tables$primary_key <- "site"
  readr::write_csv(tables, .ms_metadata_path(path, "tables.csv"), na = "")

  expect_error(
    suppressWarnings(suppressMessages(validate_salmon_datapackage(path))),
    "missing values"
  )
})
