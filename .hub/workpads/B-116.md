# Workpad — B-116

## Queue item

**B-116** — Ship a producer for the reviewed semantic closure (legacy #116, repo
metasalmon, severity P1, venue claude-code). Claimed by `a-2da3cb6cd51c4da7` on
2026-09-14; work branch `agent/B-116/a-2da3cb6cd51c4da7`, worktree
`hub-worktrees/salmon-data-mobilization-metasalmon-B-116`.

Scope is the item's `retires_when`, read literally. Brett's ruling of 2026-09-12
(`knowledge/plans/2026-09-12-queue-promotion-review.md` §3) fixes both the shape
and the export set: **one** exported function, the three internals reached
*through* it rather than exported under their own names, and an unresolvable IRI
reported as a gap rather than aborted on, because a gap is what the term-request
pipeline consumes.

This workpad replaces B-49's at the same path, which reached `main` when that
item merged. `HUB.md` names one workpad path, so each branch carries its own.

## What changed and where

### `R/semantic-closure.R` (new)

One export, `write_sdp_semantic_closure(path, evidence = NULL, search_fn =
find_terms, sources = c("smn", "gcdfo"), quiet = FALSE)`. The ruled signature is
`(path, evidence = NULL)`; the three additions are defaulted. `search_fn` is the
package's established test hook (`suggest_semantics()` carries the same
parameter) and is what lets every test in this change run offline.

It returns invisibly: `vocabulary`, `review`, `gaps`, `measurement_iris`,
`review_targets`, `placeholders`, `files`.

- **Both canonical sets are derived, not reasoned from each other.**
  `.ms_eml_canonical_measurement_iris(path, pkg)` and
  `.ms_eml_canonical_review_targets(pkg)` are both called and both returned, so
  all three `metasalmon:::` reaches the rehearsal script made are satisfied by
  reading one result.
- **Evidence resolution goes through `find_terms()`**, not a new retrieval path.
  Query candidates per IRI, most specific first: the `search_query` recorded in
  `semantic_suggestions.csv` for that IRI; then the IRI's own local name split
  back into words (`.ms_closure_iri_query()`: `SpawnerAbundance` ->
  `"spawner abundance"`); then the dictionary `column_label` of each target that
  carries it. Roles come from the review targets, so an IRI is searched under the
  role that selects the right sources. The first hit whose `iri` matches wins.
- **`evidence` is overlaid field by field**, so a row may correct one field and
  leave the rest to the search. When a row supplies every required vocabulary
  field, **no search runs for that IRI at all** — which is how QUDT works, and is
  pinned by a test whose `search_fn` is a `stop()`.
- **`native_type` and `source_url` are derived** from the resolved
  `resource_kind` and `source` (`.ms_closure_native_type()`,
  `.ms_closure_source_url()`), and both are overridable. The two source URLs are
  the ones `.smn_term_index()` and `.gcdfo_term_index()` actually fetch.
- **`confidence` / `review_rationale`** come from `evidence`, else from a
  recorded `decision_reason` in `semantic_suggestions.csv` where
  `apply_sdp_semantics()` left one, else a `REVIEW REQUIRED:` marker (the
  package's established prefix) with a warning naming every target that got one.
  A producer that invented a confident rationale would be fabricating the one
  part of the ledger that is purely human; a marker plus a warning is the honest
  alternative, and it keeps the files writable, which is the whole point.
- **Digests.** Every row's `reviewed_snapshot_sha256` via
  `.ms_eml_vocabulary_snapshot_sha256()`, and both file digests in
  `metadata/eml-mapping.yml`.
- **Gap, not abort.** An IRI left without required evidence becomes a row of
  `gaps` and is omitted from the vocabulary; both files are still written. The
  gap table is `.ms_term_gap_cols()` **plus** `unresolved_iri`, with
  `gap_detection_basis = "no_candidates"` (the enum value that already means
  "retrieval returned nothing at all") and `placement_recommendation` taken from
  the IRI's own namespace via `.ms_term_request_namespace_scope()`. It is
  accepted by `render_ontology_term_request()`, pinned by a test.

### `scripts/build-fraser-coho-knb-rehearsal.R`

Three `metasalmon:::` calls removed; **zero remain** (the only surviving mention
is a comment saying they used to be there). STAGE 5 and STAGE 6 are **swapped**:
the EML sidecar is written first with the template's 64-zero digest
placeholders, then the producer pins them. That also removed the script's own
`file_sha256()` helper, so it now computes no closure digest at all. Its header
no longer claims three artifacts have no exported producer.

### `tests/testthat/test-semantic-closure.R` (new; 16 tests, 57 expectations)

Every test offline. The oracle in most of them is not "a file appeared" but
"`.ms_eml_read_vocabulary()` and `.ms_eml_read_semantic_review()` accept what the
producer wrote" — those two validators are what made the gap visible, so they are
the right judge of the fix. Also pinned: the producer's vocabulary field order
against the digest verifier's own field vector (read out of its body, not
restated); byte-reproducibility across two runs; C-collation row order in both
files and in the written bytes; and a `stop()`ing binding on
`.ms_llm_chat_json_request()` as the no-LLM sentinel.

### `tests/testthat/test-collation-guard.R`

`write_sdp_semantic_closure` and `.ms_closure_iri_roles` added to
`collation_sensitive_fns`, registered **on creation** per the rule in the S5
block above them, with the reason each needs C collation.

### Docs and records

- `NEWS.md` — an `### Added` entry under the development version.
- `vignettes/post-review-package-publication.Rmd` — the "Known gap" callout is
  replaced by a *Produce both files* subsection covering the producer, the two
  kinds of value it cannot derive, and the gap path into
  `render_ontology_term_request()` / `submit_term_request_issues()`.
- `knowledge/backlog.md` — #116 marked fixed in R, with what landed against each
  of the four numbered findings, and the two things that are **not** closed.
- `knowledge/parity-deviations.md` — the owed port, under *What metasalmon 0.5.0
  owes the mirror*, following the B-124 / B-125 precedent: **not** a numbered row.
- `knowledge/roadmap.md` — the same port in the release index's metasalmonpy
  entry, which the pull-request template names as the second home for a port and
  which B-124 and B-125 never reached. That omission is recorded there as the
  drift it is, with the rule stated rather than just this instance.
- `queue/items/B-116.yaml` — `state: review`, `claimable: false`.
- `NAMESPACE` / `man/write_sdp_semantic_closure.Rd` — regenerated.

## Commands run and results

### Failing-before / passing-after

This defect's reproduction is the golden path itself, and it is captured twice.

**Before, by the measure the item chose for itself.** On untouched `main`
(4cd085c):

```
$ grep -c 'metasalmon:::\.ms_' scripts/build-fraser-coho-knb-rehearsal.R
3      # lines 323, 332, 346: .ms_eml_canonical_measurement_iris,
       # .ms_eml_vocabulary_snapshot_sha256, .ms_eml_canonical_review_targets
       # (grep -c on the bare string returns 4: line 229 is a comment)
$ grep -c "export(write_sdp_semantic_closure)" NAMESPACE
0      # and no other export writes either closure file
```

(That second grep is the honest one. A `grep` for `semantic_vocabulary` near a
`write_csv` call returns 0 both before *and* after, because the filename and the
write are on different lines in the new code — so it is not a discriminator and
is recorded here as one that looks like it should be.)

**Before, the user-visible symptom**, reproduced on untouched `main` by building
the fixture, deleting its pre-written closure, and asking for EML export:

```
[both closure files deleted]
SDP data object '.../reviewed_semantic_selections.csv' does not exist.

[only the vocabulary deleted]
SDP data object '.../metadata/semantic_vocabulary.csv' does not exist.
```

Worth one correction to the backlog's own account: it quotes the symptom as the
*vocabulary* message, and the first message a user actually hits is the *ledger*
one, because `write_eml_from_sdp()` reads the review ledger first. Same hole,
different file named — which matters only in that someone chasing the quoted
string would not find it.

**After.** The rehearsal script, run end to end against the shipped 173-row
example (2026-09-15, network live for smn/gcdfo):

```
== STAGE 6: build the reviewed closure (vocabulary + ledger)
* 4 canonical measurement IRIs.
* 5 canonical review targets.
* Resolving <https://w3id.org/gcdfo/salmon#SpawnerAbundance>.
* Resolving <https://w3id.org/smn/Abundance>.
* Resolving <https://w3id.org/smn/Population>.
v Wrote 4 vocabulary rows and 5 ledger rows.
  4 vocabulary rows, 5 ledger rows, sidecar digests pinned

== STAGE 7: write reviewed EML and rehearse the KNB test-node plan
v Salmon Data Package validation passed
v Validated EML "2.2.0" written to '.../publication/test/eml.xml'
v KNB dry-run manifest written to '.../publication/test/knb-manifest.json'
Status:       dry_run
Objects:      10
  - sdp_artifact: metadata/semantic_vocabulary.csv
  - sdp_artifact: reviewed_semantic_selections.csv
```

Only three of the four IRIs are resolved over the network: the fourth is
`qudt:INDIV`, supplied in full through `evidence`, and the producer skips the
search entirely for a fully supplied row. The definitions in the written
vocabulary now come from the live ontologies rather than from strings typed into
the script, which is a provenance improvement the reorder got for free.

**After, the gap path**, from the test suite, with an invented
`term_iri = https://w3id.org/smn/NoSuchTermHere`:

```
! 1 canonical measurement IRI could not be resolved from "smn" and "gcdfo" and
  is absent from the reviewed vocabulary.
x term_iri = https://w3id.org/smn/NoSuchTermHere
i Each is a row of the returned gaps table; pass it to
  `render_ontology_term_request()` ... or supply a row through `evidence`.
```

Both files are written; `gaps` has one row with
`gap_detection_basis = "no_candidates"` and `placement_recommendation = "smn"`;
`render_ontology_term_request()` accepts it; and `.ms_eml_read_vocabulary()` then
names the same IRI as missing, so the omission is not silent.

### The two canonical sets, measured on the bundled example

**In the `make_eml_test_sdp()` fixture and in the shipped Fraser coho example the
difference is the same and is exactly one row: `https://w3id.org/smn/Observation`
is a review target and not a vocabulary term**, because it is the table's
`observation_unit_iri`. Ledger 5 rows, vocabulary 4.

The difference runs the other way too in general — a `sosa:usedProcedure` reached
through a code value is a vocabulary term and not a review target — but neither
example has one, so that half is handled by construction in the producer
(`.ms_closure_iri_roles()` falls back to role `method` for an IRI in the
measurement set and in no review target) and is not covered by a fixture. Named
below as a testing gap rather than left implied.

### Test suite

```
$ Rscript -e 'devtools::test()'
[ FAIL 8 | WARN 38 | SKIP 9 | PASS 3921 ]
```

**All 8 failures pre-exist on untouched `main` at the same commit (4cd085c)**,
verified by running the four affected files in a separate clean worktree:

| file | failed on main | failed on this branch |
|---|---|---|
| `test-iri-predicates.R` | 4 | 4 |
| `test-review-console.R` | 1 | 1 |
| `test-github-helpers.R` | 2 (errors; HTTP 404) | 2 |
| `test-dictionary-helpers.R` | 1 | 1 |

The new file alone:

```
$ testthat::test_file("tests/testthat/test-semantic-closure.R")
tests: 16  failed: 0  error: 0  passed: 57  warn: 0
```

### `R CMD check`

```
$ Rscript -e 'rcmdcheck::rcmdcheck(args = "--no-manual", error_on = "warning")'
Status: 2 ERRORs, 1 WARNING
```

Identical in substance to the baseline on untouched `main`, run in a separate
worktree at the same commit, which reports `2 ERRORs, 1 WARNING, 1 NOTE`. Item by
item:

- **ERROR, `checking tests`** — the 8 pre-existing failures above.
- **ERROR, `checking running R code from vignettes`** —
  `migrating-to-sdp-0-3-0.Rmd` and `tidy-data-for-sdp.Rmd`, neither touched here,
  both failing on main. `post-review-package-publication.Rmd`, which this change
  edits, reports OK on both, and `checking re-building of vignette outputs` is OK
  on both.
- **WARNING, `checking R files for syntax errors`** — `OS reports request to set
  locale to "en_US.UTF-8" cannot be honored`. A property of this container, not
  of the package.
- **NOTE (baseline only)** — a stray `.pytest_cache` in the other worktree. Not
  in this one, which is why the note count differs and the difference means
  nothing.

```
$ git diff --check          # clean
$ LC_ALL=C grep -cP '[^\x00-\x7F]' R/semantic-closure.R      # 0
```

**R here is 4.3.3.** Per `AGENTS.md`, a green local check is evidence about this R
and not about CI's, which runs newer; the non-ASCII check in particular is one
this R may not run at all. So the new R file and the new test file were checked
for non-ASCII characters directly rather than inferred from the check being
quiet.

### CI, which is the check that counts

All three checks on pull request #121 are **green**, `check` included:

```
registers-agree: success
queue-is-valid:  success
check:           success        # rcmdcheck, error_on = "warning", CI's R
```

`registers-agree` passing is the specific confirmation that the port was
recorded correctly: that guard fails on a `parity-deviations.md` row number with
no twin in metasalmonpy's `PARITY.md`, so a numbered row here would have turned
CI red in both repositories. It is green because no row was added.

**And `check` being green is a finding, not just a relief.** The 8 test failures
and the 2 vignette errors that this machine reports do not reproduce on CI at
all. `AGENTS.md` warns that a green local check is evidence about local R and not
about CI's, with a measured case where **local was greener than CI**. This is the
same warning running the other way: **CI is greener than local**, on R 4.3.3
here against CI's newer R. Both directions have now been observed, so the rule to
draw is the symmetric one — a local check result and a CI check result are two
measurements of different things, and neither substitutes for the other. The
baseline comparison above is what makes this branch's local result readable at
all; without it, 8 local failures would have looked like something this change
did.

## What I did not do, and why

- **The metasalmonpy half.** The mirror contract presumes it and backlog #116
  measured the identical hole there on 2026-08-25. It is owed as a **port**, not
  a deviation row, per the precedent B-124 and B-125 set in
  `knowledge/parity-deviations.md`; the specification is written into that file's
  *What metasalmon 0.5.0 owes the mirror* section in this pull request, including
  that the gap-not-abort shape is the ruled part and must not become an exception
  on the Python side. **It has no queue item and needs one** — candidate 1 below.
  Not absorbed here because the item names one repository and the claim covers
  one branch in it.
- **The workshop surface.** Backlog #116 finding 1 names two downstream surfaces
  to revisit when a producer ships. The vignette is revisited. The other is
  session 6 of `salmon-data-standards-workshop`, whose callout still tells
  learners a complete deposit is unreachable and whose four publication chunks
  are `eval = FALSE` for that reason. That repository is **shared** (HUB.md's
  participation table), so an agent may not push to it. Candidate 2.
- **A fixture binding a code-resolved `sosa:usedProcedure`.** Candidate 3, with
  the reasoning under "the two canonical sets" above.
- **`#117`** (`term_type` required by EML export, not by strict validation) is
  adjacent and explicitly separable in the backlog. Untouched.
- **The roxygen2 version.** `devtools::document()` under the installed roxygen2
  8.1.0 reformats every `importFrom` directive and bumps
  `Config/roxygen2/version` from the repo's pinned 8.0.0. Both were reverted by
  hand so this pull request carries only `export(write_sdp_semantic_closure)`:
  bumping the documentation toolchain is not this item's scope and would bury the
  change. Candidate 4.

## Guards, suppressions and workarounds added, with retirement conditions

1. **`collation_sensitive_fns` entries** for `write_sdp_semantic_closure` and
   `.ms_closure_iri_roles`. *Retires when:* the collation guard stops relying on
   an enumerated list — the same condition the rest of that list carries.
2. **`.ms_closure_source_url()`**, which restates the two URLs
   `.smn_term_index()` and `.gcdfo_term_index()` fetch. It is a second copy of a
   fact and it says so in the source. *Retires when:* `find_terms()` returns the
   artifact URL it resolved, at which point reading it back is strictly better
   than restating it.
3. **`.ms_closure_set_mapping_digest()`**, which edits the sidecar's text rather
   than round-tripping the parsed YAML. Not style: `yaml::write_yaml()` drops
   every comment, and the sidecar a user starts from is the shipped template
   whose first four lines are the instructions for filling it in. *Retires when:*
   the sidecar stops being a hand-edited file and an exported writer owns it end
   to end, at which point it can be emitted whole. Its own refusal branch (a
   sidecar key written in flow style) warns rather than appending a duplicate
   key, and that branch has a test.
4. **The `REVIEW REQUIRED:` rationale placeholder.** It satisfies the ledger's
   non-empty check, so a user *could* publish with it; the warning and the
   self-identifying marker are the only signals, deliberately, because judging a
   rationale is not a validator's job. *Retires when:* the review API records a
   rationale for every accepted slot, so there is nothing left to placeholder —
   or a publication gate refuses the marker, which is a decision nobody has made.
5. **No skips added.** The new test file skips nothing and needs no network.

## A bug this change found in itself, recorded because the shape recurs

The inline-sidecar warning path aborted with cli's *"Cannot pluralize without a
quantity"*: one message element used `{?it/them}` while interpolating nothing, so
the warning replaced itself with an error. It was found only because that
otherwise-unreachable path got a test, and it is the same failure mode
`R/cli-safety.R` is about from the other direction — a cli message is a program,
and an untested one is an unrun program. The fix drops the pluralization in that
element and says why in a comment. Both the one-key and two-key renderings are
now exercised.

## Anything belonging to another item

- **`B-117`** (legacy #117) — adjacent, separable, untouched.
- **`S-13` requirement 1** shares the internals this item exposes. The 2026-09-12
  ruling settles its export set: they are reached through the one new export and
  stay unexported. Nothing further owed here.

## New-item candidates (no queue id; evidence in this workpad)

1. **Port `write_sdp_semantic_closure()` to metasalmonpy.** P1, repo
   metasalmonpy, blocked by B-116. The specification is already written into
   `knowledge/parity-deviations.md` by this pull request. Belongs beside B-124 and
   B-125.
2. **Revisit `salmon-data-standards-workshop` session 6** now that a producer
   exists: the gap callout is stale and the four `eval = FALSE` publication
   chunks can run. Shared repository, so it needs Brett.
3. **A fixture binding a code-resolved `sosa:usedProcedure`**, so the
   measurement-set-minus-review-target direction of the two canonical sets is
   covered by a test and not only by construction.
4. **Decide the roxygen2 pin.** The repo records 8.0.0 and the available
   toolchain is 8.1.0, whose output differs in every `importFrom` directive. Any
   agent running `devtools::document()` must either carry that churn or revert it
   by hand, as this pull request did. One deliberate bump would end it.

---

# Review round 2 — the five Codex findings on pull request #121

Codex left four code-review findings and, three minutes later, one security
finding, all on `R/semantic-closure.R` at head `5ad5c093bd`. All five were valid.
Two of them (the code review's `:550` and the security review's `:642`) are the
same defect seen at different completeness, and one change answers both.

## 1 + 5 — linked closure outputs (`:550` P1, `:642` P1 security)

`.ms_closure_resolve_write_path()` normalized and contained only the *parent*
directory and returned a path still naming the final entry, so `write_csv()`
followed a symlink sitting there. `.ms_closure_update_mapping()` was worse: it
called `writeLines()` on `metadata/eml-mapping.yml` with no path check at all.
The threat model the security review states is the one that matters — **an SDP
received from a collaborator**, whose own content names the file, in a function
that is newly exported and documented as a workflow.

Both are now the package's own hardened layer rather than new code:
`.ms_sdp_extension_root()` refuses a symlinked root,
`.ms_sdp_extension_assert_safe_directory(create = TRUE)` walks every component
refusing a symlinked or escaping one, and
`.ms_sdp_extension_assert_safe_file(must_exist = FALSE)` refuses a symlinked
final entry. `create = TRUE` also replaces a `dir.create(recursive = TRUE)` that
ran *before* the containment check, so a declared escaping path no longer creates
directories outside the package on its way to being refused. The sidecar's path
is resolved once and used for both the read and the write, because the declared
paths this producer obeys come out of that file.

**Hard links are not detected, and are not left open.** Base R exposes no link
count — `file.info()` has no `nlink`, `Sys.readlink()` sees nothing — so there is
no portable check to add, and the report says so rather than implying coverage.
What closes it is the install path: the staged-sibling rename in finding 3 never
opens the destination, so an external hard link keeps its inode and its content.

Failing before, all three names, with the link target outside the package:

    -- Failure: a linked closure output is refused and its target is left alone
    Expected `write_sdp_semantic_closure(...)` to throw a error.
    -- Failure: Expected `readLines(external)` to be identical to `keep`.
    - "iri,label,definition,source,ontology,resource_kind,type_iris,..."
    - "http://qudt.org/vocab/quantitykind/Count,Count,A quantity kind for..."
    + "keep_me: true"
    + "other: 1"

    (second pass, the ledger)
    - "dataset_id,table_id,column_name,target_scope,target_sdp_field,..."
    + "keep_me: true"

    (third pass, the sidecar itself)
      "keep_me: true"
      "other: 1"
    - "semantic_vocabulary:"
    - "  sha256: '980c35e06763687ae2aa9896d51d01c661644efd2dc49707b8b06892901eeec4'"
    - "semantic_review:"
    - "  sha256: 'ad2cf185fae8656890ef024a6603c08cdb5a53c7b2278abfc4ff406e70d4718f'"

A file outside the package was truncated and rewritten in every one of the three
cases. After the fix all three abort and the target is byte-identical.

## 2 — a lookup failure is not an ontology gap (`:373` P1)

The most important of the five: B-116's whole ruled shape is gap-not-abort, and
this was that shape turned into a defect. `error = function(e) NULL` swallowed a
thrown search failure, and the `"diagnostics"` attribute — which `find_terms()`
attaches to an EMPTY result while warning, in its own words, that such a result
is unknown rather than an ontology gap — was never read. Either one produced a
`no_candidates` gap row, an omitted vocabulary row, a written closure, and a term
request asking an ontology to mint a term nobody established was missing.

`.ms_closure_search_evidence()` now carries both back, and an IRI that failed to
resolve under a degraded search **aborts before anything is written**, naming the
IRI and the silent sources. That is not a departure from the ruling: the ruling is
about a term the searched vocabularies genuinely do not have, which somebody can
file. A source that did not answer has said nothing, so there is nothing to file,
and the remedy is to re-run — which is why nothing is left on disk.

The degraded-status test is now **one copy**, `.ms_search_failed_sources()` in
`R/term_search.R`, read both by `find_terms()`'s own warning and here. A second
copy would let one caller keep manufacturing gaps after the other stopped.

Failing before:

    -- Failure: a search that throws aborts rather than manufacturing a gap
    Expected `write_sdp_semantic_closure(...)` to throw a error.
    -- Failure: Expected `file.exists(.../semantic_vocabulary.csv)` to be FALSE.
    `actual`: TRUE   `expected`: FALSE
    -- Failure: Expected `file.exists(.../reviewed_semantic_selections.csv)` ...
    `actual`: TRUE   `expected`: FALSE

    -- Failure: an empty result with failed-source diagnostics is not a gap
    Expected `write_sdp_semantic_closure(...)` to throw a error.
      (and the warning it emitted instead)
      ! 2 canonical measurement IRIs could not be resolved from "smn" and
        "gcdfo" and are absent from the reviewed vocabulary.
      x entity_iri = https://w3id.org/smn/Stock
      x term_iri = https://w3id.org/smn/ObservedRateOrAbundance
      i Each is a row of the returned gaps table; pass it to
        `render_ontology_term_request()` to file a term request

That warning is the defect in its own words: an outage, reported as two ontology
gaps, with an invitation to file them.

The thrown-error test uses `stop("connection {reset} by peer")` on purpose, so
the external text reaching cli is escaped rather than interpolated.

## 3 — the three writes install as one set (`:980` P1)

Reused rather than reinvented, as the finding asked: all three render to bytes
and install through **`.ms_sdp_extension_atomic_write_set()`**, which stages each
as a sibling, renames them in, and rolls every one back if any install fails.

**This does not depend on pull request #119 landing.**
`.ms_sdp_extension_atomic_write_set()` is already on `main`
(`R/sdp-extension-helpers.R:133`), complete with the symlink refusal and the
rollback; #119 *uses* it for `create_sdp()`'s sidecars rather than introducing it.
The one thing #119 adds that this needed is `.ms_sdp_extension_text_bytes()`, and
rather than edit that file and collide with #119 on merge, this branch carries a
file-local `.ms_closure_text_bytes()` whose comment names #119 as its retirement
condition. When #119 merges, that function becomes a call to the shared one.

The digests moved from `digest(file = ...)` to `digest(<bytes>)` — identical
output, verified — because hashing installed files would require the CSVs to be
in place first, which is precisely the window the finding describes.

Failing before, in two halves, one mocked and one not:

    -- Failure: a failure in the third write leaves the first two unchanged
    Expected `read_bytes(first$files[["vocabulary"]])` to be identical to
    `before_vocabulary`.
    Differences:
          actual | expected
    [922] "41"   | "41"
                 - "6e"            <- "An operationally defined grouping"
    [923] "20"   | "20"               survived only in `expected`
    [924] "64"   - "6f"
    [925] "65"   - "70"            <- on disk: "A deliberately different
    [926] "6c"   -                    definition."

    -- Error: cannot open the connection
      7. +-metasalmon::write_sdp_semantic_closure(...)
      8. | \-readr::write_csv(review, review_file, na = "")

The first half fails the sidecar render; the vocabulary CSV had already replaced a
valid version and the sidecar still carried its old digests — a package that fails
its own digest check even though the call errored. The second half puts a
directory where the ledger belongs, with no mock in it, and the old code replaced
the vocabulary before erroring on the ledger.

## 4 — incomplete evidence is not a missing term (`:874` P2)

An exact IRI hit with a blank required field (a class with no definition is the
ordinary case) went through `.ms_closure_gap_row()`, which hard-codes
`candidate_count = 0` and `gap_detection_basis = "no_candidates"`, so the table
asked for a term that had just been found. There is now a third outcome:
`closure$incomplete`, naming the missing field and the slot it is missing from,
with a warning that says in as many words that it is not an ontology gap. The row
is still omitted, because `.ms_eml_read_vocabulary()` refuses a blank definition,
and the other rows are still written.

`.ms_closure_target_context()` was factored out so the gap row and the incomplete
row cannot disagree about where in the package an IRI sits.

Failing before:

    -- Failure: a term found with a blank required field is incomplete, not a gap
    Expected `... <- NULL` to throw a warning.
    -- Failure: Expected `nrow(closure$gaps)` to be identical to 0L.
      `actual`: 1   `expected`: 0
    -- Failure: Expected `nrow(closure$incomplete)` to be identical to 1L.
      `actual` is NULL
      (and the warning: 1 canonical measurement IRI could not be resolved ...
       x term_iri = https://w3id.org/smn/ObservedRateOrAbundance)

## The guard-retirement comment B-172 exists for

Codex on pull request #123 pointed out that B-172 exists only because the
`REVIEW REQUIRED:` placeholder had no retirement condition **in the source**, and
that B-172 is `blocked_by: [B-116]`, so the violation would land before its
one-line fix. The pull request body claimed "four, all with retirement conditions
in the source" and was one short: `.ms_closure_source_url()` and
`.ms_closure_set_mapping_digest()` carried theirs, the placeholder carried its
only in this workpad. It is now above `placeholder_rationale` in
`R/semantic-closure.R`, stated concretely: it retires when `accept_suggestion()`
requires a `decision_reason` and `apply_sdp_semantics()` carries it through for
every accepted row, at which point the branch is unreachable and the marker, the
`placeholders` return value and the warning go together.

Guards added in this round, each with its retirement condition in the source:

1. `.ms_search_degraded_statuses()` / `.ms_search_failed_sources()` — restates
   the two per-source statuses that mean "did not answer". *Retires when:* a
   failed lookup stops being representable as an empty result.
2. `.ms_closure_resolve_write_path()`'s link refusal. *Retires when:*
   `.ms_sdp_extension_assert_safe_file()` grows a create-if-absent mode, at which
   point this is one call to it.
3. `.ms_closure_text_bytes()` — a deliberate duplicate. *Retires when:* #119
   lands `.ms_sdp_extension_text_bytes()`.
4. The `REVIEW REQUIRED:` placeholder, above.

No skips added. The new symlink test carries `skip_on_os("windows")`, which is a
platform fact rather than a workaround: `file.symlink()` needs a privilege there.

## Anything Codex got wrong

Nothing. All five findings reproduce. The only correction to the *remedies* is
that finding 3 does not need pull request #119: the writer it names is already on
`main`, and only a text-bytes renderer is owed to #119.

## Commands and results

    Rscript -e 'devtools::test()'
      before this round: [ FAIL 8 | WARN 38 | SKIP 9 | PASS 3921 ]
      after:             [ FAIL 8 | WARN 38 | SKIP 9 | PASS 3958 ]
      test-semantic-closure.R alone: 21 tests, 90 passing, 0 failed (was 16/57)

    The same 8 failures, re-measured on untouched main at 4cd085c in a separate
    worktree, file by file:
      test-dictionary-helpers.R  failed 1
      test-github-helpers.R      error  2
      test-iri-predicates.R      failed 4
      test-review-console.R      failed 1     = 8

    Rscript -e 'rcmdcheck::rcmdcheck(args = "--no-manual", error_on = "warning")'
      2 errors | 1 warning | 0 notes  -- identical to the branch's own recorded
      baseline and to main's. ERRORs: the 8 test failures, and two vignettes
      (migrating-to-sdp-0-3-0.Rmd, tidy-data-for-sdp.Rmd). WARNING: "checking R
      files for syntax errors", whose body is
      `OS reports request to set locale to "en_US.UTF-8" cannot be honored` --
      an environment fact about this machine, not about the code.
      `checking R files for non-ASCII characters ... OK`

    git diff --check      clean
    non-ASCII in added R lines: none (grep -P '[^\x00-\x7F]' over the diff, and
      over both R files whole)

**Local R is 4.3.3 here.** `AGENTS.md` measures CI on 4.6.1 and warns that a
green local check is evidence about this R and not CI's, and the gap is larger
than the one that paragraph was written about. Every added R line was checked for
non-ASCII by grep as well as by `R CMD check`, because that is exactly the check
the older R was measured passing while a newer one warned.

## Claim and heartbeat

Not touched. `refs/heads/claim/B-116` in the locks repository has a `handoff`
tip from agent `a-2da3cb6cd51c4da7`, and hand-back deliberately does not release
the claim, so the item is still held and still unclaimable. This round was run
under a different session key and did not claim, beat, release or hand off; a
beat from a token that does not hold the claim would be a false record.

### Collation guard, updated with this round

`collation_sensitive_fns` in `tests/testthat/test-collation-guard.R` gained
`.ms_closure_incomplete_row` and `.ms_search_failed_sources`. That list is what
keeps the guard from decaying, and the rule for adding to it is the reason both
qualify: each ordering is read back by something other than a human. The
`missing_fields` cell is returned by an exported function and compared by a test;
the failed-source vector reaches an abort message and is compared by the caller
that decides whether any file is written. `.ms_closure_bytes_sha256()` needs no
entry: `byte_producing_pattern` matches `_sha256` and catches it by name.

### Mirror: what this round added to the owed port

The port of `write_sdp_semantic_closure()` to metasalmonpy was already specified
under *What metasalmon 0.5.0 owes the mirror* in `knowledge/parity-deviations.md`
and in the roadmap release index, and it was specified against the behaviour these
findings changed. Both copies now carry the three additions, in the same change,
which is the rule the release index states: a degraded lookup aborts rather than
becoming a gap; incomplete evidence is not a missing term; the three writes
install as one link-refusing set. Each is a way of getting the *ruled* gap-not-
abort shape wrong while appearing to implement it, which is exactly why it is
written down rather than left to be re-derived.

Still no queue item for the port. It is a new-item candidate above, unchanged.

### CI state at the end of this round, and what it is not

**No workflow run exists for any of this round's commits, and that is not a
failure — it is an absence of evidence, which is a different thing and has to be
reported as one.** The three pushes here are authored and pushed by the `claude`
app identity; every earlier run on this branch has `triggering_actor:
Br-Johnson`, and GitHub does not start `pull_request` workflows for a push made
with an app installation token. `total_count` for this branch stayed at 6 across
three pushes and forty minutes.

So the last CI data point on pull request #121 is the previous head, `5ad5c09`,
where all three checks were green. **That says nothing about `fe0fcfb`.** The
two checks that could plausibly have moved were run by hand instead, and both
are the real CI invocation rather than a proxy for it:

    python3 scripts/check-parity-registers.py knowledge/parity-deviations.md \
      ../../metasalmonpy/PARITY.md
      -> parity registers agree: 61 rows, 1-61 with no gaps
      (the exact command `parity-registers.yaml` runs; this round added prose to
       that file and no numbered rows, which is why it still agrees)

    METASALMONPY_PATH=<sibling> Rscript -e '... test-parity-register-guard.R'
      -> failed 0, error 0, skipped 0, passed 1
      (live rather than skipping, which is the state R-CMD-check.yaml arranges)

`R-CMD-check` itself cannot be reproduced here: CI runs a newer R, and on this
machine's R 4.3.3 the suite reports 8 failures and 2 vignette errors that CI's R
does not. Re-running it on a push CI has not seen would prove nothing about CI.
**Someone with push rights that trigger Actions should re-run the checks on
`fe0fcfb` before this merges.**
