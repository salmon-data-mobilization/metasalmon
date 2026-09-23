# A written package's temporal fields, checked against the pattern the SDP
# profile itself declares for them. Hub item B-198.
#
# WHY THIS FILE EXISTS. Every other check on these two fields compares one
# writer with another -- `datapackage.json` against `metadata/dataset.csv`
# (test-canonical-date-render.R, hub item B-115) -- or a writer against the
# ruled spelling. Nothing compared either file with the profile's own
# `constraints.pattern`. So when the descriptor began writing a typed instant,
# the two files agreed with each other while both broke the profile, and the
# break went unseen through two implementations and four reviews (the Q-51
# passage in knowledge/backlog.md). Two writers agreeing does not make either
# of them conform; these tests check conformance.
#
# The pattern is READ from the vendored bundle through the package's own
# vendored loader, never typed here. A regex copied into this file would pass
# against itself whatever the bundle said, and that is exactly the comparison
# that was missing.
#
# FOUR-DIGIT YEARS ONLY, ON PURPOSE. On Linux, readr writes a pre-1000 instant
# with an unpadded year (`999-06-05T13:45:30Z`), which the pattern rejects.
# Which bytes the ecosystem should write there is hub item B-161 (Brett's, and
# unruled), and this package's emission half is B-206. A four-digit year keeps
# these tests off that platform-dependent case instead of pinning a rendering
# nobody has ruled on. *The exclusion retires when:* B-161 is ruled and B-206
# emits the ruled pre-1000 spelling. At that point a pre-1000 instant belongs in
# the first test below, and the pattern it is checked against may have changed.
#
# *Retires when:* nothing. When `validate_salmon_datapackage()` enforces
# `constraints.pattern` (hub item B-204), that is a second and more general
# check of the same property. These tests stay, because they pin the writer
# and the vendored bundle to each other without depending on the validator
# being right.

# Full-match semantics, which is how the specification's own validator applies
# a pattern (`re.fullmatch` in smn-data-pkg's scripts/validate_package.py).
# PCRE's `$` also matches just before a trailing newline, so `\z` is what makes
# this a full match rather than an almost-full one.
matches_profile_pattern <- function(pattern, value) {
  grepl(paste0("^(?:", pattern, ")\\z"), value, perl = TRUE)
}

vendored_dataset_field_pattern <- function(field_name) {
  bundle <- metasalmon:::.ms_load_vendored_sdp_schema()
  field <- purrr::detect(
    bundle$metadata_schemas$dataset$fields,
    ~ identical(.x$name, field_name)
  )
  pattern <- field$constraints$pattern
  # A bundle that dropped the pattern must fail here. It must not make every
  # value pass by default.
  expect_type(pattern, "character")
  expect_length(pattern, 1L)
  pattern
}

test_that("the temporal instants a written package carries satisfy the vendored profile pattern", {
  # The condition B-198 retires on. It pins what the WRITER emits against the
  # vendored pattern. Making the VALIDATOR read `constraints.pattern` at all is
  # B-204's job, not this test's.
  #
  # FAILING-BEFORE, measured 2026-09-23 on the unchanged tree (R 4.3.3, readr
  # 2.2.0): the vendored pattern was still the pre-ruling
  # `^(\d{4}|\d{4}-\d{2}-\d{2})$`, so both instants failed it in both files,
  # while B-115's agreement test passed on the same tree.
  skip_if_not_installed("readr")

  start_pattern <- vendored_dataset_field_pattern("temporal_start")
  end_pattern <- vendored_dataset_field_pattern("temporal_end")

  path <- withr::local_tempdir()
  suppressMessages(write_salmon_datapackage(
    resources = list(obs = data.frame(site_id = c("s1", "s2"), stringsAsFactors = FALSE)),
    dataset_meta = tibble::tibble(
      dataset_id = "d1",
      title = "T",
      description = "D",
      creator = "metasalmon tests",
      # The two instants the ruled profile gives as its own `sdp:examples`
      # (smn-data-pkg f86d9b4). The end is supplied in Vancouver time on
      # purpose, because the pattern admits only the `Z` zone marker. A writer
      # that kept the caller's offset would fail here.
      temporal_start = as.POSIXct("1996-01-01 00:00:00", tz = "UTC"),
      temporal_end = as.POSIXct("2024-12-31 15:59:59", tz = "America/Vancouver")
    ),
    table_meta = tibble::tibble(
      dataset_id = "d1", table_id = "obs", file_name = "data/obs.csv",
      table_label = "Observations", description = "One site column"
    ),
    dict = tibble::tibble(
      dataset_id = "d1", table_id = "obs", column_name = "site_id",
      column_label = "Site", column_description = "Site identifier",
      column_role = "identifier", value_type = "string", required = FALSE
    ),
    path = path,
    overwrite = TRUE
  ))

  descriptor <- jsonlite::read_json(file.path(path, "datapackage.json"))
  dataset_csv <- readr::read_csv(
    file.path(path, "metadata", "dataset.csv"),
    col_types = readr::cols(.default = readr::col_character())
  )

  # The values under test are typed instants, not dates that slipped through.
  # The date branch of the pattern would accept a date, so without these two
  # lines a writer that dropped the time would pass unnoticed.
  expect_identical(descriptor$temporal$start[[1]], "1996-01-01T00:00:00Z")
  expect_identical(descriptor$temporal$end[[1]], "2024-12-31T23:59:59Z")

  # The descriptor instant satisfies the pattern the vendored profile declares.
  expect_true(matches_profile_pattern(start_pattern, descriptor$temporal$start[[1]]))
  expect_true(matches_profile_pattern(end_pattern, descriptor$temporal$end[[1]]))

  # So does the CSV, which is the file the pattern is declared on.
  expect_true(matches_profile_pattern(start_pattern, dataset_csv$temporal_start[[1]]))
  expect_true(matches_profile_pattern(end_pattern, dataset_csv$temporal_end[[1]]))
})

test_that("the profile-pattern check can fail: it rejects the spellings the ruling excludes", {
  # Without this, the test above could pass vacuously. A matcher that accepted
  # everything, or a pattern read from the wrong field, would pass there
  # without anyone noticing. These are smn-data-pkg's own rejected fixtures
  # (tests/test_validate_package.py at f86d9b4), minus the unpadded year. That
  # one is B-161's question and is deliberately not pinned here.
  pattern <- vendored_dataset_field_pattern("temporal_end")

  rejected <- c(
    "space separator, the descriptor's spelling before B-115" = "2024-12-31 00:00:00",
    "no zone marker" = "2024-12-31T00:00:00",
    "offset zone marker" = "2024-12-31T00:00:00+00:00",
    "fractional second" = "2024-12-31T00:00:00.5Z",
    "partial date" = "1996-01",
    "trailing newline, which PCRE's bare `$` would accept" = "2024-12-31T00:00:00Z\n"
  )
  for (label in names(rejected)) {
    expect_false(matches_profile_pattern(pattern, rejected[[label]]), label = label)
  }
})
