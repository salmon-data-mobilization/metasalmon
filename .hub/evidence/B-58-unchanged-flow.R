# Run from this checkout: Rscript .hub/evidence/B-58-unchanged-flow.R [base-ref]
# Git-based review evidence, not an installed-package test. Normalize only
# added class arguments, two named legacy positional classes, and the two
# exact base-warning messages wrapped in warningCondition. Every other AST
# node must match the published base. The namespace guard separately checks
# that the class arguments themselves obey the severity/domain contract.
args <- commandArgs(trailingOnly = TRUE)
base_ref <- if (length(args)) args[[1L]] else "3364b975"
head_name <- function(node) paste(deparse(node), collapse = "")

normalize <- function(node, proposed = FALSE) {
  if (is.call(node) && proposed && head_name(node[[1L]]) == "warning" &&
      length(node) == 2L && is.call(node[[2L]]) &&
      head_name(node[[2L]][[1L]]) == "warningCondition") {
    inner <- node[[2L]]
    stopifnot(is.null(inner[["call"]]),
              identical(inner[["class"]][[2L]], "warning"),
              identical(inner[["class"]][[4L]], "simpleWarning"))
    message <- inner[[2L]]
    messages <- if (is.call(message) && head_name(message[[1L]]) == "paste0") {
      as.list(message)[-1L]
    } else list(message)
    node <- as.call(c(list(as.name("warning")), messages, list(call. = FALSE)))
  }
  if (is.call(node) || is.pairlist(node) || is.expression(node)) {
    parts <- as.list(node)
    if (is.call(node)) {
      if (proposed && "class" %in% names(parts)) {
        cls <- parts[["class"]]
        if (is.call(cls) && identical(cls[[1L]], as.name(".ms_condition_classes"))) {
          if (length(cls) >= 4L) parts[["class"]] <- cls[[4L]] else parts[["class"]] <- NULL
        }
      }
      if (!proposed && head_name(node[[1L]]) %in% c("cli::cli_abort", "cli_abort")) {
        named <- names(parts)
        if (is.null(named)) named <- rep("", length(parts))
        positions <- which(!nzchar(named[-1L])) + 1L
        if (length(positions) >= 2L && is.character(parts[[positions[[2L]]]])) {
          named[positions[[2L]]] <- "class"
          names(parts) <- named
        }
      }
    }
    index <- 0L
    for (part in parts) {
      index <- index + 1L
      if (!missing(part)) parts[index] <- list(normalize(part, proposed))
    }
    return(if (is.call(node)) as.call(parts) else if (is.pairlist(node)) as.pairlist(parts) else as.expression(parts))
  }
  node
}

files <- system2("git", c("diff", "--name-only", base_ref, "--", "R"), stdout = TRUE)
files <- setdiff(files, "R/conditions.R")
stopifnot(all(c("R/dictionary-helpers.R", "R/term_search.R", "R/sdp-extension-helpers.R") %in% files))
for (path in files) {
  old <- parse(text = system2("git", c("show", paste0(base_ref, ":", path)), stdout = TRUE), keep.source = FALSE)
  current <- parse(path, keep.source = FALSE)
  stopifnot(identical(normalize(old), normalize(current, proposed = TRUE)))
  cat(path, ": messages, calls, parents and control flow preserved\n")
}
