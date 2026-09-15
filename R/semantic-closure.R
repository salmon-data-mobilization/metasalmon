# ---------------------------------------------------------------------------
# THE REVIEWED SEMANTIC CLOSURE: A PRODUCER (backlog #116, hub item B-116).
#
# `write_eml_from_sdp()` and `publish_sdp_to_knb()` both require two files that
# this package validated in three places and wrote in none:
#
#   metadata/semantic_vocabulary.csv   one evidence row per canonical
#                                      MEASUREMENT IRI, each row carrying its
#                                      own `reviewed_snapshot_sha256`
#   reviewed_semantic_selections.csv   exactly one `accepted` row per canonical
#                                      REVIEW TARGET
#
# THE TWO SETS ARE DIFFERENT SETS, and that is why this producer derives both
# rather than deriving one and reasoning the other from it. The measurement set
# is IRIs the EML measurement and method paths emit, so it includes
# code-resolved `sosa:usedProcedure` IRIs and excludes a table's
# `observation_unit_iri`. The review-target set is slots a reviewer decided, so
# it includes `observation_unit_iri` and excludes a code-resolved procedure,
# which no reviewer ever selected as a slot. In the package's own bundled Fraser
# coho example the difference is exactly one row: `smn:Observation` is a review
# target and not a vocabulary term.
#
# GAP, NOT ABORT -- ruled by Brett 2026-09-12. An IRI this producer cannot
# resolve becomes a row in `detect_semantic_term_gaps()` shape and both files
# are still written. Aborting would hand the user a failure and nothing to file;
# a gap is what `render_ontology_term_request()` and
# `submit_term_request_issues()` already consume, so the unresolvable case
# leaves the pipeline rather than dead-ending in it. An omitted vocabulary row
# is *not* silent: `.ms_eml_read_vocabulary()` then names the same IRI as
# `Missing:` when export is attempted, so the two messages agree.
#
# NO LLM REACHES THIS PATH. `find_terms()` is deterministic ontology search;
# there is no `llm_assess` argument here and nothing below constructs an LLM
# request. Pinned by `tests/testthat/test-semantic-closure.R`, which runs the
# whole producer with `.ms_llm_chat_json_request()` bound to a `stop()`.
# ---------------------------------------------------------------------------

# The vocabulary evidence fields, in the order
# `.ms_eml_vocabulary_snapshot_sha256()` hashes them. The order is load-bearing:
# the digest is over these values joined by `\r`, so a reorder here silently
# changes every hash the package writes. Pinned against the verifier's own field
# list in test-semantic-closure.R.
.ms_closure_vocabulary_fields <- function() {
  c(
    "iri",
    "label",
    "definition",
    "source",
    "ontology",
    "resource_kind",
    "type_iris",
    "native_type",
    "source_url",
    "source_artifact_sha256"
  )
}

# The subset `.ms_eml_read_vocabulary()` refuses to accept empty. `type_iris`
# and `source_artifact_sha256` are deliberately absent: a live w3id resolution
# is not a pinned release artifact, so it has no artifact digest.
.ms_closure_required_vocabulary_fields <- function() {
  c(
    "label",
    "definition",
    "source",
    "ontology",
    "resource_kind",
    "native_type",
    "source_url"
  )
}

# Of those, the six `find_terms()` returns. `native_type` and `source_url`
# describe the ontology ARTIFACT rather than the term, and nothing on the
# retrieval path records them, so they are derived below or hand-supplied.
.ms_closure_search_evidence_fields <- function() {
  c("label", "definition", "source", "ontology", "resource_kind", "type_iris")
}

.ms_closure_ledger_fields <- function() {
  c(
    "dataset_id",
    "table_id",
    "column_name",
    "target_scope",
    "target_sdp_field",
    "dictionary_role",
    "decision",
    "confidence",
    "review_rationale",
    "iri"
  )
}

# Columns a caller may hand-supply through `evidence`.
.ms_closure_evidence_fields <- function() {
  c(
    setdiff(.ms_closure_vocabulary_fields(), "iri"),
    "confidence",
    "review_rationale"
  )
}

# The gap table this producer returns: the `detect_semantic_term_gaps()` shape
# plus the IRI that could not be resolved. That column is an addition rather
# than a reuse of `top_non_smn_iri`, which means "the best candidate another
# source returned" and is empty here precisely because nothing was returned.
# `render_ontology_term_request()` reads named fields and ignores the extra one.
.ms_closure_gap_cols <- function() {
  c(.ms_term_gap_cols(), "unresolved_iri")
}

# The artifact each searchable source resolves, which is what `source_url`
# records. These are the two URLs `.smn_term_index()` and `.gcdfo_term_index()`
# fetch (R/term_search.R), so a source whose fetch URL changes changes here too.
#
# *Retires when:* `find_terms()` returns the artifact URL it resolved, at which
# point reading it back is strictly better than restating it here.
.ms_closure_source_url <- function(source) {
  source <- tolower(trimws(as.character(source)[[1]]))
  if (identical(source, "smn")) {
    return("https://w3id.org/smn/")
  }
  if (identical(source, "gcdfo")) {
    return("https://w3id.org/gcdfo/salmon")
  }
  ""
}

# `native_type` is the term's own RDF type in CURIE form. `resource_kind` is the
# RDF/XML element name the index parsed, so this is a rename rather than an
# inference.
.ms_closure_native_type <- function(resource_kind) {
  kind <- trimws(as.character(resource_kind)[[1]])
  if (is.na(kind) || !nzchar(kind)) {
    return("")
  }
  switch(
    tolower(kind),
    class = "owl:Class",
    owlclass = "owl:Class",
    owl_class = "owl:Class",
    namedindividual = "owl:NamedIndividual",
    objectproperty = "owl:ObjectProperty",
    owl_object_property = "owl:ObjectProperty",
    datatypeproperty = "owl:DatatypeProperty",
    concept = "skos:Concept",
    skosconcept = "skos:Concept",
    skos_concept = "skos:Concept",
    conceptscheme = "skos:ConceptScheme",
    paste0("owl:", kind)
  )
}

# One value, rendered once. Every cell that reaches the closure files goes
# through here, so the sort key, the digest input and the emitted byte are the
# same character vector. A multi-element value is joined rather than deparsed:
# `as.character()` on a list cell yields R source text, which would be written
# into the CSV verbatim.
.ms_closure_text <- function(x, default = "") {
  if (is.null(x) || length(x) == 0L) {
    return(default)
  }
  values <- .ms_canonical_character(unlist(x, use.names = FALSE))
  values <- values[!is.na(values)]
  values <- trimws(values)
  values <- values[nzchar(values)]
  if (length(values) == 0L) {
    return(default)
  }
  paste(values, collapse = ";")
}

# Blank out NA and trim, element-wise, in one rendering.
.ms_closure_column <- function(x) {
  values <- .ms_canonical_character(x)
  values[is.na(values)] <- ""
  trimws(values)
}

# The local name of an IRI, split back into words. `SpawnerAbundance` becomes
# "spawner abundance": the label a reviewer searched for is recoverable from the
# IRI they accepted, which is what lets evidence be re-resolved without asking
# the user to restate the query.
.ms_closure_iri_query <- function(iri) {
  local <- sub("^.*[#/]", "", trimws(as.character(iri)[[1]]))
  local <- gsub("[_-]+", " ", local)
  local <- gsub("([a-z0-9])([A-Z])", "\\1 \\2", local)
  local <- gsub("([A-Z]+)([A-Z][a-z])", "\\1 \\2", local)
  tolower(trimws(gsub("[[:space:]]+", " ", local)))
}

.ms_closure_normalize_evidence <- function(evidence) {
  if (is.null(evidence)) {
    return(NULL)
  }
  # The same early-type contract `llm_context_files` carries: a caller who hands
  # over a parsed object rather than rows gets an error here, not a confusing
  # failure eight frames down.
  if (!is.data.frame(evidence)) {
    cli::cli_abort(c(
      "{.arg evidence} must be a data frame of hand-supplied closure rows.",
      "i" = "Got {.cls {class(evidence)}}; supply one row per IRI with an {.field iri} column."
    ))
  }
  evidence <- tibble::as_tibble(evidence)
  if (nrow(evidence) == 0L) {
    return(NULL)
  }
  if (!"iri" %in% names(evidence)) {
    cli::cli_abort("{.arg evidence} must have an {.field iri} column.")
  }
  known <- c("iri", "target_sdp_field", .ms_closure_evidence_fields())
  unknown <- setdiff(names(evidence), known)
  if (length(unknown) > 0L) {
    cli::cli_abort(c(
      "{.arg evidence} has column{?s} this closure cannot use: {.field {unknown}}.",
      "i" = "Supported column{?s}: {.field {known}}."
    ))
  }
  evidence[] <- lapply(evidence, .ms_closure_column)
  if (any(!nzchar(evidence$iri))) {
    cli::cli_abort("Every {.arg evidence} row must name a non-empty {.field iri}.")
  }
  if (!"target_sdp_field" %in% names(evidence)) {
    evidence$target_sdp_field <- rep("", nrow(evidence))
  }
  keys <- paste(evidence$iri, evidence$target_sdp_field, sep = "\r")
  if (anyDuplicated(keys)) {
    cli::cli_abort(c(
      "{.arg evidence} must carry at most one row per IRI and target field.",
      .ms_cli_bullets(unique(evidence$iri[duplicated(keys)]))
    ))
  }
  evidence
}

# The `evidence` value for one IRI and field, preferring a row that names the
# target field over the IRI-wide row. Returns "" when nothing was supplied,
# which is what lets a partial row overlay a searched one field by field.
.ms_closure_evidence_value <- function(evidence, iri, field, target_field = "") {
  if (is.null(evidence) || !field %in% names(evidence)) {
    return("")
  }
  rows <- evidence[evidence$iri == iri, , drop = FALSE]
  if (nrow(rows) == 0L) {
    return("")
  }
  scoped <- rows[
    nzchar(rows$target_sdp_field) & rows$target_sdp_field == target_field,
    ,
    drop = FALSE
  ]
  general <- rows[!nzchar(rows$target_sdp_field), , drop = FALSE]
  for (candidate in list(scoped, general)) {
    if (nrow(candidate) == 0L) {
      next
    }
    value <- .ms_closure_text(candidate[[field]][[1]])
    if (nzchar(value)) {
      return(value)
    }
  }
  ""
}

# The decision trail `apply_sdp_semantics()` leaves in the package: for an
# accepted IRI it records the query that found it and the reviewer's reason.
# Reading it back is why a second run of this producer does not ask the user to
# restate what review already recorded. Every column access is guarded because
# the file is optional and its shape has grown across releases.
.ms_closure_read_decisions <- function(path) {
  empty <- tibble::tibble(
    iri = character(),
    dataset_id = character(),
    table_id = character(),
    column_name = character(),
    target_sdp_field = character(),
    search_query = character(),
    decision_reason = character()
  )
  suggestions_path <- file.path(path, "semantic_suggestions.csv")
  if (!file.exists(suggestions_path)) {
    return(empty)
  }
  suggestions <- tryCatch(
    readr::read_csv(
      suggestions_path,
      col_types = readr::cols(.default = readr::col_character()),
      show_col_types = FALSE,
      progress = FALSE
    ),
    error = function(e) NULL
  )
  if (is.null(suggestions) || nrow(suggestions) == 0L ||
    !"iri" %in% names(suggestions)) {
    return(empty)
  }
  column <- function(name) {
    if (!name %in% names(suggestions)) {
      return(rep("", nrow(suggestions)))
    }
    .ms_closure_column(suggestions[[name]])
  }
  out <- tibble::tibble(
    iri = column("iri"),
    dataset_id = column("dataset_id"),
    table_id = column("table_id"),
    column_name = column("column_name"),
    target_sdp_field = column("target_sdp_field"),
    search_query = column("search_query"),
    decision_reason = column("decision_reason")
  )
  decision <- tolower(column("decision"))
  keep <- nzchar(out$iri) & (!nzchar(decision) | decision == "accepted")
  out[keep, , drop = FALSE]
}

# Queries to try for one IRI, most specific first. The recorded review query
# comes first because it is what actually found the term; the IRI's own local
# name is the fallback that needs no prior run.
.ms_closure_queries <- function(iri, decisions, targets, dictionary) {
  recorded <- decisions$search_query[decisions$iri == iri]
  labels <- character()
  rows <- targets[targets$iri == iri, , drop = FALSE]
  has_dictionary <- nrow(dictionary) > 0L &&
    all(c("table_id", "column_name", "column_label") %in% names(dictionary))
  if (nrow(rows) > 0L && has_dictionary) {
    for (index in seq_len(nrow(rows))) {
      hit <- dictionary[
        !is.na(dictionary$table_id) &
          dictionary$table_id == rows$table_id[[index]] &
          !is.na(dictionary$column_name) &
          dictionary$column_name == rows$column_name[[index]],
        ,
        drop = FALSE
      ]
      if (nrow(hit) > 0L) {
        labels <- c(labels, .ms_closure_text(hit$column_label[[1]]))
      }
    }
  }
  queries <- trimws(as.character(c(recorded, .ms_closure_iri_query(iri), labels)))
  queries <- queries[!is.na(queries) & nzchar(queries)]
  unique(queries)
}

# Roles to search an IRI under. Role selects the sources and the ranking
# profile, so searching under the wrong one can hide a term that exists: a
# `unit` role, for instance, filters gcdfo out entirely.
.ms_closure_iri_roles <- function(iri, targets, measurement_only) {
  roles <- unique(trimws(as.character(targets$dictionary_role[targets$iri == iri])))
  roles <- roles[!is.na(roles) & nzchar(roles)]
  if (length(roles) == 0L) {
    # A code-resolved `sosa:usedProcedure` is in the measurement set and is
    # never a review target, so it has no role row to read.
    roles <- if (measurement_only) "method" else "variable"
  }
  sort(roles, method = "radix")
}

.ms_closure_search_evidence <- function(iri,
                                        queries,
                                        roles,
                                        sources,
                                        search_fn) {
  for (role in roles) {
    for (query in queries) {
      hits <- tryCatch(
        search_fn(query, role = role, sources = sources),
        error = function(e) NULL
      )
      if (is.null(hits) || !is.data.frame(hits) || nrow(hits) == 0L ||
        !"iri" %in% names(hits)) {
        next
      }
      hit <- hits[!is.na(hits$iri) & hits$iri == iri, , drop = FALSE]
      if (nrow(hit) == 0L) {
        next
      }
      hit <- hit[1, , drop = FALSE]
      values <- vapply(
        .ms_closure_search_evidence_fields(),
        function(field) {
          if (!field %in% names(hit)) {
            return("")
          }
          .ms_closure_text(hit[[field]])
        },
        character(1)
      )
      return(list(values = values, query = query, role = role))
    }
  }
  list(
    values = NULL,
    query = if (length(queries) > 0L) queries[[1]] else "",
    role = if (length(roles) > 0L) roles[[1]] else ""
  )
}

.ms_closure_placement_scope <- function(iri) {
  scope <- .ms_term_request_namespace_scope(iri)
  if (length(scope) != 1L || is.na(scope) || !nzchar(scope)) {
    return("uncertain")
  }
  scope
}

# One gap row for an IRI no search returned. `no_candidates` is the basis the
# enum already carries for "retrieval returned nothing at all", which is exactly
# this case, so no new detection value is introduced.
.ms_closure_gap_row <- function(iri, targets, dictionary, query, sources) {
  rows <- targets[targets$iri == iri, , drop = FALSE]
  target <- if (nrow(rows) > 0L) rows[1, , drop = FALSE] else NULL
  scope <- if (is.null(target)) "code" else .ms_closure_text(target$target_scope, "column")
  field <- if (is.null(target)) {
    "method_iri"
  } else {
    .ms_closure_text(target$target_sdp_field, "term_iri")
  }
  role <- if (is.null(target)) "method" else .ms_closure_text(target$dictionary_role, "variable")
  dataset_id <- if (!is.null(target)) {
    .ms_closure_text(target$dataset_id)
  } else if ("dataset_id" %in% names(dictionary) && nrow(dictionary) > 0L) {
    .ms_closure_text(dictionary$dataset_id[[1]])
  } else {
    ""
  }
  table_id <- if (is.null(target)) "" else .ms_closure_text(target$table_id)
  column_name <- if (is.null(target)) "" else .ms_closure_text(target$column_name)
  dict_row <- NULL
  if (nzchar(column_name) && nrow(dictionary) > 0L &&
    all(c("table_id", "column_name") %in% names(dictionary))) {
    hit <- dictionary[
      !is.na(dictionary$table_id) & dictionary$table_id == table_id &
        !is.na(dictionary$column_name) & dictionary$column_name == column_name,
      ,
      drop = FALSE
    ]
    if (nrow(hit) > 0L) {
      dict_row <- hit[1, , drop = FALSE]
    }
  }
  label <- if (is.null(dict_row)) "" else .ms_closure_text(dict_row$column_label)
  description <- if (is.null(dict_row)) {
    ""
  } else {
    .ms_closure_text(dict_row$column_description)
  }
  out <- tibble::tibble(
    dataset_id = dataset_id,
    table_id = table_id,
    column_name = column_name,
    code_value = NA_character_,
    target_scope = scope,
    target_sdp_file = switch(
      scope,
      column = "column_dictionary.csv",
      table = "tables.csv",
      "codes.csv"
    ),
    target_sdp_field = field,
    target_row_key = if (nzchar(column_name)) column_name else table_id,
    dictionary_role = role,
    search_query = query,
    column_label = label,
    column_description = description,
    top_non_smn_source = "",
    top_non_smn_label = "",
    top_non_smn_iri = "",
    top_non_smn_ontology = "",
    top_non_smn_match_type = "",
    top_non_smn_score = NA_real_,
    candidate_count = 0L,
    non_smn_sources = "",
    placement_recommendation = .ms_closure_placement_scope(iri),
    placement_confidence = NA_real_,
    placement_rationale = paste0(
      "The package asserts this IRI in ", field, " and searching ",
      paste(sources, collapse = "/"), " for it returned nothing, so either the ",
      "term is absent from the searched vocabularies or the IRI is wrong. Mint ",
      "the term, or supply a row through the `evidence` argument of ",
      "write_sdp_semantic_closure()."
    ),
    target_label = label,
    target_description = description,
    gap_detection_basis = "no_candidates",
    llm_decision = NA_character_,
    llm_confidence = NA_real_,
    llm_rationale = NA_character_,
    llm_new_term_label = NA_character_,
    llm_new_term_definition = NA_character_,
    llm_new_term_namespace = NA_character_,
    llm_escalated_from = NA_character_,
    unresolved_iri = iri
  )
  out[, .ms_closure_gap_cols(), drop = FALSE]
}

.ms_closure_empty_gaps <- function() {
  out <- .empty_term_gap_result()
  out$unresolved_iri <- character()
  out[, .ms_closure_gap_cols(), drop = FALSE]
}

# The reviewed EML sidecar declares where both closure files live and pins their
# bytes. Honour the declared paths when it exists so the producer cannot write a
# file the sidecar does not point at, and rewrite the two digests afterwards so
# that no user hand-writes one.
.ms_closure_mapping_paths <- function(path) {
  defaults <- list(
    vocabulary = "metadata/semantic_vocabulary.csv",
    review = "reviewed_semantic_selections.csv"
  )
  mapping_path <- file.path(path, "metadata", "eml-mapping.yml")
  if (!file.exists(mapping_path)) {
    return(defaults)
  }
  mapping <- tryCatch(yaml::read_yaml(mapping_path), error = function(e) NULL)
  if (is.null(mapping)) {
    return(defaults)
  }
  declared <- function(key, fallback) {
    value <- .ms_closure_text(mapping[[key]]$path)
    if (!nzchar(value)) fallback else value
  }
  list(
    vocabulary = declared("semantic_vocabulary", defaults$vocabulary),
    review = declared("semantic_review", defaults$review)
  )
}

# A relative path that stays inside the package. The sidecar is package content,
# so its `path` values are input: an absolute or escaping value must not send a
# write outside the directory the caller named.
.ms_closure_resolve_write_path <- function(path, relative) {
  root <- normalizePath(path, mustWork = TRUE)
  if (grepl("^([/\\\\]|[A-Za-z]:)", relative)) {
    cli::cli_abort(c(
      "The reviewed EML sidecar declares an absolute closure path.",
      .ms_cli_bullets(relative)
    ))
  }
  candidate <- file.path(root, relative)
  parent <- dirname(candidate)
  dir.create(parent, recursive = TRUE, showWarnings = FALSE)
  resolved <- normalizePath(parent, mustWork = TRUE)
  prefix <- paste0(root, .Platform$file.sep)
  if (!identical(resolved, root) && !startsWith(resolved, prefix)) {
    cli::cli_abort(c(
      "The reviewed EML sidecar declares a closure path outside the package.",
      .ms_cli_bullets(relative)
    ))
  }
  file.path(resolved, basename(candidate))
}

.ms_closure_file_sha256 <- function(file) {
  digest::digest(file = file, algo = "sha256", serialize = FALSE)
}

# Replace one block-mapping `sha256:` value in the sidecar's TEXT rather than by
# round-tripping the parsed YAML.
#
# THE REASON IS NOT STYLE. `yaml::write_yaml()` of a parsed document drops every
# comment in it, and the sidecar a user starts from is
# `inst/extdata/eml-mapping-template.yml`, whose first four lines are the
# instructions for filling it in. Rewriting two digests must not delete the
# document's own explanation of itself, and it must not reformat a file the user
# is still editing. Only the two lines this function is asked to change change.
#
# *Retires when:* the sidecar stops being a hand-edited file -- if an exported
# writer owns it end to end, it can be emitted whole and this becomes needless.
.ms_closure_set_mapping_digest <- function(lines, key, digest_value) {
  entry <- paste0("sha256: '", digest_value, "'")
  matches <- grep(paste0("^", key, ":"), lines)
  if (length(matches) == 0L) {
    return(list(lines = c(lines, paste0(key, ":"), paste0("  ", entry)),
                ok = TRUE))
  }
  start <- matches[[1]]
  if (nzchar(trimws(sub(paste0("^", key, ":"), "", lines[[start]])))) {
    # A flow-style or inline value. Appending a second key would make the
    # document say two things, so say nothing and let the caller report it.
    return(list(lines = lines, ok = FALSE))
  }
  if (start >= length(lines)) {
    return(list(lines = c(lines, paste0("  ", entry)), ok = TRUE))
  }
  rest <- seq.int(start + 1L, length(lines))
  # The block ends at the next line that starts a new top-level key.
  ends <- rest[grepl("^[^[:space:]#]", lines[rest])]
  stop_at <- if (length(ends) > 0L) ends[[1]] - 1L else length(lines)
  if (stop_at < start + 1L) {
    return(list(lines = append(lines, paste0("  ", entry), after = start),
                ok = TRUE))
  }
  block <- seq.int(start + 1L, stop_at)
  hit <- block[grepl("^[[:space:]]+sha256:[[:space:]]*", lines[block])]
  if (length(hit) > 0L) {
    indent <- sub("^([[:space:]]+).*$", "\\1", lines[[hit[[1]]]])
    lines[[hit[[1]]]] <- paste0(indent, entry)
    return(list(lines = lines, ok = TRUE))
  }
  list(lines = append(lines, paste0("  ", entry), after = start), ok = TRUE)
}

.ms_closure_update_mapping <- function(path, vocabulary_file, review_file) {
  mapping_path <- file.path(path, "metadata", "eml-mapping.yml")
  if (!file.exists(mapping_path)) {
    return(NULL)
  }
  lines <- readLines(mapping_path, warn = FALSE)
  refused <- character()
  for (entry in list(
    list(key = "semantic_vocabulary", file = vocabulary_file),
    list(key = "semantic_review", file = review_file)
  )) {
    result <- .ms_closure_set_mapping_digest(
      lines,
      entry$key,
      .ms_closure_file_sha256(entry$file)
    )
    if (!result$ok) {
      refused <- c(refused, entry$key)
      next
    }
    lines <- result$lines
  }
  if (length(refused) > 0L) {
    cli::cli_warn(c(
      "!" = "The reviewed EML sidecar writes {length(refused)} key{?s} inline, so {?its/their} {.field sha256} could not be pinned without rewriting the whole document.",
      .ms_cli_bullets(refused),
      # No cli pluralization in this element: it interpolates nothing, so a
      # `{?a/b}` here aborts with "Cannot pluralize without a quantity" -- which
      # is exactly what happened, and was found only because this otherwise
      # unreachable path got a test.
      "i" = "Rewrite each as a block mapping with {.field path} and {.field sha256} on their own lines, then re-run."
    ))
  }
  writeLines(lines, mapping_path)
  mapping_path
}

#' Write the reviewed semantic closure for a Salmon Data Package
#'
#' Produces the two files [write_eml_from_sdp()] and [publish_sdp_to_knb()]
#' require and neither writes: `metadata/semantic_vocabulary.csv`, one evidence
#' row per canonical measurement IRI, and `reviewed_semantic_selections.csv`,
#' exactly one `accepted` row per canonical review target. Both row sets are
#' derived from the package on disk, each vocabulary row's
#' `reviewed_snapshot_sha256` is computed, and the two file digests in
#' `metadata/eml-mapping.yml` are rewritten when that sidecar exists -- so no
#' digest is ever hand-written.
#'
#' @section The two canonical sets are not one set:
#' The vocabulary describes IRIs the EML measurement and method paths emit: the
#' six semantic fields of every `measurement` dictionary row, a table-level
#' `method_iri`, and any `sosa:usedProcedure` reached through a code value. The
#' ledger describes slots a reviewer decided: the same six dictionary fields
#' plus a table's `observation_unit_iri` and `method_iri`. So an
#' `observation_unit_iri` is a review target and not a vocabulary term, and a
#' code-resolved procedure is a vocabulary term and not a review target.
#' Neither set can be reasoned from the other, which is why both are derived
#' here.
#'
#' @section Unresolvable IRIs become gaps, not errors:
#' Evidence is resolved by re-running the package's own deterministic search
#' ([find_terms()]) for each IRI and keeping the hit whose IRI matches. An IRI
#' no search returns is reported as a row of `gaps` -- the shape
#' [detect_semantic_term_gaps()] returns, plus an `unresolved_iri` column --
#' and both files are still written without it. That is deliberate: an IRI
#' absent from every searched vocabulary is an ontology gap to file through
#' [render_ontology_term_request()] and [submit_term_request_issues()], not a
#' reason to leave the user with no files at all. The omission is not silent:
#' attempting EML export then names the same IRI as missing from the
#' vocabulary.
#'
#' @section Hand-supplied evidence:
#' `find_terms()` fills `label`, `definition`, `source`, `ontology`,
#' `resource_kind` and `type_iris` for `smn` and `gcdfo`. It cannot fill
#' `native_type` or `source_url`, which describe the ontology artifact rather
#' than the term -- both are derived here from the resolved source and can be
#' overridden -- and it cannot search QUDT at all, so a QUDT row is entirely
#' hand-authored. `confidence` and `review_rationale` are human judgements: they
#' are read from `semantic_suggestions.csv` where [apply_sdp_semantics()]
#' recorded them, and otherwise written as a `REVIEW REQUIRED:` placeholder with
#' a warning naming every target that got one. A placeholder rationale satisfies
#' the ledger's non-empty check, so replace it before publication; the warning
#' and the marker are the only signals, deliberately, because judging a
#' rationale is not a validator's job.
#'
#' @param path Path to an existing Salmon Data Package directory.
#' @param evidence Optional data frame of hand-supplied closure rows, one per
#'   IRI, with an `iri` column and any of `label`, `definition`, `source`,
#'   `ontology`, `resource_kind`, `type_iris`, `native_type`, `source_url`,
#'   `source_artifact_sha256`, `confidence`, `review_rationale`. Supplied
#'   non-empty values win over resolved ones field by field, so a row may
#'   correct one field and leave the rest to the search. An optional
#'   `target_sdp_field` column narrows a row to one slot, for an IRI selected in
#'   more than one. When a row supplies every required vocabulary field, no
#'   search runs for that IRI at all.
#' @param search_fn Function used to search terms. Defaults to [find_terms()].
#'   A test hook; the signature is `function(query, role, sources)`.
#' @param sources Vocabulary sources to search. Defaults to
#'   `c("smn", "gcdfo")`, the two this package resolves deterministically.
#' @param quiet Suppress the progress and summary messages. Warnings about gaps
#'   and placeholder rationales are not suppressed.
#'
#' @return Invisibly, a list with `vocabulary` and `review` (the two tibbles as
#'   written), `gaps` (the unresolvable IRIs in term-gap shape),
#'   `measurement_iris` and `review_targets` (the two canonical sets),
#'   `placeholders` (ledger rows that got a `REVIEW REQUIRED:` rationale), and
#'   `files` (the paths written).
#'
#' @seealso [write_eml_from_sdp()], [publish_sdp_to_knb()],
#'   [detect_semantic_term_gaps()], [render_ontology_term_request()],
#'   [submit_term_request_issues()]
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # Everything the deterministic search can resolve, resolved.
#' closure <- write_sdp_semantic_closure("path/to/sdp")
#'
#' # QUDT is not a searchable source, so a unit row is hand-authored.
#' closure <- write_sdp_semantic_closure(
#'   "path/to/sdp",
#'   evidence = tibble::tibble(
#'     iri = "https://qudt.org/vocab/unit/INDIV",
#'     label = "Individual",
#'     definition = "A counting unit denoting one organism.",
#'     source = "qudt",
#'     ontology = "qudt",
#'     resource_kind = "Unit",
#'     type_iris = "http://qudt.org/schema/qudt/Unit",
#'     native_type = "qudt:Unit",
#'     source_url = "https://qudt.org/vocab/unit/",
#'     confidence = "high",
#'     review_rationale = "Values are whole counts of organisms."
#'   )
#' )
#'
#' # Anything the search could not resolve is a term request, not a failure.
#' if (nrow(closure$gaps) > 0) {
#'   requests <- render_ontology_term_request(closure$gaps, ask = FALSE)
#' }
#' }
write_sdp_semantic_closure <- function(path,
                                       evidence = NULL,
                                       search_fn = find_terms,
                                       sources = c("smn", "gcdfo"),
                                       quiet = FALSE) {
  if (!is.character(path) || length(path) != 1L || is.na(path)) {
    cli::cli_abort("{.arg path} must be a single package directory path.")
  }
  if (!dir.exists(path)) {
    cli::cli_abort("Directory {.path {path}} does not exist.")
  }
  if (!is.function(search_fn)) {
    cli::cli_abort("{.arg search_fn} must be a function.")
  }
  sources <- unique(trimws(as.character(sources)))
  sources <- sources[!is.na(sources) & nzchar(sources)]
  if (length(sources) == 0L) {
    cli::cli_abort("{.arg sources} must name at least one vocabulary source.")
  }
  evidence <- .ms_closure_normalize_evidence(evidence)

  pkg <- read_salmon_datapackage(path)
  dictionary <- pkg$dictionary
  if (is.null(dictionary)) {
    dictionary <- tibble::tibble()
  }
  decisions <- .ms_closure_read_decisions(path)

  # ------------------------------------------------------------------
  # Both canonical sets, derived from the package rather than transcribed.
  # Radix ordering throughout: these orders become the row order of two CSVs
  # whose bytes are hashed into the reviewed sidecar.
  # ------------------------------------------------------------------
  measurement_iris <- .ms_closure_column(
    .ms_eml_canonical_measurement_iris(path, pkg)
  )
  measurement_iris <- sort(unique(measurement_iris[nzchar(measurement_iris)]),
    method = "radix"
  )

  review_targets <- tibble::as_tibble(.ms_eml_canonical_review_targets(pkg))
  if (nrow(review_targets) > 0L) {
    review_targets[] <- lapply(review_targets, .ms_closure_column)
    review_targets <- review_targets[
      order(
        review_targets$dataset_id,
        review_targets$table_id,
        review_targets$column_name,
        review_targets$target_scope,
        review_targets$target_sdp_field,
        review_targets$dictionary_role,
        review_targets$iri,
        method = "radix"
      ),
      ,
      drop = FALSE
    ]
  } else {
    review_targets <- tibble::tibble(
      dataset_id = character(),
      table_id = character(),
      column_name = character(),
      target_scope = character(),
      target_sdp_field = character(),
      dictionary_role = character(),
      iri = character()
    )
  }

  if (!quiet) {
    cli::cli_inform(c(
      "i" = "Deriving the reviewed closure for {.path {path}}.",
      "*" = "{length(measurement_iris)} canonical measurement IRI{?s}.",
      "*" = "{nrow(review_targets)} canonical review target{?s}."
    ))
  }

  # ------------------------------------------------------------------
  # Vocabulary evidence, one row per measurement IRI.
  # ------------------------------------------------------------------
  required_fields <- .ms_closure_required_vocabulary_fields()
  vocabulary_rows <- list()
  gap_rows <- list()
  for (iri in measurement_iris) {
    supplied <- vapply(
      setdiff(.ms_closure_vocabulary_fields(), "iri"),
      function(field) .ms_closure_evidence_value(evidence, iri, field),
      character(1)
    )
    resolved <- if (any(!nzchar(supplied[required_fields]))) {
      if (!quiet) {
        cli::cli_inform(c("*" = "Resolving {.url {iri}}."))
      }
      .ms_closure_search_evidence(
        iri,
        .ms_closure_queries(iri, decisions, review_targets, dictionary),
        .ms_closure_iri_roles(
          iri,
          review_targets,
          measurement_only = !iri %in% review_targets$iri
        ),
        sources,
        search_fn
      )
    } else {
      list(values = NULL, query = "", role = "")
    }

    values <- supplied
    if (!is.null(resolved$values)) {
      for (field in .ms_closure_search_evidence_fields()) {
        if (!nzchar(values[[field]])) {
          values[[field]] <- resolved$values[[field]]
        }
      }
    }
    if (!nzchar(values[["source_url"]])) {
      values[["source_url"]] <- .ms_closure_source_url(values[["source"]])
    }
    if (!nzchar(values[["native_type"]])) {
      values[["native_type"]] <- .ms_closure_native_type(values[["resource_kind"]])
    }

    if (any(!nzchar(values[required_fields]))) {
      gap_rows[[length(gap_rows) + 1L]] <- .ms_closure_gap_row(
        iri,
        review_targets,
        dictionary,
        resolved$query,
        sources
      )
      next
    }

    row <- tibble::as_tibble(as.list(c(iri = iri, values)))
    vocabulary_rows[[length(vocabulary_rows) + 1L]] <-
      row[, .ms_closure_vocabulary_fields(), drop = FALSE]
  }

  vocabulary <- if (length(vocabulary_rows) > 0L) {
    dplyr::bind_rows(vocabulary_rows)
  } else {
    tibble::as_tibble(stats::setNames(
      rep(list(character()), length(.ms_closure_vocabulary_fields())),
      .ms_closure_vocabulary_fields()
    ))
  }

  # ONE VALUE, ONE RENDERING. Every cell was coerced to text exactly once, by
  # `.ms_closure_text()`, when the row was built. The same character vector is
  # the sort key below, the digest input, and the CSV byte -- `write_csv()`
  # writes a character column verbatim -- so what is sorted is what is written.
  if (nrow(vocabulary) > 0L) {
    vocabulary <- vocabulary[
      order(vocabulary$iri, method = "radix"),
      ,
      drop = FALSE
    ]
    vocabulary$reviewed_snapshot_sha256 <- vapply(
      seq_len(nrow(vocabulary)),
      function(index) {
        .ms_eml_vocabulary_snapshot_sha256(vocabulary[index, , drop = FALSE])
      },
      character(1)
    )
  } else {
    vocabulary$reviewed_snapshot_sha256 <- character()
  }

  # ------------------------------------------------------------------
  # The review ledger: one accepted row per canonical target.
  # ------------------------------------------------------------------
  placeholder_rationale <- paste(
    "REVIEW REQUIRED: record why this IRI was selected for this slot.",
    "Supply it as `review_rationale` through the `evidence` argument of",
    "write_sdp_semantic_closure(), or record a decision reason with",
    "accept_suggestion() before applying it."
  )
  review <- review_targets
  review$decision <- rep("accepted", nrow(review))
  review$confidence <- rep("unassessed", nrow(review))
  review$review_rationale <- rep("", nrow(review))
  placeholders <- rep(FALSE, nrow(review))
  for (index in seq_len(nrow(review))) {
    iri <- review$iri[[index]]
    field <- review$target_sdp_field[[index]]
    confidence <- .ms_closure_evidence_value(evidence, iri, "confidence", field)
    if (nzchar(confidence)) {
      review$confidence[[index]] <- confidence
    }
    rationale <- .ms_closure_evidence_value(
      evidence,
      iri,
      "review_rationale",
      field
    )
    if (!nzchar(rationale)) {
      recorded <- decisions[
        decisions$iri == iri &
          (!nzchar(decisions$table_id) |
            decisions$table_id == review$table_id[[index]]) &
          (!nzchar(decisions$column_name) |
            decisions$column_name == review$column_name[[index]]) &
          (!nzchar(decisions$target_sdp_field) |
            decisions$target_sdp_field == field) &
          nzchar(decisions$decision_reason),
        ,
        drop = FALSE
      ]
      if (nrow(recorded) > 0L) {
        rationale <- recorded$decision_reason[[1]]
      }
    }
    if (!nzchar(rationale)) {
      rationale <- placeholder_rationale
      placeholders[[index]] <- TRUE
    }
    review$review_rationale[[index]] <- rationale
  }
  review <- review[, .ms_closure_ledger_fields(), drop = FALSE]

  # ------------------------------------------------------------------
  # Write, then pin.
  # ------------------------------------------------------------------
  declared <- .ms_closure_mapping_paths(path)
  vocabulary_file <- .ms_closure_resolve_write_path(path, declared$vocabulary)
  review_file <- .ms_closure_resolve_write_path(path, declared$review)
  readr::write_csv(vocabulary, vocabulary_file, na = "")
  readr::write_csv(review, review_file, na = "")
  mapping_file <- .ms_closure_update_mapping(path, vocabulary_file, review_file)

  gaps <- if (length(gap_rows) > 0L) {
    out <- dplyr::bind_rows(gap_rows)
    out[
      order(
        out$dataset_id, out$table_id, out$column_name,
        out$target_sdp_field, out$unresolved_iri,
        method = "radix", na.last = TRUE
      ),
      ,
      drop = FALSE
    ]
  } else {
    .ms_closure_empty_gaps()
  }

  if (nrow(gaps) > 0L) {
    cli::cli_warn(c(
      "!" = "{nrow(gaps)} canonical measurement IRI{?s} could not be resolved from {.val {sources}} and {?is/are} absent from the reviewed vocabulary.",
      .ms_cli_bullets(paste0(gaps$target_sdp_field, " = ", gaps$unresolved_iri)),
      "i" = "Each is a row of the returned {.field gaps} table; pass it to {.fn render_ontology_term_request} to file a term request, or supply a row through {.arg evidence}."
    ))
  }

  placeholder_rows <- review[placeholders, , drop = FALSE]
  if (nrow(placeholder_rows) > 0L) {
    cli::cli_warn(c(
      "!" = "{nrow(placeholder_rows)} review target{?s} got a {.code REVIEW REQUIRED:} rationale because no reviewer rationale was recorded.",
      .ms_cli_bullets(paste0(
        placeholder_rows$table_id,
        ifelse(
          nzchar(placeholder_rows$column_name),
          paste0(".", placeholder_rows$column_name),
          ""
        ),
        ".",
        placeholder_rows$target_sdp_field
      )),
      "i" = "Supply {.field review_rationale} through {.arg evidence}, or record decision reasons with {.fn accept_suggestion}, before publication."
    ))
  }

  if (!quiet) {
    cli::cli_inform(c(
      "v" = "Wrote {nrow(vocabulary)} vocabulary row{?s} and {nrow(review)} ledger row{?s}.",
      .ms_cli_bullets(c(vocabulary_file, review_file, mapping_file), name = "*")
    ))
  }

  invisible(list(
    vocabulary = vocabulary,
    review = review,
    gaps = gaps,
    measurement_iris = measurement_iris,
    review_targets = review_targets,
    placeholders = placeholder_rows,
    files = c(
      vocabulary = vocabulary_file,
      review = review_file,
      mapping = if (is.null(mapping_file)) NA_character_ else mapping_file
    )
  ))
}
