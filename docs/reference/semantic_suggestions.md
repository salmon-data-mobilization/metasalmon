# Semantic suggestions attached to a dictionary or package

[`suggest_semantics()`](https://salmon-data-mobilization.github.io/metasalmon/reference/suggest_semantics.md)
and
[`infer_dictionary()`](https://salmon-data-mobilization.github.io/metasalmon/reference/infer_dictionary.md)
attach their candidate shortlist to the returned dictionary as the
`semantic_suggestions` attribute, and
[`create_sdp()`](https://salmon-data-mobilization.github.io/metasalmon/reference/create_sdp.md)
writes the same table to `semantic_suggestions.csv` inside the package.
This is the supported way to read either, so review tooling never has to
reach for [`attr()`](https://rdrr.io/r/base/attr.html).

## Usage

``` r
semantic_suggestions(x)
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

A tibble of candidate rows, or `NULL` when none are attached. The `NULL`
is deliberate: these accessors replace `attr(x, "semantic_suggestions")`
and must answer [`is.null()`](https://rdrr.io/r/base/NULL.html) the same
way it did.

## Examples

``` r
dict <- tibble::tibble(column_name = "spawner_count")
semantic_suggestions(dict)
#> NULL

attr(dict, "semantic_suggestions") <- tibble::tibble(
  column_name = "spawner_count",
  dictionary_role = "variable",
  iri = "https://w3id.org/smn/SpawnerAbundance"
)
semantic_suggestions(dict)
#> # A tibble: 1 × 3
#>   column_name   dictionary_role iri
#>   <chr>         <chr>           <chr>
#> 1 spawner_count variable        https://w3id.org/smn/SpawnerAbundance
```
