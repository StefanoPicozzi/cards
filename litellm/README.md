# litellm

## Why

Every AI app wants its own provider key, and every key is a chore: find the provider's key page, keep credit on the account, wire the key into each app, add a second provider when the first runs out, and wonder which app spent what. This card is an AI gateway in front of all of them, from [LiteLLM](https://docs.litellm.ai/). You give it each provider's key once; your apps call it at one address, by purpose (`fast`, `smart`, `best`, `private`, `private-smart`), each with a key of its own and a budget, and it falls back to another provider when one fails. Local models count too, so private questions need not leave your machine.

## What

One app, `litellm`, on the place `litellm`, behind Edgible's `org` sign-in: LiteLLM's admin and its OpenAI-compatible API, one process on port `4000`. Postgres runs beside it as `litellm-db`, for each app's key, budget and spend.

**Models by purpose.** [gateway.yaml](gateway.yaml) names six, each set in `card.env`. Fallbacks go sideways or down, never up to a dearer model, and a private model never falls back to one elsewhere:

| Name | Default | For |
| --- | --- | --- |
| `fast` | `deepseek/deepseek-chat` | Everyday answers, reliable and cents a day; falls back to `fast-fallback` |
| `fast-fallback` | `gemini/gemini-3.5-flash` | When `fast` fails; Gemini's free tier runs out quickly, so it is the fallback |
| `smart` | `deepseek/deepseek-reasoner` | Harder questions; falls back to `fast` |
| `best` | `anthropic/claude-opus-5-5` | When it really matters, dearest by far, asked for on purpose; capped at `LITELLM_BEST_BUDGET` ($5 per 30 days) across all apps, then falls back to `smart` |
| `private` | `ollama/qwen2.5:7b` at `LITELLM_PRIVATE_URL` | A model on your own machine, such as the ollama-mac card's; no fallback, so nothing leaves it |
| `private-smart` | `ollama/qwen3.5:27b` at `LITELLM_PRIVATE_URL` | A larger model on your own machine, where there is memory for it; falls back to `private` |

**Keys you bring** (`GEMINI_API_KEY`, `DEEPSEEK_API_KEY`, `ANTHROPIC_API_KEY`) are the only keys you handle. LiteLLM finds each in that provider's usual variable, so any provider it supports works the same way: add its variable to the Compose file and name its model. Deployed with Edgible's tools, a key comes from an Edgible organisation secret by reference and is never written down here.

**The gateway's own secrets are made on the machine** by `litellm-secrets`: the database password, the salt key that encrypts what the admin stores (it travels with the data on a move), and the master key, which signs you in to the admin as `admin`. See it with:

```bash
docker compose --env-file litellm/card.env -f litellm/docker-compose.yml run --rm --no-deps litellm-secrets show LITELLM_MASTER_KEY
```

**Each app has its own key.** An app beside the gateway, such as an agent in a pattern card, gets a key made on the device like any secret: a file `LITELLM_KEY_<APP>` in the volume `litellm-secrets`. At each start, [register-keys.py](register-keys.py) registers every such key that is new, named after the app, with `LITELLM_APP_BUDGET` dollars per `LITELLM_APP_BUDGET_PERIOD`. The admin then shows each app's spend. For an app on another machine, make its key in the admin. Never give an app the master key.

To use it in a card, copy the three services, both volumes, [gateway.yaml](gateway.yaml) and [register-keys.py](register-keys.py) with their `configs:`, and the `secrets:` of [card.yml](card.yml); declare the app's key there too, made by the same `litellm-secrets` service, and point the app at `http://litellm:4000/v1` with that key.

Each app's key, budget and spend live in `litellm-db-data`, and the gateway's secrets in `litellm-secrets`. Minimum recommended for the place `litellm`: 2.5 GB of memory and 2 GB of disk, on an arm64 or amd64 machine, with no GPU.

The Compose file is [docker-compose.yml](docker-compose.yml), the settings [card.env](card.env), and the card [card.yml](card.yml).

## Share it

One gateway can serve every app on every machine of yours, with one admin showing who spent what. Publish its API as a second app, `litellm-api`, on `none`: every call to it needs a key the gateway issued, and an unknown key gets `401`.

```bash
edgible app create existing --non-interactive --name litellm-api --port "$LITELLM_PORT" \
  --protocol https --auth-modes none --device-id "$device_id"
```

Then give each app its own key, made in the admin (Keys, Create key, with a budget), or by edgible-mcp's `gateway_key`, which makes the key and stores it as an Edgible organisation secret, so a deploy passes it to the app by reference and nobody sees it. Point the app at `https://<litellm-api hostname>/v1`. The admin's sign-in page also answers on that address, guarded by the master key; keep that key on the machine.

## How

Five steps. Edit [card.env](card.env) before you start.

### 1. Fetch

```bash
mkdir -p litellm
curl -fsSL https://github.com/edgible-org/cards/archive/refs/heads/main.tar.gz \
  | tar -xz --strip-components=2 -C litellm cards-main/litellm
```

### 2. Edit card.env

Set `DEVICE` to a name `edgible device list` prints. Put a key in `GEMINI_API_KEY`, `DEEPSEEK_API_KEY` or both; a model with no key fails, and its fallback answers. For `private`, point `LITELLM_PRIVATE_URL` at an Ollama, such as the ollama-mac card's on the same Mac (the default). There are no passwords to fill: Start makes them on the machine.

```bash
nano litellm/card.env
```

### 3. Check

```bash
curl -fsSLo check-env.py https://raw.githubusercontent.com/edgible-org/card-kit/main/check-env.py
python3 check-env.py litellm
```

It moves a taken port, as lines to paste. Run it again until it says `no conflicts`.

### 4. Start

```bash
docker compose --env-file litellm/card.env -f litellm/docker-compose.yml up -d --wait
docker compose --env-file litellm/card.env -f litellm/docker-compose.yml ps
```

`--wait` returns when each service is running, and healthy when it has a healthcheck. `litellm-secrets` makes the secrets first and exits.

### 5. Publish

```bash
set -euo pipefail
set -a
. litellm/card.env
set +a
device_id=$(edgible device list --json | jq -er --arg name "$DEVICE" '
  map(select(.name == $name))
  | if length == 1 then .[0].id
    else error("need exactly one device named " + $name + " (" + (map(.status + " " + .id) | join(", ")) + ")")
    end
')
edgible app create existing \
  --non-interactive \
  --name litellm \
  --port "$LITELLM_PORT" \
  --protocol https \
  --auth-modes org \
  --device-id "$device_id"
edgible app list
```

**Without Edgible:** only Publish is Edgible's. The gateway listens on `127.0.0.1` at the port in `card.env`, so any reverse proxy or tunnel on the machine can publish it instead, and sign-in is then that tool's to provide.

## Verify

`litellm` uses `org`.

```bash
curl -sS -o /dev/null -w '%{http_code} %{redirect_url}\n' "https://<litellm hostname>"
```

That prints `302` and an Edgible sign-in address. Open the hostname, sign in, open `/ui`, and sign in to the admin as `admin` with the master key. On the machine, the gateway answers only with a key:

```bash
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:4000/v1/models
```

That prints `401`. With an app's key it lists `fast`, `fast-fallback`, `smart`, `best`, `private` and `private-smart`.

The rest is in the [LiteLLM docs](https://docs.litellm.ai/).

## Tear down

Four steps, in this order. Step 1 runs wherever `edgible` is logged in. Steps 2 to 4 run on the machine that runs the containers. Steps 2 and 3 read `card.env`, so keep it until step 4.

### 1. Unpublish

```bash
edgible app delete litellm --yes
```

### 2. Stop

```bash
docker compose --env-file litellm/card.env -f litellm/docker-compose.yml down
```

### 3. Delete the data

Skip this step to keep the data. The loop copies each volume to a `.tgz` file in this directory first. `litellm-secrets.tgz` holds the gateway's keys: keep it as safe as the data, which needs them.

```bash
for volume in $(docker volume ls -q --filter label=com.docker.compose.project=litellm); do
  docker run --rm -v "$volume:/data:ro" -v "$PWD:/backup" alpine tar -czf "/backup/$volume.tgz" -C /data .
done
docker compose --env-file litellm/card.env -f litellm/docker-compose.yml down --volumes
```

### 4. Remove the card

```bash
rm -rf litellm
```
