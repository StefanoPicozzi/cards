# edgible-agent

## Why

Most people trying an AI agent want it to do things for them, not just chat. This pattern gives you one: [OpenClaw](https://openclaw.ai), on a machine you own, that also looks after your Edgible apps. From your phone you can ask it what is running and whether each app answers, have it find a card for a need, and, if you allow it, have it deploy, move or remove apps, each change asked of you first. It is built from the [openclaw](https://github.com/edgible-org/cards/tree/main/openclaw) and [edgible-mcp](https://github.com/edgible-org/cards/tree/main/edgible-mcp) app cards.

## What

Three containers on one machine, in one Compose project. `openclaw` is OpenClaw's Gateway and Control UI, published as `openclaw` on `org`, then OpenClaw's Gateway token and device approval, as in the openclaw card. `edgible-mcp` is Edgible's MCP server, with no address of its own: OpenClaw reaches it on the project's network, and nothing else can. On the first Start, `openclaw-setup` onboards OpenClaw, adds edgible-mcp's tools as the MCP server `edgible`, and installs the edgible-cards skill from card-kit, so the agent knows the honest-advice rules as well as the tools. The tools only read unless `EDGIBLE_MCP_ALLOW_WRITE=1`; then deploy_card, move_card and remove_card ask first, each change is recorded as made by OpenClaw, and `EDGIBLE_MCP_DEVICES` limits which devices may change. The agent acts as the Edgible CLI inside edgible-mcp, signed in once after Start: sign it in as an account that may do what you allow. The model is a Gemini key (Flash) or any OpenAI-compatible address, with an optional fallback, such as DeepSeek V4 Flash, for when the main model fails.

The agent's config, memory, sessions and workspace live in `openclaw-data`, and provider sign-in profiles in `openclaw-secrets`: back them up. `edgible-mcp-login` holds the CLI's sign-in (lost, sign in again), `edgible-mcp-data` the record of what the tools did, and `edgible-mcp-cache` the catalog. Minimum recommended for the place `agent`: 2.5 GB of memory and 3 GB of disk, on an arm64 or amd64 machine, with no GPU.

The Compose file is [docker-compose.yml](docker-compose.yml), the settings [card.env](card.env), the card [card.yml](card.yml), and the last test [test.yml](test.yml).

## How

Five steps. Edit [card.env](card.env) before you start.

### 1. Fetch

```bash
mkdir -p edgible-agent
curl -fsSL https://github.com/edgible-org/cards/archive/refs/heads/main.tar.gz \
  | tar -xz --strip-components=2 -C edgible-agent cards-main/edgible-agent
```

### 2. Edit card.env

Set `DEVICE`, `ORG_LABEL` and `GEMINI_API_KEY` (a key from https://aistudio.google.com/apikey; keep a Flash model in `OPENCLAW_MODEL`). Check fills `OPENCLAW_GATEWAY_TOKEN`. For when Gemini's free tier runs out, `OPENCLAW_FALLBACK_MODEL=deepseek/deepseek-flash` with `DEEPSEEK_API_KEY` (cents a day), or `ollama/qwen2.5:7b` on a Mac with ollama-mac (free, but weak with tools). Set `EDGIBLE_MCP_ALLOW_WRITE=1` to let the agent deploy, move and remove apps, and `EDGIBLE_MCP_DEVICES` to keep it to some devices, such as a test machine.

```bash
nano edgible-agent/card.env
```

### 3. Check

```bash
curl -fsSLo check-env.py https://raw.githubusercontent.com/edgible-org/card-kit/main/check-env.py
python3 check-env.py edgible-agent
```

It fills each empty secret and moves a taken port, as lines to paste. Run it again until it says `no conflicts`.

### 4. Start

```bash
docker compose --env-file edgible-agent/card.env -f edgible-agent/docker-compose.yml up -d --wait
docker compose --env-file edgible-agent/card.env -f edgible-agent/docker-compose.yml ps
```

`--wait` returns when each service is running, and healthy when it has a healthcheck. Then sign the Edgible tools in, once: `docker compose --env-file edgible-agent/card.env -f edgible-agent/docker-compose.yml exec edgible-mcp edgible auth login --no-browser` prints a link and a code: open the link, check the code, approve. Change OpenClaw's settings later through `openclaw-cli`, always with `--no-deps`, as in the openclaw card.

### 5. Publish

```bash
set -euo pipefail
set -a
. edgible-agent/card.env
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

That prints `302` and an `edgible.com/application-access/` address, so the org sign-in is in front. Then open the hostname on your phone and sign in; open `https://<openclaw hostname>/#token=<OPENCLAW_GATEWAY_TOKEN>` once in that browser (the token is in `card.env`); approve the browser on the machine: `docker compose --env-file edgible-agent/card.env -f edgible-agent/docker-compose.yml run --rm --no-deps openclaw-cli devices list`, then `devices approve <requestId>`. Start a chat and ask "What Edgible apps are running?".

The rest of the setup is in the [OpenClaw docs docs](https://docs.openclaw.ai).

## Tear down

Four steps, in this order. Step 1 runs wherever `edgible` is logged in. Steps 2 to 4 run on the machine that runs the containers. Steps 2 and 3 read `card.env`, so keep it until step 4.

### 1. Unpublish

```bash
edgible app delete openclaw --yes
```

### 2. Stop

```bash
docker compose --env-file edgible-agent/card.env -f edgible-agent/docker-compose.yml down
```

### 3. Delete the data

Skip this step to keep the data. The loop copies each volume to a `.tgz` file in this directory first.

```bash
for volume in $(docker volume ls -q --filter label=com.docker.compose.project=edgible-agent); do
  docker run --rm -v "$volume:/data:ro" -v "$PWD:/backup" alpine tar -czf "/backup/$volume.tgz" -C /data .
done
docker compose --env-file edgible-agent/card.env -f edgible-agent/docker-compose.yml down --volumes
```

### 4. Remove the card

```bash
rm -rf edgible-agent
```
