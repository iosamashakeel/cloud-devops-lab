#!/usr/bin/env bash
# Deploy the five deliberately broken workloads for Exercise 26.
# Each one fails in exactly one way — diagnose before you fix.
set -euo pipefail

NS=lab-troubleshooting

kubectl apply -f manifests/00-namespace.yaml
kubectl apply -f manifests/01-crashloop-pod.yaml
kubectl apply -f manifests/02-bad-image-deployment.yaml
kubectl apply -f manifests/03-pending-pod.yaml
kubectl apply -f manifests/04-broken-probe-deployment.yaml
kubectl apply -f manifests/05-service-no-endpoints.yaml

echo "Waiting a few seconds for the failures to show up..."
sleep 10

kubectl get pods -n "$NS"
echo
echo "Five broken workloads deployed. Start with:"
echo "  kubectl describe pod crashloop -n $NS"
echo "  kubectl logs crashloop -n $NS --previous"
