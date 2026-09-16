---
type: Artifact
title: "Emitting I-ADOPT triples from a Salmon Data Package — explainer and recommendation"
description: "Explainer for backlog #78: who needs iop: triples from an SDP and what they cannot do today, the pattern for emitting them (where they live, what generates them, how they version), and whether triple emission should be a general SDP capability rather than an I-ADOPT-only one, with the costs of each. Written 2026-09-14 by an agent on Brett's Q46 allowance and revised twice on what emission would actually buy: DataONE's indexer flattens predicate and object into one unpaired field, so the pairing is unrecoverable, and KNB's search interface cannot reach an arbitrary IRI at all — but emission does put the component IRIs where an API client can retrieve the datasets that use them, which is real dataset discovery and which the 2026-09-15 revision wrongly denied. The 2026-09-16 pass also withdrew the claim that an artifact hash proves a derived graph still matches its inputs, so the proposed manifest binds the graph to its derivation inputs by digest. The recommendation is unchanged throughout, and its strength is weaker than the 2026-09-14 claim and stronger than the 2026-09-15 correction left it. A recommendation and not a ruling; nothing in it is operative, and no code, by design."
status: draft
tags: [i-adopt, rdf, sdp, semantics, s9, b-78, b-146, proposal]
psc:
  id: metasalmon:plan:2026-09-14-iop-triple-explainer
  contexts: [metasalmon:context:hub-coordination]
---

# Emitting I-ADOPT triples from a Salmon Data Package

**This card explains and recommends; it does not decide.** Brett allowed it on
2026-09-14 under [Q46](../questions.md) — *"For B78, let's allow the explainer
now as its own quad science item"* — and kept the decision on what it
recommends for himself. So [section 6](#6-recommendation) is a recommendation
addressed to him, carries no authority of its own, and schedules nothing. The
lifecycle state of the explainer and of the decision lives in `queue/items/`
and nowhere else; this card deliberately does not restate it, because a card
that restates queue state is a defect and the card is the copy that is wrong.
Written by an agent; the citations below were resolved with tools during the
pass and the resolution is recorded in [section 9](#9-source-register), but
**nothing here has been independently checked** and the card asserts no
verification of its own.

**Revised twice, and both revisions were substantive.** The 2026-09-14 draft
named one load-bearing uncertainty — whether DataONE's index would query the
extra predicates — and marked it unchecked. On **2026-09-15** it was settled,
and it **refuted the card's strongest argument while leaving its conclusion
standing**; the discoverability claim was deleted as false and three narrower
justifications replaced it. On **2026-09-16**, after review, that correction
was found to have **overshot**: it concluded that emission improves
discoverability "by nothing at all", which is also false, because indexing a
component IRI lets an API client find the datasets that use it and today no
such IRI reaches the index. [Section 3](#consumer-1-knb-and-dataone-the-one-that-already-exists)
and [section 6](#6-recommendation) now separate three things the two earlier
revisions each collapsed into one, and §6 says plainly where the
recommendation's strength ended up: **weaker than 2026-09-14, stronger than
2026-09-15 left it.** Both corrections are kept in place rather than tidied
away, because "the argument was wrong twice, in opposite directions, and the
answer did not move" is the useful thing to know — and because a card that
silently absorbs its own corrections teaches the next reader nothing about how
much to trust its strongest sentence.

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

### Consumer 1: KNB and DataONE, the one that already exists

This is the only consumer metasalmon actually publishes to today
(`R/knb-publication.R`), and the only one whose behaviour is not hypothetical.

**This section's discoverability argument has been wrong twice, in opposite
directions, and the second error is the more instructive.** The 2026-09-14
draft said the strongest case for emission was that a DataONE user could find
datasets by a component of the variable, and flagged as its load-bearing
uncertainty that the index had not been checked. The index was then read, and
the 2026-09-15 revision swung to the other extreme: it concluded that emission
improves discoverability *"by nothing at all"* and added that "any version of
this card that says otherwise is wrong". That sentence was itself wrong, and
the shape of the mistake is worth naming — **a correction written so that no
later correction can be right is not a finding, it is a door being closed.**
It was reopened on **2026-09-16** by a review of PR #116.

Three things have to be held apart, and each earlier revision collapsed them
into one:

1. the **pairing** of predicate to object, which the index destroys;
2. **term-level retrieval of the component IRIs**, which emission newly
   enables and which is genuine dataset discovery for an API client;
3. the **search interface a human actually uses**, which cannot reach these
   IRIs at all.

(1) and (3) are what refute the 2026-09-14 claim, and they hold. (2) does not
refute it, and the 2026-09-15 revision denied (2) while its own evidence said
otherwise — it even listed the affordance among the justifications below two
paragraphs after declaring it worth nothing. The contradiction was on the page
before any reviewer arrived, which is the argument for checking a correction
against the rest of its own section rather than against the claim it replaced.

**What the index actually does.** DataONE's indexer registers
`EmlAnnotationSubprocessor` for exactly one format,
`https://eml.ecoinformatics.org/eml-2.2.0`, and imports it into the standard
build (one of 35 `<import>` lines in `index-context-file-includes.xml`, not a
prototype branch). Its entire field configuration is a single bean:

```xml
<constructor-arg name="name"  value="sem_annotation" />
<constructor-arg name="xpath" value="//annotation/propertyURI/text() | //annotation/valueURI/text()" />
<constructor-arg name="multivalue" value="true" />
```

That XPath is a **union**. Predicate and object are *both* indexed — into the
**same flat multivalued string field**, with no pairing between them and no
record of the subject. **To that index, an I-ADOPT decomposition is exactly a
flat bag of terms.** Non-whitelisted IRIs are indexed rather than dropped, so
the bag would contain the I-ADOPT IRIs as written.

**(1) The pairing is unrecoverable, and it is fatal to the 2026-09-14 claim.**
You can ask *does this dataset mention `hasObjectOfInterest` anywhere*. You can
never ask *what is the object of interest of this variable*, and you cannot
even ask *which datasets have X as their object of interest*: a dataset matches
on `X` whether `X` was its object of interest, its property, its constraint or
its unit, and matches on `hasObjectOfInterest` whatever that predicate's object
was. Every argument for emission that depends on querying the *structure* is
dead, and no amount of emission revives it.

**(2) Term-level retrieval of the components is new, and it is dataset
discovery.** This is the part the 2026-09-15 revision got wrong. Today
`sem_annotation` receives exactly two IRIs per measurement attribute — the
compound `term_iri` and the `unit_iri`, because those are the only two
annotations `R/eml-export.R` writes ([section 1](#1-correcting-the-premise-before-answering-the-question)).
`property_iri`, `entity_iri`, `constraint_iri` and `statistical_modifier_iri`
live in `column_dictionary.csv` and in `datapackage.json`, and DataONE indexes
neither of those files. So `sem_annotation:"<some property IRI>"` returns
**nothing at all today** and would return **the datasets that use that
property** after emission. A client that knows a component IRI but not which
datasets use it learns which datasets use it. That is discovery of datasets,
and dismissing it as "a question only someone who could already answer it
would ask" confuses knowing the IRI with knowing the datasets: the IRI is the
query, not the answer.

Two qualifications keep this honest, and neither cancels it. The match is at
**dataset granularity and is role-blind** — it says *some annotation somewhere
in this dataset carries this IRI*, not which column or which role, so a term
that is legitimately an entity in one column and a constraint in another is
indistinguishable. DataONE's search is dataset-granular by design, so this is
its native answer rather than a degraded one, but it is a coarser affordance
than a graph query and should never be described as one. And it rests on the
**inference** recorded below rather than on a measurement: nothing has been
deposited and queried.

**(3) The interface a human uses cannot reach these IRIs at all.** MetacatUI's
`AnnotationFilterView.js` is a BioPortal tree picker with
`defaultOntology: "ECSO"` (line 74), and KNB's deployed configuration does not
override it; DataONE's own documentation says annotation search "only supports
searching for ECSO MeasurementType annotations at this time". So a person
browsing KNB gains nothing from emission whatever the index holds. **This is
the half of the 2026-09-15 finding that was right and stays right**, and it is
why "improves discoverability" is meaningless in this card without an audience
attached: for a human at the search box, nothing; for a client with the Solr
API and an IRI in hand, a query that works where none exists today.

*So, precisely:* emission buys **no** paired or structural query, **no**
human-facing discoverability at KNB, and **one real term-level dataset-discovery
affordance for an API client**. The 2026-09-14 claim was too strong and the
2026-09-15 correction overshot; this is the interval between them.

**What survives, and it is more than the 2026-09-15 revision allowed.** Three
justifications, only the third of which depends on the index at all:

1. **The landing page renders the full triple.** MetacatUI's `AnnotationView.js`
   and `EMLAnnotation.js` read `propertyURI`/`propertyLabel` and
   `valueURI`/`valueLabel` **from the EML document itself, not from Solr**. So
   a human reading the KNB dataset page sees the decomposition intact, with
   the predicate attached to its object, even though the index has flattened
   it. This is a real present-tense gain for the consumer that exists, and
   together with justification 3 it is what replaces the deleted argument.
2. **Direct consumers get the real structure.** Anyone reading the EML, or the
   manifest-bound sidecar of [section 4](#where-the-triples-live), gets
   subject, predicate and object as written. **The sidecar's value never
   depended on the index at all** — which is why the finding costs the
   recommendation less than it might have.
3. **The component IRIs become retrievable, and a client can find datasets by
   them** — finding (2) above. Coarse and unpaired, but it is dataset discovery
   that is impossible today rather than an inconvenient version of something
   already possible, and it is the seam through which a future federated query
   would reach these packages. *This is the justification the 2026-09-15
   revision listed here while denying, two paragraphs earlier, that it counted
   for anything.*

*Limits, stated rather than left silent.* **No I-ADOPT annotation has actually
been deposited and indexed** — that needs a write to a Metacat test node,
which this pass did not do. "I-ADOPT IRIs would be indexed literally" is
therefore an **inference**, resting on the fact that the XPath filters nothing
and on the observed indexing of other non-whitelisted IRIs. It is a strong
inference and it is not a measurement. **Justification 3 rests entirely on it**
— justifications 1 and 2 do not, and that asymmetry is worth carrying, because
it says which part of the case a failed deposit test would remove. What would
settle it: deposit an I-ADOPT-annotated EML 2.2.0 record to a test node and
query `sem_annotation:"https://w3id.org/iadopt/ont/hasObjectOfInterest"`
against it, then query one of its component IRIs and check that the dataset
comes back.

**Do not cite the indexer's readthedocs page for any of this.** Its
`emlAnnotationSubprocessor` page documents the XPath as
`//annotation/valueURI/text()` alone — the string `propertyURI` does not
appear on the page — and lists the field as `Multi: False` where the bean sets
`multivalue="true"`. Two errors on one row, and a reader of that page alone
concludes the predicate is discarded, which is the opposite of what both the
current and the legacy source do. Sourced to the configuration, not the prose
about it.

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
4. **On the EML side, every annotation carries a `label` attribute on both
   `propertyURI` and `valueURI`.** This is not style. MetacatUI's
   `EMLAnnotation.js` `parse()` returns early — dropping the annotation
   **entirely** — if either `label` is missing, so an unlabelled annotation
   vanishes from the landing page with no error and no warning anywhere. That
   landing page is justification 1 in
   [section 3](#consumer-1-knb-and-dataone-the-one-that-already-exists), so
   losing the label loses the only present-tense gain the recommendation
   claims. `.ms_eml_add_annotation()` (`R/eml-export.R`) already emits both,
   via its `predicate_label` and `value_label` arguments, so **metasalmon is
   compliant today** — the risk is a new I-ADOPT annotation being added
   without them. *Retires when:* an export-side test asserts that every
   emitted annotation carries both `label` attributes, at which point the
   compliance is enforced rather than merely true.

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
- **`inputs[]`, each with `path` and `sha256`** — the files the generator
  actually read: `metadata/semantic/measurement-decompositions.csv` and its
  manifest, or `metadata/column_dictionary.csv` in the fallback case. This is
  the field that makes the graph checkable against the package it ships in
  rather than only against itself, and the rule below says why
  `artifact.sha256` cannot do that job.
- `provenance.generated_by`, `provenance.metasalmon_version`
- per-component `source` / `source_version`, carried through from the
  decomposition rows, so a consumer can tell which vocabulary release an
  entity IRI was drawn from

And the rule that makes the versioning real rather than decorative: **the graph
is derived, so it is never edited in place.** It is regenerated. What proves it
still matches the package is **two independent checks, not one** — and the
2026-09-15 draft of this card said the artifact hash was the whole of it, which
is wrong. *(Corrected 2026-09-16 after a review of PR #116.)*

- **Artifact integrity.** `artifact.sha256` over the graph bytes catches a
  hand-edited graph, and that is all it catches. A graph and its manifest stay
  mutually consistent through any change to the *inputs*: edit
  `measurement-decompositions.csv` after generation and the hash still
  verifies while the graph publishes assertions the package no longer makes.
  Nothing in the manifest notices, and the failure is invisible from inside the
  package — which is worse than a hand-edited graph, because a stale graph is
  self-consistent and looks correct.
- **Input binding.** The manifest has to record what the graph was derived
  *from*, in a form a validator can re-check against what is in the package
  now.

**Reading `validate_sdp_measurement_decompositions()` is what shows the two are
separate**, and it is the analogue to copy. It is
`read_sdp_measurement_decompositions(path, validate = TRUE)`, which runs
`.ms_sdp_decomposition_validate_manifest()` — schema version, artifact path,
`sha256` over the exact bytes, `row_count`, writer provenance — **and then**
`.ms_sdp_decomposition_validate_dictionary()`, which re-reads
`metadata/column_dictionary.csv` out of the package and checks the artifact
against it: that each `dataset_id`/`table_id`/`column_name` still resolves to
one dictionary row with `column_role` `measurement`, that
`measurement_concept_iri` still equals that row's `term_iri`, and that every
non-empty dictionary `property_iri`, `entity_iri`, `constraint_iri`,
`statistical_modifier_iri` and `unit_iri` still appears as a matched component
of the same role. Every one of those can go wrong with the hash check passing.
The decomposition artifact is bound to its input by the second check, never by
the first.

Two shapes for the iop graph's input binding, and the package already ships
both patterns:

- **`inputs[]` digests** — the field above. The validator re-hashes each named
  file and fails when a digest has moved. This makes "the graph is stale" a
  first-class error rather than something a reader has to infer, and it is
  cheap: one `digest::digest()` per input.
- **A recomputed derivation fingerprint**, the `plan_sha256` pattern in
  `R/knb-publication.R`. `.ms_knb_plan_fingerprint()` hashes the canonical JSON
  of the whole plan, and the publication path re-derives that fingerprint from
  current state and compares it against the stored one
  (`identical(reviewed_fingerprint, plan$plan_sha256)`), so a manifest is
  disowned the moment the inputs that would produce it move. This is the
  stricter pattern and the more expensive one.

**Recommend `inputs[]` digests plus a role-level re-check of the graph against
the dictionary, and not a full re-derivation-and-compare.** Re-derivation is
the strongest check available and it is also the one that makes the validator
depend on the generator staying byte-stable forever: any later change to
serialization order, prefix layout or a label would fail every package
published before it, and the failure would report a stale graph where the real
change was in the emitter. Input digests fail exactly when an input changed,
which is the condition actually worth naming.

One asymmetry to carry across, because it is why the decomposition validator
cannot simply be copied: its dictionary check is a **containment** check —
every dictionary value must appear in the artifact — precisely because the
artifact is *allowed* to hold more than the dictionary does, in extra same-role
components and explicit `gap` rows. The iop graph is a pure function of its
inputs and is forbidden from holding gap rows at all
([section 4](#what-generates-them), rule 2), so for it the relation is
equality in both directions and a stricter check is available than the
precedent uses.

And the consequence that follows from the input binding rather than from the
hash: **a graph whose input digests no longer verify is a publication blocker,
not a warning.** `R/knb-publication.R` already calls
`validate_sdp_measurement_decompositions()` before it publishes, and the iop
validator belongs at the same point, because [section 5](#5-what-it-would-cost)
is about published triples outliving the package that made them — and a stale
triple outlives it while looking exactly like a current one.

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

## 6. Recommendation

**A recommendation, not a ruling. Brett decides; nothing below is operative.**

**Recommend: yes to emission, scoped to I-ADOPT, built so a second projection
is cheap but not built for one.** Concretely, and in this order:

1. **Do not build a general triple-emission framework now.** Two clients
   exist in principle and neither has a consumer asking for it. The
   specification's twice-recorded position — projectable, not projected — is
   the right one to keep for Data Cube.
2. **Do build the I-ADOPT projector**, as a sidecar graph under
   `metadata/semantic/` closed by its own manifest, generated from
   `measurement-decompositions.csv` with a dictionary fallback, pinning
   `https://w3id.org/iadopt/ont/1.1.0` by version IRI, hashed, **bound to its
   derivation inputs by per-input digests in the manifest and re-checked
   against the dictionary before publication** ([section 4](#4-b-the-pattern-for-emitting-them),
   *How they version*), and published only through its manifest. The artifact
   hash alone does not bind a derived graph to the package it ships in, and a
   stale graph is worse than a missing one because it is self-consistent.
3. **Extend the EML annotations in the same decision** — for the landing page
   **and** for term-level API retrieval, and **not** for paired or structural
   search and **not** for the human at KNB's search box. The index flattens
   predicate and object into one unpaired bag, so no query recovers the
   pairing, and MetacatUI's picker cannot reach a non-ECSO IRI at all. What
   emission does buy is two things
   ([section 3](#consumer-1-knb-and-dataone-the-one-that-already-exists)): a
   human reading the KNB dataset page sees the decomposition with each
   predicate attached to its object, because MetacatUI renders the annotation
   from the EML document rather than from Solr; and `sem_annotation` gains the
   component IRIs, so a client holding a property or entity IRI can retrieve
   the datasets that use it — a query that returns nothing today, because EML
   currently carries only the compound term and the unit. Smaller than the
   claim this card made on 2026-09-14, larger than the one it made on
   2026-09-15.
   It still requires answering the exporter's stated reason for declining, and
   the answer is available: the reason given is *incomplete* I-ADOPT roles,
   and rule 1 of the generator is exactly a completeness gate — a column that
   satisfies the class axiom is not incomplete. The exporter's caution about
   `dcterms:subject` and unsupported ranges was about asserting a range the
   term does not support; `iop:hasProperty` has `rdfs:range iop:Property`, so
   asserting it for a reviewed property IRI is the supported case. **This is
   my reading of the exporter's intent, not a ruling recorded anywhere**, and
   it is now the point in this card I would most want contradicted.
4. **Take the five costs as requirements, not caveats.** The
   plural-component refusal, the `gap`-row exclusion, the `label`-attribute
   rule on every EML annotation, the input-digest binding with a validator that
   re-checks it, and a `SURFACE 8` section in the role-contract guard if a
   predicate map is introduced.
5. **Put the predicate map and the subject-IRI scheme in the pull request
   text**, with justification other than "validation passed".

**Did either finding change the recommendation? No — the argument changed
twice, in opposite directions, and the recommendation is now weaker than
2026-09-14 and stronger than 2026-09-15 left it.** All three statements matter
and none should be reported without the others.

*Why it survives.* The sidecar is the larger half of the recommendation and
**its value never depended on the index**; it is read directly or not at all.
Consumer 3 in [section 3](#consumer-3--the-ecosystems-own-downstream-tools) —
the ecosystem's own tools, which currently re-derive the decomposition from the
dictionary's column layout in two implementations and no artifact — never
depended on RDF at all, let alone on DataONE. Neither is touched by what the
indexer does.

*Why it is weaker than 2026-09-14.* That draft's argument was that a DataONE
user could find datasets by a component of the variable, and I called it "the
strongest argument in favour of emission". The *structural* half of it is dead:
the index keeps no pairing, so nothing can be queried by role, and the person
at KNB's search box cannot reach a non-ECSO IRI at all. What is left is
coarser than what was claimed.

*Why it is stronger than 2026-09-15 left it.* That revision replaced the
deleted argument with the landing-page rendering alone and said the case now
rested mainly on prospective and internal benefits. It does not. Emission also
puts the component IRIs into `sem_annotation`, where they are retrievable by a
client that has an IRI and wants the datasets using it — present-tense, on the
one consumer that already exists, and impossible today because EML carries only
the compound term and the unit. That is a second concrete benefit, not a
restatement of the first, and the 2026-09-15 text denied it while listing it.
It is an **inference** from the indexer configuration rather than a
measurement, and it is stated as one.

**What would change the recommendation now.** Not the index question; that is
settled and already priced in, in both directions. Two load-bearing
uncertainties remain. **Whether the landing-page rendering and the term-level
retrieval together are worth the format commitment of
[section 5](#5-what-it-would-cost)** — published triples outlive the package
that made them, and the exactly-1 axiom makes a plural component a silent
falsehood. And **whether the retrieval affordance survives contact with a real
node**, which the deposit test in [section 8](#what-was-not-established-stated-as-limits-rather-than-as-silence)
would settle; if it does not, the EML half falls back to the rendering benefit
alone and the 2026-09-15 reading of the strength becomes the right one. If
Brett reads either trade as not worth it, *wait* becomes the right answer for
the EML half and the sidecar could still proceed alone. That split — sidecar
yes, EML annotations later — is a coherent third option and this card does not
argue against it.

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

### What was not established, stated as limits rather than as silence

The 2026-09-15 indexer pass settled more than it left open, but not
everything, and the gaps are named here so nobody infers them closed:

- **No I-ADOPT annotation was deposited and indexed.** That needs a write to a
  Metacat test node, which this pass did not do. "I-ADOPT IRIs would be
  indexed literally" is an inference from the XPath filtering nothing and from
  other non-whitelisted IRIs being indexed. *What would settle it:* deposit an
  I-ADOPT-annotated EML 2.2.0 record to a test node and query
  `sem_annotation:"https://w3id.org/iadopt/ont/hasObjectOfInterest"` against
  it.
- **No claim is made about any DataONE member node other than KNB.** The
  configuration read is the indexer's and MetacatUI's; a different node could
  deploy a different search interface.
- **The exporter's reason for declining the I-ADOPT projection** is read from
  its own documentation, not from a ruling. §6 item 3 marks that as my reading
  and it remains the part of the card most in need of contradiction.

There is **no `NEWS.md` entry** for this card, deliberately: `knowledge/` is
excluded from `R CMD build` and nothing observable changes.

---

## 9. Source register

Every identifier below was resolved with a tool during the 2026-09-14 pass, or
the 2026-09-15 indexer pass where the row says so. **Tool-resolved, not
human-verified.** A fuller ledger, including the negatives, was produced
alongside this card; the negatives worth carrying here are in the notes
column.

| id | source | resolved | passage located |
|---|---|---|---|
| `iadopt-ont-1.1.0` | I-ADOPT Framework ontology 1.1.0, RDA I-ADOPT WG — [`https://w3id.org/iadopt/ont`](https://w3id.org/iadopt/ont) | Turtle fetched from `https://i-adopt.github.io/ontology/ontology.ttl` (200, `text/turtle`, 21645 bytes); HTML at `https://i-adopt.github.io/ontology/` (200) declares version 1.1.0, released 2025-05-28 | Yes — `owl:Ontology` header (`owl:versionIRI https://w3id.org/iadopt/ont/1.1.0`); the `Variable` `owl:equivalentClass` axiom with both exactly-1 qualified cardinality restrictions; the `hasProperty`, `hasObjectOfInterest`, `hasConstraint`, `hasContextObject`, `hasMatrix`, `hasStatisticalModifier` and `constrains` axioms with their domains, ranges and absence of cardinality |
| `rda-iadopt-outputs-2022` | Magagna B., Moncoiffe G., Devaraju A., Stoica M., Schindler S., Pamment A. *InteroperAble Descriptions of Observable Property Terminologies (I-ADOPT) WG Outputs and Recommendations*. Research Data Alliance, 2022. [doi:10.15497/RDA00071](https://doi.org/10.15497/RDA00071) | DataCite API; title, authors, year, publisher and version confirmed from the record | **No — metadata only.** Full text not read, so no claim in this card rests on its contents. Cited as the WG recommendation the ontology page itself references |
| `iadopt-terminologies-registry` | I-ADOPT Terminology Repository — [`https://i-adopt.github.io/terminologies/`](https://i-adopt.github.io/terminologies/) | HTTP 200, 22304 bytes, title "I-Adopt Terminology Repository" | Yes — the per-role registry metasalmon vendors as `inst/extdata/iadopt-terminologies.csv` |
| `eml-2.2-annotation-primer` | *EML 2.2, ch. 7: Semantic Annotation Primer*, KNB/NCEAS — [`https://eml.ecoinformatics.org/semantic-annotation-primer.html`](https://eml.ecoinformatics.org/semantic-annotation-primer.html) | HTTP 200 | Yes — the `propertyURI`/`valueURI` structure; "An annotation element always has a parent-EML element, which is the 'thing' being annotated, or the subject"; appendix 7.6.1 *Semantic triples* and 7.6.3 *RDF Graphs*; glossary definition of RDF as subject-predicate-object |
| `w3c-data-cube-2014` | Cyganiak R., Reynolds D. (eds). *The RDF Data Cube Vocabulary*. W3C Recommendation, 16 January 2014 — [`https://www.w3.org/TR/vocab-data-cube/`](https://www.w3.org/TR/vocab-data-cube/) | HTTP 200, 174074 bytes | Yes — masthead date and `REC-vocab-data-cube-20140116`; vocabulary index listing `qb:DataStructureDefinition`, `qb:Observation`, `qb:DimensionProperty`, `qb:MeasureProperty`, `qb:AttributeProperty` |
| `w3c-ogc-ssn-2017` | Haller A., Janowicz K., Cox S. et al. (eds). *Semantic Sensor Network Ontology*. W3C Recommendation, 19 October 2017; OGC 16-079 — [`https://www.w3.org/TR/vocab-ssn/`](https://www.w3.org/TR/vocab-ssn/) | HTTP 200, 673275 bytes | Yes — masthead: W3C Recommendation 19 October 2017 (link errors corrected 08 December 2017), joint W3C/OGC, OGC Document Number OGC 16-079 |
| `frictionless-data-package-v2` | Pollock R., Walsh P., Kariv A., Karev E., Desmet P., Data Package Working Group. *Data Package Standard*, v2 — [`https://datapackage.org/standard/data-package/`](https://datapackage.org/standard/data-package/) | HTTP 200, 83822 bytes | Yes — Descriptor Properties section. **Negative recorded:** case-insensitive counts on the retrieved page are `@context` 0, `json-ld` 0, `jsonld` 0, `rdf` 0, `linked data` 0. Absence on one page is weaker than a normative statement, so the claim in [section 4](#where-the-triples-live) is scoped to what was retrieved |
| `dataone-indexer-eml-annotation` **(2026-09-15)** | `DataONEorg/dataone-indexer`, `src/main/resources/application-context-eml-annotation.xml` on `main` — [raw](https://raw.githubusercontent.com/DataONEorg/dataone-indexer/main/src/main/resources/application-context-eml-annotation.xml) | HTTP 200, read in full | Yes — `EmlAnnotationSubprocessor`; `matchDocuments` is the single value `https://eml.ecoinformatics.org/eml-2.2.0`; one `SolrField` bean, `name` `sem_annotation`, `xpath` `//annotation/propertyURI/text() \| //annotation/valueURI/text()`, `multivalue` `true`. **The XPath is a union**, so predicate and object both land in one unpaired multivalued field and the subject is not recorded |
| `dataone-indexer-legacy` **(2026-09-15)** | `DataONEorg/d1_cn_index_processor`, same filename on `master` — [raw](https://raw.githubusercontent.com/DataONEorg/d1_cn_index_processor/master/src/main/resources/application-context-eml-annotation.xml) | HTTP 200 | Yes — byte-identical XPath and `matchDocuments`. Cited to show the behaviour is **long-standing rather than recent**, so it is not a transient state to wait out |
| `dataone-indexer-wiring` **(2026-09-15)** | `DataONEorg/dataone-indexer`, `src/main/resources/index-context-file-includes.xml` on `main` | HTTP 200 | Yes — `<import resource="application-context-eml-annotation.xml" />` at line 51, one of 35 imports alongside the EML, FGDC and Dryad contexts. Establishes it is **in the standard build**, not a prototype |
| `metacatui-eml-annotation` **(2026-09-15)** | `NCEAS/metacatui`, `src/js/models/metadata/eml211/EMLAnnotation.js` and `src/js/views/searchSelect/AnnotationFilterView.js` on `main` | HTTP 200, both | Yes — `parse()` reads `propertyURI`/`valueURI` from the EML `objectDOM` and **returns early, dropping the annotation, if either `label` attribute is absent**; the landing page therefore renders from the document rather than from Solr. `AnnotationFilterView.js` line 74 sets `defaultOntology: "ECSO"` |
| `dataone-indexer-docs-stale` **(2026-09-15)** | *DataONE Content Indexer 2.3.3*, `emlAnnotationSubprocessor` page — [`https://indexer-documentation.readthedocs.io/en/latest/generated/proc_emlAnnotationSubprocessor.html`](https://indexer-documentation.readthedocs.io/en/latest/generated/proc_emlAnnotationSubprocessor.html) | HTTP 200 | Yes, **and it is wrong twice.** Documents the XPath as `//annotation/valueURI/text()` alone — the string `propertyURI` does not occur anywhere on the page — and lists the field as `Multi: False` where the bean sets `multivalue="true"`. **Cited only as a warning not to cite it**; the configuration is the authority |

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
