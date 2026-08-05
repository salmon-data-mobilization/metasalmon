# Write an SDP SOSA procedure registry

Writes the optional, canonical `metadata/methods.csv` resource. These
rows describe resources interpreted as `sosa:Procedure`; they are
deliberately separate from I-ADOPT variable components and from
executable workflow provenance. When a `datapackage.json` descriptor
exists, the writer updates its metadata inventory atomically.

## Usage

``` r
write_sdp_methods(path, methods = NULL, overwrite = FALSE)
```

## Arguments

- path:

  Existing Salmon Data Package directory.

- methods:

  `NULL` for an explicit no-op, or a data frame with the exact SDP
  methods schema.

- overwrite:

  Logical; replace the managed methods resource when `TRUE`.

## Value

The methods CSV path, invisibly, or `NULL` when `methods` is `NULL`.
