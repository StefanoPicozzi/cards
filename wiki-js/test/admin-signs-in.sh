# A check for test-card, run after Verify with card.env exported and HOSTNAME_<APP> set.
# wiki-js is on org, so this asks the app on the machine: the admin prepare.sh made signs in,
# and a wrong password is refused.
set -eu
B="http://127.0.0.1:$WIKI_JS_PORT"
login() {
  curl -fsS -X POST "$B/graphql" -H 'Content-Type: application/json' \
    -d "{\"query\":\"mutation { authentication { login(username: \\\"$WIKI_JS_ADMIN_EMAIL\\\", password: \\\"$1\\\", strategy: \\\"local\\\") { responseResult { succeeded } } } }\"}"
}
login "wrong-$WIKI_JS_ADMIN_PASSWORD" | grep -q '"succeeded":false' || { echo "a wrong password was not refused"; exit 1; }
login "$WIKI_JS_ADMIN_PASSWORD" | grep -q '"succeeded":true' || { echo "the admin could not sign in"; exit 1; }
