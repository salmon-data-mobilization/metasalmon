#!/usr/bin/env python3
"""Keep the five-marker budget; trust nits only after verified execution.

Read public GitHub metadata with the workflow's existing read token. No extra
Actions permission, token generation, logs, artifacts or writes are needed.
Retires when the action provides verified round accounting itself. Missing or
ambiguous metadata fails closed before model execution, rather than spending
another subscription review or interpreting an incomplete round as nits-only.
"""
import json
import os
import re
import subprocess
from datetime import datetime
from pathlib import Path

VERDICT = re.compile(r"<!-- claude-review verdict=(important|nits) -->\s*$")
HEAD = re.compile(r"^Head\s+([0-9a-f]{7,40})(?=[:\s])", re.IGNORECASE)
WORKFLOW = "claude-code-review.yml"


def marker_comments(comments):
    if not isinstance(comments, list):
        raise ValueError("review comments are not a list")
    result = []
    for comment in comments:
        if comment.get("user", {}).get("login") != "claude[bot]":
            continue
        body = comment.get("body", "")
        verdict = VERDICT.search(body)
        if verdict:
            result.append((comment, verdict.group(1)))
    return sorted(result, key=lambda row: (row[0]["created_at"], row[0]["id"]))


def in_action_window(timestamp, action):
    """GitHub mixes whole-second and fractional ISO timestamps."""
    try:
        parse = lambda value: datetime.fromisoformat(value.replace("Z", "+00:00"))
        return parse(action["started_at"]) <= parse(timestamp) <= parse(action["completed_at"])
    except (ValueError, KeyError, TypeError):
        return False


def completed_round(comment, pr, runs, jobs_for_run):
    """A green skip or a model-written verdict cannot attest completion."""
    head = HEAD.match(comment["body"].strip())
    if not head:
        return False
    candidates = []
    for run in runs:
        if (run.get("event") != "pull_request" or
                run.get("conclusion") != "success" or
                not run.get("head_sha", "").startswith(head.group(1)) or
                not any(p.get("number") == pr for p in run.get("pull_requests", []))):
            continue
        for job in jobs_for_run(run["id"]):
            steps = {s["name"]: s for s in job.get("steps", [])}
            action = steps.get("Run Claude Code Review", {})
            guard = steps.get("Verify review execution", {})
            if (job.get("name") == "claude-review" and job.get("conclusion") == "success"
                    and action.get("conclusion") == "success"
                    and guard.get("conclusion") == "success"
                    and in_action_window(comment["created_at"], action)):
                candidates.append(run["id"])
    # Do not assign one comment to multiple possible runs/attempts.
    return len(set(candidates)) == 1


def decide(comments, pr, runs_for_head, jobs_for_run):
    markers = marker_comments(comments)
    count = len(markers)
    if count >= 5:
        return count + 1, True, "five review-marker budget exhausted"
    if markers:
        comment, verdict = markers[-1]
        head = HEAD.match(comment["body"].strip())
        if verdict == "nits" and head and completed_round(
                comment, pr, runs_for_head(head.group(1)), jobs_for_run):
            return count + 1, True, "last nits verdict belongs to a verified completed review"
    return count + 1, False, "no verified nits-only completion"


class Metadata:
    def __init__(self, repo):
        if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", repo):
            raise ValueError("invalid repository")
        self.repo = repo
        self.calls = 0

    def read(self, suffix, key=None):
        self.calls += 1
        if self.calls > 20:
            raise ValueError("review metadata request budget exhausted")
        response = subprocess.run(
            ["gh", "api", "--paginate", "--slurp", f"repos/{self.repo}/{suffix}"],
            text=True, capture_output=True, timeout=45, check=False)
        if response.returncode:
            # Never echo response/command/error text, which can contain tokens.
            raise ValueError("public review metadata unavailable; model execution withheld")
        pages = json.loads(response.stdout)
        return [item for page in pages for item in (page[key] if key else page)]

    def runs(self, head):
        # GitHub head_sha filter takes a full SHA. Prefixes in historical
        # summaries are resolved through the existing read-only commit API.
        response = subprocess.run(
            ["gh", "api", f"repos/{self.repo}/commits/{head}", "--jq", ".sha"],
            text=True, capture_output=True, timeout=30, check=False)
        if response.returncode or not re.fullmatch(r"[0-9a-f]{40}\n?", response.stdout):
            raise ValueError("reviewed commit metadata unavailable")
        sha = response.stdout.strip()
        return self.read(f"actions/workflows/{WORKFLOW}/runs?event=pull_request&head_sha={sha}&per_page=100", "workflow_runs")

    def jobs(self, run_id):
        return self.read(f"actions/runs/{int(run_id)}/jobs?filter=all&per_page=100", "jobs")


def main():
    api = Metadata(os.environ["REPO"])
    pr = int(os.environ["PR"])
    comments = api.read(f"issues/{pr}/comments?per_page=100")
    round_number, skip, reason = decide(comments, pr, api.runs, api.jobs)
    with Path(os.environ["GITHUB_OUTPUT"]).open("a") as output:
        output.write(f"round={round_number}\nskip={str(skip).lower()}\n")
    print(f"Review accounting: {reason}; next round {round_number}.")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, OSError, TypeError, subprocess.TimeoutExpired):
        raise SystemExit("Review accounting unavailable; model execution withheld.")
