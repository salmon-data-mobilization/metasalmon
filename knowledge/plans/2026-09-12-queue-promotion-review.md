---
type: Artifact
title: "Queue promotion review, 2026-09-12"
description: "The first review of the hub queue after its first four claims: every icebox and needs_brett item assessed for promotion readiness, each promote candidate put to two adversarial refuters, the survivors ranked by the roadmap, the rulings Brett made on 2026-09-12 recorded with their reasoning, and the rulings still open explained with their options and implications so the next review starts here rather than from scratch."
status: draft
tags: [hub, queue, promotion, review, rulings]
psc:
  id: metasalmon:plan:2026-09-12-queue-promotion-review
  contexts: [metasalmon:context:hub-coordination]
---

# Queue promotion review, 2026-09-12

**What this is.** A dated record of one review of the hub queue: which items
could be promoted to `ready`, which could not and why, which rulings would
unblock the most, and what Brett ruled when the review was put to him. It is
written so the next promotion pass can start from this page and check what
has changed, instead of re-deriving sixty-six verdicts.

**What this is not.** Queue state. The item files under `queue/` are the
state, and a sentence here that disagrees with an item file is the sentence
that is wrong (`queue/README.md`, "the one rule for anyone editing by hand").
Where this page says an item *was* promoted or filed, it is reporting a commit
on `main` made on the date given, not maintaining the fact.

**How it was produced.** Nine assessors, one per stream group, read every item
file, its evidence, the sequence cards and the backlog entries, and returned a
verdict per item against the five claimable tests in `HUB.md`. Every verdict of
*promote* then went to two independent refuters with different lenses, one for
a hidden dependency or decision and one for staleness and overlap with work in
flight, each told to default to refuting. A synthesis ranked what survived by
`knowledge/roadmap.md`, which is the sequencing authority, and listed the
rulings by how much each unblocks. The run was measured against `main` at
`9d5434e` and finished after the merges of 2026-09-12 had landed, so the
in-flight picture below is as of that afternoon.

***Retires when*** a later promotion review supersedes it, or every item it
names has moved past the state recorded here. Until then it is the reference
Brett asked for: "file it somewhere permanent that can be reviewed again, so
we don't have to do an entire review for the next little while."

## 1. Rulings Brett made on 2026-09-12, and what was done with them

Brett's reply to the proposal, quoted where a commit needs to name its
authorization (`HUB.md`, `ready_is_set_by`):

| Ruling | Effect on the queue |
|---|---|
| "promote B-111" | B-111 `ready` |
| "B-116 is approved" | B-116 `ready`, its retirement condition rewritten to carry the approved shape (section 3) |
| "S-03 is approved" | Nothing an agent can do until the DataONE test-node token exists in a session; S-03 stays `needs_brett` (section 4) |
| "metasalmonpy port queue item is approved" | B-126 filed as `ready`; S-05 `claimable: false`, blocked by B-58, B-59, B-126 |
| "Feel free to mark B13 and B86 done" | B-13 and B-86 `done`; both spot-checked as already merged before the state changed |
| "set claimable to false on the streams that you listed" | S-02, S-04, S-05, S-06, S-07, S-11, S-13 `claimable: false` |
| "fix B99's repo to SMN data package" | B-99 `repo: smn-data-pkg`, retirement condition narrowed to the one example that still 404s |
| "split B113 into a per repository pair" | B-113 kept as the metasalmon half; B-127 filed as the metasalmonpy twin, blocked by B-113 |
| "correct the S15 card and item" | The sentence saying the locks repository does not exist removed from the S-15 item, the S15 card and the roadmap |
| "file the missing items the analysis found" | B-128 to B-139 and Q-40 filed (section 7) |

Rulings Brett asked to have explained before deciding are in section 4, each
with its options and implications, and stay open until he answers.

## 2. Method notes worth keeping

- **Refutation earned its cost.** Ten of eleven candidates the assessors
  marked *promote* were refuted, and every refutation was a specific, fixable
  defect in the item file rather than a disagreement about the work: a
  retirement condition that pre-commits to a mechanism that cannot cover its
  own cases, a `repo` field that would land a claim in the wrong repository,
  a condition that spans two repositories when a claim covers one branch. The
  item file is the contract an unattended agent works to, so a wrong file
  costs a whole claim.
- **Severity and ordering disagreed in the expected direction.** The last
  P1 (B-48) waits on a P4 ruling (B-106). The backlog's own introduction
  flags this shape; the queue makes it visible by the `blocked_by` chain.
- **The queue's evidence pointers were fixed mid-review** (PR #110 merged
  during the run), so every "pointer does not resolve" finding in the raw
  assessments was stale by the time the synthesis ran. The synthesis
  discarded them; none is recorded here.

## 3. Promoted on this review

**B-111, make `create_sdp()`'s three create-owned sidecar writes atomic**
(metasalmon, P2). Unsequenced correctness debt: the residual of the
2026-08-22 abort-safe write path, which the roadmap lists as what outlived
S10. All five claimable tests held; both refuters passed it. Spot-checked:
`.ms_replace_create_output()` still has exactly three callers
(`semantic_suggestions.csv`, the EDH XML, `README-review.txt`), and the
atomic write set and the abort-injection test template both exist in tree.
Caveats for the claimant: same-file rebase against `R/package-helpers.R`
after #111 merges; parity row 53 must be amended in the same pull request to
record the R half closed, with the metasalmonpy half left open because its
EDH path reads the package from disk inside the window.

**B-116, ship a producer for the reviewed semantic closure** (metasalmon,
P1). Promotable once its public shape was ruled, and Brett approved the shape
the backlog proposed: one exported `write_sdp_semantic_closure(path,
evidence = NULL)` that derives both canonical sets, resolves smn and gcdfo
evidence, accepts hand-supplied rows for QUDT, writes both files and the
sidecar hashes, and reports an unresolvable IRI as a gap rather than
aborting, because a gap is what the term-request pipeline consumes. The same
ruling fixes the export set for the internals S-13 requirement 1 shares. One
correction to the backlog's count: the rehearsal script calls internals at
three sites, not two.

**B-126, port metasalmon 0.5.0 to metasalmonpy** (metasalmonpy, P1). The
0.4.0 to 0.5.0 catch-up window has been open since 2026-08-25 and had no
item, which is why S-14 could not name what it was waiting for. The
retirement condition is the register's "what the port owes" section: the
nine review functions, the `decision_reason` column, an accessor for the
suggestion attributes, the `constraints.required` consumer, the #118
auto-apply fix, PARITY.md row 31 amended in place, the mirror's stale
AGENTS.md parity line, and the version moved to 0.5.0 only when the
behaviour lands. If too large for one claim, the first slice is the row-31
amendment, the #118 fix and `decision_reason`. The claiming session needs
metasalmonpy attached with push access.

## 4. Rulings that unblock the most, explained

Ordered by how much each frees. Recommendations are the review's, not
rulings; a ruling is Brett's sentence in chat or in `knowledge/questions.md`.

### 4.1 B-106, which reading of "typed as a SOSA Procedure" the spec means

**Context.** smn-data-pkg's `schema/sdp.rules.yaml` carries two rules,
`methods_are_sosa_procedures` and `row_varying_procedures_use_codes`, both
saying a method IRI must "resolve to a shared vocabulary concept typed as a
SOSA Procedure". Nothing executes either rule today: the publication
validator never reads the rules file, only the artifact generator bundles it,
which is why the wording and the modelling drifted apart unnoticed (#48).
smn types only its broad method concepts as `sosa:Procedure`; the ten
narrower enumeration methods that metasalmon's NuSEDS crosswalk targets
exist only in gcdfo, as SKOS concepts under typed parents. The crosswalk
carries 55 gcdfo CURIEs today, up from the 45 the backlog counted.

**Option (a), direct typing.** Every method IRI must itself carry
`rdf:type sosa:Procedure`. Every current crosswalk target becomes
non-conformant. Conformance then needs either gcdfo to type ten narrower
concepts (another organization's repository, patch-only for agents) with
every crosswalk target re-appraised, or metasalmon to retarget onto smn,
which needs ten narrower smn method concepts minted first, a namespace
boundary call, plus a paired metasalmonpy change.

**Option (b), reachability.** The IRI is, or sits `skos:broader*` under, a
concept typed `sosa:Procedure`. This matches smn's own method shapes and
gcdfo's modelling, makes every current target conformant, and costs one
rewording of the two rules in smn-data-pkg plus a consistency check in both
implementations. Its cost is a looser gate: a narrow concept passes on its
ancestor's typing, which is what a SKOS hierarchy asserts anyway.

**What it unblocks.** B-48 (the last P1: three error-severity rules loaded
and never executed) becomes claimable whichever way the ruling goes; B-76
(gcdfo as the recorded NuSEDS method source, or retarget) is settled by the
same sentence; S-01 and a Foundry dependency follow.

**Recommendation.** (b), with gcdfo recorded as the deliberate method
source. File the ruling as a question entry so it is asked somewhere; today
it is not.

### 4.2 Q-06, the eight smn PR #27 modelling questions

**Where it stands.** smn's PR #27 mints the life-history terms (the sockeye
lake-, river- and sea-type concepts among them). It lists seven open
questions; the S9 review found an eighth. On 2026-08-24 Brett asked for an
expansion before ruling and a briefing was written that day. All eight are
still unruled. Since then, the 2026-09-02 source pass found two of the
briefing's attributions failing the passage check, which produced B-122
(what Gilbert 1913 actually counts) and B-121 (regenerate the replacement
literals from the commons cards). The S9 card, the roadmap and the Foundry
plan all say the amendments come first, but the item's `blocked_by` is
empty. PR #27's live state could not be verified from this session.

**The eight.** (1) Does "species go in smn, never gcdfo" survive a gcdfo
code vocabulary carrying `dwc:scientificName` and a WoRMS id directly; (2)
is a bare `dwc:scientificName` literal acceptable on a life-history concept;
(3) two decomposition properties or one generic
`smn:hasLifeHistoryAxisValue`; (4) is `smn:SockeyeSeaTypeLifeHistory`
wanted at all, since it is not in the source data; (5) accept the large
prefix rewrite or take the smaller fix; (6) whether "cycle line" renames away
from issue #70's wording; (7) straight into shared `smn:` or through a
program profile bridge; (8) whether lake-, river- and sea-type sockeye are
peers, given that the literature holds both readings and the commons marks
the distinction contested.

**Options.** Rule all eight now on the 2026-08-24 briefing: fastest, but two
of its literals are known to be misattributed. Add `blocked_by [B-121]` and
rule after regeneration: the recorded sequencing, at the cost of waiting on
B-122, which is itself entangled with Q-38 and needs commons access. Split:
rule decision 1 now, because B-108 hangs on it and it does not depend on the
failed attributions, and rule 2 to 8 after B-121.

**Recommendation.** Split. Decision 1 per PR #27's own ADR-0003: species
reference by `dwc:scientificName` literal plus a WoRMS identifier.

### 4.3 Q-38, what a verified entry on a commons card means

**Context.** Every commons card carries `generated` (who wrote it) and
`verified` (who independently checked it), and the rule that a writer never
asserts their own verification is prose only: the two fields share one
schema pattern, a self-verifying card validates, and the repository has no
CI. Q24 (2026-09-05) already ruled the who-half for publication: a card is
*stable* when it carries a named human `verified` entry and passes its
citation ledger, and cards the Foundry writes carry `generated`, never
`verified`. What is open is the what-half, whether Q24 binds the commons
generally, and Brett's two questions: what gates would let an agent's check
count for something, and what human verification should mean.

**Proposed scheme: two tiers with distinct field values, so no card can
claim more than it earned.**

- **`checked`, agent-eligible, never spelled "verified".** An agent that is
  not the generator (a different session token, recorded) re-resolves every
  citation with the citation-ledger procedure (DOI metadata or fetched page
  with a title check, defining passage located by section or page, negatives
  logged), re-derives each claim from the located passages without reading
  the card's own argument, and records the ledger path, its token, the date
  and any disagreement. Gate: every citation resolved and located, zero
  unresolved rows, and agreement; any disagreement moves the card to
  `disputed` rather than leaving a partial check. Rigour floor: two such
  checks from different sessions or models that agree, which is the
  adversarial pattern this review itself used. All of it is machine-checkable
  in the commons' CI: the ledger must exist and pass, and the checker's
  identity must differ from the generator's.
- **`verified`, human only.** A named person who is not the generator has
  read the located passages, not the card's summary, and affirms the claim;
  recorded with name, date and what was read.
- **A graded human bar, so the bar matches the consequence.** One human
  `verified` entry makes a card verified. *Stable* (publishable under Q24)
  needs two humans who did not generate it, or one human plus two agreeing
  agent `checked` entries. Three independent humans agreeing is the right bar
  for a card that carries a ruling, one that mints, retargets or defines a
  term, or fixes a modelling decision, and would freeze the commons if asked
  of every card, since it has one active human today.

**Implications.** B-123 becomes writable: a schema split so `verified.by`
cannot equal `generated.by`, a human-shaped identity pattern for `verified`
and a ledger path for `checked`, and one CI workflow. Q-39 becomes
measurable in the shape Brett wanted: an agent prepares the `checked` tier,
a human does the `verified` step, and the cost measured is the human step
net of agent preparation. B-122 and B-121 stop being blocked on the meaning
of overruling a cross-checked card. The Q38 and Q39 entries still need to be
appended to `knowledge/questions.md`, whose index stops at Q37.

### 4.4 Q-09, the property slot for a spawner count

**Context.** Under the I-ADOPT decomposition a measured variable is a
property of an entity, with a unit, a constraint and a statistical modifier
where they apply. For a spawner count the variable (`term_iri`) is
`gcdfo:SpawnerAbundance`; the question is whether `property_iri` is the
generic `smn:Abundance` or the same gcdfo IRI again. Both shipped
dictionaries already carry `smn:Abundance` as property and
`gcdfo:SpawnerAbundance` as term; the seeder writes the same IRI into both
slots only because the variable and property retrievals return the identical
gcdfo ranked list, which is B-119.

**Options.** `smn:Abundance` as property, `gcdfo:SpawnerAbundance` as
variable: the property stays generic and reusable across entities
(spawners, smolts, recruits), matches the example README's argument and the
dictionaries, and implies fixing B-119's retrieval filter with a
differential test on the two roles. The gcdfo IRI in both slots: no
decomposition value, every entity-specific variable becomes its own
property, and it contradicts what the dictionaries already teach. Minting an
`smn:SpawnerAbundance`: a new term nothing needs.

**Recommendation.** The first. Record it as an ecosystem I-ADOPT ruling in
the smn-data-pkg specification's annotation guidance, with a commons card,
and the questions file pointing at both. For the sub-question B-119 raises,
whether an untyped gcdfo term may ever serve as a property by regex: no; a
property comes from a source with I-ADOPT typing or an explicit property
mapping, and gcdfo terms are variables or entities unless typed.

### 4.5 B-58, condition classes

**Context.** metasalmon raises about 479 `cli_abort`, 45 `cli_warn` and 4
`rlang::abort` calls, none with a `class` argument, and documents no
condition class. Callers, including tests, the parity harness, the KNB
pipeline and workshop code, can only catch by message text, so a wording
change breaks them silently. The fix is a hierarchy: a `metasalmon_error`
root with `metasalmon_validation_error`, `metasalmon_llm_error` and
`metasalmon_publication_error`, as the 2026-08-10 review proposed; every
abort carries a class, tests catch by class, one help topic documents them.

**Decisions inside it.** The scheme itself: the four classes, or a finer
taxonomy (schema and I/O errors, a parallel `metasalmon_warning` family for
`cli_warn`). Whether it may land before a major release: adding classes is
additive, an existing `tryCatch(error = )` keeps working, so it can land on
`main` now with the version bump left as a separate release decision; the
S5 card tied #58 and #59 to a breaking-release story for release economics
only. The mirror: metasalmonpy needs a matching exception hierarchy in the
same stream, and whether it has one is unmeasured because that repository
was not attached to the reviewing session. Timing: about 528 call sites
conflict with every open R branch, so it follows #111's merge and can be
done in per-file slices.

**Implications of leaving it.** B-59's fate turns on it, because the
`validation_message_mode` option channel is exactly what classes replace.

**Recommendation.** Accept the four classes plus a `metasalmon_warning`
parallel, land additively on `main`, mirror in Python in the same stream.

### 4.6 The smaller rulings

- **B-107, smn's undefined `sosa:Property`.** `smn:Characteristic` is a
  subclass of, and `smn:characteristicFor` has its domain in, `sosa:Property`,
  which the vendored SOSA import does not declare; only `ObservableProperty`
  is there, and the reasoner stays green because nothing checks undeclared
  superclasses. `sosa:ObservableProperty` is vendored and smn already maps
  `iadopt:Variable` close to it; `ssn:Property` is broader (it also covers
  actuatable properties) and would need SSN vendored for one class.
  Recommend `sosa:ObservableProperty`, and split out a build check that
  every asserted superclass is declared or vendored, which needs no ruling.
- **B-112, `migrate_sdp_methods()`'s report shape.** The nothing-to-migrate
  branch returns a two-column empty frame; the populated branch returns
  three (it adds `columns`). Python had the consistent three-column shape
  first and was changed to mirror R's inconsistency during S10. Ruling: the
  same three-column shape from both branches. Recommend yes; a one-line
  change each side plus tests.
- **B-115, one spelling for a descriptor instant.** A typed `POSIXct` in
  `temporal_start` or `temporal_end` renders into `datapackage.json` as the
  space-separated `0999-06-05 13:45:30`, which is not valid `xs:dateTime`,
  while `dataset.csv` gets readr's `0999-06-05T13:45:30Z`: two renderings of
  one value, the class Q12 ruled against. Recommend the ISO `T` and `Z` form
  in the descriptor; it changes bytes only for packages that carry a typed
  instant, which neither implementation produces itself. The alternative,
  making the CSV match the space form, makes the CSV invalid; coercing inside
  the aligner was ruled out under #93. Rule once for both implementations.
- **B-0, the gcdfo widoco baseline.** The docs recipe copies the working-tree
  webvowl JSON as the normalizer's baseline before overwriting it, so a failed
  run compares against the file it just replaced and goes green over raw
  output. The working-tree baseline was deliberate: it lets repeated local
  refreshes compare against the previous local run. Option (a), baseline from
  git HEAD, gives that property up; option (b), keep it and restore the
  pre-run bytes on failure with a trap, keeps it and still passes the
  retirement test. Recommend (b). Patch-only in a shared repository, and it
  needs a local WIDOCO and Java toolchain.
- **B-78, the iop-triple explainer.** Emitting observation triples from an
  SDP was deferred on 2026-08-13 pending an explainer; the wording leaves it
  unclear whether the explainer itself is deferred. Recommend allowing the
  explainer now as its own claude-science item (a knowledge card with a
  recommendation, no code) and keeping the decision half parked.
- **B-60, two clauses of the API-surface item.** (a) `DESCRIPTION` hand-writes
  `Codex [aut]` while `Authors@R` names only Brett; deriving from `Authors@R`
  alone means dropping the credit or adding it there. Attribution is Brett's
  call; if kept, `ctb` fits better than `aut`, which CRAN reads as authorship
  with copyright weight. (b) The exported surface has six name shapes; a
  written convention is either descriptive (documents the shapes, no renames)
  or normative (renames ride the major with #58). Recommend descriptive now,
  with the renames listed for the major. The mechanical clauses (drop
  `@import httr`, unwrap the offline examples, add the 23 missing examples)
  can be split into a promotable sub-item on Brett's say-so.
- **B-31, the curation-state boundary.** Either `chat_decomposition()`'s
  session engine becomes one mode of a metasalmon-owned curation engine (the
  S7 card as written) or metasalmon keeps only single-package, replayable
  curation functions and conversations, routing, retries and approval waits
  live in the Foundry (plan §1.3, ruled with Q19). Building a shared engine
  before ruling puts code on whichever side loses. Recommend the §1.3
  boundary, amend the S7 card, and keep B-31 unclaimable until then; if the
  ruling is "stays separate", B-31 retires by the ruling and B-3 narrows to
  the body-builder slice filed as B-128.
- **S-03.** Not a ruling but Brett's own two actions: a DataONE test-node
  token and one end-to-end deposit against the test node. An agent can run
  the deposit in a session that carries the token as the documented option
  or environment variable; the token never enters a repository.
- **S-04.** The one stream whose retirement needs third-party review in a
  repository outside the grant: the workshop rebuild, which retires on
  Bruno's and Tom's review and a live rehearsal. Set unclaimable on this
  review. If Brett wants it agent-finishable, the split is the human review
  conditions into a `needs_brett` item and the build and rehearsal
  preparation kept claimable.

## 5. Candidates refuted, and the one edit that lifts each

| Item | Why refuted | Lifts when |
|---|---|---|
| B-55 | Its retirement condition pre-commits to a warning handler that cannot cover boolean and date coercions, which raise no warning in R; the test clause spans metasalmonpy | Rewritten behaviourally: under `strict = TRUE` any non-missing input that becomes missing after coercion aborts for every value type; the codes step aborts under strict naming unlisted values and warns otherwise |
| B-56 | Ignores the existing `find_terms()` result cache and leaves the degraded-result rule and the mirror unstated | The item names the cache and the layer: dedupe at the `suggest_semantics()` map over query, role and sorted sources, never serving a degraded result, with a counting test |
| B-59 | An uncountable condition ("nine", "fourteen"), a missed RNG site, and a side-channel option whose fate B-58 decides | The condition made enumerable (every `metasalmon.*` option and `Sys.getenv()` name in R, including the per-source timeout family), the retry-wait RNG site named, and the release shape settled with B-58 |
| B-82 | Collides with B-44's prepared patch in three files and hides the dead ONTO fallback decision | B-44's patch applied, `blocked_by [B-44]`, and the fallback ruled |
| B-83 | Fixing line 614 alone leaves its clause false, because line 577 quotes `smn:Population` verbatim and has also drifted | Narrowed to line 614 with the sibling filed (B-138) |
| B-99 | `repo` named metasalmonpy, whose half was discharged at S10 chunk A; only smn-data-pkg's minimal example still 404s | Repo and condition corrected on this review |
| B-105 | The dead LICENSE link was left deliberately and no licence decision exists, so every exit rules on it | Q-40 filed and added to `blocked_by`; a citation grammar and a failing fixture named |
| B-108 | Its pinned NCBI range is itself the taxonomy-authority ruling that Q-06 decision 1 points away from | Q-06 decision 1 ruled, or `blocked_by [Q-06]` added, and the competency-query clause restated |
| B-113 | One `repo` field for writes in two repositories | Split on this review: B-113 (metasalmon) and B-127 (metasalmonpy) |
| B-122 | Gilbert 1913 supports both counts, so "the losing card" is a judgement; the cards are in a private repository this session cannot read | Re-posed so no losing card is named, Q-38 ruled or bypassed, commons access provisioned |

## 6. Everything else, in one line each

- **Waits on a merge:** B-53 (after #112, now merged, so promotable next),
  B-57 (after #111, or carve out sub-item (e)), B-117 (after #111), B-120
  (after #112 and a ruling), B-23 (after #112, citations corrected), S7-b and
  S7-c slices.
- **Waits on a ruling above:** B-48 and S-01 (B-106), B-119 (Q-09), B-121
  and B-123 and Q-39 (Q-38), B-107 and B-108 (their own rulings and Q-06),
  B-3 and S-07 (B-31), B-0, B-76, B-87, B-112, B-115, B-78.
- **Waits on Brett's action:** S-03 (token and deposit), Q-13 (a human
  email to the KNB support desk, or abandoning the series), B-80 (one live
  request under his OpenRouter key), S-14 (the institute organization and
  repository), S-15 (record the race test and rule the point of no return).
- **Idle-capacity cleanups:** B-22 and B-24, to batch as one S7 item on
  request.
- **Containers:** S-02, S-05, S-06, S-07, S-11, S-13 promote slices, never as
  units; S-04 also needs third-party review; S-10 is done and its real
  successor is B-126.
- **Questions:** Q-17 and Q-18 are the lowest tier (a cost difference with
  identical outcome; a byte idiom inert to behaviour).

## 7. Items filed from this review

| Id | Repository | What |
|---|---|---|
| B-126 | metasalmonpy | The 0.5.0 port (section 3); `ready` |
| B-127 | metasalmonpy | Package-ownership sentinel, the twin of B-113 |
| B-128 | metasalmon | The narrow chat body-builder slice carved from B-3 |
| B-129 | metasalmon | S-11 slice 4: an R semantic-review vignette for the 0.5.0 flow, tidyr in Suggests |
| B-130 | metasalmon | S-13 requirement 3: a bounded IRI-dereference verifier |
| B-131 | metasalmon | A guard test for the eight `:::` internals the rehearsal script calls |
| B-132 | metasalmon | The live-upstream schema test that errors on a 2-second timeout instead of skipping; it failed CI on #112 and passed on re-run |
| B-133 | metasalmon | Two vignettes whose tangled code fails R CMD check locally because `eval = FALSE` is set from a chunk `purl` does not honour |
| B-134 | dfo-salmon-ontology | Undeclared `gcdfo:` IRIs in shapes, example data and competency queries; a term decision, so `needs_brett`; blocked by B-44, whose patch carries the list |
| B-135 | dfo-salmon-ontology | The contradictory idiom in the conventions document and the five new WARN rows; blocked by B-44 |
| B-136 | dfo-salmon-ontology | `duplicate_label` on the two Wild Salmon Policy terms keeps the B-44 patch red until a label changes; `needs_brett`, blocked by B-44 |
| B-137 | metasalmon | Six locale-dependent tests that fail in a C locale |
| B-138 | metasalmon | B-83's sibling at line 577, the `smn:Population` quote |
| B-139 | metasalmon | Backlog #29 and #30, the S7 file splits, which the backlog marks partially addressed |
| Q-40 | smn-data-pkg | The licence: MIT or CC BY 4.0 for a specification repository whose schemas MIT libraries vendor |

Also on this review: B-49 moved to `review`, the state HUB.md names for a
handback whose claim is still held, which the promotion commits of
2026-09-10 had left at `ready`.

Left for the next pass, deliberately: the Q38 and Q39 entries in
`knowledge/questions.md`, whose index stops at Q37; question entries for the
rulings parked without one (B-106 with B-76, B-0, B-112, B-115, B-116's
shape, B-31); and the backlog's own status lines for #13, #86 and #99, which
restate queue state and are now the copies that are wrong.

## 8. In flight on the date of this record

Four items were claimed on 2026-09-10, the queue's first real claims. By the
afternoon of 2026-09-12: B-90 merged as smn-data-pkg#7 and B-95 as
metasalmon#112, both after Codex review and an independent adversarial
review, with every confirmed finding fixed on the branch first; B-49's
#111 was green and being brought through its Codex findings; B-44's patch
for the shared dfo-salmon-ontology repository was delivered to Brett with its
pull-request text, its claim held for him and past its lease. PR #110, the
queue's own Codex round, merged with the five findings fixed in #113. The
two ports those merges leave owed are B-124 and B-125.
