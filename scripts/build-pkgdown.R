#!/usr/bin/env Rscript
#
# Build the pkgdown site into docs/, which is committed and published as the
# package website (the `url` in _pkgdown.yml).
#
# Usage: Rscript scripts/build-pkgdown.R [--news-only | --accept-toolchain-change]
#        Rscript scripts/build-pkgdown.R [--article=NAME] [--reference=TOPIC]
# Use --news-only when only NEWS changed: build its pages and search index,
# retaining the same toolchain and publication checks as a full build.
# Article names are vignette stems; reference names are canonical Rd topic
# names. Both selectors may be repeated. Use a full build for site-wide changes
# such as a new page, navigation, or a changed toolchain.
#
# It does two things that `pkgdown::build_site()` alone does not (hub item
# B-141).
#
# 1. It keeps contributor-only Markdown off the public site. pkgdown renders
#    every Markdown file at the repository root and under .github/ as a page,
#    apart from the few it handles itself (README, NEWS, LICENSE) and a short
#    skip list. That list matches file names case-sensitively, so it skips
#    pull_request_template.md and renders .github/PULL_REQUEST_TEMPLATE.md.
#    pkgdown has no setting that skips a file, so the pages rendered from
#    `internal_sources` are deleted after the build, the search index and the
#    sitemap are rebuilt without them, and the run fails if any generated file
#    still names one. Their .html pages are also in .gitignore, for a build run
#    without this script.
#
#    The list is the part that decays. It named only AGENTS.md and CLAUDE.md
#    while HUB.md and the pull-request template were published beside them. So
#    before anything is built, every file pkgdown would render this way has to
#    be in `internal_sources` or in `public_sources`, and a file in neither
#    stops the run. Whether a new root Markdown file is public is then decided
#    the first time the site is built with it, not noticed on the site later.
#
#    Retires when: pkgdown can be told not to render a given root Markdown
#    file, or none of these files lives where pkgdown looks for them.
#
# 2. It will not rewrite the whole site by accident. pkgdown records the
#    toolchain that built the site in docs/pkgdown.yml, and a different pkgdown
#    or pandoc changes the markup of every page, not only of the pages whose
#    sources changed; B-141 records a run that did exactly that. So a run whose
#    pkgdown or pandoc differs from that record stops before building and says
#    which differ. Build under the recorded toolchain to change only what your
#    sources changed. Pass --accept-toolchain-change to rebuild the whole site
#    under this one instead, and commit that rebuild as a change of its own,
#    because it rewrites every public page.
#
#    What it does not see: the record holds pkgdown's version, its GitHub SHA
#    and pandoc's version, and nothing else. bslib, downlit and R can also
#    change every page and are not recorded, so a run that passes this check
#    can still rewrite pages whose sources did not change. `git status docs`
#    after a run is the measurement.
#
#    Retires when: docs/ stops being committed from a local build, for example
#    because CI builds and deploys the site from a pinned toolchain.

args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args, value = TRUE)
script_path <- if (length(file_arg) > 0L) {
  normalizePath(
    sub("^--file=", "", file_arg[[1L]]),
    winslash = "/",
    mustWork = TRUE
  )
} else {
  normalizePath(
    file.path("scripts", "build-pkgdown.R"),
    winslash = "/",
    mustWork = TRUE
  )
}
repo_root <- normalizePath(
  file.path(dirname(script_path), ".."),
  winslash = "/",
  mustWork = TRUE
)
setwd(repo_root)

options_given <- commandArgs(trailingOnly = TRUE)
article_options <- grep("^--article=", options_given, value = TRUE)
reference_options <- grep("^--reference=", options_given, value = TRUE)
unknown_options <- options_given[!
  options_given %in% c(
    "--accept-toolchain-change", "--news-only", article_options,
    reference_options
  )
]
if (length(unknown_options) > 0L) {
  stop(
    sprintf(
      paste0(
        "Unknown argument: %s\nUsage: Rscript scripts/build-pkgdown.R ",
        "[--news-only | --accept-toolchain-change | ",
        "--article=NAME ... --reference=TOPIC ...]"
      ),
      paste(unknown_options, collapse = " ")
    ),
    call. = FALSE
  )
}
article_targets <- unique(sub("^--article=", "", article_options))
reference_targets <- unique(sub("^--reference=", "", reference_options))
selected_build <- length(article_options) > 0L || length(reference_options) > 0L
if (any(!nzchar(article_targets)) || any(!nzchar(reference_targets))) {
  stop("Article and reference selectors must name an existing topic.", call. = FALSE)
}
accept_toolchain_change <- "--accept-toolchain-change" %in% options_given
news_only <- "--news-only" %in% options_given
if (news_only && accept_toolchain_change) {
  stop("A toolchain change requires a full build; do not combine --news-only with --accept-toolchain-change.", call. = FALSE)
}
if (selected_build && (news_only || accept_toolchain_change)) {
  stop(
    "A selected build cannot be combined with --news-only or --accept-toolchain-change; use a full build for a toolchain change.",
    call. = FALSE
  )
}

if (selected_build) {
  if (!file.exists(file.path("docs", "index.html"))) {
    stop(
      "Selected builds require an existing checked-in site; use a full build.",
      call. = FALSE
    )
  }
  # pkgdown::build_reference(topics=) silently filters names it does not know.
  # Resolve both selectors before any page is written, including when a caller
  # supplies one valid name beside an invalid one.
  selected_pkg <- pkgdown::as_pkgdown(".")
  missing_articles <- setdiff(article_targets, selected_pkg$vignettes$name)
  missing_reference <- setdiff(reference_targets, selected_pkg$topics$name)
  if (length(missing_articles) > 0L || length(missing_reference) > 0L) {
    stop(
      "Unknown selected article or reference topic: ",
      paste(c(missing_articles, missing_reference), collapse = ", "),
      call. = FALSE
    )
  }
  # Narrow mode updates existing pages. Adding pages or changing navigation
  # needs a full build, because other site sections can then depend on it.
  selected_html <- c(
    selected_pkg$vignettes$file_out[
      match(article_targets, selected_pkg$vignettes$name)
    ],
    file.path("reference", selected_pkg$topics$file_out[
      match(reference_targets, selected_pkg$topics$name)
    ])
  )
  if (any(!grepl("\\.html$", selected_html))) {
    stop(
      "Selected pages must produce HTML; use a full build for other formats.",
      call. = FALSE
    )
  }
  absent_outputs <- selected_html[!file.exists(file.path("docs", selected_html))]
  if (length(absent_outputs) > 0L) {
    stop(
      "Selected pages have no checked-in HTML; use a full build: ",
      paste(absent_outputs, collapse = ", "),
      call. = FALSE
    )
  }
}

# Root and .github/ Markdown files that pkgdown renders as pages. Each one must
# be in one of these two vectors; see (1) above.
internal_sources <- c(
  "AGENTS.md",
  "CLAUDE.md",
  "HUB.md",
  "REVIEW.md",
  ".github/PULL_REQUEST_TEMPLATE.md"
)
public_sources <- character()

rendered_sources <- sub(
  "^\\./",
  "",
  as.character(getFromNamespace("package_mds", "pkgdown")("."))
)
unlisted_sources <- setdiff(
  rendered_sources,
  c(internal_sources, public_sources)
)
if (length(unlisted_sources) > 0L) {
  stop(
    "pkgdown would publish each of these Markdown files as a page of the ",
    "public site, and this script does not say whether they belong there: ",
    paste(unlisted_sources, collapse = ", "), ". Add each one to ",
    "`internal_sources` in scripts/build-pkgdown.R (and its page to ",
    ".gitignore beside docs/AGENTS.html), or to `public_sources`. Nothing was ",
    "built.",
    call. = FALSE
  )
}

# The running toolchain is read with the same expressions pkgdown uses to write
# docs/pkgdown.yml, so the record and this run are compared in one rendering.
toolchain_value <- function(x) {
  x <- as.character(x)
  if (length(x) == 0L || is.na(x[[1L]]) || !nzchar(x[[1L]])) {
    return("none")
  }
  x[[1L]]
}
site_record_path <- file.path("docs", "pkgdown.yml")
site_record <- if (file.exists(site_record_path)) {
  yaml::read_yaml(site_record_path)
} else {
  list()
}
recorded_toolchain <- c(
  pkgdown = toolchain_value(site_record[["pkgdown"]]),
  `pkgdown GitHub SHA` = toolchain_value(site_record[["pkgdown_sha"]]),
  pandoc = toolchain_value(site_record[["pandoc"]])
)
running_toolchain <- c(
  pkgdown = toolchain_value(
    utils::packageDescription("pkgdown", fields = "Version")
  ),
  `pkgdown GitHub SHA` = toolchain_value(
    utils::packageDescription("pkgdown")[["GithubSHA1"]]
  ),
  pandoc = toolchain_value(rmarkdown::pandoc_version())
)
toolchain_differs <- names(recorded_toolchain)[
  recorded_toolchain != running_toolchain
]
if (length(toolchain_differs) > 0L) {
  toolchain_differences <- sprintf(
    "  %s: %s records %s, this run has %s",
    toolchain_differs,
    site_record_path,
    recorded_toolchain[toolchain_differs],
    running_toolchain[toolchain_differs]
  )
  if (!accept_toolchain_change) {
    stop(
      paste(
        c(
          "The checked-in site was built with a different toolchain from this run's:",
          toolchain_differences,
          paste(
            "A different pkgdown or pandoc rewrites every page of the public",
            "site, not only the pages whose sources changed, so nothing was",
            "built. Build under the recorded toolchain, or pass",
            "--accept-toolchain-change to rebuild the whole site under this",
            "one and commit that rebuild as a change of its own."
          )
        ),
        collapse = "\n"
      ),
      call. = FALSE
    )
  }
  message(
    paste(
      c(
        paste(
          "Rebuilding the whole site under a toolchain the checked-in site",
          "was not built with (--accept-toolchain-change):"
        ),
        toolchain_differences,
        "Every page will be rewritten. Commit the rebuild as a change of its own."
      ),
      collapse = "\n"
    )
  )
} else {
  message(
    sprintf(
      "Toolchain matches %s: pkgdown %s, pandoc %s.",
      site_record_path,
      running_toolchain[["pkgdown"]],
      running_toolchain[["pandoc"]]
    )
  )
}

if (news_only) {
  pkgdown::build_news()
  # build_site() normally makes the Markdown companion later, for every page.
  # Use that same converter for NEWS alone so its two public formats agree.
  pkg <- getFromNamespace("as_pkgdown", "pkgdown")(".")
  if (!isFALSE(pkg$meta$`llm-docs`)) {
    news_paths <- getFromNamespace("get_site_paths", "pkgdown")(pkg)
    news_paths <- news_paths[grepl("^news/.*\\.html$", news_paths)]
    for (path in news_paths) {
      getFromNamespace("convert_md", "pkgdown")(
        file.path(pkg$dst_path, path),
        file.path(pkg$dst_path, sub("\\.html$", ".md", path)),
        getFromNamespace("full_url", "pkgdown")(pkg, path)
      )
    }
  }
} else if (selected_build) {
  # Match build_site(install=TRUE, devel=FALSE) so article chunks and reference
  # examples read this source revision, not a different installed release.
  withr::local_temp_libpaths()
  withr::with_options(
    list(keep.source.pkgs = TRUE, keep.parse.data.pkgs = TRUE),
    utils::install.packages(".", repos = NULL, type = "source", quiet = TRUE)
  )

  index_paths <- c(
    if (length(article_targets) > 0L) "articles/index.html",
    if (length(reference_targets) > 0L) "reference/index.html"
  )
  page_bytes <- function(path) {
    if (!file.exists(path)) return(NULL)
    readBin(path, what = "raw", n = file.info(path)$size)
  }
  index_before <- lapply(file.path("docs", index_paths), page_bytes)

  if (length(article_targets) > 0L) {
    pkgdown::build_articles_index()
    for (name in article_targets) {
      pkgdown::build_article(name, lazy = FALSE, new_process = FALSE)
    }
  }
  if (length(reference_targets) > 0L) {
    pkgdown::build_reference(
      topics = reference_targets, lazy = FALSE, devel = FALSE
    )
  }

  index_changed <- vapply(seq_along(index_paths), function(i) {
    !identical(
      index_before[[i]], page_bytes(file.path("docs", index_paths[[i]]))
    )
  }, logical(1))

  # build_site() converts every HTML page to Markdown for llms.txt. A selected
  # build converts only the requested pages and any index whose HTML changed.
  # Converting all pages here would recreate the unrelated-output churn this
  # mode exists to avoid.
  if (!isFALSE(selected_pkg$meta$`llm-docs`)) {
    markdown_sources <- c(selected_html, index_paths[index_changed])
    for (path in markdown_sources) {
      getFromNamespace("convert_md", "pkgdown")(
        file.path(selected_pkg$dst_path, path),
        file.path(selected_pkg$dst_path, sub("\\.html$", ".md", path)),
        getFromNamespace("full_url", "pkgdown")(selected_pkg, path)
      )
    }
    if (any(index_changed)) {
      # Use the same three-file composition and UTF-8 helpers as pkgdown's
      # build_llm_docs(), without converting every unrelated HTML page.
      read_lines <- getFromNamespace("read_lines", "pkgdown")
      read_optional <- getFromNamespace("read_file_if_exists", "pkgdown")
      getFromNamespace("write_lines", "pkgdown")(
        c(
          read_lines(file.path(selected_pkg$dst_path, "index.md")), "",
          read_optional(file.path(selected_pkg$dst_path, "reference/index.md")), "",
          read_optional(file.path(selected_pkg$dst_path, "articles/index.md"))
        ),
        file.path(selected_pkg$dst_path, "llms.txt")
      )
    }
  }
  # The full site path checks images on the home page after rendering. Reuse
  # that read-only check while updating a section of an existing site.
  getFromNamespace("check_built_site", "pkgdown")(selected_pkg)
} else {
  pkgdown::build_site(
    new_process = FALSE,
    install = TRUE,
    lazy = FALSE
  )
}

# pkgdown writes each page as .html and, for its llms.txt support, as .md.
# Neither may stay public or in the search and sitemap indexes rebuilt below.
internal_names <- tools::file_path_sans_ext(basename(internal_sources))
internal_pages <- file.path(
  "docs",
  paste0(rep(internal_names, each = 2L), c(".html", ".md"))
)
unlink(internal_pages)

pkgdown::build_search()
getFromNamespace("build_sitemap", "pkgdown")(".")

markdown_paths <- list.files(
  if (news_only) "docs/news" else "docs",
  pattern = "\\.md$",
  recursive = TRUE,
  full.names = TRUE
)
if (selected_build) {
  # Full builds normalize all Markdown; selected builds must not rewrite pages
  # outside their requested outputs just because they were built previously.
  if (isFALSE(selected_pkg$meta$`llm-docs`)) {
    markdown_paths <- character()
  } else {
    markdown_paths <- file.path(
      selected_pkg$dst_path,
      sub("\\.html$", ".md", c(selected_html, index_paths[index_changed]))
    )
    markdown_paths <- markdown_paths[file.exists(markdown_paths)]
  }
}
for (path in markdown_paths) {
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  normalized <- sub("[ \t]+$", "", lines)
  if (!identical(lines, normalized)) {
    writeLines(normalized, path, useBytes = TRUE)
  }
}

text_paths <- list.files(
  "docs",
  pattern = "\\.(html|md|json|xml|txt)$",
  recursive = TRUE,
  full.names = TRUE
)
contains_text <- function(path, pattern) {
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  any(grepl(pattern, lines, fixed = TRUE))
}

for (pattern in c(
  paste0(internal_names, ".html"),
  "https://dfo-pacific-science.github.io/metasalmon/"
)) {
  if (any(vapply(text_paths, contains_text, logical(1), pattern = pattern))) {
    stop(
      sprintf("Generated pkgdown output still contains forbidden text: %s", pattern),
      call. = FALSE
    )
  }
}
