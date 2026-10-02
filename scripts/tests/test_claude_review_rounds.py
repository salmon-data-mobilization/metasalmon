#!/usr/bin/env python3
"""Offline regressions for actual failed-review/green-skip accounting."""
import importlib.util
import unittest
from pathlib import Path
from unittest.mock import patch
spec = importlib.util.spec_from_file_location("rounds", Path(__file__).resolve().parents[1] / "check-claude-review-rounds.py")
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)

HEAD = "a" * 40
COMMENT = dict(id=42, user=dict(login="claude[bot]"), created_at="2026-10-01T19:01:00Z",
               body=f"Head {HEAD}: no blocking issues\n<!-- claude-review verdict=nits -->")
RUN = dict(id=123, event="pull_request", conclusion="success", head_sha=HEAD,
           pull_requests=[dict(number=234)])
ACTION = dict(name="Run Claude Code Review", conclusion="success", started_at="2026-10-01T19:00:00Z", completed_at="2026-10-01T19:02:00Z")
GUARD = dict(name="Verify review execution", conclusion="success")
JOB = dict(name="claude-review", conclusion="success", steps=[ACTION, GUARD])


class Rounds(unittest.TestCase):
    def decide(self, comments=None, runs=None, jobs=None):
        return m.decide([COMMENT] if comments is None else comments, 234,
                        lambda head: [RUN] if runs is None else runs,
                        lambda run: [JOB] if jobs is None else jobs)

    def test_validated_nits_skip_and_empty_runs_do_not(self):
        self.assertEqual(self.decide()[:2], (2, True))
        self.assertEqual(self.decide(runs=[])[:2], (2, False))
        self.assertEqual(self.decide(comments=[])[:2], (1, False))

    def test_fractional_timestamps_and_missing_action_time(self):
        self.assertTrue(m.in_action_window("2026-10-01T19:01:00Z", ACTION | dict(
            started_at="2026-10-01T19:01:00.000Z", completed_at="2026-10-01T19:01:00.999Z")))
        self.assertFalse(m.in_action_window("invalid", ACTION))
        self.assertFalse(m.in_action_window(COMMENT["created_at"], {}))

    def test_denied_review_nits_do_not_suppress_next_attempt(self):
        # PR234/218/242 published nits despite denied tools; guard then failed.
        bad = JOB | dict(conclusion="failure", steps=[ACTION, GUARD | dict(conclusion="failure")])
        self.assertEqual(self.decide(runs=[RUN | dict(conclusion="failure")], jobs=[bad])[:2], (2, False))
        self.assertEqual(self.decide(jobs=[bad])[:2], (2, False))

    def test_green_skipped_review_is_not_completion(self):
        skipped = JOB | dict(steps=[ACTION | dict(conclusion="skipped"), GUARD | dict(conclusion="skipped")])
        self.assertEqual(self.decide(jobs=[skipped])[:2], (2, False))
        self.assertEqual(self.decide(jobs=[JOB | dict(steps=[ACTION])])[:2], (2, False))

    def test_mismatched_pr_head_or_comment_time_never_attests(self):
        for run in [RUN | dict(head_sha="b" * 40), RUN | dict(pull_requests=[]),
                    RUN | dict(pull_requests=[dict(number=218)]), RUN | dict(event="push")]:
            with self.subTest(run=run):
                self.assertEqual(self.decide(runs=[run])[:2], (2, False))
        late = COMMENT | dict(created_at="2026-10-01T20:00:00Z")
        self.assertEqual(self.decide(comments=[late])[:2], (2, False))
        self.assertEqual(self.decide(runs=[RUN, RUN | dict(id=124)])[:2], (2, False))

    def test_five_marker_cost_cap_preserved_even_for_incomplete_rounds(self):
        comments = [COMMENT | dict(id=n) for n in range(5)]
        with patch.object(m, "completed_round", side_effect=AssertionError("must not fetch at cap")):
            self.assertEqual(self.decide(comments=comments, runs=[])[:2], (6, True))

    def test_only_last_bot_marker_controls_nits_gate(self):
        human = COMMENT | dict(id=44, user=dict(login="person"))
        important = COMMENT | dict(id=43, body=f"Head {HEAD}: one issue\n<!-- claude-review verdict=important -->")
        self.assertEqual(self.decide(comments=[human, important, COMMENT])[:2], (3, False))
        self.assertEqual(self.decide(comments=[human])[:2], (1, False))
        bad = COMMENT | dict(body="No completed head\n<!-- claude-review verdict=nits -->")
        self.assertEqual(self.decide(comments=[bad])[:2], (2, False))

    def test_metadata_failure_stops_before_model_instead_of_guessing(self):
        with self.assertRaises(OSError):
            m.decide([COMMENT], 234, lambda _: (_ for _ in ()).throw(OSError()), lambda _: [])

    def test_workflow_does_not_expand_permissions_or_allow_shell_runners(self):
        source = (Path(__file__).resolve().parents[2] / ".github/workflows/claude-code-review.yml").read_text()
        for broad in ["Bash(gh api:", "Bash(python3:", "Bash(perl:", "Bash(xargs:", "Bash(mkdir:"]:
            self.assertNotIn(broad, source)
        self.assertNotIn("actions: read", source)
        self.assertIn("run: python3 scripts/check-claude-review-result.py", source)
        self.assertIn("steps.rounds.outputs.skip != 'true'", source)


if __name__ == "__main__":
    unittest.main()
