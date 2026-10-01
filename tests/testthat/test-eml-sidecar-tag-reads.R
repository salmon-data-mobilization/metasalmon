# Q62 / B-223: every EML and KNB read of the reviewed sidecar must refuse a
# local YAML tag. The three public paths below used to accept the tag's text.

b223_tag_eml_sidecar <- function(package_path, tag) {
  sidecar <- file.path(package_path, "metadata", "eml-mapping.yml")
  lines <- readLines(sidecar, encoding = "UTF-8")
  benign <-
    "- description: Counts were compiled using the documented monitoring workflow."
  hit <- which(lines == benign)
  stopifnot(length(hit) == 1L)
  lines[[hit]] <- paste("- description:", tag)
  writeLines(lines, sidecar, useBytes = TRUE)
  sidecar
}

b223_expr_tag <- function(root) {
  sentinel <- file.path(normalizePath(root, winslash = "/"), "evaluated")
  list(
    sentinel = sentinel,
    tag = sprintf('!expr file.create("%s")', sentinel)
  )
}

test_that("EML export refuses an unknown local tag in its sidecar", {
  # emld is checked before write_eml_from_sdp() reaches this YAML read.
  skip_if_not_installed("emld")
  package_path <- make_eml_test_sdp(withr::local_tempdir())
  sidecar <- b223_tag_eml_sidecar(package_path, "!unknown X")

  expect_error(
    suppressMessages(write_eml_from_sdp(package_path)),
    basename(sidecar),
    class = "metasalmon_eml_mapping_tag"
  )
})

test_that("KNB artifact inventory refuses an !expr tag without evaluating it", {
  root <- withr::local_tempdir()
  package_path <- make_knb_test_sdp(root)
  probe <- b223_expr_tag(root)
  sidecar <- b223_tag_eml_sidecar(package_path, probe$tag)
  withr::local_options(yaml.eval.expr = TRUE)

  expect_error(
    .ms_knb_sdp_artifact_paths(package_path),
    basename(sidecar),
    class = "metasalmon_eml_mapping_tag"
  )
  expect_false(file.exists(probe$sentinel))
})

test_that("KNB plan builder refuses a local tag before making an archive", {
  root <- withr::local_tempdir()
  package_path <- make_knb_test_sdp(root)
  sidecar <- b223_tag_eml_sidecar(package_path, "!unknown X")
  local_mocked_bindings(
    .ms_knb_write_sdp_archive = function(...) {
      stop(errorCondition(
        "Stopped after the plan builder sidecar read.",
        class = "b223_after_sidecar_read"
      ))
    },
    .package = "metasalmon"
  )

  result <- tryCatch(
    suppressMessages(publish_sdp_to_knb(
      package_path,
      public = TRUE,
      dry_run = TRUE,
      knb_environment = "production"
    )),
    error = identity
  )
  expect_s3_class(result, "metasalmon_eml_mapping_tag")
  if (inherits(result, "metasalmon_eml_mapping_tag")) {
    expect_match(conditionMessage(result), basename(sidecar), fixed = TRUE)
  }
})
