# Shared SDP extension-file plumbing -----------------------------------------
#
# The `.ms_sdp_extension_*` family is the hardened I/O layer shared by every
# module that writes an SDP metadata extension resource (observation
# structures, KNB publication, reproducibility manifests, and the sdp-0.2.0
# methods migration): symlink-refusing path resolution, closed-schema CSV
# read/validation, and crash-safe atomic multi-file writes with rollback.
# It lived in sdp-methods.R until sdp-0.3.0 removed the methods registry;
# the helpers moved here unchanged because the other consumers remain.

.ms_sdp_extension_abort <- function(message, ..., .envir = parent.frame()) {
  cli::cli_abort(message, ..., .envir = .envir)
}

.ms_sdp_extension_root <- function(path) {
  if (length(path) != 1L || is.na(path) || !nzchar(path) || !dir.exists(path)) {
    .ms_sdp_extension_abort(
      "{.arg path} must name one existing Salmon Data Package directory."
    )
  }
  if (.ms_sdp_extension_is_symlink(path)) {
    .ms_sdp_extension_abort(
      "{.arg path} must not be a symlink; refusing an unsafe SDP root."
    )
  }
  normalizePath(path, winslash = "/", mustWork = TRUE)
}

.ms_sdp_extension_is_blank <- function(value) {
  is.na(value) | !nzchar(trimws(as.character(value)))
}

.ms_sdp_extension_is_absolute_iri <- function(value) {
  value <- as.character(value)
  valid <- !.ms_sdp_extension_is_blank(value) &
    grepl("^[A-Za-z][A-Za-z0-9+.-]*:[^[:space:]]+$", value, perl = TRUE) &
    !grepl("^REVIEW:", value, ignore.case = TRUE)
  web <- valid & grepl("^https?:", value, ignore.case = TRUE)
  valid[web] <- grepl(
    "^https?://[^/[:space:]]+",
    value[web],
    ignore.case = TRUE,
    perl = TRUE
  )
  valid
}

.ms_sdp_extension_is_symlink <- function(path) {
  # `Sys.readlink("link/")` returns an empty value on macOS even when `link`
  # itself is a symbolic link. Strip only trailing directory separators so we
  # inspect the caller's package-root entry without rejecting harmless
  # symlinks elsewhere in the absolute path (for example /var -> /private/var).
  lexical <- path.expand(as.character(path))
  lexical <- sub("[/\\\\]+$", "", lexical, perl = TRUE)
  if (!nzchar(lexical)) {
    lexical <- .Platform$file.sep
  } else if (grepl("^[A-Za-z]:$", lexical)) {
    lexical <- paste0(lexical, "/")
  }
  target <- Sys.readlink(lexical)
  !is.na(target) && nzchar(target)
}

.ms_sdp_extension_assert_safe_directory <- function(root, relative_directory,
                                                     create = FALSE) {
  parts <- strsplit(relative_directory, "/", fixed = TRUE)[[1]]
  current <- root
  for (part in parts) {
    current <- file.path(current, part)
    if (.ms_sdp_extension_is_symlink(current)) {
      .ms_sdp_extension_abort(
        "Refusing an SDP metadata path that traverses symlink {.file {current}}."
      )
    }
    if (file.exists(current) && !dir.exists(current)) {
      .ms_sdp_extension_abort(
        "Expected SDP metadata directory but found a file at {.file {current}}."
      )
    }
    if (!dir.exists(current) && isTRUE(create)) {
      if (!dir.create(current, showWarnings = FALSE)) {
        .ms_sdp_extension_abort(
          "Could not create SDP metadata directory {.file {current}}."
        )
      }
    }
    if (dir.exists(current)) {
      normalized <- normalizePath(current, winslash = "/", mustWork = TRUE)
      if (!identical(normalized, root) &&
          !startsWith(normalized, paste0(root, "/"))) {
        .ms_sdp_extension_abort(
          "SDP metadata directory resolves outside the package root and is unsafe."
        )
      }
    }
  }
  invisible(current)
}

.ms_sdp_extension_assert_safe_file <- function(root, relative_path,
                                                must_exist = TRUE) {
  directory <- dirname(relative_path)
  .ms_sdp_extension_assert_safe_directory(
    root,
    directory,
    create = FALSE
  )
  path <- file.path(root, relative_path)
  if (.ms_sdp_extension_is_symlink(path)) {
    .ms_sdp_extension_abort(
      "Refusing SDP metadata symlink {.file {path}}."
    )
  }
  if (isTRUE(must_exist) && (!file.exists(path) || dir.exists(path))) {
    .ms_sdp_extension_abort(
      "Missing SDP metadata file {.file {relative_path}}."
    )
  }
  if (file.exists(path)) {
    normalized <- normalizePath(path, winslash = "/", mustWork = TRUE)
    if (!startsWith(normalized, paste0(root, "/"))) {
      .ms_sdp_extension_abort(
        "SDP metadata file resolves outside the package root and is unsafe."
      )
    }
  }
  path
}

.ms_sdp_extension_atomic_write_set <- function(writes, validate = NULL) {
  if (!is.list(writes) || length(writes) == 0L ||
      is.null(names(writes)) || any(!nzchar(names(writes))) ||
      anyDuplicated(names(writes))) {
    .ms_sdp_extension_abort(
      "Atomic SDP metadata writes require a named, non-empty set of files."
    )
  }
  if (!is.null(validate) && !is.function(validate)) {
    .ms_sdp_extension_abort("{.arg validate} must be a function or NULL.")
  }

  paths <- names(writes)
  stages <- backups <- rep(NA_character_, length(paths))
  installed <- rep(FALSE, length(paths))
  original_exists <- file.exists(paths)
  names(stages) <- names(backups) <- names(installed) <- paths

  cleanup <- function() {
    unlink(c(stages, backups)[!is.na(c(stages, backups))])
  }
  on.exit(cleanup(), add = TRUE)

  # Prepare every replacement before moving any current file out of the way.
  # A malformed descriptor, unwritable directory, or serialization error thus
  # cannot leave a partial methods/structure extension behind.
  for (index in seq_along(paths)) {
    path <- paths[[index]]
    if (!is.raw(writes[[index]])) {
      .ms_sdp_extension_abort(
        "Atomic SDP metadata content for {.file {path}} must be raw bytes."
      )
    }
    if (!dir.exists(dirname(path))) {
      .ms_sdp_extension_abort(
        "Atomic SDP metadata directory {.file {dirname(path)}} does not exist."
      )
    }
    if (.ms_sdp_extension_is_symlink(path)) {
      .ms_sdp_extension_abort(
        "Refusing to atomically replace SDP metadata symlink {.file {path}}."
      )
    }
    if (file.exists(path) && dir.exists(path)) {
      .ms_sdp_extension_abort(
        "Expected SDP metadata file but found a directory at {.file {path}}."
      )
    }
    stages[[index]] <- tempfile(
      pattern = paste0(".", basename(path), "-stage-"),
      tmpdir = dirname(path)
    )
    tryCatch(
      writeBin(writes[[index]], stages[[index]]),
      error = function(error) {
        .ms_sdp_extension_abort(
          "Could not stage SDP metadata file {.file {path}}: {conditionMessage(error)}"
        )
      }
    )
  }

  rollback <- function() {
    for (index in rev(seq_along(paths))) {
      path <- paths[[index]]
      if (isTRUE(installed[[index]]) && file.exists(path)) {
        unlink(path)
      }
      backup <- backups[[index]]
      if (!is.na(backup) && file.exists(backup)) {
        if (file.exists(path)) {
          unlink(path)
        }
        if (!file.rename(backup, path)) {
          warning(
            sprintf("Could not restore SDP metadata backup for '%s'.", path),
            call. = FALSE
          )
        }
      }
    }
  }

  tryCatch(
    {
      for (index in seq_along(paths)) {
        path <- paths[[index]]
        if (isTRUE(original_exists[[index]])) {
          backups[[index]] <- tempfile(
            pattern = paste0(".", basename(path), "-backup-"),
            tmpdir = dirname(path)
          )
          if (!file.rename(path, backups[[index]])) {
            .ms_sdp_extension_abort(
              "Could not preserve existing SDP metadata file {.file {path}}."
            )
          }
        }
        if (!file.rename(stages[[index]], path)) {
          .ms_sdp_extension_abort(
            "Could not atomically install SDP metadata file {.file {path}}."
          )
        }
        installed[[index]] <- TRUE
        stages[[index]] <- NA_character_
      }
      if (!is.null(validate)) {
        validate()
      }
    },
    error = function(error) {
      rollback()
      stop(error)
    }
  )

  unlink(backups[!is.na(backups)])
  backups[] <- NA_character_
  invisible(paths)
}

.ms_sdp_extension_atomic_write <- function(bytes, path) {
  writes <- list(bytes)
  names(writes) <- path
  .ms_sdp_extension_atomic_write_set(writes)
  invisible(path)
}

.ms_sdp_extension_csv_bytes <- function(rows) {
  temporary <- tempfile(fileext = ".csv")
  on.exit(unlink(temporary), add = TRUE)
  readr::write_csv(rows, temporary, na = "")
  readBin(temporary, what = "raw", n = file.info(temporary)$size)
}

.ms_sdp_extension_json_bytes <- function(value) {
  json <- jsonlite::toJSON(
    value,
    auto_unbox = TRUE,
    pretty = TRUE,
    null = "null",
    na = "null",
    digits = NA
  )
  charToRaw(enc2utf8(paste0(json, "\n")))
}

.ms_sdp_extension_read_csv <- function(root, relative_path, columns,
                                       column_types) {
  path <- .ms_sdp_extension_assert_safe_file(root, relative_path)
  rows <- tryCatch(
    readr::read_csv(
      path,
      col_types = column_types,
      na = "",
      trim_ws = FALSE,
      show_col_types = FALSE,
      progress = FALSE
    ),
    error = function(error) {
      .ms_sdp_extension_abort(
        "Could not parse {.file {relative_path}}: {conditionMessage(error)}"
      )
    }
  )
  rows <- tibble::as_tibble(rows)
  if (!identical(names(rows), columns)) {
    .ms_sdp_extension_abort(c(
      "{.file {relative_path}} does not have the exact SDP schema.",
      "x" = "Expected columns, in order: {.field {columns}}.",
      "x" = "Found columns: {.field {names(rows)}}."
    ))
  }
  rows
}

.ms_sdp_extension_validate_closed_rows <- function(rows, columns, label) {
  if (!inherits(rows, "data.frame")) {
    .ms_sdp_extension_abort("{.arg {label}} must be a data frame.")
  }
  missing <- setdiff(columns, names(rows))
  extra <- setdiff(names(rows), columns)
  if (length(missing) > 0L || length(extra) > 0L) {
    .ms_sdp_extension_abort(c(
      "{.arg {label}} must match the exact SDP schema.",
      "x" = if (length(missing) > 0L) "Missing: {.field {missing}}." else NULL,
      "x" = if (length(extra) > 0L) "Unexpected: {.field {extra}}." else NULL
    ))
  }
  tibble::as_tibble(rows[, columns, drop = FALSE])
}

.ms_sdp_extension_dataset_id <- function(root) {
  dataset_path <- .ms_sdp_extension_assert_safe_file(
    root,
    "metadata/dataset.csv"
  )
  dataset <- .ms_read_metadata_csv(dataset_path)
  if (!"dataset_id" %in% names(dataset) || nrow(dataset) != 1L ||
      .ms_sdp_extension_is_blank(dataset$dataset_id[[1]])) {
    .ms_sdp_extension_abort(
      "{.file metadata/dataset.csv} must contain one non-empty {.field dataset_id}."
    )
  }
  as.character(dataset$dataset_id[[1]])
}

.ms_sdp_extension_resource <- function(name, path, title, description,
                                       schema_file) {
  list(
    profile = "tabular-data-resource",
    name = name,
    path = path,
    title = title,
    description = description,
    schema = .ms_sdp_metadata_resource_schema(name, schema_file)
  )
}

.ms_sdp_extension_descriptor_bytes <- function(root, resources, metadata) {
  descriptor_path <- file.path(root, "datapackage.json")
  if (.ms_sdp_extension_is_symlink(descriptor_path)) {
    .ms_sdp_extension_abort(
      "Refusing to replace symlinked {.file datapackage.json}."
    )
  }
  if (!file.exists(descriptor_path)) {
    return(NULL)
  }
  descriptor <- tryCatch(
    jsonlite::read_json(descriptor_path, simplifyVector = FALSE),
    error = function(error) {
      .ms_sdp_extension_abort(
        "Could not parse {.file datapackage.json}: {conditionMessage(error)}"
      )
    }
  )
  existing <- descriptor$resources %||% list()
  managed_names <- purrr::map_chr(resources, ~ .x$name)
  managed_paths <- purrr::map_chr(resources, ~ .x$path)
  existing <- purrr::keep(existing, function(resource) {
    !(resource$name %||% "") %in% managed_names &&
      !(resource$path %||% "") %in% managed_paths
  })
  descriptor$resources <- c(existing, resources)
  descriptor$sdp <- descriptor$sdp %||% list()
  descriptor$sdp$metadata <- descriptor$sdp$metadata %||% list()
  for (field in names(metadata)) {
    descriptor$sdp$metadata[[field]] <- metadata[[field]]
  }
  .ms_sdp_extension_json_bytes(descriptor)
}

.ms_sdp_extension_validate_descriptor_resource <- function(descriptor,
                                                            expected) {
  resources <- descriptor$resources %||% list()
  matches <- purrr::keep(resources, function(resource) {
    identical(resource$path %||% NULL, expected$path)
  })
  if (length(matches) != 1L) {
    .ms_sdp_extension_abort(
      "{.file datapackage.json} must declare exactly one resource for {.file {expected$path}}."
    )
  }
  actual <- matches[[1]]
  for (field in c("name", "path", "profile", "schema")) {
    if (!identical(actual[[field]] %||% NULL, expected[[field]])) {
      .ms_sdp_extension_abort(
        "{.file datapackage.json} resource {.file {expected$path}} field {.field {field}} must be {.val {expected[[field]]}}."
      )
    }
  }
  invisible(TRUE)
}
