#!/usr/bin/env bash
# Verify the StatefulSet: stable pod names, one PVC per pod, per-pod data,
# and data that survives a pod being deleted and recreated.
set -uo pipefail

NS=stateful-lab
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

echo "=== Pods ==="
PODS=$(kubectl -n "$NS" get pods -l app=web --no-headers 2>/dev/null | wc -l)
check "3 web pods are running" "3" "$PODS"
for pod in web-0 web-1 web-2; do
  PHASE=$(kubectl -n "$NS" get pod "$pod" -o jsonpath='{.status.phase}' 2>/dev/null || echo "missing")
  check "pod $pod is Running" "Running" "$PHASE"
done

echo
echo "=== PersistentVolumeClaims ==="
for pod in web-0 web-1 web-2; do
  PVC_PHASE=$(kubectl -n "$NS" get pvc "data-$pod" -o jsonpath='{.status.phase}' 2>/dev/null || echo "missing")
  check "PVC data-$pod is Bound" "Bound" "$PVC_PHASE"
done

echo
echo "=== Per-pod data ==="
for pod in web-0 web-1 web-2; do
  PAGE=$(kubectl -n "$NS" exec "$pod" -- cat /usr/share/nginx/html/index.html 2>/dev/null || echo "unreachable")
  check "pod $pod serves a page with its own name" "Hello from $pod" "$PAGE"
done

echo
echo "=== Data survives a pod restart ==="
BEFORE=$(kubectl -n "$NS" exec web-1 -- cat /data/counter.txt 2>/dev/null || echo "unreachable")
check "counter on web-1 starts at 1" "1" "$BEFORE"

kubectl -n "$NS" delete pod web-1 >/dev/null
kubectl -n "$NS" wait --for=condition=ready pod/web-1 --timeout=120s >/dev/null

AFTER=$(kubectl -n "$NS" exec web-1 -- cat /data/counter.txt 2>/dev/null || echo "unreachable")
check "counter on web-1 is 2 after restart (same volume came back)" "2" "$AFTER"

echo
if [[ "$FAILURES" -eq 0 ]]; then
  echo "All checks passed. StatefulSets, PVCs and stable identities are working."
else
  echo "$FAILURES check(s) failed."
  echo "Inspect the pods: kubectl -n $NS get pods,pvc,sts"
  exit 1
fi
