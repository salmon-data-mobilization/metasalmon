# Configure MetaSalmon

Package options are initialized on loading only when the user has not
set a value. Credentials and inheritance settings remain unset.
Environment variables are read at call time and are never set by package
loading.

## Details

The inventories below are generated from the same registry that owns the
load defaults. The in-package LLM provider path is deprecated and
removed in 0.7.0; its environment variables do not by themselves request
a model call. Prefer the external semantic review packet workflow for
new review work.

## See also

[`ms_setup_github()`](https://salmon-data-mobilization.github.io/metasalmon/reference/ms_setup_github.md)
for the GitHub credential helper,
[`find_terms()`](https://salmon-data-mobilization.github.io/metasalmon/reference/find_terms.md)
for retrieval,
[`create_sdp()`](https://salmon-data-mobilization.github.io/metasalmon/reference/create_sdp.md)
for schema-backed creation.

## Options

- `metasalmon.sdp_schema_source`:

  Default: `"auto"`. SDP schema source: "auto" tries the pinned remote
  release then the vendored copy; "remote" requires remote loading;
  "vendored" stays offline.

- `metasalmon.sdp_schema_base_url`:

  Default: `the pinned SDP release URL`. Base URL of a selected SDP
  schema bundle. The default is derived from the package's current
  schema-release pin.

- `metasalmon.sdp_schema_url`:

  Default: `NULL`. Legacy schema URL override. When nonempty, its
  schema/sdp.schema.yaml suffix is removed to obtain the bundle base
  URL; it takes precedence over sdp_schema_base_url.

- `metasalmon.term_search_timeout`:

  Default: `NULL (inherit backend timeout)`. Positive timeout in
  seconds. Source-specific environment timeout overrides the global
  environment timeout, which overrides this option. Unset/invalid falls
  back to the backend's 30 or 60 seconds.

- `metasalmon.term_search_parallel`:

  Default: `TRUE`. Enable parallel term retrieval.
  METASALMON_TERM_SEARCH_PARALLEL takes precedence.

- `metasalmon.llm_deprecation_quiet`:

  Default: `FALSE`. Suppress the in-package LLM deprecation warning. It
  does not enable a model call. The deprecated provider path is removed
  in 0.7.0.

- `metasalmon.validation_message_mode`:

  Default: `"default"`. Internal validation message mode: "default" or
  "review_ready". create_sdp temporarily sets and restores it;
  ordinarily leave it unchanged.

- `metasalmon.validation_semantics_seeded`:

  Default: `FALSE`. Internal validation message context. create_sdp
  temporarily sets and restores it; ordinarily leave it unchanged.

- `metasalmon.knb_adapter`:

  Default: `NULL`. Internal adapter injection hook for KNB tests. It
  does not change the closed publication-environment registry.

- `dataone_token`:

  Default: `NULL`. Process-local production DataONE JWT. Set only when
  making an explicitly requested production publication; never persisted
  or supplied by package loading.

- `dataone_test_token`:

  Default: `NULL`. Process-local DataONE test JWT, separate from
  dataone_token. No credential fallback between test and production.

## Environment variables

- `BIOPORTAL_APIKEY`:

  BioPortal API key. Missing keys produce one warning per loaded package
  namespace and an empty BioPortal result.

- `METASALMON_CACHE`:

  Enable the process-local term-result cache with 1, true or yes; unset
  disables it.

- `METASALMON_EMBEDDING_RERANK`:

  Enable embedding reranking with 1, true or yes; unset disables it.

- `METASALMON_EMBEDDING_WEIGHT`:

  Embedding score weight; defaults to 1. Invalid/nonfinite values fall
  back to 1.

- `METASALMON_DEBUG`:

  Enable embedding diagnostics with 1 or true; unset disables them.

- `METASALMON_TERM_SEARCH_TIMEOUT`:

  Global positive retrieval timeout in seconds; overrides the option but
  yields to the source-specific variable.

- `METASALMON_TERM_SEARCH_TIMEOUT_<SOURCE>`:

  Positive retrieval timeout for an uppercase source name, such as NVS,
  ZOOMA or QUDT; highest timeout precedence.

- `METASALMON_TERM_SEARCH_PARALLEL`:

  Parallel override: 1/true/yes/on enables; 0/false/no/off disables;
  unset/unrecognized falls back to the option.

- `METASALMON_TERM_SEARCH_WORKERS`:

  Positive worker-count override; otherwise worker count derives from
  source count and available cores.

- `OPENAI_API_KEY`:

  OpenAI credential for the deprecated in-package provider path; only
  read on explicit LLM assessment.

- `OPENROUTER_API_KEY`:

  OpenRouter credential for the deprecated in-package provider path;
  only read on explicit LLM assessment.

- `CHAPI_API_KEY`:

  Chapi credential for the deprecated in-package provider path; only
  read on explicit LLM assessment.

- `METASALMON_LLM_API_KEY`:

  OpenAI-compatible credential and fallback for provider-specific keys.
  Explicit llm_api_key takes precedence.

- `METASALMON_LLM_MODEL`:

  Model fallback for the deprecated provider path. Explicit llm_model
  takes precedence; Chapi checks CHAPI_MODEL first.

- `CHAPI_MODEL`:

  Chapi model fallback before METASALMON_LLM_MODEL; otherwise the Chapi
  model default applies.

- `METASALMON_LLM_BASE_URL`:

  Endpoint fallback for the deprecated provider path. Explicit
  llm_base_url takes precedence; Chapi checks CHAPI_BASE_URL first.

- `CHAPI_BASE_URL`:

  Chapi endpoint fallback before METASALMON_LLM_BASE_URL; otherwise the
  Chapi endpoint default applies.

- `METASALMON_LLM_REASONING_EFFORT`:

  Reasoning-effort fallback for the deprecated provider path; explicit
  llm_reasoning_effort takes precedence.

## Examples

``` r
old <- options(metasalmon.term_search_parallel = FALSE)
getOption("metasalmon.term_search_parallel")
#> [1] FALSE
options(old)
```
