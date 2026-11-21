#!/usr/bin/env bash
# Create the kind cluster and deploy the service-discovery exercise:
# a two-replica Python backend, a ClusterIP Service, a headless
# Service, a NodePort Service (host port 30080) and a netshoot debug
# pod for DNS and curl checks.
set -euo pipefail

CLUSTER=discovery-lab
NS=discovery-lab
DIR="$(cd "$(dirname "$0")/.." && pwd)"

if ! kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
  kind create cluster --name "$CLUSTER" --config "$DIR/manifests/kind-config.yaml"
else
  echo "Cluster $CLUSTER already exists, reusing it."
fi

kubectl apply -f "$DIR/manifests/00-namespace.yaml"
kubectl apply -f "$DIR/manifests/01-backend-configmap.yaml"
kubectl apply -f "$DIR/manifests/02-backend-deployment.yaml"
kubectl apply -f "$DIR/manifests/03-backend-service.yaml"
kubectl apply -f "$DIR/manifests/04-headless-service.yaml"
kubectl apply -f "$DIR/manifests/05-nodeport-service.yaml"
kubectl apply -f "$DIR/manifests/06-debug-pod.yaml"

echo "Waiting for the backend to be ready..."
kubectl rollout status deployment/backend -n "$NS" --timeout=240s
echo "Waiting for the debug pod to be ready..."
kubectl rollout status deployment/debug -n "$NS" --timeout=180s

echo
kubectl get svc -n "$NS"
kubectl get endpoints -n "$NS"
echo
echo "Try it from inside the cluster with:"
echo "  kubectl exec -n $NS deploy/debug -- nslookup backend"
echo "  kubectl exec -n $NS deploy/debug -- sh -c 'for i in 1 2 3 4; do curl -s http://backend:8080/; done'"
echo "And from your laptop with:"
echo "  curl http://localhost:30080/"
