# Exercise 11: Helm Intro — Package an App as a Chart

## Learning goals

- Understand what a Helm chart is: a package of Kubernetes manifests plus
  values that let you install the same app differently per environment.
- Install, upgrade, roll back, and uninstall a release.
- Override values from the command line and from a custom values file.
- See why charts beat hand-maintaining one copy of each YAML file per
  environment.

## Prerequisites

- A Kubernetes cluster you can reach (`kubectl cluster-info` works).
  A local cluster such as minikube or kind is fine.
- Helm 3 installed (`helm version`).
- Exercises 04 (Kubernetes basics) done, so Deployments and Services
  are already familiar.

## The chart

`myapp/` is a small, complete chart. It deploys an nginx web server
behind a Service, with a ConfigMap holding a custom welcome page.
There is nothing app-specific about the pattern: the same structure
works for any container image.

```
myapp/
├── Chart.yaml              # chart name, version, description
├── values.yaml             # defaults you override per environment
└── templates/
    ├── deployment.yaml
    ├── service.yaml
    ├── configmap.yaml
    └── NOTES.txt           # printed after a successful install
```

## Steps

### 1. Look at the chart first

```bash
cat myapp/Chart.yaml
cat myapp/values.yaml
helm template myapp/ ./myapp
```

`helm template` renders the manifests locally without touching the
cluster. It is the fastest way to catch a typo in a template before
you install anything. Read the output: the Deployment, Service, and
ConfigMap should all carry the release name.

### 2. Install it

```bash
helm install demo ./myapp
helm list
kubectl get pods,svc,configmap -l app.kubernetes.io/instance=demo
```

`demo` is the release name. The same chart installed twice with two
release names gives you two independent copies of the app.

### 3. Check the output

Helm prints NOTES.txt after installing. Follow its hint to reach the
app, for example by port-forwarding the Service:

```bash
kubectl port-forward svc/demo-myapp 8080:80
```

Then open http://localhost:8080 in a browser. You should see the
custom welcome page from the ConfigMap, not the nginx default page.

### 4. Override a value

Change the replica count without editing any template:

```bash
helm upgrade demo ./myapp --set replicaCount=3
kubectl get pods -l app.kubernetes.io/instance=demo
```

Or keep the override in a file, which is how real environments do it.
Create `staging-values.yaml`:

```yaml
replicaCount: 2
image:
  tag: "1.27"
```

```bash
helm upgrade demo ./myapp -f staging-values.yaml
helm get values demo
```

`helm get values` shows what is actually applied, which is the
quickest way to answer "what is running right now?".

### 5. Roll back

Every upgrade creates a new revision. Break something on purpose,
then undo it:

```bash
helm upgrade demo ./myapp --set image.tag=does-not-exist
helm history demo
helm rollback demo 1
helm history demo
```

`helm history` is the audit trail: who changed what, and when.

### 6. Uninstall and clean up

```bash
helm uninstall demo
helm list
kubectl get pods,svc,configmap -l app.kubernetes.io/instance=demo
```

Everything the chart created should be gone. That clean removal is
half the point of packaging: no orphaned resources left behind.

## Tasks

1. Install the chart with release name `demo` and reach the welcome page.
2. Upgrade to 3 replicas with `--set`, then verify with `kubectl get pods`.
3. Write your own `prod-values.yaml` (2 replicas, a different welcome
   message in `welcomeMessage`) and upgrade with `-f`.
4. Run `helm history demo` and explain, in one sentence per revision,
   what changed.
5. Roll back to revision 1, then uninstall. Confirm nothing is left.

## Stretch goals

- Add an `ingress.yaml` template, gated by an `ingress.enabled` value,
  so the chart can optionally expose the app through an Ingress.
- Add a second chart (for example a tiny API) and install both releases
  into the same namespace.
- Package the chart with `helm package ./myapp` and install from the
  resulting `.tgz` file instead of the directory.

## Cleanup

```bash
helm uninstall demo 2>/dev/null || true
```
