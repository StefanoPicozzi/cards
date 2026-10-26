# ech0

## Why

A short-post blog or notes feed on a hosted service lives under that service's terms. [Ech0](https://github.com/lin-snow/Ech0) is a lightweight publishing platform for personal posts, with a public timeline, that runs on a machine you own. It has no newsletter or paid members: it suits a personal blog or micro-blog, not a replacement for Substack's email list.

## What

One app, `ech0`, on the place `ech0`, on `none`. A blog is public, so readers need no Edgible sign-in, and the owner's own login in Ech0 protects publishing. `prepare.sh` makes that owner, `ECH0_ADMIN_USER`, with the password the card made on the machine, and closes sign-up before the site is published, because the first account to register on a fresh Ech0 becomes its owner. The image is `sn0wl1n/ech0:v5.8.0`, from Docker Hub, and the Compose file adds a healthcheck on `/api/hello`.

Posts, uploads, users and settings live in the volume `ech0-data`, at `/app/data`. Back it up. Minimum recommended for the place `ech0`: 256 MB of memory and 1.5 GB of disk, on an arm64 or amd64 machine, with no GPU.

The Compose file is [docker-compose.yml](docker-compose.yml), the settings [card.env](card.env), the card [card.yml](card.yml).

## How

Five steps. Edit [card.env](card.env) before you start.

### 1. Fetch

```bash
mkdir -p ech0
curl -fsSL https://github.com/edgible-org/cards/archive/refs/heads/main.tar.gz \
  | tar -xz --strip-components=2 -C ech0 cards-main/ech0
```

### 2. Edit card.env

Set `DEVICE` to a name `edgible device list` prints, and `ORG_LABEL` to the part after the app name in a hostname `edgible app list` prints. The owner's email is only an address on the account, so any will do. There are no secrets to fill: Start makes them on the machine.

```bash
nano ech0/card.env
```

### 3. Check

```bash
curl -fsSLo check-env.py https://raw.githubusercontent.com/edgible-org/card-kit/main/check-env.py
python3 check-env.py ech0
```

It moves a taken port, as lines to paste. Run it again until it says `no conflicts`.

### 4. Start

```bash
docker compose --env-file ech0/card.env -f ech0/docker-compose.yml pull
docker compose --env-file ech0/card.env -f ech0/docker-compose.yml up -d --wait
docker compose --env-file ech0/card.env -f ech0/docker-compose.yml ps
```

The first start downloads the app's images from the registries named in the Compose file: about 41 MB, under a minute on a typical home connection. `pull` does that download on its own, so you can see it. The time is the download, not Edgible, and it happens once: later starts and upgrades reuse the images on the machine and fetch only what changed. `--wait` returns when each service is running, and healthy when it has a healthcheck. 

```bash
sh ech0/prepare.sh
```

[prepare.sh](prepare.sh) is:

```sh
#!/bin/sh
# Prepare for the ech0 card: make the owner and close sign-up before the site is public.
# Run it after Start and before Publish, from the directory that holds ech0/:
#   sh ech0/prepare.sh
set -eu
cd "$(dirname "$0")"
set -a; . ./card.env; set +a
COMPOSE=${COMPOSE:-docker compose --env-file card.env -f docker-compose.yml}

# The card made this password on this machine at Start (ech0-secrets).
ECH0_ADMIN_PASSWORD=$($COMPOSE run --rm --no-deps ech0-secrets show ECH0_ADMIN_PASSWORD)

B="http://127.0.0.1:$ECH0_PORT/api"
H='Content-Type: application/json'

n=0
until curl -fsS "$B/init/status" >/dev/null 2>&1; do
  n=$((n + 1)); [ "$n" -lt 60 ] || { echo "ech0 did not answer"; exit 1; }
  sleep 1
done

# The first account to register becomes the owner, so make it here, not on a public page.
curl -fsS -X POST "$B/init/owner" -H "$H" \
  -d "{\"username\":\"$ECH0_ADMIN_USER\",\"email\":\"$ECH0_ADMIN_EMAIL\",\"password\":\"$ECH0_ADMIN_PASSWORD\",\"locale\":\"en-US\"}" >/dev/null

token=$(curl -fsS -X POST "$B/login" -H "$H" \
  -d "{\"username\":\"$ECH0_ADMIN_USER\",\"password\":\"$ECH0_ADMIN_PASSWORD\"}" \
  | jq -er '.data.access_token')

# Close sign-up: the owner is the only account until the owner adds more.
settings=$(curl -fsS "$B/settings" | jq -c '.data | .allow_register = false')
curl -fsS -X PUT "$B/settings" -H "$H" -H "Authorization: Bearer $token" -d "$settings" >/dev/null
curl -fsS "$B/settings" | jq -e '.data.allow_register == false' >/dev/null
echo "owner made from ECH0_ADMIN_USER and ECH0_ADMIN_PASSWORD, sign-up closed"
```

The owner exists and sign-up is closed, so no setup page is left for a stranger to find.

### 5. Publish

```bash
set -euo pipefail
set -a
. ech0/card.env
set +a
device_id=$(edgible device list --json | jq -er --arg name "$DEVICE" '
  map(select(.name == $name))
  | if length == 1 then .[0].id
    else error("need exactly one device named " + $name + " (" + (map(.status + " " + .id) | join(", ")) + ")")
    end
')
edgible app create existing \
  --non-interactive \
  --name ech0 \
  --port "$ECH0_PORT" \
  --protocol https \
  --auth-modes none \
  --device-id "$device_id"
edgible app list
```

**Without Edgible:** only Publish is Edgible's. The app listens on `127.0.0.1` at the port in `card.env`, so any reverse proxy or tunnel on the machine, such as Caddy, nginx, Cloudflare Tunnel or Tailscale, can publish it instead, and sign-in is then that tool's to provide. Every other step stays the same.

## Verify

`ech0` uses `none`.

```bash
curl -sS -o /dev/null -w '%{http_code}\n' "https://<ech0 hostname>"
```

The public timeline, with no Edgible sign-in. Sign in as `ECH0_ADMIN_USER` with the password the card made (`docker compose --env-file ech0/card.env -f ech0/docker-compose.yml run --rm --no-deps ech0-secrets show ECH0_ADMIN_PASSWORD` prints it), and change the password in Ech0's settings.

The rest of the setup is in the [Ech0 docs](https://github.com/lin-snow/Ech0).

## Tear down

Four steps, in this order. Step 1 runs wherever `edgible` is logged in. Steps 2 to 4 run on the machine that runs the containers. Steps 2 and 3 read `card.env`, so keep it until step 4.

### 1. Unpublish

```bash
edgible app delete ech0 --yes
```

### 2. Stop

```bash
docker compose --env-file ech0/card.env -f ech0/docker-compose.yml down
```

### 3. Delete the data

Skip this step to keep the data. The loop copies each volume to a `.tgz` file in this directory first. `ech0-secrets.tgz` holds the card's passwords and keys: keep it as safe as the data, which needs them.

```bash
for volume in $(docker volume ls -q --filter label=com.docker.compose.project=ech0); do
  docker run --rm -v "$volume:/data:ro" -v "$PWD:/backup" alpine tar -czf "/backup/$volume.tgz" -C /data .
done
docker compose --env-file ech0/card.env -f ech0/docker-compose.yml down --volumes
```

### 4. Remove the card

```bash
rm -rf ech0
```
