# A Date-typed `temporal_start` must not destroy the package already on disk.
# Backlog #96: `dataset_meta$temporal_start[1] != ""` compares a Date with "",
# which coerces "" to `NA_Date_`; the `&&` evaluates to NA and `if` aborts with
# "missing value where TRUE/FALSE needed" -- AFTER `write_salmon_datapackage()`
# has unlinked every managed path and BEFORE it has written any replacement.
# The triggering input is what the package itself wrote: `readr::read_csv()`
# type-guesses `temporal_start` as Date because metasalmon put an ISO date
# there.

.typed_meta_fixture <- function() {
  list(
    resources = list(
      obs = data.frame(site_id = c("s1", "s2"), stringsAsFactors = FALSE)
    ),
    dataset_meta = tibble::tibble(
      dataset_id = "d1",
      title = "Typed metadata survives",
      description = "Regression for backlog #96",
      creator = "metasalmon tests",
      contact_name = "Test Contact",
      contact_email = "test@example.org",
      contact_org = "Test Org",
      license = "CC-BY-4.0",
      temporal_start = "2001-01-01",
      temporal_end = "2002-06-30"
    ),
    table_meta = tibble::tibble(
      dataset_id = "d1",
      table_id = "obs",
      file_name = "data/obs.csv",
      table_label = "Observations",
      description = "One site column"
    ),
    dict = tibble::tibble(
      dataset_id = "d1",
      table_id = "obs",
      column_name = "site_id",
      column_label = "Site",
      column_description = "Site identifier",
      column_role = "identifier",
      value_type = "string",
      required = FALSE
    )
  )
}

test_that("a Date-typed temporal_start/temporal_end round-trips and the package survives", {
  skip_if_not_installed("readr")

  path <- withr::local_tempdir()
  fixture <- .typed_meta_fixture()

  # First write: all-character metadata, exactly what the package produces.
  suppressMessages(write_salmon_datapackage(
    resources = fixture$resources,
    dataset_meta = fixture$dataset_meta,
    table_meta = fixture$table_meta,
    dict = fixture$dict,
    path = path,
    overwrite = TRUE
  ))
  expect_true(file.exists(file.path(path, "datapackage.json")))

  # Read the package's own metadata back the way a caller plausibly would:
  # plain readr, no column-type pinning. This is the read that type-guesses.
  dataset_meta <- readr::read_csv(
    file.path(path, "metadata", "dataset.csv"),
    show_col_types = FALSE
  )
  # Guard the premise, not just the outcome: if readr ever stops guessing Date
  # here, force the trigger instead of silently testing nothing.
  if (!inherits(dataset_meta$temporal_start, "Date")) {
    dataset_meta$temporal_start <- as.Date(dataset_meta$temporal_start)
    dataset_meta$temporal_end <- as.Date(dataset_meta$temporal_end)
  }
  table_meta <- readr::read_csv(
    file.path(path, "metadata", "tables.csv"),
    show_col_types = FALSE
  )
  dict <- readr::read_csv(
    file.path(path, "metadata", "column_dictionary.csv"),
    show_col_types = FALSE
  )

  expect_no_error(suppressMessages(write_salmon_datapackage(
    resources = fixture$resources,
    dataset_meta = dataset_meta,
    table_meta = table_meta,
    dict = dict,
    path = path,
    overwrite = TRUE
  )))

  # The defect deleted these and aborted before writing replacements.
  expect_true(file.exists(file.path(path, "datapackage.json")))
  expect_true(file.exists(file.path(path, "metadata", "dataset.csv")))
  expect_true(file.exists(file.path(path, "metadata", "tables.csv")))
  expect_true(file.exists(file.path(path, "metadata", "column_dictionary.csv")))

  descriptor <- jsonlite::read_json(file.path(path, "datapackage.json"))
  expect_identical(descriptor$temporal$start, "2001-01-01")
  expect_identical(descriptor$temporal$end, "2002-06-30")

  rewritten <- readr::read_csv(
    file.path(path, "metadata", "dataset.csv"),
    show_col_types = FALSE
  )
  expect_identical(as.character(rewritten$temporal_start[[1]]), "2001-01-01")
  expect_identical(as.character(rewritten$temporal_end[[1]]), "2002-06-30")
})

test_that("typed scalar metadata fields do not abort the descriptor builder", {
  skip_if_not_installed("readr")

  # The same `!= ""` shape guards creator/contact/license/table_label above and
  # below the temporal block. A POSIXct's comparison with "" does not even
  # yield NA -- it throws -- so the field must be rendered, not compared raw.
  path <- withr::local_tempdir()
  fixture <- .typed_meta_fixture()
  fixture$dataset_meta$temporal_start <- as.POSIXct("2001-01-01 00:00:00", tz = "UTC")
  fixture$dataset_meta$temporal_end <- as.POSIXct("2002-06-30 00:00:00", tz = "UTC")

  expect_no_error(suppressMessages(write_salmon_datapackage(
    resources = fixture$resources,
    dataset_meta = fixture$dataset_meta,
    table_meta = fixture$table_meta,
    dict = fixture$dict,
    path = path,
    overwrite = TRUE
  )))
  expect_true(file.exists(file.path(path, "datapackage.json")))
})
