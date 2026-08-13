---
type: InformationObject
title: "S6 — Ecosystem hardening"
description: "The remaining cross-repo work not absorbed by S9: gcdfo quality-gate fixes, vocabulary release pinning, policy scheme population, and governance. Backlog items 44 and 61."
status: draft
tags: [ecosystem, governance]
psc:
  id: metasalmon:sequence:s6-ecosystem
  contexts: [metasalmon:context:hub-coordination]
---

# S6 — Ecosystem hardening · #44, #61 · parallel track, mostly not R code

**Execplans:** [gcdfo validation layer verification](../plans/2026-08-10-gcdfo-validation-layer-verification.md)
(#44, verified) · remainder to be written per sub-stream.

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
