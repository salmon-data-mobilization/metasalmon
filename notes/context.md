# metasalmon — project context

Durable orientation notes for working on this package. Captures facts that are
expensive to re-derive from the (large) source files. Keep this current as the
package evolves. Last substantial update: 2026-07-21 (post-0.1.5 canonical URL
hardening and released-feature documentation refresh).

## What the package is

`metasalmon` is an R package that scaffolds, standardizes, validates, transforms,
and packages salmon datasets using the **DFO Salmon Ontology** and **Salmon Data
Package (SDP)** conventions. Development version 0.1.5.9000. License MIT.
R >= 4.1.0.

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
  └─ infer_salmon_datapackage_artifacts()   # the orchestrator (R/package-helpers.R:427)
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
- **GitHub:** `ms_setup_github`, `github_raw_url`, `read_github_csv`, `read_github_csv_dir`
- **ICES vocab:** `ices_code_types`, `ices_codes`, `ices_find_code_types`, `ices_find_codes`
- **Maintenance:** `check_for_updates`

Vignettes: `metasalmon`, `setup`, `llm-context-review`, `data-dictionary-publication`,
`post-review-package-publication`, `reusing-standards-salmon-data-terms`,
`github-csv-access`, `faq`, `glossary`.

## Domain glossary

- **SDP (Salmon Data Package):** a folder with four canonical CSVs —
  `dataset.csv` (dataset-level metadata), `tables.csv` (per-table metadata incl.
  `observation_unit_iri`), `column_dictionary.csv` (per-column semantics), and
  `codes.csv` (controlled-vocabulary code values). Validated against the canonical
  `smn-data-pkg` spec.
- **SDP schema locations:** runtime schema fetches use
  `https://raw.githubusercontent.com/salmon-data-mobilization/smn-data-pkg/main`.
  The SDP 0.2 profile and resource-schema identifiers still contain the former
  `dfo-pacific-science.github.io/smn-data-pkg` URI because that value is part of
  the current upstream profile contract; do not rewrite it independently in
  `metasalmon`.
- **DFO Salmon Ontology:** SKOS/OWL vocabularies. Namespaces: `smn` (shared,
  reusable salmon semantics) and `gcdfo` (DFO-specific operational/policy/program
  semantics). New-term proposals route to one of these by reusability.
- **I-ADOPT decomposition:** measurement columns are decomposed into semantic
  "slots". The dictionary role → search role map (R/semantics-helpers.R:381-388):
  `term_iri`→variable, `property_iri`→property, `entity_iri`→entity,
  `unit_iri`→unit, `constraint_iri`→constraint, `method_iri`→method. **Ontology
  convention:** "method" is NOT a native I-ADOPT role — procedure context is
  modeled as `gcdfo:usedProcedure`, and compound variables are SKOS concepts, not
  OWL classes (see the i-adopt chat-decomposition plan in `notes/exec-plans/`).
- **`find_terms()` / `term_search`:** the deterministic ontology retrieval engine
  (`R/term_search.R` is ~89KB). `suggest_semantics()` calls it (default
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

`suggest_semantics()` (R/semantics-helpers.R:312-1218) runs four stages:

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

## LLM context-file subsystem (R/llm-semantic-helpers.R ~270-690)

- **Strictly opt-in:** context is parsed and used ONLY when `llm_assess = TRUE`.
  Supplying `llm_context_files`/`llm_context_text` never enables network calls.
  This is the contract the 0.1.4 fix (issue #1) hardened.
- **Accepted input:** local file *paths* (character) or inline *text*. Passing an
  already-parsed object (tibble/XML/etc.) errors early (`.ms_validate_llm_context_files`
  at :441).
- **Supported extensions** (single source of truth `.ms_supported_context_extensions`
  at :270): md, txt, csv, tsv, json, yaml, yml, rst, r, rmd, qmd, pdf, htm, html,
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
  - chat decomposition (`R/chat-decomposition.R:615`): `.ms_chat` returns a
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

Verified copy-paste that the refactor plan targets:

1. **`llm_requested` 8-clause predicate** — byte-identical at
   `dictionary-helpers.R:92-99` and `package-helpers.R:452-459`.
2. **`suggest_semantics` arg-assembly** (base list + `if (llm_requested)` append
   of 11 `llm_*` args + `do.call`) appears **3×**: `package-helpers.R:541-566`,
   `dictionary-helpers.R:171-195`, `dictionary-helpers.R:247-271`. The 11-arg
   `llm_*` surface also appears as a call-site at `create_sdp` (`package-helpers.R:844-854`)
   → effectively **4 copies**.
3. **Effective shortlist** is NOT inline-duplicated — it lives once in
   `.ms_llm_effective_shortlist_size` (R/llm-semantic-helpers.R:79-93) and is
   merely *called* twice. (So Refactor 2's "centralize shortlist" is mostly done.)
4. **Column-target row construction is duplicated and divergent:**
   `.ms_semantic_column_term_target_from_dictionary` (R/semantic-suggestions.R:147-185)
   vs the inline block (R/semantics-helpers.R:966-984).
5. **HTTP request-body builders duplicated:** `.ms_llm_chat_json_request`
   (R/llm-semantic-helpers.R:1301-1330) vs `.ms_chat_http_request`
   (R/chat-decomposition.R:435-472) — divergent temperature/header handling.

## Return-value attribute contracts (preserve across refactors)

- `infer_dictionary` **multi-table** path attaches `inferred_table_meta`,
  `inferred_codes`, `inferred_dataset_meta`, `inferred_resources`
  (dictionary-helpers.R:196-199; asserted at test-dictionary-helpers.R:308-311).
- `infer_dictionary` **single-table** path attaches `seed_table_meta`,
  `seed_codes`, `seed_dataset_meta` — only when those args were non-NULL
  (272-280). The two paths attach **disjoint** attribute sets.
- `suggest_semantics` attaches `semantic_suggestions` (always),
  `semantic_llm_assessments` (when `llm_assess`), optionally `dwc_mappings`.
  `semantic_suggestions` is read in term-request-helpers.R:82,
  package-helpers.R:568/859, chat-decomposition.R:961, and ~20 tests.

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
  internal locals — EXCEPT the parse-once test (test-llm-semantic-helpers.R:1100-1136)
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
pkgdown::build_site()                                # only when public docs change
```
```sh
git diff --check
R CMD build .
R CMD check <tarball>   # not currently in the plan's ladder; recommended pre-merge
```

`notes/` is excluded from the build (`.Rbuildignore`), so planning artifacts here
do not affect the built package or pkgdown site.

## R/ file → responsibility map

| File | Lines | Responsibility |
|---|---|---|
| `package-helpers.R` | ~2975 | SDP orchestration: `infer_salmon_datapackage_artifacts`, `create_sdp`, `write_salmon_datapackage`, resource/codes/metadata inference, EDH post-processing. (God-file; split candidate.) |
| `term_search.R` | ~89KB | Deterministic ontology retrieval (`find_terms`) + ranking. |
| `semantics-helpers.R` | ~1552 | `suggest_semantics` (target discovery, retrieval, role-collision, LLM handoff). |
| `llm-semantic-helpers.R` | ~1692 | LLM context parsing/scoring + review orchestration (single/batch/explore/decomposition routing). |
| `chat-decomposition.R` | ~1346 | Interactive I-ADOPT decomposition session (`chat_decomposition`); 2nd consumer of the review contract. |
| `dictionary-helpers.R` | ~1209 | `infer_dictionary` + `infer_*_from_resources` (the latter also used by package-helpers). |
| `semantic-suggestions.R` | ~268 | Target/candidate row-shape contract + LLM-assessment merge. |
| `llm-review-adapter.R` | ~118 | Shared LLM review response contract (validate / response-data / row construction). |
| `edh-xml-export.R` | ~43KB | EDH HNAP/ISO 19139 XML export. |
| `github-helpers.R` | ~22KB | GitHub CSV access + auth setup. |
| `term-request-helpers.R` | ~28KB | Ontology new-term request rendering + issue submission. |
| `term-deduplication.R`, `nuseds-method-crosswalk.R`, `ices-vocab.R`, `dwc-dp-*.R`, `schema-helpers.R`, `validation_helpers.R`, `version-check.R`, `ontology_fetch.R`, `term_search_smn.R` | — | Supporting subsystems. |

## Related planning artifacts (read before LLM-review work)

- `notes/exec-plans/2026-06-24-deepen-architecture-refactors.md` — the five
  deep-module refactors (peer-reviewed; see its Peer Review section).
- `notes/exec-plans/2026-04-02-i-adopt-chat-decomposition-draft.md` — routes
  measurement targets through `chat_decomposition()`; **mandates one shared review
  route, not a second prompt stack.** This pre-decides Refactor 4 toward "deepen".
- `notes/exec-plans/2026-04-02-llm-semantic-fit-retrieval-gap-escalation.md` —
  bundle-aware semantic fit + `retry_search`/`request_new_term` escalation. The
  review contract should be designed to absorb these richer outcomes.

## Gotchas

- `CLAUDE.md` and `AGENTS.md` both contain only `@AGENTS.md` — `AGENTS.md`
  self-references, so the project effectively ships **no agent instructions**
  (and the include is a circular reference). See `notes/bugs-and-improvements.md`.
- On the `create_sdp` path, `infer_dictionary` is called with
  `seed_semantics = FALSE` (package-helpers.R:499), so `infer_dictionary`'s own
  `llm_requested`/arg-assembly/metadata blocks are **dead on that path** and only
  execute when `infer_dictionary` is called directly — which is why the 0.1.4 fix
  landed only in package-helpers and a parallel gap remains in dictionary-helpers.
