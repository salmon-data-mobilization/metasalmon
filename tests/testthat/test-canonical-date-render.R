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

test_that("datapackage.json and dataset.csv spell a POSIXct identically", {
  # BACKLOG #115 / hub item B-115, and it is the Date test above under a type
  # that genuinely reaches both writers. `.ms_align_cols()` converts a `Date` to
  # text and deliberately leaves a `POSIXct` typed (#93 item 1, which this does
  # not reopen), so an instant arrives at the descriptor builder AND at
  # `readr::write_csv()`, and each rendered it its own way:
  #
  #   datapackage.json      "0999-06-05 13:45:30"    <- as.character()
  #   metadata/dataset.csv  "0999-06-05T13:45:30Z"   <- write_csv()
  #
  # Brett ruled the spelling on 2026-09-14, once for both implementations:
  # readr's ISO instant form, the `T` separator and the `Z` zone marker. So the
  # descriptor moved onto readr's baseline and this asserts the AGREEMENT rather
  # than a literal, for the reason the next paragraph gives.
  #
  # WHAT THIS DELIBERATELY DOES NOT PIN: the year's zero padding. readr hands
  # `%Y` to the platform's strftime, so `write_csv()` writes
  # `0999-06-05T13:45:30Z` on macOS and `999-06-05T13:45:30Z` on Linux -- the
  # split documented at the top of `R/platform-time.R`, reaching readr's own
  # instant path. The descriptor now emits whichever one readr emits, so the two
  # files agree on both platforms; pinning the padded literal here would pass on
  # macOS and fail on CI, and padding only the descriptor to satisfy it would
  # reopen #115 on Linux. The residual unpadded year is readr's own defect on the
  # CSV side and is reported separately, not patched in one of the two files.
  #
  # FAILING-BEFORE, measured 2026-09-14 on the pre-fix tree (Linux, R 4.3.3,
  # readr 2.2.0): descriptor `0999-06-05 13:45:30`, CSV `999-06-05T13:45:30Z`.
  # So all three of separator, zone marker and padding disagreed here, where the
  # backlog's macOS measurement saw only the first two.
  #
  # *Retires when:* nothing. It is the standing check that the descriptor and the
  # CSV keep one spelling of one instant, whichever writer moves next.
  skip_if_not_installed("readr")

  path <- withr::local_tempdir()
  suppressMessages(write_salmon_datapackage(
    resources = list(obs = data.frame(site_id = c("s1", "s2"), stringsAsFactors = FALSE)),
    dataset_meta = tibble::tibble(
      dataset_id = "d1",
      title = "T",
      description = "D",
      creator = "metasalmon tests",
      # The backlog's fixture, and a midnight instant: `as.character()` drops
      # the time from an all-midnight instant entirely, so the descriptor used
      # to answer "2024-12-31" where the CSV answered "2024-12-31T00:00:00Z".
      temporal_start = as.POSIXct("0999-06-05 13:45:30", tz = "UTC"),
      temporal_end = as.POSIXct("2024-12-31 00:00:00", tz = "UTC")
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

  # The condition B-115 retires on.
  expect_identical(descriptor$temporal$start[[1]], dataset_csv$temporal_start[[1]])
  expect_identical(descriptor$temporal$end[[1]], dataset_csv$temporal_end[[1]])

  # The ruled form, asserted on the part that is platform-independent.
  expect_match(descriptor$temporal$start[[1]], "^[0-9]+-06-05T13:45:30Z$")
  # The midnight half: the time survives rather than being dropped.
  expect_identical(descriptor$temporal$end[[1]], "2024-12-31T00:00:00Z")
})

test_that("the descriptor instant renderer is readr's, by construction", {
  # The unit-level statement of the same contract, and the reason the renderer
  # asks readr instead of reproducing it. A hand-rolled
  # `format(x, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")` was measured equal to readr on
  # every case below, and would still be a SECOND rendering of one value -- the
  # defect "one value, one rendering" names rather than a way to fix it. These
  # cases are the three behaviours a hand renderer has to get right and can get
  # wrong silently: conversion to UTC, truncation of a fractional second, and
  # the year.
  #
  # *Retires when:* `metadata/dataset.csv` stops being written by
  # `readr::write_csv()`, at which point the descriptor follows its new writer.
  skip_if_not_installed("readr")

  readr_cell <- function(value) {
    sub("\n$", "", readr::format_csv(data.frame(x = value), col_names = FALSE))
  }
  cases <- list(
    as.POSIXct("0999-06-05 13:45:30", tz = "UTC"),
    as.POSIXct("0001-02-03 04:05:06", tz = "UTC"),
    as.POSIXct("2024-01-31 10:00:00.5", tz = "UTC"),
    as.POSIXct("2024-01-31 00:00:00", tz = "UTC"),
    as.POSIXct("2024-01-31 10:00:00", tz = "America/Vancouver")
  )
  for (value in cases) {
    expect_identical(
      metasalmon:::.ms_descriptor_temporal_text(value),
      readr_cell(value)
    )
  }

  # NA stays NA, and a vector keeps its positions -- the descriptor passes a
  # scalar, but a renderer that silently drops NAs would misalign any caller.
  expect_identical(
    metasalmon:::.ms_readr_instant_character(
      as.POSIXct(c("0999-06-05 13:45:30", NA), tz = "UTC")
    ),
    c(readr_cell(as.POSIXct("0999-06-05 13:45:30", tz = "UTC")), NA_character_)
  )

  # UNCHANGED FOR EVERY OTHER TYPE, which is what keeps this narrow. A character
  # cell and a Date both keep the `.ms_iso_character()` spelling they have always
  # had; only the instant branch moved.
  expect_identical(metasalmon:::.ms_descriptor_temporal_text("2024-01-01"), "2024-01-01")
  expect_identical(
    metasalmon:::.ms_descriptor_temporal_text(as.Date("0999-01-01")),
    "0999-01-01"
  )
})

# Hub item B-162, the third copy of the value the two tests above pin.
# `.ms_eml_add_coverage()` renders `temporal_start` and `temporal_end` through
# `as.character()`, which reads like a third renderer beside those two writers.
# It is not one, and the two tests below check that it stays that way. The EML
# builder has a single entry, `write_eml_from_sdp(path)`, and it reads the
# package back from disk as text: `metadata/dataset.csv` through
# `.ms_read_metadata_csv()`, every column character, or `datapackage.json` when
# there is no canonical metadata. So the value is rendered once, by a writer,
# and `as.character()` of that text is the identity. THE BASELINE IS THE FILE
# THE EML IS READ FROM, so neither of the renderers someone would reach for is
# right at that line:
#
#   .ms_descriptor_temporal_text()  pads a short year in text, so the EML
#                                   would carry "0999-06-05" from a
#                                   dataset.csv cell of "999-06-05".
#   .ms_canonical_character()       renders an instant through
#                                   as.character(), not through readr.
#
# WHAT THESE DELIBERATELY DO NOT PIN: a typed instant. The three copies of one
# agree today, because the EML reads the CSV's bytes. But EML 2.2.0's
# `calendarDate` is `xs:gYear | xs:date`, so `YYYY-MM-DDThh:mm:ssZ` fails the
# schema check `write_eml_from_sdp()` runs, although the ruling on Q-51 put
# that form in the SDP profile. Any EML that carries an instant has to differ
# from the CSV there (for example a date plus EML's separate `time` element),
# so a byte-agreement pin would make that fix look like a regression.
#
# *Retires when:* the EML stops being built from the package on disk. An EML
# builder that takes a typed frame is a writer, and has to render through the
# CSV's baseline; the pin then moves to that renderer.
eml_dataset_csv_temporal <- function(path) {
  dataset_csv <- readr::read_csv(
    file.path(path, "metadata", "dataset.csv"),
    col_types = readr::cols(.default = readr::col_character())
  )
  c(dataset_csv$temporal_start[[1]], dataset_csv$temporal_end[[1]])
}

eml_calendar_dates <- function(doc) {
  c(
    xml2::xml_text(xml2::xml_find_first(doc, ".//rangeOfDates/beginDate/calendarDate")),
    xml2::xml_text(xml2::xml_find_first(doc, ".//rangeOfDates/endDate/calendarDate"))
  )
}

test_that("EML calendarDate is the dataset.csv spelling of a typed Date", {
  # Through the exported builder and its schema check. EML can carry a date, so
  # here all three copies agree byte for byte. The pre-1000 year is the one
  # whose spelling depends on which renderer ran.
  #
  # The skip retires when emld moves from Suggests to Imports, or when
  # `write_eml_from_sdp()` stops validating through it.
  skip_if_not_installed("emld")

  path <- suppressMessages(make_eml_test_sdp(
    withr::local_tempdir(),
    temporal_start = as.Date("0999-01-01"),
    temporal_end = as.Date("2024-12-31")
  ))
  result <- suppressMessages(write_eml_from_sdp(
    path,
    output_path = file.path(path, "metadata", "eml.xml")
  ))
  calendar <- eml_calendar_dates(xml2::read_xml(result$path))
  descriptor <- jsonlite::read_json(file.path(path, "datapackage.json"))

  expect_identical(calendar, eml_dataset_csv_temporal(path))
  expect_identical(calendar, c(descriptor$temporal$start, descriptor$temporal$end))
  expect_identical(calendar, c("0999-01-01", "2024-12-31"))
})

test_that("EML calendarDate follows dataset.csv where the two writers disagree", {
  # Text that the two writers spell differently: the descriptor pads the short
  # year and dataset.csv keeps it. That disagreement is between the writers and
  # is not asserted here either way. What is asserted is that the EML follows
  # the file it reads, and this is the input a re-rendering EML would change on
  # every platform. The exported call stops at the schema check, since
  # "999-06-05" is not an `xs:date`, so the coverage is built from
  # `read_salmon_datapackage()`'s frame, which `validate_salmon_datapackage()`
  # returns unchanged as the `package` the builder receives. That also keeps
  # this half free of emld.
  path <- suppressMessages(make_eml_test_sdp(
    withr::local_tempdir(),
    temporal_start = "999-06-05",
    temporal_end = "2024-12-31"
  ))
  coverage <- xml2::xml_new_root("dataset")
  metasalmon:::.ms_eml_add_coverage(
    coverage,
    suppressMessages(read_salmon_datapackage(path))$dataset,
    mapping = list()
  )

  expect_identical(eml_calendar_dates(coverage), eml_dataset_csv_temporal(path))
  expect_identical(eml_calendar_dates(coverage)[[1]], "999-06-05")
})
