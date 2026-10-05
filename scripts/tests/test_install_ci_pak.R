#!/usr/bin/env Rscript

# Offline failure proofs: no package installs or network requests. Keep these
# before CI's bootstrap so its failure path is exercised even when the CDN is up.
source("scripts/install-ci-pak.R")

checks <- 0L
check <- function(ok, label) {
  if (!isTRUE(ok)) stop(label, call. = FALSE)
  checks <<- checks + 1L
  cat("PASS:", label, "\n")
}
lib <- tempfile("ci-pak-test-")

calls <- 0L
waits <- integer()
install <- function(...) {
  calls <<- calls + 1L
  if (calls == 1L) stop("SSL connect error")
}
result <- .ms_ci_install_pak(
  lib, install_fn = install, verify_fn = function(...) TRUE,
  sleep_fn = function(seconds) waits <<- c(waits, seconds)
)
check(result == 2L && calls == 2L && identical(waits, 5L),
      "a simulated SSL error retries and then succeeds")

calls <- 0L
waits <- integer()
warnings <- character()
messages <- character()
failure <- withCallingHandlers(tryCatch(
  .ms_ci_install_pak(
    lib,
    install_fn = function(...) {
      calls <<- calls + 1L
      warning("download of package 'pak' failed")
    },
    verify_fn = function(...) FALSE,
    sleep_fn = function(seconds) waits <<- c(waits, seconds)
  ), error = identity
), warning = function(w) {
  warnings <<- c(warnings, conditionMessage(w))
  invokeRestart("muffleWarning")
}, message = function(m) {
  messages <<- c(messages, conditionMessage(m))
  invokeRestart("muffleMessage")
})
check(inherits(failure, "error") && calls == 3L &&
        identical(waits, c(5L, 10L)) && length(warnings) == 3L &&
        !any(grepl("loads successfully", messages, fixed = TRUE)),
      "warning-only download failures do not print success or retry forever")
check(grepl("CI infrastructure failure", conditionMessage(failure), fixed = TRUE) &&
        grepl("package tests and R CMD check have not run", conditionMessage(failure), fixed = TRUE),
      "exhausted bootstrap is identified as infrastructure before package checks")

calls <- 0L
failure <- tryCatch(.ms_ci_install_pak(
  lib,
  install_fn = function(...) calls <<- calls + 1L,
  verify_fn = function(...) stop("broken pak namespace"),
  sleep_fn = function(...) NULL
), error = identity)
check(inherits(failure, "error") && calls == 3L &&
        grepl("broken pak namespace", conditionMessage(failure), fixed = TRUE),
      "an installed but unloadable pak is also a bootstrap failure")

calls <- 0L
result <- .ms_ci_install_pak(
  lib,
  install_fn = function(...) calls <<- calls + 1L,
  verify_fn = function(...) TRUE,
  sleep_fn = function(...) stop("a successful bootstrap must not wait")
)
check(result == 1L && calls == 1L, "a successful install runs only once")

# The same Rscript process boundary used in the workflow must stay nonzero on
# exhaustion. A simulated installer error avoids changing local R libraries.
child <- tempfile(fileext = ".R")
writeLines(c(
  "source('scripts/install-ci-pak.R')",
  ".ms_ci_install_pak(tempfile(), install_fn = function(...) stop('SSL connect error'), verify_fn = function(...) FALSE, sleep_fn = function(...) NULL)"
), child)
output <- suppressWarnings(system2(
  file.path(R.home("bin"), "Rscript"), shQuote(child), stdout = TRUE, stderr = TRUE
))
check(identical(attr(output, "status"), 1L) &&
        any(grepl("CI infrastructure failure", output, fixed = TRUE)),
      "Rscript propagates a permanent bootstrap failure with exit status 1")
unlink(c(lib, child), recursive = TRUE)
cat(sprintf("%d checks passed.\n", checks))
