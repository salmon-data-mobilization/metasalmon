# The regex engine and explicit Unicode members are the contract: TRE resolves
# `[[:space:]]` against Unicode in a UTF-8 locale but against ASCII under C;
# PCRE resolves it as ASCII-only. The shared predicate adds TRE's non-ASCII
# UTF-8-locale members explicitly so metasalmon's absolute-IRI validators give
# the same answer under either locale (backlog #85, hub B-137).
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

# Expected answers for the locale-stable shared predicate. U+00A0 and U+2007
# are not in its whitespace class, so they are accepted controls; U+3000 is in
# the explicitly enumerated part. If its membership changes, re-enumerate
# rather than relax the table; see parity-deviations row 28 for Python's class.
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

test_that("the shared IRI predicate rejects Unicode whitespace in the C locale", {
  # The package can run in a container with LC_CTYPE=C. TRE's POSIX space
  # class alone admits these codepoints there, even though it rejects them in
  # UTF-8 locales. These are the non-ASCII members of metasalmonpy's
  # R_SPACE_CLASS, which records the package's UTF-8-locale verdicts.
  withr::local_locale(c(LC_CTYPE = "C"))
  unicode_spaces <- c(
    0x1680L, 0x2000L:0x2006L, 0x2008L:0x200AL,
    0x2028L, 0x2029L, 0x205FL, 0x3000L
  )
  iris <- vapply(unicode_spaces, iri_with, character(1))

  expect_identical(.ms_absolute_iri_shape(iris), rep(FALSE, length(iris)))
  expect_true(.ms_absolute_iri_shape(iri_with(0x2007L)))
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
  # A drift guard, not a proof: `perl = TRUE` changes the POSIX component to
  # PCRE's ASCII class. The explicit members protect the points pinned above,
  # but a different engine still needs a full membership and Python parity
  # check. Retire this guard only if the predicate stops resolving a POSIX
  # class and both language implementations are checked.
  ns <- asNamespace("metasalmon")
  expect_true(grepl("[:space:]", ns$.ms_iri_space_class, fixed = TRUE))
  # Hub B-432: the direct SSSOM reference parser read its own `[[:space:]]`
  # and so resolved it against the locale. Every whitespace test on an IRI or a
  # CURIE builds its class from `.ms_iri_space_class`; list a new one here.
  for (fn in c(
    ".ms_absolute_iri_shape",
    ".ms_sssom_is_unambiguous_uri",
    ".ms_sssom_validate_reference"
  )) {
    body_text <- paste(deparse(body(get(fn, envir = ns))), collapse = " ")
    expect_true(grepl(".ms_iri_space_class", body_text, fixed = TRUE), info = fn)
    expect_false(grepl("[[:space:]]", body_text, fixed = TRUE), info = fn)
    expect_false(grepl("perl", body_text, fixed = TRUE), info = fn)
  }
})
