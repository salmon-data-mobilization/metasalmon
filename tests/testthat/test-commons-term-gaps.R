# B-278 / B-279 shared commons-register contract. These fixtures preserve
# source-backed draft notes; they never authorize minting or issue publication.
# Retires when a reviewed replacement export schema lands in both packages.

commons_fixture <- function(name = "register-excerpt.json") {
  test_path("fixtures", "commons-gaps", name)
}

commons_export <- function(path = commons_fixture()) {
  jsonlite::fromJSON(path, simplifyVector = FALSE)
}

commons_write <- function(value) {
  path <- tempfile(fileext = ".json")
  writeLines(jsonlite::toJSON(value, auto_unbox = TRUE, null = "null"), path)
  path
}

commons_fields <- paste0("commons_", c(
  "concept", "title", "context", "registry", "status", "mint_target", "state",
  "proposal", "rejected_because", "evidence_needed", "blocked_by", "conflicts",
  "note", "card_status", "verified", "hold_reason"
))

test_that("commons register records retain order, duplicates, and honest evidence", {
  raw <- commons_export()$gaps
  gaps <- detect_semantic_term_gaps(commons_gaps = commons_fixture())
  prefix <- metasalmon:::.ms_term_gap_cols()
  expect_equal(names(gaps), c(prefix, commons_fields))
  expect_equal(nrow(gaps), length(raw))
  expect_identical(gaps$commons_concept, vapply(raw, `[[`, "", "concept"))
  expect_gt(sum(duplicated(gaps$commons_concept)), 0L)
  for (field in setdiff(commons_fields, "commons_hold_reason")) {
    original <- sub("^commons_", "", field)
    if (original == "blocked_by") {
      expect_identical(gaps[[field]], lapply(raw, function(r) as.character(unlist(r[[original]], use.names = FALSE))))
    } else if (original == "verified") {
      expect_identical(gaps[[field]], vapply(raw, `[[`, FALSE, original))
    } else {
      expect_identical(gaps[[field]], vapply(raw, function(r) if (is.null(r[[original]])) NA_character_ else r[[original]], ""))
    }
  }
  missing_evidence <- c(
    "dataset_id", "table_id", "column_name", "code_value", "target_scope",
    "target_sdp_file", "target_sdp_field", "target_row_key", "dictionary_role",
    "column_label", "column_description", "top_non_smn_source", "top_non_smn_label",
    "top_non_smn_iri", "top_non_smn_ontology", "top_non_smn_match_type",
    "top_non_smn_score", "candidate_count", "non_smn_sources", "placement_confidence",
    "target_description", "llm_decision", "llm_confidence", "llm_rationale",
    "llm_new_term_label", "llm_new_term_definition", "llm_new_term_namespace", "llm_escalated_from"
  )
  for (field in missing_evidence) expect_true(all(is.na(gaps[[field]])), info = field)
  expect_identical(gaps$target_label, gaps$commons_title)
  expect_identical(gaps$search_query, gaps$commons_title)
  # An empty source array must not become null in the returned row's JSON.
  serialized <- jsonlite::fromJSON(jsonlite::toJSON(gaps[1L, "commons_blocked_by"], auto_unbox = TRUE, null = "null"), simplifyVector = FALSE)
  expect_identical(serialized[[1L]]$commons_blocked_by, list())
  expect_true(all(gaps$gap_detection_basis == "commons_register"))
  expect_identical(names(detect_semantic_term_gaps(dict = tibble::tibble())), prefix)
})

test_that("commons holds remain visible and cannot be revived by renderer controls", {
  all <- c(commons_export()$gaps, commons_export(commons_fixture("synthetic-controls.json"))$gaps)
  combined <- all[[1L]]
  combined$blocked_by <- list("concepts/example")
  combined$conflicts <- "Synthetic control: two authorities disagree about this draft concept."
  all <- c(all, list(combined))
  gaps <- detect_semantic_term_gaps(commons_gaps = commons_write(list(gaps = all)))
  expect_true(any(gaps$commons_hold_reason == ""))
  for (reason in c("proposed", "rejected", "do-not-mint", "blocked", "conflicted", "contested", "evidence-needed", "unsupported-target", "deprecated-card")) {
    expect_true(any(grepl(reason, gaps$commons_hold_reason, fixed = TRUE)), info = reason)
  }
  requests <- render_ontology_term_request(gaps, ask = FALSE)
  held <- nzchar(gaps$commons_hold_reason)
  expect_true(all(requests$request_scope[held] == "skip"))
  expect_identical(requests$request_scope[!held], gaps$commons_mint_target[!held])
  # Fixed scope, override and ask are existing controls, not authority to reopen
  # a lifecycle hold or redirect an explicitly routed commons declaration.
  for (args in list(list(scope = "smn"), list(scope_overrides = "gcdfo"), list(ask = TRUE))) {
    controlled <- do.call(render_ontology_term_request, c(list(gaps = gaps, ask = FALSE)[setdiff(c("gaps", "ask"), names(args))], args))
    expect_identical(controlled$request_scope, requests$request_scope)
  }
  tampered <- gaps
  tampered$commons_hold_reason <- ""
  tampered$placement_recommendation <- "smn"
  expect_identical(render_ontology_term_request(tampered, ask = TRUE)$request_scope, requests$request_scope)
  incomplete <- tampered
  incomplete$commons_concept <- NULL
  expect_error(render_ontology_term_request(incomplete, scope = "smn"), "commons_gaps")
  tampered$commons_blocked_by[1L] <- list(NULL)
  expect_error(render_ontology_term_request(tampered, scope = "smn"), "commons_gaps")
  expect_true(any(grepl("blocked; conflicted", gaps$commons_hold_reason, fixed = TRUE)))
})

test_that("commons request bodies carry source evidence and require curator choices", {
  gaps <- detect_semantic_term_gaps(commons_gaps = commons_fixture())
  requests <- render_ontology_term_request(gaps, ask = FALSE)
  for (i in seq_len(nrow(gaps))) {
    body <- requests$request_body[[i]]
    expect_match(body, gaps$commons_concept[[i]], fixed = TRUE)
    expect_match(body, gaps$commons_note[[i]], fixed = TRUE)
    expect_match(body, "Curator definition required.", fixed = TRUE)
    expect_match(body, "Curator term type required.", fixed = TRUE)
    expect_match(body, "draft", fixed = TRUE)
    expect_match(body, "Verified: false", fixed = TRUE)
    expect_false(grepl("Dataset evidence", body, fixed = TRUE))
    expect_false(grepl("unknown / unknown / unknown", body, fixed = TRUE))
  }
  preview <- testthat::with_mocked_bindings(
    submit_term_request_issues(requests, dry_run = TRUE),
    ms_current_token = function(...) stop("authentication must not run"),
    .metasalmon_post_issue = function(...) stop("network must not run"),
    .package = "metasalmon"
  )
  eligible <- !nzchar(gaps$commons_hold_reason)
  expect_equal(nrow(preview), sum(eligible))
  expect_true(all(preview$status == "dry_run"))
  expect_identical(preview$request_scope, gaps$commons_mint_target[eligible])
})

test_that("commons path accepts only a file and rejects incompatible SDP inputs", {
  fixture <- commons_fixture()
  for (value in list(list(gaps = list()), c(fixture, fixture), NA_character_, "", "{\"gaps\":[]}", tempfile())) {
    expect_error(detect_semantic_term_gaps(commons_gaps = value), "commons_gaps")
  }
  expect_error(detect_semantic_term_gaps(dict = tibble::tibble(), commons_gaps = fixture), "exclusive")
  expect_error(detect_semantic_term_gaps(suggestions = tibble::tibble(), commons_gaps = fixture), "exclusive")
  expect_error(detect_semantic_term_gaps(commons_gaps = fixture, include_target_scopes = "column"), "SDP")
  expect_error(detect_semantic_term_gaps(commons_gaps = fixture, include_dictionary_roles = "variable"), "SDP")
  expect_error(detect_semantic_term_gaps(commons_gaps = fixture, min_score = 0.5), "SDP")
})

test_that("commons reader rejects malformed envelopes and invalid typed lifecycle fields", {
  for (text in c("{", "[]", "{}", '{"gaps":null}', '{"gaps":{}}', '{"gaps":1}', '{"gaps":[null]}', '{"gaps":[[]]}')) {
    path <- tempfile(fileext = ".json")
    writeLines(text, path)
    expect_error(detect_semantic_term_gaps(commons_gaps = path), "commons_gaps")
  }
  base <- commons_export()$gaps[[1L]]
  mutations <- list(
    list(registry = "invalid"), list(status = "minted"), list(mint_target = "profile"),
    list(state = "minted"), list(state = "proposed"), list(state = "rejected"),
    list(card_status = "unknown"), list(context = "unknown"), list(verified = "false"),
    list(title = c("one", "two")), list(concept = 2), list(note = "short"),
    list(blocked_by = "concepts/example"), list(blocked_by = list(2)),
    list(blocked_by = NULL), list(verified = 0), list(conflicts = "short"),
    list(evidence_needed = "short"), list(proposal = 2),
    list(state = "proposed", proposal = "relative/path")
  )
  for (change in mutations) {
    row <- base
    for (field in names(change)) row[field] <- change[field]
    expect_error(detect_semantic_term_gaps(commons_gaps = commons_write(list(gaps = list(row)))), "commons_gaps", info = names(change))
  }
  for (field in c("concept", "title", "context", "registry", "status", "mint_target", "state", "note", "card_status", "verified", "blocked_by")) {
    row <- base
    row[[field]] <- NULL
    expect_error(detect_semantic_term_gaps(commons_gaps = commons_write(list(gaps = list(row)))), "commons_gaps", info = field)
  }
  empty <- detect_semantic_term_gaps(commons_gaps = commons_write(list(gaps = list())))
  expect_equal(nrow(empty), 0L)
  expect_identical(names(empty), c(metasalmon:::.ms_term_gap_cols(), commons_fields))
})
