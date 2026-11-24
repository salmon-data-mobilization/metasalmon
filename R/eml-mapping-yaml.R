# One owner for the reviewed EML sidecar's unknown-tag refusal (Q62). The
# closure uses it now; B-223 can reuse it for EML/KNB without a second detector.
# Known YAML core tags remain valid, as in metasalmonpy's SafeLoader.
.ms_eml_mapping_native_directive_start <- function(lines, candidates) {
  # A tag handle is not a YAML version: changing only the directive keyword
  # makes a genuine definition fail natively, while preserving every quote,
  # escape and comment character around a literal lookalike. The native source
  # line identifies the first genuine definition, excluding quoted lookalikes
  # earlier in the same group. No quote-state parser is needed.
  probe <- lines
  probe[candidates] <- sub("^%TAG", "%YAML", probe[candidates])
  suppressWarnings(tryCatch({
    yaml::yaml.load(paste(probe, collapse = "\n"), eval.expr = FALSE)
    NA_integer_
  }, error = function(e) {
    match <- regexec(
      "while scanning a %YAML directive at line ([0-9]+), column ",
      conditionMessage(e)
    )
    parts <- regmatches(conditionMessage(e), match)[[1L]]
    if (length(parts) < 2L) {
      return(NA_integer_)
    }
    line <- as.integer(parts[[2L]])
    if (line %in% candidates) line else NA_integer_
  }))
}

.ms_eml_mapping_has_unknown_tag <- function(text) {
  if (!grepl("!", text, fixed = TRUE)) {
    return(FALSE)
  }
  standard_uris <- paste0("tag:yaml.org,2002:", c(
    "null", "bool", "int", "float", "binary", "timestamp", "omap", "pairs",
    "set", "str", "seq", "map"
  ))
  lines <- strsplit(text, "\n", fixed = TRUE)[[1]]
  source_lines <- lines
  document_start <- 1L
  handles <- c("!!" = "tag:yaml.org,2002:")
  handle_names <- names(handles)
  pending_directives <- integer()
  # An undefined handle is a native node-resolution signal, before a tagged
  # collection is constructed. A source directive must not define our probe.
  private_handle <- "!metasalmon-eml-probe!"
  while (grepl(private_handle, text, fixed = TRUE)) {
    private_handle <- sub("!$", "-!", private_handle)
  }
  resolve <- function(token) {
    if (startsWith(token, "!<") && endsWith(token, ">")) {
      return(substr(token, 3L, nchar(token) - 1L))
    }
    for (handle in handle_names) {
      if (startsWith(token, handle)) {
        return(paste0(handles[[handle]],
                      substring(token, nchar(handle) + 1L)))
      }
    }
    sub("^!+", "", token)
  }
  # Verbatim candidates cannot span whitespace or either quote boundary. A
  # quoted "!<text" must not swallow a later real !foo through a comment '>'.
  # The fallback discovers a leading bang even in an unusual URI; the original
  # token stays intact, so libyaml still establishes its syntax and node status.
  tag_token <- "!<[^[:space:]'\"<>]*>|!+[^[:space:]\\[\\]{},\"\\\\]+|!"
  changed <- FALSE
  for (line_index in seq_along(lines)) {
    line <- lines[[line_index]]
    if (grepl("^%TAG[[:space:]]", line)) {
      pending_directives <- c(pending_directives, line_index)
      # Directives may follow an implicit document end. Keep this line intact
      # in the native probe; a following `---` supplies a bounded segment in
      # which libyaml can establish which definitions are actually directives.
      next
    }
    if (grepl("^---(?:[ \t]|$)", line, perl = TRUE)) {
      handles <- c("!!" = "tag:yaml.org,2002:")
      next_document_start <- line_index
      if (length(pending_directives)) {
        first <- .ms_eml_mapping_native_directive_start(
          source_lines[seq.int(document_start, line_index - 1L)],
          pending_directives - document_start + 1L
        )
        if (!is.na(first)) {
          first <- document_start + first - 1L
          for (directive_index in pending_directives[pending_directives >= first]) {
            parts <- strsplit(trimws(source_lines[[directive_index]]),
                              "[[:space:]]+")[[1L]]
            if (length(parts) >= 3L) handles[parts[[2L]]] <- parts[[3L]]
          }
          # Include this prelude when proving the next boundary: its handles
          # are needed to parse the intervening document's original nodes.
          next_document_start <- first
        }
      }
      document_start <- next_document_start
      pending_directives <- integer()
    } else if (grepl("^\\.\\.\\.(?:[ \t]|$)", line, perl = TRUE)) {
      handles <- c("!!" = "tag:yaml.org,2002:")
      document_start <- line_index + 1L
      pending_directives <- integer()
    } else if (!grepl("^[ \t]*(?:#|$)|^%YAML[[:space:]]", line, perl = TRUE)) {
      # A %TAG-looking line followed by ordinary content was not a prelude.
      # Native parsing remains responsible for malformed directive placement.
      pending_directives <- integer()
    }
    handle_names <- names(handles)[order(-nchar(names(handles)), method = "radix")]
    positions <- gregexpr(tag_token, line, perl = TRUE)[[1]]
    lengths <- attr(positions, "match.length")
    # Prefix-only right-to-left insertion preserves every original character
    # and match position, including quotes, escapes and collection delimiters.
    for (match_index in rev(which(positions > 0L))) {
      position <- positions[[match_index]]
      token <- substr(line, position, position + lengths[[match_index]] - 1L)
      # Decoding identifies known core URIs only. Malformed escapes must reach
      # libyaml's existing scanner/fallback, rather than a utils warning/error.
      # This narrow decoder suppression retires with the disposable tag probe.
      known <- tryCatch(suppressWarnings(
        utils::URLdecode(resolve(token)) %in% standard_uris
      ), error = function(e) FALSE)
      if (identical(token, "!") || known) {
        next
      }
      line <- paste0(
        if (position == 1L) "" else substr(line, 1L, position - 1L),
        private_handle, "unknown ", substring(line, position)
      )
      changed <- TRUE
    }
    lines[[line_index]] <- line
  }
  if (!changed) {
    return(FALSE)
  }
  # libyaml validates the original token before resolving the added property:
  # invalid URI escapes still give their ordinary scanner error. A real unknown
  # tag then reaches the undefined private handle before value construction,
  # while quoted/plain/comment/block literal text remains literal. Syntax
  # errors before an unreached tag retain the existing malformed-input fallback.
  # The diagnostic is native, without user error.label or custom handler errors.
  # Literal bangs normally need one disposable parse plus the untouched read.
  # Directive groups additionally need one native segment proof per document
  # boundary. Each document/prelude is visited at most twice in those proofs,
  # rather than reparsing the full sidecar per candidate. No size/count limit.
  # Both probes, including the overflow retry below, retire when yaml exposes
  # original tags or native tag refusal.
  parse_probe <- function(probe_lines) {
    suppressWarnings(tryCatch(
      yaml::yaml.load(paste(probe_lines, collapse = "\n"), eval.expr = FALSE),
      error = identity
    ))
  }
  required_key <- function(error) {
    if (!inherits(error, "error") ||
        !grepl("could not find expected ':'", conditionMessage(error), fixed = TRUE)) {
      return(NULL)
    }
    match <- regexec(
      paste0("while scanning a simple key at line ([0-9]+), column ([0-9]+)",
             " could not find expected ':' at line ([0-9]+), column ([0-9]+)"),
      conditionMessage(error)
    )
    parts <- regmatches(conditionMessage(error), match)[[1L]]
    if (length(parts) == 5L) as.integer(parts[2:5]) else NULL
  }
  original_checked <- FALSE
  original_key <- NULL
  source_line <- seq_along(lines)
  repeat {
    probe <- parse_probe(lines)
    if (!inherits(probe, "error")) return(FALSE)
    if (grepl("found undefined tag handle", conditionMessage(probe), fixed = TRUE)) {
      return(TRUE)
    }
    key <- required_key(probe)
    if (is.null(key)) return(FALSE)
    if (!original_checked) {
      original_key <- required_key(parse_probe(source_lines))
      original_checked <- TRUE
    }
    # Never repair a required-key overflow already present before this point
    # in the untouched input: native parsing did not reach a later tag there.
    # The line map retains native source positions when a probe key is split.
    if (!is.null(original_key) && original_key[[1L]] <= source_line[[key[[1L]]]]) {
      return(FALSE)
    }
    # Only the disposable prefix overflowed. An explicit key has no implicit
    # key length bound. Use libyaml's own node position, preserving every tag,
    # quote and escape byte; do not shorten the prefix or change the real read.
    line <- lines[[key[[1L]]]]
    column <- key[[2L]]
    separator <- key[[4L]]
    if (key[[3L]] != key[[1L]]) {
      return(FALSE)
    }
    if (substr(line, separator, separator) != ":") {
      # A collection can exceed the implicit-key bound before the scanner
      # reaches its separator. Native key-start coordinates still identify
      # the node: making only that disposable node explicit reaches a real
      # tag, or reports the value separator for a literal collection key.
      explicit_probe <- lines
      explicit_probe[[key[[1L]]]] <- paste0(
        if (column == 1L) "" else substr(line, 1L, column - 1L),
        "? ", substring(line, column)
      )
      explicit_result <- parse_probe(explicit_probe)
      if (!inherits(explicit_result, "error")) return(FALSE)
      if (grepl("found undefined tag handle", conditionMessage(explicit_result),
                fixed = TRUE)) return(TRUE)
      match <- regexec(
        "mapping values are not allowed in this context at line ([0-9]+), column ([0-9]+)",
        conditionMessage(explicit_result)
      )
      parts <- regmatches(conditionMessage(explicit_result), match)[[1L]]
      if (length(parts) != 3L || as.integer(parts[[2L]]) != key[[1L]]) {
        return(FALSE)
      }
      # Account only for the two inserted characters. The native diagnostic,
      # not a collection/quote scanner, chooses this separator in the probe.
      separator <- as.integer(parts[[3L]]) - 2L
      if (substr(line, separator, separator) != ":") return(FALSE)
    }
    # Keep the value separator on its own line too: `? key: value` can still
    # construct an implicit mapping inside the explicit key. libyaml reports
    # this separator's position; no quote/colon scanner chooses it for us.
    explicit <- c(paste0(
      if (column == 1L) "" else substr(line, 1L, column - 1L),
      "? ", substr(line, column, separator - 1L)
    ), paste0(strrep(" ", column - 1L), substring(line, separator)))
    position <- key[[1L]]
    lines <- append(lines[-position], explicit, after = position - 1L)
    source_line <- append(source_line[-position], rep(source_line[[position]], 2L),
                          after = position - 1L)
    # A long literal key may precede a real tag, so let native parsing reach
    # the next node rather than treating this overflow itself as tag evidence.
  }
}

.ms_eml_read_mapping_yaml <- function(mapping_file) {
  text <- paste(readLines(mapping_file, encoding = "UTF-8"), collapse = "\n")
  # Unknown-tag refusal precedes an ordinary malformed-YAML fallback, so a
  # reached tagged node cannot hide behind a later parse error. Untagged
  # malformed input still reaches the real parser's existing error below.
  if (.ms_eml_mapping_has_unknown_tag(text)) {
    cli::cli_abort(c(
      "EML mapping sidecar contains an unsupported YAML tag.",
      .ms_cli_bullets(mapping_file)
    ), class = "metasalmon_eml_mapping_tag")
  }
  # No option can enable expression evaluation on the original text.
  yaml::yaml.load(text, error.label = mapping_file, eval.expr = FALSE)
}
