---
type: InformationObject
title: "S13 — Fraser Recruits case-study requirements"
description: "What metasalmon owes its one real production consumer: a supported API for the eight internals it reaches via :::, a migration path off sdp-0.2.0 and 0.1.8, and IRI-dereference verification. The live KNB series is unresolved."
status: draft
tags: [requirements, knb, publication, external-consumer]
psc:
  id: metasalmon:sequence:s13-fraser-recruits-case-study
  contexts: [metasalmon:context:hub-coordination]
---

# S13 — Fraser Recruits case-study requirements

**Execplan:** to be written. Evidence: the recipe's own committed sources and
operation records, read 2026-08-21.

**This stream is about metasalmon, not about that repository.**
`psc-data-transformations` is a **typed external edge — a requirements-driving
consumer — and not a member of this hub**; its tasks, priorities, branches,
approvals, receipts and lifecycle stay in its own plan and never enter this
roadmap or release index. What belongs here is the other direction: the
*requirements it drives into this package*, which are durable, unrecorded
anywhere else, and larger than an edge row can carry. The
[roadmap edge row](../roadmap.md#cross-program-authority-boundary) stays a
one-line typed edge; the substance is this card.

The recipe is `fraser-sockeye-stock-recruit-detailed` — the Fraser sockeye
stock-recruit case study, "Fraser Recruits" in conversation. It is the only
place anything built by this package has been deposited to a live repository.

## Requirement 1 — a supported API for eight internals

The recipe calls **eight `metasalmon:::` internals**:

| Internal | What it needs it for |
|---|---|
| `.smn_module_urls()` | enumerating the smn module sources it pins |
| `.smn_cache_slug()` | naming the cached snapshot deterministically |
| `.ms_eml_canonical_measurement_iris()` | the expected vocabulary IRI set |
| `.ms_eml_vocabulary_snapshot_sha256()` | binding that vocabulary by checksum |
| `.ms_sdp_profile_version()` | stamping the profile version it built against |
| `.ms_eml_validate_mapping()` | validating its EML sidecar |
| `.ms_eml_read_semantic_review()` | reading the reviewed-selection ledger |
| `.ms_eml_read_vocabulary()` | reading the bound vocabulary |

`:::` is not a supported interface, and this is not an unusual consumer being
clever: every one of the eight is a *provenance* operation — pin a vocabulary,
checksum it, prove the EML sidecar binds it. That is exactly what the SDP
publication story claims to be for, and none of it is exported. The requirement
is therefore not "stop using `:::`" but **decide which of these eight are public
API and export them**, or state why each stays private and what the supported
alternative is.

Until then the constraint runs the other way: those eight names cannot be
renamed or have their signatures changed without breaking a live consumer that
has already published with them. That is a real compatibility obligation on
this package, and nothing in `R/` says so.

## Requirement 2 — a migration path off sdp-0.2.0 and metasalmon 0.1.8

`recipe.yml` pins engine `metasalmon` **0.1.8** at revision
`886e01d60d45bc3e60d0906ee50e328ddde1a5bd`, and its published artifacts carry
the **sdp-0.2.0** era. Current metasalmon is **0.3.0**, two breaking releases
later (0.2.4's empty-field missing-value token; 0.3.0's dictionary contract and
registry removal). So the migration crosses `migrate_sdp_methods()`, the
`method_iri` → `statistical_modifier_iri` flip, and a canonical-bytes change.

`migrate_sdp_methods()` exists and is the tool; what does not exist is any
evidence it has been run against a package of this shape — six measure-specific
observation structures, two SSSOM mapping sets, measurement decompositions, a
reviewed-selection ledger, and closed workflow/provenance/source inventories.
**A migration that has only been tested on fixtures is a plan, not a path.**

## Requirement 3 — IRI-dereference verification, with bounded retry

The recipe verifies that **every exact HTTP semantic IRI dereferences** before
it publishes, and writes the result to
`reproducibility/provenance/semantic-iri-dereference.csv` with a checksum in its
provenance inventory. The implementation
(`src/extended-sdp.R`) sorts the IRI set with `method = "radix"`, retries on a
classified set of transient transport failures with a **bounded** two-delay
schedule (three attempts maximum), and aborts naming every IRI that failed with
its status.

**metasalmon has no such check.** It is the capability backlog **#99** asks for
by another name — two `w3id.org/example/salmon#` IRIs that return HTTP 404 ship
in `inst/extdata/column_dictionary.csv` and are copied into metasalmonpy and
`smn-data-pkg`, and nothing in any of the three notices. An external consumer
built the check because it had to; the reference implementation exists and is
readable. Bounded is the load-bearing word: an unbounded retry against a
vocabulary host turns a publication step into an outage amplifier.

## The open KNB incident — read this before scheduling requirement 2

**A live `dry_run = FALSE` deposit put 31 objects on production DataONE and the
series head has been unsettled since 2026-08-05.** From the recipe's own
operation record (`operations/2026-08-04-knb-private-review-expanded-sdp-revision.md`),
checkpoint state **"open — DataONE series-head synchronization"**:

- 31 immutable objects on `urn:node:KNB`, environment `PROD`, restricted
  access, zero replicas, no DOI — 1 source-data object, 28 SDP artifacts, 1 EML
  object, 1 OAI-ORE resource map. All 31 verified by the live adapter.
- KNB's **Member Node** resolves the series to the new metadata PID; the DataONE
  **Coordinating Node** kept returning the **predecessor**. The strict adapter
  called the binding ambiguous and **did not write a completion receipt**.
- Two bounded polls, the second ending `2026-08-05T03:28:54Z`, reproduced the
  same external state. Nothing has advanced it since.

Three facts about the record itself, each verified across every branch of that
repository on 2026-08-21 and each worth stating because none is obvious:

- **The invocation exists in no committed branch.** `dry_run = FALSE` appears in
  no `.R` or `.Rmd` file on `main` or on any of the five feature branches. The
  call that created 31 persistent objects on public infrastructure was made from
  somewhere uncommitted, so **the exact plan cannot be re-derived from the
  repository** — only the manifest and plan SHA-256s in the operation record
  attest to it.
- **No completion receipt has ever existed.** `receipts/` contains its
  `README.md` and nothing else, on every branch. The operation record is
  explicit that it "is recovery evidence, not a weaker receipt".
- **The safety decision is to retry only that exact plan**, after the
  Coordinating Node advances — not to regenerate PIDs, change the ACL, enable
  replication, delete a version, or hand-edit the manifest.

**Migrating before the series resolves risks two live heads.** A migration to
sdp-0.3.0 rewrites the canonical bytes, which produces a different plan, a
different manifest SHA-256 and a different PID set. Depositing that while the
Coordinating Node still binds the series to the **predecessor** metadata PID
leaves two unobsoleted heads on a series that is already ambiguous — and
DataONE objects are immutable, so the cleanup for that is a third revision,
not a deletion. **Sequence requirement 2 after the series binding resolves, or
explicitly decide to publish the migrated package as a new series.** Which of
those is right is not this hub's call.

**Whose call it is:** resolving the incident belongs to that repository's owners
and its own plan. What belongs here is the constraint it places on metasalmon
sequencing, and one observation about this package: the strict adapter behaved
correctly throughout — it refused an ambiguous binding, recovered idempotently
from a coordinating-node timeout after the first object was created, and
generated no duplicate identifiers. The unresolved state is external. The
**absence of any rehearsal path is not** — see below.

## Dependencies

- **Needs [S3](s3-knb-staging.md).** This deposit went straight to production
  because there is nowhere else to go: both mirrors hardcode the production
  endpoints and neither publication function takes an environment argument. A
  case study that cannot be rehearsed is a case study that debugs in public.
  This is the concrete evidence that S3 is not a workshop nicety.
- **Independent of salmon-domain-ontology PR #27.** The recipe uses twelve
  `smn:` terms and all twelve already exist; it never mentions cycle line or
  life history. Both are Fraser sockeye, which makes the assumption natural and
  wrong — see [S9](s9-ontology-alignment.md).
- **Interacts with [S10](s10-metasalmonpy-parity.md) only through the spec era.**
  The recipe is R-only. Its sdp-0.2.0 pin and metasalmonpy's vendored sdp-0.2.0
  bundle are the same era for unrelated reasons; do not treat one as evidence
  about the other.
