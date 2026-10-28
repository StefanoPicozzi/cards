# A check for test-card, run after Verify with card.env exported and HOSTNAME_<APP> set.
# leafwiki is on org, so this asks the app on the machine: the admin LeafWiki made at its first
# start signs in, and a wrong password is refused.
set -eu
B="http://127.0.0.1:$LEAFWIKI_PORT"; H='Content-Type: application/json'
code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$B/api/auth/login" -H "$H" \
  -d "{\"identifier\":\"admin\",\"password\":\"wrong-$LEAFWIKI_ADMIN_PASSWORD\"}")
[ "$code" = 401 ] || [ "$code" = 400 ] || [ "$code" = 403 ] || { echo "a wrong password answered $code"; exit 1; }
curl -fsS -o /dev/null -X POST "$B/api/auth/login" -H "$H" \
  -d "{\"identifier\":\"admin\",\"password\":\"$LEAFWIKI_ADMIN_PASSWORD\"}"
