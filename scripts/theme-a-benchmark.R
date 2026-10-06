#!/usr/bin/env Rscript

# Theme A semantic-review evidence harness.
#
# Replay scores recorded synthetic cases with the same semantic oracles used
# by the package ingester's conformance tests. Compare checks two validated
# replay fixtures for blocking regressions. Neither mode calls a provider.

`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

abort <- function(...) {
  stop(sprintf(...), call. = FALSE)
}

script_path <- local({
  sourced_path <- tryCatch(
    sys.frame(1L)$ofile,
    error = function(e) NULL
  )
  if (!is.null(sourced_path) &&
      length(sourced_path) == 1L &&
      nzchar(sourced_path) &&
      file.exists(sourced_path)) {
    return(normalizePath(
      sourced_path,
      winslash = "/",
      mustWork = TRUE
    ))
  }
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)
  if (length(file_arg) > 0L &&
      !identical(sub("^--file=", "", file_arg[[1L]]), "-")) {
    normalizePath(sub("^--file=", "", file_arg[[1L]]), winslash = "/", mustWork = TRUE)
  } else {
    normalizePath(".", winslash = "/", mustWork = TRUE)
  }
})

repo_root <- local({
  candidates <- unique(c(
    dirname(script_path),
    file.path(dirname(script_path), ".."),
    script_path
  ))
  for (candidate in candidates) {
    if (file.exists(file.path(candidate, "DESCRIPTION"))) {
      return(normalizePath(candidate, winslash = "/", mustWork = TRUE))
    }
  }
  abort("Could not locate the metasalmon repository root.")
})

theme_a_paths <- list(
  schema = file.path(repo_root, "tests", "testthat", "fixtures", "theme-a", "schema-v1.json"),
  cases = file.path(repo_root, "tests", "testthat", "fixtures", "theme-a", "cases-v1.json"),
  replay = file.path(repo_root, "tests", "testthat", "fixtures", "theme-a", "replay-v1.json"),
  ontology_manifest = file.path(
    repo_root,
    "tests",
    "testthat",
    "fixtures",
    "theme-a",
    "ontology-manifest-v1.json"
  ),
  historical = file.path(repo_root, "notes", "evidence", "theme-a", "historical-observations-v1.json")
)

usage <- function() {
  paste(
    "Usage:",
    "  Rscript scripts/theme-a-benchmark.R [replay] [options]",
    "  Rscript scripts/theme-a-benchmark.R compare --baseline=FILE --candidate=FILE",
    "",
    "Common options:",
    "  --schema=FILE       Versioned fixture schema manifest.",
    "  --cases=FILE        Versioned case fixture.",
    "  --replay=FILE       Offline replay observations.",
    "  --ontology-manifest=FILE  Pinned ontology IRI/type contract.",
    "  --historical=FILE   Prose-only historical observations.",
    "  --output=FILE       Optional JSON evaluation output for replay/compare.",
    sep = "\n"
  )
}

parse_args <- function(args) {
  mode <- "replay"
  if (length(args) > 0L && !startsWith(args[[1L]], "--")) {
    mode <- tolower(args[[1L]])
    args <- args[-1L]
  }

  allowed_modes <- c("replay", "compare")
  if (!mode %in% allowed_modes) {
    abort("Unknown mode '%s'. Expected one of: %s.", mode, paste(allowed_modes, collapse = ", "))
  }

  options <- list(
    mode = mode,
    help = FALSE,
    schema = theme_a_paths$schema,
    cases = theme_a_paths$cases,
    replay = theme_a_paths$replay,
    ontology_manifest = theme_a_paths$ontology_manifest,
    historical = theme_a_paths$historical,
    output = NULL,
    baseline = NULL,
    candidate = NULL
  )

  for (arg in args) {
    if (arg %in% c("-h", "--help")) {
      options$help <- TRUE
      next
    }
    if (!startsWith(arg, "--") || !grepl("=", arg, fixed = TRUE)) {
      abort("Unsupported argument '%s'. Use --name=value.", arg)
    }

    parts <- strsplit(sub("^--", "", arg), "=", fixed = TRUE)[[1L]]
    key <- gsub("-", "_", parts[[1L]], fixed = TRUE)
    value <- paste(parts[-1L], collapse = "=")
    if (!key %in% names(options)) {
      abort("Unknown option '--%s'.", parts[[1L]])
    }
    options[[key]] <- value
  }

  options
}

read_json <- function(path, label) {
  if (is.null(path) || !nzchar(path) || !file.exists(path)) {
    abort("%s does not exist: %s", label, path %||% "<missing>")
  }
  tryCatch(
    jsonlite::read_json(path, simplifyVector = FALSE),
    error = function(e) abort("Could not parse %s '%s': %s", label, path, conditionMessage(e))
  )
}

write_json <- function(value, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(
    value,
    path,
    auto_unbox = TRUE,
    pretty = TRUE,
    na = "null",
    null = "null"
  )
  invisible(path)
}

require_object <- function(x, field) {
  if (!is.list(x) || is.null(names(x)) || any(!nzchar(names(x)))) {
    abort("%s must be a JSON object.", field)
  }
  invisible(x)
}

require_array <- function(x, field) {
  if (!is.list(x) || (length(x) > 0L && !is.null(names(x)))) {
    abort("%s must be a JSON array.", field)
  }
  invisible(x)
}

require_fields <- function(x, required, field) {
  missing <- setdiff(required, names(x))
  if (length(missing) > 0L) {
    abort("%s is missing required field(s): %s.", field, paste(missing, collapse = ", "))
  }
  invisible(x)
}

require_scalar_character <- function(x, field, allow_empty = FALSE) {
  if (is.null(x) || length(x) != 1L || !is.character(x) || is.na(x[[1L]])) {
    abort("%s must be one character value.", field)
  }
  if (!allow_empty && !nzchar(trimws(x[[1L]]))) {
    abort("%s cannot be empty.", field)
  }
  invisible(x[[1L]])
}

require_scalar_logical <- function(x, field) {
  if (is.null(x) || length(x) != 1L || !is.logical(x) || is.na(x[[1L]])) {
    abort("%s must be true or false.", field)
  }
  invisible(x[[1L]])
}

schema_contracts <- function(schema) {
  require_object(schema, "schema")
  require_fields(
    schema,
    c("$schema", "$id", "schema_version", "x-metasalmon-contracts"),
    "schema"
  )
  if (!identical(schema$schema_version, "theme-a-schema-v1")) {
    abort("Unsupported fixture schema version: %s.", schema$schema_version %||% "<missing>")
  }
  contracts <- schema[["x-metasalmon-contracts"]]
  require_object(contracts, "schema.x-metasalmon-contracts")
  require_fields(
    contracts,
    c(
      "cases_schema_version",
      "replay_schema_version",
      "historical_schema_version",
      "ontology_manifest_schema_version",
      "target_columns",
      "semantic_target_key",
      "assessment_prefix_columns",
      "assessment_columns",
      "oracle_buckets",
      "oracle_event_types",
      "required_case_ids"
    ),
    "schema.x-metasalmon-contracts"
  )

  if (length(contracts$target_columns) != 19L) {
    abort("The Theme A target contract must contain exactly 19 columns.")
  }
  expected_target_key <- c(
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
  if (!identical(unlist(contracts$semantic_target_key), expected_target_key)) {
    abort("The Theme A semantic target key must contain the canonical nine fields.")
  }
  if (length(contracts$assessment_prefix_columns) != 28L) {
    abort("The assessment prefix contract must contain exactly 28 columns.")
  }
  if (length(contracts$assessment_columns) != 30L) {
    abort("The Theme A assessment contract must contain exactly 30 columns.")
  }
  if (!identical(
    contracts$assessment_columns[seq_along(contracts$assessment_prefix_columns)],
    contracts$assessment_prefix_columns
  )) {
    abort("The 30-column assessment contract must preserve the existing 28-column prefix.")
  }
  expected_tail <- c("llm_escalated_from", "llm_retry_query_rejection_reason")
  actual_tail <- utils::tail(unlist(contracts$assessment_columns), 2L)
  if (!identical(actual_tail, expected_tail)) {
    abort("The assessment contract must append llm_escalated_from and llm_retry_query_rejection_reason.")
  }

  contracts
}

validate_oracle_rule <- function(rule, case_id, bucket, index, contracts) {
  field <- sprintf("cases[%s].oracle.%s[%d]", case_id, bucket, index)
  require_object(rule, field)
  require_fields(rule, c("rule_id", "type"), field)
  require_scalar_character(rule$rule_id, paste0(field, ".rule_id"))
  require_scalar_character(rule$type, paste0(field, ".type"))
  if (!rule$type %in% unlist(contracts$oracle_event_types)) {
    abort(
      "%s.type must be one of: %s.",
      field,
      paste(unlist(contracts$oracle_event_types), collapse = ", ")
    )
  }
  if (!is.null(rule$advisory)) {
    require_scalar_logical(rule$advisory, paste0(field, ".advisory"))
  }
  invisible(rule)
}

validate_ontology_provenance <- function(provenance, field) {
  require_array(provenance, field)
  if (length(provenance) == 0L) {
    abort("%s must contain at least one pinned ontology revision.", field)
  }

  sources <- character()
  for (i in seq_along(provenance)) {
    item <- provenance[[i]]
    item_field <- sprintf("%s[%d]", field, i)
    require_object(item, item_field)
    require_fields(
      item,
      c("source", "repository", "revision", "revision_url", "observed_at"),
      item_field
    )
    for (name in c("source", "repository", "revision", "revision_url", "observed_at")) {
      require_scalar_character(item[[name]], paste0(item_field, ".", name))
    }
    if (!grepl("^https://", item$revision_url)) {
      abort("%s.revision_url must be an HTTPS URL.", item_field)
    }
    if (!grepl("^[0-9a-f]{40}$", item$revision)) {
      abort("%s.revision must be a full 40-character Git commit.", item_field)
    }
    sources <- c(sources, item$source)
  }
  if (anyDuplicated(sources) > 0L) {
    abort("%s must contain unique source values.", field)
  }
  invisible(provenance)
}

validate_ontology_manifest <- function(manifest, cases, contracts) {
  require_object(manifest, "ontology manifest")
  require_fields(
    manifest,
    c("schema_version", "evidence_status", "description", "sources", "terms"),
    "ontology manifest"
  )
  if (!identical(
    manifest$schema_version,
    contracts$ontology_manifest_schema_version
  )) {
    abort(
      "Ontology manifest schema_version must be '%s'.",
      contracts$ontology_manifest_schema_version
    )
  }
  if (!identical(
    manifest$evidence_status,
    "pinned_primary_source_contract"
  )) {
    abort(
      "Ontology manifest evidence_status must be pinned_primary_source_contract."
    )
  }

  require_array(manifest$sources, "ontology manifest.sources")
  require_array(manifest$terms, "ontology manifest.terms")
  if (length(manifest$sources) == 0L || length(manifest$terms) == 0L) {
    abort("Ontology manifest must contain sources and terms.")
  }

  source_ids <- character()
  for (i in seq_along(manifest$sources)) {
    source <- manifest$sources[[i]]
    field <- sprintf("ontology manifest.sources[%d]", i)
    require_object(source, field)
    require_fields(
      source,
      c(
        "source", "repository", "revision", "revision_url",
        "artifact_path", "artifact_url", "artifact_sha256"
      ),
      field
    )
    for (name in c(
      "source", "repository", "revision", "revision_url",
      "artifact_path", "artifact_url", "artifact_sha256"
    )) {
      require_scalar_character(source[[name]], paste0(field, ".", name))
    }
    if (!grepl("^[0-9a-f]{40}$", source$revision) ||
        !grepl("^[0-9a-f]{64}$", source$artifact_sha256) ||
        !grepl("^https://", source$revision_url) ||
        !grepl("^https://", source$artifact_url)) {
      abort("%s must pin valid commit, artifact URL, and SHA-256 values.", field)
    }
    source_ids <- c(source_ids, source$source)
  }
  if (anyDuplicated(source_ids) > 0L) {
    abort("Ontology manifest source values must be unique.")
  }

  provenance_by_source <- stats::setNames(
    cases$ontology_provenance,
    vapply(cases$ontology_provenance, `[[`, character(1), "source")
  )
  manifest_by_source <- stats::setNames(manifest$sources, source_ids)
  if (!setequal(names(provenance_by_source), names(manifest_by_source))) {
    abort("Cases ontology provenance and ontology manifest sources must match.")
  }
  for (source in source_ids) {
    expected <- manifest_by_source[[source]]
    actual <- provenance_by_source[[source]]
    for (name in c("repository", "revision", "revision_url")) {
      if (!identical(actual[[name]], expected[[name]])) {
        abort(
          "Cases ontology provenance for '%s' disagrees with the manifest field '%s'.",
          source,
          name
        )
      }
    }
  }

  term_iris <- character()
  for (i in seq_along(manifest$terms)) {
    term <- manifest$terms[[i]]
    field <- sprintf("ontology manifest.terms[%d]", i)
    require_object(term, field)
    require_fields(
      term,
      c(
        "iri", "source", "label", "candidate_term_type",
        "native_rdf_types", "source_definition",
        "source_definition_status"
      ),
      field
    )
    for (name in c("iri", "source", "label", "candidate_term_type")) {
      require_scalar_character(term[[name]], paste0(field, ".", name))
    }
    require_scalar_character(
      term$source_definition_status,
      paste0(field, ".source_definition_status")
    )
    if (!term$source_definition_status %in% c(
      "normalized_source_literal",
      "not_provided"
    ) || (
      identical(term$source_definition_status, "not_provided") &&
        !is.null(term$source_definition)
    ) || (
      identical(
        term$source_definition_status,
        "normalized_source_literal"
      ) &&
        is.null(term$source_definition)
    )) {
      abort("%s has inconsistent source-definition provenance.", field)
    }
    if (!term$source %in% source_ids) {
      abort("%s.source is not declared by ontology manifest.sources.", field)
    }
    require_array(term$native_rdf_types, paste0(field, ".native_rdf_types"))
    if (length(term$native_rdf_types) == 0L ||
        any(!vapply(
          term$native_rdf_types,
          function(value) {
            is.character(value) &&
              length(value) == 1L &&
              grepl("^https?://", value)
          },
          logical(1)
        ))) {
      abort("%s.native_rdf_types must contain full RDF type IRIs.", field)
    }
    term_iris <- c(term_iris, term$iri)
  }
  if (anyDuplicated(term_iris) > 0L) {
    abort("Ontology manifest term IRIs must be unique.")
  }

  manifest_by_iri <- stats::setNames(manifest$terms, term_iris)
  fixture_candidates <- unlist(
    lapply(cases$cases, `[[`, "candidates"),
    recursive = FALSE
  )
  candidate_iris <- unique(vapply(
    fixture_candidates,
    `[[`,
    character(1),
    "iri"
  ))
  if (!setequal(candidate_iris, term_iris)) {
    abort(
      paste0(
        "Ontology manifest IRIs must exactly match fixture candidate IRIs. ",
        "Missing: %s. Unused: %s."
      ),
      paste(setdiff(candidate_iris, term_iris), collapse = ", "),
      paste(setdiff(term_iris, candidate_iris), collapse = ", ")
    )
  }

  for (candidate in fixture_candidates) {
    term <- manifest_by_iri[[candidate$iri]]
    if (!identical(candidate$source, term$source) ||
        !identical(candidate$term_type, term$candidate_term_type)) {
      abort(
        "Fixture candidate '%s' disagrees with its pinned source or native candidate type.",
        candidate$iri
      )
    }
    require_scalar_character(
      candidate$definition_status,
      sprintf("fixture candidate %s.definition_status", candidate$iri)
    )
    if (!candidate$definition_status %in% c(
      "curated_paraphrase",
      "source_definition"
    )) {
      abort(
        "Fixture candidate '%s' has an unsupported definition_status.",
        candidate$iri
      )
    }
    if (identical(candidate$definition_status, "source_definition") &&
        !identical(candidate$definition, term$source_definition)) {
      abort(
        "Fixture candidate '%s' claims a source definition but does not match it.",
        candidate$iri
      )
    }
  }

  invisible(manifest)
}

validate_cases <- function(cases, contracts, ontology_manifest = NULL) {
  require_object(cases, "cases fixture")
  require_fields(
    cases,
    c(
      "schema_version", "fixture_version", "evidence_status",
      "ontology_provenance", "cases"
    ),
    "cases fixture"
  )
  if (!identical(cases$schema_version, contracts$cases_schema_version)) {
    abort("Cases fixture schema_version must be '%s'.", contracts$cases_schema_version)
  }
  if (!identical(cases$evidence_status, "synthetic_regression_exemplar")) {
    abort("Cases fixture evidence_status must be synthetic_regression_exemplar.")
  }
  validate_ontology_provenance(
    cases$ontology_provenance,
    "cases fixture.ontology_provenance"
  )
  require_array(cases$cases, "cases fixture.cases")
  if (length(cases$cases) == 0L) {
    abort("Cases fixture must contain at least one case.")
  }

  target_columns <- unlist(contracts$target_columns)
  oracle_buckets <- unlist(contracts$oracle_buckets)
  case_ids <- character()

  for (i in seq_along(cases$cases)) {
    case <- cases$cases[[i]]
    field <- sprintf("cases fixture.cases[%d]", i)
    require_object(case, field)
    require_fields(
      case,
      c("case_id", "title", "evidence_status", "blocking", "context", "targets", "candidates", "oracle"),
      field
    )
    case_id <- require_scalar_character(case$case_id, paste0(field, ".case_id"))
    case_ids <- c(case_ids, case_id)
    if (!identical(case$evidence_status, "synthetic_regression_exemplar")) {
      abort("%s.evidence_status must be synthetic_regression_exemplar.", field)
    }
    require_scalar_logical(case$blocking, paste0(field, ".blocking"))
    require_object(case$context, paste0(field, ".context"))
    require_fields(
      case$context,
      c(
        "dataset_id", "table_id", "column_name", "column_role",
        "column_label", "column_description", "unit", "value_examples", "context_text"
      ),
      paste0(field, ".context")
    )

    require_array(case$targets, paste0(field, ".targets"))
    if (length(case$targets) == 0L) {
      abort("%s.targets must contain at least one target.", field)
    }
    target_roles <- character()
    for (j in seq_along(case$targets)) {
      target <- case$targets[[j]]
      target_field <- sprintf("%s.targets[%d]", field, j)
      require_object(target, target_field)
      if (!identical(names(target), target_columns)) {
        abort(
          "%s must contain exactly the 19 target columns in schema order. Expected: %s.",
          target_field,
          paste(target_columns, collapse = ", ")
        )
      }
      require_scalar_character(target$dictionary_role, paste0(target_field, ".dictionary_role"))
      target_roles <- c(target_roles, target$dictionary_role)
    }
    if (anyDuplicated(target_roles) > 0L) {
      abort("%s.targets must have unique dictionary_role values.", field)
    }

    require_array(case$candidates, paste0(field, ".candidates"))
    for (j in seq_along(case$candidates)) {
      candidate <- case$candidates[[j]]
      candidate_field <- sprintf("%s.candidates[%d]", field, j)
      require_object(candidate, candidate_field)
      require_fields(
        candidate,
        c(
          "target_role", "label", "iri", "source", "ontology", "definition",
          "score", "term_type", "definition_status"
        ),
        candidate_field
      )
      if (!candidate$target_role %in% target_roles) {
        abort("%s.target_role does not identify a target in the same case.", candidate_field)
      }
      for (nm in c(
        "target_role", "label", "iri", "source", "ontology", "definition",
        "term_type", "definition_status"
      )) {
        require_scalar_character(candidate[[nm]], paste0(candidate_field, ".", nm), allow_empty = nm == "definition")
      }
      if (!is.numeric(candidate$score) || length(candidate$score) != 1L || is.na(candidate$score)) {
        abort("%s.score must be one finite numeric value.", candidate_field)
      }
    }

    require_object(case$oracle, paste0(field, ".oracle"))
    require_fields(case$oracle, oracle_buckets, paste0(field, ".oracle"))
    rule_ids <- character()
    for (bucket in oracle_buckets) {
      rules <- case$oracle[[bucket]]
      require_array(rules, sprintf("%s.oracle.%s", field, bucket))
      for (j in seq_along(rules)) {
        validate_oracle_rule(rules[[j]], case_id, bucket, j, contracts)
        rule_ids <- c(rule_ids, rules[[j]]$rule_id)
      }
    }
    if (length(rule_ids) == 0L) {
      abort("%s.oracle must contain at least one rule.", field)
    }
    if (anyDuplicated(rule_ids) > 0L) {
      abort("%s.oracle rule_id values must be unique within a case.", field)
    }
  }

  if (anyDuplicated(case_ids) > 0L) {
    abort("Cases fixture case_id values must be unique.")
  }
  missing_cases <- setdiff(unlist(contracts$required_case_ids), case_ids)
  if (length(missing_cases) > 0L) {
    abort("Cases fixture is missing required Theme A case(s): %s.", paste(missing_cases, collapse = ", "))
  }
  if (!is.null(ontology_manifest)) {
    validate_ontology_manifest(ontology_manifest, cases, contracts)
  }

  invisible(cases)
}

validate_assessment_rows <- function(rows, field, contracts) {
  require_array(rows, field)
  expected <- unlist(contracts$assessment_columns)
  for (i in seq_along(rows)) {
    row <- rows[[i]]
    row_field <- sprintf("%s[%d]", field, i)
    require_object(row, row_field)
    if (!identical(names(row), expected)) {
      abort(
        "%s must contain exactly the 30 assessment columns in schema order.",
        row_field
      )
    }
  }
  invisible(rows)
}

validate_event <- function(event, field, contracts) {
  require_object(event, field)
  require_fields(event, "type", field)
  if (!event$type %in% unlist(contracts$oracle_event_types)) {
    abort(
      "%s.type must be one of: %s.",
      field,
      paste(unlist(contracts$oracle_event_types), collapse = ", ")
    )
  }
  if (event$type %in% c("assessment", "selection", "prefill", "gap")) {
    require_fields(event, "role", field)
  }
  if (identical(event$type, "routing")) {
    require_fields(event, c("scope", "repository"), field)
  }
  invisible(event)
}

validate_replay <- function(replay, cases, contracts) {
  require_object(replay, "replay fixture")
  require_fields(
    replay,
    c("schema_version", "fixture_version", "evidence_status", "provenance", "cases"),
    "replay fixture"
  )
  if (!identical(replay$schema_version, contracts$replay_schema_version)) {
    abort("Replay fixture schema_version must be '%s'.", contracts$replay_schema_version)
  }
  if (!identical(replay$evidence_status, "synthetic_regression_exemplar")) {
    abort("Replay fixture evidence_status must be synthetic_regression_exemplar.")
  }
  require_object(replay$provenance, "replay fixture.provenance")
  require_fields(
    replay$provenance,
    c(
      "source", "cases_fixture", "schema_fixture", "provider",
      "configured_model", "resolved_model", "ontology_provenance"
    ),
    "replay fixture.provenance"
  )
  validate_ontology_provenance(
    replay$provenance$ontology_provenance,
    "replay fixture.provenance.ontology_provenance"
  )
  if (!identical(
    replay$provenance$ontology_provenance,
    cases$ontology_provenance
  )) {
    abort(
      "Replay ontology provenance does not match the pinned case fixture."
    )
  }
  require_array(replay$cases, "replay fixture.cases")

  expected_ids <- vapply(cases$cases, `[[`, character(1), "case_id")
  cases_by_id <- stats::setNames(cases$cases, expected_ids)
  actual_ids <- character()
  for (i in seq_along(replay$cases)) {
    replay_case <- replay$cases[[i]]
    field <- sprintf("replay fixture.cases[%d]", i)
    require_object(replay_case, field)
    require_fields(
      replay_case,
      c(
        "case_id", "events", "assessment_rows", "suggestion_rows",
        "final_dictionary_rows", "gap_rows", "term_request_rows"
      ),
      field
    )
    actual_ids <- c(actual_ids, replay_case$case_id)
    if (!replay_case$case_id %in% expected_ids) {
      abort("%s.case_id is not declared by the cases fixture.", field)
    }
    require_array(replay_case$events, paste0(field, ".events"))
    for (j in seq_along(replay_case$events)) {
      validate_event(replay_case$events[[j]], sprintf("%s.events[%d]", field, j), contracts)
    }
    validate_assessment_rows(replay_case$assessment_rows, paste0(field, ".assessment_rows"), contracts)
    require_array(replay_case$suggestion_rows, paste0(field, ".suggestion_rows"))
    require_array(replay_case$final_dictionary_rows, paste0(field, ".final_dictionary_rows"))
    require_array(replay_case$gap_rows, paste0(field, ".gap_rows"))
    require_array(replay_case$term_request_rows, paste0(field, ".term_request_rows"))
    validate_event_cross_consistency(
      replay_case,
      cases_by_id[[replay_case$case_id]],
      contracts,
      field
    )
  }

  if (anyDuplicated(actual_ids) > 0L) {
    abort("Replay fixture case_id values must be unique.")
  }
  if (!setequal(expected_ids, actual_ids)) {
    abort(
      "Replay fixture case IDs must exactly match the cases fixture. Missing: %s. Extra: %s.",
      paste(setdiff(expected_ids, actual_ids), collapse = ", "),
      paste(setdiff(actual_ids, expected_ids), collapse = ", ")
    )
  }

  invisible(replay)
}

validate_historical <- function(historical, contracts) {
  require_object(historical, "historical observations")
  require_fields(
    historical,
    c(
      "schema_version", "evidence_status", "raw_capture_available",
      "source_references", "observations", "limitations"
    ),
    "historical observations"
  )
  if (!identical(historical$schema_version, contracts$historical_schema_version)) {
    abort("Historical observations schema_version must be '%s'.", contracts$historical_schema_version)
  }
  if (!identical(historical$evidence_status, "prose_only")) {
    abort("Historical observations must be labelled evidence_status=prose_only.")
  }
  if (!identical(historical$raw_capture_available, FALSE)) {
    abort("Prose-only historical observations cannot claim a raw capture.")
  }
  require_array(historical$source_references, "historical observations.source_references")
  require_array(historical$observations, "historical observations.observations")
  require_array(historical$limitations, "historical observations.limitations")
  invisible(historical)
}

scalar_key <- function(x) {
  if (is.null(x)) {
    return("<NA>")
  }
  if (length(x) != 1L || is.list(x)) {
    return(as.character(jsonlite::toJSON(x, auto_unbox = TRUE, null = "null", na = "null")))
  }
  if (is.logical(x)) {
    return(if (isTRUE(x)) "true" else "false")
  }
  if (is.na(x)) {
    return("<NA>")
  }
  as.character(x)
}

semantic_key <- function(row, key_columns, field) {
  require_object(row, field)
  require_fields(row, key_columns, field)
  paste(
    vapply(key_columns, function(column) scalar_key(row[[column]]), character(1)),
    collapse = "\u001f"
  )
}

semantic_key_label <- function(row, key_columns) {
  paste(
    sprintf(
      "%s=%s",
      key_columns,
      vapply(key_columns, function(column) scalar_key(row[[column]]), character(1))
    ),
    collapse = ", "
  )
}

same_optional_value <- function(x, y) {
  identical(scalar_key(x), scalar_key(y))
}

event_matches_rule <- function(event, rule) {
  ignored <- c("rule_id", "note", "advisory")
  fields <- setdiff(names(rule), ignored)
  all(vapply(fields, function(field) {
    field %in% names(event) && identical(scalar_key(event[[field]]), scalar_key(rule[[field]]))
  }, logical(1)))
}

evaluate_oracles <- function(cases, replay) {
  replay_by_id <- stats::setNames(replay$cases, vapply(replay$cases, `[[`, character(1), "case_id"))
  failures <- list()
  case_results <- vector("list", length(cases$cases))
  rule_results <- list()

  metrics <- list(
    cases_total = length(cases$cases),
    cases_passed = 0L,
    critical_cases_total = sum(vapply(cases$cases, function(x) isTRUE(x$blocking), logical(1))),
    critical_cases_passed = 0L,
    required_total = 0L,
    required_matched = 0L,
    advisory_required_total = 0L,
    advisory_required_matched = 0L,
    allowed_not_required_total = 0L,
    allowed_not_required_matched = 0L,
    forbidden_total = 0L,
    forbidden_violations = 0L,
    false_acceptance_count = 0L,
    false_prefill_count = 0L,
    correct_prefill_count = 0L,
    gap_expectations_total = 0L,
    gap_expectations_matched = 0L,
    routing_expectations_total = 0L,
    routing_expectations_matched = 0L
  )

  for (i in seq_along(cases$cases)) {
    case <- cases$cases[[i]]
    observed <- replay_by_id[[case$case_id]]
    events <- observed$events
    case_failures <- list()

    for (rule in case$oracle$required) {
      matched <- any(vapply(events, event_matches_rule, logical(1), rule = rule))
      advisory <- isTRUE(rule$advisory)
      rule_results[[length(rule_results) + 1L]] <- list(
        case_id = case$case_id,
        blocking = case$blocking,
        bucket = "required",
        rule_id = rule$rule_id,
        event_type = rule$type,
        advisory = advisory,
        matched = matched,
        violated = FALSE,
        passed = advisory || matched
      )
      if (advisory) {
        metrics$advisory_required_total <- metrics$advisory_required_total + 1L
        metrics$advisory_required_matched <- metrics$advisory_required_matched + as.integer(matched)
      } else {
        metrics$required_total <- metrics$required_total + 1L
        metrics$required_matched <- metrics$required_matched + as.integer(matched)
        if (!matched) {
          case_failures[[length(case_failures) + 1L]] <- list(
            case_id = case$case_id,
            blocking = case$blocking,
            bucket = "required",
            rule_id = rule$rule_id,
            message = "Required semantic event was not observed."
          )
        }
      }
      if (identical(rule$type, "prefill") && matched) {
        metrics$correct_prefill_count <- metrics$correct_prefill_count + 1L
      }
      if (identical(rule$type, "gap")) {
        metrics$gap_expectations_total <- metrics$gap_expectations_total + 1L
        metrics$gap_expectations_matched <- metrics$gap_expectations_matched + as.integer(matched)
      }
      if (identical(rule$type, "routing")) {
        metrics$routing_expectations_total <- metrics$routing_expectations_total + 1L
        metrics$routing_expectations_matched <- metrics$routing_expectations_matched + as.integer(matched)
      }
    }

    for (rule in case$oracle$allowed_not_required) {
      matched <- any(vapply(events, event_matches_rule, logical(1), rule = rule))
      rule_results[[length(rule_results) + 1L]] <- list(
        case_id = case$case_id,
        blocking = case$blocking,
        bucket = "allowed_not_required",
        rule_id = rule$rule_id,
        event_type = rule$type,
        advisory = FALSE,
        matched = matched,
        violated = FALSE,
        passed = TRUE
      )
      metrics$allowed_not_required_total <- metrics$allowed_not_required_total + 1L
      metrics$allowed_not_required_matched <-
        metrics$allowed_not_required_matched + as.integer(matched)
      if (identical(rule$type, "gap")) {
        metrics$gap_expectations_total <- metrics$gap_expectations_total + 1L
        metrics$gap_expectations_matched <- metrics$gap_expectations_matched + as.integer(matched)
      }
      if (identical(rule$type, "routing")) {
        metrics$routing_expectations_total <- metrics$routing_expectations_total + 1L
        metrics$routing_expectations_matched <- metrics$routing_expectations_matched + as.integer(matched)
      }
    }

    for (rule in case$oracle$forbidden) {
      matches <- vapply(events, event_matches_rule, logical(1), rule = rule)
      violated <- any(matches)
      metrics$forbidden_total <- metrics$forbidden_total + 1L
      metrics$forbidden_violations <- metrics$forbidden_violations + as.integer(violated)
      rule_results[[length(rule_results) + 1L]] <- list(
        case_id = case$case_id,
        blocking = case$blocking,
        bucket = "forbidden",
        rule_id = rule$rule_id,
        event_type = rule$type,
        advisory = FALSE,
        matched = violated,
        violated = violated,
        passed = !violated
      )
      if (violated) {
        case_failures[[length(case_failures) + 1L]] <- list(
          case_id = case$case_id,
          blocking = case$blocking,
          bucket = "forbidden",
          rule_id = rule$rule_id,
          message = "Forbidden semantic event was observed."
        )
        matched_events <- events[matches]
        if (identical(rule$type, "prefill")) {
          metrics$false_prefill_count <- metrics$false_prefill_count + 1L
        }
        accepted <- any(vapply(
          matched_events,
          function(event) identical(tolower(event$decision %||% ""), "accept"),
          logical(1)
        ))
        if (accepted && rule$type %in% c("selection", "assessment")) {
          metrics$false_acceptance_count <- metrics$false_acceptance_count + 1L
        }
      }
    }

    passed <- length(case_failures) == 0L
    metrics$cases_passed <- metrics$cases_passed + as.integer(passed)
    if (isTRUE(case$blocking)) {
      metrics$critical_cases_passed <- metrics$critical_cases_passed + as.integer(passed)
    }
    failures <- c(failures, case_failures)
    case_results[[i]] <- list(
      case_id = case$case_id,
      blocking = case$blocking,
      passed = passed,
      failure_count = length(case_failures)
    )
  }

  blocking_failures <- Filter(
    function(failure) isTRUE(failure$blocking),
    failures
  )
  list(
    schema_version = "theme-a-evaluation-v1",
    status = if (length(blocking_failures) == 0L) "pass" else "fail",
    metrics = metrics,
    cases = case_results,
    rule_results = rule_results,
    failures = failures
  )
}

print_evaluation <- function(evaluation, label = "replay") {
  metrics <- evaluation$metrics
  cat(sprintf("Theme A %s: %s\n", label, toupper(evaluation$status)))
  cat(sprintf(
    "Cases: %d/%d; critical: %d/%d; required: %d/%d; forbidden violations: %d\n",
    metrics$cases_passed,
    metrics$cases_total,
    metrics$critical_cases_passed,
    metrics$critical_cases_total,
    metrics$required_matched,
    metrics$required_total,
    metrics$forbidden_violations
  ))
  cat(sprintf(
    "False acceptances: %d; false prefills: %d; correct prefills: %d; gaps: %d/%d; routes: %d/%d\n",
    metrics$false_acceptance_count,
    metrics$false_prefill_count,
    metrics$correct_prefill_count,
    metrics$gap_expectations_matched,
    metrics$gap_expectations_total,
    metrics$routing_expectations_matched,
    metrics$routing_expectations_total
  ))
  if (length(evaluation$failures) > 0L) {
    for (failure in evaluation$failures) {
      cat(sprintf(
        "FAIL [%s/%s] %s: %s\n",
        failure$case_id,
        failure$bucket,
        failure$rule_id,
        failure$message
      ))
    }
  }
  invisible(evaluation)
}

load_fixture_set <- function(options) {
  schema <- read_json(options$schema, "fixture schema")
  contracts <- schema_contracts(schema)
  cases <- read_json(options$cases, "cases fixture")
  ontology_manifest <- read_json(
    options$ontology_manifest,
    "ontology manifest"
  )
  replay <- read_json(options$replay, "replay fixture")
  historical <- read_json(options$historical, "historical observations")
  validate_cases(cases, contracts, ontology_manifest)
  validate_replay(replay, cases, contracts)
  validate_historical(historical, contracts)
  list(
    schema = schema,
    contracts = contracts,
    cases = cases,
    ontology_manifest = ontology_manifest,
    replay = replay,
    historical = historical
  )
}

run_replay <- function(options) {
  fixtures <- load_fixture_set(options)
  evaluation <- evaluate_oracles(fixtures$cases, fixtures$replay)
  print_evaluation(evaluation)
  if (!is.null(options$output)) {
    write_json(evaluation, options$output)
  }
  if (!identical(evaluation$status, "pass")) {
    abort("Theme A replay failed one or more blocking fixture checks.")
  }
  invisible(evaluation)
}

non_empty <- function(x) {
  !is.null(x) && length(x) > 0L && !is.na(x[[1L]]) && nzchar(trimws(as.character(x[[1L]])))
}

scope_from_namespace <- function(namespace) {
  if (!non_empty(namespace)) {
    return("uncertain")
  }
  value <- tolower(trimws(as.character(namespace[[1L]])))
  if (value %in% c("smn", "gcdfo", "profile")) value else "uncertain"
}

rows_as_tibble <- function(rows) {
  if (inherits(rows, "data.frame")) {
    return(tibble::as_tibble(rows))
  }
  if (is.null(rows) || length(rows) == 0L) {
    return(tibble::tibble())
  }
  columns <- unique(unlist(lapply(rows, names), use.names = FALSE))
  rows <- lapply(rows, function(row) {
    for (column in columns) {
      if (!column %in% names(row) || is.null(row[[column]])) {
        row[column] <- list(NA)
      }
    }
    row[columns]
  })
  dplyr::bind_rows(rows)
}

scope_from_gap <- function(gap) {
  namespace <- if ("llm_new_term_namespace" %in% names(gap)) {
    scope_from_namespace(gap$llm_new_term_namespace)
  } else {
    "uncertain"
  }
  if (!identical(namespace, "uncertain")) {
    return(namespace)
  }

  placement <- if ("placement_recommendation" %in% names(gap)) {
    tolower(trimws(as.character(gap$placement_recommendation[[1L]] %||% "")))
  } else {
    ""
  }
  if (placement %in% c("smn", "gcdfo", "profile")) placement else "uncertain"
}

assessment_and_selection_events <- function(assessments) {
  assessments <- tibble::as_tibble(assessments)
  if (nrow(assessments) == 0L) {
    return(list())
  }

  events <- list()
  for (i in seq_len(nrow(assessments))) {
    row <- assessments[i, , drop = FALSE]
    role <- as.character(row$dictionary_role[[1L]])
    decision <- as.character(row$llm_decision[[1L]])
    events[[length(events) + 1L]] <- list(
      type = "assessment",
      role = role,
      decision = decision
    )

    if (non_empty(row$llm_selected_iri)) {
      iri <- as.character(row$llm_selected_iri[[1L]])
      events[[length(events) + 1L]] <- list(
        type = "selection",
        role = role,
        iri = iri,
        decision = decision
      )
    }
  }
  events
}

prefill_events_from_dictionary <- function(final_dictionary_rows) {
  rows <- rows_as_tibble(final_dictionary_rows)
  if (nrow(rows) == 0L) {
    return(list())
  }

  role_fields <- c(
    variable = "term_iri",
    property = "property_iri",
    entity = "entity_iri",
    unit = "unit_iri"
  )
  events <- list()
  for (i in seq_len(nrow(rows))) {
    for (role in names(role_fields)) {
      field <- role_fields[[role]]
      if (!field %in% names(rows) || !non_empty(rows[[field]][i])) {
        next
      }
      value <- as.character(rows[[field]][[i]])
      if (!grepl("^\\s*REVIEW\\s*:", value, ignore.case = TRUE)) {
        next
      }
      iri <- sub("^\\s*REVIEW\\s*:\\s*", "", value, ignore.case = TRUE)
      events[[length(events) + 1L]] <- list(
        type = "prefill",
        role = role,
        iri = iri,
        decision = "accept"
      )
    }
  }
  events
}

gap_events_from_rows <- function(gap_rows) {
  gaps <- rows_as_tibble(gap_rows)
  if (nrow(gaps) == 0L) {
    return(list())
  }

  lapply(seq_len(nrow(gaps)), function(i) {
    gap <- gaps[i, , drop = FALSE]
    decision <- if (
      "llm_decision" %in% names(gap) &&
        non_empty(gap$llm_decision)
    ) {
      as.character(gap$llm_decision[[1L]])
    } else if ("detection" %in% names(gap) && non_empty(gap$detection)) {
      as.character(gap$detection[[1L]])
    } else {
      "candidate_gap"
    }
    list(
      type = "gap",
      role = as.character(gap$dictionary_role[[1L]]),
      scope = scope_from_gap(gap),
      decision = decision
    )
  })
}

routing_events_from_rows <- function(term_request_rows) {
  requests <- rows_as_tibble(term_request_rows)
  if (nrow(requests) == 0L) {
    return(list())
  }

  requests <- requests[
    requests$request_scope %in% c("smn", "gcdfo", "profile"),
    ,
    drop = FALSE
  ]
  lapply(seq_len(nrow(requests)), function(i) {
    list(
      type = "routing",
      scope = as.character(requests$request_scope[[i]]),
      repository = as.character(requests$ontology_repo[[i]])
    )
  })
}

events_from_package_outputs <- function(assessments,
                                        final_dictionary_rows,
                                        gap_rows,
                                        term_request_rows) {
  c(
    assessment_and_selection_events(rows_as_tibble(assessments)),
    prefill_events_from_dictionary(final_dictionary_rows),
    gap_events_from_rows(gap_rows),
    routing_events_from_rows(term_request_rows)
  )
}

event_key <- function(event) {
  event <- event[sort(names(event), method = "radix")]
  as.character(jsonlite::toJSON(
    event,
    auto_unbox = TRUE,
    null = "null",
    na = "null"
  ))
}

validate_event_cross_consistency <- function(replay_case,
                                             case,
                                             contracts,
                                             field) {
  expected <- events_from_package_outputs(
    assessments = replay_case$assessment_rows,
    final_dictionary_rows = replay_case$final_dictionary_rows,
    gap_rows = replay_case$gap_rows,
    term_request_rows = replay_case$term_request_rows
  )
  expected_keys <- sort(vapply(expected, event_key, character(1)), method = "radix")
  actual_keys <- sort(vapply(replay_case$events, event_key, character(1)), method = "radix")
  if (!identical(actual_keys, expected_keys)) {
    missing <- setdiff(expected_keys, actual_keys)
    extra <- setdiff(actual_keys, expected_keys)
    abort(
      paste0(
        "%s.events are inconsistent with assessment, final dictionary, ",
        "gap, or term-request rows. Missing derived events: %s. Extra events: %s."
      ),
      field,
      paste(missing, collapse = " | "),
      paste(extra, collapse = " | ")
    )
  }

  key_columns <- unlist(contracts$semantic_target_key)
  target_keys <- vapply(
    seq_along(case$targets),
    function(i) {
      semantic_key(
        case$targets[[i]],
        key_columns,
        sprintf("%s.case.targets[%d]", field, i)
      )
    },
    character(1)
  )
  target_by_key <- stats::setNames(case$targets, target_keys)
  if (length(replay_case$final_dictionary_rows) != 1L) {
    abort(
      "%s.final_dictionary_rows must contain exactly one row for case '%s'.",
      field,
      case$case_id
    )
  }
  final_row <- replay_case$final_dictionary_rows[[1L]]
  require_object(final_row, paste0(field, ".final_dictionary_rows[1]"))
  final_identity <- c("dataset_id", "table_id", "column_name")
  require_fields(
    final_row,
    final_identity,
    paste0(field, ".final_dictionary_rows[1]")
  )
  for (name in final_identity) {
    if (!same_optional_value(final_row[[name]], case$context[[name]])) {
      abort(
        "%s.final_dictionary_rows[1].%s does not match case '%s'.",
        field,
        name,
        case$case_id
      )
    }
  }

  artifact_names <- c(
    "assessment_rows",
    "suggestion_rows",
    "gap_rows",
    "term_request_rows"
  )
  artifact_keys <- stats::setNames(vector("list", length(artifact_names)), artifact_names)
  for (artifact_name in artifact_names) {
    rows <- replay_case[[artifact_name]]
    artifact_keys[[artifact_name]] <- vapply(
      seq_along(rows),
      function(i) {
        row_field <- sprintf("%s.%s[%d]", field, artifact_name, i)
        key <- semantic_key(rows[[i]], key_columns, row_field)
        if (!key %in% target_keys) {
          abort(
            "%s does not identify a target in case '%s': %s.",
            row_field,
            case$case_id,
            semantic_key_label(rows[[i]], key_columns)
          )
        }
        key
      },
      character(1)
    )
  }

  assessment_keys <- artifact_keys$assessment_rows
  if (anyDuplicated(assessment_keys) > 0L) {
    abort("%s assessment rows must be unique by canonical target key.", field)
  }
  suggestion_keys <- artifact_keys$suggestion_rows
  gap_keys <- artifact_keys$gap_rows
  request_keys <- artifact_keys$term_request_rows

  if (length(replay_case$suggestion_rows) != length(case$candidates)) {
    abort(
      paste0(
        "%s.suggestion_rows must contain exactly the pinned candidate ",
        "multiplicity for case '%s'."
      ),
      field,
      case$case_id
    )
  }
  candidate_fields <- c(
    "label",
    "iri",
    "source",
    "ontology",
    "definition",
    "score",
    "term_type",
    "definition_status"
  )
  for (i in seq_along(case$candidates)) {
    expected_candidate <- case$candidates[[i]]
    suggestion <- replay_case$suggestion_rows[[i]]
    suggestion_field <- sprintf("%s.suggestion_rows[%d]", field, i)
    require_fields(
      suggestion,
      c(
        "dictionary_role",
        candidate_fields,
        "llm_selected"
      ),
      suggestion_field
    )
    if (!identical(
      suggestion$dictionary_role,
      expected_candidate$target_role
    )) {
      abort(
        "%s.dictionary_role does not match the ordered pinned candidate role.",
        suggestion_field
      )
    }
    for (name in candidate_fields) {
      if (!same_optional_value(
        suggestion[[name]],
        expected_candidate[[name]]
      )) {
        abort(
          "%s.%s does not match the ordered pinned candidate record.",
          suggestion_field,
          name
        )
      }
    }
    require_scalar_logical(
      suggestion$llm_selected,
      paste0(suggestion_field, ".llm_selected")
    )
  }

  for (i in seq_along(replay_case$assessment_rows)) {
    assessment <- replay_case$assessment_rows[[i]]
    assessment_field <- sprintf("%s.assessment_rows[%d]", field, i)
    key <- assessment_keys[[i]]
    candidate_indexes <- which(suggestion_keys == key)
    selected_flags <- if (length(candidate_indexes) > 0L) {
      vapply(
        replay_case$suggestion_rows[candidate_indexes],
        function(row) isTRUE(row$llm_selected),
        logical(1)
      )
    } else {
      logical()
    }

    if (identical(assessment$llm_decision, "accept")) {
      selected_index <- assessment$llm_selected_candidate_index
      if (is.null(selected_index) ||
          length(selected_index) != 1L ||
          !is.numeric(selected_index) ||
          is.na(selected_index) ||
          selected_index != as.integer(selected_index) ||
          selected_index < 1L ||
          selected_index > length(candidate_indexes)) {
        abort(
          "%s accepted selection does not identify a valid positional candidate.",
          assessment_field
        )
      }
      selected_index <- as.integer(selected_index)
      selected <- replay_case$suggestion_rows[[
        candidate_indexes[[selected_index]]
      ]]
      if (!same_optional_value(
        assessment$llm_selected_iri,
        selected$iri
      ) || !same_optional_value(
        assessment$llm_selected_label,
        selected$label
      )) {
        abort(
          "%s selected index, IRI, and label do not identify the same candidate.",
          assessment_field
        )
      }
      if (sum(selected_flags) != 1L || !isTRUE(selected_flags[[selected_index]])) {
        abort(
          "%s accept decision must have exactly one matching llm_selected suggestion.",
          assessment_field
        )
      }
    } else {
      selected_values <- c(
        assessment$llm_selected_candidate_index,
        assessment$llm_selected_iri,
        assessment$llm_selected_label
      )
      if (any(vapply(selected_values, non_empty, logical(1))) ||
          any(selected_flags)) {
        abort(
          "%s non-accept decision cannot retain a selected candidate.",
          assessment_field
        )
      }
    }
  }

  proposal_fields <- c(
    "llm_new_term_label",
    "llm_new_term_definition",
    "llm_new_term_namespace"
  )
  request_assessment_indexes <- which(vapply(
    replay_case$assessment_rows,
    function(row) identical(row$llm_decision, "request_new_term"),
    logical(1)
  ))
  llm_gap_indexes <- which(vapply(
    replay_case$gap_rows,
    function(row) identical(row$llm_decision, "request_new_term"),
    logical(1)
  ))
  for (i in request_assessment_indexes) {
    key <- assessment_keys[[i]]
    matching_gaps <- llm_gap_indexes[gap_keys[llm_gap_indexes] == key]
    if (length(matching_gaps) != 1L) {
      abort(
        "%s request_new_term assessment must join to exactly one structured LLM gap.",
        sprintf("%s.assessment_rows[%d]", field, i)
      )
    }
    assessment <- replay_case$assessment_rows[[i]]
    gap <- replay_case$gap_rows[[matching_gaps[[1L]]]]
    for (name in proposal_fields) {
      if (!same_optional_value(assessment[[name]], gap[[name]])) {
        abort(
          "%s proposal field '%s' disagrees between assessment and gap.",
          field,
          name
        )
      }
    }
  }
  for (i in llm_gap_indexes) {
    key <- gap_keys[[i]]
    matching_assessments <- request_assessment_indexes[
      assessment_keys[request_assessment_indexes] == key
    ]
    if (length(matching_assessments) != 1L) {
      abort(
        "%s.gap_rows[%d] must join to exactly one request_new_term assessment.",
        field,
        i
      )
    }
  }
  for (i in seq_along(replay_case$gap_rows)) {
    key <- gap_keys[[i]]
    matching_requests <- which(request_keys == key)
    if (length(matching_requests) != 1L) {
      abort(
        "%s.gap_rows[%d] must join to exactly one rendered term request.",
        field,
        i
      )
    }
    gap <- replay_case$gap_rows[[i]]
    request <- replay_case$term_request_rows[[matching_requests[[1L]]]]
    for (name in proposal_fields) {
      if (!same_optional_value(gap[[name]], request[[name]])) {
        abort(
          "%s proposal field '%s' disagrees between gap and term request.",
          field,
          name
        )
      }
    }
  }
  if (length(request_keys) != length(gap_keys)) {
    abort("%s term requests and structured gaps must be one-to-one.", field)
  }

  assessments <- rows_as_tibble(replay_case$assessment_rows)
  prefills <- Filter(
    function(event) identical(event$type, "prefill"),
    replay_case$events
  )
  for (prefill in prefills) {
    supported <- nrow(assessments) > 0L &&
      any(
        assessments$dictionary_role == prefill$role &
          assessments$llm_decision == "accept" &
          assessments$llm_selected_iri == prefill$iri,
        na.rm = TRUE
      )
    if (!supported) {
      abort(
        "%s contains a prefill without a matching accepted assessment: %s.",
        field,
        event_key(prefill)
      )
    }
  }
  invisible(replay_case)
}

evaluation_from_file <- function(path,
                                 cases,
                                 contracts) {
  value <- read_json(path, "comparison input")
  if (!identical(value$schema_version, contracts$replay_schema_version)) {
    abort(
      paste0(
        "Comparison input '%s' must be a validated Theme A replay fixture; ",
        "bare evaluation summaries do not contain fixture provenance or per-artifact evidence."
      ),
      path
    )
  }
  validate_replay(value, cases, contracts)
  list(
    input_type = "replay",
    evaluation = evaluate_oracles(cases, value),
    cases = value$cases
  )
}

oracle_rule_result_key <- function(result) {
  paste(result$case_id, result$bucket, result$rule_id, sep = "\u001f")
}

prefill_identity_set <- function(observed_cases, include_case_ids = NULL) {
  if (!is.null(include_case_ids)) {
    observed_cases <- Filter(
      function(observed) observed$case_id %in% include_case_ids,
      observed_cases
    )
  }
  identities <- unlist(lapply(observed_cases, function(observed) {
    prefills <- Filter(
      function(event) identical(event$type, "prefill"),
      observed$events
    )
    vapply(prefills, function(event) {
      paste(observed$case_id, event_key(event), sep = "\u001f")
    }, character(1))
  }), use.names = FALSE)
  sort(unique(identities), method = "radix")
}

required_prefill_identity_set <- function(cases, include_case_ids = NULL) {
  selected_cases <- cases$cases
  if (!is.null(include_case_ids)) {
    selected_cases <- Filter(
      function(case) case$case_id %in% include_case_ids,
      selected_cases
    )
  }
  identities <- unlist(lapply(selected_cases, function(case) {
    rules <- Filter(
      function(rule) {
        identical(rule$type, "prefill") && !isTRUE(rule$advisory)
      },
      case$oracle$required
    )
    vapply(rules, function(rule) {
      event <- rule[setdiff(names(rule), c("rule_id", "note", "advisory"))]
      paste(case$case_id, event_key(event), sep = "\u001f")
    }, character(1))
  }), use.names = FALSE)
  sort(unique(identities), method = "radix")
}

run_compare <- function(options) {
  schema <- read_json(options$schema, "fixture schema")
  contracts <- schema_contracts(schema)
  cases <- read_json(options$cases, "cases fixture")
  ontology_manifest <- read_json(
    options$ontology_manifest,
    "ontology manifest"
  )
  validate_cases(cases, contracts, ontology_manifest)

  if (is.null(options$baseline) || is.null(options$candidate)) {
    abort("Compare mode requires --baseline=FILE and --candidate=FILE.")
  }
  baseline <- evaluation_from_file(
    options$baseline,
    cases,
    contracts
  )
  candidate <- evaluation_from_file(
    options$candidate,
    cases,
    contracts
  )

  baseline_rules <- baseline$evaluation$rule_results
  candidate_rules <- candidate$evaluation$rule_results
  baseline_keys <- vapply(
    baseline_rules,
    oracle_rule_result_key,
    character(1)
  )
  candidate_keys <- vapply(
    candidate_rules,
    oracle_rule_result_key,
    character(1)
  )
  if (anyDuplicated(baseline_keys) > 0L ||
      anyDuplicated(candidate_keys) > 0L ||
      !setequal(baseline_keys, candidate_keys)) {
    abort("Comparison inputs do not contain the same unique per-rule oracle results.")
  }
  candidate_by_key <- stats::setNames(candidate_rules, candidate_keys)
  blocking_case_ids <- vapply(
    Filter(function(case) isTRUE(case$blocking), cases$cases),
    `[[`,
    character(1),
    "case_id"
  )
  rule_rows <- lapply(seq_along(baseline_rules), function(i) {
    baseline_rule <- baseline_rules[[i]]
    candidate_rule <- candidate_by_key[[baseline_keys[[i]]]]
    excluded <- identical(
      baseline_rule$bucket,
      "allowed_not_required"
    ) ||
      isTRUE(baseline_rule$advisory) ||
      !baseline_rule$case_id %in% blocking_case_ids
    regressed <- !excluded &&
      isTRUE(baseline_rule$passed) &&
      !isTRUE(candidate_rule$passed)
    list(
      case_id = baseline_rule$case_id,
      bucket = baseline_rule$bucket,
      rule_id = baseline_rule$rule_id,
      excluded = excluded,
      baseline_passed = baseline_rule$passed,
      candidate_passed = candidate_rule$passed,
      baseline_matched = baseline_rule$matched,
      candidate_matched = candidate_rule$matched,
      regressed = regressed
    )
  })

  baseline_prefills <- prefill_identity_set(
    baseline$cases,
    blocking_case_ids
  )
  candidate_prefills <- prefill_identity_set(
    candidate$cases,
    blocking_case_ids
  )
  required_prefills <- required_prefill_identity_set(
    cases,
    blocking_case_ids
  )
  lost_prefills <- setdiff(baseline_prefills, candidate_prefills)
  added_prefills <- setdiff(candidate_prefills, baseline_prefills)
  unexpected_added_prefills <- setdiff(added_prefills, required_prefills)
  rule_regressions <- Filter(function(row) isTRUE(row$regressed), rule_rows)
  regressed <- length(rule_regressions) > 0L ||
    length(lost_prefills) > 0L ||
    length(unexpected_added_prefills) > 0L
  comparison <- list(
    schema_version = "theme-a-comparison-v1",
    status = if (regressed) "regression" else "no_regression",
    rules_compared = rule_rows,
    prefill_identities = list(
      baseline = baseline_prefills,
      candidate = candidate_prefills,
      lost = lost_prefills,
      added = added_prefills,
      unexpected_added = unexpected_added_prefills
    ),
    excluded_fields = c(
      "allowed_not_required rules",
      "advisory rules",
      "nonblocking cases",
      "llm_rationale",
      "llm_confidence",
      "latency"
    )
  )

  cat(sprintf("Theme A compare: %s\n", toupper(comparison$status)))
  for (row in rule_regressions) {
    cat(sprintf(
      "REGRESSION [%s/%s] %s\n",
      row$case_id,
      row$bucket,
      row$rule_id
    ))
  }
  if (length(lost_prefills) > 0L) {
    cat(sprintf("Lost prefill identities: %s\n", paste(lost_prefills, collapse = " | ")))
  }
  if (length(unexpected_added_prefills) > 0L) {
    cat(sprintf(
      "Unexpected added prefill identities: %s\n",
      paste(unexpected_added_prefills, collapse = " | ")
    ))
  }
  if (!is.null(options$output)) {
    write_json(comparison, options$output)
  }
  if (identical(comparison$status, "regression")) {
    abort("Theme A candidate regressed one or more oracle metrics.")
  }
  invisible(comparison)
}
run_benchmark_mode <- function(options) {
  if (isTRUE(options$help)) {
    cat(usage(), "\n")
    return(invisible(TRUE))
  }

  switch(
    options$mode,
    replay = run_replay(options),
    compare = run_compare(options)
  )
}

main <- function() {
  options <- parse_args(commandArgs(trailingOnly = TRUE))
  run_benchmark_mode(options)
}

if (sys.nframe() == 0L) {
  tryCatch(
    main(),
    error = function(e) {
      message("Theme A benchmark error: ", conditionMessage(e))
      quit(save = "no", status = 1L, runLast = FALSE)
    }
  )
}
