#!/bin/sh
# Install a pinned Ollama release into this card's directory and run it as a background
# service (a launchd agent) that starts at login. Run it with card.env exported:
#
#   set -a; . ollama-mac/card.env; set +a
#   sh ollama-mac/install.sh
#
# Running it again restarts the service; with a new VERSION, it upgrades.
set -eu

VERSION=0.40.4
SHA256=a4ceae4b2aaf18df37ebcbfb56ba3a37a87838631112d66c2be07268693c8d58

: "${SERVICE:?set SERVICE in card.env}" "${OLLAMA_PORT:?set OLLAMA_PORT in card.env}"
OLLAMA_BIND=${OLLAMA_BIND:-0.0.0.0}
if [ "$(uname -s)" != Darwin ] || [ "$(uname -m)" != arm64 ]; then
  echo "ollama-mac runs on an Apple Silicon Mac; use the ollama card elsewhere" >&2
  exit 1
fi
dir=$(cd "$(dirname "$0")" && pwd)
models=${OLLAMA_MODELS:-$dir/models}
case $models in "~/"*) models="$HOME/${models#\~/}" ;; esac

# The release, checked against its published SHA-256 before anything is unpacked.
app="$dir/.native/ollama-$VERSION"
if [ ! -x "$app/ollama" ]; then
  mkdir -p "$dir/.native"
  tgz="$dir/.native/ollama-darwin-$VERSION.tgz"
  curl -fsSL -o "$tgz" "https://github.com/ollama/ollama/releases/download/v$VERSION/ollama-darwin.tgz"
  if ! echo "$SHA256  $tgz" | shasum -a 256 -c - >/dev/null; then
    rm -f "$tgz"
    echo "the download does not match its SHA-256; nothing was installed" >&2
    exit 1
  fi
  mkdir -p "$app"
  tar -xzf "$tgz" -C "$app"
  rm -f "$tgz"
fi
# An earlier version, after an upgrade.
for old in "$dir"/.native/ollama-*; do
  [ "$old" = "$app" ] || rm -rf "$old"
done

# The service. Ollama listens on OLLAMA_BIND (all addresses by default: card.env says why);
# Edgible publishes the port and puts the API key in front of it.
mkdir -p "$models" "$dir/logs" "$HOME/Library/LaunchAgents"
plist="$HOME/Library/LaunchAgents/$SERVICE.plist"
cat > "$plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$SERVICE</string>
  <key>ProgramArguments</key><array><string>$app/ollama</string><string>serve</string></array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>OLLAMA_HOST</key><string>$OLLAMA_BIND:$OLLAMA_PORT</string>
    <key>OLLAMA_MODELS</key><string>$models</string>
  </dict>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardOutPath</key><string>$dir/logs/ollama.log</string>
  <key>StandardErrorPath</key><string>$dir/logs/ollama.log</string>
</dict>
</plist>
PLIST
launchctl bootout "gui/$(id -u)/$SERVICE" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$plist"

for _ in $(seq 60); do
  if version=$(curl -fsS "http://127.0.0.1:$OLLAMA_PORT/api/version" 2>/dev/null); then
    echo "Ollama $VERSION is running on $OLLAMA_BIND:$OLLAMA_PORT ($version), models in $models"
    exit 0
  fi
  sleep 1
done
echo "Ollama did not answer on port $OLLAMA_PORT; see $dir/logs/ollama.log" >&2
exit 1
