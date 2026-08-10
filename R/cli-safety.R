# Message safety for text metasalmon did not author.
#
# cli treats every element of a condition message vector as a glue template,
# including named bullet elements -- the name only selects the glyph. So text
# that arrives from an LLM provider, an HTTP response, an ontology label, or a
# user's own CSV must never be passed through as a message element:
#
#   * balanced braces are evaluated as R code, so a provider error containing
#     `{Sys.getenv("OPENAI_API_KEY")}` prints the key;
#   * an unbalanced brace is a parse error, so a column literally named
#     `rate{pct` replaces the intended message with `Error: Expecting '}'`.
#
# Escaping is the mechanism rather than value interpolation, because
# `"x" = "{preview}"` collapses an N-element preview into a single
# comma-joined bullet, and so is not a drop-in for a `setNames()` bullet
# vector. Escaped text composes safely in every position.

.ms_cli_escape <- function(x) {
  x <- as.character(x)
  x[is.na(x)] <- ""
  gsub("}", "}}", gsub("{", "{{", x, fixed = TRUE), fixed = TRUE)
}

# One escaped bullet per element, preserving the per-element layout that
# `setNames(x, rep("x", length(x)))` produces.
.ms_cli_bullets <- function(x, name = "x") {
  x <- .ms_cli_escape(x)
  if (length(x) == 0L) {
    return(character())
  }
  stats::setNames(x, rep(name, length(x)))
}

# Best-effort redaction of credentials that services echo back in error bodies.
# Deliberately conservative: over-eager patterns applied to validation messages
# would hide the very value a user needs in order to fix their metadata.
#
# Apply this where external text is CAPTURED, not where it is displayed. Text
# stored in a returned tibble or written to a CSV outlives the message.
.ms_redact_secrets <- function(value) {
  value <- as.character(value)
  if (length(value) == 0L) {
    return(value)
  }

  value <- gsub("(?i)Bearer[[:space:]]+[A-Za-z0-9._~-]+", "Bearer [REDACTED]", value, perl = TRUE)
  value <- gsub("eyJ[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+", "[REDACTED JWT]", value, perl = TRUE)
  value <- gsub("(?i)(dataone_token|authorization|cookie)[=:][^[:space:]]+", "\\1=[REDACTED]", value, perl = TRUE)
  value <- gsub("sk-[A-Za-z0-9_-]{20,}", "[REDACTED KEY]", value, perl = TRUE)
  value <- gsub(
    "(?i)(x-api-key|api[_-]?key|anthropic[_-]?api[_-]?key)[[:space:]]*[=:][[:space:]]*[^[:space:]]+",
    "\\1=[REDACTED]",
    value,
    perl = TRUE
  )
  value <- gsub("AIza[0-9A-Za-z_-]{35}", "[REDACTED KEY]", value, perl = TRUE)
  value
}

# Abort with a message that is entirely external text. Uses rlang::abort rather
# than cli so the text is never a template; use this only when cli's bullet and
# markup layer would add nothing.
.ms_abort_external <- function(prefix, text, call = NULL) {
  rlang::abort(paste0(prefix, .ms_redact_secrets(text)), call = call)
}
