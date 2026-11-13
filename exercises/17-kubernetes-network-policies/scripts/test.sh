#!/usr/bin/env bash
# Test whether the client and the intruder can reach the backend.
# Run before applying policies (both should succeed) and after
# (only the client should succeed).
set -uo pipefail

NS=netpol-lab

check() {
  local pod="$1" label="$2"
  if kubectl exec -n "$NS" "deploy/$pod" -- curl -s -m 5 "http://backend:5678" >/dev/null 2>&1; then
    echo "PASS: $pod ($label) can reach the backend"
  else
    echo "BLOCKED: $pod ($label) cannot reach the backend"
  fi
}

kubectl wait --for=condition=available deploy/client deploy/intruder -n "$NS" --timeout=120s >/dev/null

check client "app=frontend"
check intruder "app=intruder"
