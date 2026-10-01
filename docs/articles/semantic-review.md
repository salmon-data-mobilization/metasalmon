# Semantic Review in R

`create_sdp()` produces review-ready metadata. This guide takes you through the
0.5.0 review flow: decide the semantic IRIs, write those decisions, fill the
remaining metadata and run strict validation. You can do this from R, keeping
your choices in a script. The examples are displayed rather than run when the
guide builds; candidate ranks and outstanding fields depend on your package.

Start with a package created by the [quickstart](metasalmon.html):

``` r
library(metasalmon)
pkg_path <- "fraser-coho-2023-2024-sdp"
```

## 1. Inspect the semantic review queue

``` r
review <- review_semantics(pkg_path)
review
```

The printed queue groups candidates by the slot they could fill, shows their
labels, definitions and ranks, and prints the call that decides each slot.
Read the definition against the column's meaning and methods before accepting.
Ranking is a retrieval aid; it does not decide whether a term is appropriate.

`review_semantics()` reads existing suggestions from the package, a dictionary
with a `semantic_suggestions` attribute, or inferred artifacts. It makes no
network or model call. To revisit filled slots, use `include_filled = TRUE`;
use `columns = "NATURAL_ADULT_SPAWNERS"` to focus on one column. The default
shows five candidates per slot; `max_candidates = Inf` shows all of them.

An empty queue does not establish that the package is finished. A required slot
with no retrieved candidates can still appear in `review_metadata()` below.

## 2. Accept a candidate or reject the shortlist

Paste the printed call for a candidate you have reviewed. For example, **if
rank 1 fits** the measurement column in your queue:

``` r
review <- accept_suggestion(
  review, "NATURAL_ADULT_SPAWNERS", "variable", rank = 1,
  table = "escapement"
)
```

If no candidate fits, reject that slot and record your actual reason. This
example reason is illustrative; replace it with the finding from your review:

``` r
review <- reject_suggestion(
  review, "NATURAL_ADULT_SPAWNERS", "unit", table = "escapement",
  reason = "The shortlisted definitions do not match the unit recorded in the source."
)
```

Each call returns the updated review; neither writes the package yet. A
rejection leaves a gap to resolve. It does not approve a different term.

The slot determines the addressing arguments. The printed calls supply them:

| Slot | Address |
|---|---|
| A dictionary field | `column`, `role`; also `table` when needed |
| A table-level field | `role` and `table`, with no `column` |
| A code-value field | `column`, `role`, `table` and `code_value` |

If a column and its code values share a role, `code_value = ""` selects the
column's own slot. To accept an independently verified IRI that retrieval did
not shortlist, pass it as `iri` to `accept_suggestion()`. The setter route in
step 4 also handles a field with no candidates.

## 3. Write and resume your decisions

``` r
apply_sdp_semantics(pkg_path, review)
```

This writes the decisions into the metadata and keeps `datapackage.json` in
step. Accepted values lose their `REVIEW:` prefix. Undecided slots remain for
review, and data CSV bytes are unchanged. Rejection reasons are persisted in
`semantic_suggestions.csv` and shown with the gap by `review_metadata()`.

Rebuild the queue after writing, or when you return to the package later:

``` r
review <- review_semantics(pkg_path)
review
```

Previously decided slots are omitted by default. Use `include_filled = TRUE`
when you intend to reconsider them.

## 4. Fill metadata and fields with no candidates

``` r
review_metadata(pkg_path)
```

This checks the package's required fields, IRIs and placeholders against the
selected schema. It prints setter calls with placeholders for your real
values. Replace each placeholder before running a call; an unedited
`<add ...>` value is refused. Review the description and contact details
against the source, including permissions and the licence.

The four setters address the four metadata tables. These examples use rows in
the bundled quickstart package; adapt the prose to your own source:

``` r
set_sdp_dataset(
  pkg_path,
  title = "Fraser coho spawner estimates, 2023-2024",
  description = "Annual spawner estimates by population and survey year."
)

set_sdp_table(
  pkg_path, "escapement",
  table_label = "Spawner estimates",
  description = "Population and year records from the bundled Fraser coho example."
)

set_sdp_column(
  pkg_path, "NATURAL_ADULT_SPAWNERS", table = "escapement",
  column_label = "Natural adult spawners"
)

set_sdp_code(
  pkg_path, "ESTIMATE_STAGE", "FINAL", table = "escapement",
  code_label = "FINAL"
)
```

These calls illustrate row addressing; they do not fill every outstanding
field. `set_sdp_column()` also accepts `term_iri`, `property_iri`, `entity_iri`
and `unit_iri`; `set_sdp_table()` accepts `observation_unit_iri`, and
`set_sdp_code()` accepts `term_iri`. Supply a term only after checking its
meaning and scope. Passing validation does not justify a semantic choice.

The setters write the canonical metadata CSVs and update the descriptor in
the same operation. Run `review_metadata()` again to see what remains.

## 5. Validate and continue to publication

``` r
review_metadata(pkg_path)
validate_salmon_datapackage(pkg_path, require_iris = TRUE)
```

Strict validation checks the required metadata and IRIs. Publication also
requires the reviewed semantic closure and reviewed EML facts. Continue with
the [post-review publication guide](post-review-package-publication.html) for
term gaps, closure evidence and the publication steps. A rejected shortlist or
unresolved ontology gap needs a decision before that path can finish.

## Optional decomposition dialogue

In 0.5.0, `chat_decomposition()` provides a console dialogue for one
measurement column's variable term. It asks grouped questions, proposes a
patch or term request, and requires explicit approval of the preview. It
returns the proposal and session record; it does not apply the patch to your
package.

``` r
pkg <- read_salmon_datapackage(pkg_path)
session <- chat_decomposition(
  dict = pkg$dictionary,
  column_name = "NATURAL_ADULT_SPAWNERS",
  table_id = "escapement"
)
session$approval_status
session$approved_patch
```

At the console, `/preview` displays the proposal, `/approve` approves it and
`/quit` saves the session and stops. Keep the returned `session_id` and pass
it to `chat_decomposition()` to resume. Review the approved patch before
writing its chosen term with `set_sdp_column()`.

Without chat adapter settings, the dialogue uses its deterministic fallback
over retrieved candidates. Retrieving candidates can contact vocabulary
services. Supplying `chat_provider`, `chat_model` and the corresponding
credentials opts into the optional model adapter.

**Development builds deprecate this dialogue and the in-package model call;
they warn on use and remove them in 0.7.0.** On those builds, use
`write_semantic_review_packet()` and `ingest_semantic_assessments()` for a
review conducted in your own harness. The ordinary review queue and setters
above remain the path for writing your decisions.

## Spreadsheet fallback

You can still edit `metadata/*.csv` in a spreadsheet, save them as CSV and run
validation again. Preserve row keys and column names. This route requires you
to keep the reasoning for your choices alongside the package; the R decision
calls record shortlist rejections directly. Neither route makes a retrieved
term or a passing validator a substitute for checking the source meaning.
