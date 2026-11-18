#!/usr/bin/env bash
# Create the kind cluster and deploy the Job, parallel Job and CronJob.
set -euo pipefail

CLUSTER=jobs-lab
DIR="$(cd "$(dirname "$0")/.." && pwd)"

if ! kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
  kind create cluster --name "$CLUSTER"
else
  echo "Cluster $CLUSTER already exists, reusing it."
fi

kubectl apply -f "$DIR/manifests/00-namespace.yaml"
kubectl apply -f "$DIR/manifests/01-configmap.yaml"
kubectl apply -f "$DIR/manifests/02-job.yaml"
kubectl apply -f "$DIR/manifests/03-job-parallel.yaml"
kubectl apply -f "$DIR/manifests/04-cronjob.yaml"

echo "Waiting for the daily-report Job to complete..."
kubectl wait --for=condition=complete --timeout=180s \
  job/daily-report -n jobs-lab

echo "Waiting for the batch-processor Job to complete..."
kubectl wait --for=condition=complete --timeout=180s \
  job/batch-processor -n jobs-lab

echo
kubectl get jobs -n jobs-lab
kubectl get cronjobs -n jobs-lab
echo
echo "Jobs are done. Read the report with:"
echo "  kubectl logs -n jobs-lab job/daily-report"
