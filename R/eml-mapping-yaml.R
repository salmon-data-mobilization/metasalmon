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
  # Literal bangs need one disposable parse plus the untouched real read.
  # Directive groups additionally need one native segment proof per document
  # boundary. Each document/prelude is visited at most twice in those proofs,
  # rather than reparsing the full sidecar per candidate. No size/count limit.
  # Both probes retire when yaml exposes original tags or native tag refusal.
  suppressWarnings(tryCatch({
    yaml::yaml.load(paste(lines, collapse = "\n"), eval.expr = FALSE)
    FALSE
  }, error = function(e) {
    grepl("found undefined tag handle", conditionMessage(e), fixed = TRUE)
  }))
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
