# Generated helper declarations for R CMD check (non-user-facing).
if (getRversion() >= "2.15.1") {
  utils::globalVariables(c(
    "column_name",
    "dataset_id",
    "notes",
    "suggested_parent_iri",
    "term_definition",
    "term_label",
    "term_type"
  ))
}

# Install only concrete defaults that the caller has not already supplied.
.onLoad <- function(libname, pkgname) {
  .ms_initialize_configuration()
}
