#!/usr/bin/env Rscript

# Bootstrap only the CI installer. Package dependency resolution, the package
# tests and R CMD check remain separate steps with their ordinary exit status.
#
# RETIREMENT CONDITION: remove this bootstrap and `pak-version: none` from the
# workflow when setup-r-dependencies itself retries failed pak downloads AND
# verifies that pak loads before reporting its install step as successful.
.ms_ci_install_pak <- function(
    lib,
    install_fn = utils::install.packages,
    verify_fn = function(lib) {
      requireNamespace("pak", lib.loc = lib, quietly = TRUE)
    },
    sleep_fn = Sys.sleep) {
  if (!nzchar(lib)) {
    stop("CI infrastructure failure: R_LIB_FOR_PAK is unset.", call. = FALSE)
  }
  dir.create(lib, recursive = TRUE, showWarnings = FALSE)
  if (!dir.exists(lib)) {
    stop("CI infrastructure failure: cannot create the pak library.", call. = FALSE)
  }

  # Match the stable binary repository used by setup-r-dependencies@v2. Giving
  # that action this library and `pak-version: none` avoids a second download.
  repo <- sprintf(
    "https://r-lib.github.io/p/pak/stable/%s/%s/%s",
    .Platform$pkgType, R.Version()$os, R.Version()$arch
  )
  attempts <- 3L
  for (attempt in seq_len(attempts)) {
    message(sprintf("CI toolchain: installing pak (attempt %d/%d).", attempt, attempts))
    result <- tryCatch({
      # install.packages() can WARN about a failed download and return normally.
      # The namespace check is the success criterion, not the call returning.
      install_fn("pak", lib = lib, repos = repo)
      if (!isTRUE(verify_fn(lib))) {
        stop("pak is absent or cannot be loaded after installation.")
      }
      TRUE
    }, error = identity)
    if (isTRUE(result)) {
      message("CI toolchain: pak is installed and loads successfully.")
      return(invisible(attempt))
    }
    message(sprintf("CI toolchain: pak bootstrap failed: %s", conditionMessage(result)))
    if (attempt < attempts) sleep_fn(5L * attempt)
  }
  stop(sprintf(
    paste0(
      "CI infrastructure failure: pak bootstrap failed after %d attempts; ",
      "package tests and R CMD check have not run. Last bootstrap error: %s"
    ),
    attempts, conditionMessage(result)
  ), call. = FALSE)
}

# Sourcing exposes the helper for offline simulations without reaching a CDN.
if (sys.nframe() == 0L) {
  .ms_ci_install_pak(Sys.getenv("R_LIB_FOR_PAK"))
}
