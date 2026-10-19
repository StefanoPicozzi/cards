# cogento

## Why

A club that bills members through Stripe still needs a place for those members to sign in, see their membership, and organise a game. [Cogento](https://cogento.org) is that place, on a machine the club runs.

## What

One app, `cogento`, on port `80` in the place `cogento`, on `none`. Club members are not members of the Edgible organization, so `org` would lock them out. They sign in with Cogento. When `COGENTO_LOGTO_ENDPOINT` and `COGENTO_LOGTO_APP_ID` are set, that sign-in is the [accounts](../accounts) card (Logto). With those blank, Cogento keeps its email code.

Postgres runs beside it as `cogento-db`. The API is `cogento-api` and is not published: the site sends `/api` to it. Onboarding is invite-only (`COGENTO_ONBOARDING_BY_INVITE=true`), so the open hostname does not let a stranger create a club.

To use it in a card, copy the `cogento`, `cogento-api`, and `cogento-db` services, both volumes, the `db/` scripts, and the `COGENTO_` lines and `ORG_LABEL` in `card.env`.

Clubs, members, and sign-in live in the volume `cogento-db-data`. Files a club uploads live in `cogento-files`. Minimum recommended for the place `cogento`: 1 GB of memory and 4 GB of disk, on an arm64 or amd64 machine, with no GPU.

The Compose file is [docker-compose.yml](docker-compose.yml), the settings [card.env](card.env), the card [card.yml](card.yml).

## How

Five steps. Edit [card.env](card.env) before you start.

### 1. Fetch

```bash
mkdir -p cogento
curl -fsSL https://github.com/edgible-org/cards/archive/refs/heads/main.tar.gz \
  | tar -xz --strip-components=2 -C cogento cards-main/cogento
```

### 2. Edit card.env

Set `DEVICE` to a name `edgible device list` prints, and `ORG_LABEL` to the part after the app name in a hostname `edgible app list` prints, so Cogento builds its links for the hostname Publish makes. Set `COGENTO_URL` only for your own domain. Set `COGENTO_LOGTO_ENDPOINT` and `COGENTO_LOGTO_APP_ID` from the accounts card, and in that Logto app add the redirect `https://cogento.<ORG_LABEL>.edgible.com/callback` (or `COGENTO_URL` with `/callback`). Set `COGENTO_SUPERUSER_EMAIL` to create that shared superuser on first start. The passwords are generated in the next step.

```bash
nano cogento/card.env
```

### 3. Check

```bash
curl -fsSLo check-env.py https://raw.githubusercontent.com/edgible-org/card-kit/main/check-env.py
python3 check-env.py cogento
```

It fills each empty secret and moves a taken port, as lines to paste. Run it again until it says `no conflicts`.

### 4. Start

```bash
docker compose --env-file cogento/card.env -f cogento/docker-compose.yml up -d --wait
docker compose --env-file cogento/card.env -f cogento/docker-compose.yml ps
```

`--wait` returns when each service is running, and healthy when it has a healthcheck. The first start creates Cogento's shared database. There is no setup page and no admin password. A club, its Stripe keys, and its members are added in Cogento after someone who may do that has signed in.

### 5. Publish

```bash
set -euo pipefail
set -a
. cogento/card.env
set +a
device_id=$(edgible device list --json | jq -er --arg name "$DEVICE" '
  map(select(.name == $name))
  | if length == 1 then .[0].id
    else error("need exactly one device named " + $name + " (" + (map(.status + " " + .id) | join(", ")) + ")")
    end
')
edgible app create existing \
  --non-interactive \
  --name cogento \
  --port "$COGENTO_PORT" \
  --protocol https \
  --auth-modes none \
  --device-id "$device_id"
edgible app list
```

**Without Edgible:** only Publish is Edgible's. The app listens on `127.0.0.1` at the port in `card.env`, so any reverse proxy or tunnel on the machine, such as Caddy, nginx, Cloudflare Tunnel or Tailscale, can publish it instead, and sign-in is then that tool's to provide. Every other step stays the same.

## Verify

`cogento` uses `none`.

```bash
curl -sS -o /dev/null -w '%{http_code}\n' "https://<cogento hostname>"
```

The site answers. Sign-in is Cogento's, through the accounts card when that is configured.

The rest of the setup is in the [Cogento docs](https://cogento.org).

## Tear down

Four steps, in this order. Step 1 runs wherever `edgible` is logged in. Steps 2 to 4 run on the machine that runs the containers. Steps 2 and 3 read `card.env`, so keep it until step 4.

### 1. Unpublish

```bash
edgible app delete cogento --yes
```

### 2. Stop

```bash
docker compose --env-file cogento/card.env -f cogento/docker-compose.yml down
```

### 3. Delete the data

Skip this step to keep the data. The loop copies each volume to a `.tgz` file in this directory first.

```bash
for volume in $(docker volume ls -q --filter label=com.docker.compose.project=cogento); do
  docker run --rm -v "$volume:/data:ro" -v "$PWD:/backup" alpine tar -czf "/backup/$volume.tgz" -C /data .
done
docker compose --env-file cogento/card.env -f cogento/docker-compose.yml down --volumes
```

### 4. Remove the card

```bash
rm -rf cogento
```
