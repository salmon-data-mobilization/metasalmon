# Small workflow improvements and the next-run measurement

Requested by Brett in chat on 2026-09-30, following the
[B-120 overhead audit](../workpads/B-120.md#workflow-overhead-audit).
This log records the experiment; `queue/` and the live claim refs still own
work-item state. Times below are UTC, including intervals after midnight on
2026-10-01. They are coarse observed working intervals, not a profiler.

## Changes being evaluated

1. `scripts/hub status ID` reads the current queue fields and live claim tip in
   one call. It reports the raw action rather than repeating eligibility logic.
   An unreadable claim is `unknown`, with a failing exit, never `absent`.
2. A successful or idempotent `hub claim` prints the existing work branch,
   workpad location and shell-quoted setup hints. The target member checkout and
   fetched base remain explicit inputs. The client creates no checkout or report.
3. `queue/README.md` has a short operational entrypoint linking to the existing
   authority files. No approval rule, claim protocol or planning store changes.

This is directly authorized maintenance, without allocating a new backlog ID.
These changes affect the ecosystem's operational client, not R package
behaviour; there is no Python package capability to mirror or parity difference
to register. No ontology term is selected or changed.

## Evidence

- The existing local-Git harness gained two checks: status at absent, released,
  handed-off and reclaimed tips (including failed lookup, seven malformed
  records and a resolved dependency retained in the raw queue field), and
  fresh/idempotent setup hints with shell-sensitive checkout paths. Remote
  refs, checkouts and workpads are checked for unintended writes.
- Against the baseline client the two new checks fail. The harness also detects
  a concurrent edit to the checkout under test, as intended.
- With the edited files frozen, `bash scripts/tests/test_hub_claim.sh` passes
  **43 checks, zero failures and zero skips**. `bash -n` on both scripts,
  `git diff --check`, queue validation and the existing OKF capture check pass.
- Live `hub status B-99` reports its queue fields and an absent claim. This is
  a read, not a claim or permission to implement it.
- The independent read found two defects before publication: a raw dependency
  label was showing filtered dependencies, and a fetched but unreadable record
  could report success. Both have regression coverage. A subsequent run caught
  a validation mistake that treated the stored ISO lease as numeric; status
  now uses the client's existing ISO parser.
- `Rscript scripts/build-pkgdown.R` passes using B-120's cached pinned Pandoc
  3.8.3. Only the new NEWS fragment and its search entry are retained. The build
  regenerated unrelated pre-existing pages; those are restored. The rebuilt
  search index changes exactly one entry, the development Internal section.

## Investment and friction observed during this change

| Interval | Activity | Attribution limit |
| --- | --- | --- |
| 02:53:10–03:00:02 | Recover current state, archive merged B-120 worktree, isolate helpers, investigate expired GitHub authentication | Mixed startup and environment repair; not a hub-bureaucracy percentage |
| 03:00:02–03:03:02 | Implement helpers and short entrypoint | Improvement investment, charged separately from B-99 |
| 03:03:02–03:12:09 | Verify and correct test expectations | Includes two avoidable noisy runs; exact rework duration was not isolated |
| 03:12:09–03:18:09 | Save this audit, build and curate NEWS, independent review and corrections | Mixed documentation, review and implementation investment |
| 03:18:09–03:19:08 | Verification finds the stored-lease validation mistake | Implementation defect, not claim bureaucracy |
| 03:19:08–03:20:31 | Inspect the stored date format and reuse the existing parser | Corrective implementation |
| 03:20:31–03:21:38 | Final frozen harness run | 43 passed; right-sized verification, not waste |

Two concrete avoidable costs occurred: running a test file while another agent
was editing it, and expecting an old fixture's action to remain `claim` after
earlier checks changed it to `reclaim`. Files are now frozen before a suite
starts. This is an execution adjustment, with no additional approval or tracker.

The saved GitHub CLI token was invalid. Public reads and the connected app
worked, but the initial orphan claim commit could not be created through that
app's available Git interface. A device login lets Brett reconnect from his
phone without changing the claim protocol. Credential repair and passive login
waiting are recorded separately from coordination overhead. The first device
code expired without authorization. No claim was created as a workaround.

Reusing the already-pinned Pandoc avoided another download/toolchain repair.
Site generation still changes unrelated pages even with matching versions.
A possible later small improvement is a NEWS-only build route for a NEWS-only
change, with the corresponding build guidance updated once. It is a candidate,
not an added policy or a claim of measured savings.

## Measurement rules for B-99, fixed before starting it

- Time claim and member-checkout setup from the first pickup command to the
  prepared worktree. Exclude authentication repair and passive waiting.
- Record implementation, verification, coordination/publication, environment
  repair and production of this requested audit separately. A mixed interval
  stays mixed; it does not become an invented percentage.
- Count repeated manual lookups, reruns caused by coordination, requests for
  approval, and external waits. Distinguish required checks from rework.
- Compare the pickup interval with B-120's identifiable **2m14s** setup interval.
  Different repositories and task scopes limit the comparison. One run cannot
  establish a causal whole-task improvement or amortize helper development.
- Report an avoidable share only when a recorded interval supports it. The
  B-120 audit's original 35–45% administration and 20–30% avoidable estimates
  were withdrawn; they are not the baseline.

## Next run

B-99 was the oldest eligible P2 candidate in the live queue inspection. After
Brett completed a fresh device login on his computer, the existing client
claimed it successfully, without an alternative lock mechanism.

The member checkout was fetched and fast-forwarded before the pickup timer.
From **04:10:23 to 04:11:21 UTC on 2026-10-01**, `hub status`, `hub claim` and the
two printed setup commands prepared its worktree in **58s**. B-120's recorded
pickup was 2m14s: an observed 1m16s (57%) shorter interval, with preparation,
repository and scope differences that prevent assigning the change to the
helpers alone. It is not a measured whole-task bureaucracy or avoidable share.

B-99's new tests reproduced both original 404s. After the three-cell CSV fix,
the full suite passes **54 tests and 22 subtests, zero skips**, including live
Turtle subject/type checks. Generated artifacts remain synchronized. The
item's implementation, source justification, skip retirement and timings live
in `smn-data-pkg`'s `.hub/workpads/B-99.md`. No file-edit race or coordination
rerun occurred during its RED/GREEN verification.

## Adjustment after B-99

`status` initially omitted `evidence` and `retires_when`, so the pickup still
needed a separate queue-file read. The next iteration prints those canonical
fields using the existing extractor and checks the added output in the same
harness. The frozen harness still passes **43 checks, no failures or skips**.
This is two added fields, not another planner or a new claim protocol.

The next cycle claimed B-186, a queued stream-validation defect. From
**04:24:16 to 04:25:20 UTC, 64s**, the same status/claim/setup sequence prepared
the worktree. This includes a brief inspection of the Claude review workflow;
the interval is not a pure setup benchmark. The evidence and retirement
condition were available in status, so no separate queue-file read was needed.
Its implementation agent reports 164 passing Python tests after a focused RED,
with lint passing on all 318 queue items. Root review and publication follow.

Brett subsequently asked for ongoing iterations, parallel claims once the
process settles, and Claude review rounds until substantive findings are
resolved. Brett then approved the complete helper and B-99 PR texts and
explicitly authorized routine branch publication and draft PR creation for
this continuous run without repeated approval questions; review-fix commits
were already authorized. This is a chat authorization for this run, not an
amendment to AGENTS or HUB policy. Semantic and policy decisions remain his;
merge, release and person-contact authority was not added. The experiment does
not treat authorization or an unstarted review as a successful publication or
review outcome.


## Parallel round and NEWS build adjustment

- B-268 and B-132 published as draft pull requests 216 and 217. Each agent
  owns its claim, worktree, focused verification, publication and handoff.
  Root's extra publication hold delayed B-132 after its tested local commit;
  it is removed for routine drafts under Brett's standing approval. No new
  tracker or approval boundary is introduced.
- B-155's pak-bootstrap failure proofs pass; B-133 is the next independent
  vignette fix. B-186's stream-lint regression has 164 passing offline tests.
  These are observed local results, not merged work or completed remote reviews.
- The NEWS-only build completed with the existing pinned toolchain. Before
  curation it touched three tracked paths (NEWS HTML, its Markdown companion and search), versus about
  forty tracked pages and four new reference pages in B-268's full build.
  It still renders the whole NEWS page, so pre-existing source/site drift must
  be reviewed and unrelated fragments restored. This reduces output scope;
  build duration and total overhead savings were not isolated.
- Claude jobs on helper PR 215 finished green but produced no review comments.
  Logs report two denied tool calls on the draft and three after ready-for-review.
  The denied calls are hidden and no execution artifact was retained. Review
  completion is therefore unverified. Local Claude is logged out; Brett was
  asked to reconnect while implementation continues.

Current useful balance: one claim per real agent, isolated worktrees, one
focused regression per defect, and autonomous routine draft publication.
Further redesign is deferred until a concrete recurring cost warrants it.
The requested measurement itself remains a separate activity, not attributed
wholesale to hub bureaucracy.


### Review repair and build checks

Codex review on PR 215 found that a handoff with no required branch could
report success. A frozen harness run reproduced it (42 passing checks, one
failure); status now requires the exact `agent/<id>/<agent>` branch for a
handoff. Other actions may legitimately omit it. The invalid-branch fixture
explicitly writes an arbitrary branch, as well as testing a missing branch.

NEWS-only rejects an unknown flag, rejects combining a partial build with a
toolchain upgrade, and rejects the unpinned local Pandoc. A pinned build passes.
Inspection found that `build_news()` alone omits its Markdown companion, so
the route now uses pkgdown's existing converter for NEWS alone. B-186 exercised
the route from a different task checkout without copying the helper script.

B-133's actual Claude comment on head 1d48520 reports no issues found. Other
draft jobs remain skips or unverified, not successful reviews. B-155's first
workflow failed with zero jobs and was absent from PR checks; actionlint
reproduced an invalid runner context and verified the pushed correction.
This is implementation rework, rather than claim administration.

The handoff repair's frozen GREEN run passes all 43 checks, zero failures or
skips. During B-186 handoff, root edited the client while Bash was still
reading it: the claim handoff succeeded, followed by a stray parse/read error.
An idempotent repeat confirmed handoff. Freeze the client during live commands
as well as harness runs; this was an avoidable coordination race.


## Sustained parallel round, observed through 05:59 UTC on 2026-10-01

The useful balance is now in use: each real agent selects an independent
eligible item, runs its evidence-driven checks, publishes under the standing
chat approval and hands it off. Root does not approve these routine steps
again. Claims and handoffs remain in the existing client; merge decisions
remain with Brett. This has kept three implementation agents working while
root fixes the review instrument and completes separate claims.

### Concrete results of the small changes

| Observation | Evidence and limits |
| --- | --- |
| B-203 reuses the NEWS-only route | 22.5s; generated output scope is three tracked paths. Claim-to-publication was about14m19s, including policy review, experiments and documentation, so that interval is not a waste estimate. |
| B-177 reuses the route | NEWS16s plus search9.5s; baseline/RED/GREEN tests11.8/7.4/8s. Claim-to-publication about11m48s. Different task scopes prevent a causal before/after percentage. |
| B-133 uses focused verification | About11m40s claim-to-ready; approximately5m10s was verification and1m publication. The complete CI and actual Claude review passed. |
| Routine publication is autonomous | Agents published B-203, B-256, B-371, B-177, B-229, B-23, B-262, B-264 and B-310 without an extra root/user permission round. |
| Source/site drift still consumes effort | B-269 final inspection caught a duplicated older news fragment. It was removed; only the new NEWS and reader search entries changed. This manual curation is the next improvement candidate. |
| Root interleaves work | B-269's claim began05:19:17, but review-workflow repair occupied the same interval. Elapsed claim duration is not a task-only or administrative duration. |

### Review evidence and repair

Claude has actually commented “No issues found” on helper PR215 at3adde91 and
vignette PR220 at1d48520. A green job without a posted review is not counted.
Draft PR jobs skip, and the plugin also skips already-commented PRs, so it
cannot supply the iterative review requested. PR222 replaces those skips with
a scoped per-head review and checks successful read/diff/comment tool results,
a successful SDK result, no denials and the exact reviewed-head marker.

The Anthropic action refuses a changed workflow before it reaches the default
branch. The repair therefore needs one explicit bootstrap merge decision;
its five other CI checks pass at051dd05. This is a concrete approval boundary,
not another routine publication question. Local Claude is still logged out.
A separate B-229 Claude job failed after375ms with no model usage, so it also
provides no review. No claim is described as Claude-reviewed on those signals.

Codex found a real public-wrapper candidate-limit defect in Python PR80.
The agent reproduced3 versus6 candidates, fixed the wrapper and verified28
focused tests in both environments; repair head dd8a5b0 has all three workflows
green. Root's independent B-269 read agrees with the enum change; a truncated
source read incorrectly reported a missing similarity field, and a direct read
of the pinned schema confirmed its string range. Review findings need evidence.

### Published surfaces for resumption

These links record where the work can be reviewed. They do not replace live
queue/claim state or assert merge completion.

| Hub item | Pull request |
| --- | --- |
| B-99 | [smn-data-pkg13](https://github.com/salmon-data-mobilization/smn-data-pkg/pull/13) |
| Helpers | [metasalmon215](https://github.com/salmon-data-mobilization/metasalmon/pull/215) |
| B-268 / B-132 / B-155 / B-186 | [216](https://github.com/salmon-data-mobilization/metasalmon/pull/216), [217](https://github.com/salmon-data-mobilization/metasalmon/pull/217), [218](https://github.com/salmon-data-mobilization/metasalmon/pull/218), [219](https://github.com/salmon-data-mobilization/metasalmon/pull/219) |
| B-133 / B-203 | [220](https://github.com/salmon-data-mobilization/metasalmon/pull/220), [221](https://github.com/salmon-data-mobilization/metasalmon/pull/221) |
| Review repair | [222](https://github.com/salmon-data-mobilization/metasalmon/pull/222) |
| B-256 / B-371 / B-177 / B-229 | [223](https://github.com/salmon-data-mobilization/metasalmon/pull/223), [224](https://github.com/salmon-data-mobilization/metasalmon/pull/224), [225](https://github.com/salmon-data-mobilization/metasalmon/pull/225), [226](https://github.com/salmon-data-mobilization/metasalmon/pull/226) |
| B-23 / B-262 / B-137 / B-269 / B-310 | [228](https://github.com/salmon-data-mobilization/metasalmon/pull/228), [229](https://github.com/salmon-data-mobilization/metasalmon/pull/229), [230](https://github.com/salmon-data-mobilization/metasalmon/pull/230), [231](https://github.com/salmon-data-mobilization/metasalmon/pull/231), [232](https://github.com/salmon-data-mobilization/metasalmon/pull/232) |
| B-261 / B-302 / B-264 | [Python79](https://github.com/salmon-data-mobilization/metasalmonpy/pull/79), [80](https://github.com/salmon-data-mobilization/metasalmonpy/pull/80), [81](https://github.com/salmon-data-mobilization/metasalmonpy/pull/81) |

### Next adjustment

A dedicated NEWS source/site reconciliation could remove repeated manual
fragment restoration. Keep it separate from defect branches and measure its
next use before adding automation. More workflow design is deferred while
independent claims can proceed. Requested measurement, environment repair,
verification, implementation rework and avoidable coordination remain separate;
there is still no defensible whole-run “percent wasted” measurement.


## Harness isolation adjustment and shared handoff compatibility

B-338 defines a chat handoff for shared repositories with no branch field and
exact `reason: hand-back in chat`. The status helper now recognizes that shape
and prints its reason. Missing/wrong reason, an explicitly empty branch and an
arbitrary branch remain unknown; ordinary branch handoffs keep their exact
branch check. Status reads the record; it does not grant either publication mode.

The compatibility fixture reproduced the expected status failure. A separate
repository-fingerprint failure was caused by another worktree creating a branch
during the harness, although the tested source files stayed frozen. B-338's
agent hit the same condition during independent verification. This is avoidable
coordination rework: freezing files alone cannot freeze a shared Git common-dir.

The small execution fix is a local frozen clone with separate Git refs, copied
working client/harness bytes and a local snapshot commit. Run the existing
harness there, then compare the tested source bytes with the working files.
No guard is weakened and other agents keep working. In that isolated clone,
all **43 checks pass, zero failures/skips**, and byte comparisons match.
B-338 independently reused the procedure in its next verification round:
**43/43 checks passed**, including the repository-ref fingerprint check that
had failed during concurrent shared-ref activity. Its clone was
`/tmp/metasalmon-b338-frozen.zc4fCq/repo`; root's was a different clone.
This demonstrates removal of that concrete source of rework while retaining
the same guard. It does not measure a percentage saving for the whole run.

B-394 was published as [PR234](https://github.com/salmon-data-mobilization/metasalmon/pull/234)
after its RED and all 163 offline queue tests passed. Its broader read exposed
seven absent recognizable historical port records; live merged PR evidence
justifies the amendments. Independent inspection found no actionable bug.
B-265, B-401 and B-129 are published as [233](https://github.com/salmon-data-mobilization/metasalmon/pull/233),
[235](https://github.com/salmon-data-mobilization/metasalmon/pull/235) and
[236](https://github.com/salmon-data-mobilization/metasalmon/pull/236).

Two scoped build ideas remain candidates: reconcile NEWS source/site history,
and preserve existing site assets during article/index builds. They are not
implemented as another workflow layer during ongoing claims.

## Next work round — independent pickup and evidence corrections

- B-59's agent reports about **40 seconds** for claim/worktree pickup using the
  current helpers. The earlier 58/64/134-second observations differ in scope
  and preparation, so the direction is encouraging but not a causal estimate.
- B-252's paired executable probes disproved its original source-only R
  premise. The agent corrected the actual Python direct-writer/table-inference
  discrepancy and kept existing caller extras. Root publishes a narrow hub
  documentation companion. This is necessary evidence correction, not time
  to remove as bureaucracy; the durable probes prevent repeating the mistake.
- B-209's independent review exposed historical attribution, wrapped-line and
  generated freshness gaps in the first implementation. RED fixtures reproduce
  them before repair. That review spends time on demonstrated bugs. It should
  not be bundled into an undifferentiated “administration” percentage.
- Routine publication and handoff still require no additional user approval.
  The pending Claude-workflow bootstrap merge is a separate unresolved action;
  actual Claude review of new heads remains unverified. A green skipped job
  is not counted as a review.

Additional review surfaces, without implying queue completion or merge:
[B-338 / PR237](https://github.com/salmon-data-mobilization/metasalmon/pull/237),
[B-396 / PR238](https://github.com/salmon-data-mobilization/metasalmon/pull/238),
[B-328 / PR239](https://github.com/salmon-data-mobilization/metasalmon/pull/239),
[B-121 / PR240](https://github.com/salmon-data-mobilization/metasalmon/pull/240),
[B-252 / Python PR82](https://github.com/salmon-data-mobilization/metasalmonpy/pull/82),
and [B-167 / smn-data-pkg PR14](https://github.com/salmon-data-mobilization/smn-data-pkg/pull/14).
Agents continue independent eligible work rather than waiting for root to
approve routine publication. Remaining design or semantic choices receive
draft evidence where a ruling is required.


## Continued work through 07:40 UTC on 2026-10-01

The live ready list now has no unclaimed item. This does not mean the queue is
complete: drafts hold claims until landing, and several items require a semantic
or policy decision. Agents continue useful companion ports, review repairs and
source-backed card repairs while those decisions remain open.

### Next-round findings and adjustments

- B-147's repository lacked the standard `agent-run` label. The agent spent
  approximately **three minutes** investigating whether another approval was
  needed. Brett's existing routine draft-publication authorization covered
  creating the necessary standard label. Root clarified that scope once; the
  agent created the same name/color as the hub and published. This is reported
  avoidable coordination time, not a measured share of that whole task.
- B-60's documentation build revealed inconsistent author metadata. A first
  repair incorrectly promoted an old duplicate `Author` string into canonical
  `Authors@R`, producing attribution and footer churn. Root caught it; the final
  change preserves the original Brett-only `Authors@R` and removes redundant
  fields. This was implementation/review rework, not approval bureaucracy.
- B-58's independent read found two authored base warnings beyond the original
  cli/rlang inventory. Both were classed with exact messages, null calls and
  muffling preserved. The first integrated run also exposed two pre-existing
  positional cli class strings; regression tests reproduce and fix them. Final
  strict R check has zero errors, warnings and notes. These are useful checks,
  not time that should be eliminated from coordination.
- B-58's search-output audit initially assumed all paths/ids were scalar and
  unique. Existing records violate both assumptions. A whole-record multiset
  comparison verifies the actual scoped change while preserving old repeated
  records. The failed audit assumptions are local instrument rework, not hub
  bureaucracy; no new required tracker or guard was created.
- A fresh Codex finding on Python PR79 correctly identified that a
  semicolon-separated constraint slot needs one ledger row per distinct IRI.
  The guide was corrected, rendered and pushed at `fe0039f`. Old findings on
  Python PR80 and hub PR215 are already fixed at their current heads. No person
  reply or repeated publication approval was required.
- B-123's bounded identity checks pass, but the commons compiler scans its
  mandatory workpad as a card. Existing green PR41 fixes that exact compiler
  defect. The new draft records the dependency instead of duplicating the fix
  or suppressing validation. A single decision packet preserves its nine
  outstanding choices; the bounded guard is not claimed as item retirement.
- B-238's coverage inventory found term-specific headings already present in
  existing commons cards. Work is repairing their source ledgers rather than
  creating duplicate cards. The unexpected source volume is genuine evidence
  work. Unresolved meaning choices are grouped in a decision packet instead of
  inventing a question/claim for every term.

### Next concrete build improvement

A dedicated current-main NEWS reconciliation is underway. The first pinned
NEWS-only build took **15.54 seconds** and touched only NEWS HTML/Markdown and
search, but recovered 563 added/14 removed lines of existing source/site drift.
This output scope is observed; it is not a time-saving estimate.

That build also exposed the reason partial builds strip icons: committed favicon
assets exist in generated `docs/`, but pkgdown checks for authoring inputs under
`pkgdown/favicon`. Restoring that documented input location from the existing
identical bytes lets pkgdown render icon links normally, without a custom HTML
patcher. The follow-up build and repeatability check are pending at this entry.

### Additional published review surfaces

[B-209 / PR241](https://github.com/salmon-data-mobilization/metasalmon/pull/241),
[B-252 hub correction / PR242](https://github.com/salmon-data-mobilization/metasalmon/pull/242),
[B-59 / R PR243](https://github.com/salmon-data-mobilization/metasalmon/pull/243),
[B-59 / Python PR83](https://github.com/salmon-data-mobilization/metasalmonpy/pull/83),
[B-130 / PR244](https://github.com/salmon-data-mobilization/metasalmon/pull/244),
[B-60 / PR245](https://github.com/salmon-data-mobilization/metasalmon/pull/245),
[B-58 / R PR246](https://github.com/salmon-data-mobilization/metasalmon/pull/246),
[B-58 / Python PR84](https://github.com/salmon-data-mobilization/metasalmonpy/pull/84),
[B-147 / ontology PR37](https://github.com/salmon-data-mobilization/salmon-domain-ontology/pull/37),
[B-154 / specification proposal PR15](https://github.com/salmon-data-mobilization/smn-data-pkg/pull/15),
and [B-123 / commons PR42](https://github.com/salmon-data-mobilization/salmon-knowledge-commons/pull/42).

These are draft review surfaces, not merge or queue-completion records. Actual
Claude reviews of the new heads remain absent. Failed/skipped jobs are not
counted as review convergence; the bootstrap-workflow decision is still pending.
There is still no defensible whole-run percentage of wasted time.


## Reconciliation reused and prerequisite integration verified

The NEWS/favicon change is published as
[PR247](https://github.com/salmon-data-mobilization/metasalmon/pull/247)
at `626e3a0`. The recovered seven favicon inputs are byte-identical to the
existing outputs. A pinned build after recovery took13.63s; its repeat took
13.31s and changed no NEWS/search hashes. Replaying B-58's actual seven-line
NEWS patch took14.45s and changed only two added/one removed HTML lines, eight
added Markdown lines and the corresponding Added search record. No historical
fragment cleanup was needed. This is a controlled reuse of a real task patch,
not an independent next claim or a measured whole-task percentage.

Independent review confirmed all545 non-NEWS search records are unchanged.
It also confirmed a concrete integration dependency: the newly rendered packet
API NEWS links need the two reference pages supplied by PR245. The change stays
draft and records that ordering. No additional build framework was introduced.

B-130's same-stream Python companion is
[PR85](https://github.com/salmon-data-mobilization/metasalmonpy/pull/85)
at `fbd44f1`; all remote test/parity/doc/changelog checks pass. Thirty focused
checks include minimumPython3.9 and exact R report-byte parity; the full suite
passes1754tests and291subtests. Its elapsed interval was approximately8minutes;
un-timed setup/coordination observations are retained without an unsupported
percentage. Both verifier modules record the later B-58 condition-family
integration obligation; no conditional compatibility shim was added.

B-123 initially failed overall CI because its required workpad exposed the
existing compiler bug fixed by PR41. After the owner confirmed its checkout
was clean/frozen, root integrated PR41's exact published commit with an
additive local merge and documented the parent dependency. The original fix is
reused, with no duplicate implementation or weakened validation. Compiler and
identity controls pass locally; both full remote checks now pass at `2d4a2db`.
This lets verification proceed without a GitHub merge or another approval
round. The nine verification-policy choices remain unresolved, and B-123 is
not retired. This single dependency integration is measured as a practical
execution adjustment, not generalized into a new mandatory workflow.

B-238 has now repaired all12 formerly failing primary card ledgers. A direct
aggregate check on20 primary commons cards reports zero errors; pre-existing
nonfatal warning wording remains disclosed. Reading the actual Q64 ruling
revealed two cards still asking for choices Brett had already made. Their
bounded content correction avoids asking him again; unrelated definition
choices remain in the grouped decision packet. Domain/source repair time is
not attributed to claim bureaucracy.

B-58 R PR246 and the latest helper head `cc920d6` have their remote checks
green; new heads still lack actual Claude reviews. The existing hourly quiet
heartbeat continues the work and review loop. There is still no reliable
whole-run waste percentage, and no queue item is reported complete merely
because its draft was published or CI passed.
