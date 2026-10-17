#!/bin/sh
# Prepare for the ech0 card: make the owner and close sign-up before the site is public.
# Run it after Start and before Publish, from the directory that holds ech0/:
#   sh ech0/prepare.sh
set -eu
cd "$(dirname "$0")"
set -a; . ./card.env; set +a

B="http://127.0.0.1:$ECH0_PORT/api"
H='Content-Type: application/json'

n=0
until curl -fsS "$B/init/status" >/dev/null 2>&1; do
  n=$((n + 1)); [ "$n" -lt 60 ] || { echo "ech0 did not answer"; exit 1; }
  sleep 1
done

# The first account to register becomes the owner, so make it here, not on a public page.
curl -fsS -X POST "$B/init/owner" -H "$H" \
  -d "{\"username\":\"$ECH0_ADMIN_USER\",\"email\":\"$ECH0_ADMIN_EMAIL\",\"password\":\"$ECH0_ADMIN_PASSWORD\",\"locale\":\"en-US\"}" >/dev/null

token=$(curl -fsS -X POST "$B/login" -H "$H" \
  -d "{\"username\":\"$ECH0_ADMIN_USER\",\"password\":\"$ECH0_ADMIN_PASSWORD\"}" \
  | jq -er '.data.access_token')

# Close sign-up: the owner is the only account until the owner adds more.
settings=$(curl -fsS "$B/settings" | jq -c '.data | .allow_register = false')
curl -fsS -X PUT "$B/settings" -H "$H" -H "Authorization: Bearer $token" -d "$settings" >/dev/null
curl -fsS "$B/settings" | jq -e '.data.allow_register == false' >/dev/null
echo "owner made from ECH0_ADMIN_USER and ECH0_ADMIN_PASSWORD, sign-up closed"
