---
type: InformationObject
title: "S16 — The model call leaves the packages"
description: "Brett's 2026-09-25 ruling that metasalmon and metasalmonpy stop calling a model: what the packages keep, the review packet and assessment ingester they gain, the order in which the in-package model call is removed, and what happens outside this hub."
status: draft
tags: [architecture, semantic-review, llm, parity]
psc:
  id: metasalmon:sequence:s16-model-call-leaves-the-packages
  contexts: [metasalmon:context:hub-coordination]
---

# S16 — The model call leaves the packages

**Execplan:** [the review-packet and assessment-ingest contract](../plans/2026-09-25-s16-review-packet-contract.md)
(step 1; its section 10 ruled 2026-09-25, every recommendation taken).

**Ruled by Brett, 2026-09-25, in chat** ([Q67](../questions.md)):

> The LLM call features leaves metasalmon and metasalmonpy. The packages keep
> everything deterministic (retrieval, ranking, validators, merge, gap
> detection, the 30-column assessment row as the record). They gain a
> review-packet exporter and an assessment ingester. Judgement runs in the
> user's harness (Claude Code, Codex, Claude Science) through `smn-sci-plgn`
> skills. This is Brett's own example, and it removes the only API-key and
> HTTP-client path in either package.

The wording is a review panel's summary, which Brett adopted verbatim in the
same message as [Q68](../questions.md) and [Q69](../questions.md). It is quoted
as he sent it, including the panel's description of the idea as his own
example. **Its last clause is true of model providers, not of HTTP in general.**
The provider key and the chat-completions client are the only credential and
client for a model in either package. `find_terms()` still reads
`BIOPORTAL_APIKEY` and calls `httr`, `httr2` serves the schema, GitHub and KNB
code, and `requests` is used across metasalmonpy. All of those stay (measured
2026-09-25 at metasalmon `ae16b42` and metasalmonpy `f1f7230`).

This card is the operative copy of the ruling. `questions.md` indexes it, the
[Foundry plan](../plans/2026-09-04-salmon-science-foundry-concrete-plan.md)'s
§1.3 and its semantic-mapper paragraph were amended to agree with it on the
day it was given, and `AGENTS.md` carries a dated pointer beside the LLM
opt-in contract.

## What stays, what is added, what goes

**Stays, with its behaviour unchanged.** Retrieval (`find_terms()` and the role
filters), ranking, the seven-surface role contract, the bundle validators, the
merge into suggestions, gap detection and the term-request pipeline
(`detect_semantic_term_gaps()` → `render_ontology_term_request()` →
`submit_term_request_issues()`), and the S5 review flow (`review_semantics()`,
`accept_suggestion()`, `reject_suggestion()`, `apply_sdp_semantics()`).

**The frozen 30-column assessment row stays too, and changes role.** Today it
is what the package's own model call writes. After this stream it is the
contract a harness writes to and the package reads back. That is what "the
30-column assessment row as the record" rules: the row outlives the provider
code, so its column contract in `AGENTS.md` stays frozen.

**Added.** A review-packet exporter, which writes a deterministic file holding
what the package already computes for a review: the targets, the ranked
candidate shortlists, the bundle groups, the context excerpts, the review
instructions, the decision vocabulary and the assessment schema. And an
assessment ingester, which reads a harness's assessments back in the 30-column
row, refuses any selection the packet did not offer, and runs the existing
validators, escalation bookkeeping and merge. **The seam is a file and not a
callback because it has to be.** A Claude Code, Codex or Claude Science session
cannot hand an R closure or a Python callable to a package process it did not
start, so `llm_request_fn` cannot be the integration point for a harness.

**Goes.** The provider client with its presets and its reading of keys from the
environment, the two chat request functions and the builder they share, the
retry stack, `llm_request_fn`, the `llm_*` arguments on the public signatures,
and `chat_decomposition()`, whose dialogue becomes a plugin skill rather than
package code.

## Order

Each step is one or two queue items. The queue holds their state; this card
holds the order and the reasons for it.

1. **The additive release: `B-326` (metasalmon) and `B-327` (metasalmonpy), in
   one train.** `B-326` follows `B-361`, R's convergence item. `B-327` follows
   `B-326`, whose contract and fixtures it vendors, and metasalmonpy's
   convergence items `B-360`, `B-362`, `B-363` and `B-364`, which make it agree
   with R where the shared fixtures need it to. The exporter
   (`write_semantic_review_packet()`), the ingester
   (`ingest_semantic_assessments()`), conformance fixtures both packages test
   against, and deprecation warnings on the in-package model call. Nothing
   is removed, so nobody's script breaks at this step. **A retry is a second
   harness pass, not a second package call.** Today R's in-package path widens
   the search and asks the model again on a `retry_search` and, for some
   low-confidence answers, on a rejected shortlist, before it escalates;
   metasalmonpy retries on `retry_search` only. In the file contract a retry is
   a continuation packet holding the widened shortlist, which the harness
   answers before the ingester merges or escalates that target. Whether a
   rejected shortlist earns a second pass before it escalates is one of the
   divergences whose direction is Brett's.
2. **The Theme A harness split: `B-328`.** Keep the replay of the recorded
   fixtures against their required, allowed and forbidden oracles, which is
   what the Foundry plan's pilot anchor for [Q23](../questions.md) reproduces.
   Retire the live, capture and promote modes, which depend on the provider
   path and whose one live attempt returned HTTP 401 for every target (`B-80`).
   Keeping the replay runnable is what lets Q23 stand unamended.
3. **The removal release: `B-329` (metasalmon) and `B-330` (metasalmonpy).**
   Breaking, and both halves wait for the whole of steps 1 and 2 so that
   neither package removes the provider path while the other lags. No earlier
   than one release after step 1, so the deprecation warnings have shipped. Not
   before a released harness skill exists (below), so users have a route to
   model judgement when the in-package one goes. And not before Brett has told
   the people who use the in-package provider route, because that notice is his
   outward act.
4. **The workshop's session-5 lane: `B-331`.** Session 5 teaches learners to
   get a provider key, so it breaks at step 3. Measured 2026-09-25 on the
   workshop's `main` at `8d739db`: `episodes/session-5.Rmd` routes its optional
   live lane through `openrouter/free` by `scripts/review_ai.R` and
   `scripts/review_ai.py`, which turn on `llm_assess`, and the kit's
   `ai/README.md` tells learners to create an OpenRouter key and set
   `OPENROUTER_API_KEY`. The replacement lane is the harness skill, so this
   step needs it released. Every word in that repository is shown to Brett
   before it is pushed.

## Outside this hub: the harness skill

The judgement itself runs in a `smn-sci-plgn` skill that builds a packet, has
the harness judge it, writes the assessments and ingests them
([Q69](../questions.md)). **This hub does not sequence that work.** The plugin
is not a hub member, its own repository owns the skill's tasks and releases,
and no item here is a step of it. What this card records is the dependency,
the way the roadmap records a typed external edge: steps 3 and 4 above each
need a *released* skill, and the skill needs a released step 1, because a skill
calls a released package.

## What this changes in records that already exist

- **`B-31`** asks for chat decomposition and the semantic path to share one
  session engine. Step 3 deletes the engine it would converge, so Brett moved
  it to icebox the same day (*"Do this edit please"*), and it retires with
  step 3.
- **`B-128`** fixes the temperature the chat path sends to GPT-5 models. Step 3
  deletes that path, so the fix matters only in the releases before step 3.
- **`B-226`** routes the benchmark's third request builder through the shared
  one. Step 2 deletes that builder instead.
- **`B-80`** asks for three live captures of the Theme A cohort under a
  provider credential. Step 2 retires the live mode, and a cohort judged in the
  harness replaces it.
- **`Q-54`** asks which side of five request differences is right. At step 3
  neither side sends a request, so no side has to move. What is left is whether
  the differences are registered for the releases before step 3.
- **The S7 card's shared chat request builder** is not converged; it is
  deleted. The deterministic half of S7's curation work is untouched.
- **Parity rows** that describe the provider path retire at step 3, by
  deletion, in both registers and in the pull requests that delete the code.
  Step 1's pull requests say which rows its ingester touches. Step 2 amends
  row 45 in both registers.

## What is Brett's

**Ruled 2026-09-25**, when he took every recommendation in section 10 of the
execplan: the names above, the paths under `review/`, the release numbers (the
additive release as 0.6.0 in both packages, tagged together, and the removal as
0.7.0 after at least one tagged 0.6.x), the cross-language bar, and the
direction of each divergence the execplan lists. Still his:

- **The notice before step 3** to the users of the in-package provider route.
- **Whether `Q-54`'s differences are registered** for the releases before
  step 3, or left unregistered because step 3 deletes both sides.
- **Q23's pilot anchor**, only if step 2 cannot keep the replay.
- **Whether the plugin should become a hub member.** Under the test Q10
  adopted, membership follows from this hub sequencing a repository's work,
  which is why this card records the skill as an external dependency and
  sequences none of it. Admitting the plugin would be a membership ruling, and
  it would move the skill's tasks into this card's order.

## Retires when

Neither package carries a model client, reads a provider key, or holds an HTTP
path to a model. The harness skill is the documented route for model judgement,
the workshop no longer teaches learners to get a provider key, and every
parity row that described the provider path has been retired by deletion.
