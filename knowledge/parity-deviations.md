---
type: InformationObject
title: "Parity deviations — metasalmonpy vs metasalmon"
description: "The hub twin of metasalmonpy's PARITY.md: every deliberate difference between the R package and its Python mirror, with kind and rationale. The two registers must agree."
status: draft
tags: [parity, mirror, s10]
psc:
  id: metasalmon:parity-deviations
  contexts: [metasalmon:context:hub-coordination]
---

# Parity deviations — metasalmonpy vs metasalmon

The mirror contract requires the same behaviour and capabilities at the
version metasalmonpy claims — **not** literal API mimicry (Brett,
2026-08-15): do not force 100% parity where it would be unintuitive for
Python users, and simple language differences that do not materially change
behaviour or capability are fine. Every deliberate difference is recorded
here **and** in metasalmonpy's `PARITY.md`; the two registers must agree. An
undocumented difference is a contract violation even when the difference
itself is fine.

Three kinds of entries: **Idiom** (same behaviour, Pythonic delivery),
**Ahead** (Python already has semantics R adopted later), **Inapplicable**
(no Python counterpart, with the why).

| # | Kind | Difference | Why |
|---|---|---|---|
| 1 | Idiom | Errors are Python exceptions with actionable messages, not R cli conditions | Language idiom; same conditions trigger them |
| 2 | Idiom | Optional dependencies are extras (`metasalmonpy[eml]`, `[knb]`), not Suggests | Packaging idiom; same lazy-guard behaviour and install pointers |
| 3 | Idiom | Canonical ordering uses codepoint `sorted()`, not explicit C-collation flags | Python's default sort is already locale-independent; the contract (locale-independent deterministic output) is identical, and `locale.strxfrm` is banned |
| 4 | Idiom | Archive/EML/ORE parity is contract-level (structure, manifest, ordering, fail-closed), never byte-level | R's bytes come from zip-3.0.1/libxml2 formatters Python cannot and should not reproduce |
| 5 | Ahead | `infer_value_type` is public API in Python, internal in R | Was already exported at 0.1.6; removing it would break users for no capability gain |
| 6 | Ahead | A failed or empty ontology fetch raises in Python; 0.1.6-era R returned an empty index | Failed lookup ≠ empty lookup; R adopted the same principle at 0.2.2 |
| 7 | Ahead | `is_statistical_modifier` is a real column in both Python term-index frames; R's TTL path carries it only inside `role_hints` | Saves the 0.3.0 milestone a retrofit; hint strings match R exactly |
| 8 | Inapplicable | No interactive term-request console in Python, so R 0.2.0's cancel-must-not-submit semantics have no counterpart | Submission is a single explicit function call with confirmation |
| 9 | Planned (0.1.8) | `write_sdp_methods` will not be implemented in Python; registry read/validate only | The writer would exist only to be deleted at 0.3.0 in the same replay; logged in the [S10 execplan](plans/2026-08-15-s10-metasalmonpy-parity-replay.md) |
| 10 | Idiom | The SSSOM header is parsed with a restricted YAML-subset parser, not a YAML library (R uses `yaml::yaml.load`) | pandas+requests dependency policy; out-of-subset YAML raises the same "not valid YAML" report, and duplicate-key/quoting/comment behaviours are differentially tested against R |
| 11 | Idiom | The SSSOM manifest provenance block names `metasalmonpy.write_sdp_sssom` + its version; R names its own. Each validator accepts either implementation's provenance | Provenance should be honest about which implementation wrote the artifact; the TSV mapping-set bytes stay byte-identical across languages |
| 12 | Idiom | The `measurement-decompositions.json` provenance block names `metasalmonpy.write_sdp_measurement_decompositions` + its version; each validator accepts either implementation's provenance | The row-11 honest-provenance ruling applied to the 0.1.7 decomposition artifact; the artifact binding (path, sha256, row_count) and the decomposition CSV bytes stay byte-identical across languages |
| 13 | Ahead | Python's SSSOM and decomposition writers treat a dangling symlink at a managed output path as existing (blocked without `overwrite`, then refused as a symlink); R's `file.exists()` misses dangling symlinks and silently writes through them | Fail-closed writer safety; read-side symlink handling matches R exactly |

Maintenance: a new deviation is added in the same PR that introduces it, in
both registers, in the same stream.
