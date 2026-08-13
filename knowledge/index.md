---
okf_version: "0.2"
---

# metasalmon — ecosystem hub knowledge bundle

This Open Knowledge Format bundle is the **coordinating hub** for the salmon
data ecosystem: metasalmon (R), metasalmonpy (Python mirror), the Salmon Data
Package spec (`smn-data-pkg`), the Salmon Domain Ontology
(`salmon-domain-ontology`), the GC DFO Salmon Ontology
(`dfo-salmon-ontology`), and the PSC controlled vocabulary
(`psc-salmon-vocabularies`). Sequencing, execplans, and the cross-repo release
index live here. It replaced the former `notes/` planning tree on 2026-08-13
(only `notes/evidence/theme-a/` stays behind — it is wired into CI and tests
and contains non-Markdown files a bundle cannot hold).

## Start here

- [ROADMAP](roadmap.md) — the single sequencing authority: what next, in what
  order, blocked by what, plus the per-repo release index.
- Sequence cards under `sequences/` — one card per stream (S1–S11) with the
  detail the roadmap deliberately omits.
- Execplans under `plans/` — dated records of how one stream is done.
- [Backlog](backlog.md) — every known defect and improvement, with evidence.
- [Orientation](orientation.md) — architecture and file→responsibility map.
- [Method model draft](method-model-draft.md) — the SDP methods/aggregation
  draft awaiting port to `smn-data-pkg`.

## Validation

From this repo's root, with a sibling `psc-data-systems` checkout:

```sh
uv run --project ../psc-data-systems psc-okf check knowledge --tier capture
```
