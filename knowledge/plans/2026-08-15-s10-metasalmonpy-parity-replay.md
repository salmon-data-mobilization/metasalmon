---
type: Artifact
title: "S10 metasalmonpy parity replay 0.1.6 → 0.3.0"
description: "ExecPlan for the nine-PR release-by-release replay bringing the Python mirror from its 0.1.6 parity claim to metasalmon 0.3.0, with the registry writer-skip and pandas-NA decisions logged."
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

## The nine-PR ladder

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
4. **0.2.2 + 0.2.3 (collapse optional)** — index session caching, call-time
   env read (`SALMONPY_CACHE` is read at import today — the exact bug class
   R 0.2.2 fixed; also decide the `SALMONPY_`→`METASALMONPY_` prefix rename
   here and log it), http-error diagnostics, no-cache-on-degraded; KNB
   dry-run overwrite, retry/`Retry-After`, BioPortal header auth. Split if
   the KNB overwrite work runs heavy.
5. **0.2.4 standalone, never collapsed** — the missing-value contract
   (single NA helper, read/write sweep, literal-"NA" round-trip guard).
   Bytes-on-disk; wants an undiluted diff. `ms_setup_github` already landed
   drift-ahead — verify tests only.
6. **0.2.5** — structural `*_token` redaction; assert exactly one redactor.
7. **0.2.6** — primary-key uniqueness/NA errors, value-like-name warnings
   (thresholds exact; the message points at `melt`), placeholder surfacing.
8. **0.3.0 standalone, atomic** — dictionary contract flip (including the
   bundled template header: Python's template is well-formed but still ends
   `method_iri`), registry removal + migration-pointing errors,
   `migrate_sdp_methods` with the full hardened stop taxonomy, every one of
   which must fire in the dry run as well as the real run, semantic
   retarget, EML placements + review-closure gating + return shape,
   default/strict placement IRI checks, pin flip to `sdp-0.3.0`. Port the R
   fixtures from the merged release tree (`5a37b11`) as pytest first —
   **but refresh that pin before the port starts.** `5a37b11` predates the
   role-contract and dry-run fixes on `fix/role-contract-leftovers`, so
   replaying it literally reproduces the pre-fix suite: no dry-run regression
   test for the undeclared-table stop, no static role-contract guard, and the
   REVIEW-only fixture still reaching around
   `add_legacy_dictionary_methods()`. Re-pin to that branch's merge commit,
   which does not exist yet. A pin naming a tree older than the fixes it is
   meant to carry is how the gap above survives into Python.

   **The rung's scope is defined by behaviour, not by a commit hash**, so it
   survives a stale pin. The 0.3.0 rung MUST carry, in addition to the release
   tree: three `statistical_modifier` rows in the ranking-preferences data
   (the role otherwise ranks with no source preferences at all); the bundle
   review prompt naming `statistical_modifier` rather than the removed
   dictionary `method` slot; every migration stop firing in the dry run; and
   a static role-contract guard covering all six surfaces a role touches.
   Python's own preference data still carries the pre-0.3.0 role set, so the
   first three are net-new work there, not a copy. If the pin and this list
   ever disagree, this list wins — it is the reason the pin exists.

Hard ordering: 0 → 1 → 2 → 3 (loader needs the host fix; typed reader
precedes the NA tightening) → … → 5 before any adoption push → 8 last.

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
