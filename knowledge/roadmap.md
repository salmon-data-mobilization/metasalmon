---
type: InformationObject
title: "ROADMAP — salmon data ecosystem hub"
description: "The single sequencing authority for metasalmon and the seven-repo salmon data ecosystem: what next, in what order, blocked by what — plus the cross-repo release index."
status: draft
tags: [roadmap, sequencing, releases]
psc:
  id: metasalmon:roadmap
  contexts: [metasalmon:context:hub-coordination]
---

# ROADMAP — salmon data ecosystem hub

**This is the single sequencing document for metasalmon and the salmon-data
ecosystem around it** — the coordinating hub for the repos in the
[domain card](domains/salmon-data-ecosystem.md) (seven today; whether that is
the right count is an open decision below). It answers *what order, what
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
  [S10](sequences/s10-metasalmonpy-parity.md). **Amended 2026-08-17 (Brett):
  the mirror is not automatically the follower** — *"don't just make things
  match metasalmon; if the Python implementation got it right, then update
  metasalmon."* Mirroring keeps the two the same and says nothing about which
  is correct, so each divergence is a question about which side is right, and
  R changing is a normal answer rather than an exception. See
  [parity-deviations](parity-deviations.md) row 32 for the first application.
- **Domain allowlist:** the seven rows in the
  [domain card](domains/salmon-data-ecosystem.md) are exhaustive. The seventh,
  `salmon-knowledge-commons`, was added 2026-08-17 (Brett) because its ontology
  gap register is an *input* to this package's term-request pipeline, not an
  artifact the hub consumes — that is the membership test, and the card records
  it. Shared tools, hyperlinks, consumed artifacts, transitive dependencies,
  and a shared GitHub organization do not add a repository to this hub.
  **The card states a *different* test in its closing paragraph, and the two
  disagree** — unruled, recorded as
  [OD-1](#od-1--which-membership-test-governs-and-is-salmon-data-standards-workshop-the-eighth-member).
  Neither test has been deleted and the allowlist is unchanged; apply both and
  report the disagreement rather than picking one.
- **External-edge rule:** an external repository appears here only as a typed
  dependency edge naming its owner, required artifact or gate, owning plan, and
  observation date. Its tasks, priorities, status, branches, approvals, and
  releases remain in its owning plan and never enter this roadmap or release
  index.

### Cross-program authority boundary

- Brett HQ's canonical Semantic PSC Data System Roadmap controls program
  strategy and activation. A roadmap or ExecPlan in this bundle cannot activate
  a PSC implementation child or confer scientific approval.
- PSC draft GitLab
  [MR !5](https://gitlab.com/pacific-salmon-commission/psc-data-systems/psc-salmon-vocabularies/-/merge_requests/5)
  is the repository-scoped FAIR mapping-product dependency specification. The
  released mapping products and decisions remain authoritative in their owning
  semantic-asset repository, not here.
- This hub retains technical sequencing, mirror coordination, and the release
  index for the seven-repository ecosystem. The bounded consumer plan is
  [governed mapping products](plans/2026-08-14-governed-mapping-products.md).
- Brett will coordinate identification of the competent CTC/domain and
  application authorities; that coordination is not their approval. Until
  holders and instruments are recorded, stable/domain-approved mapping meaning
  and output-changing application policy remain blocked.

External dependency edges are deliberately sparse. `Observed` records when the
edge contract was checked, not the external repository's implementation or
approval status.

| External repository | Edge type | Owner | Required artifact or gate consumed by this hub | Owning plan | Observed |
|---|---|---|---|---|---|
| `brett-hq` | Program-activation gate | Brett HQ planning authority | Attributable activation for a named implementation child; HQ remains authoritative for whether the gate is satisfied | `brett-hq/roadmaps/semantic-psc-data-system-roadmap.md` | 2026-08-15 |
| `psc-data-systems` | Validation-tool dependency | P06 and repository maintainers | The PSC OKF profile and `psc-okf` capture-tier validator used to check this bundle; neither is mapping authority | `brett-hq/projects/P06-psc-scientific-data-system-map/project.md` and the repository-local OKF plan | 2026-08-15 |
| `psc-data-systems-site` | Documentation-link handoff | P08 and site maintainers | Optional orientation link to a released PSC vocabulary mapping catalog; no mapping-product implementation gate | `brett-hq/projects/P08-psc-data-systems-documentation-website/project.md` | 2026-08-15 |
| `campModelInput` | Application-consumer handoff | Package maintainer and the competent application authority | Consumes psc-salmon-vocabularies **v0.1.0-alpha.2** as a vendored offline projection (34 CAMP concepts, 52 literal assignments, 22 informational alignments), gated on contract and provenance self-consistency plus semantic structure — **but no longer on artifact byte equality**: runtime checksum enforcement was removed 2026-08-07 (their MR !5) over Windows line-ending failures, so the declared SHA-256s are self-attested from inside the consumer. The pin is current, not stale. Operational policy remains application-owned | `psc-salmon-vocabularies/docs/plans/2026-08-12-fair-mapping-products-roadmap.md` and a future repository-local ExecPlan | 2026-08-16 |
| `ctc-knowledge-map` | Descriptive-evidence handoff | CTC bundle maintainers and eligible reviewers | Evidence-backed description of the released mapping flow; never mapping rows or approval inherited from a release | `psc-salmon-vocabularies/docs/plans/2026-08-12-fair-mapping-products-roadmap.md` and any activated repository-local plan | 2026-08-15 |
| `psc-data-transformations` | **Requirements-driving consumer** (new edge type — see below) | PSC Data Systems; private GitLab under `pacific-salmon-commission/psc-data-systems/` | Consumes this package as a pinned execution engine: `metasalmon` **0.1.8** at revision `886e01d`, alongside psc-salmon-vocabularies **v0.1.0-alpha.2** and salmon-domain-ontology **0.0.2**. It calls internals (`metasalmon:::.ms_eml_validate_mapping`, `metasalmon:::.ms_sdp_profile_version`), so its pin constrains what this package may rename | A repository-local plan in that repo; no hub plan owns it | 2026-08-21 |

**`psc-data-transformations` needed a new edge type, and naming it was cheaper
than bending an old one.** Every other row above describes something this hub
*consumes* — a validator, a gate, a mapping product, a documentation link. This
one runs the other way: an external repository consumes **metasalmon itself** as
a pinned execution engine, so its requirements constrain what this package may
change. `campModelInput`'s *application-consumer handoff* is the nearest
existing type and is still the wrong one, because that repo vendors a
**vocabulary release** rather than this package; filing this row under it would
have hidden the only property that matters — a consumer pinned to `0.1.8` at
`886e01d` and calling `metasalmon:::` internals is a compatibility constraint on
this package, not a downstream reader of an artifact.

**It also asserts a KNB staging model that contradicts the S3 execplan, and
nobody has ruled between them.** That repo's `docs/architecture.md` states KNB
provides **no separate hosted draft object** and that a *restricted persistent
version in production* is the review/staging state; its
`profiles/knb-private-review.yml` encodes exactly that — `deposit_kind:
production`, `access: restricted`, `staging_model: private_persistent_version`,
`creates_persistent_objects: true`. The
[S3 execplan](plans/2026-08-11-knb-environments-and-workshop-rebuild.md) assumes
the opposite shape: a `knb_environment = "staging"` switch resolving to the
DataONE **STAGING** network and member node `urn:node:mnTestKNB`, zero replicas,
a separate token. Both can be literally true at once — a test *node* and a
restricted production *version* are different objects — which is why this is an
open question and not a defect on either side. Recorded under *Open decisions*
below, because it changes what S3 must build and what S4 can teach.

**What this edge does not import.** That repository's gates (`rights`,
`semantic`, `private_review`, `public_release`), their approval evidence, its
branches, its receipts, and its lifecycle status stay in its own plan and never
enter this roadmap or release index. The external-edge rule is not weakened by
the pin being on this package rather than on an artifact.

---

## Active sequencing constraints

Ordering that is not optional, independent of who is executing:

- **Discharged, kept for the reason it existed:** the gcdfo WebVOWL normalizer
  fix had to land before the release, the definition update, and the
  `docs-widoco` baseline change. All three happened in order — gcdfo PR #82
  (normalizer + `set -e`) then #77 (definition) on 2026-08-16, release 0.0.9 on
  2026-08-17 — so this constraint no longer orders anything. It ordered them
  because on any branch lacking the fix `scripts/normalize_webvowl_json.py` died
  on a non-unique semantic class key and the recipe exited 0 over the crash,
  leaving raw un-normalized output in the tree.
- **An `ontology.json` hash is only meaningful as a (pin + normalizer) pair, and
  a hash taken from a broken pipeline is meaningless by construction.** Two
  hashes circulated in this stream as "expected under pin X". `4d350546…` is
  genuine — regenerated stably across four runs under pin `a5d4f28` with the
  fixed normalizer. `c14629eb…` was never reproducible **and never could have
  been**: it was recorded while the normalizer was crashing, and raw
  un-normalized WIDOCO/OWL2VOWL output is *nondeterministic* — two runs over
  byte-identical input produced two different hashes, both at the raw line
  count. That number was a single draw from a distribution, written down as if
  it were a fact. The normalized artifact, by contrast, is byte-stable across
  runs. Regenerate on the merged tree and accept what the generator produces; a
  hash that matches nothing expected is a finding to report, never a number to
  force. **The general form: a recorded hash inherits the trustworthiness of
  the pipeline that produced it, and nothing in the hash itself reveals which
  kind it is.**
- **`docs/webvowl/data/ontology.json` is no longer exempt from the CI drift
  gate** — gcdfo PR #82 removed the `:(exclude)` now that the file is byte-stable
  across consecutive `make ci` runs, so a hand-edit fails CI. What survives is
  narrower and local: a failed `make docs-widoco` leaves raw generator bytes in
  the working tree and the next run adopts them as its own baseline (backlog
  item 0). CI checks out clean, so it cannot be poisoned that way.
- **S10's 0.3.0 rung must carry metasalmon's post-0.3.0 fixes**, not just the
  release tree: the statistical-modifier ranking preferences, the corrected
  bundle-review prompt, the dry-run stop parity, and the role-contract guard.
  See the [S10 execplan](plans/2026-08-15-s10-metasalmonpy-parity-replay.md).

Live pull-request state is deliberately NOT tracked here — it is stale the
moment anything merges. Current work-in-flight lives in the owning execplan.

## Release index

Compact, hub-maintained. Each repo's own changelog/release page stays
authoritative; this index coordinates. Refreshed 2026-08-18 against repository
version sources, remote tags, GitHub/GitLab release objects, and the open
changes that affect this sequence; the metasalmon, metasalmonpy, smn-data-pkg,
psc-salmon-vocabularies and workshop rows were re-checked 2026-08-21 against
sibling checkouts.

**Read every row's tag line, not just its version heading.**
**Five of the seven** members have `main` ahead of their newest tag
(metasalmon, metasalmonpy, salmon-domain-ontology, dfo-salmon-ontology,
smn-data-pkg), PSC's alpha.3 is merged and untagged, and neither the commons
nor the workshop has a tag at all. Ahead-of-tag is the ecosystem's normal state
rather than an anomaly worth flagging per row, so **cite a commit unless you
have checked that the thing you mean is inside the tag.**

The index carries **eight sections for seven members**: the workshop is
sequenced here as S4 whether or not it is a member, so leaving its state
unrecorded served nobody. That mismatch is an *Open decision* below, not a
quiet expansion of the allowlist.

### metasalmon (R) — current **0.3.0**

| Version | Date | One line |
|---|---|---|
| 0.3.0 | 2026-08-15 | **Breaking:** sdp-0.3.0 implemented — dictionary swaps `method_iri` for `statistical_modifier_iri`, registry removed, `migrate_sdp_methods()` stop-and-report migration, semantic pipeline reviews the statistical-modifier slot, remote schema source pinned to spec tags |
| 0.2.6 | 2026-08-12 | Tidy-data enforcement: primary-key uniqueness, wide-format warning, placeholders surfaced |
| 0.2.5 | 2026-08-12 | Credential redaction covers qualified `*_token` names; duplicate redactor deleted |
| 0.2.4 | 2026-08-11 | **Breaking:** canonical CSV missing-value token is the empty field |

Recorded in `DESCRIPTION` + `NEWS.md` + tags/GitHub releases.
**Tagging policy (Brett, 2026-08-15): every release from 0.3.0 forward is
tagged AND gets a GitHub Release object.** `v0.3.0` is tagged at merge
`5a37b11` with its NEWS entry as the release body. 0.2.0–0.2.6 stay untagged
by decision — backfilling would invent release dates after the fact; that
historical gap remains an S6 governance note, not a task.
**S8 shipped:** PR
[#39](https://github.com/salmon-data-mobilization/metasalmon/pull/39) merged
2026-08-15 after five review rounds (29 findings fixed), so **0.3.0** is the
current R release on main at merge `5a37b11` — which is the only valid port
baseline for [S10](sequences/s10-metasalmonpy-parity.md); no intermediate
review-round commit is. The spec-tag schema pin from PR #37 shipped inside it.
**No release has been cut since**: `v0.3.0` (2026-08-15) is still the newest tag
while `main` is 107 commits past it with twelve unreleased fix entries in
`NEWS.md` — details under *metasalmon current state* below.

### metasalmonpy (Python mirror) — current **0.2.1** (= metasalmon 0.2.1 parity)

| Version | Date | One line |
|---|---|---|
| 0.2.1 | 2026-08-18 (tagged `v0.2.1`, GitHub Release published) | Every descriptor URI comes from one loader: 0.2.1's per-resource schema URLs, derived from the remote loader 0.2.0 introduced |
| 0.2.0 | 2026-08-18 (tagged `v0.2.0`, GitHub Release published) | The dictionary is the type authority: typed round-trip reader with raw-token preservation, overwrite/prune ownership, sidecar survival, symlink refusal, capture-time redaction, remote schema loader pinned to the upstream `sdp-0.2.0` tag. An era-R package round-trips through Python and back **byte-for-byte** |
| 0.1.8 | 2026-08-17 (merged `db85016`, tagged `v0.1.8`, GitHub Release published) | Parity with metasalmon 0.1.8: the SDP method registry read and validated with the **writer deliberately absent as a raising stub** (register row 9), observation structures, the reproducibility manifest, reviewed-strategy apply, expanded KNB publication, the `package_io` host fix, and the demo-data and `match_type` ranking fixes; the vendored schema bundle now comes from the upstream `sdp-0.2.0` tag. Verified by driving both implementations over the same inputs against the R **`v0.1.8` tag**: `methods.csv`, both observation-structure files and the updated `datapackage.json` came out byte-identical, and the KNB plan matched on all 20 objects, every PID and every checksum |
| 0.1.7 | 2026-08-16 (tagged `v0.1.7`, GitHub Release published) | Parity with metasalmon 0.1.7: SSSOM 1.1, measurement decompositions, reviewed EML 2.2.0, KNB/DataONE publication with the deterministic SDP archive, and the era SDP-inference corrections. Verified by running both implementations over the same inputs against the R **v0.1.7 tag**, not by reading R source |
| 0.1.6 | 2026-07-29 | Parity with metasalmon 0.1.6: `create_sdp` workflow, opt-in semantic review, term-gap detection |
| 0.1.3 | 2026-05-13 | Parity with metasalmon 0.0.13: SDP CSV IO, inference, EDH export |
| 0.1.2 | 2026-02-06 | Initial: GitHub CSV helpers, metasalmon 0.0.5 parity |

Renamed from `metaSmnPy`/`salmonpy` on 2026-08-13. Versions are **parity
claims** — [S10](sequences/s10-metasalmonpy-parity.md) must deliver the
complete released R baseline through 0.3.0, or whatever later R baseline is
current when META-1 starts. An isolated SSSOM port is not parity. **It no
longer *replays* that baseline release by release:** the 2026-08-17 replan
supersedes rungs 4–8 with a subsystem port straight to 0.3.0, so the ladder
ends at rung 3 and the phrase "replay the complete baseline" is retired.

Rung 3 has merged and tagged: metasalmonpy PRs #10, #11 and #12 are in, `v0.2.0`
and `v0.2.1` exist as tags and GitHub Releases, and `pyproject.toml` reads
`0.2.1` as a **released** parity claim rather than a branch state. The catch-up
window is therefore **0.2.2→0.3.0**. Both `AGENTS.md` files must carry that same
number — see the mirror rule above.

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
keep the historic shape). There is **no `CHANGELOG.md`** in this repo — the
changelog exists only as a generated block inside the WIDOCO `docs/` output,
which is why this index carries more smn history than the others.

**`main` has moved past the tag here too** (5 commits ahead, checked
2026-08-18): PR #26 (*one name per term, and only for terms smn owns*) and PR
#28 (commons routing, docs only) both merged after `0.0.3`. Cite the commit.
The live proposal on top of this is draft **PR #27**, which is `CONFLICTING`
and needs a rebase — see the [S9 card](sequences/s9-ontology-alignment.md) for
the five decisions it is waiting on.

### dfo-salmon-ontology (gcdfo) — current **0.0.9**

| Version | Date | One line |
|---|---|---|
| 0.0.9 | CHANGELOG dates it 2026-08-16; **tagged `0.0.9` and released 2026-08-17** — the repo's **first** tag | The S9 step-3 boundary published as data: a 32-row SSSOM set, four `gcdfo:` object properties **removed**, one class re-namespaced, the WSP Conservation Unit definition ("wild salmon"), the WebVOWL normalizer fix + ADR-007, and `make check-modules` |
| 0.0.8 | 2026-03-29 | Enhancement-status vocabulary, RemovalReference, abundance data-type classes |
| 0.0.999 | 2026-01-30 | Pre-1.0 "beta" versioning adopted; JSON-LD docs pipeline |
| 0.0.2 | 2025-01-07 | Initial structure, SKOS schemes, ROBOT toolchain |

**0.0.9 is a breaking release for consumers holding retired IRIs** — four
object properties are gone and one class moved namespace. `mappings/gcdfo-to-smn.sssom.tsv`
carries replacement rows so a dataset holding a retired IRI can resolve it.

**`main` has moved past the tag: three merges are unreleased** (re-checked
2026-08-18; `origin/main` is 7 commits ahead of the tag). PR #83 (deletes
the dead WebVOWL stabilizer and its orphaned stamp — backlog #81/#84), PR
#86 (the **Pacific fishery management area** SKOS vocabulary:
`gcdfo:PacificFisheryManagementAreaScheme` plus **48** concepts from SOR/2007-77
Schedule 2, S9 step 7 ruling A1), and PR #87 (routing durable salmon knowledge
to the commons — docs only) all merged *after* the 0.0.9 tag. They are on
`main` and the PFMA vocabulary sits in the CHANGELOG's `[Unreleased]` section,
so a consumer pinning the tag or the release object sees none of it — the same
reachable-by-branch, unreachable-by-pin state PSC alpha.3 is in below. Cite the
commit, not 0.0.9.

**This repo is under `dfo-pacific-science/`, not `salmon-data-mobilization/`** —
the only hub member in a different GitHub org, and `0.0.9` is still its only
tag. PR #87 also merged with no Kanban item, against that repo's own
`AGENTS.md` requirement; recorded as a process exception in the
[S9 card](sequences/s9-ontology-alignment.md).

**Discrepancies:** the sequence is non-monotonic (0.0.999 predates 0.0.8); the
CHANGELOG documents that as an abandoned numbering experiment and the version
line deliberately does not exceed it. Tags before 0.0.9 do not exist and are
**not** being backfilled — 0.0.9 is where the tag-and-release practice starts,
the same call made for metasalmon at 0.3.0.

**A gap 0.0.9 exposed and did not close:** `docs/releases/<version>/` snapshots
are written by `make release-snapshot` and never touched by `make ci`, so the
CI drift gate structurally cannot see a stale snapshot. The 0.0.9 snapshot had
been cut before the Conservation Unit definition change merged and **would have
published the superseded definition with every gate green**. Caught by hand and
re-cut before release. The fix — a CI check comparing
`docs/releases/<current owl:versionInfo>/` against `docs/`, scoped to the
current version so older snapshots stay free to diverge — is logged in that
repo's `docs/tech-debt.md` with its retirement condition.

### smn-data-pkg (SDP spec) — current **sdp-0.3.0**

| Version | Date | One line |
|---|---|---|
| sdp-0.3.0 | 2026-08-14 | **Breaking:** methods leave the column dictionary (three placements, no registry); `statistical_modifier_iri` added; frozen-profile versioning (v0.3 URL) |
| sdp-0.2.0 | tag cut 2026-08-14; **no changelog heading of its own** — see below | Frictionless-first schemas, v0.2 profile, `sdp.rules.yaml`, canonical `metadata/`+`data/` layout |
| 0.1.1 | 2026-01-14 (malformed in changelog) | I-ADOPT component columns in `column_dictionary.csv` |
| 0.1.0 | 2025-12-21 | Initial specification draft |

**0.2.0 got retroactive *content*, not a retroactive dated entry — there is no
`## [sdp-0.2.0]` heading in `CHANGELOG.md` at all.** (Corrected 2026-08-21;
this index asserted the opposite.) The headings run `## [Unreleased]`,
`## [sdp-0.3.0] - 2026-08-14`, `## [0.1.1]`, `## [0.1.0]`, and the entire
sdp-0.2.0 body of work sits *inside* the 0.3.0 entry as a second
`### Added`/`### Changed` pair, beneath a `### Fixed` note recording that it
"had no dated changelog entry". The visible consequence is that **one version
entry both removes and adds `metadata/methods.csv`** — removed in its own
breaking `### Changed`, added again in the nested 0.2.0 `### Added` — so
reading sdp-0.3.0's entry to learn what sdp-0.3.0 changed returns two eras at
once. *Retires when:* those nested blocks are lifted under their own
`## [sdp-0.2.0] - 2026-08-11` heading; delete this note in the same change.

Both `sdp-0.2.0` and `sdp-0.3.0` annotated tags were cut 2026-08-14
and pushed — they carry metasalmon's pinned remote schema source, which is
why they exist — but neither has a corresponding GitHub Release object
(remaining release mechanics are S6 item 3 / S1 cross-repo work).

**The spec-version spread — four consumers, three eras, and only one of them
current.** Checked 2026-08-21 against the sibling checkouts. No single repo can
see this table, which is the reason the hub carries it.

| Consumer | Declares or pins | Current? |
|---|---|---|
| `metasalmon` | Vendors **sdp-0.3.0**: `inst/extdata/schema/` is byte-identical to the spec's `schema/` for every shared schema and rule file, and it vendors the v0.3 profile | **Yes — the only one** |
| `metasalmonpy` | Vendors **sdp-0.2.0** and pins its remote loader to that tag (`SDP_SPEC_TAG`); stamps `sdp-0.2.0` into `dataset.csv$spec_version` and `datapackage.json` `sdp.specVersion` | No — era lag, deliberate |
| `smn-data-pkg`'s own shipped examples | `minimal-example` and `mixed-grain-example` both declare `"specVersion": "sdp-0.2.0"` | No |
| the Fraser recipe (`psc-data-transformations`, external) | Pins engine `metasalmon` **0.1.8** at revision `886e01d` | No |

Two things the spread makes visible. First, the vendored Python bundle carries
`schema/frictionless/metadata/methods.schema.json` — a file the spec repo **no
longer has**, since sdp-0.3.0 removed that registry — so metasalmonpy validates
against a schema with no upstream. That is the correct state for a 0.2.1 parity
claim and both sides record it with a retirement condition (metasalmonpy
`PARITY.md` rows 27 and 38: the pin and the bundle move together at S10's 0.3.0
rung, and must never name different eras). It is still worth stating plainly,
because "vendored" reads as "vendored from something that exists". Second, **the
spec repo ships examples of the version it superseded**, so the normative
document and its own demonstrations disagree — a smn-data-pkg defect that
belongs in that repo's tracker, noted here only because the hub is where the
mismatch is visible.

**Local checkout note (resolved 2026-08-13):** the dirty
state was abandoned metasmn-rename leftovers — preserved on local branch
`attic/abandoned-metasmn-rename-2026-06`, main fast-forwarded. Note PR #2
added a `methods.csv` registry the S8 method model removes; the port unwinds
it.

**`AGENTS.md` is now git-tracked here** (PR #5, merged 2026-08-18) — it had
been git-ignored since the initial commit, so the repo's own agent guidance
was invisible to every fresh clone. `main` is 2 commits past the `sdp-0.3.0`
tag as a result; both are that change. The same defect was fixed in
metasalmonpy at PR 0, and the mirror contract in this repo's `AGENTS.md`
already forbids ignoring those files.

### psc-salmon-vocabularies (PSC CV) — latest **tag** v0.1.0-alpha.2; alpha.3 is **merged to the default branch but untagged**

| Version | Date | One line |
|---|---|---|
| v0.1.0-alpha.3 | merged to the default branch (`8769597`, "Merge FAIR mapping products and alpha.3 integration"); **no `v0.1.0-alpha.3` tag and no GitLab Release object exist** | smn 0.0.3 anchoring: strict SSSOM 1.1 with nine `prototype_accepted` broadMatch rows and one visibly deferred proposal |
| v0.1.0-alpha.2 | 2026-07-31 | Prior prerelease vocabulary build (provisional, not an adopted PSC standard) |
| v0.1.0-alpha.1 | 2026-07-31 | First prerelease — tag only, no GitLab Release object |

Byte-pinned `releases/<version>/` dirs with per-artifact sha256 manifests;
GitLab.

**Read the merged/untagged distinction carefully — it changes what a consumer
gets.** MRs !8 and !5 have both merged, so `public/release/v0.1.0-alpha.3/` and
`public/integrations/campmodelinput/v1/v0.1.0-alpha.3/` are present on the
default branch. But the repository's tag list still ends at `v0.1.0-alpha.2`, so
anything pinning by tag or by Release object still resolves to alpha.2 and sees
none of it. Alpha.3 is therefore reachable by branch and unreachable by pin: a
state that reads as "released" to anyone who checks the tree and "absent" to
anyone who checks the tags. **Do not cite alpha.3 as a released product until a
tag exists** — cite the commit.

**PSC-0A content** (unchanged by the merge): it preserves the versioned
alpha.1/alpha.2/alpha.3 CAMP Adapter routes, defers the unsupported
PSC-CV-000017 composition, declares SSSOM 1.1, records PSC CC BY 4.0 as the
mapping-set licence, and serializes per-relationship dates. The nine-row
PSC-to-SMN set passes metasalmon's strict 0.2.6 reader. Good interoperability
evidence; still not the stable PSC-1 product-profile fixture a consumer child
requires, and tagging alone would not make it one.

**alpha.3's smn pin is mixed, and a reader who checks one row will get the wrong
answer** (observed 2026-08-21). `public/release/v0.1.0-alpha.3/` pins smn at
**`f7205ee`** for the 0.0.3 release TTL — the `manifest.json` and
`external-sources.json` entries for `docs/releases/0.0.3/smn.ttl`, and the
provenance column on the nine `EnumerationMethod` mapping rows — while other
rows in the *same* release still cite **`b6978b0`**: the `CONVENTIONS.md`
source entry in both files, and the `sdo-alignment-gap.md` rationale whose whole
argument is about what was true at that older commit. Two smn commits inside one
byte-pinned release is not automatically an error — the gap document is a
historical argument and re-pinning it would falsify it — but nothing in the
release says which rows are lagged on purpose. *Retires when:* alpha.3's
manifest states, per source entry, whether its pin is current or deliberately
historical; until then cite the specific entry, never "alpha.3's smn pin".

### salmon-knowledge-commons — **no releases, and no versioning scheme yet**

| Version | Date | One line |
|---|---|---|
| *(none)* | — | No tags, no release objects, no declared content-versioning scheme. `okf_version: "0.2"` names the *format* the bundle is written to, not a version of what it says |

Newest member of the domain, added 2026-08-17. **Private.** Created 2026-08-17
(`2026-08-18T01:50Z`); zero tags and zero release objects, re-checked
2026-08-18. **It cannot be pinned by version at all — only by commit SHA.**

**It grew fast: eleven concepts and 24 gaps, not the four and seven recorded
here on 2026-08-17.** PRs #1 and #2 merged 2026-08-18. The eleven cards are
cycle line, broodline, cyclic dominance, run timing, conservation-unit
independence, FishBase as a vocabulary source, migration-timing genetic
architecture, Pacific salmonid taxonomic authorities, potamodromous migration
vocabulary, sockeye rearing ecotypes, and stream-type/ocean-type chinook.
**Still none human-verified.** Gap `mint_target`s: `smn` 18, `gcdfo` 4,
`do-not-mint` 2.

It is an **upstream OKF v0.2** bundle, not a PSC-profile one, and that is a
decision rather than an oversight: the PSC profile's closed card schema rejects
`sources`, `verified`, `generated`, `stale_after`, and `resource` — the fields
the commons exists to carry — so `psc-okf`'s profile check is not its
validator, and the capture-tier command this bundle documents does not apply
to it.

**What a later refresh should and should not do here.** A versioning scheme is
a decision nobody has made, so do not invent one for this table; "no releases"
is the finding, not a hole in the index. This entry retires the moment the
repository declares a scheme or cuts its first tag, and until then the correct
citation for anything it contains is a commit.

### salmon-data-standards-workshop — **no releases, and no versioning scheme yet**

| Version | Date | One line |
|---|---|---|
| *(none)* | — | A Carpentries-style lesson (sandpaper/`config.yaml`, six sessions plus a bonus). Zero tags, zero release objects, no declared content-versioning scheme. Last commit `b080fc9`, 2026-08-11 |

**This repository was silently absent from the index while being sequenced as
[S4](sequences/s4-workshop-rebuild.md)** — the hub was ordering a rebuild of a
repo whose current state the index did not record. Added 2026-08-21 for that
reason alone. **Its membership in the domain is an open decision, not settled by
its appearing here**: see *Open decisions* below. A release-index row is a
statement about what a repo has shipped, not a membership grant.

A lesson has no versioning scheme for the same reason the commons has none:
nobody has decided one. Do not invent one for this table. What a lesson pins
*instead* of versioning itself is the software it teaches against, and those
pins are the sequencing-relevant fact: `README.md` and `session-1.Rmd` target
`metasalmon` **0.2.3 or later from GitHub `main`** (README adds "the latest
tagged R release at the time of this update is 0.1.8", written before `v0.3.0`
existed), and the Python companion is named as `salmonpy` **0.1.6** — a package
name retired in the 2026-08-13 rename to `metasalmonpy`, at a version four
releases behind. So the lesson currently teaches against an untagged moving
branch on the R side and a renamed, stale package on the Python side, which is
exactly the condition S4 exists to end: episodes must execute against *released*
metasalmon and metasalmonpy. *Retires when:* the rebuild lands and the episodes
name released versions, or the repository declares a versioning scheme — either
one makes this paragraph a row in the table above instead of prose.

---

## Open decisions

Questions this bundle has surfaced that **Brett has not ruled on**. They live
here so they stop being re-derived, not so they can be quietly settled. Writing
a preference into a card as though it were a ruling converts a recon finding
into a fake decision, and afterwards nothing downstream can tell the two apart —
which is worse than leaving the question open, because an open question at least
looks like one. Each entry names its options and what the ruling unblocks.
**Do not resolve one by editing another card to match your preferred answer.**

### OD-1 — Which membership test governs, and is `salmon-data-standards-workshop` the eighth member?

**This bundle states two different membership tests, and they disagree.**

- This card's *Domain allowlist* rule admits a repository when **its output is
  an input to this pipeline** — the stated reason `salmon-knowledge-commons` was
  admitted 2026-08-17, its gap register feeding `detect_semantic_term_gaps()`.
- The [domain card](domains/salmon-data-ecosystem.md) closes with a different
  rule: **membership follows from this hub sequencing that repository's work.**

They give **opposite answers for `psc-data-transformations`**: the hub does not
sequence its work, so the second test excludes it, while it drives requirements
into this package through a version pin and calls to `metasalmon:::` internals,
which the first test arguably admits. And they invert for the workshop — the hub
**does** sequence its rebuild as S4, so the second test admits it, while a
lesson's output is not an input to any pipeline stage, so the first excludes it.
Meanwhile the domain card asserts "seven repositories, one hub" as
**exhaustive** while this roadmap sequences an eighth repository's rebuild as a
named stream.

| # | Possible ruling | Consequence |
|---|---|---|
| A | The **input** test governs | The domain card's sequencing sentence is corrected; the workshop stays external, and S4 becomes a stream sequencing a non-member — which the external-edge rule above does not currently permit |
| B | The **sequencing** test governs | The workshop becomes the **eighth** member, the allowlist count changes, and the commons's 2026-08-17 admission is restated in sequencing terms |
| C | **Both** must hold | Neither joins; the commons's admission re-opens; S4 needs a stated exception for sequencing a non-member |
| D | Membership unchanged; the hub **explicitly permits** sequencing an external repository | Cheapest change; requires extending the external-edge rule to cover "sequenced here, owned elsewhere" |

**Unblocks:** whether the workshop's release-index section above is a member row
or a courtesy record; whether `psc-data-transformations`' pin on metasalmon
0.1.8 is an obligation on this package or advisory; and whether "seven
repositories" is a count anyone must maintain. Until it is ruled, **neither test
has been deleted and the workshop has not been added.** The same question is
recorded in the domain card, so a reader arriving from either direction meets
it. *Retires when:* Brett rules — and the losing test is deleted in the same
change, or this pair regrows.

### OD-2 — What does "the KNB test environment" mean?

The [S3 execplan](plans/2026-08-11-knb-environments-and-workshop-rebuild.md) and
`psc-data-transformations` describe incompatible things by the same name; the
evidence for both sides is in the external-edge notes above.

| # | Possible ruling | Consequence |
|---|---|---|
| A | A **distinct DataONE test node** — STAGING network, `urn:node:mnTestKNB`, zero replicas, separate token — as the S3 execplan assumes | `S3 ──► S4` holds exactly as drawn: S3 builds the switch, S4 teaches against the test node |
| B | A **restricted persistent version on production KNB** is the rehearsal, as `psc-data-transformations` asserts and has already implemented | **The `S3 ──► S4` arrow dissolves.** The rehearsal already exists in shipped form, so S4 stops being hard-blocked and instead needs the private-review path documented and taught |
| C | **Both**, as two values of `knb_environment` | S3 grows rather than shrinks: it must build and distinguish both, and S4 must teach which one a first-time depositor should reach for |

**Unblocks:** the hard `S3 ──► S4` arrow in the sequencing diagram below — S4's
only remaining hard blocker — and therefore whether the workshop rebuild can
start now. Under B it can. *Retires when:* Brett rules. Verifying directly
against KNB whether `urn:node:mnTestKNB` accepts the deposits S3 describes would
settle the *factual* half and still leave the "which one do we teach" half open,
so that check is useful evidence and not a substitute for the ruling.

---

## metasalmon current state

**Shipped: 0.3.0** (tagged `v0.3.0`, GitHub Release published 2026-08-15).
The release sequence, all reviewed and CI-green:

| Release | What |
|---|---|
| 0.2.0 | All nine P0 defects — installable again, truthful schema contract, lossless SDP round trip, byte-reproducible artifacts, external text can no longer be a cli template |
| 0.2.1 | #43 last locale-dependence · #62 last hardcoded contract value |
| 0.2.2 | #45/#46/#50 — term-index caches actually prevent work; a failed vocabulary lookup no longer looks like an ontology gap |
| 0.2.3 | #47/#51/#52 — dry runs re-plannable; LLM providers retry and honour `Retry-After`; BioPortal key out of the URL |
| 0.2.4 | #54 missing-value contract · #72 `ms_setup_github()` default · CI optional deps, non-C ambient collation, runnable examples |
| 0.2.5 | #73 credential redaction covers qualified token names |
| 0.2.6 | #77 tidy foundations — primary-key uniqueness, wide-format warning, placeholders surfaced |
| 0.3.0 | #76 sdp-0.3.0 method placement model — dictionary swaps `method_iri` for `statistical_modifier_iri`, registry removed, `migrate_sdp_methods()`, placement validation, spec-tag schema pin |

S8's 0.3.0 merged 2026-08-15 (PR #39, merge `5a37b11`, five review rounds)
and is tagged and released per the 0.3.0-forward tagging policy.

**No release has been cut since 0.3.0.** `v0.3.0` was tagged 2026-08-15 and
nothing has been released since; `main` is **107 commits past that tag**
(2026-08-21) and `NEWS.md`'s development section has accumulated **twelve fix
entries** (four under `### Bug fixes`, eight under `### Fixed`) plus two
documentation entries. `DESCRIPTION` is bumped only in the release PR, so `main`
self-reports `0.3.0` while carrying all of it — the same
cite-the-commit-not-the-tag condition gcdfo and PSC are in above, and it applies
hardest here, because this is the repo whose released version other repos pin.
State this plainly wherever the 0.3.0 number appears: **released 0.3.0 and
`main` are now materially different packages.**

Post-0.3.0, `main` has taken S11 slice 2's two vignettes (PR #46), the
statistical-modifier ranking preferences and honest dry-run previews (PR #47,
merge `6c6acb8`), the single-owner IRI whitespace predicate (backlog #85, PR
#52), dual-provenance reproducibility-manifest validation (backlog #88, PR #58),
`smn` ranked above `gcdfo` at the cause (PR #64 — the first application of
Brett's 2026-08-17 mirror ruling, where R was the side that moved), descriptor
adjudication and the `datetime` observation dimension (PR #65), and
platform-independent zero-padding of calendar years below 1000 (PR #70, backlog
#94 — a real cross-platform byte divergence, where metasalmonpy was already
correct); and the write-side half of backlog #93 (`write_salmon_datapackage()`
wrote `Date` columns in a form this package's own reader could not parse) merged
as PR #71 on 2026-08-21, confined to `Date` because readr's `POSIXct` output was
measured already correct. Live PR state is not
tracked here as a rule; this one is named because a reader counting the padding
fixes on `main` would otherwise conclude #93 is closed.

`5a37b11` is the **release** baseline for S10's 0.3.0 rung; anything replaying
the post-0.3.0 fixes needs a later commit than the tag.

**Health invariants.** Hold these at every step; a regression in any of them is
as serious as a failing test, and unlike a failure most will not announce
themselves.

- Suite: **0 failures**. CI skips: **exactly 4** (Theme A integrity, in
  `theme-a-integrity.yaml`). Local: 5, adding the CI-only optional-dependency guard.
- `R CMD check`: **Status: OK**, no NOTEs.
- CI runs under a **non-C ambient collation** (`LC_ALL=en_US.UTF-8`), so the
  byte-reproducibility guards are exercised rather than skipped.
- Three static guards stay honest: any new byte-producing function goes in
  `collation_sensitive_fns`; any new cli call uses literals or the escaping
  helpers; any new or renamed semantic role reaches all five layers of the role
  contract, including the ranking preferences and the hint emitters that the
  role-contract guard checks by inspecting function bodies. All three contracts
  are stated in `AGENTS.md`.
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
ships without them, but says something it cannot fully back. **One solid arrow
is marked conditional** — it is drawn as a hard block because that is the
current plan of record, and it survives only under some rulings of
[OD-2](#od-2--what-does-the-knb-test-environment-mean).

```
                                          ▼ conditional — OD-2, not yet ruled
#73 redaction ✔ ──► S3 KNB environments ──► S4 workshop rebuild
                                              ▲   ▲   ▲   ▲
S8 method model + tidy ──► S9.2 methods-as-SKOS ──┘   │   │   │
     (#77 → #76)                                  │   │   │
S1 validation authority ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘   │   │
S6 vocabulary release pinning ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘   │
S10 metasalmonpy parity ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘

S9 ontology conventions + alignment ── implementation evidence exists, with
                                       different release states: SMN 0.0.3 is
                                       released; gcdfo PR #78 shipped in 0.0.9,
                                       but #83/#86 sit unreleased on main; PSC
                                       alpha.3 merged (MR !5, 2026-08-16) and
                                       is still untagged
S2 correctness debt          ── independent
S5 review flow (next minor)  ── independent (#60 → #74 internally)
S7 architecture + curation   ── independent, largest
S11 vignettes + walkthroughs ── slices 1–2 independent; KNB golden path
                                after S3; review vignette with S5;
                                methods vignette after S8

PSC PLAN-0 + HQ activation ──► PSC-1 mapping-product contract ──┐
S10 full Python parity through current released R baseline ─────┼─► S6 FAIR
META-0 plan alignment (this bundle) ────────────────────────────┘   consumer

NUSED-0 authority + truthful targets or explicit gaps ──► governed NuSEDS product
governed product + META-1R/PY + Python replay of 0.3.0 ──► paired consumer
```

Read that as: S3's only hard blocker shipped in 0.2.5; S2, S5, S7, and S10 run
in parallel with everything (S10 is dashed into S4 because the workshop's
Python episodes execute against metasalmonpy). S4's **S8 blocker is discharged**
— the method model shipped as 0.3.0, so S4's method-annotation content has a
released contract to teach and S3 is its only remaining hard blocker.

**That last clause is conditional, and the condition is unruled.** `S3 ──► S4`
holds only if "the KNB test environment" means a *distinct DataONE test node*.
If a **restricted persistent version on production KNB** is accepted as the
rehearsal S4 should teach — the model `psc-data-transformations` asserts in
`docs/architecture.md` and has already implemented in
`profiles/knb-private-review.yml` — then the rehearsal S4 needs already exists,
**the arrow dissolves, and S4 has no hard blockers left at all.** That is a live
possibility, not a preference expressed here; see
[OD-2](#od-2--what-does-the-knb-test-environment-mean) for the three candidate
rulings and what each one costs. Read the arrow as the plan of record awaiting a
ruling, and do not re-draw it in either direction before one exists.

**S8 came first among the spec streams**: it decided what the SDP means, S1 then
makes the validator enforce it, and S9 step 2's methods-as-SKOS migration
implemented the vocabulary half.
The generic FAIR mapping-product consumer is a dependency-gated S6 substream:
it reuses R's existing SSSOM implementation and has no semantic dependency on
S8. The mirror invariant separately requires S10 to replay the complete current
released R baseline in Python before new behavior lands in both languages; that
baseline is now **0.3.0, released**, and the replay stands at 0.1.8 released
with rung 3 written and awaiting merge — the **last** replayed rung, since the
2026-08-17 replan ports the remainder by subsystem. The first behavior is verification,
pinning, archival, and provenance, not compatibility evaluation or predicate
execution. PID-1 now selects readable stable product slugs under `/mappings/`.
COMPAT-1 now lets a publisher assert expected compatibility while each consumer
independently verifies and accepts or rejects it, but META-1 only preserves the
qualified link and does not evaluate that assertion. The later NuSEDS migration
still waits on source authority, the Python replay of 0.3.0, and any shared
analytical-term coverage its approved scope requires; the PR #39 merge and
release half of that gate is satisfied.

### The streams

- [S1 — One validation authority](sequences/s1-validation-authority.md) · #48, #49
- [S2 — Correctness debt](sequences/s2-correctness-debt.md) · #53, #55, #56, #57
- [S3 — KNB staging environment](sequences/s3-knb-staging.md)
- [S4 — Workshop rebuild](sequences/s4-workshop-rebuild.md)
- [S5 — R-native review flow, ships as the next minor at ship time](sequences/s5-review-flow.md) · #58, #59, #60, #74 (0.3.0 was taken by S8)
- [S6 — Ecosystem hardening and governed mapping-product consumption](sequences/s6-ecosystem.md) · #44, #61
- [S7 — Architecture and curation engine](sequences/s7-architecture.md) · largest, last
- [S8 — Method model and tidy foundations](sequences/s8-method-model.md) · **shipped as 0.3.0**; #77 done, #76's crosswalk retarget did not ride it
- [S9 — Ontology conventions and alignment pass](sequences/s9-ontology-alignment.md) · step 7's four decisions are made; gcdfo #67 is closed, #68–#75 stay open behind successors #84/#85 and smn PR #27
- [S10 — metasalmonpy parity](sequences/s10-metasalmonpy-parity.md)
- [S11 — Vignettes and user-facing walkthroughs](sequences/s11-vignettes-and-walkthroughs.md) · #79; slices 1–2 have landed, 3–5 remain
- [S12 — the Fraser coho gold-standard example](sequences/s12-fraser-coho-gold-standard.md)
- [S13 — Fraser Recruits case-study requirements](sequences/s13-fraser-recruits-case-study.md)

**S12 and S13 are new streams for work that was already a stated top priority
and had no card.** Before 2026-08-21 the phrase "gold standard" appeared
**nowhere in this bundle** — not in the roadmap, not in a sequence card, not in
a backlog item, not in `AGENTS.md`. The nearest thing to it was
`nuseds-fraser-coho-2023-2024.csv` appearing as an *exercise dataset* inside the
S3/S4 execplan, which is a workshop input, not an exemplar anyone owns. A
priority with no card cannot be sequenced, cannot block anything, and cannot be
noticed as missing — it simply is not in the ordering, and every reader of this
card concludes, correctly on the evidence in front of them, that it is not
priority work. Treat a stated priority that fails a bundle-wide grep as the
finding it is.

### Continuous

- **Keep the guards honest.** New byte-producing function →
  `collation_sensitive_fns`. New cli call → literals or the escaping helpers.
- **Watch the skip count**, not just the failure count. CI must report exactly 4.
- **Refresh the release index** whenever drift is noticed.
- **Mirror every metasalmon change into metasalmonpy** (or log why not).

## Dependency-scoped plans

| Execplan | What it covers | Activation state |
|---|---|---|
| [governed mapping products](plans/2026-08-14-governed-mapping-products.md) | Reusable FAIR mapping-product verification contract, existing SSSOM reuse, immutable pins, provenance, and conditional compatibility/application/NuSEDS follow-ons | Before implementation, verify activation in Brett HQ, a released PSC-1 contract, and S10 full parity through the then-current released R baseline; META-1 remains independent of S8's method semantics |

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

## Process notes worth keeping

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

**A deferred import is still a hard dependency for every caller.** metasalmonpy
keeps PyYAML out of its core dependencies and imports it inside the functions
that need it. A change added a call from the KNB *archive* path into one of
those functions, and the archive path stopped working on core deps — a real
regression, in a package whose parity register claims core-deps safety as a
property. Reading the import statements said the opposite: every `import yaml`
was correctly deferred, and the archive module imported nothing. **The dependency
entered through the call graph, not the import list**, so only running the path
with the extra uninstalled could reveal it. Two readers reached the wrong
conclusion from the imports alone before anyone ran it. The general rule: "the
import is inside a function" is a statement about that function, never about its
callers, and a claim of dependency-tier safety is only worth what the test that
exercises it is worth.

**A changelog block anchored on the section below it follows that section
through a version promotion.** A branch added a `### Removed` block above
`## [Unreleased]`, using the released section beneath as its context anchor.
When the release branch promoted `[Unreleased]` to `[0.0.9]` and merged first,
the rebase carried the new block *into the published, tagged `[0.0.9]`* — a
second `### Removed` heading inside a cut release, silently and with no
conflict. Caught by diffing the merged `CHANGELOG.md` against the tag rather
than trusting a clean rebase. Verify a changelog rebase against the tag, not
against the absence of conflicts.

**Patch-unique is not content-unique.** When auditing whether an abandoned
branch can be discarded, `git cherry origin/main <branch>` is the obvious test
and it produces false positives constantly. Three branches across the hub
reported 14, 11, and 2 patch-unique commits and all three turned out to hold
nothing `main` lacks, for three unrelated reasons: the branch retained
generated artifacts `main` deliberately stopped tracking; a namespace migration
(`gcdfo:` → `smn:`) preserved every concept while changing every line; and a
later cleanup commit mutated the content a pre-rebase backup's patches touched,
so the patch-ids stopped matching. Each needed a semantic diff — *is this
concept present under any name?* — not a commit count. The inverse also holds:
a branch can have **zero** patch-unique commits and still be worth reading, and
one that is genuinely superseded is best recorded by *why* it is superseded
(`feature/observation-structure-methods` carried `metadata/methods.csv`, the
exact artifact sdp-0.3.0 removed) rather than by a claim that its content is
"already in main", which was the wrong reason for the right verdict.
