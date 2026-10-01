#!/usr/bin/env python3
"""Offline ID discovery: a remote collision, legacy question, unpublished local
file, and failed/incomplete reads. Temporary Git repos; no network or hub refs.
Run: python3 scripts/tests/test_hub_ids.py
"""

import contextlib
import io
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import hub_ids


def fixture_git_env():
    # -C does not override GIT_DIR, GIT_WORK_TREE or GIT_INDEX_FILE inherited
    # from a hook. Fixture writes must stay inside their disposable repos.
    return {key: value for key, value in os.environ.items() if not key.startswith("GIT_")}


class IdScan(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.repo = Path(self.temp.name)
        self.run_git("init", "-q")
        (self.repo / "queue/items").mkdir(parents=True)
        (self.repo / "knowledge").mkdir()
        (self.repo / "queue/items/B-426.yaml").write_text("id: B-426\n")
        (self.repo / "knowledge/questions.md").write_text("### Q71 — control\n")
        self.commit()
        base = self.run_git("rev-parse", "HEAD")
        (self.repo / "queue/items/B-427.yaml").write_text("id: B-427\n")
        (self.repo / "knowledge/questions.md").write_text("### Q71 — control\n### Q72 — reserved\n")
        self.commit()
        self.run_git("update-ref", "refs/remotes/origin/parallel", self.run_git("rev-parse", "HEAD"))
        self.run_git("reset", "--hard", base)
        (self.repo / "queue/items/B-428.yaml").write_text("id: B-428\n")

    def run_git(self, *args):
        return subprocess.check_output(["git", "-C", str(self.repo), *args],
                                       env=fixture_git_env(), stderr=subprocess.PIPE).decode().strip()

    def commit(self):
        self.run_git("add", ".")
        self.run_git("-c", "user.name=Fixture", "-c", "user.email=fixture@example.org",
                     "-c", "commit.gpgsign=false", "commit", "-qm", "Fixture")

    def test_collision_remote_legacy_and_unpublished_local(self):
        found, refs, worktrees = hub_ids.scan(self.repo)
        self.assertGreaterEqual(refs, 2)
        self.assertEqual(worktrees, 1)
        self.assertTrue(any("origin/parallel" in s for s in found["B-427"]))
        self.assertIn("Q-71", found)  # positive control
        self.assertIn("Q-72", found)  # no queue file: legacy heading on remote
        self.assertTrue(any(s.startswith("worktree:") for s in found["B-428"]))
        self.assertNotIn("B-429", found)
        self.assertEqual(self.run_git("status", "--short"), "?? queue/items/B-428.yaml")

    def test_cli_seen_suggestion_and_unknown(self):
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            self.assertEqual(hub_ids.main(["B-427", "--repo", str(self.repo)]), 1)
            self.assertEqual(hub_ids.main(["B", "--repo", str(self.repo)]), 0)
        self.assertIn("B-429", output.getvalue())
        with contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(hub_ids.main(["B", "--repo", str(self.repo / "missing")]), 3)

    def test_failed_tree_read_cannot_suggest(self):
        real_git = hub_ids.git
        def failing_git(repo, *args):
            if args[0] == "ls-tree":
                raise RuntimeError("fixture unreadable tree")
            return real_git(repo, *args)
        with patch.object(hub_ids, "git", failing_git), contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(hub_ids.main(["B", "--repo", str(self.repo)]), 3)

    def test_unreadable_local_source_cannot_suggest(self):
        real_read = Path.read_text
        def unreadable(file, *args, **kwargs):
            if file.name == "questions.md":
                raise PermissionError("fixture inaccessible source")
            return real_read(file, *args, **kwargs)
        with patch.object(Path, "read_text", unreadable), contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(hub_ids.main(["Q", "--repo", str(self.repo)]), 3)

    def test_empty_repository_does_not_clear_reach(self):
        with tempfile.TemporaryDirectory() as empty:
            subprocess.run(["git", "init", "-q", empty], env=fixture_git_env(),
                           check=True, stderr=subprocess.PIPE)
            with contextlib.redirect_stderr(io.StringIO()):
                self.assertEqual(hub_ids.main(["B", "--repo", empty]), 3)

    def test_git_reads_disable_lazy_fetch_and_inherited_redirects(self):
        with patch.dict(os.environ, {"GIT_DIR": "/fixture-missing", "GIT_NO_LAZY_FETCH": "0"}), \
                patch.object(hub_ids.subprocess, "run", wraps=subprocess.run) as run:
            self.assertIn("B-427", hub_ids.scan(self.repo)[0])
        for call in run.call_args_list:
            self.assertEqual(call.kwargs["env"]["GIT_NO_LAZY_FETCH"], "1")
            self.assertEqual(call.kwargs["env"]["GIT_OPTIONAL_LOCKS"], "0")
            self.assertNotIn("GIT_DIR", call.kwargs["env"])

    def test_broken_local_source_symlink_is_unknown(self):
        file = self.repo / "knowledge/questions.md"
        file.unlink()
        file.symlink_to("missing.md")
        with contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(hub_ids.main(["Q", "--repo", str(self.repo)]), 3)

    def test_tracked_item_directory_symlink_is_unknown(self):
        self.run_git("rm", "-r", "queue/items")
        (self.repo / "queue/items/B-428.yaml").unlink()
        (self.repo / "queue/items").rmdir()
        (self.repo / "queue/items").symlink_to("missing", target_is_directory=True)
        self.commit()
        with contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(hub_ids.main(["B", "--repo", str(self.repo)]), 3)

    def test_heading_boundaries_and_padded_question(self):
        self.assertEqual(hub_ids.headings("### Q06 — old\n## B-428 — owner\n"
                                         "## #429 — backlog\nprose Q999\n### Q73a text\n"),
                         {"Q-6", "B-428", "B-429"})

    def test_fixture_ignores_inherited_git_redirects(self):
        # A disposable caller repository stands in for a hook's real checkout.
        # Run only one child test, so this integration control cannot recurse.
        with tempfile.TemporaryDirectory() as caller_dir:
            caller = Path(caller_dir)
            safe_env = {k: v for k, v in os.environ.items() if not k.startswith("GIT_")}
            def caller_git(*args):
                return subprocess.check_output(["git", "-C", str(caller), *args],
                                               env=safe_env, stderr=subprocess.PIPE)
            caller_git("init", "-q")
            (caller / "keep.txt").write_text("caller content\n")
            caller_git("add", ".")
            caller_git("-c", "user.name=Caller", "-c", "user.email=caller@example.org",
                       "-c", "commit.gpgsign=false", "commit", "-qm", "Caller")
            before = (caller_git("rev-parse", "HEAD"),
                      (caller / ".git/index").read_bytes(),
                      caller_git("show-ref"), caller_git("status", "--porcelain"))
            inherited = dict(safe_env, GIT_DIR=str(caller / ".git"),
                             GIT_INDEX_FILE=str(caller / ".git/index"))
            child = subprocess.run([sys.executable, str(Path(__file__).resolve()),
                                    "IdScan.test_collision_remote_legacy_and_unpublished_local"],
                                   env=inherited, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            after = (caller_git("rev-parse", "HEAD"),
                     (caller / ".git/index").read_bytes(),
                     caller_git("show-ref"), caller_git("status", "--porcelain"))
            self.assertEqual(after, before)
            self.assertEqual(child.returncode, 0, child.stderr.decode())
            self.assertEqual((caller / "keep.txt").read_text(), "caller content\n")


if __name__ == "__main__":
    unittest.main()
