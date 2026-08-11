Salmon Data Package Review Checklist

Dataset ID: demo-1

Review the package in Excel, but treat metadata/column_dictionary.csv and metadata/tables.csv as the files you finalize.
semantic_suggestions.csv is backup context, not the main place to do the review.

Checklist:
[ ] 1. Start in metadata/*.csv and replace every value that begins with 'MISSING DESCRIPTION:' or 'MISSING METADATA:'.
[ ] 2. Review metadata/column_dictionary.csv and metadata/tables.csv first. Those files already contain the prefilled labels and IRIs you are actually finalizing. Confirm or edit the prefilled IRIs there before touching anything else.
[ ] 3. Use semantic_suggestions.csv only as a fallback shortlist if you are unsure or want a better match. Click through and read the term definitions before changing an IRI. If no candidate fits, request a new term instead of forcing a bad match.
[ ] 4. If you need EDH XML after review, rebuild it from the finalized package with write_edh_xml_from_sdp(pkg_path).
[ ] 5. Re-open the folder in R with read_salmon_datapackage(pkg_path), then run validate_salmon_datapackage(pkg_path, require_iris = TRUE). Validation should pass only after every REVIEW marker is gone.
[ ] 6. Share the whole package folder (or a zip of the whole folder) so the metadata and data stay together.

If you need a new ontology term, route it here:
- Shared cross-organization/domain term request (salmon-domain): https://github.com/salmon-data-mobilization/salmon-domain-ontology/issues/new/choose
- DFO-specific policy/operations term request (gcdfo / DFO salmon ontology): https://github.com/dfo-pacific-science/dfo-salmon-ontology/issues/new/choose

Recommended path: create package -> review/edit in Excel -> reload and check unresolved gaps -> remove REVIEW markers -> rebuild EDH XML if needed -> validate -> publish.
Tip: if you edit CSV files in Excel, save them back to CSV before re-validating in R.
Tip: semantic_suggestions.csv is the detailed evidence trail; metadata/column_dictionary.csv and metadata/tables.csv are the authoritative files you actually finalize.
Guide: https://salmon-data-mobilization.github.io/metasalmon/articles/post-review-package-publication.html
