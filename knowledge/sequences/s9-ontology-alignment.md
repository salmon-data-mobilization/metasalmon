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

   **There is now a mechanism for exactly this, and it is not optional.**
   `salmon-knowledge-commons` carries a **term lifecycle** — see the
   [domain card](../domains/salmon-data-ecosystem.md#the-term-lifecycle-is-what-connects-the-commons-to-the-ontologies).
   Every gap has `state ∈ {open, proposed, rejected, minted}`, and **when a
   term proposal closes unmerged the gap returns to the commons as `rejected`
   with `rejected_because` and `evidence_needed`, in the same change that
   closes the proposal.** The schema enforces it: both fields are required in
   the `rejected` state, each with a 40-character minimum.

   Two consequences for this step. Closing #71–#73 as rejected-with-reasoning
   now has a **home for the reasoning** other than the issue thread, which is
   what the "its reasoning has to stand on its own" worry was really about —
   `evidence_needed` is precisely "Ogden 2015 §2.3 and the New Zealand Quality
   Index, obtained". And if **PR #27's species scheme stays withdrawn**, that
   is a closed-unmerged proposal and the commons gaps it came from should move
   to `rejected` in the same change — not left `open`, which would read as
   nobody having tried and invite the next agent to re-propose it.

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
   is an open **draft**, headed *"Proposal — do not merge"* with its ADR-0003
   at `Status: Proposed`. The ruling in the table above fixed the *namespace
   and breadth*, not the modelling, and the modelling is what is still open.

   **The proposal was reworked 2026-08-17 and this card described the first
   draft until 2026-08-18.** What it proposes now:

   | | First draft | Now |
   |---|---|---|
   | Shape | 3 schemes / 12 concepts | **4 schemes / 13 concepts / 5 properties = 22 terms** |
   | Species | `smn:SalmonSpeciesScheme` + 5 species concepts | **Withdrawn — deleted, not replaced** |
   | Life-history type | Two flat concepts | **Decomposed into two species-neutral axes** (`JuvenileFreshwaterResidenceScheme`, `JuvenileNurseryHabitatScheme`) plus species-scoped named types |
   | Cycle line | "largely independent *reproductive* lines" | **A year-series construct**; the reproductive claim moved onto its own property |
   | Closes by reference | gcdfo #68 / #74 / #70 | **gcdfo #68 and #70 only** |

   Why species was withdrawn is worth carrying, because it kills the option
   rather than deferring it: **steelhead is in scope** (Brett, 2026-08-17) and
   has no taxonomic identifier in ITIS, WoRMS, NCBI, GBIF or Catalogue of Life
   — it is a vernacular for anadromous *O. mykiss* in all five. A vocabulary
   that must carry steelhead is not a species vocabulary. The source's codes
   (`SEL` = sockeye × lake-type, `PKO` = pink × odd-line) are administrative,
   not taxonomic, and the authorities actively disagree with each other on
   cutthroat rank. The only species assertion left anywhere in the change is a
   literal `dwc:scientificName`.

   **PR #27 is `CONFLICTING` / `DIRTY`, and the conflict is one changelog
   block. Merge `main`; do not rebase.** *(This card previously described the
   conflict as a hazardous rebase across the whole flat TTL, which is why the
   PR has been treated as dangerous to touch. That was never measured. It is
   now, and it was wrong.)* Measured 2026-08-21 from the merge base
   `f7205ee`:

   - **The only files changed on both sides are `docs/index-en.html` and
     `docs/index.html`.** `main` changed seven files, the branch fifteen; the
     intersection is those two.
   - **The conflicting region in each is a single changelog block, and both
     sides applied the same fix.** Both replace `<div id="changelog">null</div>`
     — `main` with the empty "Changes from last version" heading, the branch
     with the fully generated block. Same defect, same direction, different
     completeness.
   - **The flat TTL and `docs/smn.ttl` do not conflict at all.**
     `salmon-domain-ontology.ttl` and `docs/smn.ttl` are branch-only; `main`
     never touched them. The prefix rewrite of decision 5 is large, and it is
     large *alone* — nothing merges into it.
   - **`scripts/build_flat_smn_ttl.py` is untouched by `main`.** That is where
     the backlog **#89** determinism fix lives, so **no merge strategy can drop
     it.** The re-arming-a-CI-flake worry was real as a worry and is
     unsupported as a fact.
   - **All three CI checks pass on the branch** — *Reasoner gate (ELK)*,
     *Validate committed ontology artifacts*, *Verify published docs artifacts*.

   So the instruction is: **merge `origin/main` into the branch** (a rebase
   replays every branch commit over `main` and re-resolves the same two
   generated files repeatedly, for nothing), **take the branch side on both
   generated HTMLs**, **regenerate the docs**, and let the
   `verify-generated-artifacts` recipe — which the *Verify published docs
   artifacts* job runs — prove the result rather than asserting it by hand. A
   generated file is the one kind of conflict you never resolve by reading:
   you resolve it by rebuilding.

   *Retires when:* PR #27 is merged or closed. If it is reworked again, re-measure
   rather than trusting this paragraph — that is exactly the mistake it replaces.

   **PR #27 does not unblock the Fraser Recruits case study
   ([S13](s13-fraser-recruits-case-study.md)), and it has been assumed to.**
   Measured 2026-08-21: the recipe uses **twelve distinct `smn:` terms** —
   `Abundance`, `AgeAtReturnBasis`, `AgeClassValue1`, `AgeClassValue2`,
   `BroodYearBasis`, `FreshwaterAgeDimension`, `GilbertRichAgeNotation`,
   `Observation`, `RecruitAbundance`, `ReturnYearBasis`, `SpawnerStageContext`,
   `Stock` — and **all twelve already exist** in `salmon-domain-ontology.ttl`.
   (A thirteenth `w3id.org/smn/` match is the `modules` path segment, not a
   term; count carefully, because thirteen is the number a naive grep returns.)
   The recipe mentions **cycle line and life history nowhere at all**. Both
   streams are Fraser sockeye, which is what makes the assumption natural and
   wrong: S13's ontology dependency is on terms that shipped in smn 0.0.3, not
   on this proposal. Sequence them independently.

   ### The decisions PR #27 needs from Brett

   The PR lists **seven** open questions; five of them change what gets
   minted, and none can be settled by an implementer. An **eighth** was found
   here and is not on the PR's list at all — it is row 8 below. **Owner: Brett**
   on all six in the table — each is a modelling or policy call in `smn:`, and
   the B+C ruling above deliberately left modelling out of scope.

   | # | Decision | Why it cannot be deferred to whoever implements |
   |---|---|---|
   | 1 | **Does "species go in `smn`, never `gcdfo`" survive a `gcdfo` code vocabulary carrying `dwc:scientificName` + a WoRMS `dwc:scientificNameID` directly?** | Two of Brett's own 2026-08-17 statements pull against each other. They reconcile **only if the gcdfo codes never need an `smn:` species concept to point at** — which is a boundary question, not a preference. The standing "species are never minted in `gcdfo`" ruling recorded below is what is at stake |
   | 2 | **Is `dwc:scientificName` as a bare literal acceptable on a life-history concept?** | It is the minimum that makes "species-scoped" machine-checkable rather than a naming convention, and it commits to no authority — but it is also the last species assertion of any kind in the change, so rejecting it removes species from the artifact entirely |
   | 3 | **Two decomposition properties, or one generic `smn:hasLifeHistoryAxisValue`?** | A generic property lets a future axis be added with no new term, at the cost of a two-hop query through `skos:inScheme`. Cheap now, expensive to reverse once consumers query it |
   | 4 | **Is `smn:SockeyeSeaTypeLifeHistory` wanted at all?** | It is **not in the source data**. It is minted to complete the duration axis and to put the "sea-type" homograph warning on a term rather than in a document — Gilbert 1913's name for chinook ocean-type is today a sockeye type, same string, two species-scoped meanings. This is the mint-from-source-vocabulary-versus-observed-data policy applied to a concrete term |
   | 5 | **Accept the large, semantically empty prefix rewrite, or take the smaller fix?** | Binding the prefixes was necessary (it is the #89 fix). Rewriting the *published* artifact while doing it was a judgement call: the alternative leaves smn's own namespace rendering as `ns3:` in its own published TTL. Accepting it means one enormous diff, taken once |
   | 8 | **Are lake-, river- and sea-type sockeye peers, and if the PR mints them as peers, must a scope note say so?** | Not on the PR's list — see below. It asserts a grouping the cited literature reports as unsettled, in a `skos:Concept` that consumers will read as a fact |

   **Decision 8 — sockeye river-type peerhood (new, 2026-08-21).** PR #27 mints
   `smn:SockeyeLakeTypeLifeHistory`, `smn:SockeyeRiverTypeLifeHistory` and
   `smn:SockeyeSeaTypeLifeHistory` as three flat `skos:broader
   smn:LifeHistoryType` peers in `smn:LifeHistoryTypeScheme`, sourced to Burgner
   1991 and Holtby & Ciruna 2007. `salmon-knowledge-commons` records the same
   distinction with gap status **`contested`**: Beacham & Withler 2017 report
   that **river-type has been considered a special case of sea-type**, because
   neither rears in lakes — a grouping by nursery habitat that cuts across the
   duration axis, and *both* readings are in that one paper.

   The three scope notes on the PR's concepts are careful about other hazards
   (the `SEL`/`SER` code halves, the chinook `sea-type` homograph, the
   stream-type false friend) and **say nothing about this one**. So the artifact
   asserts peerhood where the source declines to. The PR's axis properties encode
   a *different* grouping again — river-type and lake-type share
   `YearlingFreshwaterResidence` while sea-type does not — so the modelling
   splits by duration, the commons's contested reading splits by habitat, and
   the flat scheme records neither as a choice.

   Three possible rulings: **(a)** peers are right, and a `skos:scopeNote`
   records that Beacham & Withler group them otherwise; **(b)** peers are wrong
   and river-type gets `skos:broader smn:SockeyeSeaTypeLifeHistory`, which
   changes the hierarchy consumers query; **(c)** peers stand with no note,
   accepting that the vocabulary is more decided than its sources. Only (c) is
   free, and it is the one that cannot be reversed quietly later.
   **Unblocks:** gcdfo **#74** (*Term review: River Type Life History*), which
   is the hold this concept exists to close — see the closes-by-reference
   inconsistency flagged above, which is about the same term. *Retires when:*
   Brett rules, and the commons gap moves off `contested` in the same change.

   Questions 6 (*"cycle line" renames away from issue #70's wording*) and 7
   (*proposed straight into shared `smn:` rather than a
   `smn/profile/<program>/` bridge, where CONVENTIONS §8 criterion 1 is
   expected reuse rather than demonstrated*) are also open but do not change
   the minted terms.

   **One inconsistency to resolve while deciding, because it will otherwise
   close the wrong issue.** PR #27's closes-by-reference list names gcdfo #68
   and #70 and says *"#74 (species) stays open"* — but **#74 is "Term review:
   River Type Life History"**, not a species issue (verified against the issue
   directly, 2026-08-18), and the PR **does** mint
   `smn:SockeyeRiverTypeLifeHistory`, which is exactly what #74 asks for. So
   either the annotation is a slip and #74 should close with #68, or something
   about river-type is deliberately being held back and the reason is not
   recorded anywhere. It reads as a leftover from the withdrawn species scheme.

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

   **Species concepts are never minted in `gcdfo` (Brett, 2026-08-17).** They
   belong in `smn:`, the shared all-agency layer. `gcdfo:` is the DFO-specific
   layer, and a salmon species is not a DFO administrative fact — no agency
   owns it, and minting one there would hand every other agency a term it has
   to map around instead of use. This closes the namespace question the
   analysis above left at "most likely" for group C, and it closes it for
   *future* proposals too: the merged CU species-code vocabulary was rejected
   on shape, and this ruling means it cannot come back on a different
   namespace either. Standing and not scoped to these holds — it governs the
   species scheme in
   [salmon-domain-ontology PR #27](https://github.com/salmon-data-mobilization/salmon-domain-ontology/pull/27)
   and every later species proposal. **Retires only if the smn/gcdfo boundary
   itself is renegotiated** (step 3's boundary, published as data in
   `gcdfo-to-smn.sssom.tsv`); a species term appearing under `gcdfo:` is a
   defect to report, not a precedent to follow. **Decision 1 above puts this
   ruling in play** — a `gcdfo` code vocabulary carrying `dwc:scientificName`
   plus a WoRMS identifier is the shape that would test it, so do not treat the
   ruling as settled while that question is open.

   ### Where the SPSR holds actually stand (checked 2026-08-18)

   **Eight of nine remain open**: gcdfo #68–#75. Only #67 closed (2026-08-17,
   as *completed*, alongside PR #86). None of the eight is blocked on an
   implementer, and they are blocked in **two different ways** that want
   different actions:

   | Holds | Blocked on | What unblocks it |
   |---|---|---|
   | **#69, #75** (management levels) | A **data-steward ruling**, tracked as gcdfo **#84** | Whether `UPPER_`/`LOWER_MANAGEMENT_LEVEL` are quantitative abundance reference points or a coded hierarchy. The two source documents genuinely disagree, both fields have **zero observed values**, and the only unit-bearing definition gives them units of "Number of fish" — so more reading will not settle it. A person with authority over the SPSR data must rule |
   | **#71, #72, #73** (quality codes) | **Sourcing two documents**, tracked as gcdfo **#85** | Ogden 2015 §2.3 and the New Zealand Quality Index — the two published 1–5 frameworks `INFORMATION_QUALITY` and `INDEX_QUALITY` cite by name. **Neither is obtainable from these repos**, so the meaning of the integers is documented nowhere readable. This is a *retrieval* task, and it is the whole blocker |
   | **#68, #70, #74** (life history, cycle line) | **PR #27's six decisions** above | Brett's rulings on the modelling. #68 and #70 close by reference on acceptance; #74 is blocked twice over — by the closes-by-reference inconsistency flagged above and by decision 8, which is about the river-type concept itself |

   The distinction matters for sequencing: #71–#73 could be unblocked by
   anyone who can obtain two documents, while #69/#75 cannot be unblocked by
   effort at all. Filing them together as "SPSR holds" has hidden that.

   ### Process exception: gcdfo PR #87 merged with no Kanban item

   **Recorded rather than left silent.** dfo-salmon-ontology PR
   [#87](https://github.com/dfo-pacific-science/dfo-salmon-ontology/pull/87)
   (*"docs: route durable salmon knowledge to salmon-knowledge-commons"*,
   merged 2026-08-18 as `e2a0888`) went through with no item on the repo's
   GitHub Project board. That repo's `AGENTS.md` **"Git Workflow (Preferred
   Pattern)"** section states as a non-negotiable: *"Always use a repo GitHub
   Project Kanban board"*, with items moving Todo → In Progress → In Review →
   Done. The PR is small, docs-only, and its content is not in question; the
   exception is procedural.

   It is logged here for one reason: **an unrecorded exception is
   indistinguishable from the rule not existing.** The next agent to skip the
   board has a precedent it cannot see was an exception, and the rule erodes
   without anyone deciding to drop it. That is the same failure mode this
   bundle's guard-expiry contract exists to prevent, applied to process rather
   than to code. Either the board requirement is real and this was an
   exception, or it is aspirational and `AGENTS.md` should stop calling it
   non-negotiable — **Brett's call**, and this note is the ask.

   Note the same commit landed as a sibling PR in four other repos the same
   day (metasalmonpy #9, salmon-domain-ontology #28, salmon-knowledge-commons,
   plus PSC MR **!9**, which is **still open** — the one unmerged limb).

**Cross-repo bookkeeping rule (Brett, 2026-08-12/13):** every repo this stream
touches gets an OKF knowledge bundle (created if absent, updated as learned),
git-tracked, free of absolute filesystem paths, with an `AGENTS.md` pointer;
the execplan and the roadmap card are re-sequenced after every step.
