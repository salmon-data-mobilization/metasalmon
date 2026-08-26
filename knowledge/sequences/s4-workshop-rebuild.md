---
type: InformationObject
title: "S4 — Workshop rebuild"
description: "Rebuild the salmon-data-standards-workshop: nine episodes, R-led with Python equivalents, executing against released metasalmon and metasalmonpy. The install/lockfile split closed 2026-08-25 (workshop PR #6, pinned to metasalmon v0.5.0 / metasalmonpy v0.4.0, open for Brett's review); primary_key is still absent from the whole lesson."
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

## The review episode now teaches S5, and it landed before the rebuild did

**2026-08-25.** Brett committed `068dab3` and `24b9da3` straight to workshop
`main` on the same day S5's M1–M3 merged here (`1ba5e1f`, PR #97), and the
review episode was then rewritten against that merged API on branch
`docs/2026-08-25-s5-review-chapter`. So a slice of S4 has moved **out of
sequence and ahead of the rebuild**, which is worth recording as a fact about
the rebuild rather than a deviation from it: the episode that most needed a
released contract to teach is the one that got one first.

What the rewritten episode teaches: `review_semantics()` prints the exact
`accept_suggestion()` call, the learner pastes it into `scripts/build_sdp.R`,
and `apply_sdp_semantics()` writes it — with every console block captured
verbatim from a real run against this repo's bundled
`nuseds-fraser-coho-sample.csv`. It also states, in the lesson, the two limits
S5's card names: the queue shows **shortlists, not gaps**, and free-text
placeholders are still hand-edited, so `require_iris = TRUE` still fails after
a complete semantic review until M4's `review_metadata()` lands.

**Three findings from that episode that belong here, because they are about the
workshop rather than about S5.**

**~~The lesson now has two different metasalmons, and they disagree.~~ CLOSED
2026-08-25** — see the paragraph below for what closed it and what it cost.
Kept struck through rather than deleted, because the *shape* of the failure is
the reusable part: Brett's commits removed the stale version pins the section
below complains about, but removed them by replacing named versions with
*"install the latest from GitHub"* on both language lanes
(`learners/setup.md:73` for R, `:115` for the metasalmonpy `main.tar.gz`), while
`renv/profiles/lesson-requirements/renv.lock` still pinned metasalmon **0.3.0**,
which is what the published site actually builds against. The failure mode
changed rather than closed: *"teaches a stale release"* became *"learners
install an untagged moving branch while the site builds against a
two-releases-old pin"*. **A currency fix that unpins is not a currency fix** —
it converts one dated wrongness into a silent moving one, which is harder to
notice and impossible to date.

**What closed it.** metasalmon `v0.5.0` released S5 on 2026-08-25 — the tag
this was waiting on — and workshop PR **#6** moves all three pieces in one
change: `learners/setup.md` names `metasalmon@v0.5.0` on the R lane and the
`metasalmonpy` **v0.4.0** tag tarball on the Python lane, and the lockfile is
snapshotted to `v0.5.0` through `sandpaper::manage_deps()` from the
lesson-requirements profile. **The two lanes deliberately name different
numbers**, which is the honest state rather than a leftover: metasalmonpy has
none of S5, so pinning it fixes reproducibility on that lane and closes nothing
about the capability gap. *Retired condition met:* both lanes name a released
version and the lockfile pins it.

The pin and the caveat deletion had to be **one change**, and that is worth
carrying. The rewritten review episode published a caveat that a fully-reviewed
package still fails `require_iris = TRUE` with nowhere in R to go; `v0.5.0`'s
`review_metadata()` and `set_sdp_*()` make that false. Deleting the caveat
without moving the pin would have had the lesson claim a capability its build
environment lacked; moving the pin without deleting the caveat would have had it
disclaim a capability it now has. Three further published statements went false
at the same instant — free-text fields still hand-edited, rejections not
persisting into a fresh queue, and an empty queue under a mistyped `columns`
filter reading as success — and were corrected in the same PR. **One release
falsified four sentences in one episode**, which is the cost of teaching against
an unreleased API and the reason S4 requires released packages in the first
place.

**PR #6 is open and needs Brett's review** (branch protection, `REVIEW_REQUIRED`).
It conflicts with open PR **#5**, which pins the same two files to `v0.4.0` —
correct when written, one release stale for the R lane now.

**The S10 dependency stopped being hypothetical.** The review episode has no
Python lane to show, because metasalmonpy has none of M1–M3: no review queue,
no `semantic_suggestions()` accessor, and nothing that reads
`semantic_suggestions.csv` back. The episode says so plainly and shows a pandas
read of the CSV instead. That is the first episode where the R-led/Python-visible
format has an *empty* Python side, and it is exactly the "episodes must not demo
Python behaviour that only exists in R" constraint biting. Note for the register:
this is an unbuilt port, **not** a parity deviation — there is no
`parity-deviations.md` row, and there should not be one.

**Two of the gaps listed below are now closed and one is not.** Corrected
2026-08-25 by reading the repository rather than this card: the `method_iri`
teaching was fixed in the 2026-08-21 currency pass and again by Brett's
commits, and tidy-shape content now exists (`episodes/session-3.Rmd:273`,
`learners/setup.md:19`). **`primary_key` is still absent from the whole
lesson** — zero occurrences in `episodes/`, `learners/` or `instructors/` —
while it remains a real `tables.csv` column whose misuse aborts validation.
That one is unchanged and still rebuild scope.

## What the current lesson is, today

> **Read this section as dated evidence, not as current state.** It was written
> 2026-08-21 and describes the repository at `b080fc9`/`ffcbfc3`. Four of its
> findings have since closed — the `method_iri` teaching, the erroring session-6
> chunks, the pre-rename `salmonpy 0.1.6` install, and the missing tidy-shape
> content — and one of the closures introduced the new install-side problem
> named above. **`primary_key` is the only item below still open as written.**
> Verified against the repository 2026-08-25; the paragraphs are kept because
> the reasoning is the useful part, and a finding whose closure is invisible is
> how a card starts lying.

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
tag tarball (releases carry no wheel assets) — ~~now itself stale: the mirror
released `v0.4.0` on 2026-08-24, so the rebuild pins that tarball, not
v0.2.1~~ **done in workshop PR #6, 2026-08-25.**
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

## The workshop's CI was red on every PR, and not for the reason it looked like

**Measured 2026-08-25 from the failing run's log, then fixed and confirmed
green.** The `Receive Pull Request` check had failed on every recent workshop PR
— including `fix/2026-08-21-currency-pass`, which was **merged red** —
reporting eleven packages `renv::restore` could not install, with `metasalmon`
among them. That reads as the stale 0.3.0 pin's
dependency tree, and the S4 story made it easy to believe.

It is not. The runner is **R 4.6.1**, and the log's actual error is
`base64enc.so: undefined symbol: SETLENGTH`, plus the same class of failure from
`yaml`. Both pinned versions (`base64enc` 0.1-3, `yaml` 2.3.10) predate R 4.6
withdrawing those non-API entry points; the other **nine are cascade failures**
downstream of exactly those two, `metasalmon`'s own spelled out in the log as
*"dependency failed (usethis, yaml)"*. So moving the metasalmon pin alone could
not have fixed it — metasalmon's `Imports` are byte-identical between 0.3.0 and
0.5.0. PR #6 bumps `base64enc` to 0.1-6, `yaml` to 2.3.12 and
`htmltools` to 0.5.9, which is the minimal change addressing the measured
cause.

**It went green, in two rounds, and the second round is the interesting one.**
Bumping those two took the failure list from eleven packages to six: both
installed, and the error moved to `htmltools` 0.5.8.1 reporting the *identical*
`SETLENGTH` symbol, with the other five named only as *"dependency failed
(htmltools, …)"*. `htmltools` → 0.5.9 cleared it. **`Receive Pull Request` is
now green on workshop PR #6 — the first green run in this series.** Three
packages, one cause, and the failure list shrank 11 → 6 → 0.

Scope was held deliberately: the lockfile carries **thirteen** compiled packages
behind CRAN, and only the three CI actually failed on were bumped. Several of
the rest are major (`curl` 7→8, `fs` 1→2, `jsonlite` 1→2) with nothing yet
saying they are needed. A fourth `SETLENGTH` failure is the signal to decide
whether the lockfile wants a wholesale refresh instead of another single bump.

Three things worth carrying past this fix. **A package named in a failure list
is not necessarily a package that failed**: nine of the eleven were named
because something they depend on failed, and the one name that mattered was two
lines further down. **A cascade hides its own depth** — clearing the first root
cause did not reveal how many more there were, it revealed exactly one more, and
only by being run. And **a red check that has been red long enough stops being
read** — this one was merged through, which is what makes the next genuine
failure invisible; it is now green, so the next failure means something again.
*Retires when:* the failure changes cause and this paragraph is rewritten rather
than trusted.

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
