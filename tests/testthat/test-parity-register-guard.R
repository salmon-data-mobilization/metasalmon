# Guard for the twin-register numbering rule in knowledge/parity-deviations.md:
# row numbers are permanent in BOTH registers so the two can be cross-referenced
# by number, and every registered difference appears in both.
#
# Nothing enforced that, and it has failed three times: rows 29/33 (2026-08-17),
# rows 35/41 (2026-08-21), and PARITY.md rows 36-39 sitting in metasalmonpy with
# no hub counterpart at all. All three are set-of-numbers failures, so the check
# is a script rather than prose -- scripts/check-parity-registers.py, which owns
# the parsing and the explanation. This file is only the wiring that runs it
# beside the repository's other guards.
#
# READ THIS BEFORE TRUSTING A GREEN RUN. The check needs BOTH registers, and the
# twin lives in a different repository, so:
#
#   * it skips whenever metasalmonpy is not checked out beside this repo (or
#     named by METASALMONPY_PATH), and
#   * it skips under `R CMD check`, where `knowledge/` and `scripts/` are
#     excluded from the build and neither file exists in the tarball.
#
# That means it does not run in this package's CI as things stand, and a green
# CI is NOT evidence the registers agree. The skip messages say so rather than
# passing quietly, because a guard that silently no-ops is the failure mode
# backlog #89 and #92 both record. Where this runs automatically -- a hub
# workflow that checks out metasalmonpy, a metasalmonpy workflow that checks out
# the hub, or neither -- is an open question nobody has ruled on; until then this
# is a local pre-commit step.
#
# *Retires when:* the two registers live in one repository, at which point this
# becomes an ordinary test that reads both files directly and never skips.

test_that("the two parity registers use the same row numbers", {
  repo_root <- normalizePath(testthat::test_path("..", ".."), mustWork = FALSE)
  script <- file.path(repo_root, "scripts", "check-parity-registers.py")
  hub <- file.path(repo_root, "knowledge", "parity-deviations.md")

  if (!file.exists(script) || !file.exists(hub)) {
    skip(paste(
      "NOT CHECKED: knowledge/ and scripts/ are excluded from R CMD build, so",
      "the registers are absent from an installed/checked package. Run",
      "`python3 scripts/check-parity-registers.py` from a source checkout."
    ))
  }

  python <- Sys.which("python3")
  if (!nzchar(python)) {
    skip("NOT CHECKED: python3 is not on PATH, so the register check cannot run.")
  }

  twin_root <- Sys.getenv("METASALMONPY_PATH", unset = "")
  if (!nzchar(twin_root)) {
    twin_root <- file.path(dirname(repo_root), "metasalmonpy")
  }
  twin <- file.path(twin_root, "PARITY.md")
  if (!file.exists(twin)) {
    skip(paste0(
      "NOT CHECKED: metasalmonpy's PARITY.md was not found at '", twin,
      "'. A missing twin is not agreement -- check metasalmonpy out beside this",
      " repo, or set METASALMONPY_PATH."
    ))
  }

  result <- suppressWarnings(system2(
    python,
    c(shQuote(script), shQuote(hub), shQuote(twin)),
    stdout = TRUE,
    stderr = TRUE
  ))
  status <- attr(result, "status")
  if (is.null(status)) status <- 0L

  expect_equal(
    status,
    0L,
    info = paste(result, collapse = "\n")
  )
})
