# ollama-mac

## Why

[Ollama](https://ollama.com) runs open models, such as Llama, Qwen, Mistral, and gpt-oss, on your own machine, behind one API that many tools speak. On an Apple Silicon Mac it is fast because it runs them on the Mac's GPU. In Docker it cannot: Docker on macOS runs a Linux VM with no access to the GPU, so the same models run several times slower on the CPU. This card runs Ollama on the Mac itself, and Edgible publishes it, so your tools and AI agents can use your models from anywhere, behind an API key, without a cloud provider seeing your prompts. On Linux or Windows, Ollama runs well in Docker, and an ollama card for that is planned.

## What

One app, `ollama`, the Ollama API on `api-key`: without a key it answers `401`, and with one any client that speaks Ollama's API works, such as Open WebUI, Continue, or your own scripts, with the key sent as `Authorization: Bearer <key>`. Ollama has no login of its own, so the key is what keeps strangers off your GPU. It listens on every address of this Mac (`OLLAMA_BIND=0.0.0.0`), and Edgible publishes it.

**Read this before you start.** Ollama refuses any request whose `Host` is not localhost when it listens on 127.0.0.1 only, and Edgible forwards the app's own hostname, so a loopback-only Ollama answers every published call with `403`, key or not. Listening on all addresses fixes that, and it means anything on this Mac's network can reach Ollama without a key. Use the card on a network you trust, and never forward the port on your router. Set `OLLAMA_BIND=127.0.0.1` to keep Ollama private to this Mac; then only clients on the Mac work, not the published app.

The models live in the folder `OLLAMA_MODELS` names, by default `models/` in the card's directory. Plan for them: a small model takes 2 to 5 GB, a large one 20 to 40 GB, and a model needs about its own size in memory to run. Minimum recommended for the place `ollama`: an Apple Silicon Mac with 8 GB of memory and 2 GB of disk; it runs on the Mac's GPU.

This card runs natively on macOS, not in Docker. [install.sh](install.sh) installs release 0.40.4, checked against its SHA-256, into the card's own directory and starts it as a background service; [uninstall.sh](uninstall.sh) removes both. The settings are [card.env](card.env), the card [card.yml](card.yml), and the last test [test.yml](test.yml).

## How

Five steps. Edit [card.env](card.env) before you start.

### 1. Fetch

```bash
mkdir -p ollama-mac
curl -fsSL https://github.com/edgible-org/cards/archive/refs/heads/main.tar.gz \
  | tar -xz --strip-components=2 -C ollama-mac cards-main/ollama-mac
```

### 2. Edit card.env

Set `DEVICE` and `ORG_LABEL`. Keep `OLLAMA_PORT` at `11434`, the port Ollama's clients expect, unless Check says it is taken, as it is when another Ollama already runs on this Mac. To keep the models an earlier Ollama install downloaded, set `OLLAMA_MODELS=~/.ollama/models`, and stop that Ollama first (quit the Ollama app, or `brew services stop ollama`), so two never use the folder at once.

```bash
nano ollama-mac/card.env
```

### 3. Check

```bash
curl -fsSLo check-env.py https://raw.githubusercontent.com/edgible-org/card-kit/main/check-env.py
python3 check-env.py ollama-mac
```

It checks this machine, the port, and the service name, and prints any fix as lines to paste. Run it again until it says `no conflicts`.

### 4. Install

```bash
set -a
. ollama-mac/card.env
set +a
sh ollama-mac/install.sh
```

It prints the version and where the models are. The service starts again at each login, and runs while your user is logged in: for a Mac that serves while nobody uses it, turn on automatic login. Then download a model, such as `curl http://127.0.0.1:$OLLAMA_PORT/api/pull -d '{"model": "llama3.2"}'`, or with the release's own command: `OLLAMA_HOST=127.0.0.1:$OLLAMA_PORT ollama-mac/.native/ollama-*/ollama pull llama3.2`.

### 5. Publish

```bash
set -euo pipefail
set -a
. ollama-mac/card.env
set +a
device_id=$(edgible device list --json | jq -er --arg name "$DEVICE" '
  map(select(.name == $name))
  | if length == 1 then .[0].id
    else error("need exactly one device named " + $name + " (" + (map(.status + " " + .id) | join(", ")) + ")")
    end
')
edgible app create existing \
  --non-interactive \
  --name ollama \
  --port "$OLLAMA_PORT" \
  --protocol https \
  --auth-modes api-key \
  --device-id "$device_id"
edgible app list
```

## Verify

`ollama` uses `api-key`. Without a key, it answers `401`.

```bash
curl -sS -o /dev/null -w '%{http_code}\n' "https://<ollama hostname>"
```

Make a key for each person or tool, which is shown once: `edgible app api-keys create --app ollama --name <who>`. Then `curl -H "Authorization: Bearer <key>" https://<ollama hostname>/api/tags` lists your models. `edgible app api-keys list --app ollama` and `delete` manage the keys. The card's tests also ask a tiny model a question and check, with `/api/ps`, that it ran 100% on the GPU, and make a key, call the published app with it from this Mac (`401` without the key, `200` with it), and delete the key.


The rest of the setup is in the [Ollama docs](https://github.com/ollama/ollama/tree/main/docs).

## Tear down

Three steps, in this order. Step 1 runs wherever `edgible` is logged in, steps 2 and 3 on the machine that runs the card.

### 1. Unpublish

```bash
edgible app delete ollama --yes
```

### 2. Uninstall

```bash
set -a
. ollama-mac/card.env
set +a
sh ollama-mac/uninstall.sh
```

It stops the service and removes it and the release. The models stay: `models/` in the card's directory goes in step 3, and a folder elsewhere (`OLLAMA_MODELS`) is never deleted, because it is not this card's.

### 3. Remove the card

```bash
rm -rf ollama-mac
```
