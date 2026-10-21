#!/bin/sh
# One-shot set-up for the openclaw card, run by the openclaw-setup service before the Gateway
# starts. On the first start it runs OpenClaw's headless onboarding: Gateway token auth, keys kept
# as references to environment variables (never written into openclaw.json), no channels or
# third-party skills; then it sets the model, the Control UI's allowed origin and the proxy in
# front. Three extras, each only when its setting is given (the edgible-agent pattern sets them):
#   OPENCLAW_FALLBACK_MODEL  a model to answer when the main one fails (a free tier's 429), by
#                            its full name: deepseek/deepseek-flash (DEEPSEEK_API_KEY), or
#                            ollama/<tag> at OPENCLAW_FALLBACK_URL, such as ollama-mac's
#   EDGIBLE_MCP_URL          Edgible's MCP tools (edgible-mcp), added as the server "edgible"
#   EDGIBLE_SKILL            1: the edgible-cards skill from card-kit, for judgment
# Later starts change nothing: OpenClaw locks its config while the Gateway runs. Change settings
# afterwards with openclaw-cli, which shares the Gateway's processes (see the card's README).
set -eu
oc() { node /app/dist/index.js "$@"; }

if [ -f "$OPENCLAW_CONFIG_PATH" ]; then
  echo "openclaw-setup: already set up; change settings with openclaw-cli"
  exit 0
fi

case "$OPENCLAW_MODEL_PROVIDER" in
  gemini) auth="--auth-choice gemini-api-key" ;;
  openai-compatible)
    auth="--auth-choice custom-api-key --custom-base-url $OPENCLAW_MODEL_URL --custom-model-id $OPENCLAW_MODEL --custom-compatibility openai" ;;
  none) auth="--auth-choice skip" ;;
  *) echo "OPENCLAW_MODEL_PROVIDER must be gemini, openai-compatible or none" >&2; exit 1 ;;
esac
# shellcheck disable=SC2086
oc onboard --non-interactive --accept-risk --skip-health --mode local $auth \
  --secret-input-mode ref --gateway-auth token --gateway-token-ref-env OPENCLAW_GATEWAY_TOKEN \
  --gateway-bind lan --skip-channels --skip-skills --skip-search --skip-hooks --skip-ui \
  --skip-daemon --suppress-gateway-token-output

# The model: Gemini's onboarding picks a model the free tier refuses, so pin OPENCLAW_MODEL.
# The OpenAI-compatible route sets its model at onboarding, from the same setting.
set_ui="{\"path\":\"gateway.controlUi.allowedOrigins\",\"value\":[\"$OPENCLAW_URL\"]}"
# Edgible's web server on this machine reaches the Gateway through Docker's port mapping, so
# requests arrive from the Compose network's gateway address with forwarded headers. Trust that
# one address and nothing else: without it, OpenClaw rejects the Control UI from the published
# hostname ("unattributable proxy-shaped traffic").
gw=$(awk '$2 == "00000000" { print $3; exit }' /proc/net/route)
proxy=$(printf '%d.%d.%d.%d' "0x$(echo "$gw" | cut -c7-8)" "0x$(echo "$gw" | cut -c5-6)" "0x$(echo "$gw" | cut -c3-4)" "0x$(echo "$gw" | cut -c1-2)")
set_ui="$set_ui,{\"path\":\"gateway.trustedProxies\",\"value\":[\"$proxy\"]}"
if [ "$OPENCLAW_MODEL_PROVIDER" = gemini ]; then
  set_ui="$set_ui,{\"path\":\"agents.defaults.model.primary\",\"value\":\"$OPENCLAW_MODEL\"}"
fi
case "${OPENCLAW_FALLBACK_MODEL:-}" in ollama/*)
  # Ollama has no key; OpenClaw wants one, so a placeholder. Keep it a small (7B) model: a big one
  # turns a rate limit into what feels like a hang.
  tag=${OPENCLAW_FALLBACK_MODEL#ollama/}
  set_ui="$set_ui,{\"path\":\"models.providers.ollama.baseUrl\",\"value\":\"${OPENCLAW_FALLBACK_URL:-http://host.docker.internal:11434}\"}"
  set_ui="$set_ui,{\"path\":\"models.providers.ollama.api\",\"value\":\"ollama\"},{\"path\":\"models.providers.ollama.apiKey\",\"value\":\"ollama-local\"}"
  set_ui="$set_ui,{\"path\":\"models.providers.ollama.models\",\"value\":[{\"id\":\"$tag\",\"name\":\"$tag\"}]}" ;;
esac
# OPENCLAW_USERS: Edgible's sign-in in front is the Gateway's auth (trusted-proxy). Edgible sets
# X-Auth-Email and drops any a client sends; only these people get in, and their browsers are
# approved as they arrive, with OpenClaw's default operator scopes (not admin). No token to paste.
if [ -n "${OPENCLAW_USERS:-}" ]; then
  users=$(printf '%s' "$OPENCLAW_USERS" | tr ',' '\n' | sed 's/^ *//; s/ *$//' | grep . | sed 's/.*/"&"/' | paste -sd, -)
  set_ui="$set_ui,{\"path\":\"gateway.auth.mode\",\"value\":\"trusted-proxy\"}"
  set_ui="$set_ui,{\"path\":\"gateway.auth.trustedProxy\",\"value\":{\"userHeader\":\"x-auth-email\",\"requiredHeaders\":[\"x-auth-type\"],\"allowUsers\":[$users],\"deviceAutoApprove\":{\"enabled\":true}}}"
fi
oc config set --batch-json "[$set_ui]"

# OPENCLAW_MODEL_CHOICES: the models an OpenAI-compatible address offers, such as an AI gateway's
# fast,smart,best,private,private-smart, so OpenClaw's model picker lists them all, not only the default.
if [ "$OPENCLAW_MODEL_PROVIDER" = openai-compatible ] && [ -n "${OPENCLAW_MODEL_CHOICES:-}" ]; then
  provider=$(node -e 'const c=require(process.env.OPENCLAW_CONFIG_PATH); console.log(Object.keys((c.models||{}).providers||{}).find((k)=>k.startsWith("custom-"))||"")')
  list=$(printf '%s' "$OPENCLAW_MODEL_CHOICES" | tr ',' '\n' | sed 's/^ *//; s/ *$//' | grep . \
    | sed 's/.*/{"id":"&","name":"&","contextWindow":128000,"maxTokens":4096,"input":["text"]}/' | paste -sd, -)
  [ -n "$provider" ] && oc config set --batch-json "[{\"path\":\"models.providers.$provider.models\",\"value\":[$list]}]"
fi

# The fallback goes through OpenClaw's own command, which only takes a model in its catalog: so
# refresh that provider's list first. Other providers, such as DeepSeek, read their key from the
# environment.
if [ -n "${OPENCLAW_FALLBACK_MODEL:-}" ]; then
  oc models list --refresh --provider "${OPENCLAW_FALLBACK_MODEL%%/*}" >/dev/null 2>&1 || true
  oc models fallbacks add "$OPENCLAW_FALLBACK_MODEL"
fi

if [ -n "${EDGIBLE_MCP_URL:-}" ]; then
  # The Gateway reaches it on this Compose network; this one-shot container may not, so no probe.
  oc mcp add edgible --url "$EDGIBLE_MCP_URL" --transport streamable-http --header "X-MCP-User=OpenClaw" --no-probe
fi
if [ "${EDGIBLE_SKILL:-0}" = 1 ]; then
  skill=$(mktemp -d)
  curl -fsSL https://codeload.github.com/edgible-org/card-kit/tar.gz/refs/heads/main \
    | tar -xz -C "$skill" --strip-components=3 card-kit-main/skills/edgible-cards/SKILL.md \
        card-kit-main/skills/edgible-cards/needs-map.yaml card-kit-main/skills/edgible-cards/EXAMPLES.md
  oc skills install "$skill" --as edgible-cards
  rm -rf "$skill"
fi
echo "openclaw-setup: ready for $OPENCLAW_URL"
