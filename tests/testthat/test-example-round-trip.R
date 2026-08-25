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

test_that("the 30-row example passes STRICT validation with zero issues", {
  skip_if_not_installed("readr")

  pkg_path <- .build_tiny_example_package(withr::local_tempdir())

  # The tiny example is the walkthrough artifact, so it must clear the
  # package's final gate completely. Its last strict blocker -- a blank
  # `tables.csv$observation_unit_iri` -- was filled with the released
  # `smn:EscapementEstimate` (the IRI for the `EscapementEstimate`
  # observation unit the row already declared). If this test starts
  # reporting issues, the shipped artifacts drifted; fix them, do not relax
  # this assertion.
  result <- expect_no_error(
    suppressMessages(validate_salmon_datapackage(pkg_path, require_iris = TRUE))
  )
  expect_identical(nrow(result$issues), 0L)
})

test_that("the shipped example metadata CSVs are well-formed", {
  skip_if_not_installed("readr")

  # The shipped codes.csv declared 9 header columns while every data row had
  # 8 fields, so each read emitted 26 parsing problems that every caller had
  # to suppress. Any shipped metadata file must parse clean.
  for (file in c(
    "dataset.csv", "tables.csv", "column_dictionary.csv", "codes.csv",
    "nuseds-fraser-coho-sample.csv",
    "nuseds-fraser-coho-2023-2024.csv",
    "nuseds-fraser-coho-2023-2024-column_dictionary.csv"
  )) {
    df <- readr::read_csv(
      example_extdata_path(file),
      show_col_types = FALSE,
      col_types = readr::cols(.default = readr::col_character())
    )
    expect_identical(nrow(readr::problems(df)), 0L, label = file)
  }
})

test_that("the fuller example with its starter dictionary validates as documented", {
  skip_if_not_installed("readr")

  # The 173-row example is documented as a STARTER whose one measurement row is
  # fully annotated (see inst/extdata/example-data-README.md). Lenient passes.
  # Strict fails -- but on the `MISSING METADATA:` placeholders `create_sdp()`
  # writes, NOT on a missing measurement IRI, and it passes once those are
  # resolved. Pinning both halves catches drift in either direction: an IRI
  # regression would reintroduce the term_iri failure, and a placeholder
  # regression would break the second half.
  tmp <- withr::local_tempdir()
  fuller <- readr::read_csv(
    example_extdata_path("nuseds-fraser-coho-2023-2024.csv"),
    show_col_types = FALSE
  )
  pkg_path <- suppressMessages(suppressWarnings(create_sdp(
    fuller,
    path = file.path(tmp, "fraser-coho-fuller"),
    dataset_id = "fraser-coho-2023-2024",
    table_id = "escapement",
    seed_semantics = FALSE,
    check_updates = FALSE,
    overwrite = TRUE
  )))
  # Install the shipped starter dictionary, as the README walkthrough does.
  file.copy(
    example_extdata_path("nuseds-fraser-coho-2023-2024-column_dictionary.csv"),
    file.path(pkg_path, "metadata", "column_dictionary.csv"),
    overwrite = TRUE
  )

  expect_no_error(suppressMessages(suppressWarnings(
    validate_salmon_datapackage(pkg_path, require_iris = FALSE)
  )))

  strict_error <- expect_error(
    suppressMessages(suppressWarnings(
      validate_salmon_datapackage(pkg_path, require_iris = TRUE)
    ))
  )
  # The remaining strict failures are placeholders the reviewer must resolve,
  # not unresolved semantics.
  expect_match(
    conditionMessage(strict_error),
    "unresolved review placeholder"
  )
  expect_false(
    grepl(
      "Measurement columns require term_iri",
      conditionMessage(strict_error),
      fixed = TRUE
    )
  )

  # Resolving exactly the placeholders -- no semantic edits -- takes the shipped
  # example through the strict gate. This is what makes it the gold standard.
  dataset_meta <- readr::read_csv(
    file.path(pkg_path, "metadata", "dataset.csv"),
    col_types = readr::cols(.default = readr::col_character()),
    na = ""
  )
  dataset_meta$description <- "Fraser coho escapement estimates, 2023-2024."
  dataset_meta$creator <- "Example Program"
  dataset_meta$contact_name <- "Example Contact"
  dataset_meta$contact_email <- "contact@example.org"
  dataset_meta$license <- "CC-BY-4.0"
  readr::write_csv(
    dataset_meta,
    file.path(pkg_path, "metadata", "dataset.csv"),
    na = ""
  )

  table_meta <- readr::read_csv(
    file.path(pkg_path, "metadata", "tables.csv"),
    col_types = readr::cols(.default = readr::col_character()),
    na = ""
  )
  table_meta$description <- "One row per population and analysis year."
  table_meta$observation_unit <- "Population-year escapement observation."
  table_meta$observation_unit_iri <- "https://w3id.org/smn/Observation"
  readr::write_csv(
    table_meta,
    file.path(pkg_path, "metadata", "tables.csv"),
    na = ""
  )

  expect_no_error(suppressMessages(suppressWarnings(
    validate_salmon_datapackage(pkg_path, require_iris = TRUE)
  )))
})
