# LLM Review With Context Files

Use this guide when you want
[`create_sdp()`](https://salmon-data-mobilization.github.io/metasalmon/reference/create_sdp.md)
or
[`suggest_semantics()`](https://salmon-data-mobilization.github.io/metasalmon/reference/suggest_semantics.md)
to review semantic candidates with an LLM **and** you have supporting
files such as README notes, data dictionaries, or technical reports.

## What Context Files Are Supported

`llm_context_files` accepts local files that can add domain context to
the LLM review step:

- markdown/text notes: `.md`, `.txt`, `.rst`
- delimited/text data: `.csv`, `.tsv`, `.json`, `.yaml`, `.yml`
- source/notebook files: `.R`, `.Rmd`, `.qmd`
- HTML pages: `.htm`, `.html`
- Word documents: `.docx`
- PDF reports: `.pdf` with the optional `pdftools` package
- Excel workbooks: `.xls`, `.xlsx`, `.xlsm` with the optional `readxl`
  package

The files are read locally, chunked, and trimmed before prompting. They
are used as supporting evidence only. The LLM still has to choose from
the deterministic shortlist returned by
[`find_terms()`](https://salmon-data-mobilization.github.io/metasalmon/reference/find_terms.md);
it does not mint raw IRIs.

## Input Contract and Explicit Opt-in

`llm_context_files` accepts a character vector of existing local **file
paths**. Keep the paths themselves instead of reading the files first:

``` r

context_files <- c(
  "./00_data/Data_dictionary_final_dataset.rmd",
  "./00_data/Data_dictionary_final_dataset.html",
  "./00_data/Data_dictionary_final_dataset.csv"
)
```

Do not pass the result of
[`readr::read_csv()`](https://readr.tidyverse.org/reference/read_delim.html),
[`xml2::read_html()`](http://xml2.r-lib.org/reference/read_xml.md), an R
Markdown reader, or another parsed object. A tibble or XML document is
data in memory, not a path, and now fails early with a path-specific
error. Use `llm_context_text` when the context is already available as
inline character text.

Context is also strictly opt-in: `llm_context_files` and
`llm_context_text` never trigger a network or LLM call. Set
`llm_assess = TRUE` explicitly. If context is supplied without it,
`metasalmon` warns that the context is ignored and continues with
deterministic retrieval, so similar output is expected.

When calling
[`infer_dictionary()`](https://salmon-data-mobilization.github.io/metasalmon/reference/infer_dictionary.md)
directly, both `seed_semantics = TRUE` and `llm_assess = TRUE` are
required for LLM review. Supplying LLM options while
`seed_semantics = FALSE` warns once and does not call the provider.

## Recommended Context Bundle

For a realistic Salmon Data Package review, pass a small bundle that
mixes:

1.  a README, HTML export, or methods note describing the dataset,
2.  a CSV, workbook, or DOCX/R Markdown data dictionary or analyst note,
3.  a technical report or PDF summary if one exists.

For example:

``` r

context_files <- c(
  "README.md",
  "methods-note.Rmd",
  "data-dictionary.xlsx",
  "technical-report.pdf"
)
```

Plain-text and CSV inputs are normally read as UTF-8. If they contain
invalid UTF-8, `metasalmon` retries Windows-1252/Latin-1 decoding before
the text is scored. R Markdown and HTML inputs are expected to be
authored as UTF-8.

Each assessment records the contributing labels in
`llm_context_sources`. Ordinary files keep their base name; when two
files share a base name, the label adds parent-directory context (and,
if necessary, a numeric suffix) so their chunks and source reports
remain distinct.

## One-shot `create_sdp()` Workflow

For DFO internal users, `chapi` plus the default Mistral model is the
shortest path:

``` r

library(metasalmon)

data_path <- system.file("extdata", "nuseds-fraser-coho-2023-2024.csv", package = "metasalmon")
fraser_coho <- readr::read_csv(data_path, show_col_types = FALSE)

pkg_path <- create_sdp(
  fraser_coho,
  path = "fraser-coho-2023-2024-sdp",
  dataset_id = "fraser-coho-2023-2024",
  table_id = "escapement",
  llm_assess = TRUE,
  llm_provider = "chapi",
  llm_model = "ollama2.mistral:7b",
  llm_context_files = context_files,
  check_updates = FALSE,
  overwrite = TRUE
)
```

That writes a review-ready package and uses the LLM to judge
deterministic candidates during semantic seeding.

What gets written back automatically:

- accepted variable, property, entity, and unit drafts into
  `metadata/column_dictionary.csv` as `REVIEW: <iri>`
- accepted table observation-unit drafts into `metadata/tables.csv` as
  `REVIEW: <iri>` when the suggestion is still lexically compatible with
  the table metadata

What stays in `semantic_suggestions.csv` for manual review:

- constraint and statistical-modifier assessments, even when the model
  accepts them
- dataset-level keyword suggestions targeting `metadata/dataset.csv`
- code-level semantic suggestions targeting `metadata/codes.csv`
- any additional shortlist evidence and `llm_*` review columns

## Bundle Review and Retrieval Sources

Measurement columns are reviewed as semantic bundles. Each bundle
contains the original dictionary row, existing semantics, column
metadata and context, plus six ordered candidate slots:

1.  variable,
2.  property,
3.  entity,
4.  unit,
5.  constraint, and
6.  statistical modifier.

A statistical modifier is part of variable identity (I-ADOPT
`StatisticalModifier`), so a slot is proposed only when the column is an
aggregation or summary — a mean, maximum, total, or peak. Methods are
never a dictionary slot under sdp-0.3.0: a table-constant procedure
lives in `tables.csv`, and row-varying procedures resolve through
`codes.csv`, where code-level method targets are still reviewed.

The initial LLM request judges those six roles together. A malformed or
missing slot falls back through the existing single-target adapter
without discarding valid sibling decisions. A malformed top-level
response falls back the whole bundle. Generic column, code, table, and
dataset targets retain their per-target review path.

Source selection is part of the review contract. Omit `sources` in
[`suggest_semantics()`](https://salmon-data-mobilization.github.io/metasalmon/reference/suggest_semantics.md)
or `semantic_sources` in
[`create_sdp()`](https://salmon-data-mobilization.github.io/metasalmon/reference/create_sdp.md)
to use role-aware defaults. Pass an explicit vector when the review must
stay inside a fixed set:

``` r

reviewed_smn_only <- suggest_semantics(
  df = fraser_coho,
  dict = infer_dictionary(
    fraser_coho,
    dataset_id = "fraser-coho-2023-2024",
    table_id = "escapement"
  ),
  sources = "smn",
  llm_assess = TRUE,
  llm_provider = "chapi",
  llm_context_files = context_files
)
```

An explicit source vector is a strict allowlist for both the initial
search and the one retry round. In this example, no retry can add a QUDT
candidate.

## Full Metadata Review With `suggest_semantics()`

If you want to inspect every metadata target explicitly, start from
inferred package artifacts and pass `codes`, `table_meta`, and
`dataset_meta` back into
[`suggest_semantics()`](https://salmon-data-mobilization.github.io/metasalmon/reference/suggest_semantics.md):

``` r

artifacts <- infer_salmon_datapackage_artifacts(
  resources = list(escapement = fraser_coho),
  dataset_id = "fraser-coho-2023-2024",
  table_id = "escapement",
  seed_semantics = FALSE
)

reviewed_dict <- suggest_semantics(
  df = artifacts$resources,
  dict = artifacts$dict,
  codes = artifacts$codes,
  table_meta = artifacts$table_meta,
  dataset_meta = artifacts$dataset_meta,
  llm_assess = TRUE,
  llm_provider = "chapi",
  llm_model = "ollama2.mistral:7b",
  llm_context_files = context_files
)

suggestions <- attr(reviewed_dict, "semantic_suggestions")
assessments <- attr(reviewed_dict, "semantic_llm_assessments")
```

Now you can filter by target file:

``` r

suggestions[, c("target_sdp_file", "target_sdp_field", "table_id", "column_name", "code_value", "label", "iri", "llm_decision", "llm_selected")]
```

Look especially at:

- `target_sdp_file == "column_dictionary.csv"`
- `target_sdp_file == "codes.csv"`
- `target_sdp_file == "tables.csv"`
- `target_sdp_file == "dataset.csv"`

That is the clearest path when you want the LLM to help review semantics
across **all** package metadata tables before you finalize anything.

## Understanding the Review Decisions

Each reviewed row carries an `llm_decision` worth scanning before you
trust a draft:

- `accept` — the model picked a candidate from the deterministic
  shortlist; on the
  [`create_sdp()`](https://salmon-data-mobilization.github.io/metasalmon/reference/create_sdp.md)
  path it is written back as a `REVIEW:` draft.
- `review` — the model was not confident enough to pick; nothing is
  auto-selected and the row is left for your judgement.
- `retry_search` — the model asked for a better query; the package runs
  at most one bounded retry round, re-retrieves, and reassesses once.
- `reject_shortlist` — the model judged every candidate to be the wrong
  concept family.
- `request_new_term` — a likely ontology gap. The model can return this
  directly, and a `reject_shortlist` that the bounded retry cannot
  resolve is **escalated** to it automatically. These rows are your cue
  to propose a new term rather than force a near miss — see the
  term-request workflow
  ([`detect_semantic_term_gaps()`](https://salmon-data-mobilization.github.io/metasalmon/reference/detect_semantic_term_gaps.md),
  [`render_ontology_term_request()`](https://salmon-data-mobilization.github.io/metasalmon/reference/render_ontology_term_request.md),
  [`submit_term_request_issues()`](https://salmon-data-mobilization.github.io/metasalmon/reference/submit_term_request_issues.md)).

The LLM never mints IRIs: `accept` only ever selects from the retrieved
shortlist, and a genuine gap surfaces as `request_new_term` instead of a
fabricated term.

The `semantic_llm_assessments` attribute uses one stable 30-column
schema for empty and populated results. Its final fields are
`llm_escalated_from`, which preserves `reject_shortlist` provenance, and
`llm_retry_query_rejection_reason`. When a retry query exactly
duplicates the original after case and whitespace normalization, the
assessment keeps `retry_search` and the original query, records
`duplicate_original_query`, and skips query generation, retrieval, and
reassessment for that slot. Other valid bundle retries can still
proceed.

Provider responses are handled conservatively. Malformed, duplicated,
unknown, or missing bundle slots fall back individually, while a
malformed top-level response falls back the whole bundle. If the
provider fails but deterministic candidates remain usable, the package
warns and preserves the original shortlist for manual review.

Pure deterministic validators run after LLM review. They check
statistical-modifier and constraint evidence, role and ontology-type
compatibility, known property/unit dimensions, and a small curated set
of redundancy rules. A failed validator changes `accept` to `review`,
clears the selected candidate, and appends a stable finding code and
explanation while preserving model confidence. Validators never retrieve
or substitute terms and never create an ontology gap.

## Structured Ontology Gaps

Use both package attributes when deciding whether a new term is needed:

``` r

gaps <- detect_semantic_term_gaps(reviewed_dict)

requests <- render_ontology_term_request(
  gaps,
  scope = "auto",
  ask = FALSE
)
```

[`detect_semantic_term_gaps()`](https://salmon-data-mobilization.github.io/metasalmon/reference/detect_semantic_term_gaps.md)
combines deterministic candidate gaps with final LLM `request_new_term`
decisions. Its `gap_detection_basis` distinguishes `candidate_gap`,
`llm_request_new_term`, and `candidate_gap_and_llm_request_new_term`.
Explicit LLM gaps remain visible even when SMN candidates exist.

Rendering never submits an issue. Routing precedence is an explicit row
override, a forced scope, a recognized model namespace suggestion, and
then the placement heuristic. A model-proposed namespace is evidence
rather than authority. Review every draft before using
[`submit_term_request_issues()`](https://salmon-data-mobilization.github.io/metasalmon/reference/submit_term_request_issues.md);
shared `smn` and DFO-specific `gcdfo` rows use their repository’s active
issue template, while `profile`, `uncertain`, and `skip` remain explicit
governance outcomes.

## Review Order

After
[`create_sdp()`](https://salmon-data-mobilization.github.io/metasalmon/reference/create_sdp.md)
or
[`suggest_semantics()`](https://salmon-data-mobilization.github.io/metasalmon/reference/suggest_semantics.md):

1.  open `README-review.txt`,
2.  review `metadata/column_dictionary.csv`,
3.  review `metadata/tables.csv`,
4.  review `metadata/dataset.csv`,
5.  review `metadata/codes.csv` when present,
6.  use `semantic_suggestions.csv` as the fallback evidence table.

Keep or edit every `REVIEW:` draft in the metadata CSVs directly. The
`semantic_suggestions.csv` file is evidence, not the canonical package
state.

## Rebuild EDH XML After Review

Once the package metadata is finalized:

``` r

validate_salmon_datapackage(pkg_path, require_iris = TRUE)
write_edh_xml_from_sdp(pkg_path)
```

[`write_edh_xml_from_sdp()`](https://salmon-data-mobilization.github.io/metasalmon/reference/write_edh_xml_from_sdp.md)
is intentionally strict. It refuses to rebuild from packages that still
contain `REVIEW:` markers or unresolved dataset/table placeholders. That
means the expected path is:

1.  create the package,
2.  review and finalize the metadata CSVs,
3.  remove all `REVIEW:` prefixes,
4.  run strict validation,
5.  rebuild the EDH XML.

## Setup Reminder

If you have not configured the provider yet, go back to:

- [Setup and
  Credentials](https://salmon-data-mobilization.github.io/metasalmon/articles/setup.html)

If you want the one-shot package walkthrough first, go back to:

- [5-Minute
  Quickstart](https://salmon-data-mobilization.github.io/metasalmon/articles/metasalmon.html)
