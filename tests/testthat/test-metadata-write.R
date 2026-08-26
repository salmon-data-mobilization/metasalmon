# `apply_sdp_semantics()` -- the surgical write-back for the R-native review
# flow (stream S5, backlog #74).
#
# The gate this whole feature is judged against, in the backlog's words:
# `create_sdp()` -> `review_semantics()` -> `accept_suggestion()` ->
# `apply_sdp_semantics()` -> `validate_salmon_datapackage(require_iris = TRUE)`
# passes with no `REVIEW:` markers left AND the data CSV bytes unchanged. The
# byte assertion is the only one that fails if the writer stops being surgical,
# so it is asserted directly rather than inferred.

review_fixture_resources <- function() {
  list(
    spawners = data.frame(
      stream_name = c("Bear Creek", "Elk River"),
      spawner_count = c(120L, 340L),
      stringsAsFactors = FALSE
    )
  )
}

# Every I-ADOPT role gets a hit, so a completed review can actually satisfy
# `require_iris = TRUE`. A fixture that leaves a role unanswered would make the
# round-trip test pass or fail for reasons unrelated to the write-back.
review_fixture_search <- function(query, role = NA_character_,
                                  sources = c("smn", "gcdfo", "ols", "nvs"), ...) {
  hit <- function(label, iri, role, definition, score, source = "smn") {
    tibble::tibble(
      label = label, iri = iri, source = source, ontology = source, role = role,
      match_type = "label_exact", definition = definition, score = score
    )
  }
  switch(
    as.character(role),
    variable = dplyr::bind_rows(
      hit("Spawner Abundance", "https://w3id.org/smn/SpawnerAbundance", "variable",
          "Mature salmon returning to spawn in a stream {reach}.", 4.9),
      hit("Escapement", "https://w3id.org/smn/Escapement", "variable",
          "Fish that escape the fishery.", 3.2)
    ),
    property = hit("Abundance", "https://w3id.org/smn/Abundance", "property", "A count property.", 4.1),
    entity = hit("Spawner", "https://w3id.org/smn/Spawner", "entity", "A mature salmon.", 4.0),
    unit = hit("Count", "http://qudt.org/vocab/unit/NUM", "unit", "A dimensionless count.", 3.9),
    tibble::tibble()
  )
}

review_fixture_package <- function(name = "review-demo") {
  path <- file.path(withr::local_tempdir(.local_envir = parent.frame()), name)
  suppressMessages(with_mocked_bindings(
    find_terms = review_fixture_search,
    create_sdp(
      review_fixture_resources(),
      path = path,
      dataset_id = "demo-1",
      semantic_max_per_role = 3,
      seed_semantics = TRUE,
      seed_verbose = FALSE,
      check_updates = FALSE,
      overwrite = TRUE
    )
  ))
}

# Free-text placeholders are M4's job (`review_metadata()` / `set_sdp_*()`),
# which is not in this change. `require_iris = TRUE` refuses them as well as
# `REVIEW:` IRIs, so the round-trip proof fills them here directly -- and that
# direct edit is precisely the step M4 exists to replace.
resolve_free_text_placeholders <- function(path) {
  for (file_name in c("dataset.csv", "tables.csv", "column_dictionary.csv")) {
    file_path <- file.path(path, "metadata", file_name)
    rows <- readr::read_csv(
      file_path,
      col_types = readr::cols(.default = readr::col_character()),
      na = ""
    )
    rows[] <- lapply(rows, function(column) {
      placeholder <- !is.na(column) &
        grepl("^\\s*(MISSING DESCRIPTION|MISSING METADATA)\\s*:", column)
      column[placeholder] <- "filled for the round-trip test"
      column
    })
    if (identical(file_name, "dataset.csv")) {
      rows$license <- "CC-BY-4.0"
      rows$contact_email <- "review@example.org"
    }
    readr::write_csv(rows, file_path, na = "")
  }
  invisible(path)
}

accept_everything <- function(review) {
  for (slot in unique(review$slot_id)) {
    row <- review[review$slot_id == slot, , drop = FALSE][1, , drop = FALSE]
    column <- if (is.na(row$column_name[[1]])) NULL else row$column_name[[1]]
    review <- accept_suggestion(
      review,
      column = column,
      role = row$role[[1]],
      rank = 1L,
      table = row$table_id[[1]]
    )
  }
  review
}

test_that("the review round trip clears every REVIEW: marker and leaves the data bytes alone", {
  path <- review_fixture_package()
  data_path <- file.path(path, "data", "spawners.csv")
  data_before <- readBin(data_path, "raw", file.info(data_path)$size)

  review <- suppressMessages(review_semantics(path))
  expect_gt(nrow(review), 0L)
  review <- accept_everything(review)

  suppressMessages(apply_sdp_semantics(path, review))

  dictionary <- readr::read_csv(
    file.path(path, "metadata", "column_dictionary.csv"),
    col_types = readr::cols(.default = readr::col_character())
  )
  iri_columns <- grep("_iri$", names(dictionary), value = TRUE)
  markers <- unlist(lapply(dictionary[iri_columns], function(column) {
    grep("^\\s*REVIEW\\s*:", as.character(column), value = TRUE)
  }))
  expect_length(markers, 0L)
  expect_equal(
    dictionary$term_iri[dictionary$column_name == "spawner_count"],
    "https://w3id.org/smn/SpawnerAbundance"
  )

  # The point of "surgical": a review decision must not rewrite the data.
  expect_identical(readBin(data_path, "raw", file.info(data_path)$size), data_before)

  resolve_free_text_placeholders(path)
  expect_no_error(suppressMessages(
    validate_salmon_datapackage(path, require_iris = TRUE)
  ))
})

test_that("applying the same review twice produces identical bytes", {
  path <- review_fixture_package()
  review <- accept_everything(suppressMessages(review_semantics(path)))
  suppressMessages(apply_sdp_semantics(path, review))

  targets <- c(
    file.path(path, "metadata", "column_dictionary.csv"),
    file.path(path, "metadata", "tables.csv"),
    file.path(path, "datapackage.json"),
    file.path(path, "semantic_suggestions.csv")
  )
  targets <- targets[file.exists(targets)]
  before <- vapply(targets, function(p) digest::digest(p, file = TRUE), character(1))

  suppressMessages(apply_sdp_semantics(path, review))
  after <- vapply(targets, function(p) digest::digest(p, file = TRUE), character(1))
  expect_identical(after, before)
})

test_that("only decided fields are written; undecided slots keep their markers", {
  path <- review_fixture_package()
  review <- suppressMessages(review_semantics(path))
  review <- accept_suggestion(review, "spawner_count", "variable", rank = 1)
  suppressMessages(apply_sdp_semantics(path, review))

  dictionary <- readr::read_csv(
    file.path(path, "metadata", "column_dictionary.csv"),
    col_types = readr::cols(.default = readr::col_character())
  )
  row <- dictionary[dictionary$column_name == "spawner_count", , drop = FALSE]
  expect_equal(row$term_iri[[1]], "https://w3id.org/smn/SpawnerAbundance")
  # `property_iri` was seeded with a marker and never decided, so it must be
  # exactly as it was. This is the contract that makes the write re-runnable
  # across a review done in several sittings.
  expect_true(grepl("^REVIEW", row$property_iri[[1]]))
})

test_that("accepting a term also records its term_type, and rejecting clears both", {
  path <- review_fixture_package()
  review <- accept_suggestion(
    suppressMessages(review_semantics(path)), "spawner_count", "variable", rank = 1
  )
  suppressMessages(apply_sdp_semantics(path, review))
  dictionary <- readr::read_csv(
    file.path(path, "metadata", "column_dictionary.csv"),
    col_types = readr::cols(.default = readr::col_character())
  )
  expect_equal(
    dictionary$term_type[dictionary$column_name == "spawner_count"],
    "skos_concept"
  )

  # The slot now holds a final IRI, so it is off the default queue -- which is
  # itself the contract: `review_semantics()` shows what still needs deciding.
  rejected <- reject_suggestion(
    suppressMessages(review_semantics(path, include_filled = TRUE)),
    "spawner_count", "variable"
  )
  suppressMessages(apply_sdp_semantics(path, rejected))
  dictionary <- readr::read_csv(
    file.path(path, "metadata", "column_dictionary.csv"),
    col_types = readr::cols(.default = readr::col_character())
  )
  row <- dictionary[dictionary$column_name == "spawner_count", , drop = FALSE]
  expect_true(is.na(row$term_iri[[1]]))
  # A `term_type` describing a term that is no longer there would be a lie the
  # validator cannot see.
  expect_true(is.na(row$term_type[[1]]))
})

test_that("the descriptor is kept in step with the dictionary in the same write", {
  # `datapackage.json` duplicates the dictionary's IRI fields and the rule that
  # would catch drift (`datapackage_consistent_with_csv_metadata`) is dead, so
  # nothing else would notice a half-applied edit.
  path <- review_fixture_package()
  review <- accept_everything(suppressMessages(review_semantics(path)))
  suppressMessages(apply_sdp_semantics(path, review))

  descriptor <- jsonlite::read_json(file.path(path, "datapackage.json"), simplifyVector = FALSE)
  resource <- Filter(function(r) identical(r$name, "spawners"), descriptor$resources)[[1]]
  field <- Filter(function(f) identical(f$name, "spawner_count"), resource$schema$fields)[[1]]
  expect_equal(field$term_iri, "https://w3id.org/smn/SpawnerAbundance")
  expect_false(grepl("REVIEW", field$term_iri %||% "", fixed = TRUE))

  rejected <- reject_suggestion(
    suppressMessages(review_semantics(path, include_filled = TRUE)),
    "spawner_count", "variable"
  )
  suppressMessages(apply_sdp_semantics(path, rejected))
  descriptor <- jsonlite::read_json(file.path(path, "datapackage.json"), simplifyVector = FALSE)
  resource <- Filter(function(r) identical(r$name, "spawners"), descriptor$resources)[[1]]
  field <- Filter(function(f) identical(f$name, "spawner_count"), resource$schema$fields)[[1]]
  # Cleared in the CSV means absent from the descriptor -- the writer omits an
  # empty field rather than emitting an empty string, and the patch has to
  # produce the same shape a full rebuild would.
  expect_null(field$term_iri)
})

test_that("the decision is recorded in semantic_suggestions.csv", {
  # `apply_semantic_suggestions(strategy = "reviewed")` has always filtered a
  # `decision` column that nothing wrote. This is that missing producer, and it
  # is what makes the decision survive in the package and not only in the
  # user's script.
  path <- review_fixture_package()
  review <- suppressMessages(review_semantics(path))
  review <- accept_suggestion(review, "spawner_count", "variable", rank = 2)
  review <- reject_suggestion(review, "stream_name", "variable")
  suppressMessages(apply_sdp_semantics(path, review))

  suggestions <- readr::read_csv(
    file.path(path, "semantic_suggestions.csv"),
    col_types = readr::cols(.default = readr::col_character())
  )
  accepted <- suggestions[!is.na(suggestions$decision) & suggestions$decision == "accepted", , drop = FALSE]
  expect_equal(accepted$iri, "https://w3id.org/smn/Escapement")
  expect_true(any(suggestions$decision %in% "not_selected"))
  expect_true(any(suggestions$decision %in% "rejected"))
})

test_that("apply_sdp_semantics() refuses a path that is not a package directory", {
  review <- suppressMessages(review_semantics(review_fixture_package()))
  expect_error(apply_sdp_semantics(tempfile(), review), "existing Salmon Data Package")
  expect_error(apply_sdp_semantics(withr::local_tempdir(), tibble::tibble()), "ms_semantic_review")
})

test_that("apply_sdp_semantics() with no decisions changes nothing", {
  path <- review_fixture_package()
  review <- suppressMessages(review_semantics(path))
  dictionary_path <- file.path(path, "metadata", "column_dictionary.csv")
  before <- digest::digest(dictionary_path, file = TRUE)
  expect_message(apply_sdp_semantics(path, review), "No decisions to apply")
  expect_identical(digest::digest(dictionary_path, file = TRUE), before)
})

test_that("apply_sdp_semantics() refuses to write through a symlinked metadata directory", {
  skip_on_os("windows")
  path <- review_fixture_package()
  review <- accept_suggestion(
    suppressMessages(review_semantics(path)), "spawner_count", "variable", rank = 1
  )

  real_metadata <- file.path(path, "metadata")
  moved <- file.path(dirname(path), "elsewhere-metadata")
  file.rename(real_metadata, moved)
  file.symlink(moved, real_metadata)

  expect_error(apply_sdp_semantics(path, review), "symbolic-link path component")
})

test_that("a reviewed decision is not overruled by the unattended auto-apply heuristic", {
  # Backlog #118. `apply_semantic_suggestions()` ran the lexical compatibility
  # gate on `strategy = "reviewed"` too, so a term a human read and accepted
  # could be dropped because its label did not match the column name -- and the
  # caller was told only that rows "did not meet the requested filters".
  dict <- tibble::tibble(
    dataset_id = "demo-1",
    table_id = "spawners",
    column_name = "stream_name",
    # An identifier column: the unattended gate vetoes EVERY suggestion for
    # one, which makes the difference between the two strategies unambiguous.
    column_role = "identifier",
    column_label = "Stream name",
    term_iri = NA_character_
  )
  suggestions <- tibble::tibble(
    dataset_id = "demo-1",
    table_id = "spawners",
    column_name = "stream_name",
    dictionary_role = "variable",
    target_scope = "column",
    target_sdp_file = "column_dictionary.csv",
    target_sdp_field = "term_iri",
    label = "Spawner Abundance",
    iri = "https://w3id.org/smn/SpawnerAbundance",
    source = "smn",
    decision = "accepted"
  )

  applied <- apply_semantic_suggestions(
    dict,
    suggestions = suggestions,
    strategy = "reviewed",
    overwrite = TRUE,
    verbose = FALSE
  )
  expect_equal(applied$term_iri, "https://w3id.org/smn/SpawnerAbundance")

  # The unattended path keeps the gate: it is the whole reason the gate exists.
  seeded <- apply_semantic_suggestions(
    dict,
    suggestions = suggestions[, setdiff(names(suggestions), "decision")],
    strategy = "top",
    overwrite = TRUE,
    verbose = FALSE
  )
  expect_true(is.na(seeded$term_iri))
})

test_that("an abort during the write leaves the package wholly unchanged", {
  # The execplan's explicit acceptance criterion: interrupt between the CSV
  # write and the descriptor step, and the package must be wholly old rather
  # than half-updated. It is asserted directly rather than inherited from the
  # atomic-write-set tests, because what is being pinned here is the ORDERING
  # in `apply_sdp_semantics()` -- every file is rendered to bytes before any
  # file is installed -- and that ordering lives in this function, not in the
  # writer it delegates to.
  path <- review_fixture_package()
  review <- accept_suggestion(
    suppressMessages(review_semantics(path)), "spawner_count", "variable", rank = 1
  )

  dictionary_path <- file.path(path, "metadata", "column_dictionary.csv")
  descriptor_path <- file.path(path, "datapackage.json")
  writeLines("{ this is not json", descriptor_path)

  before <- vapply(
    c(dictionary_path, descriptor_path, file.path(path, "data", "spawners.csv")),
    function(p) digest::digest(p, file = TRUE),
    character(1)
  )

  expect_error(apply_sdp_semantics(path, review), "datapackage.json")

  after <- vapply(
    c(dictionary_path, descriptor_path, file.path(path, "data", "spawners.csv")),
    function(p) digest::digest(p, file = TRUE),
    character(1)
  )
  # The dictionary is the one that matters: it was already mutated in memory
  # and its bytes were already rendered when the descriptor step aborted.
  expect_identical(after, before)
})
