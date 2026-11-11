# Exercise 15: GitOps with Argo CD

Deploy an application to Kubernetes the GitOps way: Git is the single source of truth, and Argo CD keeps the cluster in sync with it automatically.

## Learning goals

- Understand the GitOps model: desired state lives in Git, an agent reconciles the cluster
- Install Argo CD on a local kind cluster
- Declare an `Application` that tracks a Git repository path
- Watch Argo CD sync, detect drift, and self-heal
- Roll back a bad change with `git revert` instead of `kubectl`

## Prerequisites

- Docker running
- `kubectl`, `kind`, and `git` installed
- Exercises 04 (Kubernetes basics) and 11 (Helm intro) completed

## Steps

### 1. Create the cluster and install Argo CD

```bash
./scripts/install.sh
```

This creates a kind cluster named `gitops-lab`, installs Argo CD in the
`argocd` namespace, and waits until all pods are ready. It prints the
initial admin password at the end.

### 2. Open the Argo CD UI

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Open https://localhost:8080 and log in as `admin` with the password from
step 1. Accept the self-signed certificate warning; this is a local lab.

### 3. Register the demo application

The `argocd/application.yaml` in this exercise points at the `demo-app/`
folder of this repository. Apply it:

```bash
kubectl apply -f argocd/application.yaml
```

In the UI you should see the `demo-app` application appear and sync to
`Synced` / `Healthy` within a minute.

### 4. Verify the app is running

```bash
kubectl get pods -n demo
kubectl port-forward svc/demo-app -n demo 8081:80
curl localhost:8081
```

You should get a small "Hello from GitOps" page served by nginx.

### 5. Try drift detection

Change something directly in the cluster, bypassing Git:

```bash
kubectl scale deployment demo-app -n demo --replicas=3
```

Watch the Argo CD UI: the application flips to `OutOfSync`. Because the
Application has `selfHeal: true`, Argo CD restores the replica count from
Git within a few seconds. Check:

```bash
kubectl get deployment demo-app -n demo
```

### 6. Ship a change through Git

Edit `demo-app/deployment.yaml` — for example, change the nginx image tag
from `1.27` to `1.27-alpine` — commit and push. Argo CD picks the change up
automatically (default poll interval is 3 minutes) and rolls the deployment
forward. No `kubectl apply` needed.

### 7. Roll back with git revert

Made a bad change? Revert the commit and push. Argo CD syncs the old state
back. That is the whole point: the cluster history is the Git history.

## Tasks

1. Install Argo CD and confirm all pods are `Running`.
2. Sync the demo app and load its page in your browser.
3. Force drift with `kubectl scale` and watch self-heal restore it.
4. Change the replica count in Git to 2, push, and confirm the cluster follows.
5. Break the deployment on purpose (e.g. a bad image tag), then fix it with `git revert`.
6. Bonus: add a second `Application` that deploys the same demo app into a `staging` namespace using a Kustomize overlay.

## Cleanup

```bash
kind delete cluster --name gitops-lab
```

## What to take away

- Never `kubectl apply` by hand in a GitOps setup; change Git and let the agent sync.
- Drift is normal (someone always edits live). Self-heal turns it into a non-event.
- Rollbacks become ordinary Git operations, which means they are reviewable and auditable.
