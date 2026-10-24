#!/bin/sh
# Install pinned releases of Ollama and Caddy into this card's directory and run them as two
# background services (launchd agents) that start at login: Ollama, listening on this Mac only, and a
# small Caddy proxy in front of it that Edgible publishes. Run it with card.env exported:
#
#   set -a; . ollama-osx/card.env; set +a
#   sh ollama-osx/install.sh
#
# Running it again restarts the services; with a new version below, it upgrades.
set -eu

VERSION=0.40.4
SHA256=a4ceae4b2aaf18df37ebcbfb56ba3a37a87838631112d66c2be07268693c8d58
# Caddy publishes SHA-512 sums, so that is what the download is checked against.
CADDY_VERSION=2.11.7
CADDY_SHA512=68f592df8f0ec058fbdb9b137b64e9a0aa792d28c06e1e3b9ec12d0e7fb371683a54e73ef6d8e6d0dd70dc6b941a5b5d5b73faedd3f89de119ad2eb78bdc668e

: "${SERVICE:?set SERVICE in card.env}" "${OLLAMA_LOCAL_PORT:?set OLLAMA_LOCAL_PORT in card.env}" \
  "${OLLAMA_PORT:?set OLLAMA_PORT in card.env}"
if [ "$OLLAMA_LOCAL_PORT" = "$OLLAMA_PORT" ]; then
  echo "OLLAMA_LOCAL_PORT and OLLAMA_PORT are both $OLLAMA_LOCAL_PORT; Ollama and its proxy need a port each" >&2
  exit 1
fi
if [ "$(uname -s)" != Darwin ] || [ "$(uname -m)" != arm64 ]; then
  echo "ollama-osx runs on an Apple Silicon Mac; use the ollama card elsewhere" >&2
  exit 1
fi
dir=$(cd "$(dirname "$0")" && pwd)
models=${OLLAMA_MODELS:-$dir/models}
case $models in "~/"*) models="$HOME/${models#\~/}" ;; esac

# Ollama, checked against its published SHA-256 before anything is unpacked.
app="$dir/.native/ollama-$VERSION"
if [ ! -x "$app/ollama" ]; then
  mkdir -p "$dir/.native"
  tgz="$dir/.native/ollama-darwin-$VERSION.tgz"
  curl -fsSL -o "$tgz" "https://github.com/ollama/ollama/releases/download/v$VERSION/ollama-darwin.tgz"
  if ! echo "$SHA256  $tgz" | shasum -a 256 -c - >/dev/null; then
    rm -f "$tgz"
    echo "the Ollama download does not match its SHA-256; nothing was installed" >&2
    exit 1
  fi
  mkdir -p "$app"
  tar -xzf "$tgz" -C "$app"
  rm -f "$tgz"
fi
# Caddy, the same way, against its SHA-512.
caddy="$dir/.native/caddy-$CADDY_VERSION"
if [ ! -x "$caddy/caddy" ]; then
  mkdir -p "$dir/.native"
  tgz="$dir/.native/caddy-$CADDY_VERSION.tgz"
  curl -fsSL -o "$tgz" "https://github.com/caddyserver/caddy/releases/download/v$CADDY_VERSION/caddy_${CADDY_VERSION}_mac_arm64.tar.gz"
  if ! echo "$CADDY_SHA512  $tgz" | shasum -a 512 -c - >/dev/null; then
    rm -f "$tgz"
    echo "the Caddy download does not match its SHA-512; nothing was installed" >&2
    exit 1
  fi
  mkdir -p "$caddy"
  tar -xzf "$tgz" -C "$caddy" caddy
  rm -f "$tgz"
fi
# An earlier version, after an upgrade.
for old in "$dir"/.native/ollama-* "$dir"/.native/caddy-*; do
  [ "$old" = "$app" ] || [ "$old" = "$caddy" ] || rm -rf "$old"
done

# The proxy's rules. Ollama refuses a request whose Host is not localhost, and Edgible forwards the
# app's own hostname, so the proxy takes any Host (the site has none: it is bound to 127.0.0.1 only)
# and sets Host to localhost. It lets through only what a client
# needs to use a model, so a key cannot pull, create, copy or delete models; do those on the Mac.
mkdir -p "$models" "$dir/logs" "$dir/.native/caddy-data" "$HOME/Library/LaunchAgents"
cat > "$dir/.native/Caddyfile" <<CADDYFILE
{
	admin off
	auto_https off
}
:$OLLAMA_PORT {
	bind 127.0.0.1
	@use path / /api/chat /api/generate /api/embed /api/embeddings /api/tags /api/show /api/ps /api/version /v1/*
	handle @use {
		reverse_proxy 127.0.0.1:$OLLAMA_LOCAL_PORT {
			header_up Host localhost:$OLLAMA_LOCAL_PORT
		}
	}
	handle {
		respond "Not available through this address: manage models on the Mac itself." 403
	}
}
CADDYFILE

# The services.
launchctl bootout "gui/$(id -u)/$SERVICE-proxy" 2>/dev/null || true
launchctl bootout "gui/$(id -u)/$SERVICE" 2>/dev/null || true
# With this card's own services stopped, both ports must be free: another Ollama, or anything else,
# listening on one would answer the checks below in their place, and the card would look installed.
sleep 1
for port in "$OLLAMA_LOCAL_PORT" "$OLLAMA_PORT"; do
  if lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1; then
    echo "port $port is in use by $(lsof -nP -iTCP:"$port" -sTCP:LISTEN | awk 'NR==2{print $1}'); set OLLAMA_LOCAL_PORT or OLLAMA_PORT in card.env to a free port" >&2
    exit 1
  fi
done
cat > "$HOME/Library/LaunchAgents/$SERVICE.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$SERVICE</string>
  <key>ProgramArguments</key><array><string>$app/ollama</string><string>serve</string></array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>OLLAMA_HOST</key><string>127.0.0.1:$OLLAMA_LOCAL_PORT</string>
    <key>OLLAMA_MODELS</key><string>$models</string>
  </dict>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardOutPath</key><string>$dir/logs/ollama.log</string>
  <key>StandardErrorPath</key><string>$dir/logs/ollama.log</string>
</dict>
</plist>
PLIST
cat > "$HOME/Library/LaunchAgents/$SERVICE-proxy.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$SERVICE-proxy</string>
  <key>ProgramArguments</key><array><string>$caddy/caddy</string><string>run</string><string>--config</string><string>$dir/.native/Caddyfile</string><string>--adapter</string><string>caddyfile</string></array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>XDG_DATA_HOME</key><string>$dir/.native/caddy-data</string>
    <key>XDG_CONFIG_HOME</key><string>$dir/.native/caddy-data</string>
  </dict>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardOutPath</key><string>$dir/logs/proxy.log</string>
  <key>StandardErrorPath</key><string>$dir/logs/proxy.log</string>
</dict>
</plist>
PLIST
launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/$SERVICE.plist"
launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/$SERVICE-proxy.plist"

for _ in $(seq 60); do
  if version=$(curl -fsS "http://127.0.0.1:$OLLAMA_LOCAL_PORT/api/version" 2>/dev/null) &&
     curl -fsS "http://127.0.0.1:$OLLAMA_PORT/api/version" >/dev/null 2>&1; then
    echo "Ollama $VERSION is running on 127.0.0.1:$OLLAMA_LOCAL_PORT ($version), models in $models; the proxy is on 127.0.0.1:$OLLAMA_PORT"
    exit 0
  fi
  sleep 1
done
echo "Ollama or its proxy did not answer; see $dir/logs/ollama.log and $dir/logs/proxy.log" >&2
exit 1
