---
type: Artifact
title: "S10 metasalmonpy parity replay 0.1.6 → 0.3.0"
description: "ExecPlan bringing the Python mirror from its 0.1.6 parity claim to metasalmon 0.3.0 — rungs 0-3 replayed release-by-release, the remainder ported by subsystem after the replay was found to be building things metasalmon had already removed."
status: draft
tags: [execplan, s10, parity, metasalmonpy]
psc:
  id: metasalmon:plan:2026-08-15-s10-metasalmonpy-parity-replay
  contexts: [metasalmon:context:hub-coordination]
---

# S10 — metasalmonpy parity replay, 0.1.6 → 0.3.0

Evidence base: a three-agent recon (2026-08-15) that mapped every metasalmon
release 0.1.7–0.3.0 from NEWS, inventoried the current Python tree, and
synthesized the gap matrix. Three of its claims were spot-verified against
the working trees; the essentials are distilled here so the plan stands
alone. Each milestone's implementer reads the corresponding metasalmon NEWS
section and the R files it names — R is the complete spec for every port.

## Decisions (logged)

| Decision | Rationale | Date |
|---|---|---|
| **Registry writer-only skip at 0.1.8.** `read`/`validate` for `metadata/methods.csv` are implemented (Python receives R-written 0.2.x packages carrying registries, and 0.1.8–0.2.6 EML documents used procedures from them); the `write_sdp_methods` surface is skipped with this logged exception | No Python user ever existed at 0.1.8 parity needing to write registries; the writer would exist only to be deleted at 0.3.0 in the same stream; Brett rejected per-package registries in the method model. Flagged for veto in the 2026-08-15 report | 2026-08-15 |
| **PR 0 ships un-bumped parity debt first.** The smn/gcdfo term indexes are stubs returning empty frames (`term_search.py:505-510`), so the existing 0.1.6 claim is overstated; PR 0 makes it true and carries no version bump | A bump asserts parity; PR 0 restores an existing claim rather than making a new one. 0.1.7 inference fixes, 0.2.2 caching, and 0.3.0 modifier sourcing all attach to these indexes | 2026-08-15 |
| **The typed reader is born NA-safe.** At PR 3, `read_salmon_datapackage` gets `keep_default_na=False, na_values=["", "NA"]` (exact R-0.2.0 read parity), tightened to `na_values=[""]` at PR 5. The destructive pandas default (which silently converts literal "NA" gear codes) must never exist in any tagged state | A tagged state with pandas default NA parsing would be strictly worse than the R defect 0.2.4 fixed — read→edit→write bakes the loss into bytes | 2026-08-15 |
| **specVersion misstatement is closed at PR 3, not before.** Python stamps `sdp-0.2.0` today from pre-0.2.0-behaviour code; rolling it back would churn user packages | Known, bounded misstatement; recorded here and in the CHANGELOG at PR 3 | 2026-08-15 |
| **Archive parity is contract-level, not byte-level.** Python defines its own `zipfile` determinism reference; the R↔Python CI job asserts manifest/ordering/fail-closed, never bytes | R's determinism is `zip`-3.0.1-specific; cross-language bytes cannot match | 2026-08-15 |
| **0.3.0 ports from the merged release tree** (metasalmon main at the v0.3.0 merge, `5a37b11` — never any intermediate review-round commit; `f76ed4f` was only round one of five and lacks the rollback, role-hint, placement-validation, ordering, and method-promotion fixes), and the FINAL R fixture suite lands as pytest BEFORE the code | Five review rounds hardened the migrator (stop taxonomy, atomicity, dry_run typing, rollback); porting any pre-merge snapshot would tag 0.3.0 with known audited defects | 2026-08-15 |

### 0.1.7 dependency decisions (logged 2026-08-15, from the dependency recon)

| Decision | Rationale |
|---|---|
| **EML: build with stdlib ElementTree; validate with lxml as an optional extra; vendor the EML 2.2.0 XSD set (27 files, ~1 MB) as package data with its NCEAS/EDI notices** | R's document is one namespaced root with unqualified descendants — fully within ElementTree (already the repo convention via `edh_xml.py`). lxml IS libxml2, the identical engine behind `emld::eml_validate`, so accept/reject semantics match R by construction. metapype rejected: forces a 3.11 floor, validates against its own rule set rather than XSD, and its builder API would turn the node-for-node port into a rewrite. Fallback if lxml is ever unacceptable: `xmlschema` (weaker parity, 3.10 floor) |
| **DataONE: raw REST via `requests` behind a Python adapter mirroring R's 14-method boundary — no dataone.libclient** | The library is dormant (no release since mid-2023) with a disproportionate tree (PyXB fork, aiohttp, rdflib, cryptography) for a pandas+requests package — and R itself already bypasses it for roughly half the surface (anonymous reads, capabilities, formats, Solr are raw httr2; the ORE map is hand-built with xml2). The genuinely-library-provided part is ~11 REST endpoints and a flat single-namespace SystemMetadata document (~300–500 lines). The adapter seam keeps a future swap cheap and mirrors R's `metasalmon.knb_adapter` injection point |
| **Extras: `eml = ["lxml>=5,<7"]`, `knb = ["metasalmonpy[eml]"]`; core stays pandas+requests** | Mirrors R's Suggests-with-runtime-guard pattern (`emld`/`dataone`/`datapack`); lazy imports raise actionable install messages |
| **EML/ORE parity tests assert structural equivalence (`ET.canonicalize`), never bytes** | Python cannot match libxml2's formatter byte-for-byte; consistent with the existing contract-level archive ruling |

### Replan: rungs 4–8 become a subsystem port (Brett, 2026-08-17)

| Decision | Rationale | Date |
|---|---|---|
| **Stop replaying releases after rung 3. Port the remainder by subsystem against the `v0.3.0` tag, and bump straight to 0.3.0** | The replay was implementing behaviour metasalmon had already deleted — rung 2 built a reader for a registry sdp-0.3.0 removes, and rung 1 shipped a decomposition component annotated "it dies at 0.3.0". The replay's real value is *differential verification*, which needs chunking but not *chronological* chunking; per-subsystem chunks against `v0.3.0` give the same reviewability without the dead work. The version contract permits the jump: it requires the claimed number to be true, not that every number be visited. **Reverses if** a consumer appears pinned to an intermediate metasalmonpy version, or a defect is traced to something only an era-by-era replay would have caught | 2026-08-17 |
| **The breaking change moves from last to first.** 0.3.0's dictionary-contract flip was rung 8 because it is atomic; that ordering meant every earlier rung built on a shape it replaces. Chunk A lands it first | Nothing built after A sits on a superseded shape. This inversion is what the replan buys | 2026-08-17 |
| **Legacy *read* support is kept and is not a reason to replay.** Python receives SDPs written by metasalmon 0.2.x carrying a methods registry, and 0.1.8-era EML quotes procedures from one | Real data-compatibility need, already satisfied at rung 2; it is a feature of the 0.3.0 port, not an argument for implementing 0.2.x in order | 2026-08-17 |

### Decisions logged during the subsystem chunks

Both were made by an implementer inside a chunk, not by Brett, and both are
recorded here because the chunk that made them is the only other place they
exist. Neither is a mirror-contract question — the first is Python-only surface
naming, the second is a scope boundary between two chunks.

| Decision | Rationale | Date |
|---|---|---|
| **The `SALMONPY_*` → `METASALMONPY_*` env-prefix rename ships with deprecated aliases, and the aliases are removed in the first tagged release after the S10 parity release.** The pre-rename spellings keep working, warn **once per process**, and are consulted only when the current spelling is unset or empty. Test-suite-only gates (`METASALMONPY_RUN_QUALARK_TEST`, `METASALMONPY_QUALARK_TEST_*`) were renamed **cleanly with no alias** | This is the dated decision **open decision 1b** asked for, and it takes the middle option 1b listed. No known external consumer ever existed at any parity level metasalmonpy has claimed, so one release of overlap is already generous; keeping two live spellings of a cache switch beyond that invites the silent divergence the register exists to prevent. Developer knobs are not package API, which is why the Qualark gates got no window. Registered as parity row **50** with the retirement condition in both registers | 2026-08-22 (chunk E, metasalmonpy PR #17) |
| **URL redaction splits across E and F by layer: the call *sites* are E-scope, the *pattern* they call is F-scope** | 0.2.3's URL redaction was written into chunk F's scope line, but E is the chunk that rewrites `_safe_json` — so E added the capture-time redaction call sites and F strengthened the shared pattern to 0.2.5's structural rule, which the E sites inherit automatically. Splitting by layer rather than by release keeps each chunk's diff reviewable and makes F's one-redactor assertion meaningful, since it is only meaningful over E's final call-site set | 2026-08-22 (chunks E and F, metasalmonpy PRs #17 and #19) |

## The ladder — rungs 0–3 replayed, the remainder ported by subsystem

Each milestone = one PR ending in a version bump (both `pyproject.toml` AND
`__init__.py` — scripted, they drift; CHANGELOG entry; tag; GitHub release).

0. **Parity debt, no bump** — real smn/gcdfo term indexes replacing the
   stubs; clean stale `dist/` artifacts. Blocks everything below.
1. **0.1.7** — EML export, KNB/DataONE (plan/dry-run/live/revision),
   deterministic ZIP (Python-native reference), SSSOM, measurement
   decompositions (with the transitional `method` component — it dies at
   0.3.0), inference fixes. Heaviest milestone; two dependency decisions
   (DataONE client, XML emission) are logged decisions when made. Design the
   redactor as ONE function now (0.2.5 foresight).
2. **0.1.8** — registry read/validate (writer skipped per decision),
   observation structures, reproducibility manifest, reviewed-strategy
   apply, expanded KNB, **the `package_io.py:29-35` host fix**
   (dfo-pacific-science → salmon-data-mobilization; a constant swap — the
   URLs are stamped, never fetched), demo-data fixes, `match_type` ranking
   fix. Vendored bundle taken from the upstream **`sdp-0.2.0` git tag**
   (main is 0.3.0-shaped and lacks `methods.schema.json`).
3. **0.2.0 + 0.2.1 collapsed** — typed round-trip reader (dictionary as sole
   type authority; raw-token preservation; float-vs-Int64 is a logged
   decision either way), overwrite/prune ownership, the remote schema
   loader **born pinned to the `sdp-0.2.0` tag** with an override, 0.2.1's
   per-resource URLs derived from that same loader (collapsing avoids
   building an interim shape only to rewrite it), tie-break keys, sidecar
   survival, datetime/date inference (public API in Python — behaviour
   change), symlink refusal, capture-time redaction. Two tagged bump
   commits inside one PR keep the number line intact.

### Rungs 4–8 superseded — the remainder is a subsystem port to 0.3.0

**Superseded 2026-08-17 (Brett).** Rungs 4–8 replayed 0.2.2, 0.2.3, 0.2.4,
0.2.5, 0.2.6 and 0.3.0 in order. They are replaced by a single port organised
by **subsystem**, verified against the **`v0.3.0` tag**, taking the version
straight from rung 3's number to **0.3.0**.

**Why.** The replay was building things metasalmon had already removed. Rung 2
implemented read/validate for `metadata/methods.csv`, a registry sdp-0.3.0
deletes from the spec — its writer was skipped with a note saying it "would be
written only to be deleted in the same catch-up stream." Rung 1 shipped the
transitional `method` decomposition component annotated "it dies at 0.3.0." The
ladder had already been collapsed once for this reason (rung 3 merged 0.2.0 and
0.2.1 "to avoid building an interim shape only to rewrite it"), so the
rung-per-release granularity was never load-bearing; it had simply never been
re-examined whole.

**What the replay was actually buying, and why chronology is not required for
it.** Its value is *differential verification* — running both implementations
over the same inputs caught about a dozen divergences at 0.1.7 and more at
0.1.8, which reading R source had missed. That value comes from **chunking**,
not from *chronological* chunking. Chunking per subsystem against `v0.3.0`
gives the same reviewability, and a divergence in behaviour that 0.3.0 deleted
is not a divergence worth finding.

**The version contract permits the jump.** `AGENTS.md` says the version *is a
parity claim*, bumped when the mirrored behaviour lands. It does not require
visiting intermediate numbers — it requires that whatever number is claimed is
true.

**What is genuinely kept from the chronology.** Python receives SDPs *written
by* metasalmon 0.2.x that carry a methods registry, and 0.1.8-era EML documents
quote procedures out of one. Legacy **read** support is therefore real — but it
is a data-compatibility feature of the 0.3.0 port, already landed at rung 2, not
a reason to implement 0.2.x releases in order.

**What this gives up:** the ability to say metasalmonpy was verified at each
historical point. No consumer needs it; see the rung-2 decision recording that
no Python user ever existed at that parity level. **The risk it takes on** is a
larger diff with fewer checkpoints, mitigated by per-subsystem differential
verification rather than per-release.

**What would reverse this decision:** a consumer appearing that is pinned to an
intermediate metasalmonpy version, or a defect traced to a behaviour that only
an era-by-era replay would have caught.

### The subsystem chunks

**A comes first among the chunks that depend on it**, and that inversion is the
point of the re-plan: 0.3.0's breaking change was rung 8 precisely because it is
atomic, which meant everything before it was built on a shape it replaces. Doing
it first means nothing built on that shape is. Read "first" as *before B and G*,
not as *before everything* — see **Ordering** below, which the table's top-to-
bottom order otherwise makes it easy to read as a ladder.

| # | Subsystem | Scope |
|---|---|---|
| **A** | **Spec conformance and the dictionary contract** *(breaking; B and G depend on it)* | Methods leave `column_dictionary`; `statistical_modifier_iri` replaces `method_iri`; registry removal with errors that point at migration; `migrate_sdp_methods` with the full hardened stop taxonomy, **every stop firing in the dry run as well as the real run**; the three placements (`tables.csv$method_iri`, `protocol_iri`/`protocol_citation`, `codes.csv$term_iri`); default and strict placement-IRI checks; pin flip to `sdp-0.3.0`; the bundled demo dictionary and metadata *(corrected 2026-08-22: this cell claimed the Python copy was "well-formed but still ends `method_iri`" — **false**. The file was semantically corrupt: two unquoted description commas shifted the RUN_TYPE and ESTIMATE_STAGE rows' fields into schema-invalid `column_role`/`value_type` values, exactly as this plan's own exposures table below had already recorded from the 2026-08-21 recon — the two claims sat unreconciled in one document. Chunk A replaced the file with a byte-copy of metasalmon `main`'s)*; **EML method steps from the placements** — `write_eml_from_sdp()`'s `methods` becomes the placements tibble and `used_methods` the used-procedure IRIs, with reviewed-closure gating; **the `_atomic_write_set` rollback fix**; **backlog #86 / register row 33**, the `sdp_methods.py` whitespace class |
| **B** | **Semantic pipeline retarget** *(after A)* | Semantic retarget to `statistical_modifier`; **three `statistical_modifier` rows in the ranking-preferences data** (`data/ontology-preferences.csv`, still on the pre-0.3.0 role set `constraint`/`entity`/`method`/`property`/`unit`/`variable`/`wikidata`); the bundle-review prompt naming `statistical_modifier` rather than the removed dictionary `method` slot; **`SEM_MODIFIER_EVIDENCE_REQUIRED`**, added *beside* the surviving `SEM_METHOD_EVIDENCE_REQUIRED` (`llm_review.py:1529`) and not replacing it — the code-level `method` role survives 0.3.0; a static role-contract guard **scoped to the six surfaces Python has**, and saying so (below). **B inherits a documented five-slot intermediate state from A** (2026-08-22): post-A, measurements review five column slots and the bundle's method slot arrives `already_filled_or_not_requested` with no candidates — deliberate, with breadcrumbs naming this chunk in metasalmonpy `tests/test_llm_review.py` |
| **C** | **Missing-value contract** *(standalone, never diluted)* | Single NA helper, read/write sweep, literal-`"NA"` round-trip guard. Bytes on disk — it wants an undiluted diff. **C also owns regenerating the era EML structural fixtures** (`tests/data/eml/`, noted 2026-08-22): register row 22's live divergence — `_ERA_NA_TOKENS` still governing the EML raw-token audit — actively blocks regenerating them against current R, so chunk A deliberately left them era-shaped; they stay so until this chunk retires the split |
| **D** | **Validation hardening** | Primary-key uniqueness and NA errors, value-like-name warnings (thresholds exact; the message points at `melt`), placeholder surfacing. **D inherits register row 48 from chunk C** (2026-08-22): metadata review placeholders diverge in coverage and prose — R fills `creator`/`contact_name`/`contact_email`/`license` where Python leaves them empty, and the prose differs where both fill — to be converged by measuring current R, not by porting the row's examples |
| **E** | **Cache, environment and network robustness** | Index session caching; **call-time env read** (`SALMONPY_CACHE` is read at import today — the exact bug class R 0.2.2 fixed); the `SALMONPY_`→`METASALMONPY_` prefix rename — **open, see below**; http-error diagnostics; no-cache-on-degraded; KNB dry-run overwrite; retry and `Retry-After`; BioPortal header auth (`term_search.py:300` still puts the key in the query string) |
| **F** | **Redaction** | Structural `*_token` redaction; assert exactly **one** redactor (`knb_publication._redact` is the second one, and `text_safety.py:56-68` already carries the retirement condition naming this chunk); **0.2.3's URL redaction** — R passes request URLs through the same `.ms_redact_secrets()` at capture (`R/term_search.R:592`, `:606`), which is why the one-redactor assertion and the URL rule belong together |
| **G** | **Legacy read compatibility** *(verify, do not rebuild)* | Reading 0.2.x-written packages that carry a methods registry, and 0.1.8-era EML quoting procedures from one. Landed at rung 2 — confirm it survives A. **Partly discharged by A itself** (2026-08-22): the untouched `methods-sdp` legacy fixture (`tests/data/sdp-extensions/methods-sdp`) kept the reader and validator exercised through A's rewrite, so what remains here is deliberate re-verification of the legacy read path, not first evidence that it works |
| **H** | **Abort-safe write path** *(added 2026-08-22 — the metasalmon PR #77 mirror, backlog #96's ordering half; no earlier chunk routed it. **In flight 2026-08-22**, on branch `feat/s10-chunk-h-abort-safe-write`; D and E+F, the chunks it was sequenced behind, are complete)* | Render-first/install-atomically ordering for `write_salmon_datapackage()`: render the full write set to bytes before anything on disk is touched, install through a multi-file staged write set with rollback, unlink unrewritten managed paths only after the install succeeds. The Python ordering defect is **measured present** (2026-08-22, backlog #96's mirror measurement): `package_io.py::write_salmon_datapackage` calls `_prepare_package_dir()` — which unlinks the managed paths, or `shutil.rmtree`-wipes under prune — and only afterwards renders resources, loads the schema, builds the descriptor and writes metadata, so any exception in that window destroys the package; `atomic_io.py` has a single-file `atomic_write()` only, no multi-file set with rollback. Sequenced **after D and E+F** (both in flight when this row was added): it is write-path work in `package_io.py`, the module D also touches, so running it beside them repeats the rebase cost the *Ordering* section retired for A — an ordering choice, not a dependency. R's implementation is the spec: `.ms_commit_package_write()` / `.ms_sdp_extension_atomic_write_set()` and the abort-injection tests in `test-write-datapackage-abort-safety.R`, including the two honest narrowings (`prune` residual, create-owned sidecars = backlog #111) |

#### Behaviours added to the chunks 2026-08-21

A NEWS sweep found five observable metasalmon behaviours that no chunk named.
All five are now in the table above; where each landed, and why, is below —
because a one-line table cell cannot carry the reason, and the reason is what
stops the next reader moving it.

- **0.3.0's EML method-step rewrite → A.** Not merely a rename: A *deletes* the
  registry, and `eml.py` reads it today — `write_eml_from_sdp()` returns
  `methods` = the registry frame from `read_sdp_methods()` and `used_methods` =
  the registry subset bound to observed measurements (`eml.py:3488-3524`,
  `_used_sdp_methods` at `:2941`). R 0.3.0 makes `methods` the **placements**
  tibble and `used_methods` the **used-procedure IRIs**, and gates every
  vocabulary IRI the method path emits inside the reviewed closure (a
  table-level `method_iri` needs an accepted ledger row; table-level and used
  row-varying procedure IRIs must appear in the vocabulary snapshot; protocol
  IRIs are citations and are not gated). It lands in A because A is what breaks
  it — leaving it out means A ships an `eml.py` reading a file the same chunk
  removed. Note the interaction with **G**: G keeps the *reader* of a legacy
  registry alive, which is not the same code path as the writer of method steps.
- **`SEM_MODIFIER_EVIDENCE_REQUIRED` → B.** Python has
  `SEM_METHOD_EVIDENCE_REQUIRED` (`llm_review.py:1529`) and no modifier
  counterpart. R keeps **both** (`R/semantic-bundle-validators.R:122`, `:154`),
  so this is an addition, not a retarget; the modifier validator holds an accept
  to the same aggregation evidence (mean/median/max/min/total/peak) the
  suggestion path requires. It is one of the six role surfaces below, which is
  the reason it cannot be deferred past B.
- **Backlog #86 / register row 33 → A.** `sdp_methods.py:95` `_is_absolute_iri()`
  matches whitespace with Python's `\s` instead of the enumerated
  `metadata.R_SPACE_CLASS` that `eml.py` and `sssom.py` both import; 8
  codepoints disagree and Python is the stricter side. A rewrites that module
  anyway, so the constant import and the membership test in
  `tests/test_sdp_methods.py` are cheapest there. *Retires when:* both regexes
  are built from `R_SPACE_CLASS` and the membership is pinned by a test.
- **0.2.3's URL redaction → F** (see the chunk row).

**0.3.0's atomic-writer rollback fix → A**, and it is a live defect rather than
a missing feature. `sdp_methods.py:_atomic_write_set` mirrors R's writer
faithfully, *including* the bug 0.3.0 fixed: when `rollback()`'s
`os.replace(backup, path)` raises, it warns without naming the backup and leaves
`backups[index]` set, so the `finally: cleanup()` unlinks the only surviving
copy of the original bytes. R's fix detaches the backup from the cleanup list
and names the file in the warning (`R/sdp-extension-helpers.R:206-216`). A owns
this because A rewrites `sdp_methods.py`; `observation_structures.py:974` is the
other caller and inherits the fix.

#### The role-contract guard reaches six of seven surfaces, and must say so

`AGENTS.md` counts **seven** surfaces a semantic role has to reach. Six have
Python counterparts, all verified present 2026-08-21:

1. target/role maps — `semantics.py:1127` `role_to_field`, `:24`
2. bundle roles and slot fields — `semantics.py:737`
3. the role-hint vocabulary — the emitter is **already ahead of R** here
   (register row 7); `term_search.py:721` emits `is_statistical_modifier`
4. retrieval filters — `sources_for_role()` at `term_search.py:1054`
5. deterministic validators — the `SEM_*` family, `llm_review.py:1529-1611`
6. ranking preferences — `data/ontology-preferences.csv` is real and is
   consumed at `term_search.py:960` via `_load_role_preferences()`

**The seventh has no counterpart to guard.** In R, `role_boost` lives inside
`.ranking_profile_defaults()` (`R/term_search.R:2060`) — a named, mergeable,
overridable defaults table, which is what lets
`tests/testthat/test-smn-outranks-gcdfo.R` enumerate every ranked role and
assert each has a boost entry. Python has no profile system: `role_boost`
survives only as an inlined dict literal inside `_score_and_rank_terms`
(`term_search.py:972`), with no `ranking_profile` parameter, no defaults
function to enumerate, no override path — and no `statistical_modifier` key,
where R now carries `c(smn = 1.5, ols = 0.4)`. That absence is backlog **#87** /
register row 32, logged as out of scope below, so **chunk B cannot guard the
seventh surface.**

Therefore the Python guard **states its own scope**: the six surfaces by name,
`role_boost` named as the one it does not reach, and #87 named as the condition
that would let it. This is `AGENTS.md`'s rule applied to itself — *"a guard
whose claimed scope exceeds its real scope is worse than a missing guard,
because green means all seven verified to the person reading this line."* A
guard called "the role-contract guard" that silently covers six is exactly the
failure that shipped `statistical_modifier` broken through CI and PR review on
the R side. *Retires when:* #87 lands a Python `ranking_profile_defaults()` and
the guard is extended to seven — or R consolidates its seventh check into
`test-role-contract-guard.R` and Python mirrors the consolidated file.

*(This section replaces "all six surfaces" and "the six-surface role-contract
guard", which were correct when written on 2026-08-17 and stale within a day:
`role_boost` was named as the seventh surface that same day, and `AGENTS.md`
recorded the split guard coverage on 2026-08-18. Corrected here 2026-08-21.)*

#### Chunk H added 2026-08-22 — the PR #77 write-path mirror was unrouted

metasalmon PR #77 (the abort-safe transactional `write_salmon_datapackage()`,
merged 2026-08-22 — backlog #96's ordering half) landed mid-stream: **new R
behaviour with no Python mirror and no chunk routing it.** The chunk table
predates it, chunk C was contractually undiluted (missing-value bytes only)
and flagged it for the hub rather than absorbing it, and the defect it fixes
is *measured present* in Python (backlog #96's 2026-08-22 mirror measurement,
restated in the chunk-H row above). An unrouted mirror obligation is exactly
the state the mirror contract calls a violation-in-waiting, so it is now
chunk **H** — its own small item rather than a rider on D or E: D's subject
is validation reporting and E's is cache/network, while this is write-path
*ordering*, and PR #16's own flag said "chunk C's neighbourhood or its own
item" with C already closed. It runs after D and E+F for the
rebase-cost reason stated in its row, not because anything in them blocks it.

**Now in flight (2026-08-22).** D and E+F have all merged, so the rebase-cost
reason for sequencing H behind them is spent and H started: branch
`feat/s10-chunk-h-abort-safe-write`, cut from metasalmonpy `main` at `258db8d`
(the chunk-D merge). No PR yet at the time of this entry. **H is the last
subsystem chunk** — after it the only remaining S10 scope is the terminal
version bump, which waits on Q7 / open decision 2 and on nothing else.

### Ordering — only two chunks are forced after A

**Only B and G depend on A.** B retargets the semantic pipeline onto the
dictionary shape A introduces; G verifies that legacy registry *reading*
survives A deleting the registry, so it has nothing to verify until A lands.
**C, D, E and F depend on nothing in A** and may be started before it, beside
it, or after it in any order — they are 0.2.2–0.2.6 behaviours in subsystems A
does not reshape (the missing-value contract, the tidy/validation checks, the
cache and network layer, redaction). *(Recorded 2026-08-21 because the reverse
was the natural reading: the chunk table runs A→G down the page, and "A must
land first" sat above it unqualified. Nothing in the 2026-08-17 replan intended
a serial ladder — it intended one inversion.)*

Two coordination notes that are **not** dependencies. C and D both touch
`package_io.py`, which A also edits, so they will conflict on merge if run
concurrently; that is a rebase cost, not an ordering constraint, and it should
not be recorded as one. And because the single version bump is at the end, the
order chunks land in has no effect on what any released number claims.

One version bump to **0.3.0** at the end, not one per chunk — but *which* number
that bump may be is an open decision, not a settled one; see **Open decisions**
below.

**A is not blocked upstream.** Verified 2026-08-21: `smn-data-pkg` carries an
**annotated `sdp-0.3.0` tag** ("Salmon Data Package spec sdp-0.3.0: method-model
change"), alongside `sdp-0.2.0`. So A's two upstream-facing scope lines — the
`SDP_SPEC_TAG` pin flip and the vendored-bundle swap, which `PARITY.md` rows 27
and 38 require to move together — can proceed today. Several documents in this
bundle describe the pin flip as *pending* in a way that reads as *waiting*; it
is only unstarted.

**Verification changes with the plan.** Differential runs go against the
**`v0.3.0` tag** (annotated, so `git archive v0.3.0 | tar -x` is exact), not
against era tags. A byte-equality claim measured at or after R 0.2.0 needs no
locale caveat — R adopted C collation at 0.2.0 — while anything measured
against ≤0.1.8 does. Say which was used.

**The behaviour-defined scope survives unchanged.** Chunks A and B MUST carry
metasalmon's post-0.3.0 fixes, not just the release tree: the three
`statistical_modifier` ranking rows, the corrected bundle-review prompt, the
dry-run stop parity, and the role-contract guard. If a pin and that list ever
disagree, the list wins — it is the reason the pin exists. **Note that this
paragraph and the one above it are not fully reconciled:** "verify against the
`v0.3.0` tag" and "carry metasalmon's post-0.3.0 fixes" name two different R
trees. The "list wins" rule settles *scope* — the named fixes are in — but it
does not say which tree a differential is run against for everything else, and
metasalmon is now **107 commits past `v0.3.0`** (measured 2026-08-21 against `v0.3.0..main`). That
unstated baseline is the same question the version decision turns on.

**Resolved in practice at chunk A (2026-08-22), pending a ruling.** Chunk A's
differential ran against metasalmon **`main` at the moment of measurement** —
`e02111a`, the v0.3.0 release tree plus every post-0.3.0 fix including PR
#75's recon wave — with all four R-derived fixture families regenerated at
that commit and re-verified byte-identical after `main` moved mid-stream.
That is the operative convention for the remaining chunks unless open
decision 2 rules otherwise: not the `v0.3.0` tag, not a frozen post-tag
commit, but current `main` when the chunk's fixtures are cut, **named by
commit** so the claim stays checkable. It is also a data point *for* the
decision, not a substitute for it — see open decision 2 below and hub Q7.

## Open decisions — recorded as open, not as preferences

Three questions this plan needs answered before the chunks can finish. None has
a decider or a date behind it, so **nothing below is a ruling** and no option is
endorsed — the options are listed so a decider sees the field, not so a reader
infers a preference from the order. All three were surfaced or restated
2026-08-21, and two of them (1b and 2) are live disagreements between two
documents rather than unfilled blanks, which is the harder kind: each side reads
as settled on its own page.

### 1. What must metasalmonpy 0.3.0 contain?

Two known divergences predate the 0.1.6 parity claim and **no chunk owns
either** — both are logged out of scope below:

- **#87 / register row 32** — no ranking-profile system; candidate *order* can
  differ for the same query outside the pinned `smn`/`gcdfo` comparison, and
  `benchmark_term_ranking_fixtures`, the surface that would measure a ranking
  regression, discards its `profiles` argument.
- ~~**#91 / register row 41** — `validate_salmon_datapackage()` reports through a
  different mechanism: R tags eight `issue_type` values and collects all
  findings before one abort, Python raises untyped at the first structural
  problem.~~ **Closed at chunk D (2026-08-22), which settles this half of the
  decision in practice rather than by ruling:** D scoped #91 in — option (a)/(b)'s
  #91 arm — and closed it, so 0.3.0 will not have to choose whether to ship with
  it open. See the chunk D progress section below.

**Half of this question is now moot.** #91 was closed at chunk D
(2026-08-22) without the decision ever being made — the chunk scoped it in,
which is option (a)/(b)'s #91 arm taken by an implementer rather than by a
decider. So **only #87 is still live here**, and the question below should now
be read as being about #87 alone.

*The question (as originally posed, over both items):* does the **0.3.0 parity
claim require closing them**, or may 0.3.0 ship with both open and documented as
register rows? The mirror contract
supports either reading — it says a deliberate difference is legitimate once
recorded in both registers, and both *are* recorded; but it also says the
version number is a parity claim, and these are behavioural gaps rather than
deliberate design choices, which is a different kind of difference.

*Options, none preferred:* **(a)** scope both into 0.3.0 — #91 into chunk D (the
only chunk whose subject is that function, though D's stated scope is
primary-key and placeholder behaviour, not the reporting mechanism) and #87 into
a chunk or stream of its own, since it needs a profile system rather than a
pass-through; **(b)** scope #91 in and leave #87 to a later number, since #91
constrains verification design and #87 does not; **(c)** ship 0.3.0 with both
open, on the strength of the register rows.

*What it unblocks:* the chunk list is not final until this is answered —
(a) adds work to it. *(The two clauses that stood here, about whether chunk D
could be written at all without first ruling on #91, and about the verification
constraint that held while #91 was open, are both spent: D was written, it
closed #91, and the constraint is lifted. Struck 2026-08-22.)*

### 1b. The `SALMONPY_` prefix rename was never decided — struck 2026-08-21, **DECIDED at chunk E 2026-08-22**

Chunk E listed *"the `SALMONPY_`→`METASALMONPY_` prefix rename, **decided and
logged here**"*. **That claim is false about this document:** it contains no
decision record for the rename — no decider, no date, no rationale — and the
S10 sequence card has carried the same question as *undecided* since
2026-08-13. Two documents asserting opposite states with no evidence behind
either is worse than an open item, so the "decided and logged here" clause is
struck as an error and the question stays open, which is the resolution the
sequence card's retirement condition already offers.

**Decided 2026-08-22, at chunk E (metasalmonpy PR #17).** Rename **with**
deprecated aliases: `METASALMONPY_CACHE` / `METASALMONPY_DEBUG_FETCH` read at
call time, the `SALMONPY_*` spellings surviving as aliases that warn once per
process and are **removed in the first tagged release after the S10 parity
release**. The decision, its decider (the chunk-E implementer, not Brett) and
its rationale are in the *Decisions logged during the subsystem chunks* table
above, and its retirement condition is parity row **50** in both registers.
This satisfies the retirement condition below in the form it asked for: a dated
decision in one place, with the other document corrected to point at it in the
same change — the S10 sequence card is corrected in this same hub pass. Note
what the resolution was *not*: nobody located a prior ruling, because there was
none. The question was answered by making the decision, which is the honest
outcome when a document has been asserting a decision that never happened.

*The question:* was the prefix rename ruled, and if so by whom, and does it
carry legacy aliases? `SALMONPY_CACHE` and `SALMONPY_DEBUG_FETCH` are both
still live in `term_search.py` at 0.2.1. *Options:* rename with legacy aliases;
rename cleanly; document the old prefix as-is and never rename. The asymmetry
matters — documenting now and renaming later breaks anyone who set the variable
a *second* time, while renaming on an unlocatable decision breaks them once on
no authority. *What it blocks:* chunk E cannot be implemented as written, since
the rename is a scope line in it. *Retires when:* a dated decision naming the
decider lands in one place and the other document is corrected to point at it in
the same change.

### 2. What version number may the finished port carry?

This plan says **"one version bump to 0.3.0 at the end."** metasalmonpy's
CHANGELOG has since adopted a rule that points elsewhere. Its current
*Unreleased* section reads: *"Not a version bump: the parity claim stays at
metasalmon 0.2.1 because the metasalmon change mirrored here is in that
package's development version, not in a release. Bump on parity, not on
calendar."* Under that rule a metasalmonpy number claims a **released**
metasalmon version.

**The two reach opposite answers**, because this plan also requires chunks A and
B to carry metasalmon's **post-0.3.0** behaviour — the three
`statistical_modifier` ranking rows, the corrected bundle-review prompt, the
dry-run stop parity, the role-contract guard — none of which is in the `v0.3.0`
tree. metasalmon is **107 commits past `v0.3.0`** as of 2026-08-21 (measured against `v0.3.0..main`), with a
populated development-version NEWS section. So the finished port would deliver
behaviour that no metasalmon release contains, under a number naming a
metasalmon release.

*The question:* which number, and what does it claim? *Options, none preferred:*
**(a)** metasalmonpy 0.3.0 means "mirrors `v0.3.0` as tagged", and the
post-0.3.0 fixes are held back — which contradicts this plan's behaviour-defined
scope, and would knowingly ship the `statistical_modifier` role broken the way R
shipped it; **(b)** 0.3.0 means "verified against the R tree at the point the
chunks were done", naming the commit — honest, but it is not a claim about any R
release, which is what the CHANGELOG rule denies; **(c)** metasalmon cuts the
release containing those fixes first and metasalmonpy claims **that** number,
skipping 0.3.0 on the Python side — clean, but it makes the Python port wait on
an R release decision that is nobody's current priority, and it breaks the
version lockstep the mirror contract describes; **(d)** 0.3.0 plus an explicit
"and these named post-0.3.0 fixes" qualifier in the CHANGELOG and both
registers — cheapest, but it makes the number mean something a reader cannot
recover from the number alone, which is the property the parity-claim rule
exists to give it.

*What it unblocks:* the final bump and the roadmap release-index row — and,
before either, the **verification baseline**: which R tree a differential is run
against. This plan currently says the `v0.3.0` tag in one paragraph and
"post-0.3.0 fixes" in the next, so an implementer starting chunk A cannot read
the answer out of it. *Whoever decides this should correct both documents in the
same change*, or the disagreement simply moves.

*Data point (2026-08-22):* chunk A resolved the verification-baseline half in
practice — it measured against `main` at `e02111a`, option (b)'s shape,
recorded above as the operative convention while this decision stays open. Every
chunk verified this way widens the set of delivered behaviour that no existing
release number can truthfully claim, which strengthens hub Q7's standing
recommendation: cut the metasalmon release containing the post-0.3.0 fixes
first, and let metasalmonpy claim that number.

*Data points 2 and 3 (2026-08-22):* chunk B re-baselined mid-stream when `main`
moved under it (`39818ce` → `9d8f125`); chunks D, E and F measured at `9d8f125`
and `794647a` respectively, and E/F's move was a **re-pin rather than a
re-baseline** — they confirmed the R tree identical in `R/`, `tests/` and
`inst/` first. Six chunks, none measured against a release. The recurring cost
while no release exists is checking whether the target moved in a way that
matters; that is cheaper than re-measuring, and it is only cheap because someone
checks. Recorded in hub Q7, not resolved here.

## 0.1.7 progress (2026-08-16)

Four chunks committed on `feat/s10-017-parity`, none released — the version
stays 0.1.6 until the milestone completes, per the parity-claim rule.

| Chunk | What | Parity evidence |
|---|---|---|
| 1 | SSSOM 1.1 read/write/validate | Canonical TSV **byte-identical** to era R under C collation; three R-generated fixtures assert sha256 |
| 2 | Measurement decompositions (era shape, transitional `method` role) | Byte-identical, **unconditionally** — the only chunk whose claim needs no locale caveat |
| 3 | Reviewed EML 2.2.0 export | `ET.canonicalize`-equal to R; every UUIDv5 identifier exact |
| 4 | KNB/DataONE via raw REST, era 14-method adapter | Plan fingerprint, manifests, PIDs, Solr URL byte-exact; ORE + 9 SystemMetadata shapes canonically equal |

Then twelve defects from an adversarial review, each demonstrated against a
v0.1.7 extraction and each pinned by a test that fails on a source-reverted
build (38 failures confirmed). Deviations recorded as register rows 20–24.

**Milestone complete.** 0.1.7 shipped 2026-08-16 — merged, version bumped,
tagged `v0.1.7`, GitHub Release published. The two defects listed here as
remaining (`sssom.py`'s ASCII-only `\s`/`\S` against era R's Unicode-aware TRE,
and `package_io.py:538` taking pandas' full NA vocabulary untrimmed) were folded
in before the bump. Two Codex findings were also fixed at review: the
`atomic_io` umask dance, which two concurrent writes could leave permanently at
`000`, now measures the mode from a throwaway file instead of mutating process
state; and `eml.py` accepts a bare relative output path, which R already did.

### A correction that moves a later rung

The register's row 20 said R adopted C collation at 0.3.0. **It was 0.2.0** —
`R/sssom.R` uses `method = "radix"` throughout from that release. The locale
hazard is live only against era R (≤ 0.1.8). Two consequences: the 0.3.0 rung
below must NOT be relied on to deliver collation convergence, since it already
happened three rungs earlier; and any byte-equality claim measured against era
R needs its locale caveat, while one measured against 0.2.0+ does not. This is
also why an era claim must name the tag it was measured at — the same
comparison run against current `main` silently answers a different question.

## 0.1.8 progress (2026-08-17)

**Milestone complete.** 0.1.8 shipped 2026-08-17 — metasalmonpy PR #8 merged
as `db85016`, version bumped, tagged `v0.1.8`, GitHub Release published. The
rung carried the SDP method registry as **read and validate only**, the
writer landing as an exported raising stub rather than being absent (the
logged writer-only-skip decision above, now register row 9 and marked
*landed* rather than *planned*); observation structures; the reproducibility
manifest; reviewed-strategy apply; expanded KNB publication; the `package_io`
host fix; and the demo-data and `match_type` ranking fixes. The vendored
schema bundle now comes from the upstream `sdp-0.2.0` tag, which discharges
register row 27's retirement condition — the Python profile version is no
longer a literal — and creates row 30, which describes how that bundle is
read.

Verified the way the rung above was: by driving both implementations over the
same inputs against the R **`v0.1.8` tag**, not by reading R source.
`methods.csv`, both observation-structure files and the updated
`datapackage.json` came out byte-identical, and the KNB plan matched on all
20 objects — every PID and every checksum.

Deviations recorded as register rows 29–34. Two of them are about the same
mistake in opposite directions, and both are worth carrying forward. Row 34:
mirroring R's helper *layout* imported a constraint R does not have — `yaml`
is a hard `Imports` here, PyYAML is an extra there — and made the pure-stdlib
SDP archive require the `[eml]` extra to build; the fix moved the
reviewed-ledger binding assertions into the publication preflight, and the
core-deps property is now enforced by CI and by a `sys.meta_path` blocker
rather than asserted in prose (row 30). Row 29 is the converse: R had applied
the honest-provenance ruling to the reproducibility manifest's writer and not
its reader, so R **rejected** a Python-written manifest and, through
`R/knb-publication.R:297`, refused to publish any Python-written SDP to KNB.
Fixed R-side post-0.3.0 (backlog #88), with the accepted writer set
consolidated into `R/provenance.R` so a fourth manifest type inherits dual
acceptance instead of re-deriving it.

## Rung 3 progress (2026-08-18; outcome recorded 2026-08-21)

*As of 2026-08-18:* **written, not yet merged.** Rung 3 — `0.2.0 + 0.2.1`
collapsed — was metasalmonpy PR **#10** on `feat/s10-020-021-parity`, carrying
`0.2.1` in `pyproject.toml` and `__init__.py`; open and mergeable with checks
unstable, `main` still 0.1.8 at tag `v0.1.8`. The caution attached to that state
was: do not move the roadmap's release-index row to 0.2.1 before the tag exists,
because a branch version is not a parity claim an index can carry.

**It shipped, and that caution is discharged.** Verified 2026-08-21: PR #10
merged 2026-08-18 (`3fdd323`), `main` carries `version = "0.2.1"` in both files,
and the annotated tags `v0.2.0` (`7439145`) and `v0.2.1` (`f1d9b0e`) exist with
the GitHub Release published. **It was the last replayed rung** — the replan
above supersedes 4–8, so the next unit of work is chunk **A**, not a rung 4.
Rung 3's verification was the R↔Python round-trip (see *Verification* below),
which is why backlog #88 had to be fixed before it started rather than during it.

### What landed alongside it

**PR #11 — adjudication of the seven 0.2.0 descriptor divergences** (merged
2026-08-18, `6485afa`). Under the 2026-08-17 amendment that the mirror is not
automatically the follower, the seven `write_salmon_datapackage()` descriptor
differences that 0.2.0 had closed *by conforming to metasalmon* were re-decided
on their merits rather than by direction. **All seven fixes stand**, and no
change was warranted on either side — an outcome worth noting because the
amendment's first application, the `smn`/`gcdfo` ranking divergence, went the
other way and moved R. Re-deciding on the merits is not a bias toward Python.

Three of the seven are load-bearing for publication rather than house style, and
the authority that made them so is worth naming because neither side had cited
it: it is **`smn-data-pkg`'s `scripts/validate_package.py`, not Frictionless**.
That script compares `schema.fields` against the `column_dictionary.csv`-derived
list with an exact equality, so suppressing `title` when it equals `name`,
emitting `constraints: {"required": false}`, and rendering a one-element
`primaryKey` as an array each fail it by name. Measured rather than reasoned: a
metasalmon-written package passes the validator, and each pre-0.2.0 Python
behaviour reintroduced individually makes it fail. Recorded in metasalmonpy's
CHANGELOG under *Adjudication of the 0.2.0 descriptor divergences*.

**That same script is the subject of hub backlog #90, and PR #11 did not settle
it.** #90 asks whether the validator may reject the seven I-ADOPT
`schema.fields` keys each mirror attaches to an annotated column, and the evidence
assembled 2026-08-21 argues the script is *not* normative — `schema/sdp.rules.yaml`
never mentions it, the published v0.3 profile has no `additionalProperties`
constraint, and no CI in any ecosystem repo runs it. The two records lean on the
same script in opposite directions, and that tension should be visible rather
than smoothed over: **the "authority" framing is the weaker half of PR #11's own
argument**, and the seven fixes survive without it, because making Python's
descriptor match R's is what the mirror contract requires on its own. #90 remains
an open decision and is Brett's, as the authority over `smn-data-pkg`. Do not
read PR #11 as having made it. One consequence does reach this plan either way:
Python's seventh descriptor key is `method_iri` where R's is
`statistical_modifier_iri`, because Python still vendors sdp-0.2.0 — a separate
divergence that **chunk A** closes regardless of how #90 goes.

**PR #12 — the two-leg CI matrix** (merged 2026-08-21, `c13df83`), which
**discharges hub backlog #92**. `parity.yml`'s `python` job installed `.[test]`
— `build` plus `pytest`, and neither `[eml]` nor `[context]` — so the only
full-suite CI run was core-deps-shaped *by accident* and the extras-gated tests
(EML, KNB, context readers) ran nowhere, while `AGENTS.md` and `PARITY.md` row
30 described that accident as a deliberate core-deps job sitting alongside a
normal one. The job is now a matrix of *core only* (`.[test]`) and *with extras*
(`.[test,eml,context]`) over an identical step list, and **each leg verifies its
own dependency configuration before running anything** — the core leg fails if
`yaml`, `lxml`, `openpyxl`, `pypdf` or `xlrd` imports, the extras leg fails if
any does not. That verification step is the transferable part: without it a typo
in the extras list silently turns the second leg into a second core-deps run,
the extras-gated tests go back to skipping, and the job stays green under a name
describing coverage it had stopped providing. The workflow carries its own
retirement condition in a header comment. #92 retires as met.

**What both mean for this plan.** Differential verification for the chunks now
runs in a configuration where the EML and KNB suites actually execute — which
matters most for chunk **A**, whose EML method-step rewrite is covered by
extras-gated tests that CI had never run.

### Working practice: the checkout directory name is load-bearing

**A metasalmonpy worktree must live at a path whose last segment is
`metasalmonpy`.** `pyproject.toml` maps `package-dir = { "metasalmonpy" = "."
}`, so the repository root *is* the package directory and the import name is
supplied by the directory name. Check it out as `s10-rung3/` or
`metasalmonpy-parity/` and the entire suite errors on relative imports before
a single test asserts anything — a failure that looks like broken code and is
actually a broken path.

So an auxiliary worktree gets a *nested* path — `.worktrees/<task>/metasalmonpy`
— never `.worktrees/<task>-metasalmonpy`. Both existing checkouts follow this;
it had not been written down.

## Chunk A progress (2026-08-22)

**Chunk complete.** Chunk A — the sdp-0.3.0 breaking dictionary-contract flip
— merged 2026-08-22 as metasalmonpy PR #14 (`a3910ab`), **unversioned by
design**: which number the finished port may carry is open decision 2 / hub
Q7, so A landed under the CHANGELOG's *Unreleased* heading and the single
bump comes at the end of the chunks once that ruling exists. Do not read the
unversioned state as an oversight, and do not let a later pass "fix" it.

What landed, against this chunk's scope line above: the dictionary swap
(`method_iri` → `statistical_modifier_iri`) across nine modules and the demo
data; the vendored bundle and `SDP_SPEC_TAG`/profile constants flipped to
`sdp-0.3.0` **together** (register rows 27 and 38, both now marked
converged); `migrate_sdp_methods()` with the full hardened stop taxonomy,
every stop firing in the dry run; registry-removal errors pointing at the
migration on every current-package surface, with the reader and validator
kept as legacy read support (row 9, rewritten for the landed shape); the
three placements with default and strict IRI checks; the EML method-step
rewrite with reviewed-closure gating; the `_atomic_write_set` rollback fix;
and backlog #86 / register row 33 discharged. The final R fixture suite
landed as pytest **before** the code, red by design, per the logged decision.
Register rows 9, 27, 33, 38 and 46 were updated in both registers; no new
number was spent.

**Honest test counts, both dependency configurations, each verified by import
probe:** extras leg **629 passed / 3 skipped**; core leg (PyYAML, lxml,
openpyxl, pypdf, xlrd genuinely absent) **533 passed / 99 skipped**. The key
fixes are revert-verified — the rollback fix, the whitespace class, and the
dry-run stop parity each go red on reverted source.

**Verification baseline:** metasalmon **`main` at the moment of measurement**
(`e02111a` — the v0.3.0 tree plus every post-0.3.0 fix, including PR #75's
recon wave), fixtures regenerated at that commit and re-verified after `main`
moved mid-stream. This resolved the tag-versus-fixes ambiguity in practice;
the convention and its status as a data point for open decision 2 are
recorded under *Verification changes with the plan* above.

**A finding about R, deliberately not fixed unilaterally.** The nine-case
migration differential found **R's own no-op report shape internally
inconsistent**: `migrate_sdp_methods()` returns a two-column `tables` frame
(`table_id`, `method_iri`) on nothing-to-migrate (`R/sdp-methods.R:299`) and
a three-column frame (adding `columns`) on every populated path (`:335`).
Python's no-op frame carried the third column — internally consistent, but a
divergence — and was changed to **mirror R**, because under the amended
mirror contract which side is right is a ruling, not an implementer's call.
Filed as **backlog #112** with a retirement condition; a candidate metasalmon
tidy-up. (#111 was claimed the same day, concurrently, by the abort-safe
write-path stream for the `create_sdp()` sidecar shape — the numbering
collision was caught before either commit merged, and #112 is this item's
permanent handle.)

**What is now unblocked.** **B and G immediately**: B retargets the semantic
pipeline onto the dictionary shape A introduced, inheriting the documented
five-slot intermediate state (breadcrumbs in metasalmonpy
`tests/test_llm_review.py`); G's re-verification finally has a post-A tree to
verify against, and is already partly discharged — the untouched
`methods-sdp` legacy fixture kept the reader exercised through A's rewrite.
**C, D, E and F were never blocked on A**, but they no longer risk merge
collision with A's rewrite of `package_io.py` and `sdp_methods.py`, so the
rebase-cost caution under *Ordering* is spent. C's one inheritance from A:
the era EML structural fixtures deliberately stay era-shaped until C retires
the row-22 split.

## Chunk C progress (2026-08-22)

**Chunk complete.** Chunk C — the missing-value contract — merged 2026-08-22
as metasalmonpy PR #15, **unversioned by design** (hub Q7 open, same as A),
and standalone and undiluted per this plan's scope line: nothing but the
token, defined once, bytes on disk.

What landed: `metadata.csv_na_token()` as the single authority, mirroring
`.ms_csv_na_token()` (metasalmon 0.2.4); a write sweep passing it explicitly
through `package_io`'s metadata/resource/suggestions writers and the
`sdp_methods` extension-CSV and measurement-decomposition renderers; a read
sweep routing `scripts/validate_sdp.py` through the shared `read_sdp_csv`
instead of a bare `pd.read_csv()` whose default NA vocabulary destroyed
literal `"NA"`/`"null"` tokens on the way into validation; `_ERA_NA_TOKENS`
deleted from the EML raw-token audit — register row 22's retirement condition
executed and its live divergence (the active interop hazard with metasalmon
≥ 0.2.4) closed; and `tests/test_missing_value_contract.py` — the 0.2.4
adversarial round trip pinned **on the written bytes** (byte-identical to R
`main`'s output), write→read→write as a fixed point, and AST guards over
every `to_csv` call site and reader NA kwargs, each guard carrying its own
retirement condition.

**Honest counts, both dependency configurations, import-probe verified:**
extras **639 passed / 3 skipped**; core **540 passed / 102 skipped**, the
core venv asserted free of yaml/lxml/openpyxl/pypdf/xlrd.

**Baseline:** metasalmon **`main` @ `39818ce`** for current behaviour, via
pristine `git archive` extraction (the working hub checkout was concurrently
dirty and was not used), plus **v0.1.8 @ `886e01d`** for the era KNB corpus.
All five EML audit verdicts matched R main (the verdict list is in register
row 22); `data/obs.csv` and `column_dictionary.csv` came out byte-identical
over the adversarial frame; the regenerated `tests/data/eml/` documents are
`ET.canonicalize`-equal with identical UUIDv5 identifiers.
**Revert-verified:** restoring the era token set fails the three new audit
tests; perturbing `csv_na_token()` to `"NA"` fails the byte assertions, not
just verdicts; deleting one writer's `na_rep` fails the AST guard.

**Fixture regenerations, and why the old bytes were unregenerable.** Both era
corpora declared `missingValueCode = "NA"` over era-written bytes; current R
rejects that package outright (measured) and the converged audit rejects it
identically, so the fixtures moved the way metasalmon's own test helper moved
at 0.2.4 (commit `041d5dd`). `tests/data/eml/` was regenerated against R
`main` @ `39818ce` and is now sdp-0.3.0-shaped; `tests/data/knb/` was
regenerated under the **same era v0.1.8 extraction and toolchain** with ONLY
the NA contract moved, preserving its v0.1.8 KNB parity claim — the generator
proven first by reproducing all 22 committed artifacts byte-for-byte over the
unmoved era inputs. **The E-scope boundary held and is worth recording:
migrating the KNB pair to current-main shape was deliberately not done,
because it would have dragged unported KNB behaviours — chunk E's scope —
into this chunk.**

**A claim that did not survive contact (dated correction, 2026-08-22).** The
logged born-NA-safe decision above says the typed reader lands at rung 3 with
`na_values=["", "NA"]`, "tightened to `na_values=[""]` at PR 5", and the
chunk-C brief repeated the tightening as planned work. **On `main` no reader
carried the era token set at all**: rung 3 landed `read_sdp_csv` already
NA-safe (`na_values=[]`; register row 21's "landed early"). The one surviving
`"NA"`-as-missing site was the EML audit — row 22 — so the planned
"tightening" materially *was* the row-22 audit convergence, and that is what
this chunk executed. The reader deliberately stays at `na_values=[]` rather
than `[""]`: mapping the token to `NaN` would change the in-memory
representation row 21 records as the package's standing choice, not the
bytes. Rows 21/22's own recorded claims survived measurement exactly — every
verdict row 22 predicted was reproduced against R main before the code moved.

**Found in passing, registered not fixed:** R fills more metadata
placeholders than Python and with different prose — register **row 48**,
chunk **D**'s named scope, inherited there (see D's chunk row). Chunk C
stayed undiluted.

## Chunks B and G progress (2026-08-22)

**Both complete.** Chunk B — the semantic-pipeline retarget onto the
dictionary shape chunk A introduced — plus chunk G's legacy-read
verification, merged 2026-08-22 as metasalmonpy PR #16, **unversioned by
design** (hub Q7 open).

Chunk B, against the scope line above: `statistical_modifier` is the sixth
reviewed dictionary slot on every semantic surface, with evidence-gated
discovery (a modifier target only when column text names an aggregation;
canonical query ladder `total > mean > maximum > minimum > peak`;
evidence-free roles emit **no** target, so the bundle never reviews an empty
slot); `apply_semantic_suggestions()` maps the role to
`statistical_modifier_iri` and refuses `method`; the three
`statistical_modifier` ranking rows land in `data/ontology-preferences.csv`
byte-identical to metasalmon's file, with `sources_for_role` returning R's
list; the bundle names all seven roles and the review prompt judges exactly
the six dictionary slots — never `method` — the exact prompt defect R's
role-contract guard pins; `SEM_MODIFIER_EVIDENCE_REQUIRED` lands *beside* the
surviving `SEM_METHOD_EVIDENCE_REQUIRED`; and the role-contract guard states
its own six-surface scope, names `role_boost` as unreachable (no profile
system — backlog #87 / register row 32), and adds a **tripwire test** that
goes red the moment a profile system appears. The three measured exposures
routed here from metasalmon PR #75 all closed: **#97** (gap detection now
reports `gap_detection_basis = "no_candidates"` per target), **#101** (the
classification crosswalk), and **#102, broader in Python** — no crosswalk was
wired at all; the shared prefill engine was ported with all three wrappers
and registered as **row 47**.

**Honest counts, both dependency configurations, import-probe verified:**
extras **662 passed / 3 skipped**; core **566 passed / 99 skipped**.
**Revert-verified:** gap detection, crosswalk wiring, the retarget, and the
discovery shaping each go red with the touched files reverted to `main`.

**Baseline — and the second mid-stream re-baseline.** metasalmon **`main` at
`9d8f125`**, per the chunk-A convention (current main at the moment of
measurement, named by commit). It **moved from `39818ce` mid-stream** — docs
plus PR #77, which touches no surface measured by B — so the chunk
re-baselined, the same moving-target cost chunk A paid when `main` moved
during its fixture cut. Recorded as Q7's second data point.

**A claim that did not survive contact (dated correction, 2026-08-22).** B's
differential caught an undocumented divergence beyond its brief:
**constraint/entity measurement queries were never role-shaped in Python.**
R has shaped them since era 0.1.7 (`natural`/`hatchery` → origin queries;
spawner/stock-context → entity `population`/`stock`), but the era port pinned
only variable/property, so the raw description leaked into those searches —
and cascaded into gap detection, where a candidate matching description text
turned a genuinely-empty target into `candidate_gap`. Fixed by mirroring R
rather than registered: an undocumented divergence, not a deliberate one.
A second finding in the same spirit: a payload assertion inside an injected
`llm_request_fn` passes **vacuously** — the bundle path swallows
`AssertionError` as a provider failure, observed live when the old six-slot
assert stayed green against the new seven-role payload; the shape test now
captures the payload and asserts outside the request. Every prior chunk's
differential found undocumented divergences, and so did this one.

**Chunk G — discharged.** Verify-don't-rebuild, and it was verified.
Already-covered evidence: the v0.1.8 `methods-sdp` fixture kept the surviving
registry reader exercised (sha256-pinned, green through A and B), and the
era-shaped `tests/data/eml/` fixtures were parsed by the extras-leg
structural tests. The uncovered remainder — a **0.2.x-written package read
end-to-end** — is now covered by a new sha256-pinned fixture,
`tests/data/sdp-extensions/era-0.2.6-sdp`, written by the **last
0.2.x-behaviour** metasalmon tree (`5825467` = `1893cfa~1`), R 4.5.2 /
`LC_COLLATE=C`, registry from deliberately reversed input, era-validated at
generation. Thin tests assert: `read_salmon_datapackage()` reads it
end-to-end **preserving the era `method_iri` binding** beside the current
contract; the registry reads and validates in canonical order (register
row 9); and `validate_salmon_datapackage()` deliberately raises pointing at
`migrate_sdp_methods()`, whose dry run places the table method and leaves
every byte untouched. **Era-extraction trap, recorded because it will bite
again:** commits saying `Version: 0.2.6` include trees that already carry
0.3.0 behaviour — `1893cfa` ("feat!: implement sdp-0.3.0") landed *before*
the version bump — so era extraction must select by behaviour, never by
version string.

**Register coordination:** PR #16 claimed row 47; PR #15 had originally
claimed 47 too, caught it pre-push by running the checker, and moved to 48 on
the committed-first precedent — the first collision prevented rather than
repaired. The hub twins for 47/48 and the row 21/22 updates landed in this
hub-side pass (2026-08-22).

## Chunk D progress (2026-08-22)

**Chunk complete.** Chunk D — validation hardening — merged 2026-08-22 as
metasalmonpy PR #20, **unversioned by design** (hub Q7 / open decision 2, same
as A, B, C and G): the CHANGELOG entry sits under *Unreleased* and the single
bump comes at the end of the chunks. `validate_salmon_datapackage()` is now
metasalmon's validator — the typed accumulate-then-report issue system,
metasalmon 0.2.6's tidy checks, `value_type` enforcement and the placeholder
fill, all converged on current R.

**Verification baseline:** metasalmon **`main` @ `9d8f125`** (2026-08-22),
extracted with `git archive` to a scratch directory — never the hub working
checkout, which is dirty under concurrent agents. The chunk-A convention held:
current `main` at the moment of measurement, named by commit so the claim stays
checkable.

**Honest counts, both dependency configurations, each import-probe verified**
(the core leg confirmed `yaml`, `lxml`, `openpyxl`, `pypdf` and `xlrd` are
genuinely absent; both legs confirmed `metasalmonpy.__file__` resolves inside
the worktree rather than the primary checkout): extras **753 passed /
3 skipped**; core **648 passed / 108 skipped**. **Revert-verified:** the
`required` guard, the placeholder prose, the wide-column thresholds, the `melt`
pointer, the strict per-field message and the typed-frame enforcement each go
red on reverted source.

### The finding that matters most: Python was not reporting one problem at a time, it was reporting none

Everything in this subsection was **measured by running both implementations
over the same inputs**, never by reading R source.

**Before this chunk, on eighteen fixture packages, Python passed clean on
thirteen of them.** Duplicate `table_id`s, ghost table references, non-unique
primary keys, primary-key NAs, unlisted code values, composite-intent
violations and a `dataset.csv` with two rows in it all validated with **zero
issues**; the other five aborted with one untyped `ValueError`. R aborted on all
eighteen with a typed, itemised list.

That is worse than the shape backlog #91 and register row 41 had been
describing for weeks. Both said Python "stops at the first structural problem"
and "reports one where R reports three" — true of five fixtures, and a
significant understatement of the other thirteen, where the number reported was
zero and the call returned normally. A caller could not distinguish *validated
clean* from *this mirror does not check that at all*, which #91 had correctly
flagged as the severity but had attached to the empty `issues` frame rather than
to the checks themselves. **The register rows are corrected to the measured
state**, not left describing the milder version.

**After: field-for-field, message bytes included.** Seventeen single-defect
corruptions of the shipped example — one per issue category and per behaviour —
plus one stacked five-issue package. Every issue row matched R's across **all
five columns**: `issue_type`, `table_id`, `column_name`, `value`, `message`. The
transcribed rows are pinned in metasalmonpy's `tests/test_validation_hardening.py`,
so a wording drift on either side fails there rather than dissolving into
"roughly the same report". Two whole written packages came out **byte-identical
file-for-file** as well — the shipped 30-row example and a blank-metadata fill
probe, 11 files across the two. Two supporting batteries also ran zero
mismatches: 20 probes for the wide-column detector
(`.ms_detect_wide_columns()` vs `_detect_wide_columns()`) and 23 for
`tools::toTitleCase` via `.ms_titleize_identifier()`.

### Two defects the byte differential exposed that nobody had scoped

Neither was in D's scope. Both were found by **comparing bytes**, and the first
one is the reason to say so.

1. **A blank `required` wrote the inverted claim.** `iterrows()` hands a
   boolean-dtype NA back as a truthy float `nan`, so `bool(row.get("required"))
   is True` passed and every unlabeled-required column wrote
   `constraints: {"required": true}` into the descriptor — asserting the column
   *is* required, on the strength of the field being blank. It was firing on the
   shipped example's own `RUN_TYPE` and `ESTIMATE_STAGE` rows.
2. **A blank `column_label` omitted `title`** where R emits an explicit `null`.

**Reading the call site could not have found the first one.** The expression
is correct-looking Python over a value whose dtype is not visible at that line;
nothing in `package_io.py` reads as wrong, and no test that did not compare
against R's bytes would have had a reason to disagree with it. Only the byte
comparison surfaced it. That is **evidence for the differential method itself**,
and it should be read that way when weighing whether a later chunk's differential
is worth its cost: every chunk in this stream has found something outside its
brief this way — A found R's inconsistent no-op report shape (#112), B found the
unshaped constraint/entity queries and the vacuous in-request assertion, C found
the placeholder divergence that became row 48 — and D found a defect that
inverted a written descriptor claim in the package the project ships as its
example. A chunk verified by reading the R source and porting it would have
reproduced the intent and kept the defect.

### The prohibition on cross-implementation issue counts is lifted

This plan and register row 41 both carried a standing constraint while #91 was
open: *no milestone may verify by comparing issue counts or issue categories
across the two implementations*, because such a check passed vacuously against
an empty frame and compared one category against eight after rung 3. **Both
sides now report the same issue set for the same broken package**, so the
constraint is spent: later milestones — chunk H, the terminal bump, and any
post-S10 verification — **may** compare counts and categories. It is lifted in
the *Out of scope, logged* section below and in open decision 1 above; those
three places are the ones that stated it.

### What landed, against the chunk's scope line

- **#91 / register row 41, closed.** All eight typed categories — `dataset`,
  `tables`, `dictionary`, `codes`, `resource`, `columns`, `primary_key`,
  `composite_intent` — accumulate into R's five-column frame, and one abort
  carries the total, a ten-message preview, and the full frame as `.issues` on
  the raised error. `codes` and `composite_intent` were ported whole (code
  values canonicalized through their declared type on both sides; the WSP
  composite-intent check reading route hints from metadata *and* the
  descriptor). The `.issues` attachment is a delivery affordance R's cli abort
  has no equivalent of — row 1's conditions-to-exceptions licence, not a new
  difference.
- **The `value_type` enforcement gap** (#98's Python half). Python's validator
  did not enforce `value_type: date` at all; a mismatch was reported in a
  side-channel frame while the call returned normally. It is now a structural
  `columns` issue and the call aborts.
- **0.2.6's validation behaviours.** Primary-key NAs and duplicates as errors;
  value-like column names as a **warning in both modes, never an error**, with
  thresholds exact (two detection shapes, three-column minimum, C-collation
  sort, head-6 preview); unresolved `MISSING METADATA:` placeholders surfaced as
  a default-mode warning naming each `file$column`.
- **Register row 48, converged** — and converged the way the row asked, by
  measuring current R rather than porting the row's examples: R's guidance prose
  for blank `creator`/`contact_name`/`contact_email`/`license`, titleized
  `title`/`table_label` through a verbatim `toTitleCase` port, R's exact
  dataset/table/column wording, and `infer_*` returning placeholder-filled
  frames as R's do.
- **#100's missing round-trip test.** `tests/test_example_round_trip.py` builds
  an SDP from the shipped example and validates it in **both** modes — strict
  pinned to **zero** issues, lenient pinned to silence — plus a well-formedness
  gate over every shipped metadata CSV.
- **Register row 49 claimed** for the one deliberate difference: the tidy-shape
  warning ends `Consider pandas.melt() before packaging.` where R's ends
  `Consider tidyr::pivot_longer() before packaging.` Named as intended scope in
  D's chunk row; everything else about the check is exact.

### Three existing tests updated rather than worked around

Each pinned a behaviour this chunk deliberately changes, which is the only
condition under which editing a test is not a way of avoiding a failure:
`test_typed_roundtrip.py` now expects the abort and reads the frame off
`.issues`; `test_current_workflow.py` expects `validate_dictionary()`'s REVIEW
abort, and its "reviewed" fixture was given real contacts — a package still
holding `MISSING METADATA:` contacts is by definition not reviewed, so the
fixture was asserting a state its own name denied.

## Chunks E and F progress (2026-08-22)

**Both complete.** Chunk E — cache, environment and network robustness
(metasalmon 0.2.2 + 0.2.3) — merged 2026-08-22 as metasalmonpy PR #17. Chunk F
— the 0.2.5 redaction contract — merged the same day as PR #19, **stacked on
E's branch** deliberately: both chunks edit `knb_publication.py` and the shared
CHANGELOG/PARITY surfaces, and F's one-redactor assertion is only meaningful
over E's final call-site set, because E's new capture-time URL-redaction sites
in `_safe_json` call the very redactor F strengthens. Both **unversioned by
design** (hub Q7), each with its own *Unreleased* CHANGELOG section.

*(Numbering footnote, because the PR numbers do not run in order: F was
originally PR #18, auto-closed when its stacked base branch was deleted on
merge, and reopened as **#19** on the same branch at the same commit `1b76a69`,
based directly on `main` with E already in it.)*

**Verification baseline for both:** metasalmon **`main` @ `794647a`**,
`git archive`d to scratch, never the hub working checkout. This was a
**re-pin**, not a re-measurement: `main` moved mid-stream and the chunks
re-pinned, having first confirmed the R tree is **identical to `9d8f125` in
`R/`, `tests/` and `inst/`** — the move was documentation. Worth distinguishing
from chunks A's and B's re-baselines, which changed measured surface; see the
Q7 note below.

**Honest counts, both dependency legs, import-probe verified.** E: extras
**717 passed / 3 skipped**, core **612 passed / 108 skipped**. F: extras
**721 passed / 3 skipped**, core **616 passed / 108 skipped**.
**Revert-verified.** E: term_search reverted → 22 red, llm_review → 15 red, knb
→ 6 red. F: reverting the pattern fails the structural-token tests (2 red),
reverting the consolidation fails the one-redactor guard (1 red). All green
restored in both.

### Chunk E — what landed

- **Index session caching (0.2.2):** `_smn_term_index()`/`_gcdfo_term_index()`
  resolve once per session through `_cached_term_index`, the mirror of
  `.ms_cached_term_index`; `refresh=True` bypasses and replaces; **a failed
  resolve caches nothing.**
- **Call-time environment reads, and the prefix rename.** `SALMONPY_CACHE` was
  read **at import** — the exact bug class R 0.2.2 fixed for
  `METASALMON_CACHE`. The switches are now call-time
  `METASALMONPY_CACHE` / `METASALMONPY_DEBUG_FETCH` through one helper. The
  rename is a **logged decision** now, with a window: see the *Decisions logged
  during the subsystem chunks* table above, open decision 1b (closed by it), and
  register row **50**.
- **HTTP-error diagnostics and no-cache-on-degraded (0.2.2):** per-source
  failure signalling (`status="http_error"`, R's diagnostic columns including
  `elapsed_secs`, partial answers kept but never called clean successes), a
  degraded-lookup warning, and degraded results never cached. The curl fallback
  gained `--fail`, so an error page served as JSON can no longer masquerade as
  success.
- **KNB dry-run overwrite (0.2.3):** `publish_sdp_to_knb(overwrite=)` re-plans
  after a corrected input; eligibility is decided **before** the plan builder
  mutates; published manifests stay immutable; all three former dead-end gates
  now name the remedy.
- **Provider retry with `Retry-After` (0.2.3):** 3 total attempts (4 for
  openrouter `:free` / chapi `gpt-oss*`), delta-seconds and IMF-fixdate forms
  honoured and capped at 60s, locale-independent date parsing, jittered
  exponential backoff, R's retryable set. A sentinel `request_fn` still proves
  exactly one call. Chat decomposition stays direct, matching R.
- **BioPortal header auth and URL redaction at capture (0.2.3):** the key moves
  out of the query string into `Authorization: apikey token=…`, and every URL
  `_safe_json` records is redacted at capture through the shared redactor — the
  E/F placement split logged in the decisions table above.

**Differential: 23/23 probes matched** — cache-switch truth table (13 values),
retry limits (8 provider/model configs), retryable classifier (17 messages),
HTTP-date parsing (6 forms, including the exact epoch for IMF-fixdate and
`None` for both obsolete forms), `Retry-After` delta/cap/blank/missing/past-date,
backoff bounds at four attempt levels, BioPortal URL and header byte-identical,
and degraded-lookup semantics (status, count, error text, warning, diagnostic
columns, plus 2-calls-for-2-lookups proving no caching). **KNB overwrite ran
end-to-end over the same package** (`tests/data/knb/sdp-full`): 13/13 matched —
dry-run status, idempotent re-run, the corrected-input refusal firing at the
same gate with the same remedy, the re-plan under `overwrite=True` with a
changed plan fingerprint, the published-manifest refusal firing **before** any
local bytes were touched, orphan-resource-map non-bypass, and flag validation —
with `package_id` and `series_id` **byte-exact across implementations**.

**A register row updated in passing:** row 39 gained the cache-key consequence
of the ranking-profile gap. metasalmon 0.2.2 folds `.ms_ranking_identity()` into
the `find_terms()` cache key so a user who flips a ranking knob mid-session is
not served the previous ordering; metasalmonpy's cache key deliberately omits
that component because it has **no ranking knobs to key on**. The omission is
correct exactly as long as row 32's gap stands — so whoever closes row 32 /
backlog **#87** with a profile system must extend the cache key **in the same
change**, or they reintroduce R's 0.2.2 stale-ranking bug on the Python side as
a side effect of adding a feature.

### Chunk F — what landed

- **Structural `*_token` redaction.** `_CREDENTIAL_NAME` replaced the enumerated
  `dataone[_-]?token` with R 0.2.5's `[a-z0-9]+[_-]token(?![A-Za-z0-9_])` — any
  qualified name whose final segment is `token`. That closes the split where
  `dataone_token` was redacted while `dataone_test_token` and
  `knb_staging_token` leaked **at rest**, which matters more than at display:
  captured provider errors are stored on returned frames and written to CSV.
  `max_token_count` / `total_tokens` / `prompt_tokens` survive;
  `dataone_token_v2` is now deliberately **unmatched**, adopting R's recorded
  trade — a verdict that flipped on the Python side from redacted to left alone.
  The separator whitespace class was aligned to R's PCRE `[[:space:]]`.
- **Exactly one redactor** — register row 37's retirement condition, executed.
  `knb_publication._redact` is **deleted**; its three call sites (`_abort_safe`,
  the live-adapter warning wrapper, the DataONE REST error path) route through
  `text_safety.redact_secrets()`; and
  `tests/test_text_safety.py::test_exactly_one_redactor_exists` is the standing
  guard — it asserts `_redact` is gone, scans every package module for a second
  `def *redact*`, and checks the KNB boundary actually calls the shared
  function. One observable output changed with the consolidation, exactly as in
  R at 0.2.5: an `Authorization: Bearer …` line is redacted as a whole
  credential-header line, not just its Bearer payload. The era `expected.json`
  `redact_*` helper values retired with the deleted function they pinned.

**Differential: a 31-string adversarial battery** — credential headers, cookie
jars, serialized JSON credentials, qualified staging and production tokens,
token-count diagnostics, JWTs, `sk-`/`AIza` keys, URLs with query-string keys,
prose decoys — driven through both implementations, **byte-identical** to
`.ms_redact_secrets()` on metasalmon `main` @ `794647a`, against exactly three
divergences before the chunk. The same battery run inside chunk E's session had
shown those same three and nothing else, which is what let E state cleanly that
redaction was untouched by it. The three re-pinned KNB fixture strings were
additionally verified string-for-string through R.

**Row 37's retirement condition is met on its redaction half, and it is the
first retirement condition in this register a chunk has executed rather than
inherited.** The *Inapplicable* escape half never retires — Python has no
glue-template layer to converge on — so the row stays as the record of why, with
the redaction half marked converged and surviving as the guard test.

## Python exposure of the 2026-08-21 recon defects, mapped to chunks

metasalmon PR #75 fixed eight defects; each was measured (not assumed) against
metasalmonpy, and the exposures land in existing chunks rather than new ones:

| Defect | Python state (measured) | Chunk |
|---|---|---|
| #96 destructive Date write | **clean** — `_has_value` is type-safe, pandas does not guess dates | none |
| #93 item 2 metadata Date coercion | **clean** — `to_csv` pads | none |
| #97 gap detection blind to zero candidates | **has the defect**, same repro (0 gaps, no `semantic_targets`) | **B** |
| #98 example fails validation | partial: same DD-MON-YY sample, but the validator does not enforce `value_type: date` at all — a validator-parity divergence in its own right — and the bundled `column_dictionary.csv` is **corrupt as shipped** (unquoted commas shift two rows; stale `method_iri` header) | corruption + header → **A** (that file is in A's swap); the value_type enforcement gap → **D** |
| #99 404 IRIs | has both | **A** (example data moves with the contract flip) |
| #100 no round-trip test | none exists; one would fail today on the corrupt dictionary | **D** |
| #101 classification crosswalk | absent | **B** |
| #102 crosswalk wiring | broader than R's defect: **neither** existing crosswalk is wired into the package path at all — an undocumented divergence `PARITY.md` does not record, itself a mirror-contract violation until registered | **B**, with the register row due in the same change |

Chunk A has since landed (2026-08-22) and discharged its rows above: the #98
corruption-and-stale-header half and #99's example data both shipped in the
byte-copy demo-data swap. Chunk B has since landed too (2026-08-22,
metasalmonpy PR #16) and discharged **#97, #101 and #102** — see the chunk
B+G progress section above. **Chunk D has since landed too (2026-08-22,
metasalmonpy PR #20) and discharged the last two:** the #98
`value_type`-enforcement gap — Python's validator did not enforce
`value_type: date` at all, reporting a mismatch in a side-channel frame while
the call returned normally, and it is now a structural `columns` issue that
aborts — and **#100**, whose round-trip test (`tests/test_example_round_trip.py`)
builds an SDP from the shipped example and validates it in both modes, strict
pinned to zero issues and lenient pinned to silence, with a well-formedness
gate over every shipped metadata CSV. **Every row of this table is now
discharged.** One asymmetry worth keeping: metasalmon pins its fuller 173-row
example to one known strict failure, and that example is not shipped in Python
(register row 46, open), so the tiny example's zero-issue pin is the whole gate
there.

## Sidecar-survival rule

Sidecars appear at PRs 1–2 but read→edit→write preservation is a PR-3
contract in R's chronology. Implement preservation for each sidecar AS IT IS
INTRODUCED — reproducing R's window costs nothing and avoids tagged states
that drop reviewed artifacts.

## Out of scope, logged

The last two entries (#87, #91) were out of scope **as this plan stood when
they were written**, not permanently: whether 0.3.0 must close them is *Open
decision 1* above. **#91 has since moved into the chunk list and closed** —
chunk D scoped it in and discharged it on 2026-08-22 — so only #87 is still out
of scope here.

- `ontology_fetch.py:15` old host: R is also stale here and the paths
  diverge — a separate cross-repo coordination task, not an S10 item.
- `term_requests.py:19` `GCDFO_REPO` old org: matches current R; stays in
  lockstep until either repo fixes it first.
- Interactive cancel-must-not-submit (R 0.2.0): Python has no interactive
  term-request console — inapplicable, exception register.
- Locale/radix sweeps: Python `sorted()` is codepoint-ordinal — mirror the
  determinism TESTS plus a no-`locale.strxfrm` guard, not the fix.
- **The ranking-profile gap predates this replay and no rung covers it**
  (backlog #87, parity-deviations row 32). Python's `_score_and_rank_terms`
  has no `ranking_profile` argument and no equivalent of
  `.ranking_profile_defaults()`/`.merge_ranking_profile()`, and its inlined
  weights differ from R's across base source weights, the unknown-source
  fallback, role boosts for every role but `unit`, and the vocabulary bonuses
  — which differ in gating as well as magnitude. Candidate *order* therefore
  differs for the same query. This is **older than the 0.1.6 claim**, so no
  rung below inherits it: the 0.1.7 rung's `match_type` fix touches the ladder
  inside the scorer, not the profile system around it, and the 0.3.0 rung's
  `statistical_modifier` ranking-preferences rows are data for a system Python
  does not have. Logged here as deliberately out of scope so the omission is
  visible; it needs a rung or its own stream before any milestone verification
  depends on ranking order. Note while sequencing that
  `benchmark_term_ranking_fixtures` — the surface that would *measure* a
  ranking regression — accepts `profiles` and discards them on the Python
  side, so it cannot currently serve as the check for any rung. It has **no
  Python test**, and its default fixture path names a file that does not exist
  in the repo, so the zero-argument call is dead as well.
- **`validate_salmon_datapackage()`'s issue system diverges, and no rung owns
  that either** (backlog #91, parity-deviations row 41). **Superseded
  2026-08-22: chunk D owned it after all, and closed it.** The entry stays as
  the record of what was scoped out and why, and of the verification constraint
  that held while it was open; the constraint itself is lifted, immediately
  below. R tags every finding
  with one of **eight** `issue_type` values and collects them all before a
  single abort; Python raises an untyped `ValueError` at the **first**
  structural problem, so a package with three bad tables reports one. On
  `main` the returned `issues` frame is `pd.DataFrame(columns=["message"])`,
  whose column set does not match R's five; chunk-A-era rung 3 adds exactly
  one category, `columns`. **Older than the 0.1.6 claim** — `package_io.py`
  dates to the initial 2026-02-06 commit — so, like the ranking gap, no rung
  below inherits it. Logged here deliberately.

  **This one constrained verification design, which the ranking gap does not
  — and the constraint is now LIFTED (2026-08-22).** While it was open the rule
  was: *no milestone may verify by comparing issue counts or issue categories
  across the two implementations*, because such a check passed vacuously
  against 0.1.8's empty frame and compared one category against eight after
  rung 3. **Chunk D closed it**, which is where this entry said it would
  naturally land — the only chunk whose subject is that function — even though
  scoping it there was, at the time this was written, a decision nobody had
  made and outside D's stated primary-key-and-placeholder scope. Both
  implementations now report the same issue set, field-for-field including
  message bytes, for the same broken package, so **later milestones may compare
  issue counts and categories across the two implementations.** Chunk H and the
  terminal bump are free to use such a check; anywhere this plan still reads as
  forbidding it, the chunk D progress section governs.

## Verification

Per milestone: pytest green, the milestone's R-derived fixtures pass, and
the two version strings agree. At PR 3 and PR 8: an R↔Python round-trip
(package written by one, read and validated by the other) against the spec
example packages. The `parity.yml` archive job asserts contracts, not bytes.
