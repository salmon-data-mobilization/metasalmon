.ms_llm_assessment_cols <- function() {
  c(
    "dataset_id",
    "table_id",
    "column_name",
    "code_value",
    "dictionary_role",
    "target_scope",
    "target_sdp_file",
    "target_sdp_field",
    "search_query",
    "llm_provider",
    "llm_model",
    "llm_decision",
    "llm_confidence",
    "llm_selected_candidate_index",
    "llm_selected_iri",
    "llm_selected_label",
    "llm_rationale",
    "llm_missing_context",
    "llm_bundle_summary",
    "llm_retry_query",
    "llm_new_term_label",
    "llm_new_term_definition",
    "llm_new_term_namespace",
    "llm_context_sources",
    "llm_exploration_used",
    "llm_exploration_queries",
    "llm_exploration_candidate_gain",
    "llm_error",
    "llm_escalated_from",
    "llm_retry_query_rejection_reason"
  )
}

.ms_llm_assessment_prototypes <- function() {
  cols <- .ms_llm_assessment_cols()
  out <- stats::setNames(rep(list(character()), length(cols)), cols)
  out$llm_confidence <- numeric()
  out$llm_selected_candidate_index <- integer()
  out$llm_exploration_used <- logical()
  out$llm_exploration_candidate_gain <- integer()
  out
}

.ms_llm_normalize_assessment_rows <- function(rows) {
  rows <- tibble::as_tibble(rows)
  prototypes <- .ms_llm_assessment_prototypes()

  for (nm in setdiff(names(prototypes), names(rows))) {
    prototype <- prototypes[[nm]]
    rows[[nm]] <- if (is.logical(prototype)) {
      rep(NA, nrow(rows))
    } else if (is.integer(prototype)) {
      rep(NA_integer_, nrow(rows))
    } else if (is.numeric(prototype)) {
      rep(NA_real_, nrow(rows))
    } else {
      rep(NA_character_, nrow(rows))
    }
  }

  for (nm in names(prototypes)) {
    rows[[nm]] <- .ms_llm_cast_assessment_column(
      rows[[nm]],
      prototypes[[nm]],
      nm
    )
  }

  rows[, .ms_llm_assessment_cols(), drop = FALSE]
}

.ms_llm_cast_assessment_column <- function(x, prototype, column) {
  cast_error <- function() {
    cli::cli_abort(
      "Assessment column {.field {column}} contains values that cannot be normalized to the required type."
    )
  }
  missing_input <- is.na(x)

  if (is.logical(prototype)) {
    if (is.logical(x)) {
      return(x)
    }
    text <- tolower(trimws(as.character(x)))
    out <- rep(NA, length(text))
    out[text %in% c("true", "t", "1")] <- TRUE
    out[text %in% c("false", "f", "0")] <- FALSE
    if (any(!missing_input & !text %in% c("true", "t", "1", "false", "f", "0"))) {
      cast_error()
    }
    return(out)
  }

  if (is.integer(prototype)) {
    numeric_value <- tryCatch(
      suppressWarnings(as.numeric(x)),
      error = function(e) NULL
    )
    if (is.null(numeric_value) ||
        any(!missing_input & is.na(numeric_value)) ||
        any(!is.na(numeric_value) & numeric_value != trunc(numeric_value))) {
      cast_error()
    }
    return(as.integer(numeric_value))
  }

  if (is.numeric(prototype)) {
    out <- tryCatch(
      suppressWarnings(as.numeric(x)),
      error = function(e) NULL
    )
    if (is.null(out) || any(!missing_input & is.na(out))) {
      cast_error()
    }
    return(out)
  }

  tryCatch(
    as.character(x),
    error = function(e) cast_error()
  )
}

.ms_empty_llm_assessments <- function() {
  .ms_llm_normalize_assessment_rows(tibble::tibble())
}

.ms_llm_review_response_data <- function(result,
                                         null_message = "LLM adapter did not return a usable JSON object for review.") {
  if (is.list(result) && ("data" %in% names(result) || "content" %in% names(result))) {
    if (!is.null(result$data)) {
      return(result$data)
    }

    parsed <- tryCatch(
      jsonlite::fromJSON(.ms_llm_clean_json_text(result$content), simplifyVector = FALSE),
      error = function(e) NULL
    )
    if (!is.null(parsed)) {
      return(parsed)
    }

    snippet <- .ms_llm_review_content_snippet(result$content)
    message <- null_message
    if (nzchar(snippet)) {
      message <- c(message, i = "Response content snippet: {.val {snippet}}")
    }
    cli::cli_abort(message)
  }

  result
}

.ms_llm_review_content_snippet <- function(content, max_chars = 160L) {
  text <- as.character(content %||% "")
  text[is.na(text)] <- ""
  text <- paste(text, collapse = " ")
  text <- gsub("[\r\n\t]+", " ", text)
  text <- trimws(gsub("\\s+", " ", text))
  if (!nzchar(text)) {
    return("")
  }
  if (nchar(text) > max_chars) {
    text <- paste0(substr(text, 1L, max_chars), "...")
  }

  text
}

.ms_llm_review_validate_assessment <- function(result,
                                               candidate_rows,
                                               null_message = "LLM adapter did not return a usable JSON object for review.") {
  result <- .ms_llm_review_response_data(result, null_message = null_message)
  .ms_validate_llm_assessment(result, .ms_semantic_candidate_rows(candidate_rows))
}

.ms_llm_review_request_assessment <- function(messages, candidate_rows, config) {
  .ms_llm_review_validate_assessment(
    .ms_llm_request_with_retries(messages = messages, config = config),
    candidate_rows
  )
}

.ms_llm_review_empty_assessment <- function(target_row, config, error = NA_character_) {
  target <- tibble::as_tibble(target_row)[1, , drop = FALSE]
  target <- .ms_semantic_add_missing_cols(
    target,
    c(.ms_semantic_target_group_cols(), "search_query")
  )

  tibble::tibble(
    dataset_id = target$dataset_id[[1]] %||% NA_character_,
    table_id = target$table_id[[1]] %||% NA_character_,
    column_name = target$column_name[[1]] %||% NA_character_,
    code_value = target$code_value[[1]] %||% NA_character_,
    dictionary_role = target$dictionary_role[[1]] %||% NA_character_,
    target_scope = target$target_scope[[1]] %||% NA_character_,
    target_sdp_file = target$target_sdp_file[[1]] %||% NA_character_,
    target_sdp_field = target$target_sdp_field[[1]] %||% NA_character_,
    search_query = target$search_query[[1]] %||% NA_character_,
    llm_provider = config$provider,
    llm_model = config$model,
    llm_decision = NA_character_,
    llm_confidence = NA_real_,
    llm_selected_candidate_index = NA_integer_,
    llm_selected_iri = NA_character_,
    llm_selected_label = NA_character_,
    llm_rationale = NA_character_,
    llm_missing_context = NA_character_,
    llm_bundle_summary = NA_character_,
    llm_retry_query = NA_character_,
    llm_new_term_label = NA_character_,
    llm_new_term_definition = NA_character_,
    llm_new_term_namespace = NA_character_,
    llm_context_sources = NA_character_,
    llm_exploration_used = FALSE,
    llm_exploration_queries = NA_character_,
    llm_exploration_candidate_gain = 0L,
    llm_error = .ms_llm_non_empty_string(error),
    llm_escalated_from = NA_character_,
    llm_retry_query_rejection_reason = NA_character_
  )
}

.ms_llm_review_success_assessment <- function(target_row,
                                              candidate_rows,
                                              context_chunks,
                                              config,
                                              validated) {
  target <- tibble::as_tibble(target_row)[1, , drop = FALSE]
  target <- .ms_semantic_add_missing_cols(
    target,
    c(.ms_semantic_target_group_cols(), "search_query")
  )
  candidate_rows <- .ms_semantic_candidate_rows(candidate_rows)
  context_chunks <- tibble::as_tibble(context_chunks)

  tibble::tibble(
    dataset_id = target$dataset_id[[1]] %||% NA_character_,
    table_id = target$table_id[[1]] %||% NA_character_,
    column_name = target$column_name[[1]] %||% NA_character_,
    code_value = target$code_value[[1]] %||% NA_character_,
    dictionary_role = target$dictionary_role[[1]] %||% NA_character_,
    target_scope = target$target_scope[[1]] %||% NA_character_,
    target_sdp_file = target$target_sdp_file[[1]] %||% NA_character_,
    target_sdp_field = target$target_sdp_field[[1]] %||% NA_character_,
    search_query = target$search_query[[1]] %||% NA_character_,
    llm_provider = config$provider,
    llm_model = config$model,
    llm_decision = validated$decision,
    llm_confidence = validated$confidence,
    llm_selected_candidate_index = validated$selected_candidate_index,
    llm_selected_iri = if (!is.na(validated$selected_candidate_index)) candidate_rows$iri[[validated$selected_candidate_index]] else NA_character_,
    llm_selected_label = if (!is.na(validated$selected_candidate_index)) candidate_rows$label[[validated$selected_candidate_index]] else NA_character_,
    llm_rationale = validated$rationale,
    llm_missing_context = validated$missing_context,
    llm_bundle_summary = validated$bundle_summary,
    llm_retry_query = validated$retry_query,
    llm_new_term_label = validated$suggested_label,
    llm_new_term_definition = validated$suggested_definition,
    llm_new_term_namespace = validated$suggested_namespace,
    llm_context_sources = if (nrow(context_chunks) > 0) paste(unique(context_chunks$source), collapse = "; ") else NA_character_,
    llm_exploration_used = FALSE,
    llm_exploration_queries = NA_character_,
    llm_exploration_candidate_gain = 0L,
    llm_error = NA_character_,
    llm_escalated_from = NA_character_,
    llm_retry_query_rejection_reason = NA_character_
  )
}
