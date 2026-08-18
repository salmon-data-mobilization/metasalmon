---
type: Context
title: "Hub coordination"
description: "The standing coordination context: metasalmon's bundle is the sequencing and release-index authority for the six-repo salmon data ecosystem, refreshed as work proceeds and as releases by other agents are discovered."
status: draft
tags: [coordination, roadmap]
psc:
  id: metasalmon:context:hub-coordination
---

Brett's standing instructions (2026-08-12/13) that define this context:

- metasalmon is the coordinating hub for execplans and releases of the family
  of repos in the [domain card](../domains/salmon-data-ecosystem.md).
- Other agents may release in sibling repos without writing here, so the
  release index in the [roadmap card](../roadmap.md) is **refreshed
  opportunistically**: any agent touching the hub checks for drift.
- Every repo the work touches gets an OKF bundle (created if absent, updated
  as learned), git-tracked, containing **no absolute filesystem paths**.
- metasalmonpy mirrors metasalmon: functionality and version numbers in
  lockstep, with version bumps made only when parity actually lands. Lockstep
  is the target, not the present state — the mirror is at 0.1.8 against R's
  0.3.0 and [S10](../sequences/s10-metasalmonpy-parity.md) is the catch-up. A
  Python version number is a claim about behaviour delivered, so the gap is
  visible by design rather than papered over with a matching number.
