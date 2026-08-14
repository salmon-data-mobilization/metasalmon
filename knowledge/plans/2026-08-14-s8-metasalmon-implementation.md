---
type: Artifact
title: "S8 metasalmon implementation of sdp-0.3.0"
description: "Execplan for the breaking R change: re-vendor sdp-0.3.0, remove method_iri and the methods.csv registry with a stop-and-report migration, add statistical_modifier_iri; metasalmonpy mirror rides S10."
status: draft
tags: [execplan, s8, breaking]
psc:
  id: metasalmon:plan:2026-08-14-s8-metasalmon-implementation
  contexts: [metasalmon:context:hub-coordination]
---

# S8 — metasalmon implementation of sdp-0.3.0

**Status: ready to implement.** Spec merged (smn-data-pkg PR #4). This plan
distills the 2026-08-14 three-agent recon (full 58k-char per-file map in the
session task output; the essentials are inline here so the plan stands alone).

## Decisions (logged)

| Decision | Rationale | Date |
|---|---|---|
| The frozen 19-col semantic target row and ~30-col LLM assessment row swap the `method` role/column for `statistical_modifier` | Forced by the spec: the dictionary field is gone; a vestigial method column would describe nothing. This is the AGENTS.md "logged decision" for touching frozen contracts | 2026-08-14 |
| The metasalmonpy mirror of S8 rides the S10 replay; **S10's scope is extended in this same planning commit** so the mirror is actually scheduled (replay 0.1.7→0.2.6, then the 0.3.0 method-model change) | "Same version" is literally unsatisfiable at 0.1.6 parity, and 0.1.6-era Python has no observation-structures family to mirror the row-varying half anyway; version-as-parity-claim (Brett 2026-08-13) resolves it — the mirror lands as S10's final parity milestone, and an unscheduled promise would violate the mirror contract | 2026-08-14 |
| The codes-scope `method` search role **survives** (row-varying procedures still need shared-vocab `sosa:Procedure` terms); only the measurement-column method target dies | Spec §Methods: codes.csv term_iri resolves directly to procedure concepts | 2026-08-14 |
| This release takes the next minor version (0.3.0); S5's "ships as 0.3.0" note becomes "next minor at ship time" | Two breaking streams cannot share a number; first to ship takes it | 2026-08-14 |

## Slices (each: suite green, then commit)

### 1. Re-vendor + schema plumbing
- `R/schema-helpers.R`: drop the `methods` entry from `.ms_sdp_metadata_schema_paths()`
  (with it present a 0.3.0 bundle fails to load); profile path/URL v0.2→v0.3;
  rewrite the `sdp_methods` comment block.
- `inst/extdata`: replace the six metadata schemas + `sdp.rules.yaml`; delete
  `methods.schema.json`; add `profiles/salmon-data-package/v0.3/profile.json`
  (keep v0.2 vendored? No — metasalmon vendors only the current contract;
  read-tolerance for old descriptors is by profile-identity derivation, P0-2).
- Column contracts retarget automatically: `.ms_dataset_meta_cols`/
  `.ms_table_meta_cols`/`.ms_dictionary_cols` derive from the bundle and
  `.ms_align_cols` appends missing columns — verify by round-trip test.

### 2. Extension-helpers split + registry removal + migration
- Move the SHARED `.ms_sdp_extension_*` family (R/sdp-methods.R:20-412; used by
  observation-structures ×88, knb-publication, reproducibility-manifest) to
  `R/sdp-extension-helpers.R` FIRST.
- Remove exported `write_sdp_methods`/`read_sdp_methods`/`validate_sdp_methods`
  (+NAMESPACE via document(), roxygen, `_pkgdown.yml:115-117` in the same
  commit); keep an internal legacy reader (descriptor-validation-free) as
  migration input.
- New `migrate_sdp_methods(pkg_path)` implementing spec §Migration: column
  method_iri → tables.csv method_iri when all measurement columns agree;
  **stop and report** on disagreement; `REVIEW:` values dropped; methods.csv
  labels/descriptions surfaced in the report (they belong to the vocabulary),
  version/citation offered as protocol fields. Port the symlink/atomic-write
  hardening from the old writer tests. Register any canonical-ordering fn in
  `collation_sensitive_fns`.
- `.ms_sdp_methods_normalize` leaves `collation_sensitive_fns`.

### 3. Dictionary/semantic retarget (the role swap)
- Swap `method_iri`→`statistical_modifier_iri`: dictionary-helpers (:201, :56,
  :1247-1255, :1290-1293), package-helpers (:223-225 descriptor emission,
  :3332-3335, :3045 gate), validation_helpers (:57-60). Descriptor custom
  keys: emit and read `iAdopt:statisticalModifierIri`; the legacy
  `iAdopt:methodIri` key is **not** dropped blind — `migrate_sdp_methods()`
  reads old descriptors directly, so a descriptor-only v0.2 package keeps its
  only copy of the method binding until migration relocates it.
- Semantic roles: semantic-suggestions roles map + measurement-column loop
  emits `statistical_modifier` targets (recommended vocabulary
  `smn:StatisticalModifierScheme`); keep codes-scope `method` role;
  semantics-helpers role_to_field; semantic-bundle-review roles/slot-fields +
  system prompt ("part of variable identity; a method is never recorded
  here"); llm-semantic-helpers role_order/slot_fields/prompts;
  chat-decomposition used_procedure guess sourced from tables.csv (statistic
  slot seeds from statistical_modifier_iri); measurement-decompositions
  **drops the method role entirely** and adds statistical_modifier as a
  native role: a decomposition row binds to one measurement's variable
  identity, while a row-varying procedure is data bound with
  `sosa:usedProcedure` — keeping a method slot would pin an arbitrary
  procedure to the variable (method-model-draft, usedProcedure placement).
- EML/DwC export + KNB: eml-export methods.csv reader (:2803-2808) →
  tables/dataset protocol+method fields; knb-publication artifact inventory
  drops methods.csv; observation-structures static-method registry checks →
  absolute-IRI shared-vocab checks (mirror the spec validator's rewrite).
- NuSEDS crosswalk: **already correct** — the prefill maps crosswalk terms
  into `codes$term_iri` (the approved row-varying representation) and emits
  no per-column method_iri. Scope: preserve and test that binding, no
  retarget.

### 4. Tests + fixtures
- `test-sdp-methods.R`: registry tests die; port the hardening tests to the
  migration writer; new tests: stop-and-report disagreement, agreement
  migration, REVIEW-drop, statistical_modifier_iri round-trip + validation,
  tables/dataset protocol fields round-trip, 0.2-descriptor read tolerance.
- `test-observation-structures.R` fixture: registry → direct shared-vocab
  term_iri codes (already the right shape).
- inst/extdata template CSVs: column_dictionary gains statistical_modifier_iri
  (drops method_iri), tables gains the three fields.
- Watch the frozen-contract guards: 19-col row tests, 30-col adapter tests —
  update per the logged decision, keeping empty/success row-set identity.
- Suite target: 0 failures, 5 local skips; `R CMD check` clean.

### 5. Docs, NEWS, version
- NEWS: breaking entry in the 0.2.4 house pattern (what breaks, migration
  command, what to do with hand-authored packages).
- Vignette framing (S8's own, distinct from S11 slice 1): llm-context-review
  slot list (method slot → statistical_modifier; deterministic validator
  wording), reusing-standards role table (+destination note, +statistical
  modifier row), glossary five components + placements paragraph,
  post-review decomposition artifact ordering.
- Version 0.3.0; pkgdown rebuild; roadmap S5 note updated ("next minor").

### 6. Hub close-out + S10 card note (the mirror decision) + bundle updates.

## Verification
`devtools::test()` green each slice; `R CMD check` before the PR; a full
create→validate→migrate→publish-dry-run round trip against both spec example
packages (vendored copies) as the acceptance test.
