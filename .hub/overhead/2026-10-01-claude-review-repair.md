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
