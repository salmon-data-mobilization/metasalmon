# metasalmon — agent & contributor guidance

`metasalmon` is an R package that scaffolds, standardizes, validates, and packages
salmon datasets into **Salmon Data Packages (SDP)** using the DFO Salmon Ontology.
Start with `notes/context.md` — it is the durable orientation (architecture, the
semantic-review pipeline, domain glossary, file→responsibility map). This file is
the short, must-know contract; `notes/context.md` is the detail.

## Non-negotiable contracts (do not break without a logged decision)

- **LLM review is strictly opt-in.** Supplying `llm_context_files` /
  `llm_context_text` must NEVER trigger a network/LLM call. LLM review runs only
  when `llm_assess = TRUE` (and, for `infer_dictionary()`, `seed_semantics = TRUE`).
  This is the contract behind the 0.1.4 fix; supplying options that will be ignored
  should warn, not silently no-op.
- **Context inputs are file paths or inline text — never parsed objects.** Passing
  a tibble/XML/data frame to `llm_context_files` must error early.
- **Preserve public signatures and return-value attributes.** Exported:
  `create_sdp()`, `infer_salmon_datapackage_artifacts()`, `infer_dictionary()`,
  `suggest_semantics()`, etc. `infer_dictionary()` attaches `inferred_*`
  (multi-table) / `seed_*` (single-table) attributes; `suggest_semantics()`
  attaches `semantic_suggestions` (+ `semantic_llm_assessments` when `llm_assess`).
  These are read by other modules and many tests.
- **Frozen column contracts:** the 19-col semantic target row
  (`.ms_semantic_target_cols()`) and the ~30-col LLM assessment row
  (`R/llm-review-adapter.R`). The adapter's row builders read target columns
  positionally — a rename/reorder breaks them. Empty and success assessment rows
  must keep identical column sets.
- **Observable markers to preserve:** the `REVIEW:` IRI prefix (strict validation
  fails if any remain) and the `llm_context_sources` output column.
- **C collation for anything reproducible.** Any ordering whose result is
  hashed, written to file bytes, embedded in an identifier, returned by an
  exported function, or asserted by a validator must use explicit C collation:
  `sort(..., method = "radix")`, `order(..., method = "radix")`, or
  `dplyr::arrange(..., .locale = "C")`. Locale-dependent ordering is fine only
  for text a human reads and no machine re-checks. When you add a function that
  produces canonical bytes, a hash, or a PID, **add it to
  `collation_sensitive_fns` in `tests/testthat/test-collation-guard.R`** — that
  list is what keeps the guard from decaying.
- **External text is never a cli template.** Text from an LLM provider, an HTTP
  response, an ontology label, or a user's CSV must be wrapped in
  `.ms_cli_escape()` / `.ms_cli_bullets()` (`R/cli-safety.R`) before it reaches
  `cli_abort`/`cli_warn`/`cli_inform`. cli interpolates every element of a
  message vector, so unescaped braces are evaluated as code — and an unbalanced
  brace replaces the message with a parse error. Redact secrets where external
  text is *captured*, not where it is displayed. Enforced by
  `tests/testthat/test-cli-safety-guard.R`.
- LLM review decisions: `accept`, `review`, `retry_search`, `request_new_term`,
  `reject_shortlist`. An unresolved `reject_shortlist` escalates to
  `request_new_term` (surfaces an ontology gap) — keep that distinction.

## Build / test / docs

```r
pkgload::load_all(".", quiet = TRUE)                      # fast dev reload
Rscript -e 'devtools::test()'                             # full suite (must stay green)
testthat::test_file("tests/testthat/test-<area>.R", reporter = "summary")
devtools::document()                                     # after roxygen changes
Rscript scripts/build-pkgdown.R                          # after doc changes
```

```sh
git diff --check
R CMD build . && R CMD check <tarball>   # before merging
```

Add a `NEWS.md` entry for any observable behaviour change. `notes/` and `docs/`
are excluded from `R CMD build`; `docs/` is the pkgdown output (and
`docs/AGENTS.html`/`docs/CLAUDE.html`/`docs/plans/` are git-ignored). Some tests
skip without optional deps (`pdftools`, `readxl`, `openxlsx`, `frictionless`) or
network (`w3id.org`) — don't read a green offline run as full coverage.

## Conventions & gotchas

- Tidyverse style; native pipe where it reads well. Internal helpers are
  `.ms_`-prefixed and live in topic files under `R/`.
- Core files are large (`package-helpers.R` ~3k lines, `term_search.R` ~89KB,
  `llm-semantic-helpers.R`/`semantics-helpers.R` ~1.5k each) — delegate broad
  reads.
- On the `create_sdp()` path, `infer_dictionary()` is called with
  `seed_semantics = FALSE`, so its own LLM/option blocks are dead there and only
  run when `infer_dictionary()` is called directly.
- Test hooks: inject `search_fn` / `llm_request_fn` (a `stop()`ing fn is the
  sentinel proving the LLM was not called); mock `find_terms` via
  `with_mocked_bindings` on the `create_sdp`/`infer_dictionary` paths.

## Planning artifacts (read before related work)

- `notes/context.md` — orientation.
- `notes/bugs-and-improvements.md` — live backlog with implementation status.
- `notes/exec-plans/2026-06-26-next-behaviours-roadmap.md` — what's next.
- `notes/exec-plans/2026-06-24-deepen-architecture-refactors.md` — the executed
  architecture refactor.
- `notes/exec-plans/2026-04-02-*` — the bundle-aware semantic-fit and i-adopt
  chat-decomposition design drafts.
