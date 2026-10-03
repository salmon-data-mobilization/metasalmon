#' Fetch the Salmon Domain Ontology with caching
#'
#' Downloads the Salmon Domain Ontology using HTTP content negotiation and caches
#' the response using ETag / Last-Modified headers when available.
#' Each requested URL and Accept header has its own cached body and validators.
#' A returned path is therefore not overwritten by a fetch for another URL or
#' representation. Unqualified legacy cache files are not reused because their
#' URL and representation cannot be established. The matching-cache failure
#' policy is unchanged: if every attempted URL fails, a matching cached copy is
#' returned with a warning.
#'
#' @param url Ontology URL. Default is the canonical SMN namespace root.
#' @param accept Accept header; defaults to turtle with RDF/XML fallback.
#' @param cache_dir Directory to store cached ontology and headers. Defaults to
#'   a persistent user cache path.
#' @param fallback_urls Optional fallback ontology URLs tried if the primary `url`
#'   fails. The implicit SMN fallback is used only with the default `url`;
#'   callers naming another URL must explicitly supply its fallback URLs.
#' @param timeout_seconds Numeric timeout in seconds for each HTTP request.
#' @return Path to the cached ontology file (character string).
#' @examples
#' \dontrun{
#' # Needs the remote ontology; run in checks once a local fixture is supported.
#' ontology_path <- fetch_salmon_ontology(cache_dir = file.path(tempdir(), "smn-cache"))
#' }
#' @export
fetch_salmon_ontology <- function(
    url = "https://w3id.org/smn/",
    accept = "text/turtle, application/rdf+xml;q=0.8",
    cache_dir = file.path(tools::R_user_dir("metasalmon", which = "cache"), "ontology"),
    timeout_seconds = 30,
    fallback_urls = c(
      "https://w3id.org/smn"
    )) {

  # The default mirror serves SMN, so it must not answer a request for another
  # ontology. Keep explicit fallback choices and the public formals unchanged.
  if (missing(fallback_urls) && !identical(url, "https://w3id.org/smn/")) {
    fallback_urls <- character()
  }

  dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
  urls <- c(url, fallback_urls)
  res <- NULL
  last_error <- NULL
  cached_files <- character()

  for (u in urls) {
    # Validators belong to this requested URL/Accept pair, including when u is
    # a caller-selected fallback. An orphan header cannot validate a missing body.
    entry <- .ms_ontology_cache_entry(cache_dir, u, accept)
    ttl_file <- entry$body
    etag_file <- entry$etag
    lastmod_file <- entry$last_modified
    headers <- c(Accept = accept)
    if (file.exists(ttl_file)) {
      cached_files <- c(cached_files, ttl_file)
      if (file.exists(etag_file)) {
        etag <- .ms_read_cached_header(etag_file)
        if (!is.na(etag)) headers <- c(headers, `If-None-Match` = etag)
      }
      if (file.exists(lastmod_file)) {
        last_modified <- .ms_read_cached_header(lastmod_file)
        if (!is.na(last_modified)) {
          headers <- c(headers, `If-Modified-Since` = last_modified)
        }
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
      last_error <- res
      res <- NULL
      next
    }
    status <- httr::status_code(res)
    if (status == 200L || (status == 304L && file.exists(ttl_file))) {
      break
    } else {
      last_error <- if (status == 304L) {
        "HTTP 304 without a matching cached ontology body"
      } else {
        res
      }
      res <- NULL
    }
  }

  if (is.null(res)) {
    # Preserve the existing failure policy, but only for a body belonging to an
    # attempted URL and this Accept value. Legacy or unrelated bodies prove neither.
    if (length(cached_files) > 0L) {
      ttl_file <- cached_files[[1L]]
      cli::cli_warn(c(
        "Failed to refresh Salmon ontology; using cached copy at {.path {ttl_file}}.",
        "i" = "Last fetch error: {last_error}"
      ))
      return(ttl_file)
    }
    stop("Failed to fetch ontology from provided URLs: ", paste(urls, collapse = ", "),
         "; last error: ", last_error)
  }

  if (httr::status_code(res) == 304 && file.exists(ttl_file)) {
    return(ttl_file)
  }

  httr::stop_for_status(res)
  content <- httr::content(res, as = "text", encoding = "UTF-8")
  temp_ttl <- tempfile(tmpdir = cache_dir, fileext = ".ttl")
  on.exit(unlink(temp_ttl, force = TRUE), add = TRUE)
  writeLines(content, temp_ttl, useBytes = TRUE)
  if (!file.rename(temp_ttl, ttl_file)) {
    cli::cli_abort("Failed to update cached ontology file at {.path {ttl_file}}.")
  }

  # A 200 replaces the representation and its validator set. Headers omitted
  # by this response must not keep validating a previous body on the next call.
  unlink(c(etag_file, lastmod_file))
  etag <- httr::headers(res)[["etag"]]
  if (!is.null(etag) && nzchar(etag)) writeLines(etag, etag_file, useBytes = TRUE)
  lastmod <- httr::headers(res)[["last-modified"]]
  if (!is.null(lastmod) && nzchar(lastmod)) writeLines(lastmod, lastmod_file, useBytes = TRUE)

  ttl_file
}

# Match the URL/Accept naming already proposed in the paired R/Python fetch
# stream. Convert each declared string before joining bytes: translating a
# combined non-ASCII string through the native locale changes the hash in C.
.ms_ontology_cache_entry <- function(cache_dir, url, accept) {
  key <- substr(digest::digest(
    c(.ms_utf8_bytes(url), charToRaw("\n"), .ms_utf8_bytes(accept)),
    algo = "sha256", serialize = FALSE
  ), 1L, 16L)
  list(
    body = file.path(cache_dir, paste0(key, ".ttl")),
    etag = file.path(cache_dir, paste0(key, ".etag")),
    last_modified = file.path(cache_dir, paste0(key, ".last_modified"))
  )
}

.ms_utf8_bytes <- function(x) {
  charToRaw(if (identical(Encoding(x), "latin1")) enc2utf8(x) else x)
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
