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
# a CSV reader hands back: double, character and integer. The last two join
# their measurement word to the rest of the name with punctuation that
# `.ms_name_tokens()` does not split at (found by the Codex review of #152).
year_shaped_measurements <- list(
  NATURAL_ADULT_SPAWNERS = c(1850, 2003, 1999),
  spawner_count = c("1850", "2003", "1999"),
  escapement = c(1812L, 2240L, 1907L),
  total_return = c(2011, 2400, 1890),
  mr_1st_sample_size = c(1900, 2000),
  `Water depth (mm)` = c(1850, 1920),
  avg_weight = c(1900, 2100),
  `Water depth(mm)` = c(1850, 1920),
  `adult/count` = c("1850", "2003", "1999")
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
  # measurement word and no date or time word among the name's words, the
  # column takes the role it would take with any other values. So an explicit
  # factor stays categorical and a method-named column stays metadata, exactly
  # as they do off the year range.
  #
  # The last five pass the year-shape check through a punctuation-joined word
  # but are not read as measurements by the checks below it, for any values:
  # three measurement words the substring pattern does not contain, and two
  # method names, which the function's rule keeps out of the measurement role.
  # The year shape does not decide them either (Codex review of #152, rounds 3
  # and 4); what they are is the tokenizer's question, not this test's.
  cases <- c(
    year_shaped_measurements,
    list(
      spawner_count = factor(c("1850", "2003", "1850")),
      count_method = c("1850", "2003", "1850"),
      `adult/spawners` = c(1850, 2003),
      `fish/weight` = c(1900L, 2100L),
      `sample/size` = c("1900", "2000"),
      `method/spawners` = c(1850, 2003),
      `enumeration/abundance` = c(1850, 2003)
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
  for (name in c("method/spawners", "enumeration/abundance")) {
    for (values in list(c(1850, 2003), c(12, 15))) {
      expect_false(
        identical(infer_column_role(name, values), "measurement"),
        info = paste(name, values[[1]])
      )
    }
  }
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

  # And a year word hidden from that token check by punctuation still keeps the
  # year shape deciding. Splitting names at punctuation only to find measurement
  # words would have typed these two `measurement` while `count_year` stays
  # temporal, so the split finds time words too.
  # The plurals the token check leaves out count as time words here too
  # (Codex review of #152, round 4).
  hidden_year_word <- list(
    `Escapement (yr)` = c(2001, 2002),
    `count/year` = c("2001", "2002"),
    escapement_years = c(2001, 2002),
    count_days = c("2001", "2002")
  )
  for (name in names(hidden_year_word)) {
    values <- hidden_year_word[[name]]
    expect_true(.ms_values_look_yearish(values), info = name)
    expect_identical(infer_column_role(name, values), "temporal", info = name)
  }
})

test_that("a name's words are split at punctuation and never at a non-ASCII letter", {
  words <- function(name) .ms_name_words(.ms_name_tokens(name))
  expect_identical(words("Water depth(mm)"), c("water", "depth", "mm"))
  expect_identical(words("adult/count"), c("adult", "count"))
  expect_identical(words("Escapement (yr)"), c("escapement", "yr"))
  expect_identical(words("NATURAL_ADULT_SPAWNERS"), c("natural", "adult", "spawners"))
  expect_identical(.ms_name_words("temp\u00e9rature"), "temp\u00e9rature")
  expect_identical(.ms_name_words(character()), character())
})

test_that("unit and rate headers keep their roles off the year range", {
  # The reason the checks below the year-shape check keep the coarse tokens.
  # Splitting these headers into words for every check -- which is what making
  # the measurement checks read words would require, to keep the checks that
  # outrank them consistent -- typed the first three temporal and the last an
  # identifier (measured 2026-09-24). The year shape is not involved: these are
  # ordinary values.
  values <- c(12.5, 30.1, 44.2)
  expect_identical(infer_column_role("Discharge (m3/day)", values), "measurement")
  expect_identical(infer_column_role("Escapement (fish/yr)", values), "measurement")
  expect_identical(infer_column_role("Rate (per day)", values), "measurement")
  expect_false(identical(infer_column_role("Fish (no./site)", values), "identifier"))
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
