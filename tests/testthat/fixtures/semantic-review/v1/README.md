# Semantic review packet conformance fixtures, v1

One contract shared by metasalmon and metasalmonpy (hub items B-326 and
B-327, S16 step 1): the packet a package writes for a harness to judge, the
30-column assessment file the harness writes back, and what the package
records after ingesting it. metasalmonpy vendors this directory verbatim;
each side checks its copy against `manifest.json`, and metasalmonpy's parity
job diffs the two trees. The packet schema is
`inst/extdata/semantic-review/semantic-review-packet-v1.schema.json` and the
instructions file beside it; every packet here embeds those instructions.

Regenerate with `Rscript scripts/build-semantic-review-fixtures.R` from the
repository root. A change in a packet's bytes is a change to the contract.

## Layout

- `manifest.json`: `fixture_version`, `packet_version`, and the SHA-256 of
  every other file, keyed by path in C order.
- `search-responses.json`: the fake search function's answers for the retry
  cases, keyed by `<query>|<role>`, as the rows a real retrieval returns.
  A query with no entry returns nothing.
- `cases/<case_id>/`:
  - `input.json`: the in-memory builder input: `dictionary` rows, the
    19-column `targets`, the `candidates` (suggestion rows stamped with their
    target's columns), `context_text` and `top_n`. Every case is in-memory
    with injected candidates and text-only context, which is the bar for
    cross-language byte identity.
  - `packet-pass-1.json`: the golden packet. Compare with the `producer`
    member removed; `packet_id` excludes it already.
  - `assessments-pass-1.csv` and `assessments-pass-1.csv.packet-id`: the
    harness file and the sidecar naming the packet it judged.
  - `expected/record-pass-1.csv`, `findings-pass-1.csv`,
    `suggestions-pass-1.csv`: what the ingester returns and persists.
    Compare after reading, not as bytes: every cell as text, the empty field
    and null one value, numbers through each side's number-token formatter.
    **`llm_error` is compared for presence, not words**: an error row's text
    is worded by each implementation (parity row 63).
  - `expected/status-pass-1.json`: `status`, `pass`, `packet_id`,
    `has_next_packet`, the `summary` counts and `search_calls`, the number
    of times the ingester called the search function.
  - `packet-pass-2.json`, `assessments-pass-2.csv` (+ sidecar) and the
    `expected/*-pass-2.*` files where a case retries and gains candidates.
  - `expected/events.json` for the Theme A cases: the oracle events after
    the downstream prefill step, built the way `scripts/theme-a-benchmark.R`
    builds them (`assessment`, `selection`, `prefill`, `gap`, `routing`),
    plus the prefilled dictionary rows and the gap and request counts.
    Evaluate them against `tests/testthat/fixtures/theme-a/cases-v1.json`'s
    oracles.
- `cases/file_errors/`: the file-level rejections. `reject.json` lists each
  variant with its `expected_code`; a variant names an assessments file, a
  packet file, or an `expected_packet_id` argument. The base case's packet is
  built first and each variant is ingested against it; every variant must
  abort with its code and write nothing.

## The cases

| Case | What it pins |
|---|---|
| `bundle_accept` | A measurement bundle, every slot accepted, no findings. |
| `bundle_validator_downgrade` | A unit accept the validators refuse (`SEM_DIMENSION_MISMATCH`, `SEM_PROPERTY_UNIT_DIMENSION_MISMATCH`): downgraded to review, findings recorded. |
| `target_units` | Target units: a categorical column, a code value, a table's observation unit, a slot with no candidates. |
| `retry_gain` | A `retry_search` whose query gains candidates: `awaiting_pass_2`, a pass-2 packet, then an accept at pass 2. |
| `retry_dead_ends` | A duplicate query (`duplicate_original_query`), an identifier-like query (`identifier_like_query`), and a usable query that gains nothing. |
| `reject_escalates` | `reject_shortlist` escalates at once to `request_new_term`, including with a stray index; no second pass. |
| `row_errors` | One target per row-level rule of execplan section 3.3, plus a planted secret in `llm_error` and in a rationale, a package-owned column written by the harness, and the `propose_new_term` alias. |
| `file_errors` | `header`, `unknown_target`, `duplicate_target`, `packet_integrity`, `packet_version`, `packet_mismatch` (argument), `packet_unbound`, `stale_sidecar` (`packet_mismatch`), `no_pass_2`. |
| `theme_a_*` | The six Theme A cases as ingest oracles, and three adversarial variants: accepting the fork-length method for `catch_count` (`SEM_METHOD_EVIDENCE_REQUIRED`), accepting `CatchContext` beside `CatchAbundance` (`SEM_REDUNDANT_CATCH_CONTEXT`), and a `reject_shortlist` on `synthetic_structured_gap` that still surfaces the gap. |
