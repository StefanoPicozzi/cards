#!/bin/sh
# One-shot set-up for the openclaw card, run by the openclaw-setup service before the Gateway
# starts. On the first start it runs OpenClaw's headless onboarding: Gateway token auth, keys kept
# as references to environment variables (never written into openclaw.json), no channels or
# third-party skills; then it sets the model and the Control UI's allowed origin. Later starts
# change nothing: OpenClaw locks its config while the Gateway runs. Change settings afterwards
# with openclaw-cli, which shares the Gateway's processes (see the card's README).
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
if [ "$OPENCLAW_MODEL_PROVIDER" = gemini ]; then
  oc config set --batch-json "[$set_ui,{\"path\":\"agents.defaults.model.primary\",\"value\":\"$OPENCLAW_MODEL\"}]"
else
  oc config set --batch-json "[$set_ui]"
fi
echo "openclaw-setup: ready for $OPENCLAW_URL"
