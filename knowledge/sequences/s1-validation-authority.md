---
type: InformationObject
title: "S1 — One validation authority"
description: "Make the validator execute the rules the SDP spec declares, with a conformance test that fails on spec/implementation divergence. Backlog items 48 and 49."
status: draft
tags: [validation, sdp]
psc:
  id: metasalmon:sequence:s1-validation-authority
  contexts: [metasalmon:context:hub-coordination]
---

# S1 — One validation authority · #48, #49

**Execplan:** to be written. Findings: [comprehensive ecosystem review](../plans/2026-08-10-comprehensive-ecosystem-review.md).

metasalmon is the workshop's designated final gate before DataONE deposit, and
the gate under-checks. Confirmed premise: **zero of the 13 rule ids in
`sdp.rules.yaml` appear anywhere in `R/`** — the validator reimplements the spec
by hand, so spec and implementation can diverge silently, and three
error-severity rules are loaded and never executed. `validate_salmon_datapackage()`
additionally checks no declared primary keys, no required-column nullability, no
schema-required metadata fields, and reports success on corrupt
SSSOM/decomposition artifacts.

**Why early:** everything downstream borrows its credibility. S4 teaches
validation as the final gate before deposit; teaching that while the gate
under-checks is the one sequencing mistake worth avoiding.

**But run S8 first or alongside.** S1 builds the machinery that executes the
rules the spec declares; S8 changes which rules it should declare. Building the
machinery and then changing its inputs is the avoidable version of this work.
#49's primary-key check is also #77's first gap, so the two streams overlap by
construction.

**The change that stops it recurring:** a conformance test that fails when the
spec declares a rule the implementation does not execute. Drive the checks from
the parsed rule ids.

**Cross-repo:** needs `smn-data-pkg` to have a LICENSE, CI, and Pages config, and
the nine prose-only rules expressed machine-readably. The metasalmon-side work is
self-contained; only the *authority* question is shared. **Mirror rule:** the
validator changes land in metasalmonpy in the same stream.
