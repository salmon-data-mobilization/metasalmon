# metasalmon — agent & contributor guidance

`metasalmon` is an R package that scaffolds, standardizes, validates, and packages
salmon datasets into **Salmon Data Packages (SDP)** using the DFO Salmon Ontology.
Start with `knowledge/orientation.md` — it is the durable orientation
(architecture, the semantic-review pipeline, domain glossary,
file→responsibility map). This file is the short, must-know contract;
`knowledge/orientation.md` is the detail.

**This repo is also the coordinating hub** for the salmon data ecosystem
(metasalmonpy, `smn-data-pkg`, `salmon-domain-ontology`, `dfo-salmon-ontology`,
`psc-salmon-vocabularies`): sequencing, execplans, and the cross-repo release
index live in the `knowledge/` OKF bundle, starting at `knowledge/roadmap.md`.

## Non-negotiable contracts (do not break without a logged decision)

- **metasalmonpy mirrors this package — always.** (Brett, 2026-08-13.) Any
  change requested or made in metasalmon is **presumed to require the same
  change in metasalmonpy** (github `salmon-data-mobilization/metasalmonpy`,
  formerly `metaSmnPy`); implement it there in the same stream or log in the
  roadmap card why not. **Parity is behavioural, not literal** (Brett,
  2026-08-15): do not force 100% API mimicry where it would be unintuitive
  for Python users, and simple language differences that do not materially
  change behaviour or capability are fine — but every deliberate difference
  is recorded in `knowledge/parity-deviations.md` here AND `PARITY.md` there,
  in the same PR that introduces it. An undocumented difference is a
  contract violation even when the difference itself is fine. Functionality and **release numbers stay in lockstep**
  — metasalmonpy's version is a parity claim, bumped to match metasalmon only
  when the mirrored behaviour actually lands. Current state: metasalmonpy is
  at 0.1.7 parity; the 0.1.8→0.3.0 catch-up is roadmap stream S10. The same
  contract is stated in metasalmonpy's `AGENTS.md`; both files are
  git-tracked and must never be git-ignored.
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
- **A semantic role is a contract across five layers, not a string.** Adding
  or renaming a role (`variable`, `property`, `entity`, `unit`, `constraint`,
  `statistical_modifier`; plus `method` for code values only) means touching
  all of: the target/role maps (`semantic-suggestions.R`, `semantics-helpers.R`
  `role_to_field`), the bundle roles and slot fields
  (`semantic-bundle-review.R`), **the role-hint vocabulary** (`.smn_role_flags`
  + the emitter in `term_search_smn.R`, and the RDF/XML hint builder in
  `term_search.R`), the retrieval filters (`sources_for_role()` and
  `.gcdfo_filter_for_role()`), and the deterministic validators
  (`semantic-bundle-validators.R`). The hint layer is the one that gets
  forgotten, and forgetting it is silent and total: `.ms_validate_semantic_role_type()`
  vetoes any accept whose candidate carries hints not naming the role, so a
  role with no hint emitter has **100% of its correct accepts downgraded** to
  `review` while every test using a hand-written `role_hints` fixture still
  passes. That is exactly how sdp-0.3.0's `statistical_modifier` shipped
  broken through CI and PR review; see the 0.3.0 NEWS entry. Ranking
  preferences are the sixth surface and fail the same way: a role with no
  `inst/extdata/ontology-preferences.csv` row ranks with no source preferences
  at all. **`tests/testthat/test-role-contract-guard.R` checks every layer** —
  it reads the slot fields as the authority and inspects the emitter and filter
  bodies, so keep its `hint_roles` and `hint_to_sources` lists current when a
  role is added, renamed, or deliberately exempted.
- **A guard must say what would retire it.** Every suppression, exclusion,
  allowlist entry, skip, or workaround records *the condition under which it
  stops being needed* — the defect it routes around, the version that fixes
  it, the successor that supersedes it. Without that, a guard outlives its
  cause and then conceals the failure it was never written for, and reading
  it alone tells you nothing is wrong. Observed three times on 2026-08-16
  alone: a gcdfo CI exclusion added five weeks *before* the normalizer whose
  crash it ended up hiding, with nothing in the repo connecting the two; a
  `make` recipe whose missing `set -e` printed a success mark over a crashing
  script; and duplicate placement guards in `migrate_sdp_methods()` that
  became unreachable when the real checks moved earlier, leaving dead code
  that invited someone to weaken the live copy. The existing decay-resistant
  lists here work because they name their own maintenance rule
  (`collation_sensitive_fns`, `hint_roles`); apply the same discipline to
  anything that silences a signal.
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

## Releases

Every release from **0.3.0 forward** is tagged (`vX.Y.Z`, annotated) **and**
published as a GitHub Release with its `NEWS.md` entry as the body (Brett,
2026-08-15). Tag the commit that made the version current, not a later
docs-only merge. Releases 0.2.0–0.2.6 are deliberately untagged history — do
not backfill them.

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

Add a `NEWS.md` entry for any observable behaviour change. `knowledge/`,
`notes/` (now only `notes/evidence/theme-a/`, which is CI/test-wired), and
`docs/` are excluded from `R CMD build`; `docs/` is the pkgdown output (and
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

## Planning artifacts — the `knowledge/` OKF bundle (read before related work)

Planning and durable knowledge live in the `knowledge/` Open Knowledge Format
bundle (migrated from `notes/` on 2026-08-13; only the CI/test-wired
`notes/evidence/theme-a/` stayed behind). Four document types, one job each:

- **`knowledge/roadmap.md` — what to do next, in what order, blocked by what,
  and the cross-repo release index.** Undated, edited in place, the single
  sequencing authority for the whole ecosystem. Start here.
- **`knowledge/sequences/`** — one card per stream (S1–S11) with the detail the
  roadmap card deliberately omits.
- **`knowledge/backlog.md`** — every known defect with evidence, the live index
  of open items. Severity lives here; *ordering* lives in the roadmap, and the
  two legitimately differ.
- **`knowledge/plans/*.md`** — how to do one stream, in detail. Dated, because
  each is a record of a decision at a point in time. A sequence card links to
  its execplan before implementation starts.

Orientation is `knowledge/orientation.md`; the SDP method-model draft is
`knowledge/method-model-draft.md`. Keep the bundle valid — from the repo root,
with a sibling `psc-data-systems` checkout:

```sh
uv run --project ../psc-data-systems psc-okf check knowledge --tier capture
```

Bundle cards are git-tracked and must contain **no absolute filesystem paths**.
When ecosystem work reveals durable knowledge about a sibling repo, update
*that repo's* `knowledge/` bundle (create it if absent) and keep its
`AGENTS.md` pointing at it.
