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

## Examples

``` r
# Supply a reviewed SSSOM file. This temporary set illustrates the format.
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
sdp_path <- tempfile("sdp-")
dir.create(sdp_path)
write_sdp_sssom(sdp_path, mapping_file)
validate_sdp_sssom(sdp_path)
unlink(c(mapping_file, sdp_path), recursive = TRUE)
```
