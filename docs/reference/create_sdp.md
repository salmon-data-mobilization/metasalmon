# Create a Salmon Data Package directly from raw tables

Primary one-shot wrapper: infer dictionary/table metadata/codes/dataset
metadata from raw data tables and immediately write a review-ready
Salmon Data Package.

## Usage

``` r
create_sdp(
  resources,
  path = NULL,
  dataset_id = "dataset-1",
  table_id = "table_1",
  guess_types = TRUE,
  seed_semantics = TRUE,
  semantic_sources = c("smn", "gcdfo", "ols", "nvs"),
  semantic_max_per_role = 1,
  seed_verbose = TRUE,
  seed_codes = NULL,
  seed_table_meta = TRUE,
  seed_dataset_meta = TRUE,
  semantic_code_scope = c("factor", "all", "none"),
  check_updates = interactive(),
  format = "csv",
  overwrite = FALSE,
  include_edh_xml = FALSE,
  prune = FALSE,
  ...
)
```

## Arguments

- resources:

  Either a named list of data frames (one per resource table) or a
  single data frame (converted internally to a one-table list).

- path:

  Character; directory path where package will be written. If omitted,
  defaults to `file.path(getwd(), paste0(<dataset_id>-sdp))` using a
  filesystem-safe dataset id slug.

- dataset_id:

  Dataset identifier applied to all inferred metadata rows.

- table_id:

  Fallback table identifier when `resources` is a single data frame.

- guess_types:

  Logical; if `TRUE` (default), infer `value_type` for each dictionary
  column.

- seed_semantics:

  Logical; if `TRUE` (default), seed semantic suggestions during
  inference.

- semantic_sources:

  Vector of vocabulary sources passed to
  [`suggest_semantics()`](https://salmon-data-mobilization.github.io/metasalmon/reference/suggest_semantics.md).
  When omitted, role-aware defaults are used. When supplied explicitly,
  the vector is a strict allowlist for initial and retry retrieval.

- semantic_max_per_role:

  Maximum number of suggestions retained per I-ADOPT role.

- seed_verbose:

  Logical; if TRUE, emit progress messages while seeding semantic
  suggestions.

- seed_codes:

  Optional `codes.csv`-style seed metadata.

- seed_table_meta:

  Optional `tables.csv`-style seed metadata. Use `TRUE` (default) to
  infer starter table metadata from `resources`.

- seed_dataset_meta:

  Optional `dataset.csv`-style seed metadata. Use `TRUE` (default) to
  infer starter dataset metadata from `resources`.

- semantic_code_scope:

  Character string controlling which `codes.csv` rows are sent through
  [`suggest_semantics()`](https://salmon-data-mobilization.github.io/metasalmon/reference/suggest_semantics.md)
  during one-shot seeding. `"factor"` (default) analyzes codes sourced
  from factor columns and low-cardinality character columns in the
  original data frame(s); `"all"` analyzes all inferred or supplied code
  rows; `"none"` skips code-level semantic suggestions.

- check_updates:

  Logical; if `TRUE`, run a short, non-fatal
  [`check_for_updates()`](https://salmon-data-mobilization.github.io/metasalmon/reference/check_for_updates.md)
  call after writing the package and mention newer releases only when
  one is available. Defaults to
  [`interactive()`](https://rdrr.io/r/base/interactive.html).

- format:

  Character; resource format: `"csv"` (default, only format supported)

- overwrite:

  Logical; if `FALSE` (default), errors when `path` is a directory that
  already holds something. An existing but *completely empty* directory
  is written into without `overwrite` — there is nothing there to
  destroy — while a dot-file, a stale `.sdp-package` ownership sentinel,
  or an empty `data/` subdirectory all count as content and still
  require it. If `TRUE`, the package is updated in place — see `prune`.
  Replacement is only allowed for a directory recognised as a package:
  one holding the shared `.sdp-package` ownership sentinel, or its SDP
  metadata. An older `.metasalmon-package` sentinel on its own is not
  recognised.

- include_edh_xml:

  Logical; when `TRUE`, writes an HNAP-aware EDH XML metadata file to
  `metadata/metadata-edh-hnap.xml` using
  [`edh_build_hnap_xml()`](https://salmon-data-mobilization.github.io/metasalmon/reference/edh_build_hnap_xml.md).
  The default is `FALSE`. Because `create_sdp()` produces review-ready
  metadata, this create-time XML is treated as a **draft**: if
  `REVIEW:`/`MISSING` markers remain it is still written but a warning
  recommends rebuilding a clean file with
  [`write_edh_xml_from_sdp()`](https://salmon-data-mobilization.github.io/metasalmon/reference/write_edh_xml_from_sdp.md)
  after the metadata is finalized.

- prune:

  Logical; if `FALSE` (default), reviewed sidecars in an existing
  package directory are preserved and only files this writer owns are
  replaced. If `TRUE`, the directory is emptied first. Requires
  `overwrite = TRUE`. See
  [`write_salmon_datapackage()`](https://salmon-data-mobilization.github.io/metasalmon/reference/write_salmon_datapackage.md).

- ...:

  Deprecated legacy EDH arguments accepted for backwards compatibility:
  `edh_profile`, `EDH_Profile`, and `EDH_profile` all enable EDH XML
  export and must be `"dfo_edh_hnap"` when supplied. `edh_xml_path` is
  ignored with a warning because XML now always writes to the default
  metadata path. Any other extra arguments error.

## Value

Invisibly returns the package path.

## Details

This one-shot helper creates a review-ready package by default: semantic
suggestions are seeded and the top-ranked column-level suggestions are
auto-applied only into missing dictionary IRI fields. Table-level
observation-unit suggestions stay enabled, and `create_sdp()` can
auto-apply them into missing `tables.csv$observation_unit_iri` values
when the suggestion still looks lexically compatible with the available
table context (prefer `observation_unit`/`description`, otherwise fall
back to `table_label`/`table_id`); compatible suggestions can also
backfill `tables.csv$observation_unit` labels when missing. To reduce
review noise conservatively, code-level suggestions default to factor
and low-cardinality character source columns only; set
`semantic_code_scope = "all"` to broaden that or `"none"` to disable it.
The package root contains `README-review.txt`,
`semantic_suggestions.csv` (when available), `datapackage.json`,
`metadata/`, and `data/`. Review the prefilled values already written
into `metadata/tables.csv` and `metadata/column_dictionary.csv` first;
use `semantic_suggestions.csv` as a fallback shortlist when you want
more context or a better match. To keep that review file usable,
`semantic_suggestions.csv` trims code-level suggestions that do not have
enough human-readable context to review safely. To have a model judge
the shortlists, write a review packet for the package with
[`write_semantic_review_packet()`](https://salmon-data-mobilization.github.io/metasalmon/reference/write_semantic_review_packet.md),
have your own harness answer it, and read the answers back with
[`ingest_semantic_assessments()`](https://salmon-data-mobilization.github.io/metasalmon/reference/ingest_semantic_assessments.md);
neither call writes the metadata CSVs. Any auto-applied column/table IRI
draft is written back into the metadata CSVs as a `REVIEW:`-prefixed
value for manual confirmation there. Required-field review placeholders
are also inserted into the inferred metadata files. In interactive use,
`create_sdp()` can also mention an available package update; set
`check_updates = FALSE` to skip that network check. The package bundles
two Fraser coho examples: `nuseds-fraser-coho-sample.csv` (30 rows
across 1996-2024) for the quickest demo, and
`nuseds-fraser-coho-2023-2024.csv` (173 rows from the official Open
Government Canada Fraser and BC Interior workbook) for a fuller
multi-year example. The bundled
`system.file("extdata", "example-data-README.md", package = "metasalmon")`
note points to the upstream record/resource URLs, licensing, and the
repository `data-raw/` script used to derive the fuller example.

## Examples

``` r
data_path <- system.file("extdata", "nuseds-fraser-coho-sample.csv", package = "metasalmon")
fraser_coho <- readr::read_csv(data_path, show_col_types = FALSE)

pkg <- create_sdp(
  fraser_coho,
  path = tempfile("fraser-coho-sdp-"),
  dataset_id = "fraser-coho-2024",
  table_id = "escapement",
  seed_semantics = FALSE,
  seed_verbose = FALSE,
  check_updates = FALSE
)
#> Some measurement semantic IRI fields are still blank in this review-ready
#> package.
#> ℹ That does not block review-ready creation, but those gaps must be filled
#>   before final validation or publication.
#>   term_iri: NATURAL_SPAWNERS_TOTAL (rows 8) property_iri:
#>   NATURAL_SPAWNERS_TOTAL (rows 8) entity_iri: NATURAL_SPAWNERS_TOTAL (rows 8)
#>   unit_iri: NATURAL_SPAWNERS_TOTAL (rows 8)
#> ℹ Review metadata/column_dictionary.csv first (and metadata/tables.csv if
#>   present), then fill the remaining gaps there.
#> ℹ If you want candidate IRIs later, run `suggest_semantics()` or recreate the
#>   package with `seed_semantics = TRUE` before final validation.
#> ✔ Dictionary validation passed
#> ✔ Created Salmon Data Package at /tmp/RtmpuFZJ3j/fraser-coho-sdp-6155703e7003
#> Created review-ready one-shot package with `create_sdp()`.
#> ℹ Prefilled semantic values were written directly into the metadata CSVs only
#>   where target fields were blank. Compatible table observation-unit drafts can
#>   be auto-applied using observation-unit/description first and otherwise table
#>   label/id fallback. Any "REVIEW:" entries already live in the metadata CSVs
#>   and must be confirmed or edited there.
#> ℹ No shortlist was seeded, so set any IRI you already know with
#>   `set_sdp_column()`.
#> ℹ Then run `review_metadata(pkg_path)` for the free-text fields and any
#>   required IRI nothing was suggested for; it prints the `set_sdp_dataset()` /
#>   `set_sdp_table()` / `set_sdp_column()` call that fills each one.
#> ℹ Finish with `validate_salmon_datapackage(pkg_path, require_iris = TRUE)`,
#>   rebuilding the EDH XML first if you need it. README-review.txt has the same
#>   checklist.
```
