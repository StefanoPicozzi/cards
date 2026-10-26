# edgible-mcp

## Why

Edgible's [cards](https://github.com/edgible-org/cards) are found, read, and checked from a terminal. This card puts them in front of Claude Code and other [MCP](https://modelcontextprotocol.io) clients wherever you are: an MCP server whose tools find a card for a need, app or pattern, describe one, and show what your organization runs and whether each app answers. Allowed to, it also deploys, moves and removes app cards on any device of your organization, asking first. For Claude's web, desktop and phone apps, use it behind [mcp-signin](https://github.com/edgible-org/cards/tree/main/mcp-signin), as the [edgible-connector](https://github.com/edgible-org/cards/tree/main/edgible-connector) pattern does.

## What

One app, `edgible-mcp`, on the place `edgible-mcp`, on `api-key`. Its image, `ghcr.io/edgible-org/edgible-mcp`, is built from [card-kit's edgible-mcp](https://github.com/edgible-org/card-kit/tree/main/edgible-mcp): a Node server on the official MCP TypeScript SDK, with the Edgible CLI 1.4.12 and Docker's CLI with Compose, serving Streamable HTTP at `/mcp` with no sign-in of its own. Its healthcheck asks `/healthz`. MCP clients send a key as `Authorization: Bearer`, and Edgible refuses a request without a valid one. Give each person their own key. Claude's desktop and web connectors expect the server's own OAuth instead, so this card is for Claude Code and other clients that can send a header.

With `EDGIBLE_MCP_ALLOW_WRITE=0`, the default, the tools only read. `find` searches the cards, each an app card (one app) or a pattern card (several apps wired together), and the [needs map](https://github.com/edgible-org/card-kit/blob/main/skills/edgible-cards/needs-map.yaml) for a need in plain words. `describe` shows one card, with its type. These two read GitHub's public `main` and need no Edgible sign-in. `whats_running` lists your devices and apps, checks each hostname against its auth mode, and runs `edgible app doctor` for one app. It runs `edgible` read commands, so it needs the server's own Edgible sign-in, made after Start. Until then it says it is not signed in. The sign-in can do whatever its Edgible account can, and anyone with a key sees your app names, hostnames, and devices.

With `EDGIBLE_MCP_ALLOW_WRITE=1`, it adds `deploy_card`, `move_card`, `remove_card`, `card_status`, and `activity`. `deploy_card` runs an app card on any device of the organization as an Edgible-managed app, with no shell there; for now only cards with one published app and no secrets. Every change answers "needs confirmation" first, goes ahead only once the person agrees, and is written to a record with who asked. `EDGIBLE_MCP_DEVICES` limits changes to the devices it names. Anyone with a key can then change apps as that sign-in, so give keys only to people you would let do so.

To use the same server on your own computer instead, over stdio with that computer's `edgible` sign-in, see [card-kit's edgible-mcp](https://github.com/edgible-org/card-kit/tree/main/edgible-mcp#run-it).

The server's Edgible sign-in lives in the volume `edgible-mcp-login`, which is the CLI's HOME in the container and only root can read. It is never in this directory or in `card.env`. The catalog of cards is cached in `edgible-mcp-cache`, and `edgible-mcp-data` holds, with writes, the record and each deployed card's Compose file. Minimum recommended for the place `edgible-mcp`: 256 MB of memory and 1.5 GB of disk, on an arm64 or amd64 machine, with no GPU.

The Compose file is [docker-compose.yml](docker-compose.yml), the settings [card.env](card.env), the card [card.yml](card.yml).

## How

Five steps. Edit [card.env](card.env) before you start.

### 1. Fetch

```bash
mkdir -p edgible-mcp
curl -fsSL https://github.com/edgible-org/cards/archive/refs/heads/main.tar.gz \
  | tar -xz --strip-components=2 -C edgible-mcp cards-main/edgible-mcp
```

### 2. Edit card.env

Set `DEVICE` to a name `edgible device list` prints. Change `EDGIBLE_MCP_PORT` only if 8000 is taken. Set `EDGIBLE_MCP_ALLOW_WRITE=1` for the write tools, and `EDGIBLE_MCP_DEVICES` to limit which devices they may change.

```bash
nano edgible-mcp/card.env
```

### 3. Check

```bash
curl -fsSLo check-env.py https://raw.githubusercontent.com/edgible-org/card-kit/main/check-env.py
python3 check-env.py edgible-mcp
```

It fills each empty secret and moves a taken port, as lines to paste. Run it again until it says `no conflicts`.

### 4. Start

```bash
docker compose --env-file edgible-mcp/card.env -f edgible-mcp/docker-compose.yml pull
docker compose --env-file edgible-mcp/card.env -f edgible-mcp/docker-compose.yml up -d --wait
docker compose --env-file edgible-mcp/card.env -f edgible-mcp/docker-compose.yml ps
```

The first start downloads the app's images from the registries named in the Compose file: about 97 MB once unpacked, under a minute on a typical home connection. `pull` does that download on its own, so you can see it. The time is the download, not Edgible, and it happens once: later starts and upgrades reuse the images on the machine and fetch only what changed. `--wait` returns when each service is running, and healthy when it has a healthcheck. Then sign the server in to Edgible, so `whats_running` can see your apps. It prints a link and a code: open the link, approve the code, and sign in with the Edgible account the server should read as. The sign-in is written to the volume `edgible-mcp-login`, and nothing prints it.

```bash
docker compose --env-file edgible-mcp/card.env -f edgible-mcp/docker-compose.yml exec edgible-mcp edgible auth login --no-browser
```

`find` and `describe` work without it. To take the access away, run `edgible auth logout` the same way.

### 5. Publish

```bash
set -euo pipefail
set -a
. edgible-mcp/card.env
set +a
device_id=$(edgible device list --json | jq -er --arg name "$DEVICE" '
  map(select(.name == $name))
  | if length == 1 then .[0].id
    else error("need exactly one device named " + $name + " (" + (map(.status + " " + .id) | join(", ")) + ")")
    end
')
edgible app create existing \
  --non-interactive \
  --name edgible-mcp \
  --port "$EDGIBLE_MCP_PORT" \
  --protocol https \
  --auth-modes api-key \
  --device-id "$device_id"
edgible app list
```

## Verify

`edgible-mcp` uses `api-key`. Without a key, it answers `401`.

```bash
curl -sS -o /dev/null -w '%{http_code}\n' "https://<edgible-mcp hostname>"
```

`401`, until a key is sent. Make a key for each person, which is shown once: `edgible app api-keys create --app edgible-mcp --name <who>`. Then add the server to Claude Code: `claude mcp add --transport http edgible https://<edgible-mcp hostname>/mcp --header "Authorization: Bearer <key>"`, and `/mcp` in Claude Code lists its three tools. `edgible app api-keys list --app edgible-mcp` and `delete` manage the keys.

The rest of the setup is in the [MCP in Claude Code docs](https://docs.claude.com/en/docs/claude-code/mcp).

## Tear down

Four steps, in this order. Step 1 runs wherever `edgible` is logged in. Steps 2 to 4 run on the machine that runs the containers. Steps 2 and 3 read `card.env`, so keep it until step 4.

### 1. Unpublish

```bash
edgible app delete edgible-mcp --yes
```

### 2. Stop

```bash
docker compose --env-file edgible-mcp/card.env -f edgible-mcp/docker-compose.yml down
```

### 3. Delete the data

Skip this step to keep the data. The loop copies each volume to a `.tgz` file in this directory first.

```bash
for volume in $(docker volume ls -q --filter label=com.docker.compose.project=edgible-mcp); do
  docker run --rm -v "$volume:/data:ro" -v "$PWD:/backup" alpine tar -czf "/backup/$volume.tgz" -C /data .
done
docker compose --env-file edgible-mcp/card.env -f edgible-mcp/docker-compose.yml down --volumes
```

### 4. Remove the card

```bash
rm -rf edgible-mcp
```
