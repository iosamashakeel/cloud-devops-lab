#!/usr/bin/env bash
# Create the kind cluster, install the NGINX Ingress controller, create a
# self-signed TLS certificate for demo.local, and deploy the demo app.
set -euo pipefail

CLUSTER=ingress-lab
NS=ingress-lab
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CERT_DIR="$SCRIPT_DIR/../.certs"

if kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
  echo "Cluster '$CLUSTER' already exists, reusing it."
else
  echo "Creating kind cluster '$CLUSTER'..."
  kind create cluster --name "$CLUSTER" --config "$SCRIPT_DIR/kind-config.yaml"
fi

echo "Installing the NGINX Ingress controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.3/deploy/static/provider/kind/deploy.yaml

echo "Waiting for the Ingress controller to be ready..."
kubectl -n ingress-nginx wait --for=condition=ready pod \
  -l app.kubernetes.io/component=controller --timeout=180s

echo "Deploying the demo app..."
kubectl apply -f "$SCRIPT_DIR/../demo-app/"

echo "Waiting for the demo deployments to be ready..."
kubectl -n "$NS" rollout status deploy/web --timeout=120s
kubectl -n "$NS" rollout status deploy/api --timeout=120s

echo "Creating a self-signed TLS certificate for demo.local..."
mkdir -p "$CERT_DIR"
openssl req -x509 -newkey rsa:2048 -nodes -days 365 \
  -keyout "$CERT_DIR/tls.key" -out "$CERT_DIR/tls.crt" \
  -subj "/CN=demo.local" \
  -addext "subjectAltName=DNS:demo.local" 2>/dev/null

kubectl -n "$NS" create secret tls demo-tls \
  --cert="$CERT_DIR/tls.crt" --key="$CERT_DIR/tls.key" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Applying the Ingress..."
kubectl apply -f "$SCRIPT_DIR/../ingress/"

echo
echo "Lab is ready."
echo "Add '127.0.0.1 demo.local' to /etc/hosts, then run ./scripts/test.sh"
