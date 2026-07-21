# metasalmon — bugs & improvement backlog

Findings from the 2026-06-24 architecture-plan review (multi-agent code reading +
two adversarial verification passes + author spot-checks). Each item cites
`file:line`.

**Verification status legend**
- **confirmed** — an adversarial verifier read the cited code and upheld it.
- **spot-verified** — the author read the code firsthand this session.
- **finder-verified** — surfaced by a focused finder agent with line-level tracing
  but not independently re-verified (the second adversarial pass was cut short by
  the org spend limit).
- **unverified** — evidence-cited but the adversarial verifier errored on the
  spend limit; re-confirm before acting.
- **by-design** — investigated and judged intended behavior (kept for the record).

Severity = how much it can bite a real user.

**Implementation status legend (updated 2026-07-21 on `deepen-architecture`)**
- **fixed** — implemented on this branch and covered by focused tests.
- **done-for-plan** — the refactor-plan objective was completed, but a broader
  future improvement may remain.
- **partially addressed** — risk was reduced or documented, but the underlying
  backlog item is not exhausted.
- **open** — still present in the codebase.
- **deferred** — deliberately left out of the current refactor because it belongs
  to a separate roadmap or would change behavior beyond the plan.

**Current snapshot:** #1, #2, #7, #10, #11, #12, #14, #15, #16, #17, #18,
#19, #20, #21, #25, #27, and #28 are fixed or done-for-plan. #26, #29, and
#30 are partially addressed. #4, #5, #6, #8, #9 were fixed on 2026-06-26 (roadmap
clear-the-decks), and #32 was fixed during the 0.1.5 release gate on 2026-07-21.
#3, #13, #22, #23, #24, and #31 remain open/deferred as noted below.

**Forward plan:** the open/deferred items are sequenced into themed workstreams in
`notes/exec-plans/2026-06-26-next-behaviours-roadmap.md` (e.g. #4 → Theme B, #6 →
D1, #5 → D2, #8 → D3, #13 → A5, #29/#30 → E1, #3 → E2/C4, #9 → E3, #22/#23/#24 →
E4, #31 → Theme C).

**Next execution checkpoint (2026-07-21):** release 0.1.5 before starting more
semantic behavior. Theme A then runs A0 → A4 → A5 → A2 → A1 → A3. A4 is already
partial: direct `request_new_term` assessment rows carry label, definition, and
namespace, and unresolved shortlist rejection escalates to that decision. The
remaining A4 work is preserving richer rejection metadata and connecting
`semantic_llm_assessments` to the term-request workflow.

---

## Correctness / UX bugs

### 1. `infer_dictionary()` silently drops LLM options when `seed_semantics = FALSE`
- **Severity:** medium · **Status:** confirmed + spot-verified · **Class:** ux-bug
- **Implementation status:** fixed. `infer_dictionary()` now routes through
  `.ms_llm_review_plan()` and warns once before list/data-frame branching when
  LLM semantic options are supplied with `seed_semantics = FALSE`; regression
  coverage lives in `tests/testthat/test-dictionary-helpers.R`.
- **Where:** `R/dictionary-helpers.R:92-100` (gate at `:167`/`:243`) vs `R/package-helpers.R:462-467`.
- `infer_dictionary` defaults to `seed_semantics = FALSE`, computes `llm_requested`
  and validates context (100), but emits **no warning** when LLM options are
  supplied with `seed_semantics = FALSE` — unlike `infer_salmon_datapackage_artifacts`,
  which warns. So `infer_dictionary(df, llm_assess = TRUE)` returns deterministic
  output with no feedback. Same Alice-class surprise the 0.1.4 fix targeted, only
  half-fixed (grep confirms one `"Ignoring LLM semantic options"` string in R/).
- **Fix:** add the warning to `infer_dictionary`, emitted **once at the top of the
  function** (before the list/data.frame branch and the multi-table recursion at
  128-141), via the shared option helper from plan Refactor 2. Add a test; pre-flight
  the suite for `infer_dictionary(... llm_*)` calls lacking `expect_warning`.

### 2. Exploration with skipped reassessment pairs a stale selected-index with a re-sorted candidate set
- **Severity:** medium · **Status:** spot-verified (NEW) · **Class:** correctness-bug
- **Implementation status:** fixed (completed during 2026-06-25 code review).
  Codex's first pass only fixed the *failed-reassessment* branch
  (`R/llm-semantic-helpers.R:1310`); the **no-gain skip branch** (`candidate_gain
  <= 0`, ~`:1305`) still returned the re-sorted `updated_record` with the original
  positional index — reproducing the bug on a narrower path. The code review
  caught this; the skip branch now also returns the original `record`, and a
  dedicated regression test ("no-gain exploration (candidate_gain <= 0) keeps the
  original selected index") covers it alongside the failed-reassessment test.
- **Where:** `R/llm-semantic-helpers.R:1166-1184` (`.ms_llm_explore_record`), with
  `.ms_merge_semantic_target_candidates` (R/semantics-helpers.R) and
  `.ms_semantic_merge_llm_assessments` (R/semantic-suggestions.R:243-268).
- When exploration adds candidates, the merged group is re-sorted by score and
  capped to `max_per_role`, and `.ms_row_order` is reset (1166). If reassessment is
  then skipped — `candidate_gain <= 0`/unchanged keys (1177) or the reassess call
  returns `NA` decision (1182) — the function returns the **re-ordered** record
  paired with the **original** assessment, whose `llm_selected_candidate_index` was
  validated against the *old* ordering. Downstream `llm_selected` is recomputed
  against the new order, so the chosen IRI can be mis-attributed to a different row
  or lost entirely (notably when the selected candidate sat at rank 4-5 with default
  `top_n = 5` but `max_per_role = 3` caps it out).
- **Impact:** an accepted ontology match silently flagged on the wrong candidate or
  dropped, after a failed/no-gain exploration pass. Narrow reach (exploration must
  fire and reassessment be skipped).
- **Fix:** key `llm_selected` on the selected candidate's stable `source::iri`
  rather than a positional index; or on skip, return the original (pre-merge) record
  with the original assessment so index and ordering stay aligned.

### 3. Duplicated, divergent HTTP chat request builders
- **Severity:** medium · **Status:** confirmed · **Class:** correctness-bug (drift)
- **Implementation status:** open/deferred. R4 intentionally deepened the
  response adapter while preserving the two current response shapes. Converging
  `.ms_llm_chat_json_request()` and `.ms_chat_http_request()` is a separate
  request-builder refactor because it would change the adapter shape decision.
- **Where:** `.ms_llm_chat_json_request` (R/llm-semantic-helpers.R:1301-1330) vs
  `.ms_chat_http_request` (R/chat-decomposition.R:435-472).
- Two near-identical httr2 `/chat/completions` builders with **divergent** behavior:
  the semantic one applies `.ms_llm_build_chat_request_body` (temperature /
  reasoning-effort / GPT-5 omit-temperature) and returns a bare list; the chat one
  hardcodes temperature and returns `list(content, data, raw)`. OpenRouter headers
  are duplicated. This divergence is *why* the review adapter needs a two-shape
  normalizer.
- **Fix:** extract a shared chat request builder. NOTE: doing so is **mutually
  exclusive** with keeping the adapter's dual-shape normalizer — track as its own
  refactor, not inside plan R4 (see plan Missing/Future #2).

### 4. `create_sdp(include_edh_xml = TRUE)` writes EDH XML bypassing the unreviewed-rebuild guard
- **Severity:** low-medium · **Status:** finder-verified (NEW; likely intended) · **Class:** ux-bug
- **Implementation status:** fixed (2026-06-26, roadmap B1). `create_sdp()` still
  writes create-time EDH XML, but now reuses `.ms_collect_edh_review_state_issues()`
  and emits a "DRAFT EDH" warning (pointing to `write_edh_xml_from_sdp()`) when
  `REVIEW:`/`MISSING` markers remain. Decision: draft marker, not a hard guard
  (create-time output is inherently review-ready). Test in `test-package-helpers.R`.
- **Where:** `R/package-helpers.R:951-960` vs `R/edh-xml-export.R:1176-1200, 1270`
  (`.ms_abort_unreviewed_edh_rebuild`).
- `write_edh_xml_from_sdp` refuses to build when `REVIEW:` IRIs or `MISSING`
  placeholders remain. `create_sdp`'s inline `include_edh_xml` path calls
  `edh_build_hnap_xml` directly on `artifacts$dataset_meta` with **no** such guard,
  at a stage where `dataset_meta` routinely still has `MISSING METADATA` placeholders.
  So first-write XML can be emitted from unreviewed metadata while a later rebuild of
  the same package is refused.
- **Fix:** document that create_sdp-time EDH XML is a draft, or route it through a
  shared builder that stamps/blocks when placeholders/REVIEW markers are present.

### 5. `chunk_id` / source-label collisions for context files sharing a basename
- **Severity:** low · **Status:** confirmed · **Class:** architectural-smell
- **Implementation status:** fixed (2026-06-26, roadmap D2).
  `.ms_unique_context_sources()` disambiguates colliding basenames (parent dir, then
  a numeric suffix) inside `.ms_collect_context_chunks()`; unique labels are left
  untouched so the observable `llm_context_sources` contract is preserved. Test in
  `test-llm-semantic-helpers.R`.
- **Where:** `R/llm-semantic-helpers.R:530, 549-551, 619`; consumed at
  `R/llm-review-adapter.R:112`.
- `source = basename(normalizePath(path))` and `chunk_id = paste0(source, "#", i)`.
  Two files with the same basename in different dirs collide, and the user-visible
  `llm_context_sources` column (`unique(source)`) merges them.
- **Fix:** disambiguate colliding basenames; relevant because the plan promises to
  "preserve source reporting exactly."

### 6. Encoding mismatch can corrupt non-UTF-8 context files
- **Severity:** low · **Status:** confirmed · **Class:** architectural-smell
- **Implementation status:** fixed (2026-06-26, roadmap D1). `.ms_read_text_utf8()`
  reads the main plain-text/CSV path as UTF-8, detects invalid UTF-8 via
  `validUTF8()`, and falls back to Windows-1252/Latin-1 decoding. Test in
  `test-llm-semantic-helpers.R`. (The `.Rmd`/`.qmd`/HTML readers still assume UTF-8
  — they are normally UTF-8 authored.)
- **Where:** `R/llm-semantic-helpers.R:376, 518, 521`. `readLines(..., encoding = "UTF-8")`
  then `enc2utf8` for non-UTF-8 inputs (e.g. Latin-1 CSVs) corrupts tokens and
  degrades scoring. **Fix:** detect/allow encoding in one place.

### 7. Provider truncation reported as a generic null-response abort
- **Severity:** low · **Status:** confirmed · **Class:** ux-bug
- **Implementation status:** fixed. The review adapter now includes a sanitized
  content snippet when wrapped chat content is malformed and parsed `data` is not
  available; tests also assert parsed `data` wins over malformed `content`.
- **Where:** `R/llm-review-adapter.R:8-16`. When `data` is NULL and `content` is
  non-JSON (truncated/streamed), `fromJSON` fails in a `tryCatch`→NULL and the
  function aborts with a generic message, discarding the raw content. **Fix:**
  surface a content snippet; assert in malformed-response tests for both consumers.

### 8. `semantic_code_scope = "factor"` semi-join omits `dataset_id`
- **Severity:** low · **Status:** finder-verified (NEW; latent) · **Class:** correctness-bug (latent)
- **Implementation status:** fixed (2026-06-26, roadmap D3).
  `.ms_factor_code_keys()` / `.ms_select_semantic_seed_codes()` now thread
  `dataset_id` and join on `c("dataset_id","table_id","column_name")` when present
  (no behavior change on the single-dataset path). Test in `test-package-helpers.R`.
- **Where:** `R/package-helpers.R:2554` (`.ms_select_semantic_seed_codes` semi-join by
  `c("table_id","column_name")`); `.ms_factor_code_keys` (2200-2219).
- Safe today (single uniform `dataset_id` per run), but if `seed_codes` ever span
  multiple datasets with colliding `table_id`/`column_name`, factor-scope selection
  cross-matches across datasets. **Fix:** include `dataset_id` in the key when present.

### 9. `CLAUDE.md` / `AGENTS.md` circular self-reference
- **Severity:** low (repo hygiene) · **Status:** spot-verified · **Class:** ux-bug
- **Implementation status:** fixed (2026-06-26, roadmap E3). `AGENTS.md` now holds
  real agent/contributor guidance (non-negotiable contracts, build/test/doc
  commands, gotchas, planning pointers) seeded from `notes/context.md`; `CLAUDE.md`
  imports it via `@AGENTS.md`. The generated `docs/AGENTS.html`/`docs/CLAUDE.html`
  are git-ignored, so nothing leaks to the public pkgdown site.
- Both files contain only `@AGENTS.md`; `AGENTS.md` references itself → no agent
  guidance ships, and the include is circular. **Fix:** seed real `AGENTS.md` from
  `notes/context.md` (LLM opt-in contract, attribute/IRI-prefix contracts, commands).

---

## LLM-review robustness (new finder bugs, low severity)

These are batch/exploration robustness gaps. Output correctness is preserved
(fallbacks exist) but behavior is poor. **Status: finder-verified, unverified by the
adversarial pass** — re-confirm before fixing.

### 10. Batch system prompt omits `reject_shortlist` from allowed decisions
- **Implementation status:** fixed. Generic, decomposition, and batch prompts now
  list `reject_shortlist` consistently with the validator.
- `R/llm-semantic-helpers.R:891` lists only `accept, review, retry_search,
  request_new_term`, but the validator (`:1338`) also accepts `reject_shortlist`.
  In batched review the model is never told it may reject → behavior diverges from
  the single-target path. **Fix:** add `reject_shortlist` to the batch prompt.

### 11. One malformed batch item aborts and discards all valid assessments
- **Implementation status:** fixed. Batch validation now catches malformed items
  per target key, preserves valid sibling rows, and falls back only affected keys
  to per-target review.
- `R/llm-semantic-helpers.R:1483-1500` calls `.ms_validate_llm_assessment` per item,
  which **aborts** (not warns) on a single bad confidence/decision; the abort voids
  the whole batch and forces a full per-target re-run (1520-1530), doubling requests.
  **Fix:** `tryCatch` per item, treat a bad item as a missing key so only it falls back.

### 12. Duplicate `target_key` in a batch response silently overwrites
- **Implementation status:** fixed. Duplicate target keys are detected and the
  affected key is routed to fallback review instead of silently overwriting the
  first assessment.
- `R/llm-semantic-helpers.R:1483-1490` writes `rows[[key]] <- ...` without checking
  for an existing key; a model echoing a duplicate key silently drops the first.
  **Fix:** detect already-assigned keys; warn/fall back for the affected key.

### 13. `retry_search` can re-issue the original failing query
- **Implementation status:** open/deferred. The branch preserved the current
  exploration fallback behavior; recording rejected duplicate retry queries or
  honoring near-duplicates belongs with the retrieval-gap roadmap.
- `R/llm-semantic-helpers.R:1089-1098, 1129-1138`: if the model's `retry_query`
  equals the original, validation drops it and the code silently falls through to a
  generic exploration request — the explicit `retry_query` has no effect and an extra
  round-trip is spent. **Fix:** record the rejection; consider honoring near-duplicates.

---

## Architectural smells (the duplication driving the refactors)

Correctness-neutral today; drift risks. Cross-referenced to plan refactors R1–R5.

### 14. Triplicated 11-arg `llm_*` forwarding tail  → R2
- **Status:** confirmed (count corrected). The conditional 11-arg `llm_*` block is
  verbatim at **three** sites: `R/dictionary-helpers.R:180-193`, `:256-269`, and
  `R/package-helpers.R:551-564`. **Correction:** the earlier "quadruple duplication"
  framing was wrong — `create_sdp:831-855` is an *unconditional full ~21-arg
  pass-through* of the whole artifact surface, **not** a copy of the 11-arg LLM tail.
- **Implementation status:** fixed. The conditional LLM tail now lives in
  `.ms_llm_review_plan()`, while caller-specific base `suggest_args` remain owned
  by each public entry point.

### 15. `llm_requested` 8-clause predicate duplicated  → R2
- **Status:** confirmed. Byte-identical at `R/dictionary-helpers.R:92-99` and
  `R/package-helpers.R:452-459`.
- **Implementation status:** fixed. The predicate is centralized in
  `.ms_llm_review_requested()` and consumed through `.ms_llm_review_plan()`.

### 16. Divergent column-target builders  → R3
- **Status:** confirmed (re-characterized). `.ms_semantic_column_term_target_from_dictionary`
  (R/semantic-suggestions.R:147-185) and the inline block (R/semantics-helpers.R:966-984)
  are **divergent, not duplicates**: the inline block expands all six I-ADOPT roles
  and sets `target_sdp_field = col_name`; the standalone hardcodes a single
  variable/`term_iri` row and computes `target_query_basis/context` the inline block
  leaves NA. The standalone is currently only a **fallback** inside
  `.ms_semantic_target_from_candidate_rows` (197-201) when retrieval is empty.
  **Fix:** reconcile deliberately — do not blindly "collapse."
- **Implementation status:** done-for-plan. Full semantic target discovery moved
  into `.ms_semantic_discover_targets()` with direct tests for all SDP scopes.
  The narrow candidate-row fallback remains intentionally separate and documented
  rather than collapsed into the six-role discovery path.

### 17. Divergent `infer_dictionary` attribute schemes  → R5
- **Status:** confirmed. Multi-table attaches `inferred_*` unconditionally (196-199,
  tested at test-dictionary-helpers.R:308-311); single-table attaches `seed_*` only
  when args non-NULL (272-280). Disjoint sets. Both are contract.
- **Implementation status:** done-for-plan. R5 preserved both public attribute
  schemes and added tests pinning the single-table `seed_*` contract and absence
  of multi-table `inferred_*` attributes.

### 18. `include_dwc` inconsistency in `suggest_semantics` arg assembly  → R2
- **Status:** confirmed. `R/package-helpers.R:546` sets `include_dwc = FALSE`; both
  dictionary base lists omit it (rely on default). Centralizing must **preserve
  per-caller behavior**, not unify (it would be a behavior change).
- **Implementation status:** fixed. `.ms_llm_review_plan()` centralizes only the
  conditional LLM tail; caller-specific base arguments, including artifact-path
  `include_dwc = FALSE`, remain local.

### 19. Implicit/positional 19-col target-row contract  → R3
- **Status:** confirmed. Builders hand-write column lists instead of constructing from
  `.ms_semantic_target_cols()`; retrieval copies via `intersect(...)` so an omitted
  column drops silently (R/semantics-helpers.R:106-109).
- **Implementation status:** done-for-plan. The target row column order is now
  frozen by tests, and `.ms_semantic_discover_targets()` returns normalized rows
  across column/code/table/dataset scopes. This reduces silent-drift risk; it does
  not remove every positional read in downstream consumers.

### 20. Thin pass-through wrappers add a file-hop  → R4
- **Status:** confirmed (nuance). `.ms_empty_llm_assessment` is pass-through, but
  `.ms_llm_success_assessment` (R/llm-semantic-helpers.R:1415-1423) **unpacks the
  record struct** — inlining must move record-unpacking or keep a positional adapter
  signature.
- **Implementation status:** fixed. The thin semantic wrappers were removed;
  orchestration now calls adapter row builders directly while record unpacking
  stays outside the adapter.

### 21. `table_meta`/`dataset_meta` targets emit extra columns  → R3
- **Status:** confirmed. Table targets add `target_query_basis/context` (1063-1064);
  column/code/dataset omit them (NA-backfilled at 1109). Preserve the backfill.
- **Implementation status:** done-for-plan. R3 preserved the backfilled canonical
  target-column shape and added target-discovery tests covering table and dataset
  target rows.

### 22. Merge helper drops a `.ms_bundle_key` it never created  → R3/R4
- **Status:** confirmed. `.ms_semantic_merge_llm_assessments` (R/semantic-suggestions.R:251-267)
  drops `.ms_bundle_key` via `any_of` though it never creates it — a copy-from-the-inline-pipeline smell.
- **Implementation status:** open. The harmless defensive drop remains; removing
  it was not required for the R3/R4 behavioral work.

### 23. Multi-table recursion forwards the un-widened shortlist  → R2/R5
- **Status:** confirmed (latent). `R/dictionary-helpers.R:136` passes
  `semantic_max_per_role`, not `semantic_seed_max_per_role`. Harmless today (children
  force `seed_semantics = FALSE`) but a trap if seeding ever moves into the recursion.
- **Implementation status:** open latent. R5 moved resource-dictionary inference
  behind `.ms_infer_resource_dictionary()` but preserved child calls with
  `seed_semantics = FALSE`; if semantic seeding later moves into child recursion,
  this needs to be revisited.

### 24. Decomposition mode disables batching for the whole group
- **Status:** by-design (perf note). `any(record$decomposition_mode)` at
  `R/llm-semantic-helpers.R:1503` forces per-target review. Correct; a quiet perf
  cliff worth a debug log.
- **Implementation status:** open/by-design. No debug log was added in this
  branch.

---

## Reclassified as by-design (not bugs)

- **Positional `[[1]]` row access throughout discovery closures** (R/semantics-helpers.R:425-942)
  — intended single-row tibble contract; refactor-sensitive but not a defect.
- **Normalizer "masks" shape drift between discovery blocks** (R/semantics-helpers.R:1109)
  — the NA backfill is the intended mechanism; the inconsistent per-builder column
  sets (#21) are the smell, not the backfill.

---

## Test / infra improvements (evidence-cited; unverified by the adversarial pass)

### 25. White-box parse-once test couples to internal helper names slated for relocation
- **Implementation status:** fixed for current refactor. The parse-once invariant
  now flows through an explicit `context_chunk_pool`, and tests were updated to
  exercise that pool rather than relying on implicit reparsing.
- `tests/testthat/test-llm-semantic-helpers.R:1100-1136` mocks
  `.ms_context_text_from_file` and `.ms_chunk_context_text` by name. Plan R1's
  wrapper-deletion step breaks this unless the symbols survive or the test is
  rewritten through the new seam first.

### 26. Network-gated tests weaken the validation ladder
- **Implementation status:** partially addressed. Release validation now includes
  the full test suite and a standard `R CMD check` with all declared suggested R
  packages installed; the 0.1.5 check finished with `Status: OK`. The
  network-gated tests themselves were not rewritten, so a green offline run still
  does not prove the live services are reachable.
- `tests/testthat/test-validation-helpers.R:80-96` (`fetch_salmon_ontology`, live HEAD
  to w3id.org) and GitHub helpers skip silently offline. Lean R3/R5 gating on
  `test-package-helpers.R` and `test-dictionary-helpers.R`; assert skip-count doesn't
  rise across refactors.

### 27. Massive dictionary-fixture duplication (~30 copies)
- **Implementation status:** fixed for current refactor. Added shared fixtures in
  `tests/testthat/helper-dictionary.R` and migrated ordinary repeated dictionary
  fixtures before R3/R5 changes.
- The canonical dict tibble is copy-pasted across test files. R3/R5 change row/column
  shape, so consolidate into `helper-dictionary.R` **before** those refactors.

### 28. `semantic-suggestions` module under-tested
- **Implementation status:** fixed for current refactor. `test-semantic-suggestions.R`
  now covers semantic target row contracts, target discovery, LLM assessment row
  contracts, and review-adapter robustness cases.
- `tests/testthat/test-semantic-suggestions.R` has only 2 `test_that` blocks despite
  being the destination for R3's target rows and a consumer in R4.

### 32. Display-only vignettes are tangled and executed by `R CMD check`
- **Severity:** low-medium · **Status:** confirmed · **Class:** test-infra bug
- **Implementation status:** fixed (2026-07-21, roadmap E5). Every display-only
  chunk in the six affected vignettes now declares `purl = FALSE` in its chunk
  header. A focused `knitr::purl()` validation found zero executable lines, and
  `R CMD check metasalmon_0.1.5.tar.gz` completed with `Status: OK` while pkgdown
  continued to render the examples.
- A global runtime `knitr::opts_chunk$set(eval = FALSE, purl = FALSE)` is
  insufficient because the check's tangle phase does not execute the setup chunk.
  Without per-chunk metadata it tried to run credential, network, and local-file
  examples that were intended only for display.

---

## Larger opportunities (future refactors, not the current plan)

### 29. `package-helpers.R` is a ~2975-line god-file
- **Implementation status:** partially addressed. R5 created
  `R/artifact-inference.R` and moved package artifact inference context there.
  `package-helpers.R` remains large and still owns writing, reading, validation,
  `create_sdp()`, and EDH post-processing.
- Mixes `write_salmon_datapackage` (53), `infer_salmon_datapackage_artifacts` (427),
  `create_sdp` (712), `read_salmon_datapackage` (1008), `validate_salmon_datapackage`
  (1292), and a composite-hint cluster (1955-2490). **Recommendation:** land plan R5's
  orchestration extraction in a *new* file (e.g. `R/artifact-inference.R`) to capture
  the Locality win instead of deepening inside the god-file.

### 30. `infer_*_from_resources` defined in `dictionary-helpers.R` but core to the package path
- **Implementation status:** partially addressed/open. The package path now uses
  the new artifact-inference helper for orchestration, but the exported/resource
  inference helpers themselves still live in `dictionary-helpers.R`.
- Defined at `R/dictionary-helpers.R:442-629`, consumed by
  `infer_salmon_datapackage_artifacts` (package-helpers.R:508-525). Misplaced
  ownership — part of R5's case.

### 31. Chat session-engine / request-builder convergence (i-adopt roadmap)
- **Implementation status:** open/deferred. R4 hardened the shared response
  validation seam only; request-builder/session-engine convergence remains a
  separate roadmap item.
- `chat-decomposition.R` (~1346 lines) duplicates request/provider logic with the
  semantic path (#3). The i-adopt roadmap wants decomposition to be one mode in a
  shared curation engine; converging the request builders is the request-side half of
  that (R4 only unifies the response-validation seam).

---

## Code review of the implementation (2026-06-25)

A `/code-review` of Codex's implementation surfaced 10 findings (one confirmed
correctness bug + cleanup/test/altitude items). Resolved on this branch (full
suite green: 1281 pass / 0 fail):

- **Confirmed correctness (the bug #2 fix was only half-applied):** the no-gain
  exploration *skip* branch still returned a re-sorted shortlist paired with the
  original positional selected index. Fixed (returns the original record) +
  regression test. See item #2 above.
- **Dead context params:** removed the now-unused `context_files`/`context_text`
  from `.ms_prepare_context_chunks`, `.ms_llm_prepare_record`, and
  `.ms_llm_explore_record` (the pre-collected chunk pool is the sole input).
- **Silent column drop:** `.ms_semantic_discover_targets` now fails loud on any
  column outside the target-row contract instead of quietly subsetting it away.
- **DRY LLM arg surface:** the duplicate suggest-args identity helper was replaced
  by one canonical `.ms_llm_arg_names()` collected via `mget()` in
  `.ms_llm_review_plan()`, so the arg names live in exactly one place.
- **Batch fallback observability:** the per-key fallback *reasons* are now
  surfaced in the warning (not just the keys), and duplicate-key handling no
  longer clobbers a more specific first-occurrence reason.
- **`reject_shortlist` now has distinct behaviour:** a rejected shortlist that
  exploration cannot resolve escalates to `request_new_term`
  (`.ms_llm_escalate_unresolved_rejection`), surfacing the likely ontology gap;
  the distinct `llm_decision` is preserved through the batch/validator layers.
  Regression test added.
- **Tests + docs:** added dep-free four-scope (`target_sdp_file`) discovery
  coverage and a value-level LLM row-contract assertion; documented the
  intentional `inferred_*` return-slot naming and the deliberately divergent local
  `first_non_empty()` helper.

Deferred (unchanged): the open/deferred items in the snapshot above —
request-builder convergence (#31/#3), encoding detection (#6), create-time EDH XML
guard (#4), basename source disambiguation (#5), factor-scope `dataset_id` key
(#8), and real `AGENTS.md` content (#9).
