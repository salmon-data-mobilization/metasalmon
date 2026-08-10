# Ordering that reaches bytes, a hash, an identifier, an exported return value,
# or a validated order must use explicit C collation. Under `LC_COLLATE=en_CA`
# (a common macOS default) `sort()` orders c("apple","Apple","B","_z","a") as
# `_z a apple Apple B`, while C orders it `Apple B _z a apple` — so the same
# package produced on two machines got different bytes and a different PID.
#
# Sys.setlocale() is process-global and testthat runs one process, so these
# tests live in their own file: a mid-test failure must not leave a wrong
# collation set for the rest of the suite.

test_that("the fixture keys actually distinguish C from the ambient collation", {
  # Guards the tests below from silently degrading into tautologies if the keys
  # are ever changed to something both collations agree on.
  keys <- c("apple", "Apple", "B", "_z", "a")
  expect_identical(sort(keys, method = "radix"), c("Apple", "B", "_z", "a", "apple"))
})

test_that("the resource-map PID is a fixed value for fixed members", {
  # A golden identifier is locale-proof by construction: any reordering of the
  # preimage moves it, on every platform. If this fails after an intentional
  # change to the preimage format, that change is user-visible and needs a NEWS
  # entry — do not simply regenerate the value.
  members <- list(
    list(role = "data", path = "data/Apple.csv", pid = "urn:uuid:1",
         format_id = "text/csv", size = 10, sha256 = "aa"),
    list(role = "data", path = "data/apple.csv", pid = "urn:uuid:2",
         format_id = "text/csv", size = 20, sha256 = "bb"),
    list(role = "data", path = "data/_z.csv", pid = "urn:uuid:3",
         format_id = "text/csv", size = 30, sha256 = "cc"),
    list(role = "data", path = "data/B.csv", pid = "urn:uuid:4",
         format_id = "text/csv", size = 40, sha256 = "dd")
  )

  expect_identical(
    metasalmon:::.ms_knb_resource_map_pid("pkg-1", "2026-01-01", members),
    "urn:uuid:17599676-8c02-51c2-a769-7d3dc4f07e9c"
  )
})

test_that("SSSOM canonical bytes are a fixed value for a fixed mapping set", {
  mapping_set <- list(
    metadata = list(
      mapping_set_id = "https://example.org/sets/one",
      curie_map = list(
        Zeta = "https://example.org/Z_",
        alpha = "https://example.org/a_",
        Beta = "https://example.org/B_"
      )
    ),
    mappings = data.frame(
      subject_id = c("alpha:1", "Zeta:1"),
      predicate_id = c("skos:exactMatch", "skos:closeMatch"),
      object_id = c("Beta:1", "Beta:2"),
      mapping_justification = c("semapv:ManualMappingCuration", "semapv:ManualMappingCuration"),
      stringsAsFactors = FALSE
    )
  )

  expect_identical(
    digest::digest(
      metasalmon:::.ms_sssom_canonical_bytes(mapping_set),
      algo = "sha256",
      serialize = FALSE
    ),
    "7d80bd221e10385c0253e5ee2184e2d113a1b387d0fe2a43ffffdd2aa15e91f0"
  )
})

test_that("the SSSOM curie map header is C-ordered, matching the mapping rows", {
  # The header lines and the table body live in the same function and are part
  # of the same hash; before this they used different collations.
  mapping_set <- list(
    metadata = list(
      mapping_set_id = "https://example.org/sets/one",
      curie_map = list(
        alpha = "https://example.org/a_",
        Beta = "https://example.org/B_",
        Zeta = "https://example.org/Z_"
      )
    ),
    mappings = data.frame(
      subject_id = "alpha:1",
      predicate_id = "skos:exactMatch",
      object_id = "Beta:1",
      mapping_justification = "semapv:ManualMappingCuration",
      stringsAsFactors = FALSE
    )
  )

  text <- rawToChar(metasalmon:::.ms_sssom_canonical_bytes(mapping_set))
  prefixes <- sub("^#\\s+([A-Za-z]+):.*$", "\\1", grep("^#\\s+[A-Za-z]+:", strsplit(text, "\n")[[1]], value = TRUE))

  expect_identical(prefixes, c("Beta", "Zeta", "alpha"))
})

test_that("NuSEDS crosswalk row order does not depend on LC_COLLATE", {
  # These are exported return values. `method_family` mixes "unknown" with
  # uppercase codes, so C sorts it last while en_* sorts it between T and V.
  enumeration <- nuseds_enumeration_method_crosswalk()
  estimate <- nuseds_estimate_method_crosswalk()

  expect_identical(
    enumeration$nuseds_value,
    enumeration$nuseds_value[order(enumeration$method_family, enumeration$nuseds_value, method = "radix")]
  )
  expect_identical(
    estimate$nuseds_value,
    estimate$nuseds_value[order(estimate$method_family, estimate$nuseds_value, method = "radix")]
  )
})

test_that("canonical artifacts are identical under the ambient locale and LC_COLLATE=C", {
  # Switching *to* "C" is portable everywhere; switching to a UTF-8 collate
  # locale is not. So this is full strength on a machine whose ambient collation
  # differs from C, and a harmless no-op on a C.UTF-8 runner. It never fails
  # spuriously.
  mapping_set <- list(
    metadata = list(
      mapping_set_id = "https://example.org/sets/one",
      curie_map = list(
        Zeta = "https://example.org/Z_",
        alpha = "https://example.org/a_",
        Beta = "https://example.org/B_"
      )
    ),
    mappings = data.frame(
      subject_id = c("alpha:1", "Zeta:1"),
      predicate_id = c("skos:exactMatch", "skos:closeMatch"),
      object_id = c("Beta:1", "Beta:2"),
      mapping_justification = c("semapv:ManualMappingCuration", "semapv:ManualMappingCuration"),
      stringsAsFactors = FALSE
    )
  )
  members <- list(
    list(role = "data", path = "data/Apple.csv", pid = "urn:uuid:1",
         format_id = "text/csv", size = 10, sha256 = "aa"),
    list(role = "data", path = "data/_z.csv", pid = "urn:uuid:2",
         format_id = "text/csv", size = 20, sha256 = "bb")
  )

  ambient_bytes <- metasalmon:::.ms_sssom_canonical_bytes(mapping_set)
  ambient_pid <- metasalmon:::.ms_knb_resource_map_pid("pkg-1", "2026-01-01", members)
  ambient_crosswalk <- nuseds_enumeration_method_crosswalk()$nuseds_value

  previous <- Sys.getlocale("LC_COLLATE")
  on.exit(suppressWarnings(Sys.setlocale("LC_COLLATE", previous)), add = TRUE)
  applied <- suppressWarnings(Sys.setlocale("LC_COLLATE", "C"))
  skip_if(!nzchar(applied), "Cannot set LC_COLLATE=C on this platform")

  expect_identical(metasalmon:::.ms_sssom_canonical_bytes(mapping_set), ambient_bytes)
  expect_identical(
    metasalmon:::.ms_knb_resource_map_pid("pkg-1", "2026-01-01", members),
    ambient_pid
  )
  expect_identical(nuseds_enumeration_method_crosswalk()$nuseds_value, ambient_crosswalk)
})

test_that("term-gap row order and top-candidate choice are locale-independent", {
  # `split()` builds factor levels with a locale-collated sort, so equal-
  # confidence rows inherited that order in an exported return value; and the
  # top-candidate pick tie-breaks on `source`/`label`.
  candidates <- tibble::tibble(
    source = c("apple", "Apple", "B", "_z", "a"),
    label = c("apple", "Apple", "B", "_z", "a"),
    iri = paste0("http://example.org/", 1:5),
    score = rep(0.5, 5),
    dictionary_role = "variable",
    search_query = "spawner count",
    label_text = "spawner count"
  )

  top_source <- function() {
    .ms_term_gap_candidate_summary(candidates, key = "k")$top$source
  }

  ambient <- top_source()
  old <- Sys.getlocale("LC_COLLATE")
  on.exit(Sys.setlocale("LC_COLLATE", old), add = TRUE)
  Sys.setlocale("LC_COLLATE", "C")

  expect_identical(top_source(), ambient)
  # C collation puts "Apple" before "B" before "_z" before "a" before "apple".
  expect_identical(ambient, "Apple")
})
