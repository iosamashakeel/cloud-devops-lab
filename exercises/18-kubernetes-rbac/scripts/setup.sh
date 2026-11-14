#!/usr/bin/env bash
# Create the kind cluster and apply the RBAC lab manifests.
set -euo pipefail

CLUSTER=rbac-lab
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFESTS="$SCRIPT_DIR/../manifests"

if kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
  echo "Cluster '$CLUSTER' already exists, reusing it."
else
  echo "Creating kind cluster '$CLUSTER'..."
  kind create cluster --name "$CLUSTER"
fi

echo "Applying manifests..."
kubectl apply -f "$MANIFESTS/"

echo "Waiting for the demo deployment to be ready..."
kubectl -n rbac-lab rollout status deploy/web --timeout=120s

echo
echo "Lab is ready. Run ./scripts/test.sh to check the permissions."
