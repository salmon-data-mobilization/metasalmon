# Three dataset-level inference gaps that create_sdp() showed on a large lake
# trawl biosample table (hub item B-440). Every frame here is small and
# synthetic; none is a user's data.
#
# 1. A unit named in a column-name suffix (`fish_length_mm`, `fish_weight_g`,
#    `depth_m`) was never read, so a numeric column whose name mentions fish
#    was taken for a count and seeded the QUDT `COUNT` unit.
# 2. An administrative date column (`process_date`) fed temporal coverage, so
#    `temporal_end` landed years after the observations stopped.
# 3. A spatial extent whose longitudes are all positive was written silently,
#    even where the data are almost certainly in the western hemisphere.

# ---------------------------------------------------------------------------
# 1. Units named by a column-name suffix
# ---------------------------------------------------------------------------

unit_cue_frame <- function() {
  tibble::tibble(
    fish_length_mm = c(512, 600.5, 455),
    fish_weight_g = c(1500.2, 2100, 980),
    depth_m = c(12.5, 30, 45.1),
    fish_count = c(3L, 5L, 2L)
  )
}

unit_cue_targets <- function(df, force_measurement = character()) {
  dict <- infer_dictionary(df, dataset_id = "d1", table_id = "trawl")
  # A column the name heuristics type `attribute` gets no unit target at all,
  # so a test of the unit reader marks it a measurement, as a user would.
  dict$column_role[dict$column_name %in% force_measurement] <- "measurement"
  metasalmon:::.ms_semantic_discover_targets(
    dict = dict,
    codes = tibble::tibble(),
    table_meta = tibble::tibble(),
    dataset_meta = tibble::tibble(),
    resource_lookup = list(trawl = df)
  )
}

target_query <- function(targets, column, field) {
  hit <- targets$search_query[
    targets$column_name == column & targets$target_sdp_field == field
  ]
  if (length(hit) == 0) NA_character_ else hit[[1]]
}

test_that("a unit suffix in a column name becomes the unit search query", {
  targets <- unit_cue_targets(unit_cue_frame())

  expect_identical(target_query(targets, "fish_length_mm", "unit_iri"), "millimeter")
  expect_identical(target_query(targets, "fish_weight_g", "unit_iri"), "gram")
  expect_identical(target_query(targets, "depth_m", "unit_iri"), "meter")
  # Positive control: a real count keeps its count unit.
  expect_identical(target_query(targets, "fish_count", "unit_iri"), "count")
})

test_that("a length or mass column is not searched as a count", {
  targets <- unit_cue_targets(unit_cue_frame())

  for (column in c("fish_length_mm", "fish_weight_g")) {
    expect_false(
      identical(target_query(targets, column, "term_iri"), "count"),
      info = column
    )
    expect_false(
      identical(target_query(targets, column, "property_iri"), "count"),
      info = column
    )
  }
  # The unit token is not part of the variable query either.
  expect_identical(target_query(targets, "fish_length_mm", "term_iri"), "fish length")

  # Without a suffix, a fish length still names no count unit.
  targets_bare <- unit_cue_targets(tibble::tibble(fish_length = c(512, 600.5, 455)))
  expect_true(is.na(target_query(targets_bare, "fish_length", "unit_iri")))
})

test_that("a bare one-letter suffix is read as a unit only beside a quantity it measures", {
  targets <- unit_cue_targets(tibble::tibble(
    # `m` and `g` alone are too ambiguous (males, group): no length or mass
    # word, no unit.
    spawners_m = c(10L, 12L, 9L),
    catch_g = c(4.5, 2.1, 3.3),
    # `weight` is not a length, so `_m` is not metres.
    weight_m = c(1.2, 3.4, 5.6)
  ))

  expect_false(identical(target_query(targets, "spawners_m", "unit_iri"), "meter"))
  expect_true(is.na(target_query(targets, "catch_g", "unit_iri")))
  expect_false(identical(target_query(targets, "weight_m", "unit_iri"), "meter"))
})

test_that("a compound unit is not read from its last token", {
  # `mg/kg` is a concentration and `per kg` a rate, so reading the
  # denominator alone would draft kilogram for something that is not a mass
  # (Codex review of #285). They stay unresolved, as before B-440.
  compound <- c("mercury_mg/kg", "mercury_mg_kg", "eggs_per_kg", "fish_length_per_m")
  targets <- unit_cue_targets(
    tibble::tibble(
      `mercury_mg/kg` = c(0.12, 0.30, 0.08),
      mercury_mg_kg = c(0.12, 0.30, 0.08),
      eggs_per_kg = c(1500, 2100, 1800),
      fish_length_per_m = c(0.2, 0.4, 0.3)
    ),
    force_measurement = compound
  )

  for (column in compound) {
    expect_true(is.na(target_query(targets, column, "unit_iri")), info = column)
  }
})

test_that("create_sdp() seeds millimetre, gram and metre from unit suffixes, not COUNT", {
  withr::local_options(metasalmon.llm_deprecation_quiet = TRUE)
  qudt <- c(count = "COUNT", millimeter = "MilliM", gram = "GM", meter = "M")
  labels <- c(count = "Count", millimeter = "Millimetre", gram = "Gram", meter = "Metre")
  fake_find_terms <- function(query, role, sources, ...) {
    if (!identical(role, "unit") || !query %in% names(qudt)) {
      return(tibble::tibble())
    }
    tibble::tibble(
      label = labels[[query]],
      iri = paste0("http://qudt.org/vocab/unit/", qudt[[query]]),
      source = "qudt",
      ontology = "qudt",
      role = "unit",
      match_type = "label",
      definition = NA_character_
    )
  }

  out_dir <- withr::local_tempdir()
  pkg_path <- with_mocked_bindings(
    find_terms = fake_find_terms,
    suppressMessages(create_sdp(
      list(trawl = unit_cue_frame()),
      path = file.path(out_dir, "pkg"),
      dataset_id = "d1",
      seed_verbose = FALSE,
      check_updates = FALSE
    ))
  )

  dict <- readr::read_csv(
    file.path(pkg_path, "metadata", "column_dictionary.csv"),
    show_col_types = FALSE,
    col_types = readr::cols(.default = readr::col_character())
  )
  unit_of <- function(column) dict$unit_iri[dict$column_name == column]
  review <- metasalmon:::.ms_review_iri_prefix()

  expect_identical(unit_of("fish_length_mm"), paste0(review, "http://qudt.org/vocab/unit/MilliM"))
  expect_identical(unit_of("fish_weight_g"), paste0(review, "http://qudt.org/vocab/unit/GM"))
  expect_identical(unit_of("depth_m"), paste0(review, "http://qudt.org/vocab/unit/M"))
  expect_identical(unit_of("fish_count"), paste0(review, "http://qudt.org/vocab/unit/COUNT"))
})

# ---------------------------------------------------------------------------
# 2. Temporal coverage ignores administrative dates
# ---------------------------------------------------------------------------

test_that("an administrative date column does not stretch temporal coverage", {
  df <- tibble::tibble(
    survey_date = as.Date(c("1977-07-01", "1988-08-15", "1999-09-30")),
    process_date = as.Date(c("2016-02-01", "2016-05-01", "2017-03-15"))
  )

  meta <- metasalmon:::infer_dataset_metadata_from_resources(list(trawl = df), "d1")

  expect_identical(meta$temporal_start[[1]], "1977-07-01")
  expect_identical(meta$temporal_end[[1]], "1999-09-30")
})

test_that("common administrative date spellings are all left out of coverage", {
  admin_names <- c(
    "process_date", "processed_dtt", "date_processed", "ProcessingDate",
    "entry_date", "date_entered", "created_on", "CREATED_DTT", "DateCreated",
    "modified_date", "last_modified", "mod_date", "updated_at", "UPDATE_DTT",
    "load_date", "import_timestamp", "qc_date", "verified_date"
  )
  for (admin in admin_names) {
    df <- tibble::tibble(
      sample_date = as.Date(c("1985-06-01", "1990-06-01")),
      admin = as.Date(c("2015-01-01", "2020-01-01"))
    )
    names(df)[[2]] <- admin

    meta <- metasalmon:::infer_dataset_metadata_from_resources(list(t = df), "d1")

    expect_identical(meta$temporal_end[[1]], "1990-06-01", info = admin)
  }
})

test_that("observation dates still set coverage, and admin dates alone set none", {
  # Positive control: nothing administrative, coverage unchanged.
  obs <- tibble::tibble(
    sample_date = as.Date(c("2001-05-01", "2003-09-30")),
    release_time = as.POSIXct(c("2002-01-01 10:00", "2004-02-02 11:00"), tz = "UTC")
  )
  meta_obs <- metasalmon:::infer_dataset_metadata_from_resources(list(t = obs), "d1")
  expect_identical(meta_obs$temporal_start[[1]], "2001-05-01")
  expect_identical(meta_obs$temporal_end[[1]], "2004-02-02")

  # Fish entering fresh water is an observation, not data entry.
  river <- tibble::tibble(
    river_entry_date = as.Date(c("1995-07-01", "1996-08-01")),
    data_entry_date = as.Date(c("2016-01-01", "2017-01-01"))
  )
  meta_river <- metasalmon:::infer_dataset_metadata_from_resources(list(t = river), "d1")
  expect_identical(meta_river$temporal_start[[1]], "1995-07-01")
  expect_identical(meta_river$temporal_end[[1]], "1996-08-01")

  # An entry date is not when the data were observed, so it is no coverage.
  admin_only <- tibble::tibble(entry_date = as.Date(c("2016-01-01", "2017-01-01")))
  meta_admin <- metasalmon:::infer_dataset_metadata_from_resources(list(t = admin_only), "d1")
  expect_true(is.na(meta_admin$temporal_start[[1]]))
  expect_true(is.na(meta_admin$temporal_end[[1]]))
})

# ---------------------------------------------------------------------------
# 3. Positive longitudes get a review note, never a silent sign flip
# ---------------------------------------------------------------------------

test_that("all-positive longitudes in the mirrored North American window get a review note", {
  df <- tibble::tibble(
    lon = c(122.5, 130.1, 137.9),
    lat = c(48.2, 55.0, 60.0)
  )

  meta <- metasalmon:::infer_dataset_metadata_from_resources(list(trawl = df), "d1")
  extent <- meta$spatial_extent[[1]]

  expect_true(metasalmon:::.ms_is_review_placeholder(extent))
  # The inferred extent is kept, unflipped, so the reviewer sees what was read.
  expect_match(extent, "lon=122.5..137.9, lat=48.2..60", fixed = TRUE)
  expect_false(grepl("-122.5", extent, fixed = TRUE))
  expect_match(extent, "negative", fixed = TRUE)
})

test_that("the longitude review note reaches dataset.csv and strict validation refuses it", {
  df <- tibble::tibble(
    station = c("A", "B", "C"),
    lon = c(122.5, 130.1, 137.9),
    lat = c(48.2, 55.0, 60.0)
  )
  out_dir <- withr::local_tempdir()
  pkg_path <- suppressMessages(create_sdp(
    list(trawl = df),
    path = file.path(out_dir, "pkg"),
    dataset_id = "d1",
    seed_semantics = FALSE,
    seed_verbose = FALSE,
    check_updates = FALSE
  ))
  dataset_csv <- readr::read_csv(
    file.path(pkg_path, "metadata", "dataset.csv"),
    show_col_types = FALSE,
    col_types = readr::cols(.default = readr::col_character())
  )

  expect_match(dataset_csv$spatial_extent[[1]], "^REVIEW REQUIRED: ")
  # The sweep strict validation runs over dataset.csv names the field.
  issues <- metasalmon:::.ms_collect_review_placeholder_issues(
    dataset_csv,
    "metadata/dataset.csv"
  )
  expect_true(any(grepl("spatial_extent", issues$message, fixed = TRUE)))
})

test_that("negative or eastern-hemisphere-shaped longitudes are written as before", {
  western <- tibble::tibble(lon = c(-137.9, -122.5), lat = c(48.2, 60.0))
  meta_w <- metasalmon:::infer_dataset_metadata_from_resources(list(t = western), "d1")
  expect_identical(as.character(meta_w$spatial_extent[[1]]), "lon=-137.9..-122.5, lat=48.2..60")

  # Norway's coast: positive and correct, and outside the mirrored window.
  norway <- tibble::tibble(lon = c(5.3, 29.9), lat = c(58.1, 70.9))
  meta_n <- metasalmon:::infer_dataset_metadata_from_resources(list(t = norway), "d1")
  expect_identical(as.character(meta_n$spatial_extent[[1]]), "lon=5.3..29.9, lat=58.1..70.9")

  # A mixed-sign extent says nothing about a sign error.
  mixed <- tibble::tibble(lon = c(-10.2, 15.4), lat = c(50.0, 60.0))
  meta_m <- metasalmon:::infer_dataset_metadata_from_resources(list(t = mixed), "d1")
  expect_false(metasalmon:::.ms_is_review_placeholder(meta_m$spatial_extent[[1]]))
})
