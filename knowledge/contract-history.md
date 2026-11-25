---
type: InformationObject
title: "AGENTS.md contract history"
description: "The dated history, measurements and incident accounts behind each contract in metasalmon's AGENTS.md, moved out of it on 2026-11-24 so that AGENTS.md states only the rules. Not operative: where this card and AGENTS.md differ, AGENTS.md is right."
status: draft
tags: [contracts, history, agents]
psc:
  id: metasalmon:contract-history
  contexts: [metasalmon:context:hub-coordination]
---

# AGENTS.md contract history

**Nothing in this card is operative.** It grants nothing, forbids nothing and
defines nothing. The rules are in `AGENTS.md` at the repository root; where the
two differ, `AGENTS.md` is right and this card is the record of how it got
there.

**Why it exists.** On 2026-11-24 Brett ran a retro of the hub's process and
ruled *"Do all of this. This is the priority."* One of its findings was size:
`AGENTS.md` had grown to about 4,900 words, much of it dated history paragraphs,
and every agent read all of it before starting. Its history, measurements and
incident stories were moved here that day, keyed by the contract they belong to,
and `AGENTS.md` kept each contract as a rule. The text below is the
`AGENTS.md` wording of that day, verbatim except where a heading or a short
framing sentence was needed to say which contract a passage belongs to. The
same move was made for `HUB.md` on 2026-09-24, into `.hub/policy-history.md`.

## The hub introduction

Until 2026-11-24 the introduction listed the ecosystem's member repositories by
hand, with the admission date of the two newest. It now points at the generated
`member-list` block of the
[domain card](domains/salmon-data-ecosystem.md), because a hand-kept list is a
copy of the domain card's allowlist and the copy is what drifts.

The coherent-batch adoption paragraph read, before it was shortened to a
pointer at `HUB.md` § *Coherent batches*, whose rules it restated:

> **Repository-local coherent-batch default (requested 2026-10-01; operative only
> after this policy merges):** This repository adopts `HUB.md` § *Coherent
> batches*: one PR may contain several separately claimed IDs in one coherent
> capability or substantial related-defect family, and that is the default where
> related eligible work exists. A substantial capability with one ID is ordinary;
> a narrow standalone or urgent fix remains valid with one brief scope reason in
> the lead workpad. One owner uses one lead implementation worktree and branch,
> with an exact per-ID handoff ref and short linked record; different owners stay
> isolated. Another member repository needs its own explicit `AGENTS.md` adoption.
> The mirror, semantic, guard, security, and release contracts below remain.

## Mirror contract: metasalmonpy mirrors this package

**The version state `AGENTS.md` recorded before 2026-11-24, measured
2026-10-15:** both packages read 0.6.0 on `main`, so no catch-up window was
open. 0.6.0 (S16 step 1) was ruled a joint release, so both numbers moved
together and no window opened; the `v0.6.0` tags are Brett's to make on the two
bump merges. `AGENTS.md` keeps one dated measurement line of its own, because
metasalmonpy's `AGENTS.md` counts it as one of the three copies of the number;
the history of earlier measurements is here.

**The 0.4.0 to 0.5.0 window.** The `0.4.0→0.5.0` window that metasalmon's
`v0.5.0` opened on 2026-08-25 (roadmap stream S5 — nine new exported functions:
`review_semantics()`, `accept_suggestion()`, `reject_suggestion()`,
`apply_sdp_semantics()`, `review_metadata()` and the four `set_sdp_*()` setters,
plus the `semantic_suggestions()` / `semantic_llm_assessments()` accessors)
closed 2026-09-16, in two halves: hub queue B-126 ported the behaviour
(metasalmonpy pull request #28) and B-153 wrote the documentation half and moved
the number. **Both halves were needed, and the second is the one that nearly did
not happen**, because 0.5.0's own NEWS entry leads with a *documentation* claim
— reaching `validate_salmon_datapackage(require_iris = TRUE)` "without opening a
single file in a spreadsheet" — which a reference index cannot deliver:
metasalmonpy's guide named none of the nine functions for the twenty-two days
its reference listed all eleven of them. The whole window was ordinary "R
shipped first" lag rather than a set of deliberate differences, so it was owed
as a **port** — tracked in `knowledge/parity-deviations.md` and the roadmap's
release index, and deliberately **not** as new register rows. metasalmonpy's
tree then read 0.5.0, and measured 2026-09-24 its newest tag was `v0.5.0`, made
that day on the bump merge `67fb486` with a GitHub Release.

**Parity is the state that decays fastest**, and the version of this paragraph
that recorded 0.4.0/0.4.0 said exactly that while recording it: it decayed one
release later, which is the argument for reading any parity sentence as a dated
measurement and never as a standing property. The 0.4.0 measurement it replaced
was honest and thorough — all 25 of metasalmon 0.4.0's NEWS entries audited
against the Python tree entry by entry, the two gaps found genuinely absent
(`knb_environment` and the `statistical_modifier` `role_boost`) ported, five
remaining differences registered instead of ported, both dependency legs green
— which is the point rather than a caveat to it: thoroughness bought one release
of accuracy.

**The times the two `AGENTS.md` files disagreed about the version.** When the
two files disagree about that number, one of them is wrong about the single fact
the mirror contract turns on, and nothing in either file reveals which.

- metasalmon's `AGENTS.md` read 0.1.8 (with a 0.2.0→0.3.0 window) for three
  days after metasalmonpy tagged 0.2.1 and said so in its own `AGENTS.md`,
  corrected 2026-08-21.
- metasalmonpy's line carried a stale `0.2.2→0.3.0` window after metasalmon
  tagged 0.4.0, corrected there 2026-08-24.
- **A third time, from 2026-08-25 to 2026-09-14**: `v0.5.0` moved this package
  to 0.5.0 while metasalmonpy's `AGENTS.md` went on reading that both packages
  were at 0.4.0 with no window open, because editing the mirror was out of scope
  for the release that opened the window. Twenty days, against two the previous
  time. Corrected there by B-126.
- **The fourth time was a different shape, and it is the one the rule did not
  see coming.** On 2026-09-16, when B-153 closed the window, all three copies of
  the number were read against each other first and **all three already
  agreed** — 0.5.0 / 0.4.0, window open. What disagreed was every *description*
  of them: the `AGENTS.md` paragraph said metasalmonpy's `AGENTS.md` "still
  reads 0.4.0/0.4.0", the roadmap release index said the same, and both B-126's
  and B-153's `retires_when` said it too. All four had been true and stopped
  being true hours earlier when #28 merged. So the failure was not two files
  disagreeing about the number; it was four places agreeing about *which file
  was wrong* and all four being wrong about it — which checking that the three
  numbers match cannot catch. That is why the rule says *read the other file*
  rather than *trust the one in front of you*, and why a description of the
  three copies is not a substitute for reading them.

**The mirror is not automatically the follower** (Brett, 2026-08-17, in full:
*"Don't just make things match metasalmon. If the Python implementation got it
right, then update metasalmon."*). Presumption of mirroring is about *keeping
the two the same*, never about which one is correct — so a parity divergence
opens the question of which side is right rather than settling it, and the
answer can be that R changes. First applied the day it was stated: R ranked
`gcdfo` above `smn` and Python the reverse, and metasalmon was the side that
moved (parity-deviations row 32).

## The `smn-sci-plgn` skills follow the tools

Brett's words, 2026-11-24: *"Add keeping the relevant skills in smn-sci-plgn
repo up to date with the ecosystem of tools you coordinate."* The plugin's
skills tell users which release to install and which functions and workflows to
run, which is why a release, a rename or a workflow change can make one stale.

## LLM review is strictly opt-in

The opt-in rule is the contract behind the 0.1.4 fix. The model call's removal
was ruled 2026-09-25 (Brett, hub Q67) and is stream S16; the additive release is
hub item B-326 and the removal release B-329. metasalmonpy vendored the review
packet's schema, instructions and fixtures byte-identically when hub item B-327
landed there, in its pull request 72.

## Semantic roles: seven surfaces

**The hint layer is the one that gets forgotten, and forgetting it is silent and
total.** `.ms_validate_semantic_role_type()` vetoes any accept whose candidate
carries hints not naming the role, so a role with no hint emitter has **100% of
its correct accepts downgraded** to `review` while every test using a
hand-written `role_hints` fixture still passes. That is exactly how sdp-0.3.0's
`statistical_modifier` shipped broken through CI and PR review; see the 0.3.0
NEWS entry. The ranking preferences fail the same way: a role with no CSV row
ranks with no source preferences at all — and `role_boost` was **discovered
2026-08-17**, when `statistical_modifier` was found to have carried preference
rows since 0.3.0 while having no boost entry, so it reached ranking on base
weight alone. That is the *same role* failing a *second* silent layer, which is
the strongest evidence available that the list is not yet closed, and the reason
the rule says to assume an eighth surface exists.

The guard section-heads `SURFACE 1` … `SURFACE 7` so a missing layer is legible
in the failure. It reads the slot fields as the authority and inspects the
emitter, filter, dispatcher and scorer bodies.

*(History, kept because it is the lesson and not merely the changelog.
Corrected 2026-08-18: this contract said the role-contract guard "checks every
layer", which was true of six layers and became false the moment the seventh was
named without moving its check. A guard whose claimed scope exceeds its real
scope is worse than a missing guard, because green means "all seven verified"
to the person reading this line. From 2026-08-18 to 2026-08-24 the coverage was
honestly described but split — the first six here, `role_boost` in
`tests/testthat/test-smn-outranks-gcdfo.R` — so "did I reach every layer" had
two answers and neither was complete. Consolidated 2026-08-24, porting
metasalmonpy's 0.4.0 design, which did the same consolidation first. Two things
the consolidation found, both of which argue for distrusting a scope claim until
it is demonstrated: **surface 5 was never checked here at all**, so the "first
six" figure was itself an overstatement by one; and each of the seven now has a
recorded RED demonstration, because a guard claiming seven-surface coverage that
has not been shown to fail on all seven is exactly the claim this paragraph
exists to warn about. `test-smn-outranks-gcdfo.R` keeps the smn-over-gcdfo
**margin**, which is its own subject, and states in its header that the coverage
check moved.)*

R reads `role_boost` in place from `.ranking_profile_defaults()` rather than
hoisting it to a constant as metasalmonpy did; the reasoning, and the pin that
keeps the enumerated table the one the scorer merges, are in the `SURFACE 7`
header of the guard.

## A semantic choice made inside a code change

This is not a style rule; it is the one failure class code review structurally
cannot catch, because the diff is correct and the tests go green. A survey of
164 merged pull requests across the ecosystem in 2026 found the recurring shape:
a term chosen as a by-product of a change whose stated subject was something
else, justified by nothing except that strict validation then passed, with the
appraisal arriving days later in a different repository and never propagating
back.

## A guard must say what would retire it

Without a retirement condition, a guard outlives its cause and then conceals the
failure it was never written for, and reading it alone tells you nothing is
wrong. Observed three times on 2026-08-16 alone: a gcdfo CI exclusion added five
weeks *before* the normalizer whose crash it ended up hiding, with nothing in the
repo connecting the two; a `make` recipe whose missing `set -e` printed a success
mark over a crashing script; and duplicate placement guards in
`migrate_sdp_methods()` that became unreachable when the real checks moved
earlier, leaving dead code that invited someone to weaken the live copy. The
existing decay-resistant lists work because they name their own maintenance rule.

## An empty result is a claim about the instrument

A plausible count is the harder case, because it raises no alarm. Observed on
pull request #137: a sweep for the copies of one stale sentence printed the
authoritative card's header with nothing under it, and the empty section was
read as *no copies here* (the account is in the [backlog](backlog.md)).

## One value, one rendering

Two renderings of one value is the defect, and it is worse than a spelling
difference: `.ms_sssom_canonical_bytes()` sorted through `as.character()` and
emitted through `apply()`/`as.matrix()` (i.e. `format()`), so row order and row
content disagreed, differently on each platform, and a numeric cell's bytes
depended on *other rows in its column* because `format()` is vector-wise. Each
branch of `.ms_canonical_character()` exists because the branch above it is
wrong for that type (character must not be re-rendered — `.ms_iso_character()`
would rewrite a user's `12-34-56`). No static guard can see a violation because
two renderings of one value looks like ordinary code from every angle except the
one where you compare the outputs; it is found by reading.

**The `POSIXct` trap, stated because the package holds both answers and they
are one `git grep` apart.** `.ms_canonical_character()` pads a `POSIXct`;
`.ms_iso_date_columns()` deliberately does not. Neither is a mistake: the first
sits on the `as.character()` path, where the year is unpadded for `Date` and
`POSIXct` alike, and the second sits on the `readr::write_csv()` path, whose
instant output is already correct and differs from `as.character()` in
separator, zone marker *and* whether a fractional second survives — so padding
it there would corrupt a path that was never broken (backlog #93 item 1).

## External text is never a cli template

cli interpolates every element of a message vector, so unescaped braces are
evaluated as code, and an unbalanced brace replaces the message with a parse
error.

## Releases

A dated correction may be appended to a shipped entry because it makes the entry
describe what shipped more accurately rather than adding to what shipped.

**The instance that produced the development-heading rule (Brett,
2026-09-16):** on metasalmonpy `main` the bump merge is `67fb486` (#33, B-153)
and B-144's merge `b939fd9` (#32) is its *descendant* —
`git merge-base --is-ancestor 67fb486 b939fd9` holds — yet B-144's entry was
filed under `## 0.5.0`, which made the changelog say a version contains a change
that the commit making the version current does not; B-124's `1e9245c` (#29),
later still, went under `## Unreleased` correctly. metasalmonpy pull request 35
moved B-144's entry (merged 2026-09-16 as `3f8349a`), and `v0.5.0` went on
`67fb486` when it was tagged on 2026-09-24, eight days after the bump. The
window is real on every release, because the tag is a separate act from the
bump.

What the pre-tag check measured as `AGENTS.md` described it: until the tag
exists it measures the version against its bump commit — the first commit on
`main` whose `DESCRIPTION` reads it — and fails on any line under that heading
added by a commit that is not an ancestor of it. It runs on every pull request
from `.github/workflows/changelog-window.yaml`. Its docstring is the
authority.

## Build: a green local check is evidence about your R

CI installs the current release; a local machine may be a version behind, and
R's own checks get stricter between versions, so a check CI fails can be one
your R *does not run at all*, which no amount of local strictness will surface.
Measured 2026-08-25: two literal `·` characters in R code (R code must be ASCII;
comments are exempt) gave `checking code files for non-ASCII characters ... OK`
under **R 4.5.2** locally and `... WARNING` under **R 4.6.1** on CI. Neither
`--as-cran` nor `error_on = "warning"` would have caught it locally, because
there was no warning to escalate.

## Conventions

Core file sizes as last recounted, 2026-08-17: `package-helpers.R` ~3.8k lines,
`knb-publication.R` ~3.7k, `eml-export.R` ~3.0k, `term_search.R` ~2.8k,
`llm-semantic-helpers.R` ~2.2k.

## Planning artifacts and the commons

The `knowledge/` bundle was migrated from `notes/` on 2026-08-13; only the
CI/test-wired `notes/evidence/theme-a/` stayed behind. Item severity moved out
of the backlog into the queue on Brett's ruling of 2026-09-25 (hub item Q-52).

Durable salmon knowledge goes to the commons because a PR description, a commit
message and a chat transcript evaporate, and the next agent re-derives the same
finding from scratch and sometimes reaches a different answer; the divergence is
silent, because nobody can see the earlier derivation to compare. Deciding what
`cycle line` means, or that a run-timing label is a proxy for a physiological
state, is exactly this kind of finding. On verification: if you wrote a card,
you did not check it. A gap noticed during semantic-review work and left in a
transcript is a term request that will never be filed.
