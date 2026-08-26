# Report the metadata a package still needs, with the call that fills it

Lists every field that still blocks
`validate_salmon_datapackage(path, require_iris = TRUE)`, and prints the
exact
[`set_sdp_dataset()`](https://salmon-data-mobilization.github.io/metasalmon/reference/set_sdp_dataset.md)
/
[`set_sdp_table()`](https://salmon-data-mobilization.github.io/metasalmon/reference/set_sdp_dataset.md)
/
[`set_sdp_column()`](https://salmon-data-mobilization.github.io/metasalmon/reference/set_sdp_dataset.md)
/
[`set_sdp_code()`](https://salmon-data-mobilization.github.io/metasalmon/reference/set_sdp_dataset.md)
call that fills it. Replace the `<...>` placeholder in the printed call
with the real value and paste it – the paste is the audit trail, just as
it is for
[`accept_suggestion()`](https://salmon-data-mobilization.github.io/metasalmon/reference/accept_suggestion.md).

## Usage

``` r
review_metadata(path)
```

## Arguments

- path:

  Path to the package directory.

## Value

An `ms_metadata_review` tibble subclass, one row per unfilled field,
with the package path attached as the `review_path` attribute. Empty
when nothing is outstanding.

## Details

This is the companion to
[`review_semantics()`](https://salmon-data-mobilization.github.io/metasalmon/reference/review_semantics.md),
and it sees something that review structurally cannot: **a slot with no
candidates at all**.
[`review_semantics()`](https://salmon-data-mobilization.github.io/metasalmon/reference/review_semantics.md)
builds its queue from retrieved suggestions, so a field nothing was
found for never appears there. `review_metadata()` builds its list from
the package's own required-field rules, so an empty shortlist and a full
one look the same to it.

What it reports:

- unresolved `MISSING DESCRIPTION:` / `MISSING METADATA:` /
  `REVIEW REQUIRED:` placeholders in any metadata field;

- schema-required fields (`constraints.required`) that are blank;

- measurement columns missing `term_iri`, `property_iri`, `entity_iri`
  or `unit_iri`;

- `tables.csv` rows with a blank `observation_unit_iri`.

It never contacts a network or an LLM.

## See also

[`set_sdp_dataset()`](https://salmon-data-mobilization.github.io/metasalmon/reference/set_sdp_dataset.md),
[`review_semantics()`](https://salmon-data-mobilization.github.io/metasalmon/reference/review_semantics.md),
[`validate_salmon_datapackage()`](https://salmon-data-mobilization.github.io/metasalmon/reference/validate_salmon_datapackage.md)

## Examples

``` r
if (FALSE) { # \dontrun{
pkg <- create_sdp(resources, dataset_id = "demo-1")
review_metadata(pkg)
set_sdp_dataset(pkg, creator = "Fisheries and Oceans Canada")
} # }
```
