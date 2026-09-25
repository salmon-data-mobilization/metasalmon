#!/usr/bin/env Rscript
# Build the conformance fixtures for the semantic review packet contract
# (S16 step 1, hub item B-326) under tests/testthat/fixtures/semantic-review/v1/.
#
# The fixtures are one contract shared with metasalmonpy (hub item B-327),
# vendored there byte-identically: each side checks its copy against
# manifest.json, builds every case's packet and compares it with the golden
# packet (producer removed), ingests the harness file and compares the
# record, findings, suggestions and status after reading, and asserts the
# error code of every reject variant. The Theme A cases add an
# `expected/events.json` produced through the benchmark's own event builder,
# so both sides can evaluate the recorded oracles.
#
# Run from the repository root:
#
#     Rscript scripts/build-semantic-review-fixtures.R
#
# It rewrites every golden file. A change in the packet's bytes is a change
# to the contract and needs the same change in metasalmonpy's copy; a change
# in a golden CSV needs a NEWS entry saying which behaviour moved.
#
# Every input is in-memory with injected candidates and text-only context,
# which is the bar the execplan sets for cross-language byte identity
# (section 2.7): a real package would bring ranking and library-specific
# text extraction into the bytes.

suppressPackageStartupMessages({
  pkgload::load_all(".", quiet = TRUE)
  library(testthat)
})
source(file.path("tests", "testthat", "helper-semantic-review.R"))
options(metasalmon.llm_deprecation_quiet = TRUE)

root <- file.path("tests", "testthat", "fixtures", "semantic-review", "v1")
cases_root <- file.path(root, "cases")
unlink(cases_root, recursive = TRUE)
dir.create(cases_root, recursive = TRUE, showWarnings = FALSE)

canonical_json <- metasalmon:::.ms_semantic_review_canonical_bytes
write_json_file <- function(value, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  writeBin(canonical_json(value), path)
}
rows_to_objects <- function(frame) {
  frame <- tibble::as_tibble(frame)
  lapply(seq_len(nrow(frame)), function(i) {
    stats::setNames(lapply(names(frame), function(col) {
      value <- frame[[col]][[i]]
      if (is.null(value) || length(value) == 0L || is.na(value)) NULL else value
    }), names(frame))
  })
}
write_csv_file <- function(frame, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  frame <- metasalmon:::.ms_semantic_review_character_frame(frame)
  readr::write_csv(frame, path, na = "")
}

# -----------------------------------------------------------------------------
# Building blocks
# -----------------------------------------------------------------------------

dictionary_row <- function(column_name, column_label, column_description, column_role = "measurement",
                           value_type = "number", unit_label = NA_character_, dataset_id = "fixture-1",
                           table_id = "catch") {
  tibble::tibble(
    dataset_id = dataset_id, table_id = table_id, column_name = column_name,
    column_label = column_label, column_description = column_description,
    column_role = column_role, value_type = value_type, unit_label = unit_label,
    unit_iri = NA_character_, term_iri = NA_character_, property_iri = NA_character_,
    entity_iri = NA_character_, constraint_iri = NA_character_,
    statistical_modifier_iri = NA_character_, term_type = NA_character_
  )
}

target_row <- function(column_name, role, field, query, label, description,
                       scope = "column", file = "column_dictionary.csv",
                       code_value = NA_character_, code_label = NA_character_,
                       code_description = NA_character_, column_label = label,
                       column_description = description, dataset_id = "fixture-1",
                       table_id = "catch") {
  row_key <- switch(
    scope,
    column = paste(dataset_id, table_id, column_name, sep = "/"),
    code = paste(dataset_id, table_id, column_name, code_value, sep = "/"),
    table = paste(dataset_id, table_id, sep = "/"),
    dataset = dataset_id
  )
  tibble::tibble(
    dataset_id = dataset_id, table_id = table_id, column_name = column_name,
    code_value = code_value, dictionary_role = role, search_role = role,
    target_scope = scope, target_sdp_file = file, target_sdp_field = field,
    target_row_key = row_key, target_label = label, target_description = description,
    search_query = query, target_query_basis = "column_description",
    target_query_context = paste0(label, ": ", description),
    column_label = column_label, column_description = column_description,
    code_label = code_label, code_description = code_description
  )
}

candidate_rows <- function(target, labels, iris, sources, definitions, scores,
                           term_type = "owl_class", role_hints = NA_character_,
                           type_iris = NA_character_, resource_kind = NA_character_) {
  n <- length(labels)
  dplyr::bind_cols(
    target[rep(1L, n), , drop = FALSE],
    tibble::tibble(
      label = labels, iri = iris, source = sources,
      ontology = ifelse(sources == "qudt", "QUDT", ifelse(sources == "smn", "Salmon Ontology", sources)),
      role = target$dictionary_role[[1]], match_type = "label_partial",
      definition = definitions, score = scores, term_type = rep_len(term_type, n),
      role_hints = rep_len(role_hints, n), type_iris = rep_len(type_iris, n),
      resource_kind = rep_len(resource_kind, n),
      retrieval_query = target$search_query[[1]], retrieval_pass = 1L
    )
  )
}

harness_rows <- function(targets, ...) {
  dplyr::bind_rows(lapply(seq_len(nrow(targets)), function(i) {
    semantic_review_harness_row(targets[i, , drop = FALSE], ...)
  }))
}

# The catch_weight bundle used by several cases.
catch_weight_dictionary <- function() {
  dictionary_row("CATCH_WEIGHT", "Catch weight", "Total weight of the retained catch.", unit_label = "kilogram")
}
catch_weight_targets <- function() {
  dplyr::bind_rows(
    target_row("CATCH_WEIGHT", "variable", "term_iri", "catch weight", "Catch weight", "Total weight of the retained catch."),
    target_row("CATCH_WEIGHT", "property", "property_iri", "mass of catch", "Mass", "The mass of the retained catch.", column_label = "Catch weight", column_description = "Total weight of the retained catch."),
    target_row("CATCH_WEIGHT", "entity", "entity_iri", "retained catch", "Catch", "The retained catch of a fishing event.", column_label = "Catch weight", column_description = "Total weight of the retained catch."),
    target_row("CATCH_WEIGHT", "unit", "unit_iri", "kilogram", "Kilogram", "Unit of mass.", column_label = "Catch weight", column_description = "Total weight of the retained catch.")
  )
}
catch_weight_candidates <- function(targets) {
  dplyr::bind_rows(
    candidate_rows(
      targets[1, ], c("Catch weight", "Fish weight"),
      c("https://w3id.org/smn/CatchWeight", "https://w3id.org/smn/FishWeight"),
      c("smn", "smn"),
      c("The total mass of the organisms in a catch.", "The body mass of an individual fish."),
      c(0.94, 0.61)
    ),
    candidate_rows(
      targets[2, ], c("Mass", "Length"),
      c("http://qudt.org/vocab/quantitykind/Mass", "http://qudt.org/vocab/quantitykind/Length"),
      c("qudt", "qudt"),
      c("The mass of a body.", "The length of a body."),
      c(0.90, 0.40), term_type = "qudt_quantitykind"
    ),
    candidate_rows(
      targets[3, ], c("Catch", "Fish"),
      c("https://w3id.org/smn/Catch", "https://w3id.org/smn/Fish"),
      c("smn", "smn"),
      c("The organisms retained by a fishing event.", "An individual fish."),
      c(0.88, 0.52)
    ),
    candidate_rows(
      targets[4, ], c("Kilogram", "Metre"),
      c("http://qudt.org/vocab/unit/KiloGM", "http://qudt.org/vocab/unit/M"),
      c("qudt", "qudt"),
      c("The SI unit of mass.", "The SI unit of length."),
      c(0.97, 0.30), term_type = "qudt_unit"
    )
  )
}
catch_weight_context <- "CATCH_WEIGHT records the total mass of the retained catch in kilograms, weighed on deck with a calibrated scale after sorting."

# -----------------------------------------------------------------------------
# Case runner
# -----------------------------------------------------------------------------

search_responses <- list()
add_search_response <- function(query, role, rows) {
  search_responses[[paste(query, role, sep = "|")]] <<- rows_to_objects(rows)
}

write_case <- function(case_id, dictionary, targets, candidates, harness, context_text = character(),
                       harness_pass_2 = NULL, expect_warning = FALSE, expected_events = NULL) {
  case_dir <- file.path(cases_root, case_id)
  dir.create(case_dir, recursive = TRUE, showWarnings = FALSE)
  input <- list(
    case_id = case_id,
    dictionary = rows_to_objects(dictionary),
    targets = rows_to_objects(targets),
    candidates = rows_to_objects(candidates),
    context_text = metasalmon:::.ms_json_array(context_text),
    top_n = 5L
  )
  write_json_file(input, file.path(case_dir, "input.json"))

  dict <- semantic_review_case_dictionary(semantic_review_read_json(file.path(case_dir, "input.json")))
  review_dir <- file.path(tempfile("semantic-review-"), "review")
  built <- write_semantic_review_packet(dict, context_text = context_text, review_dir = review_dir, quiet = TRUE)
  file.copy(built$path, file.path(case_dir, "packet-pass-1.json"), overwrite = TRUE)

  harness_path <- file.path(case_dir, "assessments-pass-1.csv")
  semantic_review_write_harness(harness, harness_path, packet_id = built$packet_id)
  counter <- new.env(parent = emptyenv())
  counter$calls <- 0L
  counter$log <- list()
  search_fn <- semantic_review_fake_search(search_responses, counter)
  ingest <- function(...) {
    if (expect_warning) {
      suppressWarnings(ingest_semantic_assessments(...))
    } else {
      ingest_semantic_assessments(...)
    }
  }
  result <- ingest(dict, assessments = harness_path, review_dir = review_dir, search_fn = search_fn, quiet = TRUE)
  write_expected <- function(result, pass) {
    expected_dir <- file.path(case_dir, "expected")
    write_csv_file(result$assessments, file.path(expected_dir, paste0("record-pass-", pass, ".csv")))
    write_csv_file(result$findings, file.path(expected_dir, paste0("findings-pass-", pass, ".csv")))
    write_csv_file(result$suggestions, file.path(expected_dir, paste0("suggestions-pass-", pass, ".csv")))
    write_json_file(list(
      status = result$status,
      pass = as.integer(result$pass),
      packet_id = result$packet_id,
      has_next_packet = !is.null(result$next_packet),
      summary = list(
        decisions = as.list(result$summary$decisions),
        errors = as.integer(result$summary$errors),
        downgrades = as.integer(result$summary$downgrades),
        escalations = as.integer(result$summary$escalations),
        retries = as.integer(result$summary$retries),
        awaiting_pass_2 = as.integer(result$summary$awaiting_pass_2)
      ),
      search_calls = counter$calls
    ), file.path(expected_dir, paste0("status-pass-", pass, ".json")))
  }
  write_expected(result, 1L)
  if (!is.null(result$next_packet)) {
    file.copy(result$next_packet, file.path(case_dir, "packet-pass-2.json"), overwrite = TRUE)
    stopifnot(!is.null(harness_pass_2))
    harness_2_path <- file.path(case_dir, "assessments-pass-2.csv")
    pass_2_id <- semantic_review_read_json(result$next_packet)$packet_id
    semantic_review_write_harness(harness_pass_2(result), harness_2_path, packet_id = pass_2_id)
    counter$calls <- 0L
    result_2 <- ingest(dict, assessments = harness_2_path, review_dir = review_dir, search_fn = search_fn, quiet = TRUE)
    write_expected(result_2, 2L)
  }
  if (!is.null(expected_events)) {
    write_json_file(expected_events(result, dict), file.path(case_dir, "expected", "events.json"))
  }
  invisible(list(dir = case_dir, result = result, review_dir = review_dir, dict = dict))
}

# -----------------------------------------------------------------------------
# Cases
# -----------------------------------------------------------------------------

# A. A measurement bundle, every slot accepted, nothing to find.
{
  targets <- catch_weight_targets()
  candidates <- catch_weight_candidates(targets)
  harness <- dplyr::bind_rows(
    semantic_review_harness_row(targets[1, ], llm_decision = "accept", llm_confidence = 0.93, llm_selected_candidate_index = 1L, llm_selected_iri = "https://w3id.org/smn/CatchWeight", llm_rationale = "The whole variable is the mass of the catch.", llm_bundle_summary = "Catch weight: mass of the retained catch in kilograms."),
    semantic_review_harness_row(targets[2, ], llm_decision = "accept", llm_confidence = 0.95, llm_selected_candidate_index = 1L, llm_selected_iri = "http://qudt.org/vocab/quantitykind/Mass", llm_rationale = "Mass is the measured property.", llm_bundle_summary = "Catch weight: mass of the retained catch in kilograms."),
    semantic_review_harness_row(targets[3, ], llm_decision = "accept", llm_confidence = 0.90, llm_selected_candidate_index = 1L, llm_selected_iri = "https://w3id.org/smn/Catch", llm_rationale = "The catch is the entity weighed.", llm_bundle_summary = "Catch weight: mass of the retained catch in kilograms."),
    semantic_review_harness_row(targets[4, ], llm_decision = "accept", llm_confidence = 0.97, llm_selected_candidate_index = 1L, llm_selected_iri = "http://qudt.org/vocab/unit/KiloGM", llm_rationale = "The dictionary unit is the kilogram.", llm_bundle_summary = "Catch weight: mass of the retained catch in kilograms.")
  )
  write_case("bundle_accept", catch_weight_dictionary(), targets, candidates, harness, context_text = catch_weight_context)
}

# B. The same bundle with a unit accept the validators refuse: a length unit
# for a mass dictionary unit.
{
  targets <- catch_weight_targets()
  candidates <- catch_weight_candidates(targets)
  harness <- dplyr::bind_rows(
    semantic_review_harness_row(targets[1, ], llm_decision = "accept", llm_confidence = 0.93, llm_selected_candidate_index = 1L, llm_selected_iri = "https://w3id.org/smn/CatchWeight", llm_rationale = "The whole variable is the mass of the catch."),
    semantic_review_harness_row(targets[2, ], llm_decision = "accept", llm_confidence = 0.95, llm_selected_candidate_index = 1L, llm_selected_iri = "http://qudt.org/vocab/quantitykind/Mass", llm_rationale = "Mass is the measured property."),
    semantic_review_harness_row(targets[3, ], llm_decision = "review", llm_confidence = 0.40, llm_rationale = "Unsure whether the catch or the fish is the entity."),
    semantic_review_harness_row(targets[4, ], llm_decision = "accept", llm_confidence = 0.80, llm_selected_candidate_index = 2L, llm_selected_iri = "http://qudt.org/vocab/unit/M", llm_rationale = "Metre.")
  )
  write_case("bundle_validator_downgrade", catch_weight_dictionary(), targets, candidates, harness, context_text = catch_weight_context)
}

# C. Target units: a categorical column, a code value, a table's observation
# unit, and a column with no candidates at all.
{
  dictionary <- dplyr::bind_rows(
    dictionary_row("GEAR_TYPE", "Gear type", "The fishing gear used.", column_role = "categorical", value_type = "string"),
    dictionary_row("SAMPLE_ID", "Sample identifier", "The sample's identifier.", column_role = "identifier", value_type = "string")
  )
  targets <- dplyr::bind_rows(
    target_row("GEAR_TYPE", "variable", "term_iri", "fishing gear type", "Gear type", "The fishing gear used."),
    target_row("GEAR_TYPE", "variable", "term_iri", "gillnet", "Gillnet", "Gear code GN: gillnet.", scope = "code", file = "codes.csv", code_value = "GN", code_label = "Gillnet", code_description = "A gillnet.", column_label = "Gear type", column_description = "The fishing gear used."),
    target_row(NA_character_, "entity", "observation_unit_iri", "fishing event", "Fishing event", "One deployment of the gear.", scope = "table", file = "tables.csv", column_label = NA_character_, column_description = NA_character_),
    target_row("SAMPLE_ID", "variable", "term_iri", "sample identifier", "Sample identifier", "The sample's identifier.")
  )
  candidates <- dplyr::bind_rows(
    candidate_rows(targets[1, ], c("Fishing gear", "Gear"), c("https://w3id.org/smn/FishingGear", "https://w3id.org/smn/Gear"), c("smn", "smn"), c("The gear used to fish.", "Equipment."), c(0.85, 0.50)),
    candidate_rows(targets[2, ], c("Gillnet", "Net"), c("https://w3id.org/smn/Gillnet", "https://w3id.org/smn/Net"), c("smn", "smn"), c("A net that catches fish by the gills.", "A net."), c(0.91, 0.45)),
    candidate_rows(targets[3, ], c("Fishing event", "Sampling event"), c("https://w3id.org/smn/FishingEvent", "https://w3id.org/smn/SamplingEvent"), c("smn", "smn"), c("One deployment of fishing gear.", "One sampling occasion."), c(0.80, 0.70))
  )
  harness <- dplyr::bind_rows(
    semantic_review_harness_row(targets[1, ], llm_decision = "accept", llm_confidence = 0.86, llm_selected_candidate_index = 1L, llm_selected_iri = "https://w3id.org/smn/FishingGear", llm_rationale = "Fishing gear is the variable."),
    semantic_review_harness_row(targets[2, ], llm_decision = "accept", llm_confidence = 0.92, llm_selected_candidate_index = 2L, llm_selected_iri = "https://w3id.org/smn/Net", llm_rationale = "The code names a net."),
    semantic_review_harness_row(targets[3, ], llm_decision = "request_new_term", llm_confidence = 0.70, llm_rationale = "Neither event term is the observation unit.", llm_new_term_label = "Trawl tow", llm_new_term_definition = "One tow of a trawl net.", llm_new_term_namespace = "smn"),
    semantic_review_harness_row(targets[4, ], llm_decision = "review", llm_confidence = 0.10, llm_rationale = "No candidates were offered.", llm_missing_context = "What the identifier encodes.")
  )
  write_case("target_units", dictionary, targets, candidates, harness)
}

# D. A retry that widens the shortlist, answered at pass 2.
{
  dictionary <- dictionary_row("GEAR_TYPE", "Gear type", "The fishing gear used.", column_role = "categorical", value_type = "string")
  targets <- target_row("GEAR_TYPE", "variable", "term_iri", "gear type", "Gear type", "The fishing gear used.")
  candidates <- candidate_rows(targets, c("Equipment", "Tool"), c("https://w3id.org/smn/Equipment", "https://w3id.org/smn/Tool"), c("smn", "smn"), c("Equipment in general.", "A tool."), c(0.40, 0.30))
  add_search_response("fishing gear type", "variable", tibble::tibble(
    label = c("Fishing gear", "Gear deployment"),
    iri = c("https://w3id.org/smn/FishingGear", "https://w3id.org/smn/GearDeployment"),
    source = "smn", ontology = "Salmon Ontology", role = "variable", match_type = "label_partial",
    definition = c("The gear used to fish.", "The act of deploying gear."), score = c(0.92, 0.55),
    term_type = "owl_class"
  ))
  harness <- semantic_review_harness_row(targets, llm_decision = "retry_search", llm_confidence = 0.35, llm_rationale = "The shortlist is generic equipment; search for fishing gear.", llm_retry_query = "fishing gear type")
  harness_pass_2 <- function(result) {
    semantic_review_harness_row(targets, llm_decision = "accept", llm_confidence = 0.90, llm_selected_candidate_index = 1L, llm_selected_iri = "https://w3id.org/smn/FishingGear", llm_rationale = "The widened shortlist has the fishing gear term.")
  }
  write_case("retry_gain", dictionary, targets, candidates, harness, harness_pass_2 = harness_pass_2)
}

# E. Retries that go nowhere: a duplicate query, an identifier-like query,
# and a usable query that gains nothing.
{
  dictionary <- dplyr::bind_rows(
    dictionary_row("GEAR_TYPE", "Gear type", "The fishing gear used.", column_role = "categorical", value_type = "string"),
    dictionary_row("MESH_SIZE", "Mesh size", "The mesh size class.", column_role = "categorical", value_type = "string"),
    dictionary_row("VESSEL", "Vessel", "The vessel name.", column_role = "categorical", value_type = "string")
  )
  targets <- dplyr::bind_rows(
    target_row("GEAR_TYPE", "variable", "term_iri", "gear type", "Gear type", "The fishing gear used."),
    target_row("MESH_SIZE", "variable", "term_iri", "mesh size", "Mesh size", "The mesh size class."),
    target_row("VESSEL", "variable", "term_iri", "vessel", "Vessel", "The vessel name.")
  )
  candidates <- dplyr::bind_rows(
    candidate_rows(targets[1, ], "Equipment", "https://w3id.org/smn/Equipment", "smn", "Equipment in general.", 0.40),
    candidate_rows(targets[2, ], "Mesh", "https://w3id.org/smn/Mesh", "smn", "A mesh.", 0.45),
    candidate_rows(targets[3, ], "Vessel", "https://w3id.org/smn/Vessel", "smn", "A vessel.", 0.60)
  )
  add_search_response("fishing vessel", "variable", tibble::tibble(
    label = "Vessel", iri = "https://w3id.org/smn/Vessel", source = "smn", ontology = "Salmon Ontology",
    role = "variable", match_type = "label_partial", definition = "A vessel.", score = 0.60, term_type = "owl_class"
  ))
  harness <- dplyr::bind_rows(
    semantic_review_harness_row(targets[1, ], llm_decision = "retry_search", llm_confidence = 0.30, llm_rationale = "Try again.", llm_retry_query = "GEAR  Type"),
    semantic_review_harness_row(targets[2, ], llm_decision = "retry_search", llm_confidence = 0.30, llm_rationale = "Try the identifier.", llm_retry_query = "smn:MeshSize"),
    semantic_review_harness_row(targets[3, ], llm_decision = "retry_search", llm_confidence = 0.30, llm_rationale = "Try fishing vessel.", llm_retry_query = "fishing vessel")
  )
  write_case("retry_dead_ends", dictionary, targets, candidates, harness)
}

# F. Rejections escalate, including one carrying a stray index.
{
  targets <- catch_weight_targets()
  candidates <- catch_weight_candidates(targets)
  harness <- dplyr::bind_rows(
    semantic_review_harness_row(targets[1, ], llm_decision = "reject_shortlist", llm_confidence = 0.85, llm_rationale = "Both candidates describe an individual fish or the wrong quantity."),
    semantic_review_harness_row(targets[2, ], llm_decision = "reject_shortlist", llm_confidence = 0.80, llm_selected_candidate_index = 99L, llm_rationale = "Neither quantity kind fits."),
    semantic_review_harness_row(targets[3, ], llm_decision = "accept", llm_confidence = 0.90, llm_selected_candidate_index = 1L, llm_selected_iri = "https://w3id.org/smn/Catch", llm_rationale = "The catch is the entity."),
    semantic_review_harness_row(targets[4, ], llm_decision = "accept", llm_confidence = 0.97, llm_selected_candidate_index = 1L, llm_selected_iri = "http://qudt.org/vocab/unit/KiloGM", llm_rationale = "Kilogram.")
  )
  write_case("reject_escalates", catch_weight_dictionary(), targets, candidates, harness, context_text = catch_weight_context)
}

# G. Every row-level rule, one categorical column each.
{
  names <- sprintf("FIELD_%02d", 1:15)
  dictionary <- dplyr::bind_rows(lapply(names, function(name) {
    dictionary_row(name, paste("Field", name), paste("Field", name, "description."), column_role = "categorical", value_type = "string")
  }))
  targets <- dplyr::bind_rows(lapply(names, function(name) {
    target_row(name, "variable", "term_iri", paste("field", tolower(name)), paste("Field", name), paste("Field", name, "description."))
  }))
  candidates <- dplyr::bind_rows(lapply(seq_len(nrow(targets)), function(i) {
    candidate_rows(
      targets[i, ], c("Term A", "Term B"),
      paste0("https://example.org/", tolower(names[[i]]), c("/a", "/b")),
      c("smn", "smn"), c("Term A.", "Term B."), c(0.8, 0.6)
    )
  }))
  iri <- function(i, which) paste0("https://example.org/", tolower(names[[i]]), "/", which)
  harness <- dplyr::bind_rows(
    semantic_review_harness_row(targets[1, ], llm_decision = "accept", llm_confidence = 0.9, llm_selected_candidate_index = 1L, llm_selected_iri = "https://example.org/not-offered", llm_rationale = "An IRI the packet did not offer."),
    semantic_review_harness_row(targets[2, ], llm_decision = "accept", llm_confidence = 0.9, llm_selected_candidate_index = 1L, llm_selected_iri = iri(2, "b"), llm_rationale = "Echo names candidate 2, index names 1."),
    semantic_review_harness_row(targets[3, ], llm_decision = "accept", llm_confidence = 0.9, llm_selected_candidate_index = 1L, llm_selected_iri = iri(3, "a"), llm_rationale = "Accept with a new-term label.", llm_new_term_label = "Something new"),
    semantic_review_harness_row(targets[4, ], llm_decision = "accept", llm_confidence = 0.9, llm_selected_candidate_index = "1.5", llm_selected_iri = iri(4, "a"), llm_rationale = "A fractional index."),
    # A declared error carrying a planted secret: the record holds the
    # redacted text, never the key.
    semantic_review_harness_row(targets[5, ], llm_error = "Provider rejected the request: api_key=sk-fixture-0123456789 was invalid."),
    # targets[6, ] has no row at all.
    semantic_review_harness_row(targets[7, ], llm_decision = "maybe", llm_confidence = 0.5, llm_rationale = "Not a decision."),
    semantic_review_harness_row(targets[8, ], llm_decision = "review", llm_confidence = 1.5, llm_rationale = "Confidence out of range."),
    semantic_review_harness_row(targets[9, ], llm_decision = "accept", llm_confidence = 0.9, llm_selected_iri = iri(9, "a"), llm_rationale = "Accept without an index."),
    semantic_review_harness_row(targets[10, ], llm_decision = "accept", llm_confidence = 0.9, llm_selected_candidate_index = 99L, llm_selected_iri = iri(10, "a"), llm_rationale = "Out-of-range index."),
    semantic_review_harness_row(targets[11, ], llm_decision = "accept", llm_confidence = 0.9, llm_selected_candidate_index = 1L, llm_rationale = "Accept without an echo."),
    semantic_review_harness_row(targets[12, ], llm_decision = "retry_search", llm_confidence = 0.3, llm_rationale = "Retry without a query."),
    semantic_review_harness_row(targets[13, ], llm_decision = "review", llm_confidence = 0.5, llm_rationale = "A package-owned column was written, and a planted secret: Authorization: Bearer fixture-token-abc123 ended up in the rationale.", llm_selected_label = "Should be overwritten", llm_context_sources = "should-be-overwritten"),
    semantic_review_harness_row(targets[14, ], llm_decision = "PROPOSE_NEW_TERM", llm_confidence = 0.7, llm_rationale = "The alias, upper-cased.", llm_new_term_label = "A new term"),
    semantic_review_harness_row(targets[15, ], llm_decision = "review", llm_confidence = 0.5, llm_selected_candidate_index = 3L, llm_rationale = "A stray index on a review.")
  )
  write_case("row_errors", dictionary, targets, candidates, harness, expect_warning = TRUE)
}

# H. File-level rejections: variants of the bundle_accept case, each with
# the error code the ingester must raise. The variant files sit beside
# reject.json; the test builds the case's packet, then ingests each variant.
{
  case_dir <- file.path(cases_root, "file_errors")
  dir.create(case_dir, recursive = TRUE, showWarnings = FALSE)
  base <- file.path(cases_root, "bundle_accept")
  file.copy(file.path(base, "input.json"), file.path(case_dir, "input.json"), overwrite = TRUE)
  file.copy(file.path(base, "packet-pass-1.json"), file.path(case_dir, "packet-pass-1.json"), overwrite = TRUE)
  harness <- semantic_review_read_csv(file.path(base, "assessments-pass-1.csv"))
  packet <- semantic_review_read_json(file.path(base, "packet-pass-1.json"))

  variants <- list()
  add_variant <- function(name, code, harness_rows = NULL, packet_value = NULL, packet_id = NULL, note,
                          sidecar_id = packet$packet_id) {
    files <- list()
    if (!is.null(harness_rows)) {
      files$assessments <- paste0(name, "-assessments.csv")
      semantic_review_write_harness(harness_rows, file.path(case_dir, files$assessments), packet_id = sidecar_id)
    }
    if (!is.null(packet_value)) {
      files$packet <- paste0(name, "-packet.json")
      write_json_file(packet_value, file.path(case_dir, files$packet))
    }
    variants[[length(variants) + 1L]] <<- c(list(name = name, expected_code = code, note = note, expected_packet_id = packet_id), files)
  }
  renamed <- harness
  names(renamed)[names(renamed) == "llm_rationale"] <- "rationale"
  add_variant("header", "header", harness_rows = renamed, note = "A column of the thirty is misnamed.")
  unknown <- harness
  unknown$search_query[[1]] <- "not the packet's query"
  add_variant("unknown_target", "unknown_target", harness_rows = unknown, note = "A row's identity names no packet target.")
  add_variant("duplicate_target", "duplicate_target", harness_rows = dplyr::bind_rows(harness, harness[1, ]), note = "Two rows share an identity.")
  tampered <- packet
  tampered$units[[1]]$slots[[1]]$candidates[[1]]$label <- "Edited label"
  add_variant("packet_integrity", "packet_integrity", packet_value = tampered, note = "The packet was edited after it was written; its packet_id no longer matches.")
  versioned <- packet
  versioned$packet_version <- "semantic-review-packet/0.9"
  versioned$packet_id <- metasalmon:::.ms_semantic_review_packet_id(versioned)
  add_variant("packet_version", "packet_version", packet_value = versioned, note = "A packet version this ingester does not read.")
  add_variant("packet_mismatch", "packet_mismatch", packet_id = strrep("0", 64), note = "The caller expected a different packet_id.")
  add_variant("packet_unbound", "packet_unbound", harness_rows = harness, sidecar_id = NULL, note = "Neither a sidecar nor a packet_id argument names the packet the assessments were made against.")
  add_variant("stale_sidecar", "packet_mismatch", harness_rows = harness, sidecar_id = strrep("f", 64), note = "The sidecar names a packet other than the one being ingested: a stale file after a rebuild.")
  add_variant("no_pass_2", "no_pass_2", note = "A pass-2 assessment file is given, but nothing asked for a second pass. The test copies the pass-1 file to the pass-2 name and passes the packet_id.")
  write_json_file(list(case_id = "file_errors", base_case = "bundle_accept", variants = variants), file.path(case_dir, "reject.json"))
}

# -----------------------------------------------------------------------------
# Theme A: the recorded oracles as ingest cases, plus three adversarial
# variants where the deterministic layer protects the record whatever the
# harness says.
# -----------------------------------------------------------------------------

theme_a_root <- file.path("tests", "testthat", "fixtures", "theme-a")
theme_a_cases <- semantic_review_read_json(file.path(theme_a_root, "cases-v1.json"))
theme_a_replay <- semantic_review_read_json(file.path(theme_a_root, "replay-v1.json"))
theme_a_replay_by_id <- stats::setNames(theme_a_replay$cases, vapply(theme_a_replay$cases, `[[`, character(1), "case_id"))

# The benchmark script's own event builder and prefill step, sourced the way
# tests/testthat/test-theme-a-benchmark.R sources it.
theme_a_env <- new.env(parent = globalenv())
sys.source(file.path("scripts", "theme-a-benchmark.R"), envir = theme_a_env)

theme_a_dictionary <- function(case) {
  context <- case$context
  tibble::tibble(
    dataset_id = context$dataset_id, table_id = context$table_id, column_name = context$column_name,
    column_label = context$column_label, column_description = context$column_description,
    column_role = context$column_role, value_type = "number",
    unit_label = if (is.null(context$unit)) NA_character_ else context$unit,
    unit_iri = NA_character_, term_iri = NA_character_, property_iri = NA_character_,
    entity_iri = NA_character_, constraint_iri = NA_character_,
    statistical_modifier_iri = NA_character_, method_iri = NA_character_, term_type = NA_character_
  )
}
theme_a_targets <- function(case) {
  semantic_review_rows_to_tibble(case$targets)
}
theme_a_candidates <- function(case, targets) {
  dplyr::bind_rows(lapply(case$candidates, function(candidate) {
    target <- targets[targets$dictionary_role == candidate$target_role, , drop = FALSE][1, , drop = FALSE]
    dplyr::bind_cols(target, tibble::tibble(
      label = candidate$label, iri = candidate$iri, source = candidate$source,
      ontology = candidate$ontology, role = candidate$target_role, match_type = "label_partial",
      definition = candidate$definition, score = as.numeric(candidate$score),
      term_type = candidate$term_type %||% NA_character_,
      definition_status = candidate$definition_status %||% NA_character_,
      retrieval_query = target$search_query[[1]], retrieval_pass = 1L
    ))
  }))
}
# The harness file: the replay rows' harness-owned columns plus the IRI echo.
theme_a_harness <- function(case, targets) {
  replay <- theme_a_replay_by_id[[case$case_id]]
  harness_cols <- c(
    "llm_decision", "llm_confidence", "llm_selected_candidate_index", "llm_selected_iri",
    "llm_rationale", "llm_missing_context", "llm_bundle_summary", "llm_retry_query",
    "llm_new_term_label", "llm_new_term_definition", "llm_new_term_namespace"
  )
  dplyr::bind_rows(lapply(replay$assessment_rows, function(row) {
    target <- targets[targets$dictionary_role == row$dictionary_role, , drop = FALSE][1, , drop = FALSE]
    values <- list()
    for (col in harness_cols) {
      if (!is.null(row[[col]])) values[[col]] <- row[[col]]
    }
    do.call(semantic_review_harness_row, c(list(target), values))
  }))
}
# The oracle events after the downstream prefill step, through the benchmark
# script's own builders: `apply_semantic_suggestions(strategy = "llm")` with
# the auto-apply roles, the REVIEW: marker, gap detection and the term
# request renderer.
theme_a_events <- function(result, dict) {
  original <- dict
  attr(original, "semantic_targets") <- NULL
  attr(original, "semantic_suggestions") <- NULL
  suggestions <- result$suggestions
  allowed_roles <- metasalmon:::.ms_create_sdp_llm_auto_apply_roles()
  auto <- metasalmon:::.ms_prepare_llm_auto_apply_suggestions(original, suggestions, allowed_roles = allowed_roles)
  final <- apply_semantic_suggestions(original, suggestions = auto, strategy = "llm", roles = allowed_roles, overwrite = FALSE, verbose = FALSE)
  final <- metasalmon:::.ms_mark_reviewed_dictionary_iris(final, original_dict = original, suggestions = auto, strategy = "llm")
  gap_input <- final
  attr(gap_input, "semantic_suggestions") <- suggestions
  attr(gap_input, "semantic_llm_assessments") <- result$assessments
  attr(gap_input, "semantic_targets") <- result$targets
  gaps <- detect_semantic_term_gaps(gap_input)
  requests <- if (nrow(gaps) > 0L) {
    render_ontology_term_request(gaps, scope = "auto", ask = FALSE, profile_name = "theme-a-benchmark")
  } else {
    tibble::tibble()
  }
  final_rows <- rows_to_objects(final)
  events <- theme_a_env$events_from_package_outputs(
    result$assessments,
    final_rows,
    rows_to_objects(gaps),
    rows_to_objects(requests)
  )
  list(
    events = metasalmon:::.ms_json_array(events),
    final_dictionary_rows = metasalmon:::.ms_json_array(final_rows),
    gap_count = nrow(gaps),
    term_request_count = nrow(requests)
  )
}

for (case in theme_a_cases$cases) {
  targets <- theme_a_targets(case)
  candidates <- theme_a_candidates(case, targets)
  harness <- theme_a_harness(case, targets)
  write_case(
    paste0("theme_a_", case$case_id), theme_a_dictionary(case), targets, candidates, harness,
    context_text = case$context$context_text, expected_events = theme_a_events
  )
}

# Adversarial variants: the harness accepts what the oracles forbid, and
# the validators or the escalation still protect the record.
{
  case <- Filter(function(c) identical(c$case_id, "catch_count"), theme_a_cases$cases)[[1]]
  targets <- theme_a_targets(case)
  candidates <- theme_a_candidates(case, targets)
  harness <- theme_a_harness(case, targets)
  accept_method <- harness
  method <- accept_method$dictionary_role == "method"
  accept_method$llm_decision[method] <- "accept"
  accept_method$llm_confidence[method] <- "0.80"
  accept_method$llm_selected_candidate_index[method] <- "1"
  accept_method$llm_selected_iri[method] <- "https://w3id.org/smn/ForkLengthMeasurementFieldMethod"
  accept_method$llm_rationale[method] <- "Adversarial: accept the fork-length method for a count with no procedure."
  write_case("theme_a_catch_count_accept_method", theme_a_dictionary(case), targets, candidates, accept_method,
    context_text = case$context$context_text, expected_events = theme_a_events)

  accept_context <- harness
  constraint <- accept_context$dictionary_role == "constraint"
  accept_context$llm_decision[constraint] <- "accept"
  accept_context$llm_confidence[constraint] <- "0.75"
  accept_context$llm_selected_candidate_index[constraint] <- "1"
  accept_context$llm_selected_iri[constraint] <- "https://w3id.org/smn/CatchContext"
  accept_context$llm_rationale[constraint] <- "Adversarial: accept catch context beside catch abundance."
  write_case("theme_a_catch_count_accept_context", theme_a_dictionary(case), targets, candidates, accept_context,
    context_text = case$context$context_text, expected_events = theme_a_events)

  gap_case <- Filter(function(c) identical(c$case_id, "synthetic_structured_gap"), theme_a_cases$cases)[[1]]
  gap_targets <- theme_a_targets(gap_case)
  gap_candidates <- theme_a_candidates(gap_case, gap_targets)
  reject <- theme_a_harness(gap_case, gap_targets)
  reject$llm_decision <- "reject_shortlist"
  reject$llm_new_term_label <- NA_character_
  reject$llm_new_term_definition <- NA_character_
  reject$llm_new_term_namespace <- NA_character_
  reject$llm_rationale <- "Adversarial: reject the shortlist outright instead of asking for a new term."
  write_case("theme_a_synthetic_structured_gap_reject", theme_a_dictionary(gap_case), gap_targets, gap_candidates, reject,
    context_text = gap_case$context$context_text, expected_events = theme_a_events)
}

# -----------------------------------------------------------------------------
# The shared search responses and the manifest
# -----------------------------------------------------------------------------

write_json_file(search_responses, file.path(root, "search-responses.json"))

files <- sort(list.files(root, recursive = TRUE, all.files = FALSE), method = "radix")
files <- setdiff(files, "manifest.json")
manifest <- list(
  fixture_version = "v1",
  packet_version = metasalmon:::.ms_semantic_review_packet_version(),
  description = "Conformance fixtures for the semantic review packet contract. Every file below is listed with its SHA-256; a vendored copy is checked against this list. Packets are compared with their producer member removed; CSVs are compared after reading.",
  files = stats::setNames(lapply(files, function(file) semantic_review_sha256_file(file.path(root, file))), files)
)
write_json_file(manifest, file.path(root, "manifest.json"))
cat("Wrote", length(files), "fixture files under", root, "\n")
