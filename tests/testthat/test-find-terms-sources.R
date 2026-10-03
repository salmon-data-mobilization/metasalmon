# Which sources find_terms() searches, and how it reads the names it is given.
#
# Two rules metasalmonpy already had and this package now shares, each
# demonstrated failing before the change:
#
#   * hub B-420 (Q70, ruled by Brett on 2026-09-26: "R moves"). A call that
#     names a role and no sources searches that role's sources_for_role() list,
#     as metasalmonpy's find_terms() does. It used to search the four sources the
#     argument defaulted to, whatever the role, so a direct unit search never
#     reached QUDT.
#   * hub B-421. A named source list is normalised the way metasalmonpy's
#     `_normalize_explicit_sources()` normalises it: each name trimmed and
#     lower-cased, a missing or empty name dropped, a repeat dropped after its
#     first appearance. A capitalised name used to be searched as nothing here,
#     and reported as a successful search that found nothing.

# Every retrieval source find_terms() dispatches on.
ft_all_sources <- c("smn", "gcdfo", "ols", "nvs", "zooma", "bioportal", "qudt", "gbif", "worms")

# Calls find_terms() with every `.search_*()` stubbed, and returns the sources
# the call searched (in the order it searched them) and the sources its
# diagnostics report. Each stub returns no rows, so nothing short-circuits, and
# the search runs serially so that every stub's record comes back to this
# process (a forked worker's would not).
ft_searched <- function(...) {
  withr::local_envvar(c(METASALMON_TERM_SEARCH_PARALLEL = "0", METASALMON_CACHE = ""))
  searched <- character()
  make_stub <- function(src) {
    force(src)
    function(query, role) {
      searched <<- c(searched, src)
      .empty_terms(role)
    }
  }
  stubs <- stats::setNames(lapply(ft_all_sources, make_stub), paste0(".search_", ft_all_sources))
  do.call(testthat::local_mocked_bindings, c(stubs, list(.env = environment())))
  result <- find_terms("spawner count", ..., expand_query = FALSE)
  diagnostics <- attr(result, "diagnostics")
  list(
    searched = searched,
    diagnostics = if (is.null(diagnostics) || nrow(diagnostics) == 0L) character() else diagnostics$source
  )
}

test_that("a role with no sources searches that role's sources (hub B-420)", {
  roles <- c("variable", "property", "entity", "unit", "constraint", "statistical_modifier", "method")
  for (role in roles) {
    got <- ft_searched(role = role)
    expect_setequal(got$searched, sources_for_role(role))
    expect_setequal(got$diagnostics, sources_for_role(role))
    expect_identical(anyDuplicated(got$searched), 0L)
  }

  # The case the old default hid: a direct unit search reaches QUDT.
  expect_true("qudt" %in% ft_searched(role = "unit")$searched)

  # An explicit NULL is an omitted argument, as metasalmonpy's None is.
  expect_setequal(ft_searched(role = "unit", sources = NULL)$searched, sources_for_role("unit"))
})

test_that("a call with no role searches what it always searched (hub B-420)", {
  four <- c("smn", "gcdfo", "ols", "nvs")
  expect_identical(ft_searched()$searched, four)
  expect_identical(ft_searched(role = NA_character_)$searched, four)
  expect_identical(ft_searched(role = "")$searched, four)
})

test_that("named sources stay a strict allowlist whatever the role (hub B-420)", {
  expect_identical(ft_searched(role = "unit", sources = "ols")$searched, "ols")
  expect_identical(ft_searched(role = "entity", sources = c("gbif", "worms"))$searched, c("gbif", "worms"))
  # An empty list still searches nothing.
  expect_identical(ft_searched(role = "unit", sources = character())$searched, character())
})

test_that("named sources are trimmed, lower-cased and de-duplicated (hub B-421)", {
  expect_identical(ft_searched(sources = "SMN")$searched, "smn")
  expect_identical(ft_searched(sources = "Qudt")$searched, "qudt")
  expect_identical(ft_searched(sources = " smn ")$searched, "smn")
  expect_identical(ft_searched(sources = c("OLS", "ols", " ols"))$diagnostics, "ols")
  expect_identical(ft_searched(sources = c("smn", "SMN"))$diagnostics, "smn")
  # Python's str.strip() removes a no-break space, and so does this now.
  expect_identical(ft_searched(sources = "\u00a0NVS\t")$searched, "nvs")
})

test_that("a missing or empty source name names no source (hub B-421)", {
  # A missing name used to be dispatched, fail on `if (NA)`, and be recorded as
  # a source that did not answer.
  expect_identical(ft_searched(sources = c("ols", NA, "", "  "))$diagnostics, "ols")
  expect_identical(ft_searched(sources = NA_character_)$diagnostics, character())
  expect_identical(ft_searched(sources = "")$diagnostics, character())
})

test_that("an unknown source name is kept, searched as nothing and reported (hub B-421)", {
  got <- ft_searched(sources = c("Unknown", "ols"))
  expect_identical(got$searched, "ols")
  expect_identical(got$diagnostics, c("unknown", "ols"))
})

test_that("the source-name normaliser mirrors metasalmonpy's, code point for code point (hub B-421)", {
  normalise <- metasalmon:::.ms_normalize_explicit_sources

  # First appearance wins and the caller's order is kept.
  expect_identical(normalise(c("OLS", "smn", "ols", "Smn", "nvs")), c("ols", "smn", "nvs"))
  expect_identical(normalise(list("SMN", "ols")), c("smn", "ols"))
  expect_identical(normalise(factor(c("NVS", "nvs"))), "nvs")
  expect_identical(normalise(c(NA, "", " \t\r\n")), character())
  expect_identical(normalise(character()), character())
  expect_identical(normalise(NULL), character())

  # Every code point Python's str.isspace() accepts -- what str.strip()
  # removes -- measured under Python 3.13.11 (Unicode 15.1).
  python_whitespace <- c(
    0x09:0x0D, 0x1C:0x20, 0x85, 0xA0, 0x1680, 0x2000:0x200A,
    0x2028, 0x2029, 0x202F, 0x205F, 0x3000
  )
  expect_length(python_whitespace, 29L)
  for (point in python_whitespace) {
    padded <- paste0(intToUtf8(point), "SMN", intToUtf8(point))
    expect_identical(normalise(padded), "smn", info = sprintf("U+%04X", point))
  }
  # U+180E is not whitespace to Python (it left Unicode's Zs category in 6.3),
  # so it is kept, and the name is then no source at all.
  kept <- normalise(paste0(intToUtf8(0x180E), "smn"))
  expect_identical(utf8ToInt(kept)[[1]], 0x180EL)
  # Whitespace inside a name is not trimmed.
  expect_identical(normalise("s mn"), "s mn")
})

test_that("an explicit source list reaches search_fn normalised (hub B-421)", {
  # metasalmonpy's make_source_policy() normalises the list before any search
  # function sees it, so an injected search_fn and the review packet's
  # recorded allowlist see the same names in both packages.
  dict <- tibble::tibble(
    dataset_id = "d1",
    table_id = "t1",
    column_name = "water_temperature",
    column_label = "Water temperature",
    column_description = NA_character_,
    column_role = "measurement",
    value_type = "number",
    unit_label = NA_character_,
    unit_iri = NA_character_,
    term_iri = NA_character_,
    property_iri = NA_character_,
    entity_iri = NA_character_,
    constraint_iri = NA_character_,
    statistical_modifier_iri = NA_character_
  )
  seen <- list()
  fake_search <- function(query, role, sources) {
    seen[[length(seen) + 1L]] <<- sources
    tibble::tibble()
  }
  suppressMessages(suggest_semantics(
    NULL,
    dict,
    sources = c(" OLS", "ols", "NVS", NA),
    max_per_role = 1,
    search_fn = fake_search
  ))
  expect_gt(length(seen), 0L)
  for (sources in seen) {
    expect_identical(sources, c("ols", "nvs"))
  }

  policy <- metasalmon:::.ms_semantic_source_policy(c("SMN", " smn", "Gcdfo"))
  expect_identical(policy$mode, "explicit")
  expect_identical(policy$sources, c("smn", "gcdfo"))
})

# Ambient case-folding is injected because an installed Turkish locale does
# not expose this defect on every libc/R combination. The lower-case strings
# are positive controls: a correct normalized dispatch still reaches them.
test_that("source normalization does not consult ambient locale case folding (B-421)", {
  turkish_lower <- function(x) {
    x <- chartr("I", "\u0131", x)
    x <- chartr("ABCDEFGHIJKLMNOPQRSTUVWXYZ", "abcdefghijklmnopqrstuvwxyz", x)
    Encoding(x) <- "UTF-8"
    x
  }
  got <- testthat::with_mocked_bindings(
    list(
      names = metasalmon:::.ms_normalize_explicit_sources(c("GBIF", "BIOPORTAL", "gbif")),
      dispatch = ft_searched(sources = c("GBIF", "BIOPORTAL"))
    ),
    tolower = turkish_lower, .package = "base"
  )
  expect_identical(got$names, c("gbif", "bioportal"))
  expect_identical(got$dispatch$searched, c("gbif", "bioportal"))
  expect_identical(got$dispatch$diagnostics, c("gbif", "bioportal"))
})

test_that("shared Unicode lowercase controls survive C locale source normalization (B-421)", {
  input <- c(" GBIF ", "BIOPORTAL", "\u0130", "\u039f\u03a3", "\u00c9XAMPLE", NA, "", "gbif")
  expected <- c("gbif", "bioportal", "i\u0307", "\u03bf\u03c2", "\u00e9xample")
  # These outputs were checked against Python lower(), including its dotted-I
  # expansion and context-sensitive final sigma. This is a shared corpus, not
  # a claim that different Unicode-library versions agree on every code point.
  normalise <- metasalmon:::.ms_normalize_explicit_sources
  expect_identical(normalise(input), expected)
  withr::with_locale(c(LC_CTYPE = "C"), {
    expect_identical(normalise(input), expected)
    expect_identical(metasalmon:::.ms_semantic_source_policy(input)$sources, expected)
  })
})
