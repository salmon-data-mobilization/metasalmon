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
8. **Step 7 — clear the nine SPSR term-review holds** (gcdfo issues #67–#75,
   open since 2026-03-30 and untracked in this bundle until 2026-08-16). Each
   issue proposes one `gcdfo:` concept from the SPSR ontology-draft inventory
   and each is blocked on a decision, not on implementation — so the work is
   nine *decisions*, and they are **not nine independent ones**. They collapse
   into four, and the batching is the point: deciding them one issue at a time
   invites three different answers to the same question.

   | Group | Issues | The one decision |
   |---|---|---|
   | A — management geography | #67 DFO Management Area Name, #69 Lower Management Level, #75 Upper Management Level | Model the management-area *entity* once and reach names/levels through label and identifier properties, or mint a field concept per source column? |
   | B — sockeye life history | #68 Lake Type, #74 River Type | Split the mixed `LIFE_HISTORY_TYPE` source field into its own scheme, or reuse an existing smn/gcdfo term if one already covers the distinction? |
   | C — pink dominant cycle | #70 Odd Year Dominant Cycle | Dedicated dominant-cycle scheme or not — and if retained, mint the complementary `EvenYearDominantCycle` that the current SPSR extract does not contain? |
   | D — quality rating codes | #71/#72/#73 (codes 1/2/3) | Do `INFORMATION_QUALITY` and `INDEX_QUALITY` share one scheme, and should undocumented numeric codes become concepts at all rather than staying data until a published scheme exists? |

   Group D carries the sharpest risk: minting `QualityRatingCode1/2/3` with no
   authoritative meaning publishes an IRI that asserts a distinction nobody can
   define, and the two source fields may not even share a value set. "Leave it
   as data" is a legitimate outcome for a hold — **closing an issue as
   *rejected with reasoning* is a result, not a failure**, and #24's close is
   the precedent for recording why.

   Note the namespace question that #24 already settled once: these are
   proposed as `gcdfo:`, but life history and dominant cycle are general salmon
   concepts, not DFO administrative ones. Under the boundary the two ontologies
   now hold to, groups B and C most likely belong in `smn:` — which changes who
   decides them.

**Cross-repo bookkeeping rule (Brett, 2026-08-12/13):** every repo this stream
touches gets an OKF knowledge bundle (created if absent, updated as learned),
git-tracked, free of absolute filesystem paths, with an `AGENTS.md` pointer;
the execplan and the roadmap card are re-sequenced after every step.
