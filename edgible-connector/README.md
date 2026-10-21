# edgible-connector

## Why

Claude's web, desktop and phone apps can use Edgible as a connector: ask what is running, whether an app answers, which card fits a need, and, if you allow it, have an app deployed, moved or removed, from wherever you are. A connector is called by Claude's own servers, so it needs an address on the internet and its own sign-in. This pattern is that, on a machine of yours, and you sign in with your Edgible account. It is built from the [mcp-signin](https://github.com/edgible-org/cards/tree/main/mcp-signin) and [edgible-mcp](https://github.com/edgible-org/cards/tree/main/edgible-mcp) app cards.

## What

Two containers on one machine. `edgible-mcp` is Edgible's MCP server, with no address of its own: it acts as the Edgible CLI inside it, which you sign in once, after Start. `mcp-signin` sits in front, on two addresses: `mcp-signin` on `none`, which Claude's servers call with a token, and `mcp-signin-login` on `org`, the page where you sign in with Edgible and allow Claude. Only members of `EDGIBLE_ORGANIZATION_ID`, or the people in `MCP_SIGNIN_USERS`, get in, and mcp-signin tells edgible-mcp who each one is, which goes in its record. The tools only read unless `EDGIBLE_MCP_ALLOW_WRITE=1`: then they deploy, move and remove app cards, each change asked first, and `EDGIBLE_MCP_DEVICES` limits which devices may change. Everyone who gets in acts as the CLI's sign-in, so sign it in as an account that may do what you allow. A card that needs a key you bring, such as a model's API key, takes it from an Edgible organisation secret: Claude gives you a one-time link to a page on `mcp-signin-login` where you paste it, from your phone too, and edgible-mcp stores it with Edgible. Claude never sees the key.

Nothing here needs a backup. `mcp-signin-data` holds the registered assistants and tokens: losing it signs everyone out. `edgible-mcp-login` holds the CLI's sign-in: losing it means signing in again. `edgible-mcp-data` holds, with writes, the record of what the tools did. Minimum recommended for the place `connector`: 256 MB of memory and 1.5 GB of disk, on an arm64 or amd64 machine, with no GPU.

The Compose file is [docker-compose.yml](docker-compose.yml), the settings [card.env](card.env), the card [card.yml](card.yml), and the last test [test.yml](test.yml).

## How

Five steps. Edit [card.env](card.env) before you start.

### 1. Fetch

```bash
mkdir -p edgible-connector
curl -fsSL https://github.com/edgible-org/cards/archive/refs/heads/main.tar.gz \
  | tar -xz --strip-components=2 -C edgible-connector cards-main/edgible-connector
```

### 2. Edit card.env

Set `DEVICE` to a name `edgible device list` prints and `ORG_LABEL`. Check fills `EDGIBLE_ORGANIZATION_ID` from the CLI. Set `MCP_SIGNIN_USERS` to limit who may sign in, and `EDGIBLE_MCP_ALLOW_WRITE=1` for the tools that change things, with `EDGIBLE_MCP_DEVICES` to keep them to some devices.

```bash
nano edgible-connector/card.env
```

### 3. Check

```bash
curl -fsSLo check-env.py https://raw.githubusercontent.com/edgible-org/card-kit/main/check-env.py
python3 check-env.py edgible-connector
```

It fills each empty secret and moves a taken port, as lines to paste. Run it again until it says `no conflicts`.

### 4. Start

```bash
docker compose --env-file edgible-connector/card.env -f edgible-connector/docker-compose.yml up -d --wait
docker compose --env-file edgible-connector/card.env -f edgible-connector/docker-compose.yml ps
```

`--wait` returns when each service is running, and healthy when it has a healthcheck. Then sign the server in to Edgible, once: `docker compose --env-file edgible-connector/card.env -f edgible-connector/docker-compose.yml exec edgible-mcp edgible auth login --no-browser` prints a link and a code. Open the link, check the code, and approve. Until then, the tools that read your organisation say they are not signed in.

### 5. Publish

```bash
set -euo pipefail
set -a
. edgible-connector/card.env
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

Then add it to Claude: Settings, Connectors, Add custom connector, named Edgible, with the URL `https://<mcp-signin hostname>/mcp` and the OAuth fields empty. Connect: Edgible's sign-in, then a page asking you to allow Claude. Allow, and ask Claude "What Edgible apps are running?". It works on Claude's web, desktop and phone apps.

`mcp-signin-login` uses `org`.

```bash
curl -sS -o /dev/null -w '%{http_code} %{redirect_url}\n' "https://<mcp-signin-login hostname>"
```

That prints `302` and an `edgible.com/application-access/` address, so the org sign-in is in front. Only Edgible's sign-in leads to the page, even for a caller that sends Edgible's identity headers itself.

The rest of the setup is in the [MCP in Claude docs](https://support.claude.com/en/articles/11503834).

## Tear down

Four steps, in this order. Step 1 runs wherever `edgible` is logged in. Steps 2 to 4 run on the machine that runs the containers. Steps 2 and 3 read `card.env`, so keep it until step 4.

### 1. Unpublish

```bash
edgible app delete mcp-signin --yes
edgible app delete mcp-signin-login --yes
```

### 2. Stop

```bash
docker compose --env-file edgible-connector/card.env -f edgible-connector/docker-compose.yml down
```

### 3. Delete the data

Skip this step to keep the data. The loop copies each volume to a `.tgz` file in this directory first.

```bash
for volume in $(docker volume ls -q --filter label=com.docker.compose.project=edgible-connector); do
  docker run --rm -v "$volume:/data:ro" -v "$PWD:/backup" alpine tar -czf "/backup/$volume.tgz" -C /data .
done
docker compose --env-file edgible-connector/card.env -f edgible-connector/docker-compose.yml down --volumes
```

### 4. Remove the card

```bash
rm -rf edgible-connector
```
