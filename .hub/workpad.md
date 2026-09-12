# B-95 workpad

## Queue item

**B-95** — Stop `create_sdp()` emitting `codes.csv` rows for columns it typed
`attribute` (backlog #95; repo metasalmon; stream S12; severity P2).

Retires when: `create_sdp()` on both bundled examples produces no
`targets a non-categorical or unknown column` error, corrected in
`infer_column_role()` rather than in the code-row seeder per the 2026-09-05
ruling on Q29, and pinned with a fixture on both sides.

## What changed, and where

- `R/dictionary-helpers.R`
  - New internal helpers `.ms_code_list_limit()`, `.ms_code_list_values()` and
    `.ms_values_form_code_list()`, placed with the other value-shape helpers.
    They carry the code-row seeder's original criterion unchanged: a character
    or factor column with 1 to 30 distinct non-missing values, the values
    returned exactly as the seeder has always written them.
  - `infer_codes_from_resources()` (the seeder) now calls
    `.ms_code_list_values()` instead of holding its own copy of the threshold
    and the `unique(na.omit(as.character()))` expression. Its output is
    byte-for-byte what it was; this is the "one decision, two consumers"
    refactor that stops the two from drifting again, not a behaviour change.
  - `infer_column_role()` reads the same predicate in the three places that
    used to answer `attribute` for an enumerable string column: the
    identifier-qualifier branch (`stock_ID_quality`), the method-token branch
    (`ESTIMATE_METHOD`, `ENUMERATION_METHODS`), and the final default. The
    identifier, temporal and measurement checks still run first, so a key, a
    date, or a unit-bearing / percent-like text column keeps its role.
- `tests/testthat/test-dictionary-helpers.R` — six existing expectations whose
  verdict the ruling changes (`counting_method`, `measurement_method`,
  `sample_type`, `sampleSizeUnit`, `commentValue`, `QA/QC...6`) now expect
  `categorical`, each with a one-line comment saying why. In every one of those
  tests the assertion that mattered was "not measurement", which still holds.
- `tests/testthat/test-codes-target-categorical.R` — new. Unit tests on
  `infer_column_role()` (enumerable → categorical; wide or empty → attribute;
  identifier / temporal / measurement verdicts stay ahead), a shared-decision
  test on `infer_salmon_datapackage_artifacts()` (the set of seeded columns
  equals the set of categorical columns), and the two fixtures the retirement
  condition asks for: `create_sdp()` on each bundled example, with the
  spec validator's `validate_codes` rule applied in R to the output.
- `NEWS.md` — entry under a new `metasalmon (development version)` heading.
  `DESCRIPTION` is left at 0.5.0, matching how the 0.4.0 → 0.5.0 cycle was
  carried (heading added, version bumped only at release).

## Commands run and results

Toolchain: `R version 4.3.3 (2024-02-29)` from apt, not the R CI runs
(AGENTS.md records CI on R 4.6.1, whose checks are stricter -- a clean local
check is evidence about this R, not CI's). Box locale is `C` (non-UTF-8); CI
is UTF-8, so the verifying runs below were repeated under `LC_ALL=C.UTF-8`.
Suggests absent while the suite ran (second install phase still running):
pdftools, readxl, openxlsx, emld, jsonvalidate, dataone, datapack. Tests that
need them skip, so a green run here is not full coverage of those paths.

### Failing-before (untouched `origin/main` @ 6357ffd, `git archive` snapshot)

`Rscript b95-evidence.R <snapshot> <out>` builds `create_sdp()` output for
both bundled examples (`seed_semantics = FALSE`, `check_updates = FALSE`) and
applies the spec validator's `validate_codes` rule in R; then
`python3 smn-data-pkg/scripts/validate_package.py <pkg>` (sibling checkout
@ 47f0e81) on the same bytes.

| example | codes.csv rows | rows targeting a non-categorical column | spec validator `non-categorical` errors |
|---|---|---|---|
| 173-row `nuseds-fraser-coho-2023-2024.csv` | 22 across 6 columns (AREA, ESTIMATE_CLASSIFICATION, ESTIMATE_METHOD, ESTIMATE_STAGE, RUN_TYPE, SPECIES) | **22 across 6** -- every one; all six typed `attribute` | **22** |
| 30-row `nuseds-fraser-coho-sample.csv` | 129 across 12 columns (AREA, ENUMERATION_METHODS, ESTIMATE_CLASSIFICATION, ESTIMATE_METHOD, ESTIMATE_STAGE, FULL_CU_IN, POPULATION, RELIABILITY, RUN_TYPE, SPECIES, WATERBODY, WATERSHED_CDE) | **129 across 12** -- every one; all twelve typed `attribute` | **129** |

The 173-row numbers are the backlog's exactly. The 30-row count is 129/12
today rather than the 157/14 the 2026-08-21 recon measured: `START_DTT` and
`END_DTT` were converted to ISO afterwards (backlog #98), readr now types
them `Date`, and the seeder lists only character/factor columns. Same
mechanism, two fewer columns.

### Passing-after (this branch)

Same script against the worktree, same validator:

| example | codes.csv rows | rows targeting a non-categorical column | spec validator `non-categorical` errors |
|---|---|---|---|
| 173-row | 22 across the same 6 columns, now all `categorical` | **0** | **0** |
| 30-row | 129 across the same 12 columns, now all `categorical` | **0** | **0** |

`codes.csv` is unchanged in row count and column set on both examples, which
is the "seeder output byte-for-byte what it was" claim measured rather than
asserted. The validator still exits 1 on both packages, on the errors the
backlog calls "the other five" (blank measurement IRIs, placeholder licence)
-- none of them this item's.

### Tests

- `testthat::test_file("tests/testthat/test-codes-target-categorical.R")`
  (new): 29 expectations, all pass, under both `C` and `C.UTF-8`.
- `testthat::test_file("tests/testthat/test-dictionary-helpers.R")` (touched):
  passes under `C.UTF-8`. Under the box's `C` locale one expectation fails
  (`Discharge / Débit (cms)` at line 224) -- it fails identically on the
  untouched snapshot (line 218 there), so it is a pre-existing locale
  artefact of this machine, not this change.
- `devtools::test()` full suite, under `LC_ALL=C.UTF-8` (the run that
  counts): **0 failures**, 2 errors, 103 skips, exit 0. The two errors are
  `test-github-helpers.R:161` and `:264`, both `HTTP 404 Not Found` from
  `raw.githubusercontent.com` through this sandbox's proxy -- network, not
  code; they name no file this change touches. The skips are 87 `{emld}`,
  4 `{dataone}`, 2 `{openxlsx}`, 1 each `{pdftools}`, `{jsonvalidate}`,
  `{datapack}` (the absent Suggests above), 4 for the opt-in Theme A
  integrity matrix, 1 "not CI", 1 "no non-English LC_TIME", and 1 for the
  parity-register guard, which could not find a metasalmonpy checkout beside
  this repo and says so rather than reporting agreement.
- `devtools::test()` under the box's `C` locale, for comparison: exit 0 with
  the same two network errors, plus the `Débit` locale artefact above, four
  `test-iri-predicates.R` failures (Unicode whitespace classification) and one
  `test-review-console.R` failure (box-drawing characters rendered as
  `<U+2500>`). All five pass under `C.UTF-8` on **both** this branch and the
  untouched snapshot, so they are the locale's, not this change's. (That run
  also started before the tempdir fix to the new test helper, whose two
  errors in it are the bug fixed at the second run.)
- `git diff --check`: clean.
- `rcmdcheck::rcmdcheck(args = "--no-manual", error_on = "never")` -- CI's
  arguments, `error_on` lowered only so the whole result could be printed --
  under `LC_ALL=C.UTF-8`, run twice:
  - First run, while the Suggests phase was still installing: 2 ERRORS,
    0 WARNINGS, 2 NOTES (5m20s).
  - Second run after `r-suggests-done`, every Suggests package present:
    **2 ERRORS, 0 WARNINGS, 1 NOTE** (`[ FAIL 2 | WARN 38 | SKIP 25 |
    PASS 3773 ]`).

  The two ERRORs are the same in both runs and neither is this change's:
  1. `checking tests`: only the two `test-github-helpers.R` proxy 404s. The
     first run also had five `test-eml-export.R` errors -- `emld` was
     installed at 21:59, mid-check, so those tests stopped skipping while
     `jsonvalidate` was still absent ("Package jsonvalidate is required");
     with both present the file passes 149/149 and the second run has none.
  2. `checking running R code from vignettes`: `tidy-data-for-sdp.Rmd` and
     `migrating-to-sdp-0-3-0.Rmd` fail on their first executable line
     (`readr::read_csv("escapement-sdp/metadata/tables.csv")` and
     `"weir-counts-sdp/metadata/tables.csv"`), a file no chunk creates.
     Both set `eval = FALSE` in a setup chunk marked `purl = FALSE`, so the
     tangled script carries all their code live. This branch does not touch
     `vignettes/`, so those bytes are `origin/main`'s; on this R (4.3.3) the
     tangled run executes before "re-building of vignette outputs ... OK"
     instead of being skipped after it. Environment- and R-version-dependent
     (main is green on CI), and a candidate item below.

  The NOTE is `checking for hidden files and directories: .hub` -- the
  workpad directory this protocol puts on the branch. `.Rbuildignore` does
  not list it; a NOTE does not trip `error_on = "warning"`, so CI on this
  branch shows it without failing. Named below.

## What I did not do, and why

- **Did not touch the code-row seeder's behaviour.** Q29 put the correction
  in `infer_column_role()`; the seeder now calls the shared predicate but its
  criterion, threshold and output are unchanged (measured above).
- **Did not edit `inst/extdata/nuseds-fraser-coho-2023-2024-column_dictionary.csv`.**
  The shipped starter dictionary declares `attribute` for the six columns
  `create_sdp()` now types `categorical`, so the README walkthrough that
  installs it over the generated dictionary (and
  `test-example-round-trip.R` does the same) still carries the contradiction.
  That file is S12's curated artifact and not `create_sdp()` output, so
  changing it here would widen the item; it is named below as a candidate.
- **Did not add the rule to `validate_salmon_datapackage()`.** metasalmon's
  own validator still does not report this class; that is S1 (#48/#49),
  and B-49 is claimed by another agent right now.
- **Did not touch `.ms_column_is_semantic_code_candidate()`**, the stricter
  cardinality test that scopes *semantic seeding* of code values. It is a
  different decision (which code lists get term suggestions), not which
  columns have code lists, and it was not in the item.
- **Did not port to metasalmonpy.** The grant covers one branch in the item's
  repo. See below.
- Did not run `devtools::document()`: no roxygen on an exported object changed
  (`infer_column_role()` is `@noRd`).

## Belongs to another item

- **Candidate new item (metasalmonpy, parity port of B-95).** Mirror this
  change in metasalmonpy's `infer_column_role(col_name, series)`
  (`dictionary.py`; public there per parity-deviations row 42) and whatever
  seeds its code rows, sharing one code-list predicate the same way, and pin
  it with the same two-example fixture. **B-95's retirement condition says
  "pinned with a fixture on both sides", so this PR meets it on the R side
  only.** This is "R shipped first" lag, not a deliberate difference, so it is
  recorded here and not as a `knowledge/parity-deviations.md` row.
- **Candidate new item (S12).** Update the shipped 173-row starter dictionary's
  `column_role` for AREA, SPECIES, RUN_TYPE, ESTIMATE_METHOD,
  ESTIMATE_CLASSIFICATION and ESTIMATE_STAGE from `attribute` to
  `categorical`, so the walkthrough package it produces passes the spec's
  `validate_codes` rule. Six cells, no IRI choice involved.
- **Candidate new item (seeder, the downstream half of Q29).**
  `infer_codes_from_resources()` still lists values for a character column
  that role inference types `identifier`, `temporal` or `measurement` (a
  low-cardinality text key, a date column read as text, a percent-like
  measurement such as `"4.56%"`), so such a package still trips the spec rule.
  Neither bundled example has that shape when read with readr's defaults.
  The ruling's own words -- "the seeder is downstream of that decision" --
  describe the fix: seed codes only for columns the dictionary typed
  categorical. Out of this item's scope by its `retires_when`.
- **B-53 (`infer_column_role()` types 4-digit measurement columns temporal)**
  is adjacent and untouched; the code-list check runs after the temporal one,
  so this change neither fixes nor worsens it.
- **Candidate new item (hub protocol / packaging).** Every agent branch now
  carries `.hub/workpad.md`, and `R CMD check` NOTEs the hidden directory.
  Either `^\.hub$` goes into `.Rbuildignore` or the protocol says the
  directory is dropped before merge; today neither is written down.
- **Candidate new item (docs / check hygiene).** `vignettes/tidy-data-for-sdp.Rmd`
  and `vignettes/migrating-to-sdp-0-3-0.Rmd` set `eval = FALSE` inside a
  `purl = FALSE` setup chunk, so their tangled scripts fail on line one under
  "checking running R code from vignettes" on any R that runs that step
  before or instead of the rebuild (seen here on 4.3.3). Marking the code
  chunks `eval = FALSE` individually, or dropping `purl = FALSE` from the
  setup chunk, makes the check pass everywhere.
- Nit for S4/docs, not an item: `vignettes/glossary.Rmd` gives `SPECIES` as
  its example of an `attribute`; the generator now types a single-valued
  `SPECIES` column `categorical`.

## Retirement conditions of anything added

- **`codes_rows_off_categorical()` in
  `tests/testthat/test-codes-target-categorical.R`** re-implements the spec
  validator's `validate_codes` rule in R because metasalmon's own validator
  does not report the class. *Retires when* `validate_salmon_datapackage()`
  reports a `codes.csv` row targeting a non-categorical column (S1, #48/#49);
  the two `create_sdp()` tests then assert on the validator and the helper
  goes.
- **`.ms_code_list_limit()` / `.ms_code_list_values()`** are not guards; they
  are the seeder's criterion given one home. *Retires when* the seeder reads
  the dictionary role instead of re-deriving cardinality (the candidate item
  above), at which point role inference is the only consumer and the helper
  can fold back into it.
- No suppression, skip, allowlist entry or workaround was added.
