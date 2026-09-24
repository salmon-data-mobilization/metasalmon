# No vignette relies on a global knitr::opts_chunk$set() to keep its
# display-only code out of the script R CMD check runs.
#
# R CMD check's "checking running R code from vignettes" step re-tangles each
# vignette in a fresh R process -- tools:::.run_one_vignette() calls the
# vignette engine's tangle function, knitr::purl() here, on a copy of
# vignettes/ -- and source()s the script that comes out. Tangling runs no
# chunk, so the setup chunk's knitr::opts_chunk$set(eval = FALSE), which is
# what lets the knit display code without running it, never takes effect
# there: every chunk that does not say otherwise in its own options is written
# out as live code, and run. In a display-only vignette that code reads package
# directories nothing created, wants credentials, or calls the network, and the
# step fails at its first statement.
#
# Backlog #32 fixed this on 2026-07-21 (roadmap E5) by declaring purl = FALSE
# in every display-only chunk of six vignettes. Its entry records the rule, and
# nothing checked it: migrating-to-sdp-0-3-0.Rmd and tidy-data-for-sdp.Rmd were
# written afterwards in the shape it closed. Hub item B-164 added this file;
# its workpad shows the test failing on both before anything else changed.
#
# WHY A TEST RATHER THAN THE CHECK. That step no longer runs by default. From
# R 4.4.0 `_R_CHECK_VIGNETTES_SKIP_RUN_MAYBE_` defaults to true (it was false
# up to 4.3.3), which skips running a vignette's code whenever the vignettes
# are also re-built and it has no .Rout.save; `--as-cran` sets it on every
# version. So CI, on a current R, is green while `R CMD check` fails for a user
# on R 4.1 to 4.3, which DESCRIPTION supports. This test runs wherever the
# suite runs, under R CMD check included, where it reads the vignettes from the
# unpacked tarball.
#
# THE RULE AS TESTED. A vignette relies on a global option when a
# knitr::opts_chunk$set() call in its chunks sets `eval` or `purl` to anything
# but the literal TRUE. A call this file cannot read -- a computed value, an
# unnamed argument, opts_chunk used any other way -- counts as relying, because
# a guard that cannot read a line has not cleared it. Such a vignette must
# tangle, through its own engine and with knitr's default chunk options (what
# the fresh process has), to a script holding no live R expression. purl =
# FALSE in a chunk's own options drops the chunk from the script, and eval =
# FALSE there leaves it in as comments; both pass, and purl = FALSE is the
# convention #32 set. Where in the document the option is set is not modelled:
# once a vignette relies on one, its whole script must be free of live code, so
# a chunk that turns evaluation back on needs purl = FALSE as well (its knit
# has already run it). A vignette that sets no such option, one written to
# execute, may tangle live code, which is then the code its own knit ran.
#
# WHAT IT DOES NOT SEE. Chunk options set any way other than an
# opts_chunk$set() call in a chunk: an output format's knitr options,
# opts_hooks, opts_template, inline code. It reads R Markdown chunk syntax only,
# so a vignette in any other format fails here rather than passing unread.
#
# *Retires when:* CI's own R CMD check runs "checking running R code from
# vignettes" (`_R_CHECK_VIGNETTES_SKIP_RUN_MAYBE_: false` in
# .github/workflows/R-CMD-check.yaml). The real step is then the guard, and this
# model of it can go. That cannot happen while known_offenders below has an
# entry, because the real step fails on every one.

# Vignettes that break the rule today. Each is named with the queue item that
# fixes it and pinned to the violation it had when it was recorded: the first
# statement of every chunk that tangles as live code, and the count of live
# expressions. An entry covers exactly that violation. A chunk that turns live in
# a listed vignette fails the test just as it would in any other vignette, and
# so does any other change to what the entry pins. A list of file names alone
# would let such chunks through, which the Codex review of #157 caught. A listed
# vignette that stops breaking the rule fails too, until its entry is deleted,
# so no entry outlives its defect. A vignette that breaks the rule without being
# listed fails as well, which is the check backlog #32 lacked.
#
# MAINTENANCE: delete an entry in the change that fixes its vignette, and trim
# it in a change that fixes some of its chunks. Add an entry only for a defect
# that has its own queue item, never to let a new vignette or a new chunk
# through. The fix is one chunk option per chunk.
#
# *Retires when:* hub item B-133 declares purl = FALSE in these two vignettes'
# display-only chunks and deletes both entries, their pinned violations with
# them. The list is then empty, and stays empty.
known_offenders <- list(
  "migrating-to-sdp-0-3-0.Rmd" = list(
    item = "B-133",
    expressions = 50L,
    chunks = c(
      "tables <- readr::read_csv(\"weir-counts-sdp/metadata/tables.csv\", na = \"\")",
      "tables$protocol_iri[tables$table_id == \"escapement\"] <-",
      "readr::write_csv(tables, \"weir-counts-sdp/metadata/tables.csv\", na = \"\")",
      "escapement <- readr::read_csv(\"weir-counts-sdp/data/escapement.csv\", na = \"\")",
      "nuseds_enumeration_method_crosswalk()",
      "sources_for_role(\"statistical_modifier\")",
      "library(metasalmon)",
      "library(metasalmon)",
      "report <- migrate_sdp_methods(legacy_path, dry_run = TRUE)",
      "report$tables",
      "report$registry[c(\"method_label\", \"method_version\", \"citation\")]",
      "report <- migrate_sdp_methods(legacy_path)",
      "tables <- readr::read_csv(",
      "names(readr::read_csv(",
      "file.exists(file.path(legacy_path, \"metadata\", \"methods.csv\"))",
      "validate_salmon_datapackage(legacy_path, require_iris = FALSE)",
      "reviewed_dict <- read_salmon_datapackage(legacy_path)$dictionary",
      "report <- migrate_sdp_methods(\"weir-counts-sdp\", dry_run = TRUE)"
    )
  ),
  "tidy-data-for-sdp.Rmd" = list(
    item = "B-133",
    expressions = 18L,
    chunks = c(
      "tables <- readr::read_csv(\"escapement-sdp/metadata/tables.csv\", na = \"\")",
      "validate_salmon_datapackage(\"escapement-sdp\", require_iris = FALSE)",
      "wide <- tibble::tibble(",
      "c(\"stream_id\", \"count_1998\", \"count_1999\", \"count_2000\")",
      "long <- tidyr::pivot_longer(",
      "pkg_path <- create_sdp(",
      "wide_two <- tibble::tibble("
    )
  )
)

# The metasalmon source tree whose vignettes/ this run can read, or NA. Under
# devtools::test() it is two levels above tests/testthat; under R CMD check the
# tests run in a copy and the unpacked tarball sits beside it in 00_pkg_src/,
# the same two places test-yaml-expr-guard.R looks for R/.
vignette_source_root <- function() {
  candidates <- c(
    testthat::test_path("..", ".."),
    testthat::test_path("..", "..", "00_pkg_src", "metasalmon")
  )
  for (root in candidates) {
    description <- file.path(root, "DESCRIPTION")
    if (!file.exists(description) || !dir.exists(file.path(root, "vignettes"))) {
      next
    }
    package <- tryCatch(
      unname(read.dcf(description, fields = "Package")[1, 1]),
      error = function(e) NA_character_
    )
    if (identical(package, "metasalmon")) {
      return(normalizePath(root))
    }
  }
  NA_character_
}

# The code chunks of an R Markdown document, paired the way knitr pairs them: a
# chunk opens on a line matching knitr's own chunk.begin pattern and closes at
# the next fence with the same indentation and number of backticks. One record
# per chunk: the line it opens on, its engine, and its body.
rmd_chunks <- function(lines) {
  begin <- knitr::all_patterns$md$chunk.begin
  chunks <- list()
  i <- 1L
  while (i <= length(lines)) {
    if (!grepl(begin, lines[[i]])) {
      i <- i + 1L
      next
    }
    close <- sub("(^[\t >]*```+).*", "^\\1\\\\s*$", lines[[i]])
    j <- i + 1L
    while (j <= length(lines) && !grepl(close, lines[[j]])) {
      j <- j + 1L
    }
    header <- sub(begin, "\\1", lines[[i]])
    chunks[[length(chunks) + 1L]] <- list(
      line = i,
      engine = sub("^([a-zA-Z0-9_]+).*$", "\\1", header),
      body = lines[i + seq_len(max(0L, j - i - 1L))]
    )
    i <- j + 1L
  }
  chunks
}

opts_chunk_ref <- function(node) {
  identical(node, quote(opts_chunk)) ||
    identical(node, quote(knitr::opts_chunk)) ||
    identical(node, quote(knitr:::opts_chunk))
}

# Every way the given R chunks set a global chunk option that can keep code from
# running or from the tangle, one sentence each; character(0) when they set
# none. Read without running anything.
global_suppression <- function(chunks) {
  findings <- character()
  note <- function(line, what) {
    findings <<- c(findings, sprintf("the chunk at line %d %s", line, what))
  }
  walk <- function(node, line) {
    if (opts_chunk_ref(node)) {
      note(line, "uses knitr::opts_chunk in a way this guard cannot read")
      return(invisible())
    }
    if (!is.call(node)) {
      return(invisible())
    }
    fn <- node[[1]]
    is_set <- is.call(fn) && identical(fn[[1]], as.name("$")) &&
      identical(fn[[3]], as.name("set")) && opts_chunk_ref(fn[[2]])
    if (!is_set) {
      for (part in as.list(node)) {
        if (!missing(part)) walk(part, line)
      }
      return(invisible())
    }
    # knitr's own reading: named options, or one unnamed list() of them.
    args <- as.list(node)[-1L]
    arg_names <- names(args)
    if (is.null(arg_names)) arg_names <- rep("", length(args))
    if (length(args) == 1L && !nzchar(arg_names[[1]]) && is.call(args[[1]]) &&
        identical(args[[1]][[1]], as.name("list"))) {
      args <- as.list(args[[1]])[-1L]
      arg_names <- names(args)
      if (is.null(arg_names)) arg_names <- rep("", length(args))
    }
    for (k in seq_along(args)) {
      if (!nzchar(arg_names[[k]])) {
        note(line, "passes knitr::opts_chunk$set() an argument this guard cannot read")
      } else if (arg_names[[k]] %in% c("eval", "purl") && !identical(args[[k]], TRUE)) {
        note(line, sprintf(
          "sets %s = %s through knitr::opts_chunk$set()",
          arg_names[[k]], deparse1(args[[k]])
        ))
      }
      value <- args[[k]]
      if (!missing(value)) walk(value, line)
    }
    invisible()
  }
  for (chunk in chunks) {
    code <- paste(chunk$body, collapse = "\n")
    if (!grepl("opts_chunk", code, fixed = TRUE)) {
      next
    }
    exprs <- tryCatch(parse(text = code, keep.source = FALSE), error = function(e) NULL)
    if (is.null(exprs)) {
      note(chunk$line, "mentions opts_chunk and does not parse, so this guard cannot read it")
      next
    }
    for (expr in as.list(exprs)) walk(expr, chunk$line)
  }
  unique(findings)
}

# Tangle one vignette as the check's fresh process does: through its own engine,
# in a scratch copy of its directory (so a child document still resolves), with
# knitr's default chunk options. The script's lines, or character(0) when the
# engine writes none.
fresh_tangle <- function(doc, engine, encoding) {
  scratch <- withr::local_tempdir()
  file.copy(dirname(doc), scratch, recursive = TRUE)
  here <- file.path(scratch, basename(dirname(doc)))
  script <- file.path(here, paste0(tools::file_path_sans_ext(basename(doc)), c(".R", ".r")))
  # vignettes/*.R is git-ignored, so a checkout can hold a stale script from an
  # earlier build; it must not be read as this tangle's.
  unlink(script)
  chunk_options <- knitr::opts_chunk$get()
  knitr::opts_chunk$restore()
  withr::defer(knitr::opts_chunk$restore(chunk_options))
  withr::local_dir(here)
  tools::vignetteEngine(engine)$tangle(basename(doc), quiet = TRUE, encoding = encoding)
  script <- script[file.exists(script)]
  if (length(script) == 0L) {
    return(character())
  }
  readLines(script[[1]], encoding = "UTF-8", warn = FALSE)
}

# The live chunks of a tangled script. knitr::purl() writes a `## ----` line
# before each chunk it keeps, which splits the script back into its chunks; a
# chunk is live when its code parses to at least one expression, or does not
# parse at all, since source() stops on either.
live_chunks <- function(script) {
  if (length(script) == 0L) {
    return(list())
  }
  starts <- grep("^## ----", script)
  if (length(starts) == 0L || starts[[1]] != 1L) {
    starts <- c(1L, starts)
  }
  ends <- c(starts[-1L] - 1L, length(script))
  live <- list()
  for (k in seq_along(starts)) {
    code <- script[starts[[k]]:ends[[k]]]
    exprs <- tryCatch(parse(text = code, keep.source = FALSE), error = function(e) NULL)
    if (!is.null(exprs) && length(exprs) == 0L) {
      next
    }
    live[[length(live) + 1L]] <- list(
      first = code[!grepl("^\\s*(#|$)", code)][1L],
      count = if (is.null(exprs)) NA_integer_ else length(exprs)
    )
  }
  live
}

vignette_verdict <- function(doc, engine = "knitr::rmarkdown", encoding = "UTF-8") {
  lines <- readLines(doc, encoding = "UTF-8", warn = FALSE)
  chunks <- Filter(function(chunk) tolower(chunk$engine) == "r", rmd_chunks(lines))
  reliance <- global_suppression(chunks)
  live <- live_chunks(fresh_tangle(doc, engine, encoding))
  # Place each live chunk back in the source, in order, for the failure message.
  from <- 1L
  for (k in seq_along(live)) {
    live[[k]]$line <- NA_integer_
    for (j in seq_along(chunks)) {
      if (j < from || is.na(live[[k]]$first)) {
        next
      }
      if (trimws(live[[k]]$first) %in% trimws(chunks[[j]]$body)) {
        live[[k]]$line <- chunks[[j]]$line
        from <- j + 1L
        break
      }
    }
  }
  list(
    reliance = reliance,
    live = live,
    offends = length(reliance) > 0L && length(live) > 0L
  )
}

describe_offender <- function(name, verdict) {
  counts <- vapply(verdict$live, function(chunk) chunk$count, integer(1))
  where <- vapply(verdict$live, function(chunk) {
    sprintf("    line %s: %s", if (is.na(chunk$line)) "?" else chunk$line, chunk$first)
  }, character(1))
  paste0(
    "vignettes/", name, " relies on a global chunk option (",
    paste(verdict$reliance, collapse = "; "),
    "), which R CMD check's fresh-session tangle never applies, so ",
    length(verdict$live), " chunk(s) reach the script it runs as live code",
    if (anyNA(counts)) " (at least one does not parse)" else sprintf(" (%d expressions)", sum(counts)),
    ":\n", paste(where, collapse = "\n"),
    "\n  Declare purl = FALSE in each of those chunks' own options, as backlog #32 did."
  )
}

# How a known offender's live chunks differ from the violation its entry pins,
# as one message, or character(0) when they match. Chunks are matched by first
# statement, one recorded chunk per live one, so a repeated statement counts
# twice and a reordering changes nothing.
pinned_drift <- function(name, entry, verdict) {
  counts <- vapply(verdict$live, function(chunk) chunk$count, integer(1))
  expressions <- if (anyNA(counts)) NA_integer_ else sum(counts)
  unmatched <- entry$chunks
  added <- character()
  for (chunk in verdict$live) {
    hit <- match(trimws(chunk$first), unmatched)
    if (is.na(hit)) {
      added <- c(added, sprintf(
        "    line %s: %s", if (is.na(chunk$line)) "?" else chunk$line, chunk$first
      ))
    } else {
      unmatched <- unmatched[-hit]
    }
  }
  if (length(added) == 0L && length(unmatched) == 0L &&
      identical(expressions, entry$expressions)) {
    return(character())
  }
  paste0(
    "vignettes/", name, " is listed in known_offenders against ", entry$item,
    ", but its violation is no longer the one the entry pins:",
    if (length(added)) paste0("\n  now live, and not in the entry:\n", paste(added, collapse = "\n")),
    if (length(unmatched)) {
      paste0("\n  in the entry, and no longer live:\n", paste0("    ", unmatched, collapse = "\n"))
    },
    if (!identical(expressions, entry$expressions)) {
      sprintf("\n  live expressions: %s pinned, %s now", entry$expressions, expressions)
    },
    "\n  Declare purl = FALSE in the own options of each chunk that is newly live.",
    " Where pinned chunks were fixed, trim the entry in the same change."
  )
}

test_that("the guard flags a vignette relying on a global chunk option, passes each per-chunk fix, and holds a known offender to its pin", {
  skip_if_not_installed("knitr")

  vignette <- function(setup, chunk) {
    c(
      "---",
      "title: \"Fixture\"",
      "output: rmarkdown::html_vignette",
      "vignette: >",
      "  %\\VignetteIndexEntry{Fixture}",
      "  %\\VignetteEngine{knitr::rmarkdown}",
      "  %\\VignetteEncoding{UTF-8}",
      "---",
      "",
      setup,
      "",
      "Some prose.",
      "",
      chunk,
      ""
    )
  }
  setup <- function(header, call) c(paste0("```{", header, "}"), call, "```")
  display_setup <- setup(
    "r, include = FALSE, purl = FALSE",
    "knitr::opts_chunk$set(collapse = TRUE, comment = \"#>\", eval = FALSE)"
  )
  shown <- function(header, body = "readr::read_csv(\"nothing-made-this.csv\")") {
    c(paste0("```{", header, "}"), body, "```")
  }

  cases <- list(
    # The shape B-164 is about, and the reason #32 exists.
    list("a bare chunk under a global eval = FALSE", display_setup, shown("r"), TRUE),
    # #32's fix, and the two other per-chunk declarations knitr honours.
    list("purl = FALSE in the chunk header", display_setup, shown("r, purl = FALSE"), FALSE),
    list("eval = FALSE in the chunk header", display_setup, shown("r, eval = FALSE"), FALSE),
    # B-133's retirement condition names this as a fix. It is not: the setup
    # chunk reaches the script, and the chunk after it is still live.
    list(
      "the setup chunk purled instead",
      setup("r, include = FALSE", "knitr::opts_chunk$set(eval = FALSE)"),
      shown("r"),
      TRUE
    ),
    # The item's own wording: a global purl = FALSE is as invisible to the
    # tangle as a global eval = FALSE.
    list(
      "a bare chunk under a global purl = FALSE",
      setup("r, include = FALSE, purl = FALSE", "knitr::opts_chunk$set(purl = FALSE)"),
      shown("r", "x <- 1 + 1"),
      TRUE
    ),
    list(
      "the options passed as one list()",
      setup("r, include = FALSE, purl = FALSE", "knitr::opts_chunk$set(list(eval = FALSE))"),
      shown("r"),
      TRUE
    ),
    list(
      "a computed eval, read conservatively",
      setup(
        "r, include = FALSE, purl = FALSE",
        "knitr::opts_chunk$set(eval = nzchar(Sys.getenv(\"RUN_VIGNETTES\")))"
      ),
      shown("r"),
      TRUE
    ),
    list(
      "opts_chunk used in a form this guard cannot read",
      setup("r, include = FALSE, purl = FALSE", "do.call(knitr::opts_chunk$set, list(eval = FALSE))"),
      shown("r"),
      TRUE
    ),
    # A vignette written to execute tangles the code its own knit ran.
    list(
      "an executing vignette that sets no global eval or purl",
      setup("r, include = FALSE", "knitr::opts_chunk$set(collapse = TRUE, comment = \"#>\")"),
      shown("r", "x <- 1 + 1"),
      FALSE
    )
  )
  # knitr reads chunk options from `#|` lines from 1.35; the tangle, not a
  # header pattern, is what decides, and this case is the proof. *Retires
  # when:* DESCRIPTION requires knitr >= 1.35, and the condition goes with it.
  if (utils::packageVersion("knitr") >= "1.35") {
    cases[[length(cases) + 1L]] <- list(
      "purl: false as an in-chunk #| option",
      display_setup,
      shown("r", c("#| purl: false", "readr::read_csv(\"nothing-made-this.csv\")")),
      FALSE
    )
  }

  dir <- file.path(withr::local_tempdir(), "vignettes")
  dir.create(dir)
  doc <- file.path(dir, "fixture.Rmd")
  for (case in cases) {
    writeLines(vignette(case[[2]], case[[3]]), doc)
    verdict <- vignette_verdict(doc)
    expect_identical(verdict$offends, case[[4]], info = case[[1]])
  }

  # The pin behind known_offenders. An entry that matches passes. One more live
  # chunk, one fewer, or one more live statement each fails. A name-only list
  # passed all three, which is what the Codex review of #157 found.
  writeLines(vignette(display_setup, c(shown("r", "a <- 1"), "", shown("r", c("b <- 2", "d <- 3")))), doc)
  verdict <- vignette_verdict(doc)
  pin <- list(item = "a fixture", expressions = 3L, chunks = c("b <- 2", "a <- 1"))
  expect_identical(pinned_drift("fixture.Rmd", pin, verdict), character())
  expect_match(
    pinned_drift("fixture.Rmd", utils::modifyList(pin, list(chunks = "a <- 1")), verdict),
    "now live, and not in the entry:\n    line 20: b <- 2", fixed = TRUE
  )
  expect_match(
    pinned_drift("fixture.Rmd", utils::modifyList(pin, list(chunks = c(pin$chunks, "e <- 4"))), verdict),
    "in the entry, and no longer live:\n    e <- 4", fixed = TRUE
  )
  expect_match(
    pinned_drift("fixture.Rmd", utils::modifyList(pin, list(expressions = 2L)), verdict),
    "live expressions: 2 pinned, 3 now", fixed = TRUE
  )
})

test_that("no vignette relies on a global knitr::opts_chunk$set() to keep display-only code out of R CMD check's tangle", {
  skip_if_not_installed("knitr")
  root <- vignette_source_root()
  # Not a suppression: an installed package holds no vignette sources to read,
  # and the message says so rather than passing. It retires with this file.
  if (is.na(root)) {
    skip(paste(
      "NOT CHECKED: no metasalmon source tree with a vignettes/ directory beside",
      "these tests (they are running from an installed package). Run the suite",
      "from a source checkout, or under R CMD check."
    ))
  }

  found <- tools::pkgVignettes(dir = root)
  expect(
    length(found$docs) > 0L,
    paste0(
      "tools::pkgVignettes() found no vignette under ", root, ". A scan that",
      " reaches nothing passes over everything; if the package really has no",
      " vignettes any more, delete this guard."
    )
  )

  problems <- character()
  flagged <- character()
  for (i in seq_along(found$docs)) {
    doc <- found$docs[[i]]
    name <- basename(doc)
    if (!grepl("[.][Rr]md$", name)) {
      problems <- c(problems, paste0(
        "vignettes/", name, " is not R Markdown, and this guard reads R Markdown",
        " chunk syntax only; teach global_suppression() its syntax before relying on it."
      ))
      next
    }
    verdict <- vignette_verdict(doc, found$engines[[i]], found$encodings[[i]])
    if (!verdict$offends) {
      next
    }
    flagged <- c(flagged, name)
    entry <- known_offenders[[name]]
    problems <- c(
      problems,
      if (is.null(entry)) describe_offender(name, verdict) else pinned_drift(name, entry, verdict)
    )
  }
  for (name in setdiff(names(known_offenders), flagged)) {
    problems <- c(problems, paste0(
      "vignettes/", name, " is listed in known_offenders against ",
      known_offenders[[name]]$item, ", but no longer relies on a global chunk",
      " option to keep code out of the tangle. Its fix has landed: delete the",
      " entry in the same change."
    ))
  }

  expect(length(problems) == 0L, paste(problems, collapse = "\n\n"))
})
