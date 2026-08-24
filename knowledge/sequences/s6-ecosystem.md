---
type: InformationObject
title: "S6 — Ecosystem hardening and governed mapping products"
description: "The remaining cross-repo work not absorbed by S9: quality gates, vocabulary release pinning, governed FAIR mapping-product consumption, policy schemes, and governance. Backlog items 44 and 61."
status: draft
tags: [ecosystem, governance]
psc:
  id: metasalmon:sequence:s6-ecosystem
  contexts: [metasalmon:context:hub-coordination]
---

# S6 — Ecosystem hardening and governed mapping products · #44, #61

**Execplans:** [gcdfo validation layer verification](../plans/2026-08-10-gcdfo-validation-layer-verification.md)
(#44, verified) · [governed mapping products](../plans/2026-08-14-governed-mapping-products.md)
(planning only; implementation dependency-gated) · remainder to be written per
sub-stream.

Highest strategic value, least code. Run alongside S1–S5. Ordered:

1. **Verify the 27 finder-only ontology findings** — cheap and mechanical.
   #44 already did three and all three held, so expect a high confirmation rate.
2. **Fix #44** so the gcdfo quality gates stop being placebos.
3. **Vocabulary-release pinning** — monotonic versions, real `owl:versionIRI`,
   immutable release snapshots, then thread the resolved release into
   metasalmon's output and the KNB transformation record.
   **metasalmon's own KNB documentation states this as a precondition and it
   cannot be satisfied today**, which makes it a soft dependency of S4.
   The release-index discrepancies recorded in the [roadmap card](../roadmap.md)
   are this sub-stream's first work items: missing release objects (both
   `smn-data-pkg` spec tags; PSC alpha.3) and incomplete cross-repository
   release mechanics. **Not gcdfo's non-monotonic `0.0.999`** — that is now
   documented in gcdfo's own README and CHANGELOG as a deliberate abandoned
   numbering experiment, with the rule that the version line does not exceed
   it, so it is a recorded anomaly rather than an open item.
4. ~~Publish the smn/gcdfo boundary as data~~ — **moved to S9 step 3.**
5. ~~Method / protocol / procedure canonical style (#76)~~ — **completed by
   S9 step 2** after the S8 model decision; SMN 0.0.3 carries the released
   shared semantic result. The R-package implementation state is separate and
   is also done: PR #39 merged 2026-08-15 and shipped as 0.3.0.
6. **Populate the three empty policy schemes** (PA zones, COSEWIC, benchmarks).
   Highest-value single ontology change for real users: today term search finds
   nothing and falls back to `REVIEW:` placeholders.
7. ~~Fix the I-ADOPT layer~~ — **moved to S9 step 1.**
8. **Governance** — machine-readable licence in the TTL, real `CITATION.cff`,
   named editorial authority and review SLA, org-owned URLs, one accurate
   `entrypoints.md` per repo.

## gcdfo docs-pipeline gate substream

The gcdfo documentation build had a **placebo gate**: its WebVOWL normalizer
crashed on every run, but the `docs-widoco` recipe was a `;`-chained shell
without `set -e`, so `make` reported the trailing `echo`'s status and printed
success — and CI separately excluded the affected artifact from its
dirty-tree check. The exclusion predated the normalizer by five weeks: a
workaround that outlived its cause and then concealed a failure it was never
written for.

**Sequenced work, in order:**

1. **Make the gate able to fail** — fix the normalizer crash (colliding
   `xsd:gYear` nodes, resolved by widening the key rather than merging nodes,
   which would silently change the rendering), add `set -e` to the affected
   recipes, and remove the stale CI exclusion. *Landed as a gcdfo PR; verified
   green on a clean CI runner with the exclusion removed, which is what
   establishes cross-platform byte-stability of the normalizer output.*
2. **Fix the self-seeding baseline** — the recipe snapshots the working-tree
   artifact as the normalizer's baseline, then overwrites that same path with
   raw output before the normalizer runs, so a failed build seeds its own
   baseline and the next run goes green over un-normalized output. Tracked as
   the first entry in [backlog.md](../backlog.md) with its mechanism, fix
   path, verification trap, and retirement condition. ~~Blocked on step 1~~ —
   **unblocked**: step 1 landed (gcdfo `Makefile` now carries `set -e` in the
   docs recipes and CI has no exclusion), so the recipe can fail and this is
   actionable now.

Retires when step 2 ships and its `docs/tech-debt.md` entry in gcdfo is
deleted at the same time.

## Governed mapping-product consumer substream

This is a parallel, dependency-gated part of S6. PSC GitLab MR !5 (merged
2026-08-16; no longer a draft) is the
mapping-product dependency specification; released products remain authoritative
in their semantic-asset repository. This hub coordinates consumers and release
pins only. Brett HQ remains the program activation authority, and neither this
card nor a passing validator confers scientific approval.

The **eight** repositories in the ecosystem domain card are an allowlist (eight since 2026-08-24, when Brett ruled that membership follows from this hub sequencing a repository's work and admitted `salmon-data-standards-workshop` as the eighth). The
[roadmap's external dependency ledger](../roadmap.md#cross-program-authority-boundary)
is the only hub record for `psc-data-systems`, `psc-data-systems-site`,
`campModelInput`, and `ctc-knowledge-map`: shared tooling, documentation links,
consumer handoffs, and descriptive evidence do not transfer their tasks,
status, branches, approvals, or releases into S6.

The generic consumer work starts only after all of these hold:

1. Brett HQ activates the implementation child and the canonical strategy still
   supports the accepted PSC-semantic/CAMP-operational jurisdiction split.
2. PSC-1 releases a stable mapping-product metadata/profile contract and
   immutable test fixture. [Nested PSC MR !8](https://gitlab.com/pacific-salmon-commission/psc-data-systems/psc-salmon-vocabularies/-/merge_requests/8)
   repairs PSC-0A at `a2ca4ee`:
   its nine-row alpha.3 PSC-to-SMN candidate declares strict SSSOM 1.1 and
   passes the current R reader, the unsupported PSC-CV-000017 proposal is
   deferred, and protected Adapter routes remain present. That is publisher-
   consumer interoperability evidence, not a released PSC-1 profile or fixture.
   **Both MRs have merged** (!8 into the umbrella branch, then !5 into main),
   so the review-and-merge half of this gate is met; what remains unmet is the
   *release* half — alpha.3 is still untagged, with no GitLab Release object,
   and `pyproject.toml` still reads `0.1.0a1`.
3. S10 brings metasalmonpy through the complete current released R baseline,
   including 0.3.0 — PR #39 merged 2026-08-15, so the baseline is metasalmon
   main at merge `5a37b11` (never an intermediate review-round commit; see the
   [S10 replay execplan](../plans/2026-08-15-s10-metasalmonpy-parity-replay.md)).
   An isolated SSSOM port is insufficient parity. New FAIR envelope, pin,
   archival, and provenance behavior then lands in R and Python in the same
   stream unless mirror governance records why not.

The implementation reuses `R/sssom.R` for identified concept mappings and
keeps its rejection of raw literals and ordered decompositions. New code is
limited to verifying the FAIR product envelope and immutable release pin,
dispatching each identified-concept distribution to the existing strict
validator, archiving reviewed bytes, and recording product IDs, versions, and
hashes in SDP provenance. It may preserve a neutral compatibility link but does
not interpret it. PID-1 has selected readable stable product slugs under
`/mappings/`. COMPAT-1 permits a publisher's qualified expected-compatibility
assertion only when each consumer independently verifies and accepts or rejects
it; that evaluation belongs to a later contract, not META-1. SSSOM parsing is
not mapping execution: a later plan must
define predicate direction, cardinality, gaps, and multiple-target behavior
before applying rows. Candidate generation and review tooling may produce
evidence; it never publishes an approved mapping automatically.

Generic consumption has no semantic dependency on S8. Its full-S10 gate is a
package-parity rule, not a method-model prerequisite. The later NuSEDS migration
remains inactive until NUSED-0 records source identity, licence, publication
home, source/domain authority, correction route, and explicit HQ activation.
Its R-side prerequisite is satisfied — PR #39 merged and shipped the method
model as 0.3.0 — so what it still waits on is S10 replaying that release in
Python, and any required shared analytical-method targets existing or remaining
explicit gaps. The existing exported R
crosswalk functions stay as compatibility adapters over a future governed pin;
no package becomes the mapping authority.
