# Verify selected HTTP semantic IRIs in a Salmon Data Package

Collects exact HTTP(S) identifiers from selected SDP semantic metadata,
including manifest-bound reviewed SSSOM mappings. Candidate suggestions,
arbitrary data URLs, and non-HTTP identifiers are excluded. GET requests
follow normal httr2 redirects and have a 30-second timeout. Only HTTP
408, 429, 5xx, and classified transient transport failures are retried,
with at most three attempts per IRI. All IRIs are checked before any
failure aborts.

## Usage

``` r
verify_sdp_semantic_iris(
  path,
  report_path = file.path(path, "reproducibility", "provenance",
    "semantic-iri-dereference.csv"),
  requester = .ms_semantic_iri_request,
  sleep_fn = Sys.sleep
)
```

## Arguments

- path:

  Existing Salmon Data Package directory.

- report_path:

  CSV output path. Defaults to
  `reproducibility/provenance/semantic-iri-dereference.csv` inside
  `path`.

- requester:

  GET function receiving one exact IRI and returning a list with integer
  `status` and character `final_url`. Intended for offline tests.

- sleep_fn:

  Delay function, receiving seconds. Intended for offline tests.

## Value

Invisibly, a tibble with `iri`, `status`, `final_url`, `error`, and
`attempts`, one row for each unique exact HTTP semantic IRI. On failure,
the complete CSV is written before an aggregate error is raised.

## Details

The report is written even if verification fails. Its stable row order
and bytes allow a publication workflow to checksum the file. A
successful dereference proves HTTP resolution only, not that an ontology
term is an appropriate semantic choice.

## Examples

``` r
if (FALSE) { # \dontrun{
# This makes live HTTP requests to every selected semantic IRI.
verify_sdp_semantic_iris("path/to/package")
} # }
```
