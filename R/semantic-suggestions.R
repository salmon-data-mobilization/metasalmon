.ms_semantic_target_cols <- function() {
  c(
    "dataset_id",
    "table_id",
    "column_name",
    "code_value",
    "dictionary_role",
    "search_role",
    "target_scope",
    "target_sdp_file",
    "target_sdp_field",
    "target_row_key",
    "target_label",
    "target_description",
    "search_query",
    "target_query_basis",
    "target_query_context",
    "column_label",
    "column_description",
    "code_label",
    "code_description"
  )
}

.ms_semantic_suggestion_leading_cols <- function() {
  c(
    "column_name",
    "dictionary_role",
    "table_id",
    "dataset_id",
    "target_row_key",
    "target_label",
    "target_description",
    "target_scope",
    "target_sdp_file",
    "target_sdp_field",
    "search_query",
    "target_query_basis",
    "target_query_context",
    "column_label",
    "column_description",
    "code_value",
    "code_label",
    "code_description"
  )
}

.ms_semantic_target_group_cols <- function() {
  c(
    "dataset_id",
    "table_id",
    "column_name",
    "code_value",
    "dictionary_role",
    "target_scope",
    "target_sdp_file",
    "target_sdp_field"
  )
}

.ms_semantic_assessment_join_cols <- function() {
  c(.ms_semantic_target_group_cols(), "search_query")
}

.ms_semantic_bundle_group_cols <- function() {
  c("dataset_id", "table_id", "column_name")
}

.ms_semantic_key_df <- function(df, group_cols) {
  df <- tibble::as_tibble(df)
  missing_cols <- setdiff(group_cols, names(df))
  for (nm in missing_cols) {
    df[[nm]] <- NA_character_
  }

  do.call(
    paste,
    c(
      lapply(df[group_cols], function(x) ifelse(is.na(x), "<NA>", as.character(x))),
      sep = "\r"
    )
  )
}

.ms_semantic_group_key_df <- function(df) {
  .ms_semantic_key_df(df, .ms_semantic_target_group_cols())
}

.ms_semantic_bundle_key_df <- function(df) {
  .ms_semantic_key_df(df, .ms_semantic_bundle_group_cols())
}

.ms_semantic_add_missing_cols <- function(df, cols, value = NA_character_) {
  df <- tibble::as_tibble(df)
  missing_cols <- setdiff(cols, names(df))
  for (nm in missing_cols) {
    df[[nm]] <- value
  }
  df
}

.ms_semantic_normalize_target_rows <- function(targets, cols = .ms_semantic_suggestion_leading_cols()) {
  .ms_semantic_add_missing_cols(targets, cols)
}

.ms_semantic_candidate_rows <- function(candidate_rows = NULL) {
  if (is.null(candidate_rows)) {
    candidate_rows <- tibble::tibble()
  }

  candidate_rows <- tibble::as_tibble(candidate_rows)
  required <- c("label", "iri", "source", "ontology", "definition")
  candidate_rows <- .ms_semantic_add_missing_cols(candidate_rows, required)
  if (!"score" %in% names(candidate_rows)) {
    candidate_rows$score <- NA_real_
  }
  if (!"llm_selected" %in% names(candidate_rows)) {
    candidate_rows$llm_selected <- NA
  }

  candidate_rows
}

.ms_semantic_trim_string <- function(x, default = NA_character_) {
  if (is.null(x) || length(x) == 0) {
    return(default)
  }

  text <- trimws(as.character(x[[1]]))
  if (is.na(text) || !nzchar(text)) {
    return(default)
  }

  text
}

.ms_semantic_text_hash <- function(x) {
  ints <- utf8ToInt(enc2utf8(paste(x, collapse = "\r")))
  if (length(ints) == 0L) {
    return("0000000000000000")
  }

  rolling_hash <- function(multiplier, seed, modulus) {
    value <- as.double(seed)
    for (int in ints) {
      value <- (value * multiplier + int) %% modulus
    }
    sprintf("%08x", as.integer(value))
  }

  paste0(
    rolling_hash(131, 216613626, 2147483629),
    rolling_hash(137, 16777619, 2147483587)
  )
}

.ms_semantic_candidate_identity <- function(candidate_rows, role = NULL) {
  candidate_rows <- .ms_semantic_candidate_rows(candidate_rows)
  if (nrow(candidate_rows) == 0L) {
    return(character())
  }

  role_values <- if (!is.null(role) && length(role) > 0L) {
    rep(as.character(role[[1]]), nrow(candidate_rows))
  } else if ("dictionary_role" %in% names(candidate_rows)) {
    as.character(candidate_rows$dictionary_role)
  } else if ("role" %in% names(candidate_rows)) {
    as.character(candidate_rows$role)
  } else {
    rep("unknown", nrow(candidate_rows))
  }
  role_values[is.na(role_values) | !nzchar(trimws(role_values))] <- "unknown"

  fingerprint_value <- function(column, index) {
    if (!column %in% names(candidate_rows)) {
      return("")
    }
    value <- candidate_rows[[column]][[index]]
    if (is.null(value) || length(value) == 0L || all(is.na(value))) {
      return("")
    }
    paste(as.character(value), collapse = "|")
  }
  fingerprint_columns <- c(
    "ontology", "label", "definition", "match_type", "role_hints",
    "resource_kind", "type_iris", "term_type"
  )

  ids <- vapply(seq_len(nrow(candidate_rows)), function(i) {
    iri <- .ms_semantic_trim_string(candidate_rows$iri[[i]])
    source <- .ms_semantic_trim_string(
      candidate_rows$source[[i]],
      default = "unknown"
    )
    if (!is.na(iri)) {
      return(paste(source, iri, sep = "::"))
    }

    fingerprint <- .ms_semantic_text_hash(c(
      role_values[[i]],
      source,
      vapply(
        fingerprint_columns,
        fingerprint_value,
        character(1),
        index = i
      )
    ))
    paste("blank", role_values[[i]], fingerprint, sep = "::")
  }, character(1))
  ids
}

# Whether a `codes.csv` row's `code_value` is empty, which gives the row no
# semantic target in any role (hub item B-276, ruled by Brett 2026-09-25). The
# codes schema defines `term_iri` as "the specific term that code_value
# represents" and lets a row leave `code_value` empty when it supplies
# `vocabulary_iri` instead, so such a row has no code value for a term to
# represent. Empty is NA, or text that is empty once trimmed: the review console
# reads a code value trimmed, so a blank one had no address there either. The
# text "NA" is a code value, not an empty one.
#
# One predicate for both places the rule is applied: target discovery, which
# forms no target for such a row, and `review_semantics()`, which drops one
# from suggestions recorded before the rule existed.
.ms_semantic_code_value_is_empty <- function(code_value) {
  is.na(code_value) | !nzchar(trimws(as.character(code_value)))
}

.ms_semantic_discover_targets <- function(dict,
                                      codes,
                                      table_meta,
                                      dataset_meta,
                                      resource_lookup = NULL,
                                      default_df = NULL) {
  roles <- c(
    term_iri = "variable",
    property_iri = "property",
    entity_iri = "entity",
    unit_iri = "unit",
    constraint_iri = "constraint",
    statistical_modifier_iri = "statistical_modifier"
  )
  target_cols <- .ms_semantic_target_cols()

  is_missing <- function(x) {
    if (is.null(x) || length(x) == 0) return(TRUE)
    all(is.na(x) | as.character(x) == "")
  }
  is_present <- function(x) !is_missing(x)
  # NOTE: intentionally distinct from module-level .ms_semantic_first_non_empty():
  # this takes a list, returns "" (not NA) when nothing is present, and does not
  # trim each value. Discovery query-building depends on the empty -> "" behaviour,
  # so do not consolidate the two without reconciling those semantics.
  first_non_empty <- function(values) {
    values <- values[!vapply(values, is_missing, logical(1))]
    if (length(values) == 0) "" else values[[1]]
  }
  decamelize_text <- function(x) {
    x <- as.character(x %||% "")
    x[is.na(x)] <- ""
    gsub("([a-z0-9])([A-Z])", "\\1 \\2", x, perl = TRUE)
  }
  clean_query <- function(x) {
    x <- as.character(x %||% "")
    x[is.na(x)] <- ""
    x <- decamelize_text(x)
    x <- gsub("[._]+", " ", x)
    x <- gsub("\\s+", " ", x)
    trimws(x)
  }
  is_review_placeholder <- function(x) {
    if (is_missing(x)) return(FALSE)
    grepl("^\\s*(REVIEW REQUIRED|MISSING DESCRIPTION|MISSING METADATA)\\s*:", as.character(x), ignore.case = TRUE)
  }
  strip_review_placeholder <- function(x) {
    text <- as.character(x %||% "")
    text[is.na(text)] <- ""
    text <- sub("^\\s*(REVIEW REQUIRED|MISSING DESCRIPTION|MISSING METADATA)\\s*:\\s*", "", text, ignore.case = TRUE)
    text <- sub("^\\s*define what\\s+'?", "", text, ignore.case = TRUE)
    text <- sub("'?\\s*means in table.*$", "", text, ignore.case = TRUE)
    clean_query(text)
  }
  table_context <- function(row, dict) {
    if (!all(c("dataset_id", "table_id") %in% names(dict))) {
      return(tibble::tibble())
    }

    same <- dict[dict$dataset_id == row$dataset_id[[1]] & dict$table_id == row$table_id[[1]], , drop = FALSE]
    if (!"column_name" %in% names(same)) {
      return(same)
    }
    same[same$column_name != row$column_name[[1]], , drop = FALSE]
  }
  context_has <- function(ctx, pattern) {
    if (nrow(ctx) == 0) return(FALSE)
    candidates <- c(
      if ("column_name" %in% names(ctx)) as.character(ctx$column_name) else character(),
      if ("column_label" %in% names(ctx)) as.character(ctx$column_label) else character(),
      if ("column_description" %in% names(ctx)) as.character(ctx$column_description) else character()
    )
    candidates <- candidates[!is.na(candidates) & nzchar(trimws(candidates))]
    if (length(candidates) == 0) return(FALSE)
    any(grepl(pattern, candidates, ignore.case = TRUE))
  }
  current_table_df <- function(row) {
    if (is.null(resource_lookup)) {
      return(default_df)
    }

    table_id <- as.character(row$table_id[[1]] %||% "")
    if (nzchar(table_id) && table_id %in% names(resource_lookup)) {
      return(resource_lookup[[table_id]])
    }

    default_df
  }
  normalize_measurement_unit_query <- function(x) {
    text <- tolower(as.character(x %||% ""))
    text[is.na(text)] <- ""
    text <- decamelize_text(text)
    text <- gsub("\u00e2", "", text, fixed = TRUE)
    text <- gsub("\u00b0", " degree ", text, fixed = TRUE)
    text <- gsub("\u00b3", "3", text, fixed = TRUE)
    text <- clean_query(text)
    text <- gsub("[^a-z0-9/ ]+", " ", text)
    text <- clean_query(text)
    if (!nzchar(text)) return("")

    if (grepl("\\b(degree\\s*c|deg\\s*c|celsius)\\b", text)) return("degree celsius")
    if (grepl("^(cms|cumec|cumecs|m3/s|m\\^3/s|m3 s)$", text)) return("cubic meter per second")
    if (grepl("^(km/h|km h|kph)$", text)) return("kilometer per hour")
    if (grepl("^(square\\s+met(er|re)s?|sq\\s*m|m2)$", text)) return("square meter")
    if (grepl("^(mm|millimet(er|re)s?)$", text)) return("millimeter")
    if (grepl("^(cm|centimet(er|re)s?)$", text)) return("centimeter")
    if (grepl("^(m|met(er|re)s?)$", text)) return("meter")
    if (grepl("^(g|gram(me)?s?)$", text)) return("gram")
    if (grepl("^(kg|kilogram(me)?s?)$", text)) return("kilogram")

    ""
  }
  # A unit named by the last token of a column name or label: `fish_length_mm`,
  # `fork_length_cm`, `weightKg`, `depth_m` (hub item B-440). Without this, a
  # numeric column whose name mentioned fish was taken for a count and seeded
  # the QUDT COUNT unit. Only the length and mass units the normalizer above
  # already spells are read here; `cms`, `m2` and `km/h` stay with the whole-text
  # patterns, which see them in context.
  #
  # Metres and grams are read only beside a word for the quantity they measure,
  # because a bare `m` or `g` suffix is as often "males" or "group", and
  # `water_meter` is a device. Millimetres, centimetres and kilograms are not
  # ambiguous in a column name, so they need no such word.
  #
  # Returns the normalized unit query ("" when there is none) and the tokens
  # before it, so the variable query can drop the unit token.
  unit_suffix_length_words <- c(
    "length", "len", "depth", "height", "width", "distance", "dist",
    "elevation", "elev", "altitude", "diameter"
  )
  unit_suffix_mass_words <- c("weight", "wt", "mass")
  # Tokens that, just before the last one, make it the denominator of a ratio
  # (`mg_kg`, `eggs_per_kg`) rather than the unit of the whole column.
  unit_suffix_ratio_leads <- c(
    "per", "ng", "ug", "mg", "g", "kg", "mm", "cm", "m", "km",
    "ml", "l", "mol", "mmol", "umol", "ppm", "ppt"
  )
  trailing_unit_token <- function(text) {
    cleaned <- tolower(clean_query(gsub("\\([^)]*\\)", " ", as.character(text %||% ""))))
    tokens <- strsplit(cleaned, "[^a-z0-9]+")[[1]]
    tokens <- tokens[nzchar(tokens)]
    # A name that is only a unit (`mm`) names no measurement to attach it to.
    if (length(tokens) < 2) {
      return(list(unit = "", stem = tokens))
    }
    stem <- tokens[-length(tokens)]
    # A compound unit is a ratio: `mercury_mg/kg` is a concentration, and its
    # last token is only the denominator, so reading it would draft kilogram
    # for something that is not a mass (Codex review of #285). Nothing is read,
    # which leaves the unit unresolved as it was before B-440.
    if (
      grepl("/\\s*[a-z0-9]+\\s*$", cleaned) ||
        stem[[length(stem)]] %in% unit_suffix_ratio_leads
    ) {
      return(list(unit = "", stem = stem))
    }

    unit <- normalize_measurement_unit_query(tokens[[length(tokens)]])
    unit <- switch(
      unit,
      millimeter = ,
      centimeter = ,
      kilogram = unit,
      meter = if (any(stem %in% unit_suffix_length_words)) unit else "",
      gram = if (any(stem %in% unit_suffix_mass_words)) unit else "",
      ""
    )

    list(unit = unit, stem = stem)
  }
  extract_measurement_header_unit <- function(...) {
    texts <- unlist(list(...), use.names = FALSE)
    texts <- as.character(texts)
    texts <- texts[!is.na(texts) & nzchar(trimws(texts))]
    if (length(texts) == 0) return("")

    for (text in texts) {
      matches <- gregexpr("\\(([^)]{1,20})\\)", text, perl = TRUE)
      pieces <- regmatches(text, matches)[[1]]
      if (length(pieces) > 0) {
        pieces <- trimws(gsub("^\\(|\\)$", "", pieces))
        pieces <- pieces[nzchar(pieces)]
        if (length(pieces) > 0) {
          normalized <- normalize_measurement_unit_query(utils::tail(pieces, 1))
          if (nzchar(normalized)) {
            return(normalized)
          }
        }
      }

      normalized_full_text <- normalize_measurement_unit_query(text)
      if (nzchar(normalized_full_text)) {
        return(normalized_full_text)
      }

      suffix_text <- tolower(clean_query(gsub("\\([^)]*\\)", " ", text)))
      suffix_match <- regmatches(
        suffix_text,
        regexpr("\\bin\\s+(square\\s+met(?:er|re)s?|met(?:er|re)s?|centimet(?:er|re)s?|millimet(?:er|re)s?|degree\\s+celsius|celsius|kilomet(?:er|re)\\s+per\\s+hour|km/h|cms|cumecs|m3/s)\\b", suffix_text, perl = TRUE)
      )
      if (length(suffix_match) == 1 && nzchar(suffix_match)) {
        normalized <- normalize_measurement_unit_query(sub("^in\\s+", "", suffix_match))
        if (nzchar(normalized)) {
          return(normalized)
        }
      }

      trailing_unit <- trailing_unit_token(text)$unit
      if (nzchar(trailing_unit)) {
        return(trailing_unit)
      }
    }

    ""
  }
  paired_unit_query_from_data <- function(row) {
    column_name <- as.character(row$column_name[[1]] %||% "")
    if (!nzchar(column_name) || !grepl("value$", column_name, ignore.case = TRUE)) {
      return("")
    }

    table_df <- current_table_df(row)
    if (is.null(table_df) || !inherits(table_df, "data.frame")) {
      return("")
    }

    stem <- sub("value$", "", column_name, ignore.case = TRUE)
    sibling_hits <- names(table_df)[tolower(names(table_df)) == paste0(tolower(stem), "unit")]
    if (length(sibling_hits) == 0) {
      return("")
    }

    sibling_values <- as.character(table_df[[sibling_hits[[1]]]])
    sibling_values <- trimws(sibling_values[!is.na(sibling_values)])
    sibling_values <- sibling_values[nzchar(sibling_values)]
    if (length(sibling_values) == 0) {
      return("")
    }

    sibling_values <- sort(table(sibling_values), decreasing = TRUE)
    normalized <- normalize_measurement_unit_query(names(sibling_values)[[1]])
    if (!nzchar(normalized)) {
      return("")
    }

    normalized
  }
  normalize_measurement_header_query <- function(x) {
    text <- clean_query(x)
    if (!nzchar(text)) return("")

    text <- gsub("\\([^)]*\\)", " ", text)
    if (grepl("\\s/\\s", text)) {
      text <- strsplit(text, "\\s/\\s", perl = TRUE)[[1]][1]
    }
    text <- tolower(clean_query(text))
    text <- gsub("\\bin\\s+(square\\s+met(?:er|re)s?|met(?:er|re)s?|centimet(?:er|re)s?|millimet(?:er|re)s?|degree\\s+celsius|celsius|kilomet(?:er|re)\\s+per\\s+hour|km/h|cms|cumecs|m3/s)\\b", " ", text, perl = TRUE)
    # The unit suffix the unit query reads (`fish_length_mm`) is not part of
    # what is measured, so the variable query is `fish length`, not
    # `fish length mm` (hub item B-440).
    trailing_unit <- trailing_unit_token(text)
    if (nzchar(trailing_unit$unit)) {
      text <- paste(trailing_unit$stem, collapse = " ")
    }
    replacements <- c(
      "\\btemp\\b" = "temperature",
      "\\bspd\\b" = "speed",
      "\\bdir\\b" = "direction",
      "\\bmax\\b" = "maximum",
      "\\bmin\\b" = "minimum",
      "\\bgrnd\\b" = "ground"
    )
    for (pattern in names(replacements)) {
      text <- gsub(pattern, replacements[[pattern]], text, perl = TRUE)
    }

    if (grepl("\\btotal rain\\b", text)) return("rainfall")
    if (grepl("\\btotal snow\\b", text)) return("snowfall")
    if (grepl("\\bwater level\\b", text)) return("water level")
    if (grepl("\\bdischarge\\b", text)) return("discharge")

    clean_query(text)
  }
  is_count_like_measurement <- function(row, base_query) {
    value_type <- tolower(as.character(row$value_type[[1]] %||% ""))
    text <- tolower(clean_query(paste(
      strip_review_placeholder(row$column_name[[1]]),
      strip_review_placeholder(row$column_label[[1]]),
      base_query
    )))
    if (!nzchar(text)) return(FALSE)

    has_explicit_count <- grepl("\\b(count|counts|number|numbers|num|abundance)\\b", text)
    # A column that names a physical quantity measures that quantity, whatever
    # organism it is measured on: `fish_length_mm` is a length, not a count of
    # fish, and searching it as a count seeded the QUDT COUNT unit and a count
    # variable (hub item B-440). Only an explicit count word overrides it.
    names_physical_quantity <- grepl(
      "\\b(length|len|weight|wt|mass|depth|height|width|diameter|girth|distance|temperature|temp)\\b",
      text
    )
    if (names_physical_quantity && !has_explicit_count) {
      return(FALSE)
    }
    has_total <- grepl("\\btotal\\b", text)
    has_organism <- grepl(
      "\\b(spawner|spawners|fish|salmon|organism|organisms|recruit|recruits|smolt|smolts|fry|juvenile|juveniles|population|populations|adult|adults)\\b",
      text
    )
    looks_integer <- value_type %in% c("integer", "int", "number", "numeric", "double")

    has_explicit_count ||
      (has_total && has_organism) ||
      (grepl("\\babundance\\b", text) && (has_organism || looks_integer)) ||
      (looks_integer && has_organism)
  }
  measurement_role_query <- function(row, dict, role_name) {
    desc_query <- if (is_review_placeholder(row$column_description[[1]])) {
      ""
    } else {
      strip_review_placeholder(row$column_description[[1]])
    }
    label_query <- strip_review_placeholder(row$column_label[[1]])
    name_query <- strip_review_placeholder(row$column_name[[1]])
    base_query <- if (nzchar(desc_query)) {
      clean_query(desc_query)
    } else {
      normalize_measurement_header_query(first_non_empty(list(label_query, name_query)))
    }
    if (!nzchar(base_query)) return("")

    base_lower <- tolower(base_query)
    # The full column text, for evidence checks that must not depend on which
    # single field won the query-preference order: `mean_temperature` with a
    # description that never says "mean" still names its aggregation.
    all_text_lower <- tolower(paste(desc_query, label_query, name_query))
    ctx <- table_context(row, dict)

    if (identical(role_name, "unit")) {
      unit_query <- strip_review_placeholder(row$unit_label[[1]])
      if (!nzchar(unit_query)) {
        unit_query <- extract_measurement_header_unit(row$column_label[[1]], row$column_name[[1]])
      }
      if (!nzchar(unit_query)) {
        unit_query <- paired_unit_query_from_data(row)
      }
      if (nzchar(unit_query)) {
        return(unit_query)
      }
      if (is_count_like_measurement(row, base_query)) {
        return("count")
      }
      return("")
    }

    if (identical(role_name, "constraint")) {
      if (grepl("\\bnatural\\b", base_lower)) return("natural origin")
      if (grepl("\\bhatchery\\b", base_lower)) return("hatchery origin")
      return(base_query)
    }

    if (identical(role_name, "statistical_modifier")) {
      # Part of variable identity, and deliberately conservative: a
      # statistical-modifier target is emitted only when the column text
      # names an aggregation, so plain measurements do not gain a slot.
      # Checked across name, label, AND description — the aggregation is
      # often only in the column name (`mean_temperature`), and underscores
      # do not form \b word boundaries, so they are split first.
      modifier_text <- gsub("[_.]", " ", all_text_lower)
      if (grepl("\\b(total|cumulative|sum)\\b", modifier_text)) return("total")
      if (grepl("\\b(mean|average)\\b", modifier_text)) return("mean")
      if (grepl("\\bmax(imum)?\\b", modifier_text)) return("maximum")
      if (grepl("\\bmin(imum)?\\b", modifier_text)) return("minimum")
      if (grepl("\\bpeak\\b", modifier_text)) return("peak")
      return("")
    }

    if (identical(role_name, "entity")) {
      if (context_has(ctx, "stock")) return("stock")
      if (context_has(ctx, "population")) return("population")
      if (grepl("spawner", base_lower)) return("population")
      return(base_query)
    }

    if (role_name %in% c("variable", "property")) {
      if (is_count_like_measurement(row, base_query)) {
        if (grepl("spawner", base_lower)) {
          if (identical(role_name, "variable")) {
            if (
              (
                grepl("\\beffective\\b", base_lower) &&
                  grepl("\\bfemale\\b", base_lower)
              ) ||
                grepl("\\beggs?\\s+not\\s+spawned\\b", base_lower)
            ) {
              return("effective female spawner abundance")
            }
            if (grepl("adult", base_lower)) return("adult spawner count")
            return("spawner abundance")
          }
          return("spawner abundance")
        }

        if (identical(role_name, "variable")) {
          if (grepl("\\brecruits?\\b", base_lower)) {
            return("recruit abundance")
          }
          if (grepl("\\bsmolts?\\b", base_lower)) {
            return("smolt abundance")
          }
          if (grepl("\\bfry\\b", base_lower)) {
            return("fry abundance")
          }
        }

        if (grepl("\\babundance\\b", base_lower)) {
          return("abundance")
        }

        if (identical(role_name, "variable")) {
          return("count")
        }
        return("count")
      }
    }

    base_query
  }
  expand_attribute_tokens <- function(x) {
    text <- clean_query(x)
    if (!nzchar(text)) return("")

    text <- tolower(text)
    replacements <- c(
      "\\bcu\\b" = "conservation unit",
      "\\bcus\\b" = "conservation units",
      "\\bwaterbody\\b" = "water body",
      "\\bcde\\b" = "code",
      "\\bdtt\\b" = "date time",
      "\\byr\\b" = "year",
      "\\bpfma\\b" = "pacific fisheries management area",
      "\\byn\\b" = "indicator",
      "\\bavg\\b" = "average"
    )

    for (pattern in names(replacements)) {
      text <- gsub(pattern, replacements[[pattern]], text, perl = TRUE)
    }

    clean_query(text)
  }
  extract_taxon_like_phrase <- function(x) {
    text <- expand_attribute_tokens(x)
    if (!nzchar(text)) return("")

    named_patterns <- c(
      "atlantic salmon",
      "chinook salmon",
      "coho salmon",
      "sockeye salmon",
      "chum salmon",
      "pink salmon",
      "steelhead trout",
      "rainbow trout",
      "cutthroat trout",
      "salmo salar"
    )
    for (pattern in named_patterns) {
      if (grepl(paste0("\\b", pattern, "\\b"), text, perl = TRUE)) {
        return(pattern)
      }
    }

    latin_match <- regmatches(text, regexpr("\\boncorhynchus\\s+[a-z]+\\b", text, perl = TRUE))
    if (length(latin_match) == 1 && nzchar(latin_match)) {
      return(latin_match)
    }

    ""
  }
  non_measurement_search_role <- function(row, dict) {
    desc_query <- if (is_review_placeholder(row$column_description[[1]])) {
      ""
    } else {
      strip_review_placeholder(row$column_description[[1]])
    }
    label_query <- strip_review_placeholder(row$column_label[[1]])
    name_query <- strip_review_placeholder(row$column_name[[1]])
    query_text <- expand_attribute_tokens(paste(desc_query, label_query, name_query, collapse = " "))
    if (!nzchar(query_text)) return("variable")

    ctx <- table_context(row, dict)
    taxon_query <- extract_taxon_like_phrase(query_text)

    if (nzchar(taxon_query) && grepl("\\b(confirm|confirmed|identify|identified|species|taxon)\\b", query_text, perl = TRUE)) {
      return("entity")
    }
    if (grepl("\\b(method|protocol|procedure|gear|enumeration)\\b", query_text, perl = TRUE)) {
      return("method")
    }
    if (grepl("\\b(watershed|waterbody|river|stream|location|site|area|conservation unit|management unit)\\b", query_text, perl = TRUE)) {
      return("entity")
    }
    if (grepl("\\b(stage|classification|class|type|status|context|origin|accuracy|precision|reliability|index)\\b", query_text, perl = TRUE)) {
      return("constraint")
    }
    if (grepl("\\b(species|taxon|population|stock)\\b", query_text, perl = TRUE)) {
      return("entity")
    }

    "variable"
  }
  non_measurement_query <- function(row, dict, search_role = non_measurement_search_role(row, dict)) {
    desc_query <- if (is_review_placeholder(row$column_description[[1]])) {
      ""
    } else {
      strip_review_placeholder(row$column_description[[1]])
    }
    label_query <- strip_review_placeholder(row$column_label[[1]])
    name_query <- strip_review_placeholder(row$column_name[[1]])
    base_query <- expand_attribute_tokens(first_non_empty(list(desc_query, label_query, name_query)))
    all_text <- expand_attribute_tokens(paste(desc_query, label_query, name_query, collapse = " "))
    if (!nzchar(base_query)) return("")

    ctx <- table_context(row, dict)

    if (identical(search_role, "method")) {
      if (grepl("\\bestimate\\b", all_text, perl = TRUE) && grepl("\\bmethod\\b", all_text, perl = TRUE)) return("estimate method")
      if (grepl("\\bcount(ing)?\\b", all_text, perl = TRUE) && grepl("\\bmethod\\b", all_text, perl = TRUE)) return("counting method")
      if (grepl("\\bcatch\\b", all_text, perl = TRUE) && grepl("\\bmethod\\b", all_text, perl = TRUE)) return("capture method")
      return(base_query)
    }

    if (identical(search_role, "constraint")) {
      if (grepl("\\brun\\b", all_text, perl = TRUE) && grepl("\\btype\\b", all_text, perl = TRUE)) return("run context")
      if (grepl("\\bestimate\\b", all_text, perl = TRUE) && grepl("\\bstage\\b", all_text, perl = TRUE)) return("spawner stage context")
      if (grepl("\\bestimate\\b", all_text, perl = TRUE) && grepl("\\bclassification\\b", all_text, perl = TRUE)) return("abundance data type")
      if (grepl("\\borigin\\b", all_text, perl = TRUE)) return("origin")
      return(base_query)
    }

    if (identical(search_role, "entity")) {
      taxon_query <- extract_taxon_like_phrase(all_text)
      if (nzchar(taxon_query)) return(taxon_query)
      if (grepl("\\bconservation unit\\b", all_text, perl = TRUE)) return("conservation unit")
      if (grepl("\\baquaculture management unit\\b", all_text, perl = TRUE)) return("aquaculture management unit")
      if (grepl("\\bmanagement unit\\b", all_text, perl = TRUE)) return("management unit")
      if (grepl("\\bspecies\\b|\\btaxon\\b", all_text, perl = TRUE)) return("species")
      if (grepl("\\bpopulation\\b", all_text, perl = TRUE)) return("population")
      if (grepl("\\bwatershed\\b", all_text, perl = TRUE)) return("watershed")
      if (grepl("\\bwaterbody\\b|\\briver\\b|\\bstream\\b", all_text, perl = TRUE)) return("water body")
      if (grepl("\\bsite\\b|\\blocation\\b", all_text, perl = TRUE)) return("site")
      if (grepl("\\barea\\b", all_text, perl = TRUE)) {
        if (context_has(ctx, "waterbody|watershed|river|stream")) return("water body")
        return("area")
      }
    }

    base_query
  }
  table_target_query <- function(row) {
    observation_unit <- if ("observation_unit" %in% names(row) && !is_review_placeholder(row$observation_unit[[1]])) {
      strip_review_placeholder(row$observation_unit[[1]])
    } else {
      ""
    }
    table_description <- if ("description" %in% names(row) && !is_review_placeholder(row$description[[1]])) {
      strip_review_placeholder(row$description[[1]])
    } else {
      ""
    }
    table_label <- if ("table_label" %in% names(row)) strip_review_placeholder(row$table_label[[1]]) else ""
    table_id_query <- if ("table_id" %in% names(row)) strip_review_placeholder(row$table_id[[1]]) else ""

    query_basis <- if (nzchar(observation_unit)) {
      "observation_unit"
    } else if (nzchar(table_description)) {
      "description"
    } else if (nzchar(table_label)) {
      "table_label"
    } else if (nzchar(table_id_query)) {
      "table_id"
    } else {
      ""
    }

    query_context_parts <- c(observation_unit, table_description, table_label, table_id_query)
    query_context_parts <- query_context_parts[nzchar(query_context_parts)]

    tibble::tibble(
      search_query = clean_query(first_non_empty(list(observation_unit, table_description, table_label, table_id_query))),
      target_query_basis = query_basis,
      target_query_context = clean_query(paste(query_context_parts, collapse = " "))
    )
  }
  has_low_card_codes <- function(row, codes) {
    if (nrow(codes) == 0) return(FALSE)
    keep <- rep(TRUE, nrow(codes))
    for (key in intersect(c("dataset_id", "table_id", "column_name"), names(codes))) {
      value <- row[[key]][[1]]
      if (!is.na(value) && nzchar(as.character(value))) {
        keep <- keep & !is.na(codes[[key]]) & as.character(codes[[key]]) == as.character(value)
      }
    }
    any(keep)
  }
  has_location_like_column_signal <- function(row, dict) {
    if (!identical(non_measurement_search_role(row, dict), "entity")) {
      return(FALSE)
    }

    desc_query <- if (is_review_placeholder(row$column_description[[1]])) {
      ""
    } else {
      strip_review_placeholder(row$column_description[[1]])
    }
    label_query <- strip_review_placeholder(row$column_label[[1]])
    name_query <- strip_review_placeholder(row$column_name[[1]])
    query_text <- expand_attribute_tokens(paste(desc_query, label_query, name_query, collapse = " "))
    if (!nzchar(query_text)) {
      return(FALSE)
    }

    grepl("\\b(watershed|waterbody|river|stream|location|site)\\b", query_text, perl = TRUE)
  }
  same_table_column_names <- function(row, dict) {
    if (nrow(dict) == 0 || !all(c("dataset_id", "table_id", "column_name") %in% names(dict))) {
      return(character())
    }

    keep <- rep(TRUE, nrow(dict))
    for (key in intersect(c("dataset_id", "table_id"), names(dict))) {
      value <- row[[key]][[1]]
      if (!is.na(value) && nzchar(as.character(value))) {
        keep <- keep & !is.na(dict[[key]]) & as.character(dict[[key]]) == as.character(value)
      }
    }

    cols <- trimws(tolower(as.character(dict$column_name[keep])))
    unique(cols[nzchar(cols)])
  }
  has_long_format_observation_value_pattern <- function(row, dict) {
    cols <- same_table_column_names(row, dict)
    if (length(cols) == 0) {
      return(FALSE)
    }

    has_value <- "value" %in% cols
    has_variable <- any(cols %in% c("variable_name", "measurement_name", "parameter_name", "parameter", "analyte_name"))
    has_unit <- any(cols %in% c("unit_code", "unit", "unit_label"))

    has_value && has_variable && has_unit
  }
  is_long_format_observation_helper <- function(row, dict) {
    col_name <- tolower(trimws(as.character(row$column_name[[1]] %||% "")))
    if (!nzchar(col_name) || !has_long_format_observation_value_pattern(row, dict)) {
      return(FALSE)
    }

    col_name %in% c(
      "parameter",
      "unit",
      "unit_code",
      "vmv_code",
      "flag",
      "status",
      "grade",
      "method_detect_limit",
      "station_name",
      "location name"
    )
  }
  non_measurement_roles <- function(row, codes, dict) {
    role <- tolower(as.character(row$column_role[[1]] %||% ""))
    if (!nzchar(role) || role %in% c("identifier", "temporal")) return(character())
    if (.ms_is_text_like_field_name(row$column_name[[1]] %||% "")) return(character())
    if (is_long_format_observation_helper(row, dict)) return(character())

    term_missing <- "term_iri" %in% names(row) && is_missing(row$term_iri[[1]])
    if (!term_missing) return(character())

    has_codes <- has_low_card_codes(row, codes)
    location_fallback <- has_location_like_column_signal(row, dict)
    if (!has_codes && !location_fallback) return(character())

    if (role %in% c("categorical", "attribute")) {
      return(c(term_iri = non_measurement_search_role(row, dict)))
    }
    character()
  }
  targets <- tibble::tibble()

  if (nrow(dict) > 0) {
    column_targets <- purrr::map_dfr(seq_len(nrow(dict)), function(i) {
      row <- dict[i, , drop = FALSE]
      role_targets <- if (identical(row$column_role[[1]], "measurement")) {
        roles
      } else {
        non_measurement_roles(row, codes, dict)
      }
      if (length(role_targets) == 0) return(tibble::tibble())

      purrr::imap_dfr(role_targets, function(search_role, col_name) {
        if (!col_name %in% names(row)) return(tibble::tibble())
        if (is_present(row[[col_name]][[1]])) return(tibble::tibble())

        dictionary_role <- roles[[col_name]] %||% search_role
        role_query <- if (identical(row$column_role[[1]], "measurement")) {
          measurement_role_query(row, dict, search_role)
        } else {
          non_measurement_query(row, dict, search_role = search_role)
        }
        if (!nzchar(role_query)) return(tibble::tibble())
        tibble::tibble(
          dataset_id = row$dataset_id[[1]],
          table_id = row$table_id[[1]],
          column_name = row$column_name[[1]],
          code_value = NA_character_,
          dictionary_role = dictionary_role,
          search_role = search_role,
          target_scope = "column",
          target_sdp_file = "column_dictionary.csv",
          target_sdp_field = col_name,
          target_row_key = paste(row$dataset_id[[1]], row$table_id[[1]], row$column_name[[1]], sep = "/"),
          target_label = row$column_label[[1]],
          target_description = row$column_description[[1]],
          search_query = role_query,
          column_label = row$column_label[[1]],
          column_description = row$column_description[[1]],
          code_label = NA_character_,
          code_description = NA_character_
        )
      })
    })
    targets <- dplyr::bind_rows(targets, column_targets)
  }

  if (nrow(codes) > 0) {
    code_targets <- purrr::map_dfr(seq_len(nrow(codes)), function(i) {
      row <- codes[i, , drop = FALSE]
      term_iri <- if ("term_iri" %in% names(row)) row$term_iri[[1]] else NA_character_
      if (is_present(term_iri)) return(tibble::tibble())

      dataset_id <- if ("dataset_id" %in% names(row)) row$dataset_id[[1]] else NA_character_
      table_id <- if ("table_id" %in% names(row)) row$table_id[[1]] else NA_character_
      column_name <- if ("column_name" %in% names(row)) row$column_name[[1]] else NA_character_
      code_value <- if ("code_value" %in% names(row)) row$code_value[[1]] else NA_character_
      # No code value, no target in any role (hub item B-276); the other rows
      # of this column keep theirs.
      if (.ms_semantic_code_value_is_empty(code_value)) return(tibble::tibble())
      code_label <- if ("code_label" %in% names(row)) row$code_label[[1]] else NA_character_
      code_description <- if ("code_description" %in% names(row)) row$code_description[[1]] else NA_character_

      parent_row <- dict[dict$dataset_id == dataset_id & dict$table_id == table_id & dict$column_name == column_name, , drop = FALSE]
      parent_role <- if (nrow(parent_row) > 0 && "column_role" %in% names(parent_row)) parent_row$column_role[[1]] else NA_character_
      parent_label <- if (nrow(parent_row) > 0 && "column_label" %in% names(parent_row)) parent_row$column_label[[1]] else column_name
      parent_description <- if (nrow(parent_row) > 0 && "column_description" %in% names(parent_row)) parent_row$column_description[[1]] else NA_character_

      # A procedure column's codes ARE the row-varying methods — the only
      # method placement left in the data under sdp-0.3.0 — so its codes get
      # method candidates even though the column itself is not a measurement.
      parent_names_procedure <- grepl(
        # Stems need `\\w*`: `\\b(estimat)\\b` cannot match "estimation",
        # which is exactly the column naming this is meant to catch.
        "\\b(method|protocol|procedure|gear|estimat\\w*|enumerat\\w*|technique|survey type)\\b",
        tolower(paste(
          gsub("[_.]", " ", as.character(column_name %||% "")),
          as.character(parent_label %||% ""),
          as.character(parent_description %||% "")
        )),
        perl = TRUE
      )
      role_set <- if (identical(parent_role, "measurement")) {
        c("constraint", "entity", "method")
      } else if (parent_names_procedure) {
        c("method")
      } else {
        c("entity")
      }
      query <- clean_query(first_non_empty(list(code_description, code_label, code_value, parent_description, parent_label, column_name)))
      if (!nzchar(query)) return(tibble::tibble())

      tibble::tibble(
        dataset_id = dataset_id,
        table_id = table_id,
        column_name = column_name,
        code_value = code_value,
        dictionary_role = role_set,
        search_role = role_set,
        target_scope = "code",
        target_sdp_file = "codes.csv",
        target_sdp_field = "term_iri",
        target_row_key = paste(dataset_id, table_id, column_name, code_value, sep = "/"),
        target_label = first_non_empty(list(code_label, code_value)),
        target_description = code_description,
        search_query = query,
        column_label = parent_label,
        column_description = parent_description,
        code_label = code_label,
        code_description = code_description
      )
    })
    targets <- dplyr::bind_rows(targets, code_targets)
  }

  if (nrow(table_meta) > 0) {
    table_targets <- purrr::map_dfr(seq_len(nrow(table_meta)), function(i) {
      row <- table_meta[i, , drop = FALSE]
      observation_unit_iri <- if ("observation_unit_iri" %in% names(row)) row$observation_unit_iri[[1]] else NA_character_
      if (is_present(observation_unit_iri)) return(tibble::tibble())

      dataset_id <- if ("dataset_id" %in% names(row)) row$dataset_id[[1]] else NA_character_
      table_id <- if ("table_id" %in% names(row)) row$table_id[[1]] else NA_character_
      table_label <- if ("table_label" %in% names(row)) row$table_label[[1]] else table_id
      table_description <- if ("description" %in% names(row)) row$description[[1]] else NA_character_
      query_info <- table_target_query(row)
      query <- query_info$search_query[[1]]
      if (!nzchar(query)) return(tibble::tibble())

      tibble::tibble(
        dataset_id = dataset_id,
        table_id = table_id,
        column_name = NA_character_,
        code_value = NA_character_,
        dictionary_role = "entity",
        search_role = "entity",
        target_scope = "table",
        target_sdp_file = "tables.csv",
        target_sdp_field = "observation_unit_iri",
        target_row_key = paste(dataset_id, table_id, sep = "/"),
        target_label = table_label,
        target_description = table_description,
        search_query = query,
        target_query_basis = query_info$target_query_basis[[1]],
        target_query_context = query_info$target_query_context[[1]],
        column_label = NA_character_,
        column_description = NA_character_,
        code_label = NA_character_,
        code_description = NA_character_
      )
    })
    targets <- dplyr::bind_rows(targets, table_targets)
  }

  if (nrow(dataset_meta) > 0) {
    dataset_targets <- purrr::map_dfr(seq_len(nrow(dataset_meta)), function(i) {
      row <- dataset_meta[i, , drop = FALSE]
      keywords <- if ("keywords" %in% names(row)) row$keywords[[1]] else NA_character_
      if (is_present(keywords)) return(tibble::tibble())

      dataset_id <- if ("dataset_id" %in% names(row)) row$dataset_id[[1]] else NA_character_
      title <- if ("title" %in% names(row)) row$title[[1]] else dataset_id
      description <- if ("description" %in% names(row)) row$description[[1]] else NA_character_
      query <- clean_query(first_non_empty(list(description, title, dataset_id)))
      if (!nzchar(query)) return(tibble::tibble())

      tibble::tibble(
        dataset_id = dataset_id,
        table_id = NA_character_,
        column_name = NA_character_,
        code_value = NA_character_,
        dictionary_role = "entity",
        search_role = "entity",
        target_scope = "dataset",
        target_sdp_file = "dataset.csv",
        target_sdp_field = "keywords",
        target_row_key = dataset_id,
        target_label = title,
        target_description = description,
        search_query = query,
        column_label = NA_character_,
        column_description = NA_character_,
        code_label = NA_character_,
        code_description = NA_character_
      )
    })
    targets <- dplyr::bind_rows(targets, dataset_targets)
  }

  targets <- .ms_semantic_normalize_target_rows(targets, target_cols)
  # Fail loud rather than silently dropping a column a future builder adds: a
  # stray column here means the target-row contract and the builders disagree.
  extra_cols <- setdiff(names(targets), target_cols)
  if (length(extra_cols) > 0L) {
    cli::cli_abort(c(
      "Semantic target discovery produced columns outside the target-row contract.",
      "i" = "Add them to {.fn .ms_semantic_target_cols} or drop them in the builder: {.val {extra_cols}}."
    ))
  }
  targets <- targets[, target_cols, drop = FALSE]

  targets
}

.ms_semantic_merge_llm_assessments <- function(suggestions, assessments, top_n) {
  suggestions <- tibble::as_tibble(suggestions)
  assessments <- tibble::as_tibble(assessments)

  if (nrow(suggestions) == 0) {
    return(suggestions)
  }

  suggestions$.ms_group_key <- .ms_semantic_group_key_df(suggestions)
  suggestions$.ms_row_order <- seq_len(nrow(suggestions))

  suggestions |>
    dplyr::group_by(.data$.ms_group_key) |>
    dplyr::mutate(llm_candidate_rank = dplyr::if_else(dplyr::row_number() <= top_n, dplyr::row_number(), NA_integer_)) |>
    dplyr::ungroup() |>
    dplyr::left_join(
      assessments,
      by = .ms_semantic_assessment_join_cols()
    ) |>
    dplyr::mutate(
      # Selected only on an ACCEPT whose index names this rank. The decision
      # is checked here as well as the index because the two are separate
      # columns of a record a harness now writes (parity row 31, converged
      # for the review-packet contract in hub item B-326): an index on a
      # non-accept row is cleared by validation, and this is the second
      # guard on the same invariant.
      llm_selected = !is.na(.data$llm_selected_candidate_index) &
        !is.na(.data$llm_candidate_rank) &
        .data$llm_selected_candidate_index == .data$llm_candidate_rank &
        .data$llm_decision %in% "accept"
    ) |>
    dplyr::select(-dplyr::any_of(c(".ms_group_key", ".ms_bundle_key", ".ms_row_order")))
}
