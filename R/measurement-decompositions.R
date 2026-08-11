# Ordered SDP measurement-decomposition artifacts -------------------------
#
# The SDP dictionary keeps one interoperable value per semantic slot. A
# compound measurement can need more detail than those frozen columns permit,
# including repeated constraints and explicit vocabulary gaps. This module
# stores that detail in a separate, manifest-bound artifact. Its roles are
# informed by I-ADOPT, but the artifact does not claim native I-ADOPT
# conformance and is not an SSSOM mapping set.

.ms_sdp_decomposition_schema_version <- "1.0"
.ms_sdp_decomposition_csv_path <-
  "metadata/semantic/measurement-decompositions.csv"
.ms_sdp_decomposition_manifest_path <-
  "metadata/semantic/measurement-decompositions.json"

.ms_sdp_decomposition_columns <- c(
  "dataset_id",
  "table_id",
  "column_name",
  "measurement_concept_iri",
  "component_order",
  "component_role",
  "component_status",
  "component_relation",
  "related_component_order",
  "component_iri",
  "component_label",
  "rationale",
  "source",
  "source_version",
  "source_url",
  "provenance"
)

.ms_sdp_decomposition_abort <- function(message, ..., .envir = parent.frame()) {
  cli::cli_abort(message, ..., .envir = .envir)
}

.ms_sdp_decomposition_root <- function(path) {
  if (length(path) != 1L || is.na(path) || !nzchar(path) || !dir.exists(path)) {
    .ms_sdp_decomposition_abort(
      "{.arg path} must name one existing Salmon Data Package directory."
    )
  }
  normalizePath(path, winslash = "/", mustWork = TRUE)
}

.ms_sdp_decomposition_paths <- function(root) {
  list(
    csv = file.path(root, .ms_sdp_decomposition_csv_path),
    manifest = file.path(root, .ms_sdp_decomposition_manifest_path)
  )
}

.ms_sdp_decomposition_is_absolute_iri <- function(value) {
  grepl(
    "^(?:[A-Za-z][A-Za-z0-9+.-]*://|urn:)[^[:space:]]+$",
    value,
    perl = TRUE
  )
}

.ms_sdp_decomposition_validate_row_states <- function(rows) {
  allowed_roles <- c("property", "entity", "constraint", "method", "unit")
  if (any(!rows$component_role %in% allowed_roles)) {
    .ms_sdp_decomposition_abort(
      paste0(
        "{.field component_role} must be one of: ",
        paste(allowed_roles, collapse = ", "),
        "."
      )
    )
  }
  if (any(!rows$component_status %in% c("matched", "gap"))) {
    .ms_sdp_decomposition_abort(
      "{.field component_status} must be {.val matched} or {.val gap}."
    )
  }

  matched <- rows$component_status == "matched"
  matched_iris <- trimws(rows$component_iri[matched])
  if (any(!.ms_sdp_decomposition_is_absolute_iri(matched_iris))) {
    .ms_sdp_decomposition_abort(
      "Every matched component must have an absolute {.field component_iri} IRI."
    )
  }

  gap <- rows$component_status == "gap"
  if (any(nzchar(trimws(rows$component_iri[gap])))) {
    .ms_sdp_decomposition_abort(
      "Every gap row must have a blank {.field component_iri}."
    )
  }
  if (any(!nzchar(trimws(rows$component_label[gap])))) {
    .ms_sdp_decomposition_abort(
      "Every gap row must have a non-empty {.field component_label}."
    )
  }
  if (any(!nzchar(trimws(rows$rationale[gap])))) {
    .ms_sdp_decomposition_abort(
      "Every gap row must have a non-empty {.field rationale}."
    )
  }

  for (field in c("source", "source_version", "provenance")) {
    if (any(!nzchar(trimws(rows[[field]])))) {
      .ms_sdp_decomposition_abort(
        "Decomposition field {.field {field}} must be non-empty on every row."
      )
    }
  }
  if (any(!.ms_sdp_decomposition_is_absolute_iri(trimws(rows$source_url)))) {
    .ms_sdp_decomposition_abort(
      "Every {.field source_url} must be an absolute IRI."
    )
  }

  invisible(TRUE)
}

.ms_sdp_decomposition_validate_order_and_uniqueness <- function(rows) {
  measurement_fields <- c(
    "dataset_id",
    "table_id",
    "column_name",
    "measurement_concept_iri"
  )
  measurements <- unique(rows[, measurement_fields, drop = FALSE])
  for (measurement_index in seq_len(nrow(measurements))) {
    measurement <- measurements[measurement_index, , drop = FALSE]
    indices <- which(Reduce(
      `&`,
      lapply(
        measurement_fields,
        function(field) rows[[field]] == measurement[[field]][[1]]
      )
    ))
    order <- rows$component_order[indices]
    if (anyDuplicated(order)) {
      .ms_sdp_decomposition_abort(
        "{.field component_order} must be unique within each bound measurement."
      )
    }
    if (!identical(sort(order), seq_along(order))) {
      .ms_sdp_decomposition_abort(
        "{.field component_order} must be contiguous from 1 within each bound measurement."
      )
    }
  }

  semantic_identity <- data.frame(
    rows[, measurement_fields, drop = FALSE],
    component_role = rows$component_role,
    component_status = rows$component_status,
    component_value = ifelse(
      rows$component_status == "matched",
      rows$component_iri,
      rows$component_label
    ),
    source = rows$source,
    source_version = rows$source_version,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  if (anyDuplicated(semantic_identity)) {
    .ms_sdp_decomposition_abort(
      "Duplicate semantic component found within one bound measurement."
    )
  }

  invisible(TRUE)
}

.ms_sdp_decomposition_validate_relations <- function(rows) {
  has_relation <- nzchar(trimws(rows$component_relation))
  has_target <- !is.na(rows$related_component_order)
  if (any(xor(has_relation, has_target))) {
    .ms_sdp_decomposition_abort(
      paste0(
        "{.field component_relation} and {.field related_component_order} ",
        "must either both be populated or both be blank together."
      )
    )
  }
  if (any(has_relation & rows$component_relation != "value_of_dimension")) {
    .ms_sdp_decomposition_abort(
      "{.field component_relation} currently supports only {.val value_of_dimension}."
    )
  }

  relation_rows <- which(has_relation)
  binding_fields <- c(
    "dataset_id",
    "table_id",
    "column_name",
    "measurement_concept_iri"
  )
  for (row_index in relation_rows) {
    related_order <- rows$related_component_order[[row_index]]
    if (related_order >= rows$component_order[[row_index]]) {
      .ms_sdp_decomposition_abort(
        "A component relation must target an earlier component in the same measurement."
      )
    }
    same_measurement <- Reduce(
      `&`,
      lapply(
        binding_fields,
        function(field) rows[[field]] == rows[[field]][[row_index]]
      )
    )
    target_index <- which(
      same_measurement & rows$component_order == related_order
    )
    if (length(target_index) != 1L) {
      .ms_sdp_decomposition_abort(
        "A component relation must target an earlier component in the same measurement."
      )
    }
    if (!identical(rows$component_status[[row_index]], "matched") ||
        !identical(rows$component_role[[row_index]], "constraint") ||
        !identical(rows$component_status[[target_index]], "matched") ||
        !identical(rows$component_role[[target_index]], "constraint")) {
      .ms_sdp_decomposition_abort(
        "{.val value_of_dimension} must connect two matched constraint components."
      )
    }
  }

  invisible(TRUE)
}

.ms_sdp_decomposition_dictionary <- function(root) {
  dictionary_path <- .ms_locate_metadata_file(
    root,
    "column_dictionary.csv"
  )
  if (is.na(dictionary_path) || !file.exists(dictionary_path)) {
    .ms_sdp_decomposition_abort(
      "The SDP does not contain {.file metadata/column_dictionary.csv}."
    )
  }
  dictionary <- .ms_read_metadata_csv(dictionary_path)
  .ms_normalize_dictionary(dictionary)
}

.ms_sdp_decomposition_dictionary_values <- function(value, field) {
  if (length(value) == 0L || is.na(value) || !nzchar(trimws(value))) {
    return(character())
  }
  value <- as.character(value)
  if (identical(field, "constraint_iri")) {
    value <- strsplit(value, ";", fixed = TRUE)[[1]]
  }
  value <- trimws(value)
  value[nzchar(value)]
}

.ms_sdp_decomposition_validate_dictionary <- function(root, rows) {
  binding_fields <- c("dataset_id", "table_id", "column_name")
  if (any(vapply(
    binding_fields,
    function(field) any(!nzchar(trimws(rows[[field]]))),
    logical(1)
  ))) {
    .ms_sdp_decomposition_abort(
      paste0(
        "Decomposition binding fields must be non-empty: ",
        paste(binding_fields, collapse = ", "),
        "."
      )
    )
  }
  if (any(!.ms_sdp_decomposition_is_absolute_iri(
    trimws(rows$measurement_concept_iri)
  ))) {
    .ms_sdp_decomposition_abort(
      "{.field measurement_concept_iri} must be an absolute IRI."
    )
  }

  dictionary <- .ms_sdp_decomposition_dictionary(root)
  bindings <- unique(rows[, c(binding_fields, "measurement_concept_iri")])
  slot_roles <- c(
    property_iri = "property",
    entity_iri = "entity",
    constraint_iri = "constraint",
    method_iri = "method",
    unit_iri = "unit"
  )

  for (binding_index in seq_len(nrow(bindings))) {
    binding <- bindings[binding_index, , drop = FALSE]
    dictionary_indices <- which(
      as.character(dictionary$dataset_id) == binding$dataset_id &
        as.character(dictionary$table_id) == binding$table_id &
        as.character(dictionary$column_name) == binding$column_name
    )
    if (length(dictionary_indices) == 0L) {
      .ms_sdp_decomposition_abort(
        paste0(
          "The bound measurement ",
          .ms_cli_escape(paste(
            binding$dataset_id, binding$table_id, binding$column_name,
            sep = "/"
          )),
          " does not exist in the SDP dictionary."
        )
      )
    }
    if (length(dictionary_indices) > 1L) {
      .ms_sdp_decomposition_abort(
        "The SDP dictionary contains an ambiguous duplicate bound measurement."
      )
    }
    dictionary_row <- dictionary[dictionary_indices, , drop = FALSE]
    if (!identical(as.character(dictionary_row$column_role[[1]]), "measurement")) {
      .ms_sdp_decomposition_abort(
        "The bound dictionary row has {.field column_role} other than {.val measurement}."
      )
    }

    dictionary_term <- as.character(dictionary_row$term_iri[[1]])
    if (is.na(dictionary_term)) {
      dictionary_term <- ""
    }
    if (!identical(dictionary_term, binding$measurement_concept_iri[[1]])) {
      .ms_sdp_decomposition_abort(
        "{.field measurement_concept_iri} must equal the bound dictionary {.field term_iri}."
      )
    }

    row_indices <- which(
      rows$dataset_id == binding$dataset_id &
        rows$table_id == binding$table_id &
        rows$column_name == binding$column_name &
        rows$measurement_concept_iri == binding$measurement_concept_iri
    )
    matched <- rows[row_indices, , drop = FALSE]
    matched <- matched[matched$component_status == "matched", , drop = FALSE]

    for (field in names(slot_roles)) {
      dictionary_values <- .ms_sdp_decomposition_dictionary_values(
        dictionary_row[[field]][[1]],
        field
      )
      if (length(dictionary_values) == 0L) {
        next
      }
      role <- unname(slot_roles[[field]])
      matched_values <- matched$component_iri[
        matched$component_role == role
      ]
      missing_values <- setdiff(dictionary_values, matched_values)
      if (length(missing_values) > 0L) {
        .ms_sdp_decomposition_abort(
          paste0(
            "Dictionary ",
            .ms_cli_escape(field),
            " value must appear as a matched ",
            .ms_cli_escape(role),
            " component: ",
            .ms_cli_escape(paste(missing_values, collapse = ", ")),
            "."
          )
        )
      }
    }
  }

  invisible(TRUE)
}

.ms_sdp_decomposition_normalize_rows <- function(decompositions) {
  if (!is.data.frame(decompositions) || nrow(decompositions) == 0L) {
    .ms_sdp_decomposition_abort(
      "{.arg decompositions} must be a non-empty data frame."
    )
  }

  missing_columns <- setdiff(
    .ms_sdp_decomposition_columns,
    names(decompositions)
  )
  unknown_columns <- setdiff(
    names(decompositions),
    .ms_sdp_decomposition_columns
  )
  if (length(missing_columns) > 0L || length(unknown_columns) > 0L) {
    details <- c()
    # Column names come from the caller's data frame, so they reach cli as
    # external text and must be escaped.
    if (length(missing_columns) > 0L) {
      details <- c(
        details,
        "x" = paste0("Missing columns: ", .ms_cli_escape(paste(missing_columns, collapse = ", ")), ".")
      )
    }
    if (length(unknown_columns) > 0L) {
      details <- c(
        details,
        "x" = paste0("Unknown columns: ", .ms_cli_escape(paste(unknown_columns, collapse = ", ")), ".")
      )
    }
    .ms_sdp_decomposition_abort(c(
      "{.arg decompositions} does not match the ordered SDP decomposition schema.",
      details
    ))
  }

  rows <- tibble::as_tibble(
    decompositions[, .ms_sdp_decomposition_columns, drop = FALSE]
  )
  numeric_columns <- c("component_order", "related_component_order")
  character_columns <- setdiff(
    .ms_sdp_decomposition_columns,
    numeric_columns
  )
  for (column in character_columns) {
    if (!is.atomic(rows[[column]])) {
      .ms_sdp_decomposition_abort(
        "Decomposition column {.field {column}} must be an atomic vector."
      )
    }
    value <- as.character(rows[[column]])
    value[is.na(value)] <- ""
    rows[[column]] <- enc2utf8(value)
  }

  order_text <- trimws(as.character(rows$component_order))
  component_order <- suppressWarnings(as.integer(order_text))
  if (any(
    is.na(component_order) |
      component_order < 1L |
      order_text != as.character(component_order)
  )) {
    .ms_sdp_decomposition_abort(
      "{.field component_order} must contain positive whole numbers."
    )
  }
  rows$component_order <- component_order

  related_text <- trimws(as.character(rows$related_component_order))
  related_missing <- is.na(rows$related_component_order) | !nzchar(related_text)
  related_component_order <- rep(NA_integer_, nrow(rows))
  related_component_order[!related_missing] <- suppressWarnings(as.integer(
    related_text[!related_missing]
  ))
  if (any(
    !related_missing &
      (
        is.na(related_component_order) |
          related_component_order < 1L |
          related_text != as.character(related_component_order)
      )
  )) {
    .ms_sdp_decomposition_abort(
      "{.field related_component_order} must be blank or a positive whole number."
    )
  }
  rows$related_component_order <- related_component_order

  .ms_sdp_decomposition_validate_row_states(rows)
  .ms_sdp_decomposition_validate_order_and_uniqueness(rows)
  .ms_sdp_decomposition_validate_relations(rows)

  rows |>
    dplyr::arrange(
      .data$dataset_id,
      .data$table_id,
      .data$column_name,
      .data$measurement_concept_iri,
      .data$component_order,
      .locale = "C"
    )
}

.ms_sdp_decomposition_csv_bytes <- function(rows) {
  text <- readr::format_csv(rows, na = "")
  charToRaw(enc2utf8(text))
}

.ms_sdp_decomposition_package_version <- function() {
  tryCatch(
    as.character(utils::packageVersion("metasalmon")),
    error = function(...) "development"
  )
}

.ms_sdp_decomposition_manifest <- function(bytes, row_count) {
  list(
    schema_version = .ms_sdp_decomposition_schema_version,
    artifact = list(
      path = .ms_sdp_decomposition_csv_path,
      sha256 = digest::digest(bytes, algo = "sha256", serialize = FALSE),
      row_count = as.integer(row_count)
    ),
    provenance = list(
      generated_by = "metasalmon::write_sdp_measurement_decompositions",
      metasalmon_version = .ms_sdp_decomposition_package_version(),
      semantic_profile = paste(
        "Ordered SDP semantic profile with I-ADOPT-informed roles;",
        "not native I-ADOPT conformance."
      )
    )
  )
}

.ms_sdp_decomposition_json_bytes <- function(manifest) {
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

.ms_sdp_decomposition_atomic_write <- function(bytes, path) {
  temporary <- tempfile(
    pattern = paste0(".", basename(path), "-"),
    tmpdir = dirname(path)
  )
  on.exit(unlink(temporary), add = TRUE)
  writeBin(bytes, temporary)
  if (!file.rename(temporary, path)) {
    .ms_sdp_decomposition_abort("Could not atomically write {.file {path}}.")
  }
  invisible(path)
}

.ms_sdp_decomposition_assert_output_directory <- function(root, directory) {
  if (nzchar(Sys.readlink(directory))) {
    .ms_sdp_decomposition_abort(
      "Refusing to write measurement decompositions through a semantic-directory symlink."
    )
  }
  normalized <- normalizePath(directory, winslash = "/", mustWork = TRUE)
  if (!identical(normalized, root) &&
      !startsWith(normalized, paste0(root, "/"))) {
    .ms_sdp_decomposition_abort(
      "Measurement-decomposition output directory resolves outside the SDP and is unsafe."
    )
  }
  invisible(normalized)
}

.ms_sdp_decomposition_read_raw <- function(path, label) {
  if (!file.exists(path) || dir.exists(path)) {
    .ms_sdp_decomposition_abort("Missing {label} at {.file {path}}.")
  }
  size <- file.info(path)$size
  readBin(path, what = "raw", n = size)
}

.ms_sdp_decomposition_text_from_bytes <- function(bytes, label) {
  bom <- as.raw(c(0xef, 0xbb, 0xbf))
  if (length(bytes) >= 3L && identical(bytes[seq_len(3L)], bom)) {
    .ms_sdp_decomposition_abort("{label} must not contain a UTF-8 BOM.")
  }
  if (any(bytes == as.raw(0x0d))) {
    .ms_sdp_decomposition_abort(
      "{label} must use LF line endings without carriage returns."
    )
  }
  if (length(bytes) == 0L || !identical(utils::tail(bytes, 1L), as.raw(0x0a))) {
    .ms_sdp_decomposition_abort("{label} must end with a final LF newline.")
  }
  text <- rawToChar(bytes)
  if (!validUTF8(text)) {
    .ms_sdp_decomposition_abort("{label} must contain valid UTF-8 text.")
  }
  text
}

.ms_sdp_decomposition_read_manifest <- function(path) {
  bytes <- .ms_sdp_decomposition_read_raw(path, "decomposition manifest")
  text <- .ms_sdp_decomposition_text_from_bytes(
    bytes,
    "Measurement-decomposition manifest"
  )
  manifest <- tryCatch(
    jsonlite::fromJSON(text, simplifyVector = FALSE),
    error = function(error) {
      .ms_sdp_decomposition_abort(
        "Measurement-decomposition manifest is not valid JSON: {conditionMessage(error)}"
      )
    }
  )
  manifest
}

.ms_sdp_decomposition_read_csv <- function(path) {
  bytes <- .ms_sdp_decomposition_read_raw(path, "measurement decompositions")
  text <- .ms_sdp_decomposition_text_from_bytes(
    bytes,
    "Measurement-decomposition CSV"
  )
  rows <- tryCatch(
    readr::read_csv(
      I(text),
      col_types = readr::cols(.default = readr::col_character()),
      na = character(),
      trim_ws = FALSE,
      show_col_types = FALSE,
      progress = FALSE
    ),
    error = function(error) {
      .ms_sdp_decomposition_abort(
        "Measurement-decomposition CSV could not be parsed: {conditionMessage(error)}"
      )
    }
  )
  list(
    bytes = bytes,
    rows = .ms_sdp_decomposition_normalize_rows(rows)
  )
}

.ms_sdp_decomposition_validate_manifest <- function(manifest, bytes, rows) {
  if (!is.list(manifest) ||
      !all(c("schema_version", "artifact", "provenance") %in% names(manifest))) {
    .ms_sdp_decomposition_abort(
      "Measurement-decomposition manifest is missing required fields."
    )
  }
  if (!identical(
    manifest$schema_version,
    .ms_sdp_decomposition_schema_version
  )) {
    .ms_sdp_decomposition_abort(
      "Measurement-decomposition manifest has an unsupported schema version."
    )
  }
  if (!is.list(manifest$artifact) ||
      !all(c("path", "sha256", "row_count") %in% names(manifest$artifact)) ||
      !identical(manifest$artifact$path, .ms_sdp_decomposition_csv_path)) {
    .ms_sdp_decomposition_abort(
      "Measurement-decomposition manifest artifact binding is incomplete or unsafe."
    )
  }

  row_count <- manifest$artifact$row_count
  if (!is.numeric(row_count) ||
      length(row_count) != 1L ||
      is.na(row_count) ||
      row_count < 0 ||
      row_count != as.integer(row_count)) {
    .ms_sdp_decomposition_abort(
      "Manifest {.field artifact.row_count} must be one non-negative whole number."
    )
  }

  actual_sha256 <- digest::digest(bytes, algo = "sha256", serialize = FALSE)
  if (!is.character(manifest$artifact$sha256) ||
      length(manifest$artifact$sha256) != 1L ||
      !grepl("^[0-9a-f]{64}$", manifest$artifact$sha256) ||
      !identical(manifest$artifact$sha256, actual_sha256)) {
    .ms_sdp_decomposition_abort(
      "Measurement-decomposition CSV does not match its manifest SHA-256 hash."
    )
  }
  if (!identical(as.integer(row_count), nrow(rows))) {
    .ms_sdp_decomposition_abort(
      "Measurement-decomposition CSV does not match its manifest row count."
    )
  }
  if (!is.list(manifest$provenance) ||
      !identical(
        manifest$provenance$generated_by,
        "metasalmon::write_sdp_measurement_decompositions"
      ) ||
      !is.character(manifest$provenance$metasalmon_version) ||
      length(manifest$provenance$metasalmon_version) != 1L ||
      is.na(manifest$provenance$metasalmon_version) ||
      !nzchar(trimws(manifest$provenance$metasalmon_version)) ||
      !is.character(manifest$provenance$semantic_profile) ||
      length(manifest$provenance$semantic_profile) != 1L ||
      is.na(manifest$provenance$semantic_profile) ||
      !nzchar(trimws(manifest$provenance$semantic_profile))) {
    .ms_sdp_decomposition_abort(
      "Measurement-decomposition manifest writer provenance is incomplete."
    )
  }
  invisible(TRUE)
}

#' Read ordered measurement decompositions from a Salmon Data Package
#'
#' Reads the manifest-bound decomposition artifact that preserves repeated
#' semantic components and explicit gaps beyond the frozen SDP dictionary
#' columns. The profile uses I-ADOPT-informed roles, but does not claim native
#' I-ADOPT conformance and is separate from SSSOM vocabulary mappings.
#'
#' @param path Existing Salmon Data Package directory.
#' @param validate Logical; when `TRUE`, validate the exact-byte manifest
#'   binding and the decomposition rows against the package dictionary. A
#'   `FALSE` read still requires the closed row schema, valid row states,
#'   deterministic order, UTF-8, LF endings, and no BOM.
#'
#' @return A tibble in canonical component order. The parsed manifest is
#'   attached as the `manifest` attribute.
#' @export
read_sdp_measurement_decompositions <- function(path, validate = TRUE) {
  root <- .ms_sdp_decomposition_root(path)
  paths <- .ms_sdp_decomposition_paths(root)
  semantic_directory <- dirname(paths$csv)
  if (dir.exists(semantic_directory)) {
    .ms_sdp_decomposition_assert_output_directory(root, semantic_directory)
  }
  managed_paths <- unlist(paths, use.names = FALSE)
  symlinks <- managed_paths[
    file.exists(managed_paths) & nzchar(Sys.readlink(managed_paths))
  ]
  if (length(symlinks) > 0L) {
    .ms_sdp_decomposition_abort(
      "Refusing to read measurement-decomposition symlinks: {.file {symlinks}}."
    )
  }
  manifest <- .ms_sdp_decomposition_read_manifest(paths$manifest)
  artifact <- .ms_sdp_decomposition_read_csv(paths$csv)

  if (length(validate) != 1L || is.na(validate)) {
    .ms_sdp_decomposition_abort("{.arg validate} must be TRUE or FALSE.")
  }
  if (isTRUE(validate)) {
    .ms_sdp_decomposition_validate_manifest(
      manifest,
      artifact$bytes,
      artifact$rows
    )
    .ms_sdp_decomposition_validate_dictionary(root, artifact$rows)
  }
  attr(artifact$rows, "manifest") <- manifest
  artifact$rows
}

#' Validate ordered SDP measurement-decomposition artifacts
#'
#' @param path Existing Salmon Data Package directory.
#'
#' @return `TRUE`, invisibly, when validation succeeds; otherwise an error.
#' @export
validate_sdp_measurement_decompositions <- function(path) {
  read_sdp_measurement_decompositions(path, validate = TRUE)
  invisible(TRUE)
}

#' Write ordered measurement decompositions into a Salmon Data Package
#'
#' Writes explicit decomposition rows to
#' `metadata/semantic/measurement-decompositions.csv` and binds the exact
#' deterministic bytes to `measurement-decompositions.json`. The writer never
#' infers components, splits labels, or converts decompositions into SSSOM
#' mappings. Supplying `decompositions = NULL` is an explicit no-op.
#'
#' Each row has the following closed schema:
#'
#' - `dataset_id`, `table_id`, and `column_name` bind the decomposition to one
#'   measurement row in `metadata/column_dictionary.csv`.
#' - `measurement_concept_iri` must exactly equal that dictionary row's
#'   `term_iri`.
#' - `component_order` is a positive, contiguous, per-measurement sequence.
#' - `component_role` is one of `property`, `entity`, `constraint`, `method`, or
#'   `unit`; repeated roles are allowed.
#' - `component_status` is `matched` or `gap`. A matched row requires an
#'   absolute `component_iri`. A gap requires a blank `component_iri` plus a
#'   non-empty `component_label` and `rationale`.
#' - `component_relation` and `related_component_order` are normally blank.
#'   `value_of_dimension` links a matched constraint value to an earlier
#'   matched constraint dimension in the same measurement; for example, an
#'   age-1 class can target its freshwater-age dimension without flattening the
#'   two constraints.
#' - `source`, `source_version`, `source_url`, and `provenance` identify the
#'   pinned source and review evidence. `component_label` and `rationale`
#'   preserve caller-supplied text; they are never tokenized or inferred.
#'
#' Every non-empty dictionary `property_iri`, `entity_iri`, `constraint_iri`,
#' `method_iri`, and `unit_iri` must appear as a matched component of the same
#' role. Semicolon-separated dictionary constraints are checked separately.
#' Additional same-role components and explicit gaps stay only in this
#' artifact, leaving the frozen SDP dictionary columns unchanged. This is an
#' ordered SDP semantic profile informed by I-ADOPT roles, not a claim of
#' native I-ADOPT conformance.
#'
#' @param path Existing Salmon Data Package directory.
#' @param decompositions `NULL` or a non-empty data frame matching the ordered
#'   measurement-decomposition schema.
#' @param overwrite Logical; replace artifacts managed by this writer when
#'   `TRUE`.
#'
#' @return The manifest path, invisibly, or `NULL` when `decompositions` is
#'   `NULL`.
#' @export
write_sdp_measurement_decompositions <- function(path,
                                                 decompositions = NULL,
                                                 overwrite = FALSE) {
  if (is.null(decompositions)) {
    return(invisible(NULL))
  }
  root <- .ms_sdp_decomposition_root(path)
  if (length(overwrite) != 1L || is.na(overwrite)) {
    .ms_sdp_decomposition_abort("{.arg overwrite} must be TRUE or FALSE.")
  }

  rows <- .ms_sdp_decomposition_normalize_rows(decompositions)
  .ms_sdp_decomposition_validate_dictionary(root, rows)
  csv_bytes <- .ms_sdp_decomposition_csv_bytes(rows)
  manifest <- .ms_sdp_decomposition_manifest(csv_bytes, nrow(rows))
  manifest_bytes <- .ms_sdp_decomposition_json_bytes(manifest)
  paths <- .ms_sdp_decomposition_paths(root)
  existing <- unlist(paths, use.names = FALSE)
  existing <- existing[file.exists(existing)]
  if (length(existing) > 0L && !isTRUE(overwrite)) {
    .ms_sdp_decomposition_abort(c(
      "Measurement-decomposition output already exists and {.arg overwrite} is FALSE.",
      "i" = "Existing: {.file {existing}}."
    ))
  }
  symlinks <- existing[nzchar(Sys.readlink(existing))]
  if (length(symlinks) > 0L) {
    .ms_sdp_decomposition_abort(
      "Refusing to overwrite measurement-decomposition symlinks: {.file {symlinks}}."
    )
  }

  dir.create(dirname(paths$csv), recursive = TRUE, showWarnings = FALSE)
  .ms_sdp_decomposition_assert_output_directory(root, dirname(paths$csv))
  .ms_sdp_decomposition_atomic_write(csv_bytes, paths$csv)
  .ms_sdp_decomposition_atomic_write(manifest_bytes, paths$manifest)

  # Re-open the exact bytes written to disk before reporting success.
  validate_sdp_measurement_decompositions(root)
  invisible(paths$manifest)
}
