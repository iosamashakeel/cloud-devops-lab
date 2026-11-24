#!/usr/bin/env bash
# Checks for Exercise 28 — run after ./scripts/setup.sh.
set -uo pipefail

NS=lab-admission
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

# 1. The admission webhook is up.
check "kyverno admission controller is available" \
  kubectl wait --for=condition=available deployment/kyverno-admission-controller -n kyverno --timeout=60s

# 2. The background controller is up (it writes policy reports).
check "kyverno background controller is available" \
  kubectl wait --for=condition=available deployment/kyverno-background-controller -n kyverno --timeout=60s

# 3. All four policies are installed.
for policy in require-labels block-latest-tag require-resource-limits require-non-root; do
  check "policy $policy exists" \
    kubectl get clusterpolicy "$policy"
done

# 4. The good Deployment was admitted and its pod is Running.
check "good-app pods are Running" \
  bash -c "kubectl get pods -n $NS -l app=good-app -o jsonpath='{.items[0].status.phase}' | grep -q Running"

# 5. The bad Deployment is rejected by the webhook.
check "bad-app deployment is rejected" \
  bash -c "! kubectl apply -f manifests/06-bad-deployment.yaml >/dev/null 2>&1"

# 6. ... and it does not exist in the cluster.
check "bad-app deployment does not exist" \
  bash -c "! kubectl get deployment bad-app -n $NS >/dev/null 2>&1"

# 7. The background controller wrote a PolicyReport for the namespace.
# Reports are generated asynchronously, so allow up to a minute.
REPORT_OK=0
for _ in $(seq 1 12); do
  if kubectl get policyreport -n "$NS" >/dev/null 2>&1; then
    REPORT_OK=1
    break
  fi
  sleep 5
done
if [ "$REPORT_OK" = 1 ]; then
  echo "PASS: policyreport exists for $NS"; PASS=$((PASS + 1))
else
  echo "FAIL: policyreport exists for $NS"; FAIL=$((FAIL + 1))
fi

echo
echo "$PASS passed, $FAIL failed"
exit "$FAIL"
