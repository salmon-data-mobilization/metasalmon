# Deprecation of the in-package model call (S16 step 1, hub item B-326).
#
# Brett ruled on 2026-09-25 (hub Q67) that the model call leaves metasalmon
# and metasalmonpy: judgement runs in the user's harness against a review
# packet, and the package reads the answers back. The in-package call --
# `llm_assess = TRUE`, the eleven `llm_*` arguments and `chat_decomposition()`
# -- keeps working through the 0.6.x releases and warns once per top-level
# call that it is deprecated, naming the removal release and the replacement.
# The removal is the breaking release the S16 card sequences after at least
# one tagged 0.6.x (hub items B-329 and B-330).
#
# The rules, from section 6 of the S16 execplan:
#
#   * The warning fires on `suggest_semantics()`, `infer_dictionary()`,
#     `infer_salmon_datapackage_artifacts()` and `create_sdp()` whenever
#     `llm_assess = TRUE` or any `llm_*` argument is supplied, which each entry
#     point detects with `missing()`, and on every call to
#     `chat_decomposition()`.
#   * Exactly one warning per TOP-LEVEL call. The four entry points nest
#     (`create_sdp()` calls `infer_salmon_datapackage_artifacts()`, which calls
#     `infer_dictionary()`, which calls `suggest_semantics()`) and every inner
#     call receives the `llm_*` arguments explicitly, so `missing()` is FALSE
#     there. Each entry point therefore registers a scope on entry and only the
#     outermost scope may warn.
#   * Emitted AFTER the existing opt-in warnings ("`llm_context_files` is
#     ignored unless `llm_assess = TRUE`"), which fire inside the call: the
#     outermost scope warns when it closes, on the caller's `on.exit`. The
#     opt-in contract itself is untouched: context supplied without
#     `llm_assess` still warns that it is ignored and makes no call.
#   * A suite-wide quiet switch, the option `metasalmon.llm_deprecation_quiet`,
#     keeps every existing test byte-identical; the test setup file sets it,
#     and the tests that assert the warning switch it off locally.
#
# The warning is a classed `cli::cli_warn()` (`metasalmon_llm_deprecated`,
# `deprecatedWarning`) so a caller can `suppressWarnings(classes = )` it or
# assert on it by class.

.ms_llm_deprecation_env <- new.env(parent = emptyenv())
.ms_llm_deprecation_env$depth <- 0L

.ms_llm_deprecation_removal_release <- function() {
  "0.7.0"
}

# Enter a deprecation scope. Returns the depth the caller found, which is 0
# for a top-level call; the caller hands it back to `.ms_llm_deprecation_exit()`
# on its `on.exit`.
.ms_llm_deprecation_enter <- function() {
  depth <- .ms_llm_deprecation_env$depth
  .ms_llm_deprecation_env$depth <- depth + 1L
  depth
}

# Leave a scope: restore the depth the caller found and, when that call was the
# outermost one and the deprecated surface was used, warn once.
.ms_llm_deprecation_exit <- function(depth, entry, triggered) {
  .ms_llm_deprecation_env$depth <- depth
  if (depth > 0L || !isTRUE(triggered)) {
    return(invisible(FALSE))
  }
  .ms_llm_deprecation_warn(entry)
}

.ms_llm_deprecation_quiet <- function() {
  isTRUE(getOption("metasalmon.llm_deprecation_quiet", FALSE))
}

# `entry` is one of the five entry-point names, all literals in this package;
# the message template is a literal too.
.ms_llm_deprecation_warn <- function(entry) {
  if (.ms_llm_deprecation_quiet()) {
    return(invisible(FALSE))
  }
  release <- .ms_llm_deprecation_removal_release()
  surface <- if (identical(entry, "chat_decomposition")) {
    "{.fn chat_decomposition} is deprecated and will be removed in metasalmon {release}."
  } else {
    "{.code llm_assess = TRUE} and the {.code llm_*} arguments of {.fn {entry}} are deprecated and will be removed in metasalmon {release}."
  }
  cli::cli_warn(
    c(
      surface,
      "i" = "Model judgement now runs outside the package: write a review packet with {.fn write_semantic_review_packet}, have your harness judge it, and read the answers back with {.fn ingest_semantic_assessments}.",
      "i" = "Set {.code options(metasalmon.llm_deprecation_quiet = TRUE)} to silence this warning until then."
    ),
    class = c("metasalmon_llm_deprecated", "deprecatedWarning")
  )
  invisible(TRUE)
}

# The `missing()` test each entry point runs. Written once so the five call
# sites cannot disagree about which arguments count: every name in
# `.ms_llm_arg_names()`, evaluated in the entry point's own frame because
# `missing()` only answers there.
.ms_llm_deprecation_triggered <- function(envir) {
  supplied <- vapply(.ms_llm_arg_names(), function(name) {
    !eval(call("missing", as.name(name)), envir = envir)
  }, logical(1))
  any(supplied)
}
