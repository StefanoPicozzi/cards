# A check for test-card, run after Verify with card.env exported and HOSTNAME_<APP> set.
# From the mcp-bridge app card's check. An MCP client's whole path through Edgible: with a
# fresh Edgible API key it initializes over Streamable HTTP, lists the five read-only tools
# (find, describe, sign_in, agent_spend, whats_running), and calls the three that need nothing
# else. whats_running must answer whether or not the server's Edgible sign-in has been made: a
# test's fresh volume has none. A wrong key is refused. The key is deleted afterwards, and
# never printed.
set -eu
B="https://$HOSTNAME_EDGIBLE_MCP/mcp"
app=${HOSTNAME_EDGIBLE_MCP%%.*}
tmp=$(mktemp -d)
key_id=
cleanup() {
  [ -z "$key_id" ] || edgible app api-keys delete --app "$app" --key-id "$key_id" --yes >/dev/null 2>&1 || true
  rm -rf "$tmp"
}
trap cleanup EXIT
edgible -o json app api-keys create --app "$app" --name edgible-mcp-test \
  --expires "$(date -u -v+1d +%F 2>/dev/null || date -u -d tomorrow +%F)" 2>/dev/null > "$tmp/key.json"
key_id=$(jq -er .keyData.id "$tmp/key.json")
jq -er .apiKey "$tmp/key.json" > "$tmp/key"

# POST one JSON-RPC message; the answer may be JSON or a server-sent event stream.
rpc() {
  curl -sS -D "$tmp/headers" -o "$tmp/body" -w '%{http_code}' "$B" \
    -H "Authorization: Bearer $(cat "$tmp/key")" \
    -H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' \
    ${session:+-H "Mcp-Session-Id: $session"} --data "$1"
}
answer() { sed -n 's/^data: //p' "$tmp/body" | grep . || cat "$tmp/body"; }

code=$(curl -sS -o /dev/null -w '%{http_code}' "$B" -H 'Authorization: Bearer wrong-key' \
  -H 'Content-Type: application/json' --data '{}')
[ "$code" = 401 ] || { echo "a wrong key answered $code"; exit 1; }

session=
code=$(rpc '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"edgible-mcp-test","version":"1"}}}')
[ "$code" = 200 ] || { echo "initialize answered $code"; exit 1; }
answer | jq -e '.result.serverInfo.name' >/dev/null || { echo "initialize gave no serverInfo"; exit 1; }
# The server is stateless: it may answer with no Mcp-Session-Id, and then every call stands alone.
session=$(sed -n 's/^[Mm]cp-[Ss]ession-[Ii]d: *\([^[:space:]]*\).*/\1/p' "$tmp/headers")

rpc '{"jsonrpc":"2.0","method":"notifications/initialized"}' >/dev/null

code=$(rpc '{"jsonrpc":"2.0","id":2,"method":"tools/list"}')
[ "$code" = 200 ] || { echo "tools/list answered $code"; exit 1; }
tools=$(answer | jq -r '[.result.tools[].name] | sort | join(",")')
[ "$tools" = "agent_spend,describe,find,sign_in,whats_running" ] || { echo "tools: $tools"; exit 1; }

# call ID TOOL ARGS: the tool's text, or exit 1 when it fails.
call() {
  code=$(rpc "{\"jsonrpc\":\"2.0\",\"id\":$1,\"method\":\"tools/call\",\"params\":{\"name\":\"$2\",\"arguments\":$3}}")
  [ "$code" = 200 ] || { echo "$2 answered $code" >&2; return 1; }
  answer | jq -er 'select(.result.isError != true) | .result.content[0].text' || { echo "$2 failed: $(head -c 300 "$tmp/body")" >&2; return 1; }
}

call 3 find '{"need":"somewhere for my bookmarks"}' | grep -q '\*\*linkding\*\* (app)' || { echo "find did not find linkding"; exit 1; }
call 4 describe '{"name":"linkding"}' | grep -q '^# linkding (app)' || { echo "describe did not describe linkding"; exit 1; }
running=$(call 5 whats_running '{"app":"linkding"}') || exit 1
case "$running" in
  *"is not signed in"*) echo "whats_running: answers, and says the server is not signed in to Edgible" ;;
  "# Apps in "*) echo "whats_running: answers, signed in" ;;
  *) echo "whats_running: $(printf '%s' "$running" | head -c 300)"; exit 1 ;;
esac
echo "mcp-tools: $tools; find, describe and whats_running called with a key; a wrong key refused"
