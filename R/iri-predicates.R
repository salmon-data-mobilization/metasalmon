# One owner for the "absolute IRI, no whitespace" shape ------------------------
#
# RFC 3986/3987 grammar: a scheme, a colon, then at least one non-whitespace
# character. This shape used to be written out at three call sites -- SDP
# metadata extensions (`R/sdp-extension-helpers.R`), EML supplementary-object
# PIDs (`R/eml-export.R`), and SSSOM references (`R/sssom.R`) -- and the copies
# disagreed. Two ran under R's default TRE engine, one under PCRE, and the two
# engines do not resolve `[[:space:]]` the same way. This file is the single
# definition so they cannot drift apart again (backlog #85).
#
# **The regex engine is part of the contract here, not an implementation
# detail.** TRE resolves `[[:space:]]` against Unicode; PCRE (`perl = TRUE`)
# resolves it as ASCII-only. Under PCRE the pattern therefore *accepts* an IRI
# containing U+3000 IDEOGRAPHIC SPACE or U+1680 OGHAM SPACE MARK -- characters
# RFC 3987 requires to be percent-encoded -- while TRE rejects them. Accepting
# them is the permissive-and-wrong answer, and it is invisible in a diff.
#
# So do not add `perl = TRUE` back here for speed or for habit. Beyond widening
# what the validator accepts, metasalmonpy mirrors these validators by
# enumerating R's TRE-resolved membership as `R_SPACE_CLASS`; switching engines
# silently invalidates that enumeration and the Python mirror with it. See
# `knowledge/parity-deviations.md` row 28, whose retirement condition names this
# exact change.
#
# Deliberately NOT a caller: `.ms_sdp_decomposition_is_absolute_iri()`
# (`R/measurement-decompositions.R`). It tests a different, narrower shape --
# hierarchical `scheme://` or `urn:` only -- and keeps an ASCII whitespace class
# on purpose, matched character-for-character on the Python side. Do not fold it
# in here without re-deciding both sides together.

# Vectorized over `value`; returns one logical per element, `NA` in, `NA` out.
.ms_absolute_iri_shape <- function(value) {
  grepl("^[A-Za-z][A-Za-z0-9+.-]*:[^[:space:]]+$", value)
}
