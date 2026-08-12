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

## Three things, currently all called "method"

The SDP distinguishes these. Most standards do too, under different names; SOSA
deliberately does not (see *Relationship to other standards*).

### Protocol

A documented, citable plan that someone else could follow. Stable across
datasets, versioned, and normally has a DOI or a stable URL.

> *"PSC sockeye escapement survey protocol, v3"*

A protocol is a *document*. It is cited, not executed.

### Procedure

The technique actually applied to produce an observation. A protocol may name
several; a dataset may use one or many.

> *"Aerial survey count"*, *"fixed-site electronic counter"*, *"foot survey"*

### Analytical method

How a reported number was **derived** from observations. Distinct from the
procedure that produced the underlying observations.

> *"Area-under-the-curve expansion"*, *"Petersen mark-recapture estimator"*

**These last two are genuinely different and salmon data already separates
them.** NuSEDS records an *enumeration method* (how fish were counted) and an
*estimate method* (how the escapement figure was derived) as separate fields.
A dataset can have an aerial survey enumeration and an AUC-expansion estimate;
neither implies the other.

---

## Where each is recorded

| Level | File | Use when |
|---|---|---|
| **Dataset** | `dataset.csv` — `protocol_iri`, `protocol_citation` *(proposed)* | One protocol governs the whole dataset. **Start here.** |
| **Table** | `tables.csv` — `method_iri` *(proposed)* | The method is constant for the table |
| **Row** | A data column bound with `sosa:usedProcedure` | The method changes from row to row |
| **Registry** | `methods.csv` | Any of the above uses an IRI that needs a label, description, version, or citation |

**Three placements, deliberately.** An earlier draft added a fourth on the
observation-structure extension, for a table whose measures were made
differently. That is dropped — see *Why not a per-measure placement*.

`methods.csv` is to methods what `codes.csv` is to codes: **a registry you create
only when you have values to register.** It is not a fifth level of metadata. The
four levels remain dataset, tables, columns, codes.

### Why not a per-measure placement

A table can carry several measures made differently — a spawner count from an
aerial survey and a water temperature from a logger, in one site-visit row. The
SDP could express that on the observation-structure extension. **It deliberately
does not.**

Two reasons.

*The rare case should not complicate the common one.* Method varying between
measures in one table is uncommon; method constant per table, or varying per row,
covers nearly everything. A model whose common path requires an optional
extension is a model most contributors will get wrong.

*It is usually a signal, not a requirement.* If two measures in one table were
produced by genuinely different procedures, they are often two observational
units that tidy data would separate anyway. The guidance is therefore: **treat a
per-measure method difference as a prompt to check whether the table is carrying
two observational units.** If it is, split it — each table then has one method.
If it genuinely is not, record the method at dataset level and accept the coarser
statement, or put it in the data as a column.

**Note the two senses of "observation".** Tidy data's *observational unit* is the
entity a row describes — a site visit, a fish. SOSA's *Observation* is a single
act producing a single result. A site-visit row holding two measurements is
**one** tidy observational unit and **two** SOSA observations. `tables.csv`'s
`observation_unit` field carries the tidy sense. This model uses the tidy sense
throughout; it does not require a row to be a single SOSA Observation, because
requiring that would push every multi-variable table into an extension.

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
Is the method the same for the whole dataset?
        └── yes → dataset.csv protocol fields.           Done.
Is it constant within each table?
        └── yes → tables.csv method_iri.                 Done.
Does the method change from row to row?
        └── yes → it is data, not metadata.
                  Add a column, bind it with sosa:usedProcedure,
                  and resolve its codes to methods.csv.
```

The last case is worth stating plainly because contributors often try to force it
into metadata: **if a value varies per row, it belongs in the data.** A method
column is an ordinary categorical column with coded values.

---

## Worked example — NuSEDS escapement

One table, one row per (population, year), reporting an escapement estimate.
Counting technique varies by year; the estimation approach is constant.

| Question | Answer | Placement |
|---|---|---|
| Protocol for the whole dataset? | Yes — the NuSEDS standard | `dataset.csv.protocol_iri` |
| Analytical method constant? | Yes — AUC expansion throughout | `tables.csv.method_iri` |
| Counting technique constant? | **No** — aerial in some years, weir in others | a data column, `sosa:usedProcedure`, codes → `methods.csv` |

Every placement here is one of the three. No extension is needed for what is
probably the most common salmon dataset shape in existence.

Note what this buys: the varying thing is queryable per row, the constant things
are stated once, and nobody is asked to repeat the protocol on 40 columns.

---

## What changes

**Breaking:** `column_dictionary.method_iri` is removed.

**Migration.** A `method_iri` on a measurement column becomes the table's
`method_iri` when all measurement columns in the table agree. When they disagree,
the migration **stops and reports** rather than guessing: the contributor decides
whether to split the table, record at dataset level, or move the method into the
data. A `REVIEW:`-marked value is dropped, not migrated — it was never a reviewed
decision.

**Additive:** `protocol_iri` / `protocol_citation` on `dataset.csv`;
`method_iri` on `tables.csv`.

**Requirement level:** `methods.csv` moves from *optional* to **conditional** —
required when any `method_iri` is used, absent otherwise. This matches
`codes.csv` and makes its presence earned rather than incidental.

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

## Open questions for the alignment pass (#76)

1. **Are protocol / procedure / analytical method three classes or one with
   three roles?** This section treats them as three concepts. The ontologies must
   agree before the typing is fixed.
2. **Where do the concepts live — SMN or gcdfo?** Today the SOSA scaffolding is
   in SMN (two `sosa:Procedure` subclasses) and all the domain content is in
   gcdfo as SKOS with no SOSA typing. The layers do not meet.
3. **Does an analytical method need a different SOSA relation than
   `usedProcedure`?** SOSA folds derivation into Procedure. If the distinction is
   to survive into RDF, it needs either subclassing or a different property.
4. **Which modelling style is canonical for method concepts — OWL classes under
   `sosa:Procedure` (SMN's) or a SKOS concept scheme (gcdfo's)?** Note this is
   *not* a correctness problem: `sosa:usedProcedure` has `rdfs:range
   sosa:Procedure`, so entailment already types the object correctly whichever
   style supplies it, and `skos:Concept` is not disjoint from `sosa:Procedure`.
   The question is queryability — `skos:broader` carries no subclass entailment,
   so the same question answers differently depending on which vocabulary a term
   came from.
5. **Does the tidy precondition become normative?** If the spec states tidy
   structure as a requirement rather than a recommendation, the validator has to
   enforce it (#77) and some existing packages will stop conforming. If it stays
   a recommendation, the method placement rules keep a soft edge. **Recommend
   normative**, with the wide-format check as a warning rather than an error —
   the SDP can accept untidy data, it should simply stop implying it checked.
