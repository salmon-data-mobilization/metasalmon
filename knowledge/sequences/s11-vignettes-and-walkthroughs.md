---
type: InformationObject
title: "S11 — Vignettes and user-facing walkthroughs"
description: "Keep metasalmon vignettes and metasalmonpy guides current, and add the missing walkthroughs: KNB golden path, tidy-data preparation, R semantic review, methods annotation, and a migration page. Seeded by the 2026-08-13 staleness audit."
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

## Audit verdicts (2026-08-13; metasalmon 0.2.6, metasalmonpy 0.1.6)

No vignette was touched since 0.2.6 landed, and only one since 0.2.4.

- **Stale framing:** `metasalmon.Rmd:144` and
  `post-review-package-publication.Rmd:64-86` present default-mode
  `validate_salmon_datapackage()` as a narrow structural check; since 0.2.6
  it also warns on every unresolved `MISSING METADATA:` placeholder — which
  fires on **every freshly created package** in the quickstart, unexplained.
- **Code defects that shipped:**
  `reusing-standards-salmon-data-terms.Rmd:39` has `devtools::load_all(".")`
  in a user-facing chunk (errors outside the source tree);
  `data-dictionary-publication.Rmd:129` reads a repo-relative
  `inst/extdata/` path instead of `system.file()`.
- **Zero coverage of the new contracts:** `primary_key` (0 hits in
  vignettes/ despite being a hard error since 0.2.6 and a template column),
  wide-format/`pivot_longer` guidance (0 hits; `tidyr` isn't even in
  DESCRIPTION), and the 0.2.4 empty-field missing-value token (nothing
  contradicts it, nothing documents it — `NEWS.md:73-77` names hand-authored
  packages, and the hand-authored-package vignette says nothing).
- **S8 exposure (update in lockstep when the method model lands):**
  `glossary.Rmd:142` ("document methods in your column descriptions") will
  be flatly wrong; the four-component I-ADOPT framing needs the fifth
  (`statistical_modifier_iri`); seven more citations in the audit record.
- **metasalmonpy:** `getting-started.qmd`'s broken `@v0.1.6` install command
  (fixed 2026-08-13, PR #4 — the README fix had missed it);
  `guides/parity.qmd` never states what is *absent* (EML, KNB, SSSOM,
  decompositions) — the one guide whose job that is;
  `guides/github-access.qmd` has no runnable example (every example targets
  a private DFO repo) and `github_io.py:85` still defaults to it — the
  exact defect R fixed as #72 (logged on the S10 card).
- **Untaught API:** 27 of metasalmon's 54 exports appear in no vignette,
  including the whole `write_sdp_methods()`/`validate_sdp_methods()` family.

## Slices, in order

1. **Staleness fixes (unblocked, do first):** validation framing in the two
   vignettes; the two code defects; a missing-value entry in `faq.Rmd` and a
   note in the hand-authored-package vignette; `primary_key` taught where
   `tables.csv` is hand-built; metasalmonpy `parity.qmd` gains an explicit
   "not yet in Python" list; a public runnable example for
   `github-access.qmd` (needs a public CSV repo — ask Brett which).
2. **Tidy-data preparation vignette + migration/breaking-changes page**
   (unblocked): `pivot_longer` workflow, `primary_key` selection, the 0.2.4
   and 0.2.6 migration steps that today live only in NEWS.
3. **KNB Golden Path vignette (after S3):** extract
   `post-review-package-publication.Rmd:354-490` (§10 — the densest 137
   lines in the vignette set, currently invisible in the pkgdown articles
   index) into a dedicated end-to-end vignette: eml-mapping, dry-run
   manifest, staging rehearsal (S3), live deposit, DOI. `setup.Rmd`'s
   DataONE JWT section links to it.
4. **R semantic-review workflow vignette (with S5 / 0.3.0):** the R twin of
   metasalmonpy's `guides/semantic-review.qmd`, covering the new
   `review_semantics()` flow and `chat_decomposition()`.
5. **Methods and protocol annotation vignette (after S8 lands in code):**
   the three placements + `statistical_modifier_iri`; glossaries in both
   packages updated in the same release.

**Continuous:** when a release changes observable behaviour, the release
checklist includes "which vignette teaches this?" — untaught exports need a
home or a justification.
