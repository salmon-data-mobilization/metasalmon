---
type: InformationObject
title: "ROADMAP — salmon data ecosystem hub"
description: "The single sequencing authority for metasalmon and the six-repo salmon data ecosystem: what next, in what order, blocked by what — plus the cross-repo release index."
status: draft
tags: [roadmap, sequencing, releases]
psc:
  id: metasalmon:roadmap
  contexts: [metasalmon:context:hub-coordination]
---

# ROADMAP — salmon data ecosystem hub

**This is the single sequencing document for metasalmon and the salmon-data
ecosystem around it** — the coordinating hub for the six repos in the
[domain card](domains/salmon-data-ecosystem.md). It answers *what order, what
blocks what, and what is the current state*, and it carries the cross-repo
**release index**. It deliberately does **not** carry design detail: every
stream links to a sequence card under `sequences/` and every sequence card
links to an execplan under `plans/` before implementation starts.

Undated on purpose. Dated documents accumulate and then compete for authority.

## How to use this bundle

| Document type | Answers | Lives at | Dated |
|---|---|---|---|
| **This roadmap card** | What next, in what order, blocked by what; current releases | `knowledge/roadmap.md` | No — edited in place |
| **Sequence card** | One stream's scope, dependencies, and status | `knowledge/sequences/` | No — edited in place |
| **Execplan** | How to do one stream, in detail | `knowledge/plans/` | Yes — a record of a decision at a time |
| **Backlog** | Every known defect and improvement, with evidence | [backlog.md](backlog.md) | No — the live index |

Rules that keep this from decaying:

- A stream **must** link to an execplan before implementation starts.
- When a stream ships, record the outcome in its sequence card in one or two
  lines and leave the detail in the execplan. Do not grow cards with narrative.
- Item numbers (`#43`, `#48`, …) always refer to [backlog.md](backlog.md).
- **Release-index refresh:** other agents release in sibling repos without
  writing here, so any agent touching this bundle checks the index below
  against the repos' own version sources and fixes drift.
- **Mirror rule:** metasalmonpy mirrors metasalmon — same functionality, same
  version numbers, bumped only when parity actually lands. Stated firmly in
  both repos' `AGENTS.md`; the catch-up is
  [S10](sequences/s10-metasalmonpy-parity.md).

---

## Release index

Compact, hub-maintained. Each repo's own changelog/release page stays
authoritative; this index coordinates. Verified 2026-08-13.

### metasalmon (R) — current **0.3.0**

| Version | Date | One line |
|---|---|---|
| 0.3.0 | 2026-08-15 | **Breaking:** sdp-0.3.0 implemented — dictionary swaps `method_iri` for `statistical_modifier_iri`, registry removed, `migrate_sdp_methods()` stop-and-report migration, semantic pipeline reviews the statistical-modifier slot, remote schema source pinned to spec tags |
| 0.2.6 | 2026-08-12 | Tidy-data enforcement: primary-key uniqueness, wide-format warning, placeholders surfaced |
| 0.2.5 | 2026-08-12 | Credential redaction covers qualified `*_token` names; duplicate redactor deleted |
| 0.2.4 | 2026-08-11 | **Breaking:** canonical CSV missing-value token is the empty field |

Recorded in `DESCRIPTION` + `NEWS.md` + tags/GitHub releases.
**Discrepancy:** tags and GitHub releases stop at v0.1.8 (2026-08-05) —
0.2.0–0.2.6 are untagged (S6 governance item).

### metasalmonpy (Python mirror) — current **0.1.6** (= metasalmon 0.1.6 parity)

| Version | Date | One line |
|---|---|---|
| 0.1.6 | 2026-07-29 | Parity with metasalmon 0.1.6: `create_sdp` workflow, opt-in semantic review, term-gap detection |
| 0.1.3 | 2026-05-13 | Parity with metasalmon 0.0.13: SDP CSV IO, inference, EDH export |
| 0.1.2 | 2026-02-06 | Initial: GitHub CSV helpers, metasalmon 0.0.5 parity |

Renamed from `metaSmnPy`/`salmonpy` on 2026-08-13. Versions are **parity
claims** — catch-up to 0.2.6 is [S10](sequences/s10-metasalmonpy-parity.md).

### salmon-domain-ontology (smn) — current **0.0.3**

| Version | Date | One line |
|---|---|---|
| 0.0.3 | 2026-08-14 | The alignment-pass release: imported W3C SOSA–PROV alignment, CONVENTIONS §5b + CI gates, methods as SKOS, `StatisticalModifierScheme`, `EscapementEstimate`; first release with a correct single ontology identity in the flat serializations |
| 0.0.2 | 2026-08-04 | Year, age-basis, and abundance modelling |
| 0.0.1 | 2026-03-29 | Abundance terms (PR 17) — snapshot only, never tagged/released |

Released via `make release VERSION=X.Y.Z` → immutable `docs/releases/` snapshots
+ tags + GitHub pre-releases. **Discrepancies:** 0.0.1 has a snapshot but no
tag or GitHub release; the 0.0.0–0.0.2 flat serializations declare module 01's
IRI as the ontology (generator defect, fixed from 0.0.3; immutable snapshots
keep the historic shape).

### dfo-salmon-ontology (gcdfo) — current **0.0.8**

| Version | Date | One line |
|---|---|---|
| 0.0.8 | 2026-03-29 | Enhancement-status vocabulary, RemovalReference, abundance data-type classes |
| 0.0.999 | 2026-01-30 | Pre-1.0 "beta" versioning adopted; JSON-LD docs pipeline |
| 0.0.2 | 2025-01-07 | Initial structure, SKOS schemes, ROBOT toolchain |

Recorded **only** in `CHANGELOG.md` + `owl:versionInfo` — zero tags, zero
GitHub releases. **Discrepancies:** the sequence is non-monotonic (0.0.999
predates 0.0.8), and the `[Unreleased]` section now also carries the merged
S9 step-3 boundary work (the 32-row SSSOM set, duplicate-property removal,
re-namespacing, refreshed mirrors — PR #78, merged 2026-08-14). Cutting the
next gcdfo release and fixing the version sequence are S6 item-3 work.

### smn-data-pkg (SDP spec) — current **sdp-0.3.0**

| Version | Date | One line |
|---|---|---|
| sdp-0.3.0 | 2026-08-14 | **Breaking:** methods leave the column dictionary (three placements, no registry); `statistical_modifier_iri` added; frozen-profile versioning (v0.3 URL) |
| sdp-0.2.0 | 2026-08-11 (retroactively dated) | Frictionless-first schemas, v0.2 profile, `sdp.rules.yaml`, canonical `metadata/`+`data/` layout |
| 0.1.1 | 2026-01-14 (malformed in changelog) | I-ADOPT component columns in `column_dictionary.csv` |
| 0.1.0 | 2025-12-21 | Initial specification draft |

The 0.3.0 changelog entry is dated and 0.2.0 got its retroactive dated
entry; `sdp-0.2.0` and `sdp-0.3.0` git tags were cut 2026-08-14 (they carry
metasalmon's pinned remote schema source); GitHub releases remain absent
(S6 item 3 / S1 cross-repo work). **Local checkout note (resolved 2026-08-13):** the dirty
state was abandoned metasmn-rename leftovers — preserved on local branch
`attic/abandoned-metasmn-rename-2026-06`, main fast-forwarded. Note PR #2
added a `methods.csv` registry the S8 method model removes; the port unwinds
it.

### psc-salmon-vocabularies (PSC CV) — current **v0.1.0-alpha.3** (on the fair-mapping branch)

| Version | Date | One line |
|---|---|---|
| v0.1.0-alpha.3 | 2026-08-14 (MR !6 merged) | smn 0.0.3 anchoring: **first psc-to-smn.sssom.tsv** (ten prototype_accepted broadMatch rows), re-pinned source, alignment-gap doc retired |
| v0.1.0-alpha.2 | 2026-07-31 | Prior prerelease vocabulary build (provisional, not an adopted PSC standard) |
| v0.1.0-alpha.1 | 2026-07-31 | First prerelease — tag only, no GitLab Release object |

Byte-pinned `releases/<version>/` dirs with per-artifact sha256 manifests;
GitLab. Review branch: `feature/fair-mapping-products-roadmap`.

---

## metasalmon current state

**Shipped: 0.2.6.** The 0.2.x sequence, all reviewed and CI-green:

| Release | What |
|---|---|
| 0.2.0 | All nine P0 defects — installable again, truthful schema contract, lossless SDP round trip, byte-reproducible artifacts, external text can no longer be a cli template |
| 0.2.1 | #43 last locale-dependence · #62 last hardcoded contract value |
| 0.2.2 | #45/#46/#50 — term-index caches actually prevent work; a failed vocabulary lookup no longer looks like an ontology gap |
| 0.2.3 | #47/#51/#52 — dry runs re-plannable; LLM providers retry and honour `Retry-After`; BioPortal key out of the URL |
| 0.2.4 | #54 missing-value contract · #72 `ms_setup_github()` default · CI optional deps, non-C ambient collation, runnable examples |
| 0.2.5 | #73 credential redaction covers qualified token names |
| 0.2.6 | #77 tidy foundations — primary-key uniqueness, wide-format warning, placeholders surfaced |

**Health invariants.** Hold these at every step; a regression in any of them is
as serious as a failing test, and unlike a failure most will not announce
themselves.

- Suite: **0 failures**. CI skips: **exactly 4** (Theme A integrity, in
  `theme-a-integrity.yaml`). Local: 5, adding the CI-only optional-dependency guard.
- `R CMD check`: **Status: OK**, no NOTEs.
- CI runs under a **non-C ambient collation** (`LC_ALL=en_US.UTF-8`), so the
  byte-reproducibility guards are exercised rather than skipped.
- Two static guards stay honest: any new byte-producing function goes in
  `collation_sensitive_fns`; any new cli call uses literals or the escaping
  helpers. Both contracts are stated in `AGENTS.md`.
- **Mirror invariant:** no metasalmon release ships without its metasalmonpy
  counterpart landing in the same stream (post-S10; during S10, the gap only
  shrinks).

---

## Sequencing

Ordered by *(does it bite a real user today) × (silent or loud)*, then
adjusted for **bottleneck dependencies** — a stream that blocks others
outranks its own bite. Streams that do not block each other run in parallel.
No cost or duration estimates are kept here.

Solid arrows are hard blocks. Dashed are *credibility* dependencies: the work
ships without them, but says something it cannot fully back.

```
#73 redaction ✔ ──► S3 KNB environments ──► S4 workshop rebuild
                                              ▲   ▲   ▲   ▲
S8 method model + tidy ──► S9.2 methods-as-SKOS ──┘   │   │   │
     (#77 → #76)                                  │   │   │
S1 validation authority ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘   │   │
S6 vocabulary release pinning ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘   │
S10 metasalmonpy parity ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘

S9 ontology conventions + alignment ── steps 0–5 ALL done 2026-08-14 (smn
                                       0.0.3 released; gcdfo PR #78 and PSC
                                       MR !6 merged, promotions approved);
                                       remaining: step 6 propagation +
                                       the parked #78 explainer
S2 correctness debt          ── independent
S5 review flow (next minor)  ── independent (#60 → #74 internally)
S7 architecture + curation   ── independent, largest
S11 vignettes + walkthroughs ── slices 1–2 independent; KNB golden path
                                after S3; review vignette with S5;
                                methods vignette after S8
```

Read that as: S3's only hard blocker shipped in 0.2.5; S2, S5, S7, and S10 run
in parallel with everything (S10 is dashed into S4 because the workshop's
Python episodes execute against metasalmonpy). S4 is hard-blocked by S3 and by
**S8** for its method-annotation content. **S8 comes first among the spec
streams**: it decides what the SDP means, S1 then makes the validator enforce
it, and S9 step 2's methods-as-SKOS migration implements the vocabulary half.

### The streams

- [S1 — One validation authority](sequences/s1-validation-authority.md) · #48, #49
- [S2 — Correctness debt](sequences/s2-correctness-debt.md) · #53, #55, #56, #57
- [S3 — KNB staging environment](sequences/s3-knb-staging.md)
- [S4 — Workshop rebuild](sequences/s4-workshop-rebuild.md)
- [S5 — R-native review flow, ships as the next minor at ship time](sequences/s5-review-flow.md) · #58, #59, #60, #74 (0.3.0 is taken by S8, which ships first)
- [S6 — Ecosystem hardening](sequences/s6-ecosystem.md) · #44, #61
- [S7 — Architecture and curation engine](sequences/s7-architecture.md) · largest, last
- [S8 — Method model and tidy foundations](sequences/s8-method-model.md) · #76, #77
- [S9 — Ontology conventions and alignment pass](sequences/s9-ontology-alignment.md)
- [S10 — metasalmonpy parity](sequences/s10-metasalmonpy-parity.md)
- [S11 — Vignettes and user-facing walkthroughs](sequences/s11-vignettes-and-walkthroughs.md) · #79

### Continuous

- **Keep the guards honest.** New byte-producing function →
  `collation_sensitive_fns`. New cli call → literals or the escaping helpers.
- **Watch the skip count**, not just the failure count. CI must report exactly 4.
- **Refresh the release index** whenever drift is noticed.
- **Mirror every metasalmon change into metasalmonpy** (or log why not).

---

## Executed work

Historical records. Read these for *why* something is the way it is; do not
sequence from them.

| Execplan | What it covered | Status |
|---|---|---|
| [post-0.2.0 roadmap](plans/2026-08-10-post-0.2.0-roadmap.md) | Sequencing for 0.2.1–0.2.4 | **Superseded by this card.** Steps 1, 2, 4 shipped; step 3 is now S1 |
| [comprehensive ecosystem review](plans/2026-08-10-comprehensive-ecosystem-review.md) | 96 verified findings across metasalmon, the SDP spec, both ontologies, the workshop | Evidence base for S1, S2, S5, S6 |
| [gcdfo validation layer verification](plans/2026-08-10-gcdfo-validation-layer-verification.md) | Read-only verification of the gcdfo SHACL/SPARQL/ROBOT claims | Complete; fix belongs to S6 |
| [next behaviours roadmap](plans/2026-06-26-next-behaviours-roadmap.md) | Themes A–E | **Superseded for sequencing.** Still the authority for Theme A–E *design detail*; open remnants migrated to S7 |
| [Theme A semantic review](plans/2026-07-28-theme-a-semantic-review.md) | Theme A implementation record | Shipped 0.1.6 |
| [architecture refactors](plans/2026-06-24-deepen-architecture-refactors.md) | R1–R5 architecture refactor | Executed; remnants in S7 |
| [Alice Assmar report](plans/2026-06-24-alice-assmar-metasalmon-report.md) | External review | Absorbed into the backlog |
| [2026-04-02 drafts](plans/2026-04-02-i-adopt-chat-decomposition-draft.md) | Bundle-aware semantic fit; I-ADOPT chat decomposition | Design drafts; routing slices shipped 0.1.3, engine is S7 |

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
