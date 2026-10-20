# openclaw

## Why

[OpenClaw](https://openclaw.ai) is the open-source AI agent most people are trying: it chats, remembers, runs commands, edits files and works through messaging apps. It holds your keys and has a shell, so it belongs on a machine you are willing to hand it, and its Control UI is an admin console that should never sit open on the internet. This card runs it from OpenClaw's own image, with the Gateway on this machine's loopback only and the Control UI reached through Edgible behind your organisation's sign-in. It follows Edgible's [OpenClaw on Edgible](https://guides.edgible.com/guides/openclaw-on-edgible/) guide.

## What

One app, `openclaw`, on `org`: the Gateway and its Control UI, from `ghcr.io/openclaw/openclaw`, pinned. Three locks stand in front of it: Edgible's sign-in, which only your organisation passes; OpenClaw's Gateway token, pasted once per browser; and a device approval you give on the machine. The port is published on loopback only, and the containers run as OpenClaw's own user with no extra capabilities and no Docker socket, so the agent's sandbox mode is off. On the first Start, `openclaw-setup` runs OpenClaw's headless onboarding: token auth, the model, the Control UI's allowed address, no channels and no third-party skills. Keys stay in `card.env` and reach OpenClaw as environment variables, never written into its files. The model is your choice: a free Google AI Studio key for Gemini Flash (the default), or any OpenAI-compatible address, such as the ollama-mac card on the same Mac (`http://host.docker.internal:11434/v1`), which keeps every word on your machine. OpenClaw leans on tools, so small local models (7B) answer clumsily: prefer Gemini Flash, or a larger local model. `OPENCLAW_FALLBACK_MODEL` names a model that answers a turn when the main one fails, such as a free tier's 429: `deepseek/deepseek-flash` (fast, cents a day, with `DEEPSEEK_API_KEY`) or a small local one such as `ollama/qwen2.5:7b`, which is free but weak with tools. The Gateway trusts exactly one proxy, the Compose network's gateway address, through which Edgible's web server reaches it, and refuses a proxied request that does not say who the client is: so open the Control UI at its Edgible address, not at `http://127.0.0.1:18789`. Telegram, WhatsApp, skills and other models are added afterwards with `openclaw-cli`, as the guide's later chapters show.

The agent's config, memory, sessions and workspace live in the volume `openclaw-data`, and sign-in profiles for providers that use them in `openclaw-secrets`. Both are what makes the agent yours: back them up. Minimum recommended for the place `openclaw`: 2.5 GB of memory and 3 GB of disk, on an arm64 or amd64 machine, with no GPU.

The Compose file is [docker-compose.yml](docker-compose.yml), the settings [card.env](card.env), the card [card.yml](card.yml), and the last test [test.yml](test.yml).

## How

Five steps. Edit [card.env](card.env) before you start.

### 1. Fetch

```bash
mkdir -p openclaw
curl -fsSL https://github.com/edgible-org/cards/archive/refs/heads/main.tar.gz \
  | tar -xz --strip-components=2 -C openclaw cards-main/openclaw
```

### 2. Edit card.env

Set `DEVICE` to a name `edgible device list` prints and `ORG_LABEL`. Start makes the Gateway token on the machine; there is nothing to fill for it. For Gemini, put a key from https://aistudio.google.com/apikey in `GEMINI_API_KEY`, and keep a Flash model in `OPENCLAW_MODEL`: the free tier refuses Pro and preview models. For a model on this Mac, set `OPENCLAW_MODEL_PROVIDER=openai-compatible`, `OPENCLAW_MODEL_URL=http://host.docker.internal:11434/v1` and `OPENCLAW_MODEL` to the model's name, such as `qwen3.5:27b`. For a fallback when Gemini's free tier runs out, set `OPENCLAW_FALLBACK_MODEL=deepseek/deepseek-flash` and `DEEPSEEK_API_KEY`, or `ollama/qwen2.5:7b` with ollama-mac on the same Mac. Set `OPENCLAW_TZ` to your time zone.

```bash
nano openclaw/card.env
```

### 3. Check

```bash
curl -fsSLo check-env.py https://raw.githubusercontent.com/edgible-org/card-kit/main/check-env.py
python3 check-env.py openclaw
```

It fills each empty secret and moves a taken port, as lines to paste. Run it again until it says `no conflicts`.

### 4. Start

```bash
docker compose --env-file openclaw/card.env -f openclaw/docker-compose.yml up -d --wait
docker compose --env-file openclaw/card.env -f openclaw/docker-compose.yml ps
```

`--wait` returns when each service is running, and healthy when it has a healthcheck. `openclaw-setup` runs first, once, then the Gateway starts. To change the model or other settings later, use OpenClaw's own commands through `openclaw-cli`, which shares the Gateway's processes, always with `--no-deps`: `docker compose --env-file openclaw/card.env -f openclaw/docker-compose.yml run --rm --no-deps openclaw-cli config set agents.defaults.model.primary <model>`. A first hello from the machine: `docker compose --env-file openclaw/card.env -f openclaw/docker-compose.yml run --rm --no-deps openclaw-cli agent --agent main --message hello`.

### 5. Publish

```bash
set -euo pipefail
set -a
. openclaw/card.env
set +a
device_id=$(edgible device list --json | jq -er --arg name "$DEVICE" '
  map(select(.name == $name))
  | if length == 1 then .[0].id
    else error("need exactly one device named " + $name + " (" + (map(.status + " " + .id) | join(", ")) + ")")
    end
')
edgible app create existing \
  --non-interactive \
  --name openclaw \
  --port "$OPENCLAW_PORT" \
  --protocol https \
  --auth-modes org \
  --device-id "$device_id"
edgible app list
```

**Without Edgible:** only Publish is Edgible's. The app listens on `127.0.0.1` at the port in `card.env`, so any reverse proxy or tunnel on the machine, such as Caddy, nginx, Cloudflare Tunnel or Tailscale, can publish it instead, and sign-in is then that tool's to provide. Every other step stays the same.

## Verify

`openclaw` uses `org`.

```bash
curl -sS -o /dev/null -w '%{http_code} %{redirect_url}\n' "https://<openclaw hostname>"
```

That prints `302` and an `edgible.com/application-access/` address, so the org sign-in is in front. Then open the hostname on your phone or laptop and sign in. The Control UI asks for the Gateway token: open `https://<openclaw hostname>/#token=<OPENCLAW_GATEWAY_TOKEN>` once in that browser (`docker compose --env-file openclaw/card.env -f openclaw/docker-compose.yml run --rm --no-deps openclaw-secrets show OPENCLAW_GATEWAY_TOKEN` prints the token, which the card made on the machine). Then it waits for pairing: on the machine, `docker compose --env-file openclaw/card.env -f openclaw/docker-compose.yml run --rm --no-deps openclaw-cli devices list` shows the request, and `devices approve <requestId>` lets that browser in. Chat works from then on.

The rest of the setup is in the [OpenClaw docs docs](https://docs.openclaw.ai).

## Tear down

Four steps, in this order. Step 1 runs wherever `edgible` is logged in. Steps 2 to 4 run on the machine that runs the containers. Steps 2 and 3 read `card.env`, so keep it until step 4.

### 1. Unpublish

```bash
edgible app delete openclaw --yes
```

### 2. Stop

```bash
docker compose --env-file openclaw/card.env -f openclaw/docker-compose.yml down
```

### 3. Delete the data

Skip this step to keep the data. The loop copies each volume to a `.tgz` file in this directory first.

```bash
for volume in $(docker volume ls -q --filter label=com.docker.compose.project=openclaw); do
  docker run --rm -v "$volume:/data:ro" -v "$PWD:/backup" alpine tar -czf "/backup/$volume.tgz" -C /data .
done
docker compose --env-file openclaw/card.env -f openclaw/docker-compose.yml down --volumes
```

### 4. Remove the card

```bash
rm -rf openclaw
```
