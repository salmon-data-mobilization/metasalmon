metasalmon 0.2.6
----------------

Roadmap S8, first half: the tidy-data foundations the method placement model
depends on.

### New

- `validate_salmon_datapackage()` checks that a declared `primary_key` actually
  identifies a row. The field was declared in `tables.csv` and read by nothing
  that tested it, so a table could claim a key and ship duplicates — the tidy
  principle "each observation forms a row" going unverified. Now an error.

- Column names that look like data values are reported. Bare year-like names, or
  a shared stem with numeric suffixes, across three or more columns. A
  **warning, never an error**: the SDP may accept untidy data, it should simply
  stop implying it checked. The message points at `tidyr::pivot_longer()`.

- Unresolved `MISSING METADATA:` placeholders are surfaced in the default
  validation mode. They were already errors under `require_iris = TRUE`; an
  ordinary call returned zero issues and said nothing, so a package could look
  clean while stating in its own metadata that its metadata was missing.

metasalmon 0.2.5
----------------

### Fixes

- Credential redaction covers qualified token names. The pattern named
  `dataone_token` specifically, so the production credential was redacted and
  `dataone_test_token` was not — the worst possible split, since staging is the
  credential a first-time user is most likely to paste into a script. Captured
  HTTP and provider errors are stored in returned tibbles and written to CSV, so
  this leaked at rest, not only on screen. The rule is now structural — any
  qualified `*_token` name — so a credential introduced later is covered without
  another patch. `token` must be the final name segment, so token-count fields in
  provider diagnostics (`max_token_count`, `total_tokens`) are left intact — they
  carry the numbers needed to correct a rejected request.

### Internal

- The second redaction implementation is deleted. `.ms_knb_redact()` and
  `.ms_redact_secrets()` were two implementations of one security contract, and
  only one was extended when the pattern last changed — which is exactly how the
  gap above arose. KNB messages now redact through the shared function, which is
  strictly stronger: it also catches `x-api-key`, provider API keys, and
  serialized JSON credential forms that the deleted version missed.

metasalmon 0.2.4
----------------

### Breaking changes

- **The canonical CSV missing-value contract is now a single token: an empty
  field.** Data resources were written with readr's default `na = "NA"` while
  metadata used `na = ""`, and everything was read with `na = c("", "NA")`.
  `"NA"` is a real fisheries gear code, so a literal `"NA"` and a genuinely
  missing value produced **identical bytes** — the distinction was destroyed at
  write time, where no reader could recover it. Both sides now use `""`.

  What changes for you: a literal `"NA"`, `"N/A"`, or `"null"` in a data column
  now round-trips as the string it is. If you have a **hand-authored** package
  whose CSVs use the two characters `NA` to mean missing, those cells now read
  as the literal string `"NA"`; rewrite them as empty fields.

  Consequence worth knowing: because no non-empty token parses as missing any
  more, EML `missing_values` codes are only meaningful for tokens the reader
  treats as missing, and the canonical writer emits none. EML now represents
  absence directly rather than through a code that collided with real data. The
  guard that rejects an undeclared non-empty missing token is retained as an
  invariant and is unreachable through the canonical writer.

### Fixes

- `ms_setup_github()` no longer defaults `repo` to a specific private dataset
  repository. Nothing about the function is dataset-specific — it finds git,
  creates or locates a PAT, and stores it — but the default meant a user
  calling `ms_setup_github()` with no arguments had their setup "verified"
  against a repository they could not read, so a perfectly good token was
  reported as broken. `repo` is now optional: supply it to additionally verify
  access, omit it to just set up the PAT.

### Internal

- Three examples now run: `apply_salmon_dictionary()`, `validate_dictionary()`,
  and `suggest_dwc_mappings()` were wrapped in `\dontrun{}` despite executing
  offline in under a second. Running them immediately caught two real defects
  that `\dontrun{}` had been hiding — one used `%>%`, which examples do not
  have attached, and another wrote a package directory into the working
  directory because it omitted `path`. `check_for_updates()` and
  `validate_salmon_datapackage()` moved to `\donttest{}` (network, and ~6s
  respectively).

  The roadmap estimated ~15 such examples; measuring each one offline showed
  only 5 actually run, because most `\dontrun{}` blocks are illustrative
  sketches using `path/to/package` placeholders rather than runnable code held
  back by caution. Making those real is a larger job than un-wrapping.

- The GitHub read-helper tests point at metasalmon's own public repository
  instead of a private one, so they exercise `read_github_csv()` and
  `read_github_csv_dir()` everywhere including CI rather than skipping with a
  404. The `METASALMON_GITHUB_TEST_*` environment variables still redirect them
  at a private repository when testing those permissions specifically.

- CI runs the suite under a non-C ambient collation (`LANG`/`LC_ALL` =
  `en_US.UTF-8`, with `fr_FR.UTF-8` also generated for `LC_TIME`). The
  differential guards on the byte-reproducibility contract compare an ordering
  against a contrasting locale and skip when none exists, so on a default
  C/POSIX runner they had been passing vacuously — the guards protecting the
  package's canonical bytes gave no CI signal. They now execute, and the whole
  suite passes under a locale that collates differently, which is the first
  actual evidence for the locale-independence claim rather than an assumption.
  CI skips drop from 9 to 6.

- CI now installs `{dataone}`, `{datapack}`, and `{XML}`, and a guard fails the
  build if any optional package the suite needs is missing. `R-CMD-check.yaml`
  installed only `devtools` and `rcmdcheck`, so five tests of the DataONE
  adapter boundary — the code that talks to the repository during live
  publication — skipped silently on every machine including CI and had never
  executed. They pass. The distinction the guard encodes: locally a missing
  optional package is an environment fact and skipping is correct; in CI it is a
  workflow regression and must fail.

metasalmon 0.2.3
----------------

Roadmap step 4: publication ergonomics and provider robustness.

### New

- `publish_sdp_to_knb()` gains `overwrite`. A dry run could not be re-planned
  after correcting an input: three separate gates — the SDP archive writer, the
  plan-mismatch check, and the resource-map ownership check — each treated an
  existing artifact as a published one, and none of the messages said that a
  manual `unlink()` was the only way forward. `overwrite = TRUE` now rebuilds
  derived artifacts and replaces a manifest and resource map left by an
  *unpublished dry run*. Anything that reached the network is unaffected: a
  manifest whose status is not `dry_run` still requires a reviewed revision,
  because its DataONE PIDs are immutable, and live publication is still gated by
  `confirm`.

### Fixes

- The default LLM providers now retry. `.ms_llm_retry_limit()` returned 1
  attempt for everything except two special-cased models, so
  `attempt >= attempts` was true on the first pass and the retryable-error
  classifier was never consulted — a 429 or a 503 failed the whole review on the
  first try, after the user had already paid for every preceding request.
  `Retry-After` is now honoured in both its delta-seconds and HTTP-date forms
  and capped at 60s, with jittered exponential backoff otherwise so a batch that
  hits one rate limit does not retry in lockstep.

- The BioPortal API key travels in an `Authorization` header instead of the
  query string, where it was written into request logs at both ends and printed
  verbatim by the timeout warning. URLs are additionally redacted before being
  displayed or recorded.

metasalmon 0.2.2
----------------

Roadmap step 2: the semantic pipeline at real scale.

### Fixes

- The term-search index caches now actually prevent work. `.smn_term_index()`
  and `.gcdfo_term_index()` checked their cache stamp *after* fetching and
  parsing, so every `find_terms()` call paid 11 conditional GETs and a full
  reparse of every SMN Turtle module before discovering nothing had changed —
  projected at roughly 8 CPU-hours for a 5-table x 200-column package. An index
  is now resolved once per session. The trade is deliberate: a module updated
  upstream mid-session is not picked up until `refresh = TRUE`, matching the
  decision already taken for the schema bundle, and it is the stronger guarantee
  for seeding, where two columns in one package must not be seeded against two
  different ontology versions.

- `METASALMON_CACHE` is read at call time. As a top-level binding it was
  evaluated when the namespace was built, so an installed package captured the
  build machine's environment and the result cache could never be enabled by a
  user — only `pkgload::load_all()` ever saw the developer's own setting.

- A failed vocabulary lookup is no longer indistinguishable from a successful
  empty one. `.safe_json()` returned `NULL` for both, every caller collapsed
  that into an empty result, and the diagnostic recorded
  `status = "success", count = 0` — so a degraded OLS or BioPortal looked
  exactly like "no such term exists", which is the input that drives
  `request_new_term` escalation. An outage could therefore manufacture ontology
  gaps. Failures are now signalled, recorded per source in the `diagnostics`
  attribute as `status = "http_error"`, and surfaced as a warning; a degraded
  lookup is never written to the result cache.

metasalmon 0.2.1
----------------

Closes the last two P1 items whose fixes change written artifacts, so they ship
ahead of the larger roadmap steps.

### Fixes

- Semantic ranking is now reproducible across locales. Score ties broke on
  character keys (`source`, `ontology`, `label`, `iri`), and with
  `seed_semantics = TRUE` the top-1 pick becomes a written IRI in
  `column_dictionary.csv` — so the same input seeded differently on macOS and in
  a C-locale container. All nine ordering sites in `R/semantics-helpers.R` and
  `R/term_search.R` now use explicit C collation, and seven functions are
  registered in the collation guard. This was the last locale-dependence in the
  package. Note that `.apply_embedding_rerank()` also selected its rerank set
  with `order(-score)` alone, so *which* rows were reranked depended on input
  order; it now tie-breaks on `label`.

- Per-resource schema URLs in `datapackage.json` are derived from the loaded
  SDP bundle rather than composed from a hardcoded constant. Every URI in a
  written descriptor — profile, rules, and per-resource schemas — now comes from
  one validated bundle. The constant remains as the fallback for a bundle that
  predates the v0.2 extension resources.

metasalmon 0.2.0
----------------

Remediates the nine highest-priority defects from the 2026-08-10 ecosystem
review (`knowledge/plans/2026-08-10-comprehensive-ecosystem-review.md`).

### Breaking changes

- `read_salmon_datapackage()` now types data resources from the column
  dictionary's `value_type` instead of letting readr guess, and **columns the
  dictionary does not declare are read as character rather than guessed**. The
  dictionary is the sole type authority, which is what makes the write/read
  round trip lossless. A value that does not satisfy its declared type is kept
  as its raw token rather than silently becoming `NA`, and the mismatch is
  reported as a structured validation issue. Declared columns are collected as
  text and converted only when the conversion is faithful, judged against the
  original token — so an unparseable value, a fractional `integer`, an
  `integer` or `number` whose precision or magnitude a double cannot hold, and a
  `datetime` finer than a `POSIXct` can represent at that instant all keep their
  exact token rather than being silently accepted, rounded, clamped, or
  truncated. Both numeric and datetime checks are magnitude-aware rather than
  fixed thresholds.
  Both `integer` and `number` otherwise read as double, because
  `readr::col_integer()` silently `NA`s values past 2^31 (readr's guesser also
  produced double here, so this is not a change); `apply_salmon_dictionary()`
  remains the way to get exact R classes.
- `write_salmon_datapackage(overwrite = TRUE)` no longer empties the package
  directory. It replaces only the files it owns — the `metadata/` SDP CSVs, the
  `data/` resources declared in `tables.csv`, `datapackage.json`, and the
  ownership sentinel — and preserves everything else. Pass the new
  `prune = TRUE` to restore the previous behaviour. `create_sdp()` gained the
  same argument.
- Newly written `datapackage.json` files declare the current SDP profile URI
  (`salmon-data-mobilization.github.io`), which is what the live upstream
  profile requires. Reading packages that declare the previous URI is
  unaffected.
- `Imports: dplyr (>= 1.1.0)`, required by `arrange(.locale = )`.

### Fixes

- **`zip` is no longer pinned to an exact version, at either layer.**
  `zip (== 3.0.1)` against a CRAN that ships 3.0.2 made metasalmon
  uninstallable. Relaxing only `DESCRIPTION` was not enough: the runtime guard
  `.ms_knb_require_zip_version()` was an equally exact check, so the package
  would install and then abort on every KNB publication path. That guard is now
  a reviewed-version allowlist, `c("3.0.1", "3.0.2")`. Both versions were
  byte-compared for metasalmon's exact `zip::zip()` call against a fixture
  covering nested paths, non-ASCII filenames, an empty file, incompressible
  bytes, and highly compressible bytes; the archives are identical. The
  determinism contract therefore still holds, and it is enforced where it
  belongs — at the KNB boundary, not in a dependency pin that blocked the
  majority of users who never publish to KNB. An unreviewed `zip` still fails
  loudly, with a message saying to byte-compare before widening the allowlist.
- **Remote SDP schema loading works again.** Upstream `smn-data-pkg` migrated
  every profile `$id`; metasalmon asserted equality against the old constant, so
  `source = "remote"` aborted and the default `"auto"` silently fell back to a
  stale vendored bundle. Identity is now derived from the loaded bundle and only
  checked for internal consistency, so an upstream identifier change is
  followable rather than fatal. The vendored profile and rules were re-vendored.
- **A multi-table dictionary is no longer applied in full.**
  `apply_salmon_dictionary()` compared a column against a same-named local, which
  the dplyr data mask shadows into a tautology, so every table's renames,
  coercions, and factor levels were applied while the warning said otherwise.
  `write_salmon_datapackage()` had the same bug for `dataset_id`, leaking other
  datasets' columns into `datapackage.json`.
- **`create_sdp()` no longer writes packages its own validator rejects.**
  Character code values such as `"0.10"` and `"100000"` were re-guessed as
  numeric on read and stringified back as `0.1` and `1e+05`, so a package failed
  validation against its own `codes.csv`. `write_eml_from_sdp()` inherited it.
- **Reviewed sidecars survive a rewrite.** The read → edit → write loop silently
  deleted reviewed SSSOM mapping sets, ordered measurement decompositions, EML
  and EDH XML, `eml-mapping.yml`, review notes, and `publication/` artifacts.
- **External text can no longer be evaluated as a cli message template.** A
  provider error containing `{Sys.getenv("OPENAI_API_KEY")}` printed the key, and
  an unbalanced brace — a column literally named `rate{pct` — replaced the
  intended message with `Error: Expecting '}'`. Fifteen sites now escape, and
  credentials are redacted where external text is captured rather than where it
  is displayed.
- **Canonical bytes and identifiers no longer depend on `LC_COLLATE`.** The
  DataONE resource-map PID, the plan fingerprint, SSSOM canonical bytes and
  manifest order, the measurement-decomposition hash, EML entity order, and both
  exported NuSEDS crosswalk tables all used locale-dependent ordering, so the
  same inputs produced different bytes on different machines and a package
  written on macOS could be rejected by a `LC_COLLATE=C` container.
- **Cancelling a term-request prompt no longer submits the issue.**
  `askYesNo()` returns `NA` on cancel and the guard tested `isFALSE()`. In the
  same workflow, exiting the routing menu aborted with "replacement has length
  zero", and the candidate/rationale lines passed cli markup to `glue::glue()`,
  which fails to parse on every input — so interactive routing had never worked.
- `infer_value_type()` now distinguishes `datetime` from `date`; `POSIXt`
  previously collapsed to `date`.

### Also in this release (from the 0.1.8 merge)

- The C-collation contract is applied to the SDP v0.2 extension normalizers
  introduced in 0.1.8. `.ms_sdp_methods_normalize()` and the two
  `.ms_sdp_observation_normalize_*()` functions produce the canonical row order
  written to `metadata/methods.csv` and `metadata/structure/observation_*.csv`,
  and `extract_sdp_observations()` orders returned data by dimension columns —
  all previously with bare `dplyr::arrange()`.

### Internal

- `write_salmon_datapackage()` refuses to update a package whose managed
  directories are reached through a symbolic link. `file.exists()` follows
  links, so a `data/` or `metadata/` replaced by one would have made every
  managed child resolve outside the package and be deleted there. This matches
  the symlink discipline the KNB archive already enforces.
- `create_sdp()` replaces its own outputs rather than writing through them. A
  hard-linked `README-review.txt`, `semantic_suggestions.csv`, or EDH XML would
  otherwise have truncated the shared inode outside the package —
  `Sys.readlink()` sees only symbolic links, and the pre-0.2.0 full-directory
  wipe had unlinked these entries implicitly.
- Provider failures on the measurement-bundle review path are redacted where
  they are captured, matching the non-bundle path. They are stored on the
  exported `semantic_llm_assessments` attribute, so display-time redaction
  would have been too late.
- Text reaching cli through the `.ms_*_abort()` forwarding helpers is escaped
  too. A decomposition column name is caller-supplied and was interpolated into
  an abort message, so a column named `{Sys.getenv("...")}` had its value
  evaluated into the error.
- New `R/cli-safety.R` (`.ms_cli_escape()`, `.ms_cli_bullets()`,
  `.ms_redact_secrets()`, `.ms_abort_external()`).
- Two static guard tests enforce the new contracts: `test-cli-safety-guard.R`
  and `test-collation-guard.R`. Both carry self-tests, and both are documented
  in `AGENTS.md`, which is now tracked in git — it had been ignored, so the
  shipped repo carried no contributor guidance at all.
- A live remote-schema test closes the gap that let the profile drift go
  unnoticed: the suite pins `sdp_schema_source = "vendored"`, and nothing had
  ever exercised a successful remote fetch.

metasalmon 0.1.8
----------------

- Added exact-schema, atomic, symlink-safe readers and writers for the optional
  SDP `metadata/methods.csv` SOSA procedure registry and paired
  `metadata/structure/observation_*.csv` resources. Validation now enforces
  complete one-structure-per-measure coverage, required dimension grain,
  typed repeated-value invariance, static and row-varying procedure resolution,
  canonical descriptor inventory, and remains unchanged when the extension is
  absent. Multi-file writes stage and validate the CSV/descriptor set as one
  rollback-capable transaction. Extension, reproducibility, and KNB APIs also
  reject direct or trailing-slash package-root symlinks without rejecting
  harmless platform aliases in ancestor paths.
- Added `extract_sdp_observations()` to produce one deterministic normalized
  table per declared measure-specific observation structure without claiming
  RDF Data Cube conformance.
- `apply_semantic_suggestions(strategy = "reviewed")` now applies explicit
  accepted review decisions and preserves multiple constraints for one
  measurement as a deterministic, deduplicated, semicolon-separated
  `constraint_iri`. The LLM-reviewed strategy has the same multiple-constraint
  behavior; lexical `"top"` and all non-constraint roles remain single-winner.
- Added a deterministic, checksum-bound `reproducibility/manifest.json` API for
  the optional reviewed-selection, workflow, provenance, and source sidecars.
  Validation is closed over the exact directory contents and rejects symlinks,
  undeclared files, missing files, and checksum or byte-size drift.
- `publish_sdp_to_knb(representation = "expanded")` now deposits the closed SDP
  inventory as individually named objects with package-relative ORE locations,
  instead of a ZIP. It includes validated SSSOM, decomposition, methods,
  observation-structure, and reproducibility artifacts and can reconstruct the
  exact SDP hierarchy without publishing unrelated files. Archive mode remains
  available for compatibility.
- EML export now documents procedures actually used by observed measurements as
  method steps, including method/protocol IRIs, versions, descriptions, and
  citations; unused registry alternatives are not asserted as performed. The
  reviewed semantic-selection ledger defaults to the extended
  `reproducibility/` layout while retaining the legacy root path for existing
  reviewed packages.
- Updated generated SDP descriptors and the vendored profile/rules/schema bundle
  to the byte-verified canonical
  `salmon-data-mobilization.github.io/smn-data-pkg` publication URLs.
- Corrected the bundled demo dictionaries so organism counts use QUDT
  `Individual` as their unit, use the released Salmon Domain Ontology
  `smn:Abundance` characteristic as their property, and no longer assert the
  nonexistent QUDT `NumberOfOrganisms` property.
- Fixed semantic candidate ranking for legitimate provider results whose
  optional `match_type` is missing; they now receive the configured unclassified
  score instead of aborting `suggest_semantics()`.
- Extended the reviewed QUDT-to-EML unit crosswalk so both HTTP and HTTPS forms
  of QUDT `Individual` (`INDIV`) serialize as the EML standard unit `number`.
- Made reproducibility-manifest ordering byte-stable across process locales,
  including artifact names that mix punctuation such as hyphens and
  underscores.
- Made exact KNB plans, ORE identifiers, access-policy normalization, and
  catalog-verification evidence locale-stable. Expanded SDP artifact paths now
  use the same radix ordering as their reproducibility and execution receipts.

metasalmon 0.1.7
----------------

- Corrected the KNB package representation. New plans now upload each original
  SDP data resource, one friendly deterministic ZIP containing the complete
  canonical Salmon Data Package, one EML 2.2.0 metadata object that describes
  both representations, and one OAI-ORE resource map. Internal SDP CSV, JSON,
  SSSOM, and measurement-decomposition files no longer appear as unnamed KNB
  objects.
- Added immutable KNB revision planning through `revision_manifest`. A revised
  sidecar supplies a new `publication.revision_key`; metasalmon preserves the
  metadata series, reuses unchanged data objects, and verifies DataONE
  `obsoletes`/`obsoletedBy` links for the new EML and resource-map versions.
  Dry runs reject a reused key before any network call, and legacy verified
  schema-v2 manifests can be migrated into the archive-based schema-v3 plan.
- EML download URLs now use the KNB Member Node endpoint and preserve literal
  `urn:uuid:` colons, matching MetacatUI's object-association behavior while
  Coordinating Node synchronization is delayed.
- KNB planning now rejects referenced vocabulary rows whose `source` or
  `ontology` label marks them as review candidates. This offline gate does not
  resolve IRIs or prove release governance; canonical transformation records
  must separately pin and verify the approved vocabulary release.
- Extended `write_eml_from_sdp()` with validated `otherEntity` supplements and
  deterministic revision keys. Added a copyable EML sidecar template and
  documented KNB private staging, persistent identifiers, retry states,
  revision semantics, and DOI minting as a separate per-metadata-version KNB
  release action. metasalmon never mints a DOI during deposit.
- Made deterministic ZIP construction fail closed around symlinks, unsafe or
  undeclared paths, changed existing archives, and tampered semantic manifests.
  Archive bytes are bound to the reviewed `zip` 3.0.1 implementation, and
  publication planning rejects any custom EML, manifest, or resource-map path
  that would collide with the deterministic archive. Raw-object identifiers
  also bind the immutable DataONE filename, so renaming unchanged bytes creates
  a new object instead of a late SystemMetadata collision.
  Publication-specific `eml-mapping.yml` authorization and party details stay
  outside the downloadable canonical SDP archive.

- Added reviewed EML 2.2.0 export with deterministic identifiers and bytes,
  strict SDP/sidecar/vocabulary preflight, a closed hashed semantic-review
  ledger, exact raw-CSV missing-value audits, observed numeric/date domain
  checks, pinned source-document provenance, a reviewed QUDT-to-EML unit
  crosswalk, EML schema validation, non-dangling constraints, and conservative
  whole-variable topic/unit semantic annotations. Draft and review sidecars remain
  inspectable but only a final sidecar can be exported.
- Added opt-in KNB/DataONE publication planning and verified upload. Dry runs
  create an immutable exact-object manifest and deterministic OAI-ORE map
  without reading credentials; live calls require explicit redistribution
  confirmation, a server-verified ORCID subject matching the EML metadata
  provider, resumable low-level object creation, authenticated and anonymous
  readback, SystemMetadata/access checks, and coordinating-node catalog
  verification. `public = FALSE` is an explicitly named private-review path,
  but it still creates persistent production objects and verifies anonymous
  denial for both bytes and SystemMetadata for every uploaded member. Private
  completion also requires a complete authenticated catalog graph and zero
  matching PIDs through a separate credential-free catalog query. Reviewed
  SSSOM mapping sets remain inside the named SDP ZIP and retain canonical
  tab-separated serialization.
- Bound DataONE replication policy into the reviewed KNB plan and remote
  SystemMetadata checks. Restricted private-review deposits now explicitly
  request zero peer replicas and reject permissive replication on create or
  resume. Live calls also require a schema-v3 review manifest whose policy and
  fingerprint recompute exactly. Public deposits explicitly retain the
  three-replica preservation policy that was previously inherited from the
  DataONE client default.
- Accepted zero as a valid server-owned DataONE `serialVersion` during KNB
  readback. The field is an `xs:unsignedLong`, and production KNB returns zero
  for newly created objects before a SystemMetadata update.
- Added strict package-native SSSOM 1.1 read/write/validation for reviewed
  concept alignments and version-scoped `sssom:NoTermFound` records. Mapping
  sets are deterministic and manifest-bound; undeclared files, literal
  assignments, decomposition columns, contradictory gap/mapping rows, and
  checksum drift are rejected before KNB planning.
- Added a catalog-neutral, manifest-bound SDP measurement-decomposition
  artifact for ordered property, entity, constraint, method, and unit
  components. It preserves repeated components, explicit vocabulary gaps, and
  dimension-to-value relations, validates exact dictionary closure and source
  provenance, and deliberately remains separate from SSSOM mappings and native
  I-ADOPT conformance claims.
- Corrected SDP inference and semantic matching defects found while exercising
  the package on the PSC Fraser Sockeye detailed release: terminal ID
  qualifiers no longer misclassify quality fields, nullable identifiers are
  not made required, profile versions follow the vendored rules, custom HTTP(S)
  rights URLs remain URL licence descriptors, biology-bearing query tokens are
  retained, and SMN term/module role and OWL-class metadata are preserved more
  accurately.

metasalmon 0.1.6
----------------

- Added bundle-aware LLM review for measurement columns. Variable, property,
  entity, unit, constraint, and method candidates are judged together, while
  generic column, code, table, and dataset targets retain their established
  per-target path. Malformed bundle slots fall back independently and a
  provider failure preserves the deterministic shortlist.
- Made explicitly supplied semantic sources a strict allowlist for initial and
  retry retrieval. Omitted sources continue to use role-aware defaults, so
  callers can choose broad role-specific discovery or a deliberately bounded
  source set without retries escaping it.
- Expanded `semantic_llm_assessments` from 28 to 30 columns by appending
  `llm_escalated_from` and `llm_retry_query_rejection_reason`. Legacy rows are
  normalized additively, unresolved shortlist rejection preserves escalation
  provenance, and exact duplicate retry queries are recorded without another
  generation, search, or reassessment call.
- Extended `detect_semantic_term_gaps()` to combine deterministic candidate
  gaps with final LLM `request_new_term` decisions while preserving its
  23-column prefix. Gap rows retain target metadata, detection basis, model
  rationale, proposed-term fields, and escalation origin.
- Added first-class GCDFO term-request routing and repository-specific SMN and
  GCDFO issue bodies. Explicit row overrides take precedence over forced scope,
  recognized namespace evidence, and placement heuristics; rendering remains
  separate from explicit, curator-confirmed submission.
- Added deterministic post-review validators for method and constraint
  evidence, semantic role and ontology type, known property/unit dimensions,
  and curated redundancy. Failed checks downgrade `accept` to `review`, clear
  the selection, preserve model confidence, and never retrieve, substitute, or
  invent terms. Only variable, property, entity, and unit assessments remain
  eligible for automatic `REVIEW:` prefills.
- Added a versioned offline Theme A replay benchmark, pinned ontology
  provenance, raw-to-reviewed checksums, assessment-to-provider interaction
  lineage, recomputed immutable capture/cohort promotion, an exact clean-source
  three-run live gate, and GitHub Actions for replay, the full test suite, and
  `R CMD check`.
- Refactored Theme A evidence tests to reuse one in-process harness and cache
  immutable Git-object hashes instead of launching dozens of R and shell
  subprocesses. Exhaustive publication-integrity mutations run in a separate
  offline, path-filtered workflow. Live benchmark requests now require the
  explicit `--allow-live-api=true` acknowledgement; default local tests and CI
  temporarily blank provider credentials, remain isolated from LLM providers,
  and require no provider key.

- Updated the canonical package site, repository, issue tracker, install
  commands, update checks, OpenRouter attribution, and live SDP schema fetches
  to the `salmon-data-mobilization` organization. SDP 0.2 profile identifiers
  remain unchanged because they are part of the current upstream contract.
- Refreshed the README, vignettes, generated reference pages, and pkgdown site
  to document the 0.1.4/0.1.5 behavior explicitly: context inputs are local file
  paths rather than parsed objects, context never enables LLM review by itself,
  non-UTF-8 text handling and source-label disambiguation are observable, and
  create-time EDH XML is a draft until the metadata is reviewed and rebuilt.

metasalmon 0.1.5
----------------

- `create_sdp(include_edh_xml = TRUE)` now flags the create-time EDH XML as a
  draft: it still writes the file, but warns (and points to
  `write_edh_xml_from_sdp()`) when the package still contains `REVIEW:` IRIs or
  `MISSING` placeholders, so a draft is not mistaken for a reviewed export.
- LLM context files are now decoded more robustly: non-UTF-8 (Latin-1 /
  Windows-1252) text/CSV context files are detected and re-decoded instead of
  being silently corrupted, and two context files that share a base name no
  longer collide in chunk ids or the `llm_context_sources` column.
- `semantic_code_scope = "factor"` code selection now keys on `dataset_id` as
  well as `table_id`/`column_name`, so multi-dataset seed codes can no longer
  cross-match on a shared table/column name.
- Fixed `infer_dictionary()` so LLM semantic-review options supplied while
  `seed_semantics = FALSE` now warn once instead of being silently ignored.
- Semantic LLM review now escalates an unresolvable `reject_shortlist` to
  `request_new_term`: when the model rejects the whole deterministic shortlist
  and the bounded retry round still finds no acceptable candidate, the
  assessment surfaces a likely ontology gap in `llm_decision` instead of a
  dead-end rejection.
- Hardened batched semantic LLM review: a single malformed item no longer voids
  the whole batch (only the affected target keys fall back to per-target
  review), duplicate target keys fall back instead of silently overwriting, the
  per-target fallback warning now reports *why* each key fell back, and a
  truncated or non-JSON provider response includes a sanitized content snippet in
  the error.
- Clarified the exported documentation for `create_sdp()`,
  `infer_dictionary()`, `infer_salmon_datapackage_artifacts()`, and
  `suggest_semantics()`, including the new `reject_shortlist` ->
  `request_new_term` escalation.
- Marked display-only vignette chunks as excluded from tangling so package
  checks do not execute credential, network, and local-file examples that are
  intentionally shown but not evaluated.
- Internal: deepened the semantic-review architecture without changing public
  signatures -- centralized LLM context/option handling
  (`.ms_llm_review_plan()`), extracted semantic target discovery into
  `.ms_semantic_discover_targets()`, moved one-shot artifact inference into
  `R/artifact-inference.R`, and froze the semantic target-row and LLM
  assessment-row column contracts with direct tests.

metasalmon 0.1.4
----------------

- Fixed `llm_context_files` handling in the `create_sdp()` semantic-review
  path: context files must now be supplied as local file paths, parsed
  data-frame/XML/R Markdown objects fail early with a clear error, and context
  supplied without `llm_assess = TRUE` now warns that it will be ignored rather
  than silently producing deterministic-only output.
- Clarified the exported documentation for `create_sdp()`,
  `infer_dictionary()`, `infer_salmon_datapackage_artifacts()`, and
  `suggest_semantics()` so users know context files affect only explicit LLM
  review.

metasalmon 0.1.3
----------------

- Added a first package-native `chat_decomposition()` workflow for measurement-variable review: resumable R-console sessions now keep structured curation state separate from transcript history, ask grouped decomposition questions, and end in an explicit preview/approve or new-term artifact with SKOS-variable / `usedProcedure` wording.
- Added deterministic fallback behavior for provider-wide LLM review failures: when every LLM assessment errors but retrieved semantic suggestions are still usable, package-native semantic review now warns and preserves the deterministic shortlist instead of aborting the whole workflow.
- Added `llm_reasoning_effort` support for OpenAI semantic-review requests and omit explicit `temperature` for GPT-5 chat-completions payloads that require the provider default.

metasalmon 0.1.2
----------------

- Fixed the seeded semantic-context warning path so `seed_semantics = TRUE` no longer crashes when mixed or previously unsupported `llm_context_files` trigger `cli` interpolation in package creation/review flows.
- Expanded `llm_context_files` handling so HTML/HTM, DOCX, `.R`, `.Rmd`, and `.qmd` inputs are read or normalized cleanly during LLM review instead of failing on unsupported-file warnings.
- Added Excel workbook context-file support for package-native LLM review, including `.xls`, `.xlsx`, and `.xlsm` inputs via the optional `readxl` package.
- Hardened LLM assessment parsing so malformed `accept` responses without a selected candidate degrade to `review`, and falsey `missing_context` placeholders no longer pollute outputs.
- Expanded LLM regression coverage with mixed-context bundle tests for the exact `chapi` + `ollama2.mistral:7b` configuration, including markdown, CSV, Excel, PDF, HTML, DOCX, and notebook/source context bundles across `dataset.csv`, `tables.csv`, `column_dictionary.csv`, and `codes.csv` targets.
- Finished the `scripts/llm-sanity-check.R` harness into a richer end-to-end smoke tool: it now generates per-case context bundles, records context formats in the summaries, rebuilds EDH XML after a simulated review pass, and writes stable CSV outputs under `artifacts/`.
- Added and linked a dedicated LLM review getting-started guide from the quickstart/setup docs so the package-native workflow is easier to discover.

metasalmon 0.1.1
----------------

- Added a first-class `chapi` LLM provider preset for DFO's internal Open WebUI endpoint. It defaults to `ollama2.mistral:7b`, uses `https://chapi-dev.intra.azure.cloud.dfo-mpo.gc.ca/api`, reads provider-specific overrides from `CHAPI_API_KEY`, `CHAPI_MODEL`, and `CHAPI_BASE_URL`, and now gives slower `gpt-oss` responses a longer effective timeout plus one retry.
- Updated the quickstart/home-page docs so internal DFO users can opt into `chapi` directly from `create_sdp(..., llm_assess = TRUE)`, while external users get parallel OpenRouter-free and OpenAI-credit setup paths.
- Promoted `create_sdp()` and the Salmon Data Package workflow into a coherent release shape: single-table and multi-table package creation, semantic review artifacts, and post-review EDH rebuild are now aligned and documented as the primary path.
- Hardened final-review behavior: `validate_salmon_datapackage(..., require_iris = TRUE)` now fails on unresolved metadata placeholders, blank table observation-unit IRIs, and lingering review sentinels so strict validation actually means review is finished.
- Hardened table-level semantic review writes and EDH rebuilds: LLM-selected table suggestions now write back into `metadata/tables.csv`, and `write_edh_xml_from_sdp()` now refuses to rebuild from obviously unreviewed packages.
- Improved package-native LLM review ergonomics: one-shot shortlist preservation now respects `llm_top_n`, shared `llm_context_files` are reused across targets, and non-interactive profile-scoped term requests now fail clearly instead of silently emitting junk defaults.
- Fixed multi-table semantic seeding so later tables use their own context instead of borrowing semantic context from table 1.
- Cleaned the release docs surface: refreshed the package description, fixed broken source-view links and vignette anchors, removed stale GPT-era remnants and orphaned assets, hid leaked internal helper pages from the public site, and rebuilt pkgdown from the integrated source.
- Bundled a matching Fraser Coho 2023--2024 starter dictionary plus provenance link so the installed package has a realistic context-file demo for the package-native LLM workflow.

metasalmon 0.0.27
----------------

- Fixed a deterministic semantic-query bug for spawner-style measurement columns: the property-slot query no longer hard-codes `count` for columns like `natural_adult_spawners`, and now prefers `spawner abundance` so the shortlist is more semantically sensible before LLM review.
- Added one bounded LLM exploration round for weak semantic shortlists: when the first LLM pass comes back as review/propose-new-term or low-confidence, `suggest_semantics(..., llm_assess = TRUE)` may request 1--2 alternate plain-text search queries, rerun deterministic retrieval, merge/de-dupe candidates, and reassess once without letting the model mint raw IRIs.

metasalmon 0.0.26
----------------

- Further tuned the OpenRouter free path for practicality: `openrouter/free` now uses smaller pair-sized batches and a smaller effective candidate shortlist per target so free-router prompts stay lighter on larger quickstart-style runs.

metasalmon 0.0.25
----------------

- Made the OpenRouter free path more practical for full semantic review runs: live `openrouter/free` requests are now serially batched in pairs and use a smaller effective shortlist per target when using the built-in HTTP client, which trims request overhead without adding flaky parallel fan-out.
- Added batch fallback safety: if a batched OpenRouter response is malformed or incomplete, `metasalmon` now falls back to per-target assessment instead of poisoning the whole run.
- Retained the 0.0.24 hardening: longer effective timeout, one retry for transient failures, lighter context payloads, and downgrade-to-review handling for out-of-range candidate indexes.

metasalmon 0.0.24
----------------

- Hardened package-native LLM review for flaky free-router behavior: OpenRouter free models now get a longer effective timeout, one automatic retry for transient HTTP/network failures, and fewer context chunks per request so prompts stay lighter.
- Hardened invalid LLM candidate-index handling: out-of-range `selected_candidate_index` values no longer poison the whole target; they are downgraded to `review` with no auto-selection instead of surfacing as a hard LLM error.

metasalmon 0.0.23
----------------

- Added package-native LLM semantic review on top of deterministic retrieval: `suggest_semantics(..., llm_assess = TRUE)` can now assess shortlisted candidates with OpenAI-compatible providers, attach `llm_*` review columns to `semantic_suggestions`, and expose target-level results via `attr(dict, "semantic_llm_assessments")`.
- Added local context-file support for LLM semantic review, including README/markdown/text-style files and optional PDF extraction via `pdftools`, with bounded chunking so reports are trimmed before prompting.
- Added OpenRouter support for package-native LLM review, including pass-through model ids (so OpenRouter models ending in `:free` work without special branching).
- Extended `infer_dictionary()`, `infer_salmon_datapackage_artifacts()`, and `create_sdp()` to thread the optional LLM semantic review arguments through the start-here workflow.
- Extended `apply_semantic_suggestions()` with `strategy = "llm"` and `min_llm_confidence` for explicit application of LLM-reviewed matches.
- Updated README, GPT-collaboration vignette, entrypoint docs, tests, and generated documentation for the 0.0.23 feature release.

metasalmon 0.0.22
----------------

- Simplified EDH XML support down to the single DFO Enterprise Data Hub HNAP export we actually use: `edh_build_hnap_xml()` is now the canonical helper, while `edh_build_iso19139_xml()` remains only as a deprecated compatibility alias.
- Simplified `create_sdp()` EDH export behavior: `include_edh_xml = TRUE` now always writes `metadata/metadata-edh-hnap.xml`; legacy `edh_profile` / `EDH_Profile` / `EDH_profile` inputs are still accepted as deprecated compatibility shims, while `edh_xml_path` is deprecated and ignored.
- Rebuilt reference docs, tests, package artifacts, and pkgdown site for the 0.0.22 patch release.

metasalmon 0.0.20
----------------

- Hardened GitHub helper security: GitHub readers now reject non-GitHub remote URLs and avoid attaching GitHub auth headers to non-GitHub hosts; improved public/private auth behavior and related tests.
- Hardened package writing + export reliability: `create_sdp()` now fails fast with an explicit `overwrite = TRUE` message when the target directory already exists, fixed DwC validator execution path, and improved ontology fetch robustness with explicit timeout handling and cache fallback behavior.
- Surfaced clearer warning messages when online vocabulary API lookups time out, so empty `find_terms()` results are less opaque during semantic seeding.
- Fixed `submit_term_request_issues()` batch routing so per-row `ontology_repo` values are honored instead of posting all rows to the first repo.
- Clarified `validate_semantics()` API by explicitly deprecating ignored legacy arguments (`entity_defaults`, `vocab_priority`) with coverage for warning behavior.
- Improved release/test hygiene: dependency bootstrap script hardening, tighter warning assertions in brittle tests, and refreshed package description wording.

metasalmon 0.0.19
----------------

- Hardened table observation-unit auto-apply in `create_sdp()`: table-level observation-unit suggestions are now ignored when driven by placeholder review text and only auto-applied when lexical compatibility checks pass against non-placeholder table metadata.
- Improved non-measurement `term_iri` auto-apply quality without disabling the feature: incompatible candidates are now filtered using role-hint mismatch checks, match-type/score guards, and token-level lexical compatibility with the target column context.
- Strengthened `infer_column_role()` heuristics for NuSEDS-like fields: year-like columns are now classified as temporal more reliably, and `NATURAL_ADULT_SPAWNERS`-style quantity columns are inferred as measurement.
- Tightened default code-level seeding gates to reduce free-text noise while preserving useful low-cardinality categorical/attribute suggestions: text-like field names and non-code-like all-unique short character values are excluded from the default factor-scope code seeding path.
- Added regression coverage for the above hardening paths, including placeholder-driven table seeding prevention, bad non-measurement suggestion filtering, improved role inference for fuller examples, and free-text seeding guardrails.
- Rebuilt reference docs, tests, package artifacts, and pkgdown site for the 0.0.19 patch release.

metasalmon 0.0.18
----------------

- Reworked review placeholders so missing descriptions/metadata are labeled explicitly (`MISSING DESCRIPTION:` / `MISSING METADATA:`) instead of the more ambiguous generic review wording.
- `create_sdp()` and related inference paths now seed table-level observation-unit review content and auto-apply the top table semantic suggestion into `tables.csv`, including `observation_unit_iri` and a backfilled `observation_unit` label when needed.
- Broadened default semantic suggestion coverage beyond measurement columns in a conservative way: categorical and controlled low-cardinality attribute columns can now receive lighter `term_iri` suggestions, while identifier and temporal columns remain excluded from default non-measurement suggestion seeding.
- Broadened default code-level semantic seeding so ordinary low-cardinality character columns from typical CSV imports are considered, rather than relying on R factor inputs.
- Made inferred `required` flags less misleading by marking obvious identifier columns as required and leaving other columns unknown (`NA`) until reviewed, instead of defaulting everything to `FALSE`.
- Improved auto-filled `term_type` values when `term_iri` suggestions are applied and kept the `target_description` vs `column_description` distinction explicit in suggestion outputs.
- Added a second bundled official NuSEDS example dataset: `nuseds-fraser-coho-2023-2024.csv` (173 rows across 2023–2024), while keeping the existing 30-row demo sample intact.
- Added reproducible provenance for bundled NuSEDS examples via `data-raw/nuseds_fraser_coho_examples.R` and documented the upstream Open Government Canada record/resource and licensing.
- Updated README, vignettes, reference docs, and tests to reflect the broader semantic seeding behavior, required-flag review stance, observation-unit handling, and the tiny-vs-fuller example-data workflow.

metasalmon 0.0.17
----------------

- Improved measurement semantic query shaping for count-like fields:
  - split variable/property query behavior so `NATURAL_SPAWNERS_TOTAL` no longer defaults both roles to the same abundance concept,
  - added a count-like unit fallback query (`count`) for measurement columns that clearly represent totals/counts/abundance.
- Added/updated regression tests for role-aware query behavior, count-like unit fallback, and unit-label backfill when applying unit suggestions.

metasalmon 0.0.16
----------------

- Rewrote `README-review.txt` intro and checklist to be shorter, more first-time friendly, and more action-oriented.
- `create_sdp()` now prints an explicit up-front note that semantic seeding may take a few minutes.
- Improved column-level semantic query construction for measurement fields so placeholder text is not used as the query source.
- Added role-aware query shaping that improves built-in sample suggestions for `NATURAL_SPAWNERS_TOTAL` (e.g., variable/property `SpawnerAbundance`, entity `Population`, constraint `NaturalOrigin`) and avoids the previous exploitation/mortality-rate mismatches.
- Unit suggestions are now skipped when no unit context exists, and applying a unit suggestion now backfills `unit_label` when missing.

metasalmon 0.0.15
----------------

- `create_sdp()` now tells users up front when online semantic seeding may take a few minutes and points to `seed_semantics = FALSE` for the fastest first pass.
- Simplified `README-review.txt` into a shorter 7-step checklist so the review flow is easier to follow.

metasalmon 0.0.14
----------------

- Simplified the package-creation surface so `create_sdp()` is the clear one-shot entrypoint, `write_salmon_datapackage()` is the advanced/manual writer, and the older create-from-data helper was removed.
- Reworked `create_sdp()` output into a cleaner review layout with `metadata/` and `data/` subdirectories, package-root `README-review.txt`, package-root `semantic_suggestions.csv` (when present), and root `datapackage.json`.
- Rewrote `README-review.txt` as a step-by-step checklist that explains the canonical Salmon Data Package, how to share the full package folder (or zip), and how to return to R for validation.
- Tightened default semantic seeding so code-level semantic suggestions run only for factor/categorical source columns by default, while keeping column-level and table-level seeding available.
- Added optional update notifications inside `create_sdp()` via `check_updates`, using the explicit `check_for_updates()` helper rather than package-attach network checks.
- Refreshed README, vignettes, reference pages, generated documentation, tests, and pkgdown outputs to match the new workflow and layout.

metasalmon 0.0.13
----------------

- Added vendored SDP Frictionless metadata schemas, profile, and custom rules; the schema loader tries the remote `smn-data-pkg` schema bundle first, then warns and falls back to the vendored copy.
- Changed package creation to write the canonical `metadata/` + `data/` layout while generating root `datapackage.json` with the SDP Frictionless profile by default.
- Added `write_datapackage = TRUE` to package creation helpers so callers can opt out during draft authoring.
- Updated package reading to prefer nested `metadata/` files, then legacy root-level metadata, then `datapackage.json` fallback.
- Made `edh_build_iso19139_xml()` default to the richer North American Profile / HNAP-aware EDH export while keeping `profile = "iso19139"` available as an explicit fallback.
- Expanded EDH export support for bilingual locale scaffolding, deterministic identifiers, legal constraints, maintenance/status, reference systems, bounding boxes, and distribution metadata, with regression coverage against the confirmed EDH sample shape.
- Added `apply_semantic_suggestions()` for explicit opt-in merges of `suggest_semantics()` results into dictionaries.
- Updated `read_salmon_datapackage()` to prefer canonical nested metadata, preserve legacy root-level reading, and read profile-aware `datapackage.json` descriptors when CSV metadata is absent.
- Refreshed README, vignettes, pkgdown reference metadata, and GPT collaboration guidance to match the EDH default/export semantics and explicit dictionary-application workflow.
- Rebuilt package documentation, tests, source tarball, and pkgdown site for the 0.0.13 release.

metasalmon 0.0.12
----------------

- Added a GCDFO-backed `find_terms()` search backend that queries the DFO Salmon Ontology first via content negotiation against `https://w3id.org/gcdfo/salmon`.
- For salmon-domain roles, `find_terms()` now prioritizes GCDFO results and only falls back to OLS/NVS when GCDFO returns no good label hit.
- Updated `suggest_semantics()`, `infer_dictionary(seed_semantics = TRUE)`, man pages, and vignettes to reflect the new GCDFO-first search behavior.
- Rebuilt package documentation, tests, source tarball, and pkgdown site for the 0.0.12 release.

metasalmon 0.0.11
----------------

- Added optional semantic seeding to `infer_dictionary()` via
  `seed_semantics = TRUE`, with optional source/max-per-role controls
  (`semantic_sources`, `semantic_max_per_role`).
  - This returns dictionary suggestions via
    `attr(dict, "semantic_suggestions")` without changing existing defaults.
- Added guidance at the package README quick example that keeps the home-page flow
  short and links to 5-minute Quickstart + dedicated deep-dive articles.
- Marked related vignettes as workflow-specific to avoid duplicating the Quickstart
  path; `data-dictionary-publication` and `reusing-standards-salmon-data-terms`
  now orient users to post-Quickstart use.

metasalmon 0.0.10
----------------

- Changed `validate_dictionary()` and `validate_semantics()` non-strict semantics:
  - missing `term_iri`, `property_iri`, `entity_iri`, and `unit_iri` on
    `column_role == "measurement"` no longer block package creation by default;
  - missing fields now trigger a strong warning that calls out next steps and points to `suggest_semantics()` plus the standards guide.
- Preserved strict validation when `require_iris = TRUE` so CI/high-assurance flows can still enforce full semantic coverage.
- Updated `README`, man pages, and tests to document and verify the new behavior.
- Added `metasalmon` package release metadata for version 0.0.10.

metasalmon 0.0.9
----------------

- Added `edh_build_iso19139_xml()` to generate starter ISO 19139 metadata XML for DFO Enterprise Data Hub / GeoNetwork upload workflows.
- Added tests and reference documentation for the EDH XML export helper.
- Updated dataset metadata examples/templates to better support EDH workflows:
  - Expanded `inst/extdata/dataset.csv` with `contact_org`, `contact_position`, `update_frequency`, `topic_categories`, `keywords`, and `security_classification`.
  - Updated `inst/extdata/custom-gpt-prompt.md` to distinguish controlled `topic_categories` from free-text `keywords` and to note XML export support.
  - Refreshed README and vignette examples to include EDH-ready optional metadata and XML export guidance.

metasalmon 0.0.8
----------------

- Added and documented NuSEDS method crosswalk helpers:
  - `nuseds_enumeration_method_crosswalk()`
  - `nuseds_estimate_method_crosswalk()`
- Added reference documentation pages for both crosswalk helpers.
- Refreshed README feature list to include the new NuSEDS crosswalk utilities.

metasalmon 0.0.6
----------------

- Added `read_github_csv_dir()` to read all CSV files from a GitHub directory into a named list, similar to using `dir()` with `lapply()` for local files.
- Supports pattern matching, version pinning, and passes options to `read_csv()` for all files.
- Added comprehensive test coverage for the new function.

metasalmon 0.0.5
----------------

- Renamed the GitHub CSV helpers to generic names: `github_raw_url()` and `read_github_csv()`. `repo` is now required unless you provide a full URL.

metasalmon 0.0.4
----------------

- Added `ms_setup_github()` to guide one-time PAT setup (git check, browser token creation, git credential storage) and verify access to the private Qualark data repository.
- Added `qualark_raw_url()` and `read_qualark_csv()` to build stable raw GitHub URLs and read Qualark CSVs using the stored PAT (with SSO-aware error messages and retry logic).
- New tests cover URL construction, blob/raw URL normalization, and an opt-in Qualark fetch when a token is configured.

metasalmon 0.0.3
----------------

- Added `find_terms()` function for searching candidate terms across external vocabularies (OLS, NVS, BioPortal).
- `find_terms()` now ranks results deterministically using I-ADOPT role hints from `inst/extdata/iadopt-terminologies.csv` (preferred vocabularies boosted; ties stable).
- `suggest_semantics()` now returns best-effort suggestions (stored in `attr(,'semantic_suggestions')`) instead of a placeholder message.
- Added I-ADOPT component fields (`property_iri`, `entity_iri`, `constraint_iri`, `method_iri`) to dictionary schema and package creation/reading.
- Enhanced validation: measurement columns now require I-ADOPT components (`term_iri`, `property_iri`, `entity_iri`, `unit_iri`).
- Updated table metadata: renamed `entity_type`/`entity_iri` to `observation_unit`/`observation_unit_iri` for clarity.
- Added `httr` package dependency for vocabulary search functionality.
- Dictionary validation now normalizes optional semantic columns and returns the normalized dictionary.
- Vignettes now show end-to-end semantic enrichment (I-ADOPT-aware suggestions) and how to align with `smn-gpt`.

metasalmon 0.0.2
----------------

- Unified semantic fields to `term_iri` + `term_type` and reserved `concept_scheme_iri` for code lists only.
- Updated GPT collaboration guidance, schemas, and pkgdown outputs to match the new fields.
- Refreshed vignettes, tests, and reference docs; bumped package version.

metasalmon 0.0.1
----------------

- Initial development snapshot.
