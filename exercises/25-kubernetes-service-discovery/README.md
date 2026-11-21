# Exercise 25 — Kubernetes Service Discovery and DNS

A pod's IP changes every time it restarts. Nothing in a cluster can
rely on it — so how does anything find anything? Services give a
workload a stable name and a stable IP, and CoreDNS turns that name
into an address. This exercise builds a small backend, puts three
different kinds of Service in front of it, and shows exactly what
each one resolves to.

## What you will learn

- What a Service actually is: a stable virtual IP plus a set of
  Endpoints that track the matching pods
- The difference between ClusterIP, NodePort and headless Services —
  and when each one is the right tool
- How DNS names are built in a cluster
  (`<service>.<namespace>.svc.cluster.local`) and what CoreDNS does
  with them
- Why a headless Service returns pod IPs instead of a virtual IP, and
  why stateful workloads need that
- How to debug "service unreachable" with `nslookup`, `dig` and
  `curl` from inside the cluster

## Prerequisites

- A local cluster: `kind` (used here) or minikube
- `kubectl` configured against the cluster
- Exercise 04 (Kubernetes basics) completed

## Why service discovery matters

In a cluster, pods are cattle: they get created, deleted and
rescheduled, and every new pod gets a new IP. If your frontend
hard-coded the backend pod's IP, it would break on the next restart.
A Service fixes that by giving the backend a name that never changes
and a virtual IP (ClusterIP) that never changes, while kube-proxy
keeps the traffic flowing to whichever pods are alive right now.

The DNS name for a Service is fully qualified:

```
<service-name>.<namespace>.svc.cluster.local
```

Inside the same namespace you can just use the short name
(`backend`), and Kubernetes resolves it. That is the single most
important fact in this exercise: **in-cluster, services talk to each
other by name, never by IP.**

## The demo app

A tiny Python HTTP server (one file, in a ConfigMap) that answers
every request with its own pod hostname:

```
hello from backend-6f7c9d4b8c-x2kzq
```

Run two replicas behind a Service and you can watch load balancing
happen: repeated requests return different hostnames, because
kube-proxy spreads the connections across the Endpoints.

## Steps

### 1. Create the cluster

```bash
./scripts/setup.sh
```

This creates a kind cluster (`discovery-lab`) with host port 30080
mapped to the node's NodePort range, then deploys the backend
(two replicas), a ClusterIP Service, a headless Service, a NodePort
Service and a debug pod with networking tools.

### 2. Look at the Service and its Endpoints

```bash
kubectl get svc -n discovery-lab
kubectl get endpoints backend -n discovery-lab
kubectl describe svc backend -n discovery-lab
```

The Endpoints object lists the two backend pod IPs. That is the
Service's whole job: keep this list in sync with the pods matching
its selector, and give clients one stable ClusterIP to aim at. Scale
the deployment and watch the Endpoints update:

```bash
kubectl scale deployment backend -n discovery-lab --replicas=4
kubectl get endpoints backend -n discovery-lab
kubectl scale deployment backend -n discovery-lab --replicas=2
```

### 3. Resolve the names from inside the cluster

```bash
kubectl exec -n discovery-lab deploy/debug -- nslookup backend
kubectl exec -n discovery-lab deploy/debug -- nslookup backend-headless
kubectl exec -n discovery-lab deploy/debug -- nslookup backend.discovery-lab.svc.cluster.local
```

`backend` resolves to a single ClusterIP (e.g. `10.96.0.12`).
`backend-headless` resolves to **two A records** — the pod IPs
themselves. That is the headless difference: no virtual IP, no
load balancing, the client gets the real pod addresses and picks
one itself. StatefulSets and databases use headless Services for
exactly this reason: each replica needs its own stable address.

### 4. Watch load balancing happen

```bash
kubectl exec -n discovery-lab deploy/debug -- \
  sh -c 'for i in 1 2 3 4 5 6; do curl -s http://backend:8080/; done'
```

You should see both pod hostnames interleaved. Every request goes
to the Service's ClusterIP, and kube-proxy (iptables/IPVS rules on
each node) forwards it to one of the Endpoints. The client never
sees the pod IPs.

Try the same against the headless name:

```bash
kubectl exec -n discovery-lab deploy/debug -- \
  sh -c 'for i in 1 2 3; do curl -s http://backend-headless:8080/; done'
```

With a headless Service there is no load balancing — `curl`
resolves the name once and talks to the first IP it gets. That is
expected, and it is why headless Services are for clients that do
their own discovery (a database driver, a StatefulSet peer).

### 5. Reach the Service from your laptop

```bash
curl http://localhost:30080/
```

The NodePort Service exposes the backend on port 30080 of every
node, and kind maps that port to your host. This is how you reach a
cluster service during development — in production you would put an
Ingress or a LoadBalancer in front of it instead (see Exercise 19).

### 6. Run the checks

```bash
./scripts/test.sh
```

This verifies the backend has two Endpoints, the ClusterIP Service
resolves to one address, the headless Service resolves to two pod
IPs, the debug pod can reach the backend by name, and the NodePort
answers from the host.

## Tasks

1. Delete one backend pod (`kubectl delete pod -n discovery-lab -l app=backend`)
   and re-run `kubectl get endpoints backend`. How fast does the
   Endpoints list recover, and what happens to requests in between?
   (The controller replaces the pod and the Endpoints update within
   seconds. In-flight requests to the dead pod fail — which is why
   real clients retry.)
2. Change the backend Service selector to `app: nonexistent` and
   apply it. What do `kubectl get endpoints backend` and a `curl`
   from the debug pod show now? Put the selector back.
   (Endpoints go empty, `curl` hangs or is refused. A Service with
   no matching pods is the most common cause of "service
   unreachable" — check the selector first, always.)
3. From the debug pod, run `dig backend.discovery-lab.svc.cluster.local`
   and `dig backend-headless.discovery-lab.svc.cluster.local`. Compare
   the answer sections. Which one has a single A record and which
   has two?
4. Create a Service of type `ExternalName` pointing at
   `example.com` and resolve it from the debug pod. What does it
   return, and when would you use it? (It returns a CNAME to the
   external host — useful for giving an outside dependency a stable
   in-cluster name, e.g. a managed database.)
5. `kubectl exec` into a backend pod and run `cat /etc/resolv.conf`.
   What are the `search` domains, and why does a short name like
   `backend` resolve at all? (The search list appends
   `discovery-lab.svc.cluster.local`, `svc.cluster.local` and
   `cluster.local` in turn, so the short name expands to the FQDN.)

## Cleanup

```bash
kind delete cluster --name discovery-lab
```

## Key takeaways

- Never address a pod by IP. Services give a workload a stable
  name and a stable ClusterIP; the Endpoints object tracks the
  pods behind it.
- Inside a namespace, the short service name is enough. The full
  name is `<service>.<namespace>.svc.cluster.local`.
- A headless Service (`clusterIP: None`) has no virtual IP — DNS
  returns the pod IPs directly. That is what StatefulSets and
  databases need.
- NodePort exposes a Service on a port of every node. It is a
  development tool; use an Ingress or LoadBalancer in production.
- When a service is unreachable, check in this order: the Service
  selector matches the pods, the Endpoints list is non-empty, DNS
  resolves the name, and the pods themselves answer.
