# fetch_salmon_ontology(), with httr::GET() stubbed so no request leaves the
# process. Each rule here was demonstrated failing on the function as it stood
# before the change that introduced the rule, and metasalmonpy's
# `tests/test_ontology_fetch.py` pins the same rules on its side:
#
#   * hub B-333 (metasalmonpy B-334): the default fallback serves smn, so it is
#     tried for the default url only.
#   * hub B-335 (metasalmonpy B-336): each cached copy and its validators are
#     keyed by the URL that returned them and the accept they were fetched
#     under, with one naming scheme in both packages.
#   * hub B-422 (Q71 clarified by Brett on 2026-10-03): a failed refresh
#     warns and returns only a matching body not known to be stale.
#   * The follow-ups that converged the two fetchers' remaining differences on
#     2026-09-26: a copy holds exactly the bytes the server sent, and the
#     timeout bounds both the connection and the transfer.

of_smn <- "https://w3id.org/smn/"
of_smn_fallback <- "https://w3id.org/smn"
of_gcdfo <- "https://w3id.org/gcdfo/salmon"

# An answer in the shape httr::GET() returns. `body` is text, sent as its UTF-8
# bytes, or a raw vector sent as given.
of_answer <- function(url, status, body = "", etag = NULL, last_modified = NULL,
                      content_type = "text/turtle; charset=utf-8") {
  headers <- list(`content-type` = content_type)
  if (!is.null(etag)) headers$etag <- etag
  if (!is.null(last_modified)) headers$`last-modified` <- last_modified
  content <- if (is.raw(body)) body else charToRaw(enc2utf8(body))
  structure(
    list(url = url, status_code = as.integer(status), headers = headers, content = content),
    class = "response"
  )
}

# A route that always answers 200 with `body`.
of_ok <- function(url, body, etag = NULL, last_modified = NULL) {
  force(body)
  function(sent) of_answer(url, 200L, body, etag = etag, last_modified = last_modified)
}

# A route whose request never completes.
of_unreachable <- function(sent) stop("Could not resolve host (stub)")

# A route that answers 304 whenever the request carries a validator, and 200
# with `body` otherwise.
of_304_to_any_validator <- function(url, body, etag) {
  function(sent) {
    if (!is.null(sent[["If-None-Match"]]) || !is.null(sent[["If-Modified-Since"]])) {
      of_answer(url, 304L)
    } else {
      of_answer(url, 200L, body, etag = etag)
    }
  }
}

# Calls fetch_salmon_ontology(...) with httr::GET() answered by `routes`, a
# list mapping each URL to a function of the headers the request carried.
# Returns what the call returned (or the error it raised) and every request it
# made, with the headers and the curl options each carried.
of_fetch <- function(routes, ...) {
  requests <- list()
  get <- function(url, ...) {
    sent <- list()
    options <- list()
    for (config in list(...)) {
      if (inherits(config, "request") && length(config$headers) > 0L) {
        sent <- c(sent, as.list(config$headers))
      }
      if (inherits(config, "request") && length(config$options) > 0L) {
        options <- c(options, config$options)
      }
    }
    requests[[length(requests) + 1L]] <<- list(url = url, sent = sent, options = options)
    route <- routes[[url]]
    if (is.null(route)) stop("no route for ", url)
    route(sent)
  }
  testthat::local_mocked_bindings(GET = get, .package = "httr")
  warnings <- character()
  value <- tryCatch(withCallingHandlers(
    fetch_salmon_ontology(...),
    warning = function(w) {
      warnings <<- c(warnings, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  ), error = function(e) e)
  list(
    value = value,
    warnings = warnings,
    urls = vapply(requests, function(r) r$url, character(1)),
    sent = lapply(requests, function(r) r$sent),
    options = lapply(requests, function(r) r$options)
  )
}

of_bytes <- function(path) readBin(path, "raw", n = file.size(path))

of_body <- function(path) paste(readLines(path, warn = FALSE), collapse = "\n")

test_that("the default url's fallback is not tried for another ontology's url (hub B-333)", {
  # A call for gcdfo whose url fails used to go on to the default fallback,
  # which serves smn, and return smn's body under no warning.
  cache_dir <- withr::local_tempdir()
  got <- of_fetch(
    stats::setNames(list(of_unreachable, of_ok(of_smn_fallback, "SMN BODY")), c(of_gcdfo, of_smn_fallback)),
    url = of_gcdfo,
    cache_dir = cache_dir
  )
  expect_s3_class(got$value, "error")
  expect_match(conditionMessage(got$value), "Failed to fetch ontology from provided URLs: https://w3id.org/gcdfo/salmon;", fixed = TRUE)
  expect_identical(got$urls, of_gcdfo)
  expect_length(list.files(cache_dir), 0L)
})

test_that("the default url still reaches the default fallback (hub B-333 control)", {
  for (explicit in c(FALSE, TRUE)) {
    cache_dir <- withr::local_tempdir()
    routes <- stats::setNames(list(of_unreachable, of_ok(of_smn_fallback, "SMN BODY")), c(of_smn, of_smn_fallback))
    got <- if (explicit) {
      of_fetch(routes, url = of_smn, cache_dir = cache_dir)
    } else {
      of_fetch(routes, cache_dir = cache_dir)
    }
    expect_identical(got$urls, c(of_smn, of_smn_fallback))
    expect_identical(if (is.character(got$value)) of_body(got$value) else NULL, "SMN BODY")
  }

  # Named fallbacks are tried for any url, and character() names none.
  cache_dir <- withr::local_tempdir()
  got <- of_fetch(
    stats::setNames(list(of_unreachable, of_ok("https://example.org/gcdfo.ttl", "GCDFO BODY")), c(of_gcdfo, "https://example.org/gcdfo.ttl")),
    url = of_gcdfo,
    cache_dir = cache_dir,
    fallback_urls = "https://example.org/gcdfo.ttl"
  )
  expect_identical(of_body(got$value), "GCDFO BODY")
  got <- of_fetch(
    stats::setNames(list(of_unreachable, of_ok(of_smn_fallback, "SMN BODY")), c(of_smn, of_smn_fallback)),
    cache_dir = withr::local_tempdir(),
    fallback_urls = character()
  )
  expect_s3_class(got$value, "error")
  expect_identical(got$urls, of_smn)
})

test_that("two ontologies fetched into one cache_dir keep a copy each (hub B-335, sequence 1)", {
  cache_dir <- withr::local_tempdir()
  smn <- of_fetch(stats::setNames(list(of_ok(of_smn, "SMN BODY", etag = '"smn-1"')), of_smn), cache_dir = cache_dir)
  gcdfo <- of_fetch(
    stats::setNames(list(of_ok(of_gcdfo, "GCDFO BODY", etag = '"gcdfo-1"')), of_gcdfo),
    url = of_gcdfo,
    cache_dir = cache_dir,
    fallback_urls = character()
  )

  expect_false(identical(smn$value, gcdfo$value))
  expect_identical(of_body(smn$value), "SMN BODY")
  expect_identical(of_body(gcdfo$value), "GCDFO BODY")
  # The gcdfo request carried no validator: smn's ETag is smn's.
  expect_null(gcdfo$sent[[1]][["If-None-Match"]])

  # And smn's own validator still travels with smn.
  again <- of_fetch(
    stats::setNames(list(of_304_to_any_validator(of_smn, "CHANGED", '"smn-2"')), of_smn),
    cache_dir = cache_dir
  )
  expect_identical(again$sent[[1]][["If-None-Match"]], '"smn-1"')
  expect_identical(again$value, smn$value)
  expect_identical(of_body(again$value), "SMN BODY")
})

test_that("one url fetched under two accepts keeps a copy each (hub B-335, sequence 2)", {
  cache_dir <- withr::local_tempdir()
  turtle <- of_fetch(
    stats::setNames(list(of_ok(of_smn, "TURTLE BODY", etag = '"ttl-1"')), of_smn),
    cache_dir = cache_dir,
    accept = "text/turtle"
  )
  rdfxml <- of_fetch(
    stats::setNames(list(of_ok(of_smn, "RDFXML BODY", etag = '"rdf-1"')), of_smn),
    cache_dir = cache_dir,
    accept = "application/rdf+xml"
  )

  expect_false(identical(turtle$value, rdfxml$value))
  expect_identical(of_body(turtle$value), "TURTLE BODY")
  expect_identical(of_body(rdfxml$value), "RDFXML BODY")
  expect_null(rdfxml$sent[[1]][["If-None-Match"]])
})

test_that("a fallback's validators never answer for the url (hub B-335, sequence 3)", {
  # The url fails and its fallback answers; the fallback's copy and ETag are
  # the fallback's. The next call's url answers 304 to any validator, so if the
  # fallback's ETag were sent to it, the fallback's body would come back as the
  # url's -- which is what used to happen.
  cache_dir <- withr::local_tempdir()
  first <- of_fetch(
    stats::setNames(list(of_unreachable, of_ok(of_smn_fallback, "FALLBACK BODY", etag = '"fb-1"')), c(of_smn, of_smn_fallback)),
    cache_dir = cache_dir
  )
  expect_identical(of_body(first$value), "FALLBACK BODY")

  second <- of_fetch(
    stats::setNames(list(of_304_to_any_validator(of_smn, "URL BODY", '"url-1"')), of_smn),
    cache_dir = cache_dir
  )
  expect_null(second$sent[[1]][["If-None-Match"]])
  expect_identical(of_body(second$value), "URL BODY")
  expect_false(identical(second$value, first$value))
  # The fallback's copy is untouched.
  expect_identical(of_body(first$value), "FALLBACK BODY")
})

test_that("a refreshed copy replaces its validators rather than keeping stale ones (hub B-335)", {
  cache_dir <- withr::local_tempdir()
  of_fetch(stats::setNames(list(of_ok(of_smn, "V1", etag = '"v1"', last_modified = "Mon, 01 Jan 2024 00:00:00 GMT")), of_smn), cache_dir = cache_dir)
  # A 200 with no validators: the old ones described the old body.
  of_fetch(stats::setNames(list(of_ok(of_smn, "V2")), of_smn), cache_dir = cache_dir)
  third <- of_fetch(stats::setNames(list(of_ok(of_smn, "V3")), of_smn), cache_dir = cache_dir)
  expect_null(third$sent[[1]][["If-None-Match"]])
  expect_null(third$sent[[1]][["If-Modified-Since"]])
  expect_identical(of_body(third$value), "V3")
})

test_that("a 304 with no cached copy is that url's failure, not a copy (hub B-335)", {
  always_304 <- function(sent) of_answer(of_smn, 304L)
  got <- of_fetch(stats::setNames(list(always_304), of_smn), cache_dir = withr::local_tempdir(), fallback_urls = character())
  expect_s3_class(got$value, "error")
  expect_match(conditionMessage(got$value), "last error: HTTP 304", fixed = TRUE)

  # ...so the next url is tried.
  got <- of_fetch(
    stats::setNames(list(always_304, of_ok(of_smn_fallback, "SMN BODY")), c(of_smn, of_smn_fallback)),
    cache_dir = withr::local_tempdir()
  )
  expect_identical(of_body(got$value), "SMN BODY")
})

test_that("failed refresh warns and uses only a matching cache (Q71, B-422)", {
  cache_dir <- withr::local_tempdir()
  cached <- of_fetch(stats::setNames(list(of_ok(of_smn, "SMN BODY", etag = '"smn-1"')), of_smn),
                     cache_dir = cache_dir)$value
  for (failure in list(of_unreachable, function(sent) of_answer(of_smn, 503L))) {
    got <- of_fetch(stats::setNames(list(failure), of_smn), cache_dir = cache_dir,
                    fallback_urls = character())
    expect_identical(got$value, cached)
    expect_length(got$warnings, 1L)
    expect_match(paste(got$warnings, collapse = "\n"), "using cached copy", fixed = TRUE)
    expect_identical(if (is.character(got$value)) of_body(got$value) else NULL, "SMN BODY")
  }

  # No eligible matching body still errors and names the actual failure.
  got <- of_fetch(stats::setNames(list(function(sent) of_answer(of_smn, 503L)), of_smn),
                  cache_dir = withr::local_tempdir(), fallback_urls = character())
  expect_s3_class(got$value, "error")
  expect_match(conditionMessage(got$value), "last error: HTTP 503", fixed = TRUE)
})

test_that("a contradictory 304 makes its old cache ineligible on later calls (Q71)", {
  cache_dir <- withr::local_tempdir()
  of_fetch(stats::setNames(list(of_ok(of_smn, "V1", etag = '"v1"')), of_smn), cache_dir = cache_dir)
  got <- of_fetch(stats::setNames(list(function(sent) of_answer(of_smn, 304L, etag = '"v2"')), of_smn),
                  cache_dir = cache_dir, fallback_urls = character())
  expect_s3_class(got$value, "error")
  got <- of_fetch(stats::setNames(list(of_unreachable), of_smn), cache_dir = cache_dir,
                  fallback_urls = character())
  expect_s3_class(got$value, "error")
  expect_null(got$sent[[1]][["If-None-Match"]])

  # A fresh successful response repairs the invalidated entry.
  got <- of_fetch(stats::setNames(list(of_ok(of_smn, "V3", etag = '"v3"')), of_smn), cache_dir = cache_dir)
  expect_identical(of_body(got$value), "V3")
  again <- of_fetch(stats::setNames(list(of_unreachable), of_smn), cache_dir = cache_dir,
                    fallback_urls = character())
  expect_identical(again$value, got$value)
  expect_length(again$warnings, 1L)
  expect_identical(again$sent[[1]][["If-None-Match"]], '"v3"')
})

test_that("failed replacement storage cannot revive the superseded body (Q71)", {
  cache_dir <- withr::local_tempdir()
  cached <- of_fetch(stats::setNames(list(of_ok(of_smn, "V1", etag = '"v1"')), of_smn),
                     cache_dir = cache_dir)$value
  failed <- testthat::with_mocked_bindings(
    of_fetch(stats::setNames(list(of_ok(of_smn, "V2", etag = '"v2"')), of_smn),
             cache_dir = cache_dir, fallback_urls = character()),
    file.rename = function(...) FALSE, .package = "base"
  )
  expect_s3_class(failed$value, "error")
  # The atomic body write preserves the old bytes for inspection, but they
  # have been superseded and must no longer be used by the fetcher.
  expect_identical(of_body(cached), "V1")
  got <- of_fetch(stats::setNames(list(of_unreachable), of_smn), cache_dir = cache_dir,
                  fallback_urls = character())
  expect_s3_class(got$value, "error")
  expect_null(got$sent[[1]][["If-None-Match"]])
})

test_that("the cache file names are the ones metasalmonpy writes (hub B-335)", {
  # The first 16 hexadecimal digits of the SHA-256 of the UTF-8 bytes of the
  # url, a newline and the accept. metasalmonpy's test pins the same four.
  key <- function(url, accept) sub("\\.ttl$", "", basename(metasalmon:::.ms_ontology_cache_entry(tempdir(), url, accept)$body))
  expect_identical(key(of_smn, "text/turtle, application/rdf+xml;q=0.8"), "5891e28fd43e0292")
  expect_identical(key(of_smn_fallback, "text/turtle, application/rdf+xml;q=0.8"), "5188e73de1bcc279")
  expect_identical(key(of_smn, "application/rdf+xml"), "8fa14febd5b318d1")
  expect_identical(key("https://example.org/ontologie/unit\u00e9", "text/turtle"), "6bf05a094db6a6b1")

  entry <- metasalmon:::.ms_ontology_cache_entry("cache", of_smn, "text/turtle, application/rdf+xml;q=0.8")
  expect_identical(basename(unlist(entry, use.names = FALSE)), c(
    "5891e28fd43e0292.ttl", "5891e28fd43e0292.etag", "5891e28fd43e0292.last_modified"
  ))

  cache_dir <- withr::local_tempdir()
  got <- of_fetch(stats::setNames(list(of_ok(of_smn, "SMN BODY", etag = '"e"', last_modified = "Mon, 01 Jan 2024 00:00:00 GMT")), of_smn), cache_dir = cache_dir)
  expect_identical(basename(got$value), "5891e28fd43e0292.ttl")
  expect_setequal(list.files(cache_dir), c("5891e28fd43e0292.ttl", "5891e28fd43e0292.etag", "5891e28fd43e0292.last_modified"))
})

test_that("the default url is smn's, the one metasalmonpy defaults to (Q71 clause 1)", {
  expect_identical(formals(fetch_salmon_ontology)$url, "https://w3id.org/smn/")
  expect_null(formals(fetch_salmon_ontology)$fallback_urls)
})

test_that("a copy holds exactly the bytes the server sent", {
  # The body used to be decoded as UTF-8 and written back with writeLines(), so
  # every copy gained a final newline, a CRLF body gained a bare LF, and a body
  # that was not valid UTF-8 was stored as the two characters "NA".
  # metasalmonpy decoded a text type sent with no charset as ISO-8859-1. Both
  # now store the bytes as sent; its twin test sends the same four bodies.
  bodies <- list(
    no_final_newline = charToRaw(enc2utf8("@prefix smn: <https://w3id.org/smn/> .\nsmn:Unit\u00e9 a smn:Thing .")),
    latin1 = as.raw(c(0x63, 0x61, 0x66, 0xe9, 0x0a)),
    crlf = charToRaw("a\r\nb\r\n"),
    empty = raw(0)
  )
  for (name in names(bodies)) {
    body <- bodies[[name]]
    got <- of_fetch(
      stats::setNames(list(function(sent) of_answer(of_smn, 200L, body, content_type = "text/turtle")), of_smn),
      cache_dir = withr::local_tempdir()
    )
    expect_identical(of_bytes(got$value), body, info = name)
  }
})

test_that("a validator is stored as the header's bytes and a newline, in both packages", {
  cache_dir <- withr::local_tempdir()
  got <- of_fetch(
    stats::setNames(list(of_ok(of_smn, "SMN BODY", etag = '"e"', last_modified = "Mon, 01 Jan 2024 00:00:00 GMT")), of_smn),
    cache_dir = cache_dir
  )
  entry <- metasalmon:::.ms_ontology_cache_entry(cache_dir, of_smn, "text/turtle, application/rdf+xml;q=0.8")
  expect_identical(of_bytes(entry$etag), charToRaw('"e"\n'))
  expect_identical(of_bytes(entry$last_modified), charToRaw("Mon, 01 Jan 2024 00:00:00 GMT\n"))
})

test_that("timeout_seconds bounds both the connection and the transfer", {
  # The rule metasalmonpy ported on 2026-09-26: it took a fixed 15 s.
  got <- of_fetch(stats::setNames(list(of_ok(of_smn, "SMN BODY")), of_smn), cache_dir = withr::local_tempdir())
  expect_identical(got$options[[1]]$timeout_ms, 30000)
  expect_identical(got$options[[1]]$connecttimeout, 30)

  got <- of_fetch(
    stats::setNames(list(of_unreachable, of_ok(of_smn_fallback, "SMN BODY")), c(of_smn, of_smn_fallback)),
    cache_dir = withr::local_tempdir(),
    timeout_seconds = 5
  )
  for (options in got$options) {
    expect_identical(options$timeout_ms, 5000)
    expect_identical(options$connecttimeout, 5)
  }
})

test_that("the cache key is taken from UTF-8 bytes in any locale", {
  # A URL read without a declared encoding is a string of unknown encoding.
  # Under a C locale, enc2utf8() wrote its non-ASCII bytes out as the text
  # "<c3><a9>", so the key differed from the one metasalmonpy computes for the
  # same URL (0f607d2dd94734a9 against 6bf05a094db6a6b1, measured 2026-09-26).
  url <- rawToChar(c(charToRaw("https://example.org/ontologie/unit"), as.raw(c(0xc3, 0xa9))))
  expect_identical(Encoding(url), "unknown")
  key <- function(u) {
    sub("[.]ttl$", "", basename(metasalmon:::.ms_ontology_cache_entry(tempdir(), u, "text/turtle")$body))
  }
  expect_identical(key(url), "6bf05a094db6a6b1")
  withr::with_locale(c(LC_CTYPE = "C"), expect_identical(key(url), "6bf05a094db6a6b1"))

  # A string declared latin1 is converted to UTF-8 first.
  latin1 <- iconv(rawToChar(c(charToRaw("https://example.org/ontologie/unit"), as.raw(0xe9))), "latin1", "latin1")
  Encoding(latin1) <- "latin1"
  expect_identical(key(latin1), "6bf05a094db6a6b1")
})
