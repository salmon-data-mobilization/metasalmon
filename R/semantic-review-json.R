# Canonical JSON for the semantic review packet (S16 step 1, hub item B-326).
#
# The packet is a byte contract shared with metasalmonpy: the same inputs must
# give the same bytes in both languages, on every platform and locale, because
# `packet_id` is the SHA-256 of those bytes and is checked at ingest. The
# default JSON writers disagree about arrays, `0.3` and `2` (jsonlite's
# `digits = NA` rendered `0.1 + 0.2` as `0.3` in a probe, which does not round
# trip), so this file is a small hand-written emitter with one rule per type.
#
# The rendering is exactly what Python's
# `json.dumps(obj, indent = 2, ensure_ascii = False)` produces, with one
# stated difference for numbers, so the metasalmonpy side is the standard
# library plus a float formatter:
#
#   * UTF-8, no BOM, two-space indent, one member per line, `": "` between a
#     key and its value, `","` at the end of every member but the last, and a
#     single trailing LF after the closing bracket.
#   * Empty containers render inline: `[]` and `{}`.
#   * Only `"`, `\` and U+0000-U+001F are escaped: `\"`, `\\`, `\b`, `\f`,
#     `\n`, `\r`, `\t`, and `\u00XX` (lower-case hex) for every other control
#     character. Everything else, including non-ASCII, is written as itself.
#   * `true`, `false` and `null`; an NA of any type is `null`.
#   * NUMBERS ARE RENDERED BY VALUE, NOT BY TYPE: a finite whole number is an
#     integer literal (`2`, never `2.0`), and every other finite number goes
#     through the shared number-token formatter `.ms_format_number_token()`,
#     the shortest decimal that round-trips, never in scientific notation
#     (parity rows 36 and 59 record the two formatters as agreeing). NaN and
#     Inf are `null`.
#   * Key order is the order the builder gave. The emitter never sorts, so
#     the builder owns every ordering; `extra` members are C-sorted there.
#
# One value, one rendering: a value reaches these bytes through exactly one
# branch below, and the identity hash is computed over the same bytes that
# are written, never over a second rendering.
#
# The R representation the emitter reads:
#   * a named list is an object (an empty object is `.ms_json_object()`, a
#     named empty list, which is also what jsonlite returns for `{}`);
#   * an unnamed list is an array (`.ms_json_array(x)` wraps a vector);
#   * an atomic vector of length one is a scalar;
#   * `NULL` is null;
#   * an atomic vector of any other length is an error, because a length-one
#     array and a scalar would otherwise be indistinguishable.

.ms_json_object <- function(...) {
  out <- list(...)
  if (length(out) == 0L) {
    return(structure(list(), names = character()))
  }
  if (is.null(names(out)) || any(!nzchar(names(out)))) {
    cli::cli_abort("Every member of a JSON object needs a name.")
  }
  out
}

.ms_json_array <- function(x = NULL) {
  if (is.null(x)) {
    return(list())
  }
  if (is.list(x)) {
    return(unname(x))
  }
  lapply(seq_along(x), function(i) x[[i]])
}

.ms_json_is_object <- function(x) {
  is.list(x) && !is.null(names(x))
}

.ms_json_escape_string <- function(x) {
  x <- enc2utf8(as.character(x))
  x <- gsub("\\", "\\\\", x, fixed = TRUE)
  x <- gsub("\"", "\\\"", x, fixed = TRUE)
  x <- gsub("\n", "\\n", x, fixed = TRUE)
  x <- gsub("\r", "\\r", x, fixed = TRUE)
  x <- gsub("\t", "\\t", x, fixed = TRUE)
  x <- gsub("\b", "\\b", x, fixed = TRUE)
  x <- gsub("\f", "\\f", x, fixed = TRUE)
  # Every other control character, as \u00XX. Done last so the escapes
  # written above are not themselves re-escaped.
  if (grepl("[\\x01-\\x1f]", x, perl = TRUE, useBytes = TRUE)) {
    chars <- strsplit(x, "", useBytes = FALSE)[[1]]
    codes <- utf8ToInt(x)
    control <- codes >= 1L & codes <= 31L & !codes %in% c(8L, 9L, 10L, 12L, 13L)
    chars[control] <- sprintf("\\u%04x", codes[control])
    x <- paste(chars, collapse = "")
  }
  paste0("\"", x, "\"")
}

.ms_json_render_number <- function(x) {
  if (is.na(x) || !is.finite(x)) {
    return("null")
  }
  if (x == trunc(x) && abs(x) < 2^53) {
    # `sprintf("%.0f")` writes every digit of a whole number below 2^53
    # exactly; `format()` would round past 15 significant digits. A negative
    # zero is written as `0`.
    return(if (x == 0) "0" else sprintf("%.0f", x))
  }
  .ms_format_number_token(x)
}

.ms_json_render_scalar <- function(x) {
  if (is.null(x)) {
    return("null")
  }
  if (length(x) != 1L) {
    cli::cli_abort(c(
      "A JSON scalar must have length one; got length {length(x)}.",
      "i" = "Wrap a vector with {.fn .ms_json_array} to render it as an array."
    ))
  }
  if (is.na(x) && !is.nan(x)) {
    return("null")
  }
  if (is.logical(x)) {
    return(if (isTRUE(x)) "true" else "false")
  }
  if (is.numeric(x)) {
    return(.ms_json_render_number(as.numeric(x)))
  }
  if (is.character(x) || is.factor(x)) {
    return(.ms_json_escape_string(as.character(x)))
  }
  cli::cli_abort("Cannot render a value of class {.cls {class(x)}} as JSON.")
}

.ms_json_render <- function(x, indent = 0L) {
  pad <- strrep("  ", indent)
  inner <- strrep("  ", indent + 1L)
  if (is.null(x)) {
    return("null")
  }
  if (is.list(x)) {
    if (length(x) == 0L) {
      return(if (.ms_json_is_object(x)) "{}" else "[]")
    }
    if (.ms_json_is_object(x)) {
      keys <- names(x)
      if (any(is.na(keys) | !nzchar(keys))) {
        cli::cli_abort("Every member of a JSON object needs a name.")
      }
      members <- vapply(seq_along(x), function(i) {
        paste0(inner, .ms_json_escape_string(keys[[i]]), ": ", .ms_json_render(x[[i]], indent + 1L))
      }, character(1))
      return(paste0("{\n", paste(members, collapse = ",\n"), "\n", pad, "}"))
    }
    members <- vapply(x, function(item) {
      paste0(inner, .ms_json_render(item, indent + 1L))
    }, character(1))
    return(paste0("[\n", paste(members, collapse = ",\n"), "\n", pad, "]"))
  }
  .ms_json_render_scalar(x)
}

# The canonical bytes of a packet, or of any value built under the rules
# above: the rendering plus one trailing LF, as UTF-8. Named with "canonical"
# so the collation guard's pattern finds it; it is registered in
# `collation_sensitive_fns` because the bytes it produces are hashed.
.ms_semantic_review_canonical_bytes <- function(x) {
  charToRaw(enc2utf8(paste0(.ms_json_render(x, indent = 0L), "\n")))
}

.ms_semantic_review_sha256 <- function(bytes) {
  digest::digest(bytes, algo = "sha256", serialize = FALSE)
}

# `packet_id` is the SHA-256 of the canonical serialisation with the
# `packet_id` and `producer` members removed, so the same packet built by
# metasalmon and metasalmonpy has the same id and the id is an integrity check
# at ingest: the ingester recomputes it from the bytes it read.
.ms_semantic_review_packet_id <- function(packet) {
  stripped <- packet[setdiff(names(packet), c("packet_id", "producer"))]
  .ms_semantic_review_sha256(.ms_semantic_review_canonical_bytes(stripped))
}

# Read a packet from disk into the representation the emitter reads back:
# objects as named lists, arrays as unnamed lists, scalars as length-one
# vectors, null as NULL. `simplifyVector = FALSE` is what keeps a one-element
# array an array.
.ms_semantic_review_read_json <- function(path) {
  text <- .ms_read_text_utf8(path)
  jsonlite::fromJSON(text, simplifyVector = FALSE)
}
