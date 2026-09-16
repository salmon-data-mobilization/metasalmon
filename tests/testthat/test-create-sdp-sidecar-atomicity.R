# Backlog #111: `create_sdp()` writes three sidecars of its own AFTER the
# generic package writer has run, and each was unlink-then-rewrite -- the exact
# shape #96 retired for the package writer, at single-file blast radius. An
# abort between the unlink and the completed rewrite destroyed the file.
#
# Re-running `create_sdp()` regenerates all three, so the loss only matters for
# a copy the user has changed: an annotated `README-review.txt`, a
# `semantic_suggestions.csv` carrying review decisions, or the EDH XML of a
# package whose metadata has since moved on. Each test below therefore puts
# recognizable bytes in place first and asserts those exact bytes survive.
#
# The abort is injected at each sidecar's RENDER step, which is where the real
# abort points are -- the EDH builder renders from metadata at write time and is
# the widest of the three. The render is also the one hook the old and the new
# code share, so each of these three tests fails on the pre-fix code (the file
# is gone) and passes on the post-fix code (render-to-bytes, then install
# through `.ms_sdp_extension_atomic_write()`).
#
# Bytes, not parseability: the failure this pins is a truncated or half-written
# sidecar, and a half-written CSV can still parse.

sidecar_fixture_search <- function(query, role = NA_character_,
                                   sources = c("smn", "gcdfo", "ols", "nvs"), ...) {
  hit <- function(label, iri, role, definition, score) {
    tibble::tibble(
      label = label, iri = iri, source = "smn", ontology = "smn", role = role,
      match_type = "label_exact", definition = definition, score = score
    )
  }
  switch(
    as.character(role),
    variable = hit(
      "Spawner Abundance", "https://w3id.org/smn/SpawnerAbundance", "variable",
      "Mature salmon returning to spawn in a stream reach.", 4.9
    ),
    property = hit("Abundance", "https://w3id.org/smn/Abundance", "property", "A count property.", 4.1),
    entity = hit("Spawner", "https://w3id.org/smn/Spawner", "entity", "A mature salmon.", 4.0),
    unit = hit("Count", "http://qudt.org/vocab/unit/NUM", "unit", "A dimensionless count.", 3.9),
    tibble::tibble()
  )
}

sidecar_fixture_create <- function(path, include_edh_xml) {
  suppressMessages(suppressWarnings(with_mocked_bindings(
    find_terms = sidecar_fixture_search,
    create_sdp(
      list(
        spawners = data.frame(
          stream_name = c("Bear Creek", "Elk River"),
          spawner_count = c(120L, 340L),
          stringsAsFactors = FALSE
        )
      ),
      path = path,
      dataset_id = "sidecar-demo",
      semantic_max_per_role = 2,
      seed_semantics = TRUE,
      seed_verbose = FALSE,
      check_updates = FALSE,
      overwrite = TRUE,
      include_edh_xml = include_edh_xml
    )
  )))
}

# `NULL` rather than an error when the file is gone, so a destroyed sidecar
# fails the byte comparison with a legible message instead of blowing up inside
# `readBin()`.
sidecar_bytes <- function(path) {
  if (!file.exists(path)) {
    return(NULL)
  }
  readBin(path, what = "raw", n = file.info(path)$size)
}

test_that("an abort rendering README-review.txt leaves the prior file byte-identical", {
  path <- file.path(withr::local_tempdir(), "readme-abort")
  sidecar_fixture_create(path, include_edh_xml = FALSE)

  readme <- file.path(path, "README-review.txt")
  expect_true(file.exists(readme))
  # Stand in for the copy a reviewer annotated in place: re-running
  # `create_sdp()` cannot bring these lines back.
  writeLines(
    c("Salmon Data Package Review Checklist -- ANNOTATED", "[x] 1. decided on 2026-09-14"),
    readme,
    useBytes = TRUE
  )
  before <- sidecar_bytes(readme)

  real_write_lines <- writeLines
  expect_error(
    with_mocked_bindings(
      writeLines = function(text, con = stdout(), ...) {
        if (identical(as.character(text)[[1]], "Salmon Data Package Review Checklist")) {
          stop("injected abort: README-review.txt render")
        }
        real_write_lines(text, con, ...)
      },
      .package = "base",
      sidecar_fixture_create(path, include_edh_xml = FALSE)
    ),
    "injected abort: README-review.txt render"
  )

  expect_identical(sidecar_bytes(readme), before)
})

test_that("an abort rendering semantic_suggestions.csv leaves the prior file byte-identical", {
  path <- file.path(withr::local_tempdir(), "suggestions-abort")
  sidecar_fixture_create(path, include_edh_xml = FALSE)

  suggestions <- file.path(path, "semantic_suggestions.csv")
  expect_true(file.exists(suggestions))
  # Stand in for the evidence trail after review: the `decision` and
  # `decision_reason` columns `apply_sdp_semantics()` writes are not
  # reconstructible from a re-run.
  writeLines(
    c("column_name,dictionary_role,iri,decision,decision_reason",
      "spawner_count,variable,https://w3id.org/smn/SpawnerAbundance,accepted,reviewed by hand"),
    suggestions,
    useBytes = TRUE
  )
  before <- sidecar_bytes(suggestions)

  # Keyed on the frozen 19-column semantic target row rather than on the
  # destination path: the post-fix code renders to a staging file, so a
  # path-keyed hook would silently stop injecting anything.
  real_write_csv <- readr::write_csv
  expect_error(
    with_mocked_bindings(
      write_csv = function(x, file, ...) {
        if ("target_sdp_field" %in% names(x)) {
          stop("injected abort: semantic_suggestions.csv render")
        }
        real_write_csv(x, file, ...)
      },
      .package = "readr",
      sidecar_fixture_create(path, include_edh_xml = FALSE)
    ),
    "injected abort: semantic_suggestions.csv render"
  )

  expect_identical(sidecar_bytes(suggestions), before)
})

test_that("an abort rendering metadata-edh-hnap.xml leaves the prior file byte-identical", {
  path <- file.path(withr::local_tempdir(), "edh-abort")
  sidecar_fixture_create(path, include_edh_xml = TRUE)

  edh <- file.path(path, "metadata", "metadata-edh-hnap.xml")
  expect_true(file.exists(edh))
  # The widest of the three: this XML is rendered from dataset metadata at
  # write time, so the render is where an abort is most likely, and a package
  # whose metadata has since changed cannot reproduce the old XML.
  writeLines(
    c("<?xml version=\"1.0\"?>", "<gmd:MD_Metadata><!-- shipped to EDH 2026-09-01 --></gmd:MD_Metadata>"),
    edh,
    useBytes = TRUE
  )
  before <- sidecar_bytes(edh)

  expect_error(
    with_mocked_bindings(
      edh_build_hnap_xml = function(...) stop("injected abort: EDH XML render"),
      sidecar_fixture_create(path, include_edh_xml = TRUE)
    ),
    "injected abort: EDH XML render"
  )

  expect_identical(sidecar_bytes(edh), before)
})

test_that("the three create-owned sidecars still round-trip on the happy path", {
  # The atomicity tests above all abort, so nothing in them would notice the
  # rewrite producing different bytes than it used to. This one pins that the
  # rewrite still happens and still lands the generated content.
  path <- file.path(withr::local_tempdir(), "happy-path")
  sidecar_fixture_create(path, include_edh_xml = TRUE)

  readme <- file.path(path, "README-review.txt")
  suggestions <- file.path(path, "semantic_suggestions.csv")
  edh <- file.path(path, "metadata", "metadata-edh-hnap.xml")
  expect_true(all(file.exists(readme, suggestions, edh)))

  first <- lapply(c(readme, suggestions, edh), sidecar_bytes)

  writeLines("clobbered", readme, useBytes = TRUE)
  writeLines("clobbered", suggestions, useBytes = TRUE)
  writeLines("clobbered", edh, useBytes = TRUE)
  sidecar_fixture_create(path, include_edh_xml = TRUE)

  expect_identical(lapply(c(readme, suggestions, edh), sidecar_bytes), first)

  # No staging or backup file is left behind in either directory.
  stray <- c(
    list.files(path, pattern = "-stage-|-backup-", all.files = TRUE),
    list.files(file.path(path, "metadata"), pattern = "-stage-|-backup-", all.files = TRUE)
  )
  expect_identical(stray, character())
})

test_that("no create-owned sidecar is written by a direct filesystem call", {
  # The structural half, modelled on `test-write-datapackage-abort-safety.R`'s
  # guard for `write_salmon_datapackage()`. The three abort injections above
  # each prove one rewrite is safe; this proves a FOURTH direct write has not
  # been added beside them, which is the regression the injections cannot see.
  #
  # Scope, stated because a guard claiming more than it checks is worse than no
  # guard: exactly the two functions that write the three sidecars, and nothing
  # else. `create_sdp()` holds the suggestions and EDH writes; the README write
  # lives in `.ms_write_sdp_review_readme()`. A sidecar write moved into a third
  # function escapes this guard entirely -- so add that function here when one
  # appears.
  #
  # Two tokens are exempted, each for a reason rather than for convenience:
  #   `unlink(`     -- `create_sdp()` DELETES `semantic_suggestions.csv` when
  #                    there is no shortlist to write, and deleting a file is
  #                    already atomic. `.ms_sdp_extension_atomic_write_set()`
  #                    has no delete operation to route it through.
  #   `dir.create(` -- the EDH XML's `metadata/` directory, which the builder
  #                    used to create as a side effect of writing there.
  #                    Creating a directory destroys nothing.
  #
  # Retires when: the three sidecars are rendered into one write set that owns
  # the only filesystem handle, making a stray direct write unrepresentable --
  # or when `create_sdp()` stops writing files of its own.
  exempt <- c("unlink(", "dir.create(")
  mutating_tokens <- setdiff(
    c("write_csv(", "write_json(", "writeLines(", "writeBin(",
      "unlink(", "file.rename(", "file.remove(", "file.copy(",
      "dir.create(", "file.create("),
    exempt
  )
  writers <- c("create_sdp", ".ms_write_sdp_review_readme")

  for (writer in writers) {
    body_text <- paste(
      deparse(body(get(writer, envir = asNamespace("metasalmon")))),
      collapse = "\n"
    )
    for (token in mutating_tokens) {
      expect_false(
        grepl(token, body_text, fixed = TRUE),
        label = sprintf("%s() body contains direct filesystem call %s", writer, token)
      )
    }
  }

  # The exemptions are asserted to be REACHED, not merely permitted. An
  # exemption for a call that is no longer there is a hole nobody can see.
  create_body <- paste(deparse(body(create_sdp)), collapse = "\n")
  for (token in exempt) {
    expect_true(
      grepl(token, create_body, fixed = TRUE),
      label = sprintf("create_sdp() still needs the %s exemption", token)
    )
  }
})
