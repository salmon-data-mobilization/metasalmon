# The commons register is evidence about a concept, not an SDP retrieval row.
# Preserve that distinction through intake and rendering (hub B-278/B-279).

.ms_commons_gap_fields <- function() {
  c(
    "concept", "title", "context", "registry", "status", "mint_target", "state",
    "proposal", "rejected_because", "evidence_needed", "blocked_by", "conflicts",
    "note", "card_status", "verified"
  )
}

.ms_commons_gap_abort <- function(detail) {
  # Validation text may contain a parser message or a source field name. It is
  # external data, and must never become a cli interpolation template.
  cli::cli_abort(c(
    "Invalid `commons_gaps` export.",
    "x" = .ms_cli_escape(.ms_redact_secrets(detail))
  ))
}

.ms_validate_commons_gap <- function(row) {
  fields <- .ms_commons_gap_fields()
  if (!is.list(row) || is.null(names(row)) || anyDuplicated(names(row)) ||
      !setequal(names(row), fields)) {
    .ms_commons_gap_abort("Each record must be an object with the emitted commons fields.")
  }
  enums <- list(
    context = c("biology", "ecology", "population-structure", "assessment", "management-governance", "data-informatics"),
    registry = c("smn", "gcdfo", "psc-cv", "external"),
    status = c("no-term", "wrong-granularity", "contested"),
    mint_target = c("smn", "gcdfo", "psc-cv", "new-scheme", "do-not-mint", "undecided"),
    # A minted term is not a gap: the source schema requires its removal.
    state = c("open", "proposed", "rejected"),
    card_status = c("draft", "stable", "deprecated")
  )
  scalar_text <- function(x, minimum = 1L) {
    is.character(x) && length(x) == 1L && !is.na(x) && nchar(x) >= minimum
  }
  for (field in names(enums)) {
    if (!scalar_text(row[[field]]) || !row[[field]] %in% enums[[field]]) {
      .ms_commons_gap_abort(sprintf("Invalid enum or type in %s.", field))
    }
  }
  for (field in c("concept", "title", "note")) {
    minimum <- if (field == "note") 40L else 1L
    if (!scalar_text(row[[field]], minimum)) {
      .ms_commons_gap_abort(sprintf("Invalid string in %s.", field))
    }
  }
  for (field in c("proposal", "rejected_because", "evidence_needed", "conflicts")) {
    minimum <- if (field == "proposal") 1L else 40L
    if (!is.null(row[[field]]) && !scalar_text(row[[field]], minimum)) {
      .ms_commons_gap_abort(sprintf("Invalid nullable string in %s.", field))
    }
  }
  if (!is.null(row$proposal) &&
      !grepl("^[A-Za-z][A-Za-z0-9+.-]*:", row$proposal)) {
    .ms_commons_gap_abort("A proposal must be an absolute URI.")
  }
  if (row$state %in% c("proposed", "rejected") && is.null(row$proposal)) {
    .ms_commons_gap_abort("Proposed and rejected gaps require a proposal URI.")
  }
  if (row$state == "rejected" &&
      (is.null(row$rejected_because) || is.null(row$evidence_needed))) {
    .ms_commons_gap_abort("Rejected gaps require rejection reasons and evidence needed.")
  }
  if (!is.logical(row$verified) || length(row$verified) != 1L || is.na(row$verified)) {
    .ms_commons_gap_abort("verified must be a JSON boolean.")
  }
  # JSON arrays remain lists, including the empty array. A scalar string is
  # not accepted as a convenient substitute for a dependency list.
  if (!is.list(row$blocked_by) || !is.null(names(row$blocked_by)) ||
      !all(vapply(row$blocked_by, scalar_text, logical(1)))) {
    .ms_commons_gap_abort("blocked_by must be an array of nonempty concept strings.")
  }
  row
}

.ms_commons_gap_hold <- function(row) {
  # These holds preserve already-recorded decisions and unsettled evidence.
  # Retires when a reviewed successor commons lifecycle/routing contract
  # replaces these conditions in both packages; overrides never retire them.
  reasons <- character()
  if (row$state == "proposed") reasons <- c(reasons, "proposed")
  if (row$state == "rejected") reasons <- c(reasons, "rejected")
  if (row$mint_target == "do-not-mint") reasons <- c(reasons, "do-not-mint")
  if (length(row$blocked_by)) reasons <- c(reasons, "blocked")
  if (!is.null(row$conflicts)) reasons <- c(reasons, "conflicted")
  if (row$status == "contested") reasons <- c(reasons, "contested")
  if (!is.null(row$evidence_needed)) reasons <- c(reasons, "evidence-needed")
  if (row$mint_target %in% c("psc-cv", "new-scheme", "undecided")) {
    reasons <- c(reasons, "unsupported-target")
  }
  if (row$card_status == "deprecated") reasons <- c(reasons, "deprecated-card")
  paste(reasons, collapse = "; ")
}

.ms_read_commons_term_gaps <- function(path) {
  if (!is.character(path) || length(path) != 1L || is.na(path) || !nzchar(path) ||
      !file.exists(path) || isTRUE(file.info(path)$isdir)) {
    .ms_commons_gap_abort("commons_gaps must name one existing JSON export file.")
  }
  document <- tryCatch(
    jsonlite::fromJSON(path, simplifyVector = FALSE),
    error = function(e) .ms_commons_gap_abort(conditionMessage(e))
  )
  if (!is.list(document) || is.null(names(document)) ||
      !identical(names(document), "gaps") || !is.list(document$gaps) ||
      !is.null(names(document$gaps))) {
    .ms_commons_gap_abort("Expected an object containing the top-level gaps array.")
  }
  rows <- lapply(document$gaps, .ms_validate_commons_gap)
  # Initializing from the established prototype keeps every old column and
  # type intact, without asserting absent dataset/candidate/LLM evidence.
  out <- .empty_term_gap_result()[rep(NA_integer_, length(rows)), , drop = FALSE]
  for (field in .ms_commons_gap_fields()) {
    column <- paste0("commons_", field)
    out[[column]] <- if (field == "blocked_by") {
      # character(0), rather than unlist(list())'s NULL, preserves [] as an
      # empty dependency array when a returned row is serialized to JSON.
      lapply(rows, function(row) as.character(unlist(row[[field]], use.names = FALSE)))
    } else if (field == "verified") {
      vapply(rows, `[[`, logical(1), field)
    } else {
      vapply(rows, function(row) if (is.null(row[[field]])) NA_character_ else row[[field]], character(1))
    }
  }
  out$commons_hold_reason <- vapply(rows, .ms_commons_gap_hold, character(1))
  out$search_query <- out$commons_title
  out$target_label <- out$commons_title
  out$gap_detection_basis <- rep("commons_register", length(rows))
  # Assign into a character vector so an empty export keeps the SDP
  # prototype's type; ifelse(logical(0), ...) would produce logical(0).
  out$placement_recommendation <- out$commons_mint_target
  out$placement_recommendation[nzchar(out$commons_hold_reason)] <- "skip"
  out
}

.ms_commons_row_from_gap <- function(gaps, i) {
  row <- lapply(.ms_commons_gap_fields(), function(field) {
    value <- gaps[[paste0("commons_", field)]][[i]]
    if (field == "blocked_by") {
      if (is.null(value)) .ms_commons_gap_abort("blocked_by cannot be null in a rendered commons row.")
      return(as.list(value))
    }
    if (length(value) == 1L && is.na(value)) return(NULL)
    value
  })
  names(row) <- .ms_commons_gap_fields()
  .ms_validate_commons_gap(row)
}

.ms_render_commons_term_requests <- function(gaps, issue_labels, smn_template,
                                            smn_repo, gcdfo_template, gcdfo_repo) {
  needed <- paste0("commons_", .ms_commons_gap_fields())
  if (!all(needed %in% names(gaps))) {
    .ms_commons_gap_abort("Rendered commons rows must retain all source fields.")
  }
  if (!nrow(gaps)) return(tibble::tibble())
  rows <- lapply(seq_len(nrow(gaps)), function(i) .ms_commons_row_from_gap(gaps, i))
  # Rederive holds from source fields every time. Altering the display reason,
  # placement recommendation, ask or scope overrides cannot revive a row.
  holds <- vapply(rows, .ms_commons_gap_hold, character(1))
  scopes <- vapply(seq_along(rows), function(i) {
    if (nzchar(holds[[i]])) "skip" else rows[[i]]$mint_target
  }, character(1))
  out <- tibble::as_tibble(gaps)
  out$commons_hold_reason <- holds
  out$request_scope <- scopes
  out$profile_name <- NA_character_
  out$request_title <- paste0(
    ifelse(scopes == "skip", "Hold commons ontology gap: ", "Commons ontology gap: "),
    out$commons_title
  )
  out$ontology_repo <- ifelse(scopes == "smn", smn_repo,
                            ifelse(scopes == "gcdfo", gcdfo_repo, NA_character_))
  out$request_body <- vapply(seq_along(rows), function(i) {
    row <- rows[[i]]
    show <- function(value) if (is.null(value) || !length(value)) "None" else paste(value, collapse = ", ")
    template <- if (scopes[[i]] == "smn") smn_template else if (scopes[[i]] == "gcdfo") gcdfo_template else "Not routed"
    repo <- if (is.na(out$ontology_repo[[i]])) "Not routed" else paste0("https://github.com/", out$ontology_repo[[i]])
    paste0(
      "## Commons ontology gap\n\n",
      "Concept card: `", row$concept, ".md` in salmon-knowledge-commons.\n",
      "Concept title: ", row$title, "\nContext: ", row$context, "\n\n",
      "## Draft gap evidence\n\n", row$note, "\n\n",
      "## Curator choices required\n\nCurator definition required.\n",
      "Curator term type required.\nNo term IRI, definition or type is selected by this request.\n\n",
      "## Provenance and lifecycle\n\n",
      "- Registry with gap: ", row$registry, "\n- Proposed mint target: ", row$mint_target,
      "\n- State: ", row$state, "\n- Gap status: ", row$status,
      "\n- Card status: ", row$card_status, "\n- Verified: ", if (row$verified) "true" else "false",
      "\n- Existing proposal: ", show(row$proposal),
      "\n- Rejection reason: ", show(row$rejected_because),
      "\n- Evidence needed: ", show(row$evidence_needed),
      "\n- Blocked by: ", show(row$blocked_by), "\n- Conflicts: ", show(row$conflicts),
      "\n- Hold reasons: ", if (nzchar(holds[[i]])) holds[[i]] else "None",
      "\n- Request route: ", scopes[[i]], "\n- Template: ", template,
      "\n- Repository: ", repo, "\n"
    )
  }, character(1))
  if (is.null(issue_labels) || !length(issue_labels)) {
    out$issue_labels <- rep(list(NULL), nrow(out))
  } else if (!is.list(issue_labels)) {
    out$issue_labels <- rep(list(as.character(issue_labels)), nrow(out))
  } else if (length(issue_labels) %in% c(1L, nrow(out))) {
    out$issue_labels <- rep(issue_labels, length.out = nrow(out))
  } else {
    cli::cli_abort("`issue_labels` must have length one or the number of gaps.")
  }
  # Match the existing SDP normalization: exact empty strings become missing,
  # whitespace is preserved, and duplicates are removed on both input shapes.
  out$issue_labels <- lapply(out$issue_labels, function(labels) {
    labels <- .trim_empties(as.character(labels))
    if (!length(labels)) return(NULL)
    unique(labels)
  })
  out
}
