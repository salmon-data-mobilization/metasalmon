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

b223_sidecar_consumers <- function(package_path) {
  list(
    eml = function() write_eml_from_sdp(package_path, overwrite = TRUE),
    inventory = function() .ms_knb_sdp_artifact_paths(package_path),
    plan = function() .ms_knb_build_plan(
      package_path,
      eml_path = file.path(package_path, "metadata", "eml.xml"),
      manifest_path = file.path(package_path, "metadata", "knb-manifest.json"),
      public = TRUE, config = .ms_knb_config("production")
    )
  )
}

b223_file_bytes <- function(path) readBin(path, "raw", n = file.info(path)$size)

test_that("all sidecar consumers refuse tags before changing output bytes", {
  skip_if_not_installed("emld")
  withr::local_options(yaml.eval.expr = TRUE)
  archive_reached <- FALSE
  local_mocked_bindings(
    .ms_knb_write_sdp_archive = function(...) {
      archive_reached <<- TRUE
      stop(errorCondition("Archive construction was reached.",
                          class = "b223_archive_reached"))
    }, .package = "metasalmon"
  )
  for (consumer in c("eml", "inventory", "plan")) {
    for (expression in c(FALSE, TRUE)) {
      for (existing_output in c(FALSE, TRUE)) {
        root <- withr::local_tempdir()
        package_path <- make_knb_test_sdp(root)
        probe <- b223_expr_tag(root)
        tag <- if (expression) probe$tag else "!unknown X"
        sidecar <- b223_tag_eml_sidecar(package_path, tag)
        before <- b223_file_bytes(sidecar)
        output <- file.path(package_path, "metadata", "eml.xml")
        if (existing_output) writeLines("ORIGINAL-EML-SENTINEL", output)
        output_before <- if (existing_output) b223_file_bytes(output) else NULL
        archive_reached <- FALSE
        result <- tryCatch(
          suppressMessages(b223_sidecar_consumers(package_path)[[consumer]]()),
          error = identity
        )
        expect_s3_class(result, "metasalmon_eml_mapping_tag")
        expect_match(conditionMessage(result), basename(sidecar), fixed = TRUE)
        expect_false(file.exists(probe$sentinel))
        expect_false(archive_reached)
        expect_identical(b223_file_bytes(sidecar), before)
        if (existing_output) {
          expect_identical(b223_file_bytes(output), output_before)
        } else {
          expect_false(file.exists(output))
        }
      }
    }
  }
})

test_that("all sidecar consumers preserve untagged core and literal behavior", {
  skip_if_not_installed("emld")
  archive_reached <- FALSE
  local_mocked_bindings(
    .ms_knb_write_sdp_archive = function(...) {
      archive_reached <<- TRUE
      stop(errorCondition("Archive construction was reached.",
                          class = "b223_archive_reached"))
    }, .package = "metasalmon"
  )
  accepted <- c(
    untagged = "Counts were compiled using the documented monitoring workflow.",
    core = "!!str 'Counts were compiled using the documented monitoring workflow.'",
    literal = "'!unknown literal text'"
  )
  for (tag in accepted) {
    package_path <- make_knb_test_sdp(withr::local_tempdir())
    sidecar <- b223_tag_eml_sidecar(package_path, tag)
    before <- b223_file_bytes(sidecar)
    calls <- b223_sidecar_consumers(package_path)
    eml <- suppressMessages(calls$eml())
    expect_true(file.exists(eml$path))
    expect_true(isTRUE(eml$validation))
    if (identical(tag, accepted[["literal"]])) {
      expect_match(eml$xml, "!unknown literal text", fixed = TRUE)
    }
    inventory <- calls$inventory()
    expect_identical(
      unname(inventory[["sdp_artifact:metadata/semantic_vocabulary.csv"]]),
      normalizePath(file.path(package_path, "metadata", "semantic_vocabulary.csv"),
                    mustWork = TRUE)
    )
    archive_reached <- FALSE
    result <- tryCatch(calls$plan(), error = identity)
    # This positive control establishes the plan's read completed, reaching
    # the exact next step which must remain unreached for unknown tags.
    expect_s3_class(result, "b223_archive_reached")
    expect_true(archive_reached)
    expect_identical(b223_file_bytes(sidecar), before)
  }
})

test_that("all sidecar consumers retain ordinary malformed YAML errors", {
  skip_if_not_installed("emld")
  archive_reached <- FALSE
  local_mocked_bindings(
    .ms_knb_write_sdp_archive = function(...) {
      archive_reached <<- TRUE
      stop(errorCondition("Archive construction was reached.",
                          class = "b223_archive_reached"))
    }, .package = "metasalmon"
  )
  for (consumer in c("eml", "inventory", "plan")) {
    package_path <- make_knb_test_sdp(withr::local_tempdir())
    sidecar <- file.path(package_path, "metadata", "eml-mapping.yml")
    text <- paste(readLines(sidecar), collapse = "\n")
    text <- paste0(text, "\nbroken: [unterminated\n")
    native <- tryCatch(yaml::yaml.load(text, eval.expr = FALSE), error = identity)
    expect_s3_class(native, "error")
    writeLines(text, sidecar)
    before <- b223_file_bytes(sidecar)
    output <- file.path(package_path, "metadata", "eml.xml")
    writeLines("ORIGINAL-EML-SENTINEL", output)
    output_before <- b223_file_bytes(output)
    archive_reached <- FALSE
    result <- tryCatch(
      suppressMessages(b223_sidecar_consumers(package_path)[[consumer]]()),
      error = identity
    )
    expect_s3_class(result, "error")
    expect_false(inherits(result, "metasalmon_eml_mapping_tag"))
    expect_match(conditionMessage(result), conditionMessage(native), fixed = TRUE)
    expect_match(conditionMessage(result), basename(sidecar), fixed = TRUE)
    expect_false(archive_reached)
    expect_identical(b223_file_bytes(sidecar), before)
    expect_identical(b223_file_bytes(output), output_before)
  }
})
