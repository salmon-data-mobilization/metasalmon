test_that("nuseds_enumeration_method_crosswalk has required structure and key rows", {
  cross <- nuseds_enumeration_method_crosswalk()

  expect_true(is.data.frame(cross))
  expect_true(all(c(
    "nuseds_value",
    "method_family",
    "ontology_term",
    "notes"
  ) %in% names(cross)))

  expect_gt(nrow(cross), 0)
  expect_true(any(cross$nuseds_value == "Bank Walk"))
  expect_true(any(cross$method_family == "unknown"))
  expect_true(any(cross$method_family == "FS"))
})

test_that("nuseds_estimate_method_crosswalk has required structure and key rows", {
  cross <- nuseds_estimate_method_crosswalk()

  expect_true(is.data.frame(cross))
  expect_true(all(c(
    "nuseds_value",
    "method_family",
    "guidance_interpretation",
    "ontology_term",
    "notes"
  ) %in% names(cross)))

  expect_gt(nrow(cross), 0)
  expect_true(any(cross$nuseds_value == "Sonar-ARIS"))
  expect_true(any(cross$method_family == "depends"))
  expect_true(any(cross$method_family == "M"))
})

test_that("nuseds_estimate_classification_crosswalk maps the Hyatt types and records the non-mappings", {
  # Backlog #101: ESTIMATE_CLASSIFICATION appeared nowhere in R/ although the
  # released gcdfo 0.0.9 ships Type1-Type6 as skos:Concepts under
  # gcdfo:EstimateType, labelled to match the NuSEDS strings. A wiring gap,
  # not an ontology gap.
  cross <- nuseds_estimate_classification_crosswalk()

  expect_true(is.data.frame(cross))
  expect_identical(
    names(cross),
    c("nuseds_value", "estimate_type", "ontology_term", "notes")
  )

  lookup <- stats::setNames(cross$ontology_term, cross$nuseds_value)
  expect_identical(unname(lookup[["TRUE ABUNDANCE (TYPE-1)"]]), "gcdfo:Type1")
  expect_identical(unname(lookup[["TRUE ABUNDANCE (TYPE-2)"]]), "gcdfo:Type2")
  expect_identical(unname(lookup[["RELATIVE ABUNDANCE (TYPE-3)"]]), "gcdfo:Type3")
  expect_identical(unname(lookup[["RELATIVE ABUNDANCE (TYPE-4)"]]), "gcdfo:Type4")
  expect_identical(unname(lookup[["RELATIVE ABUNDANCE (TYPE-5)"]]), "gcdfo:Type5")
  expect_identical(unname(lookup[["PRESENCE-ABSENCE (TYPE-6)"]]), "gcdfo:Type6")

  # NO SURVEY THIS YEAR is an absence-of-observation marker, not an estimate
  # type: mapping it to any Type concept would be wrong, and the crosswalk
  # records that disposition instead of forcing a term.
  expect_true(is.na(lookup[["NO SURVEY THIS YEAR"]]))
  expect_match(
    cross$notes[cross$nuseds_value == "NO SURVEY THIS YEAR"],
    "absence",
    ignore.case = TRUE
  )
  expect_true(is.na(lookup[["UNKNOWN"]]))

  # The multi-year relative classifications have no released concept of their
  # own; they link at scheme level, the same convention the estimate-method
  # crosswalk uses for Cumulative CPUE.
  expect_identical(
    unname(lookup[["RELATIVE: CONSTANT MULTI-YEAR METHODS"]]),
    "gcdfo:EstimateType"
  )
  expect_identical(
    unname(lookup[["RELATIVE: VARYING MULTI-YEAR METHODS"]]),
    "gcdfo:EstimateType"
  )
})
