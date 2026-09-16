# Hand-back patches for shared member repositories

`HUB.md`'s branch-push grant covers only member repositories whose `solo` key is
true in `queue/config.yaml`. For a shared one — `dfo-salmon-ontology`,
`salmon-data-standards-workshop`, `psc-salmon-vocabularies` — the *Hand back*
section says the deliverable is a patch and its pull-request text, shown in chat,
and never a push. `hub done` records the hand-back on the claim ref and keeps the
claim held.

Nothing in that path made the patch itself durable, and that is what this
directory fixes. A hand-back for a shared repository lived in exactly two places,
both of which die with the container: an unpushed branch in a worktree under
`/home/user/hub-worktrees/`, and a diff in the session scratchpad. Measured
2026-09-16, three finished hand-backs were in that state at once — **161 KB of
work across B-0, B-44 and B-150**, every one of it verified with recorded
demonstrations, none of it anywhere a later session could read. The claim ref
proved the work existed and could not produce a line of it.

So: one `git format-patch` output per item, named for the item, applied with

```sh
git -C <checkout-of-the-shared-repo> am /abs/path/to/metasalmon/.hub/handbacks/<id>.patch
```

**The patch path has to be absolute, or relative to the target checkout.** Git
processes its own `-C <path>` before the `am` subcommand, so a path written
relative to this repository is opened underneath the *other* checkout and the
command fails with `could not open ... for reading`. Found by a Codex review of
pull request 135, on the first version of this file, which had exactly that bug.

Four things about the shape are load bearing.

- **The patch is `format-patch` output, not `diff` output.** It carries the
  commit messages and authorship, so the hand-back arrives as the commits the
  agent actually wrote rather than as one squashed blob somebody has to describe
  again.
- **Hub coordination files are excluded** — the export is
  `format-patch ... -- . ':(exclude).hub'`. Two reasons, and the second is the
  one that bites. A workpad is *our* record of how the work was done, not a
  contribution to somebody else's repository, so it has no business in their
  history. And B-0 and B-44 were both written before `B-140` moved workpads to
  per-item paths, so both created `.hub/workpad.md`: applying both in either
  order gave an add/add conflict, and with B-44 first the conflict landed inside
  B-0's *only* commit and stopped its actual fix from applying at all. Also found
  by that Codex review. The reports live at `.hub/workpads/<id>.md` instead.
- **It is a record, not a second source of truth.** The item's `retires_when`
  still says what has to become true, and the workpad under `.hub/workpads/`
  still holds the report and the demonstrations. A patch here that disagrees with
  the workpad is the patch being stale, and the remedy is to re-export it.
- **`.hub` is in `.Rbuildignore`**, so none of this reaches the package tarball.
  Check that line is still there before adding a large file.

## B-0 and B-150 interact, and the order is not free

**Apply B-0 first, and when you do, delete the failure branch from B-150's
hook.** These two patches are each correct alone and wrong together, which is
the one thing a per-item directory makes easy to miss.

B-150 rewrites the `ontology-ci` pre-commit entry so a failing `make ci` fails
the push, and restores `docs/webvowl/data/ontology.json` **only** on failure:

```sh
ci_status=$?; if [ "$ci_status" -ne 0 ]; then git checkout -- docs/webvowl/data/ontology.json; fi; exit "$ci_status"
```

B-0 makes `docs-widoco` restore the **pre-run working-tree bytes** on failure,
through an `EXIT` trap. Brett ruled option (b) on 2026-09-14 precisely so that a
developer's local baseline may differ from `HEAD` — repeated local refreshes
compare against the previous local run. So once B-0 has landed, a failing
`make ci` restores the developer's pre-run bytes and B-150's line then replaces
them with `HEAD`, destroying the baseline B-0 exists to protect. It is not
merely a redundant second restorer; in the case option (b) was chosen to
support, it is destructive.

**B-150's own patch says so**, in the retirement note it ships:

> Retires when: that 2026-08-16 tech-debt entry retires. Its fix makes
> `docs-widoco` restore the pre-run bytes itself on failure, at which point the
> failure branch below has nothing left to do and it, and this note, are deleted
> rather than left as a second restorer.

B-0 **is** that fix, and `B-150`'s queue item already carries the sequencing
("land (b) after B-0 or record why it is safe without it"). What nobody had
written down is that the note understates it — "nothing left to do" reads as
harmless, and it is not.

**The patches are left exactly as they were verified, deliberately.** Removing
that line would be a change nobody can re-run here: demonstrating either half of
B-150 needs a local ROBOT and Java toolchain, and demonstrating B-0's trap needs
WIDOCO. Editing a verified hand-back and still calling it verified is the failure
this repository cares most about, so the interaction is recorded instead and the
edit belongs to whoever applies them with a toolchain. Found by a Codex review of
pull request 135, which read the two patches against each other — something no
single item's review would have done.

*Retires when:* a hand-back to a shared member repository has a durable home
that is not this repository — most likely a pull request opened from a fork, once
that is a thing the grant permits and someone has ruled it is wanted. At that
point the pull request is the artifact and a patch file beside it is a second
copy that can rot. Until then, deleting a patch here means deleting the only
copy, so a patch retires when its item reaches `done` and not before.
