# Bundle log

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
