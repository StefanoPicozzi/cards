#!/bin/sh
# Stop the services and remove what install.sh installed: the service files, Ollama and the proxy.
# The models stay: in this card's directory they go when you remove the card, and anywhere
# else (OLLAMA_MODELS) they are not this card's to delete. Run it with card.env exported:
#
#   set -a; . ollama-mac/card.env; set +a
#   sh ollama-mac/uninstall.sh
set -eu

: "${SERVICE:?set SERVICE in card.env}"
dir=$(cd "$(dirname "$0")" && pwd)

for s in "$SERVICE-proxy" "$SERVICE"; do
  launchctl bootout "gui/$(id -u)/$s" 2>/dev/null || true
  rm -f "$HOME/Library/LaunchAgents/$s.plist"
done
rm -rf "$dir/.native"
echo "removed the $SERVICE services, Ollama and its proxy; the models are where they were"
