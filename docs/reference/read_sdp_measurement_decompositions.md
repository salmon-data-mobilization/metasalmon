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
