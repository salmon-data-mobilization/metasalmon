---
type: InformationObject
title: "S11 — Vignettes and user-facing walkthroughs"
description: "Keep metasalmon vignettes and metasalmonpy guides current, and add the missing walkthroughs: KNB golden path, R semantic review, methods annotation, and an executable end-to-end NuSEDS run. Seeded by the 2026-08-13 staleness audit."
status: draft
tags: [vignettes, docs, teaching]
psc:
  id: metasalmon:sequence:s11-vignettes-and-walkthroughs
  contexts: [metasalmon:context:hub-coordination]
---

# S11 — Vignettes and user-facing walkthroughs

**Evidence base:** the 2026-08-13 vignette staleness audit (agent-run, findings
below with file:line citations verified at audit time). Standing rule: the
**mirror contract applies to docs** — metasalmonpy guides update in lockstep
with the vignettes that cover the same workflow.

**Status: slices 1 and 2 have landed** (PR #46, `ac6b722`, plus the 0.3.0
staleness sweep) — `migrating-to-sdp-0-3-0.Rmd` and `tidy-data-for-sdp.Rmd`
exist and the audit's code defects, framing, and coverage gaps below are fixed.
Slices 3–6 remain.

**Two named remainders survive inside the landed slices** (re-checked
2026-08-21) — carried up here because "LANDED" on a slice line has been read as
"nothing left in it":

- **Slice 2: `tidyr` is still not in `DESCRIPTION`.** Zero matches. The
  vignette that teaches `pivot_longer` therefore names a package the installed
  package does not declare. It is display-only, so nothing errors — which is
  why it has survived two sweeps.
- **Slice 1: `guides/github-access.qmd` still has no runnable example**, and
  the blocker is a decision, not work: **Brett has to name a public CSV
  repository** to point it at. Every current example targets a private DFO
  repo. Nobody can unblock this by trying harder.

## Audit verdicts (2026-08-13; metasalmon 0.2.6, metasalmonpy 0.1.6)

**A dated record, largely discharged — do not read these as current defects.**
Everything below was true at 0.2.6/0.1.6; slices 1–2 fixed nearly all of it.
**Three** findings survive, re-checked 2026-08-21: the
`tidyr`-not-in-DESCRIPTION half of the tidy-data bullet, the
`github-access.qmd` runnable example, and the KNB-vignette split (slice 3).
*(This line said "two" and omitted the second, while slice 1 below recorded it
as outstanding — the same card counting differently in two places.)*
Corrections are flagged inline.

"No vignette was touched since 0.2.6 landed" was the audit's finding **on
2026-08-13** and is no longer true — slices 1–2 rewrote several and added two.

- **Stale framing:** `metasalmon.Rmd:144` and
  `post-review-package-publication.Rmd:64-86` present default-mode
  `validate_salmon_datapackage()` as a narrow structural check; since 0.2.6
  it also warns on every unresolved `MISSING METADATA:` placeholder — which
  fires on **every freshly created package** in the quickstart, unexplained.
  *(Fixed: both vignettes now say the warning on a fresh package is normal.)*
- **Code defects that shipped:**
  `reusing-standards-salmon-data-terms.Rmd:39` has `devtools::load_all(".")`
  in a user-facing chunk (errors outside the source tree);
  `data-dictionary-publication.Rmd:129` reads a repo-relative
  `inst/extdata/` path instead of `system.file()`. *(Both fixed: no `load_all`
  remains anywhere in `vignettes/`, and the path now uses `system.file()`.)*
- **Zero coverage of the new contracts:** `primary_key` (0 hits in
  vignettes/ — since 0.2.6 a *declared* key is enforced: duplicates,
  missing components, or absent columns are hard errors; an undeclared key
  is still accepted — and it is a shipped template column),
  wide-format/`pivot_longer` guidance (0 hits; `tidyr` isn't even in
  DESCRIPTION), and the 0.2.4 empty-field missing-value token (nothing
  contradicts it, nothing documents it — `NEWS.md:73-77` names hand-authored
  packages, and the hand-authored-package vignette says nothing).
  *(Mostly fixed: `primary_key` and `pivot_longer` are taught in
  `tidy-data-for-sdp.Rmd` and the token in `faq.Rmd`. **Still true:** `tidyr`
  is not in `DESCRIPTION`.)*
- **S8 exposure (update in lockstep when the method model lands):**
  *(Fixed in the 0.3.0 sweep: the "document methods in your column
  descriptions" line is gone and the glossary now says five I-ADOPT
  components.)* `glossary.Rmd:142` ("document methods in your column
  descriptions") will be flatly wrong; the four-component I-ADOPT framing
  needs the fifth
  (`statistical_modifier_iri`); seven more citations in the audit record.
- **metasalmonpy:** `getting-started.qmd`'s broken `@v0.1.6` install command
  (fixed 2026-08-13, PR #4 — the README fix had missed it);
  `guides/parity.qmd` never states what is *absent* (EML, KNB, SSSOM,
  decompositions) — the one guide whose job that is *(fixed: it now carries a
  "Not yet in Python" section listing exactly those)*;
  `guides/github-access.qmd` has no runnable example (every example targets
  a private DFO repo). *(Corrected: the `github_io.py` private default is
  **fixed** — mirrored as metasalmonpy `a7999b2`, shipped in v0.1.7.)*
- **Untaught API:** 27 of metasalmon's 54 exports appear in no vignette,
  including the whole `write_sdp_methods()`/`validate_sdp_methods()` family.
  *(Corrected: that family no longer exists — 0.3.0 removed it — and the
  export count is now 53. The 27 figure has not been recounted since.)*

## Slices, in order

1. **Staleness fixes — LANDED**, except the `github-access.qmd` runnable
   example, which still needs Brett to name a public CSV repo: validation framing in the two
   vignettes; the two code defects; a missing-value entry in `faq.Rmd` and a
   note in the hand-authored-package vignette; `primary_key` taught where
   `tables.csv` is hand-built; metasalmonpy `parity.qmd` gains an explicit
   "not yet in Python" list; a public runnable example for
   `github-access.qmd` (needs a public CSV repo — ask Brett which).
2. **Tidy-data preparation vignette + migration/breaking-changes page —
   LANDED** as `tidy-data-for-sdp.Rmd` and `migrating-to-sdp-0-3-0.Rmd`:
   `pivot_longer` workflow, `primary_key` selection, and the 0.2.4/0.2.6/0.3.0
   migration steps that used to live only in NEWS.
3. **KNB Golden Path vignette (after S3):** extract
   `post-review-package-publication.Rmd:354-490` (§10 — the densest 137
   lines in the vignette set, currently invisible in the pkgdown articles
   index) into a dedicated end-to-end vignette: eml-mapping, dry-run
   manifest, staging rehearsal (S3), live deposit, DOI. `setup.Rmd`'s
   DataONE JWT section links to it.
4. **R semantic-review workflow vignette (ships with S5, whatever minor S5
   lands as — 0.3.0 was taken by S8):** the R twin of
   metasalmonpy's `guides/semantic-review.qmd`, covering the new
   `review_semantics()` flow and `chat_decomposition()`.
5. **Methods and protocol annotation vignette (after S8 lands in code):**
   the three placements + `statistical_modifier_iri`; glossaries in both
   packages updated in the same release. **Re-scope before starting** — slice
   2's `migrating-to-sdp-0-3-0.Rmd` already teaches the three placements and
   the new slot, and the R glossary is updated (five I-ADOPT components, the
   "document methods in your column descriptions" line gone). What is left is
   the Python glossary and whatever annotation guidance the migration framing
   does not cover.

6. **Executable end-to-end NuSEDS walkthrough — NEW, and the only slice about
   *running* anything.** Slices 1–5 are all about other vignettes' prose;
   slice 3 in particular extracts §10's existing text into its own page, which
   improves where the walkthrough lives and not whether it works. Measured
   2026-08-21: **all eleven vignettes set `eval = FALSE` globally**, so not one
   line of the documented pipeline executes when the docs are built. That is a
   deliberate design — display-only chunks, `purl = FALSE`, backlog #32 —
   and its cost is that the end-to-end path is *shown*, never *checked*.

   The slice: one walkthrough that runs, from a bundled Fraser coho CSV through
   `create_sdp()` → semantic review → `validate_salmon_datapackage()` to a
   dry-run publication plan, executing in CI on every push. It is the natural
   home for the round-trip test backlog **#100** asks for, and it is the check
   that would have caught **#95**, **#96** and **#98** on the day each was
   introduced — three defects invisible to a green suite because twelve test
   references to the example CSVs exist and none validates a package built from
   them.

   **It cannot end green today, and that is the point.** The 30-row example
   fails `validate_salmon_datapackage()` in both modes (#98); the 173-row one
   returns a 0-row issues tibble while the spec validator reports 27 errors
   (#95, and [S1](s1-validation-authority.md)). So this slice either lands
   *after* those are fixed, or lands first and asserts the current failure
   exactly — which is a legitimate choice and has to be a stated one, because a
   walkthrough that documents its own failure needs to say so on the page.

   **Depends on [S12](s12-fraser-coho-gold-standard.md):** which example it
   executes is S12's open artifact decision, not this slice's to make.
   *Done when:* the walkthrough runs in CI against the chosen bundled example,
   the docs render its real output rather than a transcript, and a drift in
   `create_sdp()`'s behaviour turns the build red.

**Continuous:** when a release changes observable behaviour, the release
checklist includes "which vignette teaches this?" — untaught exports need a
home or a justification.
