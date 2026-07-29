# Package tests must never inherit billable provider credentials from the
# developer's shell. Tests that exercise provider configuration set local dummy
# values and inject request functions explicitly.
withr::local_envvar(
  c(
    OPENAI_API_KEY = "",
    OPENROUTER_API_KEY = "",
    METASALMON_LLM_API_KEY = "",
    CHAPI_API_KEY = ""
  ),
  .local_envir = testthat::teardown_env()
)
