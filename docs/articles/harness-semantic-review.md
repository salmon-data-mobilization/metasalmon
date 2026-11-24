# Semantic Review in Your Harness

Use this guide when you want a model to judge the ontology candidates
`metasalmon` found for your package, and you have supporting files such
as README notes, data dictionaries, or technical reports for it to read.

`metasalmon` makes no model call and needs no API key. The judgement
runs in your own harness, such as Claude Code or Codex: the package
writes a **review packet**, the harness answers it, and the package
reads the answers back and checks them. Nothing the harness answers
reaches your metadata until you confirm it.

## The route at a glance

1.  Create the package with
    [`create_sdp()`](https://salmon-data-mobilization.github.io/metasalmon/reference/create_sdp.md).
2.  Write a review packet with
    [`write_semantic_review_packet()`](https://salmon-data-mobilization.github.io/metasalmon/reference/write_semantic_review_packet.md),
    passing your supporting files as `context_files`.
3.  Have your harness judge the packet. The ready-made harness is the
    `sdp-semantic-review` skill of the
    [smn-sci-plgn](https://github.com/salmon-data-mobilization/smn-sci-plgn)
    plugin.
4.  Read the answers back with
    [`ingest_semantic_assessments()`](https://salmon-data-mobilization.github.io/metasalmon/reference/ingest_semantic_assessments.md).
5.  Confirm each answer in the
    [`review_semantics()`](https://salmon-data-mobilization.github.io/metasalmon/reference/review_semantics.md)
    queue with
    [`accept_suggestion()`](https://salmon-data-mobilization.github.io/metasalmon/reference/accept_suggestion.md),
    then write your decisions with
    [`apply_sdp_semantics()`](https://salmon-data-mobilization.github.io/metasalmon/reference/apply_sdp_semantics.md).

## Install the harness skill

The `sdp-semantic-review` skill ships in the public
[smn-sci-plgn](https://github.com/salmon-data-mobilization/smn-sci-plgn)
plugin, from its [v0.2.0
release](https://github.com/salmon-data-mobilization/smn-sci-plgn/releases/tag/v0.2.0).
Install the plugin in Claude Code or Codex as its README describes. The
skill reads the packet’s own instructions, chooses only from the
candidates the packet offers, writes the answer file in the package’s
30-column contract, and hands the confirming calls back to you.

The skill can also build the packet and ingest the answers itself,
through metasalmonpy. The two packages write and read the same packet,
so you can equally build and ingest in R, as below, and use the skill
only to judge.

If you would rather write your own harness, the [Semantic Review in
R](https://salmon-data-mobilization.github.io/metasalmon/articles/semantic-review.html#have-your-own-harness-judge-the-shortlists)
guide shows the shape of one.

## Create the package

``` r
library(metasalmon)

data_path <- system.file("extdata", "nuseds-fraser-coho-2023-2024.csv", package = "metasalmon")
fraser_coho <- readr::read_csv(data_path, show_col_types = FALSE)

pkg_path <- create_sdp(
  fraser_coho,
  path = "fraser-coho-2023-2024-sdp",
  dataset_id = "fraser-coho-2023-2024",
  table_id = "escapement",
  check_updates = FALSE,
  overwrite = TRUE
)
```

[`create_sdp()`](https://salmon-data-mobilization.github.io/metasalmon/reference/create_sdp.md)
searches the vocabularies and writes the top-ranked compatible
candidates as `REVIEW:` drafts. Those drafts, and the slots it left
blank, are what the packet asks your harness to judge.

## Choose your context files

`context_files` accepts local files that add domain context to the
review:

- markdown and text notes: `.md`, `.txt`, `.rst`
- delimited and structured text: `.csv`, `.tsv`, `.json`, `.yaml`,
  `.yml`
- source and notebook files: `.R`, `.Rmd`, `.qmd`
- HTML pages: `.htm`, `.html`
- Word documents: `.docx`
- PDF reports: `.pdf`, with the optional `pdftools` package
- Excel workbooks: `.xls`, `.xlsx`, `.xlsm`, with the optional `readxl`
  package

The files are read on your machine, cut into overlapping chunks, and
scored against each target, and the packet carries the best excerpts
beside each target rather than the whole file. They are evidence for the
judge only: the judge still has to choose from the shortlist
[`find_terms()`](https://salmon-data-mobilization.github.io/metasalmon/reference/find_terms.md)
retrieved, and it never mints an IRI.

Pass the paths themselves, not files you have already read:

``` r
context_files <- c(
  "README.md",
  "methods-note.Rmd",
  "data-dictionary.xlsx",
  "technical-report.pdf"
)
```

Do not pass the result of
[`readr::read_csv()`](https://readr.tidyverse.org/reference/read_delim.html),
[`xml2::read_html()`](http://xml2.r-lib.org/reference/read_xml.md), an R
Markdown reader, or another parsed object. A tibble or XML document is
data in memory, not a path, and it is refused with an error. Use
`context_text` when the context is already a character string.

A good bundle mixes a README, HTML export or methods note describing the
dataset; a CSV, workbook, DOCX or R Markdown data dictionary or analyst
note; and a technical report, if one exists. The package’s own
`metadata/column_dictionary.csv` is a reasonable choice too.

Plain-text and CSV inputs are read as UTF-8. If they contain invalid
UTF-8, `metasalmon` retries Windows-1252/Latin-1 decoding before the
text is scored. R Markdown and HTML inputs are expected to be UTF-8.
Each assessment records the files that supplied its excerpts in
`llm_context_sources`. Files keep their base name; when two share one,
the label adds the parent directory (and, if needed, a numeric suffix)
so their excerpts stay distinct.

## Write the packet

``` r
packet <- write_semantic_review_packet(pkg_path, context_files = context_files)
packet$path      # <package>/review/semantic-review-packet.json
packet$packet_id # the SHA-256 the ingester checks
```

The packet holds exactly the slots
[`review_semantics()`](https://salmon-data-mobilization.github.io/metasalmon/reference/review_semantics.md)
would queue, each with its shortlist retrieved again (`top_n = 5` by
default) and the evidence the package’s validators read. Measurement
columns are grouped into bundles, so the judge settles the whole
variable (variable, property, entity, unit, constraint and statistical
modifier) before deciding any one slot. It is written under `review/`,
which no publication path reads.

Two arguments shape what the judge sees:

- `sources` keeps the search inside a fixed set of vocabularies. Omit it
  for role-aware defaults; an explicit vector is a strict allowlist for
  the packet’s shortlists and for the one retry round a judge can ask
  for.
- `code_scope` chooses which `codes.csv` values get a slot. The default,
  `"factor"`, matches
  [`create_sdp()`](https://salmon-data-mobilization.github.io/metasalmon/reference/create_sdp.md);
  a blank code slot it leaves out is listed in `packet$not_covered`
  rather than dropped silently.

## Have your harness judge it

Open the package folder in your harness and ask it to review the packet
at `review/semantic-review-packet.json`. The `sdp-semantic-review` skill
writes its answers to `review/semantic-assessments-pass-1.csv`, and the
packet’s `packet_id` to the one-line sidecar beside it, so the ingester
can tell which packet it judged. Any harness has to do the same.

The judge answers every slot with one of five decisions:

- `accept`: it picked a candidate from the shortlist, by index, and
  echoed its IRI.
- `review`: it was not confident enough to pick; the slot is left for
  you.
- `retry_search`: it asked for a better query. The package searches once
  more and writes a second packet for those slots only.
- `reject_shortlist`: every candidate is the wrong concept family. The
  package escalates a rejection to `request_new_term`, so the gap is
  filed rather than lost.
- `request_new_term`: a likely ontology gap. These rows are your cue to
  propose a new term rather than force a near miss.

## Read the answers back

``` r
result <- ingest_semantic_assessments(pkg_path)
result$status # "complete", or "awaiting_pass_2"
```

The ingester checks the answer file against the packet it names, then
each row. An IRI the packet did not offer is recorded as an error and
never applied, and a candidate index that is not a whole number is
refused. Deterministic validators then check statistical-modifier and
constraint evidence, role and ontology-type compatibility, known
property and unit dimensions, and a small curated set of redundancy
rules. A failed validator changes `accept` to `review`, clears the
selection, and appends a stable finding code and its explanation;
validators never substitute a term or create a gap. Free text the
harness wrote is redacted of anything that looks like a credential
before it is kept.

When `status` is `"awaiting_pass_2"`, a retry found new candidates: have
your harness answer `review/semantic-review-packet-pass-2.json` the same
way, in `semantic-assessments-pass-2.csv`, and call
[`ingest_semantic_assessments()`](https://salmon-data-mobilization.github.io/metasalmon/reference/ingest_semantic_assessments.md)
again. There is no third pass.

The record is kept in `review/semantic-llm-assessments.csv`, one row per
target in the 30-column assessment contract:

``` r
assessments <- semantic_llm_assessments(pkg_path)
assessments[, c("column_name", "dictionary_role", "llm_decision", "llm_confidence", "llm_selected_iri")]
```

## Confirm and write your decisions

The ingester never touches the metadata CSVs. Each answer now sits in
the review queue, under the candidate it chose:

``` r
review <- review_semantics(pkg_path)
review
# Paste the printed call for each answer you have checked, for example:
review <- accept_suggestion(
  review, "NATURAL_ADULT_SPAWNERS", "variable", rank = 1,
  table = "escapement"
)
apply_sdp_semantics(pkg_path, review)
```

Read each accepted definition against the column’s meaning before you
accept it. A model’s choice and a passing validator are evidence, not a
substitute for checking the source meaning. [Semantic Review in
R](https://salmon-data-mobilization.github.io/metasalmon/articles/semantic-review.md)
covers the queue, rejections and the metadata setters in detail.

## Structured ontology gaps

``` r
gaps <- detect_semantic_term_gaps(result$dictionary)

requests <- render_ontology_term_request(
  gaps,
  scope = "auto",
  ask = FALSE
)
```

[`detect_semantic_term_gaps()`](https://salmon-data-mobilization.github.io/metasalmon/reference/detect_semantic_term_gaps.md)
combines deterministic candidate gaps with the final `request_new_term`
decisions your harness recorded. Its `gap_detection_basis` distinguishes
`candidate_gap`, `llm_request_new_term`, and
`candidate_gap_and_llm_request_new_term`, and a recorded gap stays
visible even when SMN candidates exist. The [post-review publication
guide](https://salmon-data-mobilization.github.io/metasalmon/articles/post-review-package-publication.md)
shows the gap table in detail.

Rendering never submits an issue. Routing precedence is an explicit row
override, a forced scope, a recognized namespace the judge suggested,
and then the placement heuristic. A suggested namespace is evidence
rather than authority. Review every draft before using
[`submit_term_request_issues()`](https://salmon-data-mobilization.github.io/metasalmon/reference/submit_term_request_issues.md).

## Rebuild EDH XML after review

Once the package metadata is finalized:

``` r
validate_salmon_datapackage(pkg_path, require_iris = TRUE)
write_edh_xml_from_sdp(pkg_path)
```

[`write_edh_xml_from_sdp()`](https://salmon-data-mobilization.github.io/metasalmon/reference/write_edh_xml_from_sdp.md)
refuses to rebuild from a package that still holds `REVIEW:` markers or
unresolved dataset or table placeholders, so finish the review first.

## See also

- [Setup and
  Credentials](https://salmon-data-mobilization.github.io/metasalmon/articles/setup.md)
- [5-Minute
  Quickstart](https://salmon-data-mobilization.github.io/metasalmon/articles/metasalmon.md)
- [Semantic Review in
  R](https://salmon-data-mobilization.github.io/metasalmon/articles/semantic-review.md)
