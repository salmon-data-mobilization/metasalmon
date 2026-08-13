---
type: InformationObject
title: "SDP method model draft"
description: "Draft SDP spec section for methods, protocols, procedures, and aggregation; ports to smn-data-pkg once settled. Prerequisite reading for backlog item 76."
status: draft
tags: [sdp, methods, draft]
psc:
  id: metasalmon:draft:sdp-method-model
  contexts: [metasalmon:context:hub-coordination]
---

# Draft SDP spec section — methods, protocols, and procedures

**Status: draft for review.** Written in spec voice, ready to port to
`smn-data-pkg`. Not yet normative anywhere.

This proposes the conceptual model the SDP currently implements but never
states, and one breaking change that follows from it. It is the prerequisite for
backlog **#76** (which modelling style is canonical for method concepts) — that
decision needs this one to name the concepts first.

---

## The one rule

> **A method describes how an observation was made, not what was observed.
> Record it at the coarsest level where it is still true.**

Everything below follows from that sentence.

The second half matters as much as the first. Recording a method more finely
than it actually varies is not more precise — it is repetition that will drift
out of sync, and it asks a contributor to answer the same question many times.

---

## The concept model — PNAMP nesting

**Protocol > Method**, following PNAMP/monitoringresources.org. Two levels, not
three parallel concepts.

### Protocol

A documented plan someone else could follow. It specifies **which methods apply
to which measurements**. Versioned where possible.

> *"PSC sockeye escapement survey protocol, v3"*

A protocol is a *document*. It is cited, not executed. **This is the key
simplification**: because the protocol already names the per-measurement
methods, the dataset does not have to repeat them.

**A protocol does not have to be external.** Requiring a DOI or a published URL
would exclude most real salmon datasets, where the collection plan lives in a
program document, a field manual, or nothing at all. Three forms, in descending
order of preference:

| Form | How it is referenced |
|---|---|
| **Published** — DOI or stable URL | `protocol_iri` points at it |
| **In-package** — described in the package's own `README.md` | `protocol_citation` names the section; `protocol_iri` may be omitted |
| **Undocumented** | Say nothing. An absent protocol is honest |

The in-package form matters more than it looks. It is the realistic path for a
first-time contributor, it keeps the description **with the data** rather than in
a link that will rot, and writing it down is often the first time a program's
methods have been written down at all. The spec should name the README as a
legitimate home rather than treating an external DOI as the only real answer.

### Method

A technique named by a protocol and applied to produce a value. Two subtypes,
not two separate concepts:

| Subtype | Answers | Example |
|---|---|---|
| **Observation method** | How was it observed? | Aerial survey count, fixed-site electronic counter |
| **Analytical method** | How was the number derived from observations? | Area-under-the-curve expansion, Petersen estimator |

**Subclass rather than a parallel concept**, deliberately. SOSA folds every
sense of "procedure" into `sosa:Procedure` and offers exactly one relation,
`sosa:usedProcedure`. A parallel top-level concept would have **no SOSA relation
to attach to** and would need one invented. A subclass inherits `usedProcedure`,
stays queryable through the hierarchy, and needs no new property — which also
settles open question 3 below.

Salmon data already separates the two: NuSEDS records an *enumeration method*
(how fish were counted) and an *estimate method* (how the escapement figure was
derived), and neither implies the other.

### PNAMP's third level, and why it is not ours

PNAMP nests Protocol > Method > **Metric**, and a Metric is close to a column.
That looks like it contradicts "method does not go on the column", and it does
not — the two describe **different layers**:

- PNAMP describes a **protocol design**: *for metric X, use method Y.* A
  specification of what will be done.
- The SDP describes **data**: *this value was produced this way.* A record of
  what was done.

So per-metric methods are entirely legitimate — **in the protocol**. In the
dataset you cite the protocol and record a method only where the data cannot be
derived from it: when the method varies, or departs from the plan.

## Where each is recorded

| Level | File | Use when |
|---|---|---|
| **Table** (observation unit) | `tables.csv` — `protocol_iri`, `protocol_citation` | **Start here.** A protocol governs a kind of observation event — a site visit — which is what a tidy table is |
| **Dataset** | `dataset.csv` — `protocol_iri`, `protocol_citation` | Convenience only: the same protocol governs every table |
| **Table** | `tables.csv` — `method_iri` | A single method applies and there is no protocol document to cite |
| **Row** | A data column bound with `sosa:usedProcedure` | The method varies from row to row |

**Protocol belongs at the table, not the dataset.** An earlier draft said
dataset-level and "start here"; that was wrong. A protocol governs a kind of
observation event — you have a protocol for *collecting data at a site visit* —
and a tidy table is exactly one kind of observation unit. A protocol may span
several tables, which the dataset-level field covers, but that is the special
case and not the default.

This also dissolves the per-column problem the earlier drafts kept circling. A
site-visit table with a spawner count from an aerial survey and a water
temperature from a logger does **not** need per-column method metadata, because
**the protocol already specifies which method each measurement uses**. Cite the
protocol; record a method in the data only where it varies or departs from it.

### No `methods.csv` registry

Dropped, and the reasoning is worth stating because `codes.csv` looks like a
precedent and is not one.

`codes.csv` exists because code values are **dataset-local tokens**. `"GN"` means
gill net *in this dataset*; nothing outside it can resolve that string. The
registry is the only place the meaning can live.

A method is the opposite: a **shared concept with a resolvable IRI**. A registry
for it duplicates the vocabulary, and duplicated definitions drift. Two things
the registry was carrying instead go elsewhere:

- **Label, description, definition** — these belong in the vocabulary the IRI
  resolves to. If a method has no term yet, add one; the vocabularies are
  maintained by the same people as the spec.
- **Version and citation** — these are properties of the **protocol**, not of
  the method, and now sit beside `protocol_iri` where they were always meant to
  be.

Net effect: `metadata/` holds exactly the four levels again — dataset, tables,
columns, codes — with no fifth file to explain.

### Why not a per-measure placement

An earlier draft proposed one on the observation-structure extension, for a
table whose measures were made differently. Dropped, because **the protocol
answers it**: a site-visit protocol already specifies which method each
measurement uses, so repeating that per column in the dataset is duplication
that will drift.

Where there is genuinely no protocol and the methods genuinely differ per
measure, that is a signal worth heeding — the table may be carrying two
observational units, and splitting it gives each one method. If it truly is one
unit, say nothing rather than invent a per-column slot.

**Note the two senses of "observation".** Tidy data's *observational unit* is the
entity a row describes — a site visit, a fish. SOSA's *Observation* is a single
act producing a single result. A site-visit row holding two measurements is
**one** tidy observational unit and **two** SOSA observations. `tables.csv`'s
`observation_unit` field carries the tidy sense, and this model uses that sense
throughout.

### Not recorded on a column

`column_dictionary.csv` defines a **variable** — what is measured. A method is a
property of the **act of measuring**. Putting it on the column definition is a
category error, and it is the reason a method IRI can currently be attached to a
variable with nothing to register it against.

This is also why I-ADOPT — which the column dictionary follows — has no method
component. A variable is Property + Entity of Interest + Constraints + Context
Object. How you measured it is not part of what it is.

---

## Deciding where to put it

One question, asked in order. Stop at the first *yes*.

```
Is there a protocol document describing how this table's data were collected?
        └── yes → tables.csv protocol_iri (+ protocol_citation).
                  The protocol names the per-measurement methods.
                  Nothing further is needed unless the data depart from it.
Does the method vary from row to row?
        └── yes → it is data, not metadata.
                  Add a column and bind it with sosa:usedProcedure.
Is one method constant for the whole table, with no protocol to cite?
        └── yes → tables.csv method_iri.
Otherwise → say nothing. An absent method is honest; an invented one is not.
```

The second case is worth stating plainly because contributors try to force it
into metadata: **if a value varies per row, it belongs in the data.** A method
column is an ordinary categorical column with coded values.

The last line matters as much as the rest. A slot that must be filled produces
`MISSING METADATA:` noise, and this model has no required method field anywhere.

## Worked example — NuSEDS escapement

One table, one row per (population, year), reporting an escapement estimate.
Counting technique varies by year; the estimation approach is constant.

| Question | Answer | Placement |
|---|---|---|
| Protocol for this table? | Yes — the NuSEDS standard | `tables.csv.protocol_iri` |
| Counting technique constant? | **No** — aerial in some years, weir in others | a data column bound `sosa:usedProcedure` |
| Analytical method constant? | Yes — AUC expansion throughout | named by the protocol; no dataset field needed |

Three questions, no extension, no registry, and the only thing written twice is
the thing that actually varies.

## I-ADOPT: what to adopt, and what to leave

The column dictionary is already I-ADOPT-shaped — `property_iri`, `entity_iri`,
`constraint_iri`, `unit_iri`. Two questions arise about going further.

### Context Object — recommend **not** adopting

I-ADOPT's `ContextObject` is the most abstract part of the model and the least
consistently used across adopting vocabularies. Adding a slot for it would cost
a required-looking field that most contributors cannot answer, which this
package has already learned produces `MISSING METADATA:` noise rather than
meaning (#77).

The cases it would carry — "in the Fraser River", "at the counting fence" — are
already served by `constraint_iri` and by the table's own spatial and temporal
metadata. Leave it out until a real dataset needs it and cannot be expressed.

### Statistical modifiers — a genuine gap, and **not** a constraint

metasalmon has **no statistical handling at all**: no vocabulary, no slot. Yet
salmon variables are full of it — *mean* fork length, *peak* spawner count,
*cumulative* escapement, *annual total* catch. Today it is smuggled into
`column_label` as English, where nothing can query it, or lost.

Concretely: daily **mean** and daily **maximum** water temperature decompose to
**identical** I-ADOPT components today. The semantics assert two different
variables are the same variable.

**Recommendation: a dedicated `aggregation_iri` column, not `constraint_iri`.**
An earlier draft proposed reusing the constraint slot. That was wrong, and the
reason matters.

`constraint_iri` is a real I-ADOPT component — confirmed in this package's own
schema (*"I-ADOPT constraint IRI(s)"*) and vignette, which give its intended
examples as *spawner stage, female sex, freshwater age class*. A constraint
**narrows what is measured**: which fish, which life stage, which portion of the
population. An aggregation says nothing about which fish — it says what the
**number represents** across them. Overloading one slot with both would make
`constraint_iri` mean two unrelated things and would make neither queryable.

Two standards keep them separate, and both are precedents already cited here:

- **ODM2** has `AggregationStatistic` as its **own controlled vocabulary**
  (average, maximum, minimum, cumulative…), separate from Variable — the same
  design that puts Method on the Action rather than the Variable.
- **CF conventions** keep `cell_methods` separate from `standard_name`, so the
  statistic never contaminates the variable identifier.

**Why this belongs in `column_dictionary.csv` when method does not** — the line
is worth stating, because the two changes travel together and look
contradictory:

| | Question it answers | Part of variable identity? | Home |
|---|---|---|---|
| **Method** | *How did you produce this?* | No — the same variable can be measured many ways | Protocol / table / data |
| **Aggregation** | *What does this number represent?* | **Yes** — mean temperature and maximum temperature are different variables | `column_dictionary.csv` |

So the same breaking change removes `method_iri` from the column dictionary and
adds `aggregation_iri` to it, and the apparent inconsistency is the point: one
describes the act, the other describes the variable.

*Scope:* a small controlled list to start — mean, median, minimum, maximum,
total, count, peak — sourced from an existing vocabulary rather than minted here
if one fits. **Open:** which vocabulary. ODM2's CV is the obvious candidate but
is not RDF-native; this needs the alignment pass.

### What else I-ADOPT offers that is worth taking

Beyond the four components already used, the highest-value unused piece is
**emitting actual `iop:` triples**. metasalmon consumes I-ADOPT *terminologies*
but never states, in RDF, that a column's four IRIs form an I-ADOPT Variable. A
consumer therefore has to infer the decomposition from column names. That is a
small, additive change with real interoperability payoff, and it belongs on the
roadmap independently of methods.

## What changes

**Breaking:** `column_dictionary.method_iri` is removed, and `metadata/methods.csv`
is removed with it.

**Migration.** A `method_iri` on a measurement column becomes the table's
`method_iri` when all measurement columns in the table agree. When they disagree,
the migration **stops and reports** rather than guessing: the contributor decides
whether to split the table, record at dataset level, or move the method into the
data. A `REVIEW:`-marked value is dropped, not migrated — it was never a reviewed
decision.

**Additive:** `protocol_iri` / `protocol_citation` on **`tables.csv`** (primary)
and on `dataset.csv` (when uniform across tables); `method_iri` on `tables.csv`
for the no-protocol case.

**Requirement level:** not applicable — `methods.csv` no longer exists. Labels
and definitions come from the vocabulary the IRI resolves to; version and
citation belong to the protocol and sit beside `protocol_iri`. `metadata/` holds
exactly the four levels again.

**Rules affected.** `methods_are_sosa_procedures` loses its
`column_dictionary.method_iri` clause and gains the three new placements.
`row_varying_procedures_use_codes` is unchanged — it already describes the row
case correctly.

Impact in metasalmon, measured: `method_iri` appears in **13 `R/` files, 14 test
files, and 5 schema files**. This is a spec-version-bump change, not a patch.

---

## Relationship to other standards

| Standard | How it handles this |
|---|---|
| **SOSA/SSN** | One class. `sosa:Procedure` explicitly covers "a workflow, protocol, plan, algorithm, or computational method", attached to the **Observation** via `sosa:usedProcedure`. SOSA gives no help distinguishing the three; subclassing is required. |
| **I-ADOPT** | No method component at all. Confirms the column dictionary is the wrong home. |
| **EML 2.2** | `methods` at dataset level, `methodStep` containing an optional `protocol` — so EML separates step from protocol, and places both above the variable. |
| **Darwin Core** | `samplingProtocol` at Event level; `measurementMethod` on the measurement record. Both levels, distinct terms. |
| **ODM2** | `Method` is first-class and attached to an **Action**; the `Variable` table has none. The closest precedent for this proposal. |
| **PNAMP / monitoringresources.org** | Protocol → Method → Metric, explicitly nested. |
| **CF conventions** | `cell_methods` means statistical treatment over cells — a fourth sense of the word, out of scope here. |

*Verify before publishing:* the exact DwC-DP measurement-table field names and
the current PNAMP nesting. Both are cited from general knowledge, not from a
fetched copy.

**Tidy data (Wickham 2014)** is the structural assumption underneath all of
these, and worth citing directly in the spec: each variable a column, each
observation a row, each observational unit a table.

---

## This model assumes tidy input, which is not enforced

The decision procedure asks *"is the method constant within each table?"*. That
question is only sound when a table is a coherent observational unit — one
variable per column, one observation per row. Against a wide sheet with a column
per year, or a matrix pasted into a CSV, it has no meaningful answer.

**The SDP asks for tidy input and currently enforces none of it** (backlog
**#77**, verified): `primary_key` uniqueness is never checked, there is no
wide-format detection, and `MISSING METADATA:` placeholders ship while
`validate_salmon_datapackage()` reports zero issues.

So this model has a prerequisite, and it should be stated in the spec rather than
assumed: **tidy structure is a precondition of the method placement rules, not an
aspiration alongside them.** Sequence the tidy checks first.

Note also the two senses of "observation" this creates a trap for. Tidy's
*observational unit* is an entity — a site visit, a fish. SOSA's *Observation* is
a single act producing a single result. This model uses the tidy sense
throughout. A row may legitimately hold several SOSA observations; that is not a
tidiness failure and must not be treated as one.

---

## Answers to the open questions (#76)

Settled in review; recorded here as recommendations for the alignment pass.

### 1. Three concepts or one? → **Protocol > Method, with two Method subtypes**

PNAMP nesting. Observation method and analytical method are **subclasses of a
generic Method**, not parallel top-level concepts — see *The concept model*. The
deciding argument is SOSA: one relation exists, so a parallel concept would have
nothing to attach to.

### 2. Where do the concepts live? → **SMN, in gcdfo's style**

Both halves of the question have an answer, and they point in opposite
directions from the current state.

**Live in SMN.** It is the shared vocabulary; gcdfo is the DFO-specific one. A
method concept that any salmon dataset might cite belongs in the shared layer,
with gcdfo holding only genuinely DFO-specific terms and mapping to SMN.

**But adopt gcdfo's modelling style, not SMN's.** gcdfo's stance — methods are
pick-list items, so model them as `skos:Concept` in a scheme — is not a shortcut.
It is **more technically correct** for this use:

> `sosa:usedProcedure` has `rdfs:range sosa:Procedure`, and its object is an
> **individual**. SMN currently models methods as `owl:Class`
> (`smn:FishLengthMeasurementMethod rdfs:subClassOf sosa:Procedure`), so using
> one as the object of `usedProcedure` means using a class where an individual
> belongs — OWL 2 punning. A `skos:Concept` is an individual and slots in
> directly.

So the recommendation is to **change SMN**, not gcdfo: move method concepts from
OWL classes to SKOS concepts in a scheme, typed additionally as
`sosa:Procedure`, and let `skos:broader` carry the Protocol > Method > subtype
hierarchy. That keeps them pick-list friendly, keeps them maintainable, and makes
`usedProcedure` resolve without punning.

*What is given up, concretely.* With OWL classes a reasoner answers "is this a
kind of aerial survey?" for you — subclass relations are entailed. With SKOS you
walk the hierarchy yourself.

**A correction worth stating precisely, because the loose version is wrong:**
`skos:broader` is **not transitive**. SKOS made it non-transitive deliberately,
so that a vocabulary can assert a direct broader link without committing to
inheritance up the whole chain. The transitive super-property is
`skos:broaderTransitive`, and `skos:broader rdfs:subPropertyOf
skos:broaderTransitive`, so an RDFS reasoner infers the transitive form from the
direct one.

Which means there are two correct ways to ask, and neither depends on
`skos:broader` being transitive:

```sparql
# Property path — syntactic closure, no reasoner, works in any triplestore
?m skos:broader+ smn:AerialSurvey .

# Entailed — needs RDFS reasoning to populate broaderTransitive from broader
?m skos:broaderTransitive smn:AerialSurvey .
```

The first is what to recommend: one `+`, no reasoner, universally supported. The
earlier phrase "a transitive `skos:broader` query" was wrong — the *query* takes
a transitive closure; the *property* is not transitive.

### 3. Does an analytical method need a different SOSA relation? → **No**

Subclassing removes the need. Both subtypes are `sosa:Procedure`, both attach
via `sosa:usedProcedure`, and the distinction is carried by the concept's type
rather than by a new property. Inventing a property outside SOSA would be the
same class of mistake as the invented `sosa:Property` the ecosystem review found.

### 4. Which modelling style is canonical? → **SKOS, with dual typing**

Answered by (2): `skos:Concept` in a scheme, additionally typed
`sosa:Procedure`. One style across both vocabularies, chosen because it is what
`usedProcedure` actually expects.

### 5. Does the tidy precondition become normative? → **Yes**

Confirmed. With the checks now shipped (#77, 0.2.6), the consequence is concrete
rather than theoretical:

- **Normative (MUST):** a declared `primary_key` identifies exactly one row, and
  each variable occupies one column. Both are now enforced as errors.
- **Recommended (SHOULD), enforced as a warning:** no value-like column names.
  This stays a warning because the heuristic **cannot prove** untidiness — a
  column genuinely named `2000` is legal, just suspicious. Promoting a heuristic
  to an error would reject conforming packages.

That split is the honest one: enforce what can be checked exactly, warn about
what can only be guessed.

---

## Still open after this pass

1. **Statistical modifiers via a dedicated `aggregation_iri`** — recommended above, flagged as
   the weaker argument. Needs a decision, and a small controlled list if adopted.
2. **Migrating SMN methods from OWL classes to SKOS concepts** — the concrete
   work item behind answer (2). Breaking for anything that consumed those class
   IRIs; scope before scheduling.
3. **Emitting `iop:` triples** — additive, independent of methods, worth its own
   roadmap slot.
