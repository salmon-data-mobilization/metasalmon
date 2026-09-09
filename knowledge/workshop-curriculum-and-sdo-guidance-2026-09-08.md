---
type: InformationObject
title: "Workshop curriculum and SDO guidance findings, 2026-09-08"
description: "Source-pinned curriculum state and draft guidance improvements for teaching local vocabularies, ontology bridges, and term stewardship without conflating technical checks with approval."
status: draft
tags: [workshop, ontology, contributions, evidence]
psc:
  id: metasalmon:information:workshop-curriculum-2026-09-08
  contexts: [metasalmon:context:hub-coordination]
---

# Workshop curriculum and SDO guidance findings

Prepared by the Codex authoring assistant on 2026-09-08 from the sources below.
This is a draft synthesis and proposed documentation change set. It records no
independent human verification, scientific approval, issue submission, or SDO
change. Brett authorized the workshop expansion and this coordinating-hub
update in the interactive session. S4 owns the curriculum state; this card does
not change other streams' priorities or general publication decisions.

## Curriculum state and evidence boundaries

The published Day 1 baseline is workshop commit
[`190df307b4e486d97f9899fa26c4bdff376a66dd`](https://github.com/salmon-data-mobilization/salmon-data-standards-workshop/tree/190df307b4e486d97f9899fa26c4bdff376a66dd).
It follows the same 173-row, 14-column Fraser Coho 2023–2024 source through
human graphing, dictionary/decomposition/peer review, packaging, mapping and AI
comparison, code meanings, and validation/EML/test-publication inspection.
The seven chapters total 360 minutes (55/55/65/40/70/30/45). The published
site's R/Python/Spreadsheet tab synchronization and glossary/extended-practice
navigation were checked in a browser on 2026-09-08. A successful site deployment
does not establish a public KNB record or domain review.

The authorized Day 2 expansion adds chapters 8–12, timed 60/75/90/75/60
minutes, for another 360 minutes of semantic practice using the unchanged
source. The complete implementation was committed and pushed directly to
`main` at [`27e0ced`](https://github.com/salmon-data-mobilization/salmon-data-standards-workshop/tree/27e0cede5709de4bfebb9894c45a038259305456) on 2026-09-08, as authorized by Brett.
Local Sandpaper rendering, rendered links and download integrity, source
fidelity, the four-concept vocabulary, 15 model checks and 10 bridge checks
passed. An independent automated review found no remaining substantive
findings. Browser inspection confirmed chapter navigation, diagrams, glossary
anchors and all three contribution tabs. The extracted kit also passed its
offline reference checks. These are technical observations, not human review.
The [build and deployment workflow](https://github.com/salmon-data-mobilization/salmon-data-standards-workshop/actions/runs/34304171873) passed.
On 2026-09-08 (Pacific time), anonymous HTTP checks returned 200 for the
homepage and all five new chapters. The public ZIP matched the committed
307,381-byte artifact, SHA-256
`3922ff49b6d7f2e713548b5e1d0703b7a4c353d822e431129461502ca1f4745d`.
A browser check of the deployed Chapter 12 confirmed its content and Python
tab behavior. Existing Varnish theme favicon warnings remain documented
separately from the passing lesson-content link checks.
Chapter 12 produces a source-backed, unsubmitted term request or clarification,
with an actual peer-review record when performed and a named next role/action.
It does not require live AI, ontology publication, or issue posting.

The actual Chapter 2–3 human preparation remains a prerequisite. The technical
reference is pending Bruno and Tom's scientific review. The baseline kit's
validation/status report separately records the independent SDP validator
mismatch, unsuccessful live free-provider rehearsal, and absent public KNB
test record. New curriculum does not silently close those conditions.

R is pinned to metasalmon 0.5.0 and Python to metasalmonpy 0.4.0. For Chapter
12, both pinned implementations executed candidate detection and request
rendering against the supplied seeded suggestion file: two candidate rows,
for the property and variable roles of `NATURAL_ADULT_SPAWNERS`, with the same
automatic new-term title. This is evidence about the renderer, not proof of
term absence. The corresponding kit receipt records input checksum, exact
Python tag commit, compared columns, and no submission. The lesson directs a
human to inspect existing terms and rewrite the request as warranted.

## Source pins

| Source | Observed revision / authoritative location |
| --- | --- |
| SMN modeling policy | [`CONVENTIONS.md` at d45f8f7](https://github.com/salmon-data-mobilization/salmon-domain-ontology/blob/d45f8f7cc857d92af8bbe54a7c89b2a4a14784b2/CONVENTIONS.md), especially §§2–5b, 8, 10, 12 |
| SMN beginner bridge guide | [`modules-and-bridges-for-biologists.md` at d45f8f7](https://github.com/salmon-data-mobilization/salmon-domain-ontology/blob/d45f8f7cc857d92af8bbe54a7c89b2a4a14784b2/docs/guides/modules-and-bridges-for-biologists.md) |
| SMN request template | [`new-term-request.md` at d45f8f7](https://github.com/salmon-data-mobilization/salmon-domain-ontology/blob/d45f8f7cc857d92af8bbe54a7c89b2a4a14784b2/.github/ISSUE_TEMPLATE/new-term-request.md) |
| DFO boundary and contribution rules | [`README.md` at 26d7c38](https://github.com/dfo-pacific-science/dfo-salmon-ontology/blob/26d7c388a2c97b4098cf267eddca44857f81b36b/README.md), [`CONTRIBUTING.md`](https://github.com/dfo-pacific-science/dfo-salmon-ontology/blob/26d7c388a2c97b4098cf267eddca44857f81b36b/CONTRIBUTING.md), and [`GOVERNANCE.md`](https://github.com/dfo-pacific-science/dfo-salmon-ontology/blob/26d7c388a2c97b4098cf267eddca44857f81b36b/GOVERNANCE.md) |
| DFO documented class-mapping exception | [`ontology/modules/README.md` at 26d7c38](https://github.com/dfo-pacific-science/dfo-salmon-ontology/blob/26d7c388a2c97b4098cf267eddca44857f81b36b/ontology/modules/README.md), section “Why these files use skos:closeMatch between OWL classes” |
| MetaSalmon concept-mapping versus decomposition contract | [`R/sssom.R` at 2ef11d3](https://github.com/salmon-data-mobilization/metasalmon/blob/2ef11d38e08593f8f388f858342ca0715c9fa12e/R/sssom.R) and [`post-review-package-publication.Rmd`](https://github.com/salmon-data-mobilization/metasalmon/blob/2ef11d38e08593f8f388f858342ca0715c9fa12e/vignettes/post-review-package-publication.Rmd) |
| Pinned Python preview | [metasalmonpy v0.4.0 source, 3b587e6](https://github.com/salmon-data-mobilization/metasalmonpy/tree/3b587e6be20d5feaf12c3640d48e449681271d23) |
| General semantics | [W3C SKOS Reference](https://www.w3.org/TR/skos-reference/), [OWL 2 Primer](https://www.w3.org/TR/owl2-primer/), and [SHACL Recommendation](https://www.w3.org/TR/shacl/) |

## Draft SDO guidance improvements — no upstream mutation

These recommendations belong in a reviewed documentation change to the existing
SMN guide/conventions/templates, not another ontology or parallel validator.

### 1. Separate ownership from representation

**Observed:** the guide's three-level overview is helpful, but “local profile
ontology” can sound as though all local values must become OWL classes.
CONVENTIONS §3 already distinguishes code lists from logical structure.

**Proposed wording:** “Choose ownership and representation separately. Local
code values normally form a SKOS scheme; a local OWL class/property is useful
when a stated reasoning question requires it. Either can stay in an
organization-owned namespace. A bridge connects terms without transferring
ownership. Shared promotion requires a reviewed cross-organization use case.”

Keep the existing separate-IRI rule and clarify that a SKOS concept typed as
an instance of `sosa:Procedure` is not an `owl:Class`/`skos:Concept` dual use.
Completion evidence: one local CV example and one separate logical-model
example, with their different questions and output types explicitly named.

### 2. Replace the label-driven exact bridge illustration

**Observed:** the guide calls its fictional `SpawnerSurveyEvent exactMatch
smn:SurveyEvent` example “strong and likely safe” without matching definitions,
and relates a confidence-band label to a benchmark. Those examples should not
be copied as scientifically justified mappings. The DFO module guide also
documents existing class-to-class SKOS mapping exceptions; this is a known
practice issue, not a claim that all such patterns are absent today.

**Proposed change:** use two explicitly SKOS concepts with sourced definitions
for a concept-mapping lesson. For OWL class alignment, show the logical claim
in words and use a separate candidate record until a subclass/equivalence
axiom is justified. Do not encourage class/concept cross-role SKOS mappings.
Keep existing exceptional class-to-class mappings untouched pending their own
review; neither deleting them nor strengthening them is a documentation fix.

Same-source exercise: retain `Resistivity Counter` as a local source label,
inspect DFO `FixedSiteCensusElectronic` as a candidate with broader technical
scope, and ask for the operational source definition. The NuSEDS dictionary
provides `N/A`; no new missing-term claim or exact mapping follows from that.
Completion evidence: the learner can distinguish a plausible candidate from a
defensible mapping and can leave it unresolved.

### 3. Correct the request form's decomposition guidance

**Observed:** the template's “I-ADOPT decomposition” block lists
`property_iri`, `entity_iri`, `unit_iri`, `constraint_iri`, and `method_iri`,
omitting `statistical_modifier_iri`. This can be misread as the current SDP
dictionary schema or as a complete native I-ADOPT representation.

**Proposed replacement heading:** “Measurement context and decomposition
(optional; describe the role and source of each component).” List variable,
property, entity, unit, constraints and statistical modifier where applicable;
put method/procedure context and its source field in a separate prompt. Add:
“These are request-context prompts, not an SDP CSV schema or a claim of native
I-ADOPT conformance. In SDP v0.3 there is no column-dictionary `method_iri`
field; follow the current method-placement rules.”

Completion evidence: the template links the current SDP field reference,
preserves method context, and no example instructs a learner to create the
removed dictionary field.

### 4. Distinguish inference from validation

**Proposed addition:** “An OWL axiom states what follows logically from a
model. Failure to derive a statement is not generally proof that it is false
or missing: OWL works with an open-world assumption. A table schema or SHACL
shape checks a declared data contract. A parse or consistency check cannot
approve the scientific meaning or prove required data are complete.”

Use one deliberately incomplete source-record description to compare an
unentailed claim with a declared validation failure. Keep the check and its
scope explicit; do not imply that ordinary OWL domain/range axioms are CSV
requiredness rules. Completion evidence: the walkthrough explains separately
what the reasoner, data validator, and human review establish.

### 5. Separate logical strength from governance authority

**Observed:** CONVENTIONS §5 calls Tier 1 “automation-safe”, while §7 separately
requires approved mappings. A reader can mistake the predicate itself for
permission to apply it.

**Proposed clarification:** “Predicate strength describes the claim being
made, not its correctness or approval status. Stronger predicates require
stronger justification. Only mappings with the required review and explicit
application policy may drive a production transform.” Keep reviewer evidence,
logical rationale, and the intended use as separate fields.

Clarify SSSOM at the same point: it records concept-to-concept mapping claims
and provenance and may carry OWL predicates; a Turtle bridge may contain only
advisory mappings. Format does not settle logical force. Do not encode raw
literal assignments or variable-component decomposition as concept mappings
in the SDP SSSOM profile. Completion evidence: a candidate remains unapproved
even when its predicate is `owl:equivalentClass`, and a reviewed close mapping
is not silently upgraded to equivalence.

## Verification and follow-up

Use the existing bundle's PSC profile v0.4 over OKF v0.2:

```sh
uv run --project ../psc-data-systems psc-okf check knowledge --tier capture
```

This verifies the bundle's declared structure, not the proposed guidance or
domain meaning. Workshop build/link and pinned-API checks belong in the
workshop repository. Keep a prospective upstream issue/PR draft local until
Brett authorizes the specific posting. Any future SDO change should cite this
source evidence, undergo its own maintainer review, and update this card from
the actual outcome. No approval or deployment is inferred from this proposal.
