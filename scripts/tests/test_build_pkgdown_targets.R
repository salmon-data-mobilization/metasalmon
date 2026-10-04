#!/usr/bin/env Rscript

# Run against a disposable package and site. The one initial full build gives
# the selected builds real pkgdown HTML, Markdown, search and sitemap inputs.
test_path <- sub(
  "^--file=", "",
  grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)[[1L]]
)
source_root <- normalizePath(file.path(dirname(test_path), "../.."))
pandoc_dir <- Sys.getenv("B430_PANDOC_DIR")
if (nzchar(pandoc_dir)) {
  if (!file.exists(file.path(pandoc_dir, "pandoc"))) {
    stop("B430_PANDOC_DIR does not contain pandoc.")
  }
  Sys.setenv(
    PATH = paste(pandoc_dir, Sys.getenv("PATH"), sep = .Platform$path.sep),
    RSTUDIO_PANDOC = pandoc_dir
  )
}
if (!rmarkdown::pandoc_available()) stop("Pandoc is required for this test.")
cat("pkgdown", as.character(utils::packageVersion("pkgdown")),
    "Pandoc", as.character(rmarkdown::pandoc_version()), "\n")

check <- function(ok, label) {
  if (!isTRUE(ok)) stop(label, call. = FALSE)
  cat("PASS:", label, "\n")
}

write_file <- function(root, path, lines) {
  destination <- file.path(root, path)
  dir.create(dirname(destination), recursive = TRUE, showWarnings = FALSE)
  writeLines(lines, destination, useBytes = TRUE)
}

site_snapshot <- function(root) {
  docs <- file.path(root, "docs")
  paths <- sort(list.files(
    docs, recursive = TRUE, all.files = TRUE, include.dirs = FALSE
  ), method = "radix")
  full_paths <- file.path(docs, paths)
  stats <- file.info(full_paths)
  data.frame(
    path = paths,
    md5 = unname(tools::md5sum(full_paths)),
    modified = as.numeric(stats$mtime),
    stringsAsFactors = FALSE
  )
}

same_snapshot <- function(before, after, except = character()) {
  before <- before[!before$path %in% except, , drop = FALSE]
  after <- after[!after$path %in% except, , drop = FALSE]
  identical(before, after)
}

run_builder <- function(root, arguments, expected_status = 0L) {
  output <- suppressWarnings(system2(
    file.path(R.home("bin"), "Rscript"),
    c(shQuote(file.path(root, "scripts/build-pkgdown.R")), shQuote(arguments)),
    stdout = TRUE,
    stderr = TRUE
  ))
  status <- attr(output, "status")
  if (is.null(status)) status <- 0L
  if (!identical(as.integer(status), expected_status)) {
    stop(
      sprintf("builder exited %s, expected %s:\n%s", status, expected_status,
              paste(output, collapse = "\n")),
      call. = FALSE
    )
  }
  output
}

search_has <- function(root, suffix, token) {
  records <- jsonlite::fromJSON(
    file.path(root, "docs/search.json"), simplifyVector = FALSE
  )
  matches <- Filter(
    function(record) endsWith(record$path, suffix),
    records
  )
  length(matches) > 0L && any(vapply(
    matches,
    function(record) grepl(token, paste(unlist(record), collapse = " "), fixed = TRUE),
    logical(1)
  ))
}

run_test <- function() {
  root <- tempfile("b430-pkgdown-")
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)

  write_file(root, "DESCRIPTION", c(
    "Package: sitefixture",
    "Title: Disposable Pkgdown Target Fixture",
    "Version: 0.0.1",
    "Authors@R: person('Site', 'Fixture', email = 'site@example.org', role = c('aut', 'cre'))",
    "Description: A small package for selected site build controls.",
    "URL: https://example.org/sitefixture/",
    "License: MIT",
    "Encoding: UTF-8",
    "Suggests: knitr, rmarkdown",
    "VignetteBuilder: knitr"
  ))
  write_file(root, "NAMESPACE", c(
    "export(example_topic)", "export(other_topic)"
  ))
  write_file(root, "R/topics.R", c(
    "example_topic <- function() 'example'",
    "other_topic <- function() 'other'"
  ))
  for (name in c("example_topic", "other_topic")) {
    write_file(root, file.path("man", paste0(name, ".Rd")), c(
      sprintf("\\name{%s}", name),
      sprintf("\\alias{%s}", name),
      sprintf("\\title{%s}", name),
      "\\description{Baseline reference description.}",
      sprintf("\\usage{%s()}", name),
      "\\value{A character scalar.}"
    ))
  }
  for (name in c("one", "two")) {
    write_file(root, file.path("vignettes", paste0(name, ".Rmd")), c(
      "---",
      sprintf("title: '%s'", name),
      "output: rmarkdown::html_vignette",
      "vignette: >",
      sprintf("  %%\\VignetteIndexEntry{%s}", name),
      "  %\\VignetteEngine{knitr::rmarkdown}",
      "  %\\VignetteEncoding{UTF-8}",
      "---",
      "Baseline article text."
    ))
  }
  write_file(root, "README.md", "# sitefixture")
  write_file(root, "NEWS.md", "# sitefixture (development version)")
  write_file(root, "_pkgdown.yml", c(
    "url: https://example.org/sitefixture/",
    "template:",
    "  bootstrap: 5",
    "reference:",
    "  - contents: [example_topic, other_topic]",
    "articles:",
    "  - title: Guides",
    "    contents: [one, two]"
  ))
  dir.create(file.path(root, "scripts"))
  file.copy(file.path(source_root, "scripts/build-pkgdown.R"),
            file.path(root, "scripts/build-pkgdown.R"))

  pkgdown::build_site(
    pkg = root, new_process = FALSE, install = TRUE, lazy = FALSE,
    quiet = TRUE
  )
  baseline <- site_snapshot(root)
  check(all(c("articles/one.html", "articles/one.md", "articles/two.html",
              "reference/example_topic.html", "reference/example_topic.md",
              "reference/other_topic.html", "search.json", "sitemap.xml") %in%
              baseline$path), "fixture has selected and unrelated site outputs")

  # Existing script rejects the selector: this is the tests-only RED checkpoint.
  write_file(root, "vignettes/one.Rmd", c(
    readLines(file.path(root, "vignettes/one.Rmd"), warn = FALSE),
    "B430_ARTICLE_CHANGED"
  ))
  write_file(root, "man/example_topic.Rd", c(
    readLines(file.path(root, "man/example_topic.Rd"), warn = FALSE),
    "% B430_REFERENCE_CHANGED",
    "\\details{B430_REFERENCE_CHANGED}"
  ))
  run_builder(root, c("--article=one", "--article=one",
                      "--reference=example_topic"))
  selected <- site_snapshot(root)
  for (path in c("articles/one.html", "articles/one.md")) {
    check(any(grepl("B430_ARTICLE_CHANGED", readLines(file.path(root, "docs", path)),
                    fixed = TRUE)), paste("selected article content", path))
  }
  for (path in c("reference/example_topic.html", "reference/example_topic.md")) {
    check(any(grepl("B430_REFERENCE_CHANGED", readLines(file.path(root, "docs", path)),
                    fixed = TRUE)), paste("selected reference content", path))
  }
  check(search_has(root, "/articles/one.html", "B430_ARTICLE_CHANGED") &&
          search_has(root, "/reference/example_topic.html", "B430_REFERENCE_CHANGED"),
        "search contains both changed selected pages")
  check(any(grepl("/articles/one.html", readLines(file.path(root, "docs/sitemap.xml")),
                  fixed = TRUE)) &&
          any(grepl("/reference/example_topic.html", readLines(file.path(root, "docs/sitemap.xml")),
                    fixed = TRUE)), "sitemap retains selected URLs")
  check(same_snapshot(
    baseline, selected,
    except = c("articles/one.html", "articles/one.md",
               "reference/example_topic.html", "reference/example_topic.md",
               "search.json")
  ), "all unrelated site outputs remain byte-identical")

  # Rejection must occur before any output changes, including mtimes.
  for (arguments in list(
    "--article=", "--reference=", "--article=missing",
    "--reference=missing", "--article=../one",
    c("--article=one", "--news-only"),
    c("--reference=example_topic", "--accept-toolchain-change")
  )) {
    before <- site_snapshot(root)
    output <- run_builder(root, arguments, expected_status = 1L)
    check(length(output) > 0L && same_snapshot(before, site_snapshot(root)),
          paste("invalid selector does not write", paste(arguments, collapse = " ")))
  }

  write_file(root, "unlisted.md", "# This page has no publication decision")
  before <- site_snapshot(root)
  output <- run_builder(root, "--article=one", expected_status = 1L)
  check(any(grepl("does not say whether they belong", output, fixed = TRUE)) &&
          same_snapshot(before, site_snapshot(root)),
        "root Markdown publication guard still fails before writing")
  unlink(file.path(root, "unlisted.md"))

  # A changed recorded toolchain is enough to test this without installing a
  # second Pandoc in CI. The rejection must not update the site or its record.
  toolchain_path <- file.path(root, "docs/pkgdown.yml")
  toolchain <- yaml::read_yaml(toolchain_path)
  toolchain$pandoc <- "not-the-running-pandoc"
  yaml::write_yaml(toolchain, toolchain_path)
  before <- site_snapshot(root)
  output <- run_builder(root, "--article=one", expected_status = 1L)
  check(any(grepl("different toolchain", output, fixed = TRUE)) &&
          same_snapshot(before, site_snapshot(root)),
        "changed toolchain fails before selected output is written")
}

run_test()
