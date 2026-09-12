#!/usr/bin/env python3
"""Validate the hub queue and regenerate the prose blocks that restate it.

WHY THIS EXISTS
---------------
Section 9.1 of `knowledge/plans/2026-09-04-salmon-science-foundry-concrete-plan.md`
measured the failure this program is the answer to. On 2026-09-05 the bundle
restated metasalmon's current version in 10 files across 25+ mentions, and 5 of
them were wrong; S10's "done" status lived in 4 files and 2 were wrong; the
mirror window was in 5 files and 1 was wrong. Roughly a quarter of the bundle's
8,901 non-plan lines was planning state, and that quarter took 134 commits since
2026-07-01 to keep almost-current.

The design's answer is that planning state lives in exactly one place -- one
YAML file per work item under `queue/items/` -- and every prose
restatement of a state fact becomes a generated block. `check` is the only
mechanism in the whole design that actually stops the measured drift: without a
build that fails, a stale copy waits for a reader to notice, which is precisely
what produced the five wrong version lines.

WHAT THIS PROGRAM DOES NOT DO, stated plainly, because a guard whose claimed
scope exceeds its real scope is worse than no guard:

  * It never reads or writes a git ref. Claiming is a `git push` of an orphan
    commit (section 9.4) and belongs to the `hub` client, not here.
  * It never makes a network call of any kind, and never touches the GitHub API.
  * It cannot tell whether an item's *content* is true. It checks that the queue
    is well formed, internally consistent, and that the prose agrees with it.
    An item can be perfectly valid and describe work that finished last week.
  * It does not check prose outside the generated markers. A hand-written
    sentence restating a state fact is exactly the defect being migrated away
    from, and this program cannot see it. Only moving the sentence inside
    markers puts it under the check.

RETIRES WHEN
------------
This program retires when planning state stops living in files under
`queue/` -- for instance if the queue moves into a database or a
service. Rewriting the queue's storage retires it; changing the schema does not.
The retirement-debt ratchet (below) has its own, narrower retirement condition.

THE SCHEMA, fixed so every builder agrees
-----------------------------------------
One YAML document per file, one scalar per line at column 0, `blocked_by` in
inline flow style only. That is a deliberate restriction rather than an
accident: it makes a small exact parser possible, so this program reads what is
on the page instead of approximating YAML. A file that needs a nested structure
is a file that has outgrown the queue.

    id: B-53                      # B-<n> backlog, S-<n> stream, Q-<n> question
    kind: defect                  # defect | stream | question
    title: One line, no trailing period
    state: icebox                 # icebox | ready | claimed | needs_brett | review | done
    claimable: true               # false for question items and for anything needing a credential
    repo: metasalmon              # repository where the work happens
    stream: S1                    # owning stream, or omit
    severity: P2                  # defects only: P0 P1 P2 P3 P4
    blocked_by: [B-90, S-12]      # inline flow only; [] when none
    legacy: '#53'                 # the bare citation this item preserves
    evidence: knowledge/backlog.md # path from the REPOSITORY ROOT (must exist), or an https:// URL
    retires_when: Sentence saying what makes this item stop existing
    venue: claude-code            # claude-science | claude-code | either, or omit

Trailing comments are stripped from *unquoted* values at the first ` #`. A value
that contains `#` must therefore be quoted, which is why `legacy` is written
`'#53'`. An unquoted value beginning with `#` is rejected rather than silently
read as an empty string. Inside a quoted value, YAML's own escapes are honoured:
`''` for an apostrophe in a single-quoted scalar, a backslash escape in a
double-quoted one. A `retires_when` sentence reaches for a possessive apostrophe
almost immediately, so this is the common case rather than the exotic one.

GENERATED BLOCKS
----------------
A block is delimited by `<!-- hub:generated:<name> -->` and
`<!-- /hub:generated:<name> -->`. Bytes outside those markers are never
touched. The names are:

  * `ready-queue`       what an agent may pick up now
  * `stream-status`     every stream and its state
  * `open-defects`      defects not yet done
  * `needs-brett`       what is waiting on a decision or a credential
  * `queue-summary`     counts by state and by kind
  * `retirement-debt`   the ratchet number and what it means
  * `member-count`      how many repositories the hub coordinates
  * `items:<params>`    a filtered view, params as `key=value` separated by `,`

The first four are the names `queue/config.yaml` declares, and each is
an alias for an `items:` query rather than a separate generator, so a reader can
see exactly which items a named block stands for.

`member-count` is the one block whose source is not an item file: it counts the
allowlist rows in `knowledge/domains/salmon-data-ecosystem.md`. That is a
deliberate exception rather than the start of a habit. Blocks derive from the
queue because the queue is where planning state lives; the member count lives in
the domain card because membership is a ruling and not a piece of work, and the
count drifted anyway when the ninth member was admitted on 2026-09-05.

`items:` params are field filters (`state=ready`, `kind=defect`,
`state=ready|claimed` for alternatives, `stream=S1`, `severity=P0|P1`) plus four
reserved keys: `format` (`list`, `table`, `ids`; default `list`), `sort` (a
field name; default id order), `fields` (pipe-separated column names for
`format=table`), and `empty` (the sentence used when nothing matches).

Ordering is by id -- prefix then integer -- and every other sort is a plain
codepoint sort, never a locale-dependent one, so the rendered bytes are the same
on every machine.

THREE CROSS-CHECKS BEYOND THE ITEMS
-----------------------------------
`lint` and `check` compare the `members:` list in `queue/config.yaml` against
the allowlist table in `knowledge/domains/salmon-data-ecosystem.md`. The
configuration says in its own comment that its copy is safe only because this
guard compares the two, and a claim like that has to be true or deleted.

`lint` and `check` also compare each member's `solo:` flag against the
participation table in `HUB.md`. `solo` is the one fact the standing write
authorization turns on, so it gets the same treatment as the membership list:
`HUB.md` governs, the configuration is the machine-readable copy, and a
disagreement fails.

A key stated twice inside one member entry, with or without a value the second
time, fails before that comparison runs,
because the `hub` client's own reader of the same block keeps the last
occurrence, and a linter that quietly kept a different one would approve a file
the client does not run. Neither value is read; see `validate_member_fields`.

`check` also reads `generated_blocks:` from the same configuration and fails
when a declared block has no marker pair in its target file. That one is here
because of a defect measured on 2026-09-09: `check` walked the prose, skipped
every file with no marker, found nothing to compare, and printed "OK: every
generated block matches the hub queue" with zero markers in the repository.
A configured block that is missing is an error, never a skip.
"""

from __future__ import annotations

import argparse
import os
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

# --------------------------------------------------------------------------
# Schema constants
# --------------------------------------------------------------------------

KNOWN_KEYS = (
    "id",
    "kind",
    "title",
    "state",
    "claimable",
    "repo",
    "stream",
    "severity",
    "blocked_by",
    "legacy",
    "evidence",
    "retires_when",
    "venue",
)

REQUIRED_KEYS = ("id", "kind", "title", "state", "claimable", "repo", "blocked_by", "evidence")

KINDS = ("defect", "stream", "question")
STATES = ("icebox", "ready", "claimed", "needs_brett", "review", "done")
SEVERITIES = ("P0", "P1", "P2", "P3", "P4")

# Which of Brett's two working surfaces an item wants. Optional, and advice
# rather than a gate: nothing in the `hub` client reads it and no check refuses
# work because of it, because a field that blocks work is a field that gets
# faked. What this program does is keep the vocabulary from drifting, so a
# rendered block can be filtered on it and mean something.
#
# RETIRES WHEN: the field stops changing a decision. If a season passes in which
# every item is `either`, delete `venue` from `KNOWN_KEYS`, from the item files
# and from `queue/README.md` rather than maintaining a field nobody routes on.
VENUES = ("claude-science", "claude-code", "either")

# id prefix -> the one kind it may carry.
PREFIX_KIND = {"B": "defect", "S": "stream", "Q": "question"}
PREFIX_ORDER = {"B": 0, "S": 1, "Q": 2}

ID_RE = re.compile(r"^([BSQ])-(\d+)$")
KEY_LINE_RE = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*):(.*)$")
FLOW_RE = re.compile(r"^\[(.*)\]$")

# An absolute filesystem path anywhere under `knowledge/` is a bundle-rule
# violation. Matches `~/...`, a Windows drive path, and a token that begins at a
# word boundary with `/` followed by a path segment. `refs/heads/claim` and
# `P0/P1` do not match because neither begins with a slash.
ABS_PATH_RE = re.compile(
    r"(?:^|[\s(\[\"'`])(?P<hit>~/\S*|[A-Za-z]:[\\/]\S*|/[A-Za-z0-9_.\-]+(?:/\S*)?)"
)

# The retirement-debt ratchet: the number of `kind: defect` items allowed to
# carry no `retires_when`. It exists because the backlog being migrated carried
# 34 retirement conditions across 119 items on 2026-09-05, and a day-one hard
# failure would have blocked the migration the check protects.
#
# The number itself is deliberately NOT in this file. It lives in one text file
# that this program reads, so tightening the ratchet is a one-line commit a
# reviewer can read at a glance rather than a code change. A baseline compiled
# in here is a baseline nobody lowers, and the version of this program that
# carried 85 while the real debt was 0 had 85 slack: 85 new defects could have
# arrived with no `retires_when` and lint would still have printed OK.
#
# There is no fallback number. A missing or unparseable baseline file is an
# error, because falling back to a constant would restore exactly that slack.
#
# RETIRES WHEN: the recorded baseline has been 0 long enough that the migration
# is plainly finished, at which point `retires_when` moves into `REQUIRED_KEYS`
# for `kind: defect` and this ratchet, the `--retirement-debt-baseline` flag,
# the `retirement-debt` block and the baseline file are all deleted together.
RETIREMENT_DEBT_BASELINE_FILE = "scripts/hub-retirement-debt-baseline.txt"

DEFAULT_QUEUE_DIR = "queue/items"

# Where `render` and `check` look for generated blocks. Kept as an explicit list
# rather than a whole-repo walk so the set of files under the freshness check is
# something a reader can enumerate.
DEFAULT_PROSE_ROOTS = ("HUB.md", "AGENTS.md", "README.md", "knowledge")

# Directories never scanned for markers: `docs/` is pkgdown output, and the
# queue itself is the source rather than a restatement of it.
PROSE_SKIP_DIRS = {".git", "docs", "renv", "node_modules", "queue"}

BLOCK_RE = re.compile(
    r"(?P<open><!--[ \t]*hub:generated:(?P<name>[^\s>]+?)[ \t]*-->)"
    r"(?P<body>.*?)"
    r"(?P<close><!--[ \t]*/hub:generated:(?P=name)[ \t]*-->)",
    re.DOTALL,
)
OPEN_MARKER_RE = re.compile(r"<!--[ \t]*hub:generated:([^\s>]+?)[ \t]*-->")
CLOSE_MARKER_RE = re.compile(r"<!--[ \t]*/hub:generated:([^\s>]+?)[ \t]*-->")

RENDER_COMMAND = "python3 scripts/hub_queue.py render"
DO_NOT_EDIT = (
    "<!-- Generated from the hub queue. Edit the queue file, not this block; "
    "regenerate with `" + RENDER_COMMAND + "`. -->"
)


# --------------------------------------------------------------------------
# Parsing
# --------------------------------------------------------------------------


@dataclass
class Item:
    """One parsed queue file. `raw` keeps the strings exactly as written."""

    path: str
    raw: dict = field(default_factory=dict)
    lines: dict = field(default_factory=dict)

    @property
    def id(self) -> str:
        return self.raw.get("id", "")

    @property
    def kind(self) -> str:
        return self.raw.get("kind", "")

    @property
    def state(self) -> str:
        return self.raw.get("state", "")

    def get(self, key, default=""):
        value = self.raw.get(key, default)
        return default if value is None else value

    def sort_key(self):
        match = ID_RE.match(self.id)
        if match:
            return (PREFIX_ORDER.get(match.group(1), 9), int(match.group(2)), self.id)
        return (9, 0, self.id)


@dataclass
class Problem:
    path: str
    line: int
    rule: str
    message: str

    def render(self) -> str:
        where = self.path if self.line == 0 else f"{self.path}:{self.line}"
        return f"{where}: [{self.rule}] {self.message}"


class BlockError(Exception):
    """A condition that stops the program rather than adding to a report.

    Raised for a block name that cannot be rendered, a marker pair that does not
    nest, and a retirement-debt baseline that cannot be read. `main` turns it
    into exit status 2 with the message on the first line.
    """


def strip_comment(value: str) -> str:
    """Strip a trailing ` #` comment from an unquoted scalar.

    Quoted scalars are returned untouched so `legacy: '#53'` survives. This is
    the one place the parser is lossy, which is why an unquoted value beginning
    with `#` is rejected upstream rather than silently becoming empty.
    """
    idx = value.find(" #")
    if idx >= 0:
        value = value[:idx]
    return value.strip()


def parse_scalar(raw: str):
    """Return (value, error) for the text to the right of a `key:`.

    `value` is a str, a bool, a list of str for flow style, or None on error.
    """
    text = raw.strip()
    if text == "":
        return None, "empty value"
    if text.startswith("#"):
        return None, "value begins with '#'; quote it (for example legacy: '#53')"

    if text[0] in "'\"":
        quote = text[0]
        # YAML escapes a quote inside a single-quoted scalar by doubling it, and
        # inside a double-quoted scalar with a backslash. Both appear in real
        # queue files the moment a `retires_when` sentence contains a possessive
        # apostrophe, so both are read here. Missing this looked like five
        # "trailing text after quoted value" errors on otherwise correct items.
        chars = []
        index = 1
        end = -1
        while index < len(text):
            char = text[index]
            if char == quote:
                if quote == "'" and text[index : index + 2] == "''":
                    chars.append("'")
                    index += 2
                    continue
                end = index
                break
            if char == "\\" and quote == '"' and index + 1 < len(text):
                chars.append(text[index + 1])
                index += 2
                continue
            chars.append(char)
            index += 1
        if end < 0:
            return None, "unterminated quoted value"
        rest = text[end + 1 :].strip()
        if rest and not rest.startswith("#"):
            return None, f"trailing text after quoted value: {rest!r}"
        return "".join(chars), None

    flow = FLOW_RE.match(strip_comment(text))
    if flow:
        inner = flow.group(1).strip()
        if inner == "":
            return [], None
        parts = [part.strip() for part in inner.split(",")]
        if any(part == "" for part in parts):
            return None, "empty entry in inline list"
        return parts, None

    if text.lstrip().startswith("-"):
        return None, "block-style list; use inline flow style, for example [B-90, S-12]"

    stripped = strip_comment(text)
    if stripped == "":
        return None, "value is only a comment"
    if stripped in ("true", "false"):
        return stripped == "true", None
    if stripped in ("True", "False", "yes", "no", "on", "off"):
        return None, f"use lowercase true/false, not {stripped!r}"
    return stripped, None


def parse_item_file(path: Path, display: str) -> tuple[Item, list[Problem]]:
    """Parse one queue file with the fixed one-scalar-per-line reader."""
    item = Item(path=display)
    problems: list[Problem] = []
    try:
        text = path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        problems.append(Problem(display, 0, "encoding", "file is not valid UTF-8"))
        return item, problems

    source_lines = text.splitlines()
    index = 0
    while index < len(source_lines):
        line = source_lines[index]
        number = index + 1
        index += 1
        if "\t" in line:
            problems.append(Problem(display, number, "tab", "tab character; the schema is spaces only"))
            continue
        if line.strip() == "":
            continue
        if line.strip() in ("---", "..."):
            continue
        if line.lstrip().startswith("#"):
            continue
        if line[0] in " \t":
            problems.append(
                Problem(
                    display,
                    number,
                    "indent",
                    "indented line; the schema is one scalar per line at column 0",
                )
            )
            continue
        match = KEY_LINE_RE.match(line)
        if not match:
            problems.append(Problem(display, number, "syntax", f"not a `key: value` line: {line!r}"))
            continue
        key, rest = match.group(1), match.group(2)
        if key in item.raw:
            problems.append(Problem(display, number, "duplicate-key", f"key {key!r} appears twice"))
            continue
        value, error = parse_scalar(rest)
        if error == "empty value":
            # A bare `key:` followed by indented `- item` lines is YAML block
            # style. The schema is inline flow only, so say that rather than
            # reporting an empty value and then an indent error for each entry:
            # the reader needs the one sentence that tells them what to write.
            consumed = 0
            while index + consumed < len(source_lines):
                nxt = source_lines[index + consumed]
                if nxt.strip() == "":
                    break
                if not (nxt[:1] in " \t" and nxt.lstrip().startswith("-")):
                    break
                consumed += 1
            if consumed:
                index += consumed
                error = "block-style list; use inline flow style, for example [B-90, S-12]"
        if error:
            problems.append(Problem(display, number, "value", f"{key}: {error}"))
            continue
        item.raw[key] = value
        item.lines[key] = number

    return item, problems


# --------------------------------------------------------------------------
# Loading and validation
# --------------------------------------------------------------------------


def find_item_files(queue_dir: Path) -> list[Path]:
    if not queue_dir.is_dir():
        return []
    files = [p for p in queue_dir.iterdir() if p.is_file() and p.suffix in (".yaml", ".yml")]
    return sorted(files, key=lambda p: p.name)


def load_queue(root: Path, queue_dir: Path) -> tuple[list[Item], list[Problem]]:
    items: list[Item] = []
    problems: list[Problem] = []
    for path in find_item_files(queue_dir):
        display = relative(path, root)
        item, file_problems = parse_item_file(path, display)
        problems.extend(file_problems)
        items.append(item)
    items.sort(key=lambda i: i.sort_key())
    return items, problems


def relative(path: Path, root: Path) -> str:
    try:
        return str(path.resolve().relative_to(root.resolve()))
    except ValueError:
        return str(path)


def check_absolute_paths(item: Item) -> list[Problem]:
    problems = []
    for key in sorted(item.raw):
        value = item.raw[key]
        values = value if isinstance(value, list) else [value]
        for element in values:
            if not isinstance(element, str):
                continue
            hit = ABS_PATH_RE.search(" " + element)
            if hit:
                problems.append(
                    Problem(
                        item.path,
                        item.lines.get(key, 0),
                        "absolute-path",
                        f"{key} contains an absolute filesystem path {hit.group('hit')!r}; "
                        "knowledge/ is repo-relative only",
                    )
                )
    return problems


# An `evidence` value that names a URL rather than a path. Only the shape is
# checked and nothing is fetched: this program makes no network call, and a
# lint that needs the network fails offline for reasons that have nothing to do
# with the queue. `EVIDENCE_SCHEME_RE` recognises any `scheme://` so that a
# `http://` or `file://` pointer is refused by name rather than resolved as the
# local path `<root>/http:/...` and reported as missing, which is what happened
# to the documented `https://` form until 2026-09-10.
EVIDENCE_SCHEME_RE = re.compile(r"^([A-Za-z][A-Za-z0-9+.\-]*)://")
EVIDENCE_WHITESPACE_RE = re.compile(r"\s")


def evidence_url_problem(value: str) -> str | None:
    """Why `value` is not an acceptable evidence URL, or None when it is one.

    Called only for a value `EVIDENCE_SCHEME_RE` matched. Accepts `https://`, a
    non-empty host, and a path naming something on that host, with no
    whitespace anywhere. That is the whole check: it kills the malformed
    pointer, not the dangling one, because finding out whether the page is
    still there would take a network call and lint stays offline.
    """
    scheme = EVIDENCE_SCHEME_RE.match(value).group(1)
    if scheme.lower() != "https":
        return (
            f"uses the scheme {scheme!r}; evidence in another repository is written "
            "as a full https:// URL, and no other scheme is accepted"
        )
    if EVIDENCE_WHITESPACE_RE.search(value):
        return "contains whitespace, so it is not one URL"
    host, _, path = value[len(scheme) + len("://") :].partition("/")
    if not host:
        return "has no host after https://"
    if not path:
        return (
            "has no path; a pointer at a whole host names nothing an item can be "
            "checked against"
        )
    return None


def check_evidence_exists(item: Item, root: Path) -> list[Problem]:
    """`evidence` must name something that is really there, from the repo root.

    WHY THIS RULE EXISTS. Every item carries one pointer to where its detail
    lives, and that pointer is the only thing standing between a queue entry and
    a sentence nobody can check. Nothing verified it until 2026-09-10. On
    2026-09-09 all 55 item files were rewritten from bundle-relative
    (`backlog.md`) to repository-root-relative (`knowledge/backlog.md`) pointers,
    and the inconsistency that made that rewrite necessary was caught by a human
    reading the files. A rule that only a careful reader enforces is a rule that
    holds until the first tired reader, and a broken pointer is invisible: the
    item still parses, still renders, still shows up in the ready queue, and only
    fails when somebody follows it.

    WHAT IT CHECKS: for a path, that `root / evidence` exists. A directory
    counts, because a pointer at a directory of evidence is a legitimate pointer.
    For a URL, only its shape; see below.

    WHAT IT DOES NOT CHECK, said plainly: whether the file says anything about
    this item. `evidence: knowledge/backlog.md` passes for an item the backlog
    never mentions, and nothing here can see that. This rule kills the dangling
    pointer, not the irrelevant one.

    A `#fragment` is trimmed before resolving, so `knowledge/backlog.md#B-53`
    resolves to the file. The scalar parser strips a ` #` comment (space then
    hash), so a fragment with no space in front of it survives to here.

    An absolute path is left alone: `check_absolute_paths` already reports it,
    and a second problem on the same line tells the reader nothing new.

    A path that resolves outside the repository root fails under its own rule
    name. `../psc-data-systems/...` is a real sibling checkout on Brett's
    machine and nowhere else, so a pointer that leaves the repository is a
    pointer that resolves for exactly one person, which is the same defect as an
    absolute path wearing relative clothes.

    A `https://` URL is the one form that is not a path. `queue/README.md`
    allows it for evidence that genuinely lives in another repository, and
    until 2026-09-10 this rule resolved it anyway, as `<root>/https:/...`, and
    reported the documented form as missing, so the allowance existed on paper
    and no item could have used it (Codex, pull request #110). A URL is
    accepted on its shape alone, checked by `evidence_url_problem`: `https://`,
    a host, a path naming something on that host, no whitespace. `http://` and
    every other scheme are refused by name, under `evidence-url`. Nothing is
    fetched, because this program makes no network call, so for a URL this rule
    kills the malformed pointer and not the dangling one: a well-shaped URL at a
    page that has been deleted passes, and only a reader following it finds out.

    RETIRES WHEN: `evidence` stops being a filesystem path or a URL. If it
    becomes an item id or a bundle-internal anchor, this rule is replaced by
    whatever checks that instead, and is not merely deleted: the dangling
    pointer it catches does not go away with the change of notation. The URL
    branch retires on its own if lint is ever allowed on the network, at which
    point the shape check becomes a fetch and a dangling URL fails like a
    dangling path.
    """
    value = item.raw.get("evidence")
    if not isinstance(value, str) or not value:
        return []
    if ABS_PATH_RE.search(" " + value):
        return []
    line = item.lines.get("evidence", 0)

    if EVIDENCE_SCHEME_RE.match(value):
        reason = evidence_url_problem(value)
        if reason is None:
            return []
        return [Problem(item.path, line, "evidence-url", f"evidence {value!r} {reason}")]

    target = value.split("#", 1)[0].strip()
    if not target:
        return [
            Problem(
                item.path,
                line,
                "evidence-missing",
                f"evidence {value!r} is only a fragment; it must name a file or "
                "directory relative to the repository root",
            )
        ]

    resolved = (root / target).resolve()
    try:
        resolved.relative_to(root.resolve())
    except ValueError:
        return [
            Problem(
                item.path,
                line,
                "evidence-escapes-root",
                f"evidence {target!r} resolves outside the repository root; a "
                "pointer that leaves the repository resolves on one machine only",
            )
        ]
    if not resolved.exists():
        return [
            Problem(
                item.path,
                line,
                "evidence-missing",
                f"evidence {target!r} does not exist; the pointer is resolved from "
                "the repository root, not from the item file and not from knowledge/",
            )
        ]
    return []


def validate(items: list[Item], root: Path) -> tuple[list[Problem], int]:
    """Return (problems, retirement_debt).

    Every rule here has a RED demonstration in `scripts/tests/test_hub_queue.py`.
    A rule with no demonstration is a rule nobody has tested.
    """
    problems: list[Problem] = []
    by_id: dict[str, Item] = {}
    by_legacy: dict[str, Item] = {}
    retirement_debt = 0

    for item in items:
        path, lines = item.path, item.lines

        for key in sorted(item.raw):
            if key not in KNOWN_KEYS:
                problems.append(
                    Problem(path, lines.get(key, 0), "unknown-key", f"unknown key {key!r}")
                )

        for key in REQUIRED_KEYS:
            if key not in item.raw:
                problems.append(Problem(path, 0, "missing-key", f"required key {key!r} is missing"))

        problems.extend(check_absolute_paths(item))
        problems.extend(check_evidence_exists(item, root))

        item_id = item.raw.get("id")
        prefix = None
        if isinstance(item_id, str):
            match = ID_RE.match(item_id)
            if not match:
                problems.append(
                    Problem(
                        path,
                        lines.get("id", 0),
                        "id-format",
                        f"id {item_id!r} is not B-<n>, S-<n> or Q-<n>",
                    )
                )
            else:
                prefix = match.group(1)
                stem = Path(path).stem
                if stem != item_id:
                    problems.append(
                        Problem(
                            path,
                            0,
                            "filename",
                            f"file name stem {stem!r} does not match id {item_id!r}; "
                            "one item per file, named for its id",
                        )
                    )
                if item_id in by_id:
                    problems.append(
                        Problem(
                            path,
                            lines.get("id", 0),
                            "duplicate-id",
                            f"id {item_id!r} is already used by {by_id[item_id].path}",
                        )
                    )
                else:
                    by_id[item_id] = item

        kind = item.raw.get("kind")
        if kind is not None and kind not in KINDS:
            problems.append(
                Problem(
                    path,
                    lines.get("kind", 0),
                    "kind",
                    f"kind {kind!r} is not one of {', '.join(KINDS)}",
                )
            )
        elif prefix and kind and PREFIX_KIND[prefix] != kind:
            problems.append(
                Problem(
                    path,
                    lines.get("kind", 0),
                    "id-kind",
                    f"id prefix {prefix!r} means kind {PREFIX_KIND[prefix]!r}, not {kind!r}",
                )
            )

        state = item.raw.get("state")
        if state is not None and state not in STATES:
            problems.append(
                Problem(
                    path,
                    lines.get("state", 0),
                    "state",
                    f"state {state!r} is not one of {', '.join(STATES)}",
                )
            )

        claimable = item.raw.get("claimable")
        if claimable is not None and not isinstance(claimable, bool):
            problems.append(
                Problem(
                    path,
                    lines.get("claimable", 0),
                    "claimable-type",
                    f"claimable must be true or false, not {claimable!r}",
                )
            )
        elif state == "needs_brett" and claimable is True:
            problems.append(
                Problem(
                    path,
                    lines.get("claimable", 0),
                    "needs-brett-claimable",
                    "state needs_brett requires claimable: false; an agent cannot "
                    "make a decision only Brett can make",
                )
            )

        severity = item.raw.get("severity")
        if kind == "defect":
            if severity is None:
                problems.append(
                    Problem(path, 0, "severity-missing", "kind: defect requires a severity")
                )
            elif severity not in SEVERITIES:
                problems.append(
                    Problem(
                        path,
                        lines.get("severity", 0),
                        "severity",
                        f"severity {severity!r} is not one of {', '.join(SEVERITIES)}",
                    )
                )
            if not isinstance(item.raw.get("retires_when"), str) or not item.raw.get("retires_when"):
                retirement_debt += 1
        elif severity is not None:
            problems.append(
                Problem(
                    path,
                    lines.get("severity", 0),
                    "severity-scope",
                    f"severity is for defects only; kind is {kind!r}",
                )
            )

        venue = item.raw.get("venue")
        if venue is not None and venue not in VENUES:
            problems.append(
                Problem(
                    path,
                    lines.get("venue", 0),
                    "venue",
                    f"venue {venue!r} is not one of {', '.join(VENUES)}; the field is "
                    "advice about which surface the work wants, and a value outside "
                    "the vocabulary cannot be read as advice or as anything else",
                )
            )

        title = item.raw.get("title")
        if isinstance(title, str) and title.endswith("."):
            problems.append(
                Problem(path, lines.get("title", 0), "title", "title has a trailing period")
            )

        legacy = item.raw.get("legacy")
        if isinstance(legacy, str) and legacy:
            if legacy in by_legacy:
                problems.append(
                    Problem(
                        path,
                        lines.get("legacy", 0),
                        "duplicate-legacy",
                        f"legacy citation {legacy!r} is already claimed by {by_legacy[legacy].path}; "
                        "a bare citation must resolve to exactly one item",
                    )
                )
            else:
                by_legacy[legacy] = item

        blocked_by = item.raw.get("blocked_by")
        if blocked_by is not None and not isinstance(blocked_by, list):
            problems.append(
                Problem(
                    path,
                    lines.get("blocked_by", 0),
                    "blocked-by-style",
                    "blocked_by must be inline flow style, for example [] or [B-90, S-12]",
                )
            )

    # Second pass: blocked_by targets must exist. Needs every id loaded first.
    for item in items:
        blocked_by = item.raw.get("blocked_by")
        if not isinstance(blocked_by, list):
            continue
        for target in blocked_by:
            if target not in by_id:
                problems.append(
                    Problem(
                        item.path,
                        item.lines.get("blocked_by", 0),
                        "blocked-by-missing",
                        f"blocked_by names {target!r}, which is not an item in the queue",
                    )
                )

    problems.sort(key=lambda p: (p.path, p.line, p.rule, p.message))
    return problems, retirement_debt


def read_baseline(root: Path, override: int | None) -> tuple[int, str]:
    """Return (baseline, where it came from), or raise `BlockError`.

    The first line that is neither blank nor a `#` comment is the number, so the
    file can explain itself and still be tightened by editing one line.
    """
    if override is not None:
        return override, "--retirement-debt-baseline"
    path = root / RETIREMENT_DEBT_BASELINE_FILE
    if not path.is_file():
        raise BlockError(
            f"{RETIREMENT_DEBT_BASELINE_FILE} is missing, so the retirement-debt "
            "ratchet has no recorded baseline. Count the defects with no "
            "`retires_when` and write that number into the file, or pass "
            "--retirement-debt-baseline for a one-off run. There is deliberately "
            "no built-in default: a default here is slack nobody can see."
        )
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        try:
            return int(line), RETIREMENT_DEBT_BASELINE_FILE
        except ValueError:
            break
    raise BlockError(
        f"{RETIREMENT_DEBT_BASELINE_FILE} carries no baseline: the first line that "
        "is neither blank nor a comment must be a whole number and nothing else."
    )


# --------------------------------------------------------------------------
# Block rendering
# --------------------------------------------------------------------------


def parse_block_name(name: str) -> tuple[str, dict]:
    if ":" not in name:
        return name, {}
    head, _, tail = name.partition(":")
    params: dict[str, str] = {}
    for chunk in tail.split(","):
        chunk = chunk.strip()
        if not chunk:
            continue
        if "=" not in chunk:
            raise BlockError(f"block parameter {chunk!r} is not key=value")
        key, _, value = chunk.partition("=")
        params[key.strip()] = value.strip()
    return head, params


RESERVED_PARAMS = ("format", "sort", "fields", "empty")

# The four block names `queue/config.yaml` declares, as (head, params).
# They are aliases rather than separate generators so there is one rendering
# path and a named block can be read as the `items:` query it stands for.
#
# RETIRES WHEN: a name here is removed from `generated_blocks` in the queue
# configuration and no prose file still carries its markers.
BLOCK_ALIASES = {
    "ready-queue": (
        "items",
        {
            "state": "ready",
            "claimable": "true",
            "empty": (
                "_Nothing is ready to claim right now._ `ready` is set by a commit on "
                "`main`; agents do not push there, so the queue grows only when Brett "
                "promotes an item."
            ),
        },
    ),
    "stream-status": (
        "items",
        {"kind": "stream", "format": "table", "fields": "id|title|state|blocked_by"},
    ),
    "open-defects": (
        "items",
        {
            "kind": "defect",
            "state": "icebox|ready|claimed|review",
            "format": "table",
            "fields": "id|severity|title|state|blocked_by",
            "empty": "_No open defects._",
        },
    ),
    "needs-brett": (
        "items",
        {
            "state": "needs_brett",
            "format": "table",
            "fields": "id|kind|title|repo",
            "empty": "_Nothing is waiting on Brett._",
        },
    ),
}


def matches(item: Item, params: dict) -> bool:
    for key, spec in params.items():
        if key in RESERVED_PARAMS:
            continue
        value = item.raw.get(key)
        if isinstance(value, bool):
            value = "true" if value else "false"
        if isinstance(value, list):
            value = ",".join(value)
        alternatives = [a.strip() for a in spec.split("|")]
        if str(value or "") not in alternatives:
            return False
    return True


def escape_cell(text: str) -> str:
    return str(text).replace("|", "\\|")


def render_items_block(items: list[Item], params: dict) -> list[str]:
    for key in params:
        if key not in RESERVED_PARAMS and key not in KNOWN_KEYS:
            raise BlockError(f"filter key {key!r} is not a schema field")

    selected = [item for item in items if matches(item, params)]
    sort_field = params.get("sort")
    if sort_field:
        if sort_field not in KNOWN_KEYS:
            raise BlockError(f"sort key {sort_field!r} is not a schema field")
        # Codepoint sort, never locale-dependent, with id as the tie-break so
        # the rendered bytes are identical on every machine.
        selected.sort(key=lambda i: (str(i.get(sort_field)), i.sort_key()))

    if not selected:
        return [params.get("empty", "_No items match._")]

    fmt = params.get("format", "list")
    if fmt == "ids":
        return [", ".join(item.id for item in selected)]
    if fmt == "list":
        out = []
        for item in selected:
            bits = [f"- **{item.id}** — {item.get('title')}"]
            tail = []
            if item.get("severity"):
                tail.append(item.get("severity"))
            tail.append(item.get("state"))
            if item.get("repo"):
                tail.append(item.get("repo"))
            blocked = item.raw.get("blocked_by") or []
            if blocked:
                tail.append("blocked by " + ", ".join(blocked))
            if item.raw.get("claimable") is False:
                tail.append("not claimable")
            bits.append(" (" + ", ".join(tail) + ")")
            out.append("".join(bits))
        return out
    if fmt == "table":
        fields = params.get("fields", "id|title|state|severity|blocked_by")
        columns = [c.strip() for c in fields.split("|") if c.strip()]
        for column in columns:
            if column not in KNOWN_KEYS:
                raise BlockError(f"table column {column!r} is not a schema field")
        out = ["| " + " | ".join(columns) + " |", "|" + "---|" * len(columns)]
        for item in selected:
            cells = []
            for column in columns:
                value = item.raw.get(column)
                if isinstance(value, bool):
                    value = "true" if value else "false"
                elif isinstance(value, list):
                    value = ", ".join(value) if value else "—"
                cells.append(escape_cell(value if value not in (None, "") else "—"))
            out.append("| " + " | ".join(cells) + " |")
        return out
    raise BlockError(f"unknown format {fmt!r}; use list, table or ids")


def render_summary_block(items: list[Item]) -> list[str]:
    out = ["| State | Items | of which defects |", "|---|---|---|"]
    for state in STATES:
        in_state = [i for i in items if i.state == state]
        defects = [i for i in in_state if i.kind == "defect"]
        out.append(f"| {state} | {len(in_state)} | {len(defects)} |")
    out.append(f"| **total** | **{len(items)}** | **{len([i for i in items if i.kind == 'defect'])}** |")
    return out


def render_debt_block(items: list[Item], baseline: int, source: str) -> list[str]:
    debt = sum(
        1
        for i in items
        if i.kind == "defect" and not (isinstance(i.raw.get("retires_when"), str) and i.raw.get("retires_when"))
    )
    return [
        f"Defects with no `retires_when`: **{debt}**. The recorded baseline is "
        f"**{baseline}** (from `{source}`), and lint fails when the count rises above it.",
        "",
        "This is a ratchet rather than a hard rule because the backlog it was "
        "migrated from carried 34 retirement conditions across 119 items on "
        "2026-09-05, and failing on day one would block the migration the check "
        "exists to protect. It retires when the count reaches 0, at which point "
        "`retires_when` becomes a hard requirement and the ratchet is deleted.",
    ]


# Spelled out to twenty, because the sentence this renders is read aloud in
# prose and "The ecosystem has 9 member repositories" is not how the rest of the
# bundle writes. Past twenty the digits win, which is the same rule the prose
# uses.
NUMBER_WORDS = (
    "zero", "one", "two", "three", "four", "five", "six", "seven", "eight",
    "nine", "ten", "eleven", "twelve", "thirteen", "fourteen", "fifteen",
    "sixteen", "seventeen", "eighteen", "nineteen", "twenty",
)


def render_member_count_block(root: Path) -> list[str]:
    """How many repositories the hub coordinates, counted from the domain card.

    This is the one generated block whose source is the card rather than an item
    file. It is here because the count is the fact that actually drifted: the
    bundle said eight after `salmon-science-foundry` was admitted on 2026-09-05,
    and the sentence looked exactly as right as it had the week before. Counting
    the allowlist rows at render time means a hand edit fails the build.

    RETIRES WHEN: no prose restates the member count, or the allowlist stops
    living in a Markdown table that can be counted.
    """
    card_path = root / DOMAIN_CARD_FILE
    if not card_path.is_file():
        raise BlockError(
            f"the member count is derived from {DOMAIN_CARD_FILE}, which is not "
            "present, so the block cannot be rendered"
        )
    repos = read_card_allowlist(card_path)
    if not repos:
        raise BlockError(
            f"no allowlist rows could be read from {DOMAIN_CARD_FILE}, so the "
            "member count would render as zero and read as a fact rather than as "
            "a parse failure"
        )
    count = len(repos)
    word = NUMBER_WORDS[count] if count < len(NUMBER_WORDS) else str(count)
    noun = "member repository" if count == 1 else "member repositories"
    return [f"The salmon data ecosystem has **{word}** {noun}."]


def render_block(name: str, items: list[Item], baseline: int, source: str, root: Path) -> list[str]:
    if name in BLOCK_ALIASES:
        head, params = BLOCK_ALIASES[name]
    else:
        head, params = parse_block_name(name)
    if head == "items":
        return render_items_block(items, params)
    if head == "queue-summary":
        return render_summary_block(items)
    if head == "retirement-debt":
        return render_debt_block(items, baseline, source)
    if head == "member-count":
        return render_member_count_block(root)
    raise BlockError(
        f"unknown block name {name!r}; known blocks are "
        + ", ".join(sorted(BLOCK_ALIASES))
        + ", queue-summary, retirement-debt, member-count and items:<key=value,...>"
    )


# --------------------------------------------------------------------------
# The members cross-check
# --------------------------------------------------------------------------
#
# `queue/config.yaml` carries a machine-readable copy of the eight-row
# allowlist whose home is `knowledge/domains/salmon-data-ecosystem.md`, and it
# says in its own comment that the copy "is safe only because the
# render-and-check guard compares the two and fails when they disagree". This is
# that comparison. Without it that sentence is false, and a false claim about a
# guard is the failure mode this repository has already shipped once.
#
# The card wins when the two disagree; the configuration copy is the wrong one.
#
# WHAT IT DOES NOT CHECK: only the set of repository names. It never reads
# `org` or `forge`, which the card's table does not state in a machine-readable
# column, so a member sitting under the wrong organisation or the wrong forge
# passes this check. The GitLab member matters for the authorization boundary,
# so that field is verified by reading, not here.
#
# RETIRES WHEN: the `members:` block is deleted from the queue configuration
# because the client reads the allowlist from the card directly, which the
# configuration already names as its own retirement condition.

QUEUE_CONFIG_FILE = "queue/config.yaml"
DOMAIN_CARD_FILE = "knowledge/domains/salmon-data-ecosystem.md"

CONFIG_MEMBER_RE = re.compile(r"^\s*-\s*repo:\s*(\S+)\s*$")
# A field line is any indented `key:` line, WITH OR WITHOUT a value. The value
# is optional because the `hub` client's reader matches on the key alone
# (`/^[ \t]+[A-Za-z_]+:/`) and reassigns the value to whatever follows the
# colon, which for a bare `solo:` is the empty string. The first version of
# the duplicate check below required a value, so `solo: true` followed by a
# bare `solo:` was one sighting to this program and two to the client, and
# lint printed OK on a file the client read as `solo` empty (found in review
# of pull request #110, 2026-09-10). A value-less line has to count.
CONFIG_FIELD_RE = re.compile(r"^\s+([A-Za-z_][A-Za-z0-9_]*):(.*)$")
CARD_ROW_RE = re.compile(r"^\|\s*`([^`]+)`[^|]*\|")


@dataclass
class MemberRow:
    """One `- repo:` entry from the queue configuration, with its line number.

    `fields` maps a key to `(value, line)` for every key the entry states
    exactly once. `duplicates` maps a key the entry states more than once to
    every line it appears on, and such a key is absent from `fields`: neither
    occurrence is the value, because the two readers of this file would pick
    different ones. See `validate_member_fields` for why that is the rule.
    """

    repo: str
    line: int
    fields: dict = field(default_factory=dict)
    duplicates: dict = field(default_factory=dict)


def read_config_member_rows(path: Path) -> list[MemberRow]:
    """Parse the `members:` block into rows.

    ONE parser, read by both the membership cross-check and the `solo`
    cross-check. A second parser of the same block would be a second reading of
    the same bytes, which is the shape of defect this whole program exists to
    remove, reproduced inside the program that removes it.
    """
    rows: list[MemberRow] = []
    inside = False
    for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        if line.startswith("members:"):
            inside = True
            continue
        if not inside:
            continue
        if line and not line[0].isspace() and not line.lstrip().startswith("#"):
            break
        match = CONFIG_MEMBER_RE.match(line)
        if match:
            row = MemberRow(repo=match.group(1), line=number)
            # `repo` is a field like any other to the client, which reassigns it
            # on a later `repo:` line inside the entry, so it is seeded here and
            # a restatement counts as a duplicate rather than as a new member.
            row.fields["repo"] = (row.repo, number)
            rows.append(row)
            continue
        if not rows:
            continue
        field_match = CONFIG_FIELD_RE.match(line)
        if field_match and not line.lstrip().startswith("#"):
            key, value = field_match.group(1), strip_comment(field_match.group(2))
            row = rows[-1]
            if key in row.fields or key in row.duplicates:
                # A second sighting. Record every line and keep NO value: the
                # `hub` client keeps the last and this program used to keep the
                # first, and whichever one is chosen here is a claim about which
                # one the client runs. `validate_member_fields` reports it.
                seen = row.duplicates.setdefault(key, [])
                if key in row.fields:
                    seen.append(row.fields.pop(key)[1])
                seen.append(number)
                continue
            row.fields[key] = (value, number)
    return rows


def read_config_members(path: Path) -> list[str]:
    return [row.repo for row in read_config_member_rows(path)]


def read_card_allowlist(path: Path) -> list[str]:
    repos: list[str] = []
    inside = False
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.startswith("| Repo ") or line.startswith("|Repo"):
            inside = True
            continue
        if inside:
            if not line.startswith("|"):
                break
            if set(line.replace("|", "").replace("-", "").strip()) == set():
                continue
            match = CARD_ROW_RE.match(line)
            if match:
                repos.append(match.group(1))
    return repos


def validate_members(root: Path) -> list[Problem]:
    config_path = root / QUEUE_CONFIG_FILE
    if not config_path.is_file():
        return []
    card_path = root / DOMAIN_CARD_FILE
    if not card_path.is_file():
        return [
            Problem(
                QUEUE_CONFIG_FILE,
                0,
                "members-source-missing",
                f"the configuration copies the allowlist from {DOMAIN_CARD_FILE}, "
                "which is not present, so the copy cannot be checked against its source",
            )
        ]

    config_members = read_config_members(config_path)
    card_members = read_card_allowlist(card_path)
    problems: list[Problem] = []
    if not config_members:
        problems.append(
            Problem(
                QUEUE_CONFIG_FILE,
                0,
                "members-unreadable",
                "no `members:` entries found; the cross-check against "
                f"{DOMAIN_CARD_FILE} cannot run, and a check that silently does "
                "nothing is worse than no check",
            )
        )
    if not card_members:
        problems.append(
            Problem(
                DOMAIN_CARD_FILE,
                0,
                "members-unreadable",
                "the allowlist table could not be read, so the configuration copy "
                "cannot be checked against it",
            )
        )
    if problems:
        return problems

    for repo in sorted(set(config_members) - set(card_members)):
        problems.append(
            Problem(
                QUEUE_CONFIG_FILE,
                0,
                "members-drift",
                f"{repo!r} is a member in the configuration but not in the "
                f"{DOMAIN_CARD_FILE} allowlist; the card governs, so remove it here "
                "or add the row there first",
            )
        )
    for repo in sorted(set(card_members) - set(config_members)):
        problems.append(
            Problem(
                QUEUE_CONFIG_FILE,
                0,
                "members-drift",
                f"{repo!r} is in the {DOMAIN_CARD_FILE} allowlist but missing from "
                "the configuration copy; the card governs, so add it here",
            )
        )
    return problems


# --------------------------------------------------------------------------
# The duplicate-field check on one member entry
# --------------------------------------------------------------------------
#
# WHAT THIS GUARDS: two readers of one file disagreeing about the single fact
# the standing grant turns on. `queue/config.yaml` is read by this program and,
# separately, by `members_list()` in the `hub` client, and the two parsers were
# written apart. Until 2026-09-10 this one kept the FIRST occurrence of a
# repeated key (`setdefault`) while the client's awk keeps the LAST, because it
# reassigns on every match. So a member reading
#
#     solo: false
#     solo: true
#
# was `false` to lint, which compared it against `HUB.md`, found the two
# agreed, and printed OK -- and `true` to `hub claim`, which would then push a
# work branch and open a draft pull request into a repository the policy file
# says is shared. The file that passed review was not the file the client ran.
# Reported by Codex on pull request #110; the disagreement was reproduced by
# feeding one fixture to both parsers.
#
# The first version of this check counted only lines that carried a value, so
# `solo: true` followed by a bare `solo:` was one sighting here and two to the
# client, whose reader matches on the key alone and reassigns `solo` to the
# empty string. Lint printed OK; the client answered no. Found in review the
# same day, and it is the same defect one layer down: a reader that agrees
# with the client about the lines it sees, and does not see the same lines.
# `CONFIG_FIELD_RE` now matches a key with or without a value, and a single
# value-less `solo:` is reported by `validate_solo` as unstated.
#
# So a key stated twice in one entry is an error naming the member, the key and
# every line it appears on, and NEITHER value is used: the parser drops the key
# rather than choosing, because whichever occurrence this program chose would
# be a claim about which one the client chooses, and that is the claim that
# was wrong.
#
# WHAT IT DOES NOT CHECK: that the two parsers agree about anything else. A key
# the client reads and this program does not, or a layout one parser accepts
# and the other mis-reads, is not seen here. This is one reader refusing to
# guess, not proof that the readers agree.
#
# RETIRES WHEN: the client and this program share one parser of the members
# block, or the block moves to a format that has exactly one reader. Either
# removes the second reading. Until then a duplicate is the cheapest way for
# the two readers to differ and the most expensive to find, because the file
# looks right to both of them.


def validate_member_fields(root: Path) -> list[Problem]:
    config_path = root / QUEUE_CONFIG_FILE
    if not config_path.is_file():
        return []
    problems: list[Problem] = []
    for row in read_config_member_rows(config_path):
        for key in sorted(row.duplicates):
            lines = [str(number) for number in row.duplicates[key]]
            where = ", ".join(lines[:-1]) + " and " + lines[-1]
            problems.append(
                Problem(
                    QUEUE_CONFIG_FILE,
                    row.duplicates[key][-1],
                    "members-duplicate-field",
                    f"member {row.repo!r} (line {row.line}) sets {key!r} "
                    f"{len(lines)} times, at lines {where}; the `hub` client reads "
                    "the last occurrence and this program refuses to read either, "
                    "so lint cannot approve a file the client would run "
                    "differently. Keep exactly one",
                )
            )
    return problems


# --------------------------------------------------------------------------
# The solo-participation cross-check
# --------------------------------------------------------------------------
#
# `solo` is the single fact the standing write authorization turns on: whether
# anybody other than Brett has ever contributed to a member repository. Where it
# is true an agent may push a work branch and open one draft pull request
# without asking; where it is false the agent prepares the diff and waits. So it
# is worth more than the membership list it sits beside, and until 2026-09-10 it
# was stated in prose in two places and in the queue configuration in none,
# which meant the client's own configuration could not answer the question the
# client's protocol is scoped by.
#
# `HUB.md` GOVERNS. Its participation table under the standing authorization is
# the measured record and says so in its own text ("this is the operative copy,
# and it is now the only one"). The `solo:` column in the configuration is the
# machine-readable copy, exactly as `members:` is a copy of the domain card, and
# it is safe only because this comparison exists. When the two disagree the
# table is right and the configuration is wrong.
#
# THE ASYMMETRY IS DELIBERATE. A repository marked `solo: true` that the table
# does not list fails, because a grant nothing measured is a grant nobody made.
# A repository marked `solo: false` that the table does not list passes, because
# `HUB.md` says in as many words that a repository whose participation cannot be
# determined is shared. That is why `salmon-science-foundry`, whose repository
# does not exist yet, sits outside the table and reads false.
#
# WHAT IT DOES NOT CHECK, and this is the important half: whether the table is
# TRUE. Nothing here asks GitHub who has contributed. The table is a measurement
# somebody took by hand on 2026-09-10 and the check only keeps the copy honest,
# so a collaborator who lands their first commit tomorrow makes both the table
# and this column wrong together and no test will notice. Re-measuring is a
# human job with a date on it. A table row naming a repository that is not a
# member is also ignored rather than reported: membership is the domain card's
# ruling and the members cross-check above owns that disagreement.
#
# RETIRES WHEN: the participation test stops gating writes, or a client that can
# ask the forge who has contributed replaces the recorded answer with a measured
# one. At that point the `solo:` column and this check are deleted together.

HUB_POLICY_FILE = "HUB.md"

PARTICIPATION_HEADER_RE = re.compile(r"^\|\s*Repository\s*\|.*\bGrant applies\b")
BACKTICKED_RE = re.compile(r"`([^`]+)`")


def read_hub_participation(path: Path) -> dict:
    """Return {repo: grant} from the participation table, or {} if unreadable.

    `grant` is True for a `yes` cell and False for a `no` cell, bold markers and
    surrounding whitespace stripped. A cell that is neither maps to None, which
    the caller reports rather than guessing at.
    """
    grants: dict = {}
    inside = False
    for line in path.read_text(encoding="utf-8").splitlines():
        if PARTICIPATION_HEADER_RE.match(line):
            inside = True
            continue
        if not inside:
            continue
        if not line.startswith("|"):
            break
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if len(cells) < 3:
            continue
        if set("".join(cells)) <= set("-: "):
            continue
        verdict = cells[-1].replace("*", "").replace("`", "").strip().lower()
        value = True if verdict == "yes" else False if verdict == "no" else None
        for repo in BACKTICKED_RE.findall(cells[0]):
            grants[repo] = value
    return grants


def validate_solo(root: Path) -> list[Problem]:
    config_path = root / QUEUE_CONFIG_FILE
    if not config_path.is_file():
        return []
    rows = read_config_member_rows(config_path)
    if not rows:
        # The members cross-check already reports an unreadable `members:`
        # block under `members-unreadable`. Reporting it twice under two rule
        # names tells a reader there are two faults when there is one.
        return []

    policy_path = root / HUB_POLICY_FILE
    if not policy_path.is_file():
        return [
            Problem(
                QUEUE_CONFIG_FILE,
                0,
                "solo-source-missing",
                f"the `solo:` column copies the participation table in {HUB_POLICY_FILE}, "
                "which is not present, so the copy cannot be checked against its source "
                "and the write authorization it gates cannot be trusted",
            )
        ]

    grants = read_hub_participation(policy_path)
    if not grants:
        return [
            Problem(
                HUB_POLICY_FILE,
                0,
                "solo-unreadable",
                "the participation table could not be read, so the `solo:` column in "
                f"{QUEUE_CONFIG_FILE} cannot be checked against it; a cross-check that "
                "silently finds nothing to compare is worse than no cross-check",
            )
        ]

    problems: list[Problem] = []
    for repo, value in sorted(grants.items()):
        if value is None:
            problems.append(
                Problem(
                    HUB_POLICY_FILE,
                    0,
                    "solo-unreadable",
                    f"the participation table's verdict for {repo!r} is neither yes nor "
                    "no, so what it grants cannot be read",
                )
            )
    if problems:
        return problems

    for row in rows:
        if "solo" in row.duplicates:
            # Stated more than once, so no value was read. That is reported by
            # `validate_member_fields` under its own rule; a `solo-missing` on
            # top of it would tell the reader there are two faults when there
            # is one.
            continue
        raw = row.fields.get("solo")
        if raw is None or raw[0] == "":
            # A bare `solo:` is the key with nothing after it. The `hub` client
            # reads that as the empty string and `member_solo_for_repo` answers
            # no, so nothing is granted either way; it is reported here, on the
            # line that states it, so the file is fixed rather than read as "no
            # key" by this program and "empty value" by the client.
            if raw is None:
                where, detail = row.line, "has no `solo:` key"
            else:
                where, detail = raw[1], (
                    "has a `solo:` key with no value, which the `hub` client reads "
                    "as an empty string and answers no from"
                )
            problems.append(
                Problem(
                    QUEUE_CONFIG_FILE,
                    where,
                    "solo-missing",
                    f"member {row.repo!r} {detail}; every member states whether "
                    "anybody other than Brett has ever contributed to it, because the "
                    "standing write authorization is scoped by that answer and an absent "
                    "answer reads as no scope at all",
                )
            )
            continue
        text, line = raw
        if text not in ("true", "false"):
            problems.append(
                Problem(
                    QUEUE_CONFIG_FILE,
                    line,
                    "solo-type",
                    f"member {row.repo!r} has solo: {text!r}; it must be lowercase true or "
                    "false, because a value that is neither is read by nobody as either",
                )
            )
            continue
        solo = text == "true"
        granted = grants.get(row.repo)
        if granted is None:
            if solo:
                problems.append(
                    Problem(
                        QUEUE_CONFIG_FILE,
                        line,
                        "solo-unsourced",
                        f"member {row.repo!r} claims solo: true but {HUB_POLICY_FILE}'s "
                        "participation table does not list it; a grant that nothing "
                        "measured is a grant nobody made, so measure who has participated, "
                        "add the row there, and only then set this to true",
                    )
                )
            continue
        if solo != granted:
            problems.append(
                Problem(
                    QUEUE_CONFIG_FILE,
                    line,
                    "solo-drift",
                    f"member {row.repo!r} reads solo: {text} here and "
                    f"{'yes' if granted else 'no'} in {HUB_POLICY_FILE}'s participation "
                    "table; the table governs, so correct this line, or re-measure "
                    "participation and change the table first",
                )
            )
    return problems


# --------------------------------------------------------------------------
# The configured-blocks presence check
# --------------------------------------------------------------------------
#
# WHY THIS EXISTS, stated as the defect it fixes rather than as a feature.
#
# Until 2026-09-09 `check` walked the prose files, skipped every file with no
# `hub:generated:` marker, compared what was left, and printed "OK: every
# generated block matches the hub queue". `generated_blocks` in
# `queue/config.yaml` was never read by any code path. With zero markers in the
# repository -- which was the state of the repository on the day the defect was
# found -- it walked nothing, compared nothing, and reported success. A guard
# whose green means nothing is worse than no guard, because a reader who sees it
# pass stops looking.
#
# So a block the configuration declares is checked for being *present* in its
# target file, before anything is compared. A configured block with no marker is
# an error and never a skip. The freshness comparison below then does the rest:
# present and stale fails there, present and current passes.
#
# WHAT IT DOES NOT CHECK: whether the target file is the right place for that
# block, and whether a marker pair that nobody configured should exist. An
# `items:` query written straight into prose is legitimate and unlisted, so an
# unconfigured marker is not reported here.
#
# A missing `queue/config.yaml` disables this check the same way it disables the
# members cross-check, because the fixtures the unit tests build have no
# configuration and a checker that demands one cannot be exercised on them. In
# continuous integration the file's presence is asserted by the workflow's own
# presence step, so a configuration that vanished fails there instead of turning
# this check off quietly.
#
# RETIRES WHEN: `generated_blocks` is deleted from the queue configuration
# because no prose file restates queue state any more, which is the same
# condition that retires the renderer.

CONFIG_BLOCK_RE = re.compile(r"^\s*-\s*block:\s*(\S+)\s*$")
CONFIG_TARGET_RE = re.compile(r"^\s*target:\s*(\S+)\s*$")


def read_config_generated_blocks(path: Path) -> list[tuple[str, str]]:
    """Return the `(block, target)` pairs declared under `generated_blocks:`.

    A declared block with no `target:` comes back with an empty target rather
    than being dropped, so the caller reports it instead of losing it.
    """
    entries: list[list[str]] = []
    inside = False
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.startswith("generated_blocks:"):
            inside = True
            continue
        if not inside:
            continue
        # The block ends at the next key at column 0. A list item and a comment
        # at column 0 are both still inside it, which is why neither ends it.
        stripped = line.lstrip()
        if line and not line[0].isspace() and not stripped.startswith(("#", "-")):
            break
        match = CONFIG_BLOCK_RE.match(line)
        if match:
            entries.append([match.group(1), ""])
            continue
        match = CONFIG_TARGET_RE.match(line)
        if match and entries:
            entries[-1][1] = match.group(1)
    return [(block, target) for block, target in entries]


def validate_generated_blocks(root: Path) -> list[Problem]:
    config_path = root / QUEUE_CONFIG_FILE
    if not config_path.is_file():
        return []

    text = config_path.read_text(encoding="utf-8")
    entries = read_config_generated_blocks(config_path)
    if not entries:
        return [
            Problem(
                QUEUE_CONFIG_FILE,
                0,
                "generated-blocks-unreadable",
                "no `generated_blocks:` entries could be read, so `check` has "
                "nothing to look for and would report success while guarding "
                "nothing. Declare the blocks, or delete the renderer with them"
                if "generated_blocks:" in text
                else "the configuration declares no `generated_blocks:` key, so "
                "`check` has nothing to look for and would report success while "
                "guarding nothing. Declare the blocks, or delete the renderer",
            )
        ]

    problems: list[Problem] = []
    for block, target in entries:
        if not target:
            problems.append(
                Problem(
                    QUEUE_CONFIG_FILE,
                    0,
                    "generated-block-no-target",
                    f"block {block!r} declares no `target:`, so there is no file to "
                    "check it in",
                )
            )
            continue
        target_path = root / target
        if not target_path.is_file():
            problems.append(
                Problem(
                    target,
                    0,
                    "generated-block-target-missing",
                    f"block {block!r} is declared in {QUEUE_CONFIG_FILE} with target "
                    f"{target}, which does not exist",
                )
            )
            continue
        target_text = target_path.read_text(encoding="utf-8")
        opens = set(OPEN_MARKER_RE.findall(target_text))
        closes = set(CLOSE_MARKER_RE.findall(target_text))
        if block in opens and block in closes:
            continue
        if block in opens or block in closes:
            detail = (
                f"only one half of the marker pair for {block!r} is in {target}; "
                "an opener without its closer delimits nothing"
            )
        else:
            detail = (
                f"block {block!r} is declared in {QUEUE_CONFIG_FILE} with target "
                f"{target}, but {target} carries no `<!-- hub:generated:{block} -->` "
                f"... `<!-- /hub:generated:{block} -->` pair"
            )
        problems.append(
            Problem(
                target,
                0,
                "generated-block-missing",
                detail
                + ". A configured block that is missing is an error, not a skip: "
                "without the marker pair there is nothing to compare and the "
                "freshness check reports success while guarding nothing. Add the "
                f"pair to {target} and run `{RENDER_COMMAND}`, or remove the entry "
                f"from {QUEUE_CONFIG_FILE}",
            )
        )
    return problems


# --------------------------------------------------------------------------
# Prose files
# --------------------------------------------------------------------------


def find_prose_files(root: Path, roots: tuple[str, ...]) -> list[Path]:
    found: list[Path] = []
    for entry in roots:
        path = root / entry
        if path.is_file() and path.suffix == ".md":
            found.append(path)
        elif path.is_dir():
            for dirpath, dirnames, filenames in os.walk(path):
                dirnames[:] = sorted(d for d in dirnames if d not in PROSE_SKIP_DIRS)
                for filename in sorted(filenames):
                    if filename.endswith(".md"):
                        found.append(Path(dirpath) / filename)
    return sorted(set(found), key=lambda p: str(p))


def render_text(
    text: str, items: list[Item], baseline: int, source: str, display: str, root: Path
) -> tuple[str, list[str]]:
    """Return (new_text, names_of_blocks_changed). Bytes outside markers are kept."""
    opens = OPEN_MARKER_RE.findall(text)
    closes = CLOSE_MARKER_RE.findall(text)
    matched = [m.group("name") for m in BLOCK_RE.finditer(text)]
    if sorted(opens) != sorted(matched) or sorted(closes) != sorted(matched):
        unmatched = sorted(set(opens) ^ set(closes) or set(opens) - set(matched))
        raise BlockError(
            f"{display}: generated markers do not pair up "
            f"(problem names: {', '.join(unmatched) or 'nested or out-of-order markers'})"
        )

    newline = "\r\n" if "\r\n" in text else "\n"
    changed: list[str] = []

    def substitute(match: re.Match) -> str:
        name = match.group("name")
        body_lines = [DO_NOT_EDIT, ""] + render_block(name, items, baseline, source, root)
        body = newline + newline.join(body_lines) + newline
        if body != match.group("body"):
            changed.append(name)
        return match.group("open") + body + match.group("close")

    return BLOCK_RE.sub(substitute, text), changed


# --------------------------------------------------------------------------
# Commands
# --------------------------------------------------------------------------


def command_lint(args, root: Path, queue_dir: Path, out) -> int:
    items, parse_problems = load_queue(root, queue_dir)
    problems, debt = validate(items, root)
    problems = (
        parse_problems
        + problems
        + validate_members(root)
        + validate_member_fields(root)
        + validate_solo(root)
    )

    baseline: int | None = None
    source = ""
    try:
        baseline, source = read_baseline(root, args.retirement_debt_baseline)
    except BlockError as error:
        problems.append(
            Problem(
                RETIREMENT_DEBT_BASELINE_FILE,
                0,
                "retirement-baseline-unreadable",
                str(error),
            )
        )

    problems = sorted(problems, key=lambda p: (p.path, p.line, p.rule))
    for problem in problems:
        print(problem.render(), file=out)

    print(f"\n{len(items)} item(s) in {relative(queue_dir, root)}.", file=out)
    if baseline is None:
        print(
            f"Defects with no `retires_when`: {debt}. The baseline could not be read, "
            "so the ratchet checked nothing on this run.",
            file=out,
        )
        print("FAIL", file=out)
        return 1
    print(
        f"Defects with no `retires_when`: {debt} (baseline {baseline}, from {source}). "
        "This is a ratchet, not a hard rule: the backlog it migrates from carried "
        "34 retirement conditions across 119 items on 2026-09-05, so a day-one hard "
        "failure would block the migration the check protects. Lint fails only when "
        "the count rises above the baseline, and the ratchet retires when it reaches 0.",
        file=out,
    )
    failed = bool(problems)
    if debt > baseline:
        print(
            f"FAIL: retirement debt rose from {baseline} to {debt}. Give the new "
            "defect a `retires_when`, or lower the baseline deliberately and say why.",
            file=out,
        )
        failed = True
    elif debt < baseline:
        print(
            f"The ratchet is slack by {baseline - debt}: the debt is {debt} and the "
            f"baseline is {baseline}, so {baseline - debt} new defect(s) could arrive "
            f"with no `retires_when` and lint would still pass. Record {debt} in "
            f"{RETIREMENT_DEBT_BASELINE_FILE} to close the slack.",
            file=out,
        )
    print("FAIL" if failed else "OK", file=out)
    return 1 if failed else 0


def _rendered_files(args, root: Path, queue_dir: Path):
    items, parse_problems = load_queue(root, queue_dir)
    if parse_problems:
        raise BlockError(
            "the queue does not parse, so nothing can be rendered from it; "
            "run `python3 scripts/hub_queue.py lint` first"
        )
    baseline, source = read_baseline(root, args.retirement_debt_baseline)
    for path in find_prose_files(root, tuple(args.prose or DEFAULT_PROSE_ROOTS)):
        display = relative(path, root)
        text = path.read_text(encoding="utf-8")
        if "hub:generated:" not in text:
            continue
        try:
            new_text, changed = render_text(text, items, baseline, source, display, root)
        except BlockError as error:
            message = str(error)
            raise BlockError(
                message if message.startswith(display) else f"{display}: {message}"
            ) from None
        yield path, display, text, new_text, changed


def command_render(args, root: Path, queue_dir: Path, out) -> int:
    touched = 0
    for path, display, text, new_text, changed in _rendered_files(args, root, queue_dir):
        if new_text != text:
            path.write_text(new_text, encoding="utf-8")
            touched += 1
            print(f"rendered {display}: {', '.join(sorted(set(changed)))}", file=out)
    print(f"{touched} file(s) rewritten.", file=out)
    return 0


def command_check(args, root: Path, queue_dir: Path, out) -> int:
    # Presence before freshness. A block the configuration declares and no file
    # carries used to be invisible here: the walk skipped files with no marker,
    # so zero markers compared zero blocks and printed OK. Reporting that first
    # means the failure names the block and the file rather than being absent.
    missing = 0
    for problem in validate_generated_blocks(root):
        print(f"MISSING: {problem.render()}", file=out)
        missing += 1

    drift = 0
    # The configuration's copies of the allowlist and of the participation
    # verdicts are checked here as well as in `lint`, because the configuration
    # comment names *this* guard as the reason those copies are safe to keep.
    for problem in validate_members(root) + validate_member_fields(root) + validate_solo(root):
        print(f"DRIFT: {problem.render()}", file=out)
        drift += 1
    for path, display, text, new_text, changed in _rendered_files(args, root, queue_dir):
        if new_text != text:
            for name in sorted(set(changed)):
                print(
                    f"DRIFT: {display} block `hub:generated:{name}` no longer matches the "
                    f"hub queue.\n"
                    f"       Fix it with: {RENDER_COMMAND}\n"
                    f"       Do not edit the block by hand; the queue file under "
                    f"queue/items/ is the source.",
                    file=out,
                )
                drift += 1
    if missing:
        print(
            f"\n{missing} configured block(s) missing from their target file(s).",
            file=out,
        )
    if drift:
        print(f"\n{drift} stale generated block(s). Run `{RENDER_COMMAND}` and commit.", file=out)
    if missing or drift:
        return 1
    print("OK: every generated block matches the hub queue.", file=out)
    return 0


def command_list(args, root: Path, queue_dir: Path, out) -> int:
    items, parse_problems = load_queue(root, queue_dir)
    for problem in parse_problems:
        print(problem.render(), file=out)
    if not items:
        print(f"No items in {relative(queue_dir, root)}.", file=out)
        return 0
    for state in STATES:
        in_state = [i for i in items if i.state == state]
        if not in_state:
            continue
        print(f"\n{state} ({len(in_state)})", file=out)
        print("-" * (len(state) + len(str(len(in_state))) + 3), file=out)
        for item in in_state:
            marks = []
            if item.get("severity"):
                marks.append(item.get("severity"))
            if item.raw.get("claimable") is False:
                marks.append("not claimable")
            blocked = item.raw.get("blocked_by") or []
            if blocked:
                marks.append("blocked by " + ",".join(blocked))
            suffix = ("  [" + "; ".join(marks) + "]") if marks else ""
            print(f"  {item.id:<8} {item.get('title')}{suffix}", file=out)
    unstated = [i for i in items if i.state not in STATES]
    for item in unstated:
        print(f"  {item.id:<8} {item.get('title')}  [state {item.state!r} is not valid]", file=out)
    print(f"\n{len(items)} item(s).", file=out)
    return 0


COMMANDS = {
    "lint": command_lint,
    "render": command_render,
    "check": command_check,
    "list": command_list,
}


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="hub_queue.py",
        description=(
            "Validate the hub queue under queue/items/ and regenerate the "
            "prose blocks that restate it. Reads and writes files only: no network "
            "call, no git write, no GitHub API."
        ),
    )
    parser.add_argument("command", choices=sorted(COMMANDS), help="lint, render, check or list")
    parser.add_argument(
        "--root",
        default=None,
        help="repository root (default: the parent of the scripts/ directory holding this file)",
    )
    parser.add_argument(
        "--queue",
        default=None,
        help=f"queue directory, relative to --root (default: {DEFAULT_QUEUE_DIR})",
    )
    parser.add_argument(
        "--prose",
        action="append",
        default=None,
        help=(
            "file or directory to scan for generated blocks, relative to --root; "
            "repeatable (default: " + ", ".join(DEFAULT_PROSE_ROOTS) + ")"
        ),
    )
    parser.add_argument(
        "--retirement-debt-baseline",
        type=int,
        default=None,
        help="override the recorded retirement-debt baseline",
    )
    return parser


def main(argv=None, out=None) -> int:
    out = out or sys.stdout
    args = build_parser().parse_args(argv)
    root = Path(args.root) if args.root else Path(__file__).resolve().parent.parent
    queue_dir = root / (args.queue or DEFAULT_QUEUE_DIR)
    try:
        return COMMANDS[args.command](args, root, queue_dir, out)
    except BlockError as error:
        print(f"ERROR: {error}", file=out)
        return 2


if __name__ == "__main__":
    sys.exit(main())
