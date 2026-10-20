#!/bin/sh
# Prepare for the immich card: make the admin, so the sign-up page is never public.
# Run it after Start and before Publish, from the directory that holds immich/:
#   sh immich/prepare.sh
set -eu
cd "$(dirname "$0")"
set -a; . ./card.env; set +a
COMPOSE=${COMPOSE:-docker compose --env-file card.env -f docker-compose.yml}

# The card made this password on this machine at Start (immich-secrets).
IMMICH_ADMIN_PASSWORD=$($COMPOSE run --rm --no-deps immich-secrets show IMMICH_ADMIN_PASSWORD)

curl -fsS -X POST "http://127.0.0.1:$IMMICH_PORT/api/auth/admin-sign-up" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$IMMICH_ADMIN_EMAIL\",\"password\":\"$IMMICH_ADMIN_PASSWORD\",\"name\":\"Admin\"}"
