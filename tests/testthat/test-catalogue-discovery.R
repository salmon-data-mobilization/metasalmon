catalogue_stamp <- "2026-09-30T16:00:00+00:00"
catalogue_query <- 'text:Fraser AND text:sockeye AND title:"stock recruit"'

catalogue_page_bytes <- function(found, start, ids) {
  charToRaw(jsonlite::toJSON(list(response = list(
    numFound = found, start = start,
    docs = lapply(ids, function(pid) list(id = pid, title = "Fraser sockeye"))
  )), auto_unbox = TRUE, null = "null", digits = NA))
}

catalogue_read_bytes <- function(path) {
  readBin(path, "raw", n = file.info(path)$size)
}

catalogue_test_capture <- function(out, fetch, ...) {
  capture_catalogue_query(
    catalogue_query, out, fetch = fetch, captured_at = catalogue_stamp, ...
  )
}

test_that("public endpoints and query receipts preserve pending metadata evidence", {
  for (catalogue in c("knb", "dataone")) {
    out <- tempfile("catalogue-")
    on.exit(unlink(out, recursive = TRUE), add = TRUE)
    calls <- list()
    fetch <- function(url, timeout, max_bytes) {
      calls[[length(calls) + 1L]] <<- list(url = url, timeout = timeout, max_bytes = max_bytes)
      catalogue_page_bytes(1L, 0L, "doi:10.5063/TM78J7")
    }
    receipt <- catalogue_test_capture(out, fetch, catalogue = catalogue)
    expected <- if (catalogue == "knb") {
      "https://knb.ecoinformatics.org/knb/d1/mn/v2/query/solr/"
    } else "https://cn.dataone.org/cn/v2/query/solr/"
    expect_identical(receipt$endpoint, expected)
    url <- httr::parse_url(calls[[1L]]$url)
    expect_identical(url$scheme, "https")
    expect_null(url$username)
    expect_null(url$password)
    expect_identical(url$query$q, catalogue_query)
    expect_identical(url$query$fq, "formatType:METADATA")
    expect_identical(url$query$sort, "id asc")
    expect_identical(url$query$start, "0")
    expect_identical(url$query$rows, "50")
    expect_identical(url$query$wt, "json")
    expect_match(url$query$fl, "obsoletes,obsoletedBy", fixed = TRUE)
    expect_equal(calls[[1L]]$timeout, 30)
    expect_equal(calls[[1L]]$max_bytes, 2000000)
    expect_identical(receipt$captured_at, catalogue_stamp)
    expect_identical(receipt$annotation_status, "pending")
    expect_null(receipt$independent_dataset_count)
    expect_false(receipt$transactional_snapshot)
    saved <- jsonlite::fromJSON(file.path(out, "capture.json"), simplifyVector = FALSE)
    expect_identical(saved, receipt)
    raw <- catalogue_read_bytes(file.path(out, receipt$pages[[1L]]$file))
    expect_identical(receipt$pages[[1L]]$sha256, digest::digest(raw, algo = "sha256", serialize = FALSE))
    expect_identical(receipt$pages[[1L]]$bytes, length(raw))
    expect_identical(raw, catalogue_page_bytes(1L, 0L, "doi:10.5063/TM78J7"))
  }
})

test_that("paging caps and complete-for-count claims are distinct", {
  for (cap in c(3L, 7L)) {
    out <- tempfile("catalogue-")
    on.exit(unlink(out, recursive = TRUE), add = TRUE)
    calls <- list()
    ids <- letters[1:5]
    fetch <- function(url, timeout, max_bytes) {
      query <- httr::parse_url(url)$query
      start <- as.integer(query$start)
      rows <- as.integer(query$rows)
      calls[[length(calls) + 1L]] <<- c(start, rows)
      catalogue_page_bytes(5L, start, ids[seq.int(start + 1L, min(start + rows, 5L))])
    }
    receipt <- catalogue_test_capture(out, fetch, max_records = cap, page_size = 2L)
    count <- min(cap, 5L)
    expect_equal(receipt$captured_metadata_records, count)
    expect_equal(receipt$reported_metadata_matches, 5L)
    expect_identical(receipt$complete_for_reported_count, cap == 7L)
    expect_identical(vapply(receipt$records, `[[`, character(1), "id"), ids[seq_len(count)])
    expected <- if (cap == 3L) list(c(0L, 2L), c(2L, 1L)) else list(c(0L, 2L), c(2L, 2L), c(4L, 2L))
    expect_identical(calls, expected)
  }
})

test_that("zero matches are a bounded query result without an independence claim", {
  out <- tempfile("catalogue-")
  on.exit(unlink(out, recursive = TRUE))
  receipt <- catalogue_test_capture(out, function(...) catalogue_page_bytes(0L, 0L, character()))
  expect_equal(receipt$reported_metadata_matches, 0L)
  expect_equal(receipt$captured_metadata_records, 0L)
  expect_identical(receipt$records, list())
  expect_true(receipt$complete_for_reported_count)
  expect_length(receipt$pages, 1L)
  expect_null(receipt$independent_dataset_count)
})

test_that("valid high-precision capture timestamps remain unchanged", {
  stamp <- "2026-09-30T16:00:59.9999999999999999Z"
  out <- tempfile("catalogue-timestamp-")
  on.exit(unlink(out, recursive = TRUE))
  receipt <- capture_catalogue_query(catalogue_query, out,
    fetch = function(...) catalogue_page_bytes(0L, 0L, character()),
    captured_at = stamp
  )
  expect_identical(receipt$captured_at, stamp)
  saved <- jsonlite::fromJSON(file.path(out, "capture.json"), simplifyVector = FALSE)
  expect_identical(saved$captured_at, stamp)
})

test_that("JSON counts are mathematical integers within exact numeric range", {
  for (count in c("3.0", "9007199254740991")) {
    out <- tempfile("catalogue-numeric-")
    on.exit(unlink(out, recursive = TRUE), add = TRUE)
    body <- charToRaw(paste0('{"response":{"numFound":', count, ',"start":0.0,"docs":[{"id":"a"}]}}'))
    receipt <- catalogue_test_capture(out, function(...) body, max_records = 1L)
    expect_equal(receipt$reported_metadata_matches, as.numeric(count))
    expect_equal(receipt$captured_metadata_records, 1L)
    expect_false(receipt$complete_for_reported_count)
  }
  for (count in c("1.5", "9007199254740992", "-1", "true")) {
    out <- tempfile("catalogue-numeric-")
    on.exit(unlink(paste0(out, ".incomplete"), recursive = TRUE), add = TRUE)
    body <- charToRaw(paste0('{"response":{"numFound":', count, ',"start":0,"docs":[{"id":"a"}]}}'))
    expect_error(catalogue_test_capture(out, function(...) body), "paging")
  }
})

test_that("unstable or malformed pages preserve raw failure evidence", {
  cases <- list(
    list(catalogue_page_bytes(4L, 1L, "b"), "changed"),
    list(catalogue_page_bytes(3L, 1L, "a"), "repeated"),
    list(catalogue_page_bytes(3L, 1L, character()), "Empty page"),
    list(catalogue_page_bytes(3L, 0L, "b"), "paging"),
    list(catalogue_page_bytes(3L, 1L, c("b", "c")), "paging")
  )
  for (case in cases) {
    out <- tempfile("catalogue-")
    on.exit(unlink(paste0(out, ".incomplete"), recursive = TRUE), add = TRUE)
    i <- 0L
    first <- catalogue_page_bytes(3L, 0L, "a")
    fetch <- function(...) {
      i <<- i + 1L
      if (i == 1L) first else case[[1L]]
    }
    expect_error(catalogue_test_capture(out, fetch, page_size = 1L), case[[2L]])
    incomplete <- paste0(out, ".incomplete")
    expect_false(dir.exists(out))
    expect_identical(catalogue_read_bytes(file.path(incomplete, "page-0000.json")), first)
    expect_identical(catalogue_read_bytes(file.path(incomplete, "page-0001.json")), case[[1L]])
    expect_false(file.exists(file.path(incomplete, "capture.json")))
    failure <- jsonlite::fromJSON(file.path(incomplete, "failure.json"), simplifyVector = FALSE)
    expect_identical(failure$status, "incomplete")
    expect_identical(failure$semantic_approval, "pending")
  }
})

test_that("transport failure preserves its original exception and earlier pages", {
  out <- tempfile("catalogue-")
  on.exit(unlink(paste0(out, ".incomplete"), recursive = TRUE))
  i <- 0L
  fetch <- function(...) {
    i <<- i + 1L
    if (i > 1L) stop("fixture transport interrupted")
    catalogue_page_bytes(2L, 0L, "a")
  }
  expect_error(catalogue_test_capture(out, fetch, page_size = 1L), "fixture transport interrupted")
  expect_true(file.exists(file.path(paste0(out, ".incomplete"), "page-0000.json")))
  expect_false(file.exists(file.path(paste0(out, ".incomplete"), "capture.json")))
})

test_that("a trailing output separator still preserves failure in a sibling", {
  out <- tempfile("catalogue-trailing-")
  on.exit(unlink(c(out, paste0(out, ".incomplete")), recursive = TRUE))
  expect_error(catalogue_test_capture(paste0(out, "/"), function(...) stop("fixture failure")), "fixture failure")
  expect_false(dir.exists(out))
  expect_true(file.exists(file.path(paste0(out, ".incomplete"), "failure.json")))
})

test_that("existing paths and dangling symlinks stop before transport", {
  parent <- tempfile("catalogue-existing-")
  dir.create(parent)
  on.exit(unlink(parent, recursive = TRUE))
  forbidden <- function(...) stop("forbidden transport")
  for (suffix in c("", ".incomplete")) {
    out <- file.path(parent, paste0("capture", nchar(suffix)))
    existing <- paste0(out, suffix)
    dir.create(existing)
    marker <- file.path(existing, "evidence.txt")
    writeBin(charToRaw("previous reviewed evidence"), marker)
    expect_error(catalogue_test_capture(out, forbidden), "never overwritten")
    expect_identical(rawToChar(catalogue_read_bytes(marker)), "previous reviewed evidence")
    unlink(existing, recursive = TRUE)
    expect_true(file.symlink(file.path(parent, "nonexistent"), existing))
    expect_error(catalogue_test_capture(out, forbidden), "never overwritten")
    expect_identical(Sys.readlink(existing), file.path(parent, "nonexistent"))
    unlink(existing)
  }
})

test_that("atomic destination reservation never replaces a competing capture", {
  out <- tempfile("catalogue-race-")
  on.exit(unlink(out, recursive = TRUE))
  marker <- file.path(out, "competitor.txt")
  racing_reserve <- function(path) {
    dir.create(path)
    writeBin(charToRaw("another capture owns this directory"), marker)
    dir.create(path, showWarnings = FALSE)
  }
  expect_error(with_mocked_bindings(
    catalogue_test_capture(out, function(...) stop("forbidden transport")),
    .ms_catalogue_reserve_directory = racing_reserve
  ), "never overwritten")
  expect_identical(list.files(out), "competitor.txt")
  expect_identical(rawToChar(catalogue_read_bytes(marker)), "another capture owns this directory")
})

test_that("a competing incomplete reservation remains untouched on failure", {
  out <- tempfile("catalogue-race-")
  incomplete <- paste0(out, ".incomplete")
  on.exit(unlink(c(out, incomplete), recursive = TRUE))
  original <- .ms_catalogue_reserve_directory
  reserve <- function(path) {
    if (identical(path, incomplete)) {
      dir.create(path)
      writeBin(charToRaw("other failure receipt"), file.path(path, "other-capture.txt"))
    }
    original(path)
  }
  expect_error(with_mocked_bindings(
    catalogue_test_capture(out, function(...) stop("fixture failure")),
    .ms_catalogue_reserve_directory = reserve
  ), "fixture failure")
  expect_true(file.exists(file.path(out, "failure.json")))
  expect_identical(list.files(incomplete), "other-capture.txt")
  expect_identical(rawToChar(catalogue_read_bytes(file.path(incomplete, "other-capture.txt"))), "other failure receipt")
})

test_that("late-created residuals survive incomplete capture cleanup", {
  out <- tempfile("catalogue-late-artifact-")
  incomplete <- paste0(out, ".incomplete")
  on.exit(unlink(c(out, incomplete), recursive = TRUE))
  original <- .ms_catalogue_move_artifact
  move <- function(from, to) {
    moved <- original(from, to)
    # Arrives after the handler enumerates the artifacts it owns.
    writeBin(charToRaw("preserve late evidence"), file.path(out, "late-note.txt"))
    moved
  }
  expect_warning(expect_error(with_mocked_bindings(
    catalogue_test_capture(out, function(...) stop("fixture failure")),
    .ms_catalogue_move_artifact = move
  ), "fixture failure"), "directory retained")
  expect_identical(rawToChar(catalogue_read_bytes(file.path(out, "late-note.txt"))), "preserve late evidence")
  expect_true(file.exists(file.path(incomplete, "failure.json")))
  expect_false(file.exists(file.path(out, "capture.json")))
})

test_that("injected capture never uses provider, publication or default transport", {
  out <- tempfile("catalogue-offline-")
  on.exit(unlink(out, recursive = TRUE))
  forbidden <- function(...) stop("forbidden network or semantic side effect")
  expect_no_error(with_mocked_bindings(
    catalogue_test_capture(out, function(...) catalogue_page_bytes(1L, 0L, "a")),
    .ms_catalogue_public_get = forbidden, .ms_knb_require_token = forbidden,
    find_terms = forbidden, create_sdp = forbidden, publish_sdp_to_knb = forbidden
  ))
})

test_that("invalid parameters and timestamps create no evidence or network calls", {
  parent <- tempfile("catalogue-inputs-")
  dir.create(parent)
  on.exit(unlink(parent, recursive = TRUE))
  out <- file.path(parent, "capture")
  forbidden <- function(...) stop("forbidden transport")
  cases <- list(
    list(max_records = 0), list(max_records = 1001), list(max_records = TRUE),
    list(page_size = 0), list(page_size = 101), list(page_size = "10"),
    list(max_bytes = 0), list(max_bytes = 10000001), list(max_bytes = FALSE),
    list(timeout = 0), list(timeout = 121), list(timeout = Inf), list(timeout = NaN),
    list(timeout = TRUE), list(catalogue = "private"), list(fetch = FALSE), list(fetch = 0)
  )
  for (case in cases) {
    args <- c(list(query = catalogue_query, out = out, captured_at = catalogue_stamp), case)
    if (!"fetch" %in% names(case)) args$fetch <- forbidden
    expect_error(do.call(capture_catalogue_query, args))
    expect_length(list.files(parent, all.files = TRUE, no.. = TRUE), 0L)
  }
  for (query in list("", " ", paste(rep("x", 4097L), collapse = ""), NULL, list())) {
    expect_error(capture_catalogue_query(query, out, fetch = forbidden, captured_at = catalogue_stamp), "query")
    expect_length(list.files(parent, all.files = TRUE, no.. = TRUE), 0L)
  }
  for (stamp in list("", "2026-09-30T16:00:00", "not a timestamp", 123, "2026-02-30T01:00:00Z")) {
    expect_error(capture_catalogue_query(catalogue_query, out, fetch = forbidden, captured_at = stamp), "timestamp")
    expect_length(list.files(parent, all.files = TRUE, no.. = TRUE), 0L)
  }
})

test_that("bad first pages and unbounded transports never produce a success marker", {
  bodies <- list(
    charToRaw("not json"), charToRaw("{}"),
    catalogue_page_bytes(0L, 0L, "a"), catalogue_page_bytes(1L, 0L, ""),
    catalogue_page_bytes(TRUE, 0L, "a"), catalogue_page_bytes(1.5, 0L, "a"),
    charToRaw('{"response":{"numFound":1,"start":0,"docs":{"id":"a"}}}')
  )
  for (body in bodies) {
    out <- tempfile("catalogue-bad-")
    on.exit(unlink(paste0(out, ".incomplete"), recursive = TRUE), add = TRUE)
    expect_error(catalogue_test_capture(out, function(...) body))
    incomplete <- paste0(out, ".incomplete")
    expect_identical(catalogue_read_bytes(file.path(incomplete, "page-0000.json")), body)
    expect_true(file.exists(file.path(incomplete, "failure.json")))
    expect_false(file.exists(file.path(incomplete, "capture.json")))
  }
  for (body in list("not raw bytes", charToRaw(paste(rep("x", 31L), collapse = "")))) {
    out <- tempfile("catalogue-bad-")
    on.exit(unlink(paste0(out, ".incomplete"), recursive = TRUE), add = TRUE)
    expect_error(catalogue_test_capture(out, function(...) body, max_bytes = 30L), "bounded raw bytes")
    expect_false(file.exists(file.path(paste0(out, ".incomplete"), "capture.json")))
  }
})

test_that("default public transport bounds streaming bytes without credentials", {
  calls <- list()
  stub <- function(request, ...) {
    calls[[length(calls) + 1L]] <<- request
    bytes <- charToRaw("abcd")
    offset <- 0L
    body <- list(
      close = function() invisible(NULL),
      is_complete = function() offset >= length(bytes),
      read = function(n) {
        end <- min(length(bytes), offset + n)
        chunk <- bytes[seq.int(offset + 1L, end)]
        offset <<- end
        chunk
      }
    )
    structure(list(status_code = 200L, body = body), class = "httr2_response")
  }
  expect_error(with_mocked_bindings(
    .ms_catalogue_public_get("https://knb.ecoinformatics.org/query", 5, 3L),
    req_perform_connection = stub, .package = "httr2"
  ), "max_bytes")
  request <- calls[[1L]]
  expect_setequal(tolower(names(request$headers)), c("user-agent", "accept"))
  expect_equal(request$options$netrc, 0L)
  expect_identical(request$options$proxy, "")
  expect_equal(request$options$timeout_ms, 5000)
  expect_null(request$auth)
  expect_identical(with_mocked_bindings(
    .ms_catalogue_public_get("https://knb.ecoinformatics.org/query", 5, 4L),
    req_perform_connection = stub, .package = "httr2"
  ), charToRaw("abcd"))
  bad_status <- function(...) {
    structure(list(status_code = 503L, body = list(close = function() NULL)), class = "httr2_response")
  }
  expect_error(with_mocked_bindings(
    .ms_catalogue_public_get("https://knb.ecoinformatics.org/query", 5, 4L),
    req_perform_connection = bad_status, .package = "httr2"
  ), "HTTP 503")
})


test_that("the mirrored shared catalogue capture fixtures retain their outcomes", {
  fixture <- jsonlite::fromJSON(
    test_path("fixtures", "catalogue-capture", "shared-v1.json"),
    simplifyVector = FALSE
  )
  for (case in fixture$cases) {
    out <- tempfile("catalogue-shared-")
    on.exit(unlink(c(out, paste0(out, ".incomplete")), recursive = TRUE), add = TRUE)
    calls <- 0L
    fetch <- function(url, timeout, max_bytes) {
      calls <<- calls + 1L
      if (calls > length(case$pages)) stop("unexpected fixture request")
      charToRaw(enc2utf8(case$pages[[calls]]))
    }
    result <- tryCatch(capture_catalogue_query(
      fixture$query, out, catalogue = case$catalogue,
      max_records = case$max_records, page_size = case$page_size,
      fetch = fetch, captured_at = fixture$captured_at
    ), error = identity)
    if (identical(case$status, "success")) {
      expect_false(inherits(result, "error"), info = case$name)
      expect_identical(result$captured_metadata_records, as.integer(case$captured))
      expect_identical(result$complete_for_reported_count, case$complete)
      expect_identical(result$annotation_status, "pending")
      expect_null(result$independent_dataset_count)
      expect_false(result$transactional_snapshot)
      expect_true(file.exists(file.path(out, "capture.json")))
      for (i in seq_along(case$pages)) {
        path <- file.path(out, sprintf("page-%04d.json", i - 1L))
        expect_identical(catalogue_read_bytes(path), charToRaw(enc2utf8(case$pages[[i]])))
        expect_identical(result$pages[[i]]$sha256,
          digest::digest(charToRaw(enc2utf8(case$pages[[i]])), algo = "sha256", serialize = FALSE))
      }
    } else {
      expect_true(inherits(result, "error"), info = case$name)
      incomplete <- paste0(out, ".incomplete")
      expect_false(file.exists(file.path(out, "capture.json")))
      expect_false(file.exists(file.path(incomplete, "capture.json")))
      expect_true(file.exists(file.path(incomplete, "failure.json")))
      for (i in seq_along(case$pages)) {
        expect_identical(catalogue_read_bytes(file.path(incomplete,
          sprintf("page-%04d.json", i - 1L))), charToRaw(enc2utf8(case$pages[[i]])))
      }
    }
    expect_identical(calls, length(case$pages))
  }
})


test_that("failed capture cleanup preserves the original condition under warning escalation", {
  out <- tempfile("catalogue-cleanup-warning-")
  on.exit(unlink(c(out, paste0(out, ".incomplete")), recursive = TRUE), add = TRUE)
  old <- options(warn = 2)
  on.exit(options(old), add = TRUE)
  original <- structure(list(message = "original transport condition", call = NULL),
    class = c("catalogue_original_failure", "error", "condition"))
  result <- tryCatch(testthat::with_mocked_bindings(
    catalogue_test_capture(out, function(...) stop(original)),
    .ms_catalogue_write_receipt = function(...) stop("failure receipt filesystem error")
  ), error = identity)
  expect_identical(result, original)
  expect_false(file.exists(file.path(out, "capture.json")))
  expect_false(file.exists(file.path(paste0(out, ".incomplete"), "capture.json")))
})

test_that("an incomplete-directory exception cannot mask the original capture failure", {
  out <- tempfile("catalogue-cleanup-reservation-")
  on.exit(unlink(c(out, paste0(out, ".incomplete")), recursive = TRUE), add = TRUE)
  original <- structure(list(message = "original transport condition", call = NULL),
    class = c("catalogue_original_failure", "error", "condition"))
  reserve <- .ms_catalogue_reserve_directory
  result <- tryCatch(suppressWarnings(testthat::with_mocked_bindings(
    catalogue_test_capture(out, function(...) stop(original)),
    .ms_catalogue_reserve_directory = function(path) {
      if (identical(path, paste0(out, ".incomplete"))) stop("reservation filesystem error")
      reserve(path)
    }
  )), error = identity)
  expect_identical(result, original)
  expect_true(file.exists(file.path(out, "failure.json")))
  expect_false(file.exists(file.path(out, "capture.json")))
})

test_that("an interrupted capture retains its raw pages and original interrupt", {
  out <- tempfile("catalogue-interrupt-")
  on.exit(unlink(c(out, paste0(out, ".incomplete")), recursive = TRUE), add = TRUE)
  original <- structure(list(message = "fixture interrupt", call = NULL),
    class = c("catalogue_test_interrupt", "interrupt", "condition"))
  calls <- 0L
  first <- catalogue_page_bytes(2L, 0L, "a")
  result <- tryCatch(catalogue_test_capture(out, function(...) {
    calls <<- calls + 1L
    if (calls == 1L) first else stop(original)
  }, page_size = 1L), interrupt = identity)
  expect_identical(result, original)
  incomplete <- paste0(out, ".incomplete")
  expect_true(file.exists(file.path(incomplete, "failure.json")))
  expect_true(file.exists(file.path(incomplete, "page-0000.json")))
  expect_false(file.exists(file.path(incomplete, "capture.json")))
  if (file.exists(file.path(incomplete, "page-0000.json")))
    expect_identical(catalogue_read_bytes(file.path(incomplete, "page-0000.json")), first)
})


test_that("a genuine unhandled native interrupt retains evidence without becoming an error", {
  # tools::pskill uses TerminateProcess on Windows, which cannot deliver SIGINT.
  # Retires when: a Windows-native interrupt driver exercises this same
  # unhandled-condition boundary without terminating before evidence is saved.
  skip_on_os("windows")
  root <- normalizePath(testthat::test_path("..", ".."), mustWork = TRUE)
  sandbox <- tempfile("catalogue-native-interrupt-")
  dir.create(sandbox)
  on.exit(unlink(sandbox, recursive = TRUE), add = TRUE)
  out <- file.path(sandbox, "capture")
  script <- file.path(sandbox, "interrupt.R")
  encode <- function(value) paste(capture.output(dput(value)), collapse = "\n")
  # Development loads the exact checkout. In installed R CMD check, root is
  # the metasalmon.Rcheck library containing the installed metasalmon directory.
  # The child has no outer exiting interrupt/error handler.
  code <- c(
    paste0("root <- ", encode(root)),
    "if (file.exists(file.path(root, 'R', 'catalogue-discovery.R'))) {",
    "  pkgload::load_all(root, quiet = TRUE)",
    "} else {",
    "  library(metasalmon, lib.loc = root)",
    "}",
    paste0("expected_body <- ", encode(deparse(body(capture_catalogue_query)))),
    "stopifnot(identical(deparse(body(capture_catalogue_query)), expected_body))",
    paste0("out <- ", encode(out)),
    "calls <- 0L",
    "fetch <- function(...) {",
    "  calls <<- calls + 1L",
    "  if (calls == 1L) return(charToRaw('{\"response\":{\"numFound\":2,\"start\":0,\"docs\":[{\"id\":\"a\"}]}}'))",
    "  tools::pskill(Sys.getpid(), 2L)",
    "  Sys.sleep(5)",
    "  stop('native interrupt was not delivered')",
    "}",
    "capture_catalogue_query('q', out, max_records = 2L, page_size = 1L, fetch = fetch, captured_at = '2026-10-06T09:00:00+00:00')",
    "writeLines('capture unexpectedly returned', file.path(dirname(out), 'returned'))"
  )
  writeLines(code, script)
  stdout <- file.path(sandbox, "stdout")
  stderr <- file.path(sandbox, "stderr")
  status <- suppressWarnings(system2(file.path(R.home("bin"), "Rscript"),
    c("--vanilla", shQuote(script)), stdout = stdout, stderr = stderr))
  diagnostics <- paste(readLines(stderr, warn = FALSE), collapse = "\n")
  expect_false(identical(status, 0L))
  expect_false(grepl("bad error message|native interrupt was not delivered", diagnostics))
  expect_false(file.exists(file.path(sandbox, "returned")))
  incomplete <- paste0(out, ".incomplete")
  expect_true(file.exists(file.path(incomplete, "failure.json")))
  expect_identical(catalogue_read_bytes(file.path(incomplete, "page-0000.json")),
    charToRaw('{"response":{"numFound":2,"start":0,"docs":[{"id":"a"}]}}'))
  expect_false(file.exists(file.path(incomplete, "capture.json")))
  expect_false(file.exists(file.path(out, "capture.json")))
})
