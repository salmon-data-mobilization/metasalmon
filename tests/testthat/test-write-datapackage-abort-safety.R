# An abort anywhere in `write_salmon_datapackage()` must leave the caller's
# previously valid package intact. Backlog #96's second half: PR #75 fixed the
# Date-vs-"" comparison that *triggered* an abort, but the write path still
# unlinked every managed path first and wrote replacements afterwards, so ANY
# abort in between -- a broken schema bundle, a serialization error, the next
# typed-column bug -- deleted `metadata/` and `datapackage.json` and left
# nothing in their place. The ordering is the defect class; these tests pin the
# ordering, not one trigger.
#
# The injection points are deliberately *after* the old destructive point
# (`.ms_prepare_package_write_dir()`'s unlink) and are mocked, not triggered by
# crafted inputs, so they stay valid when the individual input bugs are fixed.

.abort_safety_fixture <- function() {
  list(
    resources = list(
      obs = data.frame(site_id = c("s1", "s2"), stringsAsFactors = FALSE)
    ),
    dataset_meta = tibble::tibble(
      dataset_id = "d1",
      title = "Abort safety",
      description = "Regression for backlog #96, ordering half",
      creator = "metasalmon tests",
      license = "CC-BY-4.0",
      temporal_start = "2001-01-01",
      temporal_end = "2002-06-30"
    ),
    table_meta = tibble::tibble(
      dataset_id = "d1",
      table_id = "obs",
      file_name = "data/obs.csv",
      table_label = "Observations",
      description = "One site column"
    ),
    dict = tibble::tibble(
      dataset_id = "d1",
      table_id = "obs",
      column_name = "site_id",
      column_label = "Site",
      column_description = "Site identifier",
      column_role = "identifier",
      value_type = "string",
      required = FALSE
    )
  )
}

.write_abort_safety_package <- function(path, fixture, ...) {
  suppressMessages(write_salmon_datapackage(
    resources = fixture$resources,
    dataset_meta = fixture$dataset_meta,
    table_meta = fixture$table_meta,
    dict = fixture$dict,
    path = path,
    overwrite = TRUE,
    ...
  ))
}

# Every file in the package, hashed, so "intact" means byte-identical -- not
# merely "some file exists at that path".
.package_file_hashes <- function(path) {
  files <- sort(list.files(path, recursive = TRUE, all.files = TRUE, no.. = TRUE))
  hashes <- unname(tools::md5sum(file.path(path, files)))
  stats::setNames(hashes, files)
}

test_that("an abort after the old unlink point leaves the previous package byte-intact", {
  path <- withr::local_tempdir()
  fixture <- .abort_safety_fixture()
  .write_abort_safety_package(path, fixture)
  before <- .package_file_hashes(path)
  expect_true("datapackage.json" %in% names(before))

  # `.ms_sdp_metadata_resource_entries()` runs after the destructive point of
  # the pre-fix write path (managed paths unlinked, only data CSVs rewritten)
  # and nowhere earlier in the call, so an abort here destroyed metadata/ and
  # datapackage.json.
  expect_error(
    with_mocked_bindings(
      .ms_sdp_metadata_resource_entries = function(...) stop("injected post-unlink abort"),
      .write_abort_safety_package(path, fixture)
    ),
    "injected post-unlink abort"
  )

  expect_identical(.package_file_hashes(path), before)
  # Intact must also mean readable, not just present.
  expect_no_error(suppressMessages(read_salmon_datapackage(path)))
})

test_that("an abort while rendering a data resource leaves the previous package byte-intact", {
  path <- withr::local_tempdir()
  fixture <- .abort_safety_fixture()
  .write_abort_safety_package(path, fixture)
  before <- .package_file_hashes(path)

  # `.ms_meta_scalar_present()` runs for every resource inside the write loop
  # (table_label/description/primary_key presence) and nowhere before it -- in
  # the pre-fix ordering, after the unlink and before any metadata write. This
  # is also the exact helper PR #75 introduced: the fixed *comparison* now
  # lives at an unfixed *ordering* point, which is what made #96's second half
  # stay open.
  expect_error(
    with_mocked_bindings(
      .ms_meta_scalar_present = function(...) stop("injected resource-render abort"),
      .write_abort_safety_package(path, fixture)
    ),
    "injected resource-render abort"
  )

  expect_identical(.package_file_hashes(path), before)
  expect_no_error(suppressMessages(read_salmon_datapackage(path)))
})

test_that("with prune = TRUE, an input-dependent abort still leaves the package and sidecars intact", {
  # `prune = TRUE` accepted more deletion, not earlier deletion: the caller
  # asked to replace everything *with a successfully written package*. The
  # wipe must therefore run only after every input-dependent computation has
  # succeeded. (The residual prune window -- pure filesystem failure between
  # wipe and install -- is documented at `.ms_commit_package_write()`.)
  path <- withr::local_tempdir()
  fixture <- .abort_safety_fixture()
  .write_abort_safety_package(path, fixture)
  sidecar <- file.path(path, "README-review.txt")
  writeLines("reviewed content", sidecar)
  before <- .package_file_hashes(path)

  expect_error(
    with_mocked_bindings(
      .ms_sdp_metadata_resource_entries = function(...) stop("injected post-unlink abort"),
      .write_abort_safety_package(path, fixture, prune = TRUE)
    ),
    "injected post-unlink abort"
  )

  expect_identical(.package_file_hashes(path), before)
  expect_true(file.exists(sidecar))
  expect_no_error(suppressMessages(read_salmon_datapackage(path)))
})

test_that("a successful rewrite leaves no staging or backup scratch behind", {
  # The transactional install stages dot-prefixed siblings next to each target
  # and renames originals aside; success must clean up every one of them.
  path <- withr::local_tempdir()
  fixture <- .abort_safety_fixture()
  .write_abort_safety_package(path, fixture)
  .write_abort_safety_package(path, fixture)

  scratch <- list.files(
    path,
    pattern = "-(stage|backup)-",
    recursive = TRUE,
    all.files = TRUE
  )
  expect_identical(scratch, character(0))
})

test_that("the writer performs no direct filesystem mutation outside the commit step", {
  # Structural guard for the fix's ordering: `write_salmon_datapackage()`
  # renders the full write set to bytes and hands it to
  # `.ms_commit_package_write()`, the single place allowed to delete or
  # replace anything. A direct write/unlink/dir-mutation added back into the
  # writer body would reopen the destroy-on-abort window this file pins, while
  # every trigger-specific test above stayed green.
  #
  # Retires when: the write set is enforced by construction (e.g. the renderers
  # return into a builder that owns the only filesystem handle), making a
  # stray direct write in the writer body unrepresentable -- or when
  # `write_salmon_datapackage()` itself is replaced. Until then, keep the
  # token list in sync with R's filesystem-mutating vocabulary.
  writer_body <- paste(deparse(body(write_salmon_datapackage)), collapse = "\n")
  mutating_tokens <- c(
    "write_csv(", "write_json(", "writeLines(", "writeBin(",
    "unlink(", "file.rename(", "file.remove(", "file.copy(", "dir.create("
  )
  for (token in mutating_tokens) {
    expect_false(
      grepl(token, writer_body, fixed = TRUE),
      label = sprintf(
        "write_salmon_datapackage() body contains direct filesystem call %s",
        token
      )
    )
  }
})
