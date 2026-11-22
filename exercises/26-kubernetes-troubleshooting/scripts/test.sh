#!/usr/bin/env bash
# Checks for Exercise 26 — run after you have diagnosed and fixed
# all five broken workloads.
set -uo pipefail

NS=lab-troubleshooting
PASS=0
FAIL=0

check() {
  local name="$1"; shift
  if "$@" >/dev/null 2>&1; then
    echo "PASS: $name"; PASS=$((PASS + 1))
  else
    echo "FAIL: $name"; FAIL=$((FAIL + 1))
  fi
}

# 1. The fixed deployment is up and ready (replaces the crashloop pod).
check "crashloop-fixed deployment is ready" \
  kubectl wait --for=condition=available deployment/crashloop-fixed -n "$NS" --timeout=60s

# 2. bad-image now runs a real nginx tag.
check "bad-image pod is Running" \
  bash -c "kubectl get pods -n $NS -l app=bad-image -o jsonpath='{.items[0].status.phase}' | grep -q Running"

# 3. hungry is scheduled (no longer Pending).
check "hungry pod is Running" \
  bash -c "kubectl get pods -n $NS -l app=hungry -o jsonpath='{.items[0].status.phase}' | grep -q Running"

# 4. sick is Ready (readiness probe passes).
check "sick pod is Ready" \
  bash -c "kubectl get pods -n $NS -l app=sick -o jsonpath='{.items[0].status.containerStatuses[0].ready}' | grep -q true"

# 5. orphan-svc has endpoints now.
check "orphan-svc has endpoints" \
  bash -c "test \"\$(kubectl get endpoints orphan-svc -n $NS -o jsonpath='{.subsets[0].addresses[*].ip}')\" != ''"

echo
echo "$PASS passed, $FAIL failed"
exit "$FAIL"
