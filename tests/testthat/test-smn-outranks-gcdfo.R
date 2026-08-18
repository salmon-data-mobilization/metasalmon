# smn outranks gcdfo (Brett, 2026-08-17)
#
# `smn` is the shared, reviewed salmon namespace; `gcdfo` is the DFO fallback
# that ontology-preferences.csv ranks second behind it (and omits entirely for
# variable/property/constraint/statistical_modifier). Ranking must express that.
#
# What this guard is for: the source preference has to survive the ordinary
# per-candidate bonus stack, not merely exist. Through 0.3.0 the gap between
# smn and gcdfo in `.ranking_profile_defaults()` was 0.5 for variable, entity
# and method, because `role_boost` handed gcdfo 1.3 against smn's 1.7 -- close
# to parity, and contradicting the CSV that calls gcdfo a fallback. A gcdfo
# candidate collecting routine bonuses (0.2 label overlap + 0.4 cross-source
# label agreement = 0.6) therefore overtook smn. metasalmonpy held the same
# comparison at 0.7 and ranked smn first; Brett ruled Python correct.
#
# What would retire this guard: nothing short of dropping `gcdfo` as a
# retrieval source, or replacing additive scoring with a model that encodes
# source authority structurally rather than as a score margin. Until then the
# margin is load-bearing and a weight edit can silently erase it.

vocab <- metasalmon:::.iadopt_vocab()

# Roles whose retrieval layer actually queries both sources -- only these can
# produce an smn-vs-gcdfo comparison at all.
both_source_roles <- Filter(
  function(role) all(c("smn", "gcdfo") %in% sources_for_role(role)),
  metasalmon:::.ms_semantic_bundle_roles()
)

test_that("smn outranks gcdfo for equivalent candidates in every shared role", {
  expect_gt(length(both_source_roles), 0L)

  for (role in both_source_roles) {
    # Identical in every ranking-relevant respect except the source itself.
    df <- tibble::tibble(
      label = c("Spawner abundance", "Spawner abundance"),
      iri = c(
        "https://w3id.org/smn/SpawnerAbundance",
        "https://w3id.org/gcdfo/salmon#SpawnerAbundance"
      ),
      source = c("smn", "gcdfo"),
      ontology = c("smn", "gcdfo"),
      role = NA_character_,
      match_type = c("label_exact", "label_exact"),
      definition = c("Abundance of spawners.", "Abundance of spawners.")
    )

    ranked <- metasalmon:::.score_and_rank_terms(df, role, vocab, "spawner abundance")
    expect_identical(ranked$source[[1]], "smn", info = role)
  }
})

test_that("the smn-over-gcdfo margin survives the routine bonus stack", {
  # The measured differential against metasalmonpy (six tie-heavy candidates,
  # four input permutations). The gcdfo candidate matches the query where the
  # smn one does not, so it earns label overlap plus cross-source agreement;
  # the source preference must still carry smn. R returned gcdfo first here
  # before the fix, metasalmonpy returned smn.
  candidates <- tibble::tibble(
    iri = c("https://x/1", "https://x/2", "https://x/3", "https://y/1", "https://y/2", "https://z/1"),
    label = c("length", "length", "Length", "length", "weight", "length"),
    definition = rep("d", 6),
    source = c("ols", "ols", "nvs", "ols", "smn", "gcdfo"),
    ontology = c("envo", "obi", "P01", "envo", "smn", "gcdfo"),
    match_type = rep("exact", 6),
    role = NA_character_
  )

  # An empty vocab table still needs the columns the scorer filters on.
  empty_vocab <- tibble::tibble(
    role = character(), ontology = character(), host = character(),
    slug = character(), label_tokens = character()
  )

  permutations <- list(
    c(1, 2, 3, 4, 5, 6),
    c(6, 5, 4, 3, 2, 1),
    c(3, 1, 5, 2, 6, 4),
    c(2, 4, 6, 1, 3, 5)
  )

  orders <- unique(lapply(permutations, function(perm) {
    ranked <- metasalmon:::.score_and_rank_terms(
      candidates[perm, ], "variable", empty_vocab, "length"
    )
    ranked$iri
  }))

  # 0.2.1's determinism property: input order does not change output order.
  expect_length(orders, 1L)

  ranked <- metasalmon:::.score_and_rank_terms(
    candidates, "variable", empty_vocab, "length"
  )
  smn_rank <- which(ranked$source == "smn")
  gcdfo_rank <- which(ranked$source == "gcdfo")
  expect_lt(smn_rank, gcdfo_rank)
})

test_that("the ranking profile and ontology-preferences.csv agree that smn leads gcdfo", {
  profile <- metasalmon:::.ranking_profile_defaults()
  base <- profile$base_source_weight

  # Surface 1: the base source weight.
  expect_gt(unname(base[["smn"]]), unname(base[["gcdfo"]]))

  # Surface 2: the per-role boost. Every role the retrieval layer serves with
  # both sources needs a boost entry, and smn must lead in it -- a role missing
  # from role_boost ranks with no role-level source preference at all.
  for (role in both_source_roles) {
    boosts <- profile$role_boost[[role]]
    expect_false(is.null(boosts), info = role)
    expect_true(all(c("smn", "gcdfo") %in% names(boosts)), info = role)
    expect_gt(unname(boosts[["smn"]]), unname(boosts[["gcdfo"]]), label = role)
  }

  # Surface 3: the CSV priority. Where both are listed, smn ranks ahead
  # (lower priority number wins).
  prefs <- metasalmon:::.role_preferences()
  for (role in unique(prefs$role)) {
    role_prefs <- prefs[prefs$role == role, ]
    smn_priority <- role_prefs$priority[role_prefs$ontology == "smn"]
    gcdfo_priority <- role_prefs$priority[role_prefs$ontology == "gcdfo"]
    if (length(smn_priority) == 1L && length(gcdfo_priority) == 1L) {
      expect_lt(smn_priority, gcdfo_priority)
    }
  }
})

test_that("every role with ranking preferences has a role boost entry", {
  # The sixth surface of the role contract (AGENTS.md): a role that reaches
  # ranking with no `role_boost` row is scored on base weight alone, which is
  # a 0.1-0.2 spread across sources and effectively no preference at all.
  profile <- metasalmon:::.ranking_profile_defaults()
  prefs <- metasalmon:::.role_preferences()

  ranked_roles <- setdiff(unique(prefs$role), "wikidata")
  missing <- setdiff(ranked_roles, names(profile$role_boost))

  expect_equal(
    missing, character(0),
    info = paste(
      "Roles in ontology-preferences.csv with no .ranking_profile_defaults()",
      "role_boost entry:", paste(missing, collapse = ", ")
    )
  )
})
