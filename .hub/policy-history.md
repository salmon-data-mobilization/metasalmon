# HUB.md policy history

**Nothing in this file is operative.** It grants nothing, forbids nothing and
defines nothing, and no agent acts on it.

**Any rule wording quoted here is what `HUB.md` said at the time.** The current
rule is whatever `HUB.md` says now, and where the two differ, `HUB.md` is right.

**It exists so that the reasons and lessons are kept without every agent paying
to read them.** Every dispatched agent reads `HUB.md` in full before doing
anything, so its dated history, measurements, reversals and rationale were
moved here on 2026-09-24, from `HUB.md` as of commit `b2ce716`. The text is
verbatim and organised under the `HUB.md` section it came from. Where a value or
paragraph was only shortened, the whole original is kept here, so some of the
wording below also survives, shortened, in `HUB.md`.

## Front matter

Each block is the original YAML of a value that was shortened, with its
key. The shortened value is in `HUB.md`. Values that were not shortened are
not listed. The six claim-ref rows, which repeated one `target` string, now
share it through a YAML anchor, so their parsed values are unchanged and they
are not listed either.

### `constants_live_in`

```yaml
constants_live_in: >-
  queue/config.yaml, and nowhere else. This file carried its own copy of the
  lease hours, the heartbeat interval, the reclaim grace and the concurrency
  cap until 2026-09-09, when the cap was measured saying one here and two
  there while the client read only the configuration. A policy file holding a
  second copy of a constant nothing reads is the exact defect this design was
  built to remove, so the copies were deleted rather than corrected. Cite a
  constant by its configuration key; never restate its value here. The literal
  value of claim_ref_prefix was found in nine places in this file on 2026-09-10,
  while this key said not to restate one, and eight of them were replaced by the
  key name. The ninth is the fetch refspec under "Claiming", which a reader has
  to be able to run and which cannot cite a key; it is labelled an example on
  the spot and says the configuration wins.
```

### `queue.ready_is_set_by`

```yaml
  ready_is_set_by: >-
    a commit on the default branch, made by Brett or by an agent acting on an
    authorization Brett gave in chat. An agent's promotion commit must name that
    authorization; a promotion that cannot cite one is a defect.
    Changed 2026-09-10: this used to be a wall an agent could not climb, because
    it could not push to the default branch. It is now an audit trail. The
    property that an agent cannot invent its own work is no longer structural,
    and saying so is the point of this note.
```

### `states`: `ready`

```yaml
  - name: ready
    claimable: true
    means: >-
      Promoted: by Brett, or by an agent on an authorization he gave in chat.
      The only state a claim may be taken from. Widened 2026-09-23: this read
      "Promoted by Brett", which stopped being the only way on 2026-09-10
      (ruling R15) and stopped being the only kind of authorization when his
      standing promotion grant, quoted on the register's promotion row, was
      given.
```

### `states`: `done`

```yaml
  - name: done
    claimable: false
    means: >-
      Merged. By Brett, or by an agent under the review-delegation rule in
      "Which pull requests need Brett". The item stays as a record and is never
      re-opened in place. Widened 2026-09-16: this read "Brett merged it", which
      stopped being the only way an item reaches done on the day agents were
      given the merge.
```

### `claim.record_note`

```yaml
  record_note: >-
    These two describe the record the client writes and the client hard-codes
    them, so scripts/hub is the authority and wins if they ever disagree. They
    are restated here because a reader of the lock history needs them. On
    2026-09-09 they did disagree, in both fields at once: this file said
    claim.yml and heartbeat where the client writes claim.yaml and beat. That
    is why this note exists and why these are the only two client constants
    this file repeats.
```

### `writes.scope_note`

```yaml
  scope_note: >-
    What this register governs: writes made by an agent executing the hub
    protocol in this file against a claimed queue item. Inside that scope it is
    the only enumeration of what such an agent may write without asking, and an
    operation it does not list is not permitted there, whatever its resemblance
    to one that is. Outside that scope it governs nothing. Ordinary repository
    work, meaning everything an agent does that is not the hub protocol acting
    on a claim, is governed by Brett's global agent instructions and by the
    repository it happens in; this register neither widens nor narrows that.
    Scoped 2026-09-10, because the unscoped wording read literally forbade every
    write an agent makes anywhere unless a hub row named it, which is not what
    the register was built to say and is not a rule anyone agreed to. Retires
    with the register.
```

### `writes.permitted`: push an expiry release commit for an abandoned claim

```yaml
    - operation: push an expiry release commit for an abandoned claim
      why_it_is_listed: >-
        This row was missing until 2026-09-09 and reconcile shipped without it,
        so running the client's own command tripped the self-suspension clause
        below. That is the failure this register exists to make visible, found
        by an audit that read the code against the register rather than reading
        the register alone. A register is only a boundary if the code is
        checked against it in both directions.
```

### `writes.permitted`: push commits to a work branch

```yaml
    - operation: push commits to a work branch
      condition: >-
        Solo participation, the same test the draft pull request row applies and
        applied the same way, by asking who has ever participated rather than by
        reading the collaborator list. The repositories that passed on
        2026-09-10 are in the table under the standing authorization, and three
        named members failed it. In a member repository anyone else has worked
        in this row does not apply at all: prepare the work in the worktree,
        show Brett the diff and the pull request text in chat, and wait for him
        to say yes before pushing anything. When participation cannot be
        determined the repository is shared. Added 2026-09-10, resolving a
        contradiction inside the standing authorization about whether a branch
        push into a shared repository needed an ask; the note under that
        authorization says why it resolved against the push.
      enforced_by: >-
        hub done, which accepts exactly agent/<queue-id>/<token> for --branch
        and exits 3 on anything else. A client that will hand off a branch the
        register does not permit breaks the carve-out by accident, and the
        accident is invisible because the push already succeeded.
```

### `writes.permitted`: redirect every claim-ref push to a throwaway locks repository, by setting HUB_LOCKS_URL

```yaml
    - operation: redirect every claim-ref push to a throwaway locks repository, by setting HUB_LOCKS_URL
      condition: >-
        Honoured only while locks_repo in queue/config.yaml is still the
        placeholder. Once locks_repo names a real repository the variable is
        refused rather than obeyed, and every command that pushes exits 3 while
        it is set. It used to win unconditionally, which meant an environment
        variable could silently point every claim, heartbeat, release and
        handoff at any URL at all while the configuration named the real
        repository.
      visibility: >-
        Every command that pushes prints the effective locks repository URL and
        where that URL came from, before it pushes. A push sent to the wrong
        remote is the one failure in this protocol that raises no error, so the
        printed line is the only evidence of it in a run.
```

### `writes.permitted`: open one draft pull request for a handed-back item

```yaml
    - operation: open one draft pull request for a handed-back item
      condition: >-
        Solo participation, tested as the standing authorization below tests it
        and not by the collaborator list. The repositories that passed on
        2026-09-10 are in the table there, and three named members failed it.
        In a repository anyone else has worked in this row does not apply at
        all, and neither does the work-branch row above: prepare the diff, show
        Brett that diff and the pull request text in chat, and wait for him to
        say yes before anything is pushed. When participation cannot be
        determined the repository is shared.
      shape: >-
        labelled agent-run, body naming the queue id, from the
        agent/<queue-id>/<token> branch already pushed. Opened as a draft, and
        never a second one for the same item. Narrowed 2026-09-16: this read
        "draft only ... Never marked ready for review, never merged, ... and
        never a reply to a review comment on it", and the rows below now grant
        all three for the delegated classes. It stays a draft, unmerged and
        unanswered, when the change falls in a class "Which pull requests need
        Brett" reserves to him, which is what still makes a draft the
        conservative default rather than a formality.
      enforced_by: >-
        nothing mechanical. This is the one permitted operation with no client
        check behind it, because the client makes no API call; it is a rule an
        agent follows, and a breach is visible because the pull request carries
        an author and a timestamp.
      granted: >-
        2026-09-10, reversing the 2026-09-09 refusal. Inside Brett's own
        repositories a pull request is him talking to himself; the standing rule
        exists to stop an agent addressing other people as him.
```

### `writes.permitted`: push a README to main in the locks repository

```yaml
    - operation: push a README to main in the locks repository
      why_it_is_permitted: >-
        A locks repository needs a default branch that is not a claim. GitHub
        makes the first branch pushed to an empty repository the default, and a
        default branch cannot be deleted, so without a main the first claim ever
        taken would be permanent and would be the repository's HEAD. Learned by
        running it on 2026-09-10, before any real claim existed.
      why_it_is_not_a_local_grant: >-
        Asked and answered 2026-09-10, because this row is the one permitted
        operation that writes to a default branch in a repository other than
        this one, and that shape looks like this file granting itself authority
        over a different repository. It does not. Brett's own standing
        authorization, quoted below in his words, names this push explicitly, so
        it rests on nothing this file added; and the global rule's
        small-mechanical carve-out for a default branch covers it independently,
        in a repository that is his alone. A pull request is not an alternative
        here, because an empty repository has no base branch to open one
        against. Nothing in this file widens the global rule, so there is also
        no widening list for this row to be misfiled into; the section below
        says why the three operations that once sat in one were never widenings
        either.
```

### `writes.permitted`: merge a pull request in this repository

```yaml
    - operation: merge a pull request in this repository
      excludes: >-
        the agent's own hand-back draft pull request, which stays draft and
        unmerged by the row above. Hand-back is the point where Brett looks, so
        an agent merging its own hand-back would remove the only review the
        arrangement has. Narrowed 2026-09-16: this exclusion now yields to the
        three rows below, which move the looking from Brett to Codex for the
        classes of change "Which pull requests need Brett" says he does not need
        to see. The reasoning it states is still why he sees the rest.
      enforced_by: >-
        nothing mechanical. Green is read off the checks before the merge, not
        assumed from a clean local run, and the distinction matters here because
        CI runs a different R than this machine does.
      granted: >-
        2026-09-10 (ruling R15), under the global rule that an agent may merge a
        green pull request where Brett works alone. Nobody else works in this
        repository, so a merge here reaches no one.
```

### `writes.permitted`: mark a pull request ready for review

```yaml
    - operation: mark a pull request ready for review
      shape: >-
        the draft-to-ready conversion and nothing else. It starts the Codex
        review, which is the whole reason it is permitted, and it is the step a
        merge is impossible without: GitHub refuses to merge a draft with a 405,
        so the merge rows above were unexecutable by an agent until this row
        existed. Never on a pull request an agent did not open, and never as a
        way to request a person's attention.
      enforced_by: >-
        nothing mechanical. The conversion is reversible, which is why this is
        the least costly of the three rows added on 2026-09-16.
      granted: >-
        2026-09-16 (ruling R16), in the instruction "Convert all to 'ready' to
        trigger codex reviews."
```

### `writes.permitted`: reply to a review comment on a pull request

```yaml
    - operation: reply to a review comment on a pull request
      shape: >-
        a reply that answers the finding, and resolving the thread once it is
        answered. A finding is either fixed in a push or answered with the
        evidence that it is not a defect; "acknowledged" is neither. Never a
        reply that disputes a finding without evidence, and never resolving a
        thread whose finding was not addressed, which is the one way this row
        could be used to hide review rather than to serve it.
      excludes: >-
        a review left by a person. Where a human reviewer asks for something
        larger than a local change, the proposal goes to Brett and the reply
        waits on him, exactly as before. This row moves Codex out of the denial,
        not people.
      enforced_by: >-
        nothing mechanical, and this is the row with the most room to go wrong:
        an agent that answers a finding badly and resolves the thread has
        removed a signal rather than acted on it. The record is the thread, so a
        wrong answer stays legible.
      granted: >-
        2026-09-16 (ruling R16), in the instruction "I want you to respond to
        codex reviews in MRs now and moving forwards."
```

### `writes.permitted`: merge an approved pull request in a solo member repository

```yaml
    - operation: merge an approved pull request in a solo member repository
      shape: >-
        an ordinary merge, after the two conditions above are read rather than
        assumed. This row is what makes "Which pull requests need Brett" below
        operative: a change in the delegated classes merges on green CI plus a
        completed Codex review, and a change in the classes that need him does
        not merge without him whatever its checks say.
      enforced_by: >-
        nothing mechanical, and the asymmetry is deliberate: an agent unsure
        which side of the boundary a change falls on escalates, because a merge
        is hard to unwind and a question costs a message.
      granted: >-
        2026-09-16 (ruling R16), in the instruction "I don't want me having to
        review the merge requests to be the bottleneck. We need a system where
        only consequential or impactful MRs require my review." The named
        approvals in that same message (metasalmonpy #28; metasalmon #116, #117,
        #118, #119, #120, #121, #122, #123) are per-pull-request authorizations
        under this row and are not themselves the standing grant.
```

### `writes.permitted`: correct the description of a pull request an agent opened

```yaml
    - operation: correct the description of a pull request an agent opened
      shape: >-
        a correction that makes the description say what the branch now does:
        a count that was wrong, a plan the branch superseded, a finding fixed
        since. It is appended and dated, the way a NEWS correction is, rather
        than overwriting the sentence it corrects, so the record of the mistake
        survives the fix. Never a change to what the pull request is for.
      granted: >-
        2026-09-23, in Brett's instruction "Add a row to the registers for your
        own upkeep as needed", given with the reinstatement recorded under
        reinstated_2026_09_23. It answered the question put to him that day:
        correcting a pull-request description, asking Codex to look again and
        re-running a failed job had no row, which is why the orchestrating
        session kept stepping outside this register. The write that suspended
        the protocol on 2026-09-16 was one of these.
```

### `writes.permitted`: promote a queue item to state ready

```yaml
    - operation: promote a queue item to state ready
      enforced_by: >-
        nothing mechanical. This was structural until 2026-09-10 because an
        agent could not push to the default branch at all; it is now an audit
        trail, which the ready_is_set_by note in this front matter says in the
        one place a reader of the queue will look.
      granted: >-
        2026-09-10 (ruling R15), for a promotion on an authorization Brett gives
        in chat, one item at a time. Widened 2026-09-23 by a standing grant, in
        his words: "An agent may promote a queue item to ready, citing this
        authorization, when all of: the item's repo is one you work alone in
        (solo: true); it carries a non-empty retires_when; its severity is P0,
        P1, or P2 or P3; its blocked_by is empty; and it is not needs_brett.
        Anything else stays per-item." It is to promotion what ruling R16 is to
        merging: one grant with a stated test, under which each promotion still
        names it. First applied in commit abd58b2, whose message lists what it
        promoted and what it held back, with the reason for each.
```

### `writes.permitted`: push a small mechanical change to this repository's default branch

```yaml
    - operation: push a small mechanical change to this repository's default branch
      shape: >-
        queue state, a generated block, a typo, ignoring a stray file. Anything
        substantive goes through a pull request, because that is what Codex
        reviews and losing the review costs more than the extra step.
      enforced_by: >-
        nothing mechanical. Whether a change is small and mechanical is a
        judgement, and the commit message is where the judgement is recorded so
        that a wrong one is legible afterwards.
```

### `writes.permitted_note`

```yaml
  permitted_note: >-
    Three rows, merge a pull request in this repository, promote a queue item
    to state ready, and push a small mechanical change to this repository's
    default branch, were granted on 2026-09-10 and reached this register on
    2026-09-10, in a later change, after a review pointed out that they had been
    written into the prose below and into Brett's global instruction but not
    into the only enumeration scope_note says is operative. Until they landed
    here, an agent that merged, promoted or pushed a typo was writing outside
    the permitted list and had therefore suspended the whole authorization by
    doing exactly what it had just been told it could do. Add the row in the
    same change as the grant; a grant that lives only in prose is not a grant an
    agent can act on.
```

### `writes.reinstated`

```yaml
  reinstated: >-
    2026-09-10, for the three operations permitted_note describes and for
    nothing else. Read against itself, that note plus self_suspends below say
    the standing authorization is currently dead: merges, promotions and small
    mechanical pushes to main happened while they were outside the permitted
    list, and self_suspends says any such write suspends the whole grant until
    Brett reinstates it. It is not dead, and the reason is a matter of order.
    Brett granted those same three operations on 2026-09-10 (ruling R15), after
    the writes rather than before them, knowing they had already been made. An
    authorization given for exactly the operations that triggered a suspension,
    given after they happened, is a reinstatement in substance whatever word he
    used, so it is recorded here as one rather than left to be inferred by a
    reader comparing two other keys. Recorded alongside permitted_note rather
    than by deleting it, because that note is the evidence of how the gap opened
    and the lesson is the reason the rule exists. This clears the suspension
    arising from those three operations. It clears nothing else: a later write
    outside the permitted list suspends the grant again, and needs its own dated
    entry here from Brett before the protocol resumes.
```

### `writes.reinstated_2026_09_23`

```yaml
  reinstated_2026_09_23: >-
    2026-09-23, by Brett in chat: "Reinstate", adopting the resumption the
    orchestrating session had put to him ("The protocol resumes, and I finish
    wave 1. Four delegated pull requests (#145, #146, #147, #149) merge once
    CI is green and Codex has finished."). The four he named are per-pull-request
    authorizations under the merge row, in the way R16's named approvals are,
    so they went ahead before this entry reached main; nothing else did. The
    suspension it lifts began 2026-09-16 at 13:58 UTC, when that
    session edited the description of metasalmonpy pull request 34, claimed
    item B-145's hand-back, through the REST API. No row permitted the write,
    it was made against a claimed item, and self_suspends says such a write
    suspends the whole authorization. Nothing noticed for a week. A dispatched
    agent flagged the edit on 2026-09-23, the session's transcript confirmed
    it, and every protocol write stopped and was reported before this entry.
    The protocol writes made in between (merges on 2026-09-16 and 2026-09-17,
    and the first wave's claims, pushes and pull requests on 2026-09-23) were
    made while suspended. They were reported to Brett, by kind and count, before
    he reinstated, so this entry covers them. Writes on unclaimed pull requests
    that no row covered either (@codex review comments, one CI re-run, the
    agent-run label on queue pull requests) are outside this register's scope
    and are recorded here, not reinstated by it. In the same message Brett
    granted the three upkeep rows in the permitted list, so the kind of write
    that caused this suspension now has a row.
```

### `writes.denied`

```yaml
  denied:
    - >-
      any issue, release, or assignee; and any comment or review except a reply
      to a Codex review thread under the row the permitted list added on
      2026-09-16. Carved out 2026-09-16: this entry read "any issue, review,
      comment, release, or assignee", and a review reply is a comment, so
      answering Codex would have suspended the protocol under the grant that
      told an agent to answer it. An issue comment, a review of somebody else's
      pull request, and a reply to a person's review are all still denied.
      Carved out again 2026-09-23: the one issue comment the permitted list now
      names, "@codex review" on a pull request an agent opened, is the only
      exception, and any other issue comment is still denied.
    - >-
      any pull request operation other than the six the permitted list names,
      which are opening the one draft per handed-back item, merging a green pull
      request in this repository, marking ready for review, replying to a Codex
      review thread, merging an approved pull request in a solo member
      repository, and correcting the description of a pull request an agent
      opened (added 2026-09-23). Never a second draft for the same item, never an approval, and
      never marking ready a pull request an agent did not open. Carved out
      2026-09-10: this entry read "any pull request other than the one draft",
      which by its own words denied the merge the permitted list grants three
      rows later and the next denial below scopes, leaving an agent no valid
      reading of the register. Narrowed again 2026-09-16, when three of the
      operations this entry named as never -- marked ready for review, merged,
      replied to on a review comment -- were granted. All three are struck from
      the never list here rather than left to contradict the grant, because
      denied_note says an exception has to be carved out in the same change and
      because the 2026-09-10 lesson was exactly this one.
    - >-
      any merge in a member repository whose solo key in queue/config.yaml is
      false or absent, any merge of a pull request whose checks are not all
      green, and any merge of a pull request in a class "Which pull requests
      need Brett" reserves to him. Carved out 2026-09-16: this entry read "any
      merge outside this repository", which denied the metasalmonpy merge Brett
      authorized by number in the same message that widened the register. The
      boundary is now the solo key rather than the repository name, which is the
      test the participation table already uses for pushing a branch.
    - >-
      a push to a default branch other than the two the permitted list names,
      which are a small mechanical change here (queue state, a generated block,
      a typo, ignoring a stray file) and the locks repository's README.
      Anything substantive goes through a pull request, because that is what
      Codex reviews, and losing the review costs more than the extra step.
    - >-
      any GitHub API call that writes, including through gh, other than the
      eight the permitted list names, which are opening the one labelled draft
      pull request for a handed-back item, merging a green pull request in this
      repository, marking such a pull request ready for review, replying to and
      resolving a Codex review thread on it, merging an approved pull request in
      a solo member repository, and, on a pull request an agent opened,
      correcting its description, asking Codex to review it again, and
      re-running a failed job. Widened 2026-09-16 with the rows it counts:
      this entry names a number, so a grant that did not update it here would
      leave the register self-contradicting for the third time. Widened again
      2026-09-23 for the same reason, in the change that added the three upkeep
      rows.
```

### `writes.denied_note`

```yaml
  denied_note: >-
    This list is closed and it is the operative one, so an exception granted
    anywhere else has to be carved out of it here in the same change. Four of
    these entries read as flat prohibitions of operations the permitted list had
    already been given, from 2026-09-10 until later the same day, which left an
    agent no valid reading of the file at all: obey the grant and self-suspend,
    or obey the denial and ignore an instruction Brett had just given. Narrowing
    a denial is part of granting a permission, not a follow-up to it. It
    happened a third time on 2026-09-16 and was caught before landing rather
    than after: the grant to answer Codex reviews collided with "any issue,
    review, comment, release, or assignee", with the never-list in the pull
    request entry, with the repository scope on merging, and with the entry that
    counts the permitted API calls -- four collisions from one instruction. That
    the count keeps being four is the argument for reading this whole list
    against every new row rather than only the row that looks related.
```

## Introduction, before the first section

The client is dumb and this file is the brain. A `hub` client (`doctor`,
`ready`, `claim`, `beat`, `release`, `done`, `reconcile`) does the mechanics;
every rule it enforces is written here, once, and nowhere else. **Every number
those rules use lives in `queue/config.yaml`, once, and nowhere else**,
including here. Cite a constant by its key; do not restate its value in prose,
because a restated value is a second answer waiting to go stale, and on
2026-09-09 the concurrency cap was found saying one in this file and two in the
configuration while the client read only the configuration. The one deliberate
exception is the fetch refspec under "Claiming", which cannot cite a key and
says on the spot that it is an example.

That sentence used to read "no GitHub API call anywhere in it", which stopped
being true on 2026-09-10, when the register gained two permitted API writes:
opening the one labelled draft pull request for a handed-back item, and merging
a green pull request in this repository. **Both are the agent's own call, and
neither is ever folded into a `hub` subcommand.** A client that makes no API
call is the property this design is buying, because it means the client needs no
GitHub permission beyond `git push` and cannot exceed the grant on an agent's
behalf. That is worth more than the convenience of one fewer command to run.

## The queue and the states (history)

Each item is one YAML document under `queue/items/`, carrying its
`id`, `kind`, `title`, `state`, `claimable`, `repo`, `blocked_by`, its `legacy`
citation so the bare backlog numbers already written into 191 places never have
to be rewritten, an `evidence` pointer, a `venue`, and, for a defect,
`retires_when`.

The six states and which are claimable are in the front matter above. Two of
them are worth saying in prose because they are the ones people get wrong.
`review` is not a resting place for a free item: the claim is still held, on
purpose, so finished work never looks free again while Brett is away. `done`
means the change merged --- by Brett, or by an agent under the review-delegation
rule in *Which pull requests need Brett* --- and it stays as a record.
*(This said "Brett merged it" until 2026-09-16, which the front matter's own
`states` entry widened that same day; the widening corrected the definition
and left this restatement of it standing.)*

**`ready` is set by a commit on `main`, and until 2026-09-10 that was a wall an
agent could not climb, because it could not push there at all.** It is now an
audit trail instead: an agent may promote an item on an authorization Brett
gave in chat, and the promotion commit must name that authorization. So the
property that an agent cannot enlarge its own queue is no longer structural,
and a promotion citing no authorization is a defect rather than an impossibility.
The supply of claimable work still originates with Brett, and the protocol below
is still sized for that rather than for throughput.

**Since 2026-09-23 it originates with him in two ways rather than one**: an
authorization for a named item, or the standing grant quoted on the register's
promotion row, which states five conditions an item either meets as written or
does not. The second is the answer to a measured bottleneck, not a relaxation of
the audit trail: every promotion under it is still a commit that names it, and
anything outside its test still needs him item by item. The concurrency cap in
`queue/config.yaml` was calibrated before it existed, and that key's own
*Revisit* note names the evidence that would show the cap, rather than
promotion, has become the constraint.

## Claiming, and what to do when the push is rejected (history)

A claim is git's own compare-and-swap. A first claim is an **orphan** commit,
with no parent, pushed to the item's ref under `claim_ref_prefix`
(`queue/config.yaml`). An orphan commit can never
fast-forward an existing ref, so the push succeeds if and only if nobody holds
the claim. Every later commit on that ref, heartbeat, release, handoff, and
reclaim alike, is a **child of the tip you just read**, so it succeeds if and
only if nobody has appended since you looked. The race window is zero in both
cases, and neither needs a GitHub permission that Brett's rule protects.

**That refspec is an example, and it is the one place in this file where the
value of `claim_ref_prefix` is written out.** A fetch refspec cannot cite a
configuration key, so an example has to carry a literal. `queue/config.yaml`
holds the value; if this example and that key ever disagree, the configuration
is right and the example is the stale copy. Everywhere else in this file the
claim ref is named by the key.

**A rejected push has two meanings and they are different exit codes.** This is
the difference between a stalled queue and a silent one. If a non-fast-forward
rejection is folded into the same outcome as an expired credential or a DNS
failure, an agent spins through the entire queue reporting nothing wrong.

Reclaiming an abandoned item is permitted only when the tip's newest commit is
older than the lease for its class plus `reclaim_grace_minutes`, and only
`max_reclaims_per_item_per_day` times per item over a rolling 24 hours. A
reclaim commit is a child of that tip like any other, so two agents cannot both
reclaim. `hub claim` counts the reclaim records already in the ref's own history
and exits 3 at the limit, so this is a rule the client applies and not one it
merely states. An item that keeps being reclaimed is an item that keeps
defeating agents: report it rather than taking it again.

## Isolation (history)

**Both of those were repository-wide until 2026-09-16, and the correction to the
second is the one worth reading, because the first correction missed it.**

`git stash list` was a third check here and could never have done anything but
block. A stash is a repository-level ref: it returns the same entries from inside
every worktree, so it says nothing about *this* one. This repository has carried
one deliberately-kept stash since 2026-09-10 (the evidence-pointer edits
superseded by pull request #110), which made **every** worktree permanently
unremovable — measured with twenty-odd accumulated and a clean throwaway one
refused by it. *Retires when:* git gives a stash a worktree of record, at which
point the check can come back scoped to it.

**The revision walk had the identical defect and survived the edit that removed
the stash clause**, which claimed in as many words that the two remaining checks
were "genuinely per-worktree". That was true of `status --porcelain` and false of
the other: `--branches` means *all* of `refs/heads`, so
`git log --branches --not --remotes` run inside a worktree reports unpushed
commits from **every** branch in the repository, including branches checked out
in other worktrees. Measured 2026-09-16 in a scratch repository — a clean
worktree detached at a fully pushed commit, refused because an unrelated branch
in another worktree had one unpushed commit; scoping the walk to `HEAD` permits
it. Caught in review, not by the rule firing.

The lesson is the one this file keeps relearning and it is worth stating where it
happened: **a fix that removes one instance of a defect is not a fix for the
defect.** The stash clause and the revision walk were the same mistake written
twice, three lines apart, and removing one of them produced a paragraph asserting
the other was sound. Ask of any such correction what *else* is in the same
family, before writing the sentence that says the rest is fine.

## Reporting (history)

**The path is per-item because a single shared path made every parallel
hand-back destroy the one before it.** Until 2026-09-16 the report went to
`.hub/workpad.md`, one path for the whole repository, so two branches that each
carried a report collided on it and the resolution was to discard one — which
meant `main` only ever held the report of whichever hand-back merged last, and
the fleet's own record of what it had found lived only in closed pull requests.
That is hub item **B-140**, filed when #111 and #112 first hit it. Measured on
the night of 2026-09-15: **six** branches carried a report, four had to be
resolved by hand, and because each resolution is a push, each cost a full
continuous-integration cycle — for a file whose two versions were never in
conflict about anything, being reports of different items. With a per-item path
they merge silently and `main` accumulates the fleet's reports instead of
overwriting them. *Retires when:* nothing — this is B-140's fix, and the old
path is what retired.

The workpad carries, in this order: the queue id and the item title; what you
changed and where; the commands you ran and their results, including the
failing-before and passing-after evidence for a defect; what you did not do and
why; anything you found that belongs to another item, named by id, so it can be
promoted rather than absorbed; and the retirement condition of any guard,
suppression, skip, or workaround you added. A guard with no retirement
condition outlives its cause and then conceals a failure it was never written
for, so a workpad that adds one without saying what would retire it is
incomplete.

## Hand back (history)

**Whether it stays a draft depends on which list it falls into.** Until
2026-09-16 this paragraph read "Draft, and draft only: never mark it ready for
review, never merge it, never reply to a review comment on it", and for a pull
request in a class "Which pull requests need Brett" reserves to him that is still
exactly right: it stays draft, unmerged, and unanswered, because hand-back is
where he looks. For a pull request in the delegated classes, ruling R16 moved the
looking to Codex: mark it ready, answer what Codex finds, and merge it on the
four conditions that section lists. An agent that cannot tell which list its own
pull request is in leaves it a draft and says so, which is the safe direction and
the one that costs a message rather than a merge.

**Only in a repository nobody but Brett has ever contributed to, and that covers
the branch push as well as the pull request.** The grant is scoped by
participation, not by ownership, and three of the member repositories fail that
test; the table in the standing authorization below says which and how to test
it. In a shared member repository the hand-back ends before the push, not after
it: the work stays in the worktree, and Brett sees the diff and the pull request
text in chat and says yes before anything leaves the machine. That is the whole
point of the scope, so read the table before reaching for `git push` or `gh`.

This was declined on 2026-09-09 and granted on 2026-09-10, and the reversal is
worth recording rather than quietly replacing. The original reasoning was that a
draft pull request is a pull request, which is one of the verbs Brett's standing
rule names, so it should cost an explicit decision. The decision, once he made
it, was that inside his own repositories a pull request is him talking to
himself: the rule exists to stop an agent addressing *other people* as him, and
a draft PR on metasalmon addresses nobody. It also starts continuous integration
immediately rather than whenever he next sits down, which is the actual cost the
old arrangement was paying.

`gh pr create --draft` is the agent's own call, not a `hub` subcommand. The
client makes no GitHub API call at all and that property is worth more than the
convenience of folding this into `hub done`; the client still prints the compare
URL, which is the fallback when a PR cannot be opened.

## Which pull requests need Brett (history)

The measurement behind it: on 2026-09-15 ten claimed items produced twelve pull
requests in one night, all green, and every one of them waited on one person. The
concurrency cap in `queue/config.yaml` was calibrated on the assumption that
producing `ready` was the bottleneck. For one night it was not, the merge was,
and the cap's own `Revisit` note asks to be told when that happens.

**The principle.** CI and Codex can check whether a change is correct. Neither
can check whether it was the right change to make. So the boundary is not
severity, size, or confidence: it is whether the change contains a judgement
that a passing test would not catch. `AGENTS.md` already names the archetype:
a term IRI chosen as a by-product of a change whose stated subject was something
else, justified by nothing except that strict validation then passed. That is
the shape this section generalises.

### Brett's, whatever the checks say (history)

5. **It adds, removes, or amends a parity-register row, or changes what the
   mirror contract claims.** The single fact that contract turns on has three
   copies and they have disagreed twice.

7. **It changes `HUB.md`, `queue/config.yaml`, or this register.** Policy does
   not self-amend. The pull request that introduced this section is itself an
   instance and was not self-merged.

8. **It promotes a queue item to `ready` outside the standing grant on the
   register's promotion row, or changes `claimable` outside the grant on the
   register's claimable row.** Already his, and unchanged by this section.
   *(This read "It promotes a queue item to `ready`" until 2026-09-23, when that
   grant took the items meeting its test out of this class and left `claimable`
   in it. It read "or changes `claimable`" until 2026-09-25, when his claimable
   grant took setting it to `true`, for the items meeting that row's test, out
   of this class; setting it to `false` stayed.)*

### Delegated: merges on green CI and a completed Codex review (history)

- **CI green on the head being merged**, read off the checks rather than inferred
  from a local run. CI runs a different R than the container does, in both
  directions: two non-ASCII characters passed locally and failed CI on
  2026-08-25, and two vignettes fail locally and are not checked at all by CI's
  newer R (B-164).
  **Green means there are checks and they are green. No checks at all is not
  green, and it is the shape a merge conflict takes.** A pull request whose merge
  ref GitHub cannot compute gets no `pull_request` workflow runs at all, so its
  head shows an empty check list rather than a red one — which reads as "nothing
  failed" to anyone counting failures. Measured 2026-09-16 on PR #121: four
  successive pushes while the branch was conflicted produced **zero** runs over
  fifty minutes, and all three checks started within a minute of the conflict
  being resolved, on the same branch with the same credentials. The remedy is
  never to wait, and never to ask for a hand re-run: **merge the base branch into
  the head and resolve it**, which is both the fix and the thing that starts CI.
  An agent that reports a conflicted pull request as "CI not run" has reported
  the symptom and left the cause.

### What keeps this honest (history)

**Delegation is recorded, not silent — and recorded is not the same as
announced.** Every batch worked under this section leaves a record naming what
merged without Brett and under which delegated class. Invisible delegation is
indistinguishable from an agent deciding the boundary for itself, and the whole
point of writing the boundary down is that he can move it.

**That record goes in the repository, not into his attention.** Narrowed
2026-09-16 on his instruction: *"just notify me for consequential decisions or
design or user experience or specs or ontology or other high level decisions
required."* Until then this paragraph said *every batch ends with one message*,
which made the mechanics of merging — what was green, which conflict was
resolved how, which check ran — into things he had to read. **That is the
bottleneck R16 was granted to remove, reappearing as narration.** The pull
request body, the workpad and the commit message are the record and they persist;
a chat message is neither durable nor searchable, and spending his attention on
one costs the same whether the content needed him or not.

**The asymmetry is deliberate and runs the other way from the grant.** Under-
reporting a decision that was his costs a wrong decision that stands until
somebody notices; over-reporting mechanics costs his attention every time and
trains him to skim, which is how the real question gets missed. When genuinely
unsure whether something is a decision or a mechanic, ask — the uncertainty is
itself the signal, and this section already says uncertainty resolves toward
asking.

## The standing authorization (history)

**The block quote is reproduced as Brett wrote it and is not edited when he
widens it.** Its "never marked ready for review and never merged" was accurate
when he wrote it and stopped being the whole rule on 2026-09-16, when ruling R16
granted marking ready, answering a Codex review, and merging an approved pull
request in a repository whose `solo` key is true. The quote stays verbatim
because a record of what he said is worth more than a record kept tidy; the
widening is recorded in `writes.permitted`, which the paragraph below already
names as the list that governs. Anyone reconciling the two reads the register,
not the quote.

**The shared-repository case was settled conservatively, on purpose, and this
paragraph records that it was settled rather than always having read this way.**
Until 2026-09-10 the block quote answered its own question twice: the first
paragraph scoped every listed operation to repositories with no other
contributor, and the second said the agent stops *after* pushing the branch,
which reads as a branch push into a shared repository needing no ask. It was
resolved against the push, for two reasons that agree. Brett's global agent
instructions permit writing without asking only in a repository that is his
alone and require asking every time everywhere else, so the narrower reading is
the one his text supports and the wider one had no source. And the two ways of
being wrong do not cost the same: reading it too narrowly costs a question he
answers in a sentence, while reading it too widely costs a write into somebody
else's repository that cannot be taken back. Three further operations reach
this repository from Brett's global rule rather than from this block quote, and
the section below says how each applies here and how this file narrows it.
`writes.permitted` in the front matter is the union of the two sources and is
the list that governs.

**`dfo-salmon-ontology` gained a reviewer on 2026-09-23, and it changes how work
leaves this machine for that repository, not whether the grant applies.** Brett,
in chat: *"Note that for the dfo-salmon-ontology I have a new collaborator who
will need to review MRs so we cant auto push them any more and I want to review
any MR or issue text."* The grant column above was already **no** and stays so.
What is new is the path after his yes. A change reaches that repository only as
a merge request that collaborator reviews, and never as a push to its default
branch, whether by an agent or by Brett applying an agent's patch. Brett reviews
the text of every merge request and every issue an agent drafts for it before
it is posted. So a hand-back there ends, as it did before, at a diff and the
text of a merge request shown to him, and his yes now leads to a merge request
for review rather than to a push. The table row still records the 2026-09-10
measurement. Whoever re-measures participation there counts the collaborator
from their first commit, issue or merge request, as the test above counts
anyone.

**Do not use the collaborator list for this test.** Every repository in the
organization shows the same eight collaborators, because the organization's
base permission is `write` and every member inherits access to everything. By
that test nothing would ever be solo and the grant would be empty. Once base
permission is set to Read the access list becomes meaningful again and is worth
re-checking, which is one more reason to fix it.

**This is the operative copy, and it is now the only one.** Section 9.5 of the
Foundry plan carried the same paragraph verbatim until 2026-09-09, which is
precisely the duplicated-fact defect this design was built to remove, and the
worst possible fact to duplicate: two copies of a permission boundary can drift
into two different boundaries, and nothing in either copy would say which one an
agent is operating under. Section 9.5 now carries a summary that says this file
governs, and the review that found the duplicate found it by reading the two
against each other rather than by reading either alone.

- The claim-ref target is printed before every push, and once the locks
  repository is configured an environment variable cannot redirect it. The
  `GIT_CONFIG_*` family is stripped, because one `url.insteadOf` entry rewrites
  a push target silently no matter what the client computed.

- **Neither check binds an agent that does not use the client.** Nothing stops
  an agent running `git push` itself, and nothing here could: the grant is a
  rule an agent follows, and the client is the easiest way to follow it
  correctly rather than a mechanism that makes breaking it impossible. What
  makes a breach visible is that every push leaves an authored commit.

A grant that only prose enforces is a grant that gets exceeded by accident,
and the accident is silent because the push succeeds. That is why the client
checks. It is not why the grant holds.

**A draft pull request was declined on 2026-09-09 and granted on 2026-09-10**
(R13, then R15). One draft pull request per handed-back item is now permitted,
in a member repository **nobody else has contributed to**, labelled `agent-run`.
It was also "never marked ready and never merged" until 2026-09-16, when R16
granted both for the delegated classes and left them forbidden for Brett's;
"Which pull requests need Brett" is the operative boundary and this sentence
defers to it. There is still no Project sync paragraph, because there is still
no Project.

The grant follows a distinction worth stating, because it is the one that makes
the whole rule coherent: **what matters is not the verb, it is whether another
person reads it as Brett.** A draft pull request on his own repository is him
talking to himself. A comment on somebody else's repository is him talking to a
colleague. The first is friction; the second is the thing the rule exists to
prevent.

**The closed exclusion list.** The authorization covers nothing else, and
specifically not: any issue, release, or assignee, and any comment or review
other than a reply to a Codex review thread on a pull request the agent opened
or the "@codex review" trigger the upkeep rows permit on one;
any pull request operation other than the six granted above, which are the one
draft per handed-back item, correcting the description of a pull request an
agent opened, a merge in this repository of a pull request whose
checks are all green, marking such a pull request ready for review, replying to
and resolving a Codex thread on it, and merging an approved pull request in a
member repository whose `solo` key is true; any push of the work branch into a
member repository somebody else has contributed to, where it is ask-first; any
merge in a member repository whose `solo` key is false or absent, any merge of a
pull request
that is not green, and any merge of a pull request in a class "Which pull
requests need Brett" reserves to him; any push to `main` other than this
repository's small
mechanical changes and the locks repository's README; any move of an item to
`ready` that does not rest on an authorization Brett gave in chat and name it in
the commit; any `--force`; and anything at all on GitLab. The list is closed,
meaning that an operation resembling a permitted one is denied unless it is
named in `writes.permitted`.

**Three more operations reach this repository from Brett's global rule, and
this file narrows each of them rather than widening anything** (checked
2026-09-10). The global rule already lets an agent merge a green pull request
in a repository he works alone in, promote a queue item to `ready` on an
authorization he gave in chat with the commit naming it, and push a small
mechanical change to a default branch preferring a pull request otherwise.
Nobody else has ever worked here, so all three arrive on their own. What
follows is how each applies in this repository, and each statement is narrower
than the global one it comes from:

- **Promoting a queue item to `ready`** carries the global rule's own
  condition, restated because a reader of the queue will look for it here: the
  commit names the authorization Brett gave in chat, and a promotion that
  cannot cite one is a defect.

- **Pushing to `main`** is for small mechanical changes only, and here that
  phrase is enumerated rather than left to judgement: queue state, a generated
  block, a typo, ignoring a stray file. Anything else goes through a pull
  request, because that is what Codex reviews.

**This section called those three widenings until 2026-09-10, and the label was
wrong in a way that costs something.** A widening claims an authority this file
does not need and does not have: delete this section and all three operations
survive, because they come from the global rule; delete the global rule's
clause and none of them does. Worse, a false widening invites the next reader
to trim the global rule to match, on the reasoning that the permission really
lives here. It does not. The one thing this file genuinely does with them is
narrow them and put them in the register, and the register is what makes them
exercisable.

**Nothing here is a widening, including the locks repository's README.** That
row writes to a default branch in a repository other than this one, which is
the shape that most looks like this file granting itself authority elsewhere.
It is not: Brett's own standing authorization, quoted above in his words, names
that push explicitly, and the row's `why_it_is_not_a_local_grant` in the
register says so. There is no widening list for it to be misfiled into.

All three are rows in `writes.permitted` above and are carved out of
`writes.denied` there, which is what makes them exercisable: `scope_note` says
an operation absent from that list is not permitted whatever it resembles, so a
permission announced only in this prose would suspend the authorization the
first time an agent used it. They were announced here first and reached the
register later the same day, which is exactly that failure, caught by review
rather than by an agent tripping over it.

**A Codex review is an opinion, not an instruction.** Weigh it against the
evidence, and where it conflicts with something Brett has already decided, his
decision wins and the reply says so rather than quietly complying. A wrong
review that is followed is worse than no review, because it arrives wearing the
authority of having been reviewed.

**Self-suspending.** The whole authorization is suspended the moment an agent
executing this protocol writes outside the permitted list, and stays suspended
until Brett reinstates it. Suspension is not per-agent: the carve-out exists
because it is narrow and observable, and one write outside it removes the
evidence for both. An agent that discovers it has written outside the list
stops, reports the write, and does not continue under the protocol.

**What it does not cover.** This clause is scoped to the protocol, like the
register it protects: it fires on a write made under the protocol against a
claimed item, not on every write an agent makes in a working day. Ordinary
repository work is governed by Brett's global agent instructions, which carry
their own suspension clause with their own scope, and nothing here narrows or
replaces it. The scoping was added 2026-09-10, when the register was found
reading as though editing a file outside a claim were a breach of the hub grant.

**It first fired, and was first cleared, on 2026-09-10** (`writes.reinstated`). Merging, promoting and small mechanical pushes to `main` were made
while those three operations were still absent from `writes.permitted`, and
Brett then granted exactly those three, after the fact and knowing they had
happened. That is a reinstatement in substance, and it is recorded as one and
dated in the front matter so nobody has to reason it out from two other keys.
It clears those three and nothing else.

**It fired a second time, and nobody saw it for a week** (`writes.reinstated_2026_09_23`).
On 2026-09-16 the orchestrating session edited the description of a claimed
item's hand-back pull request, a write no row covered. The clause suspended the
protocol at that moment, but the protocol kept running, because nothing checks
for the trigger. A dispatched agent found the edit on 2026-09-23, the protocol
stopped, and Brett reinstated it that day. That is the lesson: a clause that
fires silently only works if some reader looks for its trigger, and on
2026-09-23 the reader was an agent comparing a pull request's description to
its own workpad. The three upkeep rows granted with the reinstatement give that
kind of write a row, so it cannot trip the clause again.

## Dispatch briefs restate nothing from this file (history)

**This was learned the expensive way on the day the rules changed.** Until
2026-09-16 the brief lived in a scratch directory outside the repository and
carried its own copy of the never-list, including *"never reply to a review
comment."* Ruling R16 granted exactly that reply for a pull request in a
delegated class and this file was amended the same day; the brief, being a
separate copy somewhere else, was not. A dispatched agent read the stale copy,
correctly refused the review replies it had been sent to write, and left them in
a text file for a person to paste. **The agent was right to obey what it had been
handed. The second copy was the defect** — and it disagreed with this file at
exactly the moment this file had just changed, which is when a disagreement costs
the most and is the least likely to be noticed.

So the rule is structural rather than advisory: a brief, a prompt, a card or a
comment that restates a permission, a prohibition, a path, a constant or a branch
pattern from here is **the stale copy**, as the front matter's `authority` key
already says of any document. If a brief needs a rule, it links to it.

## What you must never do (history)

- Never merge a pull request **except** in a member repository whose `solo` key
  in `queue/config.yaml` is true, and there only when every check has finished
  green, the Codex review has completed with every finding fixed or answered,
  and the change falls in a delegated class rather than one "Which pull requests
  need Brett" reserves to him. Rewritten 2026-09-16: this read "except in this
  repository ... and never the hand-back draft itself", both of which R16
  changed. A merge in a repository whose `solo` key is false or absent is still
  outside the grant, and so is a merge of a change in one of his classes,
  however green it is.

- Never set an item to `ready` **except** on an authorization Brett gave in
  chat, and then the commit must name it. A promotion commit that cannot cite
  one is a defect.
  *(These read as flat prohibitions until 2026-09-10 and contradicted the
  three permissions described above, written the same hour. A policy
  file that says both answers is worse than one that says the wrong answer,
  because an agent obeys whichever half it read; this is the disease the queue
  exists to cure, caught in the queue's own rulebook by a review that read the
  file against itself. It was caught twice. The first pass fixed the two
  bullets in this list and left `writes.denied` above still forbidding the same
  operations, which is the half that actually governs, so the second pass had
  to do the register, the closed exclusion list, the pull-request bullets and
  the locks README. Fixing the copy a reader happens to be looking at is not
  fixing the contradiction; the way to know it is fixed is to grep every
  prohibition for the verb you just permitted.)*

- Never call the GitHub API to write, including through `gh`, **except** the
  eight writes the register permits: opening one draft pull request for a
  handed-back item with the `agent-run` label; merging a green pull request in
  this repository; merging an approved pull request in a solo member repository;
  marking a pull request ready for review; replying to a review comment on
  one; and, on a pull request an agent opened, correcting its description,
  posting the `@codex review` trigger once per pushed round of fixes, and
  re-running a failed job under the conditions its row sets (the last three
  added 2026-09-23). Read-only `gh` is fine. The `hub` client itself makes no API call at all,
  deliberately, so every one of these is the agent's own call and none is ever
  folded into a `hub` subcommand.
  *(This said **two** until 2026-09-16, and went stale the same day ruling R16
  added the last three rows to the register. A count in a never-list is a second
  copy of the register's length, which is why this sentence now enumerates the
  operations instead: an enumeration that falls behind names the wrong thing and
  can be seen to, where a number that falls behind just looks like a number.)*

- Never restate an operating constant's value outside `queue/config.yaml`,
  including in this file. Cite the key. The one exception is the fetch refspec
  under "Claiming", which cannot cite a key and says on the spot that it is an
  example and that the configuration wins.

- Never remove a worktree that fails either of the cleanliness checks under
  *Isolation*, and never delete a branch. *(This said **three** until
  2026-09-16, when the `git stash list` clause was removed for being
  repository-wide; the sentence that removed it is three lines from this one
  and did not notice it.)*
