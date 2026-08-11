# Draft SDP spec section — methods, protocols, and procedures

**Status: draft for review.** Written in spec voice, ready to port to
`smn-data-pkg`. Not yet normative anywhere.

This proposes the conceptual model the SDP currently implements but never
states, and one breaking change that follows from it. It is the prerequisite for
backlog **#76** (the SMN/gcdfo typing mismatch) — that typing cannot be fixed
until this settles what is being typed.

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
| **Table** | `tables.csv` — `method_iri` *(proposed)* | One row is one observation (`observation_unit` says so), and the method is constant for the table |
| **Observation structure** | `structure/observation_structures.csv` — `method_iri` *(proposed)* | One row carries several measures, each produced differently |
| **Row** | A data column bound with `sosa:usedProcedure` | The method changes from row to row |
| **Registry** | `methods.csv` | Any of the above uses an IRI that needs a label, description, version, or citation |

`methods.csv` is to methods what `codes.csv` is to codes: **a registry you create
only when you have values to register.** It is not a fifth level of metadata. The
four levels remain dataset, tables, columns, codes.

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
Does it differ between tables, but not within one,
  and does one row represent one observation?
        └── yes → tables.csv method_iri.                 Done.
Does one row carry several measures made differently?
        └── yes → an observation structure per measure,
                  each with its own method_iri.          Done.
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

Note what this buys: the varying thing is queryable per row, the constant things
are stated once, and nobody is asked to repeat the protocol on 40 columns.

---

## What changes

**Breaking:** `column_dictionary.method_iri` is removed.

**Migration.** A `method_iri` on a measurement column becomes, in order of
preference: the table's `method_iri` if all measurement columns in the table
agree; otherwise an observation structure per distinct method. A `REVIEW:`-marked
value is dropped, not migrated — it was never a reviewed decision.

**Additive:** `protocol_iri` / `protocol_citation` on `dataset.csv`;
`method_iri` on `tables.csv` and on `observation_structures.csv`.

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
4. **What types a `methods.csv` row?** Whatever answers (1)–(3) must make
   `sosa:usedProcedure` resolve to something a SOSA-aware consumer can use.
