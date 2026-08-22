# Round-trip the shipped examples through the package's own validator.
# Backlog #98/#100: the 30-row sample and its bundled metadata shipped for
# years while failing `validate_salmon_datapackage()` in BOTH modes, because
# no test ever pointed the validator at the artifacts the docs hand a new
# user. These tests are that missing gate.

.read_example_metadata <- function(name) {
  readr::read_csv(
    example_extdata_path(name),
    show_col_types = FALSE,
    col_types = readr::cols(.default = readr::col_character())
  )
}

.build_tiny_example_package <- function(path) {
  data <- .read_example_metadata("nuseds-fraser-coho-sample.csv")
  suppressMessages(write_salmon_datapackage(
    resources = list(nuseds_fraser_coho = data),
    dataset_meta = .read_example_metadata("dataset.csv"),
    table_meta = .read_example_metadata("tables.csv"),
    dict = .read_example_metadata("column_dictionary.csv"),
    codes = .read_example_metadata("codes.csv"),
    path = path,
    overwrite = TRUE
  ))
  path
}

test_that("the 30-row example and its bundled dictionary pass lenient validation", {
  skip_if_not_installed("readr")

  pkg_path <- .build_tiny_example_package(withr::local_tempdir())

  # Backlog #98: this aborted with 2 structural issues -- START_DTT/END_DTT
  # declared `value_type: date` over Oracle DD-MON-YY bytes.
  result <- expect_no_error(
    suppressMessages(validate_salmon_datapackage(pkg_path, require_iris = FALSE))
  )
  expect_true(is.list(result))
})
