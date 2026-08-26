---
type: InformationObject
title: "Bugs and improvements backlog"
description: "Live index of every known metasalmon defect and improvement, with file:line evidence and verification status. Ordering lives in the roadmap card; severity lives here."
status: draft
tags: [backlog, defects]
psc:
  id: metasalmon:backlog
  contexts: [metasalmon:context:hub-coordination]
---

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

**Implementation status legend (updated 2026-07-28 on `feature/theme-a-semantic-review`)**
- **fixed** — implemented on this branch and covered by focused tests.
- **done-for-plan** — the refactor-plan objective was completed, but a broader
  future improvement may remain.
- **partially addressed** — risk was reduced or documented, but the underlying
  backlog item is not exhausted.
- **open** — still present in the codebase.
- **deferred** — deliberately left out of the current refactor because it belongs
  to a separate roadmap or would change behavior beyond the plan.

**Current snapshot (re-audited 2026-08-21 against `main` and the sibling repos).**

- **Closed:** #1, #2, #4, #5, #6, #7, #8, #10, #11, #12, #14, #15, #16, #17, #18,
  #19, #20, #21, #25, #27, #28, #32, #34–#42 (the 0.2.0 P0 remediation), and
  #64–#71 (defects in the 0.2.0 fixes themselves, caught in PR #11 review).
- **Closed with a correction to a previously wrong marker:** #9 and #33 — both
  had been marked fixed but were not verifiable from a clean clone. See each item.
- **Partially addressed:** #26, #29, #30.
- **Open:** #3, #13, #22, #23, #24, #31, #44, #48, #49, #53, #55–#61, #78, #80, #82, #83, #86, #87, **#89**, **#90** (ruled 2026-08-24,
  the spec-repo change is unwritten),
  and **#95**, **#103–#108**, **#111**, **#112**, **#113**, **#114** (both
  ruled 2026-08-24 and both unimplemented) and **#115**, **#116**, **#117**
  (all new 2026-08-25), plus
  item 0 (gcdfo), and **#119**, **#120** (both new 2026-08-25). **#74 closed
  2026-08-25** — the whole R-native review and editing flow shipped, and a
  package now reaches strict validation entirely from R; **#60 narrowed** the
  same day (its accessor clause closed, every other clause stands, so it stays
  open above); **#118** filed and fixed the same day. Open only in
  part: **#76** (its crosswalk-retarget half), **#79** (four of its six
  findings shipped with S11 slice 2; the KNB-vignette split and the export
  coverage count remain), and
  **#99** (this repo's dictionary is fixed; metasalmonpy and smn-data-pkg
  still ship the two 404 IRIs).
- **Open and awaiting a decision rather than an implementer:** #87's benchmark
  half, **#115** (which spelling a descriptor `POSIXct` takes — a shared defect
  in both implementations, and ruling on it in one repository only would create
  a parity row instead of closing one), and #106 (which
  reading of "typed as a SOSA Procedure" the spec means, the same undecided
  question as #76's open half). Listing them as plain open items overstates how
  ready they are to pick up. *(#93's items 3–5 were on this list until
  2026-08-24; [Q12](questions.md) ruled, and they are now retired — see
  the Fixed line below.)*
- **Ruled 2026-08-24 (Brett), and therefore now awaiting an implementer rather
  than a decision:** **#90** (permit the I-ADOPT descriptor keys; the spec
  validator learns them — [Q3](questions.md)), which also unblocks **#109**;
  **#113** (one shared package-ownership sentinel, breaking change accepted —
  [Q14](questions.md)); **#114** (adopt `metadata/semantic/**` into the SDP
  specification — [Q11](questions.md)). Each carries its ruling inline. **All
  three land outside this package** — two in `smn-data-pkg`, one in both
  implementations — which is why none of them is in a metasalmon release plan.
- **Fixed by release:** #63 in the 0.2.0 merge; #43 and #62 in 0.2.1; #45, #46
  and #50 in 0.2.2; #47, #51 and #52 in 0.2.3; #54 and #72 in 0.2.4; #73 in
  0.2.5; #77 in 0.2.6. #85, #88 and #94 are fixed in the development version,
  and the 2026-08-21 recon-fix pass (branch
  `fix/2026-08-21-recon-defects`) fixed **#97, #98, #100, #101, #102**, #93
  item 2, #96's destructive trigger, and #99 for this repo's own dictionary.
  **#96 is now fully retired**: its remaining ordering half (unlink before the
  last abortable step) was fixed in the development version on 2026-08-22
  (branch `fix/2026-08-22-abort-safe-write-path`) by making
  `write_salmon_datapackage()` transactional — render everything, then install
  through the atomic write set with rollback — with RED-verified abort-injection
  tests; the adjacent smaller shape it exposed in `create_sdp()`'s sidecars is
  **#111**.
  **#93 is now fully retired** (2026-08-25, branch
  `fix/2026-08-25-q12-date-render`): [Q12](questions.md) ruled *coerce once at
  render time, per type*, items 3 and 5 were fixed through one new
  `.ms_canonical_character()`, and item 4's stated mechanism was traced and
  found unreachable — closed as a finding with a standing agreement test rather
  than as a fix. Both halves of the item's retire condition are met. The
  `POSIXct` shape item 4's trace exposed is **#115**, deliberately not folded
  in.
- **Superseded rather than fixed:** #75 — sdp-0.3.0 deleted both the dictionary
  `method_iri` slot and the `metadata/methods.csv` registry the item was about.
- **Fixed in a sibling repo:** #81 and #84, by gcdfo PR #83 (unreleased — after
  the 0.0.9 tag); **#92**, by metasalmonpy PR #12 (merged 2026-08-21); **#91**,
  by metasalmonpy PR #20 — S10 chunk D, merged 2026-08-22 — which is the whole
  of that item, since #91 never had an R half.

**One number was doing two jobs, and three citations pointed at the ambiguity.**
Two unrelated defects were both filed as **#91**. The
`validate_salmon_datapackage()` issue-system parity gap keeps **#91** — it is
the one this snapshot's Open list always meant. The canonical-date-key defect
is renumbered **#94**. Anything that says "#91" and means year padding means
**#94**: `knowledge/parity-deviations.md` row 40, the release index in
`knowledge/roadmap.md`, and metasalmonpy's `PARITY.md` row 40. Those three
files have other owners and are **not** corrected by this change. The S10
execplan's citation still correctly means #91, and so does the row that was
**row 35 in this file's own text when this note was written** — the hub register
moved it to **41** on 2026-08-21, in the second collision described above, so
read every "row 35 means #91" as **row 41** and note that metasalmonpy's row 35
is the unrelated `integer`-storage decision. *(Corrected 2026-08-22, in the pass
that closed #91.)*

**Next up:** roadmap **S1** (one validation authority, #48/#49) — the last P1,
and the credibility dependency for the workshop. **S3** (KNB environments) had
its R side implemented 2026-08-22 — unreleased, unmirrored, and with no deposit
yet made in either environment. See `knowledge/roadmap.md` for the full
ordering.

**Forward plan.** Sequencing, dependencies, and release state live in
**`knowledge/roadmap.md`** — the single undated document that orders every stream and
links to its execplan. This file stays the live index of *what is wrong*;
the roadmap decides *what order to fix it in*.

Evidence for items #34–#71 is in
`knowledge/plans/2026-08-10-comprehensive-ecosystem-review.md`. The two older
documents that called themselves roadmaps
(`2026-08-10-post-0.2.0-roadmap.md`, `2026-06-26-next-behaviours-roadmap.md`) are
now historical records; the second still holds the Theme A–E design detail.

**How to read this file.** Items #1–#33 came from the 2026-06-24 architecture
review. Items #34+ came from the 2026-08-10 comprehensive review; #72+ were found
during the 0.2.4 work; **#95–#108 came from the 2026-08-21 recon**, which
executed the package's own examples through both validators instead of reading
the code, and carries its evidence inline in each item rather than in a plan.
**#112 came from S10 chunk A's migration differential** (2026-08-22,
metasalmonpy PR #14) — a divergence where the mirror was the internally
consistent side, logged rather than fixed pending a ruling. (#111 was claimed
the same day by the concurrent abort-safe write-path stream for the
`create_sdp()` sidecar shape; the collision was caught pre-merge and each item
keeps the number it committed under.)
**#113 and #114 came from Brett's 2026-08-24 rulings**, not from a defect hunt:
each is work a ruling created an owner for. #113 is the two-sentinel divergence
S10 chunk H registered rather than fixed, now ruled (Q14); #114 is the
`metadata/semantic/**` specification gap Q11 ruled on. Both are filed here
because the ruling needs somewhere to live that an implementer reads — a ruling
recorded only in `questions.md` is an index entry pointing at nothing.
**#115 came out of closing #93 item 4** (2026-08-25): the trace that proved the
item's stated mechanism unreachable found the same *shape* alive under a
different type, in both implementations. It is filed separately rather than
folded in, because #93's retire condition names `Date` and the SSSOM renderer,
and quietly widening a condition an item has already met is how a retired item
comes back without anyone deciding that it should.
Priorities here are severity; *ordering* is decided in
`knowledge/roadmap.md` and the two can differ — #54 was a P2 that shipped before the
remaining P1 because it silently lost user data and was cheap. An item marked **fixed**
should name a check that proves it from a clean clone; #9 is the cautionary
example of what happens otherwise. **A number here is a permanent handle**: an
item is renumbered only to break a collision (#94 is the only case), and the
snapshot records where the old citations point.

**Theme A implementation checkpoint (2026-07-28):** A4, A5, A2, A1, and A3
merged to `main` in PR #5 at `f774673`. The evidence pack (A0) passed its final
independent re-review after the harness was hardened to bind every captured
source artifact directly to the recorded Git commit.
Completed behavior includes:

- 30-column assessment rows with retry-rejection and escalation provenance;
- structured LLM and candidate gaps, conflict detection, and GCDFO routing;
- measurement-column bundle review with per-slot fallback and one retry round;
- strict explicit-source allowlists and omitted role-aware defaults;
- conservative method, constraint, native-type, dimension, and redundancy
  validators;
- a cross-consistent replay/live/compare/promote benchmark and exact-model
  three-run release gate.

Evidence/oracle, bundle architecture, retrieval/source-policy, gap/retry, and
ontology/I-ADOPT checkpoints have independently passed. Pkgdown, the complete
test suite, and `R CMD check` passed before the final review. That review found
additional release blockers in returned-source enforcement, retry call bounds,
chat native types, validator context locality, and evidence lineage. The fixes
and focused regressions are implemented. Re-review additionally caught and fixed
overlapping canonical field names leaking method evidence and explicit per-time
mortality rates being treated as dimensionally ambiguous. A subsequent code pass
also caught weak one-word field anchors and compound flow/speed precedence; those
now have conservative implementations and focused tests. A final adversarial
probe additionally caught suffixed identifiers and malformed compound units;
both are now rejected or left unknown with regression coverage. A markup-prefix
probe then caught the same suffix leak behind Markdown/Rmd bullets and table
markers; markup-aware token extraction now covers those forms without excluding
legitimate numbered-list prose. The final ontology matrix also found spaced and
inverse temporal denominators plus embedded compound-unit overmatching; exact
supported-compound matching and per-value powered/chained guards now cover those
forms, including inverse powers without `/` or `per`. The reviewed matrix is now
frozen for 0.1.6; broader unit algebra is not being added to this release. Final
independent review passed 38/38 frozen dimension cases, 55/55 locality cases,
replay/oracles, evidence lineage/attestation, and release documentation. Fresh
local release validation now passes: offline replay, the complete package suite
(14 expected warning assertions), source build, and `R CMD check` (`Status: OK`).
Remote pull-request and post-merge CI passed. The maintainer explicitly deferred
the exact-model live cohort when merging 0.1.6; issue #6 tracks its authentication
diagnosis and three-run completion. Default tests and CI are isolated from LLM
providers, and live benchmark execution now requires an explicit
billable-network acknowledgement.
The follow-up harness refactor reduced the complete default local suite from
about 38 minutes to 3 minutes 47 seconds; the exhaustive offline evidence tier
passes separately in about 1-2 minutes and runs only for relevant paths,
published releases, or manual dispatch.

---

## 0.2.0 P0 remediation (2026-08-10)

The 2026-08-10 comprehensive review
(`knowledge/plans/2026-08-10-comprehensive-ecosystem-review.md`) produced 96
adversarially-verified findings. The nine ranked P0 are all fixed on
`fix/p0-remediation` and released as 0.2.0; see `NEWS.md` for user-facing detail.

| # | Item | Where |
|---|---|---|
| P0-1 | `zip (== 3.0.1)` blocked installation against CRAN 3.0.2 | `DESCRIPTION` |
| P0-2 | Remote SDP schema loading dead; produced packages declared a rejected profile URI | `R/schema-helpers.R` |
| P0-3 | `.data$x == x` data-mask tautology applied the wrong table's rules | `R/dictionary-helpers.R`, `R/package-helpers.R` |
| P0-4 | `create_sdp()` wrote packages its own validator rejected | `R/package-helpers.R` |
| P0-5 | `read` -> edit -> `write` silently deleted reviewed sidecars | `R/package-helpers.R` |
| P0-6 | External text evaluated as a cli message template | `R/cli-safety.R` + 15 sites |
| P0-7 | Canonical bytes and identifiers depended on `LC_COLLATE` | `R/sssom.R`, `R/knb-publication.R`, others |
| P0-8 | Cancelling the term-request prompt submitted the issue | `R/term-request-helpers.R` |
| P0-9 | gcdfo validation layer inert (verified, fix deferred to the ontology repo) | `knowledge/plans/2026-08-10-gcdfo-validation-layer-verification.md` |

**Deferred from this pass, by decision:** semantic ranking tiebreakers
(`R/semantics-helpers.R:170-211`) break score ties on character keys, so with
`seed_semantics = TRUE` the top-1 pick — which becomes a written IRI in
`column_dictionary.csv` — is not reproducible across machines. Left out of the
P0 sweep deliberately: radix-ing them moves existing semantic-suggestion test
expectations, which would mix a behavioural change into a hardening pass. **This
is the highest-value remaining collation item; pick it up next.**

**Two things this pass revealed about the review process itself:**

1. A green test suite was not the signal it appeared to be. P0-2, P0-4, and the
   three unexecuted `sdp.rules.yaml` rules were all invisible to 21k lines of
   tests, because the suite pins `sdp_schema_source = "vendored"`, never
   round-trips a package through its own validator, and skips network-gated
   tests silently. One existing test in `test-edge-cases.R` was passing *because
   of* P0-3 — its `codes` fixture used `table_id = "table-1"` against a
   dictionary defaulting to `"table_1"`, and only matched because the filter was
   a no-op.
2. Two "fixed" markers in this document were wrong (#9 and #33). Both had been
   fixed in a way nobody could verify from a clean clone.

## Correctness / UX bugs

### 0. gcdfo `docs-widoco` seeds its own baseline, so a failed build goes green over raw output

**Repo:** `dfo-pacific-science/dfo-salmon-ontology`. **UNBLOCKED** — PR #82 has
merged (`06e4db0`), so this is now the next actionable change in that repo.
**Handed to this hub 2026-08-16** by the session that fixed #82 (Brett reversed
the earlier "keep it there" call).

Two things #82 fixed that this item no longer needs to carry: the `docs-widoco`
recipe now has `set -e` (it previously printed a success mark over a crashing
normalizer), and the CI drift gate's
`:(exclude)docs/webvowl/data/ontology.json` is gone, so the artifact is
enforced rather than silently unchecked. Both were cited in `AGENTS.md` as
motivating examples for the guard-expiry rule; the rule stands, the two
instances are closed.

`docs-widoco` copies the working-tree `docs/webvowl/data/ontology.json` to
`release/tmp/webvowl-baseline.json` as the normalizer's baseline, and *then*
`rsync` overwrites that same path with fresh raw WIDOCO output before the
normalizer runs. Now that the recipe fails loudly (new in #82), a failed
build leaves raw bytes in the tree; re-running adopts those raw bytes as the
baseline, the normalizer finds the new raw output semantically equal to them,
restores them, and the build goes **green over un-normalized output**. That
self-perpetuation is what kept the whole placebo alive. Not a regression from
#82 — it predates it; #82 only makes it reachable more often by failing where
it used to silently continue.

**Fix:** source the baseline from git instead of the working tree.
`scripts/normalize_webvowl_json.py` already implements this as
`load_git_head_text()` and uses it as its fallback when `--baseline` is
absent; the Makefile currently overrides it with the working-tree snapshot,
so the simplest change is to stop passing `--baseline` from `docs-widoco`.
**The "verify first" question is answered** (gcdfo `docs/tech-debt.md`,
2026-08-16 entry, written after this item): the working-tree baseline *was*
deliberate, so repeated local refreshes compare against the previous local run
rather than the last commit. That is the property the fix trades away, and it
is the thing to decide, not to discover.

**Blast radius is smaller than this item first said, and that is what changed.**
Now that PR #82 removed the CI exclusion, the drift check covers
`docs/webvowl/data/ontology.json`, and CI checks out clean, so its baseline is
always the committed file. Raw output pushed from a poisoned *local* baseline
fails CI. The workaround is one command —
`git checkout -- docs/webvowl/data/ontology.json` before retrying a failed docs
build. Severity is local developer friction, not a silent publication defect.

**The test that matters** is not a clean build, and it has a trap. Break the
normalizer deliberately, run `make docs-widoco` so it fails and leaves raw
output in the tree — then **repair the normalizer while leaving that dirty
`ontology.json` in place**, and re-run. The second run must not go green over
the raw bytes. Skipping the repair step makes the second run fail for the
trivial reason that the normalizer is still broken, which proves nothing and
would pass identically against the unfixed self-seeding implementation. A clean
`make ci` twice with `SMN_FLAT_TTL` pointed at a path that does not
exist (that is how the repo's own CI forces the pinned-fetch route rather
than a local sibling checkout), expecting a byte-identical
`ontology.json`; sha256 `4d350546…` on main's pin `a5d4f28`) is necessary but
not sufficient.

**Retire when:** the fix ships — and retire the matching
`docs/tech-debt.md` "Active Technical Debt" entry dated 2026-08-16 in that
repo at the same time.


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
- **Implementation status:** fixed 2026-06-26 in a *working copy only*; genuinely
  fixed 2026-08-10. The 2026-06-26 pass wrote real guidance into `AGENTS.md`, but
  `.gitignore` listed `AGENTS.md` and `CLAUDE.md`, so neither file was ever
  committed and the shipped repo still carried no contributor guidance — the exact
  symptom this item describes. The ignore entries are removed as of 0.2.0 and both
  files are tracked; both remain in `.Rbuildignore`, so the built package is
  unaffected, and the generated `docs/AGENTS.html`/`docs/CLAUDE.html` stay ignored.
  **Lesson for this document:** a "fixed" marker that nobody can verify from a
  clean clone is worse than an open item. Prefer claims a CI check can assert
  (here: `git ls-files AGENTS.md` is non-empty).
- Both files contain only `@AGENTS.md`; `AGENTS.md` references itself → no agent
  guidance ships, and the include is circular. **Fix:** seed real `AGENTS.md` from
  `knowledge/orientation.md` (LLM opt-in contract, attribute/IRI-prefix contracts, commands).

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
- **Implementation status:** fixed on `feature/theme-a-semantic-review`.
  Case/whitespace-normalized exact duplicates preserve `retry_search` and the
  original query, record `duplicate_original_query`, and skip query generation,
  retrieval, and reassessment for that slot. Identifier-like duplicates are
  classified before identifier fallback; near-duplicates remain eligible.
- `R/llm-semantic-helpers.R:1089-1098, 1129-1138`: if the model's `retry_query`
  equals the original, validation drops it and the code silently falls through to a
  generic exploration request — the explicit `retry_query` has no effect and an extra
  round-trip is spent. **Fix:** record the rejection; consider honoring near-duplicates.

### 33. Canonical project and runtime URLs point to the former organization
- **Severity:** medium · **Status:** spot-verified · **Class:** reliability/ux-bug
- **Implementation status:** fixed (2026-07-21). Package metadata, install and
  help links, update checks, OpenRouter attribution, tests, and source
  documentation now use `salmon-data-mobilization/metasalmon`. Runtime SDP
  schema fetches use the verified raw endpoint in
  `salmon-data-mobilization/smn-data-pkg`; focused tests and a live remote-schema
  smoke load passed. The full suite passed 1,356 tests, and
  `R CMD check metasalmon_0.1.5.9000.tar.gz` completed with `Status: OK`.
- **Where:** `DESCRIPTION`, `_pkgdown.yml`, `R/version-check.R`,
  `R/schema-helpers.R`, the two OpenRouter request paths, README/vignettes, and
  generated reference/site output.
- The package had moved to `salmon-data-mobilization`, but public install/help
  URLs and the default update check still targeted the independently existing
  `dfo-pacific-science/metasalmon` repository. The remote schema loader likewise
  fetched from the former `smn-data-pkg` repository.
- **Follow-up (2026-08-04):** upstream PRs
  `salmon-data-mobilization/smn-data-pkg#2` and `#3` added the observation/method
  extension and moved the profile, rules, and resource-schema identifiers to the
  active `salmon-data-mobilization.github.io/smn-data-pkg` Pages site. Pages and
  every published artifact were verified byte-for-byte. metasalmon now vendors
  that exact bundle while still keeping contract identifiers distinct from the
  configurable raw-GitHub retrieval source.
- **Compatibility decision (SUPERSEDED 2026-08-10):** the original decision was
  "do not rewrite the SDP 0.2 profile/resource-schema identifiers, because
  upstream still defines the former GitHub Pages URI as the contract value."
  That premise is no longer true — upstream `smn-data-pkg` migrated every `$id`,
  `properties.profile.const`, and `rules.profile` to
  `salmon-data-mobilization.github.io`. Because `.ms_validate_sdp_schema()`
  asserted equality against the hardcoded legacy constant, `source = "remote"`
  aborted outright and the default `"auto"` silently fell back to the stale
  vendored bundle, so every `datapackage.json` metasalmon wrote declared a
  profile URI the live upstream profile's `const` rejects. Invisible to the
  suite because `helper-validation.R` pins `sdp_schema_source = "vendored"` and
  nothing exercised a successful remote fetch.
- **Replacement decision:** identity is **derived from the loaded bundle**, and
  validation checks only internal self-consistency. The vendored files are
  re-vendored from upstream rather than hand-edited. This is what makes an
  upstream identifier change followable. Fixed on `fix/p0-remediation`; the
  gap is closed by a live remote-fetch test.

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

### 29. `package-helpers.R` is a 3786-line god-file
- **Implementation status:** partially addressed. R5 created
  `R/artifact-inference.R` and moved package artifact inference context there.
  `package-helpers.R` remains large and still owns writing, reading, validation,
  `create_sdp()`, and EDH post-processing.
- Mixes `write_salmon_datapackage` (53), `infer_salmon_datapackage_artifacts` (427),
  `create_sdp` (712), `read_salmon_datapackage` (1008), `validate_salmon_datapackage`
  (1292), and a composite-hint cluster (1955-2490). **Recommendation:** land plan R5's
  orchestration extraction in a *new* file (e.g. `R/artifact-inference.R`) to capture
  the Locality win instead of deepening inside the god-file.
- The headline figure said "~2975" until 2026-08-21, when the file was **3786
  lines** (`wc -l`, on `main` and on this branch — the two agree). It has grown
  ~27% since the item was written while the item still described the smaller
  file. The figure is a moving target by construction: **recount it before
  citing it**, and treat any line count in this bundle the same way. `AGENTS.md`
  carries the same number rounded ("~3.8k"), so the two now agree.

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

## 2026-08-10 comprehensive review (items #34+)

Findings from the 2026-08-10 multi-agent review (145 raw findings, 96 surviving
refute-by-default adversarial verification). Full evidence and failure scenarios
are in `knowledge/plans/2026-08-10-comprehensive-ecosystem-review.md`; this
section is the live index. Priority tags refer to
`knowledge/plans/2026-08-10-post-0.2.0-roadmap.md`.

### Fixed in 0.2.0

**#34 `zip (== 3.0.1)` blocked installation.** CRAN ships 3.0.2, so the exact pin
could not be satisfied. **The first fix was incomplete and CI caught it:**
relaxing `DESCRIPTION` to `>=` left the runtime guard
`.ms_knb_require_zip_version()` as an equally exact check, so the package
installed and then aborted on every KNB publication path — 10 test failures on a
runner with zip 3.0.2, invisible locally because the dev machine had 3.0.1.
Fixed properly: the guard is a reviewed-version allowlist
(`.ms_knb_reviewed_zip_versions`), and 3.0.1/3.0.2 were byte-compared for
metasalmon's exact `zip::zip()` call across nested paths, non-ASCII filenames, an
empty file, incompressible and highly compressible content — identical archives.
*Proof from a clean clone:* `test-knb-sdp-archive.R` asserts DESCRIPTION carries
`>=` not `==`, that its floor is a version the guard accepts, and — the check
that would have caught this — that **the installed zip version is one the guard
accepts**, which runs against whatever CI installs.
*Lesson:* a dependency relaxation must be checked against the version the
relaxation admits, not the one the developer happens to have.

**#35 Remote SDP schema loading was dead; produced packages declared a rejected
profile URI.** `.ms_validate_sdp_schema()` asserted equality against a hardcoded
legacy `$id` after upstream migrated. Fixed: identity is derived from the loaded
bundle; validation checks only internal self-consistency. *Proof:* a live
remote-fetch test, plus a bundle-identity test using a fabricated URI. Supersedes
the compatibility decision in #33.

**#36 `.data$x == x` data-mask tautologies.** Three sites; a multi-table
dictionary was applied in full and other datasets' columns leaked into
`datapackage.json`. Fixed with `.env$` pinning. *Proof:* multi-table and
multi-dataset regression tests. One pre-existing test was passing *because of*
this bug and its fixture was corrected.

**#37 `create_sdp()` wrote packages its own validator rejected.** readr re-guessed
character code values (`"0.10"` -> `0.1`, `100000` -> `"1e+05"`). Fixed:
dictionary-driven `col_types` plus a type-aware code comparison. Also fixed
`infer_value_type()` collapsing `POSIXt` to `date`.

**#38 `read` -> edit -> `write` silently deleted reviewed sidecars.** Fixed:
`.ms_package_managed_paths()` limits deletion to writer-owned files; opt-in
`prune = TRUE` restores the old behaviour.

**#39 External text was evaluated as a cli message template.** A provider error
containing braces could print an API key; an unbalanced brace replaced the
message with a parse error. Fixed: `R/cli-safety.R` + 15 sites + boundary
redaction. *Proof:* `test-cli-safety-guard.R`, an AST walk with a self-test.

**#40 Canonical bytes and identifiers depended on `LC_COLLATE`.** ~20 sites
including the resource-map PID and SSSOM canonical bytes. Fixed with explicit C
collation and `dplyr (>= 1.1.0)`. *Proof:* golden-value tests plus
`test-collation-guard.R`. See #43 for the one deliberate exclusion.

**#41 Cancelling a term-request prompt submitted the issue.** `askYesNo()` returns
`NA` on cancel and the guard tested `isFALSE()`. Two sibling bugs in the same
function: `menu()` returning `0` aborted the loop, and the candidate lines passed
cli markup to `glue::glue()`, which fails to parse on every input — so interactive
routing had never worked. All three fixed.

**#42 Repo hygiene: `tmp/` and a dead `.Rbuildignore` regex.** `^\.tmp$` never
matched anything, and the 1.5 MB `tmp/` directory was excluded by neither ignore
file. Fixed: `^tmp(/|$)` in `.Rbuildignore`, `tmp/` in `.gitignore`.

### Fixed during PR #11 review (defects in the 0.2.0 fixes themselves)

Fourteen rounds of automated review on PR #11 found real defects in code written
*for* this release — none in pre-existing code. Recorded because the failure
modes are systematic, not incidental, and the same shapes will recur.

**#64 Type conversion took four rounds of symptom patching before the
structural fix.** Each round fixed the case in front of it (scientific notation,
then precision, then whole-number checks, then datetime sub-second) while
leaving the next one. The fix that held changed the *approach*: read every
column as text, convert in memory, and verify the result against the original
token rather than against another parse. **Lesson:** when a fix needs a third
special case, the design is wrong, not incomplete.

**#65 The cli guard's own allowlist hid a live credential leak.** Allowlisting
`.ms_sdp_decomposition_abort()` as a "wrapper that forwards a caller template"
meant its callers were never examined — and one built its message from
user-supplied column names, so a column named `{Sys.getenv("OPENAI_API_KEY")}`
had its value interpolated into an error. Treating the wrappers as cli message
functions surfaced two further unescaped sites. **Lesson:** an allowlist entry
is an assertion about every call site, and a guard's exemptions deserve the same
scrutiny as the code it guards.

**#66 A fix applied to `metadata/` but not to the root-level shadows.** The
managed-path inventory covered both; the pre-read containment check added two
commits later covered only `metadata/`, so a symlinked root `tables.csv` was
parsed before the guard ran. **#67 The same containment check never inspected
the package root itself** — it walked components *below* `path`, so a symlinked
root left every child looking contained and `prune = TRUE` would have emptied
the link's target.

**#68 Blank, then padded, schema identifiers.** `sdp:version` gained a
well-formedness check; `sdp:rules` three lines away did not. Adding it used
`nzchar()` where the neighbours used `nzchar(trimws())`, so an all-whitespace
bundle agreed with itself and passed. Fixing *that* still compared and stored the
raw value, so consistent padding reached `datapackage.json`. Settled by
normalising at the boundary. **Lesson (shared with #66/#67):** the recurring
shape is fixing one instance and missing its neighbour. After any fix, ask what
else is in the same list, the same file, or the same call path.

**#69 A safeguard tested only against inputs its author imagined.** The
hard-link fix was placed in the caller; a reproduction calling the writer
directly still truncated. **#70 A platform-dependent float quirk was asserted as
universal** — a macOS `readr::parse_double()` result that Linux disagreed with,
caught by CI. Replaced with a fixed exponent band rather than a
platform-conditional assertion.

**#71 An exported row order was locale-dependent through a numeric sort.**
`detect_semantic_term_gaps()` ordered by `placement_confidence` alone; `order()`
is stable, so ties kept the order of `split()`'s factor levels — which come from
a locale-collated sort. The reported finding was only the adjacent character
tie-breaker. **Lesson:** a numeric sort key does not make an ordering
locale-safe; only a *total* order does.

### Fixed in 0.2.4

**#72 `ms_setup_github()` defaulted to a private dataset repo in the old org.**
Found while explaining a CI skip, not by the sweep that should have caught it.
`repo` is now optional: supply it to verify access, omit it to set up the PAT
alone. The test fixtures point at metasalmon's own **public** repository, so the
GitHub read helpers are now exercised everywhere including CI instead of
skipping on a 404 — turning two long-standing CI skips into real coverage.

Worth noting for future sweeps: this is the same class as #62 (a hardcoded
contract value in general-purpose API) and it survived the 0.2.0 pass because
that pass searched for hardcoded *schema* URIs specifically rather than for the
pattern.

#### More fixed in 0.2.4

**#54 The canonical CSV round trip destroyed literal `"NA"` code values.**
Reproduced, and worse than the finding stated: the **written bytes were
identical** for a literal `"NA"` and a missing value, so the loss happened at
write time and no reader could have recovered it. readr's own defaults disagree
— it writes `NA` and reads `c("", "NA")`. Both sides now use a single token,
`""`, defined in one place (`.ms_csv_na_token()`) because the contract is only
sound if the two sides agree and they live in different files.

Three EML tests changed with it, and the direction is worth recording: the
fixture declared `missingValueCode = "NA"`, which described the old bytes. With
one token there is no non-empty missing token left to declare, so EML now
represents absence directly instead of through a code that collided with real
data — and the "undeclared non-empty missing token" guard became unreachable
through the canonical writer. It is retained and now asserted as an invariant
rather than as a failure.

Note the `""`-vs-`NA` ambiguity is **not** new: the old reader mapped an empty
field to missing too, so an empty string never survived either. This change does
not narrow that.

#### Also fixed in 0.2.4

**Five DataONE adapter tests had never executed anywhere.** Not a numbered
backlog item — it came out of the roadmap's own process note about silent
skips, and it is recorded here because of what it demonstrates.
`R-CMD-check.yaml` installed only `devtools` and `rcmdcheck`, so `{dataone}` and
`{datapack}` were absent in CI as well as on development machines, and five
tests covering the boundary that talks to the repository during live publication
skipped silently on every run. They pass — but that was unknown, and a
regression there would have been invisible.

CI installs them now, and `test-ci-optional-deps.R` fails the build when an
optional package the suite needs is absent *in CI*, while still skipping
locally, where a missing optional package is an environment fact rather than a
workflow regression. A check-workflow run should report exactly four skips: the
Theme A integrity tests, which run in `theme-a-integrity.yaml`.

### Fixed in 0.2.3

**#47 `publish_sdp_to_knb()` could not re-plan after any edit.** Reproduced
end-to-end, and it was **three** gates rather than one: the SDP archive writer,
the plan-mismatch check, and the resource-map ownership check each treated an
existing artifact as a published artifact. Clearing the first only moved the
failure to the second. The original finding's "no override" was accurate for the
entry point even though the individual writers have `overwrite` — the parameter
was simply not reachable from `publish_sdp_to_knb()`.

Fixed by one principle rather than three patches: an artifact left by an
**unpublished dry run** may be replaced when `overwrite = TRUE`, because no PID
was ever minted for it. A manifest whose status is not `dry_run` still requires
a reviewed revision, and live publication is still gated by `confirm`. All three
messages now name the remedy.

**#51 The default LLM providers never retried.** `.ms_llm_retry_limit()`
returned 1 attempt for everything except two special-cased models, so
`attempt >= attempts` was true on the first pass and the retryable-error
classifier below it was unreachable — a 429 or 503 failed the whole review on
the first try, after the user had paid for every preceding request.
`Retry-After` is now honoured in both wire formats and capped, with jittered
exponential backoff otherwise so a batch hitting one rate limit does not retry
in lockstep.

**#52 The BioPortal API key travelled in the request URL.** Now an
`Authorization` header, with URLs redacted before display or recording.

### Fixed in 0.2.2

**#45 The term-search index cache never prevented work.** Both index builders
checked their cache stamp *after* fetching and parsing, so every `find_terms()`
call paid 11 conditional GETs and a full reparse before it could discover that
nothing had changed. An index is now resolved once per session, with
`refresh = TRUE` as the escape hatch. The trade — no mid-session pickup of an
upstream module update — is deliberate and matches the schema bundle's
session-stable identity decision; it is also the stronger guarantee for seeding,
where two columns in one package must not be seeded against two ontology
versions.

**#46 `METASALMON_CACHE` was read at build time.** A top-level binding is
evaluated when the namespace is built, so an installed package captured the
build machine's environment. Only `pkgload::load_all()` ever saw the developer's
own setting, which is why it looked like it worked.

**#50 Vocabulary HTTP failures were reported as successful zero-result
searches.** `.safe_json()` returned `NULL` for both a failure and a genuine
empty, every caller collapsed that into `.empty_terms()`, and the diagnostic
recorded `status = "success", count = 0` — the exact input that drives
`request_new_term` escalation, so an outage manufactured ontology gaps.
Failures are now signalled (not thrown — some calls are optional enrichment
inside a per-term map), recorded as `status = "http_error"` in the
`diagnostics` attribute, and warned about; a degraded lookup is never cached.

### Fixed in 0.2.1

**#43 Semantic ranking tiebreakers made seeded IRIs non-reproducible.** Score
ties broke on character keys (`source`, `ontology`, `label`, `iri`), and with
`seed_semantics = TRUE` the top-1 pick becomes a written IRI in
`column_dictionary.csv` — so the same input seeded differently on macOS and in a
C-locale container. Fixed across all nine ordering sites in
`R/semantics-helpers.R` and `R/term_search.R`, with seven functions added to
`collation_sensitive_fns`. **This was the last locale-dependence in the
package.**

Two things worth recording. The deferral rationale — that radix-ing it would
move semantic-suggestion test expectations — turned out to be **wrong**: zero
expectations changed, because the fixtures are lowercase ASCII where C and the
ambient locale agree. That is also precisely why the bug was invisible.
Separately, `.apply_embedding_rerank()` selected its rerank set with
`order(-score)` alone, so *which* rows were reranked depended on input order;
it now tie-breaks on `label`.

**#62 `.ms_sdp_public_schema_base()` was a hardcoded contract value.** It built
the per-resource schema URLs written into descriptors, carrying the same drift
risk that broke remote schema loading before 0.2.0 (#35).
`.ms_sdp_metadata_resource_schema()` now reads the bundle's
`sdp:metadataResources` entry of that name, so every URI in a written
`datapackage.json` — profile, rules, and per-resource schemas — comes from one
validated bundle. The constant survives as the fallback for a bundle predating
the v0.2 extension resources.

### Open — P1 (highest value next)

**#96 A `Date` in `dataset_meta$temporal_start` destroys the package already on
disk. The most severe item on this list.** *(Retired 2026-08-22 — both halves
fixed in the development version; see the closing paragraphs.)*
`R/package-helpers.R:318` read

```r
if (!is.na(dataset_meta$temporal_start[1]) && dataset_meta$temporal_start[1] != "") {
```

Comparing a `Date` with `""` coerces the string to `NA_Date_`, so the whole
`&&` is `NA` and R aborts with *"missing value where TRUE/FALSE needed"*. That
line sits **after** `write_salmon_datapackage()` has unlinked the managed paths
and before it writes any of `metadata/dataset.csv`, `metadata/tables.csv`,
`metadata/column_dictionary.csv`, `metadata/codes.csv` or `datapackage.json`.
The call does not fail cleanly — it **deletes a valid package's metadata and
descriptor and leaves nothing in their place**.

**The triggering input is what the package itself wrote.** Reproduced
2026-08-21: write a valid SDP; read its own `metadata/dataset.csv` back with a
plain `readr::read_csv()`; write it again. `read_csv()` type-guesses
`temporal_start` as `Date` — correctly, since metasalmon wrote an ISO date
there — and the second write aborts. Before: `data/`, `datapackage.json` and
four `metadata/*.csv`. After: `data/nuseds_fraser_coho.csv` alone; `metadata/`
empty, `datapackage.json` gone. No warning, and no reason for a caller to
suspect the read they did was the wrong one — nothing in the API says
`dataset_meta` must be all-character.

The read path escapes only because `.ms_read_metadata_csv()` pins
`col_types = cols(.default = col_character())`; the in-memory path has no such
coercion, which is the same seam #93 item (2) describes. Two fixes, and they
are not the same size: comparing with `!nzchar(as.character(...))` is a local
correction — the same `!= ""` idiom guards `contact_name`, `contact_email`,
`contact_org` and `license` in the twenty lines above, and is safe there only
because `readr` does not type-guess those columns as anything but character —
while coercing typed columns once in `.ms_align_cols()` is the design call #93
is waiting on. **The destructive part should not wait for the design call** —
unlinking before the last thing that can abort is its own defect.

*Retires when:* a `dataset_meta` carrying `Date`-typed `temporal_start` /
`temporal_end` round-trips through `write_salmon_datapackage()`, **and** a
regression test asserts that an aborted write leaves the previously valid
package on disk intact.

**The destructive trigger is FIXED in the development version, 2026-08-21**
(branch `fix/2026-08-21-recon-defects`). Every scalar presence test in the
descriptor builder now renders to character before deciding presence
(`.ms_meta_scalar_present()`), covering the `POSIXct` case — whose `!= ""`
comparison throws rather than yielding NA — as well; descriptor temporal
values render through `.ms_iso_character()` so the JSON and the CSV agree; and
`.ms_align_cols()` now coerces `Date` columns to padded ISO text (#93 item 2),
so no typed date reaches the comparisons or the writers at all.
`test-write-datapackage-typed-metadata.R` proves the Date round trip and that
the directory survives, verified RED first. The second half of the retire
condition — unlinking the managed paths before the last thing that can abort
is its own defect, and no test asserted that an *arbitrary* post-unlink abort
leaves the previous package intact — stayed open at that point, because it
needs a write-then-swap ordering, a design change rather than a comparison
fix.

**RETIRED 2026-08-22 — the ordering half is fixed and both halves of the
retire condition are now met** (branch `fix/2026-08-22-abort-safe-write-path`).
The fix is structural, not a hoist of individual abort points:
`write_salmon_datapackage()` now renders its entire write set — data CSVs,
metadata CSVs, `datapackage.json`, ownership sentinel — to bytes *before*
anything on disk is touched, and installs the rendered set through
`.ms_sdp_extension_atomic_write_set()`, the same staged, rollback-protected
mechanism the sdp-0.2.0 methods migration already used (each replacement fully
staged as a same-directory sibling, originals renamed aside, restored on any
mid-install failure). Managed paths not rewritten (orphans, legacy root
shadows, stale `codes.csv`) are unlinked only after the install succeeds.
Output bytes are unchanged: each file is rendered by the exact writer call
that used to write it in place. `test-write-datapackage-abort-safety.R`
injects aborts at two post-unlink points of the old ordering
(`.ms_sdp_metadata_resource_entries()` in descriptor assembly,
`.ms_meta_scalar_present()` in the resource loop — the very helper PR #75
introduced, whose fixed comparison sat at an unfixed ordering point) and
asserts the surviving package is **byte-identical** (hash comparison) and
readable by `read_salmon_datapackage()`; all injection tests were verified RED
against the pre-fix code (package destroyed, unreadable). A structural guard
in the same file keeps direct filesystem mutations out of the writer body, with
its retirement condition stated.

Two honest narrowings recorded rather than silently absorbed. (1) `prune =
TRUE` deletes files the writer does not own and therefore cannot restore; its
wipe now runs only after every input-dependent computation and the full byte
rendering have succeeded (test-verified: an injected input-dependent abort
under `prune = TRUE` leaves package *and* unmanaged sidecar intact, RED before
the fix), but a pure filesystem failure — disk full, permissions revoked —
between wipe and install can still lose the wiped files. That residual is
documented at `.ms_commit_package_write()` and in the writer's roxygen, and is
deliberate: restoring unowned files would require copying arbitrarily large
data the caller explicitly asked to delete. (2) `create_sdp()`'s create-owned
sidecars (`README-review.txt`, `semantic_suggestions.csv`,
`metadata/metadata-edh-hnap.xml`) still go through
`.ms_replace_create_output()` — unlink-then-rewrite with abort points between
— which is the same defect shape at single-file blast radius; filed as **#111**
rather than stretched into this item's scope.

**Mirror measurement, 2026-08-22 (measured, not assumed).** PR #75's exposure
table (s10 replay plan) marked metasalmonpy `#96` "clean" because `_has_value`
is type-safe and pandas does not date-guess — that covered the *comparison*
trigger only. The *ordering* defect is present in Python:
`package_io.py::write_salmon_datapackage` calls `_prepare_package_dir()` (which
unlinks the managed paths, or `shutil.rmtree`-wipes for prune) and only
afterwards runs `render_resource_frame(...).to_csv(...)`,
`load_sdp_schema(quiet=True)`, the descriptor build, `json.dump`, and
`_write_metadata_csv(...)` — so any exception in that window (a typed-column
rendering error, a broken vendored bundle, a non-serializable numpy value,
plain I/O failure) deletes `metadata/` and `datapackage.json` and writes
nothing back. metasalmonpy's `atomic_io.py` has a single-file `atomic_write()`
but no multi-file staged write set with rollback, which is the mechanism this
fix reuses on the R side. Not fixed there in this stream — S10 chunk A is
actively rewriting metasalmonpy — so this paragraph is the durable record for
the replay: the mirror needs the same render-first/install-atomically ordering
when its 0.3.x catch-up reaches the writer, and metasalmonpy's own
`knowledge/` bundle should carry this once chunk A settles.

**Routed 2026-08-22:** the Python side is no longer merely recorded here — it
is chunk **H** in the S10 execplan
(`knowledge/plans/2026-08-15-s10-metasalmonpy-parity-replay.md`), its own
small item sequenced after the D and E+F chunks, with the measured evidence
above as its brief. **FULLY RETIRED 2026-08-22**: chunk H merged as metasalmonpy PR #21, the last
S10 chunk, mirroring R's fix by reusing `sdp_methods._atomic_write_set()` —
Python's mirror of the very R file R's own fix reuses — rather than building a
second transactional writer. 7 of 8 new tests RED on unfixed `main`; an abort
at the descriptor build had reduced a valid package to a lone `data/obs.csv`.
R's warning about pre-unlink injection points repeated exactly: Python's
`_has_value` fires pre-unlink and was rejected as an injection point. Both
halves of #96 — the destructive Date comparison and the unlink-before-abort
ordering — are now closed in both implementations. The adjacent `create_sdp()`
sidecar shape is **#111** in R and **parity row 53** in Python, where the
window is wider; row 53 does not retire when #111 closes. Chunk C's PR flagged the mirror gap for the hub
rather than absorbing it, and no pre-existing chunk owned write-path
ordering.

**#80 The Theme A exact-model live benchmark was never completed, and nothing in
this bundle said so.** Tracked only in GitHub issue
[metasalmon#6](https://github.com/salmon-data-mobilization/metasalmon/issues/6),
open since 2026-07-29 and untracked here until 2026-08-16 — which is the actual
defect being recorded. PR #5 merged at the maintainer's explicit request *before*
the live cohort ran, so the 0.1.6 merge is not a live-provider attestation and
must not be read as one. The one live attempt returned HTTP 401 for every
benchmark target against `openrouter` / `openai/gpt-5.4-mini`, while a direct
authenticated call to the same provider's model catalogue with the same
credential returned 200 — so the open question is whether the fault is in the
benchmark's request-auth wiring or in provider/endpoint behaviour, and that
distinction is the first deliverable. The cohort gate is unchanged: three
independent live captures, every critical case passing in at least two of three,
zero forbidden method/constraint acceptances, zero false prefills, each capture
sanitized and lineage-verified before promotion. **Substituting a different
provider or model does not satisfy it** — an exact-model benchmark that silently
changed models would attest to nothing. Evidence for the wiring defect belongs in
a focused non-network regression test, since a network-only reproduction cannot
be re-run in CI. Sequenced under S5; `notes/evidence/theme-a/` is the CI/test-wired
evidence directory this feeds.

**#63 The 0.1.8 extension normalizers shipped with locale-dependent ordering.**
`.ms_sdp_methods_normalize()` and the two
`.ms_sdp_observation_normalize_*()` functions produce the canonical row order
written to `metadata/methods.csv` and `metadata/structure/observation_*.csv`, and
`extract_sdp_observations()` orders returned data by dimension columns — all with
bare `dplyr::arrange()`. Fixed during the 0.2.0 merge and added to
`collation_sensitive_fns`. **Recorded because of what it demonstrates:** the
collation guard's limitation #1 (it only sees listed functions) bit within days
of being written. Any new byte-producing function must be added to that list, and
the `AGENTS.md` contract now says so.


**#44 The gcdfo validation layer is inert.** Verified 2026-08-10 —
`knowledge/plans/2026-08-10-gcdfo-validation-layer-verification.md`. SHACL shapes
and example data bind their default prefix to `w3id.org/dfo/salmon#`, a namespace
with zero subjects, so `pyshacl` returns a vacuous pass over real gcdfo data; the
competency SPARQL has three queries in one `.rq` and each fails on an undeclared
prefix; and `robot-profile.yaml` replaces the default profile rather than
amending it, dropping 16 ERROR-level checks. Fix belongs in
`dfo-salmon-ontology`, not here.

**#48 Three error-severity `sdp.rules.yaml` rules are loaded and never executed.**
metasalmon is the workshop's designated final gate before DataONE deposit. Drive
the checks from the parsed rule `id`s so spec and implementation cannot silently
diverge. `R/schema-helpers.R`.

**#49 `validate_salmon_datapackage()` checks far less than it claims** — no
declared primary keys, no required-column nullability, no schema-required
metadata fields, and it reports success on corrupt SSSOM/decomposition artifacts
despite documenting itself as the end-to-end pre-flight.

### Closed — feature

**#74 R-native semantic review and editing. CLOSED 2026-08-25.** All five
milestones shipped the same day: `review_semantics()`, `accept_suggestion()`,
`reject_suggestion()` and `apply_sdp_semantics()` with the accessors #60
required (PR #97), then `review_metadata()`, `set_sdp_dataset()`,
`set_sdp_table()`, `set_sdp_column()` and `set_sdp_code()`. Design and
milestones: `knowledge/plans/2026-08-11-r-native-review-and-editing.md`, whose
Surprises section records what each half got wrong.

*Gate, measured — and this is the whole item:* `create_sdp()` →
`review_semantics()` → `accept_suggestion()` → `apply_sdp_semantics()` →
`review_metadata()` → `set_sdp_*()` →
`validate_salmon_datapackage(require_iris = TRUE)` **passes, with no file
opened in a spreadsheet at any point**, and no `REVIEW:` marker or
`MISSING …:` placeholder remains. The data CSV bytes are byte-identical
throughout, and re-applying the same review produces identical bytes. Asserted
in `tests/testthat/test-metadata-write.R` and
`tests/testthat/test-sdp-field-setters.R`, the latter by **executing the calls
the console printed** rather than by matching their text.

**What closed the half that stayed open, and why it is the interesting part.**
The M1–M3 half narrowed this item rather than closing it, for two reasons it
measured honestly: free-text placeholders had no R-native editor, and
`review_semantics()` shows *shortlists, not gaps* — a slot retrieval returned
nothing for never entered the queue. Both are the same defect seen from two
angles: **a queue built from a suggestion list cannot contain what retrieval
never produced.** `review_metadata()` is not built from suggestions at all. It
reads the package against the four rules that actually decide strict
validation — the Frictionless schema's `constraints.required` (parsed as
`field$requirement` since the schema bundle landed and read by *nothing* until
now), the placeholder markers, the measurement-column IRI requirement in
`validate_dictionary()`, and the blank-`observation_unit_iri` check — so an
empty shortlist and a full one look identical to it.

Three round-trip defects in the M1–M3 API were found while extending it, and
fixed in the same change: a rejection was recorded in
`semantic_suggestions.csv` and never read back (so the next review asked the
same question again), the rejection **reason** never reached disk at all, and
an empty queue under a mistyped `columns` filter printed the *completion*
message. Their shared shape is the reusable finding: **a feature that writes a
record and never reads it back has not been round-tripped, and no test that
only writes will say so.**

*Retires when:* it already has. What is still open in stream S5 is #58 and #59,
which share no code with this.

### Open — retrieval

**#119 `variable` and `property` retrieve the identical ranked list from
`gcdfo`. Reproduced 2026-08-25.** `find_terms("spawner abundance", role =
"variable")` and the same query with `role = "property"` return the same terms
in the same order, top hit `https://w3id.org/gcdfo/salmon#SpawnerAbundance` at
score 18.60 in both. In I-ADOPT terms that is the tool decomposing a variable
into itself: the Property of `SpawnerAbundance` is `Abundance`, not
`SpawnerAbundance`.

*Mechanism, located.* `.gcdfo_filter_for_role()` (`R/term_search.R:1739`) keeps
a term for `variable` when `index$is_variable` **or** its search text matches
`count|rate|abundance|estimate|escapement|spawner|recruit|run`, and for
`property` when `index$is_property` **or** it matches
`abundance|count|rate|length|weight|size|status|confidence|level|phase`. The
two regexes share `abundance|count|rate`, and **gcdfo terms carry no I-ADOPT
role typing at all**, so neither `is_variable` nor `is_property` ever
discriminates: for any query containing one of the shared words, both roles get
the same index and therefore the same ranking. `smn`, which does carry role
typing, is not affected the same way.

*Why this is not fixed here.* Deciding which gcdfo terms may legitimately serve
as a Property is an ontology-modelling question that intersects hub **Q9** and
the `sources_for_role()` filters, not a review-flow one. Tightening the
`property` regex blind would silently drop candidates from packages that
currently get useful ones. Filed with the reproduction so the ruling can be
made with evidence.

*Workaround, and it is a real one:* `accept_suggestion(review, column, role,
iri = "https://w3id.org/smn/Abundance")` takes a term the shortlist never
offered, and `set_sdp_column(path, column, property_iri = "…")` fills a slot
with no shortlist at all. Both were added by #74.

*Retires when:* the two roles return materially different candidate sets for a
measurement query against `gcdfo`, or the overlap is ruled correct and this
item is closed as expected behaviour with that ruling recorded.

**#120 Code-level semantic slots filled by the NuSEDS crosswalk are unreachable
from the review queue. Reported 2026-08-25, not yet reproduced in a test.** The
NuSEDS crosswalk prefills `codes.csv` rows with final (non-`REVIEW:`) IRIs and
produces **no suggestion rows** for them, so `review_semantics()` — which
queues from suggestions — cannot show them, and `include_filled = TRUE` does
not help because there is nothing to include. A reviewer who wants to check or
change one of those code-level terms has no queue entry to work from. Observed
while writing the S4 lesson, which teaches them as a read-only `codes.csv`
inspection and says why.

*Partially mitigated by #74:* `set_sdp_code(path, column, code_value, term_iri
= "…")` can now change one from R, and `review_metadata()` reports a
code-level placeholder. Neither surfaces the *candidates*, which is what a
review is for.

*Retires when:* a crosswalk-filled code slot appears in `review_semantics()`
with its alternatives, or the decision is recorded that crosswalk prefills are
authoritative and deliberately not reviewable.

### P2 — correctness and conformance debt

**Mixed state; read each item's first line, not this heading.** Open: **#86**,
**#87**, **#82**, **#83**, **#111**, **#113**. Fixed but unreleased in gcdfo:
**#81**, **#84**. Superseded: **#75**. They stay interleaved because the
resolved ones carry reasoning the open ones refer back to; the top-of-file
snapshot is the index.

**#113 One shared package-ownership sentinel, replacing the two per-language
ones. RULED, not yet implemented.** A package directory written by metasalmon
and then rewritten by metasalmonpy ends up holding **both**
`.metasalmon-package` (content `metasalmon-owned\n`) and `.metasalmonpy-package`
(`metasalmonpy-owned\n`), because each writer's managed-path inventory —
`.ms_package_managed_paths()` in R, `_package_managed_paths()` in Python — names
only its own, so neither ever removes the other's. Measured 2026-08-22 during
S10 chunk H, on a package that came out byte-identical on all six shared files
and differed **only** in the sentinel. Harm is low — a stray dot-file — but it is
undeclared package content that a hand-made ZIP carries, and the count grows with
every cross-implementation rewrite. Registered as
[parity-deviations](parity-deviations.md) row **51** and its `PARITY.md` twin;
the file was renamed with the package on 2026-08-13, exactly the class of change
that looks cosmetic and is not.

**The ruling (Brett, 2026-08-24, hub [Q14](questions.md)):** *"I want one share
sentinel name. Nobody uses this yet so dont worry about breaking changes."*
(reading "share" as *shared*). So: **one shared sentinel name**, recognised and
written by both implementations — the honest answer to "who owns this directory"
is the SDP tooling, not one language's copy of it — and **the compatibility break
is explicitly accepted**. The recommendation had proposed a read-both /
write-shared transition with the old names retired a release later; the ruling's
second sentence makes that transition optional rather than owed. The rejected
option stays rejected and is worth restating, because it is the one a passing
implementer would reach for: **do not** make each writer remove the other's file
— one implementation deleting another's owned file is the coupling S10 spent the
whole stream removing, and it makes a third implementation a two-repository
change.

**What is left to do, and neither half is decided by the ruling:** pick the name
(`.sdp-package` was the illustration in Q14, not a decision) and its content
line, then land it in both repositories — R's `.ms_package_managed_paths()` and
its writer, Python's `_package_managed_paths()` and its writer, plus whatever
each side's ownership test reads. Both sides already fall back to the SDP-CSV
check, so no package is refused during the change. *Retires when:* both
implementations write and recognise the one name, neither writes a per-language
sentinel, and parity row 51 records the convergence in both registers.

**#111 `create_sdp()`'s create-owned sidecars are unlink-then-rewrite, the same
defect shape #96 retired, at single-file blast radius.** Found while retiring
#96's ordering half (2026-08-22): `write_salmon_datapackage()` is now
transactional over the files it owns, but `create_sdp()` writes three files of
its own *after* the package write, each through `.ms_replace_create_output()`
(`R/package-helpers.R`) — unlink the existing file, then have the caller write
a replacement. `README-review.txt` (`.ms_write_sdp_review_readme()`),
`semantic_suggestions.csv` (`readr::write_csv` after the unlink), and
`metadata/metadata-edh-hnap.xml` (`edh_build_hnap_xml()` after the unlink) each
have abort points between the unlink and the completed rewrite — the EDH XML
builder is the widest, since it renders from metadata at write time. An abort
destroys only that one file, not the package, and a re-run of `create_sdp()`
regenerates it — but a *reviewed* `README-review.txt` a user annotated in
place, or the EDH XML of a package whose inputs have since changed, is not
recoverable by re-running. The fix is mechanical now that the writer shows the
shape: render to bytes, install via `.ms_sdp_extension_atomic_write_set()`
(single-file case already wrapped as `.ms_sdp_extension_atomic_write()`), and
retire `.ms_replace_create_output()` — its hard-link rationale is subsumed,
since staged-sibling rename never writes through an existing inode. *Retires
when:* `.ms_replace_create_output()` has no callers and a test injects an
abort into each of the three rewrites and finds the prior file intact.

**#86 metasalmonpy's SDP-extension IRI validator never imported `R_SPACE_CLASS`.**
`metasalmonpy/sdp_methods.py:95` `_is_absolute_iri()` says in its own docstring
that it mirrors `.ms_sdp_extension_is_absolute_iri`, but matches whitespace with
Python's `\s` (`sdp_methods.py:67,69`) rather than the enumerated
`metadata.R_SPACE_CLASS` that `eml.py:92` and `sssom.py:234` both import. `\s`
is Unicode-aware but is not TRE's set. Measured on R 4.5.2 across
U+0001–U+3100: **8 codepoints disagree — U+001C–U+001F, U+0085, U+00A0, U+2007,
U+202F — Python rejecting every one R accepts.** Python is the stricter side, so
the failure mode is a Python-written extension IRI refused by the mirror and
accepted by R. It reaches users through `validate_sdp_methods()`,
`observation_structures.py:256` and KNB publication
(`knb_publication.py:575`).

This is the same drift `sssom.py:228-232` records having already fixed once; the
one extension module that never imported the constants was never given the same
treatment, and `tests/test_sdp_methods.py` has no whitespace-membership test
where `tests/test_eml.py` and `tests/test_sssom.py` do — which is why nothing
caught it. Found by reading the Python side while fixing #85, testing the
register's claim that "Python mirrors no such function"; it does. Registered as
parity-deviations **row 33** (row 29 until 2026-08-17, when metasalmonpy's
0.1.8 rows 29–32 took that number and this one moved), and it narrowed from 23
codepoints to 8 when #85 landed. *Retires when:* `sdp_methods.py` builds both
regexes from `R_SPACE_CLASS` and `tests/test_sdp_methods.py` pins the
membership. Belongs to roadmap stream **S10**; the twin's `PARITY.md` needs the
matching row 33.

**#87 metasalmonpy's term ranker has no ranking-profile system, and its
hardcoded weights are not R's.** `term_search.py:955` `_score_and_rank_terms`
implements R's `match_type` ladder but nothing of the profile machinery around
it: no `ranking_profile` argument, no `.merge_ranking_profile()`, no
`.ranking_profile_defaults()` (`R/term_search.R:2040`, `:2222`), and every
tunable inlined.

**The ordering half of this item is closed, and it closed in R.** A
differential on 2026-08-17 measured what this entry had inferred: over six
tie-heavy candidates under four input permutations both rankers were
deterministic, but R returned `gcdfo` above `smn` and metasalmonpy the
reverse. Brett ruled that `smn` outranks `gcdfo` and that **metasalmonpy was
right**, so metasalmon changed — `role_boost` had given `gcdfo` 1.3 against
`smn`'s 1.7, a 0.5 margin the routine bonus stack (0.2 label overlap + 0.4
cross-source agreement) overturned. R now uses a flat `gcdfo` 1.0 and base
weights `smn` 1.2 / `gcdfo` 1.0, so `base_source_weight` **matches Python's
map value-for-value** and the differential returns identical order and scores
on both sides. Pinned by `tests/testthat/test-smn-outranks-gcdfo.R`.

What remains here is the missing profile machinery, plus inlined values that
still differ without being known to change order: the unknown-source fallback
(Python 0 vs R's 0.1); role boosts for the non-salmon sources (e.g.
`variable`: R `nvs` 1.0/`ols` 0.4/`zooma` 0.4, Python `nvs` 0.6/`ols`
0.2/`bioportal` 0.4), with `statistical_modifier` present only in R; and the
vocabulary bonuses, which differ in magnitude *and* in gating — R applies
`host_bonus` 0.8 / `slug_bonus` 0.8 / `label_pattern_bonus` 0.4 only inside
the role-preferences branch, Python adds 1 / 1 / 0.5 unconditionally. R's
`backend_score` term has no counterpart.

The worst part is not the absence. `benchmark_term_ranking_fixtures(profiles =
...)` is exported on both sides, but Python's
(`term_search.py:1185-1266`) binds each profile to `_profile` at **`:1224`**
and never reads it again — the sole scorer call at **`:1230`** passes
`candidates`, `role`, `vocab`, `query` and no profile — then echoes the names
back at `:1244`/`:1255` and the whole input dict at `:1265`. So benchmarking
two profiles yields two identical summary rows under different names. The one
exported surface for comparing ranking profiles silently reports that all
profiles are equivalent, which is worse than not having it.

**Threading the argument through would not be enough, and that is easy to
miss.** `_score_and_rank_terms` (`term_search.py:955`) has no parameter to
receive a profile — a repo-wide search for `ranking_profile` finds one hit and
it is a *comment*. So the fix is the profile system (the gap above), not a
one-line pass-through; the discarded argument is the **symptom**, and a patch
that only threads it would produce a plausible-looking benchmark over a scorer
that still ignores it.

**Two reasons nothing caught it, both worth fixing alongside.** metasalmonpy has
**no test at all** for this function — `tests/test_public_api.py:33-44` asserts
a hardcoded set of nine exported names that does not include it, so even the
export check skips it. And the default fixture path
(`term_search.py:1217`, `resources.files("metasalmonpy")/"tests/fixtures/semantic-ranking-fixtures.json"`)
names a file **that does not exist in the repo**, so the no-argument call path
is dead too — the R fixture it mirrors does exist, at
`tests/testthat/fixtures/semantic-ranking-fixtures.json`. R by contrast pins
exactly this behaviour: `tests/testthat/test-term-search.R:1352` benchmarks a
`no_smn` profile against `baseline` and asserts the scores differ, which is the
assertion Python cannot currently pass.

This **predates the 0.1.6 parity claim** and no S10 rung covers it — logged as
out of scope on the [S10 execplan](plans/2026-08-15-s10-metasalmonpy-parity-replay.md)
so the omission is deliberate rather than forgotten. Registered as
parity-deviations **row 32** / `PARITY.md` row 32. Severity: silent — nothing
errors, candidate order can still differ outside the pinned `smn`/`gcdfo`
comparison, and the benchmark that would catch it is the thing that is broken.
*Retires when:* `_score_and_rank_terms` takes a
profile merged over a Python `.ranking_profile_defaults()` read back from the
claimed R release, `benchmark_term_ranking_fixtures` threads `profiles`
through, and a differential fixture pins both rankers to the same order.
Needs a rung or its own stream before the 0.2.0 replay work depends on
ranking behaviour.

**#81 gcdfo ships a dead script and its orphaned output. FIXED 2026-08-17 in
gcdfo PR #83.** `scripts/stabilize_webvowl_output.py` had zero references
repo-wide — the normalizer superseded it — and `docs/webvowl/data/ontology.stamp`
was its output, a tracked file nothing regenerated: a direct violation of
gcdfo's own "no ghost code" rule. Both are deleted on `main`; verified absent
from `git ls-tree origin/main`. The retirement condition is met. **Not yet
released** — PR #83 merged after the 0.0.9 tag, so a consumer on the tag still
gets both files.

**#94 metasalmon's canonical date key WAS platform-dependent. CONFIRMED and
fixed 2026-08-21.** *(Filed as a second #91 until 2026-08-21; renumbered so the
three registers citing "#91" for year padding have an unambiguous target. See
the snapshot.)* `.ms_canonical_value_tokens()` rendered the date key with
`format(parsed, "%Y-%m-%d")`. metasalmonpy hit exactly this in Python:
`strftime("%Y")` **does not zero-pad a year below 1000 on glibc** where
macOS/BSD does, so `0001-01-01` became `1-01-01` on Linux only — and that key
decides whether a data column validates against its own `codes.csv` *and* is
written into package bytes.

**Measured, on both platforms, and the open question is closed.** macOS R 4.5.2
returns the padded `0001-01-01`. **This repo's Linux CI runner returns
`1-01-01`** — and `100-02-03` and `999-12-31` for years 100 and 999. The
measurement was made by writing the assertion as a test and reading the check
result rather than by reasoning about `--with-internal-tzcode`, which is the
only way this could have been settled: every call site reads as correct, and
the platform where it is wrong is not the one anyone develops on.

**Four sites carried it, and only one was the one everybody was looking at.**

| site | what the unpadded year did |
|---|---|
| `.ms_canonical_value_tokens()` (date + datetime) | canonical key written into package bytes — silent, because both sides of a `codes.csv` comparison shift together, so two machines simply write different packages |
| `.ms_sdp_observation_typed_character()` and `.ms_sdp_observation_normalize_typed_values()` | rendered text is matched against a `[0-9]{4}` year pattern, so on Linux a valid year-1 date was **rejected as malformed**, and a normalized value would not survive a second normalization |
| `.ms_eml_validate_observed_domain()` round-trip check | compared the reformatted date against the user's own token, so a valid EML `dateTime` value **aborted the export** on Linux — the latent EML site, matching the one metasalmonpy found in `eml.py` |
| the spreadsheet-preview reader in `llm-semantic-helpers.R` | the **implicit** form: `as.character()` of a Date is `format(x, "%Y-%m-%d")` underneath and contains no `%Y` to grep for |

Fixed in `R/platform-time.R`, which renders only the year by hand and leaves
`%m`/`%d`/`%H`/`%M`/`%OS` to strftime — `%OS6` truncates where `sprintf` rounds,
so rebuilding a whole timestamp would have changed bytes on the platform that
was already correct. Verified byte-identical for every year the two platforms
already agreed on. Guarded by `tests/testthat/test-year-padding-guard.R`, which
walks the installed namespace (a grep-based guard would skip under `R CMD
check`, where `R/` holds only `metasalmon.rdb`) and was negative-tested against
planted violations.

**`metasalmonpy/tests/data/resource_types/r-token-verdicts.json` is fine, and
the doubt is retired.** It records `0001-01-01` → `0001-01-01`, which was a
macOS-only truth when it was captured and is now true on both platforms. The
corpus encoded the *correct* expectation and the R implementation has been
brought to it; nothing needs regenerating. Had the fix gone the other way the
corpus would have been the artifact.

*Retires when:* nothing — the risk is closed. The **guard** retires when R
guarantees a zero-padded `%Y` on every platform it builds on, which is the
platform's contract and not this package's to change.

**Register state, and the twins disagree.** `knowledge/parity-deviations.md`
row 40 reads *Ahead (converged 2026-08-21, in R)*; metasalmonpy's `PARITY.md`
row 40 still reads *Ahead (open; hub owns the R side)* and still says the row
is marked converged "when metasalmon's fix merges" — which it has. Python's
copy is the stale one. Both rows also still cite this item as "#91" and want
"#94".

**#93 `as.character()` of a Date drops the year padding on every platform, and
the package cannot read back what it writes.** Found while fixing #94 and
**verified on macOS R 4.5.2**, which is what makes it a different defect rather
than more of the same one:

```r
as.character(as.Date("0001-01-01"))   #> "1-01-01"      <- macOS too
format(as.Date("0001-01-01"))         #> "0001-01-01"
readr::format_csv(data.frame(d = as.Date("0001-01-01")))
                                      #> "d\n1-01-01\n"
readr::parse_date("1-01-01")          #> NA + a parsing failure
```

Since R 4.3, `as.character.Date` takes an internal fast path that does not go
through `format()`/strftime at all. So this one is **not platform-dependent**,
and CI cannot surface it by disagreeing with a developer's machine — the way
#94 was surfaced. It is also worth naming that the two defects point in
**opposite directions**: a path that `format()`s on one side and
`as.character()`s on the other mismatches on macOS and *matches* on Linux,
which is the reverse of #94 and is a good way to fix the wrong side.

Three sites were fixed with #94, using `.ms_iso_character()` (pads the rendered
text rather than re-deriving it, so `as.character()`'s shape choices survive):
the inferred `temporal_start`/`temporal_end` in
`infer_dataset_metadata_from_resources()`, and the `meta()` accessor in
`edh-xml-export.R` — where the existing `inherits(value, c("POSIXct", "POSIXt",
"Date"))` test had **identical branches**, so it read as though the temporal
case was handled and did nothing.

**What is left needs a decision, not a substitution, which is why it is a
separate item.**

1. ~~**`write_salmon_datapackage()` writes resource columns uncoerced.**~~
   **FIXED 2026-08-21.** Date columns now go through `.ms_iso_date_columns()`
   before `readr::write_csv()`, and a pre-1000 `Date` survives
   write → read unchanged (`test-date-column-round-trip.R`, verified to fail on
   a reverted write site).

   **The design call, and it was settled by measurement rather than argument.**
   The worry was that coercing typed columns could change bytes for other
   types. It can — so the fix touches **`Date` only**:

   | | `readr::write_csv` | `as.character` |
   |---|---|---|
   | `Date`, year 1 | `1-01-01` | `1-01-01` — *identical, both wrong* |
   | `POSIXct`, year 1 | `0001-01-01T00:00:00Z` — *already correct* | `1-01-01` |
   | `POSIXct` with `.5` | `2024-01-31T10:00:00Z` — *fractional dropped* | `2024-01-31 10:00:00.5` — *kept* |

   Because `write_csv` and `as.character` agree exactly on a `Date`, padding the
   rendered text reproduces readr's own output for every year it already got
   right. Because they agree on **nothing** for a `POSIXct` — separator, zone
   marker, and whether a fractional second survives — a fix applied to both
   types "for symmetry" would have corrupted the path that was never broken.
   A regression test pins that non-interference.

   **This unblocked item 2 below**, which took the substitution on
   2026-08-21. Items 3 and 5 remain open under Q12; item 4's failure mode is
   mooted on the metadata path by item 2's fix (see its entry).

   metasalmonpy needed no change — `date.isoformat()`, `str()` and
   `pandas.to_csv` all pad — so no parity register row is added, because after
   the fix there is no difference to record. Under the 2026-08-17 ruling that
   the mirror is not automatically the follower, R is the side that moved.
2. ~~**EML `calendarDate` and the `dataset.csv` writer** are safe *only because*
   the on-disk path pins `col_types = cols(.default = col_character())` in
   `.ms_read_metadata_csv()`.~~ **FIXED 2026-08-21** (branch
   `fix/2026-08-21-recon-defects`). `.ms_align_cols()` now applies
   `.ms_iso_date_columns()` — the substitution item 1's ruling made it — so a
   caller-supplied `Date` column is rendered as padded ISO text before any
   metadata frame reaches a writer, POSIXct deliberately untouched and pinned
   by test. A consequence: item 4's `datapackage.json` vs `dataset.csv`
   disagreement can no longer occur for metadata-frame `Date` fields, because
   no `Date` survives to either writer; item 4 remains listed for any
   non-metadata path Q12 uncovers. metasalmonpy needed no change (re-measured
   2026-08-21: `pandas.to_csv` renders `date(999, 1, 1)` as `0999-01-01`).
3. ~~**`.ms_sssom_canonical_bytes()` renders the same column two ways**: the
   sort key via `as.character()` (unpadded everywhere) and the emitted bytes
   via `as.matrix()` inside `apply()` (which uses `format()`, so padded on
   macOS and unpadded on Linux). Row *order* and row *content* can therefore
   disagree about the same value, and `mapping_date` / `publication_date` /
   `review_date` are declared SSSOM columns.~~ **FIXED 2026-08-25** (branch
   `fix/2026-08-25-q12-date-render`), under the Q12 ruling below. The sort key
   and the emitted bytes now both read one `lapply(mappings,
   .ms_canonical_character)`, mirroring metasalmonpy's `_canonical_bytes()`,
   whose `cells` dict is built once and indexed by both.
   `tests/testthat/test-canonical-date-render.R` was verified RED first: with
   `mapping_date` values `1000-01-01` and `0999-01-01` and every earlier column
   held equal, the pre-fix function emitted the padded spellings in the
   unpadded order, so the canonical table was not sorted by its own visible
   contents.

   **It was worse than the item says, in a way that needs no pre-1000 date.**
   `format()` on a data-frame column is *vector-wise*: it picks one notation
   for the whole column. A `confidence` of `1.5` was emitted as `1.5e+00`
   merely because another row held `100000` — while sorting as `1.5`. A cell's
   canonical bytes were a function of its neighbours, which is disqualifying
   for a canonical form and was reachable by any typed numeric column. Pinned
   by a test that renders the same row in a one-row and a two-row set and
   requires identical bytes.

   Observable byte changes are confined to an **in-memory** mapping set
   carrying a non-character column; a set read from a `.sssom.tsv` is all
   character, where every renderer agrees. **No golden hash moved and none was
   regenerated** — `test-collation.R`'s fixed-value SSSOM hash is
   character-valued and still passes unchanged, which is the evidence that the
   change is confined where this paragraph says it is. The residual
   cross-implementation spelling difference for such a column is registered as
   [parity-deviations](parity-deviations.md) row **59**.
4. ~~**`datapackage.json` and `metadata/dataset.csv` disagree with each
   other**: `jsonlite::write_json()` pads a `Date` and `readr::write_csv()`
   does not, so one `write_salmon_datapackage()` call can emit `0999-01-01` in
   the JSON and `999-01-01` in the CSV.~~ **UNREACHABLE as stated, confirmed by
   trace 2026-08-25 — closed as a finding, not as a fix.** Item 2's coercion
   inside `.ms_align_cols()` is applied to *every* frame that reaches the
   descriptor, and the descriptor builder has no other source of a typed value:
   both assembly sites were read end to end, and there is no `created` /
   `sources` / custom-field passthrough, the `schema.fields` objects are built
   from the dictionary alone, `licenses` and `primaryKey` are hard-cast to
   character anyway, and no value from a data resource is copied into the
   descriptor. No `Date` survives to either writer, on any path.

   **Two corrections to the item's own premise, both measured rather than
   reasoned**, and the first makes the item smaller than it ever read:
   jsonlite 2.0.0 serializes a `Date` through `format.Date` (verified by
   tracing `format.Date` under `toJSON()`), which delegates `%Y` to the
   platform strftime — so on glibc **jsonlite emits `999-01-01` too**, and
   "the JSON pads and the CSV does not" was a **macOS-only** split even before
   item 2 closed it. And the same *shape* is alive for `POSIXct`, which
   `.ms_align_cols()` deliberately leaves typed: measured end to end, a
   `temporal_start` of `as.POSIXct("0999-06-05 13:45:30", tz = "UTC")` is
   written `0999-06-05 13:45:30` into `datapackage.json` and
   `0999-06-05T13:45:30Z` into `metadata/dataset.csv`. That is a *format*
   disagreement rather than a padding one, deciding it needs a ruling on which
   spelling a descriptor instant takes, and **metasalmonpy has the same
   disagreement plus an unpadded CSV side**. Filed as **#115** rather than
   folded into this item, because it is a different mechanism under a
   different type and the item's retire condition does not cover it.

   The finding is enforced rather than asserted:
   `test-canonical-date-render.R` writes a package from a `Date`-typed
   `dataset_meta` and requires `datapackage.json` and `metadata/dataset.csv` to
   **agree**, not merely to be coerced — so it still fails if a future
   descriptor key starts carrying a typed value, whichever writer changes. It
   was verified RED by removing the coercion from `.ms_align_cols()`:
   descriptor `0999-01-01`, CSV `999-01-01`, exactly the symptom this item
   described.
5. ~~`.ms_canonical_value_tokens()` still takes `trimws(as.character(x))` for
   its `original` fallback, so a Date column declared `value_type = "string"`
   keys unpadded while the `date` branch beside it now keys padded.~~ **FIXED
   2026-08-25**, same branch and same helper. The consequence was not only
   internal inconsistency: the CSV `write_salmon_datapackage()` produces from
   that column reads `0999-01-01`, so an in-memory frame disagreed with **its
   own written package** about whether a data value was listed in `codes.csv`.
   RED-verified across all four branches that return `original` (`string`, the
   empty declaration, an unknown declaration, and the unparseable fallback).

**Items 3–5 were held by a question, and the question was rewritten 2026-08-24
before it was answered.** [Q12](questions.md) had been written in language that
assumed context Brett did not have, and it drew the reasonable guess that this
was about the KNB deposit reaching the DataONE CN. **It is not, and nothing here
touches KNB or DataONE**: it is about which of R's two `Date`-to-text renderers a
given code path uses. The rewritten entry states the symptoms in those terms and
named the single decision that was actually Brett's — *fix the three now, or
accept them permanently and caveat the byte-reproducibility claim where it is
made*.

**The ruling (Brett, 2026-08-24, hub [Q12](questions.md)):** *"Fix them as per
the metasalmonpy implementation by fixing all three by coercing them once at
render time per type."* Implemented 2026-08-25 on branch
`fix/2026-08-25-q12-date-render`. Two of the three were code fixes and the third
was a trace; all three are recorded above. The ruling's second half — *per type*
— is the part that does the work, and it is why one helper could serve two very
different call sites without a symmetry error: `.ms_canonical_character()`
(`R/platform-time.R`) dispatches on the value's class, and its `POSIXt` branch
pads where `.ms_iso_date_columns()`'s deliberately does not, because the two
sit on different baselines (`as.character()` there, `readr::write_csv()` here).
A regression test pins that the second did not leak into the first.

Severity: silent data corruption at (1) and (3), silent inconsistency at (4) and
(5), latent at (2). Not urgent — every case needs a pre-1000 date, which no
salmon dataset has, except the neighbour-dependent numeric spelling found inside
(3), which needed no date at all — but it is a **byte-reproducibility** defect in
a package whose contract is byte reproducibility, and (1) is a genuine round-trip
break.

**RETIRED 2026-08-25 — the stated retire condition is met, and the honest
reading of "met" is recorded rather than assumed.** *Retires when:* a
`Date`-typed column survives `write_salmon_datapackage()` →
`read_salmon_datapackage()` unchanged for a pre-1000 year — met since 2026-08-21
by item 1, pinned by `tests/testthat/test-date-column-round-trip.R` — **and** the
SSSOM sort key and emitted bytes are rendered by the same function — met
2026-08-25 by item 3, where both now read one `lapply(mappings,
.ms_canonical_character)` and a test requires the emitted rows to be in C order
*of themselves*. Item 4 is closed as a finding rather than a fix; the `POSIXct`
shape it exposed is **#115** and is deliberately not carried by this item's
condition, which names `Date` and the SSSOM renderer and nothing else.
`tests/testthat/test-year-padding-guard.R` still does **not** cover any of this
— it is blind to the implicit form by construction, and says so; the coverage
lives in `tests/testthat/test-canonical-date-render.R`.

**#115 `datapackage.json` and `metadata/dataset.csv` spell the same `POSIXct`
two different ways, in both implementations.** Found 2026-08-25 while closing
#93 item 4, and filed separately because it is a different mechanism under a
different type: item 4's condition names `Date` and year padding, and this is
neither.

`.ms_align_cols()` coerces `Date` columns and **deliberately leaves `POSIXct`
alone** — #93 item 1 ruled that, correctly, because `readr::write_csv()`'s
instant output is already ISO-correct and coercing it would change the
separator, the zone marker, and whether a fractional second survives. The
consequence is that a typed instant reaches *both* writers, and they disagree.
Measured end to end on macOS (R 4.5.2, jsonlite 2.0.0, readr 2.2.0), a
`dataset_meta$temporal_start` of `as.POSIXct("0999-06-05 13:45:30", tz = "UTC")`:

| file | writer | bytes |
|---|---|---|
| `datapackage.json` | `.ms_iso_character()` (`R/package-helpers.R:344`) | `0999-06-05 13:45:30` |
| `metadata/dataset.csv` | `readr::write_csv()` | `0999-06-05T13:45:30Z` |

Year padding **agrees**; the separator and the `Z` do not, and a midnight
instant additionally loses its time in the descriptor because `as.character()`
drops it. The same two files therefore carry two spellings of one value that a
consumer reading either is entitled to treat as the package's answer.

**The mirror has it too, and worse — measured, not assumed** (2026-08-25, same
fixture through `metasalmonpy.package_io.write_salmon_datapackage`): descriptor
`0999-06-05T13:45:30`, `metadata/dataset.csv` `999-06-05 13:45:30`. So Python
disagrees with itself on the separator *and* on the year padding, and each
implementation's descriptor disagrees with the other's. Four spellings of one
instant across two packages. Nothing here favours R or Python; it is a shared
defect neither side noticed, which is the argument for ruling on it once rather
than fixing whichever copy is in front of you.

**The Python half is a second, separable defect, and it is the mirror's own
determinism contract rather than this one.** Narrowed on pandas 3.0.5: a column
built from `datetime.datetime` objects becomes `datetime64[us]`, and `to_csv`
renders it with an **unpadded** year, while `str()` of the same value and an
`object`-dtype column both pad.

```
str(datetime(999,6,5,13,45,30))                     -> '0999-06-05 13:45:30'
DataFrame({'t':[that]}).to_csv()   # datetime64[us] -> '999-06-05 13:45:30'
DataFrame({'t':Series([that], dtype=object)})       -> '0999-06-05 13:45:30'
DataFrame({'t':[date(999,6,5)]}).to_csv()           -> '0999-06-05'
```

`resource_types.py`'s header claims `date.isoformat()` is "already safe (it is
pure Python)" and that the padded form is what the module converges on; that is
true of every path it renders itself and **not** of the one where pandas
renders for it. #93 item 2's mirror note ("re-measured 2026-08-21:
`pandas.to_csv` renders `date(999, 1, 1)` as `0999-01-01`") is correct as
written and does not generalize to `datetime`, which is the trap: the
measurement was taken on the type that passes. Whoever fixes the Python half
should route the metadata frame through `render_resource_frame()`'s
`datetime64` branch — which already emits `_iso_seconds(...) + "Z"` — or add an
equivalent, and extend `tests/test_platform_determinism_guard.py`, which is the
guard this slipped past. **Do not fix it from this repository**; report it and
let metasalmonpy's own stream take it, with the descriptor spelling ruled
first so the two land together.

**Why this is not a substitution.** Making the two agree means deciding *which*
spelling a descriptor instant takes, and every candidate has a cost:
`readr`'s `...T...Z` is the ISO form and is already in the CSV, but adopting it
in the descriptor changes `datapackage.json` bytes for every package with a
typed instant; `.ms_iso_character()`'s form is what the descriptor emits today
but is not valid `xs:dateTime`; and coercing `POSIXct` inside `.ms_align_cols()`
is the one move #93 item 1 explicitly ruled out. It needs a ruling, and the
ruling has to be made in both repositories at once or it creates a parity row
instead of closing one.

Severity: silent inconsistency, low reach — a caller must supply a typed
`POSIXct` rather than the character metadata both packages produce themselves.
*Retires when:* one spelling is ruled for a descriptor instant, both
implementations emit it, and a test in each asserts that `datapackage.json` and
`metadata/dataset.csv` agree for a `POSIXct` — the R half of that assertion
already exists for `Date` in `tests/testthat/test-canonical-date-render.R` and
is the shape to copy.

**#92 metasalmonpy's extras-gated tests had zero CI coverage, and two documents
said otherwise. FIXED 2026-08-21 in metasalmonpy PR #12.** `parity.yml`'s
`python` job installed `.[test]` — which is
`build` plus `pytest` and **neither `[eml]` nor `[context]`** — so the only
full-suite CI run is core-deps-shaped *by accident*, and the **97 extras-gated
tests (EML, KNB, context readers) never run in CI at all**.

The documentation is worse than the gap. `AGENTS.md` and `PARITY.md` row 30 both
say "the core-deps CI job runs the whole suite with neither extra installed,"
which reads as a dedicated core-deps job sitting *alongside* a normal one. There
is only the one job. So a claim of deliberate narrow coverage is describing an
accident, and the broad coverage it implies exists nowhere — the same shape as
#89, where a determinism guard was real and passing while only ever exercising
the shape the ontology happened to have.

**Fixed 2026-08-21** (metasalmonpy PR #12, merge `c13df83`, from
`ci/run-both-dependency-configurations`). `parity.yml`'s `python` job is now a
two-leg matrix — *core dependencies only* (`.[test]`) and *with `[eml]` and
`[context]` extras* (`.[test,eml,context]`) — running an identical step list,
and each leg **verifies its own dependency configuration before it runs
anything**: the core leg asserts `yaml lxml openpyxl pypdf xlrd` are absent,
the extras leg asserts they are present. That verification step is the part
worth copying: without it a typo in the extras list turns the second leg into a
second core-deps run, the extras-gated tests go back to skipping, and the job
stays green under a name describing coverage it had stopped providing. The
workflow carries its own retirement condition in a header comment, and
`PARITY.md` row 30 now describes what CI does, with the old overstatement kept
and marked as such.

The count moved with the suite: this item recorded 97 extras-gated tests when
found, the fix records 94. Neither figure is load-bearing and neither was
re-counted here.

*Retires when:* met — CI runs both dependency configurations and both documents
describe it. Nothing here is outstanding.

**#90 Every semantically annotated SDP either mirror writes fails
smn-data-pkg's strict publication validator.** `write_salmon_datapackage()`
attaches **seven** keys to each descriptor `schema.fields` entry —
`unit_iri`, `term_iri`, `term_type`, `property_iri`, `entity_iri`,
`constraint_iri` and `statistical_modifier_iri`
(`R/package-helpers.R:205-225`). `scripts/validate_package.py` builds the
expected field list with `descriptor_field_from_column()` — `name`, `title`,
`description`, `type`, plus `constraints` when required — and compares the
whole list with `!=` (`scripts/validate_package.py:917-925`), so **any extra
key is an error**.

**Reproduced 2026-08-21, end to end.** `create_sdp()` on the bundled 173-row
example, one measurement column annotated with `term_iri` / `property_iri` /
`entity_iri` / `unit_iri`, written with `write_salmon_datapackage()`, then
`python3 scripts/validate_package.py <pkg>` from a `smn-data-pkg` checkout on
`main`: `datapackage.json resource data/nuseds_fraser_coho.csv schema.fields
must match metadata/column_dictionary.csv-derived fields.` The same package
with the IRIs left blank does not raise that error, which is the whole
mechanism — the extra keys appear only once a measurement column is annotated
the way the SDP spec asks.

**metasalmonpy emits seven keys too, but not the same seven** — corrected
2026-08-21. Python's descriptor projection (`package_io.py:680-686`,
`:910-917`) ends in **`method_iri`** where R ends in
`statistical_modifier_iri`, because it still vendors sdp-0.2.0, whose
dictionary had a `method_iri` slot that sdp-0.3.0 deleted (see #75). So the
conclusion "not a parity divergence" survives — both mirrors fail this
validator, and no R↔Python comparison would surface it — but the premise
"identical keys" was wrong, and it mattered: whichever way #90 is decided,
Python's seventh key was a *separate* divergence that the S10 catch-up had to
close on its own.

**It did, and the premise is true again — re-measured 2026-08-24.** S10 chunk A
(2026-08-22) flipped the vendored bundle and the dictionary contract to
sdp-0.3.0 together, and the catch-up closed with metasalmonpy **0.4.0** on
2026-08-24. Python's descriptor projection now ends in
`statistical_modifier_iri` in both sites this item named
(`package_io.py:851-858` optional-key list, `:1110-1121` descriptor read, which
also deliberately declines the legacy `iAdopt:methodIri` key so an unmigrated
sdp-0.2.0 package keeps its binding until `migrate_sdp_methods()` moves it).
The surviving `method_iri` in `package_io.py` is in
`_collect_placement_iri_issues()` — the mirror of R's own placement validator,
which is *supposed* to name that field. So **both mirrors emit the same seven
keys and both still fail this validator for the same reason**, which is the
state this item's conclusion always assumed; #90 is now a single decision rather
than a decision plus a Python-side cleanup.

**The two readings are not evenly supported, and the item used to imply they
were.** The normativity claim behind "the validator is normative" does not
hold up:

- All 76 lines of `schema/sdp.rules.yaml` **never mention
  `validate_package.py`**. The only repo-wide references to the script are
  `README.md:90` and `docs/entrypoints.md:12`, both describing it as something
  to run, not as a normative authority.
- The published **v0.3 profile has zero `additionalProperties` constraints**
  (as does v0.2) — so the profile the packages actually declare already
  permits the keys.
- Frictionless Table Schema explicitly allows custom field properties, which
  is the standard the descriptor claims to follow.
- **No CI in any ecosystem repo runs the script** — `smn-data-pkg` has no
  `.github/` at all (#103), and neither metasalmon's, metasalmonpy's nor
  gcdfo's workflows invoke it.

`SPECIFICATION.md:80-96` says a descriptor must "include a field entry for
each matching row in `metadata/column_dictionary.csv`", which is a
completeness requirement; the "no extra columns" sentence beside it is about
**canonical metadata CSV headers**, not descriptor field keys.

**RULED 2026-08-24 (Brett), hub [Q3](questions.md): permit the keys.** *"Yes I
accept your recommendation."* It lands in the spec repo, as this item always
said it would: `SPECIFICATION.md` states that descriptor `schema.fields` entries
**may** carry the I-ADOPT keys, and `descriptor_field_from_column()` in
`scripts/validate_package.py` learns them so the whole-list `!=` comparison stops
rejecting every annotated package. Neither mirror stops projecting the keys.

**This is the larger of the two possible changes, and the ruling does not shrink
it.** An exact comparison is what lets the validator reject an unknown key at
all, so relaxing it means deciding *which* extra keys are legal — a vocabulary
question rather than a code one. **Derive the allowlist from
`column_dictionary.schema.json`**, which is what the accepted recommendation
said: a hand-written list in the script is a second place for the dictionary
contract to live, and it will drift from the first.

*Before the ruling this item said: "the evidence assembled here favours
permitting the keys; it does not settle it." The evidence was reframed during
the 2026-08-21 recon from "two defensible readings" to that one-sided form, and
the ruling was made on the reframed item — recorded in
[questions.md](questions.md)'s notes-on-framing section, because a reader of the
ruling alone cannot see it.*

Two things a decider should have, because neither is obvious from the defect:
this is **not** a parity question (both mirrors fail the validator, so no
R↔Python comparison could surface it), and it is **not urgent in the way a
validator failure usually is** — nothing is red today, because the only
fixture under test carries no IRIs and no CI runs the script at all. It bites
the first real annotated package.

*Retires when:* an SDP with a fully annotated measurement column passes
`scripts/validate_package.py` — under the permit-the-keys ruling, so the script
is the thing that changes — and metasalmonpy's seventh key matches R's.

**#91 `validate_salmon_datapackage()`'s issue system is a different mechanism
in metasalmonpy, not a smaller one.** R's
`.ms_collect_package_validation_issues()` (`R/package-helpers.R:1995-2381`)
tags every finding with one of **eight** `issue_type` values — `dataset`,
`tables`, `dictionary`, `codes`, `resource`, `columns`, `primary_key`,
`composite_intent` — each carrying `table_id`, `column_name` and `value`, and
collects **all** of them before `.ms_abort_package_validation_issues()` reports
the total and previews up to ten. Python
(`metasalmonpy/package_io.py:1593-1668`) has four unconditional
`raise ValueError` sites and no collector, so it stops at the **first**
structural problem with an untyped string: a package with three bad tables
reports one, and the loop never reaches the other two. Fixing that first error
reveals the second, which is the debugging experience R deliberately does not
have.

**Two corrections to how this is usually stated.** First, *R accumulates and
Python raises* is not quite it — R accumulates and **then also aborts**. The
`issues` tibble R returns to a caller is reachable only when it is empty
(`R/package-helpers.R:1682-1685`), so the difference is not return-versus-raise
but **how much of the truth one failed call tells you**: R's one abort names
every problem, typed; Python's names one, untyped. Second, the gap on `main` is
wider than the category count suggests — metasalmonpy 0.1.8 returns
`pd.DataFrame(columns=["message"])`, a frame whose *column set* does not match
R's five, so nothing populates it at all. The single `columns` category and
R's column set arrive only with **unmerged rung 3** (PR #10), which is also
where the divergence is self-documented in a source comment
(`package_io.py:1555-1562`) — honest, but a comment is not a register entry.

**No rung owns this and no register row covers it.** Verified older than the
0.1.6 parity claim: `package_io.py` was added 2026-02-06 in the initial commit,
six months before the 0.1.6 alignment, and the function has been revised at
0.1.6, 0.1.8 and rung 3 without the control flow being reconciled. Registered
now as parity-deviations **row 41**. Severity: silent — a caller inspecting
`issues` on 0.1.8 gets an empty frame and cannot distinguish "validated clean"
from "this mirror does not report that category".

*Log it before any rung's verification depends on issue counts* — that is the
concrete hazard. A milestone check of the form "both sides report N issues"
would pass vacuously against 0.1.8 and compare one category against eight
after rung 3. *Retires when:* Python collects rather than raises, emits R's
eight categories with R's five columns, and a differential fixture pins both
sides to the same issue set for the same broken package.

**RETIRED 2026-08-22 — S10 chunk D (metasalmonpy PR #20).** Every clause of the
retire condition is met and was measured, not asserted:
`_collect_package_validation_issues()` accumulates all eight typed categories
into R's five-column frame, the validator aborts once carrying the total, a
ten-message preview and the full frame as `.issues`, and the differential ran
seventeen single-defect corruptions of the shipped example plus one stacked
five-issue package against metasalmon `main` @ `9d8f125` with **every issue row
matching field-for-field across all five columns, message bytes included**
(pinned in metasalmonpy's `tests/test_validation_hardening.py`). The hazard this
item asked to be logged before it bit is **lifted** in the same change: both
sides now report the same issue set for the same broken package, so a milestone
check comparing issue counts or categories is finally meaningful. **This item
had no R half** — it was entirely a statement about metasalmonpy's validator —
so closing the Python side closes it outright.

**One correction to how this item described the defect, on the evidence of the
same differential.** "Stops at the first structural problem" and "a package with
three bad tables reports one" were true of five of the eighteen fixtures.
**On the other thirteen Python reported *zero* issues and returned normally** —
duplicate `table_id`s, ghost table references, non-unique primary keys,
primary-key NAs, unlisted code values, composite-intent violations and a
two-row `dataset.csv` all validated clean. The severity note above was right
that a caller could not tell "validated clean" from "this mirror does not report
that category", but it attached that to the empty `issues` frame; the checks
themselves were the larger part of it. Parity row 41 is corrected to the
measured state in the same pass.

**#89 ~~smn's flat-TTL generator was nondeterministic~~ — FIXED 2026-08-21**
(smn PR #29, extracted verbatim from draft PR #27's build half and merged to
`main`). Measured before/after on the same content: 8 runs → 3 distinct hashes
pre-fix (the count varies with the per-process hash seed — same defect), 8 → 1
post-fix, byte-equal to the committed artifacts. One nuance the measurement
surfaced: on `main`'s pre-#27 content the defect was **dormant** — stable by
luck, because `smn:` only enters predicate position with #27's terms — so the
full `smn:` prefix compaction (PR #27 decision 5's "big diff") arrives when the
terms do, while the mechanism is already on `main`. Original entry follows for
the record.

**~~#89 original~~ smn's flat-TTL generator was nondeterministic, and nothing would have
caught it.** Merging triples without binding the source prefixes left rdflib to
number predicate namespaces `ns1:`/`ns2:`/… in **hash-randomized** order. Eight
runs on `main` produced one hash; eight runs on a branch that used `smn:` and
`dwc:` in *predicate* position for the first time produced **four distinct
hashes**. `verify-flat-ttl` would have failed in CI with no source change behind
it — a flake with a real cause, which is the worst kind to debug. Found and
fixed while reworking smn PR #27; the fix also stopped smn's own namespace
rendering as `ns3:` in its own published `docs/smn.ttl`.

*Why it stayed hidden:* the defect only manifests when a term from a bound
prefix appears as a **predicate**, and until that PR every smn predicate came
from an imported vocabulary. A determinism guard that only exercises the current
shape passes right up until the shape changes. This is the **third** ordering
defect in a sibling repo with no equivalent of metasalmon's C-collation
contract — see #82 for the second. *Retires when:* smn carries a determinism
rule of its own, or the hub adopts one that spans the ontology repos.

**#82 gcdfo's WSP review-artifact generator is nondeterministic.**
`scripts/generate_wsp_composite_escapement_review_artifacts.py` produced three
different `.graphml` files in three consecutive runs on unchanged input —
unordered edge emission. This is exactly the defect class metasalmon's
C-collation contract exists to prevent, in a sibling repo that has no equivalent
guard. Worth fixing *and* worth asking whether gcdfo should carry a collation
rule of its own; a hub-wide contract that only one repo enforces is a contract
in one repo. **Still open 2026-08-17** — gcdfo carries it as an Active entry in
its own `docs/tech-debt.md` with the retirement condition stated there (two
consecutive runs producing byte-identical `.graphml`).

**#84 A "Resolved" tech-debt entry that silently un-resolved. FIXED 2026-08-17
in gcdfo PR #83.** gcdfo's `docs/tech-debt.md` listed "2026-03-15 — `make
ci`/`make docs-refresh` WebVOWL churn stabilized" under *Resolved*, but it had
been broken since the term expansion introduced the duplicate `xsd:gYear`
datatype nodes, and stayed broken until #82. The entry now reads "first attempt;
superseded", says the fix did not hold, names PR #78 as what replaced it and PR
#82 as what repaired it, and records *why nobody noticed for five months* — PR
#78 rewrote the Resolution text **in place**, so the log kept describing a live
implementation and left no seam where a reader could notice the substitution.
The repaired entry also gained a re-verification hook, which is what the
original lacked. **Not yet released**, exactly as #81: PR #83 merged after the
0.0.9 tag, so a consumer reading the tag still sees the misleading *Resolved*
entry.

Keep the lesson, not the instance: **a resolution claim decays exactly like a
suppression does.** "Resolved" with no re-verification hook is an assertion
about the past presented as a fact about the present, and it discourages the
next person from checking. An in-place rewrite of a resolution is worse than a
stale one — a stale doc invites the question, a rewritten one destroys it.

**#83 A stale definition fixture in `test-term-search.R:614`.**
`gcdfo:ConservationUnit` now reads "A group of **wild salmon** sufficiently
isolated…" per the WSP; the inline fixture still carries the old "A group of
fish sufficiently isolated from other groups...". Cosmetic — the value is a
ranking *input*, never asserted — so nothing fails. Recorded because a fixture
that quotes an external definition will keep drifting silently, and the fix is
to stop quoting it verbatim rather than to re-sync the string.

**#75 `create_sdp()` auto-applies `method_iri` with no `metadata/methods.csv` —
SUPERSEDED by sdp-0.3.0, not fixed as filed.** Every artifact this item names is
gone from `main`: the dictionary has no `method_iri` slot, the
`metadata/methods.csv` registry was removed, and `write_sdp_methods()`,
`validate_sdp_methods()` and `.ms_measurement_supports_procedure_slot()` no
longer exist in `R/`. `.ms_create_sdp_llm_auto_apply_roles()` returns
`c("variable", "property", "entity", "unit")` and the deterministic seeded path
can no longer write a method IRI there is no registry for. The S5 card and the
r-native-review execplan both still credit their slice 1/slice 2 with fixing it;
what actually removed the defect was S8's breaking change. Recorded rather than
deleted because "fixed by the slice that was going to fix it" is exactly the
marker that goes unverified.

The original entry, kept for the reasoning:

Reproduced. The docs state that "constraint and method assessments always remain
manual", which holds only on the `llm_assess = TRUE` path, where
`.ms_create_sdp_llm_auto_apply_roles()` returns exactly
`c("variable", "property", "entity", "unit")`. On the **default seeded** path,
`apply_semantic_suggestions(strategy = "top", roles = NULL)` maps all six roles,
gated only lexically by `.ms_measurement_supports_procedure_slot()`, whose regex
includes `method|protocol|procedure|gear|estimated|enumerat|…`.

A column named `enumeration_method` gets
`method_iri = "REVIEW: https://w3id.org/smn/EnumerationMethod"`, and
`metadata/methods.csv` is never created (`write_sdp_methods()` has **zero
callers** in `R/`).

It bites at the worst moment: `validate_sdp_methods()` — which requires a
registered row in that file — runs on the **KNB publication path**
(`R/knb-publication.R:392`), not in `validate_salmon_datapackage()`. So the user
accepts the suggestion, strips the `REVIEW:` prefix exactly as the package's own
guidance instructs, passes validation, and fails at deposit after the whole
review is done. No test asserts a positive auto-apply for `method` or
`constraint`; the nearest one is green only because its `water_level` fixture
misses both regexes.

*Gate:* a test asserting that a method-ish column name does **not** receive an
auto-applied `method_iri`. **Fixed in slice 1** of
`knowledge/plans/2026-08-11-r-native-review-and-editing.md` by restricting the
default seeded path's auto-apply roles to match the LLM path's — review surfaced
that deferring it made slice 1's own acceptance criteria unsatisfiable, since the
marker it leaves blocks strict validation.



**#77 The SDP asks for tidy data and enforced almost none of it. FIXED in
0.2.6, with one claim corrected.** The original entry said `MISSING METADATA:`
placeholders ship unflagged. **That was only half true**:
`.ms_collect_review_placeholder_issues()` already reported them as errors under
`require_iris = TRUE`. What was missing was the *default* mode, which returned
zero issues and said nothing — so a package looked clean while stating in its own
metadata that its metadata was missing. Only that half was added, as a warning;
the strict path remains the single error channel rather than gaining a duplicate.

The other two gaps were real as stated and are now closed:

- **`primary_key` uniqueness is checked.** It was declared in `tables.csv` and
  read by nothing that tested it, so a table could claim a key and ship
  duplicates — "each observation forms a row" going unverified. Now an error.
- **Value-like column names are detected.** Bare year-like names, or a shared
  stem with numeric suffixes, in three or more columns. A **warning, never an
  error**: the SDP may accept untidy data, it must simply stop implying it
  checked.

*Foundation for the method model.* Its placement rule asks "is the method
constant within each table?", which is only sound when a table is a coherent
observational unit — which is why #77 was sequenced ahead of the method work in
roadmap S8.

**#76 SMN and gcdfo model methods in different styles — DECIDED 2026-08-13,
smn side implemented.** Brett ordered methods-as-SKOS ("migrate SMN methods
from OWL classes to SKOS concepts"); smn PR #22 migrated the six method
classes to `smn:MethodScheme` concepts (IRIs unchanged, instance-typed
`sosa:Procedure`), resolving the cross-repo pun.

**Half of the remaining code work rode S8 and half did not — check before
assuming this closed.** S8 shipped as 0.3.0 with the method-placement breaking
change, but **the metasalmon crosswalk retarget did not land with it**:
`R/nuseds-method-crosswalk.R` still emits `gcdfo:` CURIEs on every row (45
occurrences, zero `smn:`), so gcdfo remains the de facto method source exactly
as the entry below describes. That is the open half, and it now belongs to no
stream — S8 is closed. The history below is kept because the reasoning was
seductive and worth not repeating. Originally downgraded after review. The original entry claimed the
mismatch made the SDP rule unsatisfiable and broke SOSA consumers. **Both claims
were wrong**, and the correction is worth keeping because the reasoning was
seductive:

- *No package is unsatisfiable.* `validate_sdp_methods()`
  (`R/sdp-methods.R:444-483`) checks only that `method_iri` is an absolute IRI
  and is registered in `methods.csv`. It performs **no RDF typing check** — a
  gcdfo IRI satisfies the implemented rule.
- *No consumer breaks.* `sosa:usedProcedure` has `rdfs:range sosa:Procedure`, so
  RDFS entailment **infers** its object to be a `sosa:Procedure`. Being
  simultaneously a `skos:Concept` is not inconsistent — there is no disjointness
  axiom between them. A reasoner gets a procedure.

What is actually true, and still worth a decision:

- SMN models methods as an **OWL class hierarchy** —
  `smn:FishLengthMeasurementMethod rdfs:subClassOf sosa:Procedure` — while gcdfo
  models the same domain as a **SKOS concept scheme** —
  `gcdfo:AerialSurveyCount a skos:Concept ; skos:broader :EnumerationMethod`.
- Those styles are not interchangeable for querying. `skos:broader` carries no
  subclass entailment, so "is this a kind of aerial survey?" answers differently
  depending on which vocabulary a term came from — and metasalmon routes between
  both.
- SMN's procedure hierarchy is **thin** (two `sosa:Procedure` subclasses) while
  gcdfo holds the domain content, so the class-based route finds almost nothing.
- metasalmon's NuSEDS crosswalks point at the gcdfo terms (23/25 enumeration,
  22/27 estimate), making gcdfo the de facto source without that having been
  decided.

Separately: the rule's prose says `methods.csv` "records SOSA Procedure
resources", and nothing checks it — but `methods_are_sosa_procedures` has **zero
references in `R/`** and is one of the three never-executed rules. That gap
belongs to **#48**, not here.

*Gate:* a decision record naming which style is canonical for method concepts and
how the other maps to it, then a consistency check in both repos. No code change
is warranted until that decision exists — there is nothing broken to fix.

### Fixed in the development version (post-0.3.0)

**#88 The reproducibility-manifest validator is the one that never got its
dual-provenance half.** metasalmon accepted either implementation's provenance
for SSSOM and for measurement decompositions, but
`.ms_sdp_reproducibility_validate_manifest()` still required
`identical(generated_by, "metasalmon::write_sdp_reproducibility_manifest")`
plus a `metasalmon_version`, while metasalmonpy's validator already took both
writers. So the asymmetry ran one way: **a Python-written
`reproducibility/manifest.json` was rejected by metasalmon**, while an
R-written one was read fine by metasalmonpy. The honest-provenance ruling (PR
#43, register rows 11–12) had been applied writer-side to this artifact
without its read-side half — the same shape as the decomposition fix in PR
#44, one artifact later.

*Wider than the original item said.* `R/knb-publication.R:297` validates the
reproducibility manifest while planning a publication, so the defect blocked
KNB publication of any Python-written SDP, not only a direct
`validate_sdp_reproducibility_manifest()` call.

Fixed by giving the accepted writer set one owner rather than a third copy.
`R/provenance.R` holds the `generated_by` → version-field mapping, derived
from the bare function name so R's `metasalmon::` and Python's `.` calling
conventions are written once; all three validators now resolve their accepted
writers through it. The original item asked only that the reproducibility
validator accept both writers — three hand-maintained string lists is *how*
the ruling got applied twice out of three times, so consolidating them was the
part that stops it recurring. A deliberate exception is recorded at the SSSOM
site: it keeps a presence-only version check because metasalmonpy's `sssom.py`
asks exactly `provenance.get(version_key) is None`, and the two readers of one
artifact must accept the same manifests. That exception carries its own
retirement condition in `R/provenance.R`.

*An audit for a fourth one-sided site found none.* The package has exactly
three writer-provenance validate sites and three write sites; `written_by`,
`produced_by`, `created_by`, `producer` and `software` appear nowhere. The
other metasalmon-branded literals are write-only (UUID and fingerprint
preimage salts, user agents) or not identity gates at all — `.metasalmon-package`
is tested with `file.exists()` and its contents never compared.

*Proof:* `tests/testthat/test-reproducibility-manifest.R` validates a
metasalmonpy-provenanced manifest and keeps unknown generators, absent
versions, whitespace-only versions and a writer versioned under the *other*
implementation's field rejected; `tests/testthat/test-provenance.R` pins the
accepted set for all three artifacts and fails if any validator re-types a
writer literal instead of sharing it. Verified to fail on a build with only
the reproducibility validator reverted — the regression test errors and the
structural guard reports two re-typed literals. Verified end to end as well,
which is the thing the item was really about: metasalmonpy 0.1.8 wrote a
manifest over a tree R had written one for, R validated it, and the two
manifests were identical apart from the two provenance values. Registered as
parity-deviations **row 29**, whose retirement condition this discharges.

**#85 Four IRI validators shared one regex shape and two different answers.**
`^[A-Za-z][A-Za-z0-9+.-]*:[^[:space:]]+$` appeared in four places with the same
intent — reject an IRI containing whitespace — but `R/sdp-extension-helpers.R`
passed `perl = TRUE` while `R/eml-export.R` and `R/sssom.R` ran under TRE, and
PCRE and TRE do not agree on what `[[:space:]]` covers. Re-verified by running
both engines on R 4.5.2: `U+00A0` and `U+2007` agree (neither engine treats them
as whitespace, so both accept), but **`U+3000` IDEOGRAPHIC SPACE and `U+1680`
OGHAM SPACE MARK do not** — PCRE treats them as non-space, so the SDP-extension
validator accepted an IRI containing either while EML export and
`validate_sdp_sssom()` rejected the same string.

Fixed by dropping `perl = TRUE` from `.ms_sdp_extension_is_absolute_iri()`,
which makes it stricter rather than looser: RFC 3987 requires those characters
to be percent-encoded, so accepting them was the wrong answer, and rejecting
them was already what the other validators did. The direction mattered — the
alternative, converting the TRE sites to PCRE, would have silently invalidated
metasalmonpy's enumerated `R_SPACE_CLASS` and tripped row 28's own retirement
condition.

The shape now has one owner, `R/iri-predicates.R`, called by the SDP-extension,
EML and SSSOM validators. EML and SSSOM behaviour is unchanged; only the
SDP-extension answer moved. *Note the original item's fourth site was described
wrongly:* `R/measurement-decompositions.R` runs under **perl**, not TRE, and it
tests a narrower shape (`scheme://` or `urn:` only). Its ASCII whitespace class
is deliberate and mirrored character-for-character in Python, so it is
documented as a non-caller rather than folded in — three of four consolidated,
the fourth exempted with its reason recorded at the site.

*Proof:* `tests/testthat/test-iri-predicates.R` pins the per-character answer
for `U+0020`, `U+0009`, `U+00A0`, `U+2007` and `U+3000` (built with
`intToUtf8()`, because a literal U+3000 in a test file is exactly the invisible
thing at issue), asserts the SDP-extension validator and the *real*
`.ms_eml_supplementary_objects()` path agree on all five, and guards the shared
predicate against `perl = TRUE` being reintroduced. Verified to fail on a build
with only the extension site reverted. Found while reconciling the parity
register, where the mismatch showed up as a Python/R difference that turned out
to be an R/R difference.

*And is a Python difference after all.* Checking the register's claim that
"Python mirrors no such function" refuted it: `metasalmonpy/sdp_methods.py:95`
mirrors this exact helper and uses Python's `\s`, which matches neither R
engine. The fix **narrowed** that gap from 23 disagreeing codepoints to 8 rather
than opening it, so it needed no Python change to land — but the residual 8 are
now item **#86** and parity-deviations **row 33** (numbered 29 until 2026-08-17,
when metasalmonpy's 0.1.8 rows 29–32 claimed that number).

### Fixed in 0.2.5

**#73 Credential redaction missed qualified token names.** `dataone_token`
redacted; `dataone_test_token` and `DATAONE_TEST_TOKEN` did not. Captured HTTP
and provider errors are stored in returned tibbles and written to CSV, so this
leaked at rest. Fixed structurally — any qualified `*_token` name is covered, so
a credential named later needs no further patch — with a required prefix segment
so `token = 42` in prose is untouched.

**Both redactors are now one.** `.ms_knb_redact()` was a second implementation of
the same contract and is deleted; its callers use `.ms_redact_secrets()`, which
is strictly stronger (it also caught `x-api-key`, provider keys, and JSON forms
the KNB version missed). Two implementations of one security contract is how the
gap arose, and a test now asserts the deleted function stays deleted.

Unblocks roadmap **S3**. *Discharged 2026-08-22:* S3's environment registry
reads `dataone_test_token` as the test-node credential, so the redactor that
covered a token name nothing read now covers one the package actually uses.

### Open — the S2 correctness cluster

**These four were sitting under the "Fixed in 0.2.5" heading with no heading of
their own, so the file read as if they had shipped with #73. They have not**
(re-verified on `main` 2026-08-17); roadmap
[S2](sequences/s2-correctness-debt.md) is the stream that owns them and still
has no execplan.

**#53 `infer_column_role()` classifies 4-digit measurement columns as
`temporal`**, removing them from the entire semantic pipeline. Still live:
`.ms_values_look_yearish(col)` returns `"temporal"` on value shape alone
(`R/dictionary-helpers.R`, the role heuristic below the identifier checks).

**#55 `apply_salmon_dictionary(strict = TRUE)` never errors on the common
coercion failures**, and the codes step silently `NA`s unlisted values. Still
live, and the mechanism is worth stating because it looks handled: the coercion
is wrapped in `tryCatch(..., error = ...)` whose handler *does* branch on
`strict` and `cli_abort`s — but `as.integer("abc")` and friends **warn and
return `NA`** rather than erroring, so the handler never fires for exactly the
failures the argument is supposed to catch. A `warning =` handler, not a
different message, is the fix (`R/dictionary-helpers.R`, the coerce-type block
in `apply_salmon_dictionary()`).

**#56 Semantic retrieval issues one serial `search_fn()` call per target** with no
deduplication of identical `(query, role, sources)` tuples. Still live: the
`purrr::map_dfr()` over `seq_len(nrow(targets))` in `suggest_semantics()` calls
`.ms_retrieve_semantic_target_candidates()` once per row
(`R/semantics-helpers.R`). Plus a cluster of smaller per-call costs listed in
the review (`term_search.R:341,1763,2190`, `semantic-suggestions.R:863,920`).

**#57 Assorted smaller correctness items** carried verbatim from the review:
locale-dependent DataONE plan fingerprint inputs now fixed under #40, but
`dwc_dp_build_descriptor(validate = TRUE)` still discards its validation result
and does not declare its Python toolchain in `SystemRequirements`; `llm_top_n`
cannot widen the shortlist on the direct `suggest_semantics()` path;
`find_terms()` does not check `parallel::mclapply` worker failure; ICES helpers
error instead of degrading on a missing column; the composite-intent gate's
`optional_hint_fields` is inert.

### Open — the 2026-08-21 example-and-validator recon

**Every item below was reproduced by executing the tools, not by reading
them**, and the reason is worth stating once for the group: each one is
invisible to `devtools::test()` on `main`, and #100 is why. The package ships
two examples, ships a validator, and never points the second at the first.

**#95 `create_sdp()` writes `codes.csv` rows for columns its own
`infer_column_role()` typed `attribute`, and the spec requires `categorical`.**
On the bundled 173-row example this is **22 of the 27** errors
`scripts/validate_package.py` reports, one per `codes.csv` row across **six**
columns — `AREA`, `SPECIES`, `RUN_TYPE`, `ESTIMATE_METHOD`,
`ESTIMATE_CLASSIFICATION`, `ESTIMATE_STAGE`:

```
metadata/codes.csv row 2 targets a non-categorical or unknown column:
  ('dataset-1', 'nuseds_fraser_coho', 'AREA').
```

The other five errors are the four blank measurement IRIs and the placeholder
license, both of which `create_sdp()` announces on the console. These 22 it
does not announce — it emits `column_role = "attribute"` in the dictionary and
code rows for the same column in the same call, prints "Dictionary validation
passed", and hands back a package that is internally inconsistent by the
spec's own rule. The count scales with the data, not with
the defect: the same call on the 30-row example produces **157** of these
across **14** columns, because that file has more free-text columns. Six and
22 are properties of one example, the mechanism is the durable part.

Which side is wrong is a real question — `infer_column_role()` typing an
enumerable string column `attribute`, or `create_sdp()` seeding codes for
non-categorical columns — and it is close to #53, which is the same heuristic
mis-typing a different column shape. *Retires when:* `create_sdp()` on both
bundled examples produces no `targets a non-categorical or unknown column`
error, under whichever of the two is corrected.

**Which example this bites first is now ruled.** Brett promoted the **173-row**
`nuseds-fraser-coho-2023-2024.csv` to gold standard on 2026-08-24
([Q4](questions.md)), so the **22 errors across six columns** are the ones
standing between S12 and stage 1 of its finish line; the 30-row sample's 157 are
a speed fixture's problem and rank behind them. The retirement condition still
names **both** examples deliberately — fixing the generator fixes both, and a
fix that only cleaned the promoted file would be a fix to the data, not to the
defect.

**#97 `detect_semantic_term_gaps()` returns zero gaps when the search returned
zero candidates** — it is structurally blind to precisely the case a term
request exists for. Both entry paths short-circuit on empty input:
`R/term-request-helpers.R:109-110` returns `.empty_term_gap_result()` when
`suggestions` and `assessments` are both empty, and `:206-208` does the same
when `suggestions` is empty and no assessment carries `request_new_term`.

Verified 2026-08-21 with a `search_fn` returning zero rows for a column
described as a concept with no ontology term: `suggestions = 0`,
`gaps = 0`, and the console says *"No semantic suggestions found for missing
semantic metadata."* — which reads like a clean result. A gap is currently
detectable only when retrieval found *something* and it was judged
insufficient; a term that no vocabulary contains at all produces silence. That
inverts the pipeline `AGENTS.md` describes (`detect_semantic_term_gaps()` →
`render_ontology_term_request()` → `submit_term_request_issues()`), whose
whole purpose is surfacing terms that do not exist.

*Retires when:* a target with an unfilled required IRI field and zero
candidates appears in the gap result, with a `gap_detection_basis` that
distinguishes "nothing found" from "found and rejected", and a test pins it.

**FIXED in the development version, 2026-08-21** (branch
`fix/2026-08-21-recon-defects`), exactly per the retire condition:
`suggest_semantics()` attaches its discovered targets as a `semantic_targets`
attribute, and `detect_semantic_term_gaps()` reports any target with no
retrieval evidence at all as `gap_detection_basis = "no_candidates"` —
distinct from `llm_request_new_term` ("found and rejected"). Checked before
`min_score` filtering so a below-threshold candidate still counts as found;
the explicit-`suggestions` path keeps its historical behaviour; the 33-column
row contract is unchanged. Tests in `test-term-request-helpers.R`, verified
RED first (gaps = 0 for the zero-candidate column). **metasalmonpy has the
same defect, measured 2026-08-21**: the identical reproduction returns 0 gap
rows and no `semantic_targets` attribute exists there — S10 catch-up work.
**Mirror half discharged 2026-08-22** (metasalmonpy PR #16, S10 chunk B):
`suggest_semantics()` attaches `semantic_targets` and
`detect_semantic_term_gaps()` reports any target with no retrieval evidence
at all as `gap_detection_basis = "no_candidates"` — per target, not per
column, checked before `min_score`, the explicit-`suggestions` path keeping
row-in/row-out — differential-matched against metasalmon `main` (`9d8f125`)
including the `no_candidates`/`candidate_gap` split and the role filter.
Both halves are now closed; nothing remains open under this number.

**#98 The shipped 30-row example and its bundled dictionary fail
`validate_salmon_datapackage()` in both modes.** Writing
`inst/extdata/nuseds-fraser-coho-sample.csv` with the bundled
`dataset.csv` / `tables.csv` / `column_dictionary.csv` / `codes.csv` and
validating it aborts with 2 structural issues at `require_iris = FALSE` and
again at `require_iris = TRUE`:

```
Table 'nuseds_fraser_coho' column 'START_DTT' declares value_type 'date'
  but 14 values did not satisfy it (unparseable as that type):
  06-NOV-01, 03-NOV-18, 07-OCT-16.
```

The CSV stores Oracle `DD-MON-YY` dates as NuSEDS exports them; the bundled
dictionary declares `value_type: date`. The strict spec validator rejects the
same 28 values plus the `FULL_CU_IN` codes that the bundled `codes.csv` does
not enumerate. So the artifact the docs hand a new user as the fastest
walkthrough does not pass the package's own final gate. Note the *fuller*
173-row example does not have this defect — `data-raw/` converts `START_DTT`
and `END_DTT` to ISO there — which is why this survived: the two examples
disagree and only one is exercised.

Two defensible resolutions and they are not equivalent: declare the two
columns `string` in the bundled dictionary (honest about NuSEDS bytes,
loses the date semantics), or convert the sample CSV to ISO as the fuller
example already does (changes a file kept "unchanged for backwards
compatibility"). *Retires when:* both bundled examples pass
`validate_salmon_datapackage()` in both modes, pinned by the test #100 asks
for.

**FIXED in the development version, 2026-08-21** (branch
`fix/2026-08-21-recon-defects`). The data was converted, not the dictionary:
`date` is the correct declaration for `column_role: temporal` columns, the
fuller example's derivation already converts the same columns, and retyping
them `string` would teach discarding date semantics. The 28 values were
converted with the same `%d-%b-%y` parse the temporal inference uses (century
pivot verified: `03-DEC-97` → `1997-12-03`); every other byte is unchanged,
and the DD-MON-YY parsing test now carries an inline Oracle-format fixture so
that coverage survived. The 30-row example now passes **both** modes — its
last strict blocker, a blank `tables.csv$observation_unit_iri`, was filled
with the released, resolving `smn:EscapementEstimate` during the #100 work.
The retire condition is met in the only form the examples support: the
fuller example is a documented *starter* whose strict failure is by design,
and the #100 tests pin it exactly. The "unchanged for backwards
compatibility" README note is replaced by a dated conversion record.
metasalmonpy, measured 2026-08-21: ships the same DD-MON-YY sample, but the
failure does not reproduce there because **its validator does not enforce
`value_type: date` parsing at all** — a validator-parity divergence for S10 —
and its bundled `column_dictionary.csv` is corrupt as shipped (unquoted
description commas shift two rows; pre-0.3.0 `method_iri` header).
**Both metasalmonpy halves are now discharged (2026-08-22):** S10 chunk A
(PR #14) replaced the bundled dictionary with a byte-copy of metasalmon `main`,
taking the corruption and the stale header with it, and S10 chunk D (PR #20)
made `value_type: date` a structural `columns` issue that aborts rather than a
mismatch reported in a side-channel frame while the call returned normally.

**#99 Two IRIs that 404 ship in `inst/extdata/column_dictionary.csv`, and two
sibling repos copy them.** `https://w3id.org/example/salmon#AbsoluteSpawnerAbundance`
and `https://w3id.org/example/salmon#WildOriginConstraint`, both **HTTP 404**
when fetched 2026-08-21 (`https://w3id.org/smn/Abundance` in the same file
returns 200, so the check is discriminating). The same two values are in
`metasalmonpy/data/column_dictionary.csv` and
`smn-data-pkg/examples/minimal-example/metadata/column_dictionary.csv` —
the ecosystem's three "here is what a good dictionary looks like" artifacts
all carry unresolvable IRIs under a namespace nobody owns.

They are recognisably placeholders, which is the problem: `REVIEW:` is this
package's marker for an unfinished IRI and strict validation rejects it, while
a plausible-looking `w3id.org` IRI passes every check the package has. Two
routes and they are not the same kind of work: make them visibly fake (a docs
fix), or mint real terms for an absolute spawner abundance and a wild-origin
constraint — which is an ontology question for `smn`, and belongs in the gap
register before it belongs in a CSV. *Retires when:* every IRI in the three
shipped example dictionaries resolves, and a network-gated test asserts it.

**FIXED for this repo's dictionary in the development version, 2026-08-21**
(branch `fix/2026-08-21-recon-defects`) — a third route the item did not list:
the terms needed no minting because released equivalents already exist.
`term_iri` → `gcdfo:SpawnerAbundance` (`owl:Class` in the gcdfo 0.0.9 release
artifacts; `term_type` corrected `skos_concept` → `owl_class`) and
`constraint_iri` → `smn:NaturalOrigin` (released `skos:Concept`, "born and
reared in the wild"), both verified resolving before use. `property_iri` was
deliberately left as `smn:Abundance` so open question Q9 is not prejudged;
the term slot holding the most specific released concept is defensible under
either Q9 answer. The network-gated test
(`test-example-iri-resolution.R`) fetches every unique IRI document across
all four shipped example metadata files, verified RED with exactly
`https://w3id.org/example/salmon (404)`. **The other two repos remain**:
metasalmonpy's `data/column_dictionary.csv` carries the same two 404 IRIs
(plus corrupt rows and the stale header — measured 2026-08-21), and
smn-data-pkg's minimal example carries them per the evidence above. The item
stays open for those two dictionaries.

**#100 No test round-trips either bundled example through a validator.**
`grep` over `tests/testthat/` finds twelve references to the example CSVs and
not one of them calls `validate_salmon_datapackage()` on a package built from
them; none calls the spec validator at all. `test-package-helpers.R:525-544`
comes closest — it runs `create_sdp()` on the 30-row sample and then asserts
two inferred `temporal_*` strings and one file's existence.

This is the reason #95, #96 and #98 were all invisible to a green suite, and
it is the same lesson the 0.2.0 pass recorded at the top of this file ("the
suite … never round-trips a package through its own validator") arriving a
second time in a place the earlier fix did not reach. A test that builds each
example and validates it would have caught three of the items in this section
on the day they were introduced.

*Retires when:* a test creates a package from each bundled example and asserts
`validate_salmon_datapackage()` passes in both modes; the spec-validator leg
may be network- or dependency-gated, but the R leg must not be.

**FIXED in the development version, 2026-08-21** (branch
`fix/2026-08-21-recon-defects`). `test-example-round-trip.R` builds a package
from each bundled example and validates it, no network or optional deps
needed: the 30-row example must pass **both** modes with zero issues (its
last strict blocker, blank `tables.csv$observation_unit_iri`, was filled with
the released `smn:EscapementEstimate`), and the 173-row starter must pass
lenient and fail strict with *exactly* its one documented failure
("Measurement columns require term_iri; missing in rows 8."), so drift in
either direction is caught. Also caught in passing: the shipped `codes.csv`
declared 9 header columns over 8-field rows (26 parsing problems per read);
repaired, and a well-formedness test now covers every shipped example CSV.
The spec-validator leg was not added — the R leg was the mandatory half.
metasalmonpy, measured 2026-08-21: it has no example round-trip test either,
and one would fail immediately on its corrupt bundled dictionary — S10 work.
**Discharged 2026-08-22 by S10 chunk D (PR #20):**
`tests/test_example_round_trip.py` builds an SDP from the shipped example and
validates it in both modes — strict pinned to **zero** issues, lenient pinned to
silence — with a well-formedness gate over every shipped metadata CSV. One
asymmetry, not a gap: metasalmon pins its fuller 173-row example to one known
strict failure, and that example is not shipped in Python (parity row 46, open),
so the tiny example's zero-issue pin is the whole gate there.

**#101 `ESTIMATE_CLASSIFICATION` has no crosswalk, and the terms it needs are
released.** `R/nuseds-method-crosswalk.R` covers `ENUMERATION_METHODS` and
`ESTIMATE_METHOD`; `ESTIMATE_CLASSIFICATION` appears **nowhere in `R/`**. The
bundled 173-row example's values are `TRUE ABUNDANCE (TYPE-1)`,
`RELATIVE ABUNDANCE (TYPE-3)`, `(TYPE-4)`, `(TYPE-5)` and
`NO SURVEY THIS YEAR` — they name the type in the string — and
`gcdfo:Type1`–`gcdfo:Type6` are `skos:Concept`s under `gcdfo:EstimateType`
in the **released** gcdfo 0.0.9 (`gcdfo:Type1` is labelled "Type-1, True
Abundance, high resolution").

**This is a wiring gap, not an ontology gap**, and the distinction is the
point: it must not be filed as a term request. The terms exist, are released,
and are labelled to match. Only `NO SURVEY THIS YEAR` may need a decision — it
is an absence-of-observation marker rather than an estimate type, and mapping
it to a `Type` concept would be wrong. *Retires when:*
`nuseds_estimate_classification_crosswalk()` (or an equivalent) maps the five
observed values, `create_sdp()` wires it as it wires the estimate crosswalk,
and the disposition of `NO SURVEY THIS YEAR` is recorded rather than guessed.

**FIXED in the development version, 2026-08-21** (branch
`fix/2026-08-21-recon-defects`), per the retire condition:
`nuseds_estimate_classification_crosswalk()` maps the observed values from
both bundled examples plus `TYPE-2` (completing the released Hyatt series)
onto `gcdfo:Type1`–`Type6`; `NO SURVEY THIS YEAR` is recorded as `NA` with
its absence-marker rationale, `UNKNOWN` stays `NA` as an administrative
label, and the two `RELATIVE: … MULTI-YEAR METHODS` values link at scheme
level (`gcdfo:EstimateType`), the estimate crosswalk's own convention for
`Cumulative CPUE`. Wired at the same call site as the estimate crosswalk via
a shared prefill engine (`.ms_prefill_legacy_code_terms()`), added to
`collation_sensitive_fns`, verified RED first. metasalmonpy, measured
2026-08-21: no classification crosswalk exists there — and neither crosswalk
it *does* have is wired into its create_sdp path at all (see #102's note).
**Mirror half discharged 2026-08-22** (metasalmonpy PR #16, S10 chunk B):
`nuseds_estimate_classification_crosswalk()` ported with the same recorded
non-mappings (`NO SURVEY THIS YEAR` and `UNKNOWN` stay `NA`) and the
scheme-level multi-year rows, wired through the ported shared prefill engine;
the crosswalk frame matched R's value-for-value **and column-and-order
exact** against metasalmon `main` (`9d8f125`). Both halves are now closed.

**#102 "Fence" is in the crosswalk `create_sdp()` does not use.**
`nuseds_enumeration_method_crosswalk()` maps `"Fence"` → family `FS` →
`gcdfo:FixedSiteCensusManual`. The only crosswalk `create_sdp()` actually
wires is `nuseds_estimate_method_crosswalk()`
(`R/package-helpers.R:1897`, the sole reference to either function outside
their own file), and that one has no `"Fence"` row — its `FS` family is
`Fixed Site Census` / `Resistivity Counter` / `Video Counter`. So a NuSEDS
column recording `Fence` gets no `term_iri`, and the crosswalk that would have
supplied one is exported, documented, tested and unreachable from the package
path.

Whether `"Fence"` belongs in the estimate crosswalk is not obvious — it is an
enumeration method, and NuSEDS files record it under `ENUMERATION_METHODS` —
so the real gap is that `create_sdp()` reads only one of the two columns.
*Retires when:* `create_sdp()` applies the enumeration crosswalk to
`ENUMERATION_METHODS` values as it applies the estimate crosswalk to
`ESTIMATE_METHOD`, with a test that a `Fence` code row gets its IRI.

**FIXED in the development version, 2026-08-21** (branch
`fix/2026-08-21-recon-defects`), by wiring, not by row — `Fence` is an
enumeration (field) method and adding it to the estimate crosswalk would have
misfiled it. `.ms_prefill_legacy_enumeration_method_code_terms()` rides the
shared prefill engine and matches on the word `enumeration` alone, because
NuSEDS names the column in the plural (`ENUMERATION_METHODS`) and a
`\bmethod\b` test can never match "methods" — a `c("enumeration", "method")`
rule would have been silently dead, the same shape of failure the role-hint
layer teaches. Test: a `Fence` code row gets `gcdfo:FixedSiteCensusManual`,
explicit IRIs win, combined values ("Stream Walk, Other") stay blank;
verified RED first. **metasalmonpy's exposure is broader, measured
2026-08-21**: its two crosswalks are data-only exports referenced nowhere
else — Python wires NO crosswalk into its package path, not even the estimate
one R has wired all along, and `PARITY.md` records no such difference, which
is itself a mirror-contract violation to resolve in S10.
**Mirror half discharged 2026-08-22** (metasalmonpy PR #16, S10 chunk B): the
shared prefill engine is ported (`package_io._prefill_legacy_code_terms`,
mirror of `.ms_prefill_legacy_code_terms`) with all three wrappers —
estimate method (the pre-existing gap), classification (#101), and
enumeration, matching on `enumeration` alone for the same plural-header
reason as R — wired at the same point in the artifact path (after codes
settle, before semantic seeding; explicit caller IRIs never overwritten),
with identical `term_iri` fills against metasalmon `main` (`9d8f125`). The
previously unregistered wired-nothing divergence is now **parity-deviations /
`PARITY.md` row 47**, a permanent record with no retirement condition. Both
halves closed.

### Open — P3 (R-package and API hygiene)

**#58 No condition classes anywhere.** 415 `cli_abort` + 38 `cli_warn` + 3
`rlang::abort`, all unclassed, so callers cannot `tryCatch` selectively — a real
problem for a package meant to be driven from scripts and agents. Breaking-ish
for anyone matching on message text, so it wants a major bump.

**#59 Undocumented configuration and global-state mutation.** Nine
`metasalmon.*` options and fourteen environment variables with no registry, no
`.onLoad` defaults, and no help topic. `.search_bioportal()` permanently writes a
flag into the user's `options()`; `.ms_chat_new_session_id()` calls `sample()` and
advances the user's RNG stream. Both are CRAN-policy violations.

**#60 Example and API-surface gaps.** 22 of 30 documented topics wrap their entire
example in `\dontrun{}`, including examples that run offline in under a second,
so `R CMD check` validates almost no public example code; 15 of 45 exports ship no
examples. `NAMESPACE` blanket-imports the superseded `httr` while `httr2` is also
a hard Import. `DESCRIPTION` has a hand-written `Author:` naming someone absent
from `Authors@R`. No documented naming convention for the exported surface.

**One clause closed 2026-08-25:** `semantic_suggestions` /
`semantic_llm_assessments` were attributes with no accessor. They now have
`semantic_suggestions()` and `semantic_llm_assessments()`, which also read a
written package's `semantic_suggestions.csv` and are deliberately `NULL`-on-absent
so they are drop-in replacements for the `attr()` calls `?suggest_semantics`
documents. This was #74's hard prerequisite — the review queue had to read those
attributes through a supported accessor. Every other clause of this item stands:
the `\dontrun{}` ratio, the 15 exports with no examples, the blanket `httr`
import, and the hand-written `Author:`.

**#112 `migrate_sdp_methods()`'s no-op report shape is internally
inconsistent.** The nothing-to-migrate early return builds `report$tables` as
a **two**-column frame — `table_id`, `method_iri` (`R/sdp-methods.R:299`) —
while every populated path builds **three**, adding `columns` (`:335`). A
caller who reads `report$tables$columns` therefore gets `NULL` exactly when
the package was already clean, the branch least likely to be tested; low
severity, since the frame is empty there either way, but it is an exported
return value with two shapes. Found 2026-08-22 by S10 chunk A's nine-case
migration differential (metasalmonpy PR #14): Python's no-op frame carried
the third column — the internally *consistent* shape — and was changed to
mirror R, because under the amended mirror contract which side is right is a
ruling, not an implementer's call. Deliberately not fixed unilaterally here
for the same reason. *Retires when:* the no-op branch returns the same
three-column empty frame as the populated paths (or a logged ruling says the
shapes deliberately differ), metasalmonpy mirrors the same shape in the same
stream, and a test on each side pins the column set of both branches.

**#118 A reviewed semantic decision was overruled by the unattended auto-apply
heuristic. FIXED 2026-08-25, in the change that found it.** Severity when live:
**high**, and invisible — the symptom was a term the user had read the definition
of and explicitly accepted simply not appearing in the dictionary, with the only
feedback being a count of rows that "did not meet the requested filters".

`apply_semantic_suggestions()` ran `.ms_filter_auto_apply_suggestions()` on
every strategy, including `strategy = "reviewed"`. That helper is the
*unattended* gate: a lexical compatibility heuristic answering "is this seeded
top-1 hit safe to write into a dictionary nobody has looked at". On the reviewed
path the premise is the opposite — a human looked at it — so the heuristic was
overruling the decision it exists to substitute for. It vetoes every suggestion
for an `identifier` or `temporal` column outright, and measurement columns
whenever the label does not lexically match.

Found while building `apply_sdp_semantics()` (stream S5), which would have
silently dropped accepted terms for exactly this reason. Fixed by exempting
`reviewed`; `top` keeps the gate, which is the whole reason the gate exists.
Pinned in `tests/testthat/test-metadata-write.R` with both halves asserted —
`reviewed` applies, `top` still vetoes — because a fix that only asserted the
new behaviour would not notice the gate being removed entirely.

Nobody could have been relying on the old behaviour: nothing in the package
wrote the `decision` column `strategy = "reviewed"` filters on, so the path was
unreachable in practice.

**The mirror has the identical defect, measured 2026-08-25 and not edited
here.** `metasalmonpy/semantics.py:1294` calls
`_filter_auto_apply_suggestions(out, suggestions_df)` unconditionally, with no
strategy guard, against the same `{"top", "reviewed", "llm"}` set
(`semantics.py:1214`) and the same lexical helper (`semantics.py:487-530`). It
bites there for the same reason it bit here: the helper only early-returns for a
row with no `target_sdp_field`, and every column-level target `suggest_semantics`
emits sets one (`semantics.py:759`, `:814`).

**Two things make this more than a straight port, and both are easy to miss.**
(1) Python's docstring at `semantics.py:1196-1204` *documents the current
behaviour as intended*, citing `PARITY.md` row 57 — so the fix is a guard **and**
a docstring correction, not a guard alone. (2) **`PARITY.md` row 31
(`PARITY.md:65`) claims the reviewed strategy is "verified identical to R's
output for all three strategies".** That claim is true today, because both sides
still have the defect at the 0.4.0 both packages claim. It becomes **false the
moment metasalmon releases** this fix, and nothing will say so. Row 31 must be
**amended** in the mirror stream, not merely supplemented with a new row — a
stale "verified identical" is worse than a missing row, because it tells the
next reader the question has already been asked and answered.

Why the Python suite is green over it: the reviewed-strategy fixture
(`tests/test_semantics.py:457-482`) is compatible-by-construction — its column
description at `:448-451` lexically contains both accepted search queries, so
the heuristic happens to pass every accepted row. It never exercises
accept-then-drop.

*Retires when:* fixed here (done); metasalmonpy adds the same guard, corrects
the `semantics.py:1196-1204` docstring, amends `PARITY.md` row 31, and pins the
accept-then-drop case with a fixture whose label does **not** lexically match
the column. That fix is independently shippable ahead of the review-flow port —
it depends on none of that surface existing.

### Open — P4 (ecosystem: spec, ontologies, workshop, governance)

**#61 Ecosystem findings.** 37 verified findings across `smn-data-pkg`,
`salmon-domain-ontology`, `dfo-salmon-ontology`,
`salmon-data-standards-workshop`, and cross-repo governance, plus 27
finder-only ontology findings that still need verification (#44 verified three of
them). These do not live in this repo and are tracked in
`knowledge/plans/2026-08-10-comprehensive-ecosystem-review.md` §3–§7. The five
highest-leverage, in order: vocabulary-release pinning is impossible today
(which metasalmon's own KNB path requires); `datapackage.json` carries none of
SDP's semantic payload; the `smn:`/`gcdfo:` boundary is not machine-checkable;
no workshop episode is executable; and `smn-data-pkg` has no LICENSE, CI, or
Pages configuration.

#### smn-data-pkg (verified on `main`, 2026-08-21)

**#116 The reviewed closure has no producer and no documentation, so the
publication path is unreachable from the published docs.** Found 2026-08-25
while taking the Fraser coho example to a KNB test-node dry run. Severity:
**high** — it is not a defect in any one function, it is a hole in the golden
path, and the symptom is that a user who does everything the vignette says gets
`metadata/semantic_vocabulary.csv does not exist` with nowhere to go.

`write_eml_from_sdp()` and `publish_sdp_to_knb()` both require a reviewed
closure. Three files carry it, and **metasalmon validates all three and writes
none of them**:

- `metadata/semantic_vocabulary.csv` — read by `.ms_eml_read_vocabulary()`
  (`R/eml-export.R:1215`), required by `.ms_knb_sdp_artifact_paths()`
  (`R/knb-publication.R:271`). It is *deliberately* excluded from
  `.ms_package_managed_paths()` (`R/package-helpers.R:448`), so the exclusion is
  intentional; what is missing is anything that fills the gap it leaves.
- `reviewed_semantic_selections.csv` — read by
  `.ms_eml_read_semantic_review()` (`R/eml-export.R:1040`).
- `metadata/eml-mapping.yml` — the one with a real story: a template ships at
  `inst/extdata/eml-mapping-template.yml` and the post-review vignette says to
  copy and edit it.

Four separate things are wrong, in descending order of how badly they block:

1. **Neither closure CSV appeared in any vignette or the README** before this
   item was filed — `git grep semantic_vocabulary vignettes/ README.md`
   returned nothing. The post-review vignette walked from strict validation
   straight to the EML sidecar. Partially discharged 2026-08-25: that vignette
   now has a "reviewed closure" section stating both files, their columns, and
   the two canonical IRI sets. The **workshop** carries it too as of
   2026-08-25 (`salmon-data-standards-workshop` PR #5): session 6 states the
   gap in a callout and tells learners plainly that a complete deposit is not
   reachable unaided, which is why its four publication chunks stay
   `eval = FALSE`. **Documentation is not a producer**, so the item stays
   open — and it now has two downstream surfaces that must be revisited when
   a producer ships.
2. **`reviewed_snapshot_sha256` cannot be computed by any exported function.**
   `.ms_eml_vocabulary_snapshot_sha256()` (`R/eml-export.R:1182`) is a verifier
   only. Its sole producing caller in the whole repo is
   `tests/testthat/helper-eml.R:134`. A user's only options are to hand-write a
   SHA-256 into a CSV or to reach into `metasalmon:::`, and the first of those
   is not a workflow.
3. **The two canonical sets are derivable only from internals.** The vocabulary
   must equal `.ms_eml_canonical_measurement_iris()` exactly and the ledger must
   equal `.ms_eml_canonical_review_targets()` exactly, both internal. The sets
   legitimately differ (`observation_unit_iri` is a review target but not a
   measurement term), so a user cannot even reason one from the other.
4. **The closure demands provenance evidence for vocabularies `find_terms()`
   cannot search.** `find_terms()` supplies six of the eight evidence fields
   (`label`, `definition`, `source`, `ontology`, `resource_kind`, `type_iris`)
   for `smn`/`gcdfo`, but `native_type` and `source_url` are always hand-supplied,
   and QUDT — which the shipped examples annotate against for units — is not a
   searchable source at all, so a QUDT row is 100% hand-authored.

**Proposed shape (not a decision):** one exported `write_sdp_semantic_closure()`
that reads the package, derives both canonical sets, resolves evidence for each
IRI through the existing search path, computes the snapshot digests, and writes
both files plus the two hashes into an existing sidecar — with any IRI it cannot
resolve reported as a gap rather than guessed at. That would make the closure a
product of the review pipeline instead of a thing reviewers reconstruct.

**Worked reference in the meantime:** `scripts/build-fraser-coho-knb-rehearsal.R`
takes the shipped 173-row example from `create_sdp()` to a clean KNB test-node
dry run. It reaches into `metasalmon:::` in exactly two places, both marked, and
those two calls are the precise measure of this gap.

**The mirror has the identical gap, measured rather than presumed
(2026-08-25).** metasalmonpy requires both files on the same path
(`eml.py:1654` `_read_vocabulary()` raises `FileNotFoundError`;
`knb_publication.py:82-89` lists the vocabulary in `_REQUIRED_SDP_ARTIFACTS`),
has no public producer for either (none of the nine `write_*` entries in
`__init__.py:78-140` writes them; `package_io.py` contains zero occurrences of
either filename), keeps its digest helper private
(`eml.py:1636 _vocabulary_snapshot_sha256`, reached in tests only by importing
past the API boundary at `tests/test_eml.py:901`), and mentions neither file in
any user-facing doc — including `guides/semantic-review.qmd`, whose whole
subject is semantic review. So this is not an R defect to mirror; it is one
design decision that left the same hole twice, and the fix is owed on both
sides in the same stream.

**Assessed against S5's write-back and ruled SEPARATE (2026-08-25).** The
question was whether `apply_sdp_semantics()` is the natural producer of
`reviewed_semantic_selections.csv`, since both are about review decisions. It is
not, and the reason is structural rather than a matter of missing columns.

**Both closure files are closures over the *finished package*; a review object
is a log of *one session's decisions*.** `.ms_eml_read_semantic_review()`
requires the ledger to equal the canonical target set **exactly** — one accepted
row per final IRI, no more and no fewer — and `.ms_eml_read_vocabulary()`
requires the same of the measurement IRI set. A reviewer who decides three of
nine slots, or who decides nothing because the seeded values were already right,
still needs both files complete. A producer driven by the review object would
have to invent rows for slots that review never touched, which is the opposite
of what a review ledger is for. The producer must read the package.

The column gap is real but secondary, and worth recording so the shape of
`write_sdp_semantic_closure()` is not underestimated. Of the ledger's ten
columns a review object supplies eight; `confidence` and `review_rationale` are
human judgements the review API never asks for (`reject_suggestion(reason =)`
covers rejections only, and rejections are exactly the rows a complete ledger
must **not** contain). Of the vocabulary's eleven columns it supplies five to
seven; `native_type`, `source_url` and `source_artifact_sha256` describe the
*ontology artifact* that was searched, and nothing on the retrieval path records
them — which is item 4 above, reached independently from the other end.

**What S5 did contribute:** `apply_sdp_semantics()` now writes a `decision`
column (`accepted` / `not_selected` / `rejected`) back into
`semantic_suggestions.csv`. That is the first durable in-package record of which
candidate was chosen and which were passed over, and it is evidence a future
closure producer can read instead of asking the user to restate it. It narrows
the *evidence* available to the fix; it does not narrow this item, which stays
open at its full scope.

*Retires when:* a user can produce a publishable package without `:::` and
without hand-writing a digest, and the rehearsal script's two internal calls
become calls to exported functions.

**#117 `term_type` is required by EML export but not by strict validation, so
the SDP gate does not gate publication.** Found 2026-08-25, same session. The
shipped Fraser coho starter dictionary carried `term_iri` with an empty
`term_type`; `validate_salmon_datapackage(require_iris = TRUE)` passed, and
`write_eml_from_sdp()` then aborted with *"EML export requires measurement
term_type to be owl_class or skos_concept; found NA"*
(`.ms_eml_measurement_term_annotation()`, `R/eml-export.R:2167`). The dictionary
was fixed in the same change, but the asymmetry is the real finding: strict
validation is documented as "the last gate", and it demonstrably is not one for
the publication path. Either `validate_salmon_datapackage(require_iris = TRUE)`
should require `term_type` wherever `term_iri` is present, or the docs should
stop calling it the final gate. Related to #116 but separable — this one is a
single-field rule, not a missing producer.

**Shared with the mirror, and one case wider there (measured 2026-08-25).**
metasalmonpy's `eml.py:1813-1819` raises the same requirement while
`dictionary.py:50` `CORE_SEMANTIC_FIELDS` omits `term_type`, so
`validate_salmon_datapackage(require_iris=True)` passes the same package. Python
adds a case R does not have: its vendored
`column_dictionary.schema.json:102-110` declares `term_type` with
`enum: [owl_class, owl_object_property, skos_concept]` and no conditional
requirement — so `owl_object_property` is *schema-valid* and still aborts EML
export. Worth noting for whoever fixes this, because it means the schema and the
exporter disagree about the allowed value set, not merely about whether the
field is required. (That enum is decorative in any case: no non-test Python
source reads `constraints.enum` from the frictionless bundle at all.)

*Retires when:* the two gates agree
about `term_type`, or the documentation states which gate covers what.

**#114 `metadata/semantic/**` is specified nowhere, so metasalmon is the de
facto specification for a whole directory of package content. RULED 2026-08-24:
adopt it into `smn-data-pkg`.** Brett, hub [Q11](questions.md): *"Yes."* The
recommendation accepted was the adoption — the status quo quietly makes this
package the spec authority for content the spec repo has never described, which
is the failure the hub exists to prevent, and it gets worse rather than better
as metasalmonpy mirrors metasalmon's shape.

**The next concrete step, so this item is pickup-able:** file a `smn-data-pkg`
issue carrying the inventory of what metasalmon writes there today, and
proposing the `SPECIFICATION.md` section plus the profile/schema entries that go
with it. The inventory, read from this package's source rather than remembered:

- `metadata/semantic/*.sssom.tsv` — SSSOM mapping sets, name-constrained by
  `R/sssom.R` to `^[A-Za-z0-9][A-Za-z0-9._-]*\\.sssom\\.tsv$`.
- `metadata/semantic/mapping-sets.json` — the manifest binding each mapping set
  by path, sha256, row count and source; canonical bytes and ordering.
- `metadata/semantic/measurement-decompositions.csv` and its `.json` binding
  (`R/measurement-decompositions.R`).
- `metadata/semantic_vocabulary.csv` — adjacent rather than inside the
  directory, and pinned by the EML mapping sidecar
  (`R/eml-export.R`), so it belongs in the same proposal.

**Order matters here, and it is the reason to file before implementing:** the
spec repo owns the layout **before** metasalmonpy mirrors it. If the mirror
copies metasalmon's shape first, the adoption stops being a specification
decision and becomes a rename with two implementations already committed to it.
*Retires when:* `SPECIFICATION.md` describes `metadata/semantic/**` and the
profile/schema entries exist, and both implementations validate against them
rather than against each other.

**#110 metasalmonpy's README install guidance is stale in both directions.**
It claims no tag is installable as `metasalmonpy` while v0.1.7 through v0.2.1
all are — and **`v0.4.0` since 2026-08-24, which makes the claim staler and the
fix more valuable**: 0.4.0 is the first tag a workshop or a new user should be
pointed at, and it is the one the README denies exists. It recommends
installing `@main` although the version is a parity
*claim* — `@main` can carry unreleased behaviour ahead of any claimed number,
which is precisely what the claim rule exists to prevent readers assuming.
Found while fixing the workshop's setup instructions, which had inherited the
confusion (a pre-rename metaSmnPy wheel URL). Also: releases carry **no wheel
assets**, so installers need the tag tarball form. *Retires when:* the README
recommends installing a tagged release, states the parity-claim rule, and
either wheels are attached to releases or the tarball form is documented as
the supported path.

**#109 `spec_version` is read by nothing in smn-data-pkg, so version drift is
invisible.** `spec_version`/`specVersion` appears nowhere in
`validate_package.py` or `generate_artifacts.py`: any declaration validates
against whatever the checked-out scripts implement. That is exactly how both
shipped examples sat declaring `sdp-0.2.0` through the `sdp-0.3.0` tag while
passing validation (they now declare sdp-0.3.0 — PR #6 — but nothing would
notice a regression). *Retires when:* the strict validator reads the declared
version and validates against that version's contract, or errors on one it
does not support. **Was sequenced behind Q3/#90; that ruling landed 2026-08-24**
(permit the I-ADOPT keys, the validator learns them), so this is unblocked and
should ride the same change — both edit `validate_package.py`'s comparison
behaviour, and doing them separately means reviewing that comparison twice.

**#103 ~~Four of 23 tests fail on `main`, in a repo with no CI to notice~~ —
FIXED 2026-08-21** (smn-data-pkg PR #6). All four red tests asserted the
pre-0.3.0 method registry; **in all four the validator was already correct and
the tests were stale**, rewritten to the 0.3.0 shape (23/23 green). A minimal
CI workflow now runs the suite and `generate_artifacts.py --check` on push/PR,
which is what retires this item — a red suite on `main` went unnoticed
precisely because nothing ran it. Original entry follows.

**~~#103 original~~ Four of 23 tests fail on `main`, in a repo with no CI to notice.**
`python -m pytest tests/` reports `4 failed, 19 passed`. All four are
`ObservationStructureValidationTests` and all four are about the
`metadata/methods.csv` that sdp-0.3.0 removed, in a copy of
`examples/mixed-grain-example`. They fail in four different ways, which is
what a stale test suite looks like from the inside:

```
FileNotFoundError: .../mixed-grain-example/metadata/methods.csv
ValueError: dict contains fields not in fieldnames: 'method_iri'
AssertionError: Expected error containing
  'resources must include metadata/methods.csv'; found []
AssertionError: Expected error containing
  'not registered in metadata/methods.csv'; found []
```

The two assertions are the interesting pair: the validator correctly reports
*no* error, and the test insists there should be one. They are asserting the
pre-0.3.0 contract.

`smn-data-pkg` has **no `.github/` directory at all**, so nothing has been
running these; the breakage is as old as the 0.3.0 method-model change and
`git` shows no CI that could have caught it. This is the concrete instance of
#61's "no LICENSE, CI, or Pages configuration" bullet, and it is worth
separating because the missing CI is no longer hypothetical — it is already
hiding a red suite in the repo that owns the spec every other repo validates
against. The four tests are also the ones that would have to be rewritten
against the post-0.3.0 model, so deleting them is a decision, not cleanup.

*Retires when:* `pytest tests/` is green on `main` and a workflow runs it on
every push and pull request.

**#104 ~~stale template README with a check that cannot see it~~ — FIXED
2026-08-21** (smn-data-pkg PR #6), by the entry's own alternative retirement:
the prose is corrected AND `generate_artifacts.py` now fails `--check`/`--write`
when the README source names a `metadata/*.csv` absent from the generated
template — proven by reintroducing the stale sentence (non-zero exit). The
guard documents its coverage limits and retirement condition. Original entry
follows.

**~~#104 original~~ The generated template README tells users to delete a file the template
does not contain, and `--check` calls it in sync.**
`templates/salmon-data-package-template/README.md:9-13` says the template
"includes optional `metadata/methods.csv`" and "Delete `methods.csv` when no
procedure registry is needed". `templates/salmon-data-package-template/metadata/`
contains `codes.csv`, `column_dictionary.csv`, `dataset.csv`, `tables.csv` and
`structure/` — no `methods.csv`. `python3 scripts/generate_artifacts.py --check`
reports **"Generated artifacts are in sync."**

**A textbook guard-expiry instance, and the mechanism is exactly the one
`AGENTS.md` warns about.** `render_template_readme()`
(`scripts/generate_artifacts.py:271-284`) reads
`template-source/salmon-data-package-template/README.md` and returns it
verbatim — its only checks are that the file exists and contains no `{{`
placeholders. So the generator **structurally cannot see stale prose**: the
check compares generated output against a source that is a byte-for-byte copy
of it, and will report "in sync" for any text whatsoever. A green check here
means "the copy succeeded", and it is read as "the README is current".

*Retires when:* the template README's file list is derived from the template
tree rather than copied from prose — or, if it stays prose, `--check` asserts
that every `metadata/*.csv` the README names exists in the generated template,
and fails when one does not.

**#105 ~~Four documentation references are published 404s~~ — FIXED 2026-08-21**
(smn-data-pkg PR #6), plus a **fifth** dead reference found in the same pass
(`docs/sdp-profile-schema-guide.md`, in SPECIFICATION.md's guide list). Never-
written targets were removed and their entrypoints rows repointed; stale v0.2
pointers moved to v0.3 with v0.2 marked frozen; every repo-relative path in the
three docs now resolves, swept mechanically. **Residual:** no dedicated
link-check CI step exists — the validator is exercised via the tests, not
standalone — so a future dead link is caught only if a test happens to walk it.
*Retires fully when:* a link check runs in CI. Original entry follows.

**~~#105 original~~ Four documentation references are published 404s.** Checked live
2026-08-21 against `https://salmon-data-mobilization.github.io/smn-data-pkg/`,
which serves the repo and returns 200 for its profiles and Frictionless
schemas. These four return **404**, and none of the four exists in the repo:

| reference | cited by |
|---|---|
| `docs/quickstart.md` | `README.md:83`, and the walkthrough the README sends users to first |
| `docs/implementation-guide.md` | `docs/entrypoints.md:28` |
| `docs/edh-hnap-mapping.md` | `README.md:94` |
| `schema/frictionless/metadata/methods.schema.json` | `docs/entrypoints.md:24` |

The last one is 0.3.0 fallout like #103 and #104 — `docs/entrypoints.md` still
routes SOSA-procedure questions to a schema the method-model change deleted.
The other three are documents the README promises and that were never written
or were removed. `docs/entrypoints.md` exists to be the answer to "what is
actually used", so a dead route in it is worse than a dead route elsewhere.

*Retires when:* every relative path cited in `README.md` and
`docs/entrypoints.md` resolves in the repo, and a link check runs in the CI
#103 asks for.

**#106 `sdp.rules.yaml` requires method IRIs to be "typed as a SOSA Procedure";
gcdfo and smn do not type them that way.** The `methods_are_sosa_procedures`
rule reads *"Every method or protocol IRI resolves to a shared vocabulary
concept typed as a SOSA Procedure"*, and `row_varying_procedures_use_codes`
says the same of every enumerated `codes.csv` `term_iri`. In the released
gcdfo 0.0.9, **only `smn:EnumerationMethod` carries
`rdf:type sosa:Procedure`**; the ten narrower concepts beneath it
(`gcdfo:VisualGroundCount`, `FixedSiteCensusManual`, `AerialSurveyCount`,
`HydroacousticSonarCount`, `TrapCount`, `ReddCount`, `ElectrofishingCount`,
`MarkRecaptureFieldProgram`, `VisualSnorkelCount`, `FixedSiteCensusElectronic`)
are untyped `skos:Concept`s reaching it by `skos:broader`. smn does the same:
`salmon-domain-ontology.ttl` types six concepts `sosa:Procedure` and expresses
the narrower constraint as a `skos:broader*` path in
`ontology/shapes/method-shapes.ttl`, with an in-file comment saying why
(`someValuesFrom` cannot range over concept individuals).

**Reading, not defect — and it is the same undecided question as #76's open
half.** A literal reading makes every crosswalk target this package emits
non-conformant; a `skos:broader*` reading makes them all conformant and makes
the rule's wording imprecise. Nothing is red either way, because
`methods_are_sosa_procedures` is one of the three rules that are loaded and
never executed (#48) — so the rule text has never been tested against real
data, which is how the wording and the modelling drifted apart unnoticed.
Deciding it is a prerequisite for #48 implementing the rule, and #48 must not
pick a reading by itself.

*Retires when:* the rule text says which of the two it means (direct typing,
or reachability by `skos:broader*` from a typed concept), and #48's
implementation checks that.

#### salmon-domain-ontology — two live defects, promoted out of a dated plan

**Both were found in the 2026-08-10 review and have sat in
`knowledge/plans/2026-08-10-comprehensive-ecosystem-review.md` (rows P1-10 and
P1-11) ever since.** That file is a dated record of a decision, not a live
index; this one is the live index. Re-verified on `main` 2026-08-21 — both are
still present, unchanged.

**#107 `smn:Characteristic rdfs:subClassOf sosa:Property`, and `sosa:Property`
is not declared in smn's own vendored SOSA.**
`ontology/modules/02-observation-measurement.ttl:28`. The string
`sosa:Property` appears **zero times** in `ontology/imports/sosa.ttl`, so the
entire `smn:Characteristic` hierarchy hangs off an undefined IRI in W3C's
namespace and no SOSA-aware reasoner relates it to `sosa:ObservableProperty`.
`ontology/modules/02-observation-measurement.ttl:282` puts the same IRI in an
`rdfs:domain`.

**It is silent because ELK does not flag an undefined term** — an
un-axiomatised IRI is simply a class about which nothing is known, so the
ontology is consistent, the build is green, and the I-ADOPT Property bridge
quietly relates nothing to nothing.

**This is not abstract, and the case study is the one everyone uses.**
`smn:Abundance` — the `property_iri` the bundled example dictionary uses, and
which `inst/extdata/example-data-README.md` singles out as the deliberate
choice for spawner counts — is `rdfs:subClassOf smn:Characteristic`, so its
superclass chain terminates in the undeclared IRI. The fix is `ssn:Property` or `sosa:ObservableProperty`;
which one is a modelling call for the ontology's owner, and the plan row
estimates a day.

*Retires when:* every superclass IRI asserted in `ontology/modules/` is either
declared in the module or present in a vendored import, checked in that repo's
build rather than by inspection.

**#108 `smn:observedTaxonSpecies rdfs:range obo:NCBITaxon_8018` — so annotating
a coho observation entails it is chum.**
`ontology/modules/02-observation-measurement.ttl:265`. `NCBITaxon_8018` is
*Oncorhynchus keta*, chum salmon, and smn's own file says so twenty lines
earlier: `smn:NCBITaxon_8018` is labelled `"Oncorhynchus keta proxy class"`,
under an in-file comment naming the mirrored hierarchy as "Oncorhynchus keta
under Salmonidae". The sibling property `smn:observedTaxonFamily` (declared
immediately above it) ranges over `obo:NCBITaxon_8015`, Salmonidae — so the
family-level property is correct and the species-level one was pinned to one
species, which is what makes this a slip rather than a modelling position.

A range is an entailment, not a constraint: any observation using this
property on a coho or chinook is *inferred* to be an observation of chum. In a
five-species integration ontology that is data corruption produced by a
reasoner, arriving with no error anywhere. Same case study as #107 —
`smn:Abundance` observations are exactly what would carry this property.

*Retires when:* the range is `obo:NCBITaxon_8015` (or the property is dropped),
and a competency query in that repo asserts that a coho observation does not
entail chum.

**#79 Vignettes lag the package — mostly discharged by S11 slice 2; two
findings remain.** The 2026-08-13 staleness audit (recorded on the
[S11 sequence card](sequences/s11-vignettes-and-walkthroughs.md)) listed six
findings. **Four are fixed on `main`** (PR #46, `ac6b722`): the two shipped
code defects are gone (no `devtools::load_all(".")` anywhere in `vignettes/`;
`data-dictionary-publication.Rmd` now uses `system.file()`), the 0.2.6
placeholder warning is explained in the quickstart, and `primary_key`, tidy
shape and the 0.2.4 missing-value token are all covered by the new
`tidy-data-for-sdp.Rmd` and `faq.Rmd`. The headline itself is stale — two
vignettes were added after 0.3.0.

**Still open:** the KNB workflow is still buried as §10 of
`post-review-package-publication.Rmd` with no `_pkgdown.yml` articles entry
(that is S11 slice 3, gated on S3), and the "27 of 54 exports untaught"
coverage figure has not been recounted since the audit. Severity: user-facing,
silent (nothing errors — readers just learn the old contract).

**#78 iop-triple emission from SDPs — explainer before decision.** metasalmon
consumes I-ADOPT terminologies but never emits `iop:` triples stating that a
column's component IRIs form an I-ADOPT Variable, so RDF consumers must infer
the decomposition from column names. Brett deferred this (2026-08-13) pending
an explainer that covers: (a) when iop triples are actually useful and to
whom; (b) the pattern for emitting triples from an SDP (where they would
live, what generates them, how they version); and (c) whether triple emission
is a capability SDPs should support *generally* rather than just for I-ADOPT.
Deliverable is the explainer plus a recommendation — not an implementation.
Parked under S9 step 6; do not schedule before Brett reviews the explainer.

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
