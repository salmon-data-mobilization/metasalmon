# The package-ownership sentinel is ONE file shared by both implementations
# (hub item B-113). Brett ruled Q14 on 2026-08-24: "I want one share sentinel
# name. Nobody uses this yet so dont worry about breaking changes." So
# metasalmon and metasalmonpy write and recognise the same file name and the
# same content line, the break for packages carrying only a per-language
# sentinel is accepted, and neither writer removes the other's file.
#
# The name and content line are recorded in knowledge/parity-deviations.md row
# 51, and metasalmonpy's half (hub item B-127) takes both from that row. The
# two literals below are therefore a cross-repository contract: change them
# only together with row 51 and the mirror. They are spelled out rather than
# read back from `.ms_package_sentinel_file()` and
# `.ms_package_ownership_bytes()`, because a pin that reads the value it pins
# passes whatever the value is.

shared_sentinel_name <- ".sdp-package"
shared_sentinel_bytes <- charToRaw("sdp-owned\n")
per_language_sentinels <- c(
  ".metasalmon-package" = "metasalmon-owned",
  ".metasalmonpy-package" = "metasalmonpy-owned"
)

.ms_test_sentinel_artifacts <- function() {
  list(
    resources = list(main_table = tibble::tibble(x = 1)),
    dataset_meta = tibble::tibble(
      dataset_id = "sentinel-1",
      title = "Sentinel",
      description = "Ownership sentinel",
      creator = NA_character_,
      contact_name = NA_character_,
      contact_email = NA_character_,
      license = NA_character_,
      temporal_start = NA_character_,
      temporal_end = NA_character_,
      spatial_extent = NA_character_,
      dataset_type = NA_character_,
      source_citation = NA_character_
    ),
    table_meta = tibble::tibble(
      dataset_id = "sentinel-1",
      table_id = "main_table",
      file_name = "data/main_table.csv",
      table_label = "Main",
      description = NA_character_,
      observation_unit = NA_character_,
      observation_unit_iri = NA_character_,
      primary_key = NA_character_
    ),
    dict = fill_measurement_components(
      infer_dictionary(
        tibble::tibble(x = 1),
        dataset_id = "sentinel-1",
        table_id = "main_table"
      )
    )
  )
}

.ms_test_write_sentinel_package <- function(path, ...) {
  a <- .ms_test_sentinel_artifacts()
  write_salmon_datapackage(
    a$resources, a$dataset_meta, a$table_meta, a$dict,
    path = path, ...
  )
}

.ms_test_file_bytes <- function(path) {
  readBin(path, what = "raw", n = file.info(path)$size)
}

test_that("the ownership sentinel is the one shared file name and content line", {
  expect_identical(basename(.ms_package_sentinel_file("pkg")), shared_sentinel_name)
  expect_identical(.ms_package_ownership_bytes(), shared_sentinel_bytes)

  target <- file.path(withr::local_tempdir(), "pkg")
  .ms_test_write_sentinel_package(target)

  # The bytes a real write puts on disk, not only what the helper returns.
  sentinel <- file.path(target, shared_sentinel_name)
  expect_true(file.exists(sentinel))
  expect_identical(.ms_test_file_bytes(sentinel), shared_sentinel_bytes)

  # No per-language sentinel is written. Listing every dot-file at the package
  # root catches one under any name, not only under the two old ones.
  expect_identical(
    list.files(target, pattern = "^[.]", all.files = TRUE, no.. = TRUE),
    shared_sentinel_name
  )
})

test_that("a directory carrying only the shared sentinel is recognised as owned", {
  target <- file.path(withr::local_tempdir(), "sentinel-only")
  dir.create(target)
  # Written by hand rather than by this package, as a package metasalmonpy
  # wrote would arrive: nothing here but the shared file.
  writeBin(shared_sentinel_bytes, file.path(target, shared_sentinel_name))

  expect_true(.ms_is_metasalmon_package_dir(target))

  # Recognised means `overwrite = TRUE` may replace it: without the sentinel
  # this directory holds no SDP CSVs, and the write would be refused.
  expect_no_error(.ms_test_write_sentinel_package(target, overwrite = TRUE))
  expect_equal(read_salmon_datapackage(target)$dataset$dataset_id[[1]], "sentinel-1")
  expect_identical(
    .ms_test_file_bytes(file.path(target, shared_sentinel_name)),
    shared_sentinel_bytes
  )
})

test_that("a directory carrying only a per-language sentinel is not recognised as owned", {
  # The compatibility break Q14 accepted. A package that still has its SDP CSVs
  # is recognised by them, so this refuses only a directory whose sole claim to
  # being a package is an old sentinel.
  for (legacy in names(per_language_sentinels)) {
    target <- file.path(withr::local_tempdir(), "legacy-only")
    dir.create(target)
    writeLines(per_language_sentinels[[legacy]], file.path(target, legacy))

    expect_false(.ms_is_metasalmon_package_dir(target), info = legacy)
    expect_error(
      .ms_test_write_sentinel_package(target, overwrite = TRUE),
      "Refusing to overwrite non-metasalmon directory",
      info = legacy
    )
    expect_identical(
      list.files(target, all.files = TRUE, no.. = TRUE),
      legacy,
      info = legacy
    )
  }
})

test_that("the managed-path inventory names only the shared sentinel, so a rewrite keeps an old one", {
  target <- file.path(withr::local_tempdir(), "pkg")
  .ms_test_write_sentinel_package(target)
  for (legacy in names(per_language_sentinels)) {
    writeLines(per_language_sentinels[[legacy]], file.path(target, legacy))
  }

  managed <- basename(.ms_package_managed_paths(target))
  expect_true(shared_sentinel_name %in% managed)
  expect_false(any(names(per_language_sentinels) %in% managed))

  # An unmanaged file survives a rewrite, so both old sentinels stay exactly as
  # they were. Q14 rules out either writer removing the other's file, and
  # removing or renaming one would be a migration nobody ruled.
  .ms_test_write_sentinel_package(target, overwrite = TRUE)
  for (legacy in names(per_language_sentinels)) {
    expect_identical(
      readLines(file.path(target, legacy)),
      per_language_sentinels[[legacy]],
      info = legacy
    )
  }
  expect_identical(
    .ms_test_file_bytes(file.path(target, shared_sentinel_name)),
    shared_sentinel_bytes
  )
})
