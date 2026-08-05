# Read an SDP reproducibility manifest

Read an SDP reproducibility manifest

## Usage

``` r
read_sdp_reproducibility_manifest(path, validate = TRUE)
```

## Arguments

- path:

  Existing Salmon Data Package directory.

- validate:

  Logical; validate paths, roles, checksums, sizes, symlinks,
  provenance, deterministic ordering, and exact directory closure.

## Value

The parsed manifest as a list.
