# Surgical metadata write-back for the R-native review flow (stream S5).
#
# `write_salmon_datapackage()` rewrites a whole package from in-memory objects.
# A review decision is a much smaller edit: change the decided cells in the
# metadata CSVs and leave everything else -- above all the data CSV bytes --
# exactly as it was. That byte assertion is the point of "surgical", and it is
# the only one that fails if this ever regresses into a full rewrite.
#
# ATOMICITY IS CROSS-FILE, NOT PER-FILE. One `apply_sdp_semantics()` call can
# change `metadata/column_dictionary.csv`, `metadata/codes.csv`,
# `metadata/tables.csv`, `semantic_suggestions.csv` AND the field entries
# `datapackage.json` duplicates. Replacing each atomically still leaves a window
# where the CSV is new and the descriptor is old, and the rule that would catch
# that drift (`datapackage_consistent_with_csv_metadata`) is one of the dead
# rules in `sdp.rules.yaml` -- nothing would detect it. So every affected file
# is rendered to bytes first and installed as one set by
# `.ms_commit_package_write()`, which stages every replacement before moving any
# current file and restores the originals on failure.

# Which descriptor field key mirrors a dictionary column. The writer in
# `write_salmon_datapackage()` emits these keys verbatim and omits them when
# empty; this table is what keeps the surgical patch producing the same shape
# the full rebuild would.
.ms_descriptor_field_keys <- function() {
  c(
    term_iri = "term_iri",
    term_type = "term_type",
    property_iri = "property_iri",
    entity_iri = "entity_iri",
    unit_iri = "unit_iri",
    constraint_iri = "constraint_iri",
    statistical_modifier_iri = "statistical_modifier_iri"
  )
}

# Update one resource's schema fields from the (already updated) dictionary.
# Only touches the keys above and only for columns the review changed, so a
# descriptor a user hand-edited elsewhere survives untouched.
.ms_descriptor_sync_fields <- function(descriptor, dictionary, changed) {
  if (is.null(descriptor) || is.null(descriptor$resources) || nrow(changed) == 0L) {
    return(descriptor)
  }
  keys <- .ms_descriptor_field_keys()

  descriptor$resources <- lapply(descriptor$resources, function(resource) {
    resource_name <- resource$name %||% ""
    if (!is.list(resource$schema) || is.null(resource$schema$fields)) {
      return(resource)
    }
    resource$schema$fields <- lapply(resource$schema$fields, function(field) {
      column <- field$name %||% ""
      hit <- which(
        as.character(changed$table_id) == as.character(resource_name) &
          as.character(changed$column_name) == as.character(column)
      )
      if (length(hit) == 0L) {
        return(field)
      }
      dict_row <- which(
        as.character(dictionary$table_id) == as.character(resource_name) &
          as.character(dictionary$column_name) == as.character(column)
      )
      if (length(dict_row) != 1L) {
        return(field)
      }
      for (key in names(keys)) {
        if (!key %in% names(dictionary)) {
          next
        }
        value <- .ms_scalar_text(dictionary[[key]][[dict_row]])
        # Present when non-empty, absent when empty -- exactly the
        # `if (!is.na(...) && ... != "")` shape the writer uses.
        field[[keys[[key]]]] <- if (nzchar(value)) value else NULL
      }
      field
    })
    resource
  })
  descriptor
}

#' Write semantic review decisions into a package
#'
#' Applies the decisions recorded by [accept_suggestion()] and
#' [reject_suggestion()] to a written Salmon Data Package. Accepted IRIs are
#' written with the `REVIEW:` prefix stripped; rejected slots are cleared;
#' every other field, and every data CSV byte, is left untouched.
#'
#' Safe to re-run: applying the same review twice produces identical bytes.
#' Only fields carrying a decision are written, so undecided slots keep their
#' `REVIEW:` markers.
#'
#' The metadata CSVs, `semantic_suggestions.csv` and `datapackage.json` are
#' installed as one transactional set -- the descriptor duplicates the
#' dictionary's IRI fields, and a half-applied edit would leave the package
#' quietly self-inconsistent.
#'
#' @param path Path to the package directory.
#' @param review An `ms_semantic_review` object carrying decisions.
#' @param quiet Logical; suppress the summary message.
#'
#' @return The package path, invisibly.
#' @seealso [review_semantics()], [accept_suggestion()]
#' @export
#'
#' @examples
#' \dontrun{
#' pkg <- create_sdp(resources, dataset_id = "demo-1")
#' review <- review_semantics(pkg)
#' review <- accept_suggestion(review, "spawner_count", "variable", rank = 1)
#' apply_sdp_semantics(pkg, review)
#' validate_salmon_datapackage(pkg, require_iris = TRUE)
#' }
apply_sdp_semantics <- function(path, review, quiet = FALSE) {
  .ms_review_assert_review(review)
  if (!is.character(path) || length(path) != 1L || is.na(path) || !dir.exists(path)) {
    cli::cli_abort("{.arg path} must be an existing Salmon Data Package directory.")
  }

  decisions <- .ms_review_decisions(review)
  if (nrow(decisions) == 0L) {
    if (!isTRUE(quiet)) {
      cli::cli_inform(c(
        "No decisions to apply.",
        "i" = "Record some with {.fn accept_suggestion} or {.fn reject_suggestion} first."
      ))
    }
    return(invisible(path))
  }

  unsupported <- setdiff(unique(decisions$target_file), .ms_review_writable_files())
  if (length(unsupported) > 0) {
    cli::cli_abort(c(
      "Cannot write decisions for these metadata files.",
      .ms_cli_bullets(unsupported, "x")
    ))
  }

  # Containment BEFORE any read or write, matching `write_salmon_datapackage()`:
  # a `metadata/` replaced by a symlink would otherwise be read, and then
  # written through, outside the package.
  managed <- c(
    .ms_metadata_path(path, .ms_review_writable_files()),
    file.path(path, "semantic_suggestions.csv"),
    file.path(path, "datapackage.json")
  )
  .ms_assert_managed_path_contained(path, managed)

  frames <- list()
  paths <- list()
  for (file_name in unique(decisions$target_file)) {
    located <- .ms_locate_metadata_file(path, file_name)
    if (length(located) != 1L || is.na(located) || dir.exists(located)) {
      cli::cli_abort(c(
        "Decisions target a metadata file the package does not have.",
        "x" = paste0("Missing: ", .ms_cli_escape(file_name))
      ))
    }
    frames[[file_name]] <- tibble::as_tibble(.ms_read_metadata_csv(located))
    paths[[file_name]] <- located
  }

  applied <- 0L
  changed_columns <- decisions[0, c("table_id", "column_name"), drop = FALSE]

  for (i in seq_len(nrow(decisions))) {
    row <- decisions[i, , drop = FALSE]
    file_name <- .ms_scalar_text(row$target_file)
    field <- .ms_scalar_text(row$target_field)
    frame <- frames[[file_name]]
    keys <- .ms_review_target_keys(file_name)

    if (!field %in% names(frame)) {
      frame[[field]] <- NA_character_
    }
    hits <- .ms_review_match_rows(frame, row, keys)
    if (length(hits) != 1L) {
      cli::cli_abort(c(
        "A decision does not address exactly one metadata row.",
        "x" = paste0(
          .ms_cli_escape(file_name), " \u00b7 ", .ms_cli_escape(.ms_scalar_text(row$target_row_key)),
          " matched ", length(hits), " rows."
        ),
        "i" = "Rebuild the review from the package you are writing to."
      ))
    }

    frame[[field]][[hits]] <- if (identical(row$decision[[1]], "accept")) {
      .ms_strip_review_iri(.ms_scalar_text(row$decision_iri))
    } else {
      NA_character_
    }

    # `term_type` is the dictionary's declaration of what kind of thing
    # `term_iri` names. `apply_semantic_suggestions()` infers it whenever it
    # writes a `term_iri`; a reviewed write that skipped it would leave the two
    # disagreeing, and clearing the IRI without clearing the type would leave a
    # type describing nothing.
    if (identical(file_name, "column_dictionary.csv") && identical(field, "term_iri") &&
        "term_type" %in% names(frame)) {
      frame$term_type[[hits]] <- if (identical(row$decision[[1]], "accept")) {
        # `term_type` describes the candidate. When the decision is a
        # hand-supplied `iri =` rather than a shortlisted candidate, the
        # candidate row on which the decision was recorded describes a
        # *different* term, so its type is not evidence about this one.
        if (identical(.ms_scalar_text(row$iri), .ms_scalar_text(row$decision_iri))) {
          .ms_scalar_text(row$term_type)
        } else {
          "skos_concept"
        }
      } else {
        NA_character_
      }
    }

    frames[[file_name]] <- frame
    applied <- applied + 1L
    if (identical(file_name, "column_dictionary.csv")) {
      changed_columns <- rbind(
        changed_columns,
        data.frame(
          table_id = .ms_scalar_text(row$table_id),
          column_name = .ms_scalar_text(row$column_name),
          stringsAsFactors = FALSE
        )
      )
    }
  }

  writes <- list()
  align <- list(
    "column_dictionary.csv" = .ms_dictionary_cols,
    "codes.csv" = .ms_codes_cols,
    "tables.csv" = .ms_table_meta_cols
  )
  for (file_name in names(frames)) {
    aligned <- .ms_align_cols(frames[[file_name]], align[[file_name]]())
    writes[[paths[[file_name]]]] <- .ms_sdp_extension_csv_bytes(aligned, na = .ms_csv_na_token())
  }

  # The descriptor duplicates the dictionary's IRI fields, so it is part of the
  # same logical edit. Patched surgically rather than rebuilt: a rebuild would
  # have to re-derive every resource entry from metadata this call did not
  # read, and would silently discard descriptor content a user added.
  descriptor_path <- file.path(path, "datapackage.json")
  if (file.exists(descriptor_path) && !dir.exists(descriptor_path) &&
      "column_dictionary.csv" %in% names(frames) && nrow(changed_columns) > 0L) {
    descriptor <- tryCatch(
      jsonlite::read_json(descriptor_path, simplifyVector = FALSE),
      error = function(error) {
        .ms_abort_external("Could not parse datapackage.json: ", conditionMessage(error))
      }
    )
    descriptor <- .ms_descriptor_sync_fields(
      descriptor,
      frames[["column_dictionary.csv"]],
      changed_columns
    )
    writes[[descriptor_path]] <- .ms_datapackage_json_bytes(descriptor)
  }

  # The decision record on disk. `apply_semantic_suggestions(strategy =
  # "reviewed")` has always filtered a `decision` column that nothing wrote --
  # this is that missing producer, and it is what makes the decision survive in
  # the package rather than only in the user's script.
  suggestions_path <- file.path(path, "semantic_suggestions.csv")
  if (file.exists(suggestions_path) && !dir.exists(suggestions_path)) {
    suggestions <- tibble::as_tibble(.ms_read_metadata_csv(suggestions_path))
    if (all(c("target_sdp_file", "target_row_key", "target_sdp_field", "iri") %in% names(suggestions))) {
      suggestions$decision <- NA_character_
      slot <- .ms_review_slot_id(suggestions)
      for (i in seq_len(nrow(decisions))) {
        row <- decisions[i, , drop = FALSE]
        in_slot <- slot == row$slot_id[[1]]
        if (!any(in_slot)) {
          next
        }
        if (identical(row$decision[[1]], "reject")) {
          suggestions$decision[in_slot] <- "rejected"
          next
        }
        accepted <- in_slot &
          .ms_strip_review_iri(as.character(suggestions$iri)) == .ms_scalar_text(row$decision_iri)
        suggestions$decision[in_slot] <- "not_selected"
        suggestions$decision[accepted] <- "accepted"
      }
      writes[[suggestions_path]] <- .ms_sdp_extension_csv_bytes(
        suggestions,
        na = .ms_csv_na_token()
      )
    }
  }

  .ms_commit_package_write(
    path,
    writes,
    managed_paths = names(writes),
    prune = FALSE
  )

  if (!isTRUE(quiet)) {
    cli::cli_alert_success(
      "Applied {applied} semantic review decision{?s} to {.path {path}}."
    )
    cli::cli_inform(c(
      "i" = "Check the result with {.code validate_salmon_datapackage(path, require_iris = TRUE)}."
    ))
  }
  invisible(path)
}
