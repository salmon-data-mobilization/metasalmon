---
type: Artifact
title: "R-native review and editing flow"
description: "Execplan for the R-native semantic review and editing flow (stream S5); the 0.3.0 target and the #75 slice-1 fix are both superseded by S8."
status: draft
tags: [execplan]
psc:
  id: metasalmon:plan:2026-08-11-r-native-review-and-editing
  contexts: [metasalmon:context:hub-coordination]
---

# R-native semantic review and editing

Created 2026-08-11. Roadmap stream **S5**. Sequencing lives in
[`knowledge/roadmap.md`](../roadmap.md); this file is the detail.

> **Two premises below were overtaken by S8 — read the rest with them in mind.**
> **(1) The version is no longer 0.3.0.** S8's method-placement change took
> that number on 2026-08-15; S5 ships as whatever minor is next at ship time.
> **(2) #75 is not this plan's to fix.** sdp-0.3.0 removed the dictionary
> `method_iri` slot and the `metadata/methods.csv` registry outright, so the
> defect was superseded rather than fixed by the slice-1 suppression reasoned
> through below. That reasoning is kept because it was correct for the model
> that then existed, and because "fixed by the slice that was going to fix it"
> is exactly the marker that goes unverified.

Filed under `knowledge/plans/` rather than the `execplans` skill's default
`docs/plans/`, because `AGENTS.md` git-ignores `docs/plans/` and this document
must be linkable from the roadmap.

Backlog: **#74** (this feature) and **#75** (a defect found while scoping it,
reproduced below). The source plan numbered these #73/#74; #73 was taken by the
redaction gap in the meantime.

---

## Purpose / Big Picture

Today a user runs `create_sdp()` and then **leaves R**. The documented workflow
(`README.md`, and a vignette section literally titled *"Review In Excel"*) tells
them to open `metadata/column_dictionary.csv` in a spreadsheet, read
`semantic_suggestions.csv` as a shortlist, and copy an IRI across **by hand**.
The only record of that decision is the mutated CSV.

That is the one unreproducible link in a chain that is otherwise
byte-reproducible. Every byte-producing path in the package is pinned to C
collation and guarded by a static test — and then the most consequential step is
handed to a spreadsheet.

**User-visible proof this worked:**

1. `review_semantics(pkg)` prints a numbered shortlist per unfilled semantic
   slot, each candidate showing its definition inline and a clickable link.
2. Each candidate prints the **exact R call** that accepts it, so the decision
   can be pasted into a script and re-run.
3. `apply_sdp_semantics(pkg, rev)` writes those decisions into the metadata CSVs
   and leaves the data CSV bytes **unchanged**.
4. `review_metadata(pkg)` lists required-but-unfilled fields, each with the
   `set_sdp_*()` call that fills it.
5. `validate_salmon_datapackage(pkg, require_iris = TRUE)` passes with no
   `REVIEW:` markers left.
6. A user who never opens Excel can complete the whole review.

### Target experience

```r
pkg <- create_sdp(...)

rev <- review_semantics(pkg)
# ── table_1 · spawner_count · variable ──────────────────────────
# current: REVIEW: https://w3id.org/smn/SpawnerAbundance
#
#  [1] Spawner Abundance          smn    score 4.0
#      The number of mature salmon returning to spawn…
#      https://w3id.org/smn/SpawnerAbundance          ← clickable
#      accept_suggestion(rev, "spawner_count", "variable", rank = 1)

rev <- accept_suggestion(rev, "spawner_count", "variable", rank = 1)
rev <- reject_suggestion(rev, "gear_code", "variable")
apply_sdp_semantics(pkg, rev)

review_metadata(pkg)
set_sdp_dataset(pkg, creator = "…", contact_email = "…", license = "CC-BY-4.0")

validate_salmon_datapackage(pkg, require_iris = TRUE)
```

---

## Progress

- [ ] M1 — Accessors and read side
- [ ] M2 — Console view
- [ ] M3 — Decisions and write-back
- [ ] M4 — Free-text editing
- [ ] M5 — Docs
- [x] 2026-08-11 — Plan written; #75 reproduced; all source-plan citations
      re-checked against the working tree (several had shifted)
- [x] 2026-08-11 — Review pass: slice-1 scope reversed for methods (see Decision
      Log), byte writers registered in the collation guard, cross-file atomicity
      contract added

---

## Surprises & Discoveries

**The write-back seam is already built and unreachable.**
`apply_semantic_suggestions()` has `strategy = "reviewed"`, which filters a
`decision` column on `accepted`/`accept` (`R/semantics-helpers.R:844`). **Nothing
writes that column, and nothing reads `semantic_suggestions.csv` back** — every
reference in `R/` is a writer or a doc mention. This feature is the missing
producer for a consumer that already exists, which is why the slice is smaller
than it looks.

**Required-field truth is parsed and read by nothing.** `constraints.required`
from the Frictionless schemas is stored as `field$requirement`
(`R/schema-helpers.R`); `grep` finds five producers and no consumers outside that
file. `review_metadata()` would be its first.

**#75 — auto-applied `method_iri` with no `methods.csv`. Reproduced.**
The docs state that "constraint and method assessments always remain manual".
That holds only on the `llm_assess = TRUE` path, where
`.ms_create_sdp_llm_auto_apply_roles()` returns exactly
`c("variable", "property", "entity", "unit")`. On the **default seeded** path,
`apply_semantic_suggestions(strategy = "top", roles = NULL)` maps all six roles,
gated only lexically by `.ms_measurement_supports_procedure_slot()`, whose regex
includes `method|protocol|procedure|gear|estimated|enumerat|…`.

Reproduction — a column named `enumeration_method`, with `find_terms()` mocked so
no network is involved:

```
method_iri values: <NA> | <NA> | REVIEW: https://w3id.org/smn/EnumerationMethod
methods.csv exists: FALSE
```

Why it bites late: `validate_sdp_methods()` — which requires a registered row in
`metadata/methods.csv`, a file `create_sdp()` never creates (`write_sdp_methods()`
has **zero callers** in `R/`) — is invoked from the **KNB publication path**
(`R/knb-publication.R:392`), not from `validate_salmon_datapackage()`. So the
sequence is: accept the suggestion → strip the `REVIEW:` prefix exactly as the
package's own guidance instructs → pass validation → **fail at deposit**, after
the entire review is done.

No test asserts a positive auto-apply for `method` or `constraint`. The nearest
existing test passes only because its `water_level` fixture misses both regexes —
a test that is green for an incidental reason.

---

## Decision Log

| Decision | Rationale | Date |
|---|---|---|
| Console prints the exact `accept_suggestion(...)` call; the user pastes it | Makes the decision reproducible and scriptable without building an interactive TUI. The paste *is* the audit trail | 2026-08-11 |
| Definition inline (primary) + source-aware deep-dive link (secondary) | Definitions already flow through `find_terms()`; no network call needed to show them | 2026-08-11 |
| Slice 1 = measurement `term`/`property`/`entity`/`unit`/`constraint` + free-text setters | Covers the review a user actually does today in Excel | 2026-08-11 |
| ~~Methods deferred to slice 2~~ **Superseded** — see the last row | `method_iri` and `metadata/methods.csv` must ship together — see #75 | 2026-08-11 |
| Decomposition artifact deferred to slice 2 | Dictionary I-ADOPT slots first | 2026-08-11 |
| Free-text via a named setter family + `review_metadata()` gaps reporter | Named arguments beat a generic `field = value` API for discoverability and for `R CMD check` | 2026-08-11 |
| Write-back is surgical, then rebuild `datapackage.json` from the metadata | `datapackage.json` duplicates title/description/creator/contacts/license, and the rule that would catch drift is one of the three dead rules in `sdp.rules.yaml`. Resync rather than warn | 2026-08-11 |
| Bundle into 0.3.0 with #58/#59/#60 | #60 is a **prerequisite**, not an adjacency: the review queue must read those attributes through a supported accessor. #58 already wants a major bump, and this adds ~10 exported functions | 2026-08-11 |
| ~~Method rows shown but not acceptable in slice 1~~ **Superseded** — see the last row | `create_sdp()` can already leave a `REVIEW:`-prefixed `method_iri` (#75) and that marker blocks strict validation — hiding it would be worse than not handling it | 2026-08-11 |
| **Reversed: #75 is fixed in slice 1 by suppressing method/constraint auto-apply.** Method *acceptance* + `methods.csv` registration stay slice 2 | Review caught that the two rows above were jointly unsatisfiable: showing an unacceptable `REVIEW:` marker means slice 1 cannot deliver proof 5 (validation passes) or proof 6 (finish without Excel) for any package with a method-ish column name. Stopping the marker at its source is smaller than supporting acceptance, and it closes #75 | 2026-08-11 |

---

## Context and Orientation

**Terms.** *Slot* — one (column, I-ADOPT role) pair needing an IRI.
*`REVIEW:` marker* — a prefix `create_sdp()` writes when it is not confident;
strict validation fails while any remain. *Surgical write* — read the metadata
CSV, change only the decided cells, write it back, preserving row order.

**Key files.** `R/semantics-helpers.R` (suggestions, `apply_semantic_suggestions()`),
`R/package-helpers.R` (writer, descriptor block, `README-review.txt` generator),
`R/schema-helpers.R` (`field$requirement`), `R/cli-safety.R` (escaping),
`R/sdp-methods.R` (`validate_sdp_methods()`).

**Two traps, both enforced by existing guards.**

1. Ontology definitions are **external text** and must pass through
   `.ms_cli_escape()` before reaching cli — enforced by `test-cli-safety-guard.R`,
   which walks the installed namespace. A definition containing `{...}` is
   evaluated otherwise.
2. An IRI must **not** become a terminal hyperlink unless its scheme is `http`
   or `https`.

---

## Plan of Work

### M1 — Accessors and read side

`semantic_suggestions(x)` / `semantic_llm_assessments(x)` in
`R/semantics-helpers.R` — closes **#60**. `review_semantics(x, ...)` builds the
queue from an SDP path **or** a dict carrying the attribute, returning an
`ms_semantic_review` tibble subclass.

### M2 — Console view

New `R/review-console.R`:

- `.ms_term_browse_url(iri, source, ontology)` — refuses to hyperlink any scheme
  that is not `http`/`https`. `smn`/`gcdfo` → the w3id IRI (already the canonical
  browsable form); `ols` → an OLS4 term URL; `nvs` → the NERC IRI; otherwise the
  IRI. Render with `cli::style_hyperlink()`, using cli's own fallback when
  `cli::ansi_has_hyperlink_support()` is `FALSE`.
- `.ms_review_render_lines(review, ...)` — returns a `character` vector.
  `print.ms_semantic_review()` just emits it. **Tests assert against this**, not
  against rendered terminal output.
- `print.ms_semantic_review()` — the first S3 method in the package; `NAMESPACE`
  has **zero** `S3method()` entries today, so the roxygen export needs care.

### M3 — Decisions and write-back

`accept_suggestion()`, `reject_suggestion()` (pipe-friendly, returning the
review), then new `R/metadata-write.R`:

- `.ms_write_metadata_csv()` — reuses `.ms_read_metadata_csv()` (all-character,
  `na = ""`), `.ms_align_cols()` for column order, and
  `.ms_assert_managed_path_contained()` for the symlink and `..` guards.
  Read → mutate cells → write preserves row order, so there is no *ordering* to
  get wrong today — **but both this and `.ms_rebuild_datapackage_descriptor()`
  are canonical-byte producers and must be registered in
  `collation_sensitive_fns` (`tests/testthat/test-collation-guard.R`) when they
  are written**, not when they first sort. `AGENTS.md` states the rule as
  registration-on-creation for exactly this reason: the guard only inspects
  listed functions, so an unregistered writer that later gains a locale-sensitive
  ordering is invisible to it. That limitation bit within days of the guard being
  written (#63).
- `.ms_rebuild_datapackage_descriptor(path)` — extracted from the descriptor
  block inside `write_salmon_datapackage()`.
- `apply_sdp_semantics(path, review, ...)`.

**Two behaviours to pin:**

1. `REVIEW:`-prefixed fields are **non-blank**, so `apply_semantic_suggestions()`'s
   default `overwrite = FALSE` would drop reviewed decisions. Contract:
   `apply_sdp_semantics()` strips `REVIEW:` from decided fields and applies with
   overwrite, and **touches only fields carrying a decision** — undecided fields
   keep their markers untouched.
2. `reject_suggestion()` **blanks** the field, matching the documented user
   action. Wiring a rejection reason into `detect_semantic_term_gaps()` /
   `render_ontology_term_request()` is a natural follow-on, not slice 1.

### M4 — Free-text editing

New `R/sdp-field-setters.R`: `.ms_required_metadata_fields()` (first consumer of
`field$requirement`), `.ms_is_unfilled_metadata(x)`, `review_metadata(path)`, and
`set_sdp_dataset()` / `set_sdp_table()` / `set_sdp_column()`.

`.ms_is_unfilled_metadata()` lifts the three-way test from the existing prototype
`coalesce_review_text()` in `scripts/llm-sanity-check.R`: `is.na` **or**
blank-after-trim **or** `.ms_is_review_placeholder()`. **Do not** copy that
prototype's `readr::read_csv()` call — it omits `col_types` and type-guesses,
which is the defect class 0.2.0 fixed.

### M5 — Docs

Vignette and README rewrite (the *"Review In Excel"* section becomes
R-native-first, Excel as the alternative), `README-review.txt` generator updated
to print R commands, `_pkgdown.yml` reference group, `NEWS.md` for 0.3.0.

### #75 is fixed **in slice 1**, by suppression

This changed during review, and the reasoning matters. The original scope showed
method rows without letting anyone accept or reject them, while deferring
`methods.csv` registration to slice 2. That is internally unsatisfiable: a
`REVIEW:`-prefixed `method_iri` blocks strict validation, so for any package with
a method-ish column name, slice 1 could not deliver **proof 5** (validation
passes with no markers left) or **proof 6** (a user who never opens Excel can
finish). The feature would have shipped unable to meet its own stated bar.

**Resolution: stop emitting the marker at its source.** Slice 1 restricts the
default seeded path's auto-apply roles to match the LLM path's
(`variable`/`property`/`entity`/`unit`), so `method` and `constraint` are no
longer auto-applied and no unacceptable marker is produced. That is a small,
well-understood change and it closes #75.

Full method *support* — accepting a `method_iri` and registering the row in
`metadata/methods.csv` — remains slice 2, where the two ship together. A user who
wants a method IRI in slice 1 sets it with `set_sdp_column()` and registers it
themselves; `review_metadata()` reports it as unfilled rather than pretending it
does not exist.

### Slice 2 — named here, out of scope

`method_iri` acceptance + `metadata/methods.csv` registration shipped
**together**; `measurement-decompositions.csv` + its SHA-256 manifest.

---

## Concrete Steps

Working directory is the repo root throughout.

```r
pkgload::load_all(".", quiet = TRUE)
```

```bash
Rscript -e 'devtools::test(reporter = "summary", stop_on_failure = FALSE)'
```

```bash
Rscript -e 'devtools::document()' && R CMD build . && _R_CHECK_FORCE_SUGGESTS_=false R CMD check --no-manual metasalmon_*.tar.gz
```

```bash
Rscript scripts/build-pkgdown.R
```

**Files created:** `R/review-console.R`, `R/sdp-field-setters.R`,
`R/metadata-write.R`, `tests/testthat/test-review-console.R`,
`test-sdp-field-setters.R`, `test-metadata-write.R`.

**Files modified:** `R/semantics-helpers.R`, `R/package-helpers.R`,
`tests/testthat/test-collation-guard.R` (register the two new byte writers),
`NAMESPACE`,
`_pkgdown.yml`, `NEWS.md`, `vignettes/metasalmon.Rmd`,
`vignettes/post-review-package-publication.Rmd`, `README.md`.

**One existing test will break and must be updated:**
`tests/testthat/test-package-helpers.R:628` asserts
`grepl("Review the package in Excel", review_lines, fixed = TRUE)`.
(The source plan cited `:626`; line numbers shifted during 0.2.x.)

---

## Validation and Acceptance

House style, **not snapshots**. The package has zero `expect_snapshot` calls and
`test-cli-safety.R` records the deliberate reason: assertions must not couple to
cli's rendering. Hyperlink output is terminal-dependent, so snapshots would be
flaky.

- Assert on `.ms_review_render_lines()` output with `grepl(..., fixed = TRUE)`.
- Mock `cli::ansi_has_hyperlink_support` with `with_mocked_bindings` to cover
  both link branches.
- **cli safety:** a candidate whose `definition` contains `{Sys.getenv("HOME")}`
  must print literally, not interpolate.
- **Scheme safety:** `.ms_term_browse_url()` never hyperlinks a `javascript:` or
  `file:` IRI.
- **Round trip:** `create_sdp()` → `review_semantics()` → `accept_suggestion()` →
  `apply_sdp_semantics()` → `validate_salmon_datapackage(require_iris = TRUE)`
  passes with no `REVIEW:` markers remaining, **and the data CSV bytes are
  unchanged** — that byte assertion is the point of the surgical write, and is
  the only one that would fail if the writer rewrote the whole package.

Baseline to hold: 0 failures; CI skips exactly 4; `R CMD check` Status OK.

---

## Idempotence and Recovery

Every milestone is independently revertible; M1 and M2 add code without changing
existing behaviour. `apply_sdp_semantics()` is the first step that mutates a
user's package — it must be safe to re-run: applying the same review twice
produces identical bytes, because it strips `REVIEW:` and writes decided fields
only. Assert that directly (apply twice, compare hashes).

If a write-back is interrupted, the metadata CSV must be either wholly old or
wholly new; reuse the existing atomic-write pattern rather than writing in place.

**Per-file atomicity is not sufficient here.** One logical edit — an
`apply_sdp_semantics()` call, or any `set_sdp_*()` setter — changes both a
metadata CSV **and** `datapackage.json`, which duplicates title, description,
creator, contacts, and licence. Replacing each file atomically still leaves a
window in which the CSV is new and the descriptor is old, and the rule that would
catch that drift (`datapackage_consistent_with_csv_metadata`) is one of the three
dead rules in `sdp.rules.yaml` — so nothing would detect it and the package would
simply be quietly inconsistent.

**Contract:** stage every affected file, then commit them as one set, rolling
back the whole set on any failure. Assert it: interrupt between the CSV write and
the descriptor rebuild, and require that the package is unchanged rather than
half-updated.

---

## Outcomes & Retrospective

_To be completed as milestones land._
