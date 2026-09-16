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
#   write_csv  POSIXct year 1  #> "0001-01-01T00:00:00Z"   <- padded on macOS ONLY
#   write_csv  POSIXct 10:00.5 #> "2024-01-31T10:00:00Z"   <- fractional dropped
#   as.character(same)         #> "2024-01-31 10:00:00.5"  <- space, no Z, kept
#
# Coercing an instant here would change bytes twice over -- the separator and
# the zone marker, and whether a fractional second survives -- so a "fix"
# applied to both types would corrupt the one this function was never about.
# THAT REASONING IS UNCHANGED. What changed is the sentence that used to follow
# it: "readr's instant path is correct already" was measured on macOS and is
# FALSE ON LINUX, where `write_csv()` writes `999-06-05T13:45:30Z` for a
# pre-1000 instant (R 4.3.3 / readr 2.2.0, 2026-09-14) -- the `%Y` split at the
# top of this file, reaching readr. So readr's instant path has the year defect
# too, on the platform CI runs on.
#
# IT IS STILL NOT THIS FUNCTION'S DEFECT TO FIX, and the first thing to know
# about it is that padding it here is the move backlog #93 item 1 ruled out.
# Recorded so the ruling rests on the measurement it actually has rather than on
# a stronger one: this function is narrow because coercing an instant changes
# three fields, not because readr had nothing wrong with instants.
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

# The bytes `readr::write_csv()` writes for an instant, obtained by asking it.
#
# WHY THIS EXISTS. One value, `dataset_meta$temporal_start`, lands in two files.
# `metadata/dataset.csv` is written by `readr::write_csv()`; `datapackage.json`
# rendered the same cell through `as.character()`, so one package carried two
# spellings of one instant, and a consumer reading either is entitled to treat
# it as the package's answer:
#
#   datapackage.json      "0999-06-05 13:45:30"    <- as.character(): space, no Z
#   metadata/dataset.csv  "0999-06-05T13:45:30Z"   <- write_csv(): ISO instant
#
# and a midnight instant additionally lost its time in the descriptor, because
# `as.character()` drops it. Backlog #115 / hub item B-115.
#
# THE BASELINE DECIDES, AND HERE IT IS `readr::write_csv()`. Brett ruled the
# spelling on 2026-09-14, once for both implementations so that no implementer
# picks one: a typed instant reaching the descriptor takes readr's ISO instant
# form, the `T` separator and the `Z` zone marker. The CSV's baseline is the one
# that cannot move -- #93 item 1 ruled that `.ms_iso_date_columns()` leaves
# `POSIXct` alone, and this change does not reopen it -- so the descriptor is
# the side that moves onto readr.
#
# THIS ASKS READR RATHER THAN REPRODUCING IT, and that is the whole point.
# Reproducing readr's instant text by hand means reproducing three behaviours,
# each silent when wrong: its conversion to UTC (a `tzone` of
# "America/Vancouver" shifts the clock, not merely the marker), its truncation
# of a fractional second, and its year. A hand renderer,
# `format(x, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")`, was measured equal to readr on
# every case tried -- years 1 and 999, a fractional second, midnight, three
# zones -- and it is still two renderings of one value, which is the defect the
# "one value, one rendering" contract names rather than a way of fixing it.
# Sharing readr makes the two files agree BY CONSTRUCTION instead of by an
# agreement nothing rechecks.
#
# MEASURED, NOT ASSUMED, and it corrects the comment above this one:
# `readr::write_csv()`'s instant year is NOT padded on every platform. Linux
# R 4.3.3 / readr 2.2.0 writes `999-06-05T13:45:30Z` where macOS R 4.5.2 /
# readr 2.2.0 wrote `0999-06-05T13:45:30Z`, which is the `%Y` split at the top
# of this file reaching readr's own output. Each is readr's answer on its
# platform and this helper emits whichever applies, so the descriptor agrees
# with the CSV on both. The residual unpadded year is readr's defect on the CSV
# side, is not reachable from here, and is reported rather than patched: padding
# only the descriptor would reopen #115 on Linux, which is worse than the byte
# it fixes.
#
# Parsing the cell back out is safe because a rendered instant is a fixed-width
# ASCII token containing no comma, quote, or newline, so readr's default
# `quote = "needed"` never quotes one and one row is always one line. That
# guarantee is why this takes `POSIXt` and nothing else.
#
# *Retires when:* readr exposes a documented scalar formatter this can call
# instead of formatting a one-column frame, or `metadata/dataset.csv` stops
# being written by readr -- at which point the descriptor follows the CSV's new
# writer, because the baseline is what this helper tracks.
.ms_readr_instant_character <- function(x) {
  out <- rep(NA_character_, length(x))
  present <- !is.na(x)
  if (!any(present)) {
    return(out)
  }
  text <- readr::format_csv(
    data.frame(value = x[present]),
    col_names = FALSE,
    na = ""
  )
  lines <- strsplit(text, "\n", fixed = TRUE)[[1]]
  if (length(lines) != sum(present)) {
    # One row per line is the contract that makes the parse above safe. Fail
    # loudly rather than emit a misaligned rendering, which would be silent.
    stop("internal: readr rendered an unexpected number of instant rows")
  }
  out[present] <- lines
  out
}

# THE THIRD DEFECT, and it is neither of the two above: the same value rendered
# TWICE, by two different renderers, inside one function.
#
# `.ms_sssom_canonical_bytes()` took its sort key through `as.character()` and
# its emitted bytes through `as.matrix()` inside `apply()`, which renders a
# non-character column with `format()`. Row *order* and row *content* therefore
# disagreed about the same value, and they disagreed differently on each
# platform. It is worse than the padding split it was found next to, because
# `format()` on a data frame column is **vector-wise**: it picks one notation
# for the whole column, so a `confidence` of 1.5 emitted as `1.5e+00` merely
# because another row held 100000, while sorting as `1.5`. A cell's bytes
# depended on its neighbours.
#
# THE RULE, which is Brett's 2026-08-24 ruling on Q12: **coerce once, at render
# time, per type.** One rendering per value, chosen by that value's type, and
# every consumer -- sort key, comparison key, emitted byte -- reads that one
# rendering. Two renderings of one value is the defect; which renderer wins is
# secondary to there being only one.
#
# The per-type dispatch is not decoration. Each branch below exists because the
# branch above it would be wrong for that type:
#
#   character  identity. `.ms_iso_character()` pads anything matching
#              `^[0-9]{1,3}-[0-9]{2}-[0-9]{2}`, so a user's `object_id` of
#              "12-34-56" would be silently rewritten. Text is already text;
#              re-rendering it is how a canonicalizer corrupts data.
#   Date       `.ms_iso_character()`. `as.character()` drops the year padding on
#              every platform (see above) and `format()` does not, so this is
#              the one type where the two renderers genuinely disagree.
#   POSIXt     `.ms_iso_character()` as well -- and this is the branch to read
#              twice, because backlog #93 item 1 ruled the exact opposite for
#              `.ms_iso_date_columns()`. THE TWO CONTEXTS HAVE DIFFERENT
#              BASELINES. There, the baseline is `readr::write_csv()`, whose
#              instant output is already correct and differs from
#              `as.character()` in separator, zone marker and whether a
#              fractional second survives -- so touching POSIXct corrupts a path
#              that was never broken. Here the baseline is `as.character()`
#              itself (it is what the sort key already used), the year is
#              unpadded in it, and `.ms_iso_character()` pads the rendered text
#              without re-deriving any other field. metasalmonpy pads both types
#              here for the same reason: its `_cell()` renders a `date` and a
#              `datetime` alike through `str()`, which is padded and pure
#              Python. Behavioural parity, measured.
#   everything `as.character()`. Element-wise, so a cell cannot be reshaped by
#   else       its neighbours the way `format()` reshapes one.
#
# *Retires when:* R's `as.character()` fast path zero-pads AND no caller renders
# a canonical value twice -- at which point this collapses to `as.character()`.
# The first half is the platform's contract; the second is enforced by reading,
# because no static guard can see two renderings of one value.
.ms_canonical_character <- function(x) {
  if (is.character(x)) {
    return(x)
  }
  if (inherits(x, "Date") || inherits(x, "POSIXt")) {
    return(.ms_iso_character(x))
  }
  as.character(x)
}
