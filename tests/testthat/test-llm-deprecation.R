# The deprecation of the in-package model call (S16 step 1, hub item B-326,
# execplan section 6). The suite-wide quiet switch in
# setup-llm-deprecation-quiet.R keeps every other test byte-identical; these
# tests switch it off and assert: one warning per entry point, none on the
# default path, one even with `seed_semantics = FALSE`, one from
# `chat_decomposition()`, and that the opt-in warnings come first.

.deprecation_warnings <- function(expr) {
  found <- list()
  withCallingHandlers(
    expr,
    warning = function(w) {
      found[[length(found) + 1L]] <<- w
      invokeRestart("muffleWarning")
    }
  )
  found
}

.is_deprecation <- function(w) inherits(w, "metasalmon_llm_deprecated")

test_that("suggest_semantics(llm_assess = TRUE) warns once, after the opt-in warnings, and is classed", {
  withr::local_options(metasalmon.llm_deprecation_quiet = FALSE)
  dict <- test_dictionary()
  fake_request <- function(messages, config) {
    list(decision = "review", selected_candidate_index = NULL, confidence = 0.4, rationale = "Unsure.", missing_context = "")
  }
  warnings <- .deprecation_warnings(suppressMessages(
    suggest_semantics(
      NULL, dict,
      search_fn = test_shortlist_search,
      llm_assess = TRUE, llm_provider = "openrouter", llm_api_key = "dummy-key",
      llm_request_fn = fake_request
    )
  ))
  deprecations <- Filter(.is_deprecation, warnings)
  expect_length(deprecations, 1L)
  expect_s3_class(deprecations[[1]], "deprecatedWarning")
  expect_match(conditionMessage(deprecations[[1]]), "suggest_semantics", fixed = TRUE)
  expect_match(conditionMessage(deprecations[[1]]), "0.7.0", fixed = TRUE)
  expect_match(conditionMessage(deprecations[[1]]), "write_semantic_review_packet", fixed = TRUE)
  expect_match(conditionMessage(deprecations[[1]]), "ingest_semantic_assessments", fixed = TRUE)
})

test_that("context supplied without llm_assess still warns it is ignored, first, and makes no call", {
  withr::local_options(metasalmon.llm_deprecation_quiet = FALSE)
  dict <- test_dictionary()
  warnings <- .deprecation_warnings(suppressMessages(
    suggest_semantics(
      NULL, dict,
      search_fn = test_shortlist_search,
      llm_context_text = "Some context.",
      llm_request_fn = function(...) stop("the model must not be called")
    )
  ))
  classes <- vapply(warnings, .is_deprecation, logical(1))
  expect_equal(sum(classes), 1L)
  # The opt-in warning comes first; the deprecation warning is last.
  expect_false(classes[[1]])
  expect_match(conditionMessage(warnings[[1]]), "llm_context_text", fixed = TRUE)
  expect_true(classes[[length(classes)]])
})

test_that("the default path emits no deprecation warning from any entry point", {
  withr::local_options(metasalmon.llm_deprecation_quiet = FALSE)
  dict <- test_dictionary()
  warnings <- .deprecation_warnings(suppressMessages(
    suggest_semantics(NULL, dict, search_fn = test_shortlist_search)
  ))
  expect_length(Filter(.is_deprecation, warnings), 0L)

  df <- data.frame(spawner_count = c(1L, 2L, 3L))
  warnings <- .deprecation_warnings(suppressMessages(
    infer_dictionary(df, seed_semantics = FALSE)
  ))
  expect_length(Filter(.is_deprecation, warnings), 0L)

  warnings <- .deprecation_warnings(suppressMessages(
    infer_salmon_datapackage_artifacts(list(t1 = df), seed_semantics = FALSE)
  ))
  expect_length(Filter(.is_deprecation, warnings), 0L)

  path <- file.path(withr::local_tempdir(), "no-deprecation")
  warnings <- .deprecation_warnings(suppressMessages(
    create_sdp(list(t1 = df), path = path, seed_semantics = FALSE, check_updates = FALSE, overwrite = TRUE)
  ))
  expect_length(Filter(.is_deprecation, warnings), 0L)
})

test_that("infer_dictionary warns once even when seed_semantics = FALSE leaves the options unused", {
  withr::local_options(metasalmon.llm_deprecation_quiet = FALSE)
  df <- data.frame(spawner_count = c(1L, 2L, 3L))
  warnings <- .deprecation_warnings(suppressMessages(
    infer_dictionary(df, seed_semantics = FALSE, llm_assess = TRUE)
  ))
  deprecations <- Filter(.is_deprecation, warnings)
  expect_length(deprecations, 1L)
  expect_match(conditionMessage(deprecations[[1]]), "infer_dictionary", fixed = TRUE)
})

test_that("a nested call chain warns exactly once, naming the outermost entry point", {
  withr::local_options(metasalmon.llm_deprecation_quiet = FALSE)
  df <- data.frame(spawner_count = c(1L, 2L, 3L))
  path <- file.path(withr::local_tempdir(), "one-warning")
  warnings <- .deprecation_warnings(suppressMessages(
    create_sdp(
      list(t1 = df), path = path, seed_semantics = FALSE,
      llm_top_n = 3L, check_updates = FALSE, overwrite = TRUE
    )
  ))
  deprecations <- Filter(.is_deprecation, warnings)
  expect_length(deprecations, 1L)
  expect_match(conditionMessage(deprecations[[1]]), "create_sdp", fixed = TRUE)

  warnings <- .deprecation_warnings(suppressMessages(
    infer_salmon_datapackage_artifacts(list(t1 = df), seed_semantics = FALSE, llm_assess = FALSE)
  ))
  deprecations <- Filter(.is_deprecation, warnings)
  expect_length(deprecations, 1L)
  expect_match(conditionMessage(deprecations[[1]]), "infer_salmon_datapackage_artifacts", fixed = TRUE)
})

test_that("chat_decomposition warns on every call", {
  withr::local_options(metasalmon.llm_deprecation_quiet = FALSE)
  dict <- test_dictionary()
  warnings <- .deprecation_warnings(suppressMessages(tryCatch(
    chat_decomposition(
      dict, "spawner_count",
      search_fn = test_shortlist_search,
      chat_provider = "openrouter", chat_api_key = "dummy-key",
      chat_request_fn = function(...) stop("no model"),
      input_fn = function(...) "quit",
      output_fn = function(...) invisible(NULL)
    ),
    error = function(e) NULL
  )))
  deprecations <- Filter(.is_deprecation, warnings)
  expect_length(deprecations, 1L)
  expect_match(conditionMessage(deprecations[[1]]), "chat_decomposition", fixed = TRUE)
})

test_that("the quiet option silences the deprecation warning", {
  withr::local_options(metasalmon.llm_deprecation_quiet = TRUE)
  df <- data.frame(spawner_count = c(1L, 2L, 3L))
  warnings <- .deprecation_warnings(suppressMessages(
    infer_dictionary(df, seed_semantics = FALSE, llm_assess = TRUE)
  ))
  expect_length(Filter(.is_deprecation, warnings), 0L)
})

test_that("the deprecation trigger reads every llm_* argument with missing()", {
  f <- function(llm_assess = FALSE, llm_provider = "x", llm_model = NULL, llm_api_key = NULL,
                llm_base_url = NULL, llm_reasoning_effort = NULL, llm_top_n = 5L,
                llm_context_files = NULL, llm_context_text = NULL, llm_timeout_seconds = 60,
                llm_request_fn = NULL) {
    metasalmon:::.ms_llm_deprecation_triggered(environment())
  }
  expect_false(f())
  expect_true(f(llm_assess = FALSE))
  expect_true(f(llm_timeout_seconds = 60))
  expect_true(f(llm_request_fn = identity))
})
