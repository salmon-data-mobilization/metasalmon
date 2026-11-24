#!/usr/bin/env python3
"""Count available CI attempts, including failures hidden by successful reruns.

Usage: python3 scripts/ci-attempt-history.py --control-run-id 35105540412 > /tmp/ci-attempt-history.json
Requires an authenticated `gh` CLI; all API requests use GET. Single-attempt
runs use their only conclusion from the listing. For every discovered rerun,
read all per-attempt endpoints. The caller supplies one independently known
failed-then-successful rerun as a positive control; it is not a filter or a
prior list of reruns. No log download is needed.

Counts cover the available workflow runs, not deleted history. Listing and
attempt reads are not an atomic snapshot; a new rerun after listing is outside
this observation. A deleted/changed control must be replaced with another
independently known rerun. HTTP/schema/control failures abort rather than
returning a plausible partial count. No R/Python package behavior is changed
by this hub measurement tool.
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


def _collect_history_unchecked(repo, workflow, api_get=github_get):
    """Count returned API rows; the public wrapper checks independent reach."""
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
        "rerun_run_count": 0,
        "successful_rerun_count_with_prior_failed_attempts": 0,
        "failed_attempt_count_hidden_by_successful_reruns": 0,
        "incomplete_attempt_count": 0,
    }
    reruns = []
    for run in sorted(runs.values(), key=lambda row: row["run_number"]):
        counts["failed_run_count_from_listing"] += is_completed_as(run, "failure")
        history = [run]
        if run["run_attempt"] > 1:
            # Re-read the latest attempt too: its endpoint must agree with
            # earlier attempts about the run identity and head SHA.
            history = []
            for number in range(1, run["run_attempt"] + 1):
                attempt = api_get(f"{prefix}/runs/{run['id']}/attempts/{number}")
                validate_record(attempt)
                if any(attempt[field] != run[field] for field in ("id", "run_number", "head_sha")) or attempt["run_attempt"] != number:
                    raise ValueError("An attempt endpoint returned a different run/attempt.")
                history.append(attempt)
            prior_failures = sum(is_completed_as(row, "failure") for row in history[:-1])
            recovered = is_completed_as(history[-1], "success") and prior_failures > 0
            counts["rerun_run_count"] += 1
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
        "scope": "Runs returned by paginated API; non-atomic observation; each count names its unit.",
        "counts": counts,
        "reruns": reruns,
    }


def collect_history(repo, workflow, *, control_run_id, api_get=github_get):
    """Return counts only if a known failed-to-successful rerun was observed."""
    if type(control_run_id) is not int or control_run_id < 1:
        raise ValueError("A positive control run ID must be a positive integer.")
    report = _collect_history_unchecked(repo, workflow, api_get)
    control = next(
        (run for run in report["reruns"] if run["run_id"] == control_run_id),
        None,
    )
    if (control is None
            or control["listed_conclusion"] != "success"
            or not is_completed_as(control["attempts"][-1], "success")
            or not any(
                is_completed_as(attempt, "failure")
                for attempt in control["attempts"][:-1]
            )):
        raise ValueError(
            f"Required positive control run {control_run_id} is absent or no longer "
            "shows an earlier failure followed by success; supply another independently "
            "known rerun before reporting counts."
        )
    report["positive_control_run_id"] = control_run_id
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", default="salmon-data-mobilization/metasalmon")
    parser.add_argument("--workflow", default="R-CMD-check.yaml")
    parser.add_argument("--control-run-id", type=int, required=True,
                        help="ID of an independently known failed-then-successful rerun")
    args = parser.parse_args()
    try:
        report = collect_history(args.repo, args.workflow, control_run_id=args.control_run_id)
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        print(f"CI attempt-history read failed: {error}", file=sys.stderr)
        return 1
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
