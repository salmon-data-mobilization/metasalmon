# Find candidate terms across external vocabularies

Lightweight meta-search helper for IRIs. Uses public APIs when
available. Implements role-aware ontology preferences per
dfo-salmon-ontology CONVENTIONS.

## Usage

``` r
find_terms(
  query,
  role = NA_character_,
  sources = NULL,
  expand_query = TRUE,
  release = NULL,
  snapshot_dir = NULL
)
```

## Arguments

- query:

  Character search string (e.g., `"spawner count"`, `"temperature"`).

- role:

  Optional I-ADOPT role hint for ranking and source selection. One of:
  `"variable"` (compound term), `"property"` (characteristic),
  `"entity"` (thing measured), `"constraint"` (qualifier),
  `"statistical_modifier"`, `"method"`, or `"unit"`. Results are ranked
  higher when they match preferred ontologies for the role, and when
  `sources` is `NULL` the role also chooses which sources are searched.

- sources:

  Character vector of vocabulary sources to query, or `NULL` (the
  default) to query the sources
  [`sources_for_role()`](https://salmon-data-mobilization.github.io/metasalmon/reference/sources_for_role.md)
  names for `role`; with no role, that is
  `c("smn", "gcdfo", "ols", "nvs")`. Options: `"smn"`, `"gcdfo"`,
  `"ols"`, `"nvs"`, `"zooma"`, `"qudt"`, `"gbif"`, `"worms"`,
  `"bioportal"`. A vector you supply is a strict allowlist, read
  consistently by this package: each name is trimmed and Unicode
  lower-cased independently of the session locale, a missing or empty
  name is dropped, and a repeated name is dropped after its first
  appearance, so `"SMN"` and `" smn "` both search smn. A name that is
  none of the options is reported with `status = "unsupported"` and no
  lookup is performed for it; supported sources in the same call still
  return their results. An empty vector returns an empty tibble.

- expand_query:

  Logical. If `TRUE` (default), applies role-aware query expansion
  (Phase 4) to generate additional query variants based on the role
  context. For example, unit queries get abbreviation expansions, method
  queries get "method" suffix added. Set to `FALSE` to search only the
  exact query.

- release:

  Optional release versions of smn and gcdfo to search instead of the
  latest ontology, named by ontology: `c(smn = "0.0.3")`, or
  `c(smn = "0.0.3", gcdfo = "0.0.9")`. Each is read from its release
  snapshot, downloaded from its version IRI
  (`https://w3id.org/smn/0.0.3`) once per session, and checked against
  the snapshot's `MANIFEST.sha256` when it carries one. A pin never
  falls back to the latest ontology: a release that cannot be read or
  does not match its manifest is an error. Only smn and gcdfo can be
  pinned; other sources are searched as they are.

- snapshot_dir:

  Optional local release snapshots, named by ontology the same way, such
  as a checkout's `docs/releases/0.0.3/`. Each is read from disk, with
  no download. When `release` names the same ontology too, a snapshot
  that declares an `owl:versionIRI` must declare that version.

  A pinned smn release is read from its RDF/XML (`smn.owl`), which holds
  the same terms as the latest ontology's modules, and its terms get the
  role hints the module reader gives them, with one difference: a
  release records no module, so a term whose entity hint comes only from
  belonging to the `01-entity-systematics` module has no entity hint in
  a release.

## Value

Tibble with columns: `label`, `iri`, `source`, `ontology`, `role`,
`match_type`, `definition`, `score`, `alignment_only`,
`agreement_sources`, `role_hints`, `zooma_confidence`,
`zooma_annotator`. The `score` column shows the computed ranking score.
The `alignment_only` column indicates terms from Wikidata (useful for
crosswalks but not canonical modeling). The `agreement_sources` column
indicates how many sources returned the same IRI or label (Phase 4
cross-source agreement). Returns empty tibble if no matches found.

The result has a `"diagnostics"` attribute (access via
`attr(result, "diagnostics")`) containing per-source/query diagnostic
information: source, query, status (`success`, `http_error`, `error` or
`unsupported`), count, elapsed_secs, and error message if applicable. A
supported search with no matches remains `success`. Unsupported and
failed lookups warn that the result is incomplete and are not cached. An
unsupported name is still reported when a local smn or gcdfo match
short-circuits other supported lookups.

When `release` or `snapshot_dir` pins an ontology the call searched, the
result also has an `"ontology_release"` attribute: a tibble with one row
per pinned ontology the search asked, recording which release was
searched. smn is asked first, and when it matches a query by label,
gcdfo is not asked for that query, so a gcdfo pin that was never asked
is not recorded. The columns are `ontology`, `version`, `version_iri`
(as the snapshot declares it, or `NA`), `file`, `sha256` (of the bytes
read), `manifest_verified` (`TRUE` when the snapshot's `MANIFEST.sha256`
vouched for them, `FALSE` when it carries none) and `source` (the
version IRI or the snapshot directory).

## Details

**Supported sources:**

- **SMN** (Salmon Domain Ontology): shared salmon-domain search from
  `https://w3id.org/smn/` with canonical shared IRIs (e.g.
  `https://w3id.org/smn/Stock`)

- **GCDFO** (DFO Salmon Ontology): DFO-specific search from
  `https://w3id.org/gcdfo/salmon#`

- **OLS** (Ontology Lookup Service): Broad cross-ontology search, no API
  key needed

- **NVS** (NERC Vocabulary Server): Marine and oceanographic terms
  (P01/P06)

- **ZOOMA** (EBI text-to-term annotations): Resolves to OLS term
  metadata

- **QUDT** (Quantities, Units, Dimensions and Types): Preferred for unit
  role

- **GBIF** (Global Biodiversity Information Facility): Taxon backbone
  for entity role

- **WoRMS** (World Register of Marine Species): Marine taxa for entity
  role

- **BioPortal**: Requires API key via `BIOPORTAL_APIKEY` environment
  variable

**Role-based ontology preferences (Phase 2):**

- `unit`: QUDT preferred, then NVS P06

- `property`: STATO/OBA measurement ontologies, NVS P01

- `entity`: smn first, then gcdfo + NCEAS Salmon (ODO), GBIF/WoRMS for
  taxa

- `method`: smn first, then gcdfo: SKOS + SOSA/PROV patterns, plus
  AGROVOC

- Wikidata is alignment-only (lower ranking for
  crosswalks/reconciliation)

Results are scored using I-ADOPT vocabulary hints and role-based
ontology preferences, then ranked by relevance. When `"smn"` is included
in `sources`, shared salmon-domain ontology search runs first; `"gcdfo"`
is used as a deterministic DFO-specific source before external sources.
External fallback sources are skipped when SMN or GCDFO returns a good
label match. Network calls are best-effort and return an empty tibble on
failure.

## See also

[`suggest_semantics()`](https://salmon-data-mobilization.github.io/metasalmon/reference/suggest_semantics.md)
for automated suggestions based on your dictionary.

[`sources_for_role()`](https://salmon-data-mobilization.github.io/metasalmon/reference/sources_for_role.md)
for role-optimized source selection.

## Examples

``` r
if (FALSE) { # \dontrun{
# Search for terms matching "spawner count"
results <- find_terms("spawner count")
head(results)

# Search specifically for property terms
property_terms <- find_terms("temperature", role = "property")

# Search for units: with no sources named, the unit role searches
# sources_for_role("unit"), which puts QUDT first
unit_terms <- find_terms("kilogram", role = "unit")

# Search for taxa using taxon resolvers
taxa <- find_terms("Oncorhynchus kisutch", role = "entity", sources = c("gbif", "worms"))

# Search a specific source
ols_results <- find_terms("salmon", sources = "ols")

# Search multiple sources
all_results <- find_terms("escapement", sources = c("smn", "gcdfo", "ols", "nvs"))

# Search smn release 0.0.3 rather than the latest ontology, and record it
pinned <- find_terms("escapement", sources = "smn", release = c(smn = "0.0.3"))
attr(pinned, "ontology_release")

# Pin the searches suggest_semantics() makes
# suggest_semantics(dict, search_fn = function(query, role, sources) {
#   find_terms(query, role = role, sources = sources, release = c(smn = "0.0.3"))
# })
} # }
```
