# miniflux

## Why

Following sites and blogs usually means a hosted reader that tracks what you read, or an inbox full of newsletters. [Miniflux](https://miniflux.app) is a minimalist feed reader that fetches RSS, Atom and JSON feeds itself and keeps your subscriptions and read state in a database on a machine you own.

## What

One app, `miniflux`, on port `8080` in the place `miniflux`, behind `org`, so only members of your Edgible organization reach it, and Miniflux's own login is behind that. Postgres runs beside it as `miniflux-db`.

`org` suits a browser. Miniflux's API, and the Fever and Google Reader APIs that mobile and desktop reader apps use, cannot get past an Edgible sign-in. To use such an app, publish the hostname with `none` instead, and Miniflux's own login is then the only protection.

To use it in a card, copy the `miniflux-secrets`, `miniflux` and `miniflux-db` services, the volumes, card.yml's `secrets:`, and the `MINIFLUX_` lines and `ORG_LABEL` in `card.env`.

Feeds, entries, read state and accounts live in the volume `miniflux-db-data`. Minimum recommended for the place `miniflux`: 384 MB of memory and 1.5 GB of disk, on an arm64 or amd64 machine, with no GPU.

The Compose file is [docker-compose.yml](docker-compose.yml), the settings [card.env](card.env), the card [card.yml](card.yml), and the last test [test.yml](test.yml).

## How

Five steps. Edit [card.env](card.env) before you start.

### 1. Fetch

```bash
mkdir -p miniflux
curl -fsSL https://github.com/edgible-org/cards/archive/refs/heads/main.tar.gz \
  | tar -xz --strip-components=2 -C miniflux cards-main/miniflux
```

### 2. Edit card.env

Set `DEVICE` to a name `edgible device list` prints, and `ORG_LABEL` to the part after the app name in a hostname `edgible app list` prints, so Miniflux builds its links for the hostname Publish makes. Set `MINIFLUX_URL` only for your own domain. There are no passwords to fill: Start makes them on the machine.

```bash
nano miniflux/card.env
```

### 3. Check

```bash
curl -fsSLo check-env.py https://raw.githubusercontent.com/edgible-org/card-kit/main/check-env.py
python3 check-env.py miniflux
```

It moves a taken port, as lines to paste. Run it again until it says `no conflicts`.

### 4. Start

```bash
docker compose --env-file miniflux/card.env -f miniflux/docker-compose.yml pull
docker compose --env-file miniflux/card.env -f miniflux/docker-compose.yml up -d --wait
docker compose --env-file miniflux/card.env -f miniflux/docker-compose.yml ps
```

The first start downloads the app's images from the registries named in the Compose file: about 128 MB once unpacked, a minute or two on a typical home connection. `pull` does that download on its own, so you can see it. The time is the download, not Edgible, and it happens once: later starts and upgrades reuse the images on the machine and fetch only what changed. `--wait` returns when each service is running, and healthy when it has a healthcheck. Miniflux runs its database migrations and makes the admin `admin` on its first start, with the password the card made (`docker compose --env-file miniflux/card.env -f miniflux/docker-compose.yml run --rm --no-deps miniflux-secrets show MINIFLUX_ADMIN_PASSWORD` prints it), so there is no setup page to publish.

### 5. Publish

```bash
set -euo pipefail
set -a
. miniflux/card.env
set +a
device_id=$(edgible device list --json | jq -er --arg name "$DEVICE" '
  map(select(.name == $name))
  | if length == 1 then .[0].id
    else error("need exactly one device named " + $name + " (" + (map(.status + " " + .id) | join(", ")) + ")")
    end
')
edgible app create existing \
  --non-interactive \
  --name miniflux \
  --port "$MINIFLUX_PORT" \
  --protocol https \
  --auth-modes org \
  --device-id "$device_id"
edgible app list
```

## Verify

`miniflux` uses `org`.

```bash
curl -sS -o /dev/null -w '%{http_code} %{redirect_url}\n' "https://<miniflux hostname>"
```

That prints `302` and an `edgible.com/application-access/` address, so the org sign-in is in front. Open the hostname in a browser, sign in, then sign in to Miniflux as `admin` with the password the card made (see Start).

The rest of the setup is in the [Miniflux docs](https://miniflux.app/docs/).

## Tear down

Four steps, in this order. Step 1 runs wherever `edgible` is logged in. Steps 2 to 4 run on the machine that runs the containers. Steps 2 and 3 read `card.env`, so keep it until step 4.

### 1. Unpublish

```bash
edgible app delete miniflux --yes
```

### 2. Stop

```bash
docker compose --env-file miniflux/card.env -f miniflux/docker-compose.yml down
```

### 3. Delete the data

Skip this step to keep the data. The loop copies each volume to a `.tgz` file in this directory first. `miniflux-secrets.tgz` holds the card's passwords and keys: keep it as safe as the data, which needs them.

```bash
for volume in $(docker volume ls -q --filter label=com.docker.compose.project=miniflux); do
  docker run --rm -v "$volume:/data:ro" -v "$PWD:/backup" alpine tar -czf "/backup/$volume.tgz" -C /data .
done
docker compose --env-file miniflux/card.env -f miniflux/docker-compose.yml down --volumes
```

### 4. Remove the card

```bash
rm -rf miniflux
```
