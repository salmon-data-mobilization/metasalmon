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
- [x] (2026-08-15) Re-audit the remote dependencies: S8 R implementation PR
  #39 **merged at `5a37b11`** (metasalmon 0.3.0 on main; that merge is the only
  valid port baseline — `f76ed4f` was review round one of five and omits the
  role-hint, rollback, placement-validation, ordering, and method-promotion
  fixes); the `sdp-0.3.0` tag exists; Python remains 0.1.6; SMN 0.0.3 is released; the
  gcdfo S9 merge is unreleased; and PSC alpha.3 remains unmerged in nested draft
  MR !8 targeting draft MR !5.
- [x] (2026-08-15) Record the six-repository allowlist and typed external-edge
  rule, plus the accepted PID-1 and COMPAT-1 decisions.
- [x] (2026-08-15) Reconcile the hub after PSC-0A implementation: nested draft
  MR !8 at `a2ca4ee` is strict-reader-valid with nine accepted SMN rows and one
  deferred proposal, but remains unmerged and unreleased and therefore does not
  satisfy PSC-1 or activate a consumer child.
- [ ] Immediately before implementation, verify the attributable activation
  gate in its owning Brett HQ plan; do not mirror HQ approval or task status
  into this plan.
- [ ] Consume a released PSC-1 mapping-product profile and fixture using the
  accepted readable stable product slugs under `/mappings/`.
- [ ] Let S10 bring metasalmonpy through the complete current released R
  baseline (at least 0.3.0 if PR #39 merges and releases first), not only the
  existing SSSOM contract.
- [ ] Implement and release paired R/Python verification, pinning, archival,
  and provenance behavior with exact parity evidence.
- [ ] Reassess qualified compatibility only after PSC-4 publishes the accepted
  COMPAT-1 shape and a separate consumer plan is activated; reassess mapping
  application only after a predicate-aware contract and use case are approved.
  Neither follow-on is activated by this plan.
- [ ] Reassess a source-owned NuSEDS mapping product after its authority and
  source gates are met; gate only the later package migration on PR #39
  merge/release and replay of that R baseline in Python.

## Surprises & Discoveries

- `R/sssom.R` already reads, validates, and writes a strict SSSOM 1.1 profile,
  produces deterministic canonical bytes and checksum-bound manifests, and
  rejects raw literal assignments and ordered decompositions. Reimplementing
  SSSOM would add drift rather than capability.
- The planning authority moved from `notes/` into this `knowledge/` OKF hub on
  2026-08-13. `knowledge/roadmap.md` remains the six-repository technical
  sequence and release index; its domain table is an allowlist, and this plan is
  a child of S6.
- The same-stream mirror rule makes a new R-only consumer invalid. Python is at
  0.1.6 parity and lacks SSSOM. S10 is a hard implementation prerequisite and
  must replay the whole current released R baseline; a selective SSSOM port
  would leave the package's version claim false.
- S9's assets have different publication states: SMN 0.0.3 is released; gcdfo
  PR #78 is merged but its boundary work is unreleased; and reconciled alpha.3
  has nine provisional PSC-to-SMN broad mappings plus one deferred proposal in
  nested draft MR !8. Nine PSC analytical-method concepts remain unmatched.
- S8's model and specification are decided and its R 0.3.0 implementation
  **merged 2026-08-15** (PR #39, merge `5a37b11`); Python remains 0.1.6.
  Generic mapping consumption has no semantic dependency on S8. The NuSEDS
  migration now waits only on S10 replaying 0.3.0 in Python.
- The remote `sdp-0.3.0` annotated tag exists, although no corresponding GitHub
  Release object exists. The hub must distinguish an immutable spec tag from a
  package release and from S8's still-open R implementation.
- PSC integration commit `006763f` preserves the original strict-reader
  failure as predecessor evidence. Nested draft MR !8 legitimately repairs the
  unpublished candidate at `a2ca4ee`: SSSOM 1.1, PSC mapping-set licensing,
  per-relationship dates, protected Adapter routes, and truthful deferral of
  PSC-CV-000017. The reconciled nine-row set passes the exact metasalmon 0.2.6
  reader. A consumer still must not normalize publisher defects or treat this
  unmerged candidate as the released PSC-1 fixture.

## Decision Log

- **2026-08-14 — Reuse SSSOM; add a product envelope.** Identified concept
  mappings dispatch to the existing R SSSOM functions. Raw literal assignments,
  conditional roll-ups, and decompositions retain truthful typed formats.
- **2026-08-14 — Preserve semantic authority outside the packages.**
  `metasalmon` may generate candidates, validate, pin, archive, and record
  provenance. It does not approve or publish production mapping decisions.
- **2026-08-14 — Pair all new R/Python behavior.** META-1 is one product node
  delivered by coordinated R and Python PRs after S10 reaches full parity
  through the current released R baseline. Version equality remains a parity
  claim; SSSOM-only catch-up is insufficient.
- **2026-08-14 — Keep generic consumption independent of S8.** S8 is a method-
  placement concern, not a prerequisite for reading a generic governed product.
  The NuSEDS follow-on remains gated by PR #39 merge/release and replay of that
  method-model baseline in Python.
- **2026-08-14 — Separate verification from application and compatibility.**
  SSSOM parsing does not define how `broadMatch`, direction, cardinality,
  multiple targets, or gaps should transform data. META-1R/PY therefore stops
  at verification and provenance. It preserves, but does not evaluate, neutral
  compatibility links; missing evidence never becomes an inferred
  `compatible` state or an automatic pin update.
- **2026-08-15 — Bound the hub to an explicit allowlist.** The six repositories
  in `knowledge/domains/salmon-data-ecosystem.md` are the complete coordinated
  domain. Shared tools, links, consumed artifacts, and transitive dependencies
  do not add members. External repositories appear only in the roadmap's typed
  dependency ledger; their owning plans retain tasks, status, branches,
  approvals, and release history.
- **2026-08-17 — The allowlist is seven, not six (Brett).**
  `salmon-knowledge-commons` joined as a member node. This supersedes the count
  in the entry above and every present-tense "six repositories" statement
  elsewhere in this dated execplan; the 2026-08-15 text is left standing
  because it records what was decided then, and rewriting it would make this
  plan a worse record without making it a better one. The live count is in
  `knowledge/domains/salmon-data-ecosystem.md` and the roadmap's domain-
  allowlist rule — read those, not this plan, for membership. The reasoning is
  the part that generalizes: the commons is a member because its ontology gap
  register feeds this package's own term-request pipeline, so it is upstream
  work this hub sequences rather than an artifact this hub consumes. Shared
  ownership of a GitHub organization was **not** the reason and does not confer
  membership. Nothing else in META-0 changes: the allowlist mechanism, the
  typed external-edge ledger, and the authority boundaries all hold as written.
- **2026-08-24 — The allowlist is eight, and the membership test changed
  (Brett).** `salmon-data-standards-workshop` joined as the eighth member, and
  the governing test is now *this hub sequences that repository's work* — the
  "output is an input to this pipeline" test used in the entry above was deleted
  in the same change. This entry is added rather than rewriting the two above
  it, for the reason the 2026-08-17 entry already states: a dated plan records
  what was decided when. **Read the domain card and the roadmap's
  domain-allowlist rule for membership, never this plan** — that instruction is
  now load-bearing twice over, because the 2026-08-17 entry's *reasoning* (the
  commons feeds the term-request pipeline) is stated in a test that no longer
  governs. The commons is still a member; the domain card restates why in
  sequencing terms.
- **2026-08-15 — Resolve PID-1 with readable product slugs.** Stable mapping-
  product identifiers use readable slugs below `/mappings/`; versions remain
  immutable and separately identifiable. These identify datasets, not PSC
  concepts.
- **2026-08-15 — Resolve COMPAT-1 with separated assertions and acceptance.** A
  publisher may make a qualified expected-compatibility assertion, but each
  consumer independently verifies and accepts or rejects it. Missing or expired
  evidence remains `unknown`. META-1 preserves the assertion link only; it does
  not evaluate compatibility.
- **2026-08-15 — Rebase gates on current delivery evidence.** PR #39 is green
  but open and unreleased, the SDP 0.3.0 tag exists, and Python remains 0.1.6.
  META-1 therefore waits for S10 full parity through the released R baseline at
  implementation time. NuSEDS additionally waits for PR #39 merge/release and
  Python replay; generic META-1 remains semantically independent of S8.

## Outcomes & Retrospective

Planning outcome only as of 2026-08-15: the current capabilities and dependency
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
  release index for exactly the six repositories in its domain-card allowlist.
  It is not a semantic-asset registry. Shared tools, links, consumed artifacts,
  and transitive dependencies do not expand that jurisdiction.
- The source or vocabulary owner publishes mapping products and their review
  decisions. A consumer package verifies, archives, and records only the pinned
  product until a separate application contract is approved.
- Brett coordinates identification of the competent domain and application
  authorities, but that coordination is not their scientific approval.

The [roadmap's external dependency ledger](../roadmap.md#cross-program-authority-boundary)
is incorporated here by reference. It names the owner, required artifact or
gate, owning plan, and observation date for `psc-data-systems`,
`psc-data-systems-site`, `campModelInput`, and `ctc-knowledge-map`. Mentions of
those repositories below describe only an artifact or gate consumed by this
plan; their tasks, status, branches, approvals, and releases remain in their
owning plans.

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
- S10 records that metasalmonpy remains at 0.1.6. It must replay the complete
  current released R baseline before new mapping-product behavior is added; an
  SSSOM-only port is not sufficient parity.

### Local glossary for cross-repository gates

- **PSC-0A:** the pre-merge reconciliation of alpha.3 Adapter persistence,
  mapping provenance, and strict-SSSOM defects. Implemented in nested draft PSC
  MR !8 at `a2ca4ee`; review/merge remains a PLAN-0 deployment gate.
- **PID-1:** accepted 2026-08-15: product identifiers use readable stable slugs
  below `/mappings/`; immutable product-version identifiers remain distinct.
- **PSC-1:** the PSC publishing-kernel MR that releases the common metadata
  profile, validator, immutable fixture, lifecycle, checksums, and neutral link
  extension. It does not define compatibility semantics.
- **COMPAT-1 / PSC-4:** COMPAT-1 was accepted 2026-08-15: the publisher may
  assert expected compatibility and each consumer independently verifies and
  accepts or rejects it. PSC-4 later publishes the qualified records; META-1
  does not evaluate them.
- **S10:** the metasalmonpy parity stream. Before META-1R/PY starts it must
  replay the complete released R baseline through at least 0.3.0 if PR #39 has
  shipped, not only the existing R SSSOM contract.
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
- evaluating compatibility assertions in META-1. COMPAT-1 settled who may
  assert and who must verify, but PSC-4 must publish the qualified-record schema
  and a separate compatibility-consumer plan must be activated first;
- minting, redirecting, or governing the publisher-owned readable
  `/mappings/` product identifiers;
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
Attributable implementation activation in the owning HQ plan
                |
PSC PLAN-0 merge (PID-1: readable /mappings/ product slugs)
                |
PSC-1 released profile + strict-reader-valid immutable fixture
                |                  S10 full parity through the
                |                  current released R baseline
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
META-1R/PY release + PR #39 merge/release + Python replay
                |
future META-2R/PY migration plan
```

META-0 is this planning PR. It changes only the hub domain card and roadmap, S6
sequence card, and this ExecPlan. It does not satisfy any implementation
dependency.

## Plan of Work

### 1. Freeze the upstream product contract

After PSC-1 releases, record its product profile version, accepted readable
`/mappings/` product PID and immutable version-PID rules, metadata schema,
distribution profiles, checksum algorithm, lifecycle states, neutral extension
rule, and one immutable fixture. Verify that the fixture is valid with the
publisher tool and the strict SSSOM consumer. Do not build against an unmerged
sibling branch or repair the fixture locally.

Acceptance: the handoff record names the readable product PID, an immutable
product-version PID, and a distribution hash; both packages can use the same
fixture; and a malformed or incomplete copy fails deterministically.
Compatibility remains unevaluated.

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
after S10 has replayed the complete current released R baseline and the parity
matrix, package tests, build/checks, and cross-language fixture tests all pass.

Acceptance: neither release claims parity before both implementations land;
the hub release index records both versions and exact PRs; and this plan's
retrospective records any intentional language difference.

### 6. Reassess, but do not auto-start, the NuSEDS follow-on

First check NUSED-0, source licensing and identifier model, governing authority,
correction route, publication home, and truthful target or explicit-gap
coverage. Those conditions govern whether the source owner may publish a
mapping product; application-package readiness does not. Separately, gate a
future META-2R/PY consumer migration on META-1R/PY, PR #39 being merged and
released as the R method-model baseline, and S10 having replayed that release in
Python. If the appropriate gates are satisfied and the owning HQ plan activates
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

The planning audit captured the predecessor PSC strict-profile diagnostic
from PSC integration commit `006763f1a63d762ca5895177c132c2d10969fb0d` and
recorded the file checksum in `Surprises & Discoveries`. It remains negative
regression evidence and is not an implementation dependency. To reproduce it
without trusting whichever PSC
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

The expected predecessor result is a failure naming the missing required
`sssom_version` field. PSC-0A then provides a bounded positive interoperability
check at immutable implementation commit `a2ca4ee` without making that draft
candidate a consumer dependency:

```sh
git -C ../psc-salmon-vocabularies show a2ca4eededd1cf380f2f1ef1f7a6927ec540d7a9:releases/v0.1.0-alpha.3/mappings/psc-to-smn.sssom.tsv > "$psc_diag_file"
printf '%s  %s\n' 976c1ac6fc059275bd8c3d27c39afb07d5670165ce87e1bb19893fffb2eb59cc "$psc_diag_file" | shasum -a 256 -c -
Rscript -e 'pkgload::load_all(".", quiet = TRUE); x <- read_sssom_mapping_set(commandArgs(trailingOnly = TRUE)[[1]]); stopifnot(identical(x$metadata$sssom_version, "1.1"), identical(x$metadata$license, "https://creativecommons.org/licenses/by/4.0/"), nrow(x$mappings) == 9L)' "$psc_diag_file"
```

Once PSC-1 exists, replace this candidate object with the immutable released
fixture PID/cache path and record its checksum. If either exact Git object is
unavailable, record that preservation failure and stop; never substitute a
moving branch.

During implementation, use focused tests first, then both complete suites.
Every behavior-changing commit includes its R and Python parity evidence or an
already-reviewed exception recorded in this hub.

## Validation and Acceptance

META-0 planning acceptance:

- the OKF capture-tier check and `git diff --check` pass;
- this hub, Brett HQ, and PSC MR !5 have non-competing authority statements;
- the six-repository domain is an explicit allowlist and every external
  repository reference is governed by the typed dependency ledger;
- the plan reuses existing R SSSOM behavior and does not activate NuSEDS;
- PID-1 and COMPAT-1 are recorded without making META-1 a compatibility
  evaluator; and
- S8, S9, S10, SDP-tag, and R/Python release states match the 2026-08-15
  repository evidence.

META-1R/PY implementation acceptance:

- both full suites and package build/checks pass;
- S10 has replayed the complete released R baseline current at implementation,
  not only the SSSOM subsystem;
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
branch until it is clean, its PR is resolved, and it has no unique work. S8's
PR #39 was independent of this stream and merged on 2026-08-15.
