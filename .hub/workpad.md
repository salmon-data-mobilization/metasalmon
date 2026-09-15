# Workpad — B-111

## Queue item

**B-111** — Make `create_sdp()`'s three create-owned sidecar writes atomic
(legacy #111, repo metasalmon, severity P2, venue claude-code). Claimed by
`a-26a2b46d7750d590` on 2026-09-14; work branch
`agent/B-111/a-26a2b46d7750d590`, worktree
`hub-worktrees/salmon-data-mobilization-metasalmon-B-111`.

Retires when: `.ms_replace_create_output()` has no callers and a test injects an
abort into each of the three rewrites and finds the prior file intact.

**Both halves are met.** The helper is deleted, not left callerless (reasoning
below), and `tests/testthat/test-create-sdp-sidecar-atomicity.R` injects an
abort at each of the three render steps and asserts the prior file is
byte-identical afterwards. All three failed on the pre-fix code — where the file
was not truncated but **absent** — and pass on the post-fix code.

*(This file is the single `.hub/workpad.md` the protocol names, so it replaces
B-49's, as B-49's replaced B-95's. The earlier reports live on in git history and
in their merged pull requests.)*

## What changed, and where

- `R/package-helpers.R`
  - **Deleted `.ms_replace_create_output()`.** See the delete-or-keep decision
    below.
  - `.ms_write_sdp_review_readme()` renders `README-review.txt` to bytes with
    `.ms_sdp_extension_text_bytes()` and installs them with
    `.ms_sdp_extension_atomic_write()`.
  - `create_sdp()`'s `semantic_suggestions.csv` write renders with
    `.ms_sdp_extension_csv_bytes(review_suggestions, na = "")` — the same
    `na = ""` the `readr::write_csv()` call it replaced used — and installs
    atomically. **The removal branch is unchanged**: when there is no shortlist
    the file is still deleted with a plain `unlink()`, because deleting is
    already atomic and the atomic write set has no delete operation.
  - `create_sdp()`'s EDH XML write renders with `.ms_edh_hnap_xml_bytes()` and
    installs atomically. One added line, `dir.create(dirname(edh_xml_path), ...)`,
    because `edh_build_hnap_xml()` used to create `metadata/` as a side effect of
    writing there and the atomic writer refuses to create a target directory.
  - Comment at the `.ms_assert_managed_path_contained()` call recording that the
    three are **three transactions, not one set** (reasoning below).
- `R/sdp-extension-helpers.R`
  - New `.ms_sdp_extension_text_bytes()`, beside the existing `_csv_bytes()` and
    `_json_bytes()` renderers.
  - Comment at the staging `tempfile()` in `.ms_sdp_extension_atomic_write_set()`
    recording why the stage is a sibling of the target, why hard links need no
    separate guard (the retired helper's whole rationale), and what the rename
    does *not* buy.
- `R/edh-xml-export.R`
  - New `.ms_edh_hnap_xml_bytes()`, immediately after `edh_build_hnap_xml()`.
- `tests/testthat/test-create-sdp-sidecar-atomicity.R` — new, 30 assertions:
  three abort-injection tests, a happy-path byte and no-stray-file test, and a
  structural guard.
- `NEWS.md` — entry under the development version's `### Fixed`.
- `knowledge/backlog.md` — #111's entry records that both halves of its
  retirement condition are met, what the fix measured, and the `fsync` scope
  limit. The dated `#96` sentence saying the sidecars "still go through
  `.ms_replace_create_output()`" is annotated rather than rewritten, because its
  point is about scope and it is dated evidence.
- `knowledge/parity-deviations.md` — row 53 updated. See the mirror note below.

### Why the bytes are rendered through the writer each file already used

`writeLines(useBytes = TRUE)`, `readr::write_csv(na = "")` and
`edh_build_hnap_xml()` respectively, each into a staging file whose bytes are
read back. Not `charToRaw(paste(...))` and not the `xml` string
`edh_build_hnap_xml()` returns: `as.character(root)` is not
`write_xml(root, options = "format")`, and `paste()` re-encodes, which matters
because the README interpolates a user-supplied `dataset_id`. The existing
`.ms_sdp_extension_csv_bytes()` is the in-repo precedent for the pattern, and
`.ms_datapackage_json_bytes()` carries the same reasoning for the descriptor.

**Verified rather than argued**: md5 of all three sidecars, from a full
`create_sdp(include_edh_xml = TRUE)` run on identical inputs, pre-fix and
post-fix.

| file | pre-fix (HEAD `4cd085c`) | post-fix |
|---|---|---|
| `README-review.txt` | `328621943e64c8920da992642cde30cd` | identical |
| `semantic_suggestions.csv` | `7519d63e2e53352dfbd2e2695d3f6d50` | identical |
| `metadata/metadata-edh-hnap.xml` | `9d17f1731c0a671a2882d70e64e1388a` | identical |

### Why three transactions rather than one atomic write set

The backlog entry offers `.ms_sdp_extension_atomic_write_set()` for the
multi-file case. Three separate single-file installs were chosen instead, for
three reasons that agree:

1. The harm #111 names is a **destroyed** file, not a partially-updated group.
   Render-then-install removes it for each file independently.
2. The three are written at different points in `create_sdp()`, with the EDH
   review-state warning between the install and the end of the block. Grouping
   them would reorder observable cli output.
3. The suggestions path can **delete** rather than write, and the write set has
   no delete operation, so one of the three could not join the set anyway.

A grouped write would additionally prevent "README updated, EDH render aborts,
EDH left at the old content". That is a partial update of independent files that
a re-run fixes, not data loss, and it is outside this item's retirement
condition. Recorded here so the next reader does not have to re-derive it.

### Delete or keep `.ms_replace_create_output()` — deleted

Deleted. It is guard-shaped: its comment explains a hard-link protection and
says outright that the protection "belongs next to each write, not in one
caller, so it holds however the writer is reached". Left callerless, that reads
as a live protection a future author is invited to call — which reintroduces the
exact unlink-then-rewrite shape this item removes. That is the
`migrate_sdp_methods()` duplicate-placement-guard hazard `AGENTS.md` names, and
it is worse here, because the dead call would look like the *safe* choice.

Its rationale is genuinely subsumed rather than merely outweighed: a
staged-sibling rename never opens the destination, so an external hard link
keeps its inode and its content. The rationale is not discarded with the code —
it now sits on the atomic writer's staging line, where someone asking "what
about hard links" will look. **The existing hard-link test
(`tests/testthat/test-package-helpers.R:3753`) passes unchanged**, and it is not
skipped on this machine: `file.link()` is supported here, verified directly, and
the external file still reads `PRECIOUS EXTERNAL CONTENT` after the README is
regenerated.

Nothing is left with no callers, so there is no dead guard here needing a
retirement condition of its own.

## What the word "atomic" does not cover here

`.ms_sdp_extension_atomic_write_set()` stages in the target's **own directory**,
so the install is a same-filesystem rename and not a cross-device copy — the
first half of the brief's warning is satisfied. The second half is not:
`writeBin()` is never followed by an `fsync`, because base R exposes none. So
the write is atomic against an **aborted call**, which is every abort point #111
and #96 enumerate, and **not durable against a machine crash or power loss**,
where a visible rename can outrun the staged data blocks.

This is pre-existing, unchanged by this item, and true of every caller of that
writer, so closing it is a decision about the writer rather than about
`create_sdp()`. It is stated in three places rather than implied: the writer's
own comment, the `NEWS.md` entry, and #111's backlog entry. Filed as a candidate
item below rather than absorbed.

## Commands run, and their results

### Failing-before — the new test file against pre-fix code (HEAD `4cd085c`)

```
Rscript -e 'pkgload::load_all("."); testthat::test_file(
  "tests/testthat/test-create-sdp-sidecar-atomicity.R", reporter = "summary")'

create-sdp-sidecar-atomicity: ..1..2..3...

-- 1. Failure (...:106:3): an abort rendering README-review.txt ...
Expected `sidecar_bytes(readme)` to be identical to `before`.
  `actual` is NULL
  `expected` is a raw vector (53, 61, 6c, 6d, 6f, ...)
-- 2. Failure (...:144:3): an abort rendering semantic_suggestions.csv ...
  `actual` is NULL
-- 3. Failure (...:171:3): an abort rendering metadata-edh-hnap.xml ...
  `actual` is NULL
```

`actual is NULL` is the whole finding: the sidecar is not truncated, it is
**gone**. Three injections, three destroyed files. The happy-path test in the
same file passed on the pre-fix code, which is why nothing in the suite noticed.

The abort is injected at each sidecar's **render** step — `writeLines`,
`readr::write_csv` keyed on the frozen 19-column target row, and
`edh_build_hnap_xml` — because that is where the real abort points are and
because the render is the one hook the old and the new code share. An injection
at the *install* step would pass on the pre-fix code and prove nothing.

### Passing-after (post-fix code)

```
create-sdp-sidecar-atomicity: ..............................
== DONE ==      (30 assertions, 0 failures)
```

### The structural guard, RED-verified in both halves

In a throwaway copy of the tree:

- suggestions write reverted to `readr::write_csv(review_suggestions, ...)` ->
  `Expected create_sdp() body contains direct filesystem call write_csv( to be FALSE.`
- README write reverted to `writeLines(...)` ->
  `Expected .ms_write_sdp_review_readme() body contains direct filesystem call writeLines( to be FALSE.`
- `unlink()` delete branch removed ->
  `Expected create_sdp() still needs the unlink( exemption to be TRUE.`

The last is the check that the exemptions are *reached*. An exemption for a call
that is no longer there is a hole nobody can see.

### Full suite

```
Rscript -e 'devtools::test()'
this branch:   [ FAIL 8 | WARN 38 | SKIP  9 | PASS 3898 ]
HEAD 4cd085c:  [ FAIL 8 | WARN 41 | SKIP  8 | PASS 3857 ]   (max_fails raised to Inf)
```

Two differences in the tallies are the baseline's, not the branch's, and both
were chased rather than waved at. The three extra `WARN` on HEAD are
`test-theme-a-benchmark.R` failing to read git state, because that baseline is a
`git archive` extract with no `.git`. The extra `SKIP` on this branch is
`test-parity-register-guard.R:55:5`, which skips when metasalmonpy is not checked
out beside the repository -- it is not, next to a worktree -- and whose own header
says a skip is not agreement. **It was therefore run by hand** rather than left
skipped, since this branch edits one of the two registers:

```
python3 scripts/check-parity-registers.py knowledge/parity-deviations.md \
  <metasalmonpy checkout>/PARITY.md
parity registers agree: 61 rows, 1-61 with no gaps       # exit 0
```

**The same 8 failures by identity on both**, and every one is this machine
rather than the code:

| failure | cause |
|---|---|
| `test-github-helpers.R:161:3`, `:264:3` | network — HTTP 404 through the proxy |
| `test-iri-predicates.R:39,52,57,104` | this R's TRE whitespace class accepts `ideographic_space` |
| `test-dictionary-helpers.R:224:3` | locale — `en_US.UTF-8` unavailable here |
| `test-review-console.R:231:3` | same locale, box-drawing characters |

### R CMD check

```
Rscript -e 'rcmdcheck::rcmdcheck(args = "--no-manual", error_on = "warning")'
this branch:   Status: 2 ERRORs, 1 WARNING   [ FAIL 8 | WARN 38 | SKIP 27 | PASS 3832 ]
HEAD 4cd085c:  Status: 2 ERRORs, 1 WARNING   [ FAIL 8 | WARN 38 | SKIP 27 | PASS 3802 ]
```

Identical outcome and identical failure identities; `PASS` differs by exactly
the 30 assertions the new file contributes. The two
ERRORs are two vignettes reading `weir-counts-sdp/metadata/tables.csv` and
`escapement-sdp/metadata/tables.csv` relative to a temporary vignette directory;
the WARNING is `Sys.setlocale("LC_CTYPE", "en_US.UTF-8")` failing. Both are
present on HEAD and neither is touched here.

**A green local check is evidence about this R, not CI's.** `R.version.string`
here is **R 4.3.3**; `AGENTS.md` records CI on **R 4.6.1**. The non-ASCII check
is the one that has bitten this repo across versions, so it was checked directly
rather than inferred: every line this branch adds to `R/` is ASCII
(`grep -P '[^\x00-\x7F]'` over the added lines returns nothing), and the
pre-existing non-ASCII in `package-helpers.R` is all comments and roxygen, which
are exempt.

```
git diff --check      # clean, exit 0
```

`devtools::document()` was not run: nothing added is roxygen-documented (all new
helpers are internal `#`-commented `.ms_` functions), and `R CMD check` reports
`checking Rd files ... OK` with no undocumented-object note.

## What I did not do, and why

- **The metasalmonpy half.** The same three writes have the same shape there,
  with a wider EDH window (`_replace_create_output()` then a full
  `read_salmon_datapackage()` from disk before building). Already registered as
  parity row 53, whose retirement condition said in advance that it would
  **not** close when #111's R half closed. Out of scope; candidate item below.
  Row 53 *was* updated, because its text described the defect as present "on
  both sides" and that becomes false on merge — leaving it would put a false
  statement in the register the mirror contract depends on.
- **`R/metadata-write.R` and `R/sdp-methods.R` were not touched.** B-115 and
  B-112 are in flight in this repository and both touch metadata/descriptor
  writing. Neither file was needed here.
- **The `fsync` durability gap**, above. Filed, not absorbed.
- **Grouping the three writes into one transaction.** Reasoned and declined
  above rather than overlooked.
- **The `Open:` list in `knowledge/backlog.md`'s top-of-file snapshot still
  lists #111.** Deliberately not edited: it is an explicitly dated snapshot
  ("re-audited 2026-08-21"), the queue item file is the state authority, and
  `HUB.md` says a card restating queue state is the copy that is wrong. Editing
  it would maintain the duplication rather than the fact.

## Guards, suppressions and skips added, with retirement conditions

1. **The structural guard** in
   `tests/testthat/test-create-sdp-sidecar-atomicity.R` ("no create-owned
   sidecar is written by a direct filesystem call"). Scope stated inside the
   test: exactly `create_sdp()` and `.ms_write_sdp_review_readme()`, the two
   functions that write the three sidecars. A sidecar write moved into a third
   function escapes it, and the test says so and says to add that function.
   *Retires when:* the three sidecars are rendered into one write set that owns
   the only filesystem handle, making a stray direct write unrepresentable — or
   when `create_sdp()` stops writing files of its own.
2. **Two token exemptions inside that guard**, `unlink(` and `dir.create(`, each
   with its reason in the test body, and each asserted to be *reached* so a
   stale exemption cannot become an invisible hole. They retire with the guard.
3. **The `fsync` note** on `.ms_sdp_extension_atomic_write_set()`'s staging
   line. Not a suppression, but a documented limitation, and it carries a
   condition: *retires when* the package can fsync a file, at which point the
   stage is synced before the rename and the note loses its second half.

No test was skipped, no check suppressed, no allowlist entry added.

## Belongs to another item

- **Parity row 53 — the metasalmonpy half of #111.** A register row, not a queue
  item, as of this hand-back, so it is named here for promotion rather than
  absorbed. The work: route metasalmonpy's three create-owned sidecar writes
  through `atomic_io.py`, and make its EDH path build in memory or become
  transactional, with three abort-injection tests mirroring this branch's. The
  one thing a port must get right: **inject the abort at the render, not at the
  install.** An injection at the install passes on the unfixed code and proves
  nothing, which is why the tests here mock `writeLines`, `readr::write_csv` and
  `edh_build_hnap_xml` rather than the atomic writer. Row 53 now records this.
- **metasalmonpy's `PARITY.md` row 53 is now the stale half of the twin pair,
  and this is the mirror contract's own named failure mode.** Its text says the
  defect is present "on both sides" and cites `R/package-helpers.R:1387-1392` for
  a `.ms_replace_create_output()` call that no longer exists. The hub-side row was
  corrected here; the twin's cannot be, because the work-branch grant is scoped to
  the repository the item names and this item names metasalmon. So on merge the
  two registers disagree about which side is defective, which is exactly the
  "one of them is wrong and nothing in either file says which" shape `AGENTS.md`
  warns about. **It needs to land with the port, or before it.** Flagged rather
  than fixed, and flagged loudly because a reader of the twin alone would
  conclude the R half is still open.

## Candidate new items (no queue id)

- **`.ms_sdp_extension_atomic_write_set()` does not fsync the staging file
  before the rename.** Evidence: `R/sdp-extension-helpers.R`, the
  `writeBin(writes[[index]], stages[[index]])` call, with no sync before
  `file.rename(stages[[index]], path)`. Atomic against an aborted call, not
  durable against a machine crash, where a visible rename can outrun the staged
  data blocks. Base R exposes no fsync, so closing it means compiled code or a
  new dependency — which is why this is a decision rather than a fix, and why it
  is `claimable: false` material. Blast radius is every caller of that writer:
  `create_sdp()`'s three sidecars, `write_salmon_datapackage()`, observation
  structures, KNB publication, reproducibility manifests, measurement
  decompositions. Suggested severity P3 — the failure needs a crash rather than
  an error, and the package's documented contract (#96, #111) is about aborts.
  Mirror half applies: `atomic_io.py` should be checked for the same gap, where
  Python *does* have `os.fsync`, so the two sides may already differ in
  durability without either register saying so.
- **Two vignettes fail `R CMD check`'s "running R code from vignettes" step on a
  clean tree**, at HEAD and on this branch alike: `migrating-to-sdp-0-3-0.Rmd`
  reads `weir-counts-sdp/metadata/tables.csv` and `tidy-data-for-sdp.Rmd` reads
  `escapement-sdp/metadata/tables.csv`, each relative to the temporary vignette
  directory the tangled code runs in, where the package an earlier chunk created
  does not exist. Both chunks are `eval = FALSE` in the rendered vignette, so
  the article reads correctly and only the tangle-and-source step fails — which
  is why this has gone unnoticed. It is two ERRORs on every local `rcmdcheck`
  run, so nobody can use a clean check as a signal here without knowing to
  discount them, which is the real cost. Suggested severity P3. Not adjacent to
  this item.
