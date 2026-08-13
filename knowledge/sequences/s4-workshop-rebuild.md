---
type: InformationObject
title: "S4 — Workshop rebuild"
description: "Rebuild the salmon-data-standards-workshop: nine episodes, R-led with Python equivalents, executing against released metasalmon and metasalmonpy."
status: draft
tags: [workshop, teaching]
psc:
  id: metasalmon:sequence:s4-workshop-rebuild
  contexts: [metasalmon:context:hub-coordination]
---

# S4 — Workshop rebuild · repo: `salmon-data-standards-workshop`

**Execplan:** [KNB environments and workshop rebuild](../plans/2026-08-11-knb-environments-and-workshop-rebuild.md)

Nine episodes, R-led with visible Python equivalents and two interleaved Excel
passes. Hard-blocked by **S3** (staging target) and by **S8** for its
method-annotation content; reads better after **S1**. The Python equivalents
execute against **metasalmonpy**, which makes S10 parity a soft dependency —
episodes must not demo Python behaviour that only exists in R.

Once the episodes execute against released packages, the workshop becomes an
integration test of the public API — which is where stale-call bugs get caught
for free. That is the strategic reason to finish it, beyond teaching.
