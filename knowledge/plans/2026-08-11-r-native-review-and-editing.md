---
type: Artifact
title: "R-native review and editing flow"
description: "Execplan for the R-native semantic review and editing flow (stream S5). COMPLETE: M1-M5 all landed 2026-08-25 and a package now reaches strict validation entirely from R. The 0.3.0 target and the #75 slice-1 fix are both superseded by S8."
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

> *Written 2026-08-11 and kept in the present tense as the record of the
> problem. All six proofs below were delivered on 2026-08-25; the vignette
> section named here is now titled "Review In R".*

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

- [x] M1 — Accessors and read side — `semantic_suggestions()` /
      `semantic_llm_assessments()` (2026-08-25)
- [x] M2 — Console view — `review_semantics()`, `print.ms_semantic_review()`,
      `.ms_review_render_lines()`, `.ms_term_browse_url()` (2026-08-25)
- [x] M3 — Decisions and write-back — `accept_suggestion()`,
      `reject_suggestion()`, `apply_sdp_semantics()` (2026-08-25)
- [x] M4 — Free-text editing — `review_metadata()`, `set_sdp_dataset()`,
      `set_sdp_table()`, `set_sdp_column()`, `set_sdp_code()` (2026-08-25)
- [x] M5 — Docs — the vignette's *"Review In Excel"* section, the
      `README-review.txt` generator, `create_sdp()`'s closing message, the
      `_pkgdown.yml` group and the README (2026-08-25)
- [x] 2026-08-11 — Plan written; #75 reproduced; all source-plan citations
      re-checked against the working tree (several had shifted)
- [x] 2026-08-11 — Review pass: slice-1 scope reversed for methods (see Decision
      Log), byte writers registered in the collation guard, cross-file atomicity
      contract added
- [x] 2026-08-25 — M1–M3 implemented (PR #97). Full suite green (0 failures,
      5 skips locally / 4 in CI), `R CMD check` Status OK, OKF bundle valid.
      #60's accessor clause closed; #74 narrowed to M4/M5; #118 filed and
      fixed. See Surprises & Discoveries below for the four things the plan got
      wrong.
- [x] 2026-08-25 — M4–M5 implemented. **The stream's own bar is met and
      measured**: a `create_sdp()` package reaches
      `validate_salmon_datapackage(require_iris = TRUE)` entirely from R, with
      no file opened in a spreadsheet, asserted end to end in
      `tests/testthat/test-sdp-field-setters.R`. Proofs 4, 5 and 6 delivered;
      **#74 closed**. Three round-trip defects in the M1–M3 API found by
      teaching it and fixed here (decision replay, persisted rejection reason,
      the lying empty-queue message), plus a `prune` warning; **#119** filed
      for the `variable`/`property` retrieval overlap rather than fixed blind.
      Full suite green (0 failures, 5 skips locally), `R CMD check` Status OK.

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

**M1–M3, 2026-08-25 — four things the plan did not survive contact with.**

**1. `.ms_filter_auto_apply_suggestions()` was silently vetoing reviewed
decisions.** The plan's write-back design assumed
`apply_semantic_suggestions(strategy = "reviewed")` was simply an unreachable
consumer waiting for a producer. It is worse than unreachable: it runs every
accepted row through the *unattended* auto-apply compatibility gate — the
lexical heuristic that decides whether a seeded top-1 hit is safe to write into
a dictionary nobody has looked at. So a term a human read the definition of and
accepted could be dropped because its label did not lexically match the column
name, and the caller was told only that some rows "did not meet the requested
filters". Filed as backlog **#118** and fixed here: `reviewed` is exempt, `top`
keeps the gate. This is why the feature could not have shipped by "just wiring
up the existing seam".

**2. The descriptor is patched, not rebuilt — the plan said the opposite.**
The plan specified extracting `.ms_rebuild_datapackage_descriptor(path)` from
`write_salmon_datapackage()`. That block is ~160 lines interleaved with the CSV
byte rendering inside a 3.8k-line file, and extracting it would have made this
change mostly a refactor of the writer with the review flow as a passenger.
`apply_sdp_semantics()` instead patches the seven `*_iri`/`term_type` field keys
for exactly the columns the review changed — the same technique
`migrate_sdp_methods()` already uses and which is already tested — and asserts
the patched shape matches what a rebuild would emit (present when non-empty,
**absent** when empty). A rebuild also has a cost the plan did not price: it
would discard descriptor content a user added by hand. The extraction remains a
reasonable refactor; it is not a prerequisite for this feature.

**3. The console does not escape its external text, and escaping it would be a
bug.** The plan's trap list says ontology definitions "must pass through
`.ms_cli_escape()` before reaching cli". They never reach cli:
`.ms_review_render_lines()` returns a plain character vector and
`print.ms_semantic_review()` emits it with `cat()`, which has no template layer.
Escaping there would render a definition containing `{reach}` as `{{reach}}` —
corrupting exactly the text the rule protects. The rule is satisfied by keeping
the text off the template path, and it *is* applied where this feature does use
cli: every abort carrying a caller- or ontology-supplied string goes through
`.ms_cli_escape()`/`.ms_cli_bullets()`, which `test-cli-safety-guard.R` checks
automatically because it walks the whole installed namespace. The `cat()` branch
gets its own pinned test, because a static guard cannot see a path it does not
model. **Also corrected:** the plan says to use "cli's own fallback when
`ansi_has_hyperlink_support()` is `FALSE`". That fallback drops the URL entirely
when the link text differs from it, which would hide the OLS deep link
completely. The fallback is written out rather than inherited.

**4. `create_sdp()`'s default shortlist is one candidate long.**
`semantic_max_per_role` defaults to **1** (`R/dictionary-helpers.R`), so the
"numbered shortlist" a default package carries has exactly one entry per slot.
The feature works, but its value shows only at `semantic_max_per_role = 3` or
higher, or after re-running `suggest_semantics()`. Nothing in the plan noticed
this, and the target-experience mock-up in this document silently assumes
otherwise.

**Two limits found by testing, both now documented rather than hidden.**
*(Both closed by M4 on 2026-08-25 — kept because they are the measurement that
scoped it.)* `review_semantics()` shows *shortlists, not gaps*: a slot for
which retrieval returned nothing never appears in the queue, so a user can
complete the entire review and still fail `require_iris = TRUE`. That is the
strongest argument yet for M4's `review_metadata()`, which reports
required-but-unfilled fields regardless of whether anything was suggested.
Second, `require_iris = TRUE` also refuses free-text `MISSING …:` placeholders,
so **proof 5 of this plan cannot be met by M1–M3 alone** — the round-trip test
fills those fields with a direct CSV edit and says in a comment that M4 is what
replaces that step. Proof 6 ("a user who never opens Excel can complete the
whole review") is therefore *also* M4's to deliver; M1–M3 deliver it for the
semantic half only.

**Two defects the printed-call test caught before release**, recorded because
they are the exact failure mode this feature was most likely to ship with. A
`tables.csv` slot carries no `column_name`, so the console printed
`accept_suggestion(review, "NA", "entity", rank = 1)` — a call naming a column
that does not exist. And because `review$column_name == "spawner_count"` is `NA`
for that row, `df[NA, ]` inserted a phantom all-NA row, which made an unrelated
dictionary slot look ambiguous and print a spurious `table = "spawners"`. One
unguarded `==` against a legitimately-`NA` column produced both. The fix is
`.ms_review_match_slot_rows()`, where every comparison is `!is.na()`-guarded and
`column = NULL` deliberately selects the column-less slots.

**One scope decision.** `dataset.csv` · `keywords` is excluded from the queue:
it is a comma-joined list, not a single IRI, so it has no "accept this
candidate" semantics. Queueing it would reproduce exactly the internally
unsatisfiable state the decision log below reversed itself over. `tables.csv` ·
`observation_unit_iri` **is** in scope, because `create_sdp()` can leave a
`REVIEW:` marker there and a marker the console cannot clear would block strict
validation.

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
| Write-back addresses a slot by `target_sdp_file` + `target_row_key` + `target_sdp_field` | The producer already chose that address in `.ms_semantic_discover_targets()`. Re-deriving one would be a second spelling of the same thing, free to drift | 2026-08-25 |
| Descriptor patched surgically, not rebuilt — **supersedes** the "rebuild `datapackage.json`" row above | Extraction is a 160-line refactor of `write_salmon_datapackage()` with this feature as a passenger, and a rebuild would discard hand-added descriptor content. The patch asserts it produces the shape a rebuild would | 2026-08-25 |
| Console emits via `cat()`, and therefore does **not** escape external text | `.ms_cli_escape()` is the mechanism for the cli template path. On a `cat()` path it would print `{{reach}}` for `{reach}`, corrupting the text the rule protects. The rule is met by keeping the text off the template path; the cli aborts in the same files still escape, and the namespace-walking guard checks them | 2026-08-25 |
| `dataset.csv`/`keywords` excluded from the queue; `tables.csv`/`observation_unit_iri` included | A keyword list has no "accept this candidate" semantics, and showing an undecidable row is the state the row below reversed itself over. An `observation_unit_iri` **can** carry a `REVIEW:` marker, so excluding it would leave a marker the console cannot clear | 2026-08-25 |
| **Reversed: #75 is fixed in slice 1 by suppressing method/constraint auto-apply.** Method *acceptance* + `methods.csv` registration stay slice 2 | Review caught that the two rows above were jointly unsatisfiable: showing an unacceptable `REVIEW:` marker means slice 1 cannot deliver proof 5 (validation passes) or proof 6 (finish without Excel) for any package with a method-ish column name. Stopping the marker at its source is smaller than supporting acceptance, and it closes #75 | 2026-08-11 |
| The three descriptor builders are extracted from `write_salmon_datapackage()` and shared with the setters — **narrowing, not reversing, the "patched not rebuilt" row above** | The rejected extraction was `.ms_rebuild_datapackage_descriptor(path)`, a whole-descriptor rebuild interleaved with CSV rendering. These are three pure functions over one metadata row each, with no filesystem knowledge, and the patch-versus-rebuild choice stays the caller's. At M4's size a private patch table would be a second implementation of the descriptor, and `datapackage_consistent_with_csv_metadata` is dead so nothing would catch the drift. Extract the shared *shape*, not the shared *procedure* | 2026-08-25 |
| `review_metadata()` reports what the **validator** refuses, not what the schema calls required | The schema calls `observation_unit_iri` `recommended` and the measurement IRIs `conditional`, yet strict validation refuses both. A reporter that trusted the schema would show a clean package that still fails. The enumeration of the measurement IRIs is pinned by a test that drives `validate_dictionary()` itself | 2026-08-25 |
| The printed value slot is `<hint>` and the setters **refuse** it | `creator = "..."` is pasteable, and a package whose `creator` is `...` passes strict validation with the `MISSING METADATA:` marker gone — strictly worse than before. The address is resolved before the value is checked, so an unedited paste still proves the row exists | 2026-08-25 |
| The setters name the common fields and accept the rest through schema-checked `...` | The plan's "named arguments beat a generic `field = value`" is right about discoverability and wrong about closure: the schema is loaded at runtime and can gain fields, so a fixed argument list is a second spelling of it that decays silently. Checking `...` against the schema keeps the misspelling-is-an-error property that was the argument for naming them | 2026-08-25 |
| A printed call is emitted one argument per line and is **never** passed through `strwrap()` | `strwrap()` normalises whitespace and adds sentence spacing, so wrapping a call rewrites the text inside its own string literals. Prose may be wrapped; code may only be broken at an argument boundary | 2026-08-25 |

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

**M1–M3, 2026-08-25.** The feature works and the console is what the plan
described. What is worth carrying forward is narrower than that.

**The one thing that mattered most was the cheapest to build.** Almost all the
value of this milestone is in a design decision — print the call, let the user
paste it — that costs nothing to implement and that a reasonable implementer
would have replaced with an interactive prompt, because a prompt *feels* more
helpful. It is not: a prompt reproduces the spreadsheet's defect in a nicer
font. The plan was right to write that down in a decision log rather than leave
it to be re-derived, and this retrospective exists to say the same thing again.

**The riskiest artefact in the feature was a string.** Everything else here is
guarded by machinery that already existed: collation, atomic writes,
containment, cli safety. The printed call had no guard at all, and it is the
part a user actually executes. Writing a test that *evaluates every printed
line and asserts the resulting decision* found two defects in the first working
version, both from the same unguarded `==` against a legitimately-`NA` column.
The generalisable rule: **if a program's output is meant to be run, run it in
the tests.** Rendering assertions (`grepl` on the line) would have passed over
both.

**The plan's four wrong calls were all in the same direction.** Each assumed an
existing mechanism could be reused as-is: the `strategy = "reviewed"` seam
(which silently filtered), the descriptor rebuild (a refactor, not an
extraction), cli escaping (wrong for a `cat()` path), and cli's hyperlink
fallback (drops the URL). None was a design error; all four were *unverified
assumptions about code the plan cited but did not run*. A plan that cites a
line number has checked that the line exists, not that it does what its name
says.

**What this milestone did not deliver, restated because it is easy to overclaim
from the NEWS entry.** The gate in backlog #74 is met for IRIs and only IRIs.
`validate_salmon_datapackage(require_iris = TRUE)` still fails after a complete
console review, and the plan's proofs 5 and 6 belong to M4. The round-trip test
fills the free-text fields with a direct CSV edit precisely so that this stays
visible in the test rather than being smoothed over.

**Kept for M4.** `review_metadata()` is now the more important half of what
remains, not the smaller one. It closes both open gaps at once — free-text
placeholders *and* the shortlists-not-gaps blind spot — because it reads
required-but-unfilled from the schema rather than from whatever retrieval
happened to return.

---

**M4–M5, 2026-08-25. The stream's own bar is met, and it is measurable.**
`create_sdp()` → `review_semantics()` → `apply_sdp_semantics()` →
`review_metadata()` → `set_sdp_*()` →
`validate_salmon_datapackage(require_iris = TRUE)` **passes, with no file
opened in a spreadsheet at any point.** Proofs 4, 5 and 6 are delivered, and
the round-trip test that used to fill the free-text fields with a direct CSV
edit no longer contains one. What is worth carrying forward is not that it
works.

**The M1–M3 agent's call that M4 was the larger half was right, and for a
reason it could not have known.** It argued from the two gaps
`review_metadata()` had to close. The actual cost was somewhere else: the
setters mutate a metadata CSV, and **`datapackage.json` duplicates most of what
they mutate** — title, description, contributors, licences, temporal extent,
resource titles and descriptions, primary keys, every field entry. M1–M3 met
that duplication once, narrowly, for seven IRI keys, and solved it with a small
patch table. M4 meets it across three files and every free-text field, and at
that size a patch table is a *second implementation of the descriptor*, free to
drift from the writer's — and nothing would ever notice, because the rule that
would (`datapackage_consistent_with_csv_metadata`) is one of the dead rules in
`sdp.rules.yaml`. So the three descriptor builders were **extracted from
`write_salmon_datapackage()` and shared**, and the assertion the plan asked for
("the patch produces the shape a rebuild would") became true by construction
rather than by a test that has to imagine every field. The test still exists
and compares against an actual rebuild.

Note what this does **not** contradict. The plan's rejected extraction was
`.ms_rebuild_datapackage_descriptor(path)` — a whole-descriptor rebuild
interleaved with CSV byte rendering, which M1–M3 correctly refused. Three
pure functions over one metadata row each are a different object: they carry no
filesystem knowledge, and the rebuild-versus-patch decision is still the
caller's. *Extract the shared shape, not the shared procedure* is the rule that
distinguishes them.

**A `strwrap()` call would have shipped a printed line that is not the code it
looks like.** The first version wrapped the printed setter call with the same
helper that wraps a definition. `strwrap()` normalises whitespace and inserts
sentence spacing, so it rewrites text *inside string literals* — a printed
`set_sdp_column(pkg, "x", column_description = "counted.  twice")` comes back
with different content than the user will paste. Definitions are prose and may
be wrapped; a call is code and may only be broken at an argument boundary. The
printed call is now emitted one argument per line. This is the M1–M3
retrospective's rule ("if a program's output is meant to be run, run it in the
tests") arriving at a defect it did not predict: rendering *and* execution are
both needed, because the corruption happens in the rendering and is only
visible after evaluation.

**The value slot in a printed call must be un-pasteable.** An obvious design
prints `creator = "..."`. That is worse than the placeholder it replaces: a
user who pastes without editing gets a package whose `creator` is `...`, and it
**passes strict validation**, because the `MISSING METADATA:` marker — the only
thing that made the field visible — is gone. The templates are therefore
`<add creator, team, or originating program>` and the setters refuse anything
of that shape. The address is resolved *before* the value is checked, so
pasting an unedited call still proves the row exists, which is what the
printed-call test asserts.

**A local `R CMD check` "Status: OK" is evidence about your R, not about CI's —
and the first explanation for the difference was wrong.**
`R/sdp-field-setters.R` shipped with two literal `·` separators (R code must be
ASCII; comments are exempt). Local `R CMD build . && R CMD check --no-manual`
reported **Status: OK**; CI failed. The obvious reading — CI runs
`rcmdcheck::rcmdcheck(args = "--no-manual", error_on = "warning")`
(`.github/workflows/R-CMD-check.yaml:102`), so it escalates a warning the plain
invocation tolerates — **is not what happened**, and was written into
`AGENTS.md` before being checked. The local log says
`checking code files for non-ASCII characters ... OK`: there was no warning to
escalate. The real difference is the **R version**: 4.5.2 locally, **4.6.1** on
CI, and 4.6 tightened that check. Neither `--as-cran` nor `error_on` would have
caught it on this machine.

Two things worth keeping. **A stricter invocation cannot run a check your R does
not have** — so "I ran the CI line locally and it passed" is still not the same
claim as "CI will pass", and comparing `R.version.string` against the CI log is
the cheap way to know. And this note itself is the example: a plausible causal
story about a verification gate, written from one observation and one glance at
the workflow file, that survived until someone re-read the log it claimed to
explain.

*(`R/review-console.R` already escapes its separators as `·`, which is what
made this a one-line fix and also what made it invisible — the correct pattern
was one file away and renders identically on screen.)*

**Four defects in the M1–M3 API, all found by teaching it.** Writing a lesson
against a shipped API is a harsher usability test than reviewing it, and it
found three round-trip failures plus one retrieval question. All three of the
first kind have the same shape: *the feature did the right thing once and then
forgot it.* A rejection was written to `semantic_suggestions.csv` and never
read back, so a reviewer was asked the same question the next day. The
rejection `reason` — the one field this whole stream is about — was never
persisted at all. And an empty queue under a mistyped `columns` filter printed
the *completion* message. Each is a missing return leg on a path that was
otherwise correct, which is a class worth naming: **a feature that writes a
record and never reads it back has not been round-tripped, and no test that
only writes will say so.** All three are fixed here. The fourth —
`variable` and `property` retrieving the identical ranked list — is a
retrieval-filter question, not a review one, and is filed as backlog **#119**
rather than fixed blind.
