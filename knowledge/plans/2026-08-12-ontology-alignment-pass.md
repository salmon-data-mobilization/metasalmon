---
type: Artifact
title: "Ontology conventions and alignment pass"
description: "Execplan for the smn, gcdfo, and PSC CV conventions and alignment pass (stream S9); step 0 recon complete."
status: draft
tags: [execplan]
psc:
  id: metasalmon:plan:2026-08-12-ontology-alignment-pass
  contexts: [metasalmon:context:hub-coordination]
---

# Ontology conventions and alignment pass — smn, gcdfo, PSC CV

**Roadmap stream:** S9. **Status: step 0 complete, step 1 ready to start.**

This execplan is the detail home for the cross-vocabulary conventions and
alignment pass Brett requested on 2026-08-12. It is self-contained: a reader
with only the working trees listed below and this document can execute it.

---

## Purpose / Big Picture

Three vocabularies must interoperate through one shared layer:

- **smn** — the Salmon Domain Ontology (`smn:`, `https://w3id.org/smn/`),
  repo `../salmon-domain-ontology`, the shared
  cross-organization layer.
- **gcdfo** — the GC DFO Salmon Ontology (`gcdfo:`,
  `https://w3id.org/gcdfo/salmon#`), repo
  `../dfo-salmon-ontology`, DFO-specific semantics.
- **PSC CV** — the PSC controlled vocabulary, repo
  `../psc-salmon-vocabularies` (canonical source for this
  pass: branch `feature/fair-mapping-products-roadmap`;
  `psc-vocabulary-workbench` is **out of scope**).

The pass (a) refines smn's high-level conventions and its
`salmon-data-metamodel` views, (b) decides OWL-vs-SKOS per modelling case and
writes the decision down where CI can enforce it, and (c) publishes the
cross-vocabulary boundary as reviewable data instead of prose. Brett maintains
all three vocabularies, so no external coordination gates any change.

**What changes for the user:** a metasalmon user's `method_iri` /
`protocol_iri` / `aggregation_iri` values will resolve to concepts whose
modelling style is consistent across all three vocabularies; PSC mappings to
smn stop being blocked; and the merged graph (smn + gcdfo + profiles) becomes
safe input for deterministic reasoning.

### Consumption target (recorded decision, 2026-08-12)

Brett's answer to "what are these optimized for": SPARQL/SHACL/term-lookup
**plus neurosymbolic AI** — improving LLM comprehension of salmon-domain terms
and their relations, and enabling *deterministic checks of deductive logic*
during data integration and scientific analysis (see the
`neuro-symbolic-ai-wiki` OKF bundle under `~/.agents/wikis/`). Practical
consequence: the OWL layer should be **small but logically sound** — a
reasoner-clean backbone (no unintended punning, no false equivalences, no
accidental OWL-Full) — with breadth in SKOS. Heavy DL machinery is not the
goal; *correct* subsumption and clean instance typing are, because they are
what a deterministic checker consumes.

---

## Progress

- [x] **Step 0 — Recon and preference decisions** (2026-08-12). 14-agent
  survey + adversarial verification across all four repos and upstream specs;
  Brett answered the four preference questions. Findings recorded below.
- [x] Step 0 deliverables: this execplan; roadmap S9 added and S6 re-scoped;
  OKF knowledge bundle seeded in `salmon-domain-ontology` with `AGENTS.md`
  pointer (2026-08-12).
- [~] **Step 1 — smn conventions + metamodel split**: semantics half done
  (salmon-domain-ontology PR #21, 2026-08-13 — alignment-upper imports the
  W3C SOSA–PROV alignment, module-06 equivalences demoted, axiom-light
  views with iop: bridges, EscapementEstimate rename, CONVENTIONS §5b);
  tooling half (ELK CI gate, check scripts, Makefile hygiene, 08/09 drift
  gate, w3id views note) is the follow-up PR.
- [ ] **Step 2 — methods-as-SKOS across the trio** (couples with roadmap S8).
- [ ] **Step 3 — smn↔gcdfo boundary as data** (absorbs old S6 item 4).
- [ ] **Step 4 — PSC CV anchoring to smn.**
- [ ] **Step 5 — statistical-modifier scheme** (independent:
  runs after step 1, before or alongside S8, which consumes it).
- [ ] **Step 6 — propagation to workshop, hub, guides.**

After **each** step: update this Progress section, re-sequence
`knowledge/roadmap.md` if the step changed any dependency, and update the OKF
bundle of every repo the step touched (create the bundle if the repo lacks
one — standing instruction from Brett, 2026-08-12).

---

## Surprises & Discoveries

1. **PSC already refuses to map to smn because of the OWL/SKOS split.**
   `psc-salmon-vocabularies/docs/sdo-alignment-gap.md` declines any psc→smn
   SSSOM file because smn's method anchor is an `owl:Class`, while the 18
   released psc→gcdfo `skos:exactMatch` mappings target gcdfo's SKOS method
   concepts (pinned to gcdfo 0.0.8, commit `c7a54251`). The methods-as-SKOS
   question is not hypothetical; it is already deciding which mappings exist.
2. **A live cross-repo pun.** `smn:EnumerationMethod` is an `owl:Class`
   (⊑ `sosa:Procedure`) in smn (`modules/02:129`) and a `skos:Concept` in
   gcdfo (`dfo-salmon.ttl:1024`) — and gcdfo `owl:imports` smn
   (`dfo-salmon.ttl:200`), so any reasoner loading the closure sees the pun.
   Both repos' own conventions forbid this.
3. **gcdfo mints a term in smn's namespace.** `smn:FisheriesReferencePointLower`
   is declared only in `dfo-salmon.ttl` (~line 1920) with
   `rdfs:isDefinedBy <https://w3id.org/smn>`; smn never declares it.
4. **TDWG redefined `dwc:Occurrence` on 2026-05-26** — it is now "A dwc:Event
   that establishes the state of a dwc:Organism…", i.e. an event reading. Any
   crosswalk citing the older "existence of an organism" wording is stale.
   This *rescued* the view's `sosa:Observation skos:closeMatch dwc:Occurrence`
   (defensible now) while leaving module 06's `owl:equivalentClass` versions
   indefensible under any DwC vintage.
5. **The "REQUIRED ANNOTATION BACKFILL (auto-generated; do not hand-edit)"
   blocks have no generator.** `git log -S` shows they entered in one authored
   commit (`2549f74`); no script in the repo or its history writes them. The
   comment is a promise the tooling does not keep.
6. **`make verify-flat-ttl` mutates source** (rewrites generated modules 08/09
   in the working tree), and CI's drift gate does not cover 08/09 — a
   hand-edit there passes CI and is silently clobbered later.
7. **I-ADOPT 1.1.0 already has the statistical construct smn reinvented a
   placeholder for**: class `StatisticalModifier` + `iop:hasStatisticalModifier`
   (+ `VariableSet` and five `hasApplicable*` properties, new in 1.1.0).
   `smnv:variableUsesStatisticalModifier rdfs:range owl:Thing` is unnecessary.
8. **One unresolved contradiction between verification agents.** The F1
   verifier claimed the views' PROV axioms diverge from W3C's published
   SOSA–PROV alignment ("SSN maps `sosa:usedProcedure`, not
   `hasFeatureOfInterest`, to `prov:used`"); the upstream surveyor read the
   actual `w3c/sdw` `sosa-prov-mapping.ttl` and reports
   `sosa:hasFeatureOfInterest ⊑ prov:used` and `sosa:isSampleOf ⊑
   prov:wasDerivedFrom` **are** in it. Resolve in step 1 by reading the mapping
   file directly before writing the alignment-core module. Do not cite either
   claim until then.
9. **`dfo-salmon-ontology` was 109 commits behind origin/main** at recon start
   (fast-forwarded to 0.0.8 before any reading). A reminder to check checkout
   freshness before cross-repo review.
10. **Upstream `smn-data-pkg` added the registry the method model removes.**
   While the v2 draft was in review, smn-data-pkg merged PR #2 ("observation
   structures and methods profile"), adding an optional `metadata/methods.csv`
   registry + schema. The S8 port must unwind it. Found 2026-08-13 while
   resolving the dirty checkout (whose local edits turned out to be abandoned
   metasmn-rename leftovers, preserved on a local attic branch).

## Decision Log

| Decision | Rationale | Date |
|---|---|---|
| Consumption target: SPARQL/SHACL/lookup + neurosymbolic (reasoner-clean OWL backbone, breadth in SKOS) | Brett's answer; deterministic deductive checks require sound axioms, not many axioms | 2026-08-12 |
| Metamodel: split into a small **normative alignment-core module** + an **axiom-light teaching view** | Brett chose "Split" option; matches SSN's own practice of separately-published alignments | 2026-08-12 |
| Change posture: **anything goes** pre-1.0 — no deprecation stubs required, no mapping-file obligation | Brett's answer; nothing external consumes smn IRIs yet | 2026-08-12 |
| PSC CV canonical source: `feature/fair-mapping-products-roadmap`; workbench out of scope | Brett's answer | 2026-08-12 |
| OKF bundles: create/update in every repo the pass touches, `AGENTS.md` points at them | Brett's standing instruction this session; reuse the canonical PSC profile v0.4 + `psc-okf` validator from `psc-data-systems` (verified to work cross-repo) rather than inventing a parallel format | 2026-08-12 |
| Recommend adopting gcdfo's **methods-as-SKOS** stance in smn (step 2), with a thin `sosa:Procedure` instance-typing bridge | PSC's mapping refusal + gcdfo's working mappings are field evidence; I-ADOPT excludes methods from variables; `sosa:usedProcedure` expects an individual, which a SKOS concept is | 2026-08-12 — **pending Brett's confirmation at step 2 start** |
| **Methods-as-SKOS confirmed and ordered by Brett** ("migrate SMN methods from OWL classes to SKOS concepts") — the step-2 gate is satisfied; the v2 method-model draft names the concepts | Direct instruction; field evidence already pointed here | 2026-08-13 |
| **Statistical modifiers use I-ADOPT's own language and class**: SDP column `statistical_modifier_iri` (fifth I-ADOPT component column), values instance-typed `iop:StatisticalModifier`; the smn scheme is `smn:StatisticalModifierScheme` | Brett: "rather than aggregation_iri… use I-ADOPT's statistical_modifier language and class if possible and reasonable" — it is both | 2026-08-13 |
| **iop-triple emission deferred** — parked as backlog #78 (explainer before decision) under step 6 | Brett needs to understand when the triples are useful, the SDP→RDF emission pattern, and whether triple emission should be a general SDP capability | 2026-08-13 |
| smn-data-pkg dirty checkout resolved: abandoned metasmn-rename leftovers preserved on local branch `attic/abandoned-metasmn-rename-2026-06`, main fast-forwarded to origin (PRs #2, #3) | The edits referenced the never-adopted `metasmn` name and were superseded by upstream PRs; nothing was commit-worthy, nothing was destroyed | 2026-08-13 |
| Step 5 re-sequenced: independent of steps 2–4, runs after step 1 and before/alongside S8 | Original "steps 3–5 follow step 2" made S8 ⇄ S9 circular (S8 blocks step 2, yet step 5 fed S8); step 5 only needs module 07 + I-ADOPT 1.1.0 typing. Caught by Codex on PR #24 | 2026-08-13 |

## Outcomes & Retrospective

*(Filled as steps complete.)*

- Step 0 (2026-08-12): recon complete — six survey reports, eight adversarial
  verdicts (4 confirmed, 4 nuanced, 0 refuted). Full agent output preserved at
  the session task file and summarized below; the durable facts are being
  copied into per-repo OKF bundles as the pass touches each repo.

---

## Context and Orientation

Definitions for readers new to this stack:

- **OWL** — Web Ontology Language; classes/properties with logical axioms a
  reasoner can check. **SKOS** — Simple Knowledge Organization System;
  concepts in schemes with labels, definitions, and informal
  broader/narrower/mapping links. **Punning** — one IRI used as both a class
  and an instance (or SKOS concept); legal in OWL 2 but banned by both repos'
  conventions because it confuses consumers and some reasoners.
- **MIREOT** — copying a minimal subset of a foreign term's axioms/annotations
  into your ontology instead of importing the whole thing.
- **SSSOM** — a TSV standard for curated mapping sets with provenance;
  the PSC repo already emits and validates them.
- **I-ADOPT** (`iop:`, current release **1.1.0**) — W3C-community model that
  decomposes a variable into Property, Entity (roles: ObjectOfInterest /
  ContextObject / Matrix — roles, not classes), Constraint, and
  StatisticalModifier. It has **no method/unit component** (out of scope by
  design) and publishes **no** SOSA alignment axioms.
- **SOSA/SSN** — W3C observation ontology (2017 REC). All five of its
  published alignments (incl. PROV-O) are **non-normative**. A 2023 Edition
  is a First Public Working Draft (2025-09-16) — do not pin conventions to it.
- **The tier policy** — smn `CONVENTIONS.md §5`: Tier 1 =
  `owl:equivalent*`/`rdfs:subClassOf` etc. (automation-safe), Tier 2 =
  `skos:exactMatch`, Tier 3 = `skos:closeMatch`/`broadMatch`/… (advisory).
- **The metamodel views** — `ontology/views/salmon-data-metamodel*.ttl` in
  smn: a seven-slice "mental model" (entity, property, variable,
  method/protocol, event/observation, result/datum, provenance) that is
  deliberately not imported by any build.
- **smn builds** — main (`ontology/salmon-domain-ontology.ttl`, imports
  modules 01–07 + alignment-main), research (+ `alignment-research`),
  rda-case-study (+ generated bridge modules 08/09), and a generated flattened
  root `salmon-domain-ontology.ttl`.

### Step-0 recon: verified findings inventory

Eight adversarially verified findings on the metamodel (F1–F8), plus
structural findings. Evidence file:line citations live in the full agent
output; the durable copies belong in each repo's OKF bundle.

**Metamodel (fix in step 1):**

- **F1 (nuanced)** — views assert OWL axioms on foreign subjects
  (`iadopt:Variable ⊑ iao:0000030, sosa:Property`; `sosa:Observation ⊑
  prov:Activity`; three `sosa:* ⊑ prov:*` property axioms; …). Not an
  exposure incident — views are unreachable from every build, the flat
  artifact, w3id (live 404), and both sibling repos — but the policy gap is
  real and two axioms may diverge from W3C's own alignment (see Surprise 8).
  Fix: restate on smn/smnv-owned subjects; reference W3C's published
  alignment; CI guard that no build ever imports `views/`.
- **F2 (confirmed)** — Tier-1 + Tier-3 mappings on the same pair
  (`iadopt:Variable` ⊑ **and** closeMatch `sosa:Property`; module 06
  `equivalentClass` vs alignment-main `closeMatch` on
  `sosa:Observation`/`dwc:Occurrence` — both in the default build). Fix:
  one-strongest-mapping-per-pair rule in CONVENTIONS §5 + CI check; keep the
  alignment-main(Tier-3)→alignment-research(Tier-1) staging pattern only as a
  documented, whitelisted exception.
- **F3 (confirmed)** — `smnv:variableRepresents*`/`variableUses*` reinvent
  `iop:hasProperty`/`hasObjectOfInterest`/`hasConstraint`/`hasStatisticalModifier`
  without subPropertyOf bridges (while `smnv:constraintConstrains` *is*
  bridged, and the fraser example uses native `iop:` directly). Fix: drop the
  duplicates or bridge them; prefer native `iop:` in the normative core.
- **F4 (confirmed)** — the composite view uses relative `owl:imports`
  (filenames), unlike every other composition root (absolute w3id IRIs); no
  catalog file exists anywhere. Fix: absolute IRIs + `catalog-v001.xml` +
  either w3id `views/` routes or an explicit "not dereferenceable" note.
- **F5 (nuanced)** — `iadopt:Property ⊑ iao:0000030` is wrong by I-ADOPT's own
  definition (a characteristic, not a description) and collides with module
  06's `iadopt:Property owl:equivalentClass sosa:Property`; the ICE typing on
  `Variable`/`Constraint` is defensible. Fix per class, or demote all
  foreign-subject axioms in views to annotations.
- **F6 (confirmed)** — `smn:EscapementMeasurement` is the lone
  `*Measurement`-named class that is a **datum** (⊑ `iao:0000109`) rather than
  a subclass of the **activity** `smn:Measurement`. The name, inherited from
  gcdfo, is the defect; the mappings are correct. Fix: rename (e.g.
  `smn:EscapementEstimate`) — "anything goes" posture applies — coordinating
  gcdfo's `*CountMeasurement` hyponym family.
- **F7 (nuanced)** — keep `sosa:Observation closeMatch dwc:Occurrence`
  (post-2026-05-26 definition supports it); weaken `sosa:Sampling closeMatch
  dwc:Event` to `broadMatch`; **demote module 06's `owl:equivalentClass`
  versions** — indefensible under any DwC vintage, and in the default build.
- **F8 (nuanced)** — the statistical-modifier slot exists upstream
  (I-ADOPT 1.1.0). Fix: subPropertyOf + range `iadopt:StatisticalModifier`;
  mint `smn:AggregationStatisticScheme` in module 07 (step 5); SDP
  `aggregation_iri` resolves to it; Tier-3 links to ODM2 (whose CV hosting is
  HTTP-only and flaky — link, don't depend). Also fix the stale "via
  constraint_iri" line at `knowledge/method-model-draft.md:459`.

**smn structure (fix in step 1):** phantom "auto-generated" backfill blocks;
`verify` targets that mutate source; drift-gate gap for generated modules
08/09; import cycle (root ⇄ alignment-main); root-level generated TTL sharing
a basename with the modular source; module IRIs dereferencing to mutable
`raw.githubusercontent.com`; annotation completeness bimodal (43 missing
definitions already tracked in `docs/annotation-gap-ledger.md`); module 02
uses object properties between *classes* (`sosa:FeatureOfInterest
sosa:hasSample sosa:Sample` — instance-level triples on class subjects).

**Cross-repo (steps 2–4):** the pun, the minted term, the unbridged 18-term
age/year duplication, four gcdfo object properties duplicating smn twins
verbatim (zero semantic delta), PSC's closed SHACL shapes making any
convention enrichment a build-breaking change (budget for shape+code+CSV
changes together), PSC's SSSOM `mapping_date` hard-coded in `build.py:672`,
and gcdfo's ADR numbering drift (`docs/ADR.md` vs `docs/adr/`).

---

## Plan of Work

Each step ends with the bookkeeping loop (Progress, roadmap re-sequence, OKF
bundles). Ordering: steps 2→3→4 run in sequence (each mapping set targets a
settled model), but **step 5 is independent of steps 2–4** — it needs only
module 07 and I-ADOPT 1.1.0 typing, so it runs right after step 1, before or
alongside the S8 breaking change that consumes it. (Original draft had steps
3–5 all after step 2, which made S8 ⇄ S9 circular: S8 blocks step 2, yet
step 5 fed S8. Caught by Codex review on PR #24.)

### Step 1 — smn conventions + metamodel split (repo: salmon-domain-ontology)

The current step. Work items, in commit-sized slices:

1. **Resolve Surprise 8** — *done 2026-08-13*: the W3C file matches the
   views' axioms exactly (`hasFeatureOfInterest ⊑ prov:used` and
   `isSampleOf ⊑ prov:wasDerivedFrom` are both in it — the F1 verifier's
   divergence claim was wrong, the upstream surveyor right), and
   `http://www.w3.org/ns/sosa/prov` dereferences to the Turtle itself, so
   alignment-upper **imports** it. One subtlety: `sosa:Sample ⊑ prov:Entity`
   is *not* stated by W3C (entailed via FeatureOfInterest) — the old views
   over-asserted even relative to W3C.
2. **CONVENTIONS.md rewrite:** add one-strongest-mapping-per-pair (F2);
   explicit foreign-subject-axiom policy (allowed only inside clearly-marked,
   separately-published alignment modules, never in views or core modules —
   SSN practice); an instance-typing rule (a SKOS concept MAY be asserted an
   instance of a thin OWL class, e.g. `sosa:Procedure`, without violating the
   dual-IRI rule — this is the mechanism step 2 uses); document the
   research-staging exception; state the reasoner-clean invariant.
3. **Metamodel split (Brett's decision):** new normative
   `modules/alignment-core.ttl` (or extend alignment-main) carrying only the
   verified bridges — reference-not-reassert for SOSA–PROV; native `iop:`
   properties; corrected DwC pairings per F7 — imported by the main build;
   rebuild `views/` as an axiom-light teaching layer (annotations, seeAlso,
   diagrams) with F4's import/catalog fixes.
4. **Defect fixes:** F5 per-class split, F6 rename + gcdfo coordination
   issue, module 02 class-level property misuse, module 06 equivalence
   demotions (F7).
5. **Structure/tooling:** delete or implement the phantom backfill generator;
   make verify targets read-only (build to temp, diff); extend the drift gate
   to modules 08/09; break or document the import cycle; rename the flat
   artifact or move it; add `catalog-v001.xml`; w3id: per-file view routes or
   documented non-dereferenceability; version-pin module IRI targets.
6. **Reasoner-clean CI gate:** `robot reason` (ELK, plus HermiT if runtime
   allows) over main build and over main+gcdfo closure; fails on
   inconsistency, unintended punning (scripted check), or unsatisfiable
   classes. This is the neurosymbolic invariant made mechanical.
7. **Bundle:** update `knowledge/` cards with what implementation revealed.

### Step 2 — Methods-as-SKOS across the trio (smn + gcdfo + spec + metasalmon)

**Ordered by Brett 2026-08-13** — no further confirmation needed: migrate smn's method hierarchy
(`EnumerationMethod` family, `modules/02`) from `owl:Class ⊑ sosa:Procedure`
to SKOS concepts in a module-07 scheme, each instance-typed `sosa:Procedure`;
resolve the cross-repo pun (gcdfo drops its local re-typing once smn matches);
smn declares or gcdfo stops minting `smn:FisheriesReferencePointLower`. This
is the vocabulary half of **roadmap S8/#76** and unblocks PSC→smn mappings
(step 4). SDP `method_iri`/`protocol_iri` guidance in the method-model draft
updates to point at concept IRIs.

### Step 3 — smn↔gcdfo boundary as data (absorbs old S6 item 4)

One SSSOM mapping set for the ~55 name collisions and the 18-term age/year
duplication (bridge or delete one side — "anything goes" allows deletion with
the migration note); MIREOT-mirror policy written down (when gcdfo may mirror
smn terms, with a CI check that mirrors stay byte-consistent); drop gcdfo's
four zero-delta duplicate object properties; fix gcdfo ADR numbering; CI in
both repos validates the mapping set.

### Step 4 — PSC CV anchoring (repo: psc-salmon-vocabularies)

With smn methods as SKOS, the `sdo-alignment-gap.md` objection dissolves:
draft psc→smn SSSOM rows through PSC's own review pipeline
(`external-mapping-review.csv` → allow-listed source → SSSOM). Budget for
closed-shape revisions (shapes + `build.py` constants move together). Address
the hard-coded `mapping_date`. Do **not** relax PSC's promotion gate ("two
independently governed organizations") — record smn anchoring as mappings,
not promotion.

### Step 5 — Statistical-modifier scheme (independent: after step 1, before/alongside S8)

`smn:StatisticalModifierScheme` in module 07 seeded from the SDP draft's
starter list (mean, median, min, max, total, count, peak), concepts
instance-typed `iadopt:StatisticalModifier` (I-ADOPT's own class, per Brett's
2026-08-13 decision), Tier-3 links to ODM2; the SDP column is
`statistical_modifier_iri` — the fifth I-ADOPT component column — documented
to resolve here; metasalmon S8 breaking change consumes this. Fix
`smnv:variableUsesStatisticalModifier` range (or retire it with the view
rebuild).

### Step 6 — Propagation

Workshop (tidy-data + method episodes already scheduled in S4/S8), salmon
-ontology-hub docs, biologists' guides, I-ADOPT 1.1.0 features where useful
(`VariableSet` for SDP multi-variable tables is a candidate, not a
commitment). Update `knowledge/orientation.md` and both memory files in the metasalmon
memory directory if repo-map facts changed.

---

## Concrete Steps (step 1 kickoff)

```sh
cd ../salmon-domain-ontology
git checkout main && git pull --ff-only
# resolve Surprise 8:
curl -sL https://raw.githubusercontent.com/w3c/sdw/gh-pages/ssn/rdf/sosa-prov-mapping.ttl | less
# baseline the reasoner state BEFORE changes:
make install-robot && make verify-ontology-parse
# every change wave:
make test && make ci
```

Validation for OKF bundles (any repo):

```sh
cd ../psc-data-systems
uv run psc-okf check <repo>/knowledge --tier capture
```

## Validation and Acceptance

- Per-step: the touched repo's own `make ci` (smn), `make test` (gcdfo),
  `make ci` (psc-vocab) stay green; OKF bundles pass `psc-okf check`.
- Step-1 acceptance: main build parses, flat TTL drift gate green, **robot
  reason (ELK) reports consistent with zero unsatisfiable classes on both the
  main build and the main+gcdfo closure**, no Tier-mixed pairs (new CI check),
  no foreign-subject axioms outside declared alignment modules (new CI check),
  views import by absolute IRI and load in isolation via the catalog.
- Step-2 acceptance: no IRI in the merged closure is typed both `owl:Class`
  and `skos:Concept`; PSC's wrong-kind objection no longer applies (their doc
  updated); metasalmon suite green after crosswalk retarget.
- Step-3/4 acceptance: SSSOM files validate with the `sssom` toolchain and are
  CI-checked in their home repos.

## Idempotence and Recovery

All steps are git-branch + PR per repo; nothing mutates shared state outside
git. The smn repo's `make verify-flat-ttl` currently rewrites modules 08/09 in
the working tree — until slice 1.5 lands, run it only on a clean tree and
`git checkout -- ontology/modules/08* ontology/modules/09*` to recover (both
pathspecs must carry the directory — an unanchored `09*` matches nothing at
the repo root and git then rejects the whole command). Re-running the recon
workflow is safe (read-only). If a step is abandoned mid-way, the per-step
PR simply closes; the roadmap entry reverts to the prior state.
