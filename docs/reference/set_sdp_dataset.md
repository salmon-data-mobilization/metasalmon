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

## See also

[`review_metadata()`](https://salmon-data-mobilization.github.io/metasalmon/reference/review_metadata.md),
[`accept_suggestion()`](https://salmon-data-mobilization.github.io/metasalmon/reference/accept_suggestion.md),
[`validate_salmon_datapackage()`](https://salmon-data-mobilization.github.io/metasalmon/reference/validate_salmon_datapackage.md)

## Examples

``` r
if (FALSE) { # \dontrun{
pkg <- create_sdp(resources, dataset_id = "demo-1")
review_metadata(pkg)
set_sdp_dataset(
  pkg,
  creator = "Fisheries and Oceans Canada",
  contact_name = "Data Unit",
  contact_email = "data@example.org",
  license = "CC-BY-4.0"
)
set_sdp_table(pkg, "spawners", description = "One row per stream and year.")
set_sdp_column(pkg, "spawner_count", column_description = "Spawners counted.")
} # }
```
