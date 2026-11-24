# Q62/B-340: use libyaml node properties, never an expression evaluator or a
# lexical bang-only refusal. This owner is available for B-223's later readers.
test_that("EML sidecar reader refuses unknown tags wherever they occur", {
  declarations <- c(
    "x: !foo value", "x: !str value", "x: !e!foo value", "!foo {x: value}",
    "x: !foo [one, two]", "x: [&a !foo value]", "x: {? !foo key: value}",
    "x: [a'b, !foo value, c'd]", "x: !foo' value",
    'x: "!<literal"\ny: !foo value',
    "x: !<tag:example.org,2026:unknown> value",
    "%TAG !e! tag:example.org,2026:\n---\nx: !e!unknown value"
  )
  for (text in declarations) {
    sidecar <- file.path(withr::local_tempdir(), "eml-mapping.yml")
    writeLines(text, sidecar)
    expect_error(.ms_eml_read_mapping_yaml(sidecar), "unsupported YAML tag")
    expect_error(.ms_eml_read_mapping_yaml(sidecar), "eml-mapping.yml", fixed = TRUE)
  }
})

test_that("EML sidecar reader preserves known standard tags and literal bangs", {
  declarations <- c(
    "x: !!str value", "x: !!int 42", "x: !!seq [one, two]",
    "x: !!map {key: value}", "x: !<tag:yaml.org,2002:str> value",
    "%TAG !e! tag:yaml.org,2002:\n---\nx: !e!str value",
    "%TAG ! tag:yaml.org,2002:\n---\nx: !str value",
    "x: !!s%74r value", "x: ! value",
    'x: "!foo value"', "x: '!foo value'", "x: plain!foo", "x: Good !foo value",
    "x: [a'b] # [!foo value] 'ignored", "x: [a'b, literal, c'd]",
    "x: |\n  !foo literal", "x: [Good ? !foo]"
  )
  for (text in declarations) {
    sidecar <- file.path(withr::local_tempdir(), "eml-mapping.yml")
    writeLines(text, sidecar)
    expected <- yaml::yaml.load(text, eval.expr = FALSE)
    expect_identical(.ms_eml_read_mapping_yaml(sidecar), expected)
  }
})

test_that("closure retains malformed and nonmapping sidecar fallback", {
  defaults <- list(vocabulary = "metadata/semantic_vocabulary.csv",
                   review = "reviewed_semantic_selections.csv")
  for (text in c("x: [unterminated", "a scalar", "null")) {
    sidecar <- file.path(withr::local_tempdir(), "eml-mapping.yml")
    writeLines(text, sidecar)
    expect_identical(.ms_closure_mapping_paths(sidecar), defaults)
  }
  expect_identical(.ms_closure_mapping_paths(NULL), defaults)
})

test_that("literal builtin-like tags do not trigger per-bang document parses", {
  literal_forms <- c(
    paste0("notes: Good ", paste(rep("!str", 80L), collapse = " ")),
    paste0("notes: [", paste(rep("'!str'", 80L), collapse = ", "), "]"),
    paste0('notes: "first\n  ', paste(rep("!str", 80L), collapse = "\n  "), '\n  last"'),
    paste0("notes: |\n  ", paste(rep("!str", 80L), collapse = "\n  "))
  )
  real_load <- yaml::yaml.load
  calls <- 0L
  testthat::local_mocked_bindings(
    yaml.load = function(...) {
      calls <<- calls + 1L
      real_load(...)
    }, .package = "yaml"
  )
  for (literal in literal_forms) {
    sidecar <- file.path(withr::local_tempdir(), "eml-mapping.yml")
    text <- paste0('description: "', strrep("ordinary text ", 80000L), '"\n', literal)
    writeLines(text, sidecar)
    calls <- 0L
    expect_type(.ms_eml_read_mapping_yaml(sidecar), "list")
    expect_lte(calls, 2L)
  }
})

test_that("a literal bang before a real unknown tag cannot hide it", {
  for (text in c("x: ['!', !foo value]", "x: ['!str', !foo value]",
                 "%TAG !e! !\n---\nx: !e!str value", "x: !f%6Fo value")) {
    sidecar <- file.path(withr::local_tempdir(), "eml-mapping.yml")
    writeLines(text, sidecar)
    expect_error(.ms_eml_read_mapping_yaml(sidecar), "unsupported YAML tag")
  }
})

test_that("unknown tags in later YAML documents cannot hide behind the first", {
  for (text in c(
    "semantic_vocabulary:\n  path: metadata/declared.csv\n---\nx: !foo value",
    "x: value\n...\n---\nx: !expr value",
    "%TAG !e! tag:yaml.org,2002:\n---\nx: !e!str value\n...\n%TAG !e! tag:example.org,2026:\n---\nx: !e!unknown value"
  )) {
    sidecar <- file.path(withr::local_tempdir(), "eml-mapping.yml")
    writeLines(text, sidecar)
    expect_error(.ms_closure_mapping_paths(sidecar), "unsupported YAML tag")
  }
  sidecar <- file.path(withr::local_tempdir(), "eml-mapping.yml")
  writeLines("semantic_vocabulary:\n  path: metadata/declared.csv\n---\nx: value", sidecar)
  # R's existing read returns the first document. Do not change that separate
  # baseline here; only the unknown-tag refusal covers the full sidecar.
  expect_identical(.ms_closure_mapping_paths(sidecar)$vocabulary, "metadata/declared.csv")
})

test_that("directives after an implicit document end preserve tag classification", {
  prefix <- "semantic_vocabulary:\n  path: metadata/declared.csv\n"
  sidecar <- file.path(withr::local_tempdir(), "eml-mapping.yml")
  unknown <- paste0(prefix, "%TAG !e! tag:example.org,2026:\n---\nx: !e!foo value")
  # The original parse is valid: a directive can end the previous document
  # implicitly. Refusal must come from the reached tag, not a syntax fallback.
  expect_type(suppressWarnings(yaml::yaml.load(unknown, eval.expr = FALSE)), "list")
  writeLines(unknown, sidecar)
  expect_error(.ms_closure_mapping_paths(sidecar), "unsupported YAML tag")

  standard <- paste0(prefix, "%TAG !e! tag:yaml.org,2002:\n---\nx: !e!str value")
  writeLines(standard, sidecar)
  expect_identical(.ms_eml_read_mapping_yaml(sidecar),
                   yaml::yaml.load(standard, eval.expr = FALSE))
  expect_identical(.ms_closure_mapping_paths(sidecar)$vocabulary, "metadata/declared.csv")
})

test_that("quoted directive groups cannot become bindings at a later document", {
  unknown <- c(
    'description: "first\n%TAG ! tag:yaml.org,2002:\n# last"\n---\nx: !str value',
    paste0('description: "first\n%TAG ! tag:yaml.org,2002:\n# last"\n',
           '%TAG !e! tag:yaml.org,2002:\n%TAG !f! tag:yaml.org,2002:\n',
           '---\nx: !str value\ny: !e!str value\nz: !f!str value')
  )
  for (text in unknown) {
    sidecar <- file.path(withr::local_tempdir(), "eml-mapping.yml")
    expect_type(suppressWarnings(yaml::yaml.load(text, eval.expr = FALSE)), "list")
    writeLines(text, sidecar)
    expect_error(.ms_closure_mapping_paths(sidecar), "unsupported YAML tag")
  }
  known <- c(
    'description: "first\n%TAG !! tag:example.org,2026:\n# last"\n---\nx: !!str value',
    paste0('description: "first\n%TAG !e! tag:yaml.org,2002: # last"\n',
           '%TAG !e! tag:yaml.org,2002:\n---\nx: !e!str value'),
    paste0('%TAG !e! tag:yaml.org,2002:\n---\nx: !e!str value\n',
           '%TAG !e! tag:yaml.org,2002:\n# a comment with "\n',
           '%TAG !f! tag:yaml.org,2002:\n---\nx: !e!str value\ny: !f!str value')
  )
  for (text in known) {
    sidecar <- file.path(withr::local_tempdir(), "eml-mapping.yml")
    expected <- yaml::yaml.load(text, eval.expr = FALSE)
    writeLines(text, sidecar)
    expect_identical(.ms_eml_read_mapping_yaml(sidecar), expected)
  }
})

test_that("native directive proof visits document segments linearly", {
  document <- paste0(
    "%TAG !e! tag:yaml.org,2002:\n---\nx: !e!str value\n",
    'notes: "', strrep("ordinary text ", 500L), '"\n'
  )
  text <- paste(rep(document, 40L), collapse = "")
  real_proof <- .ms_eml_mapping_native_directive_start
  bytes <- 0
  calls <- 0L
  testthat::local_mocked_bindings(
    .ms_eml_mapping_native_directive_start = function(lines, candidates) {
      calls <<- calls + 1L
      bytes <<- bytes + sum(nchar(lines, type = "bytes")) + length(lines) - 1L
      real_proof(lines, candidates)
    }
  )
  sidecar <- file.path(withr::local_tempdir(), "eml-mapping.yml")
  writeLines(text, sidecar)
  expect_identical(.ms_eml_read_mapping_yaml(sidecar),
                   yaml::yaml.load(text, eval.expr = FALSE))
  expect_gt(calls, 0L)
  # A whole-sidecar parse at every boundary would be quadratic. Original
  # document content is visited once and its prelude can be reused once.
  # Retires with the native directive discriminator's successor tag API.
  expect_lte(bytes, 2 * nchar(text, type = "bytes"))
})

test_that("unknown-tag refusal precedes later malformed syntax", {
  for (text in c(
    "%TAG !e! tag:example.org,2026:\n---\nx: !e!str value\n...\n%TAG !e! tag:yaml.org,2002:\n---\nx: !e!str value",
    "x: !foo value\ny: [unterminated"
  )) {
    sidecar <- file.path(withr::local_tempdir(), "eml-mapping.yml")
    writeLines(text, sidecar)
    expect_error(.ms_closure_mapping_paths(sidecar), "unsupported YAML tag")
  }
})


test_that("quoted verbatim-looking text cannot swallow a real flow tag", {
  sidecar <- file.path(withr::local_tempdir(), "eml-mapping.yml")
  writeLines('x: ["!<text", !foo value # > later\n]', sidecar)
  expect_error(.ms_closure_mapping_paths(sidecar), "unsupported YAML tag")
  writeLines('x: ["!<text", "!foo value"] # > later', sidecar)
  expect_identical(.ms_eml_read_mapping_yaml(sidecar),
                   list(x = c("!<text", "!foo value")))
})

test_that("a reached unknown tag is refused before its incomplete collection", {
  for (text in c("x: !foo [unterminated", "x: !!unknown [unterminated",
                 "%TAG !e! tag:example.org,2026:\n---\nx: !e!unknown [unterminated",
                 "x: !<tag:example.org,2026:unknown> [unterminated")) {
    sidecar <- file.path(withr::local_tempdir(), "eml-mapping.yml")
    writeLines(text, sidecar)
    expect_error(.ms_closure_mapping_paths(sidecar), "unsupported YAML tag")
  }
  sidecar <- file.path(withr::local_tempdir(), "eml-mapping.yml")
  writeLines("x: [unterminated\ny: !foo value", sidecar)
  # Native parsing cannot reach the later tag after this earlier syntax error.
  # Preserve the existing malformed-input fallback, rather than lexical refusal.
  expect_identical(.ms_closure_mapping_paths(sidecar),
                   list(vocabulary = "metadata/semantic_vocabulary.csv",
                        review = "reviewed_semantic_selections.csv"))
})


test_that("directive-looking multiline literal text does not redefine tags", {
  text <- 'description: "first\n%TAG ! tag:yaml.org,2002:\nlast"\nx: !str value'
  sidecar <- file.path(withr::local_tempdir(), "eml-mapping.yml")
  writeLines(text, sidecar)
  expect_error(.ms_closure_mapping_paths(sidecar), "unsupported YAML tag")
})


test_that("native scanner errors before tag resolution retain fallback", {
  defaults <- list(vocabulary = "metadata/semantic_vocabulary.csv",
                   review = "reviewed_semantic_selections.csv")
  for (text in c("x: !<tag:%ZZ> value", "x: !<tag:bad\\bad> value")) {
    sidecar <- file.path(withr::local_tempdir(), "eml-mapping.yml")
    writeLines(text, sidecar)
    expect_identical(.ms_closure_mapping_paths(sidecar), defaults)
  }
  sidecar <- file.path(withr::local_tempdir(), "eml-mapping.yml")
  writeLines("%TAG !metasalmon-eml-probe! tag:yaml.org,2002:\n---\nx: !foo value", sidecar)
  expect_error(.ms_closure_mapping_paths(sidecar), "unsupported YAML tag")
})

test_that("long required mapping keys cannot hide an unsupported tag", {
  forms <- list(
    block = function(key) paste0("a: 1\n", key, ": 2\n"),
    flow = function(key) paste0("{a: 1, ", key, ": 2}\n")
  )
  for (form in forms) {
    for (key_length in c(10L, 1000L, 1010L)) {
      key <- strrep("k", key_length)
      unknown <- form(paste("!foo", key))
      # Reach control: these are valid authored keys, including the required
      # block key after `a`. Only the disposable prefix pushes it over the
      # native implicit-key bound; the original must still be refused.
      expect_type(suppressWarnings(yaml::yaml.load(unknown, eval.expr = FALSE)), "list")
      sidecar <- file.path(withr::local_tempdir(), "eml-mapping.yml")
      writeLines(unknown, sidecar)
      expect_error(.ms_eml_read_mapping_yaml(sidecar), "unsupported YAML tag")

      for (literal in c(paste("!!str", key),
                        paste0('"!foo ', key, '"'),
                        paste("Good !foo", key))) {
        text <- form(literal)
        expected <- yaml::yaml.load(text, eval.expr = FALSE)
        writeLines(text, sidecar)
        expect_identical(.ms_eml_read_mapping_yaml(sidecar), expected)
      }
    }
  }
})

test_that("probe overflow preserves original malformed-key fallback", {
  sidecar <- file.path(withr::local_tempdir(), "eml-mapping.yml")
  text <- paste0("a: 1\n", strrep("k", 1100L), ": 2\nnext: !foo value\n")
  # This overflow is already in the untouched input, before the later tag.
  # A disposable explicit-key probe must not make malformed source valid.
  expect_error(yaml::yaml.load(text, eval.expr = FALSE), "while scanning a simple key")
  writeLines(text, sidecar)
  expect_identical(.ms_closure_mapping_paths(sidecar),
                   list(vocabulary = "metadata/semantic_vocabulary.csv",
                        review = "reviewed_semantic_selections.csv"))

  # Literal keys can overflow only after probe insertion too. Pass those
  # literals without losing the real tag after them or repairing later syntax.
  literal <- paste0('"!foo ', strrep("k", 1000L), '"')
  text <- paste0("a: 1\n", literal, ": 2\nnext: !foo [unterminated\n")
  writeLines(text, sidecar)
  expect_error(.ms_closure_mapping_paths(sidecar), "unsupported YAML tag")
})

test_that("required flow-sequence keys retain native unknown-tag refusal", {
  sidecar <- file.path(withr::local_tempdir(), "eml-mapping.yml")
  for (key_length in c(10L, 1000L)) {
    key <- strrep("k", key_length)
    text <- paste0("a: 1\n!foo [", key, "]: 2\n")
    # Native reach control: the 1000-character collection key is valid before
    # the disposable tag prefix moves the scanner's problem mark inside it.
    expect_type(suppressWarnings(yaml::yaml.load(text, eval.expr = FALSE)), "list")
    expect_true(.ms_eml_mapping_has_unknown_tag(text))
    writeLines(text, sidecar)
    expect_error(.ms_eml_read_mapping_yaml(sidecar), "unsupported YAML tag")

    for (accepted in c(paste0("!!seq [", key, "]"),
                       paste0('["!foo ', key, '"]'))) {
      text <- paste0("a: 1\n", accepted, ": 2\n")
      expected <- yaml::yaml.load(text, eval.expr = FALSE)
      expect_false(.ms_eml_mapping_has_unknown_tag(text))
      writeLines(text, sidecar)
      expect_identical(.ms_eml_read_mapping_yaml(sidecar), expected)
    }
  }

  # A literal collection key can overflow in the disposable probe as well.
  # Passing that key must still let native parsing reach the later real tag.
  text <- paste0('a: 1\n["!foo ', strrep("k", 1000L), '"]: 2\n',
                 "next: !foo value\n")
  expect_type(suppressWarnings(yaml::yaml.load(text, eval.expr = FALSE)), "list")
  writeLines(text, sidecar)
  expect_error(.ms_eml_read_mapping_yaml(sidecar), "unsupported YAML tag")
})

test_that("original malformed sequence keys retain ordinary fallback", {
  text <- paste0("a: 1\n[", strrep("k", 1100L), "]: 2\nnext: !foo value\n")
  expect_error(yaml::yaml.load(text, eval.expr = FALSE), "while scanning a simple key")
  expect_false(.ms_eml_mapping_has_unknown_tag(text))
  sidecar <- file.path(withr::local_tempdir(), "eml-mapping.yml")
  writeLines(text, sidecar)
  expect_identical(.ms_closure_mapping_paths(sidecar),
                   list(vocabulary = "metadata/semantic_vocabulary.csv",
                        review = "reviewed_semantic_selections.csv"))
})
