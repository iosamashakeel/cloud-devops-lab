# Exercise 04 — Kubernetes Basics

Deploy a real application to Kubernetes. In this exercise you take the nginx container
from Exercise 01, declare it as a Kubernetes Deployment with 3 replicas, front it with
a Service, and watch Kubernetes keep it alive.

## Files

- `deployment.yaml` — Deployment (3 replicas) + a ConfigMap that serves a custom page
- `service.yaml` — ClusterIP Service routing port 80 to the pods

## Prerequisites

- A running cluster. The easiest local options:
  - **Docker Desktop** → Settings → Kubernetes → Enable Kubernetes
  - or `minikube start` after installing [minikube](https://minikube.sigs.k8s.io/docs/start/)
- `kubectl` installed and pointing at your cluster (`kubectl cluster-info` should answer)

No cluster yet? Install minikube — it takes a few minutes and runs fine on a laptop.

## Task 1 — Apply the manifests

```bash
kubectl apply -f deployment.yaml -f service.yaml
```

Check that everything came up:

```bash
kubectl get deployments
kubectl get pods -o wide
kubectl get svc devops-lab-web
```

All 3 pods should reach `Running` with `1/1 READY`.

## Task 2 — Reach the app

The Service is `ClusterIP`, so it is only reachable inside the cluster. Forward a local port:

```bash
kubectl port-forward svc/devops-lab-web 8080:80
```

Open http://localhost:8080 — you should see "Served from Kubernetes".

## Task 3 — Scale it

```bash
kubectl scale deployment devops-lab-web --replicas=5
kubectl get pods -w   # watch the two new pods appear
```

Scale back down when you're done:

```bash
kubectl scale deployment devops-lab-web --replicas=3
```

## Task 4 — Break a pod on purpose

Delete one pod and watch Kubernetes replace it — that self-healing loop is the
core of what a Deployment gives you over raw `docker run`:

```bash
kubectl delete pod -l app=devops-lab-web   # deletes one pod (pick any name from get pods)
kubectl get pods -w
```

The Deployment controller notices the missing replica and starts a replacement
within seconds. The service never drops — requests keep flowing to the survivors.

## Task 5 — Rolling update

Bump the nginx image tag to trigger a rolling update:

```bash
kubectl set image deployment/devops-lab-web web=nginx:1.28-alpine
kubectl rollout status deployment/devops-lab-web
```

Watch it in another terminal with `kubectl get pods -w`: pods are replaced one by
one, so the app stays available throughout. Roll back if anything looks wrong:

```bash
kubectl rollout undo deployment/devops-lab-web
```

## Task 6 — Read the state back

Try these and match the output to what you declared in the YAML:

```bash
kubectl describe deployment devops-lab-web
kubectl describe svc devops-lab-web
kubectl get configmap devops-lab-html -o yaml
```

Notice how `describe` shows both your declared state and what the controllers are
doing about it (events at the bottom are the most useful part when debugging).

## Task 7 — Clean up

```bash
kubectl delete -f deployment.yaml -f service.yaml
```

## What you learned

- **Deployment** = desired state (image, replica count, update strategy). The controller converges reality to it.
- **Service** = a stable virtual IP + DNS name in front of a shifting set of pods.
- **ConfigMap** = configuration injected into containers without rebuilding the image.
- **Probes** keep traffic away from pods that aren't ready and restart ones that are stuck.

## Stretch goals

- Change the Service to `type: NodePort` and reach it without port-forwarding.
- Add an `env` variable to the container and read it from a second ConfigMap entry.
- Write your own manifest for the app container from Exercise 01 and deploy it instead of nginx.
