# Bundle log

## 2026-09-09

- **Step 0 of the coordination change: the bundle's stale state was deleted
  rather than corrected.** Six passages were wrong on the day they were
  measured, and each has now been changed so that it cannot go wrong the same
  way again — by removing the restatement, not by refreshing it.

  | Where | Was | Now |
  |---|---|---|
  | [orientation](orientation.md) | "Released 0.3.0", two releases stale | points at the release index |
  | [hub-coordination context](contexts/hub-coordination.md) | "both are at 0.4.0, lockstep is the present state, S10 is done" | states the rule, not the numbers |
  | [S3](sequences/s3-knb-staging.md) | "not yet released, not yet mirrored"; `DESCRIPTION` stays at 0.3.0 | release state points at the index; the *reason* a release waits is kept |
  | [S8](sequences/s8-method-model.md) | mirror "is at 0.1.8 now" | past tense; the number points at the index |
  | [S13](sequences/s13-fraser-recruits-case-study.md) | "Current metasalmon is 0.3.0" | "several breaking releases later", with the breaks named |
  | [S4](sequences/s4-workshop-rebuild.md) | "conditional … this card takes no position" | records ruling A and the work it commits |

- **OD-2 was ruled on 2026-08-22 and this bundle said otherwise for eighteen
  days.** [Q1](questions.md) and the S3 card carried the ruling the whole time;
  the roadmap's OD-2 entry, its sequencing prose, its diagram legend, and the
  S4 card did not. The entry now states the ruling at its top with its heading
  unchanged, per the open-decisions convention, and keeps the discarded options
  because what was decided against is the part that stops the question
  regrowing.

- **The shape of the defect, which is the reason any of this matters.** One
  dependency had *three* renderings inside one file plus a fourth in a card,
  and correcting it meant four hand edits that nothing would have caught if one
  had been missed. One version number had ten homes and five were wrong. The
  bundle's own rule — *a count nobody maintains is decay* — was being broken by
  the bundle. The rule applied here is **one fact, one home**: a card that
  restates state now points at the authority instead, and where the
  restatement was load-bearing prose it is rewritten in the past tense so the
  reasoning survives without the number.

- **Each correction leaves a scar on purpose.** Every rewritten passage says
  how long it was wrong. A silent fix teaches nobody, and the next agent
  reading a confident sentence has no way to know which confident sentences
  have been wrong before. This is step 0 of the change described in the
  [Foundry plan's §9](plans/2026-09-04-salmon-science-foundry-concrete-plan.md),
  and it is worth doing on its own even if the rest never happens.

- **The Foundry plan and its integration kit merged into `main` as pull request
  104.** The plan landed as an *execplan candidate* and nothing was sequenced by
  it. Merging a plan commits this repository to having considered a decision at
  a point in time, which is what `plans/` is for; it does not commit anyone to
  the work, and the distinction is the only thing that keeps a dated plan from
  reading as a mandate a year later.

- **Then Brett ruled that the integration should be completed rather than
  held**, which is the reason this pass exists at all rather than only the
  fixes. S14 and S15 entered the roadmap as streams, the domain card gained a
  ninth member, and nineteen rulings that had been living inside a plan document
  moved into [the questions index](questions.md), where someone who was not in
  the conversation can find them. The Foundry repository **does not exist yet**,
  and admitting it anyway is deliberate: the sequencing membership test asks
  what a repository is *for*, not whether anyone has pushed to it, so a member
  with no commits is a valid entry. Waiting for the first commit would only move
  the ninth member from a decision into a surprise.

- **The hub queue was built.** A single policy file (`HUB.md` at the repository
  root), a client whose claim is a plain `git push` of an orphan commit and
  nothing cleverer, one YAML file per item, a validator, a freshness check, and
  a continuous-integration job whose permissions are read-only. It lives at
  `queue/` in the repository root and deliberately **not** in this bundle, for
  two reasons either of which is sufficient on its own: the OKF validator fails
  closed on non-Markdown files inside a bundle, so a queue filed here would have
  broken the bundle it was filed in; and operational state belongs with the
  system that owns it rather than in a knowledge bundle, which is a standing
  rule and not a rationalisation of the first reason. The same validator fails
  closed on a Markdown link out of the bundle, so a card names `queue/README.md`
  in backticks as prose and never as a link. There were sixty-three item files
  when this was written; that is a dated observation and not a number this
  bundle undertakes to maintain, for exactly the reason step 0 above deleted six
  other restated counts. `queue/items/` is the authority and can be counted.

- **What the review of that build found is the part worth keeping.** Four
  blockers and about twenty majors, and two of the blockers are worth naming
  because they are a shape this bundle already collects. A YAML value contained
  an unquoted `#`, so every reader silently discarded most of the sentence after
  it: the file parsed, the validator passed, and the text was simply gone, with
  **no diagnostic anywhere**. And the freshness check reported success while
  guarding nothing, because it skipped every file carrying no marker and no file
  carried one. Both are the same defect as the gcdfo continuous-integration
  exclusion that hid a crash and the `make` recipe that printed a success mark
  over a failing script: **a green signal that means nothing**. The lesson these
  keep re-teaching is that a guard's first test is that it can fail, and that a
  guard which has never been shown failing is a claim rather than a check.

- **The critic also found that the migration had not yet performed its own
  point.** The queue was added while the prose that restates the same facts
  stayed exactly where it was, so for the length of one pass the duplication
  went **up** rather than down. Worth recording because it is the ordinary way a
  deduplication ends: the new home is built, the old copies are left for later,
  later never arrives, and the divergence starts in the gap.

- **A venue field now marks which streams are best worked in Claude Science and
  which in Claude Code**, at Brett's request. Reading, evidence synthesis,
  semantic judgement, statistical analysis and scientific writing go to Claude
  Science, which is to say anything whose output is an argument; work needing
  the repository, the R or Python toolchain, a local credential, CI, a release
  or a push goes to Claude Code; genuinely-both is `either`. Two constraints
  keep it from becoming decoration. It is **advice and never a gate**, because
  nothing reads it and no check enforces it, and a field that blocks work is a
  field that gets faked. And it **retires when it stops changing a decision**:
  if a season passes in which every item is `either`, delete the field rather
  than maintain it.

- **What is not done, stated plainly, because a partial migration reads from the
  inside like a finished one.** The generated blocks cover **one** fact, the
  member count; the thirteen stream statuses and the rest of the restated state
  named in the plan's own measurement are still prose that can drift, which is
  the same condition the previous bullet describes rather than a separate
  shortfall. The locks repository does not exist, so the queue configuration
  carries a placeholder and **no claim can actually be taken** until it does and
  until a two-terminal race proves a first claim is atomic. And the point of no
  return has not been passed: nothing yet depends on the queue, every fact still
  has its old home, and the whole change could be abandoned today at the cost of
  deleting one directory. That is a comfortable position and it is also the
  trap, because a migration that can always be abandoned is one that is never
  finished.

## 2026-08-25

- **Q12 was ruled and implemented, and backlog #93 is fully retired.** Brett:
  *"Fix them as per the metasalmonpy implementation by fixing all three by
  coercing them once at render time per type."* Items 3 and 5 route through one
  new `.ms_canonical_character()`; item 4 turned out to be **unreachable as
  stated** and is closed as a finding with a standing agreement test rather than
  as a fix. Both halves of the item's own retire condition are met, which is why
  it retires rather than shrinking.

- **The item was worse than it read in one direction and smaller in another,
  and both were found by measuring rather than by reading the item.** Worse:
  `.ms_sssom_canonical_bytes()`'s second renderer was `format()` *via*
  `as.matrix()`, which is **vector-wise** — a `confidence` of `1.5` was emitted
  as `1.5e+00` because another row held `100000`, so a cell's canonical bytes
  were a function of its neighbours, and that needed no pre-1000 date at all.
  Smaller: jsonlite serializes a `Date` through `format.Date`, so item 4's "the
  JSON pads and the CSV does not" was a **macOS-only** split even before item 2
  closed it. An item's severity claim is a hypothesis; this one was wrong in
  both directions at once.

- **A closed item's trace opened a new one, deliberately rather than by
  widening the old.** The item 4 trace found the same *shape* alive under
  `POSIXct` — `datapackage.json` says `0999-06-05 13:45:30`, `dataset.csv` says
  `0999-06-05T13:45:30Z`, and metasalmonpy disagrees with itself on the
  separator *and* the year — filed as **#115**. #93's retire condition names
  `Date` and the SSSOM renderer; quietly widening a condition an item has
  already met is how a retired item comes back without anyone deciding that it
  should.

- **The package now holds two renderers that disagree about `POSIXct` on
  purpose, and that is recorded as a contract rather than as a comment.**
  `.ms_canonical_character()` pads an instant; `.ms_iso_date_columns()` does
  not. The baseline decides, not the type: the first sits on `as.character()`,
  the second on `readr::write_csv()`, whose instant output was measured already
  correct in 2026-08-21. `AGENTS.md` gains the rule and the trap, because the
  two live one `git grep` apart and the symmetric "fix" is the plausible one.

- **The mirror needed no change, measured rather than assumed** — Python's
  `_canonical_bytes()` has built its `cells` once since it was written, and its
  `canonical_value_tokens()` keys through `str()`. What the measurement *did*
  find is a residual spelling difference for non-character SSSOM cells,
  registered as parity row **59** with its `PARITY.md` twin owed, and an
  unpadded-year defect in pandas' `datetime64` `to_csv` path that belongs to
  #115 and to metasalmonpy's own determinism guard.


## 2026-08-24

- **Brett ruled eight of the fourteen open questions; this pass recorded them
  in the cards where the work happens, not only in the index.** Q3 (descriptor
  I-ADOPT keys are permitted, the spec validator learns them), Q4 (the 173-row
  Fraser coho example is the gold standard), Q5 (gcdfo is carved out for exactly
  what the gold standard needs), Q7 (metasalmon releases first, metasalmonpy
  claims that number), Q8 (PFMA Subareas to gcdfo, species to an external
  taxonomy), Q10 (the sequencing membership test governs; the workshop is the
  eighth member), Q11 (`metadata/semantic/**` is adopted into the SDP spec), and
  Q14 (one shared ownership sentinel, breaking change accepted).

- **A ruling deleted a rule, which is the part that is easy to skip.** Q10's
  answer required deleting the roadmap's *input* membership test, not merely
  choosing against it — OD-1 said so as its retirement condition. The two tests
  had coexisted since 2026-08-17 and gave opposite answers for two repositories.
  With one test deleted, `salmon-knowledge-commons`'s admission had to be
  **restated** in sequencing terms, because the sentence that admitted it cited
  the deleted test. That restatement is recorded as the weakest link in the
  ruling rather than smoothed over.

- **A count that nobody owned had drifted into six documents.** "Seven
  repositories" appeared in the domain card, the roadmap's frontmatter, its
  allowlist rule, its release index, the hub-coordination context, and the S6
  card. All now read eight. The 2026-08-14 execplan keeps its dated "seven, not
  six" entry and gains a 2026-08-24 successor entry, because a dated plan records
  what was decided when — but its *reasoning* is now stated in a test that no
  longer governs, which is a decay shape worth naming: an entry can stay true as
  history while its argument stops being usable.

- **One question was answered by rewriting it rather than by ruling on it.**
  Q12 asked where type coercion belongs on the write path, in language that
  assumed context Brett did not have; he reasonably guessed it was about the KNB
  deposit reaching the DataONE CN. It is not — it is about which of R's two
  `Date`-to-text renderers a given code path uses. The rewrite states the three
  symptoms concretely, says plainly that no salmon dataset has a pre-1000 date so
  nothing is broken in practice, names byte reproducibility as what is actually
  at stake, and reduces the ask to one decision. **A question a decider cannot
  parse is not an open decision; it is an unwritten one**, and it had been
  sitting in the open list looking like the former.

- **Q6 was expanded, not answered.** Brett asked for the precise questions,
  recommendations and trade-offs before ruling on smn PR #27. The briefing was
  given and the entry stays open. While recording that, a counting discrepancy
  surfaced in the S9 card: eight decisions live there, but only six are in the
  decision table (rows 1–5 and 8) and two sit in the prose beneath it. Anyone
  counting the table would conclude two were missing; the card now says so.

- **Two rulings created work that lands outside this repository**, so they were
  filed as backlog items with the ruling attached rather than left in the
  questions index: **#113** (one shared package-ownership sentinel, in both
  implementations) and **#114** (adopt `metadata/semantic/**` into
  `smn-data-pkg`). A ruling recorded only in `questions.md` is an index entry
  pointing at nothing.

- **The parity register moved on rows 46 and 51 with no Python PR to ride** —
  the same structural cause as its two historical numbering collisions, in
  content form. Both rows now record a ruling; the twin text was written into
  this pass's pull request for a metasalmonpy agent to apply, and the register
  says the twin is a version behind until it does. The number checker cannot see
  a content lag, which the register already states as its standing limit.


## 2026-08-18

- Currency pass across the bundle plus a sweep to give every known open
  question a recorded home. Verified against the repositories themselves, not
  against a summary — which mattered: two claims handed to this pass were
  wrong in detail and are recorded here in corrected form.

- **What the mirror contract's amendment changed.** Brett's 2026-08-17 ruling
  — *"don't just make things match metasalmon; if the Python implementation got
  it right, then update metasalmon"* — existed only inside a parity-register
  row's prose. It is a **contract** change, so it now sits in `AGENTS.md`, the
  roadmap's mirror rule, the hub-coordination context, and the S10 card. The
  distinction it draws is between *what must be the same* and *which side is
  correct*; those were being read as one rule.

- **A guard claimed more coverage than it had.** `AGENTS.md` said
  `test-role-contract-guard.R` "checks every layer" of the role contract. It
  checks six; `role_boost` — the seventh, named only the day before — is
  guarded in `test-smn-outranks-gcdfo.R`, and the role-contract guard does not
  mention it. True when written, false the moment the seventh surface was
  added without moving its check. This is the failure the guard-expiry
  contract on the same page exists to prevent, committed on the same page.

- **Two "facts" this pass was given did not survive checking**, and both would
  have been written into the bundle unexamined. The Python
  `validate_salmon_datapackage()` divergence is *not* "Python raises where R
  accumulates" — R accumulates **and then aborts**, so its returned issue
  tibble is only ever reachable empty; the real difference is that one R call
  reports every problem typed while Python reports the first, untyped. And
  smn PR #27's own body annotates gcdfo **#74 as "(species)"** when #74 is
  *River Type Life History* — the PR mints the river-type term it declines to
  close.

- **The decay shapes from the 2026-08-17 entry all recurred**, which is
  evidence they are structural rather than incidental. Counts drifted again
  (three R file line counts, a KB figure, a validator count, a call-site
  count, a test count) — every one on a file touched since the last recount.
  A superseded plan kept its old language ("replay the complete baseline"
  after the replay was superseded). And a status line described a first draft
  (smn PR #27's three schemes including species) that had been reworked into
  something materially different — 4 schemes, species withdrawn — the day
  before.

- **A shape not previously named: a fact can rot by being overtaken in a
  *sibling* repo.** The commons went from 4 concepts / 7 gaps to 11 / 24, and
  gained a term lifecycle, between one refresh and the next. Nothing in this
  bundle was wrong when written and nothing here changed; the subject moved.
  The release-index rule already anticipates this for versions — the lesson is
  that it applies to counts and mechanisms too.

## 2026-08-17

- Bundle-wide truth audit against the repositories themselves. The release
  index was re-verified against tags, release objects, and each repo's own
  version source; every backlog open/fixed marker was re-checked against
  `main` in metasalmon, metasalmonpy, and gcdfo; and each sequence card's
  status and blocked-by edges were re-checked against what has shipped.
  Corrections are recorded in the cards themselves, not here — this entry
  exists so the next reader knows when the last full pass happened. Fifteen
  execplans now live in `plans/`.

- **What the pass says about how this bundle decays.** Almost nothing here was
  invented wrong; it was *written true and then overtaken*, and three shapes
  account for most of it. **Precise citations rot fastest** — ten `file:line`
  references in the orientation card had drifted onto unrelated code, so those
  now name functions instead of lines. **Numbers written once are never
  recounted** — every line count in the file map, the PFMA count, the SDP rule
  count, the export count, the `method_iri` blast radius. **A discharged
  blocker is nobody's job to retract** — S8's edge into S4, S6's step-1 block,
  the PSC draft MRs, and the "PR #39 must merge" gate all stayed written after
  the thing they waited on happened. The general form: a card records the
  moment work was planned, and only the *planning* half gets revisited.

## 2026-08-13

- Bundle created by migrating the former `notes/` planning tree: roadmap,
  backlog, orientation, method-model draft, and twelve execplans became
  cards (`git mv`, history preserved). `notes/evidence/theme-a/` stayed
  behind (CI/test-wired, non-Markdown content). The roadmap card gained the
  cross-repo release index and stream S10 (metasalmonpy parity); per-stream
  detail moved into `sequences/` cards. All cards `status: draft`.
