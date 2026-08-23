# The regex engine is the contract: TRE resolves `[[:space:]]` against Unicode,
# PCRE resolves it as ASCII-only, so the same pattern gives different answers on
# non-ASCII whitespace depending on `perl`. metasalmon's IRI validators must all
# give the SAME answer -- a package that clears SDP-extension validation and
# then fails EML export on an invisible character is the defect these tests pin
# (backlog #85).
#
# Characters are built with `intToUtf8()` on purpose. A literal U+3000 in this
# file would be invisible in review and in a diff, which is the whole problem.

ws_cases <- list(
  ascii_space = 0x0020L, # SPACE
  ascii_tab = 0x0009L, # CHARACTER TABULATION
  nbsp = 0x00A0L, # NO-BREAK SPACE
  figure_space = 0x2007L, # FIGURE SPACE
  ideographic_space = 0x3000L # IDEOGRAPHIC SPACE
)

iri_with <- function(codepoint) {
  paste0("http://example.org/a", intToUtf8(codepoint), "b")
}

# Expected answers under TRE, this package's chosen engine. U+00A0 and U+2007
# are NOT members of TRE's `[[:space:]]`, so they are accepted by both engines
# and are the control cases; U+3000 IS a member, and is exactly where PCRE used
# to disagree. If a future R/TRE release changes a membership, this table is the
# thing that fails, which is the intended signal -- re-enumerate rather than
# relax it, and see `knowledge/parity-deviations.md` row 28 for the Python side.
ws_expected <- c(
  ascii_space = FALSE,
  ascii_tab = FALSE,
  nbsp = TRUE,
  figure_space = TRUE,
  ideographic_space = FALSE
)

test_that("the SDP-extension IRI validator rejects Unicode whitespace", {
  for (case in names(ws_cases)) {
    expect_identical(
      .ms_sdp_extension_is_absolute_iri(iri_with(ws_cases[[case]])),
      ws_expected[[case]],
      info = case
    )
  }
  # Sanity anchors: a clean IRI passes, so a wholesale FALSE cannot pass above.
  expect_true(.ms_sdp_extension_is_absolute_iri("http://example.org/a-b"))
  expect_false(.ms_sdp_extension_is_absolute_iri("REVIEW:needs-a-term"))
})

test_that("the shared shape predicate is the one the other validators use", {
  for (case in names(ws_cases)) {
    expect_identical(
      .ms_absolute_iri_shape(iri_with(ws_cases[[case]])),
      ws_expected[[case]],
      info = case
    )
    expect_identical(
      .ms_sssom_is_absolute_uri(iri_with(ws_cases[[case]])),
      ws_expected[[case]],
      info = case
    )
  }
})

test_that("EML export and SDP-extension validation agree on Unicode whitespace", {
  # Drives the real EML validator rather than re-asserting the shared predicate,
  # so this still fails if only one call site is changed back.
  root <- withr::local_tempdir()
  object_path <- file.path(root, "supplement.csv")
  writeLines("a,b\n1,2", object_path)
  checksum <- digest::digest(file = object_path, algo = "sha256", serialize = FALSE)

  eml_accepts <- function(pid) {
    objects <- data.frame(
      path = object_path,
      pid = pid,
      format_id = "text/csv",
      checksum = checksum,
      object_name = "supplement.csv",
      entity_name = "Supplement",
      description = "A supplementary object.",
      stringsAsFactors = FALSE
    )
    # Any abort counts as a reject: an ASCII tab trips the `[[:cntrl:]]` check
    # before the pid check, and both are the same answer for our purposes.
    !inherits(
      try(
        .ms_eml_supplementary_objects(objects, .ms_knb_config("production")),
        silent = TRUE
      ),
      "try-error"
    )
  }

  expect_true(eml_accepts("http://example.org/a-b"))

  for (case in names(ws_cases)) {
    iri <- iri_with(ws_cases[[case]])
    expect_identical(
      eml_accepts(iri),
      .ms_sdp_extension_is_absolute_iri(iri),
      info = case
    )
    expect_identical(eml_accepts(iri), ws_expected[[case]], info = case)
  }
})

test_that("the shared IRI predicate is not compiled under PCRE", {
  # A drift guard, not a proof: `perl = TRUE` here is a silent behaviour widening
  # -- it makes `[[:space:]]` ASCII-only and re-admits the IRIs above -- and it
  # is the kind of thing added back as a performance "optimization". It also
  # invalidates metasalmonpy's enumerated `R_SPACE_CLASS`. Retire this guard only
  # if the predicate stops resolving a POSIX character class.
  body_text <- paste(
    deparse(body(get(".ms_absolute_iri_shape", envir = asNamespace("metasalmon")))),
    collapse = " "
  )
  expect_true(grepl("[:space:]", body_text, fixed = TRUE))
  expect_false(grepl("perl", body_text, fixed = TRUE))
})
