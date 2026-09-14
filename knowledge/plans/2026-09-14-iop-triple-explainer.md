---
type: Artifact
title: "Emitting I-ADOPT triples from a Salmon Data Package — explainer and recommendation"
description: "Explainer for backlog #78: who needs iop: triples from an SDP and what they cannot do today, the pattern for emitting them (where they live, what generates them, how they version), and whether triple emission should be a general SDP capability rather than an I-ADOPT-only one, with the costs of each. Written 2026-09-14 by an agent on Brett's Q46 allowance; it carries a recommendation, and the recommendation is a proposal awaiting his ruling on B-78. No code, by design."
status: draft
tags: [i-adopt, rdf, sdp, semantics, s9, b-78, b-146, proposal]
psc:
  id: metasalmon:plan:2026-09-14-iop-triple-explainer
  contexts: [metasalmon:context:hub-coordination]
---

# Emitting I-ADOPT triples from a Salmon Data Package

**Status: proposal, awaiting B-78.** Queue item **B-146** is the explainer;
**B-78** is the decision on what it recommends, and that decision is Brett's.
He allowed this card on 2026-09-14 under [Q46](../questions.md) —
*"For B78, let's allow the explainer now as its own quad science item"* — and
kept the answer for himself. So [section 6](#6-recommendation-awaiting-b-78)
is a **proposal and nothing more**: no implementation is scheduled, and the
2026-08-13 deferral stands to that extent. Written by an agent; the citations
below were resolved with tools during the pass and the resolution is recorded
in [section 9](#9-source-register), but **nothing here has been independently
checked** and the card asserts no verification of its own.

Owning stream: [S9 — ontology conventions and alignment pass](../sequences/s9-ontology-alignment.md),
step 6. Defect of record: [backlog #78](../backlog.md).

---

## 1. Correcting the premise before answering the question

Backlog #78 and the B-146 scope both state the problem as: metasalmon
*consumes* I-ADOPT terminologies but **never emits triples** stating that a
column's component IRIs form an I-ADOPT Variable, so an RDF consumer has to
infer the decomposition from column names.

The second half of that is exactly right. The first half is not, and the
difference changes the shape of the decision, so it is worth stating before
anything else.

**metasalmon already emits triples.** The EML export writes EML 2.2 semantic
annotations, and an EML 2.2 annotation *is* an RDF triple by the EML
specification's own account: its Semantic Annotation Primer defines an
annotation as a `propertyURI`/`valueURI` pair and says "An annotation element
always has a parent-EML element, which is the 'thing' being annotated, or the
subject", with appendix sections titled *Semantic triples* and *RDF Graphs*
and a glossary entry defining RDF as a subject-predicate-object model
([EML 2.2 ch. 7](https://eml.ecoinformatics.org/semantic-annotation-primer.html)).

`R/eml-export.R` emits **exactly two** such triples per measurement attribute,
from a frozen two-entry predicate table:

| predicate | object |
|---|---|
| `http://purl.org/dc/terms/subject` | the column's `term_iri` |
| `http://qudt.org/schema/qudt/hasUnit` | the column's `unit_iri` |

and its own documentation states the omission deliberately: *"The exporter
deliberately does not project incomplete I-ADOPT roles or procedure
annotations into EML."* The breadth of `dcterms:subject` is likewise
deliberate and reasoned in place — an OWL class is not necessarily an OBOE
`MeasurementType`, and schema-valid EML must not silently assert an
unsupported range.

So the real question is not *should an SDP emit triples*. It is: **there is an
existing triple surface, narrowed on purpose for a stated reason, and the
decomposition is the thing it was narrowed to exclude.** Any recommendation
has to answer that reason rather than step around it. The rest of this card
does.

### What the package does and does not hold today

Measured in the B-146 worktree against metasalmon 0.5.0, sdp-0.3.0:

- **The components are all present, as strings.** `metadata/column_dictionary.csv`
  carries `term_iri`, `property_iri`, `entity_iri`, `constraint_iri`
  (semicolon-separated, multi-valued), `statistical_modifier_iri` and
  `unit_iri`. The Frictionless schema describes them as I-ADOPT component
  columns and names `iop:StatisticalModifier` explicitly.
- **They are already inside `datapackage.json`.** `.ms_descriptor_field_keys()`
  in `R/metadata-write.R` mirrors seven dictionary columns into each
  `schema.fields[]` entry, as flat snake_case JSON keys. The reader also
  accepts a CURIE-shaped alternate spelling (`iAdopt:propertyIri` and
  siblings) which the writer does not emit. Q3 (2026-08-24) ruled these keys
  legal in the descriptor. There is **no `@context` anywhere in the package**,
  so `iAdopt:propertyIri` is a string that looks like a CURIE and denotes
  nothing.
- **A richer artifact exists and is manifest-bound.**
  `metadata/semantic/measurement-decompositions.csv` plus its `.json` manifest
  (`R/measurement-decompositions.R`) holds ordered, per-component rows with
  `component_role` in `property, entity, constraint, statistical_modifier,
  unit`, a `component_status` of `matched` or `gap`, per-row `source`,
  `source_version`, `source_url`, `rationale` and `provenance`. Its manifest
  declares `schema_version`, the artifact `sha256` and `row_count`, and a
  `provenance.semantic_profile` reading *"Ordered SDP semantic profile with
  I-ADOPT-informed roles; not native I-ADOPT conformance."*
- **No RDF is serialized.** 65 exported functions, none naming
  rdf/ttl/turtle/jsonld/graph/triple. The only RDF-shaped code is readers
  (`.parse_salmon_rdfxml()`, `.parse_smn_ttl_modules()`, `.smn_ttl_prefixes()`).
  RDF goes in; apart from the two EML annotations, none comes out.

The gap is therefore precise, and smaller than "no triples": **the package
states the components and never states the relation between them.** It says
this column has these five IRIs. It never says *these five IRIs are one
I-ADOPT Variable, and this one is its ObjectOfInterest*. `smn-data-pkg`'s own
integration guide already says why that matters — "A column label alone is not
machine-readable decomposition."

---

## 2. What I-ADOPT actually requires: the axioms, not the prose

This matters because the recommendation turns on a cardinality constraint most
summaries of I-ADOPT omit. Resolved from the served ontology during this pass
(source register row `iadopt-ont-1.1.0`).

**Term IRIs are slash-form.** The vocabulary is `https://w3id.org/iadopt/ont`
at `owl:versionIRI` `https://w3id.org/iadopt/ont/1.1.0`, and its terms are
`https://w3id.org/iadopt/ont/Variable`,
`https://w3id.org/iadopt/ont/hasProperty`, and so on. The turtle declares
`@prefix : <https://w3id.org/iadopt/ont#>` and then uses that hash namespace
for **no term at all**. An implementer who expands `iop:` to the hash form
produces IRIs that resolve to nothing and join no graph, and nothing about the
resulting file looks wrong. This is the kind of choice `AGENTS.md` requires a
pull request to justify out loud rather than let a passing validator settle.

**`iop:Variable` is defined by exact cardinality, and defined as an
equivalence.** The class axiom is an `owl:equivalentClass` of two
restrictions:

- exactly 1 `hasObjectOfInterest`, `owl:onClass` `Entity`
- exactly 1 `hasProperty`, `owl:onClass` `Property`

with the comment *"A description of something observed or derived, minimally
consisting of an ObjectOfInterest and its Property."*

Two consequences, and both cut against a naive emitter.

1. **`equivalentClass`, not `subClassOf`, means the definition is an inference
   rule.** Anything carrying exactly one `hasObjectOfInterest` and exactly one
   `hasProperty` *is* an `iop:Variable` under OWL semantics, with no explicit
   typing needed. An explicit `rdf:type iop:Variable` triple is therefore
   redundant to a reasoner and necessary for every consumer that does no
   reasoning — which is nearly all of them. Emit it anyway; just know which
   audience it is for.
2. **Exactly-1 makes a plural emission a false assertion rather than an
   error.** Emit two `hasObjectOfInterest` triples for one variable and an
   OWL-DL reasoner does not reject the graph; it concludes the two entity
   individuals are *the same individual*. The graph parses, validates as
   well-formed RDF, and asserts something untrue about two ontology terms.
   This is the single sharpest cost in the whole question, and
   [section 5](#5-what-it-would-cost) shows the SDP can already produce the
   input that triggers it.

**The optional roles are genuinely optional, and richer than SDP's columns.**
`hasConstraint`, `hasContextObject`, `hasMatrix` and
`hasStatisticalModifier` all carry `rdfs:domain Variable` and **no**
cardinality restriction, so multi-valued constraints are fine.
`hasMatrix rdfs:subPropertyOf hasContextObject`. `hasStatisticalModifier` is
commented "might have" — optional, as the SDP treats it.

**Two things I-ADOPT can express that the SDP cannot.** Stated as findings,
not as work:

- **`hasObjectOfInterest` versus `hasContextObject`/`hasMatrix`.** I-ADOPT
  distinguishes the entity whose property is observed from an entity giving
  background context, and from the matrix containing it. The SDP has one
  `entity_iri` column, documented as "what the measurement is about", and the
  decomposition artifact's `component_role` set has one `entity` role. The
  distinction is unrepresentable, so an emitter must either map every
  `entity_iri` to `hasObjectOfInterest` (correct for the documented meaning,
  lossy for anything else a curator put there) or refuse to guess.
- **`constrains`.** I-ADOPT's `constrains` has domain `Constraint` and range
  `unionOf(Entity, Property, StatisticalModifier)` — it says *which component*
  a constraint confines. The SDP's `constraint_iri` is a flat semicolon bag
  with no target. The decomposition artifact does have `component_relation`
  and `related_component_order`, but its only permitted value is
  `value_of_dimension`, which connects two `constraint` components and is not
  `constrains`. So a constraint can be emitted as attached to the variable
  (`hasConstraint`) but never as confining a named component.

Neither of these is an ontology-term gap — no term needs minting in `smn`,
`gcdfo` or the PSC CV. They are **SDP expressivity gaps against I-ADOPT 1.1**,
and they belong in the queue rather than in this card's recommendation; see
[section 8](#8-what-this-card-does-not-decide).

---

## 3. (a) When `iop:` triples are useful, and to whom

A card that says "triples help interoperability" has answered nothing. So:
three named consumers, what each can do today, and what it cannot.

### Consumer 1 — KNB / DataONE search, the one that already exists

This is the only consumer metasalmon actually publishes to today
(`R/knb-publication.R`), and the only one whose behaviour is not hypothetical.

*Today:* each measurement column reaches DataONE as two annotations,
`dcterms:subject → term_iri` and `qudt:hasUnit → unit_iri`. A search for
datasets about a concept can match the compound term; a search can filter by
unit.

*Cannot:* find a dataset by any component of the variable that the compound
term does not itself expose. Ask *"which packages measure anything at all
whose property is a count, about an entity that is a salmon population?"* and
there is nothing to match on. The `property_iri` and `entity_iri` exist in the
package, travel to the repository inside `datapackage.json`, and are invisible
to the index because nothing states them as properties of the variable. This
is the concrete, present-tense loss, and it is the strongest argument in
favour of emission — the consumer exists, the data is already shipped, and
only the assertion is missing.

*Honest limit on this claim:* whether DataONE's production index would
actually query the extra predicates is a property of that deployment, not of
EML, and **I did not check it**. The safe form of the claim is that the
annotations are the interface DataONE takes semantic queries through, so
emitting them is a precondition for such a query rather than a guarantee of
one.

### Consumer 2 — cross-terminology variable matching

*Today:* two packages describing the same observable with different compound
terms — one from BODC, one from `smn` — look unrelated. Matching them means
matching labels or column names.

*Cannot:* match on shared components. Two variables that agree on
`hasProperty` and `hasObjectOfInterest` and differ only in constraint are
recognisably near-duplicates in a graph and are nothing in two CSVs. This is
the use case I-ADOPT was built for, and the one the vendored terminology
registry (`inst/extdata/iadopt-terminologies.csv`, 4 role-partitioned columns
over the I-ADOPT registry) already prepares the ground for: metasalmon picks
component terms from the same registries other I-ADOPT adopters pick from, and
then keeps the result to itself.

*Honest limit:* this consumer is **prospective**. I found no evidence of a
deployed system doing this matching over salmon data, and the card should not
imply one. Its weight is that the alignment work is already paid for.

### Consumer 3 — the ecosystem's own downstream tools

The gap-detection pipeline (`detect_semantic_term_gaps()` →
`render_ontology_term_request()` → `submit_term_request_issues()`), the
commons' gap register, and any future Foundry consumer all reason about
variables and their parts. Today each re-derives the decomposition from the
dictionary's column layout — that is, each hard-codes the knowledge that
`property_iri` means `hasProperty`. That knowledge lives in R and Python
source in two repositories and in no artifact.

*This is the argument that does not depend on RDF at all.* Emitting the
relation writes down, once and in a checkable place, something currently
duplicated across two implementations of a mirror contract. Even a consumer
that never loads a triple store benefits from the mapping existing as data.

### Who it is not for

Worth saying, because it bounds the recommendation. It is **not** for the
salmon biologist reading a data dictionary, who is served by
`column_dictionary.csv` and is not helped by a graph. It is **not** for
validation — the deterministic validators already check the components. And it
is **not** for an SDP consumer that only wants to read the table; the triples
are metadata about columns, not about rows.

---

## 4. (b) The pattern for emitting them

Three sub-questions. The third is the one that gets skipped.

### Where the triples live

Four candidates, and the repository has already ruled out two of them by
precedent.

| Option | Verdict |
|---|---|
| **New columns in `column_dictionary.csv`** | **No.** `smn-data-pkg`'s SPECIFICATION.md is explicit: "Project-specific metadata extensions belong in sidecar files or non-SDP descriptor fields. Strict publication validation rejects extra columns in canonical SDP metadata CSVs." A relation is not a column value anyway. |
| **A `@context` bolted onto `datapackage.json`** | **No, and this is the tempting one.** The descriptor already carries the components, and the reader already accepts CURIE-shaped keys, so it looks one `@context` away from being JSON-LD. Two reasons not to. The Data Package standard has no RDF affordance to hang it on — on the retrieved v2 standard page the strings `@context`, `json-ld`, `jsonld`, `rdf` and `linked data` occur **zero times**, and the descriptor properties are `$schema`, `resources`, `name`, `id`, `licenses`, `title`, and so on. And the writer emits snake_case keys, not the CURIE spelling, so a context would have to map invented terms; that is an SDP-local vocabulary invention dressed as an interoperability win. |
| **A sidecar graph under `metadata/semantic/`, bound by its own manifest** | **Yes.** This is the pattern the package has converged on twice already, for SSSOM mapping sets (`metadata/semantic/mapping-sets.json` + `*.sssom.tsv`) and for measurement decompositions (`measurement-decompositions.csv` + `.json`). Both are manifest-closed, and `R/knb-publication.R` publishes **only the files the manifest names** rather than scanning the directory — a deliberate guard against shipping an editor backup or an unapproved draft. A third artifact inherits that guard for free. |
| **Extra EML annotations on the existing attributes** | **Yes, and orthogonally.** This is the only option that reaches Consumer 1, because DataONE ingests EML and not the sidecar. It is not an alternative to the sidecar; it is the other half. |

So the recommendation's shape is **two surfaces, one generator**: a
self-contained sidecar graph for anyone who wants the decomposition as RDF,
and additional EML annotations for the repository that is already indexing
these packages. Emitting to one and not the other leaves a real consumer out.

For the sidecar serialization, Turtle for a human-readable review artifact or
N-Triples for a canonical hashable one. N-Triples deserves a look precisely
because of the **C collation** contract: a line-per-triple format sorted with
`method = "radix"` gives byte-stable output trivially, where Turtle's prefix
and blank-node layout does not. Whichever is chosen, the ordering is hashed
and written to file bytes, so it is collation-sensitive and the generator
belongs in `collation_sensitive_fns` in `tests/testthat/test-collation-guard.R`.
The same contract's sibling applies too: every IRI reaching the serializer is
rendered to text exactly once, through `.ms_canonical_character()`, and the
thing sorted is the thing written.

### What generates them

`measurement-decompositions.csv` is the better input than the dictionary, and
this is a real choice rather than a detail. It carries per-component `source`,
`source_version` and `source_url`, it distinguishes `matched` from `gap`, and
it is ordered. The dictionary's `constraint_iri` is a semicolon-delimited
string that a generator would have to re-split.

But the decomposition artifact is **optional**, so the generator needs a
defined behaviour when it is absent, and the honest one is to fall back to the
dictionary and emit the narrower graph the dictionary supports. A
`write_sdp_iadopt_graph()` alongside `write_sdp_sssom()` and
`write_sdp_measurement_decompositions()` is the shape the package's existing
surface implies.

Three rules the generator needs, each of which exists because of something
found above:

1. **Emit nothing for a column that cannot satisfy the class axiom.** No
   `property_iri`, or no `entity_iri`, or more than one of either: skip the
   column and say so. Partial emission here is not a partial graph, it is a
   false one.
2. **Never emit a `gap` row.** A `component_status: gap` row has a blank
   `component_iri` by validator construction, carrying only a label and a
   rationale. There is no IRI to point at, and minting a placeholder subject
   would turn an honestly recorded vocabulary gap into an assertion. The
   `REVIEW:` prefix convention is the precedent: a provisional IRI is a thing
   strict validation *refuses to ship*, not a thing to serialize.
3. **Emit `rdf:type iop:Variable` explicitly**, redundant though it is under
   the equivalence axiom, for the consumers that do not reason.

The variable subject needs an IRI, and the SDP has no natural one for "the
variable this column measures" — `term_iri` is the *concept*, not this
package's use of it. A deterministic, package-scoped IRI minted from the
dataset, table and column identifiers is the obvious answer and it is also a
**PID-shaped decision**: it is an identifier, so its construction is
collation-sensitive and it is the sort of choice that wants naming in a pull
request rather than settling by whatever made the validator pass.

### How they version — the half that gets skipped

Three version axes are already in play, and a fourth arrives with the graph.
Conflating any two is the failure.

| Axis | Where it lives today |
|---|---|
| The SDP spec version | `dataset.csv` `spec_version`, defaulting to `.ms_sdp_profile_version()` |
| The sidecar artifact's own schema | `schema_version` in each manifest (`"1.0"` for both existing artifacts) |
| The external standard's version | `sssom_version: "1.1"` and `provenance.specification: "https://mapping-commons.github.io/sssom/1.1/"` in the SSSOM manifest |
| **The ontology version the triples are written against** | nowhere yet |

The SSSOM manifest is the precedent worth copying wholesale, because it
already solves this: it pins the external specification **by version, as a
URL, in the manifest**, and records `subject_source_version` /
`object_source_version` per mapping set. The iop graph's manifest should do
the same with I-ADOPT's `owl:versionIRI`:

- `schema_version` — the manifest's own contract
- `iadopt_version_iri: "https://w3id.org/iadopt/ont/1.1.0"` — **the version
  IRI, not the bare ontology IRI**. This is the whole versioning answer in one
  field. I-ADOPT moved from 1.0 to 1.1 by adding the aggregation extension; a
  graph that says only "I-ADOPT" cannot tell a consumer whether
  `hasStatisticalModifier` was in scope when it was written.
- `artifact.path`, `artifact.sha256`, `artifact.triple_count` — exactly the
  existing decomposition manifest's shape
- `provenance.generated_by`, `provenance.metasalmon_version`
- per-component `source` / `source_version`, carried through from the
  decomposition rows, so a consumer can tell which vocabulary release an
  entity IRI was drawn from

And the rule that makes the versioning real rather than decorative: **the
graph is derived, so it is never edited in place.** It is regenerated, and its
`sha256` is what proves it still matches its inputs — the same relationship
`validate_sdp_measurement_decompositions()` already enforces for the
decomposition CSV. A hand-edited graph whose hash still matched would be the
one failure mode nothing could see.

---

## 5. What it would cost

### (c) General capability, or I-ADOPT only?

The question is whether an SDP should grow a general "emit triples" capability
with I-ADOPT as its first client, or one narrow I-ADOPT projector.

**The precedent in the ecosystem points one way, and it is worth reading
before deciding.** `smn-data-pkg` has faced this exact temptation once and
declined it. On observation structures the specification says the role names
"align conceptually with W3C RDF Data Cube component roles, but these CSV
files are not an RDF Data Cube Data Structure Definition and do not by
themselves assert Data Cube conformance", and then says an *exporter* can
project them into a Data Cube structure. That is precisely the general
capability under discussion, already scoped and already deferred to an
exporter. The decomposition manifest says the same thing in its own
`semantic_profile` field: *I-ADOPT-informed roles, not native I-ADOPT
conformance.* Twice now the format has recorded "this is projectable" instead
of projecting it.

A general emission framework would therefore have at least two clients on day
one — I-ADOPT variable decomposition and the Data Cube projection — plus the
SOSA procedure bindings the methods model already expresses with
`sosa:usedProcedure`. That is a genuine argument that the general shape is the
honest one.

**It is also the more expensive commitment, and the costs are asymmetric.**

*Implementation.* The I-ADOPT projector is bounded: read one artifact, apply a
fixed role-to-predicate map, serialize, hash, manifest. A general framework
needs a predicate-mapping registry, a per-vocabulary namespace and version
registry, a subject-minting scheme shared across projections, and a validation
story for graphs it does not itself define. The marginal cost of the second
client is where the real work is, and a framework built for one client is a
framework whose seams are in the wrong place.

*Maintenance.* This is the cost the package has the most evidence about. A
role-to-predicate map is a **new surface on which a semantic role is a
contract**, and AGENTS.md's seven-surface list is the record of what happens
when such a surface is added and forgotten: `statistical_modifier` shipped
through CI and pull-request review with its hint emitter missing, having 100%
of its correct accepts silently downgraded, and then failed a *second* silent
layer when `role_boost` was found missing a year of releases later. The
contract's own conclusion is to "assume an eighth exists and look for it".
**A predicate map is a strong candidate for being that eighth surface**, and
if it is added, `tests/testthat/test-role-contract-guard.R` gains a
`SURFACE 8` section with a recorded RED demonstration, or the guard's claimed
scope once again exceeds its real scope — which that file's history says is
worse than having no guard.

*What it commits the format to.* The sharpest cost, and it is not
implementation effort. **A published graph is an assertion, and it outlives
the package that made it.** Three specifics:

1. **Emitted triples get copied out of the package.** A consumer loads the
   graph into a store, and the assertion continues to exist after the SDP is
   corrected. The dictionary's own review discipline assumes the opposite —
   that a `REVIEW:` IRI can be fixed before publication and a wrong term
   revised in place. Emission is the point where that assumption stops
   holding.
2. **The exactly-1 axiom makes a plural component a silent falsehood, and the
   SDP can already produce one.** `.ms_sdp_decomposition_validate_order_and_uniqueness()`
   rejects only *exact* duplicate components; two **distinct** `entity` rows
   for one measurement are valid input today. Project those naively and the
   graph asserts that two different ontology entities are the same individual.
   Nothing errors; the file is well-formed. Any emission decision has to come
   with the rule that refuses this case — which is why it is rule 1 in
   [section 4](#what-generates-them) rather than a footnote.
3. **The predicate choices become a compatibility surface.** Once a consumer
   depends on `hasObjectOfInterest` meaning `entity_iri`, changing that mapping
   is a breaking change to a published graph, not a refactor. Naming a
   predicate is exactly the "semantic choice made inside a code change" that
   AGENTS.md says code review structurally cannot catch: the diff is correct,
   the tests go green, and the choice is justified by nothing except that
   validation passed.

---

## 6. Recommendation, awaiting B-78

**A proposal. Brett rules; nothing below is operative.**

**Recommend: yes to emission, scoped to I-ADOPT, built so a second projection
is cheap but not built for one.** Concretely, and in this order:

1. **Do not build a general triple-emission framework now.** Two clients
   exist in principle and neither has a consumer asking for it. The
   specification's twice-recorded position — projectable, not projected — is
   the right one to keep for Data Cube.
2. **Do build the I-ADOPT projector**, as a sidecar graph under
   `metadata/semantic/` closed by its own manifest, generated from
   `measurement-decompositions.csv` with a dictionary fallback, pinning
   `https://w3id.org/iadopt/ont/1.1.0` by version IRI, hashed, and published
   only through its manifest.
3. **Extend the EML annotations in the same decision**, because Consumer 1 is
   the only consumer that exists and the sidecar does not reach it. This is
   the part that requires answering the existing exporter's stated reason for
   declining, and the answer is available: the reason given is *incomplete*
   I-ADOPT roles, and rule 1 of the generator is exactly a completeness gate.
   A column that satisfies the class axiom is not incomplete. The exporter's
   caution about `dcterms:subject` and unsupported ranges was about asserting a
   range the term does not support; `iop:hasProperty` has
   `rdfs:range iop:Property` and asserting it for a reviewed property IRI is
   the supported case. **This is my reading of the exporter's intent, not a
   ruling recorded anywhere**, and it is the point in this card I would most
   want contradicted.
4. **Take the three costs as requirements, not caveats.** The
   plural-component refusal, the `gap`-row exclusion, and a `SURFACE 8`
   section in the role-contract guard if a predicate map is introduced.
5. **Put the predicate map and the subject-IRI scheme in the pull request
   text**, with justification other than "validation passed".

**What would change my recommendation.** If Brett's answer to Consumer 1 is
that DataONE will not query the extra predicates, then the only consumer that
exists today is unaffected, the remaining arguments are prospective, and the
right recommendation becomes *wait*. I could not check that, and I have marked
it unchecked rather than assumed it favourably. It is the load-bearing
uncertainty in the card.

---

## 7. The mirror obligation, stated because it is part of the cost

Whatever is ruled here is presumed to require the same change in
metasalmonpy, in the same stream or with a logged reason. That is not a
footnote to the cost estimate — it doubles the implementation and maintenance
figures in [section 5](#5-what-it-would-cost), and a graph emitted by one
implementation and not the other is worse than neither, because the two
packages would ship the same `spec_version` while asserting different amounts
about the same data. If the ruling is to build, the parity half is its own
queue item and any deliberate difference needs a
[`parity-deviations.md`](../parity-deviations.md) row in the pull request that
introduces it.

A related note on sequencing rather than parity: metasalmonpy is at 0.4.0
against metasalmon's 0.5.0 and already owes a port. Opening a new divergence
on top of an unclosed catch-up window is a scheduling fact worth weighing,
not a reason against the design.

---

## 8. What this card does not decide

- **Whether to emit.** That is B-78 and it is Brett's.
- **The two SDP expressivity gaps** found in
  [section 2](#2-what-i-adopt-actually-requires-the-axioms-not-the-prose):
  no `hasContextObject`/`hasMatrix` distinction, and no `constrains` target.
  Both are `smn-data-pkg` shape questions affecting both mirrors. Neither is
  an ontology-term gap and neither needs a term minted; they are candidate
  queue items and are deliberately left as findings here.
- **Whether `component_relation` should grow beyond `value_of_dimension`.**
  Adjacent to the `constrains` gap, same reason.
- **Any implementation.** No code, by design — an implementation would
  pre-empt the ruling.

There is **no `NEWS.md` entry** for this card, deliberately: `knowledge/` is
excluded from `R CMD build` and nothing observable changes.

---

## 9. Source register

Every identifier below was resolved with a tool during the 2026-09-14 pass.
**Tool-resolved, not human-verified.** A fuller ledger, including the
negatives, was produced alongside this card; the negatives worth carrying here
are in the notes column.

| id | source | resolved | passage located |
|---|---|---|---|
| `iadopt-ont-1.1.0` | I-ADOPT Framework ontology 1.1.0, RDA I-ADOPT WG — [`https://w3id.org/iadopt/ont`](https://w3id.org/iadopt/ont) | Turtle fetched from `https://i-adopt.github.io/ontology/ontology.ttl` (200, `text/turtle`, 21645 bytes); HTML at `https://i-adopt.github.io/ontology/` (200) declares version 1.1.0, released 2025-05-28 | Yes — `owl:Ontology` header (`owl:versionIRI https://w3id.org/iadopt/ont/1.1.0`); the `Variable` `owl:equivalentClass` axiom with both exactly-1 qualified cardinality restrictions; the `hasProperty`, `hasObjectOfInterest`, `hasConstraint`, `hasContextObject`, `hasMatrix`, `hasStatisticalModifier` and `constrains` axioms with their domains, ranges and absence of cardinality |
| `rda-iadopt-outputs-2022` | Magagna B., Moncoiffe G., Devaraju A., Stoica M., Schindler S., Pamment A. *InteroperAble Descriptions of Observable Property Terminologies (I-ADOPT) WG Outputs and Recommendations*. Research Data Alliance, 2022. [doi:10.15497/RDA00071](https://doi.org/10.15497/RDA00071) | DataCite API; title, authors, year, publisher and version confirmed from the record | **No — metadata only.** Full text not read, so no claim in this card rests on its contents. Cited as the WG recommendation the ontology page itself references |
| `iadopt-terminologies-registry` | I-ADOPT Terminology Repository — [`https://i-adopt.github.io/terminologies/`](https://i-adopt.github.io/terminologies/) | HTTP 200, 22304 bytes, title "I-Adopt Terminology Repository" | Yes — the per-role registry metasalmon vendors as `inst/extdata/iadopt-terminologies.csv` |
| `eml-2.2-annotation-primer` | *EML 2.2, ch. 7: Semantic Annotation Primer*, KNB/NCEAS — [`https://eml.ecoinformatics.org/semantic-annotation-primer.html`](https://eml.ecoinformatics.org/semantic-annotation-primer.html) | HTTP 200 | Yes — the `propertyURI`/`valueURI` structure; "An annotation element always has a parent-EML element, which is the 'thing' being annotated, or the subject"; appendix 7.6.1 *Semantic triples* and 7.6.3 *RDF Graphs*; glossary definition of RDF as subject-predicate-object |
| `w3c-data-cube-2014` | Cyganiak R., Reynolds D. (eds). *The RDF Data Cube Vocabulary*. W3C Recommendation, 16 January 2014 — [`https://www.w3.org/TR/vocab-data-cube/`](https://www.w3.org/TR/vocab-data-cube/) | HTTP 200, 174074 bytes | Yes — masthead date and `REC-vocab-data-cube-20140116`; vocabulary index listing `qb:DataStructureDefinition`, `qb:Observation`, `qb:DimensionProperty`, `qb:MeasureProperty`, `qb:AttributeProperty` |
| `w3c-ogc-ssn-2017` | Haller A., Janowicz K., Cox S. et al. (eds). *Semantic Sensor Network Ontology*. W3C Recommendation, 19 October 2017; OGC 16-079 — [`https://www.w3.org/TR/vocab-ssn/`](https://www.w3.org/TR/vocab-ssn/) | HTTP 200, 673275 bytes | Yes — masthead: W3C Recommendation 19 October 2017 (link errors corrected 08 December 2017), joint W3C/OGC, OGC Document Number OGC 16-079 |
| `frictionless-data-package-v2` | Pollock R., Walsh P., Kariv A., Karev E., Desmet P., Data Package Working Group. *Data Package Standard*, v2 — [`https://datapackage.org/standard/data-package/`](https://datapackage.org/standard/data-package/) | HTTP 200, 83822 bytes | Yes — Descriptor Properties section. **Negative recorded:** case-insensitive counts on the retrieved page are `@context` 0, `json-ld` 0, `jsonld` 0, `rdf` 0, `linked data` 0. Absence on one page is weaker than a normative statement, so the claim in [section 4](#where-the-triples-live) is scoped to what was retrieved |

**Negatives worth carrying.** No peer-reviewed I-ADOPT framework *journal*
article was found in CrossRef across four query formulations — only EGU
conference abstracts ([10.5194/egusphere-egu21-13155](https://doi.org/10.5194/egusphere-egu21-13155),
[10.5194/egusphere-egu2020-19895](https://doi.org/10.5194/egusphere-egu2020-19895)).
A DOI recalled from memory as that paper resolved to an entirely unrelated
article and **is cited nowhere**; the card cites the ontology and the RDA
output instead. The guessable turtle paths
(`.../ontology/iadopt.ttl`, `https://w3id.org/iadopt/ont.ttl`) both 404 — the
served copy is at `.../ontology/ontology.ttl`, recorded because a card that
tells an implementer to fetch the vocabulary must name the path that works.

**In-repo claims** — every statement in
[section 1](#1-correcting-the-premise-before-answering-the-question),
[section 4](#4-b-the-pattern-for-emitting-them) and
[section 5](#5-what-it-would-cost) about what metasalmon, `smn-data-pkg` or
the SDP schemas do was read from source in the B-146 worktree at metasalmon
0.5.0 / sdp-0.3.0 and is cited to the file and symbol rather than to a
document. Rulings are cited to [`questions.md`](../questions.md) by number.
