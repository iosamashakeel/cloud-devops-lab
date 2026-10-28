#!/usr/bin/env bash
# Run the Exercise 12 scans locally. Missing tools are skipped with a
# note instead of failing, so you can run the parts you have installed.
# Usage: ./scripts/scan-local.sh  (run from the exercise root)
set -u
cd "$(dirname "$0")/.."

if command -v docker >/dev/null 2>&1; then
  echo "==> Building image..."
  docker build -t scan-demo:1.0 app/
else
  echo "==> docker not found, skipping image build"
fi

if command -v trivy >/dev/null 2>&1; then
  echo "==> Trivy image scan (HIGH/CRITICAL fail the build)..."
  trivy image --severity HIGH,CRITICAL --exit-code 1 scan-demo:1.0
else
  echo "==> trivy not found, skipping image scan (see README for install steps)"
fi

if command -v checkov >/dev/null 2>&1; then
  echo "==> Checkov Terraform scan..."
  checkov -d terraform/ --framework terraform
elif command -v tfsec >/dev/null 2>&1; then
  echo "==> tfsec Terraform scan..."
  tfsec terraform/
else
  echo "==> neither checkov nor tfsec found, skipping IaC scan"
fi

echo "==> Done."
