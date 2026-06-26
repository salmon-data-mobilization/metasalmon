# metasalmon — next behaviours roadmap

Created 2026-06-26. A consolidating roadmap for the behaviours worth doing **next**,
after the `deepen-architecture` branch (executed) and the Alice Assmar `#1` fix
(closed, shipped in 0.1.4). This document is a triage + sequencing layer: it does
not re-derive the two detailed design drafts it points to, it decides what to pick
up and in what order, and it absorbs the incomplete items from the plans it
supersedes so nothing is lost.

## Purpose / Big Picture

Three planning artifacts already exist:

- `notes/exec-plans/2026-06-24-deepen-architecture-refactors.md` — the five
  "deep module" refactors (R1–R5). **Executed** on `deepen-architecture`
  (centralized LLM context/option policy, extracted semantic target discovery,
  deepened the review adapter, extracted `R/artifact-inference.R`, froze row
  contracts). Its *Missing/Future Refactor Candidates* are folded in below.
- `notes/exec-plans/2026-04-02-llm-semantic-fit-retrieval-gap-escalation.md` —
  **bundle-aware semantic fit** (the design detail for Theme A below).
- `notes/exec-plans/2026-04-02-i-adopt-chat-decomposition-draft.md` — the
  **interactive curation engine** (the design detail for Theme C below).

And the live backlog with implementation status:

- `notes/bugs-and-improvements.md` — 31 items; this roadmap references the open
  ones by number (e.g. *bug #4*).

What changes for the user, by theme: smarter and more honest semantic review
(Theme A), safer EDH export (Theme B), an interactive curation workflow (Theme C),
more robust context handling (Theme D), and a more maintainable codebase (Theme E).

## Status snapshot (2026-06-26)

- **Done / shipped:** the `#1` `llm_context_files` fix (0.1.4); R1–R5 refactors;
  the code-review fixes incl. the **first slice of gap escalation** —
  `reject_shortlist` that exploration cannot resolve now escalates to
  `request_new_term` (`.ms_llm_escalate_unresolved_rejection`).
- **Open behaviours to consider next:** this document.
- **Pending process:** `R CMD check` + a PR for `deepen-architecture` (see
  Process / Handoff).

## Context and Orientation

- The semantic-review pipeline and its contracts are documented in
  `notes/context.md` (target rows, the ~30-col assessment row, the review-adapter
  seam, LLM providers, the parse-once context pool).
- The five LLM review decisions are `accept`, `review`, `retry_search`,
  `request_new_term`, `reject_shortlist` (validator: `.ms_validate_llm_assessment`
  in `R/llm-semantic-helpers.R`). The vignette `vignettes/llm-context-review.Rmd`
  now explains them to users.
- "Slot" = one I-ADOPT role of a measurement column (property / entity / unit /
  constraint / method); "bundle" = the whole decomposition for one column.

---

## Theme A — Semantic-review intelligence (bundle-aware fit)  ★ highest value

Design detail: `2026-04-02-llm-semantic-fit-retrieval-gap-escalation.md`. This is
the natural next step because the `reject_shortlist → request_new_term` escalation
just shipped is the **first concrete slice** of that roadmap's gap-escalation phase.
Build the rest on top of it.

- **A1 — Whole-variable (bundle) review.** Judge the full decomposition together
  before finalizing any slot, instead of slot-by-slot nearest-neighbour picks.
  Routes through the existing decomposition path (`chat_decomposition()` /
  `.ms_llm_should_route_to_decomposition`); do **not** fork a second prompt stack
  (i-adopt-draft constraint). *Risk:* prompt complexity can help one provider and
  hurt another — keep per-provider regression fixtures.
- **A2 — Slot-aware second-pass retrieval.** Extend the existing bounded
  exploration round with role-specific source/query bias (unit → QUDT first;
  property/entity/constraint/method → `smn`/`gcdfo` first; role-specific query
  rewriting). *Risk:* unbounded oscillation — keep the one-round cap.
- **A3 — Deterministic bundle-fit validators.** Post-LLM checks that downgrade a
  bundle when a `constraint_iri` merely restates obvious context, a `method_iri`
  is chosen without method evidence, or unit/property/entity are incompatible.
  *Risk:* over-strict validators over-trigger new-term escalation — make them
  explain *why* a slot was rejected.
- **A4 — Richer structured gap escalation.** Today's escalation sets
  `llm_decision = request_new_term` with a rationale note but empty
  `llm_new_term_*`. Capture suggested label / definition / namespace
  (`smn` vs `gcdfo`) and why existing candidates were rejected, so the term-request
  workflow (`detect_semantic_term_gaps()` → `render_ontology_term_request()` →
  `submit_term_request_issues()`) can consume it directly. **Forward-compat note:**
  `reject_shortlist` currently round-trips with no reject-specific metadata column
  (review finding) — add an `llm_reject_reason`/new-term carrier to **both** the
  empty and success assessment-row builders in the same commit (row-shape symmetry
  invariant from the deepen plan).
- **A5 — `retry_search` re-issue handling (bug #13).** When the model's
  `retry_query` duplicates the original, record that on the assessment instead of
  silently spending a generic exploration round.

**Acceptance signal (from the source draft):** the Salish Sea catch benchmark stops
forcing `CatchContext` where it adds no clarity; `method_iri` stops getting
nonsensical procedure picks; gaps surface as `request_new_term` instead of forced
near-misses.

## Theme B — EDH export safety  ★ needs a product decision first

- **B1 — `create_sdp(include_edh_xml = TRUE)` guard (bug #4). ✅ DONE (draft warning).** The inline
  EDH-XML write bypasses the `.ms_abort_unreviewed_edh_rebuild` guard that
  `write_edh_xml_from_sdp()` enforces, so create-time XML can contain
  `MISSING METADATA:` / `REVIEW:` placeholders. **Decide:** (a) label create-time
  XML as a draft (filename/marker) and document it, or (b) route the inline write
  through the same guard/shared builder and only emit when clean. *Recommendation:*
  (a) — create-time output is inherently review-ready, not final; a draft marker is
  honest and non-breaking. Small, high-clarity behaviour change.

## Theme C — Interactive curation engine (i-adopt)  ★ largest

Design detail: `2026-04-02-i-adopt-chat-decomposition-draft.md`. The routing slices
(1–5) and `chat_decomposition()` itself already shipped (0.1.3). What remains is the
**follow-on engine** (draft slices 6–10):

- **C1 — Shared curation session engine** (`start_curation_session` /
  `run_curation_turn` / `propose_curation_patch` / `approve_curation_patch`) with
  structured session state separate from the transcript.
- **C2 — Question planner + grouped turns** (information-gain ranking; 3–7 questions
  for metadata, 2–4 for strict I-ADOPT).
- **C3 — Structured outputs + provenance bundle** (dataset/column patches,
  new-term request artifact, transcript/turn-summary/model provenance).
- **C4 — Provider adapter boundary + R-console UI** (`ms_chat(provider, messages,
  response_schema, ...)`; `cli` + `readline()` first). **This is where the shared
  chat request builder (bug #3 / Theme E2) belongs** — converging
  `.ms_llm_chat_json_request` and `.ms_chat_http_request` is the request-side half
  of this engine.
- **C5 — Retrieval / resume / narrowing** (chunk-and-index once; save/resume;
  top-k per unresolved item).

Sequence Theme C **after** Theme A so bundle-aware review and the curation engine
share one mature response/request contract rather than two.

## Theme D — Robustness hardening  (low risk, additive behaviours)

- **D1 — Context-file encoding detection (bug #6). ✅ DONE.** Non-UTF-8 inputs (e.g.
  Latin-1 CSVs) silently corrupt scoring; detect/allow encoding in the now-central
  context module.
- **D2 — Source-label disambiguation (bug #5). ✅ DONE.** Two context files sharing a
  basename collide in `chunk_id` and the `llm_context_sources` column; disambiguate
  while preserving the observable source-reporting contract.
- **D3 — `semantic_code_scope = "factor"` `dataset_id` key (bug #8). ✅ DONE.** Add
  `dataset_id` to the factor-code semi-join so multi-dataset `seed_codes` can't
  cross-match on a shared `table_id`/`column_name`.

## Theme E — Architecture finish-out  (from the deepen plan's Missing/Future)

- **E1 — Split `package-helpers.R` (bug #29, ~2975 lines).** Now that
  `R/artifact-inference.R` exists, split writing/validation/EDH post-processing from
  inference/orchestration; consider moving `infer_*_from_resources` (bug #30) out of
  `dictionary-helpers.R` into the artifact module. Public signatures must stay
  unchanged.
- **E2 — Shared chat request builder (bug #3).** Mutually exclusive with the
  adapter's dual-shape normalizer — do it **as part of Theme C4**, not standalone.
- **E3 — Real `AGENTS.md` content (bug #9). ✅ DONE.** Quick win: `CLAUDE.md`/`AGENTS.md`
  are a circular `@AGENTS.md` stub; seed real guidance from `notes/context.md`
  (LLM opt-in contract, attribute/IRI-prefix contracts, build/test commands).
- **E4 — Latent cleanups (bugs #22, #23, #24).** Drop the unused `.ms_bundle_key`
  `any_of` in the merge helper; forward the LLM-widened shortlist in the multi-table
  recursion guard; add a debug log when decomposition disables batching. Low
  priority; fold into whatever theme touches those files.

## Process / Handoff  (carried from the Alice + deepen plans)

- **P1 — `R CMD check`** on `deepen-architecture` (the deepen plan's validation
  ladder asks for it before merge; not yet run this session).
- **P2 — Open the PR** for `deepen-architecture` (the Alice plan's checkpoint G /
  PR handoff was never completed). Summarize: the 5 refactors, the code-review
  fixes, the doc sync; reference issue `#1` lineage.
- **P3 — Version decision.** The branch keeps `DESCRIPTION` at `0.1.4` and
  accumulates NEWS there. Decide whether to bump (`0.1.5` or dev `0.1.4.9000`)
  before merge.

## Recommended sequencing

1. **Clear the decks (days):** E3 (AGENTS.md), B1 (decide + implement EDH draft
   marker), D1–D3 (robustness), then P1 + P2 + P3 (validate, version, PR the
   current branch).
2. **Highest-value behaviour (the main thrust):** Theme A, in order
   A4 → A5 → A2 → A3 → A1 (start by completing the escalation/metadata that's
   already half-built, then deepen retrieval and bundle reasoning).
3. **Larger build-outs:** Theme C (curation engine, incl. E2) and E1 (god-file
   split), once A's contract is stable.

## Remaining-work provenance (so nothing is lost)

| Source | Item | Where it lives now |
|---|---|---|
| Alice plan (#1) | adjacent-bug investigation | `bugs-and-improvements.md` (done/tracked) |
| Alice plan (#1) | peer-review F | superseded by `/code-review` on `deepen-architecture` |
| Alice plan (#1) | peer-review G, final validation, PR | **P1–P2** above |
| Deepen plan | R1–R5 refactors | executed (branch commits) |
| Deepen plan | god-file split / `infer_*_from_resources` | **E1** (bugs #29/#30) |
| Deepen plan | shared chat request builder | **E2 / C4** (bug #3) |
| Deepen plan | real AGENTS.md | **E3** (bug #9) |
| Deepen plan | test-fixture consolidation | done (`helper-dictionary.R`) |
| bugs note | #4, #5, #6, #8, #13 | **B1, D2, D1, D3, A5** |
| bugs note | #22, #23, #24 | **E4** |
| retrieval-gap draft | bundle review / retrieval / validators / gaps | **Theme A** |
| i-adopt draft | session engine / planner / provenance / UI | **Theme C** |

## Decision Log

- 2026-06-26: Closed the Alice Assmar plan (core fix shipped in 0.1.4) and moved it
  from `docs/plans/` to `notes/exec-plans/`; created this roadmap rather than
  reopening it, because the remaining work is forward-looking and spans multiple
  sources.
- 2026-06-26: Did not duplicate the two 2026-04-02 design drafts; this roadmap
  points to them for Theme A and Theme C detail and records only sequencing +
  what's already partially built.
- 2026-06-26: Recommend Theme A before Theme C so both share one mature
  review/request contract.
- 2026-06-26: **B1 decided — draft marker, not a hard guard.** `create_sdp()`
  still writes create-time EDH XML (create-time output is inherently review-ready),
  but now emits a "DRAFT EDH" warning (reusing `.ms_collect_edh_review_state_issues`)
  when `REVIEW:`/`MISSING` markers remain, pointing to `write_edh_xml_from_sdp()`
  for a clean rebuild. Non-breaking. *Possible follow-up:* a distinct draft
  filename or an in-XML draft marker (deferred — the warning is sufficient now).
- 2026-06-26: D1 decoding fallback scoped to the main plain-text/CSV reader
  (`.ms_read_text_utf8`), where the reported Latin-1 case bites; the `.Rmd`/`.qmd`
  and HTML readers keep `encoding = "UTF-8"` (those are normally UTF-8 authored).
- 2026-06-26: D2 disambiguates only *colliding* basenames (parent dir, then a
  numeric suffix) so the observable `llm_context_sources` contract is preserved for
  the common unique-name case.

## Progress

- [x] 2026-06-26: Consolidated remaining behaviours; closed + moved the Alice plan;
  cross-referenced the deepen plan, the two design drafts, and the bugs note.
- [x] 2026-06-26: B1 decided + implemented (draft-EDH warning) with a test.
- [x] 2026-06-26: D1 (context-file encoding fallback), D2 (source-label
  disambiguation), D3 (factor-scope `dataset_id` key) implemented with tests; full
  suite green (1291 pass / 0 fail).
- [x] 2026-06-26: E3 — real `AGENTS.md` (seeded from `notes/context.md`); resolves
  the circular `@AGENTS.md` stub. `CLAUDE.md` imports it; the pkgdown artifact is
  git-ignored so nothing leaks to the public site.
- [ ] P1 (`R CMD check`), P2 (PR), P3 (version decision).
- [ ] Begin Theme A (A4 → A5 → A2 → A3 → A1).

## Validation and Acceptance

- Each behaviour change ships with focused `testthat` coverage and keeps the full
  suite green (`Rscript -e 'devtools::test()'`).
- Observable behaviour changes get a `NEWS.md` entry and roxygen/vignette updates,
  then `devtools::document()` + a lazy `pkgdown::build_site(lazy = TRUE)`.
- Public function signatures stay unchanged unless a separate compatibility
  decision is logged here.
- `R CMD check` before any merge (P1).
