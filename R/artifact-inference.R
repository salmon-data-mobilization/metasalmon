.ms_infer_resource_dictionary <- function(resources,
                                          guess_types,
                                          dataset_id,
                                          semantic_sources,
                                          semantic_max_per_role,
                                          seed_verbose) {
  dict_parts <- lapply(names(resources), function(tab_id) {
    infer_dictionary(
      df = resources[[tab_id]],
      guess_types = guess_types,
      dataset_id = dataset_id,
      table_id = tab_id,
      seed_semantics = FALSE,
      semantic_sources = semantic_sources,
      semantic_max_per_role = semantic_max_per_role,
      seed_verbose = seed_verbose,
      seed_codes = NULL,
      seed_table_meta = NULL,
      seed_dataset_meta = NULL
    )
  })

  dplyr::bind_rows(dict_parts)
}

# A NuSEDS prefill has provenance only when this call changed a blank code IRI.
# The code keys are the write-back address used by semantic suggestions; keeping
# the prefill IRI separately lets review show alternatives without changing the
# final value already written into codes.csv.
.ms_crosswalk_code_prefills <- function(before, after) {
  keys <- c("dataset_id", "table_id", "column_name", "code_value")
  empty <- tibble::tibble(
    dataset_id = character(), table_id = character(), column_name = character(),
    code_value = character(), prefill_iri = character()
  )
  if (is.null(before) || is.null(after) || nrow(after) == 0L) {
    return(empty)
  }

  old <- trimws(as.character(before$term_iri))
  new <- trimws(as.character(after$term_iri))
  filled <- (is.na(old) | !nzchar(old)) & !is.na(new) & nzchar(new)
  if (!any(filled)) {
    return(empty)
  }

  out <- tibble::as_tibble(after[filled, keys, drop = FALSE])
  out$prefill_iri <- new[filled]
  out
}

.ms_crosswalk_code_keys <- function(rows) {
  keys <- c("dataset_id", "table_id", "column_name", "code_value")
  do.call(paste, c(lapply(rows[keys], function(value) {
    text <- as.character(value)
    text[is.na(text)] <- ""
    text
  }), sep = "\r"))
}

# Stamp only candidates for rows this package itself filled. These two columns
# travel in semantic_suggestions.csv, outside the frozen target and assessment
# rows, so a later review can distinguish a crosswalk prefill from a caller's
# equally final IRI.
.ms_mark_crosswalk_suggestions <- function(suggestions, prefills) {
  if (is.null(suggestions) || nrow(suggestions) == 0L ||
      is.null(prefills) || nrow(prefills) == 0L) {
    return(suggestions)
  }

  code_slot <- as.character(suggestions$target_sdp_file) %in% "codes.csv" &
    as.character(suggestions$target_sdp_field) %in% "term_iri"
  if (!any(code_slot)) {
    return(suggestions)
  }
  keys <- .ms_crosswalk_code_keys(suggestions)
  matched <- match(keys, .ms_crosswalk_code_keys(prefills))
  matched[!code_slot] <- NA_integer_
  if (all(is.na(matched))) {
    return(suggestions)
  }

  suggestions$prefill_origin <- ifelse(is.na(matched), NA_character_, "nuseds_crosswalk")
  suggestions$prefill_iri <- prefills$prefill_iri[matched]
  suggestions
}

.ms_infer_resource_artifact_context <- function(resources,
                                                dataset_id,
                                                seed_codes = NULL,
                                                seed_table_meta = NULL,
                                                seed_dataset_meta = NULL,
                                                mode = c("dictionary", "package"),
                                                dict = NULL,
                                                semantic_code_scope = c("factor", "all", "none")) {
  mode <- match.arg(mode)

  if (identical(mode, "dictionary")) {
    inferred_table_meta <- infer_table_metadata_from_resources(resources, dataset_id = dataset_id)
    inferred_codes <- infer_codes_from_resources(resources, dataset_id = dataset_id)
    inferred_dataset_meta <- infer_dataset_metadata_from_resources(resources, dataset_id = dataset_id)

    table_meta <- if (!is.null(seed_table_meta)) seed_table_meta else inferred_table_meta
    codes <- if (!is.null(seed_codes)) seed_codes else inferred_codes
    dataset_meta <- if (!is.null(seed_dataset_meta)) seed_dataset_meta else inferred_dataset_meta

    # NOTE: the `inferred_*` slots deliberately carry the EFFECTIVE (seed-or-inferred)
    # values, not the pure-inferred locals above. These feed the public
    # `attr(dict, "inferred_*")` contract that callers/tests rely on (preserved from
    # pre-refactor behaviour). Do not "fix" them to the pure-inferred locals — that
    # would change the observable attribute when a seed_* is supplied.
    return(list(
      table_meta = table_meta,
      codes = codes,
      dataset_meta = dataset_meta,
      semantic_codes = codes,
      inferred_table_meta = table_meta,
      inferred_codes = codes,
      inferred_dataset_meta = dataset_meta,
      inferred_resources = names(resources)
    ))
  }

  table_meta <- if (is.null(seed_table_meta) || isTRUE(seed_table_meta)) {
    infer_table_metadata_from_resources(resources, dataset_id = dataset_id)
  } else {
    .ms_normalize_table_meta(seed_table_meta)
  }

  codes <- if (is.null(seed_codes)) {
    infer_codes_from_resources(resources, dataset_id = dataset_id)
  } else {
    .ms_normalize_codes(seed_codes)
  }
  codes_before_prefill <- codes
  if (!is.null(dict)) {
    codes <- .ms_prefill_legacy_estimate_method_code_terms(codes, dict = dict)
    codes <- .ms_prefill_legacy_estimate_classification_code_terms(codes, dict = dict)
    codes <- .ms_prefill_legacy_enumeration_method_code_terms(codes, dict = dict)
  }
  crosswalk_prefills <- .ms_crosswalk_code_prefills(codes_before_prefill, codes)

  dataset_meta <- if (is.null(seed_dataset_meta) || isTRUE(seed_dataset_meta)) {
    infer_dataset_metadata_from_resources(resources, dataset_id = dataset_id)
  } else {
    .ms_normalize_dataset_meta(seed_dataset_meta)
  }

  semantic_code_scope <- match.arg(semantic_code_scope)
  semantic_codes <- .ms_select_semantic_seed_codes(
    codes = codes,
    resources = resources,
    scope = semantic_code_scope,
    dataset_id = dataset_id
  )
  if (nrow(semantic_codes) > 0L && nrow(crosswalk_prefills) > 0L) {
    # Only the temporary discovery input is blanked. The package's codes keep
    # their final crosswalk IRIs; explicit seed_codes terms never enter this set.
    matched <- match(
      .ms_crosswalk_code_keys(semantic_codes),
      .ms_crosswalk_code_keys(crosswalk_prefills)
    )
    semantic_codes$term_iri[!is.na(matched)] <- NA_character_
  }

  list(
    table_meta = table_meta,
    codes = codes,
    dataset_meta = dataset_meta,
    semantic_codes = semantic_codes,
    crosswalk_prefills = crosswalk_prefills,
    inferred_table_meta = table_meta,
    inferred_codes = codes,
    inferred_dataset_meta = dataset_meta,
    inferred_resources = names(resources)
  )
}
