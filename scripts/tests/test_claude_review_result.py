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
        tools = []
        for action in ["view", "diff", "comment"]:
            tools.extend([
                dict(type="assistant", message=dict(content=[dict(type="tool_use", id=action,
                     name="Bash", input=dict(command=f"gh pr {action} 222 --repo salmon-data-mobilization/metasalmon"))])),
                dict(type="user", message=dict(content=[dict(type="tool_result", tool_use_id=action,
                     is_error=False, content="Successful nonempty result")]))
            ])
        module.check_review(tools + [result], "abc")
        with self.assertRaises(ValueError):
            module.check_review([result], "abc")
        for action in ["view", "diff", "comment"]:
            failed = [m for m in tools if m.get("type") != "user" or
                      m["message"]["content"][0]["tool_use_id"] != action]
            with self.subTest(missing=action), self.assertRaises(ValueError):
                module.check_review(failed + [result], "abc")
        # An inline comment is not the summary comment the round counter reads.
        inline = [dict(type="assistant", message=dict(content=[dict(type="tool_use", id="inline",
                       name="mcp__github_inline_comment__create_inline_comment", input={})])),
                  dict(type="user", message=dict(content=[dict(type="tool_result", tool_use_id="inline",
                       is_error=False, content="Posted")]))]
        no_summary = [m for m in tools if m.get("type") != "user" or
                      m["message"]["content"][0]["tool_use_id"] != "comment"]
        with self.assertRaises(ValueError):
            module.check_review(no_summary + inline + [result], "abc")
        for changed in [dict(permission_denials=[dict(tool_name="Bash")]),
                        dict(result="Skipped a draft"), dict(result="REVIEWED_HEAD=older"),
                        dict(result="REVIEWED_HEAD=abc-extra"), dict(result=None),
                        dict(subtype="error_max_turns"), dict(is_error=True)]:
            with self.subTest(changed=changed), self.assertRaises(ValueError):
                module.check_review(tools + [result | changed], "abc")

    def test_absent_or_ambiguous_completion(self):
        for messages in [[], {}, [dict(type="result"), dict(type="result")]]:
            with self.subTest(messages=messages), self.assertRaises(ValueError):
                module.check_review(messages, "abc")


if __name__ == "__main__":
    unittest.main()
