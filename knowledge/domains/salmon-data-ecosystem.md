---
type: ScientificDataDomain
title: "Salmon data ecosystem"
description: "The salmon data mobilization ecosystem: SDP tooling in R and Python, the SDP specification, the shared and agency ontologies, and the PSC controlled vocabulary, coordinated through the metasalmon hub."
status: draft
tags: [salmon, sdp, ecosystem]
psc:
  id: metasalmon:domain:salmon-data-ecosystem
---

The domain this bundle coordinates. The table below is the complete allowlist:
six repositories, one hub.

| Repo | Role |
|---|---|
| `metasalmon` (this repo) | R tooling for Salmon Data Packages; **the coordinating hub** — sequencing, execplans, and the release index live in this bundle |
| `metasalmonpy` | Python mirror of metasalmon (formerly `metaSmnPy`; package formerly `salmonpy`) — versions are parity claims |
| `smn-data-pkg` | The Salmon Data Package (SDP) specification — normative `SPECIFICATION.md` plus the machine-readable profile/schemas/rules that metasalmon vendors |
| `salmon-domain-ontology` | The shared Salmon Domain Ontology (`smn:`) |
| `dfo-salmon-ontology` | The GC DFO Salmon Ontology (`gcdfo:`) |
| `psc-salmon-vocabularies` | The PSC controlled vocabulary (SKOS-only, CSV-authoritative, GitLab) |

Shared tools, hyperlinks, consumed artifacts, and transitive dependencies do
not add repositories to this domain. In particular, `psc-data-systems`,
`psc-data-systems-site`, `campModelInput`, and `ctc-knowledge-map` are external
to the hub. When one matters to this domain, the hub records only a typed
dependency edge with its owner, required artifact or gate, owning plan, and
observation date; it does not absorb that repository's tasks, status, branches,
approvals, or releases.
