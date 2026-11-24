# Validate measure-specific SDP observation structures

Validate measure-specific SDP observation structures

## Usage

``` r
validate_sdp_observation_structures(path)
```

## Arguments

- path:

  Existing Salmon Data Package directory.

## Value

`TRUE`, invisibly, when the paired resources and all data-level bindings
are valid; otherwise an error.

## Examples

``` r
sdp_path <- create_sdp(
  data.frame(stock_id = c("A", "B"), total_spawners = c(100, 200)),
  path = tempfile("sdp-"), seed_semantics = FALSE,
  seed_verbose = FALSE, check_updates = FALSE
)
#> Some measurement semantic IRI fields are still blank in this review-ready
#> package.
#> ℹ That does not block review-ready creation, but those gaps must be filled
#>   before final validation or publication.
#>   term_iri: total_spawners (rows 2) property_iri: total_spawners (rows 2)
#>   entity_iri: total_spawners (rows 2) unit_iri: total_spawners (rows 2)
#> ℹ Review metadata/column_dictionary.csv first (and metadata/tables.csv if
#>   present), then fill the remaining gaps there.
#> ℹ If you want candidate IRIs later, run `suggest_semantics()` or recreate the
#>   package with `seed_semantics = TRUE` before final validation.
#> ✔ Dictionary validation passed
#> ✔ Created Salmon Data Package at /var/folders/pm/twz8_z1j6_zb996w0b17bz2r0000gn/T//RtmpP4K6i1/sdp-110117a98641f
#> Created review-ready one-shot package with `create_sdp()`.
#> ℹ Prefilled semantic values were written directly into the metadata CSVs only
#>   where target fields were blank. Compatible table observation-unit drafts can
#>   be auto-applied using observation-unit/description first and otherwise table
#>   label/id fallback. Any "REVIEW:" entries already live in the metadata CSVs
#>   and must be confirmed or edited there.
#> ℹ No shortlist was seeded, so set any IRI you already know with
#>   `set_sdp_column()`.
#> ℹ Then run `review_metadata(pkg_path)` for the free-text fields and any
#>   required IRI nothing was suggested for; it prints the `set_sdp_dataset()` /
#>   `set_sdp_table()` / `set_sdp_column()` call that fills each one.
#> ℹ Finish with `validate_salmon_datapackage(pkg_path, require_iris = TRUE)`,
#>   rebuilding the EDH XML first if you need it. README-review.txt has the same
#>   checklist.
structures <- data.frame(
  dataset_id = "dataset-1", table_id = "table_1",
  observation_structure_id = "spawners_by_stock",
  structure_label = "Spawners by stock",
  structure_description = "One count per stock"
)
components <- data.frame(
  dataset_id = "dataset-1", table_id = "table_1",
  observation_structure_id = "spawners_by_stock",
  component_order = c(1L, 2L),
  column_name = c("stock_id", "total_spawners"),
  component_role = c("dimension", "measure"),
  component_relation_iri = c(NA, NA),
  required_when_observed = c(TRUE, TRUE)
)
write_sdp_observation_structures(sdp_path, structures, components)
#> ✔ Loaded Salmon Data Package from /private/var/folders/pm/twz8_z1j6_zb996w0b17bz2r0000gn/T/RtmpP4K6i1/sdp-110117a98641f
#> ✔ Loaded Salmon Data Package from /private/var/folders/pm/twz8_z1j6_zb996w0b17bz2r0000gn/T/RtmpP4K6i1/sdp-110117a98641f
validate_sdp_observation_structures(sdp_path)
#> ✔ Loaded Salmon Data Package from /private/var/folders/pm/twz8_z1j6_zb996w0b17bz2r0000gn/T/RtmpP4K6i1/sdp-110117a98641f
unlink(sdp_path, recursive = TRUE)
```
