#!/usr/bin/env python3
"""A tiny Kubernetes operator for the WebApp custom resource.

Polls the API server for WebApp resources and reconciles each one
into a Deployment, a Service and a ConfigMap. Standard library only;
kubectl does all the API talking.
"""
import json
import subprocess
import sys
import time

MANAGED_BY = "webapp-operator"
INTERVAL = 10  # seconds between reconcile passes


def kubectl(*args, stdin=None):
    cmd = ["kubectl"] + list(args)
    result = subprocess.run(cmd, input=stdin, capture_output=True, text=True)
    return result


def log(message):
    print(f"[operator] {message}", flush=True)


def list_webapps():
    result = kubectl("get", "webapps", "-A", "-o", "json")
    if result.returncode != 0:
        log(f"failed to list webapps: {result.stderr.strip()}")
        return []
    return json.loads(result.stdout).get("items", [])


def apply_manifest(manifest):
    result = kubectl("apply", "-f", "-", stdin=manifest)
    if result.returncode != 0:
        log(f"apply failed: {result.stderr.strip()}")
        return False
    return True


def deployment_yaml(name, namespace, spec):
    return f"""apiVersion: apps/v1
kind: Deployment
metadata:
  name: {name}
  namespace: {namespace}
  labels:
    app: {name}
    app.kubernetes.io/managed-by: {MANAGED_BY}
spec:
  replicas: {spec.get("replicas", 1)}
  selector:
    matchLabels:
      app: {name}
  template:
    metadata:
      labels:
        app: {name}
    spec:
      containers:
        - name: web
          image: {spec["image"]}
          ports:
            - containerPort: 80
          volumeMounts:
            - name: message
              mountPath: /usr/share/nginx/html
              readOnly: true
      volumes:
        - name: message
          configMap:
            name: {name}
"""


def service_yaml(name, namespace):
    return f"""apiVersion: v1
kind: Service
metadata:
  name: {name}
  namespace: {namespace}
  labels:
    app: {name}
    app.kubernetes.io/managed-by: {MANAGED_BY}
spec:
  selector:
    app: {name}
  ports:
    - port: 80
      targetPort: 80
"""


def configmap_yaml(name, namespace, message):
    safe = message.replace('"', '\\"')
    return f"""apiVersion: v1
kind: ConfigMap
metadata:
  name: {name}
  namespace: {namespace}
  labels:
    app: {name}
    app.kubernetes.io/managed-by: {MANAGED_BY}
data:
  index.html: "<h1>{safe}</h1>\\n"
"""


def ready_replicas(name, namespace):
    result = kubectl(
        "get", "deployment", name, "-n", namespace,
        "-o", "jsonpath={.status.readyReplicas}",
    )
    if result.returncode != 0 or not result.stdout.strip():
        return 0
    return int(result.stdout.strip())


def reconcile(webapp):
    meta = webapp["metadata"]
    name = meta["name"]
    namespace = meta["namespace"]
    spec = webapp.get("spec", {})
    generation = meta.get("generation", 0)

    log(f"reconciling WebApp {namespace}/{name} "
        f"(image={spec.get('image')}, replicas={spec.get('replicas', 1)})")

    apply_manifest(configmap_yaml(name, namespace, spec.get("message", "")))
    apply_manifest(deployment_yaml(name, namespace, spec))
    apply_manifest(service_yaml(name, namespace))

    ready = ready_replicas(name, namespace)
    status = json.dumps({
        "status": {
            "readyReplicas": ready,
            "observedGeneration": generation,
            "message": spec.get("message", ""),
        }
    })
    result = kubectl(
        "patch", "webapp", name, "-n", namespace,
        "--subresource=status", "--type=merge", "-p", status,
    )
    if result.returncode != 0:
        log(f"status patch failed for {name}: {result.stderr.strip()}")
    else:
        log(f"{name}: {ready} ready replica(s)")


def garbage_collect(seen):
    """Delete operator-owned workloads whose WebApp no longer exists."""
    for kind in ("deployment", "service", "configmap"):
        result = kubectl(
            "get", kind, "-A",
            "-l", f"app.kubernetes.io/managed-by={MANAGED_BY}",
            "-o", "json",
        )
        if result.returncode != 0:
            continue
        for item in json.loads(result.stdout).get("items", []):
            key = (item["kind"], item["metadata"]["namespace"],
                   item["metadata"]["name"])
            if key not in seen:
                log(f"cleaning up orphan {key[0]} {key[1]}/{key[2]}")
                kubectl("delete", kind, key[2], "-n", key[1])


def main():
    log("webapp-operator starting (poll interval: "
        f"{INTERVAL}s, managed-by={MANAGED_BY})")
    while True:
        try:
            seen = set()
            for webapp in list_webapps():
                meta = webapp["metadata"]
                name = meta["name"]
                namespace = meta["namespace"]
                seen.add(("Deployment", namespace, name))
                seen.add(("Service", namespace, name))
                seen.add(("ConfigMap", namespace, name))
                reconcile(webapp)
            garbage_collect(seen)
        except Exception as exc:  # keep the loop alive on errors
            log(f"reconcile error: {exc}")
        time.sleep(INTERVAL)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(0)
