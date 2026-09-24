# Backlog #53 (queue B-53): a measurement column whose every value happens to
# be a four-digit number from 1800 to 2500 -- a small stock's spawner counts, a
# sample of 1,900 fish -- was typed `temporal` on its value shape alone, and
# `suggest_semantics()` skips temporal columns, so the column left the whole
# semantic pipeline with no warning. The same column holding numbers outside
# that range was typed `measurement`.
#
# Every fixture below is first checked against `.ms_values_look_yearish()`.
# That is the control: if the year-shape rule ever narrows so that a fixture
# stops being year-shaped, the test fails on the control instead of passing
# without exercising the case it exists for.

# One fixture per kind of whole-word measurement evidence, and per storage type
# a CSV reader hands back: double, character and integer.
year_shaped_measurements <- list(
  NATURAL_ADULT_SPAWNERS = c(1850, 2003, 1999),
  spawner_count = c("1850", "2003", "1999"),
  escapement = c(1812L, 2240L, 1907L),
  total_return = c(2011, 2400, 1890),
  mr_1st_sample_size = c(1900, 2000),
  `Water depth (mm)` = c(1850, 1920),
  avg_weight = c(1900, 2100)
)

# The same values moved out of the year range without changing storage type.
not_year_shaped <- function(values) {
  if (is.factor(values)) {
    return(factor(paste0(as.character(values), "0")))
  }
  if (is.character(values)) {
    return(paste0(values, "0"))
  }
  values * 10L
}

test_that("a year-shaped measurement column is typed measurement, not temporal", {
  for (name in names(year_shaped_measurements)) {
    values <- year_shaped_measurements[[name]]
    expect_true(.ms_values_look_yearish(values), info = name)
    expect_identical(infer_column_role(name, values), "measurement", info = name)
  }
})

test_that("year-shaped values do not change the role a measurement name gets", {
  # The invariant, stated over more than the measurement branch: with a
  # whole-word measurement term in the name, the column takes the role it would
  # take with any other values. So an explicit factor stays categorical and a
  # method-named column stays metadata, exactly as they do off the year range.
  cases <- c(
    year_shaped_measurements,
    list(
      spawner_count = factor(c("1850", "2003", "1850")),
      count_method = c("1850", "2003", "1850")
    )
  )
  for (i in seq_along(cases)) {
    name <- names(cases)[[i]]
    values <- cases[[i]]
    label <- paste(name, class(values)[[1]])
    shifted <- not_year_shaped(values)
    expect_true(.ms_values_look_yearish(values), info = label)
    expect_false(.ms_values_look_yearish(shifted), info = label)
    expect_identical(
      infer_column_role(name, values),
      infer_column_role(name, shifted),
      info = label
    )
  }
  expect_identical(
    infer_column_role("spawner_count", factor(c("1850", "2003", "1850"))),
    "categorical"
  )
  expect_identical(
    infer_column_role("count_method", c("1850", "2003", "1850")),
    "categorical"
  )
})

test_that("the year shape still decides when the name carries no measurement word", {
  # The heuristic exists for columns whose name says nothing, such as a brood
  # or return year abbreviated to `BY`. That job is unchanged.
  still_temporal <- list(
    BY = c(2001, 2002, 2003),
    RETURN = c("1999", "2000"),
    season = factor(c("2001", "2002"))
  )
  for (name in names(still_temporal)) {
    values <- still_temporal[[name]]
    expect_true(.ms_values_look_yearish(values), info = name)
    expect_identical(infer_column_role(name, values), "temporal", info = name)
  }

  # A name that says year is temporal before any measurement word is read.
  expect_identical(infer_column_role("count_year", c(2001, 2002)), "temporal")
  expect_identical(infer_column_role("ANALYSIS_YR", c("2023", "2024", "2023")), "temporal")
})

test_that("a substring or a parenthesised unit does not override the year shape", {
  # The two names a rule built on `.ms_name_has_measurement_hint()` would get
  # wrong, one per pattern in it. `temp` inside `temporal`: the SDP's own
  # dataset.csv fields, the only year-shaped columns that hint would have moved
  # across the 1,271 columns in the ecosystem's CSVs (measured 2026-09-24). And
  # the unit pattern's bare `g`, which accepts any parenthetical holding one.
  not_measurements <- list(
    temporal_start = c("2001", "2024"),
    temporal_end = c(2001, 2024),
    `Cohort (Aug)` = c(2001, 2002)
  )
  for (name in names(not_measurements)) {
    values <- not_measurements[[name]]
    expect_true(.ms_values_look_yearish(values), info = name)
    expect_identical(infer_column_role(name, values), "temporal", info = name)
  }
})

test_that("a year-shaped measurement column reaches the semantic pipeline", {
  empty_search <- function(query, role, sources) tibble::tibble()
  measurement_targets <- function(spawners) {
    df <- tibble::tibble(
      ANALYSIS_YR = c("2023", "2024", "2023"),
      NATURAL_ADULT_SPAWNERS = spawners
    )
    dict <- infer_dictionary(
      df,
      dataset_id = "fraser-coho",
      table_id = "escapement",
      seed_semantics = FALSE
    )
    out <- suppressMessages(suggest_semantics(
      df, dict,
      sources = "smn", max_per_role = 1, search_fn = empty_search
    ))
    targets <- attr(out, "semantic_targets")
    list(
      role = dict$column_role[dict$column_name == "NATURAL_ADULT_SPAWNERS"],
      targets = targets[
        targets$column_name == "NATURAL_ADULT_SPAWNERS",
        c("dictionary_role", "target_sdp_field", "search_query"),
        drop = FALSE
      ]
    )
  }

  year_shaped <- c(1850, 2003, 1999)
  expect_true(.ms_values_look_yearish(year_shaped))
  seen <- measurement_targets(year_shaped)
  expect_identical(seen$role, "measurement")

  # Before the fix this column had no targets at all. It now gets the full
  # measurement set -- the variable, property, entity and unit slots among
  # them -- and exactly the targets it gets with values off the year range.
  expect_true(all(
    c("term_iri", "property_iri", "entity_iri", "unit_iri") %in%
      seen$targets$target_sdp_field
  ))
  expect_identical(seen$targets, measurement_targets(c(12, 15, 18))$targets)
})
