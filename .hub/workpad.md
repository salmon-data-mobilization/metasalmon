# B-115 — Emit readr's ISO instant spelling for a descriptor POSIXct

Queue item: `queue/items/B-115.yaml` (P2, defect, metasalmon).
Evidence: the `#115` entry in `knowledge/backlog.md`.
Branch: `agent/B-115/a-147884b197789962`. Session key `fleet-2026-09-14-B-115`.

## The baseline I decided this renderer sits on, and why

The item required this to be named before changing anything, so it is first.

**The descriptor's temporal writer moves onto the `readr::write_csv()` baseline.**
It sat on the `as.character()` baseline (via `.ms_iso_character()`), and that is
the whole defect: one value — `dataset_meta$temporal_start` — lands in two files,
and the two files had two baselines.

The reason the descriptor is the side that moves, rather than the CSV:

- `metadata/dataset.csv` is written by `readr::write_csv()`
  (`.ms_sdp_extension_csv_bytes()`), and that writer **cannot** move here.
  Coercing `POSIXct` on the way to it is the move backlog #93 item 1 ruled out,
  and this item forbids reopening it. So the CSV's baseline is fixed.
- Brett ruled the spelling on 2026-09-14 — readr's ISO instant form, the `T`
  separator and the `Z` zone marker — which is the CSV's baseline named.

`.ms_iso_date_columns()` is untouched. Its deliberate disagreement with
`.ms_canonical_character()` about a `POSIXct` survives, and the existing test
that asserts the two disagree **on purpose** stays green (verified below).

## What I changed and where

1. **`R/platform-time.R`** — new `.ms_readr_instant_character()`: the bytes
   `readr::write_csv()` writes for an instant, obtained **by asking readr**
   (`readr::format_csv()` on a one-column frame) rather than by reproducing it.

   Asking rather than reproducing is the load-bearing choice. A hand renderer,
   `format(x, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")`, was measured equal to readr on
   every case tried — years 1 and 999, a fractional second, midnight, three
   timezones — and it would still be a **second rendering of one value**, which
   is the defect `AGENTS.md`'s "one value, one rendering" contract names rather
   than a way of fixing it. Sharing readr makes the two files agree *by
   construction* instead of by an agreement nothing rechecks. Reproducing it also
   means reproducing three silent-when-wrong behaviours: conversion to UTC (a
   `tzone` of `America/Vancouver` shifts the clock, not just the marker),
   truncation of a fractional second, and the year.

2. **`R/platform-time.R`** — corrected the comment above `.ms_iso_date_columns()`.
   It asserted `write_csv POSIXct year 1 #> "0001-01-01T00:00:00Z" <- ALREADY
   padded` and "readr's instant path is correct already". **That is a macOS-only
   measurement and is false on Linux** (see the finding below). #93 item 1's
   *ruling* is untouched — I restated its real justification (coercing an instant
   changes three fields) so it no longer rests on a claim that is not true on the
   platform CI runs on.

3. **`R/metadata-write.R`** — `.ms_descriptor_temporal_text()`, called at the two
   temporal sites. `POSIXt` goes to readr; **every other type keeps
   `.ms_iso_character()` unchanged**. Deliberately narrow: widening this to
   "whatever readr would write" would move the descriptor for character input
   too, which is a different question from the one that was ruled.

4. **`tests/testthat/test-canonical-date-render.R`** — two tests appended, in the
   shape the `Date` test at the old line 246 uses.
5. **`NEWS.md`** — entry, stating that this is not a wire-format break in the wild.
6. **`knowledge/parity-deviations.md`** — row 56 updated in place (see below).
7. **`tests/testthat/test-collation-guard.R`** — `.ms_descriptor_temporal_text()`
   and `.ms_readr_instant_character()` added to `collation_sensitive_fns`.
   **Added 2026-09-16, on a Codex P1 finding on pull request #118; the original
   pass missed it.** `AGENTS.md`'s C-collation contract states the maintenance
   rule — a function that produces canonical bytes, a hash, or a PID goes into
   that list, and the list is what keeps the guard from decaying — and
   `.ms_readr_instant_character()` is a canonical-byte producer by construction:
   its output is the descriptor's temporal text. **Both names are needed rather
   than either alone, and the reason is the guard's own stated limitation 3.**
   `.ms_descriptor_apply_dataset_meta()` was already listed and calls the
   dispatcher, which calls the renderer, but the guard does not traverse callees,
   so neither new function was inspected by anything; and neither name matches
   `byte_producing_pattern`, so the heuristic backstop in the second test does
   not reach them either. RED demonstration in the commands section below.

## Commands and results

R on this machine is **R 4.3.3 (2024-02-29)** — CI runs newer, so everything
below is evidence about 4.3.3.

### Failing before / passing after, on the backlog's fixture

Fixture: `temporal_start = as.POSIXct("0999-06-05 13:45:30", tz = "UTC")`,
`temporal_end = as.POSIXct("2024-12-31 00:00:00", tz = "UTC")`, through
`write_salmon_datapackage()`, both files read back.

Before:

```
descriptor start : 0999-06-05 13:45:30      csv start : 999-06-05T13:45:30Z
descriptor end   : 2024-12-31               csv end   : 2024-12-31T00:00:00Z
AGREE start: FALSE   AGREE end: FALSE
```

After:

```
descriptor start : 999-06-05T13:45:30Z      csv start : 999-06-05T13:45:30Z
descriptor end   : 2024-12-31T00:00:00Z     csv end   : 2024-12-31T00:00:00Z
AGREE start: TRUE    AGREE end: TRUE
```

The `end` row is the second half of the defect: `as.character()` drops the time
from an all-midnight instant, so the descriptor answered `2024-12-31` where the
CSV answered `2024-12-31T00:00:00Z`.

### RED demonstration of the new tests

New tests run against the pre-fix `R/` (changes stashed) — 4 failures + 1 error,
each naming the defect rather than an incidental difference:

```
1. descriptor$temporal$start  actual "0999-06-05 13:45:30"  expected "999-06-05T13:45:30Z"
2. descriptor$temporal$end    actual "2024-12-31"           expected "2024-12-31T00:00:00Z"
3. start does not match "^[0-9]+-06-05T13:45:30Z$"
4. end is not "2024-12-31T00:00:00Z"
5. object '.ms_descriptor_temporal_text' not found
```

GREEN after restoring: `canonical-date-render: ....... (46 assertions, 0 failures)`.

### RED demonstration of the collation-guard registration (2026-09-16)

**An allowlist entry that does not make the guard fail is decoration, so it was
demonstrated rather than asserted.** Four runs of
`testthat::test_file("tests/testthat/test-collation-guard.R")` on R 4.3.3, the
first of which is the state Codex's finding describes:

| # | Tree | Result |
|---|---|---|
| A | `lines <- lines[order(lines)]` injected into `.ms_readr_instant_character()`, the two names **absent** from `collation_sensitive_fns` | `collation-guard: .........` — **GREEN. The locale-dependent ordering is invisible.** |
| B | the same injected ordering, the two names **present** | **RED**, `.ms_readr_instant_character: order(lines)` |
| C | renderer restored; `value <- value[order(value)]` injected into `.ms_descriptor_temporal_text()`, names present | **RED**, `.ms_descriptor_temporal_text: order(value)` |
| D | both injections removed, names present | `collation-guard: .........` — GREEN |

Run A is the load-bearing one: it proves the entries are what makes the guard
inspect these functions, not the `byte_producing_pattern` heuristic and not
`.ms_descriptor_apply_dataset_meta()`'s already-present entry. Runs B and C
prove one entry each, so neither name is riding on the other. Both failures come
from the first test in the file (`test-collation-guard.R:194`), which is the
allowlist test rather than the name-heuristic one — the guard's own
self-detection test (`the collation guard detects an unqualified ordering`) stays
green throughout and is not what caught these.

### Full suite — no new failure, +12 assertions

| tree | result |
|---|---|
| clean `origin/main` | `[ FAIL 8 | WARN 38 | SKIP 9 | PASS 3868 ]` |
| with this change | `[ FAIL 8 | WARN 38 | SKIP 9 | PASS 3880 ]` |

The **same 8** failures in both, so none is mine:
`test-dictionary-helpers.R:224`, `test-github-helpers.R:161` and `:264` (both
`HTTP 404` from `httr2::req_perform`), `test-iri-predicates.R:39/52/57/104`,
`test-review-console.R:231`. They are network- and locale-dependent and are
**pre-existing on `origin/main`**; not investigated further, as they are outside
this item.

### `R CMD check` — identical to baseline

```sh
Rscript -e 'rcmdcheck::rcmdcheck(args = "--no-manual", error_on = "warning")'
```

| tree | result |
|---|---|
| clean `origin/main` | 2 ERRORs, 1 WARNING, 0 NOTEs |
| with this change | 2 ERRORs, 1 WARNING, 0 NOTEs |

So the check is unchanged by this work; it does not pass on either tree, on this
machine, for reasons that predate the change. The ERRORs are the 8 test failures
above. The WARNING is `checking R files for syntax errors ... WARNING` whose body
is `Sys.setlocale("LC_CTYPE", "en_US.UTF-8") ... cannot be honored` — a missing
locale in this container, not a code defect.

**`* checking R files for non-ASCII characters ... OK`** on both trees. The item
flagged this trap specifically; my R code is ASCII throughout, and the comment
dashes are `--` rather than em dashes to match `platform-time.R`.

```sh
git diff --check    # clean
METASALMONPY_PATH=/home/user/metasalmonpy python3 scripts/check-parity-registers.py
# -> parity registers agree: 61 rows, 1-61 with no gaps   (before AND after)
```

## The finding that outlived the item's premise

**`readr::write_csv()`'s instant year is not padded on every platform.** Measured
2026-09-14, Linux R 4.3.3 / readr 2.2.0:

| value | `write_csv()` | `as.character()` |
|---|---|---|
| `as.POSIXct("0999-06-05 13:45:30", tz="UTC")` | `999-06-05T13:45:30Z` | `999-06-05 13:45:30` |
| `as.POSIXct("0001-02-03 04:05:06", tz="UTC")` | `1-02-03T04:05:06Z` | `1-02-03 04:05:06` |

macOS R 4.5.2 / readr 2.2.0 wrote `0999-06-05T13:45:30Z` for the first. This is
the `%Y` platform split documented at the top of `R/platform-time.R` reaching
readr's own instant path.

Three consequences, all recorded in the code, `NEWS.md` and register row 56:

1. **The item's premise "that is what `metadata/dataset.csv` already writes" is
   macOS-only.** On Linux the CSV writes `999-…`, so before the fix *three*
   things disagreed here — separator, zone marker **and** year padding — where
   the backlog's macOS measurement saw only the first two and recorded "year
   padding **agrees**".
2. **I implemented the operative clause, not the parenthetical literal.** The
   item's requirement is "the same bytes `readr::write_csv()` emits for the same
   value", and its tested condition is that the two files agree. So the descriptor
   emits whichever year readr emits: on macOS that is exactly Brett's
   `0999-06-05T13:45:30Z`, and on Linux it is `999-06-05T13:45:30Z`, agreeing with
   the CSV on both. Padding only the descriptor to reach the literal would have
   made the required test fail on CI and **re-opened #115 on Linux** — worse than
   the byte it fixes. I did not touch the CSV side to pad it, because that is
   `.ms_iso_date_columns()` and #93 item 1.
3. **The standing comment claiming readr's instant path "is correct already" is
   now corrected**, because a guard or ruling resting on a stronger measurement
   than it has is the failure mode `AGENTS.md` names.

## Parity register — row 56 updated in place, no new number claimed

`knowledge/parity-deviations.md` **row 56 already is this defect**, and its
retirement condition was *"the SDP profile rules on the canonical lexical form for
a metadata instant; both sides adopt it and this row records the ruling"* — which
is precisely the ruling Brett made. So I updated row 56 rather than adding row 62:

- Row 56 now records the 2026-09-14 ruling, that **R moved**, that metasalmonpy
  owes the same move as **B-145**, and the year-padding residual B-145 must
  measure.
- Its retirement condition is sharpened: B-145 lands **and** the year residual is
  measured away or registered.
- **No number claimed**, following the register's own chunk-F precedent ("rewrote
  row 37 in place and claimed no number"). This keeps
  `scripts/check-parity-registers.py` green — it fails on a number present in one
  register and absent from the other, so claiming 62 here would hand B-145 a
  spurious failure for a fact row 56 already carries. Duplicating a fact across
  two rows is the defect this register's own history warns about.

The register's **port section** also gains a paragraph, because
`.github/PULL_REQUEST_TEMPLATE.md` distinguishes a *deliberate difference* (a
numbered row in both registers) from *a port that is owed* (tracked in the port
section, deliberately **not** a new row), and warns that recording a port as a
deviation is the failure that section exists to prevent — it tells the next
reader the difference was wanted, so nobody goes looking for the missing work.
This item is **both at once**, unusually: the port is owed as B-145, and row 56
already exists as the deviation row for the divergence B-145 will close. The new
paragraph says so explicitly, so nobody reads row 56's update as "the ecosystem
wants this difference".

`uv run --project ../psc-data-systems psc-okf check knowledge --tier capture` was
**not run**: no sibling `psc-data-systems` checkout exists in this environment. My
`knowledge/` edits are prose inside an existing card and contain no absolute
filesystem paths (checked).

**What B-145 needs to know, and it is not in the item:** R now follows readr's
platform-dependent year. Python's own renderers (`str()`/`isoformat()`) are pure
Python and padded, so a Python half that pads will **still** differ from R on a
pre-1000 instant — in the year rather than the separator — while one routed
through `to_csv`'s `datetime64` path inherits pandas' unpadded year and differs
the other way. So "both sides emit the ruled form" does not by itself close row
56. Stated in the row.

## What I did not do, and why

- **metasalmonpy is untouched.** The mirror half is **B-145**, a separate item.
- **`.ms_iso_date_columns()` / `.ms_align_cols()` untouched** — rejected candidate
  2, backlog #93 item 1.
- **`.ms_iso_character()`'s space-separated form not kept** — rejected candidate 1.
- **Character and `Date` descriptor behaviour unchanged.** Only the instant branch
  moved.
- **The 8 pre-existing suite failures and the locale WARNING are not fixed.**
  Outside the item, and they are identical on `origin/main`.

## Belongs to another item, or is a new-item candidate

- **B-145** — the metasalmonpy half. Row 56 carries what it needs.
- **B-111** is named in my brief as being worked in parallel on the create-path
  sidecar writes. **I did not touch it**, and I changed nothing outside
  `R/metadata-write.R`, `R/platform-time.R`, their test file, `NEWS.md` and the
  register — so there is no overlap to reconcile.
- **New-item candidate: `readr::write_csv()` writes an unpadded, invalid
  `xs:dateTime` year for a pre-1000 instant on Linux, so `metadata/dataset.csv`
  itself carries bytes this package cannot parse back.** Evidence above.
  This is #93's `as.character` Date defect in the same shape on readr's *instant*
  path, it is reachable only from a caller-supplied typed instant, and closing it
  means either padding the CSV side — which needs #93 item 1 reopened
  deliberately — or accepting a platform-dependent instant year across the
  ecosystem. **Not absorbed**: it is the CSV writer's defect, my item's condition
  is agreement between the two files, and agreement now holds on both platforms.
- **Observation, not a defect I verified:** `R/eml-export.R:1661` renders the same
  `temporal_start` through a third renderer (`as.character()`) for EML
  `calendarDate`. On that path the value comes from the package's metadata CSVs
  and so is character, where all renderers agree; I did not drive a typed instant
  through it. Worth a look if anyone extends typed metadata support.

## Retirement conditions of what I added

- **`.ms_readr_instant_character()`** — retires when readr exposes a documented
  scalar formatter this can call instead of formatting a one-column frame, **or**
  `metadata/dataset.csv` stops being written by readr, at which point the
  descriptor follows the CSV's new writer. The baseline is what the helper tracks,
  so the retirement condition is a statement about the baseline.
- **Its internal one-row-per-line check** (`stop()` on an unexpected row count) —
  not a suppression; it fails loudly so a misaligned rendering cannot be silent.
  Retires with the helper.
- **`datapackage.json and dataset.csv spell a POSIXct identically`** — retires
  when nothing. It is the standing check that the two files keep one spelling of
  one instant, whichever writer moves next, and it asserts the agreement rather
  than a literal so it survives a platform change.
- **`the descriptor instant renderer is readr's, by construction`** — retires when
  `metadata/dataset.csv` stops being written by `readr::write_csv()`.
- **Register row 56** — retires when B-145 lands **and** the year-padding residual
  is measured away or registered.
- **The two `collation_sensitive_fns` entries** — retire with the functions they
  name: when `.ms_descriptor_temporal_text()` and
  `.ms_readr_instant_character()` are deleted or stop reaching descriptor bytes,
  the entries go with them. They do **not** retire when the guard learns to
  traverse callees; if it ever does, `.ms_descriptor_apply_dataset_meta()`'s
  entry would reach both of these and the two rows would become redundant rather
  than wrong, and removing a redundant entry is a judgement about the traversal
  rather than about these functions. Nothing is suppressed or skipped by adding
  them: the guard inspects strictly more than it did before.
