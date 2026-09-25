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
