.ms_semantic_validator_finding_cols <- function() {
  c(
    "code",
    "severity",
    "role",
    "before_decision",
    "after_decision",
    "message"
  )
}

.ms_empty_semantic_validator_findings <- function() {
  tibble::tibble(
    code = character(),
    severity = character(),
    role = character(),
    before_decision = character(),
    after_decision = character(),
    message = character()
  )
}

.ms_semantic_validator_finding <- function(code, role, message) {
  tibble::tibble(
    code = as.character(code),
    severity = "warning",
    role = as.character(role),
    before_decision = "accept",
    after_decision = "review",
    message = as.character(message)
  )
}

.ms_semantic_validator_text <- function(...) {
  values <- unlist(list(...), recursive = TRUE, use.names = FALSE)
  values <- as.character(values)
  values <- values[!is.na(values) & nzchar(trimws(values))]
  tolower(paste(values, collapse = " "))
}

.ms_semantic_validator_strip_negated_evidence <- function(text, evidence_pattern) {
  negation <- paste(
    c(
      "no",
      "not",
      "without",
      "unknown",
      "unspecified",
      "missing",
      "does not",
      "did not",
      "is not",
      "was not"
    ),
    collapse = "|"
  )
  gsub(
    paste0(
      "\\b(", negation, ")\\b.{0,60}\\b(",
      evidence_pattern,
      ")\\b"
    ),
    " ",
    text,
    perl = TRUE
  )
}

.ms_semantic_validator_has_method_evidence <- function(evidence_text) {
  text <- .ms_semantic_validator_text(evidence_text)
  if (!nzchar(text)) {
    return(FALSE)
  }

  method_terms <- paste(
    c(
      "protocol",
      "gear",
      "instrument",
      "assay",
      "technique",
      "field method",
      "lab method",
      "laboratory method",
      "survey method",
      "measurement method",
      "estimation method",
      "field procedure",
      "lab procedure",
      "laboratory procedure",
      "measurement procedure",
      "operational procedure"
    ),
    collapse = "|"
  )
  positive_text <- .ms_semantic_validator_strip_negated_evidence(
    text,
    method_terms
  )

  grepl(
    paste0(
      "\\b(", method_terms, ")\\b",
      "|\\b(measured|sampled|surveyed|enumerated|counted|weighed)\\b.{0,80}\\b(using|with|via)\\b",
      "|\\b(measured|sampled|surveyed|enumerated|counted|weighed)\\b.{0,80}\\bby\\b.{0,40}\\b(method|protocol|procedure|observer|technician|instrument|gear)\\b",
      "|\\b(using|with)\\b.{0,80}\\b(board|scale|net|sonar|weir|camera|caliper|ruler|sensor|model)\\b",
      "|\\b(estimated|calculated|derived|modelled|modeled)\\s+(using|with|from)\\b",
      "|\\b(estimated|calculated|derived|modelled|modeled)\\b.{0,80}\\bby\\b.{0,40}\\b(model|algorithm|estimator|method|procedure)\\b"
    ),
    positive_text,
    perl = TRUE
  )
}

.ms_validate_semantic_method_evidence <- function(role, evidence_text) {
  if (!identical(role, "method") ||
      .ms_semantic_validator_has_method_evidence(evidence_text)) {
    return(.ms_empty_semantic_validator_findings())
  }

  .ms_semantic_validator_finding(
    code = "SEM_METHOD_EVIDENCE_REQUIRED",
    role = role,
    message = paste(
      "The accepted method candidate lacks explicit field, protocol, gear,",
      "instrument, or estimation-procedure evidence."
    )
  )
}

.ms_semantic_validator_has_constraint_evidence <- function(evidence_text) {
  text <- .ms_semantic_validator_text(evidence_text)
  if (!nzchar(text)) {
    return(FALSE)
  }

  constraint_terms <- paste(
    c(
      "origin",
      "life[ -]?cycle",
      "life[ -]?stage",
      "stage",
      "run",
      "season",
      "age",
      "sex",
      "maturity",
      "phase",
      "terminal",
      "ocean",
      "freshwater",
      "wild",
      "hatchery",
      "population",
      "stock",
      "species group",
      "reporting unit",
      "benchmark"
    ),
    collapse = "|"
  )
  positive_text <- .ms_semantic_validator_strip_negated_evidence(
    text,
    constraint_terms
  )

  grepl(paste0("\\b(", constraint_terms, ")\\b"), positive_text, perl = TRUE)
}

.ms_validate_semantic_constraint_evidence <- function(role, evidence_text) {
  if (!identical(role, "constraint") ||
      .ms_semantic_validator_has_constraint_evidence(evidence_text)) {
    return(.ms_empty_semantic_validator_findings())
  }

  .ms_semantic_validator_finding(
    code = "SEM_CONSTRAINT_EVIDENCE_REQUIRED",
    role = role,
    message = paste(
      "The accepted constraint candidate lacks an explicit qualifier such as",
      "origin, life stage, phase, season, age, sex, stock, or reporting unit."
    )
  )
}

.ms_semantic_validator_candidate_type <- function(candidate) {
  candidate <- tibble::as_tibble(candidate)
  type_fields <- intersect(
    c("term_type", "native_type", "resource_kind", "type_iris"),
    names(candidate)
  )
  .ms_semantic_validator_text(candidate[type_fields])
}

.ms_validate_semantic_role_type <- function(role, candidate) {
  candidate <- tibble::as_tibble(candidate)
  hints <- if ("role_hints" %in% names(candidate)) {
    .ms_semantic_split_role_hints(candidate$role_hints[[1]])
  } else {
    character()
  }
  hints <- hints[!is.na(hints) & nzchar(hints)]
  if (length(hints) > 0L && !role %in% hints) {
    return(.ms_semantic_validator_finding(
      code = "SEM_ROLE_TYPE_MISMATCH",
      role = role,
      message = paste0(
        "Candidate role hints are incompatible with the ",
        role,
        " slot: ",
        paste(hints, collapse = ", "),
        "."
      )
    ))
  }

  iri <- if ("iri" %in% names(candidate)) {
    tolower(.ms_semantic_trim_string(candidate$iri[[1]], default = ""))
  } else {
    ""
  }
  native_type <- .ms_semantic_validator_candidate_type(candidate)
  if (grepl(
    paste(
      c(
        "object\\s*property",
        "datatype\\s*property",
        "annotation\\s*property",
        "rdf\\s*property",
        "owl#objectproperty",
        "owl#datatypeproperty",
        "owl#annotationproperty"
      ),
      collapse = "|"
    ),
    native_type,
    perl = TRUE
  )) {
    return(.ms_semantic_validator_finding(
      code = "SEM_ROLE_TYPE_MISMATCH",
      role = role,
      message = paste0(
        "Candidate is an ontology relation predicate, not a value that can ",
        "populate the ",
        role,
        " semantic slot."
      )
    ))
  }
  explicit_type_role <- dplyr::case_when(
    grepl("/vocab/unit/|\\b(unit|unit of measure)\\b", paste(iri, native_type)) ~ "unit",
    grepl("/vocab/quantitykind/|\\b(quantity kind|quantitykind)\\b", paste(iri, native_type)) ~ "property",
    grepl("\\b(method|procedure)\\b", native_type) ~ "method",
    grepl("\\bconstraint\\b", native_type) ~ "constraint",
    TRUE ~ NA_character_
  )

  if (!is.na(explicit_type_role) && !identical(role, explicit_type_role)) {
    return(.ms_semantic_validator_finding(
      code = "SEM_ROLE_TYPE_MISMATCH",
      role = role,
      message = paste0(
        "Candidate native type is explicitly ",
        explicit_type_role,
        "-like and is incompatible with the ",
        role,
        " slot."
      )
    ))
  }

  .ms_empty_semantic_validator_findings()
}

.ms_semantic_validator_dimension <- function(...) {
  values <- unlist(list(...), recursive = TRUE, use.names = FALSE)
  values <- as.character(values)
  values <- values[!is.na(values) & nzchar(trimws(values))]
  if (length(values) == 0L) {
    return(NA_character_)
  }
  values <- vapply(values, function(value) {
    value <- tolower(trimws(value))
    value <- gsub("\u2212|\u207b", "-", value, perl = TRUE)
    value <- gsub("\u00b9", "1", value, fixed = TRUE)
    value <- gsub("\u00b2", "2", value, fixed = TRUE)
    value <- gsub("\u00b3", "3", value, fixed = TRUE)
    value <- gsub("\u00b7", " ", value, fixed = TRUE)
    gsub("\\s+", " ", value, perl = TRUE)
  }, character(1))
  text <- paste(values, collapse = " ")

  compound_rules <- list(
    flow = "^(cubic met(er|re)s? per second|m3/s|cumecs?|cms)$",
    speed = paste0(
      "^(kilomet(er|re)s? per hour|met(er|re)s? per second|",
      "km/h|m/s|kph)$"
    )
  )
  compound_match <- names(compound_rules)[vapply(
    compound_rules,
    function(pattern) any(grepl(pattern, values, perl = TRUE)),
    logical(1)
  )]
  if (length(compound_match) == 1L) {
    return(compound_match[[1L]])
  }
  if (length(compound_match) > 1L) {
    return(NA_character_)
  }

  time_unit <- paste0(
    "(s|sec|second|min|minute|h|hr|hour|d|day|wk|week|",
    "mo|month|yr|year|season)"
  )
  denominator_pattern <- paste0(
    "(\\bper\\s+", time_unit, "\\b",
    "|/\\s*", time_unit, "\\b",
    "|[-_]per[-_]", time_unit, "\\b",
    "|\\b", time_unit, "\\s*\\^?\\s*-\\s*1\\b)"
  )
  denominator_counts <- vapply(values, function(value) {
    matches <- gregexpr(
      denominator_pattern,
      value,
      perl = TRUE
    )[[1L]]
    if (identical(matches[[1L]], -1L)) 0L else length(matches)
  }, integer(1))
  denominator_count <- max(denominator_counts)
  powered_pattern <- paste0(
    "(\\bper\\s+|/\\s*|[-_]per[-_])",
    time_unit,
    "\\s*(\\^?\\s*[2-9]|squared|cubed)\\b"
  )
  powered_denominator <- any(vapply(
    values,
    function(value) grepl(powered_pattern, value, perl = TRUE),
    logical(1)
  ))
  if (denominator_count > 1L || powered_denominator) {
    return(NA_character_)
  }

  rules <- list(
    flow = "\\b(flow|discharge)\\b",
    speed = "\\b(speed|velocity)\\b",
    temperature = "\\b(temperature|celsius|fahrenheit|kelvin|deg c)\\b",
    area = paste0(
      "\\b(area|square[ -](milli|centi|kilo)?met(er|re)s?|m2|hectare)\\b"
    ),
    volume = paste0(
      "\\b(volume|lit(er|re)s?|cubic[ -]",
      "(milli|centi|kilo)?met(er|re)s?|m3)\\b"
    ),
    mass = "\\b(mass|weight|kilograms?|grams?|tonnes?|pounds?|lbs?|kg|kilogm|gm)\\b",
    length = "\\b(length|width|depth|height|fork length|millimet(er|re)s?|centimet(er|re)s?|met(er|re)s?|mm|cm|millim|centim)\\b",
    count = "\\b(count|abundance|number|numerosity|individuals?|num)\\b",
    dimensionless = paste0(
      "\\b(dimensionless|unitless|percentage|percent|proportion|ratio|",
      "fraction|decimal|dimensionlessratio)\\b|",
      "\\b(survival|exploitation|harvest|mortality) rate\\b|",
      "/vocab/unit/(percent|one)\\b"
    ),
    rate = paste0(
      "\\b(frequency|occurrences? per|individuals? per|fish per|",
      "events? per|per capita per)\\b"
    )
  )

  matched <- names(rules)[vapply(
    rules,
    function(pattern) grepl(pattern, text, perl = TRUE),
    logical(1)
  )]
  if (denominator_count == 1L) {
    matched <- unique(c(matched, "rate"))
  }
  strong_physical <- intersect(
    matched,
    c("flow", "speed", "temperature", "area", "volume", "mass", "length")
  )
  if (length(strong_physical) == 1L) {
    if ("rate" %in% matched) {
      return(NA_character_)
    }
    return(strong_physical[[1L]])
  }
  if (length(strong_physical) > 1L) {
    return(NA_character_)
  }
  if ("rate" %in% matched) {
    return("rate")
  }
  if (length(matched) == 1L) matched[[1]] else NA_character_
}

.ms_semantic_validator_candidate_dimension <- function(candidate) {
  candidate <- tibble::as_tibble(candidate)
  .ms_semantic_validator_dimension(
    if ("label" %in% names(candidate)) candidate$label[[1]] else NULL,
    if ("definition" %in% names(candidate)) {
      candidate$definition[[1]]
    } else {
      NULL
    },
    if ("iri" %in% names(candidate)) candidate$iri[[1]] else NULL
  )
}

.ms_validate_semantic_dimension <- function(role, candidate, dict_row) {
  if (!role %in% c("property", "unit")) {
    return(.ms_empty_semantic_validator_findings())
  }

  dict_row <- tibble::as_tibble(dict_row)
  expected <- .ms_semantic_validator_dimension(
    if ("unit_label" %in% names(dict_row)) dict_row$unit_label[[1]] else NULL,
    if ("unit_iri" %in% names(dict_row)) dict_row$unit_iri[[1]] else NULL
  )
  if (is.na(expected)) {
    return(.ms_empty_semantic_validator_findings())
  }

  candidate_dimension <- .ms_semantic_validator_candidate_dimension(candidate)
  if (is.na(candidate_dimension) || identical(candidate_dimension, expected)) {
    return(.ms_empty_semantic_validator_findings())
  }

  .ms_semantic_validator_finding(
    code = "SEM_DIMENSION_MISMATCH",
    role = role,
    message = paste0(
      "Candidate appears ",
      candidate_dimension,
      "-dimensional, but the dictionary unit is ",
      expected,
      "-dimensional."
    )
  )
}

.ms_validate_semantic_property_unit_pair <- function(role,
                                                     selected_candidates) {
  if (!role %in% c("property", "unit") ||
      is.null(selected_candidates$property) ||
      is.null(selected_candidates$unit)) {
    return(.ms_empty_semantic_validator_findings())
  }

  property_dimension <- .ms_semantic_validator_candidate_dimension(
    selected_candidates$property
  )
  unit_dimension <- .ms_semantic_validator_candidate_dimension(
    selected_candidates$unit
  )
  if (is.na(property_dimension) ||
      is.na(unit_dimension) ||
      identical(property_dimension, unit_dimension)) {
    return(.ms_empty_semantic_validator_findings())
  }

  .ms_semantic_validator_finding(
    code = "SEM_PROPERTY_UNIT_DIMENSION_MISMATCH",
    role = role,
    message = paste0(
      "The accepted property is ",
      property_dimension,
      "-dimensional, while the accepted unit is ",
      unit_dimension,
      "-dimensional; both require review as a pair."
    )
  )
}

.ms_semantic_curated_redundancy_rules <- function() {
  tibble::tibble(
    code = "SEM_REDUNDANT_CATCH_CONTEXT",
    role = "constraint",
    candidate_iri = "https://w3id.org/smn/CatchContext",
    paired_role = "variable",
    paired_iri = "https://w3id.org/smn/CatchAbundance",
    message = paste(
      "CatchContext duplicates the accepted CatchAbundance framing when no",
      "additional constraint evidence is present."
    )
  )
}

.ms_validate_semantic_redundancy <- function(role,
                                             candidate,
                                             selected_iris,
                                             evidence_text) {
  candidate <- tibble::as_tibble(candidate)
  candidate_iri <- if ("iri" %in% names(candidate)) {
    .ms_semantic_trim_string(candidate$iri[[1]], default = "")
  } else {
    ""
  }
  if (!nzchar(candidate_iri)) {
    return(.ms_empty_semantic_validator_findings())
  }

  rules <- .ms_semantic_curated_redundancy_rules()
  matches <- rules$role == role &
    rules$candidate_iri == candidate_iri &
    vapply(seq_len(nrow(rules)), function(i) {
      paired_role <- rules$paired_role[[i]]
      paired_iri <- selected_iris[[paired_role]] %||% NA_character_
      identical(.ms_semantic_trim_string(paired_iri, default = ""), rules$paired_iri[[i]])
    }, logical(1))
  matches <- matches & !.ms_semantic_validator_has_constraint_evidence(evidence_text)
  if (!any(matches)) {
    return(.ms_empty_semantic_validator_findings())
  }

  dplyr::transmute(
    rules[matches, , drop = FALSE],
    code = .data$code,
    severity = "warning",
    role = .data$role,
    before_decision = "accept",
    after_decision = "review",
    message = .data$message
  )
}

.ms_semantic_validator_field_anchors <- function(target, dict_row) {
  target <- tibble::as_tibble(target)
  dict_row <- tibble::as_tibble(dict_row)
  field_names <- c(
    if ("column_name" %in% names(dict_row)) dict_row$column_name[[1]] else NULL,
    if ("column_name" %in% names(target)) target$column_name[[1]] else NULL
  )
  field_names <- field_names[
    !is.na(field_names) & nzchar(trimws(field_names))
  ]
  labels <- c(
    if ("column_label" %in% names(dict_row)) dict_row$column_label[[1]] else NULL,
    if ("column_label" %in% names(target)) target$column_label[[1]] else NULL
  )
  candidates <- if (length(field_names) > 0L) field_names else labels
  if (length(candidates) == 0L) {
    return(character())
  }

  weak_singletons <- c(
    "age", "code", "count", "length", "method", "number", "phase",
    "rate", "sex", "total", "unit", "value", "weight"
  )
  anchors <- lapply(unique(as.character(candidates)), function(candidate) {
    identifier <- tolower(trimws(candidate))
    phrase <- trimws(gsub("[^a-z0-9]+", " ", identifier))
    tokens <- .ms_context_tokens(phrase)
    if (!nzchar(phrase) ||
        (length(tokens) < 2L &&
          (nchar(phrase) < 6L || phrase %in% weak_singletons))) {
      return(character())
    }

    c(
      if (length(field_names) > 0L &&
          grepl("^[a-z0-9_]+$", identifier)) {
        paste0("identifier:", identifier)
      },
      paste0("phrase_start:", phrase)
    )
  })
  unique(unlist(anchors, use.names = FALSE))
}

.ms_semantic_validator_chunk_has_anchor <- function(text, anchor) {
  raw_text <- as.character(text %||% "")
  text <- tolower(raw_text)
  anchor <- tolower(trimws(as.character(anchor %||% "")))
  if (!nzchar(text) || !nzchar(anchor)) {
    return(FALSE)
  }

  if (startsWith(anchor, "identifier:")) {
    identifier <- sub("^identifier:", "", anchor)
    tokens <- unlist(
      strsplit(text, "[^a-z0-9_]+", perl = TRUE),
      use.names = FALSE
    )
    return(identifier %in% tokens)
  }

  phrase <- sub("^phrase_start:", "", anchor)
  unmarked_text <- sub(
    "^\\s*(?:[[:punct:]0-9]+\\s*)+",
    "",
    raw_text,
    perl = TRUE
  )
  leading_token <- sub(
    "^\\s*([a-zA-Z0-9][a-zA-Z0-9_-]*).*$",
    "\\1",
    unmarked_text,
    perl = TRUE
  )
  if (grepl("[_-]", leading_token)) {
    return(FALSE)
  }
  normalized <- trimws(gsub(
    "[^a-z0-9]+",
    " ",
    tolower(unmarked_text)
  ))
  identical(normalized, phrase) ||
    startsWith(normalized, paste0(phrase, " "))
}

.ms_semantic_bundle_validator_evidence <- function(target,
                                                   dict_row,
                                                   context_chunks) {
  target <- tibble::as_tibble(target)
  dict_row <- tibble::as_tibble(dict_row)
  context_chunks <- tibble::as_tibble(context_chunks)
  context_text <- if ("chunk_text" %in% names(context_chunks)) {
    anchors <- .ms_semantic_validator_field_anchors(target, dict_row)
    relevant <- vapply(context_chunks$chunk_text, function(text) {
      any(vapply(
        anchors,
        function(anchor) .ms_semantic_validator_chunk_has_anchor(text, anchor),
        logical(1)
      ))
    }, logical(1))
    context_chunks$chunk_text[relevant]
  } else {
    NULL
  }

  .ms_semantic_validator_text(
    target[intersect(
      c(
        "target_query_context",
        "column_label",
        "column_description"
      ),
      names(target)
    )],
    dict_row[intersect(
      c("column_name", "column_label", "column_description", "unit_label"),
      names(dict_row)
    )],
    context_text
  )
}

.ms_semantic_bundle_current_selected_iris <- function(assessments, dict_row) {
  fields <- .ms_semantic_bundle_slot_fields()
  selected <- stats::setNames(rep(NA_character_, length(fields)), names(fields))
  for (role in names(fields)) {
    field <- fields[[role]]
    if (field %in% names(dict_row)) {
      value <- .ms_semantic_trim_string(
        dict_row[[field]][[1]],
        default = ""
      )
      if (nzchar(value) && !grepl("^REVIEW:\\s*", value, ignore.case = TRUE)) {
        selected[[role]] <- value
      }
    }
  }

  accepted <- assessments$llm_decision == "accept" &
    !is.na(assessments$llm_selected_iri) &
    nzchar(trimws(assessments$llm_selected_iri))
  for (i in which(accepted)) {
    selected[[assessments$dictionary_role[[i]]]] <- assessments$llm_selected_iri[[i]]
  }
  selected
}

.ms_semantic_bundle_selected_candidates <- function(assessments,
                                                    candidate_groups,
                                                    targets) {
  targets <- tibble::as_tibble(targets)
  selected <- list()
  accepted <- which(
    assessments$llm_decision == "accept" &
      !is.na(assessments$llm_selected_candidate_index)
  )
  for (i in accepted) {
    role <- assessments$dictionary_role[[i]]
    target_index <- match(role, targets$dictionary_role)
    if (is.na(target_index)) {
      next
    }
    key <- .ms_semantic_group_key_df(
      targets[target_index, , drop = FALSE]
    )[[1]]
    candidates <- .ms_semantic_candidate_rows(candidate_groups[[key]])
    selected_index <- assessments$llm_selected_candidate_index[[i]]
    if (selected_index < 1L || selected_index > nrow(candidates)) {
      next
    }
    selected[[role]] <- candidates[selected_index, , drop = FALSE]
  }
  selected
}

.ms_semantic_apply_bundle_validators <- function(assessments,
                                                 candidate_groups,
                                                 targets,
                                                 dict_row,
                                                 context_chunks) {
  assessments <- .ms_llm_normalize_assessment_rows(assessments)
  targets <- tibble::as_tibble(targets)
  selected_iris <- .ms_semantic_bundle_current_selected_iris(assessments, dict_row)
  selected_candidates <- .ms_semantic_bundle_selected_candidates(
    assessments,
    candidate_groups,
    targets
  )
  findings <- list()

  for (i in seq_len(nrow(assessments))) {
    if (!identical(assessments$llm_decision[[i]], "accept")) {
      next
    }

    role <- assessments$dictionary_role[[i]]
    target_index <- match(role, targets$dictionary_role)
    if (is.na(target_index)) {
      next
    }
    target <- targets[target_index, , drop = FALSE]
    key <- .ms_semantic_group_key_df(target)[[1]]
    candidates <- .ms_semantic_candidate_rows(candidate_groups[[key]])
    selected_index <- assessments$llm_selected_candidate_index[[i]]
    if (is.na(selected_index) ||
        selected_index < 1L ||
        selected_index > nrow(candidates)) {
      next
    }

    candidate <- candidates[selected_index, , drop = FALSE]
    evidence_text <- .ms_semantic_bundle_validator_evidence(
      target,
      dict_row,
      context_chunks
    )
    row_findings <- dplyr::bind_rows(
      .ms_validate_semantic_method_evidence(role, evidence_text),
      .ms_validate_semantic_constraint_evidence(role, evidence_text),
      .ms_validate_semantic_role_type(role, candidate),
      .ms_validate_semantic_dimension(role, candidate, dict_row),
      .ms_validate_semantic_property_unit_pair(
        role,
        selected_candidates
      ),
      .ms_validate_semantic_redundancy(
        role,
        candidate,
        selected_iris,
        evidence_text
      )
    )
    if (nrow(row_findings) == 0L) {
      next
    }

    findings[[length(findings) + 1L]] <- dplyr::mutate(
      row_findings,
      dataset_id = assessments$dataset_id[[i]],
      table_id = assessments$table_id[[i]],
      column_name = assessments$column_name[[i]],
      .before = 1L
    )
    notes <- paste0(
      "[",
      row_findings$code,
      "] ",
      row_findings$message,
      collapse = " "
    )
    rationale <- .ms_llm_non_empty_string(
      assessments$llm_rationale[[i]] %||% NA_character_
    )
    assessments$llm_decision[[i]] <- "review"
    assessments$llm_selected_candidate_index[[i]] <- NA_integer_
    assessments$llm_selected_iri[[i]] <- NA_character_
    assessments$llm_selected_label[[i]] <- NA_character_
    assessments$llm_rationale[[i]] <- if (is.na(rationale)) {
      notes
    } else {
      paste(rationale, notes)
    }
  }

  finding_rows <- if (length(findings) == 0L) {
    dplyr::mutate(
      .ms_empty_semantic_validator_findings(),
      dataset_id = character(),
      table_id = character(),
      column_name = character(),
      .before = 1L
    )
  } else {
    dplyr::bind_rows(findings)
  } |>
    dplyr::select(
      dplyr::all_of(c(
        "dataset_id",
        "table_id",
        "column_name",
        .ms_semantic_validator_finding_cols()
      ))
    )

  list(
    assessments = assessments,
    findings = finding_rows
  )
}
