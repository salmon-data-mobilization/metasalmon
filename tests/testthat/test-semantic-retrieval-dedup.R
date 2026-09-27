# Backlog #56, hub item B-56: `suggest_semantics()` searches each distinct
# (query, role, sources) tuple once, however many target rows share it.
#
# The fixture is duplicate-heavy on purpose: four tables carry the same two
# columns, so every tuple is shared by at least four target rows (eight for the
# `count` unit query both columns fall back to). Only the table differs, and the
# table is not part of what is searched.

dedup_fixture_dict <- function(n_tables = 4L) {
  one_table <- function(table_id) {
    tibble::tibble(
      dataset_id = "d1",
      table_id = table_id,
      column_name = c("spawners", "fork_length"),
      column_label = c("Spawner abundance", "Fork length"),
      column_description = c("Spawner abundance estimate", "Fork length of sampled fish"),
      column_role = "measurement",
      value_type = "number",
      unit_label = NA_character_,
      unit_iri = NA_character_,
      term_iri = NA_character_,
      property_iri = NA_character_,
      entity_iri = NA_character_,
      constraint_iri = NA_character_,
      statistical_modifier_iri = NA_character_
    )
  }
  dplyr::bind_rows(lapply(sprintf("t%d", seq_len(n_tables)), one_table))
}

# A search that records every call it receives and answers deterministically
# from the tuple, so a row that was served another tuple's answer is visible in
# its IRIs. `answer(calls_so_far)` decides whether the n-th call for one tuple is
# answered in full or degraded.
dedup_counting_search <- function(answer = function(n) "full") {
  log <- new.env(parent = emptyenv())
  log$keys <- character()
  fn <- function(query, role, sources) {
    key <- paste(query, role, paste(sources, collapse = ","), sep = " | ")
    log$keys <- c(log$keys, key)
    slug <- gsub("[^a-z0-9]+", "-", tolower(query))
    base <- paste0("https://example.org/", slug, "/", role, "/")
    if (identical(answer(sum(log$keys == key)), "degraded")) {
      res <- tibble::tibble(
        label = paste(query, "partial"),
        iri = paste0(base, "partial"),
        source = "ols",
        ontology = "demo",
        role = role,
        match_type = "label",
        definition = "",
        score = 1
      )
      # A source that did not answer: the shape `find_terms()` gives an outage.
      attr(res, "diagnostics") <- tibble::tibble(source = "ols", status = "error")
      return(res)
    }
    tibble::tibble(
      label = paste(query, c("A", "B", "C")),
      iri = paste0(base, c("a", "b", "c")),
      source = "ols",
      ontology = "demo",
      role = role,
      match_type = "label",
      definition = "",
      score = c(3, 2, 1)
    )
  }
  list(fn = fn, log = log)
}

# The behaviour before the fix, as a reference: retrieval run row by row over
# the targets, one search per row. Its rows are what each target must still get,
# and its call log is how many rows share each tuple.
dedup_per_row_reference <- function(targets, answer = function(n) "full") {
  search <- dedup_counting_search(answer)
  rows <- purrr::map_dfr(seq_len(nrow(targets)), function(i) {
    .ms_retrieve_semantic_target_candidates(
      target = targets[i, , drop = FALSE],
      sources = "ols",
      max_per_role = 2,
      search_fn = search$fn,
      retrieval_pass = 1L
    )
  })
  list(rows = rows, keys = search$log$keys)
}

test_that("suggest_semantics() searches each distinct query, role and sources tuple once", {
  dict <- dedup_fixture_dict()
  search <- dedup_counting_search()

  res <- suppressMessages(suggest_semantics(
    NULL, dict,
    sources = "ols", max_per_role = 2, search_fn = search$fn
  ))
  suggestions <- attr(res, "semantic_suggestions")
  keys <- search$log$keys
  per_row <- dedup_per_row_reference(attr(res, "semantic_targets"))

  # The premise: row by row, every tuple is searched at least four times.
  expect_gt(length(keys), 0L)
  expect_true(all(table(per_row$keys) >= 4L))

  # The fix: each distinct tuple is searched once, and no tuple is missed.
  expect_equal(anyDuplicated(keys), 0L)
  expect_setequal(keys, unique(per_row$keys))

  # Every row still gets exactly what a search of its own tuple returns, in the
  # same order.
  compared <- c(
    "table_id", "column_name", "dictionary_role", "search_role",
    "retrieval_query", "label", "iri", "score"
  )
  expect_identical(suggestions[compared], per_row$rows[compared])

  # And each table's rows carry that table's own target columns.
  expect_setequal(unique(suggestions$table_id), c("t1", "t2", "t3", "t4"))
  expect_true(all(startsWith(
    suggestions$iri,
    paste0(
      "https://example.org/",
      gsub("[^a-z0-9]+", "-", tolower(suggestions$retrieval_query)),
      "/", suggestions$search_role, "/"
    )
  )))
})

test_that("a degraded search result is never served to another row", {
  dict <- dedup_fixture_dict()

  # First search of each tuple degraded, every later one answered in full.
  search <- dedup_counting_search(function(n) if (n == 1L) "degraded" else "full")
  res <- suppressMessages(suggest_semantics(
    NULL, dict,
    sources = "ols", max_per_role = 2, search_fn = search$fn
  ))
  suggestions <- attr(res, "semantic_suggestions")
  per_tuple <- table(search$log$keys)

  # The degraded answer was not kept, so the tuple's next row searched again;
  # the full answer was kept, so no row after that searched.
  expect_true(all(per_tuple == 2L))

  # The row that got the degraded answer keeps it, as before, and every other
  # row with that tuple gets the full answer.
  # One row per target, in the order the targets were searched.
  rows <- unique(suggestions[c(
    "table_id", "column_name", "dictionary_role", "retrieval_query", "search_role"
  )])
  first_of_tuple <- !duplicated(paste(rows$retrieval_query, rows$search_role))
  got_partial <- vapply(seq_len(nrow(rows)), function(i) {
    hit <- suggestions$table_id == rows$table_id[[i]] &
      suggestions$column_name == rows$column_name[[i]] &
      suggestions$dictionary_role == rows$dictionary_role[[i]]
    any(endsWith(suggestions$iri[hit], "/partial"))
  }, logical(1))
  expect_identical(got_partial, first_of_tuple)

  # An outage that lasts: every row searches for itself and nothing is shared.
  outage <- dedup_counting_search(function(n) "degraded")
  res_outage <- suppressMessages(suggest_semantics(
    NULL, dict,
    sources = "ols", max_per_role = 2, search_fn = outage$fn
  ))
  outage_per_row <- dedup_per_row_reference(
    attr(res_outage, "semantic_targets"),
    function(n) "degraded"
  )
  expect_identical(table(outage$log$keys), table(outage_per_row$keys))
  expect_true(all(endsWith(attr(res_outage, "semantic_suggestions")$iri, "/partial")))
})
