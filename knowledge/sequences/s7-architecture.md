---
type: InformationObject
title: "S7 — Architecture and curation engine"
description: "The largest stream: split package-helpers.R, the curation session engine, the shared chat request builder, and latent cleanups. Backlog items 29, 30, 31 and Themes C/E."
status: draft
tags: [architecture, curation]
psc:
  id: metasalmon:sequence:s7-architecture
  contexts: [metasalmon:context:hub-coordination]
---

# S7 — Architecture and curation engine · #29, #30, #31, Themes C/E · largest

**Execplans:** [architecture refactors](../plans/2026-06-24-deepen-architecture-refactors.md)
(executed part) · [I-ADOPT chat decomposition](../plans/2026-04-02-i-adopt-chat-decomposition-draft.md)
(design) · Theme detail in [next behaviours roadmap](../plans/2026-06-26-next-behaviours-roadmap.md).

- **Split `package-helpers.R`** (#29, ~3k lines) and move `infer_*_from_resources`
  out of `dictionary-helpers.R` (#30). Public signatures unchanged.
- **Curation session engine** (Theme C1–C3): `start_curation_session()` /
  `run_curation_turn()` / `propose_curation_patch()` / `approve_curation_patch()`,
  a question planner with information-gain ranking, and a structured provenance
  bundle. Routing slices and `chat_decomposition()` shipped in 0.1.3.
  **Since 2026-09-25 (Brett, hub Q67), the turns are not the package's.** A
  model conversation runs in the caller's harness, and `chat_decomposition()` is
  deprecated and then removed under
  [S16](s16-model-call-leaves-the-packages.md), with its dialogue moving to a
  plugin skill. What can stay here is what section 1.3 of the Foundry plan
  already allowed: session state for one package and replayable patch
  artifacts, with no model call inside them.
- **Shared chat request builder** (#3 / Theme E2) — both default request
  functions go through one builder, `.ms_llm_chat_request()` (hub item B-3). It
  was not, after all, mutually exclusive with the adapter's dual-shape
  normalizer, so it did not need to wait for the curation work: the request and
  the shape its reply is returned in are separable, and the normalizer's wrapped
  branch serves what `.ms_chat()` returns, whichever request function produced
  it. What is left is
  the chat path's request body (hub item B-128) and whether decomposition
  converges on one session engine with the semantic path (hub item B-31).
  *(This read "mutually exclusive with the adapter's dual-shape normalizer, so do
  it inside the curation work" until 2026-09-23; `knowledge/backlog.md` #3
  records why that was wrong.)*
  **Superseded 2026-09-25 by hub Q67: the builder is deleted, not converged.**
  The removal release in [S16](s16-model-call-leaves-the-packages.md) deletes
  the shared builder and both request functions that use it, so B-128's fix
  has at most the releases before it to matter in, and B-31's convergence has
  nothing left to converge. B-31 was moved to icebox on Brett's instruction
  the same day and retires with the removal; B-128 stays as it is, blocked by
  Q-54.
- **Latent cleanups** (#22, #23, #24) — fold into whichever stream touches those
  files rather than scheduling separately.

Deliberately last: it is the largest, and nothing depends on it. The model-call
split is not part of that: it has its own stream, S16, and is sequenced now.
