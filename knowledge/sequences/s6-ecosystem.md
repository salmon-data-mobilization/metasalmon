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
   (missing release objects, gcdfo's non-monotonic 0.0.999, and incomplete
   cross-repository release mechanics) are this sub-stream's first work items.
4. ~~Publish the smn/gcdfo boundary as data~~ — **moved to S9 step 3.**
5. ~~Method / protocol / procedure canonical style (#76)~~ — **completed by
   S9 step 2** after the S8 model decision; SMN 0.0.3 carries the released
   shared semantic result. Open metasalmon PR #39 is a separate R-package
   implementation state.
6. **Populate the three empty policy schemes** (PA zones, COSEWIC, benchmarks).
   Highest-value single ontology change for real users: today term search finds
   nothing and falls back to `REVIEW:` placeholders.
7. ~~Fix the I-ADOPT layer~~ — **moved to S9 step 1.**
8. **Governance** — machine-readable licence in the TTL, real `CITATION.cff`,
   named editorial authority and review SLA, org-owned URLs, one accurate
   `entrypoints.md` per repo.

## Governed mapping-product consumer substream

This is a parallel, dependency-gated part of S6. PSC draft GitLab MR !5 is the
mapping-product dependency specification; released products remain authoritative
in their semantic-asset repository. This hub coordinates consumers and release
pins only. Brett HQ remains the program activation authority, and neither this
card nor a passing validator confers scientific approval.

The six repositories in the ecosystem domain card are an allowlist. The
[roadmap's external dependency ledger](../roadmap.md#cross-program-authority-boundary)
is the only hub record for `psc-data-systems`, `psc-data-systems-site`,
`campModelInput`, and `ctc-knowledge-map`: shared tooling, documentation links,
consumer handoffs, and descriptive evidence do not transfer their tasks,
status, branches, approvals, or releases into S6.

The generic consumer work starts only after all of these hold:

1. Brett HQ activates the implementation child and the canonical strategy still
   supports the accepted PSC-semantic/CAMP-operational jurisdiction split.
2. PSC-1 releases a stable mapping-product metadata/profile contract and
   immutable test fixture. [Nested PSC draft MR !8](https://gitlab.com/pacific-salmon-commission/psc-data-systems/psc-salmon-vocabularies/-/merge_requests/8)
   repairs PSC-0A at `a2ca4ee`:
   its nine-row alpha.3 PSC-to-SMN candidate declares strict SSSOM 1.1 and
   passes the current R reader, the unsupported PSC-CV-000017 proposal is
   deferred, and protected Adapter routes remain present. That is publisher-
   consumer interoperability evidence, not a released PSC-1 profile or fixture;
   MR !8 must be reviewed and merged before umbrella MR !5 may deploy.
3. S10 brings metasalmonpy through the complete current released R baseline,
   including 0.3.0 if open green PR #39 at `f76ed4f` has merged and released by
   then. An isolated SSSOM port is insufficient parity. New FAIR envelope, pin,
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
It additionally waits for PR #39 to merge and ship the R method-model release,
for S10 to replay that release in Python, and for any required shared analytical-
method targets to exist or remain explicit gaps. The existing exported R
crosswalk functions stay as compatibility adapters over a future governed pin;
no package becomes the mapping authority.
