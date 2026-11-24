# Helpers for the semantic review packet contract (S16 step 1, hub item
# B-326): building in-memory input from a conformance case's `input.json`,
# reading the shared fixtures under fixtures/semantic-review/v1/, and the fake
# search function the retry cases use. The same helpers are sourced by
# scripts/build-semantic-review-fixtures.R, which writes the golden files, so
# the generator and the tests read a case one way.

semantic_review_fixture_root <- function() {
  testthat::test_path("fixtures", "semantic-review", "v1")
}

# The conformance case id of a Theme A case. Short on purpose: every fixture
# path, with the `metasalmon/` prefix a source tarball adds, has to stay
# within the 100 bytes a portable tarball stores, or R CMD check reports a
# non-portable file name. The packet test asserts the budget.
semantic_review_theme_a_case_id <- function(case_id) {
  ids <- c(
    catch_count = "ta_catch_count",
    catch_weight_advisory = "ta_catch_weight",
    fork_length_explicit_procedure = "ta_fork_length",
    ocean_phase_explicit_lifecycle = "ta_ocean_phase",
    synthetic_structured_gap = "ta_gap",
    handcrafted_gcdfo_routing = "ta_gcdfo_routing"
  )
  if (!case_id %in% names(ids)) {
    stop("No conformance case id is mapped for Theme A case ", case_id)
  }
  unname(ids[[case_id]])
}

semantic_review_read_json <- function(path) {
  jsonlite::fromJSON(path, simplifyVector = FALSE)
}

# A JSON array of row objects to a tibble, every cell character (NA for
# null), except the columns named in `numeric`, `integer` and `logical`.
semantic_review_rows_to_tibble <- function(rows, numeric = character(), integer = character(), logical = character()) {
  if (length(rows) == 0L) {
    return(tibble::tibble())
  }
  cols <- unique(unlist(lapply(rows, names)))
  frame <- lapply(cols, function(col) {
    values <- lapply(rows, function(row) row[[col]])
    cell <- function(value, convert) if (is.null(value)) NA else convert(value[[1]])
    if (col %in% numeric) {
      vapply(values, cell, numeric(1), convert = as.numeric)
    } else if (col %in% integer) {
      vapply(values, cell, integer(1), convert = as.integer)
    } else if (col %in% logical) {
      vapply(values, cell, logical(1), convert = as.logical)
    } else {
      vapply(values, function(v) if (is.null(v)) NA_character_ else as.character(v[[1]]), character(1))
    }
  })
  tibble::as_tibble(stats::setNames(frame, cols))
}

# The dictionary a case's `input.json` describes, with `semantic_targets`
# and `semantic_suggestions` attached, exactly as `suggest_semantics()`
# would attach them.
semantic_review_case_dictionary <- function(input) {
  dictionary <- semantic_review_rows_to_tibble(input$dictionary)
  targets <- semantic_review_rows_to_tibble(input$targets)
  candidates <- semantic_review_rows_to_tibble(
    input$candidates,
    numeric = c("score", "role_hint_bonus"),
    integer = "retrieval_pass",
    logical = c("alignment_only", "role_collision")
  )
  attr(dictionary, "semantic_targets") <- targets
  attr(dictionary, "semantic_suggestions") <- candidates
  dictionary
}

# The fake search function: answers from `search-responses.json`, keyed by
# `<query>|<role>`, with the rows a real retrieval would return, and counts
# its calls. A query with no entry returns an empty frame.
semantic_review_fake_search <- function(responses, counter = NULL) {
  function(query, role, sources) {
    if (!is.null(counter)) {
      counter$calls <- counter$calls + 1L
      counter$log[[length(counter$log) + 1L]] <- list(query = query, role = role, sources = sources)
    }
    rows <- responses[[paste(query, role, sep = "|")]]
    if (is.null(rows)) {
      return(tibble::tibble())
    }
    semantic_review_rows_to_tibble(rows, numeric = "score")
  }
}

semantic_review_search_responses <- function() {
  semantic_review_read_json(file.path(semantic_review_fixture_root(), "search-responses.json"))
}

# An assessment CSV read the way the ingester reads it: every cell text.
semantic_review_read_csv <- function(path) {
  tibble::as_tibble(readr::read_csv(
    path,
    col_types = readr::cols(.default = readr::col_character()),
    na = "",
    show_col_types = FALSE
  ))
}

# Two frames compared after reading, not as bytes: the same columns in the
# same order, and every cell equal as text with NA and the empty field one
# value.
semantic_review_expect_frames_equal <- function(actual, expected, info = NULL) {
  to_text <- function(frame) {
    frame <- tibble::as_tibble(frame)
    frame[] <- lapply(frame, function(col) {
      out <- if (is.logical(col)) {
        ifelse(col, "TRUE", "FALSE")
      } else if (is.numeric(col) && !is.integer(col)) {
        vapply(col, function(v) if (is.na(v)) NA_character_ else metasalmon:::.ms_format_number_token(v), character(1))
      } else {
        as.character(col)
      }
      out[is.na(col)] <- NA_character_
      out[!is.na(out) & !nzchar(out)] <- NA_character_
      out
    })
    frame
  }
  actual <- to_text(actual)
  expected <- to_text(expected)
  testthat::expect_identical(names(actual), names(expected), info = info)
  testthat::expect_equal(nrow(actual), nrow(expected), info = info)
  for (col in names(expected)) {
    testthat::expect_identical(actual[[col]], expected[[col]], info = paste(info, col))
  }
}

# The packet with its `producer` removed: the one member that may differ
# between the two implementations and between releases of one.
semantic_review_strip_producer <- function(packet) {
  packet[setdiff(names(packet), "producer")]
}

semantic_review_sha256_file <- function(path) {
  digest::digest(readBin(path, what = "raw", n = file.info(path)$size), algo = "sha256", serialize = FALSE)
}

# Write a harness CSV from a data frame the way a harness would: a CSV
# library, UTF-8, the empty field for a missing value, and beside it the
# one-line sidecar naming the packet it judged (`<csv>.packet-id`). Pass
# `packet_id = NULL` to leave the file unbound.
semantic_review_write_harness <- function(rows, path, packet_id = NULL) {
  readr::write_csv(rows, path, na = "")
  sidecar <- metasalmon:::.ms_semantic_review_sidecar_path(path)
  if (!is.null(packet_id)) {
    writeLines(packet_id, sidecar)
  } else if (file.exists(sidecar)) {
    unlink(sidecar)
  }
  invisible(path)
}

# An empty harness row for one target of a packet: the identity copied, every
# other cell empty.
semantic_review_harness_row <- function(target, ...) {
  cols <- metasalmon:::.ms_llm_assessment_cols()
  row <- stats::setNames(as.list(rep(NA_character_, length(cols))), cols)
  for (col in metasalmon:::.ms_semantic_review_identity_cols()) {
    row[[col]] <- as.character(target[[col]])
  }
  row$llm_provider <- "fixture-harness"
  row$llm_model <- "semantic-review-v1"
  values <- list(...)
  for (name in names(values)) {
    row[[name]] <- as.character(values[[name]])
  }
  tibble::as_tibble(row)
}
