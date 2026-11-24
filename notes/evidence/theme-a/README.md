# Theme A semantic-review evidence

The versioned executable fixtures live under
`tests/testthat/fixtures/theme-a/`. The `historical-observations-v1.json` file
here is prose-only context, not captured provider output. The replay fixture is
labelled `synthetic_regression_exemplar`; neither artifact attests to a live
model run.

The ontology manifest pins fixture IRIs, source revisions, artifact hashes,
native RDF types, and definition provenance. The offline replay validates the
fixture schemas and cross-artifact lineage, then scores every case with its
required, allowed-not-required, and forbidden semantic oracles. This remains
the reproducible pilot anchor for Foundry question Q23.

Run from the repository root:

```sh
Rscript scripts/theme-a-benchmark.R replay
```

To compare two validated replay fixtures for blocking oracle or prefill
regressions:

```sh
Rscript scripts/theme-a-benchmark.R compare \
  --baseline=tests/testthat/fixtures/theme-a/replay-v1.json \
  --candidate=tests/testthat/fixtures/theme-a/replay-v1.json
```

The package ingester's conformance tests build observations from actual ingest
outputs for the same six cases and score those observations with the replay's
oracles. The dedicated Theme A CI workflow runs replay and both focused test
files; the R CMD check workflow also runs replay. Neither mode needs provider
credentials or makes a model request.

The former live capture, cohort gate, and promotion procedures were retired by
hub item B-328 under the S16 model-call removal decision. Historical plans and
NEWS entries that describe them remain records of what existed at the time.
