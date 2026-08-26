---
type: InformationObject
title: "S5 — R-native review flow and API hygiene"
description: "Scriptable, re-runnable semantic review and editing (review_semantics / accept_suggestion / apply_sdp_semantics / review_metadata / set_sdp_*), condition classes, and accessors; ships as the next minor at ship time. Backlog items 58, 59, 60, 74. M1-M5 all landed 2026-08-25 and #74 is closed; #58 and #59 remain."
status: draft
tags: [review, api]
psc:
  id: metasalmon:sequence:s5-review-flow
  contexts: [metasalmon:context:hub-coordination]
---

# S5 — R-native review flow and API hygiene · #58, #59, #60, #74 · ships as the next minor

**#74 is closed (2026-08-25), and #60's accessor clause with it — #60's other
clauses stand. #58 and #59 are what remain of this stream.**

**Execplan:** [R-native review and editing](../plans/2026-08-11-r-native-review-and-editing.md)
(#74) · #58/#59/#60 detail in the [comprehensive ecosystem review](../plans/2026-08-10-comprehensive-ecosystem-review.md).

**#74 is the headline, and all of it landed 2026-08-25** — the semantic half first, the free-text half in the same day.
`review_semantics()` / `accept_suggestion()` / `reject_suggestion()` /
`apply_sdp_semantics()` are in the development version, with the #60 accessors
(`semantic_suggestions()` / `semantic_llm_assessments()`) that were their hard
prerequisite. The console prints the exact decision call and the user pastes it
into a script — no prompt loop, no TUI, because **the paste is the audit trail**
and an interactive prompt would leave the decision as unreproducible as the
spreadsheet it replaces.

**What is done (execplan M1–M3):** the read side and accessors; the console
view; decisions and a surgical, re-runnable, cross-file-atomic write-back that
leaves the data CSV bytes untouched. One defect was found and fixed on the way —
**#118**, the unattended auto-apply heuristic silently overruling explicit
review decisions — which is why this could not have shipped by merely wiring up
the existing `strategy = "reviewed"` seam.

**Mirror state, measured 2026-08-25 and re-measured after M4/M5
(metasalmonpy not edited; still 0.4.0 in `__init__.py` and `pyproject.toml`).**
Everything this stream built is a gap there: no accessor for the suggestion
attributes (Python's only path is the raw `df.attrs[...]`, and
`read_salmon_datapackage` never reads `semantic_suggestions.csv` back at all),
**zero hits for all nine** review and editing function names
(`review_semantics`, `accept_suggestion`, `reject_suggestion`,
`apply_sdp_semantics`, `review_metadata`, `set_sdp_dataset`, `set_sdp_table`,
`set_sdp_column`, `set_sdp_code`), zero hits for `decision_reason`, **no
consumer or even parser of the schema's `constraints.required`** — the fact
`review_metadata()` is built on — and the descriptor's `contributors` /
`licenses` blocks still inline in `package_io.py` (≈934–957) rather than
extracted, which is exactly where R started. The **#118 defect is present in
the same shape** at `semantics.py:1294`. Both packages claim 0.4.0 and this
work is unreleased, so no `parity-deviations.md` row is owed yet — this is
ordinary "R shipped first" state, not a deliberate difference at a claimed
version.

**What IS owed the moment this releases, and it is a correction rather than an
addition:** metasalmonpy's `PARITY.md` **row 31** ends with the claim that
`strategy = "reviewed"` is *"verified identical to R's output for all three
strategies"*. That was true when written and is false the moment this ships —
R's `reviewed` path is now exempt from the unattended auto-apply gate (#118),
and R writes a `decision_reason` column Python does not have. **Nothing will
announce that**, because the row still reads as a passing verification. It must
be **amended in place, not joined by a new row**: a new row saying the two
differ, sitting under an old row saying they were verified identical, leaves a
reader to guess which sentence is current. The mirror port owes: the nine
functions, the `decision_reason` column, `decision` replay on queue rebuild,
the `constraints.required` consumer, and the descriptor-builder extraction.

**M4 and M5 landed 2026-08-25, and #74 is closed.** `review_metadata()` plus
`set_sdp_dataset()` / `set_sdp_table()` / `set_sdp_column()` / `set_sdp_code()`
close the two gaps M1–M3 measured and left open: free-text `MISSING …:`
placeholders had no R-native editor, and `review_semantics()` shows
**shortlists, not gaps** — a slot retrieval found nothing for never entered the
queue. `review_metadata()` closes both because it reads the package against the
rules that decide strict validation (the schema's `constraints.required`, the
placeholder markers, the measurement-IRI requirement, the table
observation-unit requirement) rather than against a suggestion list.

**The bar is measured, not asserted:** `create_sdp()` → `review_semantics()` →
`apply_sdp_semantics()` → `review_metadata()` → `set_sdp_*()` →
`validate_salmon_datapackage(require_iris = TRUE)` passes **with no file opened
in a spreadsheet at any point**, driven end to end by
`tests/testthat/test-sdp-field-setters.R`, which *executes the calls the
console printed*. The plan's proof 6 — *a user who never opens Excel can
complete the whole review* — is delivered whole. M5 removed the vignette
section titled *"Review In Excel"* and rewrote the `README-review.txt` the
package writes into every folder; the spreadsheet path stays supported and
stays named as the fallback.

**Three round-trip defects in the M1–M3 API were found by teaching it** and are
fixed in the same change: a rejection was written to
`semantic_suggestions.csv` and never read back (so the next review asked the
same question again), the rejection **reason** never reached disk at all, and
an empty queue under a mistyped `columns` filter printed the *completion*
message. Their shared shape is worth carrying: **a feature that writes a record
and never reads it back has not been round-tripped, and no test that only
writes will say so.** `prune = TRUE` now warns before destroying recorded
decisions. **#119** is filed, not fixed — `variable` and `property` retrieve an
identical ranked list from `gcdfo`, which is a retrieval-filter question
intersecting Q9, not a review one.

**#58 was judged, 2026-08-25, and does not need to be in the same PR.** The
argument for bundling is about the *release*, not the change: both want a
breaking bump, and one breaking-release story is cheaper than three. Condition
classes are ~450 mechanical call-site edits across the whole package and share
no code with the review flow, so bundling them into one PR would only make both
harder to review. #58 can land any time before this stream's release; the
review-flow functions deliberately do **not** invent a class naming scheme
ahead of that ruling, because a half-classed package is worse than an unclassed
one.

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
