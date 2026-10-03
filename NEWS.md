metasalmon (development version)
--------------------------------

### Breaking changes

* **`find_terms()` searches the sources a role calls for when you name a role
  and no sources** (hub item B-420; ruled by Brett on 2026-09-26,
  `knowledge/questions.md` Q70: R moves). `sources` now defaults to `NULL`,
  which means `sources_for_role(role)`, as it already did in metasalmonpy and
  as `suggest_semantics()` already resolved an omitted list here. So
  `find_terms("kilogram", role = "unit")` searches QUDT, NVS and OLS, where it
  searched smn, gcdfo, OLS and NVS whatever the role, and a direct unit search
  now reaches QUDT. A call with no role searches the same four sources as
  before, and a vector you name is still a strict allowlist. An explicit
  `sources = NULL` now means the same as leaving the argument out; pass
  `character()` to search nothing. The documentation described both
  behaviours, one under `role` and one under `sources`, and now describes one.
  Pinned by `tests/testthat/test-find-terms-sources.R`, which stubs every source
  and failed before the change.

* **`fetch_salmon_ontology()` raises when every URL fails, even when a copy is
  cached** (hub item B-422; ruled by Brett on 2026-09-26,
  `knowledge/questions.md` Q71, clause 2). It used to warn "Failed to refresh
  Salmon ontology; using cached copy" and return the copy as an ordinary value,
  whatever its age and, before the cache fix below, whatever URL or
  representation had written it. It now raises the error it raised when nothing
  was cached, as metasalmonpy always has, and leaves the copy on disk. The error
  names the last failure the way metasalmonpy names it -- `HTTP 503`, or the
  message of a request that did not complete -- where it used to paste the
  response object and print nothing after "last error:". Code that relied on
  the old fallback to keep working offline now gets the error. The package's own
  searches are unaffected: they cache under `tempdir()` and build each index
  once per session, so there was never an earlier copy for the fallback to
  return. The code keeps no freshness lifetime, so every call revalidates, and a
  copy the call could not revalidate is the one that is not returned. Pinned by
  `tests/testthat/test-ontology-fetch.R`, which failed before the change.

* **A package's ownership sentinel is now `.sdp-package`, holding the line
  `sdp-owned`, and `.metasalmon-package` is no longer written or recognised**
  (hub item B-113; ruled by Brett 2026-08-24, `knowledge/questions.md` Q14).
  `write_salmon_datapackage()`, and
  `create_sdp()` through it, now mark a package directory with one sentinel
  shared with metasalmonpy rather than a file named after this implementation,
  because what owns the directory is the SDP tooling and not one language's copy
  of it. The name and content line are recorded in
  `knowledge/parity-deviations.md` row 51. For a directory you already have:

  - **A package that still has its SDP metadata needs nothing.** The
    `overwrite = TRUE` check recognises it by its `metadata/` CSVs, as it
    always has, and the next write adds `.sdp-package`.
  - **A directory whose only sign of being a package is `.metasalmon-package`
    is no longer replaced.** `overwrite = TRUE` now stops with *"Refusing to
    overwrite non-metasalmon directory"*. If it is a package you mean to
    rewrite, rename that file to `.sdp-package`; otherwise write to a new
    directory.
  - **An existing `.metasalmon-package` is left where it is.** A rewrite no
    longer manages it, so it survives unless `prune = TRUE` empties the
    directory. Nothing reads it any more, and you can delete it.

  metasalmonpy writes `.metasalmonpy-package` until its half of the change
  lands (hub item B-127). This package still recognises a package metasalmonpy
  wrote by its SDP metadata, so nothing is refused in the meantime, but a
  package written by both carries both files until then.

### Added

- A dedicated semantic-review walkthrough covers the R review queue, accept
  and reject decisions, metadata setters and the optional decomposition
  dialogue. `tidyr` is now declared in Suggests for the tidy-data guide's
  `pivot_longer()` examples (hub B-129).

* **Model judgement runs outside the package: `write_semantic_review_packet()`
  writes a review packet for a harness to judge and
  `ingest_semantic_assessments()` reads its assessments back** (hub item
  B-326, step 1 of stream S16; ruled by Brett on 2026-09-25, hub Q67, with
  every recommendation of the S16 execplan's section 10 taken the same day).
  The in-package model call is deprecated below; this is its replacement, and
  the seam is a file because a harness cannot hand an R closure to a package
  process it did not start.

  - **The packet** is a deterministic JSON file, `review/semantic-review-packet.json`,
    holding what the package already computes for a review: every slot that
    still needs a decision (for a package path, exactly the queue
    `review_semantics()` shows, re-retrieved at depth `top_n`, plus the blank
    slots discovery recovers because retrieval found nothing for them at
    creation), each slot's ranked candidates by index with the evidence the
    validators read (label, IRI, source, ontology, native type, role hints,
    term type, resource kind, type IRIs, definition and scores), the
    measurement bundles with their current slots, the scored excerpts from
    the caller's context documents, the review instructions, the decision
    vocabulary and the 30-column assessment schema with an owner and a
    requiredness per column. Its `packet_id` is the SHA-256 of its canonical
    bytes with `packet_id` and `producer` removed, so the same packet built by
    metasalmon and metasalmonpy has the same id, and the id is an integrity
    check at ingest. Every ordering is C-collated and the emitter renders the
    bytes Python's `json.dumps(indent = 2, ensure_ascii = False)` renders,
    with numbers by value (a whole number as an integer literal, anything
    else through the shared number-token formatter), so the bar the execplan
    sets -- byte identity across the two languages except the `producer`
    member -- is met on the shared fixtures. Nothing pins an ontology today,
    and the packet says so (`pins.ontologies.pinned = false`) rather than
    pretending; it records the sources searched, the sources that failed, the
    vendored SDP profile version, the ranking identity and the retrieval
    depth, source policy and code scope the ingester needs to widen a
    shortlist.
  - **The assessment file** is the frozen 30-column row, one per target,
    written by the harness with a CSV library, plus a one-line sidecar
    `<csv>.packet-id` naming the packet it judged (the row has nowhere to
    carry it; `packet_id = ` names it instead). The ingester validates each
    row in a fixed order -- a harness-declared error, the decision vocabulary
    and its alias, a confidence in [0, 1] with no clamping, the index cleared
    on a non-accept before any range check, **an accept whose echoed IRI the
    packet did not offer is an error and is never applied**, an accept
    without an index or with an out-of-range one downgraded to review, a
    fractional index refused, an echo naming a different candidate an error,
    an accept carrying a new-term field an error, a retry without a query
    downgraded -- and continues past a bad row. A file-level problem aborts
    with nothing written, under a stable code carried as the condition's
    `code` field: `packet_version`, `packet_integrity`, `packet_unbound`,
    `packet_mismatch`, `header`, `unknown_target`, `duplicate_target`,
    `provenance`, `no_pass_2`. Package-owned columns are overwritten with one
    warning naming them.
  - **A retry is a second harness pass.** A `retry_search` with a usable query
    is retrieved inside the package under the packet's source policy and
    depth (the only network the ingester reaches, through `search_fn`), and
    when it widens the shortlist a continuation packet
    (`review/semantic-review-packet-pass-2.json`) is written carrying the
    widened shortlist, every slot's pass-1 row and every bundle's pass-1
    findings; nothing from that target is merged or escalated until the
    harness has answered it, and a `retry_search` answered at pass 2 is
    final. A duplicate query keeps its existing reason; an identifier-like
    query gets the new reason `identifier_like_query`, since there is no
    model call to replace it. **A rejected shortlist earns no second pass**:
    a final `reject_shortlist` escalates at once to `request_new_term`, which
    is metasalmonpy's rule and the one B-361 made R's.
  - **The bundle validators run at every ingest**, rebuilt from the packet, so
    the deterministic layer protects the record whatever the harness says:
    accepting the fork-length method for `catch_count` still fails through
    `SEM_METHOD_EVIDENCE_REQUIRED`, accepting `CatchContext` beside
    `CatchAbundance` still raises `SEM_REDUNDANT_CATCH_CONTEXT`, and the
    Theme A cases pass their recorded oracles through the ingester and the
    prefill step. Findings only grow across passes.
  - **Persistence is one atomic set** after the containment check:
    `review/semantic-llm-assessments.csv` (the record; numbers through the
    shared formatter, logicals as `TRUE`/`FALSE`, NA empty),
    `review/semantic-validator-findings.csv`, the pass-2 packet when owed,
    and, for a package path, the rows of `semantic_suggestions.csv` for the
    targets whose slots are still undecided -- decisions, decision reasons
    and hand-picked rows are preserved, and a slot decided between build and
    ingest keeps its rows. The ingester never touches the metadata CSVs:
    applying a choice stays `review_semantics()` -> `accept_suggestion()` ->
    `apply_sdp_semantics()`, and `review_semantics()` now shows the harness's
    judgement. **No unredacted copy of harness text survives**: every
    harness-owned free-text value goes through `.ms_redact_secrets()` at
    capture, the ingester never copies a harness file into `review/`, and a
    file the harness wrote at the packet's default location is replaced with
    its redacted form after a successful ingest, with a warning. `prune = TRUE`
    now warns about a record under `review/` as it does about recorded
    decisions.
  - **`semantic_llm_assessments(path)` reads the persisted record**, typed as
    the 30-column row with the findings attached as
    `semantic_validator_findings`, where it returned `NULL` for every path
    before. `detect_semantic_term_gaps()` and the accessors work unchanged on
    the dictionary the ingester returns.
  - **The contract is shared with metasalmonpy** (hub item B-327 is its
    half): the packet schema (`inst/extdata/semantic-review/semantic-review-packet-v1.schema.json`),
    the instructions file (`semantic-review-instructions-v1.txt`, carrying
    the bundle prompt's judgement policy verbatim, so it inherits surface 2 of
    the role contract) and the conformance fixtures under
    `tests/testthat/fixtures/semantic-review/v1/` -- a manifest of SHA-256s,
    the fake search responses, and per case the builder input, the golden
    packet, the harness file with its sidecar, and the expected record,
    findings, suggestions and status, with the pass-2 files where a case
    retries, the error code of every reject variant, and the Theme A cases
    with their expected oracle events. A sentinel proves no model-provider
    entry point is reachable from either function and that the network is
    reached only through `search_fn`, once per distinct query, role and
    source set.

* **`write_sdp_semantic_closure()` produces the reviewed semantic closure, which
  metasalmon has validated in three places and written in none** (backlog #116,
  hub item B-116). `write_eml_from_sdp()` and `publish_sdp_to_knb()` both require
  `metadata/semantic_vocabulary.csv` and `reviewed_semantic_selections.csv`, and
  the symptom of the hole was that a user who did everything the vignette said
  got *"metadata/semantic_vocabulary.csv does not exist"* with nowhere to go.
  One exported call now reads the package and writes both files:

  - **Both canonical sets are derived, not transcribed.** The two legitimately
    differ -- a table's `observation_unit_iri` is a review target and not a
    measurement vocabulary term, and a code-resolved `sosa:usedProcedure` is a
    measurement term and not a review target -- so neither can be reasoned from
    the other, and both come back on the result as `measurement_iris` and
    `review_targets`. In the shipped Fraser coho example the ledger has five
    rows and the vocabulary four.
  - **Evidence is resolved through the existing search path.** Each IRI's
    `label`, `definition`, `source`, `ontology`, `resource_kind` and `type_iris`
    come from `find_terms()`, re-running the query recorded in
    `semantic_suggestions.csv` or, failing that, the IRI's own local name split
    back into words (`SpawnerAbundance` -> `"spawner abundance"`). No LLM is
    involved and there is no argument that would enable one.
  - **`evidence` accepts the rows no search can fill.** QUDT is not a searchable
    source, so a unit row is hand-authored; `native_type` and `source_url`
    describe the ontology artifact rather than the term and are derived from the
    resolved source; `confidence` and `review_rationale` are human judgements,
    read from a recorded `decision_reason` where `apply_sdp_semantics()` left
    one and otherwise written as a `REVIEW REQUIRED:` marker with a warning
    naming each target. Supplied values win field by field, so one row may
    correct one field.
  - **Every digest is computed.** Each row's `reviewed_snapshot_sha256`, and both
    file digests in `metadata/eml-mapping.yml` -- edited in place, line by line,
    so the sidecar's own instructions are not deleted by a YAML round trip. A
    user never hand-writes a SHA-256 into a CSV again.
  - **An unresolvable IRI is a gap, not an abort** (ruled 2026-09-12). It is
    returned as `gaps`, in the shape `detect_semantic_term_gaps()` returns plus
    an `unresolved_iri` column, so it feeds
    `render_ontology_term_request()` and `submit_term_request_issues()`
    directly; both files are still written without that row. The omission is not
    silent, because `write_eml_from_sdp()` then names the same IRI as missing
    from the vocabulary.
  - **And a gap is a claim, so only one of the three ways a row can go unwritten
    makes one.** A gap row asserts that a term is absent from the searched
    vocabularies, which is what the term-request pipeline acts on, so the two
    outcomes that do not establish absence are reported separately. A **lookup
    that did not answer** -- a search that threw, or a `find_terms()` result whose
    `"diagnostics"` attribute names a failed source -- **aborts before anything is
    written**, naming each IRI and the sources that were silent; `find_terms()`
    already warns that such a result is unknown rather than an ontology gap, and
    this obeys it. A **term that was found with a required field blank**, such as
    a class with no definition, comes back in a new `incomplete` element naming
    the field and the slot, with a warning that says it is not a gap; the
    remaining rows are still written.
  - **The two files and the sidecar digest install as one set, and no write
    follows a link.** All three are rendered to bytes and installed through the
    package's existing `.ms_sdp_extension_atomic_write_set()`, which stages each
    as a sibling, renames them in, and rolls all three back if any install fails
    -- so a failure can no longer leave a replaced CSV beside its previous
    `sha256`. The package root, every intermediate directory component and each
    final entry are refused when they are a symlink, which matters because an SDP
    received from a collaborator can point any of the three names at a file
    outside the package and have this function truncate it. Hard links are not
    detected, because base R exposes no link count, and are closed by the same
    install path rather than by a check: the bytes go to a fresh inode and a
    rename replaces the directory entry, so nothing here ever opens the
    destination.

  `scripts/build-fraser-coho-knb-rehearsal.R` reached into `metasalmon:::` at
  three sites for exactly the things this function now returns, and reaches into
  none. The two stages are swapped so the EML sidecar is written first and the
  producer pins its digests, which removes the script's last hand-computed file
  digest as well.

### Fixed

* **`fetch_salmon_ontology()` no longer answers a request for one ontology with
  another's body, or one representation's request with another's** (hub items
  B-333 and B-335; metasalmonpy's twins are B-334 and B-336, and the two
  packages now apply one rule and one cache layout). Each is pinned by
  `tests/testthat/test-ontology-fetch.R`, which stubs `httr::GET()` and failed
  before the change.

  1. **The default fallback is tried for the default url only.**
     `fallback_urls` now defaults to `NULL`, which means `"https://w3id.org/smn"`
     when `url` is the default `"https://w3id.org/smn/"` and nothing otherwise.
     That fallback serves smn, and it used to be tried after any url, so a call
     for gcdfo whose url failed returned smn's body with no warning. Named
     `fallback_urls` are tried as before, and `character()` still names none.
     The package's own callers were never affected, because each names its own
     fallbacks.
  2. **Each URL and representation has its own cached copy and validators.**
     Every body used to be written to `salmon-ontology.ttl` in `cache_dir`,
     beside one `etag.txt` and one `last_modified.txt`. So fetching smn and then
     gcdfo into one directory left gcdfo at the path the smn call had returned,
     and the gcdfo request carried smn's ETag; a Turtle and then an RDF/XML
     fetch of one url did the same; and a fallback's ETag, sent to the url on
     the next call, could bring back the fallback's body as the url's on a
     `304`. A copy is now `<key>.ttl`, where `<key>` is the first 16 hexadecimal
     digits of the SHA-256 of the url as requested, a newline and `accept`,
     taken as UTF-8 bytes whatever the session's locale, and its validators are
     `<key>.etag` and `<key>.last_modified`. A request
     carries only the validators of the copy that URL returned under that
     `accept`, a `304` returns that copy, and a `200` replaces the copy's
     validators rather than keeping any the new answer did not send.
     **The returned file name changes accordingly.** Copies cached by earlier
     versions -- `salmon-ontology.ttl`, `etag.txt` and `last_modified.txt`
     directly under `cache_dir`, which by default is the persistent
     `file.path(tools::R_user_dir("metasalmon", which = "cache"), "ontology")`
     -- are no longer read, and you can delete them.
  3. **A `304` with no cached copy is that url's failure**, and the next url is
     tried. It used to stop the call with "Not Modified (HTTP 304)".
  4. **A copy holds exactly the bytes the server sent.** The body used to be
     decoded as UTF-8 and written back with `writeLines()`, so every copy gained
     a final newline and a body that was not valid UTF-8 was stored as the two
     characters `NA`. The copy is now the raw body, still written to a
     temporary file in `cache_dir` and renamed into place, and a validator file
     is the header's bytes and a newline, written in binary so that it is the
     same file on every platform. metasalmonpy now stores the same bytes the
     same way -- it used to decode a text type sent with no charset as
     ISO-8859-1 and rewrite it -- so a `cache_dir` either package writes holds
     the same files. `timeout_seconds` is unchanged: it bounds both the
     connection and the whole transfer, the rule metasalmonpy has now taken.

* **Source names are read the way metasalmonpy reads them** (hub item B-421).
  `find_terms()`, and the source policy that `suggest_semantics()` and
  `write_semantic_review_packet()` build (and so `infer_dictionary()`,
  `create_sdp()` and `chat_decomposition()`, which pass their sources to
  `suggest_semantics()`), now trim each name you supply of exactly what
  Python's `str.strip()` removes, lower-case it, and drop a missing or empty
  name and any repeat after its first appearance, keeping your order. Measured
  before the change: `find_terms(sources = "SMN")` and
  `sources = " smn "` searched nothing and reported a successful search with no
  rows, where metasalmonpy searched smn; and an `NA` was dispatched, failed, and
  was reported as a source that did not answer. An injected `search_fn`, the
  bundle-review payload and a review packet's recorded `explicit_allowlist` now
  see the normalised list, as they do in metasalmonpy. A name that is none of
  the sources is still kept and searches nothing. metasalmonpy's half of the
  change makes it drop a missing entry (`None`, NaN) where it used to search a
  source called `"none"`. Pinned by `tests/testthat/test-find-terms-sources.R`.

  `write_sdp_semantic_closure()` reads its `sources` by the same rule. It had
  its own, `trimws()` and `unique()` with no lower-casing, so `" SMN"` and
  `"smn"` were two sources there and a no-break space survived; metasalmonpy's
  closure had a third rule of its own. All three readers in each package now
  read a list one way, and the two packages read it the same way. A list with
  no name left is still refused. Pinned by `tests/testthat/test-semantic-closure.R`,
  which failed before the change.
* `fetch_salmon_ontology()` isolates cached bodies, ETags and Last-Modified
  validators by requested URL and Accept header. Fetching another ontology or
  representation no longer overwrites a returned path, and a primary cannot
  reuse a fallback's validators or body. Unqualified legacy files are not
  reused. Matching-cache failure behavior is unchanged (B-335; Python
  counterpart B-336).

* `fetch_salmon_ontology()` no longer tries the implicit SMN mirror when a
  caller names another ontology URL. Explicit fallbacks and the public
  argument defaults are preserved (B-333; Python counterpart B-334).

* The bundled NuSEDS dictionaries now describe `AREA` as a DFO sub-district
  code, following NuSEDS's data dictionary and sub-district map (B-401). The
  gold-standard cards no longer treat its lettered values as PFMA Subareas;
  whether a sub-district vocabulary term is needed remains open. The
  metasalmonpy and SDP-example corrections are B-402 and B-403.

* `write_sdp_semantic_closure()` now points a code-resolved procedure's gap
  or incomplete-evidence row to the `codes.csv` `term_iri` cell that carries
  it, with its table, column, code value and full row key (hub item B-265).
  When several code rows carry one procedure IRI, each address is reported.
  `render_ontology_term_request()` renders those as separate candidate
  requests; review them before filing so one missing term does not become
  duplicate ontology issues. The metasalmonpy port is B-266.

* CI review-completion failures identify known Git actions after directory or
  configuration options through fixed diagnostic categories. Paths and option
  values remain private, and denied tool calls still block review completion.

- `read_github_csv()` reaches its existing PAT, SSO and missing-path remedies
  for HTTP 401, 403 and 404. Other HTTP errors and transport failures still
  raise normally (hub B-256).

* **The migration and tidy-data vignettes now tangle without executable code**
  (hub item B-133). Their 25 display-only examples each declare
  `purl = FALSE` in the chunk header, so R CMD check's vignette-code step no
  longer tries to read example package paths that the tangle never created.
  The vignette guard's two pinned exceptions are removed; a new live chunk in
  either guide now fails the guard.

* Strict validation now checks the absolute-IRI shape of every populated
  semantic IRI in the dictionary and every `*_iri` field in `tables.csv`,
  including added table columns. Malformed text is refused before a package
  can be finalized; REVIEW markers and missing values retain their existing
  reports, and review-ready validation remains unchanged (hub B-342; Python
  mirror B-343).

* **Applying a dictionary preserves vocabulary-backed columns.** B-346,
  implementing Brett's 2026-09-25 ruling: a same-table/column codes row with
  a nonblank `vocabulary_iri` and missing/blank `code_value` now skips that
  column's code-list warning and factor conversion, even beside explicit code
  rows. Values are retained; ordinary code lists and independent declared type
  coercion keep their existing behavior. The Python companion is B-347.

* `write_eml_from_sdp()` now writes a profile UTC instant in temporal coverage
  as EML's `calendarDate` and `time` pair, so the EML 2.2.0 schema accepts it.
  Both parts come from the package's one persisted rendering and rejoin to its
  original text; year and date values remain a `calendarDate` alone, and mixed
  date/instant ranges work in either direction (hub B-354; Python mirror B-355).

* R Markdown and Quarto context files now use the shared UTF-8,
  Windows-1252, then Latin-1 decoding chain before front matter and code
  fences are removed. Review-packet excerpts retain Windows-1252 text
  instead of failing on invalid UTF-8 (hub B-383).

- Embedded SSSOM metadata with an explicit YAML tag is refused by
  `read_sssom_mapping_set()` and SDP validation through a non-evaluating YAML
  parser probe. Quoted exclamation text still reads as text, and no tag
  expression is evaluated (hub B-352; metasalmonpy mirror B-353).

- Session IDs no longer advance or initialize the user's random-number state,
  and BioPortal's once-per-session missing-key warning is recorded privately
  instead of in `options()`. `?metasalmon_configuration` documents the current
  option and environment inventory from one registry; package loading fills
  only missing concrete defaults, preserving user settings, backend-specific
  timeout inheritance and unset credentials. An unset SDP schema base URL
  resolves the package's current release pin at call time, including after a
  package reload (hub B-59).

* NuSEDS crosswalk-filled code terms now appear in `review_semantics()` with
  ranked alternatives when semantic seeding retrieves candidates (B-120).
  The existing prefill remains in `codes.csv` until a reviewer changes it;
  explicit caller IRIs and `semantic_code_scope = "none"` retain their
  behaviour. Importing a harness assessment preserves the prefill's provenance.
