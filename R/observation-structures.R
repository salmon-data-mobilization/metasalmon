# Measure-specific SDP observation structures ----------------------------
#
# A physical row can contain measures at different logical grains. These
# paired metadata tables declare one virtual observation structure per measure:
# dimensions define the logical key, one measure carries the value, and
# attributes qualify the observation without changing its grain. The role
# names are Data Cube-informed, but this CSV profile is not itself an RDF Data
# Cube Data Structure Definition.

.ms_sdp_observation_structures_path <-
  "metadata/structure/observation_structures.csv"
.ms_sdp_observation_components_path <-
  "metadata/structure/observation_components.csv"
.ms_sdp_observation_structures_columns <- c(
  "dataset_id",
  "table_id",
  "observation_structure_id",
  "structure_label",
  "structure_description"
)
.ms_sdp_observation_components_columns <- c(
  "dataset_id",
  "table_id",
  "observation_structure_id",
  "component_order",
  "column_name",
  "component_role",
  "component_relation_iri",
  "required_when_observed"
)
.ms_sosa_used_procedure <- "http://www.w3.org/ns/sosa/usedProcedure"

.ms_sdp_observation_paths <- function(root) {
  list(
    structures = file.path(root, .ms_sdp_observation_structures_path),
    components = file.path(root, .ms_sdp_observation_components_path)
  )
}

.ms_sdp_observation_parse_logical <- function(value, field) {
  if (is.logical(value)) {
    return(value)
  }
  text <- toupper(trimws(as.character(value)))
  parsed <- rep(NA, length(text))
  parsed[text == "TRUE"] <- TRUE
  parsed[text == "FALSE"] <- FALSE
  if (any(is.na(parsed))) {
    .ms_sdp_extension_abort(
      "{.field {field}} must contain only TRUE or FALSE."
    )
  }
  parsed
}

.ms_sdp_observation_parse_order <- function(value) {
  if (!is.atomic(value)) {
    .ms_sdp_extension_abort(
      "{.field component_order} must be an atomic integer vector."
    )
  }
  numeric <- suppressWarnings(as.numeric(as.character(value)))
  if (any(is.na(numeric)) || any(!is.finite(numeric)) ||
      any(numeric < 1) || any(numeric != floor(numeric))) {
    .ms_sdp_extension_abort(
      "{.field component_order} must contain positive whole numbers."
    )
  }
  as.integer(numeric)
}

.ms_sdp_observation_normalize_structures <- function(structures) {
  structures <- .ms_sdp_extension_validate_closed_rows(
    structures,
    .ms_sdp_observation_structures_columns,
    "structures"
  )
  for (column in .ms_sdp_observation_structures_columns) {
    if (!is.atomic(structures[[column]])) {
      .ms_sdp_extension_abort(
        "Observation-structure column {.field {column}} must be atomic."
      )
    }
    structures[[column]] <- as.character(structures[[column]])
  }
  structures |>
    dplyr::arrange(
      .data$dataset_id,
      .data$table_id,
      .data$observation_structure_id,
      .locale = "C"
    )
}

.ms_sdp_observation_normalize_components <- function(components) {
  components <- .ms_sdp_extension_validate_closed_rows(
    components,
    .ms_sdp_observation_components_columns,
    "components"
  )
  character_columns <- setdiff(
    .ms_sdp_observation_components_columns,
    c("component_order", "required_when_observed")
  )
  for (column in character_columns) {
    if (!is.atomic(components[[column]])) {
      .ms_sdp_extension_abort(
        "Observation-component column {.field {column}} must be atomic."
      )
    }
    components[[column]] <- as.character(components[[column]])
  }
  components$component_order <-
    .ms_sdp_observation_parse_order(components$component_order)
  components$required_when_observed <- .ms_sdp_observation_parse_logical(
    components$required_when_observed,
    "required_when_observed"
  )
  components |>
    dplyr::arrange(
      .data$dataset_id,
      .data$table_id,
      .data$observation_structure_id,
      .data$component_order,
      .locale = "C"
    )
}

.ms_sdp_observation_key <- function(rows) {
  paste(
    rows$dataset_id,
    rows$table_id,
    rows$observation_structure_id,
    sep = "\r"
  )
}

.ms_sdp_observation_column_key <- function(rows) {
  paste(rows$dataset_id, rows$table_id, rows$column_name, sep = "\r")
}

.ms_sdp_observation_structure_rows <- function(rows, structure) {
  rows[
    rows$dataset_id == structure$dataset_id[[1]] &
      rows$table_id == structure$table_id[[1]] &
      rows$observation_structure_id == structure$observation_structure_id[[1]],
    ,
    drop = FALSE
  ]
}

.ms_sdp_observation_validate_required_fields <- function(structures,
                                                         components) {
  for (column in .ms_sdp_observation_structures_columns) {
    if (any(.ms_sdp_extension_is_blank(structures[[column]]))) {
      .ms_sdp_extension_abort(
        "Every observation-structure row requires non-empty {.field {column}}."
      )
    }
  }
  required_components <- setdiff(
    .ms_sdp_observation_components_columns,
    "component_relation_iri"
  )
  for (column in required_components) {
    if (any(.ms_sdp_extension_is_blank(components[[column]]))) {
      .ms_sdp_extension_abort(
        "Every observation-component row requires non-empty {.field {column}}."
      )
    }
  }
  valid_identifier <- "^[A-Za-z_][A-Za-z0-9_]*$"
  if (any(!grepl(valid_identifier, structures$observation_structure_id)) ||
      any(!grepl(valid_identifier, components$observation_structure_id))) {
    .ms_sdp_extension_abort(
      "Every {.field observation_structure_id} must match {.val ^[A-Za-z_][A-Za-z0-9_]*$}."
    )
  }
  if (any(!components$component_role %in%
          c("measure", "dimension", "attribute"))) {
    .ms_sdp_extension_abort(
      "{.field component_role} must be measure, dimension, or attribute."
    )
  }
  relation_present <-
    !.ms_sdp_extension_is_blank(components$component_relation_iri)
  if (any(relation_present & !.ms_sdp_extension_is_absolute_iri(
    components$component_relation_iri
  ))) {
    .ms_sdp_extension_abort(
      "Every non-empty {.field component_relation_iri} must be an absolute IRI."
    )
  }
  invisible(TRUE)
}

.ms_sdp_observation_validate_bindings <- function(root, structures, components,
                                                   package) {
  dataset_id <- .ms_sdp_extension_dataset_id(root)
  if (any(structures$dataset_id != dataset_id) ||
      any(components$dataset_id != dataset_id)) {
    .ms_sdp_extension_abort(
      "Observation-structure {.field dataset_id} values must match {.file metadata/dataset.csv}."
    )
  }

  structure_keys <- .ms_sdp_observation_key(structures)
  if (anyDuplicated(structure_keys)) {
    .ms_sdp_extension_abort(
      "{.field observation_structure_id} must be unique within each dataset and table."
    )
  }
  table_keys <- paste(
    package$tables$dataset_id,
    package$tables$table_id,
    sep = "\r"
  )
  structure_table_keys <- paste(
    structures$dataset_id,
    structures$table_id,
    sep = "\r"
  )
  unknown_tables <- unique(structure_table_keys[!structure_table_keys %in% table_keys])
  if (length(unknown_tables) > 0L) {
    .ms_sdp_extension_abort(
      "Observation structures reference a table that is not declared in {.file metadata/tables.csv}."
    )
  }

  component_structure_keys <- .ms_sdp_observation_key(components)
  if (any(!component_structure_keys %in% structure_keys)) {
    .ms_sdp_extension_abort(
      "Observation components reference an unknown observation structure."
    )
  }
  dictionary_keys <- .ms_sdp_observation_column_key(package$dictionary)
  component_column_keys <- .ms_sdp_observation_column_key(components)
  if (any(!component_column_keys %in% dictionary_keys)) {
    .ms_sdp_extension_abort(
      "Observation components must reference columns in the same declared table."
    )
  }

  measure_bindings <- character()
  for (index in seq_len(nrow(structures))) {
    structure <- structures[index, , drop = FALSE]
    bound <- .ms_sdp_observation_structure_rows(components, structure)
    if (nrow(bound) == 0L) {
      .ms_sdp_extension_abort(
        "Observation structure {.val {structure$observation_structure_id[[1]]}} has no components."
      )
    }
    if (anyDuplicated(bound$component_order)) {
      .ms_sdp_extension_abort(
        "{.field component_order} must be unique within each observation structure."
      )
    }
    if (!identical(sort(bound$component_order), seq_len(nrow(bound)))) {
      .ms_sdp_extension_abort(
        "{.field component_order} must be contiguous from 1 within each observation structure."
      )
    }
    if (anyDuplicated(bound$column_name)) {
      .ms_sdp_extension_abort(
        "A column can be bound at most once within an observation structure."
      )
    }
    measure <- bound[bound$component_role == "measure", , drop = FALSE]
    if (nrow(measure) != 1L) {
      .ms_sdp_extension_abort(
        "Each observation structure must have exactly one measure component."
      )
    }
    if (sum(bound$component_role == "dimension") < 1L) {
      .ms_sdp_extension_abort(
        "Each observation structure must have at least one dimension component."
      )
    }
    measure_key <- .ms_sdp_observation_column_key(measure)
    if (measure_key %in% measure_bindings) {
      .ms_sdp_extension_abort(
        "A measurement column can be the measure of at most one observation structure."
      )
    }
    measure_bindings <- c(measure_bindings, measure_key)

    dictionary_index <- match(
      .ms_sdp_observation_column_key(bound),
      dictionary_keys
    )
    bound_dictionary <- package$dictionary[dictionary_index, , drop = FALSE]
    if (!identical(
      as.character(bound_dictionary$column_role[bound$component_role == "measure"]),
      "measurement"
    )) {
      .ms_sdp_extension_abort(
        "Every measure component must bind a {.val measurement} dictionary column."
      )
    }
    structural <- bound$component_role %in% c("measure", "dimension")
    if (any(structural & !bound$required_when_observed)) {
      .ms_sdp_extension_abort(
        "Measure and dimension components must set {.field required_when_observed} to TRUE."
      )
    }
    used_procedure <-
      bound$component_relation_iri == .ms_sosa_used_procedure
    used_procedure[is.na(used_procedure)] <- FALSE
    if (any(used_procedure & bound$component_role != "attribute")) {
      .ms_sdp_extension_abort(
        "A {.val sosa:usedProcedure} component must have the attribute role."
      )
    }
    if (any(used_procedure &
            bound_dictionary$column_role != "categorical")) {
      .ms_sdp_extension_abort(
        "A {.val sosa:usedProcedure} component must bind a categorical dictionary column."
      )
    }
  }

  # Once the optional extension is present it is a complete measure-level
  # structural inventory, not a selective annotation. Partial coverage would
  # leave consumers unable to tell whether an omitted measure shares a table
  # grain or was simply forgotten.
  measurement_dictionary <- package$dictionary[
    package$dictionary$column_role == "measurement",
    ,
    drop = FALSE
  ]
  expected_measure_bindings <- .ms_sdp_observation_column_key(
    measurement_dictionary
  )
  missing_measure_bindings <- setdiff(
    expected_measure_bindings,
    measure_bindings
  )
  if (length(missing_measure_bindings) > 0L) {
    missing_rows <- measurement_dictionary[
      expected_measure_bindings %in% missing_measure_bindings,
      ,
      drop = FALSE
    ]
    missing_labels <- paste(
      missing_rows$table_id,
      missing_rows$column_name,
      sep = "."
    )
    .ms_sdp_extension_abort(c(
      "When observation structures are present, every measurement column must be bound as exactly one measure.",
      "x" = "Not bound as a measure: {.field {missing_labels}}."
    ))
  }
  invisible(TRUE)
}

.ms_sdp_observation_method_registry <- function(root) {
  methods_path <- file.path(root, .ms_sdp_methods_path)
  if (!file.exists(methods_path)) {
    return(tibble::tibble(
      dataset_id = character(),
      method_iri = character()
    ))
  }
  read_sdp_methods(root, validate = TRUE)
}

.ms_sdp_observation_normalize_typed_values <- function(values, value_type,
                                                       column_name) {
  text <- as.character(values)
  blank <- .ms_sdp_extension_is_blank(text)
  normalized <- text
  normalized[blank] <- ""
  present <- which(!blank)
  if (length(present) == 0L) {
    return(normalized)
  }

  value_type <- tolower(trimws(as.character(value_type[[1]])))
  fail_type <- function() {
    .ms_sdp_extension_abort(c(
      "Observation component values do not match their dictionary {.field value_type}.",
      "x" = "Column {.field {column_name}} declares {.val {value_type}}."
    ))
  }
  if (identical(value_type, "integer")) {
    valid <- grepl("^[+-]?[0-9]+$", text[present])
    parsed <- suppressWarnings(as.numeric(text[present]))
    if (any(!valid) || any(!is.finite(parsed)) || any(parsed != floor(parsed))) {
      fail_type()
    }
    normalized[present] <- format(
      parsed,
      scientific = FALSE,
      trim = TRUE,
      digits = 22
    )
  } else if (identical(value_type, "number")) {
    parsed <- suppressWarnings(as.numeric(text[present]))
    if (any(!is.finite(parsed))) {
      fail_type()
    }
    # Numeric equality, not source lexical form, determines grain/invariance.
    normalized[present] <- vapply(parsed, function(value) {
      if (identical(value, 0) || identical(value, -0)) {
        return("0")
      }
      format(value, scientific = FALSE, trim = TRUE, digits = 17)
    }, character(1))
  } else if (identical(value_type, "boolean")) {
    parsed <- toupper(trimws(text[present]))
    if (any(!parsed %in% c("TRUE", "FALSE"))) {
      fail_type()
    }
    normalized[present] <- parsed
  } else if (identical(value_type, "date")) {
    valid <- grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", text[present])
    parsed <- suppressWarnings(as.Date(text[present]))
    if (any(!valid) || any(is.na(parsed))) {
      fail_type()
    }
    normalized[present] <- format(parsed, "%Y-%m-%d")
  } else if (identical(value_type, "datetime")) {
    valid <- grepl(
      "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(?:Z|[+-][0-9]{2}:[0-9]{2})$",
      text[present],
      perl = TRUE
    )
    parsed <- suppressWarnings(as.POSIXct(text[present], tz = "UTC"))
    if (any(!valid) || any(is.na(parsed))) {
      fail_type()
    }
    normalized[present] <- format(
      parsed,
      "%Y-%m-%dT%H:%M:%SZ",
      tz = "UTC"
    )
  } else if (!identical(value_type, "string")) {
    fail_type()
  }
  normalized
}

.ms_sdp_observation_cast_typed_values <- function(values, value_type,
                                                  column_name) {
  normalized <- .ms_sdp_observation_normalize_typed_values(
    values,
    value_type,
    column_name
  )
  blank <- normalized == ""
  value_type <- tolower(trimws(as.character(value_type[[1]])))
  if (identical(value_type, "integer")) {
    parsed <- suppressWarnings(as.numeric(normalized))
    parsed[blank] <- NA_real_
    if (all(
      is.na(parsed) |
        (parsed >= -.Machine$integer.max & parsed <= .Machine$integer.max)
    )) {
      return(as.integer(parsed))
    }
    return(parsed)
  }
  if (identical(value_type, "number")) {
    parsed <- suppressWarnings(as.numeric(normalized))
    parsed[blank] <- NA_real_
    return(parsed)
  }
  if (identical(value_type, "boolean")) {
    parsed <- normalized == "TRUE"
    parsed[blank] <- NA
    return(parsed)
  }
  if (identical(value_type, "date")) {
    parsed <- as.Date(normalized)
    parsed[blank] <- as.Date(NA)
    return(parsed)
  }
  if (identical(value_type, "datetime")) {
    parsed <- as.POSIXct(normalized, tz = "UTC")
    parsed[blank] <- as.POSIXct(NA, tz = "UTC")
    return(parsed)
  }
  normalized[blank] <- NA_character_
  normalized
}

.ms_sdp_observation_validate_procedure_codes <- function(
    structure, bound, data, observed_rows, codes, methods) {
  procedure_components <- bound[
    !.ms_sdp_extension_is_blank(bound$component_relation_iri) &
      bound$component_relation_iri == .ms_sosa_used_procedure,
    ,
    drop = FALSE
  ]
  for (procedure_index in seq_len(nrow(procedure_components))) {
    column <- procedure_components$column_name[[procedure_index]]
    enumerated <- codes[
      codes$dataset_id == structure$dataset_id[[1]] &
        codes$table_id == structure$table_id[[1]] &
        codes$column_name == column &
        !.ms_sdp_extension_is_blank(codes$code_value),
      ,
      drop = FALSE
    ]
    if (anyDuplicated(as.character(enumerated$code_value))) {
      .ms_sdp_extension_abort(
        "Enumerated {.val sosa:usedProcedure} code values must be unique per column."
      )
    }
    for (code_index in seq_len(nrow(enumerated))) {
      code_value <- as.character(enumerated$code_value[[code_index]])
      method_iri <- as.character(enumerated$term_iri[[code_index]])
      if (.ms_sdp_extension_is_blank(method_iri)) {
        .ms_sdp_extension_abort(c(
          "Every enumerated {.val sosa:usedProcedure} code must resolve through exactly one {.file metadata/codes.csv} row with a {.field term_iri}.",
          "x" = "Column {.field {column}}, code {.val {code_value}}."
        ))
      }
      registered <- any(
        methods$dataset_id == structure$dataset_id[[1]] &
          methods$method_iri == method_iri
      )
      if (!isTRUE(registered)) {
        .ms_sdp_extension_abort(c(
          "An enumerated {.val sosa:usedProcedure} code resolves to an unregistered method.",
          "x" = "Column {.field {column}}, code {.val {code_value}}."
        ))
      }
    }

    observed_values <- unique(as.character(data[[column]][observed_rows]))
    observed_values <- observed_values[
      !.ms_sdp_extension_is_blank(observed_values)
    ]
    missing_values <- setdiff(
      observed_values,
      as.character(enumerated$code_value)
    )
    if (length(missing_values) > 0L) {
      .ms_sdp_extension_abort(c(
        "Every observed {.val sosa:usedProcedure} code must resolve through exactly one {.file metadata/codes.csv} row with a registered {.field term_iri}.",
        "x" = "Column {.field {column}}, unregistered code(s) {.val {missing_values}}."
      ))
    }
  }
  invisible(TRUE)
}

.ms_sdp_observation_validate_data <- function(root, structures, components,
                                               package) {
  methods <- .ms_sdp_observation_method_registry(root)
  static_methods <- if ("method_iri" %in% names(package$dictionary)) {
    unique(as.character(package$dictionary$method_iri))
  } else {
    character()
  }
  static_methods <- static_methods[
    !.ms_sdp_extension_is_blank(static_methods)
  ]
  if (length(static_methods) > 0L) {
    missing_static <- setdiff(static_methods, methods$method_iri)
    if (length(missing_static) > 0L) {
      .ms_sdp_extension_abort(c(
        "Static procedure references used by observation structures require {.file metadata/methods.csv} registry rows.",
        "x" = "Unregistered {.field method_iri}: {.val {missing_static}}."
      ))
    }
  }
  codes <- package$codes
  if (is.null(codes)) {
    codes <- tibble::tibble(
      dataset_id = character(),
      table_id = character(),
      column_name = character(),
      code_value = character(),
      term_iri = character()
    )
  }

  for (index in seq_len(nrow(structures))) {
    structure <- structures[index, , drop = FALSE]
    bound <- .ms_sdp_observation_structure_rows(components, structure)
    table_id <- structure$table_id[[1]]
    data <- package$resources[[table_id]]
    if (is.null(data)) {
      .ms_sdp_extension_abort(
        "Could not load data table {.val {table_id}} for observation-structure validation."
      )
    }
    measure <- bound$column_name[bound$component_role == "measure"][[1]]
    observed <- !.ms_sdp_extension_is_blank(data[[measure]])
    observed_rows <- which(observed)
    .ms_sdp_observation_validate_procedure_codes(
      structure,
      bound,
      data,
      observed_rows,
      codes,
      methods
    )
    if (length(observed_rows) == 0L) {
      next
    }

    required <- bound$column_name[bound$required_when_observed]
    for (column in required) {
      missing <- observed_rows[.ms_sdp_extension_is_blank(data[[column]][observed_rows])]
      if (length(missing) > 0L) {
        .ms_sdp_extension_abort(c(
          "A required observation component is empty where its measure is observed.",
          "x" = "Table {.val {table_id}}, structure {.val {structure$observation_structure_id[[1]]}}, column {.field {column}}, data row(s) {.val {missing + 1L}}."
        ))
      }
    }

    dictionary_keys <- .ms_sdp_observation_column_key(package$dictionary)
    bound_dictionary <- package$dictionary[
      match(.ms_sdp_observation_column_key(bound), dictionary_keys),
      ,
      drop = FALSE
    ]
    normalized_components <- lapply(seq_len(nrow(bound)), function(component_index) {
      column <- bound$column_name[[component_index]]
      .ms_sdp_observation_normalize_typed_values(
        data[[column]][observed_rows],
        bound_dictionary$value_type[[component_index]],
        column
      )
    })
    names(normalized_components) <- bound$column_name

    dimensions <- bound$column_name[bound$component_role == "dimension"]
    attributes <- bound$column_name[bound$component_role == "attribute"]
    grain_values <- tibble::as_tibble(normalized_components[dimensions])
    grain_keys <- vapply(seq_len(nrow(grain_values)), function(row) {
      jsonlite::toJSON(
        as.list(grain_values[row, , drop = FALSE]),
        auto_unbox = TRUE,
        null = "null",
        na = "null"
      )
    }, character(1))
    invariants <- c(measure, attributes)
    for (grain_key in unique(grain_keys)) {
      positions <- which(grain_keys == grain_key)
      normalized <- normalized_components[invariants]
      normalized <- lapply(normalized, function(column) column[positions])
      value_keys <- do.call(paste, c(normalized, sep = "\r"))
      if (length(unique(value_keys)) > 1L) {
        .ms_sdp_extension_abort(c(
          "Repeated observations at one declared dimension grain are not invariant.",
          "x" = "Table {.val {table_id}}, structure {.val {structure$observation_structure_id[[1]]}}, dimension tuple {.val {grain_key}} has conflicting measure or attribute values."
        ))
      }
    }

  }
  invisible(TRUE)
}

.ms_sdp_observation_validate_descriptor <- function(root) {
  descriptor_path <- file.path(root, "datapackage.json")
  if (.ms_sdp_extension_is_symlink(descriptor_path)) {
    .ms_sdp_extension_abort("Refusing symlinked {.file datapackage.json}.")
  }
  if (!file.exists(descriptor_path)) {
    return(invisible(TRUE))
  }
  descriptor <- tryCatch(
    jsonlite::read_json(descriptor_path, simplifyVector = FALSE),
    error = function(error) {
      .ms_sdp_extension_abort(
        "Could not parse {.file datapackage.json}: {conditionMessage(error)}"
      )
    }
  )
  expected_resources <- list(
    .ms_sdp_extension_resource(
      "sdp_observation_structures",
      .ms_sdp_observation_structures_path,
      "SDP observation structures metadata",
      paste(
        "Optional logical observation structures that declare the grain",
        "of individual measures in wide or mixed-grain tables."
      ),
      "observation_structures.schema.json"
    ),
    .ms_sdp_extension_resource(
      "sdp_observation_components",
      .ms_sdp_observation_components_path,
      "SDP observation components metadata",
      paste(
        "Ordered bindings from table columns to the measure, dimensions,",
        "and attributes of a logical observation structure."
      ),
      "observation_components.schema.json"
    )
  )
  purrr::walk(
    expected_resources,
    ~ .ms_sdp_extension_validate_descriptor_resource(descriptor, .x)
  )
  if (!identical(
        descriptor$sdp$metadata$observationStructures %||% NULL,
        .ms_sdp_observation_structures_path
      ) ||
      !identical(
        descriptor$sdp$metadata$observationComponents %||% NULL,
        .ms_sdp_observation_components_path
      )) {
    .ms_sdp_extension_abort(
      "{.file datapackage.json} must declare both paired observation-structure metadata resources."
    )
  }
  invisible(TRUE)
}

.ms_sdp_observation_validate_rows <- function(root, structures, components,
                                               check_descriptor = TRUE) {
  if (nrow(structures) == 0L || nrow(components) == 0L) {
    .ms_sdp_extension_abort(
      "Present observation-structure files must each contain at least one row."
    )
  }
  .ms_sdp_observation_validate_required_fields(structures, components)
  package <- read_salmon_datapackage(root)
  .ms_sdp_observation_validate_bindings(
    root,
    structures,
    components,
    package
  )
  .ms_sdp_observation_validate_data(
    root,
    structures,
    components,
    package
  )
  if (isTRUE(check_descriptor)) {
    .ms_sdp_observation_validate_descriptor(root)
  }
  invisible(TRUE)
}

.ms_sdp_observation_assert_paired <- function(root, require_present = TRUE) {
  paths <- .ms_sdp_observation_paths(root)
  present <- vapply(paths, file.exists, logical(1))
  symlink <- vapply(paths, .ms_sdp_extension_is_symlink, logical(1))
  if (any(symlink)) {
    .ms_sdp_extension_abort(
      "Refusing symlinked observation-structure metadata files."
    )
  }
  if (xor(present[[1]], present[[2]])) {
    .ms_sdp_extension_abort(
      "{.file observation_structures.csv} and {.file observation_components.csv} must be present together."
    )
  }
  if (isTRUE(require_present) && !all(present)) {
    .ms_sdp_extension_abort(
      "The paired observation-structure metadata files are absent."
    )
  }
  invisible(all(present))
}

.ms_validate_optional_sdp_observation_metadata <- function(path) {
  root <- .ms_sdp_extension_root(path)
  methods_path <- file.path(root, .ms_sdp_methods_path)
  if (file.exists(methods_path) ||
      .ms_sdp_extension_is_symlink(methods_path)) {
    validate_sdp_methods(root)
  }
  structure_paths <- .ms_sdp_observation_paths(root)
  structure_present <- vapply(structure_paths, function(candidate) {
    file.exists(candidate) || .ms_sdp_extension_is_symlink(candidate)
  }, logical(1))
  if (any(structure_present)) {
    validate_sdp_observation_structures(root)
  }
  invisible(TRUE)
}

#' Write measure-specific SDP observation structures
#'
#' Writes the paired canonical resources under `metadata/structure/`. Each
#' structure has one measure; dimensions define that measure's grain and
#' attributes qualify it. Supplying both row arguments as `NULL` is an explicit
#' no-op. Supplying only one is an error because the files are a pair.
#'
#' @param path Existing Salmon Data Package directory.
#' @param structures `NULL` or a data frame with the exact SDP observation
#'   structures schema.
#' @param components `NULL` or a data frame with the exact SDP observation
#'   components schema.
#' @param overwrite Logical; replace both managed resources when `TRUE`.
#'
#' @return A named character vector containing the two written paths,
#'   invisibly; `NULL` for an explicit no-op.
#' @export
write_sdp_observation_structures <- function(path, structures = NULL,
                                             components = NULL,
                                             overwrite = FALSE) {
  if (is.null(structures) && is.null(components)) {
    return(invisible(NULL))
  }
  if (is.null(structures) || is.null(components)) {
    .ms_sdp_extension_abort(
      "{.arg structures} and {.arg components} must be supplied together."
    )
  }
  root <- .ms_sdp_extension_root(path)
  if (length(overwrite) != 1L || is.na(overwrite)) {
    .ms_sdp_extension_abort("{.arg overwrite} must be TRUE or FALSE.")
  }
  structures <- .ms_sdp_observation_normalize_structures(structures)
  components <- .ms_sdp_observation_normalize_components(components)
  .ms_sdp_observation_validate_rows(
    root,
    structures,
    components,
    check_descriptor = FALSE
  )

  paths <- .ms_sdp_observation_paths(root)
  existing <- vapply(paths, function(path) {
    file.exists(path) || .ms_sdp_extension_is_symlink(path)
  }, logical(1))
  if (any(existing) && !isTRUE(overwrite)) {
    .ms_sdp_extension_abort(
      "Observation-structure output already exists and {.arg overwrite} is FALSE."
    )
  }
  .ms_sdp_extension_assert_safe_directory(
    root,
    "metadata/structure",
    create = TRUE
  )
  if (any(vapply(paths, .ms_sdp_extension_is_symlink, logical(1)))) {
    .ms_sdp_extension_abort(
      "Refusing to overwrite symlinked observation-structure metadata files."
    )
  }

  descriptor_bytes <- .ms_sdp_extension_descriptor_bytes(
    root,
    resources = list(
      .ms_sdp_extension_resource(
        "sdp_observation_structures",
        .ms_sdp_observation_structures_path,
        "SDP observation structures metadata",
        paste(
          "Optional logical observation structures that declare the grain",
          "of individual measures in wide or mixed-grain tables."
        ),
        "observation_structures.schema.json"
      ),
      .ms_sdp_extension_resource(
        "sdp_observation_components",
        .ms_sdp_observation_components_path,
        "SDP observation components metadata",
        paste(
          "Ordered bindings from table columns to the measure, dimensions,",
          "and attributes of a logical observation structure."
        ),
        "observation_components.schema.json"
      )
    ),
    metadata = list(
      observationStructures = .ms_sdp_observation_structures_path,
      observationComponents = .ms_sdp_observation_components_path
    )
  )
  writes <- list(
    structures = .ms_sdp_extension_csv_bytes(structures),
    components = .ms_sdp_extension_csv_bytes(components)
  )
  names(writes) <- unlist(paths, use.names = FALSE)
  if (!is.null(descriptor_bytes)) {
    descriptor_path <- file.path(root, "datapackage.json")
    writes[[descriptor_path]] <- descriptor_bytes
  }
  .ms_sdp_extension_atomic_write_set(
    writes,
    validate = function() validate_sdp_observation_structures(root)
  )
  invisible(unlist(paths, use.names = TRUE))
}

#' Read measure-specific SDP observation structures
#'
#' @param path Existing Salmon Data Package directory.
#' @param validate Logical; validate package references, logical grain,
#'   procedure bindings, and descriptor inventory when `TRUE`.
#'
#' @return A list with `structures` and `components` tibbles.
#' @export
read_sdp_observation_structures <- function(path, validate = TRUE) {
  root <- .ms_sdp_extension_root(path)
  if (length(validate) != 1L || is.na(validate)) {
    .ms_sdp_extension_abort("{.arg validate} must be TRUE or FALSE.")
  }
  .ms_sdp_observation_assert_paired(root, require_present = TRUE)
  structures <- .ms_sdp_extension_read_csv(
    root,
    .ms_sdp_observation_structures_path,
    .ms_sdp_observation_structures_columns,
    readr::cols(.default = readr::col_character())
  )
  components <- .ms_sdp_extension_read_csv(
    root,
    .ms_sdp_observation_components_path,
    .ms_sdp_observation_components_columns,
    readr::cols(
      .default = readr::col_character(),
      component_order = readr::col_integer(),
      required_when_observed = readr::col_logical()
    )
  )
  structures <- .ms_sdp_observation_normalize_structures(structures)
  components <- .ms_sdp_observation_normalize_components(components)
  if (isTRUE(validate)) {
    .ms_sdp_observation_validate_rows(root, structures, components)
  }
  list(structures = structures, components = components)
}

#' Validate measure-specific SDP observation structures
#'
#' @param path Existing Salmon Data Package directory.
#'
#' @return `TRUE`, invisibly, when the paired resources and all data-level
#'   bindings are valid; otherwise an error.
#' @export
validate_sdp_observation_structures <- function(path) {
  read_sdp_observation_structures(path, validate = TRUE)
  invisible(TRUE)
}

#' Extract normalized logical observations from an SDP
#'
#' Validates the paired structure metadata, filters rows where each structure's
#' measure is absent, selects components in declared order, and collapses exact
#' repeats at a coarser declared grain. The result remains a list because
#' different structures can have different component columns and data types.
#'
#' @param path Existing Salmon Data Package directory.
#' @param table_id Optional scalar table identifier used to select structures.
#' @param observation_structure_id Optional scalar structure identifier used to
#'   select structures. Supply `table_id` too when the identifier is not unique
#'   across tables.
#'
#' @return A deterministically named list of tibbles, one per selected logical
#'   structure. Names use `table_id::observation_structure_id`.
#' @export
extract_sdp_observations <- function(path, table_id = NULL,
                                     observation_structure_id = NULL) {
  root <- .ms_sdp_extension_root(path)
  metadata <- read_sdp_observation_structures(root, validate = TRUE)
  structures <- metadata$structures

  validate_selector <- function(value, argument) {
    if (is.null(value)) {
      return(NULL)
    }
    if (length(value) != 1L || is.na(value) || !nzchar(trimws(value))) {
      .ms_sdp_extension_abort(
        "{.arg {argument}} must be NULL or one non-empty string."
      )
    }
    as.character(value)
  }
  table_id <- validate_selector(table_id, "table_id")
  observation_structure_id <- validate_selector(
    observation_structure_id,
    "observation_structure_id"
  )
  if (!is.null(table_id)) {
    structures <- structures[structures$table_id == table_id, , drop = FALSE]
  }
  if (!is.null(observation_structure_id)) {
    structures <- structures[
      structures$observation_structure_id == observation_structure_id,
      ,
      drop = FALSE
    ]
  }
  if (nrow(structures) == 0L) {
    .ms_sdp_extension_abort(
      "No observation structure matches the requested selector(s)."
    )
  }

  package <- read_salmon_datapackage(root)
  output <- vector("list", nrow(structures))
  names(output) <- paste(
    structures$table_id,
    structures$observation_structure_id,
    sep = "::"
  )
  for (index in seq_len(nrow(structures))) {
    structure <- structures[index, , drop = FALSE]
    components <- .ms_sdp_observation_structure_rows(
      metadata$components,
      structure
    )
    # `component_order` is integer, so radix is already the default here; the
    # explicit method documents that and satisfies the collation guard.
    components <- components[
      order(components$component_order, method = "radix"), ,
      drop = FALSE
    ]
    measure <- components$column_name[components$component_role == "measure"][[1]]
    dimensions <- components$column_name[components$component_role == "dimension"]
    data <- package$resources[[structure$table_id[[1]]]]
    data <- data[!.ms_sdp_extension_is_blank(data[[measure]]), , drop = FALSE]
    data <- data[, components$column_name, drop = FALSE]
    dictionary_keys <- .ms_sdp_observation_column_key(package$dictionary)
    component_dictionary <- package$dictionary[
      match(.ms_sdp_observation_column_key(components), dictionary_keys),
      ,
      drop = FALSE
    ]
    for (component_index in seq_len(nrow(components))) {
      column <- components$column_name[[component_index]]
      data[[column]] <- .ms_sdp_observation_cast_typed_values(
        data[[column]],
        component_dictionary$value_type[[component_index]],
        column
      )
    }
    data <- dplyr::distinct(data)
    if (length(dimensions) > 0L && nrow(data) > 0L) {
      data <- dplyr::arrange(data, !!!rlang::syms(dimensions), .locale = "C")
    }
    output[[index]] <- tibble::as_tibble(data)
  }
  output
}
