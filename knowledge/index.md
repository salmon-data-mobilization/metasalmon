---
okf_version: "0.2"
---

# metasalmon — ecosystem hub knowledge bundle

This Open Knowledge Format bundle is the **coordinating hub** for the salmon
data ecosystem: metasalmon (R), metasalmonpy (Python mirror), the Salmon Data
Package spec (`smn-data-pkg`), the Salmon Domain Ontology
(`salmon-domain-ontology`), the GC DFO Salmon Ontology
(`dfo-salmon-ontology`), the PSC controlled vocabulary
(`psc-salmon-vocabularies`), the salmon knowledge commons
(`salmon-knowledge-commons`), the standards workshop
(`salmon-data-standards-workshop`, the eighth member since Brett's 2026-08-24
membership ruling), and the Salmon Science Foundry (`salmon-science-foundry`,
the ninth member since Brett's Q19 ruling of 2026-09-05; the repository itself
does not exist yet). Sequencing, execplans, and the cross-repo release
index live here. It replaced the former `notes/` planning tree on 2026-08-13
(only `notes/evidence/theme-a/` stays behind — it is wired into CI and tests
and contains non-Markdown files a bundle cannot hold).

## Start here

- **The hub queue is where planning state lives**, at `queue/` in the
  repository root and outside this bundle: one YAML file per work item under
  `queue/items/`, described by `queue/README.md`, with `HUB.md` beside it as
  the policy file. It replaces the state the roadmap, the sequence cards and
  the backlog used to restate in prose. It is named here in backticks rather
  than linked, because a bundle card does not link to a file outside the
  bundle; the link that used to sit here resolved to `knowledge/queue/README.md`,
  which has never existed.
- [ROADMAP](roadmap.md) — the single sequencing authority: what next, in what
  order, blocked by what, plus the per-repo release index.
- Sequence cards under `sequences/` — one card per stream (S1 to S15) with the
  detail the roadmap deliberately omits.
- Execplans under `plans/` — dated records of how one stream is done.
- [Backlog](backlog.md) — every known defect and improvement, with evidence.
- [Open questions](questions.md) — the index of decisions only Brett can make,
  open and answered. The ruling itself lives in the owning card; this file says
  which card that is.
- [Orientation](orientation.md) — architecture and file→responsibility map.
- [Workshop curriculum and SDO guidance findings](workshop-curriculum-and-sdo-guidance-2026-09-08.md) — the 2026-09-08 Day 1 baseline, authorized Day 2 expansion, pinned request-preview evidence, and unsubmitted ontology-guidance recommendations.
- [Method model draft](method-model-draft.md) — the SDP methods/aggregation
  design record. **Normative since sdp-0.3.0**: ported to `smn-data-pkg`
  2026-08-14, so the spec is the authority and this card holds the reasoning.

## Validation

From this repo's root, with a sibling `psc-data-systems` checkout:

```sh
uv run --project ../psc-data-systems psc-okf check knowledge --tier capture
```

The queue is checked separately, from the repo root, with no sibling checkout
and no network call:

```sh
python3 scripts/hub_queue.py lint    # the queue files themselves
python3 scripts/hub_queue.py check   # every generated block still matches them
```

The `okf_version` declared in this file's frontmatter is unchanged by the
coordination change. Brett's Q34 ruling of 2026-09-09 moves this bundle to
upstream OKF v0.2, and the first command above with it, but sequences that
migration after the coordination change, so it is not this one.
