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
| **A** | **Spec conformance and the dictionary contract** *(breaking; B and G depend on it)* | Methods leave `column_dictionary`; `statistical_modifier_iri` replaces `method_iri`; registry removal with errors that point at migration; `migrate_sdp_methods` with the full hardened stop taxonomy, **every stop firing in the dry run as well as the real run**; the three placements (`tables.csv$method_iri`, `protocol_iri`/`protocol_citation`, `codes.csv$term_iri`); default and strict placement-IRI checks; pin flip to `sdp-0.3.0`; the bundled template header, which in Python is well-formed but still ends `method_iri`; **EML method steps from the placements** — `write_eml_from_sdp()`'s `methods` becomes the placements tibble and `used_methods` the used-procedure IRIs, with reviewed-closure gating; **the `_atomic_write_set` rollback fix**; **backlog #86 / register row 33**, the `sdp_methods.py` whitespace class |
| **B** | **Semantic pipeline retarget** *(after A)* | Semantic retarget to `statistical_modifier`; **three `statistical_modifier` rows in the ranking-preferences data** (`data/ontology-preferences.csv`, still on the pre-0.3.0 role set `constraint`/`entity`/`method`/`property`/`unit`/`variable`/`wikidata`); the bundle-review prompt naming `statistical_modifier` rather than the removed dictionary `method` slot; **`SEM_MODIFIER_EVIDENCE_REQUIRED`**, added *beside* the surviving `SEM_METHOD_EVIDENCE_REQUIRED` (`llm_review.py:1529`) and not replacing it — the code-level `method` role survives 0.3.0; a static role-contract guard **scoped to the six surfaces Python has**, and saying so (below) |
| **C** | **Missing-value contract** *(standalone, never diluted)* | Single NA helper, read/write sweep, literal-`"NA"` round-trip guard. Bytes on disk — it wants an undiluted diff |
| **D** | **Validation hardening** | Primary-key uniqueness and NA errors, value-like-name warnings (thresholds exact; the message points at `melt`), placeholder surfacing |
| **E** | **Cache, environment and network robustness** | Index session caching; **call-time env read** (`SALMONPY_CACHE` is read at import today — the exact bug class R 0.2.2 fixed); the `SALMONPY_`→`METASALMONPY_` prefix rename — **open, see below**; http-error diagnostics; no-cache-on-degraded; KNB dry-run overwrite; retry and `Retry-After`; BioPortal header auth (`term_search.py:300` still puts the key in the query string) |
| **F** | **Redaction** | Structural `*_token` redaction; assert exactly **one** redactor (`knb_publication._redact` is the second one, and `text_safety.py:56-68` already carries the retirement condition naming this chunk); **0.2.3's URL redaction** — R passes request URLs through the same `.ms_redact_secrets()` at capture (`R/term_search.R:592`, `:606`), which is why the one-redactor assertion and the URL rule belong together |
| **G** | **Legacy read compatibility** *(verify, do not rebuild)* | Reading 0.2.x-written packages that carry a methods registry, and 0.1.8-era EML quoting procedures from one. Landed at rung 2 — confirm it survives A |

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
- **#91 / register row 41** — `validate_salmon_datapackage()` reports through a
  different mechanism: R tags eight `issue_type` values and collects all
  findings before one abort, Python raises untyped at the first structural
  problem.

*The question:* does the **0.3.0 parity claim require closing them**, or may
0.3.0 ship with both open and documented as register rows? The mirror contract
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

*What it unblocks:* the chunk list is not final until this is answered — (a) and
(b) add work to it. It also decides whether **chunk D can be written at all**
without first ruling on #91, and it interacts with the constraint already logged
below: *no milestone may verify by comparing issue counts or categories across
the two implementations* while #91 is open.

### 1b. The `SALMONPY_` prefix rename was never decided — struck 2026-08-21

Chunk E listed *"the `SALMONPY_`→`METASALMONPY_` prefix rename, **decided and
logged here**"*. **That claim is false about this document:** it contains no
decision record for the rename — no decider, no date, no rationale — and the
S10 sequence card has carried the same question as *undecided* since
2026-08-13. Two documents asserting opposite states with no evidence behind
either is worse than an open item, so the "decided and logged here" clause is
struck as an error and the question stays open, which is the resolution the
sequence card's retirement condition already offers.

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

## Sidecar-survival rule

Sidecars appear at PRs 1–2 but read→edit→write preservation is a PR-3
contract in R's chronology. Implement preservation for each sidecar AS IT IS
INTRODUCED — reproducing R's window costs nothing and avoids tagged states
that drop reviewed artifacts.

## Out of scope, logged

The last two entries (#87, #91) are out of scope **as this plan currently
stands**, not permanently: whether 0.3.0 must close them is *Open decision 1*
above, and answering it can move either into the chunk list.

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
  that either** (backlog #91, parity-deviations row 41). R tags every finding
  with one of **eight** `issue_type` values and collects them all before a
  single abort; Python raises an untyped `ValueError` at the **first**
  structural problem, so a package with three bad tables reports one. On
  `main` the returned `issues` frame is `pd.DataFrame(columns=["message"])`,
  whose column set does not match R's five; chunk-A-era rung 3 adds exactly
  one category, `columns`. **Older than the 0.1.6 claim** — `package_io.py`
  dates to the initial 2026-02-06 commit — so, like the ranking gap, no rung
  below inherits it. Logged here deliberately.

  **This one constrains verification design, which the ranking gap does not.**
  *No milestone may verify by comparing issue counts or issue categories
  across the two implementations* until it closes: such a check passes
  vacuously against 0.1.8's empty frame, and after rung 3 compares one
  category against eight. Chunk **D** (validation hardening) is where it would
  naturally land if it is ever scoped in — it is the only chunk whose subject
  is this function — but scoping it there is a decision nobody has made, and
  D's stated scope is primary-key and placeholder behaviour, not the reporting
  mechanism.

## Verification

Per milestone: pytest green, the milestone's R-derived fixtures pass, and
the two version strings agree. At PR 3 and PR 8: an R↔Python round-trip
(package written by one, read and validated by the other) against the spec
example packages. The `parity.yml` archive job asserts contracts, not bytes.
