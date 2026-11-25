#!/usr/bin/env bash
# Install Linkerd and the versioned web app for Exercise 29.
# Linkerd adds a proxy sidecar to every pod in the lab-mesh
# namespace, so all traffic between pods is encrypted with mTLS
# and visible in the dashboard — without changing the app.
set -euo pipefail

LINKERD_VERSION=stable-2.14.4
NS=lab-mesh
CLUSTER=lab-mesh

# 1. Cluster (skip if it already exists).
if ! kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
  echo "Creating kind cluster $CLUSTER..."
  kind create cluster --config manifests/kind-config.yaml
fi

# 2. Build the app image and load it into kind.
echo "Building lab-web:1.0..."
docker build -t lab-web:1.0 app/
kind load docker-image lab-web:1.0 --name "$CLUSTER"

# 3. Linkerd CLI (install it if it is not already there).
if ! command -v linkerd >/dev/null 2>&1; then
  echo "Installing linkerd CLI $LINKERD_VERSION..."
  curl --proto '=https' --tlsv1.2 -sSfL \
    "https://run.linkerd.io/install?install-version=${LINKERD_VERSION}" | sh
  export PATH="$HOME/.linkerd2/bin:$PATH"
fi
linkerd version --client

# 4. Pre-flight checks, then the control plane.
linkerd check --pre
echo "Installing Linkerd control plane..."
linkerd install --crds | kubectl apply -f -
linkerd install | kubectl apply -f -
kubectl wait --for=condition=available deployment/linkerd-destination \
  -n linkerd --timeout=300s
kubectl wait --for=condition=available deployment/linkerd-identity \
  -n linkerd --timeout=300s
kubectl wait --for=condition=available deployment/linkerd-proxy-injector \
  -n linkerd --timeout=300s

# 5. The viz extension (dashboard, tap, metrics).
echo "Installing linkerd-viz..."
linkerd viz install | kubectl apply -f -
kubectl wait --for=condition=available deployment/web \
  -n linkerd-viz --timeout=300s

# 6. The app. The namespace annotation makes the injector add a
# proxy to every pod, so apply the namespace first.
kubectl apply -f manifests/00-namespace.yaml
kubectl apply -f manifests/01-web-v1.yaml
kubectl apply -f manifests/02-web-v2.yaml
kubectl apply -f manifests/03-service.yaml
kubectl apply -f manifests/04-service-profile.yaml
kubectl apply -f manifests/05-traffic-split.yaml

kubectl wait --for=condition=available deployment/web-v1 \
  -n "$NS" --timeout=180s
kubectl wait --for=condition=available deployment/web-v2 \
  -n "$NS" --timeout=180s

echo
echo "Linkerd is running and the web app is meshed."
echo "Check the proxies:   linkerd check --proxy -n $NS"
echo "Watch live traffic:  linkerd viz tap deploy/web-v1 -n $NS"
echo "Golden metrics:      linkerd viz stat deploy -n $NS"
echo "Open the dashboard:  linkerd viz dashboard"
echo "Try the canary:      kubectl run curl --rm -i --image=curlimages/curl --restart=Never -- \\"
echo "                       sh -c 'for i in \$(seq 1 30); do curl -s http://web.$NS/; echo; done'"
