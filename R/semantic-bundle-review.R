.ms_semantic_bundle_roles <- function() {
  # `method` stays: codes-scope targets still search shared-vocabulary
  # procedures for codes.csv term_iri. Only the dictionary slot is gone.
  c(
    "variable", "property", "entity", "unit", "constraint",
    "statistical_modifier", "method"
  )
}

.ms_semantic_bundle_slot_fields <- function() {
  c(
    variable = "term_iri",
    property = "property_iri",
    entity = "entity_iri",
    unit = "unit_iri",
    constraint = "constraint_iri",
    statistical_modifier = "statistical_modifier_iri"
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
