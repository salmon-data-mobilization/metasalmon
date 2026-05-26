# Entrypoints (What Is Actually Used?)

Purpose: keep one short, reliable map of what starts the system, what is wired in, and where to edit things.

## Run (human-facing)

- Start command(s):
- Local URL(s):
- Required environment variables (names only, no secrets):

## Build

- Build command(s):

## Test

- Test command(s): `Rscript -e 'pkgload::load_all(quiet = TRUE); testthat::test_dir("tests/testthat")'`
- Fastest smoke test: `Rscript -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-package-helpers.R")'`

## App Entry Points / Wiring

- Main entry file(s):
- Routes / handlers / commands:
- Background jobs (if any):

## UI Styling

- Canonical styling system (repo-majority):
- Style entry files / patterns:
- Design tokens / CSS variables live in:
- Inline styles policy:

## Canonical Implementations (Per Feature)

- SDP package writing/reading → `R/package-helpers.R`
- SDP schema loading and field order → `R/schema-helpers.R` + `inst/extdata/sdp.schema.yaml`
- Dictionary validation and column semantics → `R/dictionary-helpers.R` + `R/validation_helpers.R`
- Semantic suggestion row shape, target keys, filtering, and LLM merge rules → `R/semantic-suggestions.R`
- Shared LLM/chat review response parsing and assessment rows → `R/llm-review-adapter.R`
- Public semantic retrieval and review workflow → `R/semantics-helpers.R` + `R/llm-semantic-helpers.R`
- Interactive decomposition review workflow → `R/chat-decomposition.R`
