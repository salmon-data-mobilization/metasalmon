test_that("method evidence validator requires an explicit procedure", {
  rejected <- metasalmon:::.ms_validate_semantic_method_evidence(
    "method",
    "Catch count does not identify a measurement procedure."
  )
  accepted <- metasalmon:::.ms_validate_semantic_method_evidence(
    "method",
    paste(
      "A technician measured fork length in the field with a measuring board",
      "from the snout tip to the caudal-fin fork."
    )
  )

  expect_equal(rejected$code, "SEM_METHOD_EVIDENCE_REQUIRED")
  expect_equal(nrow(accepted), 0L)
})

test_that("role-shaped method text and grouping language are not evidence", {
  target <- tibble::tibble(
    target_label = "Catch enumeration procedure",
    target_description = "A method slot generated for this column.",
    target_query_context = "Catch count; no procedure supplied.",
    column_label = "Catch count",
    column_description = "Fish counted by species."
  )
  dict <- test_dictionary(
    column_description = "Fish counted by species."
  )
  evidence <- metasalmon:::.ms_semantic_bundle_validator_evidence(
    target,
    dict,
    tibble::tibble()
  )

  expect_false(
    metasalmon:::.ms_semantic_validator_has_method_evidence(evidence)
  )
  expect_equal(
    metasalmon:::.ms_validate_semantic_method_evidence(
      "method",
      evidence
    )$code,
    "SEM_METHOD_EVIDENCE_REQUIRED"
  )
})

test_that("constraint evidence validator recognizes explicit lifecycle context", {
  rejected <- metasalmon:::.ms_validate_semantic_constraint_evidence(
    "constraint",
    "CATCH_COUNT records the number of fish retained in each trawl catch."
  )
  accepted <- metasalmon:::.ms_validate_semantic_constraint_evidence(
    "constraint",
    "The field explicitly denotes the salmon ocean life-cycle phase."
  )

  expect_equal(rejected$code, "SEM_CONSTRAINT_EVIDENCE_REQUIRED")
  expect_equal(nrow(accepted), 0L)
})

test_that("role and native-type validator only rejects known incompatibility", {
  hinted <- tibble::tibble(
    iri = "https://example.org/count",
    role_hints = "property",
    term_type = "skos_concept"
  )
  qudt_unit <- tibble::tibble(
    iri = "https://qudt.org/vocab/unit/KiloGM",
    role_hints = NA_character_,
    term_type = "qudt unit"
  )
  unknown <- tibble::tibble(
    iri = "https://example.org/native-concept",
    role_hints = NA_character_,
    term_type = "owl_class"
  )
  predicate <- tibble::tibble(
    iri = "https://w3id.org/smn/usesObservationProcedure",
    role_hints = "method",
    resource_kind = "ObjectProperty",
    type_iris = "http://www.w3.org/2002/07/owl#ObjectProperty"
  )

  expect_equal(
    metasalmon:::.ms_validate_semantic_role_type("variable", hinted)$code,
    "SEM_ROLE_TYPE_MISMATCH"
  )
  expect_equal(
    metasalmon:::.ms_validate_semantic_role_type("property", qudt_unit)$code,
    "SEM_ROLE_TYPE_MISMATCH"
  )
  expect_equal(
    nrow(metasalmon:::.ms_validate_semantic_role_type("variable", unknown)),
    0L
  )
  expect_equal(
    metasalmon:::.ms_validate_semantic_role_type("method", predicate)$code,
    "SEM_ROLE_TYPE_MISMATCH"
  )
})

test_that("dimensional validator is conservative when dimensions are known", {
  count_dict <- test_dictionary(unit_label = "count")
  mass_dict <- test_dictionary(unit_label = "kg")
  fish_weight <- tibble::tibble(
    label = "Fish weight",
    definition = "Mass of a fish",
    iri = "https://w3id.org/smn/FishWeight"
  )

  expect_equal(
    metasalmon:::.ms_validate_semantic_dimension(
      "property",
      fish_weight,
      count_dict
    )$code,
    "SEM_DIMENSION_MISMATCH"
  )
  expect_equal(
    nrow(metasalmon:::.ms_validate_semantic_dimension(
      "property",
      fish_weight,
      mass_dict
    )),
    0L
  )
})

test_that("dimensional validator recognizes ratios and rates", {
  ratio_property <- tibble::tibble(
    label = "Female proportion",
    definition = "A dimensionless ratio.",
    iri = "https://example.org/FemaleProportion"
  )
  ratio_unit <- tibble::tibble(
    label = "Percent",
    definition = "A dimensionless percentage unit.",
    iri = "http://qudt.org/vocab/unit/PERCENT"
  )
  rate_property <- tibble::tibble(
    label = "Observation frequency",
    definition = "Frequency of observations per assessment period.",
    iri = "https://example.org/ObservationFrequency"
  )
  rate_unit <- tibble::tibble(
    label = "Per year",
    definition = "Events per year.",
    iri = "https://example.org/unit/PER-YR"
  )

  expect_equal(
    metasalmon:::.ms_semantic_validator_candidate_dimension(
      ratio_property
    ),
    "dimensionless"
  )
  expect_equal(
    metasalmon:::.ms_semantic_validator_candidate_dimension(ratio_unit),
    "dimensionless"
  )
  expect_equal(
    metasalmon:::.ms_semantic_validator_candidate_dimension(
      rate_property
    ),
    "rate"
  )
  survival_rate <- tibble::tibble(
    label = "Survival rate",
    definition = "A dimensionless survival proportion.",
    iri = "https://example.org/SurvivalRate"
  )
  expect_equal(
    metasalmon:::.ms_semantic_validator_candidate_dimension(
      survival_rate
    ),
    "dimensionless"
  )
  expect_true(is.na(
    metasalmon:::.ms_semantic_validator_dimension("generic rate")
  ))
  expect_equal(
    metasalmon:::.ms_semantic_validator_dimension(
      "Instantaneous mortality rate per year"
    ),
    "rate"
  )
  expect_equal(
    metasalmon:::.ms_semantic_validator_dimension(
      "cubic metres per second"
    ),
    "flow"
  )
  expect_equal(
    metasalmon:::.ms_semantic_validator_dimension(
      "kilometres per hour"
    ),
    "speed"
  )
  expect_true(is.na(
    metasalmon:::.ms_semantic_validator_dimension(
      "kilograms per year"
    )
  ))
  expect_true(is.na(
    metasalmon:::.ms_semantic_validator_dimension(
      "square metres per second"
    )
  ))
  expect_true(is.na(
    metasalmon:::.ms_semantic_validator_dimension(
      "cubic kilometres per hour"
    )
  ))
  expect_true(is.na(
    metasalmon:::.ms_semantic_validator_dimension(
      "metres per second squared"
    )
  ))
  expect_true(is.na(
    metasalmon:::.ms_semantic_validator_dimension("kg/year")
  ))
  expect_true(is.na(
    metasalmon:::.ms_semantic_validator_dimension(
      "http://qudt.org/vocab/unit/KiloGM-PER-YR"
    )
  ))
  expect_equal(
    metasalmon:::.ms_semantic_validator_candidate_dimension(rate_unit),
    "rate"
  )
})

test_that("validator evidence excludes context for unrelated fields", {
  target <- tibble::tibble(
    column_name = "CATCH_COUNT",
    column_label = "Catch count",
    target_label = "Catch count method",
    search_query = "catch count procedure",
    target_query_context = "Catch count; no procedure supplied.",
    column_description = "Number of fish in the catch."
  )
  dict <- test_dictionary(
    column_name = "CATCH_COUNT",
    column_label = "Catch count",
    column_description = "Number of fish in the catch."
  )
  chunks <- tibble::tibble(
    source = "inline_context",
    chunk_id = c(
      "inline_context[1]#1",
      "inline_context[2]#1",
      "inline_context[3]#1"
    ),
    chunk_text = c(
      "CATCH_COUNT is the number of fish retained in a trawl catch.",
      paste(
        "FORK_LENGTH_MM was measured in the field with a measuring",
        "board following the fork-length protocol."
      ),
      paste(
        "SPAWNER_CATCH_COUNT was enumerated using a visual survey",
        "protocol."
      )
    )
  )

  evidence <- metasalmon:::.ms_semantic_bundle_validator_evidence(
    target,
    dict,
    chunks
  )

  expect_match(evidence, "catch_count", fixed = TRUE)
  expect_false(grepl("measuring board", evidence, fixed = TRUE))
  expect_false(
    metasalmon:::.ms_semantic_validator_has_method_evidence(evidence)
  )
})

test_that("validator evidence accepts only distinctive local field anchors", {
  target <- tibble::tibble(
    column_name = "CATCH_COUNT",
    column_label = "Catch count",
    column_description = "Number of fish in the catch."
  )
  dict <- test_dictionary(
    column_name = "CATCH_COUNT",
    column_label = "Catch count",
    column_description = "Number of fish in the catch."
  )

  local_evidence <- metasalmon:::.ms_semantic_bundle_validator_evidence(
    target,
    dict,
    tibble::tibble(
      chunk_text = "Catch count was enumerated using a visual survey protocol."
    )
  )
  expect_true(
    metasalmon:::.ms_semantic_validator_has_method_evidence(local_evidence)
  )

  weak_target <- dplyr::mutate(
    target,
    column_name = "count",
    column_label = "Count"
  )
  weak_dict <- dplyr::mutate(
    dict,
    column_name = "count",
    column_label = "Count"
  )
  unrelated_evidence <- metasalmon:::.ms_semantic_bundle_validator_evidence(
    weak_target,
    weak_dict,
    tibble::tibble(
      chunk_text = "Spawner count was enumerated using a visual survey protocol."
    )
  )
  expect_false(
    metasalmon:::.ms_semantic_validator_has_method_evidence(
      unrelated_evidence
    )
  )

  suffix_evidence <- metasalmon:::.ms_semantic_bundle_validator_evidence(
    target,
    dict,
    tibble::tibble(
      chunk_text = paste(
        "CATCH_COUNT_ESTIMATE was enumerated using a sonar survey",
        "protocol during the ocean phase."
      )
    )
  )
  expect_false(
    metasalmon:::.ms_semantic_validator_has_method_evidence(suffix_evidence)
  )
  expect_false(
    metasalmon:::.ms_semantic_validator_has_constraint_evidence(
      suffix_evidence
    )
  )

  for (prefix in c("* ", "+ ", "| ", "- ", "1. ", "### ", "> ")) {
    marked_suffix_evidence <-
      metasalmon:::.ms_semantic_bundle_validator_evidence(
        target,
        dict,
        tibble::tibble(
          chunk_text = paste0(
            prefix,
            paste(
              "CATCH_COUNT_ESTIMATE was enumerated using a sonar survey",
              "protocol during the ocean phase."
            )
          )
        )
      )
    expect_false(
      metasalmon:::.ms_semantic_validator_has_method_evidence(
        marked_suffix_evidence
      ),
      info = paste("markup prefix:", prefix)
    )
    expect_false(
      metasalmon:::.ms_semantic_validator_has_constraint_evidence(
        marked_suffix_evidence
      ),
      info = paste("markup prefix:", prefix)
    )
  }

  marked_local_evidence <-
    metasalmon:::.ms_semantic_bundle_validator_evidence(
      target,
      dict,
      tibble::tibble(
        chunk_text = paste(
          "* Catch count was enumerated using a visual survey protocol",
          "during the ocean phase."
        )
      )
    )
  expect_true(
    metasalmon:::.ms_semantic_validator_has_method_evidence(
      marked_local_evidence
    )
  )
  expect_true(
    metasalmon:::.ms_semantic_validator_has_constraint_evidence(
      marked_local_evidence
    )
  )
})

test_that("newly accepted property and unit candidates are cross-validated", {
  selected <- list(
    property = tibble::tibble(
      label = "Count",
      definition = "The number of items.",
      iri = "http://qudt.org/vocab/quantitykind/Count"
    ),
    unit = tibble::tibble(
      label = NA_character_,
      definition = NA_character_,
      iri = "http://qudt.org/vocab/unit/KiloGM"
    )
  )

  property_finding <-
    metasalmon:::.ms_validate_semantic_property_unit_pair(
      "property",
      selected
    )
  unit_finding <-
    metasalmon:::.ms_validate_semantic_property_unit_pair(
      "unit",
      selected
    )

  expect_equal(
    property_finding$code,
    "SEM_PROPERTY_UNIT_DIMENSION_MISMATCH"
  )
  expect_equal(
    unit_finding$code,
    "SEM_PROPERTY_UNIT_DIMENSION_MISMATCH"
  )

  flow_selected <- list(
    property = tibble::tibble(
      label = "Stream discharge",
      definition = "Volumetric flow through a channel.",
      iri = "https://example.org/StreamDischarge"
    ),
    unit = tibble::tibble(
      label = "Cubic metres per second",
      definition = "A volumetric flow unit.",
      iri = "https://example.org/unit/M3-PER-SEC"
    )
  )
  expect_equal(
    nrow(metasalmon:::.ms_validate_semantic_property_unit_pair(
      "property",
      flow_selected
    )),
    0L
  )
  expect_equal(
    nrow(metasalmon:::.ms_validate_semantic_property_unit_pair(
      "unit",
      flow_selected
    )),
    0L
  )
})

test_that("CatchContext redundancy is an explicit paired rule", {
  catch_context <- tibble::tibble(
    iri = "https://w3id.org/smn/CatchContext"
  )
  paired <- c(variable = "https://w3id.org/smn/CatchAbundance")
  unrelated <- c(variable = "https://w3id.org/smn/SpawnerAbundance")

  expect_equal(
    metasalmon:::.ms_validate_semantic_redundancy(
      "constraint",
      catch_context,
      paired,
      "Catch count in a trawl catch."
    )$code,
    "SEM_REDUNDANT_CATCH_CONTEXT"
  )
  expect_equal(
    nrow(metasalmon:::.ms_validate_semantic_redundancy(
      "constraint",
      catch_context,
      unrelated,
      "Catch count in a trawl catch."
    )),
    0L
  )
  expect_equal(
    nrow(metasalmon:::.ms_validate_semantic_redundancy(
      "constraint",
      catch_context,
      paired,
      "Catch abundance for the ocean life-cycle phase."
    )),
    0L
  )
})

test_that("REVIEW markers do not activate accepted-pair redundancy", {
  dict <- test_dictionary()
  dict$term_iri <- "REVIEW:https://w3id.org/smn/CatchAbundance"
  assessments <- metasalmon:::.ms_empty_llm_assessments()
  selected <- metasalmon:::.ms_semantic_bundle_current_selected_iris(
    assessments,
    dict
  )
  catch_context <- tibble::tibble(
    iri = "https://w3id.org/smn/CatchContext"
  )

  expect_true(is.na(selected[["variable"]]))
  expect_equal(
    nrow(metasalmon:::.ms_validate_semantic_redundancy(
      "constraint",
      catch_context,
      selected,
      "Catch count in a trawl catch."
    )),
    0L
  )
})

test_that("bundle validators downgrade unsupported acceptances only", {
  dict <- test_dictionary(
    column_description = "Total fish observed in a trawl catch.",
    unit_label = "count"
  )
  candidate_for_role <- function(role) {
    label <- switch(
      role,
      variable = "Catch abundance",
      property = "Count",
      entity = "Fish",
      unit = "Count",
      constraint = "Catch context",
      method = "Fork-length field method"
    )
    tibble::tibble(
      label = label,
      iri = paste0("https://example.org/", role),
      source = "smn",
      ontology = "demo",
      role = role,
      role_hints = role,
      match_type = "label",
      definition = paste("A", role, "candidate"),
      score = 0.9
    )
  }
  response <- function() {
    list(
      bundle_summary = "A catch count measurement.",
      assessments = lapply(
        metasalmon:::.ms_semantic_bundle_roles(),
        function(role) {
          list(
            dictionary_role = role,
            decision = "accept",
            selected_candidate_id = paste0(
              "smn::https://example.org/",
              role
            ),
            confidence = 0.94,
            rationale = "The candidate fits.",
            missing_context = "",
            retry_query = NULL,
            suggested_label = NULL,
            suggested_definition = NULL,
            suggested_namespace = NULL
          )
        }
      )
    )
  }

  out <- suggest_semantics(
    df = tibble::tibble(spawner_count = c(10L, 12L)),
    dict = dict,
    sources = "smn",
    max_per_role = 1L,
    search_fn = function(query, role, sources) candidate_for_role(role),
    llm_assess = TRUE,
    llm_provider = "openrouter",
    llm_model = "openai/gpt-5.4-mini",
    llm_api_key = "dummy",
    llm_request_fn = function(messages, config) response()
  )

  assessments <- attr(out, "semantic_llm_assessments")
  downgraded <- assessments[
    assessments$dictionary_role %in% c("constraint", "method"),
    ,
    drop = FALSE
  ]
  retained <- assessments[
    assessments$dictionary_role %in% c("variable", "property", "entity", "unit"),
    ,
    drop = FALSE
  ]
  findings <- attr(
    assessments,
    "semantic_validator_findings",
    exact = TRUE
  )

  expect_true(all(downgraded$llm_decision == "review"))
  expect_true(all(is.na(downgraded$llm_selected_candidate_index)))
  expect_true(all(is.na(downgraded$llm_selected_iri)))
  expect_true(all(downgraded$llm_confidence == 0.94))
  expect_true(all(retained$llm_decision == "accept"))
  expect_setequal(
    findings$code,
    c(
      "SEM_CONSTRAINT_EVIDENCE_REQUIRED",
      "SEM_METHOD_EVIDENCE_REQUIRED"
    )
  )
  expect_true(all(grepl("\\[SEM_", downgraded$llm_rationale)))
})

test_that("bundle validation downgrades an incompatible accepted property-unit pair", {
  candidates <- list(
    property = tibble::tibble(
      label = "Count",
      iri = "http://qudt.org/vocab/quantitykind/Count",
      source = "qudt",
      ontology = "QUDT",
      role = "property",
      role_hints = "property",
      match_type = "label",
      definition = "The number of items.",
      score = 0.95,
      resource_kind = "QuantityKind"
    ),
    unit = tibble::tibble(
      label = "Kilogram",
      iri = "http://qudt.org/vocab/unit/KiloGM",
      source = "qudt",
      ontology = "QUDT",
      role = "unit",
      role_hints = "unit",
      match_type = "label",
      definition = "A unit of mass.",
      score = 0.95,
      resource_kind = "Unit"
    )
  )
  response <- list(
    bundle_summary = "A deliberately incompatible pair.",
    assessments = lapply(
      metasalmon:::.ms_semantic_bundle_roles(),
      function(role) {
        accepted <- role %in% c("property", "unit")
        iri <- if (accepted) candidates[[role]]$iri[[1]] else NULL
        list(
          dictionary_role = role,
          decision = if (accepted) "accept" else "review",
          selected_candidate_id = if (accepted) {
            paste0("qudt::", iri)
          } else {
            NULL
          },
          confidence = 0.94,
          rationale = "Fixture decision.",
          missing_context = "",
          retry_query = NULL,
          suggested_label = NULL,
          suggested_definition = NULL,
          suggested_namespace = NULL
        )
      }
    )
  )

  out <- suggest_semantics(
    df = tibble::tibble(spawner_count = c(10L, 12L)),
    dict = test_dictionary(unit_label = NA_character_),
    sources = "qudt",
    max_per_role = 1L,
    search_fn = function(query, role, sources) {
      if (is.null(candidates[[role]])) {
        tibble::tibble()
      } else {
        candidates[[role]]
      }
    },
    llm_assess = TRUE,
    llm_provider = "openrouter",
    llm_model = "openai/gpt-5.4-mini",
    llm_api_key = "dummy",
    llm_request_fn = function(messages, config) response
  )

  assessments <- attr(out, "semantic_llm_assessments")
  pair <- assessments[
    assessments$dictionary_role %in% c("property", "unit"),
    ,
    drop = FALSE
  ]
  findings <- attr(
    assessments,
    "semantic_validator_findings",
    exact = TRUE
  )

  expect_true(all(pair$llm_decision == "review"))
  expect_true(all(is.na(pair$llm_selected_iri)))
  expect_equal(
    sum(findings$code == "SEM_PROPERTY_UNIT_DIMENSION_MISMATCH"),
    2L
  )
})

test_that("bundle payload preserves supplied native ontology type", {
  candidate <- tibble::tibble(
    label = "Catch abundance",
    iri = "https://w3id.org/smn/CatchAbundance",
    source = "smn",
    ontology = "Salmon Ontology",
    role = "variable",
    role_hints = "variable",
    match_type = "label",
    definition = "Abundance observed in a catch.",
    score = 0.9,
    term_type = "owl_class"
  )

  payload <- metasalmon:::.ms_semantic_bundle_candidate_payload(
    candidate,
    "variable"
  )

  expect_equal(payload[[1]]$native_type, "owl_class")
})
