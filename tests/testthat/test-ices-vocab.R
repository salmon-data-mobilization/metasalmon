test_that("ices_code_types returns code types and supports text filtering", {
  fake <- data.frame(
    id = c(1, 2),
    guid = c("g1", "g2"),
    key = c("Gear", "TS_Sex"),
    description = c("Gear Type Codes", "Sex Codes (Fisheries)"),
    longDescription = c("", ""),
    modified = c("2025-01-01T00:00:00", "2025-01-01T00:00:00"),
    stringsAsFactors = FALSE
  )

  res_all <- with_mocked_bindings(
    .safe_json = function(url, headers = NULL, timeout_secs = 30) {
      if (grepl("/CodeType", url, fixed = TRUE)) return(fake)
      NULL
    },
    ices_code_types()
  )
  expect_s3_class(res_all, "tbl_df")
  expect_equal(nrow(res_all), 2)

  res_filtered <- with_mocked_bindings(
    .safe_json = function(url, headers = NULL, timeout_secs = 30) {
      if (grepl("/CodeType", url, fixed = TRUE)) return(fake)
      NULL
    },
    ices_find_code_types("gear")
  )
  expect_equal(nrow(res_filtered), 1)
  expect_equal(res_filtered$key[[1]], "Gear")
})

test_that("ices_codes returns codes with a detail URL and supports filtering", {
  fake <- data.frame(
    id = c(10, 11),
    guid = c("c1", "c2"),
    key = c("BOT", "BMT"),
    description = c("Bottom Trawl", "Beam trawl"),
    longDescription = c("", ""),
    modified = c("2025-01-01T00:00:00", "2025-01-01T00:00:00"),
    deprecated = c(FALSE, FALSE),
    stringsAsFactors = FALSE
  )

  res_all <- with_mocked_bindings(
    .safe_json = function(url, headers = NULL, timeout_secs = 30) {
      if (grepl("/Code/Gear", url, fixed = TRUE)) return(fake)
      NULL
    },
    ices_codes("Gear")
  )
  expect_s3_class(res_all, "tbl_df")
  expect_true(all(c("code_type", "url") %in% names(res_all)))
  expect_match(res_all$url[[1]], "CodeDetail/Gear/BOT", fixed = TRUE)

  res_filtered <- with_mocked_bindings(
    .safe_json = function(url, headers = NULL, timeout_secs = 30) {
      if (grepl("/Code/Gear", url, fixed = TRUE)) return(fake)
      NULL
    },
    ices_find_codes("beam", "Gear")
  )
  expect_equal(nrow(res_filtered), 1)
  expect_equal(res_filtered$key[[1]], "BMT")
})


# `.data$longDescription %||% ""` looked like a guard against a missing column
# and was not one: inside a data mask a missing column is an error, never NULL,
# so every ICES find helper aborted on a response without one of the three
# columns it searches (backlog #57). metasalmonpy's `ices_vocab.py` treats a
# missing column as empty text, and its tests use a response with no
# `longDescription` at all.
ices_response <- function(types, codes) {
  function(url, headers = NULL, timeout_secs = 30) {
    if (grepl("/CodeType", url, fixed = TRUE)) return(types)
    if (grepl("/Code/Gear", url, fixed = TRUE)) return(codes)
    NULL
  }
}

test_that("the ICES find helpers search the columns a response has", {
  respond <- ices_response(
    types = data.frame(
      key = c("Gear", "TS_Sex"),
      description = c("Gear Type Codes", "Sex Codes (Fisheries)"),
      stringsAsFactors = FALSE
    ),
    codes = data.frame(
      key = c("BOT", "BMT"),
      description = c("Bottom Trawl", "Beam trawl"),
      stringsAsFactors = FALSE
    )
  )

  found_types <- with_mocked_bindings(.safe_json = respond, ices_find_code_types("sex"))
  expect_identical(found_types$key, "TS_Sex")

  found_codes <- with_mocked_bindings(.safe_json = respond, ices_find_codes("beam", "Gear"))
  expect_identical(found_codes$key, "BMT")

  # A column holding NA reads as empty text too, as it did before.
  respond_na <- ices_response(
    types = data.frame(key = c("Gear", NA), description = c(NA, "Sex Codes"), stringsAsFactors = FALSE),
    codes = NULL
  )
  found_na <- with_mocked_bindings(.safe_json = respond_na, ices_find_code_types("sex"))
  expect_identical(found_na$description, "Sex Codes")
})

test_that("an ICES response with no rows gives an empty result rather than an error", {
  # The API answers an unknown code type with an empty array, and the helpers
  # hand that on as a tibble with no columns at all.
  respond <- ices_response(types = list(), codes = list())

  types <- with_mocked_bindings(.safe_json = respond, ices_find_code_types("gear"))
  expect_s3_class(types, "tbl_df")
  expect_identical(nrow(types), 0L)

  codes <- with_mocked_bindings(.safe_json = respond, ices_find_codes("beam", "NoSuchType"))
  expect_s3_class(codes, "tbl_df")
  expect_identical(nrow(codes), 0L)
})

test_that("ices_codes() gives an NA detail URL when a response has no key column", {
  respond <- ices_response(
    types = NULL,
    codes = data.frame(description = c("Bottom Trawl", "Beam trawl"), stringsAsFactors = FALSE)
  )

  res <- with_mocked_bindings(.safe_json = respond, ices_codes("Gear"))
  expect_identical(nrow(res), 2L)
  expect_identical(unique(res$code_type), "Gear")
  expect_true(all(is.na(res$url)))
})


# A request that failed and an answer with no rows used to reach the caller as
# the same empty tibble, with no warning, so an outage read as ICES saying it
# holds no such codes (hub item B-377). These tests mock the request itself,
# `httr::GET()`, before any helper is called, so `.safe_json()` classifies each
# failure as it would against the service and nothing opens a connection. Each
# mock records the URL it was asked for, and every test checks that record, so
# a mock that stopped intercepting would fail here rather than go to ICES.

# A refused connection, as curl reports one.
ices_refused <- function(url) {
  stop("Failed to connect to vocab.ices.dk port 443 after 2 ms: Connection refused", call. = FALSE)
}

# An HTTP answer with `status` and `body`, in the shape `httr::GET()` returns.
ices_answer <- function(status, body) {
  function(url) {
    structure(
      list(
        url = url,
        status_code = status,
        headers = list(`Content-Type` = "application/json"),
        content = charToRaw(body)
      ),
      class = "response"
    )
  }
}

# Each helper, and the one request it makes.
ices_helpers <- list(
  "ices_code_types()" = list(
    run = function() ices_code_types(),
    request = "https://vocab.ices.dk/services/api/CodeType"
  ),
  "ices_codes()" = list(
    run = function() ices_codes("Gear"),
    request = "https://vocab.ices.dk/services/api/Code/Gear"
  ),
  "ices_find_code_types()" = list(
    run = function() ices_find_code_types("gear"),
    request = "https://vocab.ices.dk/services/api/CodeType"
  ),
  "ices_find_codes()" = list(
    run = function() ices_find_codes("beam", "Gear"),
    request = "https://vocab.ices.dk/services/api/Code/Gear"
  )
)

# Runs one helper with `respond` standing in for the request, and returns what
# it returned, the warnings it gave, and the URLs it asked for.
ices_run <- function(helper, respond) {
  requested <- character()
  get <- function(url = NULL, ...) {
    requested <<- c(requested, url)
    respond(url)
  }
  result <- NULL
  warnings <- testthat::capture_warnings(
    result <- with_mocked_bindings(GET = get, .package = "httr", helper$run())
  )
  list(result = result, warnings = warnings, requested = requested)
}

for (name in names(ices_helpers)) {
  helper <- ices_helpers[[name]]

  test_that(paste(name, "warns, naming the request, when the connection is refused"), {
    run <- ices_run(helper, ices_refused)
    expect_identical(run$requested, helper$request)
    expect_length(run$warnings, 1L)
    expect_match(run$warnings, helper$request, fixed = TRUE)
    expect_match(run$warnings, "Connection\\s+refused")
    expect_s3_class(run$result, "tbl_df")
    expect_identical(nrow(run$result), 0L)
  })

  test_that(paste(name, "warns, naming the request, when ICES answers HTTP 503"), {
    run <- ices_run(helper, ices_answer(503L, "<html>Service Unavailable</html>"))
    expect_identical(run$requested, helper$request)
    expect_length(run$warnings, 1L)
    expect_match(run$warnings, helper$request, fixed = TRUE)
    expect_match(run$warnings, "HTTP\\s+503")
    expect_s3_class(run$result, "tbl_df")
    expect_identical(nrow(run$result), 0L)
  })

  test_that(paste(name, "gives the empty result with no warning when ICES answers []"), {
    run <- ices_run(helper, ices_answer(200L, "[]"))
    expect_identical(run$requested, helper$request)
    expect_length(run$warnings, 0L)
    expect_s3_class(run$result, "tbl_df")
    expect_identical(nrow(run$result), 0L)
  })
}

test_that("the ICES failure warning redacts a secret in the request and in the failure", {
  # The ICES API takes no key, so the request is given one through the base
  # URL: what is pinned is that whatever the request carries is redacted.
  leaky_refusal <- function(url) {
    stop(
      "Failed to connect to proxy.example port 3128: Proxy-Authorization: Basic dXNlcjpzM2NyM3Q=",
      call. = FALSE
    )
  }
  secret_base <- "https://vocab.ices.dk/services/api?api_key=s3cr3t-in-the-request"

  for (respond in list(leaky_refusal, ices_answer(503L, "Service Unavailable"))) {
    run <- with_mocked_bindings(
      .ices_base_url = secret_base,
      ices_run(ices_helpers[["ices_codes()"]], respond)
    )
    expect_identical(run$requested, paste0(secret_base, "/Code/Gear"))
    expect_length(run$warnings, 1L)
    expect_match(run$warnings, "https://vocab.ices.dk/services/api?api_key=[REDACTED]", fixed = TRUE)
    expect_no_match(run$warnings, "s3cr3t-in-the-request", fixed = TRUE)
    expect_no_match(run$warnings, "dXNlcjpzM2NyM3Q=", fixed = TRUE)
  }
})
