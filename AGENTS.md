# metasalmon — agent & contributor guidance

`metasalmon` is an R package that scaffolds, standardizes, validates, and packages
salmon datasets into **Salmon Data Packages (SDP)** using the DFO Salmon Ontology.
Start with `knowledge/orientation.md` (architecture, the semantic-review
pipeline, glossary, file→responsibility map). This file is the rules; their
history and reasoning are in `knowledge/contract-history.md`.

**This repo is also the coordinating hub** for the salmon data ecosystem, whose
member repositories are the generated `member-list` block of
`knowledge/domains/salmon-data-ecosystem.md`. Sequencing, execplans and the
cross-repo release index live in the `knowledge/` OKF bundle, starting at
`knowledge/roadmap.md`.

**Planning state lives in `queue/`**, one file per work item, and the claim
protocol is in `HUB.md`. A card that restates queue state is a defect, and the
card is the wrong copy. Read `queue/README.md` before editing under `queue/`.

**This repository adopts `HUB.md` § *Coherent batches*** (requested 2026-10-01;
operative only after that policy merges). Another member repository needs its
own `AGENTS.md` adoption. The contracts below still apply to a batch.

## Non-negotiable contracts (do not break without a logged decision)

- **metasalmonpy mirrors this package, always** (Brett, 2026-08-13). Any change
  requested or made here is presumed to need the same change in metasalmonpy
  (`salmon-data-mobilization/metasalmonpy`, formerly `metaSmnPy`), in the same
  stream or with the reason logged in the roadmap card.
  - **Parity is behavioural, not literal** (Brett, 2026-08-15): no forced API
    mimicry where it is unintuitive in Python, and language differences that
    change no behaviour or capability are fine. Every deliberate difference is
    recorded in `knowledge/parity-deviations.md` here and `PARITY.md` there, in
    the PR that introduces it; an undocumented difference is a violation even
    when the difference itself is fine.
  - **Functionality and release numbers stay in lockstep**: metasalmonpy's
    version is a parity claim, bumped only when the mirrored behaviour lands.
    **Measured 2026-11-25: both packages read 0.6.0 on `main`** (metasalmon's
    `DESCRIPTION`, metasalmonpy's `pyproject.toml`), so no catch-up window is
    open. When either version moves, read the other package's `AGENTS.md` in the
    same change; the roadmap's release index is the third copy and must agree
    with both. A sentence describing the copies is a dated measurement, never a
    substitute for reading them. Both `AGENTS.md` files carry this contract and
    are never git-ignored.
  - **The mirror is not automatically the follower** (Brett, 2026-08-17: *"If
    the Python implementation got it right, then update metasalmon."*).
    Direction is decided per divergence, "R leads" is no tiebreak, and changing
    R does not close a parity row: the row records the divergence, the ruling
    and which side moved.
- **The `smn-sci-plgn` skills follow the tools** (Brett, 2026-11-24). A change
  that alters what a skill says (a release of metasalmon, metasalmonpy or the
  SDP spec; a function renamed, removed or deprecated; a changed review
  workflow; an ontology, vocabulary or commons change a skill relies on)
  updates the affected skills in the same stream, or files a queue item on
  `smn-sci-plgn` naming the stale skill and what changed. A release is not
  finished while a skill pins the version it replaced and no item records the
  lag. `metasalmon-skill` and `sdp-semantic-review` move with this package;
  `salmon-terms`, `controlled-vocabulary`, `psc-vocabulary`, `graph-discovery`
  and `commons-card` with the ontologies, PSC CV and commons (read from the
  plugin's `skills/` at `v0.2.0` on 2026-11-24; that directory is the
  authority). *Retires when:* the plugin's CI fails on a skill pinning a
  version older than the ecosystem's current release.
- **LLM review is strictly opt-in.** Supplying `llm_context_files` /
  `llm_context_text` never triggers a network or LLM call; review runs only when
  `llm_assess = TRUE` (and, for `infer_dictionary()`, `seed_semantics = TRUE`).
  Options that will be ignored warn rather than silently no-op (the 0.1.4 fix).
  - **The model call leaves both packages** (Brett, 2026-09-25, hub Q67;
    [S16 card](knowledge/sequences/s16-model-call-leaves-the-packages.md)).
    This contract governs every release still carrying the call. B-326
    deprecates it: `llm_assess = TRUE`, the eleven `llm_*` arguments and
    `chat_decomposition()` warn once per top-level call (class
    `metasalmon_llm_deprecated`, silenced suite-wide by the option
    `metasalmon.llm_deprecation_quiet`) and are removed in 0.7.0. B-329
    deletes it, after which the packages make no model call at all, so
    provider-path work matters only until then.
  - **Judgement runs in the user's harness against a file**:
    `write_semantic_review_packet()` writes `review/semantic-review-packet.json`
    and `ingest_semantic_assessments()` reads
    `review/semantic-assessments-pass-<n>.csv`. The file contract is the schema
    and instructions in `inst/extdata/semantic-review/`: `packet_id` hashes the
    canonical bytes minus `packet_id` and `producer`; the harness names the
    packet it judged in a sidecar `<csv>.packet-id` (or the caller passes
    `packet_id`); an IRI the packet did not offer is never applied; a retry is
    a second harness pass on a continuation packet, and nothing from that
    target merges until it is answered; a rejected shortlist earns no second
    pass; harness free text is redacted at capture. Column ownership and
    requiredness live in `.ms_semantic_review_output_columns()` and are written
    into every packet.
  - **Neither function may reach a model provider**; the network is reached only
    through `search_fn`, as `tests/testthat/test-semantic-review-packet.R`
    proves by walking the call graph. The schema, instructions and fixtures
    (`tests/testthat/fixtures/semantic-review/v1/`) are one contract that
    metasalmonpy vendors byte-identically (B-327) and compares in
    `tests/test_semantic_review_parity.py`; changing any needs the same change
    there.
- **Context inputs are file paths or inline text, never parsed objects.**
  Passing a tibble, XML or data frame to `llm_context_files` errors early.
- **Preserve public signatures and return-value attributes** of exported
  functions (`create_sdp()`, `infer_salmon_datapackage_artifacts()`,
  `infer_dictionary()`, `suggest_semantics()`, etc.): `infer_dictionary()`'s
  `inferred_*` (multi-table) / `seed_*` (single-table) and
  `suggest_semantics()`'s `semantic_suggestions` (plus
  `semantic_llm_assessments` when `llm_assess`). Other modules and tests read
  them.
- **Frozen column contracts:** the 19-column semantic target row
  (`.ms_semantic_target_cols()`) and the 30-column LLM assessment row
  (`R/llm-review-adapter.R`), whose row builders read target columns
  positionally, so a rename or reorder breaks them; empty and success rows keep
  identical column sets. The assessment row stays frozen after the model call
  is gone, as the contract a harness writes and the ingester reads (Q67). Every
  row comes from the two builders and leaves through the one normalizer,
  persisted in `review/semantic-llm-assessments.csv` under
  `.ms_llm_assessment_cols()`.
- **Observable markers:** the `REVIEW:` IRI prefix (strict validation fails if
  any remain) and the `llm_context_sources` output column.
- **A semantic role is a contract across seven surfaces.** Adding or renaming a
  role (`variable`, `property`, `entity`, `unit`, `constraint`,
  `statistical_modifier`; `method` for code values only) touches: **(1)** the
  target/role maps (`semantic-suggestions.R`, `role_to_field` in
  `semantics-helpers.R`); **(2)** bundle roles and slot fields, prompt included
  (`semantic-bundle-review.R`); **(3)** role hints (`.smn_role_flags` and its
  emitter in `term_search_smn.R`, the RDF/XML hint builder in
  `term_search.R`); **(4)** retrieval filters (`sources_for_role()`,
  `.gcdfo_filter_for_role()`); **(5)** validators
  (`semantic-bundle-validators.R`); **(6)** ranking preferences
  (`inst/extdata/ontology-preferences.csv`); **(7)** `role_boost` in
  `.ranking_profile_defaults()`. A missed layer fails silently, so assume an
  eighth surface exists and look for it.
  `tests/testthat/test-role-contract-guard.R` checks all seven (`SURFACE 1` to
  `7`); keep its `hint_roles`, `hint_to_sources` and `role_evidence_validators`
  lists current when a role is added, renamed or exempted.
- **A semantic choice made inside a code change is the one review misses.** A
  PR that chooses, changes or removes an ontology term IRI says so, and what
  justified it other than the validator accepting it. If the answer is "it made
  validation pass", file a queue item for its appraisal rather than letting it
  merge unexamined (`.github/PULL_REQUEST_TEMPLATE.md` asks). *Retires when:*
  a competency-question test fails on an unjustified term choice.
- **A guard must say what would retire it.** Every suppression, exclusion,
  allowlist entry, skip or workaround records when it stops being needed: the
  defect it routes around, the version that fixes it, or its successor. Lists
  that name their own maintenance rule (`collation_sensitive_fns`,
  `hint_roles`) are the model.
- **An empty result is a claim about the instrument, not the target** (Brett,
  2026-09-25). Establish reach with a positive control, something known present
  that the same command must return; check a plausible count against the
  source by hand; and where the target is the authority other copies defer to,
  read it, because no instrument clears it. `queue/README.md` corollaries 7 and
  8 narrow this for a queue sweep. *Retires when:* a sweep carries its own
  positive control and fails when the control does not come back.
- **C collation for anything reproducible.** An ordering that is hashed,
  written to file bytes, embedded in an identifier, returned by an exported
  function or asserted by a validator uses `sort(..., method = "radix")`,
  `order(..., method = "radix")` or `dplyr::arrange(..., .locale = "C")`;
  locale ordering is only for text no machine re-checks. A new function
  producing canonical bytes, a hash or a PID joins `collation_sensitive_fns` in
  `tests/testthat/test-collation-guard.R`.
- **One value, one rendering, chosen by type** (Brett, 2026-08-24, Q12). A value
  that becomes canonical bytes is rendered to text once, and every sort key,
  comparison key and emitted byte reads that rendering, through
  `.ms_canonical_character()` (`R/platform-time.R`), whose per-type dispatch is
  load-bearing: character is never re-rendered. No static guard sees a
  violation, so ask of any canonical emitter: *is the thing I sorted the thing I
  wrote?* `.ms_canonical_character()` pads a `POSIXct`;
  `.ms_iso_date_columns()`, on the `readr::write_csv()` path, deliberately does
  not, because the baseline decides, not the type. Name a new renderer's
  baseline first; `tests/testthat/test-canonical-date-render.R` pins the
  difference.
- **External text is never a cli template.** LLM output, HTTP responses,
  ontology labels and users' CSV text go through `.ms_cli_escape()` /
  `.ms_cli_bullets()` (`R/cli-safety.R`) before `cli_abort`/`cli_warn`/
  `cli_inform`, because cli evaluates braces as code. Redact secrets where text
  is captured, not where it is displayed. Enforced by
  `tests/testthat/test-cli-safety-guard.R`.
- **LLM review decisions:** `accept`, `review`, `retry_search`,
  `request_new_term`, `reject_shortlist`; keep the last two distinct. Any final
  `reject_shortlist` escalates to `request_new_term`, surfacing an ontology gap,
  whatever the decision before a retry (B-361, ruled 2026-09-25); in the packet
  contract it earns no second pass, and only `retry_search` widens a
  shortlist.

## Releases

- Every release from 0.3.0 on is an annotated `vX.Y.Z` tag and a GitHub Release
  with its `NEWS.md` entry as the body (Brett, 2026-08-15), tagged on the
  commit that made the version current. 0.2.0–0.2.6 stay untagged.
- A change merged after the bump commit and before the tag goes under the
  development heading (`NEWS.md`'s *metasalmon (development version)*,
  metasalmonpy's `## Unreleased`), never under the version it did not ship in;
  the tag stays on the bump commit (Brett, 2026-09-16). Only a dated correction
  (`*(Correction, YYYY-MM-DD: …)*` or `[corrected YYYY-MM-DD: …]`) may be
  appended to a shipped entry.
- Before tagging, run `python3 scripts/check-changelog-window.py` on an
  up-to-date `main` in a full clone; a red run moves the entry to the
  development heading first. It also runs on every PR, and its docstring says
  what it checks and what it does not (hub items B-200 and B-201).

## Build / test / docs

```r
pkgload::load_all(".", quiet = TRUE)                      # fast dev reload
Rscript -e 'devtools::test()'                             # full suite (must stay green)
testthat::test_file("tests/testthat/test-<area>.R", reporter = "summary")
devtools::document()                                     # after roxygen changes
Rscript scripts/build-pkgdown.R                          # after doc changes
Rscript scripts/build-pkgdown.R --news-only              # when only NEWS changed
```

```sh
git diff --check
R CMD build . && R CMD check <tarball>   # local pass

# The line CI runs (.github/workflows/R-CMD-check.yaml). `error_on = "warning"`
# means any WARNING fails the merge, so run this rather than reading `Status: OK`.
Rscript -e 'rcmdcheck::rcmdcheck(args = "--no-manual", error_on = "warning")'
```

A green local check is evidence about your R, not CI's, which runs the current
release: before merging on a local run, compare `R.version.string` with the CI
log. Add a `NEWS.md` entry for any observable behaviour change. `knowledge/`,
`notes/` (only the CI-wired `notes/evidence/theme-a/`) and `docs/` (pkgdown
output; `docs/AGENTS.html`, `docs/CLAUDE.html` and `docs/plans/` are
git-ignored) are excluded from `R CMD build`. Some tests skip without optional
deps (`pdftools`, `readxl`, `openxlsx`, `frictionless`) or network
(`w3id.org`), so a green offline run is not full coverage.

## Conventions & gotchas

- Tidyverse style; native pipe where it reads well. Internal helpers are
  `.ms_`-prefixed, in topic files under `R/`. R code is ASCII (comments
  exempt).
- Core files run to thousands of lines (`package-helpers.R`,
  `knb-publication.R`, `eml-export.R`, `term_search.R`,
  `llm-semantic-helpers.R`): delegate broad reads.
- `create_sdp()` calls `infer_dictionary()` with `seed_semantics = FALSE`, so
  the latter's LLM/option blocks run only when it is called directly.
- Test hooks: inject `search_fn` / `llm_request_fn` (a `stop()`ing function
  proves the LLM was not called); mock `find_terms` with `with_mocked_bindings`
  on the `create_sdp` / `infer_dictionary` paths.

## Planning artifacts: the `knowledge/` OKF bundle

- **`knowledge/roadmap.md`**: what next, in what order, blocked by what, plus
  the cross-repo release index. Undated, edited in place, the single
  sequencing authority for the ecosystem. Start here.
- **`knowledge/sequences/`**: one card per stream.
- **`knowledge/backlog.md`**: every known defect with evidence. Severity lives
  in the queue item's `severity` field (Brett, 2026-09-25, Q-52), ordering in
  the roadmap.
- **`knowledge/plans/*.md`**: dated execplans, linked from the sequence card
  before implementation starts.

The SDP method-model draft is `knowledge/method-model-draft.md`. Validate with
`uv run --project ../psc-data-systems psc-okf check knowledge --tier capture`
from the repo root. Cards are git-tracked and hold **no absolute filesystem
paths**. Durable knowledge about a sibling repo goes into that repo's own
`knowledge/` bundle (create it if absent), and its `AGENTS.md` keeps pointing at
it.

## Durable salmon knowledge goes to the commons

Knowledge about **salmon** (biology, ecology, management, what a term means, why
a modelling choice went as it did) goes to
[`salmon-knowledge-commons`](https://github.com/salmon-data-mobilization/salmon-knowledge-commons),
not into a PR, commit message or chat. Open a PR there if you can; otherwise put
the finding, with its sources, in your report. Claims need citations, and you
never assert your own verification (`generated` is who wrote a card,
`verified` who independently checked it). Record an **ontology gap** there,
not in a transcript: a concept with no term in `smn`, `gcdfo` or the PSC CV,
what a term would have to say and where it should be minted. That register is
the front end of `detect_semantic_term_gaps()` →
`render_ontology_term_request()` → `submit_term_request_issues()`.
