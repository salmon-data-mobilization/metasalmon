# Migrate an sdp-0.2.0 package's method metadata to sdp-0.3.0

sdp-0.3.0 removed the `metadata/methods.csv` registry and the
column-dictionary `method_iri` field. This tool relocates what can be
relocated mechanically and **stops and reports** on anything that needs
a judgement call, rather than guessing:

## Usage

``` r
migrate_sdp_methods(path, dry_run = FALSE)
```

## Arguments

- path:

  Existing Salmon Data Package directory.

- dry_run:

  Logical; when `TRUE`, report what would change without touching any
  file.

## Value

Invisibly, a list report: `tables` (the table-level method placements
applied), `dropped_review` (unresolved `REVIEW:` bindings dropped), and
`registry` (the legacy registry rows, for relocating labels/descriptions
to the shared vocabulary and citations to `protocol_citation`).

## Details

- A `method_iri` shared by every bound measurement column of a table
  becomes that table's `tables.csv$method_iri`.

- Columns of one table bound to *different* methods stop the migration:
  you decide whether to split the table, cite a protocol, or move the
  method into the data as a code column (see the methods section of the
  SDP specification).

- `REVIEW:`-marked values are dropped, not migrated, and reported.

- Registry labels and descriptions are reported, not relocated — they
  belong in the shared vocabulary. A registry `method_version` or
  `citation` is offered in the report as `protocol_citation` material.

The rewrite is atomic: either every affected metadata file is updated
and `metadata/methods.csv` removed, or nothing changes.
