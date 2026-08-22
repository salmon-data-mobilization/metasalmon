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
the gate under-checks. Confirmed premise, re-verified after sdp-0.3.0 rewrote
the rule set: **zero of the 14 rule ids in
`sdp.rules.yaml` appear anywhere in `R/`** — the validator reimplements the spec
by hand, so spec and implementation can diverge silently, and three
error-severity rules are loaded and never executed. `validate_salmon_datapackage()`
additionally checks no required-column nullability, no schema-required metadata
fields, and reports success on corrupt SSSOM/decomposition artifacts.
**Declared primary keys are now checked** — 0.2.6 made a duplicate, missing, or
absent key component a hard error under #77, so that item has dropped off S1's
list even though it was #49's first example.

**The gap now has a measured size, and it is bigger than the card's list.**
First measurement, 2026-08-21, on the bundled 173-row Fraser coho example:
`create_sdp()` → `write_salmon_datapackage()` → both validators. metasalmon
returns a **0-row issues tibble** — no findings at all — while
`scripts/validate_package.py` from a `smn-data-pkg` checkout reports **27
errors** on the same bytes. So the divergence this stream exists to close is
not a handful of unexecuted rules; on the one artifact anyone actually runs it
is total.

**22 of the 27 are a class this card has never named**: `codes.csv` rows
targeting a column `infer_column_role()` typed `attribute` where the spec
requires `categorical` (backlog **#95** — one error per code row across six
columns). They are self-inflicted, in the sense that the *same* `create_sdp()`
call writes both sides of the contradiction and prints "Dictionary validation
passed" between them. The remaining five are the four blank measurement IRIs
and the placeholder license, which the console does announce. Whether the fix
belongs to `infer_column_role()` or to the code-row seeder is #95's open
question, not S1's — but S1 is where the *detection* has to land, because
nothing in metasalmon reports the class at all today.

**Why early:** everything downstream borrows its credibility. S4 teaches
validation as the final gate before deposit; teaching that while the gate
under-checks is the one sequencing mistake worth avoiding.

**But do not start before #90 is ruled.** S1's premise is that there is one
authority — the spec declares the rules and the validator executes them.
Backlog **#90** is the live counterexample: `smn-data-pkg` currently speaks
with four voices that disagree about descriptor `schema.fields`
(`SPECIFICATION.md` prose, `sdp.rules.yaml`, the published v0.3 profile, and
`scripts/validate_package.py`), and **which of them is normative has not been
ruled**. Every annotated SDP either mirror writes fails the script while
satisfying the profile. Building a conformance test that drives from one of
those artifacts before Brett says which one is authoritative would freeze the
answer by implementation rather than by decision — and a conformance test is
exactly the thing nobody re-examines afterwards. The ordering is not about
effort: #90's ruling is what tells S1 *what to conform to*.

**The S8 precondition is met.** S1 builds the machinery that executes the rules
the spec declares, and S8 changed which rules it should declare — building the
machinery first and then changing its inputs was the avoidable version of this
work. S8 shipped as 0.3.0 against `sdp-0.3.0`, so S1 has a settled rule *set* to
drive from and no longer waits on **S8**. It does wait on **#90**, which is a
different question — not which rules exist, but which artifact declares them.

**The change that stops it recurring:** a conformance test that fails when the
spec declares a rule the implementation does not execute. Drive the checks from
the parsed rule ids.

**Cross-repo — the "no LICENSE, CI, or Pages configuration" ask has split, and
carrying it as one line hid that a third of it is done.** Checked 2026-08-21:

- **LICENSE — still absent.**
- **CI — still absent**, and no longer hypothetical: `smn-data-pkg` has no
  `.github/` directory at all, and 4 of its 23 tests fail on `main` with nobody
  watching (backlog **#103**). All four assert the pre-0.3.0 method registry.
- **Pages — configured and serving.** `salmon-data-mobilization.github.io/smn-data-pkg/`
  returns 200, and the **v0.3 profile URL resolves** — which matters to S1
  directly, because that profile is one of the four candidate authorities #90
  is about. Four *other* documentation paths cited by `README.md` and
  `docs/entrypoints.md` are published 404s (backlog **#105**); a serving site
  is not a correct one.

The nine prose-only rules still need machine-readable expression. The
metasalmon-side work is self-contained; only the *authority* question is
shared. **Mirror rule:** the validator changes land in metasalmonpy in the same
stream — and note metasalmonpy's issue system is a different mechanism, not a
smaller one (backlog **#91**), so "both sides report N issues" is not available
as a parity check for this stream until #91 closes.
