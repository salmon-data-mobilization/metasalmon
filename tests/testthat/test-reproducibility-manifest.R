make_reproducibility_test_sdp <- function(path) {
  dir.create(
    file.path(path, "reproducibility", "workflow"),
    recursive = TRUE,
    showWarnings = FALSE
  )
  dir.create(
    file.path(path, "reproducibility", "provenance"),
    recursive = TRUE,
    showWarnings = FALSE
  )
  dir.create(
    file.path(path, "reproducibility", "source"),
    recursive = TRUE,
    showWarnings = FALSE
  )
  writeLines("dataset_id,column_name\nfraser,recruits", file.path(
    path,
    "reproducibility",
    "reviewed_semantic_selections.csv"
  ))
  writeLines("message('transform')", file.path(
    path,
    "reproducibility",
    "workflow",
    "transform.R"
  ))
  writeLines("activity_id,started_at\ntransform,2026-08-04", file.path(
    path,
    "reproducibility",
    "provenance",
    "activities.csv"
  ))
  writeLines("path,sha256\nsource.csv,abc", file.path(
    path,
    "reproducibility",
    "source",
    "source-manifest.csv"
  ))
  invisible(path)
}

reproducibility_test_artifacts <- function() {
  tibble::tribble(
    ~path, ~role, ~media_type,
    "reproducibility/workflow/transform.R", "workflow", "text/x-r-source",
    "reproducibility/reviewed_semantic_selections.csv",
    "reviewed_semantic_selections", "text/csv",
    "reproducibility/source/source-manifest.csv", "source", "text/csv",
    "reproducibility/provenance/activities.csv", "provenance", "text/csv"
  )
}

test_that("reproducibility manifests bind a deterministic closed artifact set", {
  first <- make_reproducibility_test_sdp(withr::local_tempdir())
  second <- make_reproducibility_test_sdp(withr::local_tempdir())

  first_manifest <- write_sdp_reproducibility_manifest(
    first,
    reproducibility_test_artifacts()
  )
  second_manifest <- write_sdp_reproducibility_manifest(
    second,
    dplyr::slice_sample(reproducibility_test_artifacts(), prop = 1)
  )

  expect_identical(
    readBin(first_manifest, "raw", n = file.info(first_manifest)$size),
    readBin(second_manifest, "raw", n = file.info(second_manifest)$size)
  )
  manifest <- read_sdp_reproducibility_manifest(first)
  expect_identical(
    names(manifest),
    c("profile", "artifacts", "provenance")
  )
  expect_identical(
    purrr::map_chr(manifest$artifacts, "path"),
    sort(reproducibility_test_artifacts()$path)
  )
  expect_true(isTRUE(validate_sdp_reproducibility_manifest(first)))
})

test_that("reproducibility manifests reject unbound, changed, and unsafe files", {
  drift <- make_reproducibility_test_sdp(withr::local_tempdir())
  write_sdp_reproducibility_manifest(drift, reproducibility_test_artifacts())
  writeLines("changed", file.path(drift, "reproducibility", "workflow", "transform.R"))
  expect_error(
    validate_sdp_reproducibility_manifest(drift),
    "SHA-256|size"
  )

  unbound <- make_reproducibility_test_sdp(withr::local_tempdir())
  write_sdp_reproducibility_manifest(unbound, reproducibility_test_artifacts())
  writeLines("private note", file.path(unbound, "reproducibility", "private.txt"))
  expect_error(
    validate_sdp_reproducibility_manifest(unbound),
    "undeclared|closed"
  )

  wrong_role <- make_reproducibility_test_sdp(withr::local_tempdir())
  declarations <- reproducibility_test_artifacts()
  declarations$role[[1]] <- "source"
  expect_error(
    write_sdp_reproducibility_manifest(wrong_role, declarations),
    "role|location"
  )

  outside <- tempfile(fileext = ".R")
  writeLines("message('outside')", outside)
  linked <- make_reproducibility_test_sdp(withr::local_tempdir())
  unlink(file.path(linked, "reproducibility", "workflow", "transform.R"))
  expect_true(file.symlink(
    outside,
    file.path(linked, "reproducibility", "workflow", "transform.R")
  ))
  expect_error(
    write_sdp_reproducibility_manifest(linked, reproducibility_test_artifacts()),
    "symlink|unsafe"
  )
})

test_that("failed reproducibility-manifest overwrite preserves prior bytes", {
  root <- make_reproducibility_test_sdp(withr::local_tempdir())
  manifest_path <- write_sdp_reproducibility_manifest(
    root,
    reproducibility_test_artifacts()
  )
  before <- readBin(manifest_path, "raw", n = file.info(manifest_path)$size)
  incomplete <- reproducibility_test_artifacts()[-1, , drop = FALSE]

  expect_error(
    write_sdp_reproducibility_manifest(
      root,
      incomplete,
      overwrite = TRUE
    ),
    "undeclared|closed"
  )
  after <- readBin(manifest_path, "raw", n = file.info(manifest_path)$size)
  expect_identical(after, before)
  expect_true(isTRUE(validate_sdp_reproducibility_manifest(root)))
})

test_that("reproducibility APIs reject only a symlinked package root", {
  target <- make_reproducibility_test_sdp(withr::local_tempdir())
  trailing_target <- make_reproducibility_test_sdp(withr::local_tempdir())
  link_parent <- withr::local_tempdir()
  linked_root <- file.path(link_parent, "linked-sdp")
  trailing_linked_root <- file.path(link_parent, "trailing-linked-sdp")
  if (!file.symlink(target, linked_root)) {
    skip("Filesystem does not permit directory symlink creation")
  }
  if (!file.symlink(trailing_target, trailing_linked_root)) {
    skip("Filesystem does not permit directory symlink creation")
  }

  expect_error(
    write_sdp_reproducibility_manifest(
      linked_root,
      reproducibility_test_artifacts()
    ),
    "path.*symlink|unsafe"
  )
  expect_error(
    write_sdp_reproducibility_manifest(
      paste0(trailing_linked_root, "/"),
      reproducibility_test_artifacts()
    ),
    "path.*symlink|unsafe"
  )
  expect_false(file.exists(file.path(target, "reproducibility", "manifest.json")))
  expect_false(file.exists(file.path(
    trailing_target,
    "reproducibility",
    "manifest.json"
  )))

  expect_no_error(write_sdp_reproducibility_manifest(
    target,
    reproducibility_test_artifacts()
  ))
})

test_that("reproducibility manifest APIs are exported", {
  exports <- getNamespaceExports("metasalmon")
  expect_true(all(c(
    "write_sdp_reproducibility_manifest",
    "read_sdp_reproducibility_manifest",
    "validate_sdp_reproducibility_manifest"
  ) %in% exports))
})
