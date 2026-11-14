# Exercise 18: Kubernetes RBAC

In Exercise 17 you locked down *network* traffic between pods. This one
locks down *who can do what* inside the cluster. RBAC — Role-Based Access
Control — is how Kubernetes decides whether a user or a ServiceAccount is
allowed to list pods, deploy an app, or read a secret. The default in
most clusters is far too generous, and the fix is the same idea as
before: least privilege.

## Learning goals

- Understand the four RBAC objects: Role, ClusterRole, RoleBinding,
  ClusterRoleBinding
- Give a ServiceAccount exactly the permissions it needs — and no more
- Use `kubectl auth can-i` to check permissions *before* something fails
  in production
- See what a denied request looks like, and how to debug it
- Learn why you should never bind `cluster-admin` "just to make it work"

## Prerequisites

- Docker running
- `kubectl` and `kind` installed
- Exercise 04 (Kubernetes basics) completed

## Steps

### 1. Create the cluster

```bash
./scripts/setup.sh
```

This creates a kind cluster named `rbac-lab` and applies everything in
`manifests/`. It sets up:

| Object | What it is |
| --- | --- |
| Namespace `rbac-lab` | The playground — everything lives here |
| ServiceAccount `deployer` | Can deploy and scale apps, nothing else |
| ServiceAccount `reader` | Can look at things, cannot change anything |
| ServiceAccount `intruder` | Has no bindings at all — can do nothing |
| Role `deployer` / Role `reader` | The permission sets, namespace-scoped |
| RoleBinding `deployer-binding` / `reader-binding` | Attach each Role to its ServiceAccount |
| Deployment `web` | A small nginx app to deploy against |

### 2. Check what each identity can do

```bash
./scripts/test.sh
```

The script runs a matrix of `kubectl auth can-i` checks for all three
ServiceAccounts. Expected output:

```
deployer can create deployments        -> yes
deployer can delete pods               -> no
deployer can get secrets               -> no
reader   can list pods                 -> yes
reader   can create deployments        -> no
intruder can list pods                 -> no
```

### 3. Try it for real, as the deployer

```bash
kubectl --as=system:serviceaccount:rbac-lab:deployer \
  -n rbac-lab scale deploy/web --replicas=3
```

That works. Now try something the deployer is *not* allowed to do:

```bash
kubectl --as=system:serviceaccount:rbac-lab:deployer \
  -n rbac-lab get secrets
```

Kubernetes answers:

```
Error from server (Forbidden): secrets is forbidden:
User "system:serviceaccount:rbac-lab:deployer" cannot list resource
"secrets" in API group "" in the namespace "rbac-lab"
```

That error message is your friend. It names the user, the resource, the
verb and the namespace — everything you need to fix the Role.

### 4. Try it as the reader

```bash
kubectl --as=system:serviceaccount:rbac-lab:reader \
  -n rbac-lab get pods
```

Works. Then:

```bash
kubectl --as=system:serviceaccount:rbac-lab:reader \
  -n rbac-lab delete pod -l app=web
```

Forbidden. Read-only means read-only.

### 5. Use a real token, not just `--as`

`--as` impersonates an identity, but real workloads authenticate with a
token. Mint one for the deployer and use it:

```bash
TOKEN=$(kubectl -n rbac-lab create token deployer --duration=1h)
SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
kubectl --token="$TOKEN" --server="$SERVER" \
  --insecure-skip-tls-verify -n rbac-lab get deployments
```

### 6. Break it on purpose

Edit `manifests/02-roles.yaml` and remove `secrets` from... wait, the
deployer Role never had secrets. Instead, remove `deployments` from the
deployer Role, re-apply, and re-run the scale command from step 3. It
fails. That is the point: the Role is the single source of truth, and
changing it changes behaviour immediately — no restart needed.

Restore the file and re-apply when you are done.

## Tasks

1. Run `test.sh` and confirm every line matches the expected output.
2. Give the `reader` permission to read ConfigMaps too, and verify it
   with `can-i`.
3. Create a new ServiceAccount `auditor` and a Role that can only `get`
   and `list` pods — no `watch`, no deployments. Bind it and test.
4. Try binding the built-in `ClusterRole` `view` to a ServiceAccount
   with a RoleBinding (namespace-scoped) vs a ClusterRoleBinding
   (cluster-wide). Check with `can-i` in a *different* namespace to see
   the difference.
5. Bonus: look up the `system:discovery` ClusterRole and explain why it
   exists. Then find one ClusterRoleBinding in your cluster that you
   would not want in production and explain why.

## Cleanup

```bash
kind delete cluster --name rbac-lab
```

## What to take away

- RBAC has four objects: Role and ClusterRole define permissions,
  RoleBinding and ClusterRoleBinding attach them to users, groups and
  ServiceAccounts.
- Roles are namespace-scoped; ClusterRoles are cluster-wide. Bind a
  ClusterRole with a RoleBinding when you want its permissions in one
  namespace only.
- `kubectl auth can-i` answers permission questions in seconds. Use it
  before you deploy, not after something breaks at 2am.
- A Forbidden error tells you the user, resource, verb and namespace.
  Read it — it is the fix.
- Never bind `cluster-admin` to make something work. Find the smallest
  Role that does the job and stop there.
- ServiceAccounts are identities too. Every pod runs as one, and the
  default ServiceAccount in a namespace has almost no permissions —
  which is exactly how it should stay.
