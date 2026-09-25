# `review_metadata()` and the `set_sdp_*()` setters -- free-text editing for
# the R-native review flow (stream S5 milestone M4, backlog #74).
#
# THE GATE THIS FILE EXISTS TO MEASURE. Before M4, a package built by
# `create_sdp()` could not reach
# `validate_salmon_datapackage(require_iris = TRUE)` from R at all: free-text
# `MISSING ...:` placeholders were refused and only a spreadsheet could replace
# them, and `review_semantics()` shows shortlists rather than gaps so a slot
# with no candidates never entered any queue. The round-trip test below drives
# the whole thing with **no CSV edit of any kind** -- it EXECUTES the calls
# `review_metadata()` printed, which is the standard the M1-M3 retrospective
# argued for: if a program's output is meant to be run, run it in the tests.
# A printed call naming a column that does not exist passes every `grepl()`
# assertion ever written; it does not survive being evaluated.

setter_fixture_resources <- function() {
  list(
    spawners = data.frame(
      stream_name = c("Bear Creek", "Elk River"),
      spawner_count = c(120L, 340L),
      stringsAsFactors = FALSE
    )
  )
}

setter_fixture_package <- function(name = "setter-demo", seed_semantics = FALSE) {
  path <- file.path(withr::local_tempdir(.local_envir = parent.frame()), name)
  suppressMessages(create_sdp(
    setter_fixture_resources(),
    path = path,
    dataset_id = "demo-1",
    seed_semantics = seed_semantics,
    check_updates = FALSE,
    overwrite = TRUE
  ))
}

read_meta <- function(path, file_name) {
  readr::read_csv(
    file.path(path, "metadata", file_name),
    col_types = readr::cols(.default = readr::col_character()),
    na = ""
  )
}

# Pull the runnable calls back out of the printed view. The console emits one
# argument per line, so a call runs from its `set_sdp_*(` line to the closing
# `)` -- extracted here exactly as a user pasting from the terminal would.
printed_setter_calls <- function(review, path_expr = "pkg") {
  lines <- .ms_metadata_render_lines(review, path_expr = path_expr)
  starts <- grep("^   set_sdp_", lines)
  ends <- grep("^   \\)$", lines)
  expect_equal(length(starts), length(ends))
  vapply(
    seq_along(starts),
    function(i) paste(lines[starts[[i]]:ends[[i]]], collapse = "\n"),
    character(1)
  )
}

# Replace every `<...>` template with a value a reviewer would have supplied.
fill_templates <- function(call_text) {
  replacements <- c(
    "<IRI for term_iri>" = "https://w3id.org/smn/SpawnerAbundance",
    "<IRI for property_iri>" = "https://w3id.org/smn/Abundance",
    "<IRI for entity_iri>" = "https://w3id.org/smn/Spawner",
    "<IRI for unit_iri>" = "http://qudt.org/vocab/unit/NUM",
    "<IRI for what one row represents>" = "https://w3id.org/smn/SpawningPopulation"
  )
  for (template in names(replacements)) {
    call_text <- gsub(template, replacements[[template]], call_text, fixed = TRUE)
  }
  call_text <- gsub("\"<add dataset license[^\"]*\"", "\"CC-BY-4.0\"", call_text)
  call_text <- gsub("\"<add primary contact email>\"", "\"data@example.org\"", call_text, fixed = TRUE)
  gsub("\"<[^\"]*>\"", "\"a value a reviewer typed\"", call_text)
}

test_that("a package reaches strict validation entirely from R, with no CSV edit", {
  # The whole milestone in one test, and the plan's proofs 5 and 6.
  pkg <- setter_fixture_package()
  data_path <- file.path(pkg, "data", "spawners.csv")
  data_before <- readBin(data_path, "raw", file.info(data_path)$size)

  review <- review_metadata(pkg)
  expect_gt(nrow(review), 0L)
  expect_true(all(c("dataset.csv", "tables.csv", "column_dictionary.csv") %in% review$file))

  for (call_text in fill_templates(printed_setter_calls(review))) {
    suppressMessages(eval(parse(text = call_text), envir = list2env(list(pkg = pkg))))
  }

  expect_equal(nrow(review_metadata(pkg)), 0L)
  expect_no_error(suppressMessages(
    validate_salmon_datapackage(pkg, require_iris = TRUE)
  ))
  # The setters are surgical for the same reason `apply_sdp_semantics()` is:
  # editing metadata must never rewrite the data.
  expect_identical(readBin(data_path, "raw", file.info(data_path)$size), data_before)
})

test_that("review_metadata() reports exactly what strict validation refuses", {
  # The list is only worth trusting if clearing it is sufficient AND nothing on
  # it is noise. Sufficiency is the round trip above; this is the other half --
  # every reported field is one the strict validator names.
  pkg <- setter_fixture_package()
  review <- review_metadata(pkg)
  loaded <- suppressMessages(read_salmon_datapackage(pkg))

  # Compared against the validator's own issue collectors rather than against
  # its abort message: the message shows only the first ten issues, so an
  # assertion on the text would pass or fail on where the truncation happened
  # to fall.
  reported <- paste(review$file, review$field)
  placeholder_fields <- .ms_collect_unresolved_placeholders(loaded)
  expect_gt(length(placeholder_fields), 0L)
  for (entry in placeholder_fields) {
    expect_true(sub("\\$", " ", entry) %in% reported, info = entry)
  }
  # Everything the placeholder scan finds is reported, and so is each of the
  # two requirements that live outside it.
  expect_gt(nrow(.ms_collect_missing_table_observation_unit_iri_issues(loaded$tables)), 0L)
  expect_true("tables.csv observation_unit_iri" %in% reported)
  expect_true(all(paste("column_dictionary.csv", .ms_measurement_iri_fields()) %in% reported))
})

test_that("the printed call refuses to run with its placeholder still in it", {
  # A call pasted unedited must fail loudly. Writing `<add creator, team, or
  # originating program>` into `creator` would PASS strict validation on a
  # package that says nothing about who made it -- worse than the placeholder
  # it replaced, because the marker is gone.
  pkg <- setter_fixture_package()
  calls <- printed_setter_calls(review_metadata(pkg))
  for (call_text in calls) {
    expect_error(
      eval(parse(text = call_text), envir = list2env(list(pkg = pkg))),
      "placeholder from"
    )
  }
})

test_that("the printed call addresses a row that exists", {
  # The defect this most easily ships with, and the one `grepl()` cannot see.
  # The address is resolved BEFORE the value is checked, so the abort above
  # proves the row was found; here it is proved directly by asking for a table
  # and column the printed call named.
  pkg <- setter_fixture_package()
  review <- review_metadata(pkg)
  dictionary <- read_meta(pkg, "column_dictionary.csv")
  tables <- read_meta(pkg, "tables.csv")

  for (i in seq_len(nrow(review))) {
    row <- review[i, , drop = FALSE]
    if (identical(row$file[[1]], "column_dictionary.csv")) {
      expect_equal(sum(
        dictionary$table_id == row$table_id[[1]] &
          dictionary$column_name == row$column_name[[1]]
      ), 1L)
    }
    if (identical(row$file[[1]], "tables.csv")) {
      expect_equal(sum(tables$table_id == row$table_id[[1]]), 1L)
    }
  }
})

test_that("set_sdp_dataset() keeps the descriptor in step in the same write", {
  pkg <- setter_fixture_package()
  suppressMessages(set_sdp_dataset(
    pkg,
    title = "Spawner counts",
    description = "Counts of spawning salmon.",
    creator = "Pacific Salmon Commission",
    contact_name = "Data Unit",
    contact_email = "data@example.org",
    contact_org = "PSC",
    license = "CC-BY-4.0"
  ))

  dataset <- read_meta(pkg, "dataset.csv")
  expect_equal(dataset$creator, "Pacific Salmon Commission")

  descriptor <- jsonlite::read_json(file.path(pkg, "datapackage.json"), simplifyVector = FALSE)
  expect_equal(descriptor$title, "Spawner counts")
  expect_equal(descriptor$contributors[[1]]$title, "Pacific Salmon Commission")
  expect_equal(descriptor$contributors[[2]]$email, "data@example.org")
  expect_equal(descriptor$contributors[[2]]$organization, "PSC")
  expect_equal(descriptor$licenses[[1]]$name, "CC-BY-4.0")
})

test_that("the surgical patch produces the descriptor a full rebuild would", {
  # The assertion the execplan asked for, and the reason the three descriptor
  # builders were extracted rather than re-spelled: a patched descriptor and a
  # rebuilt one must be the same JSON. Anything less and the two producers
  # drift, which nothing would detect -- the rule that would
  # (`datapackage_consistent_with_csv_metadata`) is one of the dead rules in
  # `sdp.rules.yaml`.
  pkg <- setter_fixture_package()
  suppressMessages(set_sdp_dataset(
    pkg,
    title = "Spawner counts", description = "Counts of spawning salmon.",
    creator = "Pacific Salmon Commission", contact_name = "Data Unit",
    contact_email = "data@example.org", license = "CC-BY-4.0"
  ))
  suppressMessages(set_sdp_table(
    pkg, "spawners",
    table_label = "Spawners", description = "One row per stream and year."
  ))
  suppressMessages(set_sdp_column(
    pkg, "spawner_count",
    table = "spawners",
    column_label = "Spawner count", column_description = "Spawners counted.",
    term_iri = "https://w3id.org/smn/SpawnerAbundance"
  ))
  patched <- jsonlite::read_json(file.path(pkg, "datapackage.json"), simplifyVector = FALSE)

  pkg2 <- suppressMessages(read_salmon_datapackage(pkg))
  rebuilt_path <- file.path(withr::local_tempdir(), "rebuilt")
  suppressMessages(write_salmon_datapackage(
    resources = pkg2[["resources"]],
    dict = pkg2$dictionary,
    table_meta = pkg2$tables,
    dataset_meta = pkg2$dataset,
    path = rebuilt_path
  ))
  rebuilt <- jsonlite::read_json(file.path(rebuilt_path, "datapackage.json"), simplifyVector = FALSE)

  expect_identical(patched$title, rebuilt$title)
  expect_identical(patched$description, rebuilt$description)
  expect_identical(patched$contributors, rebuilt$contributors)
  expect_identical(patched$licenses, rebuilt$licenses)

  resource_of <- function(descriptor, name) {
    Filter(function(r) identical(r$name, name), descriptor$resources)[[1]]
  }
  expect_identical(resource_of(patched, "spawners"), resource_of(rebuilt, "spawners"))
})

test_that("clearing a field removes its descriptor key, as a rebuild would", {
  pkg <- setter_fixture_package()
  suppressMessages(set_sdp_column(
    pkg, "spawner_count", table = "spawners",
    term_iri = "https://w3id.org/smn/SpawnerAbundance"
  ))
  suppressMessages(set_sdp_column(pkg, "spawner_count", table = "spawners", term_iri = NA))

  dictionary <- read_meta(pkg, "column_dictionary.csv")
  expect_true(is.na(dictionary$term_iri[dictionary$column_name == "spawner_count"]))

  descriptor <- jsonlite::read_json(file.path(pkg, "datapackage.json"), simplifyVector = FALSE)
  resource <- Filter(function(r) identical(r$name, "spawners"), descriptor$resources)[[1]]
  field <- Filter(function(f) identical(f$name, "spawner_count"), resource$schema$fields)[[1]]
  # Absent, not an empty string: the writer omits an empty field entirely.
  expect_null(field$term_iri)
})

test_that("a setter is re-runnable and does not touch anything it was not asked about", {
  pkg <- setter_fixture_package()
  suppressMessages(set_sdp_table(pkg, "spawners", description = "One row per stream."))

  targets <- c(
    file.path(pkg, "metadata", "tables.csv"),
    file.path(pkg, "metadata", "dataset.csv"),
    file.path(pkg, "metadata", "column_dictionary.csv"),
    file.path(pkg, "datapackage.json")
  )
  before <- vapply(targets, function(p) digest::digest(p, file = TRUE), character(1))
  suppressMessages(set_sdp_table(pkg, "spawners", description = "One row per stream."))
  expect_identical(
    vapply(targets, function(p) digest::digest(p, file = TRUE), character(1)),
    before
  )

  # The `observation_unit` placeholder is still there: only named fields move.
  tables <- read_meta(pkg, "tables.csv")
  expect_true(grepl("^MISSING METADATA", tables$observation_unit[[1]]))
})

test_that("set_sdp_column() names the disambiguating argument when a column repeats", {
  path <- file.path(withr::local_tempdir(), "two-tables")
  pkg <- suppressMessages(create_sdp(
    list(
      spawners = data.frame(count = 1:2),
      recruits = data.frame(count = 3:4)
    ),
    path = path, dataset_id = "demo-1", seed_semantics = FALSE,
    check_updates = FALSE, overwrite = TRUE
  ))

  expect_error(
    set_sdp_column(pkg, "count", column_description = "A count."),
    "matches 2 rows"
  )
  expect_no_error(suppressMessages(
    set_sdp_column(pkg, "count", table = "spawners", column_description = "A count.")
  ))
  # And the printed call carries `table =` for exactly this reason.
  calls <- printed_setter_calls(review_metadata(pkg))
  expect_true(all(grepl("table = ", calls[grepl("set_sdp_column", calls)], fixed = TRUE)))
})

test_that("a misspelled field is an error, not a silent no-op", {
  # The whole argument for checking `...` against the schema. A setter that
  # accepts `licence = "CC-BY-4.0"` and writes nothing is worse than one that
  # does not accept it at all: the caller believes the field is set.
  pkg <- setter_fixture_package()
  expect_error(set_sdp_dataset(pkg, licence = "CC-BY-4.0"), "no such field")
  expect_error(set_sdp_dataset(pkg, "CC-BY-4.0"), "must name the field")
  expect_error(set_sdp_dataset(pkg), "Nothing to set")
  expect_error(set_sdp_dataset(pkg, license = ""), "must not be blank")
})

test_that("a field that addresses the row cannot be set", {
  pkg <- setter_fixture_package()
  expect_error(set_sdp_table(pkg, "spawners", table_id = "other"), "cannot be set")
  expect_error(
    set_sdp_column(pkg, "spawner_count", table = "spawners", column_name = "renamed"),
    "cannot be set"
  )
})

test_that("any declared schema field is reachable through the dots", {
  # The named arguments are for discoverability, not for gatekeeping: the
  # schema is loaded at runtime and can gain fields this file has never heard
  # of, so re-spelling it as a fixed argument list would decay silently.
  pkg <- setter_fixture_package()
  suppressMessages(set_sdp_dataset(pkg, spatial_extent = "Fraser River", dataset_type = "monitoring"))
  dataset <- read_meta(pkg, "dataset.csv")
  expect_equal(dataset$spatial_extent, "Fraser River")
  expect_equal(dataset$dataset_type, "monitoring")
})

test_that("the setters refuse to write through a symlinked metadata directory", {
  skip_on_os("windows")
  pkg <- setter_fixture_package()
  real_metadata <- file.path(pkg, "metadata")
  moved <- file.path(dirname(pkg), "elsewhere-metadata")
  file.rename(real_metadata, moved)
  file.symlink(moved, real_metadata)

  expect_error(
    set_sdp_dataset(pkg, creator = "Someone"),
    "symbolic-link path component"
  )
})

test_that("an abort during the write leaves the package wholly unchanged", {
  pkg <- setter_fixture_package()
  descriptor_path <- file.path(pkg, "datapackage.json")
  dataset_path <- file.path(pkg, "metadata", "dataset.csv")
  writeLines("{ this is not json", descriptor_path)

  before <- vapply(
    c(dataset_path, descriptor_path),
    function(p) digest::digest(p, file = TRUE),
    character(1)
  )
  expect_error(set_sdp_dataset(pkg, creator = "Someone"), "datapackage.json")
  expect_identical(
    vapply(c(dataset_path, descriptor_path), function(p) digest::digest(p, file = TRUE), character(1)),
    before
  )
})

test_that("`.ms_required_metadata_fields()` reads the schema, not a hand-written list", {
  # First consumer of `field$requirement`, which had five producers and no
  # consumers. If this ever stops reading the schema the round trip above still
  # passes, so the source is asserted directly.
  expect_setequal(
    .ms_required_metadata_fields("dataset.csv"),
    c("title", "description", "creator", "contact_name", "contact_email", "license")
  )
  expect_setequal(
    .ms_required_metadata_fields("tables.csv"),
    c("table_label", "description")
  )
  expect_true("column_description" %in% .ms_required_metadata_fields("column_dictionary.csv"))
  # The keys are excluded because they address the row rather than describe it.
  expect_false(any(
    c("dataset_id", "table_id", "column_name") %in%
      .ms_required_metadata_fields("column_dictionary.csv")
  ))
})

test_that(".ms_is_unfilled_metadata() answers all three ways of being unfilled", {
  expect_equal(
    .ms_is_unfilled_metadata(c(NA, "", "   ", "MISSING METADATA: add it.", "a real value")),
    c(TRUE, TRUE, TRUE, TRUE, FALSE)
  )
})

test_that("the console prints external text literally rather than as a cli template", {
  # The same pinned contract as `R/review-console.R`: these lines carry
  # placeholder text and schema descriptions verbatim, `print()` emits them
  # with `cat()`, and escaping them would print `{{reach}}` for `{reach}`.
  pkg <- setter_fixture_package()
  suppressMessages(set_sdp_column(
    pkg, "stream_name", table = "spawners",
    column_description = "REVIEW REQUIRED: name of the {reach} it drains"
  ))
  lines <- .ms_metadata_render_lines(review_metadata(pkg))
  expect_true(any(grepl("{reach}", lines, fixed = TRUE)))
  expect_false(any(grepl("{{reach}}", lines, fixed = TRUE)))
})

test_that("review_metadata() reports a fully filled package as finished", {
  pkg <- setter_fixture_package()
  for (call_text in fill_templates(printed_setter_calls(review_metadata(pkg)))) {
    suppressMessages(eval(parse(text = call_text), envir = list2env(list(pkg = pkg))))
  }
  review <- review_metadata(pkg)
  expect_equal(nrow(review), 0L)
  lines <- .ms_metadata_render_lines(review)
  expect_true(any(grepl("No outstanding metadata.", lines, fixed = TRUE)))
})

test_that("review_metadata() reports a required column the file does not have, and its call fills it", {
  # Codex review of #111. The gap scan ran over `intersect(required,
  # names(frame))`, so a schema-required column missing from the file was not
  # a gap -- while the validator, after the same review, refuses it. The two
  # read one schema parse precisely so they cannot disagree about what blocks;
  # a column the file does not have is blank in every row for both. The
  # printed call is executed, as this file's header demands: `set_sdp_*()`
  # adds the column it is asked to write.
  pkg <- setter_fixture_package()
  for (call_text in fill_templates(printed_setter_calls(review_metadata(pkg)))) {
    suppressMessages(eval(parse(text = call_text), envir = list2env(list(pkg = pkg))))
  }
  expect_equal(nrow(review_metadata(pkg)), 0L)

  drop_column <- function(file_name, column) {
    meta <- read_meta(pkg, file_name)
    meta[[column]] <- NULL
    readr::write_csv(meta, file.path(pkg, "metadata", file_name), na = "")
  }
  drop_column("dataset.csv", "contact_email")
  drop_column("tables.csv", "table_label")
  drop_column("tables.csv", "observation_unit_iri")

  review <- review_metadata(pkg)
  expect_setequal(
    paste(review$file, review$field, review$reason),
    c(
      "dataset.csv contact_email required",
      "tables.csv table_label required",
      "tables.csv observation_unit_iri iri"
    )
  )
  expect_error(
    suppressWarnings(suppressMessages(validate_salmon_datapackage(pkg, require_iris = TRUE))),
    "contact_email"
  )

  for (call_text in fill_templates(printed_setter_calls(review))) {
    suppressMessages(eval(parse(text = call_text), envir = list2env(list(pkg = pkg))))
  }
  expect_true(all(c("contact_email") %in% names(read_meta(pkg, "dataset.csv"))))
  expect_true(all(c("table_label", "observation_unit_iri") %in% names(read_meta(pkg, "tables.csv"))))
  expect_equal(nrow(review_metadata(pkg)), 0L)
  expect_no_error(suppressMessages(validate_salmon_datapackage(pkg, require_iris = TRUE)))
})

test_that("review_metadata() refuses a path that is not a package directory", {
  expect_error(review_metadata(tempfile()), "existing Salmon Data Package")
  expect_error(set_sdp_dataset(tempfile(), creator = "x"), "existing Salmon Data Package")
})

test_that("a codes.csv gap prints a set_sdp_code() call that fills it", {
  # `codes.csv` is addressed by one more key than the others (`code_value`), so
  # it is the case where the printed call is most likely to under-address a row
  # and hit the wrong one -- or none.
  path <- file.path(withr::local_tempdir(), "coded")
  pkg <- suppressMessages(create_sdp(
    list(spawners = data.frame(
      stream_name = c("Bear Creek", "Elk River"),
      species = factor(c("CO", "CK")),
      spawner_count = c(120L, 340L),
      stringsAsFactors = FALSE
    )),
    path = path, dataset_id = "demo-1", seed_semantics = FALSE,
    check_updates = FALSE, overwrite = TRUE
  ))

  codes_path <- file.path(pkg, "metadata", "codes.csv")
  codes <- read_meta(pkg, "codes.csv")
  row <- which(codes$column_name == "species")[[1]]
  codes$code_description[[row]] <- "MISSING DESCRIPTION: say what this code means."
  readr::write_csv(codes, codes_path, na = "")

  review <- review_metadata(pkg)
  gap <- review[review$file == "codes.csv", , drop = FALSE]
  expect_equal(nrow(gap), 1L)
  expect_equal(gap$code_value[[1]], codes$code_value[[row]])

  calls <- printed_setter_calls(review)
  code_call <- calls[grepl("set_sdp_code(", calls, fixed = TRUE)]
  expect_length(code_call, 1L)
  suppressMessages(eval(
    parse(text = gsub("\"<[^\"]*>\"", "\"Coho salmon.\"", code_call)),
    envir = list2env(list(pkg = pkg))
  ))

  expect_equal(read_meta(pkg, "codes.csv")$code_description[[row]], "Coho salmon.")
  expect_equal(sum(review_metadata(pkg)$file == "codes.csv"), 0L)
})

# ---------------------------------------------------------------------------
# Draft `REVIEW:` IRIs (hub item B-174)
# ---------------------------------------------------------------------------
#
# The scan's contract is that when the last row it prints is gone, strict
# validation passes. An unresolved `REVIEW:` IRI broke it in released 0.5.0:
# the prose test cannot see the marker, so `review_metadata()` printed "No
# outstanding metadata." for a package
# `validate_salmon_datapackage(require_iris = TRUE)` then refused -- the state
# a user reaches by leaving any part of the semantic review undecided. These
# tests drive the validator itself rather than asserting on printed text.

# A package with a codes.csv, filled by executing `review_metadata()`'s own
# printed calls. That it then passes strict validation is asserted here, so a
# fixture that stops passing fails loudly instead of making every marker test
# below vacuous. The codes are what let those tests ask about every metadata
# file, not only the three a plain package has rows in.
filled_coded_package <- function(name = "filled-coded") {
  path <- file.path(withr::local_tempdir(.local_envir = parent.frame()), name)
  pkg <- suppressMessages(create_sdp(
    list(spawners = data.frame(
      stream_name = c("Bear Creek", "Elk River"),
      species = factor(c("CO", "CK")),
      spawner_count = c(120L, 340L),
      stringsAsFactors = FALSE
    )),
    path = path, dataset_id = "demo-1", seed_semantics = FALSE,
    check_updates = FALSE, overwrite = TRUE
  ))
  for (call_text in fill_templates(printed_setter_calls(review_metadata(pkg)))) {
    suppressMessages(eval(parse(text = call_text), envir = list2env(list(pkg = pkg))))
  }
  expect_equal(nrow(review_metadata(pkg)), 0L)
  expect_no_error(suppressMessages(validate_salmon_datapackage(pkg, require_iris = TRUE)))
  pkg
}

# Write `value` into one field of one row of a metadata CSV, adding the column
# when the file does not have it. Returns the bytes it replaced.
mark_metadata_field <- function(pkg, file_name, field, row, value) {
  csv <- file.path(pkg, "metadata", file_name)
  original <- readBin(csv, "raw", file.info(csv)$size)
  meta <- read_meta(pkg, file_name)
  if (!field %in% names(meta)) {
    meta[[field]] <- NA_character_
  }
  meta[[field]][[row]] <- value
  readr::write_csv(meta, csv, na = "")
  original
}

# Does strict validation refuse the package BECAUSE of a `REVIEW:` marker?
# Refusal for any other reason is an error here rather than a `TRUE`, so a
# fixture that broke for an unrelated reason cannot pass for a refused marker.
# The two phrases are the two sweeps: `.ms_collect_review_iri_issues()` for
# `tables.csv` and `validate_dictionary()` for the dictionary.
refuses_review_marker <- function(pkg) {
  outcome <- tryCatch(
    {
      suppressWarnings(suppressMessages(
        validate_salmon_datapackage(pkg, require_iris = TRUE)
      ))
      NULL
    },
    error = function(error) gsub("\\s+", " ", conditionMessage(error))
  )
  if (is.null(outcome)) {
    return(FALSE)
  }
  if (grepl("still contains a REVIEW-prefixed IRI|while REVIEW-prefixed IRI values remain", outcome)) {
    return(TRUE)
  }
  stop("strict validation refused the package for another reason: ", outcome, call. = FALSE)
}

test_that("review_metadata() reports a REVIEW: IRI exactly where strict validation refuses one", {
  pkg <- filled_coded_package()
  mark <- "REVIEW:https://example.org/Undecided"

  # Every expectation is written out rather than read from
  # `.ms_review_iri_files()`: a test comparing the scan against the list the
  # scan is built from passes for any value of that list, which is no test at
  # all. `refused` is what `validate_salmon_datapackage(require_iris = TRUE)`
  # does with a marker in that field; `reported` is whether the scan lists it.
  expected <- tibble::tribble(
    ~file,                   ~field,                     ~refused, ~reported,
    "tables.csv",            "observation_unit_iri",     TRUE,     TRUE,
    "tables.csv",            "protocol_iri",             TRUE,     TRUE,
    "tables.csv",            "method_iri",               TRUE,     TRUE,
    "column_dictionary.csv", "term_iri",                 TRUE,     TRUE,
    "column_dictionary.csv", "property_iri",             TRUE,     TRUE,
    "column_dictionary.csv", "entity_iri",               TRUE,     TRUE,
    "column_dictionary.csv", "unit_iri",                 TRUE,     TRUE,
    "column_dictionary.csv", "constraint_iri",           TRUE,     TRUE,
    "column_dictionary.csv", "statistical_modifier_iri", TRUE,     TRUE,
    # Strict validation does not sweep these two files for the marker (hub
    # item B-177), so reporting one would claim a block that does not exist.
    # If one of these rows starts failing because strict validation now
    # refuses the marker, that is B-177 landing: move `.ms_review_iri_files()`
    # with it and flip both columns, rather than deleting the row.
    "codes.csv",             "term_iri",                 FALSE,    FALSE,
    "codes.csv",             "vocabulary_iri",           FALSE,    FALSE,
    "dataset.csv",           "protocol_iri",             FALSE,    FALSE
  )

  # Coverage comes from the schema, so a newly declared IRI field fails here
  # until somebody writes down what strict validation does with it.
  declared <- unlist(lapply(names(.ms_metadata_schema_tables()), function(file_name) {
    fields <- purrr::map_chr(.ms_metadata_schema_fields(file_name), "name")
    paste(file_name, grep("_iri$", fields, value = TRUE))
  }))
  expect_setequal(paste(expected$file, expected$field), declared)

  # The dictionary marker goes on a CATEGORICAL row on purpose: the validator
  # refuses a marker whatever the column's role, and the measurement-IRI branch
  # of the scan never visits this row, so only the marker test can find it.
  dictionary <- read_meta(pkg, "column_dictionary.csv")
  dictionary_row <- which(dictionary$column_name == "stream_name")
  expect_identical(dictionary$column_role[[dictionary_row]], "categorical")

  for (i in seq_len(nrow(expected))) {
    file_name <- expected$file[[i]]
    field <- expected$field[[i]]
    label <- paste0(file_name, "$", field)
    row <- if (identical(file_name, "column_dictionary.csv")) dictionary_row else 1L

    original <- mark_metadata_field(pkg, file_name, field, row, mark)
    refused <- refuses_review_marker(pkg)
    review <- review_metadata(pkg)
    writeBin(original, file.path(pkg, "metadata", file_name))

    hit <- review[review$file == file_name & review$field == field, , drop = FALSE]
    expect_identical(refused, expected$refused[[i]], info = label)
    expect_identical(nrow(hit) > 0L, expected$reported[[i]], info = label)
    # The contract itself, which has to hold whatever the table says.
    expect_identical(nrow(hit) > 0L, refused, info = label)
    # Nothing else is reported: the marker is the package's only gap.
    expect_identical(nrow(review), nrow(hit), info = label)
    if (nrow(hit) > 0L) {
      expect_identical(nrow(hit), 1L, info = label)
      expect_identical(hit$reason[[1]], "iri", info = label)
      # The draft is shown, so the reader sees there is something to decide
      # rather than something to invent.
      expect_identical(hit$current_value[[1]], mark, info = label)
    }
  }
})

test_that("a package whose only gap is a REVIEW: IRI reaches strict validation through the printed call", {
  # Hub item B-174 as it was measured: one marker on `constraint_iri`, which
  # is neither schema-required nor a measurement IRI, so no branch of the scan
  # visited it with a test that could see the marker.
  pkg <- filled_coded_package()
  dictionary <- read_meta(pkg, "column_dictionary.csv")
  row <- which(dictionary$column_name == "spawner_count")
  mark_metadata_field(
    pkg, "column_dictionary.csv", "constraint_iri", row,
    "REVIEW:https://example.org/Undecided"
  )
  expect_true(refuses_review_marker(pkg))

  review <- review_metadata(pkg)
  expect_identical(
    paste(review$file, review$column_name, review$field, review$reason),
    "column_dictionary.csv spawner_count constraint_iri iri"
  )
  lines <- .ms_metadata_render_lines(review)
  expect_false(any(grepl("No outstanding metadata.", lines, fixed = TRUE)))

  # The printed call is executed, as this file's header demands.
  calls <- printed_setter_calls(review)
  expect_length(calls, 1L)
  suppressMessages(eval(
    parse(text = gsub(
      "<IRI for constraint_iri>", "https://example.org/DecidedConstraint", calls,
      fixed = TRUE
    )),
    envir = list2env(list(pkg = pkg))
  ))

  expect_equal(nrow(review_metadata(pkg)), 0L)
  expect_false(refuses_review_marker(pkg))
})

test_that("a REVIEW: measurement IRI is reported once, and its call runs", {
  # The marker test runs in the scan's main loop and the measurement branch
  # keeps the prose test, so a marked measurement IRI is found by one of them
  # and not both. Reported twice, the printed call would name the argument
  # twice and could not run -- so the call is run, all four fields at once.
  pkg <- filled_coded_package()
  dictionary <- read_meta(pkg, "column_dictionary.csv")
  row <- which(dictionary$column_name == "spawner_count")
  expect_identical(dictionary$column_role[[row]], "measurement")
  for (field in .ms_measurement_iri_fields()) {
    mark_metadata_field(
      pkg, "column_dictionary.csv", field, row,
      paste0("REVIEW:", dictionary[[field]][[row]])
    )
  }
  mark_metadata_field(
    pkg, "tables.csv", "observation_unit_iri", 1L,
    "REVIEW:https://example.org/Undecided"
  )
  expect_true(refuses_review_marker(pkg))

  review <- review_metadata(pkg)
  expect_setequal(
    paste(review$file, review$field, review$reason),
    c(
      paste("column_dictionary.csv", .ms_measurement_iri_fields(), "iri"),
      "tables.csv observation_unit_iri iri"
    )
  )
  expect_equal(nrow(review), 5L)

  for (call_text in fill_templates(printed_setter_calls(review))) {
    suppressMessages(eval(parse(text = call_text), envir = list2env(list(pkg = pkg))))
  }
  expect_equal(nrow(review_metadata(pkg)), 0L)
  expect_false(refuses_review_marker(pkg))
})

# Three ways to leave `tables.csv`'s `observation_unit_iri` and a measurement
# column's `unit_iri` unfilled: the value planted in each, and the one reason
# the scan must give for each field.
unfilled_iri_states <- list(
  # Reported by the field loop, which reports a placeholder in any field.
  "prose placeholder" = list(
    observation_unit_iri = "MISSING METADATA: add the observation unit IRI.",
    unit_iri = "REVIEW REQUIRED: pick a unit.",
    reason = "placeholder"
  ),
  # What the observation-unit and measurement-IRI branches exist to catch.
  "blank" = list(
    observation_unit_iri = NA_character_,
    unit_iri = NA_character_,
    reason = "iri"
  ),
  # Reported by the field loop's marker branch.
  "REVIEW: marker" = list(
    observation_unit_iri = "REVIEW:https://example.org/Undecided",
    unit_iri = "REVIEW:https://example.org/Undecided",
    reason = "iri"
  )
)

# Fill every `*_iri` template in a printed call with an IRI, whatever its hint
# says, and every other template as `fill_templates()` does. A placeholder's
# hint is its own text, which `fill_templates()` would fill with prose.
fill_iri_templates <- function(call_text) {
  fill_templates(gsub(
    "([a-z_]+_iri) = \"<[^\"]*>\"", "\\1 = \"https://example.org/Decided\"",
    call_text
  ))
}

for (state in names(unfilled_iri_states)) {
  test_that(paste0("an unfilled IRI field is reported once, and its call runs: ", state), {
    # One field, one gap row, one argument in the printed call (hub B-211;
    # metasalmonpy's half is B-212). A prose placeholder in
    # `observation_unit_iri` or a measurement IRI was reported twice: as a
    # placeholder by the field loop, then as an IRI by the branch for that
    # field, whose prose test counts a placeholder as unfilled too. The printed
    # `set_sdp_table()` and `set_sdp_column()` calls then named the field twice,
    # and R refuses a formal argument matched by two actual arguments. The
    # blank and `REVIEW:` states are the ones the fix must not disturb: those
    # branches exist to catch a blank field, and the loop reports a marker once.
    planted <- unfilled_iri_states[[state]]
    pkg <- filled_coded_package()
    dictionary <- read_meta(pkg, "column_dictionary.csv")
    row <- which(dictionary$column_name == "spawner_count")
    expect_identical(dictionary$column_role[[row]], "measurement")
    mark_metadata_field(pkg, "tables.csv", "observation_unit_iri", 1L, planted$observation_unit_iri)
    mark_metadata_field(pkg, "column_dictionary.csv", "unit_iri", row, planted$unit_iri)

    review <- review_metadata(pkg)
    expect_identical(
      sort(paste(review$file, review$field, review$reason)),
      sort(c(
        paste("column_dictionary.csv unit_iri", planted$reason),
        paste("tables.csv observation_unit_iri", planted$reason)
      ))
    )
    expect_identical(
      review$column_name[review$file == "column_dictionary.csv"],
      "spawner_count"
    )

    # Run what was printed: a call naming an argument twice fails here.
    for (call_text in fill_iri_templates(printed_setter_calls(review))) {
      suppressMessages(eval(parse(text = call_text), envir = list2env(list(pkg = pkg))))
    }
    expect_equal(nrow(review_metadata(pkg)), 0L)
    expect_no_error(suppressMessages(
      validate_salmon_datapackage(pkg, require_iris = TRUE)
    ))
  })
}

test_that("a field two checks both find is reported once: a required IRI a configured schema declares", {
  # The rule behind the tests above is one gap row per field of a metadata
  # row, whichever checks find it, so it closes a second route to the same
  # broken call. Under a schema selected through the options that calls
  # `unit_iri` required, a blank one on a measurement row came back from the
  # field loop as `required` and from the measurement-IRI branch as `iri`. No
  # shipped schema calls an IRI field required. metasalmonpy has the same rule
  # (hub B-212) and measured this route there, but its suite does not pin it.
  pkg <- filled_coded_package()
  table_name <- .ms_metadata_schema_tables()[["column_dictionary.csv"]]
  configured <- .ms_vendored_sdp_schema()
  declared <- purrr::map_chr(configured$metadata_tables[[table_name]]$fields, "name")
  at <- which(declared == "unit_iri")
  configured$metadata_tables[[table_name]]$fields[[at]]$requirement <- "required"
  # A non-default source makes every reader go through the loader, which is
  # how a selected schema reaches the scan, the setters and the validator.
  withr::local_options(metasalmon.sdp_schema_source = "remote")
  local_mocked_bindings(.ms_load_sdp_schema = function(...) configured)
  # The configuration took; without this the assertions below are vacuous.
  expect_true("unit_iri" %in% .ms_required_metadata_fields("column_dictionary.csv"))

  dictionary <- read_meta(pkg, "column_dictionary.csv")
  row <- which(dictionary$column_name == "spawner_count")
  expect_identical(dictionary$column_role[[row]], "measurement")
  mark_metadata_field(pkg, "column_dictionary.csv", "unit_iri", row, NA_character_)

  review <- review_metadata(pkg)
  measured <- review[review$column_name %in% "spawner_count" & review$field == "unit_iri", ]
  expect_identical(measured$reason, "required")

  for (call_text in fill_iri_templates(printed_setter_calls(review))) {
    suppressMessages(eval(parse(text = call_text), envir = list2env(list(pkg = pkg))))
  }
  expect_false("unit_iri" %in% review_metadata(pkg)$field)
})

test_that("the REVIEW: marker has its own predicate, and the prose ones stay narrow", {
  values <- c(
    "REVIEW:https://example.org/Thing",
    "  review : https://example.org/Thing",
    "https://example.org/Thing",
    NA,
    "",
    "MISSING METADATA: add it.",
    "REVIEW REQUIRED: confirm it."
  )
  expect_identical(
    .ms_is_unresolved_iri(values),
    c(TRUE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE)
  )
  # Widening either prose test instead would have pushed the marker into
  # strict validation's placeholder sweep, which would then refuse it as
  # prose -- in `dataset.csv` and `codes.csv` too, which strict validation does
  # not sweep for the marker today. That scope is interim rather than chosen:
  # hub item B-177 widens it, and moves `.ms_review_iri_files()` in the same
  # change. The marker would also have reached the hint `.ms_metadata_gap_row()`
  # builds from a value's own text.
  expect_identical(
    .ms_is_unfilled_metadata(values),
    c(FALSE, FALSE, FALSE, TRUE, TRUE, TRUE, TRUE)
  )
  expect_false(.ms_is_review_placeholder("REVIEW:https://example.org/Thing"))
})

test_that("an undeclared *_iri column carrying a REVIEW: marker is still missed", {
  # A KNOWN GAP, pinned so it is visible rather than latent: hub item B-185.
  # `.ms_collect_review_iri_issues()` sweeps every column of `tables.csv` whose
  # name ends in `_iri`, declared or not. The scan reads schema-declared fields
  # only, because every row it prints must be a runnable `set_sdp_*()` call and
  # the setters refuse a field the schema does not declare. Closing it means
  # printing a call that cannot run or letting a setter write an undeclared
  # field, which is a ruling about the printed-call contract and not about any
  # predicate. metasalmonpy pins the same gap in
  # `test_an_undeclared_iri_column_is_still_missed`.
  #
  # Retires when B-185 is ruled and the scan and the validator agree about
  # undeclared `*_iri` columns. Delete this test in that change: it asserts the
  # defect, so it fails when the defect is fixed.
  pkg <- filled_coded_package()
  mark_metadata_field(
    pkg, "tables.csv", "custom_thing_iri", 1L,
    "REVIEW:https://example.org/HandAdded"
  )
  expect_equal(nrow(review_metadata(pkg)), 0L)
  expect_true(refuses_review_marker(pkg))
})

test_that("a dictionary IRI field a configured schema adds is listed only if strict validation refuses its marker", {
  # Raised in the Codex review of #144. A schema selected through the options
  # can declare an `*_iri` field on `column_dictionary.csv` beyond the bundled
  # six, and the scan reads the selected schema (B-175). `validate_dictionary()`
  # sweeps a fixed six, so a marker in the added field passes strict
  # validation, and listing it would claim a block that does not exist -- the
  # same class of error as missing one. `tables.csv` has no such case: its
  # sweep takes every `*_iri` column, so any field declared there is swept.
  pkg <- filled_coded_package()
  table_name <- .ms_metadata_schema_tables()[["column_dictionary.csv"]]
  extended <- .ms_vendored_sdp_schema()
  extended$metadata_tables[[table_name]]$fields <- c(
    extended$metadata_tables[[table_name]]$fields,
    list(list(
      name = "extension_iri", type = "string", requirement = "optional",
      description = "A dictionary IRI field that only this test's schema declares."
    ))
  )
  # A non-default source makes every reader go through the loader, which is
  # how a selected schema reaches the scan, the setters and the validator.
  withr::local_options(metasalmon.sdp_schema_source = "remote")
  local_mocked_bindings(.ms_load_sdp_schema = function(...) extended)
  # The configuration took; without this the assertions below are vacuous.
  expect_true(
    "extension_iri" %in%
      purrr::map_chr(.ms_metadata_schema_fields("column_dictionary.csv"), "name")
  )

  dictionary <- read_meta(pkg, "column_dictionary.csv")
  row <- which(dictionary$column_name == "stream_name")
  mark <- "REVIEW:https://example.org/Undecided"

  # The field the configured schema adds: strict validation accepts the
  # marker, so the scan does not list it.
  original <- mark_metadata_field(pkg, "column_dictionary.csv", "extension_iri", row, mark)
  expect_false(refuses_review_marker(pkg))
  expect_equal(nrow(review_metadata(pkg)), 0L)
  writeBin(original, file.path(pkg, "metadata", "column_dictionary.csv"))

  # One of the six, under the same configured schema: refused, so listed. The
  # restriction must not cost the fields strict validation does sweep.
  mark_metadata_field(pkg, "column_dictionary.csv", "constraint_iri", row, mark)
  expect_true(refuses_review_marker(pkg))
  review <- review_metadata(pkg)
  expect_identical(paste(review$file, review$field), "column_dictionary.csv constraint_iri")
})
