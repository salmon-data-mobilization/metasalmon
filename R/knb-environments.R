# KNB/DataONE environments --------------------------------------------------
#
# The closed registry of KNB deposit targets. Before this module the member
# node, coordinating node, resolver, and Solr endpoints were module-level
# constants pinned to production, so `publish_sdp_to_knb()` had no state that
# could vary and no way to rehearse a deposit.
#
# Two rules give this module its shape, and both are structural rather than
# advisory:
#
# 1. **An environment is switched whole or not at all.** Every derived URL is
#    built here from that environment's own `mn_base_url` / `cn_base_url`, so
#    there is no assignment anywhere in the package that could pair a test node
#    identifier with a production Solr endpoint. `.ms_knb_plan_config()` then
#    re-derives the whole record from the plan's fingerprinted `node_id` on
#    every read, so a hand-edited manifest cannot smuggle a mismatched pair
#    past the planner either.
# 2. **The registry is closed.** No custom endpoints, no partial matching, no
#    fallback between environments. `getOption("metasalmon.knb_adapter")` is
#    deliberately NOT covered by that rule -- it is the suite's adapter
#    injection point, and the closed-registry rule governs endpoints and
#    tokens, not the adapter seam. Removing that hook in the name of this rule
#    would take the dry-run network-isolation tests with it.
#
# Sources for the values below, all read from the node documents themselves on
# 2026-08-22 (read-only GETs, no credentials):
#   - `urn:node:mnTestKNB` ("KNB Test Node") answers 200 at
#     `https://dev.nceas.ucsb.edu/knb/d1/mn`, and is registered `state="up"` in
#     the DataONE staging coordinating node.
#   - `urn:node:cnStage` ("cn-stage") answers 200 at
#     `https://cn-stage.test.dataone.org/cn`.
#   - `urn:node:KNB` answers 200 at `https://knb.ecoinformatics.org/knb/d1/mn`.

# Every environment record carries exactly these fields. The guard test reads
# this vector as the authority, so a field added to one environment and
# forgotten in the other fails before it can reach a deposit.
.ms_knb_environment_fields <- function() {
  c(
    "knb_environment",
    "dataone_network",
    "node_id",
    "mn_base_url",
    "mn_endpoint",
    "object_endpoint",
    "cn_base_url",
    "resolver",
    "solr_endpoint",
    "token_option",
    "pid_scope",
    "default_eml_relpath",
    "default_manifest_relpath",
    "max_replicas",
    "durable"
  )
}

# The four network-identity values -- node id, DataONE network, member-node
# base URL, coordinating-node base URL -- are the only URL inputs. The member
# object endpoint derives from the first, the resolver and Solr endpoint from
# the second. That is what makes "switch the environment together" a property
# of the code rather than a rule someone has to remember.
.ms_knb_environment_record <- function(knb_environment,
                                       dataone_network,
                                       node_id,
                                       mn_base_url,
                                       cn_base_url,
                                       token_option,
                                       pid_scope,
                                       default_eml_relpath,
                                       default_manifest_relpath,
                                       max_replicas,
                                       durable) {
  member_node <- sub("/+$", "", mn_base_url)
  coordinating_node <- sub("/+$", "", cn_base_url)
  list(
    knb_environment = knb_environment,
    dataone_network = dataone_network,
    node_id = node_id,
    mn_base_url = member_node,
    mn_endpoint = paste0(member_node, "/v2"),
    object_endpoint = paste0(member_node, "/v2/object/"),
    cn_base_url = coordinating_node,
    resolver = paste0(coordinating_node, "/v2/resolve/"),
    solr_endpoint = paste0(coordinating_node, "/v2/query/solr/"),
    token_option = token_option,
    pid_scope = pid_scope,
    default_eml_relpath = default_eml_relpath,
    default_manifest_relpath = default_manifest_relpath,
    max_replicas = as.integer(max_replicas),
    durable = isTRUE(durable)
  )
}

.ms_knb_environment_registry <- function() {
  list(
    test = .ms_knb_environment_record(
      knb_environment = "test",
      dataone_network = "STAGING",
      node_id = "urn:node:mnTestKNB",
      mn_base_url = "https://dev.nceas.ucsb.edu/knb/d1/mn",
      cn_base_url = "https://cn-stage.test.dataone.org/cn",
      # A different credential from production, deliberately. 0.2.5 redacts
      # any qualified `*_token` name structurally, so this one is covered
      # without another patch.
      token_option = "dataone_test_token",
      # Folded into every identifier minted for this environment so a test PID
      # can never be mistaken for -- or collide with -- a production PID. The
      # SDP archive makes this concrete: its bytes are environment-independent,
      # so without a scope the same package would mint the same archive PID in
      # both environments.
      pid_scope = "knb-test",
      # A test EML document contains different resolver and object URLs, so it
      # has different bytes. Writing it to `metadata/eml.xml` would replace the
      # reviewed production record -- and those bytes are hashed into
      # `plan_sha256`, the deterministic archive, and the reproducibility
      # manifest, so the damage would propagate past the file.
      default_eml_relpath = "publication/test/eml.xml",
      default_manifest_relpath = "publication/test/knb-manifest.json",
      # A rehearsal never asks peer nodes to preserve copies.
      max_replicas = 0L,
      durable = FALSE
    ),
    production = .ms_knb_environment_record(
      knb_environment = "production",
      dataone_network = "PROD",
      node_id = "urn:node:KNB",
      mn_base_url = "https://knb.ecoinformatics.org/knb/d1/mn",
      cn_base_url = "https://cn.dataone.org/cn",
      token_option = "dataone_token",
      # Empty: `.ms_knb_pid_preimage()` drops an empty scope, so every
      # production identifier minted before this module existed is unchanged.
      pid_scope = "",
      default_eml_relpath = "metadata/eml.xml",
      default_manifest_relpath = "publication/knb-manifest.json",
      max_replicas = 3L,
      durable = TRUE
    )
  )
}

.ms_knb_validate_environment_config <- function(config, knb_environment) {
  required <- .ms_knb_environment_fields()
  missing <- setdiff(required, names(config))
  unexpected <- setdiff(names(config), required)
  if (length(missing) > 0L || length(unexpected) > 0L) {
    cli::cli_abort(c(
      "KNB environment {.val {knb_environment}} is not a complete registry record.",
      "x" = if (length(missing) > 0L) {
        "Missing field{?s}: {.field {missing}}."
      } else {
        NULL
      },
      "x" = if (length(unexpected) > 0L) {
        "Unexpected field{?s}: {.field {unexpected}}."
      } else {
        NULL
      }
    ))
  }

  # `pid_scope` is legitimately empty for production; every other character
  # field must be present, or an environment could be switched partway.
  character_fields <- setdiff(
    required,
    c("max_replicas", "durable", "pid_scope")
  )
  for (field in character_fields) {
    value <- config[[field]]
    if (length(value) != 1L ||
        !is.character(value) ||
        is.na(value) ||
        !nzchar(trimws(value))) {
      cli::cli_abort(
        "KNB environment {.val {knb_environment}} field {.field {field}} must be one non-empty string."
      )
    }
  }
  if (length(config$max_replicas) != 1L ||
      is.na(config$max_replicas) ||
      config$max_replicas < 0L) {
    cli::cli_abort(
      "KNB environment {.val {knb_environment}} field {.field max_replicas} must be one non-negative count."
    )
  }
  if (length(config$durable) != 1L || !is.logical(config$durable) ||
      is.na(config$durable)) {
    cli::cli_abort(
      "KNB environment {.val {knb_environment}} field {.field durable} must be one logical value."
    )
  }

  invisible(config)
}

.ms_knb_environment_ids <- function() {
  # Radix so the reported order of a closed vocabulary never depends on the
  # ambient locale.
  sort(names(.ms_knb_environment_registry()), method = "radix")
}

.ms_knb_config <- function(knb_environment) {
  supported <- .ms_knb_environment_ids()
  if (length(knb_environment) != 1L ||
      !is.character(knb_environment) ||
      is.na(knb_environment)) {
    cli::cli_abort(c(
      "{.arg knb_environment} must be exactly one of {.val {supported}}.",
      "i" = "There is no partial matching, no custom endpoint, and no fallback between environments."
    ))
  }
  registry <- .ms_knb_environment_registry()
  # Exact match only: partial matching an environment name is how a rehearsal
  # becomes a production deposit.
  if (!knb_environment %in% names(registry)) {
    cli::cli_abort(c(
      "Unknown KNB environment {.val {knb_environment}}.",
      "i" = "Supported environment{?s}: {.val {supported}}."
    ))
  }
  .ms_knb_validate_environment_config(
    registry[[knb_environment]],
    knb_environment
  )
}

# Reverse lookup from the DataONE node identifier. This is the authoritative
# direction: `node_id` is a fingerprinted field of every plan and manifest, so
# resolving the environment from it means the Solr endpoint, resolver, and
# member-node URL a plan is read with always belong to the node that plan was
# actually built for.
.ms_knb_config_for_node <- function(node_id) {
  registry <- .ms_knb_environment_registry()
  node_id <- as.character(node_id)
  matches <- vapply(
    registry,
    function(config) identical(config$node_id, node_id),
    logical(1)
  )
  if (sum(matches) != 1L) {
    registered <- unname(vapply(
      registry[.ms_knb_environment_ids()],
      function(config) config$node_id,
      character(1)
    ))
    cli::cli_abort(c(
      "{.val {node_id}} is not a registered KNB member node.",
      "i" = "Registered node{?s}: {.val {registered}}."
    ))
  }
  .ms_knb_config(names(registry)[[which(matches)]])
}

# Resolve the environment a plan or manifest belongs to, and refuse any record
# whose environment-derived values disagree with each other. A plan claiming
# the production network under a test node identifier is exactly the
# piecemeal switch this module exists to make impossible.
.ms_knb_plan_config <- function(plan) {
  config <- .ms_knb_config_for_node(plan$node_id)
  network <- as.character(plan$environment)
  if (length(network) != 1L ||
      !identical(network, config$dataone_network)) {
    cli::cli_abort(c(
      "The publication plan mixes KNB environments.",
      "x" = "Node {.val {as.character(plan$node_id)}} belongs to the {.val {config$dataone_network}} DataONE network, but the plan records {.val {network}}."
    ))
  }
  declared <- plan$knb_environment
  if (!is.null(declared) &&
      !identical(as.character(declared), config$knb_environment)) {
    cli::cli_abort(c(
      "The publication plan mixes KNB environments.",
      "x" = "Node {.val {as.character(plan$node_id)}} is the {.val {config$knb_environment}} environment, but the plan records {.val {as.character(declared)}}."
    ))
  }
  config
}

# The default policy, which is the shape of Brett's 2026-08-22 ruling: develop
# against the test node first, then post to production once the package looks
# good there. So a dry run -- the credential-free, network-free rehearsal --
# defaults to test, and anything live has to name its target. An unstated
# environment on a live call is an error, not a default.
.ms_knb_resolve_environment <- function(knb_environment, dry_run) {
  if (is.null(knb_environment)) {
    if (isTRUE(dry_run)) {
      return(.ms_knb_config("test"))
    }
    cli::cli_abort(c(
      "Live KNB publication requires an explicit {.arg knb_environment}.",
      "i" = "Pass {.code knb_environment = \"test\"} to deposit to the KNB Test Node, or {.code knb_environment = \"production\"} to deposit to KNB.",
      "i" = "Only a dry run defaults to {.val test}; a live target is never inferred."
    ))
  }
  .ms_knb_config(knb_environment)
}

# Fold the environment's scope into an identifier preimage. Production's scope
# is empty and is dropped, so this function is a no-op there by construction --
# which is the property that keeps every production PID minted before this
# module byte-identical.
.ms_knb_pid_preimage <- function(pid_scope, ...) {
  parts <- as.character(c(...))
  scope <- if (is.null(pid_scope)) "" else as.character(pid_scope)
  if (length(scope) != 1L || is.na(scope)) {
    scope <- ""
  }
  paste(c(if (nzchar(scope)) scope, parts), collapse = ":")
}

.ms_knb_require_token <- function(config) {
  token <- getOption(config$token_option)
  if (!.ms_eml_nonempty(token)) {
    cli::cli_abort(c(
      "A short-lived DataONE JWT for the {.val {config$knb_environment}} environment is required in the process-local {.code {config$token_option}} option.",
      "i" = "The {.val {config$knb_environment}} credential is a separate token from every other environment's; {.code {config$token_option}} is the only option read for {.val {config$node_id}}."
    ))
  }
  invisible(token)
}
