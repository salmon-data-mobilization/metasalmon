#!/usr/bin/env Rscript

# Theme A semantic-review evidence harness.
#
# The default replay mode is deliberately offline and dependency-light. Live
# mode calls metasalmon's existing review adapter against frozen candidate
# snapshots, but keeps every capture under ignored artifacts/ until a human has
# reviewed and sanitized it.

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
  historical = file.path(repo_root, "notes", "evidence", "theme-a", "historical-observations-v1.json"),
  staging = file.path(repo_root, "artifacts", "theme-a"),
  promoted = file.path(repo_root, "notes", "evidence", "theme-a", "captures")
)

usage <- function() {
  paste(
    "Usage:",
    "  Rscript scripts/theme-a-benchmark.R [replay] [options]",
    "  Rscript scripts/theme-a-benchmark.R live --provider=PROVIDER --model=MODEL [options]",
    "  Rscript scripts/theme-a-benchmark.R compare --baseline=FILE --candidate=FILE",
    paste0(
      "  Rscript scripts/theme-a-benchmark.R compare ",
      "--cohort=RUN1,RUN2,RUN3 --expected-provider=NAME --expected-model=ID"
    ),
    "  Rscript scripts/theme-a-benchmark.R promote --capture=FILE",
    "  Rscript scripts/theme-a-benchmark.R promote --cohort-manifest=FILE",
    "",
    "Common options:",
    "  --schema=FILE       Versioned fixture schema manifest.",
    "  --cases=FILE        Versioned case fixture.",
    "  --replay=FILE       Offline replay observations.",
    "  --ontology-manifest=FILE  Pinned ontology IRI/type contract.",
    "  --historical=FILE   Prose-only historical observations.",
    "  --output=FILE       Optional JSON evaluation output for replay/compare.",
    "  --expected-provider=NAME  Approved provider required by the cohort gate.",
    "  --expected-model=ID       Approved exact model required by the cohort gate.",
    "",
    "Live options:",
    "  --provider=NAME     Exact provider: openai, openrouter, openai_compatible, or chapi.",
    "  --model=ID          Exact model ID. openrouter/free is rejected because it is not stable.",
    "  --base-url=URL      Optional exact API base URL.",
    "  --api-key-env=NAME  Environment variable containing the API key.",
    "  --run-id=ID         Safe staging directory name; generated when omitted.",
    "  --timeout-seconds=N Per-request timeout; default 120.",
    "  --allow-live-api=true  Explicitly permit billable provider requests.",
    "",
    "Promotion requires a staging capture whose evidence_status is",
    "reviewed_sanitized and whose review object records human review and",
    "sanitization plus raw-capture safe-to-publish attestation. Live mode",
    "creates an immutable capture.raw.json plus",
    "checksum sidecar and an editable capture.json review copy.",
    sep = "\n"
  )
}

parse_args <- function(args) {
  mode <- "replay"
  if (length(args) > 0L && !startsWith(args[[1L]], "--")) {
    mode <- tolower(args[[1L]])
    args <- args[-1L]
  }

  allowed_modes <- c("replay", "live", "compare", "promote")
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
    provider = NULL,
    model = NULL,
    base_url = NULL,
    api_key_env = NULL,
    run_id = NULL,
    timeout_seconds = 120,
    baseline = NULL,
    candidate = NULL,
    cohort = NULL,
    capture = NULL,
    cohort_manifest = NULL,
    expected_provider = NULL,
    expected_model = NULL,
    allow_live_api = FALSE
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

  options$timeout_seconds <- suppressWarnings(as.numeric(options$timeout_seconds))
  if (is.na(options$timeout_seconds) || options$timeout_seconds <= 0) {
    abort("--timeout-seconds must be a positive number.")
  }
  if (!is.logical(options$allow_live_api)) {
    allow_live_api <- tolower(trimws(options$allow_live_api))
    if (!allow_live_api %in% c("true", "false")) {
      abort("--allow-live-api must be either true or false.")
    }
    options$allow_live_api <- identical(allow_live_api, "true")
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
      "capture_schema_version",
      "ontology_manifest_schema_version",
      "target_columns",
      "semantic_target_key",
      "assessment_prefix_columns",
      "assessment_columns",
      "oracle_buckets",
      "oracle_event_types",
      "capture_interaction_stages",
      "capture_lineage_outcomes",
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

data_frame_rows <- function(df, columns = names(df)) {
  df <- as.data.frame(df, stringsAsFactors = FALSE)
  if (nrow(df) == 0L) {
    return(list())
  }
  lapply(seq_len(nrow(df)), function(i) {
    stats::setNames(
      lapply(columns, function(column) {
        value <- df[[column]][i]
        if (is.factor(value)) as.character(value) else value
      }),
      columns
    )
  })
}

normalise_assessment_df <- function(df, contracts) {
  df <- tibble::as_tibble(df)
  expected <- unlist(contracts$assessment_columns)
  logical_cols <- "llm_exploration_used"
  integer_cols <- c("llm_selected_candidate_index", "llm_exploration_candidate_gain")
  numeric_cols <- "llm_confidence"

  for (column in setdiff(expected, names(df))) {
    if (column %in% logical_cols) {
      df[[column]] <- NA
    } else if (column %in% integer_cols) {
      df[[column]] <- NA_integer_
    } else if (column %in% numeric_cols) {
      df[[column]] <- NA_real_
    } else {
      df[[column]] <- NA_character_
    }
  }
  df[, expected, drop = FALSE]
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
  event <- event[sort(names(event))]
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
  expected_keys <- sort(vapply(expected, event_key, character(1)))
  actual_keys <- sort(vapply(replay_case$events, event_key, character(1)))
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

target_as_row <- function(target) {
  values <- lapply(target, function(value) {
    if (is.null(value)) NA_character_ else value
  })
  as.data.frame(values, stringsAsFactors = FALSE, check.names = FALSE)
}

build_live_suggestions <- function(cases) {
  rows <- list()
  for (case in cases$cases) {
    targets_by_role <- stats::setNames(case$targets, vapply(case$targets, `[[`, character(1), "dictionary_role"))
    for (candidate in case$candidates) {
      target <- targets_by_role[[candidate$target_role]]
      target_row <- target_as_row(target)
      target_row$column_role <- case$context$column_role
      target_row$label <- candidate$label
      target_row$iri <- candidate$iri
      target_row$source <- candidate$source
      target_row$ontology <- candidate$ontology
      target_row$role <- candidate$target_role
      target_row$match_type <- "fixture_snapshot"
      target_row$definition <- candidate$definition
      target_row$score <- as.numeric(candidate$score)
      target_row$term_type <- candidate$term_type
      target_row$retrieval_query <- target$search_query
      target_row$retrieval_pass <- 1L
      rows[[length(rows) + 1L]] <- target_row
    }
  }
  dplyr::bind_rows(rows)
}

build_live_targets <- function(cases) {
  rows <- unlist(lapply(cases$cases, `[[`, "targets"), recursive = FALSE)
  dplyr::bind_rows(lapply(rows, target_as_row))
}

build_live_dictionary <- function(cases) {
  dplyr::bind_rows(lapply(cases$cases, function(case) {
    context <- case$context
    tibble::tibble(
      dataset_id = context$dataset_id,
      table_id = context$table_id,
      column_name = context$column_name,
      column_label = context$column_label,
      column_description = context$column_description,
      column_role = context$column_role,
      value_type = "fixture",
      unit_label = if (is.null(context$unit)) NA_character_ else context$unit,
      term_type = NA_character_,
      term_iri = NA_character_,
      property_iri = NA_character_,
      entity_iri = NA_character_,
      unit_iri = NA_character_,
      constraint_iri = NA_character_,
      method_iri = NA_character_
    )
  }))
}

derive_case_package_outputs <- function(case,
                                        dictionary,
                                        suggestions,
                                        assessments) {
  original <- dictionary[
    dictionary$dataset_id == case$context$dataset_id &
      dictionary$table_id == case$context$table_id &
      dictionary$column_name == case$context$column_name,
    ,
    drop = FALSE
  ]
  if (nrow(original) != 1L) {
    abort(
      "Live case '%s' did not resolve to exactly one dictionary row.",
      case$case_id
    )
  }

  prepare_auto <- getFromNamespace(
    ".ms_prepare_llm_auto_apply_suggestions",
    "metasalmon"
  )
  mark_reviewed <- getFromNamespace(
    ".ms_mark_reviewed_dictionary_iris",
    "metasalmon"
  )
  allowed_roles <- getFromNamespace(
    ".ms_create_sdp_llm_auto_apply_roles",
    "metasalmon"
  )()
  auto_suggestions <- prepare_auto(
    original,
    suggestions,
    allowed_roles = allowed_roles
  )
  final <- metasalmon::apply_semantic_suggestions(
    original,
    suggestions = auto_suggestions,
    strategy = "llm",
    roles = allowed_roles,
    overwrite = FALSE,
    verbose = FALSE
  )
  final <- mark_reviewed(
    final,
    original_dict = original,
    suggestions = auto_suggestions,
    strategy = "llm"
  )

  gap_input <- final
  attr(gap_input, "semantic_suggestions") <- suggestions
  attr(gap_input, "semantic_llm_assessments") <- assessments
  gaps <- metasalmon::detect_semantic_term_gaps(gap_input)
  requests <- if (nrow(gaps) > 0L) {
    metasalmon::render_ontology_term_request(
      gaps,
      scope = "auto",
      ask = FALSE,
      profile_name = "theme-a-benchmark"
    )
  } else {
    tibble::tibble()
  }

  list(
    final_dictionary_rows = final,
    gap_rows = gaps,
    term_request_rows = requests,
    events = events_from_package_outputs(
      assessments = assessments,
      final_dictionary_rows = final,
      gap_rows = gaps,
      term_request_rows = requests
    )
  )
}

provider_api_key_env <- function(provider) {
  switch(
    provider,
    openai = "OPENAI_API_KEY",
    openrouter = "OPENROUTER_API_KEY",
    openai_compatible = "METASALMON_LLM_API_KEY",
    chapi = "CHAPI_API_KEY",
    abort("Unsupported live provider '%s'.", provider)
  )
}

.capture_target_index <- function(targets, contracts) {
  targets <- tibble::as_tibble(targets)
  key_columns <- unlist(contracts$semantic_target_key)
  for (name in setdiff(key_columns, names(targets))) {
    targets[[name]] <- NA_character_
  }
  group_key_fn <- getFromNamespace(
    ".ms_semantic_group_key_df",
    "metasalmon"
  )
  bundle_key_fn <- getFromNamespace(
    ".ms_semantic_bundle_key_df",
    "metasalmon"
  )
  rows <- lapply(seq_len(nrow(targets)), function(i) {
    target <- as.list(targets[i, , drop = FALSE])
    list(
      group_key = group_key_fn(targets[i, , drop = FALSE])[[1L]],
      bundle_key = bundle_key_fn(targets[i, , drop = FALSE])[[1L]],
      role = as.character(targets$dictionary_role[[i]]),
      target_key = semantic_key(
        target,
        key_columns,
        sprintf("live targets[%d]", i)
      ),
      target = target
    )
  })
  group_keys <- vapply(rows, `[[`, character(1), "group_key")
  if (anyDuplicated(group_keys) > 0L) {
    abort("Live target index contains duplicate semantic group keys.")
  }
  list(
    rows = rows,
    by_group = stats::setNames(
      vapply(rows, `[[`, character(1), "target_key"),
      group_keys
    )
  )
}

.capture_parse_prompt_payload <- function(messages) {
  user_messages <- Filter(
    function(message) {
      is.list(message) &&
        identical(message$role, "user") &&
        is.character(message$content)
    },
    messages
  )
  if (length(user_messages) == 0L) {
    return(list(kind = "unknown", payload = NULL))
  }
  content <- user_messages[[length(user_messages)]]$content
  prefixes <- c(
    bundle = "Semantic bundle payload:",
    batch = "Assessment batch:",
    decomposition = "Decomposition assessment payload:",
    target = "Assessment payload:",
    exploration = "Exploration payload:"
  )
  kind <- names(prefixes)[vapply(
    prefixes,
    function(prefix) startsWith(trimws(content), prefix),
    logical(1)
  )]
  if (length(kind) != 1L) {
    return(list(kind = "unknown", payload = NULL))
  }
  json_text <- trimws(sub(
    prefixes[[kind]],
    "",
    trimws(content),
    fixed = TRUE
  ))
  json_text <- sub(
    "\\n\\nReturn JSON only\\.?\\s*$",
    "",
    json_text,
    perl = TRUE
  )
  payload <- tryCatch(
    jsonlite::fromJSON(json_text, simplifyVector = FALSE),
    error = function(e) NULL
  )
  list(kind = kind, payload = payload)
}

.capture_match_target_payload <- function(payload_target, target_index) {
  if (!is.list(payload_target)) {
    return(character())
  }
  fields <- intersect(
    c(
      "dataset_id",
      "table_id",
      "column_name",
      "dictionary_role",
      "target_scope",
      "target_sdp_field",
      "search_query"
    ),
    names(payload_target)
  )
  matches <- Filter(function(indexed) {
    all(vapply(fields, function(name) {
      same_optional_value(
        indexed$target[[name]],
        payload_target[[name]]
      )
    }, logical(1)))
  }, target_index$rows)
  unique(vapply(matches, `[[`, character(1), "target_key"))
}

.capture_bundle_role_target <- function(bundle_key, role, target_index) {
  matches <- Filter(function(indexed) {
    identical(indexed$bundle_key, bundle_key) &&
      identical(indexed$role, role)
  }, target_index$rows)
  unique(vapply(matches, `[[`, character(1), "target_key"))
}

.capture_interaction_context <- function(messages, target_index) {
  parsed <- .capture_parse_prompt_payload(messages)
  payload <- parsed$payload
  stage <- "unknown"
  bundle_key <- NULL
  target_keys <- character()
  assessment_target_keys <- character()

  if (identical(parsed$kind, "bundle") && is.list(payload)) {
    bundle_key <- as.character(payload$bundle_key %||% "")
    slots <- payload$slots %||% list()
    slot_roles <- vapply(slots, function(slot) {
      as.character(slot$dictionary_role %||% "")
    }, character(1))
    target_keys <- unique(unlist(lapply(
      slot_roles,
      function(role) {
        .capture_bundle_role_target(bundle_key, role, target_index)
      }
    ), use.names = FALSE))
    review_round <- as.integer(payload$review_round %||% 1L)
    stage <- if (identical(review_round, 2L)) {
      "bundle_reassessment"
    } else {
      "bundle_initial"
    }
    assessment_roles <- if (identical(stage, "bundle_reassessment")) {
      slot_roles[vapply(slots, function(slot) {
        candidates <- slot$candidates %||% list()
        any(vapply(candidates, function(candidate) {
          identical(as.integer(candidate$retrieval_pass %||% 1L), 2L)
        }, logical(1)))
      }, logical(1))]
    } else {
      slot_roles
    }
    assessment_target_keys <- unique(unlist(lapply(
      assessment_roles,
      function(role) {
        .capture_bundle_role_target(bundle_key, role, target_index)
      }
    ), use.names = FALSE))
  } else if (identical(parsed$kind, "batch") && is.list(payload)) {
    stage <- "target_batch"
    group_keys <- vapply(payload, function(item) {
      as.character(item$target_key %||% "")
    }, character(1))
    target_keys <- unname(target_index$by_group[group_keys])
    target_keys <- unique(target_keys[!is.na(target_keys)])
    assessment_target_keys <- target_keys
  } else if (parsed$kind %in% c(
    "decomposition",
    "target",
    "exploration"
  ) && is.list(payload)) {
    group_key <- as.character(payload$target_key %||% "")
    target_keys <- unname(target_index$by_group[group_key])
    target_keys <- unique(target_keys[!is.na(target_keys)])
    if (length(target_keys) == 0L) {
      target_keys <- .capture_match_target_payload(
        payload$target,
        target_index
      )
    }
    stage <- if (identical(parsed$kind, "exploration")) {
      "query_generation"
    } else {
      "target_assessment"
    }
    assessment_target_keys <- if (identical(stage, "query_generation")) {
      character()
    } else {
      target_keys
    }
  }

  list(
    stage = stage,
    bundle_key = if (length(bundle_key) == 1L && nzchar(bundle_key)) {
      bundle_key
    } else {
      NULL
    },
    target_keys = unique(target_keys),
    assessment_target_keys = unique(assessment_target_keys)
  )
}

.capture_refine_target_stage <- function(context, previous_events) {
  if (!identical(context$stage, "target_assessment") ||
      length(context$target_keys) != 1L) {
    return(context)
  }
  target_key <- context$target_keys[[1L]]
  prior <- Filter(function(event) {
    target_key %in% unlist(event$target_keys %||% list())
  }, previous_events)
  if (length(prior) == 0L) {
    context$stage <- "target_initial"
    return(context)
  }
  if (identical(prior[[length(prior)]]$stage, "query_generation")) {
    context$stage <- "target_reassessment"
  } else {
    context$stage <- "target_fallback"
  }
  context
}

make_capturing_request_fn <- function(log_env, target_index) {
  function(messages, config) {
    started_at <- Sys.time()
    endpoint <- paste0(sub("/+$", "", config$base_url), "/chat/completions")
    context <- .capture_interaction_context(messages, target_index)
    context <- .capture_refine_target_stage(context, log_env$events)
    interaction_id <- sprintf(
      "interaction-%04d",
      length(log_env$events) + 1L
    )
    event <- list(
      interaction_id = interaction_id,
      event_type = "llm_request",
      stage = context$stage,
      bundle_key = context$bundle_key,
      target_keys = as.list(context$target_keys),
      assessment_target_keys = as.list(
        context$assessment_target_keys
      ),
      started_at = format(started_at, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
      provider = config$provider,
      configured_model = config$model,
      resolved_model = NULL,
      endpoint = endpoint,
      messages = messages,
      request_sha256 = value_sha256(messages),
      response_status = NULL,
      raw_response = NULL,
      response_sha256 = NULL,
      provider_response_id = NULL,
      error = NULL,
      elapsed_seconds = NULL
    )

    result <- tryCatch({
      build_body <- getFromNamespace(".ms_llm_build_chat_request_body", "metasalmon")
      extract_content <- getFromNamespace(".ms_llm_extract_message_content", "metasalmon")
      clean_json <- getFromNamespace(".ms_llm_clean_json_text", "metasalmon")

      req <- httr2::request(endpoint) |>
        httr2::req_method("POST") |>
        httr2::req_headers(
          Authorization = paste("Bearer", config$api_key),
          `Content-Type` = "application/json"
        ) |>
        httr2::req_user_agent("metasalmon-theme-a-benchmark/1") |>
        httr2::req_timeout(seconds = config$timeout_seconds) |>
        httr2::req_body_json(build_body(messages, config), auto_unbox = TRUE)

      if (identical(config$provider, "openrouter")) {
        req <- req |>
          httr2::req_headers(
            `HTTP-Referer` = "https://salmon-data-mobilization.github.io/metasalmon/",
            `X-Title` = "metasalmon Theme A benchmark"
          )
      }

      resp <- httr2::req_perform(req)
      httr2::resp_check_status(resp)
      body <- httr2::resp_body_json(resp, simplifyVector = FALSE)
      resolved_model <- body$model %||% NULL
      require_scalar_character(resolved_model, "live response.model")

      event$response_status <- httr2::resp_status(resp)
      event$resolved_model <- resolved_model
      event$raw_response <- body
      event$response_sha256 <- value_sha256(body)
      event$provider_response_id <- body$id %||% NULL
      require_scalar_character(
        event$provider_response_id,
        "live response.id"
      )

      if (!identical(resolved_model, config$model)) {
        abort(
          "Provider resolved model '%s', but the benchmark requires exact model '%s'; refusing substitution.",
          resolved_model,
          config$model
        )
      }

      content <- clean_json(extract_content(body))
      parsed <- jsonlite::fromJSON(content, simplifyVector = FALSE)
      if (!is.list(parsed)) {
        abort("Live LLM response content was not a JSON object.")
      }
      parsed
    }, error = function(e) e)

    event$elapsed_seconds <- as.numeric(difftime(Sys.time(), started_at, units = "secs"))
    if (inherits(result, "error")) {
      event$error <- conditionMessage(result)
    }
    log_env$events[[length(log_env$events) + 1L]] <- event
    if (inherits(result, "error")) {
      stop(result)
    }
    result
  }
}

.capture_interaction_succeeded <- function(event) {
  is.null(event$error) &&
    !is.null(event$response_status) &&
    as.integer(event$response_status) >= 200L &&
    as.integer(event$response_status) < 300L &&
    !is.null(event$raw_response)
}

.capture_response_payload <- function(event) {
  body <- event$raw_response
  choices <- body$choices %||% list()
  if (length(choices) == 0L) {
    abort(
      "Provider interaction '%s' has no response choice.",
      event$interaction_id
    )
  }
  content <- choices[[1L]]$message$content %||% ""
  if (is.list(content)) {
    content <- paste(vapply(content, function(part) {
      if (is.list(part) && identical(part$type %||% NULL, "text")) {
        return(as.character(part$text %||% ""))
      }
      if (is.character(part)) {
        return(part[[1L]])
      }
      ""
    }, character(1)), collapse = "\n")
  } else {
    content <- paste(as.character(content), collapse = "\n")
  }
  content <- trimws(content)
  content <- sub("^```json\\s*", "", content, perl = TRUE)
  content <- sub("^```\\s*", "", content, perl = TRUE)
  content <- sub("\\s*```$", "", content, perl = TRUE)
  json_start <- regexpr("[\\[{]", content, perl = TRUE)[[1L]]
  if (json_start > 1L) {
    content <- substring(content, json_start)
  }
  if (json_start > 0L && nzchar(content)) {
    chars <- strsplit(content, "", fixed = TRUE)[[1L]]
    opening <- chars[[1L]]
    closing <- if (identical(opening, "{")) "}" else "]"
    depth <- 0L
    in_string <- FALSE
    escaping <- FALSE
    for (i in seq_along(chars)) {
      char <- chars[[i]]
      if (escaping) {
        escaping <- FALSE
        next
      }
      if (identical(char, "\\") && in_string) {
        escaping <- TRUE
        next
      }
      if (identical(char, "\"")) {
        in_string <- !in_string
        next
      }
      if (in_string) {
        next
      }
      if (identical(char, opening)) {
        depth <- depth + 1L
      } else if (identical(char, closing)) {
        depth <- depth - 1L
        if (depth == 0L) {
          content <- substr(content, 1L, i)
          break
        }
      }
    }
  }
  parsed <- tryCatch(
    jsonlite::fromJSON(content, simplifyVector = FALSE),
    error = function(e) e
  )
  if (inherits(parsed, "error") || !is.list(parsed)) {
    abort(
      "Provider interaction '%s' does not contain parseable JSON evidence.",
      event$interaction_id
    )
  }
  parsed
}

.capture_bundle_assessment_is_usable <- function(event, item, role) {
  parsed_prompt <- .capture_parse_prompt_payload(event$messages)
  if (!identical(parsed_prompt$kind, "bundle") ||
      !is.list(parsed_prompt$payload)) {
    return(FALSE)
  }
  slots <- parsed_prompt$payload$slots %||% list()
  slot_matches <- which(vapply(slots, function(slot) {
    identical(
      tolower(as.character(slot$dictionary_role %||% "")),
      tolower(role)
    )
  }, logical(1)))
  if (length(slot_matches) != 1L) {
    return(FALSE)
  }

  decision <- tolower(as.character(item$decision %||% ""))
  if (identical(decision, "propose_new_term")) {
    decision <- "request_new_term"
  }
  allowed <- c(
    "accept",
    "review",
    "retry_search",
    "request_new_term",
    "reject_shortlist"
  )
  confidence <- suppressWarnings(as.numeric(item$confidence %||% NA_real_))
  if (length(decision) != 1L ||
      !decision %in% allowed ||
      length(confidence) != 1L ||
      is.na(confidence) ||
      confidence < 0 ||
      confidence > 1) {
    return(FALSE)
  }

  selected_id <- item$selected_candidate_id %||%
    item$candidate_id %||%
    NULL
  selected_id <- if (is.null(selected_id) ||
      length(selected_id) != 1L ||
      is.na(selected_id) ||
      !nzchar(trimws(as.character(selected_id)))) {
    NULL
  } else {
    trimws(as.character(selected_id))
  }
  if (identical(decision, "accept")) {
    candidates <- slots[[slot_matches[[1L]]]]$candidates %||% list()
    candidate_ids <- vapply(candidates, function(candidate) {
      as.character(candidate$candidate_id %||% "")
    }, character(1))
    return(!is.null(selected_id) && selected_id %in% candidate_ids)
  }

  is.null(selected_id)
}

.capture_provider_assessment <- function(event,
                                         role,
                                         require_usable = FALSE) {
  payload <- .capture_response_payload(event)
  if (event$stage %in% c("bundle_initial", "bundle_reassessment")) {
    items <- payload$assessments %||% list()
    matches <- which(vapply(items, function(item) {
      identical(
        tolower(as.character(item$dictionary_role %||% "")),
        tolower(role)
      )
    }, logical(1)))
    if (length(matches) != 1L) {
      abort(
        paste0(
          "Provider interaction '%s' does not contain exactly one ",
          "assessment for role '%s'."
        ),
        event$interaction_id,
        role
      )
    }
    item <- items[[matches[[1L]]]]
    if (isTRUE(require_usable) &&
        !.capture_bundle_assessment_is_usable(event, item, role)) {
      abort(
        "Provider interaction '%s' contains an unusable assessment for role '%s'.",
        event$interaction_id,
        role
      )
    }
    return(item)
  }

  if (event$stage %in% c(
    "target_initial",
    "target_fallback",
    "target_reassessment"
  )) {
    if (isTRUE(require_usable)) {
      decision <- tolower(as.character(payload$decision %||% ""))
      confidence <- suppressWarnings(as.numeric(
        payload$confidence %||% NA_real_
      ))
      if (identical(decision, "propose_new_term")) {
        decision <- "request_new_term"
      }
      if (length(decision) != 1L ||
          !decision %in% c(
            "accept",
            "review",
            "retry_search",
            "request_new_term",
            "reject_shortlist"
          ) ||
          length(confidence) != 1L ||
          is.na(confidence) ||
          confidence < 0 ||
          confidence > 1) {
        abort(
          "Provider interaction '%s' contains an unusable target assessment.",
          event$interaction_id
        )
      }
    }
    return(payload)
  }

  abort(
    "Provider interaction stage '%s' cannot derive an assessment row.",
    event$stage
  )
}

build_assessment_lineage <- function(capture_cases,
                                     interaction_events,
                                     contracts) {
  key_columns <- unlist(contracts$semantic_target_key)
  assessment_records <- unlist(lapply(capture_cases, function(observed) {
    lapply(seq_along(observed$assessment_rows), function(i) {
      row <- observed$assessment_rows[[i]]
      list(
        case_id = observed$case_id,
        row = row,
        role = as.character(row$dictionary_role),
        target_key = semantic_key(
          row,
          key_columns,
          sprintf(
            "capture case '%s' assessment_rows[%d]",
            observed$case_id,
            i
          )
        )
      )
    })
  }), recursive = FALSE)
  assessment_keys <- vapply(
    assessment_records,
    `[[`,
    character(1),
    "target_key"
  )
  if (anyDuplicated(assessment_keys) > 0L) {
    abort("Live capture contains duplicate canonical assessment target keys.")
  }

  lapply(assessment_records, function(record) {
    relevant <- which(vapply(interaction_events, function(event) {
      record$target_key %in% unlist(
        event$assessment_target_keys %||% list()
      )
    }, logical(1)))
    llm_error <- record$row$llm_error %||% NULL
    deterministic <- non_empty(llm_error)

    if (deterministic) {
      event <- if (length(relevant) > 0L) {
        interaction_events[[relevant[[length(relevant)]]]]
      } else {
        NULL
      }
      return(list(
        case_id = record$case_id,
        target_key = record$target_key,
        outcome = "deterministic_fallback",
        interaction_id = if (is.null(event)) NULL else event$interaction_id,
        interaction_stage = "deterministic_fallback",
        dictionary_role = record$role,
        assessment_sha256 = value_sha256(record$row),
        provider_assessment_sha256 = NULL,
        fallback_reason = as.character(llm_error[[1L]])
      ))
    }

    successful <- relevant[vapply(
      interaction_events[relevant],
      .capture_interaction_succeeded,
      logical(1)
    )]
    derivable <- successful[vapply(successful, function(index) {
      tryCatch({
        .capture_provider_assessment(
          interaction_events[[index]],
          record$role,
          require_usable = TRUE
        )
        TRUE
      }, error = function(e) FALSE)
    }, logical(1))]
    if (length(derivable) == 0L) {
      abort(
        paste0(
          "Assessment target '%s' has no successful provider ",
          "interaction with a usable assessment and no explicit ",
          "deterministic fallback."
        ),
        record$target_key
      )
    }
    event <- interaction_events[[derivable[[length(derivable)]]]]
    provider_assessment <- .capture_provider_assessment(
      event,
      record$role,
      require_usable = TRUE
    )
    list(
      case_id = record$case_id,
      target_key = record$target_key,
      outcome = "provider",
      interaction_id = event$interaction_id,
      interaction_stage = event$stage,
      dictionary_role = record$role,
      assessment_sha256 = value_sha256(record$row),
      provider_assessment_sha256 = value_sha256(provider_assessment),
      fallback_reason = NULL
    )
  })
}

git_value <- function(args, default = NA_character_) {
  value <- tryCatch(
    system2("git", c("-C", repo_root, args), stdout = TRUE, stderr = FALSE),
    error = function(e) character()
  )
  if (length(value) == 0L) default else value[[1L]]
}

git_lines <- function(args) {
  tryCatch(
    system2("git", c("-C", repo_root, args), stdout = TRUE, stderr = FALSE),
    error = function(e) character()
  )
}

git_status <- function(args) {
  status <- suppressWarnings(tryCatch(
    system2(
      "git",
      c("-C", repo_root, args),
      stdout = FALSE,
      stderr = FALSE
    ),
    error = function(e) 1L
  ))
  as.integer(status %||% 1L)
}

git_commit_tree_cache <- new.env(parent = emptyenv())

git_commit_tree <- function(sha) {
  if (exists(sha, envir = git_commit_tree_cache, inherits = FALSE)) {
    return(get(sha, envir = git_commit_tree_cache, inherits = FALSE))
  }
  if (git_status(c("cat-file", "-e", paste0(sha, "^{commit}"))) != 0L) {
    abort("Capture Git commit does not exist in the repository: %s.", sha)
  }
  tree <- git_value(
    c("rev-parse", paste0(sha, "^{tree}")),
    default = ""
  )
  assign(x = sha, value = tree, envir = git_commit_tree_cache)
  tree
}

repo_relative_path <- function(path, label) {
  if (is.null(path) || length(path) != 1L || !is.character(path) ||
      is.na(path) || !nzchar(trimws(path))) {
    abort("%s must be one repository file path.", label)
  }

  candidate <- if (grepl("^/", path)) path else file.path(repo_root, path)
  absolute <- normalizePath(
    candidate,
    winslash = "/",
    mustWork = TRUE
  )
  root_prefix <- paste0(repo_root, "/")
  if (!startsWith(absolute, root_prefix)) {
    abort("%s must resolve inside the metasalmon repository.", label)
  }

  substring(absolute, nchar(root_prefix) + 1L)
}

write_git_blob <- function(sha, relative_path, output_path, label) {
  object_name <- paste0(sha, ":", relative_path)
  if (git_status(c("cat-file", "-e", object_name)) != 0L) {
    abort(
      "Recorded Git commit does not contain required %s '%s'.",
      label,
      relative_path
    )
  }

  error_path <- tempfile("theme-a-git-blob-error-")
  on.exit(unlink(error_path), add = TRUE)
  status <- suppressWarnings(tryCatch(
    system2(
      "git",
      c("-C", repo_root, "show", object_name),
      stdout = output_path,
      stderr = error_path
    ),
    error = function(e) 1L
  ))
  if (!identical(as.integer(status %||% 1L), 0L) ||
      !file.exists(output_path)) {
    abort(
      "Could not read required %s '%s' from recorded Git commit.",
      label,
      relative_path
    )
  }

  invisible(output_path)
}

git_blob_sha256_cache <- new.env(parent = emptyenv())

git_blob_sha256 <- function(sha, relative_path, label) {
  cache_key <- paste(sha, relative_path, sep = "\r")
  if (exists(cache_key, envir = git_blob_sha256_cache, inherits = FALSE)) {
    return(get(cache_key, envir = git_blob_sha256_cache, inherits = FALSE))
  }

  output_path <- tempfile("theme-a-git-blob-")
  on.exit(unlink(output_path), add = TRUE)
  write_git_blob(sha, relative_path, output_path, label)
  hash <- file_sha256(output_path)
  assign(x = cache_key, value = hash, envir = git_blob_sha256_cache)
  hash
}

git_description_version_cache <- new.env(parent = emptyenv())

git_description_version <- function(sha) {
  if (exists(sha, envir = git_description_version_cache, inherits = FALSE)) {
    return(get(
      sha,
      envir = git_description_version_cache,
      inherits = FALSE
    ))
  }

  output_path <- tempfile("theme-a-description-")
  on.exit(unlink(output_path), add = TRUE)
  write_git_blob(sha, "DESCRIPTION", output_path, "DESCRIPTION")
  description <- tryCatch(
    read.dcf(output_path),
    error = function(e) {
      abort(
        "Could not parse DESCRIPTION from recorded Git commit: %s",
        conditionMessage(e)
      )
    }
  )
  version <- unname(description[1L, "Version"])
  assign(
    x = sha,
    value = version,
    envir = git_description_version_cache
  )
  version
}

file_sha256 <- function(path) {
  path <- normalizePath(path, winslash = "/", mustWork = TRUE)
  if (requireNamespace("digest", quietly = TRUE)) {
    return(tolower(digest::digest(
      file = path,
      algo = "sha256",
      serialize = FALSE
    )))
  }

  command <- Sys.which("sha256sum")
  args <- shQuote(path)
  if (!nzchar(command)) {
    command <- Sys.which("shasum")
    args <- c("-a", "256", shQuote(path))
  }
  if (!nzchar(command)) {
    abort("A sha256sum or shasum executable is required for Theme A evidence.")
  }

  output <- tryCatch(
    system2(command, args, stdout = TRUE, stderr = TRUE),
    error = function(e) character()
  )
  hash <- if (length(output) > 0L) {
    strsplit(trimws(output[[1L]]), "\\s+")[[1L]][[1L]]
  } else {
    ""
  }
  if (!grepl("^[0-9a-fA-F]{64}$", hash)) {
    abort("Could not compute a SHA-256 hash for %s.", path)
  }
  tolower(hash)
}

text_sha256 <- function(text) {
  path <- tempfile("theme-a-sha256-")
  on.exit(unlink(path), add = TRUE)
  writeLines(enc2utf8(text), path, useBytes = TRUE)
  file_sha256(path)
}

value_sha256 <- function(value) {
  text_sha256(canonical_evidence_json(value))
}

normalise_endpoint <- function(endpoint) {
  endpoint <- trimws(endpoint %||% "")
  if (!nzchar(endpoint)) {
    return("")
  }
  sub("/+$", "", endpoint)
}

git_source_state <- function() {
  status <- git_lines(c("status", "--porcelain=v1", "--untracked-files=all"))
  diff <- git_lines(c("diff", "--binary", "HEAD"))
  list(
    git_sha = git_value(c("rev-parse", "HEAD")),
    git_tree = git_value(c("rev-parse", "HEAD^{tree}")),
    git_dirty = length(status) > 0L,
    source_state_sha256 = text_sha256(paste(c(status, diff), collapse = "\n"))
  )
}

clean_source_state_sha256 <- function() {
  text_sha256("")
}

write_raw_capture_artifacts <- function(capture, staging_dir) {
  raw_path <- file.path(staging_dir, "capture.raw.json")
  checksum_path <- paste0(raw_path, ".sha256")
  review_path <- file.path(staging_dir, "capture.json")
  if (any(file.exists(c(raw_path, checksum_path, review_path)))) {
    abort("Theme A capture artifacts already exist in %s.", staging_dir)
  }

  write_json(capture, raw_path)
  raw_hash <- file_sha256(raw_path)
  writeLines(
    paste(raw_hash, basename(raw_path)),
    checksum_path,
    useBytes = TRUE
  )
  copied <- file.copy(raw_path, review_path, overwrite = FALSE)
  if (!isTRUE(copied)) {
    abort("Could not create the Theme A review copy at %s.", review_path)
  }
  Sys.chmod(c(raw_path, checksum_path), mode = "0444")
  Sys.chmod(review_path, mode = "0644")
  list(
    raw_path = raw_path,
    checksum_path = checksum_path,
    review_path = review_path,
    raw_sha256 = raw_hash
  )
}

validate_review_lineage <- function(capture, capture_path, contracts) {
  if (is.null(capture_path) ||
      length(capture_path) != 1L ||
      !file.exists(capture_path)) {
    abort(
      "Reviewed capture validation requires its staging capture path."
    )
  }
  capture_path <- normalizePath(
    capture_path,
    winslash = "/",
    mustWork = TRUE
  )
  staging_raw_path <- file.path(dirname(capture_path), "capture.raw.json")
  promoted_raw_path <- file.path(
    dirname(capture_path),
    paste0(
      safe_run_id(capture$run_id),
      "-raw-",
      capture$review$pre_sanitization_sha256,
      ".json"
    )
  )
  raw_path <- if (file.exists(staging_raw_path)) {
    staging_raw_path
  } else {
    promoted_raw_path
  }
  checksum_path <- paste0(raw_path, ".sha256")
  if (!file.exists(raw_path) || !file.exists(checksum_path)) {
    abort(
      paste0(
        "Reviewed capture is missing its immutable raw capture or ",
        "checksum sidecar."
      )
    )
  }

  raw_hash <- file_sha256(raw_path)
  checksum <- readLines(checksum_path, warn = FALSE, encoding = "UTF-8")
  checksum_hash <- if (length(checksum) > 0L) {
    strsplit(trimws(checksum[[1L]]), "\\s+")[[1L]][[1L]]
  } else {
    ""
  }
  if (!identical(checksum_hash, raw_hash) ||
      !identical(capture$review$pre_sanitization_sha256, raw_hash)) {
    abort(
      "Reviewed capture does not match its raw-capture checksum lineage."
    )
  }

  raw <- read_json(raw_path, "raw capture")
  if (!identical(raw$run_id, capture$run_id) ||
      !identical(raw$schema_version, capture$schema_version) ||
      !identical(raw$mode, "live") ||
      !identical(raw$evidence_status, "unreviewed_staging") ||
      !identical(raw$review$status, "unreviewed") ||
      !identical(raw$review$sanitized, FALSE) ||
      !identical(raw$review$raw_capture_reviewed, FALSE) ||
      !identical(
        raw$review$raw_capture_safe_to_publish,
        FALSE
      )) {
    abort("Raw capture does not contain the expected unreviewed run.")
  }
  immutable_fields <- c(
    "provenance",
    "execution_error",
    "cases",
    "assessment_lineage",
    "evaluation"
  )
  for (name in immutable_fields) {
    if (!identical(raw[[name]], capture[[name]])) {
      abort(
        "Reviewed capture changed immutable semantic evidence field '%s'.",
        name
      )
    }
  }

  raw_events <- raw$interaction_events
  reviewed_events <- capture$interaction_events
  if (length(raw_events) != length(reviewed_events)) {
    abort("Reviewed capture changed the number of provider interactions.")
  }
  event_identity_fields <- c(
    "interaction_id",
    "event_type",
    "stage",
    "bundle_key",
    "target_keys",
    "assessment_target_keys",
    "started_at",
    "provider",
    "configured_model",
    "resolved_model",
    "endpoint",
    "response_status",
    "request_sha256",
    "response_sha256",
    "provider_response_id"
  )
  for (i in seq_along(raw_events)) {
    for (name in event_identity_fields) {
      if (!identical(raw_events[[i]][[name]], reviewed_events[[i]][[name]])) {
        abort(
          paste0(
            "Reviewed capture changed provider interaction identity ",
            "field '%s' for event %d."
          ),
          name,
          i
        )
      }
    }

    if (!identical(
      raw_events[[i]]$request_sha256,
      value_sha256(raw_events[[i]]$messages)
    )) {
      abort(
        "Raw provider request hash is invalid for event %d.",
        i
      )
    }
    if (!is.null(raw_events[[i]]$raw_response) &&
        !identical(
          raw_events[[i]]$response_sha256,
          value_sha256(raw_events[[i]]$raw_response)
        )) {
      abort(
        "Raw provider response hash is invalid for event %d.",
        i
      )
    }
    if (!is.null(raw_events[[i]]$raw_response) &&
        !identical(
          raw_events[[i]]$provider_response_id,
          raw_events[[i]]$raw_response$id %||% NULL
        )) {
      abort(
        "Raw provider response ID is invalid for event %d.",
        i
      )
    }
  }
  validate_assessment_lineage(
    raw,
    contracts,
    verify_provider_payload = TRUE
  )
  invisible(capture)
}

validate_git_source_provenance <- function(provenance) {
  sha <- provenance$git_sha
  tree <- provenance$git_tree
  resolved_tree <- git_commit_tree(sha)
  if (!identical(resolved_tree, tree)) {
    abort("Capture Git tree does not match the recorded commit.")
  }
  if (!identical(provenance$git_dirty, FALSE)) {
    abort("Theme A release captures must come from a clean Git worktree.")
  }
  if (!identical(
    provenance$source_state_sha256,
    clean_source_state_sha256()
  )) {
    abort(
      paste0(
        "Capture source-state SHA-256 is not the canonical clean ",
        "status/diff hash."
      )
    )
  }
  invisible(provenance)
}

validate_git_artifact_provenance <- function(provenance,
                                             schema_path,
                                             cases_path,
                                             ontology_manifest_path) {
  sha <- provenance$git_sha
  artifact_specs <- list(
    cases = list(
      recorded_path = provenance$cases_fixture,
      current_path = cases_path,
      recorded_hash = provenance$cases_fixture_sha256,
      label = "cases fixture"
    ),
    schema = list(
      recorded_path = provenance$schema_fixture,
      current_path = schema_path,
      recorded_hash = provenance$schema_fixture_sha256,
      label = "schema fixture"
    ),
    ontology_manifest = list(
      recorded_path = provenance$ontology_manifest_fixture,
      current_path = ontology_manifest_path,
      recorded_hash = provenance$ontology_manifest_fixture_sha256,
      label = "ontology-manifest fixture"
    )
  )

  for (artifact in artifact_specs) {
    recorded_relative <- repo_relative_path(
      artifact$recorded_path,
      paste0("capture.provenance.", artifact$label)
    )
    current_relative <- repo_relative_path(
      artifact$current_path,
      paste0("current ", artifact$label)
    )
    if (!identical(recorded_relative, current_relative)) {
      abort(
        "Capture %s path does not match the fixture used for validation.",
        artifact$label
      )
    }
    committed_hash <- git_blob_sha256(
      sha,
      recorded_relative,
      artifact$label
    )
    if (!identical(artifact$recorded_hash, committed_hash)) {
      abort(
        paste0(
          "Capture %s SHA-256 does not match the artifact in the ",
          "recorded Git commit."
        ),
        artifact$label
      )
    }
  }

  script_relative <- repo_relative_path(script_path, "benchmark script")
  committed_script_hash <- git_blob_sha256(
    sha,
    script_relative,
    "benchmark script"
  )
  if (!identical(
    provenance$benchmark_script_sha256,
    committed_script_hash
  )) {
    abort(
      paste0(
        "Capture benchmark-script SHA-256 does not match the script in ",
        "the recorded Git commit."
      )
    )
  }

  committed_version <- git_description_version(sha)
  if (!identical(provenance$package_version, committed_version)) {
    abort(
      "Capture package version does not match DESCRIPTION in the recorded Git commit."
    )
  }

  invisible(provenance)
}

safe_run_id <- function(run_id) {
  if (is.null(run_id) || !nzchar(run_id)) {
    run_id <- paste0(format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC"), "-", Sys.getpid())
  }
  if (!grepl("^[A-Za-z0-9][A-Za-z0-9._-]*$", run_id)) {
    abort("--run-id may contain only letters, numbers, periods, underscores, and hyphens.")
  }
  run_id
}

run_live <- function(options) {
  if (!isTRUE(options$allow_live_api)) {
    abort(
      paste0(
        "Live mode is disabled by default. Pass --allow-live-api=true only ",
        "for an intentional, potentially billable provider run."
      )
    )
  }

  schema <- read_json(options$schema, "fixture schema")
  contracts <- schema_contracts(schema)
  cases <- read_json(options$cases, "cases fixture")
  ontology_manifest <- read_json(
    options$ontology_manifest,
    "ontology manifest"
  )
  validate_cases(cases, contracts, ontology_manifest)

  provider <- options$provider %||% Sys.getenv("THEME_A_LLM_PROVIDER", unset = "")
  model <- options$model %||% Sys.getenv("THEME_A_LLM_MODEL", unset = "")
  provider <- trimws(provider)
  model <- trimws(model)
  if (!nzchar(provider) || !nzchar(model)) {
    abort("Live mode requires exact --provider and --model values (or THEME_A_LLM_PROVIDER/THEME_A_LLM_MODEL).")
  }
  if (!provider %in% c("openai", "openrouter", "openai_compatible", "chapi")) {
    abort("Unsupported live provider '%s'.", provider)
  }
  if (identical(tolower(model), "openrouter/free")) {
    abort("Live mode rejects openrouter/free because it cannot guarantee one exact resolved model.")
  }

  api_key_env <- options$api_key_env %||% provider_api_key_env(provider)
  api_key <- Sys.getenv(api_key_env, unset = "")
  if (!nzchar(api_key)) {
    abort("Live mode requires API credentials in environment variable %s.", api_key_env)
  }

  if (!requireNamespace("pkgload", quietly = TRUE)) {
    abort("Live mode requires the pkgload package.")
  }
  source_state <- git_source_state()
  validate_git_source_provenance(source_state)
  pkgload::load_all(repo_root, export_all = FALSE, helpers = FALSE, quiet = TRUE)

  suggestions <- build_live_suggestions(cases)
  targets <- build_live_targets(cases)
  dict <- build_live_dictionary(cases)
  if (nrow(suggestions) == 0L) {
    abort("Live fixture contains no candidate snapshots to assess.")
  }

  run_id <- safe_run_id(options$run_id)
  staging_dir <- file.path(theme_a_paths$staging, run_id)
  if (dir.exists(staging_dir)) {
    abort("Staging run already exists: %s", staging_dir)
  }
  dir.create(staging_dir, recursive = TRUE, showWarnings = FALSE)

  request_log <- new.env(parent = emptyenv())
  request_log$events <- list()
  target_index <- .capture_target_index(targets, contracts)
  request_fn <- make_capturing_request_fn(request_log, target_index)
  assess_fn <- getFromNamespace(".ms_assess_semantic_suggestions_llm", "metasalmon")
  context_text <- vapply(cases$cases, function(case) {
    paste(case$case_id, case$context$context_text, sep = ": ")
  }, character(1))
  empty_search <- function(query, role = NA_character_, sources = character(), ...) {
    tibble::tibble()
  }

  started_at <- Sys.time()
  execution_error <- NULL
  result <- tryCatch(
    assess_fn(
      suggestions = suggestions,
      provider = provider,
      model = model,
      api_key = api_key,
      base_url = options$base_url,
      top_n = 5L,
      context_text = context_text,
      timeout_seconds = options$timeout_seconds,
      request_fn = request_fn,
      search_fn = empty_search,
      sources = unique(suggestions$source),
      max_per_role = 5L,
      targets = targets,
      dict = dict
    ),
    error = function(e) {
      execution_error <<- conditionMessage(e)
      list(suggestions = suggestions, assessments = tibble::tibble())
    }
  )

  assessments <- normalise_assessment_df(result$assessments, contracts)
  capture_cases <- lapply(cases$cases, function(case) {
    column_name <- case$context$column_name
    case_assessments <- assessments[assessments$column_name == column_name, , drop = FALSE]
    case_suggestions <- tibble::as_tibble(result$suggestions)
    if ("column_name" %in% names(case_suggestions)) {
      case_suggestions <- case_suggestions[case_suggestions$column_name == column_name, , drop = FALSE]
    } else {
      case_suggestions <- case_suggestions[0, , drop = FALSE]
    }
    package_outputs <- derive_case_package_outputs(
      case = case,
      dictionary = dict,
      suggestions = case_suggestions,
      assessments = case_assessments
    )
    list(
      case_id = case$case_id,
      events = package_outputs$events,
      assessment_rows = data_frame_rows(case_assessments, unlist(contracts$assessment_columns)),
      suggestion_rows = data_frame_rows(case_suggestions),
      final_dictionary_rows = data_frame_rows(package_outputs$final_dictionary_rows),
      gap_rows = data_frame_rows(package_outputs$gap_rows),
      term_request_rows = data_frame_rows(package_outputs$term_request_rows)
    )
  })
  assessment_lineage <- build_assessment_lineage(
    capture_cases,
    request_log$events,
    contracts
  )

  replay_like <- list(
    schema_version = contracts$replay_schema_version,
    fixture_version = cases$fixture_version,
    evidence_status = "synthetic_regression_exemplar",
    provenance = list(source = "live capture"),
    cases = capture_cases
  )
  evaluation <- evaluate_oracles(cases, replay_like)

  description <- read.dcf(file.path(repo_root, "DESCRIPTION"))
  resolved_models <- unique(vapply(
    request_log$events,
    function(event) event$resolved_model %||% NA_character_,
    character(1)
  ))
  resolved_models <- resolved_models[!is.na(resolved_models) & nzchar(resolved_models)]
  successful_endpoints <- unique(vapply(
    Filter(
      function(event) is.null(event$error),
      request_log$events
    ),
    function(event) normalise_endpoint(event$endpoint),
    character(1)
  ))
  successful_endpoints <- successful_endpoints[nzchar(successful_endpoints)]
  capture <- list(
    schema_version = contracts$capture_schema_version,
    run_id = run_id,
    mode = "live",
    evidence_status = "unreviewed_staging",
    review = list(
      status = "unreviewed",
      sanitized = FALSE,
      raw_capture_reviewed = FALSE,
      raw_capture_safe_to_publish = FALSE,
      reviewed_by = NULL,
      reviewed_at = NULL,
      notes = NULL,
      pre_sanitization_sha256 = NULL
    ),
    provenance = list(
      created_at = format(started_at, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
      completed_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
      git_sha = source_state$git_sha,
      git_tree = source_state$git_tree,
      git_dirty = source_state$git_dirty,
      source_state_sha256 = source_state$source_state_sha256,
      git_branch = git_value(c("branch", "--show-current")),
      package_version = unname(description[1L, "Version"]),
      cases_fixture = repo_relative_path(options$cases, "cases fixture"),
      cases_fixture_sha256 = file_sha256(options$cases),
      schema_fixture = repo_relative_path(options$schema, "schema fixture"),
      schema_fixture_sha256 = file_sha256(options$schema),
      ontology_manifest_fixture = repo_relative_path(
        options$ontology_manifest,
        "ontology-manifest fixture"
      ),
      ontology_manifest_fixture_sha256 = file_sha256(
        options$ontology_manifest
      ),
      benchmark_script_sha256 = file_sha256(script_path),
      retrieval_mode = "frozen_fixture",
      data_classification = "synthetic_theme_a_fixture",
      provider = provider,
      configured_model = model,
      resolved_models = resolved_models,
      endpoint = if (length(successful_endpoints) == 1L) {
        successful_endpoints[[1L]]
      } else {
        successful_endpoints
      },
      api_key_environment = api_key_env,
      ontology_provenance = cases$ontology_provenance
    ),
    execution_error = execution_error,
    interaction_events = request_log$events,
    assessment_lineage = assessment_lineage,
    cases = capture_cases,
    evaluation = evaluation
  )

  capture_artifacts <- write_raw_capture_artifacts(capture, staging_dir)
  print_evaluation(evaluation, label = "live")
  cat(sprintf(
    paste0(
      "Raw capture: %s\nRaw SHA-256: %s\n",
      "Review copy: %s\n"
    ),
    capture_artifacts$raw_path,
    capture_artifacts$raw_sha256,
    capture_artifacts$review_path
  ))

  if (!is.null(execution_error)) {
    abort("Theme A live execution failed: %s", execution_error)
  }
  if (length(resolved_models) == 0L || !identical(resolved_models, model)) {
    abort("Live capture did not prove one exact resolved model matching '%s'.", model)
  }
  if (length(successful_endpoints) != 1L) {
    abort("Live capture did not prove one normalized successful provider endpoint.")
  }
  if (!identical(evaluation$status, "pass")) {
    abort("Theme A live benchmark failed one or more semantic oracle checks.")
  }
  validate_capture(
    capture,
    cases,
    contracts,
    schema_path = options$schema,
    cases_path = options$cases,
    ontology_manifest_path = options$ontology_manifest,
    require_oracle_pass = TRUE
  )
  invisible(capture)
}

validate_capture_cases <- function(observed_cases, cases, contracts, field) {
  require_array(observed_cases, field)
  expected_ids <- vapply(cases$cases, `[[`, character(1), "case_id")
  cases_by_id <- stats::setNames(cases$cases, expected_ids)
  actual_ids <- character()

  for (i in seq_along(observed_cases)) {
    observed <- observed_cases[[i]]
    case_field <- sprintf("%s[%d]", field, i)
    require_object(observed, case_field)
    require_fields(
      observed,
      c(
        "case_id", "events", "assessment_rows", "suggestion_rows",
        "final_dictionary_rows", "gap_rows", "term_request_rows"
      ),
      case_field
    )
    actual_ids <- c(actual_ids, observed$case_id)
    if (!observed$case_id %in% expected_ids) {
      abort("%s.case_id is not declared by the cases fixture.", case_field)
    }
    require_array(observed$events, paste0(case_field, ".events"))
    for (j in seq_along(observed$events)) {
      validate_event(
        observed$events[[j]],
        sprintf("%s.events[%d]", case_field, j),
        contracts
      )
    }
    validate_assessment_rows(
      observed$assessment_rows,
      paste0(case_field, ".assessment_rows"),
      contracts
    )
    require_array(observed$suggestion_rows, paste0(case_field, ".suggestion_rows"))
    require_array(
      observed$final_dictionary_rows,
      paste0(case_field, ".final_dictionary_rows")
    )
    require_array(observed$gap_rows, paste0(case_field, ".gap_rows"))
    require_array(
      observed$term_request_rows,
      paste0(case_field, ".term_request_rows")
    )
    validate_event_cross_consistency(
      observed,
      cases_by_id[[observed$case_id]],
      contracts,
      case_field
    )
  }

  if (anyDuplicated(actual_ids) > 0L || !setequal(actual_ids, expected_ids)) {
    abort(
      "%s case IDs must exactly match the case fixture. Missing: %s. Extra: %s.",
      field,
      paste(setdiff(expected_ids, actual_ids), collapse = ", "),
      paste(setdiff(actual_ids, expected_ids), collapse = ", ")
    )
  }
  invisible(observed_cases)
}

validate_assessment_lineage <- function(capture,
                                        contracts,
                                        verify_provider_payload = FALSE) {
  require_array(
    capture$assessment_lineage,
    "capture.assessment_lineage"
  )
  key_columns <- unlist(contracts$semantic_target_key)
  assessments <- unlist(lapply(capture$cases, function(observed) {
    lapply(seq_along(observed$assessment_rows), function(i) {
      list(
        case_id = observed$case_id,
        row = observed$assessment_rows[[i]],
        role = as.character(
          observed$assessment_rows[[i]]$dictionary_role
        ),
        target_key = semantic_key(
          observed$assessment_rows[[i]],
          key_columns,
          sprintf(
            "capture case '%s' assessment_rows[%d]",
            observed$case_id,
            i
          )
        )
      )
    })
  }), recursive = FALSE)
  assessment_keys <- vapply(assessments, `[[`, character(1), "target_key")
  if (anyDuplicated(assessment_keys) > 0L) {
    abort("Capture assessments must be unique by canonical target key.")
  }
  case_by_key <- stats::setNames(
    vapply(assessments, `[[`, character(1), "case_id"),
    assessment_keys
  )
  assessment_by_key <- stats::setNames(assessments, assessment_keys)

  interaction_ids <- vapply(
    capture$interaction_events,
    `[[`,
    character(1),
    "interaction_id"
  )
  if (anyDuplicated(interaction_ids) > 0L) {
    abort("Capture interaction_id values must be unique.")
  }
  interactions_by_id <- stats::setNames(
    capture$interaction_events,
    interaction_ids
  )

  lineage_keys <- character()
  for (i in seq_along(capture$assessment_lineage)) {
    lineage <- capture$assessment_lineage[[i]]
    field <- sprintf("capture.assessment_lineage[%d]", i)
    require_object(lineage, field)
    require_fields(
      lineage,
      c(
        "case_id",
        "target_key",
        "outcome",
        "interaction_id",
        "interaction_stage",
        "dictionary_role",
        "assessment_sha256",
        "provider_assessment_sha256",
        "fallback_reason"
      ),
      field
    )
    require_scalar_character(lineage$case_id, paste0(field, ".case_id"))
    require_scalar_character(
      lineage$target_key,
      paste0(field, ".target_key")
    )
    require_scalar_character(
      lineage$outcome,
      paste0(field, ".outcome")
    )
    if (!lineage$outcome %in% unlist(
      contracts$capture_lineage_outcomes
    )) {
      abort("%s.outcome is not recognized.", field)
    }
    if (!lineage$target_key %in% assessment_keys ||
        !identical(case_by_key[[lineage$target_key]], lineage$case_id)) {
      abort("%s does not identify exactly one captured assessment.", field)
    }
    assessment_record <- assessment_by_key[[lineage$target_key]]
    if (!identical(lineage$dictionary_role, assessment_record$role) ||
        !grepl("^[0-9a-f]{64}$", lineage$assessment_sha256) ||
        !identical(
          lineage$assessment_sha256,
          value_sha256(assessment_record$row)
        )) {
      abort(
        "%s does not cryptographically identify its assessment row.",
        field
      )
    }
    lineage_keys <- c(lineage_keys, lineage$target_key)

    if (identical(lineage$outcome, "provider")) {
      require_scalar_character(
        lineage$interaction_id,
        paste0(field, ".interaction_id")
      )
      require_scalar_character(
        lineage$interaction_stage,
        paste0(field, ".interaction_stage")
      )
      event <- interactions_by_id[[lineage$interaction_id]]
      if (is.null(event) ||
          !.capture_interaction_succeeded(event) ||
          !identical(event$stage, lineage$interaction_stage) ||
          !lineage$target_key %in% unlist(
            event$assessment_target_keys
          )) {
        abort(
          "%s does not resolve to a successful interaction for its target.",
          field
        )
      }
      if (!is.null(lineage$fallback_reason)) {
        abort("%s provider outcome cannot have a fallback reason.", field)
      }
      if (!is.character(lineage$provider_assessment_sha256) ||
          length(lineage$provider_assessment_sha256) != 1L ||
          !grepl(
            "^[0-9a-f]{64}$",
            lineage$provider_assessment_sha256
          )) {
        abort(
          "%s provider outcome must identify its provider assessment.",
          field
        )
      }
      if (isTRUE(verify_provider_payload)) {
        provider_assessment <- .capture_provider_assessment(
          event,
          lineage$dictionary_role,
          require_usable = TRUE
        )
        if (!identical(
          lineage$provider_assessment_sha256,
          value_sha256(provider_assessment)
        )) {
          abort(
            "%s is not derived from the recorded provider assessment.",
            field
          )
        }
      }
    } else {
      if (!identical(
        lineage$interaction_stage,
        "deterministic_fallback"
      ) || !non_empty(lineage$fallback_reason)) {
        abort(
          "%s deterministic fallback must record a reason and stage.",
          field
        )
      }
      if (!is.null(lineage$interaction_id)) {
        require_scalar_character(
          lineage$interaction_id,
          paste0(field, ".interaction_id")
        )
        event <- interactions_by_id[[lineage$interaction_id]]
        if (is.null(event) ||
            !lineage$target_key %in% unlist(event$target_keys)) {
          abort(
            "%s fallback interaction does not include its target.",
            field
          )
        }
      }
      if (!is.null(lineage$provider_assessment_sha256)) {
        abort(
          "%s deterministic fallback cannot identify a provider assessment.",
          field
        )
      }
    }
  }

  if (anyDuplicated(lineage_keys) > 0L ||
      !setequal(lineage_keys, assessment_keys)) {
    abort(
      paste0(
        "Capture assessment lineage must resolve every canonical ",
        "assessment target exactly once."
      )
    )
  }
  invisible(capture$assessment_lineage)
}

validate_capture <- function(capture,
                             cases,
                             contracts,
                             schema_path,
                             cases_path,
                             ontology_manifest_path,
                             require_reviewed = FALSE,
                             require_oracle_pass = TRUE,
                             capture_path = NULL,
                             verify_raw_lineage = require_reviewed) {
  require_object(capture, "capture")
  require_fields(
    capture,
    c(
      "schema_version", "run_id", "mode", "evidence_status", "review",
      "provenance", "execution_error", "interaction_events",
      "assessment_lineage", "cases",
      "evaluation"
    ),
    "capture"
  )
  if (!identical(capture$schema_version, contracts$capture_schema_version) ||
      !identical(capture$mode, "live")) {
    abort("Capture must be a Theme A live capture.")
  }
  safe_run_id(capture$run_id)
  if (!capture$evidence_status %in% c(
    "unreviewed_staging",
    "reviewed_sanitized"
  )) {
    abort("Capture evidence_status is not recognized.")
  }
  if (!is.null(capture$execution_error)) {
    abort("Capture records an execution_error and is not release evidence.")
  }

  require_object(capture$review, "capture.review")
  require_fields(
    capture$review,
    c(
      "status", "sanitized", "reviewed_by", "reviewed_at", "notes",
      "pre_sanitization_sha256", "raw_capture_reviewed",
      "raw_capture_safe_to_publish"
    ),
    "capture.review"
  )
  if (isTRUE(require_reviewed) && (
      !identical(capture$evidence_status, "reviewed_sanitized") ||
      !identical(capture$review$status, "reviewed") ||
      !isTRUE(capture$review$sanitized) ||
      !isTRUE(capture$review$raw_capture_reviewed) ||
      !isTRUE(capture$review$raw_capture_safe_to_publish) ||
      !non_empty(capture$review$reviewed_by) ||
      !non_empty(capture$review$reviewed_at) ||
      !non_empty(capture$review$pre_sanitization_sha256) ||
      !grepl(
        "^[0-9a-f]{64}$",
        capture$review$pre_sanitization_sha256
      )
  )) {
    abort(
      paste0(
        "Promotion requires an explicit human review record, sanitized=true, ",
        "raw-capture review and safe-to-publish attestations, and the ",
        "pre-sanitization capture SHA-256."
      )
    )
  }

  require_object(capture$provenance, "capture.provenance")
  require_fields(
    capture$provenance,
    c(
      "created_at", "completed_at", "git_sha", "git_branch",
      "git_tree", "git_dirty", "source_state_sha256", "package_version",
      "cases_fixture", "cases_fixture_sha256",
      "schema_fixture", "schema_fixture_sha256",
      "ontology_manifest_fixture", "ontology_manifest_fixture_sha256",
      "benchmark_script_sha256", "retrieval_mode", "data_classification",
      "provider",
      "configured_model", "resolved_models", "endpoint",
      "api_key_environment", "ontology_provenance"
    ),
    "capture.provenance"
  )
  for (name in c(
    "created_at", "completed_at", "git_sha", "git_tree",
    "source_state_sha256", "git_branch",
    "package_version", "cases_fixture", "cases_fixture_sha256",
    "schema_fixture", "schema_fixture_sha256",
    "ontology_manifest_fixture", "ontology_manifest_fixture_sha256",
    "benchmark_script_sha256", "retrieval_mode", "data_classification",
    "provider",
    "configured_model", "endpoint", "api_key_environment"
  )) {
    require_scalar_character(
      capture$provenance[[name]],
      paste0("capture.provenance.", name)
    )
  }
  require_scalar_logical(
    capture$provenance$git_dirty,
    "capture.provenance.git_dirty"
  )
  for (name in c(
    "git_sha", "git_tree", "source_state_sha256",
    "cases_fixture_sha256", "schema_fixture_sha256",
    "ontology_manifest_fixture_sha256", "benchmark_script_sha256"
  )) {
    expected_length <- if (name %in% c("git_sha", "git_tree")) 40L else 64L
    if (!grepl(
      sprintf("^[0-9a-f]{%d}$", expected_length),
      capture$provenance[[name]]
    )) {
      abort("capture.provenance.%s is not a valid pinned hash.", name)
    }
  }
  validate_git_source_provenance(capture$provenance)
  validate_git_artifact_provenance(
    capture$provenance,
    schema_path = schema_path,
    cases_path = cases_path,
    ontology_manifest_path = ontology_manifest_path
  )
  current_description <- read.dcf(file.path(repo_root, "DESCRIPTION"))
  if (!identical(
    capture$provenance$package_version,
    unname(current_description[1L, "Version"])
  )) {
    abort("Capture package version does not match the current package source.")
  }
  if (!identical(capture$provenance$retrieval_mode, "frozen_fixture")) {
    abort("Capture retrieval_mode must be frozen_fixture.")
  }
  if (!identical(
    capture$provenance$data_classification,
    "synthetic_theme_a_fixture"
  )) {
    abort(
      "Capture data_classification must be synthetic_theme_a_fixture."
    )
  }
  if (!identical(
    capture$provenance$endpoint,
    normalise_endpoint(capture$provenance$endpoint)
  )) {
    abort("Capture endpoint must be normalized.")
  }
  resolved_models <- unlist(capture$provenance$resolved_models)
  if (length(resolved_models) != 1L ||
      !identical(resolved_models[[1L]], capture$provenance$configured_model)) {
    abort("Capture must prove one resolved model identical to configured_model.")
  }
  validate_ontology_provenance(
    capture$provenance$ontology_provenance,
    "capture.provenance.ontology_provenance"
  )
  if (!identical(
    capture$provenance$ontology_provenance,
    cases$ontology_provenance
  )) {
    abort("Capture ontology provenance does not match the pinned case fixture.")
  }
  if (!identical(
    capture$provenance$cases_fixture_sha256,
    file_sha256(cases_path)
  )) {
    abort("Capture cases fixture SHA-256 does not match the current fixture.")
  }
  if (!identical(
    capture$provenance$schema_fixture_sha256,
    file_sha256(schema_path)
  )) {
    abort("Capture schema fixture SHA-256 does not match the current fixture.")
  }
  if (!identical(
    capture$provenance$ontology_manifest_fixture_sha256,
    file_sha256(ontology_manifest_path)
  )) {
    abort(
      "Capture ontology-manifest SHA-256 does not match the current fixture."
    )
  }
  if (!identical(
    capture$provenance$benchmark_script_sha256,
    file_sha256(script_path)
  )) {
    abort("Capture benchmark-script SHA-256 does not match the current script.")
  }

  require_array(capture$interaction_events, "capture.interaction_events")
  if (length(capture$interaction_events) == 0L) {
    abort("Capture must contain at least one recorded provider interaction.")
  }
  successful_interactions <- 0L
  interaction_ids <- character()
  for (i in seq_along(capture$interaction_events)) {
    event <- capture$interaction_events[[i]]
    event_field <- sprintf("capture.interaction_events[%d]", i)
    require_object(event, event_field)
    require_fields(
      event,
      c(
        "interaction_id", "event_type", "stage", "bundle_key",
        "target_keys", "assessment_target_keys", "started_at",
        "provider", "configured_model",
        "resolved_model", "endpoint", "messages", "response_status",
        "raw_response", "request_sha256", "response_sha256",
        "provider_response_id", "error", "elapsed_seconds"
      ),
      event_field
    )
    require_scalar_character(
      event$interaction_id,
      paste0(event_field, ".interaction_id")
    )
    interaction_ids <- c(interaction_ids, event$interaction_id)
    if (!is.character(event$request_sha256) ||
        length(event$request_sha256) != 1L ||
        !grepl("^[0-9a-f]{64}$", event$request_sha256)) {
      abort("%s.request_sha256 is invalid.", event_field)
    }
    require_scalar_character(
      event$stage,
      paste0(event_field, ".stage")
    )
    if (!event$stage %in% unlist(contracts$capture_interaction_stages)) {
      abort("%s.stage is not recognized.", event_field)
    }
    if (!is.null(event$bundle_key)) {
      require_scalar_character(
        event$bundle_key,
        paste0(event_field, ".bundle_key")
      )
    }
    require_array(
      event$target_keys,
      paste0(event_field, ".target_keys")
    )
    require_array(
      event$assessment_target_keys,
      paste0(event_field, ".assessment_target_keys")
    )
    if (length(event$target_keys) == 0L) {
      abort("%s must identify at least one target key.", event_field)
    }
    if (!all(unlist(event$assessment_target_keys) %in%
      unlist(event$target_keys))) {
      abort(
        "%s assessment targets must be a subset of request targets.",
        event_field
      )
    }
    if (!identical(event$provider, capture$provenance$provider) ||
        !identical(
          event$configured_model,
          capture$provenance$configured_model
        ) ||
        !identical(
          normalise_endpoint(event$endpoint),
          capture$provenance$endpoint
        )) {
      abort("%s does not match capture provider/model provenance.", event_field)
    }
    if (.capture_interaction_succeeded(event)) {
      successful_interactions <- successful_interactions + 1L
      if (!identical(
        event$resolved_model,
        capture$provenance$configured_model
      ) || is.null(event$raw_response) ||
        !is.character(event$response_sha256) ||
        length(event$response_sha256) != 1L ||
        !grepl("^[0-9a-f]{64}$", event$response_sha256) ||
        !non_empty(event$provider_response_id)) {
        abort("%s does not prove the exact resolved model and response.", event_field)
      }
    }
    require_array(event$messages, paste0(event_field, ".messages"))
    if (identical(capture$evidence_status, "unreviewed_staging")) {
      if (!identical(event$request_sha256, value_sha256(event$messages))) {
        abort("%s request hash does not match its raw messages.", event_field)
      }
      if (!is.null(event$raw_response) &&
          (!identical(
            event$response_sha256,
            value_sha256(event$raw_response)
          ) ||
            !identical(
              event$provider_response_id,
              event$raw_response$id %||% NULL
            ))) {
        abort("%s response identity does not match its raw response.", event_field)
      }
    }
  }
  if (anyDuplicated(interaction_ids) > 0L) {
    abort("Capture interaction_id values must be unique.")
  }
  if (successful_interactions == 0L) {
    abort("Capture contains no successful provider interaction.")
  }

  validate_capture_cases(capture$cases, cases, contracts, "capture.cases")
  validate_assessment_lineage(capture, contracts)
  recomputed <- evaluate_oracles(
    cases,
    list(cases = capture$cases)
  )
  if (!identical(recomputed, capture$evaluation)) {
    abort("Capture evaluation does not match recomputed semantic oracles.")
  }
  if (isTRUE(require_oracle_pass) && !identical(recomputed$status, "pass")) {
    abort("Capture does not pass the Theme A semantic oracles.")
  }
  if (isTRUE(verify_raw_lineage)) {
    validate_review_lineage(capture, capture_path, contracts)
  }
  invisible(capture)
}

evaluation_from_file <- function(path,
                                 cases,
                                 contracts,
                                 schema_path,
                                 cases_path,
                                 ontology_manifest_path) {
  value <- read_json(path, "comparison input")
  if (identical(value$schema_version, contracts$replay_schema_version)) {
    validate_replay(value, cases, contracts)
    return(list(
      input_type = "replay",
      evaluation = evaluate_oracles(cases, value),
      cases = value$cases
    ))
  }
  if (identical(value$schema_version, contracts$capture_schema_version)) {
    validate_capture(
      value,
      cases,
      contracts,
      schema_path = schema_path,
      cases_path = cases_path,
      ontology_manifest_path = ontology_manifest_path,
      require_reviewed = identical(
        value$evidence_status,
        "reviewed_sanitized"
      ),
      require_oracle_pass = FALSE,
      capture_path = path
    )
    return(list(
      input_type = "capture",
      evaluation = value$evaluation,
      cases = value$cases
    ))
  }
  abort(
    paste0(
      "Comparison input '%s' must be a validated Theme A replay or capture; ",
      "bare evaluation summaries do not contain fixture provenance or per-artifact evidence."
    ),
    path
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
  sort(unique(identities))
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
  sort(unique(identities))
}

.capture_provider_run_fingerprint <- function(capture) {
  successful <- Filter(
    .capture_interaction_succeeded,
    capture$interaction_events
  )
  value_sha256(lapply(successful, function(event) {
    list(
      provider_response_id = event$provider_response_id,
      response_sha256 = event$response_sha256
    )
  }))
}

compute_cohort_gate <- function(captures,
                                capture_hashes,
                                expected_provider,
                                expected_model,
                                cases) {
  if (length(captures) != 3L || length(capture_hashes) != 3L) {
    abort("A Theme A cohort gate requires exactly three captures.")
  }
  run_ids <- vapply(captures, `[[`, character(1), "run_id")
  if (anyDuplicated(run_ids) > 0L ||
      anyDuplicated(capture_hashes) > 0L) {
    abort(
      "A Theme A cohort gate requires three distinct run IDs and captures."
    )
  }

  providers <- unique(vapply(
    captures,
    function(capture) capture$provenance$provider,
    character(1)
  ))
  models <- unique(vapply(
    captures,
    function(capture) capture$provenance$configured_model,
    character(1)
  ))
  resolved <- unique(unlist(lapply(
    captures,
    function(capture) capture$provenance$resolved_models
  )))
  approved_provider_model <- length(providers) == 1L &&
    length(models) == 1L &&
    length(resolved) == 1L &&
    identical(providers[[1L]], expected_provider) &&
    identical(models[[1L]], expected_model) &&
    identical(models[[1L]], resolved[[1L]])

  exact_fields <- c(
    "git_sha",
    "git_tree",
    "source_state_sha256",
    "package_version",
    "cases_fixture_sha256",
    "schema_fixture_sha256",
    "ontology_manifest_fixture_sha256",
    "benchmark_script_sha256",
    "retrieval_mode",
    "data_classification",
    "endpoint"
  )
  provenance_values <- stats::setNames(lapply(exact_fields, function(field) {
    unique(vapply(
      captures,
      function(capture) capture$provenance[[field]],
      character(1)
    ))
  }), exact_fields)
  exact_source_cohort <- all(vapply(
    provenance_values,
    function(values) length(values) == 1L,
    logical(1)
  )) && all(vapply(
    captures,
    function(capture) identical(capture$provenance$git_dirty, FALSE),
    logical(1)
  ))
  exact_cohort <- approved_provider_model && exact_source_cohort
  provider_run_fingerprints <- vapply(
    captures,
    .capture_provider_run_fingerprint,
    character(1)
  )
  independent_provider_runs <-
    anyDuplicated(provider_run_fingerprints) == 0L

  blocking_ids <- vapply(
    Filter(function(case) isTRUE(case$blocking), cases$cases),
    `[[`,
    character(1),
    "case_id"
  )
  critical_results <- lapply(blocking_ids, function(case_id) {
    pass_count <- sum(vapply(captures, function(capture) {
      result <- Filter(
        function(item) identical(item$case_id, case_id),
        capture$evaluation$cases
      )
      length(result) == 1L && isTRUE(result[[1L]]$passed)
    }, logical(1)))
    list(
      case_id = case_id,
      pass_count = pass_count,
      required_pass_count = 2L,
      passed = pass_count >= 2L
    )
  })

  zero_forbidden <- all(vapply(captures, function(capture) {
    identical(
      as.integer(capture$evaluation$metrics$forbidden_violations),
      0L
    ) &&
      identical(
        as.integer(capture$evaluation$metrics$false_acceptance_count),
        0L
      )
  }, logical(1)))
  zero_false_prefills <- all(vapply(captures, function(capture) {
    identical(
      as.integer(capture$evaluation$metrics$false_prefill_count),
      0L
    )
  }, logical(1)))
  critical_pass <- all(vapply(
    critical_results,
    `[[`,
    logical(1),
    "passed"
  ))
  passed <- exact_cohort &&
    independent_provider_runs &&
    critical_pass &&
    zero_forbidden &&
    zero_false_prefills

  list(
    schema_version = "theme-a-live-cohort-gate-v1",
    status = if (passed) "pass" else "blocked",
    approved_provider = expected_provider,
    approved_model = expected_model,
    provider = if (length(providers) == 1L) providers[[1L]] else providers,
    configured_model = if (length(models) == 1L) models[[1L]] else models,
    resolved_model = if (length(resolved) == 1L) resolved[[1L]] else resolved,
    run_ids = as.list(run_ids),
    captures = lapply(seq_along(captures), function(i) {
      list(
        run_id = run_ids[[i]],
        capture_sha256 = capture_hashes[[i]],
        evidence_status = captures[[i]]$evidence_status,
        evaluation_status = captures[[i]]$evaluation$status
      )
    }),
    cohort_provenance = lapply(provenance_values, function(values) {
      if (length(values) == 1L) values[[1L]] else as.list(values)
    }),
    approved_provider_model = approved_provider_model,
    exact_source_cohort = exact_source_cohort,
    exact_provider_model_cohort = exact_cohort,
    provider_run_fingerprints = as.list(provider_run_fingerprints),
    independent_provider_runs = independent_provider_runs,
    critical_cases = critical_results,
    zero_forbidden_acceptances = zero_forbidden,
    zero_false_prefills = zero_false_prefills
  )
}

run_cohort_gate <- function(options, cases, contracts) {
  expected_provider <- trimws(options$expected_provider %||% "")
  expected_model <- trimws(options$expected_model %||% "")
  if (!nzchar(expected_provider) || !nzchar(expected_model)) {
    abort(
      paste0(
        "The live cohort gate requires explicit --expected-provider and ",
        "--expected-model approval values."
      )
    )
  }
  paths <- trimws(strsplit(options$cohort, ",", fixed = TRUE)[[1L]])
  paths <- paths[nzchar(paths)]
  if (length(paths) != 3L) {
    abort("The live release cohort must contain exactly three capture paths.")
  }

  captures <- lapply(paths, function(path) {
    capture <- read_json(path, "cohort capture")
    validate_capture(
      capture,
      cases,
      contracts,
      schema_path = options$schema,
      cases_path = options$cases,
      ontology_manifest_path = options$ontology_manifest,
      require_reviewed = TRUE,
      require_oracle_pass = FALSE,
      capture_path = path
    )
    capture
  })
  gate <- compute_cohort_gate(
    captures = captures,
    capture_hashes = vapply(paths, file_sha256, character(1)),
    expected_provider = expected_provider,
    expected_model = expected_model,
    cases = cases
  )

  cat(sprintf("Theme A live cohort gate: %s\n", toupper(gate$status)))
  cat(sprintf(
    paste0(
      "Approved provider/model: %s; exact source cohort: %s; ",
      "independent provider runs: %s; forbidden acceptances zero: %s; ",
      "false prefills zero: %s\n"
    ),
    gate$approved_provider_model,
    gate$exact_source_cohort,
    gate$independent_provider_runs,
    gate$zero_forbidden_acceptances,
    gate$zero_false_prefills
  ))
  for (result in gate$critical_cases) {
    cat(sprintf(
      "%s: %d/3 runs passed (required 2)\n",
      result$case_id,
      result$pass_count
    ))
  }
  if (!is.null(options$output)) {
    write_json(gate, options$output)
  }
  if (!identical(gate$status, "pass")) {
    abort("Theme A live cohort does not satisfy the release gate.")
  }
  invisible(gate)
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

  if (!is.null(options$cohort)) {
    if (!is.null(options$baseline) || !is.null(options$candidate)) {
      abort("Use either --cohort or --baseline/--candidate, not both.")
    }
    return(run_cohort_gate(options, cases, contracts))
  }
  if (is.null(options$baseline) || is.null(options$candidate)) {
    abort("Compare mode requires --baseline=FILE and --candidate=FILE.")
  }
  baseline <- evaluation_from_file(
    options$baseline,
    cases,
    contracts,
    schema_path = options$schema,
    cases_path = options$cases,
    ontology_manifest_path = options$ontology_manifest
  )
  candidate <- evaluation_from_file(
    options$candidate,
    cases,
    contracts,
    schema_path = options$schema,
    cases_path = options$cases,
    ontology_manifest_path = options$ontology_manifest
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
      "latency",
      "interaction_events"
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

path_is_within <- function(path, parent) {
  path <- normalizePath(path, winslash = "/", mustWork = TRUE)
  parent <- normalizePath(parent, winslash = "/", mustWork = TRUE)
  identical(path, parent) || startsWith(path, paste0(parent, "/"))
}

contains_secret_material <- function(value, key = "") {
  secret_keys <- c(
    "api_key", "authorization", "access_token", "refresh_token",
    "client_secret", "secret_key"
  )
  if (tolower(key) %in% secret_keys && !is.null(value)) {
    return(TRUE)
  }
  if (is.list(value)) {
    child_names <- names(value) %||% rep("", length(value))
    return(any(vapply(seq_along(value), function(i) {
      contains_secret_material(value[[i]], child_names[[i]])
    }, logical(1))))
  }
  if (is.character(value)) {
    return(any(grepl(
      "(?i)(Bearer\\s+[A-Za-z0-9._-]{12,}|sk-[A-Za-z0-9_-]{12,})",
      value,
      perl = TRUE
    )))
  }
  FALSE
}

promote_immutable_file <- function(source_path, destination_stem) {
  source_hash <- file_sha256(source_path)
  destination <- file.path(
    theme_a_paths$promoted,
    paste0(destination_stem, "-", source_hash, ".json")
  )
  checksum_path <- paste0(destination, ".sha256")
  if (file.exists(destination) || file.exists(checksum_path)) {
    abort("Promoted evidence is immutable and already exists: %s", destination)
  }
  dir.create(dirname(destination), recursive = TRUE, showWarnings = FALSE)
  copied <- file.copy(source_path, destination, overwrite = FALSE)
  if (!isTRUE(copied)) {
    abort("Could not promote evidence to %s.", destination)
  }
  destination_hash <- file_sha256(destination)
  if (!identical(source_hash, destination_hash)) {
    unlink(destination)
    abort("Promoted evidence hash does not match the reviewed staging source.")
  }
  writeLines(
    paste(destination_hash, basename(destination)),
    checksum_path,
    useBytes = TRUE
  )
  Sys.chmod(c(destination, checksum_path), mode = "0444")
  list(
    destination = destination,
    checksum_path = checksum_path,
    sha256 = destination_hash
  )
}

canonical_evidence_json <- function(value) {
  as.character(jsonlite::toJSON(
    value,
    auto_unbox = TRUE,
    null = "null",
    na = "null",
    digits = NA
  ))
}

validate_cohort_manifest <- function(gate,
                                     cases,
                                     contracts,
                                     schema_path,
                                     cases_path,
                                     ontology_manifest_path) {
  require_object(gate, "cohort manifest")
  require_fields(
    gate,
    c(
      "schema_version", "status", "approved_provider", "approved_model",
      "provider", "configured_model", "resolved_model", "run_ids",
      "captures", "cohort_provenance", "approved_provider_model",
      "exact_source_cohort", "exact_provider_model_cohort",
      "provider_run_fingerprints", "independent_provider_runs",
      "critical_cases", "zero_forbidden_acceptances",
      "zero_false_prefills"
    ),
    "cohort manifest"
  )
  require_array(gate$run_ids, "cohort manifest.run_ids")
  require_array(gate$captures, "cohort manifest.captures")
  require_array(
    gate$provider_run_fingerprints,
    "cohort manifest.provider_run_fingerprints"
  )
  require_array(gate$critical_cases, "cohort manifest.critical_cases")
  if (length(gate$run_ids) != 3L ||
      length(gate$captures) != 3L ||
      anyDuplicated(unlist(gate$run_ids)) > 0L) {
    abort("A promoted cohort manifest must identify three distinct runs.")
  }
  if (length(gate$provider_run_fingerprints) != 3L ||
      anyDuplicated(unlist(gate$provider_run_fingerprints)) > 0L ||
      !isTRUE(gate$independent_provider_runs)) {
    abort(
      "A promoted cohort manifest must prove three independent provider runs."
    )
  }
  captures <- vector("list", length(gate$captures))
  capture_hashes <- character(length(gate$captures))
  capture_run_ids <- character(length(gate$captures))
  for (i in seq_along(gate$captures)) {
    capture_ref <- gate$captures[[i]]
    field <- sprintf("cohort manifest.captures[%d]", i)
    require_object(capture_ref, field)
    require_fields(
      capture_ref,
      c(
        "run_id", "capture_sha256", "evidence_status",
        "evaluation_status"
      ),
      field
    )
    if (!grepl("^[0-9a-f]{64}$", capture_ref$capture_sha256)) {
      abort("%s.capture_sha256 is invalid.", field)
    }
    promoted_capture <- file.path(
      theme_a_paths$promoted,
      paste0(
        safe_run_id(capture_ref$run_id),
        "-",
        capture_ref$capture_sha256,
        ".json"
      )
    )
    if (!file.exists(promoted_capture) ||
        !identical(
          file_sha256(promoted_capture),
          capture_ref$capture_sha256
        )) {
      abort(
        "%s does not resolve to an already promoted reviewed capture.",
        field
      )
    }
    capture <- read_json(promoted_capture, "promoted cohort capture")
    validate_capture(
      capture,
      cases,
      contracts,
      schema_path = schema_path,
      cases_path = cases_path,
      ontology_manifest_path = ontology_manifest_path,
      require_reviewed = TRUE,
      require_oracle_pass = FALSE,
      capture_path = promoted_capture,
      verify_raw_lineage = TRUE
    )
    captures[[i]] <- capture
    capture_hashes[[i]] <- capture_ref$capture_sha256
    capture_run_ids[[i]] <- capture$run_id
  }
  if (anyDuplicated(capture_hashes) > 0L ||
      !identical(unlist(gate$run_ids), capture_run_ids) ||
      !identical(
        vapply(gate$captures, `[[`, character(1), "run_id"),
        capture_run_ids
      )) {
    abort(
      paste0(
        "Cohort manifest run IDs and capture references must identify ",
        "the same three distinct promoted captures."
      )
    )
  }

  recomputed <- compute_cohort_gate(
    captures = captures,
    capture_hashes = capture_hashes,
    expected_provider = gate$approved_provider,
    expected_model = gate$approved_model,
    cases = cases
  )
  if (!identical(
    canonical_evidence_json(recomputed),
    canonical_evidence_json(gate)
  )) {
    abort(
      paste0(
        "Cohort manifest does not match the gate recomputed from its ",
        "validated promoted captures."
      )
    )
  }
  if (!identical(recomputed$status, "pass")) {
    abort("Only a recomputed passing Theme A cohort may be promoted.")
  }
  invisible(gate)
}

run_promote <- function(options) {
  supplied <- c(
    capture = !is.null(options$capture),
    cohort_manifest = !is.null(options$cohort_manifest)
  )
  if (sum(supplied) != 1L) {
    abort(
      "Promote mode requires exactly one of --capture=FILE or --cohort-manifest=FILE."
    )
  }
  if (!dir.exists(theme_a_paths$staging)) {
    abort("Theme A staging directory does not exist: %s", theme_a_paths$staging)
  }
  source_path <- normalizePath(
    options$capture %||% options$cohort_manifest,
    winslash = "/",
    mustWork = TRUE
  )
  if (!path_is_within(source_path, theme_a_paths$staging)) {
    abort("Only evidence under artifacts/theme-a/ may be promoted.")
  }

  schema <- read_json(options$schema, "fixture schema")
  contracts <- schema_contracts(schema)
  cases <- read_json(options$cases, "cases fixture")
  ontology_manifest <- read_json(
    options$ontology_manifest,
    "ontology manifest"
  )
  validate_cases(cases, contracts, ontology_manifest)

  if (!is.null(options$cohort_manifest)) {
    gate <- read_json(source_path, "staging cohort manifest")
    validate_cohort_manifest(
      gate,
      cases,
      contracts,
      schema_path = options$schema,
      cases_path = options$cases,
      ontology_manifest_path = options$ontology_manifest
    )
    if (contains_secret_material(gate)) {
      abort("Cohort manifest appears to contain credential material.")
    }
    promoted <- promote_immutable_file(source_path, "cohort")
    cat(sprintf(
      "Promoted Theme A cohort manifest: %s\nSHA-256: %s\n",
      promoted$destination,
      promoted$sha256
    ))
    return(invisible(promoted$destination))
  }

  capture <- read_json(source_path, "staging capture")
  validate_capture(
    capture,
    cases,
    contracts,
    schema_path = options$schema,
    cases_path = options$cases,
    ontology_manifest_path = options$ontology_manifest,
    require_reviewed = TRUE,
    require_oracle_pass = FALSE,
    capture_path = source_path
  )
  if (contains_secret_material(capture)) {
    abort("Capture appears to contain credential material; sanitize it before promotion.")
  }

  run_id <- safe_run_id(capture$run_id)
  raw_path <- file.path(dirname(source_path), "capture.raw.json")
  raw_capture <- read_json(raw_path, "raw staging capture")
  if (contains_secret_material(raw_capture)) {
    abort(
      "Raw capture appears to contain credential material and cannot be promoted."
    )
  }
  promoted_raw <- promote_immutable_file(
    raw_path,
    paste0(run_id, "-raw")
  )
  promoted <- promote_immutable_file(source_path, run_id)
  cat(sprintf(
    paste0(
      "Promoted immutable raw capture: %s\nRaw SHA-256: %s\n",
      "Promoted reviewed and sanitized capture: %s\nSHA-256: %s\n"
    ),
    promoted_raw$destination,
    promoted_raw$sha256,
    promoted$destination,
    promoted$sha256
  ))
  invisible(promoted$destination)
}

run_benchmark_mode <- function(options) {
  if (isTRUE(options$help)) {
    cat(usage(), "\n")
    return(invisible(TRUE))
  }

  switch(
    options$mode,
    replay = run_replay(options),
    live = run_live(options),
    compare = run_compare(options),
    promote = run_promote(options)
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
