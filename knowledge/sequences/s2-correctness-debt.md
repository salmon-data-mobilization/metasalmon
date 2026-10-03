---
type: InformationObject
title: "S2 — Correctness debt"
description: "Fix the silent-meaning-loss defects: four-digit measurement columns misclassified as temporal, and the remaining correctness cluster. Backlog items 53, 55, 56, 57."
status: draft
tags: [correctness]
psc:
  id: metasalmon:sequence:s2-correctness-debt
  contexts: [metasalmon:context:hub-coordination]
---

# S2 — Correctness debt · #53, #55, #56, #57

**Execplan:** to be written.

#53 (four-digit measurement columns classified as `temporal`, removing them from
the whole semantic pipeline) is the one that silently loses meaning; do it first.
#54, the other silent data-loss item in this cluster, shipped in 0.2.4.

Independent of S1 — can run in parallel. **Mirror rule:** each fix lands in
metasalmonpy in the same stream.


### Q71 ontology-fetch clarification, 2026-10-03

Brett's clarified cache behavior applies to both packages: continue with a
warning after failed refresh when the URL/Accept body matches; refuse
unrelated, mismatching or otherwise known-stale bodies. Failed refresh alone
does not establish staleness. The ruling introduces no freshness interval;
the exact text is in [Q71](../questions.md).

R's reconciliation belongs to B-422 in the existing
[PR211](https://github.com/salmon-data-mobilization/metasalmon/pull/211).
Its Python mirror belongs to B-423 in the existing
[PR75](https://github.com/salmon-data-mobilization/metasalmonpy/pull/75),
alongside B-334/B-336's fallback and cache-identity isolation. PR75 at
`acc1a57`, inspected on 2026-10-03, still raises for a matching cache after
failed refresh, so that behavior is an owed port in the same stream.
This is not a deliberate parity difference. Preserve the B-333/B-335
checkpoints and existing claims.
