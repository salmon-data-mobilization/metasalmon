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
- [x] 2026-07-28: Checkpoint 1 contract review completed; all compatibility
  contracts were retained in the implementation and fixtures.
- [x] 2026-07-28: Milestone 1 implemented: pinned ontology manifest, structured
  replay/live evidence, per-rule comparison, immutable promotion, exact-cohort
  gate, and CI.
- [x] 2026-07-28: Checkpoint 2 evidence-pack re-review passed after all lineage,
  ontology, interaction, cohort, and commit-to-artifact provenance findings were
  resolved.
- [x] 2026-07-28: Milestone 2 implemented: structured gaps, retry safety, chat vocabulary, and GCDFO
  request routing.
- [x] 2026-07-28: Checkpoint 3 gap/retry compatibility re-review passed after
  duplicate-identifier, canonical chat-vocabulary, and missing regression-test
  findings were resolved.
- [x] 2026-07-28: Milestone 3 implemented: canonical Semantic Bundle Review Module and adapters.
- [x] 2026-07-28: Checkpoint 4 module architecture review passed after resolving
  retry-wide fallback, provider-failure fan-out, and unstable blank-IRI IDs.
- [x] 2026-07-28: Milestone 4 implemented: strict source policy, role-aware retrieval, and one bounded
  bundle reassessment.
- [x] 2026-07-28: Checkpoint 5 retrieval/source-policy review passed after adding
  actual retrieval assertions at every exported entry point and on generic and
  bundle retries.
- [x] 2026-07-28: Milestone 5 implemented: deterministic bundle validators.
- [x] 2026-07-28: Checkpoint 6 ontology and I-ADOPT re-review passed after
  property/unit pair checks, method-evidence boundaries, predicate rejection,
  and `REVIEW:` isolation were added.
- [ ] Milestone 6: documentation, 0.1.6 metadata, pkgdown, build/check, and live
  gate disposition.
- [x] 2026-07-28: Updated source/reference/vignette documentation and NEWS,
  regenerated pkgdown, and passed replay, focused tests, and the complete test
  suite. Source-package build/check and the live gate remain.
- [x] 2026-07-28: Built `metasalmon_0.1.6.tar.gz`; the standard
  `R CMD check metasalmon_0.1.6.tar.gz` completed with `Status: OK`, including
  installed-package tests, rebuilt vignettes, and the PDF manual.
- [x] 2026-07-28: Checkpoint 7 final adversarial code/release review passed. The
  first pass found
  release blockers in returned-source filtering, round-two fallback call bounds,
  chat native types, validator context locality, and evidence lineage. The code
  and focused regression tests were updated. The first re-review cleared the
  original source-policy and call-bound findings but found stricter field-anchor,
  retained-round lineage, raw-publication attestation, and stale build-command
  issues. A second ontology re-review then found an overlapping-column-name
  evidence leak and ambiguous explicit per-time mortality rates; both now have
  focused regression fixes. A subsequent code pass found weak one-word anchors
  and compound physical-rate precedence gaps; those are also fixed and covered.
  A further ontology probe found suffix-overlap and overbroad compound matching;
  both now resolve conservatively with explicit adversarial coverage. A final
  code probe found that Markdown/Rmd list and table markers could obscure a
  suffixed identifier; markup-aware token extraction and regressions now close
  that path. Re-review also caught numbered-list human prose as a false negative;
  phrase matching now uses the same unmarked text and the full prefix matrix is
  covered. The final ontology matrix then exposed spaced/inverse temporal
  denominators and embedded compound-unit overmatching. Compound units now match
  only complete supported input values, denominator notation is normalized per
  value, and powered/chained forms remain unknown, including inverse powers not
  written with `/` or `per`. The agreed matrix is now frozen for 0.1.6; a general
  unit-expression parser remains out of scope. Final bounded dispositions passed
  38/38 dimension cases, 55/55 locality cases, replay/oracle/lineage/attestation
  checks, and the release/docs review at commit `b5e8740`.
- [ ] Push final branch, make the PR ready when all release gates pass, merge to
  `main`, verify Pages, and remove the feature branch.

## Surprises & Discoveries

- The repository has no GitHub Actions workflow. Theme A therefore needs a new,
  minimal R workflow rather than an extension of existing CI.
- OpenRouter credentials are configured locally and the authenticated model
  catalogue contains the exact approved `openai/gpt-5.4-mini` identifier. Live
  evaluation remains deferred until the final reviewed source state is committed;
  no model substitution is permitted.
- Historical model observations exist only as prose. They are evidence, but not
  raw replay captures, and must be labelled `prose_only`.
- The current decomposition prompt says every variable is a SKOS concept. The
  ontology permits native term types that do not support this assumption.
- `detect_semantic_term_gaps()` currently constructs a different composite key
  than the canonical semantic-key helper and requires a `score` column despite
  documenting it as optional.
- The first evidence replay encoded more semantic events than its assessment and
  final-dictionary rows could prove. Replay validation now derives and
  cross-checks events against assessment, prefill, gap, and term-request rows.
- The first bundle implementation retried malformed reassessments as an
  all-or-nothing unit, expanded one provider outage into six per-target calls,
  and occurrence-numbered blank-IRI IDs. Checkpoint review caught all three;
  fallback is now per-slot, transport failures are non-destructive typed errors,
  and blank-IRI IDs are content-addressed.
- The initial benchmark named ontology resources that did not exist at its pinned
  revision or assigned the wrong native RDF type. A checked-in primary-source
  manifest now pins every fixture IRI, source revision, artifact hash, native
  type, and definition provenance.
- Role-shaped target labels can manufacture apparent evidence. Deterministic
  method validation now uses source column/context evidence rather than generated
  slot labels, and ontology relation predicates cannot populate semantic value
  slots.
- A real clean commit identifier was initially separable from artifact hashes
  taken from the current working tree. Capture validation now reads
  `DESCRIPTION`, the benchmark script, cases, schema, and ontology manifest
  directly from the recorded commit's Git objects; an older-real-commit mutation
  proves that cross-tree evidence is rejected.
- A benchmark test called `pkgload::load_all()` inside the shared test process.
  That replaced the package namespace and made later namespace mocks miss their
  target only in the complete suite. The unnecessary reload was removed and
  update-check mocks were made test-scoped; the combined regression and full
  suite now pass deterministically.
- `scripts/` is intentionally excluded from the built R source package, so a
  direct prompt-parser test must skip before sourcing the benchmark harness
  during installed-package checks. CI now fetches full Git history so the local
  older-real-commit mutation still executes in repository tests.
- Final review showed that passing requested source names into an Adapter is not
  enough to enforce an explicit allowlist: the returned rows also require
  post-filtering. It also showed that malformed round-two slots could invoke
  per-target provider fallback and exceed the two-request bundle bound.
- A union of context chunks is appropriate for the model prompt but too broad
  for deterministic evidence. Validator evidence now keeps dictionary/target
  text and only includes external chunks anchored to the current field, so an
  unrelated method or constraint cannot validate the selected slot.
- Reviewed captures previously left their immutable raw capture in ignored
  staging, and assessment lineage only established target association. Promotion
  now retains the content-addressed raw capture and hashes each request, response,
  provider assessment item, and final assessment row. Cohorts also require three
  distinct provider-run fingerprints.
- The first validator-locality fix still admitted generic target labels and
  queries such as `count`. External deterministic evidence now requires the
  canonical column name, or a sufficiently distinctive label only when the
  name is unavailable.
- Provider lineage cannot simply select the last interaction naming a target:
  malformed round-two slots deliberately retain their first-round assessment.
  The harness now validates each response item against the request's candidate
  IDs and selects the last usable provider assessment instead.
- Normalizing canonical field names into words makes `CATCH_COUNT` a substring
  of `SPAWNER_CATCH_COUNT`, while accepting every exact one-word identifier makes
  `count` too weak to establish locality. External validator evidence now accepts
  distinctive canonical identifiers as complete underscore-preserving tokens or
  a human-readable phrase at the start of a chunk; weak singleton names do not
  anchor external evidence, and identifier-looking suffix forms cannot use the
  phrase fallback even when preceded by Markdown/Rmd list, heading, quote, or
  table markup.
- Named rates such as mortality are dimensionless only when no explicit temporal
  denominator is present. Strong physical dimensions retain precedence, then an
  explicit per-time pattern wins over the named dimensionless-rate heuristic.
  Known flow/speed compounds resolve first; unsupported physical-per-time
  combinations, temporal IRI suffixes, and squared/cubed extensions remain
  unknown rather than generating a false mismatch. Spaced slash and inverse-time
  notation count as explicit denominators, while repeated equivalent evidence
  across label, definition, and IRI does not count as a chained dimension.
- Correct source instructions are insufficient when generated pkgdown output is
  stale. All active contributor routes now invoke `scripts/build-pkgdown.R`, and
  the release gate checks the generated index/search corpus after rebuilding.

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
- 2026-07-28: Count all six Theme A cases as critical while keeping only the
  unresolved `CATCH_WEIGHT` whole-variable gap rule advisory. Rationale: property
  correctness and forbidden outcomes remain release-critical; ontology-owner
  adjudication of the gap itself does not.
- 2026-07-28: Derive benchmark prefills through the package's actual four-role
  auto-apply functions, gaps through `detect_semantic_term_gaps()`, and routes
  through `render_ontology_term_request()`. Stored event lists are validated
  against those structured rows instead of acting as independent oracle input.
- 2026-07-28: Promoted captures are immutable and content-addressed. Promotion
  has no overwrite flag, requires human review/sanitization plus
  pre-sanitization hash lineage, checks pinned fixture and ontology provenance,
  and permits an individually failing run because the release rule is 2-of-3.
  The separately promoted cohort manifest records three capture hashes and the
  exact source/provider/model gate.
- 2026-07-28: Promote the immutable raw capture beside its reviewed, sanitized
  copy. Rationale: the pre-sanitization hash is independently verifiable after
  staging cleanup, while the reviewed copy may redact messages or responses
  without changing their recorded request/response identities.
- 2026-07-28: Require three distinct provider-run fingerprints composed from
  provider response IDs and raw-response hashes. Rationale: distinct run IDs or
  reviewed-capture hashes alone do not prove three independent provider calls.
- 2026-07-28: Live review uses frozen candidate fixtures and records
  `retrieval_mode = "frozen_fixture"`; retrieval behavior is covered separately
  by deterministic tests.
- 2026-07-28: Freeze deterministic dimension validation to the reviewed fixture
  matrix after the final inverse-power correction. Rationale: validators are
  conservative release safeguards, not a general unit-algebra engine; unsupported
  expressions remain unknown and broader parsing belongs in a proven library or
  a separately planned change.

## Review Checkpoint Log

- **Checkpoint 1 - contract/fixture:** passed. The 19-column target contract,
  28-column assessment prefix, opt-in LLM behavior, public attributes,
  `REVIEW:` markers, and four-role auto-apply boundary remain explicit.
- **Checkpoint 2 - evidence/oracles:** passed on final re-review. The initial
  review failed because replay
  events were disconnected from structured outputs, live prefills/gaps/routes
  were synthesized, optional metrics affected comparisons, promotion was
  overwriteable, and ontology provenance was unpinned. A second review found
  incorrect fixture IRIs/types and weak cross-artifact/cohort provenance. A third
  review found that a valid commit could still be paired with hashes from a
  different worktree. All findings are resolved with a pinned ontology manifest,
  nine-key joins, exact candidate/final-row checks, provider-assessment lineage,
  raw-to-reviewed checksums, mutation tests, commit-resolved artifact hashes,
  exact-source cohort recomputation, content-addressed capture/cohort promotion,
  and per-rule comparisons.
- **Checkpoint 3 - gaps/retries:** passed on re-review. Initial review found metadata loss after score
  filtering, conflated placement/LLM rationales, stale issue templates, weak
  legacy type normalization, lost pre/post rejection rationale, identifier-like
  duplicate handling, canonical chat vocabulary, and missing compatibility pins.
  All findings are fixed and focused tests pass.
- **Checkpoint 4 - bundle architecture:** passed on re-review. Material findings
  resolved: malformed retry slots no longer discard valid slots; provider
  failures no longer trigger six extra calls; blank-IRI IDs are stable,
  content-addressed identities; `llm_top_n` does not truncate public output.
- **Checkpoint 5 - retrieval/source policy:** passed on re-review. Explicit
  sources remain strict at initial and retry retrieval; omitted sources use
  role-aware defaults; exported wrappers and generic/bundle retries have direct
  `search_fn` assertions.
- **Checkpoint 6 - ontology/I-ADOPT:** passed on re-review. Property/unit pairs
  are cross-checked, generated slot labels do not count as evidence, predicates
  are rejected from value slots, and unconfirmed `REVIEW:` values cannot trigger
  accepted-pair redundancy.
- **Checkpoint 7 - final release review:** first pass failed. Material findings
  were: explicit returned-source leakage, extra provider calls from malformed
  reassessment slots, stale SKOS assumptions in interactive chat, unrelated
  context satisfying method/constraint validators, unpromoted raw lineage,
  target-only provider lineage, duplicate-run cohort risk, missing
  ratio/rate dimensions, omitted direct QUDT property retrieval, and stale
  generated-site links/pages. A first re-review found four residual issues:
  generic validator anchors, malformed reassessment lineage, raw-publication
  attestation, and direct pkgdown commands that bypassed the hardened builder.
  The next ontology pass found that normalized field-name substrings could still
  leak evidence across overlapping identifiers and that an explicit temporal
  denominator conflicted with named dimensionless-rate rules. A following code
  pass found weak singleton anchors and compound physical-rate ambiguity; a
  further ontology probe found suffixed identifiers and malformed compound units
  could still bypass those guards. The last code pass found that leading
  Markdown/Rmd markup obscured the suffix check. Each finding now has an
  implementation or build-pipeline fix and focused regression coverage,
  including positive human-prose cases for every accepted markup prefix;
  the final dimensional matrix additionally replaced substring compound matching
  with complete-value matching and per-value denominator guards, then added the
  final inverse-power case. The matrix is frozen for this release. Final
  independent dispositions passed: code behavior and call bounds, 38/38
  dimension cases, 55/55 locality cases, evidence lineage and publication
  attestations, semantic oracles, and release documentation.

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
    Rscript scripts/build-pkgdown.R
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
