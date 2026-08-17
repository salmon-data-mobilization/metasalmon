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
decisions in the execplan, bumping at each parity milestone — and when the replay reaches the release
that introduces the remote schema loader, replay it WITH the spec-tag pin
(metasalmon 2026-08-14): 0.1.6-era Python has no runtime schema fetch, so the
pin itself has no same-day mirror and rides here instead — rather than
one big jump — each bump stays a truthful claim and the release order carries
the same breaking-change story (e.g. 0.2.4's missing-value token) that R users
already absorbed.

**Interacts with S4:** the workshop's Python episodes execute against
metasalmonpy, so S4 must not demo Python behaviour that has not landed.

**Audit addition (2026-08-16) — the statistical-modifier role rides the 0.3.0
replay, not a same-day mirror.** metasalmon fixed two 0.3.0 role-contract
leftovers (see its NEWS "Fixed" entry): `inst/extdata/ontology-preferences.csv`
gained three `statistical_modifier` rows, and the bundle review prompt's
opening instruction now enumerates the six dictionary slots instead of naming
the removed `method` slot. **Neither has a mirror to make yet** — metasalmonpy
was at 0.1.6 when this was written (0.1.8 now, still short of the 0.3.0 rung),
`statistical_modifier` appears nowhere in its modules, and its
`data/ontology-preferences.csv` carries the pre-0.3.0 role set (`constraint`,
`entity`, `method`, `property`, `unit`, `variable`, `wikidata`). This is the
logged reason for no same-day mirror; the role arrives with the 0.3.0 step of
the ladder above, and **both surfaces must land in that step** or the Python
mirror reproduces the exact gap R just closed. When it lands, mirror
`tests/testthat/test-role-contract-guard.R` too: it is what makes the omission
loud, and the R-side gap survived CI and PR review without it.

**Audit additions (2026-08-13):** `github_io.py:85` still defaults
`ms_setup_github()` to the private `dfo-pacific-science/qualark-data` repo —
the exact defect metasalmon fixed as #72 in 0.2.4; mirror that fix. The
`SALMONPY_CACHE`/`SALMONPY_DEBUG_FETCH` env vars survived the rename —
decide between renaming with legacy aliases or documenting as-is.
`github_io.py:54-55` prints an R-syntax remediation message
(`metasalmon::ms_setup_github()`) from Python.
