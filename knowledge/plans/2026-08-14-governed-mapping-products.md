---
type: Artifact
title: "Governed FAIR mapping-product consumption"
description: "ExecPlan for paired R/Python verification, pinning, archival, and provenance of governed mapping products, reusing metasalmon's existing SSSOM implementation and keeping compatibility and application conditional."
status: draft
tags: [execplan, s6, mappings, fair, sssom, parity]
psc:
  id: metasalmon:plan:2026-08-14-governed-mapping-products
  contexts: [metasalmon:context:hub-coordination]
---

# Governed FAIR mapping-product consumption

This is a living ExecPlan. Keep `Progress`, `Surprises & Discoveries`,
`Decision Log`, and `Outcomes & Retrospective` current while the work proceeds.
It is the S6 consumer plan for `metasalmon` and `metasalmonpy`; it does not
authorize implementation or make either package a mapping publisher.

## Purpose / Big Picture

After this work, a Salmon Data Package workflow can consume a reviewed mapping
product from its owning semantic-asset repository, verify an immutable version
and checksum offline, archive the exact reviewed distributions, and record the
mapping-product provenance in the package. Development or CI can report whether
a newer release exists, but it cannot silently update a pin. A neutral link to
a compatibility record may be preserved without interpreting it.

The first proof reuses an identified-concept mapping product. The R package
already has strict SSSOM 1.1 behavior, so the new work is the FAIR product
envelope, immutable pin, validator dispatch, and provenance seam. The Python
mirror delivers the same user-visible behavior in the same stream. Predicate-
aware mapping application and consumer-compatibility evaluation are later,
separately approved contracts. A later NuSEDS migration is a separate,
authority-gated proof, not permission to externalize the current hard-coded
crosswalk now.

## Progress

- [x] (2026-08-14) Re-audit the current hub, S6/S8/S9/S10, recent releases,
  existing R SSSOM implementation, Python parity state, NuSEDS helpers, PSC
  alpha.3 artifact, and Brett HQ authority boundary.
- [x] (2026-08-14) Record the bounded consumer substream in the hub roadmap and
  S6 card without creating a competing sequence.
- [ ] Obtain Brett HQ implementation activation and a merged/reaffirmed
  program strategy; planning approval alone does not satisfy this gate.
- [ ] Consume a released PSC-1 mapping-product profile and fixture after PID-1
  is dispositioned in the PSC umbrella plan.
- [ ] Let S10 bring metasalmonpy through the existing SSSOM contract.
- [ ] Implement and release paired R/Python verification, pinning, archival,
  and provenance behavior with exact parity evidence.
- [ ] Reassess qualified compatibility only after COMPAT-1 and PSC-4; reassess
  mapping application only after a predicate-aware contract and use case are
  approved. Neither follow-on is activated by this plan.
- [ ] Reassess a source-owned NuSEDS mapping product after its authority and
  source gates are met; gate only the later package migration on S8 and parity.

## Surprises & Discoveries

- `R/sssom.R` already reads, validates, and writes a strict SSSOM 1.1 profile,
  produces deterministic canonical bytes and checksum-bound manifests, and
  rejects raw literal assignments and ordered decompositions. Reimplementing
  SSSOM would add drift rather than capability.
- The planning authority moved from `notes/` into this `knowledge/` OKF hub on
  2026-08-13. `knowledge/roadmap.md` remains the six-repository technical
  sequence and release index; this plan is a child of S6.
- The same-stream mirror rule makes a new R-only consumer invalid. Python is at
  0.1.6 parity and lacks SSSOM, so S10 is a hard implementation prerequisite.
- S9 completed the generic method-model ontology work: SMN 0.0.3, the
  gcdfo-to-SMN SSSOM set, and ten provisional PSC-to-SMN broad mappings exist.
  Nine PSC analytical-method concepts remain unmatched.
- S8's model and spec are decided, but its R implementation is still being
  reconciled and Python delivery rides S10. Generic mapping consumption does
  not depend on S8; NuSEDS method migration does.
- The PSC alpha.3 SSSOM header includes mapping-set ID/version, licence, and
  subject/object source IDs and versions, but omits `sssom_version: 1.1`.
  `read_sssom_mapping_set()` in metasalmon 0.2.6 at commit `5825467` therefore
  rejects it before row validation. The immutable-shaped artifact is evidence
  for PSC-1, not a fixture to patch in place.
- The same integration branch removes the public alpha.2 CAMP Adapter route
  still pinned by `campModelInput`, and PSC-CV-000017's SMN rationale claims an
  exact-match composition although its gcdfo predicate is `closeMatch`. PSC-0A
  must repair, supersede, or split those publisher-side defects before the
  umbrella MR deploys; a consumer must not normalize them.

## Decision Log

- **2026-08-14 — Reuse SSSOM; add a product envelope.** Identified concept
  mappings dispatch to the existing R SSSOM functions. Raw literal assignments,
  conditional roll-ups, and decompositions retain truthful typed formats.
- **2026-08-14 — Preserve semantic authority outside the packages.**
  `metasalmon` may generate candidates, validate, pin, archive, and record
  provenance. It does not approve or publish production mapping decisions.
- **2026-08-14 — Pair all new R/Python behavior.** META-1 is one product node
  delivered by coordinated R and Python PRs after S10 reaches SSSOM parity.
  Version equality remains a parity claim.
- **2026-08-14 — Keep generic consumption independent of S8.** S8 is a method-
  placement concern, not a prerequisite for reading a generic governed product.
  The NuSEDS follow-on remains gated by reconciled S8 delivery.
- **2026-08-14 — Separate verification from application and compatibility.**
  SSSOM parsing does not define how `broadMatch`, direction, cardinality,
  multiple targets, or gaps should transform data. META-1R/PY therefore stops
  at verification and provenance. It preserves, but does not evaluate, neutral
  compatibility links; missing evidence never becomes an inferred
  `compatible` state or an automatic pin update.

## Outcomes & Retrospective

Planning outcome only as of 2026-08-14: the current capabilities and dependency
gates are reconciled, and no package behavior, mapping product, release, or
NuSEDS authority has changed. At implementation close-out, replace this text
with the R and Python PRs/releases, product/profile versions, fixture hashes,
parity evidence, user-visible behavior, unresolved gaps, and whether the
contract earned a second producer.

## Context and Orientation

The authoritative program and repository roles are deliberately separate:

- Brett HQ's Semantic PSC Data System Roadmap owns program strategy and
  activation.
- PSC draft GitLab
  [MR !5](https://gitlab.com/pacific-salmon-commission/psc-data-systems/psc-salmon-vocabularies/-/merge_requests/5)
  is the current mapping-product dependency specification. A later PSC-1
  release owns the reusable product profile and first strict-reader-valid
  fixture.
- This OKF hub owns technical sequencing, the mirror obligation, and the
  cross-repository release index. It is not a semantic-asset registry.
- The source or vocabulary owner publishes mapping products and their review
  decisions. A consumer package verifies, archives, and records only the pinned
  product until a separate application contract is approved.
- Brett coordinates identification of the competent domain and application
  authorities, but that coordination is not their scientific approval.

Relevant current code and contracts:

- `R/sssom.R` provides strict SSSOM 1.1 read, validate, write, canonical-byte,
  hash, row-count, source-version, and `mapping-sets.json` behavior.
- `R/reproducibility-manifest.R` and KNB publication provide patterns for a
  closed checksum-bound inventory. They are consumer provenance mechanisms,
  not the public mapping registry.
- `R/nuseds-method-crosswalk.R` exposes two compatibility-sensitive functions
  backed by hard-coded data that conflates source literals, roll-ups, ontology
  targets, interpretations, and notes. Preserve those signatures in any later
  migration.
- S10 records that metasalmonpy lacks the R package's SSSOM subsystem. It must
  reach that parity milestone before new mapping-product behavior is added.

### Local glossary for cross-repository gates

- **PSC-0A:** the pre-merge reconciliation of alpha.3 Adapter persistence,
  mapping provenance, and strict-SSSOM defects.
- **PID-1:** the PSC umbrella decision on product and version identifier shape.
- **PSC-1:** the PSC publishing-kernel MR that releases the common metadata
  profile, validator, immutable fixture, lifecycle, checksums, and neutral link
  extension. It does not define compatibility semantics.
- **COMPAT-1 / PSC-4:** the later decision and publisher MR that define and
  publish qualified consumer-compatibility assertions.
- **S10:** the metasalmonpy parity stream, including the existing R SSSOM
  contract before META-1R/PY starts.
- **NUSED-0:** the future decision naming NuSEDS source identity, licensing,
  publication home, authority, correction route, and HQ activation.

### Proposed implementation surface

The released PSC-1 field names replace the placeholders below before coding;
any changed function signature is recorded in this plan's Decision Log.

| Repository | File or fixture | Proposed responsibility |
| --- | --- | --- |
| `metasalmon` | `R/mapping-products.R` | Export `read_mapping_product(path, pin = NULL)`, `verify_mapping_product(product, pin = NULL)`, and `check_mapping_product_freshness(pin, index)`; return `ms_mapping_product` and `ms_mapping_product_verification` objects without applying rows. |
| `metasalmon` | `tests/testthat/test-mapping-products.R` | Envelope, checksum, lifecycle, offline, unsupported-type, SSSOM-validator dispatch, and freshness tests. |
| `metasalmon` | `R/reproducibility-manifest.R` and its existing tests | Add a checksum-bound mapping-product provenance record to the closed SDP inventory. |
| `metasalmonpy` | `mapping_products.py` | Mirror `read_mapping_product()`, `verify_mapping_product()`, and `check_mapping_product_freshness()` with equivalent dictionaries/dataclasses and diagnostics. |
| `metasalmonpy` | `tests/test_mapping_products.py` and `tests/test_public_api.py` | Mirror the R fixtures, states, public exports, and failure behavior. |
| both | repository-local mapping-product fixture directories | Vendor byte-identical PSC-1 metadata, pin, and distributions plus one-byte-tampered negative fixtures; compare their recorded SHA-256 values in the parity matrix. |

The language-neutral verification record has these canonical fields:
`product_id`, `product_version_id`, `profile_id`, `lifecycle_status`,
`pin_id`, `distribution_id`, `media_type`, `sha256`, `source_versions`,
`target_versions`, `validator_profile`, `valid`, and ordered `diagnostics`.
Volatile observation time belongs to the surrounding provenance event, not the
canonical verification result. A compatibility link may be carried as
uninterpreted source metadata, but no `compatible` value appears until the
later contract exists.

## Scope and Non-goals

In scope for META-1R/PY:

- validate a versioned FAIR mapping-product metadata envelope;
- resolve only local files or an explicit immutable cached distribution at
  runtime;
- verify product/version identity, distribution checksum, source/target pins,
  lifecycle, and supported representation/profile;
- preserve an uninterpreted compatibility-record link separately from product
  lifecycle;
- dispatch an identified-concept SSSOM distribution to the existing strict R
  reader/validator and its S10 Python mirror;
- expose a typed verification result that preserves unsupported product types
  rather than guessing;
- record exact product IDs, versions, hashes, lifecycle, validator profile, and
  verification evidence in SDP provenance; and
- provide a read-only development/CI freshness report.

Out of scope:

- hosting or approving mappings in either package;
- forcing literals, ordered decompositions, or conditional many-input rules
  into SSSOM;
- network access during normal package execution;
- automatic upgrades or edits to a vendored pin;
- changing CAMP operational outcomes or numerical CV policy;
- resolving PID-1 or COMPAT-1 before the PSC owner decides them;
- evaluating compatibility assertions before COMPAT-1 and PSC-4;
- applying SSSOM predicates or other mapping rows to source data before a
  mapping-type-specific execution contract defines direction, cardinality,
  multiple targets, gaps, and admissible predicates;
- publishing NuSEDS source identifiers or mapping assertions on its behalf;
  and
- expanding the PSC data-systems ontology or creating a mapping database.

## Dependency and Change-request Stack

Cross-repository PRs cannot literally nest. Each PR targets its repository's
default branch and links the immutable predecessor it consumes.

```text
HQ strategy merge/reaffirmation + explicit implementation activation
                |
PSC PLAN-0 merge + PID-1
                |
PSC-1 released profile + strict-reader-valid immutable fixture
                |                                      S10 SSSOM parity
                +---------------------------------------------+
                                                              |
                                             META-1R + META-1PY paired PRs
                                                              |
                                             paired release + provenance proof

COMPAT-1 + PSC-4 --------------------> future compatibility-evaluation plan
approved predicate-aware use case ---> future mapping-application plan

NUSED-0 authority/source decision + truthful targets or explicit gaps
                |
future source-owned mapping product
                |
META-1R/PY release + reconciled S8 R/Python delivery
                |
future META-2R/PY migration plan
```

META-0 is this planning PR. It changes only the hub roadmap, S6 sequence card,
and this ExecPlan. It does not satisfy any implementation dependency.

## Plan of Work

### 1. Freeze the upstream product contract

After PSC-1 releases, record its product profile version, product/version PID
rules, metadata schema, distribution profiles, checksum algorithm, lifecycle
states, neutral extension rule, and one immutable fixture. Verify that the
fixture is valid with the publisher tool and the strict SSSOM consumer. Do not
build against an unmerged sibling branch or repair the fixture locally.

Acceptance: the handoff record names an immutable product version and hash;
PID-1 is dispositioned; both packages can use the same fixture; and a malformed
or incomplete copy fails deterministically. Compatibility remains unevaluated.

### 2. Establish the paired consumer contract test-first

In both packages, write equivalent behavior tests for valid, tampered,
withdrawn, unsupported-type, offline, and newer-release cases. Define one
language-neutral result model for product identity, verified distributions,
lifecycle, diagnostics, and provenance. A neutral compatibility link is data,
not a computed status. Language-specific object classes may differ, but
observable states and canonical values do not.

Acceptance: the two suites use byte-identical fixtures and assert an explicit
parity matrix before production behavior is added.

### 3. Implement envelope, pin, and validator dispatch

Implement the smallest reader/verifier around local product metadata and its
pinned distributions. Keep network resolution in an explicit freshness command
outside normal package execution. In R, dispatch SSSOM to
`read_sssom_mapping_set()` for strict parsing and validation; mirror that
contract in Python as part of S10/META-1PY. Reject an envelope whose claimed
type and distribution profile disagree. Return verified rows only as data;
never execute their predicates in this stream.

Acceptance: unchanged inputs yield identical verification and provenance
records under C collation; tampering fails before a distribution is accepted;
absence of a network never substitutes another release; and unsupported
mapping types return a typed refusal rather than partial parsing.

### 4. Bind provenance into SDP and publication paths

Extend the reproducibility inventory with exact mapping-product and version
PIDs, distribution hashes, source/target versions, lifecycle, validator
profile, verification result, consumer version, and any uninterpreted
compatibility link. Preserve the closed-manifest rule: KNB publication includes
only files named by the validated inventory. Do not treat a manifest entry as
mapping approval or evidence that any row was applied.

Acceptance: an SDP and its publication plan can prove exactly which immutable
mapping inputs were used in both languages, and read-back validation detects a
changed or missing mapping distribution.

### 5. Document, release, and close parity together

Add user documentation showing offline pinning, explicit freshness checks,
unsupported-type refusal, unevaluated compatibility links, and provenance. Add
NEWS/changelog entries in both repositories. Release numbers move together only
when the parity matrix, package tests, build/checks, and cross-language fixture
tests all pass.

Acceptance: neither release claims parity before both implementations land;
the hub release index records both versions and exact PRs; and this plan's
retrospective records any intentional language difference.

### 6. Reassess, but do not auto-start, the NuSEDS follow-on

First check NUSED-0, source licensing and identifier model, governing authority,
correction route, publication home, and truthful target or explicit-gap
coverage. Those conditions govern whether the source owner may publish a
mapping product; application-package readiness does not. Separately, gate a
future META-2R/PY consumer migration on META-1R/PY plus the reconciled S8 R and
Python delivery. If the appropriate gates are satisfied and Brett HQ activates
the consumer work, write a new dated META-2R/PY ExecPlan. Otherwise leave the
hard-coded functions in place and record the specific blocker; do not transform
this plan into producer authority.

## Concrete Steps

Planning validation from the `metasalmon` repository root:

```sh
git diff --check
uv run --project ../psc-data-systems psc-okf check knowledge --tier capture
```

Before META-1 implementation, capture a clean baseline from the `metasalmon`
repository root:

```sh
Rscript -e 'devtools::test(reporter = "summary")'
R CMD build .
R CMD check metasalmon_*.tar.gz
```

Then capture the Python baseline from the sibling `metasalmonpy` repository:

```sh
(
  cd ../metasalmonpy
  uv run --with pytest --with pandas --with requests -- python -m pytest tests/ -q
  uv run --with pytest --with pandas --with requests -- python tests/smoke.py
)
```

The planning audit already captured the current PSC strict-profile diagnostic
from PSC integration commit `006763f1a63d762ca5895177c132c2d10969fb0d` and
recorded the file checksum in `Surprises & Discoveries`. It is not an
implementation dependency. To reproduce it without trusting whichever PSC
branch happens to be checked out, return to the `metasalmon` root, extract the
exact Git object from the sibling repository into a temporary file, verify its
checksum, and run the strict reader from the still-current `metasalmon` root:

```sh
psc_diag_file="$(mktemp -t psc-alpha3-sssom.XXXXXX)"
trap 'rm -f "$psc_diag_file"' EXIT
git -C ../psc-salmon-vocabularies show 006763f1a63d762ca5895177c132c2d10969fb0d:releases/v0.1.0-alpha.3/mappings/psc-to-smn.sssom.tsv > "$psc_diag_file"
printf '%s  %s\n' 2c0d80a2275a81809036ce85bc9519d76d6ec6096879e739157125558abbc72d "$psc_diag_file" | shasum -a 256 -c -
Rscript -e 'pkgload::load_all(".", quiet = TRUE); read_sssom_mapping_set(commandArgs(trailingOnly = TRUE)[[1]])' "$psc_diag_file"
```

The expected pre-PSC-1 result is a failure naming the missing required
`sssom_version` field. Once PSC-1 exists, replace the path in the implementation
plan with the immutable fixture PID/cache path and record its checksum. Do not
edit alpha.3 to make this command pass. If the exact Git object is unavailable,
record that preservation failure and stop; never substitute a moving branch.

During implementation, use focused tests first, then both complete suites.
Every behavior-changing commit includes its R and Python parity evidence or an
already-reviewed exception recorded in this hub.

## Validation and Acceptance

META-0 planning acceptance:

- the OKF capture-tier check and `git diff --check` pass;
- this hub, Brett HQ, and PSC MR !5 have non-competing authority statements;
- the plan reuses existing R SSSOM behavior and does not activate NuSEDS; and
- S8, S9, and S10 dependencies match the current repository evidence.

META-1R/PY implementation acceptance:

- both full suites and package build/checks pass;
- the parity matrix covers every public state and canonical fixture;
- canonical bytes and hashes remain C-collated and deterministic;
- runtime remains offline and freshness checks are read-only;
- tampered, withdrawn, unsupported, or missing inputs fail closed with safe
  diagnostics;
- no raw literal or ordered decomposition is accepted as SSSOM;
- SDP provenance and KNB read-back retain exact product/version/hash evidence;
  and
- technical validation, mapping review, product lifecycle, compatibility, and
  application outcome remain separate dimensions; META-1R/PY computes only the
  technical-verification and product-lifecycle dimensions.

## Idempotence and Recovery

Readers, validators, and freshness checks are side-effect free. Re-running them
over the same bytes produces the same result and provenance. Vendoring a pin is
an explicit reviewed repository change; no command overwrites it automatically.

If a released mapping product is defective, preserve its metadata and checksum,
mark it withdrawn through the owning repository, publish a replacement version,
and let consumers review a semantic diff before updating. Never rewrite an
immutable fixture or fall back to a moving alias. Network failure yields
`unknown` freshness while the last reviewed offline pin remains unchanged.

Use clean worktrees for paired implementation. Do not remove a worktree or
branch until it is clean, its PR is resolved, and it has no unique work. The
unfinished S8 branch is independent and must be reconciled by its owner rather
than overwritten by this stream.
