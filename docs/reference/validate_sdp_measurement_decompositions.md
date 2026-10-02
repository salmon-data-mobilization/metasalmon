# Validate ordered SDP measurement-decomposition artifacts

Validate ordered SDP measurement-decomposition artifacts

## Usage

``` r
validate_sdp_measurement_decompositions(path)
```

## Arguments

- path:

  Existing Salmon Data Package directory.

## Value

`TRUE`, invisibly, when validation succeeds; otherwise an error.

## Examples

``` r
# Create a manifest-bound component before validating it.
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
validate_sdp_measurement_decompositions(sdp_path)
unlink(sdp_path, recursive = TRUE)
```
