# The assessment ingester (S16 step 1, hub item B-326).
#
# Reads a harness's assessments in the frozen 30-column row, validates each
# row against the packet it answers, refuses any selection the packet did not
# offer, runs the retry bookkeeping (a retry is a second harness pass: a
# usable retry query is retrieved here and, when it widens the shortlist, a
# continuation packet is written and nothing from that target is merged or
# escalated until the harness has answered it), escalates a final
# reject_shortlist to request_new_term, runs the bundle validators, merges the
# result into the suggestions and persists it so `semantic_llm_assessments(path)`
# returns it. The design is sections 3 and 4 of
# knowledge/plans/2026-09-25-s16-review-packet-contract.md.
#
# It never makes a model call, and it reaches the network only through the
# `search_fn` it is given, for a retry. The ingester never touches the
# metadata CSVs: applying a choice stays `review_semantics()` ->
# `accept_suggestion()` -> `apply_sdp_semantics()`.

# -----------------------------------------------------------------------------
# File-level errors
# -----------------------------------------------------------------------------

# A file-level problem aborts the ingest and writes nothing, with a stable
# code both languages test the same way. The condition carries the code as a
# field and as a class (`metasalmon_semantic_review_<code>`).
.ms_semantic_review_abort <- function(code, message, ..., .envir = parent.frame()) {
  # Interpolated in the caller's frame, where the values the template names
  # live; the default `.envir` would be this wrapper's frame.
  cli::cli_abort(
    message,
    class = c(paste0("metasalmon_semantic_review_", code), "metasalmon_semantic_review_error"),
    code = code,
    ...,
    .envir = .envir
  )
}

.ms_semantic_review_file_error_codes <- function() {
  c(
    "packet_version", "packet_integrity", "packet_unbound", "packet_mismatch", "header",
    "unknown_target", "duplicate_target", "provenance", "no_pass_2"
  )
}

# The harness names the packet it judged in a one-line sidecar beside its
# CSV, `<csv>.packet-id`, because the frozen 30-column row has nowhere to
# carry it. Read trimmed; absent or blank is NULL.
.ms_semantic_review_sidecar_path <- function(csv_path) {
  paste0(csv_path, ".packet-id")
}

.ms_semantic_review_read_sidecar <- function(csv_path) {
  if (is.null(csv_path) || is.na(csv_path)) {
    return(NULL)
  }
  path <- .ms_semantic_review_sidecar_path(csv_path)
  if (!file.exists(path) || dir.exists(path)) {
    return(NULL)
  }
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  # A leading byte-order mark is stripped; the code point is built at run
  # time so the source stays ASCII.
  bom <- intToUtf8(65279L)
  lines <- ifelse(startsWith(lines, bom), substring(lines, 2L), lines)
  lines <- trimws(lines)
  lines <- lines[nzchar(lines)]
  if (length(lines) == 0L) {
    return(NULL)
  }
  lines[[1]]
}

# The packet the assessments were made against must be named, by the sidecar
# or by the caller, and must be the packet being ingested: without this a
# stale file could be recorded under a newer packet's provenance.
.ms_semantic_review_check_binding <- function(current_id, argument_id, sidecar_id) {
  named <- argument_id %||% sidecar_id
  if (is.null(named) || is.na(named) || !nzchar(named)) {
    .ms_semantic_review_abort(
      "packet_unbound",
      c(
        "Nothing names the packet these assessments were made against.",
        "i" = "The harness writes the packet's {.code packet_id} in a one-line sidecar beside its CSV, {.file <csv>.packet-id}, or the caller passes {.arg packet_id}."
      )
    )
  }
  if (!identical(as.character(named), current_id)) {
    .ms_semantic_review_abort(
      "packet_mismatch",
      c(
        "The assessments were made against a different packet from the one being ingested.",
        "i" = "The file is stale: write a new packet and have the harness judge that one, or ingest the packet the file names."
      )
    )
  }
  invisible(TRUE)
}

# The harness-owned free-text columns. Every value is redacted at capture,
# before it reaches the record, so no unredacted copy of harness text
# survives in the package directory.
.ms_semantic_review_redacted_columns <- function() {
  c(
    "llm_provider", "llm_model", "llm_rationale", "llm_missing_context",
    "llm_bundle_summary", "llm_retry_query", "llm_new_term_label",
    "llm_new_term_definition", "llm_new_term_namespace", "llm_error"
  )
}

.ms_semantic_review_redact <- function(rows) {
  changed <- character()
  for (col in intersect(.ms_semantic_review_redacted_columns(), names(rows))) {
    before <- as.character(rows[[col]])
    after <- .ms_redact_secrets(before)
    after[is.na(before)] <- NA_character_
    if (!identical(after, before)) {
      changed <- c(changed, col)
      rows[[col]] <- after
    }
  }
  list(rows = rows, changed = changed)
}

# -----------------------------------------------------------------------------
# Reading the packet back
# -----------------------------------------------------------------------------

.ms_semantic_review_read_packet <- function(packet, review_dir) {
  if (is.null(packet)) {
    pass_2 <- .ms_semantic_review_file(review_dir, "packet", 2L)
    pass_1 <- .ms_semantic_review_file(review_dir, "packet", 1L)
    path <- if (file.exists(pass_2)) pass_2 else pass_1
    if (!file.exists(path)) {
      cli::cli_abort(c(
        "No semantic review packet in {.path {review_dir}}.",
        "i" = "Write one with {.fn write_semantic_review_packet} first."
      ))
    }
    return(list(packet = .ms_semantic_review_read_json(path), path = path))
  }
  if (is.character(packet) && length(packet) == 1L) {
    if (!file.exists(packet)) {
      cli::cli_abort("Packet file {.path {packet}} does not exist.")
    }
    return(list(packet = .ms_semantic_review_read_json(packet), path = packet))
  }
  if (is.list(packet)) {
    return(list(packet = packet, path = NA_character_))
  }
  cli::cli_abort("{.arg packet} must be a packet file path or a parsed packet.")
}

.ms_semantic_review_check_packet <- function(packet, expected_id = NULL) {
  version <- .ms_semantic_review_text_scalar(packet$packet_version)
  expected_version <- .ms_semantic_review_packet_version()
  if (!identical(version, expected_version)) {
    .ms_semantic_review_abort(
      "packet_version",
      "The packet's version is not {.val {expected_version}}."
    )
  }
  stored <- .ms_semantic_review_text_scalar(packet$packet_id)
  recomputed <- .ms_semantic_review_packet_id(packet)
  if (is.null(stored) || !identical(stored, recomputed)) {
    .ms_semantic_review_abort(
      "packet_integrity",
      c(
        "The packet's contents no longer match its {.code packet_id}.",
        "i" = "A packet is never edited; write a new one with {.fn write_semantic_review_packet}."
      )
    )
  }
  if (!is.null(expected_id) && !identical(as.character(expected_id), recomputed)) {
    .ms_semantic_review_abort(
      "packet_mismatch",
      "The packet's {.code packet_id} is not the one this ingest expected."
    )
  }
  invisible(recomputed)
}

# A JSON scalar back to an R cell: null becomes NA of the given type.
.ms_semantic_review_cell <- function(value, type = "character") {
  if (is.null(value) || length(value) == 0L) {
    return(switch(type, character = NA_character_, numeric = NA_real_, integer = NA_integer_, logical = NA))
  }
  switch(
    type,
    character = as.character(value[[1]]),
    numeric = as.numeric(value[[1]]),
    integer = as.integer(value[[1]]),
    logical = as.logical(value[[1]])
  )
}

.ms_semantic_review_target_from_slot <- function(slot) {
  target <- slot$target
  values <- lapply(.ms_semantic_target_cols(), function(col) .ms_semantic_review_cell(target[[col]]))
  out <- tibble::as_tibble(stats::setNames(values, .ms_semantic_target_cols()))
  out$slot_id <- .ms_semantic_review_cell(slot$slot_id)
  out$current_value <- .ms_semantic_review_cell(slot$current_value)
  out
}

# The candidate rows of one slot, as the suggestion rows the package would
# have held: the target's columns stamped on every row, the named fields,
# `score` from `lexical_score`, and every `extra` member as its own column.
.ms_semantic_review_candidates_from_slot <- function(slot, target) {
  candidates <- slot$candidates
  if (length(candidates) == 0L) {
    return(tibble::tibble())
  }
  target_cols <- target[, .ms_semantic_target_cols(), drop = FALSE]
  fields <- .ms_semantic_review_candidate_fields()
  rows <- lapply(candidates, function(candidate) {
    row <- target_cols
    for (field in fields) {
      row[[field]] <- switch(
        field,
        role_hint_bonus = .ms_semantic_review_cell(candidate[[field]], "numeric"),
        retrieval_pass = .ms_semantic_review_cell(candidate[[field]], "integer"),
        alignment_only = .ms_semantic_review_cell(candidate[[field]], "logical"),
        role_collision = .ms_semantic_review_cell(candidate[[field]], "logical"),
        .ms_semantic_review_cell(candidate[[field]])
      )
    }
    row$score <- .ms_semantic_review_cell(candidate$lexical_score, "numeric")
    extra <- candidate$extra
    if (is.list(extra) && length(extra) > 0L) {
      for (name in names(extra)) {
        value <- extra[[name]]
        row[[name]] <- if (is.null(value)) NA else value[[1]]
      }
    }
    row
  })
  dplyr::bind_rows(rows)
}

.ms_semantic_review_context_from_unit <- function(unit) {
  excerpts <- unit$context_excerpts
  if (length(excerpts) == 0L) {
    return(tibble::tibble(source = character(), chunk_id = character(), chunk_text = character(), context_score = numeric()))
  }
  tibble::tibble(
    source = vapply(excerpts, function(e) .ms_semantic_review_cell(e$source), character(1)),
    chunk_id = vapply(excerpts, function(e) .ms_semantic_review_cell(e$chunk_id), character(1)),
    chunk_text = vapply(excerpts, function(e) .ms_semantic_review_cell(e$excerpt), character(1)),
    context_score = vapply(excerpts, function(e) .ms_semantic_review_cell(e$context_score, "numeric"), numeric(1))
  )
}

# The dictionary row the validators read, rebuilt from the unit: the
# dictionary context plus the six slot fields from `current_slots`.
.ms_semantic_review_dict_row_from_unit <- function(unit) {
  dictionary <- unit$dictionary
  fields <- .ms_semantic_review_dictionary_fields()
  values <- lapply(fields, function(field) .ms_semantic_review_cell(dictionary[[field]]))
  row <- tibble::as_tibble(stats::setNames(values, fields))
  slot_fields <- .ms_semantic_bundle_slot_fields()
  for (role in names(slot_fields)) {
    row[[slot_fields[[role]]]] <- .ms_semantic_review_cell(unit$current_slots[[role]])
  }
  row
}

.ms_semantic_review_assessment_row_from_object <- function(object) {
  if (is.null(object) || length(object) == 0L) {
    return(NULL)
  }
  prototypes <- .ms_llm_assessment_prototypes()
  values <- lapply(names(prototypes), function(col) {
    type <- if (is.logical(prototypes[[col]])) {
      "logical"
    } else if (is.integer(prototypes[[col]])) {
      "integer"
    } else if (is.numeric(prototypes[[col]])) {
      "numeric"
    } else {
      "character"
    }
    .ms_semantic_review_cell(object[[col]], type)
  })
  .ms_llm_normalize_assessment_rows(tibble::as_tibble(stats::setNames(values, names(prototypes))))
}

.ms_semantic_review_findings_from_objects <- function(objects) {
  if (is.null(objects) || length(objects) == 0L) {
    return(.ms_semantic_review_empty_findings())
  }
  cols <- .ms_semantic_review_findings_cols()
  dplyr::bind_rows(lapply(objects, function(object) {
    tibble::as_tibble(stats::setNames(
      lapply(cols, function(col) .ms_semantic_review_cell(object[[col]])),
      cols
    ))
  }))
}

.ms_semantic_review_findings_cols <- function() {
  c("dataset_id", "table_id", "column_name", .ms_semantic_validator_finding_cols())
}

.ms_semantic_review_empty_findings <- function() {
  tibble::as_tibble(stats::setNames(
    lapply(.ms_semantic_review_findings_cols(), function(col) character()),
    .ms_semantic_review_findings_cols()
  ))
}

# Every slot of the packet as one record, in packet order, with its unit.
.ms_semantic_review_slots <- function(packet) {
  slots <- list()
  for (u in seq_along(packet$units)) {
    unit <- packet$units[[u]]
    for (s in seq_along(unit$slots)) {
      slot <- unit$slots[[s]]
      target <- .ms_semantic_review_target_from_slot(slot)
      slots[[length(slots) + 1L]] <- list(
        unit_index = u,
        slot_index = s,
        unit_kind = .ms_semantic_review_cell(unit$unit_kind),
        unit_key = .ms_semantic_review_cell(unit$unit_key),
        key = .ms_semantic_review_identity_key(target),
        role = .ms_semantic_review_cell(slot$dictionary_role),
        target = target,
        candidates = .ms_semantic_review_candidates_from_slot(slot, target),
        reassess = isTRUE(slot$reassess),
        previous_assessment = .ms_semantic_review_assessment_row_from_object(slot$previous_assessment)
      )
    }
  }
  slots
}

# The identity a harness copies: the nine join columns, trimmed, an empty
# field equal to null.
.ms_semantic_review_identity_key <- function(rows) {
  rows <- tibble::as_tibble(rows)
  cols <- .ms_semantic_review_identity_cols()
  parts <- lapply(cols, function(col) {
    value <- if (col %in% names(rows)) as.character(rows[[col]]) else rep(NA_character_, nrow(rows))
    value <- trimws(value)
    value[is.na(value)] <- ""
    value
  })
  do.call(paste, c(parts, sep = "\r"))
}

# -----------------------------------------------------------------------------
# Reading the assessment file
# -----------------------------------------------------------------------------

.ms_semantic_review_read_assessments <- function(assessments, pass, review_dir) {
  default_path <- .ms_semantic_review_file(review_dir, "assessments", pass)
  if (is.null(assessments)) {
    if (!file.exists(default_path)) {
      cli::cli_abort(c(
        "No assessment file at {.path {default_path}}.",
        "i" = "The harness writes it there; pass {.arg assessments} to read another path or a data frame."
      ))
    }
    assessments <- default_path
  }
  if (inherits(assessments, "data.frame")) {
    rows <- tibble::as_tibble(assessments)
    rows[] <- lapply(rows, function(col) {
      if (is.logical(col)) {
        ifelse(is.na(col), NA_character_, ifelse(col, "TRUE", "FALSE"))
      } else {
        trimws(as.character(col))
      }
    })
    return(list(rows = rows, path = NA_character_))
  }
  if (!is.character(assessments) || length(assessments) != 1L || is.na(assessments)) {
    cli::cli_abort("{.arg assessments} must be a CSV path or a data frame.")
  }
  if (!file.exists(assessments)) {
    cli::cli_abort("Assessment file {.path {assessments}} does not exist.")
  }
  rows <- tibble::as_tibble(.ms_read_metadata_csv(assessments))
  list(rows = rows, path = assessments)
}

.ms_semantic_review_check_header <- function(rows) {
  expected <- .ms_llm_assessment_cols()
  if (!identical(names(rows), expected)) {
    .ms_semantic_review_abort(
      "header",
      c(
        "The assessment file's header is not the thirty assessment columns in order.",
        "i" = "The packet's {.code output.columns} member lists them; write the file with a CSV library from that list."
      )
    )
  }
  invisible(TRUE)
}

# -----------------------------------------------------------------------------
# Row-level validation
# -----------------------------------------------------------------------------

.ms_semantic_review_note <- function(row, note) {
  row$llm_rationale <- .ms_llm_append_note(
    .ms_llm_non_empty_string(row$llm_rationale[[1]] %||% NA_character_),
    note
  )
  row
}

# An error row's text is one line: cli wraps a condition message at the
# console width, and the record must not depend on where it was written.
# The text itself is implementation-specific (metasalmonpy words its errors
# its own way), which the fixture README says: compare its presence, not
# its words.
.ms_semantic_review_error_row <- function(target, config, error) {
  error <- trimws(gsub("[[:space:]]+", " ", as.character(error)))
  .ms_llm_review_empty_assessment(target, config, error = .ms_redact_secrets(error))
}

# One harness row against one packet slot, in the order section 3.3 of the
# execplan fixes. Returns a normalized 30-column row: an error row, a
# downgraded row with a note, or the validated answer.
.ms_semantic_review_validate_row <- function(row, slot, config, context_chunks) {
  target <- slot$target[, .ms_semantic_target_cols(), drop = FALSE]
  candidates <- .ms_semantic_candidate_rows(slot$candidates)
  text <- function(col) .ms_llm_non_empty_string(row[[col]][[1]] %||% NA_character_)

  # 1. A harness-declared error is an error row, redacted.
  declared <- text("llm_error")
  if (!is.na(declared)) {
    return(.ms_semantic_review_error_row(target, config, declared))
  }

  # 2. The decision, lowercased and trimmed, with the alias read.
  decision <- tolower(text("llm_decision"))
  aliases <- .ms_semantic_review_decision_aliases()
  if (!is.na(decision) && decision %in% names(aliases)) {
    decision <- aliases[[decision]]
  }
  echo <- text("llm_selected_iri")
  candidate_iris <- trimws(as.character(candidates$iri))
  candidate_iris[is.na(candidate_iris)] <- ""

  # 5. An accept whose echoed IRI is not a candidate for the target is an
  # error: an IRI absent from the packet is never applied.
  if (identical(decision, "accept") && !is.na(echo) && !echo %in% candidate_iris[nzchar(candidate_iris)]) {
    return(.ms_semantic_review_error_row(
      target, config,
      paste0("The echoed IRI is not a candidate the packet offered for this target: ", echo)
    ))
  }

  # 2-4, 6-8 and 12 are the shared validator: an unknown decision or a
  # confidence outside [0, 1] aborts (no clamping), a non-accept decision has
  # its index cleared before the range check, an accept without an index or
  # with an out-of-range index downgrades to review, a fractional index is
  # refused, and a retry_search without a query downgrades to review.
  validated <- tryCatch(
    .ms_validate_llm_assessment(
      list(
        decision = text("llm_decision"),
        selected_candidate_index = text("llm_selected_candidate_index"),
        confidence = text("llm_confidence"),
        rationale = text("llm_rationale"),
        missing_context = text("llm_missing_context"),
        bundle_summary = text("llm_bundle_summary"),
        retry_query = text("llm_retry_query"),
        suggested_label = text("llm_new_term_label"),
        suggested_definition = text("llm_new_term_definition"),
        suggested_namespace = text("llm_new_term_namespace")
      ),
      candidates
    ),
    error = function(e) e
  )
  if (inherits(validated, "error")) {
    return(.ms_semantic_review_error_row(target, config, conditionMessage(validated)))
  }

  if (identical(validated$decision, "accept")) {
    index <- validated$selected_candidate_index
    if (is.na(echo)) {
      # 9. An accept with no echoed IRI downgrades to review.
      validated$decision <- "review"
      validated$selected_candidate_index <- NA_integer_
      validated$rationale <- .ms_llm_append_note(
        validated$rationale,
        "Harness returned accept without echoing the candidate's IRI; downgraded to review."
      )
    } else if (!identical(echo, candidate_iris[[index]])) {
      # 10. An echo naming a different candidate from the index is an error.
      return(.ms_semantic_review_error_row(
        target, config,
        paste0(
          "The echoed IRI names a different candidate from index ", index,
          ": ", echo, " is not ", candidate_iris[[index]]
        )
      ))
    }
  }
  if (identical(validated$decision, "accept") &&
      (!is.na(validated$suggested_label) || !is.na(validated$suggested_definition) ||
        !is.na(validated$suggested_namespace))) {
    # 11. An accept with any new-term field is an error.
    return(.ms_semantic_review_error_row(
      target, config,
      "An accept must not carry a new-term label, definition or namespace."
    ))
  }

  .ms_llm_review_success_assessment(
    target_row = target,
    candidate_rows = candidates,
    context_chunks = context_chunks,
    config = config,
    validated = validated
  )
}

# The provider and model for a row: the harness's, unless overridden.
.ms_semantic_review_row_config <- function(row, provider, model) {
  list(
    provider = provider %||% .ms_llm_non_empty_string(row$llm_provider[[1]] %||% NA_character_),
    model = model %||% .ms_llm_non_empty_string(row$llm_model[[1]] %||% NA_character_)
  )
}

# -----------------------------------------------------------------------------
# Retry bookkeeping and the second pass
# -----------------------------------------------------------------------------

.ms_semantic_review_source_policy_from_packet <- function(packet) {
  policy <- packet$pins$retrieval$source_policy
  mode <- .ms_semantic_review_cell(policy$mode)
  allowlist <- vapply(policy$explicit_allowlist %||% list(), function(x) as.character(x), character(1))
  .ms_semantic_source_policy(allowlist, omitted = !identical(mode, "explicit"))
}

.ms_semantic_review_top_n_from_packet <- function(packet) {
  top_n <- .ms_semantic_review_cell(packet$pins$retrieval$top_n, "integer")
  if (is.na(top_n) || top_n < 1L) 5L else top_n
}

# Classify a retry query the way the in-package path does; a duplicate keeps
# its existing reason, an identifier-like query gets `identifier_like_query`
# (decision 12 of the execplan: there is no model call to replace it), and a
# usable query is returned for retrieval.
.ms_semantic_review_classify_retry <- function(row, target) {
  query <- .ms_llm_non_empty_string(row$llm_retry_query[[1]] %||% NA_character_)
  classification <- .ms_llm_classify_retry_query(query, target$search_query[[1]])
  if (identical(classification$disposition, "duplicate_original_query")) {
    return(list(row = .ms_llm_apply_retry_query_classification(row, classification), query = NA_character_))
  }
  if (identical(classification$disposition, "identifier_like")) {
    row$llm_retry_query_rejection_reason <- "identifier_like_query"
    row <- .ms_semantic_review_note(
      row,
      "Retry query looks like an identifier rather than a lexical query; the retry was not issued."
    )
    return(list(row = row, query = NA_character_))
  }
  if (identical(classification$disposition, "use_query")) {
    return(list(row = row, query = classification$query))
  }
  list(row = row, query = NA_character_)
}

# Retrieve a usable retry query at depth `top_n` under the packet's source
# policy and merge it into the slot's shortlist. Returns the merged rows and
# the number of candidates gained.
.ms_semantic_review_retrieve_retry <- function(slot, query, source_policy, top_n, search_fn) {
  target <- slot$target[, .ms_semantic_target_cols(), drop = FALSE]
  extra <- .ms_retrieve_semantic_target_candidates(
    target = target,
    sources = source_policy,
    max_per_role = top_n,
    search_fn = search_fn,
    query = query,
    retrieval_pass = 2L
  )
  existing <- slot$candidates
  merged <- .ms_merge_semantic_target_candidates(
    existing_rows = existing,
    extra_rows = extra,
    max_per_role = top_n
  )
  role <- .ms_semantic_trim_string(target$dictionary_role)
  existing_ids <- .ms_semantic_candidate_identity(existing, role = role)
  merged_ids <- .ms_semantic_candidate_identity(merged, role = role)
  list(candidates = merged, gain = sum(!merged_ids %in% existing_ids))
}

.ms_semantic_review_assessment_object <- function(row) {
  row <- .ms_llm_normalize_assessment_rows(row)
  stats::setNames(lapply(.ms_llm_assessment_cols(), function(col) {
    value <- row[[col]][[1]]
    if (is.na(value)) NULL else value
  }), .ms_llm_assessment_cols())
}

.ms_semantic_review_findings_objects <- function(findings) {
  findings <- tibble::as_tibble(findings)
  cols <- .ms_semantic_review_findings_cols()
  lapply(seq_len(nrow(findings)), function(i) {
    stats::setNames(lapply(cols, function(col) {
      value <- if (col %in% names(findings)) findings[[col]][[i]] else NA_character_
      if (is.na(value)) NULL else as.character(value)
    }), cols)
  })
}

# The pass-2 packet: the same schema with `pass: 2` and the parent's id. It
# holds only the units with a slot that gained candidates; a bundle marks
# the roles to reassess; every slot carries its full pass-1 row and every
# bundle its pass-1 findings, so pass 2 can be re-ingested with the same
# result. Context excerpts are reused verbatim.
.ms_semantic_review_pass_2_packet <- function(packet, slots, rows, pending, findings) {
  pending_units <- sort(unique(vapply(pending, function(p) slots[[p$slot]]$unit_index, integer(1))), method = "radix")
  units <- lapply(pending_units, function(u) {
    unit <- packet$units[[u]]
    unit_slots <- Filter(function(s) s$unit_index == u, slots)
    unit$slots <- lapply(seq_along(unit$slots), function(s) {
      slot_object <- unit$slots[[s]]
      record <- Filter(function(x) x$slot_index == s, unit_slots)[[1]]
      position <- match(TRUE, vapply(slots, function(x) x$unit_index == u && x$slot_index == s, logical(1)))
      gained <- Filter(function(p) p$slot == position, pending)
      slot_object$reassess <- length(gained) > 0L
      if (length(gained) > 0L) {
        merged <- gained[[1]]$candidates
        slot_object$candidates <- lapply(seq_len(nrow(merged)), function(i) {
          .ms_semantic_review_candidate_object(merged[i, , drop = FALSE], i)
        })
      }
      slot_object$previous_assessment <- .ms_semantic_review_assessment_object(rows[[position]])
      slot_object
    })
    if (identical(.ms_semantic_review_cell(unit$unit_kind), "bundle")) {
      unit_findings <- findings[
        .ms_semantic_review_findings_unit_key(findings) == .ms_semantic_review_cell(unit$unit_key),
        ,
        drop = FALSE
      ]
      unit$previous_findings <- .ms_semantic_review_findings_objects(unit_findings)
    }
    unit
  })
  .ms_semantic_review_assemble_packet(
    pass = 2L,
    parent_packet_id = .ms_semantic_review_text_scalar(packet$packet_id),
    pins = packet$pins,
    context = packet$context,
    units = units,
    fn = "ingest_semantic_assessments"
  )
}

.ms_semantic_review_findings_unit_key <- function(findings) {
  findings <- tibble::as_tibble(findings)
  if (nrow(findings) == 0L) {
    return(character())
  }
  paste0(
    "bundle:",
    paste(
      ifelse(is.na(findings$dataset_id), "", as.character(findings$dataset_id)),
      ifelse(is.na(findings$table_id), "", as.character(findings$table_id)),
      ifelse(is.na(findings$column_name), "", as.character(findings$column_name)),
      sep = "/"
    )
  )
}

# -----------------------------------------------------------------------------
# Validators
# -----------------------------------------------------------------------------

# Run the bundle validators for one bundle unit, rebuilt from the packet, on
# the rows given (one per slot, in slot order). Returns the rows, possibly
# downgraded, and the findings.
.ms_semantic_review_validate_bundle <- function(unit, unit_slots, unit_rows) {
  targets <- dplyr::bind_rows(lapply(unit_slots, function(s) s$target[, .ms_semantic_target_cols(), drop = FALSE]))
  keys <- .ms_semantic_group_key_df(targets)
  candidate_groups <- stats::setNames(lapply(unit_slots, `[[`, "candidates"), keys)
  assessments <- .ms_llm_normalize_assessment_rows(dplyr::bind_rows(unit_rows))
  validated <- .ms_semantic_apply_bundle_validators(
    assessments = assessments,
    candidate_groups = candidate_groups,
    targets = targets,
    dict_row = .ms_semantic_review_dict_row_from_unit(unit),
    context_chunks = .ms_semantic_review_context_from_unit(unit)
  )
  rows <- lapply(seq_len(nrow(validated$assessments)), function(i) validated$assessments[i, , drop = FALSE])
  findings <- tibble::as_tibble(validated$findings)
  if (nrow(findings) == 0L) {
    findings <- .ms_semantic_review_empty_findings()
  }
  list(rows = rows, findings = findings[, .ms_semantic_review_findings_cols(), drop = FALSE])
}

.ms_semantic_review_union_findings <- function(...) {
  findings <- dplyr::bind_rows(lapply(list(...), function(f) {
    f <- tibble::as_tibble(f)
    if (nrow(f) == 0L) .ms_semantic_review_empty_findings() else f
  }))
  if (nrow(findings) == 0L) {
    return(.ms_semantic_review_empty_findings())
  }
  key <- paste(findings$dataset_id, findings$table_id, findings$column_name, findings$code, findings$role, sep = "\r")
  findings[!duplicated(key), , drop = FALSE]
}

# -----------------------------------------------------------------------------
# Persistence
# -----------------------------------------------------------------------------

# One value, one rendering: the record's numbers go through the shared
# number-token formatter, logicals as TRUE/FALSE, NA as the empty field.
.ms_semantic_review_character_frame <- function(rows) {
  rows <- tibble::as_tibble(rows)
  rows[] <- lapply(rows, function(col) {
    if (is.logical(col)) {
      out <- ifelse(col, "TRUE", "FALSE")
      out[is.na(col)] <- NA_character_
      out
    } else if (is.integer(col)) {
      as.character(col)
    } else if (is.numeric(col)) {
      vapply(col, .ms_format_number_token, character(1))
    } else if (is.list(col)) {
      vapply(col, function(x) if (is.null(x) || length(x) == 0L) NA_character_ else paste(as.character(x), collapse = "; "), character(1))
    } else {
      as.character(col)
    }
  })
  rows
}

.ms_semantic_review_record_bytes <- function(rows) {
  rows <- .ms_llm_normalize_assessment_rows(rows)
  .ms_sdp_extension_csv_bytes(.ms_semantic_review_character_frame(rows), na = "")
}

.ms_semantic_review_findings_bytes <- function(findings) {
  findings <- tibble::as_tibble(findings)
  if (nrow(findings) == 0L) {
    findings <- .ms_semantic_review_empty_findings()
  }
  .ms_sdp_extension_csv_bytes(
    .ms_semantic_review_character_frame(findings[, .ms_semantic_review_findings_cols(), drop = FALSE]),
    na = ""
  )
}

.ms_semantic_review_read_record <- function(review_dir) {
  path <- .ms_semantic_review_file(review_dir, "record")
  if (!file.exists(path)) {
    return(NULL)
  }
  .ms_llm_normalize_assessment_rows(tibble::as_tibble(.ms_read_metadata_csv(path)))
}

.ms_semantic_review_read_findings <- function(review_dir) {
  path <- .ms_semantic_review_file(review_dir, "findings")
  if (!file.exists(path)) {
    return(.ms_semantic_review_empty_findings())
  }
  found <- tibble::as_tibble(.ms_read_metadata_csv(path))
  if (nrow(found) == 0L) {
    return(.ms_semantic_review_empty_findings())
  }
  found <- .ms_semantic_add_missing_cols(found, .ms_semantic_review_findings_cols())
  found[, .ms_semantic_review_findings_cols(), drop = FALSE]
}

# Rewrite `semantic_suggestions.csv` for the targets whose slots are still
# undecided: their rows are replaced by the packet's shortlist carrying the
# merged assessment columns. A slot with a recorded decision keeps its rows,
# as does a hand-picked row; a slot the packet does not hold is untouched.
.ms_semantic_review_rewrite_suggestions <- function(path, merged, targets) {
  suggestions_path <- file.path(path, "semantic_suggestions.csv")
  if (!file.exists(suggestions_path) || dir.exists(suggestions_path)) {
    return(NULL)
  }
  existing <- tibble::as_tibble(.ms_read_metadata_csv(suggestions_path))
  if (nrow(existing) == 0L) {
    return(NULL)
  }
  existing <- .ms_semantic_add_missing_cols(
    existing,
    c("target_sdp_file", "target_row_key", "target_sdp_field", "decision", "decision_reason")
  )
  existing_slots <- .ms_review_slot_id(existing)
  decided_slots <- unique(existing_slots[!is.na(existing$decision) & nzchar(trimws(existing$decision))])
  merged <- .ms_semantic_review_character_frame(merged)
  merged_slots <- if (nrow(merged) > 0L) .ms_review_slot_id(merged) else character()
  replace_slots <- setdiff(unique(as.character(targets$slot_id)), decided_slots)

  pieces <- list()
  seen <- character()
  for (slot in unique(existing_slots)) {
    if (slot %in% replace_slots) {
      pieces[[length(pieces) + 1L]] <- merged[merged_slots == slot, , drop = FALSE]
      seen <- c(seen, slot)
    } else {
      pieces[[length(pieces) + 1L]] <- existing[existing_slots == slot, , drop = FALSE]
    }
  }
  for (slot in setdiff(replace_slots, seen)) {
    pieces[[length(pieces) + 1L]] <- merged[merged_slots == slot, , drop = FALSE]
  }
  out <- dplyr::bind_rows(pieces)
  # Existing columns keep their order; the assessment columns follow. A column
  # only the original rows carried survives, empty, when none of them do.
  out <- .ms_semantic_add_missing_cols(out, names(existing))
  out <- out[, c(names(existing), setdiff(names(out), names(existing))), drop = FALSE]
  list(path = suggestions_path, rows = out, bytes = .ms_sdp_extension_csv_bytes(out, na = ""))
}

# -----------------------------------------------------------------------------
# The ingester
# -----------------------------------------------------------------------------

#' Ingest a harness's semantic assessments
#'
#' The second half of the review-packet contract: reads the CSV a harness
#' wrote against a packet from [write_semantic_review_packet()], in the
#' frozen 30-column assessment row, and turns it into the package's record.
#' It refuses a selection whose IRI the packet did not offer (recorded as an
#' error row, never applied), runs the retry bookkeeping, escalates a final
#' `reject_shortlist` to `request_new_term` so the ontology gap is surfaced,
#' runs the existing bundle validators, merges the result into the
#' suggestions and persists it under `review/`, so that
#' [semantic_llm_assessments()] returns it for a package path.
#'
#' **A retry is a second harness pass.** A `retry_search` with a usable query
#' is retrieved here through `search_fn`, and when the search widens the
#' shortlist a continuation packet (`review/semantic-review-packet-pass-2.json`)
#' is written holding the widened shortlist; nothing from that target is
#' merged or escalated until the harness has answered it. Calling this again
#' after the harness answers the second packet completes the session. There
#' is no third pass.
#'
#' **This never calls a model**, and it reaches the network only through
#' `search_fn`, for a retry. It never touches the metadata CSVs: applying a
#' choice stays [review_semantics()] -> [accept_suggestion()] ->
#' [apply_sdp_semantics()].
#'
#' A file-level problem aborts the ingest and writes nothing, with a stable
#' code carried as the condition's `code` field and class
#' `metasalmon_semantic_review_<code>`: `packet_version`, `packet_integrity`
#' (the packet no longer matches its `packet_id`), `packet_mismatch`,
#' `header`, `unknown_target`, `duplicate_target`, `provenance` and
#' `no_pass_2`. A row-level problem makes that row an error row or downgrades
#' it with a note, and processing continues.
#'
#' @param x The package directory or the in-memory dictionary the packet was
#'   built from.
#' @param assessments The harness's file: a CSV path or a data frame. Defaults
#'   to `review/semantic-assessments-pass-<n>.csv` for the packet's pass.
#' @param packet The packet the file answers: a path or a parsed packet.
#'   Defaults to the latest pass in `review/`.
#' @param packet_id Optional. The `packet_id` this ingest expects; a
#'   different packet is refused with code `packet_mismatch`.
#' @param provider,model Optional overrides for the `llm_provider` and
#'   `llm_model` columns of every row.
#' @param search_fn The search function used for a retry. Defaults to
#'   [find_terms()].
#' @param review_dir Where the session lives. Defaults to `review/` under the
#'   package directory; required for in-memory input.
#' @param quiet Logical. Suppress the summary message.
#'
#' @return Invisibly, a list: `status` (`"complete"` or `"awaiting_pass_2"`),
#'   `pass`, `packet_id`, `next_packet` (the continuation packet's path, or
#'   `NULL`), `assessments` (the record, with the validator findings as its
#'   `semantic_validator_findings` attribute), `findings`, `suggestions`,
#'   `targets`, `dictionary` (with `semantic_suggestions`, `semantic_targets`
#'   and `semantic_llm_assessments` attached, so
#'   [detect_semantic_term_gaps()] and the accessors work unchanged), and
#'   `summary` (counts of decisions, errors, downgrades, escalations and
#'   retries).
#' @seealso [write_semantic_review_packet()], [semantic_llm_assessments()]
#' @export
ingest_semantic_assessments <- function(x,
                                        assessments = NULL,
                                        packet = NULL,
                                        packet_id = NULL,
                                        provider = NULL,
                                        model = NULL,
                                        search_fn = find_terms,
                                        review_dir = NULL,
                                        quiet = FALSE) {
  input <- .ms_semantic_review_input(x, review_dir)
  review_dir <- input$review_dir
  provider <- if (is.null(provider)) NULL else .ms_llm_non_empty_string(provider)
  model <- if (is.null(model)) NULL else .ms_llm_non_empty_string(model)

  found <- .ms_semantic_review_read_packet(packet, review_dir)
  packet <- found$packet
  current_id <- .ms_semantic_review_check_packet(packet, expected_id = packet_id)
  pass <- .ms_semantic_review_cell(packet$pass, "integer")
  if (is.na(pass) || !pass %in% c(1L, 2L)) {
    .ms_semantic_review_abort("packet_version", "The packet's {.code pass} must be 1 or 2.")
  }

  # Provenance: a pass-2 packet must descend from the pass-1 packet and the
  # record in this session, and a pass-2 ingest needs a pass-2 packet.
  pass_1_path <- .ms_semantic_review_file(review_dir, "packet", 1L)
  pass_2_path <- .ms_semantic_review_file(review_dir, "packet", 2L)
  if (pass == 2L) {
    if (!file.exists(pass_2_path)) {
      .ms_semantic_review_abort(
        "no_pass_2",
        "No continuation packet exists in {.path {review_dir}}: nothing asked for a second pass."
      )
    }
    if (!file.exists(pass_1_path) || is.null(.ms_semantic_review_read_record(review_dir))) {
      .ms_semantic_review_abort(
        "provenance",
        "A pass-2 ingest needs the pass-1 packet and its record in {.path {review_dir}}."
      )
    }
    parent <- .ms_semantic_review_text_scalar(packet$parent_packet_id)
    pass_1_packet <- .ms_semantic_review_read_json(pass_1_path)
    if (is.null(parent) || !identical(parent, .ms_semantic_review_packet_id(pass_1_packet))) {
      .ms_semantic_review_abort(
        "provenance",
        "The pass-2 packet does not descend from the pass-1 packet in {.path {review_dir}}."
      )
    }
    # The whole session's slots: the result describes every pass-1 target,
    # and a reassessed slot whose pass-2 answer is missing or unusable falls
    # back to its pass-1 candidates.
    pass_1_slots <- .ms_semantic_review_slots(pass_1_packet)
    pass_1_keys <- vapply(pass_1_slots, `[[`, character(1), "key")
  } else if (is.character(assessments) && length(assessments) == 1L &&
    identical(basename(assessments), basename(.ms_semantic_review_file(".", "assessments", 2L)))) {
    .ms_semantic_review_abort(
      "no_pass_2",
      "A pass-2 assessment file was given, but the packet being ingested is pass 1."
    )
  }

  read <- .ms_semantic_review_read_assessments(assessments, pass, review_dir)
  .ms_semantic_review_check_binding(current_id, packet_id, .ms_semantic_review_read_sidecar(read$path))
  .ms_semantic_review_check_header(read$rows)
  # Redacted at capture: nothing below sees the unredacted text.
  redacted <- .ms_semantic_review_redact(read$rows)
  harness <- redacted$rows

  slots <- .ms_semantic_review_slots(packet)
  slot_keys <- vapply(slots, `[[`, character(1), "key")
  row_keys <- .ms_semantic_review_identity_key(harness)
  unknown <- !row_keys %in% slot_keys
  if (any(unknown)) {
    .ms_semantic_review_abort(
      "unknown_target",
      c(
        "{sum(unknown)} assessment row{?s} name a target the packet does not hold.",
        "i" = "The identity columns must be copied from the packet exactly."
      )
    )
  }
  if (anyDuplicated(row_keys) > 0L) {
    .ms_semantic_review_abort(
      "duplicate_target",
      "The assessment file holds more than one row for the same target."
    )
  }

  # Harness values in package-owned columns are overwritten, with one warning.
  package_owned <- .ms_semantic_review_package_owned_columns()
  written <- package_owned[vapply(package_owned, function(col) {
    any(!is.na(harness[[col]]) & nzchar(trimws(as.character(harness[[col]]))))
  }, logical(1))]
  if (length(written) > 0L) {
    cli::cli_warn(c(
      "The assessment file wrote package-owned columns, which the package overwrites:",
      .ms_cli_bullets(written, "*")
    ))
  }

  # Row validation, one row per packet slot; a slot with no row is an error row
  # at pass 1. At pass 2 a reassessed slot whose answer is missing or unusable
  # keeps its pass-1 row and its pass-1 candidates (execplan section 4, item
  # 3), the session still completes, and the fallback is counted and said.
  row_for_slot <- match(slot_keys, row_keys)
  rows <- vector("list", length(slots))
  fallback <- logical(length(slots))
  errors <- 0L
  downgrades <- 0L
  kept_pass_1 <- 0L
  for (i in seq_along(slots)) {
    slot <- slots[[i]]
    unit <- packet$units[[slot$unit_index]]
    context_chunks <- .ms_semantic_review_context_from_unit(unit)
    target <- slot$target[, .ms_semantic_target_cols(), drop = FALSE]
    if (pass == 2L && !slot$reassess) {
      rows[[i]] <- slot$previous_assessment
      next
    }
    if (is.na(row_for_slot[[i]])) {
      config <- list(provider = provider %||% NA_character_, model = model %||% NA_character_)
      if (pass == 2L) {
        rows[[i]] <- .ms_semantic_review_note(
          slot$previous_assessment,
          "No pass-2 assessment was supplied; the pass-1 answer stands and there is no third pass."
        )
        fallback[[i]] <- TRUE
        kept_pass_1 <- kept_pass_1 + 1L
      } else {
        rows[[i]] <- .ms_semantic_review_error_row(target, config, "No assessment was supplied for this target.")
        errors <- errors + 1L
      }
      next
    }
    row <- harness[row_for_slot[[i]], , drop = FALSE]
    config <- .ms_semantic_review_row_config(row, provider, model)
    if (is.na(config$provider) || is.na(config$model)) {
      rows[[i]] <- .ms_semantic_review_error_row(target, config, "llm_provider and llm_model must be non-empty.")
      errors <- errors + 1L
      next
    }
    validated <- .ms_semantic_review_validate_row(row, slot, config, context_chunks)
    if (!is.na(validated$llm_error[[1]])) {
      errors <- errors + 1L
      if (pass == 2L) {
        validated <- .ms_semantic_review_note(
          slot$previous_assessment,
          paste0("Pass-2 answer was unusable, so the pass-1 answer stands: ", validated$llm_error[[1]])
        )
        fallback[[i]] <- TRUE
        kept_pass_1 <- kept_pass_1 + 1L
      }
    } else {
      harness_decision <- tolower(.ms_llm_non_empty_string(row$llm_decision[[1]]))
      if (!identical(validated$llm_decision[[1]], harness_decision) &&
          !identical(.ms_semantic_review_decision_aliases()[harness_decision] %||% NA_character_, validated$llm_decision[[1]])) {
        downgrades <- downgrades + 1L
      }
      if (pass == 2L) {
        previous <- slot$previous_assessment
        validated <- .ms_llm_add_exploration_metadata(
          validated,
          used = isTRUE(previous$llm_exploration_used[[1]]),
          queries = if (is.na(previous$llm_exploration_queries[[1]])) character() else previous$llm_exploration_queries[[1]],
          candidate_gain = previous$llm_exploration_candidate_gain[[1]] %||% 0L
        )
        if (identical(validated$llm_decision[[1]], "retry_search")) {
          validated <- .ms_semantic_review_note(validated, "Retry requested at pass 2 was not issued; there is no third pass.")
        }
      }
    }
    rows[[i]] <- validated
  }
  if (pass == 2L && any(fallback)) {
    # The pass-1 row's index maps onto the pass-1 candidates, so a fallback
    # slot merges those and not the widened shortlist it was shown.
    for (i in which(fallback)) {
      original <- match(slots[[i]]$key, pass_1_keys)
      if (!is.na(original)) {
        slots[[i]]$candidates <- pass_1_slots[[original]]$candidates
      }
    }
  }

  # Retry bookkeeping (pass 1 only): classify, retrieve, merge, count the gain.
  pending <- list()
  retries <- 0L
  if (pass == 1L) {
    source_policy <- .ms_semantic_review_source_policy_from_packet(packet)
    top_n <- .ms_semantic_review_top_n_from_packet(packet)
    search_once <- .ms_search_once_per_call(search_fn)
    for (i in seq_along(slots)) {
      row <- rows[[i]]
      if (!identical(row$llm_decision[[1]], "retry_search")) {
        next
      }
      classified <- .ms_semantic_review_classify_retry(row, slots[[i]]$target)
      rows[[i]] <- classified$row
      if (is.na(classified$query)) {
        next
      }
      retries <- retries + 1L
      retrieved <- .ms_semantic_review_retrieve_retry(slots[[i]], classified$query, source_policy, top_n, search_once)
      rows[[i]] <- .ms_llm_add_exploration_metadata(
        rows[[i]],
        used = TRUE,
        queries = classified$query,
        candidate_gain = retrieved$gain
      )
      if (retrieved$gain > 0L) {
        pending[[length(pending) + 1L]] <- list(slot = i, candidates = retrieved$candidates)
      }
    }
  }
  awaiting <- vapply(pending, `[[`, integer(1), "slot")
  is_final <- !seq_along(slots) %in% awaiting

  # Escalation: a final reject_shortlist becomes request_new_term.
  escalations <- 0L
  for (i in which(is_final)) {
    if (identical(rows[[i]]$llm_decision[[1]], "reject_shortlist")) {
      rows[[i]] <- .ms_llm_escalate_unresolved_rejection(NULL, list(assessment = rows[[i]]))$assessment
      escalations <- escalations + 1L
    }
  }

  # Validators, for every bundle unit, rebuilt from the packet.
  previous_findings <- if (pass == 2L) .ms_semantic_review_read_findings(review_dir) else .ms_semantic_review_empty_findings()
  new_findings <- list()
  for (u in seq_along(packet$units)) {
    unit <- packet$units[[u]]
    if (!identical(.ms_semantic_review_cell(unit$unit_kind), "bundle")) {
      next
    }
    members <- which(vapply(slots, function(s) s$unit_index == u, logical(1)))
    validated <- .ms_semantic_review_validate_bundle(unit, slots[members], rows[members])
    for (j in seq_along(members)) {
      rows[[members[[j]]]] <- validated$rows[[j]]
    }
    new_findings[[length(new_findings) + 1L]] <- validated$findings
  }
  findings <- do.call(.ms_semantic_review_union_findings, c(list(previous_findings), new_findings))

  # The record: at pass 1 one row per target; at pass 2 the record on disk
  # with the reassessed rows replaced.
  final_rows <- .ms_llm_normalize_assessment_rows(dplyr::bind_rows(rows))
  if (pass == 2L) {
    record <- .ms_semantic_review_read_record(review_dir)
    record_keys <- .ms_semantic_review_identity_key(record)
    replace <- match(slot_keys, record_keys)
    for (i in seq_along(slots)) {
      if (!is.na(replace[[i]])) {
        record[replace[[i]], ] <- final_rows[i, , drop = FALSE]
      } else {
        record <- dplyr::bind_rows(record, final_rows[i, , drop = FALSE])
      }
    }
    record <- .ms_llm_normalize_assessment_rows(record)
  } else {
    record <- final_rows
  }

  # The merge: the final targets' candidates with their assessment columns. At
  # pass 2 that is every reassessed slot of the continuation packet (a
  # fallback slot with its pass-1 candidates); the slots that were final at
  # pass 1 were merged then.
  top_n <- .ms_semantic_review_top_n_from_packet(packet)
  merge_slots <- which(is_final & (pass == 1L | vapply(slots, `[[`, logical(1), "reassess")))
  candidates <- dplyr::bind_rows(lapply(slots[merge_slots], `[[`, "candidates"))
  merged <- if (nrow(candidates) > 0L) {
    .ms_semantic_merge_llm_assessments(
      candidates,
      assessments = final_rows[merge_slots, , drop = FALSE],
      top_n = top_n
    )
  } else {
    candidates
  }
  targets <- dplyr::bind_rows(lapply(slots, `[[`, "target"))
  final_targets <- targets[merge_slots, , drop = FALSE]

  # What the result describes is the whole session, never the continuation
  # subset: at pass 2 the targets are every pass-1 target, and the suggestions
  # every pass-1 slot's candidates (the continuation's for a reassessed slot,
  # pass 1's otherwise) merged with the record.
  if (pass == 2L) {
    session_targets <- dplyr::bind_rows(lapply(pass_1_slots, `[[`, "target"))
    session_candidates <- dplyr::bind_rows(lapply(seq_along(pass_1_slots), function(j) {
      here <- match(pass_1_keys[[j]], slot_keys)
      if (!is.na(here) && isTRUE(slots[[here]]$reassess)) {
        slots[[here]]$candidates
      } else {
        pass_1_slots[[j]]$candidates
      }
    }))
    session_merged <- if (nrow(session_candidates) > 0L) {
      .ms_semantic_merge_llm_assessments(session_candidates, assessments = record, top_n = top_n)
    } else {
      session_candidates
    }
  } else {
    session_targets <- targets
    session_merged <- merged
  }

  # Persistence, as one atomic set after the containment check. The harness
  # file is never copied into `review/`; when the harness wrote it at the
  # packet's default location there, it is replaced with its redacted form.
  writes <- list()
  harness_path <- .ms_semantic_review_file(review_dir, "assessments", pass)
  same_file <- !is.na(read$path) && identical(normalizePath(read$path, mustWork = FALSE), normalizePath(harness_path, mustWork = FALSE))
  if (same_file && length(redacted$changed) > 0L) {
    writes[[harness_path]] <- .ms_sdp_extension_csv_bytes(harness, na = "")
  }
  writes[[.ms_semantic_review_file(review_dir, "record")]] <- .ms_semantic_review_record_bytes(record)
  writes[[.ms_semantic_review_file(review_dir, "findings")]] <- .ms_semantic_review_findings_bytes(findings)
  next_packet <- NULL
  if (length(pending) > 0L) {
    continuation <- .ms_semantic_review_pass_2_packet(packet, slots, rows, pending, findings)
    writes[[pass_2_path]] <- .ms_semantic_review_canonical_bytes(continuation)
    next_packet <- pass_2_path
  }
  suggestions_out <- NULL
  if (identical(input$kind, "package") && nrow(final_targets) > 0L) {
    rewrite <- .ms_semantic_review_rewrite_suggestions(input$path, merged, final_targets)
    if (!is.null(rewrite)) {
      writes[[rewrite$path]] <- rewrite$bytes
      suggestions_out <- rewrite$rows
    }
  }
  if (!dir.exists(review_dir)) {
    dir.create(review_dir, recursive = TRUE)
  }
  .ms_assert_managed_path_contained(review_dir, names(writes)[startsWith(names(writes), paste0(review_dir, "/")) | dirname(names(writes)) == review_dir])
  if (identical(input$kind, "package")) {
    .ms_assert_managed_path_contained(input$path, names(writes))
  }
  .ms_sdp_extension_atomic_write_set(writes)
  if (length(redacted$changed) > 0L) {
    cli::cli_warn(c(
      "Secrets were redacted from the harness's assessments before they reached the record:",
      .ms_cli_bullets(redacted$changed, "*"),
      if (same_file) c("i" = "The harness file in {.path {review_dir}} was replaced with its redacted form.")
    ))
  }

  attr(record, "semantic_validator_findings") <- findings
  suggestions <- suggestions_out %||% session_merged
  dictionary <- if (identical(input$kind, "package")) {
    .ms_review_source_frames(input$path)[["column_dictionary.csv"]] %||% tibble::tibble()
  } else {
    input$dict
  }
  attr(dictionary, "semantic_suggestions") <- suggestions
  attr(dictionary, "semantic_targets") <- session_targets[, .ms_semantic_target_cols(), drop = FALSE]
  attr(dictionary, "semantic_llm_assessments") <- record

  status <- if (length(pending) > 0L) "awaiting_pass_2" else "complete"
  decisions <- table(factor(final_rows$llm_decision, levels = .ms_semantic_review_decision_vocabulary()), useNA = "no")
  summary <- list(
    decisions = stats::setNames(as.integer(decisions), names(decisions)),
    errors = errors,
    downgrades = downgrades,
    escalations = escalations,
    retries = retries,
    awaiting_pass_2 = length(pending),
    kept_pass_1 = kept_pass_1
  )
  if (!isTRUE(quiet)) {
    cli::cli_inform(c(
      "Ingested {nrow(final_rows)} assessment{?s} for pass {pass}: status {.val {status}}.",
      "i" = "{errors} error row{?s}, {downgrades} downgrade{?s}, {escalations} escalation{?s}, {retries} retr{?y/ies}.",
      if (kept_pass_1 > 0L) c("!" = "{kept_pass_1} reassessed target{?s} kept {?its/their} pass-1 answer because the pass-2 answer was missing or unusable; there is no third pass."),
      if (!is.null(next_packet)) c("i" = "Continuation packet written to {.path {next_packet}}; have the harness answer it, then ingest again.")
    ))
  }
  invisible(list(
    status = status,
    pass = pass,
    packet_id = current_id,
    next_packet = next_packet,
    assessments = record,
    findings = findings,
    suggestions = suggestions,
    targets = session_targets[, .ms_semantic_target_cols(), drop = FALSE],
    dictionary = dictionary,
    summary = summary
  ))
}
