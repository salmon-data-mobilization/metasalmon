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
[salmon-domain-ontology PR #27](https://github.com/salmon-data-mobilization/salmon-domain-ontology/pull/27)
and already carry seven recorded gaps.

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
