# Least-privilege policy for the demo app.
# It may read exactly one secret path and nothing else.
# No listing, no writing, no access to other apps' secrets.

path "secret/data/demo-app" {
  capabilities = ["read"]
}

# Allow the app to look up and renew its own token.
path "auth/token/lookup-self" {
  capabilities = ["read"]
}

path "auth/token/renew-self" {
  capabilities = ["update"]
}
