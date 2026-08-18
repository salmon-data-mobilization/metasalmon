---
type: Artifact
title: "S10 metasalmonpy parity replay 0.1.6 → 0.3.0"
description: "ExecPlan bringing the Python mirror from its 0.1.6 parity claim to metasalmon 0.3.0 — rungs 0-3 replayed release-by-release, the remainder ported by subsystem after the replay was found to be building things metasalmon had already removed."
status: draft
tags: [execplan, s10, parity, metasalmonpy]
psc:
  id: metasalmon:plan:2026-08-15-s10-metasalmonpy-parity-replay
  contexts: [metasalmon:context:hub-coordination]
---

# S10 — metasalmonpy parity replay, 0.1.6 → 0.3.0

Evidence base: a three-agent recon (2026-08-15) that mapped every metasalmon
release 0.1.7–0.3.0 from NEWS, inventoried the current Python tree, and
synthesized the gap matrix. Three of its claims were spot-verified against
the working trees; the essentials are distilled here so the plan stands
alone. Each milestone's implementer reads the corresponding metasalmon NEWS
section and the R files it names — R is the complete spec for every port.

## Decisions (logged)

| Decision | Rationale | Date |
|---|---|---|
| **Registry writer-only skip at 0.1.8.** `read`/`validate` for `metadata/methods.csv` are implemented (Python receives R-written 0.2.x packages carrying registries, and 0.1.8–0.2.6 EML documents used procedures from them); the `write_sdp_methods` surface is skipped with this logged exception | No Python user ever existed at 0.1.8 parity needing to write registries; the writer would exist only to be deleted at 0.3.0 in the same stream; Brett rejected per-package registries in the method model. Flagged for veto in the 2026-08-15 report | 2026-08-15 |
| **PR 0 ships un-bumped parity debt first.** The smn/gcdfo term indexes are stubs returning empty frames (`term_search.py:505-510`), so the existing 0.1.6 claim is overstated; PR 0 makes it true and carries no version bump | A bump asserts parity; PR 0 restores an existing claim rather than making a new one. 0.1.7 inference fixes, 0.2.2 caching, and 0.3.0 modifier sourcing all attach to these indexes | 2026-08-15 |
| **The typed reader is born NA-safe.** At PR 3, `read_salmon_datapackage` gets `keep_default_na=False, na_values=["", "NA"]` (exact R-0.2.0 read parity), tightened to `na_values=[""]` at PR 5. The destructive pandas default (which silently converts literal "NA" gear codes) must never exist in any tagged state | A tagged state with pandas default NA parsing would be strictly worse than the R defect 0.2.4 fixed — read→edit→write bakes the loss into bytes | 2026-08-15 |
| **specVersion misstatement is closed at PR 3, not before.** Python stamps `sdp-0.2.0` today from pre-0.2.0-behaviour code; rolling it back would churn user packages | Known, bounded misstatement; recorded here and in the CHANGELOG at PR 3 | 2026-08-15 |
| **Archive parity is contract-level, not byte-level.** Python defines its own `zipfile` determinism reference; the R↔Python CI job asserts manifest/ordering/fail-closed, never bytes | R's determinism is `zip`-3.0.1-specific; cross-language bytes cannot match | 2026-08-15 |
| **0.3.0 ports from the merged release tree** (metasalmon main at the v0.3.0 merge, `5a37b11` — never any intermediate review-round commit; `f76ed4f` was only round one of five and lacks the rollback, role-hint, placement-validation, ordering, and method-promotion fixes), and the FINAL R fixture suite lands as pytest BEFORE the code | Five review rounds hardened the migrator (stop taxonomy, atomicity, dry_run typing, rollback); porting any pre-merge snapshot would tag 0.3.0 with known audited defects | 2026-08-15 |

### 0.1.7 dependency decisions (logged 2026-08-15, from the dependency recon)

| Decision | Rationale |
|---|---|
| **EML: build with stdlib ElementTree; validate with lxml as an optional extra; vendor the EML 2.2.0 XSD set (27 files, ~1 MB) as package data with its NCEAS/EDI notices** | R's document is one namespaced root with unqualified descendants — fully within ElementTree (already the repo convention via `edh_xml.py`). lxml IS libxml2, the identical engine behind `emld::eml_validate`, so accept/reject semantics match R by construction. metapype rejected: forces a 3.11 floor, validates against its own rule set rather than XSD, and its builder API would turn the node-for-node port into a rewrite. Fallback if lxml is ever unacceptable: `xmlschema` (weaker parity, 3.10 floor) |
| **DataONE: raw REST via `requests` behind a Python adapter mirroring R's 14-method boundary — no dataone.libclient** | The library is dormant (no release since mid-2023) with a disproportionate tree (PyXB fork, aiohttp, rdflib, cryptography) for a pandas+requests package — and R itself already bypasses it for roughly half the surface (anonymous reads, capabilities, formats, Solr are raw httr2; the ORE map is hand-built with xml2). The genuinely-library-provided part is ~11 REST endpoints and a flat single-namespace SystemMetadata document (~300–500 lines). The adapter seam keeps a future swap cheap and mirrors R's `metasalmon.knb_adapter` injection point |
| **Extras: `eml = ["lxml>=5,<7"]`, `knb = ["metasalmonpy[eml]"]`; core stays pandas+requests** | Mirrors R's Suggests-with-runtime-guard pattern (`emld`/`dataone`/`datapack`); lazy imports raise actionable install messages |
| **EML/ORE parity tests assert structural equivalence (`ET.canonicalize`), never bytes** | Python cannot match libxml2's formatter byte-for-byte; consistent with the existing contract-level archive ruling |

### Replan: rungs 4–8 become a subsystem port (Brett, 2026-08-17)

| Decision | Rationale | Date |
|---|---|---|
| **Stop replaying releases after rung 3. Port the remainder by subsystem against the `v0.3.0` tag, and bump straight to 0.3.0** | The replay was implementing behaviour metasalmon had already deleted — rung 2 built a reader for a registry sdp-0.3.0 removes, and rung 1 shipped a decomposition component annotated "it dies at 0.3.0". The replay's real value is *differential verification*, which needs chunking but not *chronological* chunking; per-subsystem chunks against `v0.3.0` give the same reviewability without the dead work. The version contract permits the jump: it requires the claimed number to be true, not that every number be visited. **Reverses if** a consumer appears pinned to an intermediate metasalmonpy version, or a defect is traced to something only an era-by-era replay would have caught | 2026-08-17 |
| **The breaking change moves from last to first.** 0.3.0's dictionary-contract flip was rung 8 because it is atomic; that ordering meant every earlier rung built on a shape it replaces. Chunk A lands it first | Nothing built after A sits on a superseded shape. This inversion is what the replan buys | 2026-08-17 |
| **Legacy *read* support is kept and is not a reason to replay.** Python receives SDPs written by metasalmon 0.2.x carrying a methods registry, and 0.1.8-era EML quotes procedures from one | Real data-compatibility need, already satisfied at rung 2; it is a feature of the 0.3.0 port, not an argument for implementing 0.2.x in order | 2026-08-17 |

## The ladder — rungs 0–3 replayed, the remainder ported by subsystem

Each milestone = one PR ending in a version bump (both `pyproject.toml` AND
`__init__.py` — scripted, they drift; CHANGELOG entry; tag; GitHub release).

0. **Parity debt, no bump** — real smn/gcdfo term indexes replacing the
   stubs; clean stale `dist/` artifacts. Blocks everything below.
1. **0.1.7** — EML export, KNB/DataONE (plan/dry-run/live/revision),
   deterministic ZIP (Python-native reference), SSSOM, measurement
   decompositions (with the transitional `method` component — it dies at
   0.3.0), inference fixes. Heaviest milestone; two dependency decisions
   (DataONE client, XML emission) are logged decisions when made. Design the
   redactor as ONE function now (0.2.5 foresight).
2. **0.1.8** — registry read/validate (writer skipped per decision),
   observation structures, reproducibility manifest, reviewed-strategy
   apply, expanded KNB, **the `package_io.py:29-35` host fix**
   (dfo-pacific-science → salmon-data-mobilization; a constant swap — the
   URLs are stamped, never fetched), demo-data fixes, `match_type` ranking
   fix. Vendored bundle taken from the upstream **`sdp-0.2.0` git tag**
   (main is 0.3.0-shaped and lacks `methods.schema.json`).
3. **0.2.0 + 0.2.1 collapsed** — typed round-trip reader (dictionary as sole
   type authority; raw-token preservation; float-vs-Int64 is a logged
   decision either way), overwrite/prune ownership, the remote schema
   loader **born pinned to the `sdp-0.2.0` tag** with an override, 0.2.1's
   per-resource URLs derived from that same loader (collapsing avoids
   building an interim shape only to rewrite it), tie-break keys, sidecar
   survival, datetime/date inference (public API in Python — behaviour
   change), symlink refusal, capture-time redaction. Two tagged bump
   commits inside one PR keep the number line intact.

### Rungs 4–8 superseded — the remainder is a subsystem port to 0.3.0

**Superseded 2026-08-17 (Brett).** Rungs 4–8 replayed 0.2.2, 0.2.3, 0.2.4,
0.2.5, 0.2.6 and 0.3.0 in order. They are replaced by a single port organised
by **subsystem**, verified against the **`v0.3.0` tag**, taking the version
straight from rung 3's number to **0.3.0**.

**Why.** The replay was building things metasalmon had already removed. Rung 2
implemented read/validate for `metadata/methods.csv`, a registry sdp-0.3.0
deletes from the spec — its writer was skipped with a note saying it "would be
written only to be deleted in the same catch-up stream." Rung 1 shipped the
transitional `method` decomposition component annotated "it dies at 0.3.0." The
ladder had already been collapsed once for this reason (rung 3 merged 0.2.0 and
0.2.1 "to avoid building an interim shape only to rewrite it"), so the
rung-per-release granularity was never load-bearing; it had simply never been
re-examined whole.

**What the replay was actually buying, and why chronology is not required for
it.** Its value is *differential verification* — running both implementations
over the same inputs caught about a dozen divergences at 0.1.7 and more at
0.1.8, which reading R source had missed. That value comes from **chunking**,
not from *chronological* chunking. Chunking per subsystem against `v0.3.0`
gives the same reviewability, and a divergence in behaviour that 0.3.0 deleted
is not a divergence worth finding.

**The version contract permits the jump.** `AGENTS.md` says the version *is a
parity claim*, bumped when the mirrored behaviour lands. It does not require
visiting intermediate numbers — it requires that whatever number is claimed is
true.

**What is genuinely kept from the chronology.** Python receives SDPs *written
by* metasalmon 0.2.x that carry a methods registry, and 0.1.8-era EML documents
quote procedures out of one. Legacy **read** support is therefore real — but it
is a data-compatibility feature of the 0.3.0 port, already landed at rung 2, not
a reason to implement 0.2.x releases in order.

**What this gives up:** the ability to say metasalmonpy was verified at each
historical point. No consumer needs it; see the rung-2 decision recording that
no Python user ever existed at that parity level. **The risk it takes on** is a
larger diff with fewer checkpoints, mitigated by per-subsystem differential
verification rather than per-release.

**What would reverse this decision:** a consumer appearing that is pinned to an
intermediate metasalmonpy version, or a defect traced to a behaviour that only
an era-by-era replay would have caught.

### The subsystem chunks

**A must land first**, and that inversion is the point of the re-plan: 0.3.0's
breaking change was rung 8 precisely because it is atomic, which meant
everything before it was built on a shape it replaces. Doing it first means
nothing after is.

| # | Subsystem | Scope |
|---|---|---|
| **A** | **Spec conformance and the dictionary contract** *(breaking; first)* | Methods leave `column_dictionary`; `statistical_modifier_iri` replaces `method_iri`; registry removal with errors that point at migration; `migrate_sdp_methods` with the full hardened stop taxonomy, **every stop firing in the dry run as well as the real run**; the three placements (`tables.csv$method_iri`, `protocol_iri`/`protocol_citation`, `codes.csv$term_iri`); default and strict placement-IRI checks; pin flip to `sdp-0.3.0`; the bundled template header, which in Python is well-formed but still ends `method_iri` |
| **B** | **Semantic pipeline retarget** *(after A)* | Semantic retarget to `statistical_modifier`; **three `statistical_modifier` rows in the ranking-preferences data** — net-new in Python, whose preference data still carries the pre-0.3.0 role set; the bundle-review prompt naming `statistical_modifier` rather than the removed dictionary `method` slot; a static role-contract guard covering **all six** surfaces a role touches |
| **C** | **Missing-value contract** *(standalone, never diluted)* | Single NA helper, read/write sweep, literal-`"NA"` round-trip guard. Bytes on disk — it wants an undiluted diff |
| **D** | **Validation hardening** | Primary-key uniqueness and NA errors, value-like-name warnings (thresholds exact; the message points at `melt`), placeholder surfacing |
| **E** | **Cache, environment and network robustness** | Index session caching; **call-time env read** (`SALMONPY_CACHE` is read at import today — the exact bug class R 0.2.2 fixed); the `SALMONPY_`→`METASALMONPY_` prefix rename, decided and logged here; http-error diagnostics; no-cache-on-degraded; KNB dry-run overwrite; retry and `Retry-After`; BioPortal header auth |
| **F** | **Redaction** | Structural `*_token` redaction; assert exactly **one** redactor |
| **G** | **Legacy read compatibility** *(verify, do not rebuild)* | Reading 0.2.x-written packages that carry a methods registry, and 0.1.8-era EML quoting procedures from one. Landed at rung 2 — confirm it survives A |

Ordering: **A → B**, C standalone and undiluted, D/E/F independent of each
other, G verified after A. One version bump to **0.3.0** at the end, not one per
chunk.

**Verification changes with the plan.** Differential runs go against the
**`v0.3.0` tag** (annotated, so `git archive v0.3.0 | tar -x` is exact), not
against era tags. A byte-equality claim measured at or after R 0.2.0 needs no
locale caveat — R adopted C collation at 0.2.0 — while anything measured
against ≤0.1.8 does. Say which was used.

**The behaviour-defined scope survives unchanged.** Chunks A and B MUST carry
metasalmon's post-0.3.0 fixes, not just the release tree: the three
`statistical_modifier` ranking rows, the corrected bundle-review prompt, the
dry-run stop parity, and the six-surface role-contract guard. If a pin and that
list ever disagree, the list wins — it is the reason the pin exists.

## 0.1.7 progress (2026-08-16)

Four chunks committed on `feat/s10-017-parity`, none released — the version
stays 0.1.6 until the milestone completes, per the parity-claim rule.

| Chunk | What | Parity evidence |
|---|---|---|
| 1 | SSSOM 1.1 read/write/validate | Canonical TSV **byte-identical** to era R under C collation; three R-generated fixtures assert sha256 |
| 2 | Measurement decompositions (era shape, transitional `method` role) | Byte-identical, **unconditionally** — the only chunk whose claim needs no locale caveat |
| 3 | Reviewed EML 2.2.0 export | `ET.canonicalize`-equal to R; every UUIDv5 identifier exact |
| 4 | KNB/DataONE via raw REST, era 14-method adapter | Plan fingerprint, manifests, PIDs, Solr URL byte-exact; ORE + 9 SystemMetadata shapes canonically equal |

Then twelve defects from an adversarial review, each demonstrated against a
v0.1.7 extraction and each pinned by a test that fails on a source-reverted
build (38 failures confirmed). Deviations recorded as register rows 20–24.

**Milestone complete.** 0.1.7 shipped 2026-08-16 — merged, version bumped,
tagged `v0.1.7`, GitHub Release published. The two defects listed here as
remaining (`sssom.py`'s ASCII-only `\s`/`\S` against era R's Unicode-aware TRE,
and `package_io.py:538` taking pandas' full NA vocabulary untrimmed) were folded
in before the bump. Two Codex findings were also fixed at review: the
`atomic_io` umask dance, which two concurrent writes could leave permanently at
`000`, now measures the mode from a throwaway file instead of mutating process
state; and `eml.py` accepts a bare relative output path, which R already did.

### A correction that moves a later rung

The register's row 20 said R adopted C collation at 0.3.0. **It was 0.2.0** —
`R/sssom.R` uses `method = "radix"` throughout from that release. The locale
hazard is live only against era R (≤ 0.1.8). Two consequences: the 0.3.0 rung
below must NOT be relied on to deliver collation convergence, since it already
happened three rungs earlier; and any byte-equality claim measured against era
R needs its locale caveat, while one measured against 0.2.0+ does not. This is
also why an era claim must name the tag it was measured at — the same
comparison run against current `main` silently answers a different question.

## 0.1.8 progress (2026-08-17)

**Milestone complete.** 0.1.8 shipped 2026-08-17 — metasalmonpy PR #8 merged
as `db85016`, version bumped, tagged `v0.1.8`, GitHub Release published. The
rung carried the SDP method registry as **read and validate only**, the
writer landing as an exported raising stub rather than being absent (the
logged writer-only-skip decision above, now register row 9 and marked
*landed* rather than *planned*); observation structures; the reproducibility
manifest; reviewed-strategy apply; expanded KNB publication; the `package_io`
host fix; and the demo-data and `match_type` ranking fixes. The vendored
schema bundle now comes from the upstream `sdp-0.2.0` tag, which discharges
register row 27's retirement condition — the Python profile version is no
longer a literal — and creates row 30, which describes how that bundle is
read.

Verified the way the rung above was: by driving both implementations over the
same inputs against the R **`v0.1.8` tag**, not by reading R source.
`methods.csv`, both observation-structure files and the updated
`datapackage.json` came out byte-identical, and the KNB plan matched on all
20 objects — every PID and every checksum.

Deviations recorded as register rows 29–34. Two of them are about the same
mistake in opposite directions, and both are worth carrying forward. Row 34:
mirroring R's helper *layout* imported a constraint R does not have — `yaml`
is a hard `Imports` here, PyYAML is an extra there — and made the pure-stdlib
SDP archive require the `[eml]` extra to build; the fix moved the
reviewed-ledger binding assertions into the publication preflight, and the
core-deps property is now enforced by CI and by a `sys.meta_path` blocker
rather than asserted in prose (row 30). Row 29 is the converse: R had applied
the honest-provenance ruling to the reproducibility manifest's writer and not
its reader, so R **rejected** a Python-written manifest and, through
`R/knb-publication.R:297`, refused to publish any Python-written SDP to KNB.
Fixed R-side post-0.3.0 (backlog #88), with the accepted writer set
consolidated into `R/provenance.R` so a fourth manifest type inherits dual
acceptance instead of re-deriving it.

**Next rung: 3 — `0.2.0 + 0.2.1` collapsed.** It is also the first of the two
rungs whose verification is the R↔Python round-trip (see *Verification*
below), which is why #88 had to be fixed before it starts rather than during
it.

## Sidecar-survival rule

Sidecars appear at PRs 1–2 but read→edit→write preservation is a PR-3
contract in R's chronology. Implement preservation for each sidecar AS IT IS
INTRODUCED — reproducing R's window costs nothing and avoids tagged states
that drop reviewed artifacts.

## Out of scope, logged

- `ontology_fetch.py:15` old host: R is also stale here and the paths
  diverge — a separate cross-repo coordination task, not an S10 item.
- `term_requests.py:19` `GCDFO_REPO` old org: matches current R; stays in
  lockstep until either repo fixes it first.
- Interactive cancel-must-not-submit (R 0.2.0): Python has no interactive
  term-request console — inapplicable, exception register.
- Locale/radix sweeps: Python `sorted()` is codepoint-ordinal — mirror the
  determinism TESTS plus a no-`locale.strxfrm` guard, not the fix.
- **The ranking-profile gap predates this replay and no rung covers it**
  (backlog #87, parity-deviations row 32). Python's `_score_and_rank_terms`
  has no `ranking_profile` argument and no equivalent of
  `.ranking_profile_defaults()`/`.merge_ranking_profile()`, and its inlined
  weights differ from R's across base source weights, the unknown-source
  fallback, role boosts for every role but `unit`, and the vocabulary bonuses
  — which differ in gating as well as magnitude. Candidate *order* therefore
  differs for the same query. This is **older than the 0.1.6 claim**, so no
  rung below inherits it: the 0.1.7 rung's `match_type` fix touches the ladder
  inside the scorer, not the profile system around it, and the 0.3.0 rung's
  `statistical_modifier` ranking-preferences rows are data for a system Python
  does not have. Logged here as deliberately out of scope so the omission is
  visible; it needs a rung or its own stream before any milestone verification
  depends on ranking order. Note while sequencing that
  `benchmark_term_ranking_fixtures` — the surface that would *measure* a
  ranking regression — accepts `profiles` and discards them on the Python
  side, so it cannot currently serve as the check for any rung.

## Verification

Per milestone: pytest green, the milestone's R-derived fixtures pass, and
the two version strings agree. At PR 3 and PR 8: an R↔Python round-trip
(package written by one, read and validated by the other) against the spec
example packages. The `parity.yml` archive job asserts contracts, not bytes.
