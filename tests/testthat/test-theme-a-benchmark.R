theme_a_script_path <- function() {
  normalizePath(
    testthat::test_path("..", "..", "scripts", "theme-a-benchmark.R"),
    winslash = "/",
    mustWork = FALSE
  )
}

run_theme_a_script <- function(args = character()) {
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

theme_a_sha256 <- function(path) {
  command <- Sys.which("sha256sum")
  args <- shQuote(path)
  if (!nzchar(command)) {
    command <- Sys.which("shasum")
    args <- c("-a", "256", shQuote(path))
  }
  testthat::skip_if(!nzchar(command), "SHA-256 command is unavailable")
  output <- system2(command, args, stdout = TRUE)
  strsplit(trimws(output[[1L]]), "\\s+")[[1L]][[1L]]
}

theme_a_value_sha256 <- function(value) {
  path <- tempfile("theme-a-value-")
  on.exit(unlink(path), add = TRUE)
  value_json <- as.character(jsonlite::toJSON(
    value,
    auto_unbox = TRUE,
    null = "null",
    na = "null",
    digits = NA
  ))
  writeLines(enc2utf8(value_json), path, useBytes = TRUE)
  theme_a_sha256(path)
}

theme_a_repo_root <- function() {
  normalizePath(
    file.path(dirname(theme_a_script_path()), ".."),
    winslash = "/",
    mustWork = TRUE
  )
}

theme_a_repo_relative_path <- function(path) {
  root <- paste0(theme_a_repo_root(), "/")
  absolute <- normalizePath(path, winslash = "/", mustWork = TRUE)
  stopifnot(startsWith(absolute, root))
  substring(absolute, nchar(root) + 1L)
}

theme_a_git_value <- function(args) {
  output <- system2(
    "git",
    c("-C", theme_a_repo_root(), args),
    stdout = TRUE,
    stderr = FALSE
  )
  stopifnot(length(output) > 0L)
  output[[1L]]
}

theme_a_git_status <- function(args) {
  suppressWarnings(system2(
    "git",
    c("-C", theme_a_repo_root(), args),
    stdout = FALSE,
    stderr = FALSE
  ))
}

theme_a_clean_source_hash <- function() {
  path <- tempfile("theme-a-clean-source-")
  on.exit(unlink(path), add = TRUE)
  writeLines("", path, useBytes = TRUE)
  theme_a_sha256(path)
}

theme_a_scalar_key <- function(x) {
  if (is.null(x)) {
    return("<NA>")
  }
  if (length(x) != 1L || is.list(x)) {
    return(as.character(jsonlite::toJSON(
      x,
      auto_unbox = TRUE,
      null = "null",
      na = "null"
    )))
  }
  if (is.logical(x)) {
    return(if (isTRUE(x)) "true" else "false")
  }
  if (is.na(x)) {
    return("<NA>")
  }
  as.character(x)
}

theme_a_target_key <- function(row) {
  columns <- c(
    "dataset_id",
    "table_id",
    "column_name",
    "code_value",
    "dictionary_role",
    "target_scope",
    "target_sdp_file",
    "target_sdp_field",
    "search_query"
  )
  paste(
    vapply(columns, function(column) {
      theme_a_scalar_key(row[[column]])
    }, character(1)),
    collapse = "\u001f"
  )
}

theme_a_capture_path <- function(prefix = "theme-a-capture-") {
  directory <- tempfile(prefix)
  dir.create(directory, recursive = TRUE)
  file.path(directory, "capture.json")
}

write_theme_a_reviewed_capture <- function(capture, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  raw <- capture
  raw$evidence_status <- "unreviewed_staging"
  raw$review <- list(
    status = "unreviewed",
    sanitized = FALSE,
    reviewed_by = NULL,
    reviewed_at = NULL,
    notes = NULL,
    pre_sanitization_sha256 = NULL
  )
  raw_path <- file.path(dirname(path), "capture.raw.json")
  checksum_path <- paste0(raw_path, ".sha256")
  write_theme_a_json(raw, raw_path)
  raw_hash <- theme_a_sha256(raw_path)
  writeLines(
    paste(raw_hash, basename(raw_path)),
    checksum_path,
    useBytes = TRUE
  )
  capture$review$pre_sanitization_sha256 <- raw_hash
  write_theme_a_json(capture, path)
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

theme_a_test_capture <- function(run_id,
                                 cases,
                                 replay,
                                 evaluation,
                                 provider = "openrouter",
                                 model = "openai/gpt-5.4-mini",
                                 git_sha = NULL,
                                 git_tree = NULL,
                                 source_state_sha256 = NULL,
                                 endpoint = "https://openrouter.ai/api/v1/chat/completions") {
  if (is.null(git_sha)) {
    git_sha <- theme_a_git_value(c("rev-parse", "HEAD"))
  }
  if (is.null(git_tree)) {
    git_tree <- theme_a_git_value(
      c("rev-parse", paste0(git_sha, "^{tree}"))
    )
  }
  if (is.null(source_state_sha256)) {
    source_state_sha256 <- theme_a_clean_source_hash()
  }
  cases_path <- theme_a_fixture_path("cases-v1.json")
  schema_path <- theme_a_fixture_path("schema-v1.json")
  ontology_manifest_path <- theme_a_fixture_path(
    "ontology-manifest-v1.json"
  )
  capture <- list(
    schema_version = "theme-a-capture-v1",
    run_id = run_id,
    mode = "live",
    evidence_status = "reviewed_sanitized",
    review = list(
      status = "reviewed",
      sanitized = TRUE,
      reviewed_by = "Theme A test maintainer",
      reviewed_at = "2026-07-28T00:02:00Z",
      notes = "Synthetic capture used only by the replay harness tests.",
      pre_sanitization_sha256 = NULL
    ),
    provenance = list(
      created_at = "2026-07-28T00:00:00Z",
      completed_at = "2026-07-28T00:01:00Z",
      git_sha = git_sha,
      git_tree = git_tree,
      git_dirty = FALSE,
      source_state_sha256 = source_state_sha256,
      git_branch = "feature/theme-a-semantic-review",
      package_version = as.character(
        read.dcf(file.path(theme_a_repo_root(), "DESCRIPTION"))[1L, "Version"]
      ),
      cases_fixture = theme_a_repo_relative_path(cases_path),
      cases_fixture_sha256 = theme_a_sha256(cases_path),
      schema_fixture = theme_a_repo_relative_path(schema_path),
      schema_fixture_sha256 = theme_a_sha256(schema_path),
      ontology_manifest_fixture = theme_a_repo_relative_path(
        ontology_manifest_path
      ),
      ontology_manifest_fixture_sha256 = theme_a_sha256(
        ontology_manifest_path
      ),
      benchmark_script_sha256 = theme_a_sha256(theme_a_script_path()),
      retrieval_mode = "frozen_fixture",
      provider = provider,
      configured_model = model,
      resolved_models = model,
      endpoint = endpoint,
      api_key_environment = "OPENROUTER_API_KEY",
      ontology_provenance = cases$ontology_provenance
    ),
    execution_error = NULL,
    interaction_events = list(),
    assessment_lineage = list(),
    cases = replay$cases,
    evaluation = evaluation
  )
  for (i in seq_along(replay$cases)) {
    observed <- replay$cases[[i]]
    target_keys <- vapply(
      observed$assessment_rows,
      theme_a_target_key,
      character(1)
    )
    interaction_id <- sprintf("interaction-%04d", i)
    provider_items <- lapply(
      observed$assessment_rows,
      function(row) {
        list(
          dictionary_role = row$dictionary_role,
          decision = row$llm_decision,
          confidence = row$llm_confidence,
          rationale = row$llm_rationale
        )
      }
    )
    messages <- list(list(
      role = "user",
      content = paste("sanitized fixture", observed$case_id)
    ))
    raw_response <- list(
      id = paste0("response-", run_id, "-", i),
      model = model,
      choices = list(list(
        message = list(
          content = as.character(jsonlite::toJSON(
            list(
              bundle_summary = paste(
                "Synthetic response for",
                observed$case_id
              ),
              assessments = provider_items
            ),
            auto_unbox = TRUE,
            null = "null",
            na = "null"
          ))
        )
      ))
    )
    capture$interaction_events[[i]] <- list(
      interaction_id = interaction_id,
      event_type = "llm_request",
      stage = "bundle_initial",
      bundle_key = paste(
        observed$final_dictionary_rows[[1L]]$dataset_id,
        observed$final_dictionary_rows[[1L]]$table_id,
        observed$final_dictionary_rows[[1L]]$column_name,
        sep = "\r"
      ),
      target_keys = as.list(target_keys),
      assessment_target_keys = as.list(target_keys),
      started_at = "2026-07-28T00:00:00Z",
      provider = provider,
      configured_model = model,
      resolved_model = model,
      endpoint = endpoint,
      messages = messages,
      request_sha256 = theme_a_value_sha256(messages),
      response_status = 200L,
      raw_response = raw_response,
      response_sha256 = theme_a_value_sha256(raw_response),
      provider_response_id = raw_response$id,
      error = NULL,
      elapsed_seconds = 1
    )
    for (target_key in target_keys) {
      capture$assessment_lineage[[length(
        capture$assessment_lineage
      ) + 1L]] <- list(
        case_id = observed$case_id,
        target_key = target_key,
        outcome = "provider",
        interaction_id = interaction_id,
        interaction_stage = "bundle_initial",
        dictionary_role = observed$assessment_rows[[
          which(target_keys == target_key)
        ]]$dictionary_role,
        assessment_sha256 = theme_a_value_sha256(
          observed$assessment_rows[[which(target_keys == target_key)]]
        ),
        provider_assessment_sha256 = theme_a_value_sha256(
          provider_items[[which(target_keys == target_key)]]
        ),
        fallback_reason = NULL
      )
    }
  }
  capture
}

theme_a_replay_evaluation <- function() {
  path <- tempfile("theme-a-evaluation-", fileext = ".json")
  on.exit(unlink(path), add = TRUE)
  result <- run_theme_a_script(c(
    "replay",
    paste0("--output=", shQuote(path))
  ))
  stopifnot(identical(result$status, 0L))
  jsonlite::read_json(path, simplifyVector = FALSE)
}

test_that("Theme A benchmark defaults to a passing offline replay", {
  result <- run_theme_a_script()

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

test_that("Theme A compare enforces a three-run exact-model cohort gate", {
  cases_path <- theme_a_fixture_path("cases-v1.json")
  schema_path <- theme_a_fixture_path("schema-v1.json")
  replay_path <- theme_a_fixture_path("replay-v1.json")
  cases <- jsonlite::read_json(cases_path, simplifyVector = FALSE)
  replay <- jsonlite::read_json(replay_path, simplifyVector = FALSE)
  evaluation_path <- tempfile("theme-a-evaluation-", fileext = ".json")
  capture_paths <- vapply(
    seq_len(3L),
    function(i) theme_a_capture_path(
      paste0("theme-a-capture-", i, "-")
    ),
    character(1)
  )
  withr::defer(unlink(evaluation_path))
  withr::defer(unlink(
    unique(dirname(capture_paths)),
    recursive = TRUE,
    force = TRUE
  ))

  replay_result <- run_theme_a_script(c(
    "replay",
    paste0("--output=", shQuote(evaluation_path))
  ))
  expect_equal(replay_result$status, 0L, info = replay_result$output)
  evaluation <- jsonlite::read_json(
    evaluation_path,
    simplifyVector = FALSE
  )

  provider <- "openrouter"
  model <- "openai/gpt-5.4-mini"
  for (i in seq_along(capture_paths)) {
    capture <- theme_a_test_capture(
      run_id = paste0("test-cohort-", i),
      cases = cases,
      replay = replay,
      evaluation = evaluation,
      provider = provider,
      model = model
    )
    write_theme_a_reviewed_capture(capture, capture_paths[[i]])
  }

  gate <- run_theme_a_script(c(
    "compare",
    paste0("--cohort=", paste(capture_paths, collapse = ",")),
    paste0("--expected-provider=", provider),
    paste0("--expected-model=", model)
  ))

  expect_equal(gate$status, 0L, info = gate$output)
  expect_match(
    gate$output,
    "Theme A live cohort gate: PASS",
    fixed = TRUE
  )
  expect_match(gate$output, "catch_weight_advisory: 3/3", fixed = TRUE)
})

test_that("Theme A live prompt capture identifies bundle retry targets", {
  skip_if_not(
    file.exists(theme_a_script_path()),
    "Theme A benchmark script is excluded from the built source package"
  )
  harness <- new.env(parent = globalenv())
  sys.source(theme_a_script_path(), envir = harness)
  schema <- jsonlite::read_json(
    theme_a_fixture_path("schema-v1.json"),
    simplifyVector = FALSE
  )
  contracts <- harness$schema_contracts(schema)
  cases <- jsonlite::read_json(
    theme_a_fixture_path("cases-v1.json"),
    simplifyVector = FALSE
  )
  targets <- dplyr::bind_rows(cases$cases[[1L]]$targets)
  target_index <- harness$.capture_target_index(targets, contracts)
  bundle_key <- target_index$rows[[1L]]$bundle_key
  slots <- lapply(target_index$rows, function(indexed) {
    list(
      dictionary_role = indexed$role,
      candidates = list(list(retrieval_pass = 1L))
    )
  })
  payload <- list(
    bundle_key = bundle_key,
    slots = slots
  )
  messages <- list(list(
    role = "user",
    content = paste(
      "Semantic bundle payload:",
      jsonlite::toJSON(
        payload,
        auto_unbox = TRUE,
        pretty = TRUE,
        null = "null"
      ),
      "\n\nReturn JSON only."
    )
  ))

  initial <- harness$.capture_interaction_context(
    messages,
    target_index
  )
  expect_equal(initial$stage, "bundle_initial")
  expect_setequal(
    initial$assessment_target_keys,
    vapply(target_index$rows, `[[`, character(1), "target_key")
  )

  payload$review_round <- 2L
  payload$slots[[1L]]$candidates[[1L]]$retrieval_pass <- 2L
  messages[[1L]]$content <- paste(
    "Semantic bundle payload:",
    jsonlite::toJSON(
      payload,
      auto_unbox = TRUE,
      pretty = TRUE,
      null = "null"
    ),
    "\n\nReturn JSON only."
  )
  retry <- harness$.capture_interaction_context(messages, target_index)

  expect_equal(retry$stage, "bundle_reassessment")
  expect_equal(
    retry$assessment_target_keys,
    target_index$rows[[1L]]$target_key
  )
})

test_that("Theme A capture requires target-specific interaction lineage", {
  cases <- jsonlite::read_json(
    theme_a_fixture_path("cases-v1.json"),
    simplifyVector = FALSE
  )
  replay <- jsonlite::read_json(
    theme_a_fixture_path("replay-v1.json"),
    simplifyVector = FALSE
  )
  evaluation <- theme_a_replay_evaluation()
  mutations <- list(
    missing_lineage = function(capture) {
      capture$assessment_lineage[[1L]] <- NULL
      capture
    },
    unknown_interaction = function(capture) {
      capture$assessment_lineage[[1L]]$interaction_id <- "unknown"
      capture
    },
    unrelated_target = function(capture) {
      capture$interaction_events[[1L]]$assessment_target_keys <-
        as.list("not-a-target")
      capture
    },
    assessment_hash = function(capture) {
      capture$assessment_lineage[[1L]]$assessment_sha256 <-
        paste(rep("e", 64L), collapse = "")
      capture
    },
    provider_assessment_hash = function(capture) {
      capture$assessment_lineage[[1L]]$provider_assessment_sha256 <-
        paste(rep("e", 64L), collapse = "")
      capture
    },
    request_hash = function(capture) {
      capture$interaction_events[[1L]]$request_sha256 <-
        paste(rep("e", 64L), collapse = "")
      capture
    }
  )

  for (name in names(mutations)) {
    path <- theme_a_capture_path(
      paste0("theme-a-lineage-", name, "-")
    )
    withr::defer(unlink(
      dirname(path),
      recursive = TRUE,
      force = TRUE
    ))
    capture <- theme_a_test_capture(
      run_id = paste0("lineage-", name),
      cases = cases,
      replay = replay,
      evaluation = evaluation
    )
    write_theme_a_reviewed_capture(mutations[[name]](capture), path)
    result <- run_theme_a_script(c(
      "compare",
      paste0("--baseline=", shQuote(path)),
      paste0(
        "--candidate=",
        shQuote(theme_a_fixture_path("replay-v1.json"))
      )
    ))
    expect_true(result$status > 0L, info = paste(name, result$output))
  }

  fallback_path <- theme_a_capture_path("theme-a-lineage-fallback-")
  withr::defer(unlink(
    dirname(fallback_path),
    recursive = TRUE,
    force = TRUE
  ))
  fallback <- theme_a_test_capture(
    run_id = "lineage-explicit-fallback",
    cases = cases,
    replay = replay,
    evaluation = evaluation
  )
  fallback_case <- which(vapply(
    fallback$cases,
    function(observed) {
      any(vapply(
        observed$assessment_rows,
        function(row) identical(row$llm_decision, "review"),
        logical(1)
      ))
    },
    logical(1)
  ))[[1L]]
  fallback_assessment <- which(vapply(
    fallback$cases[[fallback_case]]$assessment_rows,
    function(row) identical(row$llm_decision, "review"),
    logical(1)
  ))[[1L]]
  fallback_key <- theme_a_target_key(
    fallback$cases[[fallback_case]]$assessment_rows[[fallback_assessment]]
  )
  fallback$cases[[
    fallback_case
  ]]$assessment_rows[[fallback_assessment]]$llm_error <-
    "Provider response was unusable; deterministic shortlist retained."
  lineage_index <- which(vapply(
    fallback$assessment_lineage,
    function(lineage) identical(lineage$target_key, fallback_key),
    logical(1)
  ))[[1L]]
  fallback$assessment_lineage[[lineage_index]]$outcome <-
    "deterministic_fallback"
  fallback$assessment_lineage[[lineage_index]][
    "interaction_id"
  ] <- list(NULL)
  fallback$assessment_lineage[[lineage_index]]$interaction_stage <-
    "deterministic_fallback"
  fallback$assessment_lineage[[lineage_index]]$assessment_sha256 <-
    theme_a_value_sha256(
      fallback$cases[[
        fallback_case
      ]]$assessment_rows[[fallback_assessment]]
    )
  fallback$assessment_lineage[[lineage_index]][
    "provider_assessment_sha256"
  ] <- list(NULL)
  fallback$assessment_lineage[[lineage_index]]$fallback_reason <-
    "Provider response was unusable; deterministic shortlist retained."
  write_theme_a_reviewed_capture(fallback, fallback_path)
  fallback_result <- run_theme_a_script(c(
    "compare",
    paste0("--baseline=", shQuote(fallback_path)),
    paste0(
      "--candidate=",
      shQuote(theme_a_fixture_path("replay-v1.json"))
    )
  ))
  expect_equal(
    fallback_result$status,
    0L,
    info = fallback_result$output
  )
})

test_that("Theme A captures bind every source artifact to the recorded commit", {
  cases <- jsonlite::read_json(
    theme_a_fixture_path("cases-v1.json"),
    simplifyVector = FALSE
  )
  replay <- jsonlite::read_json(
    theme_a_fixture_path("replay-v1.json"),
    simplifyVector = FALSE
  )
  evaluation <- theme_a_replay_evaluation()
  capture <- theme_a_test_capture(
    run_id = "commit-artifact-mismatch",
    cases = cases,
    replay = replay,
    evaluation = evaluation
  )
  introduction_sha <- theme_a_git_value(c(
    "log",
    "--diff-filter=A",
    "--format=%H",
    "--",
    "scripts/theme-a-benchmark.R"
  ))
  parent_ref <- paste0(introduction_sha, "^")
  skip_if(
    theme_a_git_status(c("rev-parse", "--verify", "--quiet", parent_ref)) != 0L,
    "Full Git history is required for commit-to-artifact provenance mutation"
  )
  older_sha <- theme_a_git_value(c("rev-parse", parent_ref))
  capture$provenance$git_sha <- older_sha
  capture$provenance$git_tree <- theme_a_git_value(
    c("rev-parse", paste0(older_sha, "^{tree}"))
  )

  capture_path <- theme_a_capture_path("theme-a-commit-artifact-mismatch-")
  withr::defer(unlink(
    dirname(capture_path),
    recursive = TRUE,
    force = TRUE
  ))
  write_theme_a_reviewed_capture(capture, capture_path)
  result <- run_theme_a_script(c(
    "compare",
    paste0("--baseline=", shQuote(capture_path)),
    paste0(
      "--candidate=",
      shQuote(theme_a_fixture_path("replay-v1.json"))
    )
  ))

  expect_true(result$status > 0L, info = result$output)
  expect_match(
    result$output,
    "Recorded Git commit",
    fixed = TRUE
  )
})

test_that("Theme A cohort rejects mixed provider, model, source, and endpoint", {
  cases <- jsonlite::read_json(
    theme_a_fixture_path("cases-v1.json"),
    simplifyVector = FALSE
  )
  replay <- jsonlite::read_json(
    theme_a_fixture_path("replay-v1.json"),
    simplifyVector = FALSE
  )
  evaluation_path <- tempfile("theme-a-evaluation-", fileext = ".json")
  withr::defer(unlink(evaluation_path))
  replay_result <- run_theme_a_script(c(
    "replay",
    paste0("--output=", shQuote(evaluation_path))
  ))
  expect_equal(replay_result$status, 0L, info = replay_result$output)
  evaluation <- jsonlite::read_json(
    evaluation_path,
    simplifyVector = FALSE
  )
  provider <- "openrouter"
  model <- "openai/gpt-5.4-mini"
  mutations <- list(
    provider = function(capture) {
      capture$provenance$provider <- "openai"
      capture$interaction_events[[1L]]$provider <- "openai"
      capture
    },
    model = function(capture) {
      replacement <- "openai/gpt-5.4"
      capture$provenance$configured_model <- replacement
      capture$provenance$resolved_models <- replacement
      capture$interaction_events[[1L]]$configured_model <- replacement
      capture$interaction_events[[1L]]$resolved_model <- replacement
      capture$interaction_events[[1L]]$raw_response$model <- replacement
      capture
    },
    git_sha = function(capture) {
      capture$provenance$git_sha <- paste(rep("e", 40L), collapse = "")
      capture
    },
    git_tree = function(capture) {
      capture$provenance$git_tree <- paste(rep("e", 40L), collapse = "")
      capture
    },
    dirty_state = function(capture) {
      capture$provenance$git_dirty <- TRUE
      capture
    },
    clean_source_hash = function(capture) {
      capture$provenance$source_state_sha256 <-
        paste(rep("e", 64L), collapse = "")
      capture
    },
    endpoint = function(capture) {
      replacement <- "https://example.org/v1/chat/completions"
      capture$provenance$endpoint <- replacement
      capture$interaction_events[[1L]]$endpoint <- replacement
      capture
    }
  )

  for (name in names(mutations)) {
    paths <- vapply(
      seq_len(3L),
      function(i) theme_a_capture_path(
        paste0("theme-a-", name, "-", i, "-")
      ),
      character(1)
    )
    withr::defer(unlink(
      unique(dirname(paths)),
      recursive = TRUE,
      force = TRUE
    ))
    captures <- lapply(seq_len(3L), function(i) {
      theme_a_test_capture(
        run_id = paste0("mixed-", name, "-", i),
        cases = cases,
        replay = replay,
        evaluation = evaluation,
        provider = provider,
        model = model
      )
    })
    captures[[3L]] <- mutations[[name]](captures[[3L]])
    for (i in seq_along(paths)) {
      write_theme_a_reviewed_capture(captures[[i]], paths[[i]])
    }
    gate <- run_theme_a_script(c(
      "compare",
      paste0("--cohort=", paste(paths, collapse = ",")),
      paste0("--expected-provider=", provider),
      paste0("--expected-model=", model)
    ))
    expect_true(gate$status > 0L, info = paste(name, gate$output))
  }
})

test_that("Theme A cohort requires three independent provider runs", {
  cases <- jsonlite::read_json(
    theme_a_fixture_path("cases-v1.json"),
    simplifyVector = FALSE
  )
  replay <- jsonlite::read_json(
    theme_a_fixture_path("replay-v1.json"),
    simplifyVector = FALSE
  )
  evaluation <- theme_a_replay_evaluation()
  paths <- vapply(
    seq_len(3L),
    function(i) theme_a_capture_path(
      paste0("theme-a-provider-run-", i, "-")
    ),
    character(1)
  )
  withr::defer(unlink(
    unique(dirname(paths)),
    recursive = TRUE,
    force = TRUE
  ))
  captures <- lapply(seq_len(3L), function(i) {
    theme_a_test_capture(
      run_id = paste0("provider-run-", i),
      cases = cases,
      replay = replay,
      evaluation = evaluation
    )
  })
  captures[[3L]]$interaction_events <- captures[[1L]]$interaction_events
  for (i in seq_along(paths)) {
    write_theme_a_reviewed_capture(captures[[i]], paths[[i]])
  }

  gate <- run_theme_a_script(c(
    "compare",
    paste0("--cohort=", paste(paths, collapse = ",")),
    "--expected-provider=openrouter",
    "--expected-model=openai/gpt-5.4-mini"
  ))

  expect_true(gate$status > 0L, info = gate$output)
  expect_match(
    gate$output,
    "independent provider runs: FALSE",
    fixed = TRUE
  )
})

test_that("Theme A reviewed captures require raw checksum lineage", {
  cases <- jsonlite::read_json(
    theme_a_fixture_path("cases-v1.json"),
    simplifyVector = FALSE
  )
  replay <- jsonlite::read_json(
    theme_a_fixture_path("replay-v1.json"),
    simplifyVector = FALSE
  )
  evaluation <- theme_a_replay_evaluation()
  provider <- "openrouter"
  model <- "openai/gpt-5.4-mini"

  for (mutation in c("review_hash", "raw_capture")) {
    paths <- vapply(
      seq_len(3L),
      function(i) theme_a_capture_path(
        paste0("theme-a-raw-", mutation, "-", i, "-")
      ),
      character(1)
    )
    withr::defer(unlink(
      unique(dirname(paths)),
      recursive = TRUE,
      force = TRUE
    ))
    for (i in seq_along(paths)) {
      capture <- theme_a_test_capture(
        run_id = paste0("raw-", mutation, "-", i),
        cases = cases,
        replay = replay,
        evaluation = evaluation,
        provider = provider,
        model = model
      )
      write_theme_a_reviewed_capture(capture, paths[[i]])
    }

    if (identical(mutation, "review_hash")) {
      capture <- jsonlite::read_json(
        paths[[1L]],
        simplifyVector = FALSE
      )
      capture$review$pre_sanitization_sha256 <-
        paste(rep("e", 64L), collapse = "")
      write_theme_a_json(capture, paths[[1L]])
    } else {
      raw_path <- file.path(dirname(paths[[1L]]), "capture.raw.json")
      Sys.chmod(raw_path, mode = "0644")
      cat("\n", file = raw_path, append = TRUE)
    }

    gate <- run_theme_a_script(c(
      "compare",
      paste0("--cohort=", paste(paths, collapse = ",")),
      paste0("--expected-provider=", provider),
      paste0("--expected-model=", model)
    ))
    expect_true(gate$status > 0L, info = paste(mutation, gate$output))
    expect_match(
      gate$output,
      "raw-capture checksum lineage|checksum sidecar",
      perl = TRUE
    )
  }
})

test_that("Theme A cohort promotion recomputes validated promoted captures", {
  cases <- jsonlite::read_json(
    theme_a_fixture_path("cases-v1.json"),
    simplifyVector = FALSE
  )
  replay <- jsonlite::read_json(
    theme_a_fixture_path("replay-v1.json"),
    simplifyVector = FALSE
  )
  evaluation <- theme_a_replay_evaluation()
  provider <- "openrouter"
  model <- "openai/gpt-5.4-mini"
  suffix <- paste0(
    Sys.getpid(),
    "-",
    as.integer(stats::runif(1L, 1e6, 9e6))
  )
  staging_root <- file.path(
    theme_a_repo_root(),
    "artifacts",
    "theme-a",
    paste0("testthat-cohort-", suffix)
  )
  capture_paths <- file.path(
    staging_root,
    paste0("run-", seq_len(3L)),
    "capture.json"
  )
  promoted_files <- character()
  withr::defer({
    Sys.chmod(promoted_files, mode = "0644")
    unlink(promoted_files, force = TRUE)
    unlink(staging_root, recursive = TRUE, force = TRUE)
  })

  for (i in seq_along(capture_paths)) {
    run_id <- paste0("testthat-manifest-", suffix, "-", i)
    capture <- theme_a_test_capture(
      run_id = run_id,
      cases = cases,
      replay = replay,
      evaluation = evaluation,
      provider = provider,
      model = model
    )
    write_theme_a_reviewed_capture(capture, capture_paths[[i]])
    promoted <- run_theme_a_script(c(
      "promote",
      paste0("--capture=", shQuote(capture_paths[[i]]))
    ))
    expect_equal(promoted$status, 0L, info = promoted$output)
    capture_hash <- theme_a_sha256(capture_paths[[i]])
    promoted_capture <- file.path(
      theme_a_repo_root(),
      "notes",
      "evidence",
      "theme-a",
      "captures",
      paste0(run_id, "-", capture_hash, ".json")
    )
    raw_hash <- jsonlite::read_json(
      capture_paths[[i]],
      simplifyVector = FALSE
    )$review$pre_sanitization_sha256
    promoted_raw <- file.path(
      theme_a_repo_root(),
      "notes",
      "evidence",
      "theme-a",
      "captures",
      paste0(run_id, "-raw-", raw_hash, ".json")
    )
    promoted_files <- c(
      promoted_files,
      promoted_raw,
      paste0(promoted_raw, ".sha256"),
      promoted_capture,
      paste0(promoted_capture, ".sha256")
    )
  }

  gate_path <- file.path(staging_root, "cohort-gate.json")
  gate_result <- run_theme_a_script(c(
    "compare",
    paste0("--cohort=", paste(capture_paths, collapse = ",")),
    paste0("--expected-provider=", provider),
    paste0("--expected-model=", model),
    paste0("--output=", shQuote(gate_path))
  ))
  expect_equal(gate_result$status, 0L, info = gate_result$output)
  gate <- jsonlite::read_json(gate_path, simplifyVector = FALSE)

  mutations <- list(
    conflicting_provider = function(value) {
      value$provider <- "openai"
      value
    },
    duplicate_capture = function(value) {
      value$captures[[2L]] <- value$captures[[1L]]
      value
    }
  )
  for (name in names(mutations)) {
    spoof_path <- file.path(staging_root, paste0(name, ".json"))
    write_theme_a_json(mutations[[name]](gate), spoof_path)
    result <- run_theme_a_script(c(
      "promote",
      paste0("--cohort-manifest=", shQuote(spoof_path))
    ))
    expect_true(result$status > 0L, info = paste(name, result$output))
  }

  promoted_gate <- run_theme_a_script(c(
    "promote",
    paste0("--cohort-manifest=", shQuote(gate_path))
  ))
  expect_equal(promoted_gate$status, 0L, info = promoted_gate$output)
  gate_hash <- theme_a_sha256(gate_path)
  promoted_cohort <- file.path(
    theme_a_repo_root(),
    "notes",
    "evidence",
    "theme-a",
    "captures",
    paste0("cohort-", gate_hash, ".json")
  )
  promoted_files <- c(
    promoted_files,
    promoted_cohort,
    paste0(promoted_cohort, ".sha256")
  )
})

test_that("Theme A promotion has no overwrite escape hatch", {
  result <- run_theme_a_script(c(
    "promote",
    "--overwrite"
  ))

  expect_true(result$status > 0L, info = result$output)
  expect_match(result$output, "Unsupported argument '--overwrite'", fixed = TRUE)
})
