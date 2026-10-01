# Fill in a package's free-text metadata

The scriptable replacement for opening `metadata/*.csv` in a
spreadsheet. Each setter addresses one row and writes the named fields
into it, keeping `datapackage.json` in step in the same transactional
write. Every field the SDP schema declares for that file can be set: the
ones most often unfilled are named arguments for discoverability, and
the rest are passed through `...` and checked against the schema, so a
misspelling is an error rather than a silent no-op.

## Usage

``` r
set_sdp_dataset(
  path,
  ...,
  title = NULL,
  description = NULL,
  creator = NULL,
  contact_name = NULL,
  contact_email = NULL,
  contact_org = NULL,
  license = NULL,
  quiet = FALSE
)

set_sdp_table(
  path,
  table,
  ...,
  table_label = NULL,
  description = NULL,
  observation_unit = NULL,
  observation_unit_iri = NULL,
  quiet = FALSE
)

set_sdp_column(
  path,
  column,
  ...,
  table = NULL,
  column_label = NULL,
  column_description = NULL,
  unit_label = NULL,
  term_iri = NULL,
  property_iri = NULL,
  entity_iri = NULL,
  unit_iri = NULL,
  quiet = FALSE
)

set_sdp_code(
  path,
  column,
  code_value,
  ...,
  table = NULL,
  code_label = NULL,
  code_description = NULL,
  term_iri = NULL,
  vocabulary_iri = NULL,
  quiet = FALSE
)
```

## Arguments

- path:

  Path to the package directory.

- ...:

  Any other field the SDP schema declares for that file, as
  `name = value`.

- title, description, creator, contact_name, contact_email, contact_org,
  license:

  `dataset.csv` fields.

- quiet:

  Logical; suppress the confirmation message.

- table:

  Table identifier. For `set_sdp_column()` and `set_sdp_code()` it is
  needed only when the column name appears in more than one table;
  [`review_metadata()`](https://salmon-data-mobilization.github.io/metasalmon/reference/review_metadata.md)
  always prints it.

- table_label, observation_unit, observation_unit_iri:

  `tables.csv` fields.

- column:

  Column name of the dictionary or codes row.

- column_label, column_description, unit_label:

  `column_dictionary.csv` free-text fields.

- term_iri, property_iri, entity_iri, unit_iri:

  `column_dictionary.csv` (and, for `term_iri`, `codes.csv`) semantic
  IRIs. Use these for a slot retrieval found no candidate for; use
  [`accept_suggestion()`](https://salmon-data-mobilization.github.io/metasalmon/reference/accept_suggestion.md)
  when there is a shortlist to choose from.

- code_value:

  The code value identifying a `codes.csv` row.

- code_label, code_description, vocabulary_iri:

  `codes.csv` fields.

## Value

The package path, invisibly.

## Details

These are the calls
[`review_metadata()`](https://salmon-data-mobilization.github.io/metasalmon/reference/review_metadata.md)
prints. Replace the `<...>` placeholder with the real value and paste –
pasting one unedited is refused with a message saying so, because a
package whose `creator` reads
`<add creator, team, or originating program>` would pass strict
validation while saying nothing.

Pass `NA` to clear a field deliberately; a blank string is refused as
ambiguous.

The fields a setter accepts come from the same SDP schema
[`review_metadata()`](https://salmon-data-mobilization.github.io/metasalmon/reference/review_metadata.md)
reads, so a call it prints is one the setter accepts. Under the default
options that is the copy bundled with metasalmon, and neither contacts a
network.

## See also

[`review_metadata()`](https://salmon-data-mobilization.github.io/metasalmon/reference/review_metadata.md),
[`accept_suggestion()`](https://salmon-data-mobilization.github.io/metasalmon/reference/accept_suggestion.md),
[`validate_salmon_datapackage()`](https://salmon-data-mobilization.github.io/metasalmon/reference/validate_salmon_datapackage.md)

## Examples

``` r
pkg <- create_sdp(
  data.frame(spawner_count = c(12L, 19L)),
  path = tempfile("sdp-setter-"),
  seed_semantics = FALSE,
  seed_verbose = FALSE,
  check_updates = FALSE
)
#> Some measurement semantic IRI fields are still blank in this review-ready
#> package.
#> ℹ That does not block review-ready creation, but those gaps must be filled
#>   before final validation or publication.
#>   term_iri: spawner_count (rows 1) property_iri: spawner_count (rows 1)
#>   entity_iri: spawner_count (rows 1) unit_iri: spawner_count (rows 1)
#> ℹ Review metadata/column_dictionary.csv first (and metadata/tables.csv if
#>   present), then fill the remaining gaps there.
#> ℹ If you want candidate IRIs later, run `suggest_semantics()` or recreate the
#>   package with `seed_semantics = TRUE` before final validation.
#> ✔ Dictionary validation passed
#> ✔ Created Salmon Data Package at /var/folders/pm/twz8_z1j6_zb996w0b17bz2r0000gn/T//RtmpP4K6i1/sdp-setter-11011203e8d3
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
set_sdp_dataset(
  pkg,
  creator = "Fisheries and Oceans Canada",
  contact_name = "Data Unit",
  contact_email = "data@example.org",
  license = "CC-BY-4.0"
)
#> ✔ Set 4 fields in dataset.csv: creator, contact_name, contact_email, and license.
review_metadata(pkg)
#> ── dataset.csv ───────────────────────────────────────────────────────────────
#>    description: placeholder text, refused by strict validation
#>       MISSING DESCRIPTION: describe the contents and purpose of dataset
#>       'dataset-1'.
#>
#>    set_sdp_dataset("/var/folders/pm/twz8_z1j6_zb996w0b17bz2r0000gn/T//RtmpP4K6i1/sdp-setter-11011203e8d3",
#>      description = "<describe the contents and purpose of dataset 'dataset-1'>"
#>    )
#>
#> ── tables.csv · table_1 ──────────────────────────────────────────────────────
#>    description: placeholder text, refused by strict validation
#>       MISSING DESCRIPTION: describe what each row in table 'table_1'
#>       represents.
#>    observation_unit: placeholder text, refused by strict validation
#>       MISSING METADATA: describe the observation unit for table 'table_1'.
#>    observation_unit_iri: required IRI and not yet decided
#>
#>    set_sdp_table("/var/folders/pm/twz8_z1j6_zb996w0b17bz2r0000gn/T//RtmpP4K6i1/sdp-setter-11011203e8d3", "table_1",
#>      description = "<describe what each row in table 'table_1' represents>",
#>      observation_unit = "<describe the observation unit for table 'table_1'>",
#>      observation_unit_iri = "<IRI for what one row represents>"
#>    )
#>
#> ── column_dictionary.csv · table_1 · spawner_count ───────────────────────────
#>    column_description: placeholder text, refused by strict validation
#>       MISSING DESCRIPTION: define what 'spawner_count' means in table
#>       'table_1'.
#>    term_iri: required IRI and not yet decided
#>    property_iri: required IRI and not yet decided
#>    entity_iri: required IRI and not yet decided
#>    unit_iri: required IRI and not yet decided
#>
#>    set_sdp_column("/var/folders/pm/twz8_z1j6_zb996w0b17bz2r0000gn/T//RtmpP4K6i1/sdp-setter-11011203e8d3", "spawner_count", table = "table_1",
#>      column_description = "<define what 'spawner_count' means in table 'table_1'>",
#>      term_iri = "<IRI for term_iri>",
#>      property_iri = "<IRI for property_iri>",
#>      entity_iri = "<IRI for entity_iri>",
#>      unit_iri = "<IRI for unit_iri>"
#>    )
#>
#> ── next ──────────────────────────────────────────────────────────────────────
#>    9 fields still block strict validation.
#>    Replace each <...> with the real value, then paste the calls above.
#>    5 of them are IRIs -- review_semantics() shows candidates for any that have them.
#>    Then: validate_salmon_datapackage("/var/folders/pm/twz8_z1j6_zb996w0b17bz2r0000gn/T//RtmpP4K6i1/sdp-setter-11011203e8d3", require_iris = TRUE)
#>
```
