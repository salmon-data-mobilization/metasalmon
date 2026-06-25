test_dictionary <- function(dataset_id = "d1",
                            table_id = "t1",
                            column_name = "spawner_count",
                            column_label = "Spawner count",
                            column_description = "Natural-origin spawner abundance estimate",
                            column_role = "measurement",
                            value_type = "integer",
                            unit_label = NA_character_,
                            unit_iri = NA_character_,
                            term_iri = NA_character_,
                            property_iri = NA_character_,
                            entity_iri = NA_character_,
                            constraint_iri = NA_character_,
                            method_iri = NA_character_,
                            term_type = NA_character_,
                            required = NA) {
  fields <- list(
    dataset_id = dataset_id,
    table_id = table_id,
    column_name = column_name,
    column_label = column_label,
    column_description = column_description,
    column_role = column_role,
    value_type = value_type,
    unit_label = unit_label,
    unit_iri = unit_iri,
    term_iri = term_iri,
    property_iri = property_iri,
    entity_iri = entity_iri,
    constraint_iri = constraint_iri,
    method_iri = method_iri,
    term_type = term_type,
    required = required
  )
  n <- max(vapply(fields, length, integer(1L)))
  fields <- lapply(fields, rep, length.out = n)
  tibble::as_tibble(fields)
}

test_spawner_dictionary <- function(...) {
  test_dictionary(...)
}

test_count_dictionary <- function(column_name = "count",
                                  column_label = "Count",
                                  column_description = "Spawner count",
                                  value_type = "number",
                                  ...) {
  test_dictionary(
    column_name = column_name,
    column_label = column_label,
    column_description = column_description,
    value_type = value_type,
    ...
  )
}

test_shortlist_search <- function(query, role, sources) {
  tibble::tibble(
    label = c(paste(role, "best"), paste(role, "alt")),
    iri = c(
      paste0("https://example.org/", role, "/best"),
      paste0("https://example.org/", role, "/alt")
    ),
    source = c("smn", "smn"),
    ontology = c("demo", "demo"),
    role = c(role, role),
    match_type = c("label_partial", "label_partial"),
    definition = c("Best match from retrieved shortlist", "Alternative match from retrieved shortlist"),
    score = c(0.9, 0.5)
  )
}

fill_measurement_components <- function(dict) {
  measurement_rows <- !is.na(dict$column_role) & dict$column_role == "measurement"
  if (!any(measurement_rows)) {
    return(dict)
  }

  required_cols <- c("term_iri", "property_iri", "entity_iri", "unit_iri")
  for (col in required_cols) {
    if (!col %in% names(dict)) {
      dict[[col]] <- NA_character_
    }
  }

  dict$term_iri[measurement_rows & (is.na(dict$term_iri) | dict$term_iri == "")] <-
    "https://example.org/variable"
  dict$property_iri[measurement_rows & (is.na(dict$property_iri) | dict$property_iri == "")] <-
    "https://example.org/property"
  dict$entity_iri[measurement_rows & (is.na(dict$entity_iri) | dict$entity_iri == "")] <-
    "https://example.org/entity"
  dict$unit_iri[measurement_rows & (is.na(dict$unit_iri) | dict$unit_iri == "")] <-
    "https://example.org/unit"

  dict
}
