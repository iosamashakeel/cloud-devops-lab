#!/usr/bin/env bash
# Verify the backend has two Endpoints, the ClusterIP Service resolves
# to a single address, the headless Service resolves to the pod IPs,
# the debug pod can reach the backend by name, and the NodePort answers
# from the host.
set -euo pipefail

NS=discovery-lab
FAIL=0

check() {
  if [ "$1" = "0" ]; then
    echo "PASS: $2"
  else
    echo "FAIL: $2"
    FAIL=1
  fi
}

# 1. Backend deployment is ready with 2 replicas.
kubectl rollout status deployment/backend -n "$NS" --timeout=180s >/dev/null 2>&1
check "$?" "backend deployment ready"

# 2. The backend Service has exactly 2 Endpoints.
ENDPOINTS=$(kubectl get endpoints backend -n "$NS" \
  -o jsonpath='{.subsets[0].addresses[*].ip}' 2>/dev/null)
COUNT=$(echo "$ENDPOINTS" | wc -w)
[ "$COUNT" = "2" ]
check "$?" "backend Service has 2 Endpoints (got $COUNT: ${ENDPOINTS:-none})"

# 3. The backend Service has a ClusterIP.
CLUSTER_IP=$(kubectl get svc backend -n "$NS" \
  -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
[ -n "$CLUSTER_IP" ] && [ "$CLUSTER_IP" != "None" ]
check "$?" "backend Service has a ClusterIP (got '${CLUSTER_IP:-none}')"

# 4. DNS: backend resolves to the ClusterIP from inside the cluster.
kubectl rollout status deployment/debug -n "$NS" --timeout=120s >/dev/null 2>&1
RESOLVED=$(kubectl exec -n "$NS" deploy/debug -- \
  nslookup backend 2>/dev/null | awk '/^Address: /{print $2}' | tail -1)
[ "$RESOLVED" = "$CLUSTER_IP" ]
check "$?" "backend resolves to its ClusterIP (got '${RESOLVED:-none}')"

# 5. DNS: backend-headless resolves to both pod IPs.
HEADLESS_IPS=$(kubectl exec -n "$NS" deploy/debug -- \
  nslookup backend-headless 2>/dev/null | awk '/^Address: /{print $2}' | sort)
HEADLESS_COUNT=$(echo "$HEADLESS_IPS" | grep -c . || true)
[ "$HEADLESS_COUNT" = "2" ]
check "$?" "backend-headless resolves to 2 pod IPs (got $HEADLESS_COUNT)"

# 6. The debug pod reaches the backend by name and sees both replicas.
SEEN=$(kubectl exec -n "$NS" deploy/debug -- \
  sh -c 'for i in $(seq 1 10); do curl -s --max-time 5 http://backend:8080/; done' \
  2>/dev/null | sort -u | wc -l)
[ "$SEEN" = "2" ]
check "$?" "repeated curls to backend hit both replicas (saw $SEEN distinct hostnames)"

# 7. The NodePort answers from the host.
NODEPORT_BODY=$(curl -s --max-time 5 http://localhost:30080/ 2>/dev/null || true)
echo "$NODEPORT_BODY" | grep -q "^hello from backend-"
check "$?" "NodePort answers from the host (got '${NODEPORT_BODY:-no response}')"

if [ "$FAIL" = "0" ]; then
  echo "All checks passed."
else
  echo "Some checks failed." >&2
  exit 1
fi
