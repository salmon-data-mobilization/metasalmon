#!/usr/bin/env Rscript
# Build the Fraser coho "gold standard" SDP and rehearse a KNB test-node deposit.
#
# WHY THIS SCRIPT EXISTS
# ----------------------
# `inst/extdata/nuseds-fraser-coho-2023-2024.csv` plus its shipped starter
# dictionary is the package's realistic worked example. Taking it all the way to
# a publishable Salmon Data Package -- one that gets a clean
# `publish_sdp_to_knb(dry_run = TRUE)` plan -- requires reviewed decisions that
# `create_sdp()` deliberately does not guess.
#
# This script is the executable record of those decisions, so the workshop can
# teach the golden path instead of reconstructing it from a transcript.
#
# EVERY CALL IT MAKES IS AN EXPORTED ONE. Until 2026-09-14 it reached into
# `metasalmon:::` at three sites, because the reviewed semantic closure had no
# exported producer; STAGE 6 now goes through `write_sdp_semantic_closure()`
# instead (backlog #116, hub item B-116). The reviewed EML sidecar assembled in
# STAGE 5 is the one publication artifact still built here by hand, and that is
# a documented step rather than a gap: a template ships for it and the
# post-review vignette says to copy and edit it.
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
# STAGE 5 -- the reviewed EML sidecar
# ---------------------------------------------------------------------------
# `metadata/eml-mapping.yml` has no exported producer either, but unlike the two
# closure files it is documented: `inst/extdata/eml-mapping-template.yml` ships
# for exactly this, and the post-review vignette tells you to copy and edit it.
#
# THE SIDECAR IS NOW WRITTEN BEFORE THE CLOSURE, and the ordering is the point.
# The sidecar declares where both closure files live and pins their bytes; since
# 2026-09-14 `write_sdp_semantic_closure()` reads those declared paths and writes
# the two digests back into this file in place, so the placeholders below are
# filled by STAGE 6 and this script computes no file digest of its own. That is
# also the order a user follows: copy the template, fill in the reviewed values,
# then produce the closure.

say("STAGE 5: write the reviewed EML sidecar")

# The digest placeholder the shipped template carries. STAGE 6 replaces both.
unpinned_sha256 <- paste(rep("0", 64), collapse = "")

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
  fetched_sha256 <- digest::digest(
    file = fetched, algo = "sha256", serialize = FALSE
  )
  if (!identical(fetched_sha256, readme_sha256)) {
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
    sha256 = unpinned_sha256
  ),
  semantic_review = list(
    path = "reviewed_semantic_selections.csv",
    sha256 = unpinned_sha256
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
# STAGE 6 -- the reviewed closure: semantic vocabulary + review ledger
# ---------------------------------------------------------------------------
# `write_eml_from_sdp()` and `publish_sdp_to_knb()` both require a "reviewed
# closure": `metadata/semantic_vocabulary.csv` (one evidence row per canonical
# measurement IRI) and `reviewed_semantic_selections.csv` (exactly one
# `accepted` row per canonical review target).
#
# THIS STAGE USED TO BE THE GOLDEN-PATH GAP. Until 2026-09-14 neither file had
# an exported producer, and this script reached into `metasalmon:::` at three
# sites to build them: for the canonical measurement IRI set, for the canonical
# review-target set, and for each vocabulary row's snapshot digest. All three now
# come back from the one exported `write_sdp_semantic_closure()` (backlog #116,
# hub item B-116), so nothing this script does is out of reach of a user
# following the published documentation.
#
# What still has to be supplied by hand, and why each one genuinely cannot be
# derived:
#
#   * the QUDT unit row in full, because QUDT is not one of `find_terms()`'s
#     searchable sources at all;
#   * `confidence` and `review_rationale` for every target, because they are the
#     reviewer's judgement and no search produces one. Omitting them is not an
#     error -- the producer writes a `REVIEW REQUIRED:` marker and warns -- but a
#     rehearsal that shipped a marker would be rehearsing the wrong thing.
#
# Everything else -- label, definition, source, ontology, resource_kind,
# type_iris -- the producer reads back out of smn/gcdfo with `find_terms()`, so
# the evidence is resolved rather than transcribed. `llm_assess` is not involved:
# there is no such argument on this path.

say("STAGE 6: build the reviewed closure (vocabulary + ledger)")

# The reviewer's judgement, one row per accepted IRI. `smn:Observation` is here
# because it is the table's `observation_unit_iri`: a canonical REVIEW TARGET
# that is deliberately NOT a measurement vocabulary term, which is why the ledger
# has five rows and the vocabulary four.
closure_evidence <- tibble::tribble(
  ~iri, ~confidence, ~review_rationale,
  "https://w3id.org/gcdfo/salmon#SpawnerAbundance", "high",
  "The column is an escapement estimate of adult spawners, which is what the released gcdfo class denotes.",
  "https://w3id.org/smn/Abundance", "high",
  "The measured characteristic is abundance; the unit carries the counting representation separately.",
  "https://w3id.org/smn/Population", "high",
  "Rows key on POP_ID, a population, which is a finer grain than a Conservation Unit.",
  "https://w3id.org/smn/Observation", "high",
  "Each row is one population-year escapement observation."
)

# The QUDT row: hand-authored end to end, because `find_terms()` cannot search
# QUDT. `source_artifact_sha256` is left empty on purpose -- these are live w3id
# and QUDT resolutions, not pinned release artifacts.
closure_evidence <- dplyr::bind_rows(
  closure_evidence,
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
    confidence = "high",
    review_rationale =
      "Values are whole counts of organisms, expressed in QUDT Individual."
  )
)

closure <- write_sdp_semantic_closure(pkg_path, evidence = closure_evidence)

# The producer reports an IRI it cannot resolve as a term-request gap and writes
# the files anyway, which is right for a user and wrong for a rehearsal: every
# IRI in this example is a released term, so a gap here means something regressed
# in the ontologies or in retrieval. Fail loudly rather than deposit a short
# vocabulary.
if (nrow(closure$gaps) > 0L) {
  stop(
    "The reviewed closure could not resolve ",
    paste(closure$gaps$unresolved_iri, collapse = ", "),
    ". Every IRI in this example is a released term, so this is a regression ",
    "rather than an ontology gap; inspect closure$gaps.",
    call. = FALSE
  )
}
if (nrow(closure$placeholders) > 0L) {
  stop(
    "The reviewed closure left a REVIEW REQUIRED: rationale on ",
    nrow(closure$placeholders),
    " target(s); add them to `closure_evidence` above.",
    call. = FALSE
  )
}

# Each file must describe EXACTLY its canonical set: no more, no less. Both sets
# now come back from the exported producer, so these are checks on the rehearsal
# rather than a reconstruction of the package's internals.
stopifnot(setequal(closure$measurement_iris, closure$vocabulary$iri))
stopifnot(nrow(closure$review) == nrow(closure$review_targets))
stopifnot(
  identical(
    setdiff(closure$review_targets$iri, closure$measurement_iris),
    "https://w3id.org/smn/Observation"
  )
)

# And the producer pinned both digests into the sidecar STAGE 5 left unpinned, so
# no SHA-256 in this package was written by hand.
pinned <- yaml::read_yaml(file.path(pkg_path, "metadata", "eml-mapping.yml"))
stopifnot(
  !identical(pinned$semantic_vocabulary$sha256, unpinned_sha256),
  !identical(pinned$semantic_review$sha256, unpinned_sha256)
)

vocabulary_path <- closure$files[["vocabulary"]]
review_path <- closure$files[["review"]]

message(
  "  ", nrow(closure$vocabulary), " vocabulary rows, ",
  nrow(closure$review), " ledger rows, sidecar digests pinned"
)

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
