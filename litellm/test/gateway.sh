# A check for test-card, run after Verify with card.env and the card's made secrets exported.
# The gateway answers only with a key, and offers the four models by purpose.
set -eu
B="http://127.0.0.1:$LITELLM_PORT"
code=$(curl -s -o /dev/null -w '%{http_code}' "$B/v1/models")
[ "$code" = 401 ] || { echo "/v1/models with no key answered $code"; exit 1; }
models=$(curl -fsS "$B/v1/models" -H "Authorization: Bearer $LITELLM_MASTER_KEY")
for m in fast fast-fallback smart private; do
  echo "$models" | grep -q "\"$m\"" || { echo "the gateway does not offer $m"; exit 1; }
done
echo "gateway: 401 without a key; fast, fast-fallback, smart, private with one"
