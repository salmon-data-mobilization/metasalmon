make_structure_test_sdp <- function(path, inconsistent_spawners = FALSE) {
  spawners <- if (isTRUE(inconsistent_spawners)) c(100, 101, 120) else c(100, 100, 120)
  data <- tibble::tibble(
    stock_id = c("fraser", "fraser", "fraser"),
    brood_year = c(2019L, 2019L, 2020L),
    return_year = c(2022L, 2023L, 2024L),
    age = c(3L, 4L, 4L),
    total_spawners = spawners,
    recruits = c(40, 55, 60),
    estimate_method = c("mark_recapture", "expanded_count", "expanded_count")
  )
  # sdp-0.3.0: the dictionary has no method slot. The table-constant
  # procedure lives in tables.csv$method_iri; row-varying procedures resolve
  # through codes.csv$term_iri.
  dictionary <- tibble::tribble(
    ~dataset_id, ~table_id, ~column_name, ~column_label, ~column_description,
    ~column_role, ~value_type, ~unit_label, ~unit_iri, ~term_iri, ~term_type,
    ~required, ~property_iri, ~entity_iri, ~constraint_iri,
    "structure-test", "stock_recruit", "stock_id", "Stock", "Stock identifier",
    "identifier", "string", NA_character_, NA_character_, NA_character_,
    NA_character_, TRUE, NA_character_, NA_character_, NA_character_,
    "structure-test", "stock_recruit", "brood_year", "Brood year", "Brood year",
    "temporal", "integer", NA_character_, NA_character_, NA_character_,
    NA_character_, TRUE, NA_character_, NA_character_, NA_character_,
    "structure-test", "stock_recruit", "return_year", "Return year", "Return year",
    "temporal", "integer", NA_character_, NA_character_, NA_character_,
    NA_character_, TRUE, NA_character_, NA_character_, NA_character_,
    "structure-test", "stock_recruit", "age", "Age", "Age at return",
    "attribute", "integer", "year", "http://qudt.org/vocab/unit/YR",
    NA_character_, NA_character_, TRUE, NA_character_, NA_character_,
    NA_character_,
    "structure-test", "stock_recruit", "total_spawners", "Total spawners",
    "Estimated total spawners", "measurement", "number", "individual",
    "http://qudt.org/vocab/unit/INDIV", "https://example.org/variables/spawners",
    "owl_class", TRUE, "https://w3id.org/smn/Abundance",
    "https://w3id.org/smn/Stock", NA_character_,
    "structure-test", "stock_recruit", "recruits", "Recruits",
    "Estimated recruits", "measurement", "number", "individual",
    "http://qudt.org/vocab/unit/INDIV", "https://example.org/variables/recruits",
    "owl_class", TRUE, "https://w3id.org/smn/Abundance",
    "https://w3id.org/smn/Stock", NA_character_,
    "structure-test", "stock_recruit", "estimate_method", "Estimate method",
    "Row-varying recruit estimation procedure", "categorical", "string",
    NA_character_, NA_character_, NA_character_, "skos_concept", TRUE,
    NA_character_, NA_character_, NA_character_
  )
  codes <- tibble::tribble(
    ~dataset_id, ~table_id, ~column_name, ~code_value, ~code_label,
    ~code_description, ~vocabulary_iri, ~term_iri, ~term_type,
    "structure-test", "stock_recruit", "estimate_method", "mark_recapture",
    "Mark-recapture estimate", "Mark-recapture procedure", NA_character_,
    "https://example.org/methods/mark-recapture", "owl_named_individual",
    "structure-test", "stock_recruit", "estimate_method", "expanded_count",
    "Expanded count", "Expanded-count procedure", NA_character_,
    "https://example.org/methods/expanded-count", "owl_named_individual"
  )

  write_salmon_datapackage(
    resources = list(stock_recruit = data),
    dataset_meta = tibble::tibble(
      dataset_id = "structure-test",
      title = "Observation structure test",
      description = "Mixed-grain fixture"
    ),
    table_meta = tibble::tibble(
      dataset_id = "structure-test",
      table_id = "stock_recruit",
      file_name = "data/stock_recruit.csv",
      table_label = "Stock recruit",
      description = "Mixed-grain stock-recruit estimates",
      # The table-constant procedure, placed where sdp-0.3.0 expects it.
      method_iri = "https://example.org/methods/spawning-ground-survey"
    ),
    dict = dictionary,
    codes = codes,
    path = path,
    overwrite = TRUE
  )
  invisible(path)
}

structure_test_rows <- function() {
  tibble::tribble(
    ~dataset_id, ~table_id, ~observation_structure_id, ~structure_label,
    ~structure_description,
    "structure-test", "stock_recruit", "total_spawners_by_brood",
    "Total spawners by brood",
    "One logical total-spawner observation per stock and brood year.",
    "structure-test", "stock_recruit", "recruits_by_age",
    "Recruits by age",
    "One logical recruit observation per stock, brood year, return year, and age."
  )
}

component_test_rows <- function() {
  tibble::tribble(
    ~dataset_id, ~table_id, ~observation_structure_id, ~component_order,
    ~column_name, ~component_role, ~component_relation_iri,
    ~required_when_observed,
    "structure-test", "stock_recruit", "total_spawners_by_brood", 1L,
    "stock_id", "dimension", NA_character_, TRUE,
    "structure-test", "stock_recruit", "total_spawners_by_brood", 2L,
    "brood_year", "dimension", NA_character_, TRUE,
    "structure-test", "stock_recruit", "total_spawners_by_brood", 3L,
    "total_spawners", "measure", NA_character_, TRUE,
    "structure-test", "stock_recruit", "recruits_by_age", 1L,
    "stock_id", "dimension", NA_character_, TRUE,
    "structure-test", "stock_recruit", "recruits_by_age", 2L,
    "brood_year", "dimension", NA_character_, TRUE,
    "structure-test", "stock_recruit", "recruits_by_age", 3L,
    "return_year", "dimension", NA_character_, TRUE,
    "structure-test", "stock_recruit", "recruits_by_age", 4L,
    "age", "dimension", NA_character_, TRUE,
    "structure-test", "stock_recruit", "recruits_by_age", 5L,
    "recruits", "measure", NA_character_, TRUE,
    "structure-test", "stock_recruit", "recruits_by_age", 6L,
    "estimate_method", "attribute", "http://www.w3.org/ns/sosa/usedProcedure",
    TRUE
  )
}

