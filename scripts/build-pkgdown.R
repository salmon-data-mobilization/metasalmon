#!/usr/bin/env Rscript

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

pkgdown::build_site(
  new_process = FALSE,
  install = TRUE,
  lazy = FALSE
)

# pkgdown renders every root Markdown file. Contributor-only guidance must not
# become public pages or remain in the generated search and sitemap indexes.
internal_pages <- file.path(
  "docs",
  paste0(
    rep(c("AGENTS", "CLAUDE"), each = 2L),
    rep(c(".html", ".md"), times = 2L)
  )
)
unlink(internal_pages)

pkgdown::build_search()
getFromNamespace("build_sitemap", "pkgdown")(".")

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
  "AGENTS.html",
  "CLAUDE.html",
  "https://dfo-pacific-science.github.io/metasalmon/"
)) {
  if (any(vapply(text_paths, contains_text, logical(1), pattern = pattern))) {
    stop(
      sprintf("Generated pkgdown output still contains forbidden text: %s", pattern),
      call. = FALSE
    )
  }
}
