---
type: InformationObject
title: "S3 — KNB staging environment"
description: "A guarded rehearsal target so deposits can be practised without writing to production KNB. Step 0 shipped in 0.2.5; steps 1-5 are unstarted, and what 'the KNB test environment' means is an open decision."
status: draft
tags: [knb, publication]
psc:
  id: metasalmon:sequence:s3-knb-staging
  contexts: [metasalmon:context:hub-coordination]
---

# S3 — KNB staging environment

**UNBLOCKED — Q1 answered 2026-08-22 (Brett), and the environment verified the
same day.** The ruling: the golden path develops packages against the KNB
test/dev environment first, then posts to production
(`https://knb.ecoinformatics.org/knb/d1/mn/v2`) once they look good — "as long
as it works out." Measured, read-only: `urn:node:mnTestKNB` ("KNB Test Node")
is **live at `https://dev.nceas.ucsb.edu/knb/d1/mn`** (200, identity read from
the node document; demo.nceas serves the same identity) and is registered in
the DataONE staging CN. So this card's previously unsourced node id was right,
and the endpoint now has a source. The psc-data-transformations contradiction
dissolves rather than resolves: its claim concerned *production* having no
server-side draft, and the test node is a separate environment — both are
true; production private-review remains the fallback if the test path does not
work out. **Remaining before the golden path can be taught (S4): a dev.nceas
token (Brett's — credentials) and one end-to-end test deposit.**

**Execplan:** [KNB environments and workshop rebuild](../plans/2026-08-11-knb-environments-and-workshop-rebuild.md)

A guarded rehearsal path so the workshop — and any new user — can practise a
deposit without writing to the production KNB node. The execplan's shape is a
`knb_environment = "production" | "staging"` argument; **whether that is the
right shape is [OD-2](../roadmap.md#od-2--what-does-the-knb-test-environment-mean),
and it is not ruled** (below).

## Where it actually stands

**Step 0 shipped; steps 1–5 have not started.** Measured 2026-08-21 against the
execplan's own sequencing table:

| Step | State |
|---|---|
| 0. `dataone_test_token` redacted in both redactors (#73) | **Shipped in 0.2.5** |
| 1. `knb_environment` API + registry | Not started |
| 2. Staging EML output path | Not started |
| 3. Manifest and overwrite gating | Not started |
| 4. Publication-writer ownership of `publication/staging/` | Not started |
| 5. Docs, version bump, release | Not started |

Step 0 is the security fix the execplan insisted go first, and it went first —
but it is the *only* step that has, and 0.2.5 shipped a redactor for a token
name nothing yet reads. Worth knowing before reading step 0's completion as
progress on the feature.

**Both mirrors hardcode production, and neither publication function takes an
environment argument.** R: `.ms_knb_environment <- "PROD"` and the member-node,
resolver, Solr and EML object URLs are module-level constants
(`R/knb-publication.R`, `R/eml-export.R`); `publish_sdp_to_knb()`'s parameters
are `path`, `eml_path`, `public`, `manifest_path`, `dry_run`, `confirm`,
`revision_manifest`, `representation`, `overwrite` — no environment among them.
Python is the same shape: `MN_ENDPOINT`, `CN_ENDPOINT`, `RESOLVER` and
`_KNB_OBJECT_ENDPOINT` are module constants. So step 1 is not "add an argument
that threads through"; it is introducing the *first* piece of state these
modules have ever had to vary.

**On the Python side S3 is a behaviour change to an existing test, not new
coverage.** `tests/test_knb_publication.py` carries
`test_default_adapter_only_supports_production_knb`, which asserts that
`DataOneRestAdapter.connect("STAGING", NODE_ID)` **and**
`connect(ENVIRONMENT, "urn:node:mnTestKNB")` both raise. Whatever S3 mirrors
into metasalmonpy has to change that test — so the mirror PR will read as
"weakening a guard", and its description must say why, or a reviewer is right
to stop it. Note the same file's `publish_sdp_to_knb` docstring states *"A live
restricted deposit is the KNB review/staging mechanism; KNB does not expose a
separate server-side draft state"* — the mirror already documents a **different
answer** to OD-2 than the execplan assumes.

## Two unverified assertions, pulling opposite ways

**The execplan's staging target has no cited source.** Its closed registry gives
`staging` as DataONE network `STAGING`, member node `urn:node:mnTestKNB`, token
`dataone_test_token` — stated as a table, with no reference to DataONE
documentation, no record of anyone connecting to that node, and no note of who
established it. Every later step in the execplan (EML output path, manifest
gating, PID minting, zero replicas) derives from that row. If the node name or
the network is wrong, steps 1–5 are built on it. **This is the cheapest thing
to check in the whole stream and nobody has checked it.**

**`psc-data-transformations` asserts an incompatible model, also without this
hub having verified it.** Its `docs/architecture.md` says KNB provides **no
separate hosted draft object** and that a *restricted persistent version in
production* is the review/staging state; `profiles/knb-private-review.yml`
encodes exactly that (`deposit_kind: production`, `access: restricted`,
`staging_model: private_persistent_version`, `creates_persistent_objects:
true`) — and it has been **run**, which the execplan's model has not.

Both can be literally true at once: a test *node* and a restricted production
*version* are different objects. That is why this is a question and not a defect
on either side.

## The open decision — do not resolve it here

**What "the KNB test environment" means is
[OD-2](../roadmap.md#od-2--what-does-the-knb-test-environment-mean)**, and the
roadmap holds the three candidate rulings (a distinct DataONE test node; a
restricted persistent production version; both, as two values). This card
deliberately states no preference. Note that verifying `urn:node:mnTestKNB`
directly would settle the **factual** half — whether that node exists and
accepts these deposits — and would still leave the "which one do we teach"
half open. Evidence is not the ruling.

What each ruling costs S3: under a distinct test node, steps 1–5 stand as
written; under a restricted production version, most of the execplan's staging
machinery (separate token, separate EML path, staging PIDs, zero replicas) has
nothing to attach to and S3 becomes a documentation-and-teaching stream; under
both, S3 grows rather than shrinks.

## Why this is not a workshop nicety

**The ecosystem's only real KNB deposit went to production.** The Fraser
sockeye stock-recruit recipe put **31 objects** on production DataONE
(`urn:node:KNB`, `PROD`, restricted access) on 2026-08-04, hit a
coordinating-node series-binding failure, and has been **unresolved since
2026-08-05** — see [S13](s13-fraser-recruits-case-study.md). Nobody rehearsed
first, because there is nothing to rehearse against.

That reframes the stream. S3 has been carried as a prerequisite for teaching;
it is at least as much a prerequisite for *doing*, and the one time the
ecosystem did it for real, the failure landed on persistent public-infrastructure
objects that cannot be deleted. Whether a rehearsal path would have caught that
particular failure is unknown — it was a coordinating-node propagation problem,
not a plan defect — but "we have never once practised this" is the condition S3
exists to end.

## Sequencing

**Blocks S4 — conditionally.** The workshop cannot teach a rehearsal that does
not exist, and it pins an exact released metasalmon version. But that arrow is
exactly what OD-2 decides: under a restricted-production-version ruling the
rehearsal S4 needs already exists in shipped form and the arrow dissolves. Read
`S3 ──► S4` as the plan of record awaiting a ruling.

**Not blocked by S1**, but see the execplan's *Sequencing* section: shipping S3
before S1 means the staging rehearsal validates with the same under-checking
validator — acceptable for a rehearsal, not for the claim "validation is your
final gate."

**Mirror rule:** whatever lands here lands in metasalmonpy in the same stream,
including the test change named above and a `PARITY.md` row if the two ever
differ deliberately.
