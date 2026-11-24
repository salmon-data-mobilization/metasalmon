# Review instructions

Read by the Claude review workflow (`.github/workflows/claude-code-review.yml`),
whose prompt tells the reviewer to follow this file. It holds what to flag and
how hard; `AGENTS.md` holds the contracts themselves. Keep this file short:
every review reads it, and a long one dilutes the rules that matter.

## What Important means here

Important is anything that should stop a merge:

- a bug: wrong output, a crash, a regression, or a test that passes for the
  wrong reason;
- a broken `AGENTS.md` contract, especially the non-negotiable ones: R and
  metasalmonpy diverging without a `knowledge/parity-deviations.md` row,
  an LLM or network call reachable without `llm_assess = TRUE`, a renamed or
  reordered frozen column, a semantic role missing one of its seven surfaces,
  locale-dependent ordering in anything hashed, written or returned, external
  text reaching a cli template unescaped;
- an ontology IRI chosen, changed or removed with no justification beyond
  validation passing;
- a guard, skip or allowlist entry that does not say what would retire it;
- a claim in a PR body, `NEWS.md` entry or `knowledge/` card that the diff
  shows is false, including a NEWS entry filed under a version it did not
  ship in;
- an observable behaviour change with no `NEWS.md` entry.

Everything else is a Nit at most: wording, naming, style, structure,
optional refactors, test-coverage wishes, and documentation that is merely
improvable rather than wrong.

## Verification bar

Post a finding only after checking it against the source. A behaviour claim
needs a `file:line` citation, not an inference from a name. R is not
installed on the runner, so do not report "I could not run it" as a finding.

## Stop when nothing important is left

Read the whole diff first. Then check only what could be Important. When
nothing Important remains to check, stop and post the summary. Do not go on
looking for nits.

## Cap the nits

Do not post nits as inline comments. List at most five in the summary, one
line each, and give the rest as a count.

## Do not report

- Generated pkgdown output under `docs/`, except a broken link or a page
  that is missing or contradicts its source.
- `queue/` card formatting, which CI validates (`hub-queue.yml`).
- Anything another CI job in `.github/workflows/` already enforces.

## Re-review rounds

A PR gets at most five review rounds. In round 2 or later, do not repeat a
finding an earlier round already raised unless the new head still has it and
the earlier comment is unresolved; then say so in one line in the summary.
New nits in a later round go in the summary count only.

## Summary shape

Open the summary with the reviewed head and a one-line tally, for example
`Head abc1234: 1 important, 3 nits`, or `Head abc1234: no blocking issues`
when everything is a nit or nothing was found.
