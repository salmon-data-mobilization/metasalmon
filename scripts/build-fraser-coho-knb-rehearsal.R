#!/usr/bin/env Rscript
# Build the Fraser coho "gold standard" SDP and rehearse a KNB test-node deposit.
#
# WHY THIS SCRIPT EXISTS
# ----------------------
# `inst/extdata/nuseds-fraser-coho-2023-2024.csv` plus its shipped starter
# dictionary is the package's realistic worked example. Taking it all the way to
# a publishable Salmon Data Package -- one that gets a clean
# `publish_sdp_to_knb(dry_run = TRUE)` plan -- requires reviewed decisions that
# `create_sdp()` deliberately does not guess, and three publication artifacts
# that **no exported metasalmon function writes** (see STAGE 5 and STAGE 6).
#
# This script is the executable record of those decisions, so the workshop can
# teach the golden path instead of reconstructing it from a transcript.
#
# It never contacts KNB with credentials and never performs a live deposit. It
# does reach the network to read the `smn`/`gcdfo` ontologies (deterministic
# term search only). **It never enables LLM review**: `llm_assess` is left at
# its `FALSE` default throughout, per the package's opt-in contract.
#
# USAGE
# -----
#   Rscript scripts/build-fraser-coho-knb-rehearsal.R [output_dir]
#
# Default output_dir is "~/code/knb-rehearsal/fraser-coho-2023-2024".
# The directory is rebuilt from scratch on every run.

suppressMessages({
  library(dplyr)
  library(readr)
  library(tibble)
})

if (requireNamespace("pkgload", quietly = TRUE) &&
    file.exists("DESCRIPTION")) {
  pkgload::load_all(".", quiet = TRUE)
} else {
  library(metasalmon)
}

args <- commandArgs(trailingOnly = TRUE)
pkg_path <- if (length(args) >= 1L) {
  args[[1]]
} else {
  path.expand("~/code/knb-rehearsal/fraser-coho-2023-2024")
}

dataset_id <- "fraser-coho-2023-2024"
table_id <- "escapement"

say <- function(...) cat("\n== ", ..., "\n", sep = "")

`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0L || all(is.na(x))) y else x
}

# The metadata-provider ORCID is load-bearing, not decorative: a live deposit
# requires the EML to name exactly ONE metadata-provider ORCID, and it must
# match the ORCID-authenticated DataONE subject behind the token. It cannot be
# guessed. Set MS_METADATA_PROVIDER_ORCID before a live run.
#
# The default below is ORCID's own documentation example (a fictional
# researcher), carried over from `inst/extdata/eml-mapping-template.yml`. It
# lets the credential-free dry run complete; a live deposit with it will be
# refused by DataONE, which is the intended safe failure.
metadata_provider_orcid <- Sys.getenv("MS_METADATA_PROVIDER_ORCID", "")
orcid_is_placeholder <- !nzchar(metadata_provider_orcid)
if (orcid_is_placeholder) {
  metadata_provider_orcid <- "https://orcid.org/0000-0002-1825-0097"
}

# ---------------------------------------------------------------------------
# STAGE 1 -- build the starter package from the shipped 173-row example
# ---------------------------------------------------------------------------
# Ordinary `create_sdp()`. `seed_semantics = TRUE` runs deterministic ontology
# search over smn/gcdfo/ols/nvs; `llm_assess` stays FALSE (its default), so no
# LLM call is made. This is exactly what a user gets on day one.

say("STAGE 1: create_sdp() from the shipped example")

example_csv <- system.file(
  "extdata",
  "nuseds-fraser-coho-2023-2024.csv",
  package = "metasalmon"
)
stopifnot(nzchar(example_csv))

raw <- readr::read_csv(example_csv, show_col_types = FALSE, progress = FALSE)

if (dir.exists(pkg_path)) {
  unlink(pkg_path, recursive = TRUE)
}
dir.create(pkg_path, recursive = TRUE, showWarnings = FALSE)

create_sdp(
  resources = stats::setNames(list(raw), table_id),
  path = pkg_path,
  dataset_id = dataset_id,
  table_id = table_id,
  seed_semantics = TRUE,
  seed_verbose = FALSE,
  check_updates = FALSE,
  overwrite = TRUE
)

# ---------------------------------------------------------------------------
# STAGE 2 -- install the shipped starter dictionary
# ---------------------------------------------------------------------------
# The example ships a hand-reviewed starter dictionary. It is the reviewed
# artifact for this example, so it replaces the generated one wholesale rather
# than being merged. Since the gold-standard annotation fix, its one measurement
# row carries the full `term_iri`/`property_iri`/`entity_iri`/`unit_iri` set.
#
# `entity_iri` is `smn:Population`, NOT `gcdfo:ConservationUnit` as the 30-row
# demo uses: this example keys on POP_ID, which is a finer grain than a CU.

say("STAGE 2: install the shipped starter dictionary")

file.copy(
  system.file(
    "extdata",
    "nuseds-fraser-coho-2023-2024-column_dictionary.csv",
    package = "metasalmon"
  ),
  file.path(pkg_path, "metadata", "column_dictionary.csv"),
  overwrite = TRUE
)

# ---------------------------------------------------------------------------
# STAGE 3 -- fill the reviewed dataset- and table-level metadata
# ---------------------------------------------------------------------------
# `create_sdp()` writes `MISSING METADATA:` placeholders for facts it cannot
# know. Strict validation refuses to ship them. These are the reviewed values
# for this rehearsal deposit; change them for any other deposit.

say("STAGE 3: fill reviewed dataset and table metadata")

# Defined once here and reused verbatim in the EML sidecar in STAGE 6.
# `write_eml_from_sdp()` requires the two to be byte-identical, so there must be
# exactly one copy of each string in this script.
source_citation <- paste(
  "Fisheries and Oceans Canada. 2025. New Salmon Escapement Database System",
  "(NuSEDS): Fraser and BC Interior NuSEDS_20251014. Open Government Portal",
  "record c48669a3-045b-400d-b730-48aafe8c5ee6."
)
provenance_note <- paste(
  "Filtered from the official Fraser and BC Interior NuSEDS workbook to coho,",
  "analysis years 2023-2024, and a compact column subset; START_DTT and END_DTT",
  "were converted to ISO dates. See data-raw/nuseds_fraser_coho_examples.R in",
  "the metasalmon repository."
)

dataset_meta <- readr::read_csv(
  file.path(pkg_path, "metadata", "dataset.csv"),
  col_types = readr::cols(.default = readr::col_character()),
  na = "",
  show_col_types = FALSE,
  progress = FALSE
)

dataset_meta$description <- paste(
  "Adult coho salmon spawner escapement estimates for Fraser River",
  "populations, 2023-2024, derived from the DFO New Salmon Escapement",
  "Database System (NuSEDS). Each row is one population-year escapement",
  "estimate with its estimation method, classification, and survey window.",
  "Published as a Salmon Data Package to rehearse the metasalmon deposit",
  "path against the KNB test node."
)
dataset_meta$creator <- "Pacific Salmon Commission"
dataset_meta$contact_name <- "Brett Johnson"
dataset_meta$contact_email <- "johnson@psc.org"
dataset_meta$license <- "CC-BY-4.0"
dataset_meta$source_citation <- source_citation
dataset_meta$provenance_note <- provenance_note

readr::write_csv(
  dataset_meta,
  file.path(pkg_path, "metadata", "dataset.csv"),
  na = ""
)

table_meta <- readr::read_csv(
  file.path(pkg_path, "metadata", "tables.csv"),
  col_types = readr::cols(.default = readr::col_character()),
  na = "",
  show_col_types = FALSE,
  progress = FALSE
)

table_meta$description <- paste(
  "One row per Fraser coho population and analysis year: the natural adult",
  "spawner escapement estimate with its method, classification, stage, and",
  "survey window."
)
# The row grain is an observation, so the observation unit is `smn:Observation`.
# A blank `observation_unit_iri` does not block EDH rebuild, but it IS a
# canonical review target, so the reviewed ledger in STAGE 5 must account for it.
table_meta$observation_unit_iri <- "https://w3id.org/smn/Observation"

readr::write_csv(
  table_meta,
  file.path(pkg_path, "metadata", "tables.csv"),
  na = ""
)

# ---------------------------------------------------------------------------
# STAGE 4 -- strict validation (the final SDP gate)
# ---------------------------------------------------------------------------

say("STAGE 4: strict validation")

validate_salmon_datapackage(pkg_path, require_iris = TRUE)

pkg <- read_salmon_datapackage(pkg_path)

# ---------------------------------------------------------------------------
# STAGE 5 -- the reviewed closure: semantic vocabulary + review ledger
# ---------------------------------------------------------------------------
# !! GOLDEN-PATH GAP !!
#
# `write_eml_from_sdp()` and `publish_sdp_to_knb()` both require a "reviewed
# closure": `metadata/semantic_vocabulary.csv` (one evidence row per canonical
# measurement IRI) and `reviewed_semantic_selections.csv` (exactly one
# `accepted` row per canonical review target).
#
# NEITHER FILE HAS AN EXPORTED PRODUCER. metasalmon only validates them. The
# only code that builds them lives in `tests/testthat/helper-eml.R`, and no
# vignette mentions either filename. That is why the two blocks below reach into
# `metasalmon:::` for the canonical target set and the row digest -- a user
# following the published docs cannot do this at all. See backlog #116.
#
# Everything that CAN come from the real pipeline does: the term evidence below
# is read back out of the ontologies with the exported `find_terms()`, not
# transcribed.

say("STAGE 5: build the reviewed closure (vocabulary + ledger)")

# The search a reviewer ran to select each accepted IRI. Re-running it is what
# supplies label/definition/source/ontology/resource_kind/type_iris evidence.
review_searches <- tibble::tribble(
  ~iri, ~role, ~query,
  "https://w3id.org/gcdfo/salmon#SpawnerAbundance", "variable", "spawner abundance",
  "https://w3id.org/smn/Abundance", "property", "abundance",
  "https://w3id.org/smn/Population", "entity", "population"
)

# `native_type` and `source_url` are the two evidence fields `find_terms()` does
# NOT return, so they are supplied per source. `source_artifact_sha256` is
# optional and left empty: these are live w3id resolutions, not pinned release
# artifacts.
source_urls <- c(
  smn = "https://w3id.org/smn/",
  gcdfo = "https://w3id.org/gcdfo/salmon",
  qudt = "https://qudt.org/vocab/unit/"
)
native_type_for <- function(resource_kind) {
  switch(
    tolower(resource_kind),
    class = "owl:Class",
    namedindividual = "owl:NamedIndividual",
    concept = "skos:Concept",
    paste0("owl:", resource_kind)
  )
}

resolve_term <- function(iri, role, query) {
  hits <- find_terms(query, role = role, sources = c("smn", "gcdfo"))
  hit <- hits[hits$iri == iri, , drop = FALSE]
  if (nrow(hit) != 1L) {
    stop(
      "Reviewed IRI ", iri, " was not returned by find_terms(\"", query,
      "\", role = \"", role, "\"). The reviewed evidence cannot be rebuilt.",
      call. = FALSE
    )
  }
  hit <- hit[1, , drop = FALSE]
  stopifnot(nzchar(as.character(hit$definition[[1]] %||% "")))
  tibble::tibble(
    iri = iri,
    label = as.character(hit$label[[1]]),
    definition = as.character(hit$definition[[1]]),
    source = as.character(hit$source[[1]]),
    ontology = as.character(hit$ontology[[1]]),
    resource_kind = as.character(hit$resource_kind[[1]]),
    type_iris = as.character(hit$type_iris[[1]] %||% ""),
    native_type = native_type_for(as.character(hit$resource_kind[[1]])),
    source_url = unname(source_urls[[as.character(hit$source[[1]])]]),
    source_artifact_sha256 = ""
  )
}

vocabulary <- purrr::pmap_dfr(review_searches, function(iri, role, query) {
  message("  resolving ", iri)
  resolve_term(iri, role, query)
})

# QUDT is not one of `find_terms()`'s searchable sources, so the unit's evidence
# is supplied from the reviewed dictionary row plus the QUDT vocabulary itself.
# This is a second, narrower gap: the closure demands provenance evidence for
# vocabularies the package cannot search. See backlog #116.
vocabulary <- dplyr::bind_rows(
  vocabulary,
  tibble::tibble(
    iri = "https://qudt.org/vocab/unit/INDIV",
    label = "Individual",
    definition = paste(
      "A counting unit denoting one organism, used to express abundance as a",
      "number of individuals."
    ),
    source = "qudt",
    ontology = "qudt",
    resource_kind = "Unit",
    type_iris = "http://qudt.org/schema/qudt/Unit",
    native_type = "qudt:Unit",
    source_url = "https://qudt.org/vocab/unit/",
    source_artifact_sha256 = ""
  )
)

# The closure must describe EXACTLY the canonical measurement IRI set: no more,
# no less. Check that before writing, so a mismatch is a clear failure here
# rather than an abort three stages later.
canonical_iris <- metasalmon:::.ms_eml_canonical_measurement_iris(pkg_path, pkg)
stopifnot(setequal(canonical_iris, vocabulary$iri))

# `reviewed_snapshot_sha256` binds each row to its own evidence. There is no
# exported way to compute it, and hand-writing a SHA-256 into a CSV is not a
# workflow -- that is the core of the gap.
vocabulary$reviewed_snapshot_sha256 <- vapply(
  seq_len(nrow(vocabulary)),
  function(i) {
    metasalmon:::.ms_eml_vocabulary_snapshot_sha256(
      vocabulary[i, , drop = FALSE]
    )
  },
  character(1)
)

vocabulary_path <- file.path(pkg_path, "metadata", "semantic_vocabulary.csv")
readr::write_csv(vocabulary, vocabulary_path, na = "")

# The ledger records one accepted decision per canonical review target. The
# target set (which includes the table-scope `observation_unit_iri` that the
# vocabulary does not) is derived, not transcribed, so it cannot drift from the
# dictionary.
targets <- metasalmon:::.ms_eml_canonical_review_targets(pkg)

rationales <- c(
  "https://w3id.org/gcdfo/salmon#SpawnerAbundance" =
    "The column is an escapement estimate of adult spawners, which is what the released gcdfo class denotes.",
  "https://w3id.org/smn/Abundance" =
    "The measured characteristic is abundance; the unit carries the counting representation separately.",
  "https://w3id.org/smn/Population" =
    "Rows key on POP_ID, a population, which is a finer grain than a Conservation Unit.",
  "https://qudt.org/vocab/unit/INDIV" =
    "Values are whole counts of organisms, expressed in QUDT Individual.",
  "https://w3id.org/smn/Observation" =
    "Each row is one population-year escapement observation."
)

review <- targets |>
  dplyr::mutate(
    decision = "accepted",
    confidence = "high",
    review_rationale = unname(rationales[.data$iri])
  ) |>
  dplyr::select(
    dataset_id, table_id, column_name, target_scope, target_sdp_field,
    dictionary_role, decision, confidence, review_rationale, iri
  )

stopifnot(!anyNA(review$review_rationale))

review_path <- file.path(pkg_path, "reviewed_semantic_selections.csv")
readr::write_csv(review, review_path, na = "")

# ---------------------------------------------------------------------------
# STAGE 6 -- the reviewed EML sidecar
# ---------------------------------------------------------------------------
# `metadata/eml-mapping.yml` also has no exported producer, but unlike the two
# files above it is documented: `inst/extdata/eml-mapping-template.yml` ships for
# exactly this, and the post-review vignette tells you to copy and edit it.
#
# The two SHA-256 values must be recomputed by hand every time either closure
# file changes. Doing that in a script is the only way to keep them honest.

say("STAGE 6: write the reviewed EML sidecar")

file_sha256 <- function(p) {
  digest::digest(file = p, algo = "sha256", serialize = FALSE)
}

# `source_provenance.supporting_document` is mandatory in the sidecar schema,
# and its `sha256` is mandatory too: the reviewed sidecar pins the exact bytes
# of a document that supports the provenance claim. Nothing in metasalmon
# computes or pins it for you.
#
# The document used here is the package's own example-data README as published
# at the v0.4.0 tag, which is what documents this example's derivation. A tagged
# URL is immutable, so the pin below stays truthful even after the README is
# edited on main -- what is cited is the v0.4.0 bytes, not the working tree.
#
# The digest was verified against the live URL when it was pinned (2026-08-25).
# Set MS_VERIFY_SUPPORTING_DOCUMENT=1 to re-verify over the network.
# Retire the pin by bumping `readme_tag` to a later release and re-verifying;
# nothing else in this script depends on which release is cited.
readme_tag <- "v0.4.0"
readme_sha256 <-
  "d859fa2a3d4a0e62f8ea0e45517b8437dc288de7bb872c556667652f42899bb7"
readme_url <- paste0(
  "https://raw.githubusercontent.com/salmon-data-mobilization/metasalmon/",
  readme_tag, "/inst/extdata/example-data-README.md"
)

if (nzchar(Sys.getenv("MS_VERIFY_SUPPORTING_DOCUMENT"))) {
  fetched <- tempfile(fileext = ".md")
  utils::download.file(readme_url, fetched, quiet = TRUE, mode = "wb")
  if (!identical(file_sha256(fetched), readme_sha256)) {
    stop(
      "The pinned supporting document at ", readme_url,
      " no longer hashes to ", readme_sha256, ".",
      call. = FALSE
    )
  }
  message("  supporting document verified against ", readme_tag)
}

supporting_document <- list(
  citation = paste(
    "metasalmon contributors. Built-in NuSEDS example data: provenance and",
    "reproducible derivation.", readme_tag, "."
  ),
  url = readme_url,
  sha256 = readme_sha256
)

mapping <- list(
  version = 1L,
  status = "final",
  dataset_id = dataset_id,
  series_key = "psc-fraser-coho-escapement",
  system = "knb",
  language = "eng",
  publication_date = format(Sys.Date()),
  semantic_vocabulary = list(
    path = "metadata/semantic_vocabulary.csv",
    sha256 = file_sha256(vocabulary_path)
  ),
  semantic_review = list(
    path = "reviewed_semantic_selections.csv",
    sha256 = file_sha256(review_path)
  ),
  publication = list(public = FALSE),
  rights_authorization = list(
    status = "confirmed",
    evidence = paste(
      "Derived from NuSEDS data published by Fisheries and Oceans Canada under",
      "the Open Government Licence - Canada, which permits redistribution with",
      "attribution."
    )
  ),
  source_provenance = list(
    source_citation = source_citation,
    provenance_note = provenance_note,
    supporting_document = supporting_document
  ),
  creators = list(
    list(organization_name = "Pacific Salmon Commission")
  ),
  metadata_providers = list(
    list(
      given_name = "Brett",
      surname = "Johnson",
      organization_name = "Pacific Salmon Commission",
      email = "johnson@psc.org",
      orcid = metadata_provider_orcid
    )
  ),
  contacts = list(
    list(
      organization_name = "Pacific Salmon Commission",
      email = "johnson@psc.org"
    )
  ),
  publisher = list(organization_name = "Pacific Salmon Commission"),
  intellectual_rights = list(
    paragraphs = c(
      paste(
        "Contains information licensed under the Open Government Licence -",
        "Canada (https://open.canada.ca/en/open-government-licence-canada)."
      ),
      paste(
        "This Salmon Data Package is redistributed under CC-BY-4.0",
        "(https://creativecommons.org/licenses/by/4.0/)."
      )
    )
  ),
  methods = list(
    list(
      description = paste(
        "Escapement estimates were compiled by Fisheries and Oceans Canada",
        "through NuSEDS. Each row records the estimate together with the",
        "enumeration method, estimate classification, and survey window",
        "reported for that population and analysis year."
      )
    )
  ),
  taxonomic_coverage = list(
    scientific_name = "Oncorhynchus kisutch",
    common_name = "Coho salmon",
    rank = "Species"
  ),
  tables = stats::setNames(
    list(list(attributes = list())),
    table_id
  )
)

# EML needs a measurement scale for every attribute. Derive them from the
# reviewed dictionary rather than restating the column list, so a dictionary
# edit cannot silently desynchronise the sidecar.
dict <- pkg$dictionary[pkg$dictionary$table_id == table_id, , drop = FALSE]

attribute_spec <- function(row) {
  value_type <- as.character(row$value_type[[1]])
  role <- as.character(row$column_role[[1]])
  if (identical(value_type, "date")) {
    return(list(measurement_scale = "dateTime", format_string = "YYYY-MM-DD"))
  }
  if (identical(role, "measurement") &&
      value_type %in% c("integer", "number")) {
    return(list(
      measurement_scale = "ratio",
      eml_unit = "number",
      number_type = if (identical(value_type, "integer")) "whole" else "real",
      minimum = 0,
      minimum_exclusive = FALSE
    ))
  }
  if (value_type %in% c("integer", "number")) {
    # Identifiers and years are numeric but are not ratio measurements.
    return(list(measurement_scale = "nominal"))
  }
  list(measurement_scale = "nominal")
}

mapping$tables[[table_id]]$attributes <- stats::setNames(
  lapply(seq_len(nrow(dict)), function(i) attribute_spec(dict[i, , drop = FALSE])),
  as.character(dict$column_name)
)

yaml::write_yaml(mapping, file.path(pkg_path, "metadata", "eml-mapping.yml"))

# ---------------------------------------------------------------------------
# STAGE 7 -- build reviewed EML, then rehearse the test-node plan
# ---------------------------------------------------------------------------

say("STAGE 7: write reviewed EML and rehearse the KNB test-node plan")

write_eml_from_sdp(pkg_path, overwrite = TRUE, knb_environment = "test")

plan <- publish_sdp_to_knb(
  pkg_path,
  public = FALSE,
  dry_run = TRUE,
  representation = "expanded",
  knb_environment = "test",
  overwrite = TRUE
)

say("DONE")

manifest <- jsonlite::fromJSON(
  file.path(pkg_path, "publication", "test", "knb-manifest.json"),
  simplifyVector = FALSE
)

cat("Package:      ", pkg_path, "\n", sep = "")
cat("Environment:  ", manifest$knb_environment, " (", manifest$node_id, ")\n", sep = "")
cat("Status:       ", manifest$status, "\n", sep = "")
cat("Objects:      ", length(manifest$objects), "\n", sep = "")
cat("package_id:   ", manifest$package_id, "\n", sep = "")
cat("series_id:    ", manifest$series_id, "\n", sep = "")
cat("Subject:      ", manifest$expected_subject, "\n", sep = "")
for (object in manifest$objects) {
  cat("  - ", object$role, ": ", object$path, "\n", sep = "")
}

if (orcid_is_placeholder) {
  cat(
    "\n!! The metadata-provider ORCID is the placeholder from the shipped\n",
    "!! template. A live deposit will be refused until you re-run with\n",
    "!! MS_METADATA_PROVIDER_ORCID set to the ORCID behind your DataONE token.\n",
    sep = ""
  )
}

cat("\nLive test-node deposit (token already in options(dataone_test_token = ...)):\n")
cat(sprintf(
  'publish_sdp_to_knb("%s", public = FALSE, dry_run = FALSE, confirm = TRUE, representation = "expanded", knb_environment = "test")\n',
  pkg_path
))

invisible(plan)
