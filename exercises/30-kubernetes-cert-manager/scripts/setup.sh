#!/usr/bin/env bash
# Install cert-manager, ingress-nginx and the lab issuers.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFESTS="$SCRIPT_DIR/../manifests"
CERT_MANAGER_VERSION="v1.16.2"

echo "==> Installing cert-manager $CERT_MANAGER_VERSION ..."
kubectl apply -f "https://github.com/cert-manager/cert-manager/releases/download/$CERT_MANAGER_VERSION/cert-manager.yaml"

echo "==> Waiting for cert-manager to become ready ..."
kubectl wait --namespace cert-manager \
  --for=condition=available deployment/cert-manager \
  --timeout=300s
kubectl wait --namespace cert-manager \
  --for=condition=available deployment/cert-manager-webhook \
  --timeout=300s
kubectl wait --namespace cert-manager \
  --for=condition=available deployment/cert-manager-cainjector \
  --timeout=300s

echo "==> Installing ingress-nginx ..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.2/deploy/static/provider/kind/deploy.yaml
kubectl wait --namespace ingress-nginx \
  --for=condition=available deployment/ingress-nginx-controller \
  --timeout=300s

echo "==> Applying lab namespace and issuers ..."
kubectl apply -f "$MANIFESTS/00-namespace.yaml"
kubectl apply -f "$MANIFESTS/01-selfsigned-issuer.yaml"
kubectl apply -f "$MANIFESTS/02-ca-issuer.yaml"
kubectl apply -f "$MANIFESTS/05-web-deployment.yaml"

echo "==> Waiting for the lab CA certificate to become Ready ..."
kubectl wait --namespace lab-certs \
  --for=condition=Ready certificate/lab-ca \
  --timeout=120s

echo "==> Done. Issuers:"
kubectl get clusterissuers
kubectl get certificate -n lab-certs
