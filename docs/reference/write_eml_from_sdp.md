# Write reviewed EML 2.2.0 metadata from a Salmon Data Package

Builds deterministic EML 2.2.0 XML from a strictly valid Salmon Data
Package and an explicit EML mapping sidecar. The sidecar is required
because EML concepts such as measurement scale, structured parties,
dataset-level method narrative, and rights cannot be inferred defensibly
from the canonical SDP tables. When `metadata/methods.csv` is present,
validated procedures actually bound to observed measurements are emitted
as method steps with their method and protocol IRIs, descriptions,
versions, and citations; unreferenced registry alternatives are retained
in the return value but are not asserted as performed.

## Usage

``` r
write_eml_from_sdp(
  path,
  output_path = NULL,
  mapping_path = NULL,
  overwrite = FALSE,
  supplementary_objects = NULL,
  require_revision_key = FALSE
)
```

## Arguments

- path:

  Directory containing a Salmon Data Package.

- output_path:

  Output XML path. Defaults to `metadata/eml.xml` inside `path`.

- mapping_path:

  Reviewed YAML mapping. Defaults to `metadata/eml-mapping.yml` inside
  `path`.

- overwrite:

  Logical; replace a different existing output only when `TRUE`. An
  identical existing file is treated as an idempotent success.

- supplementary_objects:

  Optional data frame describing canonical SDP archives or expanded
  artifacts to expose as EML `otherEntity` elements. Required columns
  are `path`, `pid`, `format_id`, `checksum`, `object_name`,
  `entity_name`, and `description`; optional `size`, when supplied, must
  match the file. `entity_type` may distinguish an expanded artifact
  from an archive. Objects use lowercase SHA-256 checksums and safe
  relative `object_name` paths; only `application/zip` objects receive
  `compressionMethod = zip`.
  [`publish_sdp_to_knb()`](https://salmon-data-mobilization.github.io/metasalmon/reference/publish_sdp_to_knb.md)
  supplies this plan automatically; ordinary standalone EML export
  leaves the argument `NULL`.

- require_revision_key:

  Logical; when `TRUE`, require a reviewed `publication.revision_key` in
  the EML mapping sidecar. The key creates a new deterministic metadata
  package ID without changing the series ID.

## Value

Invisibly returns a list containing the XML text, normalized output
path, EML version, metadata package ID, stable series ID, validation
result, revision key, deterministic data and supplementary-object plans,
the complete method registry (`methods`), and the subset asserted in EML
(`used_methods`).

## Details

Measurement attributes receive exactly two semantic annotations in the
initial profile. Both reviewed OWL measurement-datum classes and SKOS
compound-variable concepts use Dublin Core Terms `subject` with the
reviewed `term_iri`, followed by QUDT `hasUnit` using the reviewed
`unit_iri`. The broader topic predicate is intentional: an OWL class is
not necessarily an OBOE `MeasurementType`, and schema-valid EML must not
silently assert that unsupported range. The exporter deliberately does
not project incomplete I-ADOPT roles or procedure annotations into EML.

## Examples

``` r
if (FALSE) { # \dontrun{
write_eml_from_sdp("path/to/reviewed-sdp")
} # }
```
