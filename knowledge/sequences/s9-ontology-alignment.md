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
consumption target. **Steps 0, 1a, 1b, 2 (smn side), and 5 are done** (2026-08-13,
salmon-domain-ontology PRs #21/#22/#23): the W3C SOSA–PROV alignment is
imported not restated, CONVENTIONS §5b governs mapping placement **and is
machine-enforced in CI alongside a passing ELK reasoner gate**, methods are
SKOS concepts (the cross-repo pun is resolved and PSC's mapping blocker
dissolved), and `smn:StatisticalModifierScheme` exists for the SDP
`statistical_modifier_iri`. **Step 3 done** (smn PR #24 merged
2026-08-13; gcdfo PR #78 merged 2026-08-14 with Brett's explicit approval
via admin bypass of the review ruleset): the 32-row
`gcdfo-to-smn.sssom.tsv`, the duplicate-property removal with replacement
rows, the `FisheriesReferencePointLower` re-namespacing, refreshed MIREOT
mirrors, pinned smn resolution — and gcdfo's `make ci` now reasons over the
merged gcdfo+smn closure (1b's deferred item). **Step 4 closed 2026-08-14:**
smn 0.0.3 released, PSC MR !6 merged with Brett's approval — the smn source
re-pinned to the sha256-pinned 0.0.3 snapshot, ten `prototype_accepted`
broadMatch rows publishing as `psc-to-smn.sssom.tsv` in v0.1.0-alpha.3, and
the alignment-gap objection retired (remaining gap documented: nine analysis
concepts need a shared smn analytical-method concept). Remaining in S9:
step 6 (propagation) and the parked #78 iop-triples explainer.

1. *(done)* Step 0 — recon + decisions.
2. **Step 1 — smn conventions + metamodel split.** CONVENTIONS.md hardening,
   the normative-alignment-core / teaching-view split, the eight verified
   metamodel fixes (F1–F8), repo-structure repairs, and a `robot reason` CI
   gate. Independent — can start now.
3. **Step 2 — methods-as-SKOS.** The vocabulary half of #76, ordered by
   Brett 2026-08-13. **smn side done** (PR #22; pun resolved, zero
   dual-typed IRIs). Cross-repo remainder formally reassigned: gcdfo
   follow-through → step 3, PSC doc update → step 4, metasalmon crosswalk
   retarget → the S8 breaking change.
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
