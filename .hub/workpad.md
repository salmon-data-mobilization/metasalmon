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

- **Workpad path collision (candidate queue item, hub protocol; not filed
  here -- the coordinator will):** merging `origin/main` (`9361e3b`) into this
  branch on 2026-09-12 conflicted add/add on `.hub/workpad.md`, because `main`
  carries B-95's workpad at the same path (merged with #112). Resolved by
  keeping this branch's file; B-95's stays in history through #112. The
  protocol's fixed workpad path means each merged handback overwrites the last
  on `main`, so `main`'s copy is only ever the most recently merged item's.
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

## Codex round (2026-09-12, on PR #111 head `cb03cf4` + `ad8d974`)

Four findings from the Codex review of #111 and one from its security review,
relayed by the coordinator. Each treated as a bug report: reproduced against
`ad8d974` (the head after the parity paragraph landed), then fixed with a test
that fails without the fix. None was refuted. Runner for every RED/GREEN
below: `pkgload::load_all()` + `testthat::test_file(<file>, desc = <name>,
reporter = "check")`, `LC_ALL=C.UTF-8`, R 4.3.3; RED is the run against the
unmodified `R/`, GREEN the same run after the fix.

### 1. P1 -- absent required metadata columns (real)

Finding: `.ms_collect_blank_required_metadata_fields()` scanned
`intersect(fields, names(df))`, so a required column missing from the header
was skipped rather than reported. Reproduced with `create_sdp()` output,
`contact_email` dropped from `dataset.csv` and `table_label` from `tables.csv`:
the collector returned zero rows, the default mode gave no schema-required
warning, strict validation passed, and `review_metadata()` (the same
`intersect` at `sdp-field-setters.R:268`) listed nothing. Why the four files
disagreed: the canonical reader normalises the dictionary and codes through
`.ms_align_cols()` (a missing column becomes NA and was therefore reported)
and reads `dataset.csv` / `tables.csv` as written.

Fix, one rule -- **a column the file does not have is blank in every row**:

- `R/package-helpers.R`, `.ms_collect_blank_required_metadata_fields()`:
  iterates every required field; an absent one scans as
  `rep(NA_character_, nrow(df))`. Same message, same channel as a blank value
  (placeholder warning / strict error for non-key fields, structural for
  keys), for all four files regardless of what the reader did.
- `R/package-helpers.R`, `.ms_collect_missing_table_observation_unit_iri_issues()`:
  the same rule. It returned nothing for a `tables.csv` with no
  `observation_unit_iri` column, so strict validation refused a blank IRI and
  passed a file that never declared the field. Found while making the rule
  one rule; included because leaving it would have been the next report of
  the same shape, one function above the one just fixed.
- `R/sdp-field-setters.R`, `review_metadata()`: aligns each frame to its
  schema fields (`.ms_align_cols()`, as the reader already does for the
  dictionary and codes) before the gap scan. It now reports the absent column
  and the printed `set_sdp_*()` call fills it -- `.ms_set_sdp_metadata()`
  already adds a column it is asked to write (line 802). Without this the
  NEWS claim that the validator and `review_metadata()` "cannot disagree
  about which fields block" would have become false the moment the validator
  learned to see absent columns.
- Roxygen of both functions says so; `man/validate_salmon_datapackage.Rd` and
  `man/review_metadata.Rd` regenerated with `devtools::document()`. roxygen2
  8.1.0 again rewrote `Config/roxygen2/version` and reflowed `NAMESPACE`; both
  reverted (DESCRIPTION keeps the yaml minimum from finding 5).

Tests:

- `test-package-helpers.R` "an absent schema-required metadata column is
  reported like a blank one" -- `create_sdp()` fixture with attribute-only
  columns, filled through `set_sdp_dataset()` / `set_sdp_table()` /
  `set_sdp_column()`, strict pass asserted first so the dropped column is the
  only defect in play. Then `contact_email` and `table_label` dropped: the
  default mode warns once, naming `dataset.csv$contact_email` and
  `tables.csv$table_label`; the strict verdict names
  `metadata/dataset.csv row 1 (dataset_id=absent-1) field contact_email is
  required by the SDP schema and blank` and `metadata/tables.csv row 1
  (table_id=obs, file_name=data/obs.csv) field table_label ...`; then
  `dataset_id` dropped: structural in the default mode.
  RED: `Expected blank_warning to have length 1. Actual length: 0.` and
  `Expected strict to be an S3 object. Actual OO type: none.` (strict
  validation returned its result list). GREEN: failed=0 passed=8.
- `test-package-helpers.R` "an absent observation_unit_iri column is refused
  like a blank one" -- semantic fixture with the column removed; default mode
  still passes, strict refuses. RED: `Expected suppressWarnings(...) to throw
  a error.` GREEN: failed=0 passed=2.
- `test-sdp-field-setters.R` "review_metadata() reports a required column the
  file does not have, and its call fills it" -- setter fixture brought to
  zero gaps, then `contact_email`, `table_label` and `observation_unit_iri`
  dropped; asserts exactly those three gaps by file / field / reason, that
  strict validation refuses, then executes the printed calls (this file's
  standard) and asserts the columns are back, zero gaps, strict passes.
  RED: `Actual:` (empty) versus `Expected: "dataset.csv contact_email
  required", "tables.csv table_label required", "tables.csv
  observation_unit_iri iri"`, and strict did not throw. GREEN: failed=0
  passed=9.

Not done: normalising `dataset.csv` / `tables.csv` inside
`read_salmon_datapackage()`. It would enforce the rule at one point, but it
changes the return value of an exported function (columns added and
reordered) that the writers, EML export and KNB publication consume; the
collector-level rule leaves the reader alone. Recorded so the next person does
not re-derive it.

### 2. P2 -- blank `dataset_id` crashes the alignment check (real)

Reproduced: `dataset.csv$dataset_id <- ""` with the tables and dictionary ids
intact gives `simpleError: missing value where TRUE/FALSE needed` in both
modes (`check_ids()`: `all(values == NA)` is NA). Fix:
`.ms_validate_dataset_id_alignment()` returns early when the root id is NULL,
NA or whitespace -- a blank root has nothing to align against, and
`.ms_collect_blank_required_metadata_fields(keys = TRUE)` then reports
`metadata/dataset.csv row 1 field dataset_id is required by the SDP schema and
blank` as the structural issue. Chosen over moving the key collector ahead of
alignment because it also covers an absent `dataset_id` column (NULL root)
and keeps the validator's order of checks. The validator is the only caller.

Test: `test-package-helpers.R` "a blank dataset_id is a structural issue, not
an R error" -- both modes; asserts an `rlang_error`, the structural message,
and that "missing value where TRUE/FALSE needed" is absent. RED: `Expected
caught to inherit from "rlang_error". Actual class:
"simpleError"/"error"/"condition".` and `Actual text: missing value where
TRUE/FALSE needed` (in both modes). GREEN: failed=0 passed=8.

### 3. P1 -- mirror the behaviour or log the exception (coordinator's)

The parity paragraph landed in `ad8d974` (`knowledge/parity-deviations.md`,
the concurrent agent) and `queue/items/B-124.yaml` is on `main` (`0a04524`).
The NEWS mirror sentence said the port is "owed under the S10 parity stream"
without pointing anywhere; it now reads "(queue item B-124; see the parity
register)". Nothing else.

### 4. P2 -- rebuild pkgdown after changing public documentation (real)

Run twice, because `origin/main` moved between the two runs. pkgdown 2.2.1
and pandoc 3.1.3 are installed; the checked-in site was built with pkgdown
2.2.0 and pandoc 3.8.3.

**On the pre-merge tree (`ad8d974`)** `Rscript scripts/build-pkgdown.R`
fails before it reaches the reference pages, and not because of this
change: pkgdown's home build renders every root Markdown file, and pandoc
rejects `HUB.md`, whose first 213 lines are a YAML front-matter block:

```
Reading HUB.md
YAML parse exception at line 198, column 6,
while scanning a simple key:
could not find expected ':'
Error: pandoc document conversion failed with error 64
```

Line 198 of that `HUB.md` is a list item ending in an unquoted colon (`...
that is not a small mechanical change:`) continued on the next line, which
YAML reads as a key without a value. The failed run's side effects under
`docs/` (favicons fetched from realfavicongenerator.net,
`deps/bootstrap-5.3.8/`, `authors.html`, `pkgdown.yml`, and the ignored
`AGENTS.html` / `CLAUDE.html`) were reverted or deleted. **Fixed on `main`
in the meantime**: the `HUB.md` that `9d5434e` (pull request #110) brought
in parses (`pandoc HUB.md -t html` exits 0, where the `ad8d974` copy still
fails at line 198), so no item is owed for the parse failure.

**On the merged tree (`c9a54a8`)** the same script exits 0 -- and modifies
107 tracked files under `docs/` plus 5 new ones: every page's `<head>` is
rewritten to reference `deps/bootstrap-5.3.8/` (pkgdown 2.2.1 ships a newer
Bootstrap than the 5.3.1 the checked-in site uses), favicons are re-fetched,
`pkgdown.yml` records the new pandoc and pkgdown versions, and the markdown
companions of every article and reference page are re-rendered by pandoc
3.1.3 with whitespace and table differences. That is the version churn the
coordinator said not to commit, and none of it was. The script also writes
**`docs/HUB.html` and `docs/PULL_REQUEST_TEMPLATE.html`** (with `.md`
companions, both indexed in `search.json`): pkgdown renders every root
Markdown file, and the script's `internal_pages` list deletes only `AGENTS`
and `CLAUDE`, so the hub protocol and the pull-request template become
public pages on the next real site build, and the forbidden-text check at
the end of the script does not see them. **Candidate item** (metasalmon,
docs): extend the list or exclude the files in `_pkgdown.yml`.

What was committed, produced from the regenerated man pages with the same
pkgdown: `pkgdown::build_reference(".", topics =
c("validate_salmon_datapackage", "review_metadata"), lazy = FALSE)`,
`pkgdown::build_news(".")`, `pkgdown::build_search(".")` (exit 0) -- the
targeted builds keep the site's existing `deps/bootstrap-5.3.1` references
and do not index the two stray pages. Committed:
`docs/reference/validate_salmon_datapackage.html` (the new description in
the body and the `<meta>` tags; the example ran, so its temp path changed
from the maintainer's `/var/folders/...` to `/tmp/...`; footer 2.2.0 ->
2.2.1), `docs/reference/review_metadata.html` (the one bullet; footer),
`docs/news/index.html` (the development-version section, plus
pkgdown/downlit rendering differences on *old* entries that the maintainers
should expect to flip back on their next full build: `<tr class="header|odd|
even">` on the 0.4.0 environment table, and three autolinks dropped --
`tidyr::pivot_longer()` twice and `read_csv()` once -- because those resolve
differently in this library; footer), `docs/search.json`, and, from the full
build, the two churn-free markdown companions
`docs/reference/validate_salmon_datapackage.md` and
`docs/reference/review_metadata.md` (the same description text and temp
path, nothing else). Not committed: `docs/reference/index.html` (footer
only) and `docs/news/index.md` (its regenerated form re-renders the 0.4.0
environment table and drops the tidyr links on old entries, so it is left
for the maintainers' next full build; the HTML changelog page is current).

### 5. P1 advisory, security -- `!expr` in SSSOM metadata (real)

Every `yaml::` read in `R/`, and which the validator reaches through #111:

- `R/sssom.R:241`, `.ms_sssom_parse_metadata()` --
  `yaml::yaml.load(yaml_text)` on the `#`-prefixed metadata block of every
  `.sssom.tsv` the manifest names. Reached by the validator through
  `.ms_validate_optional_sdp_semantic_artifacts()` -> `validate_sdp_sssom()`
  -> `read_sssom_mapping_set()`, and directly by `write_sdp_sssom()` and
  `read_sssom_mapping_set()`. **Fixed**: `eval.expr = FALSE`, with a one-line
  comment naming the finding. `DESCRIPTION` now declares `yaml (>= 2.2.0)`,
  the version that introduced the argument, so the call cannot become an
  "unused argument" error on an older yaml.
- Not reachable through this PR, listed here as a **candidate item**
  (metasalmon, S2): `R/eml-export.R:2920` `yaml::read_yaml(mapping_path)` and
  `R/knb-publication.R:297` / `:1572`
  `yaml::read_yaml(file.path(path, "metadata", "eml-mapping.yml"))` -- three
  reads of a collaborator-authored `eml-mapping.yml` on the EML-export and
  publication paths, all at yaml's default. `R/schema-helpers.R:168`
  (`yaml.load` on `sdp.rules.yaml` fetched from the spec repository) and
  `:199` (`read_yaml` on the vendored copy) read the package's own schema
  bundle rather than a collaborator's file; the same one-argument fix applies
  for defence in depth, but the trust boundary is different, so they are
  listed rather than changed here.
- Installed yaml is **2.3.12**. Its default is
  `eval.expr = getOption("yaml.eval.expr", FALSE)`, so a session option flips
  it on; with `eval.expr = FALSE` it returns the unevaluated expression as
  text and emits **no warning** on this version (verified:
  `yaml.load("a: !expr 1 + 1", eval.expr = FALSE)` gives `"1 + 1"` with no
  condition; with the option set and no argument it gives `2`). The test
  tolerates a warning anyway, for versions that emit one.

Test: `test-sssom.R` "validate_salmon_datapackage never evaluates an !expr
tag in SSSOM metadata" -- installs a benign mapping set through
`write_sdp_sssom()`, then patches the installed bytes to
`# mapping_set_title: !expr file.create("<sentinel>")` and the manifest
SHA-256 to match, so the validator's read is the only reader that meets the
tag (the writer re-renders metadata it parses, so a tag in the *source* never
reaches the installed file). Sets `withr::local_options(yaml.eval.expr =
TRUE)` as the worst case and runs `validate_salmon_datapackage()`. Asserts the
sentinel is absent, the verdict is not an error, and `read_sssom_mapping_set()`
returns the title as the literal text. RED (unpatched reader): `Expected
file.exists(sentinel) to be FALSE. actual: TRUE` and the title read back as
`"TRUE"` -- the validator executed the expression and then **passed**. GREEN:
failed=0 passed=5.

### Verification (all `LC_ALL=C.UTF-8`, R 4.3.3)

- Touched files in full (`testthat::test_file`): `test-package-helpers.R`
  failed=0 passed=425 (407 before this round); `test-sssom.R` failed=0
  passed=54 (49); `test-sdp-field-setters.R` failed=0 passed=89.
- `devtools::document()`: only `man/validate_salmon_datapackage.Rd` and
  `man/review_metadata.Rd` kept.
- `git diff --check`: clean.
- testthat 3.3.2 writes `tests/testthat/_problems/` on a failing run (the RED
  runs above); it is untracked and not ignored, and was deleted before
  committing. Candidate: add it to `.gitignore`.
- Full suite, `devtools::test(".", reporter = "summary")`, 13:30-13:34 UTC,
  2026-09-12, all Suggests installed: **failed=0, errors=2, skipped=7,
  passed=3852, warnings=38.** The two errors are `test-github-helpers.R`
  "read_github_csv can read remote content with a token" and
  "read_github_csv_dir can fetch when a token is configured" -- the HTTP 404
  through the session proxy, already on the pre-existing list above. The six
  locale-dependent failures of the earlier run did not occur: that run was
  under the container's C locale and this one under `C.UTF-8`, which is the
  evidence for the locale candidate item above (they pass once the locale is
  UTF-8). Skips fell from 103 to 7 because the second install phase has
  finished. No new failure.

### Not done, and why

- Did not normalise `pkg$dataset` / `pkg$tables` on read (finding 1).
- Did not change the five other yaml reads (finding 5, candidate item).
- Did not make an `!expr` tag a validation *failure*. With `eval.expr =
  FALSE` it is text, which is what the argument means; whether SSSOM metadata
  should refuse a tag outright is a spec question for #90.
- Did not open, edit, comment on or resolve anything on GitHub.
