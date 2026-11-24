# Extract normalized logical observations from an SDP

Validates the paired structure metadata, filters rows where each
structure's measure is absent, selects components in declared order, and
collapses exact repeats at a coarser declared grain. The result remains
a list because different structures can have different component columns
and data types.

## Usage

``` r
extract_sdp_observations(
  path,
  table_id = NULL,
  observation_structure_id = NULL
)
```

## Arguments

- path:

  Existing Salmon Data Package directory.

- table_id:

  Optional scalar table identifier used to select structures.

- observation_structure_id:

  Optional scalar structure identifier used to select structures. Supply
  `table_id` too when the identifier is not unique across tables.

## Value

A deterministically named list of tibbles, one per selected logical
structure. Names use `table_id::observation_structure_id`.

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
#> ✔ Created Salmon Data Package at /var/folders/pm/twz8_z1j6_zb996w0b17bz2r0000gn/T//RtmpP4K6i1/sdp-1101116246bd1
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
#> ✔ Loaded Salmon Data Package from /private/var/folders/pm/twz8_z1j6_zb996w0b17bz2r0000gn/T/RtmpP4K6i1/sdp-1101116246bd1
#> ✔ Loaded Salmon Data Package from /private/var/folders/pm/twz8_z1j6_zb996w0b17bz2r0000gn/T/RtmpP4K6i1/sdp-1101116246bd1
extract_sdp_observations(sdp_path, table_id = "table_1")
#> ✔ Loaded Salmon Data Package from /private/var/folders/pm/twz8_z1j6_zb996w0b17bz2r0000gn/T/RtmpP4K6i1/sdp-1101116246bd1
#> ✔ Loaded Salmon Data Package from /private/var/folders/pm/twz8_z1j6_zb996w0b17bz2r0000gn/T/RtmpP4K6i1/sdp-1101116246bd1
#> $`table_1::spawners_by_stock`
#> # A tibble: 2 × 2
#>   stock_id total_spawners
#>   <chr>             <dbl>
#> 1 A                   100
#> 2 B                   200
#>
unlink(sdp_path, recursive = TRUE)
```
