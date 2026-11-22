# Exercise 26 — Kubernetes Troubleshooting and Debugging

Every pod you deploy will break sooner or later. The difference between
a long outage and a short one is usually a repeatable debugging routine:
look at the pod, read the events, read the logs, then fix the cause
instead of the symptom. This exercise breaks things on purpose so you
can practise that routine in a safe cluster.

## What you will learn

- The standard debugging order: `kubectl get pods`, `describe`,
  `logs`, `events` — and what each one actually tells you
- How to recognise and fix the five most common failure modes:
  `CrashLoopBackOff`, `ImagePullBackOff`, pending pods, failing
  probes, and a Service with no endpoints
- How to use `kubectl debug` and ephemeral containers to inspect a
  running pod without rebuilding its image
- How to read resource pressure from `kubectl top` and node conditions

## Prerequisites

- A local cluster: `kind` (used here) or minikube
- `kubectl` configured against the cluster
- Exercise 04 (Kubernetes basics) completed

## Why troubleshooting matters

Kubernetes hides a lot of complexity behind a clean API, and that is
great until something goes wrong — then the error message is three
layers away from the cause. A pod stuck in `CrashLoopBackOff` is
rarely a Kubernetes problem: it is usually an app that exits, a
missing file, or a bad config value. The skill is not memorising
error strings, it is knowing where to look first so you stop guessing.

## The broken lab

The manifests in this exercise deploy five deliberately broken
workloads into the `lab-troubleshooting` namespace, one per failure
mode. Each one is broken in exactly one way, and each fix is small.
Your job is to diagnose each one before looking at the fix.

| Workload | Symptom | Root cause |
| --- | --- | --- |
| `crashloop` | `CrashLoopBackOff` | App exits immediately (bad command) |
| `bad-image` | `ImagePullBackOff` | Image tag does not exist |
| `hungry` | `Pending` | Requests more CPU than any node has |
| `sick` | `Running` but not `Ready` | Readiness probe hits a path that 404s |
| `orphan-svc` | Service has no endpoints | Selector does not match any pod label |

## Steps

### 1. Create the cluster

```bash
kind create cluster --name lab-troubleshoot --config manifests/kind-config.yaml
# or reuse an existing cluster:
# kubectl create namespace lab-troubleshooting
```

Then deploy everything broken:

```bash
./scripts/setup.sh
kubectl get pods -n lab-troubleshooting
```

You should see a mix of `CrashLoopBackOff`, `ImagePullBackOff`,
`Pending` and `0/1` ready pods. That is the point — do not fix
anything yet.

### 2. Diagnose the CrashLoopBackOff

```bash
kubectl get pods -n lab-troubleshooting
kubectl describe pod crashloop -n lab-troubleshooting
kubectl logs crashloop -n lab-troubleshooting --previous
```

`describe` shows the restart count climbing and the last exit code.
`--previous` shows the logs of the container that already exited —
without it you see nothing, because the current container has not
started yet. The log line tells you the real story: the app tried to
run a command that does not exist.

Fix it by applying the corrected command in
`manifests/06-fixed-deployment.yaml`, or edit the pod in place:

```bash
kubectl delete pod crashloop -n lab-troubleshooting
kubectl apply -f manifests/06-fixed-deployment.yaml
```

### 3. Diagnose the ImagePullBackOff

```bash
kubectl describe pod -l app=bad-image -n lab-troubleshooting
```

The events say `Failed to pull image "nginx:9.9.9": ... not found`.
There is no such tag. This is the one failure where the fix is
obvious from the event alone — but check anyway that the registry
name is spelled right before assuming the tag is wrong.

```bash
kubectl set image deployment/bad-image web=nginx:1.27 -n lab-troubleshooting
```

### 4. Diagnose the pending pod

```bash
kubectl describe pod hungry -n lab-troubleshooting
```

Look at the Events section: `0/1 nodes are available: 1 Insufficient
cpu`. The pod asks for 64 CPUs on a laptop cluster. Nothing is wrong
with the pod itself — the request is impossible. Fix the request,
not the cluster:

```bash
kubectl patch deployment hungry -n lab-troubleshooting \
  --type=json -p='[{"op":"replace","path":"/spec/template/spec/containers/0/resources/requests/cpu","value":"100m"}]'
kubectl get pods -n lab-troubleshooting -w
```

### 5. Diagnose the pod that never becomes ready

```bash
kubectl get pods -n lab-troubleshooting
kubectl describe pod -l app=sick -n lab-troubleshooting
```

The pod is `Running` and `1/1` containers are up, but readiness is
`0/1`. The events show `Readiness probe failed: HTTP probe failed
with statuscode: 404`. The app is fine — the probe checks
`/healthz` and the app only serves `/`. Either fix the app or fix
the probe. Here the probe is wrong:

```bash
kubectl patch deployment sick -n lab-troubleshooting \
  --type=json -p='[{"op":"replace","path":"/spec/template/spec/containers/0/readinessProbe/httpGet/path","value":"/"}]'
```

### 6. Diagnose the Service with no endpoints

```bash
kubectl get svc -n lab-troubleshooting
kubectl get endpoints orphan-svc -n lab-troubleshooting
kubectl get pods -n lab-troubleshooting --show-labels
```

The endpoints list is empty even though matching pods exist — or
seem to. Compare the Service selector with the pod labels: the
Service selects `app=web`, the pods are labelled `app=web-app`.
One character, no traffic.

```bash
kubectl patch svc orphan-svc -n lab-troubleshooting \
  -p '{"spec":{"selector":{"app":"web-app"}}}'
kubectl get endpoints orphan-svc -n lab-troubleshooting
```

### 7. Inspect a running pod without rebuilding it

```bash
kubectl debug -it crashloop-fixed -n lab-troubleshooting \
  --image=busybox --target=web
```

`kubectl debug` attaches an ephemeral container to the pod so you
can run `curl`, `nslookup`, `ps` and friends next to the real
container. Ephemeral containers cannot be removed from a running
pod — delete and recreate the pod to get rid of one.

### 8. Run the checks

```bash
./scripts/test.sh
```

## Tasks

1. Before fixing anything, write down your diagnosis for each of the
   five workloads from `describe` and `logs` alone. Check how many
   you got right after applying the fixes.
2. Break the fixed deployment on purpose: change its image tag to
   `nginx:does-not-exist`, watch the rollout stall, then roll back
   with `kubectl rollout undo`.
3. Run `kubectl top pods -n lab-troubleshooting` and
   `kubectl top nodes`. If metrics-server is not installed, install
   it (see Exercise 21) and compare the numbers with the requests
   you set.
4. Trigger an OOMKill: lower the fixed deployment's memory limit
   below what the app uses, watch for `OOMKilled` in
   `kubectl describe`, then restore a sane limit.
5. Practise reading events as a stream: `kubectl get events -n
   lab-troubleshooting --sort-by=.lastTimestamp -w` while you
   delete and recreate a pod.

## Cleanup

```bash
kind delete cluster --name lab-troubleshoot
# or, if you used an existing cluster:
# kubectl delete namespace lab-troubleshooting
```

## Key takeaways

- Always start with `get pods`, then `describe`, then `logs`. The
  events in `describe` tell you what Kubernetes tried; the logs
  tell you what the app did.
- `kubectl logs --previous` is the flag everyone forgets — a crashed
  container's logs are gone without it.
- Most "Kubernetes is broken" moments are a typo: a wrong image tag,
  a probe path that 404s, a selector that does not match a label.
- A pod in `Pending` is a scheduling problem, not an app problem —
  read the scheduler's reason before touching the app.
- Fix the cause, not the symptom: restarting a `CrashLoopBackOff`
  pod just crashes it again, faster.
