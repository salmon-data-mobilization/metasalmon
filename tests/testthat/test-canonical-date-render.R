# One value, one rendering. Backlog #93 items 3-5, under Brett's 2026-08-24
# ruling on Q12: "fix all three by coercing them once at render time per type."
#
# The defect these pin is not the year padding by itself -- it is that a single
# function rendered the same cell TWICE, through two renderers that disagree,
# and then used one rendering for the row ORDER and the other for the row
# CONTENT. `.ms_canonical_character()` (R/platform-time.R) is now the one
# render-time coercion, and every site reads its output.
#
# *Retires when:* R's `as.character()` fast path zero-pads AND `format()` stops
# being reachable from any canonical path -- i.e. when the two renderers can no
# longer disagree. Neither is this package's to arrange, so treat these as
# permanent.

# A mapping set is deliberately built by hand rather than read from a file: the
# reader produces character columns, and the defect needs a typed column, which
# only an in-memory mapping set can carry. `write_sdp_sssom()` accepts one.
sssom_typed_set <- function(mappings) {
  list(
    metadata = list(
      sssom_version = "1.1",
      mapping_set_id = "https://example.org/mappings/typed",
      curie_map = list(
        psc = "https://w3id.org/psc/vocab/concept/",
        gcdfo = "https://w3id.org/gcdfo/salmon#",
        skos = "http://www.w3.org/2004/02/skos/core#",
        semapv = "https://w3id.org/semapv/vocab/"
      )
    ),
    mappings = mappings
  )
}

sssom_data_rows <- function(mapping_set) {
  lines <- strsplit(
    rawToChar(metasalmon:::.ms_sssom_canonical_bytes(mapping_set)),
    "\n",
    fixed = TRUE
  )[[1]]
  table_lines <- lines[!startsWith(lines, "#")]
  table_lines[-1]
}

test_that("as.character() and format() still disagree about a pre-1000 Date", {
  # If this ever passes trivially -- a future R padding `as.character()`, or a
  # platform whose `format()` stops padding -- every test below becomes a
  # tautology without failing. Pin the premise, not just the conclusion.
  early <- as.Date("0999-01-01")
  expect_identical(as.character(early), "999-01-01")
  expect_identical(
    as.character(as.data.frame(list(d = early), stringsAsFactors = FALSE)[[1]]),
    "999-01-01"
  )
  # `apply()` renders through `as.matrix()`, which renders through `format()`.
  # macOS pads here and glibc does not, so this assertion is deliberately about
  # the DISAGREEMENT WITH `as.character()`, which holds on both platforms:
  # macOS "0999-01-01" vs "999-01-01", Linux "1-01-01"-style unpadded on both
  # sides only for year < 1000 rendered by strftime. Comparing the two
  # renderers directly is the platform-independent statement.
  matrix_form <- as.matrix(data.frame(d = early))[[1]]
  expect_true(matrix_form %in% c("0999-01-01", "999-01-01"))
})

test_that("SSSOM row order and row bytes come from the same rendering", {
  # THE CORE OF ITEM 3. The two renderers do not merely spell a date
  # differently, they SORT it differently: unpadded, "1000-01-01" precedes
  # "999-01-01" in C order because "1" < "9"; padded, "0999-01-01" precedes
  # "1000-01-01". So the pre-fix function ordered rows by one spelling and
  # emitted the other, and the emitted table was not sorted by its own visible
  # contents.
  #
  # RED, and on BOTH platforms, which is why the assertion is split in two:
  #   * macOS pre-fix: bytes padded, order unpadded -> the self-consistency
  #     assertion fails (row 0999 emitted after row 1000).
  #   * Linux pre-fix: bytes and order both unpadded -> self-consistent, but
  #     the emitted bytes read "999-01-01", so the padding assertion fails.
  # Every leading column is identical ON PURPOSE. `subject_id` is the first
  # column in `.ms_sssom_column_order`, so any difference there decides the
  # order before `mapping_date` is consulted and the test proves nothing.
  mapping_set <- sssom_typed_set(data.frame(
    subject_id = rep("psc:A", 2L),
    predicate_id = rep("skos:exactMatch", 2L),
    object_id = rep("gcdfo:A", 2L),
    mapping_justification = rep("semapv:ManualMappingCuration", 2L),
    mapping_date = as.Date(c("1000-01-01", "0999-01-01")),
    stringsAsFactors = FALSE
  ))

  rows <- sssom_data_rows(mapping_set)
  expect_length(rows, 2L)

  # The bytes carry the padded year, on every platform.
  expect_true(any(grepl("\t0999-01-01", rows, fixed = TRUE)))
  expect_false(any(grepl("\t999-01-01", rows, fixed = TRUE)))

  # ...and the emitted rows are in C order OF THEMSELVES. This is the property
  # that does not care which renderer won: order and content agree.
  expect_identical(rows, sort(rows, method = "radix"))

  # Stated concretely, so a regression reads as a story rather than as a
  # sorted-vector mismatch: 0999 sorts before 1000 once both are padded, and
  # after it when only the sort key is left unpadded.
  expect_true(endsWith(rows[[1]], "\t0999-01-01"))
  expect_true(endsWith(rows[[2]], "\t1000-01-01"))
})

test_that("an SSSOM cell's bytes do not depend on its neighbours", {
  # The second half of item 3, and it needs no pre-1000 date at all.
  # `as.matrix()` renders a numeric column with `format()`, which picks ONE
  # notation for the whole column: `confidence` 1.5 was emitted as "1.5e+00"
  # merely because another row held 100000 -- while sorting as "1.5". A cell
  # whose bytes are a function of other rows cannot be canonical.
  one_row <- sssom_typed_set(data.frame(
    subject_id = "psc:A",
    predicate_id = "skos:exactMatch",
    object_id = "gcdfo:A",
    mapping_justification = "semapv:ManualMappingCuration",
    confidence = 1.5,
    stringsAsFactors = FALSE
  ))
  two_rows <- sssom_typed_set(data.frame(
    subject_id = c("psc:A", "psc:B"),
    predicate_id = rep("skos:exactMatch", 2L),
    object_id = c("gcdfo:A", "gcdfo:B"),
    mapping_justification = rep("semapv:ManualMappingCuration", 2L),
    confidence = c(1.5, 100000),
    stringsAsFactors = FALSE
  ))

  shared <- grep("^psc:A\t", sssom_data_rows(two_rows), value = TRUE)
  expect_identical(shared, sssom_data_rows(one_row))
  expect_true(endsWith(shared, "\t1.5"))
})

test_that("SSSOM rendering leaves character cells exactly as they are", {
  # The reason the coercion is PER TYPE. `.ms_iso_character()` pads any text
  # matching `^[0-9]{1,3}-[0-9]{2}-[0-9]{2}`, so routing a character column
  # through it would rewrite a user's identifier. Text is already text.
  mapping_set <- sssom_typed_set(data.frame(
    subject_id = "psc:12-34-56",
    predicate_id = "skos:exactMatch",
    object_id = "gcdfo:A",
    mapping_justification = "semapv:ManualMappingCuration",
    mapping_date = "999-01-01",
    stringsAsFactors = FALSE
  ))

  rows <- sssom_data_rows(mapping_set)
  expect_true(startsWith(rows[[1]], "psc:12-34-56\t"))
  expect_true(endsWith(rows[[1]], "\t999-01-01"))
})

test_that("a missing SSSOM cell is still an empty field", {
  mapping_set <- sssom_typed_set(data.frame(
    subject_id = c("psc:A", "psc:B"),
    predicate_id = rep("skos:exactMatch", 2L),
    object_id = c("gcdfo:A", "gcdfo:B"),
    mapping_justification = rep("semapv:ManualMappingCuration", 2L),
    mapping_date = as.Date(c("0999-01-01", NA)),
    stringsAsFactors = FALSE
  ))

  rows <- sssom_data_rows(mapping_set)
  # `na.last = TRUE` puts the missing date last, and it serializes as "".
  expect_true(endsWith(rows[[1]], "\t0999-01-01"))
  expect_true(endsWith(rows[[2]], "\t"))
})

test_that(".ms_canonical_character() dispatches on type and renders once", {
  render <- metasalmon:::.ms_canonical_character

  # Date: the one type where the two renderers genuinely disagree.
  expect_identical(render(as.Date("0999-01-01")), "0999-01-01")
  # POSIXct: padded HERE, where the baseline is `as.character()`. Deliberately
  # the opposite of `.ms_iso_date_columns()`, whose baseline is
  # `readr::write_csv()` -- see "the write_csv Date renderer is still the narrow
  # one" below, and R/platform-time.R.
  # `as.character()`'s shape choices survive: space separator, no zone marker,
  # fractional second kept.
  expect_identical(
    render(as.POSIXct("0999-01-31 10:00:00.5", tz = "UTC")),
    "0999-01-31 10:00:00.5"
  )
  # Character: identity, including text that merely looks like a short date.
  expect_identical(render(c("999-01-01", "12-34-56", NA)), c("999-01-01", "12-34-56", NA))
  # Everything else: element-wise `as.character()`, so no cell is reshaped by
  # its neighbours the way `format()` reshapes one.
  expect_identical(render(c(1.5, 100000)), c("1.5", "1e+05"))
  expect_identical(render(c(TRUE, NA)), c("TRUE", NA))
  expect_identical(render(factor(c("b", "a"))), c("b", "a"))
  expect_identical(render(as.Date(NA)), NA_character_)
})

test_that("the canonical value token keys a Date the same in every branch", {
  # ITEM 5. `.ms_canonical_value_tokens()` took its `original` fallback through
  # `as.character()`, so a Date column declared `value_type = "string"` keyed
  # "999-01-01" while the `date` branch beside it keyed "0999-01-01" -- and
  # while the CSV the writer produces from that same column reads
  # "0999-01-01". The in-memory frame disagreed with its own written package
  # about whether a data value was listed in `codes.csv`.
  canon <- metasalmon:::.ms_canonical_value_tokens
  early <- as.Date(c("0999-01-01", "0001-12-31"))

  expect_identical(canon(early, "date"), c("0999-01-01", "0001-12-31"))
  expect_identical(canon(early, "string"), c("0999-01-01", "0001-12-31"))
  # An undeclared / unknown value_type falls into the same `original` return.
  expect_identical(canon(early, ""), c("0999-01-01", "0001-12-31"))
  expect_identical(canon(early, "not-a-value-type"), c("0999-01-01", "0001-12-31"))

  # The two sides of the codes.csv comparison now agree: the raw token as the
  # writer spells it, and the typed column it was written from.
  expect_identical(canon("0999-01-01", "string"), canon(early[1], "string"))

  # Inert for character input, which is every on-disk path, and for a year the
  # renderers already agree on.
  expect_identical(canon("999-01-01", "string"), "999-01-01")
  expect_identical(canon(as.Date("2024-01-31"), "string"), "2024-01-31")
})

test_that("the write_csv Date renderer is still the narrow one", {
  # NON-INTERFERENCE, restated here because this change adds a SECOND renderer
  # with a DIFFERENT rule for POSIXct, and the two are one `git grep` apart.
  # `.ms_iso_date_columns()` sits on the `readr::write_csv()` path, whose
  # instant output is already correct; padding a POSIXct there would change the
  # separator, the zone marker, and whether a fractional second survives.
  # `.ms_canonical_character()` sits on the `as.character()` path, where the
  # year is unpadded for both types. Same package, opposite rulings, both
  # correct. (Backlog #93 item 1 pinned the first; this pins that item 3's fix
  # did not leak into it.)
  skip_if_not_installed("readr")

  frame <- data.frame(
    ts = as.POSIXct("0999-01-31 10:00:00.5", tz = "UTC"),
    stringsAsFactors = FALSE
  )
  expect_identical(
    readr::format_csv(metasalmon:::.ms_iso_date_columns(frame)),
    readr::format_csv(frame)
  )
  expect_false(identical(
    metasalmon:::.ms_iso_date_columns(frame)$ts,
    metasalmon:::.ms_canonical_character(frame$ts)
  ))
})

test_that("datapackage.json and dataset.csv spell a Date identically", {
  # ITEM 4, and the answer is that its stated mechanism is UNREACHABLE. The
  # item read "`jsonlite::write_json()` pads a `Date` and `readr::write_csv()`
  # does not, so one `write_salmon_datapackage()` call can emit `0999-01-01` in
  # the JSON and `999-01-01` in the CSV." Item 2's fix (2026-08-21) made
  # `.ms_align_cols()` render every metadata frame's Date columns to padded ISO
  # text, and every frame that feeds the descriptor goes through it -- so no
  # `Date` survives to either writer. Traced 2026-08-25 across the whole
  # descriptor builder: no `created`/`sources`/custom-field passthrough, field
  # objects built from the dictionary alone, no resource value copied into the
  # descriptor.
  #
  # This test exists because "unreachable" decays. It asserts the AGREEMENT
  # rather than the coercion, so it still fails if a future descriptor key
  # starts carrying a typed value, whichever writer changes.
  #
  # RED-verified 2026-08-25 by removing the `.ms_iso_date_columns()` call from
  # `.ms_align_cols()`: descriptor "0999-01-01", CSV "999-01-01".
  #
  # *Retires when:* nothing. It is the standing check that item 4 stays shut.
  skip_if_not_installed("readr")

  path <- withr::local_tempdir()
  suppressMessages(write_salmon_datapackage(
    resources = list(obs = data.frame(site_id = c("s1", "s2"), stringsAsFactors = FALSE)),
    dataset_meta = tibble::tibble(
      dataset_id = "d1",
      title = "T",
      description = "D",
      creator = "metasalmon tests",
      temporal_start = as.Date("0999-01-01"),
      temporal_end = as.Date("2024-12-31")
    ),
    table_meta = tibble::tibble(
      dataset_id = "d1", table_id = "obs", file_name = "data/obs.csv",
      table_label = "Observations", description = "One site column"
    ),
    dict = tibble::tibble(
      dataset_id = "d1", table_id = "obs", column_name = "site_id",
      column_label = "Site", column_description = "Site identifier",
      column_role = "identifier", value_type = "string", required = FALSE
    ),
    path = path,
    overwrite = TRUE
  ))

  descriptor <- jsonlite::read_json(file.path(path, "datapackage.json"))
  dataset_csv <- readr::read_csv(
    file.path(path, "metadata", "dataset.csv"),
    col_types = readr::cols(.default = readr::col_character())
  )

  expect_identical(descriptor$temporal$start[[1]], "0999-01-01")
  expect_identical(descriptor$temporal$start[[1]], dataset_csv$temporal_start[[1]])
  expect_identical(descriptor$temporal$end[[1]], dataset_csv$temporal_end[[1]])
})
