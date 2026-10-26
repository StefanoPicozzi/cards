# mcp-signin

## Why

An MCP server on your own machine gives an AI assistant tools: your documents, your database, your apps. Claude on the web and phone can use one as a connector, but Claude's own servers make the calls, with no browser, so they need OAuth, not a sign-in page or an API key. This card is that OAuth, with Edgible doing the signing in: you add the connector once, sign in with your Edgible account, and use the server from Claude anywhere, and only members of your Edgible organisation, or the people you list, get in. The code is [card-kit's mcp-signin](https://github.com/edgible-org/card-kit/tree/main/mcp-signin).

## What

One process on two addresses. `mcp-signin` is on `none`, because Claude's servers call it with no browser: it answers `/mcp` only with a token it issued, and serves the OAuth endpoints Claude finds and registers with by itself. `mcp-signin-login` is on `org`: the page Claude opens in your browser, which Edgible signs you in to first. That page reads who you are from Edgible's sign-in, checks you belong to `EDGIBLE_ORGANIZATION_ID` and, when `MCP_SIGNIN_USERS` is set, that you are listed, and asks you to allow the assistant, naming where it will send you, so a link from someone else's assistant cannot sign you in silently. Each call then passes to the MCP server at `MCP_UPSTREAM_URL`, with `X-MCP-User` set to your email: keep that server unpublished, reached only from here. Tokens last an hour and renew in the background for 30 days. To put it in front of an MCP server that speaks only stdio, run that server with the mcp-bridge card and point `MCP_UPSTREAM_URL` at it.

Registered assistants and tokens live in the volume `mcp-signin-data`, the tokens kept hashed. Losing it signs everyone out, and nothing else: no backup needed. Minimum recommended for the place `mcp-signin`: 256 MB of memory and 1.5 GB of disk, on an arm64 or amd64 machine, with no GPU.

The Compose file is [docker-compose.yml](docker-compose.yml), the settings [card.env](card.env), the card [card.yml](card.yml), and the last test [test.yml](test.yml).

## How

Five steps. Edit [card.env](card.env) before you start.

### 1. Fetch

```bash
mkdir -p mcp-signin
curl -fsSL https://github.com/edgible-org/cards/archive/refs/heads/main.tar.gz \
  | tar -xz --strip-components=2 -C mcp-signin cards-main/mcp-signin
```

### 2. Edit card.env

Set `DEVICE` to a name `edgible device list` prints, `MCP_UPSTREAM_URL` to the MCP server behind (on this machine, `http://host.docker.internal:<port>/mcp`), and `ORG_LABEL`. Check fills `EDGIBLE_ORGANIZATION_ID` from the CLI. Set `MCP_SIGNIN_USERS` to limit who may sign in, and `MCP_SIGNIN_NAME` and `MCP_SIGNIN_PURPOSE` to what the consent page should say.

```bash
nano mcp-signin/card.env
```

### 3. Check

```bash
curl -fsSLo check-env.py https://raw.githubusercontent.com/edgible-org/card-kit/main/check-env.py
python3 check-env.py mcp-signin
```

It fills each empty secret and moves a taken port, as lines to paste. Run it again until it says `no conflicts`.

### 4. Start

```bash
docker compose --env-file mcp-signin/card.env -f mcp-signin/docker-compose.yml pull
docker compose --env-file mcp-signin/card.env -f mcp-signin/docker-compose.yml up -d --wait
docker compose --env-file mcp-signin/card.env -f mcp-signin/docker-compose.yml ps
```

The first start downloads the app's images from the registries named in the Compose file: about 65 MB once unpacked, under a minute on a typical home connection. `pull` does that download on its own, so you can see it. The time is the download, not Edgible, and it happens once: later starts and upgrades reuse the images on the machine and fetch only what changed. `--wait` returns when each service is running, and healthy when it has a healthcheck. 

### 5. Publish

```bash
set -euo pipefail
set -a
. mcp-signin/card.env
set +a
device_id=$(edgible device list --json | jq -er --arg name "$DEVICE" '
  map(select(.name == $name))
  | if length == 1 then .[0].id
    else error("need exactly one device named " + $name + " (" + (map(.status + " " + .id) | join(", ")) + ")")
    end
')
edgible app create existing \
  --non-interactive \
  --name mcp-signin \
  --port "$MCP_SIGNIN_PORT" \
  --protocol https \
  --auth-modes none \
  --device-id "$device_id"
edgible app create existing \
  --non-interactive \
  --name mcp-signin-login \
  --port "$MCP_SIGNIN_LOGIN_PORT" \
  --protocol https \
  --auth-modes org \
  --device-id "$device_id"
edgible app list
```

**Without Edgible:** only Publish is Edgible's. The app listens on `127.0.0.1` at the port in `card.env`, so any reverse proxy or tunnel on the machine, such as Caddy, nginx, Cloudflare Tunnel or Tailscale, can publish it instead, and sign-in is then that tool's to provide. Every other step stays the same.

## Verify

`mcp-signin` uses `none`.

```bash
curl -sS -o /dev/null -w '%{http_code}\n' "https://<mcp-signin hostname>"
```

Then add it to Claude: Settings, Connectors, Add custom connector, with the URL `https://<mcp-signin hostname>/mcp` and the OAuth fields empty. Connect: your browser opens Edgible's sign-in, then the page asking you to allow Claude. Allow, and the connector lists the tools of the server behind, on Claude's web, desktop and phone apps. Its log says who signed in: `docker compose --env-file mcp-signin/card.env -f mcp-signin/docker-compose.yml logs mcp-signin`.

`mcp-signin-login` uses `org`.

```bash
curl -sS -o /dev/null -w '%{http_code} %{redirect_url}\n' "https://<mcp-signin-login hostname>"
```

That prints `302` and an `edgible.com/application-access/` address, so the org sign-in is in front. Only Edgible's sign-in leads to the page, even for a caller that sends Edgible's identity headers itself: Edgible's agent drops them.

The rest of the setup is in the [MCP authorization docs](https://modelcontextprotocol.io/specification/2025-06-18/basic/authorization).

## Tear down

Four steps, in this order. Step 1 runs wherever `edgible` is logged in. Steps 2 to 4 run on the machine that runs the containers. Steps 2 and 3 read `card.env`, so keep it until step 4.

### 1. Unpublish

```bash
edgible app delete mcp-signin --yes
edgible app delete mcp-signin-login --yes
```

### 2. Stop

```bash
docker compose --env-file mcp-signin/card.env -f mcp-signin/docker-compose.yml down
```

### 3. Delete the data

Skip this step to keep the data. The loop copies each volume to a `.tgz` file in this directory first.

```bash
for volume in $(docker volume ls -q --filter label=com.docker.compose.project=mcp-signin); do
  docker run --rm -v "$volume:/data:ro" -v "$PWD:/backup" alpine tar -czf "/backup/$volume.tgz" -C /data .
done
docker compose --env-file mcp-signin/card.env -f mcp-signin/docker-compose.yml down --volumes
```

### 4. Remove the card

```bash
rm -rf mcp-signin
```
