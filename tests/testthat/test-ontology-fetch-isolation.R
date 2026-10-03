# B333/B335 use only mocked HTTP responses. These public-path regressions retire
# the wrong-ontology fallback and shared URL/Accept cache defects, respectively.
# A request log is the positive control that the mocked transport was reached.
fetch_test_response <- function(url, status = 200L, body = "ontology",
                                etag = NULL, last_modified = NULL) {
  headers <- list(`content-type` = "text/turtle; charset=utf-8")
  if (!is.null(etag)) headers$etag <- etag
  if (!is.null(last_modified)) headers$`last-modified` <- last_modified
  structure(list(url = url, status_code = as.integer(status), headers = headers,
                 content = charToRaw(enc2utf8(body))), class = "response")
}

fetch_test_call <- function(routes, ...) {
  requests <- list()
  get <- function(url, ...) {
    sent <- list()
    for (config in list(...)) {
      if (inherits(config, "request")) sent <- c(sent, as.list(config$headers))
    }
    requests[[length(requests) + 1L]] <<- list(url = url, headers = sent)
    route <- routes[[url]]
    if (is.null(route)) stop("unconfigured mocked URL: ", url)
    route(sent)
  }
  testthat::local_mocked_bindings(GET = get, .package = "httr")
  value <- tryCatch(fetch_salmon_ontology(...), error = identity)
  list(value = value, requests = requests)
}

test_that("B333 custom URL does not implicitly try the SMN fallback", {
  primary <- "https://example.org/gcdfo.ttl"
  fallback <- "https://w3id.org/smn"
  result <- fetch_test_call(
    setNames(list(function(sent) stop("requested ontology unavailable"),
                  function(sent) fetch_test_response(fallback, body = "smn")),
             c(primary, fallback)),
    url = primary, cache_dir = withr::local_tempdir()
  )
  expect_s3_class(result$value, "error")
  expect_equal(vapply(result$requests, `[[`, character(1), "url"), primary)
})

test_that("B333 default URL still tries its default SMN fallback", {
  primary <- "https://w3id.org/smn/"
  fallback <- "https://w3id.org/smn"
  result <- fetch_test_call(
    setNames(list(function(sent) stop("primary unavailable"),
                  function(sent) fetch_test_response(fallback, body = "smn")),
             c(primary, fallback)),
    cache_dir = withr::local_tempdir()
  )
  expect_type(result$value, "character")
  expect_equal(readLines(result$value), "smn")
  expect_equal(vapply(result$requests, `[[`, character(1), "url"),
               c(primary, fallback))
})

test_that("B333 explicitly named fallbacks remain caller controlled", {
  primary <- "https://example.org/gcdfo.ttl"
  fallback <- "https://example.org/gcdfo-mirror.ttl"
  routes <- setNames(list(function(sent) stop("primary unavailable"),
                          function(sent) fetch_test_response(fallback, body = "gcdfo")),
                     c(primary, fallback))
  result <- fetch_test_call(routes, url = primary, fallback_urls = fallback,
                            cache_dir = withr::local_tempdir())
  expect_equal(readLines(result$value), "gcdfo")
  expect_equal(vapply(result$requests, `[[`, character(1), "url"),
               c(primary, fallback))
  empty <- fetch_test_call(routes, url = primary, fallback_urls = character(),
                           cache_dir = withr::local_tempdir())
  expect_s3_class(empty$value, "error")
  expect_length(empty$requests, 1L)
})
