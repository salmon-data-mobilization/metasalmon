# B-130: the dereference report remains useful even when publication must stop.
# All requests and delays are injected; these tests never reach the network.

write_iri_fixture_csv <- function(root, relative_path, rows) {
  target <- file.path(root, relative_path)
  dir.create(dirname(target), recursive = TRUE, showWarnings = FALSE)
  readr::write_csv(rows, target, na = "")
  invisible(target)
}

make_iri_fixture_sdp <- function(root) {
  write_iri_fixture_csv(root, "metadata/dataset.csv", tibble::tibble(
    dataset_id = "iri-test"
  ))
  write_iri_fixture_csv(root, "metadata/tables.csv", tibble::tibble(
    dataset_id = "iri-test", table_id = "observations"
  ))
  write_iri_fixture_csv(root, "metadata/column_dictionary.csv", tibble::tibble(
    dataset_id = "iri-test", table_id = "observations",
    column_name = "value", term_iri = NA_character_
  ))
  invisible(root)
}

read_iri_report <- function(root) {
  readr::read_csv(
    file.path(root, "reproducibility/provenance/semantic-iri-dereference.csv"),
    col_types = readr::cols(.default = readr::col_character()),
    show_col_types = FALSE
  )
}

test_that("classified retries are bounded and every final failure is persisted", {
  root <- withr::local_tempdir()
  make_iri_fixture_sdp(root)
  write_iri_fixture_csv(root, "metadata/column_dictionary.csv", tibble::tibble(
    term_iri = "https://example.org/z#exact; https://example.org/a#exact",
    property_iri = "https://example.org/b#exact",
    constraint_iri = "https://example.org/c#exact",
    unrelated_url = "https://example.org/not-a-semantic-selection"
  ))
  calls <- new.env(parent = emptyenv())
  calls$count <- list()
  calls$delays <- numeric()
  requester <- function(iri) {
    count <- length(calls$count[[iri]]) + 1L
    calls$count[[iri]] <- c(calls$count[[iri]], count)
    if (grepl("/a#", iri, fixed = TRUE) && count == 1L) {
      return(list(status = 503L, final_url = iri))
    }
    if (grepl("/b#", iri, fixed = TRUE)) {
      return(list(status = 404L, final_url = iri))
    }
    if (grepl("/c#", iri, fixed = TRUE)) {
      stop("timeout; Authorization: Bearer test-credential")
    }
    list(status = 200L, final_url = sub("#.*$", "", iri))
  }
  sleep_fn <- function(seconds) {
    calls$delays <- c(calls$delays, seconds)
  }

  expect_error(
    verify_sdp_semantic_iris(root, requester = requester, sleep_fn = sleep_fn),
    regexp = "https://example.org/b#exact.*https://example.org/c#exact"
  )
  report_path <- file.path(root, "reproducibility/provenance/semantic-iri-dereference.csv")
  expect_true(file.exists(report_path))
  first_bytes <- readBin(report_path, "raw", n = file.info(report_path)$size)
  rows <- read_iri_report(root)
  expect_named(rows, c("iri", "status", "final_url", "error", "attempts"))
  expect_identical(rows$iri, paste0("https://example.org/", c("a", "b", "c", "z"), "#exact"))
  expect_identical(as.integer(rows$attempts), c(2L, 1L, 3L, 1L))
  expect_identical(rows$status, c("200", "404", NA_character_, "200"))
  expect_identical(calls$delays, c(0.1, 0.1, 0.25))
  expect_false(any(grepl("test-credential", readLines(report_path, warn = FALSE), fixed = TRUE)))
  expect_true(grepl("[REDACTED]", rows$error[[3]], fixed = TRUE))

  calls$count <- list()
  calls$delays <- numeric()
  expect_error(
    verify_sdp_semantic_iris(root, requester = requester, sleep_fn = sleep_fn),
    regexp = "https://example.org/b#exact.*https://example.org/c#exact"
  )
  second_bytes <- readBin(report_path, "raw", n = file.info(report_path)$size)
  expect_identical(second_bytes, first_bytes)
})

test_that("the exact selected semantic fields are collected across SDP metadata", {
  root <- withr::local_tempdir()
  make_iri_fixture_sdp(root)
  write_iri_fixture_csv(root, "metadata/dataset.csv", tibble::tibble(
    protocol_iri = "https://example.org/dataset#protocol"
  ))
  write_iri_fixture_csv(root, "metadata/tables.csv", tibble::tibble(
    method_iri = "https://example.org/table#method",
    observation_unit_iri = "https://example.org/table#unit"
  ))
  write_iri_fixture_csv(root, "metadata/column_dictionary.csv", tibble::tibble(
    term_iri = "https://example.org/column#term"
  ))
  write_iri_fixture_csv(root, "metadata/codes.csv", tibble::tibble(
    term_iri = "https://example.org/code#term",
    vocabulary_iri = "https://example.org/code#vocabulary"
  ))
  write_iri_fixture_csv(root, "metadata/semantic/measurement-decompositions.csv", tibble::tibble(
    component_iri = "https://example.org/decomposition#component"
  ))
  write_iri_fixture_csv(root, "metadata/structure/observation_components.csv", tibble::tibble(
    component_relation_iri = "https://example.org/structure#relation"
  ))
  write_iri_fixture_csv(root, "metadata/semantic_vocabulary.csv", tibble::tibble(
    iri = "https://example.org/vocabulary#accepted",
    source_url = "https://example.org/source-document"
  ))
  write_iri_fixture_csv(root, "reviewed_semantic_selections.csv", tibble::tibble(
    iri = c("https://example.org/review#accepted", "https://example.org/review#rejected"),
    decision = c("accepted", "rejected")
  ))
  write_iri_fixture_csv(root, "semantic_suggestions.csv", tibble::tibble(
    iri = "https://example.org/candidate#only"
  ))
  seen <- character()
  result <- verify_sdp_semantic_iris(root, requester = function(iri) {
    seen <<- c(seen, iri)
    list(status = 200L, final_url = iri)
  }, sleep_fn = function(...) stop("No retry expected"))
  expected <- sort(c(
    "https://example.org/dataset#protocol", "https://example.org/table#method",
    "https://example.org/table#unit", "https://example.org/column#term",
    "https://example.org/code#term", "https://example.org/code#vocabulary",
    "https://example.org/decomposition#component",
    "https://example.org/structure#relation",
    "https://example.org/vocabulary#accepted", "https://example.org/review#accepted"
  ), method = "radix")
  expect_identical(seen, expected)
  expect_identical(result$iri, expected)
  expect_false(any(grepl("candidate|rejected|source-document", result$iri)))
})

test_that("an SDP with no HTTP semantic IRI cannot produce a passing report", {
  root <- withr::local_tempdir()
  make_iri_fixture_sdp(root)
  write_iri_fixture_csv(root, "metadata/column_dictionary.csv", tibble::tibble(
    term_iri = c("REVIEW:pending", "urn:example:local")
  ))
  expect_error(verify_sdp_semantic_iris(root, requester = function(...) {
    stop("No request expected")
  }), "At least one HTTP semantic IRI")
})

test_that("manifest-bound SSSOM semantic references are checked without CURIE expansion", {
  root <- withr::local_tempdir()
  make_iri_fixture_sdp(root)
  write_iri_fixture_csv(root, "metadata/column_dictionary.csv", tibble::tibble(
    term_iri = "https://example.org/column#term"
  ))
  source <- file.path(root, "source.sssom.tsv")
  lines <- c(
    "# sssom_version: 1.1",
    "# mapping_set_id: https://example.org/mappings/test",
    "# mapping_set_version: 2026-10-01",
    "# license: https://creativecommons.org/licenses/by/4.0/",
    "# subject_source: https://example.org/subject/",
    "# subject_source_version: v1",
    "# object_source: https://example.org/object/",
    "# object_source_version: v1",
    "# curie_map:",
    "#   skos: http://www.w3.org/2004/02/skos/core#",
    "#   semapv: https://w3id.org/semapv/vocab/",
    paste(c(
      "subject_id", "subject_label", "subject_category", "predicate_id",
      "object_id", "object_label", "mapping_justification"
    ), collapse = "\t"),
    paste(c(
      "https://example.org/subject#one", "Subject",
      "https://example.org/category#one|https://example.org/category#two",
      "http://www.w3.org/2004/02/skos/core#exactMatch",
      "https://example.org/object#one", "Object",
      "semapv:ManualMappingCuration"
    ), collapse = "\t")
  )
  writeLines(lines, source, useBytes = TRUE)
  write_sdp_sssom(root, mapping_sets = source)

  seen <- character()
  result <- verify_sdp_semantic_iris(root, requester = function(iri) {
    seen <<- c(seen, iri)
    list(status = 200L, final_url = iri)
  }, sleep_fn = function(...) stop("No retry expected"))
  expect_setequal(seen, c(
    "https://example.org/column#term", "https://example.org/subject#one",
    "https://example.org/category#one", "https://example.org/category#two",
    "http://www.w3.org/2004/02/skos/core#exactMatch",
    "https://example.org/object#one"
  ))
  expect_identical(result$iri, sort(seen, method = "radix"))
  expect_false(any(grepl("semapv:|creativecommons", seen)))
})

test_that("a partial canonical package uses its descriptor rather than losing IRIs", {
  root <- withr::local_tempdir()
  write_iri_fixture_csv(root, "metadata/column_dictionary.csv", tibble::tibble(
    term_iri = "https://example.org/stale-csv#term"
  ))
  dir.create(file.path(root, "data"))
  write_iri_fixture_csv(root, "data/observations.csv", tibble::tibble(value = 1))
  descriptor <- list(
    id = "iri-test", name = "iri-test",
    resources = list(list(
      name = "observations", path = "data/observations.csv",
      schema = list(fields = list(list(
        name = "value", type = "number",
        custom = list("sdp:termIri" = "https://example.org/descriptor#term")
      )))
    ))
  )
  jsonlite::write_json(descriptor, file.path(root, "datapackage.json"),
                       auto_unbox = TRUE)
  seen <- character()
  suppressWarnings(suppressMessages(verify_sdp_semantic_iris(
    root, requester = function(iri) {
      seen <<- c(seen, iri)
      list(status = 200L, final_url = iri)
    }, sleep_fn = function(...) stop("No retry expected")
  )))
  expect_identical(seen, "https://example.org/descriptor#term")
})

test_that("malformed requester results become rows rather than stopping the sweep", {
  root <- withr::local_tempdir()
  make_iri_fixture_sdp(root)
  write_iri_fixture_csv(root, "metadata/column_dictionary.csv", tibble::tibble(
    term_iri = "https://example.org/a#malformed;https://example.org/b#good"
  ))
  seen <- character()
  expect_error(verify_sdp_semantic_iris(root, requester = function(iri) {
    seen <<- c(seen, iri)
    if (grepl("/a#", iri, fixed = TRUE)) {
      return(list(status = list(200L), final_url = list(iri)))
    }
    list(status = 200L, final_url = iri)
  }, sleep_fn = function(...) stop("Malformed responses are permanent")),
  "https://example.org/a#malformed")
  expect_identical(length(seen), 2L)
  rows <- read_iri_report(root)
  expect_identical(as.integer(rows$attempts), c(1L, 1L))
  expect_true(grepl("Malformed requester response", rows$error[[1]], fixed = TRUE))
  expect_identical(rows$status[[2]], "200")
})

test_that("scalar accepted IRIs preserve legal semicolons", {
  root <- withr::local_tempdir()
  make_iri_fixture_sdp(root)
  write_iri_fixture_csv(root, "metadata/semantic_vocabulary.csv", tibble::tibble(
    iri = "https://example.org/term;variant#one"
  ))
  write_iri_fixture_csv(root, "reviewed_semantic_selections.csv", tibble::tibble(
    iri = "https://example.org/review;variant#two", decision = "accepted"
  ))
  result <- verify_sdp_semantic_iris(root, requester = function(iri) {
    list(status = 200L, final_url = iri)
  }, sleep_fn = function(...) stop("No retry expected"))
  expect_setequal(result$iri, c(
    "https://example.org/term;variant#one",
    "https://example.org/review;variant#two"
  ))
})

test_that("the default report cannot cross a symlinked SDP directory", {
  root <- withr::local_tempdir()
  outside <- withr::local_tempdir()
  make_iri_fixture_sdp(root)
  write_iri_fixture_csv(root, "metadata/column_dictionary.csv", tibble::tibble(
    term_iri = "https://example.org/term#one"
  ))
  expect_true(file.symlink(outside, file.path(root, "reproducibility")))
  expect_error(verify_sdp_semantic_iris(root, requester = function(iri) {
    list(status = 200L, final_url = iri)
  }, sleep_fn = function(...) stop("No retry expected")), "symlink")
  expect_false(file.exists(file.path(outside, "provenance/semantic-iri-dereference.csv")))
})
