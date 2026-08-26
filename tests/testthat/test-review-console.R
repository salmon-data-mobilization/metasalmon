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
