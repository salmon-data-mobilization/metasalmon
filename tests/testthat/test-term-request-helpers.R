test_that("detect_semantic_term_gaps classifies non-SMN candidates", {
  suggestions <- tibble::tibble(
    dataset_id = c("d1", "d1"),
    table_id = c("t1", "t1"),
    column_name = c("run_id", "run_id"),
    code_value = NA_character_,
    dictionary_role = c("variable", "variable"),
    target_scope = c("column", "column"),
    target_sdp_file = c("column_dictionary.csv", "column_dictionary.csv"),
    target_sdp_field = c("term_iri", "term_iri"),
    target_row_key = c("run_id", "run_id"),
    search_query = c("run id", "run id"),
    column_label = c("Run ID", "Run ID"),
    column_description = c("Local run identifier", "Local run identifier"),
    label = c("run id", "run identifier"),
    iri = c(NA_character_, NA_character_),
    source = c("gbif", "worms"),
    ontology = c("gbif", "worms"),
    match_type = c("label", "label"),
    definition = c(NA_character_, NA_character_),
    score = c(0.9, 0.85)
  )

  gaps <- detect_semantic_term_gaps(
    dict = NULL,
    suggestions = suggestions,
    include_dictionary_roles = c("variable")
  )

  expect_s3_class(gaps, c("tbl_df", "tbl", "data.frame"))
  expect_true(nrow(gaps) >= 1L)
  expect_equal(gaps$placement_recommendation[[1]], "profile")
})


test_that("detect_semantic_term_gaps can recommend shared placement", {
  suggestions <- tibble::tibble(
    dataset_id = c("d1", "d1"),
    table_id = c("t1", "t1"),
    column_name = c("escape_rate", "escape_rate"),
    code_value = NA_character_,
    dictionary_role = c("variable", "variable"),
    target_scope = c("column", "column"),
    target_sdp_file = c("column_dictionary.csv", "column_dictionary.csv"),
    target_sdp_field = c("term_iri", "term_iri"),
    target_row_key = c("escape_rate", "escape_rate"),
    search_query = c("escape rate", "escape rate"),
    column_label = c("Escape rate", "Escape rate"),
    column_description = c("Percent of fish escaping", "Percent of fish escaping"),
    label = c("escape rate", "escape rate"),
    iri = c(NA_character_, NA_character_),
    source = c("gcdfo", "ols"),
    ontology = c("https://w3id.org/gcdfo/salmon#", "https://www.ebi.ac.uk/ols/"),
    match_type = c("label", "label"),
    definition = c(NA_character_, NA_character_),
    score = c(0.95, 0.9)
  )

  gaps <- detect_semantic_term_gaps(suggestions = suggestions)
  expect_true(nrow(gaps) >= 1L)
  expect_equal(gaps$placement_recommendation[[1]], "smn")
})

test_that("term gaps preserve the legacy prefix and allow suggestions without score", {
  suggestions <- tibble::tibble(
    dataset_id = "d1",
    table_id = "t1",
    column_name = "run_id",
    code_value = NA_character_,
    dictionary_role = "variable",
    target_scope = "column",
    target_sdp_file = "column_dictionary.csv",
    target_sdp_field = "term_iri",
    target_row_key = "d1/t1/run_id",
    target_label = "Run ID",
    target_description = "Local run identifier",
    search_query = "run id",
    column_label = "Run ID",
    column_description = "Local run identifier",
    label = "Run identifier",
    iri = NA_character_,
    source = "gbif",
    ontology = "gbif",
    match_type = "label",
    definition = NA_character_
  )
  legacy_prefix <- c(
    "dataset_id", "table_id", "column_name", "code_value", "target_scope",
    "target_sdp_file", "target_sdp_field", "target_row_key", "dictionary_role",
    "search_query", "column_label", "column_description", "top_non_smn_source",
    "top_non_smn_label", "top_non_smn_iri", "top_non_smn_ontology",
    "top_non_smn_match_type", "top_non_smn_score", "candidate_count",
    "non_smn_sources", "placement_recommendation", "placement_confidence",
    "placement_rationale"
  )

  gaps <- detect_semantic_term_gaps(suggestions = suggestions)

  expect_equal(names(gaps)[seq_along(legacy_prefix)], legacy_prefix)
  expect_equal(names(gaps), metasalmon:::.ms_term_gap_cols())
  expect_true(is.na(gaps$top_non_smn_score))
  expect_equal(gaps$gap_detection_basis, "candidate_gap")
})

test_that("explicit final LLM gaps win even when an SMN candidate exists", {
  suggestions <- tibble::tibble(
    dataset_id = "d1",
    table_id = "t1",
    column_name = "novel_metric",
    code_value = NA_character_,
    dictionary_role = "property",
    target_scope = "column",
    target_sdp_file = "column_dictionary.csv",
    target_sdp_field = "property_iri",
    target_row_key = "d1/t1/novel_metric",
    target_label = "Novel metric",
    target_description = "Program-specific derived performance metric",
    search_query = "novel performance metric",
    column_label = "Novel metric",
    column_description = "Program-specific derived performance metric",
    label = "Nearby property",
    iri = "https://w3id.org/smn/NearbyProperty",
    source = "smn",
    ontology = "smn",
    match_type = "label_partial",
    definition = "A nearby but unsuitable property",
    score = 0.82
  )
  assessment <- metasalmon:::.ms_llm_review_empty_assessment(
    suggestions,
    list(provider = "openrouter", model = "openai/gpt-5.4-mini")
  )
  assessment$llm_decision <- "request_new_term"
  assessment$llm_confidence <- 0.91
  assessment$llm_rationale <- "The existing SMN property has different semantics."
  assessment$llm_new_term_label <- "Program performance metric"
  assessment$llm_new_term_definition <- "A derived metric used by the program."
  assessment$llm_new_term_namespace <- "gcdfo"
  dict <- tibble::tibble(
    dataset_id = "d1",
    table_id = "t1",
    column_name = "novel_metric",
    column_label = "Novel metric",
    column_description = "Program-specific derived performance metric"
  )
  attr(dict, "semantic_suggestions") <- suggestions
  attr(dict, "semantic_llm_assessments") <- assessment

  gaps <- detect_semantic_term_gaps(dict = dict)

  expect_equal(nrow(gaps), 1L)
  expect_equal(gaps$gap_detection_basis, "llm_request_new_term")
  expect_equal(gaps$llm_new_term_label, "Program performance metric")
  expect_equal(gaps$llm_new_term_namespace, "gcdfo")
  expect_equal(gaps$candidate_count, 0L)
})

test_that("score filtering preserves target metadata for an explicit LLM gap", {
  suggestions <- tibble::tibble(
    dataset_id = "d1",
    table_id = "t1",
    column_name = "novel_metric",
    code_value = NA_character_,
    dictionary_role = "property",
    target_scope = "column",
    target_sdp_file = "column_dictionary.csv",
    target_sdp_field = "property_iri",
    target_row_key = "d1/t1/novel_metric",
    target_label = "Novel program metric",
    target_description = "A derived program-specific metric.",
    search_query = "novel program metric",
    column_label = "Novel metric",
    column_description = "A derived program-specific metric.",
    label = "Weak nearby property",
    iri = "https://w3id.org/smn/NearbyProperty",
    source = "smn",
    ontology = "smn",
    match_type = "label_partial",
    definition = "A weak lexical match.",
    score = 0.2,
    llm_decision = "request_new_term",
    llm_confidence = 0.9,
    llm_rationale = "No candidate represents the program metric.",
    llm_new_term_label = "Program metric",
    llm_new_term_definition = "A metric defined by the program.",
    llm_new_term_namespace = "gcdfo"
  )

  gaps <- detect_semantic_term_gaps(
    suggestions = suggestions,
    min_score = 0.8
  )

  expect_equal(gaps$target_row_key, "d1/t1/novel_metric")
  expect_equal(gaps$target_label, "Novel program metric")
  expect_equal(gaps$target_description, "A derived program-specific metric.")
  expect_equal(gaps$column_label, "Novel metric")
  expect_equal(gaps$gap_detection_basis, "llm_request_new_term")
})

test_that("LLM reasoning does not replace routing rationale", {
  suggestions <- tibble::tibble(
    dataset_id = "d1",
    table_id = "t1",
    column_name = "run_id",
    code_value = NA_character_,
    dictionary_role = "variable",
    target_scope = "column",
    target_sdp_file = "column_dictionary.csv",
    target_sdp_field = "term_iri",
    target_row_key = "d1/t1/run_id",
    target_label = "Run ID",
    target_description = "Local program run identifier.",
    search_query = "run id",
    column_label = "Run ID",
    column_description = "Local program run identifier.",
    label = "Weak match",
    iri = NA_character_,
    source = "gbif",
    ontology = "gbif",
    match_type = "label_partial",
    definition = "A nearby identifier.",
    score = 0.8,
    llm_decision = "request_new_term",
    llm_confidence = 0.9,
    llm_rationale = "The candidate has different semantics.",
    llm_new_term_label = "Program run identifier",
    llm_new_term_definition = "Identifier assigned to a local program run.",
    llm_new_term_namespace = "profile"
  )

  gaps <- detect_semantic_term_gaps(suggestions = suggestions)

  expect_match(gaps$placement_rationale, "local_pattern=TRUE", fixed = TRUE)
  expect_equal(gaps$llm_rationale, "The candidate has different semantics.")
})

test_that("conflicting LLM proposal fields for one semantic target abort", {
  target <- tibble::tibble(
    dataset_id = "d1",
    table_id = "t1",
    column_name = "novel_metric",
    code_value = NA_character_,
    dictionary_role = "property",
    target_scope = "column",
    target_sdp_file = "column_dictionary.csv",
    target_sdp_field = "property_iri",
    search_query = "novel metric"
  )
  assessment <- metasalmon:::.ms_llm_review_empty_assessment(
    target,
    list(provider = "openrouter", model = "openai/gpt-5.4-mini")
  )
  assessment <- dplyr::bind_rows(assessment, assessment)
  assessment$llm_decision <- "request_new_term"
  assessment$llm_new_term_label <- c("Metric A", "Metric B")
  dict <- tibble::tibble(
    dataset_id = "d1",
    table_id = "t1",
    column_name = "novel_metric",
    column_label = "Novel metric",
    column_description = "A new metric"
  )
  attr(dict, "semantic_suggestions") <- tibble::tibble()
  attr(dict, "semantic_llm_assessments") <- assessment

  expect_error(
    detect_semantic_term_gaps(dict = dict),
    "Conflicting llm_new_term_label values"
  )
})

test_that("explicit suggestions ignore dictionary assessment attributes", {
  suggestions <- tibble::tibble(
    dataset_id = "d1",
    table_id = "t1",
    column_name = "known_metric",
    code_value = NA_character_,
    dictionary_role = "property",
    target_scope = "column",
    target_sdp_file = "column_dictionary.csv",
    target_sdp_field = "property_iri",
    target_row_key = "d1/t1/known_metric",
    target_label = "Known metric",
    target_description = "A known property",
    search_query = "known property",
    column_label = "Known metric",
    column_description = "A known property",
    label = "Known property",
    iri = "https://w3id.org/smn/KnownProperty",
    source = "smn",
    ontology = "smn",
    match_type = "label",
    definition = "A known property",
    score = 0.95
  )
  stale <- metasalmon:::.ms_llm_review_empty_assessment(
    suggestions,
    list(provider = "fixture", model = "fixture")
  )
  stale$llm_decision <- "request_new_term"
  stale$llm_new_term_label <- "Stale proposal"
  dict <- tibble::tibble(
    dataset_id = "d1",
    table_id = "t1",
    column_name = "known_metric"
  )
  attr(dict, "semantic_suggestions") <- suggestions
  attr(dict, "semantic_llm_assessments") <- stale

  gaps <- detect_semantic_term_gaps(
    dict = dict,
    suggestions = suggestions
  )

  expect_equal(nrow(gaps), 0L)
})

test_that("identical duplicate LLM assessments collapse to one gap", {
  target <- tibble::tibble(
    dataset_id = "d1",
    table_id = "t1",
    column_name = "novel_metric",
    code_value = NA_character_,
    dictionary_role = "property",
    target_scope = "column",
    target_sdp_file = "column_dictionary.csv",
    target_sdp_field = "property_iri",
    search_query = "novel metric"
  )
  assessment <- metasalmon:::.ms_llm_review_empty_assessment(
    target,
    list(provider = "fixture", model = "fixture")
  )
  assessment$llm_decision <- "request_new_term"
  assessment$llm_new_term_label <- "Novel metric"
  assessment$llm_new_term_definition <- "A novel program metric."
  assessment <- dplyr::bind_rows(assessment, assessment)
  dict <- tibble::tibble(
    dataset_id = "d1",
    table_id = "t1",
    column_name = "novel_metric",
    column_label = "Novel metric",
    column_description = "A novel program metric."
  )
  attr(dict, "semantic_suggestions") <- tibble::tibble()
  attr(dict, "semantic_llm_assessments") <- assessment

  gaps <- detect_semantic_term_gaps(dict = dict)

  expect_equal(nrow(gaps), 1L)
  expect_equal(gaps$llm_new_term_label, "Novel metric")
})

test_that("candidate and LLM gap evidence produce the combined detection basis", {
  suggestions <- tibble::tibble(
    dataset_id = "d1",
    table_id = "t1",
    column_name = "novel_metric",
    code_value = NA_character_,
    dictionary_role = "property",
    target_scope = "column",
    target_sdp_file = "column_dictionary.csv",
    target_sdp_field = "property_iri",
    target_row_key = "d1/t1/novel_metric",
    target_label = "Novel metric",
    target_description = "A novel program metric",
    search_query = "novel metric",
    column_label = "Novel metric",
    column_description = "A novel program metric",
    label = "External nearby metric",
    iri = "https://example.org/metric",
    source = "external",
    ontology = "external",
    match_type = "label_partial",
    definition = "A nearby metric",
    score = 0.9,
    llm_decision = "request_new_term",
    llm_confidence = 0.92,
    llm_rationale = "No candidate is precise.",
    llm_new_term_label = "Novel metric",
    llm_new_term_definition = "A novel program metric.",
    llm_new_term_namespace = NA_character_
  )

  gaps <- detect_semantic_term_gaps(suggestions = suggestions)

  expect_equal(
    gaps$gap_detection_basis,
    "candidate_gap_and_llm_request_new_term"
  )
  expect_equal(gaps$candidate_count, 1L)
})


test_that("render_ontology_term_request defaults to salmon-domain ontology repo", {
  gaps <- tibble::tibble(
    dataset_id = "d1",
    table_id = "t1",
    column_name = "run_id",
    code_value = NA_character_,
    target_scope = "column",
    target_sdp_file = "column_dictionary.csv",
    target_sdp_field = "term_iri",
    target_row_key = "run_id",
    dictionary_role = "variable",
    search_query = "run id",
    column_label = "Run ID",
    column_description = "Dataset-specific run identifier",
    top_non_smn_source = "gbif",
    top_non_smn_label = "Run event id",
    top_non_smn_iri = NA_character_,
    top_non_smn_ontology = NA_character_,
    top_non_smn_match_type = "label",
    top_non_smn_score = 0.9,
    candidate_count = 1L,
    non_smn_sources = "gbif",
    placement_recommendation = "smn",
    placement_confidence = 0.82,
    placement_rationale = "shared domain concept"
  )

  reqs <- render_ontology_term_request(gaps, ask = FALSE)

  expect_equal(reqs$ontology_repo, "salmon-data-mobilization/salmon-domain-ontology")
  expect_true(grepl("salmon-domain-ontology", reqs$request_body, fixed = TRUE))
})

test_that("render_ontology_term_request uses profile scope", {
  gaps <- tibble::tibble(
    dataset_id = "d1",
    table_id = "t1",
    column_name = "run_id",
    code_value = NA_character_,
    target_scope = "column",
    target_sdp_file = "column_dictionary.csv",
    target_sdp_field = "term_iri",
    target_row_key = "run_id",
    dictionary_role = "variable",
    search_query = "run id",
    column_label = "Run ID",
    column_description = "Dataset-specific run identifier",
    top_non_smn_source = "gbif",
    top_non_smn_label = "Run event id",
    top_non_smn_iri = NA_character_,
    top_non_smn_ontology = NA_character_,
    top_non_smn_match_type = "label",
    top_non_smn_score = 0.9,
    candidate_count = 1L,
    non_smn_sources = "gbif",
    placement_recommendation = "profile",
    placement_confidence = 0.82,
    placement_rationale = "contains internal identifier signal"
  )

  reqs <- render_ontology_term_request(
    gaps,
    scope = "profile",
    ask = FALSE,
    profile_name = "pacific-monitoring"
  )

  expect_equal(reqs$request_scope, "profile")
  expect_true(grepl("pacific-monitoring", reqs$request_title, fixed = TRUE))
  expect_true(grepl("New term template", reqs$request_body, fixed = TRUE))
})

test_that("render_ontology_term_request treats GCDFO as a first-class reviewed scope", {
  gaps <- tibble::tibble(
    dataset_id = "d1",
    table_id = "t1",
    column_name = "program_metric",
    code_value = NA_character_,
    target_scope = "column",
    target_sdp_file = "column_dictionary.csv",
    target_sdp_field = "property_iri",
    target_row_key = "d1/t1/program_metric",
    dictionary_role = "property",
    search_query = "program performance metric",
    column_label = "Program metric",
    column_description = "DFO-specific operational performance metric",
    top_non_smn_source = NA_character_,
    top_non_smn_label = NA_character_,
    top_non_smn_iri = NA_character_,
    top_non_smn_ontology = NA_character_,
    top_non_smn_match_type = NA_character_,
    top_non_smn_score = NA_real_,
    candidate_count = 0L,
    non_smn_sources = NA_character_,
    placement_recommendation = "uncertain",
    placement_confidence = 0.4,
    placement_rationale = "Placement requires review.",
    target_label = "Program performance metric",
    target_description = "A DFO-specific operational metric.",
    gap_detection_basis = "llm_request_new_term",
    llm_decision = "request_new_term",
    llm_confidence = 0.9,
    llm_rationale = "The concept is specific to a DFO program.",
    llm_new_term_label = "DFO program performance metric",
    llm_new_term_definition = "An operational metric defined by a DFO program.",
    llm_new_term_namespace = "gcdfo",
    llm_escalated_from = NA_character_
  )

  reqs <- render_ontology_term_request(gaps, scope = "auto", ask = FALSE)

  expect_equal(reqs$request_scope, "gcdfo")
  expect_equal(reqs$ontology_repo, "dfo-pacific-science/dfo-salmon-ontology")
  expect_match(reqs$request_title, "DFO program performance metric", fixed = TRUE)
  expect_match(
    reqs$request_body,
    "* **Suggested term label (required):**",
    fixed = TRUE
  )
  expect_match(reqs$request_body, "* **Parent term(s):**", fixed = TRUE)
  expect_match(reqs$request_body, "* **Cross-references:**", fixed = TRUE)

  forced <- render_ontology_term_request(gaps, scope = "smn", ask = FALSE)
  expect_equal(forced$request_scope, "smn")
  expect_equal(forced$ontology_repo, "salmon-data-mobilization/salmon-domain-ontology")
  expect_match(
    forced$request_body,
    "## Suggested term label (required)",
    fixed = TRUE
  )
  expect_match(
    forced$request_body,
    "## I-ADOPT decomposition (for measurement-like terms)",
    fixed = TRUE
  )
})

test_that("term-request routing follows override forced namespace heuristic precedence", {
  gap <- tibble::tibble(
    dataset_id = "d1",
    table_id = "t1",
    column_name = "program_metric",
    code_value = NA_character_,
    target_scope = "column",
    target_sdp_file = "column_dictionary.csv",
    target_sdp_field = "property_iri",
    target_row_key = "d1/t1/program_metric",
    dictionary_role = "property",
    search_query = "program metric",
    column_label = "Program metric",
    column_description = "A DFO-specific program metric",
    top_non_smn_source = NA_character_,
    top_non_smn_label = NA_character_,
    top_non_smn_iri = NA_character_,
    top_non_smn_ontology = NA_character_,
    placement_recommendation = "smn",
    llm_new_term_namespace = "gcdfo"
  )

  explicit_row <- render_ontology_term_request(
    gap,
    scope = "smn",
    scope_overrides = "profile",
    ask = FALSE,
    profile_name = "local-program"
  )
  forced <- render_ontology_term_request(
    gap,
    scope = "smn",
    ask = FALSE
  )
  namespace <- render_ontology_term_request(
    gap,
    scope = "auto",
    ask = FALSE
  )
  gap$llm_new_term_namespace <- NA_character_
  heuristic <- render_ontology_term_request(
    gap,
    scope = "auto",
    ask = FALSE
  )

  expect_equal(explicit_row$request_scope, "profile")
  expect_equal(forced$request_scope, "smn")
  expect_equal(namespace$request_scope, "gcdfo")
  expect_equal(heuristic$request_scope, "smn")
})


test_that("render_ontology_term_request errors when auto routing needs a profile name", {
  gaps <- tibble::tibble(
    dataset_id = c("d1", "d1"),
    table_id = c("t1", "t1"),
    column_name = c("run_id", "escape_rate"),
    code_value = c(NA_character_, NA_character_),
    target_scope = c("column", "column"),
    target_sdp_file = c("column_dictionary.csv", "column_dictionary.csv"),
    target_sdp_field = c("term_iri", "term_iri"),
    target_row_key = c("run_id", "escape_rate"),
    dictionary_role = c("variable", "variable"),
    search_query = c("run id", "escape rate"),
    column_label = c("Run ID", "Escape rate"),
    column_description = c("Dataset-specific run identifier", "Percent of fish escaping"),
    top_non_smn_source = c("gbif", "gcdfo"),
    top_non_smn_label = c("Run event id", "Escape rate"),
    top_non_smn_iri = c(NA_character_, NA_character_),
    top_non_smn_ontology = c(NA_character_, "https://w3id.org/gcdfo/salmon#"),
    top_non_smn_match_type = c("label", "label"),
    top_non_smn_score = c(0.9, 0.95),
    candidate_count = c(1L, 1L),
    non_smn_sources = c("gbif", "gcdfo"),
    placement_recommendation = c("profile", "smn"),
    placement_confidence = c(0.82, 0.95),
    placement_rationale = c("contains internal identifier signal", "shared domain concept")
  )

  expect_error(
    render_ontology_term_request(gaps, scope = "auto", ask = FALSE),
    "Non-interactive profile-scoped requests require `profile_name`"
  )
})


test_that("submit_term_request_issues dry run and mock post", {
  reqs <- tibble::tibble(
    request_title = c("Request new shared SMN term: escape rate"),
    request_body = c("body"),
    request_scope = c("smn"),
    ontology_repo = c("salmon-data-mobilization/salmon-domain-ontology"),
    issue_labels = list(NULL)
  )

  dry <- submit_term_request_issues(reqs, dry_run = TRUE, confirm = FALSE)
  expect_equal(dry$status, "dry_run")
  expect_true(all(is.na(dry$issue_number)))

  called <- 0L
  with_mocked_bindings(
    .metasalmon_post_issue = function(...) {
      called <<- called + 1L
      list(number = 42L, html_url = "https://github.com/salmon-data-mobilization/salmon-domain-ontology/issues/42")
    },
    {
      submitted <- submit_term_request_issues(reqs, dry_run = FALSE, confirm = FALSE, token = "test-token")
      expect_equal(called, 1L)
      expect_equal(submitted$status, "submitted")
      expect_equal(submitted$issue_number, 42L)
    }
  )
})

test_that("submit_term_request_issues includes GCDFO in dry-run routing", {
  reqs <- tibble::tibble(
    request_title = "Request new GCDFO term: program metric",
    request_body = "body",
    request_scope = "gcdfo",
    ontology_repo = "dfo-pacific-science/dfo-salmon-ontology",
    issue_labels = list(NULL)
  )

  dry <- submit_term_request_issues(reqs, dry_run = TRUE, confirm = FALSE)

  expect_equal(dry$status, "dry_run")
  expect_equal(dry$request_scope, "gcdfo")
  expect_equal(dry$ontology_repo, "dfo-pacific-science/dfo-salmon-ontology")
})

test_that("submit_term_request_issues posts each request to its row-level ontology repo", {
  reqs <- tibble::tibble(
    request_title = c("Request A", "Request B"),
    request_body = c("body a", "body b"),
    request_scope = c("smn", "profile"),
    ontology_repo = c(
      "salmon-data-mobilization/salmon-domain-ontology",
      "dfo-pacific-science/salmon-profile-ontology"
    ),
    issue_labels = list(NULL, NULL)
  )

  called_repos <- character()
  with_mocked_bindings(
    .metasalmon_post_issue = function(repo, ...) {
      called_repos <<- c(called_repos, repo)
      list(number = 1L, html_url = paste0("https://github.com/", repo, "/issues/1"))
    },
    {
      submitted <- submit_term_request_issues(reqs, dry_run = FALSE, confirm = FALSE, token = "test-token")
      expect_equal(nrow(submitted), 2L)
      expect_equal(submitted$status, c("submitted", "submitted"))
    }
  )

  expect_equal(called_repos, reqs$ontology_repo)
})
