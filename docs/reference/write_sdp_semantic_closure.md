# Write the reviewed semantic closure for a Salmon Data Package

Produces the two files
[`write_eml_from_sdp()`](https://salmon-data-mobilization.github.io/metasalmon/reference/write_eml_from_sdp.md)
and
[`publish_sdp_to_knb()`](https://salmon-data-mobilization.github.io/metasalmon/reference/publish_sdp_to_knb.md)
require and neither writes: `metadata/semantic_vocabulary.csv`, one
evidence row per canonical measurement IRI, and
`reviewed_semantic_selections.csv`, exactly one `accepted` row per
canonical review target. Both row sets are derived from the package on
disk, each vocabulary row's `reviewed_snapshot_sha256` is computed, and
the two file digests in `metadata/eml-mapping.yml` are rewritten when
that sidecar exists – so no digest is ever hand-written.

## Usage

``` r
write_sdp_semantic_closure(
  path,
  evidence = NULL,
  search_fn = find_terms,
  sources = c("smn", "gcdfo"),
  quiet = FALSE
)
```

## Arguments

- path:

  Path to an existing Salmon Data Package directory.

- evidence:

  Optional data frame of hand-supplied closure rows, one per IRI, with
  an `iri` column and any of `label`, `definition`, `source`,
  `ontology`, `resource_kind`, `type_iris`, `native_type`, `source_url`,
  `source_artifact_sha256`, `confidence`, `review_rationale`. Supplied
  non-empty values win over resolved ones field by field, so a row may
  correct one field and leave the rest to the search. An optional
  `target_sdp_field` column narrows a row to one slot, for an IRI
  selected in more than one. When a row supplies every required
  vocabulary field, no search runs for that IRI at all.

- search_fn:

  Function used to search terms. Defaults to
  [`find_terms()`](https://salmon-data-mobilization.github.io/metasalmon/reference/find_terms.md).
  A test hook; the signature is `function(query, role, sources)`.

- sources:

  Vocabulary sources to search. Defaults to `c("smn", "gcdfo")`, the two
  this package resolves deterministically.

- quiet:

  Suppress the progress and summary messages. Warnings about gaps and
  placeholder rationales are not suppressed.

## Value

Invisibly, a list with `vocabulary` and `review` (the two tibbles as
written), `gaps` (IRIs absent from every searched source, in term-gap
shape), `incomplete` (IRIs that were found but whose evidence is short
of a required field, which is not a gap), `measurement_iris` and
`review_targets` (the two canonical sets), `placeholders` (ledger rows
that got a `REVIEW REQUIRED:` rationale), and `files` (the paths
written).

## The two canonical sets are not one set

The vocabulary describes IRIs the EML measurement and method paths emit:
the six semantic fields of every `measurement` dictionary row, a
table-level `method_iri`, and any `sosa:usedProcedure` reached through a
code value. The ledger describes slots a reviewer decided: the same six
dictionary fields plus a table's `observation_unit_iri` and
`method_iri`. So an `observation_unit_iri` is a review target and not a
vocabulary term, and a code-resolved procedure is a vocabulary term and
not a review target. Neither set can be reasoned from the other, which
is why both are derived here.

## Unresolvable IRIs become gaps, not errors

Evidence is resolved by re-running the package's own deterministic
search
([`find_terms()`](https://salmon-data-mobilization.github.io/metasalmon/reference/find_terms.md))
for each IRI and keeping the hit whose IRI matches. An IRI every
searched source answered about and none of them has is reported as a row
of `gaps` – the shape
[`detect_semantic_term_gaps()`](https://salmon-data-mobilization.github.io/metasalmon/reference/detect_semantic_term_gaps.md)
returns, plus an `unresolved_iri` column – and both files are still
written without it. That is deliberate: an IRI absent from every
searched vocabulary is an ontology gap to file through
[`render_ontology_term_request()`](https://salmon-data-mobilization.github.io/metasalmon/reference/render_ontology_term_request.md)
and
[`submit_term_request_issues()`](https://salmon-data-mobilization.github.io/metasalmon/reference/submit_term_request_issues.md),
not a reason to leave the user with no files at all. The omission is not
silent: attempting EML export then names the same IRI as missing from
the vocabulary.

## What is not a gap

Two other outcomes leave a vocabulary row unwritten and neither is an
ontology gap, because in neither case is the term known to be absent.
Reporting them as gaps would ask
[`render_ontology_term_request()`](https://salmon-data-mobilization.github.io/metasalmon/reference/render_ontology_term_request.md)
to mint a term that exists.

- **A lookup that did not answer.** If a search throws, or
  [`find_terms()`](https://salmon-data-mobilization.github.io/metasalmon/reference/find_terms.md)
  returns empty while its `"diagnostics"` attribute records a source
  that failed, nothing has been learned about that IRI. The call
  **aborts** and writes nothing, naming each IRI and the sources that
  did not answer; the remedy is to re-run, so leaving a half-derived
  closure on disk would make the retry start from worse state.

- **A term found with incomplete evidence.** An exact IRI hit can still
  carry a blank required field – a class with no definition is the
  ordinary case. The row is reported in `incomplete`, naming the missing
  field and the slot, with a warning; the other rows are still written.
  Supply the field through `evidence`, or annotate the term upstream.

## Hand-supplied evidence

[`find_terms()`](https://salmon-data-mobilization.github.io/metasalmon/reference/find_terms.md)
fills `label`, `definition`, `source`, `ontology`, `resource_kind` and
`type_iris` for `smn` and `gcdfo`. It cannot fill `native_type` or
`source_url`, which describe the ontology artifact rather than the term
– both are derived here from the resolved source and can be overridden –
and it cannot search QUDT at all, so a QUDT row is entirely
hand-authored. `confidence` and `review_rationale` are human judgements:
they are read from `semantic_suggestions.csv` where
[`apply_sdp_semantics()`](https://salmon-data-mobilization.github.io/metasalmon/reference/apply_sdp_semantics.md)
recorded them, and otherwise written as a `REVIEW REQUIRED:` placeholder
with a warning naming every target that got one. A placeholder rationale
satisfies the ledger's non-empty check, so replace it before
publication; the warning and the marker are the only signals,
deliberately, because judging a rationale is not a validator's job.

## See also

[`write_eml_from_sdp()`](https://salmon-data-mobilization.github.io/metasalmon/reference/write_eml_from_sdp.md),
[`publish_sdp_to_knb()`](https://salmon-data-mobilization.github.io/metasalmon/reference/publish_sdp_to_knb.md),
[`detect_semantic_term_gaps()`](https://salmon-data-mobilization.github.io/metasalmon/reference/detect_semantic_term_gaps.md),
[`render_ontology_term_request()`](https://salmon-data-mobilization.github.io/metasalmon/reference/render_ontology_term_request.md),
[`submit_term_request_issues()`](https://salmon-data-mobilization.github.io/metasalmon/reference/submit_term_request_issues.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Everything the deterministic search can resolve, resolved.
closure <- write_sdp_semantic_closure("path/to/sdp")

# QUDT is not a searchable source, so a unit row is hand-authored.
closure <- write_sdp_semantic_closure(
  "path/to/sdp",
  evidence = tibble::tibble(
    iri = "https://qudt.org/vocab/unit/INDIV",
    label = "Individual",
    definition = "A counting unit denoting one organism.",
    source = "qudt",
    ontology = "qudt",
    resource_kind = "Unit",
    type_iris = "http://qudt.org/schema/qudt/Unit",
    native_type = "qudt:Unit",
    source_url = "https://qudt.org/vocab/unit/",
    confidence = "high",
    review_rationale = "Values are whole counts of organisms."
  )
)

# Anything the search could not resolve is a term request, not a failure.
if (nrow(closure$gaps) > 0) {
  requests <- render_ontology_term_request(closure$gaps, ask = FALSE)
}
} # }
```
