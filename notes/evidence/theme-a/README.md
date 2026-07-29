# Theme A semantic-review evidence

This directory contains release evidence that is safe to keep in Git. The
versioned executable fixtures live under
`tests/testthat/fixtures/theme-a/`; this directory contains historical
observations and, when the live release gate is completed, immutable reviewed
captures.

## Evidence classes

- `historical-observations-v1.json` is `prose_only`. It records historical
  descriptions for orientation and is not represented as a captured provider
  response.
- Replay fixtures are synthetic regression exemplars. They must not be
  described as historical provider output.
- Live captures start under ignored `artifacts/theme-a/<run-id>/capture.json`
  with `evidence_status = "unreviewed_staging"`.
- Only a human-reviewed, sanitized capture with complete hash lineage can be
  promoted here. The immutable raw companion is publishable only because live
  mode accepts synthetic Theme A fixtures, records
  `data_classification = "synthetic_theme_a_fixture"`, never sends package-user
  data, and requires a separate maintainer safe-to-publish attestation.
  Promotion creates content-addressed, read-only files and refuses overwrite.

The ontology manifest pins fixture IRIs, source revisions, artifact hashes,
native RDF types, and definition provenance. Live review uses
`retrieval_mode = "frozen_fixture"` so all three runs judge the same candidate
evidence. Retrieval behavior itself is tested separately.

## Offline replay

Run from the repository root:

```sh
Rscript scripts/theme-a-benchmark.R replay
```

Replay validates fixture schemas and cross-artifact lineage before evaluating
the required, allowed-not-required, and forbidden semantic oracles.

The default package suite is also offline and does not require provider
credentials:

```sh
Rscript -e 'devtools::test(reporter = "summary", stop_on_failure = TRUE)'
```

Benchmark regression tests source the harness once and exercise replay,
comparison, lineage, cohort, and promotion behavior in-process. One subprocess
smoke test retains coverage of the actual command-line entry point. Immutable
Git-object and SHA-256 results are cached only within that test process, keyed by
commit and path; this avoids repeatedly reconstructing identical evidence
without weakening mutation checks.

Four exhaustive publication-integrity matrices are excluded from the ordinary
package suite. They remain offline and run automatically in the dedicated
`Theme A offline integrity` workflow when the harness, benchmark tests, evidence
fixtures, or evidence documentation changes. Run them locally with:

```sh
Rscript -e 'Sys.setenv(METASALMON_RUN_THEME_A_INTEGRITY = "true"); pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-theme-a-benchmark.R", reporter = "summary", stop_on_failure = TRUE)'
```

Those matrices cover source-artifact binding, mixed cohort provenance,
raw-checksum lineage, and immutable capture/cohort promotion. They do not make
network requests and do not read provider credentials.

## Exact live cohort

The release gate requires three runs from one clean, committed source state,
using one approved provider, exact configured model, exact resolved model, and
normalized endpoint. `openrouter/free` is rejected because it cannot prove a
stable model cohort. Live mode verifies that the recorded Git commit exists,
its tree matches, and the worktree status/diff hash is the canonical clean
value before making a provider call.

Captures are also bound to the source artifacts in that exact commit. Validation
reads `DESCRIPTION`, the benchmark script, the case fixture, the schema fixture,
and the ontology manifest directly from Git objects and verifies their recorded
SHA-256 values. A clean commit identifier cannot therefore be combined with
artifacts from a different working tree.

Use `openai/gpt-5.4-mini` only when it is available under that exact identifier
from the approved provider. Do not substitute another model silently.

```sh
Rscript scripts/theme-a-benchmark.R live \
  --provider=openrouter \
  --model=openai/gpt-5.4-mini \
  --allow-live-api=true \
  --run-id=theme-a-run-1
```

Repeat with distinct run IDs for runs 2 and 3. Provider credentials must already
exist in the expected environment variable; the harness never records the key.
Live mode refuses to proceed without `--allow-live-api=true`, even when a key is
present. Ordinary local tests and GitHub Actions never pass this flag and
explicitly run without provider credentials, so they cannot consume API credits.

Each run writes an immutable `capture.raw.json`, its `.sha256` sidecar, and an
editable `capture.json` review copy. Review the copy manually:

1. Copy the hash from `capture.raw.json.sha256` into
   `review.pre_sanitization_sha256`. Do not edit the raw capture or sidecar.
2. Inspect prompts, responses, events, assessments, final dictionary rows,
   ontology gaps, routes, and oracle results.
3. Confirm that the immutable raw capture contains only the versioned synthetic
   fixtures, provider protocol metadata, and model output. It must contain no
   credentials, package-user data, or other sensitive material.
4. Remove any sensitive material from the reviewed copy without changing the
   semantic evidence.
5. Set `review.status` to `reviewed`, `review.sanitized` to `true`,
   `review.raw_capture_reviewed` to `true`, and
   `review.raw_capture_safe_to_publish` to `true`; record `reviewed_by`,
   `reviewed_at`, and review notes.
6. Set `evidence_status` to `reviewed_sanitized`.
7. Promote the reviewed capture. Promotion verifies the raw file, sidecar,
   immutable semantic evidence, provider-interaction lineage, and review hash:

```sh
Rscript scripts/theme-a-benchmark.R promote \
  --capture=artifacts/theme-a/theme-a-run-1/capture.json
```

After all three captures have been reviewed and promoted, evaluate the exact
cohort using the reviewed staging paths:

```sh
Rscript scripts/theme-a-benchmark.R compare \
  --cohort=artifacts/theme-a/theme-a-run-1/capture.json,artifacts/theme-a/theme-a-run-2/capture.json,artifacts/theme-a/theme-a-run-3/capture.json \
  --expected-provider=openrouter \
  --expected-model=openai/gpt-5.4-mini \
  --output=artifacts/theme-a/cohort-gate.json
```

The cohort passes only when every critical case passes in at least two of three
runs, forbidden acceptances are zero, false prefills are zero, and all exact
source/provider/model provenance matches. Promote a passing gate only after its
three referenced capture hashes resolve to already promoted captures:

```sh
Rscript scripts/theme-a-benchmark.R promote \
  --cohort-manifest=artifacts/theme-a/cohort-gate.json
```

If credentials or the approved exact model are unavailable, record the release
gate as blocked in the living ExecPlan and keep the package pull request in
draft. Offline replay is not a substitute for this gate.
