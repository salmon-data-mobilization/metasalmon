# Check whether a newer metasalmon release is available

Compares the installed package version with the latest GitHub release
for `salmon-data-mobilization/metasalmon`.

## Usage

``` r
check_for_updates(
  repo = "salmon-data-mobilization/metasalmon",
  current = utils::packageVersion("metasalmon"),
  timeout = 2,
  quiet = FALSE
)
```

## Arguments

- repo:

  GitHub repository in `"owner/name"` form. Defaults to the canonical
  `metasalmon` repository.

- current:

  Installed version to compare. Defaults to
  `utils::packageVersion("metasalmon")`.

- timeout:

  Number of seconds to wait for GitHub before giving up. Defaults to
  `2`.

- quiet:

  Logical; if `TRUE`, suppresses cli messages and only returns the
  result object.

## Value

Invisibly returns a list with class `"metasalmon_update_check"`.
Elements include `status`, `current_version`, `latest_version`,
`update_available`, `repo`, `release_tag`, `release_url`,
`install_command`, and `message`.

## Details

This function performs a network request only when you call it.
`metasalmon` does not check for updates automatically when the package
is attached.
[`create_sdp()`](https://salmon-data-mobilization.github.io/metasalmon/reference/create_sdp.md)
can call it optionally when `check_updates = TRUE`.

## Examples

``` r
# \donttest{
# Queries the GitHub releases API and degrades quietly when unreachable.
check_for_updates()
#> ℹ Installed metasalmon "0.2.4" is newer than the latest GitHub release "0.1.8".
#> ℹ You're probably on an unreleased development build.
# }
```
