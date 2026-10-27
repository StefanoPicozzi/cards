# A check for test-card, run after Verify with card.env exported and HOSTNAME_<APP> set.
# docmost is on org, so this asks the app on the machine: the admin prepare.sh made signs in,
# and a wrong password is refused.
set -eu
B="http://127.0.0.1:$DOCMOST_PORT"; H='Content-Type: application/json'
code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$B/api/auth/login" -H "$H" \
  -d "{\"email\":\"$DOCMOST_ADMIN_EMAIL\",\"password\":\"wrong-$DOCMOST_ADMIN_PASSWORD\"}")
[ "$code" = 401 ] || [ "$code" = 400 ] || { echo "a wrong password answered $code"; exit 1; }
curl -fsS -D - -o /dev/null -X POST "$B/api/auth/login" -H "$H" \
  -d "{\"email\":\"$DOCMOST_ADMIN_EMAIL\",\"password\":\"$DOCMOST_ADMIN_PASSWORD\"}" | grep -qi 'set-cookie'
