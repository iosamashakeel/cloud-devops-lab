#!/usr/bin/env bash
# Checks for Exercise 29 — run after ./scripts/setup.sh.
set -uo pipefail

NS=lab-mesh
PASS=0
FAIL=0

check() {
  local name="$1"; shift
  if "$@" >/dev/null 2>&1; then
    echo "PASS: $name"; PASS=$((PASS + 1))
  else
    echo "FAIL: $name"; FAIL=$((FAIL + 1))
  fi
}

# 1. Linkerd itself is healthy.
check "linkerd check passes" linkerd check

# 2. The control plane is up.
check "linkerd destination is available" \
  kubectl wait --for=condition=available deployment/linkerd-destination -n linkerd --timeout=60s
check "linkerd identity is available" \
  kubectl wait --for=condition=available deployment/linkerd-identity -n linkerd --timeout=60s

# 3. Both app versions are up.
check "web-v1 is available" \
  kubectl wait --for=condition=available deployment/web-v1 -n "$NS" --timeout=60s
check "web-v2 is available" \
  kubectl wait --for=condition=available deployment/web-v2 -n "$NS" --timeout=60s

# 4. Every web pod has a proxy sidecar (2/2 containers).
check "web pods have the linkerd proxy injected" \
  bash -c "kubectl get pods -n $NS -l app=web -o jsonpath='{.items[*].status.containerStatuses[*].ready}' | grep -q 'true true true true true true'"

# 5. The mesh configuration objects exist.
check "ServiceProfile exists" \
  kubectl get serviceprofile web.lab-mesh.svc.cluster.local -n "$NS"
check "TrafficSplit exists" \
  kubectl get trafficsplit web-canary -n "$NS"

# 6. The service answers through the mesh.
check "web service answers" \
  bash -c "kubectl run curl-test --rm -i --image=curlimages/curl --restart=Never -q -- curl -sf http://web.$NS/"

# 7. The canary actually receives traffic: 40 requests should hit
# both versions (90/10 split, so v2 shows up a few times).
check "traffic split sends requests to both versions" \
  bash -c "
    out=\$(kubectl run curl-split --rm -i --image=curlimages/curl --restart=Never -q -- \
      sh -c 'for i in \$(seq 1 40); do curl -s http://web.$NS/; echo; done')
    echo \"\$out\" | grep -q '\"version\": \"v1\"' && echo \"\$out\" | grep -q '\"version\": \"v2\"'
  "

# 8. The failure classification has something to classify: the
# unstable endpoint returns 500s some of the time.
check "unstable endpoint returns a mix of 200 and 500" \
  bash -c "
    out=\$(kubectl run curl-flaky --rm -i --image=curlimages/curl --restart=Never -q -- \
      sh -c 'for i in \$(seq 1 20); do curl -s -o /dev/null -w \"%{http_code}\n\" http://web.$NS/unstable; done')
    echo \"\$out\" | grep -q '^200$' && echo \"\$out\" | grep -q '^500$'
  "

echo
echo "$PASS passed, $FAIL failed."
[ "$FAIL" -eq 0 ]
