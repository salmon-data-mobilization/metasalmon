# One chat-completions request builder (backlog #3, hub item B-3).
#
# metasalmon reaches an LLM provider on two paths: semantic review, whose
# default request function is `.ms_llm_chat_json_request()`, and chat
# decomposition, whose default is `.ms_chat_http_request()`. Each used to build
# its own httr2 request -- endpoint, authorization, content type, user agent,
# timeout and OpenRouter's attribution headers, written out twice -- with
# nothing to stop the two copies drifting apart. Both now go through
# `.ms_llm_chat_request()`.
#
# Pinned here:
#   * both default request functions are served by that one builder;
#   * both put the same request on the wire, apart from the body;
#   * each keeps its own return shape, because the review adapter's
#     two-shape normalizer (`.ms_llm_review_response_data()`) serves both;
#   * no other function in the namespace builds a chat-completions request.
#
# Deliberately NOT pinned: the request bodies. They still differ -- chat
# decomposition sends a fixed temperature and never consults
# `.ms_llm_build_chat_request_body()` -- and removing that difference is hub
# item B-128. Asserting it here would pin the defect B-128 exists to fix.

# THE list of functions allowed to construct an OpenAI-compatible
# `/chat/completions` request. It has one entry on purpose. A new caller routes
# through `.ms_llm_chat_request()` rather than joining this list; a provider that
# genuinely needs a different request (a chat API that is not OpenAI-compatible,
# say) is added here with its reason beside it, so the second builder is a
# decision rather than a drift.
#
# RETIREMENT CONDITION: the guard below retires when metasalmon stops building
# chat requests itself -- transport handed to a client library, or to an engine
# that owns it (whether chat decomposition should converge on one is hub item
# B-31). Until then it is what keeps backlog #3 fixed.
#
# LIMITATIONS, stated plainly: it walks the installed namespace (so it runs under
# `R CMD check`, where R/ holds no source) and matches the endpoint path as a
# string constant. A builder that assembled the path from pieces would evade it,
# and `scripts/theme-a-benchmark.R`, which builds its own request for the
# benchmark's own reasons, is outside the namespace and therefore outside it.
chat_request_builders <- ".ms_llm_chat_request"

# `httr2::local_mocked_responses()`, which answers a request without a network,
# arrived in httr2 1.0.0; the `httr2::req_get_*()` accessors that read a request
# back arrived in 1.2.0. DESCRIPTION pins neither, so a test needing one skips on
# an older install rather than erroring. RETIREMENT CONDITION: delete this helper
# and its calls once DESCRIPTION's Imports requires httr2 (>= 1.2.0).
skip_if_httr2_older_than <- function(version) {
  testthat::skip_if_not_installed("httr2", version)
}

chat_test_messages <- list(
  list(role = "system", content = "Return JSON only."),
  list(role = "user", content = "Assess the shortlist.")
)

# One config per provider the package resolves, carrying every field the
# request path reads. Built by hand rather than through
# `.ms_llm_resolve_config()` so that no environment variable can change them.
chat_test_configs <- list(
  openai = list(
    provider = "openai",
    model = "gpt-4.1-mini",
    api_key = "sk-openai-test",
    base_url = "https://api.openai.com/v1",
    timeout_seconds = 60,
    reasoning_effort = NA_character_
  ),
  openrouter = list(
    provider = "openrouter",
    model = "openai/gpt-5.4-mini",
    api_key = "sk-or-test",
    base_url = "https://openrouter.ai/api/v1",
    timeout_seconds = 90,
    reasoning_effort = NA_character_
  ),
  openai_compatible = list(
    provider = "openai_compatible",
    model = "local-model",
    api_key = "local-test",
    base_url = "http://localhost:8080/v1",
    timeout_seconds = 30,
    reasoning_effort = NA_character_
  ),
  chapi = list(
    provider = "chapi",
    model = "ollama2.mistral:7b",
    api_key = "chapi-test",
    base_url = "https://chapi.example.invalid/api",
    timeout_seconds = 120,
    reasoning_effort = NA_character_
  )
)

# A provider's 200 reply carrying `content` as the assistant message.
chat_test_response <- function(content) {
  httr2::response(
    status_code = 200L,
    headers = list(`Content-Type` = "application/json"),
    body = charToRaw(as.character(jsonlite::toJSON(
      list(
        id = "chatcmpl-test",
        model = "test-model",
        choices = list(list(
          index = 0L,
          message = list(role = "assistant", content = content)
        ))
      ),
      auto_unbox = TRUE
    )))
  )
}

# Calls both default request functions under one mocked provider and returns
# what each sent and what each returned. Nothing leaves the machine: the mock
# answers every request.
chat_test_round_trip <- function(config, content = '{"decision":"review"}') {
  sent <- list()
  httr2::local_mocked_responses(function(req) {
    sent[[length(sent) + 1L]] <<- req
    chat_test_response(content)
  })

  semantic <- .ms_llm_chat_json_request(chat_test_messages, config)
  chat <- .ms_chat_http_request(chat_test_messages, config)

  list(sent = sent, semantic = semantic, chat = chat)
}

test_that("both default request functions are served by the one chat request builder", {
  skip_if_httr2_older_than("1.0.0")

  builder <- .ms_llm_chat_request
  bodies <- list()
  local_mocked_bindings(.ms_llm_chat_request = function(config, body) {
    bodies[[length(bodies) + 1L]] <<- body
    builder(config, body)
  })
  httr2::local_mocked_responses(function(req) chat_test_response('{"decision":"review"}'))

  config <- chat_test_configs$openai
  .ms_llm_chat_json_request(chat_test_messages, config)
  .ms_chat_http_request(chat_test_messages, config)

  expect_length(bodies, 2L)
  # Semantic review's body is the body builder's, unchanged.
  expect_identical(bodies[[1]], .ms_llm_build_chat_request_body(chat_test_messages, config))
  # Chat decomposition's body is its own (see the header); only what both
  # bodies must carry is asserted.
  expect_identical(bodies[[2]]$model, config$model)
  expect_identical(bodies[[2]]$messages, chat_test_messages)
})

test_that("both chat paths put the same request on the wire apart from the body", {
  skip_if_httr2_older_than("1.2.0")

  for (provider in names(chat_test_configs)) {
    config <- chat_test_configs[[provider]]
    trip <- chat_test_round_trip(config)
    expect_length(trip$sent, 2L)
    semantic <- trip$sent[[1]]
    chat <- trip$sent[[2]]

    expect_identical(httr2::req_get_url(semantic), paste0(config$base_url, "/chat/completions"), info = provider)
    expect_identical(httr2::req_get_url(chat), httr2::req_get_url(semantic), info = provider)
    expect_identical(httr2::req_get_method(semantic), "POST", info = provider)
    expect_identical(httr2::req_get_method(chat), "POST", info = provider)

    headers <- httr2::req_get_headers(semantic, "reveal")
    expect_identical(httr2::req_get_headers(chat, "reveal"), headers, info = provider)
    expect_identical(headers$Authorization, paste("Bearer", config$api_key), info = provider)
    expect_identical(headers$`Content-Type`, "application/json", info = provider)
    if (identical(provider, "openrouter")) {
      expect_identical(headers$`HTTP-Referer`, "https://salmon-data-mobilization.github.io/metasalmon/", info = provider)
      expect_identical(headers$`X-Title`, "metasalmon", info = provider)
    } else {
      expect_false(any(c("HTTP-Referer", "X-Title") %in% names(headers)), info = provider)
    }

    # httr2 has no accessor for curl options, so `$options` is read directly.
    # The two values below are the positive control: if that field ever moved,
    # comparing two absent fields would pass without having checked anything.
    expect_identical(chat$options, semantic$options, info = provider)
    expect_identical(semantic$options$useragent, ms_user_agent(), info = provider)
    expect_equal(semantic$options$timeout_ms, config$timeout_seconds * 1000, info = provider)

    expect_identical(httr2::req_get_body_type(semantic), "json", info = provider)
    expect_identical(httr2::req_get_body_type(chat), "json", info = provider)
  }
})

test_that("semantic review keeps its bare, strict return shape", {
  skip_if_httr2_older_than("1.0.0")

  config <- chat_test_configs$openrouter
  trip <- chat_test_round_trip(
    config,
    content = "```json\n{\"decision\":\"review\",\"confidence\":0.5}\n```"
  )

  # The fenced reply is cleaned and parsed, and the parsed object is returned
  # as it is: no wrapper.
  expect_identical(trip$semantic, list(decision = "review", confidence = 0.5))

  httr2::local_mocked_responses(function(req) chat_test_response("not JSON at all"))
  expect_error(.ms_llm_chat_json_request(chat_test_messages, config))
})

test_that("chat decomposition keeps its wrapped, lenient return shape", {
  skip_if_httr2_older_than("1.0.0")

  config <- chat_test_configs$openrouter
  fenced <- "```json\n{\"decision\":\"review\",\"confidence\":0.5}\n```"
  trip <- chat_test_round_trip(config, content = fenced)

  expect_named(trip$chat, c("content", "data", "raw"))
  # `content` is the provider's text before cleaning; `data` is what it parsed to.
  expect_identical(trip$chat$content, fenced)
  expect_identical(trip$chat$data, list(decision = "review", confidence = 0.5))
  expect_identical(trip$chat$raw$id, "chatcmpl-test")

  # Content that is not JSON leaves `data` NULL rather than aborting; the review
  # adapter's normalizer is what reports it.
  httr2::local_mocked_responses(function(req) chat_test_response("not JSON at all"))
  unparsed <- .ms_chat_http_request(chat_test_messages, config)
  expect_null(unparsed$data)
  expect_identical(unparsed$content, "not JSON at all")
})

test_that("no function but the shared builder constructs a chat-completions request", {
  ns <- asNamespace("metasalmon")
  builds_chat_request <- function(name) {
    fn <- get(name, envir = ns)
    is.function(fn) && !is.primitive(fn) &&
      any(grepl("/chat/completions", deparse(body(fn)), fixed = TRUE))
  }

  found <- Filter(builds_chat_request, ls(ns, all.names = TRUE))

  expect_identical(sort(found, method = "radix"), sort(chat_request_builders, method = "radix"))
})
