"""Manual B-130 paired localhost transport proof; no external HTTP/model call.

Run with the selected Python checkout installed and R curl/jsonlite installed:
  uv run --no-project --with-editable /path/to/metasalmonpy python probe.py \
    --r-repo /path/to/metasalmon --python-repo /path/to/metasalmonpy

This fixture is separate from R's injected CI tests. It records the real
Requests 103 compatibility gap without suppressing or weakening a test.
Retires as a separate probe when both CI jobs can run the paired default
transport fixture with their normal supported dependencies.
"""

import argparse
import json
import platform
import subprocess
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

import requests
from metasalmonpy import semantic_iri_verification as python_transport

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
                assert r_result["status"] == 200
                assert python_result["status"] in (103, 200)
            elif route in ("/terminal302", "/missing"):
                assert r_result["status"] == python_result["status"] == (
                    302 if route == "/terminal302" else 404)
            else:
                assert "error" in r_result and "error" in python_result
            assert r_result["elapsed"] < args.timeout + 1
            assert python_result["elapsed"] < args.timeout + 1
            results.append({"route": route, "R": r_result, "Python": python_result})
    finally:
        release.set()
        server.shutdown()
        server.server_close()
        thread.join(timeout=2)
    interim = next(row for row in results if row["route"] == "/interim")
    report = {"python": platform.python_version(), "requests": requests.__version__,
              "deadline_seconds": args.timeout,
              "unresolved_103_gap": interim["Python"]["status"] == 103,
              "results": results}
    rendered = json.dumps(report, ensure_ascii=False, indent=2)
    if args.output:
        args.output.write_text(rendered + "\n")
    print(rendered)


if __name__ == "__main__":
    main()
