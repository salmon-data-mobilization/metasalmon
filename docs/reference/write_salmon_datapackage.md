# Write a Salmon Data Package from preassembled metadata

Advanced/manual writer for cases where you already have the canonical
Salmon Data Package (SDP) metadata tables assembled. It writes the SDP
CSV metadata files under `metadata/` (`dataset.csv`, `tables.csv`,
`column_dictionary.csv`, and optional `codes.csv`) plus the data
resource files themselves under `data/`. For interoperability with
Frictionless-style tooling, the function also emits a derived
`datapackage.json` descriptor at the package root.

## Usage

``` r
write_salmon_datapackage(
  resources,
  dataset_meta,
  table_meta,
  dict,
  codes = NULL,
  path,
  format = "csv",
  overwrite = FALSE,
  write_datapackage = TRUE,
  prune = FALSE
)
```

## Arguments

- resources:

  Named list of data frames/tibbles (one per resource)

- dataset_meta:

  Tibble with dataset-level metadata (one row)

- table_meta:

  Tibble with table-level metadata (one row per table)

- dict:

  Dictionary tibble with column definitions

- codes:

  Optional tibble with code lists

- path:

  Character; directory path where package will be written

- format:

  Character; resource format: `"csv"` (default, only format supported)

- overwrite:

  Logical; if `FALSE` (default), errors when `path` is a directory that
  already holds something. An existing but *completely empty* directory
  is written into without `overwrite` — there is nothing there to
  destroy — while a dot-file, a stale `.metasalmon-package` sentinel, or
  an empty `data/` subdirectory all count as content and still require
  it. If `TRUE`, the package is updated in place — see `prune`.
  Replacement is only allowed for directories previously written by
  `metasalmon`.

- write_datapackage:

  Logical; if `TRUE` (default), write a root `datapackage.json`
  descriptor declaring the SDP Frictionless profile after package
  validation passes. Use `FALSE` for draft authoring output.

- prune:

  Logical; if `FALSE` (default), only files this writer owns are
  replaced: the `metadata/` SDP CSVs, the `data/` resources declared in
  `tables.csv` (including any a previous write declared and this one
  does not), `datapackage.json`, and the ownership sentinel. Everything
  else is preserved — reviewed SSSOM mappings and measurement
  decompositions under `metadata/semantic/`, EML and EDH XML,
  `eml-mapping.yml`, review notes, and `publication/` artifacts. If
  `TRUE`, every entry in the directory is deleted first (the pre-0.2.0
  behaviour). Requires `overwrite = TRUE`.

## Value

Invisibly returns the path to the created package

## Details

The SDP CSV files remain the canonical package metadata.
`datapackage.json` is a convenience export, not the source of truth.

The write is transactional over the files it owns: every output is fully
rendered before anything on disk is deleted or replaced, and a failure
while installing the rendered files restores the previous package. An
error partway through therefore leaves an existing package intact rather
than destroyed. The one exception is `prune = TRUE`, which deletes files
the writer does not own and so cannot restore: the wipe still happens
only after every input-dependent step has succeeded, but a filesystem
failure (disk full, permissions) between the wipe and the install can
lose the deleted files.

## Examples

``` r
if (FALSE) { # \dontrun{
# Create a simple package
resources <- list(main_table = mtcars)
dataset_meta <- tibble::tibble(
  dataset_id = "test-1",
  title = "Test Dataset",
  description = "A test dataset"
)
table_meta <- tibble::tibble(
  dataset_id = "test-1",
  table_id = "main_table",
  file_name = "data/main_table.csv",
  table_label = "Main Table"
)
dict <- infer_dictionary(mtcars, dataset_id = "test-1", table_id = "main_table")
write_salmon_datapackage(
  resources, dataset_meta, table_meta, dict,
  path = tempdir()
)
} # }
```
