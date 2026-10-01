#!/usr/bin/env python3
"""Count available CI attempts, including failures hidden by successful reruns.

Usage: python3 scripts/ci-attempt-history.py > /tmp/ci-attempt-history.json
Requires an authenticated `gh` CLI; all API requests use GET. Single-attempt
runs use their only conclusion from the listing. For every discovered rerun,
read all per-attempt endpoints. No log download or prior list of reruns needed.

Counts cover the available workflow runs, not deleted history. Listing and
attempt reads are not an atomic snapshot; a new rerun after listing is outside
this observation. HTTP/schema failures abort rather than returning a partial
count. No R/Python package behavior is changed by this hub measurement tool.
"""

import argparse
from datetime import datetime, timezone
import json
import re
import subprocess
import sys
from urllib.parse import quote


def github_get(path, *, paginate=False):
    """Read JSON using existing CLI authentication without handling credentials."""
    command = ["gh", "api", "--method", "GET"]
    if paginate:
        command.extend(["--paginate", "--slurp"])
    result = subprocess.run(command + [path], check=True, capture_output=True, text=True)
    return json.loads(result.stdout)


def validate_record(record):
    if not isinstance(record, dict):
        raise ValueError("An API run/attempt is not an object.")
    for field in ("id", "run_number", "run_attempt"):
        if type(record.get(field)) is not int or record[field] < 1:
            raise ValueError(f"An API run/attempt lacks a positive {field}.")
    if not isinstance(record.get("status"), str) or not record["status"]:
        raise ValueError("An API run/attempt lacks its status.")
    conclusion = record.get("conclusion")
    if record["status"] == "completed" and not isinstance(conclusion, str):
        raise ValueError("A completed API run/attempt lacks its conclusion.")
    if conclusion is not None and not isinstance(conclusion, str):
        raise ValueError("An API run/attempt has an invalid conclusion.")
    if not isinstance(record.get("head_sha"), str) or not record["head_sha"]:
        raise ValueError("An API run/attempt lacks its head SHA.")


def is_completed_as(record, conclusion):
    return record["status"] == "completed" and record["conclusion"] == conclusion


def collect_history(repo, workflow, api_get=github_get):
    if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", repo):
        raise ValueError("Repository must be owner/name.")
    prefix = f"repos/{repo}/actions"
    pages = api_get(
        f"{prefix}/workflows/{quote(workflow, safe='')}/runs?per_page=100",
        paginate=True,
    )
    if not isinstance(pages, list) or not pages:
        raise ValueError("The paginated workflow listing is absent or malformed.")
    runs = {}
    for page in pages:
        if not isinstance(page, dict) or not isinstance(page.get("workflow_runs"), list):
            raise ValueError("A workflow page lacks its run list.")
        for run in page["workflow_runs"]:
            validate_record(run)
            # New runs can shift page boundaries while pagination is in progress.
            # Count an overlapping ID once; report the observation's scope above.
            runs.setdefault(run["id"], run)

    counts = {
        "snapshot_run_count": len(runs),
        "observed_attempt_count": 0,
        "failed_run_count_from_listing": 0,
        "failed_attempt_count": 0,
        "rerun_count": 0,
        "successful_rerun_count_with_prior_failed_attempts": 0,
        "failed_attempt_count_hidden_by_successful_reruns": 0,
        "incomplete_attempt_count": 0,
    }
    reruns = []
    for run in sorted(runs.values(), key=lambda row: row["run_number"]):
        counts["failed_run_count_from_listing"] += is_completed_as(run, "failure")
        history = [run]
        if run["run_attempt"] > 1:
            history = []
            for number in range(1, run["run_attempt"] + 1):
                attempt = api_get(f"{prefix}/runs/{run['id']}/attempts/{number}")
                validate_record(attempt)
                if any(attempt[field] != run[field] for field in ("id", "run_number", "head_sha")) or attempt["run_attempt"] != number:
                    raise ValueError("An attempt endpoint returned a different run/attempt.")
                history.append(attempt)
            prior_failures = sum(is_completed_as(row, "failure") for row in history[:-1])
            recovered = is_completed_as(history[-1], "success") and prior_failures > 0
            counts["rerun_count"] += 1
            counts["successful_rerun_count_with_prior_failed_attempts"] += recovered
            counts["failed_attempt_count_hidden_by_successful_reruns"] += prior_failures if recovered else 0
            reruns.append({
                "run_number": run["run_number"],
                "run_id": run["id"],
                "listed_conclusion": run["conclusion"],
                "attempts": [{
                    "number": row["run_attempt"],
                    "status": row["status"],
                    "conclusion": row["conclusion"],
                } for row in history],
            })
        counts["observed_attempt_count"] += len(history)
        counts["failed_attempt_count"] += sum(is_completed_as(row, "failure") for row in history)
        counts["incomplete_attempt_count"] += sum(row["status"] != "completed" for row in history)

    return {
        "repository": repo,
        "workflow": workflow,
        "observed_at_utc": datetime.now(timezone.utc).isoformat(),
        "scope": "Available runs from all API pages; non-atomic observation; each count names its unit.",
        "counts": counts,
        "reruns": reruns,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", default="salmon-data-mobilization/metasalmon")
    parser.add_argument("--workflow", default="R-CMD-check.yaml")
    args = parser.parse_args()
    try:
        report = collect_history(args.repo, args.workflow)
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        print(f"CI attempt-history read failed: {error}", file=sys.stderr)
        return 1
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
