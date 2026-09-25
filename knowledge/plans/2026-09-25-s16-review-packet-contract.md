---
type: Artifact
title: "S16 step 1 — the review-packet and assessment-ingest contract"
description: "The file contract that lets model judgement run in a harness instead of inside metasalmon and metasalmonpy: what the current in-package review path does (measured), the packet a package writes, the assessment file it reads back, the second pass a retry needs, where the files live, the deprecation of the in-package call, the conformance fixtures, the parity rows owed, what the later breaking release deletes, and the decisions that are Brett's. Written 2026-09-25 for hub items B-326 and B-327, and ruled the same day: Brett took every recommendation in section 10."
status: draft
tags: [s16, semantic-review, llm, parity, execplan, proposal]
psc:
  id: metasalmon:plan:2026-09-25-s16-review-packet-contract
  contexts: [metasalmon:context:hub-coordination]
---

# S16 step 1 — the review-packet and assessment-ingest contract

**Status: ruled 2026-09-25.** Brett ruled that day (hub Q67) that the model
call leaves metasalmon and metasalmonpy, and that the packages gain a
review-packet exporter and an assessment ingester. This plan says how, and he
ruled it the same day: when section 10's nineteen decisions were put to him, he
chose *"Take all recommendations"*. The ruling's operative copy is the
[S16 card](../sequences/s16-model-call-leaves-the-packages.md). The items are
`B-326` (metasalmon) and `B-327` (metasalmonpy), with the convergence items
`B-360` to `B-364` before them.

**Measurement basis.** Every file:line below is from metasalmon `ae16b42` and
metasalmonpy `f1f7230`, read on 2026-09-25, with five read-only probes against
an installed metasalmon 0.5.0 and the metasalmonpy environment. Line numbers
drift; the function names are the durable pointer.

## 0. What the first sketch got wrong

A review panel sketched this contract on 2026-09-24. Reading the code changed
it in twelve places, and each one changes what gets built:

1. **Confirmed:** `semantic_llm_assessments(path)` returns NULL for every path
   (`R/semantics-helpers.R:1225`; `review_console.py:297-299`). Nothing writes a
   `review/` directory today, and `semantic_suggestions.csv` sits at the package
   root.
2. **The candidate record the sketch listed is too short.** The validators read
   `role_hints`, `term_type`, `resource_kind` and `type_iris`
   (`R/semantic-bundle-validators.R:218-305`); the pass-2 merge sorts and dedupes
   on `score`, `source`, `ontology`, `label`, `iri`, `retrieval_pass`,
   `retrieval_query` and identity fields (`R/semantics-helpers.R:251-289`); and
   the bundle prompt asks the model to preserve each candidate's native type,
   which a harness cannot do unless the packet carries it. §2.4 has the full
   record.
3. **The system prompts cannot be copied in verbatim.** Every one is a
   JSON-response contract, R's and Python's differ in content, and the bundle
   prompt is surface 2 of the role contract
   (`tests/testthat/test-role-contract-guard.R:109-135`), so the vendored
   instructions inherit that guard. The judgement-policy sentences carry over
   from R verbatim; the output sentences are rewritten for a CSV.
4. **Parity row 31 is about `apply_semantic_suggestions(strategy = "llm")`, not
   about ingestion,** and its R-side justification cites a function that does
   not exist (the real one is `.ms_validate_llm_assessment()`,
   `R/llm-semantic-helpers.R:1779-1860`). Each language has only one of the two
   guards: R clears the index on a non-accept decision but derives
   `llm_selected` from the index alone; Python keeps the index but requires
   `accept` in the merge and in apply. Converging it covers three layers:
   validation, merge and apply.
5. **Byte-identical packets from real packages are not reachable.** Ranking
   differs (rows 32 and 39), text extraction from PDF, DOCX, XLSX and HTML is
   library-specific, and context chunking differs in ways neither register
   records: R cuts 2200-character chunks with 200 of overlap, scores by token
   set and keeps 4 excerpts; Python cuts 1400 with no overlap, scores by
   substring, keeps 8 and collapses whitespace. §2.7 sets the bar that is
   reachable.
6. **Row 39's "metasalmonpy has no retry pass" is stale.** Python does retry
   (`llm_review.py:1142-1423`); its merge sorts on score only and dedupes on
   `source, iri, label`, where R's uses seven keys.
7. **The validators the ruling keeps are not at parity, and no row says so.**
   R's dimension classifier covers area, volume, flow and speed with compound
   rules; Python's covers none of that. Field anchors differ, R's
   method-evidence pattern has two alternatives Python lacks, and the two split
   role hints differently. Shared ingest fixtures fail until these converge.
8. **Four latent defects, confirmed by probe, that the ingester must not
   inherit.** A downgrade with no rationale writes the literal text `NA Model
   returned accept without…`; a `reject_shortlist` carrying a stray
   out-of-range index becomes `review`, so its gap is never escalated; an index
   of `1.9` truncates to candidate 1; and Python's row normalizer reads the
   string `FALSE` as true, so it cannot read a persisted CSV.
9. **Escalation differs between the languages.** R escalates a
   `reject_shortlist` only when the decision before the retry was also a
   rejection, so `retry_search` followed by `reject_shortlist` is stored as a
   dead end, which contradicts `AGENTS.md`'s rule that an unresolved rejection
   escalates to `request_new_term`. Python escalates any final rejection.
10. **"The only API-key and HTTP-client path" holds for model providers only.**
    `find_terms()` reads `BIOPORTAL_APIKEY` and calls `httr`; `httr2` serves the
    version check, GitHub, schema and KNB code; `requests` is used across
    metasalmonpy. What leaves is the only model-provider credential and the only
    chat-completions client. The deletion inventory in §9 is scoped to that.
11. **`R/cli-safety.R` and `text_safety.py` are shared infrastructure,** used by
    18 R files and 7 Python modules. They stay.
12. **`find_terms()` makes network calls,** so "the exporter makes no network
    call" is true only for in-memory input or an injected `search_fn`. §7.3
    states the claim that can be proven.

Two further stale claims turned up in `knowledge/orientation.md` and are fixed
in its own change: `detect_semantic_term_gaps()` *does* consume the assessments
(`R/term-request-helpers.R:100`, `:274-279`), and `.ms_context_tokens()`
lowercases before its camelCase split, so that split never fires.

## 1. What the in-package review path does today

### 1.1 The record

`.ms_llm_assessment_cols()` (`R/llm-review-adapter.R:1-34`) and Python's
`LLM_ASSESSMENT_COLUMNS` (`llm_review.py:24-55`) list the same 30 columns in the
same order:

- identity, which is the join key: `dataset_id`, `table_id`, `column_name`,
  `code_value`, `dictionary_role`, `target_scope`, `target_sdp_file`,
  `target_sdp_field`, `search_query`;
- judgement: `llm_provider`, `llm_model`, `llm_decision`, `llm_confidence`
  (double), `llm_selected_candidate_index` (integer), `llm_selected_iri`,
  `llm_selected_label`, `llm_rationale`, `llm_missing_context`,
  `llm_bundle_summary`;
- retry and new-term notes: `llm_retry_query`, `llm_new_term_label`,
  `llm_new_term_definition`, `llm_new_term_namespace`, `llm_context_sources`;
- bookkeeping: `llm_exploration_used` (logical), `llm_exploration_queries`,
  `llm_exploration_candidate_gain` (integer), `llm_error`,
  `llm_escalated_from`, `llm_retry_query_rejection_reason`.

The row carries no target key and no packet id. Two builders make every row,
`.ms_llm_review_empty_assessment()` and `.ms_llm_review_success_assessment()`,
and every row leaves through one normalizer, `.ms_llm_normalize_assessment_rows()`,
which aborts the whole frame if one cell cannot be cast. Python's equivalents
are `_base_assessment`, `_error_assessment` and `normalize_assessment_rows`.

### 1.2 Where the review payload is built

| Piece | R | Python |
|---|---|---|
| The 19 target columns | `.ms_semantic_discover_targets()` | inline in `suggest_semantics()` |
| Shortlist | `.ms_retrieve_semantic_target_candidates()` via `.ms_search_once_per_call()` | an inline loop; no function exists |
| Generic payload | `.ms_llm_target_payload()`, `.ms_llm_candidate_payload()`, `.ms_llm_context_payload()` | `_target_payload`, `_candidate_payload` |
| Which targets are bundles | `.ms_semantic_bundle_review_targets()` | inside `assess_semantic_suggestions` |
| Bundle payload and `current_slots` | `.ms_semantic_bundle_payload()` | `_bundle_payload` |
| Context excerpts | `.ms_collect_context_chunks()`, `.ms_prepare_context_chunks()`, `.ms_score_context_chunks()` (whose `order()` is not radix) | `load_context_chunks`, `_relevant_context` |
| System prompts | generic, decomposition, batch, exploration and bundle | generic and bundle only |

R has five review paths (generic, decomposition, batch, exploration re-review
and chat); Python has two.

### 1.3 Validation, escalation and exploration

R's `.ms_validate_llm_assessment()` lowercases the decision, maps
`propose_new_term` to `request_new_term`, aborts on a decision outside the
five-word vocabulary or a confidence outside [0, 1], downgrades to `review` with
a note on an `accept` without an index, an out-of-range index, or a
`retry_search` without a query, and clears the index on any non-accept
decision. Python's `_validate_item()` clamps confidence instead of aborting,
keeps the index on non-accept decisions, adds no downgrade notes and has no
downgrade for a query-less `retry_search`.

Escalation of `reject_shortlist` to `request_new_term` is
`.ms_llm_escalate_unresolved_rejection()` and
`.ms_semantic_bundle_escalate_rejections()` in R and `_escalate_reject_shortlist()`
in Python, with the precondition that differs (§0.9). R's generic path also
*explores* — asks the model for alternate queries — on low-confidence answers
of several kinds; Python retries only on `retry_search`.

### 1.4 The bundle validators

`.ms_semantic_apply_bundle_validators()` (R) and `_apply_validators()` (Python)
raise seven codes: `SEM_METHOD_EVIDENCE_REQUIRED`,
`SEM_MODIFIER_EVIDENCE_REQUIRED`, `SEM_CONSTRAINT_EVIDENCE_REQUIRED`,
`SEM_ROLE_TYPE_MISMATCH`, `SEM_DIMENSION_MISMATCH`,
`SEM_PROPERTY_UNIT_DIMENSION_MISMATCH` and `SEM_REDUNDANT_CATCH_CONTEXT`. A
finding turns `accept` into `review`, clears the selection, keeps the
confidence and appends `[CODE] message` to the rationale. The findings frame
has nine columns (`dataset_id`, `table_id`, `column_name`, `code`, `severity`,
`role`, `before_decision`, `after_decision`, `message`). The validators read
the candidate rows, the dictionary row and field-anchored context text, run on
measurement bundles only and run after retry and escalation.

### 1.5 The merge and the retry pass

`.ms_semantic_merge_llm_assessments()` left-joins on the nine identity columns,
caps `llm_candidate_rank` at `top_n`, and sets `llm_selected` when the index
equals the rank; Python's merge does not cap the rank and does require
`accept`. The retry retrieves a second shortlist with `retrieval_pass = 2`,
merges it with `.ms_merge_semantic_target_candidates()` (a radix sort on seven
keys, deduplicated by identity) and counts the gain; the bundle retry
reassesses only the roles that gained candidates, for at most one round. The
retry-query classifier marks a duplicate of the original query, and an
identifier-like query triggers a model call for a replacement query.

### 1.6 Attributes and accessors

`suggest_semantics()` attaches `semantic_suggestions` and `semantic_targets`
always, `semantic_llm_assessments` when `llm_assess = TRUE` (an empty 30-column
frame when there are no targets), and `dwc_mappings` when asked. Findings ride
as a `semantic_validator_findings` attribute on the assessments. The accessors
accept a dictionary, an artifact list or a path; `semantic_suggestions(path)`
reads the package's `semantic_suggestions.csv`, and `semantic_llm_assessments(path)`
returns NULL.

### 1.7 What is written into the package directory

`create_sdp()` writes the managed set (`datapackage.json`, the four metadata
CSVs, `data/*`, `.metasalmon-package`), `README-review.txt` and
`semantic_suggestions.csv`, and never an assessment. `review_semantics()` writes
nothing; `apply_sdp_semantics()` rewrites the metadata CSVs, the decision
columns of `semantic_suggestions.csv` and `datapackage.json`.
`chat_decomposition()` writes its sessions under the user's state directory,
outside the package.

### 1.8 The public surface of the in-package call

The same eleven arguments, in `.ms_llm_arg_names()` order — `llm_assess`,
`llm_provider`, `llm_model`, `llm_api_key`, `llm_base_url`,
`llm_reasoning_effort`, `llm_top_n`, `llm_context_files`, `llm_context_text`,
`llm_timeout_seconds`, `llm_request_fn` — sit on `suggest_semantics()`,
`infer_dictionary()`, `infer_salmon_datapackage_artifacts()` and `create_sdp()`
in both languages. `chat_decomposition()` carries six `chat_*` arguments.
`apply_semantic_suggestions(strategy = "llm")` only consumes `llm_*` columns and
stays. R reads nine environment variables for model, key, base URL and
reasoning effort; Python reads a `{PROVIDER}_MODEL` and `{PROVIDER}_BASE_URL`
per provider plus the four key variables, and defaults the OpenAI model to
`gpt-5-mini` where R aborts without one. CI blanks the four key variables in
both repositories.

## 2. The exporter

### 2.1 Signature

One argument set in both languages, with no model argument of any kind: the
package directory or an in-memory dictionary carrying `semantic_targets` and
`semantic_suggestions`; `context_files` and `context_text` under the same
path-only contract as today's `llm_context_files`; `top_n = 5` as both the
shortlist shown and the retrieval depth; `sources` with role defaults when
omitted; `search_fn` (used only for a package path); `review_dir` (default
`<package>/review`, required for in-memory input); `overwrite = FALSE`; and
`quiet = FALSE`. It returns the packet's path, its `packet_id`, the pass, and
the unit and target counts.

### 2.2 Which targets a packet holds

**For a package path, exactly the queue `review_semantics(path)` would show,**
never a fresh discovery: writable targets in `column_dictionary.csv`,
`codes.csv` or `tables.csv` with an `*_iri` field, whose current value is blank
or `REVIEW:`-marked, and whose slot has no recorded decision; hand-picked
(`source = "user"`) rows are dropped. That rule moves out of
`review_semantics()` into one helper both functions call. Each target is then
re-retrieved at depth `top_n` with its recorded `search_query`, the precedent
`write_sdp_semantic_closure()` already follows. Re-running discovery instead
would silently drop every slot `create_sdp()` pre-filled with a `REVIEW:`
marker, because the discovery code treats a marked slot as filled.

**For in-memory input,** the targets and candidates are the dictionary's own
attributes and no retrieval runs.

**Units.** A column passing `.ms_semantic_bundle_review_targets()` becomes one
bundle unit; every other target is its own unit, including targets with no
candidates (Python includes them today and R does not). R's routing of
measurement-like non-bundle targets to the decomposition prompt is dropped;
the instructions carry the whole policy.

### 2.3 What it reuses

It is mostly a move. Package reading, retrieval (the source policy, the
shortlist retriever, the once-per-call search cache and the role-collision
block of `suggest_semantics()`, extracted), unit assembly (the bundle helpers
and `current_slots`), context (the three chunk helpers, with the scorer made
radix and the limit fixed at 4), and rendering and writes (the number-token
formatter, the containment check and the atomic writer). Python first extracts
its inline retrieval loop into a function, the same loop B-243 concerns. New
code is the canonical JSON emitter, unit assembly and the `packet_id`.

### 2.4 The packet

Every object has a fixed key order, recorded in the schema. At the top:
`packet_version` (`semantic-review-packet/1.0`), `packet_id`, `pass` (1 or 2),
`parent_packet_id`, `producer` (implementation, version, function), `pins`,
`instructions`, `decision_vocabulary` and `decision_aliases`, `output` (the file
the harness writes and the 30 columns with an owner and a requiredness for
each), `context` (the inputs with their SHA-256 and the chunking parameters),
and `units`.

A **bundle unit** carries its key, the dictionary context (labels, description,
role, value type, unit label), `current_slots` for the six measurement roles,
and one slot per role with its status, current value, slot id, the nine
identity columns, the 19 target columns and its candidates; then the context
excerpts. A **target unit** carries the same for one slot.

A **candidate** carries, in order: `index` (1-based), `label`, `iri`, `source`,
`ontology`, `role`, `match_type`, `definition`, `term_type`, `resource_kind`,
`type_iris`, `native_type`, `role_hints`, `role_hint_status`, `role_hint_bonus`,
`lexical_score`, `alignment_only`, `agreement_sources`, `retrieval_query`,
`retrieval_pass`, `role_collision`, `role_collision_note`, and `extra` for every
other candidate column, keys in C order. There is no candidate id: selection is
by index, because the two languages fingerprint a blank-IRI candidate
differently. Units sort by key in C collation; candidates keep retrieval order.

**The instructions are one vendored file,** byte-identical in both packages:
R's policy sentences verbatim, the bundle and target policies, what each of the
five decisions means, and the output rules — copy the identity exactly, echo the
IRI on accept, leave package-owned columns empty, write with a CSV library,
never edit the packet.

### 2.5 Pins, stated honestly

The SDP profile version comes from the vendored bundle, never from the default
remote-first loader, which is Q53's problem. **Nothing pins an ontology today:**
`find_terms()` reads live endpoints, and the only pins in the ecosystem are the
Theme A fixture manifests. So the packet says `pinned: false` and records the
sources used and, for a package path, the sources that failed. The ranking
identity is R's `.ms_ranking_identity()` for a package path and null
otherwise; Python writes null, per row 39. No packet carries a timestamp, an
absolute path, a hostname or a random id.

### 2.6 Where it is written

`<review_dir>/semantic-review-packet.json`, rendered to bytes first and
installed atomically after the containment check. If a record already exists in
`review/`, the exporter refuses unless `overwrite = TRUE`, and then deletes that
session's derived files.

### 2.7 Determinism, and the bar that is reachable

**Within one language,** the same inputs give the same bytes on any locale and
platform: both new functions and the unit sorter join
`collation_sensitive_fns`, the emitter is named so that guard's pattern catches
it, and the context scorer becomes radix. **One value, one rendering:** strings
as they are, non-integer numbers through the shared number-token formatter
(rows 36 and 59 already record the pair as agreeing), integers as integer
literals, logicals as `true`/`false`, NA and non-finite values as `null`. The
existing extension JSON writer is not reused, because its `digits = NA`
rendered `0.1 + 0.2` as `0.3` in a probe, which does not round-trip.

**Across languages, the recommended bar is byte identity except the `producer`
member,** on shared fixtures with injected candidates and text-only context.
`packet_id` is the SHA-256 of the canonical serialisation with `packet_id` and
`producer` removed, so it is the same in both languages and is an integrity
check at ingest. That needs a small canonical emitter on each side, because
the default JSON libraries disagree on arrays, `0.3` and `2`: UTF-8 with no BOM
and a trailing LF, two-space indent, one member per line, empty containers
inline, and only `"`, `\` and U+0000–U+001F escaped. The context algorithm is
then made identical too: R's extension list, R's text extraction for text
formats (UTF-8, then cp1252, then latin-1; CRLF to LF; front matter and fences
dropped; no whitespace collapsing), R's source labels and chunk ids, and ASCII
lowercase tokens of three or more characters. Text extracted from PDF, DOCX,
XLSX and HTML may still differ by library, recorded as an Idiom row. **The bar
that matters most either way** is that any packet plus any assessment file gives
identical ingest results in both languages.

## 3. The ingester

### 3.1 Signature

The package directory or the in-memory object the packet was built from; the
assessment file (a CSV path or a data frame, defaulting to the pass's file in
`review/`); the packet (defaulting to the latest pass); an optional expected
`packet_id`; optional `provider` and `model` overrides for columns 10 and 11;
`search_fn` for the retry; `review_dir`; and `quiet`.

### 3.2 The assessment file

UTF-8 with a leading BOM stripped, read with the packages' own metadata CSV
readers (every column character, whitespace trimmed, the empty field the only
missing value), and a header that is exactly the 30 columns in order.

| Columns | Owner | Rule |
|---|---|---|
| 1–9, identity | harness copies | must equal the target's identity exactly; empty equals null |
| 10–11, provider and model | harness, unless overridden | non-empty after any override |
| 12–13, decision and confidence | harness | both required |
| 14, index | harness | required for `accept`, ignored otherwise |
| 15, selected IRI | harness echoes; package overwrites | required echo for `accept` |
| 16, selected label | package | overwritten from the packet |
| 17, rationale | harness | package notes are appended |
| 18–19, 21–23, notes and new-term fields | harness | optional; new-term fields forbidden with `accept` |
| 20, retry query | harness | required for `retry_search` |
| 24, context sources | package | from the unit's excerpts |
| 25–27, exploration | package | set by the retry bookkeeping |
| 28, error | harness may declare one; else package | |
| 29–30, escalation and rejection reason | package | |

A harness value in a package-owned column is overwritten, with one warning
naming the columns; harness text quoted in any message goes through the cli
escaping helpers.

### 3.3 Validation, in order

**A file-level problem aborts the ingest and writes nothing,** with a stable
code both languages test the same way: `packet_version`, `packet_integrity` (the
recomputed `packet_id` does not match), `packet_mismatch`, `header`,
`unknown_target`, `duplicate_target`, `provenance` and `no_pass_2`.

**A row-level problem makes that row an error row or downgrades it with a
note, and processing continues:**

1. A harness-declared `llm_error` makes an error row carrying that text,
   redacted.
2. The decision is lowercased and trimmed, `propose_new_term` read as
   `request_new_term`; anything else is an error.
3. The confidence must be a decimal in [0, 1]; no clamping.
4. A non-accept decision has its index, echo and label cleared, *before* any
   range check, which removes the defect where a rejection with a stray index
   became `review`.
5. An `accept` whose echoed IRI is not a candidate for the target is an error.
   This is the rule that makes "an IRI absent from the packet is never applied"
   enforceable.
6. An `accept` without an index downgrades to `review`.
7. An index that is not a whole number is an error; there is no truncation.
8. An out-of-range index downgrades to `review`.
9. An `accept` with no echoed IRI downgrades to `review`.
10. An echo naming a different candidate from the index is an error.
11. An `accept` with any new-term field is an error.
12. A `retry_search` with no query downgrades to `review`.

Notes join with one space and never start with `NA `. A packet target with no
row gets an error row saying no assessment was supplied.

### 3.4 After validation

**Retry classification** uses R's classifier. A duplicate keeps its existing
reason; an identifier-like query gets a new reason, `identifier_like_query`,
since there is no longer a model call to replace it; a usable query goes to the
second pass (§4). **Escalation:** a final `reject_shortlist` becomes
`request_new_term` with the selection cleared and `llm_escalated_from` set; the
rule that decides "final" is decision 10 in §10. **Validators** run for every
bundle unit, rebuilt from the packet, at every ingest; findings only grow as
more roles are accepted, so a later pass never reverses an earlier one.

### 3.5 Merge and persistence

The merge sets `llm_selected` only for an `accept` (R changes) and caps the rank
at `top_n` (Python changes). The ingester writes, as one atomic set after the
containment check: the harness file as received, `review/semantic-llm-assessments.csv`
(the record, one row per pass-1 target, numbers through the shared formatter,
logicals as `TRUE`/`FALSE`, NA as empty), `review/semantic-validator-findings.csv`,
the pass-2 packet when a retry gained candidates, and, for a package path, the
rows of `semantic_suggestions.csv` for targets whose slots are still undecided.
Decisions, decision reasons and hand-picked rows are preserved, and a slot
decided between build and ingest keeps its rows. `semantic_llm_assessments(path)`
then reads the typed record with the findings attached. **The ingester never
touches the metadata CSVs:** applying a choice stays `review_semantics()` →
`accept_suggestion()` → `apply_sdp_semantics()`.

### 3.6 Return value

A status (`complete` or `awaiting_pass_2`), the pass, the `packet_id`, the next
packet when there is one, the assessments with their findings, the suggestions,
the targets, the dictionary with those attributes attached so
`detect_semantic_term_gaps()` and the accessors work unchanged, and a summary of
decisions, errors, downgrades, escalations and retries.

### 3.7 Why the 30-column shape cannot drift

Every row comes from one of the two builders and leaves through the one
normalizer, the persisted header is `.ms_llm_assessment_cols()`, and tests assert
that error, downgraded, escalated and success rows carry identical names and
types and validate against the vendored row schema.

## 4. The second pass

This is what "a retry is a second harness pass" in `B-326` means in detail.

1. **At pass 1,** each `retry_search` with a usable query is retrieved again
   inside the package, under the packet's source policy and depth, through the
   once-per-call search, with `retrieval_pass = 2`, and merged with R's merge,
   which Python ports. Every retried row records that it explored, the query
   and the gain. No gain: the row stays `retry_search` and is final. A gain:
   the unit goes into the pass-2 packet and the status is `awaiting_pass_2`.
2. **The pass-2 packet** has the same schema with `pass: 2` and the parent's id.
   A bundle unit marks only the roles that gained candidates for reassessment;
   each slot carries its full pass-1 row and each bundle its pass-1 findings, so
   pass 2 can be re-ingested with the same result. Context excerpts are reused
   verbatim from pass 1, so validator evidence stays stable.
3. **At pass 2,** a usable answer replaces the pass-1 row and switches the
   target to the merged candidates; an error or a missing answer keeps the
   pass-1 row and candidates, so the index still maps. Escalation runs, affected
   bundles are re-validated and the status becomes `complete`. A `retry_search`
   answered at pass 2 is final: there is no third pass.

The harness never supplies an IRI, only queries, which is what keeps the ingest
rule in §3.3 item 5 enforceable.

## 5. Where the files live, and the specification

[Q11](../questions.md) put `metadata/semantic/**` under `smn-data-pkg`, so the
packet cannot go under `metadata/`. `reproducibility/` is closed over its exact
contents, so an undeclared file there breaks its manifest and KNB publication.
**`review/` needs no specification change:** the specification designates no
project-specific assessment locations and already says nothing about
`README-review.txt` or `semantic_suggestions.csv`; KNB publication never
discovers extra files, validation checks only what it recognises, and the
managed-path inventory leaves `review/` alone, so an ordinary rewrite keeps it.
`prune = TRUE` would delete it silently, so the existing warning about pruning
recorded decisions extends to a record in `review/`, in both languages. The
packet holds excerpts from the user's own context documents and is never
published, which the documentation says.

## 6. Deprecating the in-package call

The deprecation fires on `suggest_semantics()`, `infer_dictionary()`,
`infer_salmon_datapackage_artifacts()` and `create_sdp()` whenever
`llm_assess = TRUE` or any `llm_*` argument is supplied (R detects this with
`missing()`; Python, which cannot, with any non-default value), and on every
call to `chat_decomposition()`. It names the removal release and the
replacement. R uses a classed `cli_warn` (`metasalmon_llm_deprecated` with
`deprecatedWarning`), like the existing EDH deprecations; Python a
`FutureWarning` subclass so end users see it. **The opt-in contract is
untouched:** context supplied without `llm_assess` still warns that it is ignored
and makes no call; there is exactly one deprecation warning per top-level call,
emitted after the existing opt-in warnings, which one test asserts come first;
and a suite-wide quiet switch (an option in R, a warnings filter in Python)
keeps every existing test byte-identical, while new tests switch it on and
assert one warning per entry point, none on the default path, one even with
`seed_semantics = FALSE`, and one from `chat_decomposition()`.

## 7. Tests

### 7.1 Shared fixtures

The canonical copies live in metasalmon: the packet schema (with definitions for
the packet, the assessment row and the findings row), the instructions file, and
`tests/testthat/fixtures/semantic-review/v1/` holding a manifest of SHA-256s, a
fake search function's responses, and per-case builder input, the golden
pass-1 packet, a pass-1 assessment file and the expected record, findings,
suggestions and status, plus the pass-2 files where a case retries. Reject
cases carry the expected error code. metasalmonpy vendors all of it verbatim;
each side checks its copy against the manifest; metasalmonpy's parity job,
which already clones metasalmon and runs R, also diffs the two trees and runs
build-in-R/ingest-in-Python and the reverse. Expected CSVs are compared after
reading, not as bytes.

### 7.2 The Theme A fixtures as ingest oracles

Builder input comes from the Theme A cases, harness files from the replay rows'
harness-owned columns plus the IRI echo, and the check compares oracle
*events* after ingest and the downstream prefill step with the recorded
required, allowed and forbidden oracles — events, not rows, because the replay
rows carry fixture provenance the ingester recomputes. Three adversarial
variants show the deterministic layer protecting the record whatever the
harness says: accepting the fork-length method for `catch_count` still fails
the forbidden rule through `SEM_METHOD_EVIDENCE_REQUIRED`; accepting
`CatchContext` with `CatchAbundance` still raises `SEM_REDUNDANT_CATCH_CONTEXT`;
and a `reject_shortlist` on `synthetic_structured_gap` still surfaces the gap
through escalation. These fixtures predate sdp-0.3.0; refreshing them as v2 is
separate work.

### 7.3 The sentinel

The claim that can be proven is **no model-provider call ever, and no network
except through `search_fn`.** A test helper mocks every provider entry point and
the HTTP clients to stop, and pins the vendored schema source. The matrix: an
in-memory build with a stopping `search_fn` succeeds; a package build with a
counting fake calls it once per distinct query, role and source set; an ingest
with no retry never calls it; an ingest with a retry calls it once per usable
query. A static guard walks the call graph from the two new functions and
asserts no provider symbol is reachable. Python's fixture raises on the provider
entry points, on `requests` sessions and on `socket.connect`, and an AST check
keeps the new module free of `requests` and the provider code.

### 7.4 Guards to extend

`collation_sensitive_fns`; surface 2 of the role contract, which must also read
the vendored instructions' judgement sentence in both languages; the public-API
test and the pkgdown index, which fails on an unindexed export; and the
cli-safety guard, which walks the namespace itself.

## 8. Parity consequences

**Rows amended in the same pull requests, in both registers:** 31 (the accept
rule in merge and apply, the phantom function name, and Python's
accepted-and-ignored `min_llm_confidence`); 39 (its retry half is stale, and the
merge half converges for the new path); 37 (a harness-declared error is captured
text, so it is redacted); 45 (narrows now, as Python gains the Theme A oracles
through the shared fixtures, and retires with the capture harness); 44 is
unchanged until the removal.

**New rows owed:** one *legacy* row for every unregistered difference in the
deprecated in-package path (chunking and scoring, validator semantics,
exploration, the escalation precondition, zero-candidate targets, shortlist
depth, request bodies, environment variables), retiring at the removal; an
*Idiom* row for the packet's `producer`, schema enforcement and how the
deprecation is detected; a permanent *Idiom* row for library-specific text
extraction; and a *Gap* row for validator convergence (§0.7) until Python
converges, which has to happen in the same release for the fixtures to pass.

**Also owed in the same pull requests:** `NEWS.md` and `CHANGELOG.md`; both
`AGENTS.md` files (the file contract, column ownership, the `review/` location);
the roadmap's release index; both `docs/entrypoints.md`; the documentation of
`semantic_llm_assessments(path)`; and the pull-request template's statement that
the instructions carry the existing policy verbatim and no IRI choice changed.

## 9. What the breaking release deletes

**metasalmon:** the provider presets and configuration, the retry stack, the
opt-in warnings, the prompts and message builders, the exploration and
decomposition routing, the transport and the orchestration in
`R/llm-semantic-helpers.R`, keeping the context parsing, payload helpers, the
retry-query classifier, escalation (under the new rule) and the fixed
validation; the request half of `R/llm-review-adapter.R`; the model half of
`R/semantic-bundle-review.R`; all of `R/chat-decomposition.R` and the
chat-only part of `R/semantic-suggestions.R`; the eleven `llm_*` arguments and
the `chat_decomposition()` export and page. `suggest_semantics()` stops
attaching `semantic_llm_assessments`, which is an attribute contract in
`AGENTS.md` and is cited as ruled. DESCRIPTION loses nothing: `httr`, `httr2`,
`pdftools` and `readxl` are still used. Tests: the decomposition and
offline-credential setup files go; the request-builder test is inverted into a
guard that no builder exists; the provider, retry, batch, exploration and
opt-in tests go; the context, validation and escalation tests are retargeted at
the builder and the ingester; the capture and cohort half of the Theme A script
goes and the replay half stays (`B-328`); `scripts/llm-sanity-check.R` goes;
and the provider-key blanks leave the workflows. Vignettes, README,
`docs/entrypoints.md`, the orientation card and two `AGENTS.md` bullets change
with it. The nine R environment variables stop being read.

**metasalmonpy:** the same scope in `llm_review.py`, all of
`chat_decomposition.py` and its exports, the same eleven arguments, the retry
and decomposition tests, the per-provider model and base-URL variables and the
four key variables, the workflow blanks, and the matching guides, reference
pages and entry points. `requests` and the `[context]` extra stay. The release
notes mention the session directories left under the user's state directory.

**The queue and the other repositories:** `B-128`, `Q-54` and `B-226` close as
moot, `B-31` retires with the removal, and `B-80`, `B-129` and the `llm_top_n`
part of `B-57` are rescoped; `B-22` stays, because the merge helper survives.
The workshop's session 5 changes under `B-331`. The plugin's metasalmon skill
gains packet and ingest actions, outside this hub. Rows 44, 45 and the legacy
row retire.

## 10. Decisions that were Brett's — ruled 2026-09-25: every recommendation taken

Put to him the day this plan was written, with the recommendation for each;
he chose *"Take all recommendations"*. Each line below is therefore now the
ruling, and the recommendation text is kept as it was put to him.

1. **Names.** Every `read_*` in the package is a pure reader, and this one
   writes files and can retrieve. Recommended: `write_semantic_review_packet()`
   and `ingest_semantic_assessments()` — his ruling says "ingester".
2. **Paths.** Recommended: `review/semantic-review-packet.json`, its `-pass-2`
   twin, `review/semantic-assessments-pass-<n>.csv` for what the harness writes,
   `review/semantic-llm-assessments.csv` for the record and
   `review/semantic-validator-findings.csv`.
3. **The version train.** Recommended: the additive release as 0.6.0 in both
   packages, tagged together; the removal as 0.7.0 after at least one tagged
   0.6.x.
4. **The cross-language bar.** Recommended: byte identity except `producer`,
   with a small hand-written emitter on each side (§2.7).
5. **Who runs the pass-2 retrieval.** Recommended: the ingester, so the harness
   loop is one call per turn. The alternative, a retry mode on the builder,
   keeps ingest always offline at the cost of an extra harness call.
6. **The IRI echo on accept.** Recommended: required, a missing echo downgrading
   to `review` and a mismatch an error.
7. **Ingest rewrites `semantic_suggestions.csv`.** Recommended: yes; otherwise
   `review_semantics()` never sees the harness's judgement.
8. **Prefill.** Recommended: none; the metadata CSVs keep one writer.
9. **Validator convergence (§0.7).** Recommended: converge on R's validators,
   with Python moving: they are the richer and more recently hardened set. This
   is a direction ruled per divergence, as `AGENTS.md` requires, not an "R
   leads" default.
10. **The escalation rule (§0.9).** Recommended: any final `reject_shortlist`
    escalates, with R moving, because R's rule contradicts `AGENTS.md`.
11. **The four latent defects (§0.8), fixed in the shared code,** so the legacy
    path is fixed too. Recommended: yes.
12. **The new rejection reason `identifier_like_query`.** Recommended: yes.
13. **Targets with no candidates in the packet.** Recommended: include them.
14. **Dropping decomposition routing for non-bundle targets.** Recommended: yes.
15. **Row 31's column-presence requirement in R.** Recommended: at the removal
    release.
16. **One legacy row, or one row per difference.** Recommended: one, since they
    share one retirement.
17. **Deprecation mechanics (§6).** Recommended: as written.
18. **A note in `smn-data-pkg` that tool working directories such as `review/`
    are not canonical.** Recommended: optional and not blocking.
19. **At the removal, the Theme A historical-observations evidence file and the
    `semantic_llm_assessments` element of the artifact list.** Recommended: keep
    the evidence file as frozen history, and keep the list element as NULL for
    one release.

## 11. Build order

1. **Convergence first,** one item each: metasalmonpy's validators converge on
   R's (`B-360`); R escalates any final rejection and fixes its three
   assessment defects (`B-361`); metasalmonpy reads a persisted `FALSE`
   correctly and ports R's retry-query classifier (`B-362`); metasalmonpy's
   retrieval loop becomes a function and ports R's merge (`B-363`); and
   metasalmonpy ports R's context algorithm (`B-364`).
2. **The schema, the instructions and the fixtures** land in metasalmon.
3. **The two implementations,** `B-326` and then `B-327`, which vendors the
   contract and fixtures `B-326` lands.
4. **Deprecations, documentation and the registers.**
5. **Both packages tagged together** at the number decision 3 sets.

*Retires when:* `B-326` and `B-327` are done, at which point this plan is a
record of how the contract was decided rather than of what is still to do.
