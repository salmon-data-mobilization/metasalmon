# Every YAML document metasalmon parses is parsed with `eval.expr = FALSE`.
#
# yaml's `!expr` tag asks the parser to evaluate the R code that follows it.
# Whether it does is decided by `eval.expr`, whose default is
# `getOption("yaml.eval.expr", <fallback>)`, and the fallback was TRUE until
# yaml 2.3.0 ("Made `eval.expr` default to `FALSE`", yaml's own NEWS). DESCRIPTION
# declares `yaml (>= 2.2.0)`, so a read that leaves the argument out executes
# R code found in its input on an install that DESCRIPTION permits, and on any
# yaml in a session that turned the option on. Every document this package
# parses can come from somebody else: a collaborator's SSSOM header or EML
# sidecar, or a schema bundle fetched over HTTP.
#
# Three layers, because each misses what the others see:
#
#   1. A static walk of the namespace (below) finds every call to a YAML reader
#      inside a function, and fails on one that does not pass the literal
#      `eval.expr = FALSE`. It is what catches the NEXT read: the list this file
#      began from was dated 2026-09-12 and named five sites, and a sixth
#      (`.ms_closure_mapping_paths()`) had landed four days later. It runs
#      wherever the package is installed, whether or not its sources exist.
#   2. A scan of the R/ sources applies the same rule to every expression in
#      every file. That covers what the namespace cannot show: code at the top
#      level of a file, which runs when the package is built or loaded and
#      leaves only its value behind, and a function stored inside another value
#      (raised by Codex in review of #147).
#   3. One behavioural test per site proves the argument does what the scans
#      assume: a real `!expr` tag in that site's real input, with the option
#      turned on, leaves no side effect. Each was shown failing against the
#      unfixed read before the fix (hub item B-142; the workpad records it).
#
# The SSSOM reader's behavioural test is in test-sssom.R, which predates this
# file (#111) and drives the validator; both scans cover that site too.
#
# *Retires when:* yaml stops evaluating `!expr` at all, or metasalmon stops
# parsing YAML. Not when DESCRIPTION's floor reaches 2.3.0: the option still
# turns evaluation back on there, which is the case the behavioural tests set.

# ---------------------------------------------------------------------------
# Layer 1: the namespace walk
# ---------------------------------------------------------------------------

# The YAML parsers in yaml's API. MAINTENANCE: add a function here when R/
# starts calling another YAML parser (a new yaml entry point, or another
# package's), together with that parser's own switch for code evaluation. A
# parser missing from this list is invisible to the walk, and the walk will
# still pass.
yaml_reader_fns <- c("yaml.load", "read_yaml", "yaml.load_file")

# The functions that hold a YAML read today. This is a POSITIVE CONTROL, not an
# allowlist: nothing here exempts anything. It proves that the namespace walk and
# the source scan both reach the reads that exist, so that a scan which silently
# stopped matching (a namespace it can no longer read, a source directory it
# cannot find, a changed call shape) fails instead of passing over nothing.
# Delete an entry when its read is deleted; add one when a read is added.
known_yaml_read_fns <- c(
  ".ms_sssom_parse_metadata",
  "write_eml_from_sdp",
  ".ms_knb_sdp_artifact_paths",
  ".ms_knb_build_plan",
  ".ms_fetch_remote_sdp_schema",
  ".ms_load_vendored_sdp_schema",
  ".ms_closure_mapping_paths"
)

# `yaml::read_yaml`, `yaml:::read_yaml`, or a bare `read_yaml`, as a function
# name; NA for anything else.
yaml_reader_ref <- function(node) {
  if (is.name(node)) {
    name <- as.character(node)
    return(if (name %in% yaml_reader_fns) name else NA_character_)
  }
  if (is.call(node) && length(node) == 3L && is.name(node[[1]]) &&
      as.character(node[[1]]) %in% c("::", ":::") &&
      identical(as.character(node[[2]]), "yaml") &&
      as.character(node[[3]]) %in% yaml_reader_fns) {
    return(as.character(node[[3]]))
  }
  NA_character_
}

# Walk an expression and return one record per YAML read or reference. A call
# is safe when it names `eval.expr` exactly and passes the literal FALSE: not
# `F`, which can be rebound; not a partial name, which reaches `eval.expr` only
# by partial matching; not a computed value. A reader that is REFERENCED rather
# than called (`lapply(files, yaml::read_yaml)`, `do.call("yaml.load", args)`)
# is always unsafe, because no argument list is visible to check.
collect_yaml_reads <- function(node, fn_name, acc = list()) {
  record <- function(kind, reader, safe) {
    acc[[length(acc) + 1L]] <<- list(
      fn = fn_name,
      kind = kind,
      reader = reader,
      safe = safe,
      code = paste(deparse(node, width.cutoff = 500L), collapse = " ")
    )
  }

  if (is.character(node) && length(node) == 1L && node %in% yaml_reader_fns) {
    record("reference", node, FALSE)
    return(acc)
  }
  # The formals of a function defined inside a body arrive as a pairlist, and a
  # default argument there runs as surely as the body does. (`is.pairlist(NULL)`
  # is TRUE, hence the second test.)
  if (is.pairlist(node) && !is.null(node)) {
    for (part in as.list(node)) {
      if (!missing(part)) {
        acc <- collect_yaml_reads(part, fn_name, acc)
      }
    }
    return(acc)
  }
  if (!is.call(node)) {
    reader <- yaml_reader_ref(node)
    if (!is.na(reader)) {
      record("reference", reader, FALSE)
    }
    return(acc)
  }

  reader <- yaml_reader_ref(node)
  if (!is.na(reader)) {
    # `yaml::read_yaml` itself, reached here as a value rather than as a call
    # head: the enclosing call passes the reader on instead of calling it.
    record("reference", reader, FALSE)
    return(acc)
  }

  head_reader <- yaml_reader_ref(node[[1]])
  parts <- as.list(node)
  if (!is.na(head_reader)) {
    args <- parts[-1]
    arg_names <- names(args)
    if (is.null(arg_names)) {
      arg_names <- rep("", length(args))
    }
    hit <- which(arg_names == "eval.expr")
    safe <- length(hit) == 1L && identical(args[[hit]], FALSE)
    record("call", head_reader, safe)
    parts <- args
  }

  for (part in parts) {
    if (!missing(part)) {
      acc <- collect_yaml_reads(part, fn_name, acc)
    }
  }
  acc
}

# Every function in the namespace, its default arguments as well as its body:
# a read in a default argument runs as surely as one in the body.
collect_namespace_yaml_reads <- function(ns = asNamespace("metasalmon")) {
  findings <- list()
  for (nm in sort(ls(ns, all.names = TRUE), method = "radix")) {
    obj <- get0(nm, envir = ns, inherits = FALSE)
    if (!is.function(obj) || is.primitive(obj)) {
      next
    }
    for (default in as.list(formals(obj))) {
      if (!missing(default)) {
        findings <- collect_yaml_reads(default, nm, findings)
      }
    }
    findings <- collect_yaml_reads(body(obj), nm, findings)
  }
  findings
}

test_that("every YAML read in metasalmon passes eval.expr = FALSE", {
  # Walks the installed namespace rather than grepping R/, as
  # test-cli-safety-guard.R does and for its reason: under `R CMD check` R/
  # holds no source files, so a grep would skip exactly where enforcement
  # matters. LIMITATIONS, stated so that green means only what it says: it sees
  # the functions bound in the namespace, so code at the top level of an R/
  # file, and a function stored inside another value, are left to the source
  # scan below; a reader reached through a string neither can see
  # (`get(paste0("read_", "yaml"))`) is invisible to both; and both know only
  # the parsers named in `yaml_reader_fns`.
  findings <- collect_namespace_yaml_reads()
  calls <- Filter(function(f) identical(f$kind, "call"), findings)
  reached <- unique(vapply(calls, `[[`, character(1), "fn"))

  missing_controls <- setdiff(known_yaml_read_fns, reached)
  expect(
    length(missing_controls) == 0L,
    paste0(
      "The walk no longer reaches a YAML read it is known to hold, so its ",
      "silence below would mean nothing. Not reached: ",
      paste(missing_controls, collapse = ", "),
      ". If the read was deleted, delete the entry from known_yaml_read_fns."
    )
  )

  unsafe <- Filter(function(f) !isTRUE(f$safe), findings)
  if (length(unsafe) > 0L) {
    detail <- vapply(
      unsafe,
      function(f) paste0(f$fn, " (", f$kind, "): ", substr(f$code, 1L, 160L)),
      character(1)
    )
    fail(paste0(
      "Every YAML read must pass the literal `eval.expr = FALSE`, or an `!expr` ",
      "tag in the input runs as R code.\n",
      paste(detail, collapse = "\n")
    ))
  }
  succeed()
})

test_that("the YAML read walk flags each unsafe shape and passes the safe ones", {
  # Without this, a walk that silently stopped matching would look like a pass.
  unsafe_shapes <- list(
    omitted = function(p) yaml::read_yaml(p),
    literal_true = function(p) yaml::yaml.load(p, eval.expr = TRUE),
    rebindable_f = function(p) yaml::yaml.load(p, eval.expr = F),
    computed = function(p, e) yaml::yaml.load(p, eval.expr = e),
    partial_name = function(p) yaml::yaml.load(p, eval = FALSE),
    triple_colon = function(p) yaml:::yaml.load_file(p),
    bare_name = function(p) read_yaml(p),
    nested_argument = function(p) identity(yaml::yaml.load(p)),
    nested_closure = function(p) {
      read <- function() yaml::read_yaml(p)
      read()
    },
    nested_closure_default = function(p) {
      read <- function(mapping = yaml::read_yaml(p)) mapping
      read()
    },
    inside_try_catch = function(p) tryCatch(yaml::read_yaml(p), error = function(e) NULL),
    passed_as_value = function(ps) lapply(ps, yaml::read_yaml),
    passed_by_name = function(p) do.call("yaml.load", list(p))
  )
  for (shape in names(unsafe_shapes)) {
    fn <- unsafe_shapes[[shape]]
    found <- collect_yaml_reads(body(fn), shape)
    expect_true(
      any(!vapply(found, `[[`, logical(1), "safe")),
      label = paste0("the walk flags the `", shape, "` shape")
    )
  }

  in_default <- function(p, mapping = yaml::read_yaml(p)) mapping
  found <- list()
  for (default in as.list(formals(in_default))) {
    if (!missing(default)) {
      found <- collect_yaml_reads(default, "in_default", found)
    }
  }
  expect_length(found, 1L)
  expect_false(found[[1]]$safe)

  safe_shapes <- list(
    read_yaml = function(p) yaml::read_yaml(p, eval.expr = FALSE),
    yaml_load = function(text) yaml::yaml.load(text, eval.expr = FALSE),
    load_file = function(p) yaml::yaml.load_file(p, eval.expr = FALSE),
    in_try_catch = function(p) {
      tryCatch(yaml::read_yaml(p, eval.expr = FALSE), error = function(e) NULL)
    }
  )
  for (shape in names(safe_shapes)) {
    found <- collect_yaml_reads(body(safe_shapes[[shape]]), shape)
    expect_length(found, 1L)
    expect_true(found[[1]]$safe, label = paste0("the `", shape, "` shape is safe"))
  }
})

# ---------------------------------------------------------------------------
# Layer 2: the source scan
# ---------------------------------------------------------------------------

# Every file R CMD INSTALL would source from R/: the extensions it collates.
r_source_files <- function(root) {
  sort(
    list.files(file.path(root, "R"), pattern = "[.][RrSsQq]$", full.names = TRUE),
    method = "radix"
  )
}

# The package's source root, or NA. Under devtools::test() the sources are two
# levels above tests/testthat. Under R CMD check the tests run in a copy inside
# the check directory, and the unpacked tarball sits beside that copy in
# `00_pkg_src/`, which is where CI's check finds them. Tests run from an
# installed package's own tests/ (installed with `--install-tests`) find that
# package two levels up, with a DESCRIPTION and an R/ directory; but that R/
# holds a lazy-load database and no source file, so it is never taken for the
# sources.
metasalmon_source_root <- function() {
  candidates <- c(
    testthat::test_path("..", ".."),
    testthat::test_path("..", "..", "00_pkg_src", "metasalmon")
  )
  for (root in candidates) {
    description <- file.path(root, "DESCRIPTION")
    if (!file.exists(description)) {
      next
    }
    package <- tryCatch(
      unname(read.dcf(description, fields = "Package")[1, 1]),
      error = function(e) NA_character_
    )
    if (identical(package, "metasalmon") && length(r_source_files(root)) > 0L) {
      return(normalizePath(root))
    }
  }
  NA_character_
}

# The name a top-level expression binds (`name <- value`), or NA.
top_level_binding <- function(expr) {
  if (is.call(expr) && length(expr) == 3L && is.name(expr[[1]]) &&
      as.character(expr[[1]]) %in% c("<-", "=", "<<-") &&
      (is.name(expr[[2]]) || is.character(expr[[2]]))) {
    return(as.character(expr[[2]]))
  }
  NA_character_
}

# Every expression in every source file, walked whole: top-level code, function
# bodies and default arguments alike, which makes this layer the literal form
# of B-142's condition ("every ... call in R/"). A read inside `name <- ...` is
# reported under `name`, which is what lets `known_yaml_read_fns` control this
# scan as well as the namespace walk. Anything else is reported under its file.
collect_source_yaml_reads <- function(root) {
  findings <- list()
  for (path in r_source_files(root)) {
    file_label <- paste0("R/", basename(path))
    for (expr in as.list(parse(path, keep.source = FALSE, encoding = "UTF-8"))) {
      name <- top_level_binding(expr)
      found <- collect_yaml_reads(expr, if (is.na(name)) file_label else name)
      findings <- c(
        findings,
        lapply(found, function(f) c(f, list(file = file_label)))
      )
    }
  }
  findings
}

test_that("every YAML read in the R/ sources passes eval.expr = FALSE, top-level code included", {
  root <- metasalmon_source_root()
  if (is.na(root)) {
    # Not finding the sources is not the same as finding them clean. CI always
    # has them, beside the tests or in R CMD check's `00_pkg_src/`, so there a
    # missing tree means this layer has stopped running, and that fails.
    # Elsewhere (an installed package tested on its own) the namespace walk
    # still runs, and this layer says plainly that it did not.
    # *Retires when:* nothing. This is how the layer reports that it could not look.
    skip_if_not(
      isTRUE(as.logical(Sys.getenv("CI", "false"))),
      "NOT CHECKED: the R/ sources are not beside these tests, so top-level YAML reads were not scanned (the namespace walk still ran)."
    )
    fail(paste(
      "NOT CHECKED on CI: the R/ sources were found neither beside the tests",
      "nor in R CMD check's 00_pkg_src/, so top-level YAML reads went unscanned."
    ))
  } else {
    findings <- collect_source_yaml_reads(root)
    calls <- Filter(function(f) identical(f$kind, "call"), findings)
    reached <- unique(vapply(calls, `[[`, character(1), "fn"))
    missing_controls <- setdiff(known_yaml_read_fns, reached)
    expect(
      length(missing_controls) == 0L,
      paste0(
        "The source scan does not reach a YAML read it is known to hold, so ",
        "its silence below would mean nothing. Not reached: ",
        paste(missing_controls, collapse = ", "),
        ". Sources scanned: ", root, "."
      )
    )

    unsafe <- Filter(function(f) !isTRUE(f$safe), findings)
    if (length(unsafe) > 0L) {
      detail <- vapply(
        unsafe,
        function(f) {
          paste0(f$file, ": ", f$fn, " (", f$kind, "): ", substr(f$code, 1L, 160L))
        },
        character(1)
      )
      fail(paste0(
        "Every YAML read in R/ must pass the literal `eval.expr = FALSE`, ",
        "top-level code included, or an `!expr` tag in its input runs as R code.\n",
        paste(detail, collapse = "\n")
      ))
    }
    succeed()
  }
})

test_that("the source scan flags a top-level read that the namespace walk cannot see", {
  # Codex's finding on #147, kept as a standing demonstration. A read at the top
  # level of an R/ file runs when the package is built or loaded, and binds only
  # its result, so the namespace walk, which walks functions, has nothing to
  # look at. A function kept inside a list is out of its sight for the same
  # reason. The source scan reads the expressions themselves.
  top_level <- c(
    ".rules <- yaml::yaml.load(\"probe: 1\")",
    ".readers <- list(sidecar = function(p) yaml::read_yaml(p))",
    ".safe <- yaml::yaml.load(\"probe: 1\", eval.expr = FALSE)"
  )
  root <- withr::local_tempdir()
  dir.create(file.path(root, "R"))
  writeLines(
    c(top_level, "yaml::yaml.load_file(\"settings.yml\")"),
    file.path(root, "R", "top-level.R")
  )

  found <- collect_source_yaml_reads(root)
  flagged <- vapply(Filter(function(f) !isTRUE(f$safe), found), `[[`, character(1), "fn")
  passed <- vapply(Filter(function(f) isTRUE(f$safe), found), `[[`, character(1), "fn")
  expect_setequal(flagged, c(".rules", ".readers", "R/top-level.R"))
  expect_identical(passed, ".safe")

  # The same bindings, made the way R/ makes them, leave the namespace walk
  # nothing to flag: each is a list, not a function. If this starts failing,
  # the namespace walk has learned to see them, and the division of labour in
  # this file's header should be rewritten to match.
  env <- new.env(parent = globalenv())
  eval(parse(text = top_level), envir = env)
  expect_length(collect_namespace_yaml_reads(env), 0L)
})

# ---------------------------------------------------------------------------
# Layer 3: one behavioural test per read
# ---------------------------------------------------------------------------
#
# Each test puts a real `!expr` tag in the real input of one read, turns
# `yaml.eval.expr` on, and asserts that the tag left no side effect. The option
# is the worst case on a current yaml; on the 2.2.x that DESCRIPTION still
# permits, evaluation needed no option at all. Where the site hands the value
# on, the test also asserts that it arrived as the text it is.

# The sentinel path goes inside an R string literal in the tag, so it is written
# with forward slashes: on Windows a backslash would be an escape, the evaluation
# would fail rather than run, and the test would pass for the wrong reason.
yaml_expr_probe <- function(env = parent.frame()) {
  dir <- normalizePath(withr::local_tempdir(.local_envir = env), winslash = "/")
  sentinel <- file.path(dir, "evaluated")
  text <- sprintf("file.create(\"%s\")", sentinel)
  list(sentinel = sentinel, text = text, tag = paste("!expr", text))
}

# The fixture's EML sidecar, with the one methods description replaced by the
# probe. That field is free text which only the EML export consumes, so every
# other reader of the sidecar goes on to do its ordinary work.
tag_fixture_sidecar <- function(package_path, probe) {
  sidecar <- file.path(package_path, "metadata", "eml-mapping.yml")
  lines <- readLines(sidecar, encoding = "UTF-8")
  benign <- "- description: Counts were compiled using the documented monitoring workflow."
  hit <- which(lines == benign)
  expect_length(hit, 1L)
  lines[hit] <- paste("- description:", probe$tag)
  writeLines(lines, sidecar, useBytes = TRUE)
  invisible(sidecar)
}

error_info <- function(result) {
  if (inherits(result, "error")) conditionMessage(result) else NULL
}

test_that("write_eml_from_sdp() never evaluates an !expr tag in the EML sidecar", {
  # R/eml-export.R. The function stops before its read when emld is absent, so
  # without emld this test could only pass vacuously. *Retires when:* emld
  # becomes a hard dependency, or the read moves ahead of the emld check.
  skip_if_not_installed("emld")
  probe <- yaml_expr_probe()
  package_path <- make_eml_test_sdp(withr::local_tempdir())
  tag_fixture_sidecar(package_path, probe)
  withr::local_options(yaml.eval.expr = TRUE)

  result <- tryCatch(
    suppressMessages(write_eml_from_sdp(package_path)),
    error = identity
  )

  expect_false(file.exists(probe$sentinel))
  expect_false(inherits(result, "error"), info = error_info(result))
  # The tag reaches the EML methods as the text it is, not as its value.
  methods_text <- if (inherits(result, "error")) {
    character()
  } else {
    xml2::xml_text(xml2::xml_find_all(
      xml2::read_xml(result$path),
      ".//*[local-name()='methods']//*[local-name()='para']"
    ))
  }
  expect_true(probe$text %in% methods_text)
})

test_that("the KNB artifact inventory never evaluates an !expr tag in the EML sidecar", {
  # R/knb-publication.R, `.ms_knb_sdp_artifact_paths()`: reached by both KNB
  # representations, the archive one through the SDP archive inventory.
  probe <- yaml_expr_probe()
  package_path <- make_knb_test_sdp(withr::local_tempdir())
  tag_fixture_sidecar(package_path, probe)
  withr::local_options(yaml.eval.expr = TRUE)

  paths <- tryCatch(
    .ms_knb_sdp_artifact_paths(package_path),
    error = identity
  )

  expect_false(file.exists(probe$sentinel))
  expect_false(inherits(paths, "error"), info = error_info(paths))
  # The inventory returns the root ledger only after checking the parsed
  # sidecar's `semantic_review.path` against it, so the sidecar was read.
  expect_true(any(endsWith(paths, "/reviewed_semantic_selections.csv")))
})

test_that("the KNB plan builder never evaluates an !expr tag in the EML sidecar", {
  # R/knb-publication.R, `.ms_knb_build_plan()`, reached here through the
  # exported dry run. The builder's next step is stopped so that this test sees
  # the builder's own read and no other: that step leads to the inventory and to
  # the EML export, whose reads are pinned by the two tests above. *Retires
  # when:* nothing after the builder's read parses YAML.
  probe <- yaml_expr_probe()
  package_path <- make_knb_test_sdp(withr::local_tempdir())
  tag_fixture_sidecar(package_path, probe)
  withr::local_options(yaml.eval.expr = TRUE)
  local_mocked_bindings(
    .ms_knb_write_sdp_archive = function(...) {
      stop(errorCondition(
        "Stopped after the plan builder read the sidecar.",
        class = "yaml_expr_guard_stop"
      ))
    },
    .package = "metasalmon"
  )

  expect_error(
    suppressMessages(publish_sdp_to_knb(
      package_path,
      public = TRUE,
      dry_run = TRUE,
      knb_environment = "production"
    )),
    class = "yaml_expr_guard_stop"
  )
  expect_false(file.exists(probe$sentinel))
})

test_that("the remote SDP schema fetch never evaluates an !expr tag in the rules", {
  # R/schema-helpers.R, `.ms_fetch_remote_sdp_schema()`: the one read whose
  # input arrives over the network. The responses are the vendored bundle's own
  # bytes, with the probe appended to the rules document as a key nothing reads.
  probe <- yaml_expr_probe()
  base_url <- "https://schema.invalid/sdp"
  requested <- character()
  httr2::local_mocked_responses(function(req) {
    relative <- substring(req$url, nchar(base_url) + 2L)
    requested <<- c(requested, relative)
    source <- system.file("extdata", relative, package = "metasalmon")
    if (!nzchar(source)) {
      return(httr2::response(status_code = 404L, url = req$url))
    }
    body <- rawToChar(readBin(source, "raw", file.info(source)$size))
    if (identical(relative, .ms_sdp_rules_path())) {
      body <- paste0(body, "\nprobe: ", probe$tag, "\n")
    }
    httr2::response(
      status_code = 200L,
      url = req$url,
      headers = list(`Content-Type` = "text/plain; charset=utf-8"),
      body = charToRaw(enc2utf8(body))
    )
  })
  withr::local_options(yaml.eval.expr = TRUE)

  schema <- tryCatch(
    .ms_fetch_remote_sdp_schema(base_url, timeout = 1),
    error = identity
  )

  expect_false(file.exists(probe$sentinel))
  expect_false(inherits(schema, "error"), info = error_info(schema))
  expect_true(.ms_sdp_rules_path() %in% requested)
  expect_identical(schema$rules$probe, probe$text)
})

test_that("the vendored SDP rules read never evaluates an !expr tag", {
  # R/schema-helpers.R, `.ms_load_vendored_sdp_schema()`. Its input is found
  # with system.file(), which is base R and cannot be mocked, so the input is
  # substituted one level down instead: the parser opens a tagged copy of the
  # vendored rules and receives exactly the arguments the call site passed.
  # Whether the tag runs is therefore decided by the site and by nothing else.
  # *Retires when:* the function takes its rules path from somewhere a test can
  # point elsewhere, at which point the tagged copy is simply passed in.
  probe <- yaml_expr_probe()
  vendored <- system.file("extdata", .ms_sdp_rules_path(), package = "metasalmon")
  tagged <- file.path(withr::local_tempdir(), "sdp.rules.yaml")
  writeLines(
    c(
      readLines(vendored, encoding = "UTF-8", warn = FALSE),
      paste("probe:", probe$tag)
    ),
    tagged,
    useBytes = TRUE
  )
  real_read_yaml <- yaml::read_yaml
  opened <- character()
  local_mocked_bindings(
    read_yaml = function(file, ...) {
      opened <<- c(opened, file)
      real_read_yaml(tagged, ...)
    },
    .package = "yaml"
  )
  withr::local_options(yaml.eval.expr = TRUE)

  schema <- tryCatch(.ms_load_vendored_sdp_schema(), error = identity)

  expect_false(file.exists(probe$sentinel))
  expect_false(inherits(schema, "error"), info = error_info(schema))
  expect_identical(normalizePath(opened), normalizePath(vendored))
  expect_identical(schema$rules$probe, probe$text)
})

test_that("the semantic closure's sidecar read never evaluates an !expr tag", {
  # R/semantic-closure.R, `.ms_closure_mapping_paths()`. The declared paths it
  # returns choose where write_sdp_semantic_closure() writes, so the tag is put
  # on one of them: it must come back as the text it is.
  probe <- yaml_expr_probe()
  sidecar <- file.path(withr::local_tempdir(), "eml-mapping.yml")
  writeLines(
    c(
      "semantic_vocabulary:",
      "  path: metadata/declared-vocabulary.csv",
      "semantic_review:",
      paste("  path:", probe$tag)
    ),
    sidecar,
    useBytes = TRUE
  )
  withr::local_options(yaml.eval.expr = TRUE)

  paths <- .ms_closure_mapping_paths(sidecar)

  expect_false(file.exists(probe$sentinel))
  # Parsed, not fallen back to the defaults: the declared path is honoured.
  expect_identical(paths$vocabulary, "metadata/declared-vocabulary.csv")
  expect_identical(paths$review, probe$text)
})
