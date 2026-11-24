# Fetch the Salmon Domain Ontology with caching

Downloads an ontology, by default the Salmon Domain Ontology (smn),
using HTTP content negotiation, and caches each response with its ETag /
Last-Modified validators when the server sends them, so that an
unchanged ontology is not downloaded again.

## Usage

``` r
fetch_salmon_ontology(
  url = "https://w3id.org/smn/",
  accept = "text/turtle, application/rdf+xml;q=0.8",
  cache_dir = file.path(tools::R_user_dir("metasalmon", which = "cache"), "ontology"),
  timeout_seconds = 30,
  fallback_urls = c("https://w3id.org/smn"),
  release = NULL,
  snapshot_dir = NULL
)
```

## Arguments

- url:

  Ontology URL. Default is the canonical SMN namespace root.

- accept:

  Accept header; defaults to turtle with RDF/XML fallback.

- cache_dir:

  Directory to store cached ontology and headers. Defaults to a
  persistent user cache path.

- timeout_seconds:

  Numeric timeout in seconds for each HTTP request. It bounds both the
  connection and the whole transfer.

- fallback_urls:

  URLs tried in order when `url` fails. The implicit SMN fallback is
  used only when `url` is the default; callers naming another ontology
  must explicitly supply its fallback URLs. `NULL` or
  [`character()`](https://rdrr.io/r/base/character.html) explicitly
  tries none.

- release:

  A release version of the ontology `url` names, such as `"0.0.3"`;
  `url` must then be the smn or gcdfo ontology IRI. The release is
  downloaded from its version IRI (`https://w3id.org/smn/0.0.3`), or
  from the snapshot directory on GitHub Pages when that fails, into
  `cache_dir/releases/<ontology>/<version>/` together with its
  `MANIFEST.sha256`, once: a release does not change, so later calls
  read that copy. A release that served no manifest when it was
  downloaded stays unverified in that cache; delete its directory to
  download it again. `fallback_urls` is not used.

- snapshot_dir:

  A local directory holding a release snapshot of the ontology `url`
  names, such as a checkout's `docs/releases/0.0.3/`. The file is read
  from it and nothing is downloaded. Give `release` or `snapshot_dir`,
  not both: this call does not parse the file, so it could not check
  that the directory holds that release.
  [`find_terms()`](https://salmon-data-mobilization.github.io/metasalmon/reference/find_terms.md)
  takes both and checks the snapshot's `owl:versionIRI`.

## Value

Path to the cached copy that the answering URL returned (character
string), which holds exactly the bytes that URL sent: it is not decoded,
re-encoded or given a final newline. If every URL fails to refresh, a
matching copy from an attempted URL and the requested `accept` is
returned with a warning, provided it is not known to be stale.
Unrelated, legacy, invalidated or mismatching copies are never used. A
replacement response or contradictory ETag invalidates the previous
representation, even when storing its replacement fails. The old body
stays on disk for inspection with a `.invalid` marker until a successful
replacement makes it reusable. Without an eligible matching copy the
call errors with the last failure.

With `release` or `snapshot_dir`, the path to the release file read. It
never falls back to the latest ontology: a release that cannot be read
or does not match its manifest is an error. Compute the file's SHA-256
to record exactly what was read;
[`find_terms()`](https://salmon-data-mobilization.github.io/metasalmon/reference/find_terms.md)
records it for you.

## Details

Each copy is cached under the URL that returned it and the `accept` it
was fetched under: its file name is the first 16 hexadecimal digits of
the SHA-256 of the URL, a newline and `accept` (as UTF-8), with the
extension `.ttl` whatever the representation, and its validators sit
beside it with the extensions `.etag` and `.last_modified`. Fetches of
different URLs or representations into one `cache_dir` therefore never
overwrite each other, a conditional request carries only the validators
that the URL it is sent to returned under the same `accept`, and a `304`
answer returns that URL's own copy. metasalmonpy names its cache files
the same way.

With `release` or `snapshot_dir`, it reads a pinned release of smn or
gcdfo instead: one file of that release's snapshot, the directory each
ontology publishes as `docs/releases/<version>/`, and nothing newer. The
file is the representation `accept` prefers among the three a snapshot
carries (`text/turtle` for `.ttl`, `application/rdf+xml` for `.owl`,
`application/ld+json` for `.jsonld`). When the snapshot carries a
`MANIFEST.sha256`, the file must be listed in it with the SHA-256 of its
bytes, or the call errors.
