#!/usr/bin/env Rscript

pkgdown::build_site(
  new_process = TRUE,
  install = TRUE,
  lazy = FALSE
)

non_public_pages <- file.path("docs", c("AGENTS.html", "CLAUDE.html"))
unlink(non_public_pages[file.exists(non_public_pages)])

build_sitemap <- getFromNamespace("build_sitemap", "pkgdown")
build_sitemap(".")
