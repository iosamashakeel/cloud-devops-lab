#!/usr/bin/env bash
# Create a kind cluster without the default CNI and install Calico,
# so Network Policies are actually enforced.
set -euo pipefail

CLUSTER=netpol-lab

if kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
  echo "Cluster '$CLUSTER' already exists, skipping creation."
else
  kind create cluster --name "$CLUSTER" --config kind-config.yaml
fi

echo "Installing Calico..."
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/calico.yaml

echo "Waiting for Calico to be ready (this can take a few minutes)..."
kubectl wait --for=condition=ready pod -l k8s-app=calico-node -n kube-system --timeout=300s

echo "Cluster '$CLUSTER' is ready with Calico enforcing Network Policies."
