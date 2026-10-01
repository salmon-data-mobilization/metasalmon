"""Offline proofs for CI attempts hidden by reruns; no GitHub calls."""

import importlib.util
from pathlib import Path
import subprocess
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location(
    "ci_attempt_history", Path(__file__).resolve().parents[1] / "ci-attempt-history.py"
)
history = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(history)


def record(number, conclusion, attempt=1, status="completed"):
    return {
        "id": number + 1000,
        "run_number": number,
        "run_attempt": attempt,
        "status": status,
        "conclusion": conclusion,
        "head_sha": f"head-{number}",
    }


class AttemptHistoryTests(unittest.TestCase):
    def fake_api(self, pages, attempts):
        calls = []

        def get(path, *, paginate=False):
            calls.append((path, paginate))
            if paginate:
                return pages
            run, number = path.rsplit("/runs/", 1)[1].split("/attempts/")
            return attempts[(int(run), int(number))]

        return get, calls

    def test_successful_reruns_reveal_prior_failures_on_every_page(self):
        pages = [{"workflow_runs": [record(337, "success", 2)]}, {
            "workflow_runs": [record(360, "success", 3), record(449, "success", 2)]
        }]
        attempts = {}
        for number, size in ((337, 2), (360, 3), (449, 2)):
            for attempt in range(1, size + 1):
                attempts[(number + 1000, attempt)] = record(
                    number, "success" if attempt == size else "failure", attempt
                )
        get, calls = self.fake_api(pages, attempts)
        report = history.collect_history("owner/repo", "check.yaml", get)
        counts = report["counts"]
        self.assertEqual(counts["failed_run_count_from_listing"], 0)
        self.assertEqual(counts["failed_attempt_count"], 4)
        self.assertEqual(counts["observed_attempt_count"], 7)
        self.assertEqual(counts["successful_rerun_count_with_prior_failed_attempts"], 3)
        self.assertEqual(counts["failed_attempt_count_hidden_by_successful_reruns"], 4)
        self.assertEqual(len(calls), 8)
        self.assertTrue(calls[0][1])

    def test_cancelled_then_successful_is_not_a_recovered_failure(self):
        get, _ = self.fake_api(
            [{"workflow_runs": [record(215, "success", 2)]}],
            {(1215, 1): record(215, "cancelled"), (1215, 2): record(215, "success", 2)},
        )
        counts = history.collect_history("owner/repo", "check.yaml", get)["counts"]
        self.assertEqual(counts["rerun_count"], 1)
        self.assertEqual(counts["failed_attempt_count"], 0)
        self.assertEqual(counts["successful_rerun_count_with_prior_failed_attempts"], 0)

    def test_single_attempts_and_page_overlap_are_counted_once(self):
        failed = record(1, "failure")
        pending = record(2, None, status="in_progress")
        get, calls = self.fake_api([
            {"workflow_runs": [failed]}, {"workflow_runs": [failed, pending]}
        ], {})
        counts = history.collect_history("owner/repo", "check.yaml", get)["counts"]
        self.assertEqual(counts["snapshot_run_count"], 2)
        self.assertEqual(counts["observed_attempt_count"], 2)
        self.assertEqual(counts["failed_attempt_count"], 1)
        self.assertEqual(counts["incomplete_attempt_count"], 1)
        self.assertEqual(len(calls), 1)

    def test_an_api_failure_cannot_return_a_partial_count(self):
        def get(path, *, paginate=False):
            if paginate:
                return [{"workflow_runs": [record(337, "success", 2)]}]
            raise subprocess.CalledProcessError(1, ["gh", "api", path])
        with self.assertRaises(subprocess.CalledProcessError):
            history.collect_history("owner/repo", "check.yaml", get)

    def test_malformed_and_mismatched_attempts_fail(self):
        for bad in (record(338, "failure"), {**record(337, "failure"), "conclusion": None}):
            get, _ = self.fake_api(
                [{"workflow_runs": [record(337, "success", 2)]}], {(1337, 1): bad}
            )
            with self.assertRaises(ValueError):
                history.collect_history("owner/repo", "check.yaml", get)
        with self.assertRaises(ValueError):
            history.collect_history("owner/repo", "check.yaml", lambda *a, **k: [{}])

    def test_cli_uses_get_and_preserves_pagination(self):
        with patch.object(history.subprocess, "run") as run:
            run.return_value.stdout = '[{"workflow_runs": []}]'
            history.github_get("repos/owner/repo/actions/runs", paginate=True)
        self.assertEqual(run.call_args.args[0], [
            "gh", "api", "--method", "GET", "--paginate", "--slurp",
            "repos/owner/repo/actions/runs",
        ])
        self.assertTrue(run.call_args.kwargs["check"])


if __name__ == "__main__":
    unittest.main()
