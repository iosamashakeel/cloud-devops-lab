# Exercise 30 — Kubernetes TLS Automation with cert-manager

Exercise 19 gave you TLS on an Ingress with a hand-made,
self-signed certificate. It worked, but somebody had to create the
certificate, remember its expiry date, and renew it before it
lapsed. In a real cluster that somebody is on holiday the week the
certificate expires, and on Monday morning every service behind
that Ingress is down.

cert-manager automates the whole lifecycle: it watches
`Certificate` resources, talks to an issuer (a local CA here, or
Let's Encrypt in production), issues the certificate, stores it in
a Secret, and renews it before expiry — without anyone touching
anything. This exercise builds a two-level issuer chain, issues a
certificate for a demo web app, and wires it into an Ingress.

## What you will learn

- How cert-manager turns a `Certificate` resource into a Secret
  containing a real TLS certificate
- The difference between an `Issuer` (namespaced) and a
  `ClusterIssuer` (cluster-wide), and when to use each
- How to build a small CA chain: a self-signed root that signs a
  CA, which then issues leaf certificates
- How an Ingress picks up a certificate from a Secret with the
  `tls` block, and how to verify the certificate is valid
- How renewal works, and how to force it early with
  `cmctl renew`

## Prerequisites

- A local cluster: `kind` (used here) or minikube
- `kubectl` configured against the cluster
- Exercise 19 (Ingress with TLS) completed — this exercise
  replaces the hand-made certificate from that one

## Why automated certificates matter

A certificate has two failure modes, and both are silent until
they are not. The first is expiry: a 90-day Let's Encrypt
certificate lapses, browsers refuse the connection, and the
outage looks like a network problem until someone checks the
dates. The second is a manual process: the certificate lives in
a wiki page, the renewal runbook is three years old, and the
person who knows how it works left the team.

cert-manager removes the human from both. A `Certificate`
resource declares what you want — the DNS names, the issuer, the
renewal window — and the controller keeps the Secret current. It
renews at two-thirds of the certificate lifetime by default, so a
90-day certificate is replaced after 60 days, long before anyone
notices. The Secret is the single source of truth: the Ingress
reads it, the application never sees it, and rotation is a Secret
update, not a redeploy.

The issuer chain in this exercise mirrors production. A
self-signed `ClusterIssuer` signs a CA certificate. A second
`ClusterIssuer` uses that CA to sign leaf certificates. Your
applications only ever talk to the CA issuer, so swapping the root
later — moving to Let's Encrypt, for example — means changing one
resource, not every application.

## The resources in this exercise

| File | Resource | Purpose |
| --- | --- | --- |
| `00-namespace.yaml` | Namespace `lab-certs` | Everything in this exercise lives here |
| `01-selfsigned-issuer.yaml` | ClusterIssuer `selfsigned-issuer` | Signs the CA certificate |
| `02-ca-issuer.yaml` | Certificate + ClusterIssuer `lab-ca-issuer` | The CA cert, and the issuer that uses it |
| `03-certificate.yaml` | Certificate `web-tls` | The leaf certificate for `web.lab.local` |
| `04-ingress.yaml` | Ingress `web` | Serves the app over HTTPS with the issued cert |
| `05-web-deployment.yaml` | Deployment + Service `web` | A tiny nginx app to serve |

The leaf certificate is valid for `web.lab.local` and
`www.web.lab.local`, lasts 90 days, and is renewed automatically
after 60 days.

## Steps

### 1. Create the cluster

```bash
kind create cluster --name lab-certs --config manifests/kind-config.yaml
# or reuse an existing cluster and skip to step 2
```

### 2. Install cert-manager and the issuers

```bash
./scripts/setup.sh
```

`setup.sh` installs cert-manager v1.16.2 from the official
release manifest, waits for the controller and webhook to become
ready, then applies the namespace, the two issuers, the CA
certificate and the demo web app. The CA certificate takes a few
seconds to become Ready — the script waits for it before moving
on, because the leaf certificate cannot be issued until the CA
exists.

### 3. Check the issuer chain

```bash
kubectl get clusterissuers
kubectl get certificate -n lab-certs
```

You should see both issuers Ready, and the CA certificate
`lab-ca` Ready. The self-signed issuer exists only to bootstrap
the CA — after that, nothing uses it directly.

### 4. Issue the leaf certificate

```bash
kubectl apply -f manifests/03-certificate.yaml
kubectl get certificate web-tls -n lab-certs -w
```

Watch the certificate move from issuing to Ready. cert-manager
creates a `CertificateRequest`, the CA issuer signs it, and the
result lands in the Secret `web-tls` in the same namespace.

### 5. Inspect the certificate

```bash
kubectl get secret web-tls -n lab-certs -o jsonpath='{.data.tls\.crt}' \
  | base64 -d | openssl x509 -noout -subject -issuer -dates -ext subjectAltName
```

Check the subject, the issuer (your lab CA, not a self-signed
leaf), the dates, and the SAN entries. This is the certificate
your Ingress will serve.

### 6. Expose the app over HTTPS

```bash
kubectl apply -f manifests/04-ingress.yaml
```

The Ingress references the `web-tls` Secret in its `tls` block.
Add `127.0.0.1 web.lab.local` to `/etc/hosts` and reach it
through the ingress controller's NodePort (see the note in
`manifests/04-ingress.yaml` for the port):

```bash
curl -k https://web.lab.local:<nodeport>/
```

The `-k` flag is there because the CA is yours, not a public one
— your browser and curl do not trust it yet. That is expected:
in production the same flow uses Let's Encrypt, and the `-k`
disappears.

### 7. Run the checks

```bash
./scripts/test.sh
```

## Tasks

1. Force an early renewal and watch it happen: install `cmctl`
   (`go install` or the release binary) and run
   `cmctl renew -n lab-certs web-tls`. Check the Secret's
   `tls.crt` before and after — the serial number changes, the
   Ingress keeps serving without a restart.
2. Add a second DNS name to the certificate (for example
   `api.lab.local`), apply it, and confirm cert-manager issues a
   new certificate with both names in the SAN list.
3. Break the chain on purpose: delete the CA Secret
   `lab-ca` and watch what happens to the leaf certificate.
   Restore it with `kubectl apply -f manifests/02-ca-issuer.yaml`
   and explain why the leaf recovered (or did not) without you
   re-applying it.
4. Switch the leaf certificate to a 7-day duration with
   `duration: 168h` and `renewBefore: 48h`. What does that do to
   the renewal schedule, and why would you want a short-lived
   certificate in production?
5. Read the cert-manager docs on the ACME issuer and sketch the
   changes you would make to `02-ca-issuer.yaml` to issue a real
   Let's Encrypt certificate for a domain you own. What changes,
   what stays the same, and what new resource (a solver) do you
   need?

## Cleanup

```bash
kind delete cluster --name lab-certs
# or, if you used an existing cluster:
# kubectl delete namespace lab-certs
# kubectl delete clusterissuer selfsigned-issuer lab-ca-issuer
# kubectl delete -f https://github.com/cert-manager/cert-manager/releases/download/v1.16.2/cert-manager.yaml
```

## Key takeaways

- A certificate is a lifecycle, not a file: issuance, storage,
  renewal and expiry all need owning, and cert-manager owns all
  four from one declarative resource.
- The Secret is the contract between cert-manager and everything
  else. The Ingress does not know or care who issued the
  certificate — it just reads the Secret, so rotation is free.
- Build your issuer chain in layers: a root that signs a CA, a CA
  that signs leaves. Swapping the root later is one resource
  change, not a migration.
- Renew early, not on time. Two-thirds of lifetime is the default
  for a reason: it leaves room for the issuer to be down, the
  network to fail, and a human to notice.
- Self-signed is fine for a lab and wrong for production. The
  flow is identical either way — only the issuer changes — which
  is the whole point of doing it this way.
