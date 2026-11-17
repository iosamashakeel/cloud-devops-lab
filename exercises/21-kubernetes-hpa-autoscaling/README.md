# Exercise 21 — Kubernetes Autoscaling with HPA

## What you will learn

- How the Horizontal Pod Autoscaler (HPA) decides when to add or remove replicas
- Installing metrics-server so the HPA has CPU and memory data to work with
- Writing an HPA that scales on CPU utilisation and on a custom metric
- Watching a scale-out happen live under load, and a scale-in afterwards
- Why resource `requests` are not optional: without them the HPA has nothing to compare against

## Prerequisites

- A local cluster: `kind` (used here) or minikube
- `kubectl` configured against the cluster
- `hey` or `kubectl run` for load generation (the load script uses only `kubectl` + busybox, so nothing extra is required)

## Why autoscaling matters

Fixed replica counts are a guess. Too few and a traffic spike takes the service
down; too many and you pay for idle pods all month. The HPA closes the loop:
metrics-server reports real CPU/memory usage, the HPA compares it with the
target you set, and the Deployment scales up or down inside the min/max bounds
you chose. This exercise makes that loop visible.

## Steps

### 1. Create the cluster

```bash
./scripts/setup.sh
```

This creates a kind cluster (`hpa-lab`), installs metrics-server with the
flags kind needs (`--kubelet-insecure-tls`, since kind nodes use self-signed
kubelet certificates), and waits until the metrics API answers.

### 2. Deploy the demo app

```bash
kubectl apply -f manifests/00-namespace.yaml
kubectl apply -f manifests/01-deployment.yaml
kubectl apply -f manifests/02-service.yaml
```

The deployment runs `php-apache`, the classic autoscaling demo image: it
serves a page and burns CPU on demand. It starts with 1 replica and sets
explicit CPU requests/limits — the HPA needs the request value to compute
utilisation (utilisation = usage / request).

### 3. Create the autoscaler

```bash
kubectl apply -f manifests/03-hpa.yaml
kubectl get hpa -n hpa-lab --watch
```

At first the `TARGETS` column shows `<unknown>/50%` until metrics-server
collects its first samples (about 30–60 seconds). Then it settles near the
current utilisation.

### 4. Generate load and watch it scale

```bash
./scripts/load.sh
```

In a second terminal:

```bash
kubectl get hpa -n hpa-lab --watch
kubectl get pods -n hpa-lab --watch
```

Load pushes CPU above the 50% target, the HPA raises the replica count
(up to 10), and new pods appear within a minute or two. The scale-up is
deliberately not instant: the HPA syncs every 15 seconds by default, and
new pods need time to start.

### 5. Stop the load and watch the scale-in

Stop `load.sh` (Ctrl+C). The HPA keeps the extra replicas for the default
5-minute stabilisation window before scaling back down — this avoids
flapping when load is bursty. Watch it return to 1 replica:

```bash
kubectl get hpa -n hpa-lab --watch
```

## Tasks

1. Change the CPU target in `manifests/03-hpa.yaml` from 50% to 80% and
   re-apply it. How does the replica count under the same load change?
2. Add a memory target (`averageUtilization: 70` under a memory metric)
   to the HPA. What happens when the pod is CPU-bound but not
   memory-bound — which metric drives the decision? (Answer: the HPA
   takes the *largest* replica count any metric asks for.)
3. Set `minReplicas: 2` and re-apply. Why would you run at least 2
   replicas in production even for a quiet service? (Availability during
   node drains and rolling updates.)
4. Inspect the scaling behaviour block in the HPA manifest. Change
   `scaleDown.stabilizationWindowSeconds` to 60 and observe the faster
   scale-in. When would a long stabilisation window be the safer choice?
5. Run `kubectl describe hpa -n hpa-lab` after a load test and read the
   Events section — it records every scaling decision with a reason.
6. Try scaling on a custom metric: the commented-out section in
   `manifests/03-hpa.yaml` shows an `external.metrics.k8s.io` example
   (requests per second from Prometheus Adapter). Note what extra
   component that needs before it can work.

## Cleanup

```bash
kind delete cluster --name hpa-lab
```

## Key takeaways

- HPA needs metrics-server (or another metrics provider) and resource
  requests on the pods — without either, it cannot compute utilisation.
- Utilisation is always relative to the *request*, so right-sizing
  requests is what makes autoscaling behave.
- Scale-up is fast, scale-down is deliberately slow (stabilisation
  window) to avoid flapping.
- The HPA takes the max replica count across all its metrics.
