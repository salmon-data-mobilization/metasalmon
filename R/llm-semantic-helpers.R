# What is left of the semantic-review helpers once the in-package model call was
# removed (hub item B-329, S16 step 3): the context readers and their chunking
# and scoring, which the review packet's excerpts come from; the scalar
# readers; the retry-query classifier; escalation of a final rejection; and the
# validation of one assessment. `write_semantic_review_packet()` and
# `ingest_semantic_assessments()` are their callers. Nothing here reaches a
# model provider, and `tests/testthat/test-semantic-review-packet.R` walks the
# call graph to prove it. The provider configuration, the request and retry
# code, the prompts and the orchestration that lived here are gone.

.ms_llm_first_scalar <- function(x) {
  if (is.null(x) || length(x) == 0) {
    return(NULL)
  }
  if (is.list(x)) {
    return(.ms_llm_first_scalar(x[[1]]))
  }
  x[[1]]
}

.ms_llm_non_empty_string <- function(x) {
  x <- .ms_llm_first_scalar(x)
  if (is.null(x) || length(x) == 0) {
    return(NA_character_)
  }
  x <- trimws(as.character(x))
  if (!nzchar(x) || is.na(x)) {
    return(NA_character_)
  }
  x
}

.ms_llm_optional_note <- function(x) {
  x <- .ms_llm_non_empty_string(x)
  if (is.na(x)) {
    return(NA_character_)
  }

  if (tolower(x) %in% c("false", "none", "n/a", "na", "null", "nil")) {
    return(NA_character_)
  }

  x
}

.ms_llm_scalar_numeric <- function(x) {
  x <- .ms_llm_first_scalar(x)
  if (is.null(x) || length(x) == 0) {
    return(NA_real_)
  }
  suppressWarnings(as.numeric(x))
}

.ms_supported_context_extensions <- function() {
  c("md", "txt", "csv", "tsv", "json", "yaml", "yml", "rst", "r", "rmd", "qmd", "pdf", "htm", "html", "docx", "xls", "xlsx", "xlsm")
}

.ms_context_text_from_excel <- function(path,
                                        max_sheets = 6L,
                                        max_rows = 200L,
                                        max_cols = 40L) {
  if (!requireNamespace("readxl", quietly = TRUE)) {
    cli::cli_abort(
      c(
        "Excel context files require the optional {.pkg readxl} package.",
        "i" = "Install it with {.code install.packages('readxl')} or remove the spreadsheet from {.arg llm_context_files}."
      )
    )
  }

  max_sheets <- max(1L, as.integer(max_sheets[[1]] %||% 6L))
  max_rows <- max(1L, as.integer(max_rows[[1]] %||% 200L))
  max_cols <- max(1L, as.integer(max_cols[[1]] %||% 40L))

  sheet_names <- readxl::excel_sheets(path)
  if (length(sheet_names) == 0L) {
    return("")
  }
  if (length(sheet_names) > max_sheets) {
    sheet_names <- sheet_names[seq_len(max_sheets)]
  }

  sheet_text <- purrr::map(sheet_names, function(sheet_name) {
    sheet_df <- readxl::read_excel(
      path,
      sheet = sheet_name,
      .name_repair = "minimal"
    )
    sheet_df <- tibble::as_tibble(sheet_df)
    if (ncol(sheet_df) == 0L && nrow(sheet_df) == 0L) {
      return(NULL)
    }

    truncated_rows <- FALSE
    truncated_cols <- FALSE

    if (ncol(sheet_df) > max_cols) {
      sheet_df <- sheet_df[, seq_len(max_cols), drop = FALSE]
      truncated_cols <- TRUE
    }
    if (nrow(sheet_df) > max_rows) {
      sheet_df <- sheet_df[seq_len(max_rows), , drop = FALSE]
      truncated_rows <- TRUE
    }

    col_names <- names(sheet_df)
    if (is.null(col_names)) {
      col_names <- rep("", ncol(sheet_df))
    }
    blank_names <- is.na(col_names) | !nzchar(trimws(col_names))
    if (any(blank_names)) {
      col_names[blank_names] <- paste0("column_", which(blank_names))
    }

    sheet_df[] <- lapply(sheet_df, function(col) {
      # A spreadsheet preview is user data rendered to text and written into
      # a review packet's excerpts, which the packet's id hashes, so the same
      # workbook must preview identically on every machine. Both branches were
      # wrong and in *different* ways: the POSIXt one through the platform's
      # `%Y`, and the Date one through `as.character()`, which is not `format()`
      # and drops the padding on every platform. See R/platform-time.R.
      if (inherits(col, "POSIXt")) {
        return(.ms_iso_stamp(col, "-%m-%d %H:%M:%S"))
      }
      if (inherits(col, "Date")) {
        return(.ms_iso_date(col))
      }
      out <- as.character(col)
      out[is.na(out)] <- ""
      trimws(out)
    })

    header <- paste(col_names, collapse = "\t")
    rows <- character()
    if (nrow(sheet_df) > 0L) {
      rows <- apply(as.data.frame(sheet_df, stringsAsFactors = FALSE), 1, function(row) {
        paste(as.character(row), collapse = "\t")
      })
    }

    notes <- character()
    if (isTRUE(truncated_cols)) {
      notes <- c(notes, sprintf("Note: truncated to first %d columns.", max_cols))
    }
    if (isTRUE(truncated_rows)) {
      notes <- c(notes, sprintf("Note: truncated to first %d rows.", max_rows))
    }

    paste(
      c(
        sprintf("Sheet: %s", sheet_name),
        header,
        rows,
        notes
      ),
      collapse = "\n"
    )
  })

  sheet_text <- unlist(sheet_text, use.names = FALSE)
  sheet_text <- sheet_text[nzchar(trimws(sheet_text))]
  paste(sheet_text, collapse = "\n\n")
}

.ms_context_text_from_rmarkdown <- function(path) {
  # Decode before trimws() or the fence checks inspect the lines: readLines()
  # only marks Windows-1252 bytes as UTF-8, while the shared text reader
  # validates and falls back to Windows-1252, then Latin-1.
  lines <- strsplit(.ms_read_text_utf8(path), "\n", fixed = TRUE)[[1]]
  if (length(lines) == 0L) {
    return("")
  }

  # Drop leading YAML front matter.
  if (length(lines) >= 1L && trimws(lines[[1]]) == "---") {
    end_idx <- which(trimws(lines[-1]) == "---")
    if (length(end_idx) > 0L) {
      lines <- lines[-seq_len(end_idx[[1]] + 1L)]
    }
  }

  keep <- character()
  for (line in lines) {
    trimmed <- trimws(line)
    if (grepl("^```", trimmed)) {
      next
    }
    keep <- c(keep, line)
  }

  paste(keep, collapse = "\n")
}

.ms_context_text_from_docx <- function(path) {
  tmp_dir <- tempfile("metasalmon-docx-")
  dir.create(tmp_dir)
  on.exit(unlink(tmp_dir, recursive = TRUE, force = TRUE), add = TRUE)

  utils::unzip(path, files = "word/document.xml", exdir = tmp_dir)
  document_path <- file.path(tmp_dir, "word", "document.xml")
  if (!file.exists(document_path)) {
    cli::cli_abort("DOCX context file {.path {path}} does not contain {.file word/document.xml}.")
  }

  doc <- xml2::read_xml(document_path)
  ns <- xml2::xml_ns(doc)
  paragraphs <- xml2::xml_find_all(doc, ".//w:p", ns = ns)
  paragraph_text <- vapply(paragraphs, function(node) {
    runs <- xml2::xml_find_all(node, ".//w:t", ns = ns)
    text <- trimws(xml2::xml_text(runs))
    text <- text[nzchar(text)]
    paste(text, collapse = "")
  }, character(1L))
  paragraph_text <- paragraph_text[nzchar(trimws(paragraph_text))]
  paste(paragraph_text, collapse = "\n")
}

.ms_context_text_from_html <- function(path) {
  doc <- xml2::read_html(path)
  scope <- xml2::xml_find_first(doc, ".//body")
  if (inherits(scope, "xml_missing")) {
    scope <- doc
  }

  nodes <- xml2::xml_find_all(
    scope,
    ".//text()[normalize-space() and not(ancestor::script) and not(ancestor::style)]"
  )
  text <- trimws(xml2::xml_text(nodes))
  text <- text[nzchar(text)]
  paste(text, collapse = "\n")
}

.ms_validate_llm_context_files <- function(context_files) {
  if (is.null(context_files)) {
    return(invisible(NULL))
  }

  if (!is.character(context_files)) {
    cli::cli_abort(c(
      "{.arg context_files} must be a character vector of local file paths.",
      "i" = "Pass paths such as {.code \"./00_data/Data_dictionary_final_dataset.csv\"}, not a parsed data frame, tibble, XML document, or R Markdown object."
    ))
  }

  bad <- is.na(context_files) | !nzchar(trimws(context_files))
  if (any(bad)) {
    cli::cli_abort("{.arg context_files} must not contain missing or empty paths.")
  }

  invisible(NULL)
}

# Read a plain-text context file as UTF-8, with a Latin-1/Windows-1252 fallback.
# readLines(encoding = "UTF-8") only *marks* the bytes as UTF-8 without verifying
# them, so a Latin-1/Windows-1252 file (common for field-data CSVs) would be left
# mis-encoded and the later enc2utf8() call would not repair it. Detect invalid
# UTF-8 and re-decode from the most likely single-byte encoding instead.
.ms_read_text_utf8 <- function(path) {
  text <- paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  if (!nzchar(text) || all(validUTF8(text))) {
    return(text)
  }
  native <- paste(readLines(path, warn = FALSE), collapse = "\n")
  converted <- iconv(native, from = "windows-1252", to = "UTF-8", sub = "")
  if (is.na(converted) || !nzchar(converted)) {
    converted <- iconv(native, from = "latin1", to = "UTF-8", sub = "")
  }
  if (is.na(converted)) text else converted
}

.ms_context_text_from_file <- function(path) {
  normalized <- normalizePath(path, winslash = "/", mustWork = FALSE)
  if (!file.exists(normalized)) {
    cli::cli_abort("Context file does not exist: {.path {path}}")
  }

  ext <- tolower(tools::file_ext(normalized))
  supported_extensions <- .ms_supported_context_extensions()
  if (!ext %in% supported_extensions) {
    cli::cli_warn(
      "Skipping unsupported context file {.path {path}}. Supported extensions: {.val {(supported_extensions)}}"
    )
    return(NULL)
  }

  if (ext %in% c("xls", "xlsx", "xlsm")) {
    text <- .ms_context_text_from_excel(normalized)
  } else if (identical(ext, "pdf")) {
    if (!requireNamespace("pdftools", quietly = TRUE)) {
      cli::cli_abort(
        c(
          "PDF context files require the optional {.pkg pdftools} package.",
          "i" = "Install it with {.code install.packages('pdftools')} or remove the PDF from {.arg llm_context_files}."
        )
      )
    }
    pages <- pdftools::pdf_text(normalized)
    text <- paste(pages, collapse = "\n\n")
  } else if (ext %in% c("htm", "html")) {
    text <- .ms_context_text_from_html(normalized)
  } else if (ext %in% c("rmd", "qmd")) {
    text <- .ms_context_text_from_rmarkdown(normalized)
  } else if (identical(ext, "docx")) {
    text <- .ms_context_text_from_docx(normalized)
  } else {
    text <- .ms_read_text_utf8(normalized)
  }

  text <- enc2utf8(text)
  text <- trimws(text)
  if (!nzchar(text)) {
    cli::cli_warn("Skipping empty context file {.path {path}}.")
    return(NULL)
  }

  list(
    path = normalized,
    source = basename(normalized),
    text = text
  )
}

.ms_chunk_context_text <- function(text, source, chunk_chars = 2200L, overlap_chars = 200L) {
  text <- enc2utf8(as.character(text[[1]] %||% ""))
  if (!nzchar(trimws(text))) {
    return(tibble::tibble())
  }

  chunk_chars <- max(400L, as.integer(chunk_chars[[1]] %||% 2200L))
  overlap_chars <- max(0L, min(as.integer(overlap_chars[[1]] %||% 200L), chunk_chars %/% 2L))
  starts <- seq.int(1L, nchar(text), by = max(1L, chunk_chars - overlap_chars))

  purrr::map_dfr(seq_along(starts), function(i) {
    start <- starts[[i]]
    end <- min(nchar(text), start + chunk_chars - 1L)
    tibble::tibble(
      source = source,
      chunk_id = paste0(source, "#", i),
      chunk_text = trimws(substr(text, start, end))
    )
  }) |> dplyr::filter(nzchar(.data$chunk_text))
}

.ms_context_tokens <- function(...) {
  text <- paste(unlist(list(...)), collapse = " ")
  text <- tolower(text)
  text <- gsub("([a-z0-9])([A-Z])", "\\1 \\2", text, perl = TRUE)
  text <- gsub("[^a-z0-9]+", " ", text)
  tokens <- unlist(strsplit(text, "\\s+"))
  tokens <- tokens[nzchar(tokens)]
  tokens[nchar(tokens) >= 3L]
}

.ms_score_context_chunks <- function(chunks, target_row, candidate_rows, max_chunks = 4L) {
  if (nrow(chunks) == 0) {
    return(chunks)
  }

  query_bits <- c(
    target_row$search_query[[1]] %||% "",
    target_row$target_label[[1]] %||% "",
    target_row$target_description[[1]] %||% "",
    target_row$column_label[[1]] %||% "",
    target_row$column_description[[1]] %||% "",
    candidate_rows$label %||% character(),
    candidate_rows$definition %||% character()
  )
  query_tokens <- unique(.ms_context_tokens(query_bits))
  if (length(query_tokens) == 0) {
    return(utils::head(chunks, max_chunks))
  }

  chunks$context_score <- vapply(chunks$chunk_text, function(text) {
    chunk_tokens <- .ms_context_tokens(text)
    if (length(chunk_tokens) == 0) {
      return(0)
    }
    sum(query_tokens %in% chunk_tokens)
  }, numeric(1))

  # Radix, because this order reaches the review packet's bytes and its
  # `packet_id` (hub item B-326): the `source` tie-break is character text,
  # and a locale-collated sort would rank two sources differently on two
  # machines.
  chunks <- chunks[order(-chunks$context_score, nchar(chunks$chunk_text), chunks$source, method = "radix"), , drop = FALSE]
  utils::head(chunks, max(1L, as.integer(max_chunks[[1]] %||% 4L)))
}

# Make context source labels unique. basename() collisions (e.g. two files named
# README.md in different folders) would otherwise produce colliding chunk_ids and
# silently merge in the user-visible llm_context_sources column. Labels that are
# already unique are left untouched so the observable source-reporting contract is
# preserved; collisions are disambiguated with the parent directory, then a
# numeric suffix as a final safety net.
.ms_unique_context_sources <- function(raw_context) {
  if (length(raw_context) < 2L) {
    return(raw_context)
  }
  sources <- vapply(raw_context, function(x) as.character(x$source %||% ""), character(1))
  dup_labels <- unique(sources[duplicated(sources)])
  if (length(dup_labels) == 0L) {
    return(raw_context)
  }
  for (i in seq_along(raw_context)) {
    if (!sources[[i]] %in% dup_labels) {
      next
    }
    path <- raw_context[[i]]$path
    if (!is.null(path) && !is.na(path) && nzchar(path)) {
      parent <- basename(dirname(path))
      if (nzchar(parent) && !parent %in% c(".", "/")) {
        raw_context[[i]]$source <- file.path(parent, sources[[i]])
      }
    }
  }
  final <- vapply(raw_context, function(x) as.character(x$source %||% ""), character(1))
  if (anyDuplicated(final) > 0L) {
    final <- make.unique(final, sep = " #")
    for (i in seq_along(raw_context)) {
      raw_context[[i]]$source <- final[[i]]
    }
  }
  raw_context
}

.ms_collect_context_chunks <- function(context_files = NULL,
                                       context_text = NULL) {
  .ms_validate_llm_context_files(context_files)

  raw_context <- list()
  if (!is.null(context_files) && length(context_files) > 0) {
    raw_context <- c(raw_context, lapply(context_files, .ms_context_text_from_file))
  }
  inline_text <- character()
  if (!is.null(context_text)) {
    inline_text <- trimws(as.character(context_text))
    inline_text <- inline_text[
      !is.na(inline_text) & nzchar(inline_text)
    ]
  }

  raw_context <- Filter(Negate(is.null), raw_context)
  if (length(raw_context) == 0L && length(inline_text) == 0L) {
    return(tibble::tibble())
  }

  raw_context <- .ms_unique_context_sources(raw_context)

  file_chunks <- purrr::map_dfr(raw_context, function(item) {
    .ms_chunk_context_text(item$text, item$source)
  })
  inline_chunks <- purrr::imap_dfr(inline_text, function(text, item_index) {
    chunks <- .ms_chunk_context_text(text, "inline_context")
    if (nrow(chunks) > 0L) {
      chunks$chunk_id <- paste0(
        "inline_context[",
        item_index,
        "]#",
        seq_len(nrow(chunks))
      )
    }
    chunks
  })
  pool <- dplyr::bind_rows(file_chunks, inline_chunks)
  # The review packet records each context input with its SHA-256 (hub item
  # B-326): a file by the digest of its bytes, inline text by the digest of
  # the text. Attached here, where the source labels are assigned, so the
  # packet's labels and the excerpts' labels are one rendering.
  attr(pool, "context_inputs") <- dplyr::bind_rows(
    purrr::map_dfr(raw_context, function(item) {
      tibble::tibble(
        source = as.character(item$source),
        kind = "file",
        sha256 = digest::digest(
          readBin(item$path, what = "raw", n = file.info(item$path)$size),
          algo = "sha256",
          serialize = FALSE
        )
      )
    }),
    purrr::imap_dfr(inline_text, function(text, item_index) {
      tibble::tibble(
        source = paste0("inline_context[", item_index, "]"),
        kind = "text",
        sha256 = digest::digest(charToRaw(enc2utf8(text)), algo = "sha256", serialize = FALSE)
      )
    })
  )
  pool
}

.ms_prepare_context_chunks <- function(target_row,
                                       candidate_rows,
                                       max_chunks = 4L,
                                       context_chunk_pool = NULL) {
  chunks <- context_chunk_pool
  if (is.null(chunks)) {
    cli::cli_abort(
      "{.fn .ms_prepare_context_chunks} requires a pre-collected context chunk pool."
    )
  }
  if (nrow(chunks) == 0) {
    return(chunks)
  }

  .ms_score_context_chunks(chunks, target_row = target_row, candidate_rows = candidate_rows, max_chunks = max_chunks)
}

.ms_llm_normalize_query_text <- function(x) {
  text <- .ms_llm_non_empty_string(x)
  if (is.na(text)) {
    return(NA_character_)
  }
  trimws(gsub("\\s+", " ", text))
}

# Fold case over the ASCII letters only, identically in every locale.
# `tolower()` folds non-ASCII letters according to the locale, so a
# comparison built on it answers differently on different machines: the
# retry-query duplicate check called a pair differing only in an accented
# letter's case a duplicate under en_US.UTF-8 and not under C (hub item
# B-361, defect 5). metasalmonpy's B-362 mirrors this rule exactly.
.ms_ascii_tolower <- function(x) {
  chartr("ABCDEFGHIJKLMNOPQRSTUVWXYZ", "abcdefghijklmnopqrstuvwxyz", x)
}

# A retry query is an identifier when it is a URL, a URN, a DOI, or a CURIE
# with no whitespace, whatever letters the CURIE holds. The CURIE's local part
# is `[^[:space:]]+`, the class the normalizer's `\\s` collapses, so after
# normalization the only whitespace it can meet is a single space. It was
# `[^\\s]+`, and R's default TRE engine reads a backslash inside a bracket
# expression literally, so that class meant "neither a backslash nor the
# letter s": `smn:species` was a lexical query and `abc:d e` an identifier
# (hub item B-380; metasalmonpy reproduced the quirk on purpose under B-362
# and retires it under B-381).
.ms_llm_query_looks_like_identifier <- function(x) {
  text <- .ms_llm_normalize_query_text(x)
  if (is.na(text)) {
    return(FALSE)
  }

  grepl("^(https?://|urn:|doi:)", text, ignore.case = TRUE) ||
    grepl("^[A-Za-z][A-Za-z0-9._+-]*:[^[:space:]]+$", text)
}

.ms_llm_classify_retry_query <- function(retry_query, original_query) {
  retry <- .ms_llm_normalize_query_text(retry_query)
  original <- .ms_llm_normalize_query_text(original_query)
  disposition <- if (is.na(retry)) {
    "invalid"
  } else if (!is.na(original) &&
      identical(.ms_ascii_tolower(retry), .ms_ascii_tolower(original))) {
    "duplicate_original_query"
  } else if (.ms_llm_query_looks_like_identifier(retry)) {
    "identifier_like"
  } else {
    "use_query"
  }

  list(
    query = retry,
    original_query = original,
    disposition = disposition,
    rejection_reason = if (identical(
      disposition,
      "duplicate_original_query"
    )) {
      "duplicate_original_query"
    } else {
      NA_character_
    }
  )
}

.ms_llm_apply_retry_query_classification <- function(assessment,
                                                     classification) {
  if (!identical(
    classification$disposition,
    "duplicate_original_query"
  )) {
    return(assessment)
  }

  assessment$llm_retry_query_rejection_reason <-
    classification$rejection_reason
  note <- paste(
    "Retry query matched the original query after case and whitespace normalization;",
    "the retry was not issued."
  )
  existing <- .ms_llm_non_empty_string(
    assessment$llm_rationale[[1]] %||% NA_character_
  )
  assessment$llm_rationale <- if (is.na(existing)) {
    note
  } else {
    paste(existing, note)
  }
  assessment
}

.ms_llm_add_exploration_metadata <- function(assessment_row,
                                             used = FALSE,
                                             queries = character(),
                                             candidate_gain = 0L) {
  assessment_row <- tibble::as_tibble(assessment_row)
  if (nrow(assessment_row) == 0) {
    return(assessment_row)
  }

  assessment_row$llm_exploration_used <- isTRUE(used)
  assessment_row$llm_exploration_queries <- if (length(queries) > 0) paste(queries, collapse = " | ") else NA_character_
  assessment_row$llm_exploration_candidate_gain <- as.integer(candidate_gain[[1]] %||% 0L)
  assessment_row
}

# reject_shortlist means the harness judged every candidate to be the wrong
# concept family. A final rejection is escalated to request_new_term so the
# likely ontology gap is surfaced to the new-term workflow instead of being left
# as a dead-end rejection; in the review-packet contract a rejection earns no
# second pass, so the ingester escalates it at once. Any other final decision is
# left untouched.
#
# The rule is "any FINAL reject_shortlist escalates", whatever the decision
# before the retry was (hub item B-361, Brett's 2026-09-25 ruling on decision
# 10 of the S16 execplan). Until then this escalated only when the pre-retry
# decision was also a rejection, so retry_search followed by reject_shortlist
# was stored as a dead end, which contradicted AGENTS.md. `pre_assessment` may
# be NULL when there is no earlier answer for the target; it is used only to
# label the rationale when the earlier answer was itself a rejection.
.ms_llm_escalate_unresolved_rejection <- function(pre_assessment, explored) {
  assessment <- explored$assessment
  post_decision <- .ms_llm_non_empty_string(assessment$llm_decision[[1]] %||% NA_character_)
  if (!identical(post_decision, "reject_shortlist")) {
    return(explored)
  }

  pre_decision <- .ms_llm_non_empty_string(pre_assessment$llm_decision[[1]] %||% NA_character_)
  pre_rationale <- .ms_llm_non_empty_string(
    pre_assessment$llm_rationale[[1]] %||% NA_character_
  )
  post_rationale <- .ms_llm_non_empty_string(
    assessment$llm_rationale[[1]] %||% NA_character_
  )

  assessment$llm_decision <- "request_new_term"
  assessment$llm_selected_candidate_index <- NA_integer_
  assessment$llm_selected_iri <- NA_character_
  assessment$llm_selected_label <- NA_character_
  assessment$llm_escalated_from <- "reject_shortlist"

  rationale_parts <- character()
  if (identical(pre_decision, "reject_shortlist")) {
    # The earlier answer was a rejection too: keep both, labelled, when they
    # differ, and the initial one alone when the retry repeated it.
    if (!is.na(pre_rationale)) {
      rationale_parts <- c(
        rationale_parts,
        paste0("Initial shortlist rejection: ", pre_rationale)
      )
    }
    if (!is.na(post_rationale) &&
        (is.na(pre_rationale) || !identical(post_rationale, pre_rationale))) {
      rationale_parts <- c(
        rationale_parts,
        paste0("Post-retry shortlist rejection: ", post_rationale)
      )
    }
  } else if (!is.na(post_rationale)) {
    # The earlier answer was not a rejection (or there was none), so the
    # final rationale is the only rejection rationale and needs no label.
    rationale_parts <- c(rationale_parts, post_rationale)
  }
  note <- paste(
    "Shortlist rejected and exploration found no acceptable candidate;",
    "escalated to request_new_term so the likely ontology gap is surfaced."
  )
  assessment$llm_rationale <- paste(c(rationale_parts, note), collapse = " ")
  explored$assessment <- assessment
  explored
}

# Append a package note to a rationale that may be NA or empty. The parts join
# with one space and an absent rationale contributes nothing, so a downgrade
# with no rationale never starts with the literal text "NA " (hub item B-361,
# defect 4: `paste(c(NA, note))` rendered the NA, and `nzchar(NA)` is TRUE so
# the filter that was meant to drop it did not).
.ms_llm_append_note <- function(rationale, note) {
  parts <- c(rationale, note)
  parts <- parts[!is.na(parts) & nzchar(parts)]
  if (length(parts) == 0L) {
    return(NA_character_)
  }
  paste(parts, collapse = " ")
}

.ms_validate_llm_assessment <- function(result, candidate_rows) {
  decision <- tolower(.ms_llm_non_empty_string(result$decision %||% NA_character_))
  aliases <- c(propose_new_term = "request_new_term")
  if (!is.na(decision) && decision %in% names(aliases)) {
    decision <- aliases[[decision]]
  }
  allowed_decisions <- c("accept", "review", "retry_search", "request_new_term", "reject_shortlist")
  if (is.na(decision) || !decision %in% allowed_decisions) {
    cli::cli_abort("LLM assessment must return decision = accept, review, retry_search, request_new_term, or reject_shortlist.")
  }

  # The index is read as a number here and cast to integer only once it has
  # passed the whole-number and range checks below. `as.integer()` truncates,
  # which is what let 1.9 select candidate 1 (hub item B-361, defect 3). A
  # value that is not a number at all reads as NA, meaning no candidate was
  # selected.
  selected_index <- .ms_llm_first_scalar(result$selected_candidate_index %||% NULL)
  if (is.null(selected_index) || identical(as.character(selected_index), "") || isFALSE(length(selected_index) > 0)) {
    selected_index <- NA_real_
  } else {
    selected_index <- suppressWarnings(as.numeric(selected_index))
  }

  confidence <- .ms_llm_scalar_numeric(result$confidence %||% NA_real_)
  if (is.na(confidence) || confidence < 0 || confidence > 1) {
    cli::cli_abort("LLM assessment confidence must be numeric and between 0 and 1.")
  }

  rationale <- .ms_llm_non_empty_string(result$rationale %||% NA_character_)
  retry_query <- .ms_llm_optional_note(result$retry_query %||% result$alternate_query %||% NA_character_)
  bundle_summary <- .ms_llm_optional_note(result$bundle_summary %||% result$whole_variable_summary %||% NA_character_)
  suggested_label <- .ms_llm_optional_note(result$suggested_label %||% NA_character_)
  suggested_definition <- .ms_llm_optional_note(result$suggested_definition %||% NA_character_)
  suggested_namespace <- .ms_llm_optional_note(result$suggested_namespace %||% result$namespace %||% NA_character_)

  if (identical(decision, "accept") && is.na(selected_index)) {
    decision <- "review"
    rationale <- .ms_llm_append_note(
      rationale,
      "Model returned accept without selecting a candidate; downgraded to review."
    )
  }
  if (!identical(decision, "accept")) {
    # These decisions never select a candidate, so the index is cleared BEFORE
    # it is range-checked: a reject_shortlist carrying a stray out-of-range
    # index used to be downgraded to review here, and its ontology gap was
    # then never escalated (B-361, defect 2). reject_shortlist is preserved as
    # a distinct decision (not downgraded to review) so the stored
    # llm_decision carries the rejection; the ingester then escalates a final
    # rejection to request_new_term via
    # .ms_llm_escalate_unresolved_rejection().
    selected_index <- NA_integer_
  } else if (selected_index != trunc(selected_index)) {
    cli::cli_abort(
      "LLM assessment selected_candidate_index must be a whole number, not {format(selected_index, digits = 15)}."
    )
  } else if (selected_index < 1 || selected_index > nrow(candidate_rows)) {
    decision <- "review"
    selected_index <- NA_integer_
    rationale <- .ms_llm_append_note(
      rationale,
      "Model returned an out-of-range candidate index; downgraded to review."
    )
  } else {
    selected_index <- as.integer(selected_index)
  }
  if (identical(decision, "retry_search") && is.na(retry_query)) {
    decision <- "review"
    rationale <- .ms_llm_append_note(
      rationale,
      "Model requested retry_search without providing a retry query; downgraded to review."
    )
  }

  list(
    decision = decision,
    selected_candidate_index = selected_index,
    confidence = confidence,
    rationale = rationale,
    missing_context = .ms_llm_optional_note(result$missing_context %||% NA_character_),
    bundle_summary = bundle_summary,
    retry_query = retry_query,
    suggested_label = suggested_label,
    suggested_definition = suggested_definition,
    suggested_namespace = suggested_namespace
  )
}
