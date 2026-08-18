# Bundle log

## 2026-08-17

- Bundle-wide truth audit against the repositories themselves. The release
  index was re-verified against tags, release objects, and each repo's own
  version source; the backlog's open/fixed markers were re-checked against
  `main` in metasalmon, metasalmonpy, and gcdfo. Corrections are recorded in
  the cards themselves, not here — this entry exists so the next reader knows
  when the last full pass happened. Fifteen execplans now live in `plans/`.

## 2026-08-13

- Bundle created by migrating the former `notes/` planning tree: roadmap,
  backlog, orientation, method-model draft, and twelve execplans became
  cards (`git mv`, history preserved). `notes/evidence/theme-a/` stayed
  behind (CI/test-wired, non-Markdown content). The roadmap card gained the
  cross-repo release index and stream S10 (metasalmonpy parity); per-stream
  detail moved into `sequences/` cards. All cards `status: draft`.
