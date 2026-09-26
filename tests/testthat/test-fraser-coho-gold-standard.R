# The Fraser coho gold standard (hub stream S12): the 173-row NuSEDS example,
# built into a complete Salmon Data Package by
# data-raw/fraser_coho_gold_standard.R and shipped as
# inst/extdata/nuseds-fraser-coho-2023-2024-sdp/. Two things keep it from
# rotting: the shipped package must stay clean under strict validation, which
# runs everywhere and offline, and it must stay the package its build script
# writes, which runs wherever data-raw/ exists (a source checkout, so
# devtools::test() and CI's test step, not R CMD check).

.gold_standard_path <- function() {
  example_extdata_path("nuseds-fraser-coho-2023-2024-sdp")
}

.gold_standard_files <- c(
  "datapackage.json",
  "metadata/dataset.csv",
  "metadata/tables.csv",
  "metadata/column_dictionary.csv",
  "metadata/codes.csv",
  "data/escapement.csv"
)

test_that("the gold standard passes strict validation with zero issues", {
  pkg <- .gold_standard_path()
  expect_true(dir.exists(pkg))

  # Strict mode aborts on any unresolved placeholder, REVIEW: marker, blank
  # required field or missing measurement IRI; the semantic checks it runs
  # after that only warn, so they are asserted empty here as well.
  result <- expect_no_warning(suppressMessages(
    validate_salmon_datapackage(pkg, require_iris = TRUE)
  ))
  expect_identical(nrow(result$issues), 0L)
  expect_identical(nrow(result$semantic_validation$issues), 0L)
  expect_identical(nrow(result$semantic_validation$missing_terms), 0L)
})

test_that("the gold standard is a package of its own and holds exactly the canonical files", {
  pkg <- .gold_standard_path()

  # No build sidecar (README-review.txt) and no ownership sentinel
  # (.sdp-package): what ships is the package, not the directory it was built in.
  expect_setequal(
    list.files(pkg, recursive = TRUE, all.files = TRUE),
    .gold_standard_files
  )

  loaded <- suppressMessages(read_salmon_datapackage(pkg))
  ids <- unique(c(
    loaded$dataset$dataset_id,
    loaded$tables$dataset_id,
    loaded$dictionary$dataset_id,
    loaded$codes$dataset_id
  ))
  # Its own dataset_id, not the 30-row sample's `nuseds_fraser_coho_sample`.
  expect_identical(ids, "fraser-coho-2023-2024")
  expect_identical(nrow(loaded$resources$escapement), 173L)

  # The data file is the shipped example, byte for byte.
  data_path <- file.path(pkg, "data", "escapement.csv")
  source_path <- example_extdata_path("nuseds-fraser-coho-2023-2024.csv")
  expect_identical(
    readBin(data_path, "raw", file.size(data_path)),
    readBin(source_path, "raw", file.size(source_path))
  )
})

test_that("the gold standard describes AREA as the NuSEDS sub-district", {
  # Hub item B-401: NuSEDS defines AREA as the subdistrict, and the extract's
  # values (29F, 29G, 29J, 29K) are sub-districts, not PFMA Subareas.
  dict <- suppressMessages(read_salmon_datapackage(.gold_standard_path()))$dictionary
  area <- dict[dict$column_name == "AREA", , drop = FALSE]
  expect_identical(area$column_label, "Sub-district")
  expect_match(area$column_description, "sub-district", fixed = TRUE)
  expect_false(grepl("Pacific Fishery Management Area code", area$column_description, fixed = TRUE))
  expect_true(is.na(area$term_iri) || !nzchar(area$term_iri))
})

test_that("the shipped gold standard is exactly what its data-raw script builds", {
  script <- testthat::test_path("..", "..", "data-raw", "fraser_coho_gold_standard.R")
  # Skipped under R CMD check, which runs the installed package and has no
  # data-raw/; CI's devtools::test() step runs it. Retires when the build
  # script is installed with the package, for example from inst/.
  skip_if_not(file.exists(script), "data-raw/ is not part of the built package")

  env <- new.env(parent = globalenv())
  sys.source(script, envir = env)
  expect_identical(env$gold_standard_files, .gold_standard_files)

  out <- file.path(withr::local_tempdir(), "sdp")
  env$build_fraser_coho_gold_standard(
    out,
    source_csv = example_extdata_path("nuseds-fraser-coho-2023-2024.csv")
  )

  shipped <- .gold_standard_path()
  expect_setequal(list.files(out, recursive = TRUE, all.files = TRUE), .gold_standard_files)
  for (file in .gold_standard_files) {
    rebuilt_path <- file.path(out, file)
    shipped_path <- file.path(shipped, file)
    # A difference means the script or the package changed without the other:
    # rerun `Rscript data-raw/fraser_coho_gold_standard.R` and review the diff.
    expect_identical(
      readBin(rebuilt_path, "raw", file.size(rebuilt_path)),
      readBin(shipped_path, "raw", file.size(shipped_path)),
      label = file
    )
  }
})
