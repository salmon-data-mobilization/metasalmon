# Target-level LLM assessments attached to a dictionary

The companion accessor to
[`semantic_suggestions()`](https://salmon-data-mobilization.github.io/metasalmon/reference/semantic_suggestions.md),
for the `semantic_llm_assessments` attribute that
`suggest_semantics(llm_assess = TRUE)` attaches. Reading LLM review is
never itself an LLM call: this only reports assessments that already
exist.

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
attached. A package path always returns `NULL` — assessments are not
written into the package, so a package on disk cannot carry them.

## Examples

``` r
dict <- tibble::tibble(column_name = "spawner_count")
semantic_llm_assessments(dict)
#> NULL
```
