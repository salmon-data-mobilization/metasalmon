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

    def test_denials_report_only_fixed_diagnostic_categories(self):
        secret = "PRIVATE_TOKEN_should_never_appear"
        denials = [
            dict(tool_name="Bash", tool_input=dict(command=f"gh pr diff 245 --repo {secret}")),
            dict(tool_name="Bash", tool_input=dict(command=f"git show {secret}")),
            dict(tool_name="Read", tool_input=dict(file_path=f"/private/{secret}")),
            dict(tool_name=secret, tool_input=dict(command=secret)),
            dict(tool_name="Bash", tool_input=dict(command=f"TOKEN={secret} rg pattern")),
            dict(tool_name="Bash", tool_input=dict(command="rg 'unterminated")),
        ]
        result = dict(type="result", subtype="success", is_error=False,
                      permission_denials=denials, result="REVIEWED_HEAD=abc")
        with self.assertRaises(ValueError) as caught:
            module.check_review([result], "abc")
        message = str(caught.exception)
        self.assertIn("6 calls", message)
        for label in ["Bash:gh pr diff", "Bash:git show", "Read", "unknown", "Bash:unclassified"]:
            self.assertIn(label, message)
        self.assertNotIn(secret, message)
        self.assertNotIn("/private/", message)

    def test_denial_diagnostics_bound_output_and_handle_malformed_records(self):
        for denials in [[None, "raw private input", {}, dict(tool_name="Bash", tool_input=None)],
                        dict(private="raw private input"), "raw private input"]:
            result = dict(type="result", subtype="success", is_error=False,
                          permission_denials=denials, result="REVIEWED_HEAD=abc")
            with self.subTest(denials=denials), self.assertRaises(ValueError) as caught:
                module.check_review([result], "abc")
            self.assertNotIn("raw private input", str(caught.exception))
        tools = ["Read", "Grep", "Glob", "Edit", "Write", "WebFetch", "WebSearch", "Task", "Bash"]
        denials = [dict(tool_name=name) for name in tools] * 100
        result = dict(type="result", subtype="success", is_error=False,
                      permission_denials=denials, result="REVIEWED_HEAD=abc")
        with self.assertRaises(ValueError) as caught:
            module.check_review([result], "abc")
        self.assertIn("900 calls", str(caught.exception))
        self.assertIn("additional categories omitted", str(caught.exception))
        self.assertLess(len(str(caught.exception)), 250)


if __name__ == "__main__":
    unittest.main()
