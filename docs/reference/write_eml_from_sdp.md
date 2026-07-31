# Write reviewed EML 2.2.0 metadata from a Salmon Data Package

Builds deterministic EML 2.2.0 XML from a strictly valid Salmon Data
Package and an explicit EML mapping sidecar. The sidecar is required
because EML concepts such as measurement scale, structured parties,
methods, and rights cannot be inferred defensibly from the canonical SDP
tables.

## Usage

``` r
write_eml_from_sdp(
  path,
  output_path = NULL,
  mapping_path = NULL,
  overwrite = FALSE
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

## Value

Invisibly returns a list containing the XML text, normalized output
path, EML version, metadata package ID, stable series ID, validation
result, and deterministic data-object plan.

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
