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
# detail.** In a UTF-8 locale TRE resolves `[[:space:]]` against Unicode;
# PCRE (`perl = TRUE`) resolves it as ASCII-only. Under the C locale TRE also
# resolves that class as ASCII-only. The explicit non-ASCII members below make
# the UTF-8-locale verdict stable in either locale: an IRI containing U+3000
# IDEOGRAPHIC SPACE or U+1680 OGHAM SPACE MARK must be rejected, because RFC
# 3987 requires those characters to be percent-encoded.
#
# So do not add `perl = TRUE` back here for speed or for habit: it changes how
# the POSIX part of the class resolves. Check the effective membership against
# metasalmonpy's `R_SPACE_CLASS` before changing this engine or the explicit
# members. See `knowledge/parity-deviations.md` row 28.
#
# Deliberately NOT a caller: `.ms_sdp_decomposition_is_absolute_iri()`
# (`R/measurement-decompositions.R`). It tests a different, narrower shape --
# hierarchical `scheme://` or `urn:` only -- and keeps an ASCII whitespace class
# on purpose, matched character-for-character on the Python side. Do not fold it
# in here without re-deciding both sides together.

# Vectorized over `value`; returns one logical per element, `NA` in, `NA` out.
.ms_absolute_iri_shape <- function(value) {
  # TRE's POSIX class alone admits these characters when LC_CTYPE=C. Spell out
  # its non-ASCII UTF-8-locale members, matching metasalmonpy's R_SPACE_CLASS.
  unicode_spaces <- paste0(
    "\u1680", "\u2000-\u2006", "\u2008-\u200a",
    "\u2028\u2029\u205f\u3000"
  )
  grepl(
    paste0("^[A-Za-z][A-Za-z0-9+.-]*:[^[:space:]", unicode_spaces, "]+$"),
    value
  )
}
