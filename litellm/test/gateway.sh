# A check for test-card, run after Verify with card.env and the card's made secrets exported.
# The gateway answers only with a key, offers the models by purpose, and makes app keys that may
# only use models and read their own record, as edgible-mcp's gateway_key and register-keys.py do.
set -eu
B="http://127.0.0.1:$LITELLM_PORT"
M="Authorization: Bearer $LITELLM_MASTER_KEY"
code=$(curl -s -o /dev/null -w '%{http_code}' "$B/v1/models")
[ "$code" = 401 ] || { echo "/v1/models with no key answered $code"; exit 1; }
models=$(curl -fsS "$B/v1/models" -H "$M")
for m in fast fast-fallback smart open best private private-smart; do
  echo "$models" | grep -q "\"$m\"" || { echo "the gateway does not offer $m"; exit 1; }
done
key=$(curl -fsS -X POST "$B/key/generate" -H "$M" -H 'content-type: application/json' \
  -d '{"key_alias":"card-check","max_budget":0.01,"budget_duration":"1d","allowed_routes":["/v1/chat/completions","/chat/completions","/v1/models","/models","/key/info"]}' \
  | python3 -c 'import json,sys; print(json.load(sys.stdin)["key"])')
A="Authorization: Bearer $key"
[ "$(curl -s -o /dev/null -w '%{http_code}' "$B/key/info" -H "$A")" = 200 ] || { echo "an app key cannot read its own record"; exit 1; }
[ "$(curl -s -o /dev/null -w '%{http_code}' "$B/v1/models" -H "$A")" = 200 ] || { echo "an app key cannot list models"; exit 1; }
code=$(curl -s -o /dev/null -w '%{http_code}' "$B/user/daily/activity?start_date=2026-01-01&end_date=2026-01-02" -H "$A")
[ "$code" = 403 ] || { echo "an app key reached the gateway's activity report ($code)"; exit 1; }
code=$(curl -s -o /dev/null -w '%{http_code}' "$B/user/daily/activity?start_date=2026-01-01&end_date=2026-01-02" -H "$M")
[ "$code" = 200 ] || { echo "the owner's activity report answered $code"; exit 1; }
curl -fsS -X POST "$B/key/delete" -H "$M" -H 'content-type: application/json' -d '{"key_aliases":["card-check"]}' >/dev/null
echo "gateway: 401 without a key; seven models by purpose; an app key reads only its own record (activity 403); the owner's report 200"
