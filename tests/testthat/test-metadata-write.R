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

test_that("the rejection reason reaches disk and survives a second sitting", {
  # The feature's whole thesis is the record of WHY. Until this, only the bare
  # word `rejected` reached `semantic_suggestions.csv`: the reason lived on the
  # in-memory review object and printed to the console, and then evaporated --
  # the one field a later reader most needs was the one not written down.
  path <- review_fixture_package()
  review <- reject_suggestion(
    suppressMessages(review_semantics(path)),
    "spawner_count", "unit",
    reason = "the count is dimensionless"
  )
  suppressMessages(apply_sdp_semantics(path, review))

  suggestions <- readr::read_csv(
    file.path(path, "semantic_suggestions.csv"),
    col_types = readr::cols(.default = readr::col_character())
  )
  rejected <- suggestions[!is.na(suggestions$decision) & suggestions$decision == "rejected", , drop = FALSE]
  expect_gt(nrow(rejected), 0L)
  expect_equal(unique(rejected$decision_reason), "the count is dimensionless")

  # Monday's rejection must survive Tuesday's acceptance. The column used to be
  # blanked on every apply, so a review object that did not carry an earlier
  # decision erased it.
  tuesday <- accept_suggestion(
    suppressMessages(review_semantics(path)), "spawner_count", "variable", rank = 1
  )
  suppressMessages(apply_sdp_semantics(path, tuesday))
  suggestions <- readr::read_csv(
    file.path(path, "semantic_suggestions.csv"),
    col_types = readr::cols(.default = readr::col_character())
  )
  expect_true(any(suggestions$decision %in% "rejected"))
  expect_true(any(suggestions$decision_reason %in% "the count is dimensionless"))
  expect_true(any(suggestions$decision %in% "accepted"))
})

test_that("review_metadata() reads the rejection reason back onto the gap it left", {
  # A rejection clears the field, so the gap comes back looking exactly like
  # one nobody has ever considered. Reading the reason back is what makes
  # recording it worth anything.
  path <- review_fixture_package()
  review <- reject_suggestion(
    suppressMessages(review_semantics(path)),
    "spawner_count", "unit",
    reason = "the count is dimensionless"
  )
  suppressMessages(apply_sdp_semantics(path, review))

  gaps <- review_metadata(path)
  unit_gap <- gaps[gaps$file == "column_dictionary.csv" & gaps$field == "unit_iri", , drop = FALSE]
  expect_equal(nrow(unit_gap), 1L)
  expect_true(grepl("the count is dimensionless", unit_gap$note[[1]], fixed = TRUE))
})

test_that("prune warns before it destroys recorded review decisions", {
  # `prune = TRUE` wipes the directory and `semantic_suggestions.csv` is not
  # among the files a rewrite produces, so a user reaching for prune mid-review
  # loses the audit trail -- silently, and after the point where anything could
  # be recovered.
  path <- review_fixture_package()
  review <- reject_suggestion(
    suppressMessages(review_semantics(path)), "spawner_count", "unit",
    reason = "the count is dimensionless"
  )
  suppressMessages(apply_sdp_semantics(path, review))

  expect_warning(
    suppressMessages(create_sdp(
      review_fixture_resources(),
      path = path, dataset_id = "demo-1", seed_semantics = FALSE,
      check_updates = FALSE, overwrite = TRUE, prune = TRUE
    )),
    "review decision"
  )

  # A package with no recorded decision is pruned without a word: the warning
  # is about losing an audit trail, not about pruning.
  clean <- review_fixture_package("prune-clean")
  unlink(file.path(clean, "semantic_suggestions.csv"))
  expect_no_warning(suppressMessages(create_sdp(
    review_fixture_resources(),
    path = clean, dataset_id = "demo-1", seed_semantics = FALSE,
    check_updates = FALSE, overwrite = TRUE, prune = TRUE
  )))
})

# ---------------------------------------------------------------------------
# A hand-picked accept (hub queue B-176)
#
# `accept_suggestion(iri = )` is the supported escape hatch for a term retrieval
# never surfaced, and a shortlist match was the only way an `accepted` row ever
# reached `semantic_suggestions.csv`. So a hand-picked IRI reached
# `column_dictionary.csv` and nothing else: every candidate in its slot was
# written `not_selected`, no row was `accepted`, no row carried the IRI, and the
# next `review_semantics()` replayed nothing -- the slot left the queue only
# because its field was now filled. Every test here reads the decision record
# back from disk, because the dictionary half was never broken and a test that
# asserts only on the dictionary passes against the defect.
# ---------------------------------------------------------------------------

handpicked_iri <- "https://example.org/Handpicked"

read_suggestions_file <- function(path) {
  readr::read_csv(
    file.path(path, "semantic_suggestions.csv"),
    col_types = readr::cols(.default = readr::col_character()),
    na = ""
  )
}

read_metadata_file <- function(path, file_name) {
  readr::read_csv(
    file.path(path, "metadata", file_name),
    col_types = readr::cols(.default = readr::col_character()),
    na = ""
  )
}

slot_rows <- function(suggestions, column, role) {
  suggestions[
    suggestions$column_name %in% column & suggestions$dictionary_role %in% role,
    ,
    drop = FALSE
  ]
}

accept_handpicked <- function(path, iri = handpicked_iri, include_filled = FALSE) {
  accept_suggestion(
    suppressMessages(review_semantics(path, include_filled = include_filled)),
    "spawner_count", "variable",
    iri = iri
  )
}

managed_digests <- function(path) {
  targets <- c(
    file.path(path, "metadata", "column_dictionary.csv"),
    file.path(path, "metadata", "tables.csv"),
    file.path(path, "datapackage.json"),
    file.path(path, "semantic_suggestions.csv")
  )
  targets <- targets[file.exists(targets)]
  vapply(targets, function(p) digest::digest(p, file = TRUE), character(1))
}

test_that("a hand-picked accept outside the shortlist reaches the decision record", {
  path <- review_fixture_package()
  before <- slot_rows(read_suggestions_file(path), "spawner_count", "variable")
  # The premise, asserted rather than assumed: no candidate carries this IRI.
  expect_gt(nrow(before), 0L)
  expect_false(handpicked_iri %in% before$iri)

  suppressMessages(apply_sdp_semantics(path, accept_handpicked(path)))

  # The half that was never broken.
  dictionary <- read_metadata_file(path, "column_dictionary.csv")
  expect_equal(dictionary$term_iri[dictionary$column_name == "spawner_count"], handpicked_iri)

  slot <- slot_rows(read_suggestions_file(path), "spawner_count", "variable")
  accepted <- slot[slot$decision %in% "accepted", , drop = FALSE]
  expect_equal(nrow(accepted), 1L)
  expect_equal(accepted$iri, handpicked_iri)

  # Its OWN row, not a candidate relabelled: a relabelled candidate's label,
  # ontology, definition and score would all describe a term nobody chose.
  expect_equal(nrow(slot), nrow(before) + 1L)
  expect_equal(accepted$source, "user")
  expect_true(all(is.na(unlist(accepted[c("label", "ontology", "definition", "score")]))))

  # The retrieved candidates are all still recorded, byte for byte and in their
  # order, and each still says it was not the one chosen.
  retrieved <- slot[slot$iri %in% before$iri, , drop = FALSE]
  expect_equal(as.data.frame(retrieved[names(before)]), as.data.frame(before))
  expect_equal(unique(retrieved$decision), "not_selected")

  # At the head of its slot, because rank is read from file position.
  expect_equal(slot$iri[[1]], handpicked_iri)
})

test_that("a hand-picked accept replays on the next review, and re-applies to the same bytes", {
  path <- review_fixture_package()
  suppressMessages(apply_sdp_semantics(path, accept_handpicked(path)))
  decided_slot <- "column_dictionary.csv|demo-1/spawners/spawner_count|term_iri"

  rebuilt <- suppressMessages(review_semantics(path, include_filled = TRUE))
  replayed <- rebuilt[rebuilt$slot_id == decided_slot & !is.na(rebuilt$decision), , drop = FALSE]
  expect_equal(nrow(replayed), 1L)
  expect_equal(replayed$decision, "accept")
  expect_equal(replayed$decision_iri, handpicked_iri)
  expect_equal(replayed$rank, 1L)
  expect_true(any(grepl(
    paste0("DECIDED: accept \u2192 ", handpicked_iri),
    .ms_review_render_lines(rebuilt),
    fixed = TRUE
  )))

  # A decided slot stays out of the default queue, hand-picked or not.
  expect_false(decided_slot %in% suppressMessages(review_semantics(path))$slot_id)

  # "Replayable" means the rebuilt review carries the SAME decision, so writing
  # it back changes nothing -- not the dictionary's `term_type`, not the
  # descriptor, not the record.
  before <- managed_digests(path)
  suppressMessages(apply_sdp_semantics(path, rebuilt))
  expect_identical(managed_digests(path), before)
})

test_that("applying the same hand-picked accept twice records it once", {
  path <- review_fixture_package()
  review <- accept_handpicked(path)
  suppressMessages(apply_sdp_semantics(path, review))
  once <- managed_digests(path)

  suppressMessages(apply_sdp_semantics(path, review))
  expect_identical(managed_digests(path), once)
  expect_equal(sum(read_suggestions_file(path)$iri %in% handpicked_iri), 1L)
})

test_that("a hand-picked accept ranks first rather than being filtered out behind a full shortlist", {
  # `review_semantics()` derives `rank` from file position and drops every row
  # past `max_candidates` (5 by default). Six candidates means a record appended
  # to the slot would rank 7 and vanish from the default view -- the decision
  # lost again, one layer further on.
  six_hits <- function(query, role = NA_character_, ...) {
    if (!identical(as.character(role), "variable")) {
      return(tibble::tibble())
    }
    tibble::tibble(
      label = paste("Spawner term", 1:6),
      iri = paste0("https://example.org/candidates/SpawnerTerm", 1:6),
      source = "smn", ontology = "smn", role = "variable",
      match_type = "label_exact", definition = "A spawner term.",
      score = seq(4.9, 3.9, length.out = 6)
    )
  }
  path <- file.path(withr::local_tempdir(), "six-candidates")
  suppressMessages(with_mocked_bindings(
    find_terms = six_hits,
    create_sdp(
      list(spawners = data.frame(spawner_count = c(120L, 340L))),
      path = path, dataset_id = "demo-1", semantic_max_per_role = 6,
      seed_semantics = TRUE, seed_verbose = FALSE, check_updates = FALSE,
      overwrite = TRUE
    )
  ))
  shortlist <- suppressMessages(review_semantics(path, max_candidates = Inf))
  expect_equal(nrow(shortlist), 6L)

  review <- accept_suggestion(shortlist, "spawner_count", "variable", iri = handpicked_iri)
  suppressMessages(apply_sdp_semantics(path, review))

  rebuilt <- suppressMessages(review_semantics(path, include_filled = TRUE))
  chosen <- rebuilt[rebuilt$iri %in% handpicked_iri, , drop = FALSE]
  expect_equal(nrow(chosen), 1L)
  expect_equal(chosen$rank, 1L)
  expect_equal(chosen$decision, "accept")
  # The retrieved candidates keep their relative order behind it: a position,
  # not a re-ranking.
  expect_equal(rebuilt$iri[-1], paste0("https://example.org/candidates/SpawnerTerm", 1:4))
})

test_that("a second hand-picked accept on the same slot demotes the first", {
  path <- review_fixture_package()
  first <- "https://example.org/HandpickedFirst"
  second <- "https://example.org/HandpickedSecond"
  suppressMessages(apply_sdp_semantics(path, accept_handpicked(path, iri = first)))
  suppressMessages(apply_sdp_semantics(
    path,
    accept_handpicked(path, iri = second, include_filled = TRUE)
  ))

  slot <- slot_rows(read_suggestions_file(path), "spawner_count", "variable")
  expect_equal(slot$iri[slot$decision %in% "accepted"], second)
  expect_equal(slot$iri[[1]], second)
  # The first choice stays on record, as a candidate that was not selected.
  expect_equal(slot$decision[slot$iri %in% first], "not_selected")

  dictionary <- read_metadata_file(path, "column_dictionary.csv")
  expect_equal(dictionary$term_iri[dictionary$column_name == "spawner_count"], second)
})

test_that("a hand-picked accept on a code-level slot keeps the code it addresses", {
  code_hits <- function(query, role = NA_character_, ...) {
    tibble::tibble(
      label = paste("Term", 1:2, "for", role),
      iri = paste0("https://example.org/candidates/", role, "Term", 1:2),
      source = "smn", ontology = "smn", role = role,
      match_type = "label_exact", definition = "A term.", score = c(4.5, 3.5)
    )
  }
  codes <- tibble::tibble(
    dataset_id = "demo-1", table_id = "spawners", column_name = "origin",
    code_value = c("wild", "hatchery"),
    code_label = c("Wild origin", "Hatchery origin"),
    code_description = c("Spawned in the wild.", "Reared in a hatchery.")
  )
  path <- file.path(withr::local_tempdir(), "code-slots")
  suppressMessages(with_mocked_bindings(
    find_terms = code_hits,
    create_sdp(
      list(spawners = data.frame(
        origin = rep(c("wild", "hatchery"), 6),
        spawner_count = 1:12
      )),
      path = path, dataset_id = "demo-1", table_id = "spawners",
      semantic_max_per_role = 2, seed_semantics = TRUE, seed_codes = codes,
      seed_verbose = FALSE, check_updates = FALSE, overwrite = TRUE
    )
  ))
  code_slot <- "codes.csv|demo-1/spawners/origin/wild|term_iri"
  expect_true(code_slot %in% suppressMessages(review_semantics(path))$slot_id)

  review <- accept_suggestion(
    suppressMessages(review_semantics(path)),
    "origin", "entity",
    code_value = "wild",
    iri = handpicked_iri
  )
  suppressMessages(apply_sdp_semantics(path, review))

  written <- read_suggestions_file(path)
  accepted <- written[written$decision %in% "accepted", , drop = FALSE]
  expect_equal(nrow(accepted), 1L)
  expect_equal(accepted$iri, handpicked_iri)
  expect_equal(accepted$code_value, "wild")
  expect_equal(accepted$target_sdp_file, "codes.csv")
  expect_equal(accepted$target_row_key, "demo-1/spawners/origin/wild")
  # The sibling code's slot was not decided, and is not touched.
  expect_true(all(is.na(written$decision[written$code_value %in% "hatchery"])))

  written_codes <- read_metadata_file(path, "codes.csv")
  expect_equal(written_codes$term_iri[written_codes$code_value == "wild"], handpicked_iri)

  rebuilt <- suppressMessages(review_semantics(path, include_filled = TRUE))
  replayed <- rebuilt[!is.na(rebuilt$decision), , drop = FALSE]
  expect_equal(unique(replayed$slot_id), code_slot)
  expect_equal(replayed$decision_iri, handpicked_iri)
})

test_that("a hand-picked accept tolerates a candidate row with no IRI in its slot", {
  # The write-back never required every row of a slot to carry an IRI, and a
  # hand-edited `semantic_suggestions.csv` can hold one that does not. The
  # accepted-row test now decides between marking a row and inserting one, and
  # `==` against a blank IRI is `NA`, so that test has to be NA-safe or this
  # package stops being writable at all.
  path <- review_fixture_package()
  review <- accept_handpicked(path)

  suggestions <- read_suggestions_file(path)
  blanked <- which(suggestions$column_name %in% "spawner_count" &
    suggestions$dictionary_role %in% "variable")[[2]]
  suggestions$iri[[blanked]] <- NA_character_
  readr::write_csv(suggestions, file.path(path, "semantic_suggestions.csv"), na = "")

  expect_no_error(suppressMessages(apply_sdp_semantics(path, review)))
  slot <- slot_rows(read_suggestions_file(path), "spawner_count", "variable")
  expect_equal(slot$iri[slot$decision %in% "accepted"], handpicked_iri)
})

test_that("a recorded hand-picked accept is not counted as ontology-gap evidence", {
  # A gap row claims that retrieval found no `smn` term, and the term-request
  # pipeline acts on that claim. The recorded row is a reviewer's decision, not
  # retrieval output. Counted, its blank `search_query` made it a target of its
  # own whose only candidate was not `smn`, so the post-review record reported
  # a gap for the slot the reviewer had just filled. This slot's retrieval
  # candidates are all non-`smn`, so they are a real gap before the review, and
  # after it they must be that one gap and nothing more.
  ols_hits <- function(query, role = NA_character_, ...) {
    if (!identical(as.character(role), "variable")) {
      return(tibble::tibble())
    }
    tibble::tibble(
      label = c("Fish count", "Tally"),
      iri = c("https://example.org/ols/FishCount", "https://example.org/ols/Tally"),
      source = "ols", ontology = "ols", role = "variable",
      match_type = "label_exact", definition = "A count.", score = c(4.5, 3.5)
    )
  }
  path <- file.path(withr::local_tempdir(), "gap-evidence")
  suppressMessages(with_mocked_bindings(
    find_terms = ols_hits,
    create_sdp(
      list(spawners = data.frame(spawner_count = c(120L, 340L))),
      path = path, dataset_id = "demo-1", semantic_max_per_role = 2,
      seed_semantics = TRUE, seed_verbose = FALSE, check_updates = FALSE,
      overwrite = TRUE
    )
  ))
  before <- suppressMessages(detect_semantic_term_gaps(suggestions = semantic_suggestions(path)))
  expect_equal(nrow(before), 1L)

  suppressMessages(apply_sdp_semantics(path, accept_handpicked(path)))
  record <- semantic_suggestions(path)
  # The premise: what the detector is fed carries the recorded row.
  expect_true(handpicked_iri %in% record$iri)

  after <- suppressMessages(detect_semantic_term_gaps(suggestions = record))
  expect_false(handpicked_iri %in% after$top_non_smn_iri)
  expect_equal(after, before)
})

# ---------------------------------------------------------------------------
# One decision, one `term_type` (hub queue B-221)
#
# `term_type` says what kind of thing `term_iri` names. `apply_sdp_semantics()`
# takes it from the review row a decision sits on when that row carries the
# accepted IRI, and writes `skos_concept` when it does not. `accept_suggestion(iri
# = )` put every decision on the slot's first row, so naming the IRI of a
# lower-ranked candidate wrote `skos_concept` whatever that candidate was. The
# review rebuilt from the package replays the same decision on the candidate's
# own row, and re-applying it wrote the candidate's type: one decision, two
# `term_type`s, and `column_dictionary.csv` changed between two applies of it.
# ---------------------------------------------------------------------------

owl_class_iri <- "https://example.org/ols/SpawnerCount"
owl_class_type_iri <- "http://www.w3.org/2002/07/owl#Class"

# A package whose `spawner_count` variable slot holds two candidates, an `smn`
# term and then `owl_class_iri`. `type_iris` is each one's type evidence, and a
# candidate with none reads as `skos_concept`.
typed_fixture_package <- function(type_iris = c(NA_character_, owl_class_type_iri)) {
  hits <- tibble::tibble(
    label = c("Spawner Abundance", "Spawner count"),
    iri = c("https://w3id.org/smn/SpawnerAbundance", owl_class_iri),
    source = c("smn", "ols"), ontology = c("smn", "ols"), role = "variable",
    match_type = "label_exact",
    definition = c("Mature salmon returning to spawn.", "A count of spawners."),
    score = c(4.9, 3.2),
    type_iris = type_iris
  )
  search <- function(query, role = NA_character_, ...) {
    if (identical(as.character(role), "variable")) hits else tibble::tibble()
  }
  path <- file.path(withr::local_tempdir(.local_envir = parent.frame()), "typed")
  suppressMessages(with_mocked_bindings(
    find_terms = search,
    create_sdp(
      list(spawners = data.frame(spawner_count = c(120L, 340L))),
      path = path, dataset_id = "demo-1", semantic_max_per_role = 2,
      seed_semantics = TRUE, seed_verbose = FALSE, check_updates = FALSE,
      overwrite = TRUE
    )
  ))
  path
}

variable_slot <- function(review) {
  review[review$column_name %in% "spawner_count" & review$role %in% "variable", , drop = FALSE]
}

test_that("hand-picking a lower-ranked owl_class candidate's IRI writes its term_type, and a rebuild re-applies the same bytes", {
  path <- typed_fixture_package()
  review <- suppressMessages(review_semantics(path))
  # The premise, asserted rather than assumed: the IRI is a candidate's below
  # rank 1, that candidate is an `owl_class`, and the rank-1 candidate is not.
  slot <- variable_slot(review)
  expect_equal(slot$rank[slot$iri %in% owl_class_iri], 2L)
  expect_equal(slot$term_type[slot$iri %in% owl_class_iri], "owl_class")
  expect_equal(slot$term_type[slot$rank == 1L], "skos_concept")

  suppressMessages(apply_sdp_semantics(
    path,
    accept_suggestion(review, "spawner_count", "variable", iri = owl_class_iri)
  ))
  dictionary <- read_metadata_file(path, "column_dictionary.csv")
  written <- dictionary[dictionary$column_name == "spawner_count", , drop = FALSE]
  expect_equal(written$term_iri, owl_class_iri)
  expect_equal(written$term_type, "owl_class")

  dictionary_path <- file.path(path, "metadata", "column_dictionary.csv")
  dictionary_bytes <- readBin(dictionary_path, "raw", file.info(dictionary_path)$size)
  first_apply <- managed_digests(path)

  # The rebuilt review carries the decision, on the candidate's own row, so
  # re-applying it is a second apply of the same decision.
  rebuilt <- suppressMessages(review_semantics(path, include_filled = TRUE))
  replayed <- variable_slot(rebuilt)
  replayed <- replayed[!is.na(replayed$decision), , drop = FALSE]
  expect_equal(replayed$decision, "accept")
  expect_equal(replayed$decision_iri, owl_class_iri)
  expect_equal(replayed$rank, 2L)

  suppressMessages(apply_sdp_semantics(path, rebuilt))
  expect_identical(
    readBin(dictionary_path, "raw", file.info(dictionary_path)$size),
    dictionary_bytes
  )
  # The descriptor carries `term_type` too, so it has to hold still as well.
  expect_identical(managed_digests(path), first_apply)
})

test_that("accept_suggestion(iri = ) naming a shortlisted candidate records what rank = records", {
  path <- typed_fixture_package()
  review <- suppressMessages(review_semantics(path))
  by_rank <- accept_suggestion(review, "spawner_count", "variable", rank = 2)
  expect_identical(
    accept_suggestion(review, "spawner_count", "variable", iri = owl_class_iri),
    by_rank
  )
  # The marker is stripped before the IRI is compared, so a marked spelling of
  # the candidate's IRI is the same decision.
  expect_identical(
    accept_suggestion(review, "spawner_count", "variable", iri = paste0("REVIEW: ", owl_class_iri)),
    by_rank
  )
})

test_that("an IRI no candidate carries still writes skos_concept, whatever the first candidate is", {
  # B-176's case, which this must not move. Nothing is known about a term the
  # reviewer typed, so the type of the row its decision is recorded on is not
  # evidence about it. Every candidate here is an `owl_class`, so a writer that
  # took the first row's type regardless would write `owl_class`.
  path <- typed_fixture_package(type_iris = rep(owl_class_type_iri, 2L))
  review <- suppressMessages(review_semantics(path))
  expect_equal(unique(variable_slot(review)$term_type), "owl_class")
  expect_false(handpicked_iri %in% review$iri)

  suppressMessages(apply_sdp_semantics(
    path,
    accept_suggestion(review, "spawner_count", "variable", iri = handpicked_iri)
  ))
  dictionary <- read_metadata_file(path, "column_dictionary.csv")
  expect_equal(
    dictionary$term_type[dictionary$column_name == "spawner_count"],
    "skos_concept"
  )
})
