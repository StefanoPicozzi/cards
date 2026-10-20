# A check for test-card, run after Verify with card.env exported and HOSTNAME_<APP> set.
# linkding is on none, so this signs in through the public hostname, which also proves
# LD_CSRF_TRUSTED_ORIGINS: the admin from card.env, with the password the card made, gets in, and a wrong password does not.
set -eu
B="https://$HOSTNAME_LINKDING"
jar=$(mktemp); trap 'rm -f "$jar"' EXIT
login() {
  rm -f "$jar"
  token=$(curl -fsS -c "$jar" "$B/login/" | sed -n 's/.*name="csrfmiddlewaretoken" value="\([^"]*\)".*/\1/p' | head -1)
  [ -n "$token" ] || { echo "no CSRF token on the login page"; exit 1; }
  curl -sS -b "$jar" -c "$jar" -o /dev/null -w '%{http_code} %{redirect_url}' \
    -H "Referer: $B/login/" -H "Origin: $B" \
    --data-urlencode "csrfmiddlewaretoken=$token" \
    --data-urlencode "username=$LINKDING_ADMIN_USER" \
    --data-urlencode "password=$1" "$B/login/"
}
bad=$(login "wrong-$LINKDING_ADMIN_PASSWORD")
case "$bad" in 200*|401*) ;; *) echo "a wrong password answered $bad"; exit 1 ;; esac
good=$(login "$LINKDING_ADMIN_PASSWORD")
case "$good" in 302*bookmarks*) ;; *) echo "the admin's sign-in answered $good"; exit 1 ;; esac
curl -fsS -b "$jar" "$B/bookmarks" | grep -q 'logout'
