# S3 -- KNB environment support.
#
# Three invariants have their own tests here because each one, if it broke,
# would break silently: a live production deposit that stopped demanding
# confirmation, a test rehearsal that minted a production node identifier into
# a deposited artifact, and an environment switched partway.

# Values a production artifact contains and a test artifact must never
# contain, and the reverse. Kept as data so a new environment-derived URL is
# added in one place.
knb_production_markers <- c(
  "urn:node:KNB",
  "knb.ecoinformatics.org",
  "https://cn.dataone.org/cn/"
)

knb_test_markers <- c(
  "urn:node:mnTestKNB",
  "dev.nceas.ucsb.edu",
  "cn-stage.test.dataone.org"
)

read_text_file <- function(path) {
  paste(readLines(path, warn = FALSE), collapse = "\n")
}

test_that("the environment registry is closed, complete, and switches whole", {
  registry <- .ms_knb_environment_registry()
  expect_setequal(names(registry), c("test", "production"))

  for (id in names(registry)) {
    # The record must carry exactly the declared field set -- no more, no
    # fewer. This is what fails when a field is added to one environment and
    # forgotten in the other.
    expect_silent(
      .ms_knb_validate_environment_config(registry[[id]], id)
    )
    expect_setequal(
      names(registry[[id]]),
      .ms_knb_environment_fields()
    )
  }

  test_config <- .ms_knb_config("test")
  production_config <- .ms_knb_config("production")

  # The verified facts, from the node documents themselves (2026-08-22).
  expect_identical(test_config$node_id, "urn:node:mnTestKNB")
  expect_identical(test_config$dataone_network, "STAGING")
  expect_identical(
    test_config$mn_base_url,
    "https://dev.nceas.ucsb.edu/knb/d1/mn"
  )
  expect_identical(
    test_config$cn_base_url,
    "https://cn-stage.test.dataone.org/cn"
  )
  expect_identical(test_config$token_option, "dataone_test_token")
  expect_false(test_config$durable)
  expect_identical(test_config$max_replicas, 0L)

  expect_identical(production_config$node_id, "urn:node:KNB")
  expect_identical(production_config$dataone_network, "PROD")
  expect_identical(
    production_config$mn_base_url,
    "https://knb.ecoinformatics.org/knb/d1/mn"
  )
  expect_identical(production_config$cn_base_url, "https://cn.dataone.org/cn")
  expect_identical(production_config$token_option, "dataone_token")
  expect_true(production_config$durable)
  expect_identical(production_config$max_replicas, 3L)

  # Atomicity: every derived URL belongs to that environment's own base URL.
  # A production Solr endpoint under a test coordinating node is the exact
  # failure this asserts cannot exist.
  for (config in list(test_config, production_config)) {
    expect_true(startsWith(config$mn_endpoint, config$mn_base_url))
    expect_true(startsWith(config$object_endpoint, config$mn_base_url))
    expect_true(startsWith(config$resolver, config$cn_base_url))
    expect_true(startsWith(config$solr_endpoint, config$cn_base_url))
  }

  # No environment-distinguishing value may be shared between environments.
  distinguishing <- c(
    "knb_environment", "dataone_network", "node_id", "mn_base_url",
    "mn_endpoint", "object_endpoint", "cn_base_url", "resolver",
    "solr_endpoint", "token_option", "pid_scope",
    "default_eml_relpath", "default_manifest_relpath"
  )
  for (field in distinguishing) {
    expect_false(
      identical(test_config[[field]], production_config[[field]]),
      info = paste("environments share field", field)
    )
  }
})

test_that("a partially specified environment record is refused", {
  complete <- .ms_knb_config("production")

  # RED anchor for the atomicity guard: drop one field, and the record must
  # stop being usable rather than silently fall back to a default.
  for (field in c("solr_endpoint", "node_id", "token_option")) {
    broken <- complete
    broken[[field]] <- NULL
    expect_error(
      .ms_knb_validate_environment_config(broken, "production"),
      "complete registry record"
    )
  }

  blank <- complete
  blank$resolver <- ""
  expect_error(
    .ms_knb_validate_environment_config(blank, "production"),
    "must be one non-empty string"
  )

  extra <- complete
  extra$custom_endpoint <- "https://example.invalid/"
  expect_error(
    .ms_knb_validate_environment_config(extra, "production"),
    "Unexpected field"
  )
})

test_that("environment selection is exact, with no partial match or fallback", {
  expect_identical(.ms_knb_config("test")$knb_environment, "test")
  expect_identical(
    .ms_knb_config("production")$knb_environment,
    "production"
  )

  # Partial matching an environment name is how a rehearsal becomes a
  # production deposit.
  for (value in c("prod", "PRODUCTION", "staging", "Test", "")) {
    expect_error(.ms_knb_config(value), "Unknown KNB environment|must be exactly one")
  }
  expect_error(.ms_knb_config(NA_character_), "must be exactly one")
  expect_error(.ms_knb_config(c("test", "production")), "must be exactly one")
})

test_that("a dry run defaults to the test node and a live call names its target", {
  # Brett's 2026-08-22 ruling: develop against the test environment first,
  # then post to production once the package looks good there.
  expect_identical(
    .ms_knb_resolve_environment(NULL, dry_run = TRUE)$knb_environment,
    "test"
  )
  expect_identical(
    .ms_knb_resolve_environment(NULL, dry_run = TRUE)$node_id,
    "urn:node:mnTestKNB"
  )

  # An unstated environment on a live call is an error, not a default -- in
  # particular it never silently means production.
  expect_error(
    .ms_knb_resolve_environment(NULL, dry_run = FALSE),
    "requires an explicit"
  )
  expect_identical(
    .ms_knb_resolve_environment("production", dry_run = FALSE)$node_id,
    "urn:node:KNB"
  )
})

test_that("the environment is re-derived from the node id a plan was built for", {
  expect_identical(
    .ms_knb_config_for_node("urn:node:KNB")$knb_environment,
    "production"
  )
  expect_identical(
    .ms_knb_config_for_node("urn:node:mnTestKNB")$knb_environment,
    "test"
  )
  expect_error(
    .ms_knb_config_for_node("urn:node:SOMETHINGELSE"),
    "not a registered KNB member node"
  )

  # The piecemeal switch, refused: a plan claiming the production network
  # under the test node identifier, and the reverse.
  expect_error(
    .ms_knb_plan_config(list(
      node_id = "urn:node:mnTestKNB",
      environment = "PROD"
    )),
    "mixes KNB environments"
  )
  expect_error(
    .ms_knb_plan_config(list(
      node_id = "urn:node:KNB",
      environment = "STAGING"
    )),
    "mixes KNB environments"
  )
  expect_error(
    .ms_knb_plan_config(list(
      node_id = "urn:node:KNB",
      environment = "PROD",
      knb_environment = "test"
    )),
    "mixes KNB environments"
  )
  expect_identical(
    .ms_knb_plan_config(list(
      node_id = "urn:node:KNB",
      environment = "PROD",
      knb_environment = "production"
    ))$solr_endpoint,
    "https://cn.dataone.org/cn/v2/query/solr/"
  )
})

test_that("production identifier preimages are unchanged by environment scoping", {
  # Production's scope is empty and is dropped, so every production PID minted
  # before this module is byte-identical. If this fails, existing published
  # packages can no longer be re-planned.
  expect_identical(
    .ms_knb_pid_preimage("", "data", "dataset", "table"),
    "data:dataset:table"
  )
  expect_identical(
    .ms_knb_pid_preimage(NULL, "data", "dataset"),
    "data:dataset"
  )
  expect_identical(
    .ms_knb_pid_preimage("knb-test", "data", "dataset"),
    "knb-test:data:dataset"
  )
  expect_identical(.ms_knb_config("production")$pid_scope, "")
  expect_true(nzchar(.ms_knb_config("test")$pid_scope))
})

test_that("each environment names its own missing token", {
  withr::local_options(list(
    dataone_token = NULL,
    dataone_test_token = NULL
  ))

  expect_error(
    .ms_knb_require_token(.ms_knb_config("production")),
    "dataone_token"
  )
  expect_error(
    .ms_knb_require_token(.ms_knb_config("test")),
    "dataone_test_token"
  )

  # The test credential is a different token: supplying only the production
  # one must not satisfy the test environment.
  withr::local_options(list(dataone_token = "production-jwt"))
  expect_error(
    .ms_knb_require_token(.ms_knb_config("test")),
    "dataone_test_token"
  )
  expect_silent(.ms_knb_require_token(.ms_knb_config("production")))
})

test_that("both environment tokens are redacted from captured text", {
  # 0.2.5 shipped the redaction rule structurally, for any qualified `*_token`
  # name. The test credential this stream introduces must already be covered;
  # asserting it here is what keeps that true.
  redacted <- .ms_redact_secrets(paste(
    "dataone_token=PRODSECRET",
    "dataone_test_token=TESTSECRET",
    "DATAONE_TEST_TOKEN=TESTSECRET",
    sep = " "
  ))

  expect_false(grepl("PRODSECRET", redacted, fixed = TRUE))
  expect_false(grepl("TESTSECRET", redacted, fixed = TRUE))
})

test_that("a test dry run mints no production identity into any artifact", {
  skip_if_not_installed("emld")

  package_path <- make_knb_test_sdp(withr::local_tempdir())
  adapter_accessed <- FALSE
  withr::local_options(list(
    metasalmon.knb_adapter = function() {
      adapter_accessed <<- TRUE
      stop("the adapter must not be constructed during a dry run")
    }
  ))

  result <- publish_sdp_to_knb(
    package_path,
    public = TRUE,
    dry_run = TRUE,
    knb_environment = "test"
  )

  expect_false(adapter_accessed)
  expect_identical(result$knb_environment, "test")

  manifest <- jsonlite::read_json(result$manifest_path, simplifyVector = TRUE)
  expect_identical(manifest$node_id, "urn:node:mnTestKNB")
  expect_identical(manifest$environment, "STAGING")
  expect_identical(manifest$knb_environment, "test")

  # Every deposited-artifact byte stream, checked together. The manifest, the
  # OAI-ORE resource map, and the EML record are the three things a live call
  # would send; none may carry production identity.
  artifacts <- c(
    manifest = read_text_file(result$manifest_path),
    resource_map = read_text_file(result$resource_map_path),
    eml = read_text_file(file.path(package_path, "publication", "test", "eml.xml"))
  )

  for (name in names(artifacts)) {
    for (marker in knb_production_markers) {
      expect_false(
        grepl(marker, artifacts[[name]], fixed = TRUE),
        info = paste("production marker", marker, "found in", name)
      )
    }
  }

  # ... and the resource map and EML must actually carry the test identity,
  # so this test cannot pass by producing empty artifacts.
  expect_true(grepl(
    "cn-stage.test.dataone.org",
    artifacts[["resource_map"]],
    fixed = TRUE
  ))
  expect_true(grepl(
    "dev.nceas.ucsb.edu",
    artifacts[["eml"]],
    fixed = TRUE
  ))
})

test_that("a test dry run leaves the reviewed production EML byte-identical", {
  skip_if_not_installed("emld")

  package_path <- make_knb_test_sdp(withr::local_tempdir())
  production_eml <- file.path(package_path, "metadata", "eml.xml")

  write_eml_from_sdp(package_path)
  expect_true(file.exists(production_eml))
  before <- digest::digest(
    file = production_eml,
    algo = "sha256",
    serialize = FALSE
  )

  publish_sdp_to_knb(
    package_path,
    public = TRUE,
    dry_run = TRUE,
    knb_environment = "test"
  )

  # Assert on the file hash rather than the return value: the return value
  # would look fine either way.
  after <- digest::digest(
    file = production_eml,
    algo = "sha256",
    serialize = FALSE
  )
  expect_identical(before, after)
  expect_true(file.exists(
    file.path(package_path, "publication", "test", "eml.xml")
  ))
})

test_that("test and production plans share no minted identifier", {
  skip_if_not_installed("emld")

  root <- withr::local_tempdir()
  test_path <- make_knb_test_sdp(file.path(root, "test"))
  production_path <- make_knb_test_sdp(file.path(root, "production"))

  test_result <- publish_sdp_to_knb(
    test_path,
    public = TRUE,
    dry_run = TRUE,
    knb_environment = "test"
  )
  production_result <- publish_sdp_to_knb(
    production_path,
    public = TRUE,
    dry_run = TRUE,
    knb_environment = "production"
  )

  pids_of <- function(result) {
    manifest <- jsonlite::read_json(
      result$manifest_path,
      simplifyVector = TRUE
    )
    vapply(
      .ms_knb_manifest_objects(manifest),
      function(object) as.character(object$pid),
      character(1)
    )
  }

  test_pids <- pids_of(test_result)
  production_pids <- pids_of(production_result)

  expect_length(intersect(test_pids, production_pids), 0L)
  expect_false(identical(
    test_result$package_id,
    production_result$package_id
  ))
  expect_false(identical(
    test_result$series_id,
    production_result$series_id
  ))
  # The SDP archive is the sharpest case: its bytes are identical in both
  # environments, so only the environment scope separates its identifier.
  expect_false(identical(
    test_result$resource_map_pid,
    production_result$resource_map_pid
  ))
})

test_that("each environment writes its own default manifest and EML paths", {
  skip_if_not_installed("emld")

  root <- withr::local_tempdir()
  test_path <- make_knb_test_sdp(file.path(root, "test"))
  production_path <- make_knb_test_sdp(file.path(root, "production"))

  test_result <- publish_sdp_to_knb(
    test_path,
    public = TRUE,
    dry_run = TRUE,
    knb_environment = "test"
  )
  production_result <- publish_sdp_to_knb(
    production_path,
    public = TRUE,
    dry_run = TRUE,
    knb_environment = "production"
  )

  expect_identical(
    .ms_knb_relative_path(test_path, test_result$manifest_path),
    "publication/test/knb-manifest.json"
  )
  expect_identical(
    .ms_knb_relative_path(test_path, test_result$resource_map_path),
    "publication/test/resource-map.rdf"
  )
  # Production keeps its existing default, so a package published before this
  # change still finds its manifest where it left it.
  expect_identical(
    .ms_knb_relative_path(
      production_path,
      production_result$manifest_path
    ),
    "publication/knb-manifest.json"
  )
  expect_true(file.exists(
    file.path(production_path, "metadata", "eml.xml")
  ))
  expect_false(dir.exists(file.path(production_path, "publication", "test")))
})

test_that("an omitted environment defaults to test only for a dry run", {
  skip_if_not_installed("emld")

  package_path <- make_knb_test_sdp(withr::local_tempdir())

  result <- publish_sdp_to_knb(
    package_path,
    public = TRUE,
    dry_run = TRUE
  )
  expect_identical(result$knb_environment, "test")

  # Live with no environment stated: refused before anything is planned.
  expect_error(
    publish_sdp_to_knb(
      package_path,
      public = TRUE,
      dry_run = FALSE,
      confirm = TRUE
    ),
    "requires an explicit"
  )
})

test_that("a live production publish still demands explicit confirmation", {
  skip_if_not_installed("emld")

  package_path <- make_knb_test_sdp(withr::local_tempdir())
  adapter_accessed <- FALSE
  withr::local_options(list(
    metasalmon.knb_adapter = function() {
      adapter_accessed <<- TRUE
      stop("adapter accessed")
    }
  ))

  # The confirmation gate is the oldest safety property on this path, and
  # naming an environment must not become a way around it.
  expect_error(
    publish_sdp_to_knb(
      package_path,
      public = TRUE,
      dry_run = FALSE,
      knb_environment = "production"
    ),
    "explicit.*confirm"
  )
  expect_false(adapter_accessed)

  # An interactive default can never authorize a live call either.
  expect_error(
    publish_sdp_to_knb(
      package_path,
      public = TRUE,
      dry_run = FALSE,
      knb_environment = "production",
      confirm = FALSE
    ),
    "explicit.*confirm"
  )
  expect_false(adapter_accessed)

  # A rehearsal does not relax the gate: the test environment demands
  # confirmation for a live call too.
  expect_error(
    publish_sdp_to_knb(
      package_path,
      public = TRUE,
      dry_run = FALSE,
      knb_environment = "test"
    ),
    "explicit.*confirm"
  )
  expect_false(adapter_accessed)
})

test_that("the default adapter connects each registered environment and no other", {
  skip_if_not_installed("dataone")
  skip_if_not_installed("datapack")
  skip_if_not_installed("XML")

  adapter <- .ms_knb_default_adapter()

  test_client <- adapter$connect("STAGING", "urn:node:mnTestKNB")
  expect_identical(
    test_client$endpoint,
    "https://dev.nceas.ucsb.edu/knb/d1/mn/v2"
  )
  production_client <- adapter$connect("PROD", "urn:node:KNB")
  expect_identical(
    production_client$endpoint,
    "https://knb.ecoinformatics.org/knb/d1/mn/v2"
  )

  # A mismatched network/node pair is the piecemeal switch at the network
  # boundary, and is refused there too.
  expect_error(
    adapter$connect("PROD", "urn:node:mnTestKNB"),
    "mixes KNB environments|does not belong"
  )
  expect_error(
    adapter$connect("STAGING", "urn:node:KNB"),
    "mixes KNB environments|does not belong"
  )
  expect_error(
    adapter$connect("PROD", "urn:node:UNREGISTERED"),
    "not a registered KNB member node"
  )
})

test_that("a test rehearsal survives an ordinary package rewrite", {
  skip_if_not_installed("emld")

  package_path <- make_knb_test_sdp(withr::local_tempdir())
  publish_sdp_to_knb(
    package_path,
    public = TRUE,
    dry_run = TRUE,
    knb_environment = "test"
  )
  rehearsal <- file.path(
    package_path,
    "publication",
    "test",
    "knb-manifest.json"
  )
  expect_true(file.exists(rehearsal))
  before <- digest::digest(file = rehearsal, algo = "sha256", serialize = FALSE)

  # `publication/` is a sidecar the base writer preserves. A rehearsal is
  # publication-writer output, so an ordinary metadata rewrite must leave it
  # alone -- registering it as a package-managed path would delete it here.
  package <- read_salmon_datapackage(package_path)
  write_salmon_datapackage(
    resources = package$resources,
    dataset_meta = package$dataset,
    table_meta = package$tables,
    dict = package$dictionary,
    codes = package$codes,
    path = package_path,
    overwrite = TRUE
  )

  expect_true(file.exists(rehearsal))
  expect_identical(
    before,
    digest::digest(file = rehearsal, algo = "sha256", serialize = FALSE)
  )
})
