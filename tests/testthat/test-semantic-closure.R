# Tests for `write_sdp_semantic_closure()` (backlog #116, hub item B-116).
#
# The load-bearing assertion in most of these is not "a file appeared" but "the
# validator that previously had no producer accepts what the producer wrote":
# `.ms_eml_read_vocabulary()` and `.ms_eml_read_semantic_review()` are the two
# gates that made this gap visible, so they are the oracle here.
#
# Every test is offline. `search_fn` is injected, so no test reaches w3id.org.

# A deterministic stand-in for `find_terms()`, keyed by the query text so that
# the IRI-to-query derivation is exercised rather than bypassed. It records its
# calls, which is how the "no search when fully hand-supplied" test proves a
# negative.
closure_search_index <- function() {
  tibble::tribble(
    ~query, ~iri, ~label, ~definition, ~source, ~ontology, ~resource_kind, ~type_iris,
    "observed rate or abundance", "https://w3id.org/smn/ObservedRateOrAbundance",
    "Observed rate or abundance", "An empirically observed compound measurement variable.",
    "smn", "smn", "Class", "http://www.w3.org/2002/07/owl#Class",
    "stock", "https://w3id.org/smn/Stock", "Stock",
    "An operationally defined grouping of salmon.",
    "smn", "smn", "Class", "http://www.w3.org/2002/07/owl#Class",
    "observation", "https://w3id.org/smn/Observation", "Observation",
    "An act of observing a property of a feature of interest.",
    "smn", "smn", "Class", "http://www.w3.org/2002/07/owl#Class"
  )
}

closure_search_stub <- function(index = NULL, calls = NULL) {
  index <- index %||% closure_search_index()
  function(query, role = NA_character_, sources = NULL, ...) {
    if (!is.null(calls)) {
      calls$queries <- c(calls$queries, query)
    }
    hits <- index[index$query == query, , drop = FALSE]
    hits$score <- rep(0.9, nrow(hits))
    hits[, setdiff(names(hits), "query"), drop = FALSE]
  }
}

# The two QUDT rows the fixture's dictionary uses. QUDT is not a searchable
# source, so this is what a hand-authored `evidence` row looks like.
closure_qudt_evidence <- function() {
  tibble::tribble(
    ~iri, ~label, ~definition, ~source, ~ontology, ~resource_kind, ~type_iris,
    ~native_type, ~source_url, ~confidence, ~review_rationale,
    "http://qudt.org/vocab/quantitykind/Count", "Count",
    "A quantity kind for counts.", "qudt", "qudt", "QuantityKind",
    "http://qudt.org/schema/qudt/QuantityKind", "qudt:QuantityKind",
    "https://qudt.org/3.1.1/vocab/quantitykind/", "high",
    "The column contains abundance counts.",
    "http://qudt.org/vocab/unit/COUNT", "Count",
    "A counting unit.", "qudt", "qudt", "Unit",
    "http://qudt.org/schema/qudt/Unit", "qudt:Unit",
    "https://qudt.org/3.1.1/vocab/unit/", "high",
    "The values use the reviewed counting unit."
  )
}

# What a reviewer actually supplies: the QUDT rows in full, plus their own
# judgement on every other target. Term evidence for the smn IRIs is left to
# the search, which is the division of labour the function is built around.
closure_reviewed_evidence <- function() {
  dplyr::bind_rows(
    closure_qudt_evidence(),
    tibble::tribble(
      ~iri, ~confidence, ~review_rationale,
      "https://w3id.org/smn/ObservedRateOrAbundance", "medium",
      "The reviewed measurement type is intentionally broad.",
      "https://w3id.org/smn/Stock", "high",
      "The counts describe a salmon stock.",
      "https://w3id.org/smn/Observation", "high",
      "The row grain is an observation."
    )
  )
}

# The fixture with an invented `term_iri`: every rationale supplied, so the only
# warning a run can raise is the gap itself.
closure_unresolvable_evidence <- function() {
  dplyr::bind_rows(
    closure_reviewed_evidence(),
    tibble::tribble(
      ~iri, ~confidence, ~review_rationale,
      "https://w3id.org/smn/NoSuchTermHere", "low",
      "Placeholder selection pending a minted term."
    )
  )
}

closure_full_evidence <- function() {
  dplyr::bind_rows(
    closure_qudt_evidence(),
    tibble::tribble(
      ~iri, ~label, ~definition, ~source, ~ontology, ~resource_kind, ~type_iris,
      ~native_type, ~source_url, ~confidence, ~review_rationale,
      "https://w3id.org/smn/ObservedRateOrAbundance", "Observed rate or abundance",
      "An empirically observed compound measurement variable.", "smn", "smn",
      "Class", "http://www.w3.org/2002/07/owl#Class", "owl:Class",
      "https://w3id.org/smn/", "medium",
      "The reviewed measurement type is intentionally broad.",
      "https://w3id.org/smn/Stock", "Stock",
      "An operationally defined grouping of salmon.", "smn", "smn", "Class",
      "http://www.w3.org/2002/07/owl#Class", "owl:Class",
      "https://w3id.org/smn/", "high", "The counts describe a salmon stock.",
      "https://w3id.org/smn/Observation", "Observation",
      "An act of observing a property of a feature of interest.", "smn", "smn",
      "Class", "http://www.w3.org/2002/07/owl#Class", "owl:Class",
      "https://w3id.org/smn/", "high", "The row grain is an observation."
    )
  )
}

# Removes the closure the fixture pre-writes, so a test cannot pass by reading
# what the helper already put there.
closure_clear <- function(path) {
  unlink(file.path(path, "metadata", "semantic_vocabulary.csv"))
  unlink(file.path(path, "reviewed_semantic_selections.csv"))
  invisible(path)
}

test_that("the vocabulary field order matches the digest verifier exactly", {
  # The digest is over these ten values joined by "\r". If the producer's field
  # list and the verifier's ever diverge, every hash the producer writes is
  # wrong and `.ms_eml_read_vocabulary()` rejects a file it should accept, with
  # a message that does not say why. Reading the verifier's own vector is the
  # only way to pin this without restating it.
  verifier <- body(.ms_eml_vocabulary_snapshot_sha256)
  fields <- eval(verifier[[2]][[3]])
  expect_identical(fields, .ms_closure_vocabulary_fields())
})

test_that("the two canonical sets differ and the producer derives both", {
  path <- withr::local_tempdir()
  make_eml_test_sdp(path)
  closure_clear(path)

  closure <- write_sdp_semantic_closure(
    path,
    evidence = closure_reviewed_evidence(),
    search_fn = closure_search_stub(),
    quiet = TRUE
  )

  # The bundled-fixture difference, which is the same shape the shipped Fraser
  # coho example has: the table-level observation unit is a review target and
  # not a measurement vocabulary term.
  expect_identical(
    setdiff(closure$review_targets$iri, closure$measurement_iris),
    "https://w3id.org/smn/Observation"
  )
  expect_identical(
    setdiff(closure$measurement_iris, closure$review_targets$iri),
    character()
  )
  expect_identical(nrow(closure$vocabulary), 4L)
  expect_identical(nrow(closure$review), 5L)
  expect_identical(nrow(closure$gaps), 0L)
})

# ---------------------------------------------------------------------------
# The other direction (hub item B-171). The test above pins the one difference
# the bundled fixture has: a table's `observation_unit_iri` is a review target
# and not a vocabulary term. The reverse -- an IRI reached through a code value,
# which is a vocabulary term and not a review target -- had no fixture until
# B-171, so no test reached the role fallback in `.ms_closure_iri_roles()` that
# such an IRI is searched under.
# ---------------------------------------------------------------------------

# `make_eml_test_sdp()` plus one row-varying procedure column. `estimate_method`
# is bound to the `count` measure as `sosa:usedProcedure` in an observation
# structure, and each of its code values resolves through codes.csv `term_iri`.
# The EML method path emits both IRIs, so both are canonical measurement IRIs;
# no dictionary or table slot holds either, so neither is a review target.
make_closure_procedure_sdp <- function(path) {
  make_eml_test_sdp(path)
  pkg <- read_salmon_datapackage(path)

  resources <- pkg$resources
  resources$counts$estimate_method <- c("mark_recapture", "expanded_count")
  dictionary <- dplyr::bind_rows(
    pkg$dictionary,
    tibble::tibble(
      dataset_id = "demo-salmon-2026",
      table_id = "counts",
      column_name = "estimate_method",
      column_label = "Estimate method",
      column_description = "Row-varying count estimation procedure.",
      column_role = "categorical",
      value_type = "string",
      term_type = "skos_concept",
      required = TRUE
    )
  )
  codes <- tibble::tribble(
    ~dataset_id, ~table_id, ~column_name, ~code_value, ~code_label,
    ~code_description, ~vocabulary_iri, ~term_iri, ~term_type,
    "demo-salmon-2026", "counts", "estimate_method", "mark_recapture",
    "Mark-recapture estimate", "Mark-recapture procedure", NA_character_,
    "https://example.org/methods/mark-recapture", "owl_named_individual",
    "demo-salmon-2026", "counts", "estimate_method", "expanded_count",
    "Expanded count", "Expanded-count procedure", NA_character_,
    "https://example.org/methods/expanded-count", "owl_named_individual"
  )
  # Rewritten in place. Without `prune` the writer replaces only the files it
  # owns, so the EML sidecar `make_eml_test_sdp()` wrote is kept.
  write_salmon_datapackage(
    resources = resources,
    dataset_meta = pkg$dataset,
    table_meta = pkg$tables,
    dict = dictionary,
    codes = codes,
    path = path,
    overwrite = TRUE
  )
  write_sdp_observation_structures(
    path,
    structures = tibble::tibble(
      dataset_id = "demo-salmon-2026",
      table_id = "counts",
      observation_structure_id = "count_by_record",
      structure_label = "Count by record",
      structure_description = "One count observation per record."
    ),
    components = tibble::tribble(
      ~dataset_id, ~table_id, ~observation_structure_id, ~component_order,
      ~column_name, ~component_role, ~component_relation_iri,
      ~required_when_observed,
      "demo-salmon-2026", "counts", "count_by_record", 1L,
      "record_id", "dimension", NA_character_, TRUE,
      "demo-salmon-2026", "counts", "count_by_record", 2L,
      "count", "measure", NA_character_, TRUE,
      "demo-salmon-2026", "counts", "count_by_record", 3L,
      "estimate_method", "attribute",
      "http://www.w3.org/ns/sosa/usedProcedure", TRUE
    )
  )
  invisible(path)
}

# The procedures as the search knows them, one query each: the IRI's local name,
# which is the query the producer derives when no review trail exists. Shaped
# like the procedure row `add_table_method_to_review_closure()` writes.
closure_procedure_search_index <- function() {
  tibble::tribble(
    ~query, ~iri, ~label, ~definition, ~source, ~ontology, ~resource_kind,
    ~type_iris,
    "expanded count", "https://example.org/methods/expanded-count",
    "Expanded count", "An expanded-count abundance estimation procedure.",
    "smn", "smn", "Concept", "http://www.w3.org/ns/sosa/Procedure",
    "mark recapture", "https://example.org/methods/mark-recapture",
    "Mark-recapture estimate", "A mark-recapture abundance estimation procedure.",
    "smn", "smn", "Concept", "http://www.w3.org/ns/sosa/Procedure"
  )
}

# `closure_search_stub()` answers under any role. This one answers a procedure
# under role `method` and no other, a deliberately strict model of the reason
# `.ms_closure_iri_roles()` gives for role mattering at all: role selects the
# sources and the ranking profile, so a term searched under the wrong one can
# be missed although it exists. That strictness is what makes the role a
# procedure is searched under visible in the files. Every call's query and role
# are recorded.
closure_procedure_stub <- function(calls) {
  terms <- closure_search_stub()
  procedures <- closure_procedure_search_index()
  function(query, role = NA_character_, sources = NULL, ...) {
    calls$queries <- c(calls$queries, query)
    calls$roles <- c(calls$roles, role)
    hits <- terms(query, role = role, sources = sources)
    if (identical(role, "method")) {
      found <- procedures[procedures$query == query, , drop = FALSE]
      found$score <- rep(0.9, nrow(found))
      hits <- dplyr::bind_rows(
        hits,
        found[, setdiff(names(found), "query"), drop = FALSE]
      )
    }
    hits
  }
}

test_that("a code-resolved procedure is a vocabulary term and never a review target", {
  path <- withr::local_tempdir()
  make_closure_procedure_sdp(path)
  closure_clear(path)
  # In the radix order the producer returns its measurement set in.
  procedures <- c(
    "https://example.org/methods/expanded-count",
    "https://example.org/methods/mark-recapture"
  )

  calls <- new.env()
  # No warning: both procedures resolved, so neither became a gap.
  expect_no_warning(
    closure <- write_sdp_semantic_closure(
      path,
      # No evidence row names a procedure, so their vocabulary rows can come
      # only from the search, under whatever role the producer chose.
      evidence = closure_reviewed_evidence(),
      search_fn = closure_procedure_stub(calls),
      quiet = TRUE
    )
  )

  # Both directions of the difference, in one package.
  expect_identical(
    setdiff(closure$measurement_iris, closure$review_targets$iri),
    procedures
  )
  expect_identical(
    setdiff(closure$review_targets$iri, closure$measurement_iris),
    "https://w3id.org/smn/Observation"
  )

  # The claim is about the two files, so they are read as written.
  read_back <- function(file) {
    readr::read_csv(
      file,
      col_types = readr::cols(.default = readr::col_character()),
      show_col_types = FALSE,
      progress = FALSE
    )
  }
  vocabulary <- read_back(file.path(path, "metadata", "semantic_vocabulary.csv"))
  review <- read_back(file.path(path, "reviewed_semantic_selections.csv"))
  expect_true(all(procedures %in% vocabulary$iri))
  expect_false(any(procedures %in% review$iri))
  expect_identical(nrow(vocabulary), 6L)
  expect_identical(nrow(review), 5L)

  # Reached through the fallback in `.ms_closure_iri_roles()`: a measurement IRI
  # with no `dictionary_role` row is searched under role `method`, and under no
  # other. The stub answers a procedure under `method` alone, so without that
  # fallback each procedure would be a gap and absent from the vocabulary.
  searched <- calls$roles[
    calls$queries %in% closure_procedure_search_index()$query
  ]
  expect_identical(unique(searched), "method")

  # Both gates accept the pair: the ledger is complete with no procedure row,
  # because no canonical review target asks for one.
  pkg <- read_salmon_datapackage(path)
  mapping <- yaml::read_yaml(
    file.path(path, "metadata", "eml-mapping.yml"),
    eval.expr = FALSE
  )
  expect_identical(nrow(.ms_eml_read_vocabulary(path, pkg, mapping)), 6L)
  expect_identical(nrow(.ms_eml_read_semantic_review(path, pkg, mapping)), 5L)
})

test_that("both written files satisfy the validators that had no producer", {
  path <- withr::local_tempdir()
  make_eml_test_sdp(path)
  closure_clear(path)

  # No warning: nothing is unresolved and every rationale was supplied. (The
  # package reader still says it loaded, which is not this function's message.)
  expect_no_warning(
    closure <- write_sdp_semantic_closure(
      path,
      evidence = closure_reviewed_evidence(),
      search_fn = closure_search_stub(),
      quiet = TRUE
    )
  )

  expect_true(file.exists(closure$files[["vocabulary"]]))
  expect_true(file.exists(closure$files[["review"]]))

  pkg <- read_salmon_datapackage(path)
  mapping <- yaml::read_yaml(file.path(path, "metadata", "eml-mapping.yml"))

  # These two calls are the point of the item: before it, nothing in the
  # package could produce a file either of them accepts.
  vocabulary <- .ms_eml_read_vocabulary(path, pkg, mapping)
  expect_identical(nrow(vocabulary), 4L)
  review <- .ms_eml_read_semantic_review(path, pkg, mapping)
  expect_identical(nrow(review), 5L)
  expect_true(all(review$decision == "accepted"))
})

test_that("the sidecar digests are rewritten so no user hand-writes one", {
  path <- withr::local_tempdir()
  make_eml_test_sdp(path)
  closure_clear(path)

  closure <- write_sdp_semantic_closure(
    path,
    evidence = closure_reviewed_evidence(),
    search_fn = closure_search_stub(),
    quiet = TRUE
  )

  mapping <- yaml::read_yaml(file.path(path, "metadata", "eml-mapping.yml"))
  expect_identical(
    mapping$semantic_vocabulary$sha256,
    digest::digest(
      file = closure$files[["vocabulary"]],
      algo = "sha256",
      serialize = FALSE
    )
  )
  expect_identical(
    mapping$semantic_review$sha256,
    digest::digest(
      file = closure$files[["review"]],
      algo = "sha256",
      serialize = FALSE
    )
  )
  # Every row's own snapshot digest, recomputed from the row as written.
  written <- readr::read_csv(
    closure$files[["vocabulary"]],
    col_types = readr::cols(.default = readr::col_character()),
    show_col_types = FALSE,
    progress = FALSE
  )
  expect_identical(
    written$reviewed_snapshot_sha256,
    vapply(
      seq_len(nrow(written)),
      function(i) .ms_eml_vocabulary_snapshot_sha256(written[i, , drop = FALSE]),
      character(1)
    )
  )
})

test_that("an unresolvable IRI becomes a gap and both files are still written", {
  path <- withr::local_tempdir()
  make_eml_test_sdp(
    path,
    measurement_term_iri = "https://w3id.org/smn/NoSuchTermHere"
  )
  closure_clear(path)

  # The stub knows nothing about the invented IRI, so its evidence cannot be
  # resolved and no `evidence` row supplies it. A rationale IS supplied for it,
  # so the gap warning is the only warning this call can raise.
  expect_warning(
    closure <- write_sdp_semantic_closure(
      path,
      evidence = closure_unresolvable_evidence(),
      search_fn = closure_search_stub(),
      quiet = TRUE
    ),
    "could not be resolved"
  )

  # GAP, NOT ABORT: the files exist.
  expect_true(file.exists(closure$files[["vocabulary"]]))
  expect_true(file.exists(closure$files[["review"]]))
  expect_identical(nrow(closure$review), 5L)

  # And the gap is in the shape the term-request pipeline consumes.
  expect_identical(nrow(closure$gaps), 1L)
  expect_identical(
    closure$gaps$unresolved_iri,
    "https://w3id.org/smn/NoSuchTermHere"
  )
  expect_identical(closure$gaps$gap_detection_basis, "no_candidates")
  expect_identical(closure$gaps$target_sdp_field, "term_iri")
  expect_identical(closure$gaps$dictionary_role, "variable")
  expect_identical(closure$gaps$candidate_count, 0L)
  # The IRI's own namespace says where the term would have to be minted.
  expect_identical(closure$gaps$placement_recommendation, "smn")
  expect_true(all(.ms_term_gap_cols() %in% names(closure$gaps)))

  # The unresolved row is omitted rather than invented, so the vocabulary is
  # short by exactly one and the EML gate says so in the same terms.
  expect_identical(nrow(closure$vocabulary), 3L)
  expect_false("https://w3id.org/smn/NoSuchTermHere" %in% closure$vocabulary$iri)
  pkg <- read_salmon_datapackage(path)
  mapping <- yaml::read_yaml(file.path(path, "metadata", "eml-mapping.yml"))
  expect_error(
    .ms_eml_read_vocabulary(path, pkg, mapping),
    "canonical measurement IRI set"
  )
})

test_that("the gap table is accepted by render_ontology_term_request()", {
  path <- withr::local_tempdir()
  make_eml_test_sdp(
    path,
    measurement_term_iri = "https://w3id.org/smn/NoSuchTermHere"
  )
  closure_clear(path)

  suppressWarnings(
    closure <- write_sdp_semantic_closure(
      path,
      evidence = closure_unresolvable_evidence(),
      search_fn = closure_search_stub(),
      quiet = TRUE
    )
  )
  requests <- render_ontology_term_request(closure$gaps, ask = FALSE)
  expect_true(nrow(requests) >= 1L)
  expect_true("request_scope" %in% names(requests))
})

test_that("no LLM request is constructed on the closure path", {
  path <- withr::local_tempdir()
  make_eml_test_sdp(path)
  closure_clear(path)

  # A stop()ing binding on the one function that performs the provider call is
  # the sentinel: if anything on this path reached the LLM, this test fails.
  testthat::with_mocked_bindings(
    {
      closure <- write_sdp_semantic_closure(
        path,
        evidence = closure_reviewed_evidence(),
        search_fn = closure_search_stub(),
        quiet = TRUE
      )
      expect_identical(nrow(closure$vocabulary), 4L)
    },
    .ms_llm_chat_json_request = function(...) {
      stop("LLM review must never run on the closure path.")
    }
  )
})

test_that("fully hand-supplied evidence runs no search at all", {
  path <- withr::local_tempdir()
  make_eml_test_sdp(path)
  closure_clear(path)

  closure <- write_sdp_semantic_closure(
    path,
    evidence = closure_full_evidence(),
    search_fn = function(...) stop("search_fn must not be called."),
    quiet = TRUE
  )
  expect_identical(nrow(closure$vocabulary), 4L)
  expect_identical(nrow(closure$gaps), 0L)
  expect_identical(nrow(closure$placeholders), 0L)
})

test_that("the IRI local name is the query when no review trail exists", {
  path <- withr::local_tempdir()
  make_eml_test_sdp(path)
  closure_clear(path)
  calls <- new.env(parent = emptyenv())
  calls$queries <- character()

  write_sdp_semantic_closure(
    path,
    evidence = closure_reviewed_evidence(),
    search_fn = closure_search_stub(calls = calls),
    quiet = TRUE
  )
  # `ObservedRateOrAbundance` -> "observed rate or abundance", `Stock` ->
  # "stock". Recovering the reviewer's query from the IRI they accepted is what
  # makes evidence re-resolvable without asking the user to restate it.
  expect_true("observed rate or abundance" %in% calls$queries)
  expect_true("stock" %in% calls$queries)
  # QUDT rows are fully supplied, so they are never searched.
  expect_false(any(grepl("^count$", calls$queries)))
})

test_that("a recorded decision reason becomes the review rationale", {
  path <- withr::local_tempdir()
  make_eml_test_sdp(path)
  closure_clear(path)
  readr::write_csv(
    tibble::tibble(
      dataset_id = "demo-salmon-2026",
      table_id = "counts",
      column_name = "count",
      target_sdp_field = "term_iri",
      iri = "https://w3id.org/smn/ObservedRateOrAbundance",
      search_query = "observed rate or abundance",
      decision = "accepted",
      decision_reason = "Chosen during review because the grain is a rate."
    ),
    file.path(path, "semantic_suggestions.csv")
  )

  closure <- suppressWarnings(write_sdp_semantic_closure(
    path,
    evidence = closure_qudt_evidence(),
    search_fn = closure_search_stub(),
    quiet = TRUE
  ))
  row <- closure$review[closure$review$target_sdp_field == "term_iri", ]
  expect_identical(
    row$review_rationale,
    "Chosen during review because the grain is a rate."
  )
})

test_that("a target with no recorded rationale gets a REVIEW REQUIRED marker", {
  path <- withr::local_tempdir()
  make_eml_test_sdp(path)
  closure_clear(path)

  expect_warning(
    closure <- write_sdp_semantic_closure(
      path,
      # Vocabulary evidence only: no judgement columns anywhere.
      evidence = closure_qudt_evidence()[
        , setdiff(
          names(closure_qudt_evidence()),
          c("confidence", "review_rationale")
        )
      ],
      search_fn = closure_search_stub(),
      quiet = TRUE
    ),
    "REVIEW REQUIRED"
  )
  expect_true(all(grepl("^REVIEW REQUIRED:", closure$placeholders$review_rationale)))
  expect_identical(nrow(closure$placeholders), 5L)
  expect_true(all(closure$review$confidence == "unassessed"))
})

test_that("both files are written in C collation order", {
  path <- withr::local_tempdir()
  make_eml_test_sdp(path)
  closure_clear(path)

  closure <- write_sdp_semantic_closure(
    path,
    evidence = closure_reviewed_evidence(),
    search_fn = closure_search_stub(),
    quiet = TRUE
  )
  expect_identical(
    closure$vocabulary$iri,
    sort(closure$vocabulary$iri, method = "radix")
  )
  key <- do.call(paste, c(
    unname(closure$review[c(
      "dataset_id", "table_id", "column_name", "target_scope",
      "target_sdp_field", "dictionary_role", "iri"
    )]),
    list(sep = "\r")
  ))
  expect_identical(key, sort(key, method = "radix"))
  # What was sorted is what was written: the file bytes carry the same order.
  written <- readr::read_csv(
    closure$files[["vocabulary"]],
    col_types = readr::cols(.default = readr::col_character()),
    show_col_types = FALSE,
    progress = FALSE
  )
  expect_identical(written$iri, closure$vocabulary$iri)
})

test_that("the producer is byte-reproducible across two runs", {
  path <- withr::local_tempdir()
  make_eml_test_sdp(path)
  closure_clear(path)

  first <- write_sdp_semantic_closure(
    path,
    evidence = closure_reviewed_evidence(),
    search_fn = closure_search_stub(),
    quiet = TRUE
  )
  first_digests <- vapply(
    first$files[c("vocabulary", "review")],
    function(file) digest::digest(file = file, algo = "sha256", serialize = FALSE),
    character(1)
  )
  second <- write_sdp_semantic_closure(
    path,
    evidence = closure_reviewed_evidence(),
    search_fn = closure_search_stub(),
    quiet = TRUE
  )
  second_digests <- vapply(
    second$files[c("vocabulary", "review")],
    function(file) digest::digest(file = file, algo = "sha256", serialize = FALSE),
    character(1)
  )
  expect_identical(first_digests, second_digests)
})

test_that("evidence must be rows, not a parsed object", {
  path <- withr::local_tempdir()
  make_eml_test_sdp(path)

  expect_error(
    write_sdp_semantic_closure(path, evidence = "metadata/vocab.csv", quiet = TRUE),
    "must be a data frame"
  )
  expect_error(
    write_sdp_semantic_closure(
      path,
      evidence = tibble::tibble(label = "x"),
      quiet = TRUE
    ),
    "must have an .*iri.* column"
  )
  expect_error(
    write_sdp_semantic_closure(
      path,
      evidence = tibble::tibble(iri = "x", not_a_field = "y"),
      quiet = TRUE
    ),
    "cannot use"
  )
  expect_error(
    write_sdp_semantic_closure(
      path,
      evidence = tibble::tibble(iri = c("x", "x"), label = c("a", "b")),
      quiet = TRUE
    ),
    "at most one row per IRI"
  )
})

test_that("an inline sidecar key is reported rather than rewritten", {
  path <- withr::local_tempdir()
  make_eml_test_sdp(path)
  closure_clear(path)
  mapping_path <- file.path(path, "metadata", "eml-mapping.yml")
  lines <- readLines(mapping_path, warn = FALSE)

  # Flow style. Pinning the digest here would mean rewriting the document, so the
  # producer says so instead of appending a second key and making the YAML say
  # two things. This path is otherwise unreachable, which is why it has a test.
  start <- grep("^semantic_review:", lines)[[1]]
  lines <- c(
    lines[seq_len(start - 1L)],
    "semantic_review: {path: reviewed_semantic_selections.csv, sha256: 'x'}",
    lines[-seq_len(start + 2L)]
  )
  writeLines(lines, mapping_path)

  expect_warning(
    closure <- write_sdp_semantic_closure(
      path,
      evidence = closure_reviewed_evidence(),
      search_fn = closure_search_stub(),
      quiet = TRUE
    ),
    "inline"
  )
  # The files are still written, and the vocabulary digest, which IS a block
  # mapping, is still pinned.
  expect_true(file.exists(closure$files[["review"]]))
  mapping <- yaml::read_yaml(mapping_path)
  expect_identical(
    mapping$semantic_vocabulary$sha256,
    digest::digest(
      file = closure$files[["vocabulary"]],
      algo = "sha256",
      serialize = FALSE
    )
  )
  expect_identical(mapping$semantic_review$sha256, "x")
})

test_that("a missing package directory is refused before anything is read", {
  expect_error(
    write_sdp_semantic_closure(
      file.path(withr::local_tempdir(), "absent"),
      quiet = TRUE
    ),
    "does not exist"
  )
})

# ---------------------------------------------------------------------------
# A LOOKUP THAT DID NOT ANSWER IS NOT AN ONTOLOGY GAP.
#
# These two are the same defect arriving by the two routes a search has for
# failing to answer, and the reason they are one subject: both once produced a
# `no_candidates` gap row, an omitted vocabulary row, and a written closure --
# which turns B-116's ruled gap-not-abort shape into a request that an ontology
# mint a term nobody established was missing. `find_terms()` already warns, in
# its own words, that such a result is unknown rather than an ontology gap.
# ---------------------------------------------------------------------------

# An empty result carrying the failed-source diagnostics `find_terms()` attaches.
# This is the harder half: the call returns normally, and only the attribute says
# the answer is unknown.
closure_degraded_stub <- function(failed = "gcdfo") {
  function(query, role = NA_character_, sources = NULL, ...) {
    hits <- tibble::tibble(
      label = character(),
      iri = character(),
      definition = character(),
      source = character(),
      ontology = character(),
      resource_kind = character(),
      type_iris = character(),
      score = numeric()
    )
    attr(hits, "diagnostics") <- tibble::tibble(
      source = failed,
      query = query,
      status = "http_error",
      count = 0L,
      elapsed_secs = 0,
      error = "HTTP 503"
    )
    hits
  }
}

test_that("a search that throws aborts rather than manufacturing a gap", {
  path <- withr::local_tempdir()
  make_eml_test_sdp(path)
  closure_clear(path)

  # Braces in the message on purpose: external text reaching cli unescaped is
  # evaluated as a template, and an unbalanced one replaces the message with a
  # parse error.
  expect_error(
    write_sdp_semantic_closure(
      path,
      evidence = closure_reviewed_evidence(),
      search_fn = function(...) stop("connection {reset} by peer"),
      quiet = TRUE
    ),
    "did not answer"
  )

  # NOTHING WAS WRITTEN. The remedy is to re-run, so a half-derived closure on
  # disk would make the retry start from worse state than the first attempt did.
  expect_false(file.exists(file.path(path, "metadata", "semantic_vocabulary.csv")))
  expect_false(file.exists(file.path(path, "reviewed_semantic_selections.csv")))
})

test_that("an empty result with failed-source diagnostics is not a gap", {
  path <- withr::local_tempdir()
  make_eml_test_sdp(path)
  closure_clear(path)

  expect_error(
    write_sdp_semantic_closure(
      path,
      evidence = closure_reviewed_evidence(),
      search_fn = closure_degraded_stub(),
      quiet = TRUE
    ),
    "did not answer"
  )
  expect_false(file.exists(file.path(path, "metadata", "semantic_vocabulary.csv")))
  expect_false(file.exists(file.path(path, "reviewed_semantic_selections.csv")))

  # And the degraded-status test is the one `find_terms()` applies, read rather
  # than restated, so the two cannot drift apart.
  expect_identical(
    .ms_search_failed_sources(tibble::tibble(
      source = c("smn", "gcdfo"),
      status = c("success", "http_error")
    )),
    "gcdfo"
  )
  expect_identical(
    .ms_search_failed_sources(tibble::tibble(
      source = "smn",
      status = "success"
    )),
    character()
  )
})

test_that("a term found with a blank required field is incomplete, not a gap", {
  path <- withr::local_tempdir()
  make_eml_test_sdp(path)
  closure_clear(path)

  # An ontology class with no definition. The IRI matches exactly, so the term
  # was FOUND; what is missing is evidence about it.
  index <- closure_search_index()
  index$definition[
    index$iri == "https://w3id.org/smn/ObservedRateOrAbundance"
  ] <- ""

  expect_warning(
    closure <- write_sdp_semantic_closure(
      path,
      evidence = closure_reviewed_evidence(),
      search_fn = closure_search_stub(index = index),
      quiet = TRUE
    ),
    "not an ontology gap"
  )

  # NOT a gap: nothing asks the term-request pipeline to mint what was found.
  expect_identical(nrow(closure$gaps), 0L)
  expect_identical(nrow(closure$incomplete), 1L)
  expect_identical(
    closure$incomplete$iri,
    "https://w3id.org/smn/ObservedRateOrAbundance"
  )
  expect_identical(closure$incomplete$missing_fields, "definition")
  expect_identical(closure$incomplete$resolved_source, "smn")
  expect_identical(closure$incomplete$target_sdp_field, "term_iri")
  expect_identical(closure$incomplete$dictionary_role, "variable")
  # The row is still omitted, because the validator refuses a blank definition,
  # and the other three are still written.
  expect_identical(nrow(closure$vocabulary), 3L)
  expect_true(file.exists(closure$files[["vocabulary"]]))
})

test_that("a linked closure output is refused and its target is left alone", {
  skip_on_os("windows")
  path <- withr::local_tempdir()
  make_eml_test_sdp(path)
  closure_clear(path)

  # The threat model: an SDP that arrived from a collaborator, whose own content
  # names a file the R process can write.
  outside <- withr::local_tempdir()
  external <- file.path(outside, "keep-me.yml")
  # A YAML mapping, so the sidecar iteration below exercises the write rather
  # than tripping over an unparseable link target on its way there.
  keep <- c("keep_me: true", "other: 1")
  writeLines(keep, external)

  for (relative in c(
    "metadata/semantic_vocabulary.csv",
    "reviewed_semantic_selections.csv",
    "metadata/eml-mapping.yml"
  )) {
    # Rewritten each pass: the point of the loop is that each of the three names
    # is refused on its own, so each starts from the same untouched target.
    writeLines(keep, external)
    target <- file.path(path, relative)
    original <- if (file.exists(target)) {
      readLines(target, warn = FALSE)
    } else {
      NULL
    }
    unlink(target)
    expect_true(file.symlink(external, target))

    expect_error(
      write_sdp_semantic_closure(
        path,
        evidence = closure_reviewed_evidence(),
        search_fn = closure_search_stub(),
        quiet = TRUE
      ),
      "refuses to write"
    )
    expect_identical(readLines(external, warn = FALSE), keep)

    unlink(target)
    if (!is.null(original)) {
      writeLines(original, target)
    }
  }
})

test_that("a failure in the third write leaves the first two unchanged", {
  path <- withr::local_tempdir()
  make_eml_test_sdp(path)
  closure_clear(path)

  # A valid closure whose sidecar digests match its files.
  first <- write_sdp_semantic_closure(
    path,
    evidence = closure_reviewed_evidence(),
    search_fn = closure_search_stub(),
    quiet = TRUE
  )
  mapping_path <- file.path(path, "metadata", "eml-mapping.yml")
  read_bytes <- function(file) {
    readBin(file, what = "raw", n = file.info(file)$size)
  }
  before_vocabulary <- read_bytes(first$files[["vocabulary"]])
  before_mapping <- readLines(mapping_path, warn = FALSE)

  # A second run that WOULD write different bytes, so a surviving old file is
  # distinguishable from a rewritten identical one.
  changed <- closure_reviewed_evidence()
  changed$definition[changed$iri == "https://w3id.org/smn/Stock"] <-
    "A deliberately different definition."

  # Half one: the sidecar render fails. Before the three writes became one set,
  # both CSVs had already replaced their valid versions by the time this ran, and
  # the sidecar kept its old digests -- a package that fails its own digest check
  # even though the call errored.
  testthat::with_mocked_bindings(
    expect_error(
      write_sdp_semantic_closure(
        path,
        evidence = changed,
        search_fn = closure_search_stub(),
        quiet = TRUE
      ),
      "sidecar digest render failed"
    ),
    .ms_closure_set_mapping_digest = function(...) {
      stop("sidecar digest render failed")
    }
  )
  expect_identical(read_bytes(first$files[["vocabulary"]]), before_vocabulary)
  expect_identical(readLines(mapping_path, warn = FALSE), before_mapping)

  # Half two, with no mock in it: a stray directory where the ledger belongs
  # fails the second install. The first must not already be installed.
  unlink(first$files[["review"]])
  dir.create(first$files[["review"]])
  expect_error(
    write_sdp_semantic_closure(
      path,
      evidence = changed,
      search_fn = closure_search_stub(),
      quiet = TRUE
    ),
    "directory"
  )
  expect_identical(read_bytes(first$files[["vocabulary"]]), before_vocabulary)
  expect_identical(readLines(mapping_path, warn = FALSE), before_mapping)
})
