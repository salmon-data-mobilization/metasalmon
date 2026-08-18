---
type: InformationObject
title: "Package orientation"
description: "Durable orientation for working on metasalmon: architecture, the semantic-review pipeline, domain glossary, and the file-to-responsibility map."
status: draft
tags: [orientation, architecture]
psc:
  id: metasalmon:orientation
  contexts: [metasalmon:context:hub-coordination]
---

# metasalmon — project context

Durable orientation notes for working on this package. Captures facts that are
expensive to re-derive from the (large) source files. Keep this current as the
package evolves. Last substantial update: 2026-08-18 (counts recounted, the
role contract documented, and the duplication map re-checked).
The two releases that set most of what follows: **0.3.0** (2026-08-15 — the
sdp-0.3.0 method placement model: the dictionary swaps `method_iri` for
`statistical_modifier_iri`, the `metadata/methods.csv` registry is removed, and
`migrate_sdp_methods()` is the stop-and-report migration) and **0.2.0**
(2026-08-10 P0 remediation: schema identity, SDP round-trip integrity, sidecar
preservation, cli message safety, and C collation).

## What the package is

`metasalmon` is an R package that scaffolds, standardizes, validates, transforms,
and packages salmon datasets using the **DFO Salmon Ontology** and **Salmon Data
Package (SDP)** conventions. Released 0.3.0. License MIT. R >= 4.1.0.

`main` carries unreleased changes under `NEWS.md`'s **"(development version)"**
section, but **`DESCRIPTION` is still `Version: 0.3.0`** — there is no `.9000`
bump, so the package self-reports the released number while carrying work past
it. Cite the commit, not the version, for anything landed post-0.3.0: the
`smn`-outranks-`gcdfo` ranking fix, the single-owner IRI whitespace predicate
(backlog #85), dual-provenance manifest validation (backlog #88), the datetime
observation-dimension fix, and S11 slice 2's vignettes are all in this state.

- Maintainer: Brett Johnson. Author credit also to "Codex".
- Canonical repository: https://github.com/salmon-data-mobilization/metasalmon
- Pkgdown site: https://salmon-data-mobilization.github.io/metasalmon/
- The canonical package/repository name remains **metasalmon**. Brett decided
  against the proposed `metasmn` rename; do not revive that rename without a new
  explicit decision.

## Primary workflow & entry points

The headline path is one-shot package creation:

```
create_sdp()                         # public one-shot: infer -> seed -> write -> (EDH XML)
  └─ infer_salmon_datapackage_artifacts()   # the orchestrator (R/artifact-inference.R)
       ├─ infer_dictionary(seed_semantics = FALSE)   # column dictionary rows
       ├─ infer_*_from_resources()    # table_meta / codes / dataset_meta
       └─ suggest_semantics()         # deterministic retrieval + optional LLM review
  └─ write_salmon_datapackage()       # writes dataset.csv/tables.csv/column_dictionary.csv/codes.csv
  └─ write_edh_xml_from_sdp()         # optional Enterprise Data Hub XML
```

`infer_dictionary()`, `infer_salmon_datapackage_artifacts()`, `suggest_semantics()`,
and `create_sdp()` are all **public exported functions** — their arguments,
return values, and attached attributes are a compatibility surface.

## Exported function map (from `_pkgdown.yml`)

- **Start here:** `create_sdp`, `infer_salmon_datapackage_artifacts`,
  `read_salmon_datapackage`, `validate_salmon_datapackage`
- **Package assembly:** `write_salmon_datapackage`
- **Dictionary:** `infer_dictionary`, `validate_dictionary`,
  `apply_salmon_dictionary`, `apply_semantic_suggestions`
- **Semantics:** `suggest_semantics`, `chat_decomposition`, `find_terms`,
  `sources_for_role`, `benchmark_term_ranking_fixtures`, `deduplicate_proposed_terms`
- **Ontology + validation:** `fetch_salmon_ontology`, `validate_semantics`,
  `suggest_facet_schemes`
- **Term-request workflow:** `detect_semantic_term_gaps`,
  `render_ontology_term_request`, `submit_term_request_issues`
- **NuSEDS:** `nuseds_enumeration_method_crosswalk`, `nuseds_estimate_method_crosswalk`
- **Darwin Core (DwC-DP):** `suggest_dwc_mappings`, `dwc_dp_build_descriptor`
- **Enterprise Data Hub (EDH):** `edh_build_hnap_xml`, `edh_build_iso19139_xml`,
  `write_edh_xml_from_sdp`
- **Semantic supplements:** `read_sssom_mapping_set`, `write_sdp_sssom`,
  `validate_sdp_sssom`, `read_sdp_measurement_decompositions`,
  `write_sdp_measurement_decompositions`, `validate_sdp_measurement_decompositions`
- **Extended structure and reproducibility:** `migrate_sdp_methods` (0.3.0
  replaced the `read_/write_/validate_sdp_methods` registry trio with this
  stop-and-report migration; metasalmonpy still has the trio until S10's 0.3.0
  rung),
  `read_sdp_observation_structures`, `write_sdp_observation_structures`,
  `validate_sdp_observation_structures`, `extract_sdp_observations`,
  `read_sdp_reproducibility_manifest`, `write_sdp_reproducibility_manifest`,
  `validate_sdp_reproducibility_manifest`
- **EML + KNB:** `write_eml_from_sdp`, `publish_sdp_to_knb`
- **GitHub:** `ms_setup_github`, `github_raw_url`, `read_github_csv`, `read_github_csv_dir`
- **ICES vocab:** `ices_code_types`, `ices_codes`, `ices_find_code_types`, `ices_find_codes`
- **Maintenance:** `check_for_updates`

Vignettes (11): `metasalmon`, `setup`, `llm-context-review`, `data-dictionary-publication`,
`post-review-package-publication`, `reusing-standards-salmon-data-terms`,
`github-csv-access`, `faq`, `glossary`, plus S11 slice 2's
`migrating-to-sdp-0-3-0` and `tidy-data-for-sdp`.

## Domain glossary

- **SDP (Salmon Data Package):** a folder with four canonical CSVs —
  `dataset.csv` (dataset-level metadata), `tables.csv` (per-table metadata incl.
  `observation_unit_iri`), `column_dictionary.csv` (per-column semantics), and
  `codes.csv` (controlled-vocabulary code values). Validated against the canonical
  `smn-data-pkg` spec.
- **SDP schema locations:** runtime schema fetches are pinned to the spec
  release tag the package implements
  (`https://raw.githubusercontent.com/salmon-data-mobilization/smn-data-pkg/<spec-tag>`,
  currently `sdp-0.3.0`; metasalmonpy still stamps `sdp-0.2.0` until S10's
  0.3.0 rung — parity register row 27); tracking `main` let upstream spec releases break
  networked loads. Advancing the pin is part of implementing a new spec
  version. Canonical SDP profile, rules, and resource-schema identifiers resolve at
  `https://salmon-data-mobilization.github.io/smn-data-pkg/`. Keep those
  published contract identifiers distinct from the configurable source used for
  runtime schema retrieval.
  The profile **identity is derived from the loaded bundle**
  (`schema$profile_uri` / `schema$rules_uri`, attached by
  `.ms_validate_sdp_schema()`), never asserted against a constant — that is what
  lets `metasalmon` follow a future upstream identifier change instead of
  failing on it. Validation checks only that the bundle agrees with itself:
  `$id` vs `properties.profile.const` vs `rules.profile` vs
  `sdp:version`/`rules.version`. The constants in `R/schema-helpers.R` are the
  vendored fallback only; keep them in step with `inst/extdata` by
  **re-vendoring from upstream**, not by hand-editing either side. Reading a
  package that declares an older profile URI stays valid (nothing on the read
  path inspects `datapackage.json$profile`).
  *History:* an earlier note here said the legacy `dfo-pacific-science.github.io`
  URI was the upstream contract value and must not be rewritten. Upstream
  migrated, 0.1.8 followed the value, and 0.2.0 removed the equality assertion
  that made such a migration fatal — see `knowledge/backlog.md` #33
  and #35.
- **DFO Salmon Ontology:** SKOS/OWL vocabularies. Namespaces: `smn` (shared,
  reusable salmon semantics) and `gcdfo` (DFO-specific operational/policy/program
  semantics). New-term proposals route to one of these by reusability.
- **KNB representation:** the preferred `expanded` representation publishes the
  closed, validated SDP inventory as named DataONE objects and records each
  package-relative path in OAI-ORE, so the canonical hierarchy can be rebuilt
  without a ZIP. The deterministic archive representation remains a compatibility
  option. EML and OAI-ORE complete either DataONE package. Private deposits are
  persistent staging records, not server-side drafts. Revisions require a fresh
  versioned SDP directory, preserve the metadata series, and link immutable
  EML/resource-map versions. Publication-specific EML sidecar authorization,
  party details, and mutable receipts are excluded from the published SDP.
  DOI minting is a separate KNB public-release action and is never implicit in
  `publish_sdp_to_knb()`.
- **Semantic publication boundary:** SSSOM records whole-concept mappings or
  explicit versioned no-match evidence. Ordered measurement components remain
  a separate SDP artifact. KNB planning accepts and archives reviewed records
  but rejects referenced vocabulary rows still labelled review-candidate. This
  offline string gate does not itself resolve IRIs or prove release governance;
  the transformation record must pin and verify the vocabulary release.
- **I-ADOPT decomposition:** measurement columns are decomposed into semantic
  "slots". The dictionary role → field map (`role_to_field` in
  `R/semantics-helpers.R`): variable→`term_iri`, property→`property_iri`,
  entity→`entity_iri`, unit→`unit_iri`, constraint→`constraint_iri`,
  statistical_modifier→`statistical_modifier_iri`. Multiple
  fixed constraints may be stored as a deterministic semicolon-delimited list;
  row-varying year/age coordinates belong in the optional observation-structure
  extension instead. **Ontology convention:** "method" is NOT a native I-ADOPT
  role, and since **sdp-0.3.0 it is not a dictionary slot either** — the
  dictionary has no `method_iri` and there is no `metadata/methods.csv`
  registry. A method now lands in one of three places: `tables.csv$method_iri`
  when it is constant for a table, a `codes.csv` term when it is a coded value,
  or a `sosa:usedProcedure` observation component when it varies by row. The
  slot the dictionary gained in its place is `statistical_modifier_iri`.
  Compound variables are SKOS concepts, not OWL classes (see the i-adopt
  chat-decomposition plan in `knowledge/plans/`).
- **`method` is still a *role* even though it is no longer a *slot*, and the
  two counts differ.** There are **6 dictionary slot roles**
  (`.ms_semantic_bundle_slot_fields()`, `R/semantic-bundle-review.R`) and
  **7 bundle/retrieval roles** (`.ms_semantic_bundle_roles()`, same file) —
  the six plus `method`, retained because codes-scope targets still search
  shared-vocabulary procedures for a `codes.csv` `term_iri`. Reading the
  sdp-0.3.0 note above as "method is gone" is the easy mistake: the dictionary
  slot is gone, the role is not.
- **The role contract spans seven surfaces, three of which this card used to
  omit.** Adding or renaming a role means touching all of them; `AGENTS.md`
  states the contract and this is the file map for it:

  | # | Surface | Where |
  |---|---|---|
  | 1 | Target/role maps | `role_to_field` (`R/semantics-helpers.R`), `R/semantic-suggestions.R` |
  | 2 | Bundle roles + slot fields | `R/semantic-bundle-review.R` |
  | 3 | **Role-hint vocabulary** | `.smn_role_flags` (`R/term_search_smn.R`), the RDF/XML hint builder in `R/term_search.R` |
  | 4 | Retrieval filters | `sources_for_role()`, `.gcdfo_filter_for_role()` (both `R/term_search.R`) |
  | 5 | Deterministic validators | `R/semantic-bundle-validators.R` |
  | 6 | Ranking preferences | `inst/extdata/ontology-preferences.csv` |
  | 7 | `role_boost` | `.ranking_profile_defaults()` (`R/term_search.R`) |

  **Assume an eighth exists** — the same role (`statistical_modifier`) has now
  failed two of these silently, which is the strongest available evidence the
  list is not closed.

  **Why surface 3 is the dangerous one.** `.ms_validate_semantic_role_type()`
  (`R/semantic-bundle-validators.R`) vetoes any accept whose candidate carries
  hints that do not name the role. So a role with **no hint emitter** has
  **100% of its correct accepts silently downgraded** to `review` — while every
  test using a hand-written `role_hints` fixture still passes. Nothing errors,
  nothing goes red, and the pipeline simply stops accepting anything for that
  role. That is exactly how sdp-0.3.0 shipped `statistical_modifier` broken
  through both CI and PR review.

  **Guard coverage is split and neither file covers all seven.**
  `tests/testthat/test-role-contract-guard.R` (9 `test_that` blocks) covers
  surfaces 1–6, reading the slot fields as the authority and inspecting emitter
  and filter *bodies*; keep its `hint_roles` and `hint_to_sources` lists
  current. Surface 7 is guarded in `tests/testthat/test-smn-outranks-gcdfo.R`,
  which asserts every ranked role has a `role_boost` entry — the role-contract
  guard does not mention `role_boost` at all.
- **`find_terms()` / `term_search`:** the deterministic ontology retrieval engine
  (`R/term_search.R` is ~96KB). `suggest_semantics()` calls it (default
  `search_fn = find_terms`) to build a per-target candidate shortlist before any
  LLM review. `sources_for_role()` selects vocab sources per role.
- **EDH (Enterprise Data Hub):** DFO metadata system; the package can emit HNAP /
  ISO 19139 XML from a reviewed SDP.
- **DwC-DP:** Darwin Core Data Package export path.
- **NuSEDS:** a DFO salmon escapement database; crosswalk helpers map its
  enumeration/estimate methods.
- **`REVIEW:` IRI prefix** (`metasalmon:::.ms_review_iri_prefix()`): marks IRIs
  that were auto-applied but still need human review; strict validation
  (`require_iris = TRUE`) fails if any remain. Asserted widely in tests.

## The semantic-review pipeline (the heart of the package)

`suggest_semantics()` (R/semantics-helpers.R) runs four stages:

1. **Target discovery** (`.ms_semantic_discover_targets()`): turns dict/codes/table_meta/
   dataset_meta into **semantic target rows** — one row per *empty* semantic slot
   needing an IRI. Fill-the-gaps, not overwrite. Does NOT call `search_fn` or any
   LLM; the extraction from `suggest_semantics()` landed in the architecture
   refactor.
2. **Retrieval:** `.ms_retrieve_semantic_target_candidates()` is the single call
   to `search_fn`. Produces a candidate shortlist per target.
3. **Role-collision annotation:** adds `role_collision` /
   `role_collision_note` columns (easy to forget when extracting stages).
4. **LLM review** (optional): `.ms_assess_semantic_suggestions_llm()`.
   Then results attach as the `semantic_suggestions` (always) and
   `semantic_llm_assessments` (when `llm_assess`) attributes on the returned dict.

**Semantic target row contract** — canonical 19 columns in
`.ms_semantic_target_cols()` (R/semantic-suggestions.R:1-23): `dataset_id`,
`table_id`, `column_name`, `code_value`, `dictionary_role`, `search_role`,
`target_scope`, `target_sdp_file`, `target_sdp_field`, `target_row_key`,
`target_label`, `target_description`, `search_query`, `target_query_basis`,
`target_query_context`, `column_label`, `column_description`, `code_label`,
`code_description`. `target_scope` ∈ {column, code, table, dataset}.
`target_row_key` is the slash-joined identity. Composite keys are `\r`-delimited
with NA rendered literally as `<NA>` (`.ms_semantic_key_df`) — compare keys with
the same encoding.

## LLM context-file subsystem (R/llm-semantic-helpers.R)

- **Strictly opt-in:** context is parsed and used ONLY when `llm_assess = TRUE`.
  Supplying `llm_context_files`/`llm_context_text` never enables network calls.
  This is the contract the 0.1.4 fix (issue #1) hardened.
- **Accepted input:** local file *paths* (character) or inline *text*. Passing an
  already-parsed object (tibble/XML/etc.) errors early
  (`.ms_validate_llm_context_files`).
- **Supported extensions** (single source of truth
  `.ms_supported_context_extensions`): md, txt, csv, tsv, json, yaml, yml, rst, r, rmd, qmd, pdf, htm, html,
  docx, xls, xlsx, xlsm.
- **Optional deps:** `pdftools` (PDF) and `readxl` (Excel) are Suggests; missing
  ones **abort with an actionable message** (not silent skip). `xml2` is a hard
  Import (docx/html).
- **Source labels:** unique basenames remain unchanged; colliding basenames are
  disambiguated with parent-directory context and then a numeric suffix if
  needed. Inline text uses `source = "inline_context"`. Labels propagate to the
  user-visible `llm_context_sources` column and are pinned by tests.
- **Parse-once invariant:** files are parsed once per assess run. The orchestrator
  builds one chunk pool and threads it as an explicit `context_chunk_pool`;
  `.ms_prepare_context_chunks()` no longer silently re-collects from source files.
- **Scoring:** deterministic bag-of-words token overlap (no embeddings).
  Tokens < 3 chars dropped, camelCase split. Chunk defaults 2200 chars / 200
  overlap.

## LLM review response contract / adapter (R/llm-review-adapter.R)

- `.ms_llm_review_validate_assessment` / `.ms_llm_review_response_data` is the
  **shared response contract** — and it is **already a two-consumer seam**:
  - semantic review: `.ms_llm_chat_json_request` returns a *bare* parsed-JSON list.
  - chat decomposition (`.ms_chat`, R/chat-decomposition.R): it returns a
    *wrapped* `list(content, data, ...)` shape.
  The adapter has a two-shape normalizer by design. (This matters: the
  `deepen-architecture` plan's Refactor 4 wrongly assumed a single review path.)
- Allowed decisions in `.ms_validate_llm_assessment`: `accept`, `review`,
  `retry_search`, `request_new_term`, `reject_shortlist` (+ `propose_new_term`
  aliases to `request_new_term`). Three auto-downgrades to `review`: accept without
  index, out-of-range index, retry_search without query.
- Assessment rows already carry `llm_retry_query`, `llm_new_term_label`,
  `llm_new_term_definition`, and `llm_new_term_namespace`. Direct
  `request_new_term` responses populate them, but the term-request workflow does
  not yet consume the parallel `semantic_llm_assessments` attribute; this is the
  remaining Theme A4 integration boundary.
- **Five distinct LLM review paths:** (1) generic single-target, (2) decomposition
  single-target (routed by `.ms_llm_should_route_to_decomposition`), (3) batch
  (two-layer fallback to per-target), (4) query-exploration re-review, (5)
  interactive chat decomposition. Paths 1–4 use the bare-JSON branch; path 5 uses
  the wrapped branch.
- **Provider-wide failure fallback:** if every assessment errors and none has a
  decision, `.ms_llm_abort_if_provider_wide_failure` falls back to the
  deterministic shortlist when usable, else aborts (added in 0.1.3).
- **LLM providers:** `openai`, `openrouter`, `openai_compatible`, `chapi` (DFO's
  internal Open WebUI; defaults to `ollama2.mistral:7b`). Env overrides:
  `CHAPI_API_KEY`, `CHAPI_MODEL`, `CHAPI_BASE_URL`.

## Known duplication map (drives the deepen-architecture refactors)

**Four of the five are resolved** (re-verified on `main`, 2026-08-17). Kept as a
map of where the duplication *was*, because the refactor plans still reference
these numbers:

1. ~~**`llm_requested` 8-clause predicate** duplicated across
   `dictionary-helpers.R` and `package-helpers.R`~~ — **resolved.** One
   definition, `.ms_llm_review_requested()` in `R/llm-semantic-helpers.R`,
   reached through `.ms_llm_review_plan()` from both callers. Backlog #15.
2. ~~**`suggest_semantics` arg-assembly** in effectively 4 copies~~ —
   **resolved.** `.ms_llm_review_plan()` builds the conditional `llm_*` tail
   once via `mget(.ms_llm_arg_names(), ...)`; all three call sites consume it
   as `c(suggest_args, llm_review$suggest_args)` — `R/dictionary-helpers.R:172`
   and `:234`, plus `R/package-helpers.R:836`. Backlog #14/#18.
3. **Effective shortlist** was never inline-duplicated — it lives once in
   `.ms_llm_effective_shortlist_size()` (`R/llm-semantic-helpers.R`) and is
   now called exactly **once**, from inside `.ms_llm_review_plan()`
   (`R/llm-semantic-helpers.R:177`). Item 2's consolidation removed the second
   call; this bullet said "called twice" until 2026-08-18.
4. ~~**Column-target row construction duplicated and divergent**~~ —
   **resolved.** Discovery lives once in `.ms_semantic_discover_targets()` and
   the row builder once beside it, both in `R/semantic-suggestions.R`; the
   inline block in `R/semantics-helpers.R` is gone.
5. **HTTP request-body builders duplicated — still live.**
   `.ms_llm_chat_json_request()` (`R/llm-semantic-helpers.R`) vs
   `.ms_chat_http_request()` (`R/chat-decomposition.R`), with divergent
   temperature/header handling. This is backlog **#3**, still open.

## Return-value attribute contracts (preserve across refactors)

- `infer_dictionary` **multi-table** path attaches `inferred_table_meta`,
  `inferred_codes`, `inferred_dataset_meta`, `inferred_resources`
  (R/dictionary-helpers.R; asserted in tests/testthat/test-dictionary-helpers.R).
- `infer_dictionary` **single-table** path attaches `seed_table_meta`,
  `seed_codes`, `seed_dataset_meta` — only when those args were non-NULL
  The two paths attach **disjoint** attribute sets.
- `suggest_semantics` attaches `semantic_suggestions` (always),
  `semantic_llm_assessments` (when `llm_assess`), optionally `dwc_mappings`.
  `semantic_suggestions` is read in `R/term-request-helpers.R`,
  `R/package-helpers.R` (two sites), `R/chat-decomposition.R`,
  **`R/semantics-helpers.R` — `apply_semantic_suggestions()`'s default
  `suggestions` argument, the public re-entry point and arguably the most
  load-bearing reader of the four** — and **11 test files**.

## Test infrastructure conventions

- **LLM injection hooks:** public `llm_request_fn=` (a `function(messages, config)`)
  and internal `request_fn=` (to `.ms_llm_resolve_config`). A `stop()`-ing fn is
  the standard sentinel proving the LLM was not called.
- **Retrieval injection:** `search_fn=` directly on `suggest_semantics()`. But
  `create_sdp`/`infer_dictionary` default `search_fn = find_terms`, so those paths
  need `with_mocked_bindings(find_terms = ...)`.
- `with_mocked_bindings(suggest_semantics = fake_suggest)` is the standard way to
  capture forwarded args and inject canned `semantic_suggestions` attributes.
- Results asserted via attributes and written `metadata/*.csv`, almost never via
  internal locals — EXCEPT the parse-once test in tests/testthat/test-llm-semantic-helpers.R
  which mocks `.ms_context_text_from_file` / `.ms_chunk_context_text` **by name**
  (a refactor hazard).
- Optional-dep formats gate with `skip_if_not_installed` (openxlsx/readxl/pdftools).
- `options(metasalmon.sdp_schema_source = "vendored")` (helper-validation.R) keeps
  schema validation offline.
- Network-gated tests: `fetch_salmon_ontology` (skip_if_offline w3id.org) and
  GitHub helpers (token/offline gated). These **skip silently** offline, so files
  relying on them can pass with reduced coverage.

## Build / test commands

```r
pkgload::load_all(".", quiet = TRUE)                 # fast reload during dev
testthat::test_file("tests/testthat/test-<area>.R", reporter = "summary")
devtools::document(); devtools::test(reporter = "summary")
system2("Rscript", "scripts/build-pkgdown.R")       # only when public docs change
```
```sh
git diff --check
R CMD build .
R CMD check <tarball>   # not currently in the plan's ladder; recommended pre-merge
```

`knowledge/` (and the residual `notes/evidence/`) is excluded from the build (`.Rbuildignore`), so planning artifacts here
do not affect the built package or pkgdown site.

## R/ file → responsibility map

Line counts recounted 2026-08-18 (`wc -l R/*.R`, 33.5k lines total). They drift
every release — re-run the count rather than trusting these to the digit.

| File | Lines | Responsibility |
|---|---|---|
| `package-helpers.R` | 3786 | SDP orchestration: `create_sdp`, `write_salmon_datapackage`, resource/codes/metadata inference, EDH post-processing. (God-file; split candidate.) |
| `knb-publication.R` | 3704 | Offline KNB plan, DataONE object/revision state machine, remote readback, access and catalog verification. |
| `eml-export.R` | 3001 | Strict reviewed EML 2.2.0 profile, stable series/version identifiers, and supplementary SDP-archive entities. |
| `term_search.R` | 2790 | Deterministic ontology retrieval (`find_terms`) + ranking; emits the role hints the role contract depends on. |
| `llm-semantic-helpers.R` | 2236 | LLM context parsing/scoring + review orchestration (single/batch/explore/decomposition routing); owns `.ms_llm_review_plan()`. |
| `dictionary-helpers.R` | 1578 | `infer_dictionary` + `infer_*_from_resources`, `apply_salmon_dictionary`. |
| `chat-decomposition.R` | 1380 | Interactive I-ADOPT decomposition session (`chat_decomposition`); 2nd consumer of the review contract. |
| `edh-xml-export.R` | 1293 | EDH HNAP/ISO 19139 XML export. |
| `term-request-helpers.R` | 1267 | Ontology new-term request rendering + issue submission. |
| `semantic-suggestions.R` | 1157 | Target discovery, the target/candidate row-shape contract, and LLM-assessment merge. |
| `sssom.R` | 1131 | Strict SSSOM 1.1 mapping-set serialization and manifest validation. |
| `observation-structures.R` | 1093 | Mixed-grain observation structures and `extract_sdp_observations`. |
| `semantics-helpers.R` | 1014 | `suggest_semantics` (retrieval, role-collision, LLM handoff) and the `role_to_field` map. |
| `semantic-bundle-review.R` | 936 | Bundle roles, slot fields, and the review prompt — **the role contract's authority**, read by the role-contract guard. |
| `semantic-bundle-validators.R` | 853 | Deterministic bundle validators, including the role-type veto. |
| `measurement-decompositions.R` | 849 | Ordered I-ADOPT-style component evidence kept separate from SSSOM mappings. |
| `github-helpers.R` | 638 | GitHub CSV access + auth setup. |
| `sdp-methods.R` | 582 | `migrate_sdp_methods()` — the 0.3.0 stop-and-report migration (this file no longer holds a registry read/write/validate trio). |
| `reproducibility-manifest.R` | 481 | Reproducibility manifest read/write/validate. |
| `knb-sdp-archive.R` | 479 | Closed, deterministic ZIP of canonical SDP data, metadata, SSSOM, and ordered decomposition artifacts. |
| `sdp-extension-helpers.R` | 415 | Shared helpers for the SDP extension artifacts. |
| `llm-review-adapter.R` | 272 | Shared LLM review response contract (validate / response-data / row construction); frozen ~30-col assessment row. |
| `cli-safety.R` | 103 | Escaping/redaction so external text never becomes a cli template (`.ms_cli_escape`, `.ms_cli_bullets`, `.ms_redact_secrets`). |
| `artifact-inference.R` | 101 | `infer_salmon_datapackage_artifacts()` — calls `infer_dictionary(seed_semantics = FALSE)`. |
| `provenance.R` | 68 | Single owner of the accepted writer set (`metasalmon::` / `metasalmonpy.`) for dual-provenance validation. Backlog #88. |
| `iri-predicates.R` | 34 | Single owner of the absolute-IRI shape used by **three** validators (EML PIDs, SSSOM references, SDP metadata extensions). The decomposition IRI predicate (`R/measurement-decompositions.R`) is deliberately **not** a caller — narrower shape, ASCII-only whitespace class, mirrored character-for-character in Python. Backlog #85. |
| `term-deduplication.R`, `nuseds-method-crosswalk.R`, `ices-vocab.R`, `dwc-dp-*.R`, `schema-helpers.R`, `validation_helpers.R`, `version-check.R`, `ontology_fetch.R`, `term_search_smn.R` | — | Supporting subsystems. |

## Planning artifacts (read before related work)

- **`knowledge/roadmap.md` — what to do next, in what order, and what blocks what.
  Start here.** Undated and edited in place; it links each stream to its
  execplan.
- `knowledge/backlog.md` — the live backlog and the single index of
  open items. Items #34+ came from the 2026-08-10 comprehensive review. Severity
  lives here; ordering lives in the roadmap.
- `knowledge/plans/2026-08-11-knb-environments-and-workshop-rebuild.md` — the
  KNB staging target and the workshop rebuild (roadmap S3/S4).
- `knowledge/plans/2026-08-10-post-0.2.0-roadmap.md` — superseded by
  `knowledge/roadmap.md`; kept as the record of how 0.2.1–0.2.4 were sequenced.
- `knowledge/plans/2026-08-10-comprehensive-ecosystem-review.md` — the 96
  verified findings behind that roadmap, covering metasalmon plus the SDP spec,
  both ontologies, and the workshop.
- `knowledge/plans/2026-08-10-gcdfo-validation-layer-verification.md` — the
  read-only verification of the gcdfo SHACL/SPARQL/ROBOT claims.
- `knowledge/plans/2026-06-26-next-behaviours-roadmap.md` — superseded for
  sequencing, still authoritative for the Theme A–E design detail.

## Related planning artifacts (read before LLM-review work)

- `knowledge/plans/2026-06-24-deepen-architecture-refactors.md` — the five
  deep-module refactors (peer-reviewed; see its Peer Review section).
- `knowledge/plans/2026-04-02-i-adopt-chat-decomposition-draft.md` — routes
  measurement targets through `chat_decomposition()`; **mandates one shared review
  route, not a second prompt stack.** This pre-decides Refactor 4 toward "deepen".
- `knowledge/plans/2026-04-02-llm-semantic-fit-retrieval-gap-escalation.md` —
  bundle-aware semantic fit + `retry_search`/`request_new_term` escalation. The
  review contract should be designed to absorb these richer outcomes.

## Reproducibility rules (added 2026-08-10, P0 remediation)

Two cross-cutting rules, both with a guard test. The full statements live in
`AGENTS.md`; this is the *why*.

**C collation.** `sort()`/`order()`/`dplyr::arrange()` are locale-sensitive by
default. Under `LC_COLLATE=en_CA` (a common macOS default),
`c("apple","Apple","B","_z","a")` orders as `_z a apple Apple B`; under C it is
`Apple B _z a apple`. Artifacts affected: the DataONE resource-map PID
(`.ms_knb_resource_map_pid()` UUID5 preimage), the plan fingerprint
(`plan_sha256`), SSSOM canonical bytes and the `mapping-sets.json` manifest
order, the measurement-decomposition CSV hash, EML entity order, the
`knb-manifest.json` receipt, and both exported NuSEDS crosswalk tables. Before
the fix, a curator on macOS could write an SSSOM set that a `LC_COLLATE=C` CI
container rejected, and the same package could get two different PIDs on two
machines. `dplyr::arrange()` needs `.locale = "C"` explicitly even on dplyr
>= 1.1.0, because its `NULL` default still consults the global
`dplyr.legacy_locale` option — so a user's `.Rprofile` could otherwise flip
hashed bytes. Hence `dplyr (>= 1.1.0)` in DESCRIPTION.
Guard: `tests/testthat/test-collation-guard.R`.

**cli message safety.** cli glue-interpolates every element of a condition
message vector, including named bullet elements — the name only selects the
glyph. Passing external text through means balanced braces are evaluated as R
code (a provider error containing `{Sys.getenv("OPENAI_API_KEY")}` prints the
key) and an unbalanced brace is a parse error (a column named `rate{pct` made
validation die with `Expecting '}'`). `R/cli-safety.R` holds
`.ms_cli_escape()`, `.ms_cli_bullets()`, `.ms_redact_secrets()`, and
`.ms_abort_external()`. Escaping rather than value interpolation, because
`"x" = "{preview}"` collapses an N-element preview into one comma-joined bullet.
Redaction belongs where text is captured, not displayed: `assessments$llm_error`
is returned to the caller and can be written to `semantic_suggestions.csv`.
Guard: `tests/testthat/test-cli-safety-guard.R`.

## Gotchas

- ~~`CLAUDE.md` and `AGENTS.md` both contain only `@AGENTS.md`~~ — **fixed**
  (backlog #9). `AGENTS.md` now carries the real contract; `CLAUDE.md` is the
  one-line `@AGENTS.md` include, which is a pointer, not a self-reference.
- On the `create_sdp` path, `infer_dictionary` is called with
  `seed_semantics = FALSE` (now `R/artifact-inference.R`, not
  `package-helpers.R`), so `infer_dictionary`'s own arg-assembly and metadata
  blocks are **dead on that path** and only execute when `infer_dictionary` is
  called directly. ~~which is why the 0.1.4 fix landed only in package-helpers
  and a parallel gap remains in dictionary-helpers~~ — **that gap is closed:**
  `.ms_llm_review_plan()` runs `.ms_validate_llm_context_files()` and
  `.ms_warn_if_llm_semantic_options_ignored()` for *both* entry points, so the
  opt-in contract and the ignored-options warning are single-sourced.
