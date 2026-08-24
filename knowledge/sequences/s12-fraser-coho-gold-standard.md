---
type: InformationObject
title: "S12 — the Fraser coho gold-standard example"
description: "Make one bundled Fraser coho example a validator-clean, fully annotated, publishable exemplar. Ruled 2026-08-24 (Brett): it is the 173-row nuseds-fraser-coho-2023-2024.csv, with the 30-row sample demoted to a speed fixture; the finish line is clean through both validators, then deposited under S3's exit criteria."
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

## The gold standard is the 173-row example — RULED 2026-08-24

**Ruling (Brett, 2026-08-24, hub [Q4](../questions.md)):** *"Promote the 173 row
one."* So:

- **`inst/extdata/nuseds-fraser-coho-2023-2024.csv`** (173 rows, 2023–2024) **is
  the gold standard.** It has a reproducible `data-raw/` derivation, a licensed
  upstream (Open Government Canada), and ISO dates.
- **`inst/extdata/nuseds-fraser-coho-sample.csv`** (30 rows) is the **named speed
  fixture** — "the fastest built-in demo", which is what its own README already
  claims. That is ruling **(a)** of the four this card listed, and it means the
  README's *"retained unchanged for backwards compatibility"* promise is **not**
  broken by the ruling: the small file keeps its job.
- The example README states both roles, in the change that implements this.

The comparison that supported the ruling is kept, because the numbers are what
make the choice legible and two of them are retirement conditions elsewhere:

| | `nuseds-fraser-coho-sample.csv` (speed fixture) | `nuseds-fraser-coho-2023-2024.csv` (**gold standard**) |
|---|---|---|
| Rows | 30 (1996–2024) | 173 (2023–2024) |
| Canonical metadata | ships `dataset.csv`, `tables.csv`, `column_dictionary.csv`, `codes.csv` | **ships none of them** — only `nuseds-fraser-coho-2023-2024-column_dictionary.csv`, a *starter dictionary* |
| Dates | Oracle `DD-MON-YY` against a declared `value_type: date` | converted to ISO in `data-raw/` |
| Validates today | passes both modes since the 2026-08-21 recon fix (backlog **#98**) | lenient clean; strict fails on its one documented blank `term_iri` |
| Spec-validator `codes.csv` errors | **157**, across 14 columns (#95) | **22**, across 6 columns (#95) |

**The gap the ruling opens, and it is the first work item.** The gold standard
*is currently a CSV plus a starter dictionary, not a package* — it ships no
`dataset.csv`, `tables.csv` or `codes.csv` of its own, and the bundled ones
belong to the 30-row sample (`dataset_id = nuseds_fraser_coho_sample`). Promoting
it means giving it canonical metadata of its own, which the demoted sample
already has. Nothing about the ruling makes that work smaller; it makes it
*owned*.

## The finish line — two stages, and the card carries them now

Ruled with the artifact on 2026-08-24, so "gold standard" stops meaning whatever
the reader assumes:

- **Stage 1 — clean through both validators.** Strict
  `validate_salmon_datapackage()` with zero issues **and**
  `scripts/validate_package.py` clean, on a package built by `create_sdp()` from
  the 173-row example with its measurement column fully annotated. Gated on
  [Q3/#90](../backlog.md) (ruled 2026-08-24: the descriptor keys are permitted
  and the spec validator learns them) and on **#95** (the `codes.csv` /
  `column_role` contradiction `create_sdp()` writes in one call).
- **Stage 2 — published.** Deposited under [S3](s3-knb-staging.md)'s exit
  criteria, with a resolvable identifier the docs, the workshop and the mirror
  can cite. A gold standard that stops at a validated directory on someone's
  laptop is half the claim.

Stage 1 is reachable without S3; stage 2 is what S3 blocks. Do not report the
example as finished at stage 1 — say which stage it reached.

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

- **#90 — the descriptor-key ruling. RULED 2026-08-24, so this is now work
  rather than a blocker.** A *fully annotated* exemplar is exactly the artifact
  that trips `scripts/validate_package.py`: the seven I-ADOPT keys appear on
  `schema.fields` only once a measurement column is annotated the way the spec
  asks — annotating it is what breaks it. Brett ruled ([Q3](../questions.md))
  that the keys are **permitted** and that `smn-data-pkg` moves: its
  `descriptor_field_from_column()` learns the keys, with the allowlist derived
  from `column_dictionary.schema.json`, and neither mirror stops projecting them.
  **S12's stage 1 now depends on that change landing in the spec repo**, which is
  a different kind of dependency from an unruled question and should be tracked
  as one.
- **The `codes.csv` / `column_role` class (#95).** 22 of the 27 spec errors on
  this example are code rows targeting columns `infer_column_role()` typed
  `attribute`. `create_sdp()` writes both sides of that contradiction in one
  call. Nothing S12 can do by hand fixes it; the generator has to stop
  producing it.
- **#48 / #49 — [S1](s1-validation-authority.md).** An exemplar validated by a
  gate that under-checks is an exemplar of nothing. S12 wants S1's conformance
  test as its evidence, not a green console line.
- **Two real ontology gaps, and both should be term requests rather than
  bundle prose. Both now have a ruled destination** (Brett, 2026-08-24,
  [Q8](../questions.md): *"I agree with your recommendation PFMA Sub areas go to
  gcdfo."*):
  - **Species → an external taxonomy.** The column's only value is `Coho`. PR #27
    **withdrew** its species scheme, and species concepts are never minted in
    `gcdfo` (Brett, 2026-08-17) — so there is no term in either ontology today,
    and the ruling is that none is created: the `SPECIES` column points at an
    external taxonomy. Choosing *which* authority (WoRMS, NCBI, ITIS, FishBase —
    the commons already carries a card on Pacific salmonid taxonomic
    authorities) is the open implementation question, and it is not an ontology
    gap in the mint-a-term sense.
  - **PFMA subareas → `gcdfo`.** `AREA` holds `29F`, `29G`, `29J`, `29K` —
    **subareas**. gcdfo PR #86 minted the **48 Areas** and deliberately not
    Schedule 2's 604 numbered Subareas, with a `skos:scopeNote` saying so. The
    vocabulary is complete for Areas and honestly silent here, so the gap is
    real. It goes to gcdfo because gcdfo already owns
    `gcdfo:PacificFisheryManagementAreaScheme`, and splitting one regulatory
    vocabulary across repositories for a temporary priority ordering would
    fracture it permanently.

  **This is also the whole of the gcdfo carve-out** ([Q5](../questions.md),
  Brett, 2026-08-24: *"Carve out what the gold standard needs."*): the subarea
  mint is carved out of gcdfo's de-prioritisation, nothing else is, and
  `psc-salmon-vocabularies` stays fully de-prioritised. **Still to decide, by
  this card:** whether the mint covers the four Subareas this example holds or
  all 604 of Schedule 2. Four is enough for the gold standard and leaves a
  vocabulary that is complete for Areas and arbitrary for Subareas; 604 is a
  transcription task with a published, contiguous source. Say which, and say it
  in the term request rather than leaving it to whoever implements.

  Both requests belong in `salmon-knowledge-commons`' gap register and then
  through `detect_semantic_term_gaps()` → `render_ontology_term_request()` →
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
  download — which the 2026-08-24 ruling has now made the gold standard, so S4's
  existing choice and S12's ruled artifact agree, and S4 is no longer waiting on
  S12 to say which file it teaches.
- **Feeds [S11](s11-vignettes-and-walkthroughs.md) slice 6**, the executable
  end-to-end walkthrough — that slice is what would keep this exemplar from
  silently rotting after it is built.
- **Mirror rule:** metasalmonpy ships the same example data
  (`data/column_dictionary.csv` among them, which carries two of the 404 IRIs
  in #99). Whatever S12 fixes, the mirror's copy moves in the same stream or a
  `PARITY.md` row says why not. **The 2026-08-24 ruling makes this concrete**:
  metasalmonpy ships only the 30-row sample, so the mirror is now missing the
  *gold standard* rather than missing a second example —
  [parity-deviations](../parity-deviations.md) row 46, whose "which artifact"
  half Q4 settled and whose remaining open half is narrower: one shared
  derivation script across the two repositories, or one each.
