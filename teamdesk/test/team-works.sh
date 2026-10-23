# A check for test-card, run after Verify with card.env exported and HOSTNAME_<APP> set.
# teamdesk is on org, so the hostname answers with Edgible's sign-in. This goes to the
# app on the machine instead: the first admin from card.env exists, can add a room,
# and an overlapping booking is refused while a back-to-back one is accepted.
set -eu
T="http://127.0.0.1:$TEAMDESK_PORT/api/trpc"
J='content-type: application/json'
post() { curl -sS -X POST -H "$J" -d "$2" "$T/$1"; }

admin=$(curl -sS "$T/members.list" | grep -o '"id":"[0-9]*"' | head -1 | grep -o '[0-9]*')
[ -n "$admin" ] || { echo "no first admin was made"; exit 1; }

post rooms.add "{\"actorId\":\"$admin\",\"room\":{\"name\":\"Checkroom\",\"capacity\":4}}" | grep -q '"result"' \
  || { echo "the admin could not add a room"; exit 1; }
b() { post bookings.create "{\"actorId\":\"$admin\",\"booking\":{\"roomId\":\"1\",\"attendees\":2,\"startsAt\":\"$1\",\"endsAt\":\"$2\",\"title\":\"check\"}}"; }
b 2030-01-01T09:00:00.000Z 2030-01-01T10:00:00.000Z | grep -q '"result"' || { echo "a booking was refused"; exit 1; }
b 2030-01-01T09:30:00.000Z 2030-01-01T10:30:00.000Z | grep -q 'CONFLICT' || { echo "an overlapping booking was accepted"; exit 1; }
b 2030-01-01T10:00:00.000Z 2030-01-01T11:00:00.000Z | grep -q '"result"' || { echo "a back-to-back booking was refused"; exit 1; }
