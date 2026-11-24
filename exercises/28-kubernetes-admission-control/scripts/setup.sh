#!/usr/bin/env bash
# Install Kyverno and the admission policies for Exercise 28.
# Kyverno runs as a validating admission webhook, so the script
# waits for it to be ready before applying any policy.
set -euo pipefail

KYVERNO_VERSION=v1.13.2
NS=lab-admission

kubectl apply -f manifests/00-namespace.yaml

echo "Installing Kyverno $KYVERNO_VERSION..."
kubectl apply -f "https://github.com/kyverno/kyverno/releases/download/${KYVERNO_VERSION}/install.yaml"

echo "Waiting for Kyverno to become ready..."
kubectl wait --for=condition=available deployment/kyverno-admission-controller \
  -n kyverno --timeout=300s
kubectl wait --for=condition=available deployment/kyverno-background-controller \
  -n kyverno --timeout=300s

echo "Applying admission policies..."
kubectl apply -f manifests/01-require-labels-policy.yaml
kubectl apply -f manifests/02-block-latest-tag-policy.yaml
kubectl apply -f manifests/03-require-resource-limits-policy.yaml
kubectl apply -f manifests/04-require-non-root-policy.yaml

echo "Applying the good example Deployment (this one must pass)..."
kubectl apply -f manifests/05-good-deployment.yaml

kubectl wait --for=condition=available deployment/good-app \
  -n "$NS" --timeout=120s

echo
echo "Kyverno is enforcing 4 policies in $NS."
echo "Try the bad one and watch it get rejected:"
echo "  kubectl apply -f manifests/06-bad-deployment.yaml"
echo "See what is already non-compliant:"
echo "  kubectl get policyreport -A"
