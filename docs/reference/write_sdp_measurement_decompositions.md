# Write ordered measurement decompositions into a Salmon Data Package

Writes explicit decomposition rows to
`metadata/semantic/measurement-decompositions.csv` and binds the exact
deterministic bytes to `measurement-decompositions.json`. The writer
never infers components, splits labels, or converts decompositions into
SSSOM mappings. Supplying `decompositions = NULL` is an explicit no-op.

## Usage

``` r
write_sdp_measurement_decompositions(
  path,
  decompositions = NULL,
  overwrite = FALSE
)
```

## Arguments

- path:

  Existing Salmon Data Package directory.

- decompositions:

  `NULL` or a non-empty data frame matching the ordered
  measurement-decomposition schema.

- overwrite:

  Logical; replace artifacts managed by this writer when `TRUE`.

## Value

The manifest path, invisibly, or `NULL` when `decompositions` is `NULL`.

## Details

Each row has the following closed schema:

- `dataset_id`, `table_id`, and `column_name` bind the decomposition to
  one measurement row in `metadata/column_dictionary.csv`.

- `measurement_concept_iri` must exactly equal that dictionary row's
  `term_iri`.

- `component_order` is a positive, contiguous, per-measurement sequence.

- `component_role` is one of `property`, `entity`, `constraint`,
  `statistical_modifier`, or `unit`; repeated roles are allowed.

- `component_status` is `matched` or `gap`. A matched row requires an
  absolute `component_iri`. A gap requires a blank `component_iri` plus
  a non-empty `component_label` and `rationale`.

- `component_relation` and `related_component_order` are normally blank.
  `value_of_dimension` links a matched constraint value to an earlier
  matched constraint dimension in the same measurement; for example, an
  age-1 class can target its freshwater-age dimension without flattening
  the two constraints.

- `source`, `source_version`, `source_url`, and `provenance` identify
  the pinned source and review evidence. `component_label` and
  `rationale` preserve caller-supplied text; they are never tokenized or
  inferred.

Every non-empty dictionary `property_iri`, `entity_iri`,
`constraint_iri`, `statistical_modifier_iri`, and `unit_iri` must appear
as a matched component of the same role. Semicolon-separated dictionary
constraints are checked separately. Additional same-role components and
explicit gaps stay only in this artifact, leaving the frozen SDP
dictionary columns unchanged. This is an ordered SDP semantic profile
informed by I-ADOPT roles, not a claim of native I-ADOPT conformance.
