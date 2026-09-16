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
git -C <checkout-of-the-shared-repo> am .hub/handbacks/<id>.patch
```

Three things about the shape are load bearing.

- **The patch is `format-patch` output, not `diff` output.** It carries the
  commit messages and authorship, so the hand-back arrives as the commits the
  agent actually wrote rather than as one squashed blob somebody has to describe
  again.
- **It is a record, not a second source of truth.** The item's `retires_when`
  still says what has to become true, and the workpad under `.hub/workpads/`
  still holds the report and the demonstrations. A patch here that disagrees with
  the workpad is the patch being stale, and the remedy is to re-export it.
- **`.hub` is in `.Rbuildignore`**, so none of this reaches the package tarball.
  Check that line is still there before adding a large file.

*Retires when:* a hand-back to a shared member repository has a durable home
that is not this repository — most likely a pull request opened from a fork, once
that is a thing the grant permits and someone has ruled it is wanted. At that
point the pull request is the artifact and a patch file beside it is a second
copy that can rot. Until then, deleting a patch here means deleting the only
copy, so a patch retires when its item reaches `done` and not before.
