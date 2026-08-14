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
   (untagged releases, gcdfo's non-monotonic 0.0.999, the spec's undated
   sdp-0.2.0) are this sub-stream's first work items.
4. ~~Publish the smn/gcdfo boundary as data~~ — **moved to S9 step 3.**
5. ~~Method / protocol / procedure canonical style (#76)~~ — **moved to S9
   step 2** (still blocked by S8, which names the concepts first).
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

The generic consumer work starts only after all of these hold:

1. Brett HQ activates the implementation child and the canonical strategy still
   supports the accepted PSC-semantic/CAMP-operational jurisdiction split.
2. PSC-1 releases a stable mapping-product metadata/profile contract and
   immutable test fixture; the current alpha.3 PSC-to-SMN set is predecessor
   evidence, not yet a strict-reader-valid fixture. It includes source/version
   metadata
   but omits `sssom_version: 1.1`, so the strict R reader rejects it. Its branch
   also deletes the pinned alpha.2 Adapter route and gives PSC-CV-000017 an
   exact-chain rationale despite a gcdfo `closeMatch`; PSC-0A must repair or
   split those release defects before the umbrella MR deploys.
3. S10 brings metasalmonpy through the existing SSSOM contract. New FAIR
   envelope, pin, archival, and provenance behavior then lands in R and Python
   in the same stream unless mirror governance records why not.

The implementation reuses `R/sssom.R` for identified concept mappings and
keeps its rejection of raw literals and ordered decompositions. New code is
limited to verifying the FAIR product envelope and immutable release pin,
dispatching each identified-concept distribution to the existing strict
validator, archiving reviewed bytes, and recording product IDs, versions, and
hashes in SDP provenance. It may preserve a neutral compatibility link but does
not interpret it. SSSOM parsing is not mapping execution: a later plan must
define predicate direction, cardinality, gaps, and multiple-target behavior
before applying rows. Candidate generation and review tooling may produce
evidence; it never publishes an approved mapping automatically.

Generic consumption does **not** wait on S8. The later NuSEDS migration remains
inactive until NUSED-0 records source identity, licence, publication home,
source/domain authority, correction route, and explicit HQ activation. It also
waits for the S8 implementation to be reconciled and delivered with required
R/Python parity and for any required shared analytical-method targets to exist
or remain explicit gaps. The existing exported R crosswalk functions stay as
compatibility adapters over a future governed pin; no package becomes the
mapping authority.
