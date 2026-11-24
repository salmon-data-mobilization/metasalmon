# Write a closed reproducibility manifest into a Salmon Data Package

Binds an explicit inventory of reviewed semantic selections, workflow
records, provenance, and source records to exact paths, media types,
byte sizes, and SHA-256 hashes in `reproducibility/manifest.json`. The
writer does not discover files. Validation requires the declarations to
be closed over the actual reproducibility tree, which prevents
accidental publication of local notes or editor backups.

## Usage

``` r
write_sdp_reproducibility_manifest(path, artifacts, overwrite = FALSE)
```

## Arguments

- path:

  Existing Salmon Data Package directory.

- artifacts:

  Non-empty data frame with exactly `path`, `role`, and `media_type`
  columns. Paths are package-relative. Roles are
  `reviewed_semantic_selections`, `workflow`, `provenance`, or `source`
  and must agree with the canonical directory layout.

- overwrite:

  Logical; replace an existing managed manifest when `TRUE`.

## Value

The manifest path, invisibly.

## Examples

``` r
sdp_path <- tempfile("sdp-")
dir.create(file.path(sdp_path, "reproducibility", "workflow"),
           recursive = TRUE)
writeLines("message('prepare data')",
           file.path(sdp_path, "reproducibility", "workflow", "prepare.R"))
artifacts <- data.frame(
  path = "reproducibility/workflow/prepare.R",
  role = "workflow",
  media_type = "text/x-r-source"
)
write_sdp_reproducibility_manifest(sdp_path, artifacts)
validate_sdp_reproducibility_manifest(sdp_path)
unlink(sdp_path, recursive = TRUE)
```
