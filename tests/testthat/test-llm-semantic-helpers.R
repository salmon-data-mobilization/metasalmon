test_that("invalid candidate indexes degrade to review instead of erroring", {
  candidates <- tibble::tibble(
    iri = c("https://example.org/a", "https://example.org/b"),
    label = c("A", "B")
  )

  result <- metasalmon:::.ms_validate_llm_assessment(
    list(
      decision = "accept",
      selected_candidate_index = 99,
      confidence = 0.7,
      rationale = "Bad index from model.",
      missing_context = ""
    ),
    candidates
  )

  expect_equal(result$decision, "review")
  expect_true(is.na(result$selected_candidate_index))
  expect_match(result$rationale, "out-of-range candidate index")
})

test_that("accept without a selected candidate degrades to review", {
  candidates <- tibble::tibble(
    iri = c("https://example.org/a", "https://example.org/b"),
    label = c("A", "B")
  )

  result <- metasalmon:::.ms_validate_llm_assessment(
    list(
      decision = "accept",
      selected_candidate_index = NULL,
      confidence = 0.81,
      rationale = "Top candidate looks right.",
      missing_context = ""
    ),
    candidates
  )

  expect_equal(result$decision, "review")
  expect_true(is.na(result$selected_candidate_index))
  expect_match(result$rationale, "without selecting a candidate")
})

test_that("vector-valued confidence uses the first element instead of erroring", {
  candidates <- tibble::tibble(
    iri = c("https://example.org/a", "https://example.org/b"),
    label = c("A", "B")
  )

  result <- metasalmon:::.ms_validate_llm_assessment(
    list(
      decision = "accept",
      selected_candidate_index = 1,
      confidence = c(0.82, 0.31),
      rationale = "Primary confidence is usable.",
      missing_context = ""
    ),
    candidates
  )

  expect_equal(result$decision, "accept")
  expect_equal(result$selected_candidate_index, 1L)
  expect_equal(result$confidence, 0.82)
})

test_that("nested structured values are flattened to the first scalar", {
  candidates <- tibble::tibble(
    iri = c("https://example.org/a", "https://example.org/b"),
    label = c("A", "B")
  )

  result <- metasalmon:::.ms_validate_llm_assessment(
    list(
      decision = list(c("accept", "review")),
      selected_candidate_index = list(c(2L, 1L)),
      confidence = list(c(0.74, 0.12)),
      rationale = list(c("Use the first rationale.", "Ignore this one.")),
      missing_context = list(c("", "extra"))
    ),
    candidates
  )

  expect_equal(result$decision, "accept")
  expect_equal(result$selected_candidate_index, 2L)
  expect_equal(result$confidence, 0.74)
  expect_equal(result$rationale, "Use the first rationale.")
})

test_that("falsey missing_context strings normalize to NA", {
  candidates <- tibble::tibble(
    iri = c("https://example.org/a", "https://example.org/b"),
    label = c("A", "B")
  )

  result <- metasalmon:::.ms_validate_llm_assessment(
    list(
      decision = "review",
      selected_candidate_index = NULL,
      confidence = 0.42,
      rationale = "Need more context.",
      missing_context = "FALSE"
    ),
    candidates
  )

  expect_true(is.na(result$missing_context))
})

test_that("near-duplicate retry query remains eligible", {
  classification <- metasalmon:::.ms_llm_classify_retry_query(
    "catch weight property",
    "catch weight"
  )

  expect_identical(classification$disposition, "use_query")
  expect_identical(classification$query, "catch weight property")
  expect_true(is.na(classification$rejection_reason))
})

test_that("identifier-like exact duplicate retry query is suppressed before fallback", {
  classification <- metasalmon:::.ms_llm_classify_retry_query(
    "SMN:CatchWeight",
    "smn:catchweight"
  )

  expect_identical(classification$disposition, "duplicate_original_query")
  expect_identical(
    classification$rejection_reason,
    "duplicate_original_query"
  )
})

test_that("a CURIE is identifier-like whatever letters it holds, and whitespace ends it (B-380)", {
  # The local part's class was `[^\\s]`, which R's default TRE engine reads as
  # "neither a backslash nor the letter s". The backlog's five cases, each
  # measured the other way round before the fix except abc:S and gcdfo_v2:X.
  looks <- function(x) metasalmon:::.ms_llm_query_looks_like_identifier(x)
  expect_true(looks("smn:species"))
  expect_true(looks("abc:s"))
  expect_true(looks("abc:S"))
  expect_false(looks("abc:d e"))
  expect_true(looks("gcdfo_v2:X"))
  # A backslash is an ordinary character after the colon, and whitespace the
  # normalizer collapses ends the CURIE wherever it is.
  expect_true(looks("abc:\\"))
  expect_false(looks("abc:d\te"))
  expect_false(looks("Note: fish"))
  # The classifier's verdict follows, and so does the ingester's reason.
  expect_identical(metasalmon:::.ms_llm_classify_retry_query("smn:species", "species")$disposition, "identifier_like")
  expect_identical(metasalmon:::.ms_llm_classify_retry_query("abc:d e", "x")$disposition, "use_query")
})

test_that("rejection escalation preserves distinct pre and post rationales", {
  target <- tibble::tibble(
    dataset_id = "d1",
    table_id = "t1",
    column_name = "catch_weight",
    code_value = NA_character_,
    dictionary_role = "variable",
    target_scope = "column",
    target_sdp_file = "column_dictionary.csv",
    target_sdp_field = "term_iri",
    search_query = "catch weight"
  )
  config <- list(provider = "fixture-harness", model = "semantic-review-v1")
  pre <- metasalmon:::.ms_llm_review_empty_assessment(target, config)
  pre$llm_decision <- "reject_shortlist"
  pre$llm_rationale <- "Initial candidates describe individual fish."
  post <- pre
  post$llm_rationale <- "Retry candidates still describe individual fish."

  escalated <- metasalmon:::.ms_llm_escalate_unresolved_rejection(
    pre,
    list(assessment = post)
  )$assessment

  expect_match(
    escalated$llm_rationale,
    "Initial shortlist rejection: Initial candidates",
    fixed = TRUE
  )
  expect_match(
    escalated$llm_rationale,
    "Post-retry shortlist rejection: Retry candidates",
    fixed = TRUE
  )
})

test_that("apply_semantic_suggestions can use llm strategy with a confidence threshold", {
  dict <- test_spawner_dictionary(column_description = "Spawner abundance")

  suggestions <- tibble::tibble(
    column_name = c("spawner_count", "spawner_count"),
    dictionary_role = c("variable", "variable"),
    table_id = c("t1", "t1"),
    dataset_id = c("d1", "d1"),
    target_scope = c("column", "column"),
    target_sdp_file = c("column_dictionary.csv", "column_dictionary.csv"),
    target_sdp_field = c("term_iri", "term_iri"),
    iri = c("https://example.org/variable/alt", "https://example.org/variable/best"),
    label = c("Alternative variable", "Best variable"),
    llm_selected = c(FALSE, TRUE),
    llm_confidence = c(0.3, 0.96)
  )

  out <- apply_semantic_suggestions(
    dict,
    suggestions = suggestions,
    strategy = "llm",
    min_llm_confidence = 0.9,
    verbose = FALSE
  )

  expect_equal(out$term_iri[[1]], "https://example.org/variable/best")

  expect_error(
    apply_semantic_suggestions(
      dict,
      suggestions = suggestions[, setdiff(names(suggestions), "llm_selected")],
      strategy = "llm",
      verbose = FALSE
    ),
    "harness-reviewed suggestions"
  )
})

# Retargeted from the in-package review run, removed with the model call (hub
# item B-329): the packet builder is now the one reader of context files.
test_that("context files are parsed and chunked once per packet, whatever the unit count", {
  tmp <- withr::local_tempdir()
  context_path <- file.path(tmp, "context.md")
  writeLines(
    c(
      "# Context",
      "Spawner abundance and juvenile abundance are both described here.",
      "These notes should only be read and chunked once per packet."
    ),
    context_path
  )

  dict <- tibble::tibble(
    dataset_id = c("d1", "d1"),
    table_id = c("t1", "t1"),
    column_name = c("spawner_count", "juvenile_count"),
    column_label = c("Spawner count", "Juvenile count"),
    column_description = c("Spawner abundance", "Juvenile abundance"),
    column_role = c("measurement", "measurement"),
    value_type = c("integer", "integer"),
    unit_label = c(NA_character_, NA_character_),
    unit_iri = c(NA_character_, NA_character_),
    term_iri = c(NA_character_, NA_character_),
    property_iri = c(NA_character_, NA_character_),
    entity_iri = c(NA_character_, NA_character_),
    constraint_iri = c(NA_character_, NA_character_),
    statistical_modifier_iri = c(NA_character_, NA_character_)
  )
  fake_search <- function(query, role, sources) {
    tibble::tibble(
      label = c(paste(query, "best"), paste(query, "alt")),
      iri = c(
        paste0("https://example.org/", gsub("[^a-z]+", "-", tolower(query)), "/best"),
        paste0("https://example.org/", gsub("[^a-z]+", "-", tolower(query)), "/alt")
      ),
      source = c("smn", "smn"),
      ontology = c("demo", "demo"),
      role = c(role, role),
      match_type = c("label_partial", "label_partial"),
      definition = c("Best match", "Alt match"),
      score = c(0.9, 0.6)
    )
  }
  seeded <- suppressMessages(suggest_semantics(
    NULL, dict, sources = "smn", max_per_role = 2, search_fn = fake_search
  ))

  read_calls <- 0L
  chunk_calls <- 0L
  orig_context_text_from_file <- metasalmon:::.ms_context_text_from_file
  orig_chunk_context_text <- metasalmon:::.ms_chunk_context_text
  with_mocked_bindings(
    `.ms_context_text_from_file` = function(path) {
      read_calls <<- read_calls + 1L
      orig_context_text_from_file(path)
    },
    `.ms_chunk_context_text` = function(text, source, chunk_chars = 2200L, overlap_chars = 200L) {
      chunk_calls <<- chunk_calls + 1L
      orig_chunk_context_text(text, source, chunk_chars = chunk_chars, overlap_chars = overlap_chars)
    },
    {
      built <- write_semantic_review_packet(
        seeded, context_files = context_path,
        review_dir = file.path(tmp, "review"), quiet = TRUE
      )
      expect_gt(built$units, 1L)
    },
    .package = "metasalmon"
  )

  expect_equal(read_calls, 1L)
  expect_equal(chunk_calls, 1L)
})

test_that("context chunk pool is collected once but scored per target", {
  pool <- tibble::tibble(
    source = c("context.md", "context.md"),
    chunk_id = c("context.md#1", "context.md#2"),
    chunk_text = c(
      "spawner abundance count population",
      "water temperature degree celsius"
    )
  )
  spawner_target <- tibble::tibble(
    search_query = "spawner abundance",
    target_label = "Spawner count",
    target_description = "Natural-origin spawner abundance estimate",
    column_label = "Spawner count",
    column_description = "Natural-origin spawner abundance estimate"
  )
  temperature_target <- tibble::tibble(
    search_query = "water temperature",
    target_label = "Water temperature",
    target_description = "Water temperature measurement",
    column_label = "Water temperature",
    column_description = "Water temperature measurement"
  )
  candidates <- tibble::tibble(
    label = "candidate",
    definition = "candidate definition"
  )

  spawner_chunks <- metasalmon:::.ms_prepare_context_chunks(
    target_row = spawner_target,
    candidate_rows = candidates,
    max_chunks = 1L,
    context_chunk_pool = pool
  )
  temperature_chunks <- metasalmon:::.ms_prepare_context_chunks(
    target_row = temperature_target,
    candidate_rows = candidates,
    max_chunks = 1L,
    context_chunk_pool = pool
  )

  expect_equal(spawner_chunks$chunk_id[[1]], "context.md#1")
  expect_equal(temperature_chunks$chunk_id[[1]], "context.md#2")
})

test_that("context files sharing a basename get disambiguated source labels", {
  dir_a <- withr::local_tempdir()
  dir_b <- withr::local_tempdir()
  path_a <- file.path(dir_a, "notes.md")
  path_b <- file.path(dir_b, "notes.md")
  writeLines("Alpha spawner abundance context", path_a)
  writeLines("Beta water temperature context", path_b)

  chunks <- metasalmon:::.ms_collect_context_chunks(context_files = c(path_a, path_b))
  sources <- unique(chunks$source)

  # Two distinct files must not collapse into a single "notes.md" source, and
  # their chunk ids must not collide.
  expect_length(sources, 2L)
  expect_equal(anyDuplicated(chunks$chunk_id), 0L)
  # The basename stays visible in each disambiguated label.
  expect_true(all(grepl("notes.md", sources, fixed = TRUE)))
})

test_that("inline context snippets retain separate chunk identities", {
  chunks <- metasalmon:::.ms_collect_context_chunks(
    context_text = c(
      "CATCH_COUNT is the number of fish in a catch.",
      "FORK_LENGTH_MM uses a measuring board protocol."
    )
  )

  expect_equal(nrow(chunks), 2L)
  expect_setequal(chunks$source, "inline_context")
  expect_equal(anyDuplicated(chunks$chunk_id), 0L)
  expect_true(all(grepl(
    "^inline_context\\[[12]\\]#1$",
    chunks$chunk_id
  )))
})

test_that("non-UTF-8 (Latin-1/Windows-1252) context files are decoded, not corrupted", {
  dir <- withr::local_tempdir()
  path <- file.path(dir, "field-notes.csv")
  # Write "...,Rio Fraser" with the i encoded as Windows-1252 byte 0xED (i-acute),
  # which is invalid UTF-8 on its own.
  con <- file(path, open = "wb")
  writeBin(as.raw(c(utf8ToInt("label,note\nspawners,R"), 0xED, utf8ToInt("o Fraser\n"))), con)
  close(con)

  res <- metasalmon:::.ms_context_text_from_file(path)
  expect_false(is.null(res))
  expect_true(validUTF8(res$text))
  expect_true(grepl("Río Fraser", res$text, fixed = TRUE))
})

test_that("context chunk scoring requires a pre-collected pool", {
  expect_error(
    metasalmon:::.ms_prepare_context_chunks(
      target_row = tibble::tibble(search_query = "spawner abundance"),
      candidate_rows = tibble::tibble(label = "Spawner abundance"),
      context_chunk_pool = NULL
    ),
    "requires a pre-collected context chunk pool"
  )
})

test_that("PDF context files either extract text or fail clearly when pdftools is unavailable", {
  tmp <- withr::local_tempdir()
  pdf_path <- file.path(tmp, "context.pdf")

  grDevices::pdf(pdf_path)
  plot.new()
  text(0.5, 0.5, "Spawner context PDF")
  grDevices::dev.off()

  if (requireNamespace("pdftools", quietly = TRUE)) {
    result <- metasalmon:::.ms_context_text_from_file(pdf_path)
    expect_true(is.list(result))
    expect_true(nzchar(result$text))
    expect_equal(result$source, "context.pdf")
  } else {
    expect_error(
      metasalmon:::.ms_context_text_from_file(pdf_path),
      "pdftools"
    )
  }
})

test_that("Excel context files either extract sheet text or fail clearly when readxl is unavailable", {
  testthat::skip_if_not_installed("openxlsx")

  tmp <- withr::local_tempdir()
  xlsx_path <- file.path(tmp, "context.xlsx")

  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "dictionary")
  openxlsx::writeData(
    wb,
    "dictionary",
    tibble::tibble(
      field = c("column_name", "column_description"),
      value = c("spawner_count", "Spawner abundance estimate")
    )
  )
  openxlsx::addWorksheet(wb, "notes")
  openxlsx::writeData(
    wb,
    "notes",
    tibble::tibble(
      section = "overview",
      text = "Spawner abundance counts are summarized by population and year."
    )
  )
  openxlsx::saveWorkbook(wb, xlsx_path, overwrite = TRUE)

  if (requireNamespace("readxl", quietly = TRUE)) {
    result <- metasalmon:::.ms_context_text_from_file(xlsx_path)
    expect_true(is.list(result))
    expect_equal(result$source, "context.xlsx")
    expect_match(result$text, "Sheet: dictionary", fixed = TRUE)
    expect_match(result$text, "Spawner abundance counts are summarized", fixed = TRUE)
  } else {
    expect_error(
      metasalmon:::.ms_context_text_from_file(xlsx_path),
      "readxl"
    )
  }
})

test_that("HTML context files are converted to plain text", {
  tmp <- withr::local_tempdir()
  html_path <- file.path(tmp, "context.html")

  writeLines(
    c(
      "<html><head><title>Example</title><style>.hidden{display:none;}</style></head>",
      "<body>",
      "<h1>Trawl biosample dictionary</h1>",
      "<p>spawner_count = estimated number of spawners</p>",
      "<script>console.log('ignore me')</script>",
      "</body></html>"
    ),
    html_path
  )

  result <- metasalmon:::.ms_context_text_from_file(html_path)
  expect_true(is.list(result))
  expect_equal(result$source, "context.html")
  expect_match(result$text, "Trawl biosample dictionary", fixed = TRUE)
  expect_match(result$text, "spawner_count = estimated number of spawners", fixed = TRUE)
  expect_false(grepl("ignore me", result$text, fixed = TRUE))
})

test_that("R Markdown context files keep prose and code while dropping fences/front matter", {
  tmp <- withr::local_tempdir()
  rmd_path <- file.path(tmp, "context.Rmd")

  writeLines(
    c(
      "---",
      "title: 'Trawl dictionary'",
      "output: html_document",
      "---",
      "",
      "Spawner abundance is estimated per tow.",
      "",
      "```{r}",
      "semantic_hint <- 'estimated number of spawners'",
      "summary(semantic_hint)",
      "```",
      "",
      "Method codes describe the field protocol."
    ),
    rmd_path
  )

  result <- metasalmon:::.ms_context_text_from_file(rmd_path)
  expect_true(is.list(result))
  expect_equal(result$source, "context.Rmd")
  expect_match(result$text, "Spawner abundance is estimated per tow.", fixed = TRUE)
  expect_match(result$text, "Method codes describe the field protocol.", fixed = TRUE)
  expect_match(result$text, "semantic_hint <- 'estimated number of spawners'", fixed = TRUE)
  expect_false(grepl("```", result$text, fixed = TRUE))
  expect_false(grepl("title:", result$text, fixed = TRUE))
})

test_that("Quarto context files keep prose and code while dropping fences/front matter", {
  tmp <- withr::local_tempdir()
  qmd_path <- file.path(tmp, "context.qmd")

  writeLines(
    c(
      "---",
      "title: 'Trawl dictionary'",
      "format: html",
      "---",
      "",
      "Tow-level counts are recorded here.",
      "",
      "```{r}",
      "semantic_hint <- 'estimated number of spawners'",
      "```"
    ),
    qmd_path
  )

  result <- metasalmon:::.ms_context_text_from_file(qmd_path)
  expect_true(is.list(result))
  expect_equal(result$source, "context.qmd")
  expect_match(result$text, "Tow-level counts are recorded here.", fixed = TRUE)
  expect_match(result$text, "semantic_hint <- 'estimated number of spawners'", fixed = TRUE)
  expect_false(grepl("```", result$text, fixed = TRUE))
  expect_false(grepl("format:", result$text, fixed = TRUE))
})

test_that("R script context files preserve code and comments", {
  tmp <- withr::local_tempdir()
  r_path <- file.path(tmp, "context.R")

  writeLines(
    c(
      "# estimated number of spawners",
      "semantic_hint <- 'estimated number of spawners'"
    ),
    r_path
  )

  result <- metasalmon:::.ms_context_text_from_file(r_path)
  expect_true(is.list(result))
  expect_equal(result$source, "context.R")
  expect_match(result$text, "# estimated number of spawners", fixed = TRUE)
  expect_match(result$text, "semantic_hint <- 'estimated number of spawners'", fixed = TRUE)
})

test_that("DOCX context files are converted to plain text", {
  tmp <- withr::local_tempdir()
  docx_path <- file.path(tmp, "context.docx")
  docx_b64 <- paste0(
    "UEsDBBQAAAAIAGmFglzXeYTq8QAAALgBAAATAAAAW0NvbnRlbnRfVHlwZXNdLnhtbH2QzU7DMBCE730Ky9cqccoBIZSkB36OwKE8wMreJFb9J69b2rdn00KREOVozXwz62nXB+/EHjPZGDq5qhspMOhobBg7+b55ru6koALBgIsBO3lEkut+0W6OCUkwHKiTUynpXinSE3qgOiYMrAwxeyj8zKNKoLcworppmlulYygYSlXmDNkvhGgfcYCdK+LpwMr5loyOpHg4e+e6TkJKzmoorKt9ML+Kqq+SmsmThyabaMkGqa6VzOL1jh/0lSfK1qB4g1xewLNRfcRslIl65xmu/0/649o4DFbjhZ/TUo4aiXh77+qL4sGG71+06jR8/wlQSwMEFAAAAAgAaYWCXCAbhuqyAAAALgEAAAsAAABfcmVscy8ucmVsc43Puw6CMBQG4J2naM4uBQdjDIXFmLAafICmPZRGeklbL7y9HRzEODie23fyN93TzOSOIWpnGdRlBQStcFJbxeAynDZ7IDFxK/nsLDJYMELXFs0ZZ57yTZy0jyQjNjKYUvIHSqOY0PBYOo82T0YXDE+5DIp6Lq5cId1W1Y6GTwPagpAVS3rJIPSyBjIsHv/h3ThqgUcnbgZt+vHlayPLPChMDB4uSCrf7TKzQHNKuorZvgBQSwMEFAAAAAgAaYWCXClsz4HPAAAAQgEAABEAAAB3b3JkL2RvY3VtZW50LnhtbG1PMW7DMAzc8wpCeyO3Q1EYtrP1BelcyBKTCLBIgZTr+veV0nbLcrjDkcfjcPpOC3yhaGQazfOxM4DkOUS6jubj/P70ZkCLo+AWJhzNjmpO02HY+sB+TUgFagJpv43mVkrurVV/w+T0yBmpeheW5EqVcrUbS8jCHlXrgbTYl657tclFMtMBoKbOHPZG7yJPFaRBmc7itgXmyOpSXhBC9KV2drIPtvkN5Y754b5mtxHKp+e1dh4BtcTaCwPQmmYU4Av8zejDxEZ+2zX2//30A1BLAQIUAxQAAAAIAGmFglzXeYTq8QAAALgBAAATAAAAAAAAAAAAAACAAQAAAABbQ29udGVudF9UeXBlc10ueG1sUEsBAhQDFAAAAAgAaYWCXCAbhuqyAAAALgEAAAsAAAAAAAAAAAAAAIABIgEAAF9yZWxzLy5yZWxzUEsBAhQDFAAAAAgAaYWCXClsz4HPAAAAQgEAABEAAAAAAAAAAAAAAIAB/QEAAHdvcmQvZG9jdW1lbnQueG1sUEsFBgAAAAADAAMAuQAAAPsCAAAAAA=="
  )
  writeBin(jsonlite::base64_dec(docx_b64), docx_path)

  result <- metasalmon:::.ms_context_text_from_file(docx_path)
  expect_true(is.list(result))
  expect_equal(result$source, "context.docx")
  expect_match(result$text, "Trawl biosample dictionary", fixed = TRUE)
  expect_match(result$text, "spawner_count = estimated number of spawners", fixed = TRUE)
})

test_that("unsupported context files warn without cli interpolation errors", {
  tmp <- withr::local_tempdir()
  doc_path <- file.path(tmp, "context.doc")
  writeLines("not really a doc", doc_path)

  expect_warning(
    result <- metasalmon:::.ms_context_text_from_file(doc_path),
    "Skipping unsupported context file"
  )
  expect_null(result)
})

test_that("validate_dictionary keeps strong non-strict warnings for direct review markers and gaps", {
  dict_with_review <- test_dictionary(
    dataset_id = "demo",
    table_id = "main",
    column_name = "spawner_count",
    column_label = "Spawner count",
    column_description = "Spawner abundance",
    column_role = "measurement",
    value_type = "integer",
    required = TRUE,
    term_iri = "REVIEW: https://w3id.org/smn/SpawnerAbundance",
    property_iri = "https://w3id.org/smn/SpawnerAbundance",
    entity_iri = "https://w3id.org/smn/Spawner",
    unit_iri = "https://qudt.org/vocab/unit/NUM",
    unit_label = "count",
    constraint_iri = NA_character_,
    statistical_modifier_iri = NA_character_
  )

  dict_with_missing <- test_dictionary(
    dataset_id = "demo",
    table_id = "main",
    column_name = "spawner_count",
    column_label = "Spawner count",
    column_description = "Spawner abundance",
    column_role = "measurement",
    value_type = "integer",
    required = TRUE,
    term_iri = NA_character_,
    property_iri = NA_character_,
    entity_iri = NA_character_,
    unit_iri = NA_character_,
    unit_label = "count",
    constraint_iri = NA_character_,
    statistical_modifier_iri = NA_character_
  )

  expect_warning(
    validate_dictionary(dict_with_review, require_iris = FALSE),
    "REVIEW-prefixed IRI values were found"
  )
  expect_warning(
    validate_dictionary(dict_with_missing, require_iris = FALSE),
    "definitely should fill those out"
  )
})

test_that("validate_dictionary fails final validation when REVIEW-prefixed IRIs remain", {
  dict <- test_dictionary(
    dataset_id = "demo",
    table_id = "main",
    column_name = "spawner_count",
    column_label = "Spawner count",
    column_description = "Spawner abundance",
    column_role = "measurement",
    value_type = "integer",
    required = TRUE,
    term_iri = "REVIEW: https://w3id.org/smn/SpawnerAbundance",
    property_iri = "https://w3id.org/smn/SpawnerAbundance",
    entity_iri = "https://w3id.org/smn/Spawner",
    unit_iri = "https://qudt.org/vocab/unit/NUM",
    unit_label = "count",
    constraint_iri = NA_character_,
    statistical_modifier_iri = NA_character_
  )

  expect_error(
    validate_dictionary(dict, require_iris = TRUE),
    "REVIEW-prefixed IRI"
  )
})
