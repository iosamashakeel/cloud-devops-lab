"""Tiny HTTP server used only as a scan target for Exercise 12.

Run: python3 app.py, then open http://localhost:8000 in a browser.
No third-party dependencies, so Trivy reports OS packages only.
"""

from http.server import BaseHTTPRequestHandler, HTTPServer


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):  # noqa: N802 - stdlib method name
        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.end_headers()
        self.wfile.write(b"scan-demo is running\n")

    def log_message(self, *args):  # keep the exercise output clean
        pass


if __name__ == "__main__":
    HTTPServer(("0.0.0.0", 8000), Handler).serve_forever()
