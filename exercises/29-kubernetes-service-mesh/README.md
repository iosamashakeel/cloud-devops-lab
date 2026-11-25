# Exercise 29 — Kubernetes Service Mesh with Linkerd

Admission control (Exercise 28) guards the front door. A service
mesh guards the hallways: every request between your services is
encrypted, measured, and — when you want it — split, retried, or
rerouted, without touching the application code.

This exercise installs Linkerd, the lightest of the common meshes,
on a kind cluster and meshes a small versioned web app. You will
watch mTLS appear between pods that never asked for it, read the
golden metrics (request rate, success rate, latency) per route, and
run a 90/10 canary release that shifts traffic to v2 without a
single redeploy.

## What you will learn

- What a service mesh actually does: a proxy sidecar per pod, a
  control plane that configures them, and nothing in the app itself
- How Linkerd injects its proxy automatically with a namespace
  annotation, and how to check a pod is meshed (`2/2` containers)
- How mTLS between pods works with zero application changes, and
  how to prove it with `linkerd tap` and `linkerd edges`
- How a ServiceProfile turns raw traffic into per-route golden
  metrics and lets you classify 5xx responses as failures
- How a TrafficSplit (SMI) runs a canary release: 90% stable, 10%
  new version, shifted in small steps

## Prerequisites

- Docker, `kind`, and `kubectl`
- Exercises 18 (RBAC) and 25 (Service Discovery) completed — the
  mesh builds on Services and on pods talking to each other
- About 10 minutes for the install; the control plane is small, but
  it still pulls several images

## Why a service mesh matters

In a plain cluster, service-to-service traffic is unencrypted HTTP
on the pod network. Anyone who gets into the cluster can sniff it,
and nobody can answer the simple questions: how fast is this route,
how often does it fail, which version served that request?

A mesh answers those questions by putting a tiny proxy next to
every workload. The proxy terminates TLS with an identity issued by
the mesh, so pods authenticate each other instead of trusting the
network. It records every request, so the dashboard shows latency
and error rate per route. And because the proxy sits on the request
path, it can split traffic between versions, retry a failed call,
or enforce a timeout — policy, applied at the network layer.

Linkerd is the right first mesh to learn: it is written in Rust, so
the proxy is fast and small; it installs in one command; and it
stays out of the way until you ask it for something. Istio does
more, but you pay for it in complexity and resources. Start here,
and the concepts — sidecars, mTLS, traffic splitting, golden
metrics — transfer directly.

## The app in this exercise

`app/` is a small Python web server (standard library only) with
three endpoints:

- `GET /` — returns `{"version": "v1"}` or `"v2"` plus the pod name
- `GET /health` — readiness and liveness probe
- `GET /unstable` — returns 500 about half the time, on purpose

The same image runs both versions; only the `APP_VERSION`
environment variable differs. Two Deployments (`web-v1`, two
replicas, and `web-v2`, one replica) sit behind one Service
(`web`), and the mesh decides which version answers each request.

## The mesh configuration

All of it lives in `manifests/`:

| File | What it does |
| --- | --- |
| `00-namespace.yaml` | `lab-mesh` namespace with `linkerd.io/inject: enabled`, so every pod gets a proxy |
| `01-web-v1.yaml` / `02-web-v2.yaml` | The two versions of the app |
| `03-service.yaml` | The `web` Service clients call |
| `04-service-profile.yaml` | Per-route metrics and failure classification for `/`, `/health`, `/unstable` |
| `05-traffic-split.yaml` | SMI TrafficSplit: 90% to v1, 10% to v2, plus the per-version Services it needs |

## Steps

```bash
# 1. Create the cluster, build the app, install Linkerd and the app.
./scripts/setup.sh

# 2. Confirm everything is healthy.
./scripts/test.sh
```

## Tasks

1. **Prove the pods are meshed.** `kubectl get pods -n lab-mesh`
   should show `2/2` for every web pod — app container plus
   `linkerd-proxy`. Run `linkerd check --proxy -n lab-mesh` and read
   what it verifies.
2. **Watch a request.** In one terminal, run
   `linkerd viz tap deploy/web-v1 -n lab-mesh`. In another, curl
   the service a few times from a debug pod:
   `kubectl run curl --rm -i --image=curlimages/curl --restart=Never -- sh -c 'for i in $(seq 1 10); do curl -s http://web.lab-mesh/; echo; done'`
   Watch the live requests appear in the tap output, including the
   TLS identity of the caller.
3. **See the mesh graph.** `linkerd viz edges deploy -n lab-mesh`
   shows which pods talk to which, and whether the connection is
   secured. Compare with `linkerd viz stat deploy -n lab-mesh` for
   the golden metrics per deployment.
4. **Count the canary.** Curl the service 40 times and count how
   many answers say `v2`. With a 90/10 split you should see roughly
   four. Then edit `manifests/05-traffic-split.yaml`, move v2 to
   `500m` and v1 to `500m`, reapply, and count again — a canary
   release is just a weight change.
5. **Make failures visible.** Hit `/unstable` 20 times, then check
   `linkerd viz stat deploy -n lab-mesh` again: the success rate
   for that route drops, because the ServiceProfile classifies 5xx
   as a failure. Without the profile, those 500s would still count
   as successful requests.
6. **Break it on purpose.** Delete the v2 Deployment and curl
   again — all traffic goes to v1, nothing errors. Then scale v1
   to zero and watch the requests fail fast instead of hanging:
   the proxy returns an error immediately when there is no healthy
   endpoint.

## What good looks like

- `linkerd check` passes with no warnings
- Every web pod runs `2/2` containers
- `linkerd viz stat` shows request rate, success rate and latency
  per deployment, with a visible failure rate on `/unstable`
- Roughly 10% of curls return `"version": "v2"` before you change
  the weights, roughly 50% after

## Cleanup

```bash
kind delete cluster --name lab-mesh
```

The cluster, the mesh, and the app all go away with it. Nothing
is installed on your machine except the `linkerd` CLI, which you
can remove with `rm -rf ~/.linkerd2` if you want it gone too.
