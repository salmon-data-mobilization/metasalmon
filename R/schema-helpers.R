.ms_schema_env <- new.env(parent = emptyenv())

.ms_sdp_profile_url <- function() {
  "https://dfo-pacific-science.github.io/smn-data-pkg/profiles/salmon-data-package/v0.2/profile.json"
}

.ms_sdp_public_schema_base <- function() {
  "https://dfo-pacific-science.github.io/smn-data-pkg/schema/frictionless/metadata"
}

.ms_sdp_public_rules_url <- function() {
  "https://dfo-pacific-science.github.io/smn-data-pkg/schema/sdp.rules.yaml"
}

.ms_sdp_metadata_schema_paths <- function() {
  c(
    dataset = "schema/frictionless/metadata/dataset.schema.json",
    tables = "schema/frictionless/metadata/tables.schema.json",
    column_dictionary = "schema/frictionless/metadata/column_dictionary.schema.json",
    codes = "schema/frictionless/metadata/codes.schema.json"
  )
}

.ms_sdp_profile_path <- function() {
  "profiles/salmon-data-package/v0.2/profile.json"
}

.ms_sdp_rules_path <- function() {
  "schema/sdp.rules.yaml"
}

.ms_default_sdp_schema_base_url <- function() {
  legacy_url <- getOption("metasalmon.sdp_schema_url", NULL)
  if (!is.null(legacy_url) && nzchar(legacy_url)) {
    return(sub("/schema/sdp[.]schema[.]yaml$", "", legacy_url))
  }

  getOption(
    "metasalmon.sdp_schema_base_url",
    "https://raw.githubusercontent.com/dfo-pacific-science/smn-data-pkg/main"
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
      .ms_schema_env$schema <- remote_result
      .ms_schema_env$cache_key <- cache_key
      return(remote_result)
    }
    if (identical(source, "remote")) {
      cli::cli_abort(
        c(
          "Unable to load remote SDP Frictionless schema bundle.",
          "x" = conditionMessage(remote_result)
        )
      )
    }
    if (!quiet && !isTRUE(.ms_schema_env$warned_remote_fallback)) {
      cli::cli_warn(
        c(
          "Unable to load remote SDP Frictionless schema bundle; using vendored schemas bundled with metasalmon.",
          "x" = conditionMessage(remote_result)
        )
      )
      .ms_schema_env$warned_remote_fallback <- TRUE
    }
  }

  schema <- .ms_load_vendored_sdp_schema()
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

  if (is.null(schema$profile) || !identical(schema$profile[["$id"]], .ms_sdp_profile_url())) {
    cli::cli_abort("Invalid SDP schema: profile $id does not match the SDP profile URL.")
  }
  if (is.null(schema$rules) || !identical(schema$rules$profile, .ms_sdp_profile_url())) {
    cli::cli_abort("Invalid SDP schema: rules profile does not match the SDP profile URL.")
  }

  schema$metadata_tables <- .ms_schema_tables_from_frictionless(schema$metadata_schemas)
  schema$version <- schema$rules$version
  schema
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

  purrr::keep(resources, function(resource) {
    include_codes || !identical(resource$name, "sdp_codes")
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
