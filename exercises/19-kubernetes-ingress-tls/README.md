# Exercise 19: Kubernetes Ingress with NGINX and TLS

A Service gives your app an address inside the cluster. An Ingress gives it
an address the outside world can reach — one entry point, with host and path
routing, TLS termination, and redirects handled for you.

## Learning goals

- Understand what an Ingress controller does and why a cluster needs one
- Install the NGINX Ingress controller on a local kind cluster
- Route traffic by host and by path to two different Services
- Terminate TLS at the Ingress with a self-signed certificate
- Force HTTP to redirect to HTTPS

## Prerequisites

- Docker running
- `kubectl`, `kind`, `curl`, and `openssl` installed
- Exercise 04 (Kubernetes basics) completed

> Why kind with port mappings? A kind cluster runs inside a Docker
> container, so ports 80 and 443 are not reachable from your machine unless
> the cluster config maps them through. The config in `scripts/` does that.

## Steps

### 1. Create the cluster and install the Ingress controller

```bash
./scripts/setup.sh
```

This creates a kind cluster named `ingress-lab` with ports 80 and 443 mapped
to your machine, installs the NGINX Ingress controller, creates a self-signed
TLS certificate for `demo.local`, and deploys the demo app. It takes a couple
of minutes on first run.

### 2. Point the hostname at your machine

The Ingress answers for the host `demo.local`. Add it to your hosts file:

```bash
echo "127.0.0.1 demo.local" | sudo tee -a /etc/hosts
```

### 3. Try the routes

```bash
curl http://demo.local/        # redirects to https
curl -k https://demo.local/     # the web frontend
curl -k https://demo.local/api   # the api backend
curl -k https://demo.local/unknown # 404 from the Ingress, not from an app
```

The `-k` flag tells curl to accept the self-signed certificate. In a real
setup you would use a certificate from a trusted issuer instead.

### 4. Run the checks

```bash
./scripts/test.sh
```

This verifies the HTTP-to-HTTPS redirect, both routes, TLS, and the 404 for
an unknown path.

## What to look at

- `demo-app/workloads.yaml` — two Deployments and two Services: `web`
  (a static page) and `api` (a tiny JSON responder).
- `ingress/00-ingress.yaml` — the web route: `/` goes to `web`. TLS is
  terminated here, so the pods only ever see plain HTTP.
- `ingress/01-ingress-api.yaml` — the api route, in its own Ingress so the
  `rewrite-target` only applies here: `/api` is rewritten to `/index.json`,
  the one file the api backend serves.
- `scripts/setup.sh` — generates the certificate with `openssl` and stores
  it as a `kubernetes.io/tls` Secret before applying the Ingress.

## Tasks

1. Add a third route, `/blog`, pointing at a new Service. What happens if
   two rules match the same path prefix?
2. Change the Ingress annotation so HTTP is served as well as HTTPS instead
   of redirecting. When would you want that?
3. Break the TLS Secret on purpose (delete it) and watch what `curl -k`
   returns. Then re-create it with the commands from `setup.sh`.
4. Look at the Ingress controller logs
   (`kubectl -n ingress-nginx logs deploy/ingress-nginx-controller`) while
   you send a request. Find your request in the access log.

## Cleanup

```bash
kind delete cluster --name ingress-lab
```
