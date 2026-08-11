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

test_that("whitespace-only profile identifiers are rejected", {
  # All three identifiers agree with each other, so every consistency check
  # passes and the blank would be emitted as the datapackage.json profile URI
  # rather than falling back to the vendored bundle.
  bundle <- fake_sdp_bundle()
  bundle$profile[["$id"]] <- "   "
  bundle$profile$properties$profile$const <- "   "
  bundle$rules$profile <- "   "

  expect_error(metasalmon:::.ms_validate_sdp_schema(bundle), "profile \\$id")
})

test_that("padded schema identifiers are normalised, not emitted", {
  # Consistent padding passed every consistency check -- the values were only
  # trimmed to test emptiness, then compared and stored raw, so
  # `" https://example.org/profile "` reached datapackage.json with its spaces.
  bundle <- fake_sdp_bundle()
  bundle$profile[["$id"]] <- "  https://example.org/profile  "
  bundle$profile$properties$profile$const <- " https://example.org/profile"
  bundle$rules$profile <- "https://example.org/profile "
  bundle$profile[["sdp:version"]] <- " sdp-9.9.9 "
  bundle$rules$version <- "sdp-9.9.9  "
  bundle$profile[["sdp:rules"]] <- "  https://example.org/rules  "

  validated <- metasalmon:::.ms_validate_sdp_schema(bundle)

  expect_identical(validated$profile_uri, "https://example.org/profile")
  expect_identical(validated$version, "sdp-9.9.9")
  expect_identical(validated$rules_uri, "https://example.org/rules")

  # Differently-padded identifiers still denote the same URI and must agree,
  # while a genuinely different one must not.
  mismatch <- fake_sdp_bundle()
  mismatch$rules$profile <- "https://example.org/other"
  expect_error(metasalmon:::.ms_validate_sdp_schema(mismatch), "rules profile")
})

test_that("non-URI schema identifiers are rejected", {
  # Cardinality and blankness were not enough: these are written verbatim into
  # datapackage.json, where Frictionless expects a dereferenceable profile URL.
  for (bad in c("not a URI", "example.org/profile", "https://", "://x", "1https://x")) {
    bundle <- fake_sdp_bundle()
    bundle$profile[["$id"]] <- bad
    bundle$profile$properties$profile$const <- bad
    bundle$rules$profile <- bad
    expect_error(metasalmon:::.ms_validate_sdp_schema(bundle), "profile \\$id", info = bad)
  }

  rules_bad <- fake_sdp_bundle()
  rules_bad$profile[["sdp:rules"]] <- "not a URI"
  expect_error(metasalmon:::.ms_validate_sdp_schema(rules_bad), "sdp:rules")

  # A non-http scheme is a legitimate offline arrangement and must be accepted.
  offline <- fake_sdp_bundle()
  offline$profile[["sdp:rules"]] <- "file:///opt/sdp/sdp.rules.yaml"
  expect_identical(
    metasalmon:::.ms_validate_sdp_schema(offline)$rules_uri,
    "file:///opt/sdp/sdp.rules.yaml"
  )
})

test_that("schema URIs need an authority, not just a scheme separator", {
  # `://` followed by anything accepted host-less values that would still be
  # emitted as the profile URI.
  for (bad in c("https:///profile.json", "https://?query", "https://#fragment")) {
    bundle <- fake_sdp_bundle()
    bundle$profile[["$id"]] <- bad
    bundle$profile$properties$profile$const <- bad
    bundle$rules$profile <- bad
    expect_error(metasalmon:::.ms_validate_sdp_schema(bundle), "profile \\$id", info = bad)
  }

  # `file://` legitimately has an empty authority and must still be accepted.
  offline <- fake_sdp_bundle()
  offline$profile[["sdp:rules"]] <- "file:///opt/sdp/sdp.rules.yaml"
  expect_identical(
    metasalmon:::.ms_validate_sdp_schema(offline)$rules_uri,
    "file:///opt/sdp/sdp.rules.yaml"
  )
})

test_that("schema URI authorities must carry a host", {
  # A non-empty authority is not the same claim as a host: `user@` and `:` are
  # both non-empty and hostless, and would be emitted as the profile URI.
  bad <- c("https://user@/profile.json", "https://:/profile.json",
           "https://:8080/x", "https://%zz/x")
  for (value in bad) {
    bundle <- fake_sdp_bundle()
    bundle$profile[["$id"]] <- value
    bundle$profile$properties$profile$const <- value
    bundle$rules$profile <- value
    expect_error(metasalmon:::.ms_validate_sdp_schema(bundle), "profile \\$id", info = value)
  }

  # Ordinary and unusual-but-valid authorities still pass.
  good <- c("https://example.org/x", "https://example.org:8080/x",
            "https://user:pass@example.org/x", "https://[::1]:8080/x",
            "https://ex%20ample.org/x", "file:///opt/sdp/rules.yaml",
            # `@` after the authority is path, not userinfo -- host is "a".
            "https://a/b@c/x")
  for (value in good) {
    bundle <- fake_sdp_bundle()
    bundle$profile[["sdp:rules"]] <- value
    expect_identical(metasalmon:::.ms_validate_sdp_schema(bundle)$rules_uri, value, info = value)
  }
})
