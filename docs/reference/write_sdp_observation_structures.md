# Write measure-specific SDP observation structures

Writes the paired canonical resources under `metadata/structure/`. Each
structure has one measure; dimensions define that measure's grain and
attributes qualify it. Supplying both row arguments as `NULL` is an
explicit no-op. Supplying only one is an error because the files are a
pair.

## Usage

``` r
write_sdp_observation_structures(
  path,
  structures = NULL,
  components = NULL,
  overwrite = FALSE
)
```

## Arguments

- path:

  Existing Salmon Data Package directory.

- structures:

  `NULL` or a data frame with the exact SDP observation structures
  schema.

- components:

  `NULL` or a data frame with the exact SDP observation components
  schema.

- overwrite:

  Logical; replace both managed resources when `TRUE`.

## Value

A named character vector containing the two written paths, invisibly;
`NULL` for an explicit no-op.
