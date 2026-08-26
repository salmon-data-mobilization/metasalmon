# Package index

## Start Here

One-shot package creation from raw tables

- [`metasalmon-package`](https://salmon-data-mobilization.github.io/metasalmon/reference/metasalmon.md)
  [`metasalmon`](https://salmon-data-mobilization.github.io/metasalmon/reference/metasalmon.md)
  : metasalmon: Utilities for Salmon Data Packages
- [`create_sdp()`](https://salmon-data-mobilization.github.io/metasalmon/reference/create_sdp.md)
  : Create a Salmon Data Package directly from raw tables
- [`infer_salmon_datapackage_artifacts()`](https://salmon-data-mobilization.github.io/metasalmon/reference/infer_salmon_datapackage_artifacts.md)
  : Infer Salmon Data Package artifacts from resource tables
- [`read_salmon_datapackage()`](https://salmon-data-mobilization.github.io/metasalmon/reference/read_salmon_datapackage.md)
  : Read a Salmon Data Package
- [`validate_salmon_datapackage()`](https://salmon-data-mobilization.github.io/metasalmon/reference/validate_salmon_datapackage.md)
  : Validate a Salmon Data Package end to end

## Advanced Package Assembly

Manual writing when you already have the SDP metadata tables assembled

- [`write_salmon_datapackage()`](https://salmon-data-mobilization.github.io/metasalmon/reference/write_salmon_datapackage.md)
  : Write a Salmon Data Package from preassembled metadata

## Dictionary Functions

Infer, validate, and apply semantic data dictionaries

- [`infer_dictionary()`](https://salmon-data-mobilization.github.io/metasalmon/reference/infer_dictionary.md)
  : Infer a starter dictionary from a data frame
- [`validate_dictionary()`](https://salmon-data-mobilization.github.io/metasalmon/reference/validate_dictionary.md)
  : Validate a salmon data dictionary
- [`apply_salmon_dictionary()`](https://salmon-data-mobilization.github.io/metasalmon/reference/apply_salmon_dictionary.md)
  : Apply a salmon dictionary to a data frame
- [`apply_semantic_suggestions()`](https://salmon-data-mobilization.github.io/metasalmon/reference/apply_semantic_suggestions.md)
  : Apply semantic suggestions into a dictionary

## Review and Edit (in R)

Review the seeded IRIs in the console, decide them in a script, fill in
the remaining metadata, and write it all back — no spreadsheet required

- [`review_semantics()`](https://salmon-data-mobilization.github.io/metasalmon/reference/review_semantics.md)
  : Review semantic suggestions in the console
- [`accept_suggestion()`](https://salmon-data-mobilization.github.io/metasalmon/reference/accept_suggestion.md)
  [`reject_suggestion()`](https://salmon-data-mobilization.github.io/metasalmon/reference/accept_suggestion.md)
  : Decide a semantic review slot
- [`apply_sdp_semantics()`](https://salmon-data-mobilization.github.io/metasalmon/reference/apply_sdp_semantics.md)
  : Write semantic review decisions into a package
- [`review_metadata()`](https://salmon-data-mobilization.github.io/metasalmon/reference/review_metadata.md)
  : Report the metadata a package still needs, with the call that fills
  it
- [`set_sdp_dataset()`](https://salmon-data-mobilization.github.io/metasalmon/reference/set_sdp_dataset.md)
  [`set_sdp_table()`](https://salmon-data-mobilization.github.io/metasalmon/reference/set_sdp_dataset.md)
  [`set_sdp_column()`](https://salmon-data-mobilization.github.io/metasalmon/reference/set_sdp_dataset.md)
  [`set_sdp_code()`](https://salmon-data-mobilization.github.io/metasalmon/reference/set_sdp_dataset.md)
  : Fill in a package's free-text metadata
- [`semantic_suggestions()`](https://salmon-data-mobilization.github.io/metasalmon/reference/semantic_suggestions.md)
  : Semantic suggestions attached to a dictionary or package
- [`semantic_llm_assessments()`](https://salmon-data-mobilization.github.io/metasalmon/reference/semantic_llm_assessments.md)
  : Target-level LLM assessments attached to a dictionary

## Semantic Helpers

Semantic suggestion, vocabulary search, and ranking benchmark
capabilities

- [`suggest_semantics()`](https://salmon-data-mobilization.github.io/metasalmon/reference/suggest_semantics.md)
  : Suggest semantic annotations for a dictionary
- [`chat_decomposition()`](https://salmon-data-mobilization.github.io/metasalmon/reference/chat_decomposition.md)
  : Interactive decomposition review for measurement variables
- [`find_terms()`](https://salmon-data-mobilization.github.io/metasalmon/reference/find_terms.md)
  : Find candidate terms across external vocabularies
- [`sources_for_role()`](https://salmon-data-mobilization.github.io/metasalmon/reference/sources_for_role.md)
  : Get recommended sources for a given role
- [`benchmark_term_ranking_fixtures()`](https://salmon-data-mobilization.github.io/metasalmon/reference/benchmark_term_ranking_fixtures.md)
  : Benchmark semantic term ranking against fixture cases
- [`deduplicate_proposed_terms()`](https://salmon-data-mobilization.github.io/metasalmon/reference/deduplicate_proposed_terms.md)
  : Deduplicate proposed ontology terms

## Ontology + Validation

Fetch the ontology and validate semantic coverage

- [`fetch_salmon_ontology()`](https://salmon-data-mobilization.github.io/metasalmon/reference/fetch_salmon_ontology.md)
  : Fetch the Salmon Domain Ontology with caching
- [`validate_semantics()`](https://salmon-data-mobilization.github.io/metasalmon/reference/validate_semantics.md)
  : Validate semantics with graceful gap reporting
- [`suggest_facet_schemes()`](https://salmon-data-mobilization.github.io/metasalmon/reference/suggest_facet_schemes.md)
  : Suggest facet schemes for proposed terms

## Term Request Workflow

Detect missing terms, route SMN, GCDFO, profile, or uncertain requests,
and draft curator-reviewed GitHub issues

- [`detect_semantic_term_gaps()`](https://salmon-data-mobilization.github.io/metasalmon/reference/detect_semantic_term_gaps.md)
  : Detect candidate and LLM-identified semantic term gaps
- [`render_ontology_term_request()`](https://salmon-data-mobilization.github.io/metasalmon/reference/render_ontology_term_request.md)
  : Render GitHub-ready ontology term request payloads
- [`submit_term_request_issues()`](https://salmon-data-mobilization.github.io/metasalmon/reference/submit_term_request_issues.md)
  : Submit rendered ontology term requests as GitHub issues

## NuSEDS Helpers

Crosswalk legacy NuSEDS method labels to canonical method families

- [`nuseds_enumeration_method_crosswalk()`](https://salmon-data-mobilization.github.io/metasalmon/reference/nuseds_enumeration_method_crosswalk.md)
  : NuSEDS enumeration method crosswalk
- [`nuseds_estimate_method_crosswalk()`](https://salmon-data-mobilization.github.io/metasalmon/reference/nuseds_estimate_method_crosswalk.md)
  : NuSEDS estimate method crosswalk
- [`nuseds_estimate_classification_crosswalk()`](https://salmon-data-mobilization.github.io/metasalmon/reference/nuseds_estimate_classification_crosswalk.md)
  : NuSEDS estimate classification crosswalk

## Darwin Core (DwC-DP)

Darwin Core Data Package mapping and export helpers

- [`suggest_dwc_mappings()`](https://salmon-data-mobilization.github.io/metasalmon/reference/suggest_dwc_mappings.md)
  : Suggest Darwin Core Data Package mappings for dictionary columns
- [`dwc_dp_build_descriptor()`](https://salmon-data-mobilization.github.io/metasalmon/reference/dwc_dp_build_descriptor.md)
  : Build a DwC-DP datapackage descriptor (export helper)

## Enterprise Data Hub (EDH)

HNAP-aware EDH XML export helpers for Enterprise Data Hub workflows

- [`edh_build_hnap_xml()`](https://salmon-data-mobilization.github.io/metasalmon/reference/edh_build_hnap_xml.md)
  : Build HNAP-aware metadata XML for DFO Enterprise Data Hub export

- [`edh_build_iso19139_xml()`](https://salmon-data-mobilization.github.io/metasalmon/reference/edh_build_iso19139_xml.md)
  :

  Deprecated alias for
  [`edh_build_hnap_xml()`](https://salmon-data-mobilization.github.io/metasalmon/reference/edh_build_hnap_xml.md)

- [`write_edh_xml_from_sdp()`](https://salmon-data-mobilization.github.io/metasalmon/reference/write_edh_xml_from_sdp.md)
  : Rebuild HNAP-aware EDH XML from a reviewed Salmon Data Package

## Semantic Review Supplements

Validated SSSOM concept alignments and ordered measurement
decompositions

- [`read_sssom_mapping_set()`](https://salmon-data-mobilization.github.io/metasalmon/reference/read_sssom_mapping_set.md)
  : Read a reviewed SSSOM mapping set
- [`write_sdp_sssom()`](https://salmon-data-mobilization.github.io/metasalmon/reference/write_sdp_sssom.md)
  : Write reviewed SSSOM mapping sets into a Salmon Data Package
- [`validate_sdp_sssom()`](https://salmon-data-mobilization.github.io/metasalmon/reference/validate_sdp_sssom.md)
  : Validate SDP SSSOM artifacts
- [`read_sdp_measurement_decompositions()`](https://salmon-data-mobilization.github.io/metasalmon/reference/read_sdp_measurement_decompositions.md)
  : Read ordered measurement decompositions from a Salmon Data Package
- [`write_sdp_measurement_decompositions()`](https://salmon-data-mobilization.github.io/metasalmon/reference/write_sdp_measurement_decompositions.md)
  : Write ordered measurement decompositions into a Salmon Data Package
- [`validate_sdp_measurement_decompositions()`](https://salmon-data-mobilization.github.io/metasalmon/reference/validate_sdp_measurement_decompositions.md)
  : Validate ordered SDP measurement-decomposition artifacts

## Extended SDP Structure and Reproducibility

SOSA procedures, measure-specific observation structures, and closed
reproducibility sidecars

- [`migrate_sdp_methods()`](https://salmon-data-mobilization.github.io/metasalmon/reference/migrate_sdp_methods.md)
  : Migrate an sdp-0.2.0 package's method metadata to sdp-0.3.0
- [`read_sdp_observation_structures()`](https://salmon-data-mobilization.github.io/metasalmon/reference/read_sdp_observation_structures.md)
  : Read measure-specific SDP observation structures
- [`write_sdp_observation_structures()`](https://salmon-data-mobilization.github.io/metasalmon/reference/write_sdp_observation_structures.md)
  : Write measure-specific SDP observation structures
- [`validate_sdp_observation_structures()`](https://salmon-data-mobilization.github.io/metasalmon/reference/validate_sdp_observation_structures.md)
  : Validate measure-specific SDP observation structures
- [`extract_sdp_observations()`](https://salmon-data-mobilization.github.io/metasalmon/reference/extract_sdp_observations.md)
  : Extract normalized logical observations from an SDP
- [`read_sdp_reproducibility_manifest()`](https://salmon-data-mobilization.github.io/metasalmon/reference/read_sdp_reproducibility_manifest.md)
  : Read an SDP reproducibility manifest
- [`write_sdp_reproducibility_manifest()`](https://salmon-data-mobilization.github.io/metasalmon/reference/write_sdp_reproducibility_manifest.md)
  : Write a closed reproducibility manifest into a Salmon Data Package
- [`validate_sdp_reproducibility_manifest()`](https://salmon-data-mobilization.github.io/metasalmon/reference/validate_sdp_reproducibility_manifest.md)
  : Validate an SDP reproducibility manifest

## EML and KNB

Reviewed EML 2.2.0 export and verified DataONE/KNB publication

- [`write_eml_from_sdp()`](https://salmon-data-mobilization.github.io/metasalmon/reference/write_eml_from_sdp.md)
  : Write reviewed EML 2.2.0 metadata from a Salmon Data Package
- [`publish_sdp_to_knb()`](https://salmon-data-mobilization.github.io/metasalmon/reference/publish_sdp_to_knb.md)
  : Publish a reviewed Salmon Data Package to KNB

## GitHub Access

Authenticate once and read CSVs from private GitHub repositories

- [`ms_setup_github()`](https://salmon-data-mobilization.github.io/metasalmon/reference/ms_setup_github.md)
  : Set up GitHub access for private repositories
- [`github_raw_url()`](https://salmon-data-mobilization.github.io/metasalmon/reference/github_raw_url.md)
  : Build a stable raw GitHub URL
- [`read_github_csv()`](https://salmon-data-mobilization.github.io/metasalmon/reference/read_github_csv.md)
  : Read a CSV from a GitHub repository
- [`read_github_csv_dir()`](https://salmon-data-mobilization.github.io/metasalmon/reference/read_github_csv_dir.md)
  : Read all CSV files from a GitHub directory

## ICES Vocabulary

Access ICES reference codes and vocabulary

- [`ices_vocab`](https://salmon-data-mobilization.github.io/metasalmon/reference/ices_vocab.md)
  : ICES controlled vocabularies (code lists)
- [`ices_code_types()`](https://salmon-data-mobilization.github.io/metasalmon/reference/ices_code_types.md)
  : List ICES code types
- [`ices_codes()`](https://salmon-data-mobilization.github.io/metasalmon/reference/ices_codes.md)
  : List ICES codes for a code type
- [`ices_find_code_types()`](https://salmon-data-mobilization.github.io/metasalmon/reference/ices_find_code_types.md)
  : Find ICES code types by text match
- [`ices_find_codes()`](https://salmon-data-mobilization.github.io/metasalmon/reference/ices_find_codes.md)
  : Find ICES codes within a code type by text match

## Maintenance

Version and update helpers

- [`check_for_updates()`](https://salmon-data-mobilization.github.io/metasalmon/reference/check_for_updates.md)
  : Check whether a newer metasalmon release is available
