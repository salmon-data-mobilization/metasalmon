# Deepen metasalmon architecture after `llm_context_files` fix

## Purpose

This plan records five follow-up refactors suggested after fixing Alice
Assmar's `llm_context_files` report in metasalmon 0.1.4. The 0.1.4 fix is the
right small fix for the issue: it preserves explicit LLM opt-in, validates
context-file inputs early, warns when context is ignored, updates docs, and is
covered by focused tests. The refactors below should not be folded into that
patch release.

The goal here is deeper internal Modules: smaller Interfaces for callers and
tests, more behavior behind each Interface, and better Locality when semantic
review rules change.

Base state for this plan:

- Branch: `deepen-architecture`
- Base commit: `df17aed` (`Release 0.1.4`)
- Immediate trigger: issue #1, where a parsed data dictionary was passed to
  `llm_context_files` without `llm_assess = TRUE`.

## Progress

- [x] 2026-06-25 10:45 PDT: Resumed implementation on the existing
  `deepen-architecture` branch, with `notes/context.md` and
  `notes/bugs-and-improvements.md` present in the worktree as review inputs.
- [x] 2026-06-25 10:52 PDT: Fixed
  `infer_dictionary(seed_semantics = FALSE, ...)` silently dropping LLM/context
  options. Added a shared internal warning helper, a NEWS entry, and a
  multi-table regression test asserting the warning is emitted once before list
  recursion. Validation:
  `Rscript -e 'devtools::test(filter = "dictionary-helpers", reporter = "summary")'`
  and
  `Rscript -e 'devtools::test(filter = "package-helpers", reporter = "summary")'`
  both passed; warnings were the existing deterministic LLM-fallback /
  semantic-gap warnings.
- [x] 2026-06-25 11:05 PDT: Consolidated duplicated dictionary test fixtures
  before target-row and artifact-orchestration refactors. Added canonical
  `test_dictionary()`, `test_spawner_dictionary()`, `test_count_dictionary()`,
  and `test_shortlist_search()` helpers in `tests/testthat/helper-dictionary.R`;
  replaced repeated LLM/semantic/count fixtures where the fixture shape was
  ordinary rather than intentionally specialized. Validation:
  `Rscript -e 'devtools::test(filter = "llm-semantic-helpers|semantic-suggestions", reporter = "summary")'`
  and
  `Rscript -e 'devtools::test(filter = "dictionary-helpers", reporter = "summary")'`
  both passed with the same expected optional-PDF skips and deterministic
  LLM-fallback warnings.
- [x] 2026-06-25 11:22 PDT: Implemented R1/R2. Added
  `.ms_apply_llm_context_policy()` for `suggest_semantics()` entry-policy
  handling, `.ms_llm_review_plan()` for dictionary/artifact LLM option planning,
  and removed the duplicated `llm_requested` predicates plus three duplicated
  11-argument LLM tails. Preserved caller-owned base `suggest_args` lists,
  including `include_dwc = FALSE` only on the artifact path. Enforced the
  parse-once invariant by making `.ms_prepare_context_chunks()` require a
  pre-collected context pool, then updated white-box tests to pass an explicit
  empty pool. Added public-entry coverage for file + inline context with
  `llm_assess = FALSE` and an internal test proving one pool can be scored
  differently per target. Validation:
  `Rscript -e 'devtools::test(filter = "llm-semantic-helpers", reporter = "summary")'`
  and
  `Rscript -e 'devtools::test(filter = "dictionary-helpers|package-helpers", reporter = "summary")'`
  passed with the expected optional-PDF skips and deterministic LLM-fallback /
  semantic-gap warnings.
- [x] 2026-06-25: Froze the R3/R4 row contracts before moving producer or
  consumer code. Added tests pinning `.ms_semantic_target_cols()` and the full
  LLM assessment row column order for both empty and success rows. Validation:
  `Rscript -e 'devtools::test(filter = "semantic-suggestions", reporter = "summary")'`
  passed.
- [x] 2026-06-25: Implemented R3 target discovery extraction. Moved the
  target-building closure cluster and all column/code/table/dataset target
  builders into `.ms_semantic_discover_targets()`, leaving retrieval,
  role-collision annotation, LLM review, attributes, and user messages in
  `suggest_semantics()`. Added direct target-discovery tests for the 19-column
  target contract, all four SDP scopes, measurement-parented code expansion,
  table query basis, dataset target file, and paired value/unit
  `resource_lookup` context. Explicitly documented that
  `.ms_semantic_column_term_target_from_dictionary()` remains a narrow
  candidate-row fallback rather than the full six-role discovery path.
  Validation:
  `Rscript -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-semantic-suggestions.R", reporter = "summary"); testthat::test_file("tests/testthat/test-dictionary-helpers.R", reporter = "summary")'`
  and
  `Rscript -e 'devtools::test(filter = "semantic-suggestions|dictionary-helpers|llm-semantic-helpers|package-helpers", reporter = "summary")'`
  passed with the expected optional-PDF skips and deterministic LLM-fallback /
  semantic-gap warnings.
- [x] 2026-06-25: Implemented R4 review-adapter deepening and robustness fixes.
  Preserved the bare semantic-review response shape and the wrapped
  chat-decomposition response shape, and improved malformed wrapped-content
  errors with a short sanitized content snippet. Removed the thin semantic
  helper wrappers so orchestration calls adapter row builders directly while
  record unpacking remains outside the adapter. Aligned generic, decomposition,
  and batch prompts with the validator's `reject_shortlist` decision; kept the
  frozen assessment row contract by using `llm_decision == "reject_shortlist"`
  plus `llm_rationale` as the reject carrier rather than adding a new column.
  Changed batch validation to preserve valid sibling rows, detect malformed and
  duplicate `target_key` items, and fall back only affected keys to per-target
  review. Fixed the exploration reassessment edge case where a failed
  reassessment could remap an old selected index onto a reordered candidate
  list. Validation:
  `Rscript -e 'devtools::test(filter = "semantic-suggestions|llm-semantic-helpers|chat-decomposition", reporter = "summary")'`
  and
  `Rscript -e 'devtools::test(filter = "semantic-suggestions|dictionary-helpers|llm-semantic-helpers|package-helpers|chat-decomposition", reporter = "summary")'`
  passed with the expected optional-PDF skips and deterministic LLM-fallback /
  semantic-gap warnings.
- [x] 2026-06-25: Implemented R5 artifact-inference extraction while preserving
  public `infer_dictionary()` attribute contracts. Added `R/artifact-inference.R`
  with `.ms_infer_resource_dictionary()` and
  `.ms_infer_resource_artifact_context()`. `infer_salmon_datapackage_artifacts()`
  now builds combined resource dictionaries through the internal resource
  builder instead of invoking public list-mode `infer_dictionary()`. Both
  `infer_dictionary()` list inputs and package artifact inference share the
  metadata/code/dataset context helper, with explicit `mode = "dictionary"` vs
  `mode = "package"` so bare seed override behavior remains separate from
  package-only normalization, legacy estimate-method prefill, and
  `semantic_code_scope` filtering. Added a single-table compatibility test that
  freezes the disjoint `seed_*` attribute scheme and asserts it does not attach
  multi-table `inferred_*` attributes. Validation:
  `Rscript -e 'devtools::test(filter = "dictionary-helpers|package-helpers", reporter = "summary")'`
  and `Rscript -e 'devtools::test(reporter = "summary")'` passed with the
  expected optional-PDF skips and pre-existing deterministic LLM-fallback,
  semantic-gap, optional frictionless, and network-timeout warning tests.
- [x] 2026-06-25: Ran final documentation, package build/check, and pkgdown
  validation. `Rscript -e 'devtools::document()'` completed without source
  roxygen drift. `R CMD build .` completed and built
  `metasalmon_0.1.4.tar.gz`. Initial `R CMD check metasalmon_0.1.4.tar.gz
  --no-manual` failed before tests because suggested package `pdftools` is not
  installed in this environment; rerunning with `_R_CHECK_FORCE_SUGGESTS_=false`
  exposed a pre-existing `License: MIT + file LICENSE` warning because `LICENSE`
  was missing. Added the standard MIT `LICENSE` stub, rebuilt, and reran
  `_R_CHECK_FORCE_SUGGESTS_=false R CMD check metasalmon_0.1.4.tar.gz
  --no-manual`; final status was `OK`. Ran
  `Rscript -e 'pkgdown::build_site()'` and kept regenerated docs, while ignoring
  local launcher pages generated from ignored `AGENTS.md` / `CLAUDE.md`.
- [x] 2026-06-25: Updated this ExecPlan and
  `notes/bugs-and-improvements.md` after implementation so their status reflects
  what landed, what was partially addressed, and what remains open/deferred.

## Surprises & Discoveries

- `R CMD check` initially failed before package tests because the local
  environment does not have suggested package `pdftools`. Rerunning with
  `_R_CHECK_FORCE_SUGGESTS_=false` was the appropriate local validation mode for
  this workstation.
- The `_R_CHECK_FORCE_SUGGESTS_=false` check then exposed a real package metadata
  problem: `DESCRIPTION` declared `License: MIT + file LICENSE`, but the CRAN MIT
  `LICENSE` stub was missing. The branch now includes that stub.
- `pkgdown::build_site()` generated local launcher pages from ignored
  `AGENTS.md` / `CLAUDE.md`. The branch ignores the generated launcher pages and
  removes the generated `docs/CLAUDE.html`, but the source launcher self-reference
  remains an open repo-hygiene item.
- The backlog in `notes/bugs-and-improvements.md` was broader than this refactor
  plan. The implementation fixed the plan-driving LLM/semantic bugs, but left
  separate request-builder, EDH XML guard, context-source disambiguation,
  encoding, and agent-guidance items for follow-up work.

## Decision Log

- 2026-06-25: Keep explicit LLM/network opt-in. Context files and text still warn
  when ignored; they do not auto-enable LLM review.
- 2026-06-25: Preserve public return attributes on `infer_dictionary()`. R5 keeps
  the multi-table `inferred_*` and single-table `seed_*` schemes rather than
  unifying or deprecating them.
- 2026-06-25: Preserve the two LLM response shapes. R4 deepens the shared
  response-validation seam, but defers request-builder convergence because making
  response shape single-source would be a separate behavioral refactor.
- 2026-06-25: Keep `reject_shortlist` as a decision value carried by
  `llm_decision` and `llm_rationale`; do not add a new assessment column during
  this plan.
- 2026-06-25: Treat create-time EDH XML guard behavior as out of scope for this
  branch. It needs a product decision about whether first-write EDH XML is draft
  output or should block on unresolved placeholders/`REVIEW:` IRIs.
- 2026-06-25: Leave `AGENTS.md` / `CLAUDE.md` source guidance repair out of this
  branch. The branch only prevents unwanted generated pkgdown launcher pages.

## Outcomes & Retrospective

The implementation landed all five planned refactors plus the prerequisite bug
and fixture work:

1. Fixed `infer_dictionary(seed_semantics = FALSE, ...)` ignored LLM/context
   warnings.
2. Consolidated ordinary dictionary test fixtures.
3. Centralized LLM context validation, ignored-context warnings, LLM-request
   detection, effective shortlist sizing, and conditional LLM option forwarding.
4. Froze semantic target-row and LLM assessment-row contracts before moving
   producer/consumer code.
5. Extracted semantic target discovery into `.ms_semantic_discover_targets()`.
6. Deepened LLM review adapter behavior for malformed responses,
   `reject_shortlist`, batch partial fallback, duplicate batch keys, and the
   stale selected-index exploration edge case.
7. Extracted artifact-inference context into `R/artifact-inference.R` while
   preserving public `infer_dictionary()` attribute contracts.
8. Refreshed roxygen/pkgdown output and added the missing MIT `LICENSE` stub.

Implementation commits on `deepen-architecture` before this notes update:

- `6cfeb8f` Fix infer_dictionary ignored LLM options warning
- `c30d7ff` Consolidate semantic test fixtures
- `32596fb` Centralize LLM context and option policy
- `f4ea3eb` Freeze semantic review row contracts
- `ca01b19` Extract semantic target discovery
- `05d350e` Deepen LLM review adapter robustness
- `136e42d` Extract artifact inference context
- `7e28bd6` Validate refactor branch and refresh docs

Final validation evidence:

```sh
Rscript -e 'devtools::test(reporter = "summary")'
Rscript -e 'devtools::document()'
R CMD build .
_R_CHECK_FORCE_SUGGESTS_=false R CMD check metasalmon_0.1.4.tar.gz --no-manual
Rscript -e 'pkgdown::build_site()'
```

Observed final package-check status: `OK` with `_R_CHECK_FORCE_SUGGESTS_=false`.
The ordinary `R CMD check` path still requires installing suggested package
`pdftools` in this local environment.

Remaining follow-up work is tracked in `notes/bugs-and-improvements.md` with
per-item implementation statuses. The highest-leverage remaining items are the
shared chat request builder, create-time EDH XML guard decision, context-source
basename disambiguation, encoding handling for non-UTF-8 context files, real
repo-local agent guidance, and further `package-helpers.R` decomposition.

## Peer Review (2026-06-24)

This plan was peer-reviewed against the current source (a multi-agent pass that
verified every cited `file:line`, assessed each Module's depth, and hunted for
bugs). Summary of the review and the changes folded into the sections below.

**Verdicts**

| Refactor | Verdict | Headline |
|---|---|---|
| R1 Deepen LLM context handling | **Sound, with changes** | Evidence omits the deep core (`.ms_score_context_chunks`); the "characterization tests" already exist; the parse-once invariant is emergent, not enforced. |
| R2 Centralize LLM option forwarding | **Sound, but rescoped** | Validation/warning/shortlist are *already* centralized. The real duplication is `llm_requested` (2 sites) + the 11-arg assembly (3–4 sites). "Seed/no-seed warning" is not duplicated — it is a missing warning (a latent bug). |
| R3 Extract semantic target discovery | **Sound — strongest-justified** | The cited helper range (391-424) is far too narrow (real closures span 391-942); the role-collision step (1134-1180) is uncited; extraction is a closure-to-parameter conversion, not a code move. |
| R4 Clarify the LLM review adapter | **Premise inverted → DEEPEN, do not collapse** | The plan's central claim ("only one Adapter / no second Adapter yet") is **false**: `chat-decomposition.R:615` is a live second consumer of the response contract, already tested. The decision is pre-resolved. |
| R5 Canonical orchestration module | **Sound — deepest cut** | The two `infer_dictionary` paths attach *disjoint* attribute sets; the two metadata-orchestration blocks *diverge* (bare vs normalize+prefill+scope-select); `infer_dictionary` is a public export, so attribute changes are compatibility-sensitive. |

**Cross-cutting corrections**

1. **Stop saying "add characterization tests."** For R1, all four named behaviors
   already pass (test-llm-semantic-helpers.R:1-82, 1045-1136, 1138-1331); the
   artifact half of R2's and the list-input half of R5's commit-1 tests already
   exist (test-package-helpers.R:908-929; test-dictionary-helpers.R:254-314).
   Reframe these commits as **"audit and strengthen existing characterization,
   then add only the gaps."**
2. **A real correctness bug remains and belongs in this work:**
   `infer_dictionary(seed_semantics = FALSE, llm_assess = TRUE)` silently drops
   LLM options with **no warning**, unlike `infer_salmon_datapackage_artifacts`
   (package-helpers.R:462-467). Same Alice-class surprise, other public entry
   point. Fix it as part of R1/R2 (see `notes/bugs-and-improvements.md` #1).
3. **Public-export compatibility:** `infer_dictionary`, `suggest_semantics`,
   `infer_salmon_datapackage_artifacts`, and `create_sdp` are exported. Their
   return attributes and observable warnings are a compatibility surface, not
   internal-only — treat changes deliberately.
4. **Several "shallow" claims overstate the duplication.** The shared helpers
   `.ms_validate_llm_context_files`, `.ms_warn_if_llm_context_ignored`, and
   `.ms_llm_effective_shortlist_size` already exist and are reused. The remaining
   work is narrower (and easier) than the prose implies — say so.

Where this section and a refactor section disagree, this section is the later,
verified word.

## Peer Review — Round 2 (verification pass, 2026-06-24)

A second pass completed the three missing refactor critiques (R2/R3/R4) + a
meta-critique, ran two fresh correctness finders, and adversarially verified the
candidate bugs (18 confirmed, 2 reclassified as by-design, 7 new finds; full list in
`notes/bugs-and-improvements.md`). Net refinements folded into the sections below:

1. **R2 "4th copy" was wrong.** `create_sdp:831-855` is an unconditional full ~21-arg
   pass-through, not a copy of the 11-arg LLM tail. True duplication: `llm_requested`
   ×2, LLM tail ×3. And only the LLM *tail* is shareable — the *base* `suggest_args`
   list diverges per caller, so `.ms_llm_review_plan` cannot own the whole assembly.
   `include_dwc` must stay caller-set (unifying it is a behavior change).
2. **R3 "collapse the duplicate" was unsafe.** The two column-target builders are
   *divergent*, not duplicates, and the standalone one is only an empty-retrieval
   *fallback*. Reconcile deliberately. Also: the per-scope commits (3-5) **cannot**
   be independently green (shared captured closures) — they are **one atomic move**.
3. **R4 forward-compat overclaimed.** `retry_search`/`request_new_term` survive
   normalization; **`reject_shortlist` is lossy** (no metadata column) — add a
   carrier before deepening. `.ms_llm_success_assessment` is **not** pure
   pass-through (it unpacks the record), and batch normalization is **record-aware** —
   split commit 4. The shared-request-builder idea is **mutually exclusive** with the
   dual-shape normalizer; it leaves R4.
4. **Cross-refactor coupling to name explicitly:** the adapter's row builders
   (adapter:36-118) read target columns **positionally**, so R3 (which moves the
   producer of those columns) and R4 (which deepens the consumer) share a contract. A
   column rename/reorder in R3 silently breaks R4. → freeze the target-row + the full
   ~30-col **assessment-row** column contracts (incl. `llm_retry_query`,
   `llm_new_term_*`, `llm_bundle_summary`, `llm_missing_context`, `llm_exploration_*`,
   `llm_context_sources`) as a gate before R3/R4. The retrieval-gap roadmap's
   post-validators read those bundle slots, so freezing only `llm_context_sources` is
   insufficient.
5. **Make the `infer_dictionary` silent-drop fix a standalone commit BEFORE R1/R2**,
   with its own NEWS entry + regression test — it is a real user-facing correctness
   bug independent of the architecture work, and bundling it risks it slipping if
   R1/R2 stall.
6. **Adopt the test-fixture consolidation (Missing/Future #3) as a prerequisite
   before R3/R5**, not a future candidate — both change row/column shape and would
   otherwise force edits across ~30 inline dict fixtures (and risk drift between the
   very characterization tests used as gates).
7. **Ordering:** R4-before-R3 is only weakly motivated (decomposition already routes
   through the shared validator; no growth in *this* plan unblocks it). Keep R4 early
   only if the target-row contract is frozen as an explicit R4 precondition;
   otherwise prefer R1, R2, **R3, R4**, R5 so the adapter is deepened against a stable
   row contract. Either way, name the adapter↔target-row coupling.
8. **R5 land the orchestration in a NEW file** (e.g. `R/artifact-inference.R`) rather
   than deepening inside the 2975-line `package-helpers.R` god-file — converts a
   deferred Locality win into a free one. Resolve the commit-4/commit-5 tension
   (keep `inferred_*` attached vs remove orchestration) by **deciding**: either keep
   the attributes via the shared Module, or deprecate the dictionary-side attributes
   with a note — not a shim that re-derives them (which re-introduces the duplication
   R5 removes).

## Global Constraints

- Preserve public function signatures unless a separate compatibility plan is
  approved.
- Preserve explicit network/LLM opt-in. Supplying context files or text must not
  silently enable LLM review.
- **Preserve public return-value attributes and observable warnings.**
  `infer_dictionary` is exported and attaches `inferred_*` (multi-table) /
  `seed_*` (single-table) attributes; `suggest_semantics` attaches
  `semantic_suggestions` / `semantic_llm_assessments`. These are read by other
  modules and ~20 tests — treat as contract.
- **Preserve these observable contracts specifically:** the `llm_context_sources`
  output column (derived from context source basenames), the `REVIEW:` IRI prefix
  marker, and the test injection hooks (`search_fn`, `llm_request_fn`,
  internal `request_fn`).
- **Frozen column contracts (R3/R4 are most exposed):** (a) the 19-col semantic
  target row (`.ms_semantic_target_cols`); (b) the full ~30-col **assessment row**
  emitted by the adapter (R/llm-review-adapter.R:36-118) — including
  `llm_retry_query`, `llm_new_term_label/definition/namespace`, `llm_bundle_summary`,
  `llm_missing_context`, `llm_exploration_*`, `llm_context_sources`. These are
  cross-module shapes consumed by the merge logic and (per the retrieval-gap roadmap)
  by future bundle-fit post-validators. Snapshot both column sets as a gate before
  R3/R4; the adapter's row builders read target columns **positionally**, so a
  rename/reorder in R3 silently breaks R4.
- `infer_dictionary`'s two paths attach **disjoint** attribute sets — multi-table
  `inferred_*` (unconditional) and single-table `seed_*` (only when args non-NULL).
  The contract is the disjointness, not a uniform bucket; R5 must preserve both or
  make their change a deliberate, documented deprecation.
- Keep R code in the existing tidyverse style and use the native pipe where it
  improves readability.
- Keep each commit small enough that `devtools::test()` can pass after the
  commit.
- Prefer testing through public or stable internal Interfaces. Avoid tests that
  assert temporary local variables inside implementations. **Exception already in
  the tree:** the parse-once test mocks two internal helpers by name
  (test-llm-semantic-helpers.R:1100-1136) — see R1.
- Regenerate roxygen and pkgdown only when public documentation changes.
- These are functional-R Modules (clusters of `.ms_`-prefixed helpers in a file),
  not OO classes. The Ousterhout lens (deep Module, narrow Interface, Seam,
  Deletion Test, Locality, Leverage) maps cleanly onto that — keep using it, but
  do not import class/inheritance shapes that R does not want.

## Coordination with related roadmaps

Two existing planning artifacts constrain these refactors and must be read before
touching the LLM review path:

- `notes/exec-plans/2026-04-02-i-adopt-chat-decomposition-draft.md` — routes
  measurement / compound-variable targets through `chat_decomposition()` and
  **explicitly forbids "inventing a second bundle-review prompt stack elsewhere."**
  This pre-decides R4: there is already a second review mode (the chat
  decomposition consumer at `chat-decomposition.R:615`), so the shared response
  contract should be **deepened**, and the decomposition route should reuse it.
- `notes/exec-plans/2026-04-02-llm-semantic-fit-retrieval-gap-escalation.md` —
  introduces richer review outcomes (`retry_search`, `request_new_term`,
  `reject_shortlist`) and bundle-aware review. The validator already accepts these
  decisions (`.ms_validate_llm_assessment`). **Design constraint:** R2's option
  Module, R3's target rows, and R4's response contract should each be shaped so
  these richer outcomes can land later without another rewrite.

## Refactor 1: Deepen LLM Context Handling

### Files and Evidence

- `R/llm-semantic-helpers.R`
  - `.ms_validate_llm_context_files()` validates file-path shape at lines
    441-459. *(verified exact)*
  - `.ms_warn_if_llm_context_ignored()` owns ignored-context warnings at lines
    461-481. *(verified; two independent branches: files 467-472, text 473-478)*
  - `.ms_context_text_from_file()` parses individual context files at lines
    483-533. *(verified; the deep dispatch point — 8 formats, optional-dep aborts,
    source labeling, empty/unsupported handling)*
  - **`.ms_score_context_chunks()` is the deep ranking core at lines 566-595, with
    `.ms_context_tokens()` at 556-564.** *(ADDED in review — the plan's original
    evidence omitted the most behavior-dense functions.)*
  - `.ms_collect_context_chunks()` collects context text and chunks it at lines
    597-621. *(verified; also re-validates at 599 and appends `inline_context` at
    605-611)*
  - `.ms_prepare_context_chunks()` is a **thin pool-aware wrapper** at lines
    623-640 that *delegates* selection/scoring to `.ms_score_context_chunks`.
    *(corrected — the plan called this the selector; it is not)*
  - **Pool collection + threading: `.ms_collect_context_chunks` is invoked once at
    line 1612 and threaded as `context_chunk_pool` through `.ms_llm_prepare_record`
    (1635) and `.ms_llm_explore_record` (1662).** *(ADDED — this is where the
    "parsed once" guarantee actually lives.)*
- `R/semantics-helpers.R`
  - `suggest_semantics()` validates and warns directly at lines 332-337. *(verified)*
  - LLM review receives context arguments at lines 1182-1198 (forwarded at
    1191-1192). *(verified)*
- `R/package-helpers.R`
  - `infer_salmon_datapackage_artifacts()` validates context paths at line 460 and
    separately warns about `seed_semantics = FALSE` at lines 462-467. *(verified —
    note it does NOT call `.ms_warn_if_llm_context_ignored`; it has its own,
    different seed-off warning)*
- `R/dictionary-helpers.R`
  - `infer_dictionary()` computes LLM request state and validates context paths at
    lines 92-100. *(verified — and, unlike package-helpers, emits NO ignored-context
    warning: a latent silent-drop bug, see Risks)*

### Problem

The current LLM context Module is partly deep and partly shallow — and the review
confirms exactly which parts.

- **Deep already:** parsing (`.ms_context_text_from_file`), chunking, and
  scoring (`.ms_score_context_chunks`) are genuinely deep and already unit-tested
  in isolation without network or LLM (test-llm-semantic-helpers.R:1138-1331).
- **Shallow:** the **policy surface** — validate + ignored-context warning — is
  not owned by one Module. It diverges across callers: `suggest_semantics` calls
  validate + warn (332-337); `infer_dictionary` calls validate only (100);
  `infer_salmon_datapackage_artifacts` calls validate (460) plus a *different*
  seed-off warning (462-467). That fragmentation is the legitimate target.

Alice's report exposed this split. The bug fix added guardrails on the
`create_sdp` path but the policy still lives in multiple Modules — and one of them
(`infer_dictionary`) still has no ignored-context warning at all.

### Deletion Test

Deleting `.ms_validate_llm_context_files()` would not delete complexity; it would
move context validation back into `suggest_semantics()`, `infer_dictionary()`, and
`infer_salmon_datapackage_artifacts()` (all three call it identically — verified).
The Module earns its keep. But the surrounding warning policy is *not* centralized,
so callers still make policy decisions — the Module is not deep enough yet.

### Solution

Deepen LLM context handling as one internal Module that owns:

- accepted input shapes,
- ignored-context warning policy **parameterized by reason** — "ignored unless
  `llm_assess = TRUE`" (suggest_semantics) vs "ignored because
  `seed_semantics = FALSE`" (package/dictionary) are two legitimately different
  messages and must remain distinguishable, not collapsed into one rule,
- optional dependency failures for PDF and Excel (keep the loud abort; do not hide
  behind a generic context result),
- parsing and normalization,
- chunk pooling **with an enforced parse-once invariant** (today it is emergent —
  see Risks),
- target-specific chunk scoring,
- source accounting for LLM assessment rows (the `llm_context_sources` column).

The public entry points should continue to expose simple `llm_context_files` and
`llm_context_text` arguments and should not need to know how context is parsed.

### Tiny Commits

1. **Audit and strengthen existing characterization** (do NOT "add" from scratch —
   these already pass): parsed-object error (test-llm-semantic-helpers.R:1-36),
   context-with-`llm_assess = FALSE` warns and no LLM (38-82), parse-once (1045-1136),
   empty/unsupported formats (1138-1331). Add only the genuine gaps:
   - a test pinning "collected once but **scored once per target**" (only
     parse-once is asserted today),
   - a test for `infer_dictionary`'s `seed_semantics = FALSE` + LLM-options
     behavior (currently uncharacterized),
   - one sentinel where both `llm_context_files` **and** `llm_context_text` are
     supplied with `llm_assess = FALSE` and an erroring `llm_request_fn` (the only
     genuinely net-new combination).
2. Move context validation and ignored-context warning policy behind one internal
   context Module while keeping current helper names as temporary wrappers.
3. Move context collection, chunking, scoring, and source reporting behind the
   same Module. **Make the single collect entry point own the parse-once
   invariant** (return a pool; per-target scoring requires it — no NULL-pool
   re-collect fallback).
4. Replace direct caller use of validation/warning/chunk helpers with the deeper
   Module.
5. **Before deleting wrappers:** rewrite the parse-once test (1100-1136) to assert
   through the new Module seam (count collect calls) instead of mocking
   `.ms_context_text_from_file` / `.ms_chunk_context_text` by name. Otherwise
   commit 6 reds this test.
6. Delete compatibility wrappers only after all callers and tests cross the new
   Seam.

### Benefits

- Better Locality: context behavior changes in one place instead of across
  semantic, package, and dictionary callers.
- More Leverage **for the policy/warning layer specifically** — the parse/score
  layer is *already* independently testable (test-llm-semantic-helpers.R:1138-1331),
  so do not over-claim Leverage there.
- Lower risk of another Alice-style surprise — and a concrete one fixed now:
  `infer_dictionary`'s missing ignored-context warning.

### Testing Decisions

- Extend `tests/testthat/test-llm-semantic-helpers.R` for direct context Module
  behavior, including the "scored per target, collected once" distinction.
- Keep `tests/testthat/test-package-helpers.R` tests covering the public
  `create_sdp()` path.
- Add the `infer_dictionary(seed_semantics = FALSE, llm_assess = TRUE)` behavior
  test as the regression for the silent-drop fix.

### Risks

- PDF and Excel context parsing depend on optional packages. Keep the loud abort
  (`.ms_context_text_from_file:501-508`); do not hide behind a generic result.
- Context source labels feed the `llm_context_sources` output column
  (llm-review-adapter.R:112) and are asserted by tests (166, 1491-1494, 1657).
  Preserve source reporting exactly. (Note the same-basename collision smell —
  `notes/bugs-and-improvements.md` #2 — which any source-label change should fix.)
- **The "parsed once" guarantee is currently emergent** (orchestrator threads
  `context_chunk_pool` from 1612), NOT enforced by the Module:
  `.ms_prepare_context_chunks` silently re-collects if passed a NULL pool. Deepen
  to own this, or the Locality win is illusory.
- **Renaming/absorbing `.ms_context_text_from_file` or `.ms_chunk_context_text`
  breaks the by-name mock at test-llm-semantic-helpers.R:1100-1136** — handle in
  commit 5 before deleting wrappers.
- **Unifying the ignored-context warning changes `infer_dictionary`'s observable
  behavior** (it has none today). Make that a deliberate, tested decision, not a
  side effect.

## Refactor 2: Centralize LLM Option Forwarding

### Files and Evidence

- `R/dictionary-helpers.R`
  - `infer_dictionary()` computes `llm_requested` at lines 92-99. *(verified;
    byte-identical to package-helpers.R:452-459)*
  - Multi-table semantic seeding assembles LLM arguments at lines 171-195. *(verified)*
  - Single-table semantic seeding repeats the same assembly at lines 247-271.
    *(verified; the 11-arg block at 256-269 is byte-for-byte identical to 180-193)*
- `R/package-helpers.R`
  - `infer_salmon_datapackage_artifacts()` repeats `llm_requested` at lines
    452-459. *(verified)*
  - It repeats LLM argument assembly at lines 541-566. *(verified; base list
    includes `include_dwc = FALSE` at 546, which the dictionary blocks omit)*
  - `create_sdp()` forwards options to `infer_salmon_datapackage_artifacts()` at
    lines 831-855. *(verified — CORRECTION from round 2: this is **not** a 4th copy
    of the 11-arg tail; it is an unconditional one-to-one pass-through of the ENTIRE
    ~21-arg artifact surface (resources, dataset_id, guess_types, seed_*,
    semantic_code_scope, + the 11 llm_* args). It is a separate maintenance hazard,
    out of R2's scope — do not fold it into the LLM-option helper.)*
- `R/llm-semantic-helpers.R`
  - **`.ms_llm_effective_shortlist_size()` already exists at lines 79-93 and is
    merely *called* twice** (package-helpers.R:468-472, dictionary-helpers.R:102-106).
    *(ADDED — the "effective shortlist" concept is already a deep helper; only its
    invocation repeats.)*

### Problem (rescoped)

The plan framed the whole LLM-option path as "shallow" with each caller
reimplementing validation/warning/shortlist. **That overstates it.** Verified:

- Validation (`.ms_validate_llm_context_files`), ignored-context warning
  (`.ms_warn_if_llm_context_ignored`), and effective shortlist
  (`.ms_llm_effective_shortlist_size`) are **already shared helpers.**
- What is **genuinely duplicated** is only: (a) the `llm_requested` 8-clause
  predicate (2 sites) and (b) the conditional 11-arg `llm_*` *tail* appended to
  `suggest_args` (3 sites: dictionary-helpers.R:180-193, :256-269,
  package-helpers.R:551-564). `create_sdp:831-855` is a full pass-through, not a 4th
  copy of this tail.

So this is a real DRY / coordination fix with **modest** depth — a small
constructor returning derived flags + the assembled LLM tail — not a deep Module
hiding substantial implementation. Frame it honestly so it does not become a thin
pass-through that just relocates an argument list. **Crucial scoping fact (round 2):**
only the conditional LLM *tail* is shareable. The *base* `suggest_args` list
diverges per caller — `df = resources` vs `df`; `codes = semantic_codes` vs
`seed_codes` vs `codes`; `include_dwc = FALSE` present only on the package path — so
the helper cannot own the whole assembly. That base-list divergence is precisely why
this is shallow DRY rather than a deep Module.

Also: "seed/no-seed warning policy" is listed as something to centralize *because
it is duplicated*. It is **not duplicated** — it exists only in
`infer_salmon_datapackage_artifacts` (462-467). `infer_dictionary` lacks it
entirely, which is the silent-drop bug. So fold the **fix** (add the warning to
`infer_dictionary` via the shared module), not a "de-dup".

### Deletion Test

Deleting the repeated `llm_requested` blocks would force every caller to
rediscover which LLM options count as "requested" (the predicate encodes
non-obvious policy: `request_fn`/`base_url` count). That signals a small but real
coordination Module.

### Solution

Create one internal semantic-review option helper (e.g. `.ms_llm_review_plan(...)`)
that owns:

- whether LLM-related options were supplied (`llm_requested`),
- the seed/no-seed ignored-options **warning** (so both `infer_dictionary` and
  `infer_salmon_datapackage_artifacts` warn identically — fixes the asymmetry),
- delegation to the context Module for validation/ignored-context policy,
- effective shortlist size (by **calling** the existing
  `.ms_llm_effective_shortlist_size`, not reimplementing it),
- conversion of the public LLM arguments into the conditional 11-arg `llm_*` tail
  appended to `suggest_args` when `llm_requested` — the single source of that tail
  (NOT the whole arg list; the base list stays caller-owned, see Problem).

Design the tail so future LLM knobs (provider/model resolution, retry, the richer
review outcomes from the retrieval-gap roadmap) are added in one place.
**Invariant:** the helper must only report / validate / assemble — it must never
flip `seed_semantics` or `llm_assess` defaults (centralization is exactly where an
accidental auto-enable could slip in, violating the opt-in constraint).

### Tiny Commits

1. **Audit/strengthen, then fill the gap:** the artifact-path test already exists
   (test-package-helpers.R:908-929 asserts the `seed_semantics = FALSE` warning +
   NULL outputs). The `infer_dictionary` half is net-new — add it (and it doubles
   as the regression for the silent-drop fix).
2. Add the `llm_requested` helper and replace the two duplicated blocks.
3. Move the seed/no-seed warning into the helper and **add it to `infer_dictionary`**
   (behavior change — deliberate, tested). Emit it **once at the top** of
   `infer_dictionary` (before the list/data.frame branch and the multi-table
   recursion at 128-141) so a multi-table input warns once, not per table. Pre-flight:
   grep the suite for `infer_dictionary(... llm_*)` calls lacking `expect_warning`
   and wrap them first.
4. Move the conditional 11-arg LLM *tail* into the helper, preserving public
   signatures and `llm_request_fn` forwarding. Do **not** try to centralize the base
   `suggest_args` list (it diverges per caller). Leave `include_dwc` **caller-set**:
   unifying it is an observable behavior change, not free cleanup (verify
   `suggest_semantics`'s `include_dwc` default and add a dictionary-path output
   characterization test before touching it, or skip it).
5. Remove the three duplicate LLM-tail blocks and the two `llm_requested` predicates
   once tests pass through all public entry points. (There is no `create_sdp`
   call-site copy to remove — it is a full pass-through.)

*(Dropped the original commit 3 "move effective shortlist calculation into the
option Module" as redundant — the calculation is already extracted; only its call
sites move, which commit 4 handles.)*

### Benefits

- Better Locality for new LLM knobs (provider options, context behavior, timeout,
  retry, richer review outcomes).
- Consistent behavior: `infer_dictionary` and `infer_salmon_datapackage_artifacts`
  warn identically on ignored options — closes the silent-drop gap.
- One place to evolve the option contract toward the bundle-aware roadmap.

### Testing Decisions

- Add tests at the public entry points because option forwarding is part of their
  Interface.
- Keep request-function sentinels for hidden LLM calls.
- Use mocked search functions (`with_mocked_bindings(find_terms = ...)` on the
  `create_sdp`/`infer_dictionary` paths); do not rely on live vocabulary services.

### Risks

- Public function signatures are long but user-facing. Do not hide or replace them
  without a separate compatibility decision.
- `llm_request_fn` is an advanced test hook threaded through 6+ tests. Preserve it
  or the deterministic suite breaks.
- Adding the warning to `infer_dictionary` changes observable behavior — land it
  with its own test and a NEWS note.
- **Seam overlap with R5:** R5's "shared semantic seeding Module" would otherwise
  touch this same arg-assembly. Do R2 first; R5 then relocates only metadata
  orchestration, not the LLM arg block.

## Refactor 3: Extract Semantic Target Discovery

### Files and Evidence

- `R/semantics-helpers.R`
  - `suggest_semantics()` owns input normalization at lines 342-368. *(verified)*
  - It defines local query/placeholder helpers — **but the behavior-dense closures
    span 391-942, not just 391-424.** Lines 391-424 are only trivial string
    utilities (`is_missing`, `clean_query`, `is_review_placeholder`, …); the real
    heuristics are `measurement_role_query` (603-680), `non_measurement_query`
    (765-812), `non_measurement_roles` (925-942), `paired_unit_query_from_data`
    (523-554), etc. *(corrected — citing 391-424 badly undersells the extraction
    surface)*
  - Column target discovery at lines 943-988. *(verified)*
  - Code target discovery at lines 990-1033. *(verified)*
  - Table target discovery at lines 1035-1072. *(verified)*
  - Dataset target discovery at lines 1074-1109 (normalize at 1109). *(verified)*
  - Retrieval at lines 1111-1132. *(verified — single `search_fn` call)*
  - **Role-collision annotation at lines 1134-1180** (variable-vs-property
    `group_by`/`left_join` adding `role_collision`/`role_collision_note`). *(ADDED —
    this enrichment sits between retrieval and LLM and the plan omitted it)*
  - LLM handoff and attribute attachment at lines 1182-1205. *(verified)*
- `R/semantic-suggestions.R`
  - Owns target/suggestion row-shape helpers at lines 1-122. *(verified)*
  - Owns LLM-assessment merge behavior at lines 243-268. *(verified — note this
    merge is algorithmically non-trivial; it would not "just inline")*
  - **Already contains a divergent target-discovery builder
    `.ms_semantic_column_term_target_from_dictionary` at lines 147-185** that
    duplicates the inline column-target block (semantics-helpers.R:966-984). *(ADDED
    — this is the strongest concrete evidence for the refactor and was uncited)*

### Problem

`suggest_semantics()` is a large Module with a broad Interface. It owns target
discovery, query heuristics, deterministic retrieval, LLM review, result
attachment, and user messages. Verified cost: `test-semantic-suggestions.R` makes
**zero** `suggest_semantics()` calls (it tests only row-shape helpers), and every
`suggest_semantics()` test in `test-llm-semantic-helpers.R` must define a
`fake_search` closure even when testing unrelated behavior — exactly the "tests
are expensive" symptom. Verified: target discovery never calls `search_fn` or any
LLM, so it *could* be tested in isolation — but it is locked inside
function-local closures with no callable entry point.

### Deletion Test

Deleting `semantic-suggestions.R` today would mostly inline column lists and
normalizers (verified — those constants live there) plus the non-trivial merge
helper. The behavior-dense target-discovery complexity would remain inside
`suggest_semantics()`. The Module owns the *shape* of target rows but not the
*rules* for producing them (except the one divergent dictionary builder). It is
not deep enough for the semantic-target concept.

### Solution

Deepen semantic target discovery as its own Module before retrieval or LLM review.
It should own the rules for turning dictionaries, tables, codes, dataset metadata,
and resource context into normalized semantic target rows — **and emit them
against the `.ms_semantic_target_cols()` contract** rather than hand-written
literal tibbles, removing the inconsistent per-builder column sets. Retrieval and
LLM review then consume target rows without knowing how they were chosen.

**The hidden cost the plan must name:** this is a **closure-to-parameter
conversion**, not a code move. The discovery closures capture `resource_lookup` /
`default_df` (set 339-358), the role map (381-388), and the in-scope
`dict`/`codes`. Extracting them means threading these as explicit arguments —
especially the raw `df` needed by `paired_unit_query_from_data`.

### Tiny Commits

1. **Audit/strengthen + golden fixture:** ~15 tests (test-dictionary-helpers.R:434-1210)
   already characterize discovery *rules* (queries/roles per scope) through
   `suggest_semantics()` + recorded `fake_search` calls — the net-new value is
   *leverage* (isolated tests with no `fake_search`), not first-time coverage. Add a
   **golden-fixture snapshot of the full normalized target tibble** across all four
   scopes (all 19 `.ms_semantic_target_cols`, including the 3-row code expansion and
   the table-only `target_query_basis/context`) so the extraction is verified
   value-for-value, not just rule-by-rule.
2. Confirm target-row column definitions and normalizers are in the target Module
   (already true at semantic-suggestions.R:1-104 — this commit is a **no-op**; only
   the four builders and the closure cluster actually move).
3. **(Atomic move — round 2 correction.)** Move the entire discovery closure cluster
   (391-942) **and** the four builders (943-1106) into the target Module in **one**
   commit, threading the captured state as explicit args: `dict` (whole, for the
   code-target parent lookup at 1003-1006), `codes`, `table_meta`, `dataset_meta`,
   per-table `df` access (`resource_lookup`/`default_df`, for `current_table_df` /
   `paired_unit_query_from_data` — mishandling this regresses the NEWS 0.1.1
   multi-table context fix), and the `roles` map. Per-scope splitting **cannot** stay
   green: the builders share captured helper closures, so moving one scope at a time
   breaks `load_all`. Preserve: the length-3 `role_set` recycling that yields **3
   rows per measurement-parented code** (1008/1017-1018), and the empty-tibble-skip →
   `bind_rows` → NA-backfill contract.
4. **Reconcile (do NOT blindly collapse) the divergent column-target builders.** The
   inline block (966-984) expands all six I-ADOPT roles and sets
   `target_sdp_field = col_name`; `.ms_semantic_column_term_target_from_dictionary`
   (semantic-suggestions.R:147-185) hardcodes a single `variable`/`term_iri` row and
   computes `target_query_basis/context` the inline block leaves NA — and it is
   currently only a **fallback** inside `.ms_semantic_target_from_candidate_rows`
   (197-201) when retrieval is empty. Document the divergence, decide deliberately
   whether to unify or keep both, and preserve the fallback role.
5. Make `suggest_semantics()` call target discovery → retrieval →
   **role-collision annotation (1134-1180)** → LLM review in clearly separated
   steps. Do not drop the `role_collision`/`role_collision_note` columns (add a
   characterization test that they survive the split).
6. Delete now-dead local helper definitions from `suggest_semantics()`.

### Benefits

- Better Locality for semantic target rules; one place that owns the row contract.
- More Leverage: target discovery verified without fake search, fake LLM, or
  output attributes.
- A clearer Seam between target discovery and candidate retrieval; reconciles the
  two divergent column-target builders into one place (rather than leaving an inline
  six-role builder and a single-role fallback that can drift).

### Testing Decisions

- Add direct internal tests for target-discovery row output (column/code/table/
  dataset scopes).
- Keep existing end-to-end `suggest_semantics()` tests as regression coverage.
- Strengthen `test-semantic-suggestions.R` (only 2 tests today) before moving
  behavior into that file.

### Risks

- Target discovery is behaviorally dense. Preserve exact row columns and values
  (incl. the `target_query_basis`/`target_query_context` columns that only table
  targets currently populate; the rest are NA-backfilled by
  `.ms_semantic_normalize_target_rows`).
- LLM review and deterministic retrieval depend on stable target keys
  (`target_row_key`, group keys). Changes are compatibility-sensitive — they also
  feed `chat-decomposition.R`, `llm-review-adapter.R`, and `llm-semantic-helpers.R`.
- **Cross-refactor coupling with R4:** the adapter's empty/success row builders
  (R/llm-review-adapter.R:36-118) read target columns **positionally**. R3 moves the
  producer of those columns; R4 deepens the consumer. A column rename/reorder here
  silently breaks R4 — freeze the target-row column contract (Global Constraints) and
  do R3 before R4 (or freeze as an R4 precondition).
- Code-target discovery recycles a length-3 `role_set` vector into **3 rows per
  measurement-parented code** (1008/1017-1018), and its parent lookup (1003-1006)
  reads *other* dict rows — so the extracted module must receive the whole `dict`,
  not just the code row, and a naive single-row refactor would silently emit 1 row
  instead of 3. Add a regression test asserting the 3-row expansion.
- Heavy positional `[[1]]` row access throughout the closures (425-942) raises the
  cost of "preserve exact values"; keep the single-row contract during extraction.

## Refactor 4: Deepen the LLM Review Adapter (decision pre-resolved)

> **The plan's original premise here was factually wrong and inverted the
> conclusion.** It claimed "one real Adapter path… one Adapter means a hypothetical
> Seam" and proposed deciding collapse-vs-deepen. Verified against source: there
> are **two live consumers** of the response contract already, the second is
> tested, and the i-adopt roadmap mandates reusing one shared route. **Decision:
> deepen. Do not collapse.** This section is rewritten accordingly.

### Files and Evidence

- `R/llm-review-adapter.R`
  - Response parsing + assessment validation at lines 1-34 (response_data 1-20,
    validate 22-27, request 29-34). *(verified)*
  - Empty and successful assessment row construction at lines 36-118 (empty 36-73,
    success 75-118). *(verified)*
  - **The two-shape normalizer (lines 3-17) exists by design:** it reparses
    `content` when `data` is NULL. *(this is the tell that there are two consumers)*
- `R/llm-semantic-helpers.R`
  - Single-record review uses the adapter at lines 1454-1471. *(verified)*
  - Batch review and fallback at lines 1473-1533 (two fallback layers). *(verified)*
  - Provider-wide failure handling at lines 1539-1578. *(verified)*
  - Overall LLM assessment orchestration at lines 1580-1692. *(verified)*
  - Default request fn `.ms_llm_chat_json_request` returns a **bare** parsed-JSON
    list (1301-1330).
- **`R/chat-decomposition.R` — the SECOND consumer.** `.ms_chat` /
  `.ms_chat_http_request` (435-536) return a **wrapped** `list(content, data, …)`,
  and `chat-decomposition.R:615` calls the shared validator. *(verified — this is
  the second Adapter the plan said "does not exist yet")*
- **`tests/testthat/test-semantic-suggestions.R:36-51`** already tests the
  validator with the chat-style `{content, data}` shape. *(verified — the
  second-consumer contract is under test)*

### Problem

The plan called `llm-review-adapter.R` a "suspicious shallow Module" with a
hypothetical single Seam. The code says otherwise: a **narrow Interface**
(validate / request / empty / success) hides (a) two-shape response normalization
and (b) the dense decision-validation/downgrade policy in
`.ms_validate_llm_assessment`. **Two real consumers share the contract.** The
genuine reader complaint — "maintainers bounce between files" — is caused by the
thin pass-through wrappers (`.ms_llm_success_assessment` /
`.ms_empty_llm_assessment`, helper:1411-1423), not by the Seam itself.

The complete set of review paths (the plan enumerated none): (1) generic
single-target, (2) decomposition single-target (routed by
`.ms_llm_should_route_to_decomposition`), (3) batch (two-layer fallback), (4)
query-exploration re-review, (5) interactive chat decomposition. Paths 1-4 use the
bare-JSON branch; path 5 uses the wrapped branch.

### Deletion Test

Deleting `llm-review-adapter.R` would force duplicating validate+downgrade and the
dual-shape normalizer into **both** `llm-semantic-helpers.R` and
`chat-decomposition.R`, splitting one contract across two files. It deletes no
complexity; it scatters it. **The Module passes the deletion test — it is a real,
deep Seam.**

### Solution

**Deepen** the adapter so it owns the full LLM-review response contract: request/
response normalization (both shapes), decision validation + auto-downgrades, empty
assessment rows, success assessment rows, and batch result normalization. Make
both LLM orchestration and chat decomposition call the adapter at one Seam.

Concretely:

- Move/inline the file-hop wrappers (helper:1411-1423). **Round-2 nuance:**
  `.ms_empty_llm_assessment` is a pure pass-through, but `.ms_llm_success_assessment`
  (1415-1423) **unpacks the record struct** (`record$group[1,]`, `candidate_rows`,
  `context_chunks`). Inlining it must either move that record-unpacking into the
  adapter (the adapter then learns the record shape) **or** keep the adapter's
  positional `target_row/candidate_rows/context_chunks` signature with unpacking left
  in the helper. Pick one and document it.
- **Forward-compat (retrieval-gap roadmap) — corrected:** `retry_search`
  (`llm_retry_query`, consumed at helper:1089) and `request_new_term`
  (`llm_new_term_*`, adapter:109-111) **already survive** normalization. But
  **`reject_shortlist` is LOSSY today**: the validator returns it as a decision
  (helper:1397-1408) with **no** reject-specific column in either row builder
  (adapter:36-118). Before/while deepening, add a reject-reason carrier column
  (e.g. `llm_reject_reason`, or reuse `llm_rationale` + a flag) to **both** builders,
  or the lossiness is baked into the canonical Seam.
- **Row-shape symmetry invariant:** the empty (adapter:36-73) and success (75-118)
  rows must declare **identical** column sets, or `dplyr::bind_rows` across mixed
  rows (helper:1499) silently fills NA / coerces types. Any new contract field goes
  into **both** builders in the **same** commit.
- The **shared chat request builder** (converging `.ms_llm_chat_json_request`
  1301-1330 and `.ms_chat_http_request` chat:435-472) is **mutually exclusive** with
  keeping the dual-shape normalizer (single-shape responses would delete the
  adapter:3-17 branch this section defends). It is therefore **out of R4** — track it
  as a separate later refactor (`notes/bugs-and-improvements.md` #3, plan
  Missing/Future #2). Do not attempt both.

### Tiny Commits

1. **Extend** existing characterization (the wrapped `{content, data}` shape is
   already tested at test-semantic-suggestions.R:36-51) with malformed/truncated
   fixtures for **both** shapes, the truncation-as-null-abort case (adapter:8-16),
   and a **`reject_shortlist` round-trip** fixture that pins whatever metadata the
   retrieval-gap roadmap needs — turning today's lossiness into a tracked decision.
2. Inventory call sites (done — second consumer is `chat-decomposition.R:615`).
3. **(Cheap, safe — land first.)** Move/inline the wrappers (helper:1411-1423),
   choosing one record-unpacking convention (see Solution). Pure Locality, zero
   behavior change.
4. **(Deeper — separate validation.)** Split: **4a** move the response→rows mapping
   into the adapter; **4b** keep record-keying-by-`group_name` (helper:1479) in the
   orchestrator. `.ms_llm_validate_batch_assessments` (helper:1473-1500) is
   **record-aware**, not pure response-contract — do not drag record-shape knowledge
   behind the Seam.
5. Ensure the wrapped-shape (chat) and bare-shape (semantic) paths both route through
   the same validator and row builders; keep the chat path's own `null_message` and
   `.ms_chat_named_candidate_rows` coercion (it differs from `.ms_semantic_candidate_rows`).
   Keep the test-semantic-suggestions.R:36-51 contract.
6. Run the full LLM-helper + chat-decomposition + semantic-suggestions tests after
   each movement, asserting both shapes route through one validator **in the same
   test run** (not separate files that can drift).

### Benefits

- Better Locality for the LLM response contract — one place for both consumers.
- Less file-hopping for maintainers reading one review flow.
- A real Seam that already pays for itself, ready to absorb the richer review
  outcomes from the retrieval-gap roadmap.

### Testing Decisions

- **Correction:** the existing R4-relevant tests are predominantly **white-box** on
  internals (`.ms_validate_llm_assessment` 576-683, `.ms_llm_clean_json_text`
  685-699, `.ms_llm_validate_batch_assessments` 701-748,
  `.ms_llm_review_validate_assessment` test-semantic-suggestions.R:36-51). The
  original "test through behavior, not raw JSON helper internals" stance would
  require **rewriting**, not just adding, tests. Keep the white-box validator tests
  (they pin the contract) and add behavior-level tests around them.
- Use fake request functions and malformed-response fixtures for both shapes.
- Keep provider/network tests out of scope.

### Risks

- None of the original "collapse may be premature" risk applies — collapse is off
  the table.
- Deepening must preserve the two-shape normalizer (both consumers depend on it).
- **Row-shape symmetry:** empty and success rows must keep identical column sets or
  `bind_rows` (helper:1499) coerces silently — new fields go in both builders, same
  commit.
- **Chat-path divergence:** chat supplies its own `null_message` and
  `.ms_chat_named_candidate_rows` candidate coercion (chat:615-619). Preserve
  per-caller; "route both through one validator" must not assume one candidate-row
  coercion.
- **`with_mocked_bindings` binds dotted symbols by exact name** (e.g.
  `.ms_validate_llm_assessment`, `.ms_llm_clean_json_text`). Inlining must preserve
  those names or the tests silently no-op.
- Keep the second-consumer test (test-semantic-suggestions.R:36-51) green throughout.

> Evidence of depth to cite: the validator's downgrade ladder (helper:1362-1395 —
> accept-without-index / out-of-range-index / retry_search-without-query all
> downgrade to `review`) is the dense decision policy the adapter hides; it is the
> strongest concrete proof the Seam is deep.

## Refactor 5: Make Package Artifact Inference the Canonical Orchestration Module

### Files and Evidence

- `R/dictionary-helpers.R`
  - `infer_dictionary()` handles multi-table resources at lines 108-143
    (recurse with `seed_semantics = FALSE` + `bind_rows`). *(verified)*
  - It infers table metadata, codes, and dataset metadata at lines 145-165.
    *(verified — the three `infer_*_from_resources` functions are DEFINED in this
    file at 442-629 yet also called directly by `infer_salmon_datapackage_artifacts`
    — misplaced ownership)*
  - It seeds semantics and attaches **`inferred_*` attributes (multi-table)** at
    lines 167-200 (attrs at 196-199). *(verified)*
  - The single-table path seeds semantics at 243-281 and attaches a **different,
    disjoint `seed_*` attribute set** (272-280, only when args non-NULL). *(ADDED —
    the plan treated attributes as one bucket)*
- `R/package-helpers.R`
  - `infer_salmon_datapackage_artifacts()` orchestrates resources, dictionary,
    tables, codes, dataset metadata, semantic seeding, and the returned artifacts
    at lines 427-586. *(verified)*
  - Its metadata orchestration (508-532) is **richer** than the dictionary path:
    it normalizes (`.ms_normalize_table_meta`/`_codes`/`_dataset_meta`), prefills
    legacy estimate-method code terms (519), and selects semantic seed codes by
    scope (527-532). *(ADDED — the two blocks are NOT identical)*
  - `create_sdp()` **inference call** is at 831-855; **writing** starts at
    `write_salmon_datapackage` (909); post-processing (review README,
    `semantic_suggestions.csv`, optional EDH XML, info lines) runs through ~982.
    *(corrected — the plan said "writes and post-processes at 831-950")*

### Problem

`infer_dictionary()` and `infer_salmon_datapackage_artifacts()` both know about
multi-table resources, inferred tables, codes, dataset metadata, and semantic
seeding. Verified: `infer_dictionary` is two functions under one name — a real
dictionary builder AND a second package orchestrator that re-derives table/codes/
dataset metadata (145-165), overlapping package-helpers.R:508-525. The 0.1.4
context fix had to touch both — concrete drift evidence.

### Deletion Test

Deleting the artifact-orchestration behavior from `infer_dictionary()` would not
delete the concept; it would concentrate it in
`infer_salmon_datapackage_artifacts()`, which already exists to orchestrate a
Salmon Data Package artifact set. On the `create_sdp` path `infer_dictionary` is
even called with `seed_semantics = FALSE` (package-helpers.R:499), so that
orchestration block is **dead on that path** — clear evidence the behavior belongs
in one Module. This is the strongest deletion-test in the plan.

### Solution

Deepen `infer_salmon_datapackage_artifacts()` as the canonical orchestration
Module for one-shot package artifact inference. Keep `infer_dictionary()` focused
on dictionary rows, column roles, value types, and dictionary-specific review
placeholders. Preserve existing `infer_dictionary()` list-input behavior through
compatibility tests while moving package-wide orchestration behind the artifact
Module.

**Two things the original Solution must name:**

1. **Both attribute schemes are load-bearing contract** — multi-table `inferred_*`
   (asserted at test-dictionary-helpers.R:308-311) and single-table `seed_*`
   (currently uncharacterized). Freeze both before moving code; decide explicitly
   whether the consolidated Module emits one unified scheme or preserves both.
   Because `infer_dictionary` is a **public export**, this is a compatibility/
   deprecation decision, not internal-only.
2. **The two metadata-orchestration blocks diverge** (bare seed-override at
   dictionary-helpers.R:149-165 vs normalize + `.ms_prefill_legacy_estimate_method_code_terms`
   (519) + `.ms_select_semantic_seed_codes`/`semantic_code_scope` (527-532) at the
   artifact path). A shared helper must **parameterize** this divergence — do not
   collapse to one behavior, or `infer_dictionary(seed_semantics = TRUE)` silently
   gains scope-based code selection and legacy prefill.

### Tiny Commits

1. **Audit/strengthen:** the list-input + `inferred_*` test already exists
   (test-dictionary-helpers.R:254-314). Extend it to also pin the single-table
   `seed_*` scheme (currently uncharacterized).
2. Add characterization tests for `infer_salmon_datapackage_artifacts()` output
   across resources, dictionary, table metadata, codes, dataset metadata, and
   semantic suggestions in one place (genuinely net-new — today only narrow
   assertions exist).
3. **Insert: freeze both attribute schemes as the migration contract.** Then move
   shared resource normalization into one internal helper used by both paths —
   **parameterized** for the bare-vs-rich divergence so neither path's output
   changes.
4. Move table/code/dataset metadata orchestration out of `infer_dictionary()`
   where it is only needed for semantic-seeding compatibility. **Land the extracted
   orchestration in a NEW file** (e.g. `R/artifact-inference.R`) rather than growing
   the 2975-line `package-helpers.R` — this captures the god-file Locality win
   (Missing/Future #1) for free instead of postponing it.
5. Make `infer_dictionary(seed_semantics = TRUE)` delegate package-wide context
   gathering to the shared semantic-seeding Module — **but not the LLM arg tail,
   which R2 already centralizes** (do R2 first). **Resolve the commit-4/commit-5
   tension explicitly:** keeping `inferred_*` attached (commit 4) while removing the
   orchestration (commit 5) must NOT become a shim that re-derives the attributes
   just to satisfy the contract (that re-introduces the duplication R5 removes).
   Decide one: (a) keep the attributes by having the dictionary return them *from*
   the shared Module's output, or (b) deprecate the dictionary-side attributes with a
   NEWS note. Decide the silent-drop warning here if not already fixed in R2.
6. Keep `create_sdp()` calling the orchestration Module; avoid broad changes to
   writing/validation in the same refactor.

### Benefits

- Better Locality for one-shot Salmon Data Package artifact inference.
- More Leverage for `create_sdp()` — one orchestration Module.
- Lower risk that dictionary-only behavior and package-wide behavior drift.

### Testing Decisions

- Protect `infer_dictionary()` compatibility (both attribute schemes) before
  moving behavior.
- Verify `create_sdp()` behavior through existing package-helper tests (the heavy
  gate; test-validation-helpers.R is thin and partly network-gated).
- Keep metadata/schema validation tests in the loop.

### Risks

- `infer_dictionary` is a **public exported function**; external users may read
  `inferred_*` / `seed_*` off the returned dict. Treat attribute changes as a
  compatibility decision with a deprecation note.
- `semantic_code_scope` / `.ms_select_semantic_seed_codes` and
  `.ms_prefill_legacy_estimate_method_code_terms` exist only in the artifact path;
  routing dictionary seeding through a shared Module must not silently import them.
- The dead-on-one-path duplication (infer_dictionary blocks are dead when called
  from `create_sdp` but live when called directly) means consolidation must not
  break the direct-call path while removing the dead artifact-path code.
- Keep write/export behavior out of scope (the easy way for this to become a broad
  workflow rewrite).

## Missing / Future Refactor Candidates

Surfaced during review; not required for this plan but worth tracking.

1. **`package-helpers.R` is a ~2975-line god-file.** It owns orchestration,
   `create_sdp`, writing, resource/metadata inference, and EDH post-processing.
   Once R5 lands, splitting writing/post-processing from inference/orchestration
   would be a high-value Locality win. (Partially addressed by
   `R/artifact-inference.R`; further splitting remains deliberately out of
   scope here.)
2. **Shared chat request builder.** The two divergent HTTP body assemblers
   (`.ms_llm_chat_json_request` vs `.ms_chat_http_request`) duplicate
   provider/header logic. Converging them would let the review contract become
   single-shape and simplify R4's normalizer. (Still open/deferred.)
3. **Test fixture consolidation.** The canonical dictionary tibble is copy-pasted
   ~30× across test files; `helper-dictionary.R` already exists as a home. R3/R5
   touch row/column shape, so a shared fixture would cut churn substantially.
   (Done for ordinary repeated fixtures via `tests/testthat/helper-dictionary.R`;
   intentionally specialized fixtures remain local.)
4. **Real `AGENTS.md`.** `CLAUDE.md`/`AGENTS.md` are a circular self-reference, so
   the package ships no agent guidance. Seed it from `notes/context.md` (the LLM
   opt-in contract, attribute/IRI-prefix contracts, build/test commands). (Still
   open; pkgdown launcher-page generation is ignored, but source guidance is not
   repaired.)

## Recommended Order

0. **Fix the `infer_dictionary` silent-drop bug** as a standalone commit, with its
   own NEWS entry + regression test. It is a real user-facing correctness bug
   independent of the architecture work; land it first so it cannot slip if R1/R2
   stall. (R2 later folds the warning into the shared option helper.)
0b. **Consolidate the dictionary test fixture** (Missing/Future #3) into
   `helper-dictionary.R` before R3/R5 — both change row/column shape and would
   otherwise force ~30 inline edits and risk drift in the gate tests.
1. **Deepen LLM context handling (R1)** — closest to issue #1.
2. **Centralize LLM option forwarding (R2)** — do before R5 so the LLM tail is
   touched once.
3. **Extract semantic target discovery (R3)** — stabilizes the target-row column
   contract that R4's adapter row builders consume positionally.
4. **Deepen the LLM review adapter (R4)** — decision pre-resolved (deepen); deepen
   it against the now-frozen target-row contract.
5. **Make package artifact inference the canonical orchestration Module (R5)** —
   broadest/riskiest; depends on R2's tail extraction and the attribute-scheme freeze.

**Round-2 ordering change:** the original enhanced order put R4 before R3. R4's
decision is settled, which makes it *safe* anytime but not *urgent* early — and R4
deepens a consumer (adapter row builders, adapter:36-118) of the very target-row
columns R3 moves. Doing **R3 before R4** means the adapter is deepened against a
stable contract. If you keep R4 earlier for scheduling reasons, freeze the
target-row + assessment-row column contracts as an explicit R4 precondition first.
Either way the adapter↔target-row positional coupling must be named in both
refactors' risks.

## Validation Ladder

For each tiny commit:

```r
pkgload::load_all(".", quiet = TRUE)
```

For each completed refactor:

```r
testthat::test_file("tests/testthat/test-llm-semantic-helpers.R", reporter = "summary")
testthat::test_file("tests/testthat/test-package-helpers.R", reporter = "summary")
```

For R3/R4 (target discovery + review contract), also:

```r
testthat::test_file("tests/testthat/test-semantic-suggestions.R", reporter = "summary")
testthat::test_file("tests/testthat/test-chat-decomposition.R", reporter = "summary")
```

For any refactor touching target discovery or artifact orchestration:

```r
testthat::test_file("tests/testthat/test-dictionary-helpers.R", reporter = "summary")
testthat::test_file("tests/testthat/test-validation-helpers.R", reporter = "summary")
```

> Note: `test-validation-helpers.R` has only 6 tests and one is network-gated
> (`fetch_salmon_ontology`, w3id.org), so it is a **weak** gate — the real
> coverage for R3/R5 is `test-package-helpers.R` and `test-dictionary-helpers.R`.
> Network-gated tests skip silently offline; do not read a green run as full
> coverage — **at each refactor boundary, confirm the skipped-test count has not
> increased** (a refactor can silently convert a real test into a skip).

Column-contract gate (before R3 and R4): add a characterization test that snapshots
the **column names** of (a) the normalized target tibble and (b) the adapter
assessment row, and assert them unchanged. The named test files above can pass while
silently dropping/reordering columns if they assert only subsets.

For R5 (changes a **public export's** attributes), run `R CMD check` at the commit
that changes attribute attachment — not only at merge — to catch example / NAMESPACE
/ doc drift on `infer_dictionary` mid-refactor.

Before merging any implementation branch:

```r
devtools::document()
devtools::test(reporter = "summary")
pkgdown::build_site()
```

Also run:

```sh
git diff --check
R CMD build .
R CMD check <built tarball>   # ADDED — catches doc/example/NAMESPACE drift the test suite misses
```

And add a `NEWS.md` entry for any observable behavior change (notably the
`infer_dictionary` ignored-options warning).

## Out of Scope

- Changing public argument names.
- Auto-enabling LLM review when context files or text are supplied.
- Changing default providers, model defaults, or network behavior.
- Reworking pkgdown site structure except where generated docs follow source
  changes.
- Rebranding URLs from `dfo-pacific-science/metasalmon` to
  `salmon-data-mobilization/metasmn`; that is a separate existing `main`
  workstream.
- Splitting `package-helpers.R` and converging the chat request builders (tracked
  in Missing / Future Refactor Candidates, not this plan).
- Implementing the bundle-aware / `retry_search` / `request_new_term` outcomes
  (tracked in the retrieval-gap roadmap) — this plan only keeps the contracts
  *shaped* to receive them.
