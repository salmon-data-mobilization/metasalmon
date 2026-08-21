# Static guard for the platform-time rule in R/platform-time.R: `%Y` is the one
# strftime field whose width the C standard leaves unspecified, glibc does not
# zero-pad it, and R hands `%Y` to the platform strftime unless it was built
# with `--with-internal-tzcode` (default macOS, not generally Linux). So a
# `format()` call rendering a user's date is a canonical key that differs
# between a developer's Mac and CI.
#
# The rule: a `format()`/`strftime()` call whose format string contains `%Y` or
# `%F` must go through the `.ms_iso_*()` helpers instead, unless it is listed
# below with the reason it is safe.
#
# This walks the installed namespace rather than grepping R/, for the reason
# `test-cli-safety-guard.R` gives: under `R CMD check` tests run against the
# installed package, where R/ holds metasalmon.rdb and no source files, so a
# grep-based test would skip exactly where enforcement matters. The cost is that
# failures name the function, not a line number.
#
# LIMITATIONS, stated plainly:
#   1. It is blind to the IMPLICIT form, and that is the miss that matters most.
#      `as.character(<Date>)` contains no "%Y" anywhere, so nothing here can see
#      it -- and it is not even the same defect: since R 4.3 it takes an
#      internal fast path that does not call `format()` at all and emits an
#      unpadded year on EVERY platform, macOS included. So the two point in
#      opposite directions, and a path that formats on one side and coerces on
#      the other mismatches on macOS while matching on Linux. Several of these
#      exist and are tracked as backlog #93; they were found by reading, not by
#      this guard. When you touch a Date, check the coercions, not just the
#      formats.
#   2. It only classifies by the CALLED function. `as.Date(x, format = "%Y")`
#      and `try_parse(x, "%Y")` are parsing and are correctly ignored, but a new
#      parser helper taking a format string is ignored for the same reason --
#      which is right, and is why nothing needs listing when one is added.
#   3. It cannot see a format string built at runtime (`paste0("%Y", sep)`).
#   4. srcrefs are dropped on install, so failures name the function, not a line.
#
# *Retires when:* R guarantees a zero-padded `%Y` on every platform it builds
# on. Nothing about this package can retire it; it is the platform's contract.

# Calls that FORMAT a value into text. A `%Y` reaching one of these is a
# platform-dependent byte unless it is on the allowlist.
formatting_fns <- c("format", "strftime", "format.Date", "format.POSIXct")

# Functions permitted to keep a raw `%Y`. An entry is a claim that you checked
# it; do not add one to silence a failure you have not read.
year_format_allowlist <- c(
  # `format(Sys.time(), "%Y%m%d%H%M%S")` -- a session-id stamp built from the
  # current time only. `Sys.time()` has had a four-digit year since long before
  # this package existed and will until the year 10000, so the unpadded branch
  # is unreachable. It is also not a canonical key: the id is a random-suffixed
  # session directory name, compared to nothing and hashed into nothing.
  # *Retires when:* this function takes a caller-supplied time, at which point
  # the year stops being guaranteed four digits and it must move to
  # `.ms_iso_stamp()`.
  ".ms_chat_new_session_id"
)

# Walk a body for `format()`/`strftime()` calls carrying a `%Y` or `%F` literal.
find_year_formats <- function(node, acc = character()) {
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

    if (head_name %in% formatting_fns) {
      args <- as.list(node)[-1]
      # `format(x, fmt)` and `format(x, format = fmt)` both count. Named `tz`,
      # `usetz` and friends do not carry a format string.
      arg_names <- names(args)
      for (i in seq_along(args)) {
        name <- if (is.null(arg_names)) "" else arg_names[[i]]
        if (!name %in% c("", "format")) {
          next
        }
        value <- args[[i]]
        if (is.character(value) && length(value) == 1L &&
            grepl("%Y|%F", value)) {
          acc <- c(acc, paste(deparse(node), collapse = " "))
        }
      }
    }
  }

  if (is.call(node) || is.pairlist(node)) {
    for (part in as.list(node)) {
      if (!missing(part) && (is.call(part) || is.pairlist(part))) {
        acc <- find_year_formats(part, acc)
      }
    }
  }
  acc
}

test_that("no function formats a year through the platform's %Y", {
  ns <- asNamespace("metasalmon")
  offenders <- list()

  for (name in ls(ns, all.names = TRUE)) {
    if (name %in% year_format_allowlist) {
      next
    }
    object <- get(name, envir = ns)
    if (!is.function(object)) {
      next
    }
    body <- body(object)
    if (is.null(body)) {
      next
    }
    found <- find_year_formats(body)
    if (length(found)) {
      offenders[[name]] <- found
    }
  }

  expect_identical(
    offenders,
    list(),
    info = paste0(
      "These functions format a year through the platform's `%Y`, which glibc ",
      "does not zero-pad. Route them through `.ms_iso_date()` / ",
      "`.ms_iso_stamp()` (R/platform-time.R), or add them to ",
      "`year_format_allowlist` with the reason the unpadded branch is ",
      "unreachable."
    )
  )
})

test_that("the allowlist has no stale entries", {
  # An allowlist entry that no longer describes a real `%Y` is a guard outliving
  # its cause: it reads as "checked and safe" while protecting nothing, and the
  # next person to add a `%Y` to that function gets a free pass.
  ns <- asNamespace("metasalmon")
  for (name in year_format_allowlist) {
    expect_true(
      exists(name, envir = ns, inherits = FALSE),
      info = paste0("allowlisted function no longer exists: ", name)
    )
    expect_gt(length(find_year_formats(body(get(name, envir = ns)))), 0L)
  }
})

test_that("the iso helpers pad the year and match format() otherwise", {
  iso_date <- metasalmon:::.ms_iso_date
  iso_year <- metasalmon:::.ms_iso_year
  iso_stamp <- metasalmon:::.ms_iso_stamp

  # The property the helpers exist for.
  expect_identical(iso_date(as.Date("0001-01-01")), "0001-01-01")
  expect_identical(iso_date(as.Date("0100-02-03")), "0100-02-03")
  expect_identical(iso_date(as.Date("0999-12-31")), "0999-12-31")
  expect_identical(iso_year(as.Date("0007-05-06")), "0007")
  expect_identical(
    iso_stamp(as.POSIXct("0001-01-01 00:00:00", tz = "UTC"),
              "-%m-%dT%H:%M:%SZ", tz = "UTC"),
    "0001-01-01T00:00:00Z"
  )

  # ...and the property that makes it a safe substitution: for every year the
  # platforms already agree on, the helpers must be byte-identical to the
  # `format()` calls they replace, or this "fix" is itself a bytes change.
  dates <- as.Date("1900-01-01") + seq(0L, 60000L, by = 7L)
  expect_identical(iso_date(dates), format(dates, "%Y-%m-%d"))

  instants <- as.POSIXct("1900-01-01", tz = "UTC") + seq(0, 4e9, by = 1e6)
  expect_identical(
    iso_stamp(instants, "-%m-%dT%H:%M:%OS6Z", tz = "UTC"),
    format(instants, "%Y-%m-%dT%H:%M:%OS6Z", tz = "UTC")
  )

  # `%OS6` TRUNCATES the fractional second where `sprintf("%.6f", ...)` rounds.
  # The helpers must leave `%OS` in strftime's hands; a hand-built timestamp
  # would silently change bytes on the platform that was already correct.
  fine <- as.POSIXct("2024-01-31 10:00:00.1234567", tz = "UTC")
  expect_identical(
    iso_stamp(fine, "-%m-%dT%H:%M:%OS6Z", tz = "UTC"),
    "2024-01-31T10:00:00.123456Z"
  )

  # `format()` honours an object's `tzone` only when `tz` is *missing* -- the
  # test is `missing(tz)`, not `tz == ""` -- so a helper that forwarded a `tz`
  # it was handed would shift a UTC instant into local time. That is a whole
  # timestamp wrong, not a padding digit, and it is why `tz` defaults to NULL.
  utc <- as.POSIXct("2001-03-04 05:06:07", tz = "UTC") + c(0, 86400, 1e7)
  expect_identical(iso_stamp(utc, "-%m-%d %H:%M:%S"), format(utc, "%Y-%m-%d %H:%M:%S"))

  # NA in, NA out -- not the string "NA", and not "NANA" from a paste0().
  expect_identical(iso_date(as.Date(NA)), NA_character_)
  expect_identical(iso_stamp(as.POSIXct(NA), "-%m-%d", tz = "UTC"), NA_character_)
  expect_identical(iso_year(as.Date(NA)), NA_character_)
})

test_that(".ms_iso_character() pads as.character()'s unpadded year", {
  # `as.character()` of a Date is NOT `format()`: since R 4.3 it takes an
  # internal fast path that drops the year padding on EVERY platform, macOS
  # included. This is a different defect from the `%Y` split -- not
  # platform-dependent, and pointing the opposite way, so a path that formats on
  # one side and coerces on the other mismatches on macOS and matches on Linux.
  iso_character <- metasalmon:::.ms_iso_character

  # The defect, pinned so a future R that fixes `as.character()` shows up here
  # as a change rather than as silence.
  expect_identical(as.character(as.Date("0001-01-01")), "1-01-01")
  expect_identical(iso_character(as.Date("0001-01-01")), "0001-01-01")
  expect_identical(iso_character(as.Date("0100-02-03")), "0100-02-03")
  expect_identical(iso_character(as.Date("0999-12-31")), "0999-12-31")

  # The shape `as.character()` chose is preserved: an all-midnight instant keeps
  # its date-only rendering, a fractional second survives, and the time part is
  # untouched. Re-deriving these by hand is what this helper exists to avoid.
  expect_identical(
    iso_character(as.POSIXct("0001-01-31 10:00:00", tz = "UTC")),
    "0001-01-31 10:00:00"
  )
  expect_identical(
    iso_character(as.POSIXct("2024-01-31 10:00:00.5", tz = "UTC")),
    "2024-01-31 10:00:00.5"
  )

  # Inert for four-digit years -- byte-identical to `as.character()`, which is
  # what makes it a safe drop-in at an existing call site.
  ordinary <- as.Date("1900-01-01") + seq(0L, 60000L, by = 11L)
  expect_identical(iso_character(ordinary), as.character(ordinary))
  instants <- as.POSIXct("1900-01-01 00:00:01", tz = "UTC") + seq(0, 4e9, by = 1e6)
  expect_identical(iso_character(instants), as.character(instants))

  # Non-temporal input must pass through untouched -- the helper sits on a
  # generic accessor in `edh-xml-export.R` that sees every metadata field, and a
  # value that merely *looks* like a short date is text, not a date.
  expect_identical(iso_character(c("abc", NA, "12")), c("abc", NA, "12"))
  expect_identical(iso_character(as.Date(NA)), NA_character_)
  expect_identical(iso_character(42L), "42")
})

test_that("inferred temporal coverage is padded before it becomes bytes", {
  # `infer_dataset_metadata_from_resources()` takes min()/max() over dates found
  # in the user's own columns and writes them into `metadata/dataset.csv`, which
  # feeds EML `calendarDate` and EDH `gml:beginPosition`. An unpadded year there
  # is invalid `xs:date`.
  resources <- list(
    obs = data.frame(
      event_date = as.Date(c("0999-01-01", "0999-06-30")),
      count = c(1L, 2L)
    )
  )
  meta <- metasalmon:::infer_dataset_metadata_from_resources(resources, "demo")
  expect_identical(meta$temporal_start[[1]], "0999-01-01")
  expect_identical(meta$temporal_end[[1]], "0999-06-30")
})
