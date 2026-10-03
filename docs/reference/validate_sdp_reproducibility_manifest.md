# Validate an SDP reproducibility manifest

Validate an SDP reproducibility manifest

## Usage

``` r
validate_sdp_reproducibility_manifest(path)
```

## Arguments

- path:

  Existing Salmon Data Package directory.

## Value

`TRUE`, invisibly, when validation succeeds; otherwise an error.

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
