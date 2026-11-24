# List ICES code types

List ICES code types

## Usage

``` r
ices_code_types(code_type = "", code_type_id = 0L, modified = "")
```

## Arguments

- code_type:

  Optional code type key or GUID to filter the API response.

- code_type_id:

  Optional numeric code type id to filter the API response.

- modified:

  Optional date string (`"YYYY-MM-DD"`) to return code types modified
  after that date.

## Value

Tibble of ICES code types (includes `key`, `description`, `guid`, etc.).
Empty when ICES answers with no rows, and also when the request fails,
which warns, naming the request.

## Examples

``` r
if (FALSE) { # \dontrun{
# Needs the live ICES service; run in checks once an offline fixture exists.
types <- ices_code_types(code_type = "Gear")
} # }
```
