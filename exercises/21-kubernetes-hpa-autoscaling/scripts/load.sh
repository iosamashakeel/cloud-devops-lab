#!/usr/bin/env bash
# Generate CPU load against the demo app until interrupted (Ctrl+C).
# Uses a throwaway busybox pod so no extra tooling is needed.
set -euo pipefail

NAMESPACE=hpa-lab

kubectl run -n "$NAMESPACE" loadgen --rm -i --tty --image=busybox --restart=Never \
  -- sh -c 'while true; do wget -q -O- http://php-apache/ > /dev/null; done'

echo "Load stopped. The HPA will scale back down after its stabilisation window."
