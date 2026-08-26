---
type: InformationObject
title: "S5 — R-native review flow and API hygiene"
description: "Scriptable, re-runnable semantic review (review_semantics / accept_suggestion / apply_sdp_semantics), condition classes, and accessors; ships as the next minor at ship time. Backlog items 58, 59, 60, 74. M1-M3 landed 2026-08-25; M4/M5, #58 and #59 remain."
status: draft
tags: [review, api]
psc:
  id: metasalmon:sequence:s5-review-flow
  contexts: [metasalmon:context:hub-coordination]
---

# S5 — R-native review flow and API hygiene · #58, #59, #60, #74 · ships as the next minor

**Execplan:** [R-native review and editing](../plans/2026-08-11-r-native-review-and-editing.md)
(#74) · #58/#59/#60 detail in the [comprehensive ecosystem review](../plans/2026-08-10-comprehensive-ecosystem-review.md).

**#74 is the headline, and its semantic half landed 2026-08-25.**
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

**What remains, and it is what the stream still ships for.** M4 (free-text
editing: `review_metadata()` and the `set_sdp_*()` setters) and M5 (the vignette
and `README-review.txt` rewrite; `_pkgdown.yml` and the README already name the
R path first). Until M4 lands, `validate_salmon_datapackage(require_iris = TRUE)`
still fails after a complete semantic review, for two reasons: free-text
`MISSING …:` placeholders are refused and are still spreadsheet-edited, and
`review_semantics()` shows **shortlists, not gaps** — a slot retrieval found
nothing for never enters the queue. `review_metadata()` closes both, because it
reads required-but-unfilled from the schema rather than from the suggestions.
So the plan's proof 6 — *a user who never opens Excel can complete the whole
review* — is delivered for the semantic half only. #58 and #59 are untouched.

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
