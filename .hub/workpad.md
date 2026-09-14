# Workpad — B-112

## Queue item

**B-112** — "Return the three-column report frame from `migrate_sdp_methods()`'s
no-op branch" (legacy `#112`, repo metasalmon, stream S10, severity P3, venue
`claude-code`). Claimed by `a-677b1b31606aaa8c` on 2026-09-14; work branch
`agent/B-112/a-677b1b31606aaa8c`, worktree
`hub-worktrees/salmon-data-mobilization-metasalmon-B-112`. Session key
`fleet-2026-09-14-B-112`. Evidence: the `#112` entry in `knowledge/backlog.md`.

Scope is the item's `retires_when`, read literally: the nothing-to-migrate early
return builds the same three-column empty frame the other exits build, and a
test pins the column set of both branches. **Brett ruled the three-column shape
on 2026-09-14, for both implementations**, so the shape was not an implementer's
choice and the alternative — a logged ruling that the shapes deliberately differ
— is closed. The mirror half is **B-144** and was not touched.

## What changed and where

Three files, 96 insertions, 1 deletion.

### `R/sdp-methods.R` — the one-branch fix

The nothing-to-migrate early return built `report$tables` as a two-column frame,
`table_id` and `method_iri`. It now builds the same three columns the other two
exits build, adding `columns`. The item's line numbers were verified against the
current file before editing, as it asked; all three were accurate.

| exit | lines (current file) | before | after |
|---|---|---|---|
| nothing-to-migrate early return | `R/sdp-methods.R:298-311` | 2 columns | **3 columns** |
| populated build | `R/sdp-methods.R:343-347` | 3 columns | unchanged |
| no-placement empty frame | `R/sdp-methods.R:366` | 3 columns | unchanged |

The dry-run return (`:455`) and the final return (`:589`) both read
`placements`, so they inherit the populated / no-placement shape and needed no
change. That is why there are three builders and not five.

**The empty column's type is `character()`, and it is the populated branch's
type rather than a default.** The populated build renders `columns` with
`paste(sort(rows$column_name, method = "radix"), collapse = ", ")`, which is a
length-1 character vector, and the no-placement branch already declared
`columns = character()`. So `character()` is the only choice that lets a caller
`bind_rows()` the reports of two runs without coercing the column. The type is
asserted for all three exits in the test rather than left implied, and the
reason is recorded in a comment at the fix.

### `tests/testthat/test-sdp-methods.R` — the pin

One new `test_that()` block, "every migrate_sdp_methods() exit reports the same
three table columns", placed after the REVIEW:-only test so all three fixtures
it uses are introduced above it.

It pins **all three** exits, not the two the item requires. The item asks for
both branches because pinning only the branch that was fixed leaves the
populated branch free to drift away from it; the third exit was one more fixture
in the same block, so it is cheap and strictly better. For each exit it asserts:

- the column set, via `expect_named()`, which compares order as well as
  membership — so a reordered build fails here too;
- the `character` type of `columns`;
- the row count, so the column-set assertion cannot be satisfied by an exit that
  gained the column by gaining a row it should not have.

### `NEWS.md` — the entry

One bullet under the development version's `### Fixed`. Required: this is an
observable behaviour change for a caller reading the report frame. It records
that the frame is empty either way, so nothing reading `nrow()` changes and only
the column set does; that the three-column shape is the one the migration
vignette already documents; Brett's 2026-09-14 ruling; that the mirror half is
B-144; and that `#112`'s retirement condition is met only on the R side until
B-144 lands.

## Commands run, and their results

### Failing-before / passing-after

A reproduction script (scratchpad, not committed) drives all three exits through
`create_sdp()` fixtures and prints the column set, the row count, and the type
of `report$tables$columns`.

**Before, on the unmodified source:**

```
--- BRANCH 1 nothing-to-migrate early return ---
names(report$tables): table_id, method_iri
nrow:                 0
report$tables$columns is NULL: TRUE
class(report$tables$columns): NULL
Warning messages:
1: Unknown or uninitialised column: `columns`.
2: Unknown or uninitialised column: `columns`.

--- BRANCH 2 populated build ---
names(report$tables): table_id, method_iri, columns
class(report$tables$columns): character

--- BRANCH 3 no-placement return ---
names(report$tables): table_id, method_iri, columns
class(report$tables$columns): character
```

`NULL` on the clean-package path, confirmed, with tibble's own "Unknown or
uninitialised column" warning on the read — the defect the item describes, and
the branch where the package was already clean.

**After:** all three branches print
`names(report$tables): table_id, method_iri, columns` and
`class(report$tables$columns): character`. The tibble warnings are gone.

### The new test demonstrated RED

Run against the unfixed source, with the fix stashed and the test in place:

```
== Failed ==
-- 1. Failure ('test-sdp-methods.R:524:3'): every migrate_sdp_methods() exit rep
Expected `clean$tables` to have names `expected`.
Differences:
`actual`:   "table_id" "method_iri"
`expected`: "table_id" "method_iri" "columns"

-- 2. Failure ('test-sdp-methods.R:532:3'): every migrate_sdp_methods() exit rep
Expected `clean$tables$columns` to have type "character".
Actual type: "NULL"
```

Both assertions fail on the clean-package exit and neither fails on the other
two, which is the shape the item predicts. A pin that has not been shown to fail
is not evidence that it pins anything.

### Fast loop

`testthat::test_file("tests/testthat/test-sdp-methods.R", reporter = "summary")`
— 98 passes, no failures, no warnings, no skips.

### Full suite

`Rscript -e 'devtools::test()'` — `[ FAIL 8 | WARN 38 | SKIP 9 | PASS 3877 ]`,
exit 0.

**All 8 failures are pre-existing and environmental, and that was measured, not
assumed.** The four affected files were re-run with this branch's changes
stashed; the baseline produces the identical 8 failures at the identical
locations:

| failure | owner |
|---|---|
| `test-dictionary-helpers.R:224:3` | **B-137** (locale) |
| `test-iri-predicates.R:39:5`, `:52:5`, `:57:5`, `:104:5` | **B-137** (locale) |
| `test-review-console.R:231:3` | **B-137** (locale) |
| `test-github-helpers.R:161:3`, `:264:3` | new-item candidate, below |

Six of the eight are queue item **B-137**, "Six tests depend on a UTF-8 locale
and fail under the C locale", whose `retires_when` names these exact six
expectations and predicts this container: *"the suite is green on CI's UTF-8
runner and red on any container without LANG set."* `locale -a` here offers only
`C`, `C.utf8` and `POSIX`, and `LANG` is unset. Nothing in `sdp-methods` fails.

### R CMD check

`Rscript -e 'rcmdcheck::rcmdcheck(args = "--no-manual", error_on = "warning")'`
— **`Status: 2 ERRORs, 1 WARNING`.** All three are pre-existing, each is owned
by an existing queue item or measured on the baseline, and none is caused by
this diff:

| finding | check step | owner / evidence |
|---|---|---|
| ERROR | `checking tests` — `[ FAIL 8 \| WARN 38 \| SKIP 27 \| PASS 3811 ]` | the same 8 as `devtools::test()`: 6 are **B-137**, 2 are the `test-github-helpers.R` candidate below |
| ERROR | `checking running R code from vignettes` — `migrating-to-sdp-0-3-0.Rmd` and `tidy-data-for-sdp.Rmd` | **B-133**, and reproduced on the unmodified baseline |
| WARNING | `checking R files for syntax errors` | environmental locale; see below |

**The vignette ERROR was measured on the baseline, not reasoned about**, because
one of the two failing vignettes is `migrate_sdp_methods()`'s own and that made
it the one finding here that could plausibly have been mine. The base commit
`4cd085c` was exported to a clean directory with `git archive` (its
`R/sdp-methods.R` verified to carry the unfixed two-column return) and
`tools::checkVignettes(tangle = TRUE, weave = FALSE)` produced the identical two
errors. **B-133** describes the mechanism exactly — each vignette sets
`eval = FALSE` from a setup chunk marked `purl = FALSE`, so `knitr::purl()` drops
that chunk and tangles every illustrative chunk as live code — and records that
it was "measured locally on R 4.3.3 ... and not reproduced on CI, whose newer R
passed". The logic agrees with the measurement: the migration vignette dies at
its own line 97, `readr::read_csv("weir-counts-sdp/metadata/tables.csv")`, and
the first `migrate_sdp_methods()` call in it is at line 263 — the script stops
166 lines before it reaches the function this branch changes. The second failing
vignette does not use `migrate_sdp_methods()` at all.

Two things about the WARNING worth keeping:

- `checking R files for non-ASCII characters ... OK`.
- `checking R files for syntax errors ... WARNING`, whose body is
  `Warning in Sys.setlocale("LC_CTYPE", "en_US.UTF-8"): OS reports request to
  set locale to "en_US.UTF-8" cannot be honored`. That is R CMD check's own
  locale switch failing in a container whose `locale -a` offers only `C`,
  `C.utf8` and `POSIX` — not a syntax error and nothing to do with this diff.
  Same root cause as B-137, though B-137's `retires_when` names six test
  expectations and not this check line.

**This machine runs R 4.3.3.** Per AGENTS.md a green local check is evidence
about this R and not CI's, and the 2026-08-25 episode — two `·` characters that
passed under R 4.5.2 locally and failed under R 4.6.1 on CI — is the precedent.
So the added lines were checked for non-ASCII directly rather than trusted to
the check: **every line this branch adds to `R/` and `tests/` is ASCII**. The
em-dashes that remain in `R/sdp-methods.R` and `test-sdp-methods.R` are all
pre-existing and all inside comments, which AGENTS.md exempts. The prose added
to `NEWS.md` is ASCII too.

### Whitespace

`git diff --check` — clean.

## What I did not do, and why

**`knowledge/parity-deviations.md` is untouched, and it carries a row this fix
makes stale.** Reported as a finding rather than fixed, for three reasons: the
item's `retires_when` does not mention the register; the shared brief says to
land a parity row in this pull request only *"if your item says the row lands
with each half"*, and this item does not say that; and B-111 is in flight in
this repository and has its own paragraph in that file, so editing it would risk
a conflict over a file I do not own. Specifics under new-item candidates, so
whoever takes B-144 can act on them.

**No `devtools::document()` run and no `man/` change.** The `@return` block for
`migrate_sdp_methods()` describes the three report parts without enumerating
`tables`'s columns, so this change does not make it wrong, and the migration
vignette (`vignettes/migrating-to-sdp-0-3-0.Rmd:375-384`) already prints the
populated `1 x 3` frame — so the fix makes the no-op branch agree with published
documentation rather than contradicting it. Adding a column list to the roxygen
would have regenerated all of `man/`, which with B-111 and B-115 in flight is a
larger and less reviewable diff than a P3 warrants.

**`metasalmonpy` is untouched.** The mirror half is **B-144**, a separate item,
where Python moves back to the three-column shape it had first. Under the
amended mirror contract (Brett, 2026-08-17) which side is right is a ruling and
not an implementer's call; Brett ruled the three-column shape on 2026-09-14, so
R is the side that moves and Python reverts the change it made at S10 chunk A to
mirror R's two-column frame. This is the contract's own example of the mirror not
being automatically the follower.

**One process note, recorded because it touched files outside this item even
though nothing of it survives.** While setting up the baseline vignette
comparison I ran `git stash push -- R/sdp-methods.R` after the work was already
committed, so it stashed nothing, and the following `git stash pop` reached the
repository's **pre-existing** entry instead — `stash@{0}`, *"On
claude/blissful-shannon-ag9jec: evidence-pointer edits duplicating PR #110"*.
The pop conflicted and left seven `queue/items/*.yaml` files in a conflicted
working-tree state. It was reverted with `git reset --hard HEAD`, which was safe
because every change of mine was already in the commit. **That stash entry was
not dropped and is still present and unchanged** — git kept it because the pop
failed — and `queue/items/` is untouched in this branch's diff. The baseline
comparison was then redone the correct way, on a `git archive` export of the base
commit into a scratchpad directory, which is what the R CMD check section above
reports.

**The AGENTS.md duplicate-placement-guard note is already resolved — checked,
not assumed.** AGENTS.md records that `migrate_sdp_methods()` once carried
duplicate placement guards that became unreachable when the real checks moved
earlier, leaving dead code that invited someone to weaken the live copy. Both
guards now appear exactly once each (`R/sdp-methods.R:441` and `:448`, before
the dry-run return), and the comment at `R/sdp-methods.R:462-465` records the
absence deliberately: *"a repeat of those checks here would be unreachable.
Deliberately not duplicated: a dead guard invites someone to weaken the live
one."* Nothing to fix and no new item needed.

## Belonging to another item

- **B-144** — the mirror half of this item, in metasalmonpy. Not touched.
- **B-137** — six of the eight full-suite failures on this machine. Not touched.
- **B-111**, **B-115** — worked in parallel by other agents in this repository.
  The only file this branch touches that they plausibly also touch is `NEWS.md`,
  where this entry was appended at the end of the development version's
  `### Fixed` section. A textual conflict there is possible and resolves by
  keeping both bullets.
- **B-133** — the vignette-tangle ERROR in `R CMD check`. Not touched.
- **B-132** — the nearest existing item to new-item candidate 2 below, but a
  different pair of tests, so the candidate is not part of it.

## New-item candidates

### 1. `parity-deviations.md` row 9 claims the migration is "mirrored 1:1", and this fix makes that false

Row 9 (`knowledge/parity-deviations.md:60`) reads: *"The migration itself is
mirrored 1:1 against metasalmon `main` (`e02111a`) — nine-case differential,
identical stop taxonomy, byte-identical rewrites."* The report shape is exactly
what changed, so from this merge until B-144 lands, R returns three columns from
the no-op exit and Python two.

This is the shape that file already documents at length for `PARITY.md` row 31:
*"Nothing over there will announce it, because the row still reads as a passing
verification — which is the worst shape a stale register row can take."* Row 9's
claim is at least pinned to a named commit, which is honest dating, but a reader
asking "is the migration mirrored?" reads "mirrored 1:1" and stops.

The file has an established pattern for exactly this, in its "what the port owes"
section (`knowledge/parity-deviations.md:150-171`): a dated paragraph naming the
queue item and stating outright that the port is a separate queue item **rather
than a deviation row**. Two paragraphs already follow it, for B-124 (#111) and
B-125 (#95). Recommendation: a third paragraph in the same shape naming
**B-144**, landed by B-144 itself or as a small follow-up, plus an amendment to
row 9's "mirrored 1:1" clause **in place** rather than a new row beneath it —
which is that file's own stated reasoning for row 31.

### 2. Two `test-github-helpers.R` tests error instead of skipping when the raw host is unreachable but the API host is

`test-github-helpers.R:161:3` and `:264:3` fail with
`Error in httr2::req_perform(req): HTTP 404 Not Found`. The cause is a mismatch
between what the skip guard probes and what the code under test fetches: the
guards at `test-github-helpers.R:144-160` probe reachability with `gh::gh()`
against `api.github.com` and skip on error, but `read_github_csv()` resolves to
a `raw.githubusercontent.com` URL (`R/github-helpers.R:593`, reached through
`ms_github_get()` at `R/github-helpers.R:227` and `:618`). Where the API host
answers and the raw host does not, the guards pass and the fetch then errors.

Same defect shape as **B-132** ("The live upstream SDP bundle test errors
instead of skipping when the fetch is slow or offline") but a different pair of
tests, so it is a candidate rather than part of B-132. A fix would probe the URL
the code actually fetches, or turn the 404 into a skip. *Retires when:* the
tests stop reaching the network at all, for example against a recorded fixture.

## Retirement conditions of what this branch adds

One test. No suppression, no exclusion, no allowlist entry, no skip and no
workaround — nothing here silences a signal, so there is nothing that could
outlive its cause and conceal a failure. The test states its own condition in
its header comment:

> *Retires when:* `migrate_sdp_methods()` stops returning a `tables` frame, at
> which point there is no shared column set left to pin.

The **item's** retirement condition is met on the R side by this branch: the
early return builds the three-column frame, and a test pins the column set of
both branches the condition names, plus the third. It is met in full only when
**B-144** lands the same shape in metasalmonpy.
