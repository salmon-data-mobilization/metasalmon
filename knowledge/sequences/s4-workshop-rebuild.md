---
type: InformationObject
title: "S4 — Workshop rebuild"
description: "Rebuild the salmon-data-standards-workshop: nine episodes, R-led with Python equivalents, executing against released metasalmon and metasalmonpy. The current lesson is four releases behind and teaches a removed field."
status: draft
tags: [workshop, teaching]
psc:
  id: metasalmon:sequence:s4-workshop-rebuild
  contexts: [metasalmon:context:hub-coordination]
---

# S4 — Workshop rebuild · repo: `salmon-data-standards-workshop`

**Q2 answered 2026-08-22 (Brett): currency pass first — landed 2026-08-21 as
workshop PR #4 — then the golden-path/rebuild work after the KNB test
environment's API workability is determined.** Q1's environment half is now
verified (mnTestKNB live at dev.nceas.ucsb.edu; see the S3 card), so
workability reduces to a token plus one successful end-to-end test deposit.
The golden-path section unblocks the moment that deposit succeeds.

**Execplan:** [KNB environments and workshop rebuild](../plans/2026-08-11-knb-environments-and-workshop-rebuild.md)

Nine episodes, R-led with visible Python equivalents and two interleaved Excel
passes. The **S8 blocker is discharged** — the method model shipped as
metasalmon 0.3.0 against `sdp-0.3.0`, so the method-annotation content has a
released contract to teach, and what it teaches is the three placements, not a
dictionary method slot. The Python equivalents execute against
**metasalmonpy**, which makes S10 parity a soft dependency — episodes must not
demo Python behaviour that only exists in R.

Once the episodes execute against released packages, the workshop becomes an
integration test of the public API — which is where stale-call bugs get caught
for free. That is the strategic reason to finish it, beyond teaching.

## What the current lesson is, today

**2026-08-21 currency pass landed** (workshop PR #4, merged; the post-merge
site deploy is green). Fixed: metasalmon is in the lesson lockfile pinned to
the **v0.3.0 release tag** with its dependency tree snapshotted, and a hidden
`library(metasalmon)` chunk proves the pin loads at every build; the four
session-6 chunks no longer publish R error blocks — they are `eval = FALSE`
**honestly**, because with metasalmon installed they still fail for
non-currency reasons (learner-session state, a reviewed sidecar the lesson
must not fabricate, an interactive upload), and making them genuinely execute
IS the golden path, blocked on Q1/Q2; `method_iri` teaching corrected to the
0.3.0 three-placement shape in session-4 and the learner reference;
`setup.md`'s pre-rename metaSmnPy wheel replaced with the metasalmonpy v0.2.1
tag tarball (releases carry no wheel assets) — **now itself stale: the mirror
released `v0.4.0` on 2026-08-24, so the rebuild pins that tarball, not v0.2.1.**
**Still absent, rebuild scope:**
primary-key and tidy-shape content. One Q1-relevant observation: session-6's
KNB text already describes the production private-review model, i.e. the
lesson as written agrees with psc-data-transformations' staging claim, not
with the S3 execplan's unverified test-node registry.

**The rebuild has not begun, and this card said nothing about the thing being
rebuilt** — which made "S4 is blocked" read as "nothing is wrong yet".
Something is wrong now. Measured against the repository, 2026-08-21:

**Last commit 2026-08-11** (`b080fc9`, "Update workshop for EML publication
workflow"). It targets **metasalmon 0.2.3** by name (`learners/setup.md:73,77`;
`episodes/session-1.Rmd:166`, and again in sessions 4 and 6). Four releases have
shipped since — **0.2.4, 0.2.5, 0.2.6, 0.3.0 — two of them breaking**
(0.2.4's empty-field missing-value token, 0.3.0's dictionary contract). The
lesson's own setup page tells the instructor to "check the changelog before
teaching if the version has moved"; it has moved four times.

**It still teaches `method_iri`, which 0.3.0 removed.** `episodes/session-4.Rmd:145`
puts it in the dictionary-field table (*"What method or procedure matters for
interpretation…"*) and `:147` explains where it sits relative to I-ADOPT;
`learners/reference.md:97,149,151` repeat it in the SOSA row, the field table,
and the do-not-misuse rule. A learner following session 4 today writes a column
into a dictionary slot that no longer exists — and the failure mode is not a
clean error but a migration path (`migrate_sdp_methods()`) they have never heard
of.

**Four session-6 chunks will render R errors into the published site.**
`renv/profiles/lesson-requirements/renv.lock` pins 40 packages and
**`metasalmon` is not one of them** (zero matches). Session 6's four executable
chunks — `episodes/session-6.Rmd:318, 343, 357, 384` — call
`system.file(..., package = "metasalmon")`, `write_eml_from_sdp()` and
`publish_sdp_to_knb()`. They carry `purl = FALSE`, which keeps them out of the
extracted script and **does not stop them evaluating at render**. This is the
sharpest item on the list because it is the only one that publishes: the
others mislead a reader, this one puts a traceback on the site.

**Zero `primary_key` and zero tidy-shape content.** `primary_key`,
`pivot_longer`, "tidy data" and "long format" have **no occurrences** anywhere
in `episodes/`, `learners/` or `instructors/`. Since 0.2.6 a declared primary
key is enforced with hard errors, and `primary_key` is a shipped template
column — so the lesson does not mention the field whose misuse now aborts
validation. metasalmon's own `tidy-data-for-sdp.Rmd` (S11 slice 2) already
teaches both; the workshop has not inherited it.

**The Python path installs a pre-rename wheel.** `learners/setup.md:114`
installs `salmonpy 0.1.6` from
`github.com/salmon-data-mobilization/metaSmnPy/releases/download/v0.1.6/…` —
the repository was renamed to `metasalmonpy` on 2026-08-13, and the mirror is
now at **0.4.0** (released 2026-08-24; `v0.1.7`, `v0.1.8`, `v0.2.0`, `v0.2.1`
and `v0.4.0` tagged — there is no `v0.3.0`, which the mirror skipped by
[Q7](../questions.md)'s ruling). Whether that URL still redirects is not the
point: the lesson teaches an install of a package under a name that no longer
exists, now four parity milestones back.

*None of the above is rebuild scope creep — it is the reason the rebuild is
scoped as a rebuild.* Recorded here so that "S4 is blocked" stops being read as
"S4 is fine where it is".

## The S3 dependency is real but conditional

Hard-blocked by **S3** (a rehearsal target) — **if** OD-2 rules that "the KNB
test environment" means a distinct DataONE test node. It does not hold under
the other candidate ruling: if a restricted persistent version on production
KNB is accepted as the rehearsal, that path already exists in shipped form and
**S4 has no hard blockers left**. See
[OD-2](../roadmap.md#od-2--what-does-the-knb-test-environment-mean) for the
three candidates; this card takes no position.

Worth knowing while that is decided: **the current lesson already teaches the
production-restricted model.** `episodes/session-6.Rmd:376` tells learners *"A
live call creates persistent production KNB objects even when `public = FALSE`.
Private access is a review posture, not a server-side draft."* That is evidence
about what has been taught, not a ruling — and under a test-node ruling it is
text S4 has to change rather than inherit.

Reads better after **S1**: S4 teaches validation as the final gate before
deposit, and S1 is what makes that claim true.
