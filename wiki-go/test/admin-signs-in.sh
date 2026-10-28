# A check for test-card, run after Verify with card.env exported and HOSTNAME_<APP> set.
# wiki-go is on org, so this asks the app on the machine: a wrong password and the default
# password are refused, and the password prepare.sh set signs the admin in.
set -eu
B="http://127.0.0.1:$WIKI_GO_PORT"; H='Content-Type: application/json'
login() {
  curl -s -o /dev/null -w '%{http_code}' -X POST "$B/api/login" -H "$H" \
    -d "{\"username\":\"admin\",\"password\":\"$1\"}"
}
code=$(login "wrong-$WIKI_GO_ADMIN_PASSWORD")
[ "$code" = 401 ] || { echo "a wrong password answered $code"; exit 1; }
code=$(login admin)
[ "$code" = 401 ] || { echo "the default password answered $code"; exit 1; }
code=$(login "$WIKI_GO_ADMIN_PASSWORD")
[ "$code" = 200 ] || { echo "the card's password answered $code"; exit 1; }
