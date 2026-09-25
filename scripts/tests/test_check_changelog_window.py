#!/usr/bin/env python3
"""Tests for `scripts/check-changelog-window.py` (hub item B-200).

THE RED DEMONSTRATION IS BUILT HERE, NOT BORROWED FROM HISTORY. Each test
builds a throwaway git repository in a temporary directory -- a bump commit
setting `Version`, then the change under test -- and runs the script against
it as a subprocess, so what is asserted is the exit code a continuous
integration job would see. The replay against real history (metasalmonpy at
`1e9245c`, B-144's entry under `## 0.5.0`) belongs to B-201, because it needs
a sibling checkout; nothing here does.

Every RED has its GREEN. A RED-only test passes when the checker rejects
everything, which is a checker nobody can use. So the bullet that is a finding
under a released heading is shown passing under the development heading, and
each correction that passes with the exemption is shown failing without it --
which is what makes the exemption a marker and not a hole.

The fixtures run git with GIT_CONFIG_GLOBAL and GIT_CONFIG_SYSTEM pointed at
the null device, as `test_hub_claim.sh` does, so that a developer's commit
signing, hooks or blame settings cannot change what a fixture commits or what
blame reports. Nothing here writes into this repository or makes a network
call.

Run with:

    python3 scripts/tests/test_check_changelog_window.py

RETIRES WHEN: `scripts/check-changelog-window.py` is deleted. A behaviour
removed from the script has its test removed here in the same change, or this
file starts asserting behaviour that no longer exists.
"""

from __future__ import annotations

import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent.parent / "check-changelog-window.py"

EXIT_OK, EXIT_FINDINGS, EXIT_CANNOT_RUN = 0, 1, 2


def heading(text: str) -> str:
    """A setext heading, the form metasalmon's NEWS.md uses."""
    return f"{text}\n{'-' * len(text)}\n\n"


DEV = heading("metasalmon (development version)")
V010 = heading("metasalmon 0.1.0")
SHIPPED = "* A shipped entry, described\n  over two lines.\n"
DESCRIPTION = "Package: fixture\nVersion: {}\n"


class Fixture:
    """A throwaway repository, driven with git and a config nobody else set."""

    def __init__(self, root: Path) -> None:
        self.root = root
        self.env = {
            **os.environ,
            "GIT_CONFIG_GLOBAL": os.devnull,
            "GIT_CONFIG_SYSTEM": os.devnull,
            "GIT_AUTHOR_NAME": "fixture",
            "GIT_AUTHOR_EMAIL": "fixture@example.invalid",
            "GIT_COMMITTER_NAME": "fixture",
            "GIT_COMMITTER_EMAIL": "fixture@example.invalid",
        }
        root.mkdir(parents=True, exist_ok=True)
        self.git("init", "-q", "-b", "main")

    def git(self, *args: str) -> str:
        done = subprocess.run(
            ["git", "-C", str(self.root), *args],
            env=self.env, capture_output=True, text=True,
        )
        if done.returncode != 0:
            raise AssertionError(f"git {' '.join(args)} failed:\n{done.stderr}")
        return done.stdout.strip()

    def commit(self, message: str, files: dict[str, str]) -> str:
        for name, text in files.items():
            (self.root / name).write_text(text, encoding="utf-8")
        self.git("add", "-A")
        self.git("commit", "-q", "-m", message)
        return self.git("rev-parse", "HEAD")

    def check(self, *args: str) -> subprocess.CompletedProcess:
        return subprocess.run(
            [sys.executable, str(SCRIPT), "--repo", str(self.root), *args],
            env=self.env, capture_output=True, text=True,
        )


class WindowTestCase(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.tmp = Path(self._tmp.name)

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def released(self) -> tuple[Fixture, str]:
        """Development work, then the bump commit that makes it 0.1.0."""
        repo = Fixture(self.tmp / "repo")
        repo.commit("development", {
            "DESCRIPTION": DESCRIPTION.format("0.0.0.9000"),
            "NEWS.md": DEV + SHIPPED,
        })
        bump = repo.commit("Bump the version to 0.1.0", {
            "DESCRIPTION": DESCRIPTION.format("0.1.0"),
            "NEWS.md": V010 + SHIPPED,
        })
        return repo, bump

    def assertExit(self, done: subprocess.CompletedProcess, code: int) -> None:
        self.assertEqual(
            done.returncode, code,
            f"expected exit {code}, got {done.returncode}\n"
            f"--- stdout\n{done.stdout}--- stderr\n{done.stderr}",
        )
        if code == EXIT_CANNOT_RUN:
            # Python exits 2 by itself when it cannot open a script, so the
            # code alone would pass these tests with no script at all -- which
            # it did, in this file's first run.
            self.assertIn("cannot run", done.stderr)


class TestTheWindow(WindowTestCase):
    """The shape the rule exists for: a line filed under a version it missed."""

    def test_bullet_added_under_released_heading_after_the_bump_is_red(self):
        repo, _ = self.released()
        repo.commit("A late fix, filed under the release", {
            "NEWS.md": DEV + V010 + SHIPPED + "* A late fix.\n",
        })
        done = repo.check()
        self.assertExit(done, EXIT_FINDINGS)
        self.assertIn("* A late fix.", done.stderr)
        self.assertIn("metasalmon 0.1.0", done.stderr)

    def test_same_bullet_under_the_development_heading_is_green(self):
        repo, _ = self.released()
        repo.commit("A late fix, filed under development", {
            "NEWS.md": DEV + "* A late fix.\n\n" + V010 + SHIPPED,
        })
        self.assertExit(repo.check(), EXIT_OK)

    def test_branch_forked_before_the_bump_and_merged_after_it_is_red(self):
        # The real instance (metasalmonpy b939fd9 after 67fb486): the branch
        # filed its line under the development heading, correctly for the tree
        # it forked from, and the merge carried it under the renamed heading
        # without a conflict to say so.
        repo = Fixture(self.tmp / "repo")
        repo.commit("development", {
            "DESCRIPTION": DESCRIPTION.format("0.0.0.9000"),
            "NEWS.md": DEV + SHIPPED,
        })
        repo.git("switch", "-q", "-c", "late")
        repo.commit("A late fix, under development", {
            "NEWS.md": DEV + SHIPPED + "* A late fix.\n",
        })
        repo.git("switch", "-q", "main")
        repo.commit("Bump the version to 0.1.0", {
            "DESCRIPTION": DESCRIPTION.format("0.1.0"),
            "NEWS.md": V010 + SHIPPED,
        })
        repo.git("merge", "-q", "--no-ff", "-m", "Merge the late fix", "late")
        news = (repo.root / "NEWS.md").read_text(encoding="utf-8")
        self.assertEqual(news, V010 + SHIPPED + "* A late fix.\n")
        done = repo.check()
        self.assertExit(done, EXIT_FINDINGS)
        self.assertIn("* A late fix.", done.stderr)

    def test_a_branch_merged_before_the_bump_shipped_and_is_green(self):
        repo = Fixture(self.tmp / "repo")
        repo.commit("development", {
            "DESCRIPTION": DESCRIPTION.format("0.0.0.9000"),
            "NEWS.md": DEV + SHIPPED,
        })
        repo.git("switch", "-q", "-c", "early")
        repo.commit("An early fix, under development", {
            "NEWS.md": DEV + SHIPPED + "* An early fix.\n",
        })
        repo.git("switch", "-q", "main")
        repo.git("merge", "-q", "--no-ff", "-m", "Merge the early fix", "early")
        repo.commit("Bump the version to 0.1.0", {
            "DESCRIPTION": DESCRIPTION.format("0.1.0"),
            "NEWS.md": V010 + SHIPPED + "* An early fix.\n",
        })
        self.assertExit(repo.check(), EXIT_OK)


class TestTheBumpCommit(WindowTestCase):
    """The tag when it exists, else the first commit whose version reads it."""

    def test_the_tag_names_the_bump_when_it_exists(self):
        repo, _ = self.released()
        late = repo.commit("A late fix, filed under the release", {
            "NEWS.md": V010 + SHIPPED + "* A late fix.\n",
        })
        # Without a tag the first commit reading 0.1.0 is the bump, so the
        # line missed it; a tag on the later commit says it shipped.
        self.assertExit(repo.check(), EXIT_FINDINGS)
        repo.git("tag", "-a", "v0.1.0", "-m", "0.1.0", late)
        self.assertExit(repo.check(), EXIT_OK)

    def test_a_tag_on_the_bump_keeps_the_later_line_red(self):
        repo, bump = self.released()
        repo.git("tag", "-a", "v0.1.0", "-m", "0.1.0", bump)
        repo.commit("A late fix, filed under the release", {
            "NEWS.md": V010 + SHIPPED + "* A late fix.\n",
        })
        done = repo.check()
        self.assertExit(done, EXIT_FINDINGS)
        self.assertIn("tag v0.1.0", done.stderr)

    def test_a_heading_renamed_after_the_bump_keeps_what_shipped_green(self):
        # Why the check asks blame as well as the diff: when the heading is
        # renamed after the version moved, the section is absent at the bump
        # commit and every line under it reads as added. The lines that were
        # in the bump's tree, under the development heading, are ancestors of
        # it and pass; a line written after it is still red.
        repo = Fixture(self.tmp / "repo")
        repo.commit("development", {
            "DESCRIPTION": DESCRIPTION.format("0.0.0.9000"),
            "NEWS.md": DEV + SHIPPED,
        })
        repo.commit("Bump the version to 0.1.0", {"DESCRIPTION": DESCRIPTION.format("0.1.0")})
        repo.commit("Rename the heading", {"NEWS.md": V010 + SHIPPED})
        self.assertExit(repo.check(), EXIT_OK)
        repo.commit("A late fix, filed under the release", {
            "NEWS.md": V010 + SHIPPED + "* A late fix.\n",
        })
        self.assertExit(repo.check(), EXIT_FINDINGS)

    def test_an_untagged_version_superseded_is_measured_where_it_stood(self):
        # Before the rule, entries accumulated under a version's heading while
        # it stood -- metasalmon 0.1.6 and 0.2.4 record it -- and neither was
        # ever tagged. While the version is current its window is open and the
        # first commit rules, so such a line is red at the time. Once a later
        # version supersedes it untagged, it is measured as it stood at the
        # last commit that read it: what it gained while it stood passes, and
        # a line added after that is red.
        repo, _ = self.released()
        stood = V010 + SHIPPED + "* While it stood.\n"
        repo.commit("An entry while 0.1.0 stands", {"NEWS.md": stood})
        self.assertExit(repo.check(), EXIT_FINDINGS)
        v020 = heading("metasalmon 0.2.0") + "* Next.\n\n"
        repo.commit("Bump the version to 0.2.0", {
            "DESCRIPTION": DESCRIPTION.format("0.2.0"),
            "NEWS.md": v020 + stood,
        })
        self.assertExit(repo.check(), EXIT_OK)
        repo.commit("A line under 0.1.0 after it was superseded", {
            "NEWS.md": v020 + stood + "* After it.\n",
        })
        done = repo.check()
        self.assertExit(done, EXIT_FINDINGS)
        self.assertIn("* After it.", done.stderr)
        self.assertNotIn("* While it stood.", done.stderr)

    def test_a_heading_with_no_bump_commit_is_listed_not_passed_silently(self):
        repo, _ = self.released()
        old = heading("metasalmon 0.0.1") + "* Older than this history.\n"
        repo.commit("Record a release older than the history", {
            "NEWS.md": V010 + SHIPPED + "\n" + old,
        })
        done = repo.check()
        self.assertExit(done, EXIT_OK)
        self.assertIn("0.0.1", done.stdout)
        self.assertIn("not checked", done.stdout)


class TestTheExemption(WindowTestCase):
    """A marked, dated correction passes; an unmarked addition does not."""

    def test_unmarked_paragraph_under_a_released_heading_is_red(self):
        repo, _ = self.released()
        repo.commit("Append to a shipped entry, unmarked", {
            "NEWS.md": V010 + SHIPPED + "  This entry now also covers the late fix.\n",
        })
        done = repo.check()
        self.assertExit(done, EXIT_FINDINGS)
        self.assertIn("now also covers", done.stderr)

    def test_marked_correction_paragraph_is_green_and_red_without_the_exemption(self):
        repo, _ = self.released()
        repo.commit("Correct a shipped entry", {
            "NEWS.md": V010 + SHIPPED
            + "  *(Correction, 2026-09-25: this entry shipped saying two\n"
            + "  lines; it is one line (see the fixture).)*\n",
        })
        self.assertExit(repo.check(), EXIT_OK)
        self.assertExit(repo.check("--no-exemption"), EXIT_FINDINGS)

    def test_corrected_bracket_inserted_into_a_line_is_green_and_red_without_it(self):
        # The 0.4.0 shape on metasalmon main: a bracket inserted into a shipped
        # line splits it in two, so one line more than shipped is there now.
        repo, _ = self.released()
        repo.commit("Correct a shipped line in place", {
            "NEWS.md": V010
            + "* A shipped entry [corrected 2026-09-25: it was a\n"
            + "  different entry], described\n  over two lines.\n",
        })
        self.assertExit(repo.check(), EXIT_OK)
        self.assertExit(repo.check("--no-exemption"), EXIT_FINDINGS)

    def test_a_marker_that_never_closes_exempts_nothing(self):
        repo, _ = self.released()
        repo.commit("Correct a shipped entry, unclosed", {
            "NEWS.md": V010 + SHIPPED
            + "  *(Correction, 2026-09-25: this entry shipped saying two\n"
            + "  lines, and the marker is never closed.\n",
        })
        self.assertExit(repo.check(), EXIT_FINDINGS)

    def test_an_undated_marker_exempts_nothing(self):
        repo, _ = self.released()
        repo.commit("Correct a shipped entry, undated", {
            "NEWS.md": V010 + SHIPPED
            + "  *(Correction: this entry shipped saying two lines.)*\n",
        })
        self.assertExit(repo.check(), EXIT_FINDINGS)


class TestWhatItDoesNotCover(WindowTestCase):
    """The docstring's limits, pinned so that they stay true."""

    def test_a_line_changed_in_place_is_not_a_finding(self):
        repo, _ = self.released()
        repo.commit("Fix a typo in a shipped entry", {
            "NEWS.md": V010 + "* A shipped entry, now described\n  over two lines.\n",
        })
        self.assertExit(repo.check("--no-exemption"), EXIT_OK)

    def test_a_new_line_beside_a_line_changed_in_place_is_still_red(self):
        # One replaced run: the shipped line is edited and a new line is written
        # beside it. The edit stands for the line it replaced; the new one is
        # added, and it is the new one that is reported.
        repo, _ = self.released()
        repo.commit("Edit a shipped line and add one beside it", {
            "NEWS.md": V010 + "* A shipped entry, described\n"
            + "  Something new that did not ship.\n  over two lines, edited.\n",
        })
        done = repo.check()
        self.assertExit(done, EXIT_FINDINGS)
        self.assertIn("Something new that did not ship.", done.stderr)
        self.assertNotIn("over two lines, edited.", done.stderr)

    def test_the_edited_line_stands_for_its_original_even_beside_a_short_one(self):
        # The strings are NEWS.md's own, from the 0.4.0 correction at line 1664
        # on metasalmon main: the shipped line was edited and grew into a
        # correction, whose short closing line shares a few of its words.
        # Pairing by difflib's ratio chose the closing line and reported the
        # edited one as added; pairing by characters kept does not.
        repo = Fixture(self.tmp / "repo")
        repo.commit("development", {
            "DESCRIPTION": DESCRIPTION.format("0.0.0.9000"),
            "NEWS.md": DEV + "* An entry.\n  both Python readers already did.\n",
        })
        repo.commit("Bump the version to 0.1.0", {
            "DESCRIPTION": DESCRIPTION.format("0.1.0"),
            "NEWS.md": V010 + "* An entry.\n  both Python readers already did.\n",
        })
        repo.commit("Correct it", {
            "NEWS.md": V010 + "* An entry.\n"
            + "  one Python reader already did. *(Correction, 2026-08-24: this entry shipped\n"
            + "  how widely it already held.)*\n",
        })
        self.assertExit(repo.check(), EXIT_OK)
        done = repo.check("--no-exemption")
        self.assertExit(done, EXIT_FINDINGS)
        self.assertIn("how widely it already held.)*", done.stderr)
        self.assertNotIn("one Python reader already did.", done.stderr)


class TestItCannotBeFooled(WindowTestCase):
    """A history it cannot see must never look like a history that is clean."""

    def test_a_shallow_clone_cannot_run(self):
        repo, _ = self.released()
        repo.commit("A late fix, filed under the release", {
            "NEWS.md": V010 + SHIPPED + "* A late fix.\n",
        })
        shallow = self.tmp / "shallow"
        subprocess.run(
            ["git", "clone", "-q", "--depth", "1", f"file://{repo.root}", str(shallow)],
            env=repo.env, check=True, capture_output=True,
        )
        done = subprocess.run(
            [sys.executable, str(SCRIPT), "--repo", str(shallow)],
            env=repo.env, capture_output=True, text=True,
        )
        self.assertExit(done, EXIT_CANNOT_RUN)
        self.assertIn("shallow", done.stderr)

    def test_a_missing_changelog_cannot_run(self):
        repo = Fixture(self.tmp / "repo")
        repo.commit("no changelog", {"DESCRIPTION": DESCRIPTION.format("0.1.0")})
        self.assertExit(repo.check(), EXIT_CANNOT_RUN)

    def test_released_headings_none_of_which_it_can_check_cannot_run(self):
        # The wrong repository, or a version file the profile cannot read:
        # every released heading unchecked is a run that verified nothing.
        repo = Fixture(self.tmp / "repo")
        repo.commit("a changelog no version file ever named", {
            "DESCRIPTION": "Package: fixture\n",
            "NEWS.md": V010 + SHIPPED,
        })
        self.assertExit(repo.check(), EXIT_CANNOT_RUN)


class TestTheMirrorProfile(WindowTestCase):
    """The metasalmonpy shape, so that B-201 can reuse this script."""

    def released_py(self) -> Fixture:
        repo = Fixture(self.tmp / "py")
        repo.commit("development", {
            "pyproject.toml": '[project]\nname = "fixture"\nversion = "0.0.1.dev0"\n',
            "CHANGELOG.md": "# Changelog\n\n## Unreleased\n\n" + SHIPPED,
        })
        repo.commit("Bump the version to 0.1.0", {
            "pyproject.toml": '[project]\nname = "fixture"\nversion = "0.1.0"\n',
            "CHANGELOG.md": "# Changelog\n\n## 0.1.0\n\n" + SHIPPED,
        })
        return repo

    def test_changelog_line_under_released_heading_after_the_bump_is_red(self):
        repo = self.released_py()
        repo.commit("A late fix, filed under the release", {
            "CHANGELOG.md": "# Changelog\n\n## Unreleased\n\n## 0.1.0\n\n"
            + SHIPPED + "* A late fix.\n",
        })
        done = repo.check("--profile", "metasalmonpy")
        self.assertExit(done, EXIT_FINDINGS)
        self.assertIn("* A late fix.", done.stderr)

    def test_same_line_under_unreleased_is_green(self):
        repo = self.released_py()
        repo.commit("A late fix, filed under Unreleased", {
            "CHANGELOG.md": "# Changelog\n\n## Unreleased\n\n* A late fix.\n\n## 0.1.0\n\n"
            + SHIPPED,
        })
        self.assertExit(repo.check("--profile", "metasalmonpy"), EXIT_OK)


if __name__ == "__main__":
    unittest.main()
