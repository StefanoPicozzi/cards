# A check for test-card, run after Verify with card.env exported and HOSTNAME_<APP> set.
# An MCP client's path up to the person's sign-in, which a test cannot make: /mcp refuses a
# caller with no token and names the OAuth metadata, the metadata names this address, a client
# registers itself, and /authorize sends the browser to the sign-in address. That address
# answers only after Edgible's sign-in, even to a caller that sends Edgible's identity headers
# itself, and the public address has no sign-in page.
set -eu
P="https://$HOSTNAME_MCP_SIGNIN"
L="https://$HOSTNAME_MCP_SIGNIN_LOGIN"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

code=$(curl -sS -D "$tmp/h" -o /dev/null -w '%{http_code}' -X POST "$P/mcp" -H 'Content-Type: application/json' --data '{}')
[ "$code" = 401 ] || { echo "/mcp without a token answered $code"; exit 1; }
grep -qi "resource_metadata=\"$P/.well-known/oauth-protected-resource/mcp\"" "$tmp/h" \
  || { echo "the 401 does not name $P's resource metadata"; exit 1; }

curl -fsS "$P/.well-known/oauth-protected-resource/mcp" | jq -e --arg p "$P" '.resource == "\($p)/mcp"' >/dev/null \
  || { echo "the resource metadata does not name $P/mcp"; exit 1; }
curl -fsS "$P/.well-known/oauth-authorization-server" \
  | jq -e --arg p "$P" '.issuer == "\($p)/" and .registration_endpoint == "\($p)/register" and (.code_challenge_methods_supported | index("S256"))' >/dev/null \
  || { echo "the authorization server metadata does not name $P"; exit 1; }

cb=https://claude.ai/api/mcp/auth_callback
client=$(curl -fsS -X POST "$P/register" -H 'Content-Type: application/json' \
  --data "{\"redirect_uris\":[\"$cb\"],\"client_name\":\"mcp-signin test\",\"token_endpoint_auth_method\":\"none\"}" | jq -er .client_id)
to=$(curl -sS -o /dev/null -w '%{http_code} %{redirect_url}' \
  "$P/authorize?response_type=code&client_id=$client&redirect_uri=$cb&code_challenge=E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM&code_challenge_method=S256&state=t")
case "$to" in "302 $L/signin?request="*) ;; *) echo "/authorize answered $to, not a redirect to $L/signin"; exit 1;; esac
request=${to#*request=}

org=$(curl -sS -o /dev/null -w '%{http_code}' "$L/signin?request=$request" \
  -H 'X-Auth-Type: org' -H 'X-Auth-Email: someone@example.com' -H "X-Auth-Organization-Id: $EDGIBLE_ORGANIZATION_ID")
[ "$org" = 302 ] || { echo "the sign-in page answered $org to a caller who sent Edgible's headers itself"; exit 1; }

code=$(curl -sS -o /dev/null -w '%{http_code}' "$P/signin?request=$request")
[ "$code" = 404 ] || { echo "the public address answered $code for the sign-in page"; exit 1; }
echo "OAuth metadata, registration and /authorize answer; the sign-in page is behind Edgible's sign-in"
