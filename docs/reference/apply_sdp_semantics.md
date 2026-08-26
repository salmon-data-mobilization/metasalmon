# Write semantic review decisions into a package

Applies the decisions recorded by
[`accept_suggestion()`](https://salmon-data-mobilization.github.io/metasalmon/reference/accept_suggestion.md)
and
[`reject_suggestion()`](https://salmon-data-mobilization.github.io/metasalmon/reference/accept_suggestion.md)
to a written Salmon Data Package. Accepted IRIs are written with the
`REVIEW:` prefix stripped; rejected slots are cleared; every other
field, and every data CSV byte, is left untouched.

## Usage

``` r
apply_sdp_semantics(path, review, quiet = FALSE)
```

## Arguments

- path:

  Path to the package directory.

- review:

  An `ms_semantic_review` object carrying decisions.

- quiet:

  Logical; suppress the summary message.

## Value

The package path, invisibly.

## Details

Safe to re-run: applying the same review twice produces identical bytes.
Only fields carrying a decision are written, so undecided slots keep
their `REVIEW:` markers.

The metadata CSVs, `semantic_suggestions.csv` and `datapackage.json` are
installed as one transactional set – the descriptor duplicates the
dictionary's IRI fields, and a half-applied edit would leave the package
quietly self-inconsistent.

## See also

[`review_semantics()`](https://salmon-data-mobilization.github.io/metasalmon/reference/review_semantics.md),
[`accept_suggestion()`](https://salmon-data-mobilization.github.io/metasalmon/reference/accept_suggestion.md)

## Examples

``` r
if (FALSE) { # \dontrun{
pkg <- create_sdp(resources, dataset_id = "demo-1")
review <- review_semantics(pkg)
review <- accept_suggestion(review, "spawner_count", "variable", rank = 1)
apply_sdp_semantics(pkg, review)
validate_salmon_datapackage(pkg, require_iris = TRUE)
} # }
```
