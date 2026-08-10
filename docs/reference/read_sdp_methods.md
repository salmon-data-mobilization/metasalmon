# Read an SDP SOSA procedure registry

Read an SDP SOSA procedure registry

## Usage

``` r
read_sdp_methods(path, validate = TRUE)
```

## Arguments

- path:

  Existing Salmon Data Package directory.

- validate:

  Logical; validate package bindings and descriptor inventory when
  `TRUE`.

## Value

A tibble with the exact SDP methods schema.
