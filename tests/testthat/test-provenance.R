test_that("the accepted writer set covers both mirrors for every manifest", {
  writers <- c(
    "write_sdp_sssom",
    "write_sdp_measurement_decompositions",
    "write_sdp_reproducibility_manifest"
  )
  for (writer in writers) {
    expect_identical(
      .ms_manifest_provenance_version_field(
        list(generated_by = paste0("metasalmon::", writer)),
        writer
      ),
      "metasalmon_version"
    )
    expect_identical(
      .ms_manifest_provenance_version_field(
        list(generated_by = paste0("metasalmonpy.", writer)),
        writer
      ),
      "metasalmonpy_version"
    )
  }
})

test_that("a writer that is not one of the two mirrors is not accepted", {
  writer <- "write_sdp_sssom"
  unaccepted <- list(
    # Another package entirely.
    list(generated_by = "someone-else"),
    # The right implementation, the wrong artifact's writer.
    list(generated_by = "metasalmon::write_sdp_reproducibility_manifest"),
    # The two calling conventions crossed over.
    list(generated_by = "metasalmonpy::write_sdp_sssom"),
    list(generated_by = "metasalmon.write_sdp_sssom"),
    # Malformed or absent `generated_by`.
    list(generated_by = character()),
    list(generated_by = c("metasalmon::write_sdp_sssom", "x")),
    list(generated_by = NA_character_),
    list(generated_by = 1L),
    list(generated_by = list("metasalmon::write_sdp_sssom")),
    list()
  )
  for (provenance in unaccepted) {
    expect_identical(
      .ms_manifest_provenance_version_field(provenance, writer),
      NA_character_
    )
  }
  # A provenance block that is not a list at all is not an error, just not
  # accepted -- the validators rely on that to short-circuit.
  expect_identical(
    .ms_manifest_provenance_version_field(NULL, writer),
    NA_character_
  )
  expect_identical(
    .ms_manifest_provenance_version_field("provenance", writer),
    NA_character_
  )
})

test_that("an accepted version value is one non-blank string", {
  expect_true(.ms_manifest_provenance_version_ok("0.3.0"))
  expect_true(.ms_manifest_provenance_version_ok("development"))
  for (value in list(NULL, NA_character_, "", "   ", "\t\n", 1.8, TRUE,
                     c("0.3.0", "0.3.1"), list("0.3.0"))) {
    expect_false(.ms_manifest_provenance_version_ok(value))
  }
})

test_that("no manifest validator re-types the accepted writer strings", {
  # The honest-provenance ruling was applied to SSSOM and to measurement
  # decompositions and forgotten for the reproducibility manifest (backlog
  # #88), because each application re-typed the same pair of literals instead
  # of sharing them. This guard is what stops a fourth manifest type repeating
  # it: every validator must reach the accepted set through the shared helper.
  #
  # *Retires when:* nothing -- it is a permanent structural check. Add the new
  # validator to `validators` below when a manifest type is added; exempt one
  # only by recording here why that manifest cannot be written by the mirror.
  validators <- list(
    .ms_sssom_validate_manifest = .ms_sssom_validate_manifest,
    .ms_sdp_decomposition_validate_manifest =
      .ms_sdp_decomposition_validate_manifest,
    .ms_sdp_reproducibility_validate_manifest =
      .ms_sdp_reproducibility_validate_manifest
  )
  for (name in names(validators)) {
    source <- paste(deparse(body(validators[[name]])), collapse = "\n")
    expect_true(
      grepl(".ms_manifest_provenance_version_field", source, fixed = TRUE),
      info = paste(name, "must resolve its accepted writers via R/provenance.R")
    )
    expect_false(
      grepl("metasalmonpy.write_sdp", source, fixed = TRUE),
      info = paste(name, "re-types a writer literal instead of sharing it")
    )
    expect_false(
      grepl("metasalmon::write_sdp", source, fixed = TRUE),
      info = paste(name, "re-types a writer literal instead of sharing it")
    )
  }
})
