test_that("SDP schema loader falls back loudly to vendored schema", {
  old_options <- options(
    metasalmon.sdp_schema_source = "auto",
    metasalmon.sdp_schema_base_url = "http://127.0.0.1:9"
  )
  withr::defer(options(old_options))

  expect_warning(
    schema <- metasalmon:::.ms_load_sdp_schema(refresh = TRUE),
    "using vendored schemas"
  )

  expect_equal(schema$version, "sdp-0.2.0")
  expect_equal(schema$profile[["$id"]], metasalmon:::.ms_sdp_profile_url())
  expect_true("dataset" %in% names(schema$metadata_tables))
})

test_that("Frictionless SDP schemas drive metadata column order", {
  old_options <- options(metasalmon.sdp_schema_source = "vendored")
  withr::defer(options(old_options))

  expect_equal(
    metasalmon:::.ms_dataset_meta_cols()[1:7],
    c("dataset_id", "title", "description", "creator", "contact_name", "contact_email", "license")
  )
  expect_true("property_iri" %in% metasalmon:::.ms_dictionary_cols())
})

test_that("SDP metadata resource descriptors come from the profile", {
  old_options <- options(metasalmon.sdp_schema_source = "vendored")
  withr::defer(options(old_options))

  resources <- metasalmon:::.ms_sdp_metadata_resource_entries(include_codes = TRUE)
  expect_equal(purrr::map_chr(resources, "name"), c(
    "sdp_dataset",
    "sdp_tables",
    "sdp_column_dictionary",
    "sdp_codes"
  ))
  expect_true(all(grepl("schema/frictionless/metadata/.+[.]schema[.]json$", purrr::map_chr(resources, "schema"))))
})
