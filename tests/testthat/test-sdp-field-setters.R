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
