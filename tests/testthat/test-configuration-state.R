test_that("BioPortal's missing-key warning leaves user options untouched", {
  withr::local_envvar(c(BIOPORTAL_APIKEY = ""))
  # Force a first call without prescribing how the package stores its private
  # warning state. The old implementation reads this caller-global flag.
  withr::local_options(metasalmon.warned_bioportal_missing = NULL)
  state <- get0(".ms_term_search_state", envir = asNamespace("metasalmon"))
  if (!is.null(state)) {
    old <- state$warned_bioportal_missing
    withr::defer(state$warned_bioportal_missing <- old)
    state$warned_bioportal_missing <- FALSE
  }
  before <- options()
  expect_warning(first <- .search_bioportal("salmon", "entity"), "API key missing")
  expect_identical(options(), before)
  expect_equal(nrow(first), 0L)
  expect_no_warning(second <- .search_bioportal("salmon", "entity"))
  expect_identical(second, first)
  expect_identical(options(), before)
})

test_that("session identifiers neither advance nor initialize the user's RNG", {
  withr::local_seed(738L)
  before <- .Random.seed
  ids <- vapply(seq_len(20L), function(i) .ms_chat_new_session_id(), character(1))
  expect_true(identical(.Random.seed, before))
  expect_length(unique(ids), length(ids))
  expect_true(all(grepl("^mscur-[0-9]{14}-[a-f0-9]{8}$", ids)))
  rm(".Random.seed", envir = .GlobalEnv)
  .ms_chat_new_session_id()
  expect_false(exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE))
})

test_that("load defaults preserve user options and backend timeout inheritance", {
  registry <- .ms_configuration_options()
  defaults <- lapply(registry, `[[`, "default")
  withr::local_options(stats::setNames(rep(list(NULL), length(defaults)), names(defaults)))
  options(metasalmon.term_search_parallel = FALSE,
          metasalmon.sdp_schema_source = "vendored")
  metasalmon:::.onLoad(NULL, "metasalmon")
  expect_false(getOption("metasalmon.term_search_parallel"))
  expect_identical(getOption("metasalmon.sdp_schema_source"), "vendored")
  expect_identical(getOption("metasalmon.validation_message_mode"), "default")
  expect_false(getOption("metasalmon.llm_deprecation_quiet"))
  # An unset global timeout must keep each backend's existing fallback.
  withr::local_envvar(c(METASALMON_TERM_SEARCH_TIMEOUT = "",
                       METASALMON_TERM_SEARCH_TIMEOUT_NVS = ""))
  expect_null(getOption("metasalmon.term_search_timeout"))
  expect_equal(.metasalmon_term_search_timeout(default = 30), 30)
  expect_equal(.metasalmon_term_search_timeout(source = "nvs", default = 60), 60)
  expect_null(getOption("dataone_token"))
  expect_null(getOption("dataone_test_token"))
})

test_that("an unset schema URL follows the package pin after a reload", {
  withr::local_options(metasalmon.sdp_schema_source = "auto",
                       metasalmon.sdp_schema_url = NULL,
                       metasalmon.sdp_schema_base_url = NULL)
  metasalmon:::.onLoad(NULL, "metasalmon")
  expect_null(getOption("metasalmon.sdp_schema_base_url"))

  # A later package version can advance its pin in the same R process. The
  # default URL must come from that version, not an option left by .onLoad().
  with_mocked_bindings(
    .ms_sdp_schema_pinned_base_url = function() "https://example.test/new-spec",
    {
      expect_identical(.ms_default_sdp_schema_base_url(),
                       "https://example.test/new-spec")
      expect_true(.ms_sdp_schema_options_are_default())
    }
  )

  options(metasalmon.sdp_schema_base_url = "https://example.test/caller-spec")
  expect_identical(.ms_default_sdp_schema_base_url(),
                   "https://example.test/caller-spec")
})

# Read installed function bodies, so the inventory guard also runs in R CMD
# check. Literal option reads plus the two dynamic DataONE token names are
# covered. Dynamic environment names use a documented source suffix/provider
# map; positive controls prove this walk reaches both instruments.
.configuration_calls <- function(node, fn, found = character()) {
  if (is.call(node)) {
    if (is.name(node[[1]]) && identical(as.character(node[[1]]), fn) &&
        length(node) >= 2L && is.character(node[[2]])) {
      found <- c(found, node[[2]])
    }
    args <- as.list(node)[-1L]
    for (i in seq_along(args)) {
      if (!identical(args[[i]], quote(expr = ))) {
        found <- .configuration_calls(args[[i]], fn, found)
      }
    }
  } else if (is.pairlist(node) || is.expression(node)) {
    for (i in seq_along(node)) {
      if (!identical(node[[i]], quote(expr = ))) {
        found <- .configuration_calls(node[[i]], fn, found)
      }
    }
  }
  found
}

test_that("configuration registry covers live option and environment reads", {
  ns <- asNamespace("metasalmon")
  functions <- Filter(is.function, mget(ls(ns, all.names = TRUE), envir = ns))
  option_reads <- unique(unlist(lapply(functions, function(fn) {
    .configuration_calls(body(fn), "getOption")
  })))
  option_reads <- option_reads[startsWith(option_reads, "metasalmon.")]
  expect_true("metasalmon.sdp_schema_source" %in% option_reads)
  expect_setequal(option_reads, names(.ms_configuration_options())[startsWith(
    names(.ms_configuration_options()), "metasalmon."
  )])
  token_options <- vapply(.ms_knb_environment_registry(), `[[`, character(1), "token_option")
  expect_true(all(token_options %in% names(.ms_configuration_options())))
  env_reads <- unique(unlist(lapply(functions, function(fn) {
    .configuration_calls(body(fn), "Sys.getenv")
  })))
  # TZ is preserved/restored while making an archive, not package configuration.
  # Retires when that archive path no longer changes/restores the process TZ.
  env_reads <- setdiff(env_reads, "TZ")
  expect_true("BIOPORTAL_APIKEY" %in% env_reads)
  expect_true(all(env_reads %in% names(.ms_configuration_envvars())))
  expect_true("METASALMON_TERM_SEARCH_TIMEOUT_<SOURCE>" %in% names(.ms_configuration_envvars()))
  # The provider-selected API key names are strings in the switch, rather than
  # literals at Sys.getenv(). Pin that dynamic map to the same registry.
  provider_text <- paste(deparse(body(.ms_llm_resolve_config)), collapse = " ")
  provider_keys <- c("OPENAI_API_KEY", "OPENROUTER_API_KEY", "CHAPI_API_KEY",
                     "METASALMON_LLM_API_KEY")
  expect_true(all(vapply(provider_keys, grepl, logical(1), x = provider_text, fixed = TRUE)))
  expect_true(all(provider_keys %in% names(.ms_configuration_envvars())))
})
