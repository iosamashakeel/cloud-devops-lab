#!/usr/bin/env bash
# Checks for Exercise 27 — run after ./scripts/setup.sh.
set -uo pipefail

NS=lab-operators
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

# 1. The operator itself is up.
check "operator deployment is available" \
  kubectl wait --for=condition=available deployment/webapp-operator -n "$NS" --timeout=60s

# 2. The CRD is registered.
check "WebApp CRD exists" \
  kubectl get crd webapps.example.lab

# 3. The operator created a Deployment for the example WebApp.
check "hello deployment exists with 2 replicas" \
  bash -c "test \"\$(kubectl get deployment hello -n $NS -o jsonpath='{.spec.replicas}')\" = '2'"

# 4. The hello pods are Running.
check "hello pods are Running" \
  bash -c "kubectl get pods -n $NS -l app=hello -o jsonpath='{.items[0].status.phase}' | grep -q Running"

# 5. The Service exists and selects the pods.
check "hello service has endpoints" \
  bash -c "test \"\$(kubectl get endpoints hello -n $NS -o jsonpath='{.subsets[0].addresses[*].ip}')\" != ''"

# 6. The ConfigMap carries the message from the WebApp spec.
check "configmap carries the message" \
  bash -c "kubectl get configmap hello -n $NS -o jsonpath='{.data.index\.html}' | grep -q 'Hello from the operator'"

# 7. The operator wrote the status back onto the WebApp.
check "webapp status reports ready replicas" \
  bash -c "test \"\$(kubectl get webapp hello -n $NS -o jsonpath='{.status.readyReplicas}')\" != ''"

echo
echo "$PASS passed, $FAIL failed"
exit "$FAIL"
