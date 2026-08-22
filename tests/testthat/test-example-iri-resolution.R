# Every IRI shipped in the bundled example metadata must resolve.
# Backlog #99: two plausible-looking placeholders under
# `https://w3id.org/example/salmon#` -- a namespace nobody owns -- returned
# HTTP 404 while passing every offline check the package has. `REVIEW:` is
# this package's marker for an unfinished IRI and strict validation rejects
# it; a fake-but-well-formed IRI sails through, which is exactly why it needs
# a network-gated gate of its own.

.example_metadata_iris <- function() {
  files <- c(
    "column_dictionary.csv",
    "codes.csv",
    "tables.csv",
    "nuseds-fraser-coho-2023-2024-column_dictionary.csv"
  )
  iris <- character()
  for (file in files) {
    df <- readr::read_csv(
      example_extdata_path(file),
      show_col_types = FALSE,
      col_types = readr::cols(.default = readr::col_character())
    )
    for (col in grep("_iri$", names(df), value = TRUE)) {
      values <- df[[col]]
      iris <- c(iris, values[!is.na(values) & nzchar(trimws(values))])
    }
  }
  sort(unique(iris), method = "radix")
}

test_that("every IRI in the shipped example metadata resolves", {
  testthat::skip_if_offline("w3id.org")
  reachable <- tryCatch(
    {
      resp <- httr2::request("https://w3id.org/smn/") |>
        httr2::req_method("HEAD") |>
        httr2::req_timeout(5) |>
        httr2::req_perform()
      httr2::resp_status(resp) < 500
    },
    error = function(...) FALSE
  )
  testthat::skip_if_not(reachable, "w3id.org is not reachable from this environment")

  iris <- .example_metadata_iris()
  expect_true(length(iris) > 0L)

  # A hash IRI resolves via its document, so the fragment is stripped before
  # the request; each unique document is fetched once.
  docs <- unique(sub("#.*$", "", iris))
  statuses <- vapply(docs, function(doc) {
    tryCatch(
      {
        resp <- httr2::request(doc) |>
          httr2::req_timeout(30) |>
          httr2::req_perform()
        httr2::resp_status(resp)
      },
      error = function(e) {
        # httr2 raises on 4xx/5xx; report the class of failure as a status.
        status <- tryCatch(httr2::resp_status(e$resp), error = function(...) NA_integer_)
        if (is.na(status)) 599L else status
      }
    )
  }, integer(1))

  failing <- docs[statuses >= 400L]
  expect_identical(
    failing,
    character(0),
    label = paste(
      "IRIs whose document does not resolve:",
      paste(sprintf("%s (%d)", failing, statuses[statuses >= 400L]), collapse = ", ")
    )
  )
})
