.ms_semantic_target_cols <- function() {
  c(
    "dataset_id",
    "table_id",
    "column_name",
    "code_value",
    "dictionary_role",
    "search_role",
    "target_scope",
    "target_sdp_file",
    "target_sdp_field",
    "target_row_key",
    "target_label",
    "target_description",
    "search_query",
    "target_query_basis",
    "target_query_context",
    "column_label",
    "column_description",
    "code_label",
    "code_description"
  )
}

.ms_semantic_suggestion_leading_cols <- function() {
  c(
    "column_name",
    "dictionary_role",
    "table_id",
    "dataset_id",
    "target_row_key",
    "target_label",
    "target_description",
    "target_scope",
    "target_sdp_file",
    "target_sdp_field",
    "search_query",
    "target_query_basis",
    "target_query_context",
    "column_label",
    "column_description",
    "code_value",
    "code_label",
    "code_description"
  )
}

.ms_semantic_target_group_cols <- function() {
  c(
    "dataset_id",
    "table_id",
    "column_name",
    "code_value",
    "dictionary_role",
    "target_scope",
    "target_sdp_file",
    "target_sdp_field"
  )
}

.ms_semantic_assessment_join_cols <- function() {
  c(.ms_semantic_target_group_cols(), "search_query")
}

.ms_semantic_bundle_group_cols <- function() {
  c("dataset_id", "table_id", "column_name")
}

.ms_semantic_key_df <- function(df, group_cols) {
  df <- tibble::as_tibble(df)
  missing_cols <- setdiff(group_cols, names(df))
  for (nm in missing_cols) {
    df[[nm]] <- NA_character_
  }

  do.call(
    paste,
    c(
      lapply(df[group_cols], function(x) ifelse(is.na(x), "<NA>", as.character(x))),
      sep = "\r"
    )
  )
}

.ms_semantic_group_key_df <- function(df) {
  .ms_semantic_key_df(df, .ms_semantic_target_group_cols())
}

.ms_semantic_bundle_key_df <- function(df) {
  .ms_semantic_key_df(df, .ms_semantic_bundle_group_cols())
}

.ms_semantic_add_missing_cols <- function(df, cols, value = NA_character_) {
  df <- tibble::as_tibble(df)
  missing_cols <- setdiff(cols, names(df))
  for (nm in missing_cols) {
    df[[nm]] <- value
  }
  df
}

.ms_semantic_normalize_target_rows <- function(targets, cols = .ms_semantic_suggestion_leading_cols()) {
  .ms_semantic_add_missing_cols(targets, cols)
}

.ms_semantic_candidate_rows <- function(candidate_rows = NULL) {
  if (is.null(candidate_rows)) {
    candidate_rows <- tibble::tibble()
  }

  candidate_rows <- tibble::as_tibble(candidate_rows)
  required <- c("label", "iri", "source", "ontology", "definition")
  candidate_rows <- .ms_semantic_add_missing_cols(candidate_rows, required)
  if (!"score" %in% names(candidate_rows)) {
    candidate_rows$score <- NA_real_
  }
  if (!"llm_selected" %in% names(candidate_rows)) {
    candidate_rows$llm_selected <- NA
  }

  candidate_rows
}

.ms_semantic_trim_string <- function(x, default = NA_character_) {
  if (is.null(x) || length(x) == 0) {
    return(default)
  }

  text <- trimws(as.character(x[[1]]))
  if (is.na(text) || !nzchar(text)) {
    return(default)
  }

  text
}

.ms_semantic_first_non_empty <- function(...) {
  values <- unlist(list(...), use.names = FALSE)
  values <- vapply(values, .ms_semantic_trim_string, character(1), default = NA_character_)
  values <- values[!is.na(values)]
  if (length(values) == 0L) {
    return(NA_character_)
  }
  values[[1]]
}

.ms_semantic_column_term_target_from_dictionary <- function(dict_row) {
  dict_row <- tibble::as_tibble(dict_row)

  dataset_id <- if ("dataset_id" %in% names(dict_row)) dict_row$dataset_id[[1]] else NA_character_
  table_id <- if ("table_id" %in% names(dict_row)) dict_row$table_id[[1]] else NA_character_
  column_name <- if ("column_name" %in% names(dict_row)) dict_row$column_name[[1]] else NA_character_
  column_label <- if ("column_label" %in% names(dict_row)) dict_row$column_label[[1]] else column_name
  column_description <- if ("column_description" %in% names(dict_row)) dict_row$column_description[[1]] else NA_character_
  search_query <- .ms_semantic_first_non_empty(column_description, column_label, column_name)

  tibble::tibble(
    dataset_id = dataset_id,
    table_id = table_id,
    column_name = column_name,
    code_value = NA_character_,
    dictionary_role = "variable",
    search_role = "variable",
    target_scope = "column",
    target_sdp_file = "column_dictionary.csv",
    target_sdp_field = "term_iri",
    target_row_key = paste(dataset_id, table_id, column_name, sep = "/"),
    target_label = column_label,
    target_description = column_description,
    search_query = search_query,
    target_query_basis = dplyr::case_when(
      !is.na(.ms_semantic_trim_string(column_description)) ~ "column_description",
      !is.na(.ms_semantic_trim_string(column_label)) ~ "column_label",
      TRUE ~ "column_name"
    ),
    target_query_context = .ms_semantic_first_non_empty(
      paste(column_label, column_description),
      column_name
    ),
    column_label = column_label,
    column_description = column_description,
    code_label = NA_character_,
    code_description = NA_character_
  )
}

.ms_semantic_target_from_candidate_rows <- function(candidate_rows = NULL, dict_row = NULL) {
  candidate_rows <- .ms_semantic_candidate_rows(candidate_rows)
  target_cols <- .ms_semantic_target_cols()

  if (nrow(candidate_rows) > 0L) {
    target <- candidate_rows[1, intersect(target_cols, names(candidate_rows)), drop = FALSE]
    target <- .ms_semantic_add_missing_cols(target, target_cols)
    return(target[, target_cols, drop = FALSE])
  }

  if (!is.null(dict_row)) {
    target <- .ms_semantic_column_term_target_from_dictionary(dict_row)
    target <- .ms_semantic_add_missing_cols(target, target_cols)
    return(target[, target_cols, drop = FALSE])
  }

  tibble::as_tibble(stats::setNames(rep(list(NA_character_), length(target_cols)), target_cols))
}

.ms_semantic_filter_column_term_suggestions <- function(suggestions, dict_row) {
  suggestions <- .ms_semantic_candidate_rows(suggestions)
  if (nrow(suggestions) == 0L) {
    return(suggestions)
  }

  keep <- rep(TRUE, nrow(suggestions))
  if ("dataset_id" %in% names(suggestions) && "dataset_id" %in% names(dict_row)) {
    keep <- keep & (is.na(suggestions$dataset_id) | suggestions$dataset_id == dict_row$dataset_id[[1]])
  }
  if ("table_id" %in% names(suggestions) && "table_id" %in% names(dict_row)) {
    keep <- keep & (is.na(suggestions$table_id) | suggestions$table_id == dict_row$table_id[[1]])
  }
  if ("column_name" %in% names(suggestions)) {
    keep <- keep & suggestions$column_name == dict_row$column_name[[1]]
  }
  if ("target_sdp_field" %in% names(suggestions)) {
    keep <- keep & suggestions$target_sdp_field == "term_iri"
  }
  if ("dictionary_role" %in% names(suggestions)) {
    keep <- keep & suggestions$dictionary_role == "variable"
  }

  suggestions[keep, , drop = FALSE]
}

.ms_semantic_has_usable_suggestions <- function(suggestions) {
  suggestions <- tibble::as_tibble(suggestions)
  if (nrow(suggestions) == 0 || !"iri" %in% names(suggestions)) {
    return(FALSE)
  }

  iris <- as.character(suggestions$iri)
  iris[is.na(iris)] <- ""
  any(nzchar(trimws(iris)))
}

.ms_semantic_merge_llm_assessments <- function(suggestions, assessments, top_n) {
  suggestions <- tibble::as_tibble(suggestions)
  assessments <- tibble::as_tibble(assessments)

  if (nrow(suggestions) == 0) {
    return(suggestions)
  }

  suggestions$.ms_group_key <- .ms_semantic_group_key_df(suggestions)
  suggestions$.ms_row_order <- seq_len(nrow(suggestions))

  suggestions |>
    dplyr::group_by(.data$.ms_group_key) |>
    dplyr::mutate(llm_candidate_rank = dplyr::if_else(dplyr::row_number() <= top_n, dplyr::row_number(), NA_integer_)) |>
    dplyr::ungroup() |>
    dplyr::left_join(
      assessments,
      by = .ms_semantic_assessment_join_cols()
    ) |>
    dplyr::mutate(
      llm_selected = !is.na(.data$llm_selected_candidate_index) &
        !is.na(.data$llm_candidate_rank) &
        .data$llm_selected_candidate_index == .data$llm_candidate_rank
    ) |>
    dplyr::select(-dplyr::any_of(c(".ms_group_key", ".ms_bundle_key", ".ms_row_order")))
}
