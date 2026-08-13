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
