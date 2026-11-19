#!/usr/bin/env bash
# Verify the LimitRange and quota exist, both deployments are ready, the
# QoS classes are correct, the memory hog was OOMKilled, and the
# no-resources pod got its defaults injected by the LimitRange.
set -euo pipefail

NS=resources-lab
FAIL=0

check() {
  if [ "$1" = "0" ]; then
    echo "PASS: $2"
  else
    echo "FAIL: $2"
    FAIL=1
  fi
}

qos_of() {
  kubectl get pod "$1" -n "$NS" -o jsonpath='{.status.qosClass}' 2>/dev/null
}

# 1. LimitRange exists with the expected default memory limit.
DEFAULT_LIMIT=$(kubectl get limitrange defaults -n "$NS" \
  -o jsonpath='{.spec.limits[0].default.memory}' 2>/dev/null)
[ "$DEFAULT_LIMIT" = "256Mi" ]
check "$?" "LimitRange default memory limit is 256Mi (got '${DEFAULT_LIMIT:-none}')"

# 2. ResourceQuota exists with the expected request cap.
QUOTA_CPU=$(kubectl get resourcequota team-quota -n "$NS" \
  -o jsonpath='{.spec.hard.requests\.cpu}' 2>/dev/null)
[ "$QUOTA_CPU" = "2" ]
check "$?" "ResourceQuota caps requests.cpu at 2 (got '${QUOTA_CPU:-none}')"

# 3. Both deployments are ready.
kubectl rollout status deployment/web -n "$NS" --timeout=120s >/dev/null 2>&1
check "$?" "web deployment ready"

kubectl rollout status deployment/worker -n "$NS" --timeout=120s >/dev/null 2>&1
check "$?" "worker deployment ready"

# 4. Web pods are Guaranteed QoS.
WEB_POD=$(kubectl get pods -n "$NS" -l app=web \
  -o jsonpath='{.items[0].metadata.name}')
[ "$(qos_of "$WEB_POD")" = "Guaranteed" ]
check "$?" "web pod is Guaranteed QoS (got '$(qos_of "$WEB_POD")')"

# 5. Worker pods are Burstable QoS.
WORKER_POD=$(kubectl get pods -n "$NS" -l app=worker \
  -o jsonpath='{.items[0].metadata.name}')
[ "$(qos_of "$WORKER_POD")" = "Burstable" ]
check "$?" "worker pod is Burstable QoS (got '$(qos_of "$WORKER_POD")')"

# 6. The memory hog was OOMKilled.
kubectl wait --for=jsonpath='{.status.phase}'=Failed \
  pod/memory-hog -n "$NS" --timeout=180s >/dev/null 2>&1
REASON=$(kubectl get pod memory-hog -n "$NS" \
  -o jsonpath='{.status.containerStatuses[0].state.terminated.reason}' 2>/dev/null)
[ "$REASON" = "OOMKilled" ]
check "$?" "memory-hog terminated with OOMKilled (got '${REASON:-none}')"

# 7. The no-resources pod got LimitRange defaults injected.
INJECTED=$(kubectl get pod no-resources -n "$NS" \
  -o jsonpath='{.spec.containers[0].resources.limits.memory}' 2>/dev/null)
[ "$INJECTED" = "256Mi" ]
check "$?" "no-resources pod got default memory limit 256Mi (got '${INJECTED:-none}')"

if [ "$FAIL" = "0" ]; then
  echo "All checks passed."
else
  echo "Some checks failed." >&2
  exit 1
fi
