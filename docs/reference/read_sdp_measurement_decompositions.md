# Read ordered measurement decompositions from a Salmon Data Package

Reads the manifest-bound decomposition artifact that preserves repeated
semantic components and explicit gaps beyond the frozen SDP dictionary
columns. The profile uses I-ADOPT-informed roles, but does not claim
native I-ADOPT conformance and is separate from SSSOM vocabulary
mappings.

## Usage

``` r
read_sdp_measurement_decompositions(path, validate = TRUE)
```

## Arguments

- path:

  Existing Salmon Data Package directory.

- validate:

  Logical; when `TRUE`, validate the exact-byte manifest binding and the
  decomposition rows against the package dictionary. A `FALSE` read
  still requires the closed row schema, valid row states, deterministic
  order, UTF-8, LF endings, and no BOM.

## Value

A tibble in canonical component order. The parsed manifest is attached
as the `manifest` attribute.

## Examples

``` r
# Minimal local metadata for an illustrative, manually reviewed component.
sdp_path <- tempfile("sdp-")
dir.create(file.path(sdp_path, "metadata"), recursive = TRUE)
dictionary <- data.frame(
  dataset_id = "demo", table_id = "counts", column_name = "count",
  column_role = "measurement",
  term_iri = "https://example.org/variables/count"
)
readr::write_csv(dictionary,
  file.path(sdp_path, "metadata", "column_dictionary.csv"))
components <- data.frame(
  dataset_id = "demo", table_id = "counts", column_name = "count",
  measurement_concept_iri = "https://example.org/variables/count",
  component_order = 1L, component_role = "property",
  component_status = "matched", component_relation = "",
  related_component_order = NA_integer_,
  component_iri = "https://example.org/properties/abundance",
  component_label = "Abundance", rationale = "", source = "Example",
  source_version = "1", source_url = "https://example.org/",
  provenance = "Illustrative review record"
)
write_sdp_measurement_decompositions(sdp_path, components)
read_sdp_measurement_decompositions(sdp_path)
#> # A tibble: 1 × 16
#>   dataset_id table_id column_name measurement_concept_iri        component_order
#>   <chr>      <chr>    <chr>       <chr>                                    <int>
#> 1 demo       counts   count       https://example.org/variables…               1
#> # ℹ 11 more variables: component_role <chr>, component_status <chr>,
#> #   component_relation <chr>, related_component_order <int>,
#> #   component_iri <chr>, component_label <chr>, rationale <chr>, source <chr>,
#> #   source_version <chr>, source_url <chr>, provenance <chr>
unlink(sdp_path, recursive = TRUE)
```
