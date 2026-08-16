# Static guard for the "a semantic role is a contract across five layers" rule
# in AGENTS.md. Adding or renaming a role means touching the role/target maps,
# the bundle roles and slot fields, the role-hint vocabulary, the retrieval
# filters, and the deterministic validators.
#
# The hint layer and the ranking preferences are the ones that get forgotten,
# and forgetting either is silent:
#   * A role with no hint emitter has 100% of its correct accepts downgraded to
#     `review`, because .ms_validate_semantic_role_type() vetoes any accept
#     whose candidate carries hints not naming the role. That is how sdp-0.3.0
#     shipped `statistical_modifier` broken through CI and PR review — every
#     test using a hand-written `role_hints` fixture still passed.
#   * A role with no ontology-preferences.csv row ranks with no source
#     preferences at all, and .gcdfo_filter_for_role() falls through to
#     "keep everything".
# Neither failure raises anything. Only a cross-layer check like this one sees
# them, so these tests deliberately inspect function bodies rather than
# behaviour driven by fixtures that could themselves be stale.
#
# LIMITATIONS, stated plainly:
#   1. The body checks prove a role *string* is present in the emitter or the
#      filter, not that the branch producing it is reachable or correct.
#   2. srcrefs are dropped on install, so a failure names the function, not a
#      line.

# .ms_semantic_bundle_slot_fields() is the authority: the dictionary slots, in
# order. Every other layer is checked against it rather than against a second
# hand-maintained list.
slot_roles <- function() {
  names(metasalmon:::.ms_semantic_bundle_slot_fields())
}

# Roles the salmon-ontology hint layers can emit. Two documented differences
# from the dictionary slots:
#   * `unit` is absent — units resolve from QUDT/NVS, never from smn/gcdfo, and
#     .gcdfo_filter_for_role() drops the whole index for that role.
#   * `method` is present although it is not a dictionary slot — it survives
#     for codes.csv code values.
hint_roles <- c(
  "variable", "property", "entity", "constraint", "method",
  "statistical_modifier"
)

# source_hint values name a retrieval backend; `local` covers both salmon
# ontologies, which sources_for_role() names individually.
hint_to_sources <- list(local = c("smn", "gcdfo"))

# Several of the maps below are local variables inside a function, so the body
# is the only place to read them. Normalizing whitespace keeps the fixed-string
# checks robust against deparse's line breaking.
fn_source_text <- function(fn) {
  gsub("\\s+", " ", paste(deparse(body(fn), width.cutoff = 500L), collapse = " "))
}

test_that("the bundle review prompt judges exactly the dictionary slots", {
  # The prompt's opening instruction is a role-contract surface: sdp-0.3.0 left
  # it naming the removed `method` slot and omitting the one that replaced it,
  # so the prompt contradicted its own later "A method is never a dictionary
  # slot" line.
  prompt <- metasalmon:::.ms_semantic_bundle_system_prompt()
  judge <- regmatches(prompt, regexpr("Judge [^.]*\\.", prompt))

  expect_length(judge, 1L)
  for (role in slot_roles()) {
    expect_match(judge, role, fixed = TRUE)
  }
  # A method is never a dictionary slot, so it is never judged as one.
  expect_false(grepl("method", judge, fixed = TRUE))
})

test_that("the bundle prompt describes the roles it asks the model to judge", {
  prompt <- metasalmon:::.ms_semantic_bundle_system_prompt()
  for (role in slot_roles()) {
    expect_match(prompt, role, fixed = TRUE)
  }
})

test_that("every dictionary slot role has ontology ranking preferences", {
  prefs <- metasalmon:::.role_preferences()
  expect_gt(nrow(prefs), 0L)
  expect_equal(setdiff(slot_roles(), prefs$role), character(0))
})

test_that("method keeps ranking preferences for codes.csv code values", {
  # The dictionary slot is gone but the role is not: code-value targets still
  # search shared-vocabulary procedures, so removing these rows would be wrong.
  prefs <- metasalmon:::.role_preferences()
  method_prefs <- dplyr::filter(prefs, .data$role == "method")

  expect_gt(nrow(method_prefs), 0L)
  expect_true("method" %in% metasalmon:::.ms_semantic_bundle_roles())
  expect_false("method" %in% slot_roles())
})

test_that("statistical_modifier prefers the reviewed salmon vocabulary", {
  prefs <- metasalmon:::.role_preferences()
  modifier_prefs <- dplyr::filter(prefs, .data$role == "statistical_modifier")

  expect_gt(nrow(modifier_prefs), 0L)
  smn_pref <- dplyr::filter(modifier_prefs, .data$ontology == "smn")
  # Checked before indexing so a missing row fails here rather than erroring.
  expect_equal(nrow(smn_pref), 1L)
  expect_equal(smn_pref$priority, 1)
  # I-ADOPT is where the component is defined; STATO is the general fallback.
  expect_true("iadopt" %in% modifier_prefs$ontology)
  expect_false(any(modifier_prefs$alignment_only))
})

test_that("every preference row names a role the retrieval layer can serve", {
  # Catches both halves of the drift: a preference row for a role
  # sources_for_role() does not know, and a role whose preferred ontology sits
  # behind a backend that role never queries.
  prefs <- metasalmon:::.role_preferences()
  known_roles <- c(metasalmon:::.ms_semantic_bundle_roles(), "wikidata")
  expect_equal(setdiff(unique(prefs$role), known_roles), character(0))

  findings <- character()
  for (i in seq_len(nrow(prefs))) {
    role <- prefs$role[[i]]
    # `wikidata` is the alignment-only pseudo-role, not a retrievable role.
    if (identical(role, "wikidata")) {
      next
    }
    hint <- prefs$source_hint[[i]]
    expected <- if (is.null(hint_to_sources[[hint]])) hint else hint_to_sources[[hint]]
    if (!any(expected %in% sources_for_role(role))) {
      findings <- c(
        findings,
        paste0(role, "/", prefs$ontology[[i]], " needs source ", hint)
      )
    }
  }

  if (length(findings) > 0) {
    fail(paste0(
      "An ontology-preferences.csv row prefers a source that\n",
      "sources_for_role() never queries for that role, so the preference\n",
      "can never apply. See AGENTS.md on the five-layer role contract.\n",
      paste(findings, collapse = "\n")
    ))
  }
  succeed()
})

test_that("the role-hint layers emit every role they can flag", {
  # This is the layer AGENTS.md says gets forgotten. A flag with no emitter
  # never reaches `role_hints`, and the role-type validator then downgrades
  # every correct accept for that role.
  flags <- metasalmon:::.smn_role_flags(
    label = "Mean",
    definition = "The arithmetic mean of the observed values.",
    resource_kind = "Concept",
    module_name = "07-controlled-vocabularies",
    in_scheme = "https://w3id.org/smn/StatisticalModifierScheme",
    parent_iris = character(),
    type_iris = "http://w3id.org/iadopt/ont/StatisticalModifier",
    iri = "https://w3id.org/smn/MeanStatisticalModifier"
  )
  expect_setequal(names(flags), paste0("is_", hint_roles))

  ttl_emitter <- fn_source_text(metasalmon:::.parse_smn_ttl_modules)
  rdf_emitter <- fn_source_text(metasalmon:::.parse_salmon_rdfxml)
  for (role in hint_roles) {
    quoted <- paste0("\"", role, "\"")
    expect_match(ttl_emitter, quoted, fixed = TRUE)
    expect_match(rdf_emitter, quoted, fixed = TRUE)
  }
})

test_that("the gcdfo role filter has a case for every role", {
  # Without a case the role falls through to "keep everything", so a query
  # like "mean" matches any variable whose definition merely contains the word
  # and only ranking keeps the real modifier on top.
  filter_body <- fn_source_text(metasalmon:::.gcdfo_filter_for_role)
  for (role in union(slot_roles(), hint_roles)) {
    expect_match(filter_body, paste0(role, " = "), fixed = TRUE)
  }
})

test_that("the role/field maps agree with the dictionary slot fields", {
  # Both maps are function-local, so the body is the only place to read them.
  slot_fields <- metasalmon:::.ms_semantic_bundle_slot_fields()
  apply_body <- fn_source_text(metasalmon::apply_semantic_suggestions)
  discover_body <- fn_source_text(metasalmon:::.ms_semantic_discover_targets)

  for (role in names(slot_fields)) {
    field <- unname(slot_fields[[role]])
    # apply_semantic_suggestions() maps role -> field; target discovery maps
    # field -> role. Both must know every slot.
    expect_match(apply_body, paste0(role, " = \"", field, "\""), fixed = TRUE)
    expect_match(discover_body, paste0(field, " = \"", role, "\""), fixed = TRUE)
  }
})
