# ExecPlan - Theme A semantic review implementation

This is a living execution plan. Keep `Progress`, `Surprises & Discoveries`,
`Decision Log`, and `Outcomes & Retrospective` current while the work proceeds.

## Purpose / Big Picture

Release metasalmon 0.1.6 with a deeper Semantic Bundle Review Module for
measurement columns. A reviewer should be able to judge variable, property,
entity, unit, constraint, and method candidates together; retry retrieval once
without escaping an explicit source allowlist; preserve ontology gaps as
structured data; and rely on deterministic validators to prevent unsupported
automatic acceptance.

The user-visible proof is:

1. replay fixtures exercise representative semantic-review cases offline;
2. `semantic_llm_assessments` preserves retry and escalation provenance;
3. `detect_semantic_term_gaps()` consumes both deterministic and LLM evidence;
4. SMN and GCDFO requests render repository-specific, curator-reviewable bodies;
5. the package test suite, source-package check, and pkgdown build pass.

Umbrella issue: <https://github.com/salmon-data-mobilization/metasalmon/issues/4>

## Progress

- [x] 2026-07-28: Verified a clean `main` at `378d807`, GitHub admin access, and
  the canonical single checkout at `/Users/brettjohnson/code/metasalmon`.
- [x] 2026-07-28: Opened issue #4 and created
  `feature/theme-a-semantic-review` from current `main`.
- [ ] Checkpoint 1: contract and evidence-oracle review.
- [ ] Milestone 1: evidence fixtures, replay/live benchmark, and CI.
- [ ] Checkpoint 2: evidence-pack review and finding disposition.
- [ ] Milestone 2: structured gaps, retry safety, chat vocabulary, and GCDFO
  request routing.
- [ ] Checkpoint 3: gap/retry compatibility review and finding disposition.
- [ ] Milestone 3: canonical Semantic Bundle Review Module and adapters.
- [ ] Checkpoint 4: Module architecture review and finding disposition.
- [ ] Milestone 4: strict source policy, role-aware retrieval, and one bounded
  bundle reassessment.
- [ ] Checkpoint 5: retrieval/source-policy review and finding disposition.
- [ ] Milestone 5: deterministic bundle validators.
- [ ] Checkpoint 6: ontology and I-ADOPT review and finding disposition.
- [ ] Milestone 6: documentation, 0.1.6 metadata, pkgdown, build/check, and live
  gate disposition.
- [ ] Checkpoint 7: final adversarial code/release review.
- [ ] Push final branch, make the PR ready when all release gates pass, merge to
  `main`, verify Pages, and remove the feature branch.

## Surprises & Discoveries

- The repository has no GitHub Actions workflow. Theme A therefore needs a new,
  minimal R workflow rather than an extension of existing CI.
- No provider credentials are configured locally. Live evaluation cannot run
  until an approved provider/model is available; no model substitution is
  permitted.
- Historical model observations exist only as prose. They are evidence, but not
  raw replay captures, and must be labelled `prose_only`.
- The current decomposition prompt says every variable is a SKOS concept. The
  ontology permits native term types that do not support this assumption.
- `detect_semantic_term_gaps()` currently constructs a different composite key
  than the canonical semantic-key helper and requires a `score` column despite
  documenting it as optional.

## Decision Log

- 2026-07-28: Use one branch and one checkout. Rationale: avoid duplicate active
  paths and preserve `main` as the only pre-merge source of truth.
- 2026-07-28: Append two assessment fields after the established 28-column
  prefix: `llm_escalated_from` and
  `llm_retry_query_rejection_reason`. Rationale: additive compatibility and
  symmetric empty/success rows.
- 2026-07-28: Treat explicit `sources` as a strict allowlist and omitted
  `sources` as role-aware defaults. Rationale: caller intent must constrain both
  initial and retry retrieval.
- 2026-07-28: Treat GCDFO as a first-class routing scope while keeping all issue
  submission curator-controlled. The model's namespace is evidence, not routing
  authority.
- 2026-07-28: Preserve model confidence when deterministic validation downgrades
  an `accept` decision. Rationale: confidence remains model provenance; the
  validator finding and final decision record the override.
- 2026-07-28: Keep `CATCH_WEIGHT` whole-variable ontology placement advisory
  until ontology-owner adjudication. `smn:FishWeight` may be a property candidate
  but is forbidden as the whole-variable candidate in the benchmark.

## Outcomes & Retrospective

Not yet complete.

## Context and Orientation

`suggest_semantics()` discovers a frozen 19-column semantic target row, retrieves
candidate rows, and optionally calls the LLM review Adapter. Measurement-column
targets use six ordered semantic roles: variable, property, entity, unit,
constraint, and method. A bundle is the set of those targets for one
dataset/table/column.

The public attributes `semantic_suggestions` and `semantic_llm_assessments` are
compatibility surfaces. LLM review is strictly opt-in. Supplying context or LLM
options without `llm_assess = TRUE` must never trigger a provider request.

Primary implementation areas:

- `R/semantic-suggestions.R`: target/key contracts and suggestion merging.
- `R/llm-review-adapter.R`: assessment-row Interface.
- `R/llm-semantic-helpers.R`: review, exploration, and bundle orchestration.
- `R/semantics-helpers.R`: exported retrieval workflow and source policy.
- `R/term-request-helpers.R`: gap detection, rendering, and optional submission.

## Plan of Work

### Milestone 1 - Evidence and automation

Add versioned Theme A case, replay, and schema fixtures. Add a benchmark script
with `replay`, `live`, `compare`, and `promote` modes. Keep unreviewed captures
under ignored `artifacts/theme-a/`; promote only reviewed, sanitized captures to
`notes/evidence/theme-a/captures/`. Add pull-request CI for replay, tests, and
`R CMD check`.

### Milestone 2 - Gap and retry vertical slice

Normalize assessment rows to the 30-column Interface. Integrate final
`request_new_term` decisions into gap detection using the canonical target key.
Keep the existing 23 gap columns as a prefix and append structured evidence.
Reject exact duplicate retry queries without another provider or search call.
Fix chat decision vocabulary and add repository-specific SMN/GCDFO rendering.

### Milestone 3 - Semantic Bundle Review Module

Create one internal Module for automated measurement-column review. The Module
owns bundle construction, stable candidate IDs, prompt/response shape,
per-slot validation, and per-slot fallback through the existing single-target
Adapter. Generic, code, table, and dataset targets keep their current path.

### Milestone 4 - Retrieval policy and reassessment

Represent omitted-versus-explicit source selection at exported entry points.
Thread the resulting policy through initial retrieval and the Module's single
retry round. Gather valid slot retries, retrieve once, and perform at most one
combined bundle reassessment. Preserve the original shortlist when retrieval or
reassessment provides no usable gain.

### Milestone 5 - Deterministic validation

Add pure validators for method evidence, constraint evidence, role/native term
type, deterministic unit/property dimensional compatibility, and curated
redundancy. A failed validator changes `accept` to `review`, clears selection,
and appends a stable finding code without substituting or retrieving terms.

### Milestone 6 - Release

Update roxygen, reference documentation, vignettes, examples, NEWS, roadmap, and
backlog. Set version 0.1.6, regenerate pkgdown, run the validation ladder, record
the live-gate result, complete final reviews, and merge only when required gates
pass.

## Concrete Steps

Run from `/Users/brettjohnson/code/metasalmon`:

    Rscript -e 'pkgload::load_all(".", quiet = TRUE)'
    Rscript scripts/theme-a-benchmark.R replay
    Rscript -e 'devtools::test(reporter = "summary")'
    Rscript -e 'devtools::document()'
    Rscript -e 'pkgdown::build_site(new_process = FALSE, install = FALSE, lazy = TRUE)'
    R CMD build .
    R CMD check metasalmon_0.1.6.tar.gz
    git diff --check

For the live gate, run three repetitions against one exact configured
`openai/gpt-5.4-mini` provider/model cohort. `openrouter/free` is diagnostic
only. Do not silently replace an unavailable model.

## Validation and Acceptance

- The 19-column target contract remains exact.
- Assessment rows have one exact 30-column shape for empty, success, escalated,
  and normalized legacy data.
- Explicit `sources = "smn"` never introduces QUDT initially or on retry.
- Duplicate retry queries cause no generic-query request, search, or
  reassessment for that slot.
- A bundle makes one initial request and at most one combined reassessment.
- Missing or malformed per-slot bundle output falls back only that slot.
- Method/constraint decisions without supporting evidence cannot remain
  accepted and cannot be auto-prefilled.
- Structured LLM gaps render SMN or GCDFO request bodies without automatic issue
  submission.
- Replay, focused tests, full tests, pkgdown, build, and package check pass.
- The live cohort passes every critical case in at least two of three runs, with
  zero forbidden method/constraint acceptances and zero false prefills. If
  credentials or the approved model remain unavailable, the PR stays draft and
  the blocked release gate is documented.

## Idempotence and Recovery

Fixtures and promoted captures are versioned and immutable. Benchmark staging
uses a run identifier and can be safely repeated. CI and test commands may be
rerun without changing tracked files. Behavioral milestones use atomic commits;
if a milestone fails, fix forward on the feature branch rather than creating a
second implementation path or checkout.
