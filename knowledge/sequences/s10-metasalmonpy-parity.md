---
type: InformationObject
title: "S10 — metasalmonpy parity"
description: "Bring the Python mirror to metasalmon 0.3.0 parity, bumping its version only as parity actually lands; the replay ladder is complete at 0.2.1 and the remainder ports by subsystem. The mirror rule applies to all new work immediately."
status: draft
tags: [metasalmonpy, parity, python]
psc:
  id: metasalmon:sequence:s10-metasalmonpy-parity
  contexts: [metasalmon:context:hub-coordination]
---

# S10 — metasalmonpy parity · 0.2.1 → 0.3.0

**Execplan:** the
[S10 replay execplan](../plans/2026-08-15-s10-metasalmonpy-parity-replay.md),
written 2026-08-15. Earlier recon evidence: the 2026-08-13 hub-restructure
recon (see the [roadmap card](../roadmap.md) release index and
`metasalmonpy/AGENTS.md`).

metasalmonpy (formerly `metaSmnPy`; package formerly `salmonpy`; renamed and
purged of foreign content on 2026-08-13) is the Python mirror of metasalmon.
The stream opened at **metasalmon 0.1.6** parity against an R release of 0.2.6.

**The replay ladder is complete.** Verified 2026-08-21: metasalmonpy `main`
carries `version = "0.2.1"`, the annotated tags `v0.2.0` and `v0.2.1` exist,
and the GitHub Release is published. Rung 3 — `0.2.0 + 0.2.1` collapsed,
formerly PR #10 — merged, and it was the **last replayed rung**. PR #11 (the
#65 descriptor adjudication and datetime fix) is likewise merged. So nothing in
this stream is waiting on a merge, and **the next unit of work is chunk A, not
started** — the breaking dictionary-contract flip, which the 2026-08-17 replan
put first precisely so nothing later is built on a shape it replaces.

*(This card asserted the opposite state until 2026-08-21 — `main` at 0.1.8,
rung 3 "awaiting merge as PR #10", PR #11 "also open". Three claims, all
stale in the same direction, because each described a moment rather than a
condition. The durable version is the one above: the ladder is done, and what
comes next is named. The [S10 execplan](../plans/2026-08-15-s10-metasalmonpy-parity-replay.md)'s
"Rung 3 progress (2026-08-18)" section is a dated record of that moment and is
correct as history — read it as history.)*

Target: metasalmon **0.3.0**. The ladder's target moved there when S8 shipped,
which is why this card's range and the execplan's agree.

**The contract (Brett, 2026-08-13), stated in both repos' `AGENTS.md`:**

1. metasalmon leads; metasalmonpy mirrors. Any metasalmon change is presumed
   to require the same change there.
2. Version numbers are **parity claims** — metasalmonpy bumps to a metasalmon
   version only when it actually delivers that version's behaviour.
3. New metasalmon work started after 2026-08-13 lands its Python mirror in the
   same stream, so the gap never widens again.

**Amended (Brett, 2026-08-17) — the mirror is not automatically the follower:**
*"Don't just make things match metasalmon. If the Python implementation got it
right, then update metasalmon."* Point 1 governs **what has to be the same**,
not **which side is correct**; those were being read as one rule and they are
two. So when this stream's differential verification finds a divergence, the
finding is *"the two disagree"* and the next step is a ruling, not a Python
work item. Three things follow, and they change how a chunk is executed:

- **A chunk may produce an R change.** Budget for it; a divergence found in
  chunk B can land its fix in metasalmon. It does not make the chunk a
  failure or push it out of S10 — the amendment was first applied to exactly
  this stream's output (parity-deviations row 32: R ranked `gcdfo` above
  `smn`, Python the reverse, and **R** moved).
- **Direction is decided per divergence, by Brett.** There is no standing
  tiebreak in either direction, so an implementer records the divergence and
  the evidence rather than picking a side. What settles it is which behaviour
  is *right*, which is a question about the salmon-data domain, not about
  which repo is older.
- **An R-side fix still gets a register row.** Changing metasalmon does not
  make the divergence undocumented history: the row records the divergence,
  the ruling, and which side moved, identically to a Python-side fix.

This is why differential verification is the load-bearing part of the port
(and why the replan below could drop chronology without losing anything): a
run that only asks "does Python match R" cannot find an R defect, and this
stream has now found one.

**Known gap (headline level, from recon):** the 0.1.7+ feature families are
entirely absent — EML export, KNB publication + SDP archive, SSSOM,
measurement decompositions, observation structure — and the 0.2.x contracts
differ: the CSV read contract predates the 0.2.4 empty-string missing-value
token, there is no primary-key validation (0.2.6), no credential redaction
(0.2.5), no cli-safety/collation equivalents where applicable.

**PR 0 shipped** (metasalmonpy PR #6, merged 2026-08-16, no version bump by
design): the smn/gcdfo term indexes are real — verified row-for-row against
live R (133/133 smn, 218/218 gcdfo, identical order and role hints) — and a
non-Turtle module body now raises instead of silently dropping its terms.
The same PR started the parity-deviations register (`PARITY.md` +
`knowledge/parity-deviations.md`) and fixed metasalmonpy's gitignored,
never-committed `AGENTS.md`/`CLAUDE.md`.

**Sequencing within the stream** — see the
[S10 execplan](../plans/2026-08-15-s10-metasalmonpy-parity-replay.md). It has
two halves, and the second replaced the first.

*Replayed release by release:* an un-bumped parity-debt PR 0 (the smn/gcdfo
term indexes were stubs, so the existing 0.1.6 claim was overstated), then
**0.1.7 → 0.1.8 → 0.2.0+0.2.1**. **All shipped and tagged; this half is
closed.**

*Ported by subsystem (Brett, 2026-08-17):* the remaining releases are **not**
replayed. The replay was implementing behaviour metasalmon had already deleted
— 0.1.8 built a reader for the registry sdp-0.3.0 removes, and 0.1.7 shipped a
decomposition component annotated "it dies at 0.3.0". The remainder is chunked
by subsystem against the **`v0.3.0` tag**, bumping straight to **0.3.0**, with
0.3.0's breaking dictionary-contract flip landing **first** rather than last so
nothing is built on a shape it replaces. The registry writer-only-skip and the
born-NA-safe typed reader remain logged decisions; the replan and what would
reverse it are logged alongside them.

Bumping at each parity milestone rather than in one big jump kept every bump a
truthful claim and made the release order carry the same breaking-change story
(e.g. 0.2.4's missing-value token) that R users already absorbed. One bump is
left, at the end of the chunks: **0.2.1 → 0.3.0**. The remote schema loader and
its spec-tag pin have landed; both the vendored bundle and `SDP_SPEC_TAG` still
name `sdp-0.2.0` and **must move to `sdp-0.3.0` together** in chunk A, never
separately (metasalmonpy `PARITY.md` rows 27 and 38).

**Interacts with S4:** the workshop's Python episodes execute against
metasalmonpy, so S4 must not demo Python behaviour that has not landed.

**The statistical-modifier role is half-mirrored already — check before
planning it.** metasalmon fixed two 0.3.0 role-contract leftovers (its NEWS
"Fixed" entry): `inst/extdata/ontology-preferences.csv` gained three
`statistical_modifier` rows, and the bundle review prompt now enumerates the
six dictionary slots instead of the removed `method` slot. Of the layers a role
spans, the **hint emitter already landed** in Python with PR 0 —
`term_search.py` emits an `is_statistical_modifier` flag, and register row 7
records Python as *ahead* of R here, since R carries it only inside
`role_hints`. What is still missing **at 0.2.1** (re-checked 2026-08-21, not
carried forward from the 0.1.8 reading) is the **ranking-preferences rows** —
`data/ontology-preferences.csv` still carries the pre-0.3.0 role set
(`constraint`, `entity`, `method`, `property`, `unit`, `variable`, `wikidata`)
— and the review prompt. Both must land in chunk B, and mirror
`tests/testthat/test-role-contract-guard.R` with them: a role whose hint layer
works but whose preference rows are absent ranks with no source preferences at
all, and nothing fails loudly. That is the R-side gap that survived CI and PR
review.

**Carried audit item — and this card and its execplan disagree about whether
it is still open.** The `SALMONPY_CACHE`/`SALMONPY_DEBUG_FETCH` env vars
survived the rename (`term_search.py`; both still present at 0.2.1). This card
has carried it since 2026-08-13 as an **undecided** choice between renaming
with legacy aliases and documenting the old prefix as-is. The
[S10 execplan](../plans/2026-08-15-s10-metasalmonpy-parity-replay.md)'s chunk E
instead lists *"the `SALMONPY_`→`METASALMONPY_` prefix rename, **decided and
logged here**"* — a third option, stated as settled.

**Do not read either document as the answer.** Neither cites a decider or a
date, and the execplan's "logged here" points at no decision record in its own
text, so what exists is two assertions and no evidence. Naming it precisely:
*was the prefix rename ruled, and if so by whom, and does it carry legacy
aliases?* Getting this wrong is cheap in one direction and expensive in the
other — documenting as-is and later renaming is a second breaking change for
anyone who set the variable, while renaming on the strength of a decision
nobody can locate breaks them once on no authority.

**What it blocks:** chunk E cannot be implemented as written until this is
settled, because the rename *is* a scope line in it. **Retires when:** a dated
decision naming the decider lands in one place, and the other document is
corrected to point at it in the same change — or the execplan's "decided and
logged here" is struck as an error and this stays open. *(The two items filed
beside it on 2026-08-13 are done: `ms_setup_github()`'s private `qualark-data`
default and the R-syntax remediation message were both fixed the same day in
`a7999b2`, "mirror metasalmon #72 (no default repo)", and shipped in v0.1.7.)*
