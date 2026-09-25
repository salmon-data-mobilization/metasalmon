test_that("github_raw_url builds stable raw URLs", {
  url <- github_raw_url("path/to/file.csv", repo = "owner/repo")
  expect_equal(
    url,
    "https://raw.githubusercontent.com/owner/repo/main/path/to/file.csv"
  )

  custom <- github_raw_url("path/to/file.csv", ref = "v1.0.0", repo = "owner/repo")
  expect_equal(
    custom,
    "https://raw.githubusercontent.com/owner/repo/v1.0.0/path/to/file.csv"
  )

  token_url <- "https://raw.githubusercontent.com/owner/repo/main/path/to/file.csv?token=SECRET"
  sanitized <- github_raw_url(token_url)
  expect_equal(sanitized, "https://raw.githubusercontent.com/owner/repo/main/path/to/file.csv")
})

test_that("GitHub path resolution handles blob and raw URLs", {
  blob <- metasalmon:::ms_resolve_path(
    "https://github.com/owner/repo/blob/main/path/to/file.csv",
    ref = "ignored",
    repo = NULL
  )
  expect_equal(
    blob$url,
    "https://raw.githubusercontent.com/owner/repo/main/path/to/file.csv"
  )
  expect_equal(blob$repo, "owner/repo")
  expect_equal(blob$ref, "main")

  raw <- metasalmon:::ms_resolve_path(
    "https://raw.githubusercontent.com/owner/repo/main/path/to/file.csv",
    ref = "ignored",
    repo = NULL
  )
  expect_equal(raw$url, "https://raw.githubusercontent.com/owner/repo/main/path/to/file.csv")
  expect_equal(raw$path, "path/to/file.csv")
})

test_that("GitHub helper URL parsing rejects non-GitHub remote URLs", {
  expect_error(
    metasalmon:::ms_resolve_path(
      "https://example.com/data.csv",
      ref = "main",
      repo = NULL
    ),
    "URL inputs must use"
  )

  expect_error(
    metasalmon:::ms_resolve_dir_path(
      "https://example.com/data",
      ref = "main",
      repo = NULL
    ),
    "URL inputs must use"
  )
})

test_that("read_github_csv rejects non-GitHub URLs before any fetch", {
  expect_error(
    with_mocked_bindings(
      ms_github_get = function(url, token = NULL) {
        stop("network call should not happen")
      },
      read_github_csv("https://example.com/data.csv", token = "secret"),
      .package = "metasalmon"
    ),
    "URL inputs must use"
  )
})

test_that("read_github_csv can read public content without a token", {
  out <- with_mocked_bindings(
    ms_resolve_path = function(path, ref, repo) {
      list(
        url = "https://raw.githubusercontent.com/owner/repo/main/path/to/file.csv",
        repo = "owner/repo",
        ref = "main",
        path = "path/to/file.csv"
      )
    },
    ms_current_token = function() "",
    ms_github_get = function(url, token = NULL) {
      expect_equal(token, "")
      httr2::response(
        status_code = 200,
        url = url,
        body = charToRaw("a,b\n1,2\n")
      )
    },
    read_github_csv("path/to/file.csv", repo = "owner/repo"),
    .package = "metasalmon"
  )

  expect_s3_class(out, "data.frame")
  expect_equal(nrow(out), 1)
  expect_equal(ncol(out), 2)
})

test_that("read_github_csv_dir can list and read public content without a token", {
  used_tokens <- character()
  out <- with_mocked_bindings(
    ms_resolve_dir_path = function(path, ref, repo) {
      list(repo = "owner/repo", ref = "main", path = "data")
    },
    ms_current_token = function() "",
    ms_github_list_contents = function(repo, path, ref, token = NULL) {
      expect_equal(token, "")
      list(
        list(type = "file", name = "a.csv"),
        list(type = "file", name = "b.txt"),
        list(type = "file", name = "c.csv")
      )
    },
    read_github_csv = function(path, ref = "main", repo = NULL, token = NULL, ...) {
      used_tokens <<- c(used_tokens, token)
      data.frame(x = 1, stringsAsFactors = FALSE)
    },
    read_github_csv_dir("data", repo = "owner/repo"),
    .package = "metasalmon"
  )

  expect_type(out, "list")
  expect_equal(names(out), c("a", "c"))
  expect_equal(used_tokens, c("", ""))
})

# Skip unless `url` can be fetched the way read_github_csv() fetches it: a GET
# to that raw.githubusercontent.com URL carrying the token as
# `Authorization: token <token>`, which is what ms_github_get() sends. The live
# tests below used to guard with gh::gh() against api.github.com instead, a
# different host and a different credential path, so the guard passed while
# the fetch failed and the tests errored rather than skipped (hub item B-152:
# measured with a token that api.github.com accepts and the raw host answers
# with 404). The request is built here rather than through the package, so a
# defect in the package still fails the test instead of becoming a skip.
#
# Retires when: these tests stop reaching the network. If ms_github_get()
# changes the host or how it sends the token, this probe changes in the same
# commit; the pin below fails until it does.
skip_unless_raw_github_serves <- function(url, token = "") {
  req <- httr2::request(url) |>
    httr2::req_timeout(30) |>
    httr2::req_retry(max_tries = 4) |>
    httr2::req_error(is_error = function(resp) FALSE)
  if (nzchar(token)) {
    req <- httr2::req_headers(req, Authorization = paste("token", token))
  }
  resp <- tryCatch(httr2::req_perform(req), error = function(e) e)
  if (inherits(resp, "error")) {
    testthat::skip(paste("Cannot reach", url, "-", conditionMessage(resp)))
  }
  status <- httr2::resp_status(resp)
  if (status >= 400) {
    testthat::skip(sprintf(
      "%s answered HTTP %d to a request %s the configured token.",
      url, status, if (nzchar(token)) "carrying" else "without"
    ))
  }
  invisible(resp)
}

# The two pins below answer requests with httr2::local_mocked_responses()
# (httr2 1.0.0) and read them back with httr2::req_get_headers() (1.2.0).
# DESCRIPTION pins neither, so they skip on an older install, as
# test-llm-chat-request.R does. Retires when DESCRIPTION's Imports requires
# httr2 (>= 1.2.0).
test_that("the raw-host guard sends the request read_github_csv() sends", {
  skip_if_not_installed("httr2", "1.2.0")
  seen <- list()
  httr2::local_mocked_responses(function(req) {
    seen[[length(seen) + 1L]] <<- req
    httr2::response(
      status_code = 200,
      headers = list(`Content-Type` = "text/csv; charset=utf-8"),
      body = charToRaw("x\n1\n")
    )
  })
  token <- "fake-token-for-b152"
  url <- "https://raw.githubusercontent.com/owner/repo/main/data/file.csv"

  read_github_csv("data/file.csv", ref = "main", repo = "owner/repo", token = token, progress = FALSE)
  skip_unless_raw_github_serves(url, token = token)

  auth <- function(req) httr2::req_get_headers(req, redacted = "reveal")$Authorization
  expect_length(seen, 2L)
  expect_identical(seen[[1]]$url, url)
  expect_identical(seen[[2]]$url, seen[[1]]$url)
  expect_match(auth(seen[[1]]), token, fixed = TRUE)
  expect_identical(auth(seen[[2]]), auth(seen[[1]]))
})

test_that("the raw-host guard skips when that host refuses the request or cannot be reached", {
  skip_if_not_installed("httr2", "1.0.0")
  url <- "https://raw.githubusercontent.com/owner/repo/main/data/file.csv"
  guard_skip <- function(mock) {
    httr2::local_mocked_responses(mock)
    tryCatch(
      {
        skip_unless_raw_github_serves(url, token = "fake-token-for-b152")
        NA_character_
      },
      skip = conditionMessage
    )
  }

  expect_match(guard_skip(function(req) httr2::response(status_code = 404)), "HTTP 404")
  expect_match(
    guard_skip(function(req) stop("simulated transport failure")),
    "simulated transport failure"
  )
  expect_identical(guard_skip(function(req) httr2::response(status_code = 200)), NA_character_)
})

test_that("read_github_csv can read remote content with a token", {
  token <- metasalmon:::ms_current_token()
  skip_if(!nzchar(token), "No GitHub token configured; skipping Qualark fetch test.")

  # metasalmon's own repository: public, so this runs everywhere including CI.
  # It previously defaulted to a *private* repo in another org, so the test
  # skipped with a 404 that read like a broken token, and the GitHub read
  # helpers went unexercised in CI entirely. Override the env vars to point at
  # a private repo when testing those permissions specifically.
  repo <- Sys.getenv("METASALMON_GITHUB_TEST_REPO", "salmon-data-mobilization/metasalmon")
  path <- Sys.getenv("METASALMON_GITHUB_TEST_PATH", "inst/extdata/nuseds-fraser-coho-sample.csv")
  ref <- Sys.getenv("METASALMON_GITHUB_TEST_REF", "main")

  skip_unless_raw_github_serves(
    sprintf("https://raw.githubusercontent.com/%s/%s/%s", repo, ref, path),
    token = token
  )

  df <- read_github_csv(path, ref = ref, repo = repo, token = token, progress = FALSE)

  expect_s3_class(df, "data.frame")
  expect_gt(nrow(df), 0)
  expect_gt(ncol(df), 0)
})

test_that("read_github_csv without token can read a known public GitHub raw CSV", {
  skip_if_offline()

  df <- read_github_csv(
    "https://raw.githubusercontent.com/salmon-data-mobilization/metasalmon/main/inst/extdata/nuseds-fraser-coho-sample.csv",
    token = "",
    progress = FALSE
  )

  expect_s3_class(df, "data.frame")
  expect_gt(nrow(df), 0)
  expect_gt(ncol(df), 0)
})

test_that("ms_resolve_dir_path handles directory paths correctly", {
  # Test relative path
  result <- metasalmon:::ms_resolve_dir_path("data/observations", ref = "main", repo = "owner/repo")
  expect_equal(result$repo, "owner/repo")
  expect_equal(result$ref, "main")
  expect_equal(result$path, "data/observations")

  # Test path with trailing slash
  result2 <- metasalmon:::ms_resolve_dir_path("data/observations/", ref = "main", repo = "owner/repo")
  expect_equal(result2$path, "data/observations")

  # Test empty path (root)
  result3 <- metasalmon:::ms_resolve_dir_path("", ref = "main", repo = "owner/repo")
  expect_equal(result3$path, "")

  # Test blob URL (directory)
  blob_dir <- metasalmon:::ms_resolve_dir_path(
    "https://github.com/owner/repo/tree/main/data/observations",
    ref = "ignored",
    repo = NULL
  )
  expect_equal(blob_dir$repo, "owner/repo")
  expect_equal(blob_dir$ref, "main")
  expect_equal(blob_dir$path, "data/observations")

  # Test raw URL (extracts directory from file path)
  raw_dir <- metasalmon:::ms_resolve_dir_path(
    "https://raw.githubusercontent.com/owner/repo/main/data/observations/file.csv",
    ref = "ignored",
    repo = NULL
  )
  expect_equal(raw_dir$repo, "owner/repo")
  expect_equal(raw_dir$ref, "main")
  expect_equal(raw_dir$path, "data/observations")
})

test_that("read_github_csv_dir can fetch when a token is configured", {
  token <- metasalmon:::ms_current_token()
  skip_if(!nzchar(token), "No GitHub token configured; skipping directory fetch test.")

  # metasalmon's own repository: public, so this runs everywhere including CI.
  # It previously defaulted to a *private* repo in another org, so the test
  # skipped with a 404 that read like a broken token, and the GitHub read
  # helpers went unexercised in CI entirely. Override the env vars to point at
  # a private repo when testing those permissions specifically.
  repo <- Sys.getenv("METASALMON_GITHUB_TEST_REPO", "salmon-data-mobilization/metasalmon")
  dir_path <- Sys.getenv("METASALMON_GITHUB_TEST_DIR", "inst/extdata")
  ref <- Sys.getenv("METASALMON_GITHUB_TEST_REF", "main")

  tryCatch(
    gh::gh(sprintf("/repos/%s", repo), .token = token),
    error = function(e) {
      testthat::skip(paste("Cannot access", repo, "with current token:", conditionMessage(e)))
    }
  )

  tryCatch(
    {
      contents <- gh::gh(
        sprintf("/repos/%s/contents/%s", repo, dir_path),
        .token = token,
        ref = ref
      )
      if (!is.null(contents$type) && contents$type == "file") {
        testthat::skip(paste("Path", dir_path, "is a file, not a directory"))
      }
      csv_files <- Filter(
        function(x) x$type == "file" && grepl("\\.csv$", x$name, ignore.case = TRUE),
        contents
      )
      if (length(csv_files) == 0) {
        testthat::skip(paste("Directory", dir_path, "has no CSV files"))
      }
    },
    error = function(e) {
      testthat::skip(paste("Test directory path not reachable:", conditionMessage(e)))
    }
  )

  # The probes above cover the listing, which goes through the API as
  # read_github_csv_dir() does. Each listed file is then fetched from
  # raw.githubusercontent.com with the token, so probe the first of those
  # fetches too. Only the first: that proves the host and the token, and a
  # fetch that fails for one particular file should still fail the test.
  skip_unless_raw_github_serves(
    sprintf("https://raw.githubusercontent.com/%s/%s/%s", repo, ref, csv_files[[1]]$path),
    token = token
  )

  # `inst/extdata` holds CSVs with unrelated schemas, so readr reports parse
  # issues per file. The behaviour under test is the directory fetch, not the
  # parse fidelity of a heterogeneous fixture.
  data_list <- suppressWarnings(
    read_github_csv_dir(dir_path, ref = ref, repo = repo, token = token)
  )

  expect_type(data_list, "list")
  expect_gt(length(data_list), 0)
  for (i in seq_along(data_list)) {
    expect_s3_class(data_list[[i]], "data.frame")
  }
  expect_true(all(nchar(names(data_list)) > 0))
})

test_that("read_github_csv_dir handles empty directories", {
  token <- metasalmon:::ms_current_token()
  skip_if(!nzchar(token), "No GitHub token configured; skipping empty directory test.")

  # metasalmon's own repository: public, so this runs everywhere including CI.
  # It previously defaulted to a *private* repo in another org, so the test
  # skipped with a 404 that read like a broken token, and the GitHub read
  # helpers went unexercised in CI entirely. Override the env vars to point at
  # a private repo when testing those permissions specifically.
  repo <- Sys.getenv("METASALMON_GITHUB_TEST_REPO", "salmon-data-mobilization/metasalmon")
  ref <- Sys.getenv("METASALMON_GITHUB_TEST_REF", "main")

  expect_error(
    read_github_csv_dir(
      "nonexistent-directory-that-should-not-exist",
      ref = ref,
      repo = repo,
      token = token
    ),
    "not found|404",
    ignore.case = TRUE
  )
})
