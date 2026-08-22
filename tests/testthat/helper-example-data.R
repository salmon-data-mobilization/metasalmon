# Shared by test-example-data.R and test-example-round-trip.R. Lives in a
# helper file so both test files resolve the bundled examples whether the
# package is installed or tested from a source checkout.
example_extdata_path <- function(name) {
  installed_path <- system.file("extdata", name, package = "metasalmon")
  if (nzchar(installed_path)) {
    return(installed_path)
  }

  testthat::test_path("..", "..", "inst", "extdata", name)
}
