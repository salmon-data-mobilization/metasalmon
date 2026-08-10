 .term_request_default_template <- "https://github.com/salmon-data-mobilization/salmon-domain-ontology/blob/main/.github/ISSUE_TEMPLATE/new-term-request.md"
 .term_request_gcdfo_default_template <- "https://github.com/dfo-pacific-science/dfo-salmon-ontology/blob/main/.github/ISSUE_TEMPLATE/new-term-request.md"

#' Detect candidate and LLM-identified semantic term gaps
#'
#' Given semantic suggestions (typically attached to a dictionary as
#' `semantic_suggestions`), this function summarizes candidate fields that lack
#' a direct SMN match and final LLM `request_new_term` decisions. An explicit
#' final LLM gap remains a gap even when SMN candidates exist.
#'
#' It is designed to support a practical workflow:
#'
#' 1. generate semantic suggestions with `suggest_semantics()`;
#' 2. detect unresolved gaps with `detect_semantic_term_gaps()`;
#' 3. render request payloads with `render_ontology_term_request()`;
#' 4. optionally submit issues with `submit_term_request_issues()`.
#'
#' @param dict A dictionary tibble. When `suggestions` is `NULL`, the function
#'   reads both `semantic_suggestions` and `semantic_llm_assessments` attributes.
#' @param suggestions Optional semantic suggestion table. If omitted, this function
#'   uses the dictionary attributes. If supplied explicitly, only candidate and
#'   embedded `llm_*` fields in this table are used; dictionary assessment
#'   attributes are intentionally ignored.
#' @param include_target_scopes Target scopes to inspect. Defaults to all supported
#'   scopes.
#' @param include_dictionary_roles Optional vector of dictionary roles to restrict
#'   the gap scan (for example `c("variable", "property", "entity")`).
#' @param min_score Optional minimum score filter. Rows with score below this value
#'   are ignored when score is available.
#'
#' @return A tibble with one row per unresolved semantic target. The existing
#'   23-column candidate-gap prefix is preserved, followed by target metadata,
#'   `gap_detection_basis`, LLM decision/rationale, proposed-term fields, and
#'   `llm_escalated_from`. Detection values are `candidate_gap`,
#'   `llm_request_new_term`, or
#'   `candidate_gap_and_llm_request_new_term`.
#'   Key columns:
#'   - `dataset_id`, `table_id`, `column_name`, `target_scope`,
#'     `target_sdp_file`, `target_sdp_field`, `target_row_key`, `dictionary_role`;
#'   - `search_query` text used for lookup;
#'   - `top_non_smn_source`, `top_non_smn_label`, `top_non_smn_iri`,
#'     `top_non_smn_score`;
#'   - `non_smn_sources`, `candidate_count`, `placement_recommendation`,
#'     `placement_confidence`, `placement_rationale`.
#'
#' @seealso [render_ontology_term_request()], [submit_term_request_issues()],
#'   [suggest_semantics()]
#'
#' @export
#'
#' @examples
#' suggestions <- tibble::tibble(
#'   dataset_id = c("d1", "d1"),
#'   table_id = c("t1", "t1"),
#'   column_name = c("run_id", "run_id"),
#'   code_value = NA_character_,
#'   column_label = c("Run ID", "Run ID"),
#'   column_description = "Run identifier from local monitoring pipeline",
#'   dictionary_role = c("variable", "variable"),
#'   target_scope = c("column", "column"),
#'   target_sdp_file = c("column_dictionary.csv", "column_dictionary.csv"),
#'   target_sdp_field = c("term_iri", "term_iri"),
#'   target_row_key = c("run_id", "run_id"),
#'   search_query = c("run_id", "run_id"),
#'   label = c("Run ID", "Run ID"),
#'   iri = c(NA_character_, NA_character_),
#'   source = c("gbif", "worms"),
#'   ontology = c("gbif", "worms"),
#'   match_type = c("label", "label"),
#'   definition = NA_character_,
#'   score = c(0.9, 0.85)
#' )
#' gaps <- detect_semantic_term_gaps(
#'   suggestions = suggestions,
#'   include_dictionary_roles = "variable"
#' )
#' gaps
#'
#'
#' @export
detect_semantic_term_gaps <- function(
    dict = NULL,
    suggestions = NULL,
    include_target_scopes = c("column", "code", "table", "dataset"),
    include_dictionary_roles = NULL,
    min_score = NA_real_
) {
  suggestions_supplied <- !is.null(suggestions)
  assessments <- NULL
  if (!suggestions_supplied) {
    if (is.null(dict)) {
      cli::cli_abort("Provide either `dict` with `semantic_suggestions` or `suggestions`.")
    }
    suggestions <- attr(dict, "semantic_suggestions")
    assessments <- attr(dict, "semantic_llm_assessments")
  }

  suggestions <- if (is.null(suggestions)) tibble::tibble() else tibble::as_tibble(suggestions)
  if (suggestions_supplied) {
    assessments <- .ms_term_gap_embedded_assessments(suggestions)
  } else {
    assessments <- if (is.null(assessments)) {
      .ms_empty_llm_assessments()
    } else {
      .ms_llm_normalize_assessment_rows(assessments)
    }
  }

  if (nrow(suggestions) == 0L && nrow(assessments) == 0L) {
    return(.empty_term_gap_result())
  }

  if (nrow(suggestions) > 0L) {
    required <- c(
      .ms_semantic_assessment_join_cols(),
      "target_row_key",
      "column_label",
      "column_description",
      "source",
      "label",
      "iri",
      "ontology",
      "match_type",
      "definition"
    )
    missing_cols <- setdiff(required, names(suggestions))
    if (length(missing_cols) > 0L) {
      cli::cli_abort(
        "Missing required suggestion columns: {paste(missing_cols, collapse = ', ')}"
      )
    }
    suggestions <- .ms_semantic_add_missing_cols(
      suggestions,
      c("target_label", "target_description", "score")
    )
  }

  include_target_scopes <- tolower(trimws(as.character(include_target_scopes)))
  include_dictionary_roles <- if (is.null(include_dictionary_roles)) {
    NULL
  } else {
    tolower(trimws(as.character(include_dictionary_roles)))
  }

  if (nrow(suggestions) > 0L) {
    suggestions$target_scope <- tolower(trimws(as.character(suggestions$target_scope)))
    suggestions$dictionary_role <- tolower(trimws(as.character(suggestions$dictionary_role)))
    suggestions <- suggestions[
      suggestions$target_scope %in% include_target_scopes,
      ,
      drop = FALSE
    ]
    if (!is.null(include_dictionary_roles)) {
      suggestions <- suggestions[
        suggestions$dictionary_role %in% include_dictionary_roles,
        ,
        drop = FALSE
      ]
    }
  }

  target_metadata <- list()
  if (nrow(suggestions) > 0L) {
    suggestions$.ms_gap_key <- .ms_semantic_key_df(
      suggestions,
      .ms_semantic_assessment_join_cols()
    )
    target_metadata <- lapply(
      split(suggestions, suggestions$.ms_gap_key),
      function(rows) rows[1, , drop = FALSE]
    )
  }

  if (nrow(assessments) > 0L) {
    assessments$target_scope <- tolower(trimws(as.character(assessments$target_scope)))
    assessments$dictionary_role <- tolower(trimws(as.character(assessments$dictionary_role)))
    assessments <- assessments[
      assessments$target_scope %in% include_target_scopes,
      ,
      drop = FALSE
    ]
    if (!is.null(include_dictionary_roles)) {
      assessments <- assessments[
        assessments$dictionary_role %in% include_dictionary_roles,
        ,
        drop = FALSE
      ]
    }
  }

  if (nrow(suggestions) > 0L) {
    suggestions$source <- tolower(trimws(as.character(suggestions$source)))
    suggestions$score <- suppressWarnings(as.numeric(suggestions$score))
    if (!is.na(min_score)) {
      keep <- is.na(suggestions$score) | suggestions$score >= min_score
      suggestions <- suggestions[keep, , drop = FALSE]
    }
  }

  llm_gaps <- assessments[
    !is.na(assessments$llm_decision) &
      assessments$llm_decision == "request_new_term",
    ,
    drop = FALSE
  ]
  if (nrow(suggestions) == 0L && nrow(llm_gaps) == 0L) {
    return(.empty_term_gap_result())
  }

  join_cols <- .ms_semantic_assessment_join_cols()
  candidate_groups <- list()
  if (nrow(suggestions) > 0L) {
    suggestions$.ms_gap_key <- .ms_semantic_key_df(suggestions, join_cols)
    candidate_groups <- split(suggestions, suggestions$.ms_gap_key)
  }
  if (nrow(llm_gaps) > 0L) {
    llm_gaps$.ms_gap_key <- .ms_semantic_key_df(llm_gaps, join_cols)
  }

  candidate_rows <- lapply(names(candidate_groups), function(key) {
    .ms_term_gap_candidate_summary(candidate_groups[[key]], key)
  })
  candidate_rows <- stats::setNames(candidate_rows, names(candidate_groups))

  llm_groups <- if (nrow(llm_gaps) > 0L) {
    split(llm_gaps, llm_gaps$.ms_gap_key)
  } else {
    list()
  }
  all_keys <- union(
    names(candidate_rows)[vapply(candidate_rows, function(x) isTRUE(x$candidate_gap), logical(1))],
    names(llm_groups)
  )
  if (length(all_keys) == 0L) {
    return(.empty_term_gap_result())
  }

  rows <- lapply(all_keys, function(key) {
    candidate <- candidate_rows[[key]]
    llm <- llm_groups[[key]]
    .ms_term_gap_combine_evidence(
      key = key,
      candidate = candidate,
      assessment_rows = llm,
      dict = if (suggestions_supplied) NULL else dict,
      target_metadata = target_metadata[[key]]
    )
  })

  gaps <- dplyr::bind_rows(rows)
  # Confidence alone is not a total order, and `order()` is stable, so ties kept
  # the order of `all_keys` -- which comes from `split()`, whose factor levels
  # are a locale-collated sort of the group keys. That made the row order of an
  # exported return value locale-dependent. The identity columns break ties
  # explicitly in C collation, independent of how the groups were built.
  gaps <- gaps[
    order(
      -gaps$placement_confidence,
      gaps$dataset_id, gaps$table_id, gaps$column_name, gaps$code_value,
      method = "radix", na.last = TRUE
    ),
    .ms_term_gap_cols(),
    drop = FALSE
  ]
  tibble::as_tibble(gaps)
}

.ms_term_gap_cols <- function() {
  c(
    "dataset_id",
    "table_id",
    "column_name",
    "code_value",
    "target_scope",
    "target_sdp_file",
    "target_sdp_field",
    "target_row_key",
    "dictionary_role",
    "search_query",
    "column_label",
    "column_description",
    "top_non_smn_source",
    "top_non_smn_label",
    "top_non_smn_iri",
    "top_non_smn_ontology",
    "top_non_smn_match_type",
    "top_non_smn_score",
    "candidate_count",
    "non_smn_sources",
    "placement_recommendation",
    "placement_confidence",
    "placement_rationale",
    "target_label",
    "target_description",
    "gap_detection_basis",
    "llm_decision",
    "llm_confidence",
    "llm_rationale",
    "llm_new_term_label",
    "llm_new_term_definition",
    "llm_new_term_namespace",
    "llm_escalated_from"
  )
}

.ms_term_gap_embedded_assessments <- function(suggestions) {
  if (nrow(suggestions) == 0L || !"llm_decision" %in% names(suggestions)) {
    return(.ms_empty_llm_assessments())
  }

  embedded <- .ms_llm_normalize_assessment_rows(suggestions)
  unique(embedded)
}

.ms_term_gap_candidate_summary <- function(group, key) {
  group <- tibble::as_tibble(group)
  group$is_smn <- vapply(seq_len(nrow(group)), function(i) {
    source <- .first_non_empty(group$source[[i]], "")
    iri <- .first_non_empty(group$iri[[i]], "")
    nzchar(iri) && (
      identical(source, "smn") ||
        grepl("^https?://w3id\\.org/smn/", iri, ignore.case = TRUE)
    )
  }, logical(1))

  non_smn <- group[!group$is_smn, , drop = FALSE]
  top <- if (nrow(non_smn) > 0L) {
    score <- suppressWarnings(as.numeric(non_smn$score))
    # Character tie-breakers on an equal score, and the chosen row becomes the
    # `top_non_smn_*` evidence in an exported return value.
    non_smn[
      order(-score, non_smn$source, non_smn$label, method = "radix", na.last = TRUE), ,
      drop = FALSE
    ][1, , drop = FALSE]
  } else {
    tibble::tibble()
  }
  sources <- .unique_char(.trim_empties(non_smn$source))
  metadata <- group[1, , drop = FALSE]
  recommendation <- .recommend_term_placement(
    search_query = metadata$search_query[[1]],
    dictionary_role = metadata$dictionary_role[[1]],
    sources = sources,
    local_hint = .has_local_term_signals(
      metadata$search_query[[1]],
      metadata$dictionary_role[[1]],
      sources
    )
  )

  list(
    key = key,
    group = group,
    metadata = metadata,
    candidate_gap = !any(group$is_smn) && nrow(non_smn) > 0L,
    top = top,
    non_smn = non_smn,
    sources = sources,
    recommendation = recommendation
  )
}

.ms_term_gap_proposal_value <- function(rows, column, key) {
  if (is.null(rows) || nrow(rows) == 0L || !column %in% names(rows)) {
    return(NA_character_)
  }
  values <- .unique_char(.trim_empties(rows[[column]]))
  if (length(values) > 1L) {
    cli::cli_abort(
      "Conflicting {.field {column}} values for semantic target {.val {key}}."
    )
  }
  .first_non_empty(values)
}

.ms_term_gap_dictionary_metadata <- function(dict, metadata) {
  if (is.null(dict) || !inherits(dict, "data.frame") || nrow(dict) == 0L) {
    return(list(column_label = NA_character_, column_description = NA_character_))
  }
  keep <- rep(TRUE, nrow(dict))
  for (column in intersect(c("dataset_id", "table_id", "column_name"), names(dict))) {
    value <- .first_non_empty(metadata[[column]], "")
    if (nzchar(value)) {
      keep <- keep & !is.na(dict[[column]]) & as.character(dict[[column]]) == value
    }
  }
  match <- dict[keep, , drop = FALSE]
  list(
    column_label = if (nrow(match) > 0L && "column_label" %in% names(match)) {
      .first_non_empty(match$column_label)
    } else {
      NA_character_
    },
    column_description = if (nrow(match) > 0L && "column_description" %in% names(match)) {
      .first_non_empty(match$column_description)
    } else {
      NA_character_
    }
  )
}

.ms_term_gap_combine_evidence <- function(key,
                                          candidate = NULL,
                                          assessment_rows = NULL,
                                          dict = NULL,
                                          target_metadata = NULL) {
  assessment_rows <- if (is.null(assessment_rows)) {
    .ms_empty_llm_assessments()
  } else {
    unique(.ms_llm_normalize_assessment_rows(assessment_rows))
  }
  metadata <- if (!is.null(candidate)) {
    candidate$metadata
  } else if (!is.null(target_metadata)) {
    target_metadata
  } else {
    assessment_rows[1, , drop = FALSE]
  }
  metadata <- .ms_semantic_add_missing_cols(
    metadata,
    c(
      "target_row_key",
      "target_label",
      "target_description",
      "column_label",
      "column_description"
    )
  )
  dict_metadata <- .ms_term_gap_dictionary_metadata(dict, metadata)

  candidate_gap <- !is.null(candidate) && isTRUE(candidate$candidate_gap)
  llm_gap <- nrow(assessment_rows) > 0L
  basis <- if (candidate_gap && llm_gap) {
    "candidate_gap_and_llm_request_new_term"
  } else if (llm_gap) {
    "llm_request_new_term"
  } else {
    "candidate_gap"
  }

  top <- if (!is.null(candidate)) candidate$top else tibble::tibble()
  sources <- if (!is.null(candidate)) candidate$sources else character()
  recommendation <- if (!is.null(candidate)) {
    candidate$recommendation
  } else {
    .recommend_term_placement(
      search_query = metadata$search_query[[1]],
      dictionary_role = metadata$dictionary_role[[1]],
      sources = character(),
      local_hint = .has_local_term_signals(
        metadata$search_query[[1]],
        metadata$dictionary_role[[1]],
        character()
      )
    )
  }

  llm_rationales <- if (nrow(assessment_rows) > 0L) {
    .unique_char(.trim_empties(assessment_rows$llm_rationale))
  } else {
    character()
  }
  column_label <- .first_non_empty(
    c(metadata$column_label, dict_metadata$column_label, metadata$column_name)
  )
  column_description <- .first_non_empty(
    c(metadata$column_description, dict_metadata$column_description)
  )
  target_label <- .first_non_empty(
    c(metadata$target_label, column_label, metadata$search_query, metadata$column_name)
  )
  target_description <- .first_non_empty(
    c(metadata$target_description, column_description)
  )
  llm_label <- .ms_term_gap_proposal_value(
    assessment_rows,
    "llm_new_term_label",
    key
  )
  llm_definition <- .ms_term_gap_proposal_value(
    assessment_rows,
    "llm_new_term_definition",
    key
  )
  llm_namespace <- .ms_term_gap_proposal_value(
    assessment_rows,
    "llm_new_term_namespace",
    key
  )
  escalated_from <- .ms_term_gap_proposal_value(
    assessment_rows,
    "llm_escalated_from",
    key
  )

  tibble::tibble(
    dataset_id = .first_non_empty(metadata$dataset_id),
    table_id = .first_non_empty(metadata$table_id),
    column_name = .first_non_empty(metadata$column_name),
    code_value = .first_non_empty(metadata$code_value),
    target_scope = .first_non_empty(metadata$target_scope),
    target_sdp_file = .first_non_empty(metadata$target_sdp_file),
    target_sdp_field = .first_non_empty(metadata$target_sdp_field),
    target_row_key = .first_non_empty(
      c(
        metadata$target_row_key,
        paste(
          .first_non_empty(metadata$dataset_id, ""),
          .first_non_empty(metadata$table_id, ""),
          .first_non_empty(metadata$column_name, ""),
          sep = "/"
        )
      )
    ),
    dictionary_role = .first_non_empty(metadata$dictionary_role),
    search_query = .first_non_empty(metadata$search_query),
    column_label = column_label,
    column_description = column_description,
    top_non_smn_source = if (nrow(top) > 0L) .first_non_empty(top$source) else NA_character_,
    top_non_smn_label = if (nrow(top) > 0L) .first_non_empty(top$label) else NA_character_,
    top_non_smn_iri = if (nrow(top) > 0L) .first_non_empty(top$iri) else NA_character_,
    top_non_smn_ontology = if (nrow(top) > 0L) .first_non_empty(top$ontology) else NA_character_,
    top_non_smn_match_type = if (nrow(top) > 0L) .first_non_empty(top$match_type) else NA_character_,
    top_non_smn_score = if (nrow(top) > 0L) suppressWarnings(as.numeric(top$score[[1]])) else NA_real_,
    candidate_count = if (!is.null(candidate)) nrow(candidate$non_smn) else 0L,
    non_smn_sources = if (length(sources) > 0L) paste(sources, collapse = ", ") else NA_character_,
    placement_recommendation = recommendation$placement,
    placement_confidence = recommendation$confidence,
    placement_rationale = recommendation$rationale,
    target_label = target_label,
    target_description = target_description,
    gap_detection_basis = basis,
    llm_decision = if (llm_gap) "request_new_term" else NA_character_,
    llm_confidence = if (llm_gap) {
      confidence <- suppressWarnings(as.numeric(assessment_rows$llm_confidence))
      if (all(is.na(confidence))) NA_real_ else max(confidence, na.rm = TRUE)
    } else {
      NA_real_
    },
    llm_rationale = if (length(llm_rationales) > 0L) {
      paste(llm_rationales, collapse = " | ")
    } else {
      NA_character_
    },
    llm_new_term_label = .first_non_empty(c(llm_label, target_label)),
    llm_new_term_definition = .first_non_empty(
      c(llm_definition, target_description, "Curator definition required.")
    ),
    llm_new_term_namespace = llm_namespace,
    llm_escalated_from = escalated_from
  )
}

#' Render GitHub-ready ontology term request payloads
#'
#' Convert gap candidates into request payload rows (title/body) suitable for
#' creating GitHub issues against the Salmon Domain Ontology repository by
#' default.
#'
#' For interactive workflows this function can prompt users row-by-row for whether a
#' gap should be requested as a shared SMN term, a profile-specific term, or skipped.
#'
#' @param gaps Output from `detect_semantic_term_gaps()`.
#' @param scope One of `"auto"`, `"smn"`, `"gcdfo"`, or `"profile"`.
#'   - `"auto"`: use a recognized namespace suggestion as evidence, otherwise
#'     use `placement_recommendation`, and ask for uncertainty
#'   - `"smn"`: route all requests to shared SMN
#'   - `"gcdfo"`: route all requests to the DFO-specific GCDFO repository
#'   - `"profile"`: route all requests to a profile
#' @param ask If `TRUE`, unresolved rows are asked interactively.
#' @param profile_name If routing to profiles, provide a default profile name.
#' @param scope_overrides Optional per-row scope overrides (`"smn"`, `"gcdfo"`,
#'   `"profile"`, `"uncertain"`, or `"skip"`). Useful in non-interactive
#'   pipelines. Precedence is row override, forced `scope`, recognized
#'   `llm_new_term_namespace`, then placement heuristic. The namespace is
#'   evidence, not authority.
#' @param issue_labels Optional labels to include on created GitHub issues.
#' @param term_request_template URL for the target issue template.
#' @param ontology_repo Repository slug to target when submitting issues.
#' @param gcdfo_term_request_template URL for the GCDFO issue template.
#' @param gcdfo_repo Repository slug for DFO-specific GCDFO requests.
#'
#' @return A tibble with one row per rendered request payload. Rows with
#'   `request_scope == "skip"` are retained and can be filtered before
#'   submission. SMN and GCDFO rows use their repository-specific issue
#'   templates. Rendering never submits an issue.
#'
#' @seealso [detect_semantic_term_gaps()], [submit_term_request_issues()],
#'   [validate_semantics()]
#'
#' @export
#'
#' @examples
#' gap <- dplyr::tibble(
#'   dataset_id = "d1",
#'   table_id = "t1",
#'   column_name = "run_id",
#'   code_value = NA_character_,
#'   target_scope = "column",
#'   target_sdp_file = "column_dictionary.csv",
#'   target_sdp_field = "term_iri",
#'   target_row_key = "run_id",
#'   dictionary_role = "variable",
#'   search_query = "run id",
#'   column_label = "Run ID",
#'   column_description = "Dataset-specific run identifier",
#'   top_non_smn_source = "gbif",
#'   top_non_smn_label = "Run event id",
#'   top_non_smn_iri = NA_character_,
#'   top_non_smn_ontology = NA_character_,
#'   top_non_smn_match_type = "label",
#'   top_non_smn_score = 0.9,
#'   candidate_count = 2,
#'   non_smn_sources = "gbif, worms",
#'   placement_recommendation = "profile",
#'   placement_confidence = 0.82,
#'   placement_rationale = "Contains internal identifier patterns."
#' )
#'
#' render_ontology_term_request(
#'   gap,
#'   scope = "auto",
#'   ask = FALSE,
#'   profile_name = "pacific-monitoring"
#' )
#'

render_ontology_term_request <- function(
    gaps,
    scope = c("auto", "smn", "gcdfo", "profile"),
    ask = interactive(),
    profile_name = NULL,
    scope_overrides = NULL,
    issue_labels = NULL,
    term_request_template = .term_request_default_template,
    ontology_repo = "salmon-data-mobilization/salmon-domain-ontology",
    gcdfo_term_request_template = .term_request_gcdfo_default_template,
    gcdfo_repo = "dfo-pacific-science/dfo-salmon-ontology"
) {
  scope <- match.arg(scope)
  gaps <- as.data.frame(gaps, stringsAsFactors = FALSE)

  if (nrow(gaps) == 0L) {
    return(tibble::tibble())
  }

  required <- c(
    "dataset_id", "table_id", "column_name", "target_scope", "target_sdp_file",
    "target_sdp_field", "target_row_key", "dictionary_role", "search_query",
    "column_label", "column_description", "top_non_smn_source",
    "top_non_smn_label", "top_non_smn_iri", "top_non_smn_ontology",
    "placement_recommendation"
  )
  missing <- setdiff(required, names(gaps))
  if (length(missing) > 0L) {
    cli::cli_abort("Missing required gap columns: {paste(missing, collapse = ', ')}")
  }

  gaps <- as.data.frame(gaps, stringsAsFactors = FALSE)
  gaps$request_scope <- if (scope == "auto") {
    placement <- tolower(trimws(as.character(gaps$placement_recommendation)))
    namespace_scope <- if ("llm_new_term_namespace" %in% names(gaps)) {
      vapply(gaps$llm_new_term_namespace, .ms_term_request_namespace_scope, character(1))
    } else {
      rep(NA_character_, nrow(gaps))
    }
    placement[!is.na(namespace_scope)] <- namespace_scope[!is.na(namespace_scope)]
    placement
  } else {
    rep(scope, nrow(gaps))
  }

  if (!is.null(scope_overrides)) {
    scope_overrides <- tolower(trimws(as.character(scope_overrides)))
    if (length(scope_overrides) == 1L) {
      gaps$request_scope <- scope_overrides
    } else {
      if (length(scope_overrides) != nrow(gaps)) {
        cli::cli_abort("`scope_overrides` must be length 1 or nrow(gaps).")
      }
      gaps$request_scope <- scope_overrides
    }
  }

  gaps$request_scope[is.na(gaps$request_scope) | !nzchar(gaps$request_scope)] <- "uncertain"

  # Interactive follow-up only for rows that need judgement.
  if (ask) {
    unresolved <- which(gaps$request_scope %in% c("auto", "uncertain", "") )
    for (i in unresolved) {
      term_label <- .first_non_empty(c(gaps$top_non_smn_label[[i]], gaps$search_query[[i]], gaps$column_name[[i]], "Unnamed term"))
      cli::cli_h2("Term gap review for {.val {term_label}}")
      cli::cat_line(
        sprintf(
          "Target: dataset=%s table=%s scope=%s field=%s role=%s",
          gaps$dataset_id[[i]], gaps$table_id[[i]], gaps$target_scope[[i]],
          gaps$target_sdp_field[[i]], gaps$dictionary_role[[i]]
        )
      )
      # cli, not glue: `{.val {x}}` is cli inline markup. glue has no `.val`
      # class, so it hands `.val {x}` to parse() and fails on every input.
      if (nzchar(.first_non_empty(gaps$top_non_smn_source[i], ""))) {
        candidate_label <- gaps$top_non_smn_label[[i]]
        candidate_source <- gaps$top_non_smn_source[[i]]
        cli::cli_text("Candidate: {.val {candidate_label}} ({.val {candidate_source}})")
      }
      if (nzchar(.first_non_empty(gaps$placement_rationale[i], ""))) {
        placement_rationale <- gaps$placement_rationale[[i]]
        cli::cli_text("Why: {.val {placement_rationale}}")
      }
      scope_choices <- c("smn", "gcdfo", "profile", "skip")
      pick <- utils::menu(
        c(
          "Request in shared SMN",
          "Request in DFO-specific GCDFO",
          "Request in local/program/organization profile",
          "Skip for now"
        ),
        title = "How should this term request be routed?"
      )
      # menu() returns 0L when the user exits without choosing. Guard before
      # indexing: `scope_choices[0]` is character(0), not NA, so assigning it
      # errors with "replacement has length zero".
      gaps$request_scope[i] <- if (length(pick) == 1L && !is.na(pick) &&
                                   pick >= 1L && pick <= length(scope_choices)) {
        scope_choices[[pick]]
      } else {
        "skip"
      }

      if (gaps$request_scope[i] == "profile" && is.null(profile_name)) {
        profile_candidate <- trimws(readline(prompt = "Profile name (example: pacific-monitoring): "))
        if (!nzchar(profile_candidate)) {
          cli::cli_warn("No profile name supplied; skipping this request.")
          gaps$request_scope[i] <- "skip"
        } else {
          profile_name <- profile_candidate
        }
      }
      gaps$profile_name[i] <- if (gaps$request_scope[i] == "profile") profile_name else NA_character_
    }
  } else {
    gaps$profile_name <- NA_character_
    if (!is.null(profile_name)) {
      profile_name <- trimws(as.character(profile_name[[1L]]))
    }

    profile_rows <- which(gaps$request_scope == "profile")
    profile_name_missing <- is.null(profile_name) || !nzchar(profile_name)
    if (length(profile_rows) > 0L && profile_name_missing) {
      profile_terms <- unique(vapply(profile_rows, function(i) {
        .first_non_empty(c(gaps$top_non_smn_label[[i]], gaps$search_query[[i]], gaps$column_name[[i]], "Unnamed term"))
      }, character(1), USE.NAMES = FALSE))
      profile_terms <- profile_terms[nzchar(profile_terms)]
      profile_detail <- if (length(profile_terms) > 0L) {
        sprintf(
          "Profile-scoped rows include: %s.",
          paste(utils::head(profile_terms, 3L), collapse = ", ")
        )
      } else {
        sprintf("Detected %d profile-scoped row(s).", length(profile_rows))
      }
      cli::cli_abort(c(
        "Non-interactive profile-scoped requests require `profile_name`.",
        "i" = .ms_cli_escape(profile_detail),
        "x" = "Re-run with `profile_name = 'your-profile'`, set `ask = TRUE`, or override those rows away from `profile`."
      ))
    }

    gaps$profile_name[gaps$request_scope == "profile"] <- profile_name
  }

  gaps$request_scope <- ifelse(
    gaps$request_scope %in% c("smn", "gcdfo", "profile"),
    gaps$request_scope,
    "skip"
  )

  gaps$request_title <- vapply(seq_len(nrow(gaps)), function(i) {
    term_label <- .ms_term_request_label(gaps[i, , drop = FALSE])
    if (gaps$request_scope[[i]] == "smn") {
      sprintf("Request new shared SMN term: %s", term_label)
    } else if (gaps$request_scope[[i]] == "gcdfo") {
      sprintf("Request new GCDFO term: %s", term_label)
    } else if (gaps$request_scope[[i]] == "profile") {
      profile_label <- .first_non_empty(gaps$profile_name[[i]], "")
      if (!nzchar(profile_label)) {
        cli::cli_abort("Internal error: profile-scoped request is missing `profile_name`.")
      }
      sprintf("Request new %s profile term: %s", profile_label, term_label)
    } else {
      sprintf("Skip term request: %s", term_label)
    }
  }, character(1), USE.NAMES = FALSE)

  gaps$request_body <- vapply(seq_len(nrow(gaps)), function(i) {
    .ms_render_term_request_body(
      gaps[i, , drop = FALSE],
      request_scope = gaps$request_scope[[i]],
      profile_name = .first_non_empty(gaps$profile_name[[i]], ""),
      smn_template = term_request_template,
      smn_repo = ontology_repo,
      gcdfo_template = gcdfo_term_request_template,
      gcdfo_repo = gcdfo_repo
    )
  }, character(1), USE.NAMES = FALSE)

  if (is.null(issue_labels)) {
    issue_labels <- as.list(rep(list(NULL), nrow(gaps)))
  }
  if (!is.list(issue_labels)) {
    issue_labels <- as.list(rep(list(as.character(issue_labels)), nrow(gaps)))
  } else if (length(issue_labels) == 0L) {
    issue_labels <- as.list(rep(list(NULL), nrow(gaps)))
  }

  # Normalize list of labels
  issue_labels <- lapply(seq_len(nrow(gaps)), function(i) {
    if (length(issue_labels) == 1L) issue_labels[[1L]] else issue_labels[[i]]
  })
  issue_labels <- lapply(issue_labels, function(x) {
    if (is.null(x) || length(x) == 0L) {
      return(NULL)
    }
    x <- .trim_empties(as.character(x))
    if (length(x) == 0L) return(NULL)
    unique(x)
  })

  out <- tibble::as_tibble(gaps)
  out$request_scope <- .trim_empties(out$request_scope)
  out$ontology_repo <- ifelse(
    out$request_scope == "gcdfo",
    gcdfo_repo,
    ontology_repo
  )
  out$issue_labels <- issue_labels
  out
}

.ms_term_request_namespace_scope <- function(namespace) {
  namespace <- tolower(.first_non_empty(namespace, ""))
  if (!nzchar(namespace)) {
    return(NA_character_)
  }
  if (identical(namespace, "smn") || grepl("w3id\\.org/smn", namespace)) {
    return("smn")
  }
  if (
    namespace %in% c("gcdfo", "dfo", "dfo-salmon-ontology") ||
      grepl("w3id\\.org/gcdfo|dfo-salmon-ontology", namespace)
  ) {
    return("gcdfo")
  }
  if (namespace %in% c("profile", "local", "program", "organization")) {
    return("profile")
  }
  NA_character_
}

.ms_term_request_field <- function(row, name, default = NA_character_) {
  if (!name %in% names(row)) {
    return(default)
  }
  .first_non_empty(row[[name]], default)
}

.ms_term_request_label <- function(row) {
  .first_non_empty(
    c(
      .ms_term_request_field(row, "llm_new_term_label"),
      .ms_term_request_field(row, "top_non_smn_label"),
      .ms_term_request_field(row, "target_label"),
      .ms_term_request_field(row, "search_query"),
      .ms_term_request_field(row, "column_label"),
      .ms_term_request_field(row, "column_name"),
      "Unnamed term"
    )
  )
}

.ms_render_term_request_body <- function(row,
                                         request_scope,
                                         profile_name,
                                         smn_template,
                                         smn_repo,
                                         gcdfo_template,
                                         gcdfo_repo) {
  term_label <- .ms_term_request_label(row)
  query <- .first_non_empty(
    c(
      .ms_term_request_field(row, "search_query"),
      .ms_term_request_field(row, "column_name"),
      term_label
    )
  )
  definition <- .first_non_empty(
    c(
      .ms_term_request_field(row, "llm_new_term_definition"),
      .ms_term_request_field(row, "target_description"),
      .ms_term_request_field(row, "column_description"),
      "Curator definition required."
    )
  )
  rationale <- .first_non_empty(
    c(
      .ms_term_request_field(row, "llm_rationale"),
      .ms_term_request_field(row, "placement_rationale"),
      "No rationale captured."
    )
  )
  source <- .ms_term_request_field(row, "top_non_smn_source", "unknown")
  iri <- .ms_term_request_field(row, "top_non_smn_iri", "Not found")
  ontology <- .ms_term_request_field(row, "top_non_smn_ontology", "unknown")
  dataset_id <- .ms_term_request_field(row, "dataset_id", "unknown")
  table_id <- .ms_term_request_field(row, "table_id", "unknown")
  column_name <- .ms_term_request_field(row, "column_name", "unknown")
  role <- .ms_term_request_field(row, "dictionary_role", "unknown")
  target_field <- .ms_term_request_field(row, "target_sdp_field", "unknown")
  detection_basis <- .ms_term_request_field(row, "gap_detection_basis", "candidate_gap")

  if (identical(request_scope, "smn")) {
    return(glue::glue(
      "## Suggested term label (required)\n\n{term_label}\n\n",
      "## Definition (required)\n\n{definition}\n\n",
      "## Definition source (required)\n\nDataset evidence from `{dataset_id}` / `{table_id}` / `{column_name}`.\n\n",
      "## Proposed term type (required)\n\n",
      "- [ ] owl_class\n- [ ] owl_object_property\n- [ ] owl_datatype_property\n- [ ] skos_concept\n\n",
      "## Suggested parent term(s)\n\nCurator decision required.\n\n",
      "## Synonyms (optional)\n\nRELATED: Dataset query `{query}`\n\n",
      "## Suggested relationships / cross-references (optional)\n\n",
      "Nearest external candidate: `{iri}` ({source}; {ontology})\n\n",
      "## Dataset context (optional but helpful)\n\n",
      "- Dataset id: `{dataset_id}`\n",
      "- Table + column(s): `{table_id}` / `{column_name}`\n",
      "- Example values: Not captured\n\n",
      "## I-ADOPT decomposition (for measurement-like terms)\n\n",
      "- property_iri:\n- entity_iri:\n- unit_iri:\n- constraint_iri:\n- method_iri:\n\n",
      "## Additional notes\n\n",
      "- Target field: `{target_field}`\n- Semantic role: `{role}`\n- Gap evidence: `{detection_basis}`\n",
      "- Rationale: {rationale}\n- Template: {smn_template}\n- Repository: https://github.com/{smn_repo}\n"
    ))
  }

  if (identical(request_scope, "gcdfo")) {
    return(glue::glue(
      "Please provide as much information as you can:\n\n",
      "* **Suggested term label (required):** {term_label}\n\n",
      "* **Definition (required):** {definition}\n\n",
      "* **Definition source (required):** Dataset evidence from `{dataset_id}` / `{table_id}` / `{column_name}`.\n\n",
      "* **Parent term(s):** Curator decision required.\n\n",
      "* **Children terms** (if applicable; should any existing terms that should be moved underneath this new proposed term?): None proposed.\n\n",
      "* **Synonyms** (please specify, EXACT, BROAD, NARROW or RELATED): RELATED: Dataset query `{query}`\n\n",
      "* **Cross-references:** Nearest candidate: `{iri}` ({source}; {ontology})\n\n",
      "* **Any other information:** Target field `{target_field}`; semantic role `{role}`; gap evidence `{detection_basis}`. ",
      "{rationale} Template: {gcdfo_template}. Repository: https://github.com/{gcdfo_repo}\n"
    ))
  }

  if (identical(request_scope, "profile")) {
    if (!nzchar(profile_name)) {
      cli::cli_abort("Internal error: profile-scoped request is missing `profile_name`.")
    }
    return(glue::glue(
      "## Proposed profile term\n\n",
      "- Profile: `{profile_name}`\n",
      "- Label: {term_label}\n",
      "- Definition: {definition}\n",
      "- Dataset query: `{query}`\n",
      "- Target: `{dataset_id}` / `{table_id}` / `{column_name}` / `{role}`\n",
      "- Nearest candidate: `{iri}` ({source}; {ontology})\n",
      "- Rationale: {rationale}\n",
      "- New term template: {smn_template}\n"
    ))
  }

  glue::glue(
    "## Skipped ontology term request\n\n",
    "- Label: {term_label}\n",
    "- Dataset query: `{query}`\n",
    "- Rationale: {rationale}\n"
  )
}

#' Submit rendered ontology term requests as GitHub issues
#'
#' Push term request payloads generated by
#' [render_ontology_term_request()] to the ontology repository.
#'
#' In normal development, keep `dry_run = TRUE` while reviewing; set it to
#' `FALSE` only after the request payloads look correct.
#'
#' @param requests Output from `render_ontology_term_request()`.
#' @param repo Fallback repository slug for request rows that do not carry an
#'   `ontology_repo`. Rendered SMN and GCDFO rows use their row-specific
#'   repository values.
#' @param token Optional GitHub PAT. If `NULL`, inferred from `gh` credentials.
#' @param dry_run If `TRUE`, returns a preview payload and does not call GitHub.
#' @param confirm If `TRUE`, prompts before posting each issue.
#'
#' @return A tibble summarizing request outcomes with either a dry-run preview or
#'   GitHub API response fields (`issue_number`, `issue_url`).
#'
#' @seealso [render_ontology_term_request()], [ms_setup_github()]
#'
#' @importFrom utils askYesNo
#' @export
#'
#' @examples
#' sample_gap <- dplyr::tibble(
#'   dataset_id = "d1",
#'   table_id = "t1",
#'   column_name = "run_id",
#'   code_value = NA_character_,
#'   target_scope = "column",
#'   target_sdp_file = "column_dictionary.csv",
#'   target_sdp_field = "term_iri",
#'   target_row_key = "run_id",
#'   dictionary_role = "variable",
#'   search_query = "run id",
#'   column_label = "Run ID",
#'   column_description = "Dataset-specific run identifier",
#'   top_non_smn_source = "gbif",
#'   top_non_smn_label = "Run event id",
#'   top_non_smn_iri = NA_character_,
#'   top_non_smn_ontology = NA_character_,
#'   top_non_smn_match_type = "label",
#'   top_non_smn_score = 0.9,
#'   candidate_count = 1L,
#'   non_smn_sources = "gbif",
#'   placement_recommendation = "profile",
#'   placement_confidence = 0.82,
#'   placement_rationale = "Local identifier-like term for workflow tracking."
#' )
#' reqs <- render_ontology_term_request(
#'   sample_gap,
#'   scope = "auto",
#'   ask = FALSE,
#'   profile_name = "local-program"
#' )
#' submit_term_request_issues(reqs, dry_run = TRUE)
#'
submit_term_request_issues <- function(
    requests,
    repo = "salmon-data-mobilization/salmon-domain-ontology",
    token = NULL,
    dry_run = TRUE,
    confirm = interactive()
) {
  requests <- as.data.frame(requests, stringsAsFactors = FALSE)

  if (nrow(requests) == 0L) {
    return(tibble::tibble())
  }

  required <- c("request_title", "request_body", "request_scope", "ontology_repo")
  missing <- setdiff(required, names(requests))
  if (length(missing) > 0L) {
    cli::cli_abort("Missing required request columns: {paste(missing, collapse = ', ')}")
  }

  default_repo <- ms_normalize_repo(repo)

  pending <- requests[
    requests$request_scope %in% c("smn", "gcdfo", "profile"),
    ,
    drop = FALSE
  ]
  if (nrow(pending) == 0L) {
    return(tibble::tibble())
  }

  if (dry_run) {
    return(tibble::tibble(
      request_title = pending$request_title,
      request_body = pending$request_body,
      request_scope = pending$request_scope,
      ontology_repo = pending$ontology_repo,
      issue_number = NA_integer_,
      issue_url = NA_character_,
      status = rep("dry_run", nrow(pending))
    ))
  }

  if (is.null(token)) {
    token <- ms_current_token()
  }
  if (!nzchar(token)) {
    cli::cli_abort("No GitHub token available. Run {.code metasalmon::ms_setup_github()} first or pass `token`.")
  }

  out <- list()
  for (i in seq_len(nrow(pending))) {
    scope <- pending$request_scope[[i]]
    title <- pending$request_title[[i]]
    body <- pending$request_body[[i]]
    repo_value <- pending$ontology_repo[[i]]
    repo_i <- if (is.na(repo_value) || !nzchar(trimws(repo_value))) {
      default_repo
    } else {
      ms_normalize_repo(repo_value)
    }
    lbls <- if ("issue_labels" %in% names(pending)) pending$issue_labels[[i]] else NULL

    if (is.list(lbls) && length(lbls) == 0L) {
      lbls <- NULL
    }

    # `!isTRUE()`, not `isFALSE()`: askYesNo() returns NA when the user cancels,
    # and isFALSE(NA) is FALSE — which would fall through and post the issue.
    if (isTRUE(confirm) &&
        !isTRUE(askYesNo(sprintf("Submit %s request: %s?", scope, title), default = FALSE))) {
      out[[i]] <- list(
        request_title = title,
        status = "skipped",
        issue_number = NA_integer_,
        issue_url = NA_character_
      )
      next
    }

    resp <- .metasalmon_post_issue(
      repo = repo_i,
      title = title,
      body = body,
      labels = lbls,
      token = token
    )

    out[[i]] <- list(
      request_title = title,
      status = "submitted",
      issue_number = if (!is.null(resp$number)) resp$number else NA_integer_,
      issue_url = if (!is.null(resp$html_url)) resp$html_url else NA_character_
    )
  }

  dplyr::bind_rows(out)
}


.empty_term_gap_result <- function() {
  out <- tibble::tibble(
    dataset_id = character(),
    table_id = character(),
    column_name = character(),
    code_value = character(),
    target_scope = character(),
    target_sdp_file = character(),
    target_sdp_field = character(),
    target_row_key = character(),
    dictionary_role = character(),
    search_query = character(),
    column_label = character(),
    column_description = character(),
    top_non_smn_source = character(),
    top_non_smn_label = character(),
    top_non_smn_iri = character(),
    top_non_smn_ontology = character(),
    top_non_smn_match_type = character(),
    top_non_smn_score = numeric(),
    candidate_count = integer(),
    non_smn_sources = character(),
    placement_recommendation = character(),
    placement_confidence = numeric(),
    placement_rationale = character(),
    target_label = character(),
    target_description = character(),
    gap_detection_basis = character(),
    llm_decision = character(),
    llm_confidence = numeric(),
    llm_rationale = character(),
    llm_new_term_label = character(),
    llm_new_term_definition = character(),
    llm_new_term_namespace = character(),
    llm_escalated_from = character()
  )
  out[, .ms_term_gap_cols(), drop = FALSE]
}

# Internal helper functions (not exported)

.has_local_term_signals <- function(query, dictionary_role, sources) {
  if (is.null(query)) return(FALSE)
  q <- tolower(paste(query, collapse = " "))
  if (!nzchar(q)) return(FALSE)

  local_patterns <- c(
    "id", "ids", "code", "codes", "flag", "status", "project", "program",
    "site", "station", "trip", "haul", "vessel", "fleet", "qc", "qaqc",
    "sample", "event", "group", "run", "permit", "operator", "file"
  )
  local_hits <- vapply(local_patterns, function(p) {
    grepl(paste0("\\b", p, "\\b"), q)
  }, logical(1))

  if (any(local_hits, na.rm = TRUE)) return(TRUE)
  if (tolower(dictionary_role) %in% c("unit", "constraint", "method") && length(sources) > 0L) return(TRUE)
  FALSE
}

.recommend_term_placement <- function(search_query, dictionary_role, sources, local_hint = FALSE) {
  sources <- tolower(.trim_empties(as.character(sources)))
  score_smn <- 0
  score_profile <- 0

  if (any(sources %in% c("smn", "gcdfo"))) score_smn <- score_smn + 2
  if (any(sources %in% c("ols", "nvs", "qudt"))) score_smn <- score_smn + 0.7
  if (any(sources %in% c("gbif", "worms", "bioportal", "zooma"))) score_profile <- score_profile + 0.6

  if (local_hint) score_profile <- score_profile + 1

  # Mildly conservative: variable/measurement semantics that match broad roles trend SMN
  if (dictionary_role %in% c("variable", "property", "entity", "constraint") && length(sources) > 0L) {
    score_smn <- score_smn + 0.4
  }

  if (score_profile >= score_smn + 0.8) {
    placement <- "profile"
  } else if (score_smn >= score_profile + 0.8) {
    placement <- "smn"
  } else {
    placement <- "uncertain"
  }

  gap <- max(abs(score_smn - score_profile), 0)
  confidence <- min(0.95, 0.35 + (gap / 4))

  rationale <- sprintf(
    "Signals: sources={%s}, local_pattern=%s, role=%s -> suggest '%s'",
    paste(sources, collapse = ","),
    ifelse(local_hint, "TRUE", "FALSE"),
    dictionary_role,
    placement
  )

  list(placement = placement, confidence = confidence, rationale = rationale)
}

.trim_empties <- function(x) {
  x <- as.character(x)
  x[!nzchar(x)] <- NA_character_
  x
}

.first_non_empty <- function(x, default = NA_character_) {
  for (i in seq_along(x)) {
    value <- trimws(as.character(x[[i]]))
    if (!is.na(value) && nzchar(value)) {
      return(value)
    }
  }
  default
}

.unique_char <- function(x) {
  unique(x[!is.na(x) & nzchar(x)])
}

.metasalmon_post_issue <- function(repo, title, body, labels = NULL, token) {
  endpoint <- sprintf("/repos/%s/issues", repo)
  payload <- list(title = title, body = body)
  if (!is.null(labels) && length(labels) > 0L) {
    payload$labels <- labels
  }
  do.call(gh::gh, c(list(endpoint, .token = token), payload))
}
