# Extract normalized logical observations from an SDP

Validates the paired structure metadata, filters rows where each
structure's measure is absent, selects components in declared order, and
collapses exact repeats at a coarser declared grain. The result remains
a list because different structures can have different component columns
and data types.

## Usage

``` r
extract_sdp_observations(
  path,
  table_id = NULL,
  observation_structure_id = NULL
)
```

## Arguments

- path:

  Existing Salmon Data Package directory.

- table_id:

  Optional scalar table identifier used to select structures.

- observation_structure_id:

  Optional scalar structure identifier used to select structures. Supply
  `table_id` too when the identifier is not unique across tables.

## Value

A deterministically named list of tibbles, one per selected logical
structure. Names use `table_id::observation_structure_id`.
