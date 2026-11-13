# Exercise 17: Kubernetes Network Policies

By default, every pod in Kubernetes can talk to every other pod. That is
convenient in a lab and dangerous in production. Network Policies let you
lock traffic down to exactly what each workload needs — nothing more.

## Learning goals

- Understand the default-allow behaviour of Kubernetes networking
- Write a default-deny policy for a namespace
- Allow traffic only between specific pods, selected by labels
- Allow DNS egress so name resolution keeps working under default-deny
- Prove the policies work with a client pod and an intruder pod

## Prerequisites

- Docker running
- `kubectl`, `kind`, and `curl` installed
- Exercise 04 (Kubernetes basics) completed

> Why Calico? The default CNI that ships with kind does not enforce
> Network Policies — it would silently ignore them. This exercise installs
> Calico, which does.

## Steps

### 1. Create the cluster with Calico

```bash
./scripts/setup.sh
```

This creates a kind cluster named `netpol-lab` without the default CNI,
installs Calico, and waits until all Calico pods are ready. It takes a
couple of minutes on first run.

### 2. Deploy the demo app

```bash
kubectl apply -f demo-app/
```

This creates the `netpol-lab` namespace with two workloads:

- `frontend` — an nginx pod that serves a small page
- `backend` — an `http-echo` pod answering on port 5678
- `client` and `intruder` — two curl pods used to test the policies

### 3. Prove everything is open (before policies)

```bash
./scripts/test.sh
```

Before any policy is applied, both the client and the intruder can reach
the backend. That is the default-allow behaviour — keep this in mind the
next time someone says "it's inside the cluster, it's fine".

### 4. Apply the policies

```bash
kubectl apply -f policies/
```

Four policies land in the namespace:

| File | What it does |
| --- | --- |
| `00-default-deny.yaml` | Denies all ingress and egress for every pod in the namespace |
| `01-backend-ingress.yaml` | Backend accepts traffic only from `frontend` pods, port 5678 |
| `02-frontend-egress.yaml` | Frontend may only send traffic to `backend` pods, port 5678 |
| `03-allow-dns.yaml` | Every pod may resolve names via kube-dns (UDP/TCP 53) |

### 5. Prove the lockdown works

```bash
./scripts/test.sh
```

Now the client (labelled `app=frontend`) still reaches the backend, and
the intruder gets a timeout. DNS still works, because the egress policy
for kube-dns is in place. If you skip step 4's DNS policy, name
resolution breaks and even allowed traffic fails — try it, it is a
classic mistake.

### 6. Watch a policy block in real time

```bash
kubectl exec -n netpol-lab deploy/intruder -- \
  curl -s -m 5 http://backend:5678
```

The command hangs and times out after 5 seconds. Nothing is logged by
default — Network Policies drop packets silently, which is why step 5's
test script is the way to verify behaviour, not logs.

## Tasks

1. Run the test script before and after applying the policies and compare.
2. Remove `03-allow-dns.yaml` and see what breaks; then restore it.
3. Add a policy that lets the `intruder` reach the backend only on a
   different port, then remove it again.
4. Write a policy that allows the backend to call out to an external API
   (egress to `0.0.0.0/0` on port 443) and discuss why that is usually a
   bad idea.
5. Bonus: add a second namespace with its own default-deny policy and
   allow traffic from the frontend namespace only via `namespaceSelector`.

## Cleanup

```bash
kind delete cluster --name netpol-lab
```

## What to take away

- Default-allow is the Kubernetes default. If you never write a policy,
  every pod can reach every pod.
- Start with default-deny, then allow exactly what is needed — least
  privilege applies to network traffic too.
- DNS egress is the policy everyone forgets. Under default-deny, no DNS
  means no working service names.
- Labels are the whole game: policies select pods by label, so sloppy
  labelling means sloppy security.
