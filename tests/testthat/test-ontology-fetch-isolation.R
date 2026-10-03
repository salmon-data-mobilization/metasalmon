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
  warnings <- character()
  value <- withCallingHandlers(
    tryCatch(fetch_salmon_ontology(...), error = identity),
    warning = function(w) {
      warnings <<- c(warnings, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  list(value = value, requests = requests, warnings = warnings)
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

test_that("B335 different URLs retain their own bodies and both validators", {
  cache <- withr::local_tempdir()
  smn <- "https://example.org/smn.ttl"
  gcdfo <- "https://example.org/gcdfo.ttl"
  first <- fetch_test_call(setNames(list(function(sent) {
    fetch_test_response(smn, body = "smn", etag = "smn-tag", last_modified = "smn-time")
  }), smn), url = smn, cache_dir = cache, fallback_urls = character())
  second <- fetch_test_call(setNames(list(function(sent) {
    fetch_test_response(gcdfo, body = "gcdfo", etag = "gcdfo-tag", last_modified = "gcdfo-time")
  }), gcdfo), url = gcdfo, cache_dir = cache, fallback_urls = character())
  expect_false(identical(first$value, second$value))
  expect_equal(readLines(first$value), "smn")
  expect_equal(readLines(second$value), "gcdfo")
  expect_null(second$requests[[1]]$headers[["If-None-Match"]])
  expect_null(second$requests[[1]]$headers[["If-Modified-Since"]])

  unchanged <- fetch_test_call(setNames(list(function(sent) {
    fetch_test_response(smn, 304L)
  }), smn), url = smn, cache_dir = cache, fallback_urls = character())
  expect_equal(unchanged$value, first$value)
  expect_equal(readLines(unchanged$value), "smn")
  expect_equal(unchanged$requests[[1]]$headers[["If-None-Match"]], "smn-tag")
  expect_equal(unchanged$requests[[1]]$headers[["If-Modified-Since"]], "smn-time")
})

test_that("B335 different Accept values retain separate representations", {
  cache <- withr::local_tempdir()
  url <- "https://example.org/ontology"
  route <- function(sent) {
    type <- sent$Accept
    fetch_test_response(url, body = type, etag = paste0(type, "-tag"),
                        last_modified = paste0(type, "-time"))
  }
  first <- fetch_test_call(setNames(list(route), url), url = url, cache_dir = cache,
                           accept = "text/turtle", fallback_urls = character())
  second <- fetch_test_call(setNames(list(route), url), url = url, cache_dir = cache,
                            accept = "application/rdf+xml", fallback_urls = character())
  expect_false(identical(first$value, second$value))
  expect_equal(readLines(first$value), "text/turtle")
  expect_equal(readLines(second$value), "application/rdf+xml")
  expect_null(second$requests[[1]]$headers[["If-None-Match"]])
  expect_null(second$requests[[1]]$headers[["If-Modified-Since"]])
  unchanged <- fetch_test_call(setNames(list(function(sent) fetch_test_response(url, 304L)), url),
                               url = url, cache_dir = cache, accept = "text/turtle",
                               fallback_urls = character())
  expect_equal(readLines(unchanged$value), "text/turtle")
  expect_equal(unchanged$requests[[1]]$headers[["If-None-Match"]], "text/turtle-tag")
  expect_equal(unchanged$requests[[1]]$headers[["If-Modified-Since"]], "text/turtle-time")
})

test_that("B335 fallback validators cannot make the primary return its body on 304", {
  cache <- withr::local_tempdir()
  primary <- "https://example.org/ontology"
  fallback <- "https://example.org/mirror"
  first <- fetch_test_call(setNames(list(function(sent) stop("primary unavailable"),
                                        function(sent) fetch_test_response(fallback,
                                          body = "mirror", etag = "mirror-tag",
                                          last_modified = "mirror-time")), c(primary, fallback)),
                           url = primary, cache_dir = cache, fallback_urls = fallback)
  primary_route <- function(sent) {
    if (!is.null(sent[["If-None-Match"]]) || !is.null(sent[["If-Modified-Since"]])) {
      fetch_test_response(primary, 304L)
    } else {
      fetch_test_response(primary, body = "primary", etag = "primary-tag")
    }
  }
  second <- fetch_test_call(setNames(list(primary_route), primary), url = primary,
                            cache_dir = cache, fallback_urls = fallback)
  expect_equal(readLines(second$value), "primary")
  expect_equal(readLines(first$value), "mirror")
  expect_false(identical(first$value, second$value))
  expect_null(second$requests[[1]]$headers[["If-None-Match"]])
  expect_null(second$requests[[1]]$headers[["If-Modified-Since"]])
  mirror <- fetch_test_call(setNames(list(function(sent) fetch_test_response(fallback, 304L)), fallback),
                            url = fallback, cache_dir = cache, fallback_urls = character())
  expect_equal(mirror$value, first$value)
  expect_equal(mirror$requests[[1]]$headers[["If-None-Match"]], "mirror-tag")
  expect_equal(mirror$requests[[1]]$headers[["If-Modified-Since"]], "mirror-time")
})

test_that("B335 a fresh 200 removes validators that it no longer supplies", {
  cache <- withr::local_tempdir()
  url <- "https://example.org/ontology"
  fetch_test_call(setNames(list(function(sent) fetch_test_response(url,
    etag = "old-tag", last_modified = "old-time")), url),
    url = url, cache_dir = cache, fallback_urls = character())
  fresh <- fetch_test_call(setNames(list(function(sent) fetch_test_response(url, body = "fresh")), url),
                           url = url, cache_dir = cache, fallback_urls = character())
  expect_equal(fresh$requests[[1]]$headers[["If-None-Match"]], "old-tag")
  expect_equal(fresh$requests[[1]]$headers[["If-Modified-Since"]], "old-time")
  next_call <- fetch_test_call(setNames(list(function(sent) fetch_test_response(url, body = "new")), url),
                               url = url, cache_dir = cache, fallback_urls = character())
  expect_null(next_call$requests[[1]]$headers[["If-None-Match"]])
  expect_null(next_call$requests[[1]]$headers[["If-Modified-Since"]])
})

test_that("B335 validators without their body cannot produce a cache hit", {
  cache <- withr::local_tempdir()
  url <- "https://example.org/ontology"
  first <- fetch_test_call(setNames(list(function(sent) fetch_test_response(url,
    etag = "old-tag", last_modified = "old-time")), url),
    url = url, cache_dir = cache, fallback_urls = character())
  unlink(first$value)
  result <- fetch_test_call(setNames(list(function(sent) fetch_test_response(url, body = "fresh")), url),
                            url = url, cache_dir = cache, fallback_urls = character())
  expect_null(result$requests[[1]]$headers[["If-None-Match"]])
  expect_null(result$requests[[1]]$headers[["If-Modified-Since"]])
  expect_equal(readLines(result$value), "fresh")

  unlink(result$value)
  no_body <- fetch_test_call(setNames(list(function(sent) fetch_test_response(url, 304L)), url),
                             url = url, cache_dir = cache, fallback_urls = character())
  expect_s3_class(no_body$value, "error")
  expect_false(file.exists(result$value))
})

test_that("B335 failed calls cannot return unrelated or legacy cache copies", {
  cache <- withr::local_tempdir()
  url <- "https://example.org/ontology"
  other <- "https://example.org/other"
  first <- fetch_test_call(setNames(list(function(sent) fetch_test_response(url, body = "matching")), url),
                           url = url, cache_dir = cache, accept = "text/turtle",
                           fallback_urls = character())
  unreachable <- function(sent) stop("offline stub")
  other_url <- fetch_test_call(setNames(list(unreachable), other), url = other,
                               cache_dir = cache, accept = "text/turtle",
                               fallback_urls = character())
  other_accept <- fetch_test_call(setNames(list(unreachable), url), url = url,
                                  cache_dir = cache, accept = "application/rdf+xml",
                                  fallback_urls = character())
  untried <- fetch_test_call(setNames(list(unreachable), other), url = other,
                             cache_dir = cache, accept = "text/turtle",
                             fallback_urls = character())
  expect_s3_class(other_url$value, "error")
  expect_s3_class(other_accept$value, "error")
  expect_s3_class(untried$value, "error")
  expect_equal(readLines(first$value), "matching")
  expect_equal(vapply(untried$requests, `[[`, character(1), "url"), other)
  legacy_cache <- withr::local_tempdir()
  writeLines("unqualified legacy body", file.path(legacy_cache, "salmon-ontology.ttl"))
  legacy <- fetch_test_call(setNames(list(unreachable), url), url = url,
                            cache_dir = legacy_cache, fallback_urls = character())
  expect_s3_class(legacy$value, "error")
})

test_that("B335 preserves the separately governed matching-cache failure policy", {
  cache <- withr::local_tempdir()
  url <- "https://example.org/ontology"
  first <- fetch_test_call(setNames(list(function(sent) fetch_test_response(url, body = "matching")), url),
                           url = url, cache_dir = cache, fallback_urls = character())
  failed <- fetch_test_call(setNames(list(function(sent) stop("offline stub")), url),
                            url = url, cache_dir = cache, fallback_urls = character())
  expect_equal(failed$value, first$value)
  expect_equal(readLines(failed$value), "matching")
  expect_length(failed$warnings, 1L)
  expect_match(failed$warnings, "using cached copy")
})
