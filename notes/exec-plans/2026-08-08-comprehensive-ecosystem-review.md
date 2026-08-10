# Comprehensive review — metasalmon + Salmon data-standards ecosystem

Date: 2026-08-08. Reviewed at `metasalmon` 0.1.7 / `main` @ `01eacb7`.

Scope: the `metasalmon` R package plus the four ecosystem artefacts it depends on —
the **Salmon Domain Ontology** (`smn:`), the **GC DFO Salmon Ontology** (`gcdfo:`),
the **Salmon Data Package specification** (`smn-data-pkg`), and the **workshop
materials** (`salmon-data-standards-workshop`, with `salmon-ontology-hub` as the
community docs surface).

---

## 0. Method, and how much to trust each finding

Two multi-agent audits: 6 finder agents per audit across separate dimensions, then
one adversarial verifier per finding instructed to **refute by default**. 145 raw
findings → 96 survived verification → 22 refuted → 27 lost their verifier.

| Finding set | Raw | Verified | Refuted | Verifier lost |
|---|---|---|---|---|
| metasalmon internals (6 dimensions) | 67 | **59** | 8 | 0 |
| SDP spec / workshop / cross-repo / governance | 78 | **37** | 14 | 0 |
| `smn:` + `gcdfo:` ontologies | 27 | — | — | **27** |

> **Trust caveat.** The 27 ontology findings in §5 and §6 are **finder-verified
> only**. Their adversarial verification pass died on an org monthly spend limit.
> They cite file:line and read convincingly, but *confirm each one before acting*.
> Everything in §1–§4 and §7 has been through refute-by-default verification.

**Independently confirmed by me, in this session** (not agent-reported):

- Full suite: **0 failures**, 9 skips (4 Theme A integrity, 3 `{dataone}`, 2
  `{datapack}` not installed). Runtime ~4 min.
- `R CMD check` (`--no-manual --no-vignettes`, `_R_CHECK_FORCE_SUGGESTS_=false`):
  **0 NOTEs, 0 real warnings**. The 2 warnings emitted are artefacts of my
  no-vignette build. This is a genuinely clean check — better than most packages
  this size.
- `zip` on CRAN is **3.0.2**; `DESCRIPTION` pins `zip (== 3.0.1)` (item P0-1).
- The remote SDP schema loader **aborts today** (item P0-2), proven by running it.
- Deterministic inference scales fine: `infer_dictionary()` is 0.16 s at 240
  columns, 1.66 s at 50k rows. **The deterministic path is not the bottleneck** —
  §4 is entirely about the retrieval/LLM path.

**Overall judgement.** This is a strong, unusually disciplined codebase: 28k lines
of R against 21k lines of tests, a clean check, real architectural notes, and
genuine engineering rigour in the KNB/EML determinism work. The problems cluster in
three places: (a) **a small number of silent data-corruption bugs on the ordinary
user path**, (b) **the retrieval layer has no working cache, making real-world
semantic runs impractically slow**, and (c) **the ecosystem's contracts have drifted
apart** — metasalmon, the spec, and the ontologies each believe something different
about identifiers, versions, and who validates what.

---

## 1. RANKED PRIORITY LIST

Ranked by (breaks a real workflow today) × (silent vs loud) × (cost to fix).
`[V]` = adversarially verified. `[F]` = finder-only, verify first.

### P0 — do these first (silent corruption, install blockers, security)

| # | Item | Where | Why now | Est. |
|---|---|---|---|---|
| P0-1 | **`Imports: zip (== 3.0.1)` blocks installation.** CRAN ships 3.0.2, so a fresh `install_github()` cannot satisfy the dependency. The determinism requirement is already enforced at runtime by `.ms_knb_require_zip_version()` — the DESCRIPTION pin is redundant *and* fatal. Relax to `zip (>= 3.0.1)`; keep the runtime guard. `[V]` | `DESCRIPTION:35`, `R/knb-sdp-archive.R:11` | Nobody can install the package. | 15 min |
| P0-2 | **Remote SDP schema loading is dead; produced packages declare a rejected profile IRI.** Upstream migrated every `$id`/`const` to `salmon-data-mobilization.github.io`; `schema-helpers.R` still asserts equality against `dfo-pacific-science.github.io`, so `source="remote"` hard-errors and `"auto"` warns once and silently falls back to the stale vendored bundle. Invisible to tests because `helper-validation.R` pins `source="vendored"`. `[V + proven]` | `R/schema-helpers.R:6,10,14,174`; `inst/extdata/**` | Every `datapackage.json` written today carries a URI the current upstream profile's `const` rejects. Bug #33's "upstream still defines the legacy URI" decision is now **factually stale**. | 3–4 h |
| P0-3 | **`.data$x == x` data-mask no-op silently applies the wrong table's rules.** In `apply_salmon_dictionary()` the local and the column share a name, so the filter is a tautology: a multi-table dictionary (the normal output of `infer_dictionary(list)` / `read_salmon_datapackage()`) is applied **in full** — other tables' renames, coercions and factor levels — while the warning says the opposite. Same pattern in `write_salmon_datapackage()`'s `dataset_id` filter. Fix with `.env$` pinning and **grep the package for the pattern**. `[V]` | `R/dictionary-helpers.R:1096,1167`; `R/package-helpers.R:128` | Silent data corruption on a documented path. | 2–3 h |
| P0-4 | **`create_sdp()` writes packages its own validator rejects.** Data resources are read back with readr type guessing while `codes.csv` is forced to character, then compared with `as.character()`. `"0.10"` → `0.1`, `100000` → `"1e+05"`. Reproduced: `create_sdp()` succeeds, `validate_salmon_datapackage()` then aborts on its own output. `write_eml_from_sdp()` inherits it. `[V]` | `R/package-helpers.R:1147,1772` | The headline workflow fails on itself. | 3–4 h |
| P0-5 | **`read → modify → write` silently deletes the SSSOM and decomposition sidecars.** `write_salmon_datapackage(overwrite=TRUE)` `unlink()`s reviewed `metadata/semantic/**`, the mapping-set manifest, ordered decompositions and the review report. Nothing warns; validation still passes afterwards, so the loss surfaces at publication. `[V]` | `R/package-helpers.R:327` | Destroys hours of curation work. | 4–6 h |
| P0-6 | **Model-controlled text is evaluated as R code, and can print the API key.** The provider-wide failure warning passes remote error text straight into a `cli` format string; a balanced `{...}` in that text is evaluated — `{Sys.getenv("OPENAI_API_KEY")}` prints the key. An `escape_braces()` helper already exists 65 lines above. Prompt-injection reachable. `[V]` | `R/llm-semantic-helpers.R:1960` (helper at `:1895`) | Credential disclosure + arbitrary evaluation from remote input. | 1 h |
| P0-7 | **SSSOM ordering is locale-dependent → cross-machine validation failure and non-deterministic archive bytes.** `sort()`/`order()` on character without `method="radix"`. A curator on `en_US.UTF-8` writes a set that a `LC_COLLATE=C` CI container rejects — and regenerating it changes the ZIP bytes, breaking the KNB determinism contract the 0.1.7 work exists to guarantee. `[V]` | `R/sssom.R:303,760,925,1090` | Directly undermines the reviewed-archive determinism contract. | 2 h |
| P0-8 | **Cancelling the term-request confirmation prompt submits the issue.** `utils::askYesNo()` returns `NA` on cancel and the guard treats `NA` as proceed. Files a real GitHub issue against a shared ontology repo when the user said no. `[V]` | `R/term-request-helpers.R:1086` | Irreversible outward-facing side effect against user intent. | 30 min |
| P0-9 | **`[F]` The gcdfo validation layer is entirely inert.** SHACL shapes, example data and competency-question SPARQL all use `dfo:`/`:` prefixes for a namespace that is not `https://w3id.org/gcdfo/salmon#`, so `pyshacl` returns a vacuous `conforms: true`; and `robot-quality-check.sh` uses a custom profile that disables every failing check, so CI is green over 124 uncaught violations. **Verify first**, then fix. | `dfo-salmon-ontology/ontology/shapes/dfo-salmon-shapes.ttl:7`; `robot-profile.yaml` | Both documented quality gates are placebos. | 1–2 d |

### P1 — high value, next (performance cliffs, workflow blockers, enforcement gaps)

| # | Item | Where | Est. |
|---|---|---|---|
| P1-1 | **The term-search index cache never prevents work.** `.smn_term_index()` re-fetches 11 SMN Turtle modules and fully re-parses them on **every** `find_terms()` call (~5.7 s each), and `.gcdfo_term_index()` fetches *before* consulting its cache. Measured projection: a 5-table × 200-column package (~5,000 targets) costs ~8 CPU-hours and ~55,000 round-trips before doing anything useful; a 30-column table pays ~17 min of pure re-parsing. On a network where `w3id.org` hangs, each call can burn 90 s+ and the run looks dead. **Fix: memoize `fetch_salmon_ontology()` per session; hoist the stamp check above the fetch.** `[V]` | `R/term_search.R:1570,1610` | 1–2 d |
| P1-2 | **`METASALMON_CACHE` is read at build time**, so `.metasalmon_cache_enabled` is frozen when the package is installed and the `find_terms()` result cache can never be enabled in an installed package. Move to `.onLoad`/lazy read. Compounds P1-1. `[V]` | `R/term_search.R:396` | 1 h |
| P1-3 | **`publish_sdp_to_knb()` cannot re-plan after any edit.** The archive and EML writers are called with `overwrite = FALSE` and there is no override, so every dry run after a corrected `eml-mapping.yml` aborts until the user works out they must manually `unlink()` derived artefacts. Neither message says so. `[V]` | `R/knb-publication.R:1311` | 3 h |
| P1-4 | **Three error-severity rules in `sdp.rules.yaml` are loaded and never executed** (codes required for categorical columns; `code_value`/`vocabulary_iri` presence; descriptor-vs-CSV agreement). metasalmon is the workshop's designated final gate before DataONE deposit. Drive the checks from the parsed rule `id`s so spec and implementation cannot silently diverge. `[V]` | `R/schema-helpers.R:182` | 1–2 d |
| P1-5 | **`validate_salmon_datapackage()` checks far less than it claims** — no declared primary keys, no required-column nullability, no schema-required metadata fields, and it reports success on a package whose SSSOM/decomposition artefacts are corrupt despite documenting itself as the end-to-end pre-flight. `[V]` | `R/package-helpers.R:1295,1721` | 2–3 d |
| P1-6 | **HTTP failures from vocabulary APIs are reported as successful zero-result searches**, so a degraded OLS/BioPortal looks like "no ontology term exists" and drives spurious `request_new_term` escalation. `[V]` | `R/term_search.R:505` | 4 h |
| P1-7 | **No retry or rate-limit handling for the default LLM providers**; `Retry-After` is ignored and the retry classifier is unreachable. `[V]` | `R/llm-semantic-helpers.R:196` | 1 d |
| P1-8 | **BioPortal API key is in the request URL** and printed verbatim in timeout warnings. Move to a header; redact in messages. `[V]` | `R/term_search.R:713` | 1 h |
| P1-9 | **`[F]` `smn:` normative build asserts `owl:equivalentClass` against SOSA and Darwin Core** while simultaneously stating the same pairs as Tier-3 mappings — violating the repo's own mapping-strength policy. Anyone importing `w3id.org/smn` alongside real SOSA/DwC inherits false equivalences (SOSA observations of abiotic properties become occurrence records). Downgrade to the `skos:closeMatch` already present in `alignment-main.ttl`. | `salmon-domain-ontology/ontology/modules/06-data-interoperability.ttl:22` | 2 h + review |
| P1-10 | **`[F]` `sosa:Property` does not exist in SOSA/SSN.** The entire `smn:Characteristic` hierarchy (14 descendants) and the I-ADOPT Property bridge hang off an invented IRI in W3C's namespace, so no SOSA-aware reasoner relates them to `sosa:ObservableProperty`. Occurs in 5+ files. Replace with `ssn:Property` or `sosa:ObservableProperty`. | `salmon-domain-ontology/ontology/modules/02-observation-measurement.ttl:28` | 1 d |
| P1-11 | **`[F]` `smn:observedTaxonSpecies` has `rdfs:range obo:NCBITaxon_8018`** — chum salmon. Every coho or chinook observation using it entails "is chum". Data-corrupting entailment in a five-species integration ontology. Set the range to Salmonidae or drop it. | `salmon-domain-ontology/ontology/modules/02-observation-measurement.ttl:275` | 1 h |

### P2 — correctness and conformance debt

- **`infer_column_role()` classifies 4-digit measurement columns as `temporal`**, removing them from the whole semantic pipeline. Any `count_1000`-style or year-like measurement column silently loses its semantics. `R/dictionary-helpers.R:765` `[V]`
- **Canonical CSV round-trip destroys literal `"NA"` code values.** Data resources written with readr's default `na="NA"`, metadata with `na=""`, everything read with `na=c("","NA")`. "NA" is a real fisheries code ("not applicable"). Pin the missing-value contract symmetrically on both sides. `R/package-helpers.R:124,245` `[V]`
- **`apply_salmon_dictionary(strict=TRUE)` never errors on the common coercion failures**, and the codes step silently `NA`s unlisted values. `R/dictionary-helpers.R:1149` `[V]`
- **DataONE resource-map PID and plan fingerprint are locale-dependent** (same `sort()` class as P0-7). `R/knb-publication.R:380` `[V]`
- **`dwc_dp_build_descriptor(validate=TRUE)` discards the validation result**, and the required external Python toolchain is not declared in `SystemRequirements`. `R/dwc-dp-export.R:46` `[V]`
- **Semantic retrieval issues one serial `search_fn()` call per target with no deduplication** of identical `(query, role, sources)` tuples. `R/semantics-helpers.R:493` `[V]`
- **`llm_top_n` cannot widen the shortlist on the direct `suggest_semantics()` path**, so the documented default of 5 silently becomes 3. `R/semantics-helpers.R:411` `[V]`
- **`find_terms()` dereferences `parallel::mclapply` results without checking for worker failure**, aborting the whole run. `R/term_search.R:311` `[V]`
- **`.data$col %||% ""` cannot guard a missing column**: ICES helpers error instead of degrading. `R/ices-vocab.R:90` `[V]`
- **Composite-intent gate: `optional_hint_fields` is inert** and the WSP/`cu_timeseries` rule is hardcoded, so any "composite" text aborts validation. `R/package-helpers.R:1983` `[V]`
- Blank `dataset_id`/`table_id` in `codes.csv` returns all-NA rows instead of no rows (`R/semantic-suggestions.R:920`); an all-empty column is typed `boolean` (`R/dictionary-helpers.R:613`); a custom `search_fn` missing `role`/`match_type` aborts with an opaque dplyr error (`R/semantics-helpers.R:510`). `[V]`
- **Low-value-per-call perf**: ranking re-reads two CSVs per `find_terms()` call (`term_search.R:1763`); `.iadopt_vocab()` re-parses a bundled CSV with per-row `httr::parse_url` (`:341`); ontology-preference scoring recompiles a regex per cell (`:2190`); context chunks re-tokenized per target (`llm-semantic-helpers.R:718`); target discovery rescans the full dictionary per (row, role) and per code row (`semantic-suggestions.R:863,920`). Individually small, but they multiply by the target count. `[V]`

### P3 — R-package and API hygiene

- **No condition classes anywhere**: 415 `cli_abort` + 38 `cli_warn` + 3 `rlang::abort`, all unclassed. Callers cannot `tryCatch` selectively — a real problem for a package meant to be driven from scripts and agents. Add a small class hierarchy (`metasalmon_error`, `..._validation_error`, `..._llm_error`, `..._publication_error`). `[V]`
- **Nine `metasalmon.*` options and fourteen environment variables are undocumented** — no registry, no `.onLoad` defaults, no help topic. `[V]`
- **Global-state mutation**: `.search_bioportal()` permanently writes a "already warned" flag into the user's `options()`; `.ms_chat_new_session_id()` calls `sample()` and advances the user's RNG stream. Both are CRAN-policy violations. `[V]`
- **`NAMESPACE` blanket-imports the superseded `httr`** (`import(httr)`) while `httr2` is also a hard Import — two HTTP stacks, and every `httr` use is already fully qualified. Drop the blanket import; plan the `httr` → `httr2` migration (21 vs 57 call sites). `[V]`
- **22 of 30 documented topics wrap the entire example in `\dontrun{}`**, including examples that run offline in under a second, so `R CMD check` validates almost no public example code. **15 of 45 exports ship no examples at all.** `[V]`
- **`DESCRIPTION` has a hand-written `Author:` field naming an author absent from `Authors@R`** — generated metadata and citation silently disagree. `[V]`
- `.Rbuildignore` regex `^\.tmp$` never matches; the untracked 1.5 MB `tmp/` is excluded by neither ignore file. `[V]`
- **`AGENTS.md`/`CLAUDE.md` are git-ignored and were never committed** — the shipped repo still has no agent guidance, so backlog item #9 is only locally fixed. `[V]`
- **API surface**: no documented naming convention (`create_sdp` / `write_salmon_datapackage` / `write_sdp_sssom` / `ms_setup_github` / `edh_build_hnap_xml` / `ices_codes` — six shapes); `metasalmon_sssom_mapping_set` is the only classed return value and has no `print`/`format` method; the rich `semantic_suggestions` / `semantic_llm_assessments` payloads are **attributes with no accessor**; resuming an interrupted `chat_decomposition()` is undiscoverable. `[V]`
- **SDP schema loads from mutable upstream `main` by default**; the only pinning option is documented nowhere user-facing. `[V]`

### P4 — ecosystem: spec, workshop, ontology, governance

Detailed in §3–§7. The highest-leverage five:

1. **Vocabulary-release pinning is impossible today** — and metasalmon's own KNB documentation states the transformation record *must* pin and verify the vocabulary release. `gcdfo` publishes a rolling `0.0.999` sentinel version IRI and deleted its `0.0.8` release; `smn`'s published serializations drop `owl:versionIRI` entirely. **The ecosystem cannot currently satisfy its own publication precondition.**
2. **`datapackage.json` is semantically empty** — the SDP reference validator's field builder drops every IRI (`term_iri`, `unit_iri`, the five I-ADOPT slots) and a strict equality check actively *forbids* adding them. Every "semantic querying / linked data / cross-dataset linking" claim is unreachable from the published descriptor. Table Schema's `rdfType` exists for exactly this.
3. **The `smn:`/`gcdfo:` boundary is not machine-checkable** — 55 same-named term pairs across the two ontologies with no import, no equivalence axiom, no deprecation, and no SSSOM mapping set. metasalmon's "route new-term proposals by reusability" rule has no decidable input, and an SDP can cite either IRI.
4. **No episode code in the workshop is executable** — seven `.Rmd` files contain zero knitr chunks, and the lesson-requirements lockfile omits `metasalmon`. The R and Python setup paths are guaranteed to install different versions, breaking the parity claim the lesson rests on.
5. **`smn-data-pkg` has no LICENSE, no CI, and no GitHub Pages configuration** — while two MIT-licensed libraries redistribute its files and the profile identity assumes a live Pages site.

---

## 2. metasalmon — notes beyond the ranked list

**What's genuinely good, and should not be traded away:** the deterministic-archive
and immutable-revision work in 0.1.7 is serious engineering; the Theme A evidence
harness (replay/live/compare/promote with commit-bound artefact hashing) is better
than most research software ever gets; the strictly-opt-in LLM contract holds — the
audit specifically hunted for a path where supplying context files triggers a
network call and **found none**; test-to-source ratio is 0.75; the check is clean.

**The structural theme worth naming:** the package now has *two* validation
authorities that disagree — the shipped vendored schema bundle and the upstream
spec — and *three* places that decide what a valid package is (`sdp.rules.yaml`,
`.ms_collect_package_validation_issues()`, and the reference Python validator in
`smn-data-pkg`). P0-2, P1-4 and P1-5 are all symptoms of that. The durable fix is
to make the rule set data-driven from the upstream `id`s, with a conformance test
that fails when the spec declares a rule the implementation does not execute.

**Refuted, for the record** (don't chase these): the `fetch_salmon_ontology()` 304
cache-wipe; warnings-escalated-to-abort in the live publication block;
`.ms_eml_attribute_configs()` re-derivation; `library(metasalmon)` failing on the
zip pin (it's *install*-time, not load-time — P0-1 is still real); the
`getFromNamespace("auth_get")` reach into `dataone`; single-platform CI vs POSIX-only
guards; the `eml-mapping.yaml` extension trap; `create_sdp()` discarding the LLM
audit trail.

---

## 3. Salmon Data Package specification (`smn-data-pkg`)

All `[V]`.

1. **No declared Frictionless generation.** Artefacts mix v1 and custom
   conventions: Table Schemas cite `specs.frictionlessdata.io` (v1), `profile.json`
   is JSON Schema draft-07 (published v1 profiles are draft-04), and conformance
   keys entirely off `profile` — **deprecated on both Package and Resource in Data
   Package Standard v2**, where `tabular-data-resource` no longer exists. Add a
   *Normative references* section naming one target, and an ADR for the v2 path
   (`$schema`). Mitigating: the documented conformance path is the repo's own
   `validate_package.py`, which doesn't depend on Frictionless tooling — so this is
   a third-party-implementer and forward-compat gap, not a functional break.
2. **The descriptor discards every semantic field** (see §1 P4-2). `severity: medium`
   understates its strategic cost.
3. **Nine normative prose rules are enforced nowhere** — identifier syntax
   (`SPECIFICATION.md:85-86`, no `pattern` constraint anywhere), `dataset_id`
   uniqueness, `table_id`/`column_name` scoped uniqueness, codes referential
   integrity. `sdp.rules.yaml` carries only `id`/`severity`/`description` — it is
   documentation wearing a schema's clothes.
4. **The reference validator enforces a hard-coded two-license allowlist** that
   appears in no schema, rule, or spec text.
5. **Everything the reference tooling writes is undefined by the spec** — EML,
   SSSOM, measurement decompositions, the semantic vocabulary file. The spec
   describes a narrower artefact than the ecosystem actually produces.
6. **The flagship minimal example ships placeholder IRIs, wrong-scheme QUDT
   identifiers, a self-contradicting method annotation, and a false row count.**
   This is the example everyone copies.
7. No RFC 2119 keywords, no conformance section, and "strict publication
   validation" is used normatively but never defined.
8. No versioning/deprecation policy, no released 0.2.0 changelog entry, malformed
   release date.
9. **No LICENSE, no CI, no Pages configuration** — while the profile `$id` and every
   schema `$ref` assume a live Pages site, and two MIT-licensed libraries
   redistribute the files.

---

## 4. Cross-repo drift and governance

All `[V]`.

- **P0-2** is the headline (§1).
- **metasalmon's shipped example metadata CSVs violate the spec's exact-header
  rule**, and `inst/extdata/codes.csv` is structurally ragged.
- **metasalmon writes non-schema columns into canonical SDP metadata CSVs** and its
  validator never rejects them — so the tool and the spec disagree about what the
  canonical files contain, in both directions.
- **Profile-scoped (local/program) term requests are filed against the shared
  Salmon Domain Ontology repo**, contradicting the documented three-tier
  file-first → bridge-namespace → shared-core promotion policy.
- **No version pinning between metasalmon and either ontology**: search indexes
  track branch HEAD; the ontology release version is never captured in output.
  When `smn` publishes 0.0.3, every previously published SDP's provenance becomes
  unreconstructable.
- Term-request issues are posted without labels; `gcdfo` requests silently drop the
  I-ADOPT decomposition; `term_type` vocabulary is inconsistent across the issue
  templates, the SDP schemas, and metasalmon's EML export.
- **Personal-account GitHub URLs are baked into org-published specification and
  issue-routing contracts** — a real bus-factor and continuity exposure.
- `docs/entrypoints.md` — the file whose purpose is to be the one true map — names a
  package that does not exist, as does the FAIRsharing registration draft.
- **`smn`'s published serializations declare the wrong ontology IRI and drop
  `owl:versionIRI`**, so `w3id.org/smn` does not resolve to a document about
  `w3id.org/smn`.
- **"Immutable" release snapshots are not immutable**, and the DFO version sequence
  is non-monotonic: `0.0.999` published, then edited, then followed by `0.0.8`.
- **No documented editorial authority, review SLA, or curation role** for term
  acceptance in the shared ontology; contribution entrypoints point at a personal
  fork.
- `/gcdfo/` is split across case-sensitive `/GCDFO/` and `/gcdfo/`, and the live
  content negotiation targets a directory that does not exist in the ontology repo.
- **No repository in the ecosystem is citable**: one `CITATION.cff` exists and it is
  unedited `cffinit` boilerplate with published FIXMEs.
- The ontology repo's `LICENSE` is **MIT** while the ecosystem uses **CC BY 4.0**
  everywhere else, and the TTL carries no machine-readable licence at all.

---

## 5. Salmon Domain Ontology (`smn:`) — `[F]`, verify before acting

Ranked: P1-9 (`owl:equivalentClass` rewriting SOSA/DwC), P1-10 (`sosa:Property`
doesn't exist), P1-11 (chum-salmon range) are in §1. Remaining:

- **Published Turtle/RDF-XML lose the ontology IRI and drop `owl:versionIRI`; the
  three content-negotiated serializations are different graphs.** A client asking
  for `text/turtle` at `w3id.org/smn` gets a document claiming to be
  `w3id.org/smn/modules/01-entity-systematics`. *(critical)*
- **`make verify-doc-version-metadata` doesn't verify the artefacts it claims** — it
  substring-greps two HTML files, which is why the above shipped through two tagged
  releases undetected. Rewrite to parse RDF with rdflib. *(high)*
- **OWL classes asserted as individuals cause ROBOT to demote `sosa:hasSample` /
  `sosa:isResultOf` to annotation properties** in the published artefact — OWL 2 DL
  punning; a merged import won't load in HermiT/ELK/Pellet. *(high)*
- **`sosa:resultTime` (a datatype property) restricted with an object filler** makes
  `smn:SamplingEvent` unsatisfiable against real SOSA. *(high)*
- **No machine-readable licence, creator, title or description** on the artefact —
  FAIR R1.1 and OBO principle 1 unmet. *(high)*
- **I-ADOPT modelling is not conformant**: variables typed as properties, native
  role properties absent from every module, constraints never typed
  `iop:Constraint`. The RDA juvenile-condition case study — the artefact meant to
  *demonstrate* I-ADOPT conformance — returns zero results to an I-ADOPT query.
  *(high)* This one matters most to metasalmon: it is the semantic contract the
  whole decomposition pipeline targets.
- SKOS mapping properties used between OWL classes throughout the normative
  alignment module (~30 mappings), violating the repo's own dual-representation
  rule and rendering the mappings inert to SKOS tooling. *(medium)*
- The `gcdfo`→`smn` migration map is not SSSOM and carries no mapping predicate, so
  exact replacements and semantic re-scopings are indistinguishable; no deprecation
  pattern implemented. *(medium)*
- No SHACL shapes and no executable competency questions — 19 OWL restrictions and a
  large SKOS layer with no way to check instance conformance (open-world existentials
  never flag missing data). *(medium)*
- `smn:Escapement` is defined as a number but typed as a BFO process;
  `smn:EscapementMeasurement` is simultaneously a datum, a result, an observation
  and a variable across builds. *(medium)*
- 43 shared terms lack the definition `CONVENTIONS.md` marks Required; the gap
  ledger predates the released version. *(medium)*
- Views composition root uses relative `owl:imports` that don't match the imported
  files' ontology IRIs — passes locally, 404s over HTTP. *(medium)*

---

## 6. GC DFO Salmon Ontology (`gcdfo:`) — `[F]`, verify before acting

P0-9 (inert validation layer + no-op ROBOT gate) is in §1. Remaining:

- **The ontology rewrites third-party namespaces without importing them**, including
  re-typing five SKOS object properties as annotation properties — which breaks the
  OWL 2 DL claim and makes SKOS-aware tools disagree with `gcdfo`. Any consumer
  merging with DwC silently acquires DFO's BFO parentage for DwC terms. *(high)*
- **55 term-name collisions with `smn:`** — see §1 P4-3. *(high)*
- **Cross-repo mappings are type-mismatched, include a target IRI that was never
  minted, and use predicates the projects' own conventions forbid.** *(high)*
- **The ontology contains no logical axioms at all** — no restrictions, no
  equivalences, no disjointness. The OWL half of the "hybrid OWL+SKOS" design and
  the ELK reasoning step are vacuous; none of the documented inference patterns
  (MU→CU→Stock roll-up, measurement-to-stock constraints, method applicability)
  work. *(high)*
- **The Darwin Core / DwC-CM alignment advertised in README and ADR-002 is three
  subclass axioms and no predicates**, and the repo contradicts itself on whether
  it's implemented or planned. This is the headline interoperability claim. *(high)*
- **Three policy-critical SKOS schemes are empty shells** — Precautionary Approach
  status zones, COSEWIC status, biological benchmarks. The vocabularies carrying the
  actual regulatory content cannot encode a single value, so metasalmon term search
  finds nothing and falls back to `REVIEW:` placeholders. *(high)* **This is the
  single highest-value ontology gap for metasalmon users.**
- I-ADOPT documented in three places, implemented in none; the compound-variable
  competency question depends on annotation properties that don't exist. *(medium)*
- BFO/IAO grounding asserted inconsistently: category errors on imported terms, a
  self-contradicting parent for policy targets, three orphan classes. *(medium)*
- Version IRI pinned to a rolling `0.0.999` sentinel; the prior-version chain
  silently drops the published `0.0.8`. *(medium)*
- SKOS integrity violations on an overridden ENVO term, 105 unlabelled concepts, and
  the duplicated "canonical" checklist a prior audit already flagged. *(medium)*
- Also worth reconciling: `"DFO Salmon Ontology Conventions – Compliance and
  Improvement Analysis.pdf"` in the parent directory — the finder reports several of
  its points are still unaddressed, and the project appears to believe it has been
  externally audited as OWL 2 DL- and OBO-conformant when the audit examined the
  conventions document, not the TTL.

---

## 7. Workshop materials

All `[V]`.

- **No episode code is executable**: seven `.Rmd` files contain zero knitr chunks,
  and `renv/profiles/lesson-requirements/renv.lock` omits `metasalmon`. A learner
  following the lesson runs nothing, and an instructor cannot detect API drift.
  *(medium — but it is the root cause of every other workshop finding)*
- **R and Python install paths are guaranteed to install different versions**,
  breaking the version-alignment claim the lesson rests on; `learners/setup.md`
  claims 0.1.6 while installing unpinned from `main` (now 0.1.7).
- **Learners are asked to record "mapping strength" with no mapping vocabulary ever
  taught** — SKOS mapping properties and the shipped SSSOM 1.1 support are absent.
- Six challenges, zero solutions; the bonus episode declares 45 minutes of exercises
  containing no exercise blocks.
- Session 3 reads the learner's codebook and context files into variables never used
  again, and never mentions the exported helpers that would consume them.
- **LLM-assisted review is prose only** — no runnable example, no provider values,
  and none of the documented failure modes. Given the opt-in contract is a
  first-class safety property of the package, this is the wrong thing to hand-wave.
- `CITATION.cff` is unedited `cffinit` template; FIXME placeholders are live on the
  citation page.
- **The two chartered training outcomes are not delivered**: cross-source data
  integration, and contributing an aligned ontology module.

---

## 8. ROADMAP

Five milestones. Each is independently shippable and leaves the tree green.

### M1 — "Installable and honest" (0.1.8) · ~1 week
P0-1, P0-2, P0-6, P0-7, P0-8, P1-2.
Restores installability, makes the schema contract truthful, closes the credential
and locale hazards, stops the term-request prompt filing issues against user intent.
**Gate:** re-vendor `smn-data-pkg` artefacts; add a test that loads the *live*
upstream bundle (network-gated but **asserting non-skip in CI**, since the whole
class of bug hid behind a silent skip); regression tests for locale ordering
(`LC_COLLATE=C` vs `en_US.UTF-8`) and for brace-bearing provider error text.
Update bug #33's compatibility decision — it is now stale, and the note itself is
the reason the drift went unnoticed.

### M2 — "Round-trip integrity" (0.1.9) · ~2 weeks
P0-3, P0-4, P0-5, plus the `"NA"` round-trip and `strict=TRUE` items from P2.
**Gate:** one property-style round-trip test — synthesize a package with adversarial
values (`"0.10"`, `100000`, `"NA"`, `""`, embedded newlines, non-ASCII, mixed case),
then `create_sdp → read → write → validate` and assert byte/value stability plus
sidecar survival. This single test would have caught four of the five bugs. Grep the
package for the `.data$x == x` shadowing pattern and add a lint.

### M3 — "Usable at real scale" (0.2.0) · ~3 weeks
P1-1, P1-6, P1-7, and the P2 perf cluster; then P1-3 and the P3 condition-class
work. This is the milestone that turns the semantic pipeline from a demo into
something that survives a 200-column package.
**Gate:** a benchmark fixture asserting a *bounded* number of `fetch_salmon_ontology()`
and `search_fn()` invocations for a fixed target count — a regression guard on the
cache, not just on wall-clock.
Ship the condition-class hierarchy in the same major bump, since it is the one
change here that is technically breaking for anyone matching on message text.

### M4 — "One validation authority" (0.2.x, with `smn-data-pkg`) · ~3 weeks
P1-4, P1-5, and §3 items 1, 3, 4, 7, 8, 9 — coordinated across the two repos.
Sequence: (a) give `smn-data-pkg` a LICENSE, CI, and Pages config; (b) express the
nine prose rules machine-readably and give `sdp.rules.yaml` real rule bodies;
(c) declare the Frictionless target in an ADR; (d) drive metasalmon's validator from
the rule `id`s; (e) add a conformance test that **fails when the spec declares a rule
the implementation does not execute**. Fix the minimal example — it is the artefact
everyone copies.
Then §3 item 2 (semantic fields in the descriptor via `rdfType` + an `sdp:` block),
which is the change that makes the "linked data" claims true.

### M5 — "Semantics you can pin and cite" (ecosystem) · ~6 weeks, parallel track
Highest strategic value, longest lead time, least code.
1. **Verify the 27 `[F]` ontology findings.** Cheap and mechanical: `robot
   validate-profile --profile DL`, `pyshacl` against the *correct* namespace, run
   the competency SPARQL with rdflib. Do this before anything else in M5.
2. **P0-9 + `smn` release-metadata fixes** — make the quality gates real, so the rest
   of this list stays fixed once fixed.
3. **Fix versioning so pinning is possible**: monotonic versions, real `owl:versionIRI`
   in every serialization, restored `0.0.8`, immutable release snapshots. Then thread
   the resolved ontology release into metasalmon's output and into the KNB
   transformation record — this is the precondition metasalmon already documents and
   cannot currently satisfy.
4. **Publish the `smn:`/`gcdfo:` boundary as data**: one SSSOM 1.1 mapping set for
   the 55 collisions, owned by one repo, with a CI check in both that fails on any
   unmapped local-name collision. Then make metasalmon's namespace routing read it
   instead of inferring it.
5. **Populate the three empty policy schemes** (PA zones, COSEWIC, benchmarks) —
   the highest-value single ontology change for actual users.
6. **Fix the I-ADOPT layer** (P1-10, §5 I-ADOPT item) so the decomposition pipeline
   has a conformant target.
7. **Governance**: CC BY 4.0 machine-readable in the TTL, real `CITATION.cff` in each
   repo, named editorial authority and review SLA, org-owned URLs replacing
   personal-account ones, one accurate `entrypoints.md` per repo.

### Continuous, alongside all of the above
- **Workshop (M2/M4 gates):** convert the episodes to real knitr chunks pinned to a
  released metasalmon, add the lockfile entry, write the six missing solutions,
  teach SKOS mapping properties + SSSOM, and make the LLM section runnable with its
  failure modes. Once episodes execute, the workshop becomes an integration test of
  the public API — which is where the "stale call" class of bug gets caught for free.
- **Commit `AGENTS.md`** (P3) — it is git-ignored, so #9 is only locally fixed.
- **Un-`\dontrun{}` the ~15 examples that run offline in under a second** (P3): the
  cheapest possible increase in what `R CMD check` actually validates.

---

## 9. Two things I'd push back on

1. **The `notes/bugs-and-improvements.md` "fixed" markers are load-bearing and at
   least two are wrong** — #9 (`AGENTS.md`) is fixed only in an ignored file, and
   #33's compatibility decision is now false because upstream moved. The document is
   excellent, and precisely because agents and reviewers trust it, a stale "fixed"
   is worse than an open item. Consider a dated re-verification pass, or a CI check
   that asserts the claim (e.g. `git ls-files AGENTS.md` is non-empty).

2. **Test-suite green is not the signal it looks like here.** Three of the most
   serious findings (P0-2, P1-4, and the readr round-trip class) are invisible to
   the suite because the tests pin `source = "vendored"`, skip silently offline, or
   never round-trip a package through its own validator. The suite is large and
   well-built, but it validates the vendored, offline, single-table happy path. The
   two cheapest structural improvements are the adversarial round-trip test (M2) and
   asserting that network-gated tests **do not skip** in CI (M1).
