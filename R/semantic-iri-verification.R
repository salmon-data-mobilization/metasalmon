# Verify the exact selected HTTP semantic identifiers of an SDP. The report is
# a publication artifact: keep selection, ordering, and bytes deterministic.

.ms_semantic_iri_values <- function(values, separator = ";") {
  values <- as.character(values)
  values <- values[!is.na(values) & nzchar(trimws(values))]
  if (length(values) == 0L) {
    return(character())
  }
  parts <- if (is.null(separator)) values else {
    unlist(strsplit(values, separator, fixed = TRUE), use.names = FALSE)
  }
  parts <- trimws(parts)
  parts[nzchar(parts) & grepl("^https?://", parts, ignore.case = TRUE)]
}

.ms_semantic_iris_from_rows <- function(rows, fields, separator = ";") {
  if (is.null(rows) || nrow(rows) == 0L) {
    return(character())
  }
  fields <- intersect(fields, names(rows))
  unlist(lapply(fields, function(field) {
    .ms_semantic_iri_values(rows[[field]], separator = separator)
  }), use.names = FALSE)
}

.ms_semantic_iri_csv <- function(path, fields = NULL, accepted_only = FALSE) {
  if (!file.exists(path)) {
    return(character())
  }
  rows <- .ms_read_metadata_csv(path)
  if (accepted_only) {
    if (!all(c("decision", "iri") %in% names(rows))) {
      cli::cli_abort("Reviewed semantic selections need {.field decision} and {.field iri} in {.file {path}}.")
    }
    rows <- rows[!is.na(rows$decision) & rows$decision == "accepted", , drop = FALSE]
    fields <- "iri"
    separator <- NULL
  } else {
    separator <- if (identical(fields, "iri")) NULL else ";"
  }
  if (is.null(fields)) {
    fields <- names(rows)[grepl("_iri$", names(rows))]
  }
  .ms_semantic_iris_from_rows(rows, fields, separator = separator)
}

.ms_selected_sdp_semantic_iris <- function(path) {
  # Canonical CSVs own these slots when present. The descriptor-only fallback
  # is for older SDPs; avoid reading their data resources for the usual path.
  canonical <- c("dataset.csv", "tables.csv", "column_dictionary.csv", "codes.csv")
  primary_paths <- vapply(canonical, function(file_name) {
    .ms_locate_metadata_file(path, file_name)
  }, character(1))
  has_canonical <- all(!is.na(primary_paths[c(
    "dataset.csv", "tables.csv", "column_dictionary.csv"
  )]))
  if (has_canonical) {
    iris <- unlist(lapply(primary_paths[!is.na(primary_paths)], .ms_semantic_iri_csv),
                   use.names = FALSE)
  } else if (file.exists(file.path(path, "datapackage.json"))) {
    package <- suppressMessages(read_salmon_datapackage(path))
    iris <- unlist(lapply(
      package[c("dataset", "tables", "dictionary", "codes")],
      function(rows) {
        if (is.null(rows)) return(character())
        .ms_semantic_iris_from_rows(rows, names(rows)[grepl("_iri$", names(rows))])
      }
    ), use.names = FALSE)
  } else {
    cli::cli_abort(
      "An SDP needs complete canonical metadata CSVs or {.file datapackage.json} for semantic IRI verification."
    )
  }

  # These extensions are authored package metadata, rather than candidate
  # search results or arbitrary HTTP URLs in data and provenance records.
  # Retires when the SDP profile exposes one authoritative inventory of
  # selected semantic fields; this local file list can then read that instead.
  extension_paths <- c(
    "metadata/methods.csv",
    "metadata/semantic/measurement-decompositions.csv",
    "metadata/structure/observation_components.csv"
  )
  iris <- c(iris, unlist(lapply(extension_paths, function(relative) {
    .ms_semantic_iri_csv(file.path(path, relative))
  }), use.names = FALSE))
  iris <- c(iris, .ms_semantic_iri_csv(
    file.path(path, "metadata/semantic_vocabulary.csv"), fields = "iri"
  ))
  for (relative in c(
    "reviewed_semantic_selections.csv",
    "reproducibility/reviewed_semantic_selections.csv"
  )) {
    iris <- c(iris, .ms_semantic_iri_csv(
      file.path(path, relative), accepted_only = TRUE
    ))
  }

  # A reviewed SSSOM set is package semantics too. Read only manifest-bound
  # files, verify their hashes, and retain literal HTTP values; CURIE expansion
  # would produce a different identifier from the one the package carries.
  # The field list retires when the SSSOM profile exposes semantic-reference
  # roles directly; author, license and issue URLs are not term selections.
  manifest_path <- file.path(path, "metadata/semantic/mapping-sets.json")
  if (file.exists(manifest_path)) {
    validate_sdp_sssom(path)
    manifest <- jsonlite::read_json(manifest_path, simplifyVector = FALSE)
    sssom_fields <- c(
      "subject_id", "subject_category", "predicate_id", "object_id",
      "object_category", "mapping_justification", "subject_type",
      "predicate_type", "object_type"
    )
    for (entry in manifest$mapping_sets) {
      mappings <- read_sssom_mapping_set(file.path(path, entry$path))$mappings
      iris <- c(iris, .ms_semantic_iris_from_rows(
        mappings, sssom_fields, separator = "|"
      ))
    }
  }
  sort(unique(iris), method = "radix")
}

.ms_semantic_iri_request <- function(iri) {
  response <- httr2::request(iri) |>
    httr2::req_method("GET") |>
    httr2::req_headers(Accept = "*/*") |>
    httr2::req_timeout(seconds = 30) |>
    httr2::req_error(is_error = function(response) FALSE) |>
    httr2::req_perform()
  list(
    status = as.integer(httr2::resp_status(response)),
    final_url = as.character(httr2::resp_url(response))
  )
}

.ms_semantic_iri_retry_delays <- c(0.1, 0.25)
# This local retry policy retires when dereference checks move to a shared
# verified transport that keeps the same bound and per-IRI failure evidence.
.ms_semantic_iri_transport_pattern <- paste0(
  "TLS|SSL|connect|connection reset|timed?[ -]?out|timeout|",
  "could not resolve|network is unreachable|empty reply|recv failure"
)

.ms_semantic_iri_transient_status <- function(status) {
  !is.na(status) && (status %in% c(408L, 429L) ||
                      (status >= 500L && status <= 599L))
}

.ms_semantic_iri_attempt <- function(iri, requester) {
  failure <- NULL
  response <- tryCatch(requester(iri), error = function(error) {
    failure <<- error
    NULL
  })
  if (!is.null(failure)) {
    message <- conditionMessage(failure)
    return(list(
      status = NA_integer_, final_url = NA_character_,
      error = .ms_redact_secrets(message),
      transient = inherits(failure, c("httr2_failure", "curl_error")) ||
        grepl(.ms_semantic_iri_transport_pattern, message, ignore.case = TRUE)
    ))
  }
  if (!is.list(response)) {
    response <- list(error = "Requester did not return a response list.")
  }
  error <- if (is.character(response$error) && length(response$error) == 1L) {
    response$error
  } else {
    NA_character_
  }
  raw_status <- response$status
  status_valid <- is.atomic(raw_status) && !is.factor(raw_status) &&
    length(raw_status) == 1L &&
    (is.na(raw_status) || grepl("^[1-5][0-9][0-9]$", as.character(raw_status)))
  status <- if (status_valid && !is.na(raw_status)) {
    as.integer(raw_status)
  } else {
    NA_integer_
  }
  raw_url <- response$final_url
  final_url <- if (is.character(raw_url) && length(raw_url) == 1L &&
                   !is.na(raw_url) && nzchar(raw_url)) raw_url else NA_character_
  malformed <- character()
  if (!is.null(raw_status) && !status_valid) {
    malformed <- c(malformed, "invalid status")
  }
  if (!is.na(status) && is.na(final_url)) {
    malformed <- c(malformed, "missing final URL")
  }
  if (!is.null(response$error) && is.na(error)) {
    malformed <- c(malformed, "invalid error field")
  }
  if (length(malformed) > 0L) {
    error <- paste0("Malformed requester response: ", paste(malformed, collapse = ", "), ".")
  } else if (is.na(status) && is.na(error)) {
    error <- "Requester returned neither an HTTP status nor an error."
  }
  transient <- if (is.na(status)) {
    length(malformed) == 0L && !is.na(error) && grepl(
      .ms_semantic_iri_transport_pattern, error, ignore.case = TRUE
    )
  } else {
    .ms_semantic_iri_transient_status(status)
  }
  list(
    status = status,
    final_url = .ms_redact_secrets(final_url),
    error = .ms_redact_secrets(error),
    transient = transient
  )
}

#' Verify selected HTTP semantic IRIs in a Salmon Data Package
#'
#' Collects exact HTTP(S) identifiers from selected SDP semantic metadata,
#' including manifest-bound reviewed SSSOM mappings. Candidate suggestions,
#' arbitrary data URLs, and non-HTTP identifiers are excluded. GET requests
#' follow normal httr2 redirects and have a 30-second timeout. Only HTTP 408,
#' 429, 5xx, and classified transient transport failures are retried, with at
#' most three attempts per IRI. All IRIs are checked before any failure aborts.
#'
#' The report is written even if verification fails. Its stable row order and
#' bytes allow a publication workflow to checksum the file. A successful
#' dereference proves HTTP resolution only, not that an ontology term is an
#' appropriate semantic choice.
#'
#' @param path Existing Salmon Data Package directory.
#' @param report_path CSV output path. Defaults to
#'   `reproducibility/provenance/semantic-iri-dereference.csv` inside `path`.
#' @param requester GET function receiving one exact IRI and returning a list
#'   with integer `status` and character `final_url`. Intended for offline tests.
#' @param sleep_fn Delay function, receiving seconds. Intended for offline tests.
#'
#' @return Invisibly, a tibble with `iri`, `status`, `final_url`, `error`, and
#'   `attempts`, one row for each unique exact HTTP semantic IRI. On failure,
#'   the complete CSV is written before an aggregate error is raised.
#' @examples
#' \dontrun{
#' # This makes live HTTP requests to every selected semantic IRI.
#' verify_sdp_semantic_iris("path/to/package")
#' }
#' @export
verify_sdp_semantic_iris <- function(
    path,
    report_path = file.path(
      path, "reproducibility", "provenance", "semantic-iri-dereference.csv"
    ),
    requester = .ms_semantic_iri_request,
    sleep_fn = Sys.sleep) {
  root <- .ms_sdp_extension_root(path)
  if (length(report_path) != 1L || is.na(report_path) || !nzchar(report_path)) {
    cli::cli_abort("{.arg report_path} must be one non-empty file path.")
  }
  if (!is.function(requester) || !is.function(sleep_fn)) {
    cli::cli_abort("{.arg requester} and {.arg sleep_fn} must both be functions.")
  }
  iris <- .ms_selected_sdp_semantic_iris(root)
  if (length(iris) == 0L) {
    cli::cli_abort("At least one HTTP semantic IRI is required for dereference checking.")
  }
  rows <- lapply(iris, function(iri) {
    for (attempt in seq_len(length(.ms_semantic_iri_retry_delays) + 1L)) {
      final <- .ms_semantic_iri_attempt(iri, requester)
      succeeded <- !is.na(final$status) && final$status >= 200L &&
        final$status < 300L && !is.na(final$final_url) &&
        nzchar(final$final_url)
      if (succeeded || !final$transient ||
          attempt > length(.ms_semantic_iri_retry_delays)) {
        break
      }
      sleep_fn(.ms_semantic_iri_retry_delays[[attempt]])
    }
    tibble::tibble(
      iri = iri, status = final$status, final_url = final$final_url,
      error = final$error, attempts = as.integer(attempt)
    )
  })
  results <- dplyr::bind_rows(rows)
  default_relative <- "reproducibility/provenance/semantic-iri-dereference.csv"
  default_path <- file.path(path, default_relative)
  if (identical(report_path, default_path)) {
    .ms_sdp_extension_assert_safe_directory(
      root, "reproducibility/provenance", create = TRUE
    )
    report_path <- .ms_sdp_extension_assert_safe_file(
      root, default_relative, must_exist = FALSE
    )
  } else {
    directory <- dirname(report_path)
    if (!dir.exists(directory)) {
      dir.create(directory, recursive = TRUE, showWarnings = FALSE)
    }
  }
  .ms_sdp_extension_atomic_write(
    .ms_sdp_extension_csv_bytes(results), report_path
  )
  failed <- is.na(results$status) | results$status < 200L |
    results$status >= 300L | is.na(results$final_url) |
    !nzchar(results$final_url)
  if (any(failed)) {
    details <- paste0(
      .ms_redact_secrets(results$iri[failed]), " (status=",
      ifelse(is.na(results$status[failed]), "request-error", results$status[failed]),
      ")"
    )
    rlang::abort(paste0(
      "Semantic IRI(s) did not dereference successfully: ",
      paste(details, collapse = ", "), "."
    ))
  }
  invisible(results)
}
