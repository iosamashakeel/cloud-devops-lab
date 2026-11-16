#!/usr/bin/env bash
# Create the kind cluster and deploy the StatefulSet lab.
set -euo pipefail

CLUSTER=stateful-lab
NS=stateful-lab
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
  echo "Cluster '$CLUSTER' already exists, reusing it."
else
  echo "Creating kind cluster '$CLUSTER'..."
  kind create cluster --name "$CLUSTER"
fi

echo "Applying the manifests..."
kubectl apply -f "$SCRIPT_DIR/../manifests/"

echo "Waiting for the StatefulSet pods to be ready..."
kubectl -n "$NS" rollout status statefulset/web --timeout=180s

echo
echo "Lab is ready. Run ./scripts/test.sh to verify it."
