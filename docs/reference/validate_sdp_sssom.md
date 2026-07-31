# Validate SDP SSSOM artifacts

Validates either one SSSOM 1.1 embedded-TSV file or an SDP directory.
For an SDP directory, the function validates
`metadata/semantic/mapping-sets.json`, safe relative paths, byte hashes,
row counts, metadata provenance, and every referenced mapping set.

## Usage

``` r
validate_sdp_sssom(path)
```

## Arguments

- path:

  Path to an SDP directory or one `.sssom.tsv` mapping set.

## Value

`TRUE`, invisibly, when validation succeeds; otherwise an error.
