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

theme_a_bundle_response <- function(roles = metasalmon:::.ms_semantic_bundle_roles()) {
  list(
    bundle_summary = "Spawner abundance for natural-origin fish.",
    assessments = lapply(roles, function(role) {
      accepted <- role %in% c("variable", "property", "entity", "unit")
      list(
        dictionary_role = role,
        decision = if (accepted) "accept" else "review",
        selected_candidate_id = if (accepted) {
          paste0("smn::https://example.org/", role)
        } else {
          NULL
        },
        confidence = if (accepted) 0.9 else 0.55,
        rationale = if (accepted) "Candidate fits this slot." else "Human review is required.",
        missing_context = "",
        retry_query = NULL,
        suggested_label = NULL,
        suggested_definition = NULL,
        suggested_namespace = NULL
      )
    })
  )
}

theme_a_bundle_message_payload <- function(messages) {
  content <- messages[[2]]$content
  content <- sub("^Semantic bundle payload:\\s*", "", content)
  content <- sub("\\n\\nReturn JSON only\\.$", "", content)
  jsonlite::fromJSON(content, simplifyVector = FALSE)
}

test_that("measurement semantics use one bundle request with per-slot assessments", {
  request_calls <- 0L
  out <- suggest_semantics(
    df = tibble::tibble(spawner_count = c(10L, 12L)),
    dict = theme_a_measurement_dictionary(),
    sources = "smn",
    max_per_role = 1L,
    search_fn = function(query, role, sources) theme_a_candidate(role),
    llm_assess = TRUE,
    llm_provider = "openrouter",
    llm_model = "openai/gpt-5.4-mini",
    llm_api_key = "dummy",
    llm_request_fn = function(messages, config) {
      request_calls <<- request_calls + 1L
      expect_match(messages[[1]]$content, "whole measurement-column", fixed = TRUE)
      expect_match(messages[[1]]$content, "native ontology type", fixed = TRUE)
      expect_false(grepl("Treat the variable as a SKOS", messages[[1]]$content, fixed = TRUE))
      theme_a_bundle_response()
    }
  )

  suggestions <- attr(out, "semantic_suggestions")
  assessments <- attr(out, "semantic_llm_assessments")

  expect_equal(request_calls, 1L)
  expect_equal(nrow(assessments), 6L)
  expect_equal(assessments$dictionary_role, metasalmon:::.ms_semantic_bundle_roles())
  expect_equal(names(assessments), metasalmon:::.ms_llm_assessment_cols())
  expect_setequal(
    suggestions$dictionary_role[suggestions$llm_selected],
    c("variable", "property", "entity", "unit")
  )
  expect_false(any(
    suggestions$llm_selected &
      suggestions$dictionary_role %in% c("constraint", "method")
  ))
})

test_that("prompt top_n does not truncate the public deterministic shortlist", {
  three_candidates <- function(role) {
    dplyr::bind_rows(lapply(seq_len(3L), function(index) {
      candidate <- theme_a_candidate(role)
      candidate$label <- paste(candidate$label, index)
      candidate$iri <- if (index == 1L) {
        paste0("https://example.org/", role)
      } else {
        paste0("https://example.org/", role, "-", index)
      }
      candidate$score <- 1 - index / 10
      candidate
    }))
  }

  out <- suggest_semantics(
    df = tibble::tibble(spawner_count = c(10L, 12L)),
    dict = theme_a_measurement_dictionary(),
    sources = "smn",
    max_per_role = 3L,
    search_fn = function(query, role, sources) three_candidates(role),
    llm_assess = TRUE,
    llm_provider = "openrouter",
    llm_model = "openai/gpt-5.4-mini",
    llm_api_key = "dummy",
    llm_top_n = 1L,
    llm_request_fn = function(messages, config) theme_a_bundle_response()
  )

  suggestions <- attr(out, "semantic_suggestions")

  expect_equal(nrow(suggestions), 18L)
  expect_true(all(table(suggestions$dictionary_role) == 3L))
  expect_equal(sum(suggestions$llm_selected), 4L)
})

test_that("zero-candidate measurement targets remain assessable without placeholder suggestions", {
  request_calls <- 0L
  out <- suggest_semantics(
    df = tibble::tibble(spawner_count = c(10L, 12L)),
    dict = theme_a_measurement_dictionary(),
    sources = "smn",
    search_fn = function(query, role, sources) tibble::tibble(),
    llm_assess = TRUE,
    llm_provider = "openrouter",
    llm_model = "openai/gpt-5.4-mini",
    llm_api_key = "dummy",
    llm_request_fn = function(messages, config) {
      request_calls <<- request_calls + 1L
      response <- theme_a_bundle_response()
      response$assessments <- lapply(response$assessments, function(item) {
        item$decision <- "request_new_term"
        item$selected_candidate_id <- NULL
        item$suggested_label <- paste("Proposed", item$dictionary_role)
        item$suggested_definition <- paste("A proposed", item$dictionary_role, "concept.")
        item$suggested_namespace <- "smn"
        item
      })
      response
    }
  )

  expect_equal(request_calls, 1L)
  expect_equal(nrow(attr(out, "semantic_suggestions")), 0L)
  expect_equal(nrow(attr(out, "semantic_llm_assessments")), 6L)
  expect_true(all(
    attr(out, "semantic_llm_assessments")$llm_decision == "request_new_term"
  ))
})

test_that("a provider outage preserves an empty deterministic shortlist", {
  request_calls <- 0L
  out <- NULL
  expect_warning(
    out <- suggest_semantics(
      df = tibble::tibble(spawner_count = c(10L, 12L)),
      dict = theme_a_measurement_dictionary(),
      sources = "smn",
      search_fn = function(query, role, sources) tibble::tibble(),
      llm_assess = TRUE,
      llm_provider = "openrouter",
      llm_model = "openai/gpt-5.4-mini",
      llm_api_key = "dummy",
      llm_request_fn = function(messages, config) {
        request_calls <<- request_calls + 1L
        stop("provider unavailable")
      }
    ),
    "unchanged empty semantic shortlist",
    fixed = TRUE
  )

  suggestions <- attr(out, "semantic_suggestions")
  assessments <- attr(out, "semantic_llm_assessments")

  expect_equal(nrow(suggestions), 0L)
  expect_equal(nrow(assessments), 6L)
  expect_equal(request_calls, 1L)
  expect_identical(names(assessments), metasalmon:::.ms_llm_assessment_cols())
  expect_true(all(!is.na(assessments$llm_error)))
  expect_true(all(is.na(assessments$llm_decision)))
})

test_that("a missing bundle slot falls back only that slot", {
  request_calls <- 0L
  out <- suggest_semantics(
    df = tibble::tibble(spawner_count = c(10L, 12L)),
    dict = theme_a_measurement_dictionary(),
    sources = "smn",
    max_per_role = 1L,
    search_fn = function(query, role, sources) theme_a_candidate(role),
    llm_assess = TRUE,
    llm_provider = "openrouter",
    llm_model = "openai/gpt-5.4-mini",
    llm_api_key = "dummy",
    llm_request_fn = function(messages, config) {
      request_calls <<- request_calls + 1L
      if (grepl("Semantic bundle payload:", messages[[2]]$content, fixed = TRUE)) {
        return(theme_a_bundle_response(roles = setdiff(
          metasalmon:::.ms_semantic_bundle_roles(),
          "method"
        )))
      }
      list(
        decision = "review",
        selected_candidate_index = NULL,
        confidence = 0.4,
        rationale = "Fallback reviewed the method slot.",
        missing_context = ""
      )
    }
  )

  assessments <- attr(out, "semantic_llm_assessments")

  expect_equal(request_calls, 2L)
  expect_equal(nrow(assessments), 6L)
  expect_match(
    assessments$llm_rationale[assessments$dictionary_role == "method"],
    "Bundle response fallback",
    fixed = TRUE
  )
  expect_false(any(
    grepl(
      "Bundle response fallback",
      assessments$llm_rationale[assessments$dictionary_role != "method"],
      fixed = TRUE
    )
  ))
})

test_that("a non-accept slot with a selected ID falls back and cannot prefill", {
  request_calls <- 0L
  out <- suggest_semantics(
    df = tibble::tibble(spawner_count = c(10L, 12L)),
    dict = theme_a_measurement_dictionary(),
    sources = "smn",
    max_per_role = 1L,
    search_fn = function(query, role, sources) theme_a_candidate(role),
    llm_assess = TRUE,
    llm_provider = "openrouter",
    llm_model = "openai/gpt-5.4-mini",
    llm_api_key = "dummy",
    llm_request_fn = function(messages, config) {
      request_calls <<- request_calls + 1L
      if (request_calls == 1L) {
        response <- theme_a_bundle_response()
        roles <- vapply(
          response$assessments,
          `[[`,
          character(1),
          "dictionary_role"
        )
        property <- match("property", roles)
        response$assessments[[property]]$decision <- "review"
        response$assessments[[property]]$selected_candidate_id <-
          "smn::https://example.org/property"
        return(response)
      }
      list(
        decision = "review",
        selected_candidate_index = NULL,
        confidence = 0.4,
        rationale = "Fallback rejected the malformed property selection.",
        missing_context = ""
      )
    }
  )

  suggestions <- attr(out, "semantic_suggestions")
  assessments <- attr(out, "semantic_llm_assessments")
  property <- assessments[
    assessments$dictionary_role == "property",
    ,
    drop = FALSE
  ]

  expect_equal(request_calls, 2L)
  expect_equal(property$llm_decision, "review")
  expect_true(is.na(property$llm_selected_candidate_index))
  expect_true(is.na(property$llm_selected_iri))
  expect_match(property$llm_rationale, "Bundle response fallback", fixed = TRUE)
  expect_false(any(
    suggestions$dictionary_role == "property" & suggestions$llm_selected
  ))
})

test_that("bundle retries retrieve affected slots once and reassess once", {
  request_calls <- 0L
  search_calls <- character()
  out <- suggest_semantics(
    df = tibble::tibble(spawner_count = c(10L, 12L)),
    dict = theme_a_measurement_dictionary(),
    sources = "smn",
    max_per_role = 2L,
    search_fn = function(query, role, sources) {
      search_calls <<- c(search_calls, paste(role, query, sep = "::"))
      if (identical(role, "property") && identical(query, "fish abundance")) {
        return(tibble::tibble(
          label = "Fish abundance",
          iri = "https://example.org/property-better",
          source = "smn",
          ontology = "demo",
          role = role,
          role_hints = role,
          match_type = "label_exact",
          definition = "Abundance of fish",
          score = 0.99
        ))
      }
      theme_a_candidate(role)
    },
    llm_assess = TRUE,
    llm_provider = "openrouter",
    llm_model = "openai/gpt-5.4-mini",
    llm_api_key = "dummy",
    llm_request_fn = function(messages, config) {
      request_calls <<- request_calls + 1L
      response <- theme_a_bundle_response()
      property <- match(
        "property",
        vapply(response$assessments, `[[`, character(1), "dictionary_role")
      )
      if (request_calls == 1L) {
        response$assessments[[property]]$decision <- "retry_search"
        response$assessments[[property]]$selected_candidate_id <- NULL
        response$assessments[[property]]$retry_query <- "fish abundance"
        return(response)
      }
      response$assessments[[property]]$selected_candidate_id <-
        "smn::https://example.org/property-better"
      response
    }
  )

  assessments <- attr(out, "semantic_llm_assessments")
  suggestions <- attr(out, "semantic_suggestions")
  property <- assessments[assessments$dictionary_role == "property", , drop = FALSE]

  expect_equal(request_calls, 2L)
  expect_equal(
    search_calls[grepl("^property::", search_calls)],
    c("property::spawner abundance", "property::fish abundance")
  )
  expect_true(property$llm_exploration_used)
  expect_equal(property$llm_exploration_queries, "fish abundance")
  expect_equal(property$llm_exploration_candidate_gain, 1L)
  expect_equal(property$llm_selected_iri, "https://example.org/property-better")
  expect_true(any(
    suggestions$iri == "https://example.org/property-better" &
      suggestions$llm_selected
  ))
})

test_that("one malformed retry slot does not discard another valid reassessment", {
  request_calls <- 0L
  out <- suggest_semantics(
    df = tibble::tibble(spawner_count = c(10L, 12L)),
    dict = theme_a_measurement_dictionary(),
    sources = "smn",
    max_per_role = 2L,
    search_fn = function(query, role, sources) {
      if (identical(role, "property") && identical(query, "fish abundance")) {
        candidate <- theme_a_candidate(role)
        candidate$label <- "Fish abundance"
        candidate$iri <- "https://example.org/property-better"
        candidate$score <- 0.99
        return(candidate)
      }
      theme_a_candidate(role)
    },
    llm_assess = TRUE,
    llm_provider = "openrouter",
    llm_model = "openai/gpt-5.4-mini",
    llm_api_key = "dummy",
    llm_request_fn = function(messages, config) {
      request_calls <<- request_calls + 1L
      if (request_calls == 3L) {
        return(list(
          decision = "review",
          selected_candidate_index = NULL,
          confidence = 0.4,
          rationale = "Per-target fallback reviewed the malformed method slot.",
          missing_context = ""
        ))
      }

      response <- theme_a_bundle_response()
      roles <- vapply(
        response$assessments,
        `[[`,
        character(1),
        "dictionary_role"
      )
      property <- match("property", roles)
      method <- match("method", roles)
      if (request_calls == 1L) {
        response$assessments[[property]]$decision <- "retry_search"
        response$assessments[[property]]$selected_candidate_id <- NULL
        response$assessments[[property]]$retry_query <- "fish abundance"
        return(response)
      }

      response$assessments[[property]]$selected_candidate_id <-
        "smn::https://example.org/property-better"
      response$assessments[[method]]$selected_candidate_id <-
        "smn::https://example.org/method"
      response
    }
  )

  assessments <- attr(out, "semantic_llm_assessments")
  property <- assessments[
    assessments$dictionary_role == "property",
    ,
    drop = FALSE
  ]

  expect_equal(request_calls, 3L)
  expect_equal(property$llm_decision, "accept")
  expect_equal(property$llm_selected_iri, "https://example.org/property-better")
})

test_that("a duplicate bundle retry is skipped while another slot can reassess", {
  request_calls <- 0L
  retry_searches <- character()
  retry_sources <- list()
  out <- suggest_semantics(
    df = tibble::tibble(spawner_count = c(10L, 12L)),
    dict = theme_a_measurement_dictionary(),
    sources = "smn",
    max_per_role = 2L,
    search_fn = function(query, role, sources) {
      if (identical(query, "fish population")) {
        retry_searches <<- c(retry_searches, paste(role, query, sep = "::"))
        retry_sources[[length(retry_sources) + 1L]] <<- sources
        return(tibble::tibble(
          label = "Fish population",
          iri = "https://example.org/entity-better",
          source = "smn",
          ontology = "demo",
          role = role,
          role_hints = role,
          match_type = "label_exact",
          definition = "A population of fish",
          score = 0.99
        ))
      }
      theme_a_candidate(role)
    },
    llm_assess = TRUE,
    llm_provider = "openrouter",
    llm_model = "openai/gpt-5.4-mini",
    llm_api_key = "dummy",
    llm_request_fn = function(messages, config) {
      request_calls <<- request_calls + 1L
      response <- theme_a_bundle_response()
      roles <- vapply(response$assessments, `[[`, character(1), "dictionary_role")
      property <- match("property", roles)
      entity <- match("entity", roles)
      if (request_calls == 1L) {
        response$assessments[[property]]$decision <- "retry_search"
        response$assessments[[property]]$selected_candidate_id <- NULL
        response$assessments[[property]]$retry_query <- "  SPAWNER   ABUNDANCE "
        response$assessments[[entity]]$decision <- "retry_search"
        response$assessments[[entity]]$selected_candidate_id <- NULL
        response$assessments[[entity]]$retry_query <- "fish population"
        return(response)
      }
      response$assessments[[entity]]$selected_candidate_id <-
        "smn::https://example.org/entity-better"
      response
    }
  )

  assessments <- attr(out, "semantic_llm_assessments")
  property <- assessments[assessments$dictionary_role == "property", , drop = FALSE]
  entity <- assessments[assessments$dictionary_role == "entity", , drop = FALSE]

  expect_equal(request_calls, 2L)
  expect_equal(retry_searches, "entity::fish population")
  expect_true(all(vapply(
    retry_sources,
    identical,
    logical(1),
    y = "smn"
  )))
  expect_equal(property$llm_decision, "retry_search")
  expect_equal(
    property$llm_retry_query_rejection_reason,
    "duplicate_original_query"
  )
  expect_false(property$llm_exploration_used)
  expect_equal(entity$llm_selected_iri, "https://example.org/entity-better")
})

test_that("omitted-source bundle retries keep role-aware defaults", {
  request_calls <- 0L
  source_calls <- list()
  payloads <- list()

  out <- suggest_semantics(
    df = tibble::tibble(spawner_count = c(10L, 12L)),
    dict = theme_a_measurement_dictionary(),
    max_per_role = 2L,
    search_fn = function(query, role, sources) {
      key <- paste(role, query, sep = "::")
      source_calls[[key]] <<- sources
      if (identical(role, "property") &&
          identical(query, "fish abundance detail")) {
        candidate <- theme_a_candidate(role)
        candidate$label <- "Fish abundance detail"
        candidate$iri <- "https://example.org/property-better"
        candidate$score <- 0.99
        return(candidate)
      }
      theme_a_candidate(role)
    },
    llm_assess = TRUE,
    llm_provider = "openrouter",
    llm_model = "openai/gpt-5.4-mini",
    llm_api_key = "dummy",
    llm_request_fn = function(messages, config) {
      request_calls <<- request_calls + 1L
      payloads[[request_calls]] <<- theme_a_bundle_message_payload(messages)
      response <- theme_a_bundle_response()
      roles <- vapply(
        response$assessments,
        `[[`,
        character(1),
        "dictionary_role"
      )
      property <- match("property", roles)
      if (request_calls == 1L) {
        response$assessments[[property]]$decision <- "retry_search"
        response$assessments[[property]]$selected_candidate_id <- NULL
        response$assessments[[property]]$retry_query <- "fish abundance detail"
        return(response)
      }
      response$assessments[[property]]$selected_candidate_id <-
        "smn::https://example.org/property-better"
      response
    }
  )

  assessments <- attr(out, "semantic_llm_assessments")
  property <- assessments[
    assessments$dictionary_role == "property",
    ,
    drop = FALSE
  ]

  expect_equal(request_calls, 2L)
  expect_identical(
    source_calls[["property::spawner abundance"]],
    sources_for_role("property")
  )
  expect_identical(
    source_calls[["property::fish abundance detail"]],
    sources_for_role("property")
  )
  expect_identical(payloads[[1]]$source_policy$mode, "role_defaults")
  expect_identical(payloads[[2]]$source_policy$mode, "role_defaults")
  expect_identical(
    unlist(payloads[[2]]$source_policy$effective_sources_by_role$property),
    sources_for_role("property")
  )
  expect_equal(property$llm_selected_iri, "https://example.org/property-better")
})

test_that("blank-IRI candidate IDs are content-addressed and order-stable", {
  candidates <- tibble::tibble(
    label = c("Candidate", "Candidate"),
    iri = c(NA_character_, NA_character_),
    source = c("local", "local"),
    ontology = c("demo", "demo"),
    definition = c("First definition", "Second definition"),
    match_type = c("label", "synonym")
  )

  first <- metasalmon:::.ms_semantic_bundle_candidate_ids(candidates, "property")
  reversed <- metasalmon:::.ms_semantic_bundle_candidate_ids(
    candidates[2:1, , drop = FALSE],
    "property"
  )
  filtered <- metasalmon:::.ms_semantic_bundle_candidate_ids(
    candidates[2, , drop = FALSE],
    "property"
  )
  exact_duplicates <- metasalmon:::.ms_semantic_bundle_candidate_ids(
    dplyr::bind_rows(candidates[1, ], candidates[1, ]),
    "property"
  )

  expect_length(unique(first), 2L)
  expect_equal(reversed, rev(first))
  expect_equal(filtered, first[[2]])
  expect_equal(exact_duplicates[[1]], exact_duplicates[[2]])
  expect_true(all(startsWith(first, "blank::property::")))
})

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
  expect_identical(omitted_sources$method, sources_for_role("method"))

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

test_that("bundle payload exposes explicit source allowlists", {
  payload <- NULL
  suggest_semantics(
    df = tibble::tibble(spawner_count = c(10L, 12L)),
    dict = theme_a_measurement_dictionary(),
    sources = "smn",
    max_per_role = 1L,
    search_fn = function(query, role, sources) theme_a_candidate(role),
    llm_assess = TRUE,
    llm_provider = "openrouter",
    llm_model = "openai/gpt-5.4-mini",
    llm_api_key = "dummy",
    llm_request_fn = function(messages, config) {
      payload <<- theme_a_bundle_message_payload(messages)
      theme_a_bundle_response()
    }
  )

  expect_identical(payload$source_policy$mode, "explicit")
  expect_identical(
    unlist(payload$source_policy$explicit_allowlist),
    "smn"
  )
  expect_true(all(vapply(
    payload$source_policy$effective_sources_by_role,
    function(sources) identical(unlist(sources), "smn"),
    logical(1)
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
