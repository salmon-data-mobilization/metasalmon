# Bundle log

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
