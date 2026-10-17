# A check for test-card, run after Verify with card.env exported and HOSTNAME_<APP> set.
# ech0 is on none, so this goes through the public hostname: the owner from card.env signs
# in, a wrong password does not, and sign-up is closed, so no stranger can make an account.
set -eu
B="https://$HOSTNAME_ECH0/api"
H='Content-Type: application/json'
code=$(curl -sS -o /dev/null -w '%{http_code}' -X POST "$B/login" -H "$H" \
  -d "{\"username\":\"$ECH0_ADMIN_USER\",\"password\":\"wrong-$ECH0_ADMIN_PASSWORD\"}")
case "$code" in 2*) echo "a wrong password answered $code"; exit 1 ;; esac
curl -fsS -X POST "$B/login" -H "$H" \
  -d "{\"username\":\"$ECH0_ADMIN_USER\",\"password\":\"$ECH0_ADMIN_PASSWORD\"}" | jq -e '.data.access_token | length > 0' >/dev/null
curl -fsS "$B/settings" | jq -e '.data.allow_register == false' >/dev/null
