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

## Numbering collision caught; optional lookup implemented

The B-238 routing follow-up is
[PR248](https://github.com/salmon-data-mobilization/metasalmon/pull/248)
at `98a6e31`. It restores legacy Q64 as a queue question, groups the remaining
definition choices under Q73, reuses B-238/B-232 as the existing commons and
ontology owners, and names the already ruled aggregate SHACL repair as B-428.
All questions remain unclaimable; B-428 stays in the icebox. No meanings,
retirement conditions, promotion grants, or policy were changed. Reusing owners
reduces records but holds the existing S9 prerequisite open until its choices
and required updates are finished. This tradeoff is explicit in the draft.

The routing worktree was created at **08:19:44 UTC**, and PR248 at
**08:31:50 UTC**: **12 minutes 6 seconds**, excluding earlier reconnaissance.
That interval mixes necessary routing, drafting, validation and publication;
it is not all avoidable waste. Before publishing, a fresh fetch caught B-427
already used by another session's `codex/public-catalogue-discovery` branch.
The planned repair was renumbered to B-428. Q72 was likewise already present
in a question heading on PR209's branch, despite having no new queue file.
Manual checking had involved 38 open PRs, fetched refs and local worktrees.

`python3 scripts/hub_ids.py B` now suggests the next observed number;
`python3 scripts/hub_ids.py B-427` reports where that ID is seen. This optional
helper reads queue filenames and numbered question/backlog headings across
local/fetched remote branches and all registered worktrees, including untracked
files. It performs no fetch, reservation, claim, promotion or GitHub write.
Failed reads and unsupported source symlinks return `unknown` / exit 3.
Suggestions remain unreserved: other clones' unpublished work and later writes
are outside its reach. The existing atomic claim protocol is unchanged.

The real collision replay found B-427 and Q72, then B-428/Q73 on the routing
branch. Initial scans took **2.07–2.54 seconds** across **217 refs and 38
worktrees**; the final scan with additional source-root validation took
**3.92 seconds** and suggested B-429. Offline fixtures, rather than the now
published routing branch, demonstrate untracked-file reach. Nine focused tests
pass; the existing scripts test suite passes **195 tests and 44 subtests**.
Independent review found Git's possible lazy fetch in a partial clone; the
child environment now explicitly disables lazy fetch and optional locks, and
has a regression check. Symlinked source locations fail instead of being skipped
or followed. These corrections are useful implementation review, not claim
bureaucracy. No whole-task percentage saving is claimed from these timings.

The pinned NEWS-only build passed, but again recovered unrelated current-source
history absent from this older site branch. Only the generated new bullet and
its one Internal search record were retained, with other output bytes preserved.
This remaining curation cost is exactly what PR247's separate reconciliation
removes; the controlled B-58 replay there already demonstrated its reuse. Avoid
duplicating that reconciliation into every work branch while it awaits landing.

### Next bounded policy improvement to consider

The current HUB claimable grant explicitly permits qualifying changes to
`true`, while setting `false` remains class 8. An agent that proves an item
needs a recorded Brett decision must therefore draft the correction and leave
the default queue misleading until review. A narrow standing grant to mark such
an item unclaimable, citing the existing unanswered decision, could remove this
repeat coordination cost. **This is a proposal, not an implemented grant.**
It would not authorize promotion, a semantic ruling, early retirement, or a merge.

### Current continuation boundary

B-238 source
[PR43](https://github.com/salmon-data-mobilization/salmon-knowledge-commons/pull/43)
is green at `7d8889e`; source/ledger repair is delivered, while its definition
choices and B-428 validator change remain for Brett. Independent review confirms
the Q64(b) repair implements an existing ruling but still relaxes a validator
under HUB class 6, so it cannot be made claimable under the routine publication
grant. This is a real remaining authority boundary, not an extra approval for
ordinary pushes.

The latest bounded review sweep found no new substantive findings. Current
R PR244/247, Python PR85 and commons PR42/43 checks pass. Green/skipped review
jobs still do not establish Claude review of the latest heads. `hub ready`
returns no free claimable item, with held B-60 as a positive control. Delivered
drafts retain their claims; queue retirement and merges remain pending. The
existing quiet hourly heartbeat continues pickup and review follow-ups when
state changes. There is still no defensible whole-run waste percentage.


## Actual Claude reviews and pause checkpoint — 2026-10-01

Brett is actively moving the in-package model call out through S16. New repairs
to the provider client, chat request/retry stack, llm/chat options and retiring
`chat_decomposition()` documentation are excluded from this run. The packet,
assessment rows, deterministic validators, context readers, closure, selected-IRI
verification and non-model configuration survive and remain in scope. R PR194
merged the packet seam; open PR210 is its follow-up. B-329/B-330 name full
removal; no separate open full-removal PR was found in the live sweep. Do not
duplicate or take over Brett's work. A valid Python PR83 guide correction pushed
just before this instruction is retained; prioritization does not warrant revert
churn.

Claude CLI authentication now works through the existing first-party subscription.
Successful local runs report actual Opus model usage and no permission denials;
list-price cost fields are not evidence of a separately billed API call. The new
GitHub PR247/248 reviews were real. PR247's missing packet reference pages are
already supplied by PR245: preserve that merge order rather than duplicate the
pages. PR248's owner wording was simplified and commons evidence explicitly
pinned to the observed ontology commit/date. Routing PR248 is `65bee09` and
commons PR43 is `1ee02bb`; their checks pass. No review opinion changed Brett's
semantic rulings or validator authority.

### Surviving-code review repairs

- R B-58 PR246 is published at `c5571a5`. Four semantic-closure warnings now
  carry the validation family, matching Python. Four final-form assertions fail
  on the previous head and pass after the fix; the unchanged-flow proof passes.
  Actual narrow Claude code/test review found no remaining P1/P2 defect. The
  original broader pair review's Python coverage was incomplete and inconsistently
  enumerated; the workpad/body now say so. Its strict R CMD check preceded this
  additive fix, also corrected in the record. Last observed CI: five checks green,
  R CMD check still running. No further local review is needed solely for wording.
- R B-59 PR243 is published at `9aff956`, clean, with all six checks green. A
  stored default schema base URL could remain stale after a pin change/reload;
  the default is now resolved at call time. Two RED assertions became GREEN,
  focused schema/offline tests pass, and strict local R CMD check is 0/0/0.
  A bounded actual Claude re-review completed in about 90 seconds with no new
  defect. Generated outputs were verified locally, not directly inspected by Claude.
- B-130's successful per-language reviews exposed a real Python transport issue:
  Requests' inactivity timeout did not impose the advertised total wall bound.
  A fixed subprocess with a deadline, streamed final response and explicit reap
  is implemented locally; 33 focused tests on Python 3.14 and 3.9 and the full
  1,757-test/291-subtest suite pass (two existing skips disclosed). R also has a
  confirmed vector condition-message capture defect: the narrow collapse fix and
  34 focused expectations pass. These edits are frozen locally for the pause,
  not yet published. Default R full-body GET and Python header-only success still
  differ; record temporary parity debt, not an approved deliberate deviation.
  A read-only curl multi experiment looks promising but its final-header/status
  correspondence and intermediate redirects need adversarial proof before any
  implementation. No B-130 curl change has been made.

### Next use of the smaller-review adjustment

The helper's broad review hit its 480-second deadline without a final result;
a subsequent diff-only review hit 240 seconds, also without a final result.
Neither counts as completed review. Restricting the next call to the two ID-helper
files and explicit medium effort produced an actual static review in **68.53
seconds**. It found that fixture Git writes inherited `GIT_DIR`/`GIT_INDEX_FILE`
and could mutate a caller repository despite `-C`. A disposable caller control
reproduced changed HEAD/index/refs/status before the fix, with no real checkout
at risk. Sanitized fixture environments close that path; ten tests pass.

A **38.98-second** static additive-patch review found an index-snapshot flake:
`git status` could refresh the caller index between snapshots. The caller's read
commands now disable optional locks; ten tests pass at local head `928f106`.
That one-line final correction has not received another Claude review. A
conditional concern about other unsanitized fixture writes was checked directly:
all Git subprocess sites in this file pass a sanitized environment. No production
helper behaviour changed, so no new package port or site build is owed.

Across just these four serial helper CLI attempts, about **87%** of invocation
time hit a deadline without a final review (720 seconds of deadlines versus
107.51 seconds for completed reviews). This is a narrow review-attempt metric,
not a whole-run waste percentage or a percentage attributable to hub claims.
The comparison changes both scope and effort, so it does not isolate causation.
Actual reproduction and repair are useful verification/implementation. The
B-130 broad pair attempt likewise timed out at 480.01 seconds; its smaller
language-specific reviews completed at 370.78 and 264.49 seconds. Those agents
ran concurrently, so their durations must not be added as elapsed wall time.

Repeated text-only assurance after B-58's record was accurate cost a further
99.8-second local pass and yielded only wording nits. Stop such optional passes
once concrete corrections are independently checked; do not keep feeding the
same record back for reassurance. A malformed initial MCP envelope was a tool
setup error, separate from claim coordination. No approval, ID allocation or new
claim was needed for these review fixes. There is still no defensible whole-run
bureaucracy percentage.

### Safe resume point

Brett requested a pause to update Codex at approximately 14:40 UTC. The hourly
heartbeat is PAUSED, and task-owned review/server processes are being stopped.
Helper fixture fixes `7b30dbb`/`928f106` are local and unpushed; this log is saved
with them. Published B-58/B-59 fixes are preserved. On resume, inspect new review
findings and exact-head CI, finish the frozen B-130 review/transport parity work,
then publish authorized additive commits. Recheck `hub ready` before pickup;
its latest successful fresh-default-branch scan had no free item, with B-238's
held handoff as the positive control. Do not promote blocked semantic/policy work
or retire a held draft just to create more throughput. Resume the same heartbeat
only when Brett asks to continue.


All three subagents confirmed their pause. B-130 R is clean at local `1309a19`
(branch `agent/B-130/a-16638a45c615a2f8`, published PR244 head still `fa0d4a47`);
Python is clean at local `edeb1f0` (branch `agent/B-130/a-6e8d8b1dfb43a0d4`,
published PR85 head still `fbd44f1`). Both workpads contain the exact checkpoint.
Its second delta review was terminated and reaped for Brett's pause after
373.66 seconds, with no final JSON: incomplete, not a review result or a timeout
caused by the workflow adjustment. No task-owned command remains in flight.
The read-only curl child was interrupted; the candidate must not be treated as
validated. No push, PR-body update, or curl implementation occurred after the
pause request.


## Resumed; small merge batches and shared ID scan — 2026-10-01

Brett merged review repair PR222 (`1d07477`) and its prompt/check alignment
follow-up PR249 (`40905f8`). The same quiet heartbeat is ACTIVE again. He also
authorized routine noncritical merges in this run, with only consequential
choices brought to him. Existing HUB critical classes and review/CI gates still
apply. Keep ready transitions to up to three at a time and record delegated
merges here; no human contact, release or policy authority is added.

The next optional helper adjustment accepts several prefixes/IDs in one call,
e.g. `python3 scripts/hub_ids.py B Q B-427`. One snapshot serves every query;
exit 1 means an explicit ID was seen, and invalid or incomplete batches return
3 before printing any suggestions. Both focused batch tests fail on the old CLI
and pass after the change. All twelve ID-helper tests and the existing scripts
suite (200 tests) pass. The previously frozen fixture fixes are retained.

Observed next use on this clone: separate B and Q calls took 4.193 and 3.918
seconds; the combined call took 3.895 seconds across 219 refs and 37 worktrees,
returning the same B-429/Q-74 suggestions. That saves 4.216 seconds (52%) for
these two scans. Cache/order effects limit attribution; it is not a whole-task
saving or an atomic reservation. No new task, claim or allocation was needed.

The stale helper checkout refused live queue reads after main advanced. It now
contains main through additive merges, and its richer `status` works again.
Today main advanced twice for review repair, so run current main's hub client
for pickup once PR215 lands; use existing `hub fresh` rather than manual claim
lookups. Do not weaken the freshness guard. Generated NEWS conflict resolution
initially mishandled the minified search index's empty placeholder rows; this
was caught and repaired locally before publication, and the unpublished merge
was amended. This is environment/merge repair, not claim bureaucracy. The
merged search index preserves every incoming record except the intended
Internal section. Its rebuilt Internal section is retained under the pinned
NEWS-only build; unrelated historical reconciliation remains PR247's scope.

### Working merge order

| Batch / prerequisite | PRs | Gate / reason |
| --- | --- | --- |
| First routine review batch | R215, R243, R245 | Publish helper fixes; resolve R245 conflict; actual review and current-head CI |
| Site follow-up | R247 after R245 | R245 supplies both packet reference pages; avoid a known broken-link re-review |
| Commons prerequisite | commons41, then commons42 | Root operational workpad filtering matches existing validator boundary; independent actual review first |
| Critical meaning/routing | commons43, then R248; ontology37 separately | Unresolved definition/IRI/routing choices stay for Brett |
| Critical API pairs | R244/Python85; R246/Python84 | New verifier API/remaining transport debt and condition hierarchy's major-release judgement stay for Brett |

Ready or green/skipped jobs do not prove a completed review. Existing successful
local reviews have bounded coverage; the repaired GitHub workflow supplies an
inspectable verdict on the current push/ready event. The first review batch has
no definite critical class on the checked diffs. PR215 is already ready, so its
new push triggers review; R243/R245 need ready transitions. No merge has occurred
under the new grant at this checkpoint. No free claimable item appears on the
latest fresh default scan, with B-238's held handoff as the positive control.

### Delegated merges and the next diagnostic adjustment — 2026-10-01

The earlier checkpoint above predates these merges. Each merge commit records
the direct chat authority, delegated class, exact head, review evidence and CI.
Branches remain; only clean auxiliary checkouts with no unique commits are
removed after the clean primary checkout is fast-forwarded.

| UTC merge time | PR / merge | Delegated class and evidence |
| --- | --- | --- |
| 15:33:18 | Commons41 / `1b7594e` | Routine compiler repair matching the existing root `.hub` boundary; actual local Claude and independent source review, final-head checks green. A valid `.hub-archive` positive control catches the overbroad mutant. |
| 15:42:28 | R243 / `d0339c0` | Configuration defect/documentation; six exact-head checks green, actual current-head Claude 0 important/4 nits and independent source review, no human thread or unresolved critical choice. |
| 16:01:19 | Python81 (B-264) / `430b568` | Additive procedure-closure regression test; six current-head checks green, expected PR deploy skip, completed Codex and actual 55.4s local Claude source review with zero denied calls, no substantive findings. |

Python81 was already clean, mergeable and based on current main. Inspection
avoided an unnecessary freshness-only merge, push and review. Commons41 and
R243 checkouts were cleaned up after their primary checkouts fast-forwarded;
their branches were preserved. Commons42 stays critical: its validator changes
need human approval under Commons governance, and nine verification decisions
remain unresolved. The prior table's dependency is an order, not permission to
merge Commons42 automatically.

R219/B-186 is the next routine ready item: additive stream-identity validation,
164 queue tests, 318 real items linted, no source conflict or new policy. The
base integration required NEWS/site conflict repair; fresh reviews/checks run
on `28f5ad8`. R245 supplies the two packet reference pages R247 needs. R247 is
now draft until that prerequisite lands. R241's own draft reserves the new
queue-prose rule for Brett, so it is held rather than silently reclassified.
The new R244/Python85 verifier API and reproduced informational-103 transport
gap remain critical; the single decision packet is in the R B-130 workpad,
linked from Python rather than copying its shared alternatives twice.

#### One small implementation change

The completion checker now describes denied calls using a bounded count and
fixed tool/command categories. It never copies raw SDK inputs, tool names,
paths, arguments or output. Unknown/malformed inputs remain unknown. No
permission, completed-tool, result, or exact-head gate is relaxed. Two new
tests fail on the old checker; four focused tests and all 190 scripts tests
available on this branch pass. Independent source review found no weakened
gate or untrusted-text path. The existing pinned NEWS-only builder generated
the fragment; all 614 baseline search records were retained before integrating
R243's six additions. The builder was borrowed only for generation and restored;
its canonical implementation remains PR215 until that PR lands.

The next denied run can identify a known tool/command category without exposing
its arguments. This is diagnostic investment, not a demonstrated time saving
yet. The old failed action records expose denial counts but hide categories
and retain no execution artifact, so inferring the denied commands would be
guessing. The existing retirement condition for the checker still applies.

#### Friction attribution and next use

- R215's first package job stalled during remote R setup; the reference-index
  job was cancelled in the same setup step. One targeted unchanged-head retry
  made the index green; the stalled package job was cancelled and retried once.
  This is environment repair plus passive wait, not claim coordination or test
  execution. R244 also spent 12m31s in setup-R before dependency installation.
- R245 and R247 posted nits-only summaries but failed their completion check
  on denied calls. Later 8-second green jobs skip after the nits marker and do
  not finish the failed review. The source summaries are real evidence with
  incomplete execution, never green-review claims.
- One local R245 review of a 1.53MB diff timed out after 360 seconds with no
  result or usage evidence. Generated/minified search and duplicated Rd/site
  text inflated that input. Its targeted continuation now uses the complete
  non-generated patch and checked generated correspondence, with streaming
  progress and a 180-second bound. Record its actual outcome, not a presumed
  saving or successful review.
- NEWS-only generation still exposes unrelated historical drift until R247
  reconciles the site. Two mistaken assumptions during fragment curation
  (one Internal heading overall and a heading prefix in search text) caused
  local assertion failures; candidates were corrected before publication.
  This is implementation/environment rework, not ID or claim bureaucracy.
- No new claim, ID allocation or routine publication/merge approval request
  was needed in this round. One concrete critical API/transport question was
  sent to Brett. Audit production and mixed review/implementation intervals
  stay separate; there is still no measured whole-run avoidable percentage.

The next candidate adjustment is to stop automatic review only on a nits
marker whose review also passed completion. A failed review's marker currently
stops its own continuation. Keep the five-round ceiling and substantive/nit
boundary; investigate this routing mismatch after the diagnostics' next use,
without treating a skipped job as a completed review or adding another tracker.

### Supported transport and merge-order follow-through — 2026-10-01

This append supersedes the earlier in-progress checkpoints without rewriting
the shared PR215 prefix.

- Python79/B-261 merged at 16:31:37 UTC as `9304851`, exact head `fe0039f`.
  The routine guide correction ports the established R workflow and changes
  no runtime, public API, IRI selection or guard. Six substantive current-head
  checks passed; the PR-ineligible deployment skipped. The completed Codex
  finding was fixed in the last commit, independently checked against the
  Python implementation, and no human thread awaited an answer. No completed
  Claude review is claimed for that PR. The clean primary checkout was
  fast-forwarded and the clean, fully merged B-261 checkout removed; its
  branch remains.
- PR215's first merge attempt was refused after R243 landed; no merge occurred.
  An additive main integration resolved the sole generated-search conflict,
  retained the helper fragment and all six incoming records, and left helper
  source/tests unchanged. All 200 script tests passed. Head `4a9c410` awaits
  its required package check; the prior completed Claude review on `7a631a9`
  found only nits. Its later skipped job supplies no new review evidence.
  PR215 stays first in the R merge order to avoid repeating this same
  generated conflict across the dependent log and documentation branches.
- PR250's actual GitHub Claude review on `5f95b20` completed successfully,
  ran the four checker tests and all 190 script tests, and found only three
  nits. The cancelled reference job passed on its one targeted unchanged-head
  retry. All six checks now pass. Publication waits for PR215's shared log
  prefix to land before integrating it; no optional nit-fix review loop.
- The targeted local R245 review reached 45 successful tool results but timed
  out at 180 seconds without a final result. It is incomplete, like the
  earlier 360-second full-diff attempt. Reducing the input did not establish
  either a completed review or a measured time saving. The full compact
  source patch and generated correspondence were independently inspected;
  the completed Codex finding is fixed. Keep that evidence separate from
  the actual nits-only Claude summaries whose completion checks failed.
- Claude's PR251 nits exposed concrete copies of queue state in S5 and the
  backlog. Three narrow follow-up commits correct those copies and preserve
  dated expectations as history; lint, generated blocks and OKF capture
  pass. Published head `c33dacb` remains draft pending current-head CI and
  its overlapping PR245 sequencing. This is necessary documentation repair,
  not justification for a broad sweep or a new planner.

Brett directly selected the supported Python HTTP backend in chat: implement
and verify it to close the reproduced informational-103 gap. HTTPX 0.28.1 with
HTTPcore 1.0.9 uses public streaming APIs and manual redirects so an unfinished
redirect body cannot delay receipt of the final response headers. The paired
11-route localhost proof now requires identical R/Python outcomes, including
103 followed by final 200, on Python 3.9.6 and 3.13.11. Host-scoped netrc auth,
cookies, proxy/CA settings and bounded failures receive separate controls.
Final independent review and publication are in progress. The dependency lock
was demonstrated stale before refresh and passes its check afterward. These
are local transport and installation proofs; required final-head CI and the
critical public verifier API review remain separate gates. The single B-130
decision packet records this choice; no parity-deviation ruling is invented.

No new claim or routine approval request was needed. The supported-backend
choice was consequential and is now answered. Implementation, verification,
dependency repair, requested audit, coordination and passive waiting remain
separate buckets. The concrete measured ID lookup reduction remains 52% for
that lookup alone; this round still provides no defensible whole-run avoidable
percentage. The next completed use of the safe denial diagnostics, rather
than an unchanged skipped review, will test whether that adjustment helps.

PR215 merged at 16:56:30 UTC as `0664962`, exact head `4a9c410`, after all six
current-head checks passed. The clean primary checkout was fast-forwarded;
its helper checkout had no unique work and archival was requested after
verifying this successor retains the entire shared log prefix. PR250 now
integrates that main additively. Its merged NEWS fragment retains both changes
and all 620 search records in order, with only the combined Internal text
regenerated. Bundling this append with the necessary integration avoids a
separate documentation-only push and CI fan-out.

PR251's current-head index timeout was traced to the Ubuntu apt mirror:
30.9 MB took 10m53s at 47.3 kB/s, consuming most of the 15-minute job before
the validator ran. PR215 fetched the same inputs in 35s. The one authorized
unchanged-head infrastructure retry fetched them in 10s and ran the actual
68-export/64-topic validator successfully. No timeout or validation gate was
weakened. This measured environment delay does not count as claim bureaucracy.

The B-130 final pass reproduced an invalid-port error accidentally borrowing
the injected requester's message-based transient heuristic. The concrete
default-worker regression fails before its narrow correction; preserving the
explicit permanent classification fixes that path without changing the hook.
The actual 380.56s Claude backend review completed with no denied calls and
identified netrc and proxy-bypass compatibility cases. Those findings are being
reproduced and corrected before publication; its prior frozen-snapshot review
does not cover later corrections. Requested audit found useful defects here;
it is not classified as wasted claim coordination.

After the necessary PR215 integration, PR250 passes all 202 script tests in
10.678s and the 68-export/64-topic reference check. Checker source/tests are
unchanged from its completed nits-only review. Required remote checks will run
on the new integration head; the prior green head is not substituted for it.

### Corrections found during the next review use — 2026-10-01

Codex's actual review of PR250 head `6f6b3a1` identified a P2 diagnostic
mistake: a compound Bash denial was labelled only by its first command, which
could direct repair toward an already allowed command. Eight pipeline,
compound, substitution and redirection cases fail before the narrow fix in
`f3ac497`; all five checker tests pass afterward. Specific fixed labels now
require a simple invocation; compound/unparsed syntax stays unclassified.
No shell syntax is executed and no raw text is emitted. Root independently
read the correction. This is a valid review fix, not the earlier optional
command-vocabulary nit. Required CI must run on its published corrected head.

The actual targeted B-130 follow-up review completed in 412.519s with no denied
calls and no Important findings/three nits. Together with the 380.56s first
round, requested audit took 793.079s and found useful netrc/proxy defects;
this is not a claimed efficiency saving. The revised Python source passes
54 focused tests on 3.9/3.13 and 1,778 tests plus 291 subtests on 3.13, with
the two existing optional skips. The full 3.9 suite's eight unchanged
`Path.write_text(newline=...)` helper failures remain disclosed. A three-hop
cookie control strengthens the claimed shared-jar evidence without another
model-review cycle. Prior manual Requests code already applied its per-request
proxy decision at each hop, so the correction does not create a new routing
parity rule. Broader CA/IDNA nits are not expanded into a redesign.

The final paired retry check exposed R's loss of curl's typed failure class.
The existing supported classed callback seam supplies URL-malformat and
redirect-limit errors; the narrow R correction preserves them and keeps those
two default failures permanent, matching Python, while leaving injected
requester behavior intact. Its source and paired attempt-count verification
are in progress. No approved divergence or new queue item is invented.

PR250's old-head index job cancelled before validation, but that head also has
the substantive diagnostic finding above. It is superseded by the correction;
do not spend a retry on a commit that cannot merge. Batch the valid source fix
and this durable append in one publication, then watch the new required gates.

### Backend parity proof and next merge batch — 2026-10-01

The final B-130 paired reports pass on Python 3.9.6 and 3.13.11. Both clients
consume informational 103 headers and return final 200/equal URL across the
eleven-route header fixture. Public reports agree on one attempt for malformed
URLs, one for the actual redirect-limit error, and three for a header timeout.
The loop-classification control needs three seconds to reach the limit; its
earlier 0.8-second bound measured a real timeout, correctly retried three times,
instead of the condition the instrument meant to test. Header/timeout controls
retain 0.8 seconds and the production deadline remains 30 seconds. This was
verification rework, not a runtime defect or a relaxed deadline.

The three-hop shared-cookie control passes with the 54 focused Python cases on
both versions. The R correction preserves curl's supported typed callback,
requires curl >= 6.2.1, and marks only the two default permanent failures before
the existing injected-requester heuristic. Its 81 focused expectations pass;
the strict R check reports zero errors, warnings and notes in 1m55.3s. Two
independent source reads and the actual paired JSON evidence found no remaining
substantive issue. Existing public API review and final published-head CI
remain separate gates; the selected backend does not authorize merging that
critical API. No further model-review round is needed to chase the three nits.

PR245/B-60 merged at 17:37:07 UTC as `6eba4c9`, exact head `dee9089`, under the
routine documentation/packaging class. All seven current-head checks passed;
the completed Codex copied-state finding is fixed and no human thread awaited
an answer. Actual Claude summaries reached nits, but their denied-call
completion failed; the later skipped job is not claimed as a completed review.
The first reference-index attempt spent 14m57s in setup-r/apt before validation.
One unchanged-head retry completed in 68s, with setup-r taking 31s, dependencies
26s and the actual reference assertion two seconds. This is environment repair,
not a measured claim-workflow saving. The clean primary checkout was
fast-forwarded and the clean, fully merged B-60 checkout removed; its branch
is preserved.

That merge required PR250's next integration: the sole conflict is minified
generated search JSON. All 657 incoming records and their order are retained;
only the verified development Internal record combines both additions. Checker
source/tests stay byte-identical to the fixed `a4d56b3` head and all five focused
tests pass. Incorrect assumptions about the generated record's identity and
insertion position failed assertions before correction; one wrong test glob
ran zero tests and was replaced with the discovered filename. Neither empty
result counted as evidence. These are implementation/instrument rework, not
claim bureaucracy. Final required CI must run on the integrated publication.

One small operational adjustment is being tested on PR251: when a PR remains
mergeable, inspect the synthesized merge and keep its tested head instead of
adding a base-integration commit solely for freshness. It remains `c33dacb`
when marked ready, with its existing six checks green and no pending human
thread. Its automatic Codex review is running. Do not claim an avoided elapsed
duration or completed review before the outcome. Necessary conflict resolution
and current-head CI still apply. PR247 waits for this common NEWS batch before
one integration, avoiding repeated reconstruction of the same generated files.

The bounded cross-chat B-199 audit is recorded separately as requested audit:
the published annotated sdp-0.3.2 tag, all eight R bundle hashes, R temporal
conformance and Python's fixed writer are verified. Python still pins
sdp-0.3.0, three bundle files differ and its written descriptor fails the old
pattern. The live B-199 claim is a protected handoff, so no claim was taken or
released. This consultation does not adopt a demo contract or assign an owner.

No new claim, ID allocation or routine publication/merge approval request was
needed in this batch. The earlier 52% reduction concerns one ID lookup only;
there is still no defensible whole-run avoidable percentage. Continue to keep
coordination, implementation, verification, environment repair, requested audit
and passive waiting separate rather than counting all non-coding time as waste.

### Published outcomes and the next experiment — 2026-10-01

| Outcome | Observed evidence | Workflow consequence |
| --- | --- | --- |
| PR251 merged `5334065` at 18:00:46 UTC | Exact head `bee2d57`; six green checks; completed Codex P2 diagram finding fixed | Kept the mergeable head when marked ready; the later commit fixed a real finding. No freshness-only integration or repeated approval. No elapsed saving inferred. |
| PR250 merged `e3fa5df` at 18:22:44 UTC | Exact head `47e673b`; six green checks; last Codex P2 compound-denial finding fixed and tested | First package-check attempt passed; no retry. Prior completed Claude review and later skipped jobs remain distinct. |
| B-130 backend published | R244 `2b58fe8` and Python85 `308b6ac`, applicable exact-head CI green; the normal Python PR deploy skip is expected | Supported HTTPX backend and paired R/Python behavior verified. Public verifier API stays critical draft. No new model audit or routine approval request. |
| Log route restored | PR215 prefix and PR250 append match canonical main byte-for-byte; clean auxiliary worktree has zero unique commits | Managed PR250 worktree archived; active heartbeat now reads this canonical file. Branch retained. |

The final remote R jobs both used R 4.6.1 and completed without retries:

| Interval | R244 | R250 |
| --- | ---: | ---: |
| Setup R | 5m16s | 10m58s |
| Dependencies | 7m56s | 14m36s |
| Full suite | 3m53s | 3m54s |
| Package check | 5m12s | 5m12s |
| Total job | 22m35s | 35m06s |

Setup plus dependencies totals 13m12s and 25m34s respectively. These are
remote environment intervals, overlapping local work; they are not active
coordination time or additive waste estimates. Published timeout is 45 minutes,
correcting an earlier 30-minute assumption before any retry was taken. Both
checks report zero errors/warnings and two NOTEs from the CI-only Python
sibling checkout entering the R tarball. A targeted build exclusion is a
concrete next packaging candidate; preserve the source parity guard's reach
and verify tarball absence when that change is scoped.

Next merge order is PR247 → PR219/B-186 → PR218/B-155. PR247 reconciles the
historical NEWS site once. Its frozen validated head can feed the next two
integrations while CI runs; merge gates still apply in dependency order.
Measure whether native NEWS-only builds then avoid manual fragment repair,
rather than assuming the baseline change saves time. Batch this measurement
append with a necessary integration instead of a separate documentation push.
The current ready census had no unheld claimable item, with known queue/ref
positive controls; protected handoffs remain held. No whole-run avoidable
percentage is justified by these overlapping observations.

### B-186 reuse measurement and scoped corrections — 2026-10-01

The first local B-186 integration against PR247 `1c08f98` began at 18:33:37 UTC. The native NEWS-only build was blocked before writing by default Pandoc 3.11; selecting the already-installed RStudio Pandoc 3.8.3 took about 59 seconds between that preflight and the successful retry. The matched build took 15.3 seconds. A substantive Codex P2 in PR247 then required its manifest-icon correction, so this uncommitted integration was discarded and restarted at 18:38:09 UTC against corrected head `41bcdce`. That dependency wait and repeat build are separate from NEWS generation. The final matched NEWS-only build took 15.6 seconds; both builds needed zero seconds of manual generated-fragment editing. The four conflicted NEWS/generated paths were reset to PR247 bytes, B-186’s three-line NEWS item was inserted, and native regeneration retained all 588 non-NEWS search records in order. The NEWS search record count stayed 70, with one record now containing B-186. The B-186 source/test blob hashes stayed identical to `28f5ad8`; 164 queue tests and live lint on 318 items passed. These are measured local steps, not a whole-run saving estimate.

Correction to the candidate wording above: CI sibling tarball exclusion is already the scoped, critical-held PR216/B-268, so this run did not open or claim duplicate work. The requested S16 handoff audit remains separate: R209/210/211 and Python72–75 are open; Python72/74 report parity failures. B-199 is already draft Python76 with green checks, held for parity row 38 under a protected handoff. Queue420–425 exist only in open R209, not canonical main. None was claimed or assigned here.


### Next parallel round and adoption of existing count simplification — 2026-10-01

The requested September27 handoff was read and live-checked. Its dependency
order remains useful, but B199 is already protected draft Python76 with green
checks. R209/210/211 and Python72–75 remain open; Python72/74 fail parity.
Items420–425 exist in open209, not canonical main. No duplicate claim, item
number, removal task or tracking framework was created from that old snapshot.

The ready-only census was empty, but it omitted eligible icebox items. Under
existing R15, four existing P2 items with solo repositories, exact retirement
conditions, no blockers and absent claims were promoted: B348/B383/B354/B355.
Three independent identities worked disjoint scopes; root took B355. All four
reproduced their defects before fixing them. Publications: Python86/B348,
R252/B383, R253/B354 and Python87/B355. No provider/removal repair was added.
The next pair B352/B353 was promoted under the same standing grant and Q62's
explicit ruling, with B269's frozen, distinct hunks checked for duplication.

Measured tools and verification, separated from labor attribution:

| Item or step | Observed time/result | Classification |
| --- | --- | --- |
| B354 status/ready/claim/worktree | 1.1s / 4.1s / 5.1s / 0.5s | Coordination tools |
| B354 native NEWS build after PR247 | 15.0s; zero manual fragment repair | Verification/build |
| B383 native NEWS build with PR247 | 15.1s; zero manual fragment repair | Verification/build |
| B348 pickup-to-handoff | about 11m21s, interleaved activities | Elapsed work, not waste |
| B348 full extras/core | 43.45s / 33.27s, overlapping other work | Verification |
| B348 wrong positional `hub done` URL | rejected before write; about38s until corrected `--branch` | Concrete command rework |
| B355 claim/worktree | 5.312s / 0.149s | Coordination tools |
| B355 cached locked environment | 2.31s build +0.405s install; separate core environment | Environment setup |
| B355 focused GREEN/full extras/core | 3.69s /40.54s /34.42s | Verification, overlapping intervals |
| R252 cancelled index attempt | 15m05s, during dependency setup; validator never ran | CI/environment interval; cause unknown |
| R252 one non-model index rerun | 72s total, dependency step31s/test2s; success | Necessary CI repair |
| R252 conflict repair NEWS build | 13.9s | Verification/build |
| R253 additive next-head NEWS build | 18.6s | Verification/build |

Every native build above preserved 588 ordered non-NEWS search records and
all seven source/site favicon pairs. The historical-site reconciliation has
removed manual fragment curation in these observed uses. After R219 merged,
the remaining shared `docs/search.json` still caused real conflicts in252/253;
those required additive integration and new current-head CI. This is a
remaining serialization cost, not a reason to make freshness-only commits.
The scoped installer repair218 does not fix setup-r itself, and one canceled
reference job does not establish generalized runner instability.

R219 merged asfc840429 after all six current checks passed. Its last requested
Codex reviews completed, source/test blobs stayed28f5ad8, and actual Claude
run36887378444 passed execution validation with zero denials/no blockers.
The canonical overhead route now contains219's append. Primary was advanced
and its clean zero-unique auxiliary worktree removed; branches retained.
R247 was likewise archived only after its merged tree and clean state were
verified. Delegation was documentation/defect-fix/added-guard, with no critical
semantic, public, frozen, parity, release or policy choice absorbed.

Actual Claude findings were checked:242's stale roadmap premise was corrected
at196bcf4;218's three-attempt wording was corrected at312d76e. Both earlier
review jobs posted findings but failed on denied tools; a subsequent green
skip is not a completed review. New252/253 actual reviews passed completion
with zero denials and only nits. A separately authorized reviewer-repair chat
owns draft254; its changed workflow hits default-branch validation and has
not produced a genuine new-configuration review. No duplicate repair, broad
permission change, manual model run or secret/settings mutation occurred here.

The smallest next adjustment already existed: Python PR73 drops the repeated
suite-count history from AGENTS.md, preserving core/extras/bare suite gates,
skip explanations and import provenance. It merged as93d07fa under the
routine documentation/overhead-reduction authorization after all six
applicable checks and exact-head Codex review passed, with no human hold.
This run did not open a replacement improvement PR. The earlier partial read
for B355 missed AGENTS's explicit count-update sentence; it was corrected
before merge by a short dated record at8ada95e. That correction and the now
necessary adoption of73 are real rework, not evidence that the old instruction
never existed. Test on B353: retain main's shortened AGENTS unchanged, keep
current counts in its workpad/CI, and observe whether an unrelated count-file
edit or count-conflict repair is still needed. Existing pre73 count edits on
open branches may require one-time integration; no repeat full suite is
needed just to compose a new prose count.

This round supports concrete avoided edits and remaining costs, not an exact
whole-run wasted-time percentage. Research, implementation, requested audit,
verification, environment repair, coordination and passive CI waits overlapped;
agent elapsed times must not be summed as root labor. The next small helper
candidate is an exact `hub done ID --branch ...` hint on its argument error,
but it remains a suggestion rather than collateral source work in an SSSOM PR.

## Next-use observations after the 2026-10-01 merges

R219/B186, R242/B252 factual scope correction, R252/B383 and R253/B354
merged under the routine grant after current required gates and actual
completed review evidence. Py73 removes the redundant AGENTS count record;
Py86/B348 and Py87/B355 subsequently merged after their current gates.
Canonical main now preserves the entire log prefix that previously lived
in the helper branches. Both EML mirror receipts and queue closeouts are
recorded; B348's two float-gap debt passages also carry its landed receipt.
Clean zero-unique worktrees for these finished items were removed with their
branches retained. Critical drafts remain separate.

**Count-log experiment, next two uses:** B353 and B347 required no AGENTS
count update. Their core/extras suites, bare/minimum CI and per-item evidence
remain required. This directly removes one editing/merging step per item;
there is no measured percentage reduction in total task time. B355's one-time
adoption of already merged PR73 also removed its redundant count paragraph.

**Correction to the earlier cancellation attribution:** PR252 run36911071553
attempt1 did not cancel for an unknown cause: its check annotation explicitly
says the job exceeded its configured15-minute timeout. It stopped during
dependency setup before the index assertion. The one allowed retry passed;
the final252 current-head index gate also passed. Another authorized chat
owns PR254's unchanged-assertion timeout/reviewer repair. This run does not
duplicate that repair or manufacture a review event.

**Verification remains useful effort:** independent/local and automatic
review found real YAML tag-guard holes and false refusals before merge. These
are defect discovery, not coordination waste. Py88's two actual P2 comments
were reproduced, and the owner is fixing them on its frozen branch.

**B346/B347 pickup and next adjustment candidate:** R worktree creation0.377s;
Python's first absent-code-field guard missed an optional-column case, which
peer review caught and a RED/GREEN public test fixed. R own33 assertions and
full9082 passes verify its frozen source; eight paired public outcomes agree
for the codes-step rule, preserving each language's independent baselines.
The first R site run refused the unpinned local Pandoc; the existing pinned
path fixed it without installation. A full native site build touched39
unrelated generated formatting outputs. A future narrow reference-topic
build could avoid that regeneration/inspection step while retaining native
rendering, index checks and the existing publication/toolchain guards. This
is a next candidate, not a new tracking framework or implemented feature in
B346. No new routine approval round was needed.

Coordination, implementation, verification, environment repair, requested
audit work and passive waits were interleaved here. Recorded command bounds
and removed steps support the observations above; they do not establish a
whole-run bureaucracy percentage or a causal time-saving estimate.


## Subsequent reuse and bounded review corrections

Observed 2026-10-01, through the B-343 publication. R256/B346, Py88/B353,
Py89/B347, R218/B155 and Py90/B349 have merged under the delegated routine
boundary. Their current CI and completed requested reviews were read before
merge; Py90's in-memory finding was answered with Brett's explicit B349
ruling, which had anticipated that input difference. The existing queue and
backlog carry the landed receipts. Clean zero-unique auxiliary worktrees for
these finished changes were removed after canonical fast-forward; branches
remain. B352's R half is still open, so its pair is not marked done yet.

| Next-use observation | Recorded bounds or removed step | Category |
|---|---|---|
| AGENTS count-log removal on B353, B347, B349 and B386 | Zero count edits in four uses; full/core/extras/minimum evidence remains | Removed coordination edit |
| B349 full extras/core | 47.94s /42.12s on its frozen source; runs overlap other work | Verification |
| B349 synthetic merge on newer Python main | Clean: no integration commit or extra review request | Avoided freshness work |
| B386 peer before full checks | Caught implicit-title fragment leakage; public RED then narrow fix before full legs | Requested audit/implementation |
| B343 scope audit | Removed an initial all-metadata interpretation before publication; fixed-six plus tables stays separate from B177 | Useful audit/corrected scope |
| B343 peer before full checks | Caught whitespace-only direct dictionary bypass; six public RED controls then exact-empty fix | Useful verification/implementation |
| B343 minimum environment | Unchanged base reproduces3 pandas/NumPy warnings-as-errors failures in0.44s; compatible environment-only pin/retest3.64s | Environment repair |
| B343 full extras/core | 49.65s /44.04s on frozen b26045f; no superseded full run | Verification |
| B343 combined date/strict integration gates | 293 tests +102 subtests on current/minimum in4.03s /4.21s; sole real CHANGELOG conflict | Necessary integration/verification |
| B343 publication/attach/handoff | About21:30–21:32Z, interleaved tool calls; not root active labor | Coordination interval |
| R218/255 NEWS serialization | R255 waited for218's merge, then one actual index conflict/build; later valid review issue prevents its merge | Coordination/passive wait |

The focused→frozen peer→full order found a defect before the first full run
on B386 and B343. B349's peer found no further defect; its observable result
is no superseded full run, not proof that a full run was causally saved.
B343's first full legs ran once; a later real CHANGELOG integration preserved
owned function ASTs and received combined focused checks plus fresh remote
full gates. The minimum-version evidence is focused, not a full3.9 suite.

A fresh GraphQL review read on R255 found an unresolved Codex P2 omitted from
an earlier no-findings snapshot: the YAML tag fallback reparses a complete
header per bang. The current source confirms the cost; its merge was held
for a verified repair. The latest green Claude job skipped model execution
because the five-marker budget was exhausted. Earlier actual completed
Claude rounds still count as their own reviews; the skip is not a new one.
This source review is useful defect discovery, not policy bureaucracy.

Two small habits now apply on the next item: include exact interpreter paths
in the frozen-source message, and use the canonical queue parser's documented
Item.get values instead of guessing a second parser/API. Root's absent .venv
probe and mistaken Item.fields/string-boolean assumptions were instrument
rework, not HUB bureaucracy. B341 is the next disjoint use of the interpreter
path habit. No new helper, policy or tracking system is introduced.

A post-merge hub reconcile was unnecessary for closure: it printed129 held
handoffs and did not release them merely because work had merged. The queue's
done mark is the eligibility owner. Avoid repeating reconcile as a completion
step unless actual expiry cleanup is needed; no client semantics changed.

The supported HTML reader fix B386 is tested in draft Py91. Its existing
numbered row62 description would be factually stale after the port, so HUB
class5 requires Brett's approval for the exact paired sentence correction.
That concrete approval is still pending; no duplicate request or dependent
row edit was made. Literal corrections to an existing numbered description
are a future simplification candidate, not authority this run has invented.
A targeted native reference-topic build also remains a suggestion until a
single-topic change can evaluate it without collateral tooling work.

Intervals above overlap implementation, requested audit, verification,
environment repair and passive waits. They support four removed count edits,
no unnecessary freshness merge on B349, and defects caught before full runs.
They do not support an exact whole-run percentage of wasted time. Required
critical approvals are separate from redundant coordination; work by
concurrent agents is not added together as root labor.


**R234 integration observation:** its four actual NEWS/site conflicts were
resolved against main052279b with the one B394 entry retained. The stronger
lint found that B348's already-correct float-gap receipt heading did not use
the accepted landed-record grammar; its existing receipt was rewritten in
that grammar without changing the ruling, and both debt passages were read.
The166 queue tests and318-item lint/check pass. Native NEWS output preserves
588 ordered non-NEWS records and all five discovered favicon/manifest assets.
Root incorrectly assumed a unique Internal NEWS heading and guessed asset
names/search path types in ad-hoc probes. One premature build after the failed
heading assertion required a second build. These are implementation/instrument
rework; sequential tool operations now stop on each failed result. They are
not evidence that required HUB or site validation is wasted.

**Next habit use:** B341's frozen message included its exact current/minimum
interpreter paths. The root peer reached the intended editable worktree on its
first call and passed seven sidecar controls. This removes the earlier path
discovery misstep in this use; no aggregate time-saving percentage is inferred.


## Reader review corrections and next-use checks — 2026-10-01

R257/Py92 review exposed a real constraint-list regression: the reviewed
producer emits `; ` lists, while the proposed single-IRI check rejected them.
Narrow paired corrections preserve outer whitespace, reject empty list parts,
and recognize later REVIEW components once in validation and the review
console. Independent public validation matrices passed 18 controls per
language on frozen source. R257 also fixes parsed quoted-LF optional table
IRIs disappearing through trimws; raw CSV normalization remains its existing
owner. This is implementation and useful review work, not claim bureaucracy.

R255's per-bang full-header reparsing was a valid Codex performance finding.
The bounded native-parser repair first passed focused tests but peer probes
found quoted-punctuation and percent-encoded tag bypasses. Both received
public RED controls and narrow fixes. At source SHA2569009b0ae, independent
80-bang plain/flow/multiline/block reader controls made two native loads; an
actual tag still refused. Later-document tagged controls also passed without
a new document splitter. Three interrupted strict-check attempts are
verification rework; starting a check before the final peer freeze did not
reduce overhead. The next analogous reader, R340, applies parser/count probes
before full gates rather than copying a partly verified scanner.

Py93's actual completed Codex review found ComposerError precedence hiding
unknown tags in multi-document sidecars. The published source reproduced two
public failures. A parser-event check on the malformed fallback preserves
known-tag, quoted/block text and untagged malformed behavior. Independent
peer probes passed ten public writer controls on b81b210/9658315; five
refusals left the sidecar and both closure outputs untouched. Its full gates
remain pending. This is a substantive fix, so no extra model review is asked
for merely to refresh the reviewer after the fix.

Exact interpreter paths were reused successfully for the Py93 peer, with no
interpreter-discovery round. The shortened AGENTS count history still required
zero edits on this next item, while core/extras/minimum and import provenance
remain recorded. Root's wrong module-path guesses, wrong-repository search
and an invalid empty R argument name in a temporary peer script were
instrument rework; they did not demonstrate package defects.

R234's latest Claude summary was only nits, but its run failed on a denied git
call. The PR body and workpad retain that failure; the PR is held, and a
one-off retry decision is pending under HUB's narrower retry rule. No
workflow permission, review budget or completion guard was weakened. This
question is required coordination under current policy, separate from
redundant approval asks. The historical S16 handoff remains a dependency aid:
Py76 then Py72 then R210 then Py74; Py73 has merged and R209 remains open.
No duplicate removal work, queue items or claims were made from that note.

These observations count removed edits, native parse calls and concrete
review findings. Concurrent work and passive CI waits still prevent a
defensible whole-run wasted-time percentage. This append is retained in the
R234 worktree and will publish with its next necessary submission; its review
hold is already durable in the PR body, so this measurement does not itself
restart CI or a paid review.

### Next uses and necessary integrations — 2026-10-01, about22:34–23:04 UTC

Py93/B341 merged as3aea9c1 at22:34:34Z after its completed Codex finding was
fixed and six applicable CI jobs passed. R238/B396 merged as670c45ca at
22:48:16Z after actual Claude execution36935672853 completed with nits only,
zero denials and green required CI. Its queue closeout isfae965f. These are
delegated ports/guard additions, with no critical semantic or numbered parity
row choice. Both merges have PR receipts; no repeat publication approval.

R340/B340 final full and strict gates ran sequentially on frozen source:
9262 assertions,zero failures/errors,38 existing warnings,5 existing skips
(91.696s); strict zero errors/warnings/notes(129.375s). The first full command
used a temporary external --file runner and broke the existing ThemeA source
root instrument:95.924s was a failed verification attempt, not a source defect.
Standard affected controls3082 assertions/16.881s and the full rerun passed
on unchanged source. This rework is environment/instrument repair. Its
shorter final durations than the earlier overlapping gates do not isolate
a causal scheduling benefit. Keep expensive full gates staggered for the
next B223 use, with focused/implementation work continuing concurrently.

B223 reused status/setup hints, acquired its distinct claim and isolated three
EML/KNB sidecar callsites. It defers NEWS generation until its actual R340
prerequisite lands. Frozen callsites have independent peer evidence; a
disposable helper overlay passes five controls, while the actual branch
remains correctly RED until integration. Zero early generated-file edits
means no generated conflict to resolve yet; actual integration is the next
measurement. No helper copy or second framework was created.

R255's next required integration had one real search-index conflict. One
native16.0s build retained588 ordered non-NEWS records and five assets; source
and tests stayed frozen. R257 is deliberately held until R255 lands, testing
whether serialized generated-file integration avoids another superseded build.
Py92's real CHANGELOG conflict afterPy93 required one additive merge, not a
freshness-only commit. Owned module ASTs stayed unchanged; current focused
three-file209/minimum two-file163 controls pass. No repeated full/model gate.

R234's real integration afterR238 has four NEWS/site conflicts, resolved by
retaining both source entries and one native pinned build. Combined queue
168 tests,318-item lint,OKF capture and68/64 index controls pass. Five assets
and588 ordered non-NEWS records remain identical to main. Its existing failed
Claude execution remains visible; a new head is required for source
integration, not created to reroll a model. No old-job retry or permission
expansion was performed. The pending one-off retry decision remains separate
unless a valid later execution actually satisfies the review gate.

Root's integration instrument first compared complete ASTs even though incoming
B396 intentionally updated a docstring, then assumed unchanged historical
method names and an invented added-test count. Those failed proof assumptions
were corrected using the actual merge base: owned executable function and
all owned methods match, and both incoming added test methods match main.
This is requested audit/instrument rework, not implementation or queue overhead.
The next proof should derive incoming additions from the merge base before
asserting a count. The explicit interpreter-path habit and removed AGENTS
count-log edits still required zero discovery rounds/count edits on B341.

No whole-run wasted-time percentage is inferred from these overlapping
intervals. Coordination, implementation, verification, environment repair,
requested audit and passive waits remain distinct; tool/runtime durations and
concrete avoided actions are the evidence currently available.

Current dependency-based review/merge order: Py92/B343 merged asfeb724a at
23:03:25Z after six current CI checks and the last requested Codex review
completed with no findings. R255/B352 is next once its R check completes;
R257/B342 then receives one actual landed-main integration. R258/B340's
first actual Claude run is in progress while B223 waits locally for its
helper. R234/B394 receives its necessary combined guard integration but
remains held until actual review completion. The critical S16 train remains
Py76/B199 → Py72/B327 → R210 → Py74, with R209's unmerged queue work preserved.

R255 merged13460ed at23:09:46Z after six current CI checks and resolved bot
findings, under the defect/ruled-port delegated class. B352/B353 done marks
and the same verified non-numbered landing record in both existing debt
passages were pushed asccaa917. Py88's actual merge7a2305bd was read again
before that receipt; no parity row or release changed. R257 now receives
one actual integration against this landing, with tested source frozen.

R234's legitimate new head68c84fe triggered one automatic round, not a
manual retry: it again posted only nits but run36938756509 failed on one
denied Bash:git call. This is review-execution overhead, separate from
source quality. Both failures remain recorded; a nits marker cannot clear
execution, and no permissions or completion rule were changed. Consolidate
any later necessary source integration after the current merge batch to
avoid separate source-identical submissions. No pending question was repeated.

Merged R396, Py341 and Py343 auxiliary worktrees were removed/pruned only
after clean/exact-published/zero-unique-work checks and environment-use review;
branches were retained and canonical checkouts fast-forwarded. This is
required cleanup coordination, not an implementation or verification gate.

A small scheduler improvement was applied once to the existing heartbeat:
its prompt now points to live queue/workpads/HUB for changing heads and
review order. It preserves standing authority, pending-decision handling,
model-removal scope, cleanup/verification rules, measurement categories and
quiet notification intent. The prompt shrank from602 to336 whitespace-delimited
words (44.2% fewer), and4311 to2515 characters; these are text measurements,
not model-token or time savings. Next heartbeat is the evaluation: confirm
it resumes the actual claims/holds without restoring stale branch heads.
No schedule, new automation, policy or tracking framework was introduced.

B384 reached tested draftR259 on the next independent claim. Its public
multiline false-rejection case is RED→GREEN; leading-token guards remain.
HUBclass6 still reserves the narrowed validator for Brett, so one concrete
merge/ready approval question was asked only after peer/full/strict/native
site verification and publication. This is required approval under current
policy. A possible later small policy improvement is to define whether an
exact false-rejection repair under unchanged declared scope can qualify as
routine; no such exception is assumed or implemented in this run.
The literal Rregex mutation and before/after public behavior are reviewable
in the existing PR; no parallel approval tracker was added.

R258's actual successful Claude execution36938265310 found an Important
unknown-tag bypass after implicit document end plus a percent-TAG directive.
The frozen public source reproduced1reader+4writer failures; known-core
binding acceptance remains a positive control. The owner is repairing this
surviving semantic-closure path, with independent peer before newfull/strict
on changed source. A green earlier suite/peer did not cover this valid
directive placement. Repeating gates here verifies a concrete changed-source
risk, unlike a source-identical freshness run. B223 keeps waiting locally
and will reuse the fixed owner when it lands.

### Batch checkpoint, about23:26–23:35 UTC

- R257/B342 mergedc09a76b at23:25:57Z after six current CI checks, completed
  requested Codex reviews/resolved findings and earlier verified Claude nits.
  Paired Py92/feb724a receipts and done marks are4efc54c; both existing debt
  passages have the same verified non-numbered port receipt. B342 auxiliary
  was removed only after clean/exactpublished/zero-unique/envpin checks.
- R255→R257 serialized integration completed with one14.0s native build and
  no repeated full gate; all owned source/test hashes stayed frozen. There
  was still one search-index conflict: serialization did not remove every
  conflict, and no counterfactual time saving is claimed.
- B344/B345 blockers are nowdone and both were promoted separately under
  R15, then routed to independent R/Python owners. B223's sole live claim
  prevents that same owner claiming another item while awaiting its helper.
  A genuine new Python agent was allocated; no token was changed to evade
  the per-agent cap. That adds startup/policy-read overhead. Next pickup
  habit: inspect actual source prerequisites before acquiring a formally
  eligible item whose helper is still in an open PR; prefer an item that can
  reach actual-branch GREEN. No claimability/policy field was altered.
- R340's first directive review repair passed its bounded peer but a further
  owner probe found quoted percent-TAG text with a hash-leading closing line
  causing false acceptance. The just-finished full result was superseded;
  strict/publication did not start. Preserve this as verification rework and
  a coverage gap, not a completed fix. The owner is testing a bounded native
  per-document proof before another source freeze. No quote-state parser or
  conservative known-core rejection is authorized as a shortcut.

Future batch appends will keep timings/outcomes and exceptions here, with
detailed source/tests in the existing item workpads. Repeating every live CI
snapshot or command in both places adds requested-audit work without making
the result clearer. No past measurements are discarded.

### Next bounded use, about23:39–23:47 UTC

- Brett's requested September27 handoff read still supplies the critical
  train Py76/B199 → Py72/B327 → R210 → Py74. Live reads confirm those four
  remain open and Py73 is merged; R209's queue additions remain unmerged.
  This was requested continuity audit, not a reason to duplicate the items
  or absorb the other S16 session's work. Historical statuses are not reused
  as current planning state.
- R340's final native directive discriminator preserves quote/comment bytes
  by replacing only the directive keyword in bounded document segments.
  Root's exact-source replay passed six native-valid/public controls; the
  independent reader86 and YAML-evaluation guard51 assertions pass. The
  forty-document byte-visit bound pins linear segment work. Final full and
  strict gates follow the peer; the superseded9276-pass/96.444s full remains
  verification rework, not evidence for the final source.
- R259's actual Claude36939638008 completed with zero denied tool calls and
  nits only; all six applicable checks are green. The existing concrete
  validator ready/merge decision stays pending. The valid nit that B360 is
  already done corrects a stale description, and the B385 fixture regeneration
  is a required same-stream companion; no unrelated non-ASCII phrase work
  is added to this PR.
- R344 and Py345 use separate owners and task worktrees, with focused gates
  while R340 owns the expensive gate slot. Each found raw-value trimming
  could bypass the ruled marker boundary; both are pinning public consumers
  before a source freeze. Next peer briefs name exact hashes and interpreter
  paths, avoiding a second environment-discovery pass. No whole-run wasted
  percentage or causal runtime saving is inferred from overlapping work.

### Representation preflight and next pickup, about23:48–00:10 UTC

- The R/Python marker peer found XML attributes serialize a literal tab as
  `&#9;`. Both consumers now examine the original parsed text/attributes as
  well as the retained serialized scan. Actual EML/ORE controls demonstrated
  RED then GREEN; independent final-source peers passed. R344's earlier
  full99.57s + strict125.22s are superseded:224.79s verification rework from
  a representation seam missed before those gates. Next small habit: check
  both parsed values and serialized bytes before expensive suites. B350 is
  its next use; no new test framework or policy is introduced.
- Py345 also fixed a new helper's Series positional access after root's
  nonzero-index control failed. C and reachable C.UTF-8 subprocess tests pass
  on minimum/current interpreters. Its global CSV shim still trims quoted
  leading LF, an existing row23 boundary; the PR describes raw value, written
  bytes, shim result and strict result separately rather than claiming
  end-to-end LF parity or repairing the global parser in this item.
- Py345's full runs are honestly failed: minimum3.9 core8failed/1778passed
  in37.98s (unsupported `Path.write_text(newline=...)` fixture calls), current
  3.14 extras6failed/1947passed in42.45s and genuine core6failed/1785passed
  in38.36s (HTTPError cleanup ResourceWarning counted beside the intended
  ICES warning). Bounded unchanged-main reproductions confirm the same8/6
  failures. No skip/suppression or unrelated repair was added. Py94 is a
  held critical draft; supported CI supplies its own full gates without a
  fourth local full run just to obtain green.
- R340's final source passed9294 full assertions in96.743s and strict0/0/0
  in126.479s; the canonical mirror guard ran separately without its sibling
  skip. Necessary integration cada9b6 preserved all five owned source/test
  blobs and588 ordered non-NEWS records, with one native NEWS build. Two
  false preparation assertions and an interrupted premature build remain
  environment/instrument repair, not product verification or savings.
- B350 was promoted inffe46ad under the literal R15 grant, then claimed by
  the B340 owner after its handoff. Setup0.514s reuses that stable identity;
  no cap evasion or new tracking system. Its first read already identified
  canonical writer/reader seams (propagation, quoted TSV, empty pruned prefix
  maps) before source edits. The exact applicable schema and round-trip
  controls are being checked before full gates; its row11 amendment stays
  critical draft and the version remains Brett's.
- Seven agent-created recent PR attachments were absent from this root
  task's attachment inventory despite earlier child success reports. Root
  attached them explicitly and attached Py94. Next tool habit: return only
  the required attachment URLs/status rather than dumping the entire saved
  inventory. This corrects observable routing, with no measured time or
  token-saving claim.

Detailed failures, exact freezes and commands remain in the item workpads.
The batch log distinguishes coordination, implementation, verification,
environment repair, requested audit and passive waits; concurrent elapsed
times still do not identify a whole-run percentage of wasted time.

### Review fixes and approval precision, about00:11–00:47 UTC

- R258's second actual review completed with zero denied tools and found a
  real mirror gap: Python's native undefined-tag-handle parse error silently
  selects default mapping. Public absent/existing-output probes confirmed
  changes to both exports and the sidecar. Head733e170 adds R refusal pins,
  honest PR wording and proposed B429; the new item travels through this PR,
  not a direct-main push. Three standalone namespace scans took about15s;
  repeated reservation checks are coordination, not product verification.
- R258's next model body reports only nits, but its verifier failed on one
  denied Bash:gh call. All functional checks pass. The exact-head one-off
  retry question remains pending; no readiness event or source-identical
  push is used as a substitute for that answer. Model prose and completed
  review remain separate evidence.
- R260's actual review found a valid narrative regression. Both marker
  owners reproduced ordinary narrative failures, restored the inherited
  case-sensitive literal document fallback, and retained decoded attribute
  checks. Root's R peer passed on the frozen source before new heavy gates.
  Py94's source-fix d752071 has508 focused passes on each tested interpreter;
  final-head supported3.11 CI is green. Prior-head full compatibility failures
  remain labeled as such, without another local full run to obtain green.
- The wrong-owner R216 brief was caught before edits. Correct-owner R220
  integration preserved its source/test blobs, used one native NEWS build
  (15.49s), and passed focused checks. Its new actual Claude review completed
  with zero denied calls and one queue-wording nit; R check is still running.
  No additional Codex request is needed for unchanged owned source.
- B350's representation preflight found and repaired omitted preprocessing
  CURIE declarations before its first heavy gate. The corrected391-assertion
  focused snapshot passes. An independent frozen-source peer found no further
  concrete defect in the implemented clauses. Root accidentally requested a
  duplicate peer, canceled before tool calls; that dispatch is coordination
  rework, with no claimed avoided-test saving.
- A subsequent exact-spec read distinguished mandatory paired operations
  from recommended automatic parser propagation. Root withdrew an overbroad
  public-object approval question and is investigating an internal effective
  view. This is avoidable approval/research rework, not a required redesign.
  The genuinely ambiguous legacy quote-decoding choice remains pending.

Next small adjustment: before asking for an API decision, distinguish a
standard's mandatory semantics from its recommended implementation route and
check whether an internal view preserves the current contract. Detailed item
proof stays in workpads; this compact batch is the overhead record. These
overlapping activities still do not support a whole-run wasted percentage.

### Small housekeeping batch and next preflight, about00:48–01:15 UTC

PR220 mergedf727aee under routine-defect delegation after six green checks,
actual completed Claude review and the completed last-requested Codex reviews.
Existing B133 closed in572f6a7 with the setup-purl suggestion corrected. Its
clean auxiliary had zero unique commits and was removed; its branch remains.

PR216's original handoff is integrated and ready at16d835a, with five focused
build assertions and exact exclusion bytes preserved. Readiness caused one
superseded Claude run to cancel; only the later completed actual run can supply
review coverage. PR234's local actual-main integration retains168 offline
passes and the appended log, but publication is held for the routine batch's
base to settle. Independent reviewed scopes remain separate. This reduces
potential publication churn, not a measured CI/token saving. Its native build
was prepared before the batch decision and may need repeating; failed search
record/path assumptions are instrument repair, not product verification.

The marker review's next genuine finding is narrative text starting `Review:`.
The broad decoded-node scan confuses free text with an IRI-bearing value. Both
owners are inventorying actual emitted schema positions before the next peer
and heavy gates. The earlier successful full/strict run is superseded for this
finding; no synthetic arbitrary-attribute test is accepted as real IRI coverage.

B350's exact-model distinction allowed internal paired operations to proceed
without a public-parser redesign question. Focused preflight then caught enum/
string metadata incorrectly inheriting the old table profile's URI checks.
The new internal inheritance path will preserve that prior accepted behavior;
the separate old table-range defect stays in B269. This is the next use of the
mandatory-semantics/public-route distinction, with no causal percentage claim.

### Batch landing and bounded peers, about01:16–01:25 UTC

- PR216 merged3bec752 at01:17:57 UTC after six applicable latest green checks,
  actual Claude36949087168 with zero denied tools/nits, and completed first
  Codex code/security reviews without findings. Its superseded same-head
  cancelled review supplies no coverage. CI R4.6.1 reached all five source-build
  assertions with the real mirror checkout and returned Status: OK. B268
  closed5ab308a; clean0-unique auxiliary removed, branch retained.
- PR234 now integrates the settled actual base, carrying accumulated log
  checkpoints in one necessary publication. Its final native build15.786s
  preserves588 ordered non-NEWS records, with168 offline queue tests in0.405s
  and both owned guard blobs unchanged. The earlier locally prepared native
  build must be counted as rework. Keeping independent PR scopes avoids
  adding unrelated code to a PR under review or disrupting reviewed history.
- Root's B350 public peer passed internal paired operations, multivalued YAML
  bytes plus the existing pipe-valued read projection, conflict/no-overwrite,
  source metadata and actual manifest hashes. A first probe expected a vector
  where the existing parser returns a scalar: instrument repair, not a product
  defect. Source unchanged; quote-dependent gates/conformance stay held.
- Root's marker peer caught leading ASCII whitespace before the first
  schemaLocation URI hiding a marker in the second. Both owners fixed it before
  new heavy gates; root R focused peer passed and Python's75 contract tests
  passed in1.22s with one inherited warning. R now runs its one final frozen
  full/strict pair; Python uses supported CI for broad gates.
- The original owner resumed existing Py83 guide companion, without a new
  claim. Source guide/nav hashes survive main integration; native quartodoc
  build1.89s and64-page render18.38s pass. Only its five scoped files differ.
  It is ready for its first requested review; green checks alone do not supply
  an actual review. B223 remains parked on its real dependency/approval hold.


### Final routine batch and canonical log route, about01:28–01:39 UTC

- PR234 merged as c1db3f1 at01:36:51 UTC after all six exact-head checks
  passed. Actual Claude36950838573 completed on6c145ff with zero denied tools
  and only nits; the last requested Codex code/security reviews on043ee07
  completed without findings, and owned executable logic/tests survived the
  integrations. Earlier denied-tool runs remain failed; no old run was retried.
- Py83 merged as386d721 at01:34:41 UTC after its completed first Codex review's
  valid default-offline-schema finding was fixed in a741321. Source inspection,
  the rendered guide and all six current-head checks agree. The sole bot thread
  was answered and resolved; no extra model review refreshed the reviewed head.
- Both clean canonical checkouts fast-forwarded. Completed clean auxiliary
  checkouts had zero unique commits and were removed; branches remain. PR234's
  complete log matched the canonical copy byte-for-byte before cleanup.
- R260's final frozen full/strict pair passed once (95.80s/124.16s). Actual
  Claude36951110809 completed ondd8808e with zero denied tools, zero important
  findings and four nits. A Pandoc download HTTP500 was repaired by one
  unchanged-head infrastructure retry, without a source or model reroll.
  Py94's supported3.11 exact-head gates pass. Both marker drafts remain critical.

Next small adjustment: resumptions read the latest dated log section and only
load older sections for a specific question. The complete durable history stays
intact. PR234's body now summarizes current changes and gates and routes detailed
chronology to its existing workpad/log. This reduces duplicated text; the next
wake will test the read scope. No causal time or token saving is claimed.

Root's overbroad tool-description/diff dump and unsupported gh diff path argument
were instrument rework. Direct status-only reads and guarded sequential writes
are sufficient for this batch. Queue audits found no free independent eligible
item: held work, genuine prerequisites and pending critical decisions remain.
Coordination, requested audit, verification, environment repair and passive CI
waits overlap; they still do not establish a whole-run wasted-time percentage.
