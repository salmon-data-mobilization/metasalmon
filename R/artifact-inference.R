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
  if (!is.null(dict)) {
    codes <- .ms_prefill_legacy_estimate_method_code_terms(codes, dict = dict)
  }

  dataset_meta <- if (is.null(seed_dataset_meta) || isTRUE(seed_dataset_meta)) {
    infer_dataset_metadata_from_resources(resources, dataset_id = dataset_id)
  } else {
    .ms_normalize_dataset_meta(seed_dataset_meta)
  }

  semantic_code_scope <- match.arg(semantic_code_scope)
  semantic_codes <- .ms_select_semantic_seed_codes(
    codes = codes,
    resources = resources,
    scope = semantic_code_scope
  )

  list(
    table_meta = table_meta,
    codes = codes,
    dataset_meta = dataset_meta,
    semantic_codes = semantic_codes,
    inferred_table_meta = table_meta,
    inferred_codes = codes,
    inferred_dataset_meta = dataset_meta,
    inferred_resources = names(resources)
  )
}
