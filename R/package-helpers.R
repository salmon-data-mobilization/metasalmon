#' Write a Salmon Data Package from preassembled metadata
#'
#' Advanced/manual writer for cases where you already have the canonical Salmon
#' Data Package (SDP) metadata tables assembled. It writes the SDP CSV metadata
#' files under `metadata/` (`dataset.csv`, `tables.csv`,
#' `column_dictionary.csv`, and optional `codes.csv`) plus the data resource
#' files themselves under `data/`. For interoperability with Frictionless-style
#' tooling, the function also emits a derived `datapackage.json` descriptor at
#' the package root.
#'
#' The SDP CSV files remain the canonical package metadata. `datapackage.json`
#' is a convenience export, not the source of truth.
#'
#' The write is transactional over the files it owns: every output is fully
#' rendered before anything on disk is deleted or replaced, and a failure while
#' installing the rendered files restores the previous package. An error partway
#' through therefore leaves an existing package intact rather than destroyed.
#' The one exception is `prune = TRUE`, which deletes files the writer does not
#' own and so cannot restore: the wipe still happens only after every
#' input-dependent step has succeeded, but a filesystem failure (disk full,
#' permissions) between the wipe and the install can lose the deleted files.
#'
#' @param resources Named list of data frames/tibbles (one per resource)
#' @param dataset_meta Tibble with dataset-level metadata (one row)
#' @param table_meta Tibble with table-level metadata (one row per table)
#' @param dict Dictionary tibble with column definitions
#' @param codes Optional tibble with code lists
#' @param path Character; directory path where package will be written
#' @param format Character; resource format: `"csv"` (default, only format supported)
#' @param overwrite Logical; if `FALSE` (default), errors when `path` is a
#'   directory that already holds something. An existing but *completely empty*
#'   directory is written into without `overwrite` — there is nothing there to
#'   destroy — while a dot-file, a stale `.metasalmon-package` sentinel, or an
#'   empty `data/` subdirectory all count as content and still require it. If
#'   `TRUE`, the package is updated in place — see `prune`. Replacement is only
#'   allowed for directories previously written by `metasalmon`.
#' @param write_datapackage Logical; if `TRUE` (default), write a root
#'   `datapackage.json` descriptor declaring the SDP Frictionless profile after
#'   package validation passes. Use `FALSE` for draft authoring output.
#' @param prune Logical; if `FALSE` (default), only files this writer owns are
#'   replaced: the `metadata/` SDP CSVs, the `data/` resources declared in
#'   `tables.csv` (including any a previous write declared and this one does
#'   not), `datapackage.json`, and the ownership sentinel. Everything else is
#'   preserved — reviewed SSSOM mappings and measurement decompositions under
#'   `metadata/semantic/`, EML and EDH XML, `eml-mapping.yml`, review notes, and
#'   `publication/` artifacts. If `TRUE`, every entry in the directory is
#'   deleted first (the pre-0.2.0 behaviour). Requires `overwrite = TRUE`.
#'
#' @return Invisibly returns the path to the created package
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # Create a simple package
#' resources <- list(main_table = mtcars)
#' dataset_meta <- tibble::tibble(
#'   dataset_id = "test-1",
#'   title = "Test Dataset",
#'   description = "A test dataset"
#' )
#' table_meta <- tibble::tibble(
#'   dataset_id = "test-1",
#'   table_id = "main_table",
#'   file_name = "data/main_table.csv",
#'   table_label = "Main Table"
#' )
#' dict <- infer_dictionary(mtcars, dataset_id = "test-1", table_id = "main_table")
#' write_salmon_datapackage(
#'   resources, dataset_meta, table_meta, dict,
#'   path = tempdir()
#' )
#' }
write_salmon_datapackage <- function(
    resources,
    dataset_meta,
    table_meta,
    dict,
    codes = NULL,
    path,
    format = "csv",
    overwrite = FALSE,
    write_datapackage = TRUE,
    prune = FALSE
) {
  if (!identical(format, "csv")) {
    cli::cli_abort("Only CSV format is supported. Use {.code format = 'csv'}")
  }

  # Validate inputs
  if (!inherits(dataset_meta, "data.frame") || nrow(dataset_meta) != 1) {
    cli::cli_abort("{.arg dataset_meta} must be a single-row tibble")
  }

  if (!inherits(table_meta, "data.frame") || nrow(table_meta) == 0) {
    cli::cli_abort("{.arg table_meta} must be a non-empty tibble")
  }

  if (!is.list(resources) || length(resources) == 0) {
    cli::cli_abort("{.arg resources} must be a named list of data frames")
  }

  if (is.null(names(resources)) || any(!nzchar(names(resources)))) {
    cli::cli_abort("{.arg resources} must be a named list")
  }

  # Validate dictionary (also normalizes optional columns)
  dict <- validate_dictionary(dict, require_iris = FALSE)

  dataset_meta <- .ms_fill_review_placeholders_dataset_meta(.ms_normalize_dataset_meta(dataset_meta))
  table_meta <- .ms_fill_review_placeholders_table_meta(.ms_normalize_table_meta(table_meta))
  dict <- .ms_fill_review_placeholders_dictionary(.ms_normalize_dictionary(dict))
  codes <- .ms_normalize_codes(codes)

  dataset_id <- dataset_meta$dataset_id[1]
  # `target_dataset_id` exists because `dict` has a `dataset_id` column: a local
  # of the same name is shadowed by the dplyr data mask, which would turn the
  # scoping filter below into a no-op and leak other datasets' columns.
  target_dataset_id <- dataset_id

  # Resolve every resource file name BEFORE preparing the directory, so the set
  # of paths this call will write is exactly the set it is allowed to delete.
  # Resolving inside the write loop instead would let the two drift apart.
  writable_resources <- intersect(names(resources), table_meta$table_id)
  skipped_resources <- setdiff(names(resources), writable_resources)
  for (resource_name in skipped_resources) {
    cli::cli_warn(
      "No table metadata found for resource {.val {resource_name}}, skipping"
    )
  }

  resolved_file_names <- character()
  for (resource_name in writable_resources) {
    file_name <- table_meta$file_name[table_meta$table_id == resource_name][1]
    if (is.na(file_name) || file_name == "") {
      file_name <- file.path("data", paste0(resource_name, ".", format))
    }
    file_name <- .ms_force_data_subdir(.ms_normalize_resource_file_name(file_name))
    table_meta$file_name[table_meta$table_id == resource_name] <- file_name
    resolved_file_names[[resource_name]] <- file_name
  }

  # Containment BEFORE reading anything. `.ms_package_managed_paths()` parses the
  # previous `tables.csv`, so a `metadata/` or `metadata/tables.csv` symlinked to
  # a FIFO or an enormous external file would be read before the guard ran. The
  # metadata paths are known without reading, so they can be checked first.
  metadata_names <- c("dataset.csv", "tables.csv", "column_dictionary.csv", "codes.csv")
  .ms_assert_managed_path_contained(
    path,
    c(
      .ms_metadata_path(path, metadata_names),
      # The legacy root-level shadows too: `.ms_locate_metadata_file()` accepts
      # them, so `.ms_previous_declared_data_paths()` will read a root
      # `tables.csv` when `metadata/tables.csv` is absent. Checking only the
      # `metadata/` copies left that path unguarded.
      file.path(path, metadata_names),
      file.path(path, "datapackage.json"),
      .ms_package_sentinel_file(path)
    )
  )
  managed_paths <- .ms_package_managed_paths(path, data_file_names = resolved_file_names)
  orphaned <- setdiff(.ms_previous_declared_data_paths(path), resolved_file_names)
  orphaned <- orphaned[file.exists(file.path(path, orphaned))]

  # Non-destructive preflight only. Nothing on disk is deleted or replaced
  # until every input-dependent computation below has succeeded: the old
  # ordering unlinked the managed paths here and wrote replacements afterwards,
  # so ANY abort in between -- a typed metadata column, a broken schema bundle,
  # a serialization error -- destroyed the caller's package (backlog #96). The
  # entire write set is rendered to bytes first and every deletion/replacement
  # happens in one place, `.ms_commit_package_write()`, at the end.
  .ms_check_package_write_dir(path, overwrite = overwrite, prune = prune)

  # Render resources to bytes and build the derived datapackage descriptor.
  # `writes` is keyed by absolute target path; list-assignment by name keeps
  # the last rendering when two resources resolve to one file, matching the
  # last-write-wins behaviour of the sequential writes it replaced.
  writes <- list()
  resource_list <- list()
  for (resource_name in writable_resources) {
    resource_df <- resources[[resource_name]]

    table_info <- table_meta %>%
      dplyr::filter(.data$table_id == resource_name)

    file_name <- resolved_file_names[[resource_name]]

    file_path <- file.path(path, file_name)
    # Rendered to bytes now, installed later by `.ms_commit_package_write()`.
    # `na = ""` on both sides of the round trip, matching the metadata writers
    # below. readr's default writes a missing value as the two characters `NA`,
    # which is a real fisheries code -- so a literal "NA" and a genuinely
    # missing value produced *identical bytes* and the distinction was destroyed
    # at write time, where no reader could recover it.
    # Date columns are rendered here rather than by readr, which reaches
    # `as.character.Date` and emits an unpadded year below 1000 -- text this
    # package's own reader parses as NA. Date only; readr's POSIXct output is
    # already correct and coercing it would change bytes. See
    # `.ms_iso_date_columns()`.
    writes[[file_path]] <- .ms_sdp_extension_csv_bytes(
      .ms_iso_date_columns(resource_df),
      na = .ms_csv_na_token()
    )

    table_dict <- dict %>%
      dplyr::filter(
        .data$dataset_id == .env$target_dataset_id,
        .data$table_id == resource_name
      )

    fields <- purrr::map(seq_len(nrow(table_dict)), function(i) {
      field <- list(
        name = table_dict$column_name[i],
        title = table_dict$column_label[i],
        type = table_dict$value_type[i],
        description = table_dict$column_description[i]
      )

      if (isTRUE(table_dict$required[i])) {
        field$constraints <- list(required = TRUE)
      }

      if (!is.na(table_dict$unit_iri[i]) && table_dict$unit_iri[i] != "") {
        field$unit_iri <- table_dict$unit_iri[i]
      }
      if (!is.na(table_dict$term_iri[i]) && table_dict$term_iri[i] != "") {
        field$term_iri <- table_dict$term_iri[i]
      }
      if (!is.na(table_dict$term_type[i]) && table_dict$term_type[i] != "") {
        field$term_type <- table_dict$term_type[i]
      }
      if (!is.na(table_dict$property_iri[i]) && table_dict$property_iri[i] != "") {
        field$property_iri <- table_dict$property_iri[i]
      }
      if (!is.na(table_dict$entity_iri[i]) && table_dict$entity_iri[i] != "") {
        field$entity_iri <- table_dict$entity_iri[i]
      }
      if (!is.na(table_dict$constraint_iri[i]) && table_dict$constraint_iri[i] != "") {
        field$constraint_iri <- table_dict$constraint_iri[i]
      }
      if (!is.na(table_dict$statistical_modifier_iri[i]) && table_dict$statistical_modifier_iri[i] != "") {
        field$statistical_modifier_iri <- table_dict$statistical_modifier_iri[i]
      }

      field[!purrr::map_lgl(field, is.null)]
    })

    resource_entry <- list(
      name = resource_name,
      path = file_name,
      profile = "tabular-data-resource",
      schema = list(fields = fields)
    )

    if (.ms_meta_scalar_present(table_info$table_label)) {
      resource_entry$title <- table_info$table_label[1]
    }
    if (.ms_meta_scalar_present(table_info$description)) {
      resource_entry$description <- table_info$description[1]
    }
    if (.ms_meta_scalar_present(table_info$primary_key)) {
      primary_key <- trimws(unlist(strsplit(as.character(table_info$primary_key[1]), ",")))
      # A one-column key is a JSON string, a composite key a JSON array —
      # `auto_unbox = TRUE` in the `write_json()` call below does the unboxing.
      # This is not incidental: smn-data-pkg's strict publication validator
      # derives the expected value with `descriptor_primary_key()`, which
      # returns `parts[0]` for a single column, and reports
      # "primaryKey must be 'pop_id'; found ['pop_id']" for the array form.
      # Frictionless v1, which SDP targets via its top-level `profile` key,
      # permits either shape, so only the SDP validator settles it. Wrapping
      # this in `I()` to force an array would break publication.
      resource_entry$schema$primaryKey <- primary_key
    }

    resource_list[[length(resource_list) + 1]] <- resource_entry
  }

  metadata_resource_list <- .ms_sdp_metadata_resource_entries(include_codes = !is.null(codes))
  resource_list <- c(metadata_resource_list, resource_list)
  sdp_schema <- .ms_load_sdp_schema(quiet = TRUE)

  declared_spec_version <- dataset_meta$spec_version[1]
  if (!is.na(declared_spec_version) && nzchar(trimws(declared_spec_version)) &&
      !identical(trimws(declared_spec_version), sdp_schema$version)) {
    cli::cli_warn(c(
      "{.file dataset.csv} declares {.val {declared_spec_version}} but the loaded SDP schema is {.val {sdp_schema$version}}.",
      "i" = "The package will carry both values. Clear {.field spec_version} to adopt the loaded schema version."
    ))
  }

  # Every URI written here comes from the one loaded, self-consistent bundle,
  # so the descriptor can never declare a profile the bundle disagrees with.
  datapackage <- list(
    profile = sdp_schema$profile_uri,
    name = .ms_datapackage_name(dataset_id),
    id = dataset_id,
    title = dataset_meta$title[1],
    description = dataset_meta$description[1],
    sdp = list(
      specVersion = sdp_schema$version,
      profile = sdp_schema$profile_uri,
      rules = sdp_schema$rules_uri,
      metadata = list(
        dataset = "metadata/dataset.csv",
        tables = "metadata/tables.csv",
        columnDictionary = "metadata/column_dictionary.csv",
        codes = if (!is.null(codes)) "metadata/codes.csv" else NULL
      )
    ),
    resources = resource_list
  )

  # Every presence test below goes through `.ms_meta_scalar_present()`, never a
  # bare `!= ""`: `readr::read_csv()` type-guesses `temporal_start` as a Date
  # (it holds the ISO date this package wrote), and a Date-vs-"" comparison is
  # NA -- which aborted this function after the unlink and destroyed the
  # package on disk (backlog #96). The sibling fields are guarded the same way
  # because they fail the same way the moment a caller hands them a typed
  # column.
  if (.ms_meta_scalar_present(dataset_meta$creator)) {
    datapackage$contributors <- list(list(
      title = dataset_meta$creator[1],
      role = "creator"
    ))
  }
  if (.ms_meta_scalar_present(dataset_meta$contact_name)) {
    contact <- list(
      title = dataset_meta$contact_name[1],
      role = "contact"
    )
    if (.ms_meta_scalar_present(dataset_meta$contact_email)) {
      contact$email <- dataset_meta$contact_email[1]
    }
    if (.ms_meta_scalar_present(dataset_meta$contact_org)) {
      contact$organization <- dataset_meta$contact_org[1]
    }
    datapackage$contributors <- c(datapackage$contributors %||% list(), list(contact))
  }
  license_value <- dataset_meta$license[1]
  if (.ms_meta_scalar_present(license_value) && !.ms_is_review_placeholder(license_value)) {
    datapackage$licenses <- list(.ms_license_descriptor(license_value))
  }
  if (.ms_meta_scalar_present(dataset_meta$temporal_start)) {
    # `.ms_iso_character()` renders a typed value as the ISO text the CSV side
    # writes (identity for character), so the descriptor and
    # `metadata/dataset.csv` cannot disagree about the same field.
    datapackage$temporal <- list(start = .ms_iso_character(dataset_meta$temporal_start[1]))
    if (.ms_meta_scalar_present(dataset_meta$temporal_end)) {
      datapackage$temporal$end <- .ms_iso_character(dataset_meta$temporal_end[1])
    }
  }

  # Render canonical SDP metadata after any file_name defaults were resolved.
  writes[[.ms_metadata_path(path, "dataset.csv")]] <- .ms_sdp_extension_csv_bytes(dataset_meta)
  writes[[.ms_metadata_path(path, "tables.csv")]] <- .ms_sdp_extension_csv_bytes(table_meta)
  writes[[.ms_metadata_path(path, "column_dictionary.csv")]] <- .ms_sdp_extension_csv_bytes(dict)
  if (!is.null(codes)) {
    writes[[.ms_metadata_path(path, "codes.csv")]] <- .ms_sdp_extension_csv_bytes(codes)
  }

  if (isTRUE(write_datapackage)) {
    writes[[file.path(path, "datapackage.json")]] <- .ms_datapackage_json_bytes(datapackage)
  }
  writes[[.ms_package_sentinel_file(path)]] <- .ms_package_ownership_bytes()

  # The single destructive step: everything above this line is pure
  # computation over the caller's inputs, everything below it is filesystem
  # installation of already-final bytes.
  .ms_commit_package_write(
    path,
    writes,
    managed_paths = managed_paths,
    prune = prune
  )

  if (!isTRUE(prune) && length(orphaned) > 0) {
    cli::cli_alert_info(
      "Removed data resource{?s} no longer declared in {.file tables.csv}: {.file {orphaned}}"
    )
  }

  cli::cli_alert_success("Created Salmon Data Package at {.path {path}}")
  invisible(path)
}

# Presence test for a single descriptor metadata field that must tolerate
# typed columns. `x != ""` looks safe and is not: comparing a Date with ""
# coerces "" to `NA_Date_` (so the test is NA and `if` aborts), and comparing a
# POSIXct with "" throws outright. Backlog #96 -- the abort landed after
# `write_salmon_datapackage()` had unlinked the managed paths and before it
# wrote any replacement, so it destroyed the package on disk, triggered by
# nothing more exotic than `readr::read_csv()` type-guessing the ISO date this
# package itself wrote into `metadata/dataset.csv`. Render to character first
# so every column type answers the same question.
.ms_meta_scalar_present <- function(x) {
  value <- x[1]
  if (length(value) == 0 || is.na(value)) {
    return(FALSE)
  }
  nzchar(trimws(as.character(value)))
}

.ms_package_sentinel_file <- function(path) {
  file.path(path, ".metasalmon-package")
}

# Byte-identical to the `writeLines("metasalmon-owned", ..., useBytes = TRUE)`
# call that wrote the sentinel before the write path became transactional.
.ms_package_ownership_bytes <- function() {
  charToRaw("metasalmon-owned\n")
}

# Render the descriptor with the exact writer -- and therefore the exact bytes
# -- `write_salmon_datapackage()` has always used; the file itself is
# installed later by `.ms_commit_package_write()`. Deliberately NOT
# `.ms_sdp_extension_json_bytes()`: that helper goes through `toJSON()` with
# `na = "null"`, `digits = NA` and a trailing newline, none of which
# `write_json()` emits, and changing the descriptor's bytes is an observable
# behaviour change this fix must not smuggle in.
.ms_datapackage_json_bytes <- function(datapackage) {
  temporary <- tempfile(fileext = ".json")
  on.exit(unlink(temporary), add = TRUE)
  jsonlite::write_json(
    datapackage,
    temporary,
    pretty = TRUE,
    auto_unbox = TRUE,
    null = "null"
  )
  readBin(temporary, what = "raw", n = file.info(temporary)$size)
}

# Remove a create-owned output before recreating it. The containment check
# catches symbolic links, but `Sys.readlink()` does not see HARD links, and
# writing through one truncates the shared inode outside the package. The
# pre-0.2.0 full-directory wipe unlinked these entries first; preserving the
# directory removed that protection, so it has to be explicit -- and it belongs
# next to each write, not in one caller, so it holds however the writer is
# reached.
.ms_replace_create_output <- function(path) {
  if (file.exists(path)) {
    unlink(path, force = TRUE)
  }
  invisible(path)
}

.ms_dir_entries <- function(path) {
  list.files(path, all.files = TRUE, no.. = TRUE, full.names = TRUE)
}

# Every path `write_salmon_datapackage()` is authoritative for on this call,
# whether or not this call will actually write it. Anything absent from this
# list survives a rewrite: reviewed SSSOM mappings, ordered measurement
# decompositions, EML/EDH XML, `eml-mapping.yml`, review notes, `publication/`.
#
# Deliberately NOT `.ms_knb_sdp_artifact_paths()`: that helper answers "what
# gets published", aborts when a reviewed sidecar is absent, and is documented
# as the single source of truth for the KNB inventory. This one answers "what
# this call owns", and must degrade rather than abort.
.ms_package_managed_paths <- function(path, data_file_names = character()) {
  metadata_names <- c("dataset.csv", "tables.csv", "column_dictionary.csv", "codes.csv")

  managed <- c(
    file.path(path, "datapackage.json"),
    .ms_metadata_path(path, metadata_names),
    # Legacy root-level shadows, which `.ms_locate_metadata_file()` still accepts.
    file.path(path, metadata_names),
    .ms_package_sentinel_file(path)
  )

  data_file_names <- data_file_names[!is.na(data_file_names) & nzchar(data_file_names)]
  previous <- .ms_previous_declared_data_paths(path)
  all_data <- unique(c(data_file_names, previous))
  if (length(all_data) > 0) {
    managed <- c(managed, file.path(path, all_data))
  }

  unique(managed)
}

# Windows accepts `\` as a path separator, so the trailing-`.`, trailing-`..`,
# and containment checks below must see it as one -- otherwise `C:\pkg-link\.`
# is a single opaque component and walks straight past them.
#
# Gated on the platform on purpose: a backslash is a legal character in a POSIX
# filename, and rewriting it there would split one directory name into two
# components.
#
# This does not make the symbolic-link check itself work on Windows.
# `Sys.readlink()` is documented to return "" for every path on platforms
# without the `readlink` system call, so that check is inert there and Windows
# junctions are invisible to it. The `..` and containment checks are what these
# normalizations restore.
.ms_path_separators_to_slash <- function(x) {
  if (identical(.Platform$OS.type, "windows")) {
    gsub("\\", "/", x, fixed = TRUE)
  } else {
    x
  }
}

# A directory path whose final component is a real name, so `Sys.readlink()`
# inspects the directory itself. Trailing `/` and `/.` spellings are the ones
# that matter: `Sys.readlink("link/.")` reads the `.` entry inside the resolved
# target and returns "", so a symlinked root spelled `pkg-link/.` was accepted.
#
# Deliberately not `normalizePath()`: that resolves the final component too, so
# a symlinked root would come back as its target and pass the check it exists
# to fail.
.ms_lexical_dir <- function(path) {
  root <- .ms_path_separators_to_slash(path)
  repeat {
    # Keep at least one character, so "/" and "." survive as themselves.
    stripped <- sub("(?<=.)/+$", "", root, perl = TRUE)
    stripped <- sub("(?<=.)/+\\.$", "", stripped, perl = TRUE)
    if (identical(stripped, root)) {
      return(root)
    }
    root <- stripped
  }
}

# A trailing `..` is the one spelling no lexical check can make safe. readlink(2)
# resolves every component but the last, so `a/../link` correctly inspects
# `link` -- but `link/..` resolves `link` as an intermediate component and then
# reads `..` inside the target, which is a directory, so the check sees nothing.
# The root then denotes the *target's parent*, which can be an unrelated
# package. Collapsing `..` lexically instead would be wrong precisely when an
# earlier component is a symlink, and resolving it would follow the link this
# check exists to reject. Refusing the spelling is the only sound option, and it
# costs the user nothing: `a/../b` and every other `..` position still works.
.ms_root_ends_in_parent_ref <- function(root) {
  parts <- strsplit(.ms_path_separators_to_slash(root), "/", fixed = TRUE)[[1]]
  parts <- parts[nzchar(parts) & parts != "."]
  length(parts) > 0L && identical(parts[[length(parts)]], "..")
}

# Refuse to delete through a symbolic link. `file.exists()` follows links, so a
# `data/` or `metadata/` replaced by a symlink would make every managed child
# resolve outside the package and `unlink()` delete the target. The KNB archive
# already fails closed on symlinked path components
# (`.ms_knb_sdp_archive_assert_no_symlink()`); the writer must do the same
# before it removes anything.
.ms_assert_managed_path_contained <- function(path, managed_paths) {
  root <- .ms_lexical_dir(path)

  # The root itself, before any child: the per-component walk below starts at
  # `path` and so never inspects it, which let a symlinked package root through
  # with every child appearing contained. `prune = TRUE` would then empty the
  # link's target. Only `path` is checked, never its ancestors -- on macOS
  # `/tmp` is a link to `/private/tmp`, so walking ancestors would reject every
  # ordinary tempdir write.
  if (.ms_root_ends_in_parent_ref(root)) {
    cli::cli_abort(c(
      "Refusing to update {.path {path}}: the package root ends in {.code ..}.",
      "i" = "Which directory that names depends on whether an earlier component is a symbolic link.",
      "i" = "Write to the directory itself instead."
    ))
  }
  root_link <- Sys.readlink(root)
  if (length(root_link) == 1L && !is.na(root_link) && nzchar(root_link)) {
    cli::cli_abort(c(
      "Refusing to update {.path {path}}: the package root is a symbolic link.",
      "i" = "Write to the directory the link points at, or replace the link with a real directory."
    ))
  }

  # Both sides are compared with separators normalised: `path` may be spelled
  # with `\\` while `managed_paths` are built by `file.path()`, which always
  # joins with `/`. Comparing the raw strings made every candidate fail the
  # prefix test and silently skip the check -- failing open, which is the worst
  # outcome for a guard.
  prefix <- paste0(root, "/")

  for (candidate in managed_paths) {
    normalized <- .ms_path_separators_to_slash(candidate)
    relative <- if (startsWith(normalized, prefix)) {
      substring(normalized, nchar(prefix) + 1L)
    } else {
      next
    }
    current <- root
    parts <- strsplit(relative, "/", fixed = TRUE)[[1]]
    # `.` and empty parts come from the caller's spelling, not from a real
    # directory entry; walking them would readlink the resolved target instead
    # of the component.
    for (part in parts[nzchar(parts) & parts != "."]) {
      current <- file.path(current, part)
      link <- Sys.readlink(current)
      if (length(link) == 1L && !is.na(link) && nzchar(link)) {
        cli::cli_abort(c(
          "Refusing to update {.path {path}}: {.file {relative}} contains a symbolic-link path component.",
          "i" = "Replace the link with a real directory or file, or write to a new directory."
        ))
      }
      if (!file.exists(current)) {
        break
      }
    }
  }

  invisible(managed_paths)
}

# Data resources declared by a previous write. Retaining an orphan would leave
# undeclared data in `data/` that validation never looks at but a hand-made ZIP
# would carry. Degrades to nothing if the previous tables.csv is absent or
# unreadable — a corrupt file must never widen the deletion set.
.ms_previous_declared_data_paths <- function(path) {
  tables_path <- tryCatch(.ms_locate_metadata_file(path, "tables.csv"), error = function(e) NA_character_)
  if (length(tables_path) != 1L || is.na(tables_path) || !file.exists(tables_path)) {
    return(character())
  }

  tryCatch(
    {
      previous <- .ms_read_metadata_csv(tables_path)
      if (!"file_name" %in% names(previous)) {
        return(character())
      }
      names <- trimws(as.character(previous$file_name))
      names <- names[!is.na(names) & nzchar(names)]
      if (length(names) == 0L) {
        return(character())
      }
      # Normalize (which rejects `..` and absolute paths) but do NOT force into
      # `data/`: a previous write may legitimately have declared `exports/x.csv`.
      # Relocating it would leave the real orphan behind and delete an unrelated
      # `data/x.csv` that this write does not own.
      vapply(
        names,
        function(n) .ms_normalize_resource_file_name(n),
        character(1),
        USE.NAMES = FALSE
      )
    },
    error = function(e) character()
  )
}

.ms_is_metasalmon_package_dir <- function(path) {
  if (!dir.exists(path)) {
    return(FALSE)
  }

  if (file.exists(.ms_package_sentinel_file(path))) {
    return(TRUE)
  }

  has_sdp_csvs <- all(file.exists(c(
    .ms_metadata_path(path, "dataset.csv"),
    .ms_metadata_path(path, "tables.csv"),
    .ms_metadata_path(path, "column_dictionary.csv")
  )))
  if (has_sdp_csvs) {
    return(TRUE)
  }

  file.exists(file.path(path, "datapackage.json")) &&
    dir.exists(file.path(path, "data")) &&
    dir.exists(.ms_metadata_dir(path))
}

# Non-destructive preflight for a package write: create a missing directory,
# and refuse the calls that must not proceed (missing `overwrite`, `prune`
# without `overwrite`, a non-metasalmon target). Deliberately performs NO
# deletion -- that is `.ms_commit_package_write()`'s job, and only after the
# entire write set has been rendered. Keeping deletion out of this function is
# the fix for backlog #96's second half: its predecessor
# (`.ms_prepare_package_write_dir()`) unlinked the managed paths here, before
# the descriptor build and metadata rendering, so every abort in between
# destroyed the caller's package.
#
# GUARD ORDER IS THE BEHAVIOUR. An existing directory with nothing in it is
# not a reason to abort: `overwrite` exists to authorize destroying something,
# and an empty directory has nothing to destroy. Demanding it there trains
# callers to pass `overwrite = TRUE` habitually for the ordinary
# `dir.create()`-then-write shape, which is the flag's whole value gone.
# So the emptiness test runs BEFORE the `overwrite` gate, not after it.
#
# "Empty" means `.ms_dir_entries()` returns nothing -- `list.files(all.files =
# TRUE, no.. = TRUE)`, so a dot-file, a stale `.metasalmon-package` sentinel,
# or an empty `data/` subdirectory each make the directory NON-empty and the
# `overwrite` gate applies as before. Only a directory with literally zero
# entries is written into. That is deliberately the strictest reading: every
# one of those three is evidence that something already used this path, and
# the guard should not have to judge which of them is safe to walk over.
#
# This is the metasalmonpy order, adopted here on Brett's Q15 ruling
# (2026-08-24, "Go with the python implementation") -- `parity-deviations.md`
# row 54, which the ruling retires. The two implementations already computed
# the identical notion of "empty" (`list(target.iterdir())` is the same
# predicate); only its POSITION relative to the `overwrite` gate differed,
# silently, since before the 0.1.6 parity claim. Pinned on both sides now:
# `test-package-helpers.R` "an existing EMPTY directory is written into
# without overwrite" and metasalmonpy's
# `test_writer_writes_into_an_existing_empty_directory_without_overwrite`.
.ms_check_package_write_dir <- function(path,
                                        overwrite = FALSE,
                                        prune = FALSE) {
  if (isTRUE(prune) && !isTRUE(overwrite)) {
    cli::cli_abort("{.arg prune} requires {.arg overwrite = TRUE}.")
  }

  if (!dir.exists(path)) {
    dir.create(path, recursive = TRUE, showWarnings = FALSE)
    return(invisible(path))
  }

  existing_files <- .ms_dir_entries(path)
  if (length(existing_files) == 0) {
    return(invisible(path))
  }

  if (!isTRUE(overwrite)) {
    cli::cli_abort(
      "Directory {.path {path}} already exists. Set {.code overwrite = TRUE} to replace."
    )
  }

  if (!.ms_is_metasalmon_package_dir(path)) {
    cli::cli_abort(c(
      "Refusing to overwrite non-metasalmon directory {.path {path}}.",
      "i" = "Use a new/empty directory, or manually clean this directory first."
    ))
  }

  invisible(path)
}

# The single destructive step of a package write. `writes` is the complete,
# already-rendered write set (raw vectors keyed by absolute target path), so
# nothing user-input-dependent can abort past this point.
#
# Non-prune: install through `.ms_sdp_extension_atomic_write_set()` -- each
# replacement is fully staged as a same-directory sibling before any current
# file moves, every replaced file is renamed aside first, and a failure
# mid-install restores the originals -- then unlink the managed paths this
# call did not rewrite (orphaned data resources, legacy root-level metadata
# shadows, a stale codes.csv). An abort anywhere leaves the previous package
# intact.
#
# Prune wipes files this writer does not own, which is exactly what makes the
# rollback guarantee unavailable there: the wiped sidecars are not in the
# write set, so nothing exists to restore them from. The wipe therefore runs
# as late as possible -- after every input-dependent computation and the full
# byte rendering have succeeded -- and the residual window is pure filesystem
# failure (disk full, permissions revoked) between the wipe and the install.
# That difference is deliberate: `prune = TRUE` is an explicit request to
# delete everything this call does not write.
.ms_commit_package_write <- function(path,
                                     writes,
                                     managed_paths = character(),
                                     prune = FALSE) {
  # Containment before anything destructive: refuse to delete or replace
  # through a symbolic link. The same guard the pre-#96 unlink ran, now also
  # covering the prune wipe (which previously relied on the writer's earlier
  # metadata-subset check alone).
  .ms_assert_managed_path_contained(path, managed_paths)

  if (isTRUE(prune)) {
    unlink(.ms_dir_entries(path), recursive = TRUE, force = TRUE)
  }

  for (target_dir in unique(dirname(names(writes)))) {
    dir.create(target_dir, recursive = TRUE, showWarnings = FALSE)
  }

  .ms_sdp_extension_atomic_write_set(writes)

  if (!isTRUE(prune)) {
    stale <- setdiff(managed_paths, names(writes))
    stale <- stale[file.exists(stale)]
    # No `recursive =`: if a managed path ever resolves to a directory, unlink()
    # is a no-op rather than a recursive wipe.
    unlink(stale, force = TRUE)
  }

  invisible(path)
}

#' Infer Salmon Data Package artifacts from resource tables
#'
#' Infers column dictionaries, table metadata, candidate code lists, and
#' dataset-level metadata in a single step from one or more raw data tables.
#'
#' This is a convenience helper for biologists who want to get from raw
#' data frames to package-ready metadata artifacts with one call.
#'
#' @param resources Either a named list of data frames (one per resource table)
#'   or a single data frame (converted internally to a one-table list).
#' @param dataset_id Dataset identifier applied to all inferred metadata.
#' @param table_id Name used when `resources` is a single data frame.
#' @param guess_types Logical; if `TRUE` (default), infer `value_type` for each
#'   dictionary column.
#' @param seed_semantics Logical; if `TRUE`, run
#'   `suggest_semantics()` and attach semantic suggestions to the returned
#'   dictionary.
#' @param semantic_sources Vector of vocabulary sources passed to
#'   `suggest_semantics()`. When omitted, role-aware defaults are used. When
#'   supplied explicitly, the vector is a strict allowlist for initial and
#'   retry retrieval.
#' @param semantic_max_per_role Maximum number of suggestions retained per I-ADOPT
#'   role.
#' @param seed_verbose Logical; if TRUE, emit progress messages while seeding
#'   semantic suggestions.
#' @param seed_codes Optional `codes.csv`-style seed metadata.
#' @param seed_table_meta Optional `tables.csv`-style seed metadata. Use
#'   `TRUE` (default) to infer starter table metadata from `resources`.
#' @param seed_dataset_meta Optional `dataset.csv`-style seed metadata. Use
#'   `TRUE` (default) to infer starter dataset metadata from `resources`.
#' @param semantic_code_scope Character string controlling which `codes.csv`
#'   rows are sent through `suggest_semantics()` during one-shot seeding.
#'   `"factor"` (default) analyzes codes sourced from factor columns and
#'   low-cardinality character columns in the original data frame(s); `"all"`
#'   analyzes all inferred or supplied code rows; `"none"` skips code-level
#'   semantic suggestions.
#' @param llm_assess Logical; if `TRUE`, run the optional LLM shortlist
#'   assessment inside `suggest_semantics()`. Measurement columns are reviewed
#'   as six-slot bundles; other targets keep their existing per-target path.
#' @param llm_provider LLM provider preset forwarded to `suggest_semantics()`.
#' @param llm_model Optional LLM model identifier forwarded to
#'   `suggest_semantics()`.
#' @param llm_api_key Optional API key override forwarded to
#'   `suggest_semantics()`.
#' @param llm_base_url Optional OpenAI-compatible base URL forwarded to
#'   `suggest_semantics()`.
#' @param llm_reasoning_effort Optional reasoning-effort hint forwarded to
#'   `suggest_semantics()` when using the OpenAI provider.
#' @param llm_top_n Maximum number of retrieved candidates sent to the LLM per
#'   target.
#' @param llm_context_files Optional character vector of local context file
#'   paths forwarded to `suggest_semantics()` when `llm_assess = TRUE`. Pass
#'   file paths, not parsed data frames, XML documents, or R Markdown objects.
#'   See `suggest_semantics()` for supported file types, including HTML, DOCX,
#'   `.R`, `.Rmd`, `.qmd`, PDF, and Excel context files.
#' @param llm_context_text Optional inline context snippets forwarded to
#'   `suggest_semantics()`.
#' @param llm_timeout_seconds Timeout for each LLM request in seconds.
#' @param llm_request_fn Advanced/test hook overriding the low-level
#'   OpenAI-compatible request function.
#'
#' @return A named list with the following components:
#'   - `resources`: Named list of input tables
#'   - `dict`: Inferred dictionary tibble
#'   - `table_meta`: Inferred table metadata tibble
#'   - `codes`: Inferred candidate codes tibble
#'   - `dataset_meta`: Inferred dataset metadata one-row tibble
#'   - `semantic_suggestions`: Semantic suggestion tibble (or `NULL`)
#'   - `semantic_llm_assessments`: Target-level LLM review summary tibble (or `NULL`)
#' @export
#'
#' @examples
#' \dontrun{
#' resources <- list(
#'   catches = data.frame(
#'     station_id = c("A", "B"),
#'     species = c("Coho", "Chinook"),
#'     count = c(10L, 20L),
#'     sample_date = as.Date(c("2024-01-01", "2024-01-02"))
#'   ),
#'   stations = data.frame(
#'     station_id = c("A", "B"),
#'     latitude = c(49.8, 49.9),
#'     longitude = c(-124.4, -124.5)
#'   )
#' )
#'
#' artifacts <- infer_salmon_datapackage_artifacts(
#'   resources,
#'   dataset_id = "demo-1",
#'   seed_semantics = TRUE,
#'   seed_verbose = TRUE
#' )
#'
#' dict <- artifacts$dict
#' table_meta <- artifacts$table_meta
#' codes <- artifacts$codes
#' dataset_meta <- artifacts$dataset_meta
#' }
infer_salmon_datapackage_artifacts <- function(
    resources,
    dataset_id = "dataset-1",
    table_id = "table_1",
    guess_types = TRUE,
    seed_semantics = TRUE,
    semantic_sources = c("smn", "gcdfo", "ols", "nvs"),
    semantic_max_per_role = 1,
    seed_verbose = TRUE,
    seed_codes = NULL,
    seed_table_meta = TRUE,
    seed_dataset_meta = TRUE,
    semantic_code_scope = c("factor", "all", "none"),
    llm_assess = FALSE,
    llm_provider = c("openai", "openrouter", "openai_compatible", "chapi"),
    llm_model = NULL,
    llm_api_key = NULL,
    llm_base_url = NULL,
    llm_reasoning_effort = NULL,
    llm_top_n = 5L,
    llm_context_files = NULL,
    llm_context_text = NULL,
    llm_timeout_seconds = 60,
    llm_request_fn = NULL
) {
  semantic_sources <- .ms_forward_semantic_sources(
    semantic_sources,
    omitted = missing(semantic_sources)
  )
  llm_review <- .ms_llm_review_plan(
    seed_semantics = seed_semantics,
    semantic_max_per_role = semantic_max_per_role,
    llm_assess = llm_assess,
    llm_provider = llm_provider,
    llm_model = llm_model,
    llm_api_key = llm_api_key,
    llm_base_url = llm_base_url,
    llm_reasoning_effort = llm_reasoning_effort,
    llm_top_n = llm_top_n,
    llm_context_files = llm_context_files,
    llm_context_text = llm_context_text,
    llm_timeout_seconds = llm_timeout_seconds,
    llm_request_fn = llm_request_fn
  )

  if (inherits(resources, "data.frame")) {
    resources <- list(resources)
    names(resources) <- table_id
  }

  if (!is.list(resources) || is.null(names(resources)) || any(!nzchar(names(resources)))) {
    cli::cli_abort("{.arg resources} must be a data frame or a named list of data frames")
  }
  if (anyDuplicated(names(resources)) > 0) {
    cli::cli_abort("{.arg resources} names must be unique")
  }
  if (length(resources) == 0) {
    cli::cli_abort("{.arg resources} cannot be empty")
  }

  bad_rows <- which(vapply(resources, function(x) !inherits(x, "data.frame"), logical(1L)))
  if (length(bad_rows) > 0) {
    cli::cli_abort("All entries in {.arg resources} must be data frames. Invalid entries at: {.val {bad_rows}}")
  }

  dict <- .ms_infer_resource_dictionary(
    resources = resources,
    guess_types = guess_types,
    dataset_id = dataset_id,
    semantic_sources = semantic_sources,
    semantic_max_per_role = semantic_max_per_role,
    seed_verbose = seed_verbose
  )

  artifact_context <- .ms_infer_resource_artifact_context(
    resources = resources,
    dataset_id = dataset_id,
    seed_codes = seed_codes,
    seed_table_meta = seed_table_meta,
    seed_dataset_meta = seed_dataset_meta,
    mode = "package",
    dict = dict,
    semantic_code_scope = semantic_code_scope
  )
  table_meta <- artifact_context$table_meta
  codes <- artifact_context$codes
  dataset_meta <- artifact_context$dataset_meta
  semantic_codes <- artifact_context$semantic_codes

  semantic_suggestions <- NULL
  semantic_llm_assessments <- NULL
  if (isTRUE(seed_semantics)) {
    if (seed_verbose) {
      cli::cli_alert_info("Seeding semantic suggestions during infer_salmon_datapackage_artifacts().")
    }

    suggest_args <- list(
      df = resources,
      dict = dict,
      sources = semantic_sources,
      max_per_role = llm_review$semantic_max_per_role,
      include_dwc = FALSE,
      codes = semantic_codes,
      table_meta = table_meta,
      dataset_meta = dataset_meta
    )
    suggest_args <- c(suggest_args, llm_review$suggest_args)
    dict <- do.call(suggest_semantics, suggest_args)

    semantic_suggestions <- attr(dict, "semantic_suggestions", exact = TRUE)
    semantic_llm_assessments <- attr(dict, "semantic_llm_assessments", exact = TRUE)
  }

  dict <- .ms_fill_review_placeholders_dictionary(dict)
  table_meta <- .ms_fill_review_placeholders_table_meta(table_meta)
  dataset_meta <- .ms_fill_review_placeholders_dataset_meta(dataset_meta)

  list(
    resources = resources,
    dataset_id = dataset_id,
    dict = dict,
    table_meta = table_meta,
    codes = codes,
    dataset_meta = dataset_meta,
    semantic_suggestions = semantic_suggestions,
    semantic_llm_assessments = semantic_llm_assessments
  )
}

#' Create a Salmon Data Package directly from raw tables
#'
#' Primary one-shot wrapper: infer dictionary/table metadata/codes/dataset
#' metadata from raw data tables and immediately write a review-ready Salmon
#' Data Package.
#'
#' @param resources Either a named list of data frames (one per resource table)
#'   or a single data frame (converted internally to a one-table list).
#' @param path Character; directory path where package will be written. If
#'   omitted, defaults to `file.path(getwd(), paste0(<dataset_id>-sdp))` using
#'   a filesystem-safe dataset id slug.
#' @param dataset_id Dataset identifier applied to all inferred metadata rows.
#' @param table_id Fallback table identifier when `resources` is a single data frame.
#' @param guess_types Logical; if `TRUE` (default), infer `value_type` for each
#'   dictionary column.
#' @param seed_semantics Logical; if `TRUE` (default), seed semantic suggestions
#'   during inference.
#' @param semantic_sources Vector of vocabulary sources passed to
#'   `suggest_semantics()`. When omitted, role-aware defaults are used. When
#'   supplied explicitly, the vector is a strict allowlist for initial and
#'   retry retrieval.
#' @param semantic_max_per_role Maximum number of suggestions retained per
#'   I-ADOPT role.
#' @param seed_verbose Logical; if TRUE, emit progress messages while seeding
#'   semantic suggestions.
#' @param seed_codes Optional `codes.csv`-style seed metadata.
#' @param seed_table_meta Optional `tables.csv`-style seed metadata. Use
#'   `TRUE` (default) to infer starter table metadata from `resources`.
#' @param seed_dataset_meta Optional `dataset.csv`-style seed metadata. Use
#'   `TRUE` (default) to infer starter dataset metadata from `resources`.
#' @param semantic_code_scope Character string controlling which `codes.csv`
#'   rows are sent through `suggest_semantics()` during one-shot seeding.
#'   `"factor"` (default) analyzes codes sourced from factor columns and
#'   low-cardinality character columns in the original data frame(s); `"all"`
#'   analyzes all inferred or supplied code rows; `"none"` skips code-level
#'   semantic suggestions.
#' @param llm_assess Logical; if `TRUE`, run the optional LLM shortlist
#'   assessment inside `suggest_semantics()`. Measurement columns are reviewed
#'   as six-slot bundles; other targets keep their existing per-target path.
#' @param llm_provider LLM provider preset forwarded to `suggest_semantics()`.
#' @param llm_model Optional LLM model identifier forwarded to
#'   `suggest_semantics()`.
#' @param llm_api_key Optional API key override forwarded to
#'   `suggest_semantics()`.
#' @param llm_base_url Optional OpenAI-compatible base URL forwarded to
#'   `suggest_semantics()`.
#' @param llm_reasoning_effort Optional reasoning-effort hint forwarded to
#'   `suggest_semantics()` when using the OpenAI provider.
#' @param llm_top_n Maximum number of retrieved candidates sent to the LLM per
#'   target.
#' @param llm_context_files Optional character vector of local context file
#'   paths forwarded to `suggest_semantics()` when `llm_assess = TRUE`. Pass
#'   file paths, not parsed data frames, XML documents, or R Markdown objects.
#'   See `suggest_semantics()` for supported file types, including HTML, DOCX,
#'   `.R`, `.Rmd`, `.qmd`, PDF, and Excel context files.
#' @param llm_context_text Optional inline context snippets forwarded to
#'   `suggest_semantics()`.
#' @param llm_timeout_seconds Timeout for each LLM request in seconds.
#' @param llm_request_fn Advanced/test hook overriding the low-level
#'   OpenAI-compatible request function.
#' @param check_updates Logical; if `TRUE`, run a short, non-fatal
#'   [check_for_updates()] call after writing the package and mention newer
#'   releases only when one is available. Defaults to `interactive()`.
#' @param format Character; resource format: `"csv"` (default, only format supported)
#' @param overwrite Logical; if `FALSE` (default), errors when `path` is a
#'   directory that already holds something. An existing but *completely empty*
#'   directory is written into without `overwrite` — there is nothing there to
#'   destroy — while a dot-file, a stale `.metasalmon-package` sentinel, or an
#'   empty `data/` subdirectory all count as content and still require it. If
#'   `TRUE`, the package is updated in place — see `prune`. Replacement is only
#'   allowed for directories previously written by `metasalmon`.
#' @param prune Logical; if `FALSE` (default), reviewed sidecars in an existing
#'   package directory are preserved and only files this writer owns are
#'   replaced. If `TRUE`, the directory is emptied first. Requires
#'   `overwrite = TRUE`. See [write_salmon_datapackage()].
#' @param include_edh_xml Logical; when `TRUE`, writes an HNAP-aware EDH XML
#'   metadata file to `metadata/metadata-edh-hnap.xml` using
#'   `edh_build_hnap_xml()`. The default is `FALSE`. Because `create_sdp()`
#'   produces review-ready metadata, this create-time XML is treated as a
#'   **draft**: if `REVIEW:`/`MISSING` markers remain it is still written but a
#'   warning recommends rebuilding a clean file with `write_edh_xml_from_sdp()`
#'   after the metadata is finalized.
#' @param ... Deprecated legacy EDH arguments accepted for backwards
#'   compatibility: `edh_profile`, `EDH_Profile`, and `EDH_profile` all enable
#'   EDH XML export and must be `"dfo_edh_hnap"` when supplied.
#'   `edh_xml_path` is ignored with a warning because XML now always writes to
#'   the default metadata path. Any other extra arguments error.
#'
#' @return Invisibly returns the package path.
#'
#' @details This one-shot helper creates a review-ready package by default:
#' semantic suggestions are seeded and the top-ranked column-level suggestions
#' are auto-applied only into missing dictionary IRI fields. Table-level
#' observation-unit suggestions stay enabled, and `create_sdp()` can
#' auto-apply them into missing `tables.csv$observation_unit_iri` values when
#' the suggestion still looks lexically compatible with the available table
#' context (prefer `observation_unit`/`description`, otherwise fall back to
#' `table_label`/`table_id`); compatible suggestions can also backfill
#' `tables.csv$observation_unit` labels when missing. To reduce review
#' noise conservatively, code-level suggestions default to factor and
#' low-cardinality character source columns only; set
#' `semantic_code_scope = "all"` to broaden that or `"none"` to disable it.
#' The package root contains `README-review.txt`,
#' `semantic_suggestions.csv` (when available), `datapackage.json`,
#' `metadata/`, and `data/`. Review the prefilled values already written into
#' `metadata/tables.csv` and `metadata/column_dictionary.csv` first; use
#' `semantic_suggestions.csv` as a fallback shortlist when you want more
#' context or a better match. To keep that review file usable,
#' `semantic_suggestions.csv` trims code-level suggestions that do not have
#' enough human-readable context to review safely. When `llm_assess = TRUE`,
#' the same review file also carries `llm_*` columns so the bundled LLM
#' judgments, retry rejections, escalation origins, and validator downgrades
#' stay explicit and reviewable. Only accepted variable, property, entity, and
#' unit selections are eligible for column auto-prefill; constraint and method
#' assessments always remain manual. Any auto-applied column/table IRI
#' draft is written back into the metadata CSVs as a `REVIEW:`-prefixed value
#' for manual confirmation there. Required-field review placeholders are also
#' inserted into the inferred metadata files. In
#' interactive use, `create_sdp()` can also mention an available package update;
#' set `check_updates = FALSE` to skip that network check. The package bundles
#' two Fraser coho examples: `nuseds-fraser-coho-sample.csv` (30 rows across
#' 1996-2024) for the quickest demo, and `nuseds-fraser-coho-2023-2024.csv`
#' (173 rows from the official Open Government Canada Fraser and BC Interior
#' workbook) for a fuller multi-year example. The bundled
#' `system.file("extdata", "example-data-README.md", package = "metasalmon")`
#' note points to the upstream record/resource URLs, licensing, and the
#' repository `data-raw/` script used to derive the fuller example.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' data_path <- system.file("extdata", "nuseds-fraser-coho-sample.csv", package = "metasalmon")
#' fraser_coho <- readr::read_csv(data_path, show_col_types = FALSE)
#'
#' pkg <- create_sdp(
#'   fraser_coho,
#'   dataset_id = "fraser-coho-2024",
#'   table_id = "escapement",
#'   overwrite = FALSE
#' )
#' }
create_sdp <- function(
    resources,
    path = NULL,
    dataset_id = "dataset-1",
    table_id = "table_1",
    guess_types = TRUE,
    seed_semantics = TRUE,
    semantic_sources = c("smn", "gcdfo", "ols", "nvs"),
    semantic_max_per_role = 1,
    seed_verbose = TRUE,
    seed_codes = NULL,
    seed_table_meta = TRUE,
    seed_dataset_meta = TRUE,
    semantic_code_scope = c("factor", "all", "none"),
    llm_assess = FALSE,
    llm_provider = c("openai", "openrouter", "openai_compatible", "chapi"),
    llm_model = NULL,
    llm_api_key = NULL,
    llm_base_url = NULL,
    llm_reasoning_effort = NULL,
    llm_top_n = 5L,
    llm_context_files = NULL,
    llm_context_text = NULL,
    llm_timeout_seconds = 60,
    llm_request_fn = NULL,
    check_updates = interactive(),
    format = "csv",
    overwrite = FALSE,
    include_edh_xml = FALSE,
    prune = FALSE,
    ...
) {
  semantic_sources <- .ms_forward_semantic_sources(
    semantic_sources,
    omitted = missing(semantic_sources)
  )
  dots <- list(...)
  dot_names <- names(dots)
  if (is.null(dot_names)) {
    dot_names <- rep("", length(dots))
  }

  legacy_profile_names <- intersect(c("edh_profile", "EDH_Profile", "EDH_profile"), dot_names)
  legacy_path_names <- intersect("edh_xml_path", dot_names)
  legacy_requested_xml <- FALSE

  if (length(legacy_profile_names) > 1L) {
    cli::cli_abort(
      "Use only one legacy EDH profile argument; choose {.code edh_profile}, {.code EDH_Profile}, or {.code EDH_profile}."
    )
  }

  if (length(legacy_profile_names) == 1L) {
    legacy_name <- legacy_profile_names[[1]]
    legacy_value <- dots[[legacy_name]]
    legacy_value_chr <- trimws(as.character(legacy_value[[1]]))

    if (length(legacy_value) != 1L || is.na(legacy_value_chr) || !nzchar(legacy_value_chr)) {
      cli::cli_abort(
        "Legacy argument {.code {legacy_name}} must be a single non-empty string."
      )
    }
    if (!identical(legacy_value_chr, "dfo_edh_hnap")) {
      cli::cli_abort(
        "Only {.code \"dfo_edh_hnap\"} is supported for legacy argument {.code {legacy_name}}."
      )
    }

    legacy_requested_xml <- TRUE
    cli::cli_warn(c(
      "Argument {.code {legacy_name}} is deprecated.",
      "i" = "Use {.code include_edh_xml = TRUE}; the DFO EDH HNAP XML is now the only supported export."
    ))
  }

  if (length(legacy_path_names) > 0L) {
    legacy_requested_xml <- TRUE
    cli::cli_warn(c(
      "Argument {.code edh_xml_path} is deprecated and ignored.",
      "i" = "EDH XML now always writes to {.file metadata/metadata-edh-hnap.xml}."
    ))
  }

  unused_named <- setdiff(
    dot_names[nzchar(dot_names)],
    c("edh_profile", "EDH_Profile", "EDH_profile", "edh_xml_path")
  )
  unnamed_count <- sum(!nzchar(dot_names))
  if (length(unused_named) > 0L || unnamed_count > 0L) {
    pieces <- c(unused_named, rep("<unnamed>", unnamed_count))
    cli::cli_abort(
      "Unused argument{?s}: {.code {pieces}}"
    )
  }

  if (!isTRUE(include_edh_xml) && legacy_requested_xml) {
    include_edh_xml <- TRUE
    cli::cli_inform(c(
      "Assuming {.code include_edh_xml = TRUE} because a legacy EDH argument was supplied.",
      "i" = "EDH XML now always writes {.file metadata/metadata-edh-hnap.xml} using the DFO EDH HNAP profile."
    ))
  }

  if (is.null(path) || !nzchar(trimws(path))) {
    path <- file.path(getwd(), paste0(.ms_safe_path_slug(dataset_id), "-sdp"))
  }

  # `create_sdp()`'s own copy of the write-directory gate, deliberately kept
  # rather than deferred to `.ms_check_package_write_dir()`: this one runs
  # BEFORE inference, so a doomed call never reaches `suggest_semantics()` and
  # never spends an LLM request or a network round trip on output it will
  # refuse to write. `test-package-helpers.R` "create_sdp requires
  # overwrite=TRUE to write into an existing directory" pins that by asserting
  # the mocked `suggest_semantics()` was called zero times.
  #
  # The emptiness test has to be repeated here for the same reason the gate is
  # (parity-deviations row 54, Brett's Q15 ruling): without it, this early copy
  # would abort on an empty directory that the writer would happily accept, and
  # the coarser guard would silently win. Same definition of "empty" as
  # `.ms_check_package_write_dir()` -- `.ms_dir_entries()`, dot-files included.
  # metasalmonpy has no early guard at all here and reaches the same decision
  # at write time; that difference is parity-deviations row 60.
  if (!isTRUE(overwrite) && dir.exists(path) && length(.ms_dir_entries(path)) > 0L) {
    cli::cli_abort(
      "Directory {.path {path}} already exists. Set {.code overwrite = TRUE} to replace."
    )
  }

  semantic_code_scope <- match.arg(semantic_code_scope)

  seed_note <- .ms_create_sdp_seed_note(
    seed_semantics = seed_semantics,
    seed_verbose = seed_verbose,
    semantic_code_scope = semantic_code_scope
  )
  if (!is.null(seed_note)) {
    cli::cli_alert_info(seed_note)
  }

  artifacts <- infer_salmon_datapackage_artifacts(
    resources = resources,
    dataset_id = dataset_id,
    table_id = table_id,
    guess_types = guess_types,
    seed_semantics = seed_semantics,
    semantic_sources = semantic_sources,
    semantic_max_per_role = semantic_max_per_role,
    seed_verbose = seed_verbose,
    seed_codes = seed_codes,
    seed_table_meta = seed_table_meta,
    seed_dataset_meta = seed_dataset_meta,
    semantic_code_scope = semantic_code_scope,
    llm_assess = llm_assess,
    llm_provider = llm_provider,
    llm_model = llm_model,
    llm_api_key = llm_api_key,
    llm_base_url = llm_base_url,
    llm_reasoning_effort = llm_reasoning_effort,
    llm_top_n = llm_top_n,
    llm_context_files = llm_context_files,
    llm_context_text = llm_context_text,
    llm_timeout_seconds = llm_timeout_seconds,
    llm_request_fn = llm_request_fn
  )

  suggestions <- artifacts$semantic_suggestions
  if (is.null(suggestions)) {
    suggestions <- attr(artifacts$dict, "semantic_suggestions", exact = TRUE)
  }
  if (!is.null(suggestions) && nrow(suggestions) > 0) {
    if (isTRUE(llm_assess) && "llm_selected" %in% names(suggestions)) {
      auto_apply_suggestions <- .ms_prepare_llm_auto_apply_suggestions(artifacts$dict, suggestions)
      apply_strategy <- "llm"
      min_llm_confidence <- NULL
    } else {
      auto_apply_suggestions <- .ms_filter_auto_apply_suggestions(artifacts$dict, suggestions)
      apply_strategy <- "top"
      min_llm_confidence <- NULL
    }
    dict_before_apply <- artifacts$dict
    artifacts$dict <- apply_semantic_suggestions(
      artifacts$dict,
      suggestions = auto_apply_suggestions,
      strategy = apply_strategy,
      min_llm_confidence = min_llm_confidence,
      overwrite = FALSE,
      verbose = FALSE
    )
    artifacts$dict <- .ms_mark_reviewed_dictionary_iris(
      artifacts$dict,
      dict_before_apply,
      auto_apply_suggestions,
      strategy = apply_strategy
    )
    artifacts$table_meta <- .ms_apply_table_semantic_suggestions(
      artifacts$table_meta,
      suggestions = suggestions,
      strategy = apply_strategy,
      min_llm_confidence = min_llm_confidence,
      overwrite = FALSE,
      mark_review = TRUE
    )
  }

  pkg_path <- local({
    old_validation_message_mode <- getOption("metasalmon.validation_message_mode")
    old_validation_semantics_seeded <- getOption("metasalmon.validation_semantics_seeded")
    on.exit({
      options(metasalmon.validation_message_mode = old_validation_message_mode)
      options(metasalmon.validation_semantics_seeded = old_validation_semantics_seeded)
    }, add = TRUE)

    options(
      metasalmon.validation_message_mode = "review_ready",
      metasalmon.validation_semantics_seeded = isTRUE(seed_semantics)
    )

    write_salmon_datapackage(
      resources = artifacts$resources,
      dataset_meta = artifacts$dataset_meta,
      table_meta = artifacts$table_meta,
      dict = artifacts$dict,
      codes = artifacts$codes,
      path = path,
      format = format,
      overwrite = overwrite,
      prune = prune
    )
  })

  # `create_sdp()` writes these itself, after the generic writer has run, so they
  # are deliberately absent from `managed_paths` (that is what preserves them on
  # a rewrite). They still need the same containment check: without it a
  # symlinked `README-review.txt` is followed and an external file is truncated.
  .ms_assert_managed_path_contained(
    pkg_path,
    file.path(pkg_path, c(
      "README-review.txt",
      "semantic_suggestions.csv",
      file.path("metadata", "metadata-edh-hnap.xml")
    ))
  )

  review_suggestions <- .ms_prepare_review_suggestions(suggestions)
  .ms_write_sdp_review_readme(
    pkg_path = pkg_path,
    dataset_id = dataset_id,
    has_suggestions = !is.null(review_suggestions) && nrow(review_suggestions) > 0,
    has_codes = is.data.frame(artifacts$codes) && nrow(artifacts$codes) > 0,
    has_review_prefill = any(vapply(
      list(artifacts$dict, artifacts$table_meta),
      function(x) {
        if (!is.data.frame(x)) {
          return(FALSE)
        }
        iri_cols <- grep("_iri$", names(x), value = TRUE)
        if (length(iri_cols) == 0) {
          return(FALSE)
        }
        any(vapply(
          x[iri_cols],
          function(col) any(grepl("^\\s*REVIEW\\s*:", as.character(col), ignore.case = TRUE), na.rm = TRUE),
          logical(1)
        ))
      },
      logical(1)
    ))
  )

  # `create_sdp()` owns this file, so it clears its own stale copy. The generic
  # writer's managed-path inventory deliberately does not know about it.
  suggestions_path <- file.path(pkg_path, "semantic_suggestions.csv")
  if (!is.null(review_suggestions) && nrow(review_suggestions) > 0) {
    .ms_replace_create_output(suggestions_path)
    readr::write_csv(review_suggestions, suggestions_path, na = "")
  } else if (file.exists(suggestions_path)) {
    unlink(suggestions_path, force = TRUE)
  }

  if (isTRUE(include_edh_xml)) {
    edh_xml_path <- .ms_metadata_path(pkg_path, "metadata-edh-hnap.xml")
    .ms_replace_create_output(edh_xml_path)

    edh_build_hnap_xml(
      artifacts$dataset_meta,
      output_path = edh_xml_path
    )

    # create_sdp() emits review-ready metadata, so this create-time XML is often
    # built from dataset/table metadata that still holds REVIEW:/MISSING markers.
    # write_edh_xml_from_sdp() refuses to rebuild from such packages; flag the
    # create-time output as a DRAFT (reusing the same review-state detection) so a
    # user does not ship it believing it cleared the rebuild guard.
    edh_review_issues <- .ms_collect_edh_review_state_issues(list(
      dataset = artifacts$dataset_meta,
      tables = artifacts$table_meta,
      dictionary = artifacts$dict,
      codes = artifacts$codes
    ))
    if (nrow(edh_review_issues) > 0) {
      cli::cli_warn(c(
        "Wrote a DRAFT EDH metadata XML at {.path {edh_xml_path}}.",
        "i" = "It was built from review-ready metadata that still contains {.val REVIEW:} IRIs or {.val MISSING} placeholders.",
        "i" = "Finalize the metadata CSVs, then rebuild a clean XML with {.code write_edh_xml_from_sdp()}."
      ))
    } else {
      cli::cli_alert_success("Wrote EDH metadata XML at {.path {edh_xml_path}}")
    }
  }

  review_targets <- if (!is.null(review_suggestions) && nrow(review_suggestions) > 0) {
    "Open {.file README-review.txt}, then review {.file metadata/column_dictionary.csv} and {.file metadata/tables.csv} in Excel first. Use {.file semantic_suggestions.csv} only if you want more context or a better match."
  } else {
    "Open {.file README-review.txt}, then review {.file metadata/column_dictionary.csv} and {.file metadata/tables.csv} in Excel."
  }
  update_note <- .ms_create_sdp_update_note(check_updates = check_updates)

  info_lines <- c(
    "Created review-ready one-shot package with {.fn create_sdp}.",
    "i" = "Prefilled semantic values were written directly into the metadata CSVs only where target fields were blank. Compatible table observation-unit drafts can be auto-applied using observation-unit/description first and otherwise table label/id fallback. Any {.val REVIEW:} entries already live in the metadata CSVs and must be confirmed or edited there.",
    "i" = review_targets,
    "i" = "Next: replace placeholders, remove any {.val REVIEW:} markers once final, rebuild EDH XML if needed, then run {.code validate_salmon_datapackage(pkg_path, require_iris = TRUE)}."
  )
  if (!is.null(update_note)) {
    info_lines <- c(info_lines, "i" = update_note)
  }

  cli::cli_inform(info_lines)

  invisible(pkg_path)
}

#' Read a Salmon Data Package
#'
#' Loads a Salmon Data Package from disk. When canonical SDP CSV metadata files
#' are present, those are treated as the source of truth. If they are missing,
#' the function falls back to reconstructing metadata from `datapackage.json`
#' for backwards compatibility with older `metasalmon` outputs.
#'
#' @param path Character; path to directory containing Salmon Data Package files
#'
#' @return A list with components:
#'   - `dataset`: Dataset metadata tibble
#'   - `tables`: Table metadata tibble
#'   - `dictionary`: Dictionary tibble
#'   - `codes`: Codes tibble (if available)
#'   - `resources`: Named list of data tibbles
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # Read a package
#' pkg <- read_salmon_datapackage("path/to/package")
#' pkg$resources$main_table
#' }
read_salmon_datapackage <- function(path) {
  if (!dir.exists(path)) {
    cli::cli_abort("Directory {.path {path}} does not exist")
  }

  dataset_path <- .ms_locate_metadata_file(path, "dataset.csv")
  tables_path <- .ms_locate_metadata_file(path, "tables.csv")
  dict_path <- .ms_locate_metadata_file(path, "column_dictionary.csv")
  codes_path <- .ms_locate_metadata_file(path, "codes.csv")
  json_path <- file.path(path, "datapackage.json")

  has_canonical <- all(!is.na(c(dataset_path, tables_path, dict_path)))

  if (has_canonical) {
    dataset_meta <- .ms_read_metadata_csv(dataset_path)
    table_meta <- .ms_read_metadata_csv(tables_path)
    dictionary <- .ms_read_metadata_csv(dict_path)
    dictionary <- .ms_normalize_dictionary(dictionary)
    if ("required" %in% names(dictionary)) {
      dictionary$required <- .ms_parse_logical(dictionary$required)
    }
  } else {
    if (!file.exists(json_path)) {
      cli::cli_abort(
        "No Salmon Data Package metadata found in {.path {path}} (expected canonical CSV metadata or {.file datapackage.json})."
      )
    }

    datapackage <- jsonlite::read_json(json_path, simplifyVector = FALSE)

    package_id <- datapackage$id %||% datapackage$name %||% NA_character_
    package_license <- datapackage$license %||% NA_character_
    if (!is.null(datapackage$licenses) && length(datapackage$licenses) > 0) {
      package_license <- datapackage$licenses[[1]]$name %||%
        datapackage$licenses[[1]]$title %||%
        datapackage$licenses[[1]]$path %||%
        package_license
    }
    provenance <- .ms_descriptor_provenance(datapackage)

    dataset_meta <- tibble::tibble(
      dataset_id = package_id,
      title = if (is.null(datapackage$title)) NA_character_ else datapackage$title,
      description = if (is.null(datapackage$description)) NA_character_ else datapackage$description,
      creator = provenance$creator %||% datapackage$creator %||% NA_character_,
      contact_name = provenance$contact_name %||% NA_character_,
      contact_email = provenance$contact_email %||% NA_character_,
      license = package_license,
      temporal_start = if (is.null(datapackage$temporal) || is.null(datapackage$temporal$start)) NA_character_ else datapackage$temporal$start,
      temporal_end = if (is.null(datapackage$temporal) || is.null(datapackage$temporal$end)) NA_character_ else datapackage$temporal$end
    )
    dataset_meta <- .ms_normalize_dataset_meta(dataset_meta)

    table_meta_rows <- list()
    dict_rows <- list()

    resources_json <- purrr::keep(datapackage$resources %||% list(), function(resource) {
      resource_path <- resource$path %||% ""
      !startsWith(resource_path, "metadata/")
    })
    for (resource in resources_json) {
      resource_name <- resource$name
      file_name <- resource$path %||% NA_character_

      table_meta_rows[[length(table_meta_rows) + 1]] <- list(
        dataset_id = package_id,
        table_id = resource_name,
        file_name = file_name,
        table_label = resource$title %||% resource_name,
        description = resource$description %||% NA_character_,
        observation_unit = NA_character_,
        observation_unit_iri = NA_character_,
        primary_key = if (!is.null(resource$schema$primaryKey)) paste(unlist(resource$schema$primaryKey), collapse = ",") else NA_character_
      )

      if (!is.null(resource$schema) && !is.null(resource$schema$fields)) {
        for (field in resource$schema$fields) {
          required <- NA
          if (!is.null(field$constraints) && !is.null(field$constraints$required)) {
            required <- isTRUE(field$constraints$required)
          }
          custom <- field$custom %||% list()

          dict_rows[[length(dict_rows) + 1]] <- list(
            dataset_id = package_id,
            table_id = resource_name,
            column_name = field$name %||% NA_character_,
            column_label = field$title %||% field$name %||% NA_character_,
            column_description = field$description %||% NA_character_,
            column_role = custom[["sdp:columnRole"]] %||% field$column_role %||% NA_character_,
            value_type = field$type %||% "string",
            unit_label = custom[["sdp:unitLabel"]] %||% field$unit_label %||% NA_character_,
            unit_iri = custom[["sdp:unitIri"]] %||% field$unit_iri %||% NA_character_,
            term_iri = custom[["sdp:termIri"]] %||% field$term_iri %||% NA_character_,
            term_type = custom[["sdp:termType"]] %||% field$term_type %||% NA_character_,
            required = required,
            property_iri = custom[["iAdopt:propertyIri"]] %||% field$property_iri %||% NA_character_,
            entity_iri = custom[["iAdopt:entityIri"]] %||% field$entity_iri %||% NA_character_,
            constraint_iri = custom[["iAdopt:constraintIri"]] %||% field$constraint_iri %||% NA_character_,
            # The legacy iAdopt:methodIri key is deliberately NOT read here:
            # migrate_sdp_methods() reads old descriptors directly, so a
            # descriptor-only sdp-0.2.0 package keeps its method binding
            # until migration relocates it to tables.csv.
            statistical_modifier_iri = custom[["iAdopt:statisticalModifierIri"]] %||% field$statistical_modifier_iri %||% NA_character_
          )
        }
      }
    }

    table_meta <- dplyr::bind_rows(table_meta_rows)
    table_meta <- .ms_normalize_table_meta(table_meta)
    dictionary <- dplyr::bind_rows(dict_rows)
    dictionary <- .ms_normalize_dictionary(dictionary)
    if ("required" %in% names(dictionary)) {
      dictionary$required <- .ms_parse_logical(dictionary$required)
    }
  }

  codes <- NULL
  if (!is.na(codes_path) && file.exists(codes_path)) {
    codes <- .ms_read_metadata_csv(codes_path)
    codes <- .ms_normalize_codes(codes)
  }

  resources <- list()
  if (nrow(table_meta) > 0) {
    for (i in seq_len(nrow(table_meta))) {
      resource_name <- table_meta$table_id[i]
      file_name <- table_meta$file_name[i]
      if (is.na(file_name) || file_name == "") {
        next
      }

      file_path <- file.path(path, file_name)
      if (!file.exists(file_path)) {
        cli::cli_warn("Resource file {.path {file_path}} not found, skipping")
        next
      }

      table_dict <- dictionary[dictionary$table_id == resource_name, , drop = FALSE]
      resources[[resource_name]] <- .ms_read_resource_csv(file_path, table_dict)
    }
  }

  result <- list(
    dataset = dataset_meta,
    tables = table_meta,
    dictionary = dictionary,
    codes = codes,
    resources = resources
  )

  cli::cli_alert_success("Loaded Salmon Data Package from {.path {path}}")
  result
}

.ms_collect_review_iri_issues <- function(df, source_name) {
  if (!is.data.frame(df) || nrow(df) == 0) {
    return(tibble::tibble())
  }

  iri_cols <- grep("_iri$", names(df), value = TRUE)
  if (length(iri_cols) == 0) {
    return(tibble::tibble())
  }

  issues <- purrr::map_dfr(iri_cols, function(field) {
    vals <- as.character(df[[field]])
    rows <- which(!is.na(vals) & grepl("^\\s*REVIEW\\s*:", vals, ignore.case = TRUE))
    if (length(rows) == 0) {
      return(tibble::tibble())
    }
    tibble::tibble(
      message = sprintf(
        "%s row %s field %s still contains a REVIEW-prefixed IRI (%s). Remove the REVIEW prefix only after final manual validation.",
        source_name,
        rows,
        field,
        vals[rows]
      )
    )
  })

  issues
}

.ms_validation_row_context <- function(df, row, id_fields = character()) {
  id_fields <- intersect(id_fields, names(df))
  if (length(id_fields) == 0) {
    return(sprintf("row %s", row))
  }

  bits <- vapply(id_fields, function(field) {
    value <- .ms_scalar_text(df[[field]][[row]])
    if (!nzchar(value)) {
      return("")
    }
    sprintf("%s=%s", field, value)
  }, character(1))
  bits <- bits[nzchar(bits)]

  if (length(bits) == 0) {
    return(sprintf("row %s", row))
  }

  sprintf("row %s (%s)", row, paste(bits, collapse = ", "))
}

.ms_collect_review_placeholder_issues <- function(df, source_name, id_fields = character()) {
  if (!is.data.frame(df) || nrow(df) == 0) {
    return(tibble::tibble())
  }

  fields <- names(df)
  if (length(fields) == 0) {
    return(tibble::tibble())
  }

  purrr::map_dfr(fields, function(field) {
    vals <- as.character(df[[field]])
    rows <- which(!is.na(vals) & vapply(vals, .ms_is_review_placeholder, logical(1)))
    if (length(rows) == 0) {
      return(tibble::tibble())
    }

    tibble::tibble(
      message = vapply(rows, function(row) {
        sprintf(
          "%s %s field %s still contains an unresolved review placeholder (%s). Replace it before final validation.",
          source_name,
          .ms_validation_row_context(df, row, id_fields = id_fields),
          field,
          vals[[row]]
        )
      }, character(1))
    )
  })
}

.ms_collect_missing_table_observation_unit_iri_issues <- function(table_meta, source_name = "metadata/tables.csv") {
  if (!is.data.frame(table_meta) || nrow(table_meta) == 0 || !"observation_unit_iri" %in% names(table_meta)) {
    return(tibble::tibble())
  }

  vals <- as.character(table_meta$observation_unit_iri)
  rows <- which(is.na(vals) | !nzchar(trimws(vals)))
  if (length(rows) == 0) {
    return(tibble::tibble())
  }

  tibble::tibble(
    message = vapply(rows, function(row) {
      sprintf(
        "%s %s field observation_unit_iri is blank. Final validation requires a resolved table observation-unit IRI.",
        source_name,
        .ms_validation_row_context(table_meta, row, id_fields = c("table_id", "file_name"))
      )
    }, character(1))
  )
}

# sdp-0.3.0 moved methods and protocols onto tables.csv and dataset.csv, so
# those fields need the same absolute-IRI check the dictionary's IRI columns
# get. Without it a table could claim `methods/weir-count` and validate
# cleanly: the base schema accepts any string, and the observation-structure
# validator that does check IRI shape only runs when the optional structure
# sidecars exist.
.ms_collect_placement_iri_issues <- function(meta, source_name, id_fields,
                                             fields = c("method_iri", "protocol_iri")) {
  if (!is.data.frame(meta) || nrow(meta) == 0) {
    return(tibble::tibble())
  }
  present <- intersect(fields, names(meta))
  if (length(present) == 0) {
    return(tibble::tibble())
  }

  messages <- character()
  for (field in present) {
    vals <- as.character(meta[[field]])
    populated <- !is.na(vals) & nzchar(trimws(vals))
    # `REVIEW:` markers have their own dedicated reporting path.
    invalid <- which(
      populated &
        !grepl("^REVIEW:", trimws(vals), ignore.case = TRUE) &
        !.ms_sdp_extension_is_absolute_iri(vals)
    )
    for (row in invalid) {
      messages <- c(messages, sprintf(
        "%s %s field %s is not an absolute IRI: '%s'.",
        source_name,
        .ms_validation_row_context(meta, row, id_fields = id_fields),
        field,
        trimws(vals[[row]])
      ))
    }
  }
  if (length(messages) == 0) {
    return(tibble::tibble())
  }
  tibble::tibble(message = messages)
}

#' Validate a Salmon Data Package end to end
#'
#' Reads a package from disk, checks that metadata/data files stay aligned,
#' verifies coded values against `codes.csv` when present, and then runs
#' [validate_dictionary()] plus [validate_semantics()]. This is the quickest
#' pre-flight check before sharing a package-first submission.
#'
#' @param path Character; directory containing the Salmon Data Package.
#' @param require_iris Logical; if `TRUE`, require non-empty semantic IRIs for
#'   measurement fields (`term_iri`, `property_iri`, `entity_iri`, and
#'   `unit_iri`).
#'
#' @return Invisibly returns a list with components:
#'   - `package`: loaded package list from [read_salmon_datapackage()].
#'   - `semantic_validation`: result from [validate_semantics()].
#'   - `issues`: package-structure issue tibble (empty when validation passes).
#' @export
#'
#' @examples
#' \donttest{
#' # `path` is explicit: without it `create_sdp()` writes `<dataset_id>-sdp/`
#' # into the working directory, which an example must never do.
#' pkg_path <- create_sdp(
#'   mtcars,
#'   path = file.path(tempdir(), "demo-1-sdp"),
#'   dataset_id = "demo-1",
#'   table_id = "counts",
#'   overwrite = TRUE
#' )
#' validate_salmon_datapackage(pkg_path, require_iris = FALSE)
#' }
validate_salmon_datapackage <- function(path, require_iris = FALSE) {
  pkg <- read_salmon_datapackage(path)

  .ms_validate_dataset_id_alignment(
    pkg$dataset,
    pkg$tables,
    pkg$dictionary,
    pkg$codes
  )

  issues <- .ms_collect_package_validation_issues(pkg, path = path, require_iris = require_iris)
  if (nrow(issues) > 0) {
    .ms_abort_package_validation_issues(issues)
  }

  # SDP procedure and observation-structure resources are optional. Their
  # absence preserves the historic validation path; when present, validate the
  # canonical files and their data-level bindings before semantic checks.
  .ms_validate_optional_sdp_observation_metadata(path)

  final_review_issues <- if (isTRUE(require_iris)) {
    dplyr::bind_rows(
      .ms_collect_review_placeholder_issues(pkg$dataset, "metadata/dataset.csv", id_fields = "dataset_id"),
      .ms_collect_review_placeholder_issues(pkg$tables, "metadata/tables.csv", id_fields = c("table_id", "file_name")),
      .ms_collect_missing_table_observation_unit_iri_issues(pkg$tables),
      .ms_collect_review_placeholder_issues(pkg$dictionary, "metadata/column_dictionary.csv", id_fields = c("table_id", "column_name")),
      .ms_collect_review_placeholder_issues(pkg$codes, "metadata/codes.csv", id_fields = c("table_id", "column_name", "code_value"))
    )
  } else {
    tibble::tibble()
  }

  dict <- validate_dictionary(pkg$dictionary, require_iris = require_iris)
  semantic_validation <- validate_semantics(dict, require_iris = require_iris)
  table_review_issues <- .ms_collect_review_iri_issues(pkg$tables, source_name = "metadata/tables.csv")
  if (nrow(table_review_issues) > 0) {
    semantic_validation$issues <- dplyr::bind_rows(semantic_validation$issues, table_review_issues)
  }
  # Unconditional: a method or protocol placement that is not an absolute IRI
  # is malformed in every validation mode, not only under `require_iris`.
  placement_issues <- dplyr::bind_rows(
    .ms_collect_placement_iri_issues(
      pkg$tables,
      source_name = "metadata/tables.csv",
      id_fields = c("table_id", "file_name")
    ),
    .ms_collect_placement_iri_issues(
      pkg$dataset,
      source_name = "metadata/dataset.csv",
      id_fields = "dataset_id",
      fields = "protocol_iri"
    )
  )
  if (nrow(placement_issues) > 0) {
    semantic_validation$issues <- dplyr::bind_rows(semantic_validation$issues, placement_issues)
  }

  if (isTRUE(require_iris)) {
    # A malformed placement IRI is worse than an unreviewed one: strict
    # validation must block it, exactly as it blocks a REVIEW: marker.
    final_review_issues <- dplyr::bind_rows(
      final_review_issues,
      table_review_issues,
      placement_issues
    )
  }

  if (isTRUE(require_iris) && nrow(final_review_issues) > 0) {
    preview <- utils::head(unique(final_review_issues$message), 10)
    abort_lines <- c(
      sprintf(
        "Final validation failed with %d unresolved review issue%s.",
        nrow(final_review_issues),
        ifelse(nrow(final_review_issues) == 1, "", "s")
      ),
      .ms_cli_bullets(preview, "x"),
      "i" = "Resolve placeholder metadata, blank table observation-unit IRIs, and any REVIEW-prefixed IRIs before strict validation."
    )
    if (nrow(final_review_issues) > length(preview)) {
      abort_lines <- c(
        abort_lines,
        "i" = sprintf(
          "%d more unresolved review issue%s not shown.",
          nrow(final_review_issues) - length(preview),
          ifelse(nrow(final_review_issues) - length(preview) == 1, "", "s")
        )
      )
    }
    cli::cli_abort(abort_lines)
  }

  if (nrow(semantic_validation$issues) > 0) {
    preview <- utils::head(unique(semantic_validation$issues$message), 3)
    warn_lines <- c(
      sprintf(
        "Package structure is valid, but validate_semantics() reported %d semantic issue%s.",
        nrow(semantic_validation$issues),
        ifelse(nrow(semantic_validation$issues) == 1, "", "s")
      ),
      paste0("- ", .ms_cli_escape(preview))
    )
    if (nrow(semantic_validation$issues) > length(preview)) {
      warn_lines <- c(
        warn_lines,
        sprintf(
          "%d more semantic issue%s returned in the result.",
          nrow(semantic_validation$issues) - length(preview),
          ifelse(nrow(semantic_validation$issues) - length(preview) == 1, "", "s")
        )
      )
    }
    cli::cli_warn(paste(warn_lines, collapse = "\n"))
  }

  cli::cli_alert_success("Salmon Data Package validation passed")
  invisible(list(
    package = pkg,
    semantic_validation = semantic_validation,
    issues = issues
  ))
}

.ms_dataset_meta_cols <- function() {
  .ms_sdp_schema_field_names("dataset")
}

.ms_table_meta_cols <- function() {
  .ms_sdp_schema_field_names("tables")
}

.ms_dictionary_cols <- function() {
  .ms_sdp_schema_field_names("column_dictionary")
}

.ms_codes_cols <- function() {
  .ms_sdp_schema_field_names("codes")
}

.ms_align_cols <- function(df, cols) {
  if (is.null(df)) {
    return(NULL)
  }

  df <- tibble::as_tibble(df)
  # SDP metadata frames are text contracts. A caller-supplied Date column
  # otherwise reaches readr::write_csv() -- whose as.character.Date rendering
  # drops the year padding below 1000 -- and the EML calendarDate renderer
  # intact; the on-disk path was safe only because .ms_read_metadata_csv()
  # pins col_character (backlog #93 item 2). Date ONLY, by measurement:
  # readr's POSIXct output is already correct and coercing it would change
  # bytes. See .ms_iso_date_columns().
  df <- .ms_iso_date_columns(df)
  missing_cols <- setdiff(cols, names(df))
  for (col in missing_cols) {
    df[[col]] <- NA_character_
  }

  ordered_cols <- c(cols, setdiff(names(df), cols))
  df[, ordered_cols, drop = FALSE]
}

.ms_normalize_dataset_meta <- function(dataset_meta) {
  .ms_align_cols(dataset_meta, .ms_dataset_meta_cols())
}

.ms_normalize_table_meta <- function(table_meta) {
  .ms_align_cols(table_meta, .ms_table_meta_cols())
}

.ms_normalize_dictionary <- function(dict) {
  dict <- .ms_align_cols(dict, .ms_dictionary_cols())
  if (!"required" %in% names(dict)) {
    dict$required <- NA
  }
  dict
}

.ms_normalize_codes <- function(codes) {
  if (is.null(codes)) {
    return(NULL)
  }
  .ms_align_cols(codes, .ms_codes_cols())
}

# Shared engine for the legacy NuSEDS code-term prefills. A codes.csv row gets
# its term_iri filled from `crosswalk` when (a) its column's name -- or its
# dictionary name/label/description -- contains every word in
# `required_words`, (b) the row has no explicit term_iri, and (c) the code
# value has a crosswalk row with a non-missing ontology term. Explicit values
# always win; crosswalk rows that map to NA (recorded non-mappings, e.g.
# "NO SURVEY THIS YEAR") never fill anything.
.ms_prefill_legacy_code_terms <- function(codes, dict, required_words, crosswalk) {
  codes <- .ms_normalize_codes(codes)
  if (is.null(codes) || nrow(codes) == 0) {
    return(codes)
  }

  normalize_text <- function(x) {
    out <- trimws(as.character(x))
    out[is.na(out) | !nzchar(out)] <- NA_character_
    tolower(out)
  }
  expand_gcdfo_term <- function(x) {
    out <- trimws(as.character(x))
    out[is.na(out) | !nzchar(out)] <- NA_character_
    is_curie <- !is.na(out) & grepl("^gcdfo:", out)
    out[is_curie] <- sub("^gcdfo:", "https://w3id.org/gcdfo/salmon#", out[is_curie])
    out
  }
  column_flag <- function(column_name, column_label = NULL, column_description = NULL) {
    column_name <- if (is.null(column_name)) "" else dplyr::coalesce(as.character(column_name), "")
    column_label <- if (is.null(column_label)) rep("", length(column_name)) else dplyr::coalesce(as.character(column_label), "")
    column_description <- if (is.null(column_description)) rep("", length(column_name)) else dplyr::coalesce(as.character(column_description), "")
    text <- normalize_text(gsub("[^[:alnum:]]+", " ", paste(column_name, column_label, column_description)))
    flags <- !is.na(text)
    for (word in required_words) {
      flags <- flags & grepl(paste0("\\b", word, "\\b"), text, perl = TRUE)
    }
    flags
  }

  target_rows <- column_flag(codes$column_name)
  if (!is.null(dict) && nrow(dict) > 0) {
    dict <- .ms_normalize_dictionary(dict)
    dict_flags <- column_flag(dict$column_name, dict$column_label, dict$column_description)
    dict_keys <- paste(
      dplyr::coalesce(as.character(dict$dataset_id), ""),
      dplyr::coalesce(as.character(dict$table_id), ""),
      dplyr::coalesce(as.character(dict$column_name), ""),
      sep = "\r"
    )
    flag_lookup <- stats::setNames(dict_flags, dict_keys)
    code_keys <- paste(
      dplyr::coalesce(as.character(codes$dataset_id), ""),
      dplyr::coalesce(as.character(codes$table_id), ""),
      dplyr::coalesce(as.character(codes$column_name), ""),
      sep = "\r"
    )
    lookup_flags <- unname(flag_lookup[code_keys])
    lookup_flags[is.na(lookup_flags)] <- FALSE
    target_rows <- target_rows | lookup_flags
  }

  crosswalk_lookup <- stats::setNames(
    expand_gcdfo_term(crosswalk$ontology_term),
    normalize_text(crosswalk$nuseds_value)
  )
  mapped_terms <- unname(crosswalk_lookup[normalize_text(codes$code_value)])
  existing_terms <- trimws(as.character(codes$term_iri))
  missing_terms <- is.na(existing_terms) | !nzchar(existing_terms)
  fill_rows <- target_rows & missing_terms & !is.na(mapped_terms) & nzchar(mapped_terms)

  if (any(fill_rows)) {
    codes$term_iri[fill_rows] <- mapped_terms[fill_rows]
  }

  codes
}

.ms_prefill_legacy_estimate_method_code_terms <- function(codes, dict = NULL) {
  .ms_prefill_legacy_code_terms(
    codes,
    dict,
    required_words = c("estimate", "method"),
    crosswalk = nuseds_estimate_method_crosswalk()
  )
}

.ms_prefill_legacy_estimate_classification_code_terms <- function(codes, dict = NULL) {
  .ms_prefill_legacy_code_terms(
    codes,
    dict,
    required_words = c("estimate", "classification"),
    crosswalk = nuseds_estimate_classification_crosswalk()
  )
}

# "enumeration" alone, not c("enumeration", "method"): NuSEDS names the column
# ENUMERATION_METHODS (plural), and the engine's \bword\b test would never
# match "methods" with the singular. The single word is specific enough --
# crosswalk keys ("Fence", "Bank Walk", ...) gate what actually fills.
.ms_prefill_legacy_enumeration_method_code_terms <- function(codes, dict = NULL) {
  .ms_prefill_legacy_code_terms(
    codes,
    dict,
    required_words = "enumeration",
    crosswalk = nuseds_enumeration_method_crosswalk()
  )
}

.ms_parse_logical <- function(x) {
  if (is.logical(x)) {
    return(x)
  }

  values <- trimws(as.character(x))
  out <- rep(NA, length(values))
  out[toupper(values) == "TRUE"] <- TRUE
  out[toupper(values) == "FALSE"] <- FALSE
  as.logical(out)
}

.ms_dictionary_from_input <- function(dict, normalize = TRUE) {
  if (inherits(dict, "data.frame")) {
    dict <- tibble::as_tibble(dict)
    if (isTRUE(normalize)) {
      dict <- .ms_normalize_dictionary(dict)
      if ("required" %in% names(dict)) {
        dict$required <- .ms_parse_logical(dict$required)
      }
    }
    return(dict)
  }

  if (is.character(dict) && length(dict) == 1 && !is.na(dict) && nzchar(trimws(dict))) {
    dict_path <- trimws(dict)

    if (dir.exists(dict_path)) {
      located <- .ms_locate_metadata_file(dict_path, "column_dictionary.csv")
      if (is.na(located)) {
        cli::cli_abort(
          "Directory {.path {dict_path}} does not contain {.file column_dictionary.csv}."
        )
      }
      dict_path <- located
    } else if (!file.exists(dict_path)) {
      cli::cli_abort(
        "{.arg dict} must be a data frame, package directory, or path to {.file column_dictionary.csv}."
      )
    }

    dict <- .ms_read_metadata_csv(dict_path)
    if (isTRUE(normalize)) {
      dict <- .ms_normalize_dictionary(dict)
      if ("required" %in% names(dict)) {
        dict$required <- .ms_parse_logical(dict$required)
      }
    }
    return(dict)
  }

  cli::cli_abort(
    "{.arg dict} must be a data frame, package directory, or path to {.file column_dictionary.csv}."
  )
}

.ms_validate_dataset_id_alignment <- function(dataset_meta, table_meta, dict, codes = NULL) {
  dataset_id <- dataset_meta$dataset_id[1]

  check_ids <- function(values, source_name) {
    values <- unique(values[!is.na(values) & values != ""])
    if (length(values) == 0) {
      return(invisible(NULL))
    }
    if (!all(values == dataset_id)) {
      cli::cli_abort(
        "{.arg {source_name}} contains dataset_id values that do not match {.field dataset_meta$dataset_id}."
      )
    }
    invisible(NULL)
  }

  check_ids(table_meta$dataset_id, "table_meta")
  check_ids(dict$dataset_id, "dict")
  if (!is.null(codes)) {
    check_ids(codes$dataset_id, "codes")
  }

  invisible(NULL)
}

.ms_collect_package_validation_issues <- function(pkg, path = NULL, require_iris = FALSE) {
  issues <- list()

  add_issue <- function(issue_type, message, table_id = NA_character_, column_name = NA_character_, value = NA_character_) {
    issues[[length(issues) + 1]] <<- tibble::tibble(
      issue_type = issue_type,
      table_id = table_id,
      column_name = column_name,
      value = value,
      message = message
    )
    invisible(NULL)
  }

  trimmed_unique <- function(x) {
    x <- trimws(as.character(x))
    x <- unique(x[!is.na(x) & nzchar(x)])
    x
  }

  # The `trimmed_unique()` tail, for values already canonicalized by type.
  drop_blank <- function(x) {
    unique(x[!is.na(x) & nzchar(x)])
  }

  if (nrow(pkg$dataset) != 1) {
    add_issue(
      "dataset",
      sprintf("dataset.csv should contain exactly one row; found %s.", nrow(pkg$dataset))
    )
  }
  if (nrow(pkg$tables) == 0) {
    add_issue("tables", "No rows found in tables.csv.")
  }

  # Tidy check 3: surface `MISSING METADATA:` markers in the *default* mode.
  #
  # `.ms_collect_review_placeholder_issues()` already reports these as errors
  # under `require_iris = TRUE`, so this adds only the missing half — an
  # ordinary `validate_salmon_datapackage()` call previously returned zero
  # issues and said nothing, letting a package look clean while stating in its
  # own metadata that its metadata is missing. No issue is raised here; the
  # strict path stays the single error channel.
  if (!isTRUE(require_iris)) {
    placeholder_fields <- .ms_collect_unresolved_placeholders(pkg)
    if (length(placeholder_fields) > 0L) {
      cli::cli_warn(c(
        "{length(placeholder_fields)} metadata field{?s} still hold{?s/} a placeholder.",
        "x" = paste(utils::head(.ms_cli_escape(placeholder_fields), 6L), collapse = ", "),
        "i" = "Replace them before publication; {.code require_iris = TRUE} reports these as errors."
      ))
    }
  }
  if (nrow(pkg$dictionary) == 0) {
    add_issue("dictionary", "No rows found in column_dictionary.csv.")
  }

  dup_tables <- unique(pkg$tables$table_id[duplicated(pkg$tables$table_id)])
  dup_tables <- dup_tables[!is.na(dup_tables) & nzchar(trimws(dup_tables))]
  if (length(dup_tables) > 0) {
    add_issue(
      "tables",
      sprintf("Duplicate table_id values in tables.csv: %s.", paste(dup_tables, collapse = ", "))
    )
  }

  table_ids <- trimmed_unique(pkg$tables$table_id)
  dict_table_ids <- trimmed_unique(pkg$dictionary$table_id)
  extra_dict_tables <- setdiff(dict_table_ids, table_ids)
  if (length(extra_dict_tables) > 0) {
    add_issue(
      "dictionary",
      sprintf(
        "column_dictionary.csv references table_id values not present in tables.csv: %s.",
        paste(extra_dict_tables, collapse = ", ")
      )
    )
  }

  if (!is.null(pkg$codes) && nrow(pkg$codes) > 0) {
    code_table_ids <- trimmed_unique(pkg$codes$table_id)
    extra_code_tables <- setdiff(code_table_ids, table_ids)
    if (length(extra_code_tables) > 0) {
      add_issue(
        "codes",
        sprintf(
          "codes.csv references table_id values not present in tables.csv: %s.",
          paste(extra_code_tables, collapse = ", ")
        )
      )
    }
  }

  for (i in seq_len(nrow(pkg$tables))) {
    table_row <- pkg$tables[i, , drop = FALSE]
    table_id <- .ms_scalar_text(table_row$table_id)
    if (!nzchar(table_id)) {
      next
    }

    file_name <- .ms_scalar_text(table_row$file_name)
    if (!table_id %in% names(pkg$resources)) {
      add_issue(
        "resource",
        sprintf(
          "Table '%s' points to resource '%s', but that file could not be loaded.",
          table_id,
          file_name
        ),
        table_id = table_id
      )
      next
    }

    table_dict <- pkg$dictionary[pkg$dictionary$table_id == table_id, , drop = FALSE]
    dict_cols <- trimmed_unique(table_dict$column_name)
    if (length(dict_cols) == 0) {
      add_issue(
        "dictionary",
        sprintf("No dictionary rows found for table '%s'.", table_id),
        table_id = table_id
      )
      next
    }

    data_df <- pkg$resources[[table_id]]
    data_cols <- names(data_df)

    # Tidy check 1: a declared primary key must actually identify a row. The
    # field was declared in tables.csv and read by nothing that tested it, so a
    # table could claim a key and ship duplicates.
    table_row <- pkg$tables[pkg$tables$table_id == table_id, , drop = FALSE]
    if (nrow(table_row) == 1L && "primary_key" %in% names(table_row)) {
      key_cols <- trimws(strsplit(.ms_scalar_text(table_row$primary_key), "[,;|]")[[1]])
      key_cols <- key_cols[nzchar(key_cols)]
      present <- intersect(key_cols, data_cols)
      if (length(key_cols) > 0L && length(present) == length(key_cols)) {
        # A missing component is as fatal as a duplicate: the row has no
        # identity at all. Checked separately because `paste()` turns NA into
        # the string "NA", which is unlikely to collide and so would pass the
        # duplicate test while identifying nothing.
        missing_key <- vapply(
          data_df[present],
          function(column) any(is.na(column) | !nzchar(trimws(as.character(column)))),
          logical(1)
        )
        if (any(missing_key)) {
          add_issue(
            "tables",
            sprintf(
              "Table '%s' declares primary key '%s' but column%s %s contain%s missing values.",
              table_id,
              paste(key_cols, collapse = ", "),
              ifelse(sum(missing_key) == 1, "", "s"),
              paste(present[missing_key], collapse = ", "),
              ifelse(sum(missing_key) == 1, "s", "")
            ),
            table_id = table_id
          )
        }

        key_values <- do.call(paste, c(lapply(data_df[present], as.character), sep = "\r"))
        duplicated_keys <- unique(key_values[duplicated(key_values)])
        if (length(duplicated_keys) > 0L) {
          add_issue(
            "tables",
            sprintf(
              "Table '%s' declares primary key '%s' but %d row%s repeat%s it.",
              table_id,
              paste(key_cols, collapse = ", "),
              length(duplicated_keys),
              ifelse(length(duplicated_keys) == 1, "", "s"),
              ifelse(length(duplicated_keys) == 1, "s", "")
            ),
            table_id = table_id
          )
        }
      }
    }

    # Tidy check 2: column names that look like values. A warning, never an
    # issue -- the SDP accepts untidy data, it just stops implying it checked.
    wide_cols <- .ms_detect_wide_columns(data_cols)
    if (length(wide_cols) > 0L) {
      cli::cli_warn(c(
        "Table {.val {table_id}} may not be tidy: {length(wide_cols)} column name{?s} look{?s/} like data values.",
        "x" = paste(utils::head(.ms_cli_escape(wide_cols), 6L), collapse = ", "),
        "i" = "Tidy data puts each variable in a column and each observation in a row.",
        "i" = "Consider {.code tidyr::pivot_longer()} before packaging."
      ))
    }

    # Values that do not satisfy their declared `value_type`. The reader keeps
    # the raw token rather than NA-ing it, so the code-value check below still
    # sees the offending value; this reports the declaration mismatch itself.
    for (mismatch in attr(data_df, "ms_value_type_mismatches") %||% list()) {
      add_issue(
        "columns",
        sprintf(
          "Table '%s' column '%s' declares value_type '%s' but %d value%s did not satisfy it (%s): %s.",
          table_id,
          mismatch$column,
          mismatch$declared,
          mismatch$count,
          if (mismatch$count == 1) "" else "s",
          mismatch$reason,
          paste(mismatch$examples, collapse = ", ")
        ),
        table_id = table_id,
        column_name = mismatch$column,
        value = paste(mismatch$examples, collapse = ", ")
      )
    }

    missing_in_data <- setdiff(dict_cols, data_cols)
    if (length(missing_in_data) > 0) {
      add_issue(
        "columns",
        sprintf(
          "Table '%s' is missing dictionary columns in data: %s.",
          table_id,
          paste(missing_in_data, collapse = ", ")
        ),
        table_id = table_id,
        column_name = paste(missing_in_data, collapse = ", ")
      )
    }

    extra_in_data <- setdiff(data_cols, dict_cols)
    if (length(extra_in_data) > 0) {
      add_issue(
        "columns",
        sprintf(
          "Table '%s' has data columns not listed in column_dictionary.csv: %s.",
          table_id,
          paste(extra_in_data, collapse = ", ")
        ),
        table_id = table_id,
        column_name = paste(extra_in_data, collapse = ", ")
      )
    }

    primary_key <- .ms_scalar_text(table_row$primary_key)
    if (nzchar(primary_key)) {
      pk_cols <- trimws(unlist(strsplit(primary_key, ",", fixed = TRUE)))
      pk_cols <- pk_cols[nzchar(pk_cols)]
      missing_pk <- setdiff(pk_cols, data_cols)
      if (length(missing_pk) > 0) {
        add_issue(
          "primary_key",
          sprintf(
            "Table '%s' primary_key references columns not present in data: %s.",
            table_id,
            paste(missing_pk, collapse = ", ")
          ),
          table_id = table_id,
          column_name = paste(missing_pk, collapse = ", ")
        )
      }
    }

    if (!is.null(pkg$codes) && nrow(pkg$codes) > 0) {
      table_codes <- pkg$codes[pkg$codes$table_id == table_id, , drop = FALSE]
      code_columns <- trimmed_unique(table_codes$column_name)

      for (column_name in code_columns) {
        if (!column_name %in% dict_cols) {
          add_issue(
            "codes",
            sprintf(
              "codes.csv references table '%s' column '%s', but that column is not in column_dictionary.csv.",
              table_id,
              column_name
            ),
            table_id = table_id,
            column_name = column_name
          )
        }

        if (!column_name %in% data_cols) {
          add_issue(
            "codes",
            sprintf(
              "codes.csv references table '%s' column '%s', but that column is not present in data.",
              table_id,
              column_name
            ),
            table_id = table_id,
            column_name = column_name
          )
          next
        }

        # Canonicalize both sides through the declared type. The data column is
        # a parsed vector and `code_value` is always raw CSV text, so comparing
        # `as.character()` of each made a package fail against its own codes.
        column_value_type <- table_dict$value_type[
          match(column_name, trimws(as.character(table_dict$column_name)))
        ]
        raw_code_values <- table_codes$code_value[table_codes$column_name == column_name]
        # The data resource is fidelity-checked when it is read, but code values
        # are raw text that never passes through that path. Without the same
        # check, a code token carrying more precision than its declared type can
        # hold canonicalizes onto a different data value and the comparison
        # silently succeeds.
        code_outcome <- .ms_convert_declared_tokens(raw_code_values, column_value_type)
        if (!is.null(code_outcome$reason)) {
          add_issue(
            "codes",
            sprintf(
              "Table '%s' column '%s' declares value_type '%s' but %d codes.csv value%s did not satisfy it (%s): %s.",
              table_id,
              column_name,
              column_value_type,
              length(code_outcome$offenders),
              if (length(code_outcome$offenders) == 1) "" else "s",
              code_outcome$reason,
              paste(utils::head(unique(as.character(code_outcome$offenders)), 3L), collapse = ", ")
            ),
            table_id = table_id,
            column_name = column_name
          )
        }
        data_values <- drop_blank(
          .ms_canonical_value_tokens(data_df[[column_name]], column_value_type)
        )
        code_values <- drop_blank(
          .ms_canonical_value_tokens(raw_code_values, column_value_type)
        )
        missing_code_values <- setdiff(data_values, code_values)
        if (length(missing_code_values) > 0) {
          add_issue(
            "codes",
            sprintf(
              "Table '%s' column '%s' has data values not listed in codes.csv: %s.",
              table_id,
              column_name,
              paste(missing_code_values, collapse = ", ")
            ),
            table_id = table_id,
            column_name = column_name,
            value = paste(missing_code_values, collapse = ", ")
          )
        }
      }
    }
  }

  composite_hints <- .ms_collect_composite_hint_values(
    dataset_meta = pkg$dataset,
    table_meta = pkg$tables,
    datapackage_path = if (!is.null(path)) file.path(path, "datapackage.json") else NA_character_,
    hint_fields = c("route", "route_key", "upload_route", "data_level"),
    optional_hint_fields = "source_name"
  )

  if (.ms_values_indicate_composite_intent(composite_hints$value)) {
    wsp_signal <- .ms_detect_wsp_composite_signal(pkg$resources)
    if (!wsp_signal$any_populated) {
      hint_fields_detected <- paste(unique(composite_hints$field), collapse = ", ")
      hint_values_detected <- paste(unique(composite_hints$value), collapse = ", ")
      add_issue(
        "composite_intent",
        sprintf(
          "Explicit composite route intent detected in %s (%s), but no populated WSP composite signal columns were found in cu_timeseries. Populate at least one of: %s.",
          hint_fields_detected,
          hint_values_detected,
          paste(wsp_signal$required_columns, collapse = ", ")
        ),
        table_id = "cu_timeseries",
        column_name = paste(wsp_signal$required_columns, collapse = ", "),
        value = hint_values_detected
      )
    }
  }

  if (length(issues) == 0) {
    return(tibble::tibble(
      issue_type = character(),
      table_id = character(),
      column_name = character(),
      value = character(),
      message = character()
    ))
  }

  dplyr::bind_rows(issues)
}

.ms_abort_package_validation_issues <- function(issues) {
  preview_n <- min(10, nrow(issues))
  messages <- issues$message[seq_len(preview_n)]
  cli_lines <- c(
    sprintf(
      "Salmon Data Package validation failed with %d structural issue%s.",
      nrow(issues),
      ifelse(nrow(issues) == 1, "", "s")
    ),
    .ms_cli_bullets(messages, "x")
  )

  if (nrow(issues) > preview_n) {
    cli_lines <- c(
      cli_lines,
      "i" = sprintf(
        "%d more issue%s not shown.",
        nrow(issues) - preview_n,
        ifelse(nrow(issues) - preview_n == 1, "", "s")
      )
    )
  }

  cli::cli_abort(cli_lines)
}

# The one missing-value token, used by every canonical read and write.
#
# It exists as a function rather than a literal because the contract is only
# sound if both sides agree, and the two sides live in different files. readr's
# defaults do not agree with each other: it *writes* `NA` and *reads*
# `c("", "NA")`, so a value that is literally the string "NA" -- a real
# fisheries gear code -- was written indistinguishably from a missing value and
# read back as missing.
#
# The residual ambiguity is deliberate and unchanged from the metadata writers:
# an empty string and a missing value share the empty field. CSV cannot
# distinguish them without quoting conventions readers disagree about, and the
# dictionary already treats blank as absent.
.ms_csv_na_token <- function() {
  ""
}

.ms_read_metadata_csv <- function(path) {
  readr::read_csv(
    path,
    col_types = readr::cols(.default = readr::col_character()),
    na = .ms_csv_na_token(),
    show_col_types = FALSE
  )
}

# Read a data resource with the types its dictionary declares. The dictionary is
# the sole type authority: anything it does not declare reads as character
# rather than being guessed, which is what makes the write -> read round trip
# lossless.
# Convert one declared column's raw tokens, or explain why it cannot be done
# faithfully. Returns `values` when the conversion is exact, otherwise `reason`
# and the offending tokens.
#
# The token is the ground truth. Every collector in this package is lossy in
# some direction -- `col_double()` collapses anything past 15 significant
# digits, `col_datetime()` collapses sub-resolution instants -- and no amount of
# careful formatting downstream can recover what the collector discarded. So the
# column is read as text and converted here, where the original is still
# available to check against.
.ms_convert_declared_tokens <- function(tokens, value_type) {
  present <- !is.na(tokens) & nzchar(trimws(tokens))
  parser <- switch(
    value_type,
    integer  = readr::parse_double,
    number   = readr::parse_double,
    boolean  = readr::parse_logical,
    date     = readr::parse_date,
    datetime = readr::parse_datetime,
    NULL
  )
  if (is.null(parser)) {
    return(list(values = tokens, reason = NULL))
  }

  values <- suppressWarnings(parser(tokens))

  unparseable <- present & is.na(values)
  if (any(unparseable)) {
    return(list(reason = "unparseable as that type", offenders = tokens[unparseable]))
  }

  if (value_type %in% c("integer", "number")) {
    # Decided by an actual round trip -- token versus the shortest rendering of
    # the double it produced -- not by digit or exponent thresholds, which
    # misclassify in both directions at the boundaries.
    lossy <- .ms_numeric_tokens_lossy(tokens, tokens, present)
    if (any(lossy)) {
      return(list(reason = "beyond exact numeric precision", offenders = tokens[lossy]))
    }
    if (identical(value_type, "integer")) {
      fractional <- present & is.finite(values) & values != trunc(values)
      if (any(fractional)) {
        return(list(reason = "not a whole number", offenders = tokens[fractional]))
      }
    }
  }

  if (identical(value_type, "datetime")) {
    # Six fractional digits are not uniformly safe: POSIXct is a double, so the
    # spacing between representable instants grows with the epoch magnitude and
    # already exceeds a microsecond around year 2243.
    precision <- .ms_datetime_token_precision(tokens)
    seconds <- suppressWarnings(as.numeric(values))
    too_fine <- present & (
      precision > 6L |
        (precision > 0L & is.finite(seconds) &
           10^(-precision) < .ms_double_spacing(seconds))
    )
    if (any(too_fine)) {
      return(list(
        reason = "finer than the datetime representation can hold",
        offenders = tokens[too_fine]
      ))
    }
  }

  list(values = values, reason = NULL)
}

# Read a data resource with the types its dictionary declares. The dictionary is
# the sole type authority: anything it does not declare stays character rather
# than being guessed, which is what makes the write/read round trip lossless.
#
# One text read, then in-memory conversion -- rather than a typed read plus a
# re-read when something looks wrong. That keeps the original token available
# for every fidelity check, and it is one pass over the file instead of two.
.ms_read_resource_csv <- function(file_path, table_dict) {
  raw <- readr::read_csv(
    file_path,
    col_types = list(.default = readr::col_character()),
    na = .ms_csv_na_token(),
    show_col_types = FALSE
  )
  header <- names(raw)

  declared_types <- list()
  if (is.data.frame(table_dict) && nrow(table_dict) > 0 &&
      all(c("column_name", "value_type") %in% names(table_dict))) {
    dict_names <- trimws(as.character(table_dict$column_name))
    for (nm in intersect(header, dict_names)) {
      declared_types[[nm]] <- as.character(table_dict$value_type[match(nm, dict_names)])
    }
  }

  parsed <- raw
  mismatches <- list()
  for (nm in names(declared_types)) {
    value_type <- declared_types[[nm]]
    if (!isTRUE(value_type %in% .ms_value_types()) || identical(value_type, "string")) {
      next
    }
    outcome <- .ms_convert_declared_tokens(raw[[nm]], value_type)
    if (is.null(outcome$reason)) {
      parsed[[nm]] <- outcome$values
      next
    }
    # The declared type is not satisfied: keep the exact token so the code-value
    # check still sees it, and report the declaration as wrong.
    mismatches[[length(mismatches) + 1L]] <- list(
      column = nm,
      declared = value_type,
      reason = outcome$reason,
      count = length(outcome$offenders),
      examples = utils::head(unique(as.character(outcome$offenders)), 3L)
    )
  }

  if (length(mismatches) > 0) {
    attr(parsed, "ms_value_type_mismatches") <- mismatches
  }
  parsed
}

.ms_datapackage_name <- function(dataset_id) {
  name <- tolower(dataset_id %||% "")
  name <- gsub("[^a-z0-9._-]+", "-", name)
  name <- gsub("^-+|-+$", "", name)
  if (!nzchar(name)) {
    return("salmon-data-package")
  }
  name
}

.ms_license_descriptor <- function(license) {
  if (identical(license, "Open Government Licence - Canada")) {
    return(list(
      name = "OGL-Canada-2.0",
      title = "Open Government Licence - Canada",
      path = "https://open.canada.ca/en/open-government-licence-canada"
    ))
  }
  if (identical(license, "CC-BY-4.0")) {
    return(list(
      name = "CC-BY-4.0",
      title = "Creative Commons Attribution 4.0 International",
      path = "https://creativecommons.org/licenses/by/4.0/"
    ))
  }
  if (identical(license, "MIT")) {
    return(list(
      name = "MIT",
      title = "MIT License",
      path = "https://opensource.org/license/mit"
    ))
  }

  license_text <- trimws(as.character(license[[1]]))
  parsed_url <- tryCatch(
    httr2::url_parse(license_text),
    error = function(cnd) NULL
  )
  valid_url <- !is.null(parsed_url) &&
    parsed_url$scheme %in% c("http", "https") &&
    !is.null(parsed_url$hostname) &&
    nzchar(parsed_url$hostname) &&
    identical(
      tryCatch(httr2::url_build(parsed_url), error = function(cnd) NA_character_),
      license_text
    )
  if (valid_url) {
    return(list(path = license_text))
  }

  cli::cli_abort("Unknown SDP publication license: {.val {license}}.")
}

.ms_descriptor_provenance <- function(datapackage) {
  contributors <- datapackage$contributors %||% list()
  creator <- NULL
  contact_name <- NULL
  contact_email <- NULL

  for (contributor in contributors) {
    role <- contributor$role %||% NA_character_
    if (identical(role, "creator") && is.null(creator)) {
      creator <- contributor$title %||% contributor$name %||% NULL
    }
    if (identical(role, "contact") && is.null(contact_name)) {
      contact_name <- contributor$title %||% contributor$name %||% NULL
      contact_email <- contributor$email %||% NULL
    }
  }

  list(
    creator = creator,
    contact_name = contact_name,
    contact_email = contact_email
  )
}

.ms_safe_path_slug <- function(x) {
  slug <- as.character(x)[1]
  if (is.na(slug) || !nzchar(trimws(slug))) {
    slug <- "dataset"
  }
  slug <- tolower(trimws(slug))
  slug <- gsub("[^a-z0-9._-]+", "-", slug)
  slug <- gsub("(^[-._]+|[-._]+$)", "", slug)
  if (!nzchar(slug)) {
    slug <- "dataset"
  }
  slug
}

.ms_metadata_dir <- function(path) {
  file.path(path, "metadata")
}

.ms_metadata_path <- function(path, file_name) {
  file.path(.ms_metadata_dir(path), file_name)
}

.ms_locate_metadata_file <- function(path, file_name) {
  candidates <- c(.ms_metadata_path(path, file_name), file.path(path, file_name))
  hits <- candidates[file.exists(candidates)]
  if (length(hits) == 0) {
    return(NA_character_)
  }
  hits[[1]]
}

.ms_collect_composite_hint_values <- function(
    dataset_meta,
    table_meta,
    datapackage_path,
    hint_fields,
    optional_hint_fields = character()
) {
  all_fields <- unique(c(hint_fields, optional_hint_fields))

  collect_from_df <- function(df, source_label) {
    if (is.null(df) || nrow(df) == 0) {
      return(tibble::tibble(source = character(), field = character(), value = character()))
    }

    present <- intersect(names(df), all_fields)
    if (length(present) == 0) {
      return(tibble::tibble(source = character(), field = character(), value = character()))
    }

    purrr::map_dfr(present, function(field_name) {
      values <- .ms_nonempty_text_values(df[[field_name]])
      if (length(values) == 0) {
        return(tibble::tibble(source = character(), field = character(), value = character()))
      }

      tibble::tibble(
        source = source_label,
        field = field_name,
        value = values
      )
    })
  }

  collect_from_json <- function(path) {
    if (!is.character(path) || length(path) != 1 || is.na(path) || !nzchar(path) || !file.exists(path)) {
      return(tibble::tibble(source = character(), field = character(), value = character()))
    }

    datapackage <- tryCatch(
      jsonlite::read_json(path, simplifyVector = FALSE),
      error = function(e) NULL
    )
    if (is.null(datapackage)) {
      return(tibble::tibble(source = character(), field = character(), value = character()))
    }

    top_values <- purrr::map_dfr(all_fields, function(field_name) {
      if (is.null(datapackage[[field_name]])) {
        return(tibble::tibble(source = character(), field = character(), value = character()))
      }

      values <- .ms_nonempty_text_values(datapackage[[field_name]])
      if (length(values) == 0) {
        return(tibble::tibble(source = character(), field = character(), value = character()))
      }

      tibble::tibble(
        source = "datapackage",
        field = field_name,
        value = values
      )
    })

    resource_values <- purrr::map_dfr(datapackage$resources %||% list(), function(resource) {
      resource_name <- resource$name %||% "<unnamed_resource>"
      purrr::map_dfr(all_fields, function(field_name) {
        if (is.null(resource[[field_name]])) {
          return(tibble::tibble(source = character(), field = character(), value = character()))
        }

        values <- .ms_nonempty_text_values(resource[[field_name]])
        if (length(values) == 0) {
          return(tibble::tibble(source = character(), field = character(), value = character()))
        }

        tibble::tibble(
          source = paste0("datapackage_resource:", resource_name),
          field = field_name,
          value = values
        )
      })
    })

    dplyr::bind_rows(top_values, resource_values)
  }

  dplyr::bind_rows(
    collect_from_df(dataset_meta, "dataset.csv"),
    collect_from_df(table_meta, "tables.csv"),
    collect_from_json(datapackage_path)
  ) %>%
    dplyr::distinct()
}

.ms_nonempty_text_values <- function(x) {
  values <- as.character(unlist(x, use.names = FALSE))
  values <- trimws(values)
  values <- values[!is.na(values) & nzchar(values)]
  unique(values)
}

.ms_values_indicate_composite_intent <- function(values) {
  if (length(values) == 0) {
    return(FALSE)
  }

  any(grepl("composite", values, ignore.case = TRUE))
}

.ms_column_has_populated_values <- function(x) {
  values <- x[!is.na(x)]
  if (length(values) == 0) {
    return(FALSE)
  }

  if (inherits(values, "factor") || is.character(values)) {
    values <- trimws(as.character(values))
    return(any(nzchar(values)))
  }

  TRUE
}

.ms_detect_wsp_composite_signal <- function(resources) {
  required_columns <- c("SPN_ABD_WILD", "SPN_TREND_WILD", "RAPID_STATUS")
  resource_names <- names(resources %||% list())
  idx <- which(tolower(resource_names) == "cu_timeseries")

  if (length(idx) == 0) {
    return(list(
      cu_timeseries_present = FALSE,
      required_columns = required_columns,
      populated_columns = character(),
      any_populated = FALSE
    ))
  }

  cu_tbl <- resources[[idx[[1]]]]
  present_columns <- intersect(required_columns, names(cu_tbl))
  populated_columns <- present_columns[vapply(present_columns, function(col_name) {
    .ms_column_has_populated_values(cu_tbl[[col_name]])
  }, logical(1))]

  list(
    cu_timeseries_present = TRUE,
    required_columns = required_columns,
    populated_columns = populated_columns,
    any_populated = length(populated_columns) > 0
  )
}

.ms_scalar_text <- function(value) {
  text <- as.character(value[[1]] %||% "")
  if (is.na(text)) {
    return("")
  }
  trimws(text)
}

.ms_code_target_has_review_context <- function(row) {
  code_value <- .ms_scalar_text(row$code_value)
  code_label <- .ms_scalar_text(row$code_label)
  code_description <- .ms_scalar_text(row$code_description)

  nzchar(code_description) || (nzchar(code_label) && (!nzchar(code_value) || !identical(tolower(code_label), tolower(code_value))))
}

.ms_prepare_review_suggestions <- function(suggestions) {
  if (is.null(suggestions)) {
    return(NULL)
  }

  suggestions <- tibble::as_tibble(suggestions)
  if (nrow(suggestions) == 0) {
    return(suggestions)
  }

  if (!all(c("target_scope", "code_value", "code_label", "code_description") %in% names(suggestions))) {
    return(suggestions)
  }

  keep <- vapply(seq_len(nrow(suggestions)), function(i) {
    row <- suggestions[i, , drop = FALSE]
    scope <- row$target_scope[[1]] %||% NA_character_
    if (!identical(scope, "code")) {
      return(TRUE)
    }
    .ms_code_target_has_review_context(row)
  }, logical(1))

  suggestions[keep, , drop = FALSE]
}

.ms_is_text_like_field_name <- function(x) {
  name_lower <- tolower(trimws(as.character(x %||% "")))
  if (!nzchar(name_lower)) {
    return(FALSE)
  }
  grepl("comment|note|remark|description|details?|memo|narrative|summary|reason|explanation|text", name_lower)
}

.ms_values_look_code_like <- function(values) {
  values <- as.character(values)
  values <- trimws(values[!is.na(values)])
  values <- values[nzchar(values)]
  if (length(values) == 0) {
    return(FALSE)
  }

  short_enough <- all(nchar(values) <= 24)
  single_token <- all(!grepl("\\s", values))
  code_chars <- all(grepl("^[[:alnum:]_./-]+$", values))

  short_enough && (single_token || code_chars)
}

.ms_column_is_semantic_code_candidate <- function(col_name, col) {
  if (!inherits(col, c("factor", "character"))) {
    return(FALSE)
  }
  if (.ms_is_text_like_field_name(col_name)) {
    return(FALSE)
  }

  vals <- as.character(col)
  vals <- trimws(vals[!is.na(vals)])
  vals <- vals[nzchar(vals)]
  if (length(vals) == 0) {
    return(FALSE)
  }

  unique_vals <- unique(vals)
  n_unique <- length(unique_vals)
  cardinality_ratio <- n_unique / length(vals)
  if (n_unique > 30) {
    return(FALSE)
  }

  if (cardinality_ratio <= 0.5) {
    return(TRUE)
  }

  n_unique <= 5 && .ms_values_look_code_like(unique_vals)
}

.ms_factor_code_keys <- function(resources, dataset_id = NULL) {
  if (is.null(resources) || length(resources) == 0) {
    return(tibble::tibble(table_id = character(), column_name = character()))
  }

  keys <- purrr::map_dfr(names(resources), function(tab_id) {
    df <- resources[[tab_id]]
    candidate_cols <- names(df)[vapply(names(df), function(col_name) {
      .ms_column_is_semantic_code_candidate(col_name, df[[col_name]])
    }, logical(1))]

    if (length(candidate_cols) == 0) {
      return(tibble::tibble(table_id = character(), column_name = character()))
    }

    tibble::tibble(
      table_id = tab_id,
      column_name = candidate_cols
    )
  })

  # Stamp the dataset_id when known so factor-scope selection can key on it and
  # not cross-match codes from a different dataset that share a table_id/column.
  if (!is.null(dataset_id) && nrow(keys) > 0) {
    keys$dataset_id <- as.character(dataset_id)[[1]]
    keys <- keys[, c("dataset_id", "table_id", "column_name"), drop = FALSE]
  }

  keys
}

.ms_non_measurement_target_tokens <- function(...) {
  text <- paste(unlist(list(...)), collapse = " ")
  text <- gsub("([a-z0-9])([A-Z])", "\\1 \\2", text)
  text <- tolower(text)
  text <- gsub("[^a-z0-9]+", " ", text)
  tokens <- unlist(strsplit(text, "\\s+"))
  tokens <- tokens[nzchar(tokens)]
  stop_words <- c(
    "the", "and", "for", "with", "from", "into", "column", "field", "data", "dataset", "table",
    "metadata", "missing", "review", "required", "code", "codes", "value", "values", "record",
    "records", "attribute", "attributes", "category", "categories", "variable", "variables",
    "measurement", "measurements", "type"
  )
  tokens[!(tokens %in% stop_words) & nchar(tokens) >= 3]
}

.ms_non_measurement_suggestion_is_compatible <- function(suggestion, dict_row) {
  role <- tolower(as.character(dict_row$column_role[[1]] %||% ""))
  if (!role %in% c("attribute", "categorical")) {
    return(TRUE)
  }

  label <- .ms_scalar_text(suggestion$label)
  if (!nzchar(label) || .ms_is_review_placeholder(label)) {
    return(FALSE)
  }

  role_hint_status <- if ("role_hint_status" %in% names(suggestion)) {
    tolower(.ms_scalar_text(suggestion$role_hint_status))
  } else {
    ""
  }
  if (role_hint_status %in% c("mismatch_property", "mismatch_variable")) {
    return(FALSE)
  }

  match_type <- if ("match_type" %in% names(suggestion)) {
    tolower(.ms_scalar_text(suggestion$match_type))
  } else {
    ""
  }
  if (nzchar(match_type) && !grepl("label", match_type)) {
    return(FALSE)
  }

  if ("score" %in% names(suggestion)) {
    score <- suppressWarnings(as.numeric(suggestion$score[[1]]))
    if (!is.na(score) && score < 0.75) {
      return(FALSE)
    }
  }

  query_tokens <- unique(.ms_non_measurement_target_tokens(
    if ("search_query" %in% names(suggestion)) suggestion$search_query else "",
    if ("target_label" %in% names(suggestion)) suggestion$target_label else "",
    if ("column_label" %in% names(suggestion)) suggestion$column_label else "",
    if ("column_name" %in% names(suggestion)) suggestion$column_name else ""
  ))
  label_tokens <- unique(.ms_non_measurement_target_tokens(label))
  if (length(query_tokens) == 0 || length(label_tokens) == 0) {
    return(FALSE)
  }

  length(intersect(query_tokens, label_tokens)) > 0
}

.ms_measurement_query_looks_physical <- function(...) {
  text <- paste(unlist(list(...)), collapse = " ")
  text <- gsub("([a-z0-9])([A-Z])", "\\1 \\2", text, perl = TRUE)
  text <- tolower(text)
  grepl(
    "\\b(water|level|discharge|flow|temperature|temp|rain|rainfall|snow|snowfall|precip|gust|wind|speed|depth|width|height|meter|metre|celsius)\\b",
    text,
    perl = TRUE
  )
}

.ms_normalize_measurement_unit_text <- function(x) {
  text <- tolower(.ms_scalar_text(x))
  text <- gsub("([a-z0-9])([A-Z])", "\\1 \\2", text, perl = TRUE)
  text <- gsub("\u00e2", "", text, fixed = TRUE)
  text <- gsub("\u00b0", " degree ", text, fixed = TRUE)
  text <- gsub("\u00b3", "3", text, fixed = TRUE)
  text <- gsub("[^a-z0-9/ ]+", " ", text)
  text <- trimws(gsub("\\s+", " ", text))
  if (!nzchar(text)) {
    return("")
  }

  if (grepl("^(cubic meter per second|cubic metre per second|m3/s|cms|cumec|cumecs)$", text)) return("cubic meter per second")
  if (grepl("^(degree celsius|degrees celsius|deg c|celsius)$", text)) return("degree celsius")
  if (grepl("^(kilometer per hour|kilometre per hour|km/h|kph)$", text)) return("kilometer per hour")
  if (grepl("^(square meter|square metre|square meters|square metres|sq m|m2)$", text)) return("square meter")
  if (grepl("^millimet(er|re)s?$", text)) return("millimeter")
  if (grepl("^centimet(er|re)s?$", text)) return("centimeter")
  if (grepl("^met(er|re)s?$", text)) return("meter")

  text
}

.ms_measurement_has_paired_unit_column <- function(dict_row, dict) {
  col_name <- .ms_scalar_text(dict_row$column_name)
  if (!nzchar(col_name) || !grepl("value$", col_name, ignore.case = TRUE)) {
    return(FALSE)
  }

  table_matches <- rep(TRUE, nrow(dict))
  for (key in intersect(c("dataset_id", "table_id"), names(dict_row))) {
    row_value <- .ms_scalar_text(dict_row[[key]])
    if (nzchar(row_value) && key %in% names(dict)) {
      table_matches <- table_matches & !is.na(dict[[key]]) & as.character(dict[[key]]) == row_value
    }
  }

  sibling_name <- paste0(sub("value$", "", col_name, ignore.case = TRUE), "unit")
  any(table_matches & !is.na(dict$column_name) & tolower(as.character(dict$column_name)) == tolower(sibling_name))
}

.ms_measurement_supports_constraint_slot <- function(suggestion, dict_row) {
  text <- tolower(paste(
    if ("search_query" %in% names(suggestion)) .ms_scalar_text(suggestion$search_query) else "",
    if ("target_label" %in% names(suggestion)) .ms_scalar_text(suggestion$target_label) else "",
    if ("target_description" %in% names(suggestion)) .ms_scalar_text(suggestion$target_description) else "",
    if ("column_label" %in% names(dict_row)) .ms_scalar_text(dict_row$column_label) else "",
    if ("column_description" %in% names(dict_row)) .ms_scalar_text(dict_row$column_description) else "",
    if ("column_name" %in% names(dict_row)) .ms_scalar_text(dict_row$column_name) else ""
  ))

  grepl(
    "\\b(origin|life[ -]?stage|stage|run|season|age|sex|maturity|status|class|type|phase|terminal|ocean|freshwater|wild|hatchery|population|stock|species group|reporting unit|benchmark)\\b",
    text,
    perl = TRUE
  )
}

.ms_measurement_supports_statistical_modifier_slot <- function(suggestion, dict_row) {
  text <- tolower(paste(
    if ("search_query" %in% names(suggestion)) .ms_scalar_text(suggestion$search_query) else "",
    if ("target_label" %in% names(suggestion)) .ms_scalar_text(suggestion$target_label) else "",
    if ("target_description" %in% names(suggestion)) .ms_scalar_text(suggestion$target_description) else "",
    if ("column_label" %in% names(dict_row)) .ms_scalar_text(dict_row$column_label) else "",
    if ("column_description" %in% names(dict_row)) .ms_scalar_text(dict_row$column_description) else "",
    if ("column_name" %in% names(dict_row)) .ms_scalar_text(dict_row$column_name) else ""
  ))

  grepl(
    "\\b(mean|average|max(imum)?|min(imum)?|total|cumulative|sum|peak|median|aggregate|aggregated|index)\\b",
    text,
    perl = TRUE
  )
}

.ms_measurement_suggestion_is_compatible <- function(suggestion, dict_row, dict = NULL) {
  role <- tolower(as.character(dict_row$column_role[[1]] %||% ""))
  if (!identical(role, "measurement")) {
    return(TRUE)
  }

  query_text <- paste(
    if ("search_query" %in% names(suggestion)) .ms_scalar_text(suggestion$search_query) else "",
    if ("target_label" %in% names(suggestion)) .ms_scalar_text(suggestion$target_label) else "",
    if ("column_label" %in% names(suggestion)) .ms_scalar_text(suggestion$column_label) else "",
    if ("column_name" %in% names(suggestion)) .ms_scalar_text(suggestion$column_name) else ""
  )

  target_field <- if ("target_sdp_field" %in% names(suggestion)) {
    .ms_scalar_text(suggestion$target_sdp_field)
  } else {
    ""
  }
  if (!is.null(dict) && !identical(target_field, "unit_iri") && .ms_measurement_has_paired_unit_column(dict_row, dict)) {
    return(FALSE)
  }
  if (identical(target_field, "constraint_iri") && !.ms_measurement_supports_constraint_slot(suggestion, dict_row)) {
    return(FALSE)
  }
  if (identical(target_field, "statistical_modifier_iri") && !.ms_measurement_supports_statistical_modifier_slot(suggestion, dict_row)) {
    return(FALSE)
  }

  if (!.ms_measurement_query_looks_physical(query_text)) {
    return(TRUE)
  }

  label <- .ms_scalar_text(suggestion$label)
  if (!nzchar(label) || .ms_is_review_placeholder(label)) {
    return(FALSE)
  }

  target_field <- if ("target_sdp_field" %in% names(suggestion)) {
    .ms_scalar_text(suggestion$target_sdp_field)
  } else {
    ""
  }

  match_type <- if ("match_type" %in% names(suggestion)) {
    tolower(.ms_scalar_text(suggestion$match_type))
  } else {
    ""
  }

  if (identical(target_field, "unit_iri")) {
    query_unit <- .ms_normalize_measurement_unit_text(
      if ("search_query" %in% names(suggestion)) suggestion$search_query else ""
    )
    label_unit <- .ms_normalize_measurement_unit_text(label)
    if (!nzchar(query_unit) || !nzchar(label_unit) || !identical(query_unit, label_unit)) {
      return(FALSE)
    }
    if ("score" %in% names(suggestion)) {
      score <- suppressWarnings(as.numeric(suggestion$score[[1]]))
      if (!is.na(score) && score < 0.75) {
        return(FALSE)
      }
    }
    return(TRUE)
  }

  suggestion_iri <- tolower(.ms_scalar_text(suggestion$iri))
  suggestion_ontology <- tolower(.ms_scalar_text(suggestion$ontology))
  suggestion_source <- tolower(.ms_scalar_text(suggestion$source))
  if (grepl("rs\\.tdwg\\.org/dwc/terms/", suggestion_iri) ||
      suggestion_ontology %in% c("dwc", "darwin core") ||
      suggestion_source %in% c("dwc", "tdwg")) {
    return(FALSE)
  }

  if (nzchar(match_type) && !grepl("label|unit", match_type)) {
    return(FALSE)
  }

  if ("score" %in% names(suggestion)) {
    score <- suppressWarnings(as.numeric(suggestion$score[[1]]))
    if (!is.na(score) && score < 0.75) {
      return(FALSE)
    }
  }

  query_tokens <- unique(.ms_non_measurement_target_tokens(query_text))
  label_tokens <- unique(.ms_non_measurement_target_tokens(label))
  if (length(query_tokens) == 0 || length(label_tokens) == 0) {
    return(FALSE)
  }

  length(intersect(query_tokens, label_tokens)) > 0
}

.ms_create_sdp_llm_auto_apply_roles <- function() {
  c("variable", "property", "entity", "unit")
}

.ms_prepare_llm_auto_apply_suggestions <- function(dict,
                                                   suggestions,
                                                   allowed_roles = .ms_create_sdp_llm_auto_apply_roles()) {
  suggestions <- tibble::as_tibble(suggestions)
  if (nrow(suggestions) == 0 || !"llm_selected" %in% names(suggestions)) {
    return(suggestions[0, , drop = FALSE])
  }

  suggestions <- suggestions %>%
    dplyr::filter(
      !is.na(.data$llm_selected) & .data$llm_selected,
      .data$dictionary_role %in% allowed_roles
    )
  if ("llm_decision" %in% names(suggestions)) {
    suggestions <- dplyr::filter(
      suggestions,
      !is.na(.data$llm_decision) & .data$llm_decision == "accept"
    )
  }

  .ms_filter_auto_apply_suggestions(dict, suggestions)
}

.ms_filter_auto_apply_suggestions <- function(dict, suggestions) {
  if (is.null(suggestions) || nrow(suggestions) == 0) {
    return(suggestions)
  }

  suggestions[vapply(seq_len(nrow(suggestions)), function(i) {
    suggestion <- suggestions[i, , drop = FALSE]
    target_field <- if ("target_sdp_field" %in% names(suggestion)) {
      .ms_scalar_text(suggestion$target_sdp_field)
    } else {
      ""
    }
    if (!nzchar(target_field)) {
      return(TRUE)
    }

    matches <- dict$column_name == suggestion$column_name[[1]]
    for (key in intersect(c("dataset_id", "table_id"), names(dict))) {
      if (key %in% names(suggestion)) {
        key_value <- .ms_scalar_text(suggestion[[key]])
        if (nzchar(key_value)) {
          matches <- matches & !is.na(dict[[key]]) & as.character(dict[[key]]) == key_value
        }
      }
    }

    row_ids <- which(matches)
    if (length(row_ids) == 0) {
      return(FALSE)
    }

    any(vapply(row_ids, function(row_id) {
      dict_row <- dict[row_id, , drop = FALSE]
      role <- tolower(as.character(dict_row$column_role[[1]] %||% ""))
      if (role %in% c("identifier", "temporal")) {
        return(FALSE)
      }
      if (identical(role, "measurement")) {
        return(.ms_measurement_suggestion_is_compatible(suggestion, dict_row, dict = dict))
      }
      .ms_non_measurement_suggestion_is_compatible(suggestion, dict_row)
    }, logical(1)))
  }, logical(1)), , drop = FALSE]
}

.ms_select_semantic_seed_codes <- function(codes, resources, scope = c("factor", "all", "none"), dataset_id = NULL) {
  scope <- match.arg(scope)
  codes <- .ms_normalize_codes(codes)

  if (is.null(codes) || nrow(codes) == 0) {
    return(codes)
  }
  if (identical(scope, "all")) {
    return(codes)
  }
  if (identical(scope, "none")) {
    return(codes[0, , drop = FALSE])
  }

  factor_keys <- .ms_factor_code_keys(resources, dataset_id = dataset_id)
  if (nrow(factor_keys) == 0) {
    return(codes[0, , drop = FALSE])
  }

  # Include dataset_id in the join key when it is present on both sides so
  # multi-dataset seed_codes cannot cross-match on a shared table_id/column_name.
  join_cols <- intersect(
    c("dataset_id", "table_id", "column_name"),
    intersect(names(codes), names(factor_keys))
  )
  if (!all(c("table_id", "column_name") %in% join_cols)) {
    join_cols <- c("table_id", "column_name")
  }

  dplyr::semi_join(codes, factor_keys, by = join_cols)
}

.ms_create_sdp_seed_note <- function(seed_semantics = TRUE,
                                     seed_verbose = TRUE,
                                     semantic_code_scope = c("factor", "all", "none")) {
  if (!isTRUE(seed_semantics) || !isTRUE(seed_verbose)) {
    return(NULL)
  }

  semantic_code_scope <- match.arg(semantic_code_scope)
  scope_note <- switch(
    semantic_code_scope,
    factor = "Code-level semantic suggestions are limited to factor and low-cardinality character columns for this first pass.",
    all = "Code-level semantic suggestions are enabled for all inferred code lists in this run.",
    none = "Code-level semantic suggestions are skipped for this run."
  )

  paste(
    "Seeding semantic suggestions from online vocabularies.",
    "This may take a few minutes for wider tables.",
    scope_note,
    "Use {.code seed_semantics = FALSE} for the fastest first pass."
  )
}

.ms_create_sdp_update_note <- function(check_updates = interactive()) {
  if (!isTRUE(check_updates)) {
    return(NULL)
  }

  result <- tryCatch(
    check_for_updates(quiet = TRUE),
    error = function(e) NULL
  )

  if (is.null(result) || !inherits(result, "metasalmon_update_check")) {
    return(NULL)
  }
  if (!identical(result$status, "update_available") || !isTRUE(result$update_available)) {
    return(NULL)
  }

  latest_version <- result$latest_version %||% NA_character_
  install_command <- result$install_command %||% "remotes::install_github('salmon-data-mobilization/metasalmon')"
  if (is.na(latest_version) || !nzchar(latest_version)) {
    latest_version <- "newer"
  }

  # `latest_version` derives from the GitHub release tag and `install_command`
  # can come from the same payload, so both are remote-controlled and this
  # sprintf() result becomes a cli template downstream.
  sprintf(
    "A newer {.pkg metasalmon} release (%s) is available. Update later with {.code %s} if you want.",
    .ms_cli_escape(latest_version),
    .ms_cli_escape(install_command)
  )
}

.ms_normalize_resource_file_name <- function(file_name) {
  normalized <- gsub("\\\\", "/", trimws(as.character(file_name)[1]))
  normalized <- sub("^\\./", "", normalized)

  if (!nzchar(normalized)) {
    cli::cli_abort("{.field file_name} cannot be blank after normalization.")
  }
  if (grepl("^([A-Za-z]:)?/", normalized)) {
    cli::cli_abort("{.field file_name} must be a relative path inside the package, not an absolute path.")
  }
  if (grepl("(^|/)\\.\\.(/|$)", normalized)) {
    cli::cli_abort("{.field file_name} must not contain '..' path segments.")
  }

  normalized
}

.ms_force_data_subdir <- function(file_name) {
  normalized <- gsub("\\\\", "/", file_name)
  normalized <- sub("^\\./", "", normalized)

  if (startsWith(normalized, "data/")) {
    return(normalized)
  }

  file.path("data", basename(normalized))
}

.ms_review_iri_prefix <- function() {
  "REVIEW: "
}

.ms_is_review_iri <- function(x) {
  text <- .ms_scalar_text(x)
  nzchar(text) && grepl("^\\s*REVIEW\\s*:", text, ignore.case = TRUE)
}

.ms_strip_review_iri <- function(x) {
  if (length(x) == 0) {
    return(x)
  }
  out <- as.character(x)
  out <- gsub("^\\s*REVIEW\\s*:\\s*", "", out, ignore.case = TRUE)
  out
}

.ms_mark_reviewed_dictionary_iris <- function(dict, original_dict, suggestions, strategy = c("top", "llm")) {
  dict <- tibble::as_tibble(dict)
  original_dict <- tibble::as_tibble(original_dict)
  suggestions <- tibble::as_tibble(suggestions)
  strategy <- match.arg(strategy)

  if (nrow(dict) == 0 || nrow(suggestions) == 0) {
    return(dict)
  }

  iri_fields <- intersect(
    c("term_iri", "property_iri", "entity_iri", "unit_iri", "constraint_iri", "statistical_modifier_iri"),
    names(dict)
  )
  if (length(iri_fields) == 0) {
    return(dict)
  }

  review_rows <- suggestions %>%
    dplyr::filter(
      .data$target_scope == "column",
      .data$target_sdp_file == "column_dictionary.csv",
      .data$target_sdp_field %in% iri_fields,
      !is.na(.data$iri),
      .data$iri != ""
    )

  if (identical(strategy, "llm")) {
    if (!"llm_selected" %in% names(review_rows)) {
      return(dict)
    }
    review_rows <- dplyr::filter(review_rows, !is.na(.data$llm_selected) & .data$llm_selected)
  }

  if (nrow(review_rows) == 0) {
    return(dict)
  }

  for (i in seq_len(nrow(review_rows))) {
    field <- review_rows$target_sdp_field[[i]]
    row_idx <- which(
      as.character(dict$dataset_id) == as.character(review_rows$dataset_id[[i]]) &
        as.character(dict$table_id) == as.character(review_rows$table_id[[i]]) &
        as.character(dict$column_name) == as.character(review_rows$column_name[[i]])
    )
    if (length(row_idx) != 1L) {
      next
    }

    old_value <- .ms_scalar_text(original_dict[[field]][row_idx])
    new_value <- .ms_scalar_text(dict[[field]][row_idx])
    expected <- .ms_scalar_text(review_rows$iri[[i]])

    if (!nzchar(expected) || !identical(new_value, expected)) {
      next
    }
    if (nzchar(old_value)) {
      next
    }

    dict[[field]][row_idx] <- paste0(.ms_review_iri_prefix(), expected)
  }

  dict
}

.ms_write_sdp_review_readme <- function(
  pkg_path,
  dataset_id,
  has_suggestions = TRUE,
  has_codes = FALSE,
  has_review_prefill = FALSE
) {
  review_issue_urls <- c(
    "- Shared cross-organization/domain term request (salmon-domain): https://github.com/salmon-data-mobilization/salmon-domain-ontology/issues/new/choose",
    "- DFO-specific policy/operations term request (gcdfo / DFO salmon ontology): https://github.com/dfo-pacific-science/dfo-salmon-ontology/issues/new/choose"
  )

  checklist <- c(
    "Start in metadata/*.csv and replace every value that begins with 'MISSING DESCRIPTION:' or 'MISSING METADATA:'.",
    paste(
      "Review metadata/column_dictionary.csv and metadata/tables.csv first.",
      "Those files already contain the prefilled labels and IRIs you are actually finalizing.",
      if (isTRUE(has_review_prefill)) {
        "Any IRI that begins with 'REVIEW:' already lives there; keep/edit it there and remove the REVIEW prefix only when final."
      } else {
        "Confirm or edit the prefilled IRIs there before touching anything else."
      }
    ),
    if (isTRUE(has_codes)) {
      "If metadata/codes.csv exists, confirm the coded values and descriptions there before publish."
    },
    if (isTRUE(has_suggestions)) {
      paste(
        "Use semantic_suggestions.csv only as a fallback shortlist if you are unsure or want a better match.",
        "Click through and read the term definitions before changing an IRI.",
        "If no candidate fits, request a new term instead of forcing a bad match."
      )
    } else {
      paste(
        "No semantic_suggestions.csv was written for this package.",
        "If you still need a missing term, request a new one instead of forcing a bad match."
      )
    },
    "If you need EDH XML after review, rebuild it from the finalized package with write_edh_xml_from_sdp(pkg_path).",
    "Re-open the folder in R with read_salmon_datapackage(pkg_path), then run validate_salmon_datapackage(pkg_path, require_iris = TRUE). Validation should pass only after every REVIEW marker is gone.",
    "Share the whole package folder (or a zip of the whole folder) so the metadata and data stay together."
  )
  checklist <- checklist[nzchar(trimws(checklist))]
  checklist_lines <- paste0("[ ] ", seq_along(checklist), ". ", checklist)

  lines <- c(
    "Salmon Data Package Review Checklist",
    "",
    sprintf("Dataset ID: %s", dataset_id),
    "",
    "Review the package in Excel, but treat metadata/column_dictionary.csv and metadata/tables.csv as the files you finalize.",
    "semantic_suggestions.csv is backup context, not the main place to do the review.",
    "",
    "Checklist:",
    checklist_lines,
    "",
    "If you need a new ontology term, route it here:",
    review_issue_urls,
    "",
    "Recommended path: create package -> review/edit in Excel -> reload and check unresolved gaps -> remove REVIEW markers -> rebuild EDH XML if needed -> validate -> publish.",
    "Tip: if you edit CSV files in Excel, save them back to CSV before re-validating in R.",
    "Tip: semantic_suggestions.csv is the detailed evidence trail; metadata/column_dictionary.csv and metadata/tables.csv are the authoritative files you actually finalize.",
    "Guide: https://salmon-data-mobilization.github.io/metasalmon/articles/post-review-package-publication.html"
  )
  readme_path <- .ms_replace_create_output(file.path(pkg_path, "README-review.txt"))
  writeLines(lines, con = readme_path, useBytes = TRUE)
}

# Metadata fields still holding a `MISSING METADATA:` / `MISSING DESCRIPTION:`
# marker. Reported as "file.field" so a user can go straight to the cell.
.ms_collect_unresolved_placeholders <- function(pkg) {
  found <- character()
  targets <- list(
    dataset.csv = pkg$dataset,
    tables.csv = pkg$tables,
    column_dictionary.csv = pkg$dictionary,
    # The strict path scans codes for the same markers, so omitting it here
    # would have left part of the default-mode behaviour silently conditional
    # on `require_iris`.
    codes.csv = pkg$codes
  )
  for (file_name in names(targets)) {
    tbl <- targets[[file_name]]
    if (is.null(tbl) || nrow(tbl) == 0L) {
      next
    }
    for (column in names(tbl)) {
      hits <- vapply(tbl[[column]], .ms_is_review_placeholder, logical(1), USE.NAMES = FALSE)
      if (any(hits)) {
        found <- c(found, sprintf("%s$%s", file_name, column))
      }
    }
  }
  sort(unique(found), method = "radix")
}

# Column names that look like data values rather than variable names.
#
# Tidy data puts each variable in a column; a spreadsheet habit puts each *year*
# in a column. The SDP's four metadata levels describe columns and rows, so a
# table shaped like a matrix has nothing for them to describe — but the package
# accepted it silently, which is worse than rejecting it.
#
# A heuristic, and deliberately a warning rather than an error: the SDP may
# accept untidy data, it must simply stop implying it checked. Two shapes, both
# needing at least three columns so an ordinary `x2`/`x3` pair is not flagged:
# bare year-like names, and a shared prefix with numeric suffixes.
.ms_detect_wide_columns <- function(column_names) {
  names_chr <- trimws(as.character(column_names))
  names_chr <- names_chr[!is.na(names_chr) & nzchar(names_chr)]
  if (length(names_chr) < 3L) {
    return(character())
  }

  year_like <- names_chr[grepl("^[Xx]?(19|20)[0-9]{2}$", names_chr)]
  if (length(year_like) >= 3L) {
    return(sort(year_like, method = "radix"))
  }

  # A shared stem with numeric tails: count_1998, count_1999, count_2000.
  stems <- sub("[_.-]?[0-9]+$", "", names_chr)
  numeric_tail <- stems != names_chr
  if (!any(numeric_tail)) {
    return(character())
  }
  tally <- table(stems[numeric_tail])
  repeated <- names(tally)[tally >= 3L]
  if (length(repeated) == 0L) {
    return(character())
  }
  sort(names_chr[numeric_tail & stems %in% repeated], method = "radix")
}

.ms_is_review_placeholder <- function(x) {
  text <- .ms_scalar_text(x)
  nzchar(text) && grepl("^\\s*(MISSING METADATA|MISSING DESCRIPTION|REVIEW REQUIRED)\\s*:", text, ignore.case = TRUE)
}

.ms_table_target_query_context <- function(row) {
  parts <- c(
    observation_unit = if ("observation_unit" %in% names(row) && !.ms_is_review_placeholder(row$observation_unit)) .ms_scalar_text(row$observation_unit) else "",
    description = if ("description" %in% names(row) && !.ms_is_review_placeholder(row$description)) .ms_scalar_text(row$description) else "",
    table_label = if ("table_label" %in% names(row)) .ms_scalar_text(row$table_label) else "",
    table_id = if ("table_id" %in% names(row)) .ms_scalar_text(row$table_id) else ""
  )

  basis <- names(parts)[match(TRUE, nzchar(parts), nomatch = 0)]
  if (length(basis) == 0 || identical(basis, 0L)) {
    basis <- ""
  }

  list(
    basis = basis,
    context = trimws(paste(parts[nzchar(parts)], collapse = " "))
  )
}

.ms_table_text_tokens <- function(x) {
  text <- tolower(.ms_scalar_text(x))
  text <- gsub("[^a-z0-9]+", " ", text)
  tokens <- unlist(strsplit(text, "\\s+"))
  tokens <- tokens[nzchar(tokens)]
  stop_words <- c(
    "the", "and", "for", "with", "from", "into", "table", "tables", "data", "dataset",
    "metadata", "missing", "review", "required", "describe", "what", "each", "row", "rows",
    "main", "records", "record", "values", "value", "observation", "unit", "identifier", "code", "field"
  )
  tokens[!(tokens %in% stop_words) & (nchar(tokens) >= 3 | tokens %in% c("cu", "id"))]
}

.ms_table_suggestion_is_compatible <- function(suggestion, table_row, strategy = c("top", "llm")) {
  strategy <- match.arg(strategy)
  query_basis <- if ("target_query_basis" %in% names(suggestion)) .ms_scalar_text(suggestion$target_query_basis) else ""
  query_context <- if ("target_query_context" %in% names(suggestion)) .ms_scalar_text(suggestion$target_query_context) else ""

  if (!nzchar(query_basis) || !nzchar(query_context)) {
    derived <- .ms_table_target_query_context(table_row)
    if (!nzchar(query_basis)) {
      query_basis <- derived$basis
    }
    if (!nzchar(query_context)) {
      query_context <- derived$context
    }
  }

  allowed_bases <- c("observation_unit", "description", "table_label", "table_id")
  if (!query_basis %in% allowed_bases) {
    return(FALSE)
  }

  label <- .ms_scalar_text(suggestion$label)
  if (!nzchar(label) || .ms_is_review_placeholder(label) || grepl("\\b(missing|metadata|review required)\\b", label, ignore.case = TRUE)) {
    return(FALSE)
  }

  match_type <- tolower(.ms_scalar_text(suggestion$match_type))
  if (!nzchar(match_type) || !grepl("^label", match_type)) {
    return(FALSE)
  }

  if ("score" %in% names(suggestion)) {
    score <- suppressWarnings(as.numeric(suggestion$score[[1]]))
    if (!is.na(score) && score < 0.75) {
      return(FALSE)
    }
  }

  context_tokens <- unique(.ms_table_text_tokens(query_context))
  label_tokens <- unique(.ms_table_text_tokens(label))
  if (length(context_tokens) == 0 || length(label_tokens) == 0) {
    return(FALSE)
  }

  length(intersect(context_tokens, label_tokens)) > 0
}

.ms_apply_table_semantic_suggestions <- function(table_meta,
                                               suggestions,
                                               strategy = c("top", "llm"),
                                               min_llm_confidence = NULL,
                                               overwrite = FALSE,
                                               mark_review = FALSE) {
  table_meta <- .ms_normalize_table_meta(table_meta)
  suggestions <- tibble::as_tibble(suggestions)
  strategy <- match.arg(strategy)

  if (nrow(table_meta) == 0 || nrow(suggestions) == 0) {
    return(table_meta)
  }

  required_cols <- c("target_scope", "target_sdp_file", "target_sdp_field", "iri")
  if (!all(required_cols %in% names(suggestions))) {
    return(table_meta)
  }

  table_suggestions <- suggestions %>%
    dplyr::mutate(.row_id = dplyr::row_number()) %>%
    dplyr::filter(
      .data$target_scope == "table",
      .data$target_sdp_file == "tables.csv",
      .data$target_sdp_field == "observation_unit_iri",
      !is.na(.data$iri),
      .data$iri != ""
    ) %>%
    dplyr::arrange(.data$.row_id)

  if (identical(strategy, "llm")) {
    if (!"llm_selected" %in% names(table_suggestions)) {
      return(table_meta)
    }
    table_suggestions <- dplyr::filter(table_suggestions, !is.na(.data$llm_selected) & .data$llm_selected)
    if (!is.null(min_llm_confidence)) {
      table_suggestions <- dplyr::filter(
        table_suggestions,
        !is.na(.data$llm_confidence) & .data$llm_confidence >= min_llm_confidence
      )
    }
  }

  if (nrow(table_suggestions) == 0) {
    return(table_meta)
  }

  key_cols <- intersect(c("dataset_id", "table_id"), names(table_suggestions))
  if (length(key_cols) == 0) {
    return(table_meta)
  }

  out <- table_meta
  for (row_id in seq_len(nrow(out))) {
    existing_iri <- .ms_scalar_text(out$observation_unit_iri[row_id])
    if (!isTRUE(overwrite) && nzchar(existing_iri)) {
      next
    }

    matches <- rep(TRUE, nrow(table_suggestions))
    for (key in key_cols) {
      row_value <- out[[key]][row_id]
      if (!is.na(row_value) && nzchar(as.character(row_value))) {
        matches <- matches & !is.na(table_suggestions[[key]]) & as.character(table_suggestions[[key]]) == as.character(row_value)
      }
    }

    candidate_rows <- which(matches)
    if (length(candidate_rows) == 0) {
      next
    }

    candidate_rows <- candidate_rows[vapply(candidate_rows, function(i) {
      .ms_table_suggestion_is_compatible(
        table_suggestions[i, , drop = FALSE],
        out[row_id, , drop = FALSE],
        strategy = strategy
      )
    }, logical(1))]
    if (length(candidate_rows) == 0) {
      next
    }

    suggestion <- table_suggestions[candidate_rows[[1]], , drop = FALSE]
    observation_unit_iri <- suggestion$iri[[1]]
    if (isTRUE(mark_review)) {
      observation_unit_iri <- paste0(.ms_review_iri_prefix(), observation_unit_iri)
    }
    out$observation_unit_iri[row_id] <- observation_unit_iri
    if ("observation_unit" %in% names(out) && "label" %in% names(suggestion)) {
      suggestion_label <- as.character(suggestion$label[[1]] %||% "")
      if (!is.na(suggestion_label) && nzchar(trimws(suggestion_label))) {
        existing_label <- as.character(out$observation_unit[row_id] %||% "")
        missing_label <- is.na(existing_label) | trimws(existing_label) == "" |
          grepl("^\\s*(MISSING METADATA|MISSING DESCRIPTION|REVIEW REQUIRED)\\s*:", existing_label, ignore.case = TRUE)
        if (isTRUE(missing_label)) {
          out$observation_unit[row_id] <- trimws(suggestion_label)
        }
      }
    }
  }

  out
}
