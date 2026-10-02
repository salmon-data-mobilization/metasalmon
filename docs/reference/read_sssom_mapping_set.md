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

## Examples

``` r
# Illustrative mapping only; curate real assertions before publication.
mapping_file <- tempfile(fileext = ".sssom.tsv")
writeLines(c(
  '#sssom_version: "1.1"',
  "#curie_map:",
  "#  exa: https://example.org/ontology-a/",
  "#  exb: https://example.org/ontology-b/",
  "#mapping_set_id: https://example.org/mappings/demo",
  "#mapping_set_version: 1",
  "#license: https://creativecommons.org/licenses/by/4.0/",
  "#subject_source: https://example.org/ontology-a/",
  "#subject_source_version: 1",
  "#object_source: https://example.org/ontology-b/",
  "#object_source_version: 1",
  paste("subject_id", "subject_label", "predicate_id", "object_id",
        "object_label", "mapping_justification", sep = "\t"),
  paste("exa:spawner-count", "Spawner count", "skos:exactMatch",
        "exb:spawner-count", "Spawner count",
        "semapv:ManualMappingCuration", sep = "\t")
), mapping_file, useBytes = TRUE)
mapping_set <- read_sssom_mapping_set(mapping_file)
mapping_set$metadata$mapping_set_id
#> [1] "https://example.org/mappings/demo"
unlink(mapping_file)
```
