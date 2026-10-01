# B-58: selective handlers must reach actual package emissions, not only a
# synthetic constructor. The coverage guard traverses all namespace function
# bodies (including nested functions), with no filename/function allowlist.
# Retires when emissions use one checked constructor, or these APIs disappear.

condition_call_name <- function(node) {
  if (is.name(node)) return(as.character(node))
  if (is.call(node) && identical(node[[1]], as.name("::"))) {
    return(paste0(as.character(node[[2]]), "::", as.character(node[[3]])))
  }
  ""
}

unclassed_condition_calls <- function(node) {
  bad <- character()
  if (is.call(node)) {
    name <- condition_call_name(node[[1]])
    severity <- if (name %in% c("cli_abort", "cli::cli_abort", "rlang::abort")) {
      "error"
    } else if (name %in% c("cli_warn", "cli::cli_warn", "warning", "base::warning")) {
      "warning"
    } else {
      NULL
    }
    if (!is.null(severity)) {
      cls <- node[["class"]]
      if (name %in% c("warning", "base::warning")) {
        inner <- if (length(node) > 1L) node[[2L]] else NULL
        cls <- if (is.call(inner) && condition_call_name(inner[[1L]]) %in%
                   c("warningCondition", "base::warningCondition")) inner[["class"]] else NULL
      }
      good <- is.call(cls) && identical(cls[[1]], as.name(".ms_condition_classes")) &&
        length(cls) >= 3L && identical(cls[[2]], severity) &&
        (is.null(cls[[3]]) || (is.character(cls[[3]]) && length(cls[[3]]) == 1L &&
          cls[[3]] %in% c("validation", "llm", "publication", "retrieval")))
      if (!good) bad <- c(bad, paste(deparse(node), collapse = " "))
    }
  }
  if (is.call(node) || is.pairlist(node) || is.expression(node)) {
    for (part in as.list(node)) {
      if (!missing(part) && (is.call(part) || is.pairlist(part))) {
        bad <- c(bad, unclassed_condition_calls(part))
      }
    }
  }
  bad
}

test_that("every owned cli/rlang emission carries the common class hierarchy", {
  ns <- asNamespace("metasalmon")
  findings <- character()
  for (name in ls(ns, all.names = TRUE)) {
    fn <- get(name, envir = ns)
    if (is.function(fn)) {
      findings <- c(findings, paste0(name, ": ", unclassed_condition_calls(body(fn))))
    }
  }
  # Filter empty concatenations produced by functions with no emissions.
  findings <- findings[!grepl(": $", findings)]
  expect_true(length(findings) == 0L, info = paste(findings, collapse = "\n"))
})

test_that("the coverage instrument rejects missing and wrong severity classes", {
  expect_length(unclassed_condition_calls(quote(cli::cli_abort("invalid"))), 1L)
  expect_length(unclassed_condition_calls(quote(warning("invalid", call. = FALSE))), 1L)
  expect_length(unclassed_condition_calls(quote(cli::cli_warn(
    "invalid", class = .ms_condition_classes("error", NULL)
  ))), 1L)
  expect_length(unclassed_condition_calls(quote(cli::cli_abort(
    "valid", class = .ms_condition_classes("error", "validation")
  ))), 0L)
})

test_that("the real base BioPortal warning keeps text, simpleWarning and muffling", {
  captured <- NULL
  withr::with_envvar(c(BIOPORTAL_APIKEY = NA), {
    withr::with_options(list(metasalmon.warned_bioportal_missing = FALSE), {
      result <- withCallingHandlers(.search_bioportal("salmon", "entity"),
        metasalmon_retrieval_warning = function(cnd) {
          captured <<- cnd
          invokeRestart("muffleWarning")
        })
      expect_equal(nrow(result), 0L)
    })
  })
  expect_s3_class(captured, "simpleWarning")
  expect_s3_class(captured, "metasalmon_warning")
  expect_null(captured$call)
  expect_match(conditionMessage(captured), "BioPortal API key missing", fixed = TRUE)
})

test_that("actual offline subsystem failures support selective tryCatch", {
  cases <- list(
    validation = function() .ms_validate_sdp_schema(list()),
    llm = function() .ms_llm_cast_assessment_column("not-logical", logical(), "accepted"),
    publication = function() .ms_knb_config("not-an-environment"),
    retrieval = function() ices_codes("")
  )
  for (family in names(cases)) {
    handlers <- setNames(list(function(cnd) cnd), paste0("metasalmon_", family, "_error"))
    cnd <- do.call(tryCatch, c(list(expr = quote(cases[[family]]())), handlers,
                              list(error = function(cnd) "wrong family")))
    expect_s3_class(cnd, paste0("metasalmon_", family, "_error"))
    expect_s3_class(cnd, "metasalmon_error")
    expect_s3_class(cnd, "metasalmon_condition")
  }
})

test_that("specialized packet codes and deprecation warning classes survive", {
  cnd <- tryCatch(.ms_semantic_review_abort("packet_unbound", "Unbound packet."),
                  metasalmon_error = identity, error = function(cnd) NULL)
  expect_s3_class(cnd, "metasalmon_semantic_review_packet_unbound")
  expect_s3_class(cnd, "metasalmon_semantic_review_error")
  expect_identical(cnd$code, "packet_unbound")
  expect_identical(conditionMessage(cnd), "Unbound packet.")

  warning <- NULL
  withr::with_options(list(metasalmon.llm_deprecation_quiet = FALSE), {
    withCallingHandlers(.ms_llm_deprecation_warn("chat_decomposition"),
      metasalmon_warning = function(cnd) {
        warning <<- cnd
        invokeRestart("muffleWarning")
      })
  })
  expect_s3_class(warning, "metasalmon_llm_deprecated")
  expect_s3_class(warning, "deprecatedWarning")
  expect_s3_class(warning, "metasalmon_llm_warning")
  expect_s3_class(warning, "metasalmon_warning")
  expect_s3_class(warning, "metasalmon_condition")
})

test_that("package bases catch own generic errors without catching dependencies", {
  cnd <- tryCatch(.ms_abort_external("Boundary: ", "plain text", call = NULL),
                  metasalmon_error = identity, error = function(cnd) NULL)
  expect_s3_class(cnd, "metasalmon_error")
  expect_identical(conditionMessage(cnd), "Boundary: plain text")
  expect_identical(tryCatch(stop("dependency failure"),
    metasalmon_error = function(cnd) "owned", error = function(cnd) "foreign"), "foreign")
})

test_that("legacy positional cli classes keep primary messages and selective catches", {
  dict <- infer_dictionary(data.frame(x = 1:5))
  for (field in c("value_type", "column_role")) {
    invalid <- dict
    invalid[[field]][1] <- "invalid_value"
    cnd <- tryCatch(validate_dictionary(invalid), metasalmon_validation_error = identity,
                    error = function(cnd) "wrong family")
    expect_s3_class(cnd, "metasalmon_validation_error")
    expect_match(conditionMessage(cnd), paste0("Invalid.*", field))
    # cli forwarded the old second positional string as rlang's class, not
    # as another message. Name it explicitly and preserve that legacy class.
    legacy <- if (field == "value_type") "Valid types: {.val {valid_types}}" else "Valid roles: {.val {valid_roles}}"
    expect_true(legacy %in% class(cnd))
  }
})
