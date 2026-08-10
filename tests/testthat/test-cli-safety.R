test_that(".ms_cli_escape output is inert under cli interpolation", {
  # `format_inline()` is the same glue machinery cli uses for condition
  # messages, without bullets, wrapping, or glyphs — so this asserts the whole
  # contract without coupling to cli's rendering.
  cases <- c(
    "a{b}c",
    "{",
    "}",
    "{{",
    "}}",
    "{R.version.string}",
    "{.file x}",
    "col_{n",
    "rate{pct",
    "100% {x}",
    "é{1}",
    "plain text"
  )

  for (case in cases) {
    expect_identical(cli::format_inline(.ms_cli_escape(case)), case)
  }
})

test_that(".ms_cli_escape normalises NA and preserves length", {
  expect_identical(.ms_cli_escape(c("a{", NA_character_)), c("a{{", ""))
  expect_identical(.ms_cli_escape(character()), character())
})

test_that(".ms_cli_bullets keeps one escaped bullet per element", {
  bullets <- .ms_cli_bullets(c("a{1}", "b{2}"), "x")

  expect_identical(unname(bullets), c("a{{1}}", "b{{2}}"))
  expect_identical(names(bullets), c("x", "x"))
  expect_identical(.ms_cli_bullets(character()), character())

  # A single "{preview}" element would collapse these into one comma-joined
  # bullet, which is why escaping is used instead of value interpolation.
  msg <- tryCatch(
    cli::cli_abort(c("Header", .ms_cli_bullets(c("first{1}", "second{2}"), "x"))),
    error = conditionMessage
  )
  expect_true(grepl("first{1}", msg, fixed = TRUE))
  expect_true(grepl("second{2}", msg, fixed = TRUE))
})

test_that(".ms_redact_secrets removes common credential shapes", {
  # Inside a header the whole value goes, not just the token after the scheme.
  expect_identical(
    .ms_redact_secrets("Authorization: Bearer abc123XYZ_-token"),
    "Authorization=[REDACTED]"
  )
  expect_match(.ms_redact_secrets("key sk-abcdefghijklmnopqrstuvwxyz012345"), "[REDACTED KEY]", fixed = TRUE)
  expect_match(.ms_redact_secrets("x-api-key: supersecretvalue"), "[REDACTED]", fixed = TRUE)
  expect_match(
    .ms_redact_secrets("token eyJhbGciOi.eyJzdWIiOi.SflKxwRJSM"),
    "[REDACTED JWT]",
    fixed = TRUE
  )
  # Ordinary validation text must survive untouched: redacting a column name
  # would hide the value a user needs in order to fix it.
  expect_identical(
    .ms_redact_secrets("Row 3 field term_iri uses REVIEW:spawner_count"),
    "Row 3 field term_iri uses REVIEW:spawner_count"
  )
})

test_that("a provider error containing braces is inert in the fallback warning", {
  # The canary is long, distinctive, and always present in base R, so it cannot
  # collide with real message content.
  hostile <- "provider failed: {R.version.string}"

  assessments <- tibble::tibble(
    llm_error = c(hostile, hostile),
    llm_decision = c(NA_character_, NA_character_)
  )

  msg <- tryCatch(
    metasalmon:::.ms_llm_abort_if_provider_wide_failure(
      assessments,
      config = list(provider = "openai", model = "test-model"),
      deterministic_suggestions = tibble::tibble()
    ),
    condition = conditionMessage
  )

  expect_true(grepl("{R.version.string}", msg, fixed = TRUE))
  expect_false(grepl(R.version.string, msg, fixed = TRUE))
})

test_that("a column name containing an unbalanced brace does not crash validation", {
  # Before escaping, cli parsed the message template and this raised
  # "Expecting '}'" instead of the intended review message.
  dict <- test_dictionary(
    dataset_id = "brace-1",
    table_id = "obs",
    column_name = "rate{pct",
    column_label = "rate{pct",
    column_role = "measurement",
    value_type = "number",
    term_iri = "REVIEW:rate"
  )

  msg <- tryCatch(
    validate_dictionary(dict, require_iris = TRUE),
    condition = conditionMessage
  )

  expect_false(grepl("Expecting '}'", msg, fixed = TRUE))
  expect_true(grepl("rate{pct", msg, fixed = TRUE))
})

test_that("credential headers are redacted regardless of separator spacing", {
  # A space after the colon is the conventional header form; an anchored `[=:]`
  # missed it, leaving the whole secret in captured provider errors.
  expect_identical(
    .ms_redact_secrets("Authorization: Basic dXNlcjpwYXNzd29yZA=="),
    "Authorization=[REDACTED]"
  )
  expect_identical(
    .ms_redact_secrets("Cookie: session=abc123secret; other=2"),
    "Cookie=[REDACTED]"
  )
  expect_identical(
    .ms_redact_secrets("x-api-key: supersecretvalue"),
    "x-api-key=[REDACTED]"
  )
  # No-space form still works, and is not double-substituted into gibberish.
  expect_identical(
    .ms_redact_secrets("authorization:Bearer tok123"),
    "authorization=[REDACTED]"
  )
  # A bare scheme outside a header is still caught.
  expect_match(.ms_redact_secrets("got Bearer abc123XYZ_-tok"), "Bearer [REDACTED]", fixed = TRUE)
  # Ordinary validation text is untouched.
  expect_identical(
    .ms_redact_secrets("Row 3 field term_iri uses REVIEW:spawner_count"),
    "Row 3 field term_iri uses REVIEW:spawner_count"
  )
})
