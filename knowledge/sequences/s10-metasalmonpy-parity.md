---
type: InformationObject
title: "S10 — metasalmonpy parity"
description: "Bring the Python mirror to full behavioural parity with metasalmon (the v0.3.0 tag plus its post-0.3.0 fixes); the replay ladder is complete at 0.2.1 and the subsystem port has landed chunks A through G (2026-08-22, all unversioned pending Q7). Chunk H — the metasalmon-PR-#77 abort-safe write-path mirror — is in flight and is the last chunk; after it the only remaining scope is the terminal version bump. What version number the finished port may carry is an OPEN decision — see the execplan. The mirror rule applies to all new work immediately."
status: draft
tags: [metasalmonpy, parity, python]
psc:
  id: metasalmon:sequence:s10-metasalmonpy-parity
  contexts: [metasalmon:context:hub-coordination]
---

# S10 — metasalmonpy parity · from 0.2.1 to metasalmon-0.3.0 behaviour

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
#65 descriptor adjudication and datetime fix) is likewise merged.

**Chunks A through G are done — seven of eight, all on 2026-08-22.** Chunk A
— the breaking dictionary-contract flip, which the 2026-08-17 replan put first
precisely so nothing later is built on a shape it replaces — merged as
metasalmonpy PR #14, verified against metasalmon `main` at `e02111a`. Chunk C —
the missing-value contract, undiluted — merged as PR #15 against `39818ce`,
converging register row 22 and closing its live interop hazard. Chunks B and G —
the semantic-pipeline retarget plus the legacy-read verification — merged as
PR #16 against `9d8f125` after a mid-stream re-baseline (Q7's second data
point). Chunk D — validation hardening — merged as PR #20 against `9d8f125`.
Chunks E and F — cache/environment/network robustness, then the redaction
contract stacked on it — merged as PRs #17 and #19 against `794647a`, a
**re-pin** rather than a re-baseline (the R tree was confirmed identical to
`9d8f125` in `R/`, `tests/` and `inst/`). Every one is **unversioned by
design**: metasalmonpy stays at 0.2.1 because which number the finished port may
carry is open (Q7 / execplan open decision 2), so everything lands under the
CHANGELOG's *Unreleased* heading and the single bump comes at the end. See the
execplan's dated chunk records for counts, baselines and revert verification.

**Chunk H is in flight, and it is the last one** (2026-08-22, branch
`feat/s10-chunk-h-abort-safe-write`): the mirror of metasalmon PR #77's
abort-safe write path, routed on 2026-08-22 because no earlier chunk owned it
(backlog #96's measured Python ordering defect). It was sequenced behind D and
E+F for rebase cost, not dependency, and those have now landed.

**This is the last stretch, so it is worth saying what "done" means concretely.**
S10 is finished when three things are true, and not before:

1. **Chunk H merges** — `write_salmon_datapackage()` renders the full write set
   to bytes before touching disk, installs through a multi-file staged write set
   with rollback, and unlinks unrewritten managed paths only after the install
   succeeds, with abort-injection tests mirroring
   `test-write-datapackage-abort-safety.R` and R's two honest narrowings
   (`prune` residual; create-owned sidecars = backlog #111).
2. **Q7 is answered** — the terminal bump cannot be truthful until someone rules
   on what number a port carrying metasalmon's post-0.3.0 behaviour may claim.
   This is the only remaining **decision**; everything else is work.
3. **The bump ships** in metasalmonpy's own lockstep form: both version strings
   agreeing, the CHANGELOG's *Unreleased* sections resolved into the release
   entry, an annotated tag, a published GitHub Release — and, in the same
   stream, the three places that must agree about the number: metasalmonpy's
   `AGENTS.md`, metasalmon's `AGENTS.md`, and the release index in
   [`roadmap.md`](../roadmap.md).

What does **not** gate it: backlog **#87** / register row 32, the
ranking-profile gap, which stays open with no milestone and is the surviving
half of the execplan's open decision 1 (#91, its other half, closed at chunk D).
Whether the parity claim tolerates shipping with #87 open is part of Q7.

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
by subsystem against the **`v0.3.0` tag**, with
0.3.0's breaking dictionary-contract flip landing **first** rather than last so
nothing is built on a shape it replaces. The registry writer-only-skip and the
born-NA-safe typed reader remain logged decisions; the replan and what would
reverse it are logged alongside them.

Bumping at each parity milestone rather than in one big jump kept every bump a
truthful claim and made the release order carry the same breaking-change story
(e.g. 0.2.4's missing-value token) that R users already absorbed. One bump is
left, at the end of the chunks — and **what number it may carry is an open
decision, not 0.3.0 by default** (execplan, "What version number may the
finished port carry?", four options, none preferred). The chunks are
contractually required to carry metasalmon's **post-0.3.0** fixes, so a bare
"0.3.0" would name a tree no metasalmon release contains; the options include
claiming the next R release number instead. **The chunk list itself is also not
final** until the execplan's first open decision (whether the parity claim
requires closing #87 and #91) is answered — (a) and (b) there add work to it.
The remote schema loader and
its spec-tag pin have landed, and chunk A moved the vendored bundle and
`SDP_SPEC_TAG` to `sdp-0.3.0` **together**, never separately, exactly as
required — metasalmonpy `PARITY.md` rows 27 and 38 are both now marked
converged, and the bundle is a verbatim byte-copy of the upstream tag.

**Interacts with S4:** the workshop's Python episodes execute against
metasalmonpy, so S4 must not demo Python behaviour that has not landed.

**The statistical-modifier role is fully mirrored as of chunk B (2026-08-22,
metasalmonpy PR #16):** the ranking-preferences rows landed byte-identical to
metasalmon's file, the review prompt judges exactly the six dictionary slots,
`SEM_MODIFIER_EVIDENCE_REQUIRED` sits beside the surviving method validator,
and the mirrored role-contract guard states its own six-surface scope — with
`role_boost` named as the one surface Python cannot guard (no profile system;
backlog #87) and a tripwire test that goes red the moment one appears. The
paragraph below is the pre-B state, kept as the record of what the chunk had
to check and why.

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
logged here" is struck as an error and this stays open. **The second arm
happened (2026-08-21):** the execplan struck the claim as an error (its open
decision 1b), so the two documents no longer disagreed — but the *question*
stayed open, and E+F went into flight with it unresolved.

**RETIRED 2026-08-22 — the first arm happened too, and chunk E is where.**
metasalmonpy PR #17 renamed the switches to `METASALMONPY_CACHE` /
`METASALMONPY_DEBUG_FETCH`, read at call time through one helper, and kept the
`SALMONPY_*` spellings as deprecated aliases that warn **once per process** and
are **removed in the first tagged release after the S10 parity release**. That
is the middle option of the three this card listed: rename *with* legacy
aliases, on a stated window rather than an open-ended one. The decider is the
chunk-E implementer, not Brett — recorded honestly, because this card spent nine
days asking who ruled and the answer must not become vague again. The dated
decision lives in the [S10 execplan](../plans/2026-08-15-s10-metasalmonpy-parity-replay.md)'s
*Decisions logged during the subsystem chunks* table, its open decision 1b is
marked decided, and the retirement condition is parity-deviations row **50** in
both registers. Test-suite-only gates (`METASALMONPY_RUN_QUALARK_TEST`,
`METASALMONPY_QUALARK_TEST_*`) were renamed cleanly with no alias — developer
knobs, not package API.

*The resolution was not the discovery of a prior ruling; there was none. The
question was closed by someone making the decision and dating it, which is the
only honest way out when two documents have been asserting a decision that never
happened.* *(The two items filed
beside it on 2026-08-13 are done: `ms_setup_github()`'s private `qualark-data`
default and the R-syntax remediation message were both fixed the same day in
`a7999b2`, "mirror metasalmon #72 (no default repo)", and shipped in v0.1.7.)*
