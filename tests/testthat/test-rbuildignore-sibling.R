# B-268: CI checks metasalmonpy out under the package root so the register
# guard can read it. R CMD build must leave that checkout out of the source
# tarball. This exclusion retires if CI moves the checkout outside this root.

test_that("the CI sibling checkout is absent from a source tarball", {
  buildignore <- testthat::test_path("..", "..", ".Rbuildignore")
  # The CI workflow runs devtools::test() from the source tree. R CMD check may
  # run this test from a built copy without the source-only .Rbuildignore, so
  # that copy reports a skip rather than pretending it checked the exclusion.
  # Retires when a check copy can read the authoritative build-ignore rules.
  skip_if_not(file.exists(buildignore), ".Rbuildignore is absent from this check copy")

  root <- withr::local_tempdir()
  fixture <- file.path(root, "b268fixture")
  dir.create(fixture)
  writeLines(c(
    "Package: b268fixture",
    "Title: Build Ignore Fixture",
    "Version: 0.0.1",
    'Authors@R: person("Test", "Fixture", email = "test@example.org", role = c("aut", "cre"))',
    "Description: Checks a source package build exclusion.",
    "License: MIT",
    "Encoding: UTF-8"
  ), file.path(fixture, "DESCRIPTION"))
  writeLines('exportPattern(".")', file.path(fixture, "NAMESPACE"))
  dir.create(file.path(fixture, "R"))
  writeLines("fixture <- function() TRUE", file.path(fixture, "R", "fixture.R"))
  dir.create(file.path(fixture, "inst"))
  writeLines("keep", file.path(fixture, "inst", "keep.txt"))
  file.copy(buildignore, file.path(fixture, ".Rbuildignore"))

  sibling <- file.path(fixture, ".metasalmonpy-sibling")
  dir.create(sibling)
  sentinel <- file.path(sibling, "sentinel.txt")
  writeLines("sibling checkout", sentinel)
  expect_true(file.exists(sentinel))

  withr::local_dir(root)
  output <- suppressWarnings(system2(
    file.path(R.home("bin"), "R"),
    c("CMD", "build", shQuote(fixture)),
    stdout = TRUE,
    stderr = TRUE
  ))
  status <- attr(output, "status")
  if (is.null(status)) status <- 0L
  expect_identical(status, 0L, info = paste(output, collapse = "\n"))

  archive <- file.path(root, "b268fixture_0.0.1.tar.gz")
  expect_true(file.exists(archive), info = paste(output, collapse = "\n"))
  if (file.exists(archive)) {
    members <- utils::untar(archive, list = TRUE)
    expect_true("b268fixture/inst/keep.txt" %in% members)
    expect_false(any(grepl(".metasalmonpy-sibling", members, fixed = TRUE)))
  }
})
