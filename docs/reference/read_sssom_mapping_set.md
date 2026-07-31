# Read a reviewed SSSOM mapping set

Reads the SSSOM 1.1 embedded-TSV serialization used by Salmon Data
Packages. The reader enforces UTF-8 without a byte-order mark, LF line
endings, tab delimiters, complete CURIE declarations, and the package's
alignment-only profile. In particular, decomposition fields and raw
literal assignments are refused because they belong in separate SDP
semantic artifacts.

## Usage

``` r
read_sssom_mapping_set(path, validate = TRUE)
```

## Arguments

- path:

  Path to one `.sssom.tsv` file.

- validate:

  Logical; validate metadata, CURIEs, mappings, and no-match
  cardinalities after parsing. The byte and table structure is always
  checked.

## Value

A `metasalmon_sssom_mapping_set` list containing `metadata`, a
`mappings` tibble, and the normalized source `path`.
