# A Date column must survive write -> read unchanged, including a year below
# 1000. It did not: `readr::write_csv()` renders a Date through
# `as.character.Date`, whose R-4.3 fast path emits an unpadded year on EVERY
# platform, and `readr::parse_date("1-01-01")` returns NA -- so the package
# could not read back what it had just written. Backlog #93 item 1.
#
# Distinct from the `%Y`/glibc split in #91: that one disagreed between macOS
# and Linux, this one is wrong everywhere, so no amount of cross-platform CI
# would surface it.

test_that("a Date column round-trips for a year below 1000", {
  skip_if_not_installed("readr")

  path <- withr::local_tempdir()
  observations <- data.frame(
    site_id = c("s1", "s2", "s3"),
    observed_on = as.Date(c("0001-01-01", "0999-12-31", "2024-01-31")),
    stringsAsFactors = FALSE
  )

  suppressMessages(create_sdp(
    observations,
    path = path,
    dataset_id = "dates",
    table_id = "obs",
    seed_semantics = FALSE,
    overwrite = TRUE
  ))

  written <- readLines(file.path(path, "data", "obs.csv"))
  expect_true(any(grepl("0001-01-01", written, fixed = TRUE)))
  expect_false(any(grepl("(^|,)1-01-01(,|$)", written)))

  back <- read_salmon_datapackage(path)
  expect_identical(back$resources$obs$observed_on, observations$observed_on)
})

test_that("the Date renderer leaves every other column's bytes alone", {
  skip_if_not_installed("readr")

  # The risk the narrow fix exists to avoid: readr's POSIXct output is already
  # correct, and coercing it would change the separator, the zone marker, and
  # whether a fractional second survives.
  frame <- data.frame(
    d_modern = as.Date("2024-01-31"),
    ts = as.POSIXct("2024-01-31 10:00:00.5", tz = "UTC"),
    n = 1.5,
    i = 2L,
    b = TRUE,
    s = "text",
    stringsAsFactors = FALSE
  )
  expect_identical(
    readr::format_csv(.ms_iso_date_columns(frame)),
    readr::format_csv(frame)
  )
})

test_that("a missing Date is still written as the package's NA token", {
  skip_if_not_installed("readr")

  frame <- data.frame(d = as.Date(c("0001-01-01", NA)))
  out <- readr::format_csv(
    .ms_iso_date_columns(frame),
    na = .ms_csv_na_token()
  )
  expect_identical(
    out,
    readr::format_csv(
      data.frame(d = c("0001-01-01", NA_character_)),
      na = .ms_csv_na_token()
    )
  )
})
