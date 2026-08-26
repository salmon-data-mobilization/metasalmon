# Free-text metadata review and editing (roadmap stream S5, milestone M4).
#
# M1-M3 made the *semantic* review scriptable. This file is the other half, and
# it is the larger one, for a reason the M1-M3 milestone measured rather than
# guessed: after a complete console review,
# `validate_salmon_datapackage(require_iris = TRUE)` still failed. Two causes,
# and one mechanism closes both.
#
#   1. `MISSING DESCRIPTION:` / `MISSING METADATA:` placeholders are refused by
#      strict validation, and the only way to replace them was a spreadsheet.
#   2. `review_semantics()` shows SHORTLISTS, NOT GAPS. A slot that retrieval
#      returned nothing for never enters the queue at all, so a user could
#      finish the entire console review and still be missing a required IRI --
#      and nothing in the review would have said so.
#
# `review_metadata()` closes both because it does not read a suggestion list.
# It reads the package against the rules that actually decide strict
# validation: the Frictionless schema's `constraints.required` (surfaced as
# `field$requirement`, which had five producers and no consumers before this),
# the placeholder markers, the measurement-column IRI requirement, and the
# table observation-unit IRI requirement. A field that no retrieval ever
# touched is as visible to it as one with five candidates.
#
# THE CONTRACT IT IS JUDGED AGAINST: every row `review_metadata()` reports
# prints a runnable `set_sdp_*()` call that fixes it, and when the last row is
# gone strict validation passes. `tests/testthat/test-sdp-field-setters.R`
# asserts both halves -- including by EXECUTING the printed calls, because the
# M1-M3 retrospective's one generalisable rule is that if a program's output is
# meant to be run, the tests have to run it. A printed call that names a column
# that does not exist passes every `grepl()` assertion ever written.
#
# THE PRINTED CALL IS THE CONTRACT, exactly as in `R/review-console.R`: the
# console prints a line, the user edits the placeholder value and pastes it,
# and the paste is the audit trail. No prompt loop, no TUI. And as there, the
# rendering path is `cat()` rather than cli, so a placeholder message or an
# ontology label containing `{...}` prints literally instead of being
# interpolated -- see that file's header for why escaping HERE would be the
# bug rather than the fix.

# --------------------------------------------------------------------------
# What "unfilled" means, and where the requirement comes from
# --------------------------------------------------------------------------

# A metadata value the user still has to supply. Three ways to be unfilled and
# they are not interchangeable: absent, blank, or *stating in its own text*
# that it is missing. The third is why a blankness test is not enough -- a
# `MISSING METADATA:` placeholder is a non-empty string, and strict validation
# refuses it precisely because it is not a value.
.ms_is_unfilled_metadata <- function(x) {
  text <- as.character(x)
  text[is.na(text)] <- ""
  !nzchar(trimws(text)) |
    vapply(text, .ms_is_review_placeholder, logical(1), USE.NAMES = FALSE)
}

# The instruction inside a placeholder, without its marker. The placeholder
# writers put a genuinely useful hint there ("add creator, team, or originating
# program"), so it becomes the prompt in the printed call rather than being
# thrown away and replaced with a generic one.
.ms_strip_review_placeholder_prefix <- function(x) {
  text <- .ms_scalar_text(x)
  text <- sub(
    "^\\s*(MISSING METADATA|MISSING DESCRIPTION|REVIEW REQUIRED)\\s*:\\s*", "",
    text,
    ignore.case = TRUE
  )
  sub("\\s*\\.\\s*$", "", trimws(text))
}

# Which SDP metadata file each schema table describes. One spelling of a
# mapping that would otherwise be re-derived in every function here.
.ms_metadata_schema_tables <- function() {
  c(
    "dataset.csv" = "dataset",
    "tables.csv" = "tables",
    "column_dictionary.csv" = "column_dictionary",
    "codes.csv" = "codes"
  )
}

# The columns that ADDRESS a row rather than describe it. Deliberately not
# settable: changing one would not fill a gap, it would silently re-point the
# row at a different table or column and orphan whatever referred to it.
# `validate_salmon_datapackage()` is the channel for a blank key, because a
# package with one is broken rather than incomplete.
#
# Retires when a setter can address a row without a key -- which it cannot, so
# read this as permanent rather than as an unexplained exclusion.
.ms_metadata_key_fields <- function(file_name) {
  switch(
    file_name,
    "dataset.csv" = "dataset_id",
    "tables.csv" = c("dataset_id", "table_id", "file_name"),
    "column_dictionary.csv" = c("dataset_id", "table_id", "column_name"),
    "codes.csv" = c("dataset_id", "table_id", "column_name", "code_value"),
    character()
  )
}

# The declared field definitions for one metadata file, in schema order.
.ms_metadata_schema_fields <- function(file_name) {
  table_name <- .ms_metadata_schema_tables()[[file_name]]
  schema <- .ms_load_sdp_schema(quiet = TRUE)
  schema$metadata_tables[[table_name]]$fields
}

# The fields the schema declares `constraints.required`. THE FIRST CONSUMER of
# `field$requirement`, which `.ms_field_from_frictionless()` has parsed since
# the schema bundle landed and which nothing outside that file ever read.
.ms_required_metadata_fields <- function(file_name) {
  fields <- .ms_metadata_schema_fields(file_name)
  required <- purrr::keep(fields, ~ identical(.x$requirement, "required"))
  setdiff(purrr::map_chr(required, "name"), .ms_metadata_key_fields(file_name))
}

.ms_metadata_field_description <- function(file_name, field) {
  fields <- .ms_metadata_schema_fields(file_name)
  hit <- purrr::detect(fields, ~ identical(.x$name, field))
  if (is.null(hit)) "" else .ms_scalar_text(hit$description)
}

# --------------------------------------------------------------------------
# The gap scan
# --------------------------------------------------------------------------

# Measurement columns must carry all four I-ADOPT IRIs before
# `validate_dictionary(require_iris = TRUE)` will pass. That requirement is
# stated in the dictionary validator rather than in the schema (the schema
# calls them `conditional`), so it is enumerated here and pinned by a test that
# drives the validator itself -- an enumeration that drifts from the validator
# would make `review_metadata()` report a clean package that still fails.
.ms_measurement_iri_fields <- function() {
  c("term_iri", "property_iri", "entity_iri", "unit_iri")
}

# One gap row. `hint` becomes the placeholder inside the printed call.
.ms_metadata_gap_row <- function(file_name, field, current, reason,
                                 table_id = NA_character_,
                                 column_name = NA_character_,
                                 code_value = NA_character_,
                                 hint = NULL) {
  placeholder_hint <- .ms_strip_review_placeholder_prefix(current)
  if (is.null(hint)) {
    hint <- if (nzchar(placeholder_hint) && .ms_is_review_placeholder(current)) {
      placeholder_hint
    } else {
      .ms_metadata_field_description(file_name, field)
    }
  }
  hint <- .ms_scalar_text(hint)
  if (!nzchar(hint)) {
    hint <- field
  }
  tibble::tibble(
    file = file_name,
    table_id = as.character(table_id),
    column_name = as.character(column_name),
    code_value = as.character(code_value),
    field = field,
    current_value = .ms_scalar_text(current),
    reason = reason,
    hint = hint,
    note = NA_character_
  )
}

# The key a gap row and a suggestion row share. `target_row_key` is the
# producer's own address for the same slot, but a gap is found by scanning the
# metadata rather than the suggestions, so the two meet on the identifying
# columns instead.
.ms_metadata_slot_key <- function(file, table_id, column_name, code_value, field) {
  clean <- function(x) {
    text <- as.character(x)
    text[is.na(text)] <- ""
    trimws(text)
  }
  paste(clean(file), clean(table_id), clean(column_name), clean(code_value), clean(field), sep = "|")
}

# Annotate IRI gaps a reviewer already looked at. `reject_suggestion(reason =)`
# records WHY no candidate fitted, and `apply_sdp_semantics()` persists it --
# but a rejection leaves the field blank, so the gap comes back here looking
# exactly like one nobody has ever considered. Reading the reason back is what
# makes the record worth keeping: the next person sees "rejected: none of these
# describe a stream name" instead of re-deriving it.
.ms_metadata_annotate_decisions <- function(review, path) {
  suggestions_path <- file.path(path, "semantic_suggestions.csv")
  if (nrow(review) == 0L || !file.exists(suggestions_path) || dir.exists(suggestions_path)) {
    return(review)
  }
  suggestions <- tibble::as_tibble(.ms_read_metadata_csv(suggestions_path))
  needed <- c("target_sdp_file", "target_sdp_field", "decision")
  if (!all(needed %in% names(suggestions))) {
    return(review)
  }
  rejected <- suggestions[
    !is.na(suggestions$decision) & trimws(as.character(suggestions$decision)) == "rejected", ,
    drop = FALSE
  ]
  if (nrow(rejected) == 0L) {
    return(review)
  }
  reasons <- if ("decision_reason" %in% names(rejected)) {
    as.character(rejected$decision_reason)
  } else {
    rep(NA_character_, nrow(rejected))
  }
  keys <- .ms_metadata_slot_key(
    rejected$target_sdp_file,
    if ("table_id" %in% names(rejected)) rejected$table_id else NA,
    if ("column_name" %in% names(rejected)) rejected$column_name else NA,
    if ("code_value" %in% names(rejected)) rejected$code_value else NA,
    rejected$target_sdp_field
  )
  lookup <- stats::setNames(reasons, keys)

  gap_keys <- .ms_metadata_slot_key(
    review$file, review$table_id, review$column_name, review$code_value, review$field
  )
  hit <- gap_keys %in% names(lookup)
  if (!any(hit)) {
    return(review)
  }
  matched_reason <- unname(lookup[gap_keys[hit]])
  review$note[hit] <- ifelse(
    is.na(matched_reason) | !nzchar(trimws(matched_reason)),
    "you rejected every candidate here; no reason was recorded",
    paste0("you rejected every candidate here: ", matched_reason)
  )
  review
}

# Every field of one metadata file that still blocks strict validation.
.ms_metadata_gaps_for_file <- function(frame, file_name) {
  gaps <- list()
  if (is.null(frame) || nrow(frame) == 0L) {
    return(gaps)
  }

  address <- function(row) {
    list(
      table_id = if ("table_id" %in% names(frame)) .ms_scalar_text(frame$table_id[[row]]) else NA_character_,
      column_name = if ("column_name" %in% names(frame)) .ms_scalar_text(frame$column_name[[row]]) else NA_character_,
      code_value = if ("code_value" %in% names(frame)) .ms_scalar_text(frame$code_value[[row]]) else NA_character_
    )
  }

  add <- function(row, field, reason, hint = NULL) {
    at <- address(row)
    gaps[[length(gaps) + 1L]] <<- .ms_metadata_gap_row(
      file_name, field, frame[[field]][[row]], reason,
      table_id = at$table_id, column_name = at$column_name, code_value = at$code_value,
      hint = hint
    )
    invisible(NULL)
  }

  required <- intersect(.ms_required_metadata_fields(file_name), names(frame))
  keys <- .ms_metadata_key_fields(file_name)
  # Schema order, so the printed calls name their arguments in the order the
  # spec declares them rather than in whichever order the scan happened to run.
  scan_fields <- intersect(purrr::map_chr(.ms_metadata_schema_fields(file_name), "name"), names(frame))

  for (row in seq_len(nrow(frame))) {
    for (field in scan_fields) {
      value <- frame[[field]][[row]]
      # A placeholder anywhere is refused, whether or not the schema calls the
      # field required: `observation_unit` is optional and still gets one.
      if (.ms_is_review_placeholder(value)) {
        add(row, field, "placeholder")
        next
      }
      if (field %in% keys) {
        next
      }
      if (field %in% required && .ms_is_unfilled_metadata(value)) {
        add(row, field, "required")
      }
    }

    if (identical(file_name, "tables.csv") && "observation_unit_iri" %in% names(frame)) {
      value <- frame$observation_unit_iri[[row]]
      # Blank OR still marked: the schema calls this `recommended`, and strict
      # validation refuses a blank one anyway
      # (`.ms_collect_missing_table_observation_unit_iri_issues()`). The schema
      # is not the authority on what blocks; the validator is.
      if (.ms_is_unfilled_metadata(value)) {
        add(row, "observation_unit_iri", "iri", hint = "IRI for what one row represents")
      }
    }

    if (identical(file_name, "column_dictionary.csv") &&
        identical(.ms_scalar_text(frame$column_role[[row]]), "measurement")) {
      for (field in intersect(.ms_measurement_iri_fields(), names(frame))) {
        if (.ms_is_unfilled_metadata(frame[[field]][[row]])) {
          add(row, field, "iri", hint = paste0("IRI for ", field))
        }
      }
    }
  }
  gaps
}

#' Report the metadata a package still needs, with the call that fills it
#'
#' Lists every field that still blocks
#' `validate_salmon_datapackage(path, require_iris = TRUE)`, and prints the
#' exact [set_sdp_dataset()] / [set_sdp_table()] / [set_sdp_column()] /
#' [set_sdp_code()] call that fills it. Replace the `<...>` placeholder in the
#' printed call with the real value and paste it -- the paste is the audit
#' trail, just as it is for [accept_suggestion()].
#'
#' This is the companion to [review_semantics()], and it sees something that
#' review structurally cannot: **a slot with no candidates at all**.
#' `review_semantics()` builds its queue from retrieved suggestions, so a field
#' nothing was found for never appears there. `review_metadata()` builds its
#' list from the package's own required-field rules, so an empty shortlist and
#' a full one look the same to it.
#'
#' What it reports:
#'
#' * unresolved `MISSING DESCRIPTION:` / `MISSING METADATA:` / `REVIEW REQUIRED:`
#'   placeholders in any metadata field;
#' * schema-required fields (`constraints.required`) that are blank;
#' * measurement columns missing `term_iri`, `property_iri`, `entity_iri` or
#'   `unit_iri`;
#' * `tables.csv` rows with a blank `observation_unit_iri`.
#'
#' It never contacts a network or an LLM.
#'
#' @param path Path to the package directory.
#'
#' @return An `ms_metadata_review` tibble subclass, one row per unfilled field,
#'   with the package path attached as the `review_path` attribute. Empty when
#'   nothing is outstanding.
#' @seealso [set_sdp_dataset()], [review_semantics()],
#'   [validate_salmon_datapackage()]
#' @export
#'
#' @examples
#' \dontrun{
#' pkg <- create_sdp(resources, dataset_id = "demo-1")
#' review_metadata(pkg)
#' set_sdp_dataset(pkg, creator = "Fisheries and Oceans Canada")
#' }
review_metadata <- function(path) {
  if (!is.character(path) || length(path) != 1L || is.na(path) || !dir.exists(path)) {
    cli::cli_abort("{.arg path} must be an existing Salmon Data Package directory.")
  }

  gaps <- list()
  for (file_name in names(.ms_metadata_schema_tables())) {
    located <- .ms_locate_metadata_file(path, file_name)
    if (length(located) != 1L || is.na(located) || dir.exists(located)) {
      next
    }
    frame <- tibble::as_tibble(.ms_read_metadata_csv(located))
    gaps <- c(gaps, .ms_metadata_gaps_for_file(frame, file_name))
  }

  review <- if (length(gaps) == 0L) {
    .ms_metadata_gap_row("dataset.csv", "x", "", "required")[0, , drop = FALSE]
  } else {
    .ms_metadata_annotate_decisions(dplyr::bind_rows(gaps), path)
  }
  attr(review, "review_path") <- path
  class(review) <- c("ms_metadata_review", class(tibble::tibble()))
  review
}

# --------------------------------------------------------------------------
# Rendering
# --------------------------------------------------------------------------

# The value slot in a printed call. Deliberately NOT a plausible value: a call
# pasted without editing must fail loudly, not quietly write "..." into
# `creator` and let strict validation pass on a package that says nothing.
# `.ms_assert_metadata_value()` refuses anything of this shape and says so.
.ms_metadata_value_template <- function(hint) {
  text <- gsub("[[:space:]]+", " ", .ms_scalar_text(hint))
  text <- gsub("[<>\"\\]", "", text)
  if (nchar(text) > 60L) {
    text <- paste0(substr(text, 1L, 57L), "...")
  }
  paste0("<", text, ">")
}

.ms_is_metadata_value_template <- function(x) {
  grepl("^<.*>$", trimws(.ms_scalar_text(x)))
}

# Which setter owns a file, and which arguments address the row it writes to.
#
# Returned as one line per argument rather than as a single string, and
# DELIBERATELY not passed through `.ms_review_wrap()`. `strwrap()` normalises
# whitespace and inserts sentence spacing, so wrapping a call would silently
# rewrite the text inside its own string literals -- a printed call is code,
# and the only safe way to break code across lines is at an argument boundary.
.ms_metadata_setter_call <- function(rows, path_expr) {
  file_name <- .ms_scalar_text(rows$file[[1]])
  table_id <- .ms_scalar_text(rows$table_id[[1]])
  column_name <- .ms_scalar_text(rows$column_name[[1]])
  code_value <- .ms_scalar_text(rows$code_value[[1]])

  spec <- switch(
    file_name,
    "dataset.csv" = list(fn = "set_sdp_dataset", args = character()),
    "tables.csv" = list(
      fn = "set_sdp_table",
      args = .ms_review_quote(table_id)
    ),
    "column_dictionary.csv" = list(
      fn = "set_sdp_column",
      args = c(.ms_review_quote(column_name), paste0("table = ", .ms_review_quote(table_id)))
    ),
    "codes.csv" = list(
      fn = "set_sdp_code",
      args = c(
        .ms_review_quote(column_name),
        .ms_review_quote(code_value),
        paste0("table = ", .ms_review_quote(table_id))
      )
    ),
    NULL
  )
  if (is.null(spec)) {
    return(character())
  }

  values <- paste0(
    rows$field, " = ",
    .ms_review_quote(vapply(rows$hint, .ms_metadata_value_template, character(1)))
  )
  c(
    paste0(spec$fn, "(", paste(c(path_expr, spec$args), collapse = ", "), ","),
    paste0("  ", values, c(rep(",", length(values) - 1L), "")),
    ")"
  )
}

.ms_metadata_row_id <- function(review) {
  paste(review$file, review$table_id, review$column_name, review$code_value, sep = "|")
}

.ms_metadata_reason_note <- function(reason) {
  switch(
    reason,
    placeholder = "placeholder text, refused by strict validation",
    required = "required by the SDP schema and blank",
    iri = "required IRI and not yet decided",
    reason
  )
}

# The whole view, as a plain character vector -- `print()` only emits what this
# returns, so tests assert against these lines and never against rendered
# terminal output.
.ms_metadata_render_lines <- function(review, path_expr = "path") {
  if (nrow(review) == 0L) {
    return(c(
      "No outstanding metadata.",
      "",
      "Every required field is filled and no placeholders remain.",
      "Check it with validate_salmon_datapackage(path, require_iris = TRUE).",
      ""
    ))
  }

  lines <- character()
  row_ids <- unique(.ms_metadata_row_id(review))
  all_ids <- .ms_metadata_row_id(review)

  for (row_id in row_ids) {
    rows <- review[all_ids == row_id, , drop = FALSE]
    head_row <- rows[1, , drop = FALSE]
    heading_parts <- c(
      .ms_scalar_text(head_row$file),
      .ms_scalar_text(head_row$table_id),
      .ms_scalar_text(head_row$column_name),
      .ms_scalar_text(head_row$code_value)
    )
    heading_parts <- heading_parts[nzchar(heading_parts)]
    lines <- c(lines, .ms_review_rule(paste(heading_parts, collapse = " · ")))

    for (i in seq_len(nrow(rows))) {
      lines <- c(lines, paste0(
        "   ", .ms_scalar_text(rows$field[[i]]), ": ",
        .ms_metadata_reason_note(.ms_scalar_text(rows$reason[[i]]))
      ))
      current <- .ms_scalar_text(rows$current_value[[i]])
      if (nzchar(current)) {
        lines <- c(lines, .ms_review_wrap(current, indent = "      "))
      }
      note <- .ms_scalar_text(rows$note[[i]])
      if (nzchar(note)) {
        lines <- c(lines, .ms_review_wrap(note, indent = "      "))
      }
    }
    lines <- c(
      lines,
      "",
      paste0("   ", .ms_metadata_setter_call(rows, path_expr)),
      ""
    )
  }

  iri_rows <- sum(review$reason == "iri")
  c(
    lines,
    .ms_review_rule("next"),
    paste0(
      "   ", nrow(review), " field", if (nrow(review) == 1L) "" else "s",
      " still block", if (nrow(review) == 1L) "s" else "",
      " strict validation."
    ),
    "   Replace each <...> with the real value, then paste the calls above.",
    if (iri_rows > 0L) {
      paste0(
        "   ", iri_rows, " of them ", if (iri_rows == 1L) "is an IRI" else "are IRIs",
        " -- review_semantics() shows candidates for any that have them."
      )
    },
    paste0("   Then: validate_salmon_datapackage(", path_expr, ", require_iris = TRUE)"),
    ""
  )
}

#' @export
print.ms_metadata_review <- function(x, ...) {
  if (!all(c("file", "field", "reason", "hint") %in% names(x))) {
    return(NextMethod())
  }
  path <- attr(x, "review_path", exact = TRUE)
  path_expr <- .ms_binding_name_for(
    path,
    function(value) is.character(value) && length(value) == 1L && identical(value, path),
    default = if (is.null(path) || is.na(path)) "path" else .ms_review_quote(path)
  )
  # `cat()`, not cli. These lines carry placeholder text and schema field
  # descriptions verbatim, and `cat()` has no template layer for a brace in
  # that text to be evaluated by. See the header of `R/review-console.R`.
  cat(.ms_metadata_render_lines(x, path_expr = path_expr), sep = "\n")
  invisible(x)
}

# --------------------------------------------------------------------------
# The setters
# --------------------------------------------------------------------------

.ms_assert_metadata_value <- function(value, field, call = parent.frame()) {
  if (length(value) != 1L) {
    cli::cli_abort(
      "{.arg {field}} must be a single value.",
      call = call
    )
  }
  if (is.na(value)) {
    return(NA_character_)
  }
  text <- .ms_scalar_text(value)
  if (.ms_is_metadata_value_template(text)) {
    cli::cli_abort(
      c(
        "{.arg {field}} still holds the placeholder from {.fn review_metadata}.",
        "x" = .ms_cli_escape(text),
        "i" = "Replace the {.code <...>} text with the real value before running the call."
      ),
      call = call
    )
  }
  if (!nzchar(text)) {
    cli::cli_abort(
      c(
        "{.arg {field}} must not be blank.",
        "i" = "Pass {.code NA} to clear a field on purpose."
      ),
      call = call
    )
  }
  text
}

# Resolve the addressed row, or abort with the argument that disambiguates it.
# Every comparison is `!is.na()`-guarded for the reason
# `.ms_review_match_slot_rows()` records: `df[NA, ]` inserts a phantom all-NA
# row instead of dropping it, and the visible symptom is an error message that
# names rows the package does not have.
.ms_resolve_metadata_row <- function(frame, file_name, keys, call = parent.frame()) {
  keep <- rep(TRUE, nrow(frame))
  for (key in names(keys)) {
    value <- keys[[key]]
    if (is.null(value)) {
      next
    }
    if (!key %in% names(frame)) {
      cli::cli_abort(
        "{.file {file_name}} has no {.field {key}} column to match on.",
        call = call
      )
    }
    column <- as.character(frame[[key]])
    keep <- keep & !is.na(column) & trimws(column) == .ms_scalar_text(value)
  }
  hits <- which(keep)

  if (length(hits) == 1L) {
    return(hits)
  }
  asked <- paste(
    vapply(names(keys), function(key) {
      paste0(key, " = ", .ms_review_quote(.ms_scalar_text(keys[[key]] %||% "")))
    }, character(1)),
    collapse = ", "
  )
  if (length(hits) == 0L) {
    available <- unique(apply(
      as.matrix(frame[, intersect(names(keys), names(frame)), drop = FALSE]),
      1, function(row) paste(row, collapse = " · ")
    ))
    cli::cli_abort(
      c(
        "No {.file {file_name}} row matches that address.",
        "x" = paste0("Asked for: ", .ms_cli_escape(asked)),
        .ms_cli_bullets(utils::head(available, 20L), "i")
      ),
      call = call
    )
  }
  cli::cli_abort(
    c(
      "That address matches {length(hits)} rows in {.file {file_name}}.",
      "x" = paste0("Asked for: ", .ms_cli_escape(asked)),
      "i" = "Add {.arg table} to say which."
    ),
    call = call
  )
}

# Which descriptor keys one metadata field mirrors. A field with no entry has
# no descriptor twin and needs no patch -- `observation_unit_iri` is the
# clearest case: strict validation requires it and `datapackage.json` has
# nowhere to put it.
.ms_descriptor_mirrored_fields <- function(file_name) {
  switch(
    file_name,
    "dataset.csv" = c(
      "title", "description", "creator", "contact_name", "contact_email",
      "contact_org", "license", "temporal_start", "temporal_end"
    ),
    "tables.csv" = c("table_label", "description", "primary_key"),
    "column_dictionary.csv" = c(
      "column_label", "value_type", "column_description", "required",
      names(.ms_descriptor_field_keys())
    ),
    character()
  )
}

# Patch the descriptor for the row that changed, narrowly. NOT a rebuild: a
# rebuild would discard descriptor content a user added by hand, which is the
# decision `apply_sdp_semantics()` already made and this follows. Where the
# descriptor holds a COMPOSITE of several CSV fields -- `contributors` is built
# from `creator`, `contact_name`, `contact_email` and `contact_org` together --
# the whole composite is rebuilt from the row, because there is no narrower
# unit. The CSVs are canonical and `datapackage.json` is the derived export, so
# resyncing it from the row is the documented direction of truth.
.ms_descriptor_sync_metadata_row <- function(descriptor, file_name, frame, row, fields) {
  if (is.null(descriptor)) {
    return(NULL)
  }
  mirrored <- intersect(fields, .ms_descriptor_mirrored_fields(file_name))
  if (length(mirrored) == 0L) {
    return(NULL)
  }

  if (identical(file_name, "dataset.csv")) {
    return(.ms_descriptor_apply_dataset_meta(descriptor, frame[row, , drop = FALSE]))
  }

  table_id <- .ms_scalar_text(frame$table_id[[row]])
  descriptor$resources <- lapply(descriptor$resources, function(resource) {
    if (!identical(.ms_scalar_text(resource$name %||% ""), table_id)) {
      return(resource)
    }
    if (identical(file_name, "tables.csv")) {
      return(.ms_descriptor_apply_resource_meta(resource, frame[row, , drop = FALSE]))
    }
    if (!is.list(resource$schema) || is.null(resource$schema$fields)) {
      return(resource)
    }
    column_name <- .ms_scalar_text(frame$column_name[[row]])
    resource$schema$fields <- lapply(resource$schema$fields, function(field) {
      if (!identical(.ms_scalar_text(field$name %||% ""), column_name)) {
        return(field)
      }
      rebuilt <- .ms_descriptor_field_entry(frame[row, , drop = FALSE])
      base_keys <- c(column_label = "title", value_type = "type", column_description = "description")
      for (key in intersect(mirrored, names(base_keys))) {
        # Present-but-null is the shape the writer emits for an absent value,
        # so assign `NA` rather than `NULL` -- `field$title <- NULL` deletes.
        field[[base_keys[[key]]]] <- rebuilt[[base_keys[[key]]]] %||% NA
      }
      if ("required" %in% mirrored) {
        field$constraints <- rebuilt$constraints
      }
      for (key in intersect(mirrored, names(.ms_descriptor_field_keys()))) {
        descriptor_key <- .ms_descriptor_field_keys()[[key]]
        field[[descriptor_key]] <- rebuilt[[descriptor_key]]
      }
      field
    })
    resource
  })
  descriptor
}

# The engine every `set_sdp_*()` wrapper delegates to. One logical edit changes
# a metadata CSV AND the descriptor keys that duplicate it, so both are
# rendered to bytes first and installed as ONE transactional set -- per-file
# atomicity would still leave a window where the CSV is new and the descriptor
# is old, and `datapackage_consistent_with_csv_metadata` is one of the dead
# rules in `sdp.rules.yaml`, so nothing would ever detect it.
.ms_set_sdp_metadata <- function(path, file_name, keys, values, quiet = FALSE,
                                 call = parent.frame()) {
  if (!is.character(path) || length(path) != 1L || is.na(path) || !dir.exists(path)) {
    cli::cli_abort(
      "{.arg path} must be an existing Salmon Data Package directory.",
      call = call
    )
  }

  values <- values[!vapply(values, is.null, logical(1))]
  if (length(values) == 0L) {
    cli::cli_abort(
      c(
        "Nothing to set.",
        "i" = "Name at least one field, for example {.code creator = \"...\"}."
      ),
      call = call
    )
  }

  declared <- purrr::map_chr(.ms_metadata_schema_fields(file_name), "name")
  unknown <- setdiff(names(values), declared)
  if (length(unknown) > 0L) {
    cli::cli_abort(
      c(
        "{cli::qty(length(unknown))}{.file {file_name}} has no such field{?s}.",
        .ms_cli_bullets(unknown, "x"),
        "i" = paste0("Available: ", .ms_cli_escape(paste(declared, collapse = ", ")))
      ),
      call = call
    )
  }
  protected <- intersect(names(values), .ms_metadata_key_fields(file_name))
  if (length(protected) > 0L) {
    cli::cli_abort(
      c(
        "{cli::qty(length(protected))}{?This/These} field{?s} address{?es/} the row and cannot be set.",
        .ms_cli_bullets(protected, "x"),
        "i" = "Rebuild the package to change how a row is identified."
      ),
      call = call
    )
  }

  # Containment BEFORE any read: a `metadata/` replaced by a symlink would
  # otherwise be read, and then written through, outside the package.
  managed <- c(.ms_metadata_path(path, file_name), file.path(path, "datapackage.json"))
  .ms_assert_managed_path_contained(path, managed)

  located <- .ms_locate_metadata_file(path, file_name)
  if (length(located) != 1L || is.na(located) || dir.exists(located)) {
    cli::cli_abort(
      c(
        "This package has no {.file {file_name}}.",
        "i" = "Rebuild it with {.fn create_sdp} or {.fn write_salmon_datapackage}."
      ),
      call = call
    )
  }
  frame <- tibble::as_tibble(.ms_read_metadata_csv(located))

  # Address FIRST, value second: a call pasted without editing its `<...>`
  # placeholder must prove the address resolves before it is refused, so a
  # printed call that names a column the package does not have fails on the
  # address rather than being masked by the placeholder guard.
  row <- .ms_resolve_metadata_row(frame, file_name, keys, call = call)

  for (field in names(values)) {
    value <- .ms_assert_metadata_value(values[[field]], field, call = call)
    if (!field %in% names(frame)) {
      frame[[field]] <- NA_character_
    }
    frame[[field]][[row]] <- value
  }

  align <- list(
    "dataset.csv" = .ms_dataset_meta_cols,
    "tables.csv" = .ms_table_meta_cols,
    "column_dictionary.csv" = .ms_dictionary_cols,
    "codes.csv" = .ms_codes_cols
  )
  writes <- list()
  writes[[located]] <- .ms_sdp_extension_csv_bytes(
    .ms_align_cols(frame, align[[file_name]]()),
    na = .ms_csv_na_token()
  )

  descriptor_path <- file.path(path, "datapackage.json")
  if (file.exists(descriptor_path) && !dir.exists(descriptor_path)) {
    descriptor <- tryCatch(
      jsonlite::read_json(descriptor_path, simplifyVector = FALSE),
      error = function(error) {
        .ms_abort_external("Could not parse datapackage.json: ", conditionMessage(error))
      }
    )
    patched <- .ms_descriptor_sync_metadata_row(
      descriptor, file_name, frame, row, names(values)
    )
    if (!is.null(patched)) {
      writes[[descriptor_path]] <- .ms_datapackage_json_bytes(patched)
    }
  }

  .ms_commit_package_write(path, writes, managed_paths = names(writes), prune = FALSE)

  if (!isTRUE(quiet)) {
    fields <- names(values)
    cli::cli_alert_success(
      "Set {length(fields)} field{?s} in {.file {file_name}}: {.field {fields}}."
    )
  }
  invisible(path)
}

#' Fill in a package's free-text metadata
#'
#' The scriptable replacement for opening `metadata/*.csv` in a spreadsheet.
#' Each setter addresses one row and writes the named fields into it, keeping
#' `datapackage.json` in step in the same transactional write. Every field the
#' SDP schema declares for that file can be set: the ones most often unfilled
#' are named arguments for discoverability, and the rest are passed through
#' `...` and checked against the schema, so a misspelling is an error rather
#' than a silent no-op.
#'
#' These are the calls [review_metadata()] prints. Replace the `<...>`
#' placeholder with the real value and paste -- pasting one unedited is refused
#' with a message saying so, because a package whose `creator` reads `<add
#' creator, team, or originating program>` would pass strict validation while
#' saying nothing.
#'
#' Pass `NA` to clear a field deliberately; a blank string is refused as
#' ambiguous.
#'
#' @param path Path to the package directory.
#' @param table Table identifier. For [set_sdp_column()] and [set_sdp_code()]
#'   it is needed only when the column name appears in more than one table;
#'   [review_metadata()] always prints it.
#' @param column Column name of the dictionary or codes row.
#' @param code_value The code value identifying a `codes.csv` row.
#' @param title,description,creator,contact_name,contact_email,contact_org,license
#'   `dataset.csv` fields.
#' @param table_label,observation_unit,observation_unit_iri `tables.csv` fields.
#' @param column_label,column_description,unit_label `column_dictionary.csv`
#'   free-text fields.
#' @param term_iri,property_iri,entity_iri,unit_iri `column_dictionary.csv`
#'   (and, for `term_iri`, `codes.csv`) semantic IRIs. Use these for a slot
#'   retrieval found no candidate for; use [accept_suggestion()] when there is
#'   a shortlist to choose from.
#' @param code_label,code_description,vocabulary_iri `codes.csv` fields.
#' @param quiet Logical; suppress the confirmation message.
#' @param ... Any other field the SDP schema declares for that file, as
#'   `name = value`.
#'
#' @return The package path, invisibly.
#' @seealso [review_metadata()], [accept_suggestion()],
#'   [validate_salmon_datapackage()]
#' @export
#'
#' @examples
#' \dontrun{
#' pkg <- create_sdp(resources, dataset_id = "demo-1")
#' review_metadata(pkg)
#' set_sdp_dataset(
#'   pkg,
#'   creator = "Fisheries and Oceans Canada",
#'   contact_name = "Data Unit",
#'   contact_email = "data@example.org",
#'   license = "CC-BY-4.0"
#' )
#' set_sdp_table(pkg, "spawners", description = "One row per stream and year.")
#' set_sdp_column(pkg, "spawner_count", column_description = "Spawners counted.")
#' }
set_sdp_dataset <- function(path,
                            ...,
                            title = NULL,
                            description = NULL,
                            creator = NULL,
                            contact_name = NULL,
                            contact_email = NULL,
                            contact_org = NULL,
                            license = NULL,
                            quiet = FALSE) {
  .ms_set_sdp_metadata(
    path,
    "dataset.csv",
    keys = list(),
    values = c(
      list(
        title = title, description = description, creator = creator,
        contact_name = contact_name, contact_email = contact_email,
        contact_org = contact_org, license = license
      ),
      .ms_setter_dots(...)
    ),
    quiet = quiet
  )
}

#' @rdname set_sdp_dataset
#' @export
set_sdp_table <- function(path,
                          table,
                          ...,
                          table_label = NULL,
                          description = NULL,
                          observation_unit = NULL,
                          observation_unit_iri = NULL,
                          quiet = FALSE) {
  .ms_set_sdp_metadata(
    path,
    "tables.csv",
    keys = list(table_id = table),
    values = c(
      list(
        table_label = table_label, description = description,
        observation_unit = observation_unit,
        observation_unit_iri = observation_unit_iri
      ),
      .ms_setter_dots(...)
    ),
    quiet = quiet
  )
}

#' @rdname set_sdp_dataset
#' @export
set_sdp_column <- function(path,
                           column,
                           ...,
                           table = NULL,
                           column_label = NULL,
                           column_description = NULL,
                           unit_label = NULL,
                           term_iri = NULL,
                           property_iri = NULL,
                           entity_iri = NULL,
                           unit_iri = NULL,
                           quiet = FALSE) {
  .ms_set_sdp_metadata(
    path,
    "column_dictionary.csv",
    keys = list(table_id = table, column_name = column),
    values = c(
      list(
        column_label = column_label, column_description = column_description,
        unit_label = unit_label, term_iri = term_iri,
        property_iri = property_iri, entity_iri = entity_iri, unit_iri = unit_iri
      ),
      .ms_setter_dots(...)
    ),
    quiet = quiet
  )
}

#' @rdname set_sdp_dataset
#' @export
set_sdp_code <- function(path,
                         column,
                         code_value,
                         ...,
                         table = NULL,
                         code_label = NULL,
                         code_description = NULL,
                         term_iri = NULL,
                         vocabulary_iri = NULL,
                         quiet = FALSE) {
  .ms_set_sdp_metadata(
    path,
    "codes.csv",
    keys = list(table_id = table, column_name = column, code_value = code_value),
    values = c(
      list(
        code_label = code_label, code_description = code_description,
        term_iri = term_iri, vocabulary_iri = vocabulary_iri
      ),
      .ms_setter_dots(...)
    ),
    quiet = quiet
  )
}

# `...` is the schema escape hatch: the named arguments above cover the fields
# users actually fill, and every other declared field stays reachable without
# this file having to re-spell a schema that is loaded at runtime and can move
# under it. Unnamed arguments are refused, because a positional value here has
# no field to belong to and silently doing nothing is the failure mode `...`
# is famous for.
.ms_setter_dots <- function(...) {
  dots <- list(...)
  if (length(dots) == 0L) {
    return(list())
  }
  names_given <- names(dots) %||% rep("", length(dots))
  if (any(!nzchar(names_given))) {
    cli::cli_abort(c(
      "Every extra argument must name the field it sets.",
      "i" = "For example {.code observation_unit = \"one stream-year\"}."
    ))
  }
  dots
}
