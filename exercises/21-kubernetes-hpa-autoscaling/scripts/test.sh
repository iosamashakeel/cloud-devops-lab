#!/usr/bin/env bash
# Sanity checks for this exercise: HPA exists, has a target, and the app is up.
set -euo pipefail

NAMESPACE=hpa-lab
fail=0

check() {
  if eval "$2"; then
    echo "PASS: $1"
  else
    echo "FAIL: $1"
    fail=1
  fi
}

check "namespace $NAMESPACE exists" \
  "kubectl get namespace $NAMESPACE >/dev/null 2>&1"

check "php-apache deployment has 1+ ready replica" \
  "kubectl get deployment php-apache -n $NAMESPACE -o jsonpath='{.status.readyReplicas}' | grep -q '[1-9]'"

check "HPA php-apache exists" \
  "kubectl get hpa php-apache -n $NAMESPACE >/dev/null 2>&1"

check "HPA minReplicas is 1 and maxReplicas is 10" \
  "kubectl get hpa php-apache -n $NAMESPACE -o jsonpath='{.spec.minReplicas} {.spec.maxReplicas}' | grep -qx '1 10'"

check "HPA targets 50% CPU utilisation" \
  "kubectl get hpa php-apache -n $NAMESPACE -o jsonpath='{.spec.metrics[0].resource.target.averageUtilization}' | grep -qx '50'"

check "deployment sets a CPU request (HPA needs it)" \
  "kubectl get deployment php-apache -n $NAMESPACE -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' | grep -q ."

check "metrics-server reports node metrics" \
  "kubectl top nodes >/dev/null 2>&1"

if [ "$fail" -eq 0 ]; then
  echo "All checks passed."
else
  echo "Some checks failed — see above."
  exit 1
fi
