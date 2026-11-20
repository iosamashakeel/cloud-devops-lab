#!/usr/bin/env bash
# Verify the insecure pod is rejected in the restricted namespace, runs
# in the baseline namespace, and the secure pod + deployment run with
# the expected hardened securityContext.
set -euo pipefail

NS=security-lab
BASELINE_NS=security-lab-baseline
DIR="$(cd "$(dirname "$0")/.." && pwd)"
FAIL=0

check() {
  if [ "$1" = "0" ]; then
    echo "PASS: $2"
  else
    echo "FAIL: $2"
    FAIL=1
  fi
}

# 1. The insecure pod is rejected in the restricted namespace.
if kubectl apply -f "$DIR/manifests/01-insecure-pod.yaml" >/dev/null 2>&1; then
  check 1 "insecure pod rejected in restricted namespace (it was accepted!)"
  kubectl delete pod insecure -n "$NS" --ignore-not-found >/dev/null 2>&1 || true
else
  check 0 "insecure pod rejected in restricted namespace"
fi

# 2. The trimmed insecure pod runs in the baseline namespace.
kubectl wait --for=condition=Ready pod/insecure -n "$BASELINE_NS" --timeout=120s >/dev/null 2>&1
check "$?" "trimmed insecure pod running in baseline namespace"

# 3. The secure pod is running.
kubectl wait --for=condition=Ready pod/secure -n "$NS" --timeout=120s >/dev/null 2>&1
check "$?" "secure pod running"

# 4. Secure pod runs as non-root (uid 1000).
UID=$(kubectl get pod secure -n "$NS" \
  -o jsonpath='{.spec.securityContext.runAsUser}' 2>/dev/null)
[ "$UID" = "1000" ]
check "$?" "secure pod runAsUser is 1000 (got '${UID:-none}')"

# 5. Secure pod drops all capabilities and forbids privilege escalation.
CAPS=$(kubectl get pod secure -n "$NS" \
  -o jsonpath='{.spec.containers[0].securityContext.capabilities.drop[0]}' 2>/dev/null)
[ "$CAPS" = "ALL" ]
check "$?" "secure pod drops ALL capabilities (got '${CAPS:-none}')"

ESC=$(kubectl get pod secure -n "$NS" \
  -o jsonpath='{.spec.containers[0].securityContext.allowPrivilegeEscalation}' 2>/dev/null)
[ "$ESC" = "false" ]
check "$?" "secure pod allowPrivilegeEscalation is false (got '${ESC:-none}')"

# 6. Secure pod has a read-only root filesystem.
RO=$(kubectl get pod secure -n "$NS" \
  -o jsonpath='{.spec.containers[0].securityContext.readOnlyRootFilesystem}' 2>/dev/null)
[ "$RO" = "true" ]
check "$?" "secure pod readOnlyRootFilesystem is true (got '${RO:-none}')"

# 7. The secure-web deployment is ready and its containers are non-root.
kubectl rollout status deployment/secure-web -n "$NS" --timeout=120s >/dev/null 2>&1
check "$?" "secure-web deployment ready"

WEB_UID=$(kubectl get pod -n "$NS" -l app=secure-web \
  -o jsonpath='{.items[0].spec.securityContext.runAsUser}' 2>/dev/null)
[ "$WEB_UID" = "101" ]
check "$?" "secure-web runs as uid 101 (got '${WEB_UID:-none}')"

# 8. Writing to the read-only filesystem inside the deployment fails.
if kubectl exec -n "$NS" deploy/secure-web -- touch /etc/passwd 2>/dev/null; then
  check 1 "root filesystem is read-only (write succeeded!)"
else
  check 0 "root filesystem is read-only (write refused)"
fi

if [ "$FAIL" = "0" ]; then
  echo "All checks passed."
else
  echo "Some checks failed." >&2
  exit 1
fi
