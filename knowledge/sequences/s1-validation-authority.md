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
additionally checks no required-column nullability, no schema-required metadata
fields, and reports success on corrupt SSSOM/decomposition artifacts.
**Declared primary keys are now checked** — 0.2.6 made a duplicate, missing, or
absent key component a hard error under #77, so that item has dropped off S1's
list even though it was #49's first example.

**Why early:** everything downstream borrows its credibility. S4 teaches
validation as the final gate before deposit; teaching that while the gate
under-checks is the one sequencing mistake worth avoiding.

**The S8 precondition is met.** S1 builds the machinery that executes the rules
the spec declares, and S8 changed which rules it should declare — building the
machinery first and then changing its inputs was the avoidable version of this
work. S8 shipped as 0.3.0 against `sdp-0.3.0`, so S1 now has a settled rule set
to drive from and no longer needs to wait or interleave.

**The change that stops it recurring:** a conformance test that fails when the
spec declares a rule the implementation does not execute. Drive the checks from
the parsed rule ids.

**Cross-repo:** needs `smn-data-pkg` to have a LICENSE, CI, and Pages config, and
the nine prose-only rules expressed machine-readably. The metasalmon-side work is
self-contained; only the *authority* question is shared. **Mirror rule:** the
validator changes land in metasalmonpy in the same stream.
