#!/usr/bin/env python3
"""Check SDK review completion without publishing its messages or tool output.

Retires when the action fails on denied tools and exposes a checked head result.
A successful process alone does not prove that the requested review took place.
"""
import json
import os
import re
from pathlib import Path


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
        raise ValueError("Claude review had denied tool calls")
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
