# Built-in NuSEDS example data

`metasalmon` ships two Fraser coho example tables so users can choose a tiny demo
or a fuller official slice, and one complete Salmon Data Package built from the
fuller slice: the Fraser coho gold standard.

## Included files

| File | Rows | Years | Intended use |
| --- | ---: | --- | --- |
| `nuseds-fraser-coho-sample.csv` | 30 | 1996–2024 | Smallest possible walkthroughs, fast examples, light semantic seeding demos |
| `nuseds-fraser-coho-2023-2024.csv` | 173 | 2023–2024 | More realistic package creation, testing, and documentation examples |
| `nuseds-fraser-coho-2023-2024-sdp/` | 173 | 2023–2024 | The gold standard: the 173-row slice as a complete, validated Salmon Data Package |

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
- Column definitions: the NuSEDS data dictionary, `Data_Dictionary_NuSEDS_EN.csv`,
  and the sub-district legend of the "Map of Areas", both attached to the same
  record

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

## The gold standard: `nuseds-fraser-coho-2023-2024-sdp/`

The 173-row slice as a complete Salmon Data Package, with its own
`dataset_id` (`fraser-coho-2023-2024`) and all four metadata files:

```
nuseds-fraser-coho-2023-2024-sdp/
  datapackage.json
  metadata/dataset.csv
  metadata/tables.csv
  metadata/column_dictionary.csv
  metadata/codes.csv
  data/escapement.csv        # nuseds-fraser-coho-2023-2024.csv, byte for byte
```

It passes `validate_salmon_datapackage(path, require_iris = TRUE)` and the Salmon
Data Package specification's own `scripts/validate_package.py` with no issues.
`data-raw/fraser_coho_gold_standard.R` in the source repository builds it,
offline and byte for byte, with the package's own functions: `create_sdp()`, the
`set_sdp_*()` setters for the text, and `suggest_semantics()` →
`review_semantics()` → `accept_suggestion()` / `reject_suggestion()` →
`apply_sdp_semantics()` for the IRIs. The script is the record of every
decision, including the reason for each IRI it leaves blank; a test rebuilds the
package with it and fails if the shipped bytes drift.

```r
pkg_path <- system.file("extdata", "nuseds-fraser-coho-2023-2024-sdp", package = "metasalmon")
validate_salmon_datapackage(pkg_path, require_iris = TRUE)
```

What is annotated, and what is not:

- **The spawner count is fully decomposed.** `NATURAL_ADULT_SPAWNERS` carries
  `gcdfo:SpawnerAbundance` (variable), `smn:Abundance` (property),
  `smn:Population` (entity) and QUDT `Individual` (unit). Each row is an
  `smn:EscapementEstimate` (the table's observation unit), keyed by
  `POP_ID`, `ANALYSIS_YR` and `WATERBODY`: NuSEDS keeps one record per waterbody
  that bounds a population, so population and year alone repeat on 9 rows.
- **The estimate method and classification codes resolve to `gcdfo`**, the
  methods to `gcdfo:EstimateMethodScheme` and the Type-1 to Type-5
  classifications to `gcdfo:EstimateTypeScheme`.
- **`ANALYSIS_YR`, `WATERBODY` and `SPECIES`** carry `smn:returnYear`,
  Darwin Core `waterBody` and Darwin Core `vernacularName`.
- **Blank on purpose.** No released term exists for a NuSEDS sub-district
  (`AREA`), a run timing (`RUN_TYPE`), an estimate stage, a population's name, a
  BC watershed code or the inspection dates, nor for the codes `Not Applicable`,
  `Fence`, `NO SURVEY THIS YEAR` and `FINAL`. Two more are open decisions: which
  external taxonomy the species code `Coho` points at, and a term for the
  estimate method `Combined Methods`. The spawner count's `property_iri` is the
  interim answer to an open question (hub question Q9), and the dataset's
  creator, contact and licence are interim too. The script lists every one of
  these in `pending_decisions`.

**`AREA` holds DFO sub-districts, not Pacific Fishery Management Areas.** NuSEDS
defines `AREA` as the subdistrict, which in most cases is the same as the
statistical area; the codes here (29F Lillooet, 29G Williams Lake,
29J Clearwater, 29K Salmon Arm) are sub-districts of the NuSEDS Map of Areas.
The PFMA Subareas `gcdfo` mints are numbered 29-1 to 29-17 and are a different
division, so none of them is the term for these codes. Both example
dictionaries described the column as a PFMA code until 2026-09 (hub item B-401).

**Strict validation is not the publication gate.** Depositing the gold
standard with `publish_sdp_to_knb()` additionally needs the reviewed closure
(`write_sdp_semantic_closure()`), a reviewed `metadata/eml-mapping.yml` and a
DataONE token; `scripts/build-fraser-coho-knb-rehearsal.R` in the source
repository is the worked reference for that path.

## Notes on the tiny demo

The legacy 30-row `nuseds-fraser-coho-sample.csv` file remains in place as the
fastest built-in demo. Its bundled example metadata continues to live in:

- `inst/extdata/dataset.csv`
- `inst/extdata/tables.csv`
- `inst/extdata/column_dictionary.csv`
- `inst/extdata/codes.csv`

Use the tiny sample when you want the quickest end-to-end walkthrough. Use the
173-row official slice when you want something closer to real Fraser coho data
without shipping the full NuSEDS workbook, and the gold standard when you want
to see what a finished package looks like.

## Notes on the fuller example's starter dictionary

The fuller example also ships a starter dictionary,
`nuseds-fraser-coho-2023-2024-column_dictionary.csv`, which you can pass
directly as an LLM context file or use as a seed for manual review. Its labels,
descriptions, roles and types are the gold standard's; its IRIs are the state
before semantic review:

- **Exactly one of its 14 dictionary rows carries any IRI.**
  `NATURAL_ADULT_SPAWNERS` is fully annotated — `term_iri`, `property_iri`,
  `entity_iri`, `unit_iri`, and `term_type` — and the other 13 rows are
  unannotated. Its `entity_iri` is `smn:Population`, **not** the
  `gcdfo:ConservationUnit` the 30-row demo uses: this slice keys on `POP_ID`,
  which is a finer grain than a CU.
- **It clears metasalmon's strict gate, not the specification's.** Build a
  package from the 173-row CSV, put this dictionary in `metadata/`, fill the
  `MISSING METADATA:` placeholders `create_sdp()` writes into `dataset.csv` and
  `tables.csv`, and `validate_salmon_datapackage(pkg_path, require_iris = TRUE)`
  passes. Its six coded columns are `categorical`, matching the `codes.csv` rows
  `create_sdp()` writes for them. The specification's
  `scripts/validate_package.py` still fails that package, because copying a
  dictionary into `metadata/` by hand leaves `datapackage.json` describing the
  dictionary `create_sdp()` wrote, and metasalmon's validator does not compare
  the two. The gold standard, whose build writes every field through the
  package's own functions, is the one that passes both.
- **No method or protocol binding ships with it, or with the gold standard.**
  `ESTIMATE_METHOD` varies from row to row in the data, but nothing here carries
  a `protocol_iri` and nothing declares the column as `sosa:usedProcedure`.
  `create_sdp()` resolves most `ESTIMATE_METHOD` values to `gcdfo` method IRIs
  in the `codes.csv` it generates — the ingredient for such a binding, not the
  binding itself, which lives in the observation-structures extension and
  requires a procedure term for every code, which `Not Applicable`, `Fence` and
  `Combined Methods` do not have.

## Abundance and its unit, in the dictionaries

The bundled spawner-count rows deliberately separate the ecological
characteristic from its unit. Values are expressed in QUDT `Individual`, while
`property_iri` uses the released Salmon Domain Ontology `smn:Abundance`
characteristic. In particular, do not restore the former QUDT
`NumberOfOrganisms` value: that IRI does not exist, and a counting unit is not a
substitute for the ecological property being measured.

The gold standard writes QUDT's own IRI for the unit,
`http://qudt.org/vocab/unit/INDIV`. The two starter dictionaries still carry the
`https://qudt.org/vocab/unit/INDIV` spelling, which resolves to the same page
but is a different IRI.

The tiny sample's annotated row also resolves end to end (2026-08, backlog
#99): `term_iri` is the released `gcdfo:SpawnerAbundance` (an `owl:Class`, so
`term_type` is `owl_class`) and `constraint_iri` is the released
`smn:NaturalOrigin` concept, replacing two placeholder IRIs under
`w3id.org/example/salmon#` that returned HTTP 404. Placeholders that look like
real IRIs pass every offline check; an unfinished IRI belongs behind the
`REVIEW:` marker instead, which strict validation refuses to ship. The gold
standard does not carry `smn:NaturalOrigin`: NuSEDS counts natural spawners
apart from artificial spawners such as hatchery broodstock, so *natural* there
describes where the fish spawn, not where they were born.
