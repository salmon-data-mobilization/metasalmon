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
  lockstep, with version bumps made only when parity actually lands.
  **This bullet no longer states the numbers.** The release index in the
  [roadmap](../roadmap.md) is the single authority for them; read it there.
  A Python version number is a claim about behaviour delivered, so a gap is
  visible by design rather than papered over with a matching number.
  **The order of a bump was ruled** (Brett, 2026-08-24, hub
  [Q7](../questions.md)): metasalmon releases the tree carrying its fixes
  first, then metasalmonpy claims that number. The rule outlives the stream
  and governs the next release pair.
  *Why the numbers were removed, 2026-09-09:* this line carried them three
  times and was wrong three times — "0.1.8" until 2026-08-24, then "0.2.1",
  then "both at 0.4.0, lockstep is the present state, S10 is done", which went
  stale the next day when metasalmon released 0.5.0 and stayed wrong for
  fifteen days. The bullet even predicted its own failure, in the sentence
  saying the next divergence would be created by the next change with nothing
  here to announce it. A fact restated in a place that cannot notice when it
  changes is not documentation; it is a second answer waiting to be believed.
  This is the first application of the rule in the
  [Foundry plan's §9](../plans/2026-09-04-salmon-science-foundry-concrete-plan.md):
  one fact, one home.
- **The mirror is not automatically the follower** (Brett, 2026-08-17):
  *"don't just make things match metasalmon; if the Python implementation got
  it right, then update metasalmon."* This coordination context therefore
  routes a parity divergence to a **ruling on which side is correct**, not to
  a Python work item by default. Both directions of fix are recorded the same
  way, in [parity-deviations](../parity-deviations.md) and its `PARITY.md`
  twin.
