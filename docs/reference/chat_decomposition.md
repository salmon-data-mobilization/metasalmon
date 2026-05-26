# Interactive decomposition review for measurement variables

Starts or resumes a lightweight R-console decomposition session for one
measurement column. The session keeps structured state separately from
the raw transcript, asks grouped decomposition questions in small
rounds, and ends in an explicit preview/approve or new-term decision.

## Usage

``` r
chat_decomposition(
  dict,
  column_name,
  df = NULL,
  table_id = NULL,
  dataset_id = NULL,
  suggestions = NULL,
  sources = c("smn", "gcdfo", "ols", "nvs"),
  search_fn = find_terms,
  max_per_role = 5L,
  session_id = NULL,
  session_root = NULL,
  round_size = 3L,
  chat_provider = NULL,
  chat_model = NULL,
  chat_api_key = NULL,
  chat_base_url = NULL,
  chat_timeout_seconds = 60,
  chat_request_fn = NULL,
  commands = NULL,
  input_fn = readline,
  output_fn = NULL
)
```

## Arguments

- dict:

  A dictionary tibble containing the target measurement column.

- column_name:

  Column name to review.

- df:

  Optional data frame or named list of data frames, forwarded to
  [`suggest_semantics()`](https://dfo-pacific-science.github.io/metasalmon/reference/suggest_semantics.md)
  when `suggestions` are not supplied.

- table_id, dataset_id:

  Optional keys used to disambiguate `column_name` when `dict` contains
  multiple matching rows.

- suggestions:

  Optional `semantic_suggestions`-like tibble. When omitted,
  [`suggest_semantics()`](https://dfo-pacific-science.github.io/metasalmon/reference/suggest_semantics.md)
  is called and the results are filtered down to the selected
  measurement column's `term_iri` variable shortlist.

- sources, search_fn, max_per_role:

  Retrieval controls used only when `suggestions` are not supplied.

- session_id:

  Optional existing session id to resume.

- session_root:

  Optional directory for persisted sessions. Defaults to a package state
  directory under
  [`tools::R_user_dir()`](https://rdrr.io/r/tools/userdir.html).

- round_size:

  Maximum number of grouped questions to ask in each round. Default is
  `3`.

- chat_provider, chat_model, chat_api_key, chat_base_url:

  Optional chat adapter settings used for shortlist review. When
  omitted, the function uses a deterministic fallback over the retrieved
  shortlist.

- chat_timeout_seconds:

  Timeout for the optional chat adapter call.

- chat_request_fn:

  Advanced/test hook overriding the package-local chat adapter request
  function.

- commands:

  Optional scripted replies/actions, mainly for testing. When supplied,
  they take precedence over `input_fn`.

- input_fn:

  Function used to read console input. Defaults to
  [`base::readline()`](https://rdrr.io/r/base/readline.html).

- output_fn:

  Function used to print console output. Defaults to a simple
  [`cat()`](https://rdrr.io/r/base/cat.html) wrapper.

## Value

A list with `session_id`, `session_dir`, `approval_status`,
`proposed_patch`, `approved_patch`, `state`, and `transcript`.

## Details

The current first slice is intentionally narrow: it focuses on
measurement `term_iri` review and reuses existing
[`suggest_semantics()`](https://dfo-pacific-science.github.io/metasalmon/reference/suggest_semantics.md)
retrieval machinery when a shortlist is not supplied directly.

## Examples

``` r
if (FALSE) { # \dontrun{
dict <- tibble::tibble(
  dataset_id = "demo",
  table_id = "main",
  column_name = "spawner_count",
  column_label = "Spawner count",
  column_description = "Estimated natural-origin spawner abundance",
  column_role = "measurement",
  value_type = "integer",
  unit_label = "count",
  unit_iri = NA_character_,
  term_iri = NA_character_,
  property_iri = NA_character_,
  entity_iri = NA_character_,
  constraint_iri = NA_character_,
  method_iri = NA_character_
)

chat_decomposition(dict, column_name = "spawner_count")
} # }
```
