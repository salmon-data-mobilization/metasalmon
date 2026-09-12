# Validate a Salmon Data Package end to end

Reads a package from disk and checks, in order: that `dataset.csv`,
`tables.csv`, `column_dictionary.csv` and `codes.csv` stay aligned with
each other and with the data files, and that no schema-required key
field is blank; that a declared primary key identifies each row and that
a column the dictionary declares `required` has no missing values; that
coded values appear in `codes.csv` when present; that the optional
observation-structure, SSSOM mapping-set and measurement-decomposition
artifacts validate when present; and then runs
[`validate_dictionary()`](https://salmon-data-mobilization.github.io/metasalmon/reference/validate_dictionary.md)
plus
[`validate_semantics()`](https://salmon-data-mobilization.github.io/metasalmon/reference/validate_semantics.md).
Under `require_iris = TRUE` it additionally refuses `REVIEW:` markers,
unresolved `MISSING ...:` placeholders, blank schema-required metadata
fields and blank table `observation_unit_iri` values (a column a
metadata file does not have counts as blank in every row); in the
default mode those are reported as warnings. This is the pre-flight
check before sharing a package-first submission.

## Usage

``` r
validate_salmon_datapackage(path, require_iris = FALSE)
```

## Arguments

- path:

  Character; directory containing the Salmon Data Package.

- require_iris:

  Logical; if `TRUE`, require non-empty semantic IRIs for measurement
  fields (`term_iri`, `property_iri`, `entity_iri`, and `unit_iri`).

## Value

Invisibly returns a list with components:

- `package`: loaded package list from
  [`read_salmon_datapackage()`](https://salmon-data-mobilization.github.io/metasalmon/reference/read_salmon_datapackage.md).

- `semantic_validation`: result from
  [`validate_semantics()`](https://salmon-data-mobilization.github.io/metasalmon/reference/validate_semantics.md).

- `issues`: package-structure issue tibble (empty when validation
  passes).

## Examples

``` r
# \donttest{
# `path` is explicit: without it `create_sdp()` writes `<dataset_id>-sdp/`
# into the working directory, which an example must never do.
pkg_path <- create_sdp(
  mtcars,
  path = file.path(tempdir(), "demo-1-sdp"),
  dataset_id = "demo-1",
  table_id = "counts",
  overwrite = TRUE
)
#> ℹ Seeding semantic suggestions from online vocabularies. This may take a few minutes for wider tables. Code-level semantic suggestions are limited to factor and low-cardinality character columns for this first pass. Use `seed_semantics = FALSE` for the fastest first pass.
#> ℹ Seeding semantic suggestions during infer_salmon_datapackage_artifacts().
#> Warning: Vocabulary lookup was incomplete: "gbif" and "worms" did not answer.
#> ℹ Treat an empty or short result as unknown rather than as an ontology gap.
#> ℹ See `attr(result, "diagnostics")` for per-source detail.
#> Semantic suggestions stored in attr('semantic_suggestions') for downstream
#> review.
#> ✔ Dictionary validation passed
#> ✔ Created Salmon Data Package at /tmp/RtmplIFRCa/demo-1-sdp
#> Created review-ready one-shot package with `create_sdp()`.
#> ℹ Prefilled semantic values were written directly into the metadata CSVs only
#>   where target fields were blank. Compatible table observation-unit drafts can
#>   be auto-applied using observation-unit/description first and otherwise table
#>   label/id fallback. Any "REVIEW:" entries already live in the metadata CSVs
#>   and must be confirmed or edited there.
#> ℹ Review the seeded IRIs with `review <- review_semantics(pkg_path)`, then
#>   paste the printed decision calls and finish with
#>   `apply_sdp_semantics(pkg_path, review)`.
#> ℹ Then run `review_metadata(pkg_path)` for the free-text fields and any
#>   required IRI nothing was suggested for; it prints the `set_sdp_dataset()` /
#>   `set_sdp_table()` / `set_sdp_column()` call that fills each one.
#> ℹ Finish with `validate_salmon_datapackage(pkg_path, require_iris = TRUE)`,
#>   rebuilding the EDH XML first if you need it. README-review.txt has the same
#>   checklist.
validate_salmon_datapackage(pkg_path, require_iris = FALSE)
#> ✔ Loaded Salmon Data Package from /tmp/RtmplIFRCa/demo-1-sdp
#> Warning: 8 metadata fields still hold a placeholder.
#> ✖ column_dictionary.csv$column_description, dataset.csv$contact_email,
#>   dataset.csv$contact_name, dataset.csv$creator, dataset.csv$description,
#>   dataset.csv$license
#> ℹ Replace them before publication; `require_iris = TRUE` reports these as
#>   errors.
#> ✔ Dictionary validation passed
#> ✔ Dictionary validation passed
#> ✔ Salmon Data Package validation passed
# }
```
