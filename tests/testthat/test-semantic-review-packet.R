# The semantic review packet contract (S16 step 1, hub item B-326): the
# emitter, the builder, the ingester, the conformance fixtures shared with
# metasalmonpy, the sentinel that no model is called, and the Theme A
# oracles replayed through the ingester. Execplan sections 2, 3, 4 and 7.

# -----------------------------------------------------------------------------
# The canonical JSON emitter
# -----------------------------------------------------------------------------

test_that("the emitter renders every type by one rule and round-trips through jsonlite", {
  value <- list(
    whole = 2, frac = 0.1 + 0.2, neg = -3.5, big = 9007199254740991, zero = 0, nan = NaN, na = NA_character_,
    flag = TRUE, off = FALSE, none = NULL, text = "quote \" backslash \\ newline \n tab \t",
    empty_array = metasalmon:::.ms_json_array(), empty_object = metasalmon:::.ms_json_object(),
    one = metasalmon:::.ms_json_array("only"), nested = list(k = list(list(i = 1L), list(i = 2L)))
  )
  bytes <- metasalmon:::.ms_semantic_review_canonical_bytes(value)
  text <- rawToChar(bytes)
  expect_true(endsWith(text, "\n"))
  expect_match(text, "\"whole\": 2,\n", fixed = TRUE)
  expect_match(text, "\"frac\": 0.30000000000000004,\n", fixed = TRUE)
  expect_match(text, "\"big\": 9007199254740991,\n", fixed = TRUE)
  expect_match(text, "\"zero\": 0,\n", fixed = TRUE)
  expect_match(text, "\"nan\": null,\n", fixed = TRUE)
  expect_match(text, "\"na\": null,\n", fixed = TRUE)
  expect_match(text, "\"none\": null,\n", fixed = TRUE)
  expect_match(text, "\"empty_array\": [],\n", fixed = TRUE)
  expect_match(text, "\"empty_object\": {},\n", fixed = TRUE)
  expect_match(text, "\"one\": [\n    \"only\"\n  ],\n", fixed = TRUE)
  expect_match(text, "\"text\": \"quote \\\" backslash \\\\ newline \\n tab \\t\",\n", fixed = TRUE)

  path <- withr::local_tempfile(fileext = ".json")
  writeBin(bytes, path)
  back <- metasalmon:::.ms_semantic_review_read_json(path)
  expect_identical(metasalmon:::.ms_semantic_review_canonical_bytes(back), bytes)
})

test_that("the emitter refuses a vector it cannot tell from a scalar", {
  expect_error(metasalmon:::.ms_semantic_review_canonical_bytes(list(a = c(1, 2))), "length one")
})

test_that("control characters are escaped the way Python's json module escapes them", {
  text <- rawToChar(metasalmon:::.ms_semantic_review_canonical_bytes(list(bell = intToUtf8(7L), del = intToUtf8(127L))))
  expect_match(text, "\"bell\": \"\\u0007\"", fixed = TRUE)
  expect_match(text, paste0("\"del\": \"", intToUtf8(127L), "\""), fixed = TRUE)
})

test_that("packet_id excludes packet_id and producer and nothing else", {
  packet <- list(packet_version = "x", packet_id = "old", pass = 1L, producer = list(version = "1"), units = list())
  id <- metasalmon:::.ms_semantic_review_packet_id(packet)
  packet$producer$version <- "2"
  packet$packet_id <- "other"
  expect_identical(metasalmon:::.ms_semantic_review_packet_id(packet), id)
  packet$pass <- 2L
  expect_false(identical(metasalmon:::.ms_semantic_review_packet_id(packet), id))
})

# -----------------------------------------------------------------------------
# The shared fixtures
# -----------------------------------------------------------------------------

fixture_manifest <- function() {
  semantic_review_read_json(file.path(semantic_review_fixture_root(), "manifest.json"))
}

test_that("every fixture file matches the manifest, and the manifest lists every file", {
  root <- semantic_review_fixture_root()
  manifest <- fixture_manifest()
  expect_identical(manifest$packet_version, metasalmon:::.ms_semantic_review_packet_version())
  files <- sort(setdiff(list.files(root, recursive = TRUE), "manifest.json"), method = "radix")
  expect_identical(names(manifest$files), files)
  for (file in files) {
    expect_identical(semantic_review_sha256_file(file.path(root, file)), manifest$files[[file]], info = file)
  }
  # Every path, with the prefix a source tarball adds, stays within the 100
  # bytes a portable tarball stores; past that R CMD check reports a
  # non-portable file name. Retires if R drops that check, which it will not.
  tarball_paths <- paste0("metasalmon/tests/testthat/fixtures/semantic-review/v1/", files)
  too_long <- tarball_paths[nchar(tarball_paths, type = "bytes") > 100L]
  expect_length(too_long, 0L)
})

test_that("the vendored instructions and schema are what the packets embed", {
  instructions <- metasalmon:::.ms_semantic_review_instructions()
  packet <- semantic_review_read_json(file.path(semantic_review_fixture_root(), "bundle_accept", "packet-1.json"))
  expect_identical(packet$instructions, instructions)
  expect_true(all(charToRaw(instructions) < as.raw(128L)))
  schema <- jsonlite::fromJSON(metasalmon:::.ms_semantic_review_schema_path(), simplifyVector = FALSE)
  expect_identical(schema$`$defs`$packet$properties$packet_version$const, metasalmon:::.ms_semantic_review_packet_version())
  expect_identical(schema$`$defs`$assessment_row$required, as.list(metasalmon:::.ms_llm_assessment_cols()))
  expect_identical(schema$`$defs`$findings_row$required, as.list(metasalmon:::.ms_semantic_review_findings_cols()))
})

test_that("a golden packet validates against the vendored schema", {
  skip_if_not_installed("jsonvalidate")
  validator <- jsonvalidate::json_validator(metasalmon:::.ms_semantic_review_schema_path(), engine = "ajv")
  for (case_id in c("bundle_accept", "target_units", "retry_gain")) {
    for (file in c("packet-1.json", "packet-2.json")) {
      path <- file.path(semantic_review_fixture_root(), case_id, file)
      if (!file.exists(path)) next
      expect_true(validator(readLines(path, warn = FALSE) |> paste(collapse = "\n"), verbose = TRUE), info = paste(case_id, file))
    }
  }
})

conformance_cases <- function() {
  root <- semantic_review_fixture_root()
  cases <- list.dirs(root, full.names = FALSE, recursive = FALSE)
  cases[file.exists(file.path(root, cases, "harness-1.csv"))]
}

# Build a case's packet in a fresh review directory and return what a test
# needs to go on.
build_case <- function(case_id) {
  case_dir <- file.path(semantic_review_fixture_root(), case_id)
  input <- semantic_review_read_json(file.path(case_dir, "input.json"))
  dict <- semantic_review_case_dictionary(input)
  review_dir <- file.path(withr::local_tempdir(.local_envir = parent.frame()), "review")
  context_text <- unlist(input$context_text)
  built <- write_semantic_review_packet(dict, context_text = context_text, review_dir = review_dir, quiet = TRUE)
  list(case_dir = case_dir, input = input, dict = dict, review_dir = review_dir, built = built)
}

expect_case_pass <- function(case, result, pass, counter) {
  expected_dir <- file.path(case$case_dir, "expected")
  status <- semantic_review_read_json(file.path(expected_dir, paste0("status-", pass, ".json")))
  info <- paste(basename(case$case_dir), "pass", pass)
  expect_identical(result$status, status$status, info = info)
  expect_identical(as.integer(result$pass), status$pass, info = info)
  expect_identical(result$packet_id, status$packet_id, info = info)
  expect_identical(!is.null(result$next_packet), status$has_next_packet, info = info)
  expect_identical(as.list(result$summary$decisions), status$summary$decisions, info = info)
  expect_identical(result$summary$errors, status$summary$errors, info = info)
  expect_identical(result$summary$downgrades, status$summary$downgrades, info = info)
  expect_identical(result$summary$escalations, status$summary$escalations, info = info)
  expect_identical(result$summary$retries, status$summary$retries, info = info)
  expect_identical(result$summary$kept_pass_1, status$summary$kept_pass_1, info = info)
  expect_identical(counter$calls, status$search_calls, info = info)
  semantic_review_expect_frames_equal(
    result$assessments,
    semantic_review_read_csv(file.path(expected_dir, paste0("record-", pass, ".csv"))),
    info = paste(info, "record")
  )
  semantic_review_expect_frames_equal(
    result$findings,
    semantic_review_read_csv(file.path(expected_dir, paste0("findings-", pass, ".csv"))),
    info = paste(info, "findings")
  )
  semantic_review_expect_frames_equal(
    result$suggestions,
    semantic_review_read_csv(file.path(expected_dir, paste0("suggestions-", pass, ".csv"))),
    info = paste(info, "suggestions")
  )
  # The persisted record is the returned one, typed.
  semantic_review_expect_frames_equal(
    semantic_review_read_csv(file.path(case$review_dir, "semantic-llm-assessments.csv")),
    result$assessments,
    info = paste(info, "persisted record")
  )
}

test_that("every conformance case builds the golden packet byte for byte, producer aside", {
  for (case_id in conformance_cases()) {
    case <- build_case(case_id)
    golden <- semantic_review_read_json(file.path(case$case_dir, "packet-1.json"))
    built <- semantic_review_read_json(case$built$path)
    expect_identical(case$built$packet_id, golden$packet_id, info = case_id)
    expect_identical(
      metasalmon:::.ms_semantic_review_canonical_bytes(semantic_review_strip_producer(built)),
      metasalmon:::.ms_semantic_review_canonical_bytes(semantic_review_strip_producer(golden)),
      info = case_id
    )
    expect_identical(built$producer$implementation, "metasalmon", info = case_id)
  }
})

test_that("every conformance case ingests to the golden record, findings, suggestions and status", {
  responses <- semantic_review_search_responses()
  for (case_id in conformance_cases()) {
    case <- build_case(case_id)
    counter <- new.env(parent = emptyenv())
    counter$calls <- 0L
    counter$log <- list()
    search_fn <- semantic_review_fake_search(responses, counter)
    harness <- file.path(case$case_dir, "harness-1.csv")
    result <- suppressWarnings(ingest_semantic_assessments(
      case$dict, assessments = harness, review_dir = case$review_dir, search_fn = search_fn, quiet = TRUE
    ))
    expect_case_pass(case, result, 1L, counter)

    if (!is.null(result$next_packet)) {
      golden_2 <- semantic_review_read_json(file.path(case$case_dir, "packet-2.json"))
      built_2 <- semantic_review_read_json(result$next_packet)
      expect_identical(
        metasalmon:::.ms_semantic_review_canonical_bytes(semantic_review_strip_producer(built_2)),
        metasalmon:::.ms_semantic_review_canonical_bytes(semantic_review_strip_producer(golden_2)),
        info = paste(case_id, "pass-2 packet")
      )
      counter$calls <- 0L
      result_2 <- ingest_semantic_assessments(
        case$dict, assessments = file.path(case$case_dir, "harness-2.csv"),
        review_dir = case$review_dir, search_fn = search_fn, quiet = TRUE
      )
      expect_case_pass(case, result_2, 2L, counter)
      expect_null(result_2$next_packet)
    }
  }
})

test_that("the reject variants raise their stable codes and write nothing", {
  case_dir <- file.path(semantic_review_fixture_root(), "file_errors")
  reject <- semantic_review_read_json(file.path(case_dir, "reject.json"))
  base <- build_case(reject$base_case)
  before <- list.files(base$review_dir)
  for (variant in reject$variants) {
    args <- list(base$dict, review_dir = base$review_dir, search_fn = function(...) stop("no search"), quiet = TRUE)
    if (!is.null(variant$assessments)) {
      args$assessments <- file.path(case_dir, variant$assessments)
    }
    if (!is.null(variant$packet)) {
      args$packet <- file.path(case_dir, variant$packet)
      args$assessments <- args$assessments %||% file.path(case_dir, "..", reject$base_case, "harness-1.csv")
    }
    if (!is.null(variant$expected_packet_id)) {
      args$packet_id <- variant$expected_packet_id
      args$assessments <- args$assessments %||% file.path(case_dir, "..", reject$base_case, "harness-1.csv")
    }
    if (identical(variant$expected_code, "no_pass_2")) {
      pass_2_name <- file.path(withr::local_tempdir(), "semantic-assessments-pass-2.csv")
      file.copy(file.path(case_dir, "..", reject$base_case, "harness-1.csv"), pass_2_name)
      args$assessments <- pass_2_name
      args$packet_id <- base$built$packet_id
    }
    condition <- tryCatch(do.call(ingest_semantic_assessments, args), error = function(e) e)
    expect_s3_class(condition, "metasalmon_semantic_review_error")
    expect_s3_class(condition, paste0("metasalmon_semantic_review_", variant$expected_code))
    expect_identical(condition$code, variant$expected_code, info = variant$name)
    expect_identical(list.files(base$review_dir), before, info = variant$name)
  }
})

test_that("a pass-2 packet that does not descend from the session's pass-1 packet is refused", {
  case <- build_case("retry_gain")
  responses <- semantic_review_search_responses()
  result <- ingest_semantic_assessments(
    case$dict, assessments = file.path(case$case_dir, "harness-1.csv"),
    review_dir = case$review_dir, search_fn = semantic_review_fake_search(responses), quiet = TRUE
  )
  expect_identical(result$status, "awaiting_pass_2")
  orphan <- semantic_review_read_json(result$next_packet)
  orphan$parent_packet_id <- strrep("1", 64)
  orphan$packet_id <- metasalmon:::.ms_semantic_review_packet_id(orphan)
  orphan_path <- withr::local_tempfile(fileext = ".json")
  writeBin(metasalmon:::.ms_semantic_review_canonical_bytes(orphan), orphan_path)
  condition <- tryCatch(
    ingest_semantic_assessments(
      case$dict, assessments = file.path(case$case_dir, "harness-2.csv"),
      packet = orphan_path, review_dir = case$review_dir, quiet = TRUE
    ),
    error = function(e) e
  )
  expect_identical(condition$code, "provenance")
  # A pass-2 ingest with no continuation packet is refused too.
  fresh <- build_case("bundle_accept")
  condition <- tryCatch(
    ingest_semantic_assessments(
      fresh$dict, assessments = file.path(case$case_dir, "harness-2.csv"),
      packet = result$next_packet, review_dir = fresh$review_dir, quiet = TRUE
    ),
    error = function(e) e
  )
  expect_identical(condition$code, "no_pass_2")
})

test_that("harness text is redacted at capture and no unredacted copy survives", {
  case <- build_case("bundle_accept")
  harness <- semantic_review_read_csv(file.path(case$case_dir, "harness-1.csv"))
  harness$llm_error[[1]] <- "Provider said: api_key=sk-live-9f8e7d6c5b4a was rejected."
  harness$llm_rationale[[2]] <- "Judged with Authorization: Bearer top-secret-token-42 in the header."

  # Written at the packet's default location: the file is replaced with its
  # redacted form after the ingest, with a warning.
  default_path <- file.path(case$review_dir, "semantic-assessments-pass-1.csv")
  semantic_review_write_harness(harness, default_path, packet_id = case$built$packet_id)
  expect_warning(
    result <- ingest_semantic_assessments(case$dict, review_dir = case$review_dir, search_fn = function(...) stop("no search"), quiet = TRUE),
    "redacted"
  )
  expect_false(any(grepl("sk-live-9f8e7d6c5b4a", result$assessments$llm_error, fixed = TRUE)))
  expect_false(any(grepl("top-secret-token-42", result$assessments$llm_rationale, fixed = TRUE)))
  expect_true(any(!is.na(result$assessments$llm_error)))
  for (file in list.files(case$review_dir, full.names = TRUE)) {
    text <- readChar(file, file.info(file)$size, useBytes = TRUE)
    expect_false(grepl("sk-live-9f8e7d6c5b4a", text, fixed = TRUE), info = basename(file))
    expect_false(grepl("top-secret-token-42", text, fixed = TRUE), info = basename(file))
  }

  # Written elsewhere: the record is redacted, the harness's own file is not
  # touched, and nothing is copied into review/.
  elsewhere <- build_case("bundle_accept")
  outside <- file.path(withr::local_tempdir(), "my-answers.csv")
  semantic_review_write_harness(harness, outside, packet_id = elsewhere$built$packet_id)
  before <- readChar(outside, file.info(outside)$size, useBytes = TRUE)
  expect_warning(
    result <- ingest_semantic_assessments(elsewhere$dict, assessments = outside, review_dir = elsewhere$review_dir, search_fn = function(...) stop("no search"), quiet = TRUE),
    "redacted"
  )
  expect_identical(readChar(outside, file.info(outside)$size, useBytes = TRUE), before)
  expect_false(file.exists(file.path(elsewhere$review_dir, "semantic-assessments-pass-1.csv")))
  expect_false(any(grepl("sk-live-9f8e7d6c5b4a", result$assessments$llm_error, fixed = TRUE)))
})

test_that("a stale assessment file is refused after the packet is rebuilt", {
  case <- build_case("bundle_accept")
  first_id <- case$built$packet_id
  # A harness answers the first packet at the default location.
  file.copy(file.path(case$case_dir, "harness-1.csv"), file.path(case$review_dir, "semantic-assessments-pass-1.csv"))
  writeLines(first_id, file.path(case$review_dir, "semantic-assessments-pass-1.csv.packet-id"))
  # The packet is rebuilt with more context, so its id changes; the old
  # answers name the old packet and are refused rather than recorded.
  rebuilt <- write_semantic_review_packet(case$dict, context_text = "Some new context about the catch.", review_dir = case$review_dir, overwrite = TRUE, quiet = TRUE)
  expect_false(identical(rebuilt$packet_id, first_id))
  file.copy(file.path(case$case_dir, "harness-1.csv"), file.path(case$review_dir, "semantic-assessments-pass-1.csv"))
  writeLines(first_id, file.path(case$review_dir, "semantic-assessments-pass-1.csv.packet-id"))
  condition <- tryCatch(
    ingest_semantic_assessments(case$dict, review_dir = case$review_dir, search_fn = function(...) stop("no search"), quiet = TRUE),
    error = function(e) e
  )
  expect_identical(condition$code, "packet_mismatch")
  expect_false(file.exists(file.path(case$review_dir, "semantic-llm-assessments.csv")))
  # The argument can name the packet instead of the sidecar, and it must agree too.
  condition <- tryCatch(
    ingest_semantic_assessments(case$dict, packet_id = first_id, review_dir = case$review_dir, search_fn = function(...) stop("no search"), quiet = TRUE),
    error = function(e) e
  )
  expect_identical(condition$code, "packet_mismatch")
})

test_that("a harness value in a package-owned column is overwritten with one warning naming the columns", {
  case <- build_case("row_errors")
  # The case also plants secrets, so the ingest warns twice; collect both and
  # assert the one this test is about.
  messages <- character()
  result <- withCallingHandlers(
    ingest_semantic_assessments(
      case$dict, assessments = file.path(case$case_dir, "harness-1.csv"),
      review_dir = case$review_dir, search_fn = function(...) stop("no search"), quiet = TRUE
    ),
    warning = function(w) {
      messages <<- c(messages, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  expect_length(grep("package-owned", messages), 1L)
  expect_match(grep("package-owned", messages, value = TRUE), "llm_selected_label", fixed = TRUE)
  row <- result$assessments[result$assessments$column_name == "FIELD_13", ]
  expect_true(is.na(row$llm_selected_label))
  expect_false(identical(row$llm_context_sources, "should-be-overwritten"))
})

test_that("an IRI the packet did not offer is never applied", {
  case <- build_case("row_errors")
  result <- suppressWarnings(ingest_semantic_assessments(
    case$dict, assessments = file.path(case$case_dir, "harness-1.csv"),
    review_dir = case$review_dir, search_fn = function(...) stop("no search"), quiet = TRUE
  ))
  not_offered <- result$assessments[result$assessments$column_name == "FIELD_01", ]
  expect_true(is.na(not_offered$llm_decision))
  expect_true(is.na(not_offered$llm_selected_iri))
  expect_match(not_offered$llm_error, "not a candidate the packet offered", fixed = TRUE)
  expect_false("https://example.org/not-offered" %in% result$suggestions$iri)
  expect_false(any(result$suggestions$llm_selected[result$suggestions$column_name == "FIELD_01"]))
  # An index that is not a whole number is refused, never truncated.
  fractional <- result$assessments[result$assessments$column_name == "FIELD_04", ]
  expect_true(is.na(fractional$llm_selected_candidate_index))
  expect_match(fractional$llm_error, "whole number", fixed = TRUE)
  # A downgrade with no rationale never starts with NA.
  expect_false(any(startsWith(result$assessments$llm_rationale[!is.na(result$assessments$llm_rationale)], "NA ")))
})

# -----------------------------------------------------------------------------
# The record's shape cannot drift
# -----------------------------------------------------------------------------

test_that("error, downgraded, escalated and success rows carry identical names and types", {
  case <- build_case("row_errors")
  result <- suppressWarnings(ingest_semantic_assessments(
    case$dict, assessments = file.path(case$case_dir, "harness-1.csv"),
    review_dir = case$review_dir, search_fn = function(...) stop("no search"), quiet = TRUE
  ))
  escalated <- build_case("reject_escalates")
  result_2 <- ingest_semantic_assessments(
    escalated$dict, assessments = file.path(escalated$case_dir, "harness-1.csv"),
    review_dir = escalated$review_dir, search_fn = function(...) stop("no search"), quiet = TRUE
  )
  rows <- dplyr::bind_rows(result$assessments, result_2$assessments)
  expect_identical(names(rows), metasalmon:::.ms_llm_assessment_cols())
  prototypes <- metasalmon:::.ms_llm_assessment_prototypes()
  for (col in names(prototypes)) {
    expect_identical(class(rows[[col]]), class(prototypes[[col]]), info = col)
  }
  expect_true(any(!is.na(rows$llm_error)))
  expect_true(any(rows$llm_decision %in% "request_new_term" & !is.na(rows$llm_escalated_from)))
  expect_true(any(rows$llm_decision %in% "accept"))
  expect_identical(names(result$findings), metasalmon:::.ms_semantic_review_findings_cols())
})

test_that("semantic_llm_assessments(path) reads the persisted record with its findings", {
  hits <- function(query, role = NA_character_, sources = NULL, ...) {
    tibble::tibble(
      label = paste("Term", 1:2, "for", role),
      iri = paste0("https://example.org/candidates/", role, "Term", 1:2),
      source = "smn", ontology = "smn", role = role,
      match_type = "label_exact", definition = paste("A", role, "term."), score = c(4.5, 3.5)
    )
  }
  path <- file.path(withr::local_tempdir(), "record-package")
  suppressMessages(with_mocked_bindings(
    find_terms = hits,
    create_sdp(
      list(spawners = data.frame(stream_name = c("Bear Creek", "Elk River"), spawner_count = c(120L, 340L))),
      path = path, dataset_id = "demo-1", table_id = "spawners",
      semantic_max_per_role = 1, seed_semantics = TRUE, seed_verbose = FALSE,
      check_updates = FALSE, overwrite = TRUE
    )
  ))
  expect_null(semantic_llm_assessments(path))
  built <- write_semantic_review_packet(path, search_fn = hits, quiet = TRUE)
  packet <- semantic_review_read_json(built$path)
  slots <- metasalmon:::.ms_semantic_review_slots(packet)
  harness <- dplyr::bind_rows(lapply(slots, function(slot) {
    if (nrow(slot$candidates) == 0L) {
      return(semantic_review_harness_row(slot$target, llm_decision = "review", llm_confidence = 0.2, llm_rationale = "Nothing offered."))
    }
    semantic_review_harness_row(
      slot$target, llm_decision = "accept", llm_confidence = 0.9,
      llm_selected_candidate_index = 1L, llm_selected_iri = slot$candidates$iri[[1]], llm_rationale = "First."
    )
  }))
  # A data frame carries no sidecar, so the packet is named by argument; without
  # it the file is unbound.
  unbound <- tryCatch(
    ingest_semantic_assessments(path, assessments = harness, search_fn = function(...) stop("no search"), quiet = TRUE),
    error = function(e) e
  )
  expect_identical(unbound$code, "packet_unbound")
  result <- ingest_semantic_assessments(
    path, assessments = harness, packet_id = built$packet_id,
    search_fn = function(...) stop("no search"), quiet = TRUE
  )
  record <- semantic_llm_assessments(path)
  expect_s3_class(record, "tbl_df")
  semantic_review_expect_frames_equal(record, result$assessments)
  expect_identical(names(attr(record, "semantic_validator_findings")), metasalmon:::.ms_semantic_review_findings_cols())
  # The suggestions were rewritten with the assessment columns, and the review
  # console reads them.
  suggestions <- semantic_suggestions(path)
  expect_true("llm_decision" %in% names(suggestions))
  review <- suppressMessages(review_semantics(path))
  expect_true(any(review$llm_decision %in% "accept"))
  # The metadata CSVs were not touched.
  dictionary <- read_salmon_datapackage(path)$dictionary
  expect_false(any(grepl("example.org/candidates", dictionary$term_iri) & !grepl("^REVIEW", dictionary$term_iri)))
})

# -----------------------------------------------------------------------------
# The sentinel: no model call ever, and no network except through search_fn
# -----------------------------------------------------------------------------

provider_symbols <- function() {
  c(
    ".ms_llm_request_with_retries", ".ms_llm_chat_json_request", ".ms_llm_chat_request",
    ".ms_llm_resolve_config", ".ms_llm_review_request_assessment", ".ms_llm_assess_one_record",
    ".ms_assess_semantic_suggestions_llm", ".ms_assess_semantic_candidate_records",
    ".ms_assess_semantic_bundles", ".ms_llm_explore_record", ".ms_semantic_bundle_retry"
  )
}

test_that("the builder and the ingester make no model call: a stopping provider is never reached", {
  stop_fn <- function(...) stop("a model-provider entry point was called")
  bindings <- stats::setNames(rep(list(stop_fn), length(provider_symbols())), provider_symbols())
  bindings <- bindings[vapply(names(bindings), function(name) exists(name, envir = asNamespace("metasalmon"), inherits = FALSE), logical(1))]
  do.call(local_mocked_bindings, c(bindings, list(.package = "metasalmon")))
  local_mocked_bindings(GET = stop_fn, POST = stop_fn, .package = "httr")
  local_mocked_bindings(req_perform = stop_fn, .package = "httr2")

  # An in-memory build with a stopping search_fn succeeds.
  case <- build_case("bundle_accept")
  expect_true(file.exists(case$built$path))
  # An ingest with no retry never calls search_fn.
  result <- ingest_semantic_assessments(
    case$dict, assessments = file.path(case$case_dir, "harness-1.csv"),
    review_dir = case$review_dir, search_fn = function(...) stop("search must not be called"), quiet = TRUE
  )
  expect_identical(result$status, "complete")
  # An ingest with a retry calls search_fn once per usable query, and nothing else.
  retry <- build_case("retry_gain")
  counter <- new.env(parent = emptyenv())
  counter$calls <- 0L
  counter$log <- list()
  result <- ingest_semantic_assessments(
    retry$dict, assessments = file.path(retry$case_dir, "harness-1.csv"),
    review_dir = retry$review_dir, search_fn = semantic_review_fake_search(semantic_review_search_responses(), counter), quiet = TRUE
  )
  expect_identical(counter$calls, 1L)
  expect_identical(counter$log[[1]]$query, "fishing gear type")
})

test_that("a package build calls search_fn once per distinct query, role and source set", {
  hits <- function(query, role = NA_character_, sources = NULL, ...) {
    tibble::tibble(
      label = paste("Term", 1:2, "for", role),
      iri = paste0("https://example.org/candidates/", role, "Term", 1:2),
      source = "smn", ontology = "smn", role = role,
      match_type = "label_exact", definition = "A term.", score = c(4.5, 3.5)
    )
  }
  path <- file.path(withr::local_tempdir(), "counting-package")
  suppressMessages(with_mocked_bindings(
    find_terms = hits,
    create_sdp(
      list(spawners = data.frame(stream_name = c("Bear Creek", "Elk River"), spawner_count = c(120L, 340L))),
      path = path, dataset_id = "demo-1", table_id = "spawners",
      semantic_max_per_role = 1, seed_semantics = TRUE, seed_verbose = FALSE,
      check_updates = FALSE, overwrite = TRUE
    )
  ))
  log <- list()
  counting <- function(query, role, sources) {
    log[[length(log) + 1L]] <<- list(query = query, role = role, sources = sources)
    hits(query, role, sources)
  }
  built <- write_semantic_review_packet(path, search_fn = counting, quiet = TRUE)
  keys <- vapply(log, function(entry) paste(entry$query, entry$role, paste(entry$sources, collapse = ","), sep = "|"), character(1))
  expect_identical(length(keys), length(unique(keys)))
  expect_identical(length(keys), built$targets)
  # The same call with the same inputs writes the same bytes.
  again <- file.path(withr::local_tempdir(), "review-again")
  built_again <- write_semantic_review_packet(path, search_fn = counting, review_dir = again, quiet = TRUE)
  expect_identical(built_again$packet_id, built$packet_id)
})

test_that("no provider symbol is reachable from the two exported functions", {
  ns <- asNamespace("metasalmon")
  package_fns <- Filter(function(name) is.function(get(name, envir = ns)), ls(ns, all.names = TRUE))
  reachable <- character()
  frontier <- c("write_semantic_review_packet", "ingest_semantic_assessments")
  while (length(frontier) > 0L) {
    name <- frontier[[1]]
    frontier <- frontier[-1]
    if (name %in% reachable) next
    reachable <- c(reachable, name)
    called <- intersect(codetools::findGlobals(get(name, envir = ns), merge = FALSE)$functions, package_fns)
    # `search_fn`'s default, `find_terms()`, is the one network path the
    # contract allows; it is retrieval, not a model call, and stays.
    frontier <- c(frontier, setdiff(called, reachable))
  }
  expect_length(intersect(reachable, provider_symbols()), 0L)
  expect_false(any(grepl("^\\.ms_llm_(chat|request|messages|generic|decomposition|batch|exploration)", reachable)))
  # Retrieval is reached only through the `search_fn` argument, whose default
  # is `find_terms()`; a default value is not a call, so it is not in the walk.
  expect_identical(formals(write_semantic_review_packet)$search_fn, quote(find_terms))
  expect_identical(formals(ingest_semantic_assessments)$search_fn, quote(find_terms))
})

test_that("write_semantic_review_packet refuses a parsed object as context and a session with answers", {
  case <- build_case("bundle_accept")
  expect_error(
    write_semantic_review_packet(case$dict, context_files = data.frame(x = 1), review_dir = file.path(withr::local_tempdir(), "r")),
    "character vector of local file paths"
  )
  # A packet alone may be rewritten; a session with answers may not.
  expect_no_error(write_semantic_review_packet(case$dict, review_dir = case$review_dir, quiet = TRUE))
  file.copy(file.path(case$case_dir, "harness-1.csv"), file.path(case$review_dir, "semantic-assessments-pass-1.csv"))
  expect_error(write_semantic_review_packet(case$dict, review_dir = case$review_dir, quiet = TRUE), "already exists")
  expect_no_error(write_semantic_review_packet(case$dict, review_dir = case$review_dir, overwrite = TRUE, quiet = TRUE))
  expect_false(file.exists(file.path(case$review_dir, "semantic-assessments-pass-1.csv")))
  expect_error(write_semantic_review_packet(case$dict), "review_dir")
})

test_that("apply_semantic_suggestions(strategy = 'llm') applies only an accept", {
  frame <- tibble::tibble(
    dataset_id = "d1", table_id = "t1", column_name = c("a", "b"), code_value = NA_character_,
    dictionary_role = "variable", target_scope = "column", target_sdp_file = "column_dictionary.csv",
    target_sdp_field = "term_iri", target_row_key = c("d1/t1/a", "d1/t1/b"), search_query = "q",
    label = c("A", "B"), iri = c("https://example.org/a", "https://example.org/b"), source = "smn",
    ontology = "smn", definition = "x", score = 1,
    llm_selected = c(TRUE, TRUE), llm_decision = c("accept", "review"), llm_confidence = c(0.9, 0.9)
  )
  dict <- tibble::tibble(dataset_id = "d1", table_id = "t1", column_name = c("a", "b"), column_role = "measurement", term_iri = NA_character_)
  out <- suppressMessages(apply_semantic_suggestions(dict, suggestions = frame, strategy = "llm", verbose = FALSE))
  expect_identical(out$term_iri[out$column_name == "a"], "https://example.org/a")
  expect_true(is.na(out$term_iri[out$column_name == "b"]))
})

# -----------------------------------------------------------------------------
# The Theme A oracles, replayed through the ingester
# -----------------------------------------------------------------------------

theme_a_script_env <- local({
  env <- NULL
  function() {
    if (is.null(env)) {
      path <- testthat::test_path("..", "..", "scripts", "theme-a-benchmark.R")
      skip_if_not(file.exists(path), "scripts/theme-a-benchmark.R is not in the built package")
      env <<- new.env(parent = globalenv())
      sys.source(path, envir = env)
    }
    env
  }
})

theme_a_case_events <- function(case_id) {
  case <- build_case(case_id)
  result <- ingest_semantic_assessments(
    case$dict, assessments = file.path(case$case_dir, "harness-1.csv"),
    review_dir = case$review_dir, search_fn = function(...) stop("no search"), quiet = TRUE
  )
  expected <- semantic_review_read_json(file.path(case$case_dir, "expected", "events.json"))
  list(case = case, result = result, expected = expected)
}

test_that("the Theme A cases pass their recorded oracles through the ingester and the prefill step", {
  env <- theme_a_script_env()
  cases <- semantic_review_read_json(testthat::test_path("fixtures", "theme-a", "cases-v1.json"))
  observed <- lapply(cases$cases, function(case) {
    run <- theme_a_case_events(semantic_review_theme_a_case_id(case$case_id))
    list(case_id = case$case_id, events = run$expected$events)
  })
  replay_like <- list(cases = observed)
  evaluation <- env$evaluate_oracles(cases, replay_like)
  failures <- vapply(evaluation$failures, function(f) paste(f$case_id, f$rule_id, f$message), character(1))
  expect_identical(evaluation$status, "pass", info = paste(failures, collapse = "; "))
})

test_that("the recorded events are what the ingester produces today, not only what was written down", {
  env <- theme_a_script_env()
  for (case_id in c("ta_catch_count", "ta_gap", "ta_gcdfo_routing")) {
    run <- theme_a_case_events(case_id)
    # Rebuild the events from the result the way the fixture generator did.
    original <- run$case$dict
    attr(original, "semantic_targets") <- NULL
    attr(original, "semantic_suggestions") <- NULL
    allowed_roles <- metasalmon:::.ms_create_sdp_llm_auto_apply_roles()
    auto <- metasalmon:::.ms_prepare_llm_auto_apply_suggestions(original, run$result$suggestions, allowed_roles = allowed_roles)
    final <- apply_semantic_suggestions(original, suggestions = auto, strategy = "llm", roles = allowed_roles, overwrite = FALSE, verbose = FALSE)
    final <- metasalmon:::.ms_mark_reviewed_dictionary_iris(final, original_dict = original, suggestions = auto, strategy = "llm")
    gap_input <- final
    attr(gap_input, "semantic_suggestions") <- run$result$suggestions
    attr(gap_input, "semantic_llm_assessments") <- run$result$assessments
    attr(gap_input, "semantic_targets") <- run$result$targets
    gaps <- detect_semantic_term_gaps(gap_input)
    requests <- if (nrow(gaps) > 0L) render_ontology_term_request(gaps, scope = "auto", ask = FALSE, profile_name = "theme-a-benchmark") else tibble::tibble()
    events <- env$events_from_package_outputs(run$result$assessments, final, gaps, requests)
    key <- function(e) paste(vapply(e, function(x) paste(names(x), unlist(x), collapse = ";"), character(1)), collapse = "|")
    expect_identical(key(events), key(run$expected$events), info = case_id)
  }
})

test_that("three adversarial harness answers are caught by the deterministic layer", {
  env <- theme_a_script_env()
  cases <- semantic_review_read_json(testthat::test_path("fixtures", "theme-a", "cases-v1.json"))
  by_id <- stats::setNames(cases$cases, vapply(cases$cases, `[[`, character(1), "case_id"))

  # Accepting the fork-length method for catch_count fails the forbidden
  # rule through SEM_METHOD_EVIDENCE_REQUIRED: the accept becomes review.
  method <- theme_a_case_events("ta_method_accept")
  expect_true("SEM_METHOD_EVIDENCE_REQUIRED" %in% method$result$findings$code)
  method_row <- method$result$assessments[method$result$assessments$dictionary_role == "method", ]
  expect_identical(method_row$llm_decision, "review")
  evaluation <- env$evaluate_oracles(list(cases = list(by_id$catch_count)), list(cases = list(list(case_id = "catch_count", events = method$expected$events))))
  expect_identical(evaluation$status, "pass")

  # Accepting CatchContext beside CatchAbundance raises SEM_REDUNDANT_CATCH_CONTEXT.
  context <- theme_a_case_events("ta_ctx_accept")
  expect_true("SEM_REDUNDANT_CATCH_CONTEXT" %in% context$result$findings$code)
  constraint_row <- context$result$assessments[context$result$assessments$dictionary_role == "constraint", ]
  expect_identical(constraint_row$llm_decision, "review")
  evaluation <- env$evaluate_oracles(list(cases = list(by_id$catch_count)), list(cases = list(list(case_id = "catch_count", events = context$expected$events))))
  expect_identical(evaluation$status, "pass")

  # A reject_shortlist on synthetic_structured_gap still surfaces the gap
  # through escalation.
  gap <- theme_a_case_events("ta_gap_reject")
  row <- gap$result$assessments
  expect_identical(row$llm_decision, "request_new_term")
  expect_identical(row$llm_escalated_from, "reject_shortlist")
  expect_true(any(vapply(gap$expected$events, function(e) identical(e$type, "gap") && identical(e$scope, "uncertain"), logical(1))))
  evaluation <- env$evaluate_oracles(list(cases = list(by_id$synthetic_structured_gap)), list(cases = list(list(case_id = "synthetic_structured_gap", events = gap$expected$events))))
  expect_identical(evaluation$status, "pass")
})

# -----------------------------------------------------------------------------
# Blank slots with no candidates reach a package-path packet
# -----------------------------------------------------------------------------

zero_candidate_package <- function(path, code_scope = "factor") {
  # Retrieval finds nothing for the water temperature column, so create_sdp()
  # leaves every one of its slots blank with no suggestion row; the gear codes
  # are a factor column's code list, whose slots create_sdp() seeds under the
  # default scope.
  hits <- function(query, role = NA_character_, sources = NULL, ...) {
    if (grepl("water|temp", query, ignore.case = TRUE)) {
      return(tibble::tibble())
    }
    tibble::tibble(
      label = paste("Term", 1:2, "for", role),
      iri = paste0("https://example.org/candidates/", role, "/", gsub("[^a-z]", "-", tolower(query)), 1:2),
      source = "smn", ontology = "smn", role = role,
      match_type = "label_exact", definition = "A term.", score = c(4.5, 3.5)
    )
  }
  suppressMessages(with_mocked_bindings(
    find_terms = hits,
    create_sdp(
      list(catch = data.frame(
        water_temp = c(8.5, 9.1, 7.4, 10.2),
        gear_type = factor(c("GN", "SN", "GN", "TR")),
        catch_weight = c(12.5, 8.1, 20.4, 3.3)
      )),
      path = path, dataset_id = "demo-1", table_id = "catch",
      semantic_max_per_role = 1, seed_semantics = TRUE, seed_verbose = FALSE,
      semantic_code_scope = code_scope, check_updates = FALSE, overwrite = TRUE
    )
  ))
  hits
}

test_that("a blank slot with no candidates reaches the packet through discovery", {
  path <- file.path(withr::local_tempdir(), "zero-candidate")
  hits <- zero_candidate_package(path)
  suggestions <- semantic_suggestions(path)
  expect_false(any(suggestions$column_name %in% "water_temp"))
  dictionary <- read_salmon_datapackage(path)$dictionary
  expect_true(is.na(dictionary$term_iri[dictionary$column_name == "water_temp"]) ||
    !nzchar(dictionary$term_iri[dictionary$column_name == "water_temp"]))

  built <- write_semantic_review_packet(path, search_fn = hits, quiet = TRUE)
  packet <- semantic_review_read_json(built$path)
  slots <- metasalmon:::.ms_semantic_review_slots(packet)
  sample_slots <- Filter(
    function(s) identical(s$target$column_name[[1]], "water_temp") && identical(s$target$target_sdp_file[[1]], "column_dictionary.csv"),
    slots
  )
  expect_true(length(sample_slots) >= 1L)
  expect_true(all(vapply(sample_slots, function(s) nrow(s$candidates) == 0L, logical(1))))
  # Recovered as the bundle it is: a measurement column's slots judged together.
  water_units <- Filter(function(u) identical(u$unit_key, "bundle:demo-1/catch/water_temp"), packet$units)
  expect_length(water_units, 1L)
  expect_identical(water_units[[1]]$unit_kind, "bundle")
  expect_identical(packet$pins$retrieval$code_scope, "factor")
  expect_identical(nrow(built$not_covered), 0L)

  # The harness answers the zero-candidate slot as the instructions say.
  harness <- dplyr::bind_rows(lapply(slots, function(slot) {
    if (nrow(slot$candidates) == 0L) {
      semantic_review_harness_row(slot$target, llm_decision = "request_new_term", llm_confidence = 0.6,
        llm_rationale = "No candidate was offered.", llm_new_term_label = "Water temperature")
    } else {
      semantic_review_harness_row(slot$target, llm_decision = "review", llm_confidence = 0.5, llm_rationale = "Later.")
    }
  }))
  result <- ingest_semantic_assessments(path, assessments = harness, packet_id = built$packet_id,
    search_fn = function(...) stop("no search"), quiet = TRUE)
  row <- result$assessments[result$assessments$column_name %in% "water_temp" &
    result$assessments$target_sdp_file %in% "column_dictionary.csv", ]
  expect_true(nrow(row) >= 1L)
  expect_true(all(row$llm_decision == "request_new_term"))
  gaps <- detect_semantic_term_gaps(result$dictionary)
  expect_true("water_temp" %in% gaps$column_name)
})

test_that("a blank code-level slot outside the code scope is reported as not covered, never dropped", {
  path <- file.path(withr::local_tempdir(), "code-scope")
  # Created with no code-level seeding, so every gear code slot is blank and
  # has no suggestion row.
  hits <- zero_candidate_package(path, code_scope = "none")
  suggestions <- semantic_suggestions(path)
  expect_false(any(suggestions$target_sdp_file %in% "codes.csv"))

  narrow <- write_semantic_review_packet(path, search_fn = hits, code_scope = "none",
    review_dir = file.path(withr::local_tempdir(), "narrow"), quiet = TRUE)
  expect_true(nrow(narrow$not_covered) > 0L)
  expect_true(all(narrow$not_covered$target_sdp_file == "codes.csv"))
  narrow_packet <- semantic_review_read_json(narrow$path)
  expect_identical(narrow_packet$pins$retrieval$code_scope, "none")
  narrow_slots <- metasalmon:::.ms_semantic_review_slots(narrow_packet)
  expect_false(any(vapply(narrow_slots, function(s) identical(s$target$target_sdp_file[[1]], "codes.csv"), logical(1))))

  wide <- write_semantic_review_packet(path, search_fn = hits, code_scope = "all",
    review_dir = file.path(withr::local_tempdir(), "wide"), quiet = TRUE)
  expect_identical(nrow(wide$not_covered), 0L)
  wide_slots <- metasalmon:::.ms_semantic_review_slots(semantic_review_read_json(wide$path))
  code_slots <- Filter(function(s) identical(s$target$target_sdp_file[[1]], "codes.csv"), wide_slots)
  expect_setequal(vapply(code_slots, function(s) s$target$slot_id[[1]], character(1)), narrow$not_covered$slot_id)
})

# -----------------------------------------------------------------------------
# Codex review on #194: three findings, each pinned
# -----------------------------------------------------------------------------

test_that("a package whose every lookup found nothing still gets a packet holding its blank slots", {
  nothing <- function(query, role = NA_character_, sources = NULL, ...) tibble::tibble()
  path <- file.path(withr::local_tempdir(), "all-zero")
  suppressMessages(with_mocked_bindings(
    find_terms = nothing,
    create_sdp(
      list(catch = data.frame(catch_weight = c(12.5, 8.1, 20.4), water_temp = c(8.5, 9.1, 7.4))),
      path = path, dataset_id = "demo-1", table_id = "catch",
      semantic_max_per_role = 1, seed_semantics = TRUE, seed_verbose = FALSE,
      check_updates = FALSE, overwrite = TRUE
    )
  ))
  # No shortlist was written, and the console refuses to open a queue.
  expect_null(semantic_suggestions(path))
  expect_false(file.exists(file.path(path, "semantic_suggestions.csv")))
  expect_error(suppressMessages(review_semantics(path)), "No semantic suggestions")

  built <- expect_no_warning(write_semantic_review_packet(path, search_fn = nothing, quiet = TRUE))
  packet <- semantic_review_read_json(built$path)
  slots <- metasalmon:::.ms_semantic_review_slots(packet)
  expect_true(all(vapply(slots, function(s) nrow(s$candidates) == 0L, logical(1))))
  # Both measurement columns come back as bundles; the table's observation
  # unit, blank too, is a target unit beside them.
  kinds <- vapply(packet$units, `[[`, character(1), "unit_kind")
  keys <- vapply(packet$units, `[[`, character(1), "unit_key")
  expect_setequal(keys[kinds == "bundle"], c("bundle:demo-1/catch/catch_weight", "bundle:demo-1/catch/water_temp"))
  expect_true(any(grepl("^target:tables\\.csv", keys)))
  columns <- vapply(slots, function(s) s$target$column_name[[1]], character(1))
  expect_setequal(columns[!is.na(columns)], c("catch_weight", "water_temp"))

  # The gaps reach the term-request pipeline through the ingester.
  harness <- dplyr::bind_rows(lapply(slots, function(slot) {
    semantic_review_harness_row(slot$target, llm_decision = "request_new_term", llm_confidence = 0.7,
      llm_rationale = "Nothing was offered.", llm_new_term_label = paste("Term for", slot$target$dictionary_role[[1]]))
  }))
  result <- ingest_semantic_assessments(path, assessments = harness, packet_id = built$packet_id,
    search_fn = function(...) stop("no search"), quiet = TRUE)
  expect_identical(result$status, "complete")
  expect_true(all(result$assessments$llm_decision == "request_new_term"))
  gaps <- detect_semantic_term_gaps(result$dictionary)
  expect_true(all(c("catch_weight", "water_temp") %in% gaps$column_name))
})

test_that("a tables.csv row pointing outside the package is refused, not followed", {
  hits <- function(query, role = NA_character_, sources = NULL, ...) tibble::tibble()
  path <- file.path(withr::local_tempdir(), "escape")
  suppressMessages(with_mocked_bindings(
    find_terms = hits,
    create_sdp(
      list(catch = data.frame(catch_weight = c(12.5, 8.1))),
      path = path, dataset_id = "demo-1", table_id = "catch",
      semantic_max_per_role = 1, seed_semantics = TRUE, seed_verbose = FALSE,
      check_updates = FALSE, overwrite = TRUE
    )
  ))
  secret <- file.path(withr::local_tempdir(), "outside.csv")
  writeLines(c("catch_weight", "999"), secret)
  tables_path <- file.path(path, "metadata", "tables.csv")
  tables <- readr::read_csv(tables_path, col_types = readr::cols(.default = readr::col_character()), na = "")
  tables$file_name[[1]] <- file.path("..", "..", basename(dirname(secret)), "outside.csv")
  readr::write_csv(tables, tables_path, na = "")
  expect_null(metasalmon:::.ms_semantic_review_contained_resource(path, tables$file_name[[1]]))
  expect_null(metasalmon:::.ms_semantic_review_contained_resource(path, "/etc/hosts"))
  expect_null(metasalmon:::.ms_semantic_review_contained_resource(path, "data/./spawners.csv"))
  expect_identical(
    metasalmon:::.ms_semantic_review_contained_resource(path, "data/catch.csv"),
    file.path(path, "data", "catch.csv")
  )
  # A symbolic link inside the package is refused too.
  link <- file.path(path, "data", "linked.csv")
  if (file.symlink(secret, link)) {
    expect_null(metasalmon:::.ms_semantic_review_contained_resource(path, "data/linked.csv"))
  }
  expect_warning(
    built <- write_semantic_review_packet(path, search_fn = hits, review_dir = file.path(withr::local_tempdir(), "r"), quiet = TRUE),
    "not plain files inside the package"
  )
  expect_true(built$units > 0L)
})

test_that("a continuation target the harness leaves unanswered keeps its pass-1 answer and candidates, and the session completes", {
  responses <- semantic_review_search_responses()
  for (variant in c("missing", "unusable")) {
    case <- build_case("retry_gain")
    first <- ingest_semantic_assessments(
      case$dict, assessments = file.path(case$case_dir, "harness-1.csv"),
      review_dir = case$review_dir, search_fn = semantic_review_fake_search(responses), quiet = TRUE
    )
    expect_identical(first$status, "awaiting_pass_2")
    pass_2 <- semantic_review_read_json(first$next_packet)
    slot <- metasalmon:::.ms_semantic_review_slots(pass_2)[[1]]
    expect_true(slot$reassess)
    expect_identical(nrow(slot$candidates), 4L)
    empty <- semantic_review_harness_row(slot$target)[0, ]
    answer <- if (identical(variant, "missing")) {
      empty
    } else {
      semantic_review_harness_row(slot$target, llm_error = "The model timed out.")
    }
    result <- ingest_semantic_assessments(
      case$dict, assessments = answer, packet_id = pass_2$packet_id,
      review_dir = case$review_dir, search_fn = function(...) stop("no search"), quiet = TRUE
    )
    # Execplan section 4, item 3: the pass-1 row and candidates stand, the
    # session is complete, and the fallback is counted rather than silent.
    expect_identical(result$status, "complete", info = variant)
    expect_null(result$next_packet, info = variant)
    expect_identical(result$summary$kept_pass_1, 1L, info = variant)
    expect_identical(result$summary$errors, if (identical(variant, "missing")) 0L else 1L, info = variant)
    row <- result$assessments
    expect_identical(row$llm_decision, "retry_search", info = variant)
    expect_match(row$llm_rationale, "pass-1 answer stands", fixed = TRUE, info = variant)
    expect_true(isTRUE(row$llm_exploration_used), info = variant)
    # The merged suggestions carry the pass-1 shortlist, not the widened one,
    # so the record's (absent) index maps onto what the harness first saw.
    expect_setequal(result$suggestions$iri, c("https://w3id.org/smn/Equipment", "https://w3id.org/smn/Tool"))
    expect_false(any(result$suggestions$llm_selected), info = variant)
    expect_true(all(result$suggestions$llm_decision == "retry_search"), info = variant)
    persisted <- semantic_review_read_csv(file.path(case$review_dir, "semantic-llm-assessments.csv"))
    expect_identical(persisted$llm_decision, "retry_search", info = variant)
  }
})

test_that("the result after a continuation pass describes the whole session, not the continuation subset", {
  # Two target units: GEAR_TYPE retries and gains, VESSEL is accepted at pass 1.
  target <- function(column, query, label, description) tibble::tibble(
    dataset_id = "fixture-1", table_id = "catch", column_name = column, code_value = NA_character_,
    dictionary_role = "variable", search_role = "variable", target_scope = "column",
    target_sdp_file = "column_dictionary.csv", target_sdp_field = "term_iri",
    target_row_key = paste("fixture-1/catch", column, sep = "/"), target_label = label,
    target_description = description, search_query = query, target_query_basis = "column_description",
    target_query_context = paste0(label, ": ", description), column_label = label,
    column_description = description, code_label = NA_character_, code_description = NA_character_
  )
  targets <- dplyr::bind_rows(
    target("GEAR_TYPE", "gear type", "Gear type", "The fishing gear used."),
    target("VESSEL", "vessel", "Vessel", "The vessel name.")
  )
  candidate <- function(t, label, iri, score) dplyr::bind_cols(t, tibble::tibble(
    label = label, iri = iri, source = "smn", ontology = "Salmon Ontology", role = "variable",
    match_type = "label_partial", definition = paste0(label, "."), score = score, term_type = "owl_class",
    retrieval_query = t$search_query[[1]], retrieval_pass = 1L
  ))
  candidates <- dplyr::bind_rows(
    candidate(targets[1, ], "Equipment", "https://w3id.org/smn/Equipment", 0.4),
    candidate(targets[1, ], "Tool", "https://w3id.org/smn/Tool", 0.3),
    candidate(targets[2, ], "Vessel", "https://w3id.org/smn/Vessel", 0.6)
  )
  dict <- tibble::tibble(
    dataset_id = "fixture-1", table_id = "catch", column_name = c("GEAR_TYPE", "VESSEL"),
    column_label = c("Gear type", "Vessel"), column_description = c("The fishing gear used.", "The vessel name."),
    column_role = "categorical", value_type = "string", term_iri = NA_character_
  )
  attr(dict, "semantic_targets") <- targets
  attr(dict, "semantic_suggestions") <- candidates
  review_dir <- file.path(withr::local_tempdir(), "review")
  built <- write_semantic_review_packet(dict, review_dir = review_dir, quiet = TRUE)
  expect_identical(built$units, 2L)

  responses <- semantic_review_search_responses()
  harness_1 <- dplyr::bind_rows(
    semantic_review_harness_row(targets[1, ], llm_decision = "retry_search", llm_confidence = 0.3, llm_rationale = "Generic.", llm_retry_query = "fishing gear type"),
    semantic_review_harness_row(targets[2, ], llm_decision = "accept", llm_confidence = 0.9, llm_selected_candidate_index = 1L, llm_selected_iri = "https://w3id.org/smn/Vessel", llm_rationale = "The vessel.")
  )
  first <- ingest_semantic_assessments(dict, assessments = harness_1, packet_id = built$packet_id,
    review_dir = review_dir, search_fn = semantic_review_fake_search(responses), quiet = TRUE)
  expect_identical(first$status, "awaiting_pass_2")
  # At pass 1 the pending target is not merged; the accepted one is.
  expect_setequal(unique(first$suggestions$column_name), "VESSEL")
  expect_identical(nrow(first$targets), 2L)

  pass_2 <- semantic_review_read_json(first$next_packet)
  expect_length(pass_2$units, 1L)
  gear <- metasalmon:::.ms_semantic_review_slots(pass_2)[[1]]
  harness_2 <- semantic_review_harness_row(gear$target, llm_decision = "accept", llm_confidence = 0.9,
    llm_selected_candidate_index = 1L, llm_selected_iri = "https://w3id.org/smn/FishingGear", llm_rationale = "Found it.")
  result <- ingest_semantic_assessments(dict, assessments = harness_2, packet_id = pass_2$packet_id,
    review_dir = review_dir, search_fn = function(...) stop("no search"), quiet = TRUE)
  expect_identical(result$status, "complete")
  # Every pass-1 target and every slot's candidates, with both accepts selected.
  expect_identical(nrow(result$targets), 2L)
  expect_setequal(result$targets$column_name, c("GEAR_TYPE", "VESSEL"))
  expect_identical(nrow(result$assessments), 2L)
  expect_setequal(unique(result$suggestions$column_name), c("GEAR_TYPE", "VESSEL"))
  selected <- result$suggestions[result$suggestions$llm_selected, ]
  expect_setequal(selected$iri, c("https://w3id.org/smn/FishingGear", "https://w3id.org/smn/Vessel"))
  expect_true("https://w3id.org/smn/GearDeployment" %in% result$suggestions$iri)
  expect_identical(semantic_suggestions(result$dictionary), result$suggestions)
  expect_identical(nrow(attr(result$dictionary, "semantic_targets")), 2L)
  expect_identical(nrow(semantic_llm_assessments(result$dictionary)), 2L)
})

# -----------------------------------------------------------------------------
# Codex round three on #194: two findings, each pinned
# -----------------------------------------------------------------------------

test_that("a package that started with no shortlist gets one when a retry gains candidates", {
  nothing <- function(query, role = NA_character_, sources = NULL, ...) tibble::tibble()
  path <- file.path(withr::local_tempdir(), "no-shortlist-retry")
  suppressMessages(with_mocked_bindings(
    find_terms = nothing,
    create_sdp(
      list(catch = data.frame(water_temp = c(8.5, 9.1, 7.4))),
      path = path, dataset_id = "demo-1", table_id = "catch",
      semantic_max_per_role = 1, seed_semantics = TRUE, seed_verbose = FALSE,
      semantic_code_scope = "none", check_updates = FALSE, overwrite = TRUE
    )
  ))
  expect_false(file.exists(file.path(path, "semantic_suggestions.csv")))
  built <- write_semantic_review_packet(path, search_fn = nothing, code_scope = "none", quiet = TRUE)
  slots <- metasalmon:::.ms_semantic_review_slots(semantic_review_read_json(built$path))
  gear <- Filter(function(s) identical(s$target$column_name[[1]], "water_temp") && identical(s$target$dictionary_role[[1]], "variable"), slots)
  expect_length(gear, 1L)
  expect_identical(nrow(gear[[1]]$candidates), 0L)

  wider <- function(query, role, sources) {
    if (!identical(query, "stream water temperature measured in situ")) return(tibble::tibble())
    tibble::tibble(
      label = "Water temperature", iri = "https://w3id.org/smn/WaterTemperature", source = "smn",
      ontology = "Salmon Ontology", role = role, match_type = "label_partial",
      definition = "The temperature of the water.", score = 0.92
    )
  }
  harness_1 <- dplyr::bind_rows(lapply(slots, function(slot) {
    if (identical(slot$key, gear[[1]]$key)) {
      semantic_review_harness_row(slot$target, llm_decision = "retry_search", llm_confidence = 0.3, llm_rationale = "Search for water temperature.", llm_retry_query = "stream water temperature measured in situ")
    } else {
      semantic_review_harness_row(slot$target, llm_decision = "review", llm_confidence = 0.2, llm_rationale = "Nothing offered.")
    }
  }))
  first <- ingest_semantic_assessments(path, assessments = harness_1, packet_id = built$packet_id, search_fn = wider, quiet = TRUE)
  expect_identical(first$status, "awaiting_pass_2")
  pass_2 <- semantic_review_read_json(first$next_packet)
  gear_2 <- Filter(function(s) isTRUE(s$reassess), metasalmon:::.ms_semantic_review_slots(pass_2))[[1]]
  expect_identical(nrow(gear_2$candidates), 1L)
  harness_2 <- semantic_review_harness_row(gear_2$target, llm_decision = "accept", llm_confidence = 0.9,
    llm_selected_candidate_index = 1L, llm_selected_iri = "https://w3id.org/smn/WaterTemperature", llm_rationale = "Found it.")
  result <- ingest_semantic_assessments(path, assessments = harness_2, packet_id = pass_2$packet_id,
    search_fn = function(...) stop("no search"), quiet = TRUE)
  expect_identical(result$status, "complete")
  # The shortlist file now exists, and the documented console path sees the accept.
  written <- semantic_suggestions(path)
  expect_false(is.null(written))
  expect_true("https://w3id.org/smn/WaterTemperature" %in% written$iri)
  expect_true(all(c("decision", "decision_reason") %in% names(written)))
  review <- suppressMessages(review_semantics(path))
  expect_true("https://w3id.org/smn/WaterTemperature" %in% review$iri)
  expect_true(any(review$llm_decision %in% "accept"))
})

test_that("a pass-2 row with a blank provider or model keeps the pass-1 answer like any other unusable answer", {
  responses <- semantic_review_search_responses()
  case <- build_case("retry_gain")
  first <- ingest_semantic_assessments(
    case$dict, assessments = file.path(case$case_dir, "harness-1.csv"),
    review_dir = case$review_dir, search_fn = semantic_review_fake_search(responses), quiet = TRUE
  )
  pass_2 <- semantic_review_read_json(first$next_packet)
  slot <- metasalmon:::.ms_semantic_review_slots(pass_2)[[1]]
  blank <- semantic_review_harness_row(slot$target, llm_decision = "accept", llm_confidence = 0.9,
    llm_selected_candidate_index = 1L, llm_selected_iri = "https://w3id.org/smn/FishingGear", llm_rationale = "Found it.")
  blank$llm_provider <- NA_character_
  result <- ingest_semantic_assessments(
    case$dict, assessments = blank, packet_id = pass_2$packet_id,
    review_dir = case$review_dir, search_fn = function(...) stop("no search"), quiet = TRUE
  )
  expect_identical(result$status, "complete")
  expect_identical(result$summary$kept_pass_1, 1L)
  expect_identical(result$summary$errors, 1L)
  expect_identical(result$assessments$llm_decision, "retry_search")
  expect_true(is.na(result$assessments$llm_error))
  expect_match(result$assessments$llm_rationale, "llm_provider and llm_model must be non-empty", fixed = TRUE)
  expect_setequal(result$suggestions$iri, c("https://w3id.org/smn/Equipment", "https://w3id.org/smn/Tool"))
})
