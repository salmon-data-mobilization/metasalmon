#!/usr/bin/env python3
"""Check SDK review completion without publishing its messages or tool output.

Retires when the action fails on denied tools and exposes a checked head result.
A successful process alone does not prove that the requested review took place.
Denied calls are described by fixed categories only: never print SDK inputs,
paths, command arguments or output, which may contain private source or secrets.
"""
import json
import os
import re
import shlex
from pathlib import Path


def denial_summary(denials):
    """Describe failed reach without copying untrusted text into a CI log."""
    if not isinstance(denials, list):
        return "unknown denial record"
    # Only known labels can be emitted. Even a syntactically valid tool name
    # can contain private text; validating its characters would not redact it.
    known_tools = {"Bash", "Read", "Grep", "Glob", "Edit", "Write", "WebFetch",
                   "WebSearch", "Task", "ToolSearch",
                   "mcp__github_inline_comment__create_inline_comment"}
    known_commands = {"git", "gh", "rg", "cat", "sed", "pwd", "ls", "find",
                      "head", "tail", "python", "python3", "Rscript", "bash", "sh"}
    known_git_actions = {"diff", "show", "status", "log", "rev-parse", "ls-files"}
    labels = []
    omitted = False
    for denial in denials:
        name = denial.get("tool_name") if isinstance(denial, dict) else None
        label = name if isinstance(name, str) and name in known_tools else "unknown"
        if label == "Bash":
            label = "Bash:unclassified"
            inputs = denial.get("tool_input")
            command = inputs.get("command") if isinstance(inputs, dict) else None
            if isinstance(command, str) and len(command) <= 20000:
                try:
                    words = shlex.split(command)
                except ValueError:
                    words = []
                if words and words[0] in known_commands:
                    category = words[0]
                    if category == "git" and len(words) > 1 and words[1] in known_git_actions:
                        category += " " + words[1]
                    elif category == "gh" and len(words) > 2 and words[1] == "pr" and words[2] in {"view", "diff", "comment", "checks"}:
                        category += " pr " + words[2]
                    label = "Bash:" + category
        if label not in labels:
            if len(labels) < 8:
                labels.append(label)
            else:
                omitted = True
    suffix = "; additional categories omitted" if omitted else ""
    return f"{len(denials)} calls; {', '.join(labels)}{suffix}"


def check_review(messages, head):
    if not isinstance(messages, list):
        raise ValueError("Claude execution record is not a message list")
    results = [m for m in messages if isinstance(m, dict) and m.get("type") == "result"]
    if len(results) != 1:
        raise ValueError("Claude review has no unique completion result")
    result = results[0]
    if result.get("subtype") != "success" or result.get("is_error") is not False:
        raise ValueError("Claude review did not complete successfully")
    if result.get("permission_denials"):
        raise ValueError("Claude review had denied tool calls (" +
                         denial_summary(result["permission_denials"]) + ")")
    # A final marker alone can be emitted without reading or posting anything.
    # Require successful SDK tool results for PR view/diff and the summary
    # `gh pr comment`; an inline comment alone carries no round marker.
    uses = {}
    completed = set()
    for message in messages:
        if not isinstance(message, dict):
            continue
        content = message.get("content", [])
        if message.get("type") == "assistant":
            content = message.get("message", {}).get("content", content)
        elif message.get("type") == "user":
            content = message.get("message", {}).get("content", content)
        if not isinstance(content, list):
            continue
        for block in content:
            if not isinstance(block, dict):
                continue
            if block.get("type") == "tool_use":
                command = block.get("input", {}).get("command", "")
                if block.get("name") == "Bash":
                    match = re.match(r"^gh pr (view|diff|comment)\b", command.strip())
                    if match:
                        uses[block.get("id")] = match.group(1)
            elif (block.get("type") == "tool_result" and not block.get("is_error", False)
                  and block.get("content")):
                completed.add(block.get("tool_use_id"))
    if not {"view", "diff", "comment"}.issubset({uses[i] for i in completed if i in uses}):
        raise ValueError("Claude execution lacks successful PR view, diff or review-post tools")
    response = result.get("result")
    if (not head or not isinstance(response, str) or not response.splitlines()
            or response.splitlines()[-1] != f"REVIEWED_HEAD={head}"):
        raise ValueError("Claude did not confirm review completion for this head")


if __name__ == "__main__":
    try:
        path = os.environ.get("CLAUDE_EXECUTION_FILE", "")
        if not path:
            raise ValueError("Claude action provided no execution file")
        check_review(json.loads(Path(path).read_text()), os.environ.get("REVIEWED_HEAD", ""))
    except (ValueError, OSError, TypeError) as error:
        raise SystemExit(f"Incomplete Claude review: {error}")
    print("Claude review completed for the requested head with no denied tool calls.")
