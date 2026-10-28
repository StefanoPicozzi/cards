# A check for test-card, run after Verify with card.env exported and HOSTNAME_<APP> set.
# otter-wiki is on org, so this asks the app on the machine: the wiki is healthy, and a
# visitor who has not signed in to it is sent to its login, not shown a page.
set -eu
B="http://127.0.0.1:$OTTER_WIKI_PORT"
curl -fsS -A card-test "$B/-/healthz" >/dev/null
code=$(curl -s -o /dev/null -w '%{http_code}' "$B/Home")
case "$code" in 302|401|403) ;; *) echo "an anonymous read answered $code"; exit 1 ;; esac
