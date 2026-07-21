# Entrypoints

Short map of the package's public starts and their canonical implementations.

## Run (human-facing)

- Main workflow: `create_sdp()` -> infer artifacts -> seed semantics -> write SDP
- Review workflow: `read_salmon_datapackage()` -> validate/edit -> rebuild EDH XML
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
- `write_edh_xml_from_sdp()` is the strict post-review EDH rebuild path

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
