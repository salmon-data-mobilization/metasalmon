test_that("semantic suggestion module owns target and candidate row shape", {
  suggestions <- tibble::tibble(
    dataset_id = c("d1", "d1", "d1"),
    table_id = c("t1", "t1", "t1"),
    column_name = c("spawner_count", "spawner_count", "run_type"),
    dictionary_role = c("variable", "property", "variable"),
    target_scope = c("column", "column", "column"),
    target_sdp_file = c("column_dictionary.csv", "column_dictionary.csv", "column_dictionary.csv"),
    target_sdp_field = c("term_iri", "property_iri", "term_iri"),
    target_row_key = c("d1/t1/spawner_count", "d1/t1/spawner_count", "d1/t1/run_type"),
    target_label = c("Spawner count", "Spawner count", "Run type"),
    target_description = c("Spawner abundance", "Spawner abundance", "Run classification"),
    search_query = c("spawner abundance", "abundance", "run type"),
    label = c("Spawner abundance", "Abundance", "Run type"),
    iri = c("https://example.org/spawner-abundance", "https://example.org/abundance", "https://example.org/run-type"),
    source = c("smn", "smn", "smn"),
    ontology = c("demo", "demo", "demo"),
    definition = c("Variable", "Property", "Attribute")
  )
  dict_row <- test_spawner_dictionary()

  target <- metasalmon:::.ms_semantic_target_from_candidate_rows(suggestions, dict_row = dict_row)
  filtered <- metasalmon:::.ms_semantic_filter_column_term_suggestions(suggestions, dict_row)

  expect_equal(names(target), metasalmon:::.ms_semantic_target_cols())
  expect_equal(target$target_sdp_field[[1]], "term_iri")
  expect_equal(nrow(filtered), 1L)
  expect_equal(filtered$dictionary_role[[1]], "variable")
  expect_equal(filtered$target_sdp_field[[1]], "term_iri")
})

test_that("semantic target row contract preserves column order", {
  expected_cols <- c(
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

  target <- metasalmon:::.ms_semantic_target_from_candidate_rows(
    tibble::tibble(
      dataset_id = "d1",
      table_id = "t1",
      column_name = "spawner_count",
      code_value = NA_character_,
      dictionary_role = "variable",
      search_role = "variable",
      target_scope = "column",
      target_sdp_file = "column_dictionary.csv",
      target_sdp_field = "term_iri",
      target_row_key = "d1/t1/spawner_count",
      target_label = "Spawner count",
      target_description = "Spawner abundance",
      search_query = "spawner abundance",
      target_query_basis = NA_character_,
      target_query_context = NA_character_,
      column_label = "Spawner count",
      column_description = "Spawner abundance",
      code_label = NA_character_,
      code_description = NA_character_,
      label = "Spawner abundance",
      iri = "https://example.org/spawner-abundance",
      source = "smn",
      ontology = "demo",
      definition = "Variable"
    )
  )

  expect_equal(metasalmon:::.ms_semantic_target_cols(), expected_cols)
  expect_equal(names(target), expected_cols)
})

test_that("semantic target discovery emits normalized rows across all SDP scopes", {
  dict <- test_count_dictionary(
    dataset_id = "d1",
    table_id = "survey",
    column_description = "Natural adult spawner count",
    value_type = "integer"
  )
  codes <- tibble::tibble(
    dataset_id = "d1",
    table_id = "survey",
    column_name = "count",
    code_value = "visual",
    code_label = "Visual",
    code_description = "Visual survey method",
    term_iri = NA_character_
  )
  table_meta <- tibble::tibble(
    dataset_id = "d1",
    table_id = "survey",
    table_label = "Survey observations",
    description = "Spawner survey observations",
    observation_unit = "spawner population",
    observation_unit_iri = NA_character_
  )
  dataset_meta <- tibble::tibble(
    dataset_id = "d1",
    title = "Spawner survey",
    description = "Annual spawner survey dataset",
    keywords = NA_character_
  )

  targets <- metasalmon:::.ms_semantic_discover_targets(
    dict = dict,
    codes = codes,
    table_meta = table_meta,
    dataset_meta = dataset_meta,
    default_df = tibble::tibble(count = c(10L, 20L))
  )

  expect_equal(names(targets), metasalmon:::.ms_semantic_target_cols())
  expect_setequal(unique(targets$target_scope), c("column", "code", "table", "dataset"))
  # Dep-free guard that every SDP destination file gets targets (the equivalent
  # end-to-end assertion in test-llm-semantic-helpers.R is gated behind optional
  # pdftools/readxl/openxlsx and silently skips without them).
  expect_setequal(
    unique(targets$target_sdp_file),
    c("column_dictionary.csv", "codes.csv", "tables.csv", "dataset.csv")
  )
  expect_equal(nrow(targets[targets$target_scope == "column", , drop = FALSE]), 6L)
  expect_equal(nrow(targets[targets$target_scope == "code", , drop = FALSE]), 3L)
  expect_setequal(
    targets$dictionary_role[targets$target_scope == "code"],
    c("constraint", "entity", "method")
  )
  expect_equal(
    targets$target_query_basis[targets$target_scope == "table"],
    "observation_unit"
  )
  expect_equal(
    targets$target_sdp_file[targets$target_scope == "dataset"],
    "dataset.csv"
  )
})

test_that("semantic target discovery preserves paired value/unit resource context", {
  dict <- test_dictionary(
    dataset_id = "d1",
    table_id = "survey",
    column_name = "sampleSizeValue",
    column_label = "Sample size",
    column_description = "Sample area",
    value_type = "number"
  )
  resource_lookup <- list(
    survey = tibble::tibble(
      sampleSizeValue = c(2046.33, 131340.85),
      sampleSizeUnit = c("square metre", "square metre")
    )
  )

  targets <- metasalmon:::.ms_semantic_discover_targets(
    dict = dict,
    codes = tibble::tibble(),
    table_meta = tibble::tibble(),
    dataset_meta = tibble::tibble(),
    resource_lookup = resource_lookup
  )

  unit_target <- targets[targets$target_sdp_field == "unit_iri", , drop = FALSE]
  expect_equal(nrow(unit_target), 1L)
  expect_equal(unit_target$search_query, "square meter")
})

test_that("LLM assessment row contract preserves column order and empty/success symmetry", {
  expected_cols <- c(
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
    "llm_error"
  )
  target <- metasalmon:::.ms_semantic_target_from_candidate_rows(
    tibble::tibble(
      dataset_id = "d1",
      table_id = "t1",
      column_name = "spawner_count",
      code_value = NA_character_,
      dictionary_role = "variable",
      target_scope = "column",
      target_sdp_file = "column_dictionary.csv",
      target_sdp_field = "term_iri",
      search_query = "spawner abundance",
      label = "Spawner abundance",
      iri = "https://example.org/spawner-abundance",
      source = "smn",
      ontology = "demo",
      definition = "Variable"
    )
  )
  # Two candidates so the success builder must resolve the SELECTED one (index 2),
  # not the first candidate or the target row — guards against an off-by-one that a
  # names()-only check would miss.
  candidates <- tibble::tibble(
    label = c("Spawner abundance", "Spawner count"),
    iri = c(
      "https://example.org/spawner-abundance",
      "https://example.org/spawner-count"
    ),
    source = c("smn", "smn"),
    ontology = c("demo", "demo"),
    definition = c("Variable one", "Variable two")
  )
  config <- list(provider = "openrouter", model = "openrouter/free")
  validated <- list(
    decision = "accept",
    confidence = 0.9,
    selected_candidate_index = 2L,
    rationale = "Good fit",
    missing_context = NA_character_,
    bundle_summary = NA_character_,
    retry_query = NA_character_,
    suggested_label = NA_character_,
    suggested_definition = NA_character_,
    suggested_namespace = NA_character_
  )

  empty <- metasalmon:::.ms_llm_review_empty_assessment(target, config)
  success <- metasalmon:::.ms_llm_review_success_assessment(
    target,
    candidates,
    tibble::tibble(source = "context.md"),
    config,
    validated
  )

  expect_equal(names(empty), expected_cols)
  expect_equal(names(success), expected_cols)
  # Value-level contract: the success row resolves the selected candidate (#2).
  expect_equal(success$llm_decision, "accept")
  expect_equal(success$llm_selected_candidate_index, 2L)
  expect_equal(success$llm_selected_iri, "https://example.org/spawner-count")
  expect_equal(success$llm_selected_label, "Spawner count")
  expect_equal(success$llm_context_sources, "context.md")
  # Empty assessment carries no selection.
  expect_true(is.na(empty$llm_selected_iri))
})

test_that("LLM review adapter validates chat-style JSON responses", {
  response <- list(
    content = '{"decision":"accept","selected_candidate_index":1,"confidence":0.91,"rationale":"Fits the target.","missing_context":""}',
    data = NULL
  )
  candidates <- tibble::tibble(
    label = "Spawner abundance",
    iri = "https://example.org/spawner-abundance"
  )

  validated <- metasalmon:::.ms_llm_review_validate_assessment(response, candidates)

  expect_equal(validated$decision, "accept")
  expect_equal(validated$selected_candidate_index, 1L)
  expect_equal(validated$confidence, 0.91)
})

test_that("LLM review adapter reports malformed wrapped content with a snippet", {
  response <- list(
    content = '{"decision":',
    data = NULL
  )
  candidates <- tibble::tibble(
    label = "Spawner abundance",
    iri = "https://example.org/spawner-abundance"
  )

  err <- tryCatch(
    metasalmon:::.ms_llm_review_validate_assessment(
      response,
      candidates,
      null_message = "Chat adapter did not return a usable JSON object for decomposition review."
    ),
    error = identity
  )

  expect_s3_class(err, "error")
  expect_match(conditionMessage(err), "Chat adapter did not return", fixed = TRUE)
  expect_match(conditionMessage(err), "Response content snippet", fixed = TRUE)
  expect_match(conditionMessage(err), "decision", fixed = TRUE)
})

test_that("LLM review adapter prefers parsed data over malformed wrapped content", {
  response <- list(
    content = '{"decision":',
    data = list(
      decision = "review",
      selected_candidate_index = NULL,
      confidence = 0.44,
      rationale = "Parsed data should win.",
      missing_context = ""
    )
  )
  candidates <- tibble::tibble(
    label = "Spawner abundance",
    iri = "https://example.org/spawner-abundance"
  )

  validated <- metasalmon:::.ms_llm_review_validate_assessment(response, candidates)

  expect_equal(validated$decision, "review")
  expect_equal(validated$confidence, 0.44)
  expect_true(is.na(validated$selected_candidate_index))
})
