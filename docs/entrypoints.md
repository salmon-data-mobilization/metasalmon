# Entrypoints

Short map of the package's public starts and their canonical implementations.

## Run (human-facing)

- Main workflow: `create_sdp()` -> infer artifacts -> seed semantics -> write SDP
- Review workflow: `read_salmon_datapackage()` -> validate/edit -> rebuild EDH XML
- Reviewed suggestion merge: `apply_semantic_suggestions()`; `"reviewed"`
  applies accepted review decisions, `"llm"` applies opt-in LLM selections,
  and both preserve repeated constraints in SDP semicolon form; `"top"`
  remains lexical and single-winner
- Extended SDP metadata: `write_sdp_methods()` ->
  `write_sdp_observation_structures()` -> `extract_sdp_observations()`;
  reproducibility sidecars are closed with
  `write_sdp_reproducibility_manifest()`
- KNB workflow: reviewed SDP + `metadata/eml-mapping.yml` ->
  `write_eml_from_sdp()` -> `publish_sdp_to_knb(..., public = FALSE,
  dry_run = TRUE)` -> review exact manifest -> explicit resumable live deposit.
  Re-plan after correcting an input with `overwrite = TRUE`; it replaces
  artifacts from an unpublished dry run only, never from a published manifest
- KNB environments: `knb_environment = "test"` (KNB Test Node,
  `urn:node:mnTestKNB`, credential `dataone_test_token`) or `"production"`
  (`urn:node:KNB`, credential `dataone_token`). A dry run defaults to `"test"`;
  a live call must name the environment explicitly and still requires
  `confirm = TRUE`. Test artifacts are written under `publication/test/`, so
  the reviewed production `metadata/eml.xml` is left untouched
- Package site: <https://salmon-data-mobilization.github.io/metasalmon/>
- Repository: <https://github.com/salmon-data-mobilization/metasalmon>
- Optional LLM variables: `OPENAI_API_KEY`, `OPENROUTER_API_KEY`, `CHAPI_API_KEY`

## Build

- R docs: `Rscript -e 'devtools::document()'`
- Package: `R CMD build .`
- Site: `Rscript scripts/build-pkgdown.R` (full rebuild, then removes non-public
  agent guidance from the generated sitemap)

## Test

- Full suite: `Rscript -e 'devtools::test()'`
- Release check: `R CMD check metasalmon_<version>.tar.gz`
- Fast package smoke: `Rscript -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-package-helpers.R", reporter = "summary")'`

## Public Wiring

- `create_sdp()` -> `infer_salmon_datapackage_artifacts()` ->
  `suggest_semantics()` -> `write_salmon_datapackage()`
- `suggest_semantics(llm_assess = TRUE)` -> deterministic `find_terms()` shortlist
  -> shared review adapter; context inputs are parsed once from local paths
- `apply_semantic_suggestions(strategy = "reviewed")` -> accepted reviewed
  selections in `R/semantics-helpers.R`; repeated constraints are deduplicated
  in review order and serialized as `iri-1; iri-2` in `constraint_iri`
- `write_edh_xml_from_sdp()` is the strict post-review EDH rebuild path
- `write_sdp_sssom()` stores concept mappings; ordered measurement components
  remain separate in `write_sdp_measurement_decompositions()`
- `write_sdp_methods()` registers SOSA procedures; paired
  `write_sdp_observation_structures()` metadata declares one logical grain per
  measurement, and `extract_sdp_observations()` returns the validated normalized
  projections.
- `publish_sdp_to_knb(representation = "expanded")` retains each SDP data
  resource and publishes the validated, closed package inventory as named
  objects with package-relative OAI-ORE locations; no ZIP is created. Archive
  mode remains a compatibility option. Private deposits are persistent staging
  records; DOI minting is a separate KNB public-release step. Revisions use a
  fresh SDP directory and preserve the preceding manifest.

## Canonical Implementations (Per Feature)

- SDP package writing/reading -> `R/package-helpers.R`
- SDP schema loading and field order -> `R/schema-helpers.R` +
  `inst/extdata/schema/` + `inst/extdata/profiles/`
- Artifact inference orchestration -> `R/artifact-inference.R`
- Dictionary validation and column semantics -> `R/dictionary-helpers.R` +
  `R/validation_helpers.R`
- Semantic target/assessment row contracts -> `R/semantic-suggestions.R` +
  `R/llm-review-adapter.R`
- Context loading, option policy, and optional LLM review ->
  `R/llm-semantic-helpers.R`
- Interactive decomposition review -> `R/chat-decomposition.R`
- SSSOM mapping sets -> `R/sssom.R`
- Ordered measurement decomposition artifacts ->
  `R/measurement-decompositions.R`
- Methods, measure-specific observation structures, and reproducibility
  closure -> `R/sdp-methods.R`, `R/observation-structures.R`, and
  `R/reproducibility-manifest.R`
- SOSA procedure registries and measure-specific logical grains ->
  `R/sdp-methods.R` + `R/observation-structures.R`
- EML profile and KNB/DataONE deposit/revision state machine ->
  `R/eml-export.R`, `R/knb-sdp-archive.R`, and `R/knb-publication.R`
