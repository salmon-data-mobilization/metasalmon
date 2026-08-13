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
- **Shared chat request builder** (#3 / Theme E2) — mutually exclusive with the
  adapter's dual-shape normalizer, so do it *inside* the curation work.
- **Latent cleanups** (#22, #23, #24) — fold into whichever stream touches those
  files rather than scheduling separately.

Deliberately last: it is the largest, and nothing depends on it.
