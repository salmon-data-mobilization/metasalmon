---
type: Context
title: "Hub coordination"
description: "The standing coordination context: metasalmon's bundle is the sequencing and release-index authority for the eight-repo salmon data ecosystem, refreshed as work proceeds and as releases by other agents are discovered."
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
  lockstep, with version bumps made only when parity actually lands. **As of
  2026-08-24 lockstep is the present state, not just the target** — both are at
  **0.4.0**, R tagged `v0.4.0` (`4e2bbb6`) and the mirror `v0.4.0` (`3b587e6`),
  both with GitHub Releases — so [S10](../sequences/s10-metasalmonpy-parity.md),
  the catch-up stream, is **done**. (This line read "0.1.8" until 2026-08-24,
  having lagged the 2026-08-18 tags, and then "0.2.1" until the mirror bumped;
  the release index in the [roadmap](../roadmap.md) is the authority for the
  number, and this line has now been wrong twice by lagging it.) A Python
  version number is a claim about behaviour delivered, so a gap is visible by
  design rather than papered over with a matching number — and the corollary
  now that there is no gap is that **the next divergence is created by the next
  change**, with nothing in this bullet to announce it. **The order of the final
  bump was ruled** (Brett, 2026-08-24, hub [Q7](../questions.md)): metasalmon
  releases the tree carrying its post-0.3.0 fixes first, then metasalmonpy
  claims that number and skips 0.3.0. Both steps happened that day; the rule
  survives the stream and governs the next release pair.
- **The mirror is not automatically the follower** (Brett, 2026-08-17):
  *"don't just make things match metasalmon; if the Python implementation got
  it right, then update metasalmon."* This coordination context therefore
  routes a parity divergence to a **ruling on which side is correct**, not to
  a Python work item by default. Both directions of fix are recorded the same
  way, in [parity-deviations](../parity-deviations.md) and its `PARITY.md`
  twin.
