# Retrieval and source-policy tests for semantic suggestions. They lived beside
# the in-package bundle review, whose model-path tests went with it (hub item
# B-329); the retry half of the source-policy cases now runs through the
# ingester in test-semantic-review-packet.R.

theme_a_measurement_dictionary <- function() {
  test_spawner_dictionary(
    column_description = "Estimated natural-origin spawner abundance"
  )
}

theme_a_candidate <- function(role) {
  tibble::tibble(
    label = paste("Candidate", role),
    iri = paste0("https://example.org/", role),
    source = "smn",
    ontology = "demo",
    role = role,
    role_hints = role,
    match_type = "label",
    definition = paste("A", role, "candidate"),
    score = 0.9
  )
}

test_that("retrieval preserves distinct blank-IRI evidence from one source", {
  target <- tibble::tibble(
    dictionary_role = "property",
    search_role = "property",
    search_query = "catch abundance"
  )
  candidates <- metasalmon:::.ms_retrieve_semantic_target_candidates(
    target = target,
    sources = metasalmon:::.ms_semantic_source_policy("smn"),
    max_per_role = 3L,
    search_fn = function(query, role, sources) {
      tibble::tibble(
        label = c("Catch abundance", "Observed catch abundance"),
        iri = c(NA_character_, NA_character_),
        source = c("smn", "smn"),
        ontology = c("demo", "demo"),
        role = c("property", "property"),
        definition = c(
          "Abundance of fish in a catch.",
          "Observed abundance associated with a catch."
        ),
        score = c(0.9, 0.8)
      )
    }
  )

  expect_equal(nrow(candidates), 2L)
  expect_length(unique(
    metasalmon:::.ms_semantic_candidate_identity(candidates, "property")
  ), 2L)
})

test_that("explicit source allowlists filter adapter leakage during initial retrieval", {
  out <- suggest_semantics(
    df = tibble::tibble(spawner_count = c(10L, 12L)),
    dict = theme_a_measurement_dictionary(),
    sources = "smn",
    max_per_role = 2L,
    search_fn = function(query, role, sources) {
      leaked <- theme_a_candidate(role)
      leaked$label <- paste("Leaked QUDT", role)
      leaked$iri <- paste0("https://qudt.org/vocab/", role)
      leaked$source <- "qudt"
      dplyr::bind_rows(theme_a_candidate(role), leaked)
    }
  )

  suggestions <- attr(out, "semantic_suggestions")
  expect_true(nrow(suggestions) > 0L)
  expect_setequal(suggestions$source, "smn")
})

test_that("semantic source policy distinguishes omitted and explicit sources", {
  omitted_sources <- list()
  suggest_semantics(
    df = tibble::tibble(spawner_count = c(10L, 12L)),
    dict = theme_a_measurement_dictionary(),
    max_per_role = 1L,
    search_fn = function(query, role, sources) {
      omitted_sources[[role]] <<- sources
      tibble::tibble()
    }
  )

  expect_identical(omitted_sources$unit, sources_for_role("unit"))
  expect_identical(omitted_sources$entity, sources_for_role("entity"))
  expect_identical(omitted_sources$constraint, sources_for_role("constraint"))
  # The statistical_modifier role has its own role-aware default sources even
  # though this non-aggregated fixture emits no such target.
  expect_identical(sources_for_role("statistical_modifier"), c("smn", "ols"))

  explicit_sources <- list()
  suggest_semantics(
    df = tibble::tibble(spawner_count = c(10L, 12L)),
    dict = theme_a_measurement_dictionary(),
    sources = "smn",
    max_per_role = 1L,
    search_fn = function(query, role, sources) {
      explicit_sources[[role]] <<- sources
      tibble::tibble()
    }
  )

  expect_true(length(explicit_sources) > 0L)
  expect_true(all(vapply(
    explicit_sources,
    identical,
    logical(1),
    y = "smn"
  )))
})

test_that("an explicit empty source allowlist performs no retrieval", {
  search_calls <- 0L

  out <- suggest_semantics(
    df = tibble::tibble(spawner_count = c(10L, 12L)),
    dict = theme_a_measurement_dictionary(),
    sources = character(),
    search_fn = function(query, role, sources) {
      search_calls <<- search_calls + 1L
      stop("search must not run for an explicit empty allowlist")
    }
  )

  expect_equal(search_calls, 0L)
  expect_equal(nrow(attr(out, "semantic_suggestions")), 0L)
})
