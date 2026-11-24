# Build the Fraser coho gold-standard Salmon Data Package.
#
# WHAT THIS BUILDS
# ----------------
# inst/extdata/nuseds-fraser-coho-2023-2024-sdp/, a complete Salmon Data
# Package made from inst/extdata/nuseds-fraser-coho-2023-2024.csv (173 rows,
# derived from the official NuSEDS workbook by nuseds_fraser_coho_examples.R
# in this directory). It carries its own dataset.csv, tables.csv,
# column_dictionary.csv and codes.csv, and it must stay clean under both
#   - validate_salmon_datapackage(<pkg>, require_iris = TRUE), and
#   - smn-data-pkg's scripts/validate_package.py.
# tests/testthat/test-fraser-coho-gold-standard.R holds the shipped package to
# the first, offline, and rebuilds it with this script to check that the
# shipped bytes are still the ones this script writes.
#
# USAGE (from the repository root)
# --------------------------------
#   Rscript data-raw/fraser_coho_gold_standard.R
#
# It loads the package from this checkout with pkgload, so the package is
# built by the code it ships with. It is deterministic and offline: it reads
# the shipped CSV and never the network, and it never calls an LLM
# (`llm_assess` stays at its FALSE default).
#
# HOW IT IS BUILT: THE PACKAGE'S OWN FLOW, WITH THE SEARCH STUBBED
# ----------------------------------------------------------------
#   1. create_sdp(seed_semantics = FALSE) writes the review-ready package.
#   2. set_sdp_dataset(), set_sdp_table(), set_sdp_column() and set_sdp_code()
#      fill the free text, from the NuSEDS data dictionary, and the code IRIs.
#   3. suggest_semantics() -> review_semantics() -> accept_suggestion() /
#      reject_suggestion() -> apply_sdp_semantics() decide every semantic slot
#      the flow discovers; the script stops if one is left undecided.
#   4. set_sdp_column() writes the IRIs the flow has no slot for: identifier
#      and temporal columns, and free-text attributes with many values, are
#      never targets.
#   5. validate_salmon_datapackage(require_iris = TRUE), and the canonical
#      files are copied into inst/extdata.
#
# THE SEARCH IS STUBBED. `reviewed_search()` answers every query with the
# searchable rows of `reviewed_vocabulary`, the terms this package uses from
# smn, gcdfo and QUDT, each with its published definition. So step 3 exercises
# target discovery, decision recording and the write-back, not retrieval, and
# every accept names its IRI rather than a rank. Live retrieval, measured on
# 2026-09-26 with create_sdp(seed_semantics = TRUE) over smn, gcdfo, ols and
# nvs, proposed a wrong term for most of these slots -- smn:NaturalOrigin as
# the spawner count's constraint, gcdfo:SpawnerAbundance in its property slot,
# smn:RunContext for RUN_TYPE, smn:SpawnerStageContext for ESTIMATE_STAGE --
# which is why the decisions are recorded here and not taken from it.
#
# Terms were read from the releases the w3id IRIs resolved to on 2026-09-26:
# smn 0.0.3 (https://w3id.org/smn/), gcdfo 0.0.9
# (https://w3id.org/gcdfo/salmon), QUDT 3.5.2 units and Darwin Core
# (http://rs.tdwg.org/dwc/terms/). Column and code text follows the NuSEDS
# data dictionary, Data_Dictionary_NuSEDS_EN.csv (last modified 2025-05-27,
# SHA-256 195a164956d6c748f70856111d48ba9ca6c7d6ae2080736411b89c975bda08f0),
# and the legend of the NuSEDS "Map of Areas", both attached to the NuSEDS
# Open Government record c48669a3-045b-400d-b730-48aafe8c5ee6.
#
# DECISIONS THAT ARE BRETT'S
# --------------------------
# Every IRI written here, with what justifies it, is listed in the pull
# request that introduced this script: choosing an IRI is Brett's to approve.
# The choices this script could not make are all in `pending_decisions`. A
# value there that is not NA is an interim answer to a slot strict validation
# will not leave blank, not a ruling. When one is ruled, change it here,
# rerun the script, and check its reject or accept below still says why.

pending_decisions <- list(
  # Q-09: is a spawner count's property smn:Abundance or
  # gcdfo:SpawnerAbundance? Interim: smn:Abundance, the value the starter
  # dictionary shipped and the answer knowledge/questions.md Q9 recommends,
  # with gcdfo:SpawnerAbundance as the variable (term_iri). Strict validation
  # requires a property_iri, so this one cannot be left blank.
  spawner_property_iri = "https://w3id.org/smn/Abundance",

  # The external taxonomy the SPECIES code `Coho` points at. Q8 ruled that
  # species go to an external taxonomy; which one is open, and Q-48 holds the
  # taxon-reference pattern. Recommendation: WoRMS AphiaID 127184,
  # Oncorhynchus kisutch, under the Q6-1 ruling quoted in the commons card
  # concepts/pacific-salmonid-taxonomic-authorities.md.
  coho_taxon_iri = NA_character_,

  # RUN_TYPE's column term. smn:Run is the one candidate, and what it denotes
  # (run timing, or the returning fish) is hub question Q-61; the commons card
  # concepts/run-timing.md records the term as contested.
  run_type_term_iri = NA_character_,

  # ESTIMATE_METHOD "Combined Methods". The NuSEDS method crosswalk maps it to
  # gcdfo:EstimateMethod, the top concept of the scheme: that is what the
  # column holds, not what this value is. No narrower concept exists.
  combined_methods_term_iri = NA_character_,

  # Who the package names, and under what licence. Interim: the data's
  # originator as creator, the contact of the KNB test-node rehearsal
  # (scripts/build-fraser-coho-knb-rehearsal.R), and the licence the source
  # data is published under. The rehearsal names the Pacific Salmon
  # Commission as creator and uses CC-BY-4.0, for the deposit.
  creator = "Fisheries and Oceans Canada",
  contact_name = "Brett Johnson",
  contact_email = "johnson@psc.org",
  contact_org = "Pacific Salmon Commission",
  license = "Open Government Licence - Canada"
)

dataset_id <- "fraser-coho-2023-2024"
table_id <- "escapement"

# The column- and table-level IRIs, each with the published definition that
# justifies it; the code IRIs are in `code_metadata`. The stubbed search
# returns the `searched` rows, from smn, gcdfo and QUDT. The other three are
# properties, from smn and Darwin Core, written by IRI: SPECIES's through the
# review, the other two in step 4, because their columns get no review slot.
reviewed_vocabulary <- tibble::tribble(
  ~iri, ~label, ~source, ~term_type, ~searched, ~definition,
  "https://w3id.org/gcdfo/salmon#SpawnerAbundance", "Spawner abundance", "gcdfo", "owl_class", TRUE,
  "The abundance (count) of adult salmon that reach spawning grounds in a given system and time period (often operationalized as escapement/spawning escapement).",
  "https://w3id.org/smn/Abundance", "Abundance", "smn", "owl_class", TRUE,
  "A characteristic representing the quantity of salmon or other organisms associated with a defined entity, place, and time.",
  "https://w3id.org/smn/Population", "Population", "smn", "owl_class", TRUE,
  "A group of organisms of the same species occupying a defined area that interbreed and share a gene pool. In salmon, populations are composed of one or more demes and form the biological basis for Conservation Units.",
  "http://qudt.org/vocab/unit/INDIV", "Individual", "qudt", NA, TRUE,
  "QUDT counting unit Individual, of quantity kind Population. QUDT's own IRI for it is http, not https.",
  "https://w3id.org/smn/EscapementEstimate", "Escapement estimate", "smn", "owl_class", TRUE,
  "A measurement or estimate of escapement tied to a stock and a survey event.",
  "https://w3id.org/gcdfo/salmon#EstimateMethod", "Estimate Method", "gcdfo", "skos_concept", TRUE,
  "A method used to analyze and estimate salmon abundance from enumeration data.",
  "https://w3id.org/gcdfo/salmon#EstimateType", "Estimate Type", "gcdfo", "skos_concept", TRUE,
  "Classification of escapement estimate quality based on Hyatt 1997 framework.",
  "https://w3id.org/smn/returnYear", "return year", "smn", NA, FALSE,
  "Relates a data record or observation to the calendar year in which members of a salmon cohort make the adult return relevant to the dataset's declared location or event. An owl:DatatypeProperty, for which the SDP term_type enum has no value.",
  "http://rs.tdwg.org/dwc/terms/waterBody", "Water Body", "dwc", NA, FALSE,
  "The name of the water body in which the dcterms:Location occurs. An rdf:Property.",
  "http://rs.tdwg.org/dwc/terms/vernacularName", "Vernacular Name", "dwc", NA, FALSE,
  "A common or vernacular name. An rdf:Property."
)

term <- function(label) {
  hit <- reviewed_vocabulary$iri[reviewed_vocabulary$label == label]
  stopifnot(length(hit) == 1L)
  hit
}

# The stubbed search: the searchable part of `reviewed_vocabulary`, for any
# query and role, in the shape find_terms() returns.
reviewed_search <- function(query, role = NA_character_, sources = NULL) {
  terms <- reviewed_vocabulary[reviewed_vocabulary$searched, , drop = FALSE]
  tibble::tibble(
    label = terms$label,
    iri = terms$iri,
    source = terms$source,
    ontology = terms$source,
    role = role,
    match_type = "reviewed_vocabulary",
    definition = terms$definition,
    term_type = terms$term_type,
    score = 1
  )
}

# Column text, from the NuSEDS data dictionary. `required` is TRUE for the
# primary-key columns and for SPECIES, as in the starter dictionary.
column_metadata <- tibble::tribble(
  ~column, ~label, ~required, ~description,
  "POP_ID", "Population ID", TRUE,
  "NuSEDS identifier of the population the record is for.",
  "POPULATION", "Population name", FALSE,
  paste(
    "NuSEDS population name. Inherited from earlier databases, it is by default",
    "a concatenation of stream name, sub-district, species and run type, for",
    "example Bonaparte River (Lillooet) Coho."
  ),
  "AREA", "Sub-district", FALSE,
  paste(
    "DFO Pacific Region sub-district recorded for the population. NuSEDS defines",
    "AREA as the subdistrict, which in most cases is the same as the statistical",
    "area; the two differ mainly for streams that drain to the Fraser and for",
    "large areas split into lettered parts, such as 29F. These are the",
    "sub-districts of the NuSEDS Map of Areas, not Pacific Fishery Management",
    "Areas or Subareas."
  ),
  "WATERBODY", "Waterbody", TRUE,
  "Name of the waterbody, or the portion of a waterbody, that bounds the population.",
  "ANALYSIS_YR", "Analysis year", TRUE,
  "The year the estimate is for. Surveys may have continued into the following calendar year.",
  "SPECIES", "Species", TRUE,
  "Species of fish, as its NuSEDS common name.",
  "RUN_TYPE", "Run type", FALSE,
  paste(
    "Run timing of the population's run within the season. NuSEDS names a run",
    "(for example FALL) where documentation supports it, and numbers it (1)",
    "where documentation shows only that there are distinct runs within a",
    "season. Blank where NuSEDS records none."
  ),
  "NATURAL_ADULT_SPAWNERS", "Natural adult spawners", FALSE,
  paste(
    "Estimated number of natural adult spawners: salmon that have reached",
    "maturity, excluding jacks (salmon that matured at an early age). Natural",
    "spawners are counted apart from artificial spawners such as hatchery",
    "broodstock; the word describes where the fish spawn, not their origin.",
    "Blank where no estimate was made."
  ),
  "ESTIMATE_METHOD", "Estimate method", FALSE,
  "Standard NuSEDS method used to produce the estimate.",
  "ESTIMATE_CLASSIFICATION", "Estimate classification", FALSE,
  paste(
    "Classification of the estimate by its accuracy and precision, from Type-1,",
    "the most accurate, to Type-6, the least."
  ),
  "ESTIMATE_STAGE", "Estimate stage", FALSE,
  "Review stage of the estimate: preliminary, near final or final.",
  "START_DTT", "Inspection start date", FALSE,
  "Date the first stream inspection for this season's estimate started.",
  "END_DTT", "Inspection end date", FALSE,
  "Date the last stream inspection for this season's estimate started.",
  "WATERSHED_CDE", "Watershed code", FALSE,
  paste(
    "45-digit hierarchical provincial watershed code, derived from the",
    "province's 1:50,000 National Topographic Series map sheets and unique to",
    "the waterbody and its watershed; its 12 levels follow the hierarchy of the",
    "stream network."
  )
)

# Code text and IRIs. Descriptions follow the NuSEDS data dictionary where it
# defines the value; the sub-district office names come from the legend of the
# NuSEDS Map of Areas. The ESTIMATE_METHOD and ESTIMATE_CLASSIFICATION IRIs
# are the ones create_sdp()'s NuSEDS crosswalk prefills, each checked against
# the gcdfo definition. A code with no IRI says why in `no_term`, which
# becomes the reason its review slot is rejected in step 3.
gcdfo <- function(name) paste0("https://w3id.org/gcdfo/salmon#", name)
method_scheme <- gcdfo("EstimateMethodScheme")
type_scheme <- gcdfo("EstimateTypeScheme")
no_subdistrict_term <- paste(
  "No term: gcdfo and smn define no NuSEDS sub-district, and gcdfo's PFMA",
  "Subareas (29-1 to 29-17) are a different division (commons card",
  "concepts/nuseds-area-is-a-subdistrict.md)."
)
no_run_timing_term <- "No run-timing term: smn:Run is contested (hub question Q-61)."
code_metadata <- tibble::tribble(
  ~column, ~code, ~label, ~term_iri, ~vocabulary_iri, ~no_term, ~description,
  "AREA", "29F", "29F Lillooet", NA, NA, no_subdistrict_term,
  "Sub-district 29F; the Map of Areas gives its sub-district office as Lillooet.",
  "AREA", "29G", "29G Williams Lake", NA, NA, no_subdistrict_term,
  "Sub-district 29G; the Map of Areas gives its sub-district office as Williams Lake.",
  "AREA", "29J", "29J Clearwater", NA, NA, no_subdistrict_term,
  "Sub-district 29J; the Map of Areas gives its sub-district office as Clearwater.",
  "AREA", "29K", "29K Salmon Arm", NA, NA, no_subdistrict_term,
  "Sub-district 29K; the Map of Areas gives its sub-district office as Salmon Arm.",
  "SPECIES", "Coho", "Coho salmon", pending_decisions$coho_taxon_iri, NA,
  "Pending Brett: which external taxonomy a species code points at.",
  "Coho salmon, Oncorhynchus kisutch.",
  "RUN_TYPE", "1", "Run 1", NA, NA, no_run_timing_term,
  "A distinct run within the season, numbered because no documentation supports a named run timing.",
  "RUN_TYPE", "FALL", "Fall", NA, NA, no_run_timing_term,
  "Fall run timing.",
  "ESTIMATE_METHOD", "Area Under the Curve", "Area under the curve", gcdfo("AreaUnderTheCurve"), method_scheme, NA,
  paste(
    "Combines a series of point estimates of abundance into an annual estimate:",
    "the area under the curve of abundance over time, divided by the survey life",
    "(the average time an individual is available to be observed alive)."
  ),
  "ESTIMATE_METHOD", "Combined Methods", "Combined methods", pending_decisions$combined_methods_term_iri, NA,
  "Pending Brett: gcdfo has no concept for a combination of estimate methods.",
  paste(
    "Several survey methods were run on the system and an estimate calculated for",
    "each; the final estimate combines two or more estimate methods."
  ),
  "ESTIMATE_METHOD", "Fence", "Fence", NA, NA,
  "No term: the NuSEDS dictionary defines Fence only as an enumeration method.",
  paste(
    "Fence count. The NuSEDS data dictionary lists Fence as an enumeration method",
    "and does not define it as an estimate method."
  ),
  "ESTIMATE_METHOD", "Fixed Site Census", "Fixed site census", gcdfo("FixedStationTally"), method_scheme, NA,
  paste(
    "Combines one or more raw observations into a single estimate, for example",
    "all the daily observations at a fence into one annual estimate."
  ),
  "ESTIMATE_METHOD", "Not Applicable", "Not applicable", NA, NA,
  "No term: an administrative NuSEDS label, not a method.",
  paste(
    "Replaces Insufficient Information or Addition/Subtraction where the stream",
    "was not inspected or no fish were observed."
  ),
  "ESTIMATE_METHOD", "Peak Live * Expansion", "Peak live times expansion", gcdfo("ExpansionMathematicalOperations"), method_scheme, NA,
  "An overflight count of all the spawners, multiplied by an expansion factor.",
  "ESTIMATE_METHOD", "Resistivity Counter", "Resistivity counter", gcdfo("FixedStationTally"), method_scheme, NA,
  "Count from a resistivity fish counter. The NuSEDS data dictionary gives no definition.",
  "ESTIMATE_METHOD", "Sonar-ARIS", "ARIS sonar", gcdfo("HydroacousticModelling"), method_scheme, NA,
  "Count from an ARIS imaging sonar. The NuSEDS data dictionary gives no definition.",
  "ESTIMATE_METHOD", "Sonar-DIDSON", "DIDSON sonar", gcdfo("HydroacousticModelling"), method_scheme, NA,
  "Count from a DIDSON imaging sonar; renamed from Didson Counter in 2022.",
  "ESTIMATE_CLASSIFICATION", "TRUE ABUNDANCE (TYPE-1)", "True abundance, Type-1", gcdfo("Type1"), type_scheme, NA,
  "True abundance estimate, Type-1, the most accurate classification.",
  "ESTIMATE_CLASSIFICATION", "RELATIVE ABUNDANCE (TYPE-3)", "Relative abundance, Type-3", gcdfo("Type3"), type_scheme, NA,
  "Relative abundance estimate, Type-3.",
  "ESTIMATE_CLASSIFICATION", "RELATIVE ABUNDANCE (TYPE-4)", "Relative abundance, Type-4", gcdfo("Type4"), type_scheme, NA,
  "Relative abundance estimate, Type-4.",
  "ESTIMATE_CLASSIFICATION", "RELATIVE ABUNDANCE (TYPE-5)", "Relative abundance, Type-5", gcdfo("Type5"), type_scheme, NA,
  "Relative abundance estimate, Type-5.",
  "ESTIMATE_CLASSIFICATION", "NO SURVEY THIS YEAR", "No survey this year", NA, NA,
  "No term: not an estimate type; the stream was not inspected.",
  "The stream was not inspected for the species this year.",
  "ESTIMATE_STAGE", "FINAL", "Final", NA, NA,
  "No term: smn and gcdfo have no estimate-stage vocabulary.",
  paste(
    "Released after all data were incorporated and every verification step was",
    "completed; changes are not anticipated."
  )
)

# The column- and table-level review decisions: an accept names its IRI, a
# reject gives its reason. Code-level decisions are derived from
# `code_metadata` in step 3. Step 3 stops unless these, with the code rejects,
# are exactly the slots the flow discovered.
review_decisions <- tibble::tribble(
  ~file, ~column, ~field, ~iri, ~reason,
  "column_dictionary.csv", "NATURAL_ADULT_SPAWNERS", "term_iri", term("Spawner abundance"), NA,
  "column_dictionary.csv", "NATURAL_ADULT_SPAWNERS", "property_iri", pending_decisions$spawner_property_iri, NA,
  "column_dictionary.csv", "NATURAL_ADULT_SPAWNERS", "entity_iri", term("Population"), NA,
  "column_dictionary.csv", "NATURAL_ADULT_SPAWNERS", "unit_iri", term("Individual"), NA,
  "column_dictionary.csv", "NATURAL_ADULT_SPAWNERS", "constraint_iri", NA,
  paste(
    "smn:NaturalOrigin does not apply: NuSEDS counts natural spawners apart from",
    "artificial spawners such as broodstock, so natural describes where the fish",
    "spawn; the data dictionary says nothing of origin."
  ),
  "tables.csv", NA, "observation_unit_iri", term("Escapement estimate"), NA,
  "column_dictionary.csv", "ESTIMATE_METHOD", "term_iri", term("Estimate Method"), NA,
  "column_dictionary.csv", "ESTIMATE_CLASSIFICATION", "term_iri", term("Estimate Type"), NA,
  # An rdf:Property, accepted by IRI; step 4 clears the type the write-back
  # gives it.
  "column_dictionary.csv", "SPECIES", "term_iri", term("Vernacular Name"), NA,
  "column_dictionary.csv", "RUN_TYPE", "term_iri", pending_decisions$run_type_term_iri,
  no_run_timing_term,
  "column_dictionary.csv", "AREA", "term_iri", NA, no_subdistrict_term,
  "column_dictionary.csv", "POPULATION", "term_iri", NA,
  "No term for a population's name in smn or gcdfo.",
  "column_dictionary.csv", "ESTIMATE_STAGE", "term_iri", NA,
  "No term: smn and gcdfo have no estimate-stage vocabulary.",
  "column_dictionary.csv", "WATERSHED_CDE", "term_iri", NA,
  "No term for the BC watershed code in smn, gcdfo or Darwin Core."
)

# The canonical package files, the only ones copied out of the staging build.
# create_sdp()'s review checklist (README-review.txt) and the `.sdp-package`
# ownership sentinel belong to the build, not to the package.
gold_standard_files <- c(
  "datapackage.json",
  "metadata/dataset.csv",
  "metadata/tables.csv",
  "metadata/column_dictionary.csv",
  "metadata/codes.csv",
  "data/escapement.csv"
)

build_fraser_coho_gold_standard <- function(out_dir,
                                            source_csv = file.path(
                                              "inst", "extdata",
                                              "nuseds-fraser-coho-2023-2024.csv"
                                            ),
                                            quiet = TRUE) {
  say <- function(...) if (!isTRUE(quiet)) message(...)
  run <- function(expr) if (isTRUE(quiet)) suppressMessages(expr) else expr

  # `out_dir` is replaced at the end, so it must be empty or an earlier build:
  # a mistyped path must never be emptied. Checked first, before any work.
  if (file.exists(out_dir) && !dir.exists(out_dir)) {
    stop("Refusing to replace ", out_dir, ": it is a file.", call. = FALSE)
  }
  if (dir.exists(out_dir)) {
    present <- list.files(out_dir, recursive = TRUE, all.files = TRUE, include.dirs = TRUE)
    foreign <- setdiff(present, c(gold_standard_files, "data", "metadata"))
    if (length(foreign) > 0L) {
      stop(
        "Refusing to replace ", out_dir, ": it holds files an earlier build ",
        "did not write (", paste(utils::head(foreign, 5L), collapse = ", "), ").",
        call. = FALSE
      )
    }
  }

  # Typed on read, so create_sdp() infers `integer` for the two whole-number
  # columns and writes every data byte exactly as the source CSV holds it.
  data <- readr::read_csv(
    source_csv,
    col_types = readr::cols(
      POP_ID = readr::col_integer(),
      ANALYSIS_YR = readr::col_integer(),
      NATURAL_ADULT_SPAWNERS = readr::col_double(),
      START_DTT = readr::col_date(),
      END_DTT = readr::col_date(),
      .default = readr::col_character()
    ),
    na = "",
    progress = FALSE
  )
  stopifnot(nrow(data) == 173L, ncol(data) == 14L)

  stage <- tempfile("fraser-coho-gold-standard-")
  on.exit(unlink(stage, recursive = TRUE), add = TRUE)
  pkg <- file.path(stage, "sdp")

  # -- 1. The review-ready package -------------------------------------------
  say("1. create_sdp()")
  run(metasalmon::create_sdp(
    stats::setNames(list(data), table_id),
    path = pkg,
    dataset_id = dataset_id,
    table_id = table_id,
    seed_semantics = FALSE,
    check_updates = FALSE
  ))

  # -- 2. Free text and code IRIs ----------------------------------------------
  say("2. set_sdp_dataset(), set_sdp_table(), set_sdp_column(), set_sdp_code()")
  metasalmon::set_sdp_dataset(
    pkg,
    title = "Fraser River coho salmon natural adult spawner estimates, 2023-2024",
    description = paste(
      "Estimates of natural adult coho salmon (Oncorhynchus kisutch) spawners",
      "for 87 Fraser River populations in DFO sub-districts 29F, 29G, 29J and",
      "29K, analysis years 2023 and 2024: 173 records from the DFO New Salmon",
      "Escapement Database System (NuSEDS), each with the estimate method,",
      "estimate classification, estimate stage and stream-inspection window",
      "behind it. The metasalmon gold-standard Salmon Data Package."
    ),
    creator = pending_decisions$creator,
    contact_name = pending_decisions$contact_name,
    contact_email = pending_decisions$contact_email,
    contact_org = pending_decisions$contact_org,
    license = pending_decisions$license,
    spatial_extent = paste(
      "Fraser River watershed, British Columbia, Canada: DFO Pacific Region",
      "sub-districts 29F (Lillooet), 29G (Williams Lake), 29J (Clearwater) and",
      "29K (Salmon Arm)."
    ),
    dataset_type = "escapement_estimates",
    source_citation = paste(
      "Fisheries and Oceans Canada. 2025. NuSEDS-New Salmon Escapement Database",
      "System: Fraser and BC Interior NuSEDS_20251014. Open Government Portal",
      "record c48669a3-045b-400d-b730-48aafe8c5ee6,",
      "https://open.canada.ca/data/en/dataset/c48669a3-045b-400d-b730-48aafe8c5ee6.",
      "Open Government Licence - Canada."
    ),
    topic_categories = "biota;inlandWaters",
    keywords = paste(
      "coho salmon", "Oncorhynchus kisutch", "escapement", "spawner abundance",
      "NuSEDS", "Fraser River", "British Columbia",
      sep = ";"
    ),
    security_classification = "unclassified",
    provenance_note = paste(
      "Extracted from the Fraser and BC Interior NuSEDS workbook of 2025-10-14",
      "by data-raw/nuseds_fraser_coho_examples.R in the metasalmon repository:",
      "coho only, analysis years 2023 and 2024, 14 of the workbook's columns,",
      "START_DTT and END_DTT converted to ISO 8601 dates, rows sorted by",
      "ANALYSIS_YR, AREA, WATERBODY and POP_ID. Packaged by",
      "data-raw/fraser_coho_gold_standard.R with metasalmon::create_sdp();",
      "column and code definitions follow the NuSEDS data dictionary",
      "(Data_Dictionary_NuSEDS_EN.csv, 2025-05-27)."
    ),
    quiet = TRUE
  )

  metasalmon::set_sdp_table(
    pkg,
    table_id,
    table_label = "Coho escapement estimates",
    description = paste(
      "One row per NuSEDS escapement record: a coho population, the waterbody",
      "that bounds it and an analysis year, with the natural adult spawner",
      "estimate and the method, classification, stage and inspection window",
      "behind it."
    ),
    observation_unit = "Escapement estimate",
    # POP_ID and ANALYSIS_YR alone repeat on 9 of the 173 rows: NuSEDS keeps a
    # record per waterbody that bounds a population, so NICOLA RIVER (DAM) and
    # NICOLA RIVER (DOT) are both population 46170 in 2023.
    primary_key = "POP_ID,ANALYSIS_YR,WATERBODY",
    quiet = TRUE
  )

  for (i in seq_len(nrow(column_metadata))) {
    row <- column_metadata[i, ]
    metasalmon::set_sdp_column(
      pkg,
      row$column,
      column_label = row$label,
      column_description = row$description,
      required = if (row$required) "TRUE" else "FALSE",
      quiet = TRUE
    )
  }
  metasalmon::set_sdp_column(
    pkg, "NATURAL_ADULT_SPAWNERS",
    unit_label = "Individual",
    quiet = TRUE
  )

  # Every code, including the crosswalk's prefills: each IRI is written again,
  # so a value the review below overrules (Combined Methods) is cleared, and a
  # code left blank becomes a review slot like every other unannotated code.
  for (i in seq_len(nrow(code_metadata))) {
    row <- code_metadata[i, ]
    metasalmon::set_sdp_code(
      pkg,
      row$column,
      row$code,
      code_label = row$label,
      code_description = row$description,
      term_iri = row$term_iri,
      vocabulary_iri = row$vocabulary_iri,
      term_type = if (is.na(row$term_iri)) NA else "skos_concept",
      quiet = TRUE
    )
  }

  # -- 3. The semantic review --------------------------------------------------
  say("3. suggest_semantics() -> review_semantics() -> apply_sdp_semantics()")
  current <- run(metasalmon::read_salmon_datapackage(pkg))
  suggested <- run(metasalmon::suggest_semantics(
    current$resources,
    current$dictionary,
    codes = current$codes,
    table_meta = current$tables,
    search_fn = reviewed_search,
    max_per_role = sum(reviewed_vocabulary$searched)
  ))
  review <- run(metasalmon::review_semantics(
    list(dict = suggested, codes = current$codes, table_meta = current$tables),
    max_candidates = Inf
  ))

  unannotated_codes <- code_metadata[is.na(code_metadata$term_iri), , drop = FALSE]
  decisions <- rbind(
    data.frame(
      file = review_decisions$file,
      column = review_decisions$column,
      code = NA_character_,
      field = review_decisions$field,
      iri = review_decisions$iri,
      reason = review_decisions$reason,
      stringsAsFactors = FALSE
    ),
    data.frame(
      file = "codes.csv",
      column = unannotated_codes$column,
      code = unannotated_codes$code,
      field = "term_iri",
      iri = NA_character_,
      reason = unannotated_codes$no_term,
      stringsAsFactors = FALSE
    )
  )
  slot_key <- function(file, column, code, field) {
    paste(file, ifelse(is.na(column), "", column), ifelse(is.na(code), "", code), field, sep = " | ")
  }
  slots <- unique(review[, c("target_file", "column_name", "code_value", "target_field", "role")])
  discovered <- slot_key(slots$target_file, slots$column_name, slots$code_value, slots$target_field)
  decided <- slot_key(decisions$file, decisions$column, decisions$code, decisions$field)
  if (!setequal(discovered, decided) || anyDuplicated(decided) > 0L) {
    stop(
      "The review decides a different set of slots than the flow discovered.\n",
      "Discovered, undecided: ", paste(setdiff(discovered, decided), collapse = "; "), "\n",
      "Decided, not discovered: ", paste(setdiff(decided, discovered), collapse = "; "),
      call. = FALSE
    )
  }

  for (i in seq_len(nrow(decisions))) {
    d <- decisions[i, ]
    role <- slots$role[[match(slot_key(d$file, d$column, d$code, d$field), discovered)]]
    column <- if (is.na(d$column)) NULL else d$column
    table <- if (is.na(d$column)) table_id else NULL
    code <- if (identical(d$file, "codes.csv")) d$code else if (is.null(column)) NULL else ""
    review <- if (!is.na(d$iri)) {
      metasalmon::accept_suggestion(
        review, column, role, table = table, code_value = code, iri = d$iri
      )
    } else {
      metasalmon::reject_suggestion(
        review, column, role, table = table, code_value = code, reason = d$reason
      )
    }
  }
  run(metasalmon::apply_sdp_semantics(pkg, review, quiet = TRUE))

  # -- 4. IRIs the review has no slot for, and one type ------------------------
  say("4. set_sdp_column() for the IRIs outside the review")
  metasalmon::set_sdp_column(
    pkg, "ANALYSIS_YR",
    term_iri = term("return year"),
    quiet = TRUE
  )
  metasalmon::set_sdp_column(
    pkg, "WATERBODY",
    term_iri = term("Water Body"),
    quiet = TRUE
  )
  # apply_sdp_semantics() types an accepted IRI that no candidate carried as
  # skos_concept. dwc:vernacularName is an rdf:Property, and the SDP term_type
  # enum has no value for one, so the type is cleared. Retires when the
  # write-back leaves term_type blank for a term whose type nothing records.
  metasalmon::set_sdp_column(pkg, "SPECIES", term_type = NA, quiet = TRUE)

  # -- 5. The strict gate, then the canonical files ----------------------------
  say("5. validate_salmon_datapackage(require_iris = TRUE)")
  run(metasalmon::validate_salmon_datapackage(pkg, require_iris = TRUE))

  if (dir.exists(out_dir)) {
    unlink(out_dir, recursive = TRUE)
  }
  for (file in gold_standard_files) {
    target <- file.path(out_dir, file)
    dir.create(dirname(target), recursive = TRUE, showWarnings = FALSE)
    stopifnot(file.copy(file.path(pkg, file), target))
  }
  invisible(out_dir)
}

if (sys.nframe() == 0L) {
  script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  script_path <- normalizePath(sub("^--file=", "", script_arg[[1]]), mustWork = TRUE)
  repo_root <- dirname(dirname(script_path))
  pkgload::load_all(repo_root, quiet = TRUE)

  out_dir <- file.path(repo_root, "inst", "extdata", "nuseds-fraser-coho-2023-2024-sdp")
  build_fraser_coho_gold_standard(
    out_dir,
    source_csv = file.path(repo_root, "inst", "extdata", "nuseds-fraser-coho-2023-2024.csv"),
    quiet = FALSE
  )
  cat("Wrote ", out_dir, "\n", sep = "")
}
