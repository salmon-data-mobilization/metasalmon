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
#' own copy. The matching metasalmonpy cache layout is still owed in its
#' ontology-fetch stream (B-334/B-336 and PR75).
#'
#' @param url Ontology URL. Default is the canonical SMN namespace root.
#' @param accept Accept header; defaults to turtle with RDF/XML fallback.
#' @param cache_dir Directory to store cached ontology and headers. Defaults to
#'   a persistent user cache path.
#' @param fallback_urls URLs tried in order when `url` fails. The implicit SMN
#'   fallback is used only when `url` is the default; callers naming another
#'   ontology must explicitly supply its fallback URLs. `NULL` or `character()`
#'   explicitly tries none.
#' @param timeout_seconds Numeric timeout in seconds for each HTTP request. It
#'   bounds both the connection and the whole transfer.
#' @return Path to the cached copy that the answering URL returned (character
#'   string), which holds exactly the bytes that URL sent: it is not decoded,
#'   re-encoded or given a final newline. If every URL fails to refresh, a
#'   matching copy from an attempted URL and the requested `accept` is returned
#'   with a warning, provided it is not known to be stale. Unrelated, legacy,
#'   invalidated or mismatching copies are never used. A replacement response
#'   or contradictory ETag invalidates the previous representation, even when
#'   storing its replacement fails. The old body stays on disk for inspection
#'   with a `.invalid` marker until a successful replacement makes it reusable.
#'   Without an eligible matching copy the call errors with the last failure.
#' @export
fetch_salmon_ontology <- function(
    url = "https://w3id.org/smn/",
    accept = "text/turtle, application/rdf+xml;q=0.8",
    cache_dir = file.path(tools::R_user_dir("metasalmon", which = "cache"), "ontology"),
    timeout_seconds = 30,
    fallback_urls = c("https://w3id.org/smn")) {

  # Keep the canonical public formals and explicit caller choices (B333).
  # The implicit mirror serves SMN and cannot answer for another ontology.
  if (missing(fallback_urls) && !identical(url, "https://w3id.org/smn/")) {
    fallback_urls <- character()
  }

  dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
  urls <- c(url, fallback_urls)
  last_error <- NA_character_
  cached_entries <- list()

  for (u in urls) {
    entry <- .ms_ontology_cache_entry(cache_dir, u, accept)

    # A validator travels only with the copy it describes: the one this URL
    # returned under this accept (hub B-335). One set of validators used to be
    # shared by every URL and representation in `cache_dir`, so a `304` could
    # answer for another URL's or another representation's body.
    headers <- c(Accept = accept)
    if (.ms_ontology_cache_usable(entry)) {
      cached_entries[[length(cached_entries) + 1L]] <- entry
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
      last_error <- .ms_redact_secrets(conditionMessage(attr(res, "condition")))
      next
    }

    status <- as.integer(httr::status_code(res))
    if (identical(status, 200L)) {
      return(.ms_ontology_cache_store(entry, res))
    }
    # A `304` can only confirm a copy this URL returned. With none cached it is
    # this URL's failure, and the next URL is tried.
    if (identical(status, 304L) && .ms_ontology_cache_usable(entry)) {
      received_etag <- httr::headers(res)[["etag"]]
      sent_etag <- as.list(headers)[["If-None-Match"]]
      # A contradictory validator does not confirm this representation. Weak
      # and strong spelling of the same opaque tag are equivalent for GET.
      if (!is.null(received_etag) && !is.null(sent_etag) &&
          !identical(sub("^W/", "", received_etag), sub("^W/", "", sent_etag))) {
        .ms_ontology_cache_invalidate(entry)
        last_error <- "HTTP 304 with a mismatching ETag"
        next
      }
      return(entry$body)
    }
    last_error <- paste("HTTP", status)
  }

  # A failed refresh is not evidence of staleness (Brett, Q71, 2026-10-03).
  # Recheck eligibility because a later attempt can invalidate the same entry.
  for (entry in cached_entries) {
    if (.ms_ontology_cache_usable(entry)) {
      cached_path <- entry$body
      cli::cli_warn(c(
        "Failed to refresh Salmon ontology; using cached copy at {.path {cached_path}}.",
        .ms_cli_bullets(paste0("Last fetch error: ", last_error), "i")
      ))
      return(cached_path)
    }
  }
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
# URL, a newline and the accept. The four golden inputs in
# `tests/testthat/test-ontology-fetch.R` define the layout that the pending
# metasalmonpy B-336 port must also implement.
#
# The bytes are taken from each part on its own, never through `paste0()` or
# `enc2utf8()` on a string of unknown encoding: under a non-UTF-8 locale both
# translate such a string through the native encoding, which wrote its
# non-ASCII bytes out as the text "<c3><a9>" and gave a key different from
# hashing the requested UTF-8 bytes directly.
.ms_ontology_cache_entry <- function(cache_dir, url, accept) {
  key <- substr(
    digest::digest(
      c(.ms_utf8_bytes(url), charToRaw("\n"), .ms_utf8_bytes(accept)),
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

# The UTF-8 bytes of one string: a string declared latin1 is converted, and any
# other is taken as the bytes it holds, which are UTF-8 for a string marked
# UTF-8 and for any string in a UTF-8 session.
.ms_utf8_bytes <- function(x) {
  charToRaw(if (identical(Encoding(x), "latin1")) enc2utf8(x) else x)
}

# Stores a `200` answer as `entry`'s copy, with the validators that came with
# it and no others, and returns the copy's path.
#
# The copy is the body's bytes exactly as the server sent them, written to a
# temporary file in the same directory and renamed over the old copy, so an
# aborted call leaves the previous copy whole. It used to be decoded as UTF-8
# and written back with `writeLines()`, which added a final newline to every
# copy and stored a body that was not valid UTF-8 as the text "NA".
# Exact-byte storage remains owed in the metasalmonpy ontology-fetch stream.
.ms_ontology_cache_store <- function(entry, res) {
  # Receiving a full replacement makes the nominated old body unsuitable.
  # Persist that fact before decoding or writing so an interrupted refresh
  # cannot revive it on the next offline call (RFC 9111, section 4.3.3).
  .ms_ontology_cache_invalidate(entry)
  content <- httr::content(res, as = "raw")

  # The old validators describe the old body, so they go first: a failure
  # part-way through leaves a copy with no validators, which is fetched in full
  # next time, rather than a new body paired with an old body's validators.
  unlink(c(entry$etag, entry$last_modified), force = TRUE)
  if (any(file.exists(c(entry$etag, entry$last_modified)))) {
    cli::cli_abort("Failed to reset cached ontology validators.")
  }

  temp_ttl <- tempfile(tmpdir = dirname(entry$body), fileext = ".ttl")
  on.exit(unlink(temp_ttl, force = TRUE), add = TRUE)
  writeBin(content, temp_ttl)
  if (!file.rename(temp_ttl, entry$body)) {
    cli::cli_abort("Failed to update cached ontology file at {.path {entry$body}}.")
  }

  .ms_ontology_store_validator(httr::headers(res)[["etag"]], entry$etag)
  .ms_ontology_store_validator(httr::headers(res)[["last-modified"]], entry$last_modified)
  unlink(paste0(entry$body, ".invalid"), force = TRUE)
  if (file.exists(paste0(entry$body, ".invalid"))) {
    cli::cli_abort("Failed to complete cached ontology replacement.")
  }

  entry$body
}

# A marker belongs to exactly one URL/Accept entry. Retain superseded bytes
# for inspection but exclude both that body and its validators from reuse.
# The marker retires when a successful replacement stores the complete body
# and validator set; cache age alone never creates one.
.ms_ontology_cache_usable <- function(entry) {
  file.exists(entry$body) && !file.exists(paste0(entry$body, ".invalid"))
}

.ms_ontology_cache_invalidate <- function(entry) {
  writeBin(charToRaw("superseded\n"), paste0(entry$body, ".invalid"))
  invisible(entry)
}

# A validator file is the header value's bytes and a newline, written in
# binary so that it is the same file on every platform. The metasalmonpy port
# must preserve these bytes too; that port is still pending.
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
