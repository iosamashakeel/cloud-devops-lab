#!/usr/bin/env bash
# Install the WebApp CRD and deploy the operator for Exercise 27.
# Builds the operator image locally and loads it into the kind
# cluster, so nothing is pulled from a registry.
set -euo pipefail

NS=lab-operators

docker build -t webapp-operator:dev operator/

if kind get clusters 2>/dev/null | grep -qx lab-operators; then
  kind load docker-image webapp-operator:dev --name lab-operators
fi

kubectl apply -f manifests/00-namespace.yaml
kubectl apply -f manifests/01-crd.yaml
kubectl apply -f manifests/02-operator-rbac.yaml
kubectl apply -f manifests/03-operator-deployment.yaml

echo "Waiting for the operator to become ready..."
kubectl wait --for=condition=available deployment/webapp-operator \
  -n "$NS" --timeout=120s

kubectl apply -f manifests/04-webapp-example.yaml

echo
echo "Operator is running. Watch it reconcile:"
echo "  kubectl logs -n $NS deployment/webapp-operator -f"
echo "  kubectl get webapps -n $NS"
