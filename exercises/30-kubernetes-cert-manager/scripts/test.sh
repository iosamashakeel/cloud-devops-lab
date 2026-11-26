#!/usr/bin/env bash
# Verify the cert-manager lab: issuers Ready, certificates Ready,
# the leaf Secret holds a valid certificate for web.lab.local.
set -euo pipefail

NS="lab-certs"
PASS=0
FAIL=0

check() {
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then
    echo "PASS: $desc"; PASS=$((PASS + 1))
  else
    echo "FAIL: $desc"; FAIL=$((FAIL + 1))
  fi
}

check "selfsigned-issuer is Ready" \
  kubectl wait --for=condition=Ready clusterissuer/selfsigned-issuer --timeout=30s
check "lab-ca-issuer is Ready" \
  kubectl wait --for=condition=Ready clusterissuer/lab-ca-issuer --timeout=30s
check "CA certificate lab-ca is Ready" \
  kubectl wait -n "$NS" --for=condition=Ready certificate/lab-ca --timeout=30s
check "leaf certificate web-tls is Ready" \
  kubectl wait -n "$NS" --for=condition=Ready certificate/web-tls --timeout=60s
check "Secret web-tls exists with tls.crt and tls.key" \
  bash -c "kubectl get secret web-tls -n $NS -o jsonpath='{.data.tls\.crt}' | grep -q . && kubectl get secret web-tls -n $NS -o jsonpath='{.data.tls\.key}' | grep -q ."

# Decode the issued certificate and check its contents.
CERT_TMP="$(mktemp)"
kubectl get secret web-tls -n "$NS" -o jsonpath='{.data.tls\.crt}' | base64 -d > "$CERT_TMP"
trap 'rm -f "$CERT_TMP"' EXIT

check "certificate is for web.lab.local" \
  openssl x509 -in "$CERT_TMP" -noout -subject -ext subjectAltName | grep -q "web.lab.local"
check "certificate includes www.web.lab.local" \
  openssl x509 -in "$CERT_TMP" -noout -ext subjectAltName | grep -q "www.web.lab.local"
check "certificate is issued by the lab CA" \
  openssl x509 -in "$CERT_TMP" -noout -issuer | grep -q "lab-ca"
check "certificate is not expired" \
  openssl x509 -in "$CERT_TMP" -noout -checkend 0

check "Ingress web references the web-tls Secret" \
  bash -c "kubectl get ingress web -n $NS -o jsonpath='{.spec.tls[0].secretName}' | grep -qx 'web-tls'"

echo
echo "Result: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
