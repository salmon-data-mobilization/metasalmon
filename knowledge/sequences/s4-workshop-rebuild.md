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

**That deposit succeeded 2026-08-25**: ten objects to `urn:node:mnTestKNB`,
`status: published_pending_catalog`, built entirely from the package's own
shipped example. The reproducible recipe is
`scripts/build-fraser-coho-knb-rehearsal.R`. **The golden path is unblocked**,
and session 6 now teaches its four prerequisites — including the one that has
no supported API (#116).

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

**Re-measured against the repository 2026-08-25. Most of what this section
previously asserted was no longer true, and is deleted rather than annotated —
a card that sends the next reader hunting for fixed defects is worse than no
card.** The inventory below is what a fresh check found; the deleted claims are
listed after it so the correction itself stays legible.

**The lesson is being rewritten by Brett directly on `main`, right now.** Two
commits landed on 2026-08-25 — `068dab3` (12:58) and `24b9da3` (16:37, "Build
reproducible SDP review workflow") — rewriting sessions 2, 3, 4 and 6, the
learner reference, the setup page and the instructor notes. **`24b9da3`
rewrote `session-4.Rmd`, the semantic-review episode, which stream S5
replaces**; that collision is Brett's to rule and is why S4 agent work has left
sessions 3 and 4 alone. Anyone picking this card up must check `git log` first:
this card has now gone stale twice in one day.

**Fixed by workshop PR #5 (2026-08-25), agent-side, in an isolated worktree:**

- **Version pinning.** The real defect was not a stale pin but *no pin*:
  `setup.md` installed metasalmon with `install_github()` and no ref, and
  metasalmonpy from `archive/refs/heads/main.tar.gz`, while `renv.lock` pinned
  **v0.3.0**. The lockfile and the setup page disagreed and neither reached
  0.4.0. Both lanes now pin the **v0.4.0** tag and assert the version in the
  setup check. The unpinned Python install was a **reproducibility regression**
  — it replaced a v0.2.1 *tag* tarball with a moving branch tarball. v0.3.0 and
  v0.4.0 differ only in their DESCRIPTION `Version:` line, so the lockfile bump
  touched `Version`/`RemoteRef`/`RemoteSha` and nothing else.
- **Tidy shape and `primary_key`.** The one item on this card that nothing had
  touched. Added to `learners/reference.md`, consistent with the *Tidy Data for
  Salmon Data Packages* vignette, with all four behaviours run against
  installed 0.4.0 and the messages transcribed from real output. Both checks
  are at parity in metasalmonpy 0.4.0 (`package_io.py`). **The episode-level
  home is session 3**, which was frozen; lift it there when Brett's rework
  settles.
- **The KNB golden path**, as prerequisites rather than as code — the four
  gates a learner hits, pointing at `scripts/build-fraser-coho-knb-rehearsal.R`
  as the executable record, and stating **#116** plainly: the reviewed closure
  (`metadata/semantic_vocabulary.csv`, `reviewed_semantic_selections.csv`) has
  no exported producer in either implementation, so a learner cannot complete a
  deposit from published documentation. The four session-6 chunks stay
  `eval = FALSE` for that reason, which is honest rather than stale.
- **`migrate_sdp_methods()`**, which appeared nowhere, leaving a learner with a
  pre-0.3.0 package no route forward.

**Claims deleted from this card because they are false as of 2026-08-25** —
each was true when written and stopped being true without the card noticing:

| Deleted claim | Measured reality |
|---|---|
| Targets metasalmon **0.2.3** by name (`setup.md:73,77`, `session-1.Rmd:166`) | **Zero occurrences of `0.2.3`** anywhere in the lesson |
| `metasalmon` **absent** from `renv.lock` (zero of 40 packages) | **Present**; the lockfile holds **68** packages, not 40 (the "40" and a later "93" both came from grepping `"Package"`, which also matches `"Type": "Package"`) |
| Four session-6 chunks **render R errors** into the site, at lines 318/343/357/384 | Already `eval = FALSE, purl = FALSE` at **350/379/415/473**, with prose at :346 explaining why they do not execute |
| Teaches the removed `method_iri` dictionary slot | Already corrected to the **three placements** (`session-4.Rmd:219`, `reference.md:140`) |
| `setup.md:114` installs pre-rename `salmonpy 0.1.6` from the `metaSmnPy` URL | Gone; had become an unpinned `heads/main` tarball, now pinned `v0.4.0` |

**One execplan mismatch, unresolved here.** The
[execplan](../plans/2026-08-11-knb-environments-and-workshop-rebuild.md)'s
registry table names the two environments `production` and **`staging`**. What
shipped in 0.4.0 — and what both implementations validate — is `production` and
**`test`** (`R/knb-environments.R:96`, metasalmonpy `knb_environments.py:129`).
The lesson uses `knb_environment = "test"` and is **correct**; the execplan is
the stale document. Left for whoever owns that plan, because renaming a
released enum is not a docs edit.

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
