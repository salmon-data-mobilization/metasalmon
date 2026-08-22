# Platform-independent calendar text.
#
# `%Y` is the one strftime field whose width the C standard leaves unspecified,
# and glibc does not zero-pad it. R delegates `%Y` to the platform strftime
# unless it was built with `--with-internal-tzcode` -- the configure default on
# macOS, and not generally on Linux -- so the same call returns different bytes
# on the two platforms:
#
#   format(as.Date("0001-01-01"), "%Y-%m-%d")
#   #> "0001-01-01"  on macOS   (R's internal tzcode)
#   #> "1-01-01"     on Linux   (glibc strftime)
#
# Measured, not reasoned: macOS R 4.5.2 locally, and this package's Linux CI
# runner on 2026-08-21, which returned "1-01-01", "100-02-03" and "999-12-31"
# for years 1, 100 and 999. metasalmonpy hit the identical split in Python in
# 0.2.0 and was green on every macOS run while red on Linux only.
#
# This matters here for the same reason the C-collation contract matters: these
# renderings become canonical keys, and a canonical key that varies by machine
# breaks byte reproducibility. Worse, it is *self-consistent* on each platform
# -- both sides of a codes.csv comparison shift together -- so nothing errors,
# and the only visible symptom is that two machines write different packages
# from the same input.
#
# THE FIX IS DELIBERATELY NARROW: render the year here and let strftime format
# every other field. `%m`, `%d`, `%H`, `%M`, `%S` are fixed-width fields the
# standard *does* require zero-padded, so they are not at risk; and `%OS6`
# *truncates* the fractional second where `sprintf("%.6f", ...)` would round, so
# rebuilding a whole timestamp by hand would silently change bytes on the
# platform that was already correct. Verified byte-identical to the previous
# `format()` calls over 7000 randomly drawn dates and instants on macOS.
#
# *Retires when:* R guarantees a zero-padded `%Y` on every platform it builds
# on -- at which point these helpers can collapse back into plain `format()`
# calls -- or the package stops rendering user dates through strftime at all.

# `tz = NULL` means "whatever `format()` would have used", and it is the default
# here for a reason worth stating, because getting it wrong is silent and the
# error is a whole-timestamp shift rather than a padding difference.
#
# `format.POSIXct()` and `as.POSIXlt.POSIXct()` both pick up the object's own
# `tzone` attribute with `if (missing(tz) && !is.null(tzone <- attr(x,
# "tzone"))) tz <- tzone`. The test is `missing(tz)`, **not** `tz == ""` -- so
# passing `tz = ""` explicitly, which reads like "the default", suppresses the
# attribute lookup and formats in local time instead. A UTC-stamped instant then
# renders eight hours off. Forwarding a `tz` we were handed is therefore not
# equivalent to not passing one, and these helpers have to distinguish the two.
.ms_iso_lt <- function(x, tz = NULL) {
  if (is.null(tz)) as.POSIXlt(x) else as.POSIXlt(x, tz = tz)
}

# The four-or-more-digit year of `x`, taken from the calendar parts rather than
# from strftime. `tz` must match the `tz` of the `format()` call whose year this
# replaces, or the two halves can disagree across a midnight boundary.
.ms_iso_year <- function(x, tz = NULL) {
  lt <- .ms_iso_lt(x, tz)
  year <- lt$year + 1900L
  out <- sprintf("%04d", year)
  out[is.na(year)] <- NA_character_
  out
}

# `%Y-%m-%d` for a Date or an instant, with a zero-padded year everywhere.
# Built entirely from calendar parts because a date carries no fractional
# second, so there is no truncation behaviour to preserve.
.ms_iso_date <- function(x, tz = NULL) {
  lt <- .ms_iso_lt(x, tz)
  year <- lt$year + 1900L
  out <- sprintf("%04d-%02d-%02d", year, lt$mon + 1L, lt$mday)
  out[is.na(year)] <- NA_character_
  out
}

# `format(x, fmt, tz = tz)` with the year rendered by `.ms_iso_year()`.
#
# `fmt` is the remainder of the format string *after* the year, and must begin
# with the separator that followed `%Y` -- so `"%Y-%m-%dT%H:%M:%OS6Z"` is passed
# here as `"-%m-%dT%H:%M:%OS6Z"`. That splitting is intentional rather than a
# convenience API: it keeps `%OS`, timezone handling and every other field in
# strftime's hands, so the only byte this function is responsible for is the one
# byte strftime gets wrong.
.ms_iso_stamp <- function(x, fmt, tz = NULL) {
  rest <- if (is.null(tz)) format(x, fmt) else format(x, fmt, tz = tz)
  out <- paste0(.ms_iso_year(x, tz = tz), rest)
  out[is.na(rest)] <- NA_character_
  out
}

# THE SECOND DEFECT, and it is not the same one.
#
# `as.character()` of a Date or an instant is not `format()`. Since R 4.3 it
# takes an internal fast path that does not go through strftime at all, and that
# path emits an UNPADDED year on **every** platform:
#
#   as.character(as.Date("0001-01-01"))  #> "1-01-01"   -- macOS too
#   format(as.Date("0001-01-01"))        #> "0001-01-01"
#
# So this one is not a platform split, and CI cannot find it by disagreeing with
# a developer's machine. Worse, the two defects point in opposite directions: a
# path that formats on one side and coerces on the other mismatches on macOS and
# *matches* on Linux, which is the reverse of the `%Y` case and exactly the kind
# of thing that gets "fixed" on the wrong side.
#
# It reaches bytes: `readr::write_csv()` renders a Date column through
# `as.character()`, so a package written with a pre-1000 date contains
# `1-01-01`, and `readr::parse_date("1-01-01")` returns NA -- this package
# cannot read back what it wrote. Not every such site is fixed yet; see backlog
# #93 for the ones that need a decision rather than a substitution.
#
# Pad the rendered text rather than re-deriving it. `as.character()` drops the
# time from an all-midnight instant and keeps a fractional second when one is
# present, and reproducing those rules by hand would change bytes for values
# that are currently correct. A year of four or more digits cannot match the
# pattern, so this is inert for every date anyone actually has.
#
# *Retires when:* R's `as.character()` fast path zero-pads, or every call site
# that renders a Date into bytes has been converted to `.ms_iso_date()`.
.ms_iso_character <- function(x) {
  text <- as.character(x)
  short <- !is.na(text) & grepl("^[0-9]{1,3}-[0-9]{2}-[0-9]{2}", text)
  if (any(short)) {
    year <- as.integer(sub("^([0-9]{1,3})-.*$", "\\1", text[short]))
    rest <- sub("^[0-9]{1,3}", "", text[short])
    text[short] <- paste0(sprintf("%04d", year), rest)
  }
  text
}

# Render a data frame's Date columns as platform-independent ISO text, and
# leave every other column alone.
#
# THE NARROWNESS IS THE DESIGN, and it was measured rather than reasoned
# (macOS R 4.5.2, readr 2.x). `readr::write_csv()` and `as.character()` agree
# exactly on a Date -- both emit the unpadded `1-01-01` -- so padding the
# rendered text reproduces readr's own output for every year it already got
# right, and fixes only the years it did not.
#
# POSIXct is deliberately NOT touched, and this is the part that would be easy
# to get wrong by symmetry:
#
#   write_csv  POSIXct year 1  #> "0001-01-01T00:00:00Z"   <- ALREADY padded
#   write_csv  POSIXct 10:00.5 #> "2024-01-31T10:00:00Z"   <- fractional dropped
#   as.character(same)         #> "2024-01-31 10:00:00.5"  <- space, no Z, kept
#
# readr's instant path is correct already, and coercing it would change bytes
# twice over -- the separator and the zone marker, and whether a fractional
# second survives. A "fix" applied to both types would corrupt the one that was
# never broken.
#
# *Retires when:* R's `as.character.Date` fast path zero-pads, at which point
# this collapses to the identity.
.ms_iso_date_columns <- function(df) {
  is_date <- vapply(df, function(col) inherits(col, "Date"), logical(1))
  if (!any(is_date)) {
    return(df)
  }
  df[is_date] <- lapply(df[is_date], .ms_iso_character)
  df
}
