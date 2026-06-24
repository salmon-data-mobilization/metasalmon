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

## Global Constraints

- Preserve public function signatures unless a separate compatibility plan is
  approved.
- Preserve explicit network/LLM opt-in. Supplying context files or text must not
  silently enable LLM review.
- Keep R code in the existing tidyverse style and use the native pipe where it
  improves readability.
- Keep each commit small enough that `devtools::test()` can pass after the
  commit.
- Prefer testing through public or stable internal Interfaces. Avoid tests that
  assert temporary local variables inside implementations.
- Regenerate roxygen and pkgdown only when public documentation changes.

## Refactor 1: Deepen LLM Context Handling

### Files and Evidence

- `R/llm-semantic-helpers.R`
  - `.ms_validate_llm_context_files()` validates file-path shape at lines
    441-459.
  - `.ms_warn_if_llm_context_ignored()` owns ignored-context warnings at lines
    461-481.
  - `.ms_context_text_from_file()` parses individual context files at lines
    483-533.
  - `.ms_collect_context_chunks()` collects context text and chunks it at lines
    597-621.
  - `.ms_prepare_context_chunks()` selects target-specific chunks at lines
    623-640.
- `R/semantics-helpers.R`
  - `suggest_semantics()` validates and warns directly at lines 332-337.
  - LLM review receives context arguments at lines 1182-1198.
- `R/package-helpers.R`
  - `infer_salmon_datapackage_artifacts()` validates context paths at line 460
    and separately warns about `seed_semantics = FALSE` at lines 462-466.
- `R/dictionary-helpers.R`
  - `infer_dictionary()` computes LLM request state and validates context paths
    at lines 92-100.

### Problem

The current LLM context Module is partly deep and partly shallow. The parsing
implementation is centralized, but callers still need to know several parts of
the Interface: path-only inputs, ignored-context warning policy, `llm_assess`
interaction, chunk pooling, optional dependency errors, source labels, and
target-specific scoring.

Alice's report exposed this split. The bug fix added the missing guardrails, but
it still required changes in multiple Modules because no single context Module
owned the complete rule: "context is accepted only as file paths/text, parsed
once, and used only when explicit LLM review is enabled."

### Deletion Test

Deleting `.ms_validate_llm_context_files()` would not delete complexity; it
would move context validation back into `suggest_semantics()`,
`infer_dictionary()`, and `infer_salmon_datapackage_artifacts()`. That means the
Module is earning its keep. But deleting the surrounding warning and preparation
helpers would still leave callers with policy decisions, so the Module is not
deep enough yet.

### Solution

Deepen LLM context handling as one internal Module that owns:

- accepted input shapes,
- ignored-context warning policy,
- optional dependency failures for PDF and Excel,
- parsing and normalization,
- chunk pooling,
- target-specific chunk scoring,
- source accounting for LLM assessment rows.

The public entry points should continue to expose simple `llm_context_files` and
`llm_context_text` arguments. They should not need to know how context is parsed
or how many times it is read.

### Tiny Commits

1. Add characterization tests around context behavior:
   - parsed objects error before retrieval,
   - context paths with `llm_assess = FALSE` warn and do not call the LLM,
   - context files are parsed only once per `suggest_semantics()` call,
   - empty and unsupported context files preserve current warning behavior.
2. Move context validation and ignored-context warning policy behind one
   internal context Module while keeping current helper names as temporary
   wrappers.
3. Move context collection, chunking, scoring, and source reporting behind the
   same Module.
4. Replace direct caller use of validation/warning/chunk helpers with the deeper
   Module.
5. Delete compatibility wrappers only after all callers and tests cross the new
   Seam.

### Benefits

- Better Locality: context behavior changes in one place instead of across
  semantic, package, and dictionary callers.
- More Leverage: tests can exercise the complete context Interface without
  fake retrieval or fake LLM calls.
- Lower risk of another Alice-style surprise when new context formats or warning
  rules are added.

### Testing Decisions

- Extend `tests/testthat/test-llm-semantic-helpers.R` for direct context Module
  behavior.
- Keep `tests/testthat/test-package-helpers.R` tests that cover the public
  `create_sdp()` path.
- Add one sentinel test where `llm_context_files` and `llm_context_text` are
  supplied with `llm_assess = FALSE` and an LLM request function that errors if
  called.

### Risks

- PDF and Excel context parsing depend on optional packages. Do not hide those
  errors behind a generic context result.
- Context source labels appear in LLM assessment output. Preserve source
  reporting exactly unless a migration note is written.

## Refactor 2: Centralize LLM Option Forwarding

### Files and Evidence

- `R/dictionary-helpers.R`
  - `infer_dictionary()` computes `llm_requested` at lines 92-99.
  - Multi-table semantic seeding assembles LLM arguments at lines 171-195.
  - Single-table semantic seeding repeats the same assembly at lines 247-271.
- `R/package-helpers.R`
  - `infer_salmon_datapackage_artifacts()` repeats `llm_requested` at lines
    452-459.
  - It repeats LLM argument assembly at lines 541-566.
  - `create_sdp()` forwards every LLM option again at lines 831-855.

### Problem

The LLM semantic-review option path is shallow. Each caller knows which options
mean "LLM requested", which options affect shortlist size, and which arguments
must be forwarded to `suggest_semantics()`. The 0.1.4 fix had to touch multiple
Modules because one Interface rule was duplicated across call sites.

### Deletion Test

Deleting the repeated `llm_requested` blocks would not delete complexity. It
would force every caller to rediscover which LLM options are meaningful. That is
a signal for a deeper coordination Module.

### Solution

Create one internal semantic-review option Module that owns:

- whether LLM-related options were supplied,
- seed/no-seed warning policy,
- context validation and ignored-context policy by delegating to the context
  Module,
- effective shortlist size,
- conversion from public arguments into the internal argument list passed to
  `suggest_semantics()`.

Public entry points should remain explicit, but their Implementation should ask
the option Module for the derived behavior instead of rebuilding it locally.

### Tiny Commits

1. Add characterization tests for `infer_dictionary()` and
   `infer_salmon_datapackage_artifacts()` when LLM-related options are supplied
   with `seed_semantics = FALSE`.
2. Add a small internal helper for "LLM semantic review was requested" and
   replace the two duplicated `llm_requested` blocks.
3. Move effective shortlist calculation for LLM review into the same option
   Module.
4. Move `suggest_semantics()` argument assembly into the option Module while
   preserving public signatures.
5. Remove duplicate local option assembly once tests pass through all public
   entry points.

### Benefits

- Better Locality for new LLM knobs such as provider options, context behavior,
  timeout behavior, or retry behavior.
- Better Leverage from tests that assert one option policy and know it applies
  to `infer_dictionary()`, `infer_salmon_datapackage_artifacts()`, and
  `create_sdp()`.
- Less chance that one caller silently behaves differently from another.

### Testing Decisions

- Add tests at the public entry points because option forwarding is part of
  their Interface.
- Keep request-function sentinels for hidden LLM calls.
- Use mocked search functions; do not rely on live vocabulary services.

### Risks

- Public function signatures are long but user-facing. Do not hide or replace
  them without a separate compatibility decision.
- `llm_request_fn` is an advanced test hook. Preserve it through the refactor so
  existing tests remain deterministic.

## Refactor 3: Extract Semantic Target Discovery

### Files and Evidence

- `R/semantics-helpers.R`
  - `suggest_semantics()` currently owns input normalization at lines 342-368.
  - It defines many local query/placeholder helpers at lines 391-424.
  - It discovers column targets at lines 943-988.
  - It discovers code targets at lines 990-1033.
  - It discovers table targets at lines 1035-1072.
  - It discovers dataset targets at lines 1074-1109.
  - It performs retrieval at lines 1111-1132.
  - It performs LLM handoff and attribute attachment at lines 1182-1205.
- `R/semantic-suggestions.R`
  - It already owns target/suggestion row shape helpers at lines 1-122.
  - It owns LLM assessment merge behavior at lines 243-268.

### Problem

`suggest_semantics()` is a large Module with a broad Interface. It owns target
discovery, query heuristics, deterministic retrieval, LLM review, result
attachment, and user messages. This makes tests expensive: a test for target
selection often needs fake retrieval or fake LLM plumbing even when the behavior
under test is only "which semantic targets exist?"

The existing `semantic-suggestions.R` Module has useful row-shape helpers, but
the behavior-rich target discovery implementation still lives inside
`suggest_semantics()`.

### Deletion Test

Deleting `semantic-suggestions.R` today would mostly inline column lists,
normalizers, and merge helpers. The behavior-dense target discovery complexity
would remain inside `suggest_semantics()`. That means the current Module is not
deep enough for the semantic target concept.

### Solution

Deepen semantic target discovery as its own Module before retrieval or LLM
review. It should own the rules for turning dictionaries, tables, codes, dataset
metadata, and resource context into normalized semantic target rows. Retrieval
and LLM review should consume those target rows without knowing how they were
chosen.

### Tiny Commits

1. Add characterization tests for target discovery using small dictionaries,
   table metadata, code metadata, and dataset metadata without calling
   `find_terms()`.
2. Move target-row column definitions and normalizers into the semantic target
   Module if they are not already there.
3. Move column target discovery out of `suggest_semantics()`.
4. Move code target discovery out of `suggest_semantics()`.
5. Move table and dataset target discovery out of `suggest_semantics()`.
6. Make `suggest_semantics()` call target discovery, then retrieval, then LLM
   review in clearly separated steps.
7. Delete now-dead local helper definitions from `suggest_semantics()`.

### Benefits

- Better Locality for semantic target rules.
- More Leverage in tests: target discovery can be verified without fake search,
  fake LLM, or output attributes.
- A clearer Seam between semantic target discovery and candidate retrieval.

### Testing Decisions

- Add direct internal tests for target discovery row output.
- Keep existing end-to-end `suggest_semantics()` tests as regression coverage.
- Use fixtures that cover column, code, table, and dataset target scopes.

### Risks

- Target discovery is behaviorally dense. Preserve exact row columns and values
  until a deliberate behavior change is approved.
- LLM review and deterministic retrieval depend on stable target keys. Changes
  to target row keys must be treated as compatibility-sensitive.

## Refactor 4: Clarify the LLM Review Adapter

### Files and Evidence

- `R/llm-review-adapter.R`
  - Response parsing and assessment validation live at lines 1-34.
  - Empty and successful assessment row construction live at lines 36-118.
- `R/llm-semantic-helpers.R`
  - Single-record review uses the adapter at lines 1454-1470.
  - Batch review and fallback behavior live at lines 1473-1533.
  - Provider-wide failure handling lives at lines 1539-1578.
  - The overall LLM assessment orchestration lives at lines 1580-1692.

### Problem

`llm-review-adapter.R` is currently a suspicious shallow Module. It has one real
Adapter path and several wrappers around LLM review response parsing and row
construction. One Adapter means a hypothetical Seam; two Adapters means a real
Seam. The current split makes maintainers bounce between files to understand one
review request.

### Deletion Test

If `llm-review-adapter.R` were deleted today, much of its logic would move back
into `llm-semantic-helpers.R`, and the system might become easier to read
because there is no second Adapter yet. That suggests either the Module should
be collapsed or deepened enough to own the LLM review response contract.

### Solution

Make an explicit decision:

- Collapse the adapter if there is still only one LLM review path and no near
  term second Adapter.
- Deepen the adapter if chat decomposition, semantic review, and future review
  modes need a shared response contract.

If deepened, the Module should own request response normalization, validation,
empty assessment rows, success assessment rows, and batch result normalization.
If collapsed, the code should return to the review Implementation and the
unnecessary Seam should be removed.

### Tiny Commits

1. Add characterization tests around malformed single-target and batch LLM
   responses.
2. Inventory all call sites that rely on `llm-review-adapter.R`.
3. Decide collapse versus deepen based on whether there are at least two real
   Adapters or review modes sharing the contract.
4. If collapsing, move adapter wrappers into the review Implementation and
   delete the file.
5. If deepening, move batch response normalization and row construction into the
   adapter and make LLM orchestration call the adapter at one Seam.
6. Run the full LLM-helper tests after each movement.

### Benefits

- Better Locality for the LLM response contract.
- Less file-hopping for maintainers reading one review flow.
- A real Seam only if behavior actually varies across Adapters.

### Testing Decisions

- Test through semantic review behavior, not raw JSON helper internals, except
  for clearly reusable response normalization.
- Use fake request functions and malformed response fixtures.
- Keep provider/network tests out of scope.

### Risks

- Collapsing may be premature if another review Adapter is about to land.
- Deepening may preserve an unnecessary Seam. Decide before moving code.

## Refactor 5: Make Package Artifact Inference the Canonical Orchestration Module

### Files and Evidence

- `R/dictionary-helpers.R`
  - `infer_dictionary()` handles multi-table resources at lines 108-143.
  - It also infers table metadata, codes, and dataset metadata at lines 145-165.
  - It seeds semantics and attaches package-adjacent attributes at lines
    167-199.
  - The single-table path also seeds semantics at lines 243-271.
- `R/package-helpers.R`
  - `infer_salmon_datapackage_artifacts()` already orchestrates resources,
    dictionary, tables, codes, dataset metadata, semantic seeding, and returned
    artifacts at lines 427-586.
  - `create_sdp()` then writes and post-processes those artifacts at lines
    831-950.

### Problem

`infer_dictionary()` and `infer_salmon_datapackage_artifacts()` both know about
multi-table resources, inferred tables, inferred codes, dataset metadata, and
semantic seeding. That duplication increases the chance that a workflow fix has
to touch both Modules. The 0.1.4 context validation change is one example.

### Deletion Test

Deleting the artifact-orchestration behavior from `infer_dictionary()` would not
delete the concept; it would concentrate that behavior in
`infer_salmon_datapackage_artifacts()`, which already exists to orchestrate a
Salmon Data Package artifact set. That suggests the orchestration Module should
be deeper and `infer_dictionary()` should become more dictionary-focused.

### Solution

Deepen `infer_salmon_datapackage_artifacts()` as the canonical orchestration
Module for one-shot package artifact inference. Keep `infer_dictionary()` focused
on dictionary rows, column roles, value types, and dictionary-specific review
placeholders. Preserve existing `infer_dictionary()` list-input behavior through
compatibility tests while gradually moving package-wide orchestration behind the
artifact Module.

### Tiny Commits

1. Add characterization tests for `infer_dictionary()` list input and attributes
   that callers may rely on.
2. Add characterization tests for `infer_salmon_datapackage_artifacts()` output
   across resources, dictionary, table metadata, codes, dataset metadata, and
   semantic suggestions.
3. Move shared resource normalization into one internal helper used by both
   paths.
4. Move table/code/dataset metadata orchestration out of `infer_dictionary()`
   where it is only needed for semantic seeding compatibility.
5. Make `infer_dictionary(seed_semantics = TRUE)` delegate package-wide context
   gathering to the artifact orchestration Module or a shared semantic seeding
   Module instead of duplicating assembly.
6. Keep `create_sdp()` calling `infer_salmon_datapackage_artifacts()` and avoid
   broad changes to writing/validation in the same refactor.

### Benefits

- Better Locality for one-shot Salmon Data Package artifact inference.
- More Leverage for `create_sdp()` because it can rely on one orchestration
  Module.
- Lower risk that dictionary-only behavior and package-wide behavior drift.

### Testing Decisions

- Protect `infer_dictionary()` compatibility before moving behavior.
- Verify `create_sdp()` behavior through existing package-helper tests.
- Keep metadata/schema validation tests in the loop because artifact inference
  feeds package writing.

### Risks

- `infer_dictionary()` may have callers relying on attributes from semantic
  seeding. Characterize before changing.
- This refactor can easily become a broad workflow rewrite. Keep write/export
  behavior out of scope.

## Recommended Order

1. Deepen LLM context handling.
2. Centralize LLM option forwarding.
3. Clarify the LLM review Adapter.
4. Extract semantic target discovery.
5. Make package artifact inference the canonical orchestration Module.

The first two are closest to issue #1 and should be done together or back to
back. The LLM review Adapter decision should happen before moving more review
behavior. Semantic target discovery and artifact orchestration are larger
refactors and should wait until the context/option path is stable.

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

For any refactor touching target discovery or artifact orchestration:

```r
testthat::test_file("tests/testthat/test-dictionary-helpers.R", reporter = "summary")
testthat::test_file("tests/testthat/test-validation-helpers.R", reporter = "summary")
```

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
```

## Out of Scope

- Changing public argument names.
- Auto-enabling LLM review when context files or text are supplied.
- Changing default providers, model defaults, or network behavior.
- Reworking pkgdown site structure except where generated docs follow source
  changes.
- Rebranding URLs from `dfo-pacific-science/metasalmon` to
  `salmon-data-mobilization/metasmn`; that is a separate existing `main`
  workstream.

