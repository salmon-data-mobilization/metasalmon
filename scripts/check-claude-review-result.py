#!/usr/bin/env python3
"""Check SDK review completion without publishing its messages or tool output.

Retires when the action fails on denied tools and exposes a checked head result.
A successful process alone does not prove that the requested review took place.
"""
import json
import os
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
