#!/bin/sh
# Prepare for the wiki-go card: replace the default admin password before the wiki is public.
# Wiki-Go starts with the user admin and the password admin; this sets the password the card made.
# Run it after Start and before Publish, from the directory that holds wiki-go/:
#   sh wiki-go/prepare.sh
set -eu
cd "$(dirname "$0")"
set -a; . ./card.env; set +a
COMPOSE=${COMPOSE:-docker compose --env-file card.env -f docker-compose.yml}

# The admin's password is the human secret wiki-go-secrets made on this machine.
WIKI_GO_ADMIN_PASSWORD=$($COMPOSE run --rm --no-deps wiki-go-secrets show WIKI_GO_ADMIN_PASSWORD)

$COMPOSE exec -T -e WIKI_GO_ADMIN_PASSWORD="$WIKI_GO_ADMIN_PASSWORD" wiki-go bash -s <<'EOF'
set -eu
B=http://127.0.0.1:8080
H='Content-Type: application/json'
hdr=$(mktemp)
login() {
  curl -s -D "$hdr" -o /dev/null -w '%{http_code}' -X POST "$B/api/login" -H "$H" \
    -d "{\"username\":\"admin\",\"password\":\"$1\"}"
}
if [ "$(login admin)" != 200 ]; then
  if [ "$(login "$WIKI_GO_ADMIN_PASSWORD")" = 200 ]; then
    echo "the admin password is already set"; exit 0
  fi
  echo "admin signs in with neither the default password nor the card's"; exit 1
fi
token=$(sed -n 's/^[Ss]et-[Cc]ookie: session_token=\([^;]*\).*/\1/p' "$hdr" | head -n 1)
code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$B/api/password" -H "$H" \
  -H "Cookie: session_token=$token" \
  -d "{\"current_password\":\"admin\",\"new_password\":\"$WIKI_GO_ADMIN_PASSWORD\"}")
[ "$code" = 200 ] || { echo "setting the password answered $code"; exit 1; }
EOF
echo "the default password is replaced; admin signs in with the user admin and WIKI_GO_ADMIN_PASSWORD"
