#!/bin/sh
# Prepare for the wordpress card: install WordPress, so its install page is never public.
# Run it after Start and before Publish, from the directory that holds wordpress/:
#   sh wordpress/prepare.sh
set -eu
cd "$(dirname "$0")"
set -a; . ./card.env; set +a
COMPOSE=${COMPOSE:-docker compose --env-file card.env -f docker-compose.yml}

# The card made this password on this machine at Start (wordpress-secrets).
WORDPRESS_ADMIN_PASSWORD=$($COMPOSE run --rm --no-deps wordpress-secrets show WORDPRESS_ADMIN_PASSWORD)

$COMPOSE --profile cli run --rm -T wordpress-cli \
  wp core install --url="${WORDPRESS_URL:-https://wordpress.$ORG_LABEL.${EDGIBLE_DOMAIN:-edgible.app}}" --title="My site" \
  --admin_user=admin --admin_password="$WORDPRESS_ADMIN_PASSWORD" --admin_email="$WORDPRESS_ADMIN_EMAIL" --skip-email
