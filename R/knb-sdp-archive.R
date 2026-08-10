# Deterministic SDP archive -------------------------------------------------
#
# KNB presents every aggregated DataONE object as an individual catalog item.
# Publishing the canonical SDP's internal metadata files one at a time is
# therefore both noisy and easy to misinterpret.  This module builds one
# reproducible ZIP representation of the SDP from a deliberately closed
# inventory.  It reuses the KNB publication allowlists instead of scanning the
# package directory, so EML, publication receipts, editor backups, and other
# local material cannot be swept into the archive by accident.

# Reviewed `zip` implementations, in the sense that each was byte-compared
# against the others for metasalmon's exact `zip::zip()` call before being added
# here. 3.0.1 and 3.0.2 produce identical archives for a fixture covering nested
# paths, non-ASCII filenames, an empty file, incompressible bytes, and highly
# compressible bytes.
#
# This is an allowlist rather than a single version because the archive
# checksum is bound into KNB object identifiers: an unreviewed `zip` must fail
# loudly rather than silently change published bytes. It is checked HERE, at the
# KNB boundary, and not in DESCRIPTION — pinning the dependency made the whole
# package uninstallable for the majority of users who never publish to KNB.
.ms_knb_reviewed_zip_versions <- c("3.0.1", "3.0.2")

.ms_knb_require_zip_version <- function(
    version = as.character(utils::packageVersion("zip"))) {
  version <- as.character(version)
  if (length(version) != 1L ||
      is.na(version) ||
      !version %in% .ms_knb_reviewed_zip_versions) {
    observed <- if (length(version) == 1L && !is.na(version)) {
      version
    } else {
      "an invalid version"
    }
    rlang::abort(paste0(
      "Deterministic SDP ZIP construction requires a reviewed zip version (",
      paste(.ms_knb_reviewed_zip_versions, collapse = ", "),
      "); found ",
      observed,
      ". Byte-compare the new version against a reviewed one before adding it ",
      "to `.ms_knb_reviewed_zip_versions`."
    ))
  }
  invisible(version)
}

.ms_knb_sdp_archive_filename <- function(dataset_id) {
  if (length(dataset_id) != 1L ||
      is.na(dataset_id) ||
      !nzchar(trimws(as.character(dataset_id)))) {
    cli::cli_abort(
      "{.arg dataset_id} must be one non-empty value for the SDP archive filename."
    )
  }

  paste0(
    .ms_safe_path_slug(dataset_id),
    "-salmon-data-package.zip"
  )
}

.ms_knb_sdp_archive_dataset_id <- function(path) {
  dataset_path <- .ms_locate_metadata_file(path, "dataset.csv")
  if (is.na(dataset_path)) {
    cli::cli_abort(
      "SDP archiving requires canonical {.file metadata/dataset.csv}."
    )
  }

  dataset <- .ms_read_metadata_csv(dataset_path)
  if (nrow(dataset) != 1L || !"dataset_id" %in% names(dataset)) {
    cli::cli_abort(
      "SDP archiving requires one {.field dataset.csv$dataset_id} value."
    )
  }
  dataset_id <- as.character(dataset$dataset_id[[1]])
  if (is.na(dataset_id) || !nzchar(trimws(dataset_id))) {
    cli::cli_abort(
      "SDP archiving requires one non-empty {.field dataset.csv$dataset_id} value."
    )
  }
  dataset_id
}

.ms_knb_sdp_archive_relative_labels <- function(paths, prefix) {
  labels <- names(paths)
  expected_prefix <- paste0(prefix, ":")
  if (is.null(labels) || any(!startsWith(labels, expected_prefix))) {
    cli::cli_abort(
      "Internal SDP archive inventory labels are invalid."
    )
  }

  substring(labels, nchar(expected_prefix) + 1L)
}

.ms_knb_sdp_archive_path <- function(root, relative) {
  do.call(
    file.path,
    as.list(c(root, strsplit(relative, "/", fixed = TRUE)[[1]]))
  )
}

.ms_knb_sdp_archive_assert_no_symlink <- function(root,
                                                   relative,
                                                   require_file = TRUE) {
  parts <- strsplit(relative, "/", fixed = TRUE)[[1]]
  current <- root
  for (part in parts) {
    current <- file.path(current, part)
    link <- Sys.readlink(current)
    if (length(link) == 1L && !is.na(link) && nzchar(link)) {
      cli::cli_abort(
        "SDP archive member {.file {relative}} must not contain a symbolic-link path component."
      )
    }
    if (!file.exists(current)) {
      break
    }
  }

  if (isTRUE(require_file) &&
      (!file.exists(current) ||
        isTRUE(file.info(current)$isdir) ||
        !utils::file_test("-f", current))) {
    cli::cli_abort(
      "SDP archive member {.file {relative}} must be a regular file."
    )
  }

  invisible(TRUE)
}

.ms_knb_sdp_archive_validate_relative <- function(relative) {
  relative <- gsub("\\", "/", as.character(relative), fixed = TRUE)
  if (length(relative) != 1L ||
      is.na(relative) ||
      !nzchar(relative) ||
      startsWith(relative, "/") ||
      grepl("^[A-Za-z]:/", relative) ||
      endsWith(relative, "/") ||
      grepl("//", relative, fixed = TRUE)) {
    cli::cli_abort(
      "SDP archive member path {.val {relative}} is not a canonical relative file path."
    )
  }
  .ms_knb_reject_dot_segments(relative, "SDP archive inventory")

  # EML describes the archive and publication/ contains the archive itself plus
  # mutable upload receipts.  Neither can be an archive member without making
  # the bundle self-referential or dependent on publication state.
  if (identical(relative, "metadata/eml.xml") ||
      startsWith(relative, "publication/")) {
    cli::cli_abort(
      "SDP archive inventory cannot include reserved publication path {.file {relative}}."
    )
  }

  relative
}

.ms_knb_sdp_archive_inventory <- function(path) {
  root <- .ms_knb_package_root(path)

  # These two helpers are the single source of truth for the KNB package
  # inventory.  In particular, the artifact helper validates any declared
  # SSSOM and ordered measurement-decomposition manifests before returning
  # their closed member lists.
  data_paths <- .ms_knb_declared_data_paths(root)
  artifact_paths <- .ms_knb_sdp_artifact_paths(root)
  paths <- c(data_paths, artifact_paths)
  relative <- c(
    .ms_knb_sdp_archive_relative_labels(data_paths, "data"),
    .ms_knb_sdp_archive_relative_labels(artifact_paths, "sdp_artifact")
  )
  relative <- vapply(
    relative,
    .ms_knb_sdp_archive_validate_relative,
    character(1)
  )

  if (anyDuplicated(relative)) {
    duplicated_members <- unique(relative[
      duplicated(relative) | duplicated(relative, fromLast = TRUE)
    ])
    cli::cli_abort(
      "SDP archive inventory contains duplicate member path{?s}: {.file {duplicated_members}}."
    )
  }

  for (index in seq_along(relative)) {
    member <- relative[[index]]
    .ms_knb_sdp_archive_assert_no_symlink(root, member)
    lexical_path <- .ms_knb_sdp_archive_path(root, member)
    resolved <- normalizePath(lexical_path, mustWork = TRUE)
    if (!identical(resolved, unname(paths[[index]])) ||
        !identical(.ms_knb_relative_path(root, resolved), member)) {
      cli::cli_abort(
        "SDP archive member {.file {member}} does not resolve to its canonical package path."
      )
    }
  }

  ordering <- order(relative, method = "radix")
  stats::setNames(unname(paths[ordering]), relative[ordering])
}

.ms_knb_sdp_archive_set_reproducible_metadata <- function(staging,
                                                           members) {
  member_paths <- vapply(
    members,
    function(member) .ms_knb_sdp_archive_path(staging, member),
    character(1)
  )
  directories <- unique(c(
    staging,
    unlist(lapply(member_paths, function(member) {
      current <- dirname(member)
      found <- character()
      while (!identical(current, staging)) {
        found <- c(current, found)
        current <- dirname(current)
      }
      found
    }), use.names = FALSE)
  ))

  # ZIP uses the member mtime and Unix permission bits.  Reset both after
  # copying so source mtimes, umasks, owners, and temporary roots cannot affect
  # the resulting archive bytes.  ZIP's DOS timestamp range starts in 1980;
  # 2000 is deliberately unambiguous and comfortably portable.
  Sys.chmod(directories, mode = "0755", use_umask = FALSE)
  Sys.chmod(member_paths, mode = "0644", use_umask = FALSE)
  fixed_time <- as.POSIXct("2000-01-01 00:00:00", tz = "UTC")
  Sys.setFileTime(c(directories, member_paths), fixed_time)
  invisible(TRUE)
}

.ms_knb_sdp_archive_stage <- function(inventory, staging) {
  if (!dir.create(staging, recursive = TRUE, showWarnings = FALSE) &&
      !dir.exists(staging)) {
    cli::cli_abort("Could not create the temporary SDP archive staging directory.")
  }

  for (member in names(inventory)) {
    source <- unname(inventory[[member]])
    destination <- .ms_knb_sdp_archive_path(staging, member)
    dir.create(dirname(destination), recursive = TRUE, showWarnings = FALSE)
    copied <- file.copy(
      source,
      destination,
      overwrite = FALSE,
      copy.mode = FALSE,
      copy.date = FALSE
    )
    if (!isTRUE(copied) ||
        !identical(
          digest::digest(file = source, algo = "sha256", serialize = FALSE),
          digest::digest(file = destination, algo = "sha256", serialize = FALSE)
        )) {
      cli::cli_abort(
        "Could not stage exact bytes for SDP archive member {.file {member}}."
      )
    }
  }

  # Validate the copied bytes too.  This closes the small gap between checking
  # a source manifest and asking the ZIP implementation to read its artifacts.
  if (file.exists(file.path(
    staging,
    "metadata",
    "semantic",
    "mapping-sets.json"
  ))) {
    validate_sdp_sssom(staging)
  }
  if (file.exists(file.path(
    staging,
    "metadata",
    "semantic",
    "measurement-decompositions.json"
  ))) {
    validate_sdp_measurement_decompositions(staging)
  }

  .ms_knb_sdp_archive_set_reproducible_metadata(
    staging,
    names(inventory)
  )
  invisible(staging)
}

.ms_knb_sdp_archive_descriptor <- function(path,
                                            dataset_id,
                                            members,
                                            bytes = NULL) {
  if (is.null(bytes)) {
    bytes <- .ms_knb_object_bytes(path)
  }
  list(
    path = normalizePath(path, mustWork = TRUE),
    file_name = basename(path),
    dataset_id = dataset_id,
    format_id = "application/zip",
    media_type = "application/zip",
    size = as.numeric(length(bytes)),
    sha256 = .ms_knb_sha256_raw(bytes),
    members = members
  )
}

.ms_knb_write_sdp_archive <- function(path,
                                      output_path = NULL,
                                      overwrite = FALSE) {
  if (length(overwrite) != 1L ||
      !is.logical(overwrite) ||
      is.na(overwrite)) {
    cli::cli_abort("{.arg overwrite} must be TRUE or FALSE.")
  }

  # `zip` 2.x and 3.x can serialize the same staged tree into different bytes.
  # KNB object identifiers and resumable manifests bind the archive checksum,
  # so a dependency upgrade must be reviewed as an explicit package change.
  .ms_knb_require_zip_version()

  inventory <- .ms_knb_sdp_archive_inventory(path)
  root <- normalizePath(path, mustWork = TRUE)
  dataset_id <- .ms_knb_sdp_archive_dataset_id(root)
  if (is.null(output_path)) {
    output_path <- file.path(
      root,
      "publication",
      .ms_knb_sdp_archive_filename(dataset_id)
    )
  }
  if (length(output_path) != 1L ||
      is.na(output_path) ||
      !nzchar(trimws(as.character(output_path)))) {
    cli::cli_abort("{.arg output_path} must be one non-empty path.")
  }
  if (!identical(tolower(tools::file_ext(output_path)), "zip")) {
    cli::cli_abort("{.arg output_path} must use a {.file .zip} extension.")
  }

  lexical_output <- .ms_knb_lexical_absolute_path(output_path)
  root_prefix <- paste0(root, .Platform$file.sep)
  if (startsWith(lexical_output, root_prefix)) {
    lexical_relative <- gsub(
      "\\",
      "/",
      substring(lexical_output, nchar(root_prefix) + 1L),
      fixed = TRUE
    )
    .ms_knb_sdp_archive_assert_no_symlink(
      root,
      lexical_relative,
      require_file = FALSE
    )
  }
  output_path <- .ms_knb_inside_path(
    root,
    lexical_output,
    must_work = file.exists(lexical_output)
  )
  output_relative <- .ms_knb_relative_path(
    root,
    output_path,
    must_work = file.exists(output_path)
  )
  if (!startsWith(output_relative, "publication/")) {
    cli::cli_abort(
      "{.arg output_path} must remain under the SDP's {.file publication/} directory."
    )
  }
  .ms_knb_sdp_archive_assert_no_symlink(
    root,
    output_relative,
    require_file = FALSE
  )

  directory <- dirname(output_path)
  if (!dir.create(directory, recursive = TRUE, showWarnings = FALSE) &&
      !dir.exists(directory)) {
    cli::cli_abort(
      "Could not create SDP archive output directory {.path {directory}}."
    )
  }
  .ms_knb_sdp_archive_assert_no_symlink(
    root,
    dirname(output_relative),
    require_file = FALSE
  )

  staging <- tempfile(pattern = ".metasalmon-sdp-archive-")
  on.exit(unlink(staging, recursive = TRUE, force = TRUE), add = TRUE)
  .ms_knb_sdp_archive_stage(inventory, staging)

  temporary_archive <- tempfile(
    pattern = ".metasalmon-sdp-archive-",
    tmpdir = directory,
    fileext = ".zip"
  )
  on.exit(unlink(temporary_archive, force = TRUE), add = TRUE)

  old_tz <- Sys.getenv("TZ", unset = NA_character_)
  on.exit({
    if (is.na(old_tz)) {
      Sys.unsetenv("TZ")
    } else {
      Sys.setenv(TZ = old_tz)
    }
  }, add = TRUE)
  Sys.setenv(TZ = "UTC")

  tryCatch(
    zip::zip(
      zipfile = temporary_archive,
      files = names(inventory),
      recurse = FALSE,
      compression_level = 9L,
      include_directories = FALSE,
      root = staging,
      mode = "mirror"
    ),
    error = function(error) {
      cli::cli_abort(
        "Could not create the deterministic SDP ZIP archive: {conditionMessage(error)}"
      )
    }
  )
  if (!file.exists(temporary_archive)) {
    cli::cli_abort("The ZIP implementation did not create the SDP archive.")
  }

  archived_members <- as.character(zip::zip_list(temporary_archive)$filename)
  if (!identical(archived_members, names(inventory))) {
    cli::cli_abort(
      "Generated SDP archive inventory does not exactly match its closed source allowlist."
    )
  }
  archive_bytes <- .ms_knb_object_bytes(temporary_archive)

  if (file.exists(output_path)) {
    existing_link <- Sys.readlink(output_path)
    if (length(existing_link) == 1L &&
        !is.na(existing_link) &&
        nzchar(existing_link)) {
      cli::cli_abort("Refusing to replace symbolic-link SDP archive output.")
    }
    existing_bytes <- .ms_knb_object_bytes(output_path)
    if (identical(existing_bytes, archive_bytes)) {
      return(.ms_knb_sdp_archive_descriptor(
        output_path,
        dataset_id,
        names(inventory),
        bytes = existing_bytes
      ))
    }
    if (!isTRUE(overwrite)) {
      cli::cli_abort(c(
        "SDP archive output already exists with different bytes and {.arg overwrite} is FALSE.",
        "i" = "Review the existing publication artifact before replacing it."
      ))
    }
  }

  .ms_knb_atomic_write_raw(archive_bytes, output_path)
  .ms_knb_sdp_archive_descriptor(
    output_path,
    dataset_id,
    names(inventory),
    bytes = archive_bytes
  )
}
