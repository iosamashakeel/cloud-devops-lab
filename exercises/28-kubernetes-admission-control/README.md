# Exercise 28 — Kubernetes Admission Control with Kyverno

Pod Security Standards (Exercise 24) and RBAC (Exercise 18) decide
*who* may do *what*. Admission control decides whether a request is
allowed *at all* — after authentication and authorisation, but
before the object is written to etcd. A validating admission
webhook can reject a Deployment that uses the `latest` tag, runs as
root, or forgets its resource limits, no matter who submitted it.

This exercise installs Kyverno, a policy engine that runs as an
admission webhook, and writes four real ClusterPolicies. You will
watch good workloads sail through and bad ones get rejected with a
clear error message — policy as code, enforced at the door.

## What you will learn

- Where admission control sits in the Kubernetes request flow, and
  how a validating webhook differs from RBAC
- How Kyverno turns a YAML policy into an admission decision, with
  no code and no custom webhook to write
- How to write policies that require labels, pin image tags, enforce
  resource limits, and block containers running as root
- The difference between `Enforce` mode (rejects the request) and
  `Audit` mode (reports the violation and lets the workload in)
- How to read policy reports to find non-compliant workloads that
  already exist in the cluster

## Prerequisites

- A local cluster: `kind` (used here) or minikube
- `kubectl` configured against the cluster
- Exercise 18 (RBAC) and Exercise 24 (Pod Security Standards)
  completed — this is the enforcement layer on top of both

## Why admission control matters

RBAC says "this ServiceAccount may create Deployments". It says
nothing about what those Deployments contain. In a real cluster
that gap is where the incidents live: someone deploys
`myapp:latest` on a Friday, the tag moves over the weekend, and on
Monday nobody can reproduce the running version. Someone forgets
resource limits, one pod eats the node, and three other services
fall over. Someone runs as root out of habit, and a container escape
becomes a host compromise.

An admission policy closes the gap once, for everyone. The developer
gets an immediate, readable rejection at `kubectl apply` time —
"image tag latest is not allowed" — instead of a post-mortem three
weeks later. The platform team stops reviewing YAML by hand. And
because the policy is a Kubernetes resource, it is versioned,
reviewed and rolled out like any other change.

Kyverno is the simplest way to get there. Policies are plain YAML,
the engine installs as a Deployment in the cluster, and it speaks
the same validating-webhook mechanism the API server already
supports. There is nothing to compile and no sidecar to inject.

## The policies in this exercise

All four live in `manifests/` as `ClusterPolicy` resources:

| Policy | Rule | What it stops |
| --- | --- | --- |
| `require-labels` | every Pod must carry `app` and `team` labels | Unlabelled workloads that break selectors, dashboards and cost reports |
| `block-latest-tag` | no container image may use the `latest` tag (or no tag at all) | Unreproducible deployments |
| `require-resource-limits` | every container must set CPU and memory limits | A single pod starving its neighbours |
| `require-non-root` | containers must run as a non-root user, with `runAsNonRoot` and `allowPrivilegeEscalation: false` | A container escape becoming a host compromise |

Each policy ships with the three matching namespaces excluded
(`kube-system`, `kyverno`, `local-path-storage`) so the platform
itself is never blocked by its own rules — a mistake every team
makes exactly once.

## How Kyverno enforces a policy

When you `kubectl apply` a Pod, the API server sends the object to
Kyverno's webhook before persisting it. Kyverno matches the request
against every policy, evaluates the rules, and answers allow or
deny. In `Enforce` mode a denial rejects the whole request and
`kubectl` prints the policy message. In `Audit` mode the request is
allowed but a `PolicyReport` records the violation, which is how you
roll a policy out safely: audit first, watch the reports, then flip
to enforce when the violations are gone.

Kyverno also generates reports for workloads that already exist.
`kubectl get policyreport -A` shows you every violation in the
cluster, including the ones that were admitted before the policy
existed. That is the audit trail you hand to a reviewer.

## Steps

### 1. Create the cluster

```bash
kind create cluster --name lab-admission --config manifests/kind-config.yaml
# or reuse an existing cluster and skip to step 2
```

### 2. Install Kyverno

```bash
./scripts/setup.sh
```

`setup.sh` installs Kyverno v1.13.2 from the official release
manifest, waits for the webhook and the background controller to
become ready, then applies the four policies and the good example
Deployment. The install takes a minute or two — the webhook has to
be up before the API server will accept any policy, so the script
waits for it explicitly.

### 3. Confirm the policies are active

```bash
kubectl get clusterpolicies
kubectl get pods -n kyverno
```

You should see all four policies listed. The `kyverno-admission-controller`
pod is the webhook the API server calls; `kyverno-background-controller`
is the one that writes policy reports for existing workloads.

### 4. Apply the good Deployment and watch it pass

```bash
kubectl apply -f manifests/05-good-deployment.yaml
kubectl get pods -n lab-admission
```

The good Deployment has labels, a pinned image tag, resource
limits, and runs as user 10001. It is admitted without a word.
Silence is the correct answer here.

### 5. Apply the bad Deployment and watch it fail

```bash
kubectl apply -f manifests/06-bad-deployment.yaml
```

The request is rejected, and the error message names the policy
and the rule that fired:

```
Error from server: admission webhook "validate.kyverno.svc-fail"
denied the request:

resource Deployment/lab-admission/bad-app was blocked due to the
following policies

require-resource-limits:
  require-limits: 'validation error: Every container must define CPU
  and memory limits. ...'

block-latest-tag:
  block-latest: 'validation error: Using the latest image tag is not
  allowed. Pin the image to a specific version. ...'
```

One request can violate several policies at once, and Kyverno
reports all of them. That is the whole point of failing fast at
the door: the developer fixes everything in one round trip.

### 6. Fix the bad Deployment yourself

Edit `manifests/06-bad-deployment.yaml`: pin the image to
`nginx:1.27`, add the `app` and `team` labels, set CPU and memory
limits, and run as a non-root user. Apply it again — this time it
goes through. The fastest way to learn a policy is to satisfy it.

### 7. Try Audit mode

```bash
kubectl patch clusterpolicy require-labels --type=merge \
  -p '{"spec":{"validationFailureAction":"Audit"}}'
kubectl apply -f manifests/06-bad-deployment.yaml
kubectl get policyreport -n lab-admission
```

With `Audit`, the workload is admitted and the violation shows up
in a PolicyReport instead. Flip the policy back when you are done:

```bash
kubectl patch clusterpolicy require-labels --type=merge \
  -p '{"spec":{"validationFailureAction":"Enforce"}}'
```

### 8. Run the checks

```bash
./scripts/test.sh
```

## Tasks

1. Write a fifth policy that requires every Pod to carry the
   annotation `owner` with a team email address, in `Audit` mode
   first. Check the PolicyReport, then flip it to `Enforce`.
2. Test the second rule in `block-latest-tag`: apply a Deployment
   with `image: nginx` (no tag at all) and confirm it is rejected
   even though the tag is not `latest`. Read the `image: "*:*"`
   pattern and work out why it catches this case.
3. Look at the generated reports: `kubectl get policyreport -A -o yaml`
   and find a violation for a workload that was admitted before the
   policies existed. Why is it in the report even though nothing
   was rejected?
4. Break the good Deployment on purpose in exactly one way — remove
   the memory limit — and read the rejection message. Which policy
   fired, and what does its message tell the developer to do?
5. Kyverno can also *mutate* requests, not just validate them.
   Add a mutate rule to `require-labels` that adds the label
   `team: platform` when it is missing, and test it with a Pod that
   has no `team` label.

## Cleanup

```bash
kind delete cluster --name lab-admission
# or, if you used an existing cluster:
# kubectl delete namespace lab-admission
# kubectl delete -f https://github.com/kyverno/kyverno/releases/download/v1.13.2/install.yaml
```

## Key takeaways

- Admission control is the last gate before etcd: RBAC decides who
  may ask, the webhook decides whether the request is acceptable.
- A policy that rejects with a clear message is a teaching tool,
  not a punishment — the developer learns the standard at apply
  time, not in a review three weeks later.
- Roll policies out in `Audit` first. The PolicyReport shows you
  the real violation count before you start blocking anyone's work.
- Exclude the platform namespaces from your own policies, or the
  first policy you ship will block the cluster from healing itself.
- Policies are Kubernetes resources: version them, review them,
  and roll them out like any other change. The enforcement layer is
  code, and it deserves the same rigour.
