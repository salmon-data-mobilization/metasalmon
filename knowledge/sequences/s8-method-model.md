---
type: InformationObject
title: "S8 — Method model and tidy foundations"
description: "Decide what the SDP means before S1 decides what it checks: the method placement model and tidy-data enforcement. Backlog items 76 and 77."
status: draft
tags: [sdp, methods, tidy-data]
psc:
  id: metasalmon:sequence:s8-method-model
  contexts: [metasalmon:context:hub-coordination]
---

# S8 — Method model and tidy foundations · #76, #77 · spec + metasalmon

**Draft model:** [SDP method model draft](../method-model-draft.md)
(for review; ports to `smn-data-pkg` once settled).

Two coupled items that decide what the SDP *means* before S1 decides what it
*checks*.

**#77 — tidy enforcement. Shipped in 0.2.6.** Primary-key uniqueness,
wide-format detection, and placeholder surfacing.

**#76 — the modelling styles.** SMN uses an OWL class hierarchy under
`sosa:Procedure`; gcdfo uses a SKOS concept scheme; metasalmon's crosswalks point
at gcdfo. Not a defect — but the two styles are not interchangeable for
querying, and which is canonical had never been decided. The
[ontology alignment pass](../plans/2026-08-12-ontology-alignment-pass.md)
resolves this in its step 2, **after this stream names the concepts**.

**The method placement model.** `column_dictionary.method_iri` is a category
error: a method describes how an observation was made, not what was observed.
Three placements replace it — table protocol, table method, or a data column
when it varies per row — plus a dedicated `statistical_modifier_iri` (the
fifth I-ADOPT component column; values instance-typed
`iop:StatisticalModifier`), whose vocabulary is S9 step 5's
`smn:StatisticalModifierScheme`. Port note: upstream smn-data-pkg PR #2 added
an optional `methods.csv` registry that this stream's spec port must unwind.

**Order within the stream: #77 (done) before #76.** The method model asks "is
the method constant within each table?", which is only sound when a table is a
coherent observational unit.

**Blocks:** S9 step 2 (methods-as-SKOS) and S4's method-annotation teaching.
**Consumes:** S9 step 5 (the statistical-modifier scheme), which is independent of S9
steps 2–4 precisely so this stream can consume it.

**Breaking.** `method_iri` appears in 13 `R/` files, 14 test files, and 5 schema
files. Spec version bump with a migration that stops and reports rather than
guessing. **Mirror rule:** the breaking change lands in metasalmonpy at the
same version.
