---
type: InformationObject
title: "S3 — KNB staging environment"
description: "A guarded rehearsal target so deposits can be practised without writing to production KNB. Steps 0-4 have shipped in R and the docs half of step 5; what remains is a test-node token, one end-to-end deposit, the release, and the metasalmonpy mirror."
status: draft
tags: [knb, publication]
psc:
  id: metasalmon:sequence:s3-knb-staging
  contexts: [metasalmon:context:hub-coordination]
---

# S3 — KNB staging environment

**IMPLEMENTED IN R 2026-08-22; not yet released, not yet mirrored, and no
deposit has been made in either environment.** Read the state table below
before treating this stream as done — what shipped is the *switch*, and what
S4 waits on is a *deposit*, which is a different thing and is still blocked on
a credential only Brett can obtain.

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
deposit without writing to the production KNB node. The execplan's shape was a
`knb_environment = "production" | "staging"` argument; that shape survived, with
the second value named **`"test"`** rather than `"staging"` (below).

## Where it actually stands

**Steps 0–4 shipped in R; step 5 is half done.** Measured 2026-08-22 against
the execplan's own sequencing table:

| Step | State |
|---|---|
| 0. `dataone_test_token` redacted in both redactors (#73) | **Shipped in 0.2.5** |
| 1. `knb_environment` API + registry | **Shipped (R)** — `R/knb-environments.R` |
| 2. Test EML output path | **Shipped (R)** — `publication/test/eml.xml` |
| 3. Manifest and revision gating | **Shipped (R)** — cross-environment revision refused |
| 4. Publication-writer ownership of `publication/test/` | **Shipped (R)** — asserted preserved across a base-writer rewrite |
| 5. Docs, version bump, release | **Docs shipped**; version bump and release outstanding |

Step 0 was the security fix the execplan insisted go first, and it did — and
0.2.5's redactor for a token name nothing read is now the redactor for a token
name the test environment actually reads.

**What is deliberately NOT done, because it cannot be done here:** no live
deposit has been made in either environment. There is no test-node token yet;
obtaining one is Brett's, because it is a credential. Everything verified for
this work was a read-only node-capabilities GET. So the switch exists and is
tested offline, and the *first actual rehearsal* has not happened.

**The release is deliberately deferred.** `knb_environment` is additive, so
sized against 0.3.0 this is **0.3.1** — but the mirror contract puts release
numbers in lockstep with metasalmonpy, and the Python side has not started
(below). `DESCRIPTION` therefore stays at 0.3.0 and `NEWS.md` records the work
under *development version*; the version bump and the tagged GitHub Release
belong to whoever lands the mirror.

## What the verified facts changed about the execplan

The execplan was written before the endpoint had a source, so its design is
mostly intact and its *names* are not:

| Execplan said | What shipped | Why |
|---|---|---|
| `knb_environment = "staging"` | `knb_environment = "test"` | The node is literally `mnTestKNB`, "KNB Test Node", and Brett's ruling says "test/dev environment". `STAGING` survives where it is DataONE's own term — the network name inside the registry. |
| Staging artifacts under `publication/staging/` | `publication/test/` | Follows the argument value, so a reader never has to translate between two names for one environment. |
| Production is the default; live calls must be explicit | **Dry runs default to `"test"`**; live calls must be explicit | Brett's ruling moved the default. The execplan's actual rule — *an unstated environment on a live call is an error* — survived untouched. |
| Endpoints stated without a source | Every value read from the node documents themselves | `urn:node:mnTestKNB` at `dev.nceas.ucsb.edu`, registered `state="up"` in `urn:node:cnStage` (`cn-stage.test.dataone.org`); `urn:node:KNB` at `knb.ecoinformatics.org`. |

Two things the execplan did not anticipate, both found while building it:

- **The coordinating node had to enter the registry.** The execplan's table has
  a network and a node id; it has no CN. But the resolver URL embedded in every
  OAI-ORE document and the Solr endpoint used for catalog verification are both
  CN-derived, so an environment that switched only the MN would have emitted
  production resolve URLs from a test deposit. The registry now derives every
  URL from an `mn_base_url`/`cn_base_url` pair, which makes a piecemeal switch
  structurally impossible rather than merely tested against.
- **Identifier scoping is load-bearing, and the SDP archive proves it.** The
  execplan asked for staging PIDs that "can never collide with or be mistaken
  for" production PIDs without saying how. The sharp case is the SDP archive:
  its bytes are environment-independent, so the same package minted the *same
  archive identifier* in both environments. Identifiers are now scoped per
  environment, with production's scope empty so every production identifier
  minted before this change is byte-identical.

**Both mirrors hardcode production, and neither publication function takes an
environment argument.** R: `.ms_knb_environment <- "PROD"` and the member-node,
resolver, Solr and EML object URLs were module-level constants
(`R/knb-publication.R`, `R/eml-export.R`); `publish_sdp_to_knb()`'s parameters
were `path`, `eml_path`, `public`, `manifest_path`, `dry_run`, `confirm`,
`revision_manifest`, `representation`, `overwrite` — no environment among them.
Python is still that shape: `MN_ENDPOINT`, `CN_ENDPOINT`, `RESOLVER` and
`_KNB_OBJECT_ENDPOINT` are module constants. So step 1 was not "add an argument
that threads through"; it was introducing the *first* piece of state these
modules have ever had to vary. **Done in R 2026-08-22; Python still hardcodes
production.**

**On the Python side S3 is a behaviour change to an existing test, not new
coverage.** `tests/test_knb_publication.py` carries
`test_default_adapter_only_supports_production_knb`, which asserts that
`DataOneRestAdapter.connect("STAGING", NODE_ID)` **and**
`connect(ENVIRONMENT, "urn:node:mnTestKNB")` both raise. The mirror has to
change that test — so the mirror PR will read as "weakening a guard", and its
description must say why, or a reviewer is right to stop it. It is not a
weakened guard: the R side replaced the same refusal with a *stricter* one,
which accepts a registered node paired with its own network and refuses every
other combination, including the mismatched pairs that test names. Note the
same file's `publish_sdp_to_knb` docstring states *"A live restricted deposit
is the KNB review/staging mechanism; KNB does not expose a separate server-side
draft state"* — accurate about production, and now incomplete, because a
separate test environment exists.

**The mirror is a fresh item, not part of an in-flight chunk.** S10 chunks A–H
are all merged as of 2026-08-22, so nothing is being carried in that stream
that this could ride along with. What it owes:

- `knb_environment` on `publish_sdp_to_knb()` and the EML writer, with the same
  two values, the same dry-run-defaults-to-test rule, and the same
  no-default-for-live rule.
- One environment registry with the CN in it, deriving every URL from the
  member-node and coordinating-node base URLs, so the switch cannot be partial.
- Identifier scoping with an empty production scope, so production identifiers
  stay byte-identical and a test identifier can never collide with one.
- The separate `dataone_test_token` credential, named in its own error message,
  and covered by the redaction rule.
- `publication/test/` artifact paths, leaving the reviewed production
  `metadata/eml.xml` untouched.
- Rewriting `test_default_adapter_only_supports_production_knb` into a
  both-environments-accepted / mismatched-pair-refused test.

Release numbers stay in lockstep, so the R-side 0.3.1 release waits on this.

## The two assertions that pulled opposite ways — settled

**The execplan's target had no cited source, and it turned out to be right.**
Its closed registry gave `staging` as DataONE network `STAGING`, member node
`urn:node:mnTestKNB`, token `dataone_test_token`, stated as a table with no
reference, no record of anyone connecting, and no note of who established it —
every later step derived from that row. Checked directly on 2026-08-22, it held:
the node exists, answers, and carries that identity. The cheapest check in the
stream was worth making, and the lesson survives the happy outcome — steps 1–5
were built on an unsourced row for eleven days, and would have been built on it
either way.

**`psc-data-transformations` asserted an incompatible model, and both are
true.** Its `docs/architecture.md` says KNB provides no separate hosted draft
object and that a *restricted persistent version in production* is the
review/staging state; `profiles/knb-private-review.yml` encodes exactly that,
and it has been **run**, which the test-node path still has not. That claim is
about *production*, and the test node is a different environment — so the
contradiction dissolved rather than resolving. Both models now exist in the
package: `knb_environment = "test"` is the rehearsal, and a restricted
production deposit remains the production-side review mechanism and the
fallback if the test path does not work out.

**[OD-2](../roadmap.md#od-2--what-does-the-knb-test-environment-mean) is
answered** — ruling A, a distinct DataONE test node, recorded as Q1 on
2026-08-22. Evidence settled the factual half; Brett settled which one we
teach.

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

**Still blocks S4, and the arrow is no longer conditional** — OD-2 ruled for a
distinct test node, so the workshop does need this rehearsal to exist. But the
blocker has moved: the switch exists, and what S4 now waits on is
**a dev.nceas token (Brett's — a credential) and one end-to-end test deposit**,
plus a released version to pin. Teaching a rehearsal nobody has ever performed
would be teaching an untested claim.

**Not blocked by S1**, but see the execplan's *Sequencing* section: shipping S3
before S1 means the test rehearsal validates with the same under-checking
validator — acceptable for a rehearsal, not for the claim "validation is your
final gate."

**Mirror rule:** whatever lands here lands in metasalmonpy in the same stream.
That has **not** happened — the R side landed alone, deliberately, because the
Python repo had chunk work in flight when this was built. Until the mirror
lands, the two packages differ in a way that is *not* recorded in
`parity-deviations.md`, because it is a lag rather than a deliberate deviation:
the R release is held at 0.3.0 rather than bumped to 0.3.1 precisely so the
lockstep rule is not broken. If the mirror is declined rather than deferred,
that becomes a deliberate deviation and needs a row in both registers.
