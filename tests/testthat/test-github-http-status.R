# These tests cross httr2's real request boundary rather than mocking the
# package helper: req_perform() must return the statuses the CSV reader handles.
# The offline response injector needs httr2 >= 1.0.0. Retire that version skip
# when DESCRIPTION requires at least that version.
test_that("GitHub CSV reads reach their authentication and path remedies", {
  skip_if_not_installed("httr2", "1.0.0")
  for (status in c(401L, 403L, 404L)) {
    for (token in c("", "fake-token-for-b256")) {
      sso_cases <- if (status == 403L) c(FALSE, TRUE) else FALSE
      for (sso in sso_cases) {
        httr2::local_mocked_responses(function(req) {
          httr2::response(
            status_code = status,
            headers = if (sso) list(`x-github-sso` = "required") else list()
          )
        })
        failure <- tryCatch(
          read_github_csv("data.csv", repo = "owner/repo", token = token),
          error = identity
        )
        expect_s3_class(failure, "rlang_error")
        expect_false(inherits(failure, "httr2_http"))
        message <- conditionMessage(failure)
        expect_false(grepl("fake-token-for-b256", message, fixed = TRUE))
        if (status == 401L) {
          expect_match(message, "GitHub authentication failed", fixed = TRUE)
          expect_match(message, "refresh your PAT", fixed = TRUE)
        } else if (sso) {
          expect_match(message, "Access blocked by org SSO", fixed = TRUE)
          expect_match(message, "Re-authorize your PAT", fixed = TRUE)
        } else if (status == 403L && nzchar(token)) {
          expect_match(message, "was denied (status 403)", fixed = TRUE)
          expect_false(grepl("without authentication", message, fixed = TRUE))
        } else if (status == 403L) {
          expect_match(message, "denied without authentication (status 403)", fixed = TRUE)
          expect_match(message, "ms_setup_github", fixed = TRUE)
        } else {
          expect_match(message, "not found at ref", fixed = TRUE)
          expect_identical(grepl("configure a PAT", message, fixed = TRUE), !nzchar(token))
        }
      }
    }
  }
})

test_that("GitHub CSV status handling preserves other HTTP and transport errors", {
  skip_if_not_installed("httr2", "1.0.0")
  for (status in c(400L, 500L)) {
    httr2::local_mocked_responses(function(req) httr2::response(status_code = status))
    expect_error(
      read_github_csv("data.csv", repo = "owner/repo", token = ""),
      class = paste0("httr2_http_", status)
    )
  }
  httr2::local_mocked_responses(function(req) stop("offline transport sentinel"))
  expect_error(
    read_github_csv("data.csv", repo = "owner/repo", token = ""),
    "offline transport sentinel", fixed = TRUE
  )
})

test_that("GitHub CSV status handling still parses successful CSV content", {
  skip_if_not_installed("httr2", "1.0.0")
  httr2::local_mocked_responses(function(req) {
    httr2::response(
      status_code = 200,
      headers = list(`Content-Type` = "text/csv"),
      body = charToRaw("count\n2\n")
    )
  })
  result <- read_github_csv("data.csv", repo = "owner/repo", token = "", progress = FALSE)
  expect_equal(result$count, 2)
})
