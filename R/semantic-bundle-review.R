.ms_semantic_bundle_roles <- function() {
  c("variable", "property", "entity", "unit", "constraint", "method")
}

.ms_semantic_bundle_slot_fields <- function() {
  c(
    variable = "term_iri",
    property = "property_iri",
    entity = "entity_iri",
    unit = "unit_iri",
    constraint = "constraint_iri",
    method = "method_iri"
  )
}

.ms_semantic_bundle_dictionary_row <- function(target, dict) {
  dict <- tibble::as_tibble(dict)
  if (nrow(dict) == 0L) {
    return(tibble::tibble())
  }

  keep <- rep(TRUE, nrow(dict))
  for (column in intersect(c("dataset_id", "table_id", "column_name"), names(dict))) {
    value <- .ms_semantic_trim_string(target[[column]])
    if (!is.na(value)) {
      keep <- keep & !is.na(dict[[column]]) & as.character(dict[[column]]) == value
    }
  }
  dict[keep, , drop = FALSE]
}

.ms_semantic_bundle_review_targets <- function(targets, dict) {
  targets <- tibble::as_tibble(targets)
  if (nrow(targets) == 0L) {
    return(targets)
  }

  eligible <- vapply(seq_len(nrow(targets)), function(i) {
    target <- targets[i, , drop = FALSE]
    code_value <- .ms_semantic_trim_string(target$code_value)
    if (
      !identical(.ms_semantic_trim_string(target$target_scope), "column") ||
        !is.na(code_value) ||
        !.ms_semantic_trim_string(target$dictionary_role) %in% .ms_semantic_bundle_roles()
    ) {
      return(FALSE)
    }

    dict_row <- .ms_semantic_bundle_dictionary_row(target, dict)
    nrow(dict_row) == 1L &&
      identical(
        tolower(.ms_semantic_trim_string(dict_row$column_role)),
        "measurement"
      )
  }, logical(1))

  targets[eligible, , drop = FALSE]
}

.ms_semantic_bundle_candidate_ids <- function(candidate_rows, role) {
  .ms_semantic_candidate_identity(candidate_rows, role = role)
}

.ms_semantic_bundle_candidate_payload <- function(candidate_rows, role) {
  candidate_rows <- .ms_semantic_candidate_rows(candidate_rows)
  ids <- .ms_semantic_bundle_candidate_ids(candidate_rows, role)

  purrr::map(seq_len(nrow(candidate_rows)), function(i) {
    list(
      candidate_id = ids[[i]],
      label = candidate_rows$label[[i]] %||% "",
      iri = candidate_rows$iri[[i]] %||% "",
      source = candidate_rows$source[[i]] %||% "",
      ontology = candidate_rows$ontology[[i]] %||% "",
      ontology_role = if ("role" %in% names(candidate_rows)) candidate_rows$role[[i]] %||% "" else "",
      role_hints = if ("role_hints" %in% names(candidate_rows)) candidate_rows$role_hints[[i]] %||% "" else "",
      native_type = .ms_semantic_validator_candidate_type(
        candidate_rows[i, , drop = FALSE]
      ),
      definition = candidate_rows$definition[[i]] %||% "",
      lexical_score = if ("score" %in% names(candidate_rows)) candidate_rows$score[[i]] else NA_real_,
      retrieval_query = if ("retrieval_query" %in% names(candidate_rows)) candidate_rows$retrieval_query[[i]] else NA_character_,
      retrieval_pass = if ("retrieval_pass" %in% names(candidate_rows)) candidate_rows$retrieval_pass[[i]] else 1L
    )
  })
}

.ms_semantic_bundle_candidate_groups <- function(targets, suggestions) {
  targets <- tibble::as_tibble(targets)
  suggestions <- tibble::as_tibble(suggestions)
  target_keys <- .ms_semantic_group_key_df(targets)
  suggestion_keys <- if (nrow(suggestions) > 0L) {
    .ms_semantic_group_key_df(suggestions)
  } else {
    character()
  }

  stats::setNames(
    lapply(seq_len(nrow(targets)), function(i) {
      suggestions[suggestion_keys == target_keys[[i]], , drop = FALSE]
    }),
    target_keys
  )
}

.ms_semantic_bundle_context_chunks <- function(targets,
                                               candidate_groups,
                                               context_chunk_pool,
                                               config) {
  chunks <- purrr::map_dfr(seq_len(nrow(targets)), function(i) {
    key <- .ms_semantic_group_key_df(targets[i, , drop = FALSE])[[1]]
    .ms_prepare_context_chunks(
      target_row = targets[i, , drop = FALSE],
      candidate_rows = candidate_groups[[key]],
      max_chunks = .ms_llm_context_chunk_limit(config),
      context_chunk_pool = context_chunk_pool
    )
  })
  if (nrow(chunks) == 0L) {
    return(chunks)
  }

  key <- paste(chunks$source, chunks$chunk_id, sep = "\r")
  chunks <- chunks[!duplicated(key), , drop = FALSE]
  utils::head(chunks, .ms_llm_context_chunk_limit(config))
}

.ms_semantic_bundle_source_policy_payload <- function(source_policy) {
  if (!inherits(source_policy, "metasalmon_source_policy")) {
    source_policy <- .ms_semantic_source_policy(
      source_policy,
      omitted = isTRUE(attr(
        source_policy,
        "metasalmon_sources_omitted",
        exact = TRUE
      ))
    )
  }
  roles <- .ms_semantic_bundle_roles()
  list(
    mode = source_policy$mode,
    explicit_allowlist = if (identical(source_policy$mode, "explicit")) {
      source_policy$sources
    } else {
      character()
    },
    effective_sources_by_role = stats::setNames(
      lapply(
        roles,
        function(role) .ms_sources_for_target_role(source_policy, role)
      ),
      roles
    )
  )
}

.ms_semantic_bundle_payload <- function(targets,
                                        candidate_groups,
                                        dict_row,
                                        context_chunks,
                                        source_policy) {
  roles <- .ms_semantic_bundle_roles()
  fields <- .ms_semantic_bundle_slot_fields()
  target_roles <- as.character(targets$dictionary_role)
  current_slots <- stats::setNames(
    lapply(fields, function(field) {
      if (field %in% names(dict_row)) dict_row[[field]][[1]] %||% NA_character_ else NA_character_
    }),
    names(fields)
  )
  dictionary_context_fields <- intersect(
    c(
      "dataset_id",
      "table_id",
      "column_name",
      "column_label",
      "column_description",
      "column_role",
      "value_type",
      "unit_label",
      "term_type"
    ),
    names(dict_row)
  )

  list(
    bundle_key = .ms_semantic_bundle_key_df(targets[1, , drop = FALSE])[[1]],
    dictionary_context = as.list(dict_row[1, dictionary_context_fields, drop = FALSE]),
    current_slots = current_slots,
    source_policy = .ms_semantic_bundle_source_policy_payload(source_policy),
    slots = purrr::map(roles, function(role) {
      target_index <- match(role, target_roles)
      if (is.na(target_index)) {
        return(list(
          dictionary_role = role,
          target_sdp_field = unname(fields[[role]]),
          status = "already_filled_or_not_requested",
          current_value = current_slots[[role]],
          candidates = list()
        ))
      }

      target <- targets[target_index, , drop = FALSE]
      key <- .ms_semantic_group_key_df(target)[[1]]
      list(
        dictionary_role = role,
        target_sdp_field = target$target_sdp_field[[1]],
        status = "review",
        current_value = current_slots[[role]],
        target_label = target$target_label[[1]],
        target_description = target$target_description[[1]],
        search_query = target$search_query[[1]],
        candidates = .ms_semantic_bundle_candidate_payload(candidate_groups[[key]], role)
      )
    }),
    context_excerpts = .ms_llm_context_payload(context_chunks)
  )
}

.ms_semantic_bundle_system_prompt <- function() {
  paste(
    "You are reviewing one whole measurement-column semantic bundle for the metasalmon R package.",
    "Judge variable, property, entity, unit, constraint, and method together before finalizing any slot.",
    "Role-fit beats topical relatedness. A nearby term is wrong when it does not fit the requested slot.",
    "Preserve each candidate's native ontology type; do not infer that a term is a SKOS concept merely because it targets term_iri.",
    "Treat package method_iri as a bridge to usedProcedure-style procedure context, not as a native I-ADOPT role.",
    "Accept a method only when the field explicitly names a method, protocol, gear, procedure, or estimation process.",
    "Accept a constraint only when explicit contextual evidence changes the meaning; generic catch wording alone is insufficient.",
    "Choose only supplied candidate_id values. Never invent an IRI.",
    "For a wrong candidate family use retry_search with a short lexical retry_query.",
    "When no precise existing concept appears available use request_new_term with suggested_label, suggested_definition, and suggested_namespace.",
    "Return JSON only with keys bundle_summary and assessments.",
    "assessments must contain one item for every slot whose status is review.",
    "Each item must contain dictionary_role, decision, selected_candidate_id, confidence, rationale, missing_context, retry_query, suggested_label, suggested_definition, and suggested_namespace.",
    "decision must be one of accept, review, retry_search, request_new_term, reject_shortlist.",
    "selected_candidate_id must be null unless decision is accept.",
    "confidence must be between 0 and 1."
  )
}

.ms_semantic_bundle_messages <- function(payload) {
  list(
    list(role = "system", content = .ms_semantic_bundle_system_prompt()),
    list(
      role = "user",
      content = paste(
        "Semantic bundle payload:",
        jsonlite::toJSON(payload, auto_unbox = TRUE, pretty = TRUE, null = "null"),
        "\n\nReturn JSON only."
      )
    )
  )
}

.ms_semantic_bundle_enriched_target <- function(target, dict_row) {
  target <- tibble::as_tibble(target)
  extras <- setdiff(names(dict_row), names(target))
  for (column in extras) {
    target[[column]] <- dict_row[[column]][[1]]
  }
  target
}

.ms_semantic_bundle_fallback_record <- function(target,
                                                candidate_rows,
                                                bundle_suggestions,
                                                dict_row,
                                                context_chunks) {
  enriched_target <- .ms_semantic_bundle_enriched_target(target, dict_row)
  group <- tibble::as_tibble(candidate_rows)
  if (nrow(group) == 0L) {
    group <- enriched_target
  } else {
    for (column in setdiff(names(enriched_target), names(group))) {
      group[[column]] <- enriched_target[[column]][[1]]
    }
  }
  group$.ms_row_order <- seq_len(nrow(group))

  list(
    group_name = .ms_semantic_group_key_df(target)[[1]],
    group = group,
    candidate_rows = .ms_semantic_candidate_rows(candidate_rows),
    context_chunks = context_chunks,
    bundle_group = bundle_suggestions,
    decomposition_mode = TRUE
  )
}

.ms_semantic_bundle_fallback_assessment <- function(target,
                                                    candidate_rows,
                                                    bundle_suggestions,
                                                    dict_row,
                                                    context_chunks,
                                                    config,
                                                    reason) {
  record <- .ms_semantic_bundle_fallback_record(
    target = target,
    candidate_rows = candidate_rows,
    bundle_suggestions = bundle_suggestions,
    dict_row = dict_row,
    context_chunks = context_chunks
  )
  row <- .ms_llm_assess_one_record(record, config)
  if (!is.na(reason) && nzchar(reason)) {
    note <- paste0("Bundle response fallback: ", reason)
    existing <- .ms_llm_non_empty_string(row$llm_rationale[[1]] %||% NA_character_)
    row$llm_rationale <- if (is.na(existing)) note else paste(existing, note)
  }
  row
}

.ms_semantic_bundle_validate_item <- function(item,
                                              role,
                                              target,
                                              candidate_rows,
                                              context_chunks,
                                              config,
                                              bundle_summary) {
  candidate_ids <- .ms_semantic_bundle_candidate_ids(candidate_rows, role)
  selected_id <- .ms_llm_non_empty_string(
    item$selected_candidate_id %||% item$candidate_id %||% NA_character_
  )
  decision <- tolower(.ms_llm_non_empty_string(
    item$decision %||% NA_character_
  ))
  if (identical(decision, "propose_new_term")) {
    decision <- "request_new_term"
  }
  if (identical(decision, "accept") && is.na(selected_id)) {
    cli::cli_abort(
      "Bundle assessment for role {.val {role}} accepted without a candidate ID."
    )
  }
  if (!is.na(decision) &&
      !identical(decision, "accept") &&
      !is.na(selected_id)) {
    cli::cli_abort(
      "Bundle assessment for role {.val {role}} selected a candidate for non-accept decision {.val {decision}}."
    )
  }
  if (!is.na(selected_id)) {
    selected_index <- match(selected_id, candidate_ids)
    if (is.na(selected_index)) {
      cli::cli_abort(
        "Bundle assessment for role {.val {role}} selected unknown candidate ID {.val {selected_id}}."
      )
    }
    item$selected_candidate_index <- selected_index
  }
  item$bundle_summary <- item$bundle_summary %||% bundle_summary

  validated <- .ms_llm_review_validate_assessment(item, candidate_rows)
  .ms_llm_review_success_assessment(
    target_row = target,
    candidate_rows = candidate_rows,
    context_chunks = context_chunks,
    config = config,
    validated = validated
  )
}

.ms_semantic_bundle_response_assessments <- function(result,
                                                     targets,
                                                     candidate_groups,
                                                     bundle_suggestions,
                                                     dict_row,
                                                     context_chunks,
                                                     config,
                                                     allow_fallback = TRUE,
                                                     fallback_assessments = NULL) {
  data <- .ms_llm_review_response_data(
    result,
    null_message = "Semantic bundle review did not return a usable JSON object."
  )
  items <- data$assessments %||% NULL
  if (is.null(items) || !is.list(items)) {
    cli::cli_abort("Semantic bundle review must return an assessments array.")
  }

  bundle_summary <- .ms_llm_optional_note(data$bundle_summary %||% NA_character_)
  roles <- as.character(targets$dictionary_role)
  item_roles <- vapply(items, function(item) {
    if (!is.list(item)) return(NA_character_)
    tolower(.ms_llm_non_empty_string(item$dictionary_role %||% item$role %||% NA_character_))
  }, character(1))
  unknown <- unique(item_roles[!is.na(item_roles) & !item_roles %in% roles])
  if (length(unknown) > 0L) {
    cli::cli_warn(
      "Semantic bundle response ignored unknown role(s): {paste(unknown, collapse = ', ')}."
    )
  }

  rows <- vector("list", length(roles))
  for (i in seq_along(roles)) {
    role <- roles[[i]]
    target <- targets[i, , drop = FALSE]
    key <- .ms_semantic_group_key_df(target)[[1]]
    candidate_rows <- candidate_groups[[key]]
    matches <- which(!is.na(item_roles) & item_roles == role)
    reason <- NA_character_

    if (length(matches) == 0L) {
      reason <- paste0("missing assessment for role '", role, "'")
    } else if (length(matches) > 1L) {
      reason <- paste0("duplicate assessments for role '", role, "'")
    } else if (!is.list(items[[matches[[1]]]])) {
      reason <- paste0("malformed assessment for role '", role, "'")
    }

    if (is.na(reason)) {
      validated <- tryCatch(
        .ms_semantic_bundle_validate_item(
          item = items[[matches[[1]]]],
          role = role,
          target = target,
          candidate_rows = candidate_rows,
          context_chunks = context_chunks,
          config = config,
          bundle_summary = bundle_summary
        ),
        error = function(e) e
      )
      if (!inherits(validated, "error")) {
        rows[[i]] <- validated
        next
      }
      reason <- .ms_redact_secrets(conditionMessage(validated))
    }

    if (!is.null(fallback_assessments)) {
      fallback_assessments <- .ms_llm_normalize_assessment_rows(
        fallback_assessments
      )
      fallback_index <- which(
        fallback_assessments$dictionary_role == role
      )
      if (length(fallback_index) == 1L) {
        rows[[i]] <- fallback_assessments[
          fallback_index,
          ,
          drop = FALSE
        ]
        next
      }
    }

    if (!isTRUE(allow_fallback)) {
      cli::cli_abort(
        "Semantic bundle reassessment was unusable for role {.val {role}}: {reason}."
      )
    }

    rows[[i]] <- .ms_semantic_bundle_fallback_assessment(
      target = target,
      candidate_rows = candidate_rows,
      bundle_suggestions = bundle_suggestions,
      dict_row = dict_row,
      context_chunks = context_chunks,
      config = config,
      reason = reason
    )
  }

  dplyr::bind_rows(rows)
}

.ms_semantic_bundle_rows_from_groups <- function(candidate_groups) {
  dplyr::bind_rows(unname(candidate_groups))
}

.ms_semantic_bundle_escalate_rejections <- function(initial_assessments,
                                                    final_assessments) {
  initial_assessments <- .ms_llm_normalize_assessment_rows(initial_assessments)
  final_assessments <- .ms_llm_normalize_assessment_rows(final_assessments)

  rows <- lapply(seq_len(nrow(final_assessments)), function(i) {
    role <- final_assessments$dictionary_role[[i]]
    pre <- initial_assessments[
      initial_assessments$dictionary_role == role,
      ,
      drop = FALSE
    ]
    if (nrow(pre) == 0L) {
      return(final_assessments[i, , drop = FALSE])
    }
    explored <- .ms_llm_escalate_unresolved_rejection(
      pre[1, , drop = FALSE],
      list(assessment = final_assessments[i, , drop = FALSE])
    )
    explored$assessment
  })
  .ms_llm_normalize_assessment_rows(dplyr::bind_rows(rows))
}

.ms_semantic_bundle_retry_query <- function(role,
                                            assessment,
                                            target,
                                            candidate_rows,
                                            bundle_suggestions,
                                            dict_row,
                                            context_chunks,
                                            config) {
  decision <- .ms_llm_non_empty_string(assessment$llm_decision[[1]] %||% NA_character_)
  if (!identical(decision, "retry_search")) {
    return(list(query = NA_character_, assessment = assessment))
  }

  classification <- .ms_llm_classify_retry_query(
    assessment$llm_retry_query[[1]] %||% NA_character_,
    target$search_query[[1]]
  )
  assessment <- .ms_llm_apply_retry_query_classification(
    assessment,
    classification
  )
  if (identical(
    classification$disposition,
    "duplicate_original_query"
  )) {
    return(list(query = NA_character_, assessment = assessment))
  }

  if (identical(classification$disposition, "use_query")) {
    return(list(query = classification$query, assessment = assessment))
  }

  # Identifier-like retry text follows the established generic-query fallback.
  valid <- character()
  if (identical(classification$disposition, "identifier_like")) {
    record <- .ms_semantic_bundle_fallback_record(
      target = target,
      candidate_rows = candidate_rows,
      bundle_suggestions = bundle_suggestions,
      dict_row = dict_row,
      context_chunks = context_chunks
    )
    generated <- tryCatch(
      .ms_llm_request_with_retries(
        messages = .ms_llm_messages_for_query_exploration(record, assessment),
        config = config
      ),
      error = function(e) NULL
    )
    if (!is.null(generated)) {
      valid <- .ms_llm_validate_exploration_queries(
        generated,
        original_query = classification$original_query,
        max_queries = 1L
      )
    }
  }

  list(
    query = if (length(valid) > 0L) valid[[1]] else NA_character_,
    assessment = assessment
  )
}

.ms_semantic_bundle_retry <- function(targets,
                                      candidate_groups,
                                      initial_assessments,
                                      dict_row,
                                      context_chunks,
                                      config,
                                      search_fn,
                                      sources,
                                      max_per_role,
                                      top_n) {
  bundle_suggestions <- .ms_semantic_bundle_rows_from_groups(candidate_groups)
  assessments <- .ms_llm_normalize_assessment_rows(initial_assessments)
  queries <- stats::setNames(rep(NA_character_, nrow(targets)), targets$dictionary_role)

  for (i in seq_len(nrow(targets))) {
    role <- targets$dictionary_role[[i]]
    assessment_index <- match(role, assessments$dictionary_role)
    if (is.na(assessment_index)) {
      next
    }
    target <- targets[i, , drop = FALSE]
    key <- .ms_semantic_group_key_df(target)[[1]]
    resolved <- .ms_semantic_bundle_retry_query(
      role = role,
      assessment = assessments[assessment_index, , drop = FALSE],
      target = target,
      candidate_rows = candidate_groups[[key]],
      bundle_suggestions = bundle_suggestions,
      dict_row = dict_row,
      context_chunks = context_chunks,
      config = config
    )
    assessments[assessment_index, ] <- resolved$assessment
    queries[[role]] <- resolved$query
  }

  retry_roles <- names(queries)[!is.na(queries) & nzchar(queries)]
  if (length(retry_roles) == 0L) {
    return(list(
      candidate_groups = candidate_groups,
      assessments = .ms_semantic_bundle_escalate_rejections(
        initial_assessments,
        assessments
      )
    ))
  }

  updated_groups <- candidate_groups
  gains <- stats::setNames(integer(length(retry_roles)), retry_roles)
  for (role in retry_roles) {
    target <- targets[targets$dictionary_role == role, , drop = FALSE]
    key <- .ms_semantic_group_key_df(target)[[1]]
    existing <- candidate_groups[[key]]
    extra <- .ms_retrieve_semantic_target_candidates(
      target = target,
      sources = sources,
      max_per_role = max_per_role,
      search_fn = search_fn,
      query = queries[[role]],
      retrieval_pass = 2L
    )
    merged <- .ms_merge_semantic_target_candidates(
      existing_rows = existing,
      extra_rows = extra,
      max_per_role = max_per_role
    )
    existing_ids <- .ms_semantic_bundle_candidate_ids(existing, role)
    merged_ids <- .ms_semantic_bundle_candidate_ids(merged, role)
    gains[[role]] <- sum(!merged_ids %in% existing_ids)
    updated_groups[[key]] <- merged

    assessment_index <- match(role, assessments$dictionary_role)
    assessments[assessment_index, ] <- .ms_llm_add_exploration_metadata(
      assessments[assessment_index, , drop = FALSE],
      used = TRUE,
      queries = queries[[role]],
      candidate_gain = gains[[role]]
    )
  }

  gained_roles <- names(gains)[gains > 0L]
  if (length(gained_roles) == 0L) {
    return(list(
      candidate_groups = candidate_groups,
      assessments = .ms_semantic_bundle_escalate_rejections(
        initial_assessments,
        assessments
      )
    ))
  }

  retry_context <- .ms_semantic_bundle_context_chunks(
    targets,
    lapply(updated_groups, utils::head, n = top_n),
    context_chunks,
    config
  )
  retry_payload <- .ms_semantic_bundle_payload(
    targets,
    lapply(updated_groups, utils::head, n = top_n),
    dict_row,
    retry_context,
    sources
  )
  retry_payload$review_round <- 2L
  retry_payload$previous_assessments <- lapply(seq_len(nrow(assessments)), function(i) {
    as.list(assessments[i, c(
      "dictionary_role",
      "llm_decision",
      "llm_confidence",
      "llm_rationale",
      "llm_retry_query"
    ), drop = FALSE])
  })
  reassessment_result <- tryCatch(
    .ms_llm_request_with_retries(
      messages = .ms_semantic_bundle_messages(retry_payload),
      config = config
    ),
    error = function(e) e
  )
  if (inherits(reassessment_result, "error")) {
    return(list(
      candidate_groups = candidate_groups,
      assessments = .ms_semantic_bundle_escalate_rejections(
        initial_assessments,
        assessments
      )
    ))
  }

  reassessed <- tryCatch(
    .ms_semantic_bundle_response_assessments(
      result = reassessment_result,
      targets = targets,
      candidate_groups = lapply(updated_groups, utils::head, n = top_n),
      bundle_suggestions = .ms_semantic_bundle_rows_from_groups(updated_groups),
      dict_row = dict_row,
      context_chunks = retry_context,
      config = config,
      allow_fallback = FALSE,
      fallback_assessments = assessments
    ),
    error = function(e) e
  )
  if (inherits(reassessed, "error")) {
    return(list(
      candidate_groups = candidate_groups,
      assessments = .ms_semantic_bundle_escalate_rejections(
        initial_assessments,
        assessments
      )
    ))
  }

  for (role in gained_roles) {
    old_index <- match(role, assessments$dictionary_role)
    new_index <- match(role, reassessed$dictionary_role)
    row <- reassessed[new_index, , drop = FALSE]
    row <- .ms_llm_add_exploration_metadata(
      row,
      used = TRUE,
      queries = queries[[role]],
      candidate_gain = gains[[role]]
    )
    assessments[old_index, ] <- row
  }

  list(
    candidate_groups = updated_groups,
    assessments = .ms_semantic_bundle_escalate_rejections(
      initial_assessments,
      assessments
    )
  )
}

.ms_assess_one_semantic_bundle <- function(targets,
                                           suggestions,
                                           dict,
                                           config,
                                           top_n,
                                           context_chunk_pool,
                                           search_fn,
                                           sources,
                                           max_per_role) {
  targets <- targets[
    match(.ms_semantic_bundle_roles(), targets$dictionary_role, nomatch = 0L),
    ,
    drop = FALSE
  ]
  candidate_groups <- .ms_semantic_bundle_candidate_groups(targets, suggestions)
  prompt_candidate_groups <- lapply(
    candidate_groups,
    utils::head,
    n = top_n
  )
  dict_row <- .ms_semantic_bundle_dictionary_row(targets[1, , drop = FALSE], dict)
  context_chunks <- .ms_semantic_bundle_context_chunks(
    targets,
    prompt_candidate_groups,
    context_chunk_pool,
    config
  )
  payload <- .ms_semantic_bundle_payload(
    targets,
    prompt_candidate_groups,
    dict_row,
    context_chunks,
    sources
  )
  result <- tryCatch(
    .ms_llm_request_with_retries(
      messages = .ms_semantic_bundle_messages(payload),
      config = config
    ),
    error = function(e) e
  )

  if (inherits(result, "error")) {
    reason <- .ms_redact_secrets(conditionMessage(result))
    assessments <- purrr::map_dfr(seq_len(nrow(targets)), function(i) {
      target <- targets[i, , drop = FALSE]
      .ms_llm_review_empty_assessment(
        target_row = target,
        config = config,
        error = reason
      )
    })
  } else {
    assessments <- tryCatch(
      .ms_semantic_bundle_response_assessments(
        result = result,
        targets = targets,
        candidate_groups = prompt_candidate_groups,
        bundle_suggestions = suggestions,
        dict_row = dict_row,
        context_chunks = context_chunks,
        config = config
      ),
      error = function(e) {
        reason <- .ms_redact_secrets(conditionMessage(e))
        purrr::map_dfr(seq_len(nrow(targets)), function(i) {
          target <- targets[i, , drop = FALSE]
          key <- .ms_semantic_group_key_df(target)[[1]]
          .ms_semantic_bundle_fallback_assessment(
            target = target,
            candidate_rows = prompt_candidate_groups[[key]],
            bundle_suggestions = suggestions,
            dict_row = dict_row,
            context_chunks = context_chunks,
            config = config,
            reason = reason
          )
        })
      }
    )
  }

  retried <- .ms_semantic_bundle_retry(
    targets = targets,
    candidate_groups = candidate_groups,
    initial_assessments = assessments,
    dict_row = dict_row,
    context_chunks = context_chunks,
    config = config,
    search_fn = search_fn,
    sources = sources,
    max_per_role = max_per_role,
    top_n = top_n
  )
  final_suggestions <- .ms_semantic_bundle_rows_from_groups(
    retried$candidate_groups
  )
  final_assessments <- retried$assessments
  validated <- .ms_semantic_apply_bundle_validators(
    assessments = final_assessments,
    candidate_groups = retried$candidate_groups,
    targets = targets,
    dict_row = dict_row,
    context_chunks = context_chunks
  )
  final_assessments <- validated$assessments

  list(
    suggestions = if (nrow(final_suggestions) > 0L) {
      .ms_semantic_merge_llm_assessments(
        final_suggestions,
        assessments = final_assessments,
        top_n = top_n
      )
    } else {
      final_suggestions
    },
    assessments = .ms_llm_normalize_assessment_rows(final_assessments),
    validator_findings = validated$findings
  )
}

.ms_assess_semantic_bundles <- function(targets,
                                        suggestions,
                                        dict,
                                        config,
                                        top_n,
                                        context_chunk_pool,
                                        search_fn,
                                        sources,
                                        max_per_role) {
  targets <- tibble::as_tibble(targets)
  suggestions <- tibble::as_tibble(suggestions)
  if (nrow(targets) == 0L) {
    return(list(
      suggestions = suggestions[0, , drop = FALSE],
      assessments = .ms_empty_llm_assessments()
    ))
  }

  targets$.ms_bundle_key <- .ms_semantic_bundle_key_df(targets)
  suggestions$.ms_group_key <- if (nrow(suggestions) > 0L) {
    .ms_semantic_group_key_df(suggestions)
  } else {
    character()
  }
  target_keys <- .ms_semantic_group_key_df(targets)
  suggestions <- suggestions[
    suggestions$.ms_group_key %in% target_keys,
    ,
    drop = FALSE
  ]

  target_bundles <- split(targets, targets$.ms_bundle_key)
  results <- lapply(target_bundles, function(bundle_targets) {
    bundle_target_keys <- .ms_semantic_group_key_df(bundle_targets)
    bundle_suggestions <- suggestions[
      suggestions$.ms_group_key %in% bundle_target_keys,
      ,
      drop = FALSE
    ] |>
      dplyr::select(-dplyr::any_of(".ms_group_key"))
    .ms_assess_one_semantic_bundle(
      targets = dplyr::select(bundle_targets, -dplyr::any_of(".ms_bundle_key")),
      suggestions = bundle_suggestions,
      dict = dict,
      config = config,
      top_n = top_n,
      context_chunk_pool = context_chunk_pool,
      search_fn = search_fn,
      sources = sources,
      max_per_role = max_per_role
    )
  })

  assessments <- .ms_llm_normalize_assessment_rows(
    dplyr::bind_rows(purrr::map(results, "assessments"))
  )
  attr(assessments, "semantic_validator_findings") <- dplyr::bind_rows(
    purrr::map(results, "validator_findings")
  )

  list(
    suggestions = dplyr::bind_rows(purrr::map(results, "suggestions")),
    assessments = assessments
  )
}
