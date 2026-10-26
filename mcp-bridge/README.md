# mcp-bridge

## Why

Most MCP servers speak stdio: the AI assistant starts them on the same computer, so they work on one laptop and nowhere else. This card runs any stdio MCP server, from npm or PyPI, on a machine that stays on, next to the data or tools it reaches, and serves it over Streamable HTTP, so you and your team can use it from Claude Code and other MCP clients wherever you are. The bridge is [Supergateway](https://github.com/supercorp-ai/supergateway).

## What

One app, `mcp-bridge`, on the place `mcp-bridge`, on `api-key`. MCP clients send a key as `Authorization: Bearer`, and Edgible refuses a request without a valid one before it reaches the server. Give each person their own key, so one can be revoked when they leave. Claude Code and most developer clients can send a key; Claude's desktop and web connectors expect the server's own OAuth sign-in instead, so check your client's docs before you choose it. The server to run is `MCP_BRIDGE_COMMAND` in `card.env`, with an exact version. Supergateway runs it with `--stateful`: each client session gets its own server process, ended after 10 idle minutes. The image is `supercorp/supergateway:4.1.0-uvx`, which has Node for `npx` and Python with uv for `uvx`. Its healthcheck starts the server and pings it, so `healthy` means the MCP server itself works. The default server is the MCP project's test server, `@modelcontextprotocol/server-everything`, which shows every feature of the protocol. Replace it with your own before you rely on it: among its tools is `get-env`, which returns the server's environment. A server that needs its own settings or secrets, such as an access token, reads them from `server.env` beside the Compose file: one `NAME=value` per line, `chmod 600`, never committed. Every tool a server offers is something anyone with a key can make it do: prefer servers that only read, and ask before adding ones that change or delete things.

Downloaded packages live in the volume `mcp-bridge-cache`, so a restart does not fetch the server again. Files the server keeps, for servers that keep any, live in `mcp-bridge-data`, which is the server's working directory, `/data`. Back up `mcp-bridge-data` when your server keeps something there. Minimum recommended for the place `mcp-bridge`: 384 MB of memory and 1.5 GB of disk, on an arm64 or amd64 machine, with no GPU.

The Compose file is [docker-compose.yml](docker-compose.yml), the settings [card.env](card.env), the card [card.yml](card.yml), and the last test [test.yml](test.yml).

## How

Five steps. Edit [card.env](card.env) before you start.

### 1. Fetch

```bash
mkdir -p mcp-bridge
curl -fsSL https://github.com/edgible-org/cards/archive/refs/heads/main.tar.gz \
  | tar -xz --strip-components=2 -C mcp-bridge cards-main/mcp-bridge
```

### 2. Edit card.env

Set `DEVICE` to a name `edgible device list` prints, and `MCP_BRIDGE_COMMAND` to the command that runs your server, such as `npx -y @modelcontextprotocol/server-filesystem@<version> /data`, with the version from its package page. Put its own settings, if it has any, in `server.env`.

```bash
nano mcp-bridge/card.env
```

### 3. Check

```bash
curl -fsSLo check-env.py https://raw.githubusercontent.com/edgible-org/card-kit/main/check-env.py
python3 check-env.py mcp-bridge
```

It fills each empty secret and moves a taken port, as lines to paste. Run it again until it says `no conflicts`.

### 4. Start

```bash
docker compose --env-file mcp-bridge/card.env -f mcp-bridge/docker-compose.yml pull
docker compose --env-file mcp-bridge/card.env -f mcp-bridge/docker-compose.yml up -d --wait
docker compose --env-file mcp-bridge/card.env -f mcp-bridge/docker-compose.yml ps
```

The first start downloads the app's images from the registries named in the Compose file: about 96 MB once unpacked, under a minute on a typical home connection. `pull` does that download on its own, so you can see it. The time is the download, not Edgible, and it happens once: later starts and upgrades reuse the images on the machine and fetch only what changed. `--wait` returns when each service is running, and healthy when it has a healthcheck. Here healthy means the MCP server answers. The first start downloads the server, so it takes longer.

### 5. Publish

```bash
set -euo pipefail
set -a
. mcp-bridge/card.env
set +a
device_id=$(edgible device list --json | jq -er --arg name "$DEVICE" '
  map(select(.name == $name))
  | if length == 1 then .[0].id
    else error("need exactly one device named " + $name + " (" + (map(.status + " " + .id) | join(", ")) + ")")
    end
')
edgible app create existing \
  --non-interactive \
  --name mcp-bridge \
  --port "$MCP_BRIDGE_PORT" \
  --protocol https \
  --auth-modes api-key \
  --device-id "$device_id"
edgible app list
```

## Verify

`mcp-bridge` uses `api-key`. Without a key, it answers `401`.

```bash
curl -sS -o /dev/null -w '%{http_code}\n' "https://<mcp-bridge hostname>"
```

`401`, until a key is sent. Make a key for each person, which is shown once: `edgible app api-keys create --app mcp-bridge --name <who>`. Then add the server to Claude Code: `claude mcp add --transport http mcp-bridge https://<mcp-bridge hostname>/mcp --header "Authorization: Bearer <key>"`, and `/mcp` in Claude Code lists its tools. `edgible app api-keys list --app mcp-bridge` and `delete` manage the keys.

The rest of the setup is in the [Supergateway docs](https://github.com/supercorp-ai/supergateway).

## Tear down

Four steps, in this order. Step 1 runs wherever `edgible` is logged in. Steps 2 to 4 run on the machine that runs the containers. Steps 2 and 3 read `card.env`, so keep it until step 4.

### 1. Unpublish

```bash
edgible app delete mcp-bridge --yes
```

### 2. Stop

```bash
docker compose --env-file mcp-bridge/card.env -f mcp-bridge/docker-compose.yml down
```

### 3. Delete the data

Skip this step to keep the data. The loop copies each volume to a `.tgz` file in this directory first.

```bash
for volume in $(docker volume ls -q --filter label=com.docker.compose.project=mcp-bridge); do
  docker run --rm -v "$volume:/data:ro" -v "$PWD:/backup" alpine tar -czf "/backup/$volume.tgz" -C /data .
done
docker compose --env-file mcp-bridge/card.env -f mcp-bridge/docker-compose.yml down --volumes
```

### 4. Remove the card

```bash
rm -rf mcp-bridge
```
