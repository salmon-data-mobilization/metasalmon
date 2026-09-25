# The in-package model call is deprecated (S16 step 1, hub item B-326) and
# warns once per top-level call. This suite-wide switch keeps every existing
# test byte-identical: the tests that assert the warning switch it off
# locally with `withr::local_options(metasalmon.llm_deprecation_quiet = FALSE)`.
# Retires with the removal release, when there is no deprecated call left to
# warn about.
withr::local_options(
  list(metasalmon.llm_deprecation_quiet = TRUE),
  .local_envir = testthat::teardown_env()
)
