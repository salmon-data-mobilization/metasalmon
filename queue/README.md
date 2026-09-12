---
title: "The hub queue"
description: "What the queue under queue/ is, what one item file means, how an evidence pointer resolves, which venue an item wants, why a claim is a git ref rather than a row in a tracker, exactly what the private-terms guard does and does not see, why there is no GitHub Project, and the rule that a card restating queue state is a defect."
status: draft
tags: [coordination, queue, hub]
---

<!--
This directory is deliberately outside the `knowledge/` OKF bundle. The bundle
validator fails closed on a non-Markdown file inside a bundle, and Brett's
standing instruction keeps operational state with its owning system rather than
in the knowledge bundle. So this file carries a plain front matter and no
`psc:` identity: it is documentation of a running system, not a bundle card.
Retires when: the queue moves back inside a bundle, which nothing currently
proposes.
-->

# The hub queue

The queue is the planning state of the salmon data ecosystem, in one YAML file
per work item under `items/`. Before it existed, that state lived in prose:
stream status, blocked-by, severity, open or closed, what needs Brett. Section
9.1 of the [Foundry plan](../knowledge/plans/2026-09-04-salmon-science-foundry-concrete-plan.md)
measured what that cost. About a quarter of the bundle's non-plan lines were
planning state, one fact was restated in as many as nine files, and on
2026-09-05 five of those copies were wrong. None of them looked wrong.

The queue exists so that a state fact has one home. Everything downstream of it
reads that home instead of remembering.

The protocol is in `HUB.md` at the repository root, which is
the single policy file: the states, the pickup protocol, and the register that
is the only copy of the authorization boundary. The reasoning behind all of it
is section 9 of the plan linked above. This file explains what the queue is;
it is not the protocol and it does not grant anyone anything.

## What one item file means

One file is one unit of work somebody could pick up, finish, and be done with.
Its name is its id. Its fields say what the work is, where it happens, what it
is waiting on, and what has to be true for the item to stop existing.

```yaml
id: B-53
kind: defect
title: One line, no trailing period
state: icebox
claimable: true
repo: metasalmon
stream: S1
severity: P2
venue: claude-code
blocked_by: [B-90, S-12]
legacy: '#53'
evidence: knowledge/backlog.md
retires_when: Sentence saying what makes this item stop existing
```

`HUB.md` carries the normative field list; the block above is illustrative, and
if the two ever differ, `HUB.md` is right and this one is the copy that is
wrong. Five things about the shape are worth saying here, because each is load
bearing rather than stylistic:

- **One scalar per line at column 0, and `blocked_by` in inline flow style
  only.** The extractor that reads these files is a small awk program, so the
  format is chosen to be read exactly rather than approximately. A file that
  needs a full YAML parser to understand has already broken the contract.
- **`retires_when` is required on a defect.** A defect with no stated end
  condition outlives its cause and then sits in the queue looking like work.
  This is the same rule the package applies to every guard, suppression, and
  exclusion: a thing that silences a signal has to say what would retire it.
- **`claimable: false` is required when the item needs a decision from Brett or
  a credential he holds.** Section 9.2 counted five of the first class and one
  of the second among 44 open items. Leaving them claimable does not make them
  reachable; it makes an agent claim one, discover it cannot proceed, and hand
  it back, having taught the queue nothing.
- **`legacy` preserves the citation the item replaces.** Backlog items keep
  their numbers, so a passage citing `#53` in a commit message, a card, or a
  test comment still resolves after the migration.
- **`evidence` is a path from the root of this repository**, resolved with
  `cd` to the metasalmon checkout and nothing else. The base is fixed below,
  because two other readings of it were in circulation and neither resolves.

### Where an evidence pointer resolves from

**One sentence, and it is the whole rule: an `evidence` value is a path
relative to the root of the repository that holds the queue, which is
`metasalmon`, so `knowledge/backlog.md` is the correct form and `backlog.md`
is not.**

Three bases were possible and two of them are wrong in ways worth naming, so
that nobody re-derives the discarded ones:

- **Relative to the `knowledge/` bundle.** This is what the item files were
  generated with, because the queue was drafted inside the bundle. It stopped
  resolving the moment the queue moved to the repository root on 2026-09-09,
  and it resolves from no directory a reader is ever standing in.
- **Relative to the root of the repository named by the item's `repo` field.**
  This is the reading a careful person reaches for, and it is wrong: every
  current pointer is into metasalmon's `knowledge/` bundle, including on items
  whose `repo` is `smn-data-pkg` or `metasalmonpy`. Making the base follow
  `repo` would send `B-103` looking for `knowledge/backlog.md` inside
  `smn-data-pkg`, where it does not exist.
- **Relative to this repository's root, always.** Chosen. A reader who has
  cloned metasalmon and nothing else can resolve every pointer, which is the
  property the field exists for, and the base does not vary by item.

Evidence that genuinely lives in another repository is written as a full
`https://` URL instead. No item needs that today; the allowance is here so the
first one that does has an answer rather than a precedent to invent.

`state` moves through `icebox`, `ready`, `claimed`, `needs_brett`, `review`,
`done`. Only the move into `ready` is special: it is a commit on `main`, made by
Brett or by an agent acting on an authorization he gave in chat, and an agent's
promotion commit has to name that authorization. **Until 2026-09-10 this was a
wall an agent could not climb, because it could not push to `main` at all; it is
now an audit trail.** So the property that an agent cannot invent its own work
is no longer structural, and a promotion citing nothing is a defect rather than
an impossibility. `HUB.md` is the operative copy of that rule and of every other
write an agent may make; this file describes the queue and grants nothing.

## Which venue an item wants

Brett works mainly in Claude Science and in Claude Code, and the two are good
at different things. `venue` records which one an item wants, as one of
`claude-science`, `claude-code`, or `either`. The test is what the work
actually needs, not what it is about:

- **`claude-science`** when the work is reading, evidence synthesis, semantic
  judgement, statistical analysis, or scientific writing: ontology alignment
  and term decisions, evidence briefings, source and citation checking,
  benchmark task authoring and scoring analysis, preprints, and anything whose
  output is an argument rather than a commit.
- **`claude-code`** when the work needs the repository, the R or Python
  toolchain, a local credential, CI, a release, or a git push: package
  defects, parity ports, validators, packaging, workshop builds, and the
  queue's own machinery.
- **`either`** when it is genuinely both, or when the deciding factor is which
  one Brett happens to be in.

Two rules keep this from becoming decoration.

**The venue is advice and never a gate.** Nothing in the client reads it, no
check enforces it, and no claimable test mentions it. An agent in the other
venue that can do the work should do the work. A field that blocks work is a
field that gets faked, and a faked field is worse than an absent one because it
still looks like information.

***Retires when*** it stops changing a decision. If a season passes in which
every new item is `either`, or in which nobody has routed work by reading it,
delete the field from the item files and delete this section rather than
maintaining a column of noise.

`venue` is documented here and not in `config.yaml`, because that file holds
only the values the client reads and the client does not read this one.

## Why a claim is a git ref

A claim is a plain `git push` of an orphan commit to a ref under the claim
prefix, in a separate small locks repository named in
[`config.yaml`](config.yaml). Three reasons, in the order they matter.

**It is atomic with no race window.** An orphan commit can never fast-forward
an existing ref, so a first claim succeeds if and only if nobody holds the
item. Every later record on that item, a heartbeat or a release or a handoff or
a reclaim, is a child of the tip the agent just read, so it succeeds if and
only if nobody appended since. Git's own compare-and-swap does the work, and
there is nothing to get wrong in the client. The alternative that was on the
table, creating a reference through an API and reading an error status as
"already claimed", turns out not to be documented: the reference lists two
plausible statuses and does not say which one means the reference exists.

**It needs no permission that Brett's standing rule protects.** A ref push is
not an issue, a comment, a review, or a pull request, so the claim protocol
itself asks for nothing his rule guards. That is a property of the claim, not a
claim about everything an agent does: since 2026-09-10 an agent may also open
one draft pull request per handed-back item, and may merge, promote, or push a
small mechanical change under conditions `HUB.md` sets out. Read the register
there for what is permitted; nothing in this section widens or narrows it.

**Git is the only write path, so nothing here is invisible to the
private-terms guard by virtue of being an API call.** That much is true and it
is the reason the design is shaped this way: an API write would have been
outside every layer that exists. What is *not* true, and what an earlier
version of this paragraph claimed, is that every write is therefore inspected.
Measured on this machine on 2026-09-09, the layers see this much:

- The Claude Code `PreToolUse` layer matches `Write`, `Edit`, `MultiEdit`, and
  `Bash`, and for `Bash` it scans only write-shaped commands, meaning a
  redirect, a heredoc, `tee`, or an in-place `sed`. It therefore reads every
  edit to an item file, to `config.yaml`, and to this README. It does not read
  a `hub claim` or `hub release` invocation, because a client call is not
  write shaped.
- The global `pre-commit` layer reads the added lines of a working tree
  commit, in every repository and from any agent or editor on this machine,
  not only from Claude Code. It therefore also covers every item file edit.
- **Neither layer reads a claim record.** The client builds one with
  `hash-object`, `mktree`, and `commit-tree` in a bare object cache, so no
  `git commit` runs and `pre-commit` is never invoked. The `pre-push` layer
  does fire on the push out of that cache and inspects nothing: in a bare
  repository `git rev-parse --show-toplevel` is empty and the
  `@{upstream}..HEAD` diff the hook greps is empty, so it passes without
  having read the commit.

The exposure that leaves is one field wide. A claim record carries `id`,
`agent`, `action`, `lease_until`, `attempt`, `branch`, and `reason`. Every one
of those except `reason` is an id, an agent token, an enumerated action, a
timestamp, or a branch name built from an id. `reason` is the only free text an
agent composes, and it is what reaches the locks repository unread.

Either of two changes would make the strong claim true, and the first is
better:

1. **Constrain `reason` to an enumerated set of tokens**, with anything
   discursive going into the workpad on the agent branch, which is an ordinary
   commit and therefore covered. Then no free text reaches the locks
   repository at all and the property holds by construction, which is the same
   argument that removed the API write path.
2. **Have the client check the record body against the same denylist before
   `commit-tree`** and refuse to write on a hit. This works, but it is the
   weaker option, because the local layers fail open when the denylist is
   absent, so it turns a structural property back into a runtime one.

***Retires when*** either change lands and a test pins that a denylisted term
in a release reason is refused. Until then, treat a release, handoff, or
reclaim reason as text that will be published unread, and write it that way.

One consequence of the protocol is worth stating here because it surprises
people: **a handoff does not release the claim.** The agent appends a `handoff`
record and the item stays unclaimable until Brett merges the work, so finished
work never looks free again while he is away.

## Why there is no GitHub Project

There was one in the first two drafts. Brett removed it on 2026-09-09, and the
smaller design is the better one. The Project would have given a board view,
drag-to-promote, and a link for someone who is not Brett. It would have cost a
token scope reaching every member organization, an unattended credential in
Actions secrets, a sync program, a second representation of the queue that can
drift from the first, and a write path that no guard layer could reach at all.
Removing the Project removed all five.

Reviving it is cheap and additive if the reason ever arrives. The item files
are the source, so a board is a read of this directory plus one sync program,
with no change to the claim protocol, the authorization paragraph, or any item
file. The trigger to revive it is a second person needing to see the board.

## The one rule for anyone editing by hand

**A card that restates queue state is a defect, and the copy in the card is the
one that is wrong.**

Not "may be wrong" and not "should be checked". Wrong. If a sequence card says
a stream is done and the item file says `review`, the item file is the answer
and the card has a bug in it. Fix the card, or better, replace the sentence
with a generated block so that the next divergence fails the build instead of
waiting for a reader to catch it. `generated_blocks` in
[`config.yaml`](config.yaml) lists the blocks that already work this way.

The rule reads harshly on purpose. Every stale copy this design was written to
remove was written by somebody who knew the fact was true when they wrote it.
Correctness at the moment of writing is exactly what a restatement offers and
exactly what it cannot keep, so the only durable defence is to have one home
per fact and to treat any second answer as broken on sight.

Two facts are deliberately **not** queue state, and the same rule points the
other way for them. Membership of the ecosystem lives in the
[domain card](../knowledge/domains/salmon-data-ecosystem.md), whose ruled
allowlist governs; the member list in `config.yaml` is a machine-readable copy
and it is the copy that loses. Release versions and the parity window live in
the [roadmap](../knowledge/roadmap.md) release index. Do not add item files for
either.
