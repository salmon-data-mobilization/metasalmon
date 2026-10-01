---
type: Artifact
title: "Public catalogue capture and prototype migration"
description: "Proposed package-side migration of a bounded public catalogue prototype, retaining pending review, authoritative sources and shared R/Python capture contracts."
status: draft
tags: [catalogue, data-access, migration, provenance, proposal]
psc:
  id: metasalmon:plan:2026-09-30-public-catalogue-capture-migration
  contexts: [metasalmon:context:hub-coordination]
---

# Public catalogue capture and prototype migration

This is the package-side migration record for the bounded public catalogue
prototype, authorized by Brett in the 2026-09-30 review session. It records
interfaces and acceptance boundaries; queue state lives only in
`queue/items/B-427.yaml`. A readiness proposal on a work branch is
not an effective default-branch promotion, and no hub claim is taken here.

## Existing design authority

The [Foundry design, section 3.5](2026-09-04-salmon-science-foundry-concrete-plan.md#35-tool-contracts-the-data-access-layer-and-delivery-shape-replaced)
already describes snapshot-first public source access, explicitly lists
DataONE/KNB discovery, reuses their public clients, and separates source
authority, access/redistribution terms and scientific review. Its Q27 ruling
places the verbs inside metasalmon and metasalmonpy under the mirror rule,
with a shared receipt schema. This note follows that placement; it creates
no separate catalogue, service or package and does not activate the Foundry
stream or its research stages.

This first migration captures metadata queries through the existing KNB and
DataONE query interfaces. It is narrower than the complete DatasetReceipt,
source registry, governance H0 record and object-fetch workflow planned in
section 3.5. A metadata capture is not an SDP and is not evidence that data
objects may be redistributed. Source repositories remain authoritative.

## What the prototype established

The local Fraser sockeye demonstration captured public KNB/DataONE metadata,
original KNB objects and public native data releases with URLs, timestamps
and byte hashes. It inspected genuinely different native schemas, proposed
duplicate/derived overlap using identity, version and provenance evidence,
and used local review events to control grouped coverage and query results.
The replay distinguished a repeated catalogue encounter from independent
evidence. It did not create new submission records or approve annotations.

Its same-evidence decision represents whole-object equivalence. Likely
partial or derived overlap is evidence for review, not authority to equate
entire datasets. Structured observation partitions are still missing: a
future adapter must retain the shared portion and each distinct residual
rather than discarding residual evidence after a coarse overlap judgement.
Pending overlap is withheld from eligible coverage; eligible grouping does
not establish statistical independence.

The prototype also packaged one real table through existing `create_sdp`
and package validation, preserving all source rows and values. Structural
validation passed and strict semantic validation remained blocked. SSSOM,
application-vocabulary and commons-card outputs remained proposals. Review
acceptance/revocation demonstrations used explicitly simulated fixtures;
they are not attestations by a human reviewer. These observations are local
prototype provenance, not a released capability or a scaling benchmark.

## First package interface under review

Both package drafts propose the public name `capture_catalogue_query`. Python
uses the keyword-only convention:
`capture_catalogue_query(query, out, *, catalogue="knb", max_records=100,
page_size=50, timeout=30, max_bytes=2000000, fetch=None, captured_at=None)`.
R exposes the same behavior through
`capture_catalogue_query(query, out, catalogue="knb", max_records=100L,
page_size=50L, timeout=30, max_bytes=2000000L, fetch=NULL, captured_at=NULL)`.
The public name,
argument/return contract and shared capture-receipt version in this PR are
proposals for package review, not a new adopted standard. Check the package
reference and source in this PR for the exact public signature; defaults and
implementation state are not duplicated in the queue.

The narrow capture contract retains:

- Catalogue, endpoint, exact query, capture time and raw metadata records.
- For each page: request URL, start/row request, raw file, byte size and
  SHA-256. The metadata filter and stable ID ordering remain explicit.
- Reported metadata matches, captured metadata records and completeness
  against the reported count. These are metadata encounters, including
  versions and mirrors; `independent_dataset_count` remains unset.
- Pending annotation status. Pagination is a sequence of public requests,
  not a transactional repository snapshot; `transactional_snapshot` is false.
- A success marker only after successful bounded capture. Existing output
  is reserved/rejected before any request; a failure retains its evidence
  and cannot masquerade as a successful capture. Crash recovery and final
  installation races must be tested rather than described as durable by
  assumption.

No model call, secret, authenticated source, object download, semantic
acceptance or repository submission is needed for this interface. Production
adapters should reuse existing DataONE clients where they support this
bounded contract; the injectable transport keeps fixture tests offline.

## Migration order and destinations

| Step | Destination and retained contract | Acceptance before replacing prototype code |
|---|---|---|
| Public metadata capture | metasalmon/metasalmonpy; existing public catalogue endpoints and source authority | Shared query/page/receipt fixtures, bounds, raw hashes, count distinctions, partial/failure outcomes and no-overwrite behavior agree; no secret/provider access |
| Source encounter normalization and overlap evidence | Deterministic package functions, with domain-specific scientific adapters | Preserve IDs, versions, capture provenance and immutable fingerprints; exact duplicates never become independent evidence; ambiguous keys remain visible; shared/residual observation partitions preserve partial overlap; stale or contradictory reviews fail visibly |
| Review, SSSOM and commons gap routing | Package validators and existing review-packet contract; agent-facing plugin skills for review | Bind decisions to source/proposal versions; pending mappings remain pending; revocation removes eligibility; no local approval becomes a verified commons claim or ontology term |
| Native-source packaging | Existing `create_sdp`, package schema, validators and reproducibility manifest | Source-to-package value equality and retained missing keys; structural success distinguished from strict semantic readiness; transformation receipt records field/age/basis/as-of implications |
| Evidence/coverage/query presentation | Optional research UI consuming package functions or serialized responses | Same complete evidence-group membership and withheld reasons as the deterministic query; presentation does not own harvesting or approval policy |

Each later package API needs its own reviewable diff and acceptance fixture.
The current change starts capture; it does not claim that the complete table
has migrated. The packages keep deterministic validation and execution;
agent judgement remains in the plugin/harness. Existing model, spending and
scientific approval gates continue to apply to later research/model work.

New live catalogue captures remain a separate pending metadata-capture view.
They do not silently join the prototype's object review ledger or increase
its accepted evidence coverage; catalogue version matches are not new
independent source objects.

The commons-register adapter is already planned as
`B-278` (`queue/items/B-278.yaml`) and its Python twin
`B-279` (`queue/items/B-279.yaml`); reuse those items rather than creating a
second gap pipeline. Core term admission remains a separate human-reviewed
ontology action. Source-specific rights and governance are assessed before
future object fetch/redistribution; discovery alone does not settle them.

## Validation and handoff

Run the catalogue capture fixture tests in both packages, the hub queue
`lint`/`check` commands and the private-terms checks before submission. Retain
the local replay tests for duplicate grouping, review/revocation, stale
binding, contradictory decisions, scientific basis and package equality
until equivalent package tests replace them. Bounded live read receipts are
useful corroboration but do not replace failure fixtures or establish
transactional snapshot completeness.

The package and research-consumer PRs are the review surfaces for their own
interfaces. This public note contains no private repository paths, credentials
or unpublished scientific results, and no Foundry repository or new hub
member is created by this migration.
