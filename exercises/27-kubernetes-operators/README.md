# Exercise 27 — Kubernetes Operators and Custom Resources

A Deployment knows how to run a stateless app, but it does not know
what your app *is*. An operator closes that gap: you define a custom
resource that describes the application in your own terms, and a
controller watches it and keeps the real workloads in line with it.
This exercise builds a small, working operator from scratch — no Go,
no code generation, just a Python script and `kubectl`.

## What you will learn

- What a CustomResourceDefinition (CRD) is and how it extends the
  Kubernetes API with your own resource type
- How a controller reconciles desired state (the custom resource)
  with actual state (Deployments and Services)
- How the operator pattern turns a one-off deployment into a
  reusable, declarative API for your team
- How RBAC scopes what an operator is allowed to touch

## Prerequisites

- A local cluster: `kind` (used here) or minikube
- `kubectl` configured against the cluster
- `python3` on the machine running the operator
- Exercise 04 (Kubernetes basics) and Exercise 25 (service discovery)
  completed

## Why operators matter

Almost every serious platform team ends up writing one. A database
operator turns `kind: PostgresCluster` into StatefulSets, backups
and users. A certificate operator turns `kind: Certificate` into a
renewed TLS secret. Without an operator, every team member has to
remember the same five manifests and keep them in sync by hand. With
one, the platform team ships a single, boring resource type and the
rest of the company just fills in the fields.

The operator in this exercise manages a `WebApp` resource:

```yaml
apiVersion: example.lab/v1
kind: WebApp
metadata:
  name: hello
  namespace: lab-operators
spec:
  image: nginx:1.27
  replicas: 2
  message: "Hello from the operator!"
```

Apply that, and the operator creates a Deployment with the right
image and replica count, a Service to reach it, and a ConfigMap
carrying the message the app serves. Edit `spec.replicas` and the
operator scales the Deployment. Delete the `WebApp` and the operator
cleans up everything it created. That loop — watch, compare, act —
is the whole job of a controller.

## How the operator works

The controller is `operator/operator.py`, a single Python script
using only the standard library. It runs in a loop:

1. List all `WebApp` resources in the cluster with
   `kubectl get webapps -A -o json`.
2. For each one, compute the Deployment, Service and ConfigMap that
   should exist from its `spec`.
3. Apply those objects with `kubectl apply -f -`, labelling each
   one `app.kubernetes.io/managed-by: webapp-operator` so it is
   clear who owns them.
4. Patch the `WebApp` status with the number of ready replicas, so
   `kubectl get webapps` shows real state instead of silence.
5. Sleep 10 seconds and do it again.

Polling every 10 seconds is deliberately simple. Production
operators use a watch stream so they react instantly, but the
reconcile logic is identical — the watch just replaces the sleep.

## Steps

### 1. Create the cluster

```bash
kind create cluster --name lab-operators --config manifests/kind-config.yaml
# or reuse an existing cluster and skip to step 2
```

### 2. Install the CRD

```bash
kubectl apply -f manifests/01-crd.yaml
kubectl get crds webapps.example.lab
kubectl api-resources | grep -i webapp
```

The CRD registers `WebApp` as a real API type. From now on `kubectl
get webapps` works, and the API server validates every `WebApp`
against the schema in the CRD — try applying one with
`spec.replicas: -1` and watch the server reject it.

### 3. Deploy the operator

```bash
./scripts/setup.sh
kubectl get pods -n lab-operators
kubectl logs -n lab-operators deployment/webapp-operator -f
```

`setup.sh` builds the operator image from `operator/Dockerfile`
(Python plus `kubectl`), loads it into the kind cluster, then applies
the namespace, CRD, RBAC and operator Deployment, and finally the
example `WebApp`. The log lines show each reconcile pass. The operator
runs as a pod in the cluster and talks to the API server with a
ServiceAccount.
Look at `manifests/02-operator-rbac.yaml` to see exactly what it
is allowed to do: read and write `webapps`, and create Deployments,
Services and ConfigMaps in its namespace. Nothing else.

### 4. Create your first WebApp

```bash
kubectl apply -f manifests/04-webapp-example.yaml
kubectl get webapps -n lab-operators
kubectl get pods -n lab-operators -l app=hello
```

Within seconds the operator creates the Deployment, the Service and
the ConfigMap. Check that the message made it through:

```bash
kubectl port-forward svc/hello -n lab-operators 8080:80 &
curl http://localhost:8080
```

You should see the `message` from the `WebApp` spec.

### 5. Change the desired state and watch the operator react

```bash
kubectl patch webapp hello -n lab-operators \
  --type=merge -p '{"spec":{"replicas":3,"message":"Scaled up by the operator!"}}'
kubectl get pods -n lab-operators -l app=hello -w
```

You changed one resource, the operator did the rest: a third
replica appears, the ConfigMap is updated, and the status on the
`WebApp` reports `readyReplicas: 3`. This is the point of the whole
pattern — the user declares intent, the operator owns the mechanics.

### 6. Delete the WebApp and watch the cleanup

```bash
kubectl delete webapp hello -n lab-operators
kubectl get deployments,services,configmaps -n lab-operators -l app.kubernetes.io/managed-by=webapp-operator
```

Everything the operator created is gone. The operator treats a
missing `WebApp` as desired state "nothing should exist" and
reconciles towards it — deletion is just reconciliation with an
empty list.

### 7. Run the checks

```bash
./scripts/test.sh
```

## Tasks

1. Add a second `WebApp` with a different name, image and message
   and confirm the operator manages both independently.
2. Break the operator's loop on purpose: delete the Deployment the
   operator created and watch it come back within 10 seconds. This
   self-healing is why operators beat manual manifests.
3. Extend the CRD schema: add an optional `spec.port` field (default
   80) and teach `operator.py` to use it for the Service and the
   container port. Validate the schema rejects a port of 99999.
4. Try `kubectl get webapps -A -o yaml` and compare the status the
   operator writes with the spec you declared.
5. Look at the RBAC file and remove the operator's permission to
   create Services. Reapply, restart the operator pod, and watch the
   reconcile fail in the logs — then restore the permission.

## Cleanup

```bash
kind delete cluster --name lab-operators
# or, if you used an existing cluster:
# kubectl delete namespace lab-operators
# kubectl delete crd webapps.example.lab
```

## Key takeaways

- A CRD turns a team's tribal knowledge into an API: one resource
  type replaces a folder of manifests and a runbook.
- A controller is a loop: read desired state, read actual state,
  make them match. Everything else is detail.
- Reconciliation must be idempotent — running it twice has to give
  the same result, because it will run hundreds of times a day.
- RBAC is the operator's blast radius. Give it the narrowest
  permissions that let it do its job and nothing more.
- Deletion is reconciliation too: a resource disappearing is just
  desired state becoming empty.
