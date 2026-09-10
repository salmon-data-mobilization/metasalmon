---
type: Artifact
title: "Hub-integration kit — S14 and S15"
description: "Paste-ready drafts for the two streams that survive the 2026-09-04, 2026-09-05 and 2026-09-09 rulings: S14 (Salmon Science Foundry, ruled a member by Q19) and S15 (the hub-coordination redesign, R9 as simplified by R12). S16 (a PSC core-model ontology) was drafted and withdrawn. Holds the sequence cards, domain-card rows, release-index sections, roadmap inserts, log entry, and the Foundry knowledge-bundle seed. Prepared 2026-09-04, revised 2026-09-05; nothing here is applied, and the paste is deliberately sequenced after S15 so the member count is not restated in eleven places two days before it becomes derivable."
status: draft
tags: [foundry, s14, s15, integration, prepared]
psc:
  id: metasalmon:plan:2026-09-04-s14-hub-integration-kit
  contexts: [metasalmon:context:hub-coordination]
---

# Hub-integration kit — S14 and S15 (prepared, not applied)

Companion to the [Salmon Science Foundry concrete plan](2026-09-04-salmon-science-foundry-concrete-plan.md)
(its §4.2 is the procedure these drafts serve; its Appendix A holds the
rulings). Links inside the fenced blocks are written relative to the bundle
root, where the text will be pasted.

**Status, 2026-09-05.** Q19 is ruled: the Foundry **is** a hub member. What is
*not* done is the paste, and that is deliberate. The same day's ruling R9
moves planning state into a git-native queue, under which the member count
becomes derivable rather than restated in nine files. Pasting eleven more copies of a
number and then deleting them in the following change would be the duplication
R9 exists to remove. **So the order is: S15 first, then this kit's pastes
land against the new structure.**

The streams drafted here:

| Stream | What it is | State |
|---|---|---|
| **S14** | The Salmon Science Foundry and SalmonBench | member ruled (Q19); paste held for S15 |
| **S15** | The hub-coordination redesign — the git-native queue, `HUB.md`, the `hub` client, the migration | new 2026-09-05 (R9), simplified 2026-09-09 (R12); the plan's §9 is its execplan |
| ~~**S16**~~ | ~~The PSC core-model ontology~~ | **withdrawn 2026-09-09 (R11)**; the number is not consumed |

## 1. `knowledge/sequences/s14-salmon-science-foundry.md`

```markdown
---
type: InformationObject
title: "S14 — Salmon Science Foundry and SalmonBench"
description: "PROPOSED, NOT RULED (2026-09-04). A new institute repository, salmon-science-foundry, as an orchestration, data-access, and evaluation layer above the SDP tooling: a Tier 0 run ledger with digest-bound approvals, tool receipts around metasalmon and metasalmonpy, the salmon data-access verbs, and the SalmonBench task suite. Enters the roadmap only if Brett rules it the ninth member (Q19); until then this card sequences nothing."
status: draft
tags: [foundry, salmonbench, data-access, evaluation, proposed]
psc:
  id: metasalmon:sequence:s14-salmon-science-foundry
  contexts: [metasalmon:context:hub-coordination]
---

# S14 — Salmon Science Foundry and SalmonBench · **proposed, not ruled**

**Execplan:** [Salmon Science Foundry concrete plan](../plans/2026-09-04-salmon-science-foundry-concrete-plan.md)
(2026-09-04; imported from Brett's draft and revised the same day after a
nine-dimension review and six rulings). Design input for its semantics
layer: [OKF-centred semantic knowledge architecture](../plans/2026-09-04-okf-graphify-semantic-knowledge-workflow.md).
Both carry an authority note saying they activate nothing; this card does
not change that.

**Read the state before the scope.** This card is preparation, not
integration: it is not listed under the roadmap's *The streams*,
`salmon-science-foundry` is not in the domain allowlist, and nothing here
blocks or is blocked by anything. Under the membership test ruled
2026-08-24, adding this card to *The streams* **is** the membership act, so
it waits on [Q19](../questions.md) and must not be done by an agent. Q20 to
Q30 in the same file decide what its first two stages contain.

## What S14 owns, and what it only consumes

| Workstream | Owner | S14's relation |
|---|---|---|
| A1 — metasalmonpy 0.5.0 port | **[S5](s5-review-flow.md)** | Hard dependency; S14 pins the release, never ports |
| A2 — one validation authority | **[S1](s1-validation-authority.md)** | Hard dependency for the exact-validator-success metric |
| A3 — release-train order | this card as a rule; the release index as the record | adds a "Foundry pin" step |
| B — gold-standard campaign | **[S12](s12-fraser-coho-gold-standard.md)** | S14's first campaign runs S12 through the Foundry; S12 decides the package |
| C — Tier 0 runtime | **S14** | owned; tier changes by ADR ([Q22](../questions.md)) |
| D — SalmonBench (`bench/`) | **S14** | owned; scope per [Q23](../questions.md); extraction by the execplan's criteria |
| E — PR #27 evidence briefing; commons compiler | **S14** for both; **[S9](s9-ontology-alignment.md)** for the ruling (Q6) | evidence into Q6, never adjudication; no public commons subset without [Q24](../questions.md) |
| F — Fraser Recruits | **removed 2026-09-04 (Brett)**; [S13](s13-fraser-recruits-case-study.md) keeps the three metasalmon requirements | not in S14 |
| G — practicum and Hub pages | **[S4](s4-workshop-rebuild.md)**; the Hub is a non-member ([Q20](../questions.md)) | S14 supplies content and release JSON |
| H — `salmon` data-access verbs | **S14**, or the packages under the mirror rule ([Q27](../questions.md)) | owned |
| I — citation, governance, identity register, rights | **S14** proposes; the owning repositories decide | S9 successor for the identity register |

## Dependencies, with their state on 2026-09-04

- **S5's mirror port** — the `0.4.0→0.5.0` window is open; no port branch.
- **S12** — execplan unwritten; stage 1 waits on the ruled-but-unimplemented
  `smn-data-pkg` descriptor change (Q3/#90) and on #95; the PFMA subarea gap
  closed 2026-08-26 (gcdfo PR #88, 604 subareas, unreleased); species ruled
  (Q6-1); Q9 open.
- **S3** — Q1 ruled; what remains is Brett's dev.nceas token and one
  end-to-end test deposit, which S12 stage 2 and any H5 release wait on.
- **S1** — execplan unwritten; #90 ruled, so it can start.
- **S13** — execplan unwritten; Q13 open; requirements 1 and 3 are S14's
  issue #6 in the execplan, after the port.
- **S9** — Q6's eight rulings unmade; two PR #27 attributions failed the
  passage check, so the case is not frozen.
- **S7** — credibility dependency: the execplan's §1.3 amends S7's design;
  the S7 card says so when Q19 is ruled.
- **S4** — the practicum follows the rebuild, which waits on S3's deposit.

## Rulings this card waits on

[Q19](../questions.md) admits the repository; Q20 (non-members), Q21
(commercial boundary in the bundle), Q22 (runtime ADR), Q23 (benchmark
scope), Q24 (commons subset), Q25 (gold standard location), Q26 (repository
homes under the institute), Q27 (data-access home), Q28 (licence), Q29 (#95's
fix location), Q30 (the Foundry bundle's OKF profile) decide the first two
stages.

## What a "yes" on Q19 changes, so the count does not drift again

The member count lives in eleven places (the plan's §4.2 lists them);
one change, all of them, or none. The release index gains a ninth section
("no releases yet"), the sequencing diagram gains S14's edges, and this card
moves into *The streams*.

## Retirement and supersession

- **Declined (Q19 = no):** this card moves to *Executed work* as *declined*,
  with the reason; the execplan stays as design input. Delete neither.
- **Superseded in part** when `salmon-science-foundry` has its own
  `knowledge/` bundle: implementation detail and campaign status move there;
  this card shrinks to scope, dependencies, status.
- **Split** if SalmonBench meets the extraction criteria; ruled then.
- **Retires** when the execplan's §15 engineering-success criteria are
  measured and recorded here in one or two lines, or its capacity gate
  collapses the runtime into something an existing stream owns.

**Mirror rule:** the Foundry is Python with an R command-tool shim; it is not
a third implementation of SDP behaviour. Anything it needs from the packages
that does not exist lands in both under the mirror rule, or a parity row
says why not. If the verbs become a sibling pair (Q27), the rule is extended
to them explicitly.
```

## 2. Domain-card row (append only after Q19; the membership act)

```markdown
| `salmon-science-foundry` (org `Symecology-Institute`) | The Salmon Science Foundry: an orchestration, data-access, and evaluation layer above the SDP tooling — a Tier 0 run ledger with digest-bound approvals, tool receipts around metasalmon and metasalmonpy, the `salmon` data-access verbs, and the SalmonBench task suite (under `bench/` until its extraction criteria are met). Python; calls the R package only through command tools, never as a dependency; not a third implementation of SDP behaviour — **the ninth member, admitted YYYY-MM-DD (Brett, [Q19](../questions.md))** because this hub sequences its work as [S14](../sequences/s14-salmon-science-foundry.md) |
```

In the same change: the card's description and its "eight repositories, one
hub" line become nine, and the note that a member may live in another
organization gains a second example.

## 3. Release-index section (append after the workshop section)

```markdown
### salmon-science-foundry — **no releases, and no repository yet**

| Version | Date | One line |
|---|---|---|
| *(none)* | — | The repository does not exist as of 2026-09-04. Its execplan proposes a Tier 0 runtime ladder v0.0.1 → v0.1.0 and a SalmonBench v0.1 under `bench/`; none has a commit, a tag, or a release object |

Ninth member as of the Q19 ruling (YYYY-MM-DD); a member section, not a
courtesy record, added in the same change as the domain-card row so the
index never carries "nine sections for eight members". Every release from
its first tag follows the 0.3.0-forward policy (annotated tag plus a GitHub
Release) and gets a Zenodo DOI. What it pins instead of versioning itself:
metasalmon (release), metasalmonpy (release), `sdp-` (tag), smn (release),
gcdfo (commit or tag), and a commons commit; add a row to the spec-version
spread table the moment the first pin exists. Do not invent a versioning
scheme for `bench/`. *Retires when:* the first tag exists.
```

## 3b. `knowledge/sequences/s15-hub-coordination.md` (new, 2026-09-05)

```markdown
---
type: InformationObject
title: "S15 — Hub coordination: a git-native queue"
description: "Move planning state out of the bundle into a git-native queue whose claims are ordinary git pushes, with a HUB.md policy file and a small hub client. No GitHub Project. Ruled 2026-09-05 (Brett, R9) and simplified 2026-09-09 (R12)."
status: draft
tags: [coordination, project, agents, migration]
psc:
  id: metasalmon:sequence:s15-hub-coordination
  contexts: [metasalmon:context:hub-coordination]
---

# S15 — Hub coordination: a git-native queue · **ruled 2026-09-05, simplified 2026-09-09 (Brett)**

**Execplan:** the [Foundry plan's §9](../plans/2026-09-04-salmon-science-foundry-concrete-plan.md).
Brett: *"redesign and simplify the system of hub coordination … move towards
using a GitHub project using the gh cli to track state so that any agent can
pick up work that is currently not checked out."* OpenAI Symphony is the
stated inspiration.

## Why, in one measurement

25% of this bundle's 8,901 non-plan lines is planning **state**, restated 3 to
17 times, with five copies stale on the day they were counted: metasalmon's
version in ten files, the mirror window in five, S10's status in four, and a
decision ruled 2026-08-22 whose roadmap entry still reads unruled. The bundle
already states the rule this violates — *a count nobody maintains is decay*.

## Scope

1. **The queue is files in git** — one YAML file per work item under
   `knowledge/queue/` — and every prose restatement of a state fact becomes a
   generated block with a continuous-integration freshness check.
2. **The claim is a plain `git push`** of an orphan commit to a claim ref in a
   small `hub-locks` repository: git's own compare-and-swap, zero race window,
   no API call, no `project` scope, no `issues: write`.
3. `HUB.md` at the metasalmon root as the single policy file, carrying a
   `writes:` register; Brett's global instruction is the ceiling and the
   narrower of the two governs.
4. A `hub` client (`doctor`, `ready`, `claim`, `beat`, `release`, `done`,
   `reconcile`, `sync`) that distinguishes losing the race from a failed call.
5. **No GitHub Project** (R12, 2026-09-09). The queue is git files alone; the
   plan's §9.8 records what the Project would have given, and that reviving it
   later is additive because the queue files are the source.
6. Backlog identifiers preserved, so the 191 bare citations are never
   rewritten; `ready` is human-only and set by a commit on `main`, which the
   carve-out forbids agents to push.

## Dependencies and order

- **Blocked by nothing.** It blocks the *paste* half of S14 and S16, because
  the member count becomes derivable under it.
- **Step 0 deletes rather than corrects the five stale copies**, so the
  migration starts from a true baseline. Migrating from a false one is the
  failure that is invisible afterwards.
- **Step 1 is ten minutes**: confirm the claim ref prefix accepts a push, and
  run a two-terminal race test proving the claim is atomic. Four of the five
  experiments the Project design needed are moot without a Project.
- About **18 agent-hours and two hours of Brett** after R12 removed the
  Project, its fields, its sync program, and its credential. The acceptance test is the cost of admitting
  a member: about an hour each for S14 and S16, or the design failed.

## Retirement and supersession

*Retires when:* the queue holds every stream and open work item, `HUB.md` is
the only copy of the carve-out, thirteen state facts each live in one place,
and the roadmap carries no per-stream status. *Superseded if:* claims stop
living on git refs — at which point the carve-out paragraph is deleted rather
than widened.
```

## 3c. S16 — withdrawn 2026-09-09 (R11)

A card for a PSC core-model ontology stream was drafted here on 2026-09-05 and
withdrawn on 2026-09-09: *"I don't think I want the PSC Ontology as part of
this hub anymore … Let's leave PSC out for now."* Nothing is pasted, no stream
number is consumed, and **S16 stays free** for whatever the hub sequences
next. The plan's Workstream J note keeps the two conclusions worth carrying
forward if the work is ever revived on the PSC side.

## 4. Roadmap inserts

Sequencing diagram (append after the S11 line; edges are visible before the
ruling, the S14 line is not a stream entry until Q19):

```text
S14 Salmon Science Foundry ── PROPOSED 2026-09-04, Q19 unruled: edges drawn,
                              nothing sequenced
S1 validation authority ───────────────► S14 D (exact-validator-success metric)
S5 mirror port (0.4.0→0.5.0 window) ───► S14 A1 is that port; S5 owns it
S12 stage 1 (#90 spec change, #95) ────► S14 campaign 1 (coho gold standard)
S3 test-node deposit (token: Brett) ──► S12 stage 2 ──► S14 H5 release of campaign 1
S13 requirements 1 and 3 (after S5) ──► S14 issue 6
S9 / Q6 rulings on PR #27 ─────────────► S14 E briefing target
S7 §1.3 boundary amendment ─ ─ ─ ─ ─ ─ ─► S14 C (which side owns curation state)
S4 rebuild (after S3 deposit) ─ ─ ─ ─ ─ ─► S14 G practicum
```

*The streams* bullet (append after S13 only after Q19; the membership act):

```markdown
- [S14 — Salmon Science Foundry and SalmonBench](sequences/s14-salmon-science-foundry.md) · **admitted YYYY-MM-DD (Brett, [Q19](questions.md))** · owns the Tier 0 runtime (C), SalmonBench (D), the data-access verbs (H, or the packages per [Q27](questions.md)), and the Foundry-specific halves of E, G, and I; consumes S1, S3's deposit, S5's port, S12, S13's requirements, and S9's Q6 rulings as dependencies rather than re-owning them. Fraser Recruits is out of the Foundry (Brett, 2026-09-04); the gold standard stays in metasalmon ([Q25](questions.md)); no public commons subset without [Q24](questions.md). Execplan: the 2026-09-04 plan, reviewed and revised the same day
```

Also in the same change: a *Dependency-scoped plans* row for this document;
the OD-2 and sequencing-paragraph text updated to the Q1 ruling; the
hub-coordination context's lockstep sentence corrected.

## 5. `log.md` entry

Three entries, one per pass: 2026-09-04, 2026-09-05, and 2026-09-09.

### 2026-09-09

```markdown
## 2026-09-09

- **The PSC core-model ontology left the plan four days after it entered it.**
  Brett: *"I don't think I want the PSC Ontology as part of this hub anymore …
  Let's leave PSC out for now."* Workstream J is withdrawn, the S16 card is
  not pasted and its stream number is not consumed, and Fraser Recruits
  returns to out-of-scope, which restores the 2026-09-04 position rather than
  creating a new one. The design work is held as a session memo. Two
  conclusions are worth carrying forward wherever it lands: build the context
  map before the model, and make the default answer to *should this term be
  ours* no.
- **The ruled membership test needed no amendment after all.** On 2026-09-05
  the PSC repository was a member the test could not admit, and the question
  of how to stretch it was open. Withdrawing the repository dissolved the
  question instead of adjudicating it, which is the better outcome for a test
  that had itself been ruled ten days earlier.
- **The GitHub Project is gone from the coordination design.** Brett: *"Just
  do the git files, don't bother with the generated GitHub project view if
  that's only for me."* The queue is git files, a claim is a `git push` of an
  orphan commit, and `HUB.md` is the one policy file. What went with the
  Project: a token scope reaching every organization, an unattended credential
  in Actions secrets, a sync program, a second representation that can drift,
  and a write path the private-terms guard could not see. Migration drops from
  about 26 agent-hours to about 18, and its experiment step from an hour to
  ten minutes, because four of the five open platform questions were about the
  Project.
- **The standing authorization is now one paragraph** covering two `git push`
  targets, with a closed exclusion list and a self-suspending clause. The
  draft-pull-request paragraph was declined: an agent pushes its branch,
  prints the compare URL, and stops.
- **The institute was renamed a second time**, to Symecology Institute. No
  GitHub organization exists under this name or either predecessor, and
  creating one is deferred to Stage A week 3 — a rename releases the old name
  for anyone to claim, and nothing before then needs it.
- **The hub's own bundle will migrate to upstream OKF v0.2**, sequenced after
  the coordination change. With no PSC work left in this programme, validating
  a public bundle with a PSC-owned tool from a sibling checkout is a
  dependency with nothing on the other end.
```

### 2026-09-05

```markdown
## 2026-09-05

- **Brett ruled Q19 to Q30 in one sitting, and added three things that reshape
  the programme again.** The institute's working name changed (and changed
  again on 2026-09-09 — see that entry; the name recorded here was accurate
  for four days and is kept because a dated log records what was true, not
  what is true now); its GitHub organization does not exist yet, and the
  organization created the day before carries a superseded name. Only two repositories go there (Q26): the Foundry and
  SalmonBench. The plugin stays personal.

- **PSC work re-entered scope in one bounded form.** A **PSC core-model
  ontology** — a Domain-Driven Design distillation of the Commission's core
  domain, so Domain Data Engineers can relate their Bounded Contexts to it —
  in a new repository in the PSC organization, joining this hub as S16. It is
  paid PSC work: PSC-DSC keeps every planning field, this hub sequences the
  stream and indexes the release. **Fraser Recruits returns** as its first
  bounded-context registration, and only there; the public Foundry still does
  not touch it.

- **Hub coordination is being redesigned (S15).** Planning state moves to a
  git-native queue so any agent can pick up unclaimed work. The GitHub Project
  the first two drafts used was removed on 2026-09-09 (R12): it was the only
  part needing a token scope, an unattended credential, and a second
  representation to keep honest.
  The measurement that justifies it: 25% of this bundle is state, restated 3
  to 17 times, five copies stale the day they were counted. The measurement
  that sizes it: of 44 open backlog items, about 34 could be finished by an
  agent unattended, 5 wait on a decision, 1 on a credential — so the queue is
  real, and the bottleneck is the supply of `Ready`, which only Brett makes.

- **The paste was held on purpose, again, for a different reason.** On
  2026-09-04 it was held because Q19 was unruled. Q19 is now ruled *yes*, and
  the paste is still held — because the same day's ruling makes the member
  count derivable, and adding eleven copies of a number two days before
  deleting them is the disease being cured.

- **Four things the research overturned**, recorded because each had been
  about to become a design dependency: creating a git reference is **not** a
  documented compare-and-set (409 and 422 are both documented and neither is
  specified for an existing ref); a **public Project appears to be readable
  with no credential at all**; `gh project item-edit` sets a single-select by
  option **name**, not only by id; and the same-owner restriction that is real
  for repository *linking* does not apply to Project *items*. Two facts that
  did hold and that the boundary now rests on: a sub-issue must share its
  parent's repository owner, and a Project may hold issues from any
  organization.

- **A private-terms guard was installed on this machine** after Brett asked
  whether a hook could keep commercial product names out of public
  documentation. Two layers, one denylist outside every repository, tested.
  Its gaps are written down beside it: cloud sessions, Actions runners, and
  bare headless runs do not read user settings, and API writes are invisible
  to both layers.
```

### 2026-09-04

```markdown
## 2026-09-04

- **Two documents from Brett entered `plans/` as proposals, and neither is a
  sequencing authority.** The Salmon Science Foundry concrete plan (imported
  in the morning, reviewed and revised the same day: nine review dimensions,
  166 findings, six rulings from Brett, a six-lane research sweep) and the
  OKF-centred semantic knowledge architecture note, which the plan's
  semantics section now builds on. Both `type: Artifact`, `status: draft`;
  the bundle stayed green at the capture tier with both in place. A third
  document, the graph-design companion, is held outside the bundle pending
  Q21 because it names a commercial product.

- **Integration into the roadmap was deliberately not done.** Brett: *"let's
  not integrate it to the roadmap yet, that will come, but I do want you to
  prepare for that."* Prepared and held in the plan's appendices: an S14
  card, questions Q19–Q30, a domain-card row, a ninth release-index section,
  the sequencing edges, and the seed of the new repository's `knowledge/`
  bundle. None is pasted, because under the 2026-08-24 test the paste is the
  membership act.

- **The plan quoted the membership test correctly and violated it two tables
  later** — the shape worth naming. Its §4.2 stated the ruled test; its issue
  table then sequenced two non-members and disposed of three archived
  repositories. Eight → nine was not the count its own procedure produced.

- **Rulings that reshaped the plan (Brett, 2026-09-04):** a planned BC
  not-for-profit (working name Symecology Institute; GitHub organization
  created) as the home; the ecosystem is institute work, not PSC or Thunk
  work, so no PSC data or planning enters it; Fraser Recruits is out of the
  public Foundry for now; about five hours a week from Brett with agents
  doing more and fewer gates; a preprint per stage; benchmark questions to be
  crowdsourced; Claude Science as the work environment; arXiv for preprints.

- **What the review found about the hub rather than the plan.** OD-2 and the
  sequencing paragraph still read unruled while Q1 was ruled 2026-08-22 and
  the S3 card says so; the hub-coordination context still calls 0.4.0/0.4.0
  lockstep "the present state"; `sources.psc.yaml` registers nothing; the S4
  card's description still says PR #6 is open and `primary_key` absent
  (both closed 2026-08-26). A stale open decision propagated into the plan
  (its Workstream B item 12), which is the cost of not retiring it in place.

- **The validator does not see absolute paths.** Measured on a copy: a
  home-directory path injected into a card passes the capture and review
  tiers; a missing `type:` fails. The rule is checked by reading. Also measured for the new
  repository's seed: the PSC profile rejects `type: Concept` and the
  upstream `sources`/`generated` fields, so "one source-backed Concept" under
  this profile is an `InformationObject` citing a registered source.
```

## 6. Seed for `salmon-science-foundry/knowledge/`

**The profile changed on 2026-09-05.** Q30 is ruled: the Foundry's bundle uses
**upstream OKF v0.2** with the salmon knowledge commons' strict closed schema
and its `okf-check.py`, not the PSC profile. The reasoning is in the plan's
Appendix A; the short form is that the PSC profile rejects exactly the
provenance fields (`sources`, `generated`, `verified`, `stale_after`,
`resource`) the Foundry's Claim contract and SalmonBench's task provenance
need, and that validating an institute bundle with a PSC-owned tool from a
sibling checkout is the cross-boundary dependency R2 forbids everywhere else.

**So the blocks below need one edit before they are pasted**, and it is
recorded here rather than silently applied because the two shapes are not
interchangeable: drop `bundle.psc.yaml`, `sources.psc.yaml`, and
`reviews.psc.yaml`; move each card's `psc:` block to upstream fields; give
each card `sources:` with per-source `id`/`resource`/`title`, and `generated:`
with `by` and `at`; keep `type: Concept` where a card really is one; and
replace the validation command with the commons' checker
(`uv run --with pyyaml,jsonschema scripts/okf-check.py .`), vendored into the
Foundry repository. The blocks below are the **PSC-profile version as
validated on 2026-09-04** (`ok`, 0 errors, 0 warnings) and are kept so the
structure is legible; **do not paste them unchanged.**

`COMMIT` is the metasalmon commit that adds this plan; `YYYY-MM-DD` the
seeding date.

`knowledge/index.md`:

```markdown
---
okf_version: "0.2"
---

# salmon-science-foundry — knowledge bundle

Durable, source-backed knowledge about this repository for future agents and
maintainers, in Open Knowledge Format (OKF v0.2 frontmatter) using the PSC
profile v0.4 and its `psc-okf` validator from a sibling `psc-data-systems`
checkout. Seeded YYYY-MM-DD from the metasalmon hub's S14 card and its
execplan.

**What this bundle is not.** Not a roadmap and not a sequencing authority.
Cross-repository order, dependencies, and the release index live in the
metasalmon hub (stream S14); this bundle holds implementation detail and
campaign state, and links back rather than restating.

## Cards

- [Salmon Science Foundry (domain)](domains/salmon-science-foundry.md)
- [Hub edge (context)](contexts/hub-edge.md)
- [The metasalmon / Foundry tool boundary](data/tool-boundary.md)

## Validation

```sh
uv run --project ../psc-data-systems psc-okf check knowledge --tier capture
```

Cards are git-tracked and contain no absolute filesystem paths; the
validator does not check that (measured 2026-09-04), reviewers do.
```

`knowledge/bundle.psc.yaml`:

```yaml
profile_version: '0.4'
id: foundry:bundle:salmon-science-foundry
title: Salmon Science Foundry knowledge bundle
default_domain: foundry:domain:salmon-science-foundry
contexts:
  - foundry:context:hub-edge
source_registry: sources.psc.yaml
review_registry: reviews.psc.yaml
imports: []
review_policy:
  system_and_technical:
    qualified_reviewers: []
    minimum_outcome: qualified
  data_domain:
    qualified_reviewers: []
    minimum_outcome: qualified
publication:
  classification: internal
  audience:
    - foundry-maintainers
  source_allowlist: []
```

`knowledge/sources.psc.yaml`:

```yaml
profile_version: '0.4'
sources:
  - id: foundry:source:metasalmon-foundry-plan-2026-09-04
    resource: https://github.com/salmon-data-mobilization/metasalmon/blob/COMMIT/knowledge/plans/2026-09-04-salmon-science-foundry-concrete-plan.md
    title: Salmon Science Foundry concrete plan (metasalmon hub bundle, 2026-09-04)
    author: Brett Johnson
    last_modified: '2026-09-04'
    classification: public
    selected_for_publication: false
    retention: locator-only
    publish_locator: false
```

`knowledge/reviews.psc.yaml`:

```yaml
profile_version: '0.4'
reviews: []
```

`knowledge/domains/salmon-science-foundry.md`:

```markdown
---
type: ScientificDataDomain
title: "Salmon Science Foundry"
description: "The orchestration, data-access, and evaluation layer above the salmon data ecosystem's SDP tooling: a Tier 0 run ledger with digest-bound approvals, tool receipts around metasalmon and metasalmonpy, the salmon data-access verbs, research-run crates, and the SalmonBench task suite. Proposed 2026-09-04; nothing here is implemented."
status: draft
tags: [foundry, salmonbench, data-access, evaluation]
psc:
  id: foundry:domain:salmon-science-foundry
---

The domain this bundle documents. The Foundry coordinates campaigns *around*
artifacts other repositories own: Salmon Data Packages (spec `smn-data-pkg`;
implementations metasalmon and metasalmonpy), the Salmon Domain Ontology
(`smn:`), the GC DFO Salmon Ontology (`gcdfo:`), and the salmon knowledge
commons. It is not a third implementation of SDP behaviour and must not
become one. Membership in the salmon data ecosystem hub, and the sequencing
that follows, are the hub's to state — see the [hub edge](../contexts/hub-edge.md).

**State (YYYY-MM-DD):** proposed. Repository seeded; no runtime, no
benchmark task, no campaign exists. Generated by an agent from the plan; not
verified by anyone.
```

`knowledge/contexts/hub-edge.md`:

```markdown
---
type: Context
title: "Hub edge"
description: "The standing coordination context: the metasalmon hub sequences this repository's work as stream S14 and carries its release-index entry; this bundle holds implementation detail and campaign state only, and never a roadmap."
status: draft
tags: [coordination, hub]
psc:
  id: foundry:context:hub-edge
---

- The metasalmon `knowledge/` bundle is the sequencing authority; this
  bundle links to S14 and does not restate its dependencies.
- No roadmap here. Campaign manifests and implementation cards are dated
  records.
- Every release is an annotated `vX.Y.Z` tag plus a GitHub Release and a
  Zenodo DOI, and pins metasalmon, metasalmonpy, the `sdp-` tag, the smn
  release, a gcdfo commit or tag, and a commons commit; the pins are
  reported to the hub's release index in the same change.
- The Foundry calls metasalmon and metasalmonpy through command tools with
  versioned receipts, never as library dependencies, and never reimplements
  their scientific logic.
- No PSC data, code, credentials, or planning surfaces enter this
  repository (Brett, 2026-09-04).
- Cards are git-tracked and contain no absolute filesystem paths.
- Any agent touching this bundle checks the hub's S14 card for drift and
  fixes the hub in place.
```

`knowledge/data/tool-boundary.md`:

```markdown
---
type: InformationObject
title: "The metasalmon / Foundry tool boundary"
description: "metasalmon and metasalmonpy own package-local, deterministic SDP behaviour; the Foundry owns multi-stage, cross-repository research workflows and calls the packages only through narrow JSON-in/JSON-out command tools that return versioned receipts. Stated in the 2026-09-04 plan; not yet implemented or verified."
status: draft
tags: [boundary, tool-contract, receipts]
psc:
  id: foundry:data:tool-boundary
  contexts: [foundry:context:hub-edge]
  sources:
    verification:
      - foundry:source:metasalmon-foundry-plan-2026-09-04
---

**The claim.** Package-local curation state and deterministic domain
behaviour belong to metasalmon and metasalmonpy; model conversations, agent
routing, retries, cross-dataset fan-out, human-approval waits, and
campaign-level state belong to the Foundry. The Foundry never adds a
workflow server, an agent framework, or a durable-execution library as a
dependency of either package, and calls them through command tools of the
shape `salmon-foundry tool metasalmon validate-sdp request.json`, each of
which writes a receipt naming the tool, its version and commit, inputs and
outputs by SHA-256, and the exit code. `rpy2` is not the boundary.

**Source.** The plan's §1.3 and §3.5, registered as
`foundry:source:metasalmon-foundry-plan-2026-09-04`.

**What is true, what is not.** A design decision, stated and sourced. No
command tool, receipt, or adapter exists yet. Nothing here has been verified
by a person. *Retires when:* the first receipt is written by a real
`create_sdp()` call through the adapter; then this card cites the receipt
fixture and the schema, not the plan.
```

And one line in the repository's `AGENTS.md`: "Durable knowledge about this
repository lives in `knowledge/` (OKF, PSC profile v0.4); validate with `uv
run --project ../psc-data-systems psc-okf check knowledge --tier capture`.
Sequencing lives in the metasalmon hub's S14 card, not here."
