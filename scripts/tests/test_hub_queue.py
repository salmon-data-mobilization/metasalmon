#!/usr/bin/env python3
"""Tests for `scripts/hub_queue.py`.

EVERY RULE THE LINTER ENFORCES HAS A RED DEMONSTRATION HERE: a fixture that
violates the rule, asserted to fail, then the corrected fixture asserted to
pass. A guard that has never been shown to fail is a guard nobody has tested,
and this repository has shipped that failure before -- sdp-0.3.0's
`statistical_modifier` passed continuous integration and pull-request review
with 100% of its correct accepts silently downgraded, because every test used a
hand-written fixture that routed around the layer that was broken.

The GREEN half of each pair is not decoration. A RED-only test passes when the
checker rejects everything, which is a checker nobody can use.

Every fixture is written into a temporary directory. Nothing here writes into
the repository, and nothing here makes a network call or runs git.

Run with:

    python3 scripts/tests/test_hub_queue.py

RETIRES WHEN: `scripts/hub_queue.py` is deleted, or the queue stops living in
files. A rule removed from the linter must have its pair removed here in the
same change, or this file starts asserting behaviour that no longer exists.
"""

from __future__ import annotations

import io
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import hub_queue  # noqa: E402


# The schema order, written out longhand so a fixture reads like a real file.
BASE_DEFECT = [
    ("id", "B-53"),
    ("kind", "defect"),
    ("title", "Fix the thing"),
    ("state", "ready"),
    ("claimable", "true"),
    ("repo", "metasalmon"),
    ("stream", "S1"),
    ("severity", "P2"),
    ("blocked_by", "[]"),
    ("legacy", "'#53'"),
    ("evidence", "backlog.md"),
    ("retires_when", "The thing is fixed and a regression test pins it"),
]

BASE_STREAM = [
    ("id", "S-12"),
    ("kind", "stream"),
    ("title", "Hub coordination"),
    ("state", "icebox"),
    ("claimable", "true"),
    ("repo", "metasalmon"),
    ("blocked_by", "[]"),
    ("evidence", "roadmap.md"),
]

BASE_QUESTION = [
    ("id", "Q-21"),
    ("kind", "question"),
    ("title", "Where does the denylist live"),
    ("state", "needs_brett"),
    ("claimable", "false"),
    ("repo", "metasalmon"),
    ("blocked_by", "[]"),
    ("evidence", "questions.md"),
]


def item_text(base, **overrides) -> str:
    """Render a fixture, applying overrides in place and dropping `None` keys."""
    lines = []
    seen = set()
    for key, value in base:
        if key in overrides:
            value = overrides[key]
            seen.add(key)
            if value is None:
                continue
        lines.append(f"{key}: {value}")
    for key, value in overrides.items():
        if key not in seen and value is not None:
            lines.append(f"{key}: {value}")
    return "\n".join(lines) + "\n"


class QueueTestCase(unittest.TestCase):
    """A temporary repository root with an empty queue directory.

    The queue lives at `queue/items` at the repository root, not inside the
    `knowledge/` bundle: the Open Knowledge Format validator fails closed on a
    non-Markdown file inside a bundle, and operational state stays with the
    system that owns it. This fixture mirrors that layout, and it has to, because
    a fixture at the wrong path writes items the client never reads and every
    RED assertion then passes for the wrong reason.

    Every fixture also gets a retirement-debt baseline file, because the client
    has no built-in default and refuses to guess one.
    """

    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.root = Path(self._tmp.name)
        self.queue = self.root / "queue" / "items"
        self.queue.mkdir(parents=True)
        self.baseline_path = self.root / hub_queue.RETIREMENT_DEBT_BASELINE_FILE
        self.write_baseline(0)
        self.addCleanup(self._tmp.cleanup)

    # -- fixtures ---------------------------------------------------------

    def write_baseline(self, text) -> Path:
        self.baseline_path.parent.mkdir(parents=True, exist_ok=True)
        self.baseline_path.write_text(f"{text}\n", encoding="utf-8")
        return self.baseline_path

    def write_item(self, base, filename=None, **overrides) -> Path:
        text = item_text(base, **overrides)
        name = filename or (overrides.get("id") or dict(base)["id"]) + ".yaml"
        path = self.queue / name
        path.write_text(text, encoding="utf-8")
        return path

    def write_raw(self, name: str, text: str) -> Path:
        path = self.queue / name
        path.write_text(text, encoding="utf-8")
        return path

    def write_prose(self, relpath: str, text: str) -> Path:
        path = self.root / relpath
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")
        return path

    # -- driving the program ----------------------------------------------

    def run_hub(self, *argv):
        buffer = io.StringIO()
        code = hub_queue.main(["--root", str(self.root), *argv], out=buffer)
        return code, buffer.getvalue()

    def assert_rejects(self, rule: str, *argv):
        """RED: lint must fail, and must name the rule that caught it."""
        code, output = self.run_hub("lint", *argv)
        self.assertEqual(code, 1, f"expected lint to FAIL for rule {rule}; output:\n{output}")
        self.assertIn(f"[{rule}]", output, f"lint failed but not for {rule}; output:\n{output}")
        return output

    def assert_accepts(self, *argv):
        """GREEN: lint must pass. A checker that rejects everything is unusable."""
        code, output = self.run_hub("lint", *argv)
        self.assertEqual(code, 0, f"expected lint to pass; output:\n{output}")
        return output


# --------------------------------------------------------------------------
# One RED/GREEN pair per lint rule
# --------------------------------------------------------------------------


class TestSchemaShape(QueueTestCase):
    def test_unknown_key(self):
        self.write_item(BASE_DEFECT, owner="brett")
        self.assert_rejects("unknown-key")
        self.write_item(BASE_DEFECT)
        self.assert_accepts()

    def test_missing_required_key(self):
        self.write_item(BASE_DEFECT, evidence=None)
        output = self.assert_rejects("missing-key")
        self.assertIn("'evidence'", output)
        self.write_item(BASE_DEFECT)
        self.assert_accepts()

    def test_duplicate_key_in_one_file(self):
        self.write_raw("B-53.yaml", item_text(BASE_DEFECT) + "state: done\n")
        self.assert_rejects("duplicate-key")
        self.write_item(BASE_DEFECT)
        self.assert_accepts()

    def test_indented_line_is_not_the_schema(self):
        self.write_raw("B-53.yaml", item_text(BASE_DEFECT) + "  nested: true\n")
        self.assert_rejects("indent")
        self.write_item(BASE_DEFECT)
        self.assert_accepts()

    def test_tab_character(self):
        self.write_raw("B-53.yaml", item_text(BASE_DEFECT).replace("repo: ", "repo:\t"))
        self.assert_rejects("tab")
        self.write_item(BASE_DEFECT)
        self.assert_accepts()

    def test_line_that_is_not_key_value(self):
        self.write_raw("B-53.yaml", item_text(BASE_DEFECT) + "just a sentence\n")
        self.assert_rejects("syntax")
        self.write_item(BASE_DEFECT)
        self.assert_accepts()

    def test_blank_lines_document_markers_and_comments_are_tolerated(self):
        self.write_raw(
            "B-53.yaml",
            "---\n# a note about this item\n\n" + item_text(BASE_DEFECT) + "\n...\n",
        )
        self.assert_accepts()


class TestScalarValues(QueueTestCase):
    def test_empty_value(self):
        self.write_item(BASE_DEFECT, repo="")
        self.assert_rejects("value")
        self.write_item(BASE_DEFECT)
        self.assert_accepts()

    def test_unquoted_hash_would_be_eaten_by_comment_stripping(self):
        # `legacy: #53` reads as an empty value plus a comment. Rejecting it is
        # the whole reason the schema writes the citation as `'#53'`.
        self.write_item(BASE_DEFECT, legacy="#53")
        self.assert_rejects("value")
        self.write_item(BASE_DEFECT, legacy="'#53'")
        self.assert_accepts()

    def test_trailing_comment_is_stripped_from_unquoted_values(self):
        self.write_item(BASE_DEFECT, severity="P2   # defects only")
        self.assert_accepts()
        code, output = self.run_hub("list")
        self.assertEqual(code, 0)
        self.assertIn("P2", output)
        self.assertNotIn("defects only", output)

    def test_single_quoted_value_honours_the_doubled_quote_escape(self):
        # Found against the real queue on 2026-09-09: five items carried a
        # possessive apostrophe inside a single-quoted `retires_when`, and the
        # parser read the doubled quote as the end of the scalar and reported
        # "trailing text" on five correct files.
        self.write_item(
            BASE_DEFECT,
            retires_when="'metasalmonpy''s dictionary is replaced and a test pins it'",
        )
        self.assert_accepts()
        code, output = self.run_hub("list")
        self.assertEqual(code, 0)
        self.assertNotIn("trailing text", output)

    def test_double_quoted_value_honours_the_backslash_escape(self):
        self.write_item(BASE_DEFECT, title='"The \\"strict\\" path stops lying"')
        self.assert_accepts()

    def test_unterminated_quote(self):
        self.write_item(BASE_DEFECT, title="'Fix the thing")
        self.assert_rejects("value")
        self.write_item(BASE_DEFECT, title="'Fix the thing'")
        self.assert_accepts()

    def test_block_style_list_is_refused(self):
        self.write_raw(
            "B-53.yaml",
            item_text(BASE_DEFECT, blocked_by=None) + "blocked_by:\n  - B-90\n",
        )
        output = self.assert_rejects("value")
        self.assertIn("inline flow", output)
        self.write_item(BASE_DEFECT)
        self.assert_accepts()

    def test_claimable_must_be_lowercase_boolean(self):
        self.write_item(BASE_DEFECT, claimable="True")
        self.assert_rejects("value")
        self.write_item(BASE_DEFECT, claimable="true")
        self.assert_accepts()

    def test_claimable_must_not_be_a_word(self):
        self.write_item(BASE_DEFECT, claimable="maybe")
        self.assert_rejects("claimable-type")
        self.write_item(BASE_DEFECT, claimable="false")
        self.assert_accepts()


class TestIdentity(QueueTestCase):
    def test_id_format(self):
        self.write_item(BASE_DEFECT, id="53", filename="B-53.yaml")
        self.assert_rejects("id-format")
        self.write_item(BASE_DEFECT, filename="B-53.yaml")
        self.assert_accepts()

    def test_id_prefix_must_agree_with_kind(self):
        self.write_item(BASE_DEFECT, id="S-53", filename="S-53.yaml", severity=None)
        self.assert_rejects("id-kind")
        (self.queue / "S-53.yaml").unlink()
        self.write_item(BASE_DEFECT)
        self.assert_accepts()

    def test_filename_must_match_id(self):
        self.write_item(BASE_DEFECT, filename="fix-the-thing.yaml")
        self.assert_rejects("filename")
        (self.queue / "fix-the-thing.yaml").unlink()
        self.write_item(BASE_DEFECT)
        self.assert_accepts()

    def test_duplicate_id_across_files(self):
        self.write_item(BASE_DEFECT)
        # A second file carrying the same id. Its own name matches, so the only
        # thing that can catch this is the cross-file uniqueness check.
        self.write_raw("B-53.yml", item_text(BASE_DEFECT))
        self.assert_rejects("duplicate-id")
        (self.queue / "B-53.yml").unlink()
        self.assert_accepts()

    def test_duplicate_legacy_citation(self):
        self.write_item(BASE_DEFECT)
        self.write_item(BASE_DEFECT, id="B-54", legacy="'#53'", filename="B-54.yaml")
        self.assert_rejects("duplicate-legacy")
        self.write_item(BASE_DEFECT, id="B-54", legacy="'#54'", filename="B-54.yaml")
        self.assert_accepts()


class TestEnumeratedFields(QueueTestCase):
    def test_kind(self):
        self.write_item(BASE_DEFECT, kind="bug")
        self.assert_rejects("kind")
        self.write_item(BASE_DEFECT, kind="defect")
        self.assert_accepts()

    def test_state(self):
        self.write_item(BASE_DEFECT, state="in-progress")
        self.assert_rejects("state")
        self.write_item(BASE_DEFECT, state="claimed")
        self.assert_accepts()

    def test_severity_value(self):
        self.write_item(BASE_DEFECT, severity="high")
        self.assert_rejects("severity")
        self.write_item(BASE_DEFECT, severity="P1")
        self.assert_accepts()

    def test_severity_is_required_on_a_defect(self):
        self.write_item(BASE_DEFECT, severity=None)
        self.assert_rejects("severity-missing")
        self.write_item(BASE_DEFECT)
        self.assert_accepts()

    def test_severity_is_refused_on_a_non_defect(self):
        self.write_item(BASE_STREAM, severity="P2")
        self.assert_rejects("severity-scope")
        self.write_item(BASE_STREAM)
        self.assert_accepts()

    def test_venue_value(self):
        self.write_item(BASE_DEFECT, venue="slack")
        self.assert_rejects("venue")
        self.write_item(BASE_DEFECT, venue="claude-science")
        self.assert_accepts()

    def test_venue_is_optional_and_every_ruled_value_is_accepted(self):
        # The field is advice about which of Brett's two working surfaces the
        # work wants, so an item that does not care simply omits it. All this
        # program does is hold the vocabulary still.
        self.write_item(BASE_DEFECT, venue=None)
        self.assert_accepts()
        for value in ("claude-science", "claude-code", "either"):
            with self.subTest(venue=value):
                self.write_item(BASE_DEFECT, venue=value)
                self.assert_accepts()

    def test_title_has_no_trailing_period(self):
        self.write_item(BASE_DEFECT, title="Fix the thing.")
        self.assert_rejects("title")
        self.write_item(BASE_DEFECT, title="Fix the thing")
        self.assert_accepts()


class TestAuthorizationBoundary(QueueTestCase):
    """`needs_brett` plus `claimable: true` is the one lint rule with teeth.

    Section 9.5 says an agent may not move an item to `ready` and may not make a
    decision only Brett can make. An item sitting in `needs_brett` while
    advertising itself as claimable is exactly the state that lets an agent pick
    up work it has no authority to finish.
    """

    def test_needs_brett_must_not_be_claimable(self):
        self.write_item(BASE_QUESTION, claimable="true")
        output = self.assert_rejects("needs-brett-claimable")
        self.assertIn("only Brett can make", output)
        self.write_item(BASE_QUESTION, claimable="false")
        self.assert_accepts()

    def test_other_states_may_be_claimable(self):
        self.write_item(BASE_DEFECT, state="ready", claimable="true")
        self.assert_accepts()


class TestBlockedBy(QueueTestCase):
    def test_blocked_by_target_must_exist(self):
        self.write_item(BASE_DEFECT, blocked_by="[B-90]")
        self.assert_rejects("blocked-by-missing")
        self.write_item(BASE_DEFECT, id="B-90", filename="B-90.yaml", legacy="'#90'")
        self.assert_accepts()

    def test_blocked_by_must_be_a_list_not_a_scalar(self):
        self.write_item(BASE_DEFECT, blocked_by="B-90")
        self.assert_rejects("blocked-by-style")
        self.write_item(BASE_DEFECT, blocked_by="[]")
        self.assert_accepts()

    def test_multiple_targets_resolve(self):
        self.write_item(BASE_STREAM)
        self.write_item(BASE_DEFECT, id="B-90", filename="B-90.yaml", legacy="'#90'")
        self.write_item(BASE_DEFECT, blocked_by="[B-90, S-12]")
        self.assert_accepts()


class TestAbsolutePaths(QueueTestCase):
    """`knowledge/` is repo-relative only, and that rule is enforced by review.

    A checker is cheaper than review, and it does not get tired.
    """

    def test_unix_absolute_path(self):
        self.write_item(BASE_DEFECT, evidence="/srv/notes/backlog.md")
        self.assert_rejects("absolute-path")
        self.write_item(BASE_DEFECT, evidence="knowledge/backlog.md")
        self.assert_accepts()

    def test_home_relative_path(self):
        self.write_item(BASE_DEFECT, retires_when="Deleted when ~/notes/backlog.md is gone")
        self.assert_rejects("absolute-path")
        self.write_item(BASE_DEFECT)
        self.assert_accepts()

    def test_windows_drive_path(self):
        self.write_item(BASE_DEFECT, evidence="'C:\\\\notes\\\\backlog.md'")
        self.assert_rejects("absolute-path")
        self.write_item(BASE_DEFECT, evidence="knowledge/backlog.md")
        self.assert_accepts()

    def test_relative_paths_and_slashes_are_not_flagged(self):
        # `refs/heads/claim/<id>` is in the design's own prose; flagging it would
        # make the rule unusable.
        self.write_item(
            BASE_DEFECT,
            evidence="knowledge/sequences/s14.md",
            retires_when="The claim lands on refs/heads/claim/B-53 and the ref is released",
        )
        self.assert_accepts()


class TestRetirementRatchet(QueueTestCase):
    """`retires_when` is a ratchet, not a day-one hard failure.

    The backlog being migrated carried 34 retirement conditions across 119 items
    on 2026-09-05. Failing on day one would block the migration this check
    exists to protect, so the count is a number that must not increase.
    """

    def test_debt_may_sit_at_the_baseline(self):
        self.write_item(BASE_DEFECT, retires_when=None)
        output = self.assert_accepts("--retirement-debt-baseline", "1")
        self.assertIn("Defects with no `retires_when`: 1", output)
        self.assertIn("ratchet", output)

    def test_debt_above_the_baseline_fails(self):
        self.write_item(BASE_DEFECT, retires_when=None)
        self.write_item(BASE_DEFECT, id="B-54", filename="B-54.yaml", legacy="'#54'", retires_when=None)
        code, output = self.run_hub("lint", "--retirement-debt-baseline", "1")
        self.assertEqual(code, 1)
        self.assertIn("retirement debt rose from 1 to 2", output)
        # GREEN: giving the new defect a retirement condition puts it back.
        self.write_item(BASE_DEFECT, id="B-54", filename="B-54.yaml", legacy="'#54'")
        self.assert_accepts("--retirement-debt-baseline", "1")

    def test_debt_below_the_baseline_asks_for_the_baseline_to_be_lowered(self):
        self.write_item(BASE_DEFECT)
        output = self.assert_accepts("--retirement-debt-baseline", "3")
        self.assertIn("ratchet is slack by 3", output)

    def test_a_non_defect_never_owes_a_retirement_condition(self):
        self.write_item(BASE_STREAM)
        self.write_item(BASE_QUESTION)
        output = self.assert_accepts("--retirement-debt-baseline", "0")
        self.assertIn("Defects with no `retires_when`: 0", output)

    def test_baseline_file_is_read_when_present(self):
        self.write_baseline(2)
        self.write_item(BASE_DEFECT, retires_when=None)
        output = self.assert_accepts()
        self.assertIn("baseline 2", output)
        self.assertIn(hub_queue.RETIREMENT_DEBT_BASELINE_FILE, output)

    def test_the_baseline_file_may_explain_itself(self):
        # The number has to be editable in one line and the file has to be able
        # to say why the number is what it is, or the reasoning ends up in a
        # commit message nobody reads back.
        self.baseline_path.write_text(
            "2\n# Everything below here is prose, not the baseline.\n",
            encoding="utf-8",
        )
        self.write_item(BASE_DEFECT, retires_when=None)
        self.assertIn("baseline 2", self.assert_accepts())

    def test_a_missing_baseline_file_fails_rather_than_defaulting(self):
        # RED. The defect this replaces was a baseline of 85 compiled into the
        # checker while the real debt was 0, which left 85 slack nobody could
        # see. A built-in fallback would restore exactly that, so there is none.
        self.baseline_path.unlink()
        self.write_item(BASE_DEFECT)
        self.assert_rejects("retirement-baseline-unreadable")
        # GREEN: recording the count puts it back.
        self.write_baseline(0)
        self.assert_accepts()

    def test_an_unparseable_baseline_file_fails(self):
        self.baseline_path.write_text("# only a comment\n", encoding="utf-8")
        self.write_item(BASE_DEFECT)
        self.assert_rejects("retirement-baseline-unreadable")
        self.write_baseline(0)
        self.assert_accepts()

    def test_a_baseline_of_zero_behaves_as_a_hard_requirement(self):
        # This is the state recorded on 2026-09-09: 0 defects with no
        # `retires_when`, so the ratchet has no slack left in it at all.
        self.write_baseline(0)
        self.write_item(BASE_DEFECT, retires_when=None)
        code, output = self.run_hub("lint")
        self.assertEqual(code, 1)
        self.assertIn("retirement debt rose from 0 to 1", output)
        self.write_item(BASE_DEFECT)
        self.assert_accepts()


# --------------------------------------------------------------------------
# render / check / list
# --------------------------------------------------------------------------


PROSE = """---
title: "Roadmap"
---

# Roadmap

Hand-written prose above the block, with a `|` pipe and a {brace}.

<!-- hub:generated:items:state=ready -->
stale text nobody updated
<!-- /hub:generated:items:state=ready -->

Hand-written prose below the block.
"""


class TestRender(QueueTestCase):
    def test_render_replaces_the_block_and_touches_nothing_else(self):
        self.write_item(BASE_DEFECT)
        path = self.write_prose("knowledge/roadmap.md", PROSE)
        before = path.read_text(encoding="utf-8")
        code, output = self.run_hub("render")
        self.assertEqual(code, 0, output)
        after = path.read_text(encoding="utf-8")

        head_before, _, _ = before.partition("<!-- hub:generated:")
        head_after, _, _ = after.partition("<!-- hub:generated:")
        self.assertEqual(head_before, head_after)
        tail_before = before.rpartition("<!-- /hub:generated:items:state=ready -->")[2]
        tail_after = after.rpartition("<!-- /hub:generated:items:state=ready -->")[2]
        self.assertEqual(tail_before, tail_after)

        self.assertNotIn("stale text nobody updated", after)
        self.assertIn("**B-53** — Fix the thing", after)

    def test_render_is_idempotent(self):
        self.write_item(BASE_DEFECT)
        path = self.write_prose("knowledge/roadmap.md", PROSE)
        self.run_hub("render")
        once = path.read_text(encoding="utf-8")
        code, _ = self.run_hub("render")
        self.assertEqual(code, 0)
        self.assertEqual(once, path.read_text(encoding="utf-8"))

    def test_render_writes_a_do_not_edit_line_naming_the_command(self):
        self.write_item(BASE_DEFECT)
        path = self.write_prose("knowledge/roadmap.md", PROSE)
        self.run_hub("render")
        self.assertIn(hub_queue.RENDER_COMMAND, path.read_text(encoding="utf-8"))

    def test_filters_alternatives_and_formats(self):
        self.write_item(BASE_DEFECT)
        self.write_item(BASE_DEFECT, id="B-54", filename="B-54.yaml", legacy="'#54'", state="done")
        self.write_item(BASE_STREAM)

        path = self.write_prose(
            "knowledge/views.md",
            "<!-- hub:generated:items:kind=defect,state=ready|done,format=ids -->\n"
            "<!-- /hub:generated:items:kind=defect,state=ready|done,format=ids -->\n\n"
            "<!-- hub:generated:items:kind=stream,format=table,fields=id|title|state -->\n"
            "<!-- /hub:generated:items:kind=stream,format=table,fields=id|title|state -->\n\n"
            "<!-- hub:generated:queue-summary -->\n<!-- /hub:generated:queue-summary -->\n\n"
            "<!-- hub:generated:retirement-debt -->\n<!-- /hub:generated:retirement-debt -->\n",
        )
        code, output = self.run_hub("render")
        self.assertEqual(code, 0, output)
        text = path.read_text(encoding="utf-8")
        self.assertIn("B-53, B-54", text)
        self.assertIn("| id | title | state |", text)
        self.assertIn("| S-12 | Hub coordination | icebox |", text)
        self.assertIn("| ready | 1 | 1 |", text)
        self.assertIn("Defects with no `retires_when`: **0**", text)

    def test_empty_result_uses_the_empty_sentence(self):
        self.write_item(BASE_DEFECT, state="done")
        path = self.write_prose(
            "knowledge/views.md",
            "<!-- hub:generated:items:state=ready,empty=Nothing is ready -->\n"
            "<!-- /hub:generated:items:state=ready,empty=Nothing is ready -->\n",
        )
        self.run_hub("render")
        self.assertIn("Nothing is ready", path.read_text(encoding="utf-8"))

    def test_unknown_block_name_is_an_error_naming_the_file(self):
        self.write_item(BASE_DEFECT)
        self.write_prose(
            "knowledge/views.md",
            "<!-- hub:generated:whatever -->\n<!-- /hub:generated:whatever -->\n",
        )
        code, output = self.run_hub("render")
        self.assertEqual(code, 2)
        self.assertIn("knowledge/views.md", output)
        self.assertIn("unknown block name", output)

    def test_unknown_filter_key_is_an_error(self):
        self.write_item(BASE_DEFECT)
        self.write_prose(
            "knowledge/views.md",
            "<!-- hub:generated:items:owner=brett -->\n<!-- /hub:generated:items:owner=brett -->\n",
        )
        code, output = self.run_hub("render")
        self.assertEqual(code, 2)
        self.assertIn("'owner'", output)

    def test_unpaired_marker_is_an_error(self):
        self.write_item(BASE_DEFECT)
        self.write_prose("knowledge/views.md", "<!-- hub:generated:queue-summary -->\nno closer\n")
        code, output = self.run_hub("render")
        self.assertEqual(code, 2)
        self.assertIn("do not pair up", output)

    def test_render_refuses_to_run_on_a_queue_that_does_not_parse(self):
        self.write_raw("B-53.yaml", "this is not the schema\n")
        self.write_prose("knowledge/roadmap.md", PROSE)
        code, output = self.run_hub("render")
        self.assertEqual(code, 2)
        self.assertIn("lint", output)


class TestCheck(QueueTestCase):
    """`check` is the only mechanism in the design that stops the measured drift.

    Section 9.1 measured 5 stale copies of metasalmon's version across 10 files
    on 2026-09-05. Every one of them was a passage a reader had to notice. This
    test is the demonstration that the build notices instead.
    """

    def test_drift_fails_and_names_file_block_and_fix(self):
        self.write_item(BASE_DEFECT)
        self.write_prose("knowledge/roadmap.md", PROSE)
        code, output = self.run_hub("check")
        self.assertEqual(code, 1)
        self.assertIn("knowledge/roadmap.md", output)
        self.assertIn("hub:generated:items:state=ready", output)
        self.assertIn(hub_queue.RENDER_COMMAND, output)

    def test_check_passes_after_render(self):
        self.write_item(BASE_DEFECT)
        self.write_prose("knowledge/roadmap.md", PROSE)
        self.assertEqual(self.run_hub("render")[0], 0)
        code, output = self.run_hub("check")
        self.assertEqual(code, 0, output)
        self.assertIn("OK", output)

    def test_check_notices_a_queue_edit_that_prose_has_not_followed(self):
        self.write_item(BASE_DEFECT)
        self.write_prose("knowledge/roadmap.md", PROSE)
        self.run_hub("render")
        self.assertEqual(self.run_hub("check")[0], 0)
        # The item moves on. This is the exact shape of the measured failure:
        # the state changed and the prose copy did not.
        self.write_item(BASE_DEFECT, state="done")
        code, output = self.run_hub("check")
        self.assertEqual(code, 1)
        self.assertIn("no longer matches the hub queue", output)

    def test_check_does_not_write(self):
        self.write_item(BASE_DEFECT)
        path = self.write_prose("knowledge/roadmap.md", PROSE)
        before = path.read_text(encoding="utf-8")
        self.run_hub("check")
        self.assertEqual(before, path.read_text(encoding="utf-8"))

    def test_files_without_markers_are_left_alone(self):
        self.write_item(BASE_DEFECT)
        path = self.write_prose("knowledge/orientation.md", "# Orientation\n\nNo markers here.\n")
        before = path.read_text(encoding="utf-8")
        self.assertEqual(self.run_hub("check")[0], 0)
        self.run_hub("render")
        self.assertEqual(before, path.read_text(encoding="utf-8"))


class TestNamedBlocks(QueueTestCase):
    """The four block names `queue/config.yaml` declares must render.

    They are the coordination point between this renderer and the prose files,
    which are written by someone else. A name declared in the configuration and
    unknown here fails the whole render with `unknown block name`, so each one
    is pinned.
    """

    def setUp(self):
        super().setUp()
        self.write_item(BASE_DEFECT, state="ready")
        self.write_item(
            BASE_DEFECT, id="B-54", filename="B-54.yaml", legacy="'#54'", state="done"
        )
        self.write_item(BASE_STREAM)
        self.write_item(BASE_QUESTION)

    def render_named(self, name):
        path = self.write_prose(
            "knowledge/views.md",
            f"<!-- hub:generated:{name} -->\n<!-- /hub:generated:{name} -->\n",
        )
        code, output = self.run_hub("render")
        self.assertEqual(code, 0, output)
        return path.read_text(encoding="utf-8")

    def test_every_configured_block_name_renders(self):
        for name in ("ready-queue", "stream-status", "open-defects", "needs-brett"):
            with self.subTest(block=name):
                text = self.render_named(name)
                self.assertIn(f"<!-- hub:generated:{name} -->", text)
                self.assertIn(hub_queue.RENDER_COMMAND, text)

    def test_ready_queue_holds_only_ready_and_claimable_items(self):
        text = self.render_named("ready-queue")
        self.assertIn("B-53", text)
        self.assertNotIn("B-54", text)
        self.assertNotIn("Q-21", text)

    def test_open_defects_excludes_done(self):
        text = self.render_named("open-defects")
        self.assertIn("| B-53 |", text)
        self.assertNotIn("| B-54 |", text)

    def test_ready_queue_says_why_it_is_empty(self):
        for path in self.queue.iterdir():
            path.unlink()
        self.write_item(BASE_QUESTION)
        text = self.render_named("ready-queue")
        self.assertIn("Nothing is ready to claim", text)
        self.assertIn("only when Brett promotes an item", text)


class TestMembersCrossCheck(QueueTestCase):
    """The queue configuration keeps a copy of the eight-row allowlist.

    Its own comment says the copy "is safe only because the render-and-check
    guard compares the two and fails when they disagree". This is that
    comparison, and these are its RED demonstrations. Without them the comment
    is a claim about a guard that does not exist.
    """

    CARD = (
        "# The salmon data ecosystem\n\n"
        "| Repo | Role |\n"
        "|---|---|\n"
        "| `metasalmon` (this repo) | The hub |\n"
        "| `smn-data-pkg` | The specification |\n"
        "\nProse after the table.\n"
    )

    def write_config(self, repos):
        lines = ["# configuration", "members:"]
        for repo in repos:
            lines.append(f"  - repo: {repo}")
            lines.append("    org: salmon-data-mobilization")
            lines.append("    forge: github")
        path = self.root / "queue" / "config.yaml"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("\n".join(lines) + "\n", encoding="utf-8")

    def write_card(self, text=None):
        path = self.root / "knowledge" / "domains" / "salmon-data-ecosystem.md"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text if text is not None else self.CARD, encoding="utf-8")

    def test_extra_member_in_the_configuration(self):
        self.write_item(BASE_DEFECT)
        self.write_card()
        self.write_config(["metasalmon", "smn-data-pkg", "invented-repo"])
        output = self.assert_rejects("members-drift")
        self.assertIn("'invented-repo'", output)
        self.write_config(["metasalmon", "smn-data-pkg"])
        self.assert_accepts()

    def test_member_missing_from_the_configuration(self):
        self.write_item(BASE_DEFECT)
        self.write_card()
        self.write_config(["metasalmon"])
        output = self.assert_rejects("members-drift")
        self.assertIn("'smn-data-pkg'", output)
        self.write_config(["metasalmon", "smn-data-pkg"])
        self.assert_accepts()

    def test_an_unreadable_allowlist_fails_rather_than_passing_quietly(self):
        # A cross-check that cannot find its source must say so. Failing open
        # here would leave the configuration's safety claim true-looking and
        # false, which is worse than having no check.
        self.write_item(BASE_DEFECT)
        self.write_card("# The salmon data ecosystem\n\nNo table at all.\n")
        self.write_config(["metasalmon"])
        self.assert_rejects("members-unreadable")
        self.write_card()
        self.write_config(["metasalmon", "smn-data-pkg"])
        self.assert_accepts()

    def test_a_missing_card_fails(self):
        self.write_item(BASE_DEFECT)
        self.write_config(["metasalmon"])
        self.assert_rejects("members-source-missing")
        self.write_card()
        self.write_config(["metasalmon", "smn-data-pkg"])
        self.assert_accepts()

    def test_check_reports_members_drift_too(self):
        self.write_item(BASE_DEFECT)
        self.write_card()
        self.write_config(["metasalmon"])
        code, output = self.run_hub("check")
        self.assertEqual(code, 1)
        self.assertIn("members-drift", output)

    def test_no_configuration_means_no_cross_check(self):
        self.write_item(BASE_DEFECT)
        self.assert_accepts()


class TestMemberCountBlock(QueueTestCase):
    """The member count is the one generated block sourced from the domain card.

    It exists because that number is one that actually drifted: the bundle said
    eight after the ninth member was admitted on 2026-09-05, and the sentence
    looked exactly as right as it had the week before.

    RETIRES WHEN: no prose restates the member count, or the allowlist stops
    living in a Markdown table.
    """

    def write_card(self, repos):
        rows = "".join(f"| `{repo}` | A role |\n" for repo in repos)
        path = self.root / "knowledge" / "domains" / "salmon-data-ecosystem.md"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(
            "# The salmon data ecosystem\n\n| Repo | Role |\n|---|---|\n" + rows,
            encoding="utf-8",
        )

    def render_count(self):
        path = self.write_prose(
            "knowledge/roadmap.md",
            "<!-- hub:generated:member-count -->\n<!-- /hub:generated:member-count -->\n",
        )
        code, output = self.run_hub("render")
        self.assertEqual(code, 0, output)
        return path.read_text(encoding="utf-8")

    def test_the_count_is_spelled_out_and_comes_from_the_card(self):
        self.write_item(BASE_DEFECT)
        self.write_card([f"repo-{n}" for n in range(9)])
        self.assertIn("has **nine** member repositories", self.render_count())

    def test_admitting_a_member_changes_the_rendered_sentence(self):
        # RED for the drift itself: the card gains a row and the prose must move
        # with it, which is the whole reason the sentence is generated.
        self.write_item(BASE_DEFECT)
        self.write_card([f"repo-{n}" for n in range(8)])
        self.assertIn("**eight**", self.render_count())
        self.assertEqual(self.run_hub("check")[0], 0)
        self.write_card([f"repo-{n}" for n in range(9)])
        code, output = self.run_hub("check")
        self.assertEqual(code, 1, output)
        self.assertIn("member-count", output)

    def test_one_member_is_singular(self):
        self.write_item(BASE_DEFECT)
        self.write_card(["metasalmon"])
        self.assertIn("has **one** member repository.", self.render_count())

    def test_a_card_that_cannot_be_counted_fails_rather_than_rendering_zero(self):
        self.write_item(BASE_DEFECT)
        path = self.root / "knowledge" / "domains" / "salmon-data-ecosystem.md"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("# The salmon data ecosystem\n\nNo table at all.\n", encoding="utf-8")
        self.write_prose(
            "knowledge/roadmap.md",
            "<!-- hub:generated:member-count -->\n<!-- /hub:generated:member-count -->\n",
        )
        code, output = self.run_hub("render")
        self.assertEqual(code, 2, output)
        self.assertIn("no allowlist rows", output)


class TestConfiguredBlocksExist(QueueTestCase):
    """A block the configuration declares must be present in its target file.

    THE DEFECT THIS PINS, measured 2026-09-09. `check` walked the prose files,
    skipped every file with no `hub:generated:` marker, compared what was left,
    and printed "OK: every generated block matches the hub queue".
    `generated_blocks` in the configuration was never read by any code path. The
    repository had zero markers in it, so the guard walked nothing, compared
    nothing, and reported success. Green meant nothing at all.

    The first test below is that exact repository state, and it is the one that
    matters: a configured block with no marker anywhere has to fail.

    RETIRES WHEN: `generated_blocks` is deleted from the queue configuration
    because no prose file restates queue state any more.
    """

    CARD = (
        "# The salmon data ecosystem\n\n"
        "| Repo | Role |\n"
        "|---|---|\n"
        "| `metasalmon` (this repo) | The hub |\n"
        "\nProse after the table.\n"
    )

    def write_world(self, blocks, targets):
        """Write a card, a matching members list, `blocks`, and `targets`."""
        card = self.root / "knowledge" / "domains" / "salmon-data-ecosystem.md"
        card.parent.mkdir(parents=True, exist_ok=True)
        card.write_text(self.CARD, encoding="utf-8")

        lines = [
            "# configuration",
            "members:",
            "  - repo: metasalmon",
            "    org: salmon-data-mobilization",
            "    forge: github",
            "",
            "generated_blocks:",
        ]
        for block, target in blocks:
            lines.append(f"  - block: {block}")
            if target is not None:
                lines.append(f"    target: {target}")
        config = self.root / "queue" / "config.yaml"
        config.parent.mkdir(parents=True, exist_ok=True)
        config.write_text("\n".join(lines) + "\n", encoding="utf-8")

        for relpath, text in targets.items():
            self.write_prose(relpath, text)

    @staticmethod
    def markers(name):
        return f"<!-- hub:generated:{name} -->\n<!-- /hub:generated:{name} -->\n"

    def test_a_configured_block_with_no_marker_anywhere_fails(self):
        # RED, and this is the blocker verbatim: the configuration declares a
        # block, the repository carries no markers at all, and the old `check`
        # printed OK.
        self.write_item(BASE_DEFECT)
        self.write_world([("queue-summary", "HUB.md")], {"HUB.md": "# Hub\n\nNo markers.\n"})
        code, output = self.run_hub("check")
        self.assertEqual(code, 1, output)
        self.assertNotIn("OK: every generated block matches", output)
        self.assertIn("queue-summary", output)
        self.assertIn("HUB.md", output)
        self.assertIn("not a skip", output)

        # GREEN: adding the marker pair and rendering it satisfies the check.
        self.write_prose("HUB.md", "# Hub\n\n" + self.markers("queue-summary"))
        self.assertEqual(self.run_hub("render")[0], 0)
        code, output = self.run_hub("check")
        self.assertEqual(code, 0, output)
        self.assertIn("OK", output)

    def test_the_marker_must_be_in_the_configured_target_not_merely_somewhere(self):
        self.write_item(BASE_DEFECT)
        self.write_world(
            [("queue-summary", "HUB.md")],
            {
                "HUB.md": "# Hub\n\nNo markers.\n",
                "knowledge/elsewhere.md": self.markers("queue-summary"),
            },
        )
        code, output = self.run_hub("check")
        self.assertEqual(code, 1, output)
        self.assertIn("HUB.md", output)

    def test_half_a_marker_pair_is_reported_as_missing(self):
        self.write_item(BASE_DEFECT)
        self.write_world(
            [("queue-summary", "HUB.md")],
            {"HUB.md": "# Hub\n\n<!-- hub:generated:queue-summary -->\n"},
        )
        code, output = self.run_hub("check")
        # Exit 2 rather than 1: the presence check names the half-pair first,
        # then the renderer refuses the file outright because an opener with no
        # closer delimits nothing it could rewrite. Both are failures and the
        # order is what makes the message readable.
        self.assertNotEqual(code, 0, output)
        self.assertIn("only one half", output)
        self.assertIn("do not pair up", output)

    def test_a_configured_target_that_does_not_exist_fails(self):
        self.write_item(BASE_DEFECT)
        self.write_world([("queue-summary", "HUB.md")], {})
        code, output = self.run_hub("check")
        self.assertEqual(code, 1, output)
        self.assertIn("does not exist", output)

    def test_a_configured_block_with_no_target_fails(self):
        self.write_item(BASE_DEFECT)
        self.write_world([("queue-summary", None)], {})
        code, output = self.run_hub("check")
        self.assertEqual(code, 1, output)
        self.assertIn("declares no `target:`", output)

    def test_a_configuration_declaring_no_blocks_fails(self):
        # A configuration with the key absent leaves `check` with nothing to
        # look for, which is the same silence in a different place.
        self.write_item(BASE_DEFECT)
        card = self.root / "knowledge" / "domains" / "salmon-data-ecosystem.md"
        card.parent.mkdir(parents=True, exist_ok=True)
        card.write_text(self.CARD, encoding="utf-8")
        config = self.root / "queue" / "config.yaml"
        config.parent.mkdir(parents=True, exist_ok=True)
        config.write_text(
            "members:\n  - repo: metasalmon\n    org: salmon-data-mobilization\n"
            "    forge: github\n",
            encoding="utf-8",
        )
        code, output = self.run_hub("check")
        self.assertEqual(code, 1, output)
        self.assertIn("generated-blocks-unreadable", output)

    def test_every_block_the_real_configuration_declares_is_renderable(self):
        # Every block the real configuration promises must actually render.
        #
        # This asserted membership of BLOCK_ALIASES until 2026-09-09 and failed
        # the moment the configuration was trimmed to the one block that has a
        # marker, because `member-count` is dispatched by name in render_block
        # rather than aliased. The narrower assertion was testing how the
        # renderer is wired rather than what it can do, which is the shape of
        # test that fails on a correct change. Renderability is the property
        # the configuration actually promises.
        real = Path(__file__).resolve().parent.parent.parent / "queue" / "config.yaml"
        if not real.is_file():
            self.skipTest("the real queue configuration is not in this checkout")
        entries = hub_queue.read_config_generated_blocks(real)
        self.assertTrue(entries, "generated_blocks could not be read from the real config")
        root = real.parent.parent
        items, _ = hub_queue.load_queue(root, root / "queue" / "items")
        for block, target in entries:
            with self.subTest(block=block):
                self.assertTrue(target, f"{block} has no target")
                try:
                    hub_queue.render_block(block, items, 0, "test", root)
                except hub_queue.BlockError as exc:
                    self.fail(f"configured block {block!r} does not render: {exc}")

    def test_an_unconfigured_marker_pair_is_not_reported(self):
        # A hand-written `items:` query in prose is legitimate. This check is
        # about blocks the configuration promises, not about every marker.
        self.write_item(BASE_DEFECT)
        self.write_world(
            [("queue-summary", "HUB.md")],
            {
                "HUB.md": "# Hub\n\n" + self.markers("queue-summary"),
                "knowledge/views.md": self.markers("items:kind=defect"),
            },
        )
        self.assertEqual(self.run_hub("render")[0], 0)
        code, output = self.run_hub("check")
        self.assertEqual(code, 0, output)


class TestList(QueueTestCase):
    def test_list_groups_by_state_and_marks_the_unclaimable(self):
        self.write_item(BASE_DEFECT)
        self.write_item(BASE_QUESTION)
        self.write_item(BASE_STREAM)
        code, output = self.run_hub("list")
        self.assertEqual(code, 0)
        self.assertIn("ready (1)", output)
        self.assertIn("needs_brett (1)", output)
        self.assertIn("B-53", output)
        self.assertIn("not claimable", output)
        self.assertIn("3 item(s).", output)

    def test_list_on_an_empty_queue_says_so(self):
        code, output = self.run_hub("list")
        self.assertEqual(code, 0)
        self.assertIn("No items", output)


class TestOrdering(QueueTestCase):
    """Rendered bytes must not depend on the machine that produced them.

    The repository's collation contract says any ordering whose result is
    written to file bytes uses C collation. Ids sort by prefix then integer, so
    B-9 precedes B-10 rather than following it, and every other sort is a plain
    codepoint sort.
    """

    def test_ids_sort_numerically_not_lexically(self):
        for number in (9, 10, 100):
            self.write_item(
                BASE_DEFECT,
                id=f"B-{number}",
                filename=f"B-{number}.yaml",
                legacy=f"'#{number}'",
            )
        path = self.write_prose(
            "knowledge/views.md",
            "<!-- hub:generated:items:format=ids -->\n<!-- /hub:generated:items:format=ids -->\n",
        )
        self.run_hub("render")
        self.assertIn("B-9, B-10, B-100", path.read_text(encoding="utf-8"))

    def test_kind_prefixes_group_backlog_then_stream_then_question(self):
        self.write_item(BASE_DEFECT)
        self.write_item(BASE_STREAM)
        self.write_item(BASE_QUESTION)
        path = self.write_prose(
            "knowledge/views.md",
            "<!-- hub:generated:items:format=ids -->\n<!-- /hub:generated:items:format=ids -->\n",
        )
        self.run_hub("render")
        self.assertIn("B-53, S-12, Q-21", path.read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
