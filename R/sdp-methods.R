# SDP methods migration (sdp-0.2.0 -> sdp-0.3.0) -----------------------------
#
# sdp-0.3.0 removed both the `metadata/methods.csv` registry and the
# column_dictionary `method_iri` field. Method labels and descriptions belong
# to the shared vocabulary; a table-constant procedure belongs in
# `tables.csv$method_iri`; a row-varying procedure lives in the data with its
# codes resolved through `codes.csv$term_iri`; protocols are cited through the
# `protocol_iri`/`protocol_citation` fields on `tables.csv` and `dataset.csv`.
# This module migrates sdp-0.2.0 packages to that shape. The shared
# `.ms_sdp_extension_*` I/O helpers live in sdp-extension-helpers.R.

.ms_sdp_methods_path <- "metadata/methods.csv"

# The sdp-0.2.0 registry schema, kept only to read migration input.
.ms_sdp_methods_legacy_columns <- c(
  "dataset_id",
  "method_iri",
  "method_label",
  "method_description",
  "method_version",
  "protocol_iri",
  "citation"
)

# Tolerant legacy reader: migration input, not a validation surface. The
# symlink refusals stay (we are about to delete this file), but column drift
# in a hand-edited registry must not block the migration that removes it.
.ms_sdp_methods_read_legacy <- function(root) {
  target <- file.path(root, .ms_sdp_methods_path)
  if (.ms_sdp_extension_is_symlink(target)) {
    .ms_sdp_extension_abort(
      "Refusing symlinked {.file metadata/methods.csv}."
    )
  }
  if (!file.exists(target) || dir.exists(target)) {
    return(NULL)
  }
  rows <- tryCatch(
    readr::read_csv(
      target,
      col_types = readr::cols(.default = readr::col_character()),
      na = "",
      show_col_types = FALSE,
      progress = FALSE
    ),
    error = function(error) {
      .ms_sdp_extension_abort(
        "Could not parse {.file metadata/methods.csv}: {conditionMessage(error)}"
      )
    }
  )
  tibble::as_tibble(rows)
}

# One method binding per measurement column, from both sdp-0.2.0 carriers:
# the canonical dictionary CSV and, for descriptor-first packages, the
# per-field `iAdopt:methodIri` custom key (or a bare `method_iri` field
# property). The CSV wins where both exist. Returned as a tibble of
# table_id / column_name / method_iri with blanks already removed.
.ms_sdp_methods_column_bindings <- function(root) {
  bindings <- list()

  dictionary_path <- file.path(root, "metadata", "column_dictionary.csv")
  if (file.exists(dictionary_path) && !dir.exists(dictionary_path)) {
    dictionary <- .ms_read_metadata_csv(dictionary_path)
    if (all(c("table_id", "column_name", "method_iri") %in% names(dictionary))) {
      bindings[["dictionary"]] <- tibble::tibble(
        table_id = as.character(dictionary$table_id),
        column_name = as.character(dictionary$column_name),
        method_iri = as.character(dictionary$method_iri),
        source = "metadata/column_dictionary.csv"
      )
    }
  }

  # A descriptor the migration cannot read or safely rewrite is a stop, not a
  # skip: proceeding would relocate the CSV bindings and delete the registry
  # while the descriptor keeps claiming the old shape.
  descriptor_path <- file.path(root, "datapackage.json")
  if (.ms_sdp_extension_is_symlink(descriptor_path)) {
    .ms_sdp_extension_abort(
      "Refusing symlinked {.file datapackage.json}; migration must be able to rewrite the descriptor."
    )
  }
  if (file.exists(descriptor_path)) {
    descriptor <- tryCatch(
      jsonlite::read_json(descriptor_path, simplifyVector = FALSE),
      error = function(error) {
        .ms_sdp_extension_abort(
          "Could not parse {.file datapackage.json}: {conditionMessage(error)}"
        )
      }
    )
    rows <- list()
    for (resource in descriptor$resources %||% list()) {
      # Metadata resources declare `schema` as a URL string; only inline
      # (list) schemas can carry per-field method bindings.
      fields <- if (is.list(resource$schema)) {
        resource$schema$fields %||% list()
      } else {
        list()
      }
      for (field in fields) {
        custom <- field$custom %||% list()
        method_iri <- custom[["iAdopt:methodIri"]] %||%
          field$method_iri %||% NA_character_
        if (!.ms_sdp_extension_is_blank(method_iri)) {
          rows[[length(rows) + 1]] <- tibble::tibble(
            table_id = as.character(resource$name %||% NA_character_),
            column_name = as.character(field$name %||% NA_character_),
            method_iri = as.character(method_iri),
            source = "datapackage.json"
          )
        }
      }
    }
    if (length(rows) > 0L) {
      bindings[["descriptor"]] <- dplyr::bind_rows(rows)
    }
  }

  if (length(bindings) == 0L) {
    return(tibble::tibble(
      table_id = character(),
      column_name = character(),
      method_iri = character(),
      source = character()
    ))
  }

  merged <- dplyr::bind_rows(bindings)
  merged <- merged[!.ms_sdp_extension_is_blank(merged$method_iri), , drop = FALSE]
  # A binding with no table or column to attach to cannot be placed, and an
  # NA table_id would also poison every per-table comparison below (NA == "x"
  # is NA, which subsetting treats as a phantom matching row).
  unplaceable <- .ms_sdp_extension_is_blank(merged$table_id) |
    .ms_sdp_extension_is_blank(merged$column_name)
  if (any(unplaceable)) {
    .ms_sdp_extension_abort(c(
      "Method bindings without a table and column cannot be migrated.",
      .ms_cli_bullets(
        paste0(
          merged$source[unplaceable], ": table ",
          merged$table_id[unplaceable], ", column ",
          merged$column_name[unplaceable]
        ),
        "x"
      ),
      "i" = "Fix the identifiers in the legacy metadata, then re-run."
    ))
  }
  # Two carriers claiming the same column is a judgement call, not something
  # to resolve by precedence: dropping one would erase it from the package.
  # Identical claims collapse; disagreements stop the migration.
  key <- paste(merged$table_id, merged$column_name, sep = "\r")
  merged <- merged[!duplicated(paste(key, merged$method_iri, sep = "\r")), , drop = FALSE]
  key <- paste(merged$table_id, merged$column_name, sep = "\r")
  conflicted <- key %in% key[duplicated(key)]
  if (any(conflicted)) {
    rows <- merged[conflicted, , drop = FALSE]
    .ms_sdp_extension_abort(c(
      "Method migration stopped: two carriers disagree about one column's method.",
      .ms_cli_bullets(
        paste0(
          rows$table_id, ".", rows$column_name, " = ", rows$method_iri,
          " (", rows$source, ")"
        ),
        "x"
      ),
      "i" = "Resolve the disagreement in the legacy metadata, then re-run."
    ))
  }
  merged
}

#' Migrate an sdp-0.2.0 package's method metadata to sdp-0.3.0
#'
#' sdp-0.3.0 removed the `metadata/methods.csv` registry and the
#' column-dictionary `method_iri` field. This tool relocates what can be
#' relocated mechanically and **stops and reports** on anything that needs a
#' judgement call, rather than guessing:
#'
#' * A `method_iri` shared by every bound measurement column of a table
#'   becomes that table's `tables.csv$method_iri`.
#' * Columns of one table bound to *different* methods stop the migration:
#'   you decide whether to split the table, cite a protocol, or move the
#'   method into the data as a code column (see the methods section of the
#'   SDP specification).
#' * `REVIEW:`-marked values are dropped, not migrated, and reported.
#' * Registry labels and descriptions are reported, not relocated — they
#'   belong in the shared vocabulary. A registry `method_version` or
#'   `citation` is offered in the report as `protocol_citation` material.
#'
#' The rewrite is atomic: either every affected metadata file is updated and
#' `metadata/methods.csv` removed, or nothing changes.
#'
#' @param path Existing Salmon Data Package directory.
#' @param dry_run Logical; when `TRUE`, report what would change without
#'   touching any file.
#'
#' @return Invisibly, a list report: `tables` (the table-level method
#'   placements applied), `dropped_review` (unresolved `REVIEW:` bindings
#'   dropped), and `registry` (the legacy registry rows, for relocating
#'   labels/descriptions to the shared vocabulary and citations to
#'   `protocol_citation`).
#' @export
migrate_sdp_methods <- function(path, dry_run = FALSE) {
  root <- .ms_sdp_extension_root(path)
  # `isTRUE()` decides the write, and isTRUE(1) is FALSE — so without the
  # type check a caller asking for a preview with `dry_run = 1` would get the
  # destructive path instead.
  if (!is.logical(dry_run) || length(dry_run) != 1L || is.na(dry_run)) {
    .ms_sdp_extension_abort("{.arg dry_run} must be TRUE or FALSE.")
  }

  bindings <- .ms_sdp_methods_column_bindings(root)
  registry <- .ms_sdp_methods_read_legacy(root)

  review_marked <- grepl("^REVIEW:", bindings$method_iri, ignore.case = TRUE)
  dropped_review <- bindings[review_marked, , drop = FALSE]
  bindings <- bindings[!review_marked, , drop = FALSE]

  # "Nothing to migrate" means the package already has the v0.3 shape.
  # REVIEW:-only bindings and a lingering dictionary method_iri column both
  # still require the rewrite, or the obsolete schema would survive the run
  # that reported dropping its values.
  dictionary_probe_path <- file.path(root, "metadata", "column_dictionary.csv")
  dictionary_has_method_column <-
    file.exists(dictionary_probe_path) &&
    !dir.exists(dictionary_probe_path) &&
    "method_iri" %in% names(.ms_read_metadata_csv(dictionary_probe_path))
  if (nrow(bindings) == 0L && nrow(dropped_review) == 0L &&
      is.null(registry) && !dictionary_has_method_column) {
    cli::cli_inform("Nothing to migrate: no method bindings and no {.file metadata/methods.csv}.")
    return(invisible(list(
      tables = tibble::tibble(table_id = character(), method_iri = character()),
      dropped_review = dropped_review,
      registry = NULL
    )))
  }

  # Per-table agreement check: one method per table proceeds, disagreement
  # stops. The whole report is assembled before stopping so one run surfaces
  # every decision the contributor has to make.
  placements <- list()
  conflicts <- character()
  # Canonical order: `report$tables` is an exported return value and the
  # conflict text is user-facing, so neither may depend on the order rows
  # happened to appear in the legacy metadata.
  for (tbl in sort(unique(bindings$table_id), method = "radix")) {
    rows <- bindings[bindings$table_id == tbl, , drop = FALSE]
    iris <- sort(unique(rows$method_iri), method = "radix")
    if (length(iris) == 1L) {
      placements[[length(placements) + 1]] <- tibble::tibble(
        table_id = tbl,
        method_iri = iris,
        columns = paste(sort(rows$column_name, method = "radix"), collapse = ", ")
      )
    } else {
      detail <- vapply(
        iris,
        function(iri) {
          cols <- rows$column_name[rows$method_iri == iri]
          paste0(iri, " (", paste(sort(cols, method = "radix"), collapse = ", "), ")")
        },
        character(1)
      )
      conflicts <- c(
        conflicts,
        paste0("Table ", tbl, ": ", paste(detail, collapse = " vs "))
      )
    }
  }
  placements <- if (length(placements) > 0L) {
    dplyr::bind_rows(placements)
  } else {
    tibble::tibble(table_id = character(), method_iri = character(), columns = character())
  }

  # An existing non-blank tables.csv method_iri that disagrees with the
  # dictionary-derived placement is also a stop: two carriers, two claims.
  tables_path <- file.path(root, "metadata", "tables.csv")
  tables <- NULL
  if (file.exists(tables_path) && !dir.exists(tables_path)) {
    tables <- .ms_read_metadata_csv(tables_path)
    if ("method_iri" %in% names(tables) && nrow(placements) > 0L) {
      for (index in seq_len(nrow(placements))) {
        tbl <- placements$table_id[[index]]
        existing <- tables$method_iri[tables$table_id == tbl]
        existing <- existing[!.ms_sdp_extension_is_blank(existing)]
        if (length(existing) > 0L &&
            !all(existing == placements$method_iri[[index]])) {
          conflicts <- c(conflicts, paste0(
            "Table ", tbl, ": tables.csv already claims ", existing[[1]],
            " but the dictionary columns claim ", placements$method_iri[[index]]
          ))
        }
      }
    }
  }

  if (length(conflicts) > 0L) {
    .ms_sdp_extension_abort(c(
      "Method migration stopped: measurement columns disagree about their table's method.",
      .ms_cli_bullets(conflicts, "x"),
      "i" = "Split the table, cite a protocol instead, or move the method into the data as a code column, then re-run.",
      "i" = "See the methods section of the SDP specification for the three placements."
    ))
  }

  # ---- Report ---------------------------------------------------------------
  if (nrow(placements) > 0L) {
    cli::cli_inform(c(
      "Table-level method placements:",
      .ms_cli_bullets(
        paste0(placements$table_id, " -> ", placements$method_iri,
               " (from ", placements$columns, ")"),
        "v"
      )
    ))
  }
  if (nrow(dropped_review) > 0L) {
    cli::cli_inform(c(
      "Unresolved {.code REVIEW:} method bindings dropped (resolve them via term search before publishing):",
      .ms_cli_bullets(
        paste0(dropped_review$table_id, ".", dropped_review$column_name,
               " = ", dropped_review$method_iri),
        "x"
      )
    ))
  }
  if (!is.null(registry) && nrow(registry) > 0L) {
    labels <- registry$method_label %||% rep(NA_character_, nrow(registry))
    iris <- registry$method_iri %||% rep(NA_character_, nrow(registry))
    cli::cli_inform(c(
      "{.file metadata/methods.csv} is removed by this migration. Its labels and descriptions belong in the shared vocabulary; its version and citation belong beside {.field protocol_iri}:",
      .ms_cli_bullets(paste0(iris, " (", labels, ")"), "*"),
      "i" = "Request missing vocabulary terms through the ontology's shared-term admission policy, and copy any registry citation into {.field protocol_citation}."
    ))
  }

  report <- list(
    tables = placements,
    dropped_review = dropped_review,
    registry = registry
  )

  if (isTRUE(dry_run)) {
    cli::cli_inform("Dry run: no files were changed.")
    return(invisible(report))
  }

  # ---- Rewrite --------------------------------------------------------------
  writes <- list()

  # A placement that lands nowhere would erase every carrier of a method IRI
  # while writing it to no file, so the destination must exist first.
  if (nrow(placements) > 0L && (is.null(tables) || !"table_id" %in% names(tables))) {
    .ms_sdp_extension_abort(
      "Cannot migrate table-level methods: {.file metadata/tables.csv} is missing or has no {.field table_id}."
    )
  }
  if (!is.null(tables)) {
    new_tables <- tables
    if (!"method_iri" %in% names(new_tables)) {
      new_tables$method_iri <- NA_character_
    }
    if (nrow(placements) > 0L) {
      unmatched <- setdiff(placements$table_id, as.character(new_tables$table_id))
      if (length(unmatched) > 0L) {
        .ms_sdp_extension_abort(c(
          "Method bindings name tables that {.file metadata/tables.csv} does not declare.",
          .ms_cli_bullets(unmatched, "x"),
          "i" = "Fix the table identifiers in the legacy metadata, then re-run."
        ))
      }
      for (index in seq_len(nrow(placements))) {
        hit <- new_tables$table_id == placements$table_id[[index]]
        new_tables$method_iri[hit] <- placements$method_iri[[index]]
      }
    }
    new_tables <- .ms_align_cols(new_tables, .ms_table_meta_cols())
    writes[[tables_path]] <- .ms_sdp_extension_csv_bytes(new_tables)
  }

  dictionary_path <- file.path(root, "metadata", "column_dictionary.csv")
  if (file.exists(dictionary_path) && !dir.exists(dictionary_path)) {
    dictionary <- .ms_read_metadata_csv(dictionary_path)
    dictionary$method_iri <- NULL
    dictionary <- .ms_align_cols(dictionary, .ms_dictionary_cols())
    writes[[dictionary_path]] <- .ms_sdp_extension_csv_bytes(dictionary)
  }

  dataset_path <- file.path(root, "metadata", "dataset.csv")
  if (file.exists(dataset_path) && !dir.exists(dataset_path)) {
    dataset <- .ms_read_metadata_csv(dataset_path)
    if ("spec_version" %in% names(dataset)) {
      dataset$spec_version <- .ms_sdp_profile_version()
    }
    dataset <- .ms_align_cols(dataset, .ms_dataset_meta_cols())
    writes[[dataset_path]] <- .ms_sdp_extension_csv_bytes(dataset)
  }

  # The gather phase already aborted on a symlinked or unparseable
  # descriptor, so reaching here means it is safe to rewrite.
  descriptor_path <- file.path(root, "datapackage.json")
  if (file.exists(descriptor_path)) {
    descriptor <- tryCatch(
      jsonlite::read_json(descriptor_path, simplifyVector = FALSE),
      error = function(error) {
        .ms_sdp_extension_abort(
          "Could not parse {.file datapackage.json}: {conditionMessage(error)}"
        )
      }
    )
    if (!is.null(descriptor)) {
      sdp_schema <- .ms_load_sdp_schema(quiet = TRUE)
      descriptor$resources <- purrr::keep(
        descriptor$resources %||% list(),
        function(resource) {
          !identical(resource$name %||% "", "sdp_methods") &&
            !identical(resource$path %||% "", .ms_sdp_methods_path)
        }
      )
      descriptor$resources <- purrr::map(descriptor$resources, function(resource) {
        # Metadata resources declare `schema` as a URL string, not a list.
        if (is.list(resource$schema) && !is.null(resource$schema$fields)) {
          resource$schema$fields <- purrr::map(resource$schema$fields, function(field) {
            field$custom[["iAdopt:methodIri"]] <- NULL
            field$method_iri <- NULL
            if (!is.null(field$custom) && length(field$custom) == 0L) {
              field$custom <- NULL
            }
            field
          })
        }
        resource
      })
      descriptor$sdp$metadata$methods <- NULL
      descriptor$profile <- sdp_schema$profile_uri %||% descriptor$profile
      if (!is.null(descriptor$sdp)) {
        descriptor$sdp$specVersion <- sdp_schema$version %||% descriptor$sdp$specVersion
        # The writer emits the profile URI twice, top level and under `sdp`.
        # Updating only one leaves a descriptor that contradicts itself.
        descriptor$sdp$profile <- sdp_schema$profile_uri %||% descriptor$sdp$profile
        descriptor$sdp$rules <- sdp_schema$rules_uri %||% descriptor$sdp$rules
      }
      writes[[descriptor_path]] <- .ms_sdp_extension_json_bytes(descriptor)
    }
  }

  # Registry removal is part of the transaction: the registry is renamed
  # aside BEFORE the metadata rewrite, restored if the rewrite fails, and
  # discarded only after it succeeds. A package can therefore never end up
  # with v0.3 metadata beside a registry that v0.3 validation rejects.
  registry_path <- file.path(root, .ms_sdp_methods_path)
  registry_backup <- NA_character_
  if (file.exists(registry_path)) {
    registry_backup <- tempfile(
      pattern = ".methods.csv-migrate-",
      tmpdir = dirname(registry_path)
    )
    if (!file.rename(registry_path, registry_backup)) {
      .ms_sdp_extension_abort(
        "Could not remove {.file metadata/methods.csv}; migration aborted before any changes."
      )
    }
  }

  if (length(writes) > 0L) {
    tryCatch(
      .ms_sdp_extension_atomic_write_set(writes),
      error = function(error) {
        if (!is.na(registry_backup) && file.exists(registry_backup)) {
          if (!file.rename(registry_backup, registry_path)) {
            cli::cli_warn(
              "Could not restore {.file metadata/methods.csv} after a failed migration; recover it from {.file {basename(registry_backup)}}."
            )
          }
        }
        stop(error)
      }
    )
  }
  if (!is.na(registry_backup) && file.exists(registry_backup)) {
    unlink(registry_backup)
  }

  cli::cli_inform(c(
    "v" = "Migration complete.",
    "i" = "Run {.run validate_salmon_datapackage(\"{path}\")} to confirm the package."
  ))
  invisible(report)
}
