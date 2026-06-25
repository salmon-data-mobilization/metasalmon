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

---

## Correctness / UX bugs

### 1. `infer_dictionary()` silently drops LLM options when `seed_semantics = FALSE`
- **Severity:** medium · **Status:** confirmed + spot-verified · **Class:** ux-bug
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
- **Where:** `R/llm-semantic-helpers.R:530, 549-551, 619`; consumed at
  `R/llm-review-adapter.R:112`.
- `source = basename(normalizePath(path))` and `chunk_id = paste0(source, "#", i)`.
  Two files with the same basename in different dirs collide, and the user-visible
  `llm_context_sources` column (`unique(source)`) merges them.
- **Fix:** disambiguate colliding basenames; relevant because the plan promises to
  "preserve source reporting exactly."

### 6. Encoding mismatch can corrupt non-UTF-8 context files
- **Severity:** low · **Status:** confirmed · **Class:** architectural-smell
- **Where:** `R/llm-semantic-helpers.R:376, 518, 521`. `readLines(..., encoding = "UTF-8")`
  then `enc2utf8` for non-UTF-8 inputs (e.g. Latin-1 CSVs) corrupts tokens and
  degrades scoring. **Fix:** detect/allow encoding in one place.

### 7. Provider truncation reported as a generic null-response abort
- **Severity:** low · **Status:** confirmed · **Class:** ux-bug
- **Where:** `R/llm-review-adapter.R:8-16`. When `data` is NULL and `content` is
  non-JSON (truncated/streamed), `fromJSON` fails in a `tryCatch`→NULL and the
  function aborts with a generic message, discarding the raw content. **Fix:**
  surface a content snippet; assert in malformed-response tests for both consumers.

### 8. `semantic_code_scope = "factor"` semi-join omits `dataset_id`
- **Severity:** low · **Status:** finder-verified (NEW; latent) · **Class:** correctness-bug (latent)
- **Where:** `R/package-helpers.R:2554` (`.ms_select_semantic_seed_codes` semi-join by
  `c("table_id","column_name")`); `.ms_factor_code_keys` (2200-2219).
- Safe today (single uniform `dataset_id` per run), but if `seed_codes` ever span
  multiple datasets with colliding `table_id`/`column_name`, factor-scope selection
  cross-matches across datasets. **Fix:** include `dataset_id` in the key when present.

### 9. `CLAUDE.md` / `AGENTS.md` circular self-reference
- **Severity:** low (repo hygiene) · **Status:** spot-verified · **Class:** ux-bug
- Both files contain only `@AGENTS.md`; `AGENTS.md` references itself → no agent
  guidance ships, and the include is circular. **Fix:** seed real `AGENTS.md` from
  `notes/context.md` (LLM opt-in contract, attribute/IRI-prefix contracts, commands).

---

## LLM-review robustness (new finder bugs, low severity)

These are batch/exploration robustness gaps. Output correctness is preserved
(fallbacks exist) but behavior is poor. **Status: finder-verified, unverified by the
adversarial pass** — re-confirm before fixing.

### 10. Batch system prompt omits `reject_shortlist` from allowed decisions
- `R/llm-semantic-helpers.R:891` lists only `accept, review, retry_search,
  request_new_term`, but the validator (`:1338`) also accepts `reject_shortlist`.
  In batched review the model is never told it may reject → behavior diverges from
  the single-target path. **Fix:** add `reject_shortlist` to the batch prompt.

### 11. One malformed batch item aborts and discards all valid assessments
- `R/llm-semantic-helpers.R:1483-1500` calls `.ms_validate_llm_assessment` per item,
  which **aborts** (not warns) on a single bad confidence/decision; the abort voids
  the whole batch and forces a full per-target re-run (1520-1530), doubling requests.
  **Fix:** `tryCatch` per item, treat a bad item as a missing key so only it falls back.

### 12. Duplicate `target_key` in a batch response silently overwrites
- `R/llm-semantic-helpers.R:1483-1490` writes `rows[[key]] <- ...` without checking
  for an existing key; a model echoing a duplicate key silently drops the first.
  **Fix:** detect already-assigned keys; warn/fall back for the affected key.

### 13. `retry_search` can re-issue the original failing query
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

### 15. `llm_requested` 8-clause predicate duplicated  → R2
- **Status:** confirmed. Byte-identical at `R/dictionary-helpers.R:92-99` and
  `R/package-helpers.R:452-459`.

### 16. Divergent column-target builders  → R3
- **Status:** confirmed (re-characterized). `.ms_semantic_column_term_target_from_dictionary`
  (R/semantic-suggestions.R:147-185) and the inline block (R/semantics-helpers.R:966-984)
  are **divergent, not duplicates**: the inline block expands all six I-ADOPT roles
  and sets `target_sdp_field = col_name`; the standalone hardcodes a single
  variable/`term_iri` row and computes `target_query_basis/context` the inline block
  leaves NA. The standalone is currently only a **fallback** inside
  `.ms_semantic_target_from_candidate_rows` (197-201) when retrieval is empty.
  **Fix:** reconcile deliberately — do not blindly "collapse."

### 17. Divergent `infer_dictionary` attribute schemes  → R5
- **Status:** confirmed. Multi-table attaches `inferred_*` unconditionally (196-199,
  tested at test-dictionary-helpers.R:308-311); single-table attaches `seed_*` only
  when args non-NULL (272-280). Disjoint sets. Both are contract.

### 18. `include_dwc` inconsistency in `suggest_semantics` arg assembly  → R2
- **Status:** confirmed. `R/package-helpers.R:546` sets `include_dwc = FALSE`; both
  dictionary base lists omit it (rely on default). Centralizing must **preserve
  per-caller behavior**, not unify (it would be a behavior change).

### 19. Implicit/positional 19-col target-row contract  → R3
- **Status:** confirmed. Builders hand-write column lists instead of constructing from
  `.ms_semantic_target_cols()`; retrieval copies via `intersect(...)` so an omitted
  column drops silently (R/semantics-helpers.R:106-109).

### 20. Thin pass-through wrappers add a file-hop  → R4
- **Status:** confirmed (nuance). `.ms_empty_llm_assessment` is pass-through, but
  `.ms_llm_success_assessment` (R/llm-semantic-helpers.R:1415-1423) **unpacks the
  record struct** — inlining must move record-unpacking or keep a positional adapter
  signature.

### 21. `table_meta`/`dataset_meta` targets emit extra columns  → R3
- **Status:** confirmed. Table targets add `target_query_basis/context` (1063-1064);
  column/code/dataset omit them (NA-backfilled at 1109). Preserve the backfill.

### 22. Merge helper drops a `.ms_bundle_key` it never created  → R3/R4
- **Status:** confirmed. `.ms_semantic_merge_llm_assessments` (R/semantic-suggestions.R:251-267)
  drops `.ms_bundle_key` via `any_of` though it never creates it — a copy-from-the-inline-pipeline smell.

### 23. Multi-table recursion forwards the un-widened shortlist  → R2/R5
- **Status:** confirmed (latent). `R/dictionary-helpers.R:136` passes
  `semantic_max_per_role`, not `semantic_seed_max_per_role`. Harmless today (children
  force `seed_semantics = FALSE`) but a trap if seeding ever moves into the recursion.

### 24. Decomposition mode disables batching for the whole group
- **Status:** by-design (perf note). `any(record$decomposition_mode)` at
  `R/llm-semantic-helpers.R:1503` forces per-target review. Correct; a quiet perf
  cliff worth a debug log.

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
- `tests/testthat/test-llm-semantic-helpers.R:1100-1136` mocks
  `.ms_context_text_from_file` and `.ms_chunk_context_text` by name. Plan R1's
  wrapper-deletion step breaks this unless the symbols survive or the test is
  rewritten through the new seam first.

### 26. Network-gated tests weaken the validation ladder
- `tests/testthat/test-validation-helpers.R:80-96` (`fetch_salmon_ontology`, live HEAD
  to w3id.org) and GitHub helpers skip silently offline. Lean R3/R5 gating on
  `test-package-helpers.R` and `test-dictionary-helpers.R`; assert skip-count doesn't
  rise across refactors.

### 27. Massive dictionary-fixture duplication (~30 copies)
- The canonical dict tibble is copy-pasted across test files. R3/R5 change row/column
  shape, so consolidate into `helper-dictionary.R` **before** those refactors.

### 28. `semantic-suggestions` module under-tested
- `tests/testthat/test-semantic-suggestions.R` has only 2 `test_that` blocks despite
  being the destination for R3's target rows and a consumer in R4.

---

## Larger opportunities (future refactors, not the current plan)

### 29. `package-helpers.R` is a ~2975-line god-file
- Mixes `write_salmon_datapackage` (53), `infer_salmon_datapackage_artifacts` (427),
  `create_sdp` (712), `read_salmon_datapackage` (1008), `validate_salmon_datapackage`
  (1292), and a composite-hint cluster (1955-2490). **Recommendation:** land plan R5's
  orchestration extraction in a *new* file (e.g. `R/artifact-inference.R`) to capture
  the Locality win instead of deepening inside the god-file.

### 30. `infer_*_from_resources` defined in `dictionary-helpers.R` but core to the package path
- Defined at `R/dictionary-helpers.R:442-629`, consumed by
  `infer_salmon_datapackage_artifacts` (package-helpers.R:508-525). Misplaced
  ownership — part of R5's case.

### 31. Chat session-engine / request-builder convergence (i-adopt roadmap)
- `chat-decomposition.R` (~1346 lines) duplicates request/provider logic with the
  semantic path (#3). The i-adopt roadmap wants decomposition to be one mode in a
  shared curation engine; converging the request builders is the request-side half of
  that (R4 only unifies the response-validation seam).
