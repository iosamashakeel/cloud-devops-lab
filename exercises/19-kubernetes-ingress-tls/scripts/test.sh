#!/usr/bin/env bash
# Verify the Ingress routes, the HTTP->HTTPS redirect, and TLS.
# Requires '127.0.0.1 demo.local' in /etc/hosts (see README).
set -uo pipefail

FAILURES=0

check() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$actual" == *"$expected"* ]]; then
    printf 'PASS  %s\n' "$label"
  else
    printf 'FAIL  %s (got: %s, expected to contain: %s)\n' "$label" "$actual" "$expected"
    FAILURES=$((FAILURES + 1))
  fi
}

echo "=== HTTP redirects to HTTPS ==="
REDIRECT=$(curl -s -o /dev/null -w "%{http_code} %{redirect_url}" http://demo.local/ || echo "unreachable")
check "http://demo.local/ returns 301 to https" "301 https://demo.local/" "$REDIRECT"

echo
echo "=== HTTPS routes ==="
WEB=$(curl -sk https://demo.local/ || echo "unreachable")
check "GET / returns the web page" "Hello from the web frontend" "$WEB"

API=$(curl -sk https://demo.local/api || echo "unreachable")
check "GET /api returns JSON from the api backend" '"service": "api"' "$API"

echo
echo "=== TLS ==="
TLS_ISSUER=$(echo | openssl s_client -connect demo.local:443 -servername demo.local 2>/dev/null \
  | openssl x509 -noout -issuer 2>/dev/null || echo "unreachable")
check "certificate is issued for demo.local" "CN = demo.local" "$TLS_ISSUER"

echo
echo "=== Unknown path ==="
NOTFOUND=$(curl -sk -o /dev/null -w "%{http_code}" https://demo.local/unknown || echo "unreachable")
check "GET /unknown returns 404 from the Ingress" "404" "$NOTFOUND"

echo
if [[ "$FAILURES" -eq 0 ]]; then
  echo "All checks passed. Ingress routing and TLS are working."
else
  echo "$FAILURES check(s) failed."
  echo "Check the controller logs: kubectl -n ingress-nginx logs deploy/ingress-nginx-controller"
  exit 1
fi
