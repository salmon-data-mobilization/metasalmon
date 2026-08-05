make_eml_test_sdp <- function(path,
                              dataset_id = "demo-salmon-2026",
                              count_values = c(0, 12),
                              count_value_type = "number",
                              year_values = c(2024, 2025),
                              year_value_type = "number",
                              mapping_status = "final",
                              measurement_term_iri =
                                "https://w3id.org/smn/ObservedRateOrAbundance",
                              measurement_term_label =
                                "Observed rate or abundance",
                              measurement_term_type = "owl_class",
                              measurement_native_type = "owl:Class",
                              measurement_type_iris =
                                "http://www.w3.org/2002/07/owl#Class",
                              measurement_resource_kind = "Class",
                              measurement_source = "smn",
                              measurement_source_url =
                                "https://w3id.org/smn/",
                              measurement_unit_iri =
                                "http://qudt.org/vocab/unit/COUNT",
                              measurement_unit_label = "Count") {
  resources <- list(
    counts = tibble::tibble(
      record_id = c("A", "B"),
      year = year_values,
      count = count_values,
      literal_missing = c("observed", NA_character_),
      blank_only = c("marker", "")
    )
  )
  dataset_meta <- tibble::tibble(
    dataset_id = dataset_id,
    title = "Demonstration salmon counts",
    description = "A compact fixture for deterministic EML export tests.",
    creator = "Example Salmon Program",
    contact_name = "Example Salmon Program",
    contact_email = "data@example.org",
    license = "https://example.org/data-terms/",
    contact_org = "Example Salmon Program",
    contact_position = "Data Steward",
    temporal_start = "2024",
    temporal_end = "2025",
    spatial_extent = "Example watershed",
    dataset_type = "Tabular counts",
    source_citation = "Example Salmon Program. 2026. Demonstration counts.",
    update_frequency = NA_character_,
    topic_categories = "biota",
    keywords = "salmon; abundance",
    security_classification = "Public",
    provenance_note = "Counts were compiled from a documented monitoring program.",
    created = NA_character_,
    modified = "2026-01-01",
    spec_version = "sdp-0.2.0"
  )
  table_meta <- tibble::tibble(
    dataset_id = dataset_id,
    table_id = "counts",
    file_name = "data/counts.csv",
    table_label = "Salmon counts",
    description = "One annual abundance record per identifier.",
    observation_unit = "An annual salmon count observation",
    observation_unit_iri = "https://w3id.org/smn/Observation",
    primary_key = "record_id"
  )
  dictionary <- tibble::tribble(
    ~dataset_id, ~table_id, ~column_name, ~column_label, ~column_description,
    ~term_iri, ~property_iri, ~entity_iri, ~constraint_iri, ~method_iri,
    ~unit_label, ~unit_iri, ~term_type, ~value_type, ~column_role, ~required,
    dataset_id, "counts", "record_id", "Record identifier",
    "Stable identifier for the annual count record.",
    NA_character_, NA_character_, NA_character_, NA_character_, NA_character_,
    NA_character_, NA_character_, NA_character_, "string", "identifier", TRUE,
    dataset_id, "counts", "year", "Observation year",
    "Calendar year represented by the record.",
    NA_character_, NA_character_, NA_character_, NA_character_, NA_character_,
    NA_character_, NA_character_, NA_character_, year_value_type, "temporal", TRUE,
    dataset_id, "counts", "count", "Salmon abundance",
    "Estimated number of salmon; zero is a valid observed value.",
    measurement_term_iri,
    "http://qudt.org/vocab/quantitykind/Count",
    "https://w3id.org/smn/Stock",
    NA_character_,
    NA_character_,
    measurement_unit_label,
    measurement_unit_iri,
    measurement_term_type,
    count_value_type,
    "measurement",
    TRUE,
    dataset_id, "counts", "literal_missing", "Literal missing marker",
    "A text field whose second row uses the literal CSV token NA.",
    NA_character_, NA_character_, NA_character_, NA_character_, NA_character_,
    NA_character_, NA_character_, NA_character_, "string", "attribute", FALSE,
    dataset_id, "counts", "blank_only", "Blank implicit absence",
    "A text field whose second row is an empty CSV field.",
    NA_character_, NA_character_, NA_character_, NA_character_, NA_character_,
    NA_character_, NA_character_, NA_character_, "string", "attribute", FALSE
  )

  write_salmon_datapackage(
    resources = resources,
    dataset_meta = dataset_meta,
    table_meta = table_meta,
    dict = dictionary,
    codes = tibble::tibble(),
    path = path,
    overwrite = TRUE
  )

  vocabulary <- tibble::tribble(
    ~iri, ~label, ~definition, ~source, ~ontology, ~resource_kind, ~type_iris,
    ~native_type, ~source_url, ~source_artifact_sha256,
    "http://qudt.org/vocab/quantitykind/Count", "Count",
    "A quantity kind for counts.", "qudt", "qudt", "QuantityKind", NA_character_,
    "qudt:QuantityKind", "https://qudt.org/3.1.1/vocab/quantitykind/",
    NA_character_,
    measurement_unit_iri, measurement_unit_label,
    "A counting unit.", "qudt", "qudt", "Unit", NA_character_,
    "qudt:CountingUnit;qudt:Unit", "https://qudt.org/3.1.1/vocab/unit/",
    NA_character_,
    measurement_term_iri, measurement_term_label,
    "An empirically observed compound measurement variable.",
    measurement_source, measurement_source, measurement_resource_kind,
    measurement_type_iris, measurement_native_type,
    measurement_source_url,
    paste(rep("3", 64), collapse = ""),
    "https://w3id.org/smn/Stock", "Stock",
    "An operationally defined grouping of salmon.", "smn", "smn", "Class",
    "http://www.w3.org/2002/07/owl#Class", "owl:Class",
    "https://w3id.org/smn/",
    paste(rep("3", 64), collapse = "")
  )
  vocabulary$reviewed_snapshot_sha256 <- vapply(
    seq_len(nrow(vocabulary)),
    function(row_number) {
      .ms_eml_vocabulary_snapshot_sha256(
        vocabulary[row_number, , drop = FALSE]
      )
    },
    character(1)
  )
  vocabulary_path <- file.path(path, "metadata", "semantic_vocabulary.csv")
  readr::write_csv(
    vocabulary,
    vocabulary_path,
    na = ""
  )

  semantic_review <- tibble::tribble(
    ~dataset_id, ~table_id, ~column_name, ~target_scope, ~target_sdp_field,
    ~dictionary_role, ~decision, ~confidence, ~review_rationale, ~iri,
    dataset_id, "counts", "", "table", "observation_unit_iri",
    "entity", "accepted", "high",
    "The row grain is an observation.", "https://w3id.org/smn/Observation",
    dataset_id, "counts", "count", "column", "term_iri",
    "variable", "accepted", "medium",
    "The reviewed measurement type is intentionally broad.",
    measurement_term_iri,
    dataset_id, "counts", "count", "column", "property_iri",
    "property", "accepted", "high",
    "The column contains abundance counts.",
    "http://qudt.org/vocab/quantitykind/Count",
    dataset_id, "counts", "count", "column", "entity_iri",
    "entity", "accepted", "high",
    "The counts describe a salmon stock.",
    "https://w3id.org/smn/Stock",
    dataset_id, "counts", "count", "column", "unit_iri",
    "unit", "accepted", "high",
    "The values use the reviewed counting unit.",
    measurement_unit_iri
  )
  semantic_review_path <- file.path(
    path,
    "reviewed_semantic_selections.csv"
  )
  readr::write_csv(semantic_review, semantic_review_path, na = "")

  mapping <- list(
    version = 1L,
    status = mapping_status,
    dataset_id = dataset_id,
    series_key = "demo-salmon",
    system = "knb",
    language = "eng",
    publication_date = "2026-01-01",
    semantic_vocabulary = list(
      path = "metadata/semantic_vocabulary.csv",
      sha256 = digest::digest(
        file = vocabulary_path,
        algo = "sha256",
        serialize = FALSE
      )
    ),
    semantic_review = list(
      path = "reviewed_semantic_selections.csv",
      sha256 = digest::digest(
        file = semantic_review_path,
        algo = "sha256",
        serialize = FALSE
      )
    ),
    publication = list(public = TRUE),
    rights_authorization = list(
      status = "confirmed",
      evidence = "Synthetic fixture data are authorized for public testing."
    ),
    source_provenance = list(
      source_citation =
        "Example Salmon Program. 2026. Demonstration counts.",
      provenance_note =
        "Counts were compiled from a documented monitoring program.",
      supporting_document = list(
        citation =
          "Example Salmon Program. 2026. Demonstration count documentation.",
        url = "https://example.org/demonstration-count-documentation.pdf",
        sha256 = paste(rep("4", 64), collapse = "")
      )
    ),
    creators = list(
      list(organization_name = "Example Salmon Program")
    ),
    metadata_providers = list(
      list(
        given_name = "Alex",
        surname = "Steward",
        organization_name = "Example Salmon Program",
        email = "alex@example.org",
        orcid = "https://orcid.org/0000-0001-9317-0364"
      )
    ),
    contacts = list(
      list(
        organization_name = "Example Salmon Program",
        email = "data@example.org"
      )
    ),
    publisher = list(organization_name = "Example Salmon Program"),
    intellectual_rights = list(
      paragraphs = c(
        "Copyright Example Salmon Program.",
        "Use is subject to https://example.org/data-terms/."
      )
    ),
    methods = list(
      list(
        description =
          "Counts were compiled using the documented monitoring workflow."
      )
    ),
    taxonomic_coverage = list(
      scientific_name = "Oncorhynchus nerka",
      common_name = "Sockeye salmon",
      rank = "Species"
    ),
    tables = list(
      counts = list(
        attributes = list(
          record_id = list(measurement_scale = "nominal"),
          year = list(
            measurement_scale = "dateTime",
            format_string = "YYYY"
          ),
          count = list(
            measurement_scale = "ratio",
            eml_unit = "number",
            number_type = "whole",
            minimum = 0,
            minimum_exclusive = FALSE
          ),
          literal_missing = list(
            measurement_scale = "nominal",
            missing_values = list(
              list(
                code = "NA",
                explanation = "No value was supplied."
              )
            )
          ),
          blank_only = list(measurement_scale = "nominal")
        )
      )
    )
  )
  yaml::write_yaml(
    mapping,
    file.path(path, "metadata", "eml-mapping.yml")
  )

  invisible(path)
}
