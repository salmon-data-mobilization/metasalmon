# The existing closure producer and scalar getter normalize surrounding path
# whitespace. This is their qualification rule, not a claim that a padded path
# passes the separate full EML schema's raw enum check.

# Each test file has its own evaluation environment in the full suite. Keep
# these fixtures local to this file so this regression also runs in isolation.
ledger_authority_whitespace_fixture <- function(root) {
  write <- function(relative, rows) {
    target <- file.path(root, relative)
    dir.create(dirname(target), recursive = TRUE, showWarnings = FALSE)
    readr::write_csv(rows, target, na = "")
  }
  write("metadata/dataset.csv", tibble::tibble(dataset_id = "ledger-authority"))
  write("metadata/tables.csv", tibble::tibble(table_id = "observations"))
  write("metadata/column_dictionary.csv", tibble::tibble(
    term_iri = "https://authority.invalid/canonical;literal#term"
  ))
  for (relative in c("reviewed_semantic_selections.csv",
                     "reproducibility/reviewed_semantic_selections.csv")) {
    owner <- if (startsWith(relative, "reproducibility/")) "repro" else "legacy"
    write(relative, tibble::tibble(
      decision = c("accepted", "rejected"),
      iri = paste0("https://authority.invalid/", owner, ";literal#", c("chosen", "rejected"))
    ))
  }
  invisible(root)
}

ledger_authority_whitespace_input_bytes <- function(root) {
  files <- list.files(root, recursive = TRUE, full.names = TRUE)
  files <- files[!grepl("semantic-iri-dereference[.]csv$", files)]
  stats::setNames(lapply(files, function(file) {
    readBin(file, "raw", n = file.info(file)$size)
  }), substring(files, nchar(root) + 2L))
}

test_that("ledger selection preserves native producer path normalization", {
  for (relative in c("reviewed_semantic_selections.csv",
                     "reproducibility/reviewed_semantic_selections.csv")) {
    root <- withr::local_tempdir()
    ledger_authority_whitespace_fixture(root)
    padded <- paste0(" ", relative, " ")
    mapping_file <- file.path(root, "metadata/eml-mapping.yml")
    writeLines(c("semantic_review:", paste0('  path: "', padded, '"')), mapping_file)
    mapping <- .ms_eml_read_mapping_yaml(mapping_file)
    expect_identical(.ms_eml_scalar(mapping$semantic_review, "path"), relative)
    expect_identical(.ms_closure_mapping_paths(mapping_file)$review, relative)
    owner <- if (startsWith(relative, "reproducibility/")) "repro" else "legacy"
    shadow <- if (owner == "repro") "legacy" else "repro"
    before <- ledger_authority_whitespace_input_bytes(root)
    seen <- character()
    result <- verify_sdp_semantic_iris(root, requester = function(iri) {
      seen <<- c(seen, iri)
      list(status = if (grepl(shadow, iri, fixed = TRUE)) 404L else 200L,
           final_url = iri)
    }, sleep_fn = function(...) stop("No retry expected"))
    expected <- sort(c("https://authority.invalid/canonical;literal#term",
                       paste0("https://authority.invalid/", owner, ";literal#chosen")),
                     method = "radix")
    expect_identical(seen, expected)
    expect_identical(result$iri, expected)
    expect_identical(result$attempts, c(1L, 1L))
    expect_identical(ledger_authority_whitespace_input_bytes(root), before)
  }
})
