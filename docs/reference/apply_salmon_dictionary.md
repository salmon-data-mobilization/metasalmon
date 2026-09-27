# Apply a salmon dictionary to a data frame

Renames columns, coerces types, applies factor levels from codes, and
reports mismatches. Returns a transformed tibble ready for analysis or
packaging.

## Usage

``` r
apply_salmon_dictionary(df, dict, codes = NULL, strict = TRUE)
```

## Arguments

- df:

  A data frame or tibble to transform

- dict:

  A validated dictionary tibble

- codes:

  Optional tibble with code lists (columns: `dataset_id`, `table_id`,
  `column_name`, `code_value`, `code_label`, etc.)

- strict:

  Logical; if `TRUE` (default), errors on type coercion failures; if
  `FALSE`, warns and coerces to character. A coercion failure is one
  that R reports with a warning as well as one it reports with an error,
  so a column typed `integer` holding `"abc"` is a failure even though
  `as.integer("abc")` only warns and returns `NA`.

## Value

A tibble with renamed columns, coerced types, and factor levels applied

## Details

A value that is not in its column's code list has no factor level, so it
becomes `NA`. Each such value is named in a warning, whatever `strict`
is. Blank strings are treated as missing and are not reported.

## Examples

``` r
dict <- infer_dictionary(mtcars)
validate_dictionary(dict)
#> ✔ Dictionary validation passed
applied <- apply_salmon_dictionary(mtcars, dict)
#> ✔ Dictionary validation passed
```
