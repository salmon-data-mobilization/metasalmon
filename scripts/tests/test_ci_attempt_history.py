"""Offline proofs for CI attempts hidden by reruns; no GitHub calls."""

import importlib.util
import contextlib
import io
from pathlib import Path
import re
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
        report = history._collect_history_unchecked("owner/repo", "check.yaml", get)
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
        counts = history._collect_history_unchecked("owner/repo", "check.yaml", get)["counts"]
        self.assertEqual(counts["rerun_run_count"], 1)
        self.assertEqual(counts["failed_attempt_count"], 0)
        self.assertEqual(counts["successful_rerun_count_with_prior_failed_attempts"], 0)

    def test_single_attempts_and_page_overlap_are_counted_once(self):
        failed = record(1, "failure")
        pending = record(2, None, status="in_progress")
        get, calls = self.fake_api([
            {"workflow_runs": [failed]}, {"workflow_runs": [failed, pending]}
        ], {})
        counts = history._collect_history_unchecked("owner/repo", "check.yaml", get)["counts"]
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
            history._collect_history_unchecked("owner/repo", "check.yaml", get)

    def test_malformed_and_mismatched_attempts_fail(self):
        for bad in (record(338, "failure"), {**record(337, "failure"), "conclusion": None}):
            get, _ = self.fake_api(
                [{"workflow_runs": [record(337, "success", 2)]}], {(1337, 1): bad}
            )
            with self.assertRaises(ValueError):
                history._collect_history_unchecked("owner/repo", "check.yaml", get)
        with self.assertRaises(ValueError):
            history._collect_history_unchecked("owner/repo", "check.yaml", lambda *a, **k: [{}])

    def test_control_refuses_a_valid_but_truncated_listing(self):
        # Pagination can return a syntactically valid subset without an API error.
        get, _ = self.fake_api(
            [{"workflow_runs": [record(337, "success", 2)]}],
            {(1337, 1): record(337, "failure"), (1337, 2): record(337, "success", 2)},
        )
        with self.assertRaisesRegex(ValueError, "positive control"):
            history.collect_history("owner/repo", "check.yaml", control_run_id=1449, api_get=get)

    def test_control_requires_the_known_failed_then_successful_history(self):
        pages = [{"workflow_runs": [record(449, "success", 2)]}]
        wrong = {(1449, 1): record(449, "cancelled"),
                 (1449, 2): record(449, "success", 2)}
        get, _ = self.fake_api(pages, wrong)
        with self.assertRaisesRegex(ValueError, "positive control"):
            history.collect_history("owner/repo", "check.yaml", control_run_id=1449, api_get=get)

        correct = {(1449, 1): record(449, "failure"),
                   (1449, 2): record(449, "success", 2)}
        get, _ = self.fake_api(pages, correct)
        report = history.collect_history("owner/repo", "check.yaml", control_run_id=1449, api_get=get)
        self.assertEqual(report["positive_control_run_id"], 1449)
        self.assertEqual(report["counts"]["successful_rerun_count_with_prior_failed_attempts"], 1)

    def test_cli_requires_control_before_api_access(self):
        with patch.object(history.sys, "argv", ["ci-attempt-history.py"]), \
             patch.object(history, "collect_history", side_effect=AssertionError("API called")), \
             contextlib.redirect_stderr(io.StringIO()):
            with self.assertRaises(SystemExit) as error:
                history.main()
        self.assertEqual(error.exception.code, 2)

    def test_failed_control_emits_no_json(self):
        output = io.StringIO()
        with patch.object(history.sys, "argv", ["ci-attempt-history.py", "--control-run-id", "1449"]), \
             patch.object(history, "collect_history", side_effect=ValueError("positive control absent")), \
             contextlib.redirect_stdout(output), contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(history.main(), 1)
        self.assertEqual(output.getvalue(), "")

    def test_workflow_paths_cover_instrument_in_both_events(self):
        workflow = (Path(__file__).resolve().parents[2] / ".github/workflows/hub-queue.yml").read_text()

        def paths_for_event(source, event):
            lines = source.splitlines()
            start = lines.index(f"  {event}:") + 1
            event_body = []
            for line in lines[start:]:
                if (line and not line.startswith(" ")) or re.match(r"^  [A-Za-z_]+:", line):
                    break
                event_body.append(line)
            paths_body = event_body[event_body.index("    paths:") + 1:]
            return {
                line.strip()[2:].strip('"')
                for line in paths_body
                if line.startswith("      - ")
            }

        for event in ("pull_request", "push"):
            self.assertIn("scripts/ci-attempt-history.py", paths_for_event(workflow, event))
            altered = workflow.replace('      - "scripts/ci-attempt-history.py"\n', "", 1)
            if event == "push":
                altered = workflow.replace('      - "scripts/ci-attempt-history.py"\n', "", 2)
            self.assertNotIn("scripts/ci-attempt-history.py", paths_for_event(altered, event))

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
