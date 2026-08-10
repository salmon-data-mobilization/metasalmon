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
  # The contract is that the bundle agrees with itself, not that it matches a
  # constant compiled into metasalmon.
  expect_equal(schema$profile_uri, schema$rules$profile)
  expect_equal(schema$source, "vendored")
  expect_true(all(c(
    "dataset",
    "methods",
    "observation_structures",
    "observation_components"
  ) %in% names(schema$metadata_tables)))
})

test_that("vendored extension contracts match their writers", {
  old_options <- options(metasalmon.sdp_schema_source = "vendored")
  withr::defer(options(old_options))

  expect_identical(
    metasalmon:::.ms_sdp_schema_field_names("methods"),
    metasalmon:::.ms_sdp_methods_columns
  )
  expect_identical(
    metasalmon:::.ms_sdp_schema_field_names("observation_structures"),
    metasalmon:::.ms_sdp_observation_structures_columns
  )
  expect_identical(
    metasalmon:::.ms_sdp_schema_field_names("observation_components"),
    metasalmon:::.ms_sdp_observation_components_columns
  )
})

test_that("remote schema source and SDP profile identifier remain distinct", {
  old_options <- options(
    metasalmon.sdp_schema_url = NULL,
    metasalmon.sdp_schema_base_url = NULL
  )
  withr::defer(options(old_options))

  expect_identical(
    metasalmon:::.ms_default_sdp_schema_base_url(),
    "https://raw.githubusercontent.com/salmon-data-mobilization/smn-data-pkg/main"
  )
  expect_identical(
    metasalmon:::.ms_sdp_profile_url(),
    "https://salmon-data-mobilization.github.io/smn-data-pkg/profiles/salmon-data-package/v0.2/profile.json"
  )
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

# A minimal in-memory bundle. Built by hand so these tests exercise the identity
# contract itself rather than whatever the vendored files happen to say, and so
# they are not blinded by helper-validation.R's suite-wide "vendored" pin.
fake_sdp_bundle <- function(profile_uri = "https://example.org/sdp/profile.json",
                            const_uri = profile_uri,
                            rules_profile = profile_uri,
                            profile_version = "sdp-9.9.9",
                            rules_version = "sdp-9.9.9") {
  vendored <- metasalmon:::.ms_load_vendored_sdp_schema()
  list(
    metadata_schemas = vendored$metadata_schemas,
    profile = list(
      "$id" = profile_uri,
      properties = list(profile = list(const = const_uri)),
      "sdp:version" = profile_version,
      "sdp:rules" = "https://example.org/sdp/rules.yaml"
    ),
    rules = list(profile = rules_profile, version = rules_version)
  )
}

test_that("SDP schema validation derives the profile identity from the bundle", {
  validated <- metasalmon:::.ms_validate_sdp_schema(fake_sdp_bundle())

  expect_identical(validated$profile_uri, "https://example.org/sdp/profile.json")
  expect_identical(validated$rules_uri, "https://example.org/sdp/rules.yaml")
  expect_identical(validated$version, "sdp-9.9.9")
})

test_that("SDP schema validation rejects an internally inconsistent bundle", {
  expect_error(
    metasalmon:::.ms_validate_sdp_schema(
      fake_sdp_bundle(const_uri = "https://example.org/other.json")
    ),
    "properties.profile.const"
  )
  expect_error(
    metasalmon:::.ms_validate_sdp_schema(
      fake_sdp_bundle(rules_profile = "https://example.org/other.json")
    ),
    "rules profile"
  )
  expect_error(
    metasalmon:::.ms_validate_sdp_schema(fake_sdp_bundle(rules_version = "sdp-0.0.1")),
    "sdp:version"
  )
  expect_error(
    metasalmon:::.ms_validate_sdp_schema(fake_sdp_bundle(profile_uri = "")),
    "profile [$]id is missing"
  )
})

test_that("the vendored SDP bundle is internally consistent and uses the current identifier", {
  old_options <- options(metasalmon.sdp_schema_source = "vendored")
  withr::defer(options(old_options))

  schema <- metasalmon:::.ms_load_sdp_schema(refresh = TRUE, quiet = TRUE)

  expect_identical(schema$profile_uri, schema$profile$properties$profile$const)
  expect_identical(schema$profile_uri, schema$rules$profile)
  expect_identical(schema$profile[["sdp:version"]], schema$rules$version)
  # Pins the value too, so a partial re-vendor is caught.
  expect_identical(
    schema$profile_uri,
    "https://salmon-data-mobilization.github.io/smn-data-pkg/profiles/salmon-data-package/v0.2/profile.json"
  )
})

test_that("the live upstream SDP bundle loads", {
  # The gap that let the profile-identifier drift go unnoticed: nothing ever
  # exercised a successful remote fetch, because the whole suite pins
  # `sdp_schema_source = "vendored"`.
  skip_on_cran()
  skip_if_offline("raw.githubusercontent.com")

  old_options <- options(metasalmon.sdp_schema_source = "remote")
  withr::defer({
    options(old_options)
    metasalmon:::.ms_load_sdp_schema(source = "vendored", refresh = TRUE, quiet = TRUE)
  })

  schema <- metasalmon:::.ms_load_sdp_schema(refresh = TRUE, quiet = TRUE)

  expect_identical(schema$source, "remote")
  expect_identical(schema$profile_uri, schema$rules$profile)
  expect_true(nzchar(schema$version))
})

test_that("a bundle with no usable version is rejected", {
  # `identical(NULL, NULL)` is TRUE, so two absent versions agreed and the
  # bundle was accepted with no version at all — writers then emit an invalid
  # sdp.specVersion instead of falling back to the vendored bundle.
  bundle <- fake_sdp_bundle()
  bundle$profile[["sdp:version"]] <- NULL
  bundle$rules$version <- NULL
  expect_error(
    metasalmon:::.ms_validate_sdp_schema(bundle),
    "single non-empty string"
  )

  blank <- fake_sdp_bundle(profile_version = "", rules_version = "")
  expect_error(metasalmon:::.ms_validate_sdp_schema(blank), "single non-empty string")

  missing_one <- fake_sdp_bundle()
  missing_one$rules$version <- NULL
  expect_error(metasalmon:::.ms_validate_sdp_schema(missing_one), "single non-empty string")

  # A well-formed bundle is unaffected.
  expect_identical(metasalmon:::.ms_validate_sdp_schema(fake_sdp_bundle())$version, "sdp-9.9.9")
})

test_that("an unusable sdp:rules value is rejected", {
  # It is written straight into datapackage.json$sdp$rules, so a blank,
  # whitespace-only, or non-scalar value must reject the bundle rather than be
  # emitted. Absent is fine — that falls back to the vendored constant.
  for (bad in list("", "   ", list("a", "b"))) {
    bundle <- fake_sdp_bundle()
    bundle$profile[["sdp:rules"]] <- bad
    expect_error(metasalmon:::.ms_validate_sdp_schema(bundle), "sdp:rules")
  }

  absent <- fake_sdp_bundle()
  absent$profile[["sdp:rules"]] <- NULL
  expect_identical(
    metasalmon:::.ms_validate_sdp_schema(absent)$rules_uri,
    metasalmon:::.ms_sdp_public_rules_url()
  )
})
