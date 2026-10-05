# B-346, ruled2026-09-25: a vocabulary-only codes row describes an open
# vocabulary, not an enumeration. Apply skips that column's codes step;
# B-276 owns semantic-target filtering and is deliberately not tested here.

apply_vocab_dictionary <- function(df) {
  dict <- infer_dictionary(df, dataset_id = "test-1", table_id = "table-1")
  dict$column_label <- dict$column_name
  dict$role <- "attribute"
  dict$value_type <- "string"
  dict
}

apply_vocab_codes <- function(code_value = NA_character_) {
  tibble::tibble(
    dataset_id = "test-1", table_id = "table-1", column_name = "species",
    code_value = code_value, code_label = "Species vocabulary",
    vocabulary_iri = "https://example.org/vocabulary"
  )
}

test_that("vocabulary-only rows preserve values with either strict setting", {
  df <- tibble::tibble(species = c("Coho", "Chinook", "", NA_character_))
  dict <- apply_vocab_dictionary(df)
  dict$column_label <- "Species Name"
  for (missing_code in c(NA_character_, "", "  ")) {
    for (strict in c(TRUE, FALSE)) {
      expect_no_warning(result <- apply_salmon_dictionary(
        df, dict, codes = apply_vocab_codes(missing_code), strict = strict
      ))
      expect_identical(result[["Species Name"]], df$species)
      expect_false(is.factor(result[["Species Name"]]))
    }
  }
})

test_that("a vocabulary row takes precedence over enumerated rows of its column", {
  df <- tibble::tibble(species = c("Coho", "Chinook", "Pink"))
  dict <- apply_vocab_dictionary(df)
  codes <- dplyr::bind_rows(
    apply_vocab_codes(),
    tibble::tibble(
      dataset_id = "test-1", table_id = "table-1", column_name = "species",
      code_value = "Coho", code_label = "Coho label", vocabulary_iri = NA_character_
    )
  )
  expect_no_warning(result <- apply_salmon_dictionary(df, dict, codes))
  expect_identical(result$species, df$species)
  expect_false(is.factor(result$species))
})

test_that("an omitted optional code_value still describes a vocabulary", {
  df <- tibble::tibble(species = c("Coho", "Chinook"))
  codes <- apply_vocab_codes()[, c("dataset_id", "table_id", "column_name",
                                  "code_label", "vocabulary_iri")]
  expect_no_warning(result <- apply_salmon_dictionary(
    df, apply_vocab_dictionary(df), codes
  ))
  expect_identical(result$species, df$species)
})

test_that("a vocabulary IRI beside a real code value keeps the ordinary code list", {
  df <- tibble::tibble(species = c("Coho", "Chinook", NA_character_))
  dict <- apply_vocab_dictionary(df)
  # Nonempty code_value is the distinguishing control, even with a vocabulary.
  codes <- apply_vocab_codes("Coho")
  expect_warning(result <- apply_salmon_dictionary(df, dict, codes),
                 "not in its code list")
  expect_true(is.factor(result$species))
  expect_identical(as.character(result$species),
                   c("Species vocabulary", NA_character_, NA_character_))

  # The optional vocabulary column was absent in older caller-supplied lists.
  codes$vocabulary_iri <- NULL
  expect_warning(ordinary <- apply_salmon_dictionary(df, dict, codes),
                 "not in its code list")
  expect_identical(ordinary$species, result$species)
})

test_that("another table or column cannot exempt an ordinary code list", {
  df <- tibble::tibble(species = c("Coho", "Chinook"))
  ordinary <- apply_vocab_codes("Coho")
  foreign_table <- apply_vocab_codes()
  foreign_table$table_id <- "table-2"
  foreign_column <- apply_vocab_codes()
  foreign_column$column_name <- "stock"
  codes <- dplyr::bind_rows(ordinary, foreign_table, foreign_column)
  expect_warning(result <- apply_salmon_dictionary(
    df, apply_vocab_dictionary(df), codes
  ), "not in its code list")
  expect_true(is.factor(result$species))
  expect_identical(as.character(result$species), c("Species vocabulary", NA_character_))
})

test_that("vocabulary-backed columns retain independent declared type coercion", {
  df <- tibble::tibble(species = c("10", "20"))
  dict <- apply_vocab_dictionary(df)
  dict$value_type <- "integer"
  expect_no_warning(result <- apply_salmon_dictionary(df, dict, apply_vocab_codes()))
  expect_identical(result$species, c(10L, 20L))
})
