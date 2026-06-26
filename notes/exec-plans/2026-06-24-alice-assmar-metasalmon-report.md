# Alice Assmar metasalmon report triage and fix

## Closure (2026-06-26) — CLOSED, superseded

**Status: closed.** The core objective shipped: GitHub issue #1 was filed and the
`llm_context_files` fix landed in **metasalmon 0.1.4** (see `NEWS.md`). This plan
is retained as a historical record and was **moved from `docs/plans/` to
`notes/exec-plans/`** (it was untracked and sitting in the pkgdown output folder).

Disposition of the four remaining Progress items (37–40), so no work is lost:

- *Investigate/fix obvious adjacent bugs* → **carried forward and largely done.**
  The adjacent-bug hunt continued on the `deepen-architecture` branch and through a
  `/code-review` pass; every finding is tracked in
  `notes/bugs-and-improvements.md` (31 items, with implementation status).
- *Peer-review checkpoint F (schema/metadata semantics)* → **superseded.** The
  schema/metadata-touching work on `deepen-architecture` was reviewed via the
  `/code-review` process; the full `testthat` suite is green (1281 pass / 0 fail).
- *Peer-review checkpoint G (pre-PR/docs)* → **partly done; PR still pending.**
  Docs were regenerated (`devtools::document()` + a lazy pkgdown rebuild). The
  open piece is opening the PR for `deepen-architecture` and an `R CMD check` —
  tracked as the "Process / handoff" items in
  `notes/exec-plans/2026-06-26-next-behaviours-roadmap.md`.
- *Final validation + PR-ready summary* → **carried forward** to the same roadmap
  (`R CMD check` + PR handoff).

Everything beyond the original #1 fix — the architecture deepening and the new
review behaviours — lives in
`notes/exec-plans/2026-06-24-deepen-architecture-refactors.md` (executed) and
`notes/exec-plans/2026-06-26-next-behaviours-roadmap.md` (what's next).

## Purpose / Big Picture

This plan turns Alice Assmar's report about the `metasalmon` R package into a traceable GitHub issue, creates an issue branch from `main`, reproduces the reported behavior, fixes it with tests, and catches obvious adjacent bugs without broad refactoring.

The visible outcome is a GitHub issue in `salmon-data-mobilization/metasalmon`, a branch named from that issue, and a tested patch that can become a pull request. A user should be able to verify the fix by running the focused test command and, before merge, the broader package check.

Two inputs affect the external issue and branch steps:

- The actual Alice Assmar report text or artifact has not been found in the prompt, repository, local Salmon memory, Gmail search, or Google Drive search.
- The local worktree on `main` already has many modified files. These look like pre-existing URL-migration changes and must not be overwritten or hidden by this work. The default implementation path is a separate clean git worktree from verified `origin/main`.

## Progress

- [x] 2026-06-24: Loaded global Agent OS, COO, Salmon Work Wiki, ExecPlan, GitHub workflow, Gmail, Drive, and testing guidance relevant to this task.
- [x] 2026-06-24: Verified GitHub authentication and repository identity: `salmon-data-mobilization/metasalmon`, default branch `main`.
- [x] 2026-06-24: Checked existing GitHub issues; no existing issues were listed.
- [x] 2026-06-24: Checked GitHub Projects for `salmon-data-mobilization`; no org project was listed.
- [x] 2026-06-24: Searched repository, Salmon memory/wiki, Gmail, and Drive for `Alice Assmar`, `Assmar`, `metasalmon report`, and `metasmn report`; no report was located.
- [x] 2026-06-24: Confirmed the local worktree is dirty on `main` with many modified source, documentation, generated docs, schema, and test files.
- [x] 2026-06-24: Ran focused tests for current URL/version/schema/GitHub touched areas: `devtools::test(filter = "version-check")`, `devtools::test(filter = "schema-helpers")`, and `devtools::test(filter = "github-helpers")`; all passed.
- [x] 2026-06-24: Ran full testthat baseline on the current dirty tree with `Rscript -e 'devtools::test()'`; result was 0 failures, 29 warnings, 2 skips, 1198 passes.
- [x] 2026-06-24: Spawned sub-agents A/B/C for investigation and D for plan review.
- [x] 2026-06-24: Received plan-review findings and git-hygiene findings; incorporated them into this plan.
- [x] 2026-06-24: Received Alice's report from Brett in-thread.
- [x] 2026-06-24: Created GitHub issue #1: `Fix: make create_sdp llm_context_files behavior explicit and testable`.
- [x] 2026-06-24: Created separate clean worktree `/Users/brettjohnson/code/metasalmon-issue-1-llm-context-files` on `feature/1-llm-context-files` from verified `origin/main`.
- [x] 2026-06-24: Commented the working branch on issue #1.
- [x] 2026-06-24: Completed investigation checkpoint A/B/C before writing the failing reproduction.
- [x] 2026-06-24: Completed plan-review checkpoint D after the issue body was concrete and before code edits.
- [x] 2026-06-24: Reproduced the reported behavior with focused `create_sdp()` tests for parsed `llm_context_files` and path context supplied without `llm_assess = TRUE`.
- [x] 2026-06-24: Implemented the smallest fix: validate `llm_context_files` as local file-path strings, warn when LLM context is supplied without `llm_assess = TRUE`, and document the contract.
- [x] 2026-06-24: Ran focused validation: `testthat::test_file("tests/testthat/test-package-helpers.R")` and `testthat::test_file("tests/testthat/test-llm-semantic-helpers.R")`; both passed with only pre-existing warnings/skips.
- [x] 2026-06-24: Ran broader validation: `devtools::test(reporter = "summary")`; passed with 29 warnings and 2 skips, consistent with the baseline warning/skip profile.
- [x] 2026-06-24: Completed peer-review checkpoint E; reviewer found no blocking or non-blocking issues and independently verified no hidden LLM call when `llm_assess = FALSE`.
- [x] 2026-06-26: Adjacent-bug investigation carried forward to the
  `deepen-architecture` branch + `/code-review`; tracked in
  `notes/bugs-and-improvements.md`. (See Closure.)
- [x] 2026-06-26: Checkpoint F superseded by the `/code-review` process on
  `deepen-architecture`; full suite green. (See Closure.)
- [~] Checkpoint G partly done (docs regenerated); PR + `R CMD check` still
  pending — carried to `notes/exec-plans/2026-06-26-next-behaviours-roadmap.md`.
- [~] Final validation + PR-ready summary carried to the same roadmap.

## Surprises & Discoveries

- The local remote URL is `https://github.com/salmon-data-mobilization/metasmn.git`, but `gh repo view` resolves the current GitHub repository as `salmon-data-mobilization/metasalmon`. Treat `salmon-data-mobilization/metasalmon` as the GitHub API repository and verify push behavior before opening a PR.
- The repo has many pre-existing modifications on `main` across R source, generated pkgdown docs, schemas, tests, README, and vignettes. Any branch operation must preserve those changes.
- No GitHub Project board exists for the org according to `gh project list --owner salmon-data-mobilization --format json`. The GitHub workflow skill prefers a repo project board, so this may need a follow-up decision.
- The configured remote URL is `https://github.com/salmon-data-mobilization/metasmn.git`, while GitHub canonicalizes both `salmon-data-mobilization/metasmn` and `salmon-data-mobilization/metasalmon` to `salmon-data-mobilization/metasalmon`. `origin/main`, `main`, and `HEAD` currently point at `2361b704cae800eaa39aac712c04b010a6eef1db`.
- The current dirty tree passes the full testthat suite despite 29 expected or environmental warnings and 2 skips.
- `scripts/install_deps.sh` currently fails when `CLAUDE_CODE_REMOTE` is unset under `set -u`; treat that as an adjacent bug candidate only if Alice's report touches setup or dependency-install workflows.
- Alice's example explains two separate user-visible traps: `llm_context_files` was a parsed tibble/XML/Rmd object instead of a character file path, and `llm_assess` was omitted, so the context could not affect LLM review. The fix should make both traps explicit without silently enabling network/API use.

## Decision Log

- 2026-06-24: Use `main` as the default base branch because GitHub reports `main` as the repository default branch.
- 2026-06-24: Do not create the issue with a placeholder report. The issue should preserve Alice's concrete report, reproduction notes, expected behavior, and any environment details.
- 2026-06-24: Use a separate clean git worktree from verified `origin/main` for Alice's issue branch. This avoids stashing, committing, or proceeding on top of the current dirty URL-migration work.
- 2026-06-24: Keep adjacent bug fixes narrow. "Obvious bugs" means directly observed failures, small invariant violations, or clearly broken behavior in the same workflow, not opportunistic refactors.
- 2026-06-24: Treat `salmon-data-mobilization/metasalmon` as the GitHub issue/PR repository and verify that the worktree remote canonicalizes before pushing.
- 2026-06-24: Do not auto-enable `llm_assess` when context files/text are supplied. That would hide network/API/cost behavior behind an argument that users may reasonably expect to be inert unless LLM review is explicitly enabled.

## Outcomes & Retrospective

- GitHub issue: <https://github.com/salmon-data-mobilization/metasalmon/issues/1>
- Branch/worktree: `feature/1-llm-context-files` in `/Users/brettjohnson/code/metasalmon-issue-1-llm-context-files`
- Reproduction summary: Alice's command passed a parsed dictionary object to `llm_context_files` and omitted `llm_assess = TRUE`; the package accepted the object too late and otherwise ignored context during deterministic-only semantic seeding.
- Fix summary: `llm_context_files` is now validated as a character vector of local file paths, valid context paths/text warn when supplied without `llm_assess = TRUE`, and public docs clarify that context affects only explicit LLM review.
- Files changed: `R/llm-semantic-helpers.R`, `R/semantics-helpers.R`, `R/package-helpers.R`, `R/dictionary-helpers.R`, generated `man/*.Rd`, and tests in `test-package-helpers.R` and `test-llm-semantic-helpers.R`.
- Validation: focused package-helper tests passed; focused LLM-helper tests passed; `devtools::test(reporter = "summary")` passed with 29 warnings and 2 skips matching the baseline profile; `git diff --check` passed.
- Peer review: checkpoint E found no blocking or non-blocking findings and verified that `llm_context_files` plus `llm_assess = FALSE` does not call the LLM request function.

## Context and Orientation

`metasalmon` is an R package for creating, validating, and exporting Salmon Data Packages. A Salmon Data Package is a folder containing data files plus canonical CSV metadata such as `dataset.csv`, `tables.csv`, `column_dictionary.csv`, and `codes.csv`.

Important local paths:

- `/Users/brettjohnson/code/metasalmon/R/`: package source files.
- `/Users/brettjohnson/code/metasalmon/tests/testthat/`: unit tests.
- `/Users/brettjohnson/code/metasalmon/inst/extdata/`: bundled schemas, example data, and templates.
- `/Users/brettjohnson/code/metasalmon/vignettes/`: source vignettes.
- `/Users/brettjohnson/code/metasalmon/docs/`: generated pkgdown site. (This plan
  was moved to `/Users/brettjohnson/code/metasalmon/notes/exec-plans/` on
  2026-06-26; see the Closure section.)
- `/Users/brettjohnson/code/metasalmon/DESCRIPTION`: package metadata and dependencies.
- `/Users/brettjohnson/code/metasalmon/README.md`: user-facing quickstart and workflow guidance.

Potentially relevant source areas will be chosen from Alice's report. Common fault zones in this package include:

- package creation and validation: `R/package-helpers.R`, `R/schema-helpers.R`, `R/validation_helpers.R`
- dictionary inference and semantics: `R/dictionary-helpers.R`, `R/semantic-suggestions.R`, `R/llm-semantic-helpers.R`
- GitHub helpers: `R/github-helpers.R`, `R/version-check.R`
- EDH XML export: `R/edh-xml-export.R`

## Sub-Agent Plan and Checkpoints

Use sub-agents only for narrow, non-overlapping work. Every coding sub-agent must be told that other work may be happening in the codebase, that they must not revert existing edits, and that their write scope is limited.

Investigation checkpoint:

- Investigator A, R-package surface: map functions, tests, and vignettes likely related to Alice's report once the report is available.
- Investigator B, validation/runtime: run or inspect the smallest commands that expose likely failures and identify current test health.
- Investigator C, worktree/GitHub hygiene: inspect dirty changes and branch/remote state, then recommend a low-risk branch strategy.

Gate: A/B/C findings must be reviewed before choosing the reproduction test file.

Plan-review checkpoint:

- Reviewer D, implementation plan: review this ExecPlan after Alice's report is added and before code edits begin. Focus on missing reproduction steps, hidden assumptions, test adequacy, and scope control.

Gate: D findings must be addressed or logged before code edits.

Implementation peer-review checkpoints:

- Peer Reviewer E, R package API and tidyverse style: after the first fix compiles and focused tests pass.
- Peer Reviewer F, Salmon Data Package semantics: after metadata/schema behavior changes, before final validation.
- Peer Reviewer G, release/docs risk: after final code changes, before opening a PR or updating generated docs.

Gate: E is required for any code fix. F is required if `metadata/*.csv`, schemas, validation, dictionary semantics, or SDP export behavior changes. G is required before PR handoff or generated-documentation updates.

## Plan of Work

1. Fill in the report section.
   - Paste or fetch Alice's report.
   - Extract reported steps, inputs, observed behavior, expected behavior, environment, and severity.
   - Record unknowns plainly.

2. Resolve branch safety.
   - Verify `origin/main`, GitHub default branch, and canonical repository name before branching.
   - Use a separate git worktree from `origin/main` and do the issue branch there.
   - Do not change, stash, commit, or revert the dirty work in `/Users/brettjohnson/code/metasalmon`.

3. Create GitHub issue.
   - Title format: `Fix: <short observed failure>`.
   - Body sections: `Summary`, `Report`, `Reproduction`, `Expected behavior`, `Tasks`, `Notes`.
   - Include Alice's report content as a concise paraphrase unless Brett wants exact wording.
   - If the issue branch is not created with `gh issue develop`, comment the branch name on the issue after branch creation.

4. Create issue branch.
   - Branch from `main`.
   - Branch format: `feature/<issue-number>-<short-slug>` unless Brett chooses a different prefix.
   - Prefer `gh issue develop <issue-number> --checkout --branch feature/<issue-number>-<short-slug>` inside the separate worktree if it works with the repo's remote state; otherwise use `git worktree add -b ... origin/main` and comment the branch on the issue.

5. Reproduce.
   - Add a focused failing test in `tests/testthat/` or a temporary reproduction script if a test cannot be written first.
   - Prefer `withr::local_tempdir()` and bundled test fixtures over writing persistent test artifacts.
   - Gate: review A/B/C findings before choosing the reproduction location.

6. Fix.
   - Make the smallest source change that satisfies the failing test.
   - Keep generated documentation out of the first fix unless user-facing docs or Rd files must change.
   - Preserve the repo's existing tidyverse/native-pipe style and heavily document R code inline when the logic is non-obvious.

7. Verify.
   - Run the focused test file first.
   - Run a broader test suite if the fix touches shared helpers.
   - Run package check before PR if time and dependencies allow.
   - If exported APIs, roxygen comments, `NAMESPACE`, Rd files, README, schemas, or vignettes change, run `devtools::document()` or explicitly log why generated docs are intentionally excluded.

8. Adjacent-bug inspection.
   - Inspect only the same workflow and directly touched helper boundaries for obvious adjacent bugs.
   - Fix adjacent bugs only when each has a failing test, static proof, or clear before/after reproduction command.
   - Log deferred adjacent issues as follow-up issue candidates rather than expanding the patch indefinitely.

9. Peer review.
   - Ask the relevant sub-agent reviewer to inspect the diff and test evidence at the required gates.
   - Address concrete findings or log why they are deferred.

10. Prepare PR handoff.
   - Summarize reproduction, fix, tests, and remaining risk.
   - Link `Closes #<issue-number>` in PR body.

## Concrete Steps

Run all commands from `/Users/brettjohnson/code/metasalmon` unless a separate worktree is chosen.

Initial state checks:

```sh
git status --short --branch
git remote -v
git ls-remote --symref origin HEAD
gh repo view --json nameWithOwner,defaultBranchRef,url
gh issue list --repo salmon-data-mobilization/metasalmon --state all --limit 100
```

Create issue after the report is available:

```sh
gh issue create \
  --repo salmon-data-mobilization/metasalmon \
  --title "Fix: <short observed failure>" \
  --body-file /tmp/metasalmon-issue-body.md
```

Then create the branch in a separate worktree, replacing `<issue-number>` and `<short-slug>`:

```sh
git fetch origin
git worktree add -b feature/<issue-number>-<short-slug> ../metasalmon-issue-<issue-number>-<short-slug> origin/main
cd ../metasalmon-issue-<issue-number>-<short-slug>
git status --short --branch
gh issue comment <issue-number> --repo salmon-data-mobilization/metasalmon --body "Working branch: `feature/<issue-number>-<short-slug>`"
```

Alternative if `gh issue develop` works cleanly in a separate worktree:

```sh
git worktree add ../metasalmon-issue-<issue-number>-<short-slug> origin/main
cd ../metasalmon-issue-<issue-number>-<short-slug>
gh issue develop <issue-number> --checkout --branch feature/<issue-number>-<short-slug> --repo salmon-data-mobilization/metasalmon
```

Focused tests, replacing `<test-file>` with the relevant file:

```sh
Rscript -e 'devtools::load_all(); testthat::test_file("tests/testthat/<test-file>.R")'
```

Broader test suite:

```sh
Rscript -e 'devtools::test()'
```

Package check:

```sh
Rscript -e 'rcmdcheck::rcmdcheck(args = "--no-manual", error_on = "warning")'
```

If `devtools` or `rcmdcheck` is unavailable, use:

```sh
R CMD build .
R CMD check --no-manual metasalmon_*.tar.gz
```

Documentation validation when public API docs or generated docs are in scope:

```sh
Rscript -e 'devtools::document()'
git diff --check
```

## Validation and Acceptance

Acceptance requires:

- A GitHub issue exists and accurately captures Alice's report.
- A branch exists from the agreed base branch.
- The issue thread records the working branch or the branch is created through `gh issue develop`.
- The reported behavior is reproduced by a focused failing test or documented reproduction command.
- The fix passes the focused test.
- Any adjacent bug fix is backed by its own test or a clear before/after command.
- The broader package test suite passes, or any unrelated pre-existing failures are documented with evidence.
- Required sub-agent gates have run and findings are addressed or logged.
- The plan's Progress, Surprises & Discoveries, Decision Log, and Outcomes & Retrospective sections are current.

Expected test evidence should include command names and pass/fail summaries, not only "tests passed."

## Idempotence and Recovery

- Searching for the report is read-only and can be repeated safely.
- Creating the GitHub issue is not idempotent. Before creating it, run `gh issue list` and search for the title to avoid duplicates.
- Creating a branch is idempotent only if the branch name does not exist. Before creating it, run `git branch --list '<branch>'` and `gh api repos/salmon-data-mobilization/metasalmon/branches/<branch>` if needed.
- Use a separate git worktree to avoid disturbing the current dirty `main` worktree.
- If a test writes files, use temp directories and clean them through `withr`.
- If a change proves wrong, revert only the files changed for this issue branch. Never revert pre-existing dirty changes from the original worktree.
