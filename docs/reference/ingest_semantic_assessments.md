# Ingest a harness's semantic assessments

The second half of the review-packet contract: reads the CSV a harness
wrote against a packet from
[`write_semantic_review_packet()`](https://salmon-data-mobilization.github.io/metasalmon/reference/write_semantic_review_packet.md),
in the frozen 30-column assessment row, and turns it into the package's
record. It refuses a selection whose IRI the packet did not offer
(recorded as an error row, never applied), runs the retry bookkeeping,
escalates a final `reject_shortlist` to `request_new_term` so the
ontology gap is surfaced, runs the existing bundle validators, merges
the result into the suggestions and persists it under `review/`, so that
[`semantic_llm_assessments()`](https://salmon-data-mobilization.github.io/metasalmon/reference/semantic_llm_assessments.md)
returns it for a package path.

## Usage

``` r
ingest_semantic_assessments(
  x,
  assessments = NULL,
  packet = NULL,
  packet_id = NULL,
  provider = NULL,
  model = NULL,
  search_fn = find_terms,
  review_dir = NULL,
  quiet = FALSE
)
```

## Arguments

- x:

  The package directory or the in-memory dictionary the packet was built
  from.

- assessments:

  The harness's file: a CSV path or a data frame. Defaults to
  `review/semantic-assessments-pass-<n>.csv` for the packet's pass.

- packet:

  The packet the file answers: a path or a parsed packet. Defaults to
  the latest pass in `review/`.

- packet_id:

  Optional. The `packet_id` this ingest expects; a different packet is
  refused with code `packet_mismatch`.

- provider, model:

  Optional overrides for the `llm_provider` and `llm_model` columns of
  every row.

- search_fn:

  The search function used for a retry. Defaults to
  [`find_terms()`](https://salmon-data-mobilization.github.io/metasalmon/reference/find_terms.md).

- review_dir:

  Where the session lives. Defaults to `review/` under the package
  directory; required for in-memory input.

- quiet:

  Logical. Suppress the summary message.

## Value

Invisibly, a list: `status` (`"complete"` or `"awaiting_pass_2"`),
`pass`, `packet_id`, `next_packet` (the continuation packet's path, or
`NULL`), `assessments` (the record, with the validator findings as its
`semantic_validator_findings` attribute), `findings`, `suggestions`,
`targets`, `dictionary` (with `semantic_suggestions`, `semantic_targets`
and `semantic_llm_assessments` attached, so
[`detect_semantic_term_gaps()`](https://salmon-data-mobilization.github.io/metasalmon/reference/detect_semantic_term_gaps.md)
and the accessors work unchanged), and `summary` (counts of decisions,
errors, downgrades, escalations and retries).

## Details

**A retry is a second harness pass.** A `retry_search` with a usable
query is retrieved here through `search_fn`, and when the search widens
the shortlist a continuation packet
(`review/semantic-review-packet-pass-2.json`) is written holding the
widened shortlist; nothing from that target is merged or escalated until
the harness has answered it. Calling this again after the harness
answers the second packet completes the session. There is no third pass.

**This never calls a model**, and it reaches the network only through
`search_fn`, for a retry. It never touches the metadata CSVs: applying a
choice stays
[`review_semantics()`](https://salmon-data-mobilization.github.io/metasalmon/reference/review_semantics.md)
-\>
[`accept_suggestion()`](https://salmon-data-mobilization.github.io/metasalmon/reference/accept_suggestion.md)
-\>
[`apply_sdp_semantics()`](https://salmon-data-mobilization.github.io/metasalmon/reference/apply_sdp_semantics.md).

A file-level problem aborts the ingest and writes nothing, with a stable
code carried as the condition's `code` field and class
`metasalmon_semantic_review_<code>`: `packet_version`,
`packet_integrity` (the packet no longer matches its `packet_id`),
`packet_mismatch`, `header`, `unknown_target`, `duplicate_target`,
`provenance` and `no_pass_2`. A row-level problem makes that row an
error row or downgrades it with a note, and processing continues.

## See also

[`write_semantic_review_packet()`](https://salmon-data-mobilization.github.io/metasalmon/reference/write_semantic_review_packet.md),
[`semantic_llm_assessments()`](https://salmon-data-mobilization.github.io/metasalmon/reference/semantic_llm_assessments.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Run in checks once a harness response fixture is bundled.
# Start with an SDP whose semantic targets are ready for review.
sdp_path <- "/path/to/reviewed-sdp"
packet <- write_semantic_review_packet(sdp_path)
# Have the external harness judge packet$path and write its 30-column
# response and a matching .packet-id sidecar in the SDP's review directory.
response <- file.path(sdp_path, "review", "semantic-assessments-pass-1.csv")
result <- ingest_semantic_assessments(
  sdp_path, assessments = response, packet_id = packet$packet_id
)
if (identical(result$status, "awaiting_pass_2")) {
  # The harness judges result$next_packet, then ingest that second response.
  second_response <- file.path(
    sdp_path, "review", "semantic-assessments-pass-2.csv"
  )
  result <- ingest_semantic_assessments(
    sdp_path, assessments = second_response
  )
}
} # }
```
