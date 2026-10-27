#!/bin/sh
# Prepare for the docmost card: make the workspace and its admin before the setup page is public.
# Run it after Start and before Publish, from the directory that holds docmost/:
#   sh docmost/prepare.sh
set -eu
cd "$(dirname "$0")"
set -a; . ./card.env; set +a
COMPOSE=${COMPOSE:-docker compose --env-file card.env -f docker-compose.yml}

# The admin's password is the human secret docmost-secrets made on this machine.
DOCMOST_ADMIN_PASSWORD=$($COMPOSE run --rm --no-deps docmost-secrets show DOCMOST_ADMIN_PASSWORD)

# Docmost lets the first visitor to /setup make the workspace; this takes that place.
$COMPOSE exec -T -e DOCMOST_ADMIN_PASSWORD="$DOCMOST_ADMIN_PASSWORD" \
  -e DOCMOST_ADMIN_EMAIL="$DOCMOST_ADMIN_EMAIL" -e DOCMOST_WORKSPACE="${DOCMOST_WORKSPACE:-Team wiki}" docmost node -e '
fetch("http://127.0.0.1:3000/api/auth/setup", {
  method: "POST",
  headers: {"Content-Type": "application/json"},
  body: JSON.stringify({
    workspaceName: process.env.DOCMOST_WORKSPACE,
    name: "Admin",
    email: process.env.DOCMOST_ADMIN_EMAIL,
    password: process.env.DOCMOST_ADMIN_PASSWORD,
  }),
}).then(async (r) => {
  if (!r.ok) { console.error("setup answered " + r.status + ": " + await r.text()); process.exit(1); }
}).catch((e) => { console.error(String(e)); process.exit(1); });
'
echo "the workspace is made; the admin signs in with DOCMOST_ADMIN_EMAIL and DOCMOST_ADMIN_PASSWORD"
