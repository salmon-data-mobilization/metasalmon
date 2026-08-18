---
type: InformationObject
title: "S10 — metasalmonpy parity"
description: "Bring the Python mirror from metasalmon 0.1.6 parity to 0.3.0, bumping its version only as parity actually lands; the mirror rule applies to all new work immediately."
status: draft
tags: [metasalmonpy, parity, python]
psc:
  id: metasalmon:sequence:s10-metasalmonpy-parity
  contexts: [metasalmon:context:hub-coordination]
---

# S10 — metasalmonpy parity · 0.1.6 → 0.3.0

**Execplan:** the
[S10 replay execplan](../plans/2026-08-15-s10-metasalmonpy-parity-replay.md),
written 2026-08-15. Earlier recon evidence: the 2026-08-13 hub-restructure
recon (see the [roadmap card](../roadmap.md) release index and
`metasalmonpy/AGENTS.md`).

metasalmonpy (formerly `metaSmnPy`; package formerly `salmonpy`; renamed and
purged of foreign content on 2026-08-13) is the Python mirror of metasalmon.
The stream opened at **metasalmon 0.1.6** parity against an R release of
0.2.6. **Current state: metasalmonpy is at 0.1.8; metasalmon is at 0.3.0.**
Rungs 1 (0.1.7) and 2 (0.1.8) have shipped; **the next rung is 3, `0.2.0 +
0.2.1` collapsed.** The ladder's target moved to 0.3.0 when S8 shipped, which
is why this card's range and the execplan's now agree on 0.3.0.

**The contract (Brett, 2026-08-13), stated in both repos' `AGENTS.md`:**

1. metasalmon leads; metasalmonpy mirrors. Any metasalmon change is presumed
   to require the same change there.
2. Version numbers are **parity claims** — metasalmonpy bumps to a metasalmon
   version only when it actually delivers that version's behaviour.
3. New metasalmon work started after 2026-08-13 lands its Python mirror in the
   same stream, so the gap never widens again.

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

**Sequencing within the stream:** the nine-PR ladder in the
[S10 replay execplan](../plans/2026-08-15-s10-metasalmonpy-parity-replay.md)
(recon 2026-08-15): an un-bumped parity-debt PR 0 first (the smn/gcdfo term
indexes are stubs, so the existing 0.1.6 claim is overstated), then
0.1.7 → 0.1.8 → 0.2.0+0.2.1 → 0.2.2+0.2.3 → 0.2.4 → 0.2.5 → 0.2.6 → the
0.3.0 method-model change from S8 (scheduled here since 2026-08-14, when
S8's R implementation ran ahead of this stream). The registry
writer-only-skip at 0.1.8 and the born-NA-safe typed reader are logged
decisions in the execplan.

Bumping at each parity milestone rather than in one big jump keeps every bump a
truthful claim and makes the release order carry the same breaking-change story
(e.g. 0.2.4's missing-value token) that R users already absorbed. When the
replay reaches the release that introduces the remote schema loader, replay it
**with** the spec-tag pin (metasalmon 2026-08-14): 0.1.6-era Python has no
runtime schema fetch, so the pin has no same-day mirror and rides here instead.

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
`role_hints`. What is still missing at 0.1.8 is the **ranking-preferences
rows** — `data/ontology-preferences.csv` carries the pre-0.3.0 role set
(`constraint`, `entity`, `method`, `property`, `unit`, `variable`, `wikidata`)
— and the review prompt. Both must land in the 0.3.0 rung, and mirror
`tests/testthat/test-role-contract-guard.R` with them: a role whose hint layer
works but whose preference rows are absent ranks with no source preferences at
all, and nothing fails loudly. That is the R-side gap that survived CI and PR
review.

**Carried audit item:** the `SALMONPY_CACHE`/`SALMONPY_DEBUG_FETCH` env vars
survived the rename (`term_search.py`) — decide between renaming with legacy
aliases or documenting as-is. *(The two items filed beside it on 2026-08-13 are
done: `ms_setup_github()`'s private `qualark-data` default and the R-syntax
remediation message were both fixed the same day in `a7999b2`, "mirror
metasalmon #72 (no default repo)", and shipped in v0.1.7.)*
