# Retrieval keeps `max_per_role` candidates per role on the direct
# `suggest_semantics()` path, and the seeding wrappers keep
# `semantic_max_per_role`, read as a positive whole number. The rule that
# widened both to `llm_top_n` (backlog #57) went with the in-package model call
# (hub item B-329); these pin what was left, so the wrappers' retrieval did not
# change when it went.

eight_candidate_search <- function(query, role, sources) {
  tibble::tibble(
    label = paste(role, "candidate", 1:8),
    iri = paste0("https://example.org/", role, "/c", 1:8),
    source = "smn",
    ontology = "demo",
    role = role,
    match_type = "label_partial",
    definition = paste("Candidate", 1:8, "for", role),
    score = seq(0.9, 0.2, length.out = 8)
  )
}

kept_per_role <- function(dict) {
  suggestions <- attr(dict, "semantic_suggestions")
  as.integer(table(suggestions$dictionary_role))
}

wrapped_dictionary <- function(semantic_max_per_role) {
  with_mocked_bindings(
    find_terms = eight_candidate_search,
    suppressMessages(infer_dictionary(
      data.frame(spawner_count = c(120L, 340L)),
      dataset_id = "d1",
      table_id = "t1",
      seed_semantics = TRUE,
      semantic_sources = "smn",
      semantic_max_per_role = semantic_max_per_role,
      seed_verbose = FALSE
    ))
  )
}

test_that("the direct path keeps max_per_role candidates per role", {
  res <- suppressMessages(suggest_semantics(
    NULL,
    test_spawner_dictionary(),
    sources = "smn",
    search_fn = eight_candidate_search
  ))
  expect_true(all(kept_per_role(res) == 3L))

  res <- suppressMessages(suggest_semantics(
    NULL,
    test_spawner_dictionary(),
    sources = "smn",
    search_fn = eight_candidate_search,
    max_per_role = 6
  ))
  expect_true(all(kept_per_role(res) == 6L))
})

test_that("infer_dictionary() keeps semantic_max_per_role, one at the least", {
  expect_equal(unique(kept_per_role(wrapped_dictionary(3))), 3L)
  expect_equal(unique(kept_per_role(wrapped_dictionary(2.7))), 2L)
  expect_equal(unique(kept_per_role(wrapped_dictionary(0))), 1L)
})
