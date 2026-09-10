---
type: InformationObject
title: "S14 — Salmon Science Foundry and SalmonBench"
description: "The ninth member, admitted 2026-09-05 on Brett's Q19 ruling: an orchestration, data-access, and evaluation layer above the SDP tooling, with a Tier 0 run ledger, tool receipts around metasalmon and metasalmonpy, and the SalmonBench task suite in its own institute repository. Neither repository nor the institute's GitHub organization exists yet."
status: draft
tags: [foundry, salmonbench, data-access, evaluation]
psc:
  id: metasalmon:sequence:s14-salmon-science-foundry
  contexts: [metasalmon:context:hub-coordination]
---

# S14 — Salmon Science Foundry and SalmonBench · **admitted 2026-09-05 (Brett, [Q19](../questions.md))**

**Execplan:** [Salmon Science Foundry concrete plan](../plans/2026-09-04-salmon-science-foundry-concrete-plan.md)
(2026-09-04; imported from Brett's draft and revised the same day after a
nine-dimension review, then again on 2026-09-05 and 2026-09-09 as Brett ruled
Q19 to Q37). Design input for its semantics layer:
[OKF-centred semantic knowledge architecture](../plans/2026-09-04-okf-graphify-semantic-knowledge-workflow.md).
Both carry an authority note saying they activate nothing, and admission to
this hub does not change that: what is ruled is that the hub sequences this
work, not that any stage is funded or started.

**Nothing exists yet.** As of 2026-09-09 there is no `salmon-science-foundry`
commit, no SalmonBench repository, and no GitHub organization for the
**Symecology Institute**. The institute was renamed twice in five days, so the
organization is created when a repository needs it, in Stage A week 3, and the
slug `Symecology-Institute` is assumed rather than confirmed
([Q35](../questions.md)). *That paragraph retires* on the Foundry's first
commit, at which point the release index carries a version instead of a note.

## What S14 owns, and what it only consumes

| Workstream | Owner | S14's relation |
|---|---|---|
| A1 — metasalmonpy 0.5.0 port | **[S5](s5-review-flow.md)** | hard dependency; S14 pins the release and never ports |
| A2 — one validation authority | **[S1](s1-validation-authority.md)** | hard dependency for the exact-validator-success metric |
| A3 — release-train order | this card as a rule; the release index as the record | adds a Foundry pin step |
| B — gold-standard campaign | **[S12](s12-fraser-coho-gold-standard.md)** | the first campaign runs S12 through the Foundry; the 173-row artifact is referenced by checksum, never copied ([Q25](../questions.md)) |
| C — Tier 0 runtime | **S14** | owned; Tier 0 is ADR-0001 and tier changes go by ADR ([Q22](../questions.md)) |
| D — SalmonBench | **S14** | owned; 25-task pilot then 60-task v0.1 ([Q23](../questions.md)) |
| E — PR #27 evidence briefing; commons compiler | **S14** for both; **[S9](s9-ontology-alignment.md)** for the ruling (Q6) | evidence into Q6, never adjudication; no public commons feed in Stage A or B ([Q24](../questions.md)) |
| F — Fraser Recruits | **removed 2026-09-04 (Brett)** | out of the Foundry, and it stayed out when the PSC work was withdrawn on 2026-09-09; [S13](s13-fraser-recruits-case-study.md) keeps the three metasalmon requirements |
| G — practicum and Hub pages | **[S4](s4-workshop-rebuild.md)**; the RDA Hub site is a non-member ([Q20](../questions.md)) | S14 supplies content and release JSON |
| H — the `salmon` data-access verbs | **S14** for the design and the receipt schema; **metasalmon and metasalmonpy** for the code | the verbs live inside the two packages under the mirror rule ([Q27](../questions.md)), not in a Foundry-only module |
| I — citation, governance, identity register, rights | **S14** proposes; the owning repositories decide | S9 successor for the identity register |

**SalmonBench is a separate institute repository from the start**
([Q26](../questions.md), 2026-09-05), not a `bench/` directory that graduates
later. That reverses the review's recommendation and moves the cost forward:
two repositories released in lockstep, and a task schema that is a published
interface before it has an external author. The mitigation is that its first
release waits for the 25-task pilot, so the interface is not frozen before the
tasks exist. It is **not** a member row of its own: Q19 named
`salmon-science-foundry` alone, and the [domain card](../domains/salmon-data-ecosystem.md)
records what would change that.

**The Foundry's own bundle uses upstream OKF v0.2** with the commons' strict
closed schema and its checker ([Q30](../questions.md)), not the PSC profile,
because the fields its Claim contract needs are the ones that profile rejects
and because validating an institute bundle with a PSC-owned tool from a
sibling checkout is the cross-boundary dependency this plan forbids elsewhere.
The hub's own bundle follows later ([Q34](../questions.md)), sequenced after
[S15](s15-hub-coordination.md).

## Dependencies

Edges only. Whether each is satisfied today is queue state, not card state, and
lives in the item files rather than here.

- **[S5](s5-review-flow.md)** carries the mirror port of metasalmon 0.5.0,
  which is workstream A1; S14 consumes a released metasalmonpy and never ports
  it itself.
- **[S1](s1-validation-authority.md)** owns the rule-driven conformance test,
  which is what makes exact-validator-success measurable at all.
- **[S3](s3-knb-staging.md)**: the test-node deposit gates S12 stage 2, which
  gates the release of campaign 1.
- **[S12](s12-fraser-coho-gold-standard.md)** supplies campaign 1 and decides
  the package; #90 and #95 are its stage-1 blockers.
- **[S13](s13-fraser-recruits-case-study.md)**: its requirements 1 and 3 are
  the execplan's issue 6, after the port.
- **[S9](s9-ontology-alignment.md)**: the Q6 rulings are what workstream E
  briefs; S14 supplies evidence and never adjudicates.
- **[S7](s7-architecture.md)**: a credibility dependency rather than a code
  one: the execplan's section 1.3 amends S7's boundary by deciding which side
  owns curation state.
- **[S4](s4-workshop-rebuild.md)**: the practicum follows the rebuild.

## Retirement and supersession

- **Superseded in part** when `salmon-science-foundry` has its own `knowledge/`
  bundle: implementation detail and campaign status move there, and this card
  shrinks to scope, dependencies, and the hub edges.
- **Split** if SalmonBench's work is sequenced here directly, at which point
  the membership test applies to it as it did to the Foundry and it takes its
  own card and its own domain row.
- ***Retires when*** the execplan's section 15 engineering-success criteria for
  v0.1 are measured and the outcome is recorded here in one or two lines, or
  when the gate at the end of Stage A collapses the runtime into something an
  existing stream already owns.
  A declined gate retires this card as *declined* rather than deleting it; the
  execplan stays as design input either way.

**Mirror rule.** The Foundry is Python with an R command-tool shim, and it is
not a third implementation of SDP behaviour. Anything it needs from the
packages that does not exist lands in both under the mirror rule, or a row in
[parity-deviations](../parity-deviations.md) says why not. The data-access
verbs are inside those packages by ruling, so the rule already covers them; if
a measured dependency or file-size cost ever moves them to a sibling pair, the
rule is extended to that pair in the same change.
