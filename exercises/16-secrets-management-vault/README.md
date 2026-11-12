# Exercise 16: Secrets Management with HashiCorp Vault

## What you will learn

- Why secrets do not belong in code, environment files, or container images
- How Vault stores secrets in a key-value engine and hands them out with short-lived tokens
- How to write a least-privilege policy so an app can read exactly one secret path
- How an app fetches a secret from Vault at runtime instead of reading it from disk

## Prerequisites

- Docker and Docker Compose (see exercise 01)
- `curl` and `jq` on your machine
- About 30 minutes

## Setup

```bash
cd exercises/16-secrets-management-vault
docker compose up -d
```

This starts Vault in **dev mode** with a known root token (`root`) and the demo app.
Dev mode is for learning only: secrets live in memory and nothing is sealed.

## Steps

### 1. Check Vault is running

```bash
curl -s http://localhost:8200/v1/sys/health | jq
docker compose logs vault | tail -5
```

### 2. Write a secret

```bash
export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=root

vault kv put secret/demo-app db_password='s3cret-db-pass' api_key='demo-key-123'
vault kv get secret/demo-app
```

No Vault CLI installed? Use the HTTP API instead:

```bash
curl -s -H "X-Vault-Token: root" -X POST \
  -d '{"data": {"db_password": "s3cret-db-pass", "api_key": "demo-key-123"}}' \
  http://localhost:8200/v1/secret/data/demo-app | jq
```

Or run the script that does it for you:

```bash
bash vault/scripts/setup.sh
```

### 3. Create a least-privilege policy and token

```bash
vault policy write demo-app vault/policies/app-policy.hcl
vault token create -policy=demo-app -format=json | jq -r '.auth.client_token'
```

Copy the token. It can read `secret/data/demo-app` and nothing else. Try to prove it:

```bash
export APP_TOKEN=<token from above>
curl -s -H "X-Vault-Token: $APP_TOKEN" http://localhost:8200/v1/secret/data/other-app
# -> 403 permission denied
```

### 4. Let the app fetch its own secret

Restart the app with the least-privilege token instead of the root token:

```bash
docker compose stop demo-app
VAULT_TOKEN=<token> docker compose up -d demo-app
curl -s http://localhost:8080/ | jq
curl -s http://localhost:8080/health | jq
```

The app never sees the real password on disk. It asks Vault at startup, keeps the
value in memory only, and the `/` endpoint returns a masked version.

### 5. Rotate the secret

```bash
vault kv put secret/demo-app db_password='rotated-pass-456' api_key='demo-key-123'
docker compose restart demo-app
curl -s http://localhost:8080/ | jq .db_password_masked
```

No rebuild, no redeploy, no code change. The app picks up the new value on restart.

## Tasks

1. Add a second secret path `secret/demo-app/staging` and a policy that allows
   reading it only from the staging namespace (hint: same policy file, new path).
2. Create a token with a 60-second TTL (`-ttl=60s`) and watch the app fail after
   it expires. What would you change so the app renews its token?
3. Revoke the app token (`vault token revoke <token>`) while the app is running.
   What happens on the next request, and how should the app handle it?
4. Bonus: enable the database secrets engine (`vault secrets enable database`)
   and configure it to issue short-lived database credentials instead of a
   static password. Why is that better than rotating a static secret?

## Cleanup

```bash
docker compose down
```

## Key ideas

- Secrets are data with a lifecycle: create, read, rotate, revoke.
- An app should get the smallest token it needs, for the shortest time it needs.
- If a secret is committed to git, it is compromised. Rotate it and remove it
  from history; deleting the file is not enough.
- Vault dev mode is a learning tool. Production Vault runs sealed, with TLS,
  audit logging, and unseal keys held by more than one person.
