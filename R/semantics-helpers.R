.ms_semantic_split_role_hints <- function(x) {
  if (is.null(x) || length(x) == 0) {
    return(character())
  }
  hints <- trimws(unlist(strsplit(as.character(x), "\\|", fixed = FALSE)))
  hints[nzchar(hints)]
}

.ms_semantic_role_hint_status <- function(role, role_hints) {
  hints <- .ms_semantic_split_role_hints(role_hints)
  if (length(hints) == 0) {
    return("unknown")
  }
  if (role %in% hints) {
    return("match")
  }
  if (identical(role, "variable") && "property" %in% hints) {
    return("mismatch_property")
  }
  if (identical(role, "property") && "variable" %in% hints) {
    return("mismatch_variable")
  }
  "unknown"
}

.ms_semantic_role_hint_bonus <- function(status) {
  switch(status,
    match = 0.35,
    mismatch_property = -0.35,
    mismatch_variable = -0.35,
    0
  )
}

.ms_semantic_role_hint_explanation <- function(status, role) {
  switch(status,
    match = paste0("Candidate carries a ", role, " role hint."),
    mismatch_property = "Candidate carries a property hint; kept lower for variable destination.",
    mismatch_variable = "Candidate carries a variable hint; kept lower for property destination.",
    NA_character_
  )
}

.ms_sources_for_target_role <- function(base_sources, search_role) {
  if (length(base_sources) == 0) {
    return(base_sources)
  }
  if (!identical(search_role, "unit")) {
    return(base_sources)
  }

  unique(c(base_sources, sources_for_role("unit")))
}

.ms_retrieve_semantic_target_candidates <- function(target,
                                                    sources,
                                                    max_per_role,
                                                    search_fn,
                                                    query = NULL,
                                                    retrieval_pass = 1L) {
  target <- tibble::as_tibble(target)
  if (nrow(target) == 0) {
    return(tibble::tibble())
  }

  search_role <- as.character((target$search_role[[1]] %||% target$dictionary_role[[1]]) %||% "")
  if (!nzchar(search_role)) {
    return(tibble::tibble())
  }

  query <- trimws(as.character(query[[1]] %||% target$search_query[[1]] %||% ""))
  if (!nzchar(query)) {
    return(tibble::tibble())
  }

  target_sources <- .ms_sources_for_target_role(sources, search_role)
  res <- search_fn(query, role = search_role, sources = target_sources)
  if (!inherits(res, "data.frame") || nrow(res) == 0) {
    return(tibble::tibble())
  }

  res <- tibble::as_tibble(res)
  res <- res[!duplicated(paste(res$source, res$iri, sep = "::")), , drop = FALSE]
  if (!"role_hints" %in% names(res)) {
    res$role_hints <- NA_character_
  }
  res$role_hint_status <- vapply(
    res$role_hints,
    function(h) .ms_semantic_role_hint_status(search_role, h),
    character(1)
  )
  res$role_hint_bonus <- vapply(res$role_hint_status, .ms_semantic_role_hint_bonus, numeric(1))
  res$role_hint_explanation <- vapply(
    res$role_hint_status,
    function(s) .ms_semantic_role_hint_explanation(s, search_role),
    character(1)
  )
  if ("score" %in% names(res)) {
    res$score <- res$score + res$role_hint_bonus
    res <- res[order(-res$score, res$source, res$ontology, res$label, res$iri), , drop = FALSE]
  } else {
    res <- res[order(-res$role_hint_bonus, res$source, res$ontology, res$label, res$iri), , drop = FALSE]
  }
  res <- utils::head(res, max(1L, as.integer(max_per_role[[1]] %||% 3L)))

  target_cols <- intersect(.ms_semantic_target_cols(), names(target))
  for (nm in target_cols) {
    res[[nm]] <- target[[nm]][[1]]
  }
  res$retrieval_query <- query
  res$retrieval_pass <- as.integer(retrieval_pass[[1]] %||% 1L)
  res
}

.ms_merge_semantic_target_candidates <- function(existing_rows, extra_rows, max_per_role) {
  existing_rows <- tibble::as_tibble(existing_rows)
  extra_rows <- tibble::as_tibble(extra_rows)
  combined <- dplyr::bind_rows(existing_rows, extra_rows)
  if (nrow(combined) == 0) {
    return(combined)
  }

  if ("score" %in% names(combined)) {
    combined <- combined[order(
      -combined$score,
      combined$source,
      combined$ontology,
      combined$label,
      combined$iri,
      combined$retrieval_pass,
      combined$retrieval_query
    ), , drop = FALSE]
  } else {
    combined <- combined[order(
      -combined$role_hint_bonus,
      combined$source,
      combined$ontology,
      combined$label,
      combined$iri,
      combined$retrieval_pass,
      combined$retrieval_query
    ), , drop = FALSE]
  }

  combined <- combined[!duplicated(paste(combined$source, combined$iri, sep = "::")), , drop = FALSE]
  utils::head(combined, max(1L, as.integer(max_per_role[[1]] %||% 3L)))
}

#' Suggest semantic annotations for a dictionary
#'
#' Searches external vocabularies to suggest IRIs for semantic gaps in the
#' dictionary and package metadata. Measurement columns keep full I-ADOPT
#' decomposition (`term_iri`, `property_iri`, `entity_iri`, `unit_iri`,
#' `constraint_iri`), while selected non-measurement columns can receive
#' lighter `term_iri` coverage when they are categorical or controlled
#' low-cardinality attributes.
#'
#' The function uses the column's label or description as the search query and
#' returns suggestions as an attribute on the dictionary tibble. This allows
#' you to review candidates before accepting them into your dictionary.
#'
#' @param df A data frame or tibble containing the data being documented, or a
#'   named list of data frames for multi-table workflows. When a named list is
#'   supplied, `suggest_semantics()` matches each dictionary row to the correct
#'   table via `dict$table_id` and uses that table's data as context.
#' @param dict A dictionary tibble created by `infer_dictionary()` (may have
#'   incomplete semantic fields).
#' @param sources Character vector of vocabulary sources to search. Options are
#'   `"smn"` (Salmon Domain Ontology via content negotiation), `"gcdfo"` (DFO-specific source), `"ols"` (Ontology Lookup Service), `"nvs"` (NERC Vocabulary Server), and
#'   `"bioportal"` (requires `BIOPORTAL_APIKEY` environment variable).
#'   Default is `c("smn", "gcdfo", "ols", "nvs")`.
#' @param include_dwc Logical; if `TRUE`, also attach DwC-DP export mappings
#'   (via `suggest_dwc_mappings()`) as a parallel attribute `dwc_mappings`.
#'   Default is `FALSE` to keep the UI simple for non-DwC users.
#' @param max_per_role Maximum number of suggestions to keep per I-ADOPT role
#'   (variable, property, entity, unit, constraint) per column. Default is 3.
#' @param search_fn Function used to search terms. Defaults to `find_terms()`.
#'   Can be replaced for testing or custom search strategies.
#' @param codes Optional `codes.csv`-like tibble. When provided, suggestions are
#'   also generated for missing `codes.csv$term_iri` targets.
#' @param table_meta Optional `tables.csv`-like tibble. When provided,
#'   suggestions are generated for missing `tables.csv$observation_unit_iri`.
#' @param dataset_meta Optional `dataset.csv`-like tibble. When provided,
#'   suggestions are generated for missing `dataset.csv$keywords` as candidate
#'   semantic keywords (IRIs intended for keyword curation).
#' @param llm_assess Logical; if `TRUE`, assess the top semantic candidates per
#'   target with an LLM after deterministic retrieval. When the first shortlist
#'   looks weak, the LLM may request at most one bounded alternate-query pass
#'   (1--2 plain-text search phrases) before a single reassessment. Default is
#'   `FALSE`.
#' @param llm_provider LLM provider preset. One of `"openai"`,
#'   `"openrouter"`, `"openai_compatible"`, or `"chapi"`.
#' @param llm_model Character model identifier. Required when
#'   `llm_assess = TRUE` unless supplied via `METASALMON_LLM_MODEL`. When
#'   `llm_provider = "openrouter"` and no model is supplied, the package
#'   defaults to `"openrouter/free"`. Any valid OpenRouter model ID may be
#'   supplied here (for example `"openai/gpt-5.4-mini"`). When
#'   `llm_provider = "chapi"` and no model is supplied, the package defaults
#'   to `"ollama2.mistral:7b"` and also checks `CHAPI_MODEL`.
#' @param llm_api_key Optional API key override. If omitted, provider-specific
#'   environment variables are used (`OPENAI_API_KEY`, `OPENROUTER_API_KEY`,
#'   `CHAPI_API_KEY`, or `METASALMON_LLM_API_KEY`).
#' @param llm_base_url Optional base URL override for the OpenAI-compatible
#'   chat endpoint. Required for `llm_provider = "openai_compatible"` when not
#'   set via `METASALMON_LLM_BASE_URL`. For `llm_provider = "chapi"`, the
#'   package defaults to `https://chapi-dev.intra.azure.cloud.dfo-mpo.gc.ca/api`
#'   and also checks `CHAPI_BASE_URL`.
#' @param llm_reasoning_effort Optional reasoning-effort hint forwarded to the
#'   OpenAI chat-completions request body when `llm_provider = "openai"`.
#' @param llm_top_n Maximum number of retrieved candidates to send to the LLM
#'   per target for each assessment round. Default is `5`.
#' @param llm_context_files Optional character vector of local context files
#'   (for example README/markdown notes, CSV dictionaries, HTML exports,
#'   DOCX files, source/notebook files such as `.R`, `.Rmd`, or `.qmd`, Excel
#'   workbooks, or PDF reports) used to provide extra domain context to the
#'   LLM when `llm_assess = TRUE`. Pass file paths, not parsed data frames, XML
#'   documents, or R Markdown objects. Supplying context does not enable LLM
#'   review; without `llm_assess = TRUE`, it is ignored with a warning. PDF
#'   support uses the optional `pdftools` package; Excel support uses the
#'   optional `readxl` package.
#' @param llm_context_text Optional character vector of extra inline context
#'   snippets passed alongside `llm_context_files`.
#' @param llm_timeout_seconds Timeout for each LLM request in seconds.
#'   `chapi` models matching `gpt-oss` are automatically given at least 120
#'   seconds because the internal endpoint can be slow to warm up.
#' @param llm_request_fn Advanced/test hook overriding the low-level
#'   OpenAI-compatible request function.
#'
#' @return The dictionary tibble (unchanged) with a `semantic_suggestions`
#'   attribute containing a tibble of suggested IRIs. The suggestions tibble
#'   starts with `column_name`, `dictionary_role`, `table_id`, and `dataset_id`
#'   so the original dictionary term is visible before the candidate match.
#'   It also includes `target_scope`, `target_sdp_file`, and
#'   `target_sdp_field` so users can see exactly where each accepted suggestion
#'   would land in the Salmon Data Package. Additional columns include
#'   `search_query`, `target_query_basis`, `target_query_context`,
#'   `column_label`, `column_description`, `label`, `iri`,
#'   `source`, `ontology`, `definition`, `retrieval_query`, and
#'   `retrieval_pass`. If the underlying search results include a `score`
#'   column, it is preserved for downstream filtering.
#'   For non-column targets, the tibble also includes explicit destination
#'   context (`target_row_key`, `target_label`, `target_description`,
#'   `code_value`, `code_label`, `code_description`) so table-, dataset-, and
#'   code-level rows are inspectable without extra joins. When
#'   `llm_assess = TRUE`, the suggestions also include `llm_*` review columns
#'   such as `llm_decision`, `llm_confidence`, `llm_selected`,
#'   `llm_candidate_rank`, and bounded exploration metadata, and the
#'   dictionary gains a parallel `semantic_llm_assessments` attribute with one
#'   row per assessed target.
#'
#' @details
#' Column targets keep full I-ADOPT behavior for
#' `column_role == "measurement"` rows. Non-measurement coverage is lighter:
#' only missing `term_iri` values are considered, focused on categorical rows
#' and controlled low-cardinality attribute rows inferred through `codes.csv`.
#' Identifier and temporal columns are skipped by default. When `codes`,
#' `table_meta`, or `dataset_meta` are supplied, additional target rows are
#' generated for `codes.csv`, `tables.csv`, and `dataset.csv` respectively.
#' Table-level observation-unit queries ignore review placeholders such as
#' `MISSING METADATA:` and fall back to real table metadata context instead.
#'
#' When `llm_assess = TRUE`, the LLM only judges deterministically retrieved
#' candidates; it does not mint new IRIs. If the first shortlist looks weak,
#' the model may suggest at most one bounded alternate-query round (1--2
#' plain-text queries), the package reruns deterministic retrieval, de-dupes
#' the merged shortlist, and reassesses once. If the model rejects the entire
#' shortlist (`reject_shortlist`) and that bounded retry still surfaces no
#' acceptable candidate, the assessment is escalated to `request_new_term` so a
#' likely ontology gap shows up in `llm_decision` instead of a dead-end
#' rejection. Local context files are read on disk, chunked, and lexically
#' trimmed down before prompt assembly so large README/report/workbook files do
#' not get dumped wholesale into the model call. Plain-text/CSV context with
#' invalid UTF-8 is retried as Windows-1252/Latin-1, and colliding file base
#' names are disambiguated in `llm_context_sources`. If a batched provider
#' response has malformed, missing, or duplicate target items, valid siblings
#' are retained and only affected targets fall back to individual review.
#'
#' A term can legitimately appear more than once with different
#' `dictionary_role` values (for example as both a variable and a property).
#' In that case, `match_type` still describes lexical match quality, while
#' `target_sdp_field` tells you where that suggestion would be written in the
#' package. The output adds `role_collision` and `role_collision_note` so
#' variable-vs-property collisions stay explicit and destination-aware.
#'
#' After calling this function, access suggestions with:
#' ```
#' suggestions <- attr(result, "semantic_suggestions")
#' ```
#'
#' Suggestions stay separate by default. Review them first, then use
#' [apply_semantic_suggestions()] for an explicit opt-in merge, or copy values
#' manually when you need finer control.
#'
#' @seealso [find_terms()] for direct vocabulary searches, [infer_dictionary()]
#'   for creating starter dictionaries, [apply_semantic_suggestions()] for
#'   explicitly filling selected IRI fields, [validate_dictionary()] for
#'   checking dictionary completeness.
#' @importFrom metasalmon suggest_dwc_mappings
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # Create a starter dictionary
#' dict <- infer_dictionary(my_data, dataset_id = "example", table_id = "main")
#'
#' # Get semantic suggestions for measurement columns
#' dict_with_suggestions <- suggest_semantics(my_data, dict)
#'
#' # View the suggestions
#' suggestions <- attr(dict_with_suggestions, "semantic_suggestions")
#' print(suggestions)
#'
#' # Filter suggestions for a specific column
#' spawner_suggestions <- suggestions[suggestions$column_name == "SPAWNER_COUNT", ]
#'
#' # Explicitly apply the top suggestion for one column without overwriting
#' # any existing IRIs in the dictionary
#' dict <- apply_semantic_suggestions(dict_with_suggestions, columns = "SPAWNER_COUNT")
#' }
suggest_semantics <- function(df,
                              dict,
                              sources = c("smn", "gcdfo", "ols", "nvs"),
                              include_dwc = FALSE,
                              max_per_role = 3,
                              search_fn = find_terms,
                              codes = NULL,
                              table_meta = NULL,
                              dataset_meta = NULL,
                              llm_assess = FALSE,
                              llm_provider = c("openai", "openrouter", "openai_compatible", "chapi"),
                              llm_model = NULL,
                              llm_api_key = NULL,
                              llm_base_url = NULL,
                              llm_reasoning_effort = NULL,
                              llm_top_n = 5L,
                              llm_context_files = NULL,
                              llm_context_text = NULL,
                              llm_timeout_seconds = 60,
                              llm_request_fn = NULL) {
  .ms_apply_llm_context_policy(
    llm_assess = llm_assess,
    context_files = llm_context_files,
    context_text = llm_context_text
  )

  resource_lookup <- NULL
  default_df <- NULL

  if (is.list(df) && !inherits(df, "data.frame")) {
    if (length(df) == 0) {
      cli::cli_abort("{.arg df} cannot be an empty resource list")
    }
    if (is.null(names(df)) || any(!nzchar(names(df)))) {
      cli::cli_abort("{.arg df} list inputs must be named by table_id")
    }
    if (anyDuplicated(names(df)) > 0) {
      cli::cli_abort("{.arg df} table_id names must be unique")
    }
    bad_resource <- vapply(df, function(x) !inherits(x, "data.frame"), logical(1))
    if (any(bad_resource)) {
      bad <- which(bad_resource)
      cli::cli_abort("All items in {.arg df} must be data frames. Invalid entries at: {.val {bad}}")
    }
    resource_lookup <- df
    default_df <- resource_lookup[[1L]]
  } else if (is.null(df) || inherits(df, "data.frame")) {
    default_df <- df
  } else {
    cli::cli_abort("{.arg df} must be NULL, a data frame, or a named list of data frames")
  }

  dict <- tibble::as_tibble(dict)
  codes <- if (is.null(codes)) tibble::tibble() else tibble::as_tibble(codes)
  table_meta <- if (is.null(table_meta)) tibble::tibble() else tibble::as_tibble(table_meta)
  dataset_meta <- if (is.null(dataset_meta)) tibble::tibble() else tibble::as_tibble(dataset_meta)

  if (nrow(dict) == 0 && nrow(codes) == 0 && nrow(table_meta) == 0 && nrow(dataset_meta) == 0) {
    attr(dict, "semantic_suggestions") <- tibble::tibble()
    if (isTRUE(llm_assess)) {
      attr(dict, "semantic_llm_assessments") <- tibble::tibble()
    }
    if (isTRUE(include_dwc)) {
      attr(dict, "dwc_mappings") <- tibble::tibble()
    }
    return(dict)
  }

  targets <- .ms_semantic_discover_targets(
    dict = dict,
    codes = codes,
    table_meta = table_meta,
    dataset_meta = dataset_meta,
    resource_lookup = resource_lookup,
    default_df = default_df
  )
  suggestion_leading_cols <- .ms_semantic_suggestion_leading_cols()

  suggestions <- purrr::map_dfr(seq_len(nrow(targets)), function(i) {
    target <- targets[i, , drop = FALSE]
    res <- .ms_retrieve_semantic_target_candidates(
      target = target,
      sources = sources,
      max_per_role = max_per_role,
      search_fn = search_fn,
      retrieval_pass = 1L
    )
    if (nrow(res) == 0) return(tibble::tibble())

    optional_cols <- intersect(
      c("score", "alignment_only", "agreement_sources", "zooma_confidence", "zooma_annotator", "role_hints", "role_hint_status", "role_hint_bonus", "role_hint_explanation"),
      names(res)
    )
    dplyr::select(
      res,
      dplyr::all_of(c(suggestion_leading_cols, "label", "iri", "source", "ontology", "role", "match_type", "definition")),
      dplyr::all_of(optional_cols),
      dplyr::everything()
    )
  })

  if (nrow(suggestions) > 0) {
    suggestions$candidate_label_norm <- tolower(trimws(suggestions$label %||% ""))
    grouped <- suggestions %>%
      dplyr::group_by(
        .data$dataset_id,
        .data$table_id,
        .data$column_name,
        .data$code_value,
        .data$target_scope,
        .data$target_sdp_file,
        .data$candidate_label_norm
      ) %>%
      dplyr::summarise(
        collision_roles = paste(sort(unique(.data$dictionary_role)), collapse = "|"),
        role_collision = all(c("variable", "property") %in% unique(.data$dictionary_role)),
        .groups = "drop"
      )
    suggestions <- suggestions %>%
      dplyr::left_join(
        grouped,
        by = c(
          "dataset_id",
          "table_id",
          "column_name",
          "code_value",
          "target_scope",
          "target_sdp_file",
          "candidate_label_norm"
        )
      ) %>%
      dplyr::mutate(
        role_collision_note = dplyr::case_when(
          .data$role_collision & .data$dictionary_role == "variable" ~ paste0(
            "Label appears for variable and property candidates; this row targets variable semantics for ",
            .data$target_sdp_field,
            "."
          ),
          .data$role_collision & .data$dictionary_role == "property" ~ paste0(
            "Label appears for variable and property candidates; this row targets property semantics for ",
            .data$target_sdp_field,
            "."
          ),
          TRUE ~ NA_character_
        )
      ) %>%
      dplyr::select(-dplyr::any_of("candidate_label_norm"))
  }

  if (isTRUE(llm_assess) && nrow(suggestions) > 0) {
    llm_results <- .ms_assess_semantic_suggestions_llm(
      suggestions,
      provider = llm_provider,
      model = llm_model,
      api_key = llm_api_key,
      base_url = llm_base_url,
      reasoning_effort = llm_reasoning_effort,
      top_n = llm_top_n,
      context_files = llm_context_files,
      context_text = llm_context_text,
      timeout_seconds = llm_timeout_seconds,
      request_fn = llm_request_fn,
      search_fn = search_fn,
      sources = sources,
      max_per_role = max_per_role
    )
    suggestions <- llm_results$suggestions
    attr(dict, "semantic_llm_assessments") <- llm_results$assessments
  } else if (isTRUE(llm_assess)) {
    attr(dict, "semantic_llm_assessments") <- tibble::tibble()
  }

  attr(dict, "semantic_suggestions") <- suggestions

  if (isTRUE(include_dwc)) {
    attr(dict, "dwc_mappings") <- metasalmon::suggest_dwc_mappings(dict) |> attr("dwc_mappings")
  }

  if (nrow(suggestions) > 0) {
    cli::cli_inform("Semantic suggestions stored in attr('semantic_suggestions') for downstream review.")
  } else {
    cli::cli_inform("No semantic suggestions found for missing semantic metadata.")
  }

  dict
}

#' Apply semantic suggestions into a dictionary
#'
#' Copies selected IRIs from a `semantic_suggestions` tibble into the matching
#' dictionary fields. Suggestions remain separate by default; this helper gives
#' you an explicit merge step when you decide the top candidates are good enough.
#'
#' Matching is done by both `column_name` and `dictionary_role`. When the
#' suggestions tibble also includes `dataset_id` and `table_id`, those keys are
#' honored too. Suggestions that target non-column destinations (for example
#' `codes.csv`, `tables.csv`, or `dataset.csv`) are ignored by this helper and
#' remain review-only.
#'
#' @param dict A dictionary tibble, typically returned by [infer_dictionary()] or
#'   [suggest_semantics()].
#' @param suggestions A suggestions tibble, usually
#'   `attr(dict, "semantic_suggestions")`. If omitted, the function reads that
#'   attribute from `dict`.
#' @param strategy Selection strategy per column-role pair. `"top"` keeps the
#'   original lexical ranking; `"llm"` applies only candidates marked with
#'   `llm_selected = TRUE` by `suggest_semantics(..., llm_assess = TRUE)`.
#' @param columns Optional character vector limiting application to specific
#'   `column_name` values.
#' @param roles Optional character vector limiting application to specific
#'   suggestion roles: `"variable"`, `"property"`, `"entity"`, `"unit"`,
#'   `"constraint"`, `"method"`.
#' @param min_score Optional numeric threshold. Only available when
#'   `suggestions` includes a `score` column; otherwise the function errors.
#' @param min_llm_confidence Optional numeric threshold for `strategy = "llm"`.
#'   Requires `llm_confidence` in `suggestions`.
#' @param overwrite Logical; if `FALSE` (default), only missing fields are
#'   filled. Set `TRUE` to intentionally replace existing IRIs.
#' @param verbose Logical; if `TRUE` (default), print a short summary.
#'
#' @return The dictionary tibble with selected semantic IRI fields filled in.
#' @export
#'
#' @examples
#' \dontrun{
#' dict <- infer_dictionary(my_data, dataset_id = "example", table_id = "main")
#' dict <- suggest_semantics(my_data, dict)
#'
#' # Fill only the missing semantic fields for one measurement column
#' dict <- apply_semantic_suggestions(dict, columns = "SPAWNER_COUNT")
#'
#' # Require stronger lexical matches when score is available
#' dict <- apply_semantic_suggestions(dict, min_score = 2)
#' }
apply_semantic_suggestions <- function(dict,
                                       suggestions = attr(dict, "semantic_suggestions"),
                                       strategy = c("top", "llm"),
                                       columns = NULL,
                                       roles = NULL,
                                       min_score = NULL,
                                       min_llm_confidence = NULL,
                                       overwrite = FALSE,
                                       verbose = TRUE) {
  if (!inherits(dict, "data.frame")) {
    cli::cli_abort("{.arg dict} must be a data frame or tibble")
  }

  if (is.null(suggestions)) {
    cli::cli_abort(
      c(
        "No semantic suggestions supplied.",
        "i" = "Pass {.arg suggestions} explicitly or run {.fn suggest_semantics} first."
      )
    )
  }

  suggestions <- tibble::as_tibble(suggestions)
  if (nrow(suggestions) == 0) {
    if (isTRUE(verbose)) {
      cli::cli_inform("No semantic suggestions to apply.")
    }
    return(dict)
  }

  required_cols <- c("column_name", "dictionary_role", "iri")
  missing_cols <- setdiff(required_cols, names(suggestions))
  if (length(missing_cols) > 0) {
    cli::cli_abort(
      "Suggestions are missing required columns: {.field {missing_cols}}"
    )
  }

  role_to_field <- c(
    variable = "term_iri",
    property = "property_iri",
    entity = "entity_iri",
    unit = "unit_iri",
    constraint = "constraint_iri",
    method = "method_iri"
  )

  if (!is.null(roles)) {
    invalid_roles <- setdiff(roles, names(role_to_field))
    if (length(invalid_roles) > 0) {
      cli::cli_abort(
        "Unsupported {.arg roles}: {.val {invalid_roles}}. Valid roles: {.val {names(role_to_field)}}"
      )
    }
  }

  if (!is.null(min_score) && !"score" %in% names(suggestions)) {
    cli::cli_abort(
      c(
        "{.arg min_score} requires scored suggestions.",
        "i" = "Run {.fn suggest_semantics} with the default search results or pass a suggestions tibble that includes a {.field score} column."
      )
    )
  }

  strategy <- match.arg(strategy)

  if (!is.null(min_llm_confidence) && !"llm_confidence" %in% names(suggestions)) {
    cli::cli_abort(
      c(
        "{.arg min_llm_confidence} requires LLM-reviewed suggestions.",
        "i" = "Run {.fn suggest_semantics} with {.code llm_assess = TRUE} or pass a suggestions tibble that includes {.field llm_confidence}."
      )
    )
  }

  infer_term_type <- function(suggestion_row) {
    if ("term_type" %in% names(suggestion_row)) {
      candidate <- as.character(suggestion_row$term_type[[1]] %||% "")
      if (!is.na(candidate) && nzchar(trimws(candidate))) {
        return(trimws(candidate))
      }
    }
    if (identical(suggestion_row$dictionary_role[[1]], "variable")) {
      return("skos_concept")
    }
    NA_character_
  }

  out <- dict
  for (field in unique(unname(role_to_field))) {
    if (!field %in% names(out)) {
      out[[field]] <- NA_character_
    }
  }

  suggestions$.row_id <- seq_len(nrow(suggestions))
  suggestions <- suggestions[!is.na(suggestions$iri) & suggestions$iri != "", , drop = FALSE]

  if ("target_scope" %in% names(suggestions)) {
    keep <- is.na(suggestions$target_scope) | suggestions$target_scope == "column"
    dropped <- sum(!keep)
    suggestions <- suggestions[keep, , drop = FALSE]
    if (isTRUE(verbose) && dropped > 0) {
      cli::cli_inform(
        "{dropped} suggestion{?s} target non-column scopes and were left as review-only metadata."
      )
    }
  }
  if ("target_sdp_file" %in% names(suggestions)) {
    keep <- is.na(suggestions$target_sdp_file) | suggestions$target_sdp_file == "column_dictionary.csv"
    dropped <- sum(!keep)
    suggestions <- suggestions[keep, , drop = FALSE]
    if (isTRUE(verbose) && dropped > 0) {
      cli::cli_inform(
        "{dropped} suggestion{?s} target non-dictionary files and were not auto-applied."
      )
    }
  }

  if (!is.null(columns)) {
    suggestions <- suggestions[suggestions$column_name %in% columns, , drop = FALSE]
  }
  if (!is.null(roles)) {
    suggestions <- suggestions[suggestions$dictionary_role %in% roles, , drop = FALSE]
  }
  if (!is.null(min_score)) {
    suggestions <- suggestions[!is.na(suggestions$score) & suggestions$score >= min_score, , drop = FALSE]
  }
  if (identical(strategy, "llm")) {
    if (!"llm_selected" %in% names(suggestions)) {
      cli::cli_abort(
        c(
          "{.arg strategy = 'llm'} requires LLM-reviewed suggestions.",
          "i" = "Run {.fn suggest_semantics} with {.code llm_assess = TRUE} first."
        )
      )
    }
    suggestions <- suggestions[!is.na(suggestions$llm_selected) & suggestions$llm_selected, , drop = FALSE]
  }
  if (!is.null(min_llm_confidence)) {
    suggestions <- suggestions[!is.na(suggestions$llm_confidence) & suggestions$llm_confidence >= min_llm_confidence, , drop = FALSE]
  }

  suggestions <- .ms_filter_auto_apply_suggestions(out, suggestions)

  unknown_roles <- unique(suggestions$dictionary_role[!is.na(suggestions$dictionary_role) &
    !suggestions$dictionary_role %in% names(role_to_field)])
  if (length(unknown_roles) > 0) {
    cli::cli_warn("Ignoring unsupported suggestion roles: {.val {unknown_roles}}")
  }
  suggestions <- suggestions[!is.na(suggestions$dictionary_role) & suggestions$dictionary_role %in% names(role_to_field), , drop = FALSE]

  if (nrow(suggestions) == 0) {
    if (isTRUE(verbose)) {
      cli::cli_inform("No semantic suggestions met the requested filters.")
    }
    return(out)
  }

  match_keys <- c(intersect(c("dataset_id", "table_id"), names(suggestions)), "column_name", "dictionary_role")
  selected <- suggestions[order(suggestions$.row_id), , drop = FALSE]
  group_id <- do.call(
    paste,
    c(
      lapply(selected[match_keys], function(x) ifelse(is.na(x), "<NA>", as.character(x))),
      sep = "\r"
    )
  )
  selected <- selected[!duplicated(group_id), , drop = FALSE]

  dict_match_keys <- intersect(c("dataset_id", "table_id"), names(out))
  applied <- 0L
  skipped_existing <- 0L
  unmatched <- 0L

  for (i in seq_len(nrow(selected))) {
    suggestion <- selected[i, , drop = FALSE]
    role <- suggestion$dictionary_role[[1]]
    field <- role_to_field[[role]]

    matches <- out$column_name == suggestion$column_name[[1]]
    for (key in dict_match_keys) {
      if (key %in% names(suggestion)) {
        key_value <- suggestion[[key]][[1]]
        if (!is.na(key_value) && key_value != "") {
          matches <- matches & out[[key]] == key_value
        }
      }
    }

    row_ids <- which(matches)
    if (length(row_ids) == 0) {
      unmatched <- unmatched + 1L
      next
    }

    if (isTRUE(overwrite)) {
      out[[field]][row_ids] <- suggestion$iri[[1]]
      if (identical(field, "term_iri") && "term_type" %in% names(out)) {
        term_type_guess <- infer_term_type(suggestion)
        if (!is.na(term_type_guess) && nzchar(term_type_guess)) {
          missing_term_type <- is.na(out$term_type[row_ids]) | out$term_type[row_ids] == ""
          if (any(missing_term_type)) {
            out$term_type[row_ids[missing_term_type]] <- term_type_guess
          }
        }
      }
      if (identical(field, "unit_iri") && "unit_label" %in% names(out) && "label" %in% names(suggestion)) {
        missing_labels <- is.na(out$unit_label[row_ids]) | out$unit_label[row_ids] == ""
        if (any(missing_labels)) {
          out$unit_label[row_ids[missing_labels]] <- suggestion$label[[1]]
        }
      }
      applied <- applied + length(row_ids)
      next
    }

    missing_now <- is.na(out[[field]][row_ids]) | out[[field]][row_ids] == ""
    fill_rows <- row_ids[missing_now]
    if (length(fill_rows) > 0) {
      out[[field]][fill_rows] <- suggestion$iri[[1]]
      if (identical(field, "term_iri") && "term_type" %in% names(out)) {
        term_type_guess <- infer_term_type(suggestion)
        if (!is.na(term_type_guess) && nzchar(term_type_guess)) {
          missing_term_type <- is.na(out$term_type[fill_rows]) | out$term_type[fill_rows] == ""
          if (any(missing_term_type)) {
            out$term_type[fill_rows[missing_term_type]] <- term_type_guess
          }
        }
      }
      if (identical(field, "unit_iri") && "unit_label" %in% names(out) && "label" %in% names(suggestion)) {
        missing_labels <- is.na(out$unit_label[fill_rows]) | out$unit_label[fill_rows] == ""
        if (any(missing_labels)) {
          out$unit_label[fill_rows[missing_labels]] <- suggestion$label[[1]]
        }
      }
      applied <- applied + length(fill_rows)
    }

    if (identical(field, "term_iri") && "term_type" %in% names(out)) {
      term_type_guess <- infer_term_type(suggestion)
      if (!is.na(term_type_guess) && nzchar(term_type_guess)) {
        existing_rows <- row_ids[!missing_now]
        if (length(existing_rows) > 0) {
          missing_term_type <- is.na(out$term_type[existing_rows]) | out$term_type[existing_rows] == ""
          if (any(missing_term_type)) {
            out$term_type[existing_rows[missing_term_type]] <- term_type_guess
          }
        }
      }
    }
    skipped_existing <- skipped_existing + sum(!missing_now)
  }

  if (isTRUE(verbose)) {
    msg <- c(
      "Applied {.val {applied}} semantic suggestion field{?s} using the {.val {strategy}} strategy."
    )
    if (!overwrite && skipped_existing > 0) {
      msg <- c(
        msg,
        "i" = paste0(
          skipped_existing,
          " field",
          if (skipped_existing == 1) " was" else "s were",
          " left alone because the dictionary already had an IRI. Use overwrite = TRUE to replace them."
        )
      )
    }
    if (unmatched > 0) {
      msg <- c(
        msg,
        "i" = paste0(
          unmatched,
          " suggestion",
          if (unmatched == 1) " did" else "s did",
          " not match any dictionary row."
        )
      )
    }
    cli::cli_inform(msg)
  }

  out
}
