# Pinned ontology releases (tern ECOSYSTEM M-12): find_terms() and
# fetch_salmon_ontology() reading a release snapshot of smn or gcdfo. No test
# here reaches the network: every httr::GET() is answered by a stub, and the
# ones that expect no request at all stub it with an error.

or_fixture <- function(...) {
  testthat::test_path("fixtures", "ontology-release", ...)
}

or_sha256 <- function(path) {
  digest::digest(file = path, algo = "sha256")
}

# A temporary copy of a fixture snapshot. `manifest` is TRUE to write a
# MANIFEST.sha256 from the copied bytes, FALSE for none, or a character vector
# of manifest lines to write as given.
or_snapshot <- function(name, manifest = TRUE, env = parent.frame()) {
  dir <- withr::local_tempdir(.local_envir = env)
  files <- list.files(or_fixture(name), full.names = TRUE)
  file.copy(files, dir)
  if (isTRUE(manifest)) {
    copied <- file.path(dir, basename(files))
    writeLines(paste0(vapply(copied, or_sha256, character(1)), "  ", basename(files)),
               file.path(dir, "MANIFEST.sha256"))
  } else if (is.character(manifest)) {
    writeLines(manifest, file.path(dir, "MANIFEST.sha256"))
  }
  dir
}

or_no_network <- function(env = parent.frame()) {
  testthat::local_mocked_bindings(
    GET = function(url, ...) stop("unexpected request to ", url),
    .package = "httr",
    .env = env
  )
}

# Each test reads its snapshots afresh, not from an index another test parsed.
or_fresh_indexes <- function(env = parent.frame()) {
  rm(list = ls(.ms_release_index_cache, all.names = TRUE), envir = .ms_release_index_cache)
  withr::defer(
    rm(list = ls(.ms_release_index_cache, all.names = TRUE), envir = .ms_release_index_cache),
    envir = env
  )
}

# An answer in the shape httr::GET() returns.
or_answer <- function(url, status, body = raw()) {
  content <- if (is.raw(body)) body else charToRaw(enc2utf8(body))
  structure(
    list(url = url, status_code = as.integer(status), headers = list(), content = content),
    class = "response"
  )
}

# Stubs httr::GET() with `routes`, a list mapping each URL to a function of the
# Accept header sent, and records every request in `log$requests`.
or_routes <- function(routes, env = parent.frame()) {
  log <- new.env(parent = emptyenv())
  log$requests <- list()
  get <- function(url, ...) {
    accept <- NA_character_
    for (config in list(...)) {
      if (inherits(config, "request") && !is.null(config$headers[["Accept"]])) {
        accept <- config$headers[["Accept"]]
      }
    }
    log$requests[[length(log$requests) + 1L]] <- list(url = url, accept = accept)
    route <- routes[[url]]
    if (is.null(route)) {
      return(or_answer(url, 404L))
    }
    route(url, accept)
  }
  testthat::local_mocked_bindings(GET = get, .package = "httr", .env = env)
  log
}

or_serve_file <- function(path) {
  force(path)
  function(url, accept) or_answer(url, 200L, readBin(path, "raw", file.size(path)))
}

smn_release_pages <- "https://salmon-data-mobilization.github.io/salmon-domain-ontology/releases/"

# ---------------------------------------------------------------------------
# The smn release reader
# ---------------------------------------------------------------------------

test_that("the release reader gives smn terms the hints the module reader gives them", {
  # The release is one merged RDF/XML graph; the latest read is the modules.
  # Both build rows with .smn_index_row(), and the release reader makes up for
  # the two ways a release differs: the serializer's owl:NamedIndividual
  # declarations, and the module names it no longer carries. Remove either
  # adjustment and AgeClassValue1's hints differ here.
  modules <- c("01-entity-systematics", "02-observation-measurement", "07-controlled-vocabularies")
  paths <- or_fixture("smn-modules", paste0(modules, ".ttl"))
  names(paths) <- paste0("https://w3id.org/smn/modules/", modules)
  latest <- .parse_smn_ttl_modules(paths)
  release <- .smn_release_index(xml2::read_xml(or_fixture("smn-0.0.3", "smn.owl")))

  expect_setequal(release$iri, latest$iri)
  at <- match(latest$iri, release$iri)
  expect_identical(release$role_hints[at], latest$role_hints)
  expect_identical(release$label[at], latest$label)
  expect_identical(release$definition[at], latest$definition)
  expect_identical(release$resource_kind[at], latest$resource_kind)
  expect_identical(names(release), names(latest))

  # The same table is pinned in metasalmonpy's tests/test_ontology_release.py.
  hints <- stats::setNames(release$role_hints, sub("^https://w3id.org/smn/", "", release$iri))
  expect_identical(as.list(hints[order(names(hints), method = "radix")]), list(
    AgeClassValue1 = "constraint",
    BroodYearBasis = "constraint",
    Escapement = "variable",
    MeanStatisticalModifier = "constraint|statistical_modifier",
    StatisticalModifierScheme = "constraint|statistical_modifier",
    Stock = "entity"
  ))
})

test_that("the release reader leaves out the ontology header and foreign subjects", {
  release <- .smn_release_index(xml2::read_xml(or_fixture("smn-0.0.3", "smn.owl")))
  expect_false(any(grepl("sosa", release$iri, fixed = TRUE)))
  expect_false("https://w3id.org/smn" %in% release$iri)
  expect_false(any(grepl("NamedIndividual", release$type_iris, fixed = TRUE)))
  # A subject spread over two nodes is one row holding both nodes' values.
  stock <- release[release$iri == "https://w3id.org/smn/Stock", ]
  expect_identical(nrow(stock), 1L)
  expect_identical(stock$definition, "A group of salmon managed as one unit.")
})

test_that("the RDF/XML reader binds namespaces by URI, not by the file's prefixes", {
  # The fixture binds the OBO namespace to `ns1`, as the smn 0.0.3 release does.
  doc <- xml2::read_xml(or_fixture("smn-0.0.3", "smn.owl"))
  expect_no_warning(index <- .parse_salmon_rdfxml(doc))
  escapement <- index[index$iri == "https://w3id.org/smn/Escapement", ]
  expect_match(escapement$definition, "^The number of mature salmon")
})

# ---------------------------------------------------------------------------
# find_terms() against a snapshot directory
# ---------------------------------------------------------------------------

test_that("find_terms() searches a pinned smn snapshot and records which one", {
  or_no_network()
  or_fresh_indexes()
  local_mocked_bindings(.smn_term_index = function(...) stop("the latest smn index was read"))
  dir <- or_snapshot("smn-0.0.3")

  result <- find_terms(
    "escapement",
    role = "variable",
    sources = "smn",
    release = c(smn = "0.0.3"),
    snapshot_dir = c(smn = dir)
  )

  expect_identical(result$iri[[1]], "https://w3id.org/smn/Escapement")
  expect_identical(result$role_hints[[1]], "variable")
  record <- attr(result, "ontology_release")
  expect_identical(record, tibble::tibble(
    ontology = "smn",
    version = "0.0.3",
    version_iri = "https://w3id.org/smn/0.0.3",
    file = "smn.owl",
    sha256 = or_sha256(file.path(dir, "smn.owl")),
    manifest_verified = TRUE,
    source = dir
  ))
})

test_that("a snapshot without a manifest is read and recorded as unverified", {
  or_no_network()
  or_fresh_indexes()
  dir <- or_snapshot("smn-0.0.3", manifest = FALSE)

  result <- find_terms("escapement", sources = "smn", snapshot_dir = c(smn = dir))

  record <- attr(result, "ontology_release")
  expect_false(record$manifest_verified)
  # With no version pinned, the version the snapshot declares is recorded.
  expect_identical(record$version, "0.0.3")
})

test_that("a pinned read refuses bytes its manifest does not vouch for", {
  or_no_network()
  or_fresh_indexes()
  wrong <- paste0(strrep("0", 64), "  smn.owl")
  dir <- or_snapshot("smn-0.0.3", manifest = wrong)
  expect_error(
    find_terms("escapement", sources = "smn", snapshot_dir = c(smn = dir)),
    "does not match",
    class = "metasalmon_ontology_release_error"
  )
  # The caller's own snapshot is never touched.
  expect_true(file.exists(file.path(dir, "smn.owl")))

  unlisted <- or_snapshot("smn-0.0.3", manifest = paste0(strrep("0", 64), "  smn.ttl"))
  expect_error(
    find_terms("escapement", sources = "smn", snapshot_dir = c(smn = unlisted)),
    "does not list",
    class = "metasalmon_ontology_release_error"
  )

  malformed <- or_snapshot("smn-0.0.3", manifest = "smn.owl is fine")
  expect_error(
    find_terms("escapement", sources = "smn", snapshot_dir = c(smn = malformed)),
    "sha256sum",
    class = "metasalmon_ontology_release_error"
  )
})

test_that("a manifest in binary-mode sha256sum format verifies too", {
  or_no_network()
  or_fresh_indexes()
  path <- or_fixture("smn-0.0.3", "smn.owl")
  dir <- or_snapshot("smn-0.0.3", manifest = paste0(toupper(or_sha256(path)), " *./smn.owl"))
  result <- find_terms("escapement", sources = "smn", snapshot_dir = c(smn = dir))
  expect_true(attr(result, "ontology_release")$manifest_verified)
})

test_that("a snapshot that declares another version is not the release pinned", {
  or_no_network()
  or_fresh_indexes()
  dir <- or_snapshot("smn-0.0.3")
  expect_error(
    find_terms("escapement", sources = "smn", release = c(smn = "0.0.4"), snapshot_dir = c(smn = dir)),
    "is not release 0.0.4",
    class = "metasalmon_ontology_release_error"
  )
})

test_that("smn and gcdfo can be pinned together, and a pin is read only when searched", {
  or_no_network()
  or_fresh_indexes()
  smn <- or_snapshot("smn-0.0.3")
  gcdfo <- or_snapshot("gcdfo-0.0.9")

  result <- find_terms(
    "conservation unit",
    sources = c("smn", "gcdfo"),
    snapshot_dir = list(smn = smn, gcdfo = gcdfo)
  )
  record <- attr(result, "ontology_release")
  expect_identical(record$ontology, c("smn", "gcdfo"))
  expect_identical(record$version, c("0.0.3", "0.0.9"))
  expect_true("https://w3id.org/gcdfo/salmon#ConservationUnit" %in% result$iri)

  # smn matches "escapement" by label, so gcdfo is never asked, and its release
  # is not recorded as searched.
  smn_answers <- find_terms(
    "escapement",
    sources = c("smn", "gcdfo"),
    expand_query = FALSE,
    snapshot_dir = list(smn = smn, gcdfo = gcdfo)
  )
  expect_identical(unique(attr(smn_answers, "diagnostics")$source), "smn")
  expect_identical(attr(smn_answers, "ontology_release")$ontology, "smn")

  # gcdfo is pinned to a directory that does not exist, but not searched.
  only_smn <- find_terms(
    "escapement",
    sources = "smn",
    snapshot_dir = c(smn = smn, gcdfo = file.path(smn, "missing"))
  )
  expect_identical(attr(only_smn, "ontology_release")$ontology, "smn")
})

test_that("a snapshot that cannot be read stops the call instead of answering nothing", {
  or_no_network()
  or_fresh_indexes()
  missing_dir <- file.path(withr::local_tempdir(), "nowhere")
  expect_error(
    find_terms("escapement", sources = "smn", snapshot_dir = c(smn = missing_dir)),
    "does not exist",
    class = "metasalmon_ontology_release_error"
  )
  empty_dir <- withr::local_tempdir()
  expect_error(
    find_terms("escapement", sources = "smn", snapshot_dir = c(smn = empty_dir)),
    "holds none of the files",
    class = "metasalmon_ontology_release_error"
  )
})

test_that("release and snapshot_dir are checked before anything is searched", {
  or_no_network()
  expect_error(find_terms("x", release = "0.0.3"), "named by its ontology",
               class = "metasalmon_ontology_release_error")
  expect_error(find_terms("x", release = c(ols = "1.0.0")), "only smn and gcdfo",
               class = "metasalmon_ontology_release_error")
  expect_error(find_terms("x", release = c(smn = "v0.0.3")), "three numbers",
               class = "metasalmon_ontology_release_error")
  expect_error(find_terms("x", release = c(smn = "0.0.3", SMN = "0.0.4")), "more than once",
               class = "metasalmon_ontology_release_error")
  # Checked even when the call would search nothing.
  expect_error(find_terms("", release = c(smn = "latest")), "three numbers",
               class = "metasalmon_ontology_release_error")
})

test_that("pinned and latest results do not share a cache entry", {
  or_no_network()
  or_fresh_indexes()
  withr::local_envvar(METASALMON_CACHE = "1")
  rm(list = ls(.metasalmon_cache, all.names = TRUE), envir = .metasalmon_cache)
  withr::defer(rm(list = ls(.metasalmon_cache, all.names = TRUE), envir = .metasalmon_cache))
  latest_index <- .smn_index_empty()
  local_mocked_bindings(.smn_term_index = function(...) latest_index)
  dir <- or_snapshot("smn-0.0.3")

  pinned <- find_terms("escapement", sources = "smn", snapshot_dir = c(smn = dir))
  latest <- find_terms("escapement", sources = "smn")

  expect_gt(nrow(pinned), 0L)
  expect_identical(nrow(latest), 0L)
  expect_null(attr(latest, "ontology_release"))
})

# ---------------------------------------------------------------------------
# find_terms() against a release downloaded from its version IRI
# ---------------------------------------------------------------------------

test_that("a pinned release is downloaded once from its version IRI and verified", {
  or_fresh_indexes()
  cache <- withr::local_tempdir()
  local_mocked_bindings(.ms_release_session_cache_root = function() cache)
  owl <- or_fixture("smn-0.0.3", "smn.owl")
  manifest <- paste0(or_sha256(owl), "  smn.owl\n")
  log <- or_routes(list(
    "https://w3id.org/smn/0.0.3" = or_serve_file(owl),
    "https://salmon-data-mobilization.github.io/salmon-domain-ontology/releases/0.0.3/MANIFEST.sha256" =
      function(url, accept) or_answer(url, 200L, manifest)
  ))

  first <- find_terms("escapement", sources = "smn", release = c(smn = "0.0.3"))
  second <- find_terms("brood year basis", sources = "smn", release = c(smn = "0.0.3"))

  expect_identical(
    vapply(log$requests, `[[`, character(1), "url"),
    c("https://w3id.org/smn/0.0.3", paste0(smn_release_pages, "0.0.3/MANIFEST.sha256"))
  )
  expect_identical(log$requests[[1]]$accept, "application/rdf+xml")
  record <- attr(first, "ontology_release")
  expect_true(record$manifest_verified)
  expect_identical(record$source, "https://w3id.org/smn/0.0.3")
  expect_identical(record$sha256, or_sha256(owl))
  expect_identical(attr(second, "ontology_release"), record)
  expect_identical(second$iri[[1]], "https://w3id.org/smn/BroodYearBasis")
})

test_that("a release with no manifest is recorded unverified, and Pages answers when w3id cannot", {
  or_fresh_indexes()
  cache <- withr::local_tempdir()
  local_mocked_bindings(.ms_release_session_cache_root = function() cache)
  owl <- or_fixture("smn-0.0.3", "smn.owl")
  log <- or_routes(list(
    "https://w3id.org/smn/0.0.3" = function(url, accept) stop("Could not resolve host (stub)"),
    "https://salmon-data-mobilization.github.io/salmon-domain-ontology/releases/0.0.3/smn.owl" =
      or_serve_file(owl)
  ))

  result <- find_terms("escapement", sources = "smn", release = c(smn = "0.0.3"))

  expect_false(attr(result, "ontology_release")$manifest_verified)
  expect_true(file.exists(file.path(cache, "smn", "0.0.3", "MANIFEST.sha256.absent")))
  expect_identical(length(log$requests), 3L)
})

test_that("a manifest that cannot be fetched stops the read, and the next call tries again", {
  or_fresh_indexes()
  cache <- withr::local_tempdir()
  local_mocked_bindings(.ms_release_session_cache_root = function() cache)
  owl <- or_fixture("smn-0.0.3", "smn.owl")
  manifest_route <- function(url, accept) or_answer(url, 503L)
  or_routes(list(
    "https://w3id.org/smn/0.0.3" = or_serve_file(owl),
    "https://salmon-data-mobilization.github.io/salmon-domain-ontology/releases/0.0.3/MANIFEST.sha256" =
      function(url, accept) manifest_route(url, accept)
  ))

  expect_error(
    find_terms("escapement", sources = "smn", release = c(smn = "0.0.3")),
    "Could not establish",
    class = "metasalmon_ontology_release_error"
  )

  manifest_route <- function(url, accept) or_answer(url, 200L, paste0(or_sha256(owl), "  smn.owl\n"))
  result <- find_terms("escapement", sources = "smn", release = c(smn = "0.0.3"))
  expect_true(attr(result, "ontology_release")$manifest_verified)
})

test_that("a downloaded copy that fails its manifest is removed so the next call fetches it again", {
  or_fresh_indexes()
  cache <- withr::local_tempdir()
  local_mocked_bindings(.ms_release_session_cache_root = function() cache)
  owl <- or_fixture("smn-0.0.3", "smn.owl")
  or_routes(list(
    "https://w3id.org/smn/0.0.3" = or_serve_file(owl),
    "https://salmon-data-mobilization.github.io/salmon-domain-ontology/releases/0.0.3/MANIFEST.sha256" =
      function(url, accept) or_answer(url, 200L, paste0(strrep("a", 64), "  smn.owl\n"))
  ))

  expect_error(
    find_terms("escapement", sources = "smn", release = c(smn = "0.0.3")),
    "does not match",
    class = "metasalmon_ontology_release_error"
  )
  expect_false(file.exists(file.path(cache, "smn", "0.0.3", "smn.owl")))
})

test_that("a release that serves no file is an error, not an empty source", {
  or_fresh_indexes()
  cache <- withr::local_tempdir()
  local_mocked_bindings(.ms_release_session_cache_root = function() cache)
  or_routes(list())
  expect_error(
    find_terms("escapement", sources = "smn", release = c(smn = "9.9.9")),
    "serves none of the files",
    class = "metasalmon_ontology_release_error"
  )
})

# ---------------------------------------------------------------------------
# fetch_salmon_ontology()
# ---------------------------------------------------------------------------

test_that("fetch_salmon_ontology() returns the snapshot file accept prefers", {
  or_no_network()
  dir <- or_snapshot("smn-0.0.3")

  expect_identical(fetch_salmon_ontology(snapshot_dir = dir), file.path(dir, "smn.ttl"))
  expect_identical(
    fetch_salmon_ontology(accept = "text/turtle;q=0.5, application/rdf+xml", snapshot_dir = dir),
    file.path(dir, "smn.owl")
  )
  # A representation the snapshot lacks gives way to the next one asked for.
  expect_identical(
    fetch_salmon_ontology(accept = "application/ld+json, application/rdf+xml;q=0.9", snapshot_dir = dir),
    file.path(dir, "smn.owl")
  )
  expect_error(
    fetch_salmon_ontology(accept = "application/ld+json", snapshot_dir = dir),
    "holds none of the files",
    class = "metasalmon_ontology_release_error"
  )
  expect_error(
    fetch_salmon_ontology(accept = "text/html", snapshot_dir = dir),
    "no representation",
    class = "metasalmon_ontology_release_error"
  )

  tampered <- or_snapshot("smn-0.0.3", manifest = paste0(strrep("0", 64), "  smn.ttl"))
  expect_error(
    fetch_salmon_ontology(snapshot_dir = tampered),
    "does not match",
    class = "metasalmon_ontology_release_error"
  )
})

test_that("fetch_salmon_ontology() downloads a release into cache_dir once", {
  cache <- withr::local_tempdir()
  ttl <- or_fixture("smn-0.0.3", "smn.ttl")
  log <- or_routes(list(
    "https://w3id.org/smn/0.0.3" = or_serve_file(ttl),
    "https://salmon-data-mobilization.github.io/salmon-domain-ontology/releases/0.0.3/MANIFEST.sha256" =
      function(url, accept) or_answer(url, 200L, paste0(or_sha256(ttl), "  smn.ttl\n"))
  ))

  first <- fetch_salmon_ontology(release = "0.0.3", cache_dir = cache)
  second <- fetch_salmon_ontology(release = "0.0.3", cache_dir = cache)

  expected <- file.path(cache, "releases", "smn", "0.0.3", "smn.ttl")
  expect_identical(first, expected)
  expect_identical(second, expected)
  expect_identical(or_sha256(first), or_sha256(ttl))
  expect_identical(length(log$requests), 2L)
  expect_identical(log$requests[[1]]$accept, "text/turtle")
})

test_that("fetch_salmon_ontology() pins only smn and gcdfo, and says what it ignores", {
  or_no_network()
  dir <- or_snapshot("gcdfo-0.0.9")
  expect_identical(
    fetch_salmon_ontology(
      url = "https://w3id.org/gcdfo/salmon",
      accept = "application/rdf+xml",
      snapshot_dir = dir
    ),
    file.path(dir, "gcdfo.owl")
  )
  expect_error(
    fetch_salmon_ontology(url = "https://example.org/onto", release = "1.0.0"),
    "smn or gcdfo",
    class = "metasalmon_ontology_release_error"
  )
  expect_error(
    fetch_salmon_ontology(release = "latest"),
    "three numbers",
    class = "metasalmon_ontology_release_error"
  )
  smn <- or_snapshot("smn-0.0.3")
  # The file is not parsed, so nothing could check the directory is 0.0.3.
  expect_error(
    fetch_salmon_ontology(release = "0.0.3", snapshot_dir = smn),
    "not both",
    class = "metasalmon_ontology_release_error"
  )
  expect_warning(
    fetch_salmon_ontology(snapshot_dir = smn, fallback_urls = "https://example.org/mirror"),
    "not used"
  )
})
