# Review semantic suggestions in the console

Builds a re-runnable review queue from suggestions that already exist.
One entry per unfilled semantic slot, each with its ranked shortlist and
the exact
[`accept_suggestion()`](https://salmon-data-mobilization.github.io/metasalmon/reference/accept_suggestion.md)
call that decides it – printing that call is the feature: paste it into
a script and the decision becomes reproducible, which the spreadsheet
workflow this replaces never was.

## Usage

``` r
review_semantics(
  x,
  include_filled = FALSE,
  max_candidates = 5L,
  columns = NULL
)
```

## Arguments

- x:

  A written package path, a dictionary carrying the
  `semantic_suggestions` attribute, or the artifact list returned by
  [`infer_salmon_datapackage_artifacts()`](https://salmon-data-mobilization.github.io/metasalmon/reference/infer_salmon_datapackage_artifacts.md).

- include_filled:

  Logical; if `TRUE`, also queue slots that already hold a final
  (non-`REVIEW:`) IRI. Defaults to `FALSE`.

- max_candidates:

  Maximum candidates shown per slot. `Inf` shows all.

- columns:

  Optional character vector restricting the queue to these column names.

## Value

An `ms_semantic_review` tibble subclass, one row per candidate, in the
order the ranked producer emitted them. Carries the package path (when
there is one) as the `review_path` attribute.

## Details

**This never contacts a network or an LLM.** It reads the
`semantic_suggestions` attribute (or `semantic_suggestions.csv`) that
[`suggest_semantics()`](https://salmon-data-mobilization.github.io/metasalmon/reference/suggest_semantics.md)
/
[`create_sdp()`](https://salmon-data-mobilization.github.io/metasalmon/reference/create_sdp.md)
already produced. When those suggestions carry LLM review – only
possible if they were generated with `llm_assess = TRUE` – this surfaces
it; it never generates it.

## See also

[`accept_suggestion()`](https://salmon-data-mobilization.github.io/metasalmon/reference/accept_suggestion.md),
[`reject_suggestion()`](https://salmon-data-mobilization.github.io/metasalmon/reference/accept_suggestion.md),
[`apply_sdp_semantics()`](https://salmon-data-mobilization.github.io/metasalmon/reference/apply_sdp_semantics.md)

## Examples

``` r
dict <- tibble::tibble(
  dataset_id = "demo-1",
  table_id = "spawners",
  column_name = "spawner_count",
  term_iri = NA_character_
)
attr(dict, "semantic_suggestions") <- tibble::tibble(
  dataset_id = "demo-1",
  table_id = "spawners",
  column_name = "spawner_count",
  code_value = NA_character_,
  dictionary_role = "variable",
  target_scope = "column",
  target_sdp_file = "column_dictionary.csv",
  target_sdp_field = "term_iri",
  target_row_key = "demo-1/spawners/spawner_count",
  label = "Spawner Abundance",
  iri = "https://w3id.org/smn/SpawnerAbundance",
  source = "smn",
  ontology = "smn",
  definition = "Mature salmon returning to spawn.",
  score = 4.9
)

review <- review_semantics(dict)
review
#> ── spawners · spawner_count · variable ───────────────────────────────────────
#>    field:   column_dictionary.csv · term_iri
#>    current: <blank>
#>
#>    [1] Spawner Abundance   smn   score 4.9
#>        Mature salmon returning to spawn.
#>        https://w3id.org/smn/SpawnerAbundance
#>        review <- accept_suggestion(review, "spawner_count", "variable", rank = 1)
#>
#>        review <- reject_suggestion(review, "spawner_count", "variable")   # no candidate fits
#>
#> ── next ──────────────────────────────────────────────────────────────────────
#>    0 of 1 slot decided.
#>    Paste the calls above into your script, then write the decisions:
#>    apply_sdp_semantics(<package path>, review)
#>
```
