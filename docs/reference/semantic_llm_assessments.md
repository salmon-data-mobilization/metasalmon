# Target-level assessments ingested from a harness

The companion accessor to
[`semantic_suggestions()`](https://salmon-data-mobilization.github.io/metasalmon/reference/semantic_suggestions.md),
for the `semantic_llm_assessments` attribute that
[`ingest_semantic_assessments()`](https://salmon-data-mobilization.github.io/metasalmon/reference/ingest_semantic_assessments.md)
attaches to the dictionary it returns. The package makes no model call:
this only reports assessments your harness already wrote and the
ingester read back.

## Usage

``` r
semantic_llm_assessments(x)
```

## Arguments

- x:

  A dictionary carrying the attribute, a list in the shape returned by
  [`infer_salmon_datapackage_artifacts()`](https://salmon-data-mobilization.github.io/metasalmon/reference/infer_salmon_datapackage_artifacts.md)
  /
  [`create_sdp()`](https://salmon-data-mobilization.github.io/metasalmon/reference/create_sdp.md)-style
  inference, or a length-one character path to a written Salmon Data
  Package.

## Value

A tibble of target-level assessment rows, or `NULL` when none are
attached. For a package path, the record
[`ingest_semantic_assessments()`](https://salmon-data-mobilization.github.io/metasalmon/reference/ingest_semantic_assessments.md)
persisted in `review/semantic-llm-assessments.csv`, typed as the
30-column assessment row and carrying the validator findings as its
`semantic_validator_findings` attribute, or `NULL` when no record has
been ingested. A `review/` directory or record that is a symbolic link
is refused rather than followed.

## Examples

``` r
dict <- tibble::tibble(column_name = "spawner_count")
semantic_llm_assessments(dict)
#> NULL
```
