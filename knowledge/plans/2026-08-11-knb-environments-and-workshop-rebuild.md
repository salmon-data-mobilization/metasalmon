---
type: Artifact
title: "KNB environments and workshop rebuild"
description: "Execplan for the KNB staging environment (stream S3) and the workshop rebuild (stream S4)."
status: draft
tags: [execplan]
psc:
  id: metasalmon:plan:2026-08-11-knb-environments-and-workshop-rebuild
  contexts: [metasalmon:context:hub-coordination]
---

# KNB environments and workshop rebuild

Created 2026-08-11. Covers roadmap streams **S3** (KNB staging environment) and
**S4** (workshop rebuild). Sequencing and dependencies live in
[`knowledge/roadmap.md`](../roadmap.md); this file is the detail.

Source: an authored plan, reviewed and refined below. Six findings are called out
inline as **REVIEW** so the original intent stays visible next to what changed —
two blocking, one of them a credential leak.

REVIEW 4 also records a correction to *this document's own first
recommendation*, which was wrong in a way that would have deleted a user's
staging rehearsal. Kept rather than quietly edited: the reasoning is the useful
part.

**Currency pass 2026-08-21.** Three things this plan waited on have shipped, and
each is annotated where it is stated rather than only here: REVIEW 1's redaction
leak (#73) in **0.2.5**; the tidy checks (#77) in **0.2.6**; roadmap **S8**, and
with it REVIEW 7's method-annotation blocker, as **0.3.0** and spec `sdp-0.3.0`.
REVIEW 6's version arithmetic went stale as a result. Everything still open is
open for a reason stated at the point it appears — chiefly roadmap **S1**, and
the Python lane, which was at metasalmonpy 0.2.1 and demonstrated none of the
new behaviour. *(That last clause expired 2026-08-24: metasalmonpy released
**0.4.0**, mirroring `knb_environment` and the sdp-0.3.0 shape, so the Python
lane is no longer the constraint this paragraph treated it as.)* Nothing here
has been re-decided; only re-dated.

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

**There are two redactors, and both have the gap.** `.ms_knb_redact()`
(`R/knb-publication.R:1767`) is a separate implementation with the same
`dataone_token`-only pattern, and it is the one that handles KNB **adapter
errors and warnings** — precisely the path a live staging call takes. Verified:

```
.ms_knb_redact("dataone_token=SECRET")       -> dataone_token=[REDACTED]
.ms_knb_redact("dataone_test_token=SECRET")  -> dataone_test_token=SECRET   # leaks
```

Fixing only `.ms_redact_secrets()` would leave the new staging path exposed
while looking addressed.

**Do this first, in its own commit, before any staging code exists.** Extend
**both** patterns to cover qualified token names, assert the staging name in
`test-cli-safety.R` alongside the four provider variables already there **and**
in the KNB redaction tests, and consider whether the two redactors should
converge — two implementations of one security contract is how this gap arose.
Backlog **#73**.

**FIXED in 0.2.5** (recorded here 2026-08-21). The rule shipped **structural**
rather than enumerated — any qualified `*_token` name, so a credential
introduced later is covered without another patch, with `token` required as the
final name segment so provider diagnostics keep `max_token_count` and
`total_tokens` intact. And the parenthetical suggestion was taken all the way:
`.ms_knb_redact()` is **deleted**, not extended, with KNB messages routed
through the shared function — strictly stronger, since that one also catches
`x-api-key`, provider API keys, and serialized JSON credential forms the
narrow copy missed. Nothing in this review is outstanding; step 0 of the
sequencing table below is done, and **S3 has no remaining hard blocker**.

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

**Do not register it in `.ms_package_managed_paths()`** — my first
recommendation here was wrong, and the reason is worth keeping. That helper's
entries are *unlinked before the base writer runs*, and
`write_salmon_datapackage()` never recreates publication artifacts. Registering
`publication/staging/` there would delete a staging rehearsal on the next
ordinary metadata rewrite. It would also invert an existing documented contract:
`R/package-helpers.R:369` lists `publication/` among the sidecars the base
writer explicitly **preserves**. (Separately, the helper builds literal paths;
a `**` glob is not expanded.)

**Instead:** staging artifacts are owned by the *publication* writer, not the
package writer, so ownership belongs alongside `.ms_knb_sdp_artifact_paths()` —
the inventory that already answers "what does publication own". State that
`publication/staging/` is publication-writer-owned and preserved by the base
writer, and assert both halves: an ordinary `write_salmon_datapackage(overwrite
= TRUE)` leaves a staging rehearsal intact, and a staging re-plan replaces only
its own files.

### REVIEW 5 — "never accept custom endpoints" vs the test hook

`getOption("metasalmon.knb_adapter")` is how the suite injects a fake adapter and
asserts that a dry run never constructs a real one. The closed registry must
govern **endpoints and tokens**, not the adapter injection point. State that
distinction in the code comment, or a later reader will remove the hook in the
name of the rule and take the dry-run isolation tests with it.

### REVIEW 6 — version claim is stale (and so, since 2026-08-11, is this review)

The plan said "if parallel work has reached 0.3.0, this becomes the next 0.3.x".
*Answered 2026-08-11:* current version is **0.2.4**; `knb_environment` is
additive, so on its own it is **0.2.5**; it only becomes 0.3.0 if bundled with
S5 (#58 condition classes are breaking). Do not bundle for its own sake — S4
pins an exact released version, and a smaller release is easier to pin.

**Both numbers in that answer are now wrong (recorded 2026-08-21).** Current is
**0.3.0**, tagged `v0.3.0`, with `main`'s development version 107 commits past
it. And **0.2.5 shipped as something else**: the credential-redaction fix this
document's own REVIEW 1 called for (backlog #73) — qualified `*_token` names
redacted structurally, and the second redactor deleted. So the plan's original
sentence turned out to be the accurate one; parallel work did reach 0.3.0.

The *reasoning* survives, the arithmetic does not. `knb_environment` is still
additive, so sized against 0.3.0 it is the next patch, **0.3.1**. Whether to
bundle with S5 was never decided, then or now — it stays an open call, and the
advice against bundling for its own sake is advice, not a ruling.

*Worth generalising, because this document produced the same failure twice —
here, and in "smoke-test Python 0.1.6" under Verification and delivery:* a plan
that writes down a **current version number** has written a fact with a few
weeks' shelf life, and the number is the part a later reader acts on. The sizing
rule ("additive, therefore next patch") kept its value across four releases; the
number it produced did not survive one. Prefer recording the rule.

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

### Tidy data comes first — episode 1

**The SDP works on tidy tables and nothing else, and the workshop must say so
before anyone opens a file.** Today it does not, and the omission is expensive:
a learner arriving with a matrix, a multi-sheet pivot report, or a NetCDF spends
the session discovering the tool does not fit rather than learning what it does.

Place it in episode 1, before the four metadata CSVs are previewed, and keep it
short — three rules and one counter-example:

- Each **variable** is a column.
- Each **observation** is a row.
- Each **observational unit** is a table.

Then the counter-example that does the real work: a wide escapement sheet with a
column per year (`1998`, `1999`, `2000`…) beside the tidy long form of the same
data. Learners recognise their own files in the first one.

State the boundary plainly, as the plan already requires elsewhere: one flat
file, multiple CSVs, or rectangular tables from a workbook — **not** NetCDF,
rasters, nested arrays, or presentation-formatted sheets. Say *why* rather than
only *what*: the four metadata levels describe columns and rows, so a shape
without columns and rows has nothing to describe.

Two things to be honest about, because a learner will hit both:

1. **The package now checks part of this — demonstrate it rather than disclaim
   it.** *(Corrected 2026-08-21. This item read "the package does not currently
   check any of this (backlog #77)", which was true on 2026-08-11 and stopped
   being true when **0.2.6 shipped #77** as S8's first half.)* Be exact about
   which part, because over-claiming here is the same mistake the original
   caveat was guarding against:
   - A **declared `primary_key` is enforced, as an error.** Both a missing value
     in a key column and a duplicate key are reported. The check exists only
     when `tables.csv` declares a key *and* every declared component is present
     in the data — a table that declares no key is still unchecked, which is
     worth saying out loud.
   - **Wide-format column names are a warning, never an error**, deliberately:
     the SDP may accept untidy data, it should simply stop implying it checked.
     It fires on bare year-like names, or a shared stem with numeric suffixes,
     across three or more columns, and its message already points at
     `tidyr::pivot_longer()`.
   - Unresolved `MISSING METADATA:` placeholders are surfaced in the default
     validation mode as well; previously they were errors only under
     `require_iris = TRUE`, so an ordinary call said nothing while the package
     stated in its own metadata that its metadata was missing.

   The wide escapement counter-example above is precisely the input that trips
   the warning, so the episode can run it live: the teaching example and the
   demonstration are the same file, and the tool says the thing the instructor
   just said.
2. **Reshaping is real work.** Point at `tidyr::pivot_longer()` for R learners
   and the pandas equivalent for Python, in this episode rather than later.

**The caveat moves to the Python lane.** metasalmonpy writes `primaryKey` into
the descriptor but implements none of the three checks — they are S10 chunk
**D**, unstarted. An episode demonstrating the tidy checks demonstrates them in
**R only** until D lands, and Python learners must be told that at the shared
checkpoint rather than inferring from a quiet run that their package was clean.
*(This replaces the "cross-check when S8 lands" note, which is discharged.)*

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

### REVIEW 7 — three content dependencies to resolve before writing the episodes

- **Episode 8 teaches validation as the final gate before deposit.** Roadmap S1
  exists because that gate under-checks: three error-severity rules are never
  executed and the validator checks no primary keys, nullability, or
  schema-required fields. Either land S1 first, or scope the episode's claim to
  what the validator actually does. Do not teach the stronger claim.
- **"Copy the latest SDP template"** needs a canonical, versioned template with a
  stable URL. That is `smn-data-pkg`, which S1 also touches. Name the exact
  source and version in the episode, not "the latest". *(Half-resolved
  2026-08-21: the versioned source now exists — `smn-data-pkg` carries an
  annotated **`sdp-0.3.0`** tag beside `sdp-0.2.0` — so the episode has an exact
  version to name. What S1 still owes is the validation authority, not the
  template's identity.)*
- **Method annotation was blocked by roadmap S8. DISCHARGED — S8 shipped as
  metasalmon 0.3.0 against spec `sdp-0.3.0`** (2026-08-15; recorded here
  2026-08-21). The draft model this bullet anticipated is now the released one,
  and it landed the way the bullet predicted: `column_dictionary.method_iri` is
  gone. The dictionary instead carries **`statistical_modifier_iri`**, on the
  reasoning that a *mean* weight and a *maximum* weight are different variables
  while a method never was part of what a value **is**. That distinction is the
  teachable idea, and it is now safe to teach.

  A method has three settled placements the episode can name:
  `tables.csv` `method_iri` for a procedure shared by a whole table;
  `protocol_iri` / `protocol_citation` on `tables.csv` and `dataset.csv` for a
  cited protocol; and, for a method that varies row by row, a code column in the
  data resolving through `codes.csv` `term_iri` to a shared-vocabulary
  procedure. The `metadata/methods.csv` registry is removed.

  Two things the episode author should know rather than rediscover. Learners
  arriving with an sdp-0.2.0 package need `migrate_sdp_methods()`, which
  relocates what it can mechanically and stops on anything needing a judgement
  call — *whether the episode covers migration at all is a content decision, not
  one made here*. And the **Python lane cannot demonstrate any of this yet**:
  metasalmonpy is at 0.2.1, still vendors sdp-0.2.0, and its dictionary still
  has `method_iri`. That is S10 chunk A, unstarted, so the S10 card's rule —
  *S4 must not demo Python behaviour that has not landed* — binds this episode
  harder than any other. **Superseded 2026-08-24:** chunk A landed 2026-08-22
  and metasalmonpy released **0.4.0**, vendoring sdp-0.3.0 with
  `statistical_modifier_iri`, so the Python lane *can* demonstrate this now. The
  S10 rule still binds — it just no longer excludes this episode's content.

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
version; smoke-test the released metasalmonpy — **0.4.0 as of 2026-08-24**
(0.2.1 as of 2026-08-21, and the 0.1.6 this line originally named), now
sdp-0.3.0-shaped, **so record the version tested rather than restating a number
here — this line has already gone stale twice in three days**; validate Excel
template
headers; confirm the shared checkpoints. `sandpaper::check_lesson()` and
`sandpaper::build_lesson()`. Inspect learner, instructor, and all-in-one HTML
for complete paths, valid links, unique ids, and visible print content.

Update `config.yaml`, setup/reference/instructor guidance, README/index, links,
and the workshop's own `docs/entrypoints.md`. Preserve the untracked `.DS_Store`;
stage only intended files. Commit to `main`, let Pages rebuild, then verify the
live site and the key R / Python / Excel and KNB / EDH routes.

---

## Sequencing summary

| Step | Depends on | Gate |
|---|---|---|
| 0. ~~Fix `dataone_test_token` in **both** redactors (#73)~~ — **done, shipped in 0.2.5** (the second redactor was deleted rather than fixed) | — | met |
| 1. `knb_environment` API + registry | 0 | Enum, URL/token isolation |
| 2. Staging EML output path (REVIEW 2) | 1 | Production `metadata/eml.xml` byte-identical |
| 3. Manifest and overwrite gating (REVIEW 3) | 1 | Pre-existing production manifest validates |
| 4. Publication-writer ownership of `publication/staging/` (REVIEW 4) | 1 | Base-writer rewrite leaves a rehearsal intact |
| 5. Docs, version bump, release | 1–4 | `R CMD check` OK, pkgdown built |
| 6. Workshop rebuild | 5, and ideally S1 | `check_lesson()`, live site routes |
