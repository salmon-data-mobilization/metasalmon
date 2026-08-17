# SSSOM mapping-set support -------------------------------------------------
#
# A Salmon Data Package may carry reviewed vocabulary alignments, but those
# alignments are not another representation of its variable decompositions.
# This module therefore implements a deliberately small, strict SSSOM 1.1
# profile: approved mapping sets go in; no mappings are inferred from semantic
# suggestions, dictionary literals, or component columns.

.ms_sssom_version <- "1.1"
.ms_sssom_manifest_version <- "1.0"

.ms_sssom_required_metadata <- c(
  "sssom_version",
  "mapping_set_id",
  "mapping_set_version",
  "license",
  "subject_source",
  "subject_source_version",
  "object_source",
  "object_source_version",
  "curie_map"
)

.ms_sssom_metadata_order <- c(
  "sssom_version",
  "mapping_set_id",
  "mapping_set_version",
  "mapping_set_source",
  "mapping_set_title",
  "mapping_set_description",
  "mapping_set_confidence",
  "creator_id",
  "creator_label",
  "license",
  "subject_type",
  "subject_source",
  "subject_source_version",
  "object_type",
  "object_source",
  "object_source_version",
  "predicate_type",
  "mapping_provider",
  "cardinality_scope",
  "mapping_tool",
  "mapping_tool_id",
  "mapping_tool_version",
  "mapping_date",
  "publication_date",
  "subject_match_field",
  "object_match_field",
  "subject_preprocessing",
  "object_preprocessing",
  "similarity_measure",
  "curation_rule",
  "curation_rule_text",
  "see_also",
  "issue_tracker",
  "other",
  "comment",
  "curie_map"
)

# These are the mapping slots in the SSSOM 1.1 model. Rejecting unknown table
# columns is intentional: an extension field called, for example,
# `component_id` must not turn a mapping table into an undocumented
# decomposition table.
.ms_sssom_mapping_columns <- c(
  "record_id",
  "subject_id",
  "subject_label",
  "subject_category",
  "predicate_id",
  "predicate_label",
  "predicate_modifier",
  "object_id",
  "object_label",
  "object_category",
  "mapping_justification",
  "author_id",
  "author_label",
  "reviewer_id",
  "reviewer_label",
  "creator_id",
  "creator_label",
  "license",
  "subject_type",
  "subject_source",
  "subject_source_version",
  "object_type",
  "object_source",
  "object_source_version",
  "predicate_type",
  "mapping_provider",
  "mapping_source",
  "mapping_cardinality",
  "cardinality_scope",
  "mapping_tool",
  "mapping_tool_id",
  "mapping_tool_version",
  "mapping_date",
  "publication_date",
  "review_date",
  "confidence",
  "reviewer_agreement",
  "curation_rule",
  "curation_rule_text",
  "subject_match_field",
  "object_match_field",
  "match_string",
  "subject_preprocessing",
  "object_preprocessing",
  "similarity_score",
  "similarity_measure",
  "see_also",
  "issue_tracker_item",
  "other",
  "comment"
)

.ms_sssom_column_order <- c(
  "record_id",
  "subject_id",
  "subject_label",
  "subject_category",
  "predicate_id",
  "predicate_label",
  "predicate_modifier",
  "object_id",
  "object_label",
  "object_category",
  "mapping_justification",
  setdiff(
    .ms_sssom_mapping_columns,
    c(
      "record_id", "subject_id", "subject_label", "subject_category",
      "predicate_id", "predicate_label", "predicate_modifier", "object_id",
      "object_label", "object_category", "mapping_justification"
    )
  )
)

.ms_sssom_required_columns <- c(
  "subject_id",
  "predicate_id",
  "object_id",
  "mapping_justification"
)

.ms_sssom_justifications <- paste0(
  "semapv:",
  c(
    "MappingReview",
    "ManualMappingCuration",
    "LogicalReasoning",
    "LexicalMatching",
    "CompositeMatching",
    "UnspecifiedMatching",
    "SemanticSimilarityThresholdMatching",
    "LexicalSimilarityThresholdMatching",
    "MappingChaining",
    "MappingInversion",
    "StructuralMatching",
    "InstanceBasedMatching",
    "BackgroundKnowledgeBasedMatching"
  )
)

.ms_sssom_cardinalities <- c("1:1", "1:n", "n:1", "n:n", "1:0", "0:1", "0:0")

.ms_sssom_abort <- function(message, ..., .envir = parent.frame()) {
  cli::cli_abort(message, ..., .envir = .envir)
}

.ms_sssom_scalar <- function(value, name) {
  if (is.null(value) || length(value) != 1L || is.na(value[[1]])) {
    .ms_sssom_abort(
      "SSSOM metadata field {.field {name}} must contain one non-empty value."
    )
  }
  value <- trimws(as.character(value[[1]]))
  if (!nzchar(value)) {
    .ms_sssom_abort(
      "SSSOM metadata field {.field {name}} must contain one non-empty value."
    )
  }
  value
}

.ms_sssom_read_bytes <- function(path, label = "SSSOM mapping set") {
  if (!file.exists(path) || dir.exists(path)) {
    .ms_sssom_abort("{label} does not exist at {.file {path}}.")
  }

  size <- file.info(path)$size
  bytes <- readBin(path, what = "raw", n = size)
  if (length(bytes) == 0L) {
    .ms_sssom_abort("{label} at {.file {path}} is empty.")
  }
  if (length(bytes) >= 3L && identical(
    bytes[seq_len(3L)],
    as.raw(c(0xef, 0xbb, 0xbf))
  )) {
    .ms_sssom_abort("{label} at {.file {path}} must not contain a UTF-8 BOM.")
  }
  if (any(bytes == as.raw(0x0d))) {
    .ms_sssom_abort(
      "{label} at {.file {path}} must use LF line endings without carriage returns."
    )
  }
  if (any(bytes == as.raw(0x00))) {
    .ms_sssom_abort("{label} at {.file {path}} contains a NUL byte.")
  }
  if (!identical(bytes[[length(bytes)]], as.raw(0x0a))) {
    .ms_sssom_abort("{label} at {.file {path}} must end with an LF newline.")
  }

  text <- rawToChar(bytes)
  if (!isTRUE(base::validUTF8(text))) {
    .ms_sssom_abort("{label} at {.file {path}} is not valid UTF-8.")
  }
  list(bytes = bytes, text = text)
}

.ms_sssom_split_tabs <- function(line) {
  # Appending a sentinel keeps a final empty TSV field, which base::strsplit()
  # otherwise drops.
  sentinel <- "\u001f"
  parts <- strsplit(paste0(line, sentinel), "\t", fixed = TRUE)[[1]]
  parts[[length(parts)]] <- sub(
    paste0(sentinel, "$"),
    "",
    parts[[length(parts)]]
  )
  parts
}

.ms_sssom_parse_metadata <- function(comment_lines, path) {
  yaml_lines <- sub("^# ?", "", comment_lines)
  yaml_text <- paste(yaml_lines, collapse = "\n")
  metadata <- tryCatch(
    yaml::yaml.load(yaml_text),
    error = function(error) {
      .ms_sssom_abort(
        "Embedded SSSOM metadata in {.file {path}} is not valid YAML: {conditionMessage(error)}"
      )
    }
  )
  if (!is.list(metadata) || is.null(names(metadata))) {
    .ms_sssom_abort(
      "Embedded SSSOM metadata in {.file {path}} must be a named YAML mapping."
    )
  }

  unknown <- setdiff(names(metadata), .ms_sssom_metadata_order)
  if (length(unknown) > 0L) {
    .ms_sssom_abort(
      "Embedded metadata in {.file {path}} contains unsupported SSSOM fields: {.field {unknown}}."
    )
  }

  missing <- setdiff(.ms_sssom_required_metadata, names(metadata))
  if (length(missing) > 0L) {
    .ms_sssom_abort(
      "Embedded metadata in {.file {path}} is missing required fields: {.field {missing}}."
    )
  }

  for (name in setdiff(names(metadata), "curie_map")) {
    value <- metadata[[name]]
    if (length(value) > 1L) {
      # Multivalued SSSOM/TSV metadata uses the same vertical-bar encoding as
      # propagated multivalued cells.
      value <- paste(as.character(unlist(value, use.names = FALSE)), collapse = "|")
    }
    metadata[[name]] <- .ms_sssom_scalar(value, name)
  }

  curie_map <- metadata$curie_map
  if (!is.list(curie_map) && !is.atomic(curie_map)) {
    .ms_sssom_abort("SSSOM metadata {.field curie_map} must be a prefix mapping.")
  }
  curie_map <- unlist(curie_map, use.names = TRUE)
  if (length(curie_map) == 0L || is.null(names(curie_map)) ||
      any(!nzchar(names(curie_map)))) {
    .ms_sssom_abort("SSSOM metadata {.field curie_map} must not be empty.")
  }
  if (anyDuplicated(names(curie_map))) {
    .ms_sssom_abort("SSSOM metadata {.field curie_map} contains duplicate prefixes.")
  }
  if (any(!grepl("^[A-Za-z_][A-Za-z0-9._-]*$", names(curie_map)))) {
    .ms_sssom_abort("SSSOM metadata {.field curie_map} contains an invalid prefix name.")
  }
  curie_map <- vapply(
    curie_map,
    function(value) trimws(as.character(value[[1]])),
    character(1)
  )
  if (any(!vapply(curie_map, .ms_sssom_is_absolute_uri, logical(1)))) {
    .ms_sssom_abort(
      "Every SSSOM {.field curie_map} expansion must be an absolute URI."
    )
  }
  metadata$curie_map <- as.list(curie_map[order(names(curie_map), method = "radix")])
  metadata
}

.ms_sssom_parse_table <- function(lines, header_index, path) {
  header <- .ms_sssom_split_tabs(lines[[header_index]])
  if (length(header) < 2L) {
    .ms_sssom_abort(
      "SSSOM mapping table in {.file {path}} must be tab-delimited."
    )
  }
  if (any(!nzchar(header)) || anyDuplicated(header)) {
    .ms_sssom_abort(
      "SSSOM mapping table in {.file {path}} has blank or duplicate column names."
    )
  }
  unknown <- setdiff(header, .ms_sssom_mapping_columns)
  if (length(unknown) > 0L) {
    .ms_sssom_abort(c(
      "SSSOM mapping table in {.file {path}} contains unsupported columns: {.field {unknown}}.",
      "i" = "Variable decomposition fields such as {.field component_id} belong in SDP semantic artifacts, not SSSOM."
    ))
  }
  missing <- setdiff(.ms_sssom_required_columns, header)
  if (length(missing) > 0L) {
    .ms_sssom_abort(
      "SSSOM mapping table in {.file {path}} is missing required columns: {.field {missing}}."
    )
  }

  data_lines <- if (header_index == length(lines)) {
    character()
  } else {
    lines[seq.int(header_index + 1L, length(lines))]
  }
  if (length(data_lines) > 0L && any(!nzchar(data_lines))) {
    .ms_sssom_abort("SSSOM mapping table in {.file {path}} contains a blank row.")
  }
  if (length(data_lines) > 0L && any(startsWith(data_lines, "#"))) {
    .ms_sssom_abort(
      "SSSOM comments are only allowed in embedded metadata before the TSV header."
    )
  }

  if (length(data_lines) == 0L) {
    mappings <- stats::setNames(
      replicate(length(header), character(), simplify = FALSE),
      header
    )
    return(tibble::as_tibble(mappings))
  }

  rows <- lapply(data_lines, .ms_sssom_split_tabs)
  widths <- vapply(rows, length, integer(1))
  if (any(widths != length(header))) {
    .ms_sssom_abort(
      "Every row in the SSSOM mapping table at {.file {path}} must contain {length(header) - 1L} tab delimiters."
    )
  }
  matrix <- matrix(
    unlist(rows, use.names = FALSE),
    nrow = length(rows),
    byrow = TRUE,
    dimnames = list(NULL, header)
  )
  tibble::as_tibble(as.data.frame(matrix, stringsAsFactors = FALSE))
}

.ms_sssom_is_absolute_uri <- function(value) {
  # Shared predicate, not a local regex: `R/iri-predicates.R` owns the shape and
  # the engine choice. Behaviour here is unchanged -- it already ran under TRE.
  length(value) == 1L &&
    !is.na(value) &&
    .ms_absolute_iri_shape(value)
}

.ms_sssom_is_unambiguous_uri <- function(value) {
  # A colon alone is ambiguous between an RFC 3986 scheme and a CURIE prefix.
  # Treat network URLs and these common non-hierarchical URI schemes as URIs;
  # all other `prefix:reference` values must be declared by curie_map.
  grepl("^[A-Za-z][A-Za-z0-9+.-]*://[^[:space:]]+$", value) ||
    grepl("^(urn|mailto|doi|tag|data):[^[:space:]]+$", value)
}

.ms_sssom_validate_reference <- function(value, curie_map, field, row = NULL) {
  where <- if (is.null(row)) "" else paste0(" in row ", row)
  if (!nzchar(value) || grepl("[[:space:]]", value)) {
    .ms_sssom_abort(
      "SSSOM {.field {field}}{where} must be an absolute URI or compact CURIE."
    )
  }
  if (.ms_sssom_is_unambiguous_uri(value)) {
    return(invisible(TRUE))
  }
  if (!grepl("^[A-Za-z_][A-Za-z0-9._-]*:[^[:space:]]+$", value)) {
    .ms_sssom_abort(
      "SSSOM {.field {field}}{where} must be an absolute URI or compact CURIE."
    )
  }
  prefix <- sub(":.*$", "", value)
  if (!prefix %in% names(curie_map)) {
    .ms_sssom_abort(
      "SSSOM {.field {field}}{where} uses unknown CURIE prefix {.val {prefix}}."
    )
  }
  invisible(TRUE)
}

.ms_sssom_validate_metadata <- function(metadata, path) {
  if (!identical(metadata$sssom_version, .ms_sssom_version)) {
    .ms_sssom_abort(
      "SSSOM metadata in {.file {path}} must declare {.field sssom_version}: {.val 1.1}."
    )
  }
  for (field in c("mapping_set_id", "license")) {
    if (!.ms_sssom_is_absolute_uri(metadata[[field]])) {
      .ms_sssom_abort(
        "SSSOM metadata {.field {field}} in {.file {path}} must be an absolute URI."
      )
    }
  }
  for (field in c("subject_source", "object_source")) {
    .ms_sssom_validate_reference(
      metadata[[field]],
      metadata$curie_map,
      field
    )
  }
  for (field in intersect(c("subject_type", "object_type"), names(metadata))) {
    if (grepl("literal", metadata[[field]], ignore.case = TRUE)) {
      .ms_sssom_abort(
        "SSSOM {.field {field}} cannot declare a raw literal assignment in this SDP profile."
      )
    }
  }
  invisible(TRUE)
}

.ms_sssom_reference_columns <- c(
  "record_id",
  "subject_id",
  "subject_category",
  "predicate_id",
  "object_id",
  "object_category",
  "mapping_justification",
  "author_id",
  "reviewer_id",
  "creator_id",
  "license",
  "subject_source",
  "object_source",
  "predicate_type",
  "mapping_provider",
  "mapping_source",
  "mapping_tool_id",
  "curation_rule",
  "subject_match_field",
  "object_match_field",
  "similarity_measure",
  "see_also",
  "issue_tracker_item"
)

.ms_sssom_validate_mappings <- function(mappings, metadata, path) {
  for (field in .ms_sssom_required_columns) {
    blank <- is.na(mappings[[field]]) | !nzchar(trimws(mappings[[field]]))
    if (any(blank)) {
      .ms_sssom_abort(
        "SSSOM required column {.field {field}} contains a blank value in {.file {path}}."
      )
    }
  }

  for (field in intersect(c("subject_type", "object_type"), names(mappings))) {
    literal <- !is.na(mappings[[field]]) &
      grepl("literal", mappings[[field]], ignore.case = TRUE)
    if (any(literal)) {
      .ms_sssom_abort(
        "SSSOM {.field {field}} cannot declare raw literal assignments in this SDP profile."
      )
    }
  }

  # Tabs and newlines are structural in embedded TSV. The parser has already
  # split tabs, while this catches other controls before deterministic writing.
  for (field in names(mappings)) {
    values <- mappings[[field]]
    if (any(grepl("[\t\r\n]", values))) {
      .ms_sssom_abort(
        "SSSOM column {.field {field}} contains a forbidden control character."
      )
    }
  }

  for (field in intersect(.ms_sssom_reference_columns, names(mappings))) {
    values <- mappings[[field]]
    for (row in which(!is.na(values) & nzchar(values))) {
      for (value in strsplit(values[[row]], "|", fixed = TRUE)[[1]]) {
        .ms_sssom_validate_reference(
          value,
          metadata$curie_map,
          field,
          row
        )
      }
    }
  }

  misplaced_no_term <- vapply(
    setdiff(names(mappings), c("subject_id", "object_id")),
    function(field) {
      any(vapply(
        mappings[[field]],
        function(value) {
          if (is.na(value) || !nzchar(value)) {
            return(FALSE)
          }
          "sssom:NoTermFound" %in%
            strsplit(value, "|", fixed = TRUE)[[1]]
        },
        logical(1)
      ))
    },
    logical(1)
  )
  if (any(misplaced_no_term)) {
    .ms_sssom_abort(
      "{.val sssom:NoTermFound} is only valid in {.field subject_id} or {.field object_id}."
    )
  }

  invalid_justification <- !mappings$mapping_justification %in%
    .ms_sssom_justifications
  if (any(invalid_justification)) {
    .ms_sssom_abort(
      "SSSOM {.field mapping_justification} must use a SSSOM 1.1 SEMAPV justification."
    )
  }

  if ("mapping_cardinality" %in% names(mappings)) {
    present <- nzchar(mappings$mapping_cardinality)
    if (any(present & !mappings$mapping_cardinality %in% .ms_sssom_cardinalities)) {
      .ms_sssom_abort("SSSOM {.field mapping_cardinality} contains an invalid value.")
    }
  } else {
    mappings$mapping_cardinality <- ""
  }

  subject_gap <- mappings$subject_id == "sssom:NoTermFound"
  object_gap <- mappings$object_id == "sssom:NoTermFound"
  expected_cardinality <- rep(NA_character_, nrow(mappings))
  expected_cardinality[!subject_gap & object_gap] <- "1:0"
  expected_cardinality[subject_gap & !object_gap] <- "0:1"
  expected_cardinality[subject_gap & object_gap] <- "0:0"
  gaps <- subject_gap | object_gap
  if (any(gaps & mappings$mapping_cardinality != expected_cardinality)) {
    .ms_sssom_abort(
      "Mappings using {.val sssom:NoTermFound} must use the corresponding {.field mapping_cardinality} value (including {.val 1:0} for an object gap)."
    )
  }
  if (any(!gaps & mappings$mapping_cardinality %in% c("1:0", "0:1", "0:0"))) {
    .ms_sssom_abort(
      "SSSOM zero-cardinality mappings must use {.val sssom:NoTermFound}."
    )
  }
  if (any(object_gap) && !nzchar(metadata$object_source)) {
    .ms_sssom_abort(
      "A {.val sssom:NoTermFound} object requires {.field object_source}."
    )
  }
  if (any(subject_gap) && !nzchar(metadata$subject_source)) {
    .ms_sssom_abort(
      "A {.val sssom:NoTermFound} subject requires {.field subject_source}."
    )
  }

  # Metadata source and version values propagate to every row. A row-level
  # source override, however, needs its own version because the mapping-set
  # version cannot describe a different vocabulary release.
  effective_object_source <- rep(metadata$object_source, nrow(mappings))
  effective_object_version <- rep(
    metadata$object_source_version,
    nrow(mappings)
  )
  if ("object_source" %in% names(mappings)) {
    row_source <- mappings$object_source
    overrides <- !is.na(row_source) & nzchar(row_source)
    effective_object_source[overrides] <- row_source[overrides]
    changed_source <- overrides & row_source != metadata$object_source
    effective_object_version[changed_source] <- ""
  }
  if ("object_source_version" %in% names(mappings)) {
    row_version <- mappings$object_source_version
    overrides <- !is.na(row_version) & nzchar(row_version)
    effective_object_version[overrides] <- row_version[overrides]
  }
  if (any(object_gap &
      (!nzchar(effective_object_source) | !nzchar(effective_object_version)))) {
    .ms_sssom_abort(
      "A {.val sssom:NoTermFound} object requires an effective {.field object_source} and {.field object_source_version}."
    )
  }

  # A 1:0 row asserts that the subject has no term in the target source. It is
  # contradictory to carry a positive mapping for that subject and target
  # source in the same mapping set, even when the two rows use different SKOS
  # predicates.
  scope_key <- paste(
    mappings$subject_id,
    effective_object_source,
    effective_object_version,
    sep = "\u001f"
  )
  if (length(intersect(scope_key[object_gap], scope_key[!object_gap])) > 0L) {
    .ms_sssom_abort(
      "A subject/object-source scope cannot contain both a positive mapping and {.val sssom:NoTermFound}; the records contradict each other."
    )
  }

  identity <- paste(
    mappings$subject_id,
    mappings$predicate_id,
    mappings$object_id,
    sep = "\u001f"
  )
  if (anyDuplicated(identity)) {
    .ms_sssom_abort(
      "SSSOM mapping set at {.file {path}} contains a duplicate subject/predicate/object mapping."
    )
  }
  invisible(TRUE)
}

.ms_sssom_validate_mapping_set <- function(mapping_set) {
  path <- mapping_set$path %||% "<in-memory mapping set>"
  .ms_sssom_validate_metadata(mapping_set$metadata, path)
  .ms_sssom_validate_mappings(
    mapping_set$mappings,
    mapping_set$metadata,
    path
  )
  invisible(TRUE)
}

#' Read a reviewed SSSOM mapping set
#'
#' Reads the SSSOM 1.1 embedded-TSV serialization used by Salmon Data
#' Packages. The reader enforces UTF-8 without a byte-order mark, LF line
#' endings, tab delimiters, complete CURIE declarations, and the package's
#' alignment-only profile. In particular, decomposition fields and raw literal
#' assignments are refused because they belong in separate SDP semantic
#' artifacts.
#'
#' @param path Path to one `.sssom.tsv` file.
#' @param validate Logical; validate metadata, CURIEs, mappings, and no-match
#'   cardinalities after parsing. The byte and table structure is always
#'   checked.
#'
#' @return A `metasalmon_sssom_mapping_set` list containing `metadata`, a
#'   `mappings` tibble, and the normalized source `path`.
#' @export
read_sssom_mapping_set <- function(path, validate = TRUE) {
  if (length(path) != 1L || is.na(path) || !nzchar(path)) {
    .ms_sssom_abort("{.arg path} must name one SSSOM mapping-set file.")
  }
  if (length(validate) != 1L || is.na(validate)) {
    .ms_sssom_abort("{.arg validate} must be TRUE or FALSE.")
  }
  path <- normalizePath(path, winslash = "/", mustWork = TRUE)
  source <- .ms_sssom_read_bytes(path)
  # The byte validator already requires the terminal LF. Remove that one
  # structural character before splitting so a one-row table cannot be
  # mistaken for a two-row table by base::strsplit()'s trailing-empty rules.
  body <- substr(source$text, 1L, nchar(source$text, type = "chars") - 1L)
  lines <- strsplit(body, "\n", fixed = TRUE)[[1]]

  non_comment <- which(nzchar(lines) & !startsWith(lines, "#"))
  if (length(non_comment) == 0L) {
    .ms_sssom_abort("SSSOM file {.file {path}} does not contain a TSV header.")
  }
  header_index <- non_comment[[1]]
  if (header_index == 1L) {
    .ms_sssom_abort(
      "SSSOM file {.file {path}} must begin with embedded YAML metadata comments."
    )
  }
  metadata_region <- lines[seq_len(header_index - 1L)]
  if (any(nzchar(metadata_region) & !startsWith(metadata_region, "#"))) {
    .ms_sssom_abort(
      "SSSOM embedded metadata in {.file {path}} must use comment-prefixed YAML lines."
    )
  }
  comment_lines <- metadata_region[nzchar(metadata_region)]
  metadata <- .ms_sssom_parse_metadata(comment_lines, path)
  mappings <- .ms_sssom_parse_table(lines, header_index, path)

  result <- structure(
    list(
      metadata = metadata,
      mappings = mappings,
      path = path
    ),
    class = c("metasalmon_sssom_mapping_set", "list")
  )
  if (isTRUE(validate)) {
    .ms_sssom_validate_mapping_set(result)
  }
  result
}

.ms_sssom_normalize_in_memory <- function(mapping_set) {
  if (!is.list(mapping_set) ||
      !all(c("metadata", "mappings") %in% names(mapping_set))) {
    .ms_sssom_abort(
      "Each {.arg mapping_sets} entry must be a path or a parsed SSSOM mapping set."
    )
  }
  mapping_set$mappings <- tibble::as_tibble(mapping_set$mappings)
  mapping_set$path <- mapping_set$path %||% NA_character_
  class(mapping_set) <- unique(c("metasalmon_sssom_mapping_set", class(mapping_set)))
  .ms_sssom_validate_mapping_set(mapping_set)
  mapping_set
}

.ms_sssom_input_sets <- function(mapping_sets) {
  if (is.character(mapping_sets)) {
    return(lapply(mapping_sets, read_sssom_mapping_set))
  }
  if (inherits(mapping_sets, "metasalmon_sssom_mapping_set") ||
      (is.list(mapping_sets) &&
        all(c("metadata", "mappings") %in% names(mapping_sets)))) {
    return(list(.ms_sssom_normalize_in_memory(mapping_sets)))
  }
  if (is.list(mapping_sets) && length(mapping_sets) > 0L) {
    return(lapply(mapping_sets, function(mapping_set) {
      if (is.character(mapping_set) && length(mapping_set) == 1L) {
        read_sssom_mapping_set(mapping_set)
      } else {
        .ms_sssom_normalize_in_memory(mapping_set)
      }
    }))
  }
  .ms_sssom_abort(
    "{.arg mapping_sets} must be NULL, path(s), or parsed SSSOM mapping set(s)."
  )
}

.ms_sssom_json_scalar <- function(value) {
  as.character(jsonlite::toJSON(
    as.character(value),
    auto_unbox = TRUE,
    pretty = FALSE,
    na = "null"
  ))
}

.ms_sssom_canonical_bytes <- function(mapping_set) {
  metadata <- mapping_set$metadata
  metadata$curie_map <- metadata$curie_map[order(names(metadata$curie_map), method = "radix")]

  metadata_lines <- character()
  for (field in .ms_sssom_metadata_order) {
    if (!field %in% names(metadata)) {
      next
    }
    if (identical(field, "curie_map")) {
      metadata_lines <- c(metadata_lines, "# curie_map:")
      for (prefix in names(metadata$curie_map)) {
        metadata_lines <- c(
          metadata_lines,
          paste0(
            "#   ",
            prefix,
            ": ",
            .ms_sssom_json_scalar(metadata$curie_map[[prefix]])
          )
        )
      }
    } else {
      metadata_lines <- c(
        metadata_lines,
        paste0("# ", field, ": ", .ms_sssom_json_scalar(metadata[[field]]))
      )
    }
  }

  columns <- .ms_sssom_column_order[.ms_sssom_column_order %in%
    names(mapping_set$mappings)]
  mappings <- mapping_set$mappings[, columns, drop = FALSE]
  if (nrow(mappings) > 0L) {
    ordering <- do.call(
      order,
      c(lapply(mappings, as.character), list(na.last = TRUE, method = "radix"))
    )
    mappings <- mappings[ordering, , drop = FALSE]
  }
  table_lines <- paste(columns, collapse = "\t")
  if (nrow(mappings) > 0L) {
    row_lines <- apply(
      as.data.frame(mappings, stringsAsFactors = FALSE),
      1L,
      function(row) paste(ifelse(is.na(row), "", row), collapse = "\t")
    )
    table_lines <- c(table_lines, row_lines)
  }
  charToRaw(enc2utf8(paste0(
    paste(c(metadata_lines, table_lines), collapse = "\n"),
    "\n"
  )))
}

.ms_sssom_safe_filename <- function(mapping_set) {
  source_path <- mapping_set$path
  if (length(source_path) == 1L && !is.na(source_path) && nzchar(source_path)) {
    candidate <- basename(source_path)
    if (grepl("^[A-Za-z0-9][A-Za-z0-9._-]*\\.sssom\\.tsv$", candidate)) {
      return(candidate)
    }
  }

  id <- mapping_set$metadata$mapping_set_id
  candidate <- sub("^.*[/#]", "", id)
  candidate <- gsub("[^A-Za-z0-9._-]+", "-", candidate)
  candidate <- gsub("^-+|-+$", "", candidate)
  if (!nzchar(candidate)) {
    candidate <- paste0(
      "mapping-set-",
      substr(digest::digest(id, algo = "sha256", serialize = FALSE), 1L, 12L)
    )
  }
  paste0(candidate, ".sssom.tsv")
}

.ms_sssom_atomic_write <- function(bytes, path) {
  temporary <- tempfile(
    pattern = paste0(".", basename(path), "-"),
    tmpdir = dirname(path)
  )
  on.exit(unlink(temporary), add = TRUE)
  writeBin(bytes, temporary)
  if (!file.rename(temporary, path)) {
    .ms_sssom_abort("Could not atomically write {.file {path}}.")
  }
  invisible(path)
}

.ms_sssom_manifest_bytes <- function(entries) {
  package_version <- tryCatch(
    as.character(utils::packageVersion("metasalmon")),
    error = function(...) "development"
  )
  manifest <- list(
    schema_version = .ms_sssom_manifest_version,
    sssom_version = .ms_sssom_version,
    mapping_sets = unname(entries),
    provenance = list(
      generated_by = "metasalmon::write_sdp_sssom",
      metasalmon_version = package_version,
      specification = "https://mapping-commons.github.io/sssom/1.1/"
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

.ms_sssom_assert_contained <- function(root, candidate, label) {
  root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  candidate <- normalizePath(candidate, winslash = "/", mustWork = TRUE)
  if (!identical(candidate, root) &&
      !startsWith(candidate, paste0(root, "/"))) {
    .ms_sssom_abort("{label} resolves outside the SDP root and is unsafe.")
  }
  invisible(candidate)
}

#' Write reviewed SSSOM mapping sets into a Salmon Data Package
#'
#' Writes explicitly supplied SSSOM 1.1 mapping sets under
#' `metadata/semantic/` and records their paths, hashes, row counts, source
#' versions, licenses, and writer provenance in
#' `metadata/semantic/mapping-sets.json`. Bytes and manifest ordering are
#' deterministic. This function does not turn semantic suggestions or variable
#' decompositions into mappings; `mapping_sets = NULL` is therefore a no-op.
#'
#' @param path Existing Salmon Data Package directory.
#' @param mapping_sets `NULL`, one or more paths to reviewed `.sssom.tsv`
#'   files, or parsed objects returned by [read_sssom_mapping_set()].
#' @param overwrite Logical; replace files managed by this writer when `TRUE`.
#'
#' @return The manifest path, invisibly, or `NULL` when `mapping_sets` is
#'   `NULL`.
#' @export
write_sdp_sssom <- function(path, mapping_sets = NULL, overwrite = FALSE) {
  if (is.null(mapping_sets)) {
    return(invisible(NULL))
  }
  if (length(path) != 1L || is.na(path) || !dir.exists(path)) {
    .ms_sssom_abort("{.arg path} must be an existing SDP directory.")
  }
  if (length(overwrite) != 1L || is.na(overwrite)) {
    .ms_sssom_abort("{.arg overwrite} must be TRUE or FALSE.")
  }
  root <- normalizePath(path, winslash = "/", mustWork = TRUE)
  sets <- .ms_sssom_input_sets(mapping_sets)
  if (length(sets) == 0L) {
    return(invisible(NULL))
  }

  ids <- vapply(
    sets,
    function(mapping_set) mapping_set$metadata$mapping_set_id,
    character(1)
  )
  if (anyDuplicated(ids)) {
    .ms_sssom_abort("{.arg mapping_sets} contains duplicate mapping_set_id values.")
  }
  sets <- sets[order(ids, method = "radix")]

  filenames <- vapply(sets, .ms_sssom_safe_filename, character(1))
  if (anyDuplicated(filenames)) {
    .ms_sssom_abort(
      "{.arg mapping_sets} resolves to duplicate output filenames; use distinct safe source filenames."
    )
  }
  if (any(!grepl(
    "^[A-Za-z0-9][A-Za-z0-9._-]*\\.sssom\\.tsv$",
    filenames
  ))) {
    .ms_sssom_abort("A generated SSSOM output filename is unsafe.")
  }

  bytes <- lapply(sets, .ms_sssom_canonical_bytes)
  entries <- lapply(seq_along(sets), function(index) {
    metadata <- sets[[index]]$metadata
    list(
      path = paste0("metadata/semantic/", filenames[[index]]),
      sha256 = digest::digest(
        bytes[[index]],
        algo = "sha256",
        serialize = FALSE
      ),
      row_count = as.integer(nrow(sets[[index]]$mappings)),
      mapping_set_id = metadata$mapping_set_id,
      mapping_set_version = metadata$mapping_set_version,
      license = metadata$license,
      subject_source = metadata$subject_source,
      subject_source_version = metadata$subject_source_version,
      object_source = metadata$object_source,
      object_source_version = metadata$object_source_version
    )
  })
  manifest_bytes <- .ms_sssom_manifest_bytes(entries)

  semantic_directory <- file.path(root, "metadata", "semantic")
  manifest_path <- file.path(semantic_directory, "mapping-sets.json")
  output_paths <- file.path(semantic_directory, filenames)
  managed_paths <- c(output_paths, manifest_path)
  existing <- managed_paths[file.exists(managed_paths)]
  if (length(existing) > 0L && !isTRUE(overwrite)) {
    .ms_sssom_abort(c(
      "SSSOM output already exists and {.arg overwrite} is FALSE.",
      "i" = "Existing: {.file {existing}}."
    ))
  }
  symlinks <- existing[nzchar(Sys.readlink(existing))]
  if (length(symlinks) > 0L) {
    .ms_sssom_abort("Refusing to overwrite SSSOM symlinks: {.file {symlinks}}.")
  }

  dir.create(semantic_directory, recursive = TRUE, showWarnings = FALSE)
  .ms_sssom_assert_contained(root, semantic_directory, "SSSOM output directory")
  for (index in seq_along(output_paths)) {
    .ms_sssom_atomic_write(bytes[[index]], output_paths[[index]])
  }
  .ms_sssom_atomic_write(manifest_bytes, manifest_path)

  # Read back the exact artifacts rather than trusting an in-memory plan.
  validate_sdp_sssom(root)
  invisible(manifest_path)
}

.ms_sssom_manifest_safe_path <- function(value) {
  length(value) == 1L &&
    !is.na(value) &&
    grepl(
      "^metadata/semantic/[A-Za-z0-9][A-Za-z0-9._-]*\\.sssom\\.tsv$",
      value
    ) &&
    !grepl("(^|/)\\.\\.?(/|$)|\\\\", value)
}

.ms_sssom_validate_manifest <- function(root) {
  manifest_path <- file.path(root, "metadata", "semantic", "mapping-sets.json")
  source <- .ms_sssom_read_bytes(manifest_path, "SSSOM manifest")
  manifest <- tryCatch(
    jsonlite::fromJSON(source$text, simplifyVector = FALSE),
    error = function(error) {
      .ms_sssom_abort(
        "SSSOM manifest at {.file {manifest_path}} is not valid JSON: {conditionMessage(error)}"
      )
    }
  )
  if (!is.list(manifest) ||
      !all(c(
        "schema_version", "sssom_version", "mapping_sets", "provenance"
      ) %in% names(manifest))) {
    .ms_sssom_abort("SSSOM manifest is missing required top-level fields.")
  }
  if (!identical(manifest$schema_version, .ms_sssom_manifest_version) ||
      !identical(manifest$sssom_version, .ms_sssom_version)) {
    .ms_sssom_abort("SSSOM manifest declares an unsupported schema or SSSOM version.")
  }
  # Either implementation's provenance is complete: the mirror writes
  # byte-identical mapping-set artifacts, and its manifest honestly names
  # metasalmonpy as the generator (parity-deviations register, row 11). The
  # accepted writer set is shared with the decomposition and reproducibility
  # validators -- see `R/provenance.R`.
  version_field <- .ms_manifest_provenance_version_field(
    manifest$provenance,
    "write_sdp_sssom"
  )
  # Presence-only rather than `.ms_manifest_provenance_version_ok()`, which the
  # other two validators use: metasalmonpy's `sssom.py` asks exactly
  # `provenance.get(version_key) is None`, and the two readers of the same
  # artifact must accept the same manifests. See the retirement condition on
  # that predicate in `R/provenance.R`.
  provenance_ok <- !is.na(version_field) &&
    !is.null(manifest$provenance[[version_field]])
  if (!provenance_ok) {
    .ms_sssom_abort("SSSOM manifest provenance is incomplete.")
  }
  if (!is.list(manifest$mapping_sets) || length(manifest$mapping_sets) == 0L) {
    .ms_sssom_abort("SSSOM manifest must contain at least one mapping set.")
  }

  paths <- character(length(manifest$mapping_sets))
  ids <- character(length(manifest$mapping_sets))
  for (index in seq_along(manifest$mapping_sets)) {
    entry <- manifest$mapping_sets[[index]]
    required <- c(
      "path", "sha256", "row_count", "mapping_set_id",
      "mapping_set_version", "license", "subject_source",
      "subject_source_version", "object_source", "object_source_version"
    )
    if (!is.list(entry) || !all(required %in% names(entry))) {
      .ms_sssom_abort("SSSOM manifest mapping-set entry {index} is incomplete.")
    }
    if (!.ms_sssom_manifest_safe_path(entry$path)) {
      .ms_sssom_abort(
        "SSSOM manifest entry {index} does not use a safe relative mapping-set path."
      )
    }
    paths[[index]] <- entry$path
    ids[[index]] <- entry$mapping_set_id
    mapping_path <- file.path(root, entry$path)
    if (!file.exists(mapping_path) || dir.exists(mapping_path)) {
      .ms_sssom_abort("SSSOM manifest references missing file {.file {mapping_path}}.")
    }
    .ms_sssom_assert_contained(root, mapping_path, "SSSOM mapping-set path")
    file_source <- .ms_sssom_read_bytes(mapping_path)
    actual_sha256 <- digest::digest(
      file_source$bytes,
      algo = "sha256",
      serialize = FALSE
    )
    if (!grepl("^[0-9a-f]{64}$", entry$sha256) ||
        !identical(actual_sha256, entry$sha256)) {
      .ms_sssom_abort(
        "SSSOM mapping set {.file {mapping_path}} does not match its manifest SHA-256 hash."
      )
    }

    mapping_set <- read_sssom_mapping_set(mapping_path)
    if (!is.numeric(entry$row_count) || length(entry$row_count) != 1L ||
        is.na(entry$row_count) || entry$row_count < 0 ||
        entry$row_count != as.integer(entry$row_count) ||
        !identical(as.integer(entry$row_count), nrow(mapping_set$mappings))) {
      .ms_sssom_abort(
        "SSSOM mapping set {.file {mapping_path}} does not match its manifest row count."
      )
    }
    for (field in setdiff(required, c("path", "sha256", "row_count"))) {
      if (!identical(entry[[field]], mapping_set$metadata[[field]])) {
        .ms_sssom_abort(
          "SSSOM manifest field {.field {field}} does not match {.file {mapping_path}}."
        )
      }
    }
  }
  if (anyDuplicated(paths) || anyDuplicated(ids)) {
    .ms_sssom_abort("SSSOM manifest contains duplicate paths or mapping_set_id values.")
  }
  if (!identical(ids, sort(ids, method = "radix"))) {
    .ms_sssom_abort("SSSOM manifest mapping sets must be ordered by mapping_set_id.")
  }
  invisible(TRUE)
}

#' Validate SDP SSSOM artifacts
#'
#' Validates either one SSSOM 1.1 embedded-TSV file or an SDP directory. For an
#' SDP directory, the function validates `metadata/semantic/mapping-sets.json`,
#' safe relative paths, byte hashes, row counts, metadata provenance, and every
#' referenced mapping set.
#'
#' @param path Path to an SDP directory or one `.sssom.tsv` mapping set.
#'
#' @return `TRUE`, invisibly, when validation succeeds; otherwise an error.
#' @export
validate_sdp_sssom <- function(path) {
  if (length(path) != 1L || is.na(path) || !nzchar(path)) {
    .ms_sssom_abort("{.arg path} must name one SDP directory or SSSOM file.")
  }
  if (dir.exists(path)) {
    root <- normalizePath(path, winslash = "/", mustWork = TRUE)
    .ms_sssom_validate_manifest(root)
  } else {
    read_sssom_mapping_set(path, validate = TRUE)
  }
  invisible(TRUE)
}
