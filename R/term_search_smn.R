# Helpers for Salmon Domain Ontology (SMN) module indexing
#
# The shared SMN root (`https://w3id.org/smn/`) is the canonical entrypoint for
# the latest ontology. For lightweight lexical search we index the canonical
# module IRIs under `https://w3id.org/smn/modules/...`, which currently remain
# Turtle-first on W3ID.

.smn_module_urls <- function() {
  base <- "https://w3id.org/smn/modules"
  c(
    paste0(base, "/01-entity-systematics"),
    paste0(base, "/02-observation-measurement"),
    paste0(base, "/03-assessment-benchmarks"),
    paste0(base, "/04-management-governance"),
    paste0(base, "/05-provenance-quality"),
    paste0(base, "/06-data-interoperability"),
    paste0(base, "/07-controlled-vocabularies"),
    paste0(base, "/08-rda-case-study-profile-bridges"),
    paste0(base, "/09-rda-neville-decomposition-profile-bridges"),
    paste0(base, "/alignment-main"),
    paste0(base, "/alignment-research")
  )
}

.smn_cache_slug <- function(url) {
  slug <- sub("^https?://", "", url)
  slug <- gsub("[^A-Za-z0-9]+", "-", slug)
  slug <- gsub("(^-+|-+$)", "", slug)
  slug
}

.smn_fetch_module_path <- function(url, cache_dir) {
  fetch_salmon_ontology(
    url = url,
    accept = "text/turtle, text/plain;q=0.9",
    cache_dir = file.path(cache_dir, .smn_cache_slug(url)),
    fallback_urls = character()
  )
}

.smn_module_index_bundle <- function(cache_dir) {
  paths <- vapply(.smn_module_urls(), .smn_fetch_module_path, character(1), cache_dir = cache_dir)
  info <- file.info(paths)
  stamp <- paste(
    paste(paths, as.numeric(info$mtime), info$size, sep = "::"),
    collapse = "|"
  )

  list(
    paths = paths,
    stamp = stamp,
    index = .parse_smn_ttl_modules(paths)
  )
}

.smn_ttl_prefixes <- function(text) {
  lines <- unlist(strsplit(text, "\n", fixed = TRUE), use.names = FALSE)
  prefix_lines <- grep("^\\s*@prefix\\s+", lines, value = TRUE)
  if (length(prefix_lines) == 0) {
    return(character())
  }

  out <- stats::setNames(character(length(prefix_lines)), character(length(prefix_lines)))
  idx <- 0L
  for (line in prefix_lines) {
    m <- regexec("^\\s*@prefix\\s+([A-Za-z][A-Za-z0-9_-]*):\\s*<([^>]+)>\\s*\\.", line, perl = TRUE)
    hits <- regmatches(line, m)[[1]]
    if (length(hits) == 3) {
      idx <- idx + 1L
      out[[idx]] <- hits[[3]]
      names(out)[[idx]] <- hits[[2]]
    }
  }

  out[seq_len(idx)]
}

.smn_expand_curie <- function(term, prefixes) {
  term <- trimws(term)
  if (!nzchar(term)) {
    return(NA_character_)
  }
  if (startsWith(term, "<") && endsWith(term, ">")) {
    return(substring(term, 2L, nchar(term) - 1L))
  }
  if (!grepl(":", term, fixed = TRUE)) {
    return(term)
  }

  prefix <- sub(":.*$", "", term)
  local <- sub("^[^:]+:", "", term)
  base <- prefixes[[prefix]]
  if (is.null(base) || !nzchar(base)) {
    return(term)
  }
  paste0(base, local)
}

.smn_literal_values <- function(text) {
  pieces <- gregexpr('"[^"]+"(?:@[A-Za-z-]+)?', text, perl = TRUE)
  vals <- regmatches(text, pieces)[[1]]
  if (length(vals) == 0) {
    return(character())
  }
  vals <- sub('^"', "", vals)
  vals <- sub('"(@[A-Za-z-]+)?$', "", vals)
  vals
}

.smn_term_values <- function(text, prefixes) {
  pieces <- gregexpr('(<[^>]+>|[A-Za-z][A-Za-z0-9_-]*:[^\\s,;]+)', text, perl = TRUE)
  vals <- regmatches(text, pieces)[[1]]
  if (length(vals) == 0) {
    return(character())
  }
  vals <- vapply(vals, .smn_expand_curie, character(1), prefixes = prefixes)
  vals[!is.na(vals) & nzchar(vals)]
}

.smn_predicate_chunks <- function(rest, predicate) {
  pred <- gsub("([.|()\\^{}+$*?\\[\\]\\\\])", "\\\\\\1", predicate, perl = TRUE)
  pattern <- paste0("(?:^|;)\\s*", pred, "\\s+([^;]+)")
  pieces <- gregexpr(pattern, rest, perl = TRUE)
  vals <- regmatches(rest, pieces)[[1]]
  if (length(vals) == 0) {
    return(character())
  }
  vals <- sub(paste0("^(?:;)?\\s*", pred, "\\s+"), "", trimws(vals), perl = TRUE)
  trimws(vals)
}

.smn_subject_local_name <- function(iri) {
  if (is.na(iri) || !nzchar(iri)) {
    return(NA_character_)
  }
  sub("^.*/", "", iri)
}

.smn_resource_kind <- function(type_iris) {
  types <- tolower(type_iris)
  if (any(grepl("skos/core#conceptscheme$", types))) return("ConceptScheme")
  if (any(grepl("skos/core#concept$", types))) return("Concept")
  if (any(grepl("owl#namedindividual$", types))) return("NamedIndividual")
  if (any(grepl("owl#objectproperty$", types))) return("ObjectProperty")
  if (any(grepl("owl#dataproperty$", types))) return("DataProperty")
  if (any(grepl("owl#annotationproperty$", types))) return("AnnotationProperty")
  if (any(grepl("owl#class$", types))) return("Class")
  NA_character_
}

.smn_role_flags <- function(label, definition, resource_kind, module_name, in_scheme, parent_iris, type_iris, iri) {
  subject_text <- tolower(paste(
    label,
    resource_kind,
    in_scheme,
    parent_iris,
    type_iris,
    .smn_subject_local_name(iri),
    collapse = " "
  ))
  evidence_text <- tolower(paste(subject_text, definition))

  # Treat only the vocabulary container itself as a scheme. A SKOS concept's
  # `inScheme` value is evidence about the concept, not evidence that the
  # concept is a ConceptScheme.
  is_scheme <- identical(tolower(resource_kind %||% ""), "conceptscheme") ||
    grepl("\\bscheme$", tolower(trimws(label %||% ""))) ||
    grepl("scheme$", tolower(.smn_subject_local_name(iri) %||% ""))

  # Role exclusions describe the term itself, so evaluate them against its
  # label/type/parents rather than incidental words in a prose definition. A
  # Stock remains an entity even when its definition says it is used in an
  # assessment; RecruitAbundance remains a variable when its definition states
  # that the value has an assessment context.
  entity_exclusion <- grepl(
    "measurement|benchmark|reference point|procedure|method|characteristic|property",
    subject_text
  ) ||
    grepl("\\bstock assessment\\b", subject_text) ||
    grepl("\\b(phase|context|origin)\\b", subject_text)
  is_entity <- (
    grepl("entity-systematics", module_name) |
      grepl(
        "entity|population|stock|river|habitat|taxon|organism|individual|group|stratum|species",
        subject_text
      )
  ) &&
    !is_scheme &&
    !entity_exclusion
  is_property <- grepl(
    "property|characteristic|length|weight|size|status|confidence|phase",
    subject_text
  )
  if (grepl("sosa/property", subject_text)) {
    is_property <- TRUE
  }
  is_method <- grepl("method|procedure|protocol|enumeration", subject_text)
  if (grepl("sosa/procedure", subject_text)) {
    is_method <- TRUE
  }
  is_constraint <- grepl("controlled-vocabularies", module_name) ||
    grepl(
      "constraint|context|phase|origin|benchmark|reference point|target|limit|status zone",
      subject_text
    )
  # sdp-0.3.0: statistical modifiers are their own I-ADOPT component, and smn
  # 0.0.3 gives them a scheme of their own. Without this hint every real
  # modifier concept reaches review carrying only the broad
  # "controlled-vocabularies" constraint hint, and the role-type validator
  # then vetoes the accept as role-incompatible.
  is_statistical_modifier <- grepl(
    "statisticalmodifier|statistical modifier",
    subject_text
  ) ||
    # Token fallback only inside the controlled-vocabulary module, so a
    # variable named TotalRunSize does not pick up a modifier hint.
    (
      grepl("controlled-vocabularies", module_name) &&
        grepl(
          "\\b(mean|median|average|maximum|minimum|total|cumulative|peak)\\b",
          subject_text
        )
    )
  is_variable <- (
    grepl(
      "measurement|abundance|count|rate|escapement|recruit",
      subject_text
    ) ||
      (
        grepl("measurement datum|abundance|count|rate|escapement", evidence_text) &&
          grepl("observedrateorabundance|measurement", subject_text)
      )
  ) &&
    !grepl(
      "context|scheme|benchmark|reference point",
      subject_text
    )

  list(
    is_variable = is_variable,
    is_property = is_property,
    is_entity = is_entity,
    is_constraint = is_constraint,
    is_method = is_method,
    is_statistical_modifier = is_statistical_modifier
  )
}

.parse_smn_ttl_modules <- function(paths) {
  rows <- list()
  idx <- 0L

  for (path_index in seq_along(paths)) {
    path <- unname(paths[[path_index]])
    if (!file.exists(path)) {
      next
    }

    text <- paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
    prefixes <- .smn_ttl_prefixes(text)
    stripped <- gsub("(?m)^\\s*#.*$", "", text, perl = TRUE)
    stripped <- gsub("(?m)^\\s*@prefix\\s+.*$", "", stripped, perl = TRUE)
    blocks <- strsplit(stripped, "\\n\\s*\\n+", perl = TRUE)[[1]]
    blocks <- trimws(blocks)
    blocks <- blocks[nzchar(blocks)]
    path_names <- names(paths)
    module_reference <- if (
      !is.null(path_names) &&
        length(path_names) >= path_index &&
        !is.na(path_names[[path_index]]) &&
        nzchar(path_names[[path_index]])
    ) {
      path_names[[path_index]]
    } else {
      path
    }
    module_name <- basename(sub("/+$", "", module_reference))

    for (block in blocks) {
      collapsed <- gsub("\\s+", " ", trimws(block), perl = TRUE)
      if (!nzchar(collapsed)) {
        next
      }

      subject <- sub("\\s.*$", "", collapsed)
      if (!grepl("^smn:", subject)) {
        next
      }

      iri <- .smn_expand_curie(subject, prefixes)
      if (!grepl("^https?://w3id\\.org/smn/", iri)) {
        next
      }

      rest <- trimws(sub("^\\S+\\s+", "", collapsed, perl = TRUE))
      type_iris <- unique(unlist(lapply(.smn_predicate_chunks(rest, "a"), .smn_term_values, prefixes = prefixes), use.names = FALSE))
      labels <- unique(c(
        unlist(lapply(.smn_predicate_chunks(rest, "rdfs:label"), .smn_literal_values), use.names = FALSE),
        unlist(lapply(.smn_predicate_chunks(rest, "skos:prefLabel"), .smn_literal_values), use.names = FALSE)
      ))
      alt_labels <- unique(unlist(lapply(.smn_predicate_chunks(rest, "skos:altLabel"), .smn_literal_values), use.names = FALSE))
      definition <- unique(c(
        unlist(lapply(.smn_predicate_chunks(rest, "iao:0000115"), .smn_literal_values), use.names = FALSE),
        unlist(lapply(.smn_predicate_chunks(rest, "skos:definition"), .smn_literal_values), use.names = FALSE),
        unlist(lapply(.smn_predicate_chunks(rest, "rdfs:comment"), .smn_literal_values), use.names = FALSE)
      ))
      in_scheme <- unique(unlist(lapply(.smn_predicate_chunks(rest, "skos:inScheme"), .smn_term_values, prefixes = prefixes), use.names = FALSE))
      parents <- unique(c(
        unlist(lapply(.smn_predicate_chunks(rest, "rdfs:subClassOf"), .smn_term_values, prefixes = prefixes), use.names = FALSE),
        unlist(lapply(.smn_predicate_chunks(rest, "skos:broader"), .smn_term_values, prefixes = prefixes), use.names = FALSE),
        unlist(lapply(.smn_predicate_chunks(rest, "owl:equivalentClass"), .smn_term_values, prefixes = prefixes), use.names = FALSE),
        unlist(lapply(.smn_predicate_chunks(rest, "rdfs:subPropertyOf"), .smn_term_values, prefixes = prefixes), use.names = FALSE)
      ))

      idx <- idx + 1L
      rows[[idx]] <- .smn_index_row(
        iri = iri,
        type_iris = type_iris,
        labels = labels,
        alt_labels = alt_labels,
        definition = definition,
        in_scheme = in_scheme,
        parents = parents,
        module_name = module_name,
        search_module = module_name
      )
    }
  }

  if (length(rows) == 0) {
    return(.smn_index_empty())
  }

  dplyr::bind_rows(rows) %>%
    dplyr::distinct(.data$iri, .keep_all = TRUE)
}

# One row of the smn term index, and the one place its role hints are emitted.
# Both smn readers build their rows here -- the module reader above and the
# release reader below -- so a term reaches ranking and the role-type validator
# with the same hints whichever way smn was read. `module_name` is the evidence
# `.smn_role_flags()` reads; `search_module` is the module name the module
# reader also folds into `search_text` (the release reader has none to fold).
.smn_index_row <- function(iri, type_iris, labels, alt_labels, definition,
                           in_scheme, parents, module_name,
                           search_module = character()) {
  label <- if (length(labels)) labels[[1]] else .smn_subject_local_name(iri)
  definition_text <- if (length(definition)) paste(definition, collapse = " | ") else ""
  resource_kind <- .smn_resource_kind(type_iris)
  role_flags <- .smn_role_flags(
    label = label,
    definition = definition_text,
    resource_kind = resource_kind,
    module_name = module_name,
    in_scheme = paste(in_scheme, collapse = " | "),
    parent_iris = paste(parents, collapse = " | "),
    type_iris = paste(type_iris, collapse = " | "),
    iri = iri
  )
  search_text <- tolower(paste(
    c(
      label,
      paste(alt_labels, collapse = " "),
      definition_text,
      paste(in_scheme, collapse = " "),
      paste(parents, collapse = " "),
      .smn_subject_local_name(iri),
      search_module
    ),
    collapse = " "
  ))
  role_hints <- paste(
    c(
      if (isTRUE(role_flags$is_variable)) "variable",
      if (isTRUE(role_flags$is_property)) "property",
      if (isTRUE(role_flags$is_entity)) "entity",
      if (isTRUE(role_flags$is_constraint)) "constraint",
      if (isTRUE(role_flags$is_method)) "method",
      if (isTRUE(role_flags$is_statistical_modifier)) "statistical_modifier"
    ),
    collapse = "|"
  )

  tibble::tibble(
    iri = iri,
    label = label,
    alt_labels = paste(alt_labels, collapse = " | "),
    definition = definition_text,
    resource_kind = resource_kind %||% "Resource",
    in_scheme = paste(in_scheme, collapse = " | "),
    parent_iris = paste(parents, collapse = " | "),
    type_iris = paste(type_iris, collapse = " | "),
    search_text = search_text,
    is_variable = isTRUE(role_flags$is_variable),
    is_property = isTRUE(role_flags$is_property),
    is_entity = isTRUE(role_flags$is_entity),
    is_constraint = isTRUE(role_flags$is_constraint),
    is_method = isTRUE(role_flags$is_method),
    role_hints = role_hints
  )
}

.smn_index_empty <- function() {
  tibble::tibble(
    iri = character(),
    label = character(),
    alt_labels = character(),
    definition = character(),
    resource_kind = character(),
    in_scheme = character(),
    parent_iris = character(),
    type_iris = character(),
    search_text = character(),
    is_variable = logical(),
    is_property = logical(),
    is_entity = logical(),
    is_constraint = logical(),
    is_method = logical(),
    role_hints = character()
  )
}

# The smn term index of one release snapshot, read from its RDF/XML.
#
# A release is one merged graph, `docs/releases/<version>/smn.owl` in the
# salmon-domain-ontology repository, so it has no modules for the reader above
# to read, and its Turtle is a serializer's output, which that reader's
# line-based parse does not read (it found no terms in the 0.0.3 release). The
# RDF/XML is read with an XML parser and every row is built by
# `.smn_index_row()`, so the terms carry the hints the module reader gives
# them. Two things differ between a release and the modules, and each is read
# so that the hints still agree:
#
# * The serializer declares every individual `owl:NamedIndividual`, which no
#   smn module asserts. The declaration is left out of the type evidence: kept,
#   its word "individual" gave every SKOS concept an entity hint.
# * A release says nothing about which module a term came from. smn keeps its
#   shared SKOS schemes and concepts, and only those, in
#   `07-controlled-vocabularies` (its `ontology/modules/README.md`, and Layer B
#   of its CONVENTIONS.md), so a term typed `skos:Concept` or
#   `skos:ConceptScheme` is read as that module's. The only other module the
#   hints read is `01-entity-systematics`, whose entity hint rests on the
#   module alone, so a release cannot reproduce it.
#
# Measured on the smn main branch at 0e42037 (its modules against its own
# merged build): 126 of 129 shared terms carry the same hints. The other three
# are GeographicFeature, which loses the hint `01-entity-systematics` gave it,
# and YearBasis and AgeNotation, whose label and definition sit in a module
# the module reader drops as a duplicate block, so only this reader sees them.
.smn_release_index <- function(doc) {
  ns <- .ms_rdfxml_ns()
  serializer_types <- "http://www.w3.org/2002/07/owl#NamedIndividual"
  fields <- list()

  for (node in xml2::xml_find_all(doc, "/rdf:RDF/*[@rdf:about]", ns = ns)) {
    iri <- xml2::xml_attr(node, "rdf:about", ns = ns)
    if (is.na(iri) || !grepl("^https?://w3id\\.org/smn/", iri)) {
      next
    }
    resource <- function(xpath) {
      values <- xml2::xml_attr(xml2::xml_find_all(node, xpath, ns = ns), "rdf:resource", ns = ns)
      values[!is.na(values) & nzchar(values)]
    }
    literal <- function(xpath) {
      values <- xml2::xml_text(xml2::xml_find_all(node, xpath, ns = ns))
      values <- trimws(gsub("\\s+", " ", values, perl = TRUE))
      values[nzchar(values)]
    }
    element_type <- paste0(
      xml2::xml_find_chr(node, "namespace-uri(.)"),
      xml2::xml_find_chr(node, "local-name(.)")
    )
    if (identical(element_type, paste0(ns[["rdf"]], "Description"))) {
      element_type <- character()
    }

    # One subject can be spread over several nodes; its values are gathered
    # predicate by predicate, in the order the module reader reads them.
    seen <- fields[[iri]] %||% list()
    add <- function(name, values) c(seen[[name]], values)
    fields[[iri]] <- list(
      type = add("type", c(element_type, resource("./rdf:type"))),
      label = add("label", literal("./rdfs:label")),
      pref_label = add("pref_label", literal("./skos:prefLabel")),
      alt_label = add("alt_label", literal("./skos:altLabel")),
      iao_definition = add("iao_definition", literal("./obo:IAO_0000115")),
      skos_definition = add("skos_definition", literal("./skos:definition")),
      comment = add("comment", literal("./rdfs:comment")),
      in_scheme = add("in_scheme", resource("./skos:inScheme")),
      sub_class_of = add("sub_class_of", resource("./rdfs:subClassOf")),
      broader = add("broader", resource("./skos:broader")),
      equivalent_class = add("equivalent_class", resource("./owl:equivalentClass")),
      sub_property_of = add("sub_property_of", resource("./rdfs:subPropertyOf"))
    )
  }

  rows <- list()
  for (iri in names(fields)) {
    f <- fields[[iri]]
    type_iris <- setdiff(unique(f$type), serializer_types)
    if (paste0(ns[["owl"]], "Ontology") %in% type_iris) {
      next
    }
    resource_kind <- .smn_resource_kind(type_iris)
    module_name <- if (isTRUE(resource_kind %in% c("Concept", "ConceptScheme"))) {
      "07-controlled-vocabularies"
    } else {
      ""
    }
    rows[[length(rows) + 1L]] <- .smn_index_row(
      iri = iri,
      type_iris = type_iris,
      labels = unique(c(f$label, f$pref_label)),
      alt_labels = unique(f$alt_label),
      definition = unique(c(f$iao_definition, f$skos_definition, f$comment)),
      in_scheme = unique(f$in_scheme),
      parents = unique(c(f$sub_class_of, f$broader, f$equivalent_class, f$sub_property_of)),
      module_name = module_name
    )
  }

  if (length(rows) == 0) {
    return(.smn_index_empty())
  }
  dplyr::bind_rows(rows)
}
