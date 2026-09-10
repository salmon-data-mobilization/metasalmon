# Workpad — B-49

## Queue item

**B-49** — `validate_salmon_datapackage()` checks far less than it claims
(legacy #49, repo metasalmon, stream S1, severity P1). Claimed by
`a-a7bf88a77f89e8db` on 2026-09-10; work branch
`agent/B-49/a-a7bf88a77f89e8db`, worktree
`hub-worktrees/salmon-data-mobilization-metasalmon-B-49`.

Scope is the item's `retires_when`, read literally: the validator checks
required-column nullability and schema-required metadata fields, refuses corrupt
SSSOM and decomposition artifacts instead of reporting success, and a test
asserts a failure for each class. The declared-primary-key clause closed under
#77 and was not touched.

## What changed and where

`R/package-helpers.R`

- `validate_salmon_datapackage()` now calls
  `.ms_validate_optional_sdp_semantic_artifacts(path)` right after the
  observation-structure gate. That helper runs `validate_sdp_sssom()` when
  `metadata/semantic/mapping-sets.json` is present and
  `validate_sdp_measurement_decompositions()` when either managed decomposition
  file is present (file or dangling symlink, the observation-structure
  precedent). Presence is by managed file name, exactly as
  `R/knb-publication.R` and `R/knb-sdp-archive.R` already detect it; the
  directory is never scanned, so an unapproved draft under `metadata/semantic/`
  stays local. **Class 3.**
- `.ms_collect_package_validation_issues()`, per-table loop, after the
  extra-columns check: "Tidy check 4" — a dictionary row with `required = TRUE`
  whose data column carries an NA or whitespace value is a structural `columns`
  issue in every mode. Only columns present in the data are checked (an absent
  one was already reported). **Class 1.**
- `.ms_collect_package_validation_issues()`, before the dictionary-empty check:
  blank schema-required **key** fields (`dataset_id`, `table_id`, `file_name`,
  `column_name`) are structural issues in every mode, typed by file
  (`dataset` / `tables` / `dictionary` / `codes` — the existing eight
  categories, none added). Blank schema-required **non-key** fields take the
  placeholder channel: a `cli_warn` in the default mode (mirrors "Tidy check 3"),
  and under `require_iris = TRUE` they join `final_review_issues` and abort.
  **Class 2.**
- New helpers beside the validator: `.ms_package_metadata_frames()` (one spelling
  of file → frame / issue type / source name / id fields) and
  `.ms_collect_blank_required_metadata_fields(pkg, keys = FALSE)`.
- Roxygen description of `validate_salmon_datapackage()` rewritten to list what
  it checks — the item title is about the claim, so the claim moved too.
  `man/validate_salmon_datapackage.Rd` regenerated with `devtools::document()`;
  the local roxygen2 8.1.0 also rewrote `DESCRIPTION`
  (`Config/roxygen2/version`) and reflowed `NAMESPACE`, and both were reverted
  as unrelated churn.
- Strict-abort hint now names "blank schema-required fields".

`R/sdp-field-setters.R`

- `.ms_schema_required_metadata_fields(file_name)` — every `constraints.required`
  field, keys included — split out of `.ms_required_metadata_fields()`, which now
  derives from it. The validator and `review_metadata()` therefore read one
  schema parse, so they cannot disagree about which fields block.

Tests

- `tests/testthat/test-package-helpers.R` (beside the #77 tests):
  "a column declared required must not ship missing values";
  "a blank schema-required metadata field warns by default and fails strict
  validation"; "a blank metadata key field is a structural error in every mode".
- `tests/testthat/test-sssom.R`: "validate_salmon_datapackage refuses a corrupt
  SSSOM artifact" (manifest SHA-256 drift).
- `tests/testthat/test-measurement-decompositions.R`:
  "validate_salmon_datapackage refuses a corrupt decomposition artifact" (CSV
  bytes drift from the manifest; then manifest deleted with the CSV present).
  The decomposition fixture lives inside that test file rather than a helper,
  which is why the artifact tests sit beside their fixtures instead of in one
  new file.

Other

- `NEWS.md`: new `metasalmon (development version)` heading with a `### Fixed`
  entry for the three classes.
- `.Rbuildignore`: `^\.hub$` added so this workpad does not reach the tarball.
- The default-mode warning's hint line uses `cli::qty()` so it reads "Fill it
  ... as an error" for one field and "Fill them ... as errors" for several;
  rendered both ways by hand before the suite ran.

## Commands run and results

R used: **R version 4.3.3 (2024-02-29)** (apt). CI runs a newer R; a check that
is green here is evidence about this R, not CI's (AGENTS.md, "A green local
check is evidence about your R"). No non-ASCII characters were added to R code.

Suggests **absent** when the suite ran (second install phase still in
progress): pdftools, readxl, openxlsx, emld, jsonvalidate, dataone, datapack.
Present: knitr, rmarkdown, frictionless, XML. Tests gated on the absent ones
skip; a green run here is not full coverage of those paths.

### Failing-before (tests written first, run with `R/` stashed at origin/main)

Runner: `pkgload::load_all()` + `testthat::test_file(<file>, desc = <name>)`.

| Class | Test | Before |
|---|---|---|
| 1 nullability | a column declared required must not ship missing values | **FAIL** — `expect_error(validate_salmon_datapackage(path))` did not throw (`test-package-helpers.R:4110`) |
| 2 schema-required (non-key) | a blank schema-required metadata field warns by default and fails strict validation | **FAIL ×2** — no warning in default mode (`:4138`), no error under `require_iris = TRUE` (`:4142`) |
| 2 schema-required (key) | a blank metadata key field is a structural error in every mode | **ERROR** — validator aborted, but the only issue it named was "column_dictionary.csv references table_id values not present in tables.csv"; the blank `table_id` itself was never reported |
| 3 SSSOM | validate_salmon_datapackage refuses a corrupt SSSOM artifact | **FAIL** — validation passed over a manifest whose SHA-256 was all zeros (`test-sssom.R:479`) |
| 3 decomposition | validate_salmon_datapackage refuses a corrupt decomposition artifact | **FAIL ×2** — passed over drifted CSV bytes (`:821`) and over a deleted manifest (`:827`) |

### Passing-after (same runner, patched `R/`)

All five: `failed=0`, passed 2 / 2 / 1 / 2 / 3 expectations respectively.

### Touched files in full (`testthat::test_file`, patched `R/`)

- `test-sssom.R`: failed=0 skipped=0 passed=49
- `test-measurement-decompositions.R`: failed=0 skipped=0 passed=72
- `test-package-helpers.R`: failed=0 skipped=0 passed=407

### Full suite (`devtools::test()`)

Run 21:56–21:59 UTC, 2026-09-10, `devtools::test(reporter = "summary")`:
**failed=6 (plus 2 errors = 8 failing items), skipped=103, passed=3192,
warnings=38.** Suggests absent at suite start: pdftools, readxl, openxlsx,
emld, jsonvalidate, dataone, datapack (the second install phase was still
running; at suite end only dataone and datapack were still absent, so some
early-alphabet files ran without emld/jsonvalidate and skipped where gated).
The 103 skips are those gates plus the `not CI` skip in
`test-ci-optional-deps.R`.

**All eight failing items pre-exist and are unrelated to this change.** Shown,
not assumed: with `R/` stashed back to `origin/main` and the same runner, the
same four files produce the identical eight —

- `test-dictionary-helpers.R` "infer_dictionary recognizes wide numeric and
  percent metrics" (1 failure) — a column name containing `é` is not matched;
  this container runs the **C locale** (`Sys.getlocale("LC_CTYPE") == "C"`,
  `l10n_info()$UTF-8 == FALSE`).
- `test-github-helpers.R` "read_github_csv can read remote content with a
  token" and "read_github_csv_dir can fetch when a token is configured"
  (2 errors) — `HTTP 404 Not Found` from `httr2::req_perform()` through the
  session proxy; network, not code.
- `test-iri-predicates.R` (4 failures) — `ideographic_space` accepted as
  whitespace-free by `.ms_absolute_iri_shape()` and its callers; the same
  C-locale cause, in the regex engine's `[[:space:]]` class (the file's own
  header says the engine is contractual and locale-sensitive).
- `test-review-console.R` "print() emits exactly the rendered lines"
  (1 failure) — rendered-text comparison under the same non-UTF-8 locale.

Baseline output (original `R/`):
`test-dictionary-helpers.R failed=1 passed=289`;
`test-github-helpers.R errors=2 passed=31`;
`test-iri-predicates.R failed=4 passed=26`;
`test-review-console.R failed=1 passed=106` — the same names, the same counts.
None of the four files exercises the validator paths this change touches.
Not fixed here: a locale-dependent test is a separate finding (see below).

### Other checks

- `devtools::document()` — only `man/validate_salmon_datapackage.Rd` kept.
- `git diff --check` — clean (exit 0).
- `rcmdcheck::rcmdcheck(args = "--no-manual", error_on = "warning")` — the
  CI line, run 22:01–22:06 UTC: **`Status: 2 ERRORs, 1 WARNING`**, so the call
  threw, and none of the three is this change:
  - WARNING, "checking R files for syntax errors": `Sys.setlocale("LC_CTYPE",
    "en_US.UTF-8")` cannot be honored — the container has no such locale (CI
    sets `LANG: en_US.UTF-8` and has it). Environment.
  - ERROR, "checking tests": `[ FAIL 8 | WARN 38 | SKIP 27 | PASS 3741 ]` — the
    same eight items as the suite above (fewer skips because more Suggests had
    finished installing by then), each reproduced against `origin/main`'s `R/`.
  - ERROR, "checking running R code from vignettes":
    `migrating-to-sdp-0-3-0.Rmd` and `tidy-data-for-sdp.Rmd` both fail at
    their first statement, `readr::read_csv("<pkg>-sdp/metadata/tables.csv")`,
    because nothing created that directory. Measured with `knitr::purl()`: both
    vignettes set `eval = FALSE` globally inside a `purl = FALSE` setup chunk,
    so the tangled script the check sources contains every illustrative chunk
    as live code and its line 2 is that read, with no `create_sdp()` or
    `write_salmon_datapackage()` before it. No `R/` path is reached before the
    failure, so it cannot be this change; whether CI's runner exercises the
    same step is not knowable from here.
  Every other check line was OK, including "R code for possible problems", the
  Rd/usage/code-documentation checks over the regenerated man page, examples,
  and "code files for non-ASCII characters" — with the standing caveat that the
  last is R-4.3.3's answer, not R-4.6.1's.

## What I did not do, and why

- **Did not touch the declared-primary-key check.** Closed under #77 in 0.2.6
  and excluded by the item's `retires_when`.
- **Did not make a blank non-key required field a structural error in the
  default mode.** `create_sdp()` writes placeholders into the required fields it
  cannot fill, and the package's own vocabulary treats a placeholder as
  *incomplete* (warn by default, error under strict) rather than *broken*. A
  blank required field is the same state minus the marker, so it takes the same
  channel; `review_metadata()` documents these as blocking *strict* validation,
  and the documented `create_sdp()` → `validate_salmon_datapackage(require_iris
  = FALSE)` example must keep passing. Keys are the exception and are structural,
  because a row without its key cannot be addressed by any setter.
- **Did not scan `metadata/semantic/` for stray `.sssom.tsv` files.** The
  publication path deliberately publishes only what the manifest names and
  leaves "an editor backup, private review note, or unapproved mapping draft"
  local; a validator that refused those would contradict that contract. A
  mapping set the manifest does not bind is therefore not a package artifact.
- **Did not add a conformance test driven from `sdp.rules.yaml` rule ids.**
  That is #48 / the S1 execplan, and the S1 card says it waits on the #90
  authority ruling.
- **Did not port to metasalmonpy.** The claim grant covers one branch in the
  item's repository. See below.

## Belongs to another item

- **Mirror port owed (candidate new queue item, repo `metasalmonpy`, stream
  S10):** the three checks above in `package_io.py`
  (`_collect_package_validation_issues()` / `validate_salmon_datapackage()`,
  the row-41 collector), calling `sssom.py`'s `validate_sdp_sssom` and
  `measurement_decompositions.py`'s `validate_sdp_measurement_decompositions`
  by manifest presence, plus the key/non-key split of the schema-required
  fields against its own schema parse. Not a deviation to register: it is
  "R shipped first" lag, exactly as the 0.4.0→0.5.0 window is recorded in
  `knowledge/parity-deviations.md`. NEWS says so.
- **Observation for #48 / #90 (spec authority), not acted on:**
  `inst/extdata/schema/frictionless/metadata/codes.schema.json` does not mark
  `code_value` as `constraints.required`, while `.ms_metadata_key_fields()`
  treats it as a key of `codes.csv`. This change follows the schema (a blank
  `code_value` is not reported as a blank key). Whichever artifact #90 rules
  normative decides whether the schema is missing a constraint.
- **Candidate new item (metasalmon, S2 correctness debt):** six tests are
  locale-dependent and fail in a C / non-UTF-8 locale on R 4.3.3 —
  `test-dictionary-helpers.R:218`, the four `test-iri-predicates.R` whitespace
  cases, `test-review-console.R:231`. They pass on CI's UTF-8 runner, so the
  suite is green there and red on any container without `LANG` set; either the
  tests declare the locale they need (`withr::local_locale()` /
  `skip_if_not(l10n_info()$\`UTF-8\`)`) or the predicates stop depending on it.
  Evidence: this workpad's baseline run.
- **Candidate new item (metasalmon, S2 or S11 vignettes):** the tangled code
  of `vignettes/migrating-to-sdp-0-3-0.Rmd` and `vignettes/tidy-data-for-sdp.Rmd`
  fails `R CMD check`'s "running R code from vignettes" on any machine, because
  `eval = FALSE` is set globally from a `purl = FALSE` chunk and `purl()` only
  honours the option on chunk headers. Fix is in the vignettes (per-chunk
  `eval = FALSE`, or `purl = FALSE` on illustrative chunks), not in `R/`.
  Evidence: the rcmdcheck section above and the two tangled scripts.
- **Observation, not acted on:** on the descriptor-only read path
  (`datapackage.json` with no canonical CSVs) `contact_name` / `contact_email`
  arrive as NA by construction, so such a package now warns in the default mode
  and fails strict validation on those fields. That is the honest answer for a
  package with no contact, but if the descriptor carries contact information in
  a field the reader does not map, the fix is in
  `.ms_descriptor_provenance()`, not here.

## Guards added, and what retires them

- `.Rbuildignore` `^\.hub$` — keeps the protocol's workpad out of the R tarball.
  *Retires when:* `HUB.md` stops placing `.hub/workpad.md` on the work branch,
  at which point the line is deleted with the directory.
- No skip, suppression, allowlist entry, or workaround was added. The "presence
  by managed file name" rule in `.ms_validate_optional_sdp_semantic_artifacts()`
  is a design choice inherited from the two existing consumers, not a guard,
  and its comment says why.
