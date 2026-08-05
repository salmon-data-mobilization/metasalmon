# Read measure-specific SDP observation structures

Read measure-specific SDP observation structures

## Usage

``` r
read_sdp_observation_structures(path, validate = TRUE)
```

## Arguments

- path:

  Existing Salmon Data Package directory.

- validate:

  Logical; validate package references, logical grain, procedure
  bindings, and descriptor inventory when `TRUE`.

## Value

A list with `structures` and `components` tibbles.
