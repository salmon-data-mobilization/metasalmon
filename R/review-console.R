# R-native semantic review (roadmap stream S5, backlog #74).
#
# The documented review workflow used to leave R: open
# `metadata/column_dictionary.csv` in a spreadsheet, read
# `semantic_suggestions.csv` as a shortlist, copy an IRI across by hand. The
# only record of that decision was the mutated CSV -- the one unreproducible
# link in a chain that is otherwise byte-reproducible and guarded.
#
# THE DESIGN DECISION THAT DEFINES THIS FILE (execplan decision log, 2026-08-11;
# restated by Brett 2026-08-25): the console prints the exact
# `accept_suggestion(...)` call and the user pastes it into a script. There is
# no TUI, no `readline()` loop, no menu. **The paste IS the audit trail** -- an
# interactive prompt would make the decision as unreproducible as the
# spreadsheet it replaces.
#
# That makes the printed call load-bearing rather than decorative. A printed
# call that does not parse, or that names a column that does not exist, is the
# defect this feature could most easily ship with, so
# `.ms_review_accept_call()` computes the argument set by *resolving it* and
# `tests/testthat/test-review-console.R` evaluates the printed string and
# checks it produces the decision it claims.
#
# WHY THIS FILE DOES NOT ESCAPE ITS EXTERNAL TEXT. Ontology labels,
# definitions, and LLM rationales are third-party text, and `AGENTS.md`
# requires that such text never become a cli template. This file satisfies that
# contract by not putting the text on a template path at all:
# `.ms_review_render_lines()` returns a plain character vector and
# `print.ms_semantic_review()` emits it with `cat()`, which has no template
# semantics. Escaping on that path would be actively wrong -- a definition
# containing `{reach}` would print as `{{reach}}`, corrupting exactly the text
# the rule exists to protect. Escaping is the mechanism for the cli path, and
# the cli path is where it is applied: every `cli_abort()`/`cli_warn()` below
# that carries a user- or ontology-supplied string wraps it in
# `.ms_cli_escape()`/`.ms_cli_bullets()`, and `test-cli-safety-guard.R` walks
# the installed namespace, so it checks those automatically. The `cat()` branch
# gets its own pinned test instead ("a definition containing braces prints
# literally"), because a static guard cannot see a path it does not model.

# One (target file, target row, target field) triple. `target_row_key` is
# already built by `.ms_semantic_discover_targets()` from the identifying
# columns, so this is a re-spelling of an address the producer chose, not a new
# one.
.ms_review_slot_id <- function(suggestions) {
  paste(
    as.character(suggestions$target_sdp_file),
    as.character(suggestions$target_row_key),
    as.character(suggestions$target_sdp_field),
    sep = "|"
  )
}

# Which metadata columns identify the row a target writes into. Anything not
# listed here has no write-back address and is refused rather than silently
# shown as acceptable -- the lesson of the execplan's superseded "show method
# rows but do not let anyone accept them" decision.
.ms_review_target_keys <- function(target_file) {
  switch(
    target_file,
    "column_dictionary.csv" = c("dataset_id", "table_id", "column_name"),
    "codes.csv" = c("dataset_id", "table_id", "column_name", "code_value"),
    "tables.csv" = c("dataset_id", "table_id"),
    NULL
  )
}

.ms_review_writable_files <- function() {
  c("column_dictionary.csv", "codes.csv", "tables.csv")
}

# Whether each target is a code's slot: one whose write-back address includes
# `code_value`, which today means `codes.csv`. Read from
# `.ms_review_target_keys()` rather than spelled a second time, so the two cannot
# disagree. A code's slot stays one when its `code_value` is empty, as a
# `codes.csv` row's may be when it supplies `vocabulary_iri` instead.
.ms_review_is_code_slot <- function(target_file) {
  vapply(
    as.character(target_file),
    function(file) !is.na(file) && "code_value" %in% .ms_review_target_keys(file),
    logical(1),
    USE.NAMES = FALSE
  )
}

# The `decision` values `apply_sdp_semantics()` writes into
# `semantic_suggestions.csv`, and how each maps back onto a review row.
# `not_selected` is the sibling of an accept within the same slot: the slot IS
# decided, but this candidate is not the one, so it carries no decision of its
# own and the accepted row in the same slot supplies it.
.ms_review_recorded_decisions <- function() {
  c(accepted = "accept", accept = "accept", rejected = "reject")
}

# A candidate's IRI as a decision records it: trimmed, with the leading
# `REVIEW:` marker removed, which is what `accept_suggestion(rank = )` and a
# replayed decision put in `decision_iri`. Whether a decision names a given
# candidate is asked twice. `accept_suggestion(iri = )` picks the candidate's
# row with it, and `apply_sdp_semantics()` takes the candidate's `term_type`
# only when the decision row carries the accepted IRI. Both read this one
# rendering. While the writer compared the stored IRI with its marker, a
# candidate stored as `REVIEW: <IRI>` was picked by the first and not recognised
# by the second, so it wrote `skos_concept` (hub item B-221).
.ms_review_decision_iri <- function(x) {
  .ms_strip_review_iri(trimws(as.character(x)))
}

# Replay the decisions recorded in the package onto a freshly built review.
.ms_review_seed_recorded_decisions <- function(review, suggestions) {
  if (!"decision" %in% names(suggestions) || nrow(review) == 0L) {
    return(review)
  }
  recorded <- .ms_review_recorded_decisions()
  decision <- trimws(as.character(suggestions$decision))
  reason <- if ("decision_reason" %in% names(suggestions)) {
    as.character(suggestions$decision_reason)
  } else {
    rep(NA_character_, length(decision))
  }
  # `review` is built from `suggestions` row for row and then filtered, so the
  # positions still line up here -- this runs before any subsetting.
  for (i in seq_len(nrow(review))) {
    value <- decision[[i]]
    if (is.na(value) || !value %in% names(recorded)) {
      next
    }
    review$decision[[i]] <- recorded[[value]]
    review$decision_reason[[i]] <- reason[[i]]
    if (identical(recorded[[value]], "accept")) {
      review$decision_iri[[i]] <- .ms_strip_review_iri(.ms_scalar_text(review$iri[[i]]))
    }
  }
  review
}

# Row indices in `frame` matching one suggestion row on the identifying keys.
# A key the suggestion leaves blank is not constrained -- `table_meta` targets
# carry no `column_name`, and requiring one would match nothing.
.ms_review_match_rows <- function(frame, row, keys) {
  if (!inherits(frame, "data.frame") || nrow(frame) == 0L) {
    return(integer())
  }
  matches <- rep(TRUE, nrow(frame))
  for (key in keys) {
    if (!key %in% names(frame) || !key %in% names(row)) {
      next
    }
    value <- .ms_scalar_text(row[[key]])
    if (!nzchar(value)) {
      next
    }
    column <- as.character(frame[[key]])
    matches <- matches & !is.na(column) & trimws(column) == value
  }
  which(matches)
}

# A slot is unfilled when it is blank or still carries the `REVIEW:` marker.
# `REVIEW:`-prefixed values are non-blank, which is precisely why the review
# queue cannot just test for emptiness -- and why `apply_sdp_semantics()` has
# to write with `overwrite = TRUE`.
.ms_review_is_unfilled <- function(value) {
  text <- as.character(value %||% "")
  text[is.na(text)] <- ""
  !nzchar(trimws(text)) | vapply(text, .ms_is_review_iri, logical(1), USE.NAMES = FALSE)
}

# The metadata frames a review reads its current values from. Accepts the same
# three shapes the accessors do, so `review_semantics()` never has to know
# whether it was handed a package or an in-memory dictionary.
.ms_review_source_frames <- function(x) {
  if (is.character(x) && length(x) == 1L && !is.na(x)) {
    if (!dir.exists(x)) {
      cli::cli_abort("Directory {.path {x}} does not exist.")
    }
    read_one <- function(file_name) {
      located <- .ms_locate_metadata_file(x, file_name)
      if (length(located) != 1L || is.na(located) || dir.exists(located)) {
        return(NULL)
      }
      tibble::as_tibble(.ms_read_metadata_csv(located))
    }
    return(list(
      "column_dictionary.csv" = read_one("column_dictionary.csv"),
      "codes.csv" = read_one("codes.csv"),
      "tables.csv" = read_one("tables.csv")
    ))
  }
  if (inherits(x, "data.frame")) {
    return(list("column_dictionary.csv" = tibble::as_tibble(x)))
  }
  if (is.list(x)) {
    return(list(
      "column_dictionary.csv" = if (inherits(x$dict, "data.frame")) tibble::as_tibble(x$dict) else NULL,
      "codes.csv" = if (inherits(x$codes, "data.frame")) tibble::as_tibble(x$codes) else NULL,
      "tables.csv" = if (inherits(x$table_meta, "data.frame")) tibble::as_tibble(x$table_meta) else NULL
    ))
  }
  list()
}

#' Review semantic suggestions in the console
#'
#' Builds a re-runnable review queue from suggestions that already exist. One
#' entry per unfilled semantic slot, each with its ranked shortlist and the
#' exact [accept_suggestion()] call that decides it -- printing that call is the
#' feature: paste it into a script and the decision becomes reproducible,
#' which the spreadsheet workflow this replaces never was.
#'
#' **This never contacts a network or an LLM.** It reads the
#' `semantic_suggestions` attribute (or `semantic_suggestions.csv`) that
#' `suggest_semantics()` / `create_sdp()` already produced. When those
#' suggestions carry LLM review -- only possible if they were generated with
#' `llm_assess = TRUE` -- this surfaces it; it never generates it.
#'
#' @param x A written package path, a dictionary carrying the
#'   `semantic_suggestions` attribute, or the artifact list returned by
#'   `infer_salmon_datapackage_artifacts()`.
#' @param include_filled Logical; if `TRUE`, also queue slots that already hold
#'   a final (non-`REVIEW:`) IRI. Defaults to `FALSE`.
#' @param max_candidates Maximum candidates shown per slot. `Inf` shows all.
#' @param columns Optional character vector restricting the queue to these
#'   column names.
#'
#' @return An `ms_semantic_review` tibble subclass, one row per candidate, in
#'   the order the ranked producer emitted them. Carries the package path (when
#'   there is one) as the `review_path` attribute.
#' @seealso [accept_suggestion()], [reject_suggestion()], [apply_sdp_semantics()]
#' @export
#'
#' @examples
#' dict <- tibble::tibble(
#'   dataset_id = "demo-1",
#'   table_id = "spawners",
#'   column_name = "spawner_count",
#'   term_iri = NA_character_
#' )
#' attr(dict, "semantic_suggestions") <- tibble::tibble(
#'   dataset_id = "demo-1",
#'   table_id = "spawners",
#'   column_name = "spawner_count",
#'   code_value = NA_character_,
#'   dictionary_role = "variable",
#'   target_scope = "column",
#'   target_sdp_file = "column_dictionary.csv",
#'   target_sdp_field = "term_iri",
#'   target_row_key = "demo-1/spawners/spawner_count",
#'   label = "Spawner Abundance",
#'   iri = "https://w3id.org/smn/SpawnerAbundance",
#'   source = "smn",
#'   ontology = "smn",
#'   definition = "Mature salmon returning to spawn.",
#'   score = 4.9
#' )
#'
#' review <- review_semantics(dict)
#' review
review_semantics <- function(x,
                             include_filled = FALSE,
                             max_candidates = 5L,
                             columns = NULL) {
  queue <- .ms_review_queue(x, include_filled = include_filled, columns = columns)
  review <- queue$review

  if (is.finite(max_candidates)) {
    review <- review[review$rank <= as.integer(max_candidates), , drop = FALSE]
  }

  attr(review, "review_path") <- queue$review_path
  class(review) <- c("ms_semantic_review", class(tibble::tibble()))
  review
}

# The review queue: which slots still need a decision, with every candidate
# row that would be shown for them. This is the one rule both
# `review_semantics()` and `write_semantic_review_packet()` apply (hub item
# B-326), so the packet a harness judges holds exactly the slots the console
# would show and never a fresh discovery -- re-running discovery would drop
# every slot `create_sdp()` pre-filled with a `REVIEW:` marker, because the
# discovery code treats a marked slot as filled.
#
# Returns the review rows (one per candidate, before `max_candidates`), the
# suggestion rows they were built from (`suggestions[source_row, ]` is the row
# behind `review[i, ]`), and the package path when there is one.
.ms_review_queue <- function(x, include_filled = FALSE, columns = NULL) {
  suggestions <- semantic_suggestions(x)
  if (is.null(suggestions) || nrow(suggestions) == 0L) {
    cli::cli_abort(c(
      "No semantic suggestions to review.",
      "i" = "Run {.fn suggest_semantics}, or {.fn create_sdp} with {.code seed_semantics = TRUE}, first."
    ))
  }

  required <- c(
    "column_name", "dictionary_role", "iri", "label",
    "target_sdp_file", "target_sdp_field", "target_row_key"
  )
  missing_cols <- setdiff(required, names(suggestions))
  if (length(missing_cols) > 0) {
    cli::cli_abort(
      "Suggestions are missing required columns: {.field {missing_cols}}"
    )
  }

  suggestions <- .ms_semantic_add_missing_cols(
    suggestions,
    c("dataset_id", "table_id", "code_value", "source", "ontology", "definition")
  )
  if (!"score" %in% names(suggestions)) {
    suggestions$score <- NA_real_
  }

  # Only slots with a write-back address, and only IRI fields. `dataset.csv`
  # targets a comma-joined `keywords` list rather than a single IRI, so it has
  # no "accept this candidate" semantics; queueing it would show a row that
  # cannot be decided, which is the failure mode the execplan's decision log
  # reversed itself over.
  writable <- as.character(suggestions$target_sdp_file) %in% .ms_review_writable_files()
  iri_field <- grepl("_iri$", as.character(suggestions$target_sdp_field))
  has_iri <- !is.na(suggestions$iri) & nzchar(trimws(as.character(suggestions$iri)))
  keep <- writable & iri_field & has_iri
  # `any(!keep)` first: `paste0(character(0), " - ", character(0))` recycles the
  # length-one separator and returns `" - "`, so a length test on the pasted
  # vector reports a dropped target on every call that dropped nothing.
  dropped <- if (any(!keep)) {
    unique(paste0(
      as.character(suggestions$target_sdp_file)[!keep], " \u00b7 ",
      as.character(suggestions$target_sdp_field)[!keep]
    ))
  } else {
    character()
  }
  suggestions <- suggestions[keep, , drop = FALSE]
  if (length(dropped) > 0) {
    cli::cli_inform(c(
      "Some suggestions target fields this review cannot decide, and are not queued.",
      .ms_cli_bullets(dropped, "*"),
      "i" = "Edit those in the metadata CSVs directly."
    ))
  }

  if (!is.null(columns)) {
    # A `columns` value naming nothing is a typo, and it must say so. Filtering
    # first and then reporting an empty queue told the user "every slot that
    # had a shortlist already holds a final IRI" -- which reads as SUCCESS, on
    # a package where nothing had been reviewed at all.
    known <- unique(as.character(suggestions$column_name))
    unknown <- setdiff(as.character(columns), known)
    if (length(unknown) > 0) {
      cli::cli_abort(c(
        "No suggestions target {cli::qty(length(unknown))}{?this/these} column{?s}.",
        .ms_cli_bullets(unknown, "x"),
        .ms_cli_bullets(utils::head(sort(known[nzchar(known)], method = "radix"), 20L), "i")
      ))
    }
    suggestions <- suggestions[as.character(suggestions$column_name) %in% columns, , drop = FALSE]
  }

  frames <- .ms_review_source_frames(x)
  review_path <- if (is.character(x) && length(x) == 1L) x else NA_character_

  slot_id <- .ms_review_slot_id(suggestions)
  # Deliberately NO re-ranking. The incoming row order is the ranked order
  # `.ms_retrieve_semantic_target_candidates()` produced, and that ordering is
  # already pinned to C collation and registered in the collation guard.
  # Re-sorting here would create a SECOND ordering of the same candidates that
  # could disagree with the top-1 the seeded auto-apply already wrote into the
  # dictionary -- two renderings of one decision. `rank` is therefore a
  # position, not a sort.
  rank <- integer(length(slot_id))
  seen <- new.env(parent = emptyenv())
  for (i in seq_along(slot_id)) {
    key <- slot_id[[i]]
    position <- (seen[[key]] %||% 0L) + 1L
    seen[[key]] <- position
    rank[[i]] <- position
  }

  current <- vapply(seq_len(nrow(suggestions)), function(i) {
    row <- suggestions[i, , drop = FALSE]
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

  review <- tibble::tibble(
    slot_id = slot_id,
    dataset_id = as.character(suggestions$dataset_id),
    table_id = as.character(suggestions$table_id),
    column_name = as.character(suggestions$column_name),
    code_value = as.character(suggestions$code_value),
    role = as.character(suggestions$dictionary_role),
    target_file = as.character(suggestions$target_sdp_file),
    target_field = as.character(suggestions$target_sdp_field),
    target_row_key = as.character(suggestions$target_row_key),
    current_value = current,
    rank = as.integer(rank),
    label = as.character(suggestions$label),
    iri = as.character(suggestions$iri),
    source = as.character(suggestions$source),
    ontology = as.character(suggestions$ontology),
    definition = as.character(suggestions$definition),
    score = suppressWarnings(as.numeric(suggestions$score)),
    # Computed here, from the candidate row, with the same helper
    # `apply_semantic_suggestions()` uses -- so the reviewed write and the
    # seeded write cannot disagree about the same candidate's `term_type`.
    term_type = vapply(
      seq_len(nrow(suggestions)),
      function(i) as.character(.ms_semantic_term_type(suggestions[i, , drop = FALSE])),
      character(1)
    ),
    llm_decision = if ("llm_decision" %in% names(suggestions)) as.character(suggestions$llm_decision) else NA_character_,
    llm_confidence = if ("llm_confidence" %in% names(suggestions)) suppressWarnings(as.numeric(suggestions$llm_confidence)) else NA_real_,
    llm_rationale = if ("llm_rationale" %in% names(suggestions)) as.character(suggestions$llm_rationale) else NA_character_,
    decision = NA_character_,
    decision_iri = NA_character_,
    decision_reason = NA_character_
  )

  # DECISIONS ALREADY ON DISK ARE READ BACK. `apply_sdp_semantics()` records
  # each decision in `semantic_suggestions.csv`, and until this existed nothing
  # read it: a reject CLEARS the field, a blank field reads as undecided, and
  # so the next `review_semantics()` asked the same question again with no sign
  # the user had ever answered it. A reviewer who works through sixteen slots,
  # rejects four and comes back tomorrow was shown those four as if they were
  # new. The round trip is the point of persisting the decision at all.
  review <- .ms_review_seed_recorded_decisions(review, suggestions)

  source_row <- seq_len(nrow(review))
  if (!isTRUE(include_filled)) {
    # A slot with an unknown current value (no frame to read, or an ambiguous
    # row match) is kept: dropping it would hide work, and the console labels
    # it "current: <unknown>" so the user can see why.
    unfilled <- is.na(review$current_value) | .ms_review_is_unfilled(review$current_value)
    # A recorded decision takes a slot out of the queue even though rejecting
    # leaves the field blank -- "blank" and "undecided" are different states,
    # and only `include_filled = TRUE` shows the decided ones again. A
    # hand-picked accept (`source = "user"`) is recorded with a decision, so
    # this is also what drops it.
    decided <- review$slot_id %in% unique(review$slot_id[!is.na(review$decision)])
    source_row <- which(unfilled & !decided)
    review <- review[source_row, , drop = FALSE]
  }

  list(
    review = review,
    suggestions = suggestions,
    source_row = source_row,
    review_path = review_path
  )
}

# --------------------------------------------------------------------------
# Console rendering
# --------------------------------------------------------------------------

# A browsable URL for a term, or `NA` when there is nothing safe to open.
# Refuses every scheme that is not http/https: an ontology IRI is external
# text, and turning a `javascript:` or `file:` string into a terminal hyperlink
# would make third-party data actionable with one click.
.ms_term_browse_url <- function(iri, source = NA_character_, ontology = NA_character_) {
  text <- .ms_scalar_text(iri)
  if (!nzchar(text)) {
    return(NA_character_)
  }
  source_text <- tolower(.ms_scalar_text(source))
  ontology_text <- tolower(.ms_scalar_text(ontology))

  url <- if (identical(source_text, "ols")) {
    # OLS4 resolves a term by ontology plus double-encoded IRI.
    if (nzchar(ontology_text) && !identical(ontology_text, "ols")) {
      paste0(
        "https://www.ebi.ac.uk/ols4/ontologies/", ontology_text,
        "/classes/", utils::URLencode(utils::URLencode(text, reserved = TRUE), reserved = TRUE)
      )
    } else {
      text
    }
  } else {
    # smn, gcdfo and nvs IRIs are already the canonical browsable form.
    text
  }

  if (!grepl("^https?://", url, ignore.case = TRUE)) {
    return(NA_character_)
  }
  url
}

# The IRI as it should appear on screen: clickable where the terminal supports
# it, and never hiding the URL where it does not. cli's own fallback drops the
# URL entirely when the link text differs from it, so the fallback is written
# out here rather than inherited.
.ms_review_iri_display <- function(iri, source, ontology) {
  text <- .ms_scalar_text(iri)
  url <- .ms_term_browse_url(iri, source, ontology)
  if (is.na(url)) {
    return(text)
  }
  if (isTRUE(cli::ansi_has_hyperlink_support())) {
    return(cli::style_hyperlink(text, url))
  }
  if (identical(url, text)) {
    return(text)
  }
  paste0(text, "  ", url)
}

# The variable the user actually bound the review to. `substitute()` answers
# for `print(rev)` but not for auto-printing at the prompt, where R calls the
# generic on an anonymous value -- and auto-printing is the common case, since
# `rev <- review_semantics(pkg)` is silent and the user then types `rev`. So
# fall back to finding the binding. Getting this wrong is not cosmetic: the
# printed call is meant to be pasted, and `accept_suggestion(review, ...)`
# against a review bound to `rev` fails with "object 'review' not found".
.ms_review_object_name <- function(x, expr = NULL, default = "review") {
  if (!is.null(expr) && is.name(expr)) {
    name <- as.character(expr)
    if (!identical(name, "x") && nzchar(name)) {
      return(name)
    }
  }
  .ms_binding_name_for(
    x,
    function(value) inherits(value, "ms_semantic_review") && identical(value, x),
    default = default
  )
}

# The name of a global binding holding this value, or `default`. Shared with
# `review_metadata()`, whose printed calls take a package *path* rather than a
# review object -- one scan, so the two console views cannot disagree about how
# they name the user's own variable.
.ms_binding_name_for <- function(x, matches, default) {
  # `ls()` is locale-ordered; radix keeps the choice reproducible when more
  # than one binding holds the same value.
  names_in_global <- sort(ls(globalenv()), method = "radix")
  for (name in names_in_global) {
    value <- tryCatch(get0(name, envir = globalenv(), inherits = FALSE), error = function(e) NULL)
    if (is.null(value)) {
      next
    }
    if (isTRUE(tryCatch(matches(value), error = function(e) FALSE))) {
      return(name)
    }
  }
  default
}

# NA-safe slot matching. Every comparison is guarded with `!is.na()` because
# `tables.csv` slots carry NO column name: `review$column_name == "x"` is then
# `NA`, and `df[NA, ]` inserts an all-NA row rather than dropping it. The first
# version of this file did the unguarded comparison, and the visible symptom
# was a printed call that could not run -- `accept_suggestion(review, "NA",
# "entity", ...)` for the table slot, and a spurious `table = "spawners"` on an
# unrelated dictionary slot that the phantom NA row had made look ambiguous.
# `column = NULL` selects the column-less (table-scope) slots deliberately.
#
# `code_value` has three states, and the third is the one hub queue B-151 was
# missing. `NULL` leaves it unconstrained; a value selects that code's slot; and
# a BLANK value (`""`, or `NA`, which `.ms_scalar_text()` reads as `""`)
# selects the slots that belong to no code: the column's own slot, or a
# table's. Without the third state a column-level slot could not be told apart
# from its own codes' slots when they share a role -- a measurement column's
# `entity_iri` and its codes' `entity` targets do -- because omitting
# `code_value` matched every code as well as the column.
#
# "Belongs to no code" is decided by the slot's file, not by its `code_value`
# alone. A `codes.csv` row may leave `code_value` empty when it supplies
# `vocabulary_iri`, which the codes schema allows, and discovery still gives it a
# code-level target. Reading an empty `code_value` as "no code" matched that
# slot and the column's own slot together, so the blank never settled anything
# for a column with such a row (Codex review of pull request #153).
.ms_review_match_slot_rows <- function(review, column, role, table = NULL, code_value = NULL) {
  keep <- rep(TRUE, nrow(review))
  has_column <- !is.na(review$column_name) & nzchar(trimws(review$column_name))
  keep <- if (is.null(column)) {
    keep & !has_column
  } else {
    keep & has_column & review$column_name == column
  }
  keep <- keep & !is.na(review$role) & review$role == role
  if (!is.null(table)) {
    keep <- keep & !is.na(review$table_id) & review$table_id == table
  }
  if (!is.null(code_value)) {
    code_value <- .ms_scalar_text(code_value)
    has_code <- !is.na(review$code_value) & nzchar(trimws(review$code_value))
    keep <- if (nzchar(code_value)) {
      keep & has_code & review$code_value == code_value
    } else {
      keep & !has_code & !.ms_review_is_code_slot(review$target_file)
    }
  }
  review[keep, , drop = FALSE]
}

# The minimal argument set that resolves to exactly this slot -- computed by
# *doing* the resolution, not by guessing. `table` and `code_value` are added
# only when (column, role) alone is ambiguous, so the common single-table case
# prints the short call the execplan's target experience shows. A column-less
# slot has no positional spelling at all, so it prints named arguments and
# `table` is mandatory rather than a disambiguator.
#
# When `table` is not enough, `code_value` is added. For a code's slot that is
# its code value. For a slot that belongs to no code it is `code_value = ""`,
# the only spelling that excludes the code slots sharing this slot's column and
# role, because an omitted `code_value` matches them all (hub queue B-151).
# A code's slot with an empty `code_value` gets neither: `""` now selects the
# slots that belong to no code, so printing it there would decide the column's
# own slot instead of this one. That slot's call stays as ambiguous as it was
# before B-151, and refuses rather than deciding the wrong slot.
.ms_review_call_args <- function(review, slot_id) {
  row <- review[review$slot_id == slot_id, , drop = FALSE][1, , drop = FALSE]
  column <- .ms_scalar_text(row$column_name)
  args <- list(
    column = if (nzchar(column)) column else NULL,
    role = .ms_scalar_text(row$role)
  )
  resolved <- function(extra) {
    unique(.ms_review_match_slot_rows(
      review, args$column, args$role, extra$table, extra$code_value
    )$slot_id)
  }

  extra <- list()
  if (is.null(args$column) || length(resolved(extra)) > 1L) {
    table_value <- .ms_scalar_text(row$table_id)
    if (nzchar(table_value)) {
      extra$table <- table_value
    }
  }
  if (length(resolved(extra)) > 1L) {
    code_value <- .ms_scalar_text(row$code_value)
    if (nzchar(code_value) || !.ms_review_is_code_slot(row$target_file)) {
      extra$code_value <- code_value
    }
  }
  c(args, extra)
}

.ms_review_quote <- function(x) {
  paste0("\"", gsub("\"", "\\\\\"", as.character(x), fixed = TRUE), "\"")
}

# The pasteable call. Positional `column`/`role` when there is a column, all
# named when there is not -- so the printed string always parses to the same
# slot it was printed under.
.ms_review_decision_call <- function(fn, review, slot_id, rank = NULL, object_name = "review") {
  args <- .ms_review_call_args(review, slot_id)
  parts <- if (is.null(args$column)) {
    c(object_name, paste0("role = ", .ms_review_quote(args$role)))
  } else {
    c(object_name, .ms_review_quote(args$column), .ms_review_quote(args$role))
  }
  if (!is.null(rank)) {
    parts <- c(parts, paste0("rank = ", rank))
  }
  if (!is.null(args$table)) {
    parts <- c(parts, paste0("table = ", .ms_review_quote(args$table)))
  }
  if (!is.null(args$code_value)) {
    parts <- c(parts, paste0("code_value = ", .ms_review_quote(args$code_value)))
  }
  paste0(fn, "(", paste(parts, collapse = ", "), ")")
}

.ms_review_accept_call <- function(review, slot_id, rank, object_name = "review") {
  .ms_review_decision_call("accept_suggestion", review, slot_id, rank, object_name)
}

.ms_review_reject_call <- function(review, slot_id, object_name = "review") {
  .ms_review_decision_call("reject_suggestion", review, slot_id, NULL, object_name)
}

.ms_review_rule <- function(text, width = 78L) {
  prefix <- paste0("\u2500\u2500 ", text, " ")
  pad <- max(3L, width - nchar(prefix))
  paste0(prefix, strrep("\u2500", pad))
}

# Wrap a definition without breaking a long IRI or a brace run. Plain
# `strwrap()`, which is locale-aware only for what it treats as whitespace.
.ms_review_wrap <- function(text, indent = "       ", width = 78L) {
  text <- .ms_scalar_text(text)
  if (!nzchar(text)) {
    return(character())
  }
  wrapped <- strwrap(text, width = max(20L, width - nchar(indent)))
  paste0(indent, wrapped)
}

# The whole console view, as a plain character vector. `print()` only emits
# what this returns, so tests assert against these lines rather than against
# rendered terminal output -- hyperlink support is terminal-dependent and the
# package deliberately holds zero snapshots (see `test-cli-safety.R`).
.ms_review_render_lines <- function(review, object_name = "review") {
  if (nrow(review) == 0L) {
    return(c(
      "Nothing left to review.",
      "",
      "Every slot that had a shortlist is either filled or already decided.",
      "Pass include_filled = TRUE to see the decided ones.",
      "Run review_metadata(path) for the fields that still block validation."
    ))
  }

  slot_ids <- unique(review$slot_id)
  lines <- character()

  for (slot in slot_ids) {
    rows <- review[review$slot_id == slot, , drop = FALSE]
    head_row <- rows[1, , drop = FALSE]

    heading_parts <- c(
      .ms_scalar_text(head_row$table_id),
      .ms_scalar_text(head_row$column_name),
      .ms_scalar_text(head_row$code_value),
      .ms_scalar_text(head_row$role)
    )
    heading_parts <- heading_parts[nzchar(heading_parts)]
    lines <- c(lines, .ms_review_rule(paste(heading_parts, collapse = " \u00b7 ")))

    current <- head_row$current_value[[1]]
    current_text <- if (is.na(current)) {
      "<unknown>"
    } else if (!nzchar(trimws(current))) {
      "<blank>"
    } else {
      current
    }
    lines <- c(
      lines,
      paste0("   field:   ", .ms_scalar_text(head_row$target_file), " \u00b7 ", .ms_scalar_text(head_row$target_field)),
      paste0("   current: ", current_text)
    )

    decided <- rows$decision[!is.na(rows$decision)]
    if (length(decided) > 0) {
      decision <- decided[[1]]
      decided_row <- rows[!is.na(rows$decision), , drop = FALSE][1, , drop = FALSE]
      lines <- c(lines, if (identical(decision, "accept")) {
        paste0("   DECIDED: accept \u2192 ", .ms_scalar_text(decided_row$decision_iri))
      } else {
        paste0(
          "   DECIDED: reject (clears the field)",
          if (nzchar(.ms_scalar_text(decided_row$decision_reason))) {
            paste0(" \u2014 ", .ms_scalar_text(decided_row$decision_reason))
          } else {
            ""
          }
        )
      })
    }
    lines <- c(lines, "")

    for (i in seq_len(nrow(rows))) {
      candidate <- rows[i, , drop = FALSE]
      score <- candidate$score[[1]]
      score_text <- if (is.na(score)) "" else paste0("score ", format(round(score, 2), nsmall = 0, trim = TRUE))
      marker <- if (identical(candidate$decision[[1]], "accept")) "*" else " "
      lines <- c(lines, paste0(
        "  ", marker, "[", candidate$rank[[1]], "] ",
        .ms_scalar_text(candidate$label), "   ",
        .ms_scalar_text(candidate$source),
        if (nzchar(score_text)) paste0("   ", score_text) else ""
      ))
      lines <- c(lines, .ms_review_wrap(candidate$definition))
      lines <- c(lines, paste0("       ", .ms_review_iri_display(
        candidate$iri[[1]], candidate$source[[1]], candidate$ontology[[1]]
      )))
      llm_decision <- .ms_scalar_text(candidate$llm_decision)
      if (nzchar(llm_decision)) {
        confidence <- candidate$llm_confidence[[1]]
        lines <- c(lines, paste0(
          "       llm: ", llm_decision,
          if (!is.na(confidence)) paste0(" (confidence ", format(confidence, trim = TRUE), ")") else ""
        ))
        lines <- c(lines, .ms_review_wrap(candidate$llm_rationale, indent = "            "))
      }
      lines <- c(lines, paste0(
        "       ", object_name, " <- ",
        .ms_review_accept_call(review, slot, candidate$rank[[1]], object_name)
      ))
      lines <- c(lines, "")
    }

    lines <- c(lines, paste0(
      "       ", object_name, " <- ", .ms_review_reject_call(review, slot, object_name),
      "   # no candidate fits"
    ), "")
  }

  path <- attr(review, "review_path", exact = TRUE)
  apply_call <- if (is.null(path) || is.na(path)) {
    paste0("apply_sdp_semantics(<package path>, ", object_name, ")")
  } else {
    paste0("apply_sdp_semantics(", .ms_review_quote(path), ", ", object_name, ")")
  }

  n_decided <- length(unique(review$slot_id[!is.na(review$decision)]))
  c(
    lines,
    .ms_review_rule("next"),
    paste0(
      "   ", n_decided, " of ", length(slot_ids), " slot",
      if (length(slot_ids) == 1L) "" else "s", " decided."
    ),
    "   Paste the calls above into your script, then write the decisions:",
    paste0("   ", apply_call),
    ""
  )
}

#' @export
print.ms_semantic_review <- function(x, ...) {
  if (!all(c("slot_id", "rank", "decision") %in% names(x))) {
    # A subset that dropped the review columns is no longer a review.
    return(NextMethod())
  }
  object_name <- .ms_review_object_name(x, substitute(x))
  # `cat()`, not cli: see the header of this file. These lines carry ontology
  # definitions and LLM rationales verbatim, and `cat()` has no template layer
  # for a brace in that text to be evaluated by.
  cat(.ms_review_render_lines(x, object_name = object_name), sep = "\n")
  invisible(x)
}

# --------------------------------------------------------------------------
# Decisions
# --------------------------------------------------------------------------

.ms_review_assert_review <- function(review, call = parent.frame()) {
  if (!inherits(review, "ms_semantic_review")) {
    cli::cli_abort(
      c(
        "{.arg review} must be an {.cls ms_semantic_review} object.",
        "i" = "Build one with {.fn review_semantics}."
      ),
      call = call
    )
  }
  invisible(review)
}

# Resolve (column, role[, table][, code_value]) to exactly one slot, or abort
# with the disambiguating argument the caller has to add. Every piece of the
# message that echoes caller text goes through `.ms_cli_escape()`: a column
# literally named `rate{pct` would otherwise replace the message with a parse
# error, which is the failure `R/cli-safety.R` exists to prevent.
.ms_review_resolve_slot <- function(review,
                                    column,
                                    role,
                                    table = NULL,
                                    code_value = NULL,
                                    call = parent.frame()) {
  column_text <- if (is.null(column)) NULL else .ms_scalar_text(column)
  if (!is.null(column_text) && !nzchar(column_text)) {
    column_text <- NULL
  }
  role <- .ms_scalar_text(role)
  table_text <- if (is.null(table)) NULL else .ms_scalar_text(table)
  code_text <- if (is.null(code_value)) NULL else .ms_scalar_text(code_value)

  rows <- .ms_review_match_slot_rows(review, column_text, role, table_text, code_text)

  if (nrow(rows) == 0L) {
    available <- unique(paste0(
      ifelse(is.na(review$column_name) | !nzchar(review$column_name),
             paste0("<table ", review$table_id, ">"), review$column_name),
      " \u00b7 ", review$role
    ))
    cli::cli_abort(
      c(
        "No review slot matches that column and role.",
        "x" = paste0("Asked for: ", .ms_cli_escape(paste0(column_text %||% "<no column>", " \u00b7 ", role))),
        .ms_cli_bullets(utils::head(available, 20L), "i")
      ),
      call = call
    )
  }

  slots <- unique(rows$slot_id)
  if (length(slots) > 1L) {
    # A slot that belongs to no code and shares its table with code slots is
    # selected only by `code_value = ""`; offering bare `table = ` for it
    # repeated an argument that could not settle anything, so the column's own
    # slot was unreachable by following this message (hub queue B-151). What
    # makes a slot a code's is its file, not a non-empty `code_value`: a
    # `codes.csv` row may leave the value empty when it supplies
    # `vocabulary_iri` (Codex review of pull request #153). Such a code slot
    # has no option of its own that settles it, since no argument tells it
    # apart from the column's own slot, so it keeps the bare `table = ` it had
    # before.
    is_code_slot <- .ms_review_is_code_slot(rows$target_file)
    has_code <- !is.na(rows$code_value) & nzchar(trimws(rows$code_value))
    needs_blank <- !is_code_slot & rows$table_id %in% rows$table_id[is_code_slot]
    ambiguous <- unique(paste0(
      "table = \"", rows$table_id, "\"",
      ifelse(
        has_code,
        paste0(", code_value = \"", rows$code_value, "\""),
        ifelse(needs_blank, ", code_value = \"\"", "")
      )
    ))
    cli::cli_abort(
      c(
        "That column and role match more than one review slot.",
        "i" = "Add one of these arguments to say which:",
        .ms_cli_bullets(ambiguous, "*")
      ),
      call = call
    )
  }
  slots[[1]]
}

#' Decide a semantic review slot
#'
#' `accept_suggestion()` records that a candidate is the right term for a slot;
#' `reject_suggestion()` records that none is, and clears the field. Both are
#' pipe-friendly -- they take a review and return it -- so a whole review is an
#' ordinary, re-runnable R script. Nothing is written until
#' [apply_sdp_semantics()] is called.
#'
#' These are the calls [review_semantics()] prints. Pasting the printed line is
#' the intended workflow, and it is what makes the decision reproducible: the
#' script is the audit trail.
#'
#' @param review An `ms_semantic_review` object from [review_semantics()].
#' @param column Column name of the slot. Omit it for a table-level slot
#'   (`tables.csv` - `observation_unit_iri`), which has no column; pass `table`
#'   instead. `review_semantics()` prints the right spelling either way.
#' @param role Semantic role of the slot (`"variable"`, `"property"`,
#'   `"entity"`, `"unit"`, `"constraint"`, `"statistical_modifier"`).
#' @param rank Rank of the candidate to accept, as printed in the shortlist.
#' @param table Table identifier; needed only when the column name appears in
#'   more than one table.
#' @param code_value Code value; needed only for code-level slots. Pass `""`
#'   (or `NA`) to select a column's own slot when codes of that column have
#'   slots with the same role, as a measurement column's codes do: leaving
#'   `code_value` out matches those code slots too. A blank never selects a
#'   code's slot, even for a `codes.csv` row that leaves `code_value` empty
#'   because it supplies `vocabulary_iri`. `review_semantics()` prints it
#'   whenever it is needed.
#' @param iri Optional IRI to accept instead of a shortlisted candidate -- for
#'   the case where the right term exists but retrieval did not surface it. An
#'   `iri` that a shortlisted candidate in the slot carries is recorded as that
#'   candidate, exactly as its `rank` would be.
#' @param reason Optional free-text reason recorded with a rejection.
#'
#' @return The review, with the decision recorded.
#' @seealso [review_semantics()], [apply_sdp_semantics()]
#' @export
#'
#' @examples
#' dict <- tibble::tibble(
#'   dataset_id = "demo-1", table_id = "spawners",
#'   column_name = "spawner_count", term_iri = NA_character_
#' )
#' attr(dict, "semantic_suggestions") <- tibble::tibble(
#'   dataset_id = "demo-1", table_id = "spawners",
#'   column_name = "spawner_count", code_value = NA_character_,
#'   dictionary_role = "variable", target_scope = "column",
#'   target_sdp_file = "column_dictionary.csv", target_sdp_field = "term_iri",
#'   target_row_key = "demo-1/spawners/spawner_count",
#'   label = "Spawner Abundance", iri = "https://w3id.org/smn/SpawnerAbundance",
#'   source = "smn", ontology = "smn",
#'   definition = "Mature salmon returning to spawn.", score = 4.9
#' )
#'
#' review <- review_semantics(dict)
#' review <- accept_suggestion(review, "spawner_count", "variable", rank = 1)
#' review$decision
accept_suggestion <- function(review,
                              column = NULL,
                              role,
                              rank = 1L,
                              table = NULL,
                              code_value = NULL,
                              iri = NULL) {
  .ms_review_assert_review(review)
  slot <- .ms_review_resolve_slot(review, column, role, table, code_value)
  in_slot <- review$slot_id == slot

  accepted_iri <- if (!is.null(iri)) {
    .ms_scalar_text(iri)
  } else {
    hit <- which(in_slot & review$rank == as.integer(rank))
    if (length(hit) != 1L) {
      available <- review$rank[in_slot]
      cli::cli_abort(c(
        "No candidate with that {.arg rank} in this slot.",
        "i" = "Ranks available: {.val {available}}.",
        "i" = "To accept a term that is not shortlisted, pass {.arg iri} instead."
      ))
    }
    .ms_scalar_text(review$iri[[hit]])
  }

  # `REVIEW:` never survives a decision: the marker means "not confident", and
  # accepting is the statement that removes it. Stripping here rather than at
  # write time keeps the review object and the written bytes agreeing about
  # what was decided.
  accepted_iri <- .ms_strip_review_iri(accepted_iri)

  # The non-empty check reads the stripped value, because that is the value the
  # decision records. Run before the strip, it let `iri = "REVIEW:"`, and every
  # other spelling the strip removes, record an accept that named no term
  # (hub item B-219).
  if (!is.null(iri) && !nzchar(accepted_iri)) {
    message <- "{.arg iri} must be a non-empty IRI."
    if (nzchar(.ms_scalar_text(iri))) {
      message <- c(
        message,
        "i" = "An accepted IRI is recorded without its {.code REVIEW:} marker, and nothing follows the marker here."
      )
    }
    cli::cli_abort(message)
  }

  review$decision[in_slot] <- NA_character_
  review$decision_iri[in_slot] <- NA_character_
  review$decision_reason[in_slot] <- NA_character_

  # An `iri` that a shortlisted candidate carries names that candidate, so the
  # decision goes on the candidate's row, where `rank =` would put it. That row
  # is where `apply_sdp_semantics()` reads the candidate's `term_type` and where
  # the rebuilt review replays the decision. On the slot's first row instead,
  # one decision wrote `skos_concept` when first applied and the candidate's own
  # type once rebuilt (hub item B-221). Candidate IRIs are compared as a
  # decision records them (`.ms_review_decision_iri()`, which the writer reads
  # too), and the first carrier wins, as it does on replay. An IRI no candidate
  # in this review carries still goes on the first row, whose different IRI
  # tells the writer nothing is known about its type.
  target <- if (is.null(iri)) {
    which(in_slot & review$rank == as.integer(rank))
  } else {
    carried <- which(in_slot & .ms_review_decision_iri(review$iri) %in% accepted_iri)
    if (length(carried) > 0L) carried[[1]] else which(in_slot)[[1]]
  }
  review$decision[target] <- "accept"
  review$decision_iri[target] <- accepted_iri
  review
}

#' @rdname accept_suggestion
#' @export
reject_suggestion <- function(review,
                              column = NULL,
                              role,
                              table = NULL,
                              code_value = NULL,
                              reason = NULL) {
  .ms_review_assert_review(review)
  slot <- .ms_review_resolve_slot(review, column, role, table, code_value)
  in_slot <- review$slot_id == slot

  review$decision[in_slot] <- "reject"
  review$decision_iri[in_slot] <- NA_character_
  review$decision_reason[in_slot] <- if (is.null(reason)) NA_character_ else .ms_scalar_text(reason)
  review
}

# One row per decided slot, in review order. The write-back's only input.
.ms_review_decisions <- function(review) {
  decided <- review[!is.na(review$decision), , drop = FALSE]
  if (nrow(decided) == 0L) {
    return(decided[0, , drop = FALSE])
  }
  # A reject marks every row in the slot; keep the first so a slot contributes
  # exactly one write.
  decided[!duplicated(decided$slot_id), , drop = FALSE]
}
