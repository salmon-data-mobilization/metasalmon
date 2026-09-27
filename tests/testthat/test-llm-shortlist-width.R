# `llm_top_n` is how many retrieved candidates the LLM is shown per target,
# and the LLM can only be shown what retrieval kept. Every wrapper widens
# retrieval to `max(semantic_max_per_role, llm_top_n)` through
# `.ms_llm_review_plan()`, but the direct `suggest_semantics()` path kept
# `max_per_role` candidates per role, so its documented `llm_top_n` default of
# 5 silently became its `max_per_role` default of 3 (backlog #57).

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

# Records, for each LLM request, the distinct `variable` candidates it names.
variable_shortlist_recorder <- function() {
  seen <- list()
  request <- function(messages, config) {
    body <- paste(vapply(messages, function(m) m$content, character(1)), collapse = "\n")
    iris <- regmatches(body, gregexpr("https://example\\.org/variable/c[0-9]+", body))[[1]]
    seen[[length(seen) + 1L]] <<- unique(iris)
    list(
      decision = "review",
      selected_candidate_index = NA,
      confidence = 0.2,
      rationale = "Shortlist-width stub.",
      missing_context = ""
    )
  }
  list(request = request, seen = function() seen)
}

kept_per_role <- function(dict) {
  suggestions <- attr(dict, "semantic_suggestions")
  as.integer(table(suggestions$dictionary_role))
}

direct_review <- function(recorder, ...) {
  suppressMessages(suggest_semantics(
    NULL,
    test_spawner_dictionary(),
    sources = "smn",
    search_fn = eight_candidate_search,
    llm_assess = TRUE,
    llm_provider = "openai",
    llm_model = "stub-model",
    llm_api_key = "dummy-key",
    llm_request_fn = recorder$request,
    ...
  ))
}

test_that("llm_top_n widens the shortlist on the direct suggest_semantics() path", {
  recorder <- variable_shortlist_recorder()
  res <- direct_review(recorder)

  # Defaults: max_per_role = 3, llm_top_n = 5. Five are kept per role ...
  expect_true(all(kept_per_role(res) == 5L))
  # ... and the first review request shows the LLM all five.
  first <- recorder$seen()[[1]]
  expect_setequal(first, paste0("https://example.org/variable/c", 1:5))
})

test_that("a larger max_per_role still sets how many suggestions are kept", {
  recorder <- variable_shortlist_recorder()
  res <- direct_review(recorder, max_per_role = 6, llm_top_n = 2)

  expect_true(all(kept_per_role(res) == 6L))
  expect_setequal(recorder$seen()[[1]], paste0("https://example.org/variable/c", 1:2))
})

test_that("without llm_assess the shortlist stays at max_per_role", {
  res <- suppressMessages(suggest_semantics(
    NULL,
    test_spawner_dictionary(),
    sources = "smn",
    search_fn = eight_candidate_search
  ))

  expect_true(all(kept_per_role(res) == 3L))
})

test_that("the direct path and infer_dictionary() widen by the same rule", {
  recorder <- variable_shortlist_recorder()
  direct <- direct_review(recorder, max_per_role = 3, llm_top_n = 5)

  wrapper_recorder <- variable_shortlist_recorder()
  wrapped <- with_mocked_bindings(
    find_terms = eight_candidate_search,
    suppressMessages(infer_dictionary(
      data.frame(spawner_count = c(120L, 340L)),
      dataset_id = "d1",
      table_id = "t1",
      seed_semantics = TRUE,
      semantic_sources = "smn",
      semantic_max_per_role = 3,
      seed_verbose = FALSE,
      llm_assess = TRUE,
      llm_provider = "openai",
      llm_model = "stub-model",
      llm_api_key = "dummy-key",
      llm_top_n = 5,
      llm_request_fn = wrapper_recorder$request
    ))
  )

  expect_equal(unique(kept_per_role(direct)), 5L)
  expect_equal(unique(kept_per_role(wrapped)), unique(kept_per_role(direct)))
  expect_equal(
    length(wrapper_recorder$seen()[[1]]),
    length(recorder$seen()[[1]])
  )
})
