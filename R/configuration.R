# A single inventory owns defaults and the help topic's rendered entries.
# NULL means inherit/no value, not a global value installed by .onLoad(): a
# timeout has backend-specific fallbacks, and credentials are never supplied.
.ms_configuration_option <- function(default, label, description) {
  list(default = default, label = label, description = description)
}

.ms_configuration_options <- function() {
  list(
    metasalmon.sdp_schema_source = .ms_configuration_option(
      "auto", '"auto"',
      'SDP schema source: "auto" tries the pinned remote release then the vendored copy; "remote" requires remote loading; "vendored" stays offline.'
    ),
    metasalmon.sdp_schema_base_url = .ms_configuration_option(
      NULL, "NULL (the pinned SDP release URL at call time)",
      "Base URL of a selected SDP schema bundle. When unset, each call resolves the package's current schema-release pin."
    ),
    metasalmon.sdp_schema_url = .ms_configuration_option(
      NULL, "NULL",
      "Legacy schema URL override. When nonempty, its schema/sdp.schema.yaml suffix is removed to obtain the bundle base URL; it takes precedence over sdp_schema_base_url."
    ),
    metasalmon.term_search_timeout = .ms_configuration_option(
      NULL, "NULL (inherit backend timeout)",
      "Positive timeout in seconds. Source-specific environment timeout overrides the global environment timeout, which overrides this option. Unset/invalid falls back to the backend's 30 or 60 seconds."
    ),
    metasalmon.term_search_parallel = .ms_configuration_option(
      TRUE, "TRUE",
      "Enable parallel term retrieval. METASALMON_TERM_SEARCH_PARALLEL takes precedence."
    ),
    metasalmon.llm_deprecation_quiet = .ms_configuration_option(
      FALSE, "FALSE",
      "Suppress the in-package LLM deprecation warning. It does not enable a model call. The deprecated provider path is removed in 0.7.0."
    ),
    metasalmon.validation_message_mode = .ms_configuration_option(
      "default", '"default"',
      'Internal validation message mode: "default" or "review_ready". create_sdp temporarily sets and restores it; ordinarily leave it unchanged.'
    ),
    metasalmon.validation_semantics_seeded = .ms_configuration_option(
      FALSE, "FALSE",
      "Internal validation message context. create_sdp temporarily sets and restores it; ordinarily leave it unchanged."
    ),
    metasalmon.knb_adapter = .ms_configuration_option(
      NULL, "NULL",
      "Internal adapter injection hook for KNB tests. It does not change the closed publication-environment registry."
    ),
    dataone_token = .ms_configuration_option(
      NULL, "NULL",
      "Process-local production DataONE JWT. Set only when making an explicitly requested production publication; never persisted or supplied by package loading."
    ),
    dataone_test_token = .ms_configuration_option(
      NULL, "NULL",
      "Process-local DataONE test JWT, separate from dataone_token. No credential fallback between test and production."
    )
  )
}

.ms_configuration_envvars <- function() {
  c(
    BIOPORTAL_APIKEY = "BioPortal API key. Missing keys produce one warning per loaded package namespace and an empty BioPortal result.",
    METASALMON_CACHE = "Enable the process-local term-result cache with 1, true or yes; unset disables it.",
    METASALMON_EMBEDDING_RERANK = "Enable embedding reranking with 1, true or yes; unset disables it.",
    METASALMON_EMBEDDING_WEIGHT = "Embedding score weight; defaults to 1. Invalid/nonfinite values fall back to 1.",
    METASALMON_DEBUG = "Enable embedding diagnostics with 1 or true; unset disables them.",
    METASALMON_TERM_SEARCH_TIMEOUT = "Global positive retrieval timeout in seconds; overrides the option but yields to the source-specific variable.",
    `METASALMON_TERM_SEARCH_TIMEOUT_<SOURCE>` = "Positive retrieval timeout for an uppercase source name, such as NVS, ZOOMA or QUDT; highest timeout precedence.",
    METASALMON_TERM_SEARCH_PARALLEL = "Parallel override: 1/true/yes/on enables; 0/false/no/off disables; unset/unrecognized falls back to the option.",
    METASALMON_TERM_SEARCH_WORKERS = "Positive worker-count override; otherwise worker count derives from source count and available cores.",
    OPENAI_API_KEY = "OpenAI credential for the deprecated in-package provider path; only read on explicit LLM assessment.",
    OPENROUTER_API_KEY = "OpenRouter credential for the deprecated in-package provider path; only read on explicit LLM assessment.",
    CHAPI_API_KEY = "Chapi credential for the deprecated in-package provider path; only read on explicit LLM assessment.",
    METASALMON_LLM_API_KEY = "OpenAI-compatible credential and fallback for provider-specific keys. Explicit llm_api_key takes precedence.",
    METASALMON_LLM_MODEL = "Model fallback for the deprecated provider path. Explicit llm_model takes precedence; Chapi checks CHAPI_MODEL first.",
    CHAPI_MODEL = "Chapi model fallback before METASALMON_LLM_MODEL; otherwise the Chapi model default applies.",
    METASALMON_LLM_BASE_URL = "Endpoint fallback for the deprecated provider path. Explicit llm_base_url takes precedence; Chapi checks CHAPI_BASE_URL first.",
    CHAPI_BASE_URL = "Chapi endpoint fallback before METASALMON_LLM_BASE_URL; otherwise the Chapi endpoint default applies.",
    METASALMON_LLM_REASONING_EFFORT = "Reasoning-effort fallback for the deprecated provider path; explicit llm_reasoning_effort takes precedence."
  )
}

.ms_initialize_configuration <- function() {
  defaults <- lapply(.ms_configuration_options(), `[[`, "default")
  # Preserve settings the user installed before loading the package, including
  # FALSE. Skip NULL rather than overriding each backend's inheritance rule.
  missing <- setdiff(names(defaults), names(options()))
  concrete <- missing[!vapply(defaults[missing], is.null, logical(1))]
  if (length(concrete)) options(defaults[concrete])
  invisible(NULL)
}

.ms_configuration_rd <- function() {
  options_registry <- .ms_configuration_options()
  option_entries <- vapply(names(options_registry), function(name) {
    entry <- options_registry[[name]]
    paste0("\\item{\\code{", name, "}}{Default: \\code{", entry$label,
           "}. ", entry$description, "}")
  }, character(1))
  env_registry <- .ms_configuration_envvars()
  env_entries <- vapply(names(env_registry), function(name) {
    paste0("\\item{\\code{", name, "}}{", env_registry[[name]], "}")
  }, character(1))
  c("\\section{Options}{\\describe{", option_entries, "}}",
    "\\section{Environment variables}{\\describe{", env_entries, "}}")
}

#' Configure MetaSalmon
#'
#' Package options are initialized on loading only when the user has not set a
#' value. Credentials and inheritance settings remain unset. Environment
#' variables are read at call time and are never set by package loading.
#'
#' The inventories below are generated from the same registry that owns the
#' load defaults. The in-package LLM provider path is deprecated and removed in
#' 0.7.0; its environment variables do not by themselves request a model call.
#' Prefer the external semantic review packet workflow for new review work.
#'
#' @seealso [ms_setup_github()] for the GitHub credential helper,
#'   [find_terms()] for retrieval, [create_sdp()] for schema-backed creation.
#' @name metasalmon_configuration
#' @aliases metasalmon-options
#' @evalRd .ms_configuration_rd()
#' @examples
#' old <- options(metasalmon.term_search_parallel = FALSE)
#' getOption("metasalmon.term_search_parallel")
#' options(old)
NULL
