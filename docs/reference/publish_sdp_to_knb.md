# Publish a reviewed Salmon Data Package to production KNB

Plans an immutable DataONE package containing the original data
resources named by `tables.csv`, one validated EML 2.2.0 metadata
object, and a deterministic OAI-ORE resource map. The `expanded`
representation publishes each allowlisted canonical SDP artifact as a
named, EML-documented DataONE object and records its package-relative
path with PROV-O `atLocation`; it does not create a ZIP or duplicate the
source table. The compatibility `archive` representation publishes one
deterministic SDP ZIP. The default operation is a credential-free,
network-free dry run. Live publication requires a pre-existing exact
dry-run manifest and an explicitly supplied `confirm = TRUE` approving
that plan. Redistribution authority is recorded separately in the
reviewed EML sidecar.

## Usage

``` r
publish_sdp_to_knb(
  path,
  eml_path = NULL,
  public = NULL,
  manifest_path = NULL,
  dry_run = TRUE,
  confirm = interactive(),
  revision_manifest = NULL,
  representation = c("archive", "expanded")
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

- revision_manifest:

  Optional path to the verified manifest for the preceding KNB version.
  Supplying it plans an immutable DataONE revision: the reviewed sidecar
  must contain a new `publication.revision_key`, the metadata series
  stays stable, and the new EML/resource-map objects obsolete their
  predecessors. Access cannot change in the same operation.

- representation:

  Publication representation. `"expanded"` publishes the closed SDP
  artifact inventory as individually named objects whose relative paths
  can reconstruct the package. `"archive"` (the compatibility default)
  publishes one deterministic ZIP in addition to each source data
  object. Neither mode scans arbitrary package files.

## Value

Invisibly returns publication status, identifiers, normalized manifest
and resource-map paths, the optional SDP-archive path, the
representation, and the manifest.

## Details

DataONE credentials are read only inside the live adapter. Use a
short-lived DataONE JWT through the supported `dataone_token` runtime
option; credentials are never accepted as function arguments or written
to the manifest.

A live restricted deposit is the KNB review/staging mechanism; KNB does
not expose a separate server-side draft state. The persistent object
identifiers remain even while access is private. This function does not
call KNB's separate Publish action and never mints a DOI. If a reviewed
dataset should receive a DOI, request it for the science-metadata
version through KNB when making that version public. The DOI identifies
the metadata version, not each raw or supplementary object.

Revisions must be built in a fresh versioned SDP directory. Keep the
prior package and its verified manifest unchanged, write the corrected
SDP to a new directory with a new `publication.revision_key`, and choose
a new local manifest path there. If KNB's separate Publish action later
creates a DOI-bearing metadata version, that KNB-created version is not
automatically imported into a metasalmon manifest; do not plan another
metasalmon revision from the older pre-DOI manifest.

Publication currently materializes object bytes in memory for exact
hashing and readback. It is intended for modest tabular SDPs; large
packages should be tested in a dry run and may require a future
streaming adapter.

## Examples

``` r
if (FALSE) { # \dontrun{
publish_sdp_to_knb(
  "path/to/reviewed-sdp",
  public = FALSE,
  dry_run = TRUE
)
} # }
```
