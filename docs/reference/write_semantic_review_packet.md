# Write a semantic review packet for a harness to judge

Model judgement runs outside metasalmon (ruled 2026-09-25, hub Q67).
This writes the deterministic file a harness reads: every semantic slot
that still needs a decision, each slot's ranked candidate shortlist with
the evidence the package's own validators read (label, IRI, source,
ontology, native type, role hints, term type, resource kind, type IRIs,
definition and scores), the measurement bundles with their current
slots, the scored excerpts from your context documents, the review
instructions, the decision vocabulary and the 30-column assessment
schema. The harness answers in a CSV next to the packet, and
[`ingest_semantic_assessments()`](https://salmon-data-mobilization.github.io/metasalmon/reference/ingest_semantic_assessments.md)
reads it back.

## Usage

``` r
write_semantic_review_packet(
  x,
  context_files = NULL,
  context_text = NULL,
  top_n = 5L,
  sources = NULL,
  search_fn = find_terms,
  code_scope = c("factor", "all", "none"),
  review_dir = NULL,
  overwrite = FALSE,
  quiet = FALSE
)
```

## Arguments

- x:

  A package directory written by
  [`create_sdp()`](https://salmon-data-mobilization.github.io/metasalmon/reference/create_sdp.md),
  or a dictionary carrying the `semantic_targets` and
  `semantic_suggestions` attributes that
  [`suggest_semantics()`](https://salmon-data-mobilization.github.io/metasalmon/reference/suggest_semantics.md)
  attaches (an artifact list in the
  [`infer_salmon_datapackage_artifacts()`](https://salmon-data-mobilization.github.io/metasalmon/reference/infer_salmon_datapackage_artifacts.md)
  shape is read through its `dict`).

- context_files:

  Optional character vector of local file paths whose text is chunked
  and scored against each unit, under the same path-only contract as
  `llm_context_files`: a parsed object is refused.

- context_text:

  Optional character vector of inline context text.

- top_n:

  Integer. The shortlist shown per slot and, for a package path, the
  retrieval depth. Default 5.

- sources:

  Optional character vector of vocabulary sources. When omitted, each
  role searches its default sources
  ([`sources_for_role()`](https://salmon-data-mobilization.github.io/metasalmon/reference/sources_for_role.md));
  when supplied, it is a strict allowlist.

- search_fn:

  The search function, used only for a package path. Defaults to
  [`find_terms()`](https://salmon-data-mobilization.github.io/metasalmon/reference/find_terms.md).

- code_scope:

  Which `codes.csv` values get a slot when a blank slot is recovered by
  discovery for a package path: the same choice as
  `create_sdp(semantic_code_scope = )`, whose default this shares.
  Nothing in a package records the scope it was created with, so the
  packet records the one used here, and a blank code-level slot outside
  it is reported as `not_covered` rather than silently dropped.

- review_dir:

  Where to write the packet. Defaults to `review/` under the package
  directory; required for in-memory input.

- overwrite:

  Logical. A review session that already holds answers or a record
  refuses to be overwritten unless this is `TRUE`, in which case the
  session's files are deleted first.

- quiet:

  Logical. Suppress the summary message.

## Value

Invisibly, a list with `path` (the packet file), `packet_id` (the
SHA-256 the ingester checks), `pass` (always 1 here), `units` and
`targets` (counts), and `not_covered`: the blank code-level slots the
chosen `code_scope` left out, one row each (empty for in-memory input).

## Details

**This never calls a model.** For a package path it retrieves each
slot's shortlist again through `search_fn`, which is the only way it
reaches the network; for in-memory input it makes no network call at
all.

For a package path the packet holds exactly the queue
[`review_semantics()`](https://salmon-data-mobilization.github.io/metasalmon/reference/review_semantics.md)
would show – slots in `column_dictionary.csv`, `codes.csv` or
`tables.csv` whose IRI field is blank or `REVIEW:`-marked and that carry
no recorded decision – and never a fresh discovery. For an in-memory
dictionary it holds every target in the `semantic_targets` attribute,
including targets with no candidates, with the first `top_n` candidates
of each from the `semantic_suggestions` attribute.

The packet holds excerpts from your own context documents. It is written
under `review/`, which no publication path reads, and it is never
published.

For a package path, recovering blank slots re-runs discovery over the
package's own metadata and data. A data resource is opened only when
`tables.csv` names it with a plain relative path inside the package (no
`..`, no absolute path, no symbolic link in the path); any other row is
skipped with a warning.

## See also

[`ingest_semantic_assessments()`](https://salmon-data-mobilization.github.io/metasalmon/reference/ingest_semantic_assessments.md),
[`review_semantics()`](https://salmon-data-mobilization.github.io/metasalmon/reference/review_semantics.md)

## Examples

``` r
dict <- tibble::tibble(
  dataset_id = "demo-1", table_id = "spawners", column_name = "spawner_count",
  column_role = "measurement", column_label = "Spawner count",
  column_description = "Number of spawners counted.", unit_label = "count",
  term_iri = NA_character_
)
target <- tibble::tibble(
  dataset_id = "demo-1", table_id = "spawners", column_name = "spawner_count",
  code_value = NA_character_, dictionary_role = "variable", search_role = "variable",
  target_scope = "column", target_sdp_file = "column_dictionary.csv",
  target_sdp_field = "term_iri", target_row_key = "demo-1/spawners/spawner_count",
  target_label = "Spawner count", target_description = "Number of spawners counted.",
  search_query = "spawner count", target_query_basis = "label",
  target_query_context = "Spawner count", column_label = "Spawner count",
  column_description = "Number of spawners counted.",
  code_label = NA_character_, code_description = NA_character_
)
attr(dict, "semantic_targets") <- target
attr(dict, "semantic_suggestions") <- dplyr::bind_cols(
  target,
  tibble::tibble(
    label = "Spawner Abundance", iri = "https://w3id.org/smn/SpawnerAbundance",
    source = "smn", ontology = "smn", role = "variable", match_type = "label",
    definition = "Mature salmon returning to spawn.", score = 4.9
  )
)
review_dir <- file.path(tempdir(), "review-packet-example")
packet <- write_semantic_review_packet(dict, review_dir = review_dir, quiet = TRUE)
packet$packet_id
#> [1] "c39b7fc0df2632fb3767fa06e484d2bf2ab3c7d9ebff9d1b6a56c7601ba8b0f6"
```
