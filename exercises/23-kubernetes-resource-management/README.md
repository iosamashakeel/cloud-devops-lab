# Exercise 23 — Kubernetes Resource Management

Requests and limits are how Kubernetes decides where a pod can run and how
much it may consume. Get them wrong and you get two classic production
failures: pods that cannot be scheduled at all, and pods that get killed
out of nowhere. This exercise makes both failures happen on purpose, in a
safe cluster, so you recognise them when they happen for real.

## What you will learn

- The difference between a request (a guaranteed minimum, used for
  scheduling) and a limit (a hard ceiling, enforced by the kernel)
- What happens when a container exceeds its CPU limit (throttling) versus
  its memory limit (OOMKilled, exit code 137)
- The three Quality of Service classes — Guaranteed, Burstable,
  BestEffort — and the order Kubernetes evicts pods in when a node runs
  out of memory
- How a LimitRange sets defaults and min/max bounds for a namespace
- How a ResourceQuota caps the total resources a namespace may consume

## Prerequisites

- A local cluster: `kind` (used here) or minikube
- `kubectl` configured against the cluster
- Exercise 04 (Kubernetes basics) completed

## Why requests and limits matter

The scheduler places a pod on a node only if the node has enough
*unrequested* CPU and memory left. A request is therefore a reservation:
the pod is guaranteed at least that much. A limit is the opposite — the
most the container is allowed to use. The two are enforced differently:

- **CPU over the limit:** the container is throttled. It keeps running,
  just slower. No crash, no error, only latency.
- **Memory over the limit:** the kernel kills the container with
  OOMKilled. The pod restarts (or stays dead, depending on
  `restartPolicy`), and the only trace is exit code 137.

A pod with no requests at all can be scheduled onto a node that is already
full, and a pod with no limits can eat the whole node. In a shared cluster
that is how one bad deployment takes everyone else down.

## Steps

### 1. Create the cluster

```bash
./scripts/setup.sh
```

This creates a kind cluster (`resources-lab`) and applies the manifests:
a LimitRange, a ResourceQuota, a Guaranteed deployment, a Burstable
deployment, a memory-hog pod, and a pod with no resource settings at all.

### 2. Look at what the LimitRange did

```bash
kubectl describe limitrange -n resources-lab
kubectl get pod no-resources -n resources-lab \
  -o jsonpath='{.spec.containers[0].resources}'
```

The `no-resources` pod asked for nothing. The LimitRange filled in the
defaults anyway (100m CPU / 128Mi memory requested, 500m / 256Mi as the
limit). That is the point of a LimitRange: no container in the namespace
runs without *some* bound, even if its author forgot.

### 3. Check the quota

```bash
kubectl describe resourcequota -n resources-lab
```

The quota caps the namespace at 2 CPU and 2Gi of memory in requests, 4 CPU
and 4Gi in limits, and 10 pods. The `Used` column shows what the running
workloads already consume. Try creating another deployment with huge
requests and watch the API server refuse it:

```bash
kubectl run too-big --image=nginx --requests='cpu=10,memory=10Gi' -n resources-lab
```

The error — `exceeded quota` — is the quota doing its job. Delete the
failed pod afterwards: `kubectl delete pod too-big -n resources-lab`.

### 4. Compare the QoS classes

```bash
kubectl get pods -n resources-lab -o custom-columns=NAME:.metadata.name,QOS:.status.qosClass
```

- `web` pods are **Guaranteed**: every container sets requests equal to
  limits for both CPU and memory. These are the last pods Kubernetes
  evicts when a node is under memory pressure.
- `worker` pods are **Burstable**: they set requests but no limits (the
  LimitRange filled the limits in, and requests differ from limits).
  They are evicted after BestEffort pods, before Guaranteed ones.
- `no-resources` is also Burstable, because the LimitRange gave it
  requests and limits. Nothing in this namespace is BestEffort — that is
  exactly what the LimitRange prevents.

### 5. Watch the memory hog get OOMKilled

```bash
kubectl get pod memory-hog -n resources-lab --watch
kubectl logs -n resources-lab memory-hog
```

The pod allocates 10 MB at a time, printing as it goes. Its memory limit
is 128Mi. Once it passes that limit the kernel kills it: the pod moves to
`Error`/`CrashLoopBackOff` (or stays `Failed`, since its
`restartPolicy` is `Never`) and `kubectl describe` shows
`Reason: OOMKilled`, exit code 137.

```bash
kubectl get pod memory-hog -n resources-lab \
  -o jsonpath='{.status.containerStatuses[0].state.terminated.reason}'
```

### 6. Run the checks

```bash
./scripts/test.sh
```

This verifies the LimitRange and quota exist, both deployments are ready,
the QoS classes are what they should be, the memory hog really was
OOMKilled, and the no-resources pod got its defaults injected.

## Tasks

1. Change the `web` deployment's memory limit to 64Mi and re-apply. What
   happens? (The container needs more than 64Mi to run nginx, so it gets
   OOMKilled on start. Requests and limits have to match what the app
   actually uses — measure first, then set them.)
2. Remove the CPU limit from one `worker` pod and load the node. What do
   you observe? (Nothing crashes — CPU over the limit only throttles.
   That asymmetry with memory is worth remembering.)
3. Lower the quota to `requests.memory: 500Mi` and try to scale the `web`
   deployment to 5 replicas. Which error do you get, and why?
   (The quota counts *requests*, so 5 × 256Mi = 1280Mi exceeds 500Mi.
   Scaling is refused even though the node has spare capacity.)
4. Add a `max` to the LimitRange (`cpu: 1`, `memory: 512Mi`) and try to
   create a pod asking for 2 CPU. What does the API server say?
5. Think about which QoS class your own workloads should be. A database
   that must never be evicted: Guaranteed. A batch job that can restart:
   Burstable. Anything in production that is BestEffort is a bug waiting
   to happen.

## Cleanup

```bash
kind delete cluster --name resources-lab
```

## Key takeaways

- Requests are for scheduling, limits are for enforcement. Set both, on
  every container, based on measured usage.
- CPU over the limit throttles; memory over the limit kills (OOMKilled,
  exit 137). Memory limits are the dangerous ones.
- QoS classes decide eviction order under pressure: BestEffort first,
  then Burstable, Guaranteed last. A LimitRange keeps a namespace free of
  BestEffort pods by giving everything defaults.
- A ResourceQuota caps a namespace's total requests and limits. It counts
  requests, not actual usage, so it can refuse work on a node that still
  has spare capacity.
- Set limits from measurements, not guesses. Too low and the app gets
  killed; too high and the quota blocks everything else.
