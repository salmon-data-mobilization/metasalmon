# Report the metadata a package still needs, with the call that fills it

Lists every field that still blocks
`validate_salmon_datapackage(path, require_iris = TRUE)`, and prints the
exact
[`set_sdp_dataset()`](https://salmon-data-mobilization.github.io/metasalmon/reference/set_sdp_dataset.md)
/
[`set_sdp_table()`](https://salmon-data-mobilization.github.io/metasalmon/reference/set_sdp_dataset.md)
/
[`set_sdp_column()`](https://salmon-data-mobilization.github.io/metasalmon/reference/set_sdp_dataset.md)
/
[`set_sdp_code()`](https://salmon-data-mobilization.github.io/metasalmon/reference/set_sdp_dataset.md)
call that fills it. Replace the `<...>` placeholder in the printed call
with the real value and paste it – the paste is the audit trail, just as
it is for
[`accept_suggestion()`](https://salmon-data-mobilization.github.io/metasalmon/reference/accept_suggestion.md).

## Usage

``` r
review_metadata(path)
```

## Arguments

- path:

  Path to the package directory.

## Value

An `ms_metadata_review` tibble subclass, one row per unfilled field,
with the package path attached as the `review_path` attribute. Empty
when nothing is outstanding.

## Details

This is the companion to
[`review_semantics()`](https://salmon-data-mobilization.github.io/metasalmon/reference/review_semantics.md),
and it sees something that review structurally cannot: **a slot with no
candidates at all**.
[`review_semantics()`](https://salmon-data-mobilization.github.io/metasalmon/reference/review_semantics.md)
builds its queue from retrieved suggestions, so a field nothing was
found for never appears there. `review_metadata()` builds its list from
the package's own required-field rules, so an empty shortlist and a full
one look the same to it.

What it reports:

- unresolved `MISSING DESCRIPTION:` / `MISSING METADATA:` /
  `REVIEW REQUIRED:` placeholders in any metadata field;

- schema-required fields (`constraints.required`) that are blank – a
  column the file does not have counts as blank in every row;

- draft IRIs still carrying the `REVIEW:` prefix wherever strict
  validation refuses one: any schema-declared `*_iri` field of
  `tables.csv`, and the six semantic IRI fields of
  `column_dictionary.csv` (`term_iri`, `property_iri`, `entity_iri`,
  `unit_iri`, `constraint_iri` and `statistical_modifier_iri`). A marker
  in `codes.csv` or `dataset.csv` is not listed, because strict
  validation does not refuse it there. Where retrieval found candidates
  for one,
  [`review_semantics()`](https://salmon-data-mobilization.github.io/metasalmon/reference/review_semantics.md)
  shows them;

- measurement columns missing `term_iri`, `property_iri`, `entity_iri`
  or `unit_iri`;

- `tables.csv` rows with a blank `observation_unit_iri`.

It never contacts an LLM, and under the default options it never
contacts a network: the SDP schema it reads the required fields from is
the copy bundled with metasalmon. When the
`metasalmon.sdp_schema_source` or `metasalmon.sdp_schema_base_url`
option selects a different schema, it reads that one, as the package
writers do: from this session's cache once they have loaded it, and
otherwise by fetching it as they would.

## See also

[`set_sdp_dataset()`](https://salmon-data-mobilization.github.io/metasalmon/reference/set_sdp_dataset.md),
[`review_semantics()`](https://salmon-data-mobilization.github.io/metasalmon/reference/review_semantics.md),
[`validate_salmon_datapackage()`](https://salmon-data-mobilization.github.io/metasalmon/reference/validate_salmon_datapackage.md)

## Examples

``` r
pkg <- create_sdp(
  data.frame(spawner_count = c(12L, 19L)),
  path = tempfile("sdp-review-"),
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
#> ✔ Created Salmon Data Package at /var/folders/pm/twz8_z1j6_zb996w0b17bz2r0000gn/T//RtmpP4K6i1/sdp-review-1101157331d76
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
review_metadata(pkg)
#> ── dataset.csv ───────────────────────────────────────────────────────────────
#>    description: placeholder text, refused by strict validation
#>       MISSING DESCRIPTION: describe the contents and purpose of dataset
#>       'dataset-1'.
#>    creator: placeholder text, refused by strict validation
#>       MISSING METADATA: add creator, team, or originating program.
#>    contact_name: placeholder text, refused by strict validation
#>       MISSING METADATA: add primary contact name or team.
#>    contact_email: placeholder text, refused by strict validation
#>       MISSING METADATA: add primary contact email.
#>
#>    set_sdp_dataset("/var/folders/pm/twz8_z1j6_zb996w0b17bz2r0000gn/T//RtmpP4K6i1/sdp-review-1101157331d76",
#>      description = "<describe the contents and purpose of dataset 'dataset-1'>",
#>      creator = "<add creator, team, or originating program>",
#>      contact_name = "<add primary contact name or team>",
#>      contact_email = "<add primary contact email>"
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
#>    set_sdp_table("/var/folders/pm/twz8_z1j6_zb996w0b17bz2r0000gn/T//RtmpP4K6i1/sdp-review-1101157331d76", "table_1",
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
#>    set_sdp_column("/var/folders/pm/twz8_z1j6_zb996w0b17bz2r0000gn/T//RtmpP4K6i1/sdp-review-1101157331d76", "spawner_count", table = "table_1",
#>      column_description = "<define what 'spawner_count' means in table 'table_1'>",
#>      term_iri = "<IRI for term_iri>",
#>      property_iri = "<IRI for property_iri>",
#>      entity_iri = "<IRI for entity_iri>",
#>      unit_iri = "<IRI for unit_iri>"
#>    )
#>
#> ── next ──────────────────────────────────────────────────────────────────────
#>    12 fields still block strict validation.
#>    Replace each <...> with the real value, then paste the calls above.
#>    5 of them are IRIs -- review_semantics() shows candidates for any that have them.
#>    Then: validate_salmon_datapackage("/var/folders/pm/twz8_z1j6_zb996w0b17bz2r0000gn/T//RtmpP4K6i1/sdp-review-1101157331d76", require_iris = TRUE)
#>
```
