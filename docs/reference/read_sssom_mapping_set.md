# Read a reviewed SSSOM mapping set

Reads the SSSOM 1.1 embedded-TSV serialization used by Salmon Data
Packages. The reader enforces UTF-8 without a byte-order mark, LF line
endings, tab delimiters, declared CURIE prefixes, and the package's
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

## Details

Every CURIE prefix must be declared in `curie_map` except the SSSOM
built-in prefixes (`owl`, `rdf`, `rdfs`, `semapv`, `skos`, `sssom`,
`xsd` and `linkml`), which the SSSOM specification lets a file omit, so
a canonical SSSOM/TSV file that leaves them out is read. A `curie_map`
that does declare a built-in prefix must give it the expansion the
specification fixes for it (for example
`http://www.w3.org/2004/02/skos/core#` for `skos`); any other expansion
is refused.
