#!/usr/bin/env bash
# Create the kind cluster and deploy the resource-management exercise:
# LimitRange, ResourceQuota, Guaranteed + Burstable deployments, a
# memory-hog pod and a pod with no resource settings.
set -euo pipefail

CLUSTER=resources-lab
NS=resources-lab
DIR="$(cd "$(dirname "$0")/.." && pwd)"

if ! kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
  kind create cluster --name "$CLUSTER"
else
  echo "Cluster $CLUSTER already exists, reusing it."
fi

kubectl apply -f "$DIR/manifests/00-namespace.yaml"
kubectl apply -f "$DIR/manifests/01-limitrange.yaml"
kubectl apply -f "$DIR/manifests/02-resourcequota.yaml"
kubectl apply -f "$DIR/manifests/03-deployment.yaml"
kubectl apply -f "$DIR/manifests/04-burstable-deployment.yaml"
kubectl apply -f "$DIR/manifests/05-memory-hog.yaml"
kubectl apply -f "$DIR/manifests/06-no-resources-pod.yaml"

echo "Waiting for the web deployment to be ready..."
kubectl rollout status deployment/web -n "$NS" --timeout=180s
echo "Waiting for the worker deployment to be ready..."
kubectl rollout status deployment/worker -n "$NS" --timeout=180s

echo "Waiting for the memory-hog pod to be OOMKilled..."
kubectl wait --for=jsonpath='{.status.phase}'=Failed \
  pod/memory-hog -n "$NS" --timeout=180s || true

echo
kubectl get pods -n "$NS" -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,QOS:.status.qosClass
kubectl describe resourcequota -n "$NS"
echo
echo "Watch the hog die with:"
echo "  kubectl logs -n $NS memory-hog"
