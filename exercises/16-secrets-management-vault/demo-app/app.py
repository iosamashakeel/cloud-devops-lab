"""Demo app: fetch a secret from Vault at startup, keep it in memory only.

Reads VAULT_ADDR and VAULT_TOKEN from the environment, asks Vault for
secret/demo-app, then serves the masked values over HTTP. No secret is ever
written to disk or baked into the image.
"""

import json
import os
import urllib.request
import urllib.error
from http.server import BaseHTTPRequestHandler, HTTPServer

VAULT_ADDR = os.environ.get("VAULT_ADDR", "http://localhost:8200")
VAULT_TOKEN = os.environ.get("VAULT_TOKEN", "root")
SECRET_PATH = "secret/data/demo-app"


def fetch_secret():
    req = urllib.request.Request(
        f"{VAULT_ADDR}/v1/{SECRET_PATH}",
        headers={"X-Vault-Token": VAULT_TOKEN},
    )
    try:
        with urllib.request.urlopen(req, timeout=5) as resp:
            body = json.load(resp)
    except urllib.error.HTTPError as exc:
        raise SystemExit(f"Vault request failed: HTTP {exc.code} — check the token and path")
    except urllib.error.URLError as exc:
        raise SystemExit(f"Cannot reach Vault at {VAULT_ADDR}: {exc.reason}")
    return body["data"]["data"]


def mask(value, visible=2):
    if not value:
        return ""
    return value[:visible] + "*" * max(len(value) - visible, 0)


SECRET = fetch_secret()
print("Secret loaded from Vault (values masked in logs).", flush=True)


class Handler(BaseHTTPRequestHandler):
    def _send(self, payload, status=200):
        body = json.dumps(payload).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path == "/":
            self._send({
                "app": "vault-demo-app",
                "db_password_masked": mask(SECRET.get("db_password", "")),
                "api_key_masked": mask(SECRET.get("api_key", "")),
                "source": "HashiCorp Vault",
            })
        elif self.path == "/health":
            self._send({"status": "ok", "secret_loaded": bool(SECRET)})
        else:
            self._send({"error": "not found"}, status=404)

    def log_message(self, *args):
        pass


if __name__ == "__main__":
    HTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
