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

.ms_semantic_iris_from_rows <- function(rows, fields, separator = ";",
                                       scalar_fields = character()) {
  if (is.null(rows) || nrow(rows) == 0L) {
    return(character())
  }
  fields <- intersect(fields, names(rows))
  unlist(lapply(fields, function(field) {
    .ms_semantic_iri_values(
      rows[[field]], separator = if (field %in% scalar_fields) NULL else separator
    )
  }), use.names = FALSE)
}

.ms_semantic_iri_csv <- function(path, fields = NULL, accepted_only = FALSE,
                                 scalar_fields = character()) {
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
  .ms_semantic_iris_from_rows(rows, fields, separator = separator,
                             scalar_fields = scalar_fields)
}

.ms_selected_sdp_semantic_iris <- function(path) {
  # Canonical CSVs own these slots when present. The descriptor-only fallback
  # is for older SDPs; avoid reading their data resources for the usual path.
  # The canonical metadata schemas declare these owner-specific slots as
  # scalar IRIs. A legal semicolon is part of each identifier. constraint_iri
  # explicitly declares a list; unknown extension fields retain their existing
  # handling rather than acquiring a new convention from their suffix.
  scalar_fields <- list(
    dataset = "protocol_iri",
    tables = c("observation_unit_iri", "protocol_iri", "method_iri"),
    dictionary = c("unit_iri", "term_iri", "property_iri", "entity_iri",
                   "statistical_modifier_iri"),
    codes = c("term_iri", "vocabulary_iri")
  )
  canonical <- c(dataset = "dataset.csv", tables = "tables.csv",
                 dictionary = "column_dictionary.csv", codes = "codes.csv")
  primary_paths <- vapply(canonical, function(file_name) {
    .ms_locate_metadata_file(path, file_name)
  }, character(1))
  has_canonical <- all(!is.na(primary_paths[c(
    "dataset", "tables", "dictionary"
  )]))
  if (has_canonical) {
    iris <- unlist(lapply(names(primary_paths)[!is.na(primary_paths)], function(owner) {
      .ms_semantic_iri_csv(primary_paths[[owner]], scalar_fields = scalar_fields[[owner]])
    }), use.names = FALSE)
  } else if (file.exists(file.path(path, "datapackage.json"))) {
    package <- suppressMessages(read_salmon_datapackage(path))
    iris <- unlist(lapply(
      names(scalar_fields), function(owner) {
        rows <- package[[owner]]
        if (is.null(rows)) return(character())
        .ms_semantic_iris_from_rows(
          rows, names(rows)[grepl("_iri$", names(rows))], scalar_fields = scalar_fields[[owner]]
        )
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
  # Current decomposition/observation validators require single absolute IRIs.
  # The two methods slots retain that scalar contract from the sdp-0.2.0 schema
  # still read for migration. Only these declared fields bypass list splitting;
  # unknown extension slots keep their previous representation.
  extension_fields <- list(
    "metadata/methods.csv" = c("method_iri", "protocol_iri"),
    "metadata/semantic/measurement-decompositions.csv" = c(
      "measurement_concept_iri", "component_iri"
    ),
    "metadata/structure/observation_components.csv" = "component_relation_iri"
  )
  iris <- c(iris, unlist(lapply(names(extension_fields), function(relative) {
    .ms_semantic_iri_csv(file.path(path, relative),
                       scalar_fields = extension_fields[[relative]])
  }), use.names = FALSE))
  iris <- c(iris, .ms_semantic_iri_csv(
    file.path(path, "metadata/semantic_vocabulary.csv"), fields = "iri"
  ))
  # The reviewed EML sidecar chooses one authority when it explicitly names a
  # supported ledger. A compatibility copy must not add stale accepted terms.
  # Unqualified, absent and ordinary malformed sidecars retain the earlier
  # union; shared native YAML parsing still refuses Q62 tags without evaluation.
  # EML's checksum/target-completeness validation remains with that consumer.
  ledger_names <- c("reviewed_semantic_selections.csv",
                    "reproducibility/reviewed_semantic_selections.csv")
  ledger_paths <- file.path(path, ledger_names)
  mapping_file <- .ms_closure_mapping_file(path)
  if (!is.null(mapping_file)) {
    mapping <- tryCatch(.ms_eml_read_mapping_yaml(mapping_file), error = function(e) {
      if (inherits(e, "metasalmon_eml_mapping_tag")) stop(e)
      NULL
    })
    declared <- if (is.list(mapping) && is.list(mapping$semantic_review)) {
      mapping$semantic_review$path
    } else NULL
    if (is.character(declared) && length(declared) == 1L &&
        !is.na(declared) && declared %in% ledger_names) {
      # Resolve the selected file once with the existing existence/containment
      # guard. A missing or escaping authority cannot silently use its shadow.
      ledger_paths <- .ms_eml_resource_path(path, declared)
    }
  }
  iris <- c(iris, unlist(lapply(ledger_paths, function(ledger_path) {
    .ms_semantic_iri_csv(ledger_path, accepted_only = TRUE)
  }), use.names = FALSE))

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

.ms_semantic_iri_final_headers <- function(response) {
  if (length(response$status_code) != 1L || is.na(response$status_code) ||
      response$status_code < 200L || length(response$headers) == 0L) {
    return(FALSE)
  }
  headers <- rawToChar(response$headers)
  if (!endsWith(headers, "\r\n\r\n")) return(FALSE)
  blocks <- strsplit(headers, "\r\n\r\n", fixed = TRUE)[[1]]
  block <- utils::tail(blocks[nzchar(blocks)], 1L)
  status_line <- strsplit(block, "\r\n", fixed = TRUE)[[1]][[1]]
  if (!grepl("^HTTP/[0-9.]+ [0-9]{3}($| )", status_line)) return(FALSE)
  status <- as.integer(sub("^HTTP/[0-9.]+ ([0-9]{3}).*$", "\\1", status_line))
  # A prior complete redirect block can remain visible while the next status
  # has arrived but its headers have not. Never treat that stale block as final.
  if (status != response$status_code) return(FALSE)
  location <- curl::parse_headers_list(block)$location
  !(status %in% c(301L, 302L, 303L, 307L, 308L) &&
      length(location) > 0L && any(nzchar(location)))
}

.ms_semantic_iri_request_timeout <- 30
.ms_semantic_iri_request <- function(iri) {
  handle <- curl::new_handle(
    url = iri, httpget = TRUE, followlocation = TRUE, maxredirs = 30L,
    suppress_connect_headers = TRUE,
    timeout_ms = as.integer(1000 * .ms_semantic_iri_request_timeout)
  )
  # Proxy CONNECT headers are not the requested HTTP resource's response.
  curl::handle_setheaders(handle, Accept = "*/*")
  pool <- curl::new_pool()
  failure <- NULL
  completed <- FALSE
  curl::multi_add(
    handle, done = function(response) completed <<- TRUE,
    fail = function(message) failure <<- message,
    data = function(chunk, final = FALSE) invisible(NULL), pool = pool
  )
  on.exit(curl::multi_cancel(handle), add = TRUE)
  deadline <- proc.time()[["elapsed"]] + .ms_semantic_iri_request_timeout
  repeat {
    remaining <- deadline - proc.time()[["elapsed"]]
    if (remaining <= 0) {
      stop(errorCondition("Semantic IRI request timed out.", class = "curl_error"))
    }
    # A zero-time poll exposes headers promptly. Even short blocking multi_run
    # calls waited for a body/timeout on some local responses in curl 7.1.0.
    # Retires when a shared header transport keeps this bound and failure proof.
    curl::multi_run(timeout = 0, pool = pool)
    response <- curl::handle_data(handle)
    if (.ms_semantic_iri_final_headers(response)) {
      return(list(status = as.integer(response$status_code), final_url = response$url))
    }
    if (!is.null(failure)) {
      # curl >= 6.2.1 supplies classed callback text. Preserve its public error
      # subclasses instead of erasing the two explicit permanent defaults.
      # Retires when a shared transport preserves these classes and attempts.
      classes <- setdiff(class(failure), "character")
      if (inherits(failure, c("curl_error_url_malformat", "curl_error_too_many_redirects"))) {
        classes <- c("metasalmon_semantic_iri_permanent_error", classes)
      }
      stop(errorCondition(as.character(failure), class = unique(c(classes, "curl_error"))))
    }
    if (completed) {
      stop(errorCondition("Request completed without final HTTP headers.", class = "curl_error"))
    }
    Sys.sleep(min(0.01, remaining))
  }
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
    # Some conditions carry a vector message; keep its complete evidence in one
    # row before scalar retry classification and capture-time redaction.
    message <- paste(conditionMessage(failure), collapse = "\n")
    return(list(
      status = NA_integer_, final_url = NA_character_,
      error = .ms_redact_secrets(message),
      transient = !inherits(failure, "metasalmon_semantic_iri_permanent_error") && (
        inherits(failure, c("httr2_failure", "curl_error")) ||
          grepl(.ms_semantic_iri_transport_pattern, message, ignore.case = TRUE)
      )
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
    # A redirect can put credentials in the effective URL even when no
    # credential header was sent. Remove only HTTP(S) authority userinfo at
    # capture, before this value enters a returned row or persistent CSV.
    # Stopping at /, ? or # preserves host/port and every path/query/fragment
    # byte, including at-signs; a greedy authority match takes its final @.
    final_url = .ms_redact_secrets(sub(
      "(?i)^(https?://)[^/?#]*@", "\\1", final_url, perl = TRUE
    )),
    error = .ms_redact_secrets(error),
    transient = transient
  )
}

#' Verify selected HTTP semantic IRIs in a Salmon Data Package
#'
#' Collects exact HTTP(S) identifiers from selected SDP semantic metadata,
#' including manifest-bound reviewed SSSOM mappings. Candidate suggestions,
#' arbitrary data URLs, and non-HTTP identifiers are excluded. GET requests
#' follow redirects and stop after complete final response headers, with a
#' 30-second timeout across connection and redirects. The final body is not
#' retained or required for HTTP resolution. Only HTTP 408,
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
