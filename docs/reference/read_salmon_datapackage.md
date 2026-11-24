# Read a Salmon Data Package

Loads a Salmon Data Package from disk. When canonical SDP CSV metadata
files are present, those are treated as the source of truth. If they are
missing, the function falls back to reconstructing metadata from
`datapackage.json` for backwards compatibility with older `metasalmon`
outputs.

## Usage

``` r
read_salmon_datapackage(path)
```

## Arguments

- path:

  Character; path to directory containing Salmon Data Package files

## Value

A list with components:

- `dataset`: Dataset metadata tibble

- `tables`: Table metadata tibble

- `dictionary`: Dictionary tibble

- `codes`: Codes tibble (if available)

- `resources`: Named list of data tibbles

## Examples

``` r
# Read the bundled example package without a network call.
example_path <- system.file("extdata", package = "metasalmon")
pkg <- read_salmon_datapackage(example_path)
#> ✔ Loaded Salmon Data Package from /tmp/RtmpuFZJ3j/temp_libpath6155326754a4/metasalmon/extdata
names(pkg$resources)
#> [1] "nuseds_fraser_coho"
```
