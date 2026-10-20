#!/bin/sh
# Prepare for the gitea card: make the admin.
# Run it after Start and before Publish, from the directory that holds gitea/:
#   sh gitea/prepare.sh
set -eu
cd "$(dirname "$0")"
set -a; . ./card.env; set +a
COMPOSE=${COMPOSE:-docker compose --env-file card.env -f docker-compose.yml}

# The card made this password on this machine at Start (gitea-secrets).
GITEA_ADMIN_PASSWORD=$($COMPOSE run --rm --no-deps gitea-secrets show GITEA_ADMIN_PASSWORD)

$COMPOSE exec -T -u git gitea \
  gitea admin user create --admin --username gitadmin \
  --password "$GITEA_ADMIN_PASSWORD" --email "$GITEA_ADMIN_EMAIL" --must-change-password=false
