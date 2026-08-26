# Decide a semantic review slot

`accept_suggestion()` records that a candidate is the right term for a
slot; `reject_suggestion()` records that none is, and clears the field.
Both are pipe-friendly – they take a review and return it – so a whole
review is an ordinary, re-runnable R script. Nothing is written until
[`apply_sdp_semantics()`](https://salmon-data-mobilization.github.io/metasalmon/reference/apply_sdp_semantics.md)
is called.

## Usage

``` r
accept_suggestion(
  review,
  column = NULL,
  role,
  rank = 1L,
  table = NULL,
  code_value = NULL,
  iri = NULL
)

reject_suggestion(
  review,
  column = NULL,
  role,
  table = NULL,
  code_value = NULL,
  reason = NULL
)
```

## Arguments

- review:

  An `ms_semantic_review` object from
  [`review_semantics()`](https://salmon-data-mobilization.github.io/metasalmon/reference/review_semantics.md).

- column:

  Column name of the slot. Omit it for a table-level slot
  (`tables.csv` - `observation_unit_iri`), which has no column; pass
  `table` instead.
  [`review_semantics()`](https://salmon-data-mobilization.github.io/metasalmon/reference/review_semantics.md)
  prints the right spelling either way.

- role:

  Semantic role of the slot (`"variable"`, `"property"`, `"entity"`,
  `"unit"`, `"constraint"`, `"statistical_modifier"`).

- rank:

  Rank of the candidate to accept, as printed in the shortlist.

- table:

  Table identifier; needed only when the column name appears in more
  than one table.

- code_value:

  Code value; needed only for code-level slots.

- iri:

  Optional IRI to accept instead of a shortlisted candidate – for the
  case where the right term exists but retrieval did not surface it.

- reason:

  Optional free-text reason recorded with a rejection.

## Value

The review, with the decision recorded.

## Details

These are the calls
[`review_semantics()`](https://salmon-data-mobilization.github.io/metasalmon/reference/review_semantics.md)
prints. Pasting the printed line is the intended workflow, and it is
what makes the decision reproducible: the script is the audit trail.

## See also

[`review_semantics()`](https://salmon-data-mobilization.github.io/metasalmon/reference/review_semantics.md),
[`apply_sdp_semantics()`](https://salmon-data-mobilization.github.io/metasalmon/reference/apply_sdp_semantics.md)

## Examples

``` r
dict <- tibble::tibble(
  dataset_id = "demo-1", table_id = "spawners",
  column_name = "spawner_count", term_iri = NA_character_
)
attr(dict, "semantic_suggestions") <- tibble::tibble(
  dataset_id = "demo-1", table_id = "spawners",
  column_name = "spawner_count", code_value = NA_character_,
  dictionary_role = "variable", target_scope = "column",
  target_sdp_file = "column_dictionary.csv", target_sdp_field = "term_iri",
  target_row_key = "demo-1/spawners/spawner_count",
  label = "Spawner Abundance", iri = "https://w3id.org/smn/SpawnerAbundance",
  source = "smn", ontology = "smn",
  definition = "Mature salmon returning to spawn.", score = 4.9
)

review <- review_semantics(dict)
review <- accept_suggestion(review, "spawner_count", "variable", rank = 1)
review$decision
#> [1] "accept"
```
