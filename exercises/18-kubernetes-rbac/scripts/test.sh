#!/usr/bin/env bash
# Check what each ServiceAccount in the rbac-lab namespace can do.
# Uses kubectl auth can-i with --as impersonation, so no real tokens
# are needed. Prints PASS/FAIL per check and exits non-zero on mismatch.
set -uo pipefail

NS=rbac-lab
FAILURES=0

check() {
  local identity="$1" verb="$2" resource="$3" expected="$4"
  local actual
  actual=$(kubectl auth can-i "$verb" "$resource" -n "$NS" \
    --as="system:serviceaccount:$NS:$identity" 2>/dev/null || echo "error")
  if [[ "$actual" == "$expected" ]]; then
    printf 'PASS  %-9s %-6s %-12s -> %s\n' "$identity" "$verb" "$resource" "$actual"
  else
    printf 'FAIL  %-9s %-6s %-12s -> got %s, expected %s\n' \
      "$identity" "$verb" "$resource" "$actual" "$expected"
    FAILURES=$((FAILURES + 1))
  fi
}

echo "=== deployer (should deploy, not read secrets or delete pods) ==="
check deployer create deployments     yes
check deployer update deployments     yes
check deployer get    pods            yes
check deployer list   pods            yes
check deployer delete pods            no
check deployer get    secrets         no
check deployer create configmaps      no

echo
echo "=== reader (read-only) ==="
check reader get    pods              yes
check reader list   deployments       yes
check reader get    configmaps        yes
check reader create deployments       no
check reader delete pods              no
check reader get    secrets           no

echo
echo "=== intruder (no bindings at all) ==="
check intruder list pods              no
check intruder get  deployments       no
check intruder get  secrets           no

echo
if [[ "$FAILURES" -eq 0 ]]; then
  echo "All checks passed. Least privilege is working as designed."
else
  echo "$FAILURES check(s) failed. Compare the Roles in manifests/02-roles.yaml"
  echo "with the bindings in manifests/03-rolebindings.yaml."
  exit 1
fi
