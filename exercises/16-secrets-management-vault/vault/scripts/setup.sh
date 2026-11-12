#!/usr/bin/env bash
# Write the demo secret into Vault (KV v2) and show how to read it back.
# Run from the exercise root after `docker compose up -d`.
set -euo pipefail

export VAULT_ADDR="${VAULT_ADDR:-http://localhost:8200}"
export VAULT_TOKEN="${VAULT_TOKEN:-root}"

echo "Writing secret/demo-app ..."
curl -s -H "X-Vault-Token: $VAULT_TOKEN" -X POST \
  -d '{"data": {"db_password": "s3cret-db-pass", "api_key": "demo-key-123"}}' \
  "$VAULT_ADDR/v1/secret/data/demo-app" > /dev/null

echo "Reading it back ..."
curl -s -H "X-Vault-Token: $VAULT_TOKEN" \
  "$VAULT_ADDR/v1/secret/data/demo-app" | python3 -m json.tool | grep -A4 '"data"'

echo "Done. The app can now fetch this secret with its own token."
