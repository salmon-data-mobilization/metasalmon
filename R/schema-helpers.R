.ms_schema_env <- new.env(parent = emptyenv())

# The SDP profile identity is DERIVED from the loaded schema bundle, never
# asserted against a constant here: metasalmon must be able to follow an
# upstream identifier change rather than fail on it. The constants below are
# only the fallback for a bundle that omits the values, and they must agree
# with the vendored files under inst/extdata.
.ms_sdp_profile_url <- function() {
  "https://salmon-data-mobilization.github.io/smn-data-pkg/profiles/salmon-data-package/v0.2/profile.json"
}

# Fallback only, for a bundle that predates the v0.2 extension resources.
# `.ms_sdp_metadata_resource_schema()` is what callers use.
.ms_sdp_public_schema_base <- function() {
  "https://salmon-data-mobilization.github.io/smn-data-pkg/schema/frictionless/metadata"
}

# The schema URL for one metadata resource, taken from the loaded bundle's
# `sdp:metadataResources` entry of that name. Deriving it means every URI in a
# written `datapackage.json` -- profile, rules, and now per-resource schemas --
# comes from one validated bundle, closing the last hardcoded contract value.
#
# The fallback is not dead code: a bundle published before the v0.2 extension
# resources existed has no `sdp_methods` entry, and composing the vendored base
# with the caller's filename is the same URL that shipped before this was
# derived.
#
# It is reserved for a genuinely absent entry. An entry that exists but declares
# an unusable schema is rejected by `.ms_validate_sdp_schema()` before any
# bundle reaches here, so falling back on it -- which would emit a descriptor
# mixing this bundle's profile identity with the vendored schema URLs -- is not
# reachable.
.ms_sdp_metadata_resource_schema <- function(name, fallback_file) {
  schema <- .ms_load_sdp_schema(quiet = TRUE)
  for (resource in schema$profile[["sdp:metadataResources"]] %||% list()) {
    if (identical(.ms_sdp_schema_identifier(resource$name), name)) {
      return(.ms_sdp_schema_uri(resource$schema))
    }
  }
  paste0(.ms_sdp_public_schema_base(), "/", fallback_file)
}

.ms_sdp_public_rules_url <- function() {
  "https://salmon-data-mobilization.github.io/smn-data-pkg/schema/sdp.rules.yaml"
}

# Accessors for the derived identity. Prefer `schema$profile_uri` /
# `schema$rules_uri`, which `.ms_validate_sdp_schema()` attaches after checking
# that the bundle agrees with itself.
.ms_sdp_profile_uri <- function(schema = .ms_load_sdp_schema(quiet = TRUE)) {
  schema$profile[["$id"]] %||% .ms_sdp_profile_url()
}

.ms_sdp_rules_uri <- function(schema = .ms_load_sdp_schema(quiet = TRUE)) {
  schema$profile[["sdp:rules"]] %||% .ms_sdp_public_rules_url()
}

.ms_sdp_metadata_schema_paths <- function() {
  c(
    dataset = "schema/frictionless/metadata/dataset.schema.json",
    tables = "schema/frictionless/metadata/tables.schema.json",
    column_dictionary = "schema/frictionless/metadata/column_dictionary.schema.json",
    codes = "schema/frictionless/metadata/codes.schema.json",
    methods = "schema/frictionless/metadata/methods.schema.json",
    observation_structures =
      "schema/frictionless/metadata/observation_structures.schema.json",
    observation_components =
      "schema/frictionless/metadata/observation_components.schema.json"
  )
}

.ms_sdp_profile_path <- function() {
  "profiles/salmon-data-package/v0.2/profile.json"
}

.ms_sdp_rules_path <- function() {
  "schema/sdp.rules.yaml"
}

# Deliberately NOT pinned to `source = "vendored"`. Pinning made
# `dataset.csv$spec_version` and `datapackage.json$sdp$specVersion` read
# different bundles, so one package could carry two disagreeing versions.
# `.ms_load_sdp_schema()` caches per session, so both now resolve identically.
.ms_sdp_profile_version <- function() {
  .ms_load_sdp_schema(quiet = TRUE)$version
}

.ms_default_sdp_schema_base_url <- function() {
  legacy_url <- getOption("metasalmon.sdp_schema_url", NULL)
  if (!is.null(legacy_url) && nzchar(legacy_url)) {
    return(sub("/schema/sdp[.]schema[.]yaml$", "", legacy_url))
  }

  getOption(
    "metasalmon.sdp_schema_base_url",
    "https://raw.githubusercontent.com/salmon-data-mobilization/smn-data-pkg/main"
  )
}

.ms_load_sdp_schema <- function(source = getOption("metasalmon.sdp_schema_source", "auto"),
                                refresh = FALSE,
                                quiet = FALSE) {
  source <- match.arg(source, c("auto", "remote", "vendored"))
  cache_key <- paste(source, .ms_default_sdp_schema_base_url(), sep = "|")

  if (!refresh && identical(.ms_schema_env$cache_key, cache_key) && !is.null(.ms_schema_env$schema)) {
    return(.ms_schema_env$schema)
  }

  if (source %in% c("auto", "remote")) {
    remote_result <- tryCatch(
      .ms_fetch_remote_sdp_schema(.ms_default_sdp_schema_base_url()),
      error = function(e) e
    )
    if (!inherits(remote_result, "error")) {
      remote_result$source <- "remote"
      .ms_schema_env$schema <- remote_result
      .ms_schema_env$cache_key <- cache_key
      return(remote_result)
    }
    if (identical(source, "remote")) {
      cli::cli_abort(
        c(
          "Unable to load remote SDP Frictionless schema bundle.",
          "x" = .ms_cli_escape(.ms_redact_secrets(conditionMessage(remote_result)))
        )
      )
    }
    if (!quiet && !isTRUE(.ms_schema_env$warned_remote_fallback)) {
      cli::cli_warn(
        c(
          "Unable to load remote SDP Frictionless schema bundle; using vendored schemas bundled with metasalmon.",
          "x" = .ms_cli_escape(.ms_redact_secrets(conditionMessage(remote_result)))
        )
      )
      .ms_schema_env$warned_remote_fallback <- TRUE
    }
  }

  # The vendored bundle is cached under the requested source's key on purpose:
  # once a session resolves an identity, every package it writes carries the
  # same profile URI, even if the network recovers mid-script.
  schema <- .ms_load_vendored_sdp_schema()
  schema$source <- "vendored"
  .ms_schema_env$schema <- schema
  .ms_schema_env$cache_key <- cache_key
  schema
}

.ms_fetch_remote_sdp_schema <- function(base_url, timeout = 2) {
  fetch_text <- function(path) {
    url <- paste0(sub("/+$", "", base_url), "/", path)
    request <- httr2::request(url)
    request <- httr2::req_timeout(request, timeout)
    request <- httr2::req_user_agent(request, "metasalmon")
    response <- httr2::req_perform(request)
    httr2::resp_body_string(response)
  }

  metadata_schemas <- purrr::map(
    .ms_sdp_metadata_schema_paths(),
    ~ jsonlite::fromJSON(fetch_text(.x), simplifyVector = FALSE)
  )
  profile <- jsonlite::fromJSON(fetch_text(.ms_sdp_profile_path()), simplifyVector = FALSE)
  rules <- yaml::yaml.load(fetch_text(.ms_sdp_rules_path()))

  .ms_validate_sdp_schema(list(
    metadata_schemas = metadata_schemas,
    profile = profile,
    rules = rules
  ))
}

.ms_load_vendored_sdp_schema <- function() {
  metadata_schemas <- purrr::map(.ms_sdp_metadata_schema_paths(), function(path) {
    full_path <- system.file("extdata", path, package = "metasalmon")
    if (!nzchar(full_path) || !file.exists(full_path)) {
      cli::cli_abort("Vendored SDP metadata schema is missing: {.path inst/extdata/{path}}.")
    }
    jsonlite::read_json(full_path, simplifyVector = FALSE)
  })

  profile_path <- system.file("extdata", .ms_sdp_profile_path(), package = "metasalmon")
  if (!nzchar(profile_path) || !file.exists(profile_path)) {
    cli::cli_abort("Vendored SDP profile is missing: {.path inst/extdata/{.ms_sdp_profile_path()}}.")
  }

  rules_path <- system.file("extdata", .ms_sdp_rules_path(), package = "metasalmon")
  if (!nzchar(rules_path) || !file.exists(rules_path)) {
    cli::cli_abort("Vendored SDP rules are missing: {.path inst/extdata/{.ms_sdp_rules_path()}}.")
  }

  .ms_validate_sdp_schema(list(
    metadata_schemas = metadata_schemas,
    profile = jsonlite::read_json(profile_path, simplifyVector = FALSE),
    rules = yaml::read_yaml(rules_path)
  ))
}

.ms_validate_sdp_schema <- function(schema) {
  if (!is.list(schema) || is.null(schema$metadata_schemas)) {
    cli::cli_abort("Invalid SDP schema: expected Frictionless metadata_schemas.")
  }

  required_tables <- names(.ms_sdp_metadata_schema_paths())
  missing_tables <- setdiff(required_tables, names(schema$metadata_schemas))
  if (length(missing_tables) > 0) {
    cli::cli_abort("Invalid SDP schema: missing table(s) {.val {missing_tables}}.")
  }

  for (table_name in required_tables) {
    table_schema <- schema$metadata_schemas[[table_name]]
    if (!identical(table_schema[["sdp:table"]], table_name)) {
      cli::cli_abort("Invalid SDP schema: {.val {table_name}} has mismatched sdp:table.")
    }
    fields <- table_schema$fields
    if (!is.list(fields) || length(fields) == 0) {
      cli::cli_abort("Invalid SDP schema: table {.val {table_name}} has no fields.")
    }
    field_names <- purrr::map_chr(fields, ~ .x$name %||% NA_character_)
    if (any(is.na(field_names) | field_names == "")) {
      cli::cli_abort("Invalid SDP schema: table {.val {table_name}} has unnamed fields.")
    }
    if (anyDuplicated(field_names)) {
      cli::cli_abort("Invalid SDP schema: table {.val {table_name}} has duplicate fields.")
    }
  }

  # Identity is derived from the bundle, so the checks below are all internal
  # self-consistency: the profile must agree with itself and with the rules
  # file. Asserting equality against a constant here is what made an upstream
  # identifier change unfollowable rather than merely noticeable.
  profile_uri <- .ms_sdp_schema_uri(if (is.null(schema$profile)) NULL else schema$profile[["$id"]])
  if (is.na(profile_uri)) {
    cli::cli_abort("Invalid SDP schema: profile $id is missing or is not a single absolute URI.")
  }
  # Compare the normalised forms: two identifiers padded differently denote the
  # same URI, and one padded consistently across all three would otherwise pass
  # every check here and be emitted with its spaces intact.
  if (!identical(.ms_sdp_schema_identifier(schema$profile$properties$profile$const), profile_uri)) {
    cli::cli_abort(
      "Invalid SDP schema: profile properties.profile.const does not match profile $id."
    )
  }
  if (is.null(schema$rules) ||
      !identical(.ms_sdp_schema_identifier(schema$rules$profile), profile_uri)) {
    cli::cli_abort("Invalid SDP schema: rules profile does not match profile $id.")
  }
  # Each version must exist before comparing them: `identical(NULL, NULL)` is
  # TRUE, so two absent versions would agree and the bundle would be accepted
  # with no usable `version` at all -- writers then omit or emit an invalid
  # `sdp.specVersion` instead of falling back to the vendored bundle.
  schema_version <- .ms_sdp_schema_identifier(schema$rules$version)
  profile_version <- .ms_sdp_schema_identifier(schema$profile[["sdp:version"]])
  if (is.na(schema_version) || is.na(profile_version)) {
    cli::cli_abort(
      "Invalid SDP schema: profile sdp:version and rules version must each be a single non-empty string."
    )
  }
  if (!identical(profile_version, schema_version)) {
    cli::cli_abort("Invalid SDP schema: profile sdp:version does not match rules version.")
  }

  schema$metadata_tables <- .ms_schema_tables_from_frictionless(schema$metadata_schemas)
  # Every declared metadata resource must carry a usable schema URI, because
  # `.ms_sdp_metadata_resource_schema()` writes it into `datapackage.json`.
  # Rejecting here rather than in the accessor is what makes the failure mode
  # right: a bad remote bundle fails to load and `auto` falls back to the
  # vendored bundle whole, instead of emitting a descriptor that mixes one
  # bundle's profile identity with another bundle's schema URLs.
  for (resource in schema$profile[["sdp:metadataResources"]] %||% list()) {
    resource_name <- .ms_sdp_schema_identifier(resource$name)
    if (is.na(resource_name)) {
      cli::cli_abort(
        "Invalid SDP schema: every profile sdp:metadataResources entry needs a name."
      )
    }
    if (is.na(.ms_sdp_schema_uri(resource$schema))) {
      cli::cli_abort(
        "Invalid SDP schema: metadata resource {.val {resource_name}} declares no usable schema URI."
      )
    }
  }

  # The normalised forms are what consumers read and what reaches
  # `datapackage.json`; the raw bundle values are never emitted.
  schema$version <- schema_version
  schema$profile_uri <- profile_uri
  # `sdp:rules` is written straight into `datapackage.json$sdp$rules`, so a
  # blank, whitespace-only, or non-scalar value has to reject the bundle rather
  # than be emitted. Absent is fine -- that falls back to the vendored constant.
  raw_rules_uri <- schema$profile[["sdp:rules"]]
  rules_uri <- .ms_sdp_schema_uri(raw_rules_uri)
  if (!is.null(raw_rules_uri) && is.na(rules_uri)) {
    cli::cli_abort(
      "Invalid SDP schema: profile sdp:rules must be a single absolute URI when present."
    )
  }
  schema$rules_uri <- if (is.na(rules_uri)) .ms_sdp_public_rules_url() else rules_uri
  schema
}

# A schema identifier: a single non-blank string, returned in its trimmed form,
# or `NA_character_` when it is anything else. Normalising at the boundary is
# what makes the checks above sound -- testing `trimws(x)` for emptiness while
# comparing and storing the raw `x` let a consistently padded
# `" https://example.org/profile "` pass every consistency check and reach the
# written `datapackage.json` with its spaces intact.
.ms_sdp_schema_identifier <- function(value) {
  if (!is.character(value) || length(value) != 1L || is.na(value) || !nzchar(trimws(value))) {
    return(NA_character_)
  }
  trimws(value)
}

# The identifiers that are URIs rather than versions. Cardinality and blankness
# are not enough for these: they are written verbatim into `datapackage.json`,
# where Frictionless expects a dereferenceable `profile` URL, so a non-blank
# scalar like `"not a URI"` was accepted and emitted instead of letting `auto`
# fall back to the vendored bundle.
#
# Scheme-and-authority with no internal whitespace, per RFC 3986's scheme
# grammar. Deliberately not restricted to http/https -- a `file://` bundle is a
# legitimate offline arrangement, and the requirement here is that the value is
# a usable absolute URI, not that it is fetchable over the network.
.ms_sdp_schema_uri <- function(value) {
  uri <- .ms_sdp_schema_identifier(value)
  if (is.na(uri) || grepl("[[:space:]]", uri)) {
    return(NA_character_)
  }
  # Split scheme / authority / remainder. Matching only `://` followed by
  # anything accepted `https:///profile.json`, `https://?query`, and
  # `https://#fragment`, all of which have no host and would be emitted as the
  # profile URI.
  parts <- regmatches(uri, regexec("^([A-Za-z][A-Za-z0-9+.-]*)://([^/?#]*)", uri))[[1]]
  if (length(parts) == 0L) {
    return(NA_character_)
  }
  # `file://` legitimately has an empty authority (`file:///path`); every other
  # scheme written with `://` needs a host. A non-empty authority is not the
  # same claim: `user@` and `:` are both non-empty and hostless.
  if (identical(tolower(parts[[2]]), "file")) {
    return(uri)
  }
  if (!.ms_uri_authority_has_host(parts[[3]])) {
    return(NA_character_)
  }
  uri
}

# Whether an RFC 3986 authority (`[userinfo@]host[:port]`) carries a host.
.ms_uri_authority_has_host <- function(authority) {
  host <- sub("^.*@", "", authority)
  host <- sub(":[0-9]*$", "", host)
  if (!nzchar(host)) {
    return(FALSE)
  }
  # An IP-literal is bracketed and is the one host form that may contain `:`.
  if (grepl("^\\[[0-9A-Fa-f:.]+\\]$", host)) {
    return(TRUE)
  }
  # reg-name: unreserved / pct-encoded / sub-delims. Anything else -- a stray
  # `:`, a bracket, a slash -- means this is not a host.
  if (!grepl("^[A-Za-z0-9._~%!$&'()*+,;=-]+$", host)) {
    return(FALSE)
  }
  # A `%` that is not the start of a well-formed escape is not pct-encoding.
  !grepl("%(?![0-9A-Fa-f]{2})", host, perl = TRUE)
}

.ms_schema_tables_from_frictionless <- function(metadata_schemas) {
  purrr::imap(metadata_schemas, function(table_schema, table_name) {
    list(
      path = table_schema[["sdp:path"]],
      requirement = table_schema[["sdp:requirement"]] %||% "required",
      condition = table_schema[["sdp:condition"]] %||% NULL,
      row_rule = table_schema[["sdp:rowRule"]] %||% NULL,
      description = table_schema$description %||% NA_character_,
      fields = purrr::map(table_schema$fields, .ms_field_from_frictionless)
    )
  })
}

.ms_field_from_frictionless <- function(field) {
  constraints <- field$constraints %||% list()
  requirement <- if (isTRUE(constraints$required)) {
    "required"
  } else {
    field[["sdp:requirement"]] %||% "optional"
  }

  out <- list(
    name = field$name,
    type = field$type,
    requirement = requirement,
    description = field$description %||% ""
  )
  if (!is.null(constraints$enum)) {
    out$allowed_values <- unlist(constraints$enum, use.names = FALSE)
  }
  if (!is.null(field[["sdp:condition"]])) {
    out$condition <- field[["sdp:condition"]]
  }
  examples <- field[["sdp:examples"]] %||% NULL
  if (is.null(examples) && !is.null(field$example)) {
    examples <- field$example
  }
  if (!is.null(examples)) {
    out$examples <- unlist(examples, use.names = FALSE)
  }
  out
}

.ms_sdp_schema_field_names <- function(table_name) {
  schema <- .ms_load_sdp_schema(quiet = TRUE)
  table <- schema$metadata_tables[[table_name]]
  if (is.null(table)) {
    cli::cli_abort("Unknown SDP metadata table {.val {table_name}}.")
  }
  purrr::map_chr(table$fields, "name")
}

.ms_sdp_metadata_resource_entries <- function(include_codes = FALSE) {
  schema <- .ms_load_sdp_schema(quiet = TRUE)
  resources <- schema$profile[["sdp:metadataResources"]] %||% list()
  core_names <- c(
    "sdp_dataset",
    "sdp_tables",
    "sdp_column_dictionary",
    "sdp_codes"
  )

  purrr::keep(resources, function(resource) {
    resource$name %in% core_names &&
      (include_codes || !identical(resource$name, "sdp_codes"))
  }) |>
    purrr::map(function(resource) {
      list(
        profile = resource$profile %||% "tabular-data-resource",
        name = resource$name,
        path = resource$path,
        title = resource$title %||% resource$name,
        description = resource$description %||% NA_character_,
        schema = resource$schema
      )
    })
}
