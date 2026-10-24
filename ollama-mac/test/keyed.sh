#!/bin/sh
# The published app, through the proxy: 401 without a key, 200 with one, a model answers (streamed),
# and a key cannot manage models: pull, create, copy and delete are refused. Ollama refuses a request
# whose Host is not localhost, which shows up as a 403 even with a valid key, so this check calls the
# public address, not the local port. Needs `edgible` logged in.
set -eu
# test-card gives the published hostname (a taken app name becomes test-<name>); by hand, the app's name.
if [ -n "${HOSTNAME_OLLAMA:-}" ]; then
  app=$(edgible -o json app list | jq -er --arg h "$HOSTNAME_OLLAMA" '.[] | select(.hostnames | index($h)) | .name')
  url=https://$HOSTNAME_OLLAMA
else
  app=${OLLAMA_APP:-ollama}
  url=$(edgible -o json app list | jq -er --arg n "$app" '.[] | select(.name == $n) | .url')
fi
keyfile=$(mktemp)
trap 'rm -f "$keyfile"' EXIT
edgible -o json app api-keys create --app "$app" --name card-test >"$keyfile"
id=$(jq -er .keyData.id "$keyfile")
trap 'edgible app api-keys delete --app "$app" --key-id "$id" --yes >/dev/null 2>&1 || true; rm -f "$keyfile"' EXIT
key=$(jq -er .apiKey "$keyfile")
code() { curl -s -m "${T:-30}" -o /dev/null -w '%{http_code}' "$@" || true; }
# The certificate and route can take a minute after Publish.
for _ in $(seq 20); do
  [ "$(T=15 code "$url/api/tags")" = 401 ] && break
  sleep 10
done
nokey=$(code "$url/api/tags")
[ "$nokey" = 401 ] || { echo "no key: expected 401, got $nokey"; exit 1; }
withkey=$(code -H "Authorization: Bearer $key" "$url/api/tags")
[ "$withkey" = 200 ] || { echo "with a key: expected 200, got $withkey"; exit 1; }
# A model answers, streamed line by line, through the proxy.
model=$(curl -fsS -m 30 -H "Authorization: Bearer $key" "$url/api/tags" | jq -er '.models[0].name') \
  || { echo "no model to ask; gpu.sh pulls one first"; exit 1; }
lines=$(curl -fsS -m 120 -H "Authorization: Bearer $key" "$url/api/chat" \
  -d "{\"model\":\"$model\",\"messages\":[{\"role\":\"user\",\"content\":\"Count to five.\"}],\"stream\":true,\"options\":{\"num_predict\":24}}" | wc -l)
[ "$lines" -ge 2 ] || { echo "the answer did not stream: $lines line(s)"; exit 1; }
# A key uses models; it does not manage them.
for call in "POST /api/pull" "POST /api/create" "POST /api/copy" "DELETE /api/delete" "POST /api/push"; do
  got=$(code -X "${call% *}" -H "Authorization: Bearer $key" "$url${call#* }" -d '{"model":"keyed-check"}')
  [ "$got" = 403 ] || { echo "$call with a key: expected 403, got $got"; exit 1; }
done
echo "401 without a key, 200 with one, a streamed answer, and pull, create, copy, delete and push refused (403)"
