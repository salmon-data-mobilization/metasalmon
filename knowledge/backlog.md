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
- **Implementation status:** fixed 2026-09-23 for the request builder (hub item
  B-3; see below). The request body is still divergent, and that is hub item
  B-128. Until then this read *open/deferred*: R4 intentionally deepened the
  response adapter while preserving the two current response shapes, and
  converging `.ms_llm_chat_json_request()` and `.ms_chat_http_request()` was held
  back as a separate refactor "because it would change the adapter shape
  decision" — which the fix shows it does not.
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

**FIXED 2026-09-23** (branch `agent/B-3/a-b14a5733e191f2cc`). One builder,
`.ms_llm_chat_request()` in `R/llm-semantic-helpers.R`, now constructs the
chat-completions request for both default request functions, and
`.ms_llm_chat_completion()` beside it sends the request and hands back the
extracted message text with the decoded body. `.ms_llm_chat_json_request()` and
`.ms_chat_http_request()` keep their signatures and their return shapes and do
only what is theirs: supply a body, and parse the reply. **The wire request is
unchanged on every provider, and that is measured rather than asserted:**
`tests/testthat/test-llm-chat-request.R` captures both paths' requests through
httr2's mocked responses for `openai`, `openrouter`, `openai_compatible` and
`chapi`, compares URL, method, revealed headers and curl options, and passed on
the code before this change as well as after it. A guard in the same file walks
the namespace and fails if any function but `.ms_llm_chat_request()` holds the
endpoint path — RED before the change, when it found `.ms_chat_http_request`
and `.ms_llm_chat_json_request`, GREEN after.

**Two sentences in this entry were wrong, and the fix is the evidence.** *"This
divergence is why the review adapter needs a two-shape normalizer"* and *"doing
so is mutually exclusive with keeping the adapter's dual-shape normalizer"* both
assumed that converging the request builders meant converging on one *response*
shape. It does not: a request and the shape its reply is returned in are
separable, the shared builder hands back unparsed text, and each caller parses it
its own way. The normalizer (`.ms_llm_review_response_data()`) stays, and not by
default. It is needed because `.ms_chat()` wraps whatever a `chat_request_fn`
returns — a string, a wrapped list or a bare one — into `list(content, data,
...)` before the review adapter sees it, while the semantic path hands the
adapter whatever its request function returned. Removing the wrapped branch would
mean changing what `.ms_chat()` returns, which is the session-engine question
hub item B-31 carries, not a request-builder one.

**What this does not fix, named rather than absorbed.** The request *bodies*
still differ: chat decomposition sends a fixed `temperature = 0.2` and never
consults `.ms_llm_build_chat_request_body()`, so on the chat path an `openai`
GPT-5 model still receives a temperature, and a `reasoning_effort` configured
through `METASALMON_LLM_REASONING_EFFORT` still never reaches the provider. That
is hub item B-128. And `scripts/theme-a-benchmark.R` builds a third request of
its own, with its own user agent and `X-Title` and a need for the provider's
model and response id; it is outside the package namespace and outside this
item's condition, and the B-3 workpad records it rather than converging it here.
It is filed as `B-226`.

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
- **Guarded from 2026-09-24** by `tests/testthat/test-vignette-purl-guard.R`
  (hub item B-164), which makes the focused `knitr::purl()` validation above
  permanent: a vignette that turns `eval` or `purl` off through
  `opts_chunk$set()` must tangle to no live code. Until then nothing checked
  the rule, and two vignettes written after this fix broke it; see `B-164`
  below.

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
rather than stretched into this item's scope. (True as measured on 2026-08-22.
#111 closed 2026-09-14 and that helper is deleted; the sentence is kept in its
dated form because the point it makes is about scope, not about today's code.)

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

**Both halves of that condition are met as of 2026-09-14** (queue B-111; the
queue item file holds the state, this paragraph holds the evidence). All three
sidecars render to bytes and install through `.ms_sdp_extension_atomic_write()`,
and `.ms_replace_create_output()` is **deleted** rather than left callerless —
its comment reads as a live hard-link protection that "belongs next to each
write", which is precisely the invitation `AGENTS.md` warns about, and the
protection is genuinely subsumed (the note now sits on the atomic writer's own
symlink refusal, where someone looking for it will be). Two things the fix
measured that the paragraph above only predicted. **The prescription was right
about the mechanism and understated the damage**: an abort injected at each of
the three render steps left the prior file not truncated but *absent*, all
three times — `tests/testthat/test-create-sdp-sidecar-atomicity.R` records the
run. And **the bytes are unchanged**, verified by md5 against this entry's own
pre-fix code on all three files, which is why each bytes renderer goes through
the writer the file already used rather than through a re-implementation of it.
The three stay **three transactions rather than one set**: they are independent
files written at different points in `create_sdp()`, the harm is a destroyed
file rather than a partially-updated group, and the suggestions branch can also
*delete*, which an atomic write set has no operation for.

**What the fix did not buy, and it is worth naming because the word "atomic"
implies it:** `.ms_sdp_extension_atomic_write_set()` stages in the target's own
directory, so the rename is atomic on one filesystem, but `writeBin()` is never
followed by an `fsync`. That is sufficient against a **process** abort, which is
every abort point this item enumerated, and insufficient against a machine
crash or power loss, where a visible rename can outrun the staged data blocks.
Base R exposes no fsync, so closing it means a compiled call or an external
dependency, and the writer is shared with observation structures, KNB
publication and reproducibility manifests — so it is a decision about that
writer rather than about `create_sdp()`. **Filed as a candidate item rather than
absorbed here** (see the B-111 hand-back workpad).

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
- *No consumer breaks.* **True, and the reason originally given for it was false
  — corrected 2026-09-14.** The bullet read: *"`sosa:usedProcedure` has
  `rdfs:range sosa:Procedure`, so RDFS entailment **infers** its object to be a
  `sosa:Procedure`. Being simultaneously a `skos:Concept` is not inconsistent —
  there is no disjointness axiom between them. A reasoner gets a procedure."*
  **There is no such range, and therefore no such entailment.** Official SOSA
  declares `sosa:usedProcedure a owl:ObjectProperty` with
  `schema:rangeIncludes sosa:Procedure` — an annotation property carrying no
  inferential force, and chosen that way deliberately. The SSN specification's
  §3 lists it among the notable differences from SSN: *"the usage of the
  Schema.org `domainIncludes` and `rangeIncludes` annotation properties that
  provide an **informal semantics** compared to the inferential semantics of
  their OWL 2 counterparts."* Verified 2026-09-14 against the official ontology
  at `http://www.w3.org/ns/sosa/` and against smn's vendored copy at
  `ontology/imports/sosa.ttl`, which is byte-identical to it once sorted.

  What survives is the middle sentence, not the first or the last. Being both a
  `skos:Concept` and a `sosa:Procedure` really is consistent. But *"a reasoner
  gets a procedure"* is wrong: a reasoner gets nothing, because nothing types
  the object and nothing asks. **No consumer breaks because no consumer
  checks** — `methods_are_sosa_procedures` is one of **#48**'s three rules that
  are loaded and never executed. The conclusion is therefore correct and its
  support is the opposite of what was claimed, which is why this is corrected
  rather than left standing on a true answer: the premise is the part a future
  reader reuses, and reused it would argue that some *other* untyped method IRI
  is safe, which it is not. The ruling that governs this is **Q47** in
  [`knowledge/questions.md`](questions.md) (2026-09-14, Brett), which settles
  what **#106**'s rule text means and makes the reachability something a
  validator checks — precisely because no entailment supplies it.

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

*The metasalmonpy half, split 2026-09-24 as `B-240`, measured the same day* on
metasalmonpy `main` `e595752` (Python 3.11.15, pandas 3.0.5), loading
`dictionary.py` from a `git archive` extract. `infer_column_role()` types
`spawner_count` (the strings `"1850"`, `"2003"`, `"1999"`) and `escapement`
(int64 1850, 2003, 1999) `temporal`, and `_values_look_yearish()` is true for
both; an int64 column off the year range (185, 20003, 99) types `measurement`.
So the mirror has the same defect. **A different divergence sits beside it,
and it is not the one B-240 ports:** `_character_values()` renders through
`str()`, so a float64 column never looks year-shaped in Python. A float64
`NATURAL_ADULT_SPAWNERS` (1850.0, 2003.0, 1999.0) types `measurement` by that
accident, and `pd.read_csv()` on `BY,n / 2001,1 / ,2 / 2003,3` gives a float64
`BY` that types `attribute`. The B-53 run measured both first, on `3f8349a`,
and also measured `readr::read_csv()` on the same text giving a numeric `BY`
that R types `temporal`.

**#55 `apply_salmon_dictionary(strict = TRUE)` never errors on the common
coercion failures**, and the codes step silently `NA`s unlisted values. Still
live, and the mechanism is worth stating because it looks handled: the coercion
is wrapped in `tryCatch(..., error = ...)` whose handler *does* branch on
`strict` and `cli_abort`s — but `as.integer("abc")` and friends **warn and
return `NA`** rather than erroring, so the handler never fires for exactly the
failures the argument is supposed to catch. A `warning =` handler, not a
different message, is the fix (`R/dictionary-helpers.R`, the coerce-type block
in `apply_salmon_dictionary()`).

*R half fixed 2026-09-24 (hub item B-55).* The block now has a `warning =`
handler, the codes step warns about each unlisted value it blanks, and
`tests/testthat/test-edge-cases.R` covers both. Two of that file's tests had
pinned the defect and were rewritten to the documented contract. The
metasalmonpy half is owed as a port; see *What metasalmon 0.5.0 owes the mirror*
in [`parity-deviations.md`](parity-deviations.md). **What the fix does not
reach, measured on R 4.3.3:** a `warning =` handler only sees a coercion that
signals. `as.logical("yes")` returns `NA` silently, `as.Date(c("2020-01-01",
"abc"))` returns `NA` for the second value silently, and `as.integer("3.7")`
truncates to `3` silently, so all three still pass `strict = TRUE`. That is the
same defect class reached by a different mechanism, and the B-55 workpad records
it as a candidate item.

**#56 Semantic retrieval issues one serial `search_fn()` call per target** with no
deduplication of identical `(query, role, sources)` tuples. Still live: the
`purrr::map_dfr()` over `seq_len(nrow(targets))` in `suggest_semantics()` calls
`.ms_retrieve_semantic_target_candidates()` once per row
(`R/semantics-helpers.R`). Plus a cluster of smaller per-call costs listed in
the review (`term_search.R:341,1763,2190`, `semantic-suggestions.R:863,920`).

*R half fixed 2026-09-25 (hub item B-56).* `suggest_semantics()` now hands the
map `.ms_search_once_per_call(search_fn)`, which searches each distinct
`(query, role, sources)` tuple once for the life of the call and never keeps an
answer whose diagnostics name a source that did not answer.
`tests/testthat/test-semantic-retrieval-dedup.R` counts the calls. Measured on
R 4.3.3 with a counting `search_fn`: four tables carrying the same two columns
make 40 targets and 9 distinct tuples, and the calls fell from 40 to 9 while the
returned object, every attribute included, stayed `identical()`; the bundled
example package, whose 35 tuples are all distinct, still makes 35. The cluster
of smaller per-call costs above and the two LLM retry passes are not part of
it. The metasalmonpy half, filed 2026-09-25 as `B-243`, is owed as a port: its
`suggest_semantics()` makes 40 calls for the same 9 tuples on `main` `85ebbb0`.
See *What metasalmon 0.5.0 owes the mirror* in
[`parity-deviations.md`](parity-deviations.md).

**#57 Assorted smaller correctness items** carried verbatim from the review:
locale-dependent DataONE plan fingerprint inputs now fixed under #40, but
`dwc_dp_build_descriptor(validate = TRUE)` still discards its validation result
and does not declare its Python toolchain in `SystemRequirements`; `llm_top_n`
cannot widen the shortlist on the direct `suggest_semantics()` path;
`find_terms()` does not check `parallel::mclapply` worker failure; ICES helpers
error instead of degrading on a missing column; the composite-intent gate's
`optional_hint_fields` is inert.

*Re-measured 2026-09-25 by hub item B-57, on `main` `6675dae` under R 4.3.3;
the mirror on metasalmonpy `main` `f1f7230` under Python 3.11.15 and pandas
3.0.5.* All five still reproduced. Four are fixed and two are refiled: item 1
split into one of each. Every search, LLM request and `.safe_json()` call was
injected, so nothing left the machine.

1. **`dwc_dp_build_descriptor(validate = TRUE)`.** *The `SystemRequirements`
   half is fixed:* `DESCRIPTION` now names Python 3 and the `frictionless`
   Python package, as optional. *The validation-result half is refiled as
   **B-300**, which needs Brett.* With a stub interpreter whose validator prints
   a failing report and exits 1, the call printed the report and returned the
   descriptor with no attribute. The only signal was R's own `system2()`
   warning that the command `had status 1`. The `python3` on the measuring
   machine has no `frictionless` module, and it produced the same outcome
   exactly, so "not installed" cannot be told from "invalid". Two more things
   stand in the way of a plain "abort when invalid" fix. First, the descriptor
   is validated from `tempfile(fileext = ".json")` in R's session temp
   directory, and Frictionless resolves a local resource path relative to the
   descriptor. So `occurrence.csv` would be looked for in the temp directory
   and would never be found there. That is Frictionless's documented rule and
   was not measured, because `frictionless` is not installed here and
   installing it is a network call. Second, the table schemas are URLs on
   `raw.githubusercontent.com`, so validation needs the network. Acting on the
   result without the path fix would turn a report nobody reads into an abort
   for every relative path. The questions for Brett: should an invalid report
   abort, as `read_sdp_reproducibility_manifest(validate = TRUE)` does on a
   failed check, or warn and return? And which directory should relative paths
   resolve against? The recommendation is to abort, and to resolve against
   `dirname(output_path)` when it is given and the working directory otherwise.
   metasalmonpy's `dwc_dp_build_descriptor(validate=True)` also discards the
   report: with a fake `frictionless` reporting invalid, it returned the
   descriptor with no warning. Without `frictionless` it returned silently.
2. **`llm_top_n` on the direct `suggest_semantics()` path. Fixed.** An injected
   `search_fn` gave eight candidates per role. With the defaults, the direct
   call kept 3 per role and its first review request named 3, while
   `infer_dictionary()` kept and showed 5. After the fix both keep and show 5.
   metasalmonpy's direct call shows the LLM 3 as well, and the port is
   **B-302**.
3. **`find_terms()` and `parallel::mclapply` worker failure. Fixed.** With
   `ols` and `nvs` mocked and the `nvs` worker killed by `SIGKILL`, the result
   had no `nvs` diagnostic row and `.ms_search_failed_sources()` returned
   nothing. The only warning was `mclapply()`'s own, and the result was cached.
   With an error escaping `run_source()` in that worker, the search aborted
   with `$ operator is invalid for atomic vectors`. After the fix both record
   `nvs` with `status = "error"` and give the *did not answer* warning, and
   nothing is cached. metasalmonpy searches its sources one after another, so
   it has no worker to fail.
4. **ICES helpers on a missing column. Fixed.** A response with no
   `longDescription` aborted both find helpers with *Column `longDescription`
   not found in `.data`*. An empty array and a failed request aborted them on
   `key`, and `ices_codes()` aborted on a response with no `key`. metasalmonpy
   returned the match, or an empty frame, in every one of those cases, so R
   moved to match it. What remains is not #57's: an empty result from any ICES
   helper, in either package, cannot say whether ICES answered. That is a
   candidate with no item.
5. **The composite-intent gate's `optional_hint_fields`. Refiled as
   **B-301**, which needs Brett.** Any reading under which `source_name` alone
   stops failing a package narrows a validator, and HUB.md reserves that to
   him (class 6). A package with no `cu_timeseries` table, and with
   `source_name = "Composite of three weir counts"` in `dataset.csv`, fails
   validation with *Explicit composite route intent detected in source_name*.
   Without that column it validates with 0 issues. There are three readings.
   (a) An optional hint field never fires the gate on its own: it only adds
   context to a hint field that fires. This is recommended, because the gate's
   own message calls what it detects "explicit" intent, and free text is not
   that. (b) Optional hints count only when the package has a `cu_timeseries`
   table, which is where the WSP signal is read from. (c) `source_name` is
   dropped from the gate. metasalmonpy's `_collect_composite_hint_values()`
   merges the two lists the same way.

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

### The 2026-09-15 fleet findings

**Thirteen findings from a night of parallel agent runs on 2026-09-15, each
reproduced rather than read.** Eleven are defects and are below; **two are
questions and live in [`questions.md`](questions.md)** as `Q49` and `Q50`, which
is the only file that indexes a decision only Brett can make. They are headed by
their **queue id** rather than by a `#N`, because they are new items and carry no
legacy backlog number: `#120` is the last number this file issued, and inventing
`#121` upward would create a second numbering nobody reconciles. **State is not
here.** Whether one of these is icebox, ready, claimed or done lives in
`queue/items/`, which is the only home for that fact; this section is the
evidence each item's `evidence:` pointer resolves to. **The heading above says
nothing about state on purpose**, and the older `Open — …` headings further up
this file are the pre-queue convention rather than the one to copy: a heading
reading `Open` is a second copy of eleven items' state, it goes stale the moment
any one of them moves, and nothing checks it. *Retires when:* those older
headings are relabelled too, at which point this note is no longer telling a
reader why the neighbours differ.

**Four of the eleven are the guard rule failing in `AGENTS.md`'s own words, and
none of them was looked for.** Three are one defect in three costumes — *a step
that reports success over a failed write* — found in two repositories and two
toolchains by two agents who could not see each other: `B-149` and `B-150` in
gcdfo's `Makefile` and its `pre-commit` hook, and `B-155` in this repository's
CI toolchain install, where `install.packages()` reports a failed download as a
warning and the step goes green. The fourth, `B-159`, is the adjacent shape —
*an instruction that reads as enforced and is not* — and it is in `AGENTS.md`
itself, which is where the rule is written. `AGENTS.md` names the class from a
single 2026-08-16 observation; four more in one night is the measurement that
says it is endemic rather than anecdotal, and that is worth more than any one of
the four on its own.

**`B-149` gcdfo's `prepare-import-catalog` prints a success mark over a failed
catalog write.** The recipe has no `set -e` and both of its branches end in
`echo "✅ ROBOT catalog maps smn import to …"`, so the mark prints whatever the
redirection did. Reproduced 2026-09-15 by making the write target a directory so
the real `printf > $(ROBOT_CATALOG)` fails: the sibling-present branch printed
one `cannot create … Is a directory`, the pinned-commit branch printed two (it
redirects twice), both then printed the success mark, and `make` exited **0**
both times.

Every ROBOT target consumes `ROBOT_CATALOG` — `quality-check`, `reason`,
`convert`, the SPARQL lint, the module check — so a truncated or absent catalog
silently changes how the `smn` import resolves, and the build that follows is
reasoning over a different graph than the one the author thinks. Nothing says
so. The recipe is one of **21** `echo "✅` sites in that Makefile against **2**
`set -e`, which is why the retirement condition asks for a sweep and not for the
one recipe: fixing the instance and leaving the pattern is how this class
survives.

This is exactly the defect class `AGENTS.md` records against 2026-08-16 — *"a
`make` recipe whose missing `set -e` printed a success mark over a crashing
script"* — in the same repository, a month later, in a recipe the earlier fix
did not reach. The Makefile even carries the lesson in a comment on
`ci-sync-artifacts`: *"No `|| true` here: a `git add` that fails must not print
a success mark over the failure, which is the same fault this target's own
`make ci` dependency was fixed for."* One recipe learned it; twenty did not.

*Retires when:* the recipe fails the build when any command in it fails, its
success mark prints only after the catalog file exists and is non-empty, a
deliberately broken write makes `make` exit non-zero, and a sweep confirms no
other recipe in that Makefile prints an unconditional success mark.
`dfo-salmon-ontology` is not solo under `HUB.md`, so the deliverable is a patch
and its pull-request text shown to Brett in chat, never a push.

**`B-150` the gcdfo `pre-push` hook cannot fail, and throws away the artifact
`make ci` just rebuilt.** Two defects in one 589-character `entry:` line, and
naming only the first would leave the second looking like the fix.

The `ontology-ci` hook in `.pre-commit-config.yaml` runs a `bash -lc` chain that
ends `…; make ci; git checkout -- docs/webvowl/data/ontology.json || true`. The
chain's exit status is the status of its **last** command, and that command is
guarded by `|| true`.

1. **The gate is inert.** Demonstrated 2026-09-15 with the same shape: `bash -lc
   'make definitely-not-a-target; git checkout -- README.md || true'` exits
   **0**. So a failing `make ci` does not fail the push, and never has. This is
   the P1 half.
2. **The `git checkout --` discards a real result.** It fires on success exactly
   as it fires on failure, and the hook's `files: ^ontology/dfo-salmon\.ttl$`
   restricts it to pushes that changed the canonical ontology — precisely when
   `make ci` *should* have regenerated `docs/webvowl/data/ontology.json`, since
   `ci` runs `docs-refresh` which runs `docs-widoco`. That repository's own
   `ci.yml` then rejects **any** uncommitted change left after `make ci` across
   the worktree, so the hook locally destroys the regeneration CI is about to
   demand.

Half 2 is a churn suppressor that outlived its cause and carries no retirement
condition — the failure `AGENTS.md`'s guard rule names. Its rationale is the
2026-08-16 entry in that repository's `docs/tech-debt.md`, which says to run
`git checkout -- docs/webvowl/data/ontology.json` **before retrying a failed
docs build** — a manual recovery step, not an unconditional one on every push.
`B-0`'s trap restores the pre-run bytes on failure, so when it lands the
remaining rationale is gone.

Same shape as **`B-44`** ("the gcdfo validation layer is inert") one layer up:
there the SHACL shapes and competency queries are loaded and bind nothing, here
the gate is wired and can only pass. In both, green means nothing and reading
the configuration alone tells you nothing is wrong.

*Retires when:* a failing `make ci` turns the push red, demonstrated with a
deliberately broken ontology; and the trailing `git checkout --` stops
discarding the artifact, landed after `B-0` or with a recorded reason it is safe
without it. Not solo: patch and pull-request text in chat, and a local ROBOT and
Java toolchain to demonstrate either half.

**`B-151` the printed `accept_suggestion()` call is ambiguous for a measurement
column with a code list.** The console prints the exact call the user pastes,
and `R/review-console.R`'s own header says why that makes the printed call
load-bearing: *"A printed call that does not parse, or that names a column that
does not exist, is the defect this feature could most easily ship with."* This
is that defect, in the one shape the design's resolution step does not catch.

`.ms_review_call_args()` computes the minimal argument set *by resolving it*,
escalating from `(column, role)` to `table` and then to `code_value` while the
match is ambiguous. The escalation cannot rescue a column-level slot, because it
appends `code_value` **only when the row it is printing has one** — and
`.ms_review_match_slot_rows()` leaves `code_value` unconstrained when it is not
passed, so the absent value matches every code row rather than only the rows
with no code.

A **measurement** column carrying a code list produces exactly that collision: a
column-level `entity_iri` target (role `entity`, no code value) from
`.ms_semantic_discover_targets()`'s role map, and a `codes.csv` `term_iri`
target per code (role `entity`, with one) from the
`c("constraint", "entity", "method")` role set a measurement parent gives its
codes.

Reproduced 2026-09-15 on a three-slot review — one column-level `entity` slot
and two code-level `entity` slots on the same column and table:

```
printed for the column-level slot:
  accept_suggestion(review, "gear", "entity", rank = 1, table = "t")
that call resolves to: 3 slots
```

```
That column and role match more than one review slot.
i Add one of these arguments to say which:
* table = "t"
* table = "t", code_value = "SEINE"
* table = "t", code_value = "TRAP"
```

**The abort's own disambiguation list is no help**, which is the part that makes
this worse than a bad error message: every option it offers either repeats the
`table` the call already carries or names a code value, so *none of the three
selects the column-level slot*. A user who does what the message says cannot
reach the slot at all.

Reachable from the real pipeline rather than only from a hand-built frame, and
metasalmon 0.5.0's own tests miss it. **It affects both implementations** — the
Python spelling is `_review_call_args()` / `_match_slot_rows()` — so the mirror
half is owed in metasalmonpy in the same shape rather than as a parity row. It
is one line on each side. metasalmonpy PR #28 pinned it as
`test_a_column_level_slot_sharing_a_role_with_its_codes_is_still_ambiguous`,
with its retirement condition in the docstring, so it is visible rather than
latent; that pin is the evidence trail and it un-pins when this lands.

*Retires when:* the printed call for a column-level slot constrains `code_value`
explicitly (or the matcher reads an absent `code_value` as "no code value"
rather than as unconstrained) so it resolves to exactly one slot; a test covers
a measurement column with a code list in both implementations; and the
metasalmonpy pin is removed in the same change.

*Split 2026-09-24 (`queue/README.md`, corollary 2):* `B-151` keeps the
metasalmon half and `B-242` is the metasalmonpy half, which carries the Python
fix, its test and the pin's removal. The item files hold each half's condition,
so the *Retires when* above is the condition as filed rather than either half's.

**`B-152` the network guards in `test-github-helpers.R` probe a host and a
credential path the code under test never uses.** The guards at
`tests/testthat/test-github-helpers.R:143-159` and `:231-259` reach
`api.github.com` through `gh::gh()` and skip when it errors. The code under test
goes somewhere else: `read_github_csv()` builds a `raw.githubusercontent.com`
URL at `R/github-helpers.R:593` and fetches it at `:227` through `:618`.
`read_github_csv_dir()` lists through the API and then calls `read_github_csv()`
per file at `:446`, so its guard covers its listing half and not the fetches
that follow it.

So the guard can pass while the fetch fails, and then the tests at `:161` and
`:264` **error instead of skipping**.

Measured on this machine 2026-09-15 with a token configured, which is what the
tests require: both `gh::gh()` guards return successfully — repository metadata
and the file's contents entry, 6085 bytes — and the two fetches immediately
after raise `HTTP 404 Not Found`. Both tests error.

**The cause is narrower than host reachability, and it changes the fix.** An
unauthenticated request for that same raw file returns **200**; the identical
request carrying the configured token returns **404**. So the guard is wrong
about the *credential path* as well as about the host: `gh::gh()` and
`ms_github_get()` do not send the same thing to the same place, and only one of
them is being proved to work. A guard rebuilt around "does `api.github.com`
answer" would still pass here and the tests would still error.

Same shape as **`B-132`** in a different test file, and `B-132`'s fix should be
applied here in the same pass while it is still open — a guard that proves some
other host resolves is the defect in both.

*Retires when:* both tests skip rather than error when the host the code under
test actually fetches is unreachable or refuses the configured token, because
the guard exercises that host and that credential path; demonstrated by making
that fetch fail and seeing a skip.

**`B-153` metasalmonpy's 0.5.0 documentation half, and the version bump that
closes the window.** metasalmonpy PR #28 lands the whole S5 **behaviour** port —
the nine functions, the two accessors, `decision_reason` with decision replay,
the first consumer of the schema's `constraints.required`, and the `#118`
auto-apply exemption — and **deliberately leaves the version at 0.4.0**. That is
the right call and it is why this is a separate item: a version is a parity
claim, and bumping it with the documentation half missing would put a false
claim in the tree.

**This is the item that actually closes the `0.4.0 → 0.5.0` catch-up window**,
which is the single fact the mirror contract in `AGENTS.md` turns on. Three
files carry that fact — metasalmon's `AGENTS.md`, metasalmonpy's `AGENTS.md`,
and the release index in `knowledge/roadmap.md` — and all three must be read
against each other and moved in the same change, because the whole reason the
contract says *read the other file* is that a stale copy looks exactly like a
current one.

Where the three stand on 2026-09-15: metasalmon's `AGENTS.md` and the roadmap
release index both read 0.5.0 / 0.4.0 with the window open, which is correct.
metasalmonpy's `AGENTS.md` read 0.4.0 / 0.4.0 with no window on `main` — the
copy that was wrong — and **is corrected on the PR #28 branch**, so that
correction lands with that merge and is not owed here.

What the guide still lacks, measured against the PR #28 branch:
`guides/semantic-review.qmd` presents `suggest_semantics()` → the
`semantic_suggestions` attribute → `apply_semantic_suggestions()` as the whole
workflow, and names **none** of the nine functions or the two accessors.
`_quarto.yml` gained an API-reference section for them in that PR; the narrative
guide did not. So the in-Python review path the version number would be claiming
is reachable from the reference and from nothing a reader follows.

*(One correction to how this was first written down, because the file does not
say what the report said it says: the word "spreadsheet" appears nowhere in
`guides/semantic-review.qmd`, and nowhere in metasalmonpy's guides at all. The
guide does not present the spreadsheet as the workflow; it offers no review path
at all. What leads with the spreadsheet is metasalmon 0.5.0's own NEWS entry —
"a salmon data package can now be taken from `create_sdp()` to
`validate_salmon_datapackage(require_iris = TRUE)` without opening a single file
in a spreadsheet" — which is the claim the guide has to be able to support
before the number can be claimed.)*

**The split left a deadlock behind it, and it was a real one rather than a
tidiness point.** `B-153` is `blocked_by: [B-126]`, and `B-126`'s retirement
condition *also* required the 0.5.0 bump. The queue only lets a blocked item be
claimed once its blocker is `done`, so there were exactly two outcomes: `B-126`
closes without satisfying its own recorded condition, or `B-153` is never
claimable and can never do the work that would close it. Neither is a schedule.

**It was broken on `B-126`'s side, on 2026-09-16.** The blocker is a genuine
dependency — a guide cannot document nine functions that are not in the tree, and
a version number cannot claim behaviour that has not landed — so dropping it
would have bought a claimable item that could not be worked. `B-126`'s clause was
written on 2026-09-12, three days before `B-153` existed, and the 2026-09-15
split is what made the bump a separate item; the clause is simply the half that
did not move with the split. So it now ends at the behavioural port and assigns
the bump here by name, and `blocked_by` stands. Found by a Codex review of
pull request 122.

*Retires when:* `guides/semantic-review.qmd` documents the nine review functions
as the workflow, metasalmonpy's version moves to 0.5.0, and all three copies of
the version fact agree in that same change.

**`B-154` the SDP cannot express two I-ADOPT relations, and both are format gaps
rather than ontology gaps.** Both surfaced while writing the iop-triple
explainer (metasalmon PR #116, candidates 1 and 2 of its workpad), and both were
deliberately left as findings rather than absorbed into that claim.

1. **`hasObjectOfInterest` is indistinguishable from
   `hasContextObject`/`hasMatrix`.** I-ADOPT separates the entity whose property
   is observed from a background-context entity and from the containing matrix,
   with `hasMatrix rdfs:subPropertyOf hasContextObject`. The SDP has one
   `entity_iri`, whose field reference reads *"I-ADOPT entity IRI, meaning what
   the measurement is about"*, and the decomposition artifact has one `entity`
   role. An emitter must map everything to `hasObjectOfInterest` or refuse to
   guess.
2. **`constrains` cannot be expressed at all.** `constrains` names *which
   component* a constraint confines — range a union of `Entity`, `Property` and
   `StatisticalModifier`. `constraint_iri` is a flat semicolon-separated bag.
   `measurement-decompositions.csv` does carry `component_relation` and
   `related_component_order`, but `R/measurement-decompositions.R:194` permits
   the single value `value_of_dimension` and `:234` further requires it to
   connect **two matched `constraint` components**. That is not `constrains` and
   cannot be widened into it without changing what the existing value means.

**Both are format-expressivity gaps and neither is an ontology gap.** Every
predicate already exists in I-ADOPT 1.1, nothing needs minting, and filing
either through `detect_semantic_term_gaps()` → `render_ontology_term_request()`
would be wrong. This is stated explicitly because routing it into the
term-request pipeline is the plausible mistake, and it is the same distinction
PR #116's own "Ontology gaps" section drew when it reported **none to file** and
called that a finding rather than a blank.

Affects both mirrors. The decomposition artifact is not yet in the
specification, which is **`#114`** / `B-114`, so a ruling here either waits on
that adoption or says how the two relate.

*Retires when:* the SDP schema can express both relations, or a logged ruling
records that it deliberately will not and says what a consumer should do
instead; and metasalmon and metasalmonpy both read and write whatever lands.

**`B-155` CI's `pak` install has no retry, so a transient SSL error fails
`check` before a single test runs.** Observed 2026-09-15 on metasalmon PR #118,
run `34912254547` attempt 1. `.github/workflows/R-CMD-check.yaml`'s
`r-lib/actions/setup-r-dependencies@v2` step died fetching
`pak_0.11.1_R-4-6_x86_64-linux-gnu.tar.gz` from `r-lib.github.io`:

```
URL 'https://r-lib.github.io/p/pak/stable/…/pak_0.11.1_R-4-6_x86_64-linux-gnu.tar.gz':
  status was 'SSL connect error'
Warning in download.packages(…) : download of package ‘pak’ failed
…
##[error]Error in loadNamespace(x) : there is no package called ‘pak’
Execution halted
```

Whole job red **71 seconds** after it started, with "Replay Theme A evidence",
the test suite and `R CMD check` all skipped.

**Transient, not systemic**, and the evidence is unusually clean: the same job
passed on PRs #119, #120 and #121 within twenty minutes, all four against the
same base `4cd085c`, and attempt 2 of *this very run* passed under two hours
later on the **identical head commit**. Nothing about the diff was implicated at
any point.

The cost is that a red `check` on this repository does not distinguish "your
diff is broken" from "a CDN blinked" — the same legibility problem as
**`B-132`**, where a two-second hard-coded fetch timeout turns a slow network
into a test failure.

One detail found while confirming it, which belongs in the fix rather than in
the diagnosis: **the "Install pak" sub-step reported `outcome=success`**
(592 ms) while the download was failing, because `install.packages()` reports a
failed download as a *warning*; only the next sub-step turned red, and it turned
red on a symptom (`there is no package called 'pak'`) rather than on the cause.
So this is the same success-over-a-failed-write family as `B-149` and `B-150`,
one layer further out, and not only a missing retry.

*Retires when:* a transient failure to install the CI toolchain retries before
failing the job, or fails with a message that names it as an infrastructure
failure rather than a check failure; demonstrated against a simulated download
failure.

***`B-156` was reassigned to `Q50` on 2026-09-16 and the `B-156` id is retired
unused.*** The Frictionless `profile`-versus-`$schema` finding is a question and
its entry is in [`questions.md`](questions.md) as
[Q50](questions.md#q50--does-the-sdp-deliberately-pin-frictionless-v1s-profile-or-move-to-v2s-schema);
the item file is `queue/items/Q-50.yaml`. **Nothing vanished and `B-156` is not
reused for anything else** — the gap between `B-155` and `B-157` is the record of
the reassignment, and this note is here so that a reader counting the sequence
does not go looking for a deleted item.

Why it moved, recorded because the misfiling is the lesson: the entry said of
itself that it was *"an open question, not an established defect"*, that it was
noticed in passing while writing PR #116 and **not investigated**, and that
whether the SDP targets v1 or v2 is a ruling rather than an implementer's call —
and it was filed `kind: defect` anyway. That made the queue count and prioritise
it as a P4 defect and kept it out of `questions.md`, which is the one file that
indexes a decision only Brett can make, so the effect of writing it down was to
hide it. Found by a Codex review of pull request 122.

**`B-157` two 2026-09-14 knowledge cards are reachable from nothing inside the
bundle.** There is a convention and no enumeration: `AGENTS.md` says a sequence
card links to its execplan before implementation starts, and `knowledge/index.md`
names the `plans/` directory as a whole without listing a single card. So
nothing enumerates the set, and nothing notices a card that joins it unlinked.

Measured on `main` at `4cd085c`, 2026-09-15, by searching the sequence cards,
the roadmap, the index, this file, `questions.md` and `orientation.md` for each
of the **21** plan-card filenames. Exactly two have zero inbound references;
every other card has at least one.

- `knowledge/plans/2026-09-14-commons-verification-scheme.md` — reachable from
  **nothing at all**, including `Q39` and `Q40`, the two open commons questions
  it was written to answer. That is the case that shows the cost: a proposal
  that answers an open question without being linked from it leaves the question
  looking unanswered, and the next agent re-derives the scheme.
- `knowledge/plans/2026-09-14-taxonomic-assignment-briefing.md` — **reachable
  from the queue but not from the bundle.** `queue/items/Q-48.yaml` names its
  path.

*(The second bullet is a correction. This was first reported as "both cards are
linked from no file but themselves", which is true of the first and false of the
second. The weaker claim is the true one and it is still a defect — a bundle
card whose only inbound link is from outside the bundle is unreachable to anyone
reading the bundle — but it is a smaller defect than the one reported, and the
difference is exactly the kind a reader cannot check without redoing the search.)*

*Retires when:* every card in `knowledge/plans/` is reachable from
`knowledge/index.md` or from the sequence card it serves, and a check or a
documented convention keeps that true.

**`B-158` eight foreign superclass IRIs in smn are declared nowhere, and
vendor-or-stub is one decision applied eight times.** `B-143` landed on
2026-09-15 as salmon-domain-ontology **PR #30** — open and draft, not merged — a
referential-integrity gate that fails when a superclass IRI asserted in
`ontology/modules/` is declared neither there nor in a vendored file under
`ontology/imports/`. Its first run reports **nine** undeclared IRIs. One is
`sosa:Property`, which is `#107` / `B-107`. **The other eight are vendoring
omissions, and they are this item.**

Measured by running that gate in staged mode on 2026-09-15 against the modules
at `d45f8f7`, rather than taken from the report that filed it:

| IRI | Asserted at | Subjects |
|---|---|---|
| `obo:BFO_0000015` | `02-observation-measurement.ttl:216`, `03-assessment-benchmarks.ttl:53` | `smn:Escapement`, `smn:StockAssessment` |
| `obo:IAO_0000030` | `01-entity-systematics.ttl:69`, `03-…:65,82`, `05-provenance-quality.ttl:13,19` | five |
| `obo:IAO_0000109` | `02-…:241`, `03-…:18,45` | three |
| `obo:NCBITaxon_8015` | `02-…:202` | the MIREOT mirror |
| `obo:NCBITaxon_8018` | `02-…:206` | `smn:NCBITaxon_8018` |
| `dwc:Event` | `02-…:224` | `smn:SurveyEvent` |
| `dwc:Organism` | `01-…:86,94` | `smn:Deme`, `smn:Population` |
| `geosparql:Feature` | `01-…:59` | `smn:GeographicFeature` |

**They are omissions rather than typos, and that is measured rather than
judged:** smn declares **13** IRIs in the `sosa:` namespace and **zero** in each
of `obo:`, `dwc:` and `geosparql:`. A typo needs a correct neighbour to be a
typo of, and these three namespaces have none.

Two things decide how this is worked, and both are easy to get wrong.

**`CONVENTIONS.md` 5b rule 2 already permits a bare declaration stub
(`ex:Term a owl:Class .`) anywhere**, so the cheap remedy exists and nothing has
to be vendored to clear the gate. The decision is therefore
**vendor-the-namespace versus stub-the-IRI**, taken once and applied eight
times, not eight independent calls. That is why these are one item and not
eight, and it is why the item was filed `claimable: false` when this section
was written: a modelling call is not an agent's to make. *(Brett made it on
2026-09-16 — stubs for the `obo:` and `geosparql:` IRIs, a vendored import for
the `dwc:` ones — which is what that clause was waiting for. The ruling and its
justification are recorded in* The 2026-09-16 rulings round *below; what the
item's fields say now is `queue/items/B-158.yaml`'s to answer, not this
section's.)*

**This is the item that gates `B-143`'s switch-on, not `B-107`.** `B-107` clears
one of the nine; the other eight are these, and until all nine clear the gate
stays staged and `make test` keeps running
`verify-superclass-declarations-staged` rather than the real target. Stated
plainly because the chain is easy to describe as a single hop and it is not
one.

**Cross-reference `Q-48`.** `dwc:Organism` carries `smn:Deme` and
`smn:Population`, and `obo:NCBITaxon_8015`/`8018` are the MIREOT mirror — the
same terms the 2026-09-14 taxonomic-assignment briefing is about. The vendoring
decision and the taxonomy-pattern ruling are one decision surface, so whoever
rules `Q-48` should see this at the same time rather than after.

*Retires when:* each of the eight is either declared by a vendored import under
`ontology/imports/` or carries a stub per 5b rule 2,
`make verify-superclass-declarations` exits 0 over the modules as they stand,
and `KNOWN_UNDECLARED` in `scripts/verify_superclass_declarations.py` is empty
so the staged target and its `--staged` mode can be deleted and `make test`
swapped to the full gate.

**`B-159` the knowledge-bundle validator `AGENTS.md` instructs cannot be run by
any agent, so every agent-written card is unvalidated.** `AGENTS.md:326-331`
says to keep the bundle valid with
`uv run --project ../psc-data-systems psc-okf check knowledge --tier capture`.
It is unexecutable in this environment on **four independent legs**, each
verified 2026-09-15:

1. **No checkout.** There is no `psc-data-systems` directory anywhere on this
   machine.
2. **Not installed.** `psc-okf` is not on `PATH`. `uv` itself is present, so
   this is not a missing-runtime problem.
3. **Not obtainable as a package.** PyPI returns **404** for both `psc-okf` and
   `psc_okf`.
4. **CI never runs it.** There is no reference to `psc-okf` or
   `psc-data-systems` anywhere under `.github/`.

`queue/config.yaml:228-231` records `psc-data-systems` only as a **GitLab**
path. `HUB.md` permits an agent to read there and forbids every write, and no
agent here holds a credential for it, so leg 1 is not one an agent can clear on
its own either.

**The consequence is the item.** Every `knowledge/` card written by an agent has
gone in **bundle-unvalidated**. Two agents hit this independently on the same
night and each recorded the skip in its own pull request — metasalmon **#116**
for the iop-triple card, salmon-domain-ontology **#30** for two cards there —
and neither could substitute for it; hand-checking front matter against
neighbouring cards is a *different* check that happens to be available. By legs
1 to 3 the same is true of every card before them, including the taxonomy
briefing, the commons verification scheme, and the 2026-09-12 promotion-review
record.

This is the class `AGENTS.md`'s own guard rule names, arriving in `AGENTS.md`
itself: **an instruction that reads as enforced, is not, and whose absence is
invisible to someone reading the instruction.** A green pull request on this
repository is currently silent about bundle validity and looks like it is not.

Three remedies, in the filing review's stated order and recorded as its own:

1. **Publish or mirror `psc-okf`** somewhere agents can reach it.
2. **Reimplement the `--tier capture` checks** as a script in this repository,
   wired into CI beside the `queue-is-valid` job — which already triggers on
   `knowledge/**`, so this needs no new trigger.
3. **Record in `AGENTS.md` that the check is human-only**, with the condition
   that would retire that.

The third is the honest minimum and costs nothing. All three are choices rather
than work, which is why the item is not claimable.

*Retires when:* either an agent in this environment can run the bundle check and
CI runs it on every pull request touching `knowledge/`, or `AGENTS.md` states
that the check is human-only and names what would change that.

**`B-160` ask DataONE to give `smn` and `gcdfo` ontology expansion in the
indexer, where salmon namespaces are already accepted.** DataONE's production
indexer applies superclass and subproperty **query expansion** only to
ontologies named in `ontologyList` in
`src/main/resources/application-context-ontology-model-service.xml` in
`DataONEorg/dataone-indexer`. Read on `main`, 2026-09-15: **23 entries** — ECSO,
ProvONE, ENVO, **13** OBOE modules, `MOSAIC_`, `ARCRC`, `ADCAD_`, `SENSO_`, and
**three salmon namespaces**, `purl.dataone.org/odo/SALMON_`,
`SALMON_alignment_` and `SASAP_`. It carries **zero** occurrences of `w3id`,
`iadopt`, `smn` or `gcdfo`. Two shapes of entry share that one list — a full
ontology document URL (ECSO, ENVO, ProvONE, the OBOE modules) and a namespace
prefix (all five `odo/` entries) — which is what says which shape smn's own
entry would take.

**Why this is P2 rather than a nicety.** An annotation whose IRI is outside the
list is still indexed — it lands in the flat `sem_annotation` field and is
exact-IRI queryable — but it gets **no expansion**, so a search for a parent
concept does not match a dataset annotated with a child of it. For a package
built on an ontology whose whole value proposition is a subclass hierarchy,
that is the difference between the hierarchy doing retrieval work at DataONE and
being inert there.

**It is in use, not theoretical.** Re-measured against the production endpoints
on 2026-09-15: `sem_annotation:*` matches **13,040** of **3,376,880** CN
documents and **2,485** of **286,653** KNB documents.

**Two things checking it turned up, and both change what the ask is.**

1. **The list is not a namespace filter — it is a set of ontologies DataONE
   vendors.** Every `ontologyList` entry is paired in `altEntryList` with a
   **bundled local OWL file** under `src/main/resources/ontologies/`:
   `SALMON_` → `ontologies/SALMON.owl`, `SASAP_` → `ontologies/SASAP.owl`, and
   both files are really there. So inclusion is a release-and-versioning
   commitment on smn's side — which file, pinned how, refreshed how — rather
   than a one-line configuration edit, and the ask has to arrive with an answer
   to that.
2. **The two fields the list feeds are undefined on the public CN endpoint
   today.** `annotation_property_uri` and `annotation_value_uri` both return
   **HTTP 400, `undefined field`**, while `sem_annotation` resolves. Either the
   expansion fields exist internally and are not exposed through the public
   query schema, or that path is not wired into production at all. **The ask has
   to carry that question** rather than assume inclusion alone buys anything.

The retirement condition below survives both readings, which is why it is
phrased as a retrieval demonstration and not as "the configuration changed".
Keep it that way.

**The strategic point, stated plainly because it is why the item exists: this is
a better discoverability lever than emitting I-ADOPT triples** — the subject of
`#78` / `B-78` and `B-146`. The index cannot represent an I-ADOPT decomposition
**at all**: it flattens predicate and object into one unordered multivalued
field, with no pairing and no subject. Expansion, by contrast, makes smn's
existing hierarchy do real retrieval work. The two are not alternatives in
principle, but if effort is scarce this one buys more.

**The precedent is the strongest argument available.** DataONE has already
accepted salmon-domain namespaces under `purl.dataone.org/odo/`, so this is
*extension of an existing arrangement* rather than a novel request. Part of the
item is working out the relationship between those `SALMON_`/`SASAP_`
namespaces and `smn`/`gcdfo` — whether smn seeks its own entry, mints under
`purl.dataone.org/odo/`, or aligns to what is already there. That is a real
modelling question, and it is why this is not claimable alongside its being an
outward-facing request to another organisation.

Venue for the ask: an issue on `DataONEorg/dataone-indexer`, which is also where
roadmap intent on per-predicate indexing would be answered. `S-03`'s KNB deposit
is the same destination and the natural occasion to raise it.

*Retires when:* either `smn` and `gcdfo` IRIs receive superclass expansion in
DataONE's production index — demonstrated by a query for a parent concept
matching a record annotated only with a child — or a logged decision records
that smn will instead mint or align under an already-accepted namespace, or that
the ask was made and declined, with what was said.

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

### The R halves of the 2026-09-15 Codex findings on metasalmonpy PR #28

**Five findings from fixing three Codex P2 findings on metasalmonpy PR #28
(queue item `B-126`), each re-measured here rather than taken from the report
that surfaced it.** `B-174`, `B-175` and `B-176` are the **R halves** of those
three: the same defects exist in metasalmon 0.5.0 in the same shape, so they are
owed as **ports and not deviations** — a shared defect is not a chosen
difference, so no `PARITY.md` row is owed for any of the three. `B-177` is a
question the first finding opened and did not close. `B-178` is an
evidence-hygiene item in metasalmonpy and it **records a negative result**: the
finding as reported does not hold, and the measurement that shows why is the
entry.

They are headed by their **queue id**, because they are new items with no legacy
backlog number. **State is not here.** Whether one is icebox, ready, claimed or
done lives in `queue/items/`; this section is what each item's `evidence:`
pointer resolves to. **The heading above says nothing about state on purpose**,
and the older `Open — …` headings further up this file are the pre-queue
convention rather than the one to copy: a heading reading `Open` is a second
copy of five items' state, it goes stale the moment any one of them moves, and
nothing checks it. *Retires when:* those older headings are relabelled too, at
which point this note is no longer telling a reader why the neighbours differ.

Everything below was measured on 2026-09-15 under **R 4.3.3** against
metasalmon **0.5.0 loaded from source at `main` `4cd085c`** (`DESCRIPTION`
reads 0.5.0). The report these came from said "installed metasalmon 0.5.0";
the package is installed in no library on this machine, so that phrase
described a `pkgload::load_all()` tree. Two measurement traps bit during the
re-check and are worth carrying forward: `pkgload::load_all()` sources
`tests/testthat/helper-*.R` by default, so a dev console silently inherits
`options(metasalmon.sdp_schema_source = "vendored")` and **cannot see `B-175`
at all**; and a fixture's candidate count is a property of the fixture, which
is why the `not_selected` row count in `B-176` is two here and one in the
report.

**`B-174` `review_metadata()` reports a clean package that strict validation
refuses.** **A user-facing defect in released 0.5.0**, not a latent one: it is
the state a user reaches by leaving any part of the semantic review queue
undecided, which is the ordinary path rather than an edge case.

`.ms_is_unfilled_metadata()` (`R/sdp-field-setters.R:50-55`) answers `FALSE`
for `REVIEW:https://example.org/Thing` and `TRUE` for the three prose
placeholder spellings (`MISSING METADATA:`, `MISSING DESCRIPTION:`,
`REVIEW REQUIRED:`), for blank and for `NA`. End to end, on a package filled by
executing `review_metadata()`'s own printed calls until
`validate_salmon_datapackage(pkg, require_iris = TRUE)` passed, and then given
one `REVIEW:` marker:

```
review_metadata(pkg)                -> "No outstanding metadata."
                                       "Every required field is filled and
                                        no placeholders remain."
validate_salmon_datapackage(pkg, require_iris = TRUE)
                                    -> Error: Validation cannot pass while
                                       REVIEW-prefixed IRI values remain.
                                       x constraint_iri: spawner_count (rows 2)
```

**The defect is the predicate, not the field list, and that changes the fix.**
It was reported as a coverage gap that needed to reach `constraint_iri`,
`statistical_modifier_iri` and a code's `term_iri` "not only measurement and
table IRIs" — implying the measurement and table IRIs were already handled.
They are not. A `REVIEW:` marker on `term_iri`, `property_iri`, `entity_iri` or
`unit_iri` of a measurement column is missed although all four are enumerated
in `.ms_measurement_iri_fields()` and visited on every row, and one on
`tables.csv$observation_unit_iri` is missed although that field has its own
dedicated branch. Every one of those was measured refused by strict validation
and reported as **0 rows** by the scan. `constraint_iri` and
`statistical_modifier_iri` fail for the same reason plus a second: neither is
schema-`required` nor in the measurement enumeration, so only the
prose-placeholder branch ever looks at them.

Two parts of the fix shape are load-bearing.

1. **Keep `.ms_is_review_placeholder()` narrow and add a second predicate.**
   Its narrowness is deliberate and depended on by **12 call sites across four
   files** (`R/package-helpers.R`, `R/sdp-field-setters.R`,
   `R/edh-xml-export.R`, `R/metadata-write.R`), several of which exclude the
   marker *on purpose* — the placement sweep at `R/package-helpers.R:1748-1751`
   says so in a comment ("`REVIEW:` markers have their own dedicated reporting
   path"), and `.ms_metadata_gap_row()` uses it to decide whether a value's own
   text is a usable hint, which an IRI's is not. *(The report said five
   callers; five is the Python count for `_is_review_placeholder` in
   metasalmonpy's `semantics.py`. R has 12.)*
2. **`.ms_review_is_unfilled()` (`R/review-console.R:133`) is IRI-aware and is
   not a drop-in replacement.** Measured, it answers `FALSE` for all three
   prose placeholder spellings, so swapping it onto this path trades one half
   of the defect for the other. What is needed is the union of the two, or a
   second predicate as metasalmonpy PR #28 added (`_is_unresolved_iri()`, kept
   separate for exactly this reason and carrying "*Retires when:* nothing" in
   its docstring).

The scan's **file** scope must follow what strict validation actually sweeps
rather than what looks symmetric: `tables.csv` and `column_dictionary.csv` are
refused, `dataset.csv` and `codes.csv` are not (`B-177`), so reporting a marker
there would make the scan claim a block that does not exist — the same class of
error as missing one, pointing the other way. `B-177` is **not** a blocker: the
two swept files can be fixed first.

*Retires when:* `review_metadata()` reports every field whose `REVIEW:` IRI
blocks `validate_salmon_datapackage(require_iris = TRUE)`, so the scan's own
stated contract holds again — when the last row it prints is gone, strict
validation passes — demonstrated red on a package whose only remaining gap is a
`REVIEW:` marker, and pinned by a test that drives the validator rather than
asserting on the printed text.

**`B-175` `review_metadata()` contacts the network although its documentation
says it never does.** The roxygen sentence is at `R/sdp-field-setters.R:340` —
*"It never contacts a network or an LLM."* — and it is rendered into
`man/review_metadata.Rd:44`, so it is a published guarantee and not only a code
comment. *(The report placed it at line 339.)*

Path measured: `.ms_metadata_schema_fields()` (`R/sdp-field-setters.R:101-105`)
→ `.ms_load_sdp_schema(quiet = TRUE)` (`R/schema-helpers.R:103-151`), whose
default source is `getOption("metasalmon.sdp_schema_source", "auto")`, and
`"auto"` calls `.ms_fetch_remote_sdp_schema()` (`R/schema-helpers.R:153-175`)
**before** falling back to the bundled copy.

Cost, measured with a counting wrapper around `httr2::req_perform` and the
schema cache cleared: **eight** requests to `raw.githubusercontent.com` per
cold schema load — six Frictionless metadata schemas from
`.ms_sdp_metadata_schema_paths()`, plus the profile and `sdp.rules.yaml` — each
carrying the 2-second timeout that is `.ms_fetch_remote_sdp_schema()`'s default,
1.08s of wall clock with the host reachable, and one 2.1–2.5s timeout per cold
call when the host never answers. *(The report said six requests at 2.0s each.)*
*(Corrected 2026-09-23: this read "up to 16s when it hangs". The B-175 run
measured one timeout per cold call on `main` `12efe9d` — 2.12–2.45s across
`review_metadata()` and the four setters, each opening one connection to a
listener that never answered — because the first failed request aborts the whole
bundle fetch and the loader falls back to the bundled copy. Eight times two
seconds bounds only a host that answers each request just inside the timeout.)*
The bundle is cached in
`.ms_schema_env` per cache key, so it is eight requests on the first call in a
session and **zero** on the second; a scripted review that starts a fresh R
process per package pays it every time. `set_sdp_dataset()` measured the same
eight on the same path. `review_semantics()` measured **zero**, so its
identically worded claim (`man/review_semantics.Rd:40`) holds — which is what
makes this a defect in one function rather than a house style.

**This is the trap, and it is why the retirement condition names the
sentinel.** `.ms_load_sdp_schema()` wraps the fetch in
`tryCatch(..., error = function(e) e)` (`R/schema-helpers.R:114-117`), so an R
sentinel that signals an **error** is swallowed and the test passes either way.
Measured: a mocked `req_perform` that calls `stop()` was reached once and the
call still returned all 24 `dataset.csv` field definitions with nothing
escaping — the R spelling of the same trap that swallowed a Python `Exception`
on the other side. A sentinel that works either records its firing outside the
call (a counter incremented before the `stop()`) or signals a **non-error**
condition; both were demonstrated firing.

**Nothing in the suite can see this.** `tests/testthat/helper-validation.R:3`
sets `options(metasalmon.sdp_schema_source = "vendored")` for the whole run, so
the shipped default is exercised nowhere — and metasalmonpy's
`tests/conftest.py` pins the same value for the same stated reason, which is
why the defect survived on both sides.

This is the same contract shape as `AGENTS.md`'s **LLM-opt-in** rule: supplying
`llm_context_files` must *never* trigger a network or LLM call, and options that
will be ignored should warn rather than silently no-op. A function documented as
local has to be local, and a documented guarantee that is only usually true is
the failure that rule exists to name. metasalmonpy PR #28's fix is a module
constant reading the bundled bundle on this path (`_SCHEMA_SOURCE = "vendored"`,
with its own retirement condition), with the setters reading the same source so
the gap scan and the printed call cannot disagree about which fields exist.

*Retires when:* `review_metadata()` and the four `set_sdp_*()` setters make no
network request under the shipped default options, **and a sentinel proves it**
— a counter or a non-error condition, never a `stop()`.

**`B-176` `apply_sdp_semantics()` loses a hand-picked accept.** On a
`create_sdp()` package seeded through a mocked `find_terms`:

```
accept_suggestion(review, "spawner_count", "variable",
                  iri = "https://example.org/Handpicked")
apply_sdp_semantics(path, review)

column_dictionary.csv$term_iri  -> https://example.org/Handpicked
semantic_suggestions.csv        -> 2 rows decision=not_selected
                                   0 rows decision=accepted
                                   0 rows whose iri is the accepted one
review_semantics(path)          -> 0 decisions replayed
  (same with include_filled = TRUE)
```

The mask is `R/metadata-write.R:445-449`: `accepted` is `in_slot` **and** the
row's stripped `iri` equalling the decision IRI, so when the accepted IRI is not
one of the slot's candidates the vector is all `FALSE`, line 447 sets every row
in the slot to `not_selected`, and line 448 sets nothing to `accepted`.
`not_selected` is absent from `.ms_review_recorded_decisions()` (the map is
`accepted`, `accept`, `rejected`), so the replay helper skips those rows and the
decision is unrecoverable from the package. The slot then drops out of the next
queue only because the dictionary field is now filled, not because the answer
was remembered. *(The report said one `not_selected` row; the count is a
property of the fixture's slot, which carries two candidates.)*

**Two things the Python fix established that the R fix must not lose.**

1. **The accepted IRI needs its own row**, not an existing candidate
   relabelled. Relabelling would make the file say a term the reviewer never
   chose is the one they chose, and that row's `label`, `source`, `ontology`,
   `definition` and `score` would all describe a different term.
2. **The new row goes at the head of its slot, not the tail.**
   `review_semantics()` derives `rank` from file position
   (`R/review-console.R:316-323`, deliberately not a sort, so the ranked order
   and the seeded auto-apply cannot disagree) and then drops everything past
   `max_candidates`, default `5` (`R/review-console.R:398-399`). Demonstrated on
   a slot padded to six candidates: appended, the hand-picked row ranks 7 and is
   filtered straight back out of the rebuilt review; inserted at the head, it
   ranks 1 and survives.

*Retires when:* `accept_suggestion(..., iri = )` followed by
`apply_sdp_semantics()` leaves `semantic_suggestions.csv` carrying a row whose
`iri` is the accepted IRI with `decision` `accepted`, and the next
`review_semantics()` replays it; demonstrated red on an IRI that is not among
the slot's existing candidates, and pinned by a test that reads the file back
rather than asserting only on the dictionary.

**`B-177` two code paths in the same package disagree about whether
`dataset.csv` and `codes.csv` are swept for `REVIEW:` IRIs.** **Latent today**,
and say so, so nobody reads it as live breakage: `.ms_review_iri_prefix()` has
exactly two call sites — `R/package-helpers.R:3848`, which writes into
`column_dictionary.csv`, and `R/package-helpers.R:4166`, which writes
`tables.csv$observation_unit_iri` — so no producer in the package writes a
marker into either file, and only a hand-edited or third-party package can be in
this state.

The sharper question is inside it. `R/edh-xml-export.R:1175-1178` calls
`.ms_collect_review_iri_issues()` on **all four** frames; the strict validation
path calls it on `tables` alone (`R/package-helpers.R:1972`) and reaches the
dictionary only through `validate_dictionary()` / `validate_semantics()`.
Measured on a package filled until strict validation passed:

| marker on | EDH gate | `validate_salmon_datapackage(require_iris = TRUE)` |
|---|---|---|
| `column_dictionary.csv$term_iri`, `constraint_iri`, `statistical_modifier_iri` | reports | **refuses** |
| `tables.csv$observation_unit_iri`, `method_iri`, `protocol_iri` | reports | **refuses** |
| `dataset.csv$protocol_iri` | reports | **passes** |
| `codes.csv$term_iri`, `vocabulary_iri` | reports | **passes** |

`codes.csv` was not in the report and is the same defect as `dataset.csv`: two
files, not one. It escapes the unconditional placement check too, which excludes
anything matching `^REVIEW:` on purpose (`R/package-helpers.R:1748-1751`)
because the marker has its own reporting path — and on
`dataset.csv$protocol_iri` that path is the one that is missing.

**The same question is open on the Python side, and the two implementations
already differ on one half of it**, so this is not purely an R item.
metasalmonpy's `_collect_review_issues()` (`package_io.py:2284-2315`) sweeps
tables, dictionary and codes for `REVIEW:` IRIs but **not** dataset, where R's
EDH path does — so the two EDH gates disagree about `dataset.csv$protocol_iri`.
PR #28 froze the scan-side answer as
`_REVIEW_IRI_FILES = ("tables.csv", "column_dictionary.csv", "codes.csv")` with
a retirement condition tying that tuple to whatever `_collect_review_issues()`
sweeps.

*Retires when:* strict validation and the EDH rebuild gate sweep the same set of
files, **or** a logged decision names which set is right and why, with the loser
changed to match in the same change. Whichever way it is ruled, the ruling has
to reach four places — R strict validation, the R EDH gate, the Python
equivalents of both, and `B-174`'s scan list — and any deliberate difference
that survives needs a parity register row. That row is the **only** one anything
in this filing run could owe.

**`B-178` metasalmonpy PR #28's body records suite counts measured at its first
commit, not at its head.** **The finding this item was filed to record does not
hold, and the negative result is the point.** It was reported as "the body
records test counts that do not reproduce, with a two-test difference that was
not chased". The body's counts reproduce exactly.

Measured from a throwaway clone of the branch, with metasalmonpy installed
editable into two purpose-built virtual environments:

| commit | leg | `Rscript` absent | `Rscript` present |
|---|---|---|---|
| `05be2a1` | `[test,eml,context]` | **896 / 3** | 898 / 1 |
| `05be2a1` | core deps only | **783 / 116** | 785 / 114 |
| `ead77a3` (head) | `[test,eml,context]` | — | **904 / 1** |
| `ead77a3` (head) | core deps only | — | **791 / 114** |

The two bold figures are byte-for-byte the ones in the PR body. **The whole
difference is the two R round-trip tests, and the body already says so:**
`tests/test_roundtrip.py` gates its two tests on `HAVE_R`
(`shutil.which("Rscript")` and `os.path.isdir()` of the `R_LIB_PATH` constant at
`:19`), and the body records *"With R plus metasalmon installed: 898 / 1"* as a
separate line. Two tests move from skipped to passed in both legs, the totals
are 899 either way, and the same pair explains the core leg's 783/116 against
785/114 — which the body does not state but which follows from the identical
gate. So there is no unchased two-test difference and nothing measured here
contradicts the body.

**What is actually stale is smaller and real.** The branch has two commits and
the body's evidence table was measured at the first. At the head — `ead77a3`,
*"Fix the three Codex P2 findings on the S5 port"* — the same two legs give
**six more** passing tests each, because that commit added tests to
`tests/test_review_console.py` and `tests/test_sdp_field_setters.py`. A reader
checking the body against the head finds four numbers all wrong by six, with
nothing in the body saying which commit it describes. That is evidence hygiene
rather than a code defect, which is why it is P4: a PR body's evidence should
reproduce, and when it does not, the first question is whether the measurement
or the environment differs — here it was neither, it was the commit.

*Retires when:* the evidence table names the commit each count was measured at,
or is re-measured at the head; and the convention that a suite count in a PR
body carries its commit is written into wherever that repository records its
release and review procedure. No code change is owed in either repository and no
`PARITY.md` row is owed.

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
publication path is unreachable from the published docs. FIXED IN R
2026-09-15 (hub item B-116); the mirror half is still owed.** Found 2026-08-25
while taking the Fraser coho example to a KNB test-node dry run. Severity:
**high** — it is not a defect in any one function, it is a hole in the golden
path, and the symptom is that a user who does everything the vignette says gets
`metadata/semantic_vocabulary.csv does not exist` with nowhere to go.

**What landed, against the four numbered findings below.** One exported
`write_sdp_semantic_closure(path, evidence = NULL, search_fn = find_terms,
sources = c("smn", "gcdfo"), quiet = FALSE)` in `R/semantic-closure.R`,
following the shape Brett approved on 2026-09-12. It derives both canonical sets
(finding 3) and returns them as `measurement_iris` and `review_targets`, so a
user never reasons one from the other; resolves each IRI's evidence by re-running
`find_terms()` with the query recorded in `semantic_suggestions.csv` or, failing
that, the IRI's own local name split back into words (finding 4's searchable
half); takes hand-supplied rows through `evidence`, overlaid field by field, for
QUDT and for `native_type` / `source_url` (finding 4's unsearchable half);
computes every `reviewed_snapshot_sha256` and both file digests in
`metadata/eml-mapping.yml` (finding 2); and reports an IRI it cannot resolve as a
row of `gaps` in `detect_semantic_term_gaps()` shape, writing both files without
it, rather than aborting. The post-review vignette's "Known gap" callout is
replaced by the producer and its gap path (finding 1's R half).

**The rehearsal script's three `metasalmon:::` calls are gone, and the script
ran end to end to a clean `publish_sdp_to_knb(dry_run = TRUE)` plan on
2026-09-15** — 4 vocabulary rows, 5 ledger rows, both sidecar digests pinned by
the producer, 10 objects in the manifest. Its STAGE 5 and STAGE 6 are swapped so
the EML sidecar is written first and the producer pins its digests, which also
removed the script's last hand-computed file digest. So the measure this item
chose for itself — *"those two calls are the precise measure of this gap"* — now
reads zero.

**Two things this did not close, and they are not oversights.** The **workshop**
surface named in finding 1 lives in `salmon-data-standards-workshop`, which is a
shared repository an agent may not push to, so session 6's callout and its four
`eval = FALSE` publication chunks still describe an unreachable deposit and need
revisiting. And the **mirror half is owed as a port**, not as a deviation row;
the detail is under *What metasalmon 0.5.0 owes the mirror* in
[`knowledge/parity-deviations.md`](parity-deviations.md), and it has no queue item
yet.

**Everything from here down is the diagnosis as found on 2026-08-25, kept
because it is what the fix had to answer.** Read its present tense as of that
date: two of the three files below now have a producer, and findings 2, 3 and 4
are discharged in R. The four findings are numbered, and the "What landed" block
above answers them by number.

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
   a producer ships. *2026-09-15: the vignette surface is revisited (the callout
   is replaced by the producer and its gap path). The workshop surface is not,
   and cannot be from here: that repository is shared.*
2. **`reviewed_snapshot_sha256` cannot be computed by any exported function.**
   `.ms_eml_vocabulary_snapshot_sha256()` (`R/eml-export.R:1182`) is a verifier
   only. Its sole producing caller in the whole repo is
   `tests/testthat/helper-eml.R:134`. A user's only options are to hand-write a
   SHA-256 into a CSV or to reach into `metasalmon:::`, and the first of those
   is not a workflow. *Discharged 2026-09-15: `write_sdp_semantic_closure()`
   computes it for every row, and pins both file digests in the sidecar too.*
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

**Proposed shape, ruled and shipped.** One exported
`write_sdp_semantic_closure()` that reads the package, derives both canonical
sets, resolves evidence for each IRI through the existing search path, computes
the snapshot digests, and writes both files plus the two hashes into an existing
sidecar — with any IRI it cannot resolve reported as a gap rather than guessed
at. Approved by Brett on 2026-09-12 (`knowledge/plans/2026-09-12-queue-promotion-review.md`
§3), including the part that is easy to get backwards: **the gap is reported
because a gap is what the term-request pipeline consumes**, so the producer must
not abort. The same ruling fixed the export set — the internals shared with S-13
requirement 1 are reached *through* the one export and stay unexported. Landed
2026-09-15.

**Worked reference:** `scripts/build-fraser-coho-knb-rehearsal.R` takes the
shipped 173-row example from `create_sdp()` to a clean KNB test-node dry run.
Until 2026-09-15 it reached into `metasalmon:::` at **three** sites (the earlier
wording here said two, corrected by the 2026-09-12 review), and those calls were
the precise measure of this gap. It now reaches into none, which is the measure
reading zero.

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
open at its full scope. **Used as predicted (2026-09-15):**
`write_sdp_semantic_closure()` reads a recorded `decision_reason` for an accepted
IRI and writes it as that target's `review_rationale`, so a reviewer who
recorded a reason once is not asked for it again. Where none was recorded it
writes a `REVIEW REQUIRED:` marker and warns, naming each target — a producer
that invented a confident-sounding rationale would be fabricating the one thing
in the ledger that is purely human.

*Retires when:* a user can produce a publishable package without `:::` and
without hand-writing a digest, and the rehearsal script's three internal calls
become calls to exported functions.

**R half discharged 2026-09-15** on both counts: the rehearsal runs to a clean
dry run with zero `:::` calls, and no SHA-256 in the resulting package was
written by hand. **Retained open for the mirror**, which still has every part of
this hole; the port is specified under *What metasalmon 0.5.0 owes the mirror* in
[`knowledge/parity-deviations.md`](parity-deviations.md) and has no queue item
yet. The workshop surface in finding 1 also still needs revisiting, in a
repository an agent may not push to.

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

**The explainer for this entry is the
[iop-triple card, 2026-09-14](plans/2026-09-14-iop-triple-explainer.md)**,
allowed under Q46. It corrects this entry's own premise, and the correction is
why the card has the shape it does: metasalmon **does** already emit triples.
EML 2.2 semantic annotations are RDF triples by EML's own account, and
`R/eml-export.R` writes exactly two per measurement attribute
(`dcterms:subject` → `term_iri`, `qudt:hasUnit` → `unit_iri`) while documenting
that it "deliberately does not project incomplete I-ADOPT roles". So the gap is
narrower and sharper than "no triples": the package states the components and
never states the relation between them. Two findings from that pass are **not**
part of #78 and belong to separate items rather than to this one — the SDP
cannot distinguish `hasObjectOfInterest` from `hasContextObject`/`hasMatrix`,
and cannot express I-ADOPT's `constrains` target at all.

### The 2026-09-15 recovered findings

**Twelve findings recovered from four hub agents' workpads and pull requests
after the fact, plus a thirteenth found while filing them** — the four items
worked on the night of 2026-09-15 were `B-116`, `B-111`, `B-115` and `B-106`.
Each agent named what it had found and deliberately did not absorb; none of it
was a queue item, and a finding that lives only in a workpad is a finding the
next reader re-derives. They are headed by their
**queue id** for the reason the *2026-09-15 fleet findings* section
gives: `#120` is the last number this file issued and inventing `#121` upward
would create a second numbering nobody reconciles. **State is not here** —
whether one of these is icebox, ready, claimed or done lives in `queue/items/`,
and this section is what each item's `evidence:` pointer resolves to. **The
heading above says nothing about state on purpose**, and the older `Open — …`
headings further up this file are the pre-queue convention rather than the one to
copy: a heading reading `Open` is a second copy of a dozen items' state, it goes
stale the moment any one of them moves, and nothing checks it. *Retires when:*
those older headings are relabelled too, at which point this note is no longer
telling a reader why the neighbours differ. That fleet section — the defects from
`B-149` up, and its questions in [`questions.md`](questions.md) — is the sibling
of this one: same night, different agents, filed separately.

**Twelve recovered findings, eleven items** (twelve counting `B-173`, which was
not recovered from anything). One of the twelve, `B-172`, has **no item file**:
the one-line fix was folded into the change that produced the finding before it
could be scheduled, and its entry below is the record. A finding and a queue item
are not the same thing, so the count of findings above stays what it was.

| Found by | Items |
|---|---|
| **B-116** (PR #121, the closure producer) | `B-164`, `B-165`, `B-169`, `B-170`, `B-171`, and `B-172` (absorbed, no item) |
| **B-115** (PR #118, the descriptor instant) | `B-161`, `B-162` |
| **B-111** (PR #119, the create-path sidecars) | `B-163` |
| **B-106** (PR #120 and smn-data-pkg PR #8, the reworded rules) | `B-166`, `B-167`, `B-168` |
| *nobody* — found by tripping over it while filing `B-164` | `B-173` |

**Every description was re-verified before it was filed, and four of the twelve
moved when checked.** That is the measurement worth keeping, because all twelve
arrived as confident prose and none of the four looked wrong. `B-163`'s blast
radius named files that are not on the atomic path, and asserted a durability
divergence with the mirror that does not exist. `B-164` arrived as "two
vignettes fail" and is in fact invisible to CI, on a step the CI's R no longer
runs. `B-168`'s git half is false in all three repositories, and the half that
*is* true belongs to a different repository than the one it was reported
against — so it is filed against metasalmon. `B-170` overstated the churn.
Three more gained precision that changes the work rather than the claim
(`B-161`, `B-166`, `B-167`), and **one could not be verified at all** (`B-169`),
which its entry says rather than asserting what it could not check.

**A note on that rate, since it is the second night running.** The fleet
findings above were filed by an agent that was told six of its handed-down
descriptions were wrong and found them; this pass was told to assume the same
rate and found four plus one unverifiable. Two passes is not a trend, but it is
enough to stop treating a workpad sentence as a finding: it is a **lead**, and
the distance between the two is a third of them.

**`B-161` `readr::write_csv()` writes an unpadded, invalid `xs:dateTime` year
for a pre-1000 instant on Linux.** Reproduced 2026-09-15 on R 4.3.3 with readr
2.2.0:

```r
readr::write_csv(data.frame(t = as.POSIXct("0001-02-03 04:05:06", tz = "UTC")), f)
#> t
#> 1-02-03T04:05:06Z          <- not a valid xs:dateTime
readr::write_csv(data.frame(t = as.POSIXct("0999-12-31 23:59:59", tz = "UTC")), f)
#> 999-12-31T23:59:59Z        <- nor is this
```

So `metadata/dataset.csv` carries bytes this package cannot parse back. It is
**#93's `as.character` Date defect in the same shape on readr's *instant*
path**, and unlike #93 it **is** platform-dependent — which this file already
records without having noticed. **#93 item 1's** own comparison table, measured
on macOS R 4.5.2, has the row `POSIXct, year 1 → 0001-01-01T00:00:00Z —
*already correct*`, and **#115**'s entry rests on it in prose: *"`readr::write_csv()`'s
instant output is already ISO-correct"*. True on macOS, false on Linux, and CI
runs Linux.

**B-115 and PR #118 deliberately did not absorb it**, and say so in
`R/platform-time.R` on that branch, which is the right call and worth stating so
nobody folds them: what B-115's branch *achieves* is **agreement** between
`datapackage.json` and `metadata/dataset.csv`, agreement now holds on both
platforms, and this is the separate question of whether the agreed-on bytes are
*valid*. Reachable only from a caller-supplied typed instant, which neither
implementation produces on its own.

**B-115's recorded condition asks for more than agreement, and on Linux the two
halves of it cannot both hold. This entry is where that is written down, because
the fix is not this item's to make.** `queue/items/B-115.yaml` reads:

> A typed `POSIXct` reaching the descriptor renders as readr's ISO instant form,
> with the `T` separator and the `Z` zone marker (`0999-06-05T13:45:30Z` for the
> backlog's fixture), **which is what `metadata/dataset.csv` already writes**

The parenthetical literal and the closing clause name **the same bytes on macOS**,
where #115's comparison table was measured, and **different bytes on Linux**,
where `readr::write_csv()` writes `999-06-05T13:45:30Z` for that same fixture —
the measurement at the top of this entry. So on the platform CI runs, an
implementation can satisfy the agreement half or the padded-literal half, and no
Linux implementation can satisfy both **unless the CSV path is padded**, which is
precisely the decision this item defers: padding it reopens #93 item 1, which
ruled that `.ms_iso_date_columns()` leaves `POSIXct` alone and ruled it
*correctly*. B-115's branch satisfies the agreement half. The padded literal is
not reachable from it at all.

**The consequence, stated plainly because it is the reason this paragraph exists:
B-115 can be merged and marked `done` while violating its own recorded retirement
condition, and nothing in either item file would say so.** This entry does not
rewrite B-115's clause and nobody else should either before the ruling — Brett
approved PR #118 without ruling the byte, and the spelling is his. **What the
ruling now has to settle is two things rather than one:** which spelling a
pre-1000 instant takes in `metadata/dataset.csv`, and whether B-115's condition is
restated to name the ruled bytes at the same time. Found by a Codex review of
pull request 123 and escalated to Brett on 2026-09-16; it is deliberately left as
a stated conflict rather than a quiet edit, because the quiet edit would be an
agent choosing the byte.

*Retires when:* `queue/items/B-161.yaml` says, and this passage deliberately
does not restate it — it is the card's evidence, not a second definition. The
shape, for a reader deciding whether to open the card: a **ruling**, not an
implementation, but one that must also leave the queue **walkable** from itself
to a state where what the writers emit, what the profile admits and what the
validators check all agree, with every step of that walk filed as an item in the
repository that can finish it.

*(This said "**the ruling alone** — one spelling … together with whether B-115's
condition is restated" between the split and `c5e7f59` on 2026-09-16. That was
right for about an hour and then became an **under**-statement, which is the
dangerous direction: a reader could have treated the ruling as finished without
the re-vendor and pin work the walk needs. Caught by the Codex review of pull
request 137 — the second time the same edit was made to the card and not to this
passage, which is why the passage now points rather than copies.)*

**It said "and both implementations emit it, with a test pinning write → read
for a `POSIXct` below year 1000" until 2026-09-16, and that clause is now the
emission halves** — `B-206` (metasalmon) and `B-207` (metasalmonpy), each blocked
on the ruling and each naming the other. The split is a fix rather than a
rescoping: the old wording could not be satisfied inside the item's declared
`repo: metasalmon` at all, which is the claimable-and-unfinishable case
`queue/README.md` forbids and whose prescription is exactly this pair. It went
unseen because `claimable: false` meant nobody could take the item and discover
it. Caught twice by the Codex review of pull request 137 — once on the card, and
again here, on the `evidence` pointer, which is the copy the first fix left
behind. **A ruling, not a substitution**,
which is why the item is not claimable: padding the CSV side means reopening #93
item 1 deliberately — it ruled that `.ms_iso_date_columns()` leaves `POSIXct`
alone, *correctly*, because coercing an instant changes the separator, the zone
marker and whether a fractional second survives — and the only alternative is
accepting a platform-dependent instant year ecosystem-wide. Cross-references
B-115, B-145, #93 item 1; like B-115 it has to be ruled for both
implementations at once or it creates a parity row instead of closing one.

**`B-162` EML `calendarDate` renders `temporal_start` through a third
renderer.** `R/eml-export.R:1661` and `:1663` read
`as.character(temporal_start)` and `as.character(temporal_end)` inside
`.ms_eml_add_coverage()` (`:1603`) — a third rendering of one value in a package
whose contract is *one value, one rendering*.

**Filed as an observation and not a verified defect**, which is the strength it
was reported at and the strength it was confirmed at. On today's only path it
cannot diverge: the frame arrives as `pkg$dataset` from
`validate_salmon_datapackage()` (`R/eml-export.R:2915`), which reads
`metadata/dataset.csv` through `.ms_read_metadata_csv()`
(`R/package-helpers.R:2814`) with `col_types = cols(.default = col_character())`,
so every cell is character and `as.character()` is the identity. A typed instant
has never been driven through it.

*Retires when:* both lines render through the same renderer the two writers use,
**or** a test pins that all three agree for a typed `POSIXct`, **or** the
question is answered by-design and this closes with no code change. It becomes
real the moment any caller hands the EML builder a typed metadata frame — which
is exactly the situation B-115 established is reachable for the other two
writers — so the cheap close is the test.

**`B-163` The SDP atomic write set renames a staging file it never flushed.**
`.ms_sdp_extension_atomic_write_set()` (`R/sdp-extension-helpers.R:133`) stages
each replacement with `writeBin()` at `:186` and installs it with
`file.rename()` at `:240`, with no flush between; the rollback path — the
rename-aside at `:234` and the restore at `:206` — has the same shape. It is
**atomic against an aborted call and not durable against a crash**: a power loss
after a rename can leave a renamed empty file where the previous bytes were.

**The blast radius as reported was wrong in two directions and the corrected one
is the point of the item.** On `main`, what reaches the write set is
`write_salmon_datapackage()` through `.ms_commit_package_write()`
(`R/package-helpers.R:718`), the `set_sdp_*()` setters through
`.ms_set_sdp_metadata()` (`R/sdp-field-setters.R:850`), `apply_sdp_semantics()`
(`R/metadata-write.R:463`), `migrate_sdp_methods()` (`R/sdp-methods.R:560`) and
`write_sdp_observation_structures()` (`R/observation-structures.R:946`).
`create_sdp()`'s three sidecars are **not** on it today — they arrive with B-111
and PR #119, which is what that item does. And KNB publication, the
reproducibility manifest and measurement decompositions do **not** go through
the set at all: each has **its own** `tempfile` → `writeBin` → `file.rename`
helper with the identical gap (`R/knb-publication.R:865`,
`R/reproducibility-manifest.R:220`, `R/measurement-decompositions.R:537`), and
so do SSSOM (`R/sssom.R:870`), EML export (`R/eml-export.R:3007`) and ontology
fetch (`R/ontology_fetch.R:90`). Six private copies of one pattern, six copies
of one gap.

**The mirror half is not a divergence today, which corrects the report
directly.** metasalmonpy has **zero** occurrences of `fsync`; `atomic_io.py`'s
`atomic_write()` writes through `os.fdopen`, chmods, and calls `os.replace` with
no flush. The two implementations are therefore **identical in durability** and
no register row is owed. What differs is the *cost of closing it*: Python has
`os.fsync` in the standard library and base R exposes nothing, so R needs
compiled code, a new dependency, or an external `sync`. That asymmetry is an
argument for ruling once for both rather than letting Python close it quietly
and open a register row.

*Retires when:* Brett rules whether metasalmon takes on compiled code, a
dependency, or an external call to make an SDP write durable, and — if he rules
for durability — the staging file and its directory are flushed before the
rename with a test pinning the call, naming the six independent writers or
deliberately leaving them out.

**`B-164` #32's fix has no guard, and two vignettes written after it carry the
shape it closed.** #32 was closed 2026-07-21 under roadmap E5 by adding
per-chunk `purl = FALSE` to six vignettes and adding **nothing that would notice
a seventh**. Its entry already states the rule the two later vignettes break: *a
global runtime `knitr::opts_chunk$set(eval = FALSE, purl = FALSE)` is
insufficient because the check's tangle phase does not execute the setup chunk.*

`vignettes/migrating-to-sdp-0-3-0.Rmd` and `vignettes/tidy-data-for-sdp.Rmd`
each open with an `include = FALSE, purl = FALSE` setup chunk setting only
`collapse`, `comment` and `eval = FALSE`, then use bare ```` ```{r} ```` headers
for 18 and 7 content chunks. Reproduced 2026-09-15, in the built tarball rather
than by reading:

```
$ R CMD build .
  -> inst/doc/migrating-to-sdp-0-3-0.R   (209 lines)
     inst/doc/tidy-data-for-sdp.R        (86 lines)
     and NO .R file at all for the other nine vignettes

$ R CMD check --no-manual --no-tests --no-examples metasalmon_0.5.0.tar.gz   # R 4.3.3
  * checking running R code from vignettes ...
    'migrating-to-sdp-0-3-0.Rmd' using 'UTF-8'... failed
    'tidy-data-for-sdp.Rmd' using 'UTF-8'... failed
   ERROR
  * checking re-building of vignette outputs ... OK
  Status: 1 ERROR, 1 WARNING
```

`--no-tests --no-examples` narrows the run to the vignette steps, so the one
ERROR is this and nothing else; the WARNING is the container's `en_US.UTF-8`
locale and is not the package's. Both failures are the **first line** of each
tangled file — `readr::read_csv()` on a package directory the setup chunk would
have created had it run — so the re-tangle plainly happens in a session where it
did not.

**Framing it as "two vignettes fail" is what the re-check corrected, and the
correction makes the guard mandatory rather than merely desirable.** The check
step that catches this **does not exist on the R that CI runs**: the
`R-CMD-check` job on **R 4.6.1** prints `checking package vignettes` then
`checking re-building of vignette outputs` with no `checking running R code from
vignettes` between them. CI is green, and would stay green through any number of
further regressions. (Which R release dropped the step was not determined —
present on 4.3.3, absent on 4.6.1.) That **inverts** the warning in `AGENTS.md`
rather than repeating it: there a green local check hid a CI failure; here a
green CI hides a failure any user on an older R hits.

**Determined 2026-09-24, by the change that added the guard: R 4.4.0 stopped
running the step, by changing a default rather than removing the code.** In
`tools:::.check_packages()`, `R_check_vignettes_skip_run_maybe` reads
`_R_CHECK_VIGNETTES_SKIP_RUN_MAYBE_` with a default of `"FALSE"` at R's
`R-4-1-0`, `R-4-2-0` and `R-4-3-3` tags and `"TRUE"` at `R-4-4-0`, `R-4-4-3`,
`R-4-5-0` and trunk, read from `src/library/tools/R/check.R` at each tag in the
`wch/r-source` mirror; the `NEWS.Rd` at `R-4-4-0` does not name the variable.
When it is true and the vignettes are being re-built, the step runs only for a
vignette with a `.Rout.save`, and none here has one. `--as-cran` sets it on
every version, 4.3.3 included, so the reproduction above saw the step because
it ran without `--as-cran`. The function the step calls for each vignette,
`tools:::.run_one_vignette()`, fails on both files when called directly on
R 4.3.3 and completes on the other nine, which is exactly the guard's verdict.

*Retires when:* a test fails when a vignette relies on the global
`opts_chunk$set()` form instead of per-chunk `purl = FALSE`, demonstrated RED
against both files before either is fixed. The two fixes are not the item; the
guard is.

**`B-165` The metasalmonpy port of `write_sdp_semantic_closure()`.** The R
producer is **proposed in PR #121** (B-116, #116) and the port has **no queue
item**, unlike its two siblings B-124 and B-125. *Proposed* and not *shipped*:
that pull request is open as this is written, and its state lives in
`queue/items/B-116.yaml` and in the pull request itself rather than here — this
section's own preamble says state is not recorded in this file, and a sentence
calling an open change shipped is exactly the second copy that rule exists to
stop. It also mislabels the port's baseline, which is the reader-visible cost:
the Python side would be following an R behaviour that can still change in
review. **The specification is already written and is
deliberately not restated here**: *What metasalmon 0.5.0 owes the mirror* in
[`parity-deviations.md`](parity-deviations.md) gives it field by field, and the
release index in [`roadmap.md`](roadmap.md) carries the same addition to the
catch-up window. Both were written by PR #121, and both say in their own words
that the item is missing.

**It is not B-153 and it is not B-126**, which is worth stating because all
three are metasalmonpy and all three are 0.5.0-shaped: B-126 is the S5
*behaviour* port of the nine review functions; B-153 is the S5 *documentation*
half plus the version bump that closes the 0.4.0 → 0.5.0 window; this is a third
thing. Owed as a **port** and not a register row, because absence in Python is
lag rather than design.

*Retires when:* metasalmonpy exports one `write_sdp_semantic_closure(path,
evidence=None)` doing what the R producer does and `guides/semantic-review.qmd`
documents it. **The gap-not-abort shape is the part Brett ruled** (2026-09-12)
and must not become an exception on the Python side.

**`B-166` Re-vendor `sdp.rules.yaml` into metasalmonpy.** Measured 2026-09-15 —
metasalmon `main`, metasalmonpy `data/schema/` and smn-data-pkg `main` all carry
md5 `3c702a373409b23f9c58cb1e1a702c06`, and the reworded file on metasalmon's
B-106 branch is `2f6126c241ce637955604b75e48b9265`. So all three copies sit at
the pre-change bytes today, with the source change open as smn-data-pkg #8 and
metasalmon's re-vendor open as PR #120 — and metasalmonpy's with nothing open
for it at all. A **port, not a deviation** — the file is vendored
spec text rather than an implementation choice, so no register row, and a stale
vendored copy is a third answer to a question smn-data-pkg owns.

*Retires when:* metasalmonpy's copy matches smn-data-pkg's once smn-data-pkg #8
merges.

**`B-167` `SPECIFICATION.md` and four other documents still carry the reading
the reworded rules drop.** Five documents, six passages, carry *"resolves to a
shared vocabulary concept typed as a `sosa:Procedure`"* or its twin. **Which are generated was
established rather than assumed**, because regenerating and hand-editing are
different work and the report did not distinguish them:

| Site | How it is maintained |
|---|---|
| `SPECIFICATION.md:237-238`, `:265` | hand-edited |
| `template-source/salmon-data-package-template/README.md:15-17` | hand-edited |
| `examples/mixed-grain-example/README.md:15-16` | hand-edited |
| `docs/field-reference.md:64` | **generated** from `schema/frictionless/metadata/tables.schema.json:76` by `scripts/generate_artifacts.py`; carries a do-not-edit banner |
| `templates/salmon-data-package-template/README.md` | **generated** — copied verbatim from the `template-source` file and byte-identical to it |

Three source edits plus one regeneration therefore reach all six.

*Retires when:* every copy carries the reachability reading Brett ruled
2026-09-14, in wording that agrees with the rules file. **Rewording normative
spec prose is itself a semantic choice**, so the pull request has to say what
justified the new wording *other than* the rules file already carrying it — the
failure class `AGENTS.md` says code review structurally cannot catch — rather
than inheriting B-106's justification. `SPECIFICATION.md` calls itself the
human-readable validity specification and `docs/field-reference.md` defers to
it, so a spec disagreeing with the rules file is the spec being **wrong**, not
merely stale.

**`B-168` `.pytest_cache` is in no ignore file in the ecosystem, and a stray one
adds an `R CMD check` NOTE that muddies a baseline.** The report was **half
right, and the half it got wrong is why this is filed rather than fixed in
passing**. It read: *".pytest_cache is git-ignored but not in metasalmon's
`.Rbuildignore`"*.

**The `.Rbuildignore` half is true and has a measured consequence**, recorded
twice on 2026-09-15 by two agents who could not see each other. The B-106 run
found `checking for hidden files and directories ... NOTE / Found ...
.pytest_cache` on its *baseline* worktree and not on its own, and the B-116 run
recorded the same note as a baseline-only difference. Nothing excludes the
directory, so `R CMD build` packages it: a worktree where pytest has been run
and a fresh one produce different check output. In a fleet whose agents read
their result against a baseline run, that is noise in the one measurement the
baseline exists to provide.

**The git half is false in all three repositories.** `git check-ignore -v
.pytest_cache` **exits 1** in smn-data-pkg, and the Python block of every
`.gitignore` here is `__pycache__/`, `*.py[cod]`, `*$py.class`, `*.so`,
`.Python` and virtualenv entries with no pytest line — metasalmon line 69,
metasalmonpy line 79, smn-data-pkg the same. What actually keeps it out of `git
status` is that **pytest writes `.pytest_cache/.gitignore` containing a single
`*`** when it creates the directory, so every file inside ignores itself:
`git check-ignore -v .pytest_cache/CACHEDIR.TAG` reports
`.pytest_cache/.gitignore:2:*` as the matching rule. That is the guard shape
`AGENTS.md` warns about seen from the far side — the protection is a
third-party artifact nobody in the repository knows about, it stops silently if
pytest changes it, and reading the repository alone tells you nothing is wrong.

**The item is filed against metasalmon and not smn-data-pkg**, deliberately:
smn-data-pkg has **no `.Rbuildignore` at all** and is not an R package (no
`DESCRIPTION`, no `NAMESPACE`), so the half with a consequence exists only
here.

*Retires when:* metasalmon's `.Rbuildignore` excludes `.pytest_cache`, so a
checkout where pytest has been run builds the same tarball as a fresh one; and
`.gitignore` names `.pytest_cache/` beside the `__pycache__/` entry it already
carries, here and in the two siblings that run pytest. P4 — nothing is
committed today and it is one line per repository — and filed rather than
dropped because the next person to check re-derives the same wrong answer.

**`B-169` Workshop session 6's gap callout goes stale and its publication chunks
become runnable when the closure producer ships.** #116 finding 1 names two
downstream surfaces to revisit when a producer ships; the post-review vignette
is the other and is already revisited on PR #121's branch, so this is the
remaining one.

**Not verified against the repository, and this entry says so rather than being
filed as though it had been.** `salmon-data-standards-workshop` is neither
checked out on the machine that filed this nor readable from the session, so the
callout and the count of four `eval = FALSE` publication chunks come from **#116
finding 1 as recorded 2026-08-25** (workshop PR #5: session 6 states the gap in
a callout and tells learners plainly that a complete deposit is not reachable
unaided, which is why its four publication chunks stay `eval = FALSE`) and from
PR #121, which names the same surface as not done for the same reason. Whoever
claims it reads session 6 first and corrects the count if it has moved.

**The deliverable is a patch and its pull-request text shown to Brett in chat,
never a push.** `salmon-data-standards-workshop` is the member repository
`HUB.md`'s participation table records as having one collaborator other than
Brett, in commits and issues, so the standing authorization does not reach it —
neither the work-branch push nor the draft pull request.

*Retires when:* session 6 no longer tells learners a complete deposit is
unreachable unaided, and its publication chunks run.

**`B-170` The roxygen2 version pin is a release behind the toolchain.**
`DESCRIPTION` records `Config/roxygen2/version: 8.0.0`; the installed toolchain
is roxygen2 **8.1.0**. Running the namespace roclet produces a 20-line
`NAMESPACE` diff plus the version bump, so any agent running
`devtools::document()` must carry that churn into an unrelated diff or revert it
by hand — which is what PR #121 did, and recorded.

**The churn is narrower than reported, and the correction changes how the cost
is judged.** 8.1.0 does not rewrite *every* `importFrom` directive; it collapses
the directives of a package with more than one imported name into one multi-line
directive. So the five `dplyr` lines and three `rlang` lines become two blocks,
while `importFrom(tools,toTitleCase)` and `importFrom(utils,askYesNo)` come out
byte-identical:

```
-importFrom(dplyr,"%>%")          +importFrom(dplyr,
-importFrom(dplyr,coalesce)       +  "%>%",
-importFrom(dplyr,filter)         +  coalesce,
 ...                              ...
 importFrom(tools,toTitleCase)     importFrom(tools,toTitleCase)   <- unchanged
```

*Retires when:* Brett rules which version metasalmon pins, `DESCRIPTION` carries
it, and `NAMESPACE` is regenerated under it in the same commit so the next
`document()` run produces no diff. Not claimable: a pin is a statement about the
toolchain the project supports, so an agent choosing one would be inventing a
policy rather than doing work.

**`B-171` The code-resolved `sosa:usedProcedure` direction of B-116's two
canonical sets is held by construction and no fixture.** B-116's central claim
is that the two canonical sets *legitimately differ and neither can be reasoned
from the other* — and only one direction of it has a fixture. In both
`make_eml_test_sdp()` and the shipped Fraser coho example the difference is
exactly one row, `smn:Observation`, a review target and not a vocabulary term
because it is the table's `observation_unit_iri`.

The other direction — an IRI reached through a code value, which is a
vocabulary term and not a review target — is held by construction in
`.ms_closure_iri_roles()` (`R/semantic-closure.R:351` on PR #121's branch),
whose fallback returns role `method` for an IRI in the measurement set carrying
no `dictionary_role` row. **Nothing reaches that fallback**: the only matches for
`method` in the new test file are `sort(..., method = "radix")`. The branch's
workpad names it as a testing gap rather than leaving it implied, which is why
this is a fixture item and not a defect report against the producer.

*Retires when:* a fixture binds a column with `component_relation_iri` =
`sosa:usedProcedure` whose `codes.csv` `term_iri` lands in the measurement set
and in no review target, and a test asserts it reaches
`metadata/semantic_vocabulary.csv` and not `reviewed_semantic_selections.csv`.

***`B-172` PR #121 claims four guards state their retirement condition in the
source, and one does not — absorbed into PR #121, no item file.*** Its Guards
section reads *"Four, all with retirement conditions in the source and restated
in the workpad."* `R/semantic-closure.R` as first pushed on that branch contains
**exactly two** `Retires when:` comments — `:117` for `.ms_closure_source_url()`
and `:573` for `.ms_closure_set_mapping_digest()` — and the `REVIEW REQUIRED:`
rationale placeholder is constructed at `:923` with no retirement condition
anywhere near it.

The condition exists and is a good one (*the review API records a rationale for
every accepted slot, or a publication gate refuses the marker, which is a
decision nobody has made*), but it lived only in the pull-request body and in
`.hub/workpad.md` item 4 — and a pull-request body evaporates, which is why this
repository writes such things into files. The fourth guard, the two
`collation_sensitive_fns` entries, carries the rest of that list's condition
rather than one of its own; the workpad says so outright and that is a
defensible reading of an enumerated list, so it was never part of the finding.

**Why there is no `B-172.yaml`, and it is the scheduling rather than the
evidence.** The item was filed `blocked_by: [B-116]`, which is the worst possible
ordering for it: the queue lets a blocked item be claimed only once its blocker is
`done`, so a contract violation would have merged with PR #121 and its one-line
fix would have arrived after it, in a separate pull request, for a comment the
author was standing next to. The fix belongs in the change that introduced the
gap. **PR #121 now carries the comment**, at the placeholder's construction site
rather than near it, ending:

> *Retires when:* every accepted slot has a recorded rationale to read, so a
> target without one is a defect rather than a row to mark. Concretely: when
> `accept_suggestion()` requires a `decision_reason` and `apply_sdp_semantics()`
> carries it through to `semantic_suggestions.csv` for every accepted row, this
> branch becomes unreachable and the marker, the `placeholders` return value and
> the warning all go together, replaced by an abort naming the slot.

That is the whole of what the item asked for, so nothing is left to narrow it to
and the item was deleted rather than left as work that is already done. The
`B-172` id is retired unused and the gap between `B-171` and `B-173` is the record
of it. **Re-file if PR #121 merges without that comment** — this entry is written
on the state of that pull request on 2026-09-16, not on a merge, and the absorbing
change had not yet been pushed when this was written. Found by a Codex review of
pull request 123, which read the `blocked_by` rather than the evidence and was
right to.

**`B-173` `hub_queue.py` silently truncates an unquoted value at the first
` #`, and `lint` reports OK.** A thirteenth finding, and the only one here that
was **not** recovered from a workpad: it was found by tripping over it while
filing `B-164` above.

That item's file said:

```yaml
title: Backlog #32's fix has no guard, and two vignettes written after it carry the shape it closed
```

`hub_queue.py list` rendered the title as the single word **`Backlog`**, and
`lint` printed `OK`.

`strip_comment()` (`scripts/hub_queue.py:302`) cuts an unquoted value at the
first ` #`. That is correct YAML and the schema block at the top of that same
file documents it — *"A value that contains `#` must therefore be quoted, which
is why `legacy` is written `'#53'`"*. **The defect is not the rule; it is that
breaking the rule is silent and the guard says OK.** A truncated title is still
a valid title, so every existing check passes, and the only signal is a human
reading a rendered block weeks later and finding a sentence that stops
mid-thought. That is the failure this queue was built to remove, occurring
inside the queue's own validator: the file on disk and the fact the client reads
have quietly become two different things.

The exposure is one-directional and worth naming. A backlog citation of the form
`#N` is the **single most likely** thing to appear in `title` and
`retires_when`, because every item migrated from this file cites one — so the
one construction the stripper eats is the one the fields are full of.

**It was already live on `main`, in two items, and had been for weeks.** A sweep
of all 110 item files for an unquoted value containing ` #` found exactly two,
and they are `B-124` and `B-125` — the pair `B-165` above is filed beside:

```
$ python3 scripts/hub_queue.py list        # before
  B-124    Port the validator checks of        [P1; blocked by B-49]
  B-125    Port the categorical inference of   [P2; blocked by B-95]
```

Both titles end mid-phrase, because both cite `#49` and `#95`. Both are quoted
now, in the same change as this entry, and the sweep is the thing to re-run
rather than the fix to remember. `lint` reported `OK` on them throughout.

*Retires when:* `lint` refuses, or warns by name, when `strip_comment()` removes
text from a value that is not a comment — at minimum for `title` and
`retires_when` — demonstrated RED against a title reading `Backlog #32's fix has
no guard`. A complete fix compares the stripped value against the raw one and
refuses when the removed text does not look like a comment; a cheaper partial
one refuses any unquoted value containing `#`, which also catches the case where
the truncation happens to leave a plausible sentence behind.

### The 2026-09-16 filing of #111's mirror half

**One item, and the only new thing about it is the queue file** — the evidence
was written by the change that created the gap. metasalmon PR **#119** closed
**#111** (queue `B-111`) and, on the same branch, recorded in
[`roadmap.md`](roadmap.md)'s metasalmonpy release index and in register
[row 53](parity-deviations.md) that the Python half was not done, that it would
**not** retire with the R half, and that **nothing in the queue covered it**.
`B-179` is that item, and each of those two records now names it. Headed by its
**queue id** for the reason the two sections above give, and **state is not
here**: whether it is icebox, ready, claimed or done lives in `queue/items/`,
and this section is what its `evidence:` pointer resolves to.

**`B-179` metasalmonpy's three `create_sdp()` sidecars are still
unlink-then-rewrite, and its widest window is wider than R's ever was.** Read
2026-09-16 against metasalmonpy `main` `1f510c9`, at the call sites rather than
from the register:

| Site | Shape |
|---|---|
| `package_io.py:388` | `_replace_create_output(path)` — `path.unlink()`, and the caller renders the replacement afterwards |
| `package_io.py:1545` | `README-review.txt`: unlink, then `readme_path.write_text(...)` |
| `package_io.py:1820` | `semantic_suggestions.csv`: unlink, then `suggestions.to_csv(...)` |
| `package_io.py:1838` | `metadata/metadata-edh-hnap.xml`: unlink, then **`read_salmon_datapackage(pkg_path)` at `:1839`**, then `edh_build_hnap_xml(...)` |

The last row is the difference from R and it is not a detail: the whole package
is read and parsed from disk **after** the previous EDH file has been destroyed,
so every read and parse failure of every file in the package sits inside the
destroyed-file window too. R built from the in-memory `artifacts$dataset_meta`
and never had that. Register row 53 measured the consequence during S10 chunk H
on 2026-08-22 rather than inferring it — 5479 bytes of previously written XML
deleted with nothing in their place — and said in advance that closing R's half
would leave this standing. It has.

**This is a live data-loss path, not a missing feature**, which is the reason it
is owed as work rather than as bookkeeping. Re-running `create_sdp()` regenerates
all three files, so the loss only bites a copy the user has changed — and all
three are exactly that kind of copy: an annotated `README-review.txt`, a
`semantic_suggestions.csv` carrying review decisions, or the EDH XML of a
package whose metadata has since moved on. The three files a re-run cannot
reproduce are the three files at risk.

**The port uses `atomic_io.py`, and the one thing it must get right is where the
abort goes in.** metasalmon's `tests/testthat/test-create-sdp-sidecar-atomicity.R`
is the model: three abort injections at the three **render** steps, each
asserting the prior file is byte-identical afterwards, plus a happy-path
round-trip and a direct-filesystem-call guard. **Injecting at the install instead
proves nothing** — a staged-sibling rename leaves the prior bytes in place by
construction, so such a test passes on the unfixed code. The R run learned a
second lesson by hitting it, and it transfers directly: **key each hook on
content, never on the destination path**, because the post-fix render writes into
a staging file and a path-keyed hook silently stops injecting while the test
still goes green (R's suggestions hook is keyed on the frozen 19-column target
row for exactly this reason). In Python, `edh_build_hnap_xml` is already
render-level and survives the fix; a hook on `Path.write_text`, or a `to_csv`
hook keyed by its path argument, does not.

**A second record is owed with or before the port, and it is a correction rather
than a new row.** metasalmonpy's `PARITY.md` copy of row 53 still describes the
sidecars as unlink-then-rewrite *"on both sides"* and cites
`R/package-helpers.R:1387-1392` for a `.ms_replace_create_output()` call PR #119
deletes. Once #119 merges, the two registers disagree about which side is
defective, with nothing in either file saying which is right — the failure mode
both `AGENTS.md` files name when they say to read the other file rather than
trust the one in front of you. Every one of that row's **Python** line citations
has drifted too, measured the same day: `:1506` → `:1545`, `:1738` → `:1820`,
`:1755-1760` → `:1838-1841`, and the `write_salmon_datapackage()` call it credits
at `:1706` is at `:1788`. The correction is the row's claim, not its line
numbers; the drift is worth recording only because re-reading the call sites is
what a corrector has to do anyway. The correction reaches one more place, found
while checking those call sites: the docstring of
`test_create_sdp_inherits_the_transactional_package_write` in
`tests/test_write_datapackage_abort_safety.py` states that the three sidecars
"are still unlink-then-rewrite and are NOT covered here" — true today, and the
sentence the port falsifies.

**One thing for the porter to settle rather than discover, because the two
registers already name different writers.** Row 53 here says the port goes
through `atomic_io.py`; the twin's retirement clause says `_atomic_write_set()`.
Both exist in metasalmonpy — `atomic_io.atomic_write(data, path)` is the
single-file staged-sibling rename, and `sdp_methods._atomic_write_set()` is the
rollback-capable set that mirrors `.ms_sdp_extension_atomic_write_set()`, so a
one-entry call to it is the literal analogue of R's
`.ms_sdp_extension_atomic_write()` wrapper. Either satisfies *render to bytes,
then install by rename*. **What must not happen is a third mechanism**, and the
R half's reasoning for keeping the three as three transactions rather than one
set transfers unchanged: they are independent files written at different points
in `create_sdp()`, the harm is a destroyed file rather than a partly-updated
group, and the suggestions branch can also *delete*, which a write set has no
operation for.

**A port and not a deviation**, so no numbered row is added to
[`parity-deviations.md`](parity-deviations.md) and row 53 is neither renumbered
nor duplicated: absence in Python here is ordinary "R shipped first" lag, not a
chosen difference, and a shared defect one side has fixed is not a design
decision to register.

**It is not `B-163` and it is not `B-165`**, which is worth stating because all
three touch the same writers. `B-163` is the `fsync` durability gap in the atomic
write **set**, and its own text records that the mirror half is *not* a
divergence today, because metasalmonpy has zero occurrences of `fsync` and
`atomic_io.atomic_write()` calls `os.replace` with no flush either — that item is
the write set never flushing, and this one is Python never reaching the writer at
all. `B-165` is `B-116`'s mirror half, `write_sdp_semantic_closure()`.

*Retires when:* metasalmonpy's three create-owned sidecar writes render to bytes
and install through the `atomic_io.py` writer, `_replace_create_output()` has no
callers, and the EDH path either builds in memory the way R does or brings its
whole read inside the transaction — pinned by three abort injections at the
render steps, each demonstrated RED against the pre-fix code, with the
`PARITY.md` correction landing in the same change.
### The 2026-09-16 orchestrator filings

**Four items filed by the orchestrator on 2026-09-16, none of which had a
backlog entry until Codex asked where the evidence was.** Each carried
`evidence: knowledge/backlog.md` and appeared in that file nowhere — the exact
shape the agent brief had been rewritten to warn about hours earlier: *"a
dangling pointer is quieter than a stale copy, because nothing contradicts
anything and the reader simply finds nothing."* Written four times in one
sitting by the author of that sentence, which is the useful part of the record.
Items filed by agents the same night (`B-161`, `B-173`) carry entries; the
difference is that an agent follows a written protocol and the orchestrator was
working from memory.

**`B-180` `AGENTS.md`'s no-absolute-paths rule for bundle cards is enforced
nowhere in bundle prose.** Three live violations on `main`, measured
2026-09-16: `knowledge/plans/2026-08-12-ontology-alignment-pass.md:58` and
`knowledge/plans/2026-09-04-salmon-science-foundry-concrete-plan.md:1958`, each
a tilde-rooted path inside a command, and
`knowledge/plans/2026-06-24-alice-assmar-metasalmon-report.md:236`, a literal
temporary-directory path in a `--body-file` argument.

`scripts/hub_queue.py` already owns the regex and an `absolute-path` problem
class and applies it to queue item fields only, so the guard stops at the queue
boundary while the rule is written about `knowledge/`. **Two things have to be
settled before the guard is written, and a naive regex gets both wrong.** What
counts: a tilde is not literally absolute, and two of the three sit inside
commands rather than naming repository files, so only the third is plainly the
case the rule is about. And citation: **the item was itself refused by `lint`
on first write, for quoting the third violation's path verbatim in the field
describing it.** A rule over prose that cannot tell a cited path from a used one
turns every card documenting a violation into one.

*Retires when:* `lint` scans `knowledge/` prose with the same regex, red against
the case the rule names rather than against every tilde.

**`B-185` an undeclared `*_iri` column is swept by the validator and missed by
the metadata review, in both implementations.** Measured 2026-09-16 on the
metasalmonpy branch: an `*_iri` column hand-added to `tables.csv` is collected by
the review-marker sweep and **not** by `review_metadata()`'s scan, which reaches
schema-declared fields only — because every row it prints has to be a runnable
`set_sdp_*()` call. Scan empty, validator refuses.

**This is B-174's residual, not its sibling**, which is why it is
`blocked_by: [B-174]`: B-174 closes the declared-field case, and this is what is
left over — a field the scan cannot reach **by design** rather than by oversight.
Whoever takes B-174 meets the fork and must not quietly widen the scan through
it; metasalmonpy hit it and pinned the residual in
`test_an_undeclared_iri_column_is_still_missed` rather than closing it. Closing
it means printing a call that cannot be run, or letting a setter write an
undeclared field — a decision about the printed-call contract, which is why the
item is `needs_brett` rather than claimable. Both languages are identical here,
so it is a port and not a `parity-deviations.md` row.

**`B-186` `lint` accepts any `stream` value, so a padded `S05` omits an item
from its own stream view.** Measured 2026-09-16: `lint` lists `stream` among the
known keys and validates only that it is **present**, never what it holds. Five
items were filed with `S01` and `S05`, `lint` reported `OK` on all five, and the
queue's convention is unpadded — `S6`×18, `S5`×14, `S10`×12, down to `S8`×1 —
with the `items:` block filter matching the string exactly. So a padded value
silently omits the item from its own stream view while every check passes.

Same shape as `B-173` and the third of that family in one day: a field wrong in
a way no check can see, whose only symptom is an absence somebody has to notice.
**Found by Codex review, not by the queue** — the five bad values were written,
linted clean, and would have merged.

*Retires when:* `lint` refuses a `stream` value naming no `S-` item, red against
a padded `S05`. Enumerate from the `S-` item files rather than a hard-coded
list, which would be a fourth copy of a fact `queue/items/` already holds.

**`B-187` `hub` reads the queue from whatever checkout it is run in, and says an
item does not exist when the tree is stale.** Found 2026-09-16 by dispatching
four agents at a checkout nobody had noticed was **67 commits behind**: a session
branch at the tip `origin/main` had when the night began, carrying a
`scripts/hub` 19 lines old and a `queue/items/` missing everything filed since.
`HUB.md` and the dispatch brief both send agents there for read-only commands,
so four claim commands went to it and **for two the item file did not exist in
that tree at all**.

**The defect is the message, not the refusal.** `hub claim B-165` answers *"no
such queue item"* for an item that does exist: true about the working tree, false
about the queue, and an agent that believes it reports the item missing rather
than the checkout stale. `list` is worse, because it **succeeds** — it renders a
stale queue with nothing saying so.

Two things the item records that are easy to get wrong. Sending agents to a
worktree off `origin/main` is **already** the rule (`HUB.md` § *Isolation*) and
one of the four did exactly that unprompted, so the gap is not the instruction;
it is that the client cannot tell a reader when the tree it read is not the
queue. And **the fix cannot live only in the client**: a checkout stale enough to
show the defect has a `scripts/hub` too old to contain the check, so a
client-side comparison protects only checkouts that already have it. Closing the
observed bootstrap failure needs something independently current — a dispatch-time
check, or a refresh enforced before the checkout-local client is invoked.

*Retires when:* an invocation against a stale tree names staleness, the distance
and the branch rather than reporting absence — demonstrated RED from a checkout
that predates the fix, which is the case that matters.
### The 2026-09-16 review-coverage asymmetry

**`B-190` Codex runs a security review on every metasalmon pull request and none
on any metasalmonpy one.** Measured 2026-09-16 over every pull request either
repository has had under Codex, by counting Security Review rows in the review
summary comment:

```
metasalmon     #121 #126 #127 #128 #129 #130 #131   ->  7 of 7 have one
metasalmonpy   #28  #29  #30                        ->  0 of 3 have one
```

It is a per-repository Codex setting; nothing in either tree selects it.

**The mirror contract is what turns a settings difference into a defect.** The
same behaviour lands in both repositories by design, so a class of defect caught
on the R side is a class *not looked for* on the Python side — and the asymmetry
is invisible from inside either pull request, because a Python review that found
nothing reads exactly like an R review that found nothing.

**Measured consequence, the same night.** metasalmon pull request 121's
**security** review raised the symlinked-output finding at
`R/semantic-closure.R:642`, which its code review had reached only in part: the
security review named `metadata/eml-mapping.yml`, which the code review missed
entirely; it covered linked roots and intermediate components rather than final
entries alone; and it forced the hard-link question to be answered explicitly
rather than left implied. **`B-165` ports that exact producer into
metasalmonpy**, so the Python half of a fix that a security review found will not
get a security review.

*Retires when:* Brett enables the security review for metasalmonpy and a later
metasalmonpy pull request shows a Security Review row — **or** records the
decision not to, with its reason, in `knowledge/questions.md`, at which point the
mirror contract should say that review coverage is deliberately asymmetric, so
nobody reads a clean Python review as the same assurance an R one gives.
### The 2026-09-16 closure-port findings

**Four findings the B-165 run named and deliberately did not absorb**, filed as
`B-191` to `B-194`. Two are shared residuals present identically in both
implementations, one is the source of a defect already fixed in the mirror, and
one is a coordinating-system defect that three separate agents worked around in
a single night without knowing about each other.

**`B-191` the metasalmonpy suite only collects when its checkout directory is
named `metasalmonpy`.** Measured on clean `main` under pytest 8: **908
collection errors against 907 passes**, flipping on the directory name alone.

**The hub protocol guarantees the breaking name.** `HUB.md` keys an agent
worktree as `<owner>-<repo>-<item>`, so every metasalmonpy worktree is named
`salmon-data-mobilization-metasalmonpy-B-nnn` — and none of them collects.
**B-124, B-125 and B-165 each nested a second directory named `metasalmonpy`
inside their worktree to get a suite to run, none knowing the others had.** A
workaround rediscovered three times in one night is a defect with an interest
rate.

**CI is green only by coincidence**, because `actions/checkout` happens to check
out into a directory named for the repository, so nothing in the pipeline will
ever report this.

*Not reproduced independently:* this container has no pandas, so the import fails
before collection is reached. The 908/907 figures are the B-165 run's
measurement. The fix is the import route in metasalmonpy, and nowhere else.
*(Corrected 2026-09-23. This sentence offered the worktree key in `HUB.md` as an
equally good fix until then, a week after the item's own condition had ruled it
out: renaming the key leaves a checkout at any other path failing, and `HUB.md`
is outside the item's repository and Brett's under class 7. The reasoning is
under* The 2026-09-16 review-and-bookkeeping round *below; the item file was
corrected on the day and this paragraph was not.)*

**`B-192` the publication vignette's description of the review-target set makes a
reader break their own package.** `vignettes/post-review-package-publication.Rmd`
calls it the measurement set *"plus each table's `observation_unit_iri`"*. Both
halves measured 2026-09-16: neither implementation's canonical-review-target
builder references the used-procedure resolver at all — **zero occurrences** of
`used_procedures` in `.ms_eml_canonical_review_targets()` or Python's
`_canonical_review_targets`, while the canonical *measurement* set does call it —
and the ledger reader enforces an **exact** set, collecting any key outside the
canonical targets as `unexpected` and refusing the ledger.

So the sentence does not describe a redundant row. A reader who follows it adds a
target for a code-resolved procedure and **their package stops validating**,
which is the opposite of what the vignette is for. Both directions need saying:
an `observation_unit_iri` is a review target and not a vocabulary term; a
code-resolved `sosa:usedProcedure` is a vocabulary term and not a review target,
because it comes from the data rather than from a metadata field.

**The Python twin is already fixed**, in metasalmonpy pull request 31 — whose
prose was transcribed *from* this vignette. So this is the **source** of that
defect rather than its mirror, which is the unusual direction and the reason it
is filed against metasalmon.

**`B-193` both sidecar spellings present: the writer refuses, the producers
proceed.** `write_eml_from_sdp()` aborts when a package carries both
`eml-mapping.yml` and `eml-mapping.yaml` — the conflict its default-path helper
exists to detect — while the closure producer hard-codes the `.yml` path instead
of routing through that helper, and writes happily to the file the writer would
have refused the package over. Measured identical on both sides, with
byte-identical producer output, so the two implementations agree; what they agree
on is answering one question two ways inside one package.

**Brett's, and that is why it was filed rather than fixed.** Making the Python
producer raise where the R producer does not would be a deliberate divergence
requiring a `parity-deviations.md` row, and a port may not open one. The B-165
agent measured it, declined, and filed it. *Recommended shape:* one cross-repo
change routing **both** producers through the shared helper, so the conflict is
detected once and in one place.

**`B-194` a sidecar declaring one output path twice silently loses a file.**
Present and identical in both implementations, so a shared residual rather than a
divergence. Low severity — a sidecar is hand-edited and the duplicate has to be
written deliberately — but the failure is **silent**: the second write wins, the
first output is simply absent, and the digests recorded in the sidecar are
consistent with the file that survived, so nothing downstream reports anything.

---


---


---


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

### The 2026-09-16 review-and-bookkeeping round

**One Codex review found the same defect twice, and the audit it prompted found
five items sitting in `ready` with their work already delivered.** The review is
of metasalmon pull request 134 and arrived five and a half minutes before that
pull request was merged, which is its own lesson and is filed as `B-196`.

**Two items were claimable and unfinishable at once.** `B-191`'s retirement
condition ended by offering the `HUB.md` worktree key as an equally good
alternative to fixing metasalmonpy's import route. It is neither: renaming the
key makes hub-created checkouts collect while leaving the suite dependent on its
directory name, so the opening clause — a checkout at *any* path collects and
passes — stays false, and the item would retire with its own condition unmet.
And `HUB.md` is in metasalmon while that item's `repo` is metasalmonpy, so the
alternative was outside the claim's scope and reserved to Brett besides.
`B-194` required "a test in each implementation" and told the claimant to fix
both sides in one change while naming metasalmon in `repo`. Split into `B-194`
(metasalmon) and `B-195` (metasalmonpy), which is the convention the ecosystem
already follows for `B-111`/`B-179`, `B-115`/`B-145` and `B-112`/`B-144`.

**The generalisation was measured unmechanizable, and that is the useful part.**
Matching member repository names in `retires_when` across claimable items flagged
**29 of about 80**, nearly all legitimately naming another repository as evidence
or as a mirror pointer. Narrowing to a both-sides requirement phrase with no
mirror id named flagged **four, and passed both items the rule was written to
catch** — `B-191` and `B-194` each name related ids for unrelated reasons. A
guard whose real scope is narrower than its claimed scope is what `AGENTS.md`
calls worse than a missing guard, so no rule was added and the check lives in
`queue/README.md` as a filing rule instead.

**`B-196` a green check run measures the base as it stood at the last push.**
All three checks were green on pull request 118's head `b38e824`, and merging it
would have turned `main` red: `B-140`'s `validate_workpads()` rule landed in pull
request 127 afterwards, and 118's head still carries the `.hub/workpad.md` that
rule forbids. `HUB.md`'s delegated conditions already name two ways a check
reading goes wrong — inferred from a local run, and no checks at all, which is
the shape a merge conflict takes — and this is a third that neither covers,
because the checks exist, were read off GitHub, and are green.

**Five items were in `ready` with their work delivered.** `B-0`, `B-143` and
`B-150` moved to `review`; `B-44` moved to `needs_brett`, for the reason in the
next paragraph; and `B-115` went to **`done`**, because pull request 118 merged
while this branch was open. It was written here as `review` and was wrong within
the hour — the shortest a wrong state has lasted in this queue, and only because
that merge happened to be watched. None of the others had landed: `B-143` is
salmon-domain-ontology pull request
30, a draft whose own body says not to merge it before `B-107`; `B-0`, `B-44` and
`B-150` are patches to a shared repository that correctly were never pushed.

**`B-44` was the live hazard, and the lock is what failed.** Its claim ref tip is
a `beat` with no `branch` field and no `handoff`, so the lease and the reclaim
grace both elapsed and claimability test 4 passed. `./scripts/hub ready` listed
it as the only available item, at **P1**, which is the lowest severity number and
therefore what step 2's selection rule picks first — pointing the next agent at a
103 KB patch with a four-gate self-test that already exists. The item's `state`
field was the only thing protecting it, which is the reverse of the design: the
lock is meant to be the atomic protection and the state the readable copy of it.

**It went to `needs_brett` rather than `review`, and the first answer was
wrong.** `review` was the obvious move and a Codex review of pull request 135
caught what it claimed: `review` means the hand-back protocol completed, and for
`B-44` it did not. The handoff could not simply be appended either — `hub done`
refuses a claim held by another agent (`scripts/hub:1782-1785`), and forging that
agent's token on the claim ref is the only way past it. `needs_brett` is also the
honest state on the merits twice over: the deliverable is a patch to a **shared**
repository, so landing it needs the push credential Brett holds, and the restored
`duplicate_label` check is red on `main` because `gcdfo:WildSalmonPolicy` and
`gcdfo:WildSalmonPolicyTheme` share an `rdfs:label`, which is the term decision
filed as `B-136`. The claim ref is still inconsistent and wants a `hub reconcile`
expiry release or a hand repair.

**Three finished hand-backs existed only in places that die with the container.**
`B-0`, `B-44` and `B-150` — **161 KB** of verified work with recorded
demonstrations — lived in unpushed worktree branches and a session scratchpad.
The claim ref proved the work existed and could not produce a line of it. Now
exported to `.hub/handbacks/<id>.patch` as `git format-patch` output, which
`.Rbuildignore` keeps out of the tarball. The remaining question is Brett's: a
patch to a shared member repository has no durable home that is not this
repository.

### The 2026-09-16 network-guard finding, and the changelog window

**`B-197`: one test makes a live call it does not need, so a DataONE outage reds
every `check` run that executes while it lasts, whatever the diff.**
Measured on pull request 137, whose entire diff was one queue item and one
backlog section — both excluded by `.Rbuildignore` and reachable by no test.
`check` went red with `Error accessing https://cn.dataone.org/cn: Server error:
(503) Service Unavailable`, from `dataone::CNode("PROD")` at
`test-knb-publication.R:1129`.

**Ruled out as the pull request's three ways**, which is the part worth copying:
the diff touches nothing R runs; `check` was green on the base commit `a592c23`;
and **a re-run of the identical commit went green** minutes later — same code,
same sha, different third party. That third check is what turns a plausible story
into a demonstration, and it is the one re-run the drive-to-green rule allows for
exactly this case.

The missing guard is specific. The test calls `skip_if_not_installed("dataone")`,
which checks that the **package** is present and never that the **service** is
reachable, and no test in that file calls `skip_if_offline()`. `B-132` is the
same shape for the live SDP bundle fetch, which is why `B-197`'s retirement
condition requires sweeping the file rather than fixing the one instance that
happened to fire.

**The remedy is to remove the call, not to skip on it, and the first version of
this item had that backwards.** It asked for a skip — which, under an outage,
throws away the assertion that both nodes are checked. `AGENTS.md` warns that a
green *offline* run is not full coverage, so a skip *reduces* coverage exactly
where removing the call would keep it. And the call is removable, because it is
not load-bearing: the test already builds `member_node` locally with
`methods::new("MNode")` and an `@identifier`,
`.ms_knb_lookup_node_system_metadata()` is mocked, and `coordinating_node` is
used for precisely two things — the `cn` slot of the `D1Client` and
`coordinating_node@identifier` in the closing `expect_identical` — so a `CNode`
built the same local way serves both. `skip_if_offline()` is for the tests where
the live service genuinely *is* the thing under test — **and even there it is
not enough on its own**, which `B-132`'s card already measured: it proves the
host *resolves*, not that the request completes, and the outage that produced
this item was a 503 from a host that resolved. Those tests need a
**skip-on-outage** guard, and the word matters: attempt the request, skip on a
transport error, a 5xx or a named throttling status, and **fail on everything
else**. A 400, 401, 403 or 404 is this package regressing, not DataONE being
down, and a guard that skips those is how an outage workaround quietly becomes
a way to not notice defects. The status goes in the skip message, which makes
the skip legible without preserving the assertion — which is exactly why the
4xx side fails instead.

**The blast radius is narrower than this section first claimed, and the
correction matters because the claim is what prioritises the item.**
`.github/workflows/R-CMD-check.yaml:3-7` triggers on `pull_request` and on `push`
to `main`, with **no `schedule`** — so nothing re-runs a completed check, and
already-green checks stay green. What is true is that every `check` that
*executes* during the outage fails regardless of its diff: every new pull
request, every push to an open one, every re-run. On a busy merge day that still
reaches most of them, and the diff-independence is what makes it expensive —
each failure looks like its author's fault until somebody reads the log.

**FIXED 2026-09-16**, merged as `2313848` in pull request #140 (from branch
`agent/B-197/a-d592f9a0947ebb37`).
`dataone::CNode("PROD")` is gone; the node is built with `methods::new("CNode")`
and a locally set `@identifier`, the way the test already builds `member_node`
two lines above. Checked rather than assumed to be safe:
`.ms_knb_lookup_pid_default()` passes `client@cn` straight into the mocked
`.ms_knb_lookup_node_system_metadata()`, so `@identifier` is the only slot
anything reads, and the closing assertion compares against
`coordinating_node@identifier` rather than a repeated literal — so the test
still pins what it always pinned, that the lookup visits the client's `mn` and
then its `cn`.

**Both clauses fall out of one measurement**, with every proxy variable pointed
at a dead local port and the block proved first by a probe that reports
`Couldn't connect to server [cn.dataone.org]`. `dataone::CNode("PROD")` errors
under that block and the replacement builds offline — the RED and the GREEN for
the removed line. Then the whole file runs with **zero failures and exactly one
skip**, the collation-locale one, which is the same single skip the online run
produces. A test that *passes* rather than skips is clause 1; a file with no
other network skip is clause 2. The file is clean.

**The sweep does not extend past that file, and three findings from trying are
filed against the items that own them** — `B-132` confirmed at
`test-schema-helpers.R:172`, `B-152` given two more measured instances — its file holds
**four** defective tests carrying **three different wrong guards**, none of them
a missing one — and `B-137` confirmed as six failures on a `C` locale. The B-197 workpad carries them; they are named rather than absorbed
because this claim covers one branch and those tests belong to other items.

**One of those findings is worth reading even if the others are not, because it
is why all four of these were cheap to miss: a re-run erases the flake it
fixes.** Across 484 `R-CMD-check` runs the API reports 10 that ever finished
failed and **none at all since 2026-09-01** — while four runs carry
`run_attempt > 1`, three of them in the five days to 2026-09-16 (runs 337, 360,
449). A re-run overwrites the run's conclusion, so a flake that was re-run into
green is indistinguishable from a run that never failed. It is worse than
invisible at the log layer: `get_job_logs(failed_only)` reads the *latest*
attempt and answers "no failed jobs" for a run whose first attempt died, and
attempt 1's log is reachable only by following the API's redirect to blob
storage with the `Authorization` header stripped, or it 401s. So the honest
reading of "no failed checks this month" is **not** that nothing failed; it is
that nothing failed *and stayed failed*, which is a different and much weaker
claim. It had no queue item until the 2026-09-23 sweep filed it as `B-229`, and
it is not one of `B-132`/`B-152`/`B-155`/`B-197` — it is the measurement layer
under all of them.

**A changelog entry written between a version bump and its tag has no home, and
that gap produced two instances in one day.** `AGENTS.md`'s *Releases* section
says to tag the commit that made the version current, not a later docs-only
merge. It says nothing about where a CHANGELOG entry goes for work that merges
*after* the bump and *before* the tag — and metasalmonpy sat in exactly that
window all day, at `0.5.0` in-tree with `v0.4.0` still its newest tag.

The two instances were resolved in **opposite directions**, and only one of them
was right:

- **B-124** (metasalmonpy #29) merged after the bump and its entry went under a
  **restored `## Unreleased`**, above `## 0.5.0`, mirroring `NEWS.md`'s
  *(development version)* heading here. That heading's own preamble gives the
  reason: filing it under `## 0.5.0` "would make this file say a version
  contains a change that the commit making the version current does not."
- **B-144** (metasalmonpy #32) merged in the same window and its entry went
  **under `## 0.5.0`** — the placement B-124's resolution avoided, and by
  B-124's own stated reason simply misplaced.

**An earlier revision of this section had that backwards, and recording the
correction is the point.** It reasoned *from* B-144's placement *to* the tag:
since `## 0.5.0` now claimed a fix the bump commit does not contain, `main` had
to be the commit to tag. That inverts the two. `AGENTS.md`'s *Releases* section
names the tag target — *"Tag the commit that made the version current"* — and
the changelog is the mutable thing, so letting a misplaced entry choose the tag
lets the mutable copy overrule the rule. It is wrong on scope as well:
`roadmap.md:497` says of the list that names **B-144** at `:468` that "**these
are *not* part of the `0.4.0→0.5.0` window**", so B-144 is post-`0.5.0` work
whose entry does not belong under `## 0.5.0` at all, and tagging `main` to
accommodate it would bake a next-window port into the release.

**So the tag belongs on the bump.** `19f467b` set the version to `0.5.0` and
reached `main` as merge `67fb486`; `b939fd9` (B-144) and `1e9245c` (B-124) are
both later. Moving B-144's entry to `## Unreleased` is the owed follow-up and is
deliberately **not** done here — a different repository, a different pull
request, and it touches a release act Brett owns.

**The gap itself stands, and is why this section exists.** `AGENTS.md` says
nothing about where a CHANGELOG entry goes for work that merges after a bump and
before its tag, and two agents read that silence in opposite directions inside
one day. The durable fix is a sentence in the *Releases* section naming where an
entry goes inside that window, plus something that checks it; that is a
specification change and Brett's, which is why it is recorded here rather than
patched into `AGENTS.md`.

*(**Resolved the same day, and this paragraph is left standing as the record of
what was known when it was written.** Brett ruled it on 2026-09-16 — "Regarding
the agents.md change log entry. I will take your recommendation." — so the two
present-tense claims above are now history: the gap no longer stands, because
`AGENTS.md`'s *Releases* section carries the sentence; and moving B-144's entry
is no longer an owed follow-up, because metasalmonpy pull request 35 did it,
merging as `3f8349a`. What remains true is everything this section measured —
the two opposite readings, the commits, and why the tag belongs on the bump.
The next section records the ruling and the two check items it produced.)*

### The 2026-09-16 temporal-profile finding

**The string both implementations are converging on is one the SDP profile
forbids**, filed as `Q-51`. Verified at `inst/extdata/schema/frictionless/metadata/dataset.schema.json`
lines 77–98: `temporal_start` and `temporal_end` each carry
`constraints.pattern` of `^(\d{4}|\d{4}-\d{2}-\d{2})$` — a year or a date, never
an instant — with `sdp:examples` of `1996` / `1996-01-01` and `2024` /
`2024-12-31`. So `0999-06-05T13:45:30Z` fails the profile the package ships, and
so does `2024-12-31T00:00:00Z`.

**It is not a regression, and the distinction is the whole point.** It was true
before `B-115` and `B-145` and it is true after them. Those two items owed one
thing — that `datapackage.json` and `metadata/dataset.csv` spell the same instant
the same way. What they could not deliver is a *legal* string, because the profile
admits no instant at all. The work changes **which** invalid string is written, not
whether one is.

**Nothing here should be read as saying the two sides already agree, and this is
not the place to find out whether they do** — `queue/items/B-145.yaml` owns that,
and a copy of it here would be wrong the moment it moves. What belongs here is the
evidence, which does not: measured 2026-09-16, Python's descriptor emitted
`0999-06-05T13:45:30` with no `Z` while its `metadata/dataset.csv` emitted
`999-06-05 13:45:30` — disagreeing on the separator *and* the year padding, which
is the disagreement `B-145` exists to close.

That does not soften the question, and it does change what is being asked: the
invalidity above is true of both implementations **whether or not `B-145` has
landed**, because no instant was legal either way. *(State at discovery,
2026-09-16 morning: the profile ruling was the open question and the port was
not a precondition for it. It was answered (a) later the same day — recorded
below — so this paragraph describes the position that made the question worth
asking, not a decision still outstanding. It read in the present tense until the
Codex review of pull request 137 on `3414a3a` caught it: a sentence saying a
ruling "is open" in the same section that records the ruling is the
state-in-prose defect wearing a tense rather than a field, and it survived two
earlier rounds of exactly this hunt.)*

**Why it went unseen through two implementations and four reviews.** Every check
either side runs compares the two files against each other, or against the ruled
spelling. Nothing compared the result against the profile's own pattern, so a
divergence was visible and an invalidity was not. That is the same shape as the
`role_boost` and `statistical_modifier` cases in `AGENTS.md`: a layer nobody
thought to look at, where green means only that the layers anyone did look at
agree.

Found by the `B-145` run and deliberately not absorbed — it was a specification
question in `smn-data-pkg`, a third repository. Four options were put to Brett,
not three: **(a)** widen the pattern; **(b1)** refuse — the writer errors, so the
caller is told; **(b2)** coerce — the writer truncates, so the call keeps working
and the time and zone are silently discarded; **(c)** leave it. b1 and b2 were one
option until a Codex review of pull request 137 observed that refusing and
coercing are opposite failure modes, so a ruling of "(b)" would not have been
implementable. `Q-50`, about the Frictionless profile key, is adjacent.

**Ruled (a) on 2026-09-16 and recorded the same day.** `smn-data-pkg` pull
request **#9**, merged as **`f86d9b4`**, widened `constraints.pattern` on both
fields to
`^(\d{4}|\d{4}-\d{2}-\d{2}|\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z)$`, added
`1996-01-01T00:00:00Z` and `2024-12-31T23:59:59Z` to `sdp:examples`, and widened
`validate_temporal_value()`'s calendar layer to match. The ruling and its full
options analysis are indexed in [`questions.md`](questions.md) as `Q51`, now
ANSWERED; that file is the index and `f86d9b4` is the authority.

**Two things the ruling deliberately did not settle.** The first is a
**platform-rendering defect, not a schema limit**: the ruled pattern's `\d{4}`
branch **accepts** the padded `0999-06-05T13:45:30Z`, and what fails it is the
**unpadded** bytes `readr` writes on Linux, `999-06-05T13:45:30Z`, which
`smn-data-pkg`'s own tests pin as rejected under the fixture name *unpadded year*.
So `B-161`, Brett's and unruled, holds **which bytes the ecosystem writes — R and
Python both** (it read *"which bytes R should write"* until 2026-09-16; `B-145` had
measured pandas `to_csv` emitting an unpadded year since 2026-08-25, so the R-only
scope could have produced a ruling that omitted Python) — not
whether the profile admits a pre-1000 instant, which it does. The second is that
no fractional second is admitted, because neither writer emits one.

**The implementation halves are `B-198` (metasalmon) and `B-199` (metasalmonpy)**,
each re-vendoring the ruled schema into its own copy from the smn-data-pkg tag
that `B-236` cuts, which contains `f86d9b4` and is the ref the remote pin names,
so the vendored and remote bundles cannot differ (their queue cards are the
authority on the ref), and adding the test that was actually missing: a
comparison of a written package's temporal fields to the profile's own
pattern, with a four-digit-year fixture. Nothing on
either side does that, which is why this went unseen, so re-vendoring without the
comparison would leave the hole it came through. `B-199` was filed depending on `B-145`, and
the reason is durable whatever the field says later: the instant the Python
descriptor writes is `B-145`'s output, so widening the pattern does not by itself
make it legal. `queue/items/B-199.yaml` carries its blockers. **The general half of the same
gap** — both validators consume `constraints.required` and `constraints.enum` and
never `constraints.pattern`, so a widened pattern is still not *checked* by either
package — is **`B-204`** (metasalmon) and **`B-205`**
(metasalmonpy), filed 2026-09-16 and on `main` since metasalmon pull request 139.
**The boundary:** this pair pins what the *writer* emits against the vendored
pattern; that pair makes the *validator read* `constraints.pattern` at all.
**They are not order-free, and this section said they were.** Schema-then-validator
is harmless; **validator-then-schema is a regression**, because `B-204`/`B-205`
would enforce the pre-ruling pattern still sitting in the vendored copy against
a descriptor `B-115` already taught to write instants. The ordering belongs in a
field rather than a sentence, so those two cards carry their own blockers and
this section does not restate them; `knowledge/questions.md` carries the
reasoning under Q-51, including the correction that the first version of this
paragraph copied the field it was arguing against copying.

### The 2026-09-16 rulings round

**Two messages in chat carrying three rulings, six new items, one promotion,
and one modelling call recorded as made without the promotion it does not
authorize.** The three are `B-197`'s, the `B-158`/`Q-48` modelling call, and the
changelog-window rule; a fourth sentence in those messages rules Q-51 and a
fifth authorizes the smn #27 merge, and both are recorded elsewhere for the
reasons given below. Brett ruled on 2026-09-16, in two messages: *"[…] Regarding
B197, promote it. Regarding the agents.md change log entry. I will take your
recommendation."* and *"Regarding SMN number 27. Let's commit to what we already
decided. So yeah, you can merge it. Regarding B158 and Q48, let's stub the OBO
and GeoSparkle [GeoSPARQL] terms. And vendor DWC."* This section records what
those two messages changed in this repository. The elided first sentence of the
first message is Q-51's ruling, deliberately **not** recorded here: `Q-51`'s card
is being written on pull request 137 (open when this was written, 2026-09-16),
that pull request is the record of the ruling, and a record that gets ahead of
the card it describes is the defect `queue/README.md` names. The smn pull
request 27 half is a merge to be carried out in that repository, authorized by
that ruling (*"you can merge it"*); when this was written on 2026-09-16 it was
still open, a draft at `949ed95` on `d45f8f7`, and it is not recorded here
either way.

**`B-197` was promoted; `B-158` was not, and the difference is the point.**
The promotion commit names the sentence it rests on, as `HUB.md`'s promotion row
requires — and the two sentences differ in kind. *"Regarding B197, promote it"*
is a promotion instruction. *"Let's stub … and vendor DWC"* rules a modelling
call and says nothing about promotion, so reading it as a go-ahead would be an
agent's inference standing where `HUB.md` requires an authorization — and **this
round did not promote it on that reading**. Whether it has been promoted since
is `queue/items/B-158.yaml`'s to say and this section's to stay quiet about.
Nothing was lost by not promoting it here: on 2026-09-16 it carried
`blocked_by: [B-107, B-143]`, and neither of those was `done`, so a promotion
would have bought no claimable work that day. **What the ruling
did settle is recorded on the card**: the modelling call it had said only Brett
could make is now made — the six `obo:`/`geosparql:` superclass IRIs get
bare declaration stubs under `CONVENTIONS.md` 5b rule 2, and the two `dwc:`
IRIs (`dwc:Event`,
`dwc:Organism`) are vendored into `ontology/imports/`. **The trade-off the ruling
settled is the justification, and "the validator accepts it" is not** — the gate
accepts either. A stub is nearly free and permitted anywhere, but a reasoner
learns nothing from a stub, so it fits an IRI smn uses structurally — a
superclass hook, a MIREOT mirror — where the foreign axioms are not what smn
relies on. Vendoring carries weight, a pin and a licence question per source, so
it is reserved for the one namespace whose semantics smn actually relies on:
`dwc:` carries `smn:Deme`, `smn:Population` and `smn:SurveyEvent`. The ruling
settles the vendor-or-stub half of the decision surface `B-158`'s card joined
to `Q-48`; the taxonomic-assignment pattern bundle itself is still Q-48's, and
`knowledge/questions.md` still owes it an entry. `B-107` was not promoted: its
card carries its own promotion condition, which had not been met when this was
written (2026-09-16). `B-158` gained `blocked_by: [B-107, B-143]` on 2026-09-16, whatever
its state: `B-107` because both edit
`ontology/modules/02-observation-measurement.ttl`, and `B-143` because the gate
its condition names exists only on salmon-domain-ontology pull request 30's
branch — an item whose end condition needs a script `main` does not carry would
be claimable and unfinishable at once the moment it were promoted, and
`blocked_by` is what keeps `hub ready` from offering it. Nothing in `HUB.md` serialises claims within a
repository (`solo` is a participation fact, and the only concurrency cap is
per agent), so the order is carried by `blocked_by` and the S6 card, not by any
rule. The third ruling, where a changelog entry goes between a bump and its
tag, is now a sentence in `AGENTS.md`'s *Releases* section; *The 2026-09-16
network-guard finding, and the changelog window* is its evidence, and
`B-200`/`B-201` are its mechanical form.

**`B-200`: nothing checks that a `NEWS.md` entry under a released heading was in
the tree the tag names.** The rule is now written — a change merged after the
bump commit and before the tag files under *(development version)*, never under
the version it did not ship in, tag on the bump — and *The 2026-09-16
network-guard finding, and the changelog window* shows two agents reading its
absence in opposite directions inside one day. A rule that
lives only in prose is the thing `HUB.md` keeps relearning about, so this item is
the check: a script under `scripts/` (a `check-changelog-window.py` beside
`check-parity-registers.py`), run from continuous integration on every pull
request and named as the pre-tag step in *Releases*. For each released heading
whose bump commit `main` carries — the `vX.Y.Z` tag when it exists, otherwise the
first commit on `main` whose `DESCRIPTION` reads that `Version` — every line
beneath the heading that is absent from the same section at the bump commit is a
finding unless the commit that added it is an ancestor of the bump
(`git merge-base --is-ancestor`). **One exemption, and it is measured rather
than assumed:** a marked, dated correction to a shipped entry — a
*(Correction, YYYY-MM-DD: …)* paragraph appended to an entry, or a
*[corrected YYYY-MM-DD: …]* bracket inserted into one — is not a finding,
because the *Releases* rule admits exactly that, and because `main` does not
pass without it. At `e9d7dc4`, `git diff -U0 v0.4.0 origin/main -- NEWS.md` has
three hunks under the 0.4.0 heading, every one a correction dated 2026-08-24 and
none from an ancestor of `v0.4.0` (`4e2bbb6`): lines 1024–1027 and 1206–1210
from `09099538` (*"docs: correct two claims about metasalmonpy in the 0.4.0
notes"*, 40 minutes after the tag) and lines 1162–1163 from `5a90a7f1`. A check
written without the exemption arrives red on `main`, and `B-143`'s card says
what that produces: a first reader who weakens it. So the RED demonstration
also shows that an unmarked paragraph under a released heading is still a
finding, which is what makes the exemption a marker and not a hole. A line
changed in place is likewise not a finding, so a typo fix to a shipped entry
stays possible, and the script's docstring says so as the scope it does not
cover — along with the two things reading catches and the check cannot: a
paragraph carrying the marker but describing new work, and a rewrite that turns
a shipped bullet into one. **RED demonstration:** a fixture repository the test
builds — a bump commit setting `Version`, then a commit adding a bullet under
that version's heading — turns the check red, and the same bullet under the
development heading turns it green. The B-144 instance
replayed against a metasalmonpy checkout at `1e9245c` (`CHANGELOG.md` lines
257–297 under `## 0.5.0`, added by `b939fd9`, which is not an ancestor of
`67fb486`) is the real-history confirmation, reached the way
`check-parity-registers.py` reaches its twin, and is not part of the retirement
condition, because a condition satisfiable only with a sibling checkout is the
shape `queue/README.md` forbids. **P3:** the failure corrupts no data and no
behaviour, and the window is bounded — bump to tag — but the release record is
what the mirror contract's parity claim is read from, one real instance occurred
within a minute of the window opening — `67fb486` at 12:55:23Z, `b939fd9` at
12:55:44Z — and it is silent until somebody diffs a tag
against its changelog.

**`B-201`: the metasalmonpy half.** The same sentence in metasalmonpy's
`AGENTS.md` *Releases* section (line 155 at `1e9245c`), and the same check over
`CHANGELOG.md` with the bump commit read from `pyproject.toml`'s `version`. **Its
RED demonstration is its own history**, which is why the pair is filed rather than
folded: at `1e9245c`, `CHANGELOG.md` lines 257–297 sit under `## 0.5.0` and were
added by `b939fd9`, the merge of #32, which is a descendant of the bump merge
`67fb486` (`git merge-base --is-ancestor 67fb486 b939fd9` holds) and therefore
not an ancestor of it; `1e9245c` (#29, B-124) is later still and went under
`## Unreleased` correctly, so the check has one finding and not two. metasalmonpy
pull request 35 (merged 2026-09-16 as `3f8349a`, 15:47Z) moved the entry,
verbatim: the RED is run at a checkout of `1e9245c`, and the check is green on
`main` from `3f8349a` on, where `git diff 67fb486 origin/main -- CHANGELOG.md`
has a single hunk above the `## 0.5.0` heading at line 97, so the 0.5.0 section
matches the bump merge. The `v0.5.0` tag went on `67fb486` on 2026-09-24.
**P3**, as B-200.

**`B-202`: a port item can reach `done` while the register still says the port
is owed, and it did five times in one day — the fifth on this pull request's own
branch.** The dated record, from the queue's
own history. `B-115` was written `review` on pull request 135's branch
(`85eccc5`, 04:51Z); metasalmon #118 merged while that branch was open; it was
corrected to `done` on the same branch (`690d53c`) before the branch merged.
`B-144`'s `review`, pushed directly to `main` in `5a86fd6` (05:14Z, *"handed
off, metasalmonpy #32 open"*), was true until #32 merged as `b939fd9` at 12:55Z;
`a592c23` corrected it at 13:08Z. `B-153`: pull request 136's branch
first wrote `review` (*"B-153 moves to state review"*, preserved in `a592c23`'s
squashed message), #33 merged as `67fb486` at 12:55Z before the branch did at
13:08Z, and the merged result reads `done`. And `B-124` was set `done` on pull
request 138's branch while `knowledge/parity-deviations.md:190` still read
*"Queued as B-124, blocked by B-49"* and `knowledge/roadmap.md:466` still listed
validation without the landed marker its neighbours carried; a Codex review of
#138 caught it, and `e9d7dc4`'s message records it as the fourth time a sentence
about owed work outlived the work. **`B-165` is the fifth, and it was live on
`main` while this very item was being drafted**: metasalmonpy #31 merged at
04:18Z (`999fa19`), the card was set `done` at 04:21Z, and
`parity-deviations.md` went on reading *"Queued as B-165, blocked by B-116"*
with `roadmap.md` reading *"queued as B-165"* until the branch carrying this
section wrote the closure paragraph and the landed marker. The adversarial
review of that branch found it. An item about stale port records whose own
branch carried a live stale port record is not an irony worth enjoying; it is
the measurement that settles whether prose can hold this. **The register's own rule was written at the
third and broken at the fourth by an agent who had read it** — *"a catch-up
window changes in both places in the same change"*, stated under B-125's closure
(`parity-deviations.md:237-238`) and restated under B-124's (`:211-212`). That is
the evidence that prose cannot hold this: a written state is a claim about a tree
that moves. The item is a rule in `scripts/hub_queue.py lint`, which already
reads the queue — or in `scripts/check-parity-registers.py` if it learns to —
that fails when an id named in the register's port section or the roadmap's
mirror-debt passage is `done` without a closure paragraph and a landed marker, or
not `done` with either. **RED demonstration**, two of them, because one is a replay and
one is real: the queue as it stands against the register and roadmap as they
stood at `a592c23` (register line 190, roadmap line 466) must fail, and so must
the queue against those two files as they stood at `e9d7dc4`, where `B-165` was
`done` and both passages read *"queued"*. `main` must pass once this pull
request lands — and it passes only because this pull request closes that fifth
instance, which is the distinction between a check that arrives green and one
that arrives green *honestly*. The rule reads only ids named **as owed ports**,
not ids named as blockers or as R halves (six of those are `done` and owed no
closure paragraph), and looks for the bold *"landed … as metasalmonpy #N"* form
rather than the bare word. Like
`check-parity-registers.py`, it catches the shape and not the substance — whether
a closure paragraph is true is still a reading. **P2:** the register is one of the
three copies of the single fact the mirror contract turns on, a stale "owed"
sends the next agent to port work that has landed or to claim a window is open,
and five instances in a day with the rule written down at the third is the
argument that the fix is mechanical or nothing.

**`B-203`: `HUB.md`'s worktree-removal check is silently wrong in a
single-branch clone.** `HUB.md:711-716` requires
`git -C "$WT" log HEAD --not --remotes --oneline` to print nothing before a
worktree is removed. `--remotes` walks the local `refs/remotes/` namespace, and
`git push` updates a remote-tracking ref only where a configured fetch refspec
maps it — so a clone whose `remote.origin.fetch` is
`+refs/heads/main:refs/remotes/origin/main`, which is what `--single-branch`
writes and what the metasalmonpy checkout used by the hub in this environment
carries, never gets `refs/remotes/origin/<branch>` for anything but `main`, and
the check reports a fully pushed branch as entirely unpushed, on every branch but
`main`, with no signal that it is wrong. **Measured 2026-09-16, twice.** In situ:
`agent/B-145/a-cbde7679ed732a03` sits on the remote at `7b41e59`, identical to
the local tip (`git ls-remote --heads origin` says so), and the walk prints all
six of its commits; the agent working there got past it with
`git fetch origin <branch>:refs/remotes/origin/<branch>`, a workaround and not a
fix. In a scratch repository built for the purpose: a `--single-branch` clone, an
empty commit on a new branch, `git push -u origin feature` succeeding and
`ls-remote` confirming it, the walk printing that commit, and the workaround
fetch clearing it. **It fails safe, which is why it is P3 and why it is an item
at all:** the worktree is kept rather than lost, but the check sits in the policy
file every agent reads, it is wrong for a whole class of clone, and the
workaround is one every agent rediscovers alone. `scripts/hub` does not carry the
walk (no `--remotes` under `scripts/` on 2026-09-16), so the edit is to
`HUB.md`, which is Brett's to merge under class 7; the item is claimable because
the edit and its demonstration can be prepared unattended. **Retire on:** the
check verifies against `git ls-remote --heads origin <branch>` — the sha on the
remote, not the local remote-tracking ref — or the client normalizes the fetch
refspec before the walk, with a RED demonstration on a single-branch clone. This
is the third defect in that one paragraph in two days: the stash clause and the
`--branches` walk were removed on 2026-09-16, and the paragraph already warns
that a fix removing one instance is not a fix for the defect. This is the
instance it did not see.

**Reported three more times on 2026-09-25, once by a second route.** Three
metasalmonpy runs reported it to the orchestrator and did not write it into
their workpads, so what follows is the orchestrator's record of those reports,
not a measurement taken here. The B-222 run (metasalmonpy pull request 48) and
the B-227 run (pull request 50) each found `git log HEAD --not --remotes`
listing pushed commits as unpushed in a single-branch clone, which is the case
above. The B-212 run (pull request 49) met the same false report another way: in
the shared metasalmonpy clone, another session's fetch pruned the
remote-tracking ref of a branch this run had pushed, and the walk listed that
branch's commits until a re-fetch restored the ref. How the ref came to be
pruned was not established. Read by the 2026-09-25 queue sweep: that clone's
`remote.origin.fetch` is still `+refs/heads/main:refs/remotes/origin/main`, and
every metasalmonpy worktree shares the setting. Whichever fix lands should be
checked against the second route as well as the first.

**`B-204` and `B-205`: both validators ignore the vendored schema's
`constraints.pattern`.** Measured 2026-09-16, at `e9d7dc4` here and `1e9245c`
there. R: `.ms_field_from_frictionless()` (`R/schema-helpers.R:387`) reads
`constraints$required` at `:389` and `constraints$enum` at `:401-402` and nothing
else off `constraints`; the only other `constraints` reader under `R/`,
`R/package-helpers.R:1539-1540`, reads `required` too; a grep for
`constraints$pattern` or `[["pattern"]]` finds no consumer under `R/`. Python:
`package_io.py:1313-1314` reads `constraints["required"]` and nothing else; the
only other reader, `sdp_schema.py:595-596`, reads `required` too;
`sdp_field_setters.py:970-973` copies the block whole without reading a key; and
no `.py` file at `1e9245c` reads a `"pattern"` key, single- or double-quoted. The
vendored
`inst/extdata/schema/frictionless/metadata/dataset.schema.json` carries a
`pattern` on `temporal_start` (`:82`) and `temporal_end` (`:94`) — a year or a
date — which is how a typed instant reached the descriptor and passed local
validation while the profile at that time forbade it: the history behind `Q-51`,
whose ruling is not stated here and does not change these items, because
whatever the pattern says, nothing reads it. **The specification's own validator
enforces it:** `smn-data-pkg`'s `scripts/validate_package.py:221-222` at
`bb71c8b` rejects a value `re.fullmatch` fails, and
`tests/test_validate_package.py:73-79` pins it with a partial date (`1996-01`)
and the message *"temporal_start must match pattern"*. So the gap is in the two
implementations, not the spec — one gap in two trees, filed as a pair naming each
other because a claim covers one repository. **P2 on both:** silent conformance
debt. A green `validate_salmon_datapackage()` is read as "conforms to the
profile", and here it does not, for a rule the profile states in the very file
both packages vendor. Each retires when its validator enforces
`constraints.pattern` on metadata fields, with a test that a violating value is
reported and a conforming one is not, and a parity row or port note as the mirror
contract requires.

**`B-204` observed again, by the B-162 run on 2026-09-25**
(`.hub/workpads/B-162.md` on `main`, measured on `main` `372ef07` under R
4.3.3). `validate_salmon_datapackage(require_iris = TRUE)` accepted a package
whose `temporal_start` was each of `999-06-05T13:45:30Z`,
`2024-01-01T00:00:00Z`, `2024-01-02T04:00:00Z` and `999-06-05`. The pattern
vendored at that commit, `^(\d{4}|\d{4}-\d{2}-\d{2})$` on both temporal fields
(read by the 2026-09-25 queue sweep, unchanged on `be7c4e8`), admits none of
them. Each was refused only afterwards, by `write_eml_from_sdp()`'s EML schema
check: *Generated EML 2.2.0 failed schema validation*, on `calendarDate`. The
first three are what the package's own writer makes of a typed `POSIXct`, so the
gap is reachable without editing a file by hand.

### The 2026-09-16 card-hygiene round

**Twenty-nine Codex review rounds on pull request 137, forty-five findings, all
upheld — and the durable output is not the fixes.** The pull request's own
subject was one queue item and one ruling record. What it produced was a
measurement of how card prose decays, made on prose written the same afternoon
by someone who knew it was true when they wrote it. Nine distinct failure shapes
came out of it, and a tenth came out of the pull request that wrote the nine
down: two of them were broken by that diff itself, caught by review and not by
the author. All ten are now `queue/README.md`'s *Ten corollaries, each paid for
once*, each naming what produced it. Counts are from the pull request's review
API rather than the commit log, which undercounts because one commit often
answered two findings.

**The largest single group was one sentence copied six times.** `B-161`'s
condition grew from *rule a spelling* into an invariant, and the sentence saying
the item was *the ruling alone* became an under-statement in the dangerous
direction — a reader of the decision log could treat the ruling as finished
before the conditional re-vendor and pin work existed. Each fix was followed by a
review finding another copy: `knowledge/backlog.md`, then `B-206` and `B-207`,
then `B-204` and `B-205`, then `knowledge/questions.md`, then `B-161`'s own card.

**Two of the nine are about the search rather than the copies, and they are the
new ones.** A sweep keyed to phrasings the author remembered writing finds only
the copies that share that wording. Then the sweep keyed to the item's *id* —
the right key — loaded each file, gated on the string, and **replaced the text
with the `retires_when` field alone before searching**, which discards the `id:`
line; a card calls itself *THIS ITEM* inside its own condition, so the
authoritative copy matched nothing. It printed `=== queue/items/B-161.yaml` as
the first line of its output with no matches under it, while eight other files
returned three to ten each, and the empty section was read as *no copies here*.

**And the account of that miss, written into the card afterwards, was wrong.** It
said a card cannot match its own id. Line 1 of every card is `id: B-161`. The
explanation had been reconstructed from memory rather than read off the command
that ran, and a review caught it with the reason that matters: a wrong recorded
diagnosis makes the next sweep repeat the real failure. Both versions are now in
`B-161`'s card, side by side, because the pair is the finding. **The rule is that
an empty result for one target states the instrument's reach and not the target's
contents, and a post-hoc explanation of a miss is itself a measurement.**

**Two items filed, and their cards are the authority for every field of them.**

`B-209` asks for a check that fails when a tracked prose file restates queue
state. `queue/README.md`'s top rule says such a restatement is a defect; nothing
enforces it but a reader noticing. **The distance between what that rule asserts
and what anything mechanically checks was measured on 2026-09-16, and it is
wider than "only the blocks it covers" suggests: `queue/config.yaml`'s
`generated_blocks` contains exactly one entry — `member-count`, rendered into
`knowledge/roadmap.md`.** One fact in the whole bundle fails the build on
divergence, and it is the ecosystem member count. Nothing about any item's
state, severity, blockers or repository is checked anywhere. The card's first
deliverable is deliberately the *discrimination rule* rather than the checker,
because a check that cannot tell *is blocked on* from *was blocked on until the
split* gets switched off within a week — at which point `AGENTS.md`'s guard rule
applies to it and it is suppressed rather than fixed.

`B-208` records that a frozen SDP profile pins **unversioned** URLs, so only the
profile *file* is frozen and every schema it references is live. `sdp.rules.yaml`
changed twice in the B-106 work; Q-51's widening at `f86d9b4` changed a JSON
schema, which none of the earlier changes had. So a package validated against
v0.2 today is validated against v0.3's rules. Q-51 did not create this and is
only the first change a review happened to notice; it was merged anyway on the
reasoning that the new pattern is a strict *superset* of the old one, so nothing
that validated under v0.2 stops validating — what changes is that a new package
can carry an instant while claiming v0.2, the tolerable direction of drift while
this is decided. The shape of a fix, as a starting point rather than a
prescription: snapshot each frozen profile's schemas under a version-specific
path such as `profiles/salmon-data-package/v0.2/schema/…` and repoint v0.2 at
those, leaving the unversioned paths as the development head. The card is the
authority for its state, and the reason that state is what it is: the fix
changes published URLs that downstream validators are built against, which is
outward-facing spec design rather than an implementation choice.

**`B-161` gained four measurements, because this round found that its two
options are not comparable.** Read out of `smn-data-pkg` at `f86d9b4` rather
than out of a card describing it, the widened pattern is
`^(\d{4}|\d{4}-\d{2}-\d{2}|\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z)$` — the year is
`\d{4}`, exactly four digits — so a padded pre-1000 instant already passes the
profile in force and an unpadded one does not. The profile is not the only layer:
`scripts/validate_package.py`'s `datetime` branch runs
`datetime.fromisoformat()` *after* the pattern, and on Python 3.11.15 that
accepts `0999-06-05T13:45:30Z` and raises on `999-06-05T13:45:30Z`, so the
unpadded outcome needs **two** widenings upstream rather than one — the same trap
Q-51 already hit once. It would also land after `B-198`/`B-199` have vendored the
four-digit pattern, so both get redone, and `B-145` becomes work in the opposite
direction. None of that decides the item, which is Brett's; it is recorded so the
ruling is made against measurements rather than against the card's earlier
framing of two comparable options.

### The 2026-09-16 post-#141 sweep: one fact with two homes, an omitted field, and an exemption misread as a gap

Two subjects, filed as **Q-52** (the ruling) and **B-210** (the omission). They
share a section because they share a lesson, and it is the one #137 and #141
were both about: *every claim here rests on something that stood in for the
source — an instrument that read it, or a file that described it — and each of
those stand-ins was wrong the first time in a way that looked like a clean
answer.* Most were faulty instruments. **One was not an instrument at all**: a
file was read that named another as authoritative, and the authoritative file
was never opened. The instances are enumerated below, each with what it
measured, what it was taken to measure, and who caught it.

That distinction is the one this lede lost when the count came out of it, which
is its own instance of the failure below: rewriting a summary to fix one
mismatch with the list introduced a different one. It reads as a rule now rather
than a tally, and a rule has to be true of every item it covers.

**This paragraph used to carry the count**, and the count was wrong on every
round of this pull request — as was the heading above it, which said the
exemption had been read as a gap *three times*. Both are now claims about kind
rather than number, for the reason the enumeration itself establishes further
down: **a summary is a second copy of what it summarises, and a correction to
the thing summarised does not reach it.** The first version of this paragraph
then over-claimed, in the sentence right after asserting the rule: it said *no
count sits in a sentence whose job is to introduce one*, which was not true of
the section even as it was written — the exemption lede still said *three
times*, and a review found it one round later.

**The accurate rule, which is narrower.** A count appears here only where the
material that verifies it is immediately adjacent, and only where the number is
itself the finding. *"Diverged twice"* stays, because two rather than one is the
correction, and the two-row table is directly beneath it. The reading lede and
the exemption lede carry no counts, because there the number only characterised
a list and a reader gained nothing from it that the list did not already say.

**Severity has two homes, they are differently shaped, and they have diverged
twice.** Six readings, each taken from the file named:

| What | Where | What it says |
| --- | --- | --- |
| The contract sentence | `AGENTS.md:358` | "Severity lives here" — of `knowledge/backlog.md` |
| The queue's founding rationale | `queue/README.md:22` | lists `severity` among the facts that lived in prose *before* the queue, which exists "so that a state fact has one home" |
| The field | `queue/items/*.yaml` | every `kind: defect` item carries `severity:`; no `question` or `stream` item does. Stated as an invariant, not a count: the count in the first draft of this row was already stale when it was written, because filing `Q-52` and `B-210` changed it |
| The protocol that acts on it | `HUB.md:617`, step 2 *Select* | "Prefer the item with the lowest `severity` number among defects" — read out of the item file; step 1 of the same list says "Read item files, not prose" |
| The normative field list | `HUB.md:551` | names `id`, `kind`, `title`, `state`, `claimable`, `repo`, `blocked_by`, `legacy`, `evidence`, `venue` and, for a defect, `retires_when` — and **stops there**. Neither `severity` nor `stream` is in it |
| The second copy | `knowledge/backlog.md` | carries severity by **position**: four sections, `### Open — P1` (1015), `### P2 — correctness and conformance debt` (1309), `### Open — P3` (3312), `### Open — P4` (3719) |

**The tally is 3–2–1, and it was never the argument.** Three readings point at
the item file: the founding rationale, the field itself, and the *Select* step.
Two point at the backlog: the contract sentence and the positional grouping. One
points at neither, because it omits `severity` altogether. The version of this
sentence first written here said *"four of the six behave as though the item
file is the home"* — and the version before it said *four of the five*, which was
already wrong by one before the sixth row existed. Adding a row and changing the
denominator without re-deriving the numerator is the same failure as every other
one in this section, in the one paragraph that was supposed to summarise them.

**What does bear on the ruling is not a vote count.** Of those readings, exactly one
*acts* on the value — the `Select` step, which orders the queue by it, and which
reads the item file. And exactly one makes a *normative claim* about where the
fact lives, rather than carrying it, acting on it, or recording history: the
`AGENTS.md` sentence. That is what makes it the expensive place to be wrong —
not that it is outnumbered, but that it is the only assertion of the contract,
in the file an agent reads first and without choosing to.

**The `HUB.md:551` reading is the one that enlarges the question**, and it was found
only because the first draft of `Q-52` asserted the opposite. `HUB.md`'s
normative field list omits `severity` — and omits `stream` with it — while the
*Select* step twenty lines below orders the queue by `severity`.
`queue/README.md:44` shows both fields in its illustrative block, and
`queue/README.md:59` says of that block: *"`HUB.md` carries the normative field
list … if the two ever differ, `HUB.md` is right and this one is the copy that
is wrong."* So by the queue's own precedence rule, the field the queue is
ordered by is not one of the fields an item carries, and 129 cards carry it
anyway (117 carry `stream`). **Nothing checks either list**: `hub_queue.py` has
no field-set validation at all — its checks are doubled apostrophes, absolute
paths, evidence existence, members, member fields, workpads, `solo`, and
generated blocks. So the ruling has to name the field in `HUB.md` too, or say
why a field the protocol depends on is not one an item declares.

The draft of this row said the list *included* `severity` — a claim taken from
`queue/README.md`'s illustrative block plus that sentence about precedence,
without opening `HUB.md` at the line the sentence points to. Third instrument
failure of the same sweep, and the one that was not an instrument at all:
reading a file that says another file is authoritative, and then not reading the
authoritative file. This is the case the lede at the top of the section has to
cover, and did not until the Codex review of pull request #142 said so.

**The positional copy is partial, and that is not a detail.** Measured
2026-09-16: of 119 backlog entries, 43 sit under one of the four P-sections
(P1=6, P2=18, P3=5, P4=14) and 76 sit under none — among them all 34 of the
older `### N. title` entries, and every entry filed in the dated 2026-09 round
sections at the end of this file.
(The highest-numbered line of a P-sectioned entry is 4212; the run of dated
sections begins at 4780.) Severity sections are at the same heading level as the
dated round sections, so a P-section ends at the next heading of its own level
or shallower. Those
entries carry severity in prose if at all (`**P3**, as B-200`; `**P2 on
both:**`). A reader who follows `AGENTS.md:358` to find a recent item's severity
therefore finds nothing — and per B-161's rule, an empty result states the
instrument's reach, not the target's contents, so that reader concludes "no
severity recorded" rather than "wrong file."

**Two divergences, and in both of them the positional copy is the wrong one.**
Measured 2026-09-16: of the 44 items carrying a `legacy: '#NN'` pointer, 30
resolve to an entry under a P-section; 28 agree with the item file and two do
not.

| Item | Card says | Position says | The entry's own prose says |
| --- | --- | --- | --- |
| `B-83` (`icebox`) | `P4` | `P2` — inside `### P2 — correctness and conformance debt` (1309–2270), at 2116 | *"Cosmetic — the value is a ranking input, never asserted — so nothing fails"* → P4 |
| `B-116` (`done`) | `P1` | `P4` — inside `### Open — P4` (3719) via `#### smn-data-pkg` (3733), at 3735 | *"Severity: **high**"* → P1 |

Each entry's prose agrees with its card and contradicts its own position, in
opposite directions, which is the strongest available evidence for the
recommendation in `Q-52`: the field is the reliable copy and the position is
not. `B-116` is also the backlog contradicting *itself* — an entry that calls
its own severity *high* filed under the P4 ecosystem heading. Both have to be
disposed of by the ruling rather than left to whichever side wins.

**Every earlier reading of that table was wrong, and each looked clean.** They
are enumerated below with the instrument and the finder named on each, and this
sentence deliberately states neither a count nor a common origin: the version of
it that did said *"three wrong readings, all from the same script,"* which was
wrong three ways at once — the list had four items, one of them is a standalone
`awk` check rather than the Python reader, and two of the four were found by
review rather than by any run of mine.

**A summary sentence left behind by the list it summarises is the single most
repeated defect on this pull request**, and the instances are marked where they
occur rather than tallied here — this paragraph carried a count of them and the
count went stale twice, which is the defect describing itself. Each was caught
by review, none by a re-read, and each is the one this whole section is about:
**a summary is a second copy of what it summarises, so it has exactly the
two-homes problem, and a correction to the list does not touch it.** The
structural fix is a lede that carries no facts of its own, because such a lede
cannot fall out of step with the list under it — which is why the count here is
gone rather than corrected.

**And the rule that governs this had already excluded this sentence when it was
written.** Two rounds earlier the section settled on: *a count appears only
where the material that verifies it is immediately adjacent and the number is
itself the finding.* Here the number was the finding, but its instances are
scattered through the section rather than adjacent — so the rule already said
this count could not stay, and it stayed anyway, until review. That is the
tenth corollary of `queue/README.md` in its purest form: the change that
introduces a rule is the one least likely to be checked against it, and this
time the rule was two rounds old and still not applied to the paragraph
directly above it.

1. The cross-check script first read entries as `### N. title` headings only. It
   reported 34 entries, **zero** under any P-section, zero agreements and zero
   disagreements — which reads as "the backlog does not record severity at all,"
   a tidy finding that would have retired Q-52 before it was filed. The
   P-sections do not use headings for entries at all: they use bold-lead
   paragraphs, of the form `**#96 A Date in dataset_meta destroys the
   package...**`. Reading both forms gives 119 entries and 26 under a section.
   The fixed script now prints its counts **per entry form**, so a form it
   cannot see shows up as a zero beside a non-zero rather than as a clean total.
2. Checking which heading precedes entry #83, `awk 'NR<=2116 && /^#{2,} /'`
   returned line 757, a `##` section — which would have put #83 under no
   P-section and made the single divergence disappear. Over the lines it
   actually read — those at or before 2116 — that pattern matches 8 lines where
   `/^##/` matches 54, so the interval expression is not doing what it reads as
   doing. `grep -n "^#\+ "` gives 1309, agreeing with the Python instrument.

3. **The version that produced the numbers first written into this section
   cancelled a severity section on *any* heading that was not an entry.** A
   deeper heading is a *child*, not a terminator: `#### smn-data-pkg` (3733)
   nests inside `### Open — P4` (3719), and treating it as a terminator made
   entry #116 and every entry after it read as ungrouped. That concealed the
   second divergence and understated the grouped population by 13 entries —
   26 rather than 39 — and cross-checked 16 pairs rather than 27. **It was
   found by the Codex review of pull request #142, not by this script**, which
   is the part worth keeping: the section-scope bug produces a *smaller*
   inventory and a *cleaner* story, so nothing inside the result invites
   suspicion. The fix is a heading stack keyed by level, so a section is in
   force until a heading at its own level or shallower — Markdown ancestry,
   which is what "sits under" means. The script's header now carries all three
   wrong versions.

4. **And the version that replaced it registered each entry number with
   `setdefault`, so the FIRST occurrence won.** Four numbers — #94, #112, #113,
   #115 — are *mentioned* in the provenance prose near the top of this file
   before their real entry appears inside a P-section (`**#115 came out of
   closing #93 item 4**` at line 157, against the entry at 1770), so all four
   read as ungrouped: 39 sectioned rather than 43, and 27 pairs rather than 30.
   **Found by the Codex review of pull request #142, on the round after the one
   that found the section-scope bug** — the same reader, the same file, a second
   wrong number in the same paragraph, caught by the same reviewer one round
   later. The reader now prefers a *sectioned* occurrence, and states the limit
   it cannot escape: a mention and an entry are the same shape to it, both a
   bold `**#N` at line start, so an entry's section is *inferred* from the one
   occurrence that has a section. Correct for all four of these, verified by
   reading them, and a heuristic rather than a rule. Making it a rule means the
   backlog marking its entries — a change to the backlog, not to the reader.

**And one that was not a reading at all — it was a WRITE that never happened.**
Three of the corrections above were reported as made, replied to on the pull
request as made, and described in a commit message as made, while the file on
disk still carried the old text: *"diverged once"* against a table recording
two, `39` sectioned entries where the corrected figure is `43`, and `27` pairs
where it is `30`. The script that made them batched every substitution into one
in-memory string and called `write_text` once at the end; a later assertion
raised first, so **nothing was written while four `ok:` lines had already
printed**. The follow-up script then re-applied only the substitutions that had
*failed to match* — the ones that had "succeeded" looked done. Found five rounds
later, by a sweep looking for something else.

This is the most consequential failure in the section, because it is the only
one that made the *reports* false rather than the measurements: the reviewer was
told a thing was fixed, and it was not. The mechanical fix is that an edit
writes to disk immediately and is confirmed by re-reading the file, so a later
failure cannot discard an earlier success and a success is never asserted from a
variable. The general form belongs with the rest: **a log line saying an edit
succeeded is a claim about the program's memory, not about the file** — the same
distinction as instrument versus target, one layer down.

**And one in a different instrument, with a cost none of the others had.**
The round-outcome watcher for this pull request reported head `3cad83b`
**clean** while its code review was still running. Its reaction check read
`any("codex" in m["user"]["login"] for m in marks)` — any reaction by Codex at
all — while the bot's own comment states the semantics in the same thread:
*"Codex reacts with 👀 while any review is running … and reacts with 👍 once all
reviews finish with no findings."* So 👀 is the **running** signal and the check
treated it as the finished one. The script's own header described the shape
correctly ("a THUMBS-UP REACTION … per Codex's own documentation") and the code
under it did something else, which is the shape `B-210` is about, one file
lower: **a stated scope and the implementation of it are two artifacts, and only
one of them runs.** This is the one instrument error in the sweep that could
have merged an unreviewed head, and it was caught by reading the output against
documentation that was quoted verbatim in the notification carrying it.

The rule is the same one every time, and it is B-161's: a result that makes a
finding vanish is the one to re-measure with a second instrument. What this
round adds is two harder cases. **A result that makes a finding vanish while
looking like an ordinary count** — nothing empty, nothing surprising, so there
is no signal to re-measure against except reading the source by hand. And **a
result that agrees with what you were hoping for**, which is worse, because the
watcher's false "clean" was the answer that ended the work rather than
continuing it. An instrument that reports success is the one to check twice.

**The exemption that was repeatedly misread as a gap.** `CHECK_ONLY_RULES` in
`scripts/tests/test_hub_queue.py:2004` exempts `generated-block-missing`,
`generated-block-no-target`, `generated-block-target-missing` and
`generated-blocks-unreadable` from the coverage guard that #141 added, and gives
a correct reason: they are emitted by `validate_generated_blocks`, which
`command_check` calls and `command_lint` does not, so they are outside a claim
about lint rules rather than gaps in it. What it does not say is where they *are*
demonstrated, and the reading that followed went wrong three times in one sweep:

- A grep for the four **rule names** in the test file found one hit outside the
  set itself. Conclusion drawn: four rules never shown to fire. Filed as a draft
  queue item asking for four tests.
- The one hit turned out to be a real demonstration
  (`test_a_configuration_declaring_no_blocks_fails`). Conclusion narrowed to
  three. Still wrong, and now wrong *with* a correction attached, which is the
  more convincing state to be wrong in.
- A grep for the rules' **message text** — which is what those tests assert on,
  and the reason the name grep saw nothing — found
  `test_a_configured_block_with_no_target_fails` ("declares no `target:`") and
  `test_half_a_marker_pair_is_reported_as_missing` ("delimits nothing"). That is
  the remaining two, so the demonstrated count is four: all of them.

All four are demonstrated, by six tests in `TestConfiguredBlocksExist`
(`scripts/tests/test_hub_queue.py:1592`), and
`test_a_configured_block_with_no_marker_anywhere_fails` carries an explicit
RED/GREEN pair whose comment names the blocker verbatim: *"RED, and this is the
blocker verbatim: the configuration declares a block, the repository carries no
markers at all, and the old `check` printed OK."* The draft item was deleted and
B-210 filed in its place, for the omission rather than the imagined gap.

**One distinction these rounds forced, and it is the rule `B-209`'s first
deliverable asks for.** Twice now a card has been trimmed for asserting what the
tooling currently does or does not check — `Q-52` said *"nothing checks either
list"* and *"nothing compares them"*, both true today and both invalidated the
moment `B-209`'s own checker lands. But `B-209`'s **title** asserts an absent
check too — *"nothing fails when a card restates queue state in prose"* — and
that one is correct to keep. The difference is what retires the claim: **a card
may assert an absence that is its own defect, because the card stops existing
when the absence does; it may not assert the coverage state of anything else,
because nothing retires the card when that changes.** The first is a condition,
the second is a measurement wearing a condition's clothes.

The generalisation is B-210's subject and is worth stating on its own, because
the same shape will recur wherever a guard states a scope: **membership in an
exemption set is evidence about the guard, never about the test suite.** An
exemption that explains why something is outside one claim, without naming what
is inside another, reads as absence of coverage — and the reader most likely to
misread it is the one who wrote the exemption, because they are reading their own
sentence for confirmation rather than for content. Three readings, one reader,
ten minutes.

### The 2026-09-23 queue sweep

**What wave 1's hand-backs found and deliberately did not absorb, each filed
below as its own item, plus a measurement-layer finding from 2026-09-16 that
waited a week for a card.** Each entry is headed by its queue id. **State,
severity and each item's condition live in `queue/items/` and are not restated
here**: this section is what each new item's `evidence:` pointer resolves to,
and it holds the measurements — what was observed, on which tree, and by whom.

**Where a number comes from is part of the number.** Each measurement is cited
to the run that took it and the tree it ran on. Where this sweep re-ran one
rather than copying it from a workpad, it says so. The sweep's own runs used R
4.3.3 under `C.UTF-8` on metasalmon `main` at `b456201` unless another tree is
named, and Python 3.11.15 with pandas 3.0.5, requests 2.33.1 and PyYAML 6.0.1
against a `git archive` of metasalmonpy `main` at `3f8349a`, its tip that day,
imported from a directory named `metasalmonpy` (`B-191` says why). Their scripts
were scratch files and are not committed. The workpads for `B-3`, `B-142`,
`B-175` and `B-176` are on `main` under `.hub/workpads/`; those for `B-174` and
`B-198` are on their pull requests' branches (#144, #148); `B-191`'s was in a
local metasalmonpy worktree whose branch had not been pushed when this was
written.

**From `B-174`'s hand-back** (metasalmon pull request 144, head `b80bdff`).

**`B-211` and `B-212`: a prose placeholder in an `*_iri` field is reported
twice, and the call printed for it cannot run.** Measured by the B-174 run on
`main` `12efe9d`: with `MISSING METADATA: add the observation unit IRI.` in
`tables.csv`'s `observation_unit_iri`, `review_metadata()` returns two rows for
the field, `placeholder` from the field loop and `iri` from the dedicated
branch, and the printed `set_sdp_table()` call names `observation_unit_iri`
twice, so evaluating it fails with *formal argument "observation_unit_iri"
matched by multiple actual arguments*. `REVIEW REQUIRED: pick a unit.` in a
measurement row's `unit_iri` does the same through `set_sdp_column()`.

**Re-measured by this sweep, which is how it is known to predate B-174:** the
same two plantings, on a package `create_sdp()` built with the schema source
pinned to `vendored`, give two rows per field and the same two errors on `main`
`28fef73`, on pull request 144's head `b80bdff`, and on `main` `b456201`. On
`b456201` the code is `.ms_metadata_gaps_for_file()`
(`R/sdp-field-setters.R:271`): the field loop's `.ms_is_review_placeholder()`
at `:306`, then `.ms_is_unfilled_metadata()` at `:324` for
`observation_unit_iri` and at `:332` for the measurement IRIs.

**metasalmonpy was read by the B-174 run and run by this sweep.** The same two
plantings on `3f8349a` give two rows per field, `placeholder` and `iri`, and
both printed calls fail to compile with *keyword argument repeated*.
`_gaps_for_file()` (`sdp_field_setters.py:403`) tests `is_review_placeholder()`
in its loop at `:447` and `_is_unfilled_metadata()` at `:480` and `:494`, and
`_is_unfilled_metadata()` counts a prose placeholder as unfilled (`:186`).

**Latent on both sides**, per the B-174 workpad: nothing in the package writes a
prose placeholder into an `*_iri` field — the one `REVIEW REQUIRED:` writer, in
`R/semantic-closure.R`, targets a rationale column — so only a hand-edited
package reaches it.

**From `B-175`'s hand-back** (metasalmon pull request 145, merged 2026-09-23 as
`c7e4274`).

**`B-213`: the pkgdown build aborts on `main`.** Measured by the B-175 run with
pkgdown 2.2.1 on a copy of `12efe9d` plus that branch's two regenerated Rd
files: `pkgdown::build_reference()` stops with *In _pkgdown.yml, 1 topic missing
from index: "write_sdp_semantic_closure"*. Re-measured by this sweep on
`b456201` with `pkgdown::check_pkgdown()` under pkgdown 2.2.1, which reads the
index without building anything: the same message. `NAMESPACE:69` exports the
function and `man/write_sdp_semantic_closure.Rd` documents it; B-116 exported
it, and `_pkgdown.yml` last changed on 2026-08-25 (`8c8ec6a`). **Nothing in CI
would have said so:** a search of `.github/workflows/` for `pkgdown` finds
nothing, so no job builds or checks the site. The B-175 workpad records that
the function's reference page was never generated either.

**`Q-53`: R's validator reaches the remote schema on a cold session, and
metasalmonpy's makes no network call.** Measured by the B-175 run under the
shipped defaults with a cold schema cache: `validate_salmon_datapackage()` makes
one remote fetch attempt, for the whole bundle, through the readers' column
aligners (`.ms_sdp_schema_field_names()`), from 13 schema-loader calls on `main`
`12efe9d` and 5 on pull request 145's branch, where the blank-required collector
stopped loading. **Re-measured by this sweep on `b456201`**, with the loader and
the remote fetch counted and the fetch failing as an unreachable host's would:

| call, each from a cold cache | loader calls | remote fetch attempts |
|---|---|---|
| `validate_salmon_datapackage(pkg)` | 5 | 1 |
| `validate_salmon_datapackage(pkg, require_iris = TRUE)` | 3 | 1 |
| `review_metadata(pkg)` (B-175's fix) | 0 | 0 |
| `.ms_load_sdp_schema()`, the control | 1 | 1 |

The `require_iris = TRUE` call stops on the fixture's unfilled `term_iri` after
its fetch, so its counts run to that point. On a host that never answers, the
attempt costs one timeout (the correction under `B-175` above). R's
documentation for its validator makes no offline claim.

metasalmonpy's docstring for its blank-required collector reads the bundled
schema "because `validate_salmon_datapackage()` makes no network call"
(`package_io.py:2336-2337` at `3f8349a`). The B-175 run did not measure that.
This sweep did: a package built by `create_sdp()` under the vendored pin, then
the source reset to `auto`, the loader cache and the vendored-document cache
cleared, `requests.get` replaced by a counter that raises, and
`socket.socket.connect` blocked. `validate_salmon_datapackage(pkg)`, the same
with `require_iris=True` (which raised on the fixture's unreviewed IRIs, after
reading the package), and `read_salmon_datapackage(pkg)` made no remote fetch,
no GET and no socket connection, and raised no fallback warning. **The
instrument's reach was shown first, in the same process:** a cold
`load_sdp_schema()` under `auto` registered one fetch and one GET. Neither
`knowledge/parity-deviations.md` nor metasalmonpy's `PARITY.md` mentions the
difference.

**`B-214`: metasalmonpy's socket test never calls `set_sdp_code()`.** At
`3f8349a`, `test_the_offline_path_opens_no_socket_at_all`
(`tests/test_sdp_field_setters.py:460`) blocks `socket.socket.connect`,
`connect_ex` and `socket.create_connection`, then calls `review_metadata()`, the
console renderer, `set_sdp_dataset()`, `set_sdp_table()` and `set_sdp_column()`.
Its docstring says it covers "the four setters and the console renderer, because
`_SCHEMA_SOURCE` claims the bundled read for all of them". Found by the B-175
run; this sweep set the docstring against the body. The four setters share
`_set_sdp_metadata()`, so the fourth is covered by construction and not by
assertion. metasalmon's offline test, added by B-175, asserts all four.

**`B-215`: metasalmonpy ignores a schema the options select.** Codex's finding on
pull request 145 at `2b74b14` (thread `PRRT_kwDOSoVfrc6lNfgN`) was that a schema
selected through `metasalmon.sdp_schema_base_url` or
`metasalmon.sdp_schema_source` no longer reached the scan or the setters. The
B-175 run reproduced it with a selected bundle adding a required `dataset.csv`
field, `funding_source`, cached under the writers' key: at `2b74b14` the writer
wrote the column, `review_metadata()` omitted it,
`set_sdp_dataset(funding_source = ...)` failed with *'dataset.csv' has no such
field*, and the validator's blank-required collector lost it, where `main`
`12efe9d` honoured all four.
`7c22fa3` fixed it by reading the bundle under the default options only, and
that is what merged.

**metasalmonpy has the finding verbatim, and has had it since its pull request
28 merged on 2026-09-16.** `_SCHEMA_SOURCE = "vendored"`
(`sdp_field_setters.py:153` at `3f8349a`) is passed to every schema read in
`sdp_field_setters.py` and to the validator's collector in `package_io.py`
(`:2345-2357`). Run by this sweep on `3f8349a`, with the same shape of bundle
cached under the key `set_sdp_schema_source("remote")` selects: the writers'
field list included `funding_source`; `review_metadata()` did not report it;
`set_sdp_dataset(funding_source=...)` raised *dataset.csv has no such field:
funding_source*; the collector did not name it; and no GET was made. **The
control:** with `_SCHEMA_SOURCE` pointed at the session's source, the scan and
the collector both reported the field. That control earned its place: the first
version of the probe tested the collector by iterating the DataFrame it returns,
which yields column labels, and reported "not named" whatever the collector
did. The port is recorded as owed in `parity-deviations.md` and in the
roadmap's release index, in this change.

**From `B-176`'s hand-back** (metasalmon pull request 146, merged 2026-09-23 as
`11e8a2f`). Its workpad measured each finding below in both implementations — R
on its branch, metasalmonpy on `main` `3f8349a` with the same stub retrieval —
and found each behaving identically, which is why the shared ones are pairs.

**`B-216`: metasalmonpy counts a recorded hand-picked accept as ontology-gap
evidence.** Pull request 146 records a hand-picked accept as a row of its own,
`source` `user`. Codex found on its first head, `142ff91`, that
`detect_semantic_term_gaps()` then reported a false gap: on a fixture whose
`spawner_count` slot holds two `ols` candidates, one real gap, the post-review
file gave a second row for the slot, with a blank `search_query`,
`top_non_smn_source` `user`, the hand-picked IRI and placement `uncertain`.
`52b0a6c` excludes `source = "user"` rows in R. metasalmonpy has recorded the
same row since its #28 and still counts it: measured on `3f8349a`, one gap row
before a hand-picked accept and two after. A hand-picked IRI under
`w3id.org/smn/` does not trigger it — measured at `142ff91`,
`https://w3id.org/smn/HandpickedSmn` gives one row before and one after —
because the detector counts that namespace as `smn`. **No function in either
package passes a post-review file to the detector** (a search of `R/` at
`b456201` and of metasalmonpy's modules at `3f8349a` finds no caller), so a user
reaches it by passing `semantic_suggestions(path)` as `suggestions`. Pull
request 146 wrote the port's specification into `parity-deviations.md` and the
release index, saying the metasalmonpy item was still to be filed; this sweep
put the id in both places.

**`B-217` and `B-218`: a decision hidden by `max_candidates`.** On a
six-candidate slot, `accept_suggestion(..., rank = 6)` after
`review_semantics(max_candidates = Inf)`, applied, then the review rebuilt at
the default: no decided row is shown and no `DECIDED` line is printed, in both
implementations, while the slot still leaves the default queue. In R on
`b456201` the default queue computes the decided set at
`R/review-console.R:394`, inside the branch `include_filled = TRUE` skips, the
rank filter follows at `:398-399`, and the `DECIDED` line is built only from
rows carrying a decision (`:661-666`). metasalmonpy at `3f8349a` has the same
shape (`review_console.py:694-695`, filter at `:698-699`). A hand-picked accept
does not hit it, because pull request 146 inserts that row at the head of its
slot.

**`B-219` and `B-220`: an accept whose IRI is empty.**
`accept_suggestion(iri = "REVIEW:")` passes the non-empty check, which runs
before the marker is stripped: R checks at `R/review-console.R:886` and strips at `:907` on
`b456201`; metasalmonpy checks at `review_console.py:1153-1154` and strips at
`:1170` on `3f8349a`. The B-176 run measured the consequence: on `main`
`12efe9d` apply clears the field and records nothing; on its branch and in
metasalmonpy it clears the field and records an `accepted` row with an empty
`iri`, which `review_semantics()`, `apply_semantic_suggestions()` and the
closure reader each drop. **The two strips are not the same function**: R's
removes `^\s*REVIEW\s*:\s*` ignoring case (`R/package-helpers.R:3787`), and
metasalmonpy's removes a leading `REVIEW:` compared upper-cased
(`review_console.py:140`), so a space before the colon is stripped by one and
not the other. That is why each item's condition names the spellings its own
package's strip removes rather than a shared list. `Q-63` owns which spellings
every detector in both packages should recognise, so the pair cannot close the
difference by accident or leave it unowned. Each package is itself mixed as well:
R's four `^REVIEW:` detectors and both packages' literal-substring output guards
disagree with their own strips, and Q-63 lists every site. `Q-18` holds the
neighbouring question of the marker's trailing space.

**`B-221` and `B-222`: the `term_type` a hand-picked IRI gets.** With an
`owl_class` candidate at rank 2, `accept_suggestion(iri = <that IRI>)` writes
`term_type` `skos_concept`, and re-applying the rebuilt review — which replays
the decision at rank 2 — writes `owl_class`, in both implementations, so that
one path is not byte-stable across a rebuild. In R, on `main` `f6cd22a`, the
decision sits on the slot's first row (`R/review-console.R:913`), and the writer
takes the type from that row only when its `iri` equals the accepted one,
falling back to `skos_concept` (`R/metadata-write.R:463-473`). The B-176 run
scoped its `NEWS.md` sentence about byte-identical re-application to the case
where no candidate carries the IRI, for this reason.

**From `B-142`'s hand-back** (metasalmon pull request 147, merged 2026-09-23 as
`b456201`).

**`B-223`: a tagged scalar in the EML sidecar.** Measured by the B-142 run on
`main` `12efe9d` with yaml 2.3.12 and the option unset: an `!expr` tag in
`metadata/eml-mapping.yml` came back as its text from
`.ms_closure_mapping_paths()` and from `write_eml_from_sdp()`, whose EML methods
paragraph carried the text, with yaml's warning *Evaluating R expressions
(!expr) requires explicit `eval.expr=TRUE` option*; since B-142 the explicit
argument also silences that warning. Any unrecognised local tag, such as
`!foo`, reads the same way. metasalmonpy at `3f8349a`, PyYAML 6.0.1:
`_read_mapping_yaml()` (`eml.py:3704`) raises *EML mapping sidecar ... is not
valid YAML* on the EML and KNB paths, and `_mapping_paths()`
(`semantic_closure.py:851`, `yaml.safe_load()` at `:864`) falls back silently
to the default closure paths. Register row 14 records PyYAML for the sidecar and
says nothing about tags. The roadmap's `B-142` paragraph says the difference is
tracked as its own queue item; this is that item.

**`B-224`: yaml's history, told two ways in one `NEWS.md` section.** yaml's own
NEWS dates the argument to 2.1.19 (*"Added `eval.expr` option"*) and the
default change to 2.3.0 (*"Made `eval.expr` default to `FALSE`"*). The B-142
run read `yaml.load()`'s signature in CRAN's archived tarballs —
`getOption("yaml.eval.expr", TRUE)` in 2.2.0 and 2.2.2, `FALSE` in 2.3.4 — and,
on yaml 2.2.2 built from the archive with no option set, measured `main`'s
remote rules read and closure read evaluating a tag. `NEWS.md:129`, in #111's
validator entry under the development heading, calls `yaml (>= 2.2.0)` "the
version that introduced the argument", and `:125-128` describe the exposure as a
session that turned the option on; `tests/testthat/test-sssom.R:491-493` says
yaml's own default is `FALSE` and that such a session is the worst case. Since
`b456201` the same `NEWS.md` section also carries B-142's entry, which states
the history correctly (`:329-331`), so the section contradicts itself. `B-189`'s
card makes the same understatement in its rationale; its retirement condition
is unaffected.

**`B-225`: nothing pins metasalmonpy's other YAML reads.** Read by the B-142 run
on `3f8349a`: the sidecar goes through `_read_mapping_yaml()`, whose loader is
`_StrictSafeLoader` (`eml.py:3676`), a `yaml.SafeLoader` subclass adding only a
duplicate-key check and a timestamp-as-text constructor; the closure's paths go
through `yaml.safe_load()` (`semantic_closure.py:864`); both rules reads go
through `_rules_scalars()`, a regular-expression scan (`sdp_schema.py:383`,
`:406`); and the SSSOM header goes through `_parse_yaml_subset()`
(`sssom.py:456`), which `B-189` is to pin. Nothing fails if
`_strict_yaml_loader()` is swapped for `yaml.Loader`, or `safe_load()` for
`yaml.load()` or `full_load()`.

**From `B-3`'s hand-back** (metasalmon pull request 149, merged as `19bf188`).

**`Q-54`: the two request shapes.** Measured by the B-3 run against metasalmonpy
`main` `3f8349a`, with R read at its branch head and re-read by this sweep on
`b456201`:

| | R | metasalmonpy |
|---|---|---|
| temperature | `0` on semantic review, omitted for an `openai` GPT-5 model (`R/llm-semantic-helpers.R:1693-1697`); `0.2` on chat decomposition (`R/chat-decomposition.R:443-450`) | none |
| JSON mode | never | `response_format: {"type": "json_object"}` (`llm_review.py:422`) |
| OpenRouter attribution | `HTTP-Referer` and `X-Title` (`R/llm-semantic-helpers.R:1741-1742`) | none |
| user agent | `metasalmon/<version>` (`:1734`) | the `requests` default |

metasalmonpy's chat decomposition goes through the same `request_json()`
(`chat_decomposition.py:279`), so both of its paths send one shape. Both
packages send a configured `reasoning_effort` on semantic review; R's chat
decomposition sends none, and whether metasalmonpy's resolves one there was not
measured. A search of both registers for temperature, `response_format`,
`json_object`, reasoning effort, referer, `X-Title`, user agent, `request_json`
and the endpoint path finds nothing relevant; row 60 matches only on "billable
LLM requests".

**Reasoning effort, measured 2026-09-24** on metasalmon `main` `abfc7d6` and
metasalmonpy `main` `e595752`, which refines the sentence above. R resolves
`METASALMON_LLM_REASONING_EFFORT` when no argument names an effort, then drops
the effort for every provider but `openai` (`R/llm-semantic-helpers.R:412-418`),
and the body builder sends what is left (`:1699-1701`). metasalmonpy reads no
such variable (no `.py` file contains `REASONING_EFFORT`) and sends an effort
whenever `llm_reasoning_effort` names one, for any provider
(`llm_review.py:424-425`). So semantic review differs twice: a session that sets
only the variable sends an effort from R and none from metasalmonpy, and an
effort named for OpenRouter reaches the provider from metasalmonpy and not from
R. Neither chat path sends one today: R's builds its own body, and metasalmonpy's
passes `reasoning_effort=None` (`chat_decomposition.py:253`). R's chat path
resolves its config through `.ms_llm_resolve_config()` with no effort argument
(`R/chat-decomposition.R:487-494`), so routing it through the shared builder, as
B-128 does, would make it send the variable's value. The Codex review of pull
request 150 on `e03fd35` found the chat-path half.

**`B-226`: a third request, in the benchmark.** `scripts/theme-a-benchmark.R`
builds the endpoint at `:2074` and the request at `:2106-2130`, unchanged
between the B-3 run and `b456201`: its own user agent,
`metasalmon-theme-a-benchmark/1`, and for OpenRouter its own `X-Title`,
*metasalmon Theme A benchmark*, with the authorization and content-type headers
and the timeout written out again. It already reaches the body builder through
`getFromNamespace()`, and records the provider's resolved model and refuses a
substituted one. The single-builder guard's header says the script is outside
its reach (`tests/testthat/test-llm-chat-request.R:35-39`). The B-3 run also found
`.ms_chat_http_request()` accepting `response_schema` and ignoring it; that
belongs to `B-31`, which owns the engine's request contract, and is not filed
separately.

**From `B-191`'s run** (metasalmonpy, measured on `main` `3f8349a` and on the
run's local fix `8476b8e`, Python 3.11.15 with pandas 3.0.6).

**`B-227`: bare `pytest`.** `tests/test_validation.py:5`
(`from validation import validate_semantics`) and
`tests/test_term_deduplication.py:5` (`from term_deduplication import ...`)
resolve only when the checkout root is on `sys.path`, which `python -m pytest`
from the root arranges and bare `pytest` does not. Bare `pytest -q` — the
command metasalmonpy's `AGENTS.md` documents after `pip install -e ".[test]"`
(`AGENTS.md:228` at `3f8349a`) — and `python -m pytest -q` launched from inside
`tests/` both stop at two collection errors, *No module named 'validation'* and
*No module named 'term_deduplication'*, and report *Interrupted*, the same
before and after the B-191 fix.

**`B-228`: the old shared workpad.** metasalmonpy `3f8349a` still carries
`.hub/workpad.md`, holding B-126's report, beside a `.hub/workpads/` directory
that has no `B-126.md`. B-140 retired the shared path in metasalmon only. The
B-165, B-144 and B-191 runs each named it, and none moved it, since it was none
of theirs.

**From *The 2026-09-16 network-guard finding* above.**

**`B-229`: a re-run erases the flake it fixes.** Filed from the orchestrator's
*Salmon Hub Decisions* page (the card *A re-run erases the flake it fixes*,
2026-09-23), which carries the B-197 run's figures of 2026-09-16, recorded in
that section: across 484 `R-CMD-check` runs, ten had ever finished failed and
none since 2026-09-01, while four carried `run_attempt > 1`, three of them in
the five days to 2026-09-16. **Re-measured by this sweep on 2026-09-23 through
the Actions API**, reading workflow `R-CMD-check` (id 322644612): 551 runs, 549
completed and 2 in progress; 387 `success`, 152 `cancelled` and 10 `failure` —
the same ten, created between 2026-08-10 and 2026-08-26 — so none since
2026-09-01. Four runs carry `run_attempt` 2, each concluding `success`: 215
(2026-08-18), 337 (2026-09-12), 360 (2026-09-15) and 449 (2026-09-16). None of
the 22 runs created from 2026-09-17 on failed or was re-run. The 2026-09-16
count was taken during that day: runs are numbered in creation order, the 484th
was created at 18:36 UTC and the 485th at 18:58, and 529 were created before
2026-09-17.

**What the per-attempt endpoint shows that the run list does not.** Reading each
re-run's attempts: 337, 360 and 449 each have attempt 1 concluding `failure` and
attempt 2 `success`, and 215's attempt 1 was `cancelled`. So three failures are
invisible to any count taken from the run listing, and recoverable without the
blob-storage redirect the 2026-09-16 reading needed for logs, because the
attempt endpoint keeps each attempt's conclusion. The three are flakes already
filed: 337 is pull request 112's, the one `B-132` records; 360 is run
34912254547, `B-155`'s pak install failure; and 449 is pull request 137's
DataONE 503, `B-197`'s.

**From the 2026-09-23 rulings.**

**`B-230`: the metasalmonpy half of the ruling on `REVIEW:`-marked IRIs.** The
ruling and the plan that implements it are on `B-177`'s card; the evidence for
the question is `B-177`'s entry under *The R halves of the 2026-09-15 Codex
findings on metasalmonpy PR #28* above. What the Python half has to move, read
by this sweep on `3f8349a`: `_collect_review_issues()`
(`package_io.py:2465-2496`), which the EDH gate builds on, sweeps `tables.csv`,
`column_dictionary.csv` and `codes.csv` for `REVIEW:` IRIs and not
`dataset.csv`; `_REVIEW_IRI_FILES` (`sdp_field_setters.py:259`) lists the same
three; and `test_which_files_a_review_marker_actually_blocks`
(`tests/test_sdp_field_setters.py:213`) pins strict validation refusing a marker
in `tables.csv` and `column_dictionary.csv` and passing one in `codes.csv` and
`dataset.csv` — the answers measured on 2026-09-16 and recorded on `B-177`'s
card.

**From Brett's question on 2026-09-23 about the smn documentation site.**

**`B-231` and `B-232`: 43 of smn's 159 local terms carry no definition, and 41
of them show a blank entry on the published site.** Brett noticed it at
`https://salmon-data-mobilization.github.io/salmon-domain-ontology/#/Run`.
Measured by this sweep with rdflib 7.6.0, on salmon-domain-ontology `main` at
`d45f8f7`. The scope was every `smn:` IRI in `ontology/modules/*.ttl` typed as an
OWL class, an object, datatype or annotation property, or a SKOS concept or
concept scheme. That is 159 terms, and 43 of them carry neither
`obo:IAO_0000115` nor `skos:definition`. By module, the 43 fall:

- 7 in `01-entity-systematics.ttl`;
- 29 in `02-observation-measurement.ttl`;
- 2 in `04-management-governance.ttl`;
- 5 in `07-controlled-vocabularies.ttl`.

Modules 03, 05, 08 and 09 and `alignment-research.ttl` have none.

Two of the 43 carry an `rdfs:comment`, which the site shows in the
definition's place: `AggregatedMeasurement` and `FishLengthMeasurementType`.
For the other 41 it shows nothing. Measured a second time under the stricter
rule the repository already uses for some of its terms (`skos:definition` for a
SKOS term, `obo:IAO_0000115` otherwise), the count is still 43, and no term is
defined in the wrong property for its kind.

**It is not a rendering defect.** `smn:Run`, at
`ontology/modules/02-observation-measurement.ttl:99`, carries a label, a
superclass and `rdfs:isDefinedBy`, and nothing else. Its entry in
`docs/index-en.html` shows exactly those three.

**The gap was counted and never filed.** The ontology repository's
`docs/annotation-gap-ledger.md` records "Missing definitions: **43**" under
*Current status (2026-05-13)*. Its list and the 43 measured here are the same
terms. Five of its module-02 entries now sit in module 07 as SKOS concepts,
moved there by the 2026-08-13 methods-as-SKOS migration.

The hub's `knowledge/plans/2026-08-12-ontology-alignment-pass.md` cites the
ledger's count among the things S9 step 1 would fix. No queue item was ever
filed, and `S-09`'s condition does not mention definitions, so the stream could
close with the gap still open.

Nothing in the build reads the ledger. The one check that asserts a definition
exists is `require_term_annotations()` in
`scripts/verify_year_age_semantic_contract.py`, which calls itself "the
repository's minimum human-facing annotation contract", and it runs only on the
terms that script names. That is why `B-231` exists alongside `B-232`: the count
stayed at 43 for four months in a file nothing checks.

**Why the ledger could not simply be worked through.** Its ground rules forbid
inventing a definition. Its 2026-05-13 backfill note says there was no usable
wording for these terms in the three sources it checked: the prior GCDFO
release, the RDA case-study sheet and the Hakai GraphML source. So `B-232` is
source work before it is ontology work. The commons is where that work belongs:
the roadmap's census of `salmon-knowledge-commons`, taken 2026-08-18, lists a
run-timing card among its eleven concepts, none of them human-verified at the
time.

**The cost reaches metasalmon.** Its smn retrieval takes a candidate's
definition from `iao:0000115`, `skos:definition` and `rdfs:comment`
(`R/term_search_smn.R:302`, the same line on `b456201` and on `main`
`f6cd22a`). `.smn_role_flags()` draws part of its role evidence from that text
(`:161`). For these terms it has a label and nothing more.

**Terms another item already touches.** Four of the 43 are also in other items:

- `B-108` deletes `smn:NCBITaxon_8018`, which therefore needs no definition.
- `B-108` also removes the range pins on `smn:observedTaxonFamily` and
  `smn:observedTaxonSpecies`. Both terms survive and still need definitions.
- `B-107` changes `smn:Characteristic`'s superclass. It also survives and still
  needs a definition.

`smn:Run` cannot be defined until `Q-61` is ruled, because smn uses the word
two ways. The measurements are in that question's entry in
[`questions.md`](questions.md) and are not repeated here.

**From the RMIS vocabulary recommendation, 2026-09-23.**

**`B-233` and `B-234`: both SSSOM readers reject canonical SSSOM/TSV.**
The SSSOM specification says the built-in prefixes (`owl`, `rdf`, `rdfs`,
`semapv`, `skos`, `sssom`, `xsd`, `linkml`) may be omitted from a file's
`curie_map`, and that a canonical writer must not include them
(<https://mapping-commons.github.io/sssom/dev/spec-intro/>,
<https://mapping-commons.github.io/sssom/dev/spec-formats-tsv/>). Both
statements were read on 2026-09-23 by the agent that wrote the RMIS
recommendation.

metasalmon's reader looks up every CURIE prefix in the file's own `curie_map`
and aborts with *uses unknown CURIE prefix* when it is absent
(`R/sssom.R:405-409` on `main` `f6cd22a`). Nothing in `R/sssom.R` supplies the
built-in set. metasalmonpy's reader does the same (`sssom.py:595`). The
agent's canonical example mapping set was:

- rejected by `read_sssom_mapping_set(validate = TRUE)` with *uses unknown
  CURIE prefix "skos"*;
- accepted once `rdfs`, `semapv`, `skos` and `sssom` were declared;
- read and validated without error by sssom-py 0.4.21.

This is therefore the only objection. Checked against temporary copies;
metasalmon's working tree stayed clean.

Two related notes, neither filed as its own item:

- metasalmon accepts full IRIs in entity-reference slots (`R/sssom.R:382`),
  which the SSSOM/TSV specification says parsers *should* reject. sssom-py
  accepts them too.
- metasalmon requires `mapping_cardinality` on every `sssom:NoTermFound` row.
  SSSOM only fixes the value (`1:0`) when the slot is filled, so this is
  stricter than the specification but harmless.

**`B-235`: `HUB.md` contradicts its own writes register in thirteen places.**
Found on 2026-09-24 by the agent trimming `HUB.md` for length, reading the file
on `main` at `7bfc3ca`. Sections are named rather than line-numbered, because
line citations into this file have gone stale three times. None of these was
fixed in the trim, which changes no rule.

- **A.** *What you must never do*, the pull-request bullet, says R16 permits
  "three further things and nothing more" on an agent's pull request. The
  register has since added the "@codex review" trigger and the description
  correction, and the same list's API bullet counts eight writes.
- **B.** *The standing authorization*, "Three more operations", merge bullet:
  "never in another member repository even one Brett works alone in; and never
  the agent's own hand-back draft". This contradicts the approved-merge row
  (R16), the `excludes` of the merge-in-this-repository row, and the
  never-list's merge bullet.
- **C.** "That is the whole grant.", after the quoted grant, predates R15, R16
  and the 2026-09-23 upkeep rows. The register governs.
- **D.** *Hand back*: "The item stays unclaimable until Brett merges." Since
  R16 agents merge delegated pull requests too. The `done` state was widened;
  this sentence was not.
- **E.** *Reporting*: "an agent may not write an issue comment at all". The
  "@codex review" trigger is a permitted issue comment.
- **F.** The merge-in-this-repository row (R15) requires only green checks.
  The approved-merge row, the never-list and *Delegated* also require a
  completed Codex review, and *Delegated* adds two more conditions. metasalmon
  is solo, so both rows apply to it, and the R15 row is the looser.
- **G.** `writes.denied` lists six pull-request operations. Neither the
  "@codex review" comment nor the CI re-run is among them. If either counts as
  a pull-request operation, the entry denies what two upkeep rows permit.
- **H.** `scope_note` and `self_suspends` cover writes "against a claimed queue
  item". Merges, promotions and small pushes to `main` are usually not made
  against a claimed item, and `reinstated_2026_09_23` already treats writes on
  unclaimed pull requests as out of scope. So whether those rows, and a breach
  of them, fall inside the register at all is unclear.
- **I.** The draft-pull-request row's `enforced_by` says it is "the one
  permitted operation with no client check behind it". Eleven rows now say
  "nothing mechanical".
- **J.** Class 5 says the parity fact's three copies "have disagreed twice".
  `AGENTS.md` records four.
- **K.** The `review` state reads "Work is pushed and handed back". A
  hand-back in a shared repository pushes nothing. This is the governance call
  already on Brett's decisions page.
- **L.** The small-push row calls "small and mechanical" "a judgement". The
  body says the phrase "is enumerated rather than left to judgement".
- **M.** The draft-pull-request row's `shape` and *Hand back* both say a pull
  request in a class reserved to Brett "stays a draft, unmerged and
  unanswered". The reply-to-a-review-comment row has no class exception, so it
  permits answering Codex on that draft. Practice on 2026-09-24 followed the
  reply row: B-179's metasalmonpy #39 and B-187's #156 answered Codex on
  reserved drafts, so that Brett reviews a change Codex has already passed.
  Added to this list on 2026-09-24, found by B-179 and B-144's workpads.

Two trivial ones ride along. `.hub/agent-brief.md` is said to live "beside
this file", but it is under `.hub/`. `self_suspends` says "the reinstatement
above", in the singular, and there are now two. The field list's omission of
`severity` and `stream` is the same finding as Q-52 and is tracked there.

**`B-236`: no sdp release tag carries the ruled temporal pattern.** Brett ruled
on 2026-09-23 that B-198's remote pin names a tag ("B198: Switch to a tag"). On
2026-09-16, smn-data-pkg's only tags were `sdp-0.2.0` and `sdp-0.3.0`, and the
Q-51 commit `f86d9b4` was sixteen commits ahead of `sdp-0.3.0`. So B-198 and
B-199 were waiting on a tag nobody owned. The Codex review of pull request 150 found the
gap. B-236 was filed to own the tag, and this change added it to both items'
`blocked_by`. The name and the act are Brett's.

**`B-223` narrowed, and `Q-62` filed.** B-223 changed R's semantic closure reader
along with the two EML paths. On that path metasalmonpy falls back to the default
paths rather than refusing. So B-223 would have closed while leaving an
unrecorded difference, as the Codex review of pull request 150 pointed out. This
change gave the closure path to Q-62.

**`B-237`: `smn:Run`'s definition gets its own owner.** B-232 counts a term as
accounted for when its meaning waits on a ruling, and Q-61 said the definition
would be "written under B-232" afterwards. B-232 can retire first. If it does,
nothing owns the definition once Q-61 is ruled. The Codex review of pull request
150 found the gap. B-232's condition was changed to require every term deferred for a
ruling to have an item, sequenced after that ruling, that owns its later
definition. B-237 was filed as that item for `smn:Run`.

**`B-238`: the research behind B-232's definitions gets a commons owner.**
B-232 writes a definition for every undefined local smn term, each from a source.
Establishing what a term means is durable salmon knowledge, which AGENTS.md sends
to the commons, but B-232's condition let it retire with that research recorded
only in ontology annotations. One item cannot finish work in two repositories, as
the Codex review of pull request 150 pointed out. B-238 was filed to own the commons
cards, and this change sequenced B-232 after it and made B-232's condition cite
each card by commit.

**`B-239`, and three follow-ups from the next review round.** B-238 counted a
term deferred for a ruling once its card stated the question, but after the
ruling nothing in the commons would have owned changing the card. B-239 was filed
to own that for `smn:Run`, sequenced after Q-61, and B-237 was sequenced after
B-239 and made to cite the updated card. This change also made B-237 delete
`smn:Run`'s row from B-231's exemptions file when it adds the definition, so the
guard is not left suppressing a term that has one, and made B-198 and B-199
re-vendor from the exact tag B-236 creates, the ref the remote pin names, rather
than from `f86d9b4`, so online and offline sessions cannot load different
bundles.

**Exemption rows retire with their terms.** B-231 was written to seed an
exemption for every local smn term undefined when it lands, and B-232 to empty
the list. Only B-237 said to delete its row, so B-232 could have defined every
other term and left its row in place, and a later loss of that definition would
have passed the guard. B-108 was in the same position for `smn:NCBITaxon_8018`.
The next Codex review of pull request 150 found it. This change made B-231's
check fail on a stale row, one whose term has a definition or is no longer a
local term, and made B-232 and B-108 each delete their rows in the change that
defines or removes the term.

**The whole bundle, not one schema.** B-198 and B-199 asked for a re-vendor
of `dataset.schema.json` only, but each package's remote fetch loads eight files:
six metadata schemas, the profile and the rules. So the pin could have moved to
B-236's tag while the fallback kept stale copies of the other seven. This change
made both re-vendor the complete bundle from the tag, commit a manifest of each
file's SHA-256, and test the vendored files against it. The Codex review of pull
request 150 found it.

**Two more owners.** B-238 required a commons card proposing definition
wording for every term in B-232's scope, which no card can do for
`smn:NCBITaxon_8018`, since B-108 deletes it. This change let a term that an open
item deletes go without a card, accounted for by naming that item. Q-61 could
have retired on the ruling alone, while options (b) and (c) need ontology work
B-237 did not own; this change made its retirement wait on an owner for every
consequence of the chosen option, including a commons gap for a newly minted
concept. The Codex review of pull request 150 found both.

**Three sequencing fixes from the same review.** A ruling decides the shape of
three items: Q-54's temperature ruling decides B-128's request shape, and Q-53
decides which schema B-204's and B-205's pattern check enforces. So this change
added each question to its items' `blocked_by`, which is where the live
dependency is kept; this paragraph records why it was added, not whether it
still holds. This change also moved the closure-path difference in the
roadmap's B-142 passage from B-223 to Q-62.

**A minor tag carries its own profile path, and this section keeps no blocker
state.** B-236 could have retired on an `sdp-0.4.0` tag cut on a commit whose
profile still said v0.3, and B-198 and B-199 would then have pinned a release
that claims a version its own profile does not carry. This change made B-236's
condition put the profile move in the release pull request whenever the name is a
new minor. Separately, several paragraphs above said an item "now waits on"
another, which restated the live `blocked_by` field in prose that nothing
checks; this change rewrote them to record what each change did and why. The
Codex review of pull request 150 found both.

**Three more owners from the next review.** Publishing a v0.4 profile freezes
v0.3, whose schema URLs are unversioned, and keeping a frozen profile's schema
bytes is B-208's subject; so a minor release depends on B-208 where a patch does
not. This change recorded that dependency in B-236's condition, because B-236 is
where the minor-or-patch answer is made. Q-53, Q-54, Q-62 and Q-63 each let a
ruling that keeps a difference retire only once both parity registers had been
written, which no metasalmon item can do; this change rewrote each to ask for a
pair of register items, one per repository. Under Q-61's option (c) the commons
gap entry had no runnable owner, since B-239 was blocked on Q-61 and owned only
`run.md`; this change gave B-239 the gap entry and tied Q-61's retirement to its
owners being filed. The Codex review of pull request 150 found all three. `B-235`
also gained a thirteenth passage, *M*: `HUB.md` says a reserved pull request
stays "unanswered" while the reply row lets agents answer Codex on it.

**Q-61 moved to metasalmon, and B-232 to one pull request.** Q-61 was
declared `repo: salmon-domain-ontology`, but retiring it meant recording a ruling
in `knowledge/questions.md` and filing queue items, both writes in this
repository, and its ontology consequences already had their own items; this
change moved it. The Q61 entry in `questions.md` had copied Q-61's retirement
rule and owner mapping; this change pointed it at the item instead and dropped
from Q60's owner line the dependency it had restated. B-232 allowed several pull
requests, which one claim cannot produce; this change made it one pull request
with a commit per module. The Codex review of pull request 150 found all three.

**The profile path, the validator cards, and this section's tense.** Under a
minor tag, B-198 and B-199 could have moved the pin and re-vendored every file
the loaders request while `.ms_sdp_profile_path()` (`R/schema-helpers.R:71-73`)
and metasalmonpy's `SDP_PROFILE_PATH` went on naming the v0.3 profile, so both
packages would have pinned the new tag and loaded the frozen profile. This change
made both cards move the profile path with the pin under a minor name. Q-53 had
been added to B-204's and B-205's `blocked_by`, but both conditions still named
the vendored file, and Q-53 can rule for a remote-first validator; this change
made recording Q-53's ruling include updating both cards to the schema copy it
selects, and took the copy out of their conditions until then. The same review
found that the paragraphs above restated live conditions of B-236 and of Q-53,
Q-54, Q-62 and Q-63; this change rewrote the section in the past tense. The
Codex review of pull request 150 on `7daeea6` found all three. Separately, B-201's
sentence that the metasalmonpy `v0.5.0` tag was still Brett's to make was
corrected, because the tag was made on 2026-09-24 on `67fb486`; the Codex review
of metasalmon pull request 159 found it.

**Q-54's ruling owns B-128's condition too.** Q-54 asked its temperature ruling
only to say what becomes of B-128, whose condition assumes R's chat path keeps
sending a temperature, so a ruling to send none could have retired Q-54 and
unblocked B-128 with a condition the ruling contradicts. This change made
recording that ruling update, replace or retire B-128, as Q-53's does for B-204
and B-205, and added the same pointer to B-128. The Codex review of pull request
150 on `462cf5f` found it.

**Q-54 gained reasoning effort, and B-234 the redefinition rule.** B-128's routing
would make R's chat path send a reasoning effort resolved from the environment,
which neither chat path sends, and Q-54 listed four differences without it; the
measurement under Q-54 above found two more on semantic review. This change added
reasoning effort to Q-54 as a fifth difference and made B-128 follow that ruling
too. B-233 rejects a `curie_map` entry redefining a built-in prefix if the SSSOM
specification forbids it, and B-234 did not, so the halves could have landed with
different accepted sets; this change gave B-234 the same conditional rule. The
Codex review of pull request 150 on `e03fd35` found both.

**The two questions entries followed their items.** The Q53 entry in
`knowledge/questions.md` named only B-204 as the card whose pattern check the
ruling decides, and the Q54 entry listed four differences. This change made Q53
name B-204 and B-205 and leave how the ruling reaches them to `Q-53`, and made
Q54 list reasoning effort and its effect on B-128. The Codex review of pull
request 150 on `0fdc5a5` found both.

**B-223's direction became Q-62's to rule, and Q59 stopped copying a plan.**
B-223 recorded R moving to refusal on the EML and KNB reads as a default Brett
had been offered and had not overruled, which read the absence of an objection
as a ruling on which side of a divergence moves. This change widened Q-62 from
the closure path to both readers of the EML sidecar, added Q-62 to B-223's
`blocked_by`, and made recording Q-62's ruling update, replace or retire B-223.
The Q59 entry in `knowledge/questions.md` had copied the implementation plan on
B-177's card; this change pointed it at B-177 and B-230 instead. The Codex
review of pull request 150 on `4d84682` found both.

Every paragraph in this section records what a change made on 2026-09-23 or
2026-09-24 did, and why. The conditions in force are in the item files under
`queue/items/`, and where the two differ, the item file is right.

### The 2026-09-25 queue sweep

**What the 2026-09-25 runs found and did not absorb, filed as `B-246` to
`B-277`.** Each entry is headed by its queue ids. **State, severity and each
item's condition live in `queue/items/` and are not restated here**: this
section is what those items' `evidence:` pointers resolve to. It holds the
measurements, meaning what was observed, on which tree and by whom, and for each
item the reason its severity was proposed, given without the value.

**Where a number comes from is part of the number.** Each measurement is cited
to the run that took it and the tree it ran on, and every workpad cited is on
its repository's `main` unless a pull request is named. This sweep's own runs
used Python 3.11.15 with pandas 3.0.5, requests 2.33.1 and PyYAML 6.0.1,
against `git archive` exports of metasalmonpy imported from a directory named
`metasalmonpy`: `main` at `f1f7230`, its tip when this was written, and
`012d04b` for two probes whose modules are identical on both commits. It ran no
R. Every statement below about R code that is not cited to a run was read on
metasalmon `main` at `e9c377e`, and says so. The sweep's scripts were scratch
files and are not committed.

**From the B-219 and B-220 runs** (metasalmon pull request 165, metasalmonpy
pull request 45).

**`B-246` and `B-247`: the `REVIEW:`-marker cases the two fixes left open.**
B-219 and B-220 moved `accept_suggestion()`'s non-empty check after the marker
strip on the `iri =` path. Four neighbouring cases are open.

- *A shortlisted candidate whose `iri` is only the marker.* In R, measured by
  the B-219 run on its branch with the fix: `review_semantics()` queues the
  candidate, because its `has_iri` filter tests only that the value is not
  blank (`R/review-console.R:294`), and `accept_suggestion(rank = 1)` records
  `decision_iri` `""`, because the refusal runs only when `iri` was passed
  (`:992`). In metasalmonpy, measured by this sweep on `f1f7230` with a
  one-candidate review built from the test module's `_suggestion_row()`: for
  `"REVIEW:"`, `"REVIEW: "` and `"review:"` the candidate is queued and
  `accept_suggestion(..., rank=1)` records `decision_iri` `''`, while
  `"REVIEW:"` passed as `iri=` is refused, which is B-220's fix. The `keep`
  mask there tests only that the text of `iri` is not empty
  (`review_console.py:577-581`). No producer in either package writes such a
  candidate, so a hand-edited or external suggestions table reaches it.
- *Replaying a recorded accept of such a row.* In R, measured by the B-219 run:
  a recorded `accepted` row whose `iri` is only the marker replays with an empty
  `decision_iri`, through `.ms_review_seed_recorded_decisions()` (`:128`). In
  metasalmonpy it was read and not run: `_review_seed_recorded_decisions()`
  sets `decision_iri` from `_strip_review_iri()` of the row's `iri` in the same
  way (`review_console.py:488`).
- *A doubled marker.* In R, measured by the B-219 run on `main` `6f4c1e8` and
  unchanged by its fix: `iri = "REVIEW: REVIEW:"` records `decision_iri`
  `"REVIEW:"`, because `.ms_strip_review_iri()` removes one leading marker
  (`R/package-helpers.R:3782-3789`). In metasalmonpy, measured by the B-220 run
  on `85ebbb0` and on `acf243e`: `iri="REVIEW:REVIEW:"` records `"REVIEW:"`,
  against the docstring of `_strip_review_iri()`, which says *"`REVIEW:` never
  survives a decision"*.
- *A row with an empty `iri`, reported as a field the review cannot decide.* In
  metasalmonpy, measured by the B-220 run on `85ebbb0`: once the B-220 defect
  had recorded an accept with an empty `iri`, the next `review_semantics()`
  printed *"Some suggestions target fields this review cannot decide, and are
  not queued"*, naming `column_dictionary.csv · term_iri`, a field the review
  does decide, and *"Edit those in the metadata CSVs directly."* The `keep`
  mask drops such a row together with the rows that have no write-back address,
  and one message lists them all (`review_console.py:577-598`). In R it was
  read and not run, and has the same shape:
  `keep <- writable & iri_field & has_iri` (`R/review-console.R:295`), with
  every dropped row listed under the same message (`:299-313`). A package the
  B-219 or B-220 defect already wrote carries such a row, so it prints this on
  every review.

Which spellings count as the marker is `Q-63`'s. The B-220 run measured the two
strips against each other for it, and that table is Q-63's evidence rather than
these items'.

*Why this severity:* ordinary use reaches none of the four. The first three need
a hand-edited table or a doubled marker typed by hand, and the fourth needs a
package an earlier defect wrote. But three of them record a decision that names
no term, and the fourth misdirects the user on every review of such a package.

**From the B-56 run** (metasalmon pull request 164).

**`B-248`: the per-call costs listed beside #56.** The #56 entry above lists a
cluster of smaller per-call costs beside the per-row retrieval map, and B-56
retired on the map alone. The 2026-08-10 comprehensive review describes them, in
the *Low-value-per-call perf* bullet of its P2 list
(`knowledge/plans/2026-08-10-comprehensive-ecosystem-review.md`). This sweep
read each on `e9c377e`, where each is still there:

- `find_terms()` hands `.score_and_rank_terms()` a fresh `.iadopt_vocab()`
  (`R/term_search.R:367`), which reads `inst/extdata/iadopt-terminologies.csv`
  (`:1915`) and calls `httr::parse_url()` once per row (`:1918`);
- `.score_and_rank_terms()` calls `.role_preferences()` (`:2289`), which reads
  `inst/extdata/ontology-preferences.csv` (`:1950`);
- its ontology-preference scoring calls `grepl()` once for each candidate row
  and preference row (`:2374-2395`, the call at `:2383`);
- target discovery in `R/semantic-suggestions.R` calls
  `non_measurement_roles()` for every dictionary row (`:881`), whose helpers are
  each handed the whole dictionary or code table, and finds a code row's parent
  by scanning the whole dictionary for every code row (`:933`).

The first two happen on every `find_terms()` call. The review's sixth cost,
context chunks re-tokenized per target, runs only when an LLM is asked and is
not in #56's list. Nothing was timed: the review called these costs
"individually small, but they multiply by the target count", and no run has
measured them on a real package. metasalmonpy was not measured.

*Why this severity:* the output is right, and the cost is unmeasured. A
measurement on a real package showing that it matters is the evidence for
raising it.

**From the B-216 run** (metasalmonpy pull request 46).

**`B-249` and `B-250`: the recorded-accept marker shares the `source` column
with retrieval.** A recorded hand-picked accept is the value `user` in `source`,
the column that otherwise names the vocabulary a candidate came from, in both
implementations: `.ms_review_hand_picked_source()` and
`.ms_review_is_hand_picked()` (`R/metadata-write.R:289-304`, read on
`e9c377e`), and `_HAND_PICKED_SOURCE` with `_is_hand_picked()`
(`metadata_write.py:291` and `:306` on `f1f7230`). Each
`detect_semantic_term_gaps()` drops those rows (`R/term-request-helpers.R:115`,
and `term_requests.py` since B-216), so a genuine candidate that a caller's own
`search_fn` labels `user` is lost from gap evidence. Measured by this sweep on
`f1f7230`, on a suggestion table with no `decision` column: a slot whose one
candidate is labelled `ols` gives one gap row, and the same slot with the
candidate labelled `user` gives none. The R half was read and not run; R's
`suggest_semantics()` takes a `search_fn` too. The B-216 run found that
metasalmonpy's `find_terms()` answers only for `smn`, `gcdfo`, `ols`, `nvs`,
`zooma`, `bioportal`, `qudt`, `gbif` and `worms`, so its built-in retrieval
cannot produce such a row; R's was not checked.

**Why keying the exclusion on `decision` does not work**, measured by the B-216
run on its branch: a later accept or reject on the same slot turns the recorded
row's `decision` into `not_selected` or `rejected` and leaves the row in the
file. A detector keyed on `source == "user"` and `decision == "accepted"` then
gave two gap rows where it had given one, with the hand-picked IRI back in
`top_non_smn_iri`. What would separate the two is a marker no retrieval source
can take.

*Why this severity:* it needs a custom `search_fn` that names a source `user`,
and what it causes is a gap row that is missing rather than one that is wrong.

**From the B-215 run** (metasalmonpy pull request 47).

**`B-251`: the "six documents" docstring.** The docstring of
`sdp_schema_fields()` in `sdp_schema.py` says the default `"auto"` source
"fetches six documents over HTTP", and that a scan on a fresh process "waited
out a timeout per document" (`:583` on `f1f7230`). Read by the B-215 run and
again by this sweep: `_fetch_remote_sdp_schema()` (`:435`) requests eight, the
six in `SDP_METADATA_SCHEMA_PATHS`, then the profile, then the rules, which is
also the count metasalmon's B-175 run measured for R. And `_fetch_text()` raises
on the first request that fails, which ends the loop, and `load_sdp_schema()`
falls back on any exception (`:474-477`), so a host that never answers costs one
timeout rather than one per document; that part was read and not run. The
comment the B-215 run replaced said six as well.

*Why this severity:* it is a docstring that miscounts, and nothing behaves
wrongly.

**`B-252`: a field a selected schema drops is still written.** The B-215 run
found it by reading both sides and ran neither under such a schema. This sweep
ran the orchestrator's scratch probe for it, with a selected schema that drops
`dataset` `update_frequency` and `column_dictionary` `constraint_iri`, retrieval
stubbed and the network refused. On `f1f7230`, after the port, `create_sdp()`
wrote `update_frequency` as the last of 24 columns of `dataset.csv` and
`constraint_iri` as the last of 16 of `column_dictionary.csv`, and both columns
were still there after `set_sdp_dataset()` and after `apply_sdp_semantics()`. On
`2405df2`, before the port, the same two columns were written at index 14 of 24
and 14 of 16, their static places; that tree was the orchestrator's scratch copy,
whose `metadata.py`, `sdp_schema.py`, `package_io.py` and `metadata_write.py`
match the commit byte for byte. metasalmon's writers align to the selected
schema's declared columns alone, which was read and not run under such a
schema.

*Why this severity:* the output carries a column its schema does not declare,
but only a schema other than the shipped one reaches it.

**From the B-141 run** (metasalmon pull request 167).

**`B-253`: two contributor-only Markdown pages that nothing ignores.** The
B-141 run measured that pkgdown 2.2.1's `build_llm_docs()` writes a `.md` page
beside each HTML page it renders, and its workpad reports that a build run
without `scripts/build-pkgdown.R` leaves `docs/AGENTS.md`, `docs/CLAUDE.md`,
`docs/HUB.md` and `docs/PULL_REQUEST_TEMPLATE.md` untracked and not ignored,
each carrying the full text of its source. **Measured by this sweep with
`git check-ignore` on `e9c377e`, half of that was covered already:**
`docs/AGENTS.md` and `docs/CLAUDE.md` are ignored by `docs/.gitignore`, which
has listed both since the initial commit, and `docs/HUB.md` and
`docs/PULL_REQUEST_TEMPLATE.md` are not ignored by anything. The root
`.gitignore` lists only the HTML page of each of the four (`:51-59`). The script
deletes all four, so only a build without it leaves them behind.

*Why this severity:* the text is already public in the repository. The risk is
that two pages B-141 kept off the site reach it, and that needs a build without
the script followed by a commit of untracked files.

**From the B-221 run** (metasalmon pull request 166).

**`B-254` and `B-255`: two candidates carrying one IRI in one slot.** Measured by
the B-221 run on a slot with `smn` at rank 1 and no type evidence and `ols` at
rank 2 typed `owl#Class`: `accept_suggestion(rank = 2)`, an apply, a rebuild
with `include_filled = TRUE`, and a second apply.

```
== main 0ff9bff
exact duplicate        rank = 2 writes owl_class; record accepted rows 1,2; replay on rank 1,2; re-apply writes skos_concept; identical FALSE
duplicate + newline    rank = 2 writes owl_class; record accepted rows 1;   replay on rank 1;   re-apply writes skos_concept; identical FALSE
== B-221's branch 81debc7
exact duplicate        rank = 2 writes owl_class; record accepted rows 1,2; replay on rank 1,2; re-apply writes skos_concept; identical FALSE
duplicate + newline    rank = 2 writes owl_class; record accepted rows 1,2; replay on rank 1,2; re-apply writes skos_concept; identical FALSE
```

The record marks every row of the slot whose IRI equals the decision's as
`accepted`, the rebuilt review seeds an accept on each, and the decision the
rebuilt review keeps is the first, so the second apply writes the first
carrier's type. `create_sdp()` keeps both rows when a search returns one IRI
from two sources, so retrieval reaches this. It predates B-221, which changed
neither outcome. metasalmonpy `main` `2405df2` gave the exact-duplicate line
unchanged, also measured by the B-221 run. That was before metasalmonpy pull
request 48 (B-222), whose workpad says it moved where an `iri=` accept is
recorded and left alone what the record and the replay do with a second
carrier; the case was not re-measured after it.

*Why this severity:* re-applying a rebuilt review is meant to write the same
bytes, and here it writes a different `term_type`, in a case ordinary retrieval
produces. The IRI itself is right.

**From the B-152 run** (metasalmon pull request 168).

**`B-256`: `read_github_csv()`'s messages are unreachable.** Read on
`e9c377e`: `ms_github_get()` (`R/github-helpers.R:606-619`) ends in
`httr2::req_perform(req)` with httr2's default error handling, which raises on
an HTTP error status before `read_github_csv()` reads `resp_status()` (`:229`),
so its 401, 403 and 404 branches (`:230-258`) cannot run; `read_github_csv()` is
the only caller of `ms_github_get()`. The B-152 workpad shows both of its
network tests' tracebacks ending in
`httr2::req_perform(req)` at `:618` with *HTTP 404 Not Found*, never at a
`cli::cli_abort()`. The B-176 workpad on `main` records the same two errors as
*HTTP 404 Not Found from `httr2::req_perform()`*, and the B-3 workpad notes, for
another caller, that under httr2 1.3.0 `req_perform()` "already raises on an
error status before it returns". metasalmonpy was read and not run:
`_perform_request()` in `github_io.py` returns a 4xx response rather than
raising (`:128-150` on `012d04b`), so its `read_github_csv()` reaches its own
messages (`:65-83`).

*Why this severity:* the call still fails, but a user reading a private
repository without a token sees an HTTP status where the package wrote them a
remedy.

**From the B-222 run** (metasalmonpy pull request 48).

**`B-257`: a quoted field's trailing newline.** Measured by the B-222 run on one
CSV whose `iri` field is `"https://example.org/ols/SpawnerCount\n"`, quoted:
readr 2.2.0 under R 4.3.3 returns the value with its newline, and
metasalmonpy's `read_sdp_csv()` returns it without. `PARITY.md` row 23 says
that metasalmonpy's `trim_ws` approximates readr's, names one measured mismatch,
a tab before an opening quote, and says every other probed shape in `READR_ROW`
agrees, and row 23 of `parity-deviations.md` says the same. So this second
mismatch is in neither register. The B-222 run left R's trailing-newline test
without a twin, because its premise does not hold in Python.

*Why this severity:* it takes a quoted field that ends in a newline, which is
rare in a package's metadata. Where one occurs, the two readers return different
values from the same file.

**From the B-211 and B-212 runs** (metasalmon pull request 170, metasalmonpy
pull request 49).

**`B-258` and `B-259`: one metadata row twice.** When `column_dictionary.csv`
carries the `spawner_count` row twice, the console prints one `set_sdp_column()`
call that names each of that row's fields twice. Measured in R by the B-211 run
on its branch at `83e5d2a`: *formal argument "column_description" matched by
multiple actual arguments*. Measured in metasalmonpy by the B-212 run on its
branch at `351fed6`: *SyntaxError: keyword argument repeated:
column_description*. Both renderers group gap rows by file, `table_id`,
`column_name` and `code_value` (`.ms_metadata_render_lines()`,
`_render_metadata_lines()`), so the one row per field of each metadata row that
each run added does not reach it. A duplicated key is already a structural
defect, and the setter refuses an ambiguous address; what the runs found is that
the printed call fails before the setter can say so.

*Why this severity:* the input is already invalid, and what goes wrong is the
message a user gets about it.

**`B-260`: a route closed in both packages and pinned in one.** The one row per
field that B-212 put in `add()` also closed a route its item did not name: a
selected schema that marks `column_dictionary.csv` `unit_iri` required, with that
field blank on a measurement row. Measured by the B-212 run with a scratch
script: on `70fa8fd` the field gave two rows, `required` and `iri`, and the
printed call failed with *SyntaxError: keyword argument repeated: unit_iri*; on
`351fed6`, one row, and the call compiled. It pinned nothing, as its workpad and
`CHANGELOG.md` say. The B-211 run measured the same route in R, three rows and
*formal argument "unit_iri" matched by multiple actual arguments* on `643209c`
and two rows, one per metadata row, with both calls running on `83e5d2a`, and
pinned it: the test at `tests/testthat/test-sdp-field-setters.R:804` on
`e9c377e`.

*Why this severity:* both packages behave correctly. What is missing is the
test that would keep one of them correct.

**From the B-192 run** (metasalmon pull request 169).

**`B-261`: the Python guide.** Read by the B-192 run on metasalmonpy `70fa8fd`,
and again by this sweep on `f1f7230`. `guides/semantic-review.qmd` says a row
added for a code-resolved procedure means "the package stops validating"
(`:463`), but the ledger is read only on the export path: `_read_semantic_review()`
is called from `_export_reviewed()` in `eml.py` (`:3578`), and `package_io.py`,
which holds `validate_salmon_datapackage()`, does not mention it. And the guide
says no reviewer ever selected such a procedure as a slot (`:456-457`), but
`review_console.py` lists `codes.csv` among `WRITABLE_FILES` (`:92`). The B-192
workpad has the R vignette's rewrite and the three places it departs from the
Python wording.

*Why this severity:* a reader who trusts the guide expects a validation failure
that never comes, and looks for the refusal in the wrong call.

**`B-262`: two R texts that B-192 did not reach.** Found by the B-192 run and
read by this sweep on `e9c377e`. Step 9 of
`vignettes/post-review-package-publication.Rmd` says strict validation "should
pass only when the package is actually publication-ready" (`:358`), and step 10
opens by saying strict validation is not the publication gate; the B-192 run
measured step 10 right, with strict validation passing on a package both
`write_eml_from_sdp()` and `publish_sdp_to_knb()` refuse. And
`R/semantic-closure.R` calls a code-resolved procedure one "which no reviewer
ever selected as a slot", in its header comment (`:19`) and in the comment above
`.ms_closure_target_context()` (`:473-474`). That is the gloss the B-192 rewrite
avoided, because in R a reviewer can choose a code value's `term_iri`. The
B-192 run judged the roxygen section *The two canonical sets are not one set* on
the same function (`:869`) accurate already; it calls a code-resolved procedure
a vocabulary term and not a review target, without the gloss.

*Why this severity:* a user-facing vignette contradicts itself about the
publication gate from one step to the next.

**From the B-227 run** (metasalmonpy pull request 50).

**`B-263`: two fallback imports.** `validate_semantics()` in `validation.py`
falls back from `from .dictionary import ...` to
`from metasalmonpy.dictionary import ...` under `except ImportError`, marked
`# pragma: no cover - direct module import compatibility` (`:67-70`). The B-227
run found that only the top-level `from validation import` in
`tests/test_validation.py` had run that branch, and that pull request moved the
test onto the package, so nothing runs it now; `git grep` found no other
top-level import. `scripts/validate_sdp.py` falls back from
`metasalmonpy.dictionary` and `metasalmonpy.metadata` to `dictionary` and
`metadata` under `except Exception`, as a "script fallback when executed
directly" (`:6-11`). Reproduced by this sweep on `012d04b`, from the root of the
export with no `metasalmonpy` importable: `python3 scripts/validate_sdp.py
--help` exits 1 with *ModuleNotFoundError: No module named 'dictionary'*,
because a script run directly has its own directory, `scripts/`, on `sys.path`
rather than the root. With the export's parent directory on `PYTHONPATH`, the
same command prints the usage. Neither fallback says what retires it.

*Why this severity:* one branch is dead, and the other fails only for someone
running the script without the package installed.

**From the B-171 run** (metasalmon pull request 171).

**`B-264`: the Python twin of B-171's test.** Read by the B-171 run on
metasalmonpy `25dc7f3` and again by this sweep on `f1f7230`: `_iri_roles()` in
`semantic_closure.py` (`:492`) falls back to role `method` for a measurement IRI
that has no `dictionary_role` row (`:504-507`), as R's `.ms_closure_iri_roles()`
does, and `tests/test_semantic_closure.py` has no `usedProcedure` component, no
observation structure and no `example.org/methods` IRI. Its one set-difference
test, `test_the_two_canonical_sets_differ_and_the_producer_derives_both`
(`:333`), pins the `smn:Observation` direction and asserts that the other
direction is empty in its fixture. On metasalmon's side, the B-171 run's mutation
of the fallback passed the whole suite on `main` and failed the new test on its
branch.

*Why this severity:* the behaviour is the same and right in both packages, and
in the mirror nothing but its construction holds it.

**`B-265` and `B-266`: the closure's address for a code-resolved procedure.**
Measured in R by the B-171 run on its fixture with the plain
`closure_search_stub()`, which does not know the procedures, so both became
gaps:

```
                              unresolved_iri target_scope target_sdp_file
1 https://example.org/methods/expanded-count         code       codes.csv
2 https://example.org/methods/mark-recapture         code       codes.csv
  target_sdp_field table_id column_name code_value target_row_key
1       method_iri                            <NA>
2       method_iri                            <NA>

placement_rationale[1]:
The package asserts this IRI in method_iri and searching smn/gcdfo for it returned nothing, ...

codes.csv columns: dataset_id, table_id, column_name, code_value, code_label, code_description, vocabulary_iri, term_iri, term_type
```

The warning a user sees says `method_iri = https://example.org/methods/...`.
`.ms_closure_target_context()` (`R/semantic-closure.R:478-524`) gives an IRI
with no review target the scope `code`, the file `codes.csv` and the field
`method_iri`, and leaves the table, column, code value and row key empty,
although the IRI sits in a `codes.csv` row's `term_iri` whose table, column and
code value are all known. The only SDP metadata schema with a `method_iri`
column is `tables.csv`'s. metasalmonpy was read and not run: `_target_context()`
in `semantic_closure.py` makes the same choice (`:607-613` on `f1f7230`).

*Why this severity:* the gap and its IRI are right, and the address a term
request would cite is wrong. It is reached whenever a code value's `term_iri` is
a procedure that smn and gcdfo lack.

**`B-267`: the benchmark test outside the setting CI uses.** Measured by the
B-171 run. On a `git archive` export of `main` `d4ffe91`, three
`test-theme-a-benchmark.R` tests error (`:916`, `:1103`, `:1379`), each at
`theme_a_git_value(c("rev-parse", "HEAD"))`, because an export is not a git
checkout. Under a runner started from a script file, twelve of the file's tests
fail identically on both trees that run compared, because
`scripts/theme-a-benchmark.R` locates itself from the path of the script R is
running (`:18-41`, read on `e9c377e`). The file passes on its own under
`Rscript -e`, with 18 tests, none failing and 4 skipped, and that is how CI runs
it, inside a checkout. Neither file has changed since `d4ffe91`.

*Why this severity:* CI is unaffected. The cost is a false failure for a
contributor who runs the suite another way.

**From the B-200 run** (metasalmon pull request 173).

**`B-268`: the sibling checkout in the tarball.** The B-200 workpad records that
R-CMD-check on that pull request reported two NOTEs, on hidden files and
directories and on non-portable file paths, and that every file they list is
under `.metasalmonpy-sibling`, listed as `metasalmon/.metasalmonpy-sibling/...`.
Read by this sweep on `e9c377e`: `.github/workflows/R-CMD-check.yaml` checks
metasalmonpy out to `.metasalmonpy-sibling` inside the workspace (`:60-65`) and
points `METASALMONPY_PATH` at it (`:43`), and neither `.Rbuildignore` nor
`.gitignore` names it, so `R CMD build` packs it into the tarball the check step
checks.

*Why this severity:* unlike a stray local file, which is B-168's case, it is on
every CI run of every pull request, so any genuine NOTE arrives beside two that
readers have learned to pass over.

**From the B-233 run** (metasalmon pull request 162).

**`B-269` and `B-270`: four columns checked as CURIEs.** Read on `e9c377e`:
`R/sssom.R` lists `predicate_type`, `subject_category`, `object_category` and
`similarity_measure` in `.ms_sssom_reference_columns` (`:498-521`), and every
value in those columns goes through `.ms_sssom_validate_reference()` (`:555`),
which refuses a value containing white space and a value that is neither an
unambiguous URI nor a CURIE with a declared prefix (`:416-438`). The SSSOM
LinkML schema on the default branch of the specification's repository, fetched
by this sweep on 2026-09-25, types `predicate_type` as `entity_type_enum`, whose
values are phrases such as `owl annotation property`, and the other three as
`string`, and types every other column in that list `EntityReference` or
`NonRelativeURI`. The B-233 run reproduced the refusal in R on its branch: a
`predicate_type` of `owl annotation property` fails with *"SSSOM predicate_type
in row 1 must be an absolute URI or compact CURIE."* This sweep reproduced it in
metasalmonpy on `012d04b`, with `read_sssom_mapping_set(validate=True)` on a
mapping set that otherwise reads cleanly: `owl annotation property` in
`predicate_type`, `fishing gear` in `subject_category`, `sampling method` in
`object_category` and `Levenshtein` in `similarity_measure` are each refused
with that message for their column, and a control, `https://example.org/tool` in
`mapping_tool_id`, is accepted. `_REFERENCE_COLUMNS` (`sssom.py:198-222`) is R's
list.

*Why this severity:* it refuses valid input, but only in four optional columns,
and a mapping set that leaves them out is unaffected.

**`B-271` and `B-272`: the manifest's specification link.** Both writers put
`https://mapping-commons.github.io/sssom/1.1/` in the manifest's
`provenance.specification` (`R/sssom.R:950` on `e9c377e`, `sssom.py:1046` on
`f1f7230`), and `knowledge/plans/2026-09-14-iop-triple-explainer.md:500` cites
it. Fetched by this sweep on 2026-09-25, that URL answers 404, and so does
`https://mapping-commons.github.io/sssom/1.1.0/`, while
`https://mapping-commons.github.io/sssom/`,
`https://mapping-commons.github.io/sssom/1.0/` and
`https://mapping-commons.github.io/sssom/dev/spec-intro/` answer 200, which is
what the B-233 run found too. The string is part of each manifest's canonical
bytes, and metasalmonpy carries an R-written copy in
`tests/data/sssom/r-sdp/metadata/semantic/mapping-sets.json`, whose checksum
`tests/data/sssom/checksums.json` records.

*Why this severity:* every SSSOM manifest either package writes, including any
deposited with a package, cites a page that does not exist. The mappings
themselves are unaffected.

**From the B-151 and B-242 runs** (metasalmon pull request 153, metasalmonpy pull
request 42).

**`B-273`: the Python floor.** Measured by the B-151 run on metasalmonpy `main`
`3f8349a` under Python 3.9.23: 8 failed, 814 passed and 142 skipped. The
failures call `Path.write_text(newline=)`, which Python added in 3.10, in
`tests/test_sdp_csv_reader.py` and `tests/test_missing_value_contract.py`. Read
by this sweep on `f1f7230`: `pyproject.toml` still says
`requires-python = ">=3.9"` (`:10`), both call sites are still there
(`tests/test_sdp_csv_reader.py:49` and `tests/test_missing_value_contract.py:185`),
and every Python the workflows set up is 3.11 (`parity.yml` and `docs.yml`),
where the B-151 workpad says 3.12. The cause, reproduced by this sweep: under
Python 3.9.23, `Path.write_text("a", encoding="utf-8", newline="")` raises
*TypeError: write_text() got an unexpected keyword argument 'newline'*, and
under 3.10 it writes. The B-242 run did not re-measure it, because every run it
made used 3.11.

*Why this severity:* the package's own code passed the rest of the suite on 3.9.
What fails is the tests, and nothing checks the declared floor.

**`B-276` and `B-277`: a codes row with no code value.** The schema allows a
`codes.csv` row whose `code_value` is empty and whose `vocabulary_iri` is set.
The B-151 run found, as its found item 3, that such a row's slot has no address:
every call printed for it refuses and none decides another slot, in both
implementations, before B-151 and after it. The B-242 run re-measured it in
metasalmonpy at `ff2d557`: the vocabulary row's six printed calls refuse, and
none decides another slot. The B-151 workpad says closing it needs a signature
change or a ruling that such a row gets no semantic target, because the schema
defines `term_iri` as "the specific term that code_value represents". The two
implementations also key such a row's `target_row_key` differently, `NA` in R
and `nan` in metasalmonpy (the B-151 workpad's found item 4, re-measured by the
B-242 run), which is a separate difference and not these items'.

*Why this severity:* a row the schema allows cannot be decided through the
console, but nothing is decided wrongly.

**From the B-55 and B-241 runs** (metasalmon pull request 154, metasalmonpy pull
request 43).

**`B-274`: `code_label`.** Found by the B-55 run on pandas 3.0.5 (its workpad,
found item 3). `apply_salmon_dictionary()`'s codes block calls
`rename_categories` on a `Series` rather than on its `.cat` accessor, and the
`AttributeError` falls into the `except Exception` branch marked
`pragma: no cover - defensive`, which turns the column into strings, so every
codes application takes that branch. The `column_role == "categorical"` block
after it rebuilds the categories from the code values, so once the labels are
applied that block would blank every labelled value. And
`test_apply_salmon_dictionary_with_codes` asserts that the categories are the
code values (`tests/test_dictionary.py:62` on `f1f7230`). The B-241 run found a
second symptom: a Categorical of integers `[1, 2, 3]`, with integer code values
`[1, 2]` and `column_role` `categorical`, came back `[nan, nan, nan]`, the
listed values blanked too, with a warning naming only `3`. Re-measured by this
sweep on `f1f7230`: code values `N` and `W` with labels `Net` and `Weir` give a
categorical whose categories are `N` and `W`, with no warning, so the labels are
still never applied. The integer case was not re-measured in the B-241 run's
shape. With `value_type` `string`, the same input comes back all missing, with a
warning naming all three values, because the column becomes text before the
codes are matched.

*Why this severity:* every coded column loses its labels without a word. The
case that also loses listed values needs integer code values, which a code
table read from a package does not have, because `read_sdp_csv()` reads text;
that last point was read, not run.

**`B-275`: the coercion warning.** The B-241 run's found item 3: metasalmonpy's
non-strict coercion warning names neither the column nor the values, where R's
names both. Re-measured by this sweep on `f1f7230`, with `"1"` and `"x"` in a
column typed `integer` under `strict=False`: *Coercion to integer failed;
keeping as string*, from `dictionary.py:822`. R's, read on `e9c377e`: *Failed to
coerce column ... to ..., keeping as character*, with an `i` bullet that counts
and names the values that cannot be read (`R/dictionary-helpers.R:1704-1707`).
The column has been named since the initial commit, and the values since
B-55's `03a9e22`.

*Why this severity:* the column is kept, as text, and the user is warned; only
the warning cannot say where.

Every paragraph in this section records what was observed, where and by whom,
on 2026-09-25. The conditions in force are in the item files under
`queue/items/`, and where the two differ, the item file is right.

## B-338: a hand-back shown in chat has no claim record (filed 2026-09-25)

**`B-338` `hub done` has no hand-back for a shared repository.** `HUB.md` step 7
says that in a member repository somebody other than Brett has contributed to,
"the branch is never pushed at all and the hand-back is a diff plus a pull
request draft shown in chat". The same paragraph then says to pass `hub done`
the branch you pushed. The client requires one: `scripts/hub` exits with "done
needs --branch, naming the branch you pushed" when `--branch` is missing, and
refuses any name other than `agent/<queue-id>/<token>`. So in the shared case
there is no honest way to record the hand-back. Passing the expected name
records a remote branch that does not exist, and skipping `hub done` leaves an
ordinary claim to expire. Read, not run.

Found by the Codex review of pull request 184 on `8745c0d`. That pull request
rewords the `review` state, on Brett's 2026-09-25 ruling, as "Handed back —
pushed where the grant covers a push, shown in chat where it does not". The
reword describes the chat case honestly, and this item gives the client a way
to record it. Until then, step 7 tells the agent to keep the claim alive with
heartbeats while Brett answers in chat.
