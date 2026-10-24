#!/bin/sh
# Nothing on this Mac's network can reach Ollama or its proxy: both listen on 127.0.0.1 only.
set -eu
for port in "$OLLAMA_LOCAL_PORT" "$OLLAMA_PORT"; do
  listening=$(lsof -nP -iTCP:"$port" -sTCP:LISTEN | tail -n +2 | awk '{print $9}')
  [ -n "$listening" ] || { echo "nothing listens on port $port"; exit 1; }
  wrong=$(echo "$listening" | grep -v '^127\.0\.0\.1:' || true)
  [ -z "$wrong" ] || { echo "port $port listens beyond this Mac: $wrong"; exit 1; }
done
echo "Ollama (:$OLLAMA_LOCAL_PORT) and the proxy (:$OLLAMA_PORT) listen on 127.0.0.1 only"
