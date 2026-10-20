#!/bin/sh
# Prepare for the umami card: change the default password, admin / umami, before the login page is public.
# Run it after Start and before Publish, from the directory that holds umami/:
#   sh umami/prepare.sh
set -eu
cd "$(dirname "$0")"
set -a; . ./card.env; set +a
COMPOSE=${COMPOSE:-docker compose --env-file card.env -f docker-compose.yml}

# The new password is the human secret umami-secrets made on this machine.
UMAMI_ADMIN_PASSWORD=$($COMPOSE run --rm --no-deps umami-secrets show UMAMI_ADMIN_PASSWORD)

B="http://127.0.0.1:$UMAMI_PORT"
H='Content-Type: application/json'
token=$(curl -fsS -X POST "$B/api/auth/login" -H "$H" -d '{"username":"admin","password":"umami"}' \
  | sed -n 's/.*"token":"\([^"]*\)".*/\1/p')
curl -fsS -X POST "$B/api/me/password" -H "$H" -H "Authorization: Bearer $token" \
  -d "{\"currentPassword\":\"umami\",\"newPassword\":\"$UMAMI_ADMIN_PASSWORD\"}" >/dev/null
echo "admin's password is now UMAMI_ADMIN_PASSWORD"
