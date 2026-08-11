# The suite's skips are load-bearing, and one set of them was hiding real
# coverage rather than reflecting an environment limitation.
#
# `R-CMD-check.yaml` installed only `devtools` and `rcmdcheck`, so `{dataone}`
# and `{datapack}` were absent in CI as well as on most development machines.
# Five tests of the DataONE adapter boundary -- the code that talks to the
# repository during live publication, the highest-consequence path in the
# package -- therefore skipped on every machine, silently, and had never
# executed. They pass; nobody knew.
#
# The distinction this file encodes: locally, a missing optional package is an
# environment fact and skipping is correct. In CI it is a workflow regression
# and must fail. Keep this list in step with `extra-packages` in
# `.github/workflows/R-CMD-check.yaml`.
#
# Not covered here, deliberately: the four Theme A integrity tests skip under
# `R-CMD-check.yaml` by design and run in `theme-a-integrity.yaml`, which sets
# `METASALMON_RUN_THEME_A_INTEGRITY=true`. A CI run of the check workflow should
# therefore report exactly those four skips.
ci_provided_packages <- c(
  "frictionless",
  "withr",
  "pdftools",
  "readxl",
  "openxlsx",
  "emld",
  "jsonvalidate",
  "dataone",
  "datapack",
  "XML"
)

test_that("every CI-provided package is declared in Suggests", {
  # Runs everywhere, so the list above cannot drift into naming a package the
  # package itself never declares.
  declared <- packageDescription("metasalmon")$Suggests
  expect_false(is.null(declared))

  declared <- trimws(gsub("[(][^)]*[)]", "", strsplit(declared, ",")[[1]]))
  expect_identical(setdiff(ci_provided_packages, declared), character())
})

test_that("CI installs every optional package the suite needs", {
  skip_if_not(
    isTRUE(as.logical(Sys.getenv("CI", "false"))),
    "not CI: a missing optional package here is an environment fact, not a regression"
  )

  missing <- ci_provided_packages[
    !vapply(ci_provided_packages, requireNamespace, logical(1), quietly = TRUE)
  ]
  expect_identical(missing, character())
})
