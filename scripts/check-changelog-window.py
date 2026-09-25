#!/usr/bin/env python3
"""Fail when a line under a released changelog heading is not in that release.

AGENTS.md's Releases section carries the rule, accepted by Brett on
2026-09-16: a change that merges after the commit that bumped the version and
before that version's tag exists is filed under the development heading --
never under the version it did not ship in -- and the tag stays on the bump
commit. The window opens on every release, because the tag is a separate act
from the bump. On metasalmonpy `main` it was missed within a minute of
opening: B-144's merge `b939fd9` landed 21 seconds after the bump merge
`67fb486`, descends from it, and filed its entry under `## 0.5.0`. A sentence
did not stop that, so this is the rule's mechanical form (hub item B-200).

What it checks
--------------
For every released version heading in the changelog at the revision checked:

1. The BUMP COMMIT is the version's `vX.Y.Z` tag when one exists, and
   otherwise the first commit on the first-parent history of the checked
   revision whose version file reads that version -- the open window between
   bump and tag. First-parent, because that is the commit that made the
   version current on `main`, which is where AGENTS.md says the tag belongs;
   measured 2026-09-25, it is exactly the commit each of metasalmon's five
   `v*` tags names.
   One exception, because without it this check arrives red on `main`: an
   untagged version that a later version has superseded will never have a
   tag (AGENTS.md: 0.2.0 to 0.2.6 are deliberately untagged history), and it
   is measured as it stood at the LAST commit whose version file read it.
   Before the rule, entries accumulated under a version's heading while it
   stood: measured 2026-09-25, 0.1.6 gained lines from pull request #7 and
   0.2.4 from #16 and #17 after their bump commits, 49 lines in all, and the
   first-commit reading fails `main` on them. While a version is current its
   window is open and the first commit rules, so continuous integration sees
   such a line when it is written; a line added under a superseded version
   after it was superseded is still a finding. *Retires when:* no superseded,
   untagged heading holds a line added after its first commit -- in practice
   never while 0.1.6 and 0.2.4 keep theirs, since AGENTS.md rules out tagging
   them; it is the reading of fixed history, not a hole with an end date.
2. The section as it stood at the bump commit is diffed against the section
   as it stands now. A line the diff inserts is ADDED. A run that replaces
   shipped lines stands for them one for one -- the lines that keep the most
   of them, in order -- and only the lines by which it outgrows them are
   added.
3. An added line is a FINDING when `git blame` attributes it to a commit that
   is not an ancestor of the bump commit (`git merge-base --is-ancestor`):
   the line was not in the tree the release names. Blame is asked as well as
   the diff because a heading renamed after the bump leaves the section
   absent at the bump commit; the lines that were there, under the
   development heading, are blamed on ancestors and pass.

THE EXEMPTION, which is a marker and not a hole. A marked, dated correction to
a shipped entry is not a finding, because the Releases section admits exactly
that: a `*(Correction, YYYY-MM-DD: ...)*` paragraph appended to an entry, or a
`[corrected YYYY-MM-DD: ...]` bracket inserted into one. An added line is
exempt when such a marker, closed by its matching bracket inside its own
paragraph, covers any part of it. An undated or unclosed marker exempts
nothing, and an unmarked paragraph is a finding. `--no-exemption` switches it
off to show what it is holding: on 2026-09-25 metasalmon `main` passed with it
and failed without it, on the three corrections dated 2026-08-24 under 0.4.0.

WHAT IT DOES NOT COVER. A guard whose claimed scope exceeds its real scope is
worse than none, so:

* A line changed in place under a released heading is not a finding, so a
  typo fix to a shipped entry stays possible -- and so does any rewrite that
  keeps to the lines it replaced, including one that turns a shipped bullet
  into a description of new work.
* A paragraph carrying the correction marker passes whatever it says,
  including new work, and so does text sharing a line with a marker.
  Reading catches those; this check does not.
* A line added to an untagged version while it stood, after its bump, passes
  once a later version supersedes it (see 1), including one that was red when
  it merged and was merged anyway. A version that is tagged is not forgiven:
  its tag is its bump for good.
* A deleted line is never a finding, and a blank line is never checked.
* A heading with no bump commit is not checked: a version older than the
  history (metasalmon 0.0.1 to 0.1.2 predate its first commit), or one no
  version file has read yet. Those are listed in the output rather than
  skipped silently, and a run that could check no released heading at all
  cannot run rather than passes.
* The tag is trusted. A tag on the wrong commit makes this measure the wrong
  tree; AGENTS.md says which commit a tag belongs on.
* It reads a committed revision, never the working tree.

Usage
-----
    python3 scripts/check-changelog-window.py
    python3 scripts/check-changelog-window.py --rev REV --no-exemption
    python3 scripts/check-changelog-window.py --profile metasalmonpy

With no arguments it checks `NEWS.md` at `HEAD` in this repository. The
`metasalmonpy` profile reads `CHANGELOG.md` and `pyproject.toml` in the checkout
named by `METASALMONPY_PATH`, defaulting to `../metasalmonpy`, the way
`check-parity-registers.py` reaches its twin: that is B-201's replay, and the
reason the profiles exist. `--repo` names any other checkout.

Exits 0 with no findings, 1 on any finding, and 2 when it cannot run -- not a
git repository, a shallow clone (blame and ancestry need the whole history), no
changelog, or nothing it could check. A history it cannot see must never look
like a history that is clean.

*Retires when:* the changelog stops being written by hand -- generated at
release from what the tag contains -- so that a line cannot be filed under a
version it did not ship in.
"""

from __future__ import annotations

import argparse
import difflib
import os
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

EXIT_OK = 0
EXIT_FINDINGS = 1
EXIT_CANNOT_RUN = 2

ROOT = Path(__file__).resolve().parent.parent

# A released heading names a version that is tagged `vX.Y.Z`. Any other label
# -- the development heading, `Unreleased` -- bounds a section and is not
# checked.
RELEASED = re.compile(r"^\d+\.\d+\.\d+$")
SETEXT_UNDERLINE = re.compile(r"^(?:-{3,}|={3,})\s*$")

# The two correction markers, each with the bracket pair that closes it.
MARKERS = (
    (re.compile(r"\*\(Correction, \d{4}-\d{2}-\d{2}:"), "(", ")"),
    (re.compile(r"\[corrected \d{4}-\d{2}-\d{2}:"), "[", "]"),
)

BLAME_HEADER = re.compile(r"^([0-9a-f]{40,64}) \d+ (\d+)(?: \d+)?$")


@dataclass(frozen=True)
class Profile:
    changelog: str
    version_file: str
    version: re.Pattern
    # Group 1 is an ATX prefix, absent for a setext heading; group 2 the label.
    heading: re.Pattern
    sibling_env: str | None = None
    sibling_dir: str | None = None


PROFILES = {
    # `metasalmon 0.5.0` over a line of dashes, below `metasalmon (development
    # version)`. The ATX form `# metasalmon 0.5.0` is read too.
    "metasalmon": Profile(
        changelog="NEWS.md",
        version_file="DESCRIPTION",
        version=re.compile(r"^Version:\s*(\S+)\s*$", re.M),
        heading=re.compile(r"^(#{1,2}\s+)?metasalmon\s+(\S.*?)\s*$"),
    ),
    # For B-201: `## 0.5.0` below `## Unreleased`, the version in pyproject.toml.
    "metasalmonpy": Profile(
        changelog="CHANGELOG.md",
        version_file="pyproject.toml",
        version=re.compile(r"^version\s*=\s*[\"']([^\"']+)[\"']", re.M),
        heading=re.compile(r"^(##\s+)(\S.*?)\s*$"),
        sibling_env="METASALMONPY_PATH",
        sibling_dir="metasalmonpy",
    ),
}


class CannotRun(Exception):
    """The check could not see what it needs. Never to be read as a pass."""


@dataclass(frozen=True)
class Finding:
    heading: str
    version: str
    line: int  # 1-based, in the changelog at the checked revision
    text: str
    commit: str
    bump: str
    how: str


def git(repo: Path, *args: str) -> str:
    done = subprocess.run(
        ["git", "-C", str(repo), *args],
        capture_output=True, encoding="utf-8", errors="replace",
    )
    if done.returncode != 0:
        raise CannotRun(f"git {' '.join(args)} failed: {done.stderr.strip()}")
    return done.stdout


def read_blobs(repo: Path, specs: list[str]) -> list[str | None]:
    """The text of each `rev:path`, or None where there is no such file."""
    if not specs:
        return []
    done = subprocess.run(
        ["git", "-C", str(repo), "cat-file", "--batch"],
        input=("\n".join(specs) + "\n").encode(), capture_output=True,
    )
    if done.returncode != 0:
        raise CannotRun(f"git cat-file failed: {done.stderr.decode(errors='replace').strip()}")
    data, pos, out = done.stdout, 0, []
    for _ in specs:
        end = data.index(b"\n", pos)
        header = data[pos:end].split()
        pos = end + 1
        if len(header) != 3:  # "<spec> missing"
            out.append(None)
            continue
        size = int(header[2])
        body = data[pos:pos + size]
        pos += size + 1
        out.append(body.decode("utf-8", "replace") if header[1] == b"blob" else None)
    return out


def split_lines(text: str) -> list[str]:
    """Lines as git numbers them: split on newline only.

    Not `str.splitlines()`, which also splits on a form feed or U+2028 and
    would put every later line out of step with blame's line numbers.
    """
    lines = text.split("\n")
    if lines and lines[-1] == "":
        lines.pop()
    return [line[:-1] if line.endswith("\r") else line for line in lines]


def sections(profile: Profile, text: str) -> tuple[dict[str, tuple[str, int, list[str]]], list[str]]:
    """Each heading's label -> (its heading line, index of its first body line, its body lines).

    The second value lists labels that head more than one section; only the
    first of them is kept.
    """
    lines = split_lines(text)
    heads = []  # (heading line index, label, first body line index)
    for i, line in enumerate(lines):
        m = profile.heading.match(line)
        if not m:
            continue
        if m.group(1):
            heads.append((i, m.group(2), i + 1))
        elif i + 1 < len(lines) and SETEXT_UNDERLINE.match(lines[i + 1]):
            heads.append((i, m.group(2), i + 2))
    found: dict[str, tuple[str, int, list[str]]] = {}
    repeated = []
    for n, (at, label, body) in enumerate(heads):
        end = heads[n + 1][0] if n + 1 < len(heads) else len(lines)
        if label in found:
            repeated.append(label)
        else:
            found[label] = (lines[at], body, lines[body:end])
    return found, repeated


def bump_commits(repo: Path, rev: str, profile: Profile,
                 versions: list[str]) -> dict[str, tuple[str, str]]:
    """Each version that has one -> (its bump commit, how that was decided).

    The tag when there is one. Otherwise the version file on the first-parent
    history decides: the FIRST commit reading the version while it is still
    the one the checked revision reads -- the open window -- and the LAST
    commit that read it once a later version has superseded it untagged.
    """
    found = {}
    for version in versions:
        done = subprocess.run(
            ["git", "-C", str(repo), "rev-parse", "-q", "--verify",
             f"refs/tags/v{version}^{{commit}}"],
            capture_output=True, text=True,
        )
        if done.returncode == 0:
            found[version] = (done.stdout.strip(), f"tag v{version}")
    wanted = set(versions) - set(found)
    if wanted:
        chain = git(repo, "rev-list", "--first-parent", "--reverse", rev).split()
        texts = read_blobs(repo, [f"{c}:{profile.version_file}" for c in chain])
        first: dict[str, str] = {}
        last: dict[str, str] = {}
        current = None
        for commit, text in zip(chain, texts):
            m = profile.version.search(text) if text else None
            current = m.group(1) if m else None
            if current in wanted:
                first.setdefault(current, commit)
                last[current] = commit
        for version in wanted & set(first):
            if version == current:
                found[version] = (
                    first[version],
                    f"no tag yet; the first commit on the first-parent history "
                    f"whose {profile.version_file} reads {version}",
                )
            else:
                found[version] = (
                    last[version],
                    f"never tagged, and superseded; the last commit on the "
                    f"first-parent history whose {profile.version_file} read {version}",
                )
    return found


def blame(repo: Path, rev: str, path: str) -> dict[int, str]:
    """Line number -> the commit that put that line where it is."""
    # `--ignore-revs-file=` with nothing after it empties any list configured
    # by blame.ignoreRevsFile. An ignored revision's lines are attributed to an
    # earlier commit, which would hide the very commits this check looks for:
    # measured 2026-09-25 with git 2.43, a configured list naming 0909953 left
    # none of its nine NEWS.md lines attributed to it, and this option all nine.
    out = git(repo, "blame", "--porcelain", "--ignore-revs-file=", rev, "--", path)
    commits = {}
    for line in out.split("\n"):
        m = BLAME_HEADER.match(line)
        if m:
            commits[int(m.group(2))] = m.group(1)
    return commits


def most_alike(old: list[str], new: list[str]) -> set[int]:
    """The len(old) indices into `new`, in order, whose lines best match `old`.

    Needs len(new) >= len(old). Likeness is how many characters of the old
    line the new one keeps, summed over the pairs and maximised, so that a
    line edited in place is the one standing for the line it replaced and the
    line written beside it is the one added.

    Characters kept, not difflib's ratio: the ratio divides by both lengths,
    so a short line sharing a few words outscores the long line that was
    edited. Measured 2026-09-25 on NEWS.md's 0.4.0 correction at line 1664,
    where the ratio paired the shipped line with the correction's closing line
    (0.554 against 0.541) and reported the edited line as the one added.
    """
    k, n = len(old), len(new)
    worst = float("-inf")
    score = [[0.0] * (n + 1)] + [[worst] * (n + 1) for _ in range(k)]
    paired = [[False] * (n + 1) for _ in range(k + 1)]
    for i in range(1, k + 1):
        for j in range(i, n + 1):
            skip = score[i][j - 1]
            kept = difflib.SequenceMatcher(None, old[i - 1], new[j - 1], autojunk=False)
            pair = score[i - 1][j - 1] + sum(b.size for b in kept.get_matching_blocks())
            score[i][j], paired[i][j] = (pair, True) if pair >= skip else (skip, False)
    kept, i, j = set(), k, n
    while i > 0:
        if paired[i][j]:
            kept.add(j - 1)
            i -= 1
        j -= 1
    return kept


def added_lines(shipped: list[str], now: list[str]) -> list[int]:
    """Indices into `now` of the lines the diff from `shipped` adds."""
    added = []
    matcher = difflib.SequenceMatcher(None, shipped, now, autojunk=False)
    for op, i1, i2, j1, j2 in matcher.get_opcodes():
        if op == "insert":
            added.extend(range(j1, j2))
        elif op == "replace" and j2 - j1 > i2 - i1:
            kept = most_alike(shipped[i1:i2], now[j1:j2])
            added.extend(j1 + j for j in range(j2 - j1) if j not in kept)
    return added


def closing(text: str, at: int, opener: str, closer: str) -> int | None:
    """Index of the bracket closing the one at `at`, or None if none does."""
    depth = 0
    for pos in range(at, len(text)):
        if text[pos] == opener:
            depth += 1
        elif text[pos] == closer:
            depth -= 1
            if depth == 0:
                return pos
    return None


def marked_lines(body: list[str]) -> set[int]:
    """Indices into `body` of the lines a closed, dated correction marker touches."""
    marked: set[int] = set()
    start = 0
    while start < len(body):
        if not body[start].strip():
            start += 1
            continue
        end = start
        while end < len(body) and body[end].strip():
            end += 1
        paragraph = body[start:end]
        text = "\n".join(paragraph)
        offsets, pos = [], 0
        for line in paragraph:
            offsets.append(pos)
            pos += len(line) + 1
        for pattern, opener, closer in MARKERS:
            for m in pattern.finditer(text):
                close = closing(text, text.index(opener, m.start()), opener, closer)
                if close is None:
                    continue
                for n, offset in enumerate(offsets):
                    if offset <= close and m.start() < offset + len(paragraph[n]):
                        marked.add(start + n)
        start = end
    return marked


def run(repo: Path, rev: str, profile: Profile, exemption: bool) -> int:
    git(repo, "rev-parse", "--git-dir")
    if git(repo, "rev-parse", "--is-shallow-repository").strip() == "true":
        raise CannotRun(
            f"{repo} is a shallow clone, and blame and ancestry need the whole "
            "history. Fetch it (git fetch --unshallow --tags), or check out with "
            "fetch-depth: 0."
        )
    head = git(repo, "rev-parse", "--verify", f"{rev}^{{commit}}").strip()
    (text,) = read_blobs(repo, [f"{head}:{profile.changelog}"])
    if text is None:
        raise CannotRun(f"there is no {profile.changelog} at {rev} in {repo}")
    now, repeated = sections(profile, text)
    released = [label for label in now if RELEASED.match(label)]
    repeated = [label for label in repeated if RELEASED.match(label)]
    if repeated:
        raise CannotRun(f"{profile.changelog} has more than one heading for {', '.join(repeated)}")
    if not released:
        print(f"changelog window: {profile.changelog} at {head[:7]} has no released heading yet")
        return EXIT_OK

    bumps = bump_commits(repo, head, profile, released)
    unchecked = [v for v in released if v not in bumps]
    if not bumps:
        raise CannotRun(
            f"none of the {len(released)} released headings in {profile.changelog} "
            f"has a bump commit on this history: no v* tag, and no "
            f"{profile.version_file} on the first-parent history reads one of "
            "them. Is this the right repository and profile?"
        )
    shas = sorted({sha for sha, _ in bumps.values()})
    at_bump = dict(zip(shas, read_blobs(repo, [f"{s}:{profile.changelog}" for s in shas])))
    blamed = blame(repo, head, profile.changelog)

    findings: list[Finding] = []
    exempt: dict[str, int] = {}
    ancestry: dict[tuple[str, str], bool] = {}
    for version in released:
        if version not in bumps:
            continue
        bump, how = bumps[version]
        shipped_text = at_bump[bump]
        shipped = sections(profile, shipped_text)[0] if shipped_text else {}
        title, body_at, body = now[version]
        marked = marked_lines(body) if exemption else set()
        for index in added_lines(shipped.get(version, ('', 0, []))[2], body):
            if not body[index].strip():
                continue
            line = body_at + index + 1
            commit = blamed.get(line)
            if commit is None:
                raise CannotRun(f"blame gave no commit for {profile.changelog}:{line}")
            if (commit, bump) not in ancestry:
                done = subprocess.run(
                    ["git", "-C", str(repo), "merge-base", "--is-ancestor", commit, bump],
                    capture_output=True, text=True,
                )
                if done.returncode not in (0, 1):
                    raise CannotRun(f"git merge-base --is-ancestor failed: {done.stderr.strip()}")
                ancestry[(commit, bump)] = done.returncode == 0
            if ancestry[(commit, bump)]:
                continue
            if index in marked:
                exempt[version] = exempt.get(version, 0) + 1
                continue
            findings.append(Finding(title, version, line, body[index], commit, bump, how))

    checked = len(released) - len(unchecked)
    print(f"changelog window: {profile.changelog} at {head[:7]}, "
          f"{checked} released heading{'s' if checked != 1 else ''} checked"
          + ("" if exemption else ", with the correction exemption switched off"))
    for version in released:
        if version in bumps:
            bump, how = bumps[version]
            note = f"; {exempt[version]} added lines exempt as marked corrections" if version in exempt else ""
            print(f"  {version:<8} {bump[:7]}  {how}{note}")
    if unchecked:
        print(f"not checked, no bump commit on this history ({len(unchecked)}): "
              + " ".join(unchecked))
    if not findings:
        print("no findings")
        return EXIT_OK

    report(profile, findings)
    return EXIT_FINDINGS


def report(profile: Profile, findings: list[Finding]) -> None:
    groups: list[list[Finding]] = []
    for f in findings:
        last = groups[-1][-1] if groups else None
        if last and (last.version, last.commit, last.line + 1) == (f.version, f.commit, f.line):
            groups[-1].append(f)
        else:
            groups.append([f])
    err = sys.stderr
    err.write(f"\nchangelog window: {len(findings)} line"
              f"{'s' if len(findings) != 1 else ''} under a released heading "
              "missed that release\n")
    for group in groups:
        first, last = group[0], group[-1]
        where = f"{first.line}" if first is last else f"{first.line}-{last.line}"
        err.write(
            f"  {profile.changelog}:{where} under \"{first.heading}\", "
            f"added by {first.commit[:7]}, which is not an ancestor of {first.version}'s "
            f"bump commit {first.bump[:7]} ({first.how}):\n"
        )
        for f in group[:5]:
            err.write(f"      {f.text}\n")
        if len(group) > 5:
            err.write(f"      ... and {len(group) - 5} more lines\n")
    err.write(
        "\nA line under a released heading has to be in the tree that release names:\n"
        "its vX.Y.Z tag, or, before the tag exists, the commit that bumped the version.\n"
        "AGENTS.md, Releases: a change that merged after that commit is filed under the\n"
        "development heading, never under a version it did not ship in, so move it\n"
        "there. A correction to a shipped entry is the one exception, marked and dated\n"
        "so it can be told apart: a *(Correction, YYYY-MM-DD: ...)* paragraph, or a\n"
        "[corrected YYYY-MM-DD: ...] bracket.\n"
    )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Fail when a line under a released changelog heading is not in that release.",
    )
    parser.add_argument("--profile", choices=sorted(PROFILES), default="metasalmon")
    parser.add_argument("--repo", help="the checkout to read (default: this repository, "
                        "or METASALMONPY_PATH for the metasalmonpy profile)")
    parser.add_argument("--rev", default="HEAD", help="the revision to check (default: HEAD)")
    parser.add_argument("--no-exemption", action="store_true",
                        help="treat marked corrections as findings, to see what the exemption holds")
    args = parser.parse_args(argv)
    profile = PROFILES[args.profile]
    if args.repo:
        repo = Path(args.repo)
    elif profile.sibling_env:
        repo = Path(os.environ.get(profile.sibling_env) or ROOT.parent / profile.sibling_dir)
    else:
        repo = ROOT
    try:
        return run(repo, args.rev, profile, exemption=not args.no_exemption)
    except CannotRun as err:
        sys.stderr.write(f"changelog window: cannot run: {err}\n")
        return EXIT_CANNOT_RUN


if __name__ == "__main__":
    raise SystemExit(main())
