#!/bin/sh
# Prepare for the jellyfin card: finish Jellyfin's setup wizard, so it is never public.
# Run it after Start and before Publish, from the directory that holds jellyfin/:
#   sh jellyfin/prepare.sh
set -eu
cd "$(dirname "$0")"
set -a; . ./card.env; set +a
COMPOSE=${COMPOSE:-docker compose --env-file card.env -f docker-compose.yml}

# The card made this password on this machine at Start (jellyfin-secrets).
JELLYFIN_ADMIN_PASSWORD=$($COMPOSE run --rm --no-deps jellyfin-secrets show JELLYFIN_ADMIN_PASSWORD)

B="http://127.0.0.1:$JELLYFIN_PORT"
H='Content-Type: application/json'
curl -fsS -X POST "$B/Startup/Configuration" -H "$H" \
  -d '{"UICulture":"en-US","MetadataCountryCode":"US","PreferredMetadataLanguage":"en"}'
curl -fsS "$B/Startup/User" >/dev/null
curl -fsS -X POST "$B/Startup/User" -H "$H" \
  -d "{\"Name\":\"$JELLYFIN_ADMIN_USER\",\"Password\":\"$JELLYFIN_ADMIN_PASSWORD\"}"
curl -fsS -X POST "$B/Startup/RemoteAccess" -H "$H" \
  -d '{"EnableRemoteAccess":true,"EnableAutomaticPortMapping":false}'
curl -fsS -X POST "$B/Startup/Complete"
