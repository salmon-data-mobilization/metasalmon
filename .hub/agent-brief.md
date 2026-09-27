# Dispatch brief for a hub agent

This is what an orchestrator hands a dispatched agent instead of writing a fresh
brief each time. It is **git-tracked and lives beside `HUB.md` on purpose**, so
that a change to the rules and a change to the brief are the same review.

## It is an index, not a summary

`HUB.md` is the single policy copy. **Every rule below is a pointer into it.**
Nothing here restates a permission, a prohibition, a path, a constant or a branch
pattern — those change, and a copy of one is a second authority that will
disagree with the first exactly when the first has just changed.

That is not tidiness. Until 2026-09-16 this brief lived outside the repository
and carried its own copy of the never-list, including *"never reply to a review
comment."* Ruling **R16** granted exactly that reply and `HUB.md` was amended the
same day; the copy was not. A dispatched agent read the stale copy, correctly
refused the work it had been sent to do, and wrote its output to a text file
instead. **The agent was right to obey what it was handed; the copy was the
defect.**

The first draft of *this file* then did the same thing — it restated the workpad
path and a CI remedy inside the very section forbidding restatement — and review
caught it. So the rule needs saying twice: **if you are about to write a rule
into this file, put it in `HUB.md` and link it from here.**

**An index has its own failure mode, and this file shipped with one.** The table
below pointed at `queue/config.yaml` for the session key, which is where the old
scratch brief said it lived and where it is not; it is documented by
`./scripts/hub help`. A pointer that no longer resolves is quieter than a stale
copy — nothing contradicts anything, the reader simply finds nothing and guesses.
So when you add a row, **open the target and confirm the thing is there**, and
prefer pointing at a section heading or a named key over a file, because those
fail loudly when they move.

## Read, in this order

1. **[`HUB.md`](../HUB.md)** — in full, before you write anything. The claim
   protocol, the writes register, reporting, isolation and worktrees, which pull
   requests need Brett and which do not, and every never. **Where this brief and
   `HUB.md` disagree, `HUB.md` wins and you say so in your report.**
2. **[`AGENTS.md`](../AGENTS.md)** — the project contracts your change has to
   survive, and the non-negotiable ones are listed there under that heading.
3. **[`queue/README.md`](../queue/README.md)** — before touching anything under
   `queue/`.
4. **[`queue/config.yaml`](../queue/config.yaml)** — every operating constant,
   each with its own calibration note. Never take a constant from prose,
   including from here.

## Where to find the rest

| what you need | where it is |
|---|---|
| running several agents at once without tripping the concurrency cap | the cap is `max_concurrent_claims` in `queue/config.yaml`; it applies per agent identity, and the identity is set by `HUB_SESSION_KEY`, documented by `./scripts/hub help` |
| claiming, and what a rejected claim push means | `HUB.md` § *Claiming* |
| which worktree to work in, and when one may be removed | `HUB.md` § *Isolation* |
| which checkout to run `hub` from, what a "STALE CHECKOUT" refusal means, and the check an orchestrator runs on a checkout before a brief names it | `HUB.md` § *Which checkout the queue is read from* |
| where your report goes and what it must carry | `HUB.md` § *Reporting* |
| pushing, opening a pull request, and whether it stays a draft | `HUB.md` § *Hand back* |
| what you may merge, answer or mark ready, and on what conditions | `HUB.md` § *Which pull requests need Brett* |
| what reaches Brett rather than the record | same section, under *Delegation is recorded* |
| every prohibition | `HUB.md` § *What you must never do* — the only copy |

`./scripts/hub` enforces what it can and exits non-zero rather than guessing. **A
refusal names the rule it is enforcing: read it rather than working around it.**

## Scope, which is yours to hold

Stay inside the item's `retires_when`. Anything you find that belongs to another
item, name by queue id in your report and do **not** absorb. Anything with no
item, describe as a candidate, with evidence. For a defect, capture
failing-before and passing-after — the standard `HUB.md` § *Reporting* sets.

## You may spawn your own subagents

Delegate broad reads and independent slices; the core R files run to thousands of
lines. Pass them this file's path. They inherit everything `HUB.md` says,
including every never. You remain accountable for the claim, the heartbeat and
the hand-back.

## Reporting back to the orchestrator

Short and load-bearing: whether you got the claim (if not, stop there); what you
changed, in a paragraph; the pull request URL, or the worktree path where the
diff waits; test evidence, before and after, with real command output; anything
needing Brett, as a question with your recommendation; anything that is not your
item, by id or as a candidate.

**"Needing Brett" means a decision that is his, not a mechanic that was hard.** A
conflict you resolved or a check that went green belongs in the workpad and the
pull request body, which persist and are searchable. The classes that reach him
are in `HUB.md` § *Which pull requests need Brett*, plus any design or
user-experience question you cannot settle from the repository.

Do not pad it. Several of these are read at once.
