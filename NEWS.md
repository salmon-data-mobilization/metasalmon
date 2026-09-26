metasalmon (development version)
--------------------------------

### Breaking changes

* **A package's ownership sentinel is now `.sdp-package`, holding the line
  `sdp-owned`, and `.metasalmon-package` is no longer written or recognised**
  (hub item B-113; ruled by Brett 2026-08-24, `knowledge/questions.md` Q14).
  `write_salmon_datapackage()`, and
  `create_sdp()` through it, now mark a package directory with one sentinel
  shared with metasalmonpy rather than a file named after this implementation,
  because what owns the directory is the SDP tooling and not one language's copy
  of it. The name and content line are recorded in
  `knowledge/parity-deviations.md` row 51. For a directory you already have:

  - **A package that still has its SDP metadata needs nothing.** The
    `overwrite = TRUE` check recognises it by its `metadata/` CSVs, as it
    always has, and the next write adds `.sdp-package`.
  - **A directory whose only sign of being a package is `.metasalmon-package`
    is no longer replaced.** `overwrite = TRUE` now stops with *"Refusing to
    overwrite non-metasalmon directory"*. If it is a package you mean to
    rewrite, rename that file to `.sdp-package`; otherwise write to a new
    directory.
  - **An existing `.metasalmon-package` is left where it is.** A rewrite no
    longer manages it, so it survives unless `prune = TRUE` empties the
    directory. Nothing reads it any more, and you can delete it.

  metasalmonpy writes `.metasalmonpy-package` until its half of the change
  lands (hub item B-127). This package still recognises a package metasalmonpy
  wrote by its SDP metadata, so nothing is refused in the meantime, but a
  package written by both carries both files until then.

### Added

* **`write_sdp_semantic_closure()` produces the reviewed semantic closure, which
  metasalmon has validated in three places and written in none** (backlog #116,
  hub item B-116). `write_eml_from_sdp()` and `publish_sdp_to_knb()` both require
  `metadata/semantic_vocabulary.csv` and `reviewed_semantic_selections.csv`, and
  the symptom of the hole was that a user who did everything the vignette said
  got *"metadata/semantic_vocabulary.csv does not exist"* with nowhere to go.
  One exported call now reads the package and writes both files:

  - **Both canonical sets are derived, not transcribed.** The two legitimately
    differ -- a table's `observation_unit_iri` is a review target and not a
    measurement vocabulary term, and a code-resolved `sosa:usedProcedure` is a
    measurement term and not a review target -- so neither can be reasoned from
    the other, and both come back on the result as `measurement_iris` and
    `review_targets`. In the shipped Fraser coho example the ledger has five
    rows and the vocabulary four.
  - **Evidence is resolved through the existing search path.** Each IRI's
    `label`, `definition`, `source`, `ontology`, `resource_kind` and `type_iris`
    come from `find_terms()`, re-running the query recorded in
    `semantic_suggestions.csv` or, failing that, the IRI's own local name split
    back into words (`SpawnerAbundance` -> `"spawner abundance"`). No LLM is
    involved and there is no argument that would enable one.
  - **`evidence` accepts the rows no search can fill.** QUDT is not a searchable
    source, so a unit row is hand-authored; `native_type` and `source_url`
    describe the ontology artifact rather than the term and are derived from the
    resolved source; `confidence` and `review_rationale` are human judgements,
    read from a recorded `decision_reason` where `apply_sdp_semantics()` left
    one and otherwise written as a `REVIEW REQUIRED:` marker with a warning
    naming each target. Supplied values win field by field, so one row may
    correct one field.
  - **Every digest is computed.** Each row's `reviewed_snapshot_sha256`, and both
    file digests in `metadata/eml-mapping.yml` -- edited in place, line by line,
    so the sidecar's own instructions are not deleted by a YAML round trip. A
    user never hand-writes a SHA-256 into a CSV again.
  - **An unresolvable IRI is a gap, not an abort** (ruled 2026-09-12). It is
    returned as `gaps`, in the shape `detect_semantic_term_gaps()` returns plus
    an `unresolved_iri` column, so it feeds
    `render_ontology_term_request()` and `submit_term_request_issues()`
    directly; both files are still written without that row. The omission is not
    silent, because `write_eml_from_sdp()` then names the same IRI as missing
    from the vocabulary.
  - **And a gap is a claim, so only one of the three ways a row can go unwritten
    makes one.** A gap row asserts that a term is absent from the searched
    vocabularies, which is what the term-request pipeline acts on, so the two
    outcomes that do not establish absence are reported separately. A **lookup
    that did not answer** -- a search that threw, or a `find_terms()` result whose
    `"diagnostics"` attribute names a failed source -- **aborts before anything is
    written**, naming each IRI and the sources that were silent; `find_terms()`
    already warns that such a result is unknown rather than an ontology gap, and
    this obeys it. A **term that was found with a required field blank**, such as
    a class with no definition, comes back in a new `incomplete` element naming
    the field and the slot, with a warning that says it is not a gap; the
    remaining rows are still written.
  - **The two files and the sidecar digest install as one set, and no write
    follows a link.** All three are rendered to bytes and installed through the
    package's existing `.ms_sdp_extension_atomic_write_set()`, which stages each
    as a sibling, renames them in, and rolls all three back if any install fails
    -- so a failure can no longer leave a replaced CSV beside its previous
    `sha256`. The package root, every intermediate directory component and each
    final entry are refused when they are a symlink, which matters because an SDP
    received from a collaborator can point any of the three names at a file
    outside the package and have this function truncate it. Hard links are not
    detected, because base R exposes no link count, and are closed by the same
    install path rather than by a check: the bytes go to a fresh inode and a
    rename replaces the directory entry, so nothing here ever opens the
    destination.

  `scripts/build-fraser-coho-knb-rehearsal.R` reached into `metasalmon:::` at
  three sites for exactly the things this function now returns, and reaches into
  none. The two stages are swapped so the EML sidecar is written first and the
  producer pins its digests, which removes the script's last hand-computed file
  digest as well.

### Fixed

* **Any final `reject_shortlist` now escalates to `request_new_term`, and four
  ways an LLM assessment was being mangled are fixed** (hub item B-361; ruled by
  Brett on 2026-09-25 as decisions 10 and 11 of the S16 execplan, and a
  prerequisite of the review-packet contract, B-326). All five sit in the
  validation, escalation and retry code that every review path shares -- the
  generic, batched and bundle paths today, and the assessment ingester next --
  so the ingester does not inherit them. Each is pinned by a test that failed
  before the change (`tests/testthat/test-llm-assessment-validation.R`).

  1. **A `reject_shortlist` that follows a `retry_search` is escalated.**
     `AGENTS.md` has said since 2026-08-10 that an unresolved `reject_shortlist`
     escalates to `request_new_term` so the ontology gap is surfaced; the code
     escalated only when the decision *before* the retry was also a rejection,
     so a model that asked for a wider search and then rejected the widened
     shortlist left a dead-end `reject_shortlist` in the record and no gap was
     filed. The rule is now the one `AGENTS.md` states: any final
     `reject_shortlist` escalates, whatever came before it, including in the
     bundle path for a role with no initial answer. metasalmonpy already
     escalated any final rejection, so this is R moving. When the earlier
     answer was itself a rejection the two rationales are still kept, labelled,
     as before; otherwise the final rationale stands alone.
  2. **A non-accept decision has its index cleared before the range check.**
     A `reject_shortlist` (or `review`, `retry_search`, `request_new_term`)
     carrying a stray out-of-range index was downgraded to `review` by the
     range check, which threw the rejection away and with it the escalation.
     The index is meaningful only for `accept`, so for every other decision it
     is now cleared first and the range check never sees it.
  3. **An index that is not a whole number is refused, not truncated.** The
     index was read with `as.integer()`, so `1.9` selected candidate 1 and
     `2.7` selected candidate 2. A fractional index now aborts the assessment
     with a message naming the value, which the calling path records as an
     error row (or, in a batch, as that target's fallback reason). Whole
     numbers written as `"2"` or `2.0` are still accepted.
  4. **A downgrade with no rationale no longer starts with the text `NA`.**
     When the model gave no rationale and the package appended a downgrade
     note, the stored rationale read `NA Model returned accept without
     selecting a candidate; ...`, because `nzchar(NA)` is `TRUE` and the
     filter meant to drop the missing rationale kept it. Notes now join with
     one space and a missing rationale contributes nothing.
  5. **The retry-query duplicate check folds case over ASCII letters only, the
     same in every locale.** The check compared `tolower()` of the retry
     query with `tolower()` of the original, and `tolower()` folds non-ASCII
     letters according to the locale, so a pair of queries differing only in
     an accented letter's case was a duplicate (and the retry withheld) under
     `en_US.UTF-8` and a usable query under `C`. The fold is now `A-Z` to
     `a-z` through `chartr()`, so the verdict is the same on every machine;
     metasalmonpy's B-362 mirrors the rule exactly as this package now states
     it. Raised in a Codex review of hub pull request #187.

* **`validate_salmon_datapackage()` now checks the three things backlog #49
  (hub item B-49) measured it claiming and not doing.** Each was a contract
  the package already wrote and nothing read back:

  1. **Required-column nullability.** The dictionary's `required` flag was
     inferred, written to `column_dictionary.csv`, parsed back to logical and
     exported as Frictionless `constraints.required`, and compared to the data
     by nothing -- a package could declare a column required and ship blanks in
     it. A `required = TRUE` column with an NA or whitespace value is now a
     structural `columns` issue in every mode, read the way the primary-key
     check reads a missing key component. Only columns present in the data are
     checked; an absent one was already reported.
  2. **Schema-required metadata fields.** The Frictionless schema declares
     `constraints.required` on seven `dataset.csv` fields, five `tables.csv`
     fields and seven dictionary fields, and `review_metadata()` has reported a
     blank one as *blocking strict validation* since 0.5.0 -- while strict
     validation let it through, because the placeholder scan only sees a field
     that says it is missing, not one that is. A blank non-key required field
     now takes the placeholder channel: a warning in the default mode, an error
     under `require_iris = TRUE`, so a freshly created package stays valid until
     the strict answer is asked for. A blank **key** field (`dataset_id`,
     `table_id`, `file_name`, `column_name`) is structural in every mode: a
     `tables.csv` row with no `table_id` used to be skipped by the per-table
     loop rather than named. Both read the same schema parse
     `review_metadata()` reads, so the two cannot disagree about which fields
     block. A column the file does not have counts as blank in every row, in
     the validator and in `review_metadata()` alike -- the canonical reader
     normalises only the dictionary and codes, so an absent required column
     was reported in those two files and passed in `dataset.csv` and
     `tables.csv` (raised in review of #111; the same rule now covers a
     `tables.csv` with no `observation_unit_iri` column under
     `require_iris = TRUE`). A blank `dataset_id` in `dataset.csv` used to
     stop the validator with R's `missing value where TRUE/FALSE needed` from
     the id-alignment check before the key collector ran; it is now reported
     as the structural issue it is.
  3. **Corrupt SSSOM and decomposition artifacts.** `validate_sdp_sssom()` and
     `validate_sdp_measurement_decompositions()` existed, and only the KNB
     publication and archive paths called them: the end-to-end validator
     reported success over a `mapping-sets.json` whose SHA-256 no longer matched
     its bytes, and over a decomposition CSV whose manifest had been deleted.
     Both validators now run when their managed files are present, detected
     exactly as those two paths detect them -- by file name, never by scanning
     `metadata/semantic/`, so an unapproved draft there stays local and unread.
     Because routine validation now reaches the SSSOM reader, its
     `yaml::yaml.load()` on the embedded metadata block passes
     `eval.expr = FALSE` explicitly: yaml's default follows
     `getOption("yaml.eval.expr")`, so a session that had turned the option on
     would have executed a `!expr` tag in a collaborator's file before any
     hash or field check ran (raised in the security review of #111).
     `yaml (>= 2.2.0)`, the version that introduced the argument, is now the
     declared minimum.

  One test asserts a failure for each class (`tests/testthat/test-package-helpers.R`,
  `test-sssom.R`, `test-measurement-decompositions.R`), each shown failing
  against the previous validator before the check landed. The roxygen
  description now lists what the function checks, which is the claim the item
  title said was wrong. The declared-primary-key clause of #49 closed in 0.2.6
  under #77 and is untouched. **Mirror:** metasalmonpy's
  `validate_salmon_datapackage()` (`package_io.py`) has none of the three
  checks; the port is owed under the S10 parity stream (queue item B-124; see
  the parity register), not registered as a deviation.

* **`infer_column_role()` now types an enumerable string column
  `categorical`, so `create_sdp()` stops writing `codes.csv` rows for columns
  its own dictionary typed `attribute`** (backlog **#95**, queue **B-95**).
  The code-row seeder writes one `codes.csv` row per distinct value of every
  character or factor column with at most 30 distinct values, and the
  specification's `codes_required_for_categorical_columns` rule binds a code
  list to `column_role = "categorical"` -- so `scripts/validate_package.py`
  in `smn-data-pkg` rejected every one of those rows as targeting "a
  non-categorical or unknown column": 22 rows across six columns on the
  173-row gold standard (`AREA`, `SPECIES`, `RUN_TYPE`, `ESTIMATE_METHOD`,
  `ESTIMATE_CLASSIFICATION`, `ESTIMATE_STAGE`), and every code-bearing column
  of the 30-row sample, all written by the same call that printed
  "Dictionary validation passed" between them.

  Ruled Q29 (Brett, 2026-09-05): the correction belongs in role inference,
  and the seeder is downstream of that decision. Both now read one internal
  predicate, `.ms_code_list_values()`, which carries the seeder's original
  criterion unchanged, so the two cannot drift; the seeder's output is
  byte-for-byte what it was. Identifier, temporal and measurement verdicts
  still run first, so a key, a date, or a unit-bearing or percent-like text
  column keeps its role even when its values repeat. A method-named column
  whose values enumerate (`ESTIMATE_METHOD`, `ENUMERATION_METHODS`) is now
  `categorical` rather than `attribute`, which is also where its procedures
  resolve (`codes.csv$term_iri`).

  Pinned on the R side by `tests/testthat/test-codes-target-categorical.R`,
  which applies the validator's rule to `create_sdp()`'s output on both
  bundled examples. The metasalmonpy fixture is owed as a port, and the
  item's retirement condition is met only on the R side until it lands.

* **A measurement column whose values all look like years is no longer typed
  `temporal`** (backlog **#53**, queue **B-53**). `infer_column_role()` typed
  a column `temporal` whenever all its values were four-digit numbers from 1800
  to 2500, reading the values alone and ahead of any measurement word in its
  name, so a small stock's `NATURAL_ADULT_SPAWNERS` of 1850, 2003 and 1999, or
  a sample of 1,900 fish, became a `temporal` column. `suggest_semantics()`
  skips temporal columns, so such a column left the whole semantic pipeline --
  no variable, property, entity or unit target -- without a warning, while the
  same column holding numbers outside that range was typed `measurement`.

  The year shape now decides unless the name's words include a measurement
  word -- one of the words the measurement check already reads (`count`,
  `total`, `spawners`, `escapement`, `weight`, `depth` and the rest), or a
  sample or partition size -- and no date or time word. Then the year shape is
  not consulted, and the column is typed by the checks that follow exactly as
  it would be with values outside the year range. Words are split at spaces,
  punctuation and case changes, so `Water depth(mm)` and `adult/count` are
  measurement names, while the year word in `Escapement (yr)` and `count/year`,
  or a plural one as in `escapement_years`, keeps them `temporal`, as
  `count_year` always was. Whole words rather than
  the broader measurement hint, because that hint's two pattern tests match
  names that are not measurements: `temp` inside `temporal_start`, and any
  parenthetical containing a `g`, such as `Cohort (Aug)`. Measured over the
  1,271 columns in the CSVs of metasalmon, metasalmonpy, smn-data-pkg and
  salmon-domain-ontology, the broader hint would have retyped 18
  `temporal_start` / `temporal_end` columns as measurements, all rightly
  temporal; the whole-word rule changes the role of none of the 1,271.

  **Not covered, on purpose:** a name whose only measurement evidence is a
  substring (`ADULTCOUNT`) or a unit in parentheses (`Mass (kg)`) is still typed
  `temporal` when its values look like years. Separate the words in the name
  (`ADULT_COUNT`), or correct `column_role` in the dictionary
  `infer_dictionary()` returns. And the words decide only whether the year
  shape may decide; the role checks after it read the name as before. So a
  name whose measurement word only the split reveals, and which those checks
  do not otherwise recognise (`adult/spawners`, `fish/weight`), is no longer
  `temporal` but is not `measurement` either: it gets the role it gets with any
  other values, `attribute` for a numeric column. Letting those checks read
  the words would need every check that outranks them to read them too, and
  that breaks units and rates: `Discharge (m3/day)` and `Rate (per day)` would
  become `temporal`, and `Fish (no./site)` an `identifier`.

  Pinned by `tests/testthat/test-year-shaped-measurement-role.R`, which checks
  each fixture against `.ms_values_look_yearish()` before asserting its role,
  and follows one such column through `infer_dictionary()` and
  `suggest_semantics()` to its semantic targets. **Mirror:** metasalmonpy's
  `infer_column_role()` (`dictionary.py`) has the same defect; the port is owed
  (see the parity register), and the item's retirement condition is met only on
  the R side until it lands.

* **`datapackage.json` and `metadata/dataset.csv` no longer spell the same
  instant two different ways** (backlog **#115**, queue **B-115**). A
  `dataset_meta$temporal_start`/`temporal_end` supplied as a typed `POSIXct`
  reached both writers -- `.ms_align_cols()` renders a `Date` to text and
  deliberately leaves an instant typed (backlog #93 item 1, unchanged here) --
  and each rendered it its own way: the descriptor through `as.character()`
  (`0999-06-05 13:45:30`, and a midnight instant lost its time entirely) and
  the CSV through `readr::write_csv()` (`0999-06-05T13:45:30Z`). Two spellings
  of one value, in two files a consumer is entitled to read either of.

  Brett ruled the spelling on 2026-09-14, once for both implementations so that
  no implementer picks one: a typed instant reaching the descriptor takes
  readr's ISO instant form, the `T` separator and the `Z` zone marker. The
  descriptor's temporal writer therefore moves onto the `readr::write_csv()`
  baseline, and it does so by **asking readr for the bytes** rather than
  reproducing them -- a hand-rolled format string was measured equal to readr
  on every case tried and would still be a second rendering of one value, which
  is the defect `AGENTS.md`'s "one value, one rendering" contract names rather
  than a way of fixing it. `.ms_iso_date_columns()` is untouched, and its
  deliberate disagreement with `.ms_canonical_character()` about a `POSIXct`
  survives, asserted on purpose by `test-canonical-date-render.R`.

  **This is not a wire-format break for any package in the wild.** The bytes
  change only for a package whose caller supplied a typed instant, and neither
  implementation produces one itself -- both write character metadata -- so no
  package either of them has written is affected.

  Two things worth carrying forward. `readr::write_csv()`'s instant year is
  **not** padded on every platform: it writes `999-06-05T13:45:30Z` on Linux
  (R 4.3.3, readr 2.2.0) where macOS wrote `0999-06-05T13:45:30Z`, which is the
  `%Y` platform split already documented in `R/platform-time.R` reaching readr's
  own instant path, and it retires the standing comment that "readr's instant
  path is correct already" as a macOS-only measurement. The descriptor now emits
  whichever year readr emits, so the two files agree on both platforms; padding
  only the descriptor would have re-opened this defect on the platform CI runs
  on. **Mirror:** metasalmonpy adopted the same ruling in queue **B-145**
  ([metasalmonpy pull request 34](https://github.com/salmon-data-mobilization/metasalmonpy/pull/34), 2026-09-25); parity-deviations row 56
  records that both sides moved, and the one residual left, the year below
  1000, which is hub item B-161.

* **A failed `create_sdp()` no longer destroys the sidecar it was rewriting**
  (backlog #111, hub item B-111). `create_sdp()` writes three files of its own
  after the package writer has finished -- `README-review.txt`,
  `semantic_suggestions.csv` and, with `include_edh_xml = TRUE`,
  `metadata/metadata-edh-hnap.xml`. Each unlinked the existing file first and
  then rendered its replacement, so any abort in between left nothing at all
  where the file had been. Measured, not inferred: an abort injected at each of
  the three render steps removed the previous file all three times.

  All three now render to bytes and install by staged-sibling rename through
  `.ms_sdp_extension_atomic_write()`, the same writer
  `write_salmon_datapackage()` uses, so a failure during the render leaves the
  previous file byte-for-byte as it was. The bytes a successful call writes are
  unchanged: each renderer goes through the writer the file already used
  (`writeLines()`, `readr::write_csv(na = "")`, `edh_build_hnap_xml()`) rather
  than through a re-implementation of it.

  This matters for a file you have changed since. Re-running `create_sdp()`
  regenerates all three, so the loss only bit an annotated `README-review.txt`,
  a `semantic_suggestions.csv` carrying review decisions, or the EDH XML of a
  package whose metadata has moved on. Pinned by
  `tests/testthat/test-create-sdp-sidecar-atomicity.R`, three abort injections
  asserting byte-identity. `.ms_replace_create_output()` is deleted; its
  hard-link rationale is subsumed, because a staged-sibling rename never writes
  through an existing inode.

  **Scope, since the word "atomic" promises more than this delivers:** the
  staging file sits in the target's own directory, so the rename is atomic, but
  it is not `fsync`ed before the rename. That is sufficient against an aborted
  call and insufficient against a machine crash or power loss. Unchanged by
  this release, and true of every caller of that writer, not just
  `create_sdp()`.

  The same three writes have the same shape in metasalmonpy, where the EDH
  window is wider still; that is recorded as parity row 53 and owed as a port.

* **`migrate_sdp_methods()` now returns the same three-column `report$tables`
  frame from every exit** (backlog #112, hub item B-112). The
  nothing-to-migrate early return built two columns, `table_id` and
  `method_iri`, while the populated build and the no-placement empty frame
  both build three by adding `columns`. A caller reading
  `report$tables$columns` therefore got `NULL` -- with tibble's "Unknown or
  uninitialised column" warning -- in exactly the case where the package was
  already clean, which is the branch least likely to be exercised and the
  reason it survived. The empty `columns` is `character()`, matching the type
  the populated build renders with `paste(collapse = ", ")`, so binding the
  reports of two runs together no longer coerces the column. The frame is
  empty either way, so nothing that read `nrow()` changes; only the column set
  does. The three-column shape is the one the migration vignette already
  documents.

  Ruled by Brett on 2026-09-14 for both implementations, so the shape is not
  an implementer's choice: the alternative -- a logged ruling that the shapes
  deliberately differ -- is closed. Found 2026-08-22 by stream S10 chunk A's
  migration differential, where Python carried the internally consistent
  three-column frame first and was changed to mirror R; under the amended
  mirror contract which side is right is a ruling rather than an implementer's
  call, so this is the side that moves. The mirror half is hub item B-144,
  where metasalmonpy returns to the shape it had originally, and #112's
  retirement condition is met only on the R side until it lands. All three
  exits are pinned by `tests/testthat/test-sdp-methods.R`, not only the branch
  that was wrong, because pinning one leaves the other two free to drift away
  from it and the failure would look identical.

* **`review_metadata()` and the four `set_sdp_*()` setters no longer contact the
  network under the default options** (hub item B-175). `review_metadata()` has
  documented since 0.5.0 that it *never contacts a network or an LLM*, and under
  the default options that was false on every fresh session: all five read the
  SDP schema through the loader whose default source fetches eight documents
  from the pinned `sdp-0.3.0` release on `raw.githubusercontent.com` before it
  falls back to the copy bundled with the package. That was eight requests from
  each of them called cold, and a stall of about two seconds per call when the
  host did not answer. Under the default options they now read the bundled
  copy, in a cache slot of its own, so the schema a session has already
  resolved is not evicted and the next writer or validator call does not fetch
  it again.

  **A schema the options select is still the one they read.** When
  `metasalmon.sdp_schema_source` or `metasalmon.sdp_schema_base_url` selects a
  different schema, they read it exactly as before. That is the schema the
  writers read, so a package is reviewed and edited against the field contract
  it was written to. It comes from the session's cache once a writer has loaded
  it, and otherwise is fetched as a writer would fetch it. The first version of
  this change read the bundled copy under every setting, which dropped a
  selected schema's requirements from the scan and made the setters refuse its
  fields (raised in the Codex review of #145).

  The setters read the same parse the scan reads, so a call `review_metadata()`
  prints is one the setter accepts. So does the validator's check for blank
  schema-required fields, which keeps "the last reported row is gone" and
  "strict validation passes" one statement; the rest of
  `validate_salmon_datapackage()` still reads the schema the way it did. The
  bundled and published copies of the six metadata schemas are identical
  today, so under the default options no result changes.

  Nothing in the suite could see this, because
  `tests/testthat/helper-validation.R` pins the bundled source for the whole
  run. `tests/testthat/test-review-metadata-offline.R` un-pins it and proves the
  absence with sentinels that **count rather than throw**: the loader catches
  any error its fetch raises and falls back, so a sentinel that errors passes
  whether or not the network was reached. One counts calls to the package's
  own fetch; the other is a local socket named as every HTTP(S) proxy, which
  every R HTTP client measured reaches, so it still fails if the request moves
  to another client. The default-options change is the R half of the change
  metasalmonpy made in pull request 28.

* **No YAML read evaluates an `!expr` tag any more, and adding one that could
  now fails a test** (hub item B-142). yaml's `!expr` tag asks the parser to run
  the R code that follows it, and whether it does is set by `eval.expr`, whose
  default is `getOption("yaml.eval.expr", <fallback>)`. The SSSOM reader has
  passed `eval.expr = FALSE` since #111; six other reads left it out, and all
  six now pass it: `write_eml_from_sdp()`'s read of the EML sidecar, the two
  reads of that sidecar on `publish_sdp_to_knb()`'s path (the plan builder and
  the artifact inventory), both reads of the SDP rules document (fetched over
  HTTP, and vendored), and the read of the sidecar's declared paths in
  `write_sdp_semantic_closure()`. Two facts make this more than a
  session-option corner:

  - **The fallback was `TRUE` until yaml 2.3.0**, which yaml's own NEWS records
    as "Made `eval.expr` default to `FALSE`" (the argument itself arrived in
    2.1.19), and DESCRIPTION's floor is `yaml (>= 2.2.0)`. So on a yaml 2.2.x
    install those reads ran an `!expr` tag with no option set at all. Measured
    with yaml 2.2.2 built from CRAN's archive and no option set: the previous
    closure-path read and the previous remote rules read both ran a tag's
    `file.create()`, and neither does now. The explicit argument works across
    the whole declared range, so the floor stays where it is.
  - **Most of that input is somebody else's.** The sidecar is package content,
    which the closure producer already treats as untrusted, and the rules
    document arrives over the network whenever the schema source is `"auto"`
    or `"remote"`.

  A tag now reaches the caller as its text: `!expr f()` in a sidecar field
  reads as the string `"f()"`, as it already did under yaml 2.3.0 or later
  with the option unset. The one difference such a session sees is that
  yaml's own warning ("Evaluating R expressions (!expr) requires explicit
  `eval.expr=TRUE` option") no longer appears, because the argument is now
  given. `tests/testthat/test-yaml-expr-guard.R` walks the namespace and the
  R/ sources, top-level code included, and fails on any call to `yaml.load()`,
  `read_yaml()` or `yaml.load_file()` that does not pass the literal
  `eval.expr = FALSE`, and gives each of the six reads a real tag with the
  option turned on. Each of those six tests was shown failing against its
  unfixed read. The sixth read was not on the item's own list of 2026-09-12:
  it arrived four days later with the closure producer, which is exactly the
  case the two scans are there to catch.
  **Mirror:** nothing to port. metasalmonpy already never evaluates a tag here:
  its sidecar reads use PyYAML's `SafeLoader`, its rules reads a
  regular-expression scan, and its SSSOM reader a subset parser, which hub item
  B-189 is to pin with a test.

* **A hand-picked accept now reaches the decision record** (hub item B-176).
  `accept_suggestion(review, column, role, iri = "...")` is the supported
  escape hatch for a term retrieval never surfaced, and a shortlist match was the
  only way `apply_sdp_semantics()` ever wrote an `accepted` row to
  `semantic_suggestions.csv`. So a hand-picked IRI reached
  `column_dictionary.csv` and nowhere else: every candidate in its slot was
  written `not_selected`, no row was `accepted`, no row carried the IRI, and the
  next `review_semantics()` replayed nothing, with `include_filled` either way.
  The slot left the queue only because its field was now filled, not because
  the answer had been remembered. Two things that read the record lost it too:
  `apply_semantic_suggestions(strategy = "reviewed")`, fed the package's own
  `semantic_suggestions.csv`, re-applied nothing to that slot, and
  `create_sdp(prune = TRUE)` counted no decision to warn about before deleting
  the file.

  The accepted IRI now gets **its own row**, carrying the slot's addressing
  columns (so a code-level slot keeps its `code_value`) and `source = "user"`,
  with every column that describes a candidate -- `label`, `ontology`,
  `definition`, `score`, the retrieval trace -- left empty. Relabelling an
  existing candidate instead would make the file say the reviewer chose a term
  they did not, with that row's label, definition and score describing another
  term. The row goes at the **head** of its slot, not the end of the file:
  `review_semantics()` derives `rank` from file position and drops everything
  past `max_candidates` (5 by default), so behind a full shortlist an appended
  record ranks 6 or lower and is filtered straight back out. At the head it
  ranks 1, which is also what makes a replayed
  `accept_suggestion(..., rank = 1)` re-accept the term actually chosen. A
  second hand-picked accept on the same slot demotes the first to
  `not_selected`. Re-applying the same review, or the review rebuilt from the
  package, leaves every written byte of a slot decided this way as it was.

  **`detect_semantic_term_gaps()` does not count that row as gap evidence.** A
  gap row claims retrieval found no `smn` term, and the recorded row is a
  reviewer's decision, not something a search returned. Counted, its blank
  `search_query` made it a target of its own whose only candidate was not
  `smn`, so a post-review `semantic_suggestions.csv` passed as `suggestions`
  reported an ontology gap for the slot the reviewer had just filled. The
  slot's own retrieval candidates are weighed exactly as before.

  A port, not a deviation: metasalmonpy had the same defect in the same shape
  and fixed it first ([metasalmonpy pull request 28](https://github.com/salmon-data-mobilization/metasalmonpy/pull/28), hub item B-126), and both
  now record the same row, so no parity-register row is owed. The gap-evidence
  exclusion is R's alone for now: metasalmonpy's `detect_semantic_term_gaps()`
  still counts the row it has recorded since [pull request 28](https://github.com/salmon-data-mobilization/metasalmonpy/pull/28), and the same fix is owed
  there.

* **`review_metadata()` now lists a draft `REVIEW:` IRI that strict validation
  refuses** (hub item B-174). Its contract is that when the last row it prints
  is gone, `validate_salmon_datapackage(require_iris = TRUE)` passes, and in
  0.5.0 that failed for the most ordinary unfinished package: one whose
  semantic review was left partly undecided. A `REVIEW:`-prefixed IRI is not
  blank and is not one of the three `MISSING ...:` / `REVIEW REQUIRED:`
  placeholder spellings, so the scan's test for an unfilled value passed over
  it and `review_metadata()` printed "No outstanding metadata." for a package
  strict validation then refused. Every IRI field strict validation sweeps was
  affected -- including the four measurement IRIs and `observation_unit_iri`,
  which the scan did visit, with a test that could not see the marker.

  A marker is now listed wherever strict validation refuses one, with the
  `set_sdp_*()` call that replaces it: in any schema-declared `*_iri` field of
  `tables.csv`, and in the six semantic IRI fields of `column_dictionary.csv`.
  The six are read from the list `validate_dictionary()` sweeps, not from the
  schema. So when a schema selected through the options declares a seventh
  dictionary `*_iri` field, a marker there is not listed, because strict
  validation accepts it (raised in the Codex review of #144). Also still not
  listed:

  - a marker in `codes.csv` or `dataset.csv`, because strict validation does
    not refuse one there yet (hub item B-177);
  - a marker in a `*_iri` column the schema does not declare, which has no
    setter to print (hub item B-185).

  The fix is a second test for the marker rather than a wider placeholder
  test, because other callers depend on the placeholder test's narrowness. It
  is pinned by marking each declared `*_iri` field of all four metadata files
  in turn, on a package that otherwise passes, and asserting that the scan
  lists it exactly when strict validation refuses it. A second test does the
  same for a configured schema's extra dictionary field.

  metasalmonpy fixed the same defect in [pull request 28](https://github.com/salmon-data-mobilization/metasalmonpy/pull/28), and its scan also
  lists a marker in `codes.csv`, the one file where the two differ. Brett ruled
  on 2026-09-23 that strict validation refuses a marker there, so R is the side
  that moves, when B-177 lands. Until then the difference is tracked as a port
  owed in `knowledge/parity-deviations.md`, not as a register row.

* **`apply_salmon_dictionary(strict = TRUE)` now stops on the coercion failure
  it used to let through, and the codes step names the values it blanks**
  (backlog #55, hub item B-55). Both were silent losses in one call.

  - **A value R only warns about is now a coercion failure.**
    `as.integer("abc")` and `as.numeric("1,5")` do not error. They warn and
    return `NA`. The coercion block handled `error` alone, so under the default
    `strict = TRUE` a column typed `integer` or `number` holding such a value
    came back with `NA` in its place and R's generic *"NAs introduced by
    coercion"* beside it, and never reached the abort that `strict` promises.
    A warning is now a failure too. `strict = TRUE` aborts, naming the column
    and the type, and for a failure R only warned about, each value that did not
    convert. `strict = FALSE` warns and keeps the column as character, which is
    what the argument has always documented; it too returned the `NA`s. A
    missing or blank value is not a failure.
  - **A value that is not in its column's code list is reported.** The codes
    step makes the column a factor whose levels are the code list, so an
    unlisted value has no level and becomes `NA`, and it used to do that without
    a word. It now warns, naming each distinct unlisted value, under either
    value of `strict`: `strict` governs type coercion, and the defect was the
    silence, not the conversion, which is unchanged. Blank strings count as
    missing and are not named.

  Two tests pinned the old behaviour. One asserted that `strict = TRUE` returned
  `NA` for `"not-a-number"`, beside a comment saying the handler "only triggers on
  actual errors, not warnings". Both now assert the documented contract.

  **Not covered, because it is a different mechanism:** a coercion that loses a
  value without signalling anything still passes `strict = TRUE`. `as.logical()`
  returns `NA` for `"yes"` with no warning, `as.Date()` does the same for a
  value after a parseable first one, and `as.integer("3.7")` truncates to `3`.
  None of them raises a condition for a handler to catch.

  **Mirror:** the coercion half brings R to where metasalmonpy already was,
  because its `_coerce_series()` raises on these values under `strict=True`. Its
  codes step still blanks an unlisted value silently, and that half is owed
  there as a port (see `knowledge/parity-deviations.md`).

* **The call `review_semantics()` prints for a measurement column's own slot
  now runs when the column has a code list** (hub item B-151). A measurement
  column's `entity_iri` and `constraint_iri` targets share their roles with the
  `codes.csv` targets of its codes, and an omitted `code_value` matches every
  code. So the column's own slot printed
  `accept_suggestion(review, "spawner_count", "entity", rank = 1, table = "spawners")`,
  which matched that slot and every code's slot and aborted with *"That column
  and role match more than one review slot"*; its `reject_suggestion()` line did
  the same. Reproduced through `create_sdp(semantic_code_scope = "all")` with a
  two-code sentinel list on a count column: 6 of the 33 printed calls aborted.
  The abort's own list of arguments to add was no way out either, because the
  option it offered for the column's slot was the `table =` the call already
  carried.

  A blank `code_value` now selects the slots that belong to no code:
  `accept_suggestion(..., code_value = "")`, or `code_value = NA`, selects the
  column's own slot. It never selects a code's slot, including one whose
  `codes.csv` row leaves `code_value` empty because it supplies
  `vocabulary_iri`, which the codes schema allows. `review_semantics()` prints
  `code_value = ""` whenever `table` alone would not select the column's own
  slot, and the refusal offers it too. An omitted `code_value` still matches
  every code, as before, so no call an earlier version printed resolves to a
  different slot now. Reading the omission as "no code value" instead, the
  other way to fix this, would have changed what every code slot's call printed
  without a `code_value` resolves to.

  One case is not fixed here. A code slot whose `codes.csv` row has no code
  value has no call of its own that tells it apart from another slot of the
  same column, role and table, such as a measurement column's own slot. Its
  printed call still refuses as ambiguous, as it did before, and never decides
  the other slot. Set that row's `term_iri` in `codes.csv` directly.

  **Mirror:** metasalmonpy prints the same ambiguous call and pins it as a
  known limitation shared with R. Its matcher already read `code_value=""` as
  "no code value", where R aborted with *"No review slot matches"*, but it also
  matched a code slot whose row has no code value. The printed call, the
  refusal and that part of the matcher are owed there as a port, with the
  pin's removal.

* **`suggest_semantics()` searches each distinct query, role and sources
  tuple once, where it searched once per target row** (backlog #56, hub item
  B-56). Rows repeat a tuple whenever tables share a column or columns fall
  back to the same unit query: four tables carrying the same two columns are
  40 targets and 9 distinct tuples, and all 40 were searches. Now 9 are. A
  `search_fn` you supply is therefore called fewer times, and a counting or
  logging one will see it. What each row gets is unchanged: its candidates,
  their order and every attribute of the result are `identical()` to before on
  that fixture and on the bundled example package. The saving lasts for one
  call only, so it is not a cache and never outlives a change of settings. An
  answer whose diagnostics say a source did not answer is never reused, and the
  next row with that tuple searches again, as `find_terms()` already refuses
  to cache a degraded lookup. The LLM review's retry searches are unchanged.

  **Mirror:** metasalmonpy's `suggest_semantics()` still searches once per
  target row, and the change is owed there as a port.

* **`accept_suggestion()` now refuses an `iri` that is only the `REVIEW:`
  marker** (hub item B-219). It checked that `iri` was not empty before
  stripping the marker, so `accept_suggestion(review, column, role, iri =
  "REVIEW:")` passed the check. So did every other spelling the strip removes,
  in any case and with whitespace before or after the colon. The accept
  recorded an IRI that named no term. `apply_sdp_semantics()` then cleared the
  field, whatever it held, and gave a cleared `term_iri` a `term_type` anyway.
  It marked every retrieved candidate `not_selected` and wrote an `accepted`
  row with an empty `iri` to `semantic_suggestions.csv`, which the next
  `review_semantics()` drops, so the slot came back undecided. The check now
  reads the value after the strip, which is the value the decision records, and
  the refusal says that the marker was removed and nothing followed it. An
  `iri` with a term after the marker is accepted as before and recorded without
  the marker.

  **Mirror:** metasalmonpy's `accept_suggestion()` checks in the same order and
  records the same empty accept for every spelling its own strip removes. The
  fix is owed there as a port (see `knowledge/parity-deviations.md`).

* **Naming a shortlisted candidate's IRI in `accept_suggestion(iri = )` now
  writes that candidate's `term_type`** (hub item B-221). The accept was
  recorded on the slot's first row. `apply_sdp_semantics()` takes `term_type`
  from the row a decision sits on only when that row carries the accepted IRI,
  and writes `skos_concept` otherwise. So hand-picking the IRI of a candidate
  below rank 1 wrote `skos_concept`, whatever that candidate was. The review
  rebuilt from the package replays the same decision on the candidate's own
  row, and re-applying it wrote the candidate's type. So one decision changed
  `column_dictionary.csv` and `datapackage.json` between two applies. With an
  `owl_class` candidate at rank 2, the first apply wrote `skos_concept` and the
  re-apply `owl_class`. An `iri` that a candidate in the review's shortlist
  carries, compared without the `REVIEW:` marker, is now recorded on that
  candidate's row. It is the same decision as `rank = <its rank>`, and applying,
  rebuilding and re-applying it writes the same bytes. A candidate stored with
  the `REVIEW:` marker on its IRI now writes its own `term_type` too, by
  `iri =` and by `rank =` alike. The writer compared that stored IRI, marker
  and all, with the unmarked IRI the decision records, so it never recognised
  the candidate and wrote `skos_concept`. The record in
  `semantic_suggestions.csv` now reads a candidate's IRI the same way, trimmed
  as well as unmarked. A quoted IRI keeps a trailing newline through
  `read_csv()`, so the record missed such a candidate and gave the IRI a
  hand-picked row instead, which the rebuilt review replayed as `skos_concept`.
  An IRI that no candidate in the shortlist carries still writes
  `skos_concept`, as before. That includes hub item B-176's case, a term the
  reviewer typed whose type nothing records.

  **Mirror:** metasalmonpy's `accept_suggestion()` also records `iri=` on the
  slot's first row, and its writer falls back to `skos_concept` the same way,
  marked candidates included, so the fix is owed there as a port (see
  `knowledge/parity-deviations.md`).

* **The semantic review no longer records, by any route, an accept whose IRI
  is empty or still a `REVIEW:` marker** (hub item B-246). Hub item B-219
  closed one route, `accept_suggestion(iri = )`. Three more stayed open, and
  one message misdirected:

  - `review_semantics()` queued a shortlisted candidate whose `iri` was only
    the marker, because it tested only that `iri` was not blank.
    `accept_suggestion(rank = )` then recorded an accept with an empty IRI, in
    every spelling the strip removes. Such a candidate is no longer queued. In
    a slot that held one, the candidates after it now rank one place higher,
    as they already did after a candidate with a blank IRI. A review saved by
    an earlier version, or edited by hand, can still hold one, so `rank =`
    now refuses a candidate whose IRI names no term.
  - A recorded accept of such a candidate came back in the next review as an
    accept with an empty IRI. It is no longer replayed, so the slot is asked
    again. A recorded reject is still replayed from such a candidate, and now
    from one with a blank IRI too, because rejecting a slot names no candidate.
    A slot whose only candidate was blank used to lose its rejection and reason
    from `include_filled = TRUE`. The console prints no accept call for such a
    candidate, since the call would be refused.
  - The strip removes one marker, so `accept_suggestion(iri = "REVIEW:
    REVIEW:")` recorded the IRI `REVIEW:`. An `iri` that is still a marker once
    one is removed is now refused, a shortlisted candidate carrying one is not
    queued, and `rank =` refuses one that a review still holds.
  - `review_semantics()` listed a suggestion row with no IRI under *"Some
    suggestions target fields this review cannot decide"*, naming a field the
    review does decide, and said to edit it in the metadata CSVs directly. A
    package where an accept before B-219 recorded an empty IRI printed that on
    every review. A row with no IRI offers nothing to accept, and it is now
    dropped without a message. Fields the review cannot decide are still
    listed.

  Which spellings count as the marker is unchanged: these checks use the same
  strip and detector as before.

  **Mirror:** metasalmonpy's review console has the same defects (the replay
  was read there, not run), and the fix is owed there as a port (see
  `knowledge/parity-deviations.md`).

* **A `codes.csv` row with no code value gets no semantic suggestions, and the
  review no longer queues a slot it could not address** (hub item B-276; ruled
  by Brett 2026-09-25). The codes schema lets a row leave `code_value` empty
  when it supplies `vocabulary_iri`, and defines `term_iri` as the term that
  `code_value` represents, so such a row has no code value for a term to
  represent. Target discovery still gave it a code-level target, so
  `suggest_semantics()` and `create_sdp()` wrote suggestions for it and
  `review_semantics()` queued its slot. No argument told that slot apart from
  the column's own slot of the same role, so wherever the column had one, the
  calls printed for it refused as ambiguous: the case the B-151 entry above
  leaves open.

  - Discovery now forms no target for such a row, in any role, so
    `suggest_semantics()` and `create_sdp()` write no suggestion for it. A row
    of the same column that has a code value keeps its targets. Empty means
    `NA`, or text that is blank once trimmed; the text `NA` is a code value.
  - `review_semantics()` leaves such a row out of the queue when a
    `semantic_suggestions.csv` written before this change still carries its
    candidates, whichever key spelled its empty value. The rows stay in the
    file. The queue leaves them out with `include_filled = TRUE` too, and does
    not replay a decision recorded on them.
  - Every call the review prints for such a column now runs. Where the row was
    the column's only code, the call for the column's own slot no longer needs
    `code_value`. A call an earlier version printed for the row's own slot
    stops with *"No review slot matches that column and role"* where it used
    to run; where it used to refuse as ambiguous, it can now select the
    column's own slot of that role. Paste calls from a fresh
    `review_semantics()`.

  **Mirror:** metasalmonpy's target discovery gives such a row a target too,
  and the fix is owed there as a port (see `knowledge/parity-deviations.md`).

* **The publication vignette no longer leads a reader to add a ledger row that
  stops their package publishing** (hub item B-192).
  `vignettes/post-review-package-publication.Rmd` described the canonical
  review target set as the measurement set *plus* each table's
  `observation_unit_iri`, which holds in one direction only. The measurement set
  includes every `sosa:usedProcedure` reached through a code value, and the
  review targets never do: `.ms_eml_canonical_review_targets()` reads only the
  dictionary and `tables.csv`, and never calls the used-procedure resolver that
  the measurement set calls. So a reader who followed the sentence and added a
  `reviewed_semantic_selections.csv` row for such a procedure had it refused by
  `write_eml_from_sdp()` and `publish_sdp_to_knb()`, whose ledger gate accepts
  exactly the canonical target set, while
  `validate_salmon_datapackage(require_iris = TRUE)` went on passing. The
  vignette now describes the review target set on its own terms and says both
  directions: an `observation_unit_iri` is a review target and not a vocabulary
  term, and a code-resolved procedure is a vocabulary term and not a review
  target. No code changed. `write_sdp_semantic_closure()` writes the ledger from
  the canonical target set, so a ledger it wrote never carried the row; only a
  hand-edited one could.

  **Mirror:** metasalmonpy corrected the same passage first, in pull request
  31, because its `guides/semantic-review.qmd` was transcribed from this
  vignette. This is the R half following it.

* **`review_metadata()` reports a placeholder in an IRI field once, and the
  call it prints for that row runs** (hub item B-211). A `MISSING METADATA:`,
  `MISSING DESCRIPTION:` or `REVIEW REQUIRED:` placeholder in `tables.csv`'s
  `observation_unit_iri`, or in a measurement column's `term_iri`,
  `property_iri`, `entity_iri` or `unit_iri`, came back as two rows. The
  scan's field loop reported it with reason `placeholder`, as it does a
  placeholder in any field. The check for a blank one of those fields then
  reported it again with reason `iri`, because its test counts a placeholder
  as unfilled. The `set_sdp_table()` or `set_sdp_column()` call printed for the
  row named the field twice, so evaluating it failed with *formal argument
  "observation_unit_iri" matched by multiple actual arguments*. Measured on
  hub `main` `643209c` with one placeholder planted in each file: two rows for
  each field, both printed calls failed that way, and the console counted 16
  fields still blocking strict validation where there were 14. Each field now
  comes back once, as a placeholder, and its call runs. A blank IRI field is
  still reported once with reason `iri`, and so is one still carrying a
  `REVIEW:` marker.

  The scan now keeps one row per field of each metadata row, and the first
  check to report a field keeps it. So the same holds whichever two checks
  find one field. Under a schema selected through the options that calls
  `unit_iri` required, a blank one on a measurement row came back as
  `required` and as `iri`, and its call failed the same way. It now comes back
  once, as `required`. No shipped schema calls an IRI field required, and
  nothing in the package writes a placeholder into an IRI field, so only a
  hand-edited package reached either. `tests/testthat/test-sdp-field-setters.R`
  plants a placeholder, a blank and a `REVIEW:` marker in turn, and pins the
  required-IRI case with a configured schema. Each test runs the printed calls,
  and the placeholder and required-IRI tests failed on the scan as it stood.

  The console's footer now counts IRI gaps by field, not by the reason a row
  kept. So an IRI field reported as a placeholder, or as `required`, still
  counts as an IRI. And when every IRI gap is a placeholder, the line pointing
  at `review_semantics()` still prints. Counted by reason, that line dropped
  out once each field came back once. A test pins it with every IRI gap a
  placeholder.

  **Mirror:** metasalmonpy fixed the same defect first, with the same rule
  (hub item B-212, [metasalmonpy pull request 49](https://github.com/salmon-data-mobilization/metasalmonpy/pull/49)), so the two packages report
  the same rows. Its suite does not pin the required-IRI case. A defect the
  two packages shared is not a deliberate difference, so it opens no
  parity-register row. metasalmonpy's footer still counts IRI gaps by reason,
  so the footer change is owed there as a port, hub item B-244 (see
  `knowledge/parity-deviations.md`).

* **`read_sssom_mapping_set()` now reads a canonical SSSOM/TSV file, which
  leaves the built-in prefixes out of its `curie_map`** (hub item B-233). The
  reader looked every CURIE prefix up in the file's own `curie_map` and refused
  any it did not find, so `skos:exactMatch` in a file that did not declare
  `skos` stopped with *uses unknown CURIE prefix "skos"*. The SSSOM
  specification allows exactly that file: `owl`, `rdf`, `rdfs`, `semapv`,
  `skos`, `sssom`, `xsd` and `linkml` are built-in, they "MAY be omitted from
  the curie_map", and a canonical SSSOM/TSV writer "MUST NOT include" them. As
  `mapping_justification` is required and is always a `semapv:` CURIE, every
  canonical file with a mapping in it was refused. The eight are now accepted
  undeclared. Every other prefix still has to be declared, since SSSOM/TSV
  parsers "MUST reject a file with undeclared, non-built-in prefix names".

  One kind of file that used to be accepted is now refused: a `curie_map` that
  declares a built-in prefix with a different expansion, such as `skos` with
  `https://www.w3.org/2004/02/skos/core#`. The specification says a declared
  built-in "MUST point to the same IRI prefixes" as its table, and the old
  reader, which knew no built-ins, read such an entry as an ordinary
  declaration. The rule sits with the other CURIE checks, so it holds in
  `validate_sdp_sssom()` and for an in-memory set passed to `write_sdp_sssom()`,
  which is refused before anything is written, and `validate = FALSE` skips it
  as it skips them. The rules are in the model's Identifiers section and the
  table in the introduction's IRI prefixes section
  (<https://mapping-commons.github.io/sssom/1.0/spec-model/#identifiers>,
  <https://mapping-commons.github.io/sssom/1.0/spec-intro/#iri-prefixes>),
  unchanged in the SSSOM 1.1 draft.

  **Mirror:** metasalmonpy's reader refuses the same canonical files. It is
  owed there as a port, hub item B-234, and not registered as a deviation.

* **`DESCRIPTION` now declares the Python toolchain that
  `dwc_dp_build_descriptor(validate = TRUE)` runs** (backlog #57, hub item
  B-57). Validation writes a Python script, runs it with the interpreter the
  `python` argument names, and imports the `frictionless` Python package.
  Neither is an R dependency, and nothing in the package's metadata said they
  were needed. `SystemRequirements` now names both and says they are optional.
  What the function does with the validation result is unchanged: it still
  prints the report and returns the descriptor whatever the report says. That
  is hub item B-300.

  **Mirror:** metasalmonpy imports `frictionless` in-process, and its
  `pyproject.toml` does not declare it, not even as an optional extra. The
  declaration is owed there as part of hub item B-302.

* **`suggest_semantics(llm_assess = TRUE)` now shows the LLM as many candidates
  as `llm_top_n` says** (backlog #57, hub item B-57). The LLM can only be shown
  what retrieval kept, and the direct call kept `max_per_role` candidates per
  role, so the documented `llm_top_n` default of 5 silently became the
  `max_per_role` default of 3. `create_sdp()`, `infer_dictionary()` and
  `infer_salmon_datapackage_artifacts()` already widened retrieval to the larger
  of the two, and the direct call now does the same. With `llm_assess = TRUE`,
  `semantic_suggestions` therefore keeps up to `max(max_per_role, llm_top_n)`
  rows per role where it kept up to `max_per_role`. Without `llm_assess`
  nothing changes.

  **Mirror:** metasalmonpy's `suggest_semantics()` has the same defect. Under
  the same defaults its first review round shows the LLM 3 candidates per role,
  measured on `main` `f1f7230`. The widening is owed there as a port, hub item
  B-302.

* **`find_terms()` now checks what each parallel search worker delivered**
  (backlog #57, hub item B-57). When parallel search is on, the default outside
  Windows, the sources after `smn` and `gcdfo` are searched in forked
  `parallel::mclapply()` workers, and each worker's result was read without a
  check that it had delivered one. A worker that died, the way an out-of-memory
  kill or a crash in a native library ends one, dropped its source silently. It
  left no diagnostic row and no *did not answer* warning, and the incomplete
  result was cached and read as complete. An error that escaped a worker aborted
  the whole search with `$ operator is invalid for atomic vectors`. Either is
  now recorded as an error from that source, the way a source that errors is
  already recorded. So `find_terms()` warns that the source did not answer and
  does not cache the result.

  **Mirror:** metasalmonpy does not have this defect. Its `find_terms()`
  searches its sources one after another, so there is no worker to fail.

* **The ICES find helpers search the columns a response has, where a missing
  one was an error** (backlog #57, hub item B-57). `ices_find_code_types()` and
  `ices_find_codes()` guarded each column they search with `.data$col %||% ""`,
  which guards nothing: inside a data mask a missing column is an error, never
  `NULL`. So a response with no `longDescription` column aborted the search
  with *Column `longDescription` not found in `.data`*. An answer with no rows
  aborted it too, because it reaches the helpers as a tibble with no columns at
  all. A missing column now reads as empty text, as a missing value already
  did, and an answer with no rows gives an empty result. `ices_codes()` now
  returns the rows of a response with no `key` column, with an `NA` detail
  `url`, where it aborted. A failed request still gives the same empty result
  as an empty answer, as `ices_code_types()` and `ices_codes()` always have, so
  an empty result does not say whether ICES answered. The next entry adds the
  warning that tells the two apart (hub item B-377).

  **Mirror:** metasalmonpy already behaves this way. Its helpers fill a missing
  column with `""` and return an empty frame for an empty or failed response,
  and its own tests use a response with no `longDescription`. R has moved to
  match it, so nothing is owed there and no register row is needed.

* **The ICES helpers warn when the request fails, so an empty result no longer
  hides an outage** (hub item B-377). `ices_code_types()`, `ices_codes()`,
  `ices_find_code_types()` and `ices_find_codes()` returned the same empty
  tibble for a request that failed as for an answer with no rows, and nothing
  warned, so during an outage a user asking for a code list was told there was
  none. `.safe_json()` did record the failure, but as a condition with no
  default handler, and the ICES helpers installed none. A refused connection,
  an HTTP error status, a timeout, or an answer that is not JSON now gives a
  warning that names the request, with any secret in it redacted, and says what
  failed. The result is still the empty tibble, and an answer with no rows
  still gives it with no warning. A timeout also keeps the warning it already
  had.

  It is a warning and not an error because the return value does not change:
  the list helpers have always returned the empty tibble for a failed request,
  the find helpers have since B-57, and a caller that expects a data frame
  keeps getting one. `find_terms()` answers the same problem the same way, with
  a warning that a source did not answer.

  **Mirror:** metasalmonpy's helpers return an empty frame for a failed request
  with no warning, measured by the second 2026-09-25 queue sweep on its `main`
  at `056fccc`. The warning is owed there as a port, hub item B-378.

### Changed

* **`create_sdp()` and `write_salmon_datapackage()` no longer write a licence
  placeholder.** A blank `license` in `metadata/dataset.csv` used to be filled
  with *"MISSING METADATA: add dataset license (for example, CC-BY-4.0)."*, and
  it now stays blank. This is the writer half of making the dataset licence
  recommended rather than required in the SDP specification
  ([smn-data-pkg PR 12](https://github.com/salmon-data-mobilization/smn-data-pkg/pull/12);
  Brett, 2026-09-26: most datasets assign none). A blank licence states that
  none was granted, and `datapackage.json` then carries no `licenses`, just as
  it carried none for the placeholder. The other prompts are unchanged, because
  they fill fields the schema requires.

  **Strict validation still requires a licence for now.** metasalmon reads the
  requirement from its bundled SDP schema, which is re-vendored, with the remote
  pin, only from a specification release (hub item B-198). Until that release
  arrives here, `validate_salmon_datapackage(require_iris = TRUE)` reports a
  blank licence as a blank schema-required field rather than as a placeholder,
  and `review_metadata()` prints the `set_sdp_dataset()` call that fills it.

  **A package written before this change keeps its placeholder,** and strict
  validation refuses it, as it always has. State the licence the publisher
  granted, or clear the field with `set_sdp_dataset(path, license = NA)`, which
  passes once the licence is optional. Neither a placeholder nor a `REVIEW:`
  marker ever becomes a `datapackage.json` `licenses` entry: the placeholder is
  left out, and the writer refuses the marker.

* **The vendored SDP rules bundle is re-vendored for the reworded SOSA
  Procedure rules** (backlog #106, hub item B-106; ruled by Brett 2026-09-14,
  `knowledge/questions.md` Q47). `inst/extdata/schema/sdp.rules.yaml` is a
  byte-for-byte copy of `smn-data-pkg`'s `schema/sdp.rules.yaml`, and this is
  the copy half of that change -- paired with [smn-data-pkg PR 8](https://github.com/salmon-data-mobilization/smn-data-pkg/pull/8), which merged
  first as `bb71c8b`. Nothing was hand-edited on this side; the copies were
  identical before (md5 `3c702a37...`) and are identical after (md5
  `f94d6c8f...`, git blob `489d46a0`), which is the property
  `knowledge/orientation.md` asks for when it says to keep them in step by
  re-vendoring from upstream rather than hand-editing either side.

  **The rationale is no longer in the file, and the pointer it leaves behind is
  an upstream path.** Brett asked on 2026-09-15 that the reasoning not clutter
  the rules, so upstream moved it to `docs/adr/0002-sosa-procedure-reachability.md`
  and left a two-line comment naming that file and the unresolved outcome's
  retirement condition. metasalmon vendors the schema and not upstream's `docs/`,
  so a reader of `inst/extdata` who follows that pointer will not find the file
  here; it resolves in `smn-data-pkg`. Vendoring the ADR too, or rewriting the
  comment, would both break the byte-identity this entry rests on, so neither was
  done. *Retires when:* the vendored bundle carries its own rationale pointer
  that resolves inside this package, or `knowledge/orientation.md` records that a
  vendored file's internal paths are upstream's and are expected not to resolve.

  What the upstream rewording says, because the package ships the text and a
  reader of `inst/extdata` will not have the upstream changelog:
  `methods_are_sosa_procedures` and `row_varying_procedures_use_codes` now
  state **reachability**. A method or protocol IRI, and every `codes.csv`
  `term_iri` on a component bound with `sosa:usedProcedure`, is **declared by**
  a shared vocabulary and **reaches** a resource carrying
  `rdf:type sosa:Procedure` by a `skos:broader` path of **zero or more steps**
  -- so a directly typed IRI passes as the zero-length case. The phrase
  "resolves to" is gone, because it read as a per-IRI HTTP dereference and
  neither `smn` nor `gcdfo` is served for one. An asserted `skos:broader`,
  `skos:broadMatch` or any other sub-property of `skos:semanticRelation` whose
  other side is an `owl:Class` is refused by name: SKOS S19-S22 give every such
  property `rdfs:domain` and `rdfs:range` `skos:Concept`, so the edge entails
  that the OWL class is a `skos:Concept` and entails nothing about anything
  being a Procedure. Estimate-type and data-quality vocabularies are named as
  never being method vocabularies -- a Hyatt (1997) estimate type
  (`gcdfo:Type1`-`gcdfo:Type6`) or an ordinal quality or reliability rating says
  how good a value is, not how it was produced.

  **No observable behaviour changes in this package, and that is the defect
  rather than a reassurance.** Nothing in `R/` reads a rule `description`:
  `.ms_load_sdp_schema()` uses the document's `version` and `profile` and no
  rule text, and both reworded rules are among the three that backlog #48 (hub
  item B-48) measured as loaded and never executed. B-48 builds its dispatch on
  this text; no rule `id`, `severity`, `version` or `profile` changed, because
  that test keys on rule ids.

### Internal

* **The test suite now fails when a vignette relies on a global
  `knitr::opts_chunk$set()` to keep its display-only code out of the script
  `R CMD check` runs** (backlog #32, hub item B-164).
  `tests/testthat/test-vignette-purl-guard.R` tangles every vignette the way the
  check's fresh process does -- through the vignette's own engine, with knitr's
  default chunk options, because the tangle never runs the setup chunk -- and
  fails when one that turns `eval` or `purl` off globally still yields live
  code. #32 closed this shape in six vignettes on 2026-07-21 and added nothing
  that would notice a seventh. `migrating-to-sdp-0-3-0.Rmd` and
  `tidy-data-for-sdp.Rmd` were written afterwards in it: their 18 and 7 display
  chunks tangle as live code and fail `R CMD check` at the first statement on
  R 4.3.3. The guard was shown failing on both before anything else changed.
  Both stay as they are until hub item B-133 fixes them. Meanwhile the guard
  lists them as known offenders, each pinned to the chunks that offend today.
  A new live chunk in either one still fails, and so does an entry that has
  stopped offending.

  A test is needed because the check step that catches this stopped running by
  default in R 4.4.0, when `_R_CHECK_VIGNETTES_SKIP_RUN_MAYBE_` became true, so
  CI's current R stays green while `R CMD check` fails for a user on R 4.1 to
  4.3, which DESCRIPTION supports. *Retires when:* CI's own check runs that
  step again, which it cannot while the known-offender list has an entry.

metasalmon 0.5.0
----------------

Released 2026-08-25. Roadmap S5, and the one claim worth putting first: **a
salmon data package can now be taken from `create_sdp()` to
`validate_salmon_datapackage(require_iris = TRUE)` without opening a single
file in a spreadsheet.** Nine new exported functions — `review_semantics()`,
`accept_suggestion()`, `reject_suggestion()`, `apply_sdp_semantics()`,
`review_metadata()` and the four `set_sdp_*()` setters — plus the
`semantic_suggestions()` / `semantic_llm_assessments()` accessors, make the
most consequential decision in the pipeline scriptable, re-runnable and
recorded. Backlog **#74** is closed, with **#118** and the accessor half of
**#60**.

The release is a minor rather than a major: #58 (condition classes) wants a
breaking bump and was deliberately **not** bundled into it, so nothing here
renames an exported function, drops an argument, or changes a documented
return shape. It does change bytes in two narrow places, both stated in full
below — an in-memory SSSOM mapping set carrying a typed column, and
`semantic_suggestions.csv`, which gains a `decision_reason` column.

### Added

* **A package can now reach strict validation entirely from R.**
  `review_metadata()` and the `set_sdp_dataset()` / `set_sdp_table()` /
  `set_sdp_column()` / `set_sdp_code()` setters complete roadmap stream S5 and
  close backlog **#74**. `create_sdp()` → `review_semantics()` →
  `apply_sdp_semantics()` → `review_metadata()` → `set_sdp_*()` →
  `validate_salmon_datapackage(require_iris = TRUE)` **passes, with no file
  opened in a spreadsheet at any point**, and that whole sequence is asserted
  end to end in `tests/testthat/test-sdp-field-setters.R`.

  Until now it could not. The semantic review that shipped last was only half
  the job, and the half that was missing was the larger one:

  1. **Free-text `MISSING …:` placeholders** in `dataset.csv`, `tables.csv` and
     `column_dictionary.csv` are refused by strict validation, and the only way
     to replace them was a spreadsheet.
  2. **`review_semantics()` shows shortlists, not gaps.** A slot that retrieval
     returned nothing for never entered the queue, so a user could complete the
     entire console review and still be missing a required IRI, with nothing in
     the review saying so.

  `review_metadata()` closes both, because it does not read a suggestion list.
  It reads the package against the rules that actually decide strict
  validation — the Frictionless schema's `constraints.required` (parsed as
  `field$requirement` since the schema bundle landed, and read by **nothing**
  until now), the placeholder markers, the measurement-column IRI requirement,
  and the table observation-unit IRI requirement. A field no retrieval ever
  touched is as visible to it as one with five candidates.

  ```r
  review_metadata(pkg_path)
  #> ── dataset.csv ──────────────────────────────────────────────────────
  #>    creator: placeholder text, refused by strict validation
  #>       MISSING METADATA: add creator, team, or originating program.
  #>
  #>    set_sdp_dataset(pkg_path,
  #>      creator = "<add creator, team, or originating program>"
  #>    )
  ```

  **The printed call is the contract**, exactly as it is for
  `accept_suggestion()`: replace the `<…>` with the real value and paste, and
  the paste is the audit trail. Pasting one **unedited is refused** — a package
  whose `creator` reads `<add creator, team, or originating program>` would
  pass strict validation while saying nothing, which is worse than the
  placeholder it replaced, because the marker is gone. The address is resolved
  before the value is checked, so a printed call naming a row that does not
  exist fails on the address rather than being masked by that guard.

  The setters name the commonly-unfilled fields as arguments for
  discoverability and accept every other declared field through `...`, checked
  against the schema — so a misspelled `licence =` is an error rather than a
  silent no-op, and a schema that gains a field does not need this code changed.
  Each setter writes its metadata CSV and the `datapackage.json` keys that
  duplicate it as **one** transactional set, and the three descriptor builders
  are now shared with `write_salmon_datapackage()` rather than re-spelled, so
  "the patch produces the shape a rebuild would" is true by construction and
  asserted against an actual rebuild.

* **The semantic review no longer has to leave R.** `review_semantics()`,
  `accept_suggestion()`, `reject_suggestion()` and `apply_sdp_semantics()`, plus
  the `semantic_suggestions()` / `semantic_llm_assessments()` accessors, make
  the most consequential decision in the pipeline scriptable and re-runnable.
  Roadmap stream S5; backlog **#74** (and the accessor half of **#60**).

  Until now the documented workflow was: open `metadata/column_dictionary.csv`
  in a spreadsheet, read `semantic_suggestions.csv` as a shortlist, copy an IRI
  across by hand. The only record of that decision was the mutated CSV — the
  one unreproducible link in a chain that is otherwise byte-reproducible,
  C-collated, hash-verified and guarded.

  ```r
  review <- review_semantics(pkg_path)
  review
  #> ── spawners · spawner_count · variable ─────────────────────────────
  #>    field:   column_dictionary.csv · term_iri
  #>    current: REVIEW: https://w3id.org/smn/SpawnerAbundance
  #>
  #>   [1] Spawner Abundance   smn   score 4.9
  #>       The number of mature salmon returning to spawn in a stream.
  #>       https://w3id.org/smn/SpawnerAbundance
  #>       review <- accept_suggestion(review, "spawner_count", "variable", rank = 1)

  review <- accept_suggestion(review, "spawner_count", "variable", rank = 1)
  apply_sdp_semantics(pkg_path, review)
  ```

  **The console prints the exact call and the user pastes it. That paste is the
  audit trail**, and it is why there is no interactive prompt, no menu and no
  TUI: a `readline()` loop would leave the decision exactly as unreproducible as
  the spreadsheet it replaces. Because the printed string is the contract rather
  than decoration, the argument set is computed by *resolving* it — `table =`
  and `code_value =` appear only when they are needed to make the call address
  one slot — and the tests evaluate every printed line and assert it produces
  the decision it claims. That test found two real defects before release: a
  table-level slot printed `accept_suggestion(review, "NA", "entity", …)`,
  naming a column that does not exist, and a phantom `NA` row made an unrelated
  dictionary slot print a spurious `table =`. Both came from one unguarded `==`
  against a column that is legitimately `NA`.

  `apply_sdp_semantics()` is **surgical and re-runnable**: it strips `REVIEW:`
  from decided fields, clears rejected ones, leaves undecided slots untouched,
  and does not touch the data CSV bytes. Applying the same review twice produces
  identical bytes. The metadata CSVs, `semantic_suggestions.csv` and the field
  entries `datapackage.json` duplicates are installed as **one** transactional
  set through the existing atomic write path — per-file atomicity is not enough
  here, because the rule that would catch a CSV/descriptor drift
  (`datapackage_consistent_with_csv_metadata`) is one of the dead rules in
  `sdp.rules.yaml`, so nothing would detect a half-applied edit.

  Two limits were documented rather than papered over, and **both are closed by
  `review_metadata()` above** in this same development version. **A slot with no
  candidate never appears in the queue** — `review_semantics()` shows
  shortlists, not gaps — and **free-text fields had no R-native editor**. Either
  one alone was enough to make a completed console review still fail
  `require_iris = TRUE`.

  `review_semantics()` **never contacts a network or an LLM.** It reads
  suggestions that already exist, and surfaces LLM review only when the
  suggestions were generated with `llm_assess = TRUE`. A `stop()`ing
  `find_terms` binding is the sentinel that pins this.

### Fixed

* **A review decision now survives being put down and picked up again.** Three
  defects, all the same shape — the feature did the right thing once and then
  forgot it — found by teaching the review flow to learners, which is the
  harshest usability test an API gets.

  **A rejection did not survive rebuilding the queue.** `apply_sdp_semantics()`
  wrote `decision = "rejected"` into `semantic_suggestions.csv` and cleared the
  field, but nothing ever read that column back, and a cleared field reads as
  *undecided*. A reviewer who worked through sixteen slots, rejected four and
  came back the next day was asked the same four questions with no sign they had
  ever answered them. `review_semantics()` now replays the recorded decisions,
  keeps decided slots out of the default queue, and shows them under
  `include_filled = TRUE`.

  **The rejection `reason` never reached disk.** It lived on the in-memory
  review object and printed to the console; only the bare word `rejected` was
  written. For a feature whose whole thesis is *the record of why*, that was the
  single field that most wanted a column. `semantic_suggestions.csv` gains
  `decision_reason`, and `review_metadata()` reads it back onto the gap the
  rejection left — otherwise that gap comes back looking exactly like one nobody
  ever considered. Applying a review also **preserves** decisions it does not
  itself carry, where it previously blanked the column first: Monday's four
  rejections used to be erased by Tuesday's acceptance.

  **An empty queue under a bad `columns` filter read as success.**
  `review_semantics(pkg, columns = "TYPO")` printed *"No unfilled semantic slots
  with suggestions … every slot that had a shortlist already holds a final
  IRI"*, telling a user who mistyped a column name that their package was
  finished. A `columns` value matching no column is now an error that names the
  columns that do exist; a column that exists but has nothing left to decide
  still gets the (now accurate) completion message.

* **`prune = TRUE` warns before it destroys recorded review decisions.**
  Pruning wipes the package directory, and `semantic_suggestions.csv` is not
  among the files a rewrite produces, so a user reaching for `prune` mid-review
  silently lost the audit trail. The prune still happens — a clean rebuild is a
  legitimate thing to want — but it now says what it is about to take, and only
  when there is a recorded decision to lose.

* **A reviewed semantic decision is no longer overruled by the unattended
  auto-apply heuristic.** `apply_semantic_suggestions(strategy = "reviewed")`
  ran every accepted row through `.ms_filter_auto_apply_suggestions()`, the
  lexical compatibility gate that decides whether a *seeded* top-1 hit is safe
  to write into a dictionary nobody has looked at. On the reviewed path a human
  has read the definition and said yes, so the effect was that a regex silently
  overruled the decision and the caller was told only that some rows "did not
  meet the requested filters". Found while building `apply_sdp_semantics()`,
  which would have dropped accepted terms for exactly this reason; the
  unattended `strategy = "top"` path keeps the gate, which is the whole reason
  the gate exists. Backlog **#118**.

### Changed

* **The documentation stops sending users to a spreadsheet.** The quickstart
  vignette's section titled *"Review In Excel"* — which was this stream's whole
  subject — is now *"Review In R"* and walks the two-call flow end to end. The
  `README-review.txt` checklist that `create_sdp()` writes into every package
  told users to open the CSVs in Excel; it now hands them the R calls in order,
  each of which prints the call for the next step. `create_sdp()`'s own closing
  message does the same. The spreadsheet path is still supported and is still
  described — as the fallback, with the reason it is the fallback: a
  spreadsheet edit leaves no record of *why* a value was chosen.

* `_pkgdown.yml`'s **Semantic Review (in R)** group becomes **Review and Edit
  (in R)** and gains `review_metadata()` and the setters, and the `README`
  review workflow names the R path first with the spreadsheet path kept as the
  supported alternative.

* **An existing but *empty* directory no longer requires `overwrite = TRUE`.**
  `write_salmon_datapackage()` and `create_sdp()` now write into a directory
  that exists and contains nothing, where they previously aborted with
  "Directory ... already exists." `overwrite` exists to authorize destroying
  something, and an empty directory has nothing to destroy; demanding it for
  the ordinary `dir.create()`-then-write shape trained callers to pass
  `overwrite = TRUE` habitually, which is the flag's whole value gone.

  **"Empty" is literal, and the definition is the substance of the change.** It
  means `.ms_dir_entries()` returns nothing — `list.files(all.files = TRUE,
  no.. = TRUE)` — so a dot-file, a stale `.metasalmon-package` sentinel, or an
  empty `data/` subdirectory each make the directory **non-empty**, and the
  `overwrite` gate applies to them exactly as before. Emptiness is never
  recursive. Each of those three is now pinned by its own test, alongside the
  unchanged behaviour for a directory holding an ordinary file.

  This adopts metasalmonpy's guard order on Brett's ruling of 2026-08-24
  ("Go with the python implementation"), retiring `knowledge/parity-deviations.md`
  row 54. The divergence is older than the mirror's parity claim: it arrived in
  metasalmonpy with its 0.1.6 alignment commit and metasalmon 0.1.6 already had
  the other order, so the two sides have disagreed here since **before** the
  0.1.6 claim was made. It survived because **neither suite tested it** — R's
  test used a *non-empty* directory and the mirror did not test the case at all
  — so a whole-suite parity run stayed green over it for four minor versions.
  What the measurement added: both sides already computed the *identical* notion
  of "empty" (`list(path.iterdir())` is the same predicate), and only its
  position relative to the `overwrite` gate differed. Of five directory shapes
  driven through both implementations, exactly one cell disagreed.

  `create_sdp()` carries its own earlier copy of the gate — deliberately, so a
  doomed call never spends a retrieval pass or an LLM request — and that copy
  moved with the authoritative one. It had to: leaving it would have let the
  coarser guard silently win, which is a fair warning about duplicated checks
  and is now registered as row 60.

### Fixed

* **The 173-row Fraser coho example now reaches a KNB deposit plan.** Its one
  measurement row, `NATURAL_ADULT_SPAWNERS`, was missing `term_iri`,
  `entity_iri` and `term_type`; all three are now filled in the shipped starter
  dictionary `inst/extdata/nuseds-fraser-coho-2023-2024-column_dictionary.csv`.

  `entity_iri` is **`smn:Population`**, not the `gcdfo:ConservationUnit` the
  30-row demo uses. That is not a copy of the smaller example with a different
  spelling: this slice keys on `POP_ID`, which is a finer grain than a
  Conservation Unit, so annotating it as a CU would have been wrong at the row
  level while passing every check the package can run.

  `term_type` is the half of this that a reader should not skip. Strict
  validation — `validate_salmon_datapackage(require_iris = TRUE)`, which the
  docs call the final gate — passed with `term_type` empty; `write_eml_from_sdp()`
  then refused the same package, because EML annotation requires the term to be
  declared `owl_class` or `skos_concept`
  (`.ms_eml_measurement_term_annotation()`). **Strict validation is not the
  publication gate**, and nothing said so. Filed as backlog #117 with the two
  ways to reconcile them; the vignette and the example README now both state the
  distinction rather than implying there is one gate.

  The example's own README claimed the dictionary "does not pass strict
  validation as shipped" and pinned the exact failure text. That claim was true
  when written and became false with this change, so it is corrected rather than
  left to mislead. The two tests that encoded the same stale state
  (`test-example-round-trip.R`, `test-example-data.R`) are updated — the
  round-trip test now pins both halves of the new behaviour, including that
  resolving *only* the `MISSING METADATA:` placeholders carries the shipped
  example through the strict gate.

* **One value, one rendering: canonical text is now coerced once, at render
  time, per type.** Brett's 2026-08-24 ruling on hub [Q12] closes backlog #93
  items 3 and 5 — *"fix all three by coercing them once at render time per
  type"* — and the shape is ported from metasalmonpy, whose
  `sssom._canonical_bytes()` builds its `cells` once and indexes both the sort
  key and the row writer into it.

  `.ms_sssom_canonical_bytes()` took its sort key through `as.character()` and
  its emitted bytes through `as.matrix()` inside `apply()` — which renders
  through `format()`. Row *order* and row *content* could therefore disagree
  about the same cell. `mapping_date`, `publication_date` and `review_date`
  are declared SSSOM columns, so an in-memory mapping set with a typed date
  column hit it directly: given `mapping_date` values `1000-01-01` and
  `0999-01-01`, the function ordered by the unpadded spellings (where
  `"1000-01-01"` sorts *before* `"999-01-01"`, because `"1" < "9"`) and
  emitted the padded ones — a canonical table not sorted by its own visible
  contents.

  Two things it turned out to be worse than, both fixed by the same change:

  - **It needs no pre-1000 date at all.** `format()` on a data-frame column is
    *vector-wise*: it picks one notation for the whole column. A `confidence`
    of `1.5` was emitted as `1.5e+00` merely because another row held
    `100000` — while sorting as `1.5`. A cell's canonical bytes were a
    function of its neighbours.
  - **The key/content disagreement is different on each platform.**
    `format()` pads `%Y` on macOS and glibc does not, so macOS emitted padded
    bytes in an unpadded order while Linux was self-consistent and unpadded.
    A single-platform run cannot see the whole defect.

  `.ms_canonical_value_tokens()` had the same split at smaller blast radius
  (#93 item 5): its `original` fallback took `trimws(as.character(x))`, so a
  `Date` column declared `value_type = "string"` keyed `999-01-01` while the
  `date` branch beside it keyed `0999-01-01` — and while the CSV
  `write_salmon_datapackage()` produces from that same column reads
  `0999-01-01`. An in-memory frame disagreed with its own written package
  about whether a data value was listed in `codes.csv`.

  Both now route through one new internal helper, `.ms_canonical_character()`
  (`R/platform-time.R`), which renders a value **once**, choosing the renderer
  by type: character is identity (`.ms_iso_character()` would rewrite a user's
  `psc:12-34-56` into `0012-34-56`), `Date` and `POSIXct` are padded, and
  everything else takes element-wise `as.character()` so no cell can be
  reshaped by another row.

  **Observable byte changes, stated plainly.** Only an in-memory SSSOM mapping
  set carrying a non-character column is affected — a set read from a
  `.sssom.tsv` file is all character, where every renderer agrees, so no
  existing golden hash moved and none was regenerated. For such a set:
  `confidence` `1.5` now emits `1.5` rather than `1.5e+00`; `100000` emits
  `1e+05` rather than `1.0e+05`; a pre-1000 `mapping_date` emits its padded
  ISO form on every platform, and rows sort by that same form. The `sha256`
  recorded in `metadata/semantic/mapping-sets.json` moves with the bytes, as
  it should.

  **`.ms_iso_date_columns()` is deliberately unchanged, and the asymmetry is
  the point.** It sits on the `readr::write_csv()` path, whose instant output
  is already correct, so #93 item 1 ruled that padding a `POSIXct` there would
  corrupt a path that was never broken. `.ms_canonical_character()` sits on the
  `as.character()` path, where the year is unpadded for both types, so it pads
  both — which is also what metasalmonpy's `_cell()` does, since `str()` is
  pure Python and padded for `date` and `datetime` alike. Same package,
  opposite rulings for the same type, both correct; a regression test pins
  that the second did not leak into the first.

* **Backlog #93 item 4 was investigated and found unreachable, not fixed.**
  The item read that `jsonlite::write_json()` pads a `Date` while
  `readr::write_csv()` does not, so one `write_salmon_datapackage()` call could
  emit `0999-01-01` into `datapackage.json` and `999-01-01` into
  `metadata/dataset.csv`. Item 2's 2026-08-21 fix put `.ms_iso_date_columns()`
  inside `.ms_align_cols()`, and every frame that reaches the descriptor is
  aligned — traced across the whole descriptor builder in both assembly sites:
  no `created`/`sources`/custom-field passthrough, field objects built from the
  dictionary alone, no resource value copied into the descriptor. No `Date`
  survives to either writer. A regression test asserts the two files *agree*
  rather than asserting the coercion, so it still fails if a future descriptor
  key starts carrying a typed value; it was verified RED by removing the
  coercion.

  Two corrections to the item's premise came out of the trace, both measured.
  jsonlite 2.0.0 serializes a `Date` through `format.Date`, which delegates
  `%Y` to the platform's strftime — so on glibc jsonlite emits `999-01-01`
  too, and item 4 was a **macOS-only** split even before item 2 closed it. And
  the same *shape* of defect is alive for `POSIXct`, which `.ms_align_cols()`
  deliberately leaves typed: a `temporal_start` of
  `as.POSIXct("0999-06-05 13:45:30", tz = "UTC")` is written as
  `0999-06-05 13:45:30` in `datapackage.json` and `0999-06-05T13:45:30Z` in
  `metadata/dataset.csv`. That is a *format* disagreement rather than a
  padding one, deciding it needs a ruling on which spelling a descriptor
  instant takes, and metasalmonpy has the same disagreement plus an unpadded
  CSV side. Filed as backlog **#115** rather than folded into this change.

### Internal

* **`create_sdp()`'s deterministic constraint and statistical-modifier prefill
  is now pinned.** No behaviour changed here — Brett ruled on 2026-08-24
  ("Yeah lets go the R way") that this side was correct and metasalmonpy moved
  — but the *reason* the divergence survived was that neither suite pinned the
  positive case. Both had asserted several times over that the two qualifier
  slots stay **empty** when the evidence gate rejects, and neither asserted
  they ever fill. `tests/testthat/test-package-helpers.R` now drives a
  `mean_wild_spawner_count` column through `create_sdp()` and asserts both
  slots fill **and carry the `REVIEW:` marker**; the marking is asserted rather
  than assumed, because review-visibility is the property the ruling turned on.
  Retires `knowledge/parity-deviations.md` row 57.

  Two findings worth carrying: this package's "no role restriction" is true of
  the **deterministic path only** — the LLM path restricts to the same four
  core roles the mirror used everywhere — and the two implementations spell the
  `REVIEW:` marker differently (`REVIEW: ` here, `REVIEW:` there). The second is
  inert to behaviour, invisible to every test on either side, and now
  registered as row 61 with [Q18](https://github.com/salmon-data-mobilization/metasalmon/blob/main/knowledge/questions.md#q18--review--or-review--does-the-markers-exact-spelling-matter) open on it.


* **The role-contract guard now checks all seven surfaces in one file, and
  each one is demonstrated to fail.** `AGENTS.md` has said since 2026-08-18
  that the coverage was split — `tests/testthat/test-role-contract-guard.R`
  claiming the first six, `role_boost` guarded over in
  `tests/testthat/test-smn-outranks-gcdfo.R` — so "did I reach every layer"
  had two answers and neither was complete. metasalmonpy's 0.4.0 parity work
  consolidated its own copy first (`tests/test_role_contract_guard.py`), and
  this is that design ported back under Brett's 2026-08-17 ruling that the
  mirror is not automatically the follower.

  The guard is now section-headed `SURFACE 1` … `SURFACE 7`, so a missing
  layer is legible in the failure rather than only in the test name. Two
  findings came out of doing it, and both are arguments for demonstrating a
  guard rather than reading it:

  - **Surface 5 was never checked here at all.** The deterministic validators
    (`semantic-bundle-validators.R`) were listed in `AGENTS.md` among the
    "first six" this file covered and were not among them, so the honest
    figure was five, not six. Dropping an evidence gate from
    `.ms_semantic_apply_bundle_validators()` removed the only deterministic
    check between the model's word and an IRI written into the dictionary,
    and nothing failed. A new pair of tests asserts each gated role
    (`method`, `statistical_modifier`, `constraint`) has a validator that
    names it, that the dispatcher calls it, that it raises its own `SEM_*`
    code, and that the role-type veto is wired in.
  - **`sources_for_role()` had no fall-through check.** metasalmonpy's guard
    had one where R's did not; ported. A role that falls through to the
    generic source list has no retrieval identity of its own, which is the
    shape of failure that let `statistical_modifier` reach ranking with no
    source preferences in the first place.

  Each of the seven surfaces was broken in turn and the guard confirmed RED
  for each; the demonstrations are in the pull request that introduced this
  entry.

  `role_boost` is read in place from `.ranking_profile_defaults()` rather
  than hoisted to a package constant as metasalmonpy hoisted `ROLE_BOOST`.
  Python hoisted because its table was an inlined dict literal inside the
  scorer with nothing enumerable to assert against; R's is already a named
  list returned by the function that is the merge base for the
  `ranking_profile` override system, and hoisting would have created a second
  copy of the authority — the drift metasalmonpy then needed an extra test to
  rule out. What did port is that extra test: a pin that the `role_boost`
  table the guard enumerates is the table `.score_and_rank_terms()` actually
  merges.

  `tests/testthat/test-smn-outranks-gcdfo.R` keeps the smn-over-gcdfo
  **margin**, which is its own subject, and no longer carries the coverage
  check. Its header says so, and says why the margin assertions that remain
  are not a second coverage check: they are scoped to roles served by both
  sources, so they say nothing about `statistical_modifier`.

* **The `role_boost` comment in `.ranking_profile_defaults()` called it the
  sixth surface of the role contract; it is the seventh.** `AGENTS.md` counts
  `inst/extdata/ontology-preferences.csv` as the sixth. The count was off by
  one in the comment, not in the contract, and `AGENTS.md` had flagged it
  explicitly as a thing to fix in the comment — an eighth surface arriving
  into a numbering ambiguity is how the seventh went unnoticed. The 0.4.0
  entry below inherited the wrong number from that comment and carries a
  dated correction rather than a silent edit.

metasalmon 0.4.0
----------------

Released 2026-08-24. Roadmap S3 makes a KNB deposit rehearsable against the
test node, and the rest of the release is the post-0.3.0 fix stream: the
package writer is transactional over the files it owns, calendar text renders
identically on macOS and Linux, both shipped examples pass the package's own
final gate, and semantic ranking puts `smn` above `gcdfo` as the ontology
preferences always said it did.

### New

* **`publish_sdp_to_knb()` and `write_eml_from_sdp()` take a
  `knb_environment`, so a deposit can finally be rehearsed** (roadmap S3).
  Both functions hardcoded production, and the member node, coordinating node,
  resolver, and Solr endpoints were module-level constants — this is the first
  state those modules have ever had to vary. Two environments, matched
  exactly, with no partial matching, no custom endpoints, and no fallback
  between them:

  | Environment | DataONE network | Member node | Credential |
  |---|---|---|---|
  | `"test"` | `STAGING` | `urn:node:mnTestKNB` at `dev.nceas.ucsb.edu` | `dataone_test_token` |
  | `"production"` | `PROD` | `urn:node:KNB` at `knb.ecoinformatics.org` | `dataone_token` |

  Every value was read from the DataONE node documents themselves on
  2026-08-22 rather than assumed: the KNB Test Node answers 200 at
  `https://dev.nceas.ucsb.edu/knb/d1/mn` and is registered `state="up"` in the
  staging coordinating node (`urn:node:cnStage`, `cn-stage.test.dataone.org`).

  **A dry run defaults to `"test"`; a live call has no default.** That is
  Brett's 2026-08-22 ruling — develop against the test node first, post to
  production once the package looks good there — and an unstated environment
  on a live call is an error rather than a silent production target. Live
  publication still demands `confirm = TRUE` in both environments; naming an
  environment is not a substitute for approving the plan.

  Three properties are structural rather than advisory, and each is tested:

  - **An environment switches whole.** Every derived URL is built from that
    environment's own member-node and coordinating-node base URLs, so no
    assignment in the package can pair a test node with a production Solr
    endpoint. Reads re-derive the whole record from the plan's fingerprinted
    `node_id` and refuse any plan whose network, node, and environment name
    disagree — a hand-edited manifest cannot smuggle a mixed pair through.
  - **A test deposit cannot mint production identity.** The node identifier in
    every SystemMetadata and OAI-ORE artifact is the selected environment's
    own, and identifiers are scoped so a test PID can never collide with or be
    mistaken for a production one. The SDP archive is the sharpest case: its
    bytes are environment-independent, so without the scope the same package
    would mint the same archive identifier in both.
  - **The reviewed production EML is never replaced.** A test document has
    different bytes, and those bytes are hashed into `plan_sha256`, the
    deterministic archive, and the reproducibility manifest — so test
    artifacts go to `publication/test/` while production keeps
    `metadata/eml.xml` and `publication/knb-manifest.json`. A rehearsal is
    publication-writer output that the base package writer preserves.

  Test deposits also request zero replicas, and a revision may not cross
  environments. **Production behaviour is unchanged**: production identifier
  preimages are byte-identical to those minted before this change, so an
  existing manifest still validates and an existing package can still be
  re-planned.

  No live deposit has been performed in either environment; a test-node token
  is still outstanding. Everything verified for this release was a read-only
  node-capabilities GET.

* **`nuseds_estimate_classification_crosswalk()` maps NuSEDS
  `ESTIMATE_CLASSIFICATION` values onto the released gcdfo Hyatt (1997)
  estimate types** (backlog #101), and `create_sdp()` wires it in exactly
  where the estimate-method crosswalk is wired, with the same
  never-overwrite-an-explicit-IRI rule. `TRUE ABUNDANCE (TYPE-1)` …
  `PRESENCE-ABSENCE (TYPE-6)` map to `gcdfo:Type1`–`gcdfo:Type6`
  (`skos:Concept`s under `gcdfo:EstimateType`, released in gcdfo 0.0.9). Two
  families of values deliberately map to no Type concept, and the crosswalk
  records the disposition instead of forcing it: `NO SURVEY THIS YEAR` is an
  absence-of-observation marker, not an estimate type (mapping it would assert
  a survey quality for a survey that did not happen), and the two
  `RELATIVE: … MULTI-YEAR METHODS` classifications have no released concept of
  their own so they link at scheme level, the convention the estimate-method
  crosswalk already uses for `Cumulative CPUE`. The two prefill passes now
  share one engine (`.ms_prefill_legacy_code_terms()`) rather than a
  copy-paste sibling.

* **`create_sdp()` now applies the enumeration crosswalk to
  `ENUMERATION_METHODS` codes** (backlog #102). `"Fence"` has always been in
  `nuseds_enumeration_method_crosswalk()` (→ `gcdfo:FixedSiteCensusManual`),
  but the only crosswalk `create_sdp()` wired was the estimate one — so a
  NuSEDS column recording `Fence` got no `term_iri` while the crosswalk that
  supplies one sat exported, documented, tested, and unreachable from the
  package path. Resolved by wiring, not by row: `Fence` is an enumeration
  (field) method recorded under `ENUMERATION_METHODS`, exactly the division of
  labour the two crosswalks document, so adding a `Fence` row to the estimate
  crosswalk would have misfiled it. The prefill matches on the word
  `enumeration` alone because NuSEDS names the column in the plural
  (`ENUMERATION_METHODS`) and a `\bmethod\b` test would never match it;
  combined multi-method values (`"Stream Walk, Other"`) have no crosswalk row
  and stay blank, and explicit caller-supplied IRIs are never overwritten.

### Fixed

* **An abort anywhere in `write_salmon_datapackage()` now leaves the caller's
  existing package intact** (backlog #96, the ordering half). The write path
  unlinked every managed path (`metadata/*.csv`, `datapackage.json`, declared
  `data/` resources, the ownership sentinel) *first* and wrote replacements
  *afterwards*, so any abort in between — a broken schema bundle, a
  serialization error, the next typed-column bug — deleted the package's
  metadata and descriptor and left nothing in their place. The `Date`
  comparison fixed below was one trigger; the delete-then-write ordering was
  the defect class. The writer is now transactional over the files it owns:
  every output (data CSVs, metadata CSVs, descriptor, sentinel) is rendered to
  bytes **before** anything on disk is touched, and the rendered set is
  installed through the same staged, rollback-protected mechanism the methods
  migration already used (`.ms_sdp_extension_atomic_write_set()`), so even a
  failure mid-install restores the previous files. Managed paths this call
  does not rewrite (orphaned data resources, legacy root-level metadata
  shadows, a stale `codes.csv`) are unlinked only after the install succeeds.
  Output bytes are unchanged — each file is rendered by the exact writer call
  it was written with before. One deliberate exception, stated rather than
  silent: `prune = TRUE` deletes files the writer does not own and therefore
  cannot restore, so its wipe runs only after every input-dependent step has
  succeeded, and the residual window is pure filesystem failure (disk full,
  permissions) between wipe and install. Regression tests inject aborts at
  post-unlink points of the old ordering — verified to destroy the package
  before the fix — and assert the surviving package is byte-identical and
  readable; a structural guard keeps direct filesystem writes out of the
  writer body so the ordering cannot silently regress.

* **A `Date`-typed `temporal_start` no longer destroys the package on disk**
  (backlog #96). `write_salmon_datapackage()` tested
  `dataset_meta$temporal_start[1] != ""`; comparing a `Date` with `""` coerces
  `""` to `NA_Date_`, the `if` condition evaluated to `NA`, and the call
  aborted with *"missing value where TRUE/FALSE needed"* — **after** the
  managed paths had been unlinked and **before** any replacement was written,
  deleting `metadata/` and `datapackage.json` and leaving nothing in their
  place. The triggering input is what the package itself wrote: reading a valid
  package's `metadata/dataset.csv` back with a plain `readr::read_csv()`
  type-guesses `temporal_start` as `Date`, because metasalmon put an ISO date
  there. Every scalar presence test in the descriptor builder (`creator`,
  `contact_*`, `license`, `temporal_*`, `table_label`, `description`,
  `primary_key`) now renders the value to character before deciding presence
  (`.ms_meta_scalar_present()`), a `POSIXct` — whose `!= ""` comparison throws
  outright rather than yielding `NA` — is covered by the same route, and the
  descriptor's temporal values are rendered with `.ms_iso_character()` so the
  JSON and the CSV cannot disagree about the same field. A regression test
  proves the directory survives the round trip.

* **Metadata normalization now renders `Date` columns as padded ISO text**
  (backlog #93 item 2, unblocked by item 1's Date-only ruling).
  `.ms_align_cols()` — the in-memory path's only normalizer for
  `dataset.csv` / `tables.csv` / `column_dictionary.csv` / `codes.csv` frames —
  did no type coercion, so a caller-supplied `Date` column reached
  `readr::write_csv()` (which renders an unpadded year below 1000) and the EML
  `calendarDate` renderer intact; the on-disk path was safe only because
  `.ms_read_metadata_csv()` pins every column to character. Normalization now
  applies `.ms_iso_date_columns()` — `Date` only, per the measured rule:
  readr's `POSIXct` rendering is already correct and coercing it would change
  bytes. A consequence worth naming: `datapackage.json` and
  `metadata/dataset.csv` can no longer disagree about a metadata `Date` field
  (item 4's failure mode on this path), because no `Date` survives to either
  writer. Items 3 and 5 of #93 (SSSOM canonical bytes; canonical value
  tokens) remain open under Q12.

* **`write_salmon_datapackage()` can read back the dates it writes.** A `Date`
  column holding a year below 1000 was written as text this package's own
  reader rejected: `readr::write_csv()` renders a `Date` through
  `as.character.Date`, whose R-4.3 fast path emits an unpadded year, and
  `readr::parse_date("1-01-01")` returns `NA` — so a round trip aborted with
  "unparseable as that type". Date columns are now rendered through
  `.ms_iso_date_columns()` before writing.

  This is **not** the platform split fixed below, and the two point in opposite
  directions: that one disagreed between macOS and Linux, this one was wrong on
  every platform, so no amount of cross-platform CI could surface it.

  The fix is deliberately confined to `Date`. Measured rather than assumed:
  `readr` already emits `0001-01-01T00:00:00Z` for a `POSIXct`, so its instant
  path was never broken — and coercing it would have changed bytes twice over,
  swapping `T…Z` for a space and reinstating a fractional second that `readr`
  drops. Applying the fix to both types by symmetry would have corrupted the one
  that was correct. metasalmonpy was already correct here (`date.isoformat()`,
  `str()` and `pandas.to_csv` all pad), so R is the side that moved.

* **Calendar years below 1000 are zero-padded on every platform.** `%Y` is the
  one strftime field whose width the C standard leaves unspecified, and glibc
  does not pad it. R delegates `%Y` to the platform strftime unless it was
  built with `--with-internal-tzcode` — the configure default on macOS, and not
  generally on Linux — so `format(as.Date("0001-01-01"), "%Y-%m-%d")` returned
  the padded `"0001-01-01"` on macOS and the unpadded `"1-01-01"` on Linux.
  Measured on this package's Linux CI runner on 2026-08-21, which returned
  `"1-01-01"`, `"100-02-03"` and `"999-12-31"` for years 1, 100 and 999.

  This reached four paths, and the failure was different in each. In
  `.ms_canonical_value_tokens()` the canonical date and datetime keys are
  written into package bytes, so the same input produced different packages on
  the two platforms — and nothing errored, because both sides of a `codes.csv`
  comparison shifted together. In `.ms_sdp_observation_typed_character()` and
  the observation normalizer, the rendered text is matched against a `[0-9]{4}`
  year pattern, so on Linux a valid year-1 date was rejected as malformed and a
  normalized value would not have survived a second normalization. In the EML
  export, a round-trip check compared the reformatted date against the user's
  own token, so a valid `dateTime` calendar value **aborted the export** on
  Linux while exporting cleanly on macOS. The spreadsheet-preview reader had
  the implicit form of the same defect, via `as.character()` of a Date.

  Calendar text is now rendered through `R/platform-time.R`. The fix is
  deliberately narrow — only the year is built by hand, and `%m`, `%d`, `%H`,
  `%M`, `%OS` stay with strftime, because `%OS6` *truncates* the fractional
  second where `sprintf("%.6f", ...)` rounds and a hand-built timestamp would
  have changed bytes on the platform that was already correct. Verified
  byte-identical to the previous calls for every year the two platforms already
  agreed on. **On macOS nothing changes; on Linux, packages written with a
  pre-1000 date now match.** `tests/testthat/test-year-padding-guard.R` fails
  on any new `format()` carrying a raw `%Y`.

  metasalmonpy hit the identical split in Python in 0.2.0 and pads
  unconditionally, so this brings metasalmon into line with the mirror rather
  than the other way round (Brett's 2026-08-17 ruling); parity register row 40.

* **Inferred temporal coverage and EDH temporal positions are padded too.**
  Looking for the `%Y` sites turned up a *second*, unrelated defect:
  `as.character()` of a `Date` is not `format()`. Since R 4.3 it takes an
  internal fast path that emits an unpadded year on **every** platform, macOS
  included — so the two defects point in opposite directions, and a path that
  formats on one side and coerces on the other mismatches on macOS and matches
  on Linux. `infer_dataset_metadata_from_resources()` used it for
  `temporal_start`/`temporal_end`, which are computed from the user's own date
  columns and written into `metadata/dataset.csv`, EML `calendarDate` and EDH
  `gml:beginPosition`; the EDH metadata accessor used it for every temporal
  field, behind an `inherits(value, c("POSIXct", "POSIXt", "Date"))` test whose
  two branches were identical, so it read as though the case was handled and did
  nothing. A year-999 coverage bound emitted `999-01-01` — not a valid
  `xs:date`. Both now go through `.ms_iso_character()`, which pads the rendered
  text without re-deriving it, so every four-digit year is byte-identical to
  before. **This is not fully fixed**: `write_salmon_datapackage()` still writes
  resource columns uncoerced, so a `Date` column with a pre-1000 year is written
  as text this package's own reader cannot parse. That needs a decision about
  where type coercion belongs and is tracked as backlog #93.

* **A `datetime` observation dimension no longer rejects a valid package.**
  *(Correction, 2026-08-24: this entry reads as though R found and fixed the
  defect first. metasalmonpy had fixed it seven days earlier — it had
  deliberately mirrored the defect, then repaired it — so R was the follower
  here. Recorded as parity row 55, which the entry should have cited.)*
  Since 0.2.0 `.ms_sdp_observation_validate_data()` has read resources through
  `read_salmon_datapackage()`, which types each column from the dictionary, so
  a column declared `datetime` reaches the observation validators as a POSIXct
  rather than as CSV text. The normalizer took `as.character()` of it, yielding
  `"2024-01-31 10:00:00"` — a space, no `T`, no zone — and tested that against
  a strict ISO-8601 pattern the string can never match. Every package with a
  datetime-typed dimension was rejected, and `write_sdp_observation_structures()`
  refused to write one. The normalizer now formats the temporal classes into
  the canonical lexical form the validators expect; character input is
  untouched, so malformed text still fails its pattern. The same lexical form
  is used where observed `sosa:usedProcedure` codes are compared against
  `metadata/codes.csv`, which had the identical exposure.

* **ISO-8601 instants keep their time of day.** `as.POSIXct()` has no
  ISO-8601 entry in its default format list: given `"2024-01-31T10:00:00Z"` it
  falls through to `"%Y-%m-%d"` and silently returns midnight. Both the
  observation normalizer and the caster did this, so two distinct instants on
  one date collapsed to a single grain key — a genuine invariance violation
  would go unreported, and a legitimate sub-daily series looked
  self-contradictory. Instants are now parsed explicitly, with a `+HH:MM` or
  `-HH:MM` zone offset folded into UTC rather than discarded. The defect was
  unreachable before the fix above, because every datetime dimension aborted
  first; metasalmonpy's mirror was correct throughout, and this brings
  metasalmon into line with it.

* **The shipped 30-row example now passes `validate_salmon_datapackage()`**
  (backlog #98). `inst/extdata/nuseds-fraser-coho-sample.csv` stored
  `START_DTT`/`END_DTT` as Oracle `DD-MON-YY` text while its bundled
  dictionary declared `value_type: date`, so writing the pair and validating
  aborted with 2 structural issues in **both** modes — the artifact the docs
  hand a new user as the fastest walkthrough failed the package's own final
  gate. The data was fixed rather than the dictionary: the `date` declaration
  is the semantically correct one for `column_role: temporal` columns, the
  fuller 173-row example's derivation script already converts the same columns
  to ISO, and retyping them `string` would teach users to discard date
  semantics whenever source bytes are ugly. The 28 values were converted with
  the same `%d-%b-%y` parse the package's temporal inference uses (so the
  century pivot matches: `03-DEC-97` → `1997-12-03`); every other byte of the
  file is unchanged, and no other bundled metadata derives from the date
  format. The DD-MON-YY parsing test now carries its own inline Oracle-format
  fixture instead of leaning on the shipped sample, and a new round-trip test
  builds the package from the shipped artifacts and validates it so the pair
  cannot silently diverge again.

* **The shipped example dictionary's two placeholder IRIs are replaced with
  released terms that resolve** (backlog #99).
  `https://w3id.org/example/salmon#AbsoluteSpawnerAbundance` and
  `https://w3id.org/example/salmon#WildOriginConstraint` — both HTTP 404, under
  a namespace nobody owns — shipped in `inst/extdata/column_dictionary.csv`'s
  one annotated row. They were recognisably placeholders, which is the problem:
  `REVIEW:` is the package's marker for an unfinished IRI and strict validation
  rejects it, while a plausible-looking `w3id.org` IRI passed every offline
  check. `term_iri` is now the released `gcdfo:SpawnerAbundance` (an
  `owl:Class` in gcdfo 0.0.9, so `term_type` moves from `skos_concept` to
  `owl_class`), and `constraint_iri` is the released `smn:NaturalOrigin`
  concept ("born and reared in the wild", broader `smn:SalmonOrigin`) — the
  wild-origin filter the placeholder faked. `property_iri` stays
  `smn:Abundance`: which of `smn:Abundance` / `gcdfo:SpawnerAbundance` belongs
  in the property slot is open question Q9, and this fix deliberately does not
  prejudge it — the term slot holding the most specific released variable
  concept is defensible under either answer. A network-gated test now asserts
  every IRI in the shipped example metadata resolves.

* **Both shipped examples are now round-tripped through
  `validate_salmon_datapackage()` by the test suite** (backlog #100), the gate
  whose absence let #95, #96, and #98 ship invisibly. The 30-row example must
  pass **both** modes — its last strict blocker, a blank
  `tables.csv$observation_unit_iri`, is filled with the released
  `smn:EscapementEstimate` (the IRI for the `EscapementEstimate` observation
  unit the row already declared; resolves 200) — and the 173-row starter must
  pass lenient and fail strict with *exactly* its one documented failure
  (`Measurement columns require term_iri; missing in rows 8.`), so drift in
  either direction is caught. The shipped `codes.csv` was also repaired in
  passing: it declared 9 header columns while every data row carried 8 fields,
  so each read emitted 26 readr parsing problems; a well-formedness test now
  covers every shipped example CSV.

* **`detect_semantic_term_gaps()` now sees the targets retrieval found nothing
  for** (backlog #97). Both entry paths short-circuited on an empty suggestions
  table, so a concept absent from every vocabulary — the strongest possible
  term-gap evidence, and precisely the case the term-request pipeline exists
  for — produced *zero* gaps and a console message that read like a clean
  result. A gap was detectable only when retrieval found *something* and it
  was judged insufficient. `suggest_semantics()` now attaches its discovered
  targets as a `semantic_targets` attribute (additive; the existing
  `semantic_suggestions` / `semantic_llm_assessments` contract is unchanged),
  and `detect_semantic_term_gaps()` reports any target with no retrieval
  evidence at all as `gap_detection_basis = "no_candidates"` — distinguishing
  "nothing found" from "found and rejected" (`llm_request_new_term`). The
  check runs before `min_score` filtering, so a below-threshold candidate
  still counts as "found"; the explicit-`suggestions` path keeps its
  historical row-in/row-out behaviour; the 33-column gap row contract is
  unchanged.

* **Semantic ranking now puts `smn` above `gcdfo`, which is what the ontology
  preferences always said it did.** (Brett, 2026-08-17.) `smn` is the shared,
  reviewed salmon namespace and `gcdfo` is the DFO fallback:
  `inst/extdata/ontology-preferences.csv` ranks `smn` priority 1 and `gcdfo` 2
  where it lists `gcdfo` at all, and omits it entirely for `variable`,
  `property`, `constraint` and `statistical_modifier`. But
  `.ranking_profile_defaults()` disagreed with that file. Its `role_boost` gave
  `gcdfo` **1.3** against `smn`'s 1.7 for `variable`, `entity` and `method`, and
  the base weights added only 0.1 more, so the entire preference came to a
  **0.5** margin — while the routine per-candidate bonuses any candidate can
  earn reach **0.6** on their own (0.2 label overlap plus 0.4 cross-source label
  agreement across three sources). A `gcdfo` term that merely matched the query
  text therefore outranked the reviewed `smn` term, and the preference was
  decided by whichever candidate happened to collect bonuses rather than by the
  declared source authority. `gcdfo` is now a flat **1.0** in every role and the
  base weights are `smn` 1.2 / `gcdfo` 1.0, restoring a margin of 0.5–0.7 that
  the bonus stack does not overturn. **This changes ranking order**: where an
  `smn` and a `gcdfo` candidate previously came back with `gcdfo` first, `smn`
  now leads, and `suggest_semantics()` / `infer_dictionary()` top-1 picks can
  change accordingly. The measured differential against metasalmonpy — six
  tie-heavy candidates under four input permutations — now returns the same
  order *and the same scores* on both sides (`smn` 2.75, `gcdfo` 2.65); the
  ordering half of `knowledge/parity-deviations.md` row 32 was an R defect, not
  a Python gap. Pinned by `tests/testthat/test-smn-outranks-gcdfo.R`.

* **The statistical-modifier role reaches the ranking layer.** Two 0.3.0
  leftovers, the same class as the role-hint gap that release already fixed:
  `inst/extdata/ontology-preferences.csv` had no `statistical_modifier` row
  at all, so the new role ranked with no source preferences; and the bundle
  review prompt still told the model to judge "variable, property, entity,
  unit, constraint, and method together", naming a slot the dictionary no
  longer has while omitting the one it gained. The `method` preference rows
  are correct and stay — that role survives for code values.

* **`statistical_modifier` reached ranking with no source preference at all.**
  The role has had `inst/extdata/ontology-preferences.csv` rows since 0.3.0
  (`smn` priority 1, then I-ADOPT and STATO) and `sources_for_role()` serves it
  from `smn` and `ols`, but `.ranking_profile_defaults()$role_boost` had no
  `statistical_modifier` entry, so the role was scored on base weight alone —
  the sixth surface of the role contract, silently absent exactly as
  `AGENTS.md` warns [corrected 2026-08-24: the **seventh** surface — this
  entry inherited the off-by-one from the in-code comment, now fixed]. It now carries `smn = 1.5, ols = 0.4`, and a new guard
  fails if any role with ranking preferences lacks a `role_boost` entry.

* **SDP-extension IRI validation no longer accepts Unicode whitespace, and one
  predicate now owns the check.** `.ms_sdp_extension_is_absolute_iri()` — the
  validator behind observation structures, KNB publication and reproducibility
  manifests — applied `perl = TRUE` to `[^[:space:]]`, and PCRE's
  `[[:space:]]` is ASCII-only where R's default TRE engine resolves it against
  Unicode. So it *accepted* an IRI containing U+3000 IDEOGRAPHIC SPACE or
  U+1680 OGHAM SPACE MARK while `write_eml()` and `validate_sdp_sssom()`
  rejected the same string: a package could clear extension validation and then
  fail EML export on a character invisible in a diff. RFC 3987 requires those
  characters to be percent-encoded, so the permissive answer was the wrong one;
  dropping `perl = TRUE` makes this validator stricter and aligns all three.
  **Observable change:** an `iri` field containing non-ASCII whitespace that
  previously validated is now rejected. The shape is now defined once, in
  `R/iri-predicates.R`, and called by the SDP-extension, EML and SSSOM
  validators — four near-copies of one regex is how they came to disagree. EML
  and SSSOM behaviour is unchanged; they already ran under TRE. The
  measurement-decomposition validator deliberately keeps its own narrower,
  ASCII-classed pattern, mirrored character-for-character in metasalmonpy.
  Backlog #85; see the parity-deviations register, row 28.

* `migrate_sdp_methods(dry_run = TRUE)` previews the undeclared-table stop.
  The check sat after the dry-run early return, so a clean preview promised a
  migration the real run then refused. Nothing could be corrupted — the
  rewrite is atomic — but the preview was not honest about the outcome.

* **`validate_sdp_reproducibility_manifest()` accepts a manifest written by
  metasalmonpy, and the accepted writer set now has one owner.** The
  honest-provenance ruling reached this artifact's *writer* and not its
  reader: the validator still demanded
  `generated_by = "metasalmon::write_sdp_reproducibility_manifest"`, so a
  `reproducibility/manifest.json` written by the Python mirror was rejected
  outright — and because `publish_sdp_to_knb()` validates the manifest while
  planning, that also blocked KNB publication of any Python-written SDP, not
  just direct validation. **Observable change:** a manifest carrying
  `metasalmonpy.write_sdp_reproducibility_manifest` + `metasalmonpy_version`
  now validates; for the same declared artifact set the two implementations'
  manifests differ in nothing else, verified by driving both writers over the
  same tree. Two smaller behaviour changes come with it: a
  `metasalmon_version` that is whitespace-only, or not a string at all, is now
  rejected rather than accepted, which is what the decomposition validator and
  one Python reader already did. *(Correction, 2026-08-24: this entry shipped
  saying "both Python readers". The 0.4.0 parity audit measured it — only one
  refused a non-string version, and metasalmonpy's other reader was fixed to
  match in its own 0.4.0. The claim was true of the behaviour and wrong about
  how widely it already held.)*

  The ruling had been applied one artifact at a time, re-typing the same pair
  of writer strings each time — SSSOM in PR #43, decompositions in PR #44, and
  this one missed — so the set now lives once in `R/provenance.R` and all
  three validators resolve their accepted writers through it. A structural
  guard (`tests/testthat/test-provenance.R`) fails if any manifest validator
  re-types a writer literal, which is the part that let a fourth manifest type
  repeat the omission. Backlog #88; see the parity-deviations register, row 29.

* `validate_sdp_measurement_decompositions()` accepts a manifest written by
  metasalmonpy, exactly as `validate_sdp_sssom()` now does — the mirror
  writes byte-identical decomposition CSVs and honestly names itself in the
  provenance block. Unknown generators and missing versions stay rejected.
  See the parity-deviations register, row 12.

* `validate_sdp_sssom()` accepts a manifest written by metasalmonpy
  (`generated_by = "metasalmonpy.write_sdp_sssom"` with
  `metasalmonpy_version`). The mirror writes byte-identical mapping-set
  artifacts and honestly names itself in the provenance block; rejecting
  that provenance made every Python-written SDP fail R validation for no
  data reason. Unknown generators, and known generators missing their
  version, stay rejected. See the parity-deviations register, row 11.

### Documentation

* Two new vignettes, roadmap stream S11 slice 2. **Migrating to SDP 0.3.0**
  (`vignettes/migrating-to-sdp-0-3-0.Rmd`) is the user-facing guide to the
  0.3.0 breaking change that until now existed only as a NEWS entry: why a
  method is not part of what a value *is*, the three exact placements with a
  worked example of each, the new `statistical_modifier_iri` slot and when it
  applies, a complete offline `migrate_sdp_methods()` walkthrough, every
  stop-and-report case with how to resolve it, and where each column of the
  removed `metadata/methods.csv` registry now belongs. **Tidy Data for Salmon
  Data Packages** (`vignettes/tidy-data-for-sdp.Rmd`) documents the 0.2.6
  enforcement: declared-primary-key uniqueness, the value-like column-name
  warning and the heuristic behind it, and the `tidyr::pivot_longer()`
  reshape, with the validator's actual messages.

* Vignette corrections found auditing the set against 0.3.0. The quickstart
  and the FAQ both still named a dictionary *method* slot that 0.3.0 removed,
  and the quickstart's "never auto-filled" claim was also wrong on the
  deterministic path, where a constraint or statistical modifier is applied
  when the column text carries the evidence. The publication guide listed a
  blank `observation_unit_iri` as an EDH rebuild refusal (only a `REVIEW:`
  value is) and listed "methods" in the closed KNB inventory (the artifact is
  gone; a package carrying one is refused). The vocabulary guide's `property`
  source row omitted QUDT, and the glossary's quick-reference row still named
  four I-ADOPT components instead of five.

metasalmon 0.3.0
----------------

Roadmap S8, second half: the sdp-0.3.0 method placement model. A method
describes how a value was produced; it was never part of what the value *is*,
and the old placements let the two blur. This release implements the spec that
separates them.

### Breaking changes

- **`column_dictionary.csv` loses `method_iri` and gains
  `statistical_modifier_iri`.** A statistical modifier (I-ADOPT
  `StatisticalModifier`) is part of variable identity — a *mean* weight and a
  *maximum* weight are different variables — so it belongs in the dictionary.
  A method never was: a procedure shared by a whole table now lives in
  `tables.csv` `method_iri`, protocols are cited through `protocol_iri` /
  `protocol_citation` on `tables.csv` and `dataset.csv`, and a method that
  varies row by row lives in the data as a code column resolving through
  `codes.csv` `term_iri` to shared-vocabulary procedures.

- **The `metadata/methods.csv` registry is gone**, and
  `write_sdp_methods()`, `read_sdp_methods()`, and `validate_sdp_methods()`
  are removed with it. Method labels and descriptions belong in the shared
  vocabulary, not in per-package registries that restate it. Every surface
  that consumed the registry — observation-structure validation, EML method
  steps, KNB publication — now reads the new placements, and a package still
  carrying a `methods.csv` gets an error pointing at the migration.

- **`migrate_sdp_methods()` migrates sdp-0.2.0 packages.** It relocates what
  can be relocated mechanically and **stops and reports** on anything needing
  a judgement call: columns of one table bound to different methods stop the
  migration (you decide whether to split the table, cite a protocol, or move
  the method into the data); unresolved `REVIEW:` bindings are dropped and
  reported; registry labels are reported toward the shared vocabulary. The
  rewrite is atomic — on any stop, nothing on disk changes. Descriptor-only
  packages are handled too: the legacy `iAdopt:methodIri` custom key is read
  by the migration (and only by the migration).

- **The semantic pipeline reviews a statistical-modifier slot instead of a
  method slot.** Measurement bundles carry variable, property, entity, unit,
  constraint, and statistical modifier; a statistical-modifier target is
  emitted only when the column text names an aggregation (mean, maximum,
  total, peak), so plain measurements do not gain review volume. The
  code-level method role survives — codes still resolve to shared
  `sosa:Procedure` concepts — and `sources_for_role("statistical_modifier")`
  searches SMN and OLS. Measurement decompositions drop the `method`
  component role for the same reason the dictionary did: a decomposition row
  binds one variable's identity, and a row-varying procedure would pin an
  arbitrary one.

- **EML method steps now come from the placements.** Table-level method and
  protocol fields and dataset-level protocol fields each emit a method step,
  and row-varying procedures actually used by the data are listed from their
  code resolutions. The `write_eml_from_sdp()` return value's `methods` is
  now the placements tibble and `used_methods` the used-procedure IRIs.
  Every vocabulary IRI the method path emits stays inside the reviewed
  closure: a table-level `method_iri` needs an accepted semantic-review
  ledger row, and table-level and used row-varying procedure IRIs must
  appear in the vocabulary snapshot. Protocol IRIs are citations, not
  vocabulary terms, and are not gated.

### Fixed

- **The statistical-modifier slot can actually be filled from smn.** The
  role-hint vocabulary never learned the new role, so every genuine modifier
  concept — they live in smn's controlled-vocabularies module — reached
  review carrying only a `constraint` hint, and the deterministic role-type
  validator downgraded 100% of correct accepts to `review`. Both hint
  builders now emit `statistical_modifier`, `sources_for_role()`'s companion
  index filter gained the matching case (it previously fell through to "keep
  the whole ontology"), and a new `SEM_MODIFIER_EVIDENCE_REQUIRED` validator
  holds an accept to the same aggregation evidence the suggestion path
  requires.

- **A table or dataset method/protocol placement that is not an absolute IRI
  is now reported.** Moving methods onto `tables.csv` and `dataset.csv` meant
  those fields needed the IRI-shape check the dictionary columns already had:
  the Frictionless schema accepts any string, and the validator that does
  check IRI shape only runs when the optional observation-structure sidecars
  exist. A table could therefore claim `methods/weir-count` and validate with
  zero issues.

- `migrate_sdp_methods()` hardening found in review: two carriers disagreeing
  about one column's method now stop the migration instead of the dictionary
  silently winning and the descriptor's IRI being erased; bindings that name
  an undeclared table, or that carry no table/column, stop before any write
  rather than reporting a placement that lands nowhere; `dry_run` rejects
  non-logical input (`isTRUE(1)` is `FALSE`, so a truthy non-logical would
  have taken the destructive branch).

- A failed rollback inside the shared atomic writer no longer deletes the
  backup holding the original bytes, and the warning now names that file.

- The bundled `column_dictionary.csv` template had unquoted commas in two
  descriptions, so every field after them shifted and the rows parsed into
  schema-invalid `column_role`/`value_type` values. Pre-existing since the
  template was added; the descriptions are now quoted.

- The default remote SDP schema source is pinned to the spec release tag the
  package implements (now `sdp-0.3.0`) instead of the upstream `main` branch,
  so an upstream spec release can no longer break networked schema loads.
  The `metasalmon.sdp_schema_base_url` option still overrides it.

metasalmon 0.2.6
----------------

Roadmap S8, first half: the tidy-data foundations the method placement model
depends on.

### New

- `validate_salmon_datapackage()` checks that a declared `primary_key` actually
  identifies a row. The field was declared in `tables.csv` and read by nothing
  that tested it, so a table could claim a key and ship duplicates — the tidy
  principle "each observation forms a row" going unverified. Now an error.

- Column names that look like data values are reported. Bare year-like names, or
  a shared stem with numeric suffixes, across three or more columns. A
  **warning, never an error**: the SDP may accept untidy data, it should simply
  stop implying it checked. The message points at `tidyr::pivot_longer()`.

- Unresolved `MISSING METADATA:` placeholders are surfaced in the default
  validation mode. They were already errors under `require_iris = TRUE`; an
  ordinary call returned zero issues and said nothing, so a package could look
  clean while stating in its own metadata that its metadata was missing.

metasalmon 0.2.5
----------------

### Fixes

- Credential redaction covers qualified token names. The pattern named
  `dataone_token` specifically, so the production credential was redacted and
  `dataone_test_token` was not — the worst possible split, since staging is the
  credential a first-time user is most likely to paste into a script. Captured
  HTTP and provider errors are stored in returned tibbles and written to CSV, so
  this leaked at rest, not only on screen. The rule is now structural — any
  qualified `*_token` name — so a credential introduced later is covered without
  another patch. `token` must be the final name segment, so token-count fields in
  provider diagnostics (`max_token_count`, `total_tokens`) are left intact — they
  carry the numbers needed to correct a rejected request.

### Internal

- The second redaction implementation is deleted. `.ms_knb_redact()` and
  `.ms_redact_secrets()` were two implementations of one security contract, and
  only one was extended when the pattern last changed — which is exactly how the
  gap above arose. KNB messages now redact through the shared function, which is
  strictly stronger: it also catches `x-api-key`, provider API keys, and
  serialized JSON credential forms that the deleted version missed.

metasalmon 0.2.4
----------------

### Breaking changes

- **The canonical CSV missing-value contract is now a single token: an empty
  field.** Data resources were written with readr's default `na = "NA"` while
  metadata used `na = ""`, and everything was read with `na = c("", "NA")`.
  `"NA"` is a real fisheries gear code, so a literal `"NA"` and a genuinely
  missing value produced **identical bytes** — the distinction was destroyed at
  write time, where no reader could recover it. Both sides now use `""`.

  What changes for you: a literal `"NA"`, `"N/A"`, or `"null"` in a data column
  now round-trips as the string it is. If you have a **hand-authored** package
  whose CSVs use the two characters `NA` to mean missing, those cells now read
  as the literal string `"NA"`; rewrite them as empty fields.

  Consequence worth knowing: because no non-empty token parses as missing any
  more, EML `missing_values` codes are only meaningful for tokens the reader
  treats as missing, and the canonical writer emits none. EML now represents
  absence directly rather than through a code that collided with real data. The
  guard that rejects an undeclared non-empty missing token is retained as an
  invariant and is unreachable through the canonical writer.

### Fixes

- `ms_setup_github()` no longer defaults `repo` to a specific private dataset
  repository. Nothing about the function is dataset-specific — it finds git,
  creates or locates a PAT, and stores it — but the default meant a user
  calling `ms_setup_github()` with no arguments had their setup "verified"
  against a repository they could not read, so a perfectly good token was
  reported as broken. `repo` is now optional: supply it to additionally verify
  access, omit it to just set up the PAT.

### Internal

- Three examples now run: `apply_salmon_dictionary()`, `validate_dictionary()`,
  and `suggest_dwc_mappings()` were wrapped in `\dontrun{}` despite executing
  offline in under a second. Running them immediately caught two real defects
  that `\dontrun{}` had been hiding — one used `%>%`, which examples do not
  have attached, and another wrote a package directory into the working
  directory because it omitted `path`. `check_for_updates()` and
  `validate_salmon_datapackage()` moved to `\donttest{}` (network, and ~6s
  respectively).

  The roadmap estimated ~15 such examples; measuring each one offline showed
  only 5 actually run, because most `\dontrun{}` blocks are illustrative
  sketches using `path/to/package` placeholders rather than runnable code held
  back by caution. Making those real is a larger job than un-wrapping.

- The GitHub read-helper tests point at metasalmon's own public repository
  instead of a private one, so they exercise `read_github_csv()` and
  `read_github_csv_dir()` everywhere including CI rather than skipping with a
  404. The `METASALMON_GITHUB_TEST_*` environment variables still redirect them
  at a private repository when testing those permissions specifically.

- CI runs the suite under a non-C ambient collation (`LANG`/`LC_ALL` =
  `en_US.UTF-8`, with `fr_FR.UTF-8` also generated for `LC_TIME`). The
  differential guards on the byte-reproducibility contract compare an ordering
  against a contrasting locale and skip when none exists, so on a default
  C/POSIX runner they had been passing vacuously — the guards protecting the
  package's canonical bytes gave no CI signal. They now execute, and the whole
  suite passes under a locale that collates differently, which is the first
  actual evidence for the locale-independence claim rather than an assumption.
  CI skips drop from 9 to 6.

- CI now installs `{dataone}`, `{datapack}`, and `{XML}`, and a guard fails the
  build if any optional package the suite needs is missing. `R-CMD-check.yaml`
  installed only `devtools` and `rcmdcheck`, so five tests of the DataONE
  adapter boundary — the code that talks to the repository during live
  publication — skipped silently on every machine including CI and had never
  executed. They pass. The distinction the guard encodes: locally a missing
  optional package is an environment fact and skipping is correct; in CI it is a
  workflow regression and must fail.

metasalmon 0.2.3
----------------

Roadmap step 4: publication ergonomics and provider robustness.

### New

- `publish_sdp_to_knb()` gains `overwrite`. A dry run could not be re-planned
  after correcting an input: three separate gates — the SDP archive writer, the
  plan-mismatch check, and the resource-map ownership check — each treated an
  existing artifact as a published one, and none of the messages said that a
  manual `unlink()` was the only way forward. `overwrite = TRUE` now rebuilds
  derived artifacts and replaces a manifest and resource map left by an
  *unpublished dry run*. Anything that reached the network is unaffected: a
  manifest whose status is not `dry_run` still requires a reviewed revision,
  because its DataONE PIDs are immutable, and live publication is still gated by
  `confirm`.

### Fixes

- The default LLM providers now retry. `.ms_llm_retry_limit()` returned 1
  attempt for everything except two special-cased models, so
  `attempt >= attempts` was true on the first pass and the retryable-error
  classifier was never consulted — a 429 or a 503 failed the whole review on the
  first try, after the user had already paid for every preceding request.
  `Retry-After` is now honoured in both its delta-seconds and HTTP-date forms
  and capped at 60s, with jittered exponential backoff otherwise so a batch that
  hits one rate limit does not retry in lockstep.

- The BioPortal API key travels in an `Authorization` header instead of the
  query string, where it was written into request logs at both ends and printed
  verbatim by the timeout warning. URLs are additionally redacted before being
  displayed or recorded.

metasalmon 0.2.2
----------------

Roadmap step 2: the semantic pipeline at real scale.

### Fixes

- The term-search index caches now actually prevent work. `.smn_term_index()`
  and `.gcdfo_term_index()` checked their cache stamp *after* fetching and
  parsing, so every `find_terms()` call paid 11 conditional GETs and a full
  reparse of every SMN Turtle module before discovering nothing had changed —
  projected at roughly 8 CPU-hours for a 5-table x 200-column package. An index
  is now resolved once per session. The trade is deliberate: a module updated
  upstream mid-session is not picked up until `refresh = TRUE`, matching the
  decision already taken for the schema bundle, and it is the stronger guarantee
  for seeding, where two columns in one package must not be seeded against two
  different ontology versions.

- `METASALMON_CACHE` is read at call time. As a top-level binding it was
  evaluated when the namespace was built, so an installed package captured the
  build machine's environment and the result cache could never be enabled by a
  user — only `pkgload::load_all()` ever saw the developer's own setting.

- A failed vocabulary lookup is no longer indistinguishable from a successful
  empty one. `.safe_json()` returned `NULL` for both, every caller collapsed
  that into an empty result, and the diagnostic recorded
  `status = "success", count = 0` — so a degraded OLS or BioPortal looked
  exactly like "no such term exists", which is the input that drives
  `request_new_term` escalation. An outage could therefore manufacture ontology
  gaps. Failures are now signalled, recorded per source in the `diagnostics`
  attribute as `status = "http_error"`, and surfaced as a warning; a degraded
  lookup is never written to the result cache.

metasalmon 0.2.1
----------------

Closes the last two P1 items whose fixes change written artifacts, so they ship
ahead of the larger roadmap steps.

### Fixes

- Semantic ranking is now reproducible across locales. Score ties broke on
  character keys (`source`, `ontology`, `label`, `iri`), and with
  `seed_semantics = TRUE` the top-1 pick becomes a written IRI in
  `column_dictionary.csv` — so the same input seeded differently on macOS and in
  a C-locale container. All nine ordering sites in `R/semantics-helpers.R` and
  `R/term_search.R` now use explicit C collation, and seven functions are
  registered in the collation guard. This was the last locale-dependence in the
  package. Note that `.apply_embedding_rerank()` also selected its rerank set
  with `order(-score)` alone, so *which* rows were reranked depended on input
  order; it now tie-breaks on `label`.

- Per-resource schema URLs in `datapackage.json` are derived from the loaded
  SDP bundle rather than composed from a hardcoded constant. Every URI in a
  written descriptor — profile, rules, and per-resource schemas — now comes from
  one validated bundle. The constant remains as the fallback for a bundle that
  predates the v0.2 extension resources.

metasalmon 0.2.0
----------------

Remediates the nine highest-priority defects from the 2026-08-10 ecosystem
review (`knowledge/plans/2026-08-10-comprehensive-ecosystem-review.md`).

### Breaking changes

- `read_salmon_datapackage()` now types data resources from the column
  dictionary's `value_type` instead of letting readr guess, and **columns the
  dictionary does not declare are read as character rather than guessed**. The
  dictionary is the sole type authority, which is what makes the write/read
  round trip lossless. A value that does not satisfy its declared type is kept
  as its raw token rather than silently becoming `NA`, and the mismatch is
  reported as a structured validation issue. Declared columns are collected as
  text and converted only when the conversion is faithful, judged against the
  original token — so an unparseable value, a fractional `integer`, an
  `integer` or `number` whose precision or magnitude a double cannot hold, and a
  `datetime` finer than a `POSIXct` can represent at that instant all keep their
  exact token rather than being silently accepted, rounded, clamped, or
  truncated. Both numeric and datetime checks are magnitude-aware rather than
  fixed thresholds.
  Both `integer` and `number` otherwise read as double, because
  `readr::col_integer()` silently `NA`s values past 2^31 (readr's guesser also
  produced double here, so this is not a change); `apply_salmon_dictionary()`
  remains the way to get exact R classes.
- `write_salmon_datapackage(overwrite = TRUE)` no longer empties the package
  directory. It replaces only the files it owns — the `metadata/` SDP CSVs, the
  `data/` resources declared in `tables.csv`, `datapackage.json`, and the
  ownership sentinel — and preserves everything else. Pass the new
  `prune = TRUE` to restore the previous behaviour. `create_sdp()` gained the
  same argument.
- Newly written `datapackage.json` files declare the current SDP profile URI
  (`salmon-data-mobilization.github.io`), which is what the live upstream
  profile requires. Reading packages that declare the previous URI is
  unaffected.
- `Imports: dplyr (>= 1.1.0)`, required by `arrange(.locale = )`.

### Fixes

- **`zip` is no longer pinned to an exact version, at either layer.**
  `zip (== 3.0.1)` against a CRAN that ships 3.0.2 made metasalmon
  uninstallable. Relaxing only `DESCRIPTION` was not enough: the runtime guard
  `.ms_knb_require_zip_version()` was an equally exact check, so the package
  would install and then abort on every KNB publication path. That guard is now
  a reviewed-version allowlist, `c("3.0.1", "3.0.2")`. Both versions were
  byte-compared for metasalmon's exact `zip::zip()` call against a fixture
  covering nested paths, non-ASCII filenames, an empty file, incompressible
  bytes, and highly compressible bytes; the archives are identical. The
  determinism contract therefore still holds, and it is enforced where it
  belongs — at the KNB boundary, not in a dependency pin that blocked the
  majority of users who never publish to KNB. An unreviewed `zip` still fails
  loudly, with a message saying to byte-compare before widening the allowlist.
- **Remote SDP schema loading works again.** Upstream `smn-data-pkg` migrated
  every profile `$id`; metasalmon asserted equality against the old constant, so
  `source = "remote"` aborted and the default `"auto"` silently fell back to a
  stale vendored bundle. Identity is now derived from the loaded bundle and only
  checked for internal consistency, so an upstream identifier change is
  followable rather than fatal. The vendored profile and rules were re-vendored.
- **A multi-table dictionary is no longer applied in full.**
  `apply_salmon_dictionary()` compared a column against a same-named local, which
  the dplyr data mask shadows into a tautology, so every table's renames,
  coercions, and factor levels were applied while the warning said otherwise.
  `write_salmon_datapackage()` had the same bug for `dataset_id`, leaking other
  datasets' columns into `datapackage.json`.
- **`create_sdp()` no longer writes packages its own validator rejects.**
  Character code values such as `"0.10"` and `"100000"` were re-guessed as
  numeric on read and stringified back as `0.1` and `1e+05`, so a package failed
  validation against its own `codes.csv`. `write_eml_from_sdp()` inherited it.
- **Reviewed sidecars survive a rewrite.** The read → edit → write loop silently
  deleted reviewed SSSOM mapping sets, ordered measurement decompositions, EML
  and EDH XML, `eml-mapping.yml`, review notes, and `publication/` artifacts.
- **External text can no longer be evaluated as a cli message template.** A
  provider error containing `{Sys.getenv("OPENAI_API_KEY")}` printed the key, and
  an unbalanced brace — a column literally named `rate{pct` — replaced the
  intended message with `Error: Expecting '}'`. Fifteen sites now escape, and
  credentials are redacted where external text is captured rather than where it
  is displayed.
- **Canonical bytes and identifiers no longer depend on `LC_COLLATE`.** The
  DataONE resource-map PID, the plan fingerprint, SSSOM canonical bytes and
  manifest order, the measurement-decomposition hash, EML entity order, and both
  exported NuSEDS crosswalk tables all used locale-dependent ordering, so the
  same inputs produced different bytes on different machines and a package
  written on macOS could be rejected by a `LC_COLLATE=C` container.
- **Cancelling a term-request prompt no longer submits the issue.**
  `askYesNo()` returns `NA` on cancel and the guard tested `isFALSE()`. In the
  same workflow, exiting the routing menu aborted with "replacement has length
  zero", and the candidate/rationale lines passed cli markup to `glue::glue()`,
  which fails to parse on every input — so interactive routing had never worked.
- `infer_value_type()` now distinguishes `datetime` from `date`; `POSIXt`
  previously collapsed to `date`.

### Also in this release (from the 0.1.8 merge)

- The C-collation contract is applied to the SDP v0.2 extension normalizers
  introduced in 0.1.8. `.ms_sdp_methods_normalize()` and the two
  `.ms_sdp_observation_normalize_*()` functions produce the canonical row order
  written to `metadata/methods.csv` and `metadata/structure/observation_*.csv`,
  and `extract_sdp_observations()` orders returned data by dimension columns —
  all previously with bare `dplyr::arrange()`.

### Internal

- `write_salmon_datapackage()` refuses to update a package whose managed
  directories are reached through a symbolic link. `file.exists()` follows
  links, so a `data/` or `metadata/` replaced by one would have made every
  managed child resolve outside the package and be deleted there. This matches
  the symlink discipline the KNB archive already enforces.
- `create_sdp()` replaces its own outputs rather than writing through them. A
  hard-linked `README-review.txt`, `semantic_suggestions.csv`, or EDH XML would
  otherwise have truncated the shared inode outside the package —
  `Sys.readlink()` sees only symbolic links, and the pre-0.2.0 full-directory
  wipe had unlinked these entries implicitly.
- Provider failures on the measurement-bundle review path are redacted where
  they are captured, matching the non-bundle path. They are stored on the
  exported `semantic_llm_assessments` attribute, so display-time redaction
  would have been too late.
- Text reaching cli through the `.ms_*_abort()` forwarding helpers is escaped
  too. A decomposition column name is caller-supplied and was interpolated into
  an abort message, so a column named `{Sys.getenv("...")}` had its value
  evaluated into the error.
- New `R/cli-safety.R` (`.ms_cli_escape()`, `.ms_cli_bullets()`,
  `.ms_redact_secrets()`, `.ms_abort_external()`).
- Two static guard tests enforce the new contracts: `test-cli-safety-guard.R`
  and `test-collation-guard.R`. Both carry self-tests, and both are documented
  in `AGENTS.md`, which is now tracked in git — it had been ignored, so the
  shipped repo carried no contributor guidance at all.
- A live remote-schema test closes the gap that let the profile drift go
  unnoticed: the suite pins `sdp_schema_source = "vendored"`, and nothing had
  ever exercised a successful remote fetch.

metasalmon 0.1.8
----------------

- Added exact-schema, atomic, symlink-safe readers and writers for the optional
  SDP `metadata/methods.csv` SOSA procedure registry and paired
  `metadata/structure/observation_*.csv` resources. Validation now enforces
  complete one-structure-per-measure coverage, required dimension grain,
  typed repeated-value invariance, static and row-varying procedure resolution,
  canonical descriptor inventory, and remains unchanged when the extension is
  absent. Multi-file writes stage and validate the CSV/descriptor set as one
  rollback-capable transaction. Extension, reproducibility, and KNB APIs also
  reject direct or trailing-slash package-root symlinks without rejecting
  harmless platform aliases in ancestor paths.
- Added `extract_sdp_observations()` to produce one deterministic normalized
  table per declared measure-specific observation structure without claiming
  RDF Data Cube conformance.
- `apply_semantic_suggestions(strategy = "reviewed")` now applies explicit
  accepted review decisions and preserves multiple constraints for one
  measurement as a deterministic, deduplicated, semicolon-separated
  `constraint_iri`. The LLM-reviewed strategy has the same multiple-constraint
  behavior; lexical `"top"` and all non-constraint roles remain single-winner.
- Added a deterministic, checksum-bound `reproducibility/manifest.json` API for
  the optional reviewed-selection, workflow, provenance, and source sidecars.
  Validation is closed over the exact directory contents and rejects symlinks,
  undeclared files, missing files, and checksum or byte-size drift.
- `publish_sdp_to_knb(representation = "expanded")` now deposits the closed SDP
  inventory as individually named objects with package-relative ORE locations,
  instead of a ZIP. It includes validated SSSOM, decomposition, methods,
  observation-structure, and reproducibility artifacts and can reconstruct the
  exact SDP hierarchy without publishing unrelated files. Archive mode remains
  available for compatibility.
- EML export now documents procedures actually used by observed measurements as
  method steps, including method/protocol IRIs, versions, descriptions, and
  citations; unused registry alternatives are not asserted as performed. The
  reviewed semantic-selection ledger defaults to the extended
  `reproducibility/` layout while retaining the legacy root path for existing
  reviewed packages.
- Updated generated SDP descriptors and the vendored profile/rules/schema bundle
  to the byte-verified canonical
  `salmon-data-mobilization.github.io/smn-data-pkg` publication URLs.
- Corrected the bundled demo dictionaries so organism counts use QUDT
  `Individual` as their unit, use the released Salmon Domain Ontology
  `smn:Abundance` characteristic as their property, and no longer assert the
  nonexistent QUDT `NumberOfOrganisms` property.
- Fixed semantic candidate ranking for legitimate provider results whose
  optional `match_type` is missing; they now receive the configured unclassified
  score instead of aborting `suggest_semantics()`.
- Extended the reviewed QUDT-to-EML unit crosswalk so both HTTP and HTTPS forms
  of QUDT `Individual` (`INDIV`) serialize as the EML standard unit `number`.
- Made reproducibility-manifest ordering byte-stable across process locales,
  including artifact names that mix punctuation such as hyphens and
  underscores.
- Made exact KNB plans, ORE identifiers, access-policy normalization, and
  catalog-verification evidence locale-stable. Expanded SDP artifact paths now
  use the same radix ordering as their reproducibility and execution receipts.

metasalmon 0.1.7
----------------

- Corrected the KNB package representation. New plans now upload each original
  SDP data resource, one friendly deterministic ZIP containing the complete
  canonical Salmon Data Package, one EML 2.2.0 metadata object that describes
  both representations, and one OAI-ORE resource map. Internal SDP CSV, JSON,
  SSSOM, and measurement-decomposition files no longer appear as unnamed KNB
  objects.
- Added immutable KNB revision planning through `revision_manifest`. A revised
  sidecar supplies a new `publication.revision_key`; metasalmon preserves the
  metadata series, reuses unchanged data objects, and verifies DataONE
  `obsoletes`/`obsoletedBy` links for the new EML and resource-map versions.
  Dry runs reject a reused key before any network call, and legacy verified
  schema-v2 manifests can be migrated into the archive-based schema-v3 plan.
- EML download URLs now use the KNB Member Node endpoint and preserve literal
  `urn:uuid:` colons, matching MetacatUI's object-association behavior while
  Coordinating Node synchronization is delayed.
- KNB planning now rejects referenced vocabulary rows whose `source` or
  `ontology` label marks them as review candidates. This offline gate does not
  resolve IRIs or prove release governance; canonical transformation records
  must separately pin and verify the approved vocabulary release.
- Extended `write_eml_from_sdp()` with validated `otherEntity` supplements and
  deterministic revision keys. Added a copyable EML sidecar template and
  documented KNB private staging, persistent identifiers, retry states,
  revision semantics, and DOI minting as a separate per-metadata-version KNB
  release action. metasalmon never mints a DOI during deposit.
- Made deterministic ZIP construction fail closed around symlinks, unsafe or
  undeclared paths, changed existing archives, and tampered semantic manifests.
  Archive bytes are bound to the reviewed `zip` 3.0.1 implementation, and
  publication planning rejects any custom EML, manifest, or resource-map path
  that would collide with the deterministic archive. Raw-object identifiers
  also bind the immutable DataONE filename, so renaming unchanged bytes creates
  a new object instead of a late SystemMetadata collision.
  Publication-specific `eml-mapping.yml` authorization and party details stay
  outside the downloadable canonical SDP archive.

- Added reviewed EML 2.2.0 export with deterministic identifiers and bytes,
  strict SDP/sidecar/vocabulary preflight, a closed hashed semantic-review
  ledger, exact raw-CSV missing-value audits, observed numeric/date domain
  checks, pinned source-document provenance, a reviewed QUDT-to-EML unit
  crosswalk, EML schema validation, non-dangling constraints, and conservative
  whole-variable topic/unit semantic annotations. Draft and review sidecars remain
  inspectable but only a final sidecar can be exported.
- Added opt-in KNB/DataONE publication planning and verified upload. Dry runs
  create an immutable exact-object manifest and deterministic OAI-ORE map
  without reading credentials; live calls require explicit redistribution
  confirmation, a server-verified ORCID subject matching the EML metadata
  provider, resumable low-level object creation, authenticated and anonymous
  readback, SystemMetadata/access checks, and coordinating-node catalog
  verification. `public = FALSE` is an explicitly named private-review path,
  but it still creates persistent production objects and verifies anonymous
  denial for both bytes and SystemMetadata for every uploaded member. Private
  completion also requires a complete authenticated catalog graph and zero
  matching PIDs through a separate credential-free catalog query. Reviewed
  SSSOM mapping sets remain inside the named SDP ZIP and retain canonical
  tab-separated serialization.
- Bound DataONE replication policy into the reviewed KNB plan and remote
  SystemMetadata checks. Restricted private-review deposits now explicitly
  request zero peer replicas and reject permissive replication on create or
  resume. Live calls also require a schema-v3 review manifest whose policy and
  fingerprint recompute exactly. Public deposits explicitly retain the
  three-replica preservation policy that was previously inherited from the
  DataONE client default.
- Accepted zero as a valid server-owned DataONE `serialVersion` during KNB
  readback. The field is an `xs:unsignedLong`, and production KNB returns zero
  for newly created objects before a SystemMetadata update.
- Added strict package-native SSSOM 1.1 read/write/validation for reviewed
  concept alignments and version-scoped `sssom:NoTermFound` records. Mapping
  sets are deterministic and manifest-bound; undeclared files, literal
  assignments, decomposition columns, contradictory gap/mapping rows, and
  checksum drift are rejected before KNB planning.
- Added a catalog-neutral, manifest-bound SDP measurement-decomposition
  artifact for ordered property, entity, constraint, method, and unit
  components. It preserves repeated components, explicit vocabulary gaps, and
  dimension-to-value relations, validates exact dictionary closure and source
  provenance, and deliberately remains separate from SSSOM mappings and native
  I-ADOPT conformance claims.
- Corrected SDP inference and semantic matching defects found while exercising
  the package on the PSC Fraser Sockeye detailed release: terminal ID
  qualifiers no longer misclassify quality fields, nullable identifiers are
  not made required, profile versions follow the vendored rules, custom HTTP(S)
  rights URLs remain URL licence descriptors, biology-bearing query tokens are
  retained, and SMN term/module role and OWL-class metadata are preserved more
  accurately.

metasalmon 0.1.6
----------------

- Added bundle-aware LLM review for measurement columns. Variable, property,
  entity, unit, constraint, and method candidates are judged together, while
  generic column, code, table, and dataset targets retain their established
  per-target path. Malformed bundle slots fall back independently and a
  provider failure preserves the deterministic shortlist.
- Made explicitly supplied semantic sources a strict allowlist for initial and
  retry retrieval. Omitted sources continue to use role-aware defaults, so
  callers can choose broad role-specific discovery or a deliberately bounded
  source set without retries escaping it.
- Expanded `semantic_llm_assessments` from 28 to 30 columns by appending
  `llm_escalated_from` and `llm_retry_query_rejection_reason`. Legacy rows are
  normalized additively, unresolved shortlist rejection preserves escalation
  provenance, and exact duplicate retry queries are recorded without another
  generation, search, or reassessment call.
- Extended `detect_semantic_term_gaps()` to combine deterministic candidate
  gaps with final LLM `request_new_term` decisions while preserving its
  23-column prefix. Gap rows retain target metadata, detection basis, model
  rationale, proposed-term fields, and escalation origin.
- Added first-class GCDFO term-request routing and repository-specific SMN and
  GCDFO issue bodies. Explicit row overrides take precedence over forced scope,
  recognized namespace evidence, and placement heuristics; rendering remains
  separate from explicit, curator-confirmed submission.
- Added deterministic post-review validators for method and constraint
  evidence, semantic role and ontology type, known property/unit dimensions,
  and curated redundancy. Failed checks downgrade `accept` to `review`, clear
  the selection, preserve model confidence, and never retrieve, substitute, or
  invent terms. Only variable, property, entity, and unit assessments remain
  eligible for automatic `REVIEW:` prefills.
- Added a versioned offline Theme A replay benchmark, pinned ontology
  provenance, raw-to-reviewed checksums, assessment-to-provider interaction
  lineage, recomputed immutable capture/cohort promotion, an exact clean-source
  three-run live gate, and GitHub Actions for replay, the full test suite, and
  `R CMD check`.
- Refactored Theme A evidence tests to reuse one in-process harness and cache
  immutable Git-object hashes instead of launching dozens of R and shell
  subprocesses. Exhaustive publication-integrity mutations run in a separate
  offline, path-filtered workflow. Live benchmark requests now require the
  explicit `--allow-live-api=true` acknowledgement; default local tests and CI
  temporarily blank provider credentials, remain isolated from LLM providers,
  and require no provider key.

- Updated the canonical package site, repository, issue tracker, install
  commands, update checks, OpenRouter attribution, and live SDP schema fetches
  to the `salmon-data-mobilization` organization. SDP 0.2 profile identifiers
  remain unchanged because they are part of the current upstream contract.
- Refreshed the README, vignettes, generated reference pages, and pkgdown site
  to document the 0.1.4/0.1.5 behavior explicitly: context inputs are local file
  paths rather than parsed objects, context never enables LLM review by itself,
  non-UTF-8 text handling and source-label disambiguation are observable, and
  create-time EDH XML is a draft until the metadata is reviewed and rebuilt.

metasalmon 0.1.5
----------------

- `create_sdp(include_edh_xml = TRUE)` now flags the create-time EDH XML as a
  draft: it still writes the file, but warns (and points to
  `write_edh_xml_from_sdp()`) when the package still contains `REVIEW:` IRIs or
  `MISSING` placeholders, so a draft is not mistaken for a reviewed export.
- LLM context files are now decoded more robustly: non-UTF-8 (Latin-1 /
  Windows-1252) text/CSV context files are detected and re-decoded instead of
  being silently corrupted, and two context files that share a base name no
  longer collide in chunk ids or the `llm_context_sources` column.
- `semantic_code_scope = "factor"` code selection now keys on `dataset_id` as
  well as `table_id`/`column_name`, so multi-dataset seed codes can no longer
  cross-match on a shared table/column name.
- Fixed `infer_dictionary()` so LLM semantic-review options supplied while
  `seed_semantics = FALSE` now warn once instead of being silently ignored.
- Semantic LLM review now escalates an unresolvable `reject_shortlist` to
  `request_new_term`: when the model rejects the whole deterministic shortlist
  and the bounded retry round still finds no acceptable candidate, the
  assessment surfaces a likely ontology gap in `llm_decision` instead of a
  dead-end rejection.
- Hardened batched semantic LLM review: a single malformed item no longer voids
  the whole batch (only the affected target keys fall back to per-target
  review), duplicate target keys fall back instead of silently overwriting, the
  per-target fallback warning now reports *why* each key fell back, and a
  truncated or non-JSON provider response includes a sanitized content snippet in
  the error.
- Clarified the exported documentation for `create_sdp()`,
  `infer_dictionary()`, `infer_salmon_datapackage_artifacts()`, and
  `suggest_semantics()`, including the new `reject_shortlist` ->
  `request_new_term` escalation.
- Marked display-only vignette chunks as excluded from tangling so package
  checks do not execute credential, network, and local-file examples that are
  intentionally shown but not evaluated.
- Internal: deepened the semantic-review architecture without changing public
  signatures -- centralized LLM context/option handling
  (`.ms_llm_review_plan()`), extracted semantic target discovery into
  `.ms_semantic_discover_targets()`, moved one-shot artifact inference into
  `R/artifact-inference.R`, and froze the semantic target-row and LLM
  assessment-row column contracts with direct tests.

metasalmon 0.1.4
----------------

- Fixed `llm_context_files` handling in the `create_sdp()` semantic-review
  path: context files must now be supplied as local file paths, parsed
  data-frame/XML/R Markdown objects fail early with a clear error, and context
  supplied without `llm_assess = TRUE` now warns that it will be ignored rather
  than silently producing deterministic-only output.
- Clarified the exported documentation for `create_sdp()`,
  `infer_dictionary()`, `infer_salmon_datapackage_artifacts()`, and
  `suggest_semantics()` so users know context files affect only explicit LLM
  review.

metasalmon 0.1.3
----------------

- Added a first package-native `chat_decomposition()` workflow for measurement-variable review: resumable R-console sessions now keep structured curation state separate from transcript history, ask grouped decomposition questions, and end in an explicit preview/approve or new-term artifact with SKOS-variable / `usedProcedure` wording.
- Added deterministic fallback behavior for provider-wide LLM review failures: when every LLM assessment errors but retrieved semantic suggestions are still usable, package-native semantic review now warns and preserves the deterministic shortlist instead of aborting the whole workflow.
- Added `llm_reasoning_effort` support for OpenAI semantic-review requests and omit explicit `temperature` for GPT-5 chat-completions payloads that require the provider default.

metasalmon 0.1.2
----------------

- Fixed the seeded semantic-context warning path so `seed_semantics = TRUE` no longer crashes when mixed or previously unsupported `llm_context_files` trigger `cli` interpolation in package creation/review flows.
- Expanded `llm_context_files` handling so HTML/HTM, DOCX, `.R`, `.Rmd`, and `.qmd` inputs are read or normalized cleanly during LLM review instead of failing on unsupported-file warnings.
- Added Excel workbook context-file support for package-native LLM review, including `.xls`, `.xlsx`, and `.xlsm` inputs via the optional `readxl` package.
- Hardened LLM assessment parsing so malformed `accept` responses without a selected candidate degrade to `review`, and falsey `missing_context` placeholders no longer pollute outputs.
- Expanded LLM regression coverage with mixed-context bundle tests for the exact `chapi` + `ollama2.mistral:7b` configuration, including markdown, CSV, Excel, PDF, HTML, DOCX, and notebook/source context bundles across `dataset.csv`, `tables.csv`, `column_dictionary.csv`, and `codes.csv` targets.
- Finished the `scripts/llm-sanity-check.R` harness into a richer end-to-end smoke tool: it now generates per-case context bundles, records context formats in the summaries, rebuilds EDH XML after a simulated review pass, and writes stable CSV outputs under `artifacts/`.
- Added and linked a dedicated LLM review getting-started guide from the quickstart/setup docs so the package-native workflow is easier to discover.

metasalmon 0.1.1
----------------

- Added a first-class `chapi` LLM provider preset for DFO's internal Open WebUI endpoint. It defaults to `ollama2.mistral:7b`, uses `https://chapi-dev.intra.azure.cloud.dfo-mpo.gc.ca/api`, reads provider-specific overrides from `CHAPI_API_KEY`, `CHAPI_MODEL`, and `CHAPI_BASE_URL`, and now gives slower `gpt-oss` responses a longer effective timeout plus one retry.
- Updated the quickstart/home-page docs so internal DFO users can opt into `chapi` directly from `create_sdp(..., llm_assess = TRUE)`, while external users get parallel OpenRouter-free and OpenAI-credit setup paths.
- Promoted `create_sdp()` and the Salmon Data Package workflow into a coherent release shape: single-table and multi-table package creation, semantic review artifacts, and post-review EDH rebuild are now aligned and documented as the primary path.
- Hardened final-review behavior: `validate_salmon_datapackage(..., require_iris = TRUE)` now fails on unresolved metadata placeholders, blank table observation-unit IRIs, and lingering review sentinels so strict validation actually means review is finished.
- Hardened table-level semantic review writes and EDH rebuilds: LLM-selected table suggestions now write back into `metadata/tables.csv`, and `write_edh_xml_from_sdp()` now refuses to rebuild from obviously unreviewed packages.
- Improved package-native LLM review ergonomics: one-shot shortlist preservation now respects `llm_top_n`, shared `llm_context_files` are reused across targets, and non-interactive profile-scoped term requests now fail clearly instead of silently emitting junk defaults.
- Fixed multi-table semantic seeding so later tables use their own context instead of borrowing semantic context from table 1.
- Cleaned the release docs surface: refreshed the package description, fixed broken source-view links and vignette anchors, removed stale GPT-era remnants and orphaned assets, hid leaked internal helper pages from the public site, and rebuilt pkgdown from the integrated source.
- Bundled a matching Fraser Coho 2023--2024 starter dictionary plus provenance link so the installed package has a realistic context-file demo for the package-native LLM workflow.

metasalmon 0.0.27
----------------

- Fixed a deterministic semantic-query bug for spawner-style measurement columns: the property-slot query no longer hard-codes `count` for columns like `natural_adult_spawners`, and now prefers `spawner abundance` so the shortlist is more semantically sensible before LLM review.
- Added one bounded LLM exploration round for weak semantic shortlists: when the first LLM pass comes back as review/propose-new-term or low-confidence, `suggest_semantics(..., llm_assess = TRUE)` may request 1--2 alternate plain-text search queries, rerun deterministic retrieval, merge/de-dupe candidates, and reassess once without letting the model mint raw IRIs.

metasalmon 0.0.26
----------------

- Further tuned the OpenRouter free path for practicality: `openrouter/free` now uses smaller pair-sized batches and a smaller effective candidate shortlist per target so free-router prompts stay lighter on larger quickstart-style runs.

metasalmon 0.0.25
----------------

- Made the OpenRouter free path more practical for full semantic review runs: live `openrouter/free` requests are now serially batched in pairs and use a smaller effective shortlist per target when using the built-in HTTP client, which trims request overhead without adding flaky parallel fan-out.
- Added batch fallback safety: if a batched OpenRouter response is malformed or incomplete, `metasalmon` now falls back to per-target assessment instead of poisoning the whole run.
- Retained the 0.0.24 hardening: longer effective timeout, one retry for transient failures, lighter context payloads, and downgrade-to-review handling for out-of-range candidate indexes.

metasalmon 0.0.24
----------------

- Hardened package-native LLM review for flaky free-router behavior: OpenRouter free models now get a longer effective timeout, one automatic retry for transient HTTP/network failures, and fewer context chunks per request so prompts stay lighter.
- Hardened invalid LLM candidate-index handling: out-of-range `selected_candidate_index` values no longer poison the whole target; they are downgraded to `review` with no auto-selection instead of surfacing as a hard LLM error.

metasalmon 0.0.23
----------------

- Added package-native LLM semantic review on top of deterministic retrieval: `suggest_semantics(..., llm_assess = TRUE)` can now assess shortlisted candidates with OpenAI-compatible providers, attach `llm_*` review columns to `semantic_suggestions`, and expose target-level results via `attr(dict, "semantic_llm_assessments")`.
- Added local context-file support for LLM semantic review, including README/markdown/text-style files and optional PDF extraction via `pdftools`, with bounded chunking so reports are trimmed before prompting.
- Added OpenRouter support for package-native LLM review, including pass-through model ids (so OpenRouter models ending in `:free` work without special branching).
- Extended `infer_dictionary()`, `infer_salmon_datapackage_artifacts()`, and `create_sdp()` to thread the optional LLM semantic review arguments through the start-here workflow.
- Extended `apply_semantic_suggestions()` with `strategy = "llm"` and `min_llm_confidence` for explicit application of LLM-reviewed matches.
- Updated README, GPT-collaboration vignette, entrypoint docs, tests, and generated documentation for the 0.0.23 feature release.

metasalmon 0.0.22
----------------

- Simplified EDH XML support down to the single DFO Enterprise Data Hub HNAP export we actually use: `edh_build_hnap_xml()` is now the canonical helper, while `edh_build_iso19139_xml()` remains only as a deprecated compatibility alias.
- Simplified `create_sdp()` EDH export behavior: `include_edh_xml = TRUE` now always writes `metadata/metadata-edh-hnap.xml`; legacy `edh_profile` / `EDH_Profile` / `EDH_profile` inputs are still accepted as deprecated compatibility shims, while `edh_xml_path` is deprecated and ignored.
- Rebuilt reference docs, tests, package artifacts, and pkgdown site for the 0.0.22 patch release.

metasalmon 0.0.20
----------------

- Hardened GitHub helper security: GitHub readers now reject non-GitHub remote URLs and avoid attaching GitHub auth headers to non-GitHub hosts; improved public/private auth behavior and related tests.
- Hardened package writing + export reliability: `create_sdp()` now fails fast with an explicit `overwrite = TRUE` message when the target directory already exists, fixed DwC validator execution path, and improved ontology fetch robustness with explicit timeout handling and cache fallback behavior.
- Surfaced clearer warning messages when online vocabulary API lookups time out, so empty `find_terms()` results are less opaque during semantic seeding.
- Fixed `submit_term_request_issues()` batch routing so per-row `ontology_repo` values are honored instead of posting all rows to the first repo.
- Clarified `validate_semantics()` API by explicitly deprecating ignored legacy arguments (`entity_defaults`, `vocab_priority`) with coverage for warning behavior.
- Improved release/test hygiene: dependency bootstrap script hardening, tighter warning assertions in brittle tests, and refreshed package description wording.

metasalmon 0.0.19
----------------

- Hardened table observation-unit auto-apply in `create_sdp()`: table-level observation-unit suggestions are now ignored when driven by placeholder review text and only auto-applied when lexical compatibility checks pass against non-placeholder table metadata.
- Improved non-measurement `term_iri` auto-apply quality without disabling the feature: incompatible candidates are now filtered using role-hint mismatch checks, match-type/score guards, and token-level lexical compatibility with the target column context.
- Strengthened `infer_column_role()` heuristics for NuSEDS-like fields: year-like columns are now classified as temporal more reliably, and `NATURAL_ADULT_SPAWNERS`-style quantity columns are inferred as measurement.
- Tightened default code-level seeding gates to reduce free-text noise while preserving useful low-cardinality categorical/attribute suggestions: text-like field names and non-code-like all-unique short character values are excluded from the default factor-scope code seeding path.
- Added regression coverage for the above hardening paths, including placeholder-driven table seeding prevention, bad non-measurement suggestion filtering, improved role inference for fuller examples, and free-text seeding guardrails.
- Rebuilt reference docs, tests, package artifacts, and pkgdown site for the 0.0.19 patch release.

metasalmon 0.0.18
----------------

- Reworked review placeholders so missing descriptions/metadata are labeled explicitly (`MISSING DESCRIPTION:` / `MISSING METADATA:`) instead of the more ambiguous generic review wording.
- `create_sdp()` and related inference paths now seed table-level observation-unit review content and auto-apply the top table semantic suggestion into `tables.csv`, including `observation_unit_iri` and a backfilled `observation_unit` label when needed.
- Broadened default semantic suggestion coverage beyond measurement columns in a conservative way: categorical and controlled low-cardinality attribute columns can now receive lighter `term_iri` suggestions, while identifier and temporal columns remain excluded from default non-measurement suggestion seeding.
- Broadened default code-level semantic seeding so ordinary low-cardinality character columns from typical CSV imports are considered, rather than relying on R factor inputs.
- Made inferred `required` flags less misleading by marking obvious identifier columns as required and leaving other columns unknown (`NA`) until reviewed, instead of defaulting everything to `FALSE`.
- Improved auto-filled `term_type` values when `term_iri` suggestions are applied and kept the `target_description` vs `column_description` distinction explicit in suggestion outputs.
- Added a second bundled official NuSEDS example dataset: `nuseds-fraser-coho-2023-2024.csv` (173 rows across 2023–2024), while keeping the existing 30-row demo sample intact.
- Added reproducible provenance for bundled NuSEDS examples via `data-raw/nuseds_fraser_coho_examples.R` and documented the upstream Open Government Canada record/resource and licensing.
- Updated README, vignettes, reference docs, and tests to reflect the broader semantic seeding behavior, required-flag review stance, observation-unit handling, and the tiny-vs-fuller example-data workflow.

metasalmon 0.0.17
----------------

- Improved measurement semantic query shaping for count-like fields:
  - split variable/property query behavior so `NATURAL_SPAWNERS_TOTAL` no longer defaults both roles to the same abundance concept,
  - added a count-like unit fallback query (`count`) for measurement columns that clearly represent totals/counts/abundance.
- Added/updated regression tests for role-aware query behavior, count-like unit fallback, and unit-label backfill when applying unit suggestions.

metasalmon 0.0.16
----------------

- Rewrote `README-review.txt` intro and checklist to be shorter, more first-time friendly, and more action-oriented.
- `create_sdp()` now prints an explicit up-front note that semantic seeding may take a few minutes.
- Improved column-level semantic query construction for measurement fields so placeholder text is not used as the query source.
- Added role-aware query shaping that improves built-in sample suggestions for `NATURAL_SPAWNERS_TOTAL` (e.g., variable/property `SpawnerAbundance`, entity `Population`, constraint `NaturalOrigin`) and avoids the previous exploitation/mortality-rate mismatches.
- Unit suggestions are now skipped when no unit context exists, and applying a unit suggestion now backfills `unit_label` when missing.

metasalmon 0.0.15
----------------

- `create_sdp()` now tells users up front when online semantic seeding may take a few minutes and points to `seed_semantics = FALSE` for the fastest first pass.
- Simplified `README-review.txt` into a shorter 7-step checklist so the review flow is easier to follow.

metasalmon 0.0.14
----------------

- Simplified the package-creation surface so `create_sdp()` is the clear one-shot entrypoint, `write_salmon_datapackage()` is the advanced/manual writer, and the older create-from-data helper was removed.
- Reworked `create_sdp()` output into a cleaner review layout with `metadata/` and `data/` subdirectories, package-root `README-review.txt`, package-root `semantic_suggestions.csv` (when present), and root `datapackage.json`.
- Rewrote `README-review.txt` as a step-by-step checklist that explains the canonical Salmon Data Package, how to share the full package folder (or zip), and how to return to R for validation.
- Tightened default semantic seeding so code-level semantic suggestions run only for factor/categorical source columns by default, while keeping column-level and table-level seeding available.
- Added optional update notifications inside `create_sdp()` via `check_updates`, using the explicit `check_for_updates()` helper rather than package-attach network checks.
- Refreshed README, vignettes, reference pages, generated documentation, tests, and pkgdown outputs to match the new workflow and layout.

metasalmon 0.0.13
----------------

- Added vendored SDP Frictionless metadata schemas, profile, and custom rules; the schema loader tries the remote `smn-data-pkg` schema bundle first, then warns and falls back to the vendored copy.
- Changed package creation to write the canonical `metadata/` + `data/` layout while generating root `datapackage.json` with the SDP Frictionless profile by default.
- Added `write_datapackage = TRUE` to package creation helpers so callers can opt out during draft authoring.
- Updated package reading to prefer nested `metadata/` files, then legacy root-level metadata, then `datapackage.json` fallback.
- Made `edh_build_iso19139_xml()` default to the richer North American Profile / HNAP-aware EDH export while keeping `profile = "iso19139"` available as an explicit fallback.
- Expanded EDH export support for bilingual locale scaffolding, deterministic identifiers, legal constraints, maintenance/status, reference systems, bounding boxes, and distribution metadata, with regression coverage against the confirmed EDH sample shape.
- Added `apply_semantic_suggestions()` for explicit opt-in merges of `suggest_semantics()` results into dictionaries.
- Updated `read_salmon_datapackage()` to prefer canonical nested metadata, preserve legacy root-level reading, and read profile-aware `datapackage.json` descriptors when CSV metadata is absent.
- Refreshed README, vignettes, pkgdown reference metadata, and GPT collaboration guidance to match the EDH default/export semantics and explicit dictionary-application workflow.
- Rebuilt package documentation, tests, source tarball, and pkgdown site for the 0.0.13 release.

metasalmon 0.0.12
----------------

- Added a GCDFO-backed `find_terms()` search backend that queries the DFO Salmon Ontology first via content negotiation against `https://w3id.org/gcdfo/salmon`.
- For salmon-domain roles, `find_terms()` now prioritizes GCDFO results and only falls back to OLS/NVS when GCDFO returns no good label hit.
- Updated `suggest_semantics()`, `infer_dictionary(seed_semantics = TRUE)`, man pages, and vignettes to reflect the new GCDFO-first search behavior.
- Rebuilt package documentation, tests, source tarball, and pkgdown site for the 0.0.12 release.

metasalmon 0.0.11
----------------

- Added optional semantic seeding to `infer_dictionary()` via
  `seed_semantics = TRUE`, with optional source/max-per-role controls
  (`semantic_sources`, `semantic_max_per_role`).
  - This returns dictionary suggestions via
    `attr(dict, "semantic_suggestions")` without changing existing defaults.
- Added guidance at the package README quick example that keeps the home-page flow
  short and links to 5-minute Quickstart + dedicated deep-dive articles.
- Marked related vignettes as workflow-specific to avoid duplicating the Quickstart
  path; `data-dictionary-publication` and `reusing-standards-salmon-data-terms`
  now orient users to post-Quickstart use.

metasalmon 0.0.10
----------------

- Changed `validate_dictionary()` and `validate_semantics()` non-strict semantics:
  - missing `term_iri`, `property_iri`, `entity_iri`, and `unit_iri` on
    `column_role == "measurement"` no longer block package creation by default;
  - missing fields now trigger a strong warning that calls out next steps and points to `suggest_semantics()` plus the standards guide.
- Preserved strict validation when `require_iris = TRUE` so CI/high-assurance flows can still enforce full semantic coverage.
- Updated `README`, man pages, and tests to document and verify the new behavior.
- Added `metasalmon` package release metadata for version 0.0.10.

metasalmon 0.0.9
----------------

- Added `edh_build_iso19139_xml()` to generate starter ISO 19139 metadata XML for DFO Enterprise Data Hub / GeoNetwork upload workflows.
- Added tests and reference documentation for the EDH XML export helper.
- Updated dataset metadata examples/templates to better support EDH workflows:
  - Expanded `inst/extdata/dataset.csv` with `contact_org`, `contact_position`, `update_frequency`, `topic_categories`, `keywords`, and `security_classification`.
  - Updated `inst/extdata/custom-gpt-prompt.md` to distinguish controlled `topic_categories` from free-text `keywords` and to note XML export support.
  - Refreshed README and vignette examples to include EDH-ready optional metadata and XML export guidance.

metasalmon 0.0.8
----------------

- Added and documented NuSEDS method crosswalk helpers:
  - `nuseds_enumeration_method_crosswalk()`
  - `nuseds_estimate_method_crosswalk()`
- Added reference documentation pages for both crosswalk helpers.
- Refreshed README feature list to include the new NuSEDS crosswalk utilities.

metasalmon 0.0.6
----------------

- Added `read_github_csv_dir()` to read all CSV files from a GitHub directory into a named list, similar to using `dir()` with `lapply()` for local files.
- Supports pattern matching, version pinning, and passes options to `read_csv()` for all files.
- Added comprehensive test coverage for the new function.

metasalmon 0.0.5
----------------

- Renamed the GitHub CSV helpers to generic names: `github_raw_url()` and `read_github_csv()`. `repo` is now required unless you provide a full URL.

metasalmon 0.0.4
----------------

- Added `ms_setup_github()` to guide one-time PAT setup (git check, browser token creation, git credential storage) and verify access to the private Qualark data repository.
- Added `qualark_raw_url()` and `read_qualark_csv()` to build stable raw GitHub URLs and read Qualark CSVs using the stored PAT (with SSO-aware error messages and retry logic).
- New tests cover URL construction, blob/raw URL normalization, and an opt-in Qualark fetch when a token is configured.

metasalmon 0.0.3
----------------

- Added `find_terms()` function for searching candidate terms across external vocabularies (OLS, NVS, BioPortal).
- `find_terms()` now ranks results deterministically using I-ADOPT role hints from `inst/extdata/iadopt-terminologies.csv` (preferred vocabularies boosted; ties stable).
- `suggest_semantics()` now returns best-effort suggestions (stored in `attr(,'semantic_suggestions')`) instead of a placeholder message.
- Added I-ADOPT component fields (`property_iri`, `entity_iri`, `constraint_iri`, `method_iri`) to dictionary schema and package creation/reading.
- Enhanced validation: measurement columns now require I-ADOPT components (`term_iri`, `property_iri`, `entity_iri`, `unit_iri`).
- Updated table metadata: renamed `entity_type`/`entity_iri` to `observation_unit`/`observation_unit_iri` for clarity.
- Added `httr` package dependency for vocabulary search functionality.
- Dictionary validation now normalizes optional semantic columns and returns the normalized dictionary.
- Vignettes now show end-to-end semantic enrichment (I-ADOPT-aware suggestions) and how to align with `smn-gpt`.

metasalmon 0.0.2
----------------

- Unified semantic fields to `term_iri` + `term_type` and reserved `concept_scheme_iri` for code lists only.
- Updated GPT collaboration guidance, schemas, and pkgdown outputs to match the new fields.
- Refreshed vignettes, tests, and reference docs; bumped package version.

metasalmon 0.0.1
----------------

- Initial development snapshot.
