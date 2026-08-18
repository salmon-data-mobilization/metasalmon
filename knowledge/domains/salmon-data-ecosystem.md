---
type: ScientificDataDomain
title: "Salmon data ecosystem"
description: "The salmon data mobilization ecosystem: SDP tooling in R and Python, the SDP specification, the shared and agency ontologies, the PSC controlled vocabulary, and the salmon knowledge commons, coordinated through the metasalmon hub."
status: draft
tags: [salmon, sdp, ecosystem]
psc:
  id: metasalmon:domain:salmon-data-ecosystem
---

The domain this bundle coordinates. The table below is the complete allowlist:
seven repositories, one hub.

| Repo | Role |
|---|---|
| `metasalmon` (this repo) | R tooling for Salmon Data Packages; **the coordinating hub** — sequencing, execplans, and the release index live in this bundle |
| `metasalmonpy` | Python mirror of metasalmon (formerly `metaSmnPy`; package formerly `salmonpy`) — versions are parity claims |
| `smn-data-pkg` | The Salmon Data Package (SDP) specification — normative `SPECIFICATION.md` plus the machine-readable profile/schemas/rules that metasalmon vendors |
| `salmon-domain-ontology` | The shared Salmon Domain Ontology (`smn:`) |
| `dfo-salmon-ontology` | The GC DFO Salmon Ontology (`gcdfo:`) |
| `psc-salmon-vocabularies` | The PSC controlled vocabulary (SKOS-only, CSV-authoritative, GitLab) |
| `salmon-knowledge-commons` | Source-backed prose about salmon ecology, biology, conservation, management, and research, written for people and agents (upstream OKF v0.2, private) — every concept names its ontology term or records a structured gap, and that gap register is the front end of this package's term-request pipeline |

**`salmon-knowledge-commons` was added 2026-08-17 (Brett), and it is a member
rather than an external edge for one reason: its gap register is an input to
this ecosystem's own pipeline**, not an artifact the hub happens to consume.
Every concept records the ontology term it corresponds to, or a structured gap
stating what a term would have to say and where it should be minted — which is
what `detect_semantic_term_gaps()` → `render_ontology_term_request()` →
`submit_term_request_issues()` already exists to carry. Its first four concepts
(cycle line, broodline, cyclic dominance, run timing) came out of resolving a
live modelling question in
[salmon-domain-ontology PR #27](https://github.com/salmon-data-mobilization/salmon-domain-ontology/pull/27).
It now holds **eleven concepts and 24 gaps** (2026-08-18).

## The term lifecycle is what connects the commons to the ontologies

A gap is not a note; it is a **state machine**, declared in
`schema/concept.schema.json` and enforced by the schema rather than by
convention. Each entry in a concept card's `alignment.gaps[]` carries
`state ∈ {open, proposed, rejected, minted}`:

| State | Means | Schema then requires |
|---|---|---|
| `open` | Nobody has proposed a term | — |
| `proposed` | A term is up for review somewhere | `proposal` (the PR/issue URL) |
| `rejected` | Review declined it | `proposal`, **`rejected_because`**, **`evidence_needed`** |
| `minted` | The term exists | Move the IRI to `alignment.exact` and delete the gap |

**The rule that matters to this hub: when a term proposal closes unmerged, the
gap goes back to the commons as `rejected`, carrying `rejected_because` and
`evidence_needed`, in the same change that closes the proposal.** Both fields
have a 40-character minimum, so neither can be satisfied with a shrug.

This is the mechanism, not a nicety. A rejection that records no reason and no
way forward is **indistinguishable from nobody having tried** — so the same
term gets proposed again unchanged, reviewed again, and declined again by
whoever has forgotten the first round. `rejected_because` is what stops the
loop; `evidence_needed` is what makes a rejection a *route* rather than a dead
end, which is why S9's group D can record "leave it as data until a published
scheme is in hand" as a **result** rather than a failure.

Note the machinery is untested in practice: **all 24 gaps are currently
`open`**, and `rejected_because` / `evidence_needed` appear in the schema, the
contributing guide and the checker but in **no card**. smn PR #27 is the
obvious first customer — it is a live proposal that withdrew its species
scheme, which is a `rejected` gap in everything but the recording.

**Do not read membership as maturity.** It was created 2026-08-17, holds four
concepts, **none of them human-verified**, and its card schema and contribution
flow are being written concurrently with its first content. It uses upstream
OKF v0.2 rather than the PSC profile deliberately: that profile's closed card
schema rejects `sources`, `verified`, `generated`, `stale_after`, and
`resource`, which are precisely the fields the commons exists to carry, so
`psc-okf`'s profile check is not its validator.

Shared tools, hyperlinks, consumed artifacts, and transitive dependencies do
not add repositories to this domain, and neither does sharing a GitHub
organization — membership follows from this hub sequencing that repository's
work, not from who owns it. In particular, `psc-data-systems`,
`psc-data-systems-site`, `campModelInput`, and `ctc-knowledge-map` are external
to the hub. When one matters to this domain, the hub records only a typed
dependency edge with its owner, required artifact or gate, owning plan, and
observation date; it does not absorb that repository's tasks, status, branches,
approvals, or releases.
