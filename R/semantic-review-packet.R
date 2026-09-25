# The semantic review packet (S16 step 1, hub item B-326).
#
# Brett ruled on 2026-09-25 (hub Q67) that the model call leaves the package:
# judgement runs in the user's harness, and the seam is a file, because a
# harness cannot hand an R closure to a package process it did not start. The
# packet written here is what the package already computes for a review --
# the targets in the frozen 19-column row, each target's ranked shortlist by
# index, the bundle groups with their current slots, the scored context
# excerpts, the review instructions, the decision vocabulary and the
# 30-column assessment schema -- rendered to deterministic bytes. The
# assessment file a harness writes back is read by
# `ingest_semantic_assessments()` (R/semantic-review-ingest.R). The design is
# `knowledge/plans/2026-09-25-s16-review-packet-contract.md`, sections 2, 5
# and 7; the file contract is shared with metasalmonpy (its half is B-327)
# and the conformance fixtures under tests/testthat/fixtures/semantic-review/
# are the same cases in both packages.

.ms_semantic_review_packet_version <- function() {
  "semantic-review-packet/1.0"
}

.ms_semantic_review_decision_vocabulary <- function() {
  c("accept", "review", "retry_search", "request_new_term", "reject_shortlist")
}

.ms_semantic_review_decision_aliases <- function() {
  c(propose_new_term = "request_new_term")
}

# Where the session's files live under `review_dir`. These are the paths
# section 10 of the S16 execplan names (decision 2).
.ms_semantic_review_file <- function(review_dir, what, pass = 1L) {
  name <- switch(
    what,
    packet = if (pass == 1L) "semantic-review-packet.json" else "semantic-review-packet-pass-2.json",
    assessments = paste0("semantic-assessments-pass-", pass, ".csv"),
    record = "semantic-llm-assessments.csv",
    findings = "semantic-validator-findings.csv",
    cli::cli_abort("Unknown semantic review file kind {.val {what}}.")
  )
  file.path(review_dir, name)
}

.ms_semantic_review_session_files <- function(review_dir) {
  c(
    .ms_semantic_review_file(review_dir, "packet", 1L),
    .ms_semantic_review_file(review_dir, "packet", 2L),
    .ms_semantic_review_file(review_dir, "assessments", 1L),
    .ms_semantic_review_file(review_dir, "assessments", 2L),
    .ms_semantic_review_file(review_dir, "record"),
    .ms_semantic_review_file(review_dir, "findings")
  )
}

.ms_semantic_review_instructions <- function() {
  path <- system.file("extdata", "semantic-review", "semantic-review-instructions-v1.txt", package = "metasalmon")
  if (!nzchar(path) || !file.exists(path)) {
    cli::cli_abort("The vendored semantic review instructions are missing from the installed package.")
  }
  .ms_read_text_utf8(path)
}

.ms_semantic_review_schema_path <- function() {
  path <- system.file("extdata", "semantic-review", "semantic-review-packet-v1.schema.json", package = "metasalmon")
  if (!nzchar(path) || !file.exists(path)) {
    cli::cli_abort("The vendored semantic review packet schema is missing from the installed package.")
  }
  path
}

# The 30 assessment columns with an owner and a requiredness each (execplan
# section 3.2). `required` is one of "always", "accept", "retry_search" and
# "never"; a harness reads it as "on which decision must I fill this".
.ms_semantic_review_output_columns <- function() {
  cols <- .ms_llm_assessment_cols()
  owner <- stats::setNames(rep("harness", length(cols)), cols)
  required <- stats::setNames(rep("never", length(cols)), cols)
  required[cols[1:13]] <- "always"
  required["llm_selected_candidate_index"] <- "accept"
  required["llm_selected_iri"] <- "accept"
  required["llm_retry_query"] <- "retry_search"
  package_owned <- c(
    "llm_selected_label", "llm_context_sources", "llm_exploration_used",
    "llm_exploration_queries", "llm_exploration_candidate_gain",
    "llm_escalated_from", "llm_retry_query_rejection_reason"
  )
  owner[package_owned] <- "package"
  owner["llm_error"] <- "harness_or_package"
  lapply(cols, function(col) {
    list(name = col, owner = unname(owner[[col]]), required = unname(required[[col]]))
  })
}

.ms_semantic_review_package_owned_columns <- function() {
  vapply(
    Filter(function(col) identical(col$owner, "package"), .ms_semantic_review_output_columns()),
    `[[`, character(1), "name"
  )
}

# -----------------------------------------------------------------------------
# Input resolution
# -----------------------------------------------------------------------------

# One of two input shapes: a package path (the queue `review_semantics()` would
# show, re-retrieved at depth `top_n`) or an in-memory dictionary carrying
# `semantic_targets` and `semantic_suggestions` (no retrieval). An artifact
# list in the `create_sdp()` shape counts as in-memory input through its
# `dict`.
.ms_semantic_review_input <- function(x, review_dir, arg = "x") {
  if (is.character(x) && length(x) == 1L && !is.na(x)) {
    if (!dir.exists(x)) {
      cli::cli_abort("Package directory {.path {x}} does not exist.")
    }
    return(list(
      kind = "package",
      path = x,
      review_dir = review_dir %||% file.path(x, "review")
    ))
  }
  dict <- if (inherits(x, "data.frame")) {
    x
  } else if (is.list(x) && inherits(x$dict, "data.frame")) {
    x$dict
  } else {
    NULL
  }
  if (is.null(dict)) {
    cli::cli_abort(c(
      "{.arg {arg}} must be a package path or a dictionary carrying {.code semantic_targets} and {.code semantic_suggestions}.",
      "i" = "Pass the directory {.fn create_sdp} wrote, or the dictionary {.fn suggest_semantics} returned."
    ))
  }
  if (is.null(review_dir)) {
    cli::cli_abort(c(
      "{.arg review_dir} is required for in-memory input.",
      "i" = "The packet and the harness's answers need a directory that outlives this call."
    ))
  }
  list(kind = "memory", dict = tibble::as_tibble(dict), object = x, review_dir = review_dir)
}

# The current value of each target's slot, read the way the review console
# reads it: the metadata frame the target writes into, matched on its keys.
.ms_semantic_review_current_values <- function(targets, frames) {
  vapply(seq_len(nrow(targets)), function(i) {
    row <- targets[i, , drop = FALSE]
    target_file <- .ms_scalar_text(row$target_sdp_file)
    target_field <- .ms_scalar_text(row$target_sdp_field)
    frame <- frames[[target_file]]
    keys <- .ms_review_target_keys(target_file)
    if (is.null(frame) || is.null(keys) || !target_field %in% names(frame)) {
      return(NA_character_)
    }
    hits <- .ms_review_match_rows(frame, row, keys)
    if (length(hits) != 1L) {
      return(NA_character_)
    }
    value <- as.character(frame[[target_field]][[hits]])
    if (is.na(value)) "" else value
  }, character(1))
}

# A data resource is opened only when `tables.csv` names it with a plain
# relative path inside the package: no absolute path, no drive letter, no
# `.` or `..` component, and no symbolic link anywhere in the path. A row
# that fails the check is skipped with a warning naming it, never followed;
# `tables.csv` is external text, and a package written by someone else could
# otherwise point the reader at any file the analyst can open (Codex security
# review on pull request #194). The package root itself is checked by
# `.ms_assert_managed_path_contained()` before any packet is written.
.ms_semantic_review_contained_resource <- function(root, file_name) {
  text <- .ms_scalar_text(file_name)
  if (!nzchar(text)) {
    return(NULL)
  }
  normalized <- gsub("\\\\", "/", text)
  if (startsWith(normalized, "/") || grepl("^[A-Za-z]:", normalized)) {
    return(NULL)
  }
  parts <- strsplit(normalized, "/", fixed = TRUE)[[1]]
  parts <- parts[nzchar(parts)]
  if (length(parts) == 0L || any(parts %in% c(".", ".."))) {
    return(NULL)
  }
  current <- root
  for (part in parts) {
    current <- file.path(current, part)
    link <- Sys.readlink(current)
    if (length(link) == 1L && !is.na(link) && nzchar(link)) {
      return(NULL)
    }
  }
  if (!file.exists(current) || dir.exists(current)) {
    return(NULL)
  }
  current
}

.ms_semantic_review_package_resources <- function(path, table_meta, dictionary) {
  resources <- list()
  table_meta <- tibble::as_tibble(table_meta)
  if (nrow(table_meta) == 0L || !all(c("table_id", "file_name") %in% names(table_meta))) {
    return(resources)
  }
  refused <- character()
  for (i in seq_len(nrow(table_meta))) {
    table_id <- .ms_scalar_text(table_meta$table_id[[i]])
    file_name <- .ms_scalar_text(table_meta$file_name[[i]])
    if (!nzchar(table_id) || !nzchar(file_name)) {
      next
    }
    contained <- .ms_semantic_review_contained_resource(path, file_name)
    if (is.null(contained)) {
      refused <- c(refused, file_name)
      next
    }
    table_dict <- dictionary[!is.na(dictionary$table_id) & dictionary$table_id == table_id, , drop = FALSE]
    resources[[table_id]] <- .ms_read_resource_csv(contained, table_dict)
  }
  if (length(refused) > 0L) {
    cli::cli_warn(c(
      "Some data resources named in {.file tables.csv} are not plain files inside the package and were not read:",
      .ms_cli_bullets(refused, "*"),
      "i" = "Blank slots are still recovered from the metadata; code-level slots of these tables may be missed."
    ))
  }
  resources
}

# Blank slots with no candidates, recovered by discovery. `semantic_suggestions.csv`
# holds only candidate rows and the package does not persist its targets, so a
# slot `create_sdp()` left blank because retrieval found nothing is invisible
# to the queue. A blank slot is exactly what discovery sees, so the same
# discovery `create_sdp()` ran is run again over the package's own frames and
# restricted to the writable IRI slots that are blank (not `REVIEW:`-marked),
# have no suggestion row and no recorded decision. The one thing that cannot
# be recovered is the code scope the caller chose at creation, because nothing
# records it: the packet records the scope it used, and a code-level slot
# outside it is reported as not covered rather than silently dropped.
.ms_semantic_review_blank_slots <- function(path, frames, suggestions, code_scope) {
  dict <- frames[["column_dictionary.csv"]]
  if (is.null(dict) || nrow(dict) == 0L) {
    return(list(targets = tibble::tibble(), not_covered = tibble::tibble()))
  }
  # The package's own frames, normalized the way `create_sdp()` saw them, and
  # its data resources read only through the containment check below: a
  # `tables.csv` row names its file, and a file name is external text.
  dict <- .ms_normalize_dictionary(dict)
  if ("required" %in% names(dict)) {
    dict$required <- .ms_parse_logical(dict$required)
  }
  codes <- .ms_normalize_codes(frames[["codes.csv"]] %||% tibble::tibble())
  table_meta <- .ms_normalize_table_meta(frames[["tables.csv"]] %||% tibble::tibble())
  dataset_path <- .ms_locate_metadata_file(path, "dataset.csv")
  dataset_meta <- if (length(dataset_path) == 1L && !is.na(dataset_path) && file.exists(dataset_path) && !dir.exists(dataset_path)) {
    .ms_normalize_dataset_meta(tibble::as_tibble(.ms_read_metadata_csv(dataset_path)))
  } else {
    tibble::tibble()
  }
  resources <- .ms_semantic_review_package_resources(path, table_meta, dict)
  dataset_id <- .ms_semantic_trim_string(dataset_meta$dataset_id) %||% .ms_semantic_trim_string(dict$dataset_id)
  known_slots <- if (!is.null(suggestions) && nrow(suggestions) > 0L) {
    unique(.ms_review_slot_id(.ms_semantic_add_missing_cols(
      suggestions, c("target_sdp_file", "target_row_key", "target_sdp_field")
    )))
  } else {
    character()
  }

  discover <- function(scope) {
    scoped_codes <- if (nrow(tibble::as_tibble(codes)) == 0L) {
      tibble::tibble()
    } else {
      .ms_select_semantic_seed_codes(
        codes = codes,
        resources = resources,
        scope = scope,
        dataset_id = dataset_id
      )
    }
    targets <- .ms_semantic_discover_targets(
      dict = dict,
      codes = scoped_codes,
      table_meta = table_meta,
      dataset_meta = dataset_meta,
      resource_lookup = if (length(resources) > 0L) resources else NULL,
      default_df = if (length(resources) > 0L) resources[[1L]] else NULL
    )
    targets <- tibble::as_tibble(targets)
    if (nrow(targets) == 0L) {
      return(targets)
    }
    targets <- .ms_semantic_add_missing_cols(targets, .ms_semantic_target_cols())
    targets <- targets[, .ms_semantic_target_cols(), drop = FALSE]
    targets$slot_id <- .ms_review_slot_id(targets)
    targets$current_value <- .ms_semantic_review_current_values(targets, frames)
    writable <- as.character(targets$target_sdp_file) %in% .ms_review_writable_files()
    iri_field <- grepl("_iri$", as.character(targets$target_sdp_field))
    blank <- !is.na(targets$current_value) & !nzchar(trimws(targets$current_value))
    no_row <- !targets$slot_id %in% known_slots
    targets[writable & iri_field & blank & no_row, , drop = FALSE]
  }

  in_scope <- discover(code_scope)
  not_covered <- tibble::tibble()
  if (!identical(code_scope, "all")) {
    wider <- discover("all")
    code_level <- wider[as.character(wider$target_scope) %in% "code", , drop = FALSE]
    not_covered <- code_level[!code_level$slot_id %in% in_scope$slot_id, , drop = FALSE]
  }
  list(
    targets = in_scope,
    not_covered = not_covered[, intersect(c("slot_id", "column_name", "code_value", "dictionary_role", "target_sdp_file", "target_sdp_field"), names(not_covered)), drop = FALSE]
  )
}

# Targets and candidates for a package path: the review queue plus the blank
# slots discovery recovers, all re-retrieved at depth `top_n`.
.ms_semantic_review_package_targets <- function(path, frames, top_n, source_policy, search_fn, code_scope) {
  # A package whose every lookup found nothing has no `semantic_suggestions.csv`
  # at all (`create_sdp()` writes none for an empty shortlist), and the console
  # refuses to open a queue without one. That package is exactly the one whose
  # blank slots discovery has to recover, so an absent or empty shortlist is
  # an empty queue here, not a refusal.
  existing <- semantic_suggestions(path)
  queue <- if (is.null(existing) || nrow(existing) == 0L) {
    list(review = tibble::tibble(), suggestions = tibble::tibble(), source_row = integer(), review_path = path)
  } else {
    .ms_review_queue(path, include_filled = FALSE, columns = NULL)
  }
  review <- queue$review
  targets <- tibble::tibble()
  if (nrow(review) > 0L) {
    rows <- queue$suggestions[queue$source_row, , drop = FALSE]
    first <- !duplicated(review$slot_id)
    targets <- rows[first, , drop = FALSE]
    targets <- .ms_semantic_add_missing_cols(targets, .ms_semantic_target_cols())
    targets <- targets[, .ms_semantic_target_cols(), drop = FALSE]
    if (!"search_role" %in% names(rows) || all(is.na(targets$search_role))) {
      targets$search_role <- targets$dictionary_role
    }
    targets$slot_id <- review$slot_id[first]
    targets$current_value <- review$current_value[first]
  }
  blank <- .ms_semantic_review_blank_slots(path, frames, queue$suggestions, code_scope)
  if (nrow(blank$targets) > 0L) {
    known <- if (nrow(targets) > 0L) targets$slot_id else character()
    targets <- dplyr::bind_rows(targets, blank$targets[!blank$targets$slot_id %in% known, , drop = FALSE])
  }
  if (nrow(targets) == 0L) {
    return(list(targets = targets, candidates = tibble::tibble(), failed_sources = character(), not_covered = blank$not_covered))
  }

  failed <- character()
  search_once <- .ms_search_once_per_call(function(query, role, sources) {
    result <- search_fn(query, role = role, sources = sources)
    failed <<- unique(c(failed, .ms_search_failed_sources(attr(result, "diagnostics", exact = TRUE))))
    result
  })
  candidates <- purrr::map_dfr(seq_len(nrow(targets)), function(i) {
    .ms_retrieve_semantic_target_candidates(
      target = targets[i, setdiff(names(targets), c("slot_id", "current_value")), drop = FALSE],
      sources = source_policy,
      max_per_role = top_n,
      search_fn = search_once,
      retrieval_pass = 1L
    )
  })
  if (nrow(candidates) > 0L) {
    candidates <- .ms_semantic_flag_role_collisions(candidates)
  }
  list(targets = targets, candidates = candidates, failed_sources = failed, not_covered = blank$not_covered)
}

# Targets and candidates for in-memory input: the dictionary's own attributes,
# every target included, the first `top_n` candidates of each in the order the
# ranked producer emitted them.
.ms_semantic_review_memory_targets <- function(dict, top_n) {
  targets <- attr(dict, "semantic_targets", exact = TRUE)
  suggestions <- attr(dict, "semantic_suggestions", exact = TRUE)
  if (is.null(targets)) {
    cli::cli_abort(c(
      "The dictionary carries no {.code semantic_targets} attribute.",
      "i" = "Run {.fn suggest_semantics} first; it attaches the targets and the shortlist."
    ))
  }
  targets <- tibble::as_tibble(targets)
  suggestions <- if (is.null(suggestions)) tibble::tibble() else tibble::as_tibble(suggestions)
  if (nrow(targets) > 0L) {
    targets <- .ms_semantic_add_missing_cols(targets, .ms_semantic_target_cols())
    targets <- targets[, .ms_semantic_target_cols(), drop = FALSE]
    targets$slot_id <- .ms_review_slot_id(targets)
  }
  candidates <- tibble::tibble()
  if (nrow(suggestions) > 0L && nrow(targets) > 0L) {
    suggestions <- suggestions[!.ms_review_is_hand_picked(suggestions), , drop = FALSE]
    keys <- .ms_semantic_group_key_df(suggestions)
    target_keys <- .ms_semantic_group_key_df(targets)
    keep <- keys %in% target_keys
    suggestions <- suggestions[keep, , drop = FALSE]
    keys <- keys[keep]
    # Retrieval order within a target is the ranked order; the shortlist
    # shown is its first `top_n` rows.
    rank <- stats::ave(seq_along(keys), keys, FUN = seq_along)
    candidates <- suggestions[rank <= top_n, , drop = FALSE]
  }
  list(targets = targets, candidates = candidates, failed_sources = character(), not_covered = tibble::tibble())
}

# -----------------------------------------------------------------------------
# Unit assembly
# -----------------------------------------------------------------------------

.ms_semantic_review_dictionary_fields <- function() {
  c(
    "dataset_id", "table_id", "column_name", "column_label",
    "column_description", "column_role", "value_type", "unit_label", "term_type"
  )
}

.ms_semantic_review_dictionary_object <- function(dict_row) {
  dict_row <- tibble::as_tibble(dict_row)
  values <- lapply(.ms_semantic_review_dictionary_fields(), function(field) {
    if (nrow(dict_row) == 1L && field %in% names(dict_row)) {
      .ms_semantic_review_scalar(dict_row[[field]][[1]])
    } else {
      NULL
    }
  })
  stats::setNames(values, .ms_semantic_review_dictionary_fields())
}

.ms_semantic_review_current_slots <- function(dict_row) {
  fields <- .ms_semantic_bundle_slot_fields()
  dict_row <- tibble::as_tibble(dict_row)
  stats::setNames(lapply(fields, function(field) {
    if (nrow(dict_row) == 1L && field %in% names(dict_row)) {
      .ms_semantic_review_scalar(dict_row[[field]][[1]])
    } else {
      NULL
    }
  }), names(fields))
}

# A single cell as a JSON scalar: NA and empty strings are null, everything
# else is itself. A length-zero or NULL cell is null.
.ms_semantic_review_scalar <- function(value) {
  if (is.null(value) || length(value) == 0L) {
    return(NULL)
  }
  value <- value[[1]]
  if (is.na(value)) {
    return(NULL)
  }
  if (is.character(value) && !nzchar(value)) {
    return(NULL)
  }
  if (is.factor(value)) {
    return(as.character(value))
  }
  value
}

.ms_semantic_review_text_scalar <- function(value) {
  scalar <- .ms_semantic_review_scalar(value)
  if (is.null(scalar)) {
    return(NULL)
  }
  as.character(scalar)
}

.ms_semantic_review_identity_cols <- function() {
  .ms_semantic_assessment_join_cols()
}

.ms_semantic_review_candidate_fields <- function() {
  c(
    "label", "iri", "source", "ontology", "role", "match_type", "definition",
    "term_type", "resource_kind", "type_iris", "role_hints", "role_hint_status",
    "role_hint_bonus", "alignment_only", "agreement_sources", "retrieval_query",
    "retrieval_pass", "role_collision", "role_collision_note"
  )
}

# Columns of a candidate row that are not candidate evidence: the target it
# was stamped with, the review console's decision columns, assessment output
# and internal keys. Everything else that is not a named field goes to `extra`.
.ms_semantic_review_candidate_excluded_cols <- function() {
  c(
    .ms_semantic_target_cols(), .ms_semantic_review_candidate_fields(), "score",
    "decision", "decision_reason", "llm_selected", "llm_candidate_rank",
    "candidate_label_norm", "collision_roles"
  )
}

.ms_semantic_review_candidate_object <- function(row, index) {
  text <- function(col) .ms_semantic_review_text_scalar(if (col %in% names(row)) row[[col]] else NULL)
  number <- function(col) {
    value <- .ms_semantic_review_scalar(if (col %in% names(row)) row[[col]] else NULL)
    if (is.null(value)) NULL else suppressWarnings(as.numeric(value))
  }
  flag <- function(col) {
    value <- .ms_semantic_review_scalar(if (col %in% names(row)) row[[col]] else NULL)
    if (is.null(value)) {
      return(NULL)
    }
    if (is.logical(value)) {
      return(value)
    }
    lowered <- tolower(trimws(as.character(value)))
    if (lowered %in% c("true", "t", "1")) TRUE else if (lowered %in% c("false", "f", "0")) FALSE else NULL
  }
  retrieval_pass <- number("retrieval_pass")
  extra_cols <- setdiff(names(row), .ms_semantic_review_candidate_excluded_cols())
  extra_cols <- extra_cols[!startsWith(extra_cols, ".") & !startsWith(extra_cols, "llm_")]
  extra_cols <- sort(extra_cols, method = "radix")
  extra <- stats::setNames(lapply(extra_cols, function(col) {
    value <- row[[col]]
    if (is.list(value)) {
      value <- value[[1]]
    }
    if (length(value) > 1L) {
      return(paste(as.character(value), collapse = "; "))
    }
    .ms_semantic_review_scalar(value)
  }), extra_cols)
  if (length(extra) == 0L) {
    extra <- .ms_json_object()
  }
  list(
    index = as.integer(index),
    label = text("label"),
    iri = text("iri"),
    source = text("source"),
    ontology = text("ontology"),
    role = text("role"),
    match_type = text("match_type"),
    definition = text("definition"),
    term_type = text("term_type"),
    resource_kind = text("resource_kind"),
    type_iris = text("type_iris"),
    native_type = .ms_semantic_review_text_scalar(.ms_semantic_validator_candidate_type(row)),
    role_hints = text("role_hints"),
    role_hint_status = text("role_hint_status"),
    role_hint_bonus = number("role_hint_bonus"),
    lexical_score = number("score"),
    alignment_only = flag("alignment_only"),
    agreement_sources = text("agreement_sources"),
    retrieval_query = text("retrieval_query"),
    retrieval_pass = if (is.null(retrieval_pass)) NULL else as.integer(retrieval_pass),
    role_collision = flag("role_collision"),
    role_collision_note = text("role_collision_note"),
    extra = extra
  )
}

.ms_semantic_review_identity_object <- function(target) {
  stats::setNames(
    lapply(.ms_semantic_review_identity_cols(), function(col) .ms_semantic_review_text_scalar(target[[col]])),
    .ms_semantic_review_identity_cols()
  )
}

.ms_semantic_review_target_object <- function(target) {
  stats::setNames(
    lapply(.ms_semantic_target_cols(), function(col) .ms_semantic_review_text_scalar(target[[col]])),
    .ms_semantic_target_cols()
  )
}

.ms_semantic_review_slot_object <- function(target, candidate_rows) {
  candidate_rows <- tibble::as_tibble(candidate_rows)
  candidates <- lapply(seq_len(nrow(candidate_rows)), function(i) {
    .ms_semantic_review_candidate_object(candidate_rows[i, , drop = FALSE], i)
  })
  current <- .ms_semantic_review_text_scalar(target$current_value)
  list(
    dictionary_role = .ms_semantic_review_text_scalar(target$dictionary_role),
    target_sdp_field = .ms_semantic_review_text_scalar(target$target_sdp_field),
    status = "review",
    current_value = current,
    slot_id = .ms_semantic_review_text_scalar(target$slot_id),
    identity = .ms_semantic_review_identity_object(target),
    target = .ms_semantic_review_target_object(target),
    candidates = candidates
  )
}

.ms_semantic_review_excerpt_objects <- function(chunks) {
  chunks <- tibble::as_tibble(chunks)
  if (nrow(chunks) == 0L) {
    return(list())
  }
  lapply(seq_len(nrow(chunks)), function(i) {
    list(
      source = as.character(chunks$source[[i]]),
      chunk_id = as.character(chunks$chunk_id[[i]]),
      context_score = if ("context_score" %in% names(chunks)) as.numeric(chunks$context_score[[i]]) else 0,
      excerpt = as.character(chunks$chunk_text[[i]])
    )
  })
}

# The excerpts for one unit: scored per target against the pool, deduplicated
# across the unit's targets, capped at four (the in-package bundle limit with
# the provider special case removed).
.ms_semantic_review_unit_context <- function(targets, candidate_groups, context_pool, max_chunks = 4L) {
  if (is.null(context_pool) || nrow(context_pool) == 0L) {
    return(tibble::tibble())
  }
  keys <- .ms_semantic_group_key_df(targets)
  chunks <- purrr::map_dfr(seq_len(nrow(targets)), function(i) {
    .ms_prepare_context_chunks(
      target_row = targets[i, , drop = FALSE],
      candidate_rows = candidate_groups[[keys[[i]]]] %||% tibble::tibble(),
      max_chunks = max_chunks,
      context_chunk_pool = context_pool
    )
  })
  if (nrow(chunks) == 0L) {
    return(chunks)
  }
  if (!"context_score" %in% names(chunks)) {
    chunks$context_score <- 0
  }
  key <- paste(chunks$source, chunks$chunk_id, sep = "\r")
  chunks <- chunks[!duplicated(key), , drop = FALSE]
  utils::head(chunks, max_chunks)
}

# Assemble the units: one bundle unit per measurement column that
# `.ms_semantic_bundle_review_targets()` accepts, one target unit for every
# other target, including a target with no candidates. Units are sorted by
# key in C collation; candidates keep retrieval order.
.ms_semantic_review_units <- function(targets, candidates, dict, frames, context_pool) {
  if (nrow(targets) == 0L) {
    return(list())
  }
  targets <- tibble::as_tibble(targets)
  candidates <- tibble::as_tibble(candidates)
  target_keys <- .ms_semantic_group_key_df(targets)
  candidate_keys <- if (nrow(candidates) > 0L) .ms_semantic_group_key_df(candidates) else character()
  candidate_groups <- stats::setNames(
    lapply(target_keys, function(key) candidates[candidate_keys == key, , drop = FALSE]),
    target_keys
  )

  bundle_targets <- .ms_semantic_bundle_review_targets(targets, dict)
  bundle_target_keys <- if (nrow(bundle_targets) > 0L) .ms_semantic_group_key_df(bundle_targets) else character()
  is_bundle <- target_keys %in% bundle_target_keys

  units <- list()
  if (any(is_bundle)) {
    bundle_keys <- .ms_semantic_bundle_key_df(targets[is_bundle, , drop = FALSE])
    for (bundle_key in unique(bundle_keys)) {
      members <- which(is_bundle)[bundle_keys == bundle_key]
      member_targets <- targets[members, , drop = FALSE]
      member_targets <- member_targets[
        order(match(member_targets$dictionary_role, .ms_semantic_bundle_roles()), method = "radix"),
        ,
        drop = FALSE
      ]
      dict_row <- .ms_semantic_bundle_dictionary_row(member_targets[1, , drop = FALSE], dict)
      unit_key <- paste0(
        "bundle:",
        paste(
          vapply(c("dataset_id", "table_id", "column_name"), function(col) {
            .ms_semantic_review_text_scalar(member_targets[[col]][[1]]) %||% ""
          }, character(1)),
          collapse = "/"
        )
      )
      member_keys <- .ms_semantic_group_key_df(member_targets)
      units[[length(units) + 1L]] <- list(
        unit_kind = "bundle",
        unit_key = unit_key,
        dictionary = .ms_semantic_review_dictionary_object(dict_row),
        current_slots = .ms_semantic_review_current_slots(dict_row),
        slots = lapply(seq_len(nrow(member_targets)), function(i) {
          .ms_semantic_review_slot_object(member_targets[i, , drop = FALSE], candidate_groups[[member_keys[[i]]]])
        }),
        context_excerpts = .ms_semantic_review_excerpt_objects(
          .ms_semantic_review_unit_context(member_targets, candidate_groups, context_pool)
        )
      )
    }
  }
  for (i in which(!is_bundle)) {
    target <- targets[i, , drop = FALSE]
    dict_row <- if (identical(.ms_semantic_trim_string(target$target_scope), "column")) {
      .ms_semantic_bundle_dictionary_row(target, dict)
    } else {
      tibble::tibble()
    }
    units[[length(units) + 1L]] <- list(
      unit_kind = "target",
      unit_key = paste0("target:", .ms_semantic_review_text_scalar(target$slot_id) %||% target_keys[[i]]),
      dictionary = .ms_semantic_review_dictionary_object(dict_row),
      current_slots = .ms_json_object(),
      slots = list(.ms_semantic_review_slot_object(target, candidate_groups[[target_keys[[i]]]])),
      context_excerpts = .ms_semantic_review_excerpt_objects(
        .ms_semantic_review_unit_context(target, candidate_groups, context_pool)
      )
    )
  }
  keys <- vapply(units, `[[`, character(1), "unit_key")
  if (anyDuplicated(keys) > 0L) {
    cli::cli_abort("Semantic review units must have unique keys; found duplicates.")
  }
  units[order(keys, method = "radix")]
}

# -----------------------------------------------------------------------------
# Packet assembly
# -----------------------------------------------------------------------------

.ms_semantic_review_producer <- function(fn) {
  list(
    implementation = "metasalmon",
    version = as.character(utils::packageVersion("metasalmon")),
    `function` = fn
  )
}

.ms_semantic_review_pins <- function(source_policy, sources_used, failed_sources, ranking_identity, top_n, code_scope) {
  policy <- .ms_semantic_bundle_source_policy_payload(source_policy)
  list(
    sdp_profile = list(
      version = .ms_semantic_review_text_scalar(.ms_vendored_sdp_schema()$version),
      source = "vendored"
    ),
    ontologies = list(
      pinned = FALSE,
      sources = .ms_json_array(sort(unique(as.character(sources_used)), method = "radix")),
      failed_sources = .ms_json_array(sort(unique(as.character(failed_sources)), method = "radix"))
    ),
    ranking_identity = ranking_identity,
    retrieval = list(
      top_n = as.integer(top_n),
      code_scope = code_scope,
      source_policy = list(
        mode = policy$mode,
        explicit_allowlist = .ms_json_array(policy$explicit_allowlist),
        effective_sources_by_role = lapply(policy$effective_sources_by_role, .ms_json_array)
      )
    )
  )
}

.ms_semantic_review_context_object <- function(context_pool) {
  inputs <- attr(context_pool, "context_inputs", exact = TRUE)
  inputs <- if (is.null(inputs)) tibble::tibble() else tibble::as_tibble(inputs)
  list(
    inputs = lapply(seq_len(nrow(inputs)), function(i) {
      list(
        source = as.character(inputs$source[[i]]),
        kind = as.character(inputs$kind[[i]]),
        sha256 = as.character(inputs$sha256[[i]])
      )
    }),
    chunking = list(
      chunk_chars = 2200L,
      overlap_chars = 200L,
      max_excerpts = 4L,
      token_min_chars = 3L
    )
  )
}

.ms_semantic_review_assemble_packet <- function(pass,
                                               parent_packet_id,
                                               pins,
                                               context,
                                               units,
                                               fn = "write_semantic_review_packet") {
  packet <- list(
    packet_version = .ms_semantic_review_packet_version(),
    packet_id = NULL,
    pass = as.integer(pass),
    parent_packet_id = parent_packet_id,
    producer = .ms_semantic_review_producer(fn),
    pins = pins,
    instructions = .ms_semantic_review_instructions(),
    decision_vocabulary = .ms_json_array(.ms_semantic_review_decision_vocabulary()),
    decision_aliases = as.list(.ms_semantic_review_decision_aliases()),
    output = list(
      file = paste0("review/", basename(.ms_semantic_review_file(".", "assessments", pass))),
      columns = .ms_semantic_review_output_columns()
    ),
    context = context,
    units = .ms_json_array(units)
  )
  packet$packet_id <- .ms_semantic_review_packet_id(packet)
  packet
}

# The counts a return value and a message report.
.ms_semantic_review_unit_counts <- function(units) {
  list(
    units = length(units),
    targets = sum(vapply(units, function(unit) length(unit$slots), integer(1)))
  )
}

.ms_semantic_review_write_files <- function(root, writes) {
  .ms_assert_managed_path_contained(root, names(writes))
  .ms_sdp_extension_atomic_write_set(writes)
  invisible(names(writes))
}

#' Write a semantic review packet for a harness to judge
#'
#' Model judgement runs outside metasalmon (ruled 2026-09-25, hub Q67). This
#' writes the deterministic file a harness reads: every semantic slot that
#' still needs a decision, each slot's ranked candidate shortlist with the
#' evidence the package's own validators read (label, IRI, source, ontology,
#' native type, role hints, term type, resource kind, type IRIs, definition
#' and scores), the measurement bundles with their current slots, the scored
#' excerpts from your context documents, the review instructions, the
#' decision vocabulary and the 30-column assessment schema. The harness
#' answers in a CSV next to the packet, and
#' [ingest_semantic_assessments()] reads it back.
#'
#' **This never calls a model.** For a package path it retrieves each slot's
#' shortlist again through `search_fn`, which is the only way it reaches the
#' network; for in-memory input it makes no network call at all.
#'
#' For a package path the packet holds exactly the queue [review_semantics()]
#' would show -- slots in `column_dictionary.csv`, `codes.csv` or `tables.csv`
#' whose IRI field is blank or `REVIEW:`-marked and that carry no recorded
#' decision -- and never a fresh discovery. For an in-memory dictionary it
#' holds every target in the `semantic_targets` attribute, including targets
#' with no candidates, with the first `top_n` candidates of each from the
#' `semantic_suggestions` attribute.
#'
#' The packet holds excerpts from your own context documents. It is written
#' under `review/`, which no publication path reads, and it is never
#' published.
#'
#' For a package path, recovering blank slots re-runs discovery over the
#' package's own metadata and data. A data resource is opened only when
#' `tables.csv` names it with a plain relative path inside the package (no
#' `..`, no absolute path, no symbolic link in the path); any other row is
#' skipped with a warning.
#'
#' @param x A package directory written by [create_sdp()], or a dictionary
#'   carrying the `semantic_targets` and `semantic_suggestions` attributes
#'   that [suggest_semantics()] attaches (an artifact list in the
#'   [infer_salmon_datapackage_artifacts()] shape is read through its `dict`).
#' @param context_files Optional character vector of local file paths whose
#'   text is chunked and scored against each unit, under the same path-only
#'   contract as `llm_context_files`: a parsed object is refused.
#' @param context_text Optional character vector of inline context text.
#' @param top_n Integer. The shortlist shown per slot and, for a package
#'   path, the retrieval depth. Default 5.
#' @param sources Optional character vector of vocabulary sources. When
#'   omitted, each role searches its default sources
#'   ([sources_for_role()]); when supplied, it is a strict allowlist.
#' @param search_fn The search function, used only for a package path.
#'   Defaults to [find_terms()].
#' @param code_scope Which `codes.csv` values get a slot when a blank slot is
#'   recovered by discovery for a package path: the same choice as
#'   `create_sdp(semantic_code_scope = )`, whose default this shares. Nothing
#'   in a package records the scope it was created with, so the packet
#'   records the one used here, and a blank code-level slot outside it is
#'   reported as `not_covered` rather than silently dropped.
#' @param review_dir Where to write the packet. Defaults to `review/` under
#'   the package directory; required for in-memory input.
#' @param overwrite Logical. A review session that already holds answers or
#'   a record refuses to be overwritten unless this is `TRUE`, in which case
#'   the session's files are deleted first.
#' @param quiet Logical. Suppress the summary message.
#'
#' @return Invisibly, a list with `path` (the packet file), `packet_id`
#'   (the SHA-256 the ingester checks), `pass` (always 1 here), `units` and
#'   `targets` (counts), and `not_covered`: the blank code-level slots the
#'   chosen `code_scope` left out, one row each (empty for in-memory input).
#' @seealso [ingest_semantic_assessments()], [review_semantics()]
#' @export
#'
#' @examples
#' dict <- tibble::tibble(
#'   dataset_id = "demo-1", table_id = "spawners", column_name = "spawner_count",
#'   column_role = "measurement", column_label = "Spawner count",
#'   column_description = "Number of spawners counted.", unit_label = "count",
#'   term_iri = NA_character_
#' )
#' target <- tibble::tibble(
#'   dataset_id = "demo-1", table_id = "spawners", column_name = "spawner_count",
#'   code_value = NA_character_, dictionary_role = "variable", search_role = "variable",
#'   target_scope = "column", target_sdp_file = "column_dictionary.csv",
#'   target_sdp_field = "term_iri", target_row_key = "demo-1/spawners/spawner_count",
#'   target_label = "Spawner count", target_description = "Number of spawners counted.",
#'   search_query = "spawner count", target_query_basis = "label",
#'   target_query_context = "Spawner count", column_label = "Spawner count",
#'   column_description = "Number of spawners counted.",
#'   code_label = NA_character_, code_description = NA_character_
#' )
#' attr(dict, "semantic_targets") <- target
#' attr(dict, "semantic_suggestions") <- dplyr::bind_cols(
#'   target,
#'   tibble::tibble(
#'     label = "Spawner Abundance", iri = "https://w3id.org/smn/SpawnerAbundance",
#'     source = "smn", ontology = "smn", role = "variable", match_type = "label",
#'     definition = "Mature salmon returning to spawn.", score = 4.9
#'   )
#' )
#' review_dir <- file.path(tempdir(), "review-packet-example")
#' packet <- write_semantic_review_packet(dict, review_dir = review_dir, quiet = TRUE)
#' packet$packet_id
write_semantic_review_packet <- function(x,
                                         context_files = NULL,
                                         context_text = NULL,
                                         top_n = 5L,
                                         sources = NULL,
                                         search_fn = find_terms,
                                         code_scope = c("factor", "all", "none"),
                                         review_dir = NULL,
                                         overwrite = FALSE,
                                         quiet = FALSE) {
  input <- .ms_semantic_review_input(x, review_dir)
  code_scope <- match.arg(code_scope)
  top_n <- as.integer(top_n[[1]])
  if (is.na(top_n) || top_n < 1L) {
    cli::cli_abort("{.arg top_n} must be a positive whole number.")
  }
  source_policy <- .ms_semantic_source_policy(
    if (is.null(sources)) character() else as.character(sources),
    omitted = is.null(sources)
  )
  review_dir <- input$review_dir

  existing <- .ms_semantic_review_session_files(review_dir)
  existing <- existing[file.exists(existing)]
  answered <- setdiff(existing, .ms_semantic_review_file(review_dir, "packet", 1L))
  if (length(answered) > 0L && !isTRUE(overwrite)) {
    cli::cli_abort(c(
      "A semantic review session already exists in {.path {review_dir}}.",
      .ms_cli_bullets(basename(answered), "*"),
      "i" = "Pass {.code overwrite = TRUE} to delete this session's files and start again."
    ))
  }

  context_pool <- .ms_collect_context_chunks(
    context_files = context_files,
    context_text = context_text
  )

  frames <- .ms_review_source_frames(if (identical(input$kind, "package")) input$path else input$object)
  dict <- frames[["column_dictionary.csv"]] %||% tibble::tibble()
  if (identical(input$kind, "package")) {
    found <- .ms_semantic_review_package_targets(input$path, frames, top_n, source_policy, search_fn, code_scope)
    ranking_identity <- .ms_ranking_identity()
  } else {
    found <- .ms_semantic_review_memory_targets(input$dict, top_n)
    if (nrow(found$targets) > 0L) {
      found$targets$current_value <- .ms_semantic_review_current_values(found$targets, frames)
    }
    ranking_identity <- NULL
  }
  targets <- found$targets
  candidates <- found$candidates
  sources_used <- if (identical(input$kind, "package")) {
    roles <- unique(as.character(targets$search_role %||% targets$dictionary_role))
    unlist(lapply(roles, function(role) .ms_sources_for_target_role(source_policy, role)))
  } else if (nrow(candidates) > 0L && "source" %in% names(candidates)) {
    candidates$source[!is.na(candidates$source)]
  } else {
    character()
  }

  units <- .ms_semantic_review_units(targets, candidates, dict, frames, context_pool)
  packet <- .ms_semantic_review_assemble_packet(
    pass = 1L,
    parent_packet_id = NULL,
    pins = .ms_semantic_review_pins(source_policy, sources_used, found$failed_sources, ranking_identity, top_n, code_scope),
    context = .ms_semantic_review_context_object(context_pool),
    units = units
  )

  if (!dir.exists(review_dir)) {
    dir.create(review_dir, recursive = TRUE)
  }
  if (isTRUE(overwrite) && length(existing) > 0L) {
    .ms_assert_managed_path_contained(review_dir, existing)
    unlink(existing, force = TRUE)
  }
  packet_path <- .ms_semantic_review_file(review_dir, "packet", 1L)
  writes <- stats::setNames(list(.ms_semantic_review_canonical_bytes(packet)), packet_path)
  .ms_semantic_review_write_files(review_dir, writes)

  counts <- .ms_semantic_review_unit_counts(units)
  not_covered <- tibble::as_tibble(found$not_covered %||% tibble::tibble())
  if (!isTRUE(quiet)) {
    cli::cli_inform(c(
      "Wrote semantic review packet {.path {packet_path}}.",
      "i" = "{counts$units} unit{?s} holding {counts$targets} target{?s}; packet_id {packet$packet_id}.",
      if (nrow(not_covered) > 0L) {
        c("!" = "{nrow(not_covered)} blank code-level slot{?s} {?is/are} outside {.code code_scope = \"{code_scope}\"} and not in the packet; see {.code not_covered}.")
      },
      "i" = "Have your harness write {.file {packet$output$file}} next to it, then call {.fn ingest_semantic_assessments}."
    ))
  }
  invisible(list(
    path = packet_path,
    packet_id = packet$packet_id,
    pass = 1L,
    units = counts$units,
    targets = counts$targets,
    not_covered = not_covered
  ))
}
