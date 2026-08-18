---
type: InformationObject
title: "S5 — R-native review flow and API hygiene"
description: "Scriptable, re-runnable semantic review (review_semantics / accept_suggestion / apply_sdp_semantics), condition classes, and accessors; ships as the next minor at ship time. Backlog items 58, 59, 60, 74."
status: draft
tags: [review, api]
psc:
  id: metasalmon:sequence:s5-review-flow
  contexts: [metasalmon:context:hub-coordination]
---

# S5 — R-native review flow and API hygiene · #58, #59, #60, #74 · ships as the next minor

**Execplan:** [R-native review and editing](../plans/2026-08-11-r-native-review-and-editing.md)
(#74) · #58/#59/#60 detail in the [comprehensive ecosystem review](../plans/2026-08-10-comprehensive-ecosystem-review.md).

**#74 is the headline.** Today the documented review workflow leaves R for a
spreadsheet, and the only record of the most consequential decision in the
pipeline is a mutated CSV — the single unreproducible link in a chain that is
otherwise byte-reproducible and guarded. `review_semantics()` /
`accept_suggestion()` / `apply_sdp_semantics()` make the decision scriptable and
re-runnable.

**Why these four ship together:** #60 (the `semantic_suggestions` /
`semantic_llm_assessments` attributes have no accessor) is #74's prerequisite —
the review queue has to read those attributes through a supported accessor. #58
(condition classes) is breaking for anyone matching on message text and already
wants a major bump, and #74 adds roughly ten exported functions, which wants the
same bump. One breaking-release story is cheaper than three coordinated
releases. **That minor is no longer 0.3.0** — S8 took it; S5 ships as whatever
minor is next when it lands.

Independent of every other stream. ~~Smaller sibling: **#75**, an auto-applied
`method_iri` with no `metadata/methods.csv` — fixed by the execplan's
slice 2.~~ **#75 no longer belongs to this stream**: sdp-0.3.0 removed the
dictionary `method_iri` slot and the registry outright, so S8's breaking change
superseded the defect before S5's slice 2 reached it. Do not carry it as S5
scope. **Mirror rule:** whatever minor this ships as lands in metasalmonpy at
the same version.
