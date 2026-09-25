# The R-native semantic review flow (stream S5, backlog #74 / #60).
#
# House style, deliberately NOT snapshots: the package holds zero
# `expect_snapshot` calls and `test-cli-safety.R` records why -- assertions must
# not couple to cli's rendering, and hyperlink output is terminal-dependent.
# Assertions run against `.ms_review_render_lines()`, which is the console view
# as a plain character vector.
#
# The load-bearing test in this file is "every printed call runs and produces
# the decision it claims". The whole feature rests on a printed string the user
# pastes; a call that does not parse, or that names a column that does not
# exist, is the way this ships broken. Both of those defects were live in the
# first working version -- a `tables.csv` slot printed
# `accept_suggestion(review, "NA", "entity", ...)`, and an unrelated dictionary
# slot printed a spurious `table = ` -- and this test is what found them.

fixture_suggestions <- function(...) {
  base <- tibble::tibble(
    dataset_id = "demo-1",
    table_id = "spawners",
    column_name = "spawner_count",
    code_value = NA_character_,
    dictionary_role = "variable",
    target_scope = "column",
    target_sdp_file = "column_dictionary.csv",
    target_sdp_field = "term_iri",
    target_row_key = "demo-1/spawners/spawner_count",
    label = "Spawner Abundance",
    iri = "https://w3id.org/smn/SpawnerAbundance",
    source = "smn",
    ontology = "smn",
    definition = "Mature salmon returning to spawn.",
    score = 4.9
  )
  overrides <- list(...)
  for (name in names(overrides)) {
    base[[name]] <- overrides[[name]]
  }
  base
}

fixture_dict <- function(...) {
  dict <- tibble::tibble(
    dataset_id = "demo-1",
    table_id = "spawners",
    column_name = "spawner_count",
    term_iri = NA_character_,
    property_iri = NA_character_,
    entity_iri = NA_character_,
    unit_iri = NA_character_
  )
  overrides <- list(...)
  for (name in names(overrides)) {
    dict[[name]] <- overrides[[name]]
  }
  dict
}

with_suggestions <- function(dict, suggestions) {
  attr(dict, "semantic_suggestions") <- suggestions
  dict
}

# ---------------------------------------------------------------------------
# M1 -- accessors (backlog #60)
# ---------------------------------------------------------------------------

test_that("semantic_suggestions() reads the attribute, the list element, and the package file", {
  dict <- with_suggestions(fixture_dict(), fixture_suggestions())
  expect_equal(semantic_suggestions(dict), tibble::as_tibble(fixture_suggestions()))

  artifacts <- list(dict = dict, semantic_suggestions = fixture_suggestions(label = "From list"))
  expect_equal(semantic_suggestions(artifacts)$label, "From list")

  # A list carrying only a dictionary falls through to the dictionary's own
  # attribute, which is the shape `infer_salmon_datapackage_artifacts()` returns
  # when seeding was off for the list but the dict was annotated later.
  expect_equal(semantic_suggestions(list(dict = dict))$label, "Spawner Abundance")

  package_dir <- withr::local_tempdir()
  readr::write_csv(fixture_suggestions(label = "From disk"), file.path(package_dir, "semantic_suggestions.csv"), na = "")
  expect_equal(semantic_suggestions(package_dir)$label, "From disk")
})

test_that("the accessors answer NULL exactly where attr() did", {
  # These are drop-in replacements for the documented `attr()` calls, so a
  # reader testing `is.null()` must keep working. An empty tibble would be a
  # silent behaviour change for every existing caller.
  expect_null(semantic_suggestions(fixture_dict()))
  expect_null(semantic_llm_assessments(fixture_dict()))
  expect_null(semantic_suggestions(list()))
  expect_null(semantic_suggestions(withr::local_tempdir()))
  # Assessments are never written into a package, so a path cannot carry them.
  expect_null(semantic_llm_assessments(withr::local_tempdir()))
})

test_that("semantic_llm_assessments() reads the attribute", {
  dict <- fixture_dict()
  attr(dict, "semantic_llm_assessments") <- tibble::tibble(llm_decision = "accept")
  expect_equal(semantic_llm_assessments(dict)$llm_decision, "accept")
})

test_that("the accessors refuse an input that is neither dictionary, list, nor path", {
  expect_error(semantic_suggestions(42), "must be a dictionary")
  expect_error(semantic_llm_assessments(NULL), "must be a dictionary")
})

# ---------------------------------------------------------------------------
# M2 -- console view
# ---------------------------------------------------------------------------

test_that("review_semantics() queues one slot per unfilled target and skips filled ones", {
  suggestions <- dplyr::bind_rows(
    fixture_suggestions(),
    fixture_suggestions(
      dictionary_role = "property",
      target_sdp_field = "property_iri",
      label = "Abundance",
      iri = "https://w3id.org/smn/Abundance",
      score = 4.1
    )
  )
  # `property_iri` is already final; `term_iri` still carries the marker.
  dict <- with_suggestions(
    fixture_dict(
      term_iri = "REVIEW: https://w3id.org/smn/SpawnerAbundance",
      property_iri = "https://w3id.org/smn/Abundance"
    ),
    suggestions
  )

  review <- review_semantics(dict)
  expect_s3_class(review, "ms_semantic_review")
  expect_equal(unique(review$role), "variable")

  # A `REVIEW:`-prefixed value is NOT blank -- which is exactly why the queue
  # cannot test for emptiness, and why the write-back has to overwrite.
  expect_equal(review$current_value, "REVIEW: https://w3id.org/smn/SpawnerAbundance")

  expect_equal(nrow(review_semantics(dict, include_filled = TRUE)), 2L)
})

test_that("review_semantics() never reaches a search or an LLM", {
  # LLM review is strictly opt-in and this function only reads what already
  # exists. A `stop()`ing binding is the sentinel: if the queue ever retrieves,
  # this fails rather than silently going to the network.
  dict <- with_suggestions(fixture_dict(), fixture_suggestions())
  with_mocked_bindings(
    find_terms = function(...) stop("review_semantics() must not search"),
    {
      review <- review_semantics(dict)
      expect_equal(nrow(review), 1L)
    }
  )
})

test_that("review_semantics() surfaces LLM review it did not generate", {
  suggestions <- fixture_suggestions()
  suggestions$llm_decision <- "accept"
  suggestions$llm_confidence <- 0.92
  suggestions$llm_rationale <- "The definition matches the column description."

  review <- review_semantics(with_suggestions(fixture_dict(), suggestions))
  lines <- .ms_review_render_lines(review)
  expect_true(any(grepl("llm: accept", lines, fixed = TRUE)))
  expect_true(any(grepl("confidence 0.92", lines, fixed = TRUE)))
  expect_true(any(grepl("The definition matches the column description.", lines, fixed = TRUE)))
})

test_that("review_semantics() refuses targets with no write-back address", {
  # `dataset.csv` targets a comma-joined `keywords` list, not a single IRI, so
  # it has no "accept this candidate" semantics. Showing a row nobody can
  # decide is the failure the execplan's decision log reversed itself over.
  suggestions <- fixture_suggestions(
    target_scope = "dataset",
    target_sdp_file = "dataset.csv",
    target_sdp_field = "keywords",
    target_row_key = "demo-1"
  )
  expect_message(
    review <- review_semantics(with_suggestions(fixture_dict(), suggestions)),
    "cannot decide"
  )
  expect_equal(nrow(review), 0L)
  # Silently dropping them would be the worse failure: the user would never
  # learn the field still needs an edit.
  expect_true(any(grepl(
    "Nothing left to review.",
    .ms_review_render_lines(review),
    fixed = TRUE
  )))
})

test_that("review_semantics() aborts when there is nothing to review", {
  expect_error(review_semantics(fixture_dict()), "No semantic suggestions to review")
})

test_that("the console prints a numbered shortlist with definition, IRI and current value", {
  suggestions <- dplyr::bind_rows(
    fixture_suggestions(),
    fixture_suggestions(label = "Escapement", iri = "https://w3id.org/smn/Escapement", score = 3.2)
  )
  review <- review_semantics(with_suggestions(fixture_dict(), suggestions))
  lines <- .ms_review_render_lines(review, object_name = "rev")

  expect_true(any(grepl("spawners · spawner_count · variable", lines, fixed = TRUE)))
  expect_true(any(grepl("current: <blank>", lines, fixed = TRUE)))
  expect_true(any(grepl("[1] Spawner Abundance", lines, fixed = TRUE)))
  expect_true(any(grepl("[2] Escapement", lines, fixed = TRUE)))
  expect_true(any(grepl("Mature salmon returning to spawn.", lines, fixed = TRUE)))
  expect_true(any(grepl("https://w3id.org/smn/SpawnerAbundance", lines, fixed = TRUE)))
  # The object name is the one the review is actually bound to, so the printed
  # call can be pasted as-is.
  expect_true(any(grepl("rev <- accept_suggestion(rev, ", lines, fixed = TRUE)))
})

test_that("max_candidates truncates the shortlist", {
  suggestions <- dplyr::bind_rows(
    fixture_suggestions(),
    fixture_suggestions(label = "Escapement", iri = "https://w3id.org/smn/Escapement"),
    fixture_suggestions(label = "Returns", iri = "https://w3id.org/smn/Returns")
  )
  dict <- with_suggestions(fixture_dict(), suggestions)
  expect_equal(nrow(review_semantics(dict, max_candidates = 2L)), 2L)
  expect_equal(nrow(review_semantics(dict, max_candidates = Inf)), 3L)
})

test_that("print() emits exactly the rendered lines", {
  review <- review_semantics(with_suggestions(fixture_dict(), fixture_suggestions()))
  printed <- capture.output(print(review))
  expect_equal(printed, .ms_review_render_lines(review, object_name = "review"))
})

# ---------------------------------------------------------------------------
# The printed call IS the contract
# ---------------------------------------------------------------------------

# Pull every pasteable decision line out of the console view and run it.
eval_printed_calls <- function(review, pattern) {
  lines <- .ms_review_render_lines(review, object_name = "review")
  calls <- grep(pattern, lines, fixed = TRUE, value = TRUE)
  expect_gt(length(calls), 0L)
  sub("^\\s*review <- ", "", trimws(calls))
}

test_that("every printed accept call parses and records the decision it claims", {
  suggestions <- dplyr::bind_rows(
    fixture_suggestions(),
    fixture_suggestions(label = "Escapement", iri = "https://w3id.org/smn/Escapement", score = 3.2),
    fixture_suggestions(
      dictionary_role = "property",
      target_sdp_field = "property_iri",
      label = "Abundance",
      iri = "https://w3id.org/smn/Abundance"
    ),
    # A second table using the SAME column name: this is what forces the
    # printed call to carry `table = `.
    fixture_suggestions(
      table_id = "surveys",
      target_row_key = "demo-1/surveys/spawner_count",
      label = "Spawner Abundance"
    ),
    # A table-level slot, which has NO column name at all. The first version of
    # this feature printed `"NA"` as the column here.
    fixture_suggestions(
      column_name = NA_character_,
      dictionary_role = "entity",
      target_scope = "table",
      target_sdp_file = "tables.csv",
      target_sdp_field = "observation_unit_iri",
      target_row_key = "demo-1/spawners",
      label = "Spawner",
      iri = "https://w3id.org/smn/Spawner"
    )
  )
  dict <- with_suggestions(
    dplyr::bind_rows(fixture_dict(), fixture_dict(table_id = "surveys")),
    suggestions
  )
  review <- review_semantics(dict)
  expect_true(any(is.na(review$column_name)))

  printed <- eval_printed_calls(review, "accept_suggestion(")
  for (text in printed) {
    decided <- eval(parse(text = text)[[1]], list(review = review), enclos = environment())
    expect_s3_class(decided, "ms_semantic_review")
    accepted <- decided[!is.na(decided$decision), , drop = FALSE]
    # Exactly one decision, and it is an accept whose IRI is the candidate the
    # line was printed under.
    expect_equal(nrow(accepted), 1L)
    expect_equal(accepted$decision, "accept")
    expect_equal(accepted$decision_iri, accepted$iri)
  }

  # And the same for the rejection line under every slot.
  for (text in eval_printed_calls(review, "reject_suggestion(")) {
    text <- sub("\\s+#.*$", "", text)
    decided <- eval(parse(text = text)[[1]], list(review = review), enclos = environment())
    rejected <- decided[!is.na(decided$decision), , drop = FALSE]
    expect_equal(unique(rejected$decision), "reject")
    expect_equal(length(unique(rejected$slot_id)), 1L)
  }
})

test_that("a column shared by two tables prints and resolves a table-qualified call", {
  suggestions <- dplyr::bind_rows(
    fixture_suggestions(),
    fixture_suggestions(table_id = "surveys", target_row_key = "demo-1/surveys/spawner_count")
  )
  dict <- with_suggestions(
    dplyr::bind_rows(fixture_dict(), fixture_dict(table_id = "surveys")),
    suggestions
  )
  review <- review_semantics(dict)
  lines <- .ms_review_render_lines(review)
  expect_true(any(grepl("table = \"spawners\"", lines, fixed = TRUE)))
  expect_true(any(grepl("table = \"surveys\"", lines, fixed = TRUE)))

  # Without the qualifier the call must refuse rather than pick one.
  expect_error(
    accept_suggestion(review, "spawner_count", "variable", rank = 1),
    "more than one review slot"
  )
})

# Every printed decision call, run, and checked against the slot and rank it was
# printed UNDER -- not only that it decides something. A call that resolves to a
# sibling slot passes a "one decision was recorded" check and writes the wrong
# field. The text run is the rendered line, so it is what a user pastes.
#
# The calls of every slot in `must_run` have to run. A slot left out of it may
# refuse as ambiguous, which is what a call does when nothing in its arguments
# can tell its slot apart, but no call may ever decide a slot other than the one
# it was printed under.
expect_printed_calls_decide_their_own_slots <- function(review, must_run = unique(review$slot_id)) {
  rendered <- sub("\\s+#.*$", "", trimws(.ms_review_render_lines(review, object_name = "review")))
  run <- function(call) {
    tryCatch(
      eval(parse(text = call)[[1]], list(review = review), enclos = environment()),
      error = identity
    )
  }
  refused <- function(slot, call, outcome) {
    expect_false(slot %in% must_run, info = paste(call, "->", conditionMessage(outcome)))
    expect_match(conditionMessage(outcome), "more than one review slot", info = call)
  }
  for (i in seq_len(nrow(review))) {
    slot <- review$slot_id[[i]]
    call <- .ms_review_accept_call(review, slot, review$rank[[i]])
    expect_true(paste0("review <- ", call) %in% rendered, info = call)
    decided <- run(call)
    if (inherits(decided, "error")) {
      refused(slot, call, decided)
      next
    }
    accepted <- decided[!is.na(decided$decision), , drop = FALSE]
    expect_equal(nrow(accepted), 1L, info = call)
    expect_equal(accepted$slot_id, slot, info = call)
    expect_equal(accepted$rank, review$rank[[i]], info = call)
  }
  for (slot in unique(review$slot_id)) {
    call <- .ms_review_reject_call(review, slot)
    expect_true(paste0("review <- ", call) %in% rendered, info = call)
    decided <- run(call)
    if (inherits(decided, "error")) {
      refused(slot, call, decided)
      next
    }
    expect_equal(unique(decided$slot_id[!is.na(decided$decision)]), slot, info = call)
  }
}

# Hub queue B-151. A measurement column's own `entity_iri` and `constraint_iri`
# targets share their roles with its codes' `codes.csv` targets, which a
# measurement parent gives the roles constraint, entity and method -- so one
# (column, role) pair names the column's own slot AND a slot per code. An
# omitted `code_value` matches every code, so the column's own slot printed
# `accept_suggestion(review, "spawner_count", "entity", rank = 1, table =
# "spawners")`, which matched three slots and aborted: the printed call that
# cannot run, which the header of R/review-console.R names as the defect this
# feature could most easily ship with. Built the way discovery builds it: the
# three roles of one code share that code's slot.
measurement_code_review <- function() {
  code_rows <- function(code) {
    dplyr::bind_rows(lapply(c("constraint", "entity", "method"), function(role) {
      fixture_suggestions(
        code_value = code,
        dictionary_role = role,
        target_scope = "code",
        target_sdp_file = "codes.csv",
        target_sdp_field = "term_iri",
        target_row_key = paste0("demo-1/spawners/spawner_count/", code),
        label = paste(role, "term for", code),
        iri = paste0("https://example.org/", role, "/", code)
      )
    }))
  }
  suggestions <- dplyr::bind_rows(
    fixture_suggestions(
      dictionary_role = "entity", target_sdp_field = "entity_iri",
      label = "Spawner", iri = "https://w3id.org/smn/Spawner"
    ),
    fixture_suggestions(
      dictionary_role = "constraint", target_sdp_field = "constraint_iri",
      label = "Wild origin", iri = "https://example.org/constraint/column"
    ),
    code_rows("-9"),
    code_rows("-99")
  )
  review_semantics(with_suggestions(fixture_dict(constraint_iri = NA_character_), suggestions))
}

measurement_column_slot <- "column_dictionary.csv|demo-1/spawners/spawner_count|entity_iri"

test_that("a measurement column with a code list prints a call that reaches its own slot", {
  review <- measurement_code_review()
  lines <- .ms_review_render_lines(review)
  expect_true(any(grepl(
    "accept_suggestion(review, \"spawner_count\", \"entity\", rank = 1, table = \"spawners\", code_value = \"\")",
    lines,
    fixed = TRUE
  )))
  expect_printed_calls_decide_their_own_slots(review)
})

test_that("a blank code_value selects the column's own slot, and an omitted one still matches every code", {
  review <- measurement_code_review()
  for (blank in list("", NA)) {
    decided <- accept_suggestion(review, "spawner_count", "entity", rank = 1, code_value = blank)
    expect_equal(unique(decided$slot_id[!is.na(decided$decision)]), measurement_column_slot)
  }
  # An omitted `code_value` still matches every code, as it always has. A call
  # printed for a code slot when that slot was the only one for its column and
  # role carries no `code_value`, and reading the omission as "no code value"
  # would re-point that pasted call at the column's own slot, or at nothing. So
  # the bare call still refuses rather than guessing.
  expect_error(
    accept_suggestion(review, "spawner_count", "entity", rank = 1),
    "more than one review slot"
  )
})

test_that("doing what the ambiguity refusal says reaches every slot it matched", {
  # The column's own option used to be a bare `table = "spawners"`, which
  # repeated the ambiguity instead of settling it, so a user who followed the
  # message could not reach that slot at all.
  review <- measurement_code_review()
  refused <- tryCatch(
    accept_suggestion(review, "spawner_count", "entity", rank = 1),
    error = identity
  )
  expect_match(conditionMessage(refused), "more than one review slot")
  options <- unname(refused$body[names(refused$body) == "*"])
  reached <- vapply(options, function(option) {
    call <- paste0("accept_suggestion(review, \"spawner_count\", \"entity\", rank = 1, ", option, ")")
    tryCatch({
      decided <- eval(parse(text = call)[[1]], list(review = review), enclos = environment())
      unique(decided$slot_id[!is.na(decided$decision)])
    }, error = function(e) NA_character_)
  }, character(1), USE.NAMES = FALSE)
  expect_setequal(reached, unique(review$slot_id[review$role %in% "entity"]))
})

# A code slot whose `codes.csv` row has no code value: the codes schema lets a
# row leave `code_value` empty when it supplies `vocabulary_iri`, and discovery
# still gives it a code-level target, with the three roles a measurement parent
# gives its codes (Codex review of pull request #153). Its `code_value` is as
# empty as the column's own slot's, so only the file tells the two apart.
vocabulary_code_review <- function() {
  code_rows <- dplyr::bind_rows(lapply(c("constraint", "entity", "method"), function(role) {
    fixture_suggestions(
      code_value = NA_character_,
      dictionary_role = role,
      target_scope = "code",
      target_sdp_file = "codes.csv",
      target_sdp_field = "term_iri",
      target_row_key = "demo-1/spawners/spawner_count/NA",
      label = paste(role, "term for the vocabulary"),
      iri = paste0("https://example.org/", role, "/vocabulary")
    )
  }))
  suggestions <- dplyr::bind_rows(
    fixture_suggestions(
      dictionary_role = "entity", target_sdp_field = "entity_iri",
      label = "Spawner", iri = "https://w3id.org/smn/Spawner"
    ),
    fixture_suggestions(
      dictionary_role = "constraint", target_sdp_field = "constraint_iri",
      label = "Wild origin", iri = "https://example.org/constraint/column"
    ),
    code_rows
  )
  review_semantics(with_suggestions(fixture_dict(constraint_iri = NA_character_), suggestions))
}

test_that("a blank code_value never selects a code slot whose codes.csv row has no code value", {
  review <- vocabulary_code_review()
  column_slots <- unique(review$slot_id[review$target_file != "codes.csv"])

  # The column's own slots print calls that run and decide them. The code
  # slot's own calls may still refuse, because no argument tells a code slot
  # with no code value apart from the column's own slot; that is a separate
  # defect, recorded in `.hub/workpads/B-151.md`. What no call may do is decide
  # the other slot.
  expect_printed_calls_decide_their_own_slots(review, must_run = column_slots)
  for (blank in list("", NA)) {
    decided <- accept_suggestion(review, "spawner_count", "entity", rank = 1, code_value = blank)
    expect_equal(unique(decided$slot_id[!is.na(decided$decision)]), measurement_column_slot)
  }

  # And the refusal offers the column's own slot an option that reaches it.
  refused <- tryCatch(
    accept_suggestion(review, "spawner_count", "entity", rank = 1),
    error = identity
  )
  options <- unname(refused$body[names(refused$body) == "*"])
  expect_true("table = \"spawners\", code_value = \"\"" %in% options)
  decided <- accept_suggestion(review, "spawner_count", "entity", rank = 1, table = "spawners", code_value = "")
  expect_equal(unique(decided$slot_id[!is.na(decided$decision)]), measurement_column_slot)
})

# Build a package through the real pipeline: `create_sdp()` with `find_terms`
# mocked, and `codes` seeded onto the measurement column `spawner_count`.
# `semantic_code_scope = "all"` is the documented option that gives a numeric
# column's codes semantic targets, and `suggest_semantics(codes = )` applies no
# scope at all.
measurement_code_package <- function(codes, name) {
  hits <- function(query, role = NA_character_, ...) {
    tibble::tibble(
      label = paste("Term", 1:2, "for", role),
      iri = paste0("https://example.org/candidates/", role, "Term", 1:2),
      source = "smn", ontology = "smn", role = role,
      match_type = "label_exact", definition = "A term.", score = c(4.5, 3.5)
    )
  }
  path <- file.path(withr::local_tempdir(.local_envir = parent.frame()), name)
  suppressMessages(with_mocked_bindings(
    find_terms = hits,
    create_sdp(
      list(spawners = data.frame(
        stream_name = rep(c("Bear Creek", "Elk River"), 6),
        spawner_count = c(120L, 340L, -9L, 88L, 17L, -99L, 5L, 9L, 10L, 11L, 12L, 13L)
      )),
      path = path, dataset_id = "demo-1", table_id = "spawners",
      semantic_max_per_role = 2, seed_semantics = TRUE, seed_codes = codes,
      semantic_code_scope = "all",
      seed_verbose = FALSE, check_updates = FALSE, overwrite = TRUE
    )
  ))
  path
}

# Paste the printed call for the column's own entity slot, apply it, and check
# it wrote the column's `entity_iri` and left `codes.csv` alone.
expect_column_call_writes_the_dictionary <- function(path, review) {
  read_csv_text <- function(file_name) {
    readr::read_csv(
      file.path(path, "metadata", file_name),
      col_types = readr::cols(.default = readr::col_character()),
      na = ""
    )
  }
  codes_before <- read_csv_text("codes.csv")
  call <- .ms_review_accept_call(review, measurement_column_slot, 1L)
  expect_match(call, "code_value = \"\"", fixed = TRUE)
  decided <- eval(parse(text = call)[[1]], list(review = review), enclos = environment())
  suppressMessages(apply_sdp_semantics(path, decided))

  chosen <- review$iri[review$slot_id == measurement_column_slot & review$rank == 1L]
  dictionary <- read_csv_text("column_dictionary.csv")
  expect_equal(
    dictionary$entity_iri[dictionary$column_name == "spawner_count"],
    .ms_strip_review_iri(chosen)
  )
  expect_equal(read_csv_text("codes.csv"), codes_before)
}

test_that("a measurement column with a code list round-trips from create_sdp() to disk", {
  path <- measurement_code_package(
    tibble::tibble(
      dataset_id = "demo-1", table_id = "spawners", column_name = "spawner_count",
      code_value = c("-9", "-99"),
      code_label = c("Not surveyed", "Survey abandoned"),
      code_description = c("The reach was not surveyed.", "The survey was abandoned.")
    ),
    "measurement-codes"
  )
  review <- suppressMessages(review_semantics(path))

  code_slots <- paste0("codes.csv|demo-1/spawners/spawner_count/", c("-9", "-99"), "|term_iri")
  # The collision is real: the column's own slot and both code slots answer to
  # (spawner_count, entity), and the same holds for constraint.
  expect_true(all(c(measurement_column_slot, code_slots) %in% review$slot_id[review$role %in% "entity"]))
  expect_true(all(code_slots %in% review$slot_id[review$role %in% "constraint"]))

  expect_printed_calls_decide_their_own_slots(review)
  expect_column_call_writes_the_dictionary(path, review)
})

test_that("a measurement column whose codes.csv row names a vocabulary round-trips from create_sdp() to disk", {
  # The Codex finding on pull request #153, through the real pipeline: the
  # column's only `codes.csv` row supplies `vocabulary_iri` and no code value.
  path <- measurement_code_package(
    tibble::tibble(
      dataset_id = "demo-1", table_id = "spawners", column_name = "spawner_count",
      code_value = NA_character_,
      code_label = "Count categories",
      code_description = "Counts are recorded against a published category vocabulary.",
      vocabulary_iri = "https://example.org/vocab/count-categories"
    ),
    "vocabulary-codes"
  )
  review <- suppressMessages(review_semantics(path))

  code_slot <- "codes.csv|demo-1/spawners/spawner_count/NA|term_iri"
  expect_true(all(c(measurement_column_slot, code_slot) %in% review$slot_id[review$role %in% "entity"]))

  column_slots <- unique(review$slot_id[review$target_file != "codes.csv"])
  expect_printed_calls_decide_their_own_slots(review, must_run = column_slots)
  expect_column_call_writes_the_dictionary(path, review)
})

test_that("a single-table review prints the short call, with no needless qualifier", {
  review <- review_semantics(with_suggestions(fixture_dict(), fixture_suggestions()))
  lines <- .ms_review_render_lines(review)
  expect_true(any(grepl(
    "accept_suggestion(review, \"spawner_count\", \"variable\", rank = 1)",
    lines,
    fixed = TRUE
  )))
  expect_false(any(grepl("table = ", lines, fixed = TRUE)))
})

# ---------------------------------------------------------------------------
# External text and link safety
# ---------------------------------------------------------------------------

test_that("braces in an ontology definition print literally", {
  # The console prints third-party text by design, so this is the package's
  # highest-risk surface for the cli-template defect. `print()` uses `cat()`,
  # which has no template layer -- pinned here because a static guard cannot
  # see a path it does not model.
  suggestions <- fixture_suggestions(
    definition = "Count of {Sys.getenv(\"HOME\")} spawners",
    label = "Braced {label}"
  )
  review <- review_semantics(with_suggestions(fixture_dict(), suggestions))
  lines <- .ms_review_render_lines(review)
  printed <- capture.output(print(review))

  expect_true(any(grepl("{Sys.getenv(\"HOME\")}", lines, fixed = TRUE)))
  expect_true(any(grepl("{Sys.getenv(\"HOME\")}", printed, fixed = TRUE)))
  expect_true(any(grepl("Braced {label}", printed, fixed = TRUE)))
  expect_false(any(grepl(Sys.getenv("HOME"), printed, fixed = TRUE)))
  # And not double-escaped either: escaping here would corrupt the very text
  # the rule exists to protect.
  expect_false(any(grepl("{{", printed, fixed = TRUE)))
})

test_that("a column name that would break a cli template is escaped in the abort", {
  review <- review_semantics(with_suggestions(fixture_dict(), fixture_suggestions()))
  # An unbalanced brace replaces the message with a parse error when it reaches
  # cli unescaped.
  expect_error(
    accept_suggestion(review, "rate{pct", "variable"),
    "No review slot matches"
  )
})

test_that(".ms_term_browse_url() refuses every scheme that is not http/https", {
  expect_true(is.na(.ms_term_browse_url("javascript:alert(1)", "smn", "smn")))
  expect_true(is.na(.ms_term_browse_url("file:///etc/passwd", "smn", "smn")))
  expect_true(is.na(.ms_term_browse_url("urn:uuid:1234", "smn", "smn")))
  expect_true(is.na(.ms_term_browse_url("", "smn", "smn")))
  expect_equal(
    .ms_term_browse_url("https://w3id.org/smn/Spawner", "smn", "smn"),
    "https://w3id.org/smn/Spawner"
  )
  expect_true(startsWith(
    .ms_term_browse_url("http://purl.obolibrary.org/obo/UO_0000027", "ols", "uo"),
    "https://www.ebi.ac.uk/ols4/ontologies/uo/classes/"
  ))
})

test_that("an unlinkable IRI is never turned into a terminal hyperlink", {
  suggestions <- fixture_suggestions(iri = "javascript:alert(1)")
  review <- review_semantics(with_suggestions(fixture_dict(), suggestions))
  with_mocked_bindings(
    .package = "cli",
    ansi_has_hyperlink_support = function() TRUE,
    {
      lines <- .ms_review_render_lines(review)
      expect_true(any(grepl("javascript:alert(1)", lines, fixed = TRUE)))
      expect_false(any(grepl("\033]8;;", lines, fixed = TRUE)))
    }
  )
})

test_that("the IRI stays visible when the terminal has no hyperlink support", {
  # cli's own fallback drops the URL entirely when the link text differs from
  # it, which would hide the OLS deep link. The fallback is written out rather
  # than inherited, and this is what pins that.
  suggestions <- fixture_suggestions(
    iri = "http://purl.obolibrary.org/obo/UO_0000027",
    source = "ols",
    ontology = "uo"
  )
  review <- review_semantics(with_suggestions(fixture_dict(), suggestions))
  with_mocked_bindings(
    .package = "cli",
    ansi_has_hyperlink_support = function() FALSE,
    {
      lines <- .ms_review_render_lines(review)
      expect_true(any(grepl("http://purl.obolibrary.org/obo/UO_0000027", lines, fixed = TRUE)))
      expect_true(any(grepl("https://www.ebi.ac.uk/ols4/", lines, fixed = TRUE)))
    }
  )
})

# ---------------------------------------------------------------------------
# M3 -- decisions
# ---------------------------------------------------------------------------

test_that("accept_suggestion() is pipe-friendly and keeps one decision per slot", {
  suggestions <- dplyr::bind_rows(
    fixture_suggestions(),
    fixture_suggestions(label = "Escapement", iri = "https://w3id.org/smn/Escapement")
  )
  review <- review_semantics(with_suggestions(fixture_dict(), suggestions)) |>
    accept_suggestion("spawner_count", "variable", rank = 2) |>
    accept_suggestion("spawner_count", "variable", rank = 1)

  decided <- review[!is.na(review$decision), , drop = FALSE]
  expect_equal(nrow(decided), 1L)
  expect_equal(decided$decision_iri, "https://w3id.org/smn/SpawnerAbundance")
})

test_that("accept_suggestion() strips the REVIEW: prefix from a decided IRI", {
  suggestions <- fixture_suggestions(iri = "REVIEW: https://w3id.org/smn/SpawnerAbundance")
  review <- review_semantics(with_suggestions(fixture_dict(), suggestions)) |>
    accept_suggestion("spawner_count", "variable", rank = 1)
  expect_equal(
    review$decision_iri[!is.na(review$decision)],
    "https://w3id.org/smn/SpawnerAbundance"
  )
})

test_that("accept_suggestion(iri =) takes a term retrieval never surfaced", {
  review <- review_semantics(with_suggestions(fixture_dict(), fixture_suggestions())) |>
    accept_suggestion("spawner_count", "variable", iri = "https://w3id.org/smn/WaterTemperature")
  expect_equal(
    review$decision_iri[!is.na(review$decision)],
    "https://w3id.org/smn/WaterTemperature"
  )
  expect_error(
    accept_suggestion(review, "spawner_count", "variable", iri = "  "),
    "non-empty IRI"
  )
})

# An `iri =` that is empty once its `REVIEW:` marker is stripped (hub item
# B-219). The non-empty check read `iri` before the strip, so the bare marker
# passed it and the accept recorded an IRI that named no term.
# `apply_sdp_semantics()` then cleared the field and wrote an `accepted` row
# with an empty `iri` into `semantic_suggestions.csv`.
#
# One test per spelling `.ms_strip_review_iri()` removes, because the check has
# to agree with the strip. Which spellings count as the marker is hub question
# Q-63, so this list is what the strip removes today, not a ruling, and it
# follows the strip: when Q-63 is ruled, a spelling the ruling drops leaves the
# list and one it adds joins it. Each test asserts that premise first, so a
# change to the strip fails here and names the spelling rather than leaving a
# test that checks nothing.
marker_only_iris <- c(
  "the bare marker" = "REVIEW:",
  "the marker as the package writes it" = .ms_review_iri_prefix(),
  "lower case" = "review:",
  "mixed case" = "Review:",
  "a space before the colon" = "REVIEW :",
  "a tab before the colon" = "REVIEW\t:",
  "leading spaces" = "  REVIEW:",
  # `.ms_scalar_text()` trims spaces, tabs and newlines. A form feed survives
  # the trim, and only the strip's `\s*` removes it.
  "a form feed after the colon" = "REVIEW:\f"
)

for (spelling in names(marker_only_iris)) {
  test_that(paste0("accept_suggestion() refuses an `iri` that is only the REVIEW: marker: ", spelling), {
    marker <- marker_only_iris[[spelling]]
    expect_identical(.ms_strip_review_iri(.ms_scalar_text(marker)), "")

    review <- review_semantics(with_suggestions(fixture_dict(), fixture_suggestions()))
    expect_error(
      accept_suggestion(review, "spawner_count", "variable", iri = marker),
      "non-empty IRI"
    )
  })
}

test_that("accept_suggestion(iri =) still takes a marked IRI, and records it without the marker", {
  review <- review_semantics(with_suggestions(fixture_dict(), fixture_suggestions())) |>
    accept_suggestion("spawner_count", "variable", iri = "review : https://w3id.org/smn/WaterTemperature")
  expect_equal(
    review$decision_iri[!is.na(review$decision)],
    "https://w3id.org/smn/WaterTemperature"
  )
})

# The routes B-219 left open to a decision that names no term (hub item B-246).
# A shortlisted candidate whose `iri` is only the marker was queued, because the
# queue tested only that `iri` was not blank, so `rank =` accepted it with an
# empty `decision_iri`, and a recorded accept of one replayed the same way. The
# strip removes one marker, so a doubled one left a marker in the decision on
# either route. No producer writes such a candidate; a hand-edited or external
# suggestions table does. The spellings are `marker_only_iris` above, which
# follows the strip, and each test asserts its premise first for the same reason
# those tests do.

for (spelling in names(marker_only_iris)) {
  test_that(paste0("a candidate that is only the REVIEW: marker is not queued, so rank = cannot accept it: ", spelling), {
    marker <- marker_only_iris[[spelling]]
    expect_identical(.ms_strip_review_iri(.ms_scalar_text(marker)), "")

    alone <- review_semantics(with_suggestions(fixture_dict(), fixture_suggestions(iri = marker)))
    expect_equal(nrow(alone), 0L)
    expect_error(
      accept_suggestion(alone, "spawner_count", "variable", rank = 1),
      "No review slot matches"
    )

    # Ahead of a real candidate it does not take rank 1 from it, and dropping it
    # is not reported as a field the review cannot decide.
    suggestions <- dplyr::bind_rows(
      fixture_suggestions(label = "Marker only", iri = marker),
      fixture_suggestions()
    )
    expect_no_message(
      review <- review_semantics(with_suggestions(fixture_dict(), suggestions)),
      message = "cannot decide"
    )
    review <- accept_suggestion(review, "spawner_count", "variable", rank = 1)
    expect_equal(
      review$decision_iri[!is.na(review$decision)],
      "https://w3id.org/smn/SpawnerAbundance"
    )
  })
}

for (spelling in names(marker_only_iris)) {
  test_that(paste0("a recorded accept of a candidate that is only the REVIEW: marker replays no empty IRI: ", spelling), {
    marker <- marker_only_iris[[spelling]]
    expect_identical(.ms_strip_review_iri(.ms_scalar_text(marker)), "")

    suggestions <- dplyr::bind_rows(
      fixture_suggestions(label = "Marker only", iri = marker),
      fixture_suggestions()
    )
    suggestions$decision <- c("accepted", "not_selected")
    data <- with_suggestions(fixture_dict(), suggestions)

    rebuilt <- review_semantics(data, include_filled = TRUE)
    expect_false(any(rebuilt$decision %in% "accept" & rebuilt$decision_iri %in% ""))
    # That accept named no term, so it decided nothing: the slot is asked again.
    queued <- review_semantics(data)
    expect_equal(queued$iri, "https://w3id.org/smn/SpawnerAbundance")
    expect_true(all(is.na(queued$decision)))
  })
}

# What each of these leaves once `.ms_strip_review_iri()` has run is still read
# as a marker by `.ms_is_review_iri()`.
doubled_marker_iris <- c(
  "twice, with nothing after" = "REVIEW: REVIEW:",
  "twice, with no space between" = "REVIEW:REVIEW:",
  "twice, in two cases" = "review : Review:",
  "twice, before a term" = "REVIEW: REVIEW: https://w3id.org/smn/WaterTemperature"
)

for (spelling in names(doubled_marker_iris)) {
  test_that(paste0("no accept records an IRI that is still a REVIEW: marker once one is stripped: ", spelling), {
    doubled <- doubled_marker_iris[[spelling]]
    expect_true(.ms_is_review_iri(.ms_strip_review_iri(.ms_scalar_text(doubled))))

    review <- review_semantics(with_suggestions(fixture_dict(), fixture_suggestions()))
    expect_error(
      accept_suggestion(review, "spawner_count", "variable", iri = doubled),
      "not a .?REVIEW:.? marker"
    )

    # On a shortlisted candidate it is not queued, so neither `rank =` nor a
    # recorded accept of it can put it in a decision.
    suggestions <- dplyr::bind_rows(
      fixture_suggestions(label = "Doubled marker", iri = doubled),
      fixture_suggestions()
    )
    review <- review_semantics(with_suggestions(fixture_dict(), suggestions)) |>
      accept_suggestion("spawner_count", "variable", rank = 1)
    decided <- review$decision_iri[!is.na(review$decision)]
    expect_false(.ms_is_review_iri(decided))
    expect_equal(decided, "https://w3id.org/smn/SpawnerAbundance")

    suggestions$decision <- c("accepted", "not_selected")
    rebuilt <- review_semantics(with_suggestions(fixture_dict(), suggestions), include_filled = TRUE)
    replayed <- rebuilt$decision_iri[rebuilt$decision %in% "accept"]
    expect_false(any(vapply(replayed, .ms_is_review_iri, logical(1))))
  })
}

# A row with no IRI targets a field the review does decide, so it is not one of
# the fields "this review cannot decide", and editing the metadata CSV by hand
# is not what it needs. The shape B-219 left in a package: a hand-picked
# `accepted` row with an empty `iri` at the head of its slot.
empty_iris <- c("an empty string" = "", "a missing value" = NA_character_)

for (form in names(empty_iris)) {
  test_that(paste0("review_semantics() does not report a row with no IRI as a field it cannot decide: ", form), {
    suggestions <- dplyr::bind_rows(
      fixture_suggestions(iri = empty_iris[[form]], source = "user", decision = "accepted"),
      fixture_suggestions(decision = "not_selected")
    )
    expect_no_message(
      review <- review_semantics(with_suggestions(fixture_dict(), suggestions)),
      message = "cannot decide"
    )
    expect_equal(review$iri, "https://w3id.org/smn/SpawnerAbundance")
    expect_true(all(is.na(review$decision)))

    # A field the review cannot decide is still reported, and alone.
    suggestions <- dplyr::bind_rows(
      suggestions,
      fixture_suggestions(
        target_scope = "dataset",
        target_sdp_file = "dataset.csv",
        target_sdp_field = "keywords",
        target_row_key = "demo-1"
      )
    )
    reported <- character()
    withCallingHandlers(
      review_semantics(with_suggestions(fixture_dict(), suggestions)),
      message = function(condition) {
        reported <<- c(reported, conditionMessage(condition))
        invokeRestart("muffleMessage")
      }
    )
    reported <- paste(reported, collapse = "\n")
    expect_match(reported, "cannot decide", fixed = TRUE)
    expect_match(reported, "dataset.csv", fixed = TRUE)
    expect_no_match(reported, "column_dictionary.csv", fixed = TRUE)
  })
}

test_that("accept_suggestion() rejects a rank that is not in the shortlist", {
  review <- review_semantics(with_suggestions(fixture_dict(), fixture_suggestions()))
  expect_error(
    accept_suggestion(review, "spawner_count", "variable", rank = 7),
    "No candidate with that"
  )
})

test_that("reject_suggestion() marks the whole slot and records a reason", {
  suggestions <- dplyr::bind_rows(
    fixture_suggestions(),
    fixture_suggestions(label = "Escapement", iri = "https://w3id.org/smn/Escapement")
  )
  review <- reject_suggestion(
    review_semantics(with_suggestions(fixture_dict(), suggestions)),
    "spawner_count", "variable",
    reason = "no candidate describes a wild-origin count"
  )
  expect_equal(unique(review$decision), "reject")
  expect_true(all(is.na(review$decision_iri)))
  lines <- .ms_review_render_lines(review)
  expect_true(any(grepl("DECIDED: reject", lines, fixed = TRUE)))
  expect_true(any(grepl("no candidate describes a wild-origin count", lines, fixed = TRUE)))
})

test_that("the decision helpers refuse an object that is not a review", {
  expect_error(accept_suggestion(tibble::tibble(), "a", "variable"), "ms_semantic_review")
  expect_error(reject_suggestion(tibble::tibble(), "a", "variable"), "ms_semantic_review")
})

# --------------------------------------------------------------------------
# Decisions survive the round trip (found while extending this API for M4)
# --------------------------------------------------------------------------
#
# These three came out of writing a lesson against the M1-M3 API, which is the
# harshest usability test an API gets. All three are the same shape: the
# feature did the right thing once and then forgot it.

test_that("a recorded decision takes its slot out of the next review", {
  # A reject CLEARS the field, a blank field reads as undecided, and nothing
  # read the `decision` column back -- so a reviewer who worked through the
  # queue, rejected four slots and came back the next day was asked the same
  # four questions with no sign they had ever answered them. The round trip is
  # the point of persisting the decision at all.
  suggestions <- fixture_suggestions()
  suggestions$decision <- "rejected"
  suggestions$decision_reason <- "no candidate describes a wild-origin count"

  review <- review_semantics(with_suggestions(fixture_dict(), suggestions))
  expect_equal(nrow(review), 0L)

  revisited <- review_semantics(
    with_suggestions(fixture_dict(), suggestions),
    include_filled = TRUE
  )
  expect_equal(revisited$decision, "reject")
  lines <- .ms_review_render_lines(revisited)
  expect_true(any(grepl("DECIDED: reject", lines, fixed = TRUE)))
  expect_true(any(grepl("no candidate describes a wild-origin count", lines, fixed = TRUE)))
})

test_that("a recorded acceptance comes back with the IRI it accepted", {
  suggestions <- dplyr::bind_rows(
    fixture_suggestions(),
    fixture_suggestions(label = "Escapement", iri = "https://w3id.org/smn/Escapement")
  )
  suggestions$decision <- c("not_selected", "accepted")

  review <- review_semantics(
    with_suggestions(fixture_dict(), suggestions),
    include_filled = TRUE
  )
  expect_equal(review$decision, c(NA, "accept"))
  expect_equal(review$decision_iri[[2]], "https://w3id.org/smn/Escapement")
})

test_that("a columns filter that matches nothing says so instead of reporting success", {
  # The empty-queue message reads as completion -- "every slot that had a
  # shortlist already holds a final IRI". Printing it after a typo told the
  # user their package was finished when nothing had been reviewed at all.
  expect_error(
    review_semantics(with_suggestions(fixture_dict(), fixture_suggestions()), columns = "TYPO"),
    "No suggestions target"
  )
  expect_error(
    review_semantics(with_suggestions(fixture_dict(), fixture_suggestions()), columns = "TYPO"),
    "spawner_count"
  )
  # A column that exists but has nothing left to decide is NOT an error: that
  # is the message doing its job.
  filled <- fixture_dict(term_iri = "https://w3id.org/smn/SpawnerAbundance")
  review <- review_semantics(
    with_suggestions(filled, fixture_suggestions()),
    columns = "spawner_count"
  )
  expect_equal(nrow(review), 0L)
})
