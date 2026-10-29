# A check for test-card, run after Verify with card.env exported and HOSTNAME_<APP> set.
# club-noticeboard is on none, so this goes through the public hostname: a wrong password is
# refused, the committee signs in with the password the card made, posts a notice, and deletes it.
set -eu
B="https://$HOSTNAME_CLUB_NOTICEBOARD"
jar=$(mktemp); trap 'rm -f "$jar"' EXIT
csrf() { sed -n 's/.*name="csrf" value="\([^"]*\)".*/\1/p' | head -1; }
login() {
  t=$(curl -sS -c "$jar" -b "$jar" "$B/login" | csrf)
  curl -sS -c "$jar" -b "$jar" -L "$B/login" --data-urlencode "csrf=$t" --data-urlencode "password=$1"
}
login "wrong-$CLUB_NOTICEBOARD_ADMIN_PASSWORD" | grep -q 'Wrong password' || { echo "a wrong password was not refused"; exit 1; }
page=$(login "$CLUB_NOTICEBOARD_ADMIN_PASSWORD")
echo "$page" | grep -q 'New notice' || { echo "the committee could not sign in"; exit 1; }
page=$(curl -sS -c "$jar" -b "$jar" -L "$B/new" --data-urlencode "csrf=$(echo "$page" | csrf)" \
  --data-urlencode "title=Card check" --data-urlencode "body=posted by test-card")
echo "$page" | grep -q 'Card check' || { echo "a notice could not be posted"; exit 1; }
id=$(echo "$page" | sed -n 's/.*action="\/delete\/\([0-9]*\)".*/\1/p' | head -1)
page=$(curl -sS -c "$jar" -b "$jar" -L "$B/delete/$id" --data-urlencode "csrf=$(echo "$page" | csrf)")
echo "$page" | grep -q 'Card check' && { echo "the notice was not deleted"; exit 1; }
true
