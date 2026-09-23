# `review_metadata()` documents that it never contacts a network, and the four
# `set_sdp_*()` setters whose calls it prints are local edits with no reason to.
# Until hub item B-175 both were false on a fresh session under the shipped
# default options: all five read the SDP schema through `.ms_load_sdp_schema()`,
# whose default "auto" source fetches eight documents from the pinned remote
# before it falls back to the bundled copy. Measured 2026-09-23: eight requests
# to raw.githubusercontent.com from each of the five, called cold (the item's
# 2026-09-15 measurement had found the same eight for two of them).
#
# THE SUITE PIN IS UNDONE HERE, ON PURPOSE. `helper-validation.R` sets
# `metasalmon.sdp_schema_source = "vendored"` for the whole run, and
# `pkgload::load_all()` sources that helper too, which is why neither the suite
# nor a dev console could see the defect. `local_shipped_schema_defaults()`
# clears the option, empties every schema cache slot so each call is cold, and
# restores both afterwards.
#
# EVERY SENTINEL HERE COUNTS; NONE OF THEM THROWS. `.ms_load_sdp_schema()` wraps
# the remote fetch in `tryCatch(error = )` and falls back to the bundled copy,
# so a sentinel that signals an error is swallowed and the call returns
# normally whether or not the network was reached. Measured: a `stop()`ing mock
# was reached and the scan still returned every row. So each sentinel records
# its firing outside the call, and the positive controls at the end of the first
# test show the trap and show each instrument hearing, because silence from an
# instrument means nothing until it has been shown to hear.
#
# TWO LAYERS, because the first guards only today's code path.
#   1. A counter on `.ms_fetch_remote_sdp_schema()`, the package's own fetch.
#      Deterministic and free, and blind to a request that goes another way.
#   2. A local socket named as every HTTP(S) proxy, on which nothing is ever
#      read. libcurl sends each request to the proxy its environment names, and
#      base R's url() and download.file() read the same variables: measured
#      2026-09-23 under R 4.3.3, httr2 (https and http), curl, httr, url() and
#      download.file() (libcurl and default method) all reached the listener,
#      and a no-op did not. So a move to another HTTP client, or a new network
#      read elsewhere on this path, still lands here. It does NOT see a raw
#      socketConnection() or a DNS lookup -- measured the same day, both went
#      straight past it -- and a client given an explicit proxy would bypass it
#      too: this is not a block on the socket API, which R does not expose to a
#      test. `serverSocket()` takes no bind address, so the listener is on every
#      interface for the length of one test.
#
# Retires when: never, while `review_metadata()` documents that it does not
# contact a network. An offline promise with no test that fails when the
# network is reached is a comment, not a contract.

offline_fixture_package <- function(env = parent.frame()) {
  path <- file.path(withr::local_tempdir(.local_envir = env), "offline-demo")
  # Built under an explicit vendored pin: `create_sdp()` has no offline
  # contract and is not what is under test, so it must not depend on the suite
  # helper having run.
  withr::with_options(
    list(metasalmon.sdp_schema_source = "vendored"),
    suppressMessages(create_sdp(
      list(spawners = data.frame(
        stream_name = c("Bear Creek", "Elk River"),
        spawner_count = c(120L, 340L),
        stringsAsFactors = FALSE
      )),
      path = path,
      dataset_id = "demo-1",
      seed_semantics = FALSE,
      check_updates = FALSE,
      overwrite = TRUE
    ))
  )
}

clear_schema_caches <- function() {
  rm(list = ls(.ms_schema_env, all.names = TRUE), envir = .ms_schema_env)
}

# The options a user gets, on a cold cache, for the rest of the calling test.
local_shipped_schema_defaults <- function(env = parent.frame()) {
  saved <- as.list(.ms_schema_env, all.names = TRUE)
  withr::defer(
    {
      clear_schema_caches()
      list2env(saved, envir = .ms_schema_env)
    },
    envir = env
  )
  clear_schema_caches()
  withr::local_options(
    list(
      metasalmon.sdp_schema_source = NULL,
      metasalmon.sdp_schema_base_url = NULL,
      metasalmon.sdp_schema_url = NULL
    ),
    .local_envir = env
  )
  invisible()
}

# Name a local socket as every HTTP(S) proxy for the rest of the calling test.
# Returns a function that counts, and drains, the connections that reached it.
local_proxy_listener <- function(env = parent.frame()) {
  # Twenty distinct candidates drawn at once: under a preserved seed, a draw per
  # attempt would return the same port every time.
  candidates <- 49152L + withr::with_preserve_seed(sample.int(16000L, 20L))
  listener <- NULL
  for (port in candidates) {
    listener <- tryCatch(serverSocket(port), error = function(e) NULL)
    if (!is.null(listener)) {
      break
    }
  }
  if (is.null(listener)) {
    stop("could not open a local listening socket on any of 20 ports")
  }
  withr::defer(close(listener), envir = env)

  proxy <- sprintf("http://127.0.0.1:%d", port)
  withr::local_envvar(
    c(
      http_proxy = proxy, HTTP_PROXY = proxy,
      https_proxy = proxy, HTTPS_PROXY = proxy,
      all_proxy = proxy, ALL_PROXY = proxy,
      no_proxy = NA, NO_PROXY = NA
    ),
    .local_envir = env
  )

  function() {
    reached <- 0L
    while (isTRUE(socketSelect(list(listener), timeout = 0))) {
      close(socketAccept(listener))
      reached <- reached + 1L
    }
    reached
  }
}

test_that("review_metadata() and the four setters make no network request", {
  pkg <- offline_fixture_package()
  real_fetch <- .ms_fetch_remote_sdp_schema

  local_shipped_schema_defaults()
  expect_identical(getOption("metasalmon.sdp_schema_source", "auto"), "auto")

  fetches <- 0L
  local_mocked_bindings(.ms_fetch_remote_sdp_schema = function(...) {
    fetches <<- fetches + 1L
    stop("B-175 sentinel: the remote SDP schema was fetched")
  })
  connections <- local_proxy_listener()

  # Each called first in a cold session, because a warm cache hides a fetch:
  # whichever call ran first would pay for the rest.
  calls <- list(
    # Printing is part of the call at a console, so it is part of the promise.
    review_metadata = function() print(review_metadata(pkg)),
    set_sdp_dataset = function() {
      set_sdp_dataset(pkg, creator = "Offline Guard", quiet = TRUE)
    },
    set_sdp_table = function() {
      set_sdp_table(pkg, "spawners", table_label = "Spawners", quiet = TRUE)
    },
    set_sdp_column = function() {
      set_sdp_column(
        pkg, "spawner_count",
        table = "spawners", column_description = "Spawners counted.", quiet = TRUE
      )
    },
    set_sdp_code = function() {
      set_sdp_code(
        pkg, "stream_name", "Bear Creek",
        table = "spawners", code_label = "Bear Creek", quiet = TRUE
      )
    }
  )
  fetched <- integer()
  connected <- integer()
  for (name in names(calls)) {
    clear_schema_caches()
    fetches <- 0L
    output <- utils::capture.output(calls[[name]]())
    fetched[[name]] <- fetches
    connected[[name]] <- connections()
  }
  none <- stats::setNames(integer(length(calls)), names(calls))
  expect_identical(fetched, none)
  expect_identical(connected, none)

  # The silence is from calls that did their work, not from calls that failed.
  meta <- function(file_name) {
    readr::read_csv(
      file.path(pkg, "metadata", file_name),
      col_types = readr::cols(.default = readr::col_character()),
      na = ""
    )
  }
  expect_identical(meta("dataset.csv")$creator, "Offline Guard")
  expect_identical(meta("tables.csv")$table_label, "Spawners")
  dictionary <- meta("column_dictionary.csv")
  expect_identical(
    dictionary$column_description[dictionary$column_name == "spawner_count"],
    "Spawners counted."
  )
  codes <- meta("codes.csv")
  expect_identical(codes$code_label[codes$code_value == "Bear Creek"], "Bear Creek")

  # POSITIVE CONTROL, LAYER 1, and the trap it exists for: the loader on the
  # default source reaches the fetch, and the stop() inside the sentinel goes
  # nowhere -- the loader hands back the bundled copy as if nothing happened.
  clear_schema_caches()
  fetches <- 0L
  schema <- .ms_load_sdp_schema(quiet = TRUE)
  expect_identical(fetches, 1L)
  expect_identical(schema$source, "vendored")

  # POSITIVE CONTROL, LAYER 2: the package's real fetch reaches the listener.
  # Nothing answers there, so it fails once the short timeout passes -- after
  # connecting, which is the thing counted.
  try(real_fetch(.ms_default_sdp_schema_base_url(), timeout = 0.25), silent = TRUE)
  expect_gte(connections(), 1L)
})

test_that("the offline read leaves the session's own schema cache alone", {
  pkg <- offline_fixture_package()
  local_shipped_schema_defaults()

  # Stand in for the bundle a session has already resolved on the default
  # source, which is what a `create_sdp()` earlier in the same script leaves.
  resolved <- .ms_load_vendored_sdp_schema()
  resolved$source <- "remote"
  key <- paste("auto", .ms_default_sdp_schema_base_url(), sep = "|")
  .ms_schema_env$schema <- resolved
  .ms_schema_env$cache_key <- key

  utils::capture.output(print(review_metadata(pkg)))
  set_sdp_dataset(pkg, creator = "Cache Guard", quiet = TRUE)

  # Reading the bundle through `.ms_load_sdp_schema(source = "vendored")` would
  # also be offline, and would evict this: the next writer, reader or validator
  # call would then fetch all eight documents again, and the next package the
  # script writes could carry a different profile identity from the last.
  expect_identical(.ms_schema_env$cache_key, key)
  expect_identical(.ms_schema_env$schema, resolved)
})
