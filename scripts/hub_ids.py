#!/usr/bin/env python3
"""Suggest an unreserved ID from fetched refs and this clone's worktrees.

Usage: python3 scripts/hub_ids.py B       # next observed B number
       python3 scripts/hub_ids.py B-427   # where this ID is already seen
       python3 scripts/hub_ids.py B Q     # several queries, one snapshot

Read-only: no fetch, claim, reservation, promotion, or GitHub API call. Fetch
origin first. Other clones' unpublished work and future concurrent writes are
unseen. Retires when queue IDs are allocated atomically by the owning system.
Exit 0: suggestions / all IDs unseen; 1: any ID seen; 3: incomplete or invalid.
"""

from __future__ import annotations

import argparse
import os
from pathlib import Path
import re
import subprocess
import sys


ITEM = re.compile(r"queue/items/([BQS]-[0-9]+)\.yaml\Z")
HEADING = re.compile(r"^#{1,6}\s+(?:([BQS])-?([0-9]+)|#([0-9]+))\b")
SOURCES = ("knowledge/questions.md", "knowledge/backlog.md")


def git(repo: Path, *args: str) -> bytes:
    # An inherited git environment must not redirect this read to another repo.
    env = {key: value for key, value in os.environ.items() if not key.startswith("GIT_")}
    # Missing objects in a promisor clone must fail rather than trigger a fetch.
    # https://git-scm.com/docs/git#Documentation/git.txt-codeGITNOLAZYFETCHcode
    env["GIT_NO_LAZY_FETCH"] = "1"
    env["GIT_OPTIONAL_LOCKS"] = "0"
    result = subprocess.run(["git", "-C", str(repo), *args], env=env,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
    if result.returncode:
        raise RuntimeError(f"git {args[0]} failed in {repo}: "
                           + os.fsdecode(result.stderr).strip())
    return result.stdout


def headings(text: str) -> set[str]:
    result = set()
    for line in text.splitlines():
        match = HEADING.match(line)
        if match:
            prefix, number, legacy = match.groups()
            result.add(f"{prefix or 'B'}-{int(number or legacy)}")
    return result


def scan(repo: Path) -> tuple[dict[str, set[str]], int, int]:
    found: dict[str, set[str]] = {}

    def add(item: str, source: str) -> None:
        prefix, number = item.split("-")
        found.setdefault(f"{prefix}-{int(number)}", set()).add(source)

    refs = os.fsdecode(git(repo, "for-each-ref", "--format=%(objectname) %(refname)",
                           "refs/heads", "refs/remotes")).splitlines()
    if not refs:
        raise RuntimeError("no local or fetched remote refs; reach is unverified")
    trees: dict[str, list[tuple[str, str]]] = {}
    blobs: dict[str, set[str]] = {}
    for record in refs:
        oid, ref = record.split(" ", 1)
        if oid not in trees:
            roots = git(repo, "ls-tree", "-z", oid, "--", "queue", "knowledge")
            for entry in roots.split(b"\0"):
                if entry and entry.split(b"\t", 1)[0].split()[1] != b"tree":
                    raise RuntimeError(f"unsupported source root: {ref}:{os.fsdecode(entry)}")
            tree = git(repo, "ls-tree", "-r", "-z", oid, "--", "queue/items", *SOURCES)
            trees[oid] = []
            for entry in tree.split(b"\0"):
                if not entry:
                    continue
                metadata, raw_path = entry.split(b"\t", 1)
                mode, kind, blob = os.fsdecode(metadata).split()
                path = os.fsdecode(raw_path)
                if path == "queue/items":
                    raise RuntimeError(f"unsupported item directory: {ref}:{path}")
                if ITEM.fullmatch(path) or path in SOURCES:
                    if kind != "blob" or mode not in ("100644", "100755"):
                        raise RuntimeError(f"unsupported source type: {ref}:{path}")
                    trees[oid].append((path, blob))
        for path, blob in trees[oid]:
            match = ITEM.fullmatch(path)
            if match:
                add(match.group(1), f"{ref}:{path}")
            else:
                if blob not in blobs:
                    blobs[blob] = headings(git(repo, "cat-file", "blob", blob).decode("utf-8"))
                for item in blobs[blob]:
                    add(item, f"{ref}:{path}")

    worktrees = [Path(os.fsdecode(record)[9:]) for record in
                git(repo, "worktree", "list", "--porcelain", "-z").split(b"\0")
                if record.startswith(b"worktree ")]
    for root in worktrees:
        if not root.is_dir():
            raise RuntimeError(f"registered worktree is inaccessible: {root}")
        for source in ("queue", "queue/items", "knowledge", *SOURCES):
            if (root / source).is_symlink():
                raise RuntimeError(f"symlink source location is unsupported: {root / source}")
        items = root / "queue/items"
        try:
            files = list(items.iterdir())
        except FileNotFoundError:
            files = []
        for file in files:
            match = ITEM.fullmatch(f"queue/items/{file.name}")
            if match:
                add(match.group(1), f"worktree:{file}")
        for source in SOURCES:
            file = root / source
            try:
                text = file.read_text(encoding="utf-8")
            except FileNotFoundError:
                continue
            for item in headings(text):
                add(item, f"worktree:{file}")
    if not found:
        raise RuntimeError("no IDs found in source locations; reach is unverified")
    return found, len(refs), len(worktrees)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("id_or_prefix", nargs="+", help="B, Q, S, or IDs such as B-427")
    parser.add_argument("--repo", type=Path, default=Path(__file__).resolve().parent.parent)
    args = parser.parse_args(argv)
    matches = [re.fullmatch(r"([BQS])(?:-([0-9]+))?", item) for item in args.id_or_prefix]
    if any(match is None for match in matches):
        print("unknown: expected B, Q, S, or an ID such as B-427", file=sys.stderr)
        return 3
    try:
        found, refs, worktrees = scan(args.repo)
    except (OSError, UnicodeError, RuntimeError, ValueError) as error:
        print(f"unknown: {error}", file=sys.stderr)
        return 3
    # Check every requested prefix before emitting any suggestion. An incomplete
    # batch must not leave an apparently usable partial allocation behind.
    suggestions = {}
    for match in matches:
        prefix, number = match.groups()
        if number is None:
            numbers = [int(item.split("-")[1]) for item in found if item.startswith(prefix + "-")]
            if not numbers:
                print(f"unknown: no {prefix} positive control in source locations", file=sys.stderr)
                return 3
            suggestions[prefix] = max(numbers) + 1
    print(f"Scanned {refs} fetched/local refs and {worktrees} registered worktrees.")
    print("Fetch first. Suggestions are unreserved; other clones' unpublished work is unseen.")
    seen = False
    for match in matches:
        prefix, number = match.groups()
        if number is None:
            print(f"Next observed {prefix} suggestion: {prefix}-{suggestions[prefix]}")
            continue
        item = f"{prefix}-{int(number)}"
        sources = sorted(found.get(item, ()))
        print(f"{item}: {'seen' if sources else 'unseen in this snapshot'}")
        for source in sources[:8]:
            print(f"  {source}")
        if len(sources) > 8:
            print(f"  ... {len(sources) - 8} further source locations")
        seen = seen or bool(sources)
    return 1 if seen else 0


if __name__ == "__main__":
    sys.exit(main())
