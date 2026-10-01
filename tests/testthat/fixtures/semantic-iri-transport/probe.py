"""Manual B-130 paired localhost transport proof; no external HTTP/model call.

Run with the selected Python checkout installed and R curl/jsonlite/pkgload installed:
  uv run --no-project --with-editable /path/to/metasalmonpy python probe.py \
    --r-repo /path/to/metasalmon --python-repo /path/to/metasalmonpy

This fixture is separate from R's injected CI tests. It records the real
resolved 103 compatibility gap using both default transports, without a skip.
Retires as a separate probe when both CI jobs can run the paired default
transport fixture with their normal supported dependencies.
"""

import argparse
import csv
import json
import platform
import subprocess
import threading
import tempfile
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

import httpx
import httpcore
from metasalmonpy import semantic_iri_verification as python_transport
from metasalmonpy import verify_sdp_semantic_iris

R_PROBE = """
args <- commandArgs(TRUE)
source(args[[1]])
.ms_semantic_iri_request_timeout <- as.numeric(args[[3]])
started <- proc.time()[['elapsed']]
result <- tryCatch(.ms_semantic_iri_request(args[[2]]),
                   error = function(e) list(error = conditionMessage(e)))
result$elapsed <- proc.time()[['elapsed']] - started
cat(jsonlite::toJSON(result, auto_unbox = TRUE))
"""


R_REPORT_PROBE = """
args <- commandArgs(TRUE)
pkgload::load_all(args[[1]], quiet = TRUE)
.ms_semantic_iri_request_timeout <- as.numeric(args[[3]])
unlockBinding(".ms_semantic_iri_request_timeout", asNamespace("metasalmon"))
assign(".ms_semantic_iri_request_timeout", as.numeric(args[[3]]), envir = asNamespace("metasalmon"))
lockBinding(".ms_semantic_iri_request_timeout", asNamespace("metasalmon"))
invisible(tryCatch(verify_sdp_semantic_iris(args[[2]], sleep_fn = function(...) NULL),
                   error = function(error) NULL))
rows <- readr::read_csv(file.path(args[[2]], "reproducibility/provenance/semantic-iri-dereference.csv"),
                       show_col_types = FALSE)
cat(jsonlite::toJSON(list(attempts = as.integer(rows$attempts), error = rows$error),
                     auto_unbox = TRUE))
"""


def report_attempts(repo, iri, timeout):
    """Compare public default report attempts, including transient timeout control."""
    with tempfile.TemporaryDirectory() as temporary:
        root = Path(temporary)
        metadata = root / "metadata"
        metadata.mkdir()
        for name, header, value in [("dataset.csv", "dataset_id", "iri-test"),
                                    ("tables.csv", "table_id", "observations"),
                                    ("column_dictionary.csv", "term_iri", iri)]:
            with (metadata / name).open("w", newline="") as stream:
                writer = csv.writer(stream)
                writer.writerow([header])
                writer.writerow([value])
        run = subprocess.run(["Rscript", "-e", R_REPORT_PROBE, str(repo), str(root), str(timeout)],
                             capture_output=True, text=True, timeout=timeout * 3 + 10)
        assert run.returncode == 0, run.stderr
        r_result = json.loads(run.stdout)
        try:
            verify_sdp_semantic_iris(root, sleep_fn=lambda seconds: None)
        except ValueError:
            pass
        with (root / "reproducibility/provenance/semantic-iri-dereference.csv").open() as stream:
            row = next(csv.DictReader(stream))
        return {"R": r_result, "Python": {"attempts": int(row["attempts"]), "error": row["error"]}}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--r-repo", required=True, type=Path)
    parser.add_argument("--python-repo", required=True, type=Path)
    parser.add_argument("--timeout", type=float, default=0.8)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    assert Path(python_transport.__file__).resolve() == (
        args.python_repo / "semantic_iri_verification.py").resolve(), "Wrong Python checkout"
    source = args.r_repo / "R/semantic-iri-verification.R"
    assert source.is_file()
    assert args.timeout > 0
    release = threading.Event()

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            path = self.path
            if path in ("/redirect", "/chain", "/stale-redirect", "/redirect-body"):
                self.send_response(301 if path == "/chain" else 302)
                target = "/redirect" if path == "/chain" else (
                    "/partial" if path == "/stale-redirect" else "/body")
                self.send_header("Location", target)
                self.send_header("Content-Length", "1000000" if path == "/redirect-body" else "0")
                self.end_headers()
                if path == "/redirect-body":
                    release.wait(30)
                return
            if path == "/loop":
                self.send_response(302)
                self.send_header("Location", "/loop")
                self.send_header("Content-Length", "0")
                self.end_headers()
                return
            if path == "/interim":
                self.wfile.write(b"HTTP/1.1 103 Early Hints\r\nLink: </hint>\r\n\r\n")
                self.wfile.flush()
            if path == "/headers":
                release.wait(30)
                return
            if path == "/partial":
                self.wfile.write(b"HTTP/1.1 200 OK\r\nContent-Length: 1000000\r\n")
                self.wfile.flush()
                release.wait(30)
                return
            self.send_response(302 if path == "/terminal302" else (
                404 if path == "/missing" else 200))
            self.send_header("Content-Length", "1000000")
            self.end_headers()
            release.wait(30)  # The final body never arrives during an attempt.

        def log_message(self, *arguments):
            pass

    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    root = f"http://127.0.0.1:{server.server_port}"
    python_transport._REQUEST_TIMEOUT = args.timeout
    results = []
    try:
        for route in ("/body", "/redirect", "/chain", "/interim", "/terminal302",
                      "/missing", "/partial", "/stale-redirect", "/headers", "/loop",
                      "/redirect-body"):
            iri = root + route
            run = subprocess.run(["Rscript", "-e", R_PROBE, str(source), iri, str(args.timeout)],
                                 capture_output=True, text=True, timeout=args.timeout + 5)
            assert run.returncode == 0, run.stderr
            r_result = json.loads(run.stdout)
            started = time.monotonic()
            try:
                python_result = python_transport._request(iri)
            except Exception as error:
                python_result = {"error": str(error)}
            python_result["elapsed"] = round(time.monotonic() - started, 3)
            if route in ("/body", "/redirect", "/chain", "/redirect-body"):
                assert r_result["status"] == python_result["status"] == 200
                target = root + ("/body" if route != "/body" else route)
                assert r_result["final_url"] == python_result["final_url"] == target
            elif route == "/interim":
                assert r_result["status"] == python_result["status"] == 200
                assert r_result["final_url"] == python_result["final_url"] == iri
            elif route in ("/terminal302", "/missing"):
                assert r_result["status"] == python_result["status"] == (
                    302 if route == "/terminal302" else 404)
            else:
                assert "error" in r_result and "error" in python_result
            assert r_result["elapsed"] < args.timeout + 1
            assert python_result["elapsed"] < args.timeout + 1
            results.append({"route": route, "R": r_result, "Python": python_result})
        retry_results = []
        for iri, expected, limit in [
            ("http://selected.invalid:connection/term", 1, args.timeout),
            # 31 actual R redirect polls may exceed the header probe's 0.8s.
            # Let the redirect fault occur before the deadline so this proves
            # its class, rather than correctly retrying a genuine timeout.
            (root + "/loop", 1, max(3.0, args.timeout)),
            (root + "/headers", 3, args.timeout)]:
            python_transport._REQUEST_TIMEOUT = limit
            result = report_attempts(args.r_repo, iri, limit)
            assert result["R"]["attempts"] == result["Python"]["attempts"] == expected, (iri, expected, result)
            retry_results.append({"iri": iri, "deadline_seconds": limit,
                                  "expected_attempts": expected, **result})
    finally:
        release.set()
        server.shutdown()
        server.server_close()
        thread.join(timeout=2)
    interim = next(row for row in results if row["route"] == "/interim")
    report = {"python": platform.python_version(), "httpx": httpx.__version__,
              "httpcore": httpcore.__version__,
              "deadline_seconds": args.timeout,
              "interim_103_matches_final": interim["R"]["status"] == interim["Python"]["status"] == 200,
              "results": results, "retry_results": retry_results}
    rendered = json.dumps(report, ensure_ascii=False, indent=2)
    if args.output:
        args.output.write_text(rendered + "\n")
    print(rendered)


if __name__ == "__main__":
    main()
