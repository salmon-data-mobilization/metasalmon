# The observable contract of the removal release's R half (hub item B-329,
# S16 step 3): the package makes no model call, so the surface that requested
# one is gone rather than ignored. A caller still passing it gets an error at
# the call, not a silent deterministic run. The judgement route that replaces
# it is the review packet, pinned in test-semantic-review-packet.R.
#
# *Retires when:* Brett reverses Q67 and a model call comes back into the
# package, which would be a design decision with its own tests.

test_that("no public signature takes an llm_* or chat_* argument", {
  ns <- asNamespace("metasalmon")
  exported <- getNamespaceExports("metasalmon")
  for (name in exported) {
    fn <- get(name, envir = ns)
    if (!is.function(fn)) next
    args <- names(formals(fn))
    if (is.null(args)) args <- character()
    expect_false(any(startsWith(args, "llm_") | startsWith(args, "chat_")), info = name)
  }
  # The positive control: the walk reads real signatures.
  expect_true("context_files" %in% names(formals(write_semantic_review_packet)))
  expect_false("chat_decomposition" %in% exported)
})

test_that("a removed argument is an error at the call", {
  dict <- test_spawner_dictionary()
  expect_error(
    suggest_semantics(NULL, dict, search_fn = function(...) tibble::tibble(), llm_assess = TRUE),
    "unused argument"
  )
  expect_error(
    infer_dictionary(data.frame(x = 1), llm_context_files = "notes.md"),
    "unused argument"
  )
  # create_sdp() routes unknown arguments through `...`, and names every one
  # before it infers or writes anything.
  path <- file.path(withr::local_tempdir(), "never-written")
  expect_error(
    create_sdp(
      data.frame(x = 1), path = path, seed_semantics = FALSE, seed_verbose = FALSE,
      check_updates = FALSE, llm_assess = TRUE, llm_provider = "openai"
    ),
    "llm_assess.*llm_provider"
  )
  expect_false(dir.exists(path))
})

test_that("the artifact list keeps a NULL semantic_llm_assessments element for one release", {
  artifacts <- infer_salmon_datapackage_artifacts(
    data.frame(spawner_count = c(1L, 2L)),
    seed_semantics = FALSE,
    seed_verbose = FALSE
  )
  expect_true("semantic_llm_assessments" %in% names(artifacts))
  expect_null(artifacts$semantic_llm_assessments)
})
