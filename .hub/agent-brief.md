# Dispatch brief for a hub agent

This file is what an orchestrator hands a dispatched agent instead of writing a
fresh brief each time. It is **git-tracked and lives beside `HUB.md` on
purpose**, so that a change to the rules and a change to the brief are the same
review.

## It restates no rule, and that is the whole design

`HUB.md` is the single policy copy. **This brief points at it and never
summarises it.** Anything shaped like a permission, a prohibition, a path, a
constant or a branch pattern is in `HUB.md` or `queue/config.yaml`, and you read
it there.

That rule is not tidiness. Until 2026-09-16 the brief lived outside the
repository and carried its own copy of the never-list, including *"never reply to
a review comment."* On 2026-09-16 ruling **R16** granted exactly that reply for a
delegated pull request and `HUB.md` was amended the same day — and the brief,
being a separate copy in a scratch directory, was not. A dispatched agent read
the stale copy, correctly refused the work it had been sent to do, and wrote its
replies to a text file instead. It was right to obey what it had been given; the
copy was the defect. A brief that restates the register is a second authority
that will disagree with the first exactly when the first has just changed, which
is the moment the disagreement costs the most.

So: if you are about to write a rule into this file, put it in `HUB.md` and link
it from here.

## Read these first, in this order

1. **`HUB.md`**, in full. It is the authority: the claim protocol, the writes
   register, what a pull request needs from Brett and what it does not, the
   worktree rules, and every never. Where this brief and `HUB.md` disagree,
   `HUB.md` wins and you say so in your report.
2. **`AGENTS.md`**, for the project contracts your change has to survive — the
   mirror contract, the seven surfaces of a semantic role, C collation, one
   value one rendering, `.ms_cli_escape()` on external text, and that every
   guard states what retires it.
3. **`queue/README.md`**, before you touch anything under `queue/`.
4. **`queue/config.yaml`**, for every operating constant. Never take a constant
   from prose.

## Your identity

Export a session key unique to you **before any `hub` command**, so the
per-identity concurrency cap applies to you alone and not to the whole fleet:

```sh
export HUB_SESSION_KEY="<fleet-date>-<YOUR-ITEM-ID>"
```

It does not persist between shell invocations. Set it in every shell you use.

## The shape of a run

Claim, isolate, heartbeat, work in scope, verify, report, hand back. `HUB.md`
carries each step and its conditions; `./scripts/hub` enforces what it can and
exits non-zero rather than guessing. **If `hub` refuses something, read the
refusal — it names the rule.** Do not work around it.

Two things worth knowing before you start, because both are easy to get wrong
and neither is obvious from a single step:

- **Your report goes to `.hub/workpads/<queue-id>.md`** — one file per item,
  named for the item. If you ever find yourself resolving a conflict *inside* a
  workpad, stop: two items are writing to one name, and the name is the bug.
- **A pull request with a merge conflict gets no CI at all**, not red CI. Its
  head shows an empty check list, which reads like "nothing failed". Merge the
  base branch in and resolve it; that is both the fix and the thing that starts
  the checks.

## Scope

Stay inside the item's `retires_when`. Anything you find that belongs to another
item: **name it by queue id in your report** so it can be promoted, and do not
absorb it. Anything you find that has no item: describe it as a candidate new
item, with evidence. For a defect, capture **failing-before and passing-after** —
a fix with no reproduction of the original failure is not finished.

## You may spawn your own subagents

Delegate broad reads and independent slices; the core R files run to thousands of
lines and should not be read whole in your context. Pass them this file's path.
They inherit everything in `HUB.md`, including every never. You remain the one
accountable for the claim, the heartbeat and the hand-back.

## What to report back to the orchestrator

Short and load-bearing, in this order: whether you got the claim (if not, stop
there); what you changed, in one paragraph; the pull request URL, or — in a
shared member repository — the worktree path where the diff is waiting; test
evidence, the before and the after, with the actual command output; anything
needing Brett, stated as a question with your recommendation; and anything you
found that is not your item, by id or as a new-item candidate with evidence.

**"Needing Brett" means a decision that is his, not a mechanic that was hard.**
A conflict you resolved, a check that went green, a re-run you waited out: those
belong in the workpad and the pull request body, which persist and are
searchable. What reaches him is an ontology term, a public signature or frozen
contract, a version or release, a specification change, anything outward-facing,
a parity-register row, the weakening of a guard, `HUB.md` itself — or a design or
user-experience question you cannot settle from the repository. `HUB.md`'s
"Which pull requests need Brett" is the list; this is the same boundary applied
to your report.

Do not pad it. Several of these are read at once.
