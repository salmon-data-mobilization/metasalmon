# The existing closure producer and scalar getter normalize surrounding path
# whitespace. This is their qualification rule, not a claim that a padded path
# passes the separate full EML schema's raw enum check.
test_that("ledger selection preserves native producer path normalization", {
  for (relative in c("reviewed_semantic_selections.csv",
                     "reproducibility/reviewed_semantic_selections.csv")) {
    root <- withr::local_tempdir()
    ledger_authority_fixture(root)
    padded <- paste0(" ", relative, " ")
    mapping_file <- file.path(root, "metadata/eml-mapping.yml")
    writeLines(c("semantic_review:", paste0('  path: "', padded, '"')), mapping_file)
    mapping <- .ms_eml_read_mapping_yaml(mapping_file)
    expect_identical(.ms_eml_scalar(mapping$semantic_review, "path"), relative)
    expect_identical(.ms_closure_mapping_paths(mapping_file)$review, relative)
    owner <- if (startsWith(relative, "reproducibility/")) "repro" else "legacy"
    shadow <- if (owner == "repro") "legacy" else "repro"
    before <- ledger_authority_input_bytes(root)
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
    expect_identical(ledger_authority_input_bytes(root), before)
  }
})
