# Setup and Credentials

Use this page once before the homepage quick example or the [5-Minute
Quickstart](https://salmon-data-mobilization.github.io/metasalmon/articles/metasalmon.html).

It covers three things:

1.  GitHub credentials so `remotes::install_github()` works reliably.
2.  Optional setup for having a model review the semantic shortlists in
    your own harness.
3.  Short-lived DataONE credentials for an explicit live KNB deposit.

## 1) GitHub setup for installs and updates

`metasalmon` is installed from GitHub. Public installs often work
without a token, but setting up a GitHub Personal Access Token (PAT) up
front avoids rate limits and awkward auth failures.

### Create a GitHub token

Create a PAT in GitHub:

- <https://github.com/settings/tokens>

For public package install/update, a read-only token is enough. If you
also plan to read private GitHub repositories later, make sure the token
can access those repositories too.

### Store it in `~/.Renviron`

``` r
file.edit("~/.Renviron")
```

Add:

``` r
GITHUB_PAT="paste token here"
```

Restart R after saving.

### Install `metasalmon`

``` r
install.packages("remotes")
remotes::install_github("salmon-data-mobilization/metasalmon")
```

### If you also need private GitHub CSV access later

The install token and the package’s private-repo CSV helpers are related
but not identical workflows.

When you later want to use
[`read_github_csv()`](https://salmon-data-mobilization.github.io/metasalmon/reference/read_github_csv.md)
against a private repository, run:

``` r
ms_setup_github(repo = "your-org/your-private-repo")
```

That verifies private GitHub access for the repository you actually
intend to read.

## 2) Optional: model review in your own harness

The base quick example and quickstart need no API key, and neither does
the package at any point: `metasalmon` makes no model call. When you
want a model to judge the ontology candidates the package found, the
judgement runs in your own harness (for example Claude Code or Codex),
against a review packet the package writes and reads back. That needs:

- the `sdp-semantic-review` skill from the public
  [smn-sci-plgn](https://github.com/salmon-data-mobilization/smn-sci-plgn)
  plugin (release v0.2.0 or later), installed in your harness as the
  plugin’s README describes, or a harness of your own that follows the
  packet’s instructions;
- nothing in R beyond `metasalmon` itself. HTML, DOCX, `.R`, `.Rmd` and
  `.qmd` context files need no extra package; for the packet to quote
  your PDF or Excel files, install the optional readers once:

``` r
install.packages(c("pdftools", "readxl"))
```

Any credential your harness uses for its model is the harness’s own
configuration, not something `metasalmon` reads. [Semantic Review in
Your
Harness](https://salmon-data-mobilization.github.io/metasalmon/articles/harness-semantic-review.html)
walks through the whole route.

## 3) Optional DataONE/KNB live-deposit credential

You do not need a DataONE credential to build EML or create a KNB
dry-run manifest. For a live deposit, sign in to DataONE with the same
ORCID recorded as the single EML metadata provider and obtain a
short-lived DataONE JWT.

Treat this token differently from an install PAT. Do not put it in
`.Renviron`, a script, a command argument, an EML sidecar, a publication
manifest, or a transformation record. Enter it only into the current R
process and clear it immediately afterward:

``` r
options(dataone_token = rstudioapi::askForPassword("Short-lived DataONE JWT"))
on.exit(options(dataone_token = NULL), add = TRUE)
```

The live KNB preflight verifies that DataONE reports the authenticated
subject as the metadata-provider ORCID. A matching string supplied
locally is not enough.

## 4) Next step

After this setup is done, go back to:

- [Homepage quick
  example](https://salmon-data-mobilization.github.io/metasalmon/)
- [5-Minute
  Quickstart](https://salmon-data-mobilization.github.io/metasalmon/articles/metasalmon.html)
- [Semantic Review in Your
  Harness](https://salmon-data-mobilization.github.io/metasalmon/articles/harness-semantic-review.html)

If you are continuing from a reviewed package later, use:

- [After Excel
  Review](https://salmon-data-mobilization.github.io/metasalmon/articles/post-review-package-publication.html)
