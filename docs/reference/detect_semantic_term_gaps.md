# Detect candidate and LLM-identified semantic term gaps

Given semantic suggestions (typically attached to a dictionary as
`semantic_suggestions`), this function summarizes candidate fields that
lack a direct SMN match and final LLM `request_new_term` decisions. An
explicit final LLM gap remains a gap even when SMN candidates exist.

## Usage

``` r
detect_semantic_term_gaps(
  dict = NULL,
  suggestions = NULL,
  include_target_scopes = c("column", "code", "table", "dataset"),
  include_dictionary_roles = NULL,
  min_score = NA_real_
)
```

## Arguments

- dict:

  A dictionary tibble. When `suggestions` is `NULL`, the function reads
  both `semantic_suggestions` and `semantic_llm_assessments` attributes.

- suggestions:

  Optional semantic suggestion table. If omitted, this function uses the
  dictionary attributes. If supplied explicitly, only candidate and
  embedded `llm_*` fields in this table are used; dictionary assessment
  attributes are intentionally ignored.

- include_target_scopes:

  Target scopes to inspect. Defaults to all supported scopes.

- include_dictionary_roles:

  Optional vector of dictionary roles to restrict the gap scan (for
  example `c("variable", "property", "entity")`).

- min_score:

  Optional minimum score filter. Rows with score below this value are
  ignored when score is available.

## Value

A tibble with one row per unresolved semantic target. The existing
23-column candidate-gap prefix is preserved, followed by target
metadata, `gap_detection_basis`, LLM decision/rationale, proposed-term
fields, and `llm_escalated_from`. Detection values are `candidate_gap`,
`llm_request_new_term`, or `candidate_gap_and_llm_request_new_term`. Key
columns:

- `dataset_id`, `table_id`, `column_name`, `target_scope`,
  `target_sdp_file`, `target_sdp_field`, `target_row_key`,
  `dictionary_role`;

- `search_query` text used for lookup;

- `top_non_smn_source`, `top_non_smn_label`, `top_non_smn_iri`,
  `top_non_smn_score`;

- `non_smn_sources`, `candidate_count`, `placement_recommendation`,
  `placement_confidence`, `placement_rationale`.

## Details

It is designed to support a practical workflow:

1.  generate semantic suggestions with
    [`suggest_semantics()`](https://salmon-data-mobilization.github.io/metasalmon/reference/suggest_semantics.md);

2.  detect unresolved gaps with `detect_semantic_term_gaps()`;

3.  render request payloads with
    [`render_ontology_term_request()`](https://salmon-data-mobilization.github.io/metasalmon/reference/render_ontology_term_request.md);

4.  optionally submit issues with
    [`submit_term_request_issues()`](https://salmon-data-mobilization.github.io/metasalmon/reference/submit_term_request_issues.md).

## See also

[`render_ontology_term_request()`](https://salmon-data-mobilization.github.io/metasalmon/reference/render_ontology_term_request.md),
[`submit_term_request_issues()`](https://salmon-data-mobilization.github.io/metasalmon/reference/submit_term_request_issues.md),
[`suggest_semantics()`](https://salmon-data-mobilization.github.io/metasalmon/reference/suggest_semantics.md)

## Examples

``` r
suggestions <- tibble::tibble(
  dataset_id = c("d1", "d1"),
  table_id = c("t1", "t1"),
  column_name = c("run_id", "run_id"),
  code_value = NA_character_,
  column_label = c("Run ID", "Run ID"),
  column_description = "Run identifier from local monitoring pipeline",
  dictionary_role = c("variable", "variable"),
  target_scope = c("column", "column"),
  target_sdp_file = c("column_dictionary.csv", "column_dictionary.csv"),
  target_sdp_field = c("term_iri", "term_iri"),
  target_row_key = c("run_id", "run_id"),
  search_query = c("run_id", "run_id"),
  label = c("Run ID", "Run ID"),
  iri = c(NA_character_, NA_character_),
  source = c("gbif", "worms"),
  ontology = c("gbif", "worms"),
  match_type = c("label", "label"),
  definition = NA_character_,
  score = c(0.9, 0.85)
)
gaps <- detect_semantic_term_gaps(
  suggestions = suggestions,
  include_dictionary_roles = "variable"
)
gaps
#> # A tibble: 1 × 33
#>   dataset_id table_id column_name code_value target_scope target_sdp_file
#>   <chr>      <chr>    <chr>       <chr>      <chr>        <chr>
#> 1 d1         t1       run_id      NA         column       column_dictionary.csv
#> # ℹ 27 more variables: target_sdp_field <chr>, target_row_key <chr>,
#> #   dictionary_role <chr>, search_query <chr>, column_label <chr>,
#> #   column_description <chr>, top_non_smn_source <chr>,
#> #   top_non_smn_label <chr>, top_non_smn_iri <chr>, top_non_smn_ontology <chr>,
#> #   top_non_smn_match_type <chr>, top_non_smn_score <dbl>,
#> #   candidate_count <int>, non_smn_sources <chr>,
#> #   placement_recommendation <chr>, placement_confidence <dbl>, …

```
