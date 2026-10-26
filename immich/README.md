# immich

## Why

Your photos and videos are the data people least want on someone else's servers, and the most expensive to keep there. [Immich](https://immich.app) is a photo and video library with phone apps that back up your camera roll, on a machine you own.

## What

One app, `immich`, on the place `immich`, on `none`. That is deliberate: Immich's phone apps cannot get past an Edgible sign-in, so `org` would stop them backing up. Immich's own login protects it, and nobody can sign up: the first account is the admin, made from the command line before anything is public, and the admin adds everyone else.

It runs four services, from the Compose file Immich publishes for v3.3.1: `immich-server`, `immich-machine-learning` for face recognition and smart search, `immich-redis`, and `immich-db`, a Postgres with vector search. The images are pinned to `v3.3.1`, with the digests Immich publishes for Redis and Postgres. To run without machine learning, remove that service; Immich then skips those features.

To use it in a card, copy the five services, the `x-immich-env` block, the four volumes, card.yml's `secrets:`, and the `IMMICH_` lines.

Photos and videos live in the volume `immich-library`, the database in `immich-db-data`, and machine learning's models in `immich-model-cache`. Back up the first two together. The memory and disk below follow Immich's own documented minimum, which is higher than an empty test library measures; disk is for Immich itself, so add room for your photos and about 20% more for thumbnails. Minimum recommended for the place `immich`: 6 GB of memory and 10 GB of disk, on an arm64 or amd64 machine, with a GPU if you have one (it runs without).

The Compose file is [docker-compose.yml](docker-compose.yml), the settings [card.env](card.env), the card [card.yml](card.yml), and the last test [test.yml](test.yml).

## How

Five steps. Edit [card.env](card.env) before you start.

### 1. Fetch

```bash
mkdir -p immich
curl -fsSL https://github.com/edgible-org/cards/archive/refs/heads/main.tar.gz \
  | tar -xz --strip-components=2 -C immich cards-main/immich
```

### 2. Edit card.env

Set `DEVICE` to a name `edgible device list` prints, and `IMMICH_ADMIN_EMAIL` to your address, which is also the admin's login. There are no passwords to fill: Start makes them on the machine.

```bash
nano immich/card.env
```

### 3. Check

```bash
curl -fsSLo check-env.py https://raw.githubusercontent.com/edgible-org/card-kit/main/check-env.py
python3 check-env.py immich
```

It moves a taken port, as lines to paste. Run it again until it says `no conflicts`.

### 4. Start

```bash
docker compose --env-file immich/card.env -f immich/docker-compose.yml pull
docker compose --env-file immich/card.env -f immich/docker-compose.yml up -d --wait
docker compose --env-file immich/card.env -f immich/docker-compose.yml ps
```

The first start downloads the app's images from the registries named in the Compose file: about 854 MB once unpacked, a few minutes on a typical home connection. `pull` does that download on its own, so you can see it. The time is the download, not Edgible, and it happens once: later starts and upgrades reuse the images on the machine and fetch only what changed. `--wait` returns when each service is running, and healthy when it has a healthcheck. Then make the admin, before Publish, so the sign-up page is never public:

```bash
sh immich/prepare.sh
```

[prepare.sh](prepare.sh) is:

```sh
#!/bin/sh
# Prepare for the immich card: make the admin, so the sign-up page is never public.
# Run it after Start and before Publish, from the directory that holds immich/:
#   sh immich/prepare.sh
set -eu
cd "$(dirname "$0")"
set -a; . ./card.env; set +a
COMPOSE=${COMPOSE:-docker compose --env-file card.env -f docker-compose.yml}

# The card made this password on this machine at Start (immich-secrets).
IMMICH_ADMIN_PASSWORD=$($COMPOSE run --rm --no-deps immich-secrets show IMMICH_ADMIN_PASSWORD)

curl -fsS -X POST "http://127.0.0.1:$IMMICH_PORT/api/auth/admin-sign-up" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$IMMICH_ADMIN_EMAIL\",\"password\":\"$IMMICH_ADMIN_PASSWORD\",\"name\":\"Admin\"}"
```

It answers with the new admin's details.

### 5. Publish

```bash
set -euo pipefail
set -a
. immich/card.env
set +a
device_id=$(edgible device list --json | jq -er --arg name "$DEVICE" '
  map(select(.name == $name))
  | if length == 1 then .[0].id
    else error("need exactly one device named " + $name + " (" + (map(.status + " " + .id) | join(", ")) + ")")
    end
')
edgible app create existing \
  --non-interactive \
  --name immich \
  --port "$IMMICH_PORT" \
  --protocol https \
  --auth-modes none \
  --device-id "$device_id"
edgible app list
```

## Verify

`immich` uses `none`.

```bash
curl -sS -o /dev/null -w '%{http_code}\n' "https://<immich hostname>"
```

That prints `200`: the web app, with no Edgible sign-in, as the phone apps need. Sign in with `IMMICH_ADMIN_EMAIL` and the password the card made; see it with `docker compose --env-file immich/card.env -f immich/docker-compose.yml run --rm --no-deps immich-secrets show IMMICH_ADMIN_PASSWORD`. In the phone app, set the server to `https://<immich hostname>` and sign in the same way.

The rest of the setup is in the [Immich docs](https://docs.immich.app).

## Tear down

Four steps, in this order. Step 1 runs wherever `edgible` is logged in. Steps 2 to 4 run on the machine that runs the containers. Steps 2 and 3 read `card.env`, so keep it until step 4.

### 1. Unpublish

```bash
edgible app delete immich --yes
```

### 2. Stop

```bash
docker compose --env-file immich/card.env -f immich/docker-compose.yml down
```

### 3. Delete the data

Skip this step to keep the data. The loop copies each volume to a `.tgz` file in this directory first. `immich-secrets.tgz` holds the card's passwords and keys: keep it as safe as the data, which needs them.

```bash
for volume in $(docker volume ls -q --filter label=com.docker.compose.project=immich); do
  docker run --rm -v "$volume:/data:ro" -v "$PWD:/backup" alpine tar -czf "/backup/$volume.tgz" -C /data .
done
docker compose --env-file immich/card.env -f immich/docker-compose.yml down --volumes
```

### 4. Remove the card

```bash
rm -rf immich
```
