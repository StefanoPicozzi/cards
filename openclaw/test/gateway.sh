# A check for test-card, run after Verify with card.env exported and HOSTNAME_<APP> set.
# The Gateway answers its health check and serves the Control UI on this machine's loopback,
# and nowhere else: the published hostname sends a browser to Edgible's sign-in first
# (Verify checks that), and the port is not open on this machine's other addresses.
set -eu
code=$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$OPENCLAW_PORT/healthz")
[ "$code" = 200 ] || { echo "/healthz on loopback answered $code"; exit 1; }
curl -fsS "http://127.0.0.1:$OPENCLAW_PORT/" | grep -qi openclaw || { echo "the Control UI did not answer on loopback"; exit 1; }
for ip in $( (hostname -I 2>/dev/null || ipconfig getifaddr en0 2>/dev/null || true) | tr ' ' '\n' | grep -E '^[0-9]+\.' ); do
  if curl -s -o /dev/null --max-time 3 "http://$ip:$OPENCLAW_PORT/healthz"; then
    echo "the Gateway answers on $ip, not only on loopback"; exit 1
  fi
done
echo "Gateway healthy, Control UI on loopback only"
