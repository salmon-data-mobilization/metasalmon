#!/usr/bin/env python3
"""Guard the one property the two parity registers cannot check for themselves.

`knowledge/parity-deviations.md` (here) and `PARITY.md` (in metasalmonpy) are
twins. Both say row numbers are permanent so the two can be cross-referenced by
number, and both say the registers must agree. Nothing enforced either claim,
and both have failed:

  * Row 33 was row 29 until 2026-08-17 -- two streams claimed 29 for entirely
    different deviations, in different repositories, days apart.
  * Row 41 was row 35 until 2026-08-21 -- the same collision again, against
    metasalmonpy's released `integer`-storage row.
  * Rows 36-39 lived in `PARITY.md` with no hub counterpart at all, so the hub
    register -- the one the mirror contract is checked from -- was missing four
    registered differences.

Every one of those is a set-of-numbers property, which is exactly what a
program is good at and a reader is not. So this checks:

  1. no number used twice within one register (collision-in-waiting),
  2. no number present in one register and absent from the other (one-sided),
  3. no table row whose number cannot be parsed.

WHAT IT DOES NOT CHECK, stated plainly, because a guard whose claimed scope
exceeds its real scope is worse than no guard: it never reads the *content* of
a row. Two rows can share a number and describe different things -- which is
what a collision looks like the moment before someone notices -- and a row can
sit at the right number in both files while one copy is a version out of date.
Rows 32, 37 and 38 all drifted that way and this script would have passed them
all. It catches the shape of the failures above, not their substance.

*Retires when:* the two registers live in one repository, at which point a
single ordinary test can read both without a sibling checkout and this script
becomes a test helper rather than a standalone tool.

Usage
-----
    python3 scripts/check-parity-registers.py
    python3 scripts/check-parity-registers.py HUB_REGISTER TWIN_REGISTER

With no arguments it reads `knowledge/parity-deviations.md` relative to the
repository root and `PARITY.md` from the sibling checkout named by
`METASALMONPY_PATH`, defaulting to `../metasalmonpy`. Exits 0 when the two
number sets agree, 1 on any finding, and 2 when a register cannot be read --
"the twin is missing" must never look like "the twin agrees".
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

EXIT_OK = 0
EXIT_DRIFT = 1
EXIT_UNREADABLE = 2

# A register row is a markdown table row whose first cell is the row number.
# The number may carry emphasis, because rows are written by hand and some
# numbers are bolded for the eye -- `| **35** | ...` must parse as 35, not as a
# junk row, or the guard reports drift that is only formatting.
_STRIP = "* _`"


def parse_row_numbers(path: Path) -> tuple[dict[int, int], list[tuple[int, str]]]:
    """Return {row number: line number} and a list of unparseable table rows.

    Header (`| # | Kind |`) and separator (`|---|---|`) lines are skipped by
    shape rather than by position, so a register that grows a second table or
    moves its first one keeps working.
    """
    numbers: dict[int, int] = {}
    duplicates: list[tuple[int, str]] = []
    unparseable: list[tuple[int, str]] = []

    for lineno, line in enumerate(path.read_text(encoding="utf-8").split("\n"), start=1):
        stripped = line.strip()
        if not stripped.startswith("|"):
            continue
        cells = stripped.split("|")
        if len(cells) < 3:
            continue
        first = cells[1].strip()
        if set(first) <= set("-: ") and first:  # separator row
            continue
        if first in {"#", "Row", ""}:  # header row, or a continuation line
            continue
        token = first.strip(_STRIP).strip()
        if not token.isdigit():
            unparseable.append((lineno, stripped[:90]))
            continue
        number = int(token)
        if number in numbers:
            duplicates.append((number, f"lines {numbers[number]} and {lineno}"))
        else:
            numbers[number] = lineno

    for number, where in duplicates:
        unparseable.append((-number, f"DUPLICATE row {number} ({where})"))
    return numbers, unparseable


def main(argv: list[str]) -> int:
    if len(argv) == 3:
        hub_path, twin_path = Path(argv[1]), Path(argv[2])
    elif len(argv) == 1:
        root = Path(__file__).resolve().parent.parent
        hub_path = root / "knowledge" / "parity-deviations.md"
        sibling = os.environ.get("METASALMONPY_PATH") or str(root.parent / "metasalmonpy")
        twin_path = Path(sibling) / "PARITY.md"
    else:
        sys.stderr.write(__doc__ or "")
        return EXIT_UNREADABLE

    for path in (hub_path, twin_path):
        if not path.is_file():
            sys.stderr.write(
                f"cannot read register: {path}\n"
                "Both registers must be present. A missing twin is not agreement --\n"
                "set METASALMONPY_PATH to a metasalmonpy checkout, or pass both paths.\n"
            )
            return EXIT_UNREADABLE

    hub, hub_bad = parse_row_numbers(hub_path)
    twin, twin_bad = parse_row_numbers(twin_path)

    findings: list[str] = []
    for label, bad in ((hub_path.name, hub_bad), (twin_path.name, twin_bad)):
        for _, detail in bad:
            findings.append(f"{label}: {detail}")

    hub_only = sorted(set(hub) - set(twin))
    twin_only = sorted(set(twin) - set(hub))
    if hub_only:
        findings.append(
            f"{hub_path.name}: rows {hub_only} have no counterpart in {twin_path.name}"
        )
    if twin_only:
        findings.append(
            f"{twin_path.name}: rows {twin_only} have no counterpart in {hub_path.name}"
        )

    if findings:
        sys.stderr.write("parity register drift:\n")
        for finding in findings:
            sys.stderr.write(f"  - {finding}\n")
        sys.stderr.write(
            "\nRow numbers are permanent in both registers so the two can be\n"
            "cross-referenced by number. A one-sided number means a difference is\n"
            "registered in one repository and invisible in the other; a duplicate\n"
            "means two deviations answer to one handle. Precedent for a collision\n"
            "(rows 29/33, 35/41): the committed, released row keeps the number and\n"
            "the newer one moves to the next free number in BOTH registers.\n"
        )
        return EXIT_DRIFT

    print(f"parity registers agree: {len(hub)} rows, 1-{max(hub)} with no gaps"
          if sorted(hub) == list(range(1, max(hub) + 1))
          else f"parity registers agree: {len(hub)} rows")
    return EXIT_OK


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
