---
type: InformationObject
title: "S9 — Ontology conventions and alignment pass"
description: "One conventions layer across smn, gcdfo, and the PSC CV, plus a reasoner-clean OWL backbone for the neurosymbolic consumption target."
status: draft
tags: [ontology, alignment, owl, skos]
psc:
  id: metasalmon:sequence:s9-ontology-alignment
  contexts: [metasalmon:context:hub-coordination]
---

# S9 — Ontology conventions and alignment pass · smn + gcdfo + PSC CV

**Execplan:** [ontology alignment pass](../plans/2026-08-12-ontology-alignment-pass.md)

One conventions layer across the three vocabularies so everything interoperates
*through* smn, plus a reasoner-clean OWL backbone for the neurosymbolic
consumption target. **Steps 0, 1 (semantics), 2, and 5 are done** (2026-08-13,
salmon-domain-ontology PRs #21/#22): the W3C SOSA–PROV alignment is imported
not restated, CONVENTIONS §5b governs mapping placement, methods are SKOS
concepts (the cross-repo pun is resolved and PSC's mapping blocker dissolved),
and `smn:StatisticalModifierScheme` exists for the SDP
`statistical_modifier_iri`. **Next: the step-1 tooling PR** (ELK CI gate, §5b
check scripts, pyshacl wiring, Makefile hygiene), then steps 3–4.

1. *(done)* Step 0 — recon + decisions.
2. **Step 1 — smn conventions + metamodel split.** CONVENTIONS.md hardening,
   the normative-alignment-core / teaching-view split, the eight verified
   metamodel fixes (F1–F8), repo-structure repairs, and a `robot reason` CI
   gate. Independent — can start now.
3. **Step 2 — methods-as-SKOS across the trio.** The vocabulary half of #76 —
   **ordered by Brett 2026-08-13** ("migrate SMN methods from OWL classes to
   SKOS concepts"); the S8 gate is satisfied by the v2 draft naming the
   concepts. Field evidence agreed: PSC refuses to map to smn's OWL-class
   methods while 18 released mappings target gcdfo's SKOS methods, and a live
   cross-repo pun on `smn:EnumerationMethod` poisons the merged closure.
4. **Step 3 — the smn↔gcdfo boundary as data** (SSSOM set, the minted `smn:`
   term, the unbridged age/year duplication). Absorbed from S6 item 4.
5. **Step 4 — PSC CV anchoring to smn** — unblocked by step 2.
6. **Step 5 — statistical-modifier scheme** (`smn:StatisticalModifierScheme`,
   concepts instance-typed `iop:StatisticalModifier` per Brett's 2026-08-13
   decision), the vocabulary the SDP `statistical_modifier_iri` column (S8)
   resolves to. **Independent of steps 2–4** — runs right after step 1, before
   or alongside S8's breaking change (otherwise S8→S9.2→S9.5→S8 would be
   circular).
7. **Step 6 — propagation** to workshop, hub docs, and guides; also hosts the
   parked #78 iop-triple-emission explainer (deferred by Brett 2026-08-13).

**Cross-repo bookkeeping rule (Brett, 2026-08-12/13):** every repo this stream
touches gets an OKF knowledge bundle (created if absent, updated as learned),
git-tracked, free of absolute filesystem paths, with an `AGENTS.md` pointer;
the execplan and the roadmap card are re-sequenced after every step.
