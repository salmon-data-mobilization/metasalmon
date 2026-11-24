---
type: Artifact
title: "S13 requirement 3 — bounded semantic IRI dereference verification"
description: "Execution plan for B-130: enumerate the exact selected HTTP semantic IRIs in a Salmon Data Package, verify them with bounded retries, and persist a deterministic per-IRI report even when verification fails. Records the owed Python port without deciding ontology terms or publication authority."
status: draft
tags: [s13, semantic-iris, verification, parity, execplan]
psc:
  id: metasalmon:plan:2026-10-01-s13-semantic-iri-verification
  contexts: [metasalmon:context:hub-coordination]
---

# S13 requirement 3 — bounded semantic IRI dereference verification

## Purpose and boundary

An exported R function verifies the **exact HTTP semantic IRIs selected in a
Salmon Data Package (SDP)** and writes a reproducible CSV that a publication
recipe can bind by checksum. An IRI is the complete URL, including its fragment;
the verifier must not replace it with a label, local name, or namespace root.
This plan executes [B-130](../../queue/items/B-130.yaml), requirement 3 of the
[S13 card](../sequences/s13-fraser-recruits-case-study.md). It does not decide
whether any ontology term is semantically suitable, approve a deposit, or
settle S13 requirement 1's public API choices.

The reference consumer is the Fraser Recruits recipe in
`psc-data-transformations/transformations/fraser-sockeye-stock-recruit-detailed`.
Its `src/build.R` enumerates semantic slots in dictionary, table, code,
decomposition, vocabulary, method, and observation-component metadata; its
`src/extended-sdp.R` performs bounded GET retries. This package owns a
supported equivalent. The recipe's current implementation sorts with C
collation, uses at most three attempts, and inventories the report checksum.
It writes the report only after all checks succeed; B-130 needs the report
on failure as well, so a failed publication leaves reviewable evidence.

## Progress

- [x] 2026-10-01: Inspect B-130, S13, the consumer's implementation, and current SDP metadata surfaces.
- [x] 2026-10-01: Implement exact-IRI collection, transport classification, and a report persisted before aggregate failure.
- [x] 2026-10-01: Demonstrate bounded retries, complete failure reporting, deterministic bytes, descriptor fallback, SSSOM coverage, and symlink refusal with stubbed transport.
- [x] 2026-10-01: Finish local strict package check and review the final diff; focused tests, package suite, documentation build, queue and OKF checks passed.
- [x] 2026-10-01: Publish the R draft pull request and record the Python port as owed.

## Context and implementation

The package root contains the SDP descriptor and metadata CSVs. The primary
reader is `read_salmon_datapackage()` in `R/package-helpers.R`; semantic fields
also appear in `R/dictionary-helpers.R`, `R/measurement-decompositions.R`,
`R/observation-structures.R`, and the reviewed semantic ledger. The existing
`.ms_eml_canonical_measurement_iris()` is an EML closure for measurements, not
the complete package set, so it cannot stand in for collection here.

Add an exported `verify_sdp_semantic_iris(path, report_path = ...)` in a
focused `R/semantic-iri-verification.R` module. Walk selected semantic metadata
fields, including the `*_iri` slots in dictionary, tables, codes, method,
decomposition, and observation-component metadata, the accepted `iri` slots
in semantic vocabulary or reviewed selections, and the literal HTTP semantic
references in manifest-bound reviewed SSSOM mapping sets. SSSOM cells may
separate references with `|`; do not expand CURIEs into different identifiers.
Do not treat candidate
shortlists, raw data cells, or arbitrary URLs in descriptions as selected
semantics. Split semicolon-delimited multi-values, trim whitespace, keep only
HTTP(S) IRIs, preserve each exact string, deduplicate, and sort with
`sort(..., method = "radix")`. A package with no HTTP semantic IRI must fail
clearly rather than claim a successful verification.

Use GET with redirects and a finite timeout; preserve the final URL and HTTP
status. Retry only HTTP 408, 429, and 5xx, or classified transient transport
failures. Use the consumer's two-delay schedule of 0.1 and 0.25 seconds, hence
at most three attempts per IRI. A permanent HTTP failure is one attempt. Tests
inject request and sleep functions so they never reach the network or wait.
Treat a 2xx response with a nonempty final URL as success. A transport error
must yield a report row with a status and redacted error text, not disappear.

Write `reproducibility/provenance/semantic-iri-dereference.csv` by default.
Rows use C-sorted exact IRI order and record at least `iri`, `status`,
`final_url`, `error`, and `attempts`; there are no timestamps or locale-dependent
fields, so the CSV can be checksummed. Write a complete report atomically
**before** raising an aggregate error that names every failed IRI and its final
status. A rerun replaces the same report from the same current package state;
an interrupted temporary write must not replace the prior complete report.
External error text is redacted at capture and escaped before CLI formatting.

Add focused offline tests with a transient failure that succeeds on retry, a
permanent failure, and several selected metadata surfaces. The assertions
must check per-IRI attempts, the maximum bound, exact fragment preservation,
C-collated row order, report presence after aggregate failure, all failed IRIs
in the error, and stable report bytes on a repeat run. Add an observable
`NEWS.md` entry, generated function documentation, and the narrow site update.

## Concrete steps and acceptance

From the metasalmon B-130 worktree:

1. Implement the module and test file, then run
   `Rscript -e 'devtools::document()'` and
   `Rscript -e 'testthat::test_file("tests/testthat/test-semantic-iri-verification.R", reporter = "summary")'`.
2. Run `Rscript -e 'devtools::test(stop_on_failure = TRUE)'`,
   `git diff --check`, and the package's relevant documentation build.
3. Run `uv run --project ../psc-data-systems psc-okf check knowledge --tier capture`
   from the primary repository checkout, or use the absolute sibling project
   path when running from a hub worktree. Run queue lint/check from the hub CLI.
4. Review the full diff and the persisted failure report fixture. Acceptance
   is the B-130 retirement condition in the queue item, with no live network
   dependency in tests.

The Python mirror is **owed, not an approved deviation**. This R-first change
establishes an evidence-backed API and report contract; a separate metasalmonpy
claim must port behavior in the same release stream before a version parity
claim can include it. Record that open leg in the S13 roadmap entry and R PR.
No invented queue ID or ontology ruling is implied by this plan.

## Decision log

- 2026-10-01: Scope collection to selected package semantic metadata. Candidate
  suggestions and data URLs have different meaning and would make the
  publication report claim more than it verified.
- 2026-10-01: Persist rows before aggregate failure. The consumer's
  success-only write loses the evidence most needed for diagnosis.
- 2026-10-01: Keep the Python port owed while B-130 settles the R contract;
  no deliberate parity deviation is being registered.
- 2026-10-01: Descriptor fallback follows the package reader's authority rule:
  all three canonical core CSVs must be present before they supersede the
  descriptor. A partial set does not hide identifiers in the descriptor.
- 2026-10-01: Scalar accepted/vocabulary IRIs are not semicolon-split. The
  package's multi-value `_iri` slots use semicolons, but a scalar URL may
  contain one legally as part of its exact identifier.

## Surprises and discoveries

- The Fraser consumer's collection is in `src/build.R`; its retrying verifier
  is in `src/extended-sdp.R`. Reading only the latter would miss several
  metadata surfaces.
- The current EML measurement IRI closure is narrower than the package
  semantic set and is unsuitable as the sole collector.
- The consumer's original collector omits the reviewed SSSOM mapping sets its
  package can carry. This implementation includes their literal HTTP semantic
  references after validating the manifest and its bound files.
- A full pkgdown build re-rendered unrelated pre-existing pages and NEWS
  history. The committed site slice keeps only this new function's page,
  reference entry, NEWS fragment, search entries, and sitemap link.

## Outcomes and recovery

The R verifier and its offline regressions are implemented in
[draft pull request 244](https://github.com/salmon-data-mobilization/metasalmon/pull/244).
The local strict R CMD check passed with zero errors, warnings, or notes;
GitHub CI and the Python port remain outstanding at this point. The report is
written before the aggregate abort, including status-less transport errors
and their final attempt counts. If the process stops before report
replacement, rerun the verifier on the unchanged SDP. If it reports failures, inspect its CSV and
correct the upstream vocabulary or package metadata before publication; a
failed dereference is not a warrant to substitute a different ontology term.
