# metasalmon — roadmap

**This is the single sequencing document for metasalmon and the salmon-data
ecosystem around it.** It answers *what order, what blocks what, and what is the
current state*. It deliberately does **not** carry design detail: every stream
links to an execplan that does.

Undated on purpose. Dated documents accumulate and then compete for authority —
which is exactly what happened before this file existed, when two documents in
`notes/exec-plans/` both called themselves roadmaps. Those are now historical
records of executed work (see [Executed work](#executed-work)).

## How to use this file

| Document type | Answers | Lives in | Dated |
|---|---|---|---|
| **This roadmap** | What next, in what order, blocked by what | `notes/ROADMAP.md` | No — edited in place |
| **Execplan** | How to do one stream, in detail | `notes/exec-plans/` | Yes — a record of a decision at a time |
| **Backlog** | Every known defect and improvement, with evidence | `notes/bugs-and-improvements.md` | No — the live index |

Rules that keep this from decaying:

- A stream here **must** link to an execplan before implementation starts.
- When a stream ships, record the outcome **here in one or two lines** and leave
  the detail in the execplan. Do not grow this file with narrative.
- Item numbers (`#43`, `#48`, …) always refer to `notes/bugs-and-improvements.md`.

---

## Current state

**Shipped: 0.2.4.** Six releases in the current sequence, all reviewed and CI-green.

| Release | What |
|---|---|
| 0.2.0 | All nine P0 defects — installable again, truthful schema contract, lossless SDP round trip, byte-reproducible artifacts, external text can no longer be a cli template |
| 0.2.1 | #43 last locale-dependence · #62 last hardcoded contract value |
| 0.2.2 | #45/#46/#50 — term-index caches actually prevent work (~8 CPU-hours → seconds); a failed vocabulary lookup no longer looks like an ontology gap |
| 0.2.3 | #47/#51/#52 — dry runs can be re-planned; LLM providers retry and honour `Retry-After`; BioPortal key out of the URL |
| 0.2.4 | #54 missing-value contract · #72 `ms_setup_github()` default · CI optional deps, non-C ambient collation, runnable examples |

**Health invariants.** Hold these at every step; a regression in any of them is
as serious as a failing test, and unlike a failure most will not announce
themselves.

- Suite: **0 failures**. CI skips: **exactly 4** (Theme A integrity, which run in
  `theme-a-integrity.yaml`). Local: 5, adding the CI-only optional-dependency guard.
- `R CMD check`: **Status: OK**, no NOTEs.
- CI runs under a **non-C ambient collation** (`LC_ALL=en_US.UTF-8`), so the
  byte-reproducibility guards are exercised rather than skipped.
- Two static guards stay honest: any new byte-producing function goes in
  `collation_sensitive_fns`; any new cli call uses literals or the escaping
  helpers. Both contracts are stated in `AGENTS.md`.

---

## Sequencing

Ordered by *(does it bite a real user today) × (silent or loud) × (cost)*, then
adjusted for hard dependencies. Streams that do not block each other can run in
parallel.

Solid arrows are hard blocks. Dashed are *credibility* dependencies: the work
ships without them, but says something it cannot fully back.

```
#73 redaction ──► S3 KNB environments ──► S4 workshop rebuild
                                              ▲   ▲
S1 validation authority ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘   │
S6 vocabulary release pinning ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘

S2 correctness debt          ── independent
S5 review flow + 0.3.0       ── independent (#60 → #74 internally)
S7 architecture + curation   ── independent, largest
```

Read that as: **S3's only hard blocker is #73**, and S1, S2, S5, S6 and S7 can
all run in parallel with it. S4 is hard-blocked by S3 alone. S1 and S6 are
dashed into S4 because episode 8 teaches validation as the final gate and the
KNB documentation names vocabulary pinning as a precondition — the workshop can
ship first, but only with its claims scoped to what is true.

### S1 — One validation authority · #48, #49 · ~2 weeks · **next**

**Execplan:** to be written. Findings: `2026-08-10-comprehensive-ecosystem-review.md`.

metasalmon is the workshop's designated final gate before DataONE deposit, and
the gate under-checks. Confirmed premise: **zero of the 13 rule ids in
`sdp.rules.yaml` appear anywhere in `R/`** — the validator reimplements the spec
by hand, so spec and implementation can diverge silently, and three
error-severity rules are loaded and never executed. `validate_salmon_datapackage()`
additionally checks no declared primary keys, no required-column nullability, no
schema-required metadata fields, and reports success on corrupt
SSSOM/decomposition artifacts.

**Why first:** everything downstream borrows its credibility. S4 teaches
validation as the final gate before deposit; teaching that while the gate
under-checks is the one sequencing mistake worth avoiding.

**The change that stops it recurring:** a conformance test that fails when the
spec declares a rule the implementation does not execute. Drive the checks from
the parsed rule `id`s.

**Cross-repo:** needs `smn-data-pkg` to have a LICENSE, CI, and Pages config, and
the nine prose-only rules expressed machine-readably. The metasalmon-side work is
self-contained; only the *authority* question is shared.

### S2 — Correctness debt · #53, #55, #56, #57 · ~1 week

**Execplan:** to be written.

#53 (four-digit measurement columns classified as `temporal`, removing them from
the whole semantic pipeline) is the one that silently loses meaning; do it first.
#54, the other silent data-loss item in this cluster, shipped in 0.2.4.

Independent of S1 — can run in parallel.

### S3 — KNB staging environment · ~1 week

**Execplan:** [`2026-08-11-knb-environments-and-workshop-rebuild.md`](exec-plans/2026-08-11-knb-environments-and-workshop-rebuild.md)

A guarded `knb_environment = "production" | "staging"` so the workshop — and any
new user — can rehearse a deposit without writing to the production KNB node.

**Blocks S4.** The workshop cannot teach a rehearsal that does not exist, and it
pins an exact released metasalmon version.

**Not blocked by S1**, but see the execplan's *Sequencing* section: shipping S3
before S1 means the staging rehearsal validates with the same under-checking
validator, which is acceptable for a rehearsal and not for the claim "validation
is your final gate."

### S4 — Workshop rebuild · ~2 weeks · repo: `salmon-data-standards-workshop`

**Execplan:** [`2026-08-11-knb-environments-and-workshop-rebuild.md`](exec-plans/2026-08-11-knb-environments-and-workshop-rebuild.md)

Nine episodes, R-led with visible Python equivalents and two interleaved Excel
passes. Depends on **S3** (staging target) and reads better after **S1**.

Once the episodes execute against a released metasalmon, the workshop becomes an
integration test of the public API — which is where stale-call bugs get caught
for free. That is the strategic reason to finish it, beyond teaching.

### S5 — R-native review flow and API hygiene · #58, #59, #60, #74 · ~2–3 weeks · ships as 0.3.0

**Execplan:** [`2026-08-11-r-native-review-and-editing.md`](exec-plans/2026-08-11-r-native-review-and-editing.md)
(#74) · #58/#59/#60 detail in `2026-08-10-comprehensive-ecosystem-review.md`.

**#74 is the headline.** Today the documented review workflow leaves R for a
spreadsheet, and the only record of the most consequential decision in the
pipeline is a mutated CSV — the single unreproducible link in a chain that is
otherwise byte-reproducible and guarded. `review_semantics()` /
`accept_suggestion()` / `apply_sdp_semantics()` make the decision scriptable and
re-runnable.

**Why these four ship together, rather than as a sequence:** #60 (the
`semantic_suggestions` / `semantic_llm_assessments` attributes have no accessor)
is not merely adjacent to #74, it is its **prerequisite** — the review queue has
to read those attributes through a supported accessor. #58 (condition classes)
is breaking for anyone matching on message text and already wants a major bump,
and #74 adds roughly ten exported functions, which wants the same bump. One
0.3.0 story is cheaper than three coordinated releases.

Independent of every other stream. The feature also has a smaller sibling:
**#75**, an auto-applied `method_iri` with no `metadata/methods.csv`, found while
scoping #74 and reproduced — it is fixed by that execplan's slice 2, where
`method_iri` and `methods.csv` ship together.

### S6 — Ecosystem · #44, #61 · ~6 weeks · parallel track, mostly not R code

**Execplans:** [`2026-08-10-gcdfo-validation-layer-verification.md`](exec-plans/2026-08-10-gcdfo-validation-layer-verification.md)
(#44, verified) · remainder to be written per sub-stream.

Highest strategic value, longest lead time, least code. Run alongside S1–S5.
Ordered:

1. **Verify the 27 finder-only ontology findings** — cheap and mechanical.
   #44 already did three and all three held, so expect a high confirmation rate.
2. **Fix #44** so the gcdfo quality gates stop being placebos.
3. **Vocabulary-release pinning** — monotonic versions, real `owl:versionIRI`,
   immutable release snapshots, then thread the resolved release into
   metasalmon's output and the KNB transformation record.
   **metasalmon's own KNB documentation states this as a precondition and it
   cannot be satisfied today**, which makes it a soft dependency of S4.
4. **Publish the `smn:`/`gcdfo:` boundary as data** — one SSSOM 1.1 mapping set
   for the ~55 name collisions, with CI checks in both repos.
5. **Populate the three empty policy schemes** (PA zones, COSEWIC, benchmarks).
   Highest-value single ontology change for real users: today term search finds
   nothing and falls back to `REVIEW:` placeholders.
6. **Fix the I-ADOPT layer** so the decomposition pipeline has a conformant target.
7. **Governance** — machine-readable licence in the TTL, real `CITATION.cff`,
   named editorial authority and review SLA, org-owned URLs, one accurate
   `entrypoints.md` per repo.

### S7 — Architecture and curation engine · #29, #30, #31, Themes C/E · largest

**Execplans:** [`2026-06-24-deepen-architecture-refactors.md`](exec-plans/2026-06-24-deepen-architecture-refactors.md)
(executed part) · [`2026-04-02-i-adopt-chat-decomposition-draft.md`](exec-plans/2026-04-02-i-adopt-chat-decomposition-draft.md)
(design) · Theme detail in [`2026-06-26-next-behaviours-roadmap.md`](exec-plans/2026-06-26-next-behaviours-roadmap.md).

Migrated here from the old Theme C/E sections so it is not lost:

- **Split `package-helpers.R`** (#29, ~3k lines) and move `infer_*_from_resources`
  out of `dictionary-helpers.R` (#30). Public signatures unchanged.
- **Curation session engine** (Theme C1–C3): `start_curation_session()` /
  `run_curation_turn()` / `propose_curation_patch()` / `approve_curation_patch()`,
  a question planner with information-gain ranking, and a structured
  provenance bundle. The routing slices and `chat_decomposition()` shipped in
  0.1.3; this is the follow-on engine.
- **Shared chat request builder** (#3 / Theme E2) — mutually exclusive with the
  adapter's dual-shape normalizer, so do it *inside* the curation work, not
  standalone.
- **Latent cleanups** (#22, #23, #24) — fold into whichever stream touches those
  files rather than scheduling separately.

Deliberately last: it is the largest, and none of the above depends on it.

### Continuous

- **Keep the guards honest.** New byte-producing function → `collation_sensitive_fns`.
  New cli call → literals or the escaping helpers. Stated in `AGENTS.md`.
- **Watch the skip count**, not just the failure count. CI must report exactly 4.

---

## Executed work

Historical records. Read these for *why* something is the way it is; do not
sequence from them.

| Execplan | What it covered | Status |
|---|---|---|
| [`2026-08-10-post-0.2.0-roadmap.md`](exec-plans/2026-08-10-post-0.2.0-roadmap.md) | Sequencing for 0.2.1–0.2.4 | **Superseded by this file.** Steps 1, 2, 4 shipped; step 3 is now S1 |
| [`2026-08-10-comprehensive-ecosystem-review.md`](exec-plans/2026-08-10-comprehensive-ecosystem-review.md) | 96 verified findings across metasalmon, the SDP spec, both ontologies, the workshop | Evidence base for S1, S2, S5, S6 |
| [`2026-08-10-gcdfo-validation-layer-verification.md`](exec-plans/2026-08-10-gcdfo-validation-layer-verification.md) | Read-only verification of the gcdfo SHACL/SPARQL/ROBOT claims | Complete; fix belongs to S6 |
| [`2026-06-26-next-behaviours-roadmap.md`](exec-plans/2026-06-26-next-behaviours-roadmap.md) | Themes A–E | **Superseded for sequencing.** Still the authority for Theme A–E *design detail*; open remnants migrated to S7 |
| [`2026-07-28-theme-a-semantic-review.md`](exec-plans/2026-07-28-theme-a-semantic-review.md) | Theme A implementation record | Shipped 0.1.6 |
| [`2026-06-24-deepen-architecture-refactors.md`](exec-plans/2026-06-24-deepen-architecture-refactors.md) | R1–R5 architecture refactor | Executed; remnants in S7 |
| [`2026-06-24-alice-assmar-metasalmon-report.md`](exec-plans/2026-06-24-alice-assmar-metasalmon-report.md) | External review | Absorbed into the backlog |
| [`2026-04-02-*`](exec-plans/) | Bundle-aware semantic fit; i-adopt chat decomposition | Design drafts; routing slices shipped 0.1.3, engine is S7 |

---

## Two process notes worth keeping

**A green suite was not the signal it looked like.** Three 0.2.0 findings were
invisible to 21k lines of tests because the suite pinned the vendored schema,
never round-tripped a package through its own validator, and skipped tests
silently. All three structural fixes have now landed (0.2.0 and 0.2.4). The
0.2.4 one is the cautionary tale: five tests of the DataONE adapter boundary —
the code that talks to the repository during live publication — had **never
executed on any machine**, and nobody could have known.

**A skip's stated reason can be accurate while the reason it exists is a
defect.** Two CI skips reported, correctly, that a private repository was
unreadable. Asking *why the default pointed there* surfaced #72: an exported
function defaulting to a private dataset repo, so a good token was reported as
broken. Read the reason; then ask why it is true.
