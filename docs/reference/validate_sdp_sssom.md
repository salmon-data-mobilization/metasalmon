# Validate SDP SSSOM artifacts

Validates either one SSSOM 1.1 embedded-TSV file or an SDP directory.
For an SDP directory, the function validates
`metadata/semantic/mapping-sets.json`, safe relative paths, byte hashes,
row counts, metadata provenance, and every referenced mapping set.

## Usage

``` r
validate_sdp_sssom(path)
```

## Arguments

- path:

  Path to an SDP directory or one `.sssom.tsv` mapping set.

## Value

`TRUE`, invisibly, when validation succeeds; otherwise an error.

## Examples

``` r
# Validate a self-contained mapping set before placing it in an SDP.
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
validate_sdp_sssom(mapping_file)
unlink(mapping_file)
```
