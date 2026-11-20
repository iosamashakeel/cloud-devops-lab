#!/usr/bin/env bash
# Create the kind cluster and deploy the pod-security exercise: two
# namespaces (restricted + baseline), an insecure pod that the admission
# controller rejects, its trimmed version that baseline accepts, a
# hardened pod and a hardened nginx deployment.
set -euo pipefail

CLUSTER=security-lab
NS=security-lab
BASELINE_NS=security-lab-baseline
DIR="$(cd "$(dirname "$0")/.." && pwd)"

if ! kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
  kind create cluster --name "$CLUSTER"
else
  echo "Cluster $CLUSTER already exists, reusing it."
fi

kubectl apply -f "$DIR/manifests/00-namespace.yaml"

echo
echo "Trying to apply the insecure pod to the restricted namespace..."
echo "(This is expected to fail — read the admission error.)"
if kubectl apply -f "$DIR/manifests/01-insecure-pod.yaml" 2>&1; then
  echo "WARNING: the insecure pod was accepted, the policy is not enforcing."
else
  echo "Rejected as expected."
fi

kubectl apply -f "$DIR/manifests/02-insecure-pod-baseline.yaml"
kubectl apply -f "$DIR/manifests/03-secure-pod.yaml"
kubectl apply -f "$DIR/manifests/04-secure-deployment.yaml"

echo "Waiting for the secure pod to be ready..."
kubectl wait --for=condition=Ready pod/secure -n "$NS" --timeout=180s
echo "Waiting for the secure-web deployment to be ready..."
kubectl rollout status deployment/secure-web -n "$NS" --timeout=180s

echo
kubectl get pods -n "$NS" -o wide
kubectl get pods -n "$BASELINE_NS" -o wide
echo
echo "Try writing to the read-only filesystem with:"
echo "  kubectl exec -n $NS deploy/secure-web -- touch /etc/passwd"
echo "And check who nginx runs as with:"
echo "  kubectl exec -n $NS deploy/secure-web -- id"
