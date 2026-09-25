# Four pins on the shared assessment validator and the rejection escalation,
# from hub item B-361 (S16 step 1, ruled by Brett on 2026-09-25 when he took
# every recommendation in section 10 of the S16 execplan; decisions 10 and 11).
# Each test failed before the change it pins. The same code serves the
# in-package model call and the assessment ingester that B-326 adds, so a
# regression here would be inherited by both.
#
#   (1) Any FINAL reject_shortlist escalates to request_new_term, including one
#       that follows a retry_search. The old rule escalated only when the
#       decision before the retry was also a rejection, which contradicted
#       AGENTS.md ("an unresolved reject_shortlist escalates to request_new_term").
#   (2) A non-accept decision has its index cleared BEFORE the range check, so a
#       reject_shortlist carrying a stray out-of-range index stays a rejection
#       (and is escalated) instead of becoming review.
#   (3) An index that is not a whole number is refused, not truncated: 1.9 used
#       to select candidate 1.
#   (4) A downgrade with no rationale writes its note without the literal text
#       "NA " in front of it.
#   (5) The retry-query duplicate check folds case over ASCII letters only, the
#       same in every locale. `tolower()` folds non-ASCII letters by locale, so
#       the same pair was a duplicate under en_US.UTF-8 and not under C.
#       metasalmonpy's B-362 mirrors the rule exactly as this file pins it.

.b361_candidates <- function() {
  tibble::tibble(
    iri = c("https://example.org/a", "https://example.org/b"),
    label = c("A", "B")
  )
}

.b361_target <- function() {
  tibble::tibble(
    dataset_id = "d1",
    table_id = "t1",
    column_name = "catch_weight",
    code_value = NA_character_,
    dictionary_role = "property",
    target_scope = "column",
    target_sdp_file = "column_dictionary.csv",
    target_sdp_field = "property_iri",
    search_query = "catch weight"
  )
}

# (1) --------------------------------------------------------------------------

test_that("a final reject_shortlist escalates even when the first answer was retry_search", {
  config <- list(provider = "openrouter", model = "openai/gpt-5.4-mini")
  pre <- metasalmon:::.ms_llm_review_empty_assessment(.b361_target(), config)
  pre$llm_decision <- "retry_search"
  pre$llm_confidence <- 0.4
  pre$llm_retry_query <- "catch mass"
  pre$llm_rationale <- "The shortlist is weak; try catch mass."
  post <- pre
  post$llm_decision <- "reject_shortlist"
  post$llm_retry_query <- NA_character_
  post$llm_rationale <- "The widened shortlist is still the wrong concept family."

  escalated <- metasalmon:::.ms_llm_escalate_unresolved_rejection(
    pre,
    list(assessment = post)
  )$assessment

  expect_equal(escalated$llm_decision[[1]], "request_new_term")
  expect_equal(escalated$llm_escalated_from[[1]], "reject_shortlist")
  expect_true(is.na(escalated$llm_selected_candidate_index[[1]]))
  expect_true(is.na(escalated$llm_selected_iri[[1]]))
  expect_true(is.na(escalated$llm_selected_label[[1]]))
  # The pre-retry answer was not a rejection, so it is not labelled as one.
  expect_false(grepl("Initial shortlist rejection", escalated$llm_rationale[[1]], fixed = TRUE))
  expect_match(escalated$llm_rationale[[1]], "wrong concept family", fixed = TRUE)
  expect_match(escalated$llm_rationale[[1]], "escalated to request_new_term", fixed = TRUE)
})

test_that("a final reject_shortlist escalates when no earlier assessment exists", {
  config <- list(provider = "openrouter", model = "openai/gpt-5.4-mini")
  post <- metasalmon:::.ms_llm_review_empty_assessment(.b361_target(), config)
  post$llm_decision <- "reject_shortlist"
  post$llm_confidence <- 0.9
  post$llm_rationale <- "Nothing here is a catch-level property."

  escalated <- metasalmon:::.ms_llm_escalate_unresolved_rejection(
    NULL,
    list(assessment = post)
  )$assessment

  expect_equal(escalated$llm_decision[[1]], "request_new_term")
  expect_equal(escalated$llm_escalated_from[[1]], "reject_shortlist")
  expect_match(escalated$llm_rationale[[1]], "Nothing here is a catch-level property.", fixed = TRUE)
  expect_false(startsWith(escalated$llm_rationale[[1]], "NA "))
})

test_that("a final accept after an initial reject_shortlist is left untouched", {
  config <- list(provider = "openrouter", model = "openai/gpt-5.4-mini")
  pre <- metasalmon:::.ms_llm_review_empty_assessment(.b361_target(), config)
  pre$llm_decision <- "reject_shortlist"
  pre$llm_rationale <- "Wrong family."
  post <- pre
  post$llm_decision <- "accept"
  post$llm_selected_candidate_index <- 1L
  post$llm_selected_iri <- "https://example.org/a"
  post$llm_selected_label <- "A"
  post$llm_rationale <- "The retry found the right term."

  out <- metasalmon:::.ms_llm_escalate_unresolved_rejection(pre, list(assessment = post))$assessment
  expect_equal(out$llm_decision[[1]], "accept")
  expect_equal(out$llm_selected_candidate_index[[1]], 1L)
  expect_true(is.na(out$llm_escalated_from[[1]]))
  expect_equal(out$llm_rationale[[1]], "The retry found the right term.")
})

test_that("bundle escalation escalates a final reject_shortlist for a role with no initial row", {
  config <- list(provider = "openrouter", model = "openai/gpt-5.4-mini")
  initial <- metasalmon:::.ms_llm_review_empty_assessment(.b361_target(), config)
  initial$llm_decision <- "review"
  final_property <- initial
  final_unit <- initial
  final_unit$dictionary_role <- "unit"
  final_unit$target_sdp_field <- "unit_iri"
  final_unit$llm_decision <- "reject_shortlist"
  final_unit$llm_rationale <- "No unit candidate is a mass unit."
  final <- dplyr::bind_rows(final_property, final_unit)

  out <- metasalmon:::.ms_semantic_bundle_escalate_rejections(initial, final)

  expect_equal(out$llm_decision[out$dictionary_role == "property"], "review")
  expect_equal(out$llm_decision[out$dictionary_role == "unit"], "request_new_term")
  expect_equal(out$llm_escalated_from[out$dictionary_role == "unit"], "reject_shortlist")
})

test_that("retry_search followed by reject_shortlist escalates through the generic review path", {
  suggestions <- tibble::tibble(
    dataset_id = c("d1", "d1"),
    table_id = c("t1", "t1"),
    column_name = c("CATCH_WEIGHT", "CATCH_WEIGHT"),
    column_label = c("Catch weight", "Catch weight"),
    column_description = c("Weight of catch", "Weight of catch"),
    column_role = c("measurement", "measurement"),
    code_value = c(NA_character_, NA_character_),
    dictionary_role = c("property", "property"),
    search_role = c("property", "property"),
    target_scope = c("column", "column"),
    target_sdp_file = c("column_dictionary.csv", "column_dictionary.csv"),
    target_sdp_field = c("property_iri", "property_iri"),
    search_query = c("catch weight", "catch weight"),
    target_label = c("Weight of catch", "Weight of catch"),
    target_description = c("Weight of catch", "Weight of catch"),
    target_query_basis = c("label", "label"),
    target_query_context = c("ctx", "ctx"),
    label = c("Fish weight", "Weight context"),
    iri = c("https://example.org/property/fish-weight", "https://example.org/constraint/context"),
    source = c("smn", "smn"),
    ontology = c("demo", "demo"),
    definition = c("Fish weight property", "Weak context term"),
    match_type = c("label_partial", "label_partial"),
    score = c(0.8, 0.79)
  )

  call_idx <- 0L
  fake_request <- function(messages, config) {
    call_idx <<- call_idx + 1L
    if (call_idx == 1L) {
      return(list(
        decision = "retry_search",
        selected_candidate_index = NULL,
        confidence = 0.45,
        rationale = "Need a catch-mass specific property.",
        missing_context = "",
        retry_query = "catch mass"
      ))
    }
    # The widened shortlist is judged the wrong concept family outright.
    list(
      decision = "reject_shortlist",
      selected_candidate_index = NULL,
      confidence = 0.88,
      rationale = "Every candidate describes an individual fish, not the catch.",
      missing_context = ""
    )
  }

  fake_search <- function(query, role, sources) {
    if (identical(query, "catch mass")) {
      return(tibble::tibble(
        label = c("Catch mass", "Fish weight"),
        iri = c("https://example.org/property/catch-mass", "https://example.org/property/fish-weight"),
        source = c("smn", "smn"),
        ontology = c("demo", "demo"),
        role = c(role, role),
        match_type = c("label_partial", "label_partial"),
        definition = c("Total mass of catch", "Fish weight property"),
        score = c(0.94, 0.86)
      ))
    }
    tibble::tibble()
  }

  out <- metasalmon:::.ms_assess_semantic_suggestions_llm(
    suggestions,
    provider = "openrouter",
    model = "qwen/qwen3.6-plus:free",
    api_key = "dummy-key",
    top_n = 2L,
    request_fn = fake_request,
    search_fn = fake_search,
    sources = "smn",
    max_per_role = 2L
  )

  assessment <- out$assessments
  expect_equal(call_idx, 2L)
  expect_equal(nrow(assessment), 1L)
  expect_true(isTRUE(assessment$llm_exploration_used[[1]]))
  expect_equal(assessment$llm_exploration_candidate_gain[[1]], 1L)
  expect_equal(assessment$llm_decision[[1]], "request_new_term")
  expect_equal(assessment$llm_escalated_from[[1]], "reject_shortlist")
  expect_true(is.na(assessment$llm_selected_candidate_index[[1]]))
  expect_match(assessment$llm_rationale[[1]], "escalated to request_new_term", fixed = TRUE)
  expect_false(any(isTRUE(out$suggestions$llm_selected)))
})

# (2) --------------------------------------------------------------------------

test_that("a reject_shortlist carrying a stray out-of-range index stays a rejection", {
  result <- metasalmon:::.ms_validate_llm_assessment(
    list(
      decision = "reject_shortlist",
      selected_candidate_index = 99,
      confidence = 0.83,
      rationale = "The whole shortlist is the wrong concept family.",
      missing_context = ""
    ),
    .b361_candidates()
  )

  expect_equal(result$decision, "reject_shortlist")
  expect_true(is.na(result$selected_candidate_index))
  expect_equal(result$rationale, "The whole shortlist is the wrong concept family.")
})

test_that("a review decision carrying a stray out-of-range index keeps its rationale", {
  result <- metasalmon:::.ms_validate_llm_assessment(
    list(
      decision = "review",
      selected_candidate_index = 0,
      confidence = 0.5,
      rationale = "Unsure.",
      missing_context = ""
    ),
    .b361_candidates()
  )

  expect_equal(result$decision, "review")
  expect_true(is.na(result$selected_candidate_index))
  expect_equal(result$rationale, "Unsure.")
})

test_that("an accept with an out-of-range index still downgrades to review", {
  result <- metasalmon:::.ms_validate_llm_assessment(
    list(
      decision = "accept",
      selected_candidate_index = 3,
      confidence = 0.7,
      rationale = "Bad index from model.",
      missing_context = ""
    ),
    .b361_candidates()
  )

  expect_equal(result$decision, "review")
  expect_true(is.na(result$selected_candidate_index))
  expect_equal(
    result$rationale,
    "Bad index from model. Model returned an out-of-range candidate index; downgraded to review."
  )
})

# (3) --------------------------------------------------------------------------

test_that("a candidate index that is not a whole number is refused, not truncated", {
  for (bad in list(1.9, "1.9", 0.5, "2.000001")) {
    expect_error(
      metasalmon:::.ms_validate_llm_assessment(
        list(
          decision = "accept",
          selected_candidate_index = bad,
          confidence = 0.9,
          rationale = "Looks right.",
          missing_context = ""
        ),
        .b361_candidates()
      ),
      "whole number"
    )
  }
})

test_that("a whole-number index written as a decimal or a string is still accepted", {
  for (ok in list(2, 2L, "2", "2.0", 2.0)) {
    result <- metasalmon:::.ms_validate_llm_assessment(
      list(
        decision = "accept",
        selected_candidate_index = ok,
        confidence = 0.9,
        rationale = "Looks right.",
        missing_context = ""
      ),
      .b361_candidates()
    )
    expect_equal(result$decision, "accept")
    expect_identical(result$selected_candidate_index, 2L)
  }
})

test_that("a non-whole index on a non-accept decision is ignored, because the index is", {
  result <- metasalmon:::.ms_validate_llm_assessment(
    list(
      decision = "review",
      selected_candidate_index = 1.9,
      confidence = 0.5,
      rationale = "Unsure.",
      missing_context = ""
    ),
    .b361_candidates()
  )
  expect_equal(result$decision, "review")
  expect_true(is.na(result$selected_candidate_index))
})

test_that("a refused index becomes an error row rather than a truncated selection", {
  target <- .b361_target()
  candidates <- .b361_candidates()
  candidates$source <- "smn"
  config <- list(provider = "openrouter", model = "openai/gpt-5.4-mini")
  record <- list(
    group_name = "g1",
    group = dplyr::bind_cols(target[rep(1, 2), ], candidates),
    candidate_rows = dplyr::bind_cols(target[rep(1, 2), ], candidates),
    context_chunks = tibble::tibble(),
    bundle_group = NULL,
    decomposition_mode = FALSE
  )
  batch <- list(assessments = list(list(
    target_key = "g1",
    decision = "accept",
    selected_candidate_index = 1.9,
    confidence = 0.9,
    rationale = "Looks right."
  )))

  rows <- metasalmon:::.ms_llm_validate_batch_assessments(batch, list(record), config)

  # The batch validator keeps only usable rows and records why the rest fell
  # back; a refused index is a fallback with its reason, not a row selecting
  # candidate 1.
  expect_equal(nrow(rows), 0L)
  expect_equal(attr(rows, "llm_batch_fallback_keys"), "g1")
  expect_match(attr(rows, "llm_batch_fallback_reasons")[["g1"]], "whole number")
})

test_that("a refused index reaches the assessments as an error row, not as candidate 1", {
  suggestions <- tibble::tibble(
    dataset_id = c("d1", "d1"),
    table_id = c("t1", "t1"),
    column_name = c("CATCH_WEIGHT", "CATCH_WEIGHT"),
    column_label = c("Catch weight", "Catch weight"),
    column_description = c("Weight of catch", "Weight of catch"),
    column_role = c("measurement", "measurement"),
    code_value = c(NA_character_, NA_character_),
    dictionary_role = c("property", "property"),
    search_role = c("property", "property"),
    target_scope = c("column", "column"),
    target_sdp_file = c("column_dictionary.csv", "column_dictionary.csv"),
    target_sdp_field = c("property_iri", "property_iri"),
    search_query = c("catch weight", "catch weight"),
    target_label = c("Weight of catch", "Weight of catch"),
    target_description = c("Weight of catch", "Weight of catch"),
    target_query_basis = c("label", "label"),
    target_query_context = c("ctx", "ctx"),
    label = c("Fish weight", "Weight context"),
    iri = c("https://example.org/property/fish-weight", "https://example.org/constraint/context"),
    source = c("smn", "smn"),
    ontology = c("demo", "demo"),
    definition = c("Fish weight property", "Weak context term"),
    match_type = c("label_partial", "label_partial"),
    score = c(0.8, 0.79)
  )
  fake_request <- function(messages, config) {
    list(
      decision = "accept",
      selected_candidate_index = 1.9,
      confidence = 0.9,
      rationale = "Looks right.",
      missing_context = ""
    )
  }

  out <- suppressWarnings(metasalmon:::.ms_assess_semantic_suggestions_llm(
    suggestions,
    provider = "openrouter",
    model = "qwen/qwen3.6-plus:free",
    api_key = "dummy-key",
    top_n = 2L,
    request_fn = fake_request,
    search_fn = function(query, role, sources) tibble::tibble(),
    sources = "smn",
    max_per_role = 2L
  ))

  assessment <- out$assessments
  expect_equal(nrow(assessment), 1L)
  expect_true(is.na(assessment$llm_decision[[1]]))
  expect_true(is.na(assessment$llm_selected_candidate_index[[1]]))
  expect_true(is.na(assessment$llm_selected_iri[[1]]))
  expect_match(assessment$llm_error[[1]], "whole number")
  # Every assessment failed, so the deterministic fallback carries no
  # llm_selected column at all; either way nothing is selected.
  expect_false(isTRUE(any(out$suggestions[["llm_selected"]])))
})

# (4) --------------------------------------------------------------------------

test_that("a downgrade with no rationale is written without an NA prefix", {
  cases <- list(
    list(decision = "accept", selected_candidate_index = NULL, confidence = 0.6),
    list(decision = "accept", selected_candidate_index = 5, confidence = 0.6),
    list(decision = "retry_search", selected_candidate_index = NULL, confidence = 0.6)
  )
  for (case in cases) {
    result <- metasalmon:::.ms_validate_llm_assessment(case, .b361_candidates())
    expect_equal(result$decision, "review")
    expect_false(is.na(result$rationale))
    expect_false(startsWith(result$rationale, "NA"), info = case$decision)
    expect_match(result$rationale, "^Model ")
  }
})

test_that("a downgrade with an empty-string rationale is written without a leading space", {
  result <- metasalmon:::.ms_validate_llm_assessment(
    list(decision = "accept", selected_candidate_index = NULL, confidence = 0.6, rationale = ""),
    .b361_candidates()
  )
  expect_equal(
    result$rationale,
    "Model returned accept without selecting a candidate; downgraded to review."
  )
})

test_that("two downgrade notes join with one space after the rationale", {
  # accept with no index, then retry_search is not reachable together; use the
  # rationale-plus-note case to pin the joiner.
  result <- metasalmon:::.ms_validate_llm_assessment(
    list(decision = "retry_search", selected_candidate_index = NULL, confidence = 0.6, rationale = "Need more."),
    .b361_candidates()
  )
  expect_equal(
    result$rationale,
    "Need more. Model requested retry_search without providing a retry query; downgraded to review."
  )
})

# (5) --------------------------------------------------------------------------

# Run `code` under each of two LC_CTYPE locales: one UTF-8 locale (the first
# of a short list that this machine can set) and C. A locale that cannot be
# set is skipped by name, so a platform without any UTF-8 locale still runs
# the C half. Retires when R's tolower() stops depending on the locale, which
# it will not; the helper is only how the pin is stated.
.b361_with_ctype <- function(locale, code) {
  previous <- Sys.getlocale("LC_CTYPE")
  set <- suppressWarnings(Sys.setlocale("LC_CTYPE", locale))
  if (!nzchar(set)) {
    testthat::skip(paste("LC_CTYPE", locale, "cannot be set on this machine"))
  }
  on.exit(suppressWarnings(Sys.setlocale("LC_CTYPE", previous)), add = TRUE)
  force(code)
}

.b361_utf8_locale <- function() {
  previous <- Sys.getlocale("LC_CTYPE")
  on.exit(suppressWarnings(Sys.setlocale("LC_CTYPE", previous)), add = TRUE)
  for (candidate in c("en_US.UTF-8", "C.UTF-8", "en_CA.UTF-8", "en_GB.UTF-8")) {
    if (nzchar(suppressWarnings(Sys.setlocale("LC_CTYPE", candidate)))) {
      return(candidate)
    }
  }
  NA_character_
}

test_that("the retry-query duplicate check folds ASCII case only, identically in every locale", {
  # E-acute in both cases: tolower() folds it under a UTF-8 locale and not
  # under C, so the old check gave a locale-dependent verdict.
  retry <- "Poisson ÉLEVÉ"
  original <- "poisson élevé"
  ascii_retry <- "CATCH Weight"
  ascii_original <- "catch weight"

  utf8 <- .b361_utf8_locale()
  locales <- c(if (!is.na(utf8)) utf8, "C")
  for (locale in locales) {
    .b361_with_ctype(locale, {
      non_ascii <- metasalmon:::.ms_llm_classify_retry_query(retry, original)
      expect_equal(non_ascii$disposition, "use_query", info = locale)
      expect_true(is.na(non_ascii$rejection_reason), info = locale)

      ascii <- metasalmon:::.ms_llm_classify_retry_query(ascii_retry, ascii_original)
      expect_equal(ascii$disposition, "duplicate_original_query", info = locale)
      expect_equal(ascii$rejection_reason, "duplicate_original_query", info = locale)
    })
  }
})

test_that(".ms_ascii_tolower folds A-Z only and leaves every other character alone", {
  expect_identical(metasalmon:::.ms_ascii_tolower("ABC xyz 123 ÉÀ"), "abc xyz 123 ÉÀ")
  expect_identical(metasalmon:::.ms_ascii_tolower(character()), character())
  expect_identical(metasalmon:::.ms_ascii_tolower(NA_character_), NA_character_)
})
