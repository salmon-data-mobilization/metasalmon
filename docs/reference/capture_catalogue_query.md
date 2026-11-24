# Capture a bounded public catalogue metadata query

Capture unauthenticated KNB or DataONE Solr metadata pages with a
provenance receipt. This is an interim metadata-discovery helper, not a
Salmon Data Package, a submission catalogue, or the full
source-fetch/DatasetReceipt API.

## Usage

``` r
capture_catalogue_query(
  query,
  out,
  catalogue = "knb",
  max_records = 100L,
  page_size = 50L,
  timeout = 30,
  max_bytes = 2000000L,
  fetch = NULL,
  captured_at = NULL
)
```

## Arguments

- query:

  One nonblank Solr query string, at most 4096 characters.

- out:

  A new output directory. Existing destinations (including dangling
  symlinks) or an existing `.incomplete` sibling are never overwritten.

- catalogue:

  Exactly `"knb"` (default) or `"dataone"`. Endpoints come from the
  existing production KNB environment registry; no custom endpoint.

- max_records:

  Maximum metadata records to capture, a whole number from 1 to 1000. A
  cap-limited capture is not a complete catalogue search.

- page_size:

  Requested records per page, a whole number from 1 to 100.

- timeout:

  Positive request timeout, at most 120 seconds.

- max_bytes:

  Maximum bytes per raw page, a whole number from 1 to 10000000.
  Default: 2000000. Enforced by both the default and injected fetch.

- fetch:

  Optional function `fetch(url, timeout, max_bytes)` returning a raw
  vector. Use this seam for offline fixtures or explicitly controlled
  public network routing; `NULL` uses direct public HTTPS with inherited
  proxies and netrc credentials disabled.

- captured_at:

  Optional ISO timestamp including timezone. `NULL` records the current
  UTC capture time, not historical data availability.

## Value

A list also written to `out/capture.json`, containing query, endpoint,
capture time, reported/captured metadata counts, completeness, page URLs
and byte SHA-256 checksums, and untransformed metadata records.
`annotation_status` remains `"pending"`, `independent_dataset_count` is
`NULL`, and `transactional_snapshot` is `FALSE`.

## Details

The fixed filter is `formatType:METADATA`; results request `id asc`
sorting. Paging offsets, count stability, missing/repeated identifiers
and premature empty pages are checked. Response counts/offsets must be
finite nonnegative integer-valued JSON numbers no greater than
`2^53 - 1`, excluding booleans; `3` and `3.0` have the same mathematical
meaning. A live index can still change without changing its count, so
even a complete-for-reported-count capture is not transactional.
Metadata versions/encounters are not independent datasets. Source
objects are not downloaded, semantic decisions are not accepted, and
credentials, model providers and publication APIs are not used.

The destination is reserved before fetching. On failure an `.incomplete`
sibling is exclusively reserved for raw pages and `failure.json`; if
that sibling appeared concurrently, the owned output directory remains
instead. Errors are propagated and no successful receipt is reported.
Inspect preserved evidence and rerun to a new destination rather than
overwriting it.

## Examples

``` r
# Offline example; no catalogue or provider is contacted.
mock <- function(url, timeout, max_bytes) {
  charToRaw('{"response":{"numFound":0,"start":0,"docs":[]}}')
}
output <- tempfile("catalogue-capture-")
receipt <- capture_catalogue_query("Fraser AND sockeye", output, fetch = mock)
receipt$captured_metadata_records
#> [1] 0
unlink(output, recursive = TRUE)
```
