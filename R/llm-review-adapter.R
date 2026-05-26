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

    cli::cli_abort(null_message)
  }

  result
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
    llm_error = .ms_llm_non_empty_string(error)
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
    llm_error = NA_character_
  )
}
