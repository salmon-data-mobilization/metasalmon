# Static guard for the collation rule in AGENTS.md: any ordering whose result is
# hashed, written to file bytes, embedded in an identifier, returned by an
# exported function, or asserted by a validator must use explicit C collation.
#
# The allowlist below IS the machine-readable list of byte-producing functions.
# When you add a function that produces canonical bytes, a hash, or a PID, add
# it here.
#
# LIMITATIONS, stated plainly:
#   1. It only inspects the listed functions. A new byte-producing function with
#      an unqualified sort is invisible until it is listed. The name heuristic
#      below is a partial backstop, and it works only because this repo's naming
#      is disciplined.
#   2. It cannot tell a character key from a numeric one, so it will ask for
#      `method =` on integer sorts inside listed functions too. That is a
#      harmless no-op annotation (radix is already the integer default).
#   3. One level of indirection defeats it: a listed function that delegates
#      sorting to an unlisted helper is a miss.
#   4. srcrefs are dropped on install, so failures name the function, not a line.

collation_sensitive_fns <- c(
  # KNB identifiers and plan fingerprints
  ".ms_knb_resource_map_pid",
  ".ms_knb_sdp_artifact_paths",
  ".ms_knb_normalize_access",
  ".ms_knb_normalize_member_nodes",
  ".ms_knb_catalog_values",
  ".ms_knb_catalog_evidence",
  ".ms_knb_anonymous_catalog_evidence",
  # SSSOM canonical bytes and the manifest order contract
  ".ms_sssom_parse_metadata",
  ".ms_sssom_canonical_bytes",
  "write_sdp_sssom",
  ".ms_sssom_validate_manifest",
  # Exported tables whose row order is part of the return value
  "nuseds_enumeration_method_crosswalk",
  "nuseds_estimate_method_crosswalk",
  # SDP extension normalizers: their output IS the canonical row order
  # written to metadata/structure/observation_*.csv
  ".ms_sdp_observation_normalize_structures",
  ".ms_sdp_observation_normalize_components",
  "extract_sdp_observations",
  # Exported: rewrites tables.csv/column_dictionary.csv/dataset.csv and the
  # descriptor bytes, and sorts column names into its placement report.
  "migrate_sdp_methods",
  # Reproducibility manifest artifact inventory
  ".ms_sdp_reproducibility_artifact_paths",
  # Canonical row order for the measurement-decomposition CSV and its hash, and
  # for the EML supplementary object list. Neither name matches the heuristic
  # below, so without these entries a future bare arrange() in either path would
  # silently restore locale-dependent bytes.
  ".ms_sdp_decomposition_normalize_rows",
  ".ms_eml_supplementary_objects",
  # Exported: the returned `dwc_mappings` attribute carries this row order.
  "suggest_dwc_mappings",
  ".ms_dwc_rank_mappings",
  # Exported: `detect_semantic_term_gaps()` returns this row order, and the
  # candidate summary picks the `top_non_smn_*` evidence with character
  # tie-breakers. Neither name matches the heuristic below.
  "detect_semantic_term_gaps",
  ".ms_term_gap_candidate_summary",
  # Semantic ranking. The shortlist order these produce selects the top-1 IRI
  # that `seed_semantics = TRUE` writes into `column_dictionary.csv`, so a tie
  # broken by locale seeds the same input differently on macOS and in a
  # C-locale container. `find_terms()` alone was never enough: the guard does
  # not traverse callees, so its entry covered only its own cache-key sort while
  # the ranking itself lives in the helpers below.
  "find_terms",
  ".score_and_rank_terms",
  ".ms_retrieve_semantic_target_candidates",
  ".ms_merge_semantic_target_candidates",
  ".gcdfo_match_terms",
  ".apply_embedding_rerank",
  # Exported, and both carry a character ordering into their result:
  # `collision_roles` is pasted from a sorted vector, and the suggestion row
  # order is part of the returned tibble.
  "suggest_semantics",
  "apply_semantic_suggestions"
)

# Functions whose *name* claims they produce canonical bytes, a hash, or a PID.
# A convention enforcer, not a proof.
byte_producing_pattern <- "canonical_bytes|_pid$|fingerprint|_sha256|csv_bytes|json_bytes"

find_unqualified_ordering <- function(node, acc = list()) {
  if (is.call(node)) {
    head <- node[[1]]
    head_name <- if (is.name(head)) {
      as.character(head)
    } else if (is.call(head) && length(head) == 3L &&
               identical(as.character(head[[1]]), "::")) {
      as.character(head[[3]])
    } else {
      ""
    }

    args <- as.list(node)[-1]
    arg_names <- names(args)
    # Presence is not enough: `method = "shell"` and `.locale = "en"` are
    # locale-dependent, so the value has to be the C-collation one.
    argument_is <- function(name, expected) {
      if (is.null(arg_names) || !(name %in% arg_names)) {
        return(FALSE)
      }
      identical(args[[which(arg_names == name)[1]]], expected)
    }
    if (head_name %in% c("sort", "order") && !argument_is("method", "radix")) {
      acc[[length(acc) + 1L]] <- paste(deparse(node), collapse = " ")
    }
    if (head_name == "arrange" && !argument_is(".locale", "C")) {
      acc[[length(acc) + 1L]] <- paste(deparse(node), collapse = " ")
    }
  }

  if (is.call(node) || is.pairlist(node)) {
    for (part in as.list(node)) {
      if (!missing(part) && (is.call(part) || is.pairlist(part))) {
        acc <- find_unqualified_ordering(part, acc)
      }
    }
  }
  acc
}

report_unqualified <- function(fn_names) {
  ns <- asNamespace("metasalmon")
  findings <- character()

  for (nm in fn_names) {
    obj <- tryCatch(get(nm, envir = ns), error = function(e) NULL)
    if (!is.function(obj)) {
      next
    }
    hits <- find_unqualified_ordering(body(obj))
    for (hit in hits) {
      findings <- c(findings, paste0(nm, ": ", substr(hit, 1, 140)))
    }
  }
  findings
}

test_that("byte- and identifier-producing functions use explicit C collation", {
  findings <- report_unqualified(collation_sensitive_fns)

  if (length(findings) > 0) {
    fail(paste0(
      "Ordering that reaches bytes, a hash, an identifier, an exported return\n",
      "value, or a validated order must pass method = \"radix\" (sort/order) or\n",
      ".locale = \"C\" (dplyr::arrange). See AGENTS.md.\n",
      paste(findings, collapse = "\n")
    ))
  }
  succeed()
})

test_that("functions named as byte producers use explicit C collation", {
  ns <- asNamespace("metasalmon")
  named <- grep(byte_producing_pattern, ls(ns, all.names = TRUE), value = TRUE)
  findings <- report_unqualified(setdiff(named, collation_sensitive_fns))

  if (length(findings) > 0) {
    fail(paste0(
      "A function whose name claims it produces canonical bytes, a hash, or a\n",
      "PID contains an unqualified sort/order/arrange:\n",
      paste(findings, collapse = "\n")
    ))
  }
  succeed()
})

test_that("the collation guard detects an unqualified ordering", {
  # Without this, a guard that stopped matching would look like a pass.
  unqualified <- function(x) sort(x)
  qualified <- function(x) sort(x, method = "radix")
  unqualified_arrange <- function(df) dplyr::arrange(df, .data$a)
  qualified_arrange <- function(df) dplyr::arrange(df, .data$a, .locale = "C")

  # Presence of the argument is not enough; the value must be the C one.
  wrong_method <- function(x) sort(x, method = "shell")
  auto_method <- function(x) order(x, method = "auto")
  wrong_locale <- function(df) dplyr::arrange(df, .data$a, .locale = "en")

  expect_length(find_unqualified_ordering(body(unqualified)), 1L)
  expect_length(find_unqualified_ordering(body(qualified)), 0L)
  expect_length(find_unqualified_ordering(body(unqualified_arrange)), 1L)
  expect_length(find_unqualified_ordering(body(qualified_arrange)), 0L)
  expect_length(find_unqualified_ordering(body(wrong_method)), 1L)
  expect_length(find_unqualified_ordering(body(auto_method)), 1L)
  expect_length(find_unqualified_ordering(body(wrong_locale)), 1L)
})
