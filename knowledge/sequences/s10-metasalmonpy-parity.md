---
type: InformationObject
title: "S10 — metasalmonpy parity"
description: "Bring the Python mirror from metasalmon 0.1.6 parity to 0.2.6, bumping its version only as parity actually lands; the mirror rule applies to all new work immediately."
status: draft
tags: [metasalmonpy, parity, python]
psc:
  id: metasalmon:sequence:s10-metasalmonpy-parity
  contexts: [metasalmon:context:hub-coordination]
---

# S10 — metasalmonpy parity · 0.1.6 → 0.2.6

**Execplan:** to be written at stream start. Recon evidence: the 2026-08-13
hub-restructure recon (see the [roadmap card](../roadmap.md) release index and
`metasalmonpy/AGENTS.md`).

metasalmonpy (formerly `metaSmnPy`; package formerly `salmonpy`; renamed and
purged of foreign content on 2026-08-13) is the Python mirror of metasalmon.
It last synced at **metasalmon 0.1.6**; metasalmon is at **0.2.6**.

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

**Sequencing within the stream:** replay the metasalmon release order
(0.1.7 → 0.1.8 → 0.2.0 … 0.2.6, then the 0.3.0 method-model change from S8 —
added 2026-08-14 when S8's R implementation started ahead of this stream, so
the mirror contract's obligation is scheduled here, not merely promised),
bumping at each parity milestone — and when the replay reaches the release
that introduces the remote schema loader, replay it WITH the spec-tag pin
(metasalmon 2026-08-14): 0.1.6-era Python has no runtime schema fetch, so the
pin itself has no same-day mirror and rides here instead — rather than
one big jump — each bump stays a truthful claim and the release order carries
the same breaking-change story (e.g. 0.2.4's missing-value token) that R users
already absorbed.

**Interacts with S4:** the workshop's Python episodes execute against
metasalmonpy, so S4 must not demo Python behaviour that has not landed.

**Audit additions (2026-08-13):** `github_io.py:85` still defaults
`ms_setup_github()` to the private `dfo-pacific-science/qualark-data` repo —
the exact defect metasalmon fixed as #72 in 0.2.4; mirror that fix. The
`SALMONPY_CACHE`/`SALMONPY_DEBUG_FETCH` env vars survived the rename —
decide between renaming with legacy aliases or documenting as-is.
`github_io.py:54-55` prints an R-syntax remediation message
(`metasalmon::ms_setup_github()`) from Python.
