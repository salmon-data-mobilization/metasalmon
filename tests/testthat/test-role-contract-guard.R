# Static guard for the semantic-role contract in AGENTS.md — ALL SEVEN
# surfaces. Adding or renaming a role means touching every one of:
#
#   1. the target/role maps          (semantic-suggestions.R, semantics-helpers.R)
#   2. the bundle roles + slot fields (semantic-bundle-review.R, incl. the prompt)
#   3. the role-hint vocabulary      (.smn_role_flags + both hint emitters)
#   4. the retrieval filters         (sources_for_role, .gcdfo_filter_for_role)
#   5. the deterministic validators  (semantic-bundle-validators.R)
#   6. the ranking preferences       (inst/extdata/ontology-preferences.csv)
#   7. the role boosts               (role_boost in .ranking_profile_defaults)
#
# **This file is the answer to "did I reach every layer".** It has not always
# been. Through metasalmon 0.4.0 the seventh surface was checked in
# tests/testthat/test-smn-outranks-gcdfo.R and this file's header claimed to
# check "every layer" — a guard whose claimed scope exceeded its real scope,
# which is worse than a missing guard, because green read as "all seven
# verified" to whoever trusted the header. AGENTS.md carried that correction
# dated 2026-08-18; metasalmonpy's 0.4.0 parity work consolidated its own copy
# first (tests/test_role_contract_guard.py, hoisting ROLE_BOOST to a module
# constant so there was something to enumerate), and this is that consolidation
# ported back under Brett's 2026-08-17 ruling. Surface 5 turned out never to
# have been checked here at all, so the old claim was short by two, not one.
#
# **What would retire this file:** nothing short of the role vocabulary
# becoming a single declarative table that every layer reads, so that a role
# cannot exist in one place and be absent from another. Until then each layer
# is a separate hand-maintained map and only a cross-layer check sees the drift.
#
# Why body inspection rather than behaviour: the failures these tests catch do
# not raise. A role with no hint emitter has 100% of its correct accepts
# downgraded to `review`, because .ms_validate_semantic_role_type() vetoes any
# accept whose candidate carries hints not naming the role — that is how
# sdp-0.3.0 shipped `statistical_modifier` broken through CI and PR review,
# with every test using a hand-written `role_hints` fixture still passing. A
# role with no ontology-preferences.csv row ranks with no source preferences at
# all, and .gcdfo_filter_for_role() falls through to "keep everything". A role
# with no `role_boost` entry is scored on base weight alone. Fixture-driven
# behaviour tests cannot see any of these, because the fixture is itself the
# thing that has gone stale.
#
# LIMITATIONS, stated plainly:
#   1. The body checks prove a role *string* is present in the emitter, the
#      filter or the dispatcher, not that the branch producing it is reachable
#      or correct.
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

# Roles carrying a deterministic evidence gate, and the validator that enforces
# it. Keep this current when a role gains or loses a gate: a gate the
# dispatcher never calls is a validator that cannot fire, and a role whose gate
# was dropped accepts on the model's word alone.
role_evidence_validators <- list(
  method = ".ms_validate_semantic_method_evidence",
  statistical_modifier = ".ms_validate_semantic_modifier_evidence",
  constraint = ".ms_validate_semantic_constraint_evidence"
)

# Several of the maps below are local variables inside a function, so the body
# is the only place to read them. Normalizing whitespace keeps the fixed-string
# checks robust against deparse's line breaking.
fn_source_text <- function(fn) {
  gsub("\\s+", " ", paste(deparse(body(fn), width.cutoff = 500L), collapse = " "))
}


# ---------------------------------------------------------------------------
# SURFACE 1 — the target/role maps
# ---------------------------------------------------------------------------

test_that("SURFACE 1: the role/field maps agree with the dictionary slot fields", {
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


# ---------------------------------------------------------------------------
# SURFACE 2 — the bundle roles and slot fields (including the review prompt)
# ---------------------------------------------------------------------------

test_that("SURFACE 2: the bundle review prompt judges exactly the dictionary slots", {
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

test_that("SURFACE 2: the bundle prompt describes the roles it asks the model to judge", {
  prompt <- metasalmon:::.ms_semantic_bundle_system_prompt()
  for (role in slot_roles()) {
    expect_match(prompt, role, fixed = TRUE)
  }
})

test_that("SURFACE 2: method is a bundle role but never a dictionary slot", {
  # The dictionary slot is gone but the role is not: code-value targets still
  # search shared-vocabulary procedures.
  expect_true("method" %in% metasalmon:::.ms_semantic_bundle_roles())
  expect_false("method" %in% slot_roles())
  # Every dictionary slot is a bundle role; the reverse does not hold.
  expect_equal(setdiff(slot_roles(), metasalmon:::.ms_semantic_bundle_roles()), character(0))
})


# ---------------------------------------------------------------------------
# SURFACE 3 — the role-hint vocabulary
# ---------------------------------------------------------------------------

test_that("SURFACE 3: the role-hint layers emit every role they can flag", {
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


# ---------------------------------------------------------------------------
# SURFACE 4 — the retrieval filters
# ---------------------------------------------------------------------------

test_that("SURFACE 4: the gcdfo role filter has a case for every role", {
  # Without a case the role falls through to "keep everything", so a query
  # like "mean" matches any variable whose definition merely contains the word
  # and only ranking keeps the real modifier on top.
  filter_body <- fn_source_text(metasalmon:::.gcdfo_filter_for_role)
  for (role in union(slot_roles(), hint_roles)) {
    expect_match(filter_body, paste0(role, " = "), fixed = TRUE)
  }
})

test_that("SURFACE 4: sources_for_role() serves every bundle role explicitly", {
  # A role that falls through to the generic default has no retrieval identity
  # of its own — the shape of failure that let `statistical_modifier` reach
  # ranking with no source preferences. Ported from metasalmonpy's guard,
  # which had this check where R did not.
  generic_default <- sources_for_role("")
  for (role in metasalmon:::.ms_semantic_bundle_roles()) {
    sources <- sources_for_role(role)
    expect_gt(length(sources), 0L)
    expect_false(
      identical(sources, generic_default),
      info = paste0("sources_for_role(\"", role, "\") fell through to the default")
    )
  }
})

test_that("SURFACE 4: every preference row names a role the retrieval layer can serve", {
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
      "can never apply. See AGENTS.md on the seven-surface role contract.\n",
      paste(findings, collapse = "\n")
    ))
  }
  succeed()
})


# ---------------------------------------------------------------------------
# SURFACE 5 — the deterministic validators
# ---------------------------------------------------------------------------

test_that("SURFACE 5: every evidence-gated role has a validator the dispatcher calls", {
  # This surface was never checked here before the 2026-08-24 consolidation —
  # AGENTS.md listed it among the "first six" this file covered, and it was
  # not among them. A gate the dispatcher stops calling removes the only
  # deterministic check standing between the model's word and an IRI written
  # into the dictionary, and nothing about that failure is visible: the review
  # still runs, the accept still lands, only unchecked.
  dispatcher <- fn_source_text(metasalmon:::.ms_semantic_apply_bundle_validators)

  for (role in names(role_evidence_validators)) {
    validator_name <- role_evidence_validators[[role]]
    validator <- get(validator_name, envir = asNamespace("metasalmon"))

    # The gate names the role it gates — otherwise it is dead code for it.
    expect_match(
      fn_source_text(validator),
      paste0("\"", role, "\""),
      fixed = TRUE,
      info = paste0(validator_name, " does not name the ", role, " role")
    )
    # And the dispatcher reaches it.
    expect_match(
      dispatcher,
      validator_name,
      fixed = TRUE,
      info = paste0(validator_name, " is never called by the bundle dispatcher")
    )
  }

  # The role-type veto is not role-specific: it applies to every accept, and it
  # is the mechanism that makes SURFACE 3 load-bearing.
  expect_match(dispatcher, ".ms_validate_semantic_role_type", fixed = TRUE)
})

test_that("SURFACE 5: each evidence gate raises its own finding code", {
  # Distinct codes are what let a reviewer tell which gate fired; collapsing
  # two onto one code loses that without failing anything.
  codes <- c(
    method = "SEM_METHOD_EVIDENCE_REQUIRED",
    statistical_modifier = "SEM_MODIFIER_EVIDENCE_REQUIRED",
    constraint = "SEM_CONSTRAINT_EVIDENCE_REQUIRED"
  )
  for (role in names(codes)) {
    validator <- get(role_evidence_validators[[role]], envir = asNamespace("metasalmon"))
    expect_match(fn_source_text(validator), codes[[role]], fixed = TRUE)
  }
  expect_match(
    fn_source_text(metasalmon:::.ms_validate_semantic_role_type),
    "SEM_ROLE_TYPE_MISMATCH",
    fixed = TRUE
  )
})


# ---------------------------------------------------------------------------
# SURFACE 6 — the ranking preferences (inst/extdata/ontology-preferences.csv)
# ---------------------------------------------------------------------------

test_that("SURFACE 6: every dictionary slot role has ontology ranking preferences", {
  prefs <- metasalmon:::.role_preferences()
  expect_gt(nrow(prefs), 0L)
  expect_equal(setdiff(slot_roles(), prefs$role), character(0))
})

test_that("SURFACE 6: method keeps ranking preferences for codes.csv code values", {
  # The dictionary slot is gone but the role is not: code-value targets still
  # search shared-vocabulary procedures, so removing these rows would be wrong.
  prefs <- metasalmon:::.role_preferences()
  method_prefs <- dplyr::filter(prefs, .data$role == "method")

  expect_gt(nrow(method_prefs), 0L)
})

test_that("SURFACE 6: statistical_modifier prefers the reviewed salmon vocabulary", {
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


# ---------------------------------------------------------------------------
# SURFACE 7 — the role boosts (role_boost in .ranking_profile_defaults())
# ---------------------------------------------------------------------------
#
# Consolidated here 2026-08-24, from tests/testthat/test-smn-outranks-gcdfo.R,
# which keeps the *margin* property (smn must outrank gcdfo) that is its own
# subject. Coverage of the surface lives here and only here.
#
# Design note, because it is a deliberate departure from the port's source.
# metasalmonpy hoisted its table to a module constant (term_search.ROLE_BOOST)
# because the Python table was an inlined dict literal inside the scorer, with
# nothing enumerable for a guard to assert against. R has no such problem:
# .ranking_profile_defaults() already returns the table as a named list, and it
# is the merge base for the `ranking_profile` override system. Hoisting it to a
# package constant would create a *second* copy of the authority — exactly the
# drift metasalmonpy then needed an extra test to rule out. So R reads it in
# place, and ports the *pin* rather than the hoist: the test below fixes that
# the table this file enumerates is the table the scorer actually merges.

test_that("SURFACE 7: every role that reaches ranking has a role_boost entry", {
  # THE SEVENTH SURFACE. A role scored with no `role_boost` entry falls back to
  # base weight alone — a 0.1-0.2 spread across sources, which is effectively
  # no source preference at all. `statistical_modifier` carried
  # ontology-preferences.csv rows from sdp-0.3.0 until 2026-08-17 with no boost
  # entry: the *same role* failing a *second* silent layer, and the reason
  # AGENTS.md says to assume an eighth surface exists.
  profile <- metasalmon:::.ranking_profile_defaults()
  prefs <- metasalmon:::.role_preferences()
  boosted <- names(profile$role_boost)

  # (a) Every bundle role reaches .score_and_rank_terms(), so every bundle role
  # needs a boost. This is the strictly wider half.
  missing_bundle <- setdiff(metasalmon:::.ms_semantic_bundle_roles(), boosted)
  expect_equal(
    missing_bundle, character(0),
    info = paste(
      "Bundle roles with no .ranking_profile_defaults() role_boost entry:",
      paste(missing_bundle, collapse = ", ")
    )
  )

  # (b) And every role the CSV ranks, which is the assertion moved out of
  # test-smn-outranks-gcdfo.R. Kept as its own check so a CSV row for a role
  # outside the bundle vocabulary still fails here.
  ranked_roles <- setdiff(unique(prefs$role), "wikidata")
  expect_gt(length(ranked_roles), 0L)
  missing_ranked <- setdiff(ranked_roles, boosted)
  expect_equal(
    missing_ranked, character(0),
    info = paste(
      "Roles in ontology-preferences.csv with no .ranking_profile_defaults()",
      "role_boost entry:", paste(missing_ranked, collapse = ", ")
    )
  )

  # Every boost entry is a named numeric vector of source weights; an unnamed
  # or empty one is present-but-inert, which the setdiff checks cannot see.
  for (role in boosted) {
    boosts <- profile$role_boost[[role]]
    expect_true(is.numeric(boosts), info = role)
    expect_gt(length(boosts), 0L)
    expect_true(all(nzchar(names(boosts))), info = role)
  }
})

test_that("SURFACE 7: the role_boost table this guard enumerates is the one ranking uses", {
  # The check above is worth nothing if the table it enumerates is not the
  # table the scorer reads. Ported from metasalmonpy's
  # test_the_role_boost_table_is_the_one_ranking_uses: there it rules out a
  # hoisted constant drifting from the scorer, here it rules out the scorer
  # acquiring its own defaults instead of merging these.
  scorer <- fn_source_text(metasalmon:::.score_and_rank_terms)
  expect_match(
    scorer,
    ".merge_ranking_profile(.ranking_profile_defaults(), ranking_profile)",
    fixed = TRUE
  )
  expect_match(scorer, "profile$role_boost", fixed = TRUE)
  expect_match(scorer, "profile$base_source_weight", fixed = TRUE)

  # A caller-supplied profile merges over the defaults rather than replacing
  # them, so an override that names one role cannot silently strip the rest.
  merged <- metasalmon:::.merge_ranking_profile(
    metasalmon:::.ranking_profile_defaults(),
    list(role_boost = list(variable = c(smn = 9)))
  )
  expect_true(all(
    metasalmon:::.ms_semantic_bundle_roles() %in% names(merged$role_boost)
  ))
  expect_equal(unname(merged$role_boost$variable[["smn"]]), 9)
})
