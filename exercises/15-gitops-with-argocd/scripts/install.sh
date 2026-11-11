#!/usr/bin/env bash
# Install Argo CD on a local kind cluster for the GitOps lab.
set -euo pipefail

CLUSTER_NAME="gitops-lab"
ARGOCD_VERSION="v2.12.3"

if ! kind get clusters | grep -qx "$CLUSTER_NAME"; then
  echo "Creating kind cluster '$CLUSTER_NAME'..."
  kind create cluster --name "$CLUSTER_NAME"
else
  echo "Cluster '$CLUSTER_NAME' already exists, reusing it."
fi

echo "Installing Argo CD $ARGOCD_VERSION..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f "https://raw.githubusercontent.com/argoproj/argo-cd/$ARGOCD_VERSION/manifests/install.yaml"

echo "Waiting for Argo CD to become ready (this takes a few minutes)..."
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s

echo
echo "Argo CD is ready."
echo "Admin password:"
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
echo
echo "Open the UI with:"
echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "Then visit https://localhost:8080 (admin / password above)."
