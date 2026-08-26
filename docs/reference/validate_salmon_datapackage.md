# Validate a Salmon Data Package end to end

Reads a package from disk, checks that metadata/data files stay aligned,
verifies coded values against `codes.csv` when present, and then runs
[`validate_dictionary()`](https://salmon-data-mobilization.github.io/metasalmon/reference/validate_dictionary.md)
plus
[`validate_semantics()`](https://salmon-data-mobilization.github.io/metasalmon/reference/validate_semantics.md).
This is the quickest pre-flight check before sharing a package-first
submission.

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
#> ✔ Created Salmon Data Package at /var/folders/pm/twz8_z1j6_zb996w0b17bz2r0000gn/T//Rtmp70FjXF/demo-1-sdp
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
#> ✔ Loaded Salmon Data Package from /var/folders/pm/twz8_z1j6_zb996w0b17bz2r0000gn/T//Rtmp70FjXF/demo-1-sdp
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
