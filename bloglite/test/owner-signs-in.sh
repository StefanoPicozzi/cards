# A check for test-card, run after Verify with card.env exported and HOSTNAME_<APP> set.
# bloglite is on none, so this goes through the public hostname: the owner from card.env
# signs in, and a wrong password does not.
set -eu
B="https://$HOSTNAME_BLOGLITE"
code=$(curl -sS -o /dev/null -w '%{http_code}' -X POST "$B/login" \
  --data-urlencode "username=$BLOGLITE_ADMIN_USER" --data-urlencode "password=wrong-$BLOGLITE_ADMIN_PASSWORD")
case "$code" in 2*|3*) echo "a wrong password answered $code"; exit 1 ;; esac
code=$(curl -sS -o /dev/null -w '%{http_code}' -X POST "$B/login" \
  --data-urlencode "username=$BLOGLITE_ADMIN_USER" --data-urlencode "password=$BLOGLITE_ADMIN_PASSWORD")
case "$code" in 2*|3*) ;; *) echo "the owner's password answered $code"; exit 1 ;; esac
