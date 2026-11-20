# Exercise 24 — Kubernetes Pod Security

By default a pod runs as root, can escalate privileges, and can write
anywhere in its filesystem. That is the container equivalent of running
everything as administrator. This exercise shows how Pod Security
Standards and a hardened `securityContext` close those holes — and what
breaks when you turn them on.

## What you will learn

- The three Pod Security Standards levels — `privileged`, `baseline`,
  `restricted` — and how a namespace label enforces one of them
- What the admission controller actually rejects, and what the error
  looks like
- How to harden a pod with `securityContext`: non-root user, dropped
  capabilities, no privilege escalation, read-only root filesystem,
  seccomp
- Why a read-only root filesystem breaks apps that write to disk, and
  how `emptyDir` volumes fix that without weakening the policy

## Prerequisites

- A local cluster: `kind` (used here) or minikube
- `kubectl` configured against the cluster
- Exercise 04 (Kubernetes basics) completed

## Why pod security matters

Most container breakouts start from a pod that had more privilege than
it needed. A container running as root with the `SYS_ADMIN` capability
and a hostPath mount is one exploit away from owning the node. The
defaults do not protect you: Kubernetes happily schedules a privileged
root pod unless a policy says otherwise.

Pod Security Standards (PSS) are the built-in answer. They are enforced
by the Pod Security admission controller, which reads labels on the
namespace:

- `privileged` — no restrictions at all.
- `baseline` — blocks the known-bad things: host namespaces, hostPath
  volumes, privileged containers, host ports.
- `restricted` — everything in baseline, plus: must run as a non-root
  user, no privilege escalation, read-only root filesystem, drop all
  capabilities, seccomp profile required.

The levels are enforced per namespace with labels like this:

```yaml
pod-security.kubernetes.io/enforce: restricted
pod-security.kubernetes.io/enforce-version: latest
```

`enforce` rejects violating pods. `audit` only logs them, and `warn`
only warns — useful when you are rolling a policy out to an existing
namespace and want to see what would break before you break it.

## Steps

### 1. Create the cluster

```bash
./scripts/setup.sh
```

This creates a kind cluster (`security-lab`) and two namespaces:
`security-lab` (enforced `restricted`) and `security-lab-baseline`
(enforced `baseline`). It then tries to deploy the insecure pod into
the restricted namespace — and fails on purpose.

### 2. Read the rejection

The setup script prints the admission error. It looks like this:

```
Error from server (Forbidden): error when creating "01-insecure-pod.yaml":
pods "insecure" is forbidden: violates PodSecurity "restricted:latest":
privileged (container "app" must not set securityContext.privileged=true),
runAsUser=0 (container "app" must not set runAsUser=0),
hostPath volumes (volume "host-etc"), allowPrivilegeEscalation != false
...
```

Every line names one violation and the rule it breaks. That is the
whole point of the exercise: the policy tells you exactly what to fix.

### 3. See what baseline still allows

```bash
kubectl get pod insecure -n security-lab-baseline
```

The pod in the baseline namespace is the insecure one with the host
access stripped out — no privileged flag, no hostPath, no extra
capabilities. What is left still runs as root and can escalate
privileges, and baseline accepts that. The contrast is the lesson:
`baseline` keeps you out of the worst trouble, `restricted` is what a
real production namespace should enforce.

### 4. Inspect the hardened pod

```bash
kubectl get pod secure -n security-lab \
  -o jsonpath='{.spec.containers[0].securityContext}' | python3 -m json.tool
```

The secure pod sets, at pod level and container level:

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  seccompProfile:
    type: RuntimeDefault
  # container level:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop: ["ALL"]
```

- `runAsNonRoot` makes the kubelet refuse to start the container if
  the image would run as root. `runAsUser: 1000` pins the UID.
- `allowPrivilegeEscalation: false` stops setuid binaries and
  `CAP_SETUID` tricks from gaining root at runtime.
- `capabilities.drop: ["ALL"]` removes every Linux capability,
  including the default set Docker/Kubernetes normally grants
  (`CHOWN`, `SETUID`, `NET_RAW`, ...). Add back only what the app
  provably needs, e.g. `NET_BIND_SERVICE` if it must bind a port
  below 1024.
- `readOnlyRootFilesystem: true` makes the container filesystem
  read-only. An attacker who gets in cannot write a binary or modify
  config. The app's legitimate writes go to `emptyDir` volumes.
- `seccompProfile.type: RuntimeDefault` applies the container
  runtime's default syscall filter, blocking dangerous syscalls.

### 5. Check the hardened nginx deployment

```bash
kubectl get pods -n security-lab -l app=secure-web
kubectl exec -n security-lab deploy/secure-web -- id
kubectl exec -n security-lab deploy/secure-web -- touch /etc/passwd
```

`id` shows `uid=101(nginx)`. The `touch` fails with a read-only
filesystem error. The deployment uses the
`nginxinc/nginx-unprivileged` image, which listens on port 8080
instead of 80 — a non-root user cannot bind ports below 1024, so a
hardened web server must listen on an unprivileged port.

The deployment also mounts `emptyDir` volumes at `/tmp`,
`/var/cache/nginx` and `/var/run`, because nginx needs writable
scratch space even though its root filesystem is read-only:

```yaml
volumeMounts:
  - name: tmp
    mountPath: /tmp
  - name: cache
    mountPath: /var/cache/nginx
  - name: run
    mountPath: /var/run
volumes:
  - name: tmp
    emptyDir: {}
```

An `emptyDir` is wiped when the pod dies, so nothing sensitive can
persist there — it is scratch space, not storage.

### 6. Run the checks

```bash
./scripts/test.sh
```

This verifies the insecure pod is rejected in the restricted
namespace, runs in the baseline namespace, the secure pod and
deployment are running with the expected `securityContext`, and the
read-only filesystem really is read-only.

## Tasks

1. Change the secure pod's `runAsUser` to `0` and re-apply. What does
   the admission controller say? (It refuses: `runAsUser=0` violates
   `restricted`. The policy is enforced at admission time, not
   runtime — the pod never starts.)
2. Remove `readOnlyRootFilesystem` from the secure pod and try writing
   a file inside it with `kubectl exec ... touch /tmp/test`. Then put
   the setting back and try again. Which behaviour do you want in
   production?
3. Add the `NET_RAW` capability back to the secure pod
   (`capabilities: {add: ["NET_RAW"], drop: ["ALL"]}`) and apply it.
   Does `restricted` allow that? (No — restricted allows no added
   capabilities at all. If the app really needs one, the namespace
   has to drop to `baseline`.)
4. Set `pod-security.kubernetes.io/warn: restricted` on the baseline
   namespace and re-apply the insecure pod. What warning do you get,
   and does the pod still start? (It starts, with a warning. `warn`
   is how you preview a policy before enforcing it.)
5. Look at a workload you run in real life and list which of the five
   hardening settings it would break. That list is your migration
   plan for moving the namespace to `restricted`.

## Cleanup

```bash
kind delete cluster --name security-lab
```

## Key takeaways

- Kubernetes defaults let a pod run as root with full capabilities.
  Nothing stops that unless a policy does.
- Pod Security Standards are enforced per namespace by a label:
  `privileged`, `baseline`, `restricted`. Enforce `restricted` on
  production namespaces.
- Harden every pod: non-root user, drop all capabilities, no
  privilege escalation, read-only root filesystem, seccomp
  RuntimeDefault.
- A read-only root filesystem needs `emptyDir` volumes for the app's
  scratch space, and an unprivileged port (above 1024) for a
  non-root web server.
- Roll a policy out with `warn` and `audit` first, so you find out
  what breaks before enforcement breaks it for you.
