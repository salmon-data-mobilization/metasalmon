# Built-in NuSEDS example data

`metasalmon` ships two Fraser coho example tables so users can choose a tiny demo
or a fuller official slice.

## Included files

| File | Rows | Years | Intended use |
| --- | ---: | --- | --- |
| `nuseds-fraser-coho-sample.csv` | 30 | 1996–2024 | Smallest possible walkthroughs, fast examples, light semantic seeding demos |
| `nuseds-fraser-coho-2023-2024.csv` | 173 | 2023–2024 | More realistic package creation, testing, and documentation examples |

The tiny sample's `START_DTT`/`END_DTT` values were converted from the Oracle
`DD-MON-YY` format NuSEDS exports to ISO dates (2026-08, backlog #98): its
bundled dictionary declares `value_type: date`, and the shipped pair must pass
`validate_salmon_datapackage()` — an example that fails the package's own
final gate teaches the wrong thing. The conversion used the same
`%d-%b-%y` parse the package's temporal inference applies, so the dates are
unchanged in meaning; every other byte of the file is as originally shipped.
This matches the fuller example, whose derivation script already converts the
same columns to ISO.

## Provenance for the fuller official example

- Open Government Canada record: <https://open.canada.ca/data/en/dataset/c48669a3-045b-400d-b730-48aafe8c5ee6>
- Upstream resource used: <https://api-proxy.edh-cde.dfo-mpo.gc.ca/catalogue/records/c48669a3-045b-400d-b730-48aafe8c5ee6/attachments/Fraser%20and%20BC%20Interior%20NuSEDS_20251014.xlsx>
- Resource label: `Fraser and BC Interior NuSEDS_20251014.xlsx`
- Publisher: Fisheries and Oceans Canada
- Licence: Open Government Licence - Canada

## Reproducible derivation

The source repository includes `data-raw/nuseds_fraser_coho_examples.R`, which
recreates `nuseds-fraser-coho-2023-2024.csv` by:

1. downloading the official Fraser and BC Interior workbook,
2. filtering to `SPECIES == "Coho"`,
3. filtering to `ANALYSIS_YR %in% c(2023, 2024)`,
4. keeping a compact analysis-friendly subset of columns,
5. using `NATURAL_ADULT_SPAWNERS` because `NATURAL_SPAWNERS_TOTAL` is blank for
   this official two-year slice,
6. converting `START_DTT` and `END_DTT` to ISO dates, and
7. sorting by `ANALYSIS_YR`, `AREA`, `WATERBODY`, and `POP_ID`.

## Notes on the tiny demo

The legacy 30-row `nuseds-fraser-coho-sample.csv` file remains in place as the
fastest built-in demo. Its bundled example metadata continues to live in:

- `inst/extdata/dataset.csv`
- `inst/extdata/tables.csv`
- `inst/extdata/column_dictionary.csv`
- `inst/extdata/codes.csv`

Use the tiny sample when you want the quickest end-to-end walkthrough. Use the
173-row official slice when you want something closer to real Fraser coho data
without shipping the full NuSEDS workbook.

## Notes on the fuller example — a starter, not a finished package

The fuller example ships with a matching starter dictionary,
`nuseds-fraser-coho-2023-2024-column_dictionary.csv`, which you can pass
directly as an LLM context file or use as a seed for manual review.

Read the rest of this section before you treat it as a model SDP. Four things
are true of it as shipped:

- **No `dataset.csv`, `tables.csv` or `codes.csv` ship for it.** The files of
  those names in this folder belong to the 30-row demo — their `dataset_id` is
  `nuseds_fraser_coho_sample`, not `fraser-coho-2023-2024`. The fuller example
  is a data CSV plus a column dictionary; the other three metadata levels are
  what `create_sdp()` generates for you, not something you can copy from here.
- **Exactly one of its 14 dictionary rows carries any IRI.**
  `NATURAL_ADULT_SPAWNERS` has `property_iri` and `unit_iri`; even that row
  leaves `term_iri` and `entity_iri` blank, and the other 13 rows are
  unannotated.
- **It does not pass strict validation as shipped.** Build a package from the
  173-row CSV, put this dictionary in `metadata/`, and
  `validate_salmon_datapackage(pkg_path, require_iris = TRUE)` fails with:

  ```
  Measurement columns require term_iri; missing in rows 8.
  ```

  That is the expected state of a *starter*: strict mode is the final gate, and
  semantic review is what gets you through it. Do not read the example as a
  validated package, and do not work around the failure — fill the IRIs.
- **No method or protocol binding ships with it.** `ESTIMATE_METHOD` varies
  from row to row in the data, but nothing here carries a `protocol_iri` and
  nothing declares the column as `sosa:usedProcedure`. `create_sdp()` does
  resolve most `ESTIMATE_METHOD` values to `gcdfo` method IRIs in the
  `codes.csv` it generates — that is the ingredient for such a binding, not the
  binding itself, which lives in the observation-structures extension the
  example does not use.

## Abundance and its unit, in both dictionaries

The bundled spawner-count rows deliberately separate the ecological
characteristic from its unit. Values are expressed in QUDT `Individual`
(`https://qudt.org/vocab/unit/INDIV`), while `property_iri` uses the released
Salmon Domain Ontology `smn:Abundance` characteristic. In particular, do not
restore the former QUDT `NumberOfOrganisms` value: that IRI does not exist, and
a counting unit is not a substitute for the ecological property being measured.
