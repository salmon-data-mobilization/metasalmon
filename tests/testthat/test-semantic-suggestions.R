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
