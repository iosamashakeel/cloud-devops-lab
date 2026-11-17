#!/usr/bin/env bash
# Create the kind cluster and install metrics-server (required by the HPA).
set -euo pipefail

CLUSTER=hpa-lab

if ! kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
  kind create cluster --name "$CLUSTER" --config "$(dirname "$0")/kind-config.yaml"
else
  echo "Cluster $CLUSTER already exists, reusing it."
fi

# metrics-server: kind nodes use self-signed kubelet certs, so the
# --kubelet-insecure-tls flag is required in local clusters.
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

kubectl patch deployment metrics-server -n kube-system --type=json \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'

echo "Waiting for the metrics API to become available..."
for i in $(seq 1 30); do
  if kubectl top nodes >/dev/null 2>&1; then
    echo "metrics-server is ready."
    kubectl top nodes
    exit 0
  fi
  sleep 10
done

echo "ERROR: metrics-server did not become ready in time." >&2
kubectl get pods -n kube-system -l k8s-app=metrics-server
exit 1
