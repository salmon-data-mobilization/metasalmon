#!/usr/bin/env python3
"""Offline completion checks; never invoke Claude or post to GitHub."""
import sys
import unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from importlib.util import module_from_spec, spec_from_file_location
spec = spec_from_file_location("review_check", Path(__file__).resolve().parents[1] / "check-claude-review-result.py")
module = module_from_spec(spec)
spec.loader.exec_module(module)


class ReviewCompletion(unittest.TestCase):
    def test_completed_requested_head(self):
        result = dict(type="result", subtype="success", is_error=False,
                      permission_denials=[], result="Done.\nREVIEWED_HEAD=abc")
        module.check_review([dict(type="assistant"), result], "abc")
        for changed in [dict(permission_denials=[dict(tool_name="Bash")]),
                        dict(result="Skipped a draft"), dict(result="REVIEWED_HEAD=older"),
                        dict(result="REVIEWED_HEAD=abc-extra"), dict(result=None),
                        dict(subtype="error_max_turns"), dict(is_error=True)]:
            with self.subTest(changed=changed), self.assertRaises(ValueError):
                module.check_review([result | changed], "abc")

    def test_absent_or_ambiguous_completion(self):
        for messages in [[], {}, [dict(type="result"), dict(type="result")]]:
            with self.subTest(messages=messages), self.assertRaises(ValueError):
                module.check_review(messages, "abc")


if __name__ == "__main__":
    unittest.main()
