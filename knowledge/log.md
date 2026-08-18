# Bundle log

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
