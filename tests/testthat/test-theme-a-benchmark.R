theme_a_script_path <- function() {
  normalizePath(
    testthat::test_path("..", "..", "scripts", "theme-a-benchmark.R"),
    winslash = "/",
    mustWork = FALSE
  )
}

theme_a_harness <- local({
  harness <- NULL

  function() {
    testthat::skip_if_not(
      file.exists(theme_a_script_path()),
      "Theme A benchmark script is excluded from the built source package"
    )
    if (is.null(harness)) {
      harness <<- new.env(parent = globalenv())
      sys.source(theme_a_script_path(), envir = harness)
      harness$script_path <- theme_a_script_path()
    }
    harness
  }
})

run_theme_a_cli <- function(args = character()) {
  testthat::skip_if_not(
    file.exists(theme_a_script_path()),
    "Theme A benchmark script is excluded from the built source package"
  )
  output <- suppressWarnings(system2(
    file.path(R.home("bin"), "Rscript"),
    c(shQuote(theme_a_script_path()), args),
    stdout = TRUE,
    stderr = TRUE
  ))
  status <- attr(output, "status")
  list(
    status = if (is.null(status)) 0L else status,
    output = paste(output, collapse = "\n")
  )
}

unquote_theme_a_arg <- function(arg) {
  if (!startsWith(arg, "--") || !grepl("=", arg, fixed = TRUE)) {
    return(arg)
  }
  parts <- strsplit(arg, "=", fixed = TRUE)[[1L]]
  value <- paste(parts[-1L], collapse = "=")
  if (nchar(value) >= 2L) {
    first <- substr(value, 1L, 1L)
    last <- substr(value, nchar(value), nchar(value))
    if (first %in% c("'", "\"") && identical(first, last)) {
      value <- substr(value, 2L, nchar(value) - 1L)
    }
  }
  paste0(parts[[1L]], "=", value)
}

run_theme_a_script <- function(args = character()) {
  harness <- theme_a_harness()
  args <- vapply(args, unquote_theme_a_arg, character(1))
  error <- NULL
  output <- suppressWarnings(capture.output(
    tryCatch({
      options <- harness$parse_args(args)
      harness$run_benchmark_mode(options)
    }, error = function(e) {
      error <<- e
      cat(
        "Theme A benchmark error: ",
        conditionMessage(e),
        "\n",
        sep = ""
      )
    }),
    type = "output"
  ))
  list(
    status = if (is.null(error)) 0L else 1L,
    output = paste(output, collapse = "\n")
  )
}

theme_a_fixture_path <- function(name) {
  testthat::test_path("fixtures", "theme-a", name)
}

write_theme_a_json <- function(value, path) {
  jsonlite::write_json(
    value,
    path,
    auto_unbox = TRUE,
    pretty = TRUE,
    na = "null",
    null = "null"
  )
  path
}

theme_a_null_selection <- function(row) {
  row$llm_decision <- "review"
  row["llm_selected_candidate_index"] <- list(NULL)
  row["llm_selected_iri"] <- list(NULL)
  row["llm_selected_label"] <- list(NULL)
  row
}

theme_a_downgrade_accept <- function(replay, case_id, role) {
  case_index <- which(vapply(
    replay$cases,
    function(case) identical(case$case_id, case_id),
    logical(1)
  ))
  stopifnot(length(case_index) == 1L)
  observed <- replay$cases[[case_index]]
  assessment_index <- which(vapply(
    observed$assessment_rows,
    function(row) identical(row$dictionary_role, role),
    logical(1)
  ))
  stopifnot(length(assessment_index) == 1L)
  selected_iri <- observed$assessment_rows[[
    assessment_index
  ]]$llm_selected_iri
  observed$assessment_rows[[assessment_index]] <-
    theme_a_null_selection(observed$assessment_rows[[assessment_index]])

  for (i in seq_along(observed$suggestion_rows)) {
    if (identical(observed$suggestion_rows[[i]]$dictionary_role, role)) {
      observed$suggestion_rows[[i]]$llm_selected <- FALSE
      observed$suggestion_rows[[i]]$llm_decision <- "review"
      observed$suggestion_rows[[i]]$llm_selected_iri <- NULL
      observed$suggestion_rows[[i]]$llm_selected_label <- NULL
    }
  }

  field <- switch(
    role,
    variable = "term_iri",
    property = "property_iri",
    entity = "entity_iri",
    unit = "unit_iri",
    constraint = "constraint_iri",
    method = "method_iri"
  )
  observed$final_dictionary_rows[[1L]][field] <- list(NULL)
  observed$events <- Filter(function(event) {
    event_role <- if ("role" %in% names(event)) event$role else NULL
    event_iri <- if ("iri" %in% names(event)) event$iri else NULL
    !(identical(event_role, role) &&
      event$type %in% c("assessment", "selection", "prefill") &&
      (
        !identical(event$type, "selection") ||
          identical(event_iri, selected_iri)
      ))
  }, observed$events)
  observed$events[[length(observed$events) + 1L]] <- list(
    type = "assessment",
    role = role,
    decision = "review"
  )
  replay$cases[[case_index]] <- observed
  replay
}

test_that("Theme A benchmark defaults to a passing offline replay", {
  result <- run_theme_a_cli()

  expect_equal(result$status, 0L, info = result$output)
  expect_match(result$output, "Theme A replay: PASS", fixed = TRUE)
  expect_match(result$output, "Cases: 6/6", fixed = TRUE)
  expect_match(result$output, "critical: 6/6", fixed = TRUE)
  expect_match(result$output, "False acceptances: 0", fixed = TRUE)
  expect_match(result$output, "false prefills: 0", fixed = TRUE)
})

test_that("Theme A replay rejects a fixture that violates the target schema", {
  cases_path <- testthat::test_path("fixtures", "theme-a", "cases-v1.json")
  cases <- jsonlite::read_json(cases_path, simplifyVector = FALSE)
  cases$cases[[1L]]$targets[[1L]]$target_label <- NULL

  invalid_path <- tempfile("theme-a-invalid-", fileext = ".json")
  withr::defer(unlink(invalid_path))
  jsonlite::write_json(
    cases,
    invalid_path,
    auto_unbox = TRUE,
    pretty = TRUE,
    na = "null",
    null = "null"
  )

  result <- run_theme_a_script(c(
    "replay",
    paste0("--cases=", shQuote(invalid_path))
  ))

  expect_true(result$status > 0L, info = result$output)
  expect_match(
    result$output,
    "must contain exactly the 19 target columns",
    fixed = TRUE
  )
})

test_that("Theme A replay pins every candidate IRI and native type", {
  cases <- jsonlite::read_json(
    theme_a_fixture_path("cases-v1.json"),
    simplifyVector = FALSE
  )
  cases$cases[[1L]]$candidates[[1L]]$term_type <- "skos_concept"
  invalid_path <- tempfile("theme-a-ontology-mismatch-", fileext = ".json")
  withr::defer(unlink(invalid_path))
  write_theme_a_json(cases, invalid_path)

  result <- run_theme_a_script(c(
    "replay",
    paste0("--cases=", shQuote(invalid_path))
  ))

  expect_true(result$status > 0L, info = result$output)
  expect_match(
    result$output,
    "disagrees with its pinned source or native candidate type",
    fixed = TRUE
  )
})

test_that("Theme A replay rejects events unsupported by structured rows", {
  replay <- jsonlite::read_json(
    theme_a_fixture_path("replay-v1.json"),
    simplifyVector = FALSE
  )
  selection <- which(vapply(
    replay$cases[[1L]]$events,
    function(event) identical(event$type, "selection"),
    logical(1)
  ))[[1L]]
  replay$cases[[1L]]$events[[selection]]$iri <-
    "https://example.org/tampered"

  invalid_path <- tempfile("theme-a-inconsistent-", fileext = ".json")
  withr::defer(unlink(invalid_path))
  write_theme_a_json(replay, invalid_path)

  result <- run_theme_a_script(c(
    "replay",
    paste0("--replay=", shQuote(invalid_path))
  ))

  expect_true(result$status > 0L, info = result$output)
  expect_match(
    result$output,
    "events are inconsistent with assessment, final dictionary",
    fixed = TRUE
  )
})

test_that("Theme A replay rejects inconsistent structured artifacts", {
  base <- jsonlite::read_json(
    theme_a_fixture_path("replay-v1.json"),
    simplifyVector = FALSE
  )
  mutations <- list(
    selected_iri = function(replay) {
      replay$cases[[1L]]$assessment_rows[[1L]]$llm_selected_iri <-
        "https://example.org/not-in-shortlist"
      replay
    },
    selected_flag = function(replay) {
      replay$cases[[1L]]$suggestion_rows[[1L]]$llm_selected <- FALSE
      replay
    },
    target_identity = function(replay) {
      replay$cases[[1L]]$suggestion_rows[[1L]]$search_query <-
        "different target"
      replay
    },
    candidate_record = function(replay) {
      replay$cases[[1L]]$suggestion_rows[[1L]]$label <-
        "Tampered catch abundance"
      replay$cases[[1L]]$assessment_rows[[1L]]$llm_selected_label <-
        "Tampered catch abundance"
      replay
    },
    candidate_source = function(replay) {
      replay$cases[[1L]]$suggestion_rows[[1L]]$source <- "gcdfo"
      replay
    },
    candidate_type = function(replay) {
      replay$cases[[1L]]$suggestion_rows[[1L]]$term_type <-
        "skos_concept"
      replay
    },
    candidate_definition = function(replay) {
      replay$cases[[1L]]$suggestion_rows[[1L]]$definition <-
        "Tampered definition"
      replay
    },
    candidate_score = function(replay) {
      replay$cases[[1L]]$suggestion_rows[[1L]]$score <- 0.01
      replay
    },
    duplicate_candidate = function(replay) {
      replay$cases[[1L]]$suggestion_rows[[5L]] <-
        replay$cases[[1L]]$suggestion_rows[[1L]]
      replay
    },
    final_dictionary_identity = function(replay) {
      replay$cases[[1L]]$final_dictionary_rows[[1L]]$column_name <-
        "OTHER_COLUMN"
      replay
    },
    proposed_term = function(replay) {
      gap_index <- which(vapply(
        replay$cases[[2L]]$gap_rows,
        function(row) identical(row$dictionary_role, "variable"),
        logical(1)
      ))[[1L]]
      replay$cases[[2L]]$term_request_rows[[
        gap_index
      ]]$llm_new_term_label <- "Different proposal"
      replay
    }
  )

  for (name in names(mutations)) {
    invalid_path <- tempfile(
      paste0("theme-a-", name, "-"),
      fileext = ".json"
    )
    withr::defer(unlink(invalid_path))
    write_theme_a_json(mutations[[name]](base), invalid_path)
    result <- run_theme_a_script(c(
      "replay",
      paste0("--replay=", shQuote(invalid_path))
    ))
    expect_true(
      result$status > 0L,
      info = paste(name, result$output)
    )
  }
})

test_that("Theme A replay requires exact ontology provenance", {
  replay <- jsonlite::read_json(
    theme_a_fixture_path("replay-v1.json"),
    simplifyVector = FALSE
  )
  replay$provenance$ontology_provenance[[1L]]$revision <-
    paste(rep("f", 40L), collapse = "")
  invalid_path <- tempfile(
    "theme-a-replay-provenance-",
    fileext = ".json"
  )
  withr::defer(unlink(invalid_path))
  write_theme_a_json(replay, invalid_path)

  result <- run_theme_a_script(c(
    "replay",
    paste0("--replay=", shQuote(invalid_path))
  ))

  expect_true(result$status > 0L, info = result$output)
  expect_match(
    result$output,
    "Replay ontology provenance does not match",
    fixed = TRUE
  )
})

test_that("Theme A compare requires validated evidence and compares per-rule results", {
  bare_evaluation_path <- tempfile(
    "theme-a-bare-evaluation-",
    fileext = ".json"
  )
  baseline_path <- tempfile("theme-a-baseline-", fileext = ".json")
  candidate_path <- tempfile("theme-a-candidate-", fileext = ".json")
  withr::defer(unlink(c(
    bare_evaluation_path,
    baseline_path,
    candidate_path
  )))

  replay <- jsonlite::read_json(
    theme_a_fixture_path("replay-v1.json"),
    simplifyVector = FALSE
  )
  replay_result <- run_theme_a_script(c(
    "replay",
    paste0("--output=", shQuote(bare_evaluation_path))
  ))
  expect_equal(replay_result$status, 0L, info = replay_result$output)
  bare_compare <- run_theme_a_script(c(
    "compare",
    paste0("--baseline=", shQuote(bare_evaluation_path)),
    paste0(
      "--candidate=",
      shQuote(theme_a_fixture_path("replay-v1.json"))
    )
  ))
  expect_true(bare_compare$status > 0L, info = bare_compare$output)
  expect_match(
    bare_compare$output,
    "bare evaluation summaries do not contain fixture provenance",
    fixed = TRUE
  )

  baseline <- theme_a_downgrade_accept(
    replay,
    "catch_count",
    "variable"
  )
  candidate <- theme_a_downgrade_accept(
    replay,
    "catch_count",
    "property"
  )
  write_theme_a_json(baseline, baseline_path)
  write_theme_a_json(candidate, candidate_path)
  comparison <- run_theme_a_script(c(
    "compare",
    paste0("--baseline=", shQuote(baseline_path)),
    paste0("--candidate=", shQuote(candidate_path))
  ))

  expect_true(comparison$status > 0L, info = comparison$output)
  expect_match(comparison$output, "catch-count-property", fixed = TRUE)
})

test_that("Theme A compare excludes nonblocking-case regressions", {
  cases <- jsonlite::read_json(
    theme_a_fixture_path("cases-v1.json"),
    simplifyVector = FALSE
  )
  replay <- jsonlite::read_json(
    theme_a_fixture_path("replay-v1.json"),
    simplifyVector = FALSE
  )
  catch_count <- which(vapply(
    cases$cases,
    function(case) identical(case$case_id, "catch_count"),
    logical(1)
  ))[[1L]]
  cases$cases[[catch_count]]$blocking <- FALSE
  candidate <- theme_a_downgrade_accept(
    replay,
    "catch_count",
    "property"
  )

  cases_path <- tempfile("theme-a-nonblocking-cases-", fileext = ".json")
  candidate_path <- tempfile(
    "theme-a-nonblocking-candidate-",
    fileext = ".json"
  )
  withr::defer(unlink(c(cases_path, candidate_path)))
  write_theme_a_json(cases, cases_path)
  write_theme_a_json(candidate, candidate_path)

  comparison <- run_theme_a_script(c(
    "compare",
    paste0("--cases=", shQuote(cases_path)),
    paste0(
      "--baseline=",
      shQuote(theme_a_fixture_path("replay-v1.json"))
    ),
    paste0("--candidate=", shQuote(candidate_path))
  ))

  expect_equal(comparison$status, 0L, info = comparison$output)
  expect_match(comparison$output, "NO_REGRESSION", fixed = TRUE)
})
