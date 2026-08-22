# NuSEDS estimate classification crosswalk

Return a static crosswalk of NuSEDS `ESTIMATE_CLASSIFICATION` values to
the released gcdfo Hyatt (1997) estimate-type concepts
(`gcdfo:Type1`–`gcdfo:Type6`, `skos:Concept`s under
`gcdfo:EstimateType`).

## Usage

``` r
nuseds_estimate_classification_crosswalk()
```

## Value

A tibble with columns `nuseds_value`, `estimate_type`, `ontology_term`,
and `notes`.

## Details

Two families of values deliberately map to no Type concept, and the
distinction is recorded here rather than forced:

- `NO SURVEY THIS YEAR` is an absence-of-observation marker, not an
  estimate type – assigning any Hyatt type would assert a survey quality
  for a survey that did not happen. It maps to `NA` with a note.

- `RELATIVE: CONSTANT MULTI-YEAR METHODS` /
  `RELATIVE: VARYING MULTI-YEAR METHODS` are real classifications with
  no released concept of their own; they link at scheme level
  (`gcdfo:EstimateType`), the same convention
  [`nuseds_estimate_method_crosswalk()`](https://salmon-data-mobilization.github.io/metasalmon/reference/nuseds_estimate_method_crosswalk.md)
  uses for `Cumulative CPUE`.

## See also

[`nuseds_estimate_method_crosswalk()`](https://salmon-data-mobilization.github.io/metasalmon/reference/nuseds_estimate_method_crosswalk.md),
[`nuseds_enumeration_method_crosswalk()`](https://salmon-data-mobilization.github.io/metasalmon/reference/nuseds_enumeration_method_crosswalk.md)

## Examples

``` r
nuseds_estimate_classification_crosswalk()
#> # A tibble: 10 × 4
#>    nuseds_value                          estimate_type ontology_term      notes
#>    <chr>                                 <chr>         <chr>              <chr>
#>  1 TRUE ABUNDANCE (TYPE-1)               Type-1        gcdfo:Type1        ""
#>  2 TRUE ABUNDANCE (TYPE-2)               Type-2        gcdfo:Type2        ""
#>  3 RELATIVE ABUNDANCE (TYPE-3)           Type-3        gcdfo:Type3        ""
#>  4 RELATIVE ABUNDANCE (TYPE-4)           Type-4        gcdfo:Type4        ""
#>  5 RELATIVE ABUNDANCE (TYPE-5)           Type-5        gcdfo:Type5        ""
#>  6 PRESENCE-ABSENCE (TYPE-6)             Type-6        gcdfo:Type6        ""
#>  7 NO SURVEY THIS YEAR                   NA            NA                 "Abse…
#>  8 RELATIVE: CONSTANT MULTI-YEAR METHODS NA            gcdfo:EstimateType "No r…
#>  9 RELATIVE: VARYING MULTI-YEAR METHODS  NA            gcdfo:EstimateType "No r…
#> 10 UNKNOWN                               NA            NA                 "Admi…
```
