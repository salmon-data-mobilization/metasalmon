# An explicit reviewed mapping owns one ledger, not the union of its legacy
# compatibility copy and the reproducibility ledger. Native YAML interpretation
# and tag refusal are reused; this verifier does not invent EML SHA/target policy.
ledger_authority_fixture <- function(root) {
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

ledger_authority_input_bytes <- function(root) {
  files <- list.files(root, recursive = TRUE, full.names = TRUE)
  files <- files[!grepl("semantic-iri-dereference[.]csv$", files)]
  stats::setNames(lapply(files, function(file) {
    readBin(file, "raw", n = file.info(file)$size)
  }), substring(files, nchar(root) + 2L))
}

test_that("each supported explicit mapping selects only its accepted ledger", {
  for (relative in c("reviewed_semantic_selections.csv",
                     "reproducibility/reviewed_semantic_selections.csv")) {
    root <- withr::local_tempdir()
    ledger_authority_fixture(root)
    owner <- if (startsWith(relative, "reproducibility/")) "repro" else "legacy"
    shadow <- if (owner == "repro") "legacy" else "repro"
    mapping_file <- file.path(root, "metadata/eml-mapping.yml")
    writeLines(c("semantic_review:", paste0("  path: ", relative)), mapping_file)
    expect_identical(.ms_closure_mapping_paths(mapping_file)$review, relative)
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
    expect_identical(names(result), c("iri", "status", "final_url", "error", "attempts"))
    expect_identical(result$attempts, c(1L, 1L))
    expect_identical(ledger_authority_input_bytes(root), before)
    report <- file.path(root, "reproducibility/provenance/semantic-iri-dereference.csv")
    expect_true(file.exists(report))
    expect_false(any(grepl("rejected", result$iri, fixed = TRUE)))
  }
})

test_that("absent and unqualified mappings keep the existing ledger union", {
  for (text in list(NULL, "notes: pending", "ordinary scalar", "semantic_review: []",
                   "semantic_review:\n  path: not-a-supported-ledger.csv", "broken: [")) {
    root <- withr::local_tempdir()
    ledger_authority_fixture(root)
    if (!is.null(text)) writeLines(text, file.path(root, "metadata/eml-mapping.yml"))
    before <- ledger_authority_input_bytes(root)
    seen <- character()
    result <- verify_sdp_semantic_iris(root, requester = function(iri) {
      seen <<- c(seen, iri)
      list(status = 200L, final_url = iri)
    })
    expected <- sort(c("https://authority.invalid/canonical;literal#term",
                       "https://authority.invalid/legacy;literal#chosen",
                       "https://authority.invalid/repro;literal#chosen"), method = "radix")
    expect_identical(seen, expected)
    expect_identical(result$iri, expected)
    expect_identical(ledger_authority_input_bytes(root), before)
  }
})

test_that("a missing explicit ledger refuses before requests or report replacement", {
  root <- withr::local_tempdir()
  ledger_authority_fixture(root)
  unlink(file.path(root, "reproducibility/reviewed_semantic_selections.csv"))
  writeLines(c("semantic_review:", "  path: reproducibility/reviewed_semantic_selections.csv"),
             file.path(root, "metadata/eml-mapping.yml"))
  report <- file.path(root, "reproducibility/provenance/semantic-iri-dereference.csv")
  dir.create(dirname(report), recursive = TRUE)
  sentinel <- charToRaw("prior complete report\n")
  writeBin(sentinel, report)
  before <- ledger_authority_input_bytes(root)
  expect_error(verify_sdp_semantic_iris(root, requester = function(...) {
    stop("Requester must never be reached")
  }), "does not exist")
  expect_identical(readBin(report, "raw", n = file.info(report)$size), sentinel)
  expect_identical(ledger_authority_input_bytes(root), before)
})

test_that("native Q62 tag refusal precedes requests and any report write", {
  for (existing in c(FALSE, TRUE)) {
    root <- withr::local_tempdir()
    ledger_authority_fixture(root)
    writeLines(c("semantic_review:", "  path: reproducibility/reviewed_semantic_selections.csv",
                 "notes: !foo reached-tag"), file.path(root, "metadata/eml-mapping.yml"))
    report <- file.path(root, "reproducibility/provenance/semantic-iri-dereference.csv")
    sentinel <- charToRaw("prior complete report\n")
    if (existing) {
      dir.create(dirname(report), recursive = TRUE)
      writeBin(sentinel, report)
    }
    before <- ledger_authority_input_bytes(root)
    expect_error(verify_sdp_semantic_iris(root, requester = function(...) {
      stop("Requester must never be reached")
    }), class = "metasalmon_eml_mapping_tag")
    if (existing) {
      expect_identical(readBin(report, "raw", n = file.info(report)$size), sentinel)
    } else expect_false(file.exists(report))
    expect_identical(ledger_authority_input_bytes(root), before)
  }
})

test_that("an explicitly bound ledger cannot resolve outside the package", {
  root <- withr::local_tempdir()
  ledger_authority_fixture(root)
  outside <- withr::local_tempfile()
  readr::write_csv(tibble::tibble(decision = "accepted", iri = "https://outside.invalid/term"), outside)
  target <- file.path(root, "reproducibility/reviewed_semantic_selections.csv")
  unlink(target)
  expect_true(file.symlink(outside, target))
  writeLines(c("semantic_review:", "  path: reproducibility/reviewed_semantic_selections.csv"),
             file.path(root, "metadata/eml-mapping.yml"))
  report <- file.path(root, "reproducibility/provenance/semantic-iri-dereference.csv")
  before <- ledger_authority_input_bytes(root)
  expect_error(verify_sdp_semantic_iris(root, requester = function(...) {
    stop("Requester must never be reached")
  }), "resolves outside")
  expect_false(file.exists(report))
  expect_identical(ledger_authority_input_bytes(root), before)
})
