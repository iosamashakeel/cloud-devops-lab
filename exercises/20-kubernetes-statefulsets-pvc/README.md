# Exercise 20: Kubernetes StatefulSets and Persistent Volumes

A Deployment is great for stateless apps — any pod can die and a new one
takes its place without anyone noticing. But a database, a message queue,
or anything that keeps data on disk is different: when its pod comes back,
it has to be the *same* pod, with the *same* data. That is what a
StatefulSet is for.

## Learning goals

- Understand when a StatefulSet is the right choice and when a Deployment is
- See how a headless Service gives each pod a stable DNS name
- Give each pod its own PersistentVolumeClaim with `volumeClaimTemplates`
- Prove that data survives a pod being deleted and recreated
- Learn how StatefulSets roll out one pod at a time, in order

## Prerequisites

- Docker running
- `kubectl` and `kind` installed
- Exercise 04 (Kubernetes basics) completed

> This lab uses the default StorageClass that kind ships with, so no extra
> storage setup is needed. On a real cluster your admin provides the
> StorageClass (for example AWS EBS or a local-path provisioner).

## Steps

### 1. Create the cluster and deploy the StatefulSet

```bash
./scripts/setup.sh
```

This creates a kind cluster named `stateful-lab` and applies the manifests.
It deploys a StatefulSet with three nginx pods. Each pod gets its own
PersistentVolume, and an init container writes a small page into that volume
with the pod's name and a counter on it.

### 2. Look at the pods

```bash
kubectl -n stateful-lab get pods -o wide
kubectl -n stateful-lab get pvc
kubectl -n stateful-lab get sts
```

Notice three things:

- The pods are named `web-0`, `web-1`, `web-2` — stable names, created in
  order, one after the other.
- Each pod has its own PVC: `data-web-0`, `data-web-1`, `data-web-2`.
- The Service `web` is headless (`clusterIP: None`). That is what gives
  each pod its own DNS name, like `web-0.web.stateful-lab.svc.cluster.local`.

### 3. Check that each pod has its own data

```bash
kubectl -n stateful-lab exec web-0 -- cat /usr/share/nginx/html/index.html
kubectl -n stateful-lab exec web-1 -- cat /usr/share/nginx/html/index.html
```

Each page says which pod wrote it, and the counter file on each pod
(`data/counter.txt`) shows how many times that pod has started.

### 4. Prove the data survives a restart

Delete a pod and watch it come back with the same name and the same data:

```bash
kubectl -n stateful-lab delete pod web-1
kubectl -n stateful-lab get pods -w   # wait until web-1 is Running again
kubectl -n stateful-lab exec web-1 -- cat /data/counter.txt
```

The counter now says `2`. If the pod had been given a fresh, empty volume
it would say `1` again. The new `web-1` got its old volume back — the data
outlived the pod. Try the same thing with a Deployment pod and the file is
gone.

### 5. Run the checks

```bash
./scripts/test.sh
```

This verifies the pods, the PVCs, the per-pod files, and the restart test
above, automatically.

## Try it yourself

1. Scale the StatefulSet to 5 replicas and watch the new pods get new PVCs:
   `kubectl -n stateful-lab scale sts web --replicas=5`. Then scale back
   down to 3 — notice the PVCs for `web-3` and `web-4` are *not* deleted.
   StatefulSets never delete a pod's volume for you, on purpose. Clean them
   up by hand when you are sure the data is not needed.
2. Look at the rollout behaviour: change the nginx image tag in
   `manifests/02-statefulset.yaml` and apply it. The pods update one at a
   time, in reverse order (`web-2`, then `web-1`, then `web-0`), and each
   one is ready before the next starts.
3. Run `kubectl -n stateful-lab get pvc` after deleting the whole
   StatefulSet. The PVCs are still there. That is the safety net — and the
   reason you should always delete leftover PVCs explicitly.

## Cleanup

```bash
kind delete cluster --name stateful-lab
```

## Key ideas

- **StatefulSet** = stable pod name, stable network identity, stable storage.
  Use it for databases, queues, and anything where "which instance am I?"
  matters.
- **Deployment** = interchangeable pods, no identity, no local state. Use it
  for everything else.
- **volumeClaimTemplates** creates one PVC per pod, from the same template,
  named after the pod. The PVC follows the pod through restarts.
- **Headless Service** (`clusterIP: None`) turns the Service into plain DNS
  records, one per pod, instead of a single load-balanced address.
- Deleting a StatefulSet or scaling it down never deletes its PVCs. Storage
  is deleted only when you delete the PVC yourself.
