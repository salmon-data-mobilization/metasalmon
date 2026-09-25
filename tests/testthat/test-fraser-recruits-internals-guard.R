# Guard for the metasalmon internals the Fraser Recruits recipe calls through
# `:::` (hub item B-131, stream S13).
#
# The recipe, the Fraser sockeye stock-recruit case study, calls the eight
# internals in `fraser_recruits_internals` below as `metasalmon:::<name>()`,
# and it has already published with them. `:::` is not a supported interface,
# but until a name is exported or its retirement is recorded, renaming it or
# changing its signature breaks that consumer on the release that ships the
# change, and nothing else in this repository would say so: the tests that
# happen to call some of these names would be updated alongside a rename, which
# is what would hide it. This file states the obligation at the place a rename
# fails.
#
# The list's home is the table under "Requirement 1" in
# knowledge/sequences/s13-fraser-recruits-case-study.md. When that table gains
# or loses a name, change this file in the same change.
#
# WHAT IS PINNED, AND WHAT IS NOT
#   * That each name resolves the way `metasalmon:::name` resolves it, to a
#     function. `:::` is get(name, envir = asNamespace(pkg), inherits = FALSE),
#     and that is the lookup used here.
#   * That its formal argument names are the ones listed, in that order.
#   * One default: `require_final = TRUE` on `.ms_eml_validate_mapping()`. It
#     sets how strict the validation is, so flipping it would loosen a caller
#     that omits it without raising anything. The recipe's call sites are not
#     in this repository (the S-13 card records what each call is for, not its
#     arguments), so this pin rests on that reasoning rather than on an
#     observed call.
# Return values and bodies are not pinned. They change by design, as the
# profile version does when the vendored spec moves, and a guard on a name
# should not freeze what the name does.
#
# ITS REAL SCOPE, MEASURED 2026-09-25
# This pins the formals as they stood when it was added. For two of the eight
# those already differ from v0.1.8, the release the S-13 card recorded the
# recipe pinning when this was measured:
#   .ms_eml_canonical_measurement_iris  (dictionary)                was
#                                       (path, pkg)                 now
#   .ms_eml_read_vocabulary             (path, dictionary, mapping) was
#                                       (path, pkg, mapping)        now
# Both changed in f76ed4f (2026-08-15) and were first released in v0.3.0. For
# those two, this guard protects the shape the recipe migrates onto (S-13
# requirement 2), not the calls it makes at its pinned release.
#
# PER-NAME RETIREMENT
# Each name is its own guard and retires on its own: when that name is exported
# under a supported API ("exported" below), or when its retirement is recorded
# in the S-13 card's "Requirement 1" section ("recorded"). When one retires,
# delete its line here and its entry in `fraser_recruits_internals` together,
# and leave the rest.
#   .smn_module_urls                    exported, or recorded
#   .smn_cache_slug                     exported, or recorded
#   .ms_eml_canonical_measurement_iris  exported, or recorded (a)
#   .ms_eml_vocabulary_snapshot_sha256  exported, or recorded (a)
#   .ms_sdp_profile_version             exported, or recorded
#   .ms_eml_validate_mapping            exported, or recorded
#   .ms_eml_read_semantic_review        exported, or recorded
#   .ms_eml_read_vocabulary             exported, or recorded
# (a) B-116 records the 2026-09-12 ruling that these two stay unexported and
#     are reached through the exported write_sdp_semantic_closure(). While that
#     ruling stands the export half cannot happen, so these two retire when it
#     is recorded that the recipe no longer calls them by name.
#
# Not listed: `.ms_eml_canonical_review_targets()`. The recipe does not call
# it, and scripts/build-fraser-coho-knb-rehearsal.R, the one caller in this
# repository that reached it through `:::`, has gone through
# write_sdp_semantic_closure() instead since B-116.

# Formal argument names, in order, as `names(formals())` returns them.
fraser_recruits_internals <- list(
  .smn_module_urls                   = character(),
  .smn_cache_slug                    = "url",
  .ms_eml_canonical_measurement_iris = c("path", "pkg"),
  .ms_eml_vocabulary_snapshot_sha256 = "row",
  .ms_sdp_profile_version            = character(),
  .ms_eml_validate_mapping           = c("mapping", "pkg", "require_final"),
  .ms_eml_read_semantic_review       = c("path", "pkg", "mapping"),
  .ms_eml_read_vocabulary            = c("path", "pkg", "mapping")
)

# Defaults pinned, by function and then by argument. The header says why this
# is the only one.
fraser_recruits_defaults <- list(
  .ms_eml_validate_mapping = list(require_final = TRUE)
)

fraser_recruits_resolve <- function(name) {
  get0(name, envir = asNamespace("metasalmon"), inherits = FALSE)
}

fraser_recruits_signature <- function(args) {
  paste0("(", paste(args, collapse = ", "), ")")
}

test_that("every internal the Fraser Recruits recipe calls through ::: resolves to a function", {
  for (name in names(fraser_recruits_internals)) {
    expect(
      is.function(fraser_recruits_resolve(name)),
      sprintf(
        paste(
          "metasalmon:::%s no longer resolves to a function, and the Fraser",
          "Recruits recipe calls it by that name (S-13 requirement 1). Keep",
          "the name, or record its retirement and delete its pin as the",
          "header of this file says."
        ),
        name
      )
    )
  }
})

test_that("every internal the recipe calls keeps its formal arguments, in order", {
  for (name in names(fraser_recruits_internals)) {
    fn <- fraser_recruits_resolve(name)
    expected <- fraser_recruits_internals[[name]]
    actual <- if (is.function(fn)) as.character(names(formals(fn))) else NULL
    expect(
      identical(actual, expected),
      sprintf(
        paste(
          "metasalmon:::%s has formals %s where the pin says %s. The Fraser",
          "Recruits recipe calls it through :::, so a signature change breaks",
          "it (S-13 requirement 1); the header of this file says what retires",
          "the pin."
        ),
        name,
        if (is.null(actual)) "<none, not a function>" else fraser_recruits_signature(actual),
        fraser_recruits_signature(expected)
      )
    )
  }
})

test_that("the one default the recipe may rely on keeps its value", {
  for (name in names(fraser_recruits_defaults)) {
    fn <- fraser_recruits_resolve(name)
    for (arg in names(fraser_recruits_defaults[[name]])) {
      expected <- fraser_recruits_defaults[[name]][[arg]]
      ok <- is.function(fn) &&
        arg %in% names(formals(fn)) &&
        identical(formals(fn)[[arg]], expected)
      expect(
        ok,
        sprintf(
          paste(
            "metasalmon:::%s no longer defaults %s = %s. A recipe call that",
            "omits it would change behaviour without an error; the header of",
            "this file says why this default is pinned."
          ),
          name,
          arg,
          deparse(expected)
        )
      )
    }
  }
})
