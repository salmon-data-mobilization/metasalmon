# Write reviewed SSSOM mapping sets into a Salmon Data Package

Writes explicitly supplied SSSOM 1.1 mapping sets under
`metadata/semantic/` and records their paths, hashes, row counts, source
versions, licenses, and writer provenance in
`metadata/semantic/mapping-sets.json`. Bytes and manifest ordering are
deterministic. This function does not turn semantic suggestions or
variable decompositions into mappings; `mapping_sets = NULL` is
therefore a no-op.

## Usage

``` r
write_sdp_sssom(path, mapping_sets = NULL, overwrite = FALSE)
```

## Arguments

- path:

  Existing Salmon Data Package directory.

- mapping_sets:

  `NULL`, one or more paths to reviewed `.sssom.tsv` files, or parsed
  objects returned by
  [`read_sssom_mapping_set()`](https://salmon-data-mobilization.github.io/metasalmon/reference/read_sssom_mapping_set.md).

- overwrite:

  Logical; replace files managed by this writer when `TRUE`.

## Value

The manifest path, invisibly, or `NULL` when `mapping_sets` is `NULL`.
