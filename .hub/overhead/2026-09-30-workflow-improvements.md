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
