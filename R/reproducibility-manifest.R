# Closed SDP reproducibility manifests ------------------------------------
#
# Reproducibility material can contain scripts, provenance records, reviewed
# decisions, and a description of source inputs. These files are deliberately
# outside the tabular SDP core. This manifest gives publication adapters a
# closed, checksum-bound inventory so they never need to publish everything
# they happen to find in a directory.

.ms_sdp_reproducibility_profile <-
  "metasalmon-reproducibility-manifest/1.0"
.ms_sdp_reproducibility_path <- "reproducibility/manifest.json"
.ms_sdp_reproducibility_roles <- c(
  "reviewed_semantic_selections",
  "workflow",
  "provenance",
  "source"
)

.ms_sdp_reproducibility_abort <- function(message, ...,
                                           .envir = parent.frame()) {
  cli::cli_abort(message, ..., .envir = .envir)
}

.ms_sdp_reproducibility_root <- function(path) {
  if (length(path) != 1L || is.na(path) || !nzchar(path) || !dir.exists(path)) {
    .ms_sdp_reproducibility_abort(
      "{.arg path} must name one existing Salmon Data Package directory."
    )
  }
  if (.ms_sdp_extension_is_symlink(path)) {
    .ms_sdp_reproducibility_abort(
      "{.arg path} must not be a symlink; refusing an unsafe SDP root."
    )
  }
  normalizePath(path, winslash = "/", mustWork = TRUE)
}

.ms_sdp_reproducibility_safe_path <- function(path) {
  if (length(path) != 1L || is.na(path) || !nzchar(path) ||
      grepl("\\\\", path) || startsWith(path, "/")) {
    return(FALSE)
  }
  parts <- strsplit(path, "/", fixed = TRUE)[[1]]
  length(parts) >= 2L &&
    identical(parts[[1]], "reproducibility") &&
    !any(parts %in% c("", ".", "..")) &&
    !identical(path, .ms_sdp_reproducibility_path)
}

.ms_sdp_reproducibility_expected_role <- function(path) {
  if (identical(
    path,
    "reproducibility/reviewed_semantic_selections.csv"
  )) {
    return("reviewed_semantic_selections")
  }
  for (role in c("workflow", "provenance", "source")) {
    if (startsWith(path, paste0("reproducibility/", role, "/"))) {
      return(role)
    }
  }
  NA_character_
}

.ms_sdp_reproducibility_assert_not_symlinked <- function(root, path) {
  relative <- substring(path, nchar(root) + 2L)
  parts <- strsplit(relative, "/", fixed = TRUE)[[1]]
  candidates <- file.path(
    root,
    vapply(
      seq_along(parts),
      function(index) paste(parts[seq_len(index)], collapse = "/"),
      character(1)
    )
  )
  links <- candidates[nzchar(Sys.readlink(candidates))]
  if (length(links) > 0L) {
    .ms_sdp_reproducibility_abort(
      "Reproducibility artifacts cannot be reached through a symlink: {.file {links}}."
    )
  }
  invisible(path)
}

.ms_sdp_reproducibility_resolve <- function(root, relative) {
  if (!.ms_sdp_reproducibility_safe_path(relative)) {
    .ms_sdp_reproducibility_abort(
      "Reproducibility path {.val {relative}} is not a safe package-relative path."
    )
  }
  candidate <- file.path(root, relative)
  if (!file.exists(candidate) || dir.exists(candidate)) {
    .ms_sdp_reproducibility_abort(
      "Reproducibility artifact {.file {candidate}} is missing or is not a regular file."
    )
  }
  .ms_sdp_reproducibility_assert_not_symlinked(root, candidate)
  resolved <- normalizePath(candidate, winslash = "/", mustWork = TRUE)
  if (!startsWith(resolved, paste0(root, "/"))) {
    .ms_sdp_reproducibility_abort(
      "Reproducibility artifact {.file {candidate}} resolves outside the SDP and is unsafe."
    )
  }
  resolved
}

.ms_sdp_reproducibility_normalize_declarations <- function(root, artifacts) {
  if (!is.data.frame(artifacts) || nrow(artifacts) == 0L) {
    .ms_sdp_reproducibility_abort(
      "{.arg artifacts} must be a non-empty data frame of explicit declarations."
    )
  }
  required <- c("path", "role", "media_type")
  if (!identical(names(artifacts), required)) {
    .ms_sdp_reproducibility_abort(
      "{.arg artifacts} must have exactly the columns {.field {required}} in that order."
    )
  }
  declarations <- tibble::as_tibble(artifacts)
  for (field in required) {
    declarations[[field]] <- as.character(declarations[[field]])
    if (any(is.na(declarations[[field]]) |
            !nzchar(trimws(declarations[[field]])))) {
      .ms_sdp_reproducibility_abort(
        "Reproducibility declaration {.field {field}} must be non-empty."
      )
    }
    declarations[[field]] <- trimws(declarations[[field]])
  }
  if (anyDuplicated(declarations$path)) {
    .ms_sdp_reproducibility_abort(
      "Reproducibility declarations contain duplicate {.field path} values."
    )
  }
  if (any(!declarations$role %in% .ms_sdp_reproducibility_roles)) {
    .ms_sdp_reproducibility_abort(
      "Reproducibility {.field role} must be one of {.val {.ms_sdp_reproducibility_roles}}."
    )
  }
  if (any(!grepl(
    "^[A-Za-z0-9!#$&^_.+-]+/[A-Za-z0-9!#$&^_.+-]+$",
    declarations$media_type
  ))) {
    .ms_sdp_reproducibility_abort(
      "Every reproducibility {.field media_type} must be a valid media type."
    )
  }

  expected_roles <- vapply(
    declarations$path,
    .ms_sdp_reproducibility_expected_role,
    character(1)
  )
  if (any(is.na(expected_roles)) ||
      any(declarations$role != expected_roles)) {
    .ms_sdp_reproducibility_abort(
      "Each reproducibility {.field role} must match its canonical path location."
    )
  }

  resolved <- vapply(
    declarations$path,
    function(relative) .ms_sdp_reproducibility_resolve(root, relative),
    character(1)
  )
  declarations$resolved_path <- unname(resolved)
  declarations |>
    dplyr::arrange(.data$path)
}

.ms_sdp_reproducibility_file_entry <- function(declaration) {
  bytes <- readBin(
    declaration$resolved_path,
    what = "raw",
    n = file.info(declaration$resolved_path)$size
  )
  list(
    path = declaration$path,
    role = declaration$role,
    media_type = declaration$media_type,
    sha256 = digest::digest(bytes, algo = "sha256", serialize = FALSE),
    size_bytes = as.numeric(length(bytes))
  )
}

.ms_sdp_reproducibility_manifest_bytes <- function(entries) {
  package_version <- tryCatch(
    as.character(utils::packageVersion("metasalmon")),
    error = function(...) "development"
  )
  manifest <- list(
    profile = .ms_sdp_reproducibility_profile,
    artifacts = unname(entries),
    provenance = list(
      generated_by = "metasalmon::write_sdp_reproducibility_manifest",
      metasalmon_version = package_version
    )
  )
  json <- jsonlite::toJSON(
    manifest,
    auto_unbox = TRUE,
    pretty = TRUE,
    null = "null",
    na = "null",
    digits = NA
  )
  charToRaw(enc2utf8(paste0(json, "\n")))
}

.ms_sdp_reproducibility_atomic_write <- function(bytes, path) {
  temporary <- tempfile(
    pattern = paste0(".", basename(path), "-"),
    tmpdir = dirname(path)
  )
  on.exit(unlink(temporary), add = TRUE)
  writeBin(bytes, temporary)
  if (!file.rename(temporary, path)) {
    .ms_sdp_reproducibility_abort(
      "Could not atomically write reproducibility manifest {.file {path}}."
    )
  }
  invisible(path)
}

.ms_sdp_reproducibility_read_bytes <- function(path) {
  if (!file.exists(path) || dir.exists(path)) {
    .ms_sdp_reproducibility_abort(
      "Missing reproducibility manifest at {.file {path}}."
    )
  }
  if (nzchar(Sys.readlink(path))) {
    .ms_sdp_reproducibility_abort(
      "Refusing to read a reproducibility-manifest symlink."
    )
  }
  bytes <- readBin(path, what = "raw", n = file.info(path)$size)
  if (length(bytes) == 0L ||
      !identical(utils::tail(bytes, 1L), as.raw(0x0a)) ||
      any(bytes == as.raw(0x0d))) {
    .ms_sdp_reproducibility_abort(
      "Reproducibility manifest must use UTF-8, LF endings, and a final newline."
    )
  }
  text <- rawToChar(bytes)
  if (!validUTF8(text)) {
    .ms_sdp_reproducibility_abort(
      "Reproducibility manifest must contain valid UTF-8."
    )
  }
  text
}

.ms_sdp_reproducibility_all_files <- function(root) {
  directory <- file.path(root, "reproducibility")
  if (!dir.exists(directory) || nzchar(Sys.readlink(directory))) {
    .ms_sdp_reproducibility_abort(
      "The SDP must contain a real {.file reproducibility} directory."
    )
  }
  entries <- list.files(
    directory,
    all.files = TRUE,
    full.names = TRUE,
    recursive = TRUE,
    include.dirs = TRUE,
    no.. = TRUE
  )
  links <- entries[nzchar(Sys.readlink(entries))]
  if (length(links) > 0L) {
    .ms_sdp_reproducibility_abort(
      "Reproducibility trees cannot contain symlinks: {.file {links}}."
    )
  }
  files <- entries[file.exists(entries) & !dir.exists(entries)]
  prefix <- paste0(root, "/")
  relative <- substring(
    normalizePath(files, winslash = "/", mustWork = TRUE),
    nchar(prefix) + 1L
  )
  sort(setdiff(relative, .ms_sdp_reproducibility_path))
}

.ms_sdp_reproducibility_validate_manifest <- function(root, manifest) {
  if (!is.list(manifest) ||
      !identical(names(manifest), c("profile", "artifacts", "provenance")) ||
      !identical(manifest$profile, .ms_sdp_reproducibility_profile) ||
      !is.list(manifest$artifacts) || length(manifest$artifacts) == 0L) {
    .ms_sdp_reproducibility_abort(
      "Reproducibility manifest has an unsupported profile or incomplete fields."
    )
  }
  if (!is.list(manifest$provenance) ||
      !identical(
        manifest$provenance$generated_by,
        "metasalmon::write_sdp_reproducibility_manifest"
      ) ||
      length(manifest$provenance$metasalmon_version) != 1L ||
      !nzchar(as.character(manifest$provenance$metasalmon_version))) {
    .ms_sdp_reproducibility_abort(
      "Reproducibility manifest writer provenance is incomplete."
    )
  }

  paths <- character(length(manifest$artifacts))
  for (index in seq_along(manifest$artifacts)) {
    entry <- manifest$artifacts[[index]]
    required <- c("path", "role", "media_type", "sha256", "size_bytes")
    if (!is.list(entry) || !identical(names(entry), required)) {
      .ms_sdp_reproducibility_abort(
        "Reproducibility manifest artifact entry {index} is incomplete."
      )
    }
    declaration <- tibble::tibble(
      path = as.character(entry$path),
      role = as.character(entry$role),
      media_type = as.character(entry$media_type)
    )
    normalized <- .ms_sdp_reproducibility_normalize_declarations(
      root,
      declaration
    )
    path <- normalized$resolved_path[[1]]
    bytes <- readBin(path, what = "raw", n = file.info(path)$size)
    actual_hash <- digest::digest(
      bytes,
      algo = "sha256",
      serialize = FALSE
    )
    size <- entry$size_bytes
    if (!is.character(entry$sha256) || length(entry$sha256) != 1L ||
        !grepl("^[0-9a-f]{64}$", entry$sha256) ||
        !identical(entry$sha256, actual_hash)) {
      .ms_sdp_reproducibility_abort(
        "Reproducibility artifact {.file {entry$path}} does not match its manifest SHA-256."
      )
    }
    if (!is.numeric(size) || length(size) != 1L || is.na(size) || size < 0 ||
        !identical(as.numeric(size), as.numeric(length(bytes)))) {
      .ms_sdp_reproducibility_abort(
        "Reproducibility artifact {.file {entry$path}} does not match its manifest size."
      )
    }
    paths[[index]] <- entry$path
  }
  if (anyDuplicated(paths) || !identical(paths, sort(paths))) {
    .ms_sdp_reproducibility_abort(
      "Reproducibility manifest paths must be unique and sorted."
    )
  }
  discovered <- .ms_sdp_reproducibility_all_files(root)
  if (!identical(paths, discovered)) {
    .ms_sdp_reproducibility_abort(c(
      "Reproducibility manifest must be closed over the exact directory contents.",
      "i" = "No undeclared or missing reproducibility artifacts are allowed."
    ))
  }
  invisible(TRUE)
}

#' Write a closed reproducibility manifest into a Salmon Data Package
#'
#' Binds an explicit inventory of reviewed semantic selections, workflow
#' records, provenance, and source records to exact paths, media types, byte
#' sizes, and SHA-256 hashes in `reproducibility/manifest.json`. The writer does
#' not discover files. Validation requires the declarations to be closed over
#' the actual reproducibility tree, which prevents accidental publication of
#' local notes or editor backups.
#'
#' @param path Existing Salmon Data Package directory.
#' @param artifacts Non-empty data frame with exactly `path`, `role`, and
#'   `media_type` columns. Paths are package-relative. Roles are
#'   `reviewed_semantic_selections`, `workflow`, `provenance`, or `source` and
#'   must agree with the canonical directory layout.
#' @param overwrite Logical; replace an existing managed manifest when `TRUE`.
#'
#' @return The manifest path, invisibly.
#' @export
write_sdp_reproducibility_manifest <- function(path, artifacts,
                                                overwrite = FALSE) {
  root <- .ms_sdp_reproducibility_root(path)
  if (length(overwrite) != 1L || is.na(overwrite)) {
    .ms_sdp_reproducibility_abort(
      "{.arg overwrite} must be TRUE or FALSE."
    )
  }
  declarations <- .ms_sdp_reproducibility_normalize_declarations(
    root,
    artifacts
  )
  entries <- lapply(
    seq_len(nrow(declarations)),
    function(index) {
      .ms_sdp_reproducibility_file_entry(as.list(declarations[index, ]))
    }
  )
  manifest_path <- file.path(root, .ms_sdp_reproducibility_path)
  if (file.exists(manifest_path) && !isTRUE(overwrite)) {
    .ms_sdp_reproducibility_abort(c(
      "Reproducibility manifest already exists and {.arg overwrite} is FALSE.",
      "i" = "Existing: {.file {manifest_path}}."
    ))
  }
  manifest_link <- Sys.readlink(manifest_path)
  if (!is.na(manifest_link) && nzchar(manifest_link)) {
    .ms_sdp_reproducibility_abort(
      "Refusing to overwrite a reproducibility-manifest symlink."
    )
  }
  directory <- dirname(manifest_path)
  if (!dir.exists(directory)) {
    dir.create(directory, recursive = TRUE, showWarnings = FALSE)
  }
  .ms_sdp_reproducibility_assert_not_symlinked(root, directory)
  manifest_bytes <- .ms_sdp_reproducibility_manifest_bytes(entries)
  candidate <- jsonlite::fromJSON(
    rawToChar(manifest_bytes),
    simplifyVector = FALSE
  )
  # Validate the complete candidate against the current tree before replacing
  # a valid recovery record. In particular, an incomplete overwrite must not
  # leave the package with a newly invalid manifest.
  .ms_sdp_reproducibility_validate_manifest(root, candidate)
  .ms_sdp_reproducibility_atomic_write(manifest_bytes, manifest_path)
  validate_sdp_reproducibility_manifest(root)
  invisible(manifest_path)
}

#' Read an SDP reproducibility manifest
#'
#' @param path Existing Salmon Data Package directory.
#' @param validate Logical; validate paths, roles, checksums, sizes, symlinks,
#'   provenance, deterministic ordering, and exact directory closure.
#'
#' @return The parsed manifest as a list.
#' @export
read_sdp_reproducibility_manifest <- function(path, validate = TRUE) {
  root <- .ms_sdp_reproducibility_root(path)
  if (length(validate) != 1L || is.na(validate)) {
    .ms_sdp_reproducibility_abort(
      "{.arg validate} must be TRUE or FALSE."
    )
  }
  manifest_path <- file.path(root, .ms_sdp_reproducibility_path)
  text <- .ms_sdp_reproducibility_read_bytes(manifest_path)
  manifest <- tryCatch(
    jsonlite::fromJSON(text, simplifyVector = FALSE),
    error = function(error) {
      .ms_sdp_reproducibility_abort(
        "Reproducibility manifest is not valid JSON: {conditionMessage(error)}"
      )
    }
  )
  if (isTRUE(validate)) {
    .ms_sdp_reproducibility_validate_manifest(root, manifest)
  }
  manifest
}

#' Validate an SDP reproducibility manifest
#'
#' @param path Existing Salmon Data Package directory.
#'
#' @return `TRUE`, invisibly, when validation succeeds; otherwise an error.
#' @export
validate_sdp_reproducibility_manifest <- function(path) {
  read_sdp_reproducibility_manifest(path, validate = TRUE)
  invisible(TRUE)
}
