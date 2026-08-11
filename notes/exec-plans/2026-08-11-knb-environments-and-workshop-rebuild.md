# KNB environments and workshop rebuild

Created 2026-08-11. Covers roadmap streams **S3** (KNB staging environment) and
**S4** (workshop rebuild). Sequencing and dependencies live in
[`notes/ROADMAP.md`](../ROADMAP.md); this file is the detail.

Source: an authored plan, reviewed and refined below. The review found five
things that would have bitten during implementation and one that would have
shipped a credential leak. Those are called out inline as **REVIEW** so the
original intent stays visible next to what changed.

---

## Part 1 — `knb_environment` in metasalmon

### Goal

A guarded staging target so a first-time depositor — and every workshop learner —
can rehearse the full publication path without writing to the production KNB
node.

### API

Add `knb_environment` as the **final** argument to `publish_sdp_to_knb()` and
`write_eml_from_sdp()`. Accept exactly `"production"` and `"staging"`; no partial
matching, no custom endpoints, no fallback between environments.

Production stays the default. Every **live** operation must state
`knb_environment` explicitly alongside `confirm = TRUE` — an unstated environment
on a live call is an error, not a default.

Closed internal registry, the single source of every environment-derived value:

| Value | DataONE network / node | Token |
|---|---|---|
| `production` | `PROD` / `urn:node:KNB` | `dataone_token` |
| `staging` | `STAGING` / `urn:node:mnTestKNB` | `dataone_test_token` |

Member-node, coordinating-node, resolver, catalog, and EML object URLs all derive
from that registry.

### REVIEW 1 — the staging token name is not redacted (blocking, security)

Verified against the current code:

```
dataone_token=SECRET       -> dataone_token=[REDACTED]
dataone_test_token=SECRET  -> dataone_test_token=SECRET     # leaks
DATAONE_TEST_TOKEN=SECRET  -> DATAONE_TEST_TOKEN=SECRET     # leaks
```

`.ms_redact_secrets()` (`R/cli-safety.R`) matches `dataone[_-]?token`, and
`dataone_test_token` does not match it — the alternation needs the whole
qualified name. Captured HTTP and provider errors are stored in returned tibbles
and written to CSV, so this is a leak at rest, not only on screen.

**Do this first, in its own commit, before any staging code exists.** Extend the
pattern to cover qualified token names and add the staging name to
`test-cli-safety.R` alongside the four provider variables already asserted there.
Backlog **#73**.

### REVIEW 2 — staging EML would overwrite production EML (blocking, correctness)

The plan says "keep production artifacts unchanged" and "isolate staging
derivatives under `publication/staging/`". Those two statements conflict for EML:

- `write_eml_from_sdp()` defaults `output_path` to **`metadata/eml.xml` inside
  the package** (`R/eml-export.R:2768`), not under `publication/`.
- Environment changes the resolver and object URLs the document contains, so a
  staging EML has **different bytes**.

So `write_eml_from_sdp(knb_environment = "staging")` with default arguments
silently replaces the reviewed production `metadata/eml.xml`. Worse, those bytes
are hashed into `plan_sha256`, the deterministic archive, and the reproducibility
manifest, so the damage propagates past the file itself.

**Resolve explicitly. Recommended:** when `knb_environment = "staging"` and
`output_path` is not supplied, default to
`publication/staging/eml.xml`. Production keeps `metadata/eml.xml`. An
explicitly supplied `output_path` is always honoured. Add a test asserting a
staging write leaves `metadata/eml.xml` byte-identical — assert on the file
hash, not on the return value, because the return value would look fine either
way.

### REVIEW 3 — the overwrite gate must stay ahead of the plan builder

0.2.3 added `overwrite` to `publish_sdp_to_knb()`, and PR #14 review caught a
real regression in it: `.ms_knb_build_plan()` **mutates** — it rewrites the SDP
archive and `eml.xml` in place — so eligibility must be decided *before* it runs.
Deciding after let `overwrite = TRUE` destroy published bytes and only then
abort.

The plan's rule "reject attempts to retarget an existing manifest with
`overwrite = TRUE`" lands in exactly that code path. Implement it beside the
existing `overwrite_eligible` computation in `publish_sdp_to_knb()`, **before**
the `.ms_knb_build_plan()` call — not inside the builder, and not after it. The
existing test that fingerprints every derived artifact and requires it
byte-identical after a refusal is the template to copy.

### REVIEW 4 — `publication/staging/` and the sidecar-preservation contract

0.2.0's P0-5 established that the writer replaces only files it owns and
preserves everything else, with `prune = TRUE` as the opt-in wipe. A new
writer-owned directory must be declared, or its status is ambiguous: preserved
as a user sidecar, or pruned as writer output?

**Decide and state it:** add `publication/staging/**` to
`.ms_package_managed_paths()` so `prune = TRUE` removes it and an ordinary
rewrite replaces only the files this call writes. Add it to the P0-5 regression
test's list of sidecar kinds with the *opposite* expectation from the reviewed
sidecars, so the contract is asserted in both directions.

### REVIEW 5 — "never accept custom endpoints" vs the test hook

`getOption("metasalmon.knb_adapter")` is how the suite injects a fake adapter and
asserts that a dry run never constructs a real one. The closed registry must
govern **endpoints and tokens**, not the adapter injection point. State that
distinction in the code comment, or a later reader will remove the hook in the
name of the rule and take the dry-run isolation tests with it.

### REVIEW 6 — version claim is stale

The plan says "if parallel work has reached 0.3.0, this becomes the next 0.3.x".
Current version is **0.2.4**. `knb_environment` is additive, so on its own it is
**0.2.5**. It only becomes 0.3.0 if bundled with S5 (#58 condition classes are
breaking). Do not bundle for its own sake — S4 pins an exact released version,
and a smaller release is easier to pin.

### Behaviour

- **Access and replication.** Staging may be private or public, and requests
  **zero replicas**; production public records keep three. Public staging still
  requires reviewed redistribution authority — rehearsal does not relax rights.
  Note `.ms_knb_normalize_access()` is in `collation_sensitive_fns`; any new
  ordering there must be radix.
- **Manifests.** Schema stays compatible. Reject environment mismatch,
  cross-environment revision, and retargeting an existing manifest. Assert that
  an existing **production** manifest written before this change still validates —
  that is the compatibility claim users depend on.
- **PIDs.** State how staging PIDs are minted such that one can never collide
  with or be mistaken for a production PID. Staging objects are never promoted;
  production is planned separately with production credentials.
- **Warnings.** Staging is non-durable, unsuitable for sensitive data, not
  promotable, and cannot receive a DOI. Say it at the call, not only in the docs.

### Verification

Enum validation · URL and token isolation per environment · production
compatibility · explicit live-target gating · staging public/private with zero
replicas · rights checks · target-specific artifacts · dry-run network isolation ·
capability failures · manifest mismatch · cross-target revision rejection ·
pre-existing production manifest still validates · **staging EML leaves
`metadata/eml.xml` byte-identical** (REVIEW 2) · **staging token redacted**
(REVIEW 1).

Then: focused publication tests, full suite, `devtools::document()`,
`R CMD check`, `scripts/build-pkgdown.R`. Live staging writes stay opt-in and out
of ordinary CI.

Docs to update: function reference, publication vignette, authentication
guidance, `NEWS.md`, and `docs/entrypoints.md` — whose KNB line currently
describes the workflow without an environment.

### Process

Isolated `feature/knb-environments` worktree. Merge `origin/main` at four
checkpoints: before implementation, after API and tests, before versioning and
full checks, and whenever the PR falls behind. Push, open a PR, merge only green.

---

## Part 2 — Workshop rebuild

Repo: `salmon-data-standards-workshop` (sandpaper). **Blocked by Part 1** — it
pins the exact released metasalmon version as its minimum.

### Episode order

1. Shared introduction and end goal
2. NuSEDS Fraser Coho in R / Python
3. **Excel:** NuSEDS template workflow
4. Personal data in R / Python
5. **Excel:** personal-data template workflow
6. Semantic annotation choices
7. Code lists and term placement
8. Validation, EML, KNB, and EDH
9. Optional concept-mapping extension

### Format

R stays visibly primary: `### R: live demonstration`, then a visible
`### Python: parallel workflow`, then a common checkpoint. **No required tabs and
no native `<details>`** — learner, instructor, print, JavaScript-free, and
all-in-one views must all be complete. One supported collapsed `spoiler`, used
only for optional LLM setup.

Each Excel episode gets a parallel metadata-review task for R/Python learners so
the room rejoins at the same artifact checkpoint.

### Layout

```text
salmon-data-workshop/
  fraser-coho-example/
    fraser-coho-example.Rproj   # R only
    raw/  context/  output/
  my-dataset/
    my-dataset.Rproj            # R only
    raw/  context/  output/
```

R users create the Fraser Coho project **during the NuSEDS exercise**, not during
setup, and the personal-data project during the second pass.

### Content

- Replace the legacy 30-row sample with the bundled
  `nuseds-fraser-coho-2023-2024.csv`; ship an identical download for Python and
  Excel learners and verify it against the package fixture.
- NuSEDS pass: template generation, `seed_semantics = FALSE`. Personal-data pass:
  the recommended middle path, `seed_semantics = TRUE, llm_assess = FALSE`.
- Present three semantic routes — manual, deterministic seeded review, optional
  LLM-assisted refinement. Human review is required for all three.
- Excel episodes: copy the latest SDP template, add CSV data, and explicitly open
  and edit `dataset.csv`, `tables.csv`, `column_dictionary.csv`, `codes.csv`. No
  R or Python.
- Keep early definitions of dataset, table, flat file, workbook; preview the four
  metadata CSVs before any code; distinguish Frictionless structure from
  external-standard alignment and salmon-specific convention.
- State supported inputs plainly: one flat file, multiple CSVs, rectangular
  tables from multi-sheet workbooks. **Not** NetCDF, rasters, nested arrays, or
  presentation-formatted sheets.
- Teach generate-once / version-later: never rerun
  `create_sdp(..., overwrite = TRUE)` over reviewed metadata; use a fresh
  versioned output and preserve prior manifests.

### REVIEW 7 — two content dependencies to resolve before writing episode 8

- **Episode 8 teaches validation as the final gate before deposit.** Roadmap S1
  exists because that gate under-checks: three error-severity rules are never
  executed and the validator checks no primary keys, nullability, or
  schema-required fields. Either land S1 first, or scope the episode's claim to
  what the validator actually does. Do not teach the stronger claim.
- **"Copy the latest SDP template"** needs a canonical, versioned template with a
  stable URL. That is `smn-data-pkg`, which S1 also touches. Name the exact
  source and version in the episode, not "the latest".

### Publication narrative

Frame the outcome as a reviewed SDP, validated EML, and a catalog-ready metadata
record. KNB is the golden path. Describe the benefit of reviewed EML ontology and
controlled-vocabulary annotations **conservatively** — they support discovery and
can aid computer-assisted integration; they do not produce automatic integration
or complete indexing. Link the
[EML semantic annotation primer](https://eml.ecoinformatics.org/semantic-annotation-primer).

Teach this sequence:

1. credential-free **staging dry run**
2. optional authorized private or public **staging rehearsal**
3. fresh **production dry run**
4. optional private **production deposit**
5. separate **KNB Publish** action for public release and DOI

Staging objects are never promoted. metasalmon does not mint the DOI; KNB's later
publication action does ([KNB DOI guidance](https://knb.ecoinformatics.org/knb/docs/doi.html)).

DFO/EDH is the alternative lane: `write_edh_xml_from_sdp()` produces HNAP-aware
XML, while profile validation and submission remain organizational handoffs.

R is the final validation/export/publication lane; Python and Excel learners
prepare a reviewed package and hand it to an R steward.

### Verification and delivery

Run the NuSEDS and personal-data R examples against the merged metasalmon
version; smoke-test Python 0.1.6; validate Excel template headers; confirm the
shared checkpoints. `sandpaper::check_lesson()` and `sandpaper::build_lesson()`.
Inspect learner, instructor, and all-in-one HTML for complete paths, valid links,
unique ids, and visible print content.

Update `config.yaml`, setup/reference/instructor guidance, README/index, links,
and the workshop's own `docs/entrypoints.md`. Preserve the untracked `.DS_Store`;
stage only intended files. Commit to `main`, let Pages rebuild, then verify the
live site and the key R / Python / Excel and KNB / EDH routes.

---

## Sequencing summary

| Step | Depends on | Gate |
|---|---|---|
| 0. Fix `dataone_test_token` redaction (#73) | — | `test-cli-safety.R` covers the qualified name |
| 1. `knb_environment` API + registry | 0 | Enum, URL/token isolation |
| 2. Staging EML output path (REVIEW 2) | 1 | Production `metadata/eml.xml` byte-identical |
| 3. Manifest and overwrite gating (REVIEW 3) | 1 | Pre-existing production manifest validates |
| 4. Managed-path declaration (REVIEW 4) | 1 | P0-5 contract asserted both directions |
| 5. Docs, version bump, release | 1–4 | `R CMD check` OK, pkgdown built |
| 6. Workshop rebuild | 5, and ideally S1 | `check_lesson()`, live site routes |
