# Suggest facet schemes for proposed terms

Analyzes a proposed terms dataframe and suggests which facet schemes
(age class, life phase, etc.) should be created instead of proliferating
individual terms.

## Usage

``` r
suggest_facet_schemes(proposed_terms)
```

## Arguments

- proposed_terms:

  A data frame with term_label column

## Value

A tibble with suggested facet schemes and their member concepts

## Examples

``` r
proposed <- tibble::tibble(
  term_label = c("Spawner Age 1", "Spawner Age 2", "Spawner Age 3")
)
facets <- suggest_facet_schemes(proposed)
facets$scheme_name
#>   AgeClassScheme
#> "AgeClassScheme"
```
