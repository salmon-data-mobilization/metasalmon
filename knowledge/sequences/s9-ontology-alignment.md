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
re-pinned to the sha256-pinned 0.0.3 snapshot, nine `prototype_accepted`
broadMatch rows publishing as `psc-to-smn.sssom.tsv` in v0.1.0-alpha.3 (the
tenth, `PSC-CV-000017`, visibly deferred), and
the alignment-gap objection retired (remaining gap documented: nine analysis
concepts need a shared smn analytical-method concept). Remaining in S9: **step
7's B+C implementation** (below), step 6 (propagation), and the parked #78
iop-triples explainer.

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
   open since 2026-03-30 and untracked in this bundle until 2026-08-16;
   **#67 is now closed, eight remain**). Each
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

   **A 2026-08-16 evidence pass answered the factual half of all four groups**
   and is posted on the issues themselves (full write-ups on #67, #69, #68,
   #70, #71; pointers on #75, #74, #72, #73), so the record lives where the
   decision gets made. What it established, and how it moved each group:

   - **A is now two separate things.** `DFO_AREA` holds one of four DFO Pacific
     **salmon Areas** (South Coast, North Coast, Fraser and Interior, Yukon
     Transboundary) — not a PFMA, which is one of 48 SOR/2007-77 Schedule 2
     divisions. The SPSR inventory has *already* adopted
     `entity_iri = gcdfo:PacificFisheryManagementArea` for it, so **the mapping
     that exists is probably a category error**, and no `DFOManagementAreaName`
     concept is needed either way — the entity-plus-`rdfs:label` pattern is in
     place. Meanwhile #69/#75 may not be vocabulary at all: both fields have
     **zero observed values**, and the only unit-bearing definition in the
     source gives them units of "Number of fish", making them measurements
     rather than tiers. The two source documents genuinely disagree; a
     data-steward ruling settles it, not more reading.
   - **B collapsed into a bigger, better question.** `LIFE_HISTORY_TYPE` is
     mixed as suspected (sockeye rearing type + pink brood cycle), and it is
     also **perfectly redundant with the `CU_ID` prefix** — `SEL`/`SER`/`PKO`
     map one-to-one onto its values. A single **CU species-code vocabulary**
     (`CK`/`CM`/`CO`/`SEL`/`SER`/`PKE`/`PKO`) would resolve B and C together
     instead of two schemes.
   - **C's stated gap is closed.** `PKE` (Pink-Even) *is* documented in the DFO
     CU species-code list even though the extract contains only odd-year rows.
     So the question is no longer "does the complement exist" but the general
     policy call: **mint from the source vocabulary or from observed data?**
     Worth deciding once for every SPSR hold.
   - **D's assumed shape is ruled out.** `INFORMATION_QUALITY` and
     `INDEX_QUALITY` are **two different published 1–5 frameworks** — Ogden 2015
     §2.3 and the New Zealand Quality Index, named verbatim in the SPSR
     `Definitions` sheets. They never co-occur with values in any table, and
     codes 1 and 3 appear only in `INFORMATION_QUALITY`. So framework-neutral
     `QualityRatingCode1/2/3` shared across both fields would conflate two
     distinct scales. Neither framework document is obtainable from these
     repos, so **the meaning of the integers is not documented anywhere
     readable**; gcdfo already carries an ordinal DFO quality vocabulary at
     `gcdfo:EstimateTypeScheme` (Hyatt 1997, Type-1…Type-6).

   Group D still carries the sharpest risk: minting concepts for integers whose
   meaning no available document defines publishes IRIs asserting a distinction
   nobody can state. "Leave it as data until a published scheme is in hand" is
   a legitimate outcome — **closing an issue as *rejected with reasoning* is a
   result, not a failure**. Note there is **no precedent for it in this
   repository yet** — #24 is sometimes cited as one and is not: it closed as
   *completed*, because the `LifePhaseScheme` terms were minted, just under
   `smn:` instead of the proposed `gcdfo:`. It is a precedent for recording why
   a delivery differs from the request. A hold closed as rejected would be the
   first of its kind, so its reasoning has to stand on its own rather than lean
   on an earlier close.

   Note the namespace question that #24 already settled once: these are
   proposed as `gcdfo:`, but life history and dominant cycle are general salmon
   concepts, not DFO administrative ones. Under the boundary the two ontologies
   now hold to, groups B and C most likely belong in `smn:` — which changes who
   decides them.

   ### Decided (Brett, 2026-08-17)

   All four groups ruled on. Two of the four went against the recommendation
   above, which is why the reasoning is recorded rather than just the outcome.

   | Group | Ruling |
   |---|---|
   | **A1** (#67) | **Mint the PFMAs as a controlled vocabulary** in gcdfo, sourced from DFO materials, then close #67. The alternative — a separate four-value "DFO salmon Area" entity, which is what the evidence pointed at — was **rejected**. |
   | **A2** (#69, #75) | **Capture as an issue.** Filed as **#84**, posing the single question: quantitative abundance reference points, or a coded hierarchy? Needs a data-steward ruling; #69/#75 stay open behind it. |
   | **B + C** (#68, #74, #70) | **Three separate schemes, in `smn:`, scoped "very broad"** — explicitly *not* the single merged CU species-code vocabulary recommended above. Broad means species-agnostic: a life-history-type scheme that contains lake- and river-type rather than a sockeye scheme. Brett's second constraint is that **PSC should be able to leverage them**, so they are designed for `psc-salmon-vocabularies` to map onto rather than mint parallels. Mint from the source code list, not observed values — `PKE` lands alongside `PKO`. |
   | **D** (#71–#73) | **Capture as an issue.** Filed as **#85**. Brett's constraint closes an option the evidence had left open: **`gcdfo:EstimateTypeScheme` (Hyatt 1997) is specifically only for escapement measurements**, so it must not be the mapping target for general data-quality codes. |

   **B+C proposed, and contested — do not read the design as agreed.**
   salmon-domain-ontology
   [PR #27](https://github.com/salmon-data-mobilization/salmon-domain-ontology/pull/27)
   is an open **draft** proposing three orthogonal `smn:` SKOS schemes —
   life-history type, cycle line, salmon species — closing gcdfo #68/#74/#70 by
   reference on acceptance. It is under active discussion and being reworked:
   the species approach, whether a cycle-line concept should exist at all, and
   the life-history structure are each still in question. Track it as an open
   proposal; the ruling in the table above fixed the *namespace and breadth*,
   not the modelling.

   **A1 delivered** (gcdfo PR #86, issue #67 closed): 48 concepts plus
   `gcdfo:PacificFisheryManagementAreaScheme`, sourced from SOR/2007-77
   Schedule 2 (consolidation current to 2026-06-17) and cross-checked against
   DFO's published area listing. Scope is **Areas only** — Schedule 2's 604
   numbered Subareas are deliberately not minted, and the scheme's
   `skos:scopeNote` says so, which makes the vocabulary complete for Areas and
   explicitly silent about Subareas rather than quietly short. PR #86 merged
   **after** the 0.0.9 tag, so the vocabulary is on gcdfo `main` and in no
   release; cite the commit until the next gcdfo release cuts.

   **Correct the count wherever it appears: there are 48 PFMAs, not ~142.**
   142 is the highest area *number* (the set is Areas 1–29, 101–111, 121,
   123–127, 130, 142), not a cardinality. The wrong figure was in the evidence
   comment on #67 and in this card; Schedule 2 numbers its items 1–48
   contiguously, so a gap would have meant a missed area and there is none.

   **The A1 caveat survives the ruling, and got sharper.** Minting the PFMA
   vocabulary does not make `DFO_AREA`'s values members of it, and #67's close
   says so. Closing #67 left that mis-mapping untracked; it is now tracked as
   `spsr-data-dict` **issue #1**, filed 2026-08-17. What remains open, none of
   it resolved by PR #86:

   - `DFO_AREA` is **still mapped to the wrong entity** in `spsr-data-dict`'s
     `columns.csv` (line **13**, not 15 as previously recorded) — wrong before
     that PR and wrong after it.
   - **No term exists for the coarse DFO salmon Area**, since minting one was
     rejected, so `DFO_AREA` has no correct `entity_iri` available in either
     ontology today. That is the live gap, and the substance of issue #1 — it
     is a gap, not a typo, so the column cannot simply be repointed.
   - `PFMA_ID` is an **unpopulated slot**: one fixture row in the live table,
     6288/6289 population foreign keys NULL, and the SDP export is the literal
     string `NA` for all 737 rows.
   - The stored values are **uppercase** and read `YUKON AND TRANSBOUNDARY`,
     not "Yukon Transboundary" as the data dictionary phrases it — any value
     mapping written from the dictionary text will silently miss.

   Scoping issue #1 against the remaining B+C work is still Brett's call.

   **Open disposition question:** #72's distinguishing premise — that code `2`
   is shared between `INDEX_QUALITY` and `INFORMATION_QUALITY` — is factually
   false, so nothing answerable remains in it. #71 and #73 are hollow but not
   false. Closing all three as rejected-with-reasoning, with #85 as successor,
   is defensible **only if** the `spsr-data-dict` hold drafts are dispositioned
   in the same change, or the inventory and the tracker will disagree. Not done;
   awaiting Brett.

**Cross-repo bookkeeping rule (Brett, 2026-08-12/13):** every repo this stream
touches gets an OKF knowledge bundle (created if absent, updated as learned),
git-tracked, free of absolute filesystem paths, with an `AGENTS.md` pointer;
the execplan and the roadmap card are re-sequenced after every step.
