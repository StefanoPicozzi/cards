#!/bin/sh
# Ollama answers a prompt, and runs the model on the Mac's GPU, which is what this card is for.
# A tiny model (about 270 MB), pulled into the card's own models folder.
set -eu
api="http://127.0.0.1:$OLLAMA_LOCAL_PORT/api"
model=smollm2:135m
curl -fsS "$api/pull" -d "{\"model\":\"$model\",\"stream\":false}" >/dev/null
answer=$(curl -fsS "$api/generate" -d "{\"model\":\"$model\",\"prompt\":\"Say hi.\",\"stream\":false,\"options\":{\"num_predict\":8}}")
echo "$answer" | grep -q '"response":"[^"]' || { echo "no answer: $answer"; exit 1; }
ps=$(curl -fsS "$api/ps")
size=$(echo "$ps" | sed -n 's/.*"size":\([0-9]*\).*/\1/p')
vram=$(echo "$ps" | sed -n 's/.*"size_vram":\([0-9]*\).*/\1/p')
[ -n "$vram" ] && [ "$vram" -gt 0 ] && [ "$vram" = "$size" ] || { echo "not on the GPU: $ps"; exit 1; }
echo "answered, 100% on the GPU"
