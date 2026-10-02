# Read an SDP reproducibility manifest

Read an SDP reproducibility manifest

## Usage

``` r
read_sdp_reproducibility_manifest(path, validate = TRUE)
```

## Arguments

- path:

  Existing Salmon Data Package directory.

- validate:

  Logical; validate paths, roles, checksums, sizes, symlinks,
  provenance, deterministic ordering, and exact directory closure.

## Value

The parsed manifest as a list.

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
manifest <- read_sdp_reproducibility_manifest(sdp_path)
manifest$artifacts[[1]]$role
#> [1] "workflow"
unlink(sdp_path, recursive = TRUE)
```
