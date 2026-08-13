---
type: InformationObject
title: "S3 — KNB staging environment"
description: "A guarded knb_environment switch so deposits can be rehearsed against the KNB staging node instead of production."
status: draft
tags: [knb, publication]
psc:
  id: metasalmon:sequence:s3-knb-staging
  contexts: [metasalmon:context:hub-coordination]
---

# S3 — KNB staging environment

**Execplan:** [KNB environments and workshop rebuild](../plans/2026-08-11-knb-environments-and-workshop-rebuild.md)

A guarded `knb_environment = "production" | "staging"` so the workshop — and any
new user — can rehearse a deposit without writing to the production KNB node.

**Blocks S4.** The workshop cannot teach a rehearsal that does not exist, and it
pins an exact released metasalmon version.

**Not blocked by S1**, but see the execplan's *Sequencing* section: shipping S3
before S1 means the staging rehearsal validates with the same under-checking
validator — acceptable for a rehearsal, not for the claim "validation is your
final gate."
