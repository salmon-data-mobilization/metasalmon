# Pinned ontology releases (tern ECOSYSTEM M-12).
#
# smn and gcdfo publish each release as an immutable snapshot directory,
# `docs/releases/<version>/` in their repositories, which GitHub Pages serves
# and w3id routes from the version IRI `<ontology IRI>/<version>`. A pinned
# read reads that snapshot and nothing else: a local copy of the directory
# (`snapshot_dir`), or the release itself, downloaded into a cache directory
# and then read the same way. It never falls back to the latest ontology. A
# snapshot that carries `MANIFEST.sha256` (lines in `sha256sum` format) must
# list the file read with the digest of the bytes read; one that carries none
# is read unverified, and says so.

.ms_ontology_release_registry <- function() {
  list(
    smn = list(
      iri = "https://w3id.org/smn",
      stem = "smn",
      pages = "https://salmon-data-mobilization.github.io/salmon-domain-ontology/releases/"
    ),
    gcdfo = list(
      iri = "https://w3id.org/gcdfo/salmon",
      stem = "gcdfo",
      pages = "https://dfo-pacific-science.github.io/dfo-salmon-ontology/releases/"
    )
  )
}

# The representations a snapshot carries, by the media type that asks for each.
.ms_release_media_types <- function() {
  c(`text/turtle` = "ttl", `application/rdf+xml` = "owl", `application/ld+json` = "jsonld")
}

# A version as the w3id routes accept it: three dot-separated numbers.
.ms_check_release_version <- function(version, ontology) {
  ok <- is.character(version) && length(version) == 1L && !is.na(version) &&
    grepl("^[0-9]+\\.[0-9]+\\.[0-9]+$", version)
  if (!ok) {
    shown <- paste(format(version), collapse = " ")
    cli::cli_abort(c(
      "A release is named by its version, three numbers such as {.val 0.0.3}.",
      "x" = "The {ontology} release was given {.val {shown}}."
    ), class = "metasalmon_ontology_release_error")
  }
  invisible(version)
}

# The ontology that `url` names, for `fetch_salmon_ontology()`'s pinned read.
.ms_release_ontology_for_url <- function(url) {
  registry <- .ms_ontology_release_registry()
  bare <- sub("/+$", "", as.character(url %||% ""))
  for (ontology in names(registry)) {
    if (identical(bare, registry[[ontology]]$iri)) {
      return(ontology)
    }
  }
  cli::cli_abort(c(
    "A pinned read needs {.arg url} to name smn or gcdfo.",
    "i" = "Use {.url https://w3id.org/smn/} or {.url https://w3id.org/gcdfo/salmon}."
  ), class = "metasalmon_ontology_release_error")
}

# The release files `accept` asks for, most preferred first, named by the media
# type that asks for each. A higher `q` comes first and a tie keeps the order
# written; a type a snapshot does not carry is skipped.
.ms_release_files_for_accept <- function(accept, stem) {
  parts <- trimws(strsplit(as.character(accept %||% ""), ",", fixed = TRUE)[[1]])
  parts <- parts[nzchar(parts)]
  types <- tolower(trimws(sub(";.*$", "", parts)))
  q <- vapply(parts, function(part) {
    hit <- regmatches(part, regexec(";\\s*q\\s*=\\s*([0-9.]+)", part, perl = TRUE))[[1]]
    if (length(hit) == 2L) suppressWarnings(as.numeric(hit[[2]])) else 1
  }, numeric(1), USE.NAMES = FALSE)
  q[is.na(q)] <- 0
  media <- .ms_release_media_types()
  keep <- types %in% names(media) & q > 0
  types <- types[keep][order(-q[keep], seq_len(sum(keep)), method = "radix")]
  types <- unique(types)
  if (length(types) == 0L) {
    cli::cli_abort(c(
      "{.arg accept} names no representation a release snapshot carries.",
      "i" = "A snapshot carries {.val text/turtle}, {.val application/rdf+xml} and {.val application/ld+json}."
    ), class = "metasalmon_ontology_release_error")
  }
  stats::setNames(paste0(stem, ".", media[types]), types)
}

# `release` or `snapshot_dir` as `find_terms()` takes them: one entry per
# ontology, named by it. Returns a named character vector.
.ms_release_pin_map <- function(x, arg) {
  if (is.null(x)) {
    return(stats::setNames(character(), character()))
  }
  if (is.list(x)) {
    x <- unlist(x)
  }
  if (!is.character(x) || length(x) == 0L) {
    cli::cli_abort(
      "{.arg {arg}} must be a named character vector, such as {.code c(smn = \"0.0.3\")}.",
      class = "metasalmon_ontology_release_error"
    )
  }
  ontologies <- names(x)
  if (is.null(ontologies) || anyNA(ontologies) || !all(nzchar(trimws(ontologies)))) {
    cli::cli_abort(
      "Each entry of {.arg {arg}} must be named by its ontology, such as {.code c(smn = \"0.0.3\")}.",
      class = "metasalmon_ontology_release_error"
    )
  }
  ontologies <- tolower(trimws(ontologies))
  unknown <- setdiff(ontologies, names(.ms_ontology_release_registry()))
  if (length(unknown) > 0L) {
    cli::cli_abort(c(
      "{.arg {arg}} can name only smn and gcdfo.",
      .ms_cli_bullets(paste0("Not an ontology with release snapshots: ", unknown))
    ), class = "metasalmon_ontology_release_error")
  }
  if (anyDuplicated(ontologies)) {
    cli::cli_abort(
      "{.arg {arg}} names an ontology more than once.",
      class = "metasalmon_ontology_release_error"
    )
  }
  if (anyNA(x) || !all(nzchar(trimws(x)))) {
    cli::cli_abort(
      "Every entry of {.arg {arg}} must be a non-empty string.",
      class = "metasalmon_ontology_release_error"
    )
  }
  stats::setNames(trimws(as.character(x)), ontologies)
}

# The pins one `find_terms()` call asks for: a list, one element per ontology
# named in `release` or `snapshot_dir`, each with its `version` and its
# `snapshot_dir` (`NA` where not given).
.ms_find_terms_release_pins <- function(release, snapshot_dir) {
  versions <- .ms_release_pin_map(release, "release")
  dirs <- .ms_release_pin_map(snapshot_dir, "snapshot_dir")
  ontologies <- intersect(names(.ms_ontology_release_registry()), union(names(versions), names(dirs)))
  pins <- lapply(ontologies, function(ontology) {
    version <- if (ontology %in% names(versions)) versions[[ontology]] else NA_character_
    if (!is.na(version)) {
      .ms_check_release_version(version, ontology)
    }
    list(
      ontology = ontology,
      version = version,
      snapshot_dir = if (ontology %in% names(dirs)) dirs[[ontology]] else NA_character_
    )
  })
  stats::setNames(pins, ontologies)
}

# Reads `MANIFEST.sha256`: one `<64 hex digits> <space or *><path>` line per
# file, as `sha256sum` writes them. Returns the digests, lower-cased, named by
# path. A line in any other shape, or a path listed twice with two digests, is
# an error: a manifest that cannot be read cannot verify anything.
.ms_read_sha256_manifest <- function(path) {
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  lines <- sub("\r$", "", lines)
  lines <- lines[nzchar(trimws(lines))]
  hits <- regmatches(lines, regexec("^([0-9A-Fa-f]{64}) [ *](.+)$", lines, perl = TRUE))
  malformed <- lengths(hits) != 3L
  if (any(malformed)) {
    cli::cli_abort(c(
      "{.file MANIFEST.sha256} at {.path {path}} is not in {.code sha256sum} format.",
      .ms_cli_bullets(paste0("Unreadable line: ", utils::head(lines[malformed], 3L)))
    ), class = "metasalmon_ontology_release_error")
  }
  digests <- tolower(vapply(hits, `[[`, character(1), 2L))
  files <- sub("^\\./", "", vapply(hits, `[[`, character(1), 3L))
  conflicting <- unique(files[duplicated(files)])
  conflicting <- conflicting[vapply(conflicting, function(f) {
    length(unique(digests[files == f])) > 1L
  }, logical(1))]
  if (length(conflicting) > 0L) {
    cli::cli_abort(c(
      "{.file MANIFEST.sha256} at {.path {path}} gives two digests for one file.",
      .ms_cli_bullets(conflicting)
    ), class = "metasalmon_ontology_release_error")
  }
  stats::setNames(digests, files)[!duplicated(files)]
}

# GETs the first of `urls` that answers 200 and writes its body to `dest`,
# replacing it whole. Returns "stored", or "absent" when every URL answered
# 404 or 410. Any other answer, or a request that fails, is an error, because
# it does not say whether the file exists.
.ms_release_download <- function(urls, accept, dest, timeout_seconds) {
  failures <- character()
  for (url in urls) {
    res <- try(
      httr::GET(
        url,
        httr::add_headers(Accept = accept),
        httr::timeout(timeout_seconds),
        httr::config(connecttimeout = timeout_seconds)
      ),
      silent = TRUE
    )
    if (inherits(res, "try-error")) {
      detail <- .ms_redact_secrets(conditionMessage(attr(res, "condition")))
      failures <- c(failures, paste0(url, ": ", detail))
      next
    }
    status <- as.integer(httr::status_code(res))
    if (identical(status, 200L)) {
      temp <- tempfile(tmpdir = dirname(dest), fileext = ".part")
      on.exit(unlink(temp, force = TRUE), add = TRUE)
      writeBin(httr::content(res, as = "raw"), temp)
      if (!file.rename(temp, dest)) {
        cli::cli_abort(
          "Failed to store the downloaded release file at {.path {dest}}.",
          class = "metasalmon_ontology_release_error"
        )
      }
      return("stored")
    }
    if (!status %in% c(404L, 410L)) {
      failures <- c(failures, paste0(url, ": HTTP ", status))
    }
  }
  if (length(failures) == 0L) {
    return("absent")
  }
  cli::cli_abort(c(
    "Could not establish whether the release serves {.file {basename(dest)}}.",
    .ms_cli_bullets(failures, "i")
  ), class = "metasalmon_ontology_release_error")
}

# Downloads the release into `dir`, once: the first of `files` it serves, then
# its manifest, or a marker recording that it serves none. A directory with
# neither holds an interrupted download and is fetched again. Returns the file
# name read.
.ms_materialize_release <- function(ontology, version, files, dir, timeout_seconds) {
  entry <- .ms_ontology_release_registry()[[ontology]]
  release_url <- paste0(entry$pages, version, "/")
  manifest <- file.path(dir, "MANIFEST.sha256")
  absent_marker <- paste0(manifest, ".absent")
  complete <- file.exists(manifest) || file.exists(absent_marker)
  if (!complete && dir.exists(dir)) {
    every_file <- paste0(entry$stem, ".", .ms_release_media_types())
    unlink(file.path(dir, c(every_file, "MANIFEST.sha256")), force = TRUE)
  }
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)

  chosen <- NULL
  for (i in seq_along(files)) {
    file <- files[[i]]
    if (file.exists(file.path(dir, file))) {
      chosen <- file
      break
    }
    outcome <- .ms_release_download(
      urls = c(paste0(entry$iri, "/", version), paste0(release_url, file)),
      accept = names(files)[[i]],
      dest = file.path(dir, file),
      timeout_seconds = timeout_seconds
    )
    if (identical(outcome, "stored")) {
      chosen <- file
      break
    }
  }
  if (is.null(chosen)) {
    cli::cli_abort(c(
      "The {ontology} {version} release serves none of the files asked for.",
      .ms_cli_bullets(paste0(release_url, files), "i")
    ), class = "metasalmon_ontology_release_error")
  }

  if (!complete) {
    outcome <- .ms_release_download(
      urls = paste0(release_url, "MANIFEST.sha256"),
      accept = "text/plain",
      dest = manifest,
      timeout_seconds = timeout_seconds
    )
    if (identical(outcome, "absent")) {
      writeBin(charToRaw("no MANIFEST.sha256 was served for this release\n"), absent_marker)
    }
  }
  chosen
}

# Locates the release file to read, reads it, and checks its bytes. `files` are
# the candidate file names, most preferred first, named by media type. Returns
# the path, the file name, the bytes read and their SHA-256, whether a manifest
# verified them, and where the snapshot came from. The bytes hashed are the
# bytes returned, so a caller that parses them parses what was checked.
.ms_resolve_release_file <- function(ontology, version, snapshot_dir, files,
                                     cache_root, timeout_seconds = 30) {
  entry <- .ms_ontology_release_registry()[[ontology]]
  owned <- is.na(snapshot_dir)
  if (!owned) {
    dir <- snapshot_dir
    if (!dir.exists(dir)) {
      cli::cli_abort(
        "The {ontology} snapshot directory {.path {dir}} does not exist.",
        class = "metasalmon_ontology_release_error"
      )
    }
    present <- files[file.exists(file.path(dir, files))]
    if (length(present) == 0L) {
      cli::cli_abort(c(
        "The {ontology} snapshot directory {.path {dir}} holds none of the files asked for.",
        .ms_cli_bullets(unname(files), "i")
      ), class = "metasalmon_ontology_release_error")
    }
    file <- present[[1]]
    source <- dir
  } else {
    if (is.na(version)) {
      cli::cli_abort(
        "A pinned {ontology} read needs a release version or a snapshot directory.",
        class = "metasalmon_ontology_release_error"
      )
    }
    dir <- file.path(cache_root, ontology, version)
    file <- .ms_materialize_release(ontology, version, files, dir, timeout_seconds)
    source <- paste0(entry$iri, "/", version)
  }

  path <- file.path(dir, file)
  bytes <- readBin(path, "raw", file.size(path))
  sha256 <- digest::digest(bytes, algo = "sha256", serialize = FALSE)
  manifest <- file.path(dir, "MANIFEST.sha256")
  verified <- FALSE
  if (file.exists(manifest)) {
    listed <- .ms_read_sha256_manifest(manifest)
    expected <- unname(listed[file])
    if (is.na(expected)) {
      cli::cli_abort(c(
        "The {ontology} snapshot's {.file MANIFEST.sha256} does not list {.file {file}}.",
        "i" = "Snapshot: {.path {dir}}"
      ), class = "metasalmon_ontology_release_error")
    }
    if (!identical(expected, sha256)) {
      # A copy this package downloaded is removed, so the next call fetches it
      # again; a snapshot the caller supplied is never touched.
      if (owned) {
        unlink(path, force = TRUE)
      }
      cli::cli_abort(c(
        "{.file {file}} does not match the {ontology} snapshot's {.file MANIFEST.sha256}.",
        "i" = "Expected SHA-256 {.val {expected}}; the file read has {.val {sha256}}.",
        "i" = "Snapshot: {.path {dir}}"
      ), class = "metasalmon_ontology_release_error")
    }
    verified <- TRUE
  }

  list(
    path = path,
    file = file,
    bytes = bytes,
    sha256 = sha256,
    manifest_verified = verified,
    source = source
  )
}

# Parsed release indexes, by ontology and the SHA-256 of the bytes they were
# parsed from, so a session reads one snapshot's bytes into an index once
# however many searches pin it.
.ms_release_index_cache <- new.env(parent = emptyenv())

# The term index of one pinned release, and the row that records which release
# it is. The snapshot is read through its RDF/XML. When it declares an
# `owl:versionIRI`, that must be the version pinned; with no version pinned,
# the declared one is recorded.
.ms_release_term_index <- function(pin, cache_root, timeout_seconds = 30) {
  ontology <- pin$ontology
  entry <- .ms_ontology_release_registry()[[ontology]]
  resolved <- .ms_resolve_release_file(
    ontology = ontology,
    version = pin$version,
    snapshot_dir = pin$snapshot_dir,
    files = stats::setNames(paste0(entry$stem, ".owl"), "application/rdf+xml"),
    cache_root = cache_root,
    timeout_seconds = timeout_seconds
  )

  key <- paste(ontology, resolved$sha256, sep = "@")
  cached <- if (exists(key, envir = .ms_release_index_cache, inherits = FALSE)) {
    get(key, envir = .ms_release_index_cache)
  } else {
    NULL
  }
  if (is.null(cached)) {
    doc <- tryCatch(
      xml2::read_xml(resolved$bytes),
      error = function(e) {
        cli::cli_abort(c(
          "The {ontology} snapshot file {.path {resolved$path}} is not readable RDF/XML.",
          .ms_cli_bullets(conditionMessage(e), "i")
        ), class = "metasalmon_ontology_release_error")
      }
    )
    ns <- .ms_rdfxml_ns()
    declared <- xml2::xml_attr(
      xml2::xml_find_first(doc, "/rdf:RDF/owl:Ontology/owl:versionIRI", ns = ns),
      "rdf:resource",
      ns = ns
    )
    index <- if (identical(ontology, "smn")) {
      .smn_release_index(doc)
    } else {
      .parse_salmon_rdfxml(doc, iri_pattern = "^https?://w3id\\.org/gcdfo/salmon(#|$)")
    }
    if (nrow(index) == 0L) {
      cli::cli_abort(
        "The {ontology} snapshot file {.path {resolved$path}} holds no {ontology} terms.",
        class = "metasalmon_ontology_release_error"
      )
    }
    cached <- list(index = index, version_iri = if (is.na(declared)) NA_character_ else declared)
    assign(key, cached, envir = .ms_release_index_cache)
  }

  version <- pin$version
  declared <- cached$version_iri
  if (!is.na(declared)) {
    declared_version <- .ms_release_version_from_iri(declared, entry$iri)
    if (!is.na(version) && !identical(declared_version, version)) {
      cli::cli_abort(c(
        "The {ontology} snapshot is not release {version}.",
        "x" = "Its {.code owl:versionIRI} is {.url {declared}}.",
        "i" = "Snapshot: {.path {resolved$source}}"
      ), class = "metasalmon_ontology_release_error")
    }
    if (is.na(version)) {
      version <- declared_version
    }
  }

  list(
    index = cached$index,
    record = tibble::tibble(
      ontology = ontology,
      version = version,
      version_iri = declared,
      file = resolved$file,
      sha256 = resolved$sha256,
      manifest_verified = resolved$manifest_verified,
      source = resolved$source
    )
  )
}

# The version a declared `owl:versionIRI` names: `<ontology IRI>/<X.Y.Z>`, with
# either scheme and an optional final slash. `NA` for any other IRI.
.ms_release_version_from_iri <- function(version_iri, ontology_iri) {
  bare <- sub("^https?://", "", sub("/+$", "", version_iri))
  prefix <- paste0(sub("^https?://", "", ontology_iri), "/")
  if (!startsWith(bare, prefix)) {
    return(NA_character_)
  }
  version <- substring(bare, nchar(prefix) + 1L)
  if (grepl("^[0-9]+\\.[0-9]+\\.[0-9]+$", version)) version else NA_character_
}

# The indexes `find_terms()` searches for the pinned ontologies it will query,
# the record of the releases they came from, and the identity of those
# releases for its result cache. An ontology pinned but not searched is not
# read. A remote snapshot is downloaded once per session, into the session's
# temporary directory, the way the latest indexes are.
.ms_find_terms_pinned_indexes <- function(pins, sources) {
  pins <- pins[names(pins) %in% sources]
  if (length(pins) == 0L) {
    return(list(indexes = list(), record = NULL, identity = ""))
  }
  resolved <- lapply(pins, .ms_release_term_index, cache_root = .ms_release_session_cache_root())
  record <- dplyr::bind_rows(lapply(unname(resolved), `[[`, "record"))
  list(
    indexes = lapply(resolved, `[[`, "index"),
    record = record,
    identity = paste0(record$ontology, "=", record$version, "@", record$sha256, collapse = ";")
  )
}

# `fetch_salmon_ontology()` with `release` or `snapshot_dir`: the path to the
# release file `accept` prefers, checked against the snapshot's manifest.
.ms_fetch_release_file <- function(url, accept, cache_dir, timeout_seconds,
                                   release, snapshot_dir) {
  ontology <- .ms_release_ontology_for_url(url)
  if (!is.null(release) && !is.null(snapshot_dir)) {
    cli::cli_abort(c(
      "Give {.arg release} or {.arg snapshot_dir}, not both.",
      "i" = "This call does not parse the file, so it cannot check that the directory holds that release."
    ), class = "metasalmon_ontology_release_error")
  }
  version <- NA_character_
  if (!is.null(release)) {
    .ms_check_release_version(release, ontology)
    version <- unname(release)
  }
  dir <- NA_character_
  if (!is.null(snapshot_dir)) {
    if (!is.character(snapshot_dir) || length(snapshot_dir) != 1L ||
        is.na(snapshot_dir) || !nzchar(trimws(snapshot_dir))) {
      cli::cli_abort(
        "{.arg snapshot_dir} must be one directory path.",
        class = "metasalmon_ontology_release_error"
      )
    }
    dir <- unname(snapshot_dir)
  }
  entry <- .ms_ontology_release_registry()[[ontology]]
  resolved <- .ms_resolve_release_file(
    ontology = ontology,
    version = version,
    snapshot_dir = dir,
    files = .ms_release_files_for_accept(accept, entry$stem),
    cache_root = file.path(cache_dir, "releases"),
    timeout_seconds = timeout_seconds
  )
  resolved$path
}

.ms_release_session_cache_root <- function() {
  file.path(tempdir(), "metasalmon-ontology-releases")
}
