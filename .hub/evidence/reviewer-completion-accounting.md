# Reviewer completion accounting repair

Observed 2026-10-01. PR234 run36910687757 at043ee0779a posted a nits verdict,
then failed Verify review execution for denied gh pr checks. PR218
run36909400356 and PR242 run36910684703 had the same incomplete-marker
problem with four and two denials respectively. The old comment-only counter
would stop subsequent reviews at any last nits marker, regardless of validation.

The repaired counter preserves the existing five-marker budget, including
incomplete markers. Only a nits comment whose head, PR, comment time and run
match a successful Claude action AND successful completion guard suppresses
later rounds. A green skip cannot validate a comment. Missing/ambiguous public
metadata stops before model execution. No raw logs, execution artifacts or
new token permissions are used. GitHub documents public workflow/job metadata
as accessible without the Actions permission needed for private resources:
https://docs.github.com/en/rest/actions/workflow-jobs#list-jobs-for-a-workflow-run

Live read-only probes: PR234 => round2, skip=false; PR252 => round2, skip=true
from its genuinely completed nits-only review. PR243 => round2, skip=false;
its green skipped job is not completion evidence. These probes did not invoke
models or post comments. Nine offline accounting regressions and the five
existing completion regressions pass; actionlint1.7.12 passes.

The prompt prohibits CI checks, external website reads, interpreters and
compound shell commands; source inspection uses existing tools. Broad
interpreter, generic gh api/search and command-runner grants are removed.
Publication remains limited to existing summary and inline review channels.
The completion guard still rejects every denied tool call. OAuth subscription
model and effort, GitHub permissions, event triggers, round cap and concurrency
are unchanged. No manual model reruns, credential operations or settings changes.
This is CI/reviewer behavior, with no R/Python package behavior or parity port.

Bootstrap limitation: PR249 run36880102606 shows the Claude OIDC app integration
requires workflow content identical to default branch. A PR modifying this
workflow therefore cannot establish a completed review under its new config
before the reviewed workflow lands. Keep the default-branch validation intact;
do not bypass it with supplied tokens, new permissions or pull_request_target.
The draft must be independently inspected and integrated by an authorized
maintainer before a later ordinary PR event can prove genuine model completion.
A validation skip, green skip or local test is not that proof.

Source runs:
- https://github.com/salmon-data-mobilization/metasalmon/actions/runs/36910687757
- https://github.com/salmon-data-mobilization/metasalmon/actions/runs/36909400356
- https://github.com/salmon-data-mobilization/metasalmon/actions/runs/36910684703
- https://github.com/salmon-data-mobilization/metasalmon/actions/runs/36880102606
