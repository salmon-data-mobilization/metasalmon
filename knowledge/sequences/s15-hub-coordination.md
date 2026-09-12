---
type: InformationObject
title: "S15 — Hub coordination: a git-native queue"
description: "Move planning state out of prose and into a git-native queue whose claims are ordinary git pushes, with a root-level policy file and a small client. No GitHub Project, and a client that makes no GitHub API call at all. Ruled 2026-09-05 (Brett, R9), simplified 2026-09-09 (R12), largely built the same day, and its authorization widened 2026-09-10 (R15)."
status: draft
tags: [coordination, queue, agents, migration]
psc:
  id: metasalmon:sequence:s15-hub-coordination
  contexts: [metasalmon:context:hub-coordination]
---

# S15 — Hub coordination: a git-native queue · **ruled 2026-09-05, simplified 2026-09-09 (Brett)**

**Execplan:** section 9 of the
[Salmon Science Foundry concrete plan](../plans/2026-09-04-salmon-science-foundry-concrete-plan.md).
Brett: *"redesign and simplify the system of hub coordination … so that any
agent can pick up work that is currently not checked out."* The first two
drafts routed that through a GitHub Project; R12 removed it on 2026-09-09,
leaving git files alone.

## Why, in one measurement

25% of this bundle's 8,901 non-plan lines was planning **state**, restated 3
to 17 times, with five copies stale on the day they were counted: metasalmon's
version in ten files, the mirror window in five, S10's status in four, and a
decision ruled 2026-08-22 whose roadmap entry still read unruled. The bundle
already stated the rule that violates, which is that a count nobody maintains
is decay. The second measurement is what sizes the queue rather than justifying
it: of 44 open backlog items, about 34 could be finished by an agent
unattended, 5 wait on a decision and 1 on a credential, so the bottleneck is
the supply of `ready`, which only Brett produces.

## Scope

1. **The queue is files in git**, one YAML document per work item, and they
   live in `queue/` at the repository root rather than in this bundle. Two
   reasons point the same way: the OKF validator fails closed on a non-Markdown
   file inside a bundle, and operational state belongs with the system that
   owns it rather than with the knowledge that describes it.
2. **Every prose restatement of a state fact becomes a generated block** with a
   freshness check, so drift fails a build instead of waiting for a reader.
3. **A claim is a plain `git push`** of an orphan commit to a claim ref in a
   small locks repository. That is git's own compare-and-swap: zero race
   window, no API call, no `project` scope, no `issues: write`.
4. **`HUB.md` at the repository root is the single policy file**, carrying the
   states, the claim protocol, and a `writes:` register. Brett's global
   instruction is the ceiling and the narrower of the two governs.
5. **A client with seven verbs** (`doctor`, `ready`, `claim`, `beat`,
   `release`, `done`, `reconcile`) that distinguishes losing the race from a
   failed call, because folding a dead credential into "somebody got there
   first" makes an agent spin through the whole queue reporting nothing wrong.
6. **No GitHub Project** (R12). Section 9.8 of the execplan records what the
   Project would have given and that reviving it is additive, because the queue
   files are the source.
7. **Backlog identifiers are preserved** in a `legacy` field, so the 191 bare
   citations already written elsewhere never have to be rewritten.
8. **The standing authorization lives in `HUB.md` and only there**, as a
   `writes` register with a closed exclusion list and a clause suspending the
   whole grant on the first write outside it. This card does not restate what
   it permits, because a boundary with two copies has two readings and the one
   an agent obeys is whichever file it opened. The grant was ruled on
   2026-09-09 and widened on 2026-09-10, including a reversal of the refusal of
   the draft pull request ([Q37 and Q38](../questions.md)), so any sentence
   here enumerating it would already have been wrong once.

## What exists, and what remains

**Landed 2026-09-09:** the policy file and the queue at the repository root
with its configuration and its item files, the client, the render-and-check
guard and its unit tests under `scripts/`, the continuous-integration workflow
that runs them, and the first generated block, the member count at the top of
the [roadmap](../roadmap.md). `queue/README.md` explains what an item file
means; neither it nor `HUB.md` is linked from this bundle, because the bundle
check reports a Markdown link whose target sits outside the bundle and this
bundle is held at zero warnings.

**Outstanding, in order:**

- **The step-1 race test against the real locks repository is not
  recorded.** The repository itself exists: `salmon-data-mobilization/hub-locks`,
  created by Brett on 2026-09-10 and named by `queue/config.yaml`, with a
  `main` that holds only a README so a claim ref is never the default branch.
  The first real claims were taken the same day (B-44, B-49, B-90, B-95);
  three were handed back (B-49, B-90, B-95) and two of those had merged by
  2026-09-12 (B-90 as smn-data-pkg #7, B-95 as metasalmon #112), with
  B-49's metasalmon #111 still open. What step 1 also asked for, a
  two-terminal race test proving a first claim is atomic, has a record only
  offline: `scripts/tests/test_hub_claim.sh` races two clones of a throwaway
  bare repository by design, and neither it nor section 9.7 of the execplan
  records a run against `hub-locks`.
- **The generated blocks beyond the first.** The remaining restated state
  facts are still prose, so a card can still disagree with the queue.
- **The point of no return**, migration step 5, where the roadmap and the
  cards lose their status prose. Steps 0 to 4 are reversible and this one is
  not, so it is a go or no-go on the evidence from the first four.
- **Every timing constant is a calibration condition**, not a settled number.
  The lease, heartbeat, grace, and concurrency values are labelled guesses and
  are revisited after twenty recorded claims, with the measurement written into
  this card on the day it is made.

## Dependencies and order

- **Blocked by nothing.** It blocked only the *paste* half of
  [S14](s14-salmon-science-foundry.md), which is why that stream reached the
  roadmap on 2026-09-09 and not on the day Q19 was ruled.
- **Step 0 deletes rather than corrects** the stale state copies, so the
  migration starts from a true baseline. Migrating from a false one is the
  failure that is invisible afterwards.
- **About 18 agent-hours and two hours of Brett**, after R12 removed the
  Project, its fields, its sync program, and its credential.
- **The acceptance test is the cost of admitting a member**: about an hour of
  diff for S14, or the design failed.
- **It precedes the bundle's own migration to upstream OKF v0.2**
  ([Q34](../questions.md)), because that migration changes the documented
  validation command in several files at once, which is exactly the
  duplication this stream removes.

## Retirement and supersession

***Retires when*** the queue holds every stream and open work item, `HUB.md` is
the only copy of the standing authorization, each state fact lives in one place,
and no card in this bundle carries per-stream status prose. At that point this
card records the outcome in one or two lines and stops describing a migration
that is over. *Superseded if:* claims stop living on git refs, in which case
the authorization paragraph is deleted rather than widened and the policy file
goes with it; or if section 9 of the execplan is replaced by a ruled successor
design, in which case this card is rewritten in the same change rather than
left to disagree with it.
