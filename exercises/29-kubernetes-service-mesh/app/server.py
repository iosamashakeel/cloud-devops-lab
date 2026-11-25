#!/usr/bin/env python3
"""Tiny versioned web app for Exercise 29.

Runs on port 8080 and answers three endpoints:

  GET /          -> JSON with the app version, pod hostname and a greeting
  GET /health    -> 200 OK, used as the readiness/liveness probe
  GET /unstable  -> 500 about half the time, so the ServiceProfile's
                    failure classification has something to catch

The version comes from the APP_VERSION environment variable, so the
same image serves v1 and v2 — only the Deployment differs.
"""

import json
import os
import random
import socket
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

VERSION = os.environ.get("APP_VERSION", "v1")
HOSTNAME = socket.gethostname()


class Handler(BaseHTTPRequestHandler):
    def _json(self, status, payload):
        body = json.dumps(payload).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path == "/health":
            self._json(200, {"status": "ok", "version": VERSION})
        elif self.path == "/unstable":
            # Fails roughly half the time on purpose.
            if random.random() < 0.5:
                self._json(500, {"status": "error", "version": VERSION})
            else:
                self._json(200, {"status": "ok", "version": VERSION})
        elif self.path == "/":
            self._json(200, {
                "version": VERSION,
                "pod": HOSTNAME,
                "message": f"Hello from web {VERSION}",
            })
        else:
            self._json(404, {"status": "not found", "path": self.path})

    # Keep the logs readable: one line per request is enough.
    def log_message(self, fmt, *args):
        print(f"{self.client_address[0]} - {fmt % args}")


if __name__ == "__main__":
    server = ThreadingHTTPServer(("0.0.0.0", 8080), Handler)
    print(f"web {VERSION} listening on :8080 (pod {HOSTNAME})", flush=True)
    server.serve_forever()
