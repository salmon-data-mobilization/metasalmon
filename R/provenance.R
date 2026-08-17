# One owner for the writer provenance an SDP manifest may declare -------------
#
# Every manifest metasalmon writes carries a `provenance$generated_by` naming
# the function that wrote it, plus that implementation's version. metasalmonpy
# writes the same artifacts and names *itself* -- honestly, rather than
# impersonating R -- so a validator that accepts only R's writer rejects a
# byte-identical Python-written manifest for no data reason. The ruling is that
# every validator accepts either implementation (parity-deviations register
# rows 11, 12 and 29).
#
# That ruling was applied one artifact at a time, and each application re-typed
# the same pair of strings: SSSOM got them in PR #43, measurement
# decompositions in PR #44, and the reproducibility manifest got the writer
# half without the read half and was left rejecting Python's manifest entirely
# (backlog #88). Three hand-maintained string lists is exactly how a ruling
# gets applied twice out of three times, so the accepted set lives here now and
# the next manifest type inherits dual acceptance instead of re-deriving it.
#
# The two writer names are deliberately not the same shape: R's is a `::`
# namespace call and Python's a `.` module attribute, each written the way its
# own users would call it. Both are derived from the bare function name, so a
# validator names its writer once.
#
# The mirror keeps the same table under the same rule -- metasalmonpy's
# `_ACCEPTED_PROVENANCE` dicts in `sssom.py`, `measurement_decompositions.py`
# and `reproducibility.py`. Adding a writer here means adding it there.

# Returns the provenance field that must carry a version for this manifest's
# declared writer, or `NA_character_` when `generated_by` is absent, malformed,
# or names neither mirror implementation. `writer` is the bare function name,
# e.g. `"write_sdp_sssom"`. A non-list `provenance` is not an error here; it is
# simply not an accepted provenance block.
.ms_manifest_provenance_version_field <- function(provenance, writer) {
  if (!is.list(provenance)) {
    return(NA_character_)
  }
  generated_by <- provenance$generated_by
  if (!is.character(generated_by) ||
      length(generated_by) != 1L ||
      is.na(generated_by)) {
    return(NA_character_)
  }
  accepted <- c("metasalmon_version", "metasalmonpy_version")
  names(accepted) <- c(
    paste0("metasalmon::", writer),
    paste0("metasalmonpy.", writer)
  )
  unname(accepted[generated_by])
}

# The version value a validator demands alongside an accepted `generated_by`:
# one non-blank string.
#
# Deliberately NOT called by `.ms_sssom_validate_manifest()`, which asks only
# that the field be present. That is not an oversight: metasalmonpy's
# `sssom.py` validator asks exactly `provenance.get(version_key) is None`, and
# the two readers of the same artifact must accept the same manifests. Its
# `measurement_decompositions.py` and `reproducibility.py` validators both
# demand a non-blank value, which is what this predicate mirrors.
# *Retires when:* metasalmonpy's SSSOM validator tightens to the non-blank
# shape its two sibling validators already use -- then both sides adopt this
# predicate in the same stream and the exception disappears.
.ms_manifest_provenance_version_ok <- function(value) {
  is.character(value) &&
    length(value) == 1L &&
    !is.na(value) &&
    nzchar(trimws(value))
}
