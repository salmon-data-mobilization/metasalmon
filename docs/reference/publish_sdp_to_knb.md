# Publish a reviewed Salmon Data Package to production KNB

Plans an immutable DataONE package containing exactly the data resources
named by `tables.csv`, the canonical SDP reconstruction artifacts, one
validated EML 2.2.0 metadata object, and a deterministic OAI-ORE
resource map. The default is a credential-free, network-free dry run.
Live publication requires a pre-existing exact dry-run manifest and an
explicitly supplied `confirm = TRUE` approving that plan. Redistribution
authority is recorded separately in the reviewed EML sidecar.

## Usage

``` r
publish_sdp_to_knb(
  path,
  eml_path = NULL,
  public = NULL,
  manifest_path = NULL,
  dry_run = TRUE,
  confirm = interactive()
)
```

## Arguments

- path:

  Directory containing the reviewed Salmon Data Package.

- eml_path:

  Validated EML output path. Defaults to `metadata/eml.xml` inside
  `path`; it is rebuilt deterministically before planning.

- public:

  Explicit logical access decision. `TRUE` requests anonymous read
  access for every DataONE object and explicitly requests three DataONE
  preservation replicas. `FALSE` creates a restricted KNB-only
  production deposit, explicitly disables peer replication, and requires
  authenticated exact-byte/SystemMetadata verification plus anonymous
  denial for every object and zero anonymous catalog matches. The
  replication policy is part of the exact reviewed manifest and is
  verified on remote readback. There is no implicit access default.

- manifest_path:

  Recovery manifest path inside `path`. Defaults to
  `publication/knb-manifest.json`.

- dry_run:

  Logical; when `TRUE` (the default), write only local plan artifacts
  and never construct a DataONE adapter or read credentials.

- confirm:

  Explicit approval of the pre-existing exact dry-run plan and live
  mutation. Its interactive default can never authorize a live call:
  live mode requires that the argument was supplied and is exactly
  `TRUE`.

## Value

Invisibly returns publication status, identifiers, normalized
manifest/resource-map paths, and the manifest.

## Details

DataONE credentials are read only inside the live adapter. Use a
short-lived DataONE JWT through the supported `dataone_token` runtime
option; credentials are never accepted as function arguments or written
to the manifest.

## Examples

``` r
if (FALSE) { # \dontrun{
publish_sdp_to_knb(
  "path/to/reviewed-sdp",
  public = TRUE,
  dry_run = TRUE
)
} # }
```
