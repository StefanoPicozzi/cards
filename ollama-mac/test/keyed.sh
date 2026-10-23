#!/bin/sh
# The published app works with a key: 401 without one, 200 with one. Ollama refuses a request whose
# Host is not localhost when it listens on 127.0.0.1 only, which shows up as a 403 even with a valid
# key, so this check calls the public address, not the local port. Needs `edgible` logged in.
set -eu
app=${OLLAMA_APP:-ollama}
url=$(edgible -o json app list | jq -er --arg n "$app" '.[] | select(.name == $n) | .url')
keyfile=$(mktemp)
trap 'rm -f "$keyfile"' EXIT
edgible -o json app api-keys create --app "$app" --name card-test >"$keyfile"
id=$(jq -er .keyData.id "$keyfile")
trap 'edgible app api-keys delete --app "$app" --key-id "$id" --yes >/dev/null 2>&1 || true; rm -f "$keyfile"' EXIT
key=$(jq -er .apiKey "$keyfile")
# The certificate and route can take a minute after Publish.
for _ in $(seq 20); do
  [ "$(curl -s -m 15 -o /dev/null -w '%{http_code}' "$url/api/tags" || true)" = 401 ] && break
  sleep 10
done
nokey=$(curl -s -m 15 -o /dev/null -w '%{http_code}' "$url/api/tags" || true)
[ "$nokey" = 401 ] || { echo "no key: expected 401, got $nokey"; exit 1; }
withkey=$(curl -s -m 30 -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $key" "$url/api/tags" || true)
[ "$withkey" = 200 ] || { echo "with a key: expected 200, got $withkey (403 means Ollama is on 127.0.0.1 only; see OLLAMA_BIND)"; exit 1; }
echo "401 without a key, 200 with one"
