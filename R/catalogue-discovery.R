# Interim public Solr metadata capture, not S14's DatasetReceipt/source-fetch API.
# No publication, package creation, ontology assertion or review is performed.

.ms_catalogue_fields <- function() {
  paste(c(
    "id", "title", "formatId", "formatType", "authoritativeMN", "obsoletes",
    "obsoletedBy", "dateUploaded", "dateModified", "beginDate", "endDate",
    "resourceMap"
  ), collapse = ",")
}

.ms_catalogue_path_exists <- function(path) {
  link <- Sys.readlink(path)
  file.exists(path) || dir.exists(path) || (!is.na(link) && nzchar(link))
}

.ms_catalogue_reserve_directory <- function(path) {
  dir.create(path, showWarnings = FALSE)
}

.ms_catalogue_move_artifact <- function(from, to) {
  file.rename(from, to)
}

.ms_catalogue_whole_number <- function(value, minimum, maximum = Inf) {
  is.numeric(value) && length(value) == 1L && !is.na(value) &&
    is.finite(value) && value == floor(value) &&
    value >= minimum && value <= maximum
}

.ms_catalogue_capture_stamp <- function(captured_at) {
  if (is.null(captured_at)) {
    return(.ms_iso_stamp(Sys.time(), "-%m-%dT%H:%M:%OS6+00:00", tz = "UTC"))
  }
  shape <- "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\\.[0-9]+)?(Z|[+-][0-9]{2}:[0-9]{2})$"
  valid <- is.character(captured_at) && length(captured_at) == 1L &&
    !is.na(captured_at) && grepl(shape, captured_at)
  if (valid) {
    local_time <- sub("(Z|[+-][0-9]{2}:[0-9]{2})$", "", captured_at)
    offset <- sub(".*(Z|[+-][0-9]{2}:[0-9]{2})$", "\\1", captured_at)
    parsed <- suppressWarnings(as.POSIXct(
      substr(local_time, 1L, 19L), format = "%Y-%m-%dT%H:%M:%S", tz = "UTC"
    ))
    valid <- !is.na(parsed) && as.integer(substr(local_time, 1L, 4L)) >= 1L &&
      as.integer(substr(local_time, 12L, 13L)) <= 23L &&
      as.integer(substr(local_time, 15L, 16L)) <= 59L &&
      as.integer(substr(local_time, 18L, 19L)) <= 59L &&
      (identical(offset, "Z") ||
        (as.integer(substr(offset, 2L, 3L)) <= 23L &&
          as.integer(substr(offset, 5L, 6L)) <= 59L))
  }
  if (!valid) {
    stop("captured_at must be a valid ISO timestamp including a timezone", call. = FALSE)
  }
  captured_at
}

.ms_catalogue_url <- function(endpoint, query, start, rows) {
  parameters <- list(
    q = query, fq = "formatType:METADATA", fl = .ms_catalogue_fields(),
    sort = "id asc", start = start, rows = rows, wt = "json"
  )
  values <- vapply(parameters, function(value) {
    utils::URLencode(as.character(value), reserved = TRUE, repeated = TRUE)
  }, character(1))
  paste0(endpoint, "?", paste0(names(values), "=", values, collapse = "&"))
}

.ms_catalogue_public_get <- function(url, timeout, max_bytes) {
  # httr2 does not inherit httr's global authentication configuration. Explicitly
  # disable netrc and use only public headers; no token option is consulted.
  request <- httr2::request(url) |>
    httr2::req_headers(
      `User-Agent` = "MetaSalmon-public-discovery/0.1",
      Accept = "application/json"
    ) |>
    httr2::req_options(proxy = "", netrc = 0L) |>
    httr2::req_timeout(timeout) |>
    httr2::req_error(is_error = function(response) FALSE)
  response <- httr2::req_perform_connection(request)
  on.exit(response$body$close(), add = TRUE)
  status <- httr2::resp_status(response)
  if (status < 200L || status >= 300L) {
    stop(paste0("Public catalogue request failed (HTTP ", status, ")"), call. = FALSE)
  }
  bytes <- raw()
  while (!response$body$is_complete()) {
    chunk <- response$body$read(min(65536L, max_bytes + 1L - length(bytes)))
    bytes <- c(bytes, chunk)
    if (length(bytes) > max_bytes) {
      stop("Catalogue page exceeds max_bytes", call. = FALSE)
    }
  }
  bytes
}

.ms_catalogue_write_receipt <- function(receipt, path) {
  json <- jsonlite::toJSON(
    receipt, auto_unbox = TRUE, pretty = TRUE, null = "null", digits = NA
  )
  temporary <- tempfile(".receipt-", tmpdir = dirname(path))
  on.exit(unlink(temporary), add = TRUE)
  writeBin(charToRaw(paste0(enc2utf8(json), "\n")), temporary)
  if (!file.rename(temporary, path)) {
    stop("Could not finalize catalogue receipt", call. = FALSE)
  }
}

#' Capture a bounded public catalogue metadata query
#'
#' Capture unauthenticated KNB or DataONE Solr metadata pages with a provenance
#' receipt. This is an interim metadata-discovery helper, not a Salmon Data
#' Package, a submission catalogue, or the full source-fetch/DatasetReceipt API.
#'
#' @param query One nonblank Solr query string, at most 4096 characters.
#' @param out A new output directory. Existing destinations (including dangling
#'   symlinks) or an existing `.incomplete` sibling are never overwritten.
#' @param catalogue Exactly `"knb"` (default) or `"dataone"`. Endpoints come from
#'   the existing production KNB environment registry; no custom endpoint.
#' @param max_records Maximum metadata records to capture, a whole number from
#'   1 to 1000. A cap-limited capture is not a complete catalogue search.
#' @param page_size Requested records per page, a whole number from 1 to 100.
#' @param timeout Positive request timeout, at most 120 seconds.
#' @param max_bytes Maximum bytes per raw page, a whole number from 1 to
#'   10000000. Default: 2000000. Enforced by both the default and injected fetch.
#' @param fetch Optional function `fetch(url, timeout, max_bytes)` returning a
#'   raw vector. Use this seam for offline fixtures or explicitly controlled
#'   public network routing; `NULL` uses direct public HTTPS with inherited
#'   proxies and netrc credentials disabled.
#' @param captured_at Optional ISO timestamp including timezone. `NULL` records
#'   the current UTC capture time, not historical data availability.
#'
#' @return A list also written to `out/capture.json`, containing query,
#'   endpoint, capture time, reported/captured metadata counts, completeness,
#'   page URLs and byte SHA-256 checksums, and untransformed metadata records.
#'   `annotation_status` remains `"pending"`, `independent_dataset_count` is
#'   `NULL`, and `transactional_snapshot` is `FALSE`.
#'
#' @details
#' The fixed filter is `formatType:METADATA`; results request `id asc` sorting.
#' Paging offsets, count stability, missing/repeated identifiers and premature
#' empty pages are checked. Response counts/offsets must be finite nonnegative
#' integer-valued JSON numbers no greater than `2^53 - 1`, excluding booleans;
#' `3` and `3.0` have the same mathematical meaning. A live index can still change without changing its
#' count, so even a complete-for-reported-count capture is not transactional.
#' Metadata versions/encounters are not independent datasets. Source objects
#' are not downloaded, semantic decisions are not accepted, and credentials,
#' model providers and publication APIs are not used.
#'
#' The destination is reserved before fetching. On failure an `.incomplete`
#' sibling is exclusively reserved for raw pages and `failure.json`; if that
#' sibling appeared concurrently, the owned output directory remains instead. Errors
#' are propagated and no successful receipt is reported. Inspect preserved
#' evidence and rerun to a new destination rather than overwriting it.
#'
#' @examples
#' # Offline example; no catalogue or provider is contacted.
#' mock <- function(url, timeout, max_bytes) {
#'   charToRaw('{"response":{"numFound":0,"start":0,"docs":[]}}')
#' }
#' output <- tempfile("catalogue-capture-")
#' receipt <- capture_catalogue_query("Fraser AND sockeye", output, fetch = mock)
#' receipt$captured_metadata_records
#' unlink(output, recursive = TRUE)
#' @export
capture_catalogue_query <- function(query, out, catalogue = "knb",
                                    max_records = 100L, page_size = 50L,
                                    timeout = 30, max_bytes = 2000000L,
                                    fetch = NULL, captured_at = NULL) {
  if (!is.character(query) || length(query) != 1L || is.na(query) ||
      !nzchar(trimws(query)) || nchar(query) > 4096L) {
    stop("query must be nonblank text of at most 4096 characters", call. = FALSE)
  }
  if (!is.character(catalogue) || length(catalogue) != 1L ||
      is.na(catalogue) || !catalogue %in% c("knb", "dataone")) {
    stop("catalogue must be knb or dataone", call. = FALSE)
  }
  caps <- list(max_records = max_records, page_size = page_size, max_bytes = max_bytes)
  limits <- c(max_records = 1000L, page_size = 100L, max_bytes = 10000000L)
  for (name in names(caps)) {
    if (!.ms_catalogue_whole_number(caps[[name]], 1L, limits[[name]])) {
      stop(paste0(name, " must be a whole number from 1 to ", limits[[name]]), call. = FALSE)
    }
  }
  if (!is.numeric(timeout) || length(timeout) != 1L || is.na(timeout) ||
      !is.finite(timeout) || timeout <= 0 || timeout > 120) {
    stop("timeout must be positive and at most 120 seconds", call. = FALSE)
  }
  if (!is.null(fetch) && !is.function(fetch)) {
    stop("fetch must be a function or NULL", call. = FALSE)
  }
  if (!is.character(out) || length(out) != 1L || is.na(out) ||
      !nzchar(trimws(out))) {
    stop("out must name one new output directory", call. = FALSE)
  }
  stamp <- .ms_catalogue_capture_stamp(captured_at)
  # Match Path() normalization so a trailing separator cannot turn the
  # incomplete sibling into a child of the owned capture directory.
  out <- path.expand(out)
  out <- file.path(dirname(out), basename(out))
  incomplete <- paste0(out, ".incomplete")
  if (.ms_catalogue_path_exists(out) || .ms_catalogue_path_exists(incomplete)) {
    stop("Capture destination must be new; existing evidence is never overwritten", call. = FALSE)
  }
  parent <- dirname(out)
  if (!dir.exists(parent) && !dir.create(parent, recursive = TRUE, showWarnings = FALSE)) {
    stop("Could not create capture parent directory", call. = FALSE)
  }
  # Reservation, rather than a final directory rename, prevents competing
  # creators from having their empty directory replaced after the fetch.
  if (!.ms_catalogue_reserve_directory(out)) {
    stop("Capture destination must be new; existing evidence is never overwritten", call. = FALSE)
  }
  pages <- list()
  docs <- list()
  seen <- character()
  total <- NULL
  tryCatch({
    config <- .ms_knb_config("production")
    endpoint <- if (identical(catalogue, "knb")) {
      paste0(config$mn_endpoint, "/query/solr/")
    } else {
      config$solr_endpoint
    }
    transport <- if (is.null(fetch)) .ms_catalogue_public_get else fetch
    while (length(docs) < max_records) {
      start <- length(docs)
      rows <- min(page_size, max_records - start)
      url <- .ms_catalogue_url(endpoint, query, start, rows)
      raw_page <- transport(url, timeout, max_bytes)
      if (!is.raw(raw_page) || length(raw_page) > max_bytes) {
        stop("fetch must return bounded raw bytes", call. = FALSE)
      }
      name <- sprintf("page-%04d.json", length(pages))
      writeBin(raw_page, file.path(out, name))
      parsed <- jsonlite::fromJSON(rawToChar(raw_page), simplifyVector = FALSE)
      if (!is.list(parsed) || !is.list(parsed$response)) {
        stop("Malformed catalogue response or unexpected paging", call. = FALSE)
      }
      page <- parsed$response
      found <- page$numFound
      items <- page$docs
      if (!is.list(page) || !.ms_catalogue_whole_number(found, 0L, 2^53 - 1) ||
          !.ms_catalogue_whole_number(page$start, 0L, 2^53 - 1) || page$start != start ||
          !is.list(items) || !is.null(names(items)) || length(items) > rows) {
        stop("Malformed catalogue response or unexpected paging", call. = FALSE)
      }
      if (!is.null(total) && found != total) {
        stop("Catalogue changed during capture; rerun as a new capture", call. = FALSE)
      }
      total <- found
      if (start + length(items) > total) {
        stop("Page exceeds reported catalogue count", call. = FALSE)
      }
      for (item in items) {
        pid <- if (is.list(item)) item$id else NULL
        if (!is.character(pid) || length(pid) != 1L || is.na(pid) ||
            !nzchar(pid) || pid %in% seen) {
          stop("Missing or repeated metadata PID; unstable capture", call. = FALSE)
        }
        seen <- c(seen, pid)
      }
      pages[[length(pages) + 1L]] <- list(
        file = name, url = url,
        sha256 = digest::digest(raw_page, algo = "sha256", serialize = FALSE),
        bytes = length(raw_page), start = start, rows = length(items)
      )
      docs <- c(docs, items)
      if (length(docs) >= total) break
      if (length(items) == 0L) {
        stop("Empty page before reported result end", call. = FALSE)
      }
    }
    receipt <- list(
      receipt_version = "0.1", catalogue = catalogue, endpoint = endpoint,
      query = query, captured_at = stamp,
      reported_metadata_matches = total, captured_metadata_records = length(docs),
      complete_for_reported_count = length(docs) == total,
      transactional_snapshot = FALSE, annotation_status = "pending",
      independent_dataset_count = NULL, pages = pages, records = docs
    )
    .ms_catalogue_write_receipt(receipt, file.path(out, "capture.json"))
    receipt
  }, error = function(error) {
    failure <- list(
      status = "incomplete", query = query, catalogue = catalogue,
      pages = pages, semantic_approval = "pending"
    )
    # Never substitute success or an empty result for a failed capture. Failure
    # evidence is best-effort if the filesystem itself has become unwritable.
    tryCatch(
      .ms_catalogue_write_receipt(failure, file.path(out, "failure.json")),
      error = function(e) warning("Could not write failure receipt; inspect the reserved output directory", call. = FALSE)
    )
    # Atomic reservation avoids replacing an empty directory created after a
    # preflight check. If another capture owns the sibling, retain our original.
    if (.ms_catalogue_reserve_directory(incomplete)) {
      artifacts <- sort(list.files(out, all.files = TRUE, no.. = TRUE), method = "radix")
      moved <- vapply(artifacts, function(artifact) {
        .ms_catalogue_move_artifact(file.path(out, artifact), file.path(incomplete, artifact))
      }, logical(1))
      if (all(moved)) {
        # C remove() removes only an empty directory on POSIX. A late-created
        # residual must be preserved, not deleted by a recursive cleanup. On a
        # platform unable to remove directories this way, retain the output.
        if (!suppressWarnings(file.remove(out))) {
          warning("Incomplete output directory retained; inspect residual files before cleanup", call. = FALSE)
        }
      } else {
        warning("Incomplete capture remains across the reserved output directories", call. = FALSE)
      }
    }
    stop(error)
  })
}
