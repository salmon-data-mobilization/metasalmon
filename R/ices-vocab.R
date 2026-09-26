#' ICES controlled vocabularies (code lists)
#'
#' ICES publishes controlled vocabularies (also called **code lists**: tables of
#' allowed values like "Gear" codes) via a public REST API.
#'
#' These are not OWL ontologies; use them for categorical fields and reporting
#' codes, not for ontology IRIs.
#'
#' @seealso ICES vocab API docs: <https://vocab.ices.dk/services/api/swagger/index.html>
#'
#' @name ices_vocab
NULL

.ices_base_url <- "https://vocab.ices.dk/services/api"

.ices_empty <- function() {
  tibble::tibble()
}

# One request to the ICES vocab API: the parsed JSON, or NULL when the request
# failed. A failed request also warns, naming the request.
#
# A request that failed and an answer with no rows both reach the helpers
# below as nothing to return, and until hub item B-377 both gave the same empty
# tibble in silence, so an outage read as ICES saying it holds no such codes.
# `.safe_json()` tells the two apart only by signalling a
# `metasalmon_search_failure` condition, which has no default handler, so
# nothing here ever saw it. `find_terms()` installs a handler for the same
# reason and warns that a source did not answer; this does the same for ICES.
#
# A warning and not an error, because the return value stays what it was: the
# empty tibble, which every caller already receives for an outage, and which
# B-57 (backlog #57) settled these helpers return rather than abort.
.ices_request <- function(url) {
  failure <- NULL
  data <- withCallingHandlers(
    .safe_json(url, headers = c(Accept = "application/json")),
    metasalmon_search_failure = function(cnd) {
      failure <<- cnd
    }
  )
  if (is.null(failure)) {
    return(data)
  }
  # Redacted where the text is captured. `.safe_json()` has redacted both
  # already, and redacting twice changes nothing, so this does not depend on it.
  request <- .ms_redact_secrets(url)
  detail <- .ms_redact_secrets(failure$detail %||% conditionMessage(failure))
  cli::cli_warn(c(
    "The ICES vocabulary request failed, so the result is empty.",
    "x" = paste0("Request: ", .ms_cli_escape(request)),
    "x" = paste0("Failure: ", .ms_cli_escape(detail)),
    "i" = "This empty result says nothing about what ICES holds. An answer with no rows gives no warning."
  ))
  NULL
}

# The lower-cased text of `field` in each row of an ICES response, with a
# missing column and a missing value both read as "".
#
# `.data$longDescription %||% ""` was written as this guard and was not one:
# inside a data mask a missing column is an error, never NULL, so a response
# without one of the searched columns aborted the search, and so did a response
# with no rows, which reaches here as a tibble with no columns (backlog #57).
# metasalmonpy's `ices_vocab.py` fills a missing column with "" in the same way.
.ices_text <- function(df, field) {
  if (!field %in% names(df)) {
    return(rep("", nrow(df)))
  }
  text <- as.character(df[[field]])
  text[is.na(text)] <- ""
  tolower(text)
}

# The rows whose `key`, `description` or `longDescription` contains `query`,
# ignoring case, and at most `max_results` of them.
.ices_filter_text <- function(df, query, max_results) {
  q <- tolower(query)
  hit <- grepl(q, .ices_text(df, "key"), fixed = TRUE) |
    grepl(q, .ices_text(df, "description"), fixed = TRUE) |
    grepl(q, .ices_text(df, "longDescription"), fixed = TRUE)
  utils::head(df[hit, , drop = FALSE], max_results)
}

#' List ICES code types
#'
#' @param code_type Optional code type key or GUID to filter the API response.
#' @param code_type_id Optional numeric code type id to filter the API response.
#' @param modified Optional date string (`"YYYY-MM-DD"`) to return code types
#'   modified after that date.
#'
#' @return Tibble of ICES code types (includes `key`, `description`, `guid`, etc.).
#'   Empty when ICES answers with no rows, and also when the request fails,
#'   which warns, naming the request.
#' @export
ices_code_types <- function(code_type = "",
                            code_type_id = 0L,
                            modified = "") {
  url <- paste0(.ices_base_url, "/CodeType")
  query <- list()
  if (!is.null(code_type) && nzchar(code_type)) query$codeType <- code_type
  if (!is.null(code_type_id) && !is.na(code_type_id) && code_type_id != 0) query$codeTypeID <- code_type_id
  if (!is.null(modified) && nzchar(modified)) query$modified <- modified
  if (length(query) > 0) url <- httr::modify_url(url, query = query)

  data <- .ices_request(url)
  if (is.null(data) || !is.data.frame(data) || nrow(data) == 0) return(.ices_empty())
  tibble::as_tibble(data)
}

#' List ICES codes for a code type
#'
#' @param code_type ICES code type key or GUID (e.g., `"Gear"`).
#' @param code Optional code key or GUID to filter the API response.
#' @param modified Optional date string (`"YYYY-MM-DD"`) to return codes modified
#'   after that date.
#'
#' @return Tibble of ICES codes for the requested code type. Adds a `code_type`
#'   column and a `url` column pointing at the corresponding `CodeDetail` API endpoint.
#'   Empty when ICES answers with no rows, and also when the request fails,
#'   which warns, naming the request.
#' @export
ices_codes <- function(code_type,
                       code = "",
                       modified = "") {
  if (is.null(code_type) || !nzchar(code_type)) {
    cli::cli_abort("{.arg code_type} must be a non-empty ICES code type key (e.g., {.code Gear}).")
  }
  url <- paste0(.ices_base_url, "/Code/", utils::URLencode(code_type, reserved = TRUE))
  query <- list()
  if (!is.null(code) && nzchar(code)) query$code <- code
  if (!is.null(modified) && nzchar(modified)) query$modified <- modified
  if (length(query) > 0) url <- httr::modify_url(url, query = query)

  data <- .ices_request(url)
  if (is.null(data) || !is.data.frame(data) || nrow(data) == 0) return(.ices_empty())

  # A response with no `key` column still returns its rows. Only the detail
  # URL, which is built from the key, is NA (backlog #57).
  has_key <- "key" %in% names(data)
  tibble::as_tibble(data) %>%
    dplyr::mutate(
      code_type = code_type,
      url = if (has_key) {
        paste0(.ices_base_url, "/CodeDetail/", utils::URLencode(code_type, reserved = TRUE), "/", .data$key)
      } else {
        NA_character_
      }
    )
}

#' Find ICES code types by text match
#'
#' @param query Search string matched against `key`, `description`, and `longDescription`.
#' @param max_results Maximum number of rows to return (default 20).
#'
#' @return Filtered tibble of code types. Empty when nothing matches, and also
#'   when the request to ICES fails, which warns, naming the request.
#' @export
ices_find_code_types <- function(query, max_results = 20) {
  if (is.null(query) || is.na(query) || !nzchar(query)) return(.ices_empty())
  .ices_filter_text(ices_code_types(), query, max_results)
}

#' Find ICES codes within a code type by text match
#'
#' @param query Search string matched against `key`, `description`, and `longDescription`.
#' @param code_type ICES code type key (e.g., `"Gear"`).
#' @param max_results Maximum number of rows to return (default 50).
#'
#' @return Filtered tibble of codes for the given code type. Empty when nothing
#'   matches, and also when the request to ICES fails, which warns, naming the
#'   request.
#' @export
ices_find_codes <- function(query, code_type, max_results = 50) {
  if (is.null(query) || is.na(query) || !nzchar(query)) return(.ices_empty())
  .ices_filter_text(ices_codes(code_type), query, max_results)
}

