# Backlog #95 (queue B-95), ruled Q29 on 2026-09-05: a column that has a code
# list is categorical by the specification's own definition, and the code-row
# seeder is downstream of that decision. `create_sdp()` used to write
# `column_role = "attribute"` and `codes.csv` rows for the same column in one
# call and print "Dictionary validation passed" between them; the
# specification's validator (`scripts/validate_package.py` in smn-data-pkg)
# reports each such row as "targets a non-categorical or unknown column" --
# 22 rows across six columns on the 173-row gold standard.
#
# `codes_rows_off_categorical()` is that validator's `validate_codes` rule
# applied in R: every codes.csv row's (dataset_id, table_id, column_name) must
# name a dictionary row whose column_role is "categorical". It is applied to
# the generator's own output on both bundled examples, so a regression in
# either the role heuristic or the seeder fails here rather than in a sibling
# repository's validator. metasalmon's own `validate_salmon_datapackage()` does
# not report this class yet (backlog #48/#49, stream S1); when it does, the
# helper below can go and the create_sdp() tests can assert on the validator.

codes_rows_off_categorical <- function(pkg_path) {
  read_meta <- function(name) {
    readr::read_csv(
      file.path(pkg_path, "metadata", name),
      col_types = readr::cols(.default = readr::col_character()),
      show_col_types = FALSE
    )
  }
  dict <- read_meta("column_dictionary.csv")
  codes <- read_meta("codes.csv")
  key <- function(x) paste(x$dataset_id, x$table_id, x$column_name, sep = "\r")
  categorical_keys <- key(dict)[dict$column_role %in% "categorical"]
  list(
    dict = dict,
    codes = codes,
    offending = codes[!key(codes) %in% categorical_keys, , drop = FALSE]
  )
}

build_example_sdp <- function(file, dataset_id, table_id, dir) {
  df <- readr::read_csv(example_extdata_path(file), show_col_types = FALSE)
  suppressMessages(suppressWarnings(create_sdp(
    df,
    path = file.path(dir, dataset_id),
    dataset_id = dataset_id,
    table_id = table_id,
    seed_semantics = FALSE,
    seed_verbose = FALSE,
    check_updates = FALSE,
    overwrite = TRUE
  )))
}

test_that("infer_column_role types an enumerable string column categorical", {
  enumerable <- rep(c("29F", "29G", "29J", "29K"), length.out = 40)
  expect_equal(infer_column_role("AREA", enumerable), "categorical")
  expect_equal(infer_column_role("SPECIES", rep("Coho", 12)), "categorical")
  expect_equal(infer_column_role("RUN_TYPE", c("1", "FALL", NA, "1")), "categorical")
  expect_equal(infer_column_role("ESTIMATE_STAGE", c("FINAL", "NEAR FINAL")), "categorical")

  # Method-named columns whose values enumerate are code lists too; their
  # procedures resolve through codes.csv$term_iri.
  expect_equal(
    infer_column_role("ESTIMATE_METHOD", c("Fence", "Area Under the Curve", "Fence")),
    "categorical"
  )
  expect_equal(
    infer_column_role("ENUMERATION_METHODS", c("Bank Walk", "Dead Pitch", NA)),
    "categorical"
  )

  # The identifier-qualifier branch reads the same predicate.
  expect_equal(infer_column_role("stock_ID_quality", c("high", "low", "high")), "categorical")
  expect_equal(infer_column_role("stock_ID_quality", c(2, 3, NA_real_)), "attribute")
})

test_that("infer_column_role keeps free text and wide code sets as attribute", {
  # More distinct values than the seeder will list is not a code list.
  wide <- sprintf("WATERBODY %02d", seq_len(.ms_code_list_limit() + 1L))
  expect_equal(infer_column_role("WATERBODY", wide), "attribute")
  expect_equal(infer_column_role("counting_method", wide), "attribute")

  # A column with no non-missing values has no code list either.
  expect_equal(infer_column_role("notes", c(NA_character_, NA_character_)), "attribute")

  # The boundary is the seeder's own limit, on both sides of it.
  at_limit <- sprintf("code-%02d", seq_len(.ms_code_list_limit()))
  expect_equal(infer_column_role("flag", at_limit), "categorical")
})

test_that("identifier, temporal and measurement verdicts run ahead of the code-list check", {
  few <- c("A", "B", "A", "C")
  expect_equal(infer_column_role("site_id", few), "identifier")
  expect_equal(infer_column_role("sample_reference_number", few), "identifier")
  expect_equal(infer_column_role("survey_date", c("2024-01-01", "2024-01-02")), "temporal")
  expect_equal(infer_column_role("ANALYSIS_YR", c("2023", "2024", "2023")), "temporal")
  expect_equal(infer_column_role("run", factor(c("early", "late"))), "categorical")

  # A percent-like or unit-bearing text column is a measurement even when its
  # values repeat; the seeder still lists such values, and that residual
  # inconsistency is the seeder's half of #95, not this heuristic's.
  expect_equal(infer_column_role("Environmental (%/month)", c("0.00%", "4.56%")), "measurement")
  expect_equal(infer_column_role("spawner_count", c("12", "15", "12")), "measurement")
})

test_that("the role heuristic and the code-row seeder share one code-list decision", {
  resources <- list(
    escapement = tibble::tibble(
      POP_ID = c(1L, 2L, 3L),
      AREA = c("29F", "29G", "29F"),
      WATERBODY = sprintf("STREAM %02d", seq_len(3)),
      ESTIMATE_METHOD = c("Fence", "Fence", "Area Under the Curve"),
      NATURAL_ADULT_SPAWNERS = c(10, 20, 30),
      RELIABILITY = factor(c("LOW", "HIGH", "LOW"))
    )
  )
  wide_codes <- tibble::tibble(
    STATION = sprintf("station-%02d", seq_len(.ms_code_list_limit() + 1L)),
    STAGE = rep("FINAL", .ms_code_list_limit() + 1L)
  )
  resources$stations <- wide_codes

  artifacts <- infer_salmon_datapackage_artifacts(
    resources,
    dataset_id = "b95-demo",
    seed_semantics = FALSE,
    seed_verbose = FALSE
  )
  dict <- artifacts$dict
  codes <- artifacts$codes

  seeded <- unique(paste(codes$table_id, codes$column_name, sep = "\r"))
  categorical <- paste(dict$table_id, dict$column_name, sep = "\r")[
    dict$column_role %in% "categorical"
  ]
  # Every seeded column is categorical, and every categorical column is seeded.
  expect_setequal(seeded, categorical)
  expect_setequal(
    codes$column_name,
    c("AREA", "WATERBODY", "ESTIMATE_METHOD", "RELIABILITY", "STAGE")
  )
  expect_equal(dict$column_role[dict$column_name == "STATION"], "attribute")
  expect_equal(dict$column_role[dict$column_name == "POP_ID"], "identifier")
  expect_equal(dict$column_role[dict$column_name == "NATURAL_ADULT_SPAWNERS"], "measurement")
})

test_that("create_sdp() seeds no codes.csv row for a non-categorical column on the 173-row gold standard", {
  pkg_path <- build_example_sdp(
    "nuseds-fraser-coho-2023-2024.csv",
    dataset_id = "fraser-coho-2023-2024",
    table_id = "escapement",
    dir = withr::local_tempdir()
  )
  got <- codes_rows_off_categorical(pkg_path)

  # The six columns the backlog names, so the check cannot pass by seeding nothing.
  expect_setequal(
    unique(got$codes$column_name),
    c("AREA", "SPECIES", "RUN_TYPE", "ESTIMATE_METHOD", "ESTIMATE_CLASSIFICATION", "ESTIMATE_STAGE")
  )
  expect_equal(
    got$dict$column_role[got$dict$column_name %in% unique(got$codes$column_name)],
    rep("categorical", 6)
  )
  expect_equal(nrow(got$offending), 0L, info = paste(
    "codes.csv rows targeting non-categorical columns:",
    paste(unique(got$offending$column_name), collapse = ", ")
  ))
})

test_that("date and date-time text seeds no code list unless declared as a factor", {
  # These are readr's guesses pinned in the mirror's B-188 test: date shape
  # alone includes invalid calendar dates, while date-time fields must parse.
  # Whitespace and blank cells do not turn an otherwise date column into codes.
  dates <- c("2001-11-06", "2001/11/07", "2001-02-30", NA_character_)
  expect_identical(.ms_code_list_values(dates), character())
  expect_identical(.ms_code_list_values(c(" 2001-11-06\t", "\r\n")), character())
  expect_identical(
    .ms_code_list_values(c("2001-11-06", "2001-11-07T10:00:00Z", "")),
    character()
  )

  # The caller's categorical declaration wins over date-looking levels, as
  # Python's Categorical does. Kept values retain their original byte/order.
  factor_dates <- factor(c("2001-11-07", "2001-11-06", "2001-11-07"))
  expect_identical(.ms_code_list_values(factor_dates), c("2001-11-07", "2001-11-06"))
  mixed <- c("2001-11-06", "unknown", "2001-11-06")
  expect_identical(.ms_code_list_values(mixed), c("2001-11-06", "unknown"))
  expect_identical(.ms_code_list_values(c("2001-11-06", "NA")), c("2001-11-06", "NA"))
  expect_identical(.ms_code_list_values("2001-02-30T10:00:00"), "2001-02-30T10:00:00")
  expect_identical(.ms_code_list_values("10:00:00"), "10:00:00")
  expect_identical(.ms_code_list_values(c(" ", "")), c(" ", ""))
  expect_false(infer_column_role("SURVEY_WAVE", c("2001-11-06", "2001-11-07")) == "categorical")
})

test_that("create_sdp() seeds no date-text codes on the all-character bundled sample", {
  # B-310's reproduction deliberately bypasses readr's type guess. Other
  # numeric text columns retain separate known debt, so assert on the dates
  # and a known categorical positive control rather than the whole package.
  df <- readr::read_csv(
    example_extdata_path("nuseds-fraser-coho-sample.csv"),
    col_types = readr::cols(.default = readr::col_character()),
    show_col_types = FALSE
  )
  expect_type(df$START_DTT, "character")
  expect_type(df$END_DTT, "character")
  pkg_path <- file.path(withr::local_tempdir(), "b310-all-character")
  suppressMessages(suppressWarnings(create_sdp(
    df, path = pkg_path, dataset_id = "b310-all-character", table_id = "escapement",
    seed_semantics = FALSE, seed_verbose = FALSE, check_updates = FALSE
  )))
  got <- codes_rows_off_categorical(pkg_path)
  expect_true("SPECIES" %in% got$codes$column_name)
  expect_true("Coho" %in% got$codes$code_value[got$codes$column_name == "SPECIES"])
  expect_false(any(got$codes$column_name %in% c("START_DTT", "END_DTT")))
  expect_true(all(got$dict$column_role[
    got$dict$column_name %in% c("START_DTT", "END_DTT")
  ] == "temporal"))
})

test_that("create_sdp() seeds no codes.csv row for a non-categorical column on the 30-row sample", {
  pkg_path <- build_example_sdp(
    "nuseds-fraser-coho-sample.csv",
    dataset_id = "nuseds_fraser_coho_sample",
    table_id = "nuseds_fraser_coho",
    dir = withr::local_tempdir()
  )
  got <- codes_rows_off_categorical(pkg_path)

  expect_gt(nrow(got$codes), 0L)
  expect_equal(nrow(got$offending), 0L, info = paste(
    "codes.csv rows targeting non-categorical columns:",
    paste(unique(got$offending$column_name), collapse = ", ")
  ))
})
