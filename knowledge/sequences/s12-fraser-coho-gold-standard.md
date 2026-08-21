---
type: InformationObject
title: "S12 — the Fraser coho gold-standard example"
description: "Make one bundled Fraser coho example a validator-clean, fully annotated, publishable exemplar. Which of the two shipped examples it should be is an open decision."
status: draft
tags: [example, validation, teaching, nuseds]
psc:
  id: metasalmon:sequence:s12-fraser-coho-gold-standard
  contexts: [metasalmon:context:hub-coordination]
---

# S12 — the Fraser coho gold-standard example

**Execplan:** to be written. Evidence: the 2026-08-21 example-and-validator
recon in the [backlog](../backlog.md#open--the-2026-08-21-example-and-validator-recon)
(#95, #97–#102), plus the measurements below.

One Fraser coho package that is what the ecosystem says a Salmon Data Package
looks like: created by `create_sdp()`, fully annotated, clean through both
validators, published, and pointed at from the docs, the workshop and the
Python mirror. Every other stream has been assuming this artifact exists.

**Why it is a stream now.** A stated top priority with no card cannot be
sequenced, cannot block anything, and cannot be noticed as missing. Before
2026-08-21 the phrase "gold standard" appeared **nowhere** in this bundle, and
the nearest thing to it was an *exercise dataset* line inside the S3/S4
execplan — a workshop input, not an exemplar anyone owns. See the
[roadmap](../roadmap.md#the-streams) for that finding; this card is the owner it
lacked.

## Open decision — which example is the gold standard?

**Two bundled examples, neither one currently an exemplar, and the choice has
not been made.** It is recorded here as a decision, not settled:

| | `nuseds-fraser-coho-sample.csv` | `nuseds-fraser-coho-2023-2024.csv` |
|---|---|---|
| Rows | 30 (1996–2024) | 173 (2023–2024) |
| Canonical metadata | ships `dataset.csv`, `tables.csv`, `column_dictionary.csv`, `codes.csv` | **ships none of them** — only `nuseds-fraser-coho-2023-2024-column_dictionary.csv`, a *starter dictionary* |
| Dates | Oracle `DD-MON-YY` against a declared `value_type: date` | converted to ISO in `data-raw/` |
| Validates today | **No** — 2 structural issues in both modes (backlog **#98**) | **No** — see the measured state below |
| Spec-validator `codes.csv` errors | **157**, across 14 columns (#95) | **22**, across 6 columns (#95) |
| Its stated job | "the fastest built-in demo", *"retained unchanged for backwards compatibility"* | "more realistic package creation, testing, and documentation examples" |

Possible rulings: **(a)** promote the 173-row slice and leave the 30-row sample
as the fast demo it claims to be; **(b)** promote the 30-row sample, accepting
that fixing #98 means changing a file the README promises is unchanged;
**(c)** both, with the difference between exemplar and demo stated in the
example README; **(d)** neither — mint a third, purpose-built package and
demote both.

**Unblocks:** what S4's NuSEDS exercise builds on; what S11's executable
walkthrough executes (slice 6 there); which artifact #95's and #98's retirement
conditions are measured against; and whether the ecosystem maintains one
exemplar or two. **Retires when:** Brett rules, and the example README states
the roles in the same change. *Note the backwards-compatibility promise is
itself a constraint someone made, not a law* — but breaking it is a decision,
so it belongs in the ruling rather than in an implementer's judgement.

## Measured state of the 173-row candidate

Measured 2026-08-21 by running the code, not by reading it. The invocation is
part of the measurement, because two of these counts move with it:
`create_sdp(list(nuseds_fraser_coho = <csv>), dataset_id = "dataset-1",
seed_semantics = FALSE)`.

- **It ships no `dataset.csv`, `tables.csv` or `codes.csv` of its own.** The
  bundled ones in `inst/extdata/` belong to the 30-row sample — their
  `dataset_id` is `nuseds_fraser_coho_sample`. So "the fuller example" is a CSV
  plus a starter dictionary, not a package.
- **One of its 14 dictionary rows carries any IRI at all**:
  `NATURAL_ADULT_SPAWNERS`, with `property_iri` (`smn:Abundance`) and `unit_iri`
  (QUDT `INDIV`) — and **no `term_iri`**. Thirteen rows are entirely unannotated.
- **Strict validation fails on exactly that**: `Measurement columns require
  term_iri; missing in rows 8.`
- **Default validation returns a 0-row issues tibble** — no findings — while the
  spec validator reports 27 errors on the same bytes. That gap is
  [S1](s1-validation-authority.md)'s subject and it is measured there.
- **16 of the 23 generated code values get no IRI** (7 do, from the estimate
  crosswalk), across `AREA`, `SPECIES`, `RUN_TYPE`, `ESTIMATE_METHOD`,
  `ESTIMATE_CLASSIFICATION`, `ESTIMATE_STAGE`. Record the invocation with any
  future count: a differently-named `table_id` or a live semantic seeding pass
  changes it, and a bare number here would decay into a false claim within a
  release.

## Blockers, and they are not all metasalmon's

- **#90 — the descriptor-key ruling.** A *fully annotated* exemplar is exactly
  the artifact that trips `scripts/validate_package.py`: the seven I-ADOPT keys
  appear on `schema.fields` only once a measurement column is annotated the way
  the spec asks. So S12 cannot produce a clean-through-both-validators package
  until #90 is ruled — annotating it is what breaks it.
- **The `codes.csv` / `column_role` class (#95).** 22 of the 27 spec errors on
  this example are code rows targeting columns `infer_column_role()` typed
  `attribute`. `create_sdp()` writes both sides of that contradiction in one
  call. Nothing S12 can do by hand fixes it; the generator has to stop
  producing it.
- **#48 / #49 — [S1](s1-validation-authority.md).** An exemplar validated by a
  gate that under-checks is an exemplar of nothing. S12 wants S1's conformance
  test as its evidence, not a green console line.
- **Two real ontology gaps, and both should be term requests rather than
  bundle prose:**
  - **Species.** The column's only value is `Coho`. PR #27 **withdrew** its
    species scheme, and species concepts are never minted in `gcdfo` (Brett,
    2026-08-17) — so there is no term in either ontology for a salmon species
    today, and the exemplar's `SPECIES` column has nothing to point at.
  - **PFMA subareas.** `AREA` holds `29F`, `29G`, `29J`, `29K` — **subareas**.
    gcdfo PR #86 minted the **48 Areas** and deliberately not Schedule 2's 604
    numbered Subareas, with a `skos:scopeNote` saying so. The vocabulary is
    complete for Areas and honestly silent here, which means the gap is real
    rather than an oversight to route around.

  Both belong in `salmon-knowledge-commons`' gap register and then through
  `detect_semantic_term_gaps()` → `render_ontology_term_request()` →
  `submit_term_request_issues()`. Note **#97**: that detector returns zero gaps
  when retrieval returned zero candidates, which is precisely the shape both of
  these have — so filing them today is manual work, and #97 is why.

## Dependencies

- **Needs [S3](s3-knb-staging.md) for a finish line.** "Gold standard" that
  stops at a validated directory is half the claim; the exemplar should be
  *published*, with a resolvable identifier the docs can cite. Until there is a
  rehearsal path, the only way to finish it is a live production deposit —
  which is how the ecosystem's one real deposit happened
  ([S13](s13-fraser-recruits-case-study.md)).
- **Consumed by [S4](s4-workshop-rebuild.md).** The workshop's NuSEDS exercise
  builds this package; the execplan already names the 173-row file as the
  download. So S4 inherits whichever artifact S12's decision picks, and cannot
  sensibly be written before it.
- **Feeds [S11](s11-vignettes-and-walkthroughs.md) slice 6**, the executable
  end-to-end walkthrough — that slice is what would keep this exemplar from
  silently rotting after it is built.
- **Mirror rule:** metasalmonpy ships the same example data
  (`data/column_dictionary.csv` among them, which carries two of the 404 IRIs
  in #99). Whatever S12 fixes, the mirror's copy moves in the same stream or a
  `PARITY.md` row says why not.
