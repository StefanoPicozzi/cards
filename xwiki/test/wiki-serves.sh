# A check for test-card, run after Verify with card.env exported and HOSTNAME_<APP> set.
# xwiki is on org, so this asks the app on the machine: it answers with XWiki's own page,
# which on a new install is the distribution wizard, and the database is not published.
set -eu
B="http://127.0.0.1:$XWIKI_PORT"
curl -fsSL "$B/bin/view/Main/" | grep -qi 'xwiki'
if curl -s --max-time 3 -o /dev/null "http://127.0.0.1:5432"; then echo "the database is reachable from the host"; exit 1; fi
