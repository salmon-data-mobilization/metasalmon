#' Fetch the Salmon Domain Ontology with caching
#'
#' Downloads an ontology, by default the Salmon Domain Ontology (smn), using
#' HTTP content negotiation, and caches each response with its ETag /
#' Last-Modified validators when the server sends them, so that an unchanged
#' ontology is not downloaded again.
#'
#' Each copy is cached under the URL that returned it and the `accept` it was
#' fetched under: its file name is the first 16 hexadecimal digits of the
#' SHA-256 of the URL, a newline and `accept` (as UTF-8), with the extension
#' `.ttl` whatever the representation, and its validators sit beside it with
#' the extensions `.etag` and `.last_modified`. Fetches of different URLs or
#' representations into one `cache_dir` therefore never overwrite each other,
#' a conditional request carries only the validators that the URL it is sent
#' to returned under the same `accept`, and a `304` answer returns that URL's
#' own copy. metasalmonpy names its cache files the same way.
#'
#' @param url Ontology URL. Default is the canonical SMN namespace root.
#' @param accept Accept header; defaults to turtle with RDF/XML fallback.
#' @param cache_dir Directory to store cached ontology and headers. Defaults to
#'   a persistent user cache path.
#' @param fallback_urls URLs tried in order when `url` fails. `NULL` (the
#'   default) tries `"https://w3id.org/smn"` when `url` is the default and none
#'   otherwise: that fallback serves smn, so a call for any other ontology must
#'   not be answered by it. `character()` tries none.
#' @param timeout_seconds Numeric timeout in seconds for each HTTP request. It
#'   bounds both the connection and the whole transfer.
#' @return Path to the cached copy that the answering URL returned (character
#'   string), which holds exactly the bytes that URL sent: it is not decoded,
#'   re-encoded or given a final newline. If every URL fails, the call raises an
#'   error naming the URLs and
#'   the last failure, even when a copy fetched by an earlier call is cached: a
#'   copy that could not be refreshed is not returned. That copy is left on
#'   disk.
#' @export
fetch_salmon_ontology <- function(
    url = "https://w3id.org/smn/",
    accept = "text/turtle, application/rdf+xml;q=0.8",
    cache_dir = file.path(tools::R_user_dir("metasalmon", which = "cache"), "ontology"),
    timeout_seconds = 30,
    fallback_urls = NULL) {

  # The default fallback serves smn, so it belongs to the default url alone. It
  # used to follow any url, and a call for gcdfo whose url failed returned smn's
  # body under no warning (hub B-333; metasalmonpy's twin is B-334). "The
  # default" is read from this function's own formals, so it cannot drift from
  # the signature.
  if (is.null(fallback_urls)) {
    fallback_urls <- if (identical(url, formals(sys.function())[["url"]])) {
      "https://w3id.org/smn"
    } else {
      character()
    }
  }

  dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
  urls <- c(url, fallback_urls)
  last_error <- NA_character_

  for (u in urls) {
    entry <- .ms_ontology_cache_entry(cache_dir, u, accept)

    # A validator travels only with the copy it describes: the one this URL
    # returned under this accept (hub B-335). One set of validators used to be
    # shared by every URL and representation in `cache_dir`, so a `304` could
    # answer for another URL's or another representation's body.
    headers <- c(Accept = accept)
    if (file.exists(entry$body)) {
      etag <- if (file.exists(entry$etag)) .ms_read_cached_header(entry$etag) else NA_character_
      if (!is.na(etag)) {
        headers <- c(headers, `If-None-Match` = etag)
      }
      last_modified <- if (file.exists(entry$last_modified)) .ms_read_cached_header(entry$last_modified) else NA_character_
      if (!is.na(last_modified)) {
        headers <- c(headers, `If-Modified-Since` = last_modified)
      }
    }

    res <- try(
      httr::GET(
        u,
        httr::add_headers(.headers = headers),
        httr::timeout(timeout_seconds),
        httr::config(connecttimeout = timeout_seconds)
      ),
      silent = TRUE
    )
    if (inherits(res, "try-error")) {
      last_error <- conditionMessage(attr(res, "condition"))
      next
    }

    status <- as.integer(httr::status_code(res))
    if (identical(status, 200L)) {
      return(.ms_ontology_cache_store(entry, res))
    }
    # A `304` can only confirm a copy this URL returned. With none cached it is
    # this URL's failure, and the next URL is tried.
    if (identical(status, 304L) && file.exists(entry$body)) {
      return(entry$body)
    }
    last_error <- paste("HTTP", status)
  }

  # Every URL failed. A copy cached by an earlier call is not returned, however
  # it got there (hub B-422; Q71 clause 2, ruled by Brett on 2026-09-26). It
  # used to come back as an ordinary value under a warning, which is a failure
  # read as a success, and metasalmonpy already raised here. The last failure
  # is named as metasalmonpy names it: the condition's message, or
  # `HTTP <status>`, where this used to paste the response object and print
  # nothing.
  stop(
    "Failed to fetch ontology from provided URLs: ", paste(urls, collapse = ", "),
    "; last error: ", last_error
  )
}

# Where one cached copy and its validators live: a name derived from the URL as
# requested (before any redirect) and the `accept` it was requested under, so
# no two URLs or representations share a file (hub B-335). The key is the first
# 16 hexadecimal digits -- 64 bits, which keeps a deep cache path well inside
# Windows' 260-character limit and makes a collision among the handful of URLs
# one directory holds negligible -- of the SHA-256 of the UTF-8 bytes of the
# URL, a newline and the accept. metasalmonpy's `_cache_entry()`
# (ontology_fetch.py) computes the same name, and
# `tests/testthat/test-ontology-fetch.R` pins four inputs its twin also pins.
.ms_ontology_cache_entry <- function(cache_dir, url, accept) {
  key <- substr(
    digest::digest(
      charToRaw(enc2utf8(paste0(url, "\n", accept))),
      algo = "sha256",
      serialize = FALSE
    ),
    1L,
    16L
  )
  list(
    body = file.path(cache_dir, paste0(key, ".ttl")),
    etag = file.path(cache_dir, paste0(key, ".etag")),
    last_modified = file.path(cache_dir, paste0(key, ".last_modified"))
  )
}

# Stores a `200` answer as `entry`'s copy, with the validators that came with
# it and no others, and returns the copy's path.
#
# The copy is the body's bytes exactly as the server sent them, written to a
# temporary file in the same directory and renamed over the old copy, so an
# aborted call leaves the previous copy whole. It used to be decoded as UTF-8
# and written back with `writeLines()`, which added a final newline to every
# copy and stored a body that was not valid UTF-8 as the text "NA".
# metasalmonpy writes the same bytes the same way (`atomic_io.atomic_write()`).
.ms_ontology_cache_store <- function(entry, res) {
  content <- httr::content(res, as = "raw")

  # The old validators describe the old body, so they go first: a failure
  # part-way through leaves a copy with no validators, which is fetched in full
  # next time, rather than a new body paired with an old body's validators.
  unlink(c(entry$etag, entry$last_modified), force = TRUE)

  temp_ttl <- tempfile(tmpdir = dirname(entry$body), fileext = ".ttl")
  on.exit(unlink(temp_ttl, force = TRUE), add = TRUE)
  writeBin(content, temp_ttl)
  if (!file.rename(temp_ttl, entry$body)) {
    cli::cli_abort("Failed to update cached ontology file at {.path {entry$body}}.")
  }

  .ms_ontology_store_validator(httr::headers(res)[["etag"]], entry$etag)
  .ms_ontology_store_validator(httr::headers(res)[["last-modified"]], entry$last_modified)

  entry$body
}

# A validator file is the header value's bytes and a newline, written in
# binary so that it is the same file on every platform and from either
# package; metasalmonpy writes it the same way.
.ms_ontology_store_validator <- function(value, path) {
  if (!is.null(value) && nzchar(value)) {
    writeBin(c(charToRaw(value), charToRaw("\n")), path)
  }
  invisible(path)
}

.ms_read_cached_header <- function(path) {
  value <- readLines(path, warn = FALSE, n = 1)
  if (length(value) == 0) {
    return(NA_character_)
  }
  value <- trimws(value[[1]])
  if (!nzchar(value)) {
    return(NA_character_)
  }
  value
}
