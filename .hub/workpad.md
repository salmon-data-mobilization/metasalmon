# Workpad — B-106 (metasalmon half: the re-vendor)

*(This file is per-branch. It carried B-49's report on `main`, preserved in git
history; this branch replaces it rather than appending, so the pull request diff
is this item's report and nothing else.)*

## Queue item

**B-106** — Reword the two `sdp.rules.yaml` SOSA Procedure rules to the ruled
reachability reading. `queue/items/B-106.yaml`: kind `defect`, severity P4,
`repo: smn-data-pkg`, legacy `#106`, evidence `knowledge/backlog.md` #106. The
ruling is **Q47** in `knowledge/questions.md` (ANSWERED 2026-09-14, Brett).

**This is the second of two branches for one claim.** The item's `retires_when`
requires metasalmon's vendored copy re-vendored "in the same change" as the
upstream rewording, and the two files are in different repositories, so they
cannot be one commit.

- **Primary:** `smn-data-pkg` draft PR **#8**, branch
  `agent/B-106/a-65bf3fd54d6198d2`. The rule text, the CHANGELOG entry, and the
  full report live there.
- **This branch:** the copy half. **Must not merge before #8**, because it
  re-vendors *from* #8 — merging it first puts a file in metasalmon that
  upstream does not yet have.

## What changed and where

Two files.

- **`inst/extdata/schema/sdp.rules.yaml`** — re-vendored. A **byte-for-byte
  copy** of `schema/sdp.rules.yaml` from the smn-data-pkg branch, taken with
  `cp` and verified with `cmp -s` plus matching md5. Nothing was typed on this
  side.
  - Before: md5 `3c702a373409b23f9c58cb1e1a702c06`
  - After: md5 `2f6126c241ce637955604b75e48b9265`, identical to the upstream
    branch's file.
- **`NEWS.md`** — one `### Changed` entry in the development version. It states
  what the upstream rewording says, because the package *ships* the text and a
  reader of `inst/extdata` will not have smn-data-pkg's changelog; it names PR
  #8 and the merge order; and it says plainly that **no observable behaviour
  changes here, and that this is the defect rather than a reassurance** —
  nothing in `R/` reads a rule `description`, and both reworded rules are among
  B-48's three loaded-and-never-executed rules.

### Drift check — the thing the item said to stop for

The item said to stop and report rather than reconcile a drift under a P4
wording claim. **There is no drift.** Before the change, all three copies were
byte-identical at md5 `3c702a37…`: smn-data-pkg `schema/sdp.rules.yaml`,
metasalmon `inst/extdata/schema/sdp.rules.yaml`, and the primary checkout. So
the re-vendor is a plain copy and nothing had to be reconciled.

### Copied, not generated — checked before editing

**No vendoring script exists in either repository.** Measured: no `vendor` target
in metasalmon's `scripts/` and no reference to a vendoring step in `AGENTS.md`;
upstream's `scripts/generate_artifacts.py` treats `schema/sdp.rules.yaml` as an
**input only** (it reads `version` and `profile`; `RULES_PATH` is never written),
so the rules file is a source, not a generated artifact, and comments in it are
durable. `knowledge/orientation.md` (lines 130–131) gives the governing
instruction — keep the copies in step "by re-vendoring from upstream, not by
hand-editing either side" — which is what was done.

## Commands run, and results

All in this worktree, branched from `origin/main` at `4cd085c`. The container has
**no UTF-8 locale set** (`LANG` unset, `l10n_info()$"UTF-8"` is `FALSE`) and R is
**4.3.3**, so results are reported in both locales.

Vendored bundle loads in R, and agrees with what Python read from the upstream
file:

```
Rscript -e 'pkgload::load_all("."); options(metasalmon.sdp_schema_source="vendored");
            s <- metasalmon:::.ms_load_sdp_schema(); ...'
  -> rules version sdp-0.3.0; rules_uri and profile_uri unchanged; 14 rules;
     all 14 ids identical to main; methods_are_sosa_procedures severity error,
     description 3266 chars -- the same length PyYAML reported upstream
```

Targeted tests, default locale — all green:

```
test-schema-helpers.R    -> 74 pass, 1 skip ("the live upstream SDP bundle loads", on CRAN)
test-sdp-methods.R       -> 89 pass
test-collation-guard.R   -> 9 pass
test-cli-safety-guard.R  -> 11 pass
```

Full suite and `R CMD check`, each run on **this branch and on clean `main` at
the same commit**, because every failure here is pre-existing and the only
honest way to say so is to show the baseline:

| Run | This branch | Clean `main` @ `4cd085c` |
|---|---|---|
| `devtools::test()`, no locale | `FAIL 8 \| WARN 38 \| SKIP 9 \| PASS 3868` | same 8 failures, same lines |
| `devtools::test()`, `LC_ALL=C.utf8` | `FAIL 2 \| WARN 38 \| SKIP 7 \| PASS 3881` | same 2 |
| `rcmdcheck(args="--no-manual", error_on="warning")`, `C.utf8` | **2 errors, 0 warnings, 0 notes** | 2 errors, 0 warnings, 1 note |
| `git diff --check` | clean | — |

**Every failure is pre-existing and none is mine.** Specifically:

- **Six of the eight default-locale failures are queue item B-137**, which
  enumerates them by name in its `retires_when`: the accented
  `Discharge / Débit (cms)` column in `test-dictionary-helpers.R:224`, the four
  Unicode-whitespace cases in `test-iri-predicates.R` (39, 52, 57, 104 — an
  ideographic space passes `.ms_absolute_iri_shape()` under C because TRE
  resolves `[[:space:]]` against the locale), and
  `test-review-console.R:231` (box-drawing rendered as `<U+2500>`). They vanish
  under `C.utf8`, exactly as B-137 predicts. Verified against clean `main` at the
  same commit, with identical line numbers.
- **The remaining two are network**, not locale: `test-github-helpers.R:161:3`
  and `:264:3`, both `httr2::req_perform()` HTTP 404 through the agent proxy.
  Also reproduced on clean `main` under `C.utf8`. `AGENTS.md` warns not to read a
  green offline run as full coverage; this is the other side of that warning.
- **The one note on the baseline is not a real difference.** It is
  `checking for hidden files and directories ... NOTE / Found ... .pytest_cache`,
  and `.pytest_cache/` exists only in the `…-metasalmon-main` worktree's
  filesystem. It is git-ignored but **absent from `.Rbuildignore`**, so
  `R CMD build` packages it and the check notes it. This branch's worktree is
  fresh, which is the whole of why it shows 0 notes. See the candidate items
  below.

**A green run here is evidence about R 4.3.3, not about CI's R.** `AGENTS.md`
records a case where ASCII-in-R-code passed under 4.5.2 locally and warned under
4.6.1 on CI; this machine is two minor versions older still. Nothing in this
change is R code, so the exposure is small — but the check result should be read
as "no new note or warning under 4.3.3", not as "CI will be clean".

## What I did not do, and why

- **Did not touch metasalmonpy.** See the mirror note below: it is owed, and it
  is not in this item's `retires_when`.
- **Did not edit `knowledge/backlog.md` #106, `knowledge/parity-deviations.md`,
  `knowledge/roadmap.md`, or `queue/items/B-106.yaml`.** Item state and the
  ecosystem indices are Brett's, `hub done` deliberately leaves the claim held,
  and four other agents are working this queue in parallel right now — editing
  shared index files would manufacture conflicts across the fleet.
- **Did not change any R code, test, or exported signature.** This branch is a
  data-file copy plus a NEWS entry.

## Mirror — metasalmonpy

**Not a behavioural change in this package**, so the mirror contract is not
engaged by behaviour: nothing in `R/` reads a rule `description`, and both
reworded rules are among the three B-48 measured as loaded and never executed.

**But metasalmonpy vendors the same file and its copy is now stale.** Measured
2026-09-14: `metasalmonpy/data/schema/sdp.rules.yaml` is md5
`3c702a373409b23f9c58cb1e1a702c06` — byte-identical to the *pre-change* upstream
file, so a third re-vendor is owed there, as a plain copy with no drift. Under
`AGENTS.md`'s three outcomes this is **outcome 3, a port that is owed** — R
shipped first — and explicitly **not** a deliberate difference, so it must not be
written up as a `knowledge/parity-deviations.md` register row. B-106's
`retires_when` names smn-data-pkg's file and metasalmon's vendored copy and stops
there, so it is reported rather than absorbed.

## Candidate new items (no id yet)

1. **Re-vendor `sdp.rules.yaml` into metasalmonpy** (`data/schema/`), a plain
   copy once smn-data-pkg #8 merges. Port, not a deviation. Suggested P4.
2. **`SPECIFICATION.md` and four other smn-data-pkg documents restate the two
   rules' old wording** and now contradict the rules file. Evidence and the
   file/line table are in the smn-data-pkg workpad and in PR #8. Suggested P3.
3. **`.pytest_cache` is git-ignored but not in metasalmon's `.Rbuildignore`**, so
   any checkout where pytest has been run gains a `R CMD check` NOTE that has
   nothing to do with the change under review — which is exactly how a baseline
   comparison gets muddied. One line in `.Rbuildignore`. Suggested P4/trivial.

## Guards, suppressions, skips and workarounds — and what retires them

**None added on this branch.** The one skip introduced by this item is in the
*specification text*, and it lands in smn-data-pkg #8: the **unresolved**
outcome, where a check cannot resolve the namespace declaring an IRI.

It is restated here because this repository is where its retirement condition
comes true:

> ***Retires when:*** pinned `smn` and `gcdfo` snapshots ship in
> **`inst/extdata`** (and the metasalmonpy equivalent), so that every namespace
> either resolves against the pinned snapshot or is genuinely outside the spec's
> knowledge, at which point a check can report *absent* or *unreachable* in every
> case and never skip.

Measured 2026-09-14: `inst/extdata/` contains no `smn` or `gcdfo` snapshot today
(no `.ttl` files at all), so the condition is genuinely forward-looking rather
than already met. Until it is, the rule text says three separate times that
unresolved is not a pass: it leaves the rule unchecked for that IRI, it is not an
executing check for the rule id, and `require_iris = TRUE` reports it as an
error.
