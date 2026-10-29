test_that("an unsupported source is not a successful empty search", {
  expect_warning(
    result <- find_terms("escapement", sources = c(" PSC ", "psc"), expand_query = FALSE),
    "Vocabulary lookup was incomplete"
  )

  expect_equal(nrow(result), 0L)
  diagnostics <- attr(result, "diagnostics")
  expect_identical(diagnostics$source, "psc")
  expect_identical(diagnostics$status, "unsupported")
  expect_identical(diagnostics$count, 0L)
  expect_match(diagnostics$error[[1L]], "Unsupported vocabulary source")
})

test_that("a local match keeps its evidence and still reports unsupported sources", {
  snapshot <- testthat::test_path("fixtures", "ontology-release", "smn-0.0.3")
  expect_warning(
    result <- find_terms("escapement", sources = c("psc", "smn"), expand_query = FALSE,
                         snapshot_dir = c(smn = snapshot)),
    "Vocabulary lookup was incomplete"
  )

  expect_true("https://w3id.org/smn/Escapement" %in% result$iri)
  diagnostics <- attr(result, "diagnostics")
  expect_identical(diagnostics$status[diagnostics$source == "smn"], "success")
  expect_identical(diagnostics$status[diagnostics$source == "psc"], "unsupported")
  expect_identical(attr(result, "ontology_release")$version, "0.0.3")
})

unsupported_ols_response <- function(status = 200L, docs = list(), .env = parent.frame()) {
  # Replace only the external HTTP boundary; search and ranking remain real.
  testthat::local_mocked_bindings(
    GET = function(url, ...) {
      stopifnot(startsWith(url, "https://www.ebi.ac.uk/ols4/api/search?"))
      structure(list(
        url = url,
        status_code = status,
        headers = list(`content-type` = "application/json"),
        content = charToRaw(jsonlite::toJSON(list(response = list(docs = docs)), auto_unbox = TRUE))
      ), class = "response")
    },
    .package = "httr", .env = .env
  )
}

test_that("a supported source with no matches is still a success", {
  unsupported_ols_response()
  result <- find_terms("escapement", sources = "ols", expand_query = FALSE)

  expect_equal(nrow(result), 0L)
  diagnostics <- attr(result, "diagnostics")
  expect_identical(diagnostics$status, "success")
  expect_identical(diagnostics$count, 0L)
  expect_true(is.na(diagnostics$error[[1L]]))
})

test_that("a mixed lookup keeps supported empty or failed status", {
  withr::local_envvar(c(METASALMON_TERM_SEARCH_PARALLEL = "0", METASALMON_CACHE = ""))
  for (status in c(200L, 503L)) {
    unsupported_ols_response(status)
    expect_warning(
      result <- find_terms("escapement", sources = c("psc", "ols"), expand_query = FALSE),
      "Vocabulary lookup was incomplete"
    )
    diagnostics <- attr(result, "diagnostics")
    expect_equal(nrow(result), 0L)
    expect_identical(diagnostics$source, c("psc", "ols"))
    expect_identical(diagnostics$status, c("unsupported", if (status == 200L) "success" else "http_error"))
    expect_identical(diagnostics$count, c(0L, 0L))
  }
})

test_that("a mixed unsupported lookup does not freeze supported results", {
  withr::local_envvar(c(METASALMON_TERM_SEARCH_PARALLEL = "0", METASALMON_CACHE = "1"))
  unsupported_ols_response()
  expect_warning(
    first <- find_terms("escapement", sources = c("psc", "ols"), expand_query = FALSE),
    "Vocabulary lookup was incomplete"
  )
  unsupported_ols_response(docs = list(list(
    label = "Escapement", iri = "https://example.org/Escapement", ontology_name = "example",
    type = "class", description = list("Synthetic search result.")
  )))
  expect_warning(
    second <- find_terms("escapement", sources = c("psc", "ols"), expand_query = FALSE),
    "Vocabulary lookup was incomplete"
  )

  expect_equal(nrow(first), 0L)
  expect_identical(second$iri, "https://example.org/Escapement")
  expect_identical(attr(second, "diagnostics")$status, c("unsupported", "success"))
})
