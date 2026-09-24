#!/usr/bin/env Rscript
#
# Fail when an exported topic is missing from _pkgdown.yml's reference index.
#
# Why this exists (hub item B-213). `write_sdp_semantic_closure()` was
# exported, documented for users, and merged on 2026-09-16 without an entry in
# the reference index. pkgdown refuses to build a site whose index leaves out a
# public topic, so the next site build aborted. No CI job built or checked the
# site, and a person running the build by hand a week later was the first to
# notice. The next export would have gone the same way.
#
# What it checks:
#
#   1. Every name NAMESPACE exports is an alias of some topic under man/. An
#      export with no topic has no page for the index to list.
#   2. `pkgdown::check_pkgdown()` passes when every topic that documents an
#      export is treated as public, whatever `@keywords internal` says. This is
#      pkgdown's own check, so it resolves the index exactly as a site build
#      would, including selectors such as `starts_with()`. Its other parts (the
#      site URL, the articles index) run too. It builds no page, but pkgdown
#      renders the index descriptions with pandoc, so pandoc must be installed.
#
# Why (2) is stricter than `check_pkgdown()` on its own. pkgdown asks for an
# index entry only for topics not marked `@keywords internal`, and its own error
# message offers that keyword as a fix. For an exported function that fix is
# wrong: it hides a function users are meant to find from the reference index.
# So here an exported topic cannot be keyworded out of the index. A topic that
# documents nothing exported is left to pkgdown's own rule.
#
# What it does not check. A guard that claims more than it checks is worse than
# none, so the limits are stated here. It does not check whether an entry sits
# in the right section; that is a judgement for review. It does not catch
# anything only a full site build finds, such as a failing example or a link
# that does not resolve. That is B-141's build. And it reads man/ as committed,
# so an export whose Rd was not regenerated is checked against the stale Rd;
# R CMD check is what notices that.
#
# Exit status: 0 when every exported topic is in the index and pkgdown finds
# nothing else; 1 on any finding; 2 when the check cannot run at all. A check
# that could not look must never report that it looked and found nothing.
#
# Usage: Rscript scripts/check-pkgdown-index.R [PACKAGE_ROOT]
# PACKAGE_ROOT defaults to the repository this script lives in.
#
# Retires when: some job that runs on every pull request already fails when an
# exported topic is missing from the index, whatever its keywords. A full site
# build would do that if pkgdown stopped exempting internal topics that document
# an export. As long as pkgdown exempts them, a site build alone does not retire
# this check.

EXIT_FINDING <- 1L
EXIT_CANNOT_RUN <- 2L

cannot_run <- function(...) {
  message("check-pkgdown-index: cannot run: ", ...)
  quit(save = "no", status = EXIT_CANNOT_RUN)
}

default_root <- function() {
  file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  if (length(file_arg) == 0L) {
    return(".")
  }
  file.path(dirname(sub("^--file=", "", file_arg[[1L]])), "..")
}

args <- commandArgs(trailingOnly = TRUE)
root <- if (length(args) >= 1L) args[[1L]] else default_root()
if (!dir.exists(root)) {
  cannot_run("no directory at ", root, ".")
}
root <- normalizePath(root, winslash = "/", mustWork = TRUE)

if (!requireNamespace("pkgdown", quietly = TRUE)) {
  cannot_run("pkgdown is not installed.")
}
# pkgdown renders the Markdown descriptions in _pkgdown.yml's indexes with
# pandoc, even when it builds no page. Without pandoc the check stops there,
# having said nothing about the index.
if (!requireNamespace("rmarkdown", quietly = TRUE) || !rmarkdown::pandoc_available()) {
  cannot_run("pandoc is not available, and pkgdown needs it to read the index.")
}

# 1. What the package exports ------------------------------------------------

if (!file.exists(file.path(root, "NAMESPACE"))) {
  cannot_run("no NAMESPACE in ", root, ".")
}
ns <- tryCatch(
  parseNamespaceFile(basename(root), dirname(root)),
  error = function(e) cannot_run("NAMESPACE does not parse: ", conditionMessage(e))
)
if (length(ns$exportPatterns) > 0L) {
  cannot_run(
    "NAMESPACE uses exportPattern(). Resolving a pattern needs the package ",
    "loaded, and this check only reads files."
  )
}
exports <- unique(ns$exports)
if (length(exports) == 0L) {
  cannot_run("NAMESPACE exports nothing, so a pass would have checked nothing.")
}

# 2. Which topics document those exports --------------------------------------

pkg <- tryCatch(pkgdown::as_pkgdown(root), error = function(e) e)
if (inherits(pkg, "error")) {
  message("check-pkgdown-index: pkgdown cannot read the package:")
  message(conditionMessage(pkg))
  quit(save = "no", status = EXIT_FINDING)
}
topics <- pkg$topics
if (!is.data.frame(topics) || !all(c("name", "alias", "internal") %in% names(topics))) {
  cannot_run(
    "pkgdown ", as.character(utils::packageVersion("pkgdown")), " no longer ",
    "describes topics with name, alias and internal columns, so this script ",
    "needs updating before it can say anything."
  )
}

undocumented <- setdiff(exports, unlist(topics$alias, use.names = FALSE))
documents_export <- vapply(
  topics$alias,
  function(aliases) any(aliases %in% exports),
  logical(1)
)
keyworded_out <- topics$name[documents_export & topics$internal]
pkg$topics$internal[documents_export] <- FALSE

# 3. pkgdown's own check, with those topics public -----------------------------

pkgdown_error <- tryCatch(
  {
    pkgdown::check_pkgdown(pkg)
    NULL
  },
  error = function(e) e
)

if (length(undocumented) > 0L) {
  message(
    "check-pkgdown-index: exported, but no topic under man/ documents it: ",
    paste(undocumented, collapse = ", "), "."
  )
}
if (!is.null(pkgdown_error)) {
  message("check-pkgdown-index: pkgdown::check_pkgdown() failed:")
  message(conditionMessage(pkgdown_error))
  message(
    "\nIf pkgdown reports a topic missing from the index: an exported topic ",
    "needs an entry in the `reference:` section of _pkgdown.yml, beside the ",
    "functions it works with. `@keywords internal` does not satisfy this check ",
    "for a topic that documents an export, whatever pkgdown's message above ",
    "suggests (hub item B-213). If the function should not be public, stop ",
    "exporting it instead."
  )
  if (length(keyworded_out) > 0L) {
    message(
      "Treated as public here, though marked `@keywords internal`: ",
      paste(keyworded_out, collapse = ", "), "."
    )
  }
}
if (length(undocumented) > 0L || !is.null(pkgdown_error)) {
  quit(save = "no", status = EXIT_FINDING)
}

cat(sprintf(
  "check-pkgdown-index: ok. %d exports, documented by %d topics, all in the reference index (pkgdown %s).\n",
  length(exports),
  sum(documents_export),
  as.character(utils::packageVersion("pkgdown"))
))
