# Make review execution visible

Brett authorized iterative review and fixes plus routine draft publication in
this continuous run. This directly requested workflow maintenance allocates
no new work-item number and changes no claim or merge authority.

## Evidence and changes

PR 215's draft and ready Claude jobs completed green with no review comments.
Their sanitized logs reported two and three denied tool calls respectively.
The upstream code-review command skips draft PRs and any PR already containing
a Claude comment (Anthropic source checked 2026-10-01). Its read/comment shell
tools were absent from the workflow's explicit allowlist.

Replace that command with a direct review prompt for drafts and each exact
head, retaining Brett's chosen model and effort. Allow only repository reads
and PR review comments. Cancel superseded runs. Check the SDK completion file
for success, denied tools and an exact final head marker; publish none of its
messages or tool output. Missing or incomplete execution fails visibly.

Sources: [plugin command](https://github.com/anthropics/claude-code/blob/main/plugins/code-review/commands/code-review.md),
[action output contract](https://github.com/anthropics/claude-code-action/blob/main/action.yml),
[execution-file writer](https://github.com/anthropics/claude-code-action/blob/main/base-action/src/execution-file.ts),
[SDK sanitizer](https://github.com/anthropics/claude-code-action/blob/main/base-action/src/run-claude-sdk.ts).

## Verification

Offline paired tests accept a completed exact-head review and reject denied
tools, skipped drafts, older or partial head markers, SDK failure, no result
and ambiguous results. Actionlint validates the workflow. No package runtime
or ontology term change; Python parity does not apply. Remote execution still
must demonstrate a real review on the published head.

## Retirement and limits

The completion check retires when the action itself rejects denied tools and
exposes a checked head result. A model's completion marker is evidence of its
reported execution, not proof that its semantic judgement is correct; findings
still require comparison against source and Brett's decisions. This PR remains
draft for review of the workflow change.

## Independent review correction

The initial completion fixture could pass with only a final marker and no
tool calls. An independent reviewer reproduced that weakness. The check now
requires successful SDK tool results for `gh pr view`, `gh pr diff`, and a PR
comment (shell or inline tool); offline tests reject each missing operation.
These events demonstrate execution, while review quality still requires
comparison against source.

Remote run 36818758378 failed because Anthropic’s workflow validation refuses
changed workflow content until it matches the default branch. The SDK never
ran and supplied no execution file. No bypass was added; Brett was asked for
a one-time merge decision after the other checks and independent review.

## Review rounds, REVIEW.md and local dry runs

Brett ruled on 2026-10-01: drafts are reviewed, the Bash allowlist widens to
read-only shell tools, and each PR gets at most five review rounds, with no
further round after one that finds only nits. A per-run `--max-turns 5` was
measured first and rejected: the run stopped at `error_max_turns` after reading
only the PR and diff (21 s, $0.41, no finding). The round limit is counted from
a verdict marker in Claude's own summary comment, so it needs no state outside
the PR. What counts as Important lives in a root `REVIEW.md`, which the prompt
tells the reviewer to read; claude-code-action does not load that file by
itself (only Anthropic's managed Code Review does), and keeping review rules
out of `CLAUDE.md` keeps them out of every other agent session. `REVIEW.md` is
listed in `internal_sources` so the site build does not publish it.

The prompt and tools were exercised locally with `claude -p` at the
workflow's model and effort, against real PR heads, with the comment tools
removed so nothing was posted. A local run is evidence about the prompt and
allowlist, not about the action, which still has to run on `main`.

| PR | Prompt | Turns | Cost | Denials | Verdict |
|---|---|---|---|---|---|
| 246 (draft) | upstream plugin, on CI | 3 | $0.52 | 0 | skipped as draft |
| 247 | upstream plugin, on CI | 14 | $3.28 | 41 | nothing posted |
| 246 (draft) | direct prompt, read-only git | 32 | $4.26 | 5 | 4 findings |
| 247 | direct prompt, read-only git | 34 | $2.61 | 6 | 1 finding |
| 246 (draft) | with REVIEW.md | 43 | $4.45 | 2 | important |
| 247 | with REVIEW.md | 45 | $2.73 | 4 | important |
| 228 | with REVIEW.md | 37 | $2.55 | 4 | important |
| 242 | with REVIEW.md | 33 | $2.90 | 2 | important |

No sampled PR came out nits-only, so the early stop has not yet been observed
to fire. Most remaining denials were reads of metasalmonpy through `gh api`;
its default branch is now checked out read-only at `.review/metasalmonpy`.
Every run still had at least one denial, and the completion check fails the
job on any denial. Brett ruled the same day to keep that check and widen the
allowlist instead: `python3`, `perl`, `awk`, `find`, `xargs`, `mkdir`,
`git -C`, `gh api` and `gh search` were added, which covers every command
denied in the eight runs above except shell constructs (`cd`, `for`, `$(...)`)
that the prompt already asks the reviewer to avoid. The allowlist is no longer
read-only. What bounds it is that only same-repository pull requests, whose
authors already have write access, receive the token, and the prompt's rule
against edits, pushes, merges and labels.
