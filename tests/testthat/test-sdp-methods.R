make_methods_test_sdp <- function(path, static_method = NA_character_) {
  data <- tibble::tibble(
    stock_id = c("fraser", "fraser"),
    brood_year = c(2019L, 2020L),
    abundance = c(100, 120)
  )
  dictionary <- tibble::tribble(
    ~dataset_id, ~table_id, ~column_name, ~column_label,
    ~column_description, ~column_role, ~value_type, ~unit_label, ~unit_iri,
    ~term_iri, ~term_type, ~required, ~property_iri, ~entity_iri,
    ~constraint_iri, ~method_iri,
    "methods-test", "stock_recruit", "stock_id", "Stock", "Stock identifier",
    "identifier", "string", NA_character_, NA_character_, NA_character_,
    NA_character_, TRUE, NA_character_, NA_character_, NA_character_, NA_character_,
    "methods-test", "stock_recruit", "brood_year", "Brood year", "Brood year",
    "temporal", "integer", NA_character_, NA_character_, NA_character_,
    NA_character_, TRUE, NA_character_, NA_character_, NA_character_, NA_character_,
    "methods-test", "stock_recruit", "abundance", "Abundance", "Estimated abundance",
    "measurement", "number", "individual", "http://qudt.org/vocab/unit/INDIV",
    "https://example.org/variables/abundance", "owl_class", TRUE,
    "https://w3id.org/smn/Abundance", "https://w3id.org/smn/Stock",
    NA_character_, static_method
  )

  write_salmon_datapackage(
    resources = list(stock_recruit = data),
    dataset_meta = tibble::tibble(
      dataset_id = "methods-test",
      title = "Methods test",
      description = "Fixture for SDP methods metadata"
    ),
    table_meta = tibble::tibble(
      dataset_id = "methods-test",
      table_id = "stock_recruit",
      file_name = "data/stock_recruit.csv",
      table_label = "Stock recruit",
      description = "Test table"
    ),
    dict = dictionary,
    path = path,
    overwrite = TRUE
  )
  invisible(path)
}

methods_test_rows <- function() {
  tibble::tibble(
    dataset_id = "methods-test",
    method_iri = c(
      "https://example.org/methods/expanded-count",
      "https://example.org/methods/mark-recapture"
    ),
    method_label = c("Expanded count", "Mark-recapture estimate"),
    method_description = c(
      "Expands an observed count.",
      "Estimates abundance from marked and recaptured fish."
    ),
    method_version = c(NA_character_, "2026"),
    protocol_iri = c(NA_character_, "https://example.org/protocols/mark-recapture"),
    citation = c("Example Program. 2026.", NA_character_)
  )
}

test_that("SDP methods round-trip with the exact upstream schema", {
  first <- withr::local_tempdir()
  second <- withr::local_tempdir()
  make_methods_test_sdp(first)
  make_methods_test_sdp(second)

  reversed_methods <- methods_test_rows()[
    2:1,
    rev(names(methods_test_rows())),
    drop = FALSE
  ]
  first_path <- write_sdp_methods(first, reversed_methods)
  second_path <- write_sdp_methods(second, methods_test_rows())

  expect_identical(
    readBin(first_path, "raw", n = file.info(first_path)$size),
    readBin(second_path, "raw", n = file.info(second_path)$size)
  )
  expect_identical(
    names(read_sdp_methods(first)),
    c(
      "dataset_id", "method_iri", "method_label", "method_description",
      "method_version", "protocol_iri", "citation"
    )
  )
  expect_identical(read_sdp_methods(first), read_sdp_methods(second))
  expect_true(isTRUE(validate_sdp_methods(first)))

  descriptor <- jsonlite::read_json(
    file.path(first, "datapackage.json"),
    simplifyVector = FALSE
  )
  paths <- purrr::map_chr(descriptor$resources, ~ .x$path)
  expect_true("metadata/methods.csv" %in% paths)
  expect_identical(descriptor$sdp$metadata$methods, "metadata/methods.csv")
})

test_that("SDP methods validate identifiers, package bindings, and static procedures", {
  root <- withr::local_tempdir()
  fixed <- "https://example.org/methods/mark-recapture"
  make_methods_test_sdp(root, static_method = fixed)
  expect_no_error(write_sdp_methods(root, methods_test_rows()))

  duplicate <- dplyr::bind_rows(methods_test_rows(), methods_test_rows()[1, ])
  expect_error(
    write_sdp_methods(root, duplicate, overwrite = TRUE),
    "unique within each dataset"
  )

  wrong_dataset <- methods_test_rows()
  wrong_dataset$dataset_id[[1]] <- "another-dataset"
  expect_error(
    write_sdp_methods(root, wrong_dataset, overwrite = TRUE),
    "must match.*dataset.csv"
  )

  missing_static <- methods_test_rows()[1, ]
  expect_error(
    write_sdp_methods(root, missing_static, overwrite = TRUE),
    "Static procedure references.*missing"
  )

  invalid_protocol <- methods_test_rows()
  invalid_protocol$protocol_iri[[1]] <- "not an IRI"
  expect_error(
    write_sdp_methods(root, invalid_protocol, overwrite = TRUE),
    "protocol_iri.*absolute IRI"
  )
})

test_that("legacy static procedure references remain valid without extensions", {
  root <- withr::local_tempdir()
  make_methods_test_sdp(
    root,
    static_method = "https://example.org/methods/mark-recapture"
  )

  expect_no_error(
    suppressMessages(validate_salmon_datapackage(root))
  )
})

test_that("SDP methods use explicit overwrite and reject metadata symlinks", {
  root <- withr::local_tempdir()
  make_methods_test_sdp(root)
  write_sdp_methods(root, methods_test_rows())
  expect_error(
    write_sdp_methods(root, methods_test_rows()),
    "already exists.*overwrite"
  )
  expect_no_error(
    write_sdp_methods(root, methods_test_rows(), overwrite = TRUE)
  )

  outside <- tempfile(fileext = ".csv")
  writeLines("outside", outside)
  methods_path <- file.path(root, "metadata", "methods.csv")
  unlink(methods_path)
  if (!file.symlink(outside, methods_path)) {
    skip("Filesystem does not permit symlink creation")
  }
  expect_error(
    write_sdp_methods(root, methods_test_rows(), overwrite = TRUE),
    "symlink"
  )
  expect_identical(readLines(outside), "outside")
})

test_that("SDP extension APIs reject only a symlinked package root", {
  target <- withr::local_tempdir()
  link_parent <- withr::local_tempdir()
  make_methods_test_sdp(target)
  linked_root <- file.path(link_parent, "linked-sdp")
  if (!file.symlink(target, linked_root)) {
    skip("Filesystem does not permit directory symlink creation")
  }

  expect_error(
    write_sdp_methods(linked_root, methods_test_rows()),
    "path.*symlink|unsafe"
  )
  expect_error(
    write_sdp_methods(paste0(linked_root, "/"), methods_test_rows()),
    "path.*symlink|unsafe"
  )
  expect_false(file.exists(file.path(target, "metadata", "methods.csv")))

  # On macOS the temporary directory is commonly spelled through the harmless
  # /var -> /private/var system alias. Only the supplied package-root entry,
  # not its ancestors, is part of this trust boundary.
  expect_no_error(write_sdp_methods(target, methods_test_rows()))
})

test_that("failed methods writes preserve CSV and descriptor bytes", {
  root <- withr::local_tempdir()
  make_methods_test_sdp(root)
  methods_path <- write_sdp_methods(root, methods_test_rows())
  descriptor_path <- file.path(root, "datapackage.json")
  before_methods <- readBin(
    methods_path,
    "raw",
    n = file.info(methods_path)$size
  )

  writeLines("{ malformed descriptor", descriptor_path)
  before_descriptor <- readBin(
    descriptor_path,
    "raw",
    n = file.info(descriptor_path)$size
  )
  changed <- methods_test_rows()
  changed$method_label[[1]] <- "Changed label"

  expect_error(
    write_sdp_methods(root, changed, overwrite = TRUE),
    "Could not parse.*datapackage.json"
  )
  expect_identical(
    readBin(methods_path, "raw", n = file.info(methods_path)$size),
    before_methods
  )
  expect_identical(
    readBin(descriptor_path, "raw", n = file.info(descriptor_path)$size),
    before_descriptor
  )

  linked <- withr::local_tempdir()
  make_methods_test_sdp(linked)
  linked_methods_path <- write_sdp_methods(linked, methods_test_rows())
  linked_descriptor <- file.path(linked, "datapackage.json")
  descriptor_target <- tempfile(fileext = ".json")
  expect_true(file.copy(linked_descriptor, descriptor_target))
  unlink(linked_descriptor)
  if (!file.symlink(descriptor_target, linked_descriptor)) {
    skip("Filesystem does not permit descriptor symlink creation")
  }
  before_linked_methods <- readBin(
    linked_methods_path,
    "raw",
    n = file.info(linked_methods_path)$size
  )
  before_target <- readBin(
    descriptor_target,
    "raw",
    n = file.info(descriptor_target)$size
  )

  expect_error(
    write_sdp_methods(linked, changed, overwrite = TRUE),
    "symlinked.*datapackage.json"
  )
  expect_identical(
    readBin(
      linked_methods_path,
      "raw",
      n = file.info(linked_methods_path)$size
    ),
    before_linked_methods
  )
  expect_identical(
    readBin(
      descriptor_target,
      "raw",
      n = file.info(descriptor_target)$size
    ),
    before_target
  )
  expect_true(nzchar(Sys.readlink(linked_descriptor)))
})

test_that("SDP methods reader rejects schema and descriptor drift", {
  root <- withr::local_tempdir()
  make_methods_test_sdp(root)
  write_sdp_methods(root, methods_test_rows())

  descriptor_path <- file.path(root, "datapackage.json")
  descriptor <- jsonlite::read_json(descriptor_path, simplifyVector = FALSE)
  descriptor$sdp$metadata$methods <- NULL
  jsonlite::write_json(
    descriptor,
    descriptor_path,
    auto_unbox = TRUE,
    pretty = TRUE,
    null = "null"
  )
  expect_error(validate_sdp_methods(root), "must declare.*methods.csv")

  write_sdp_methods(root, methods_test_rows(), overwrite = TRUE)
  descriptor <- jsonlite::read_json(descriptor_path, simplifyVector = FALSE)
  methods_index <- which(purrr::map_chr(
    descriptor$resources,
    ~ .x$path
  ) == "metadata/methods.csv")
  descriptor$resources[[methods_index]]$schema <- "https://example.org/wrong.json"
  jsonlite::write_json(
    descriptor,
    descriptor_path,
    auto_unbox = TRUE,
    pretty = TRUE,
    null = "null"
  )
  expect_error(validate_sdp_methods(root), "schema.*methods.schema.json")

  write_sdp_methods(root, methods_test_rows(), overwrite = TRUE)
  methods_path <- file.path(root, "metadata", "methods.csv")
  methods <- readr::read_csv(methods_path, show_col_types = FALSE)
  methods$unexpected <- "drift"
  readr::write_csv(methods, methods_path, na = "")
  expect_error(read_sdp_methods(root), "exact SDP schema")
})
