# uptime-kuma

## Why

You want to know your sites and services are up before your users tell you. [Uptime Kuma](https://github.com/louislam/uptime-kuma) checks them on a schedule, alerts you through dozens of channels, and draws status pages, from a machine you own. This card puts its interface behind your org login.

## What

One app, `uptime-kuma`, on the place `uptime-kuma`, behind `org`. The image is `louislam/uptime-kuma:2.5.5-slim`, about 180 MB. It keeps monitors in SQLite and leaves out the bundled MariaDB and the browser-based monitors; `2.5.5` is the full image, about 600 MB, if you want those. The image brings its own healthcheck.

A monitor on the same machine as what it watches cannot report that machine going down. Put this card on a different serving device from the services it checks. To use it in a card, copy the `uptime-kuma` service and its volume, and `UPTIME_KUMA_PORT`, and give it its own place.

Monitors, settings and history live in the volume `uptime-kuma-data`. Minimum recommended for the place `uptime-kuma`: 256 MB of memory and 1.5 GB of disk, on an arm64, amd64 or 32-bit arm machine, with no GPU.

The Compose file is [docker-compose.yml](docker-compose.yml), the settings [card.env](card.env), the card [card.yml](card.yml), and the last test [test.yml](test.yml).

## How

Five steps. Edit [card.env](card.env) before you start.

### 1. Fetch

```bash
mkdir -p uptime-kuma
curl -fsSL https://github.com/edgible-org/cards/archive/refs/heads/main.tar.gz \
  | tar -xz --strip-components=2 -C uptime-kuma cards-main/uptime-kuma
```

### 2. Edit card.env

Set `DEVICE` to a name `edgible device list` prints.

```bash
nano uptime-kuma/card.env
```

### 3. Check

```bash
curl -fsSLo check-env.py https://raw.githubusercontent.com/edgible-org/card-kit/main/check-env.py
python3 check-env.py uptime-kuma
```

It fills each empty secret and moves a taken port, as lines to paste. Run it again until it says `no conflicts`.

### 4. Start

```bash
docker compose --env-file uptime-kuma/card.env -f uptime-kuma/docker-compose.yml pull
docker compose --env-file uptime-kuma/card.env -f uptime-kuma/docker-compose.yml up -d --wait
docker compose --env-file uptime-kuma/card.env -f uptime-kuma/docker-compose.yml ps
```

The first start downloads the app's images from the registries named in the Compose file: about 180 MB once unpacked, a minute or two on a typical home connection. `pull` does that download on its own, so you can see it. The time is the download, not Edgible, and it happens once: later starts and upgrades reuse the images on the machine and fetch only what changed. `--wait` returns when each service is running, and healthy when it has a healthcheck. The image's own healthcheck applies, so `ps` shows `(healthy)`.

### 5. Publish

```bash
set -euo pipefail
set -a
. uptime-kuma/card.env
set +a
device_id=$(edgible device list --json | jq -er --arg name "$DEVICE" '
  map(select(.name == $name))
  | if length == 1 then .[0].id
    else error("need exactly one device named " + $name + " (" + (map(.status + " " + .id) | join(", ")) + ")")
    end
')
edgible app create existing \
  --non-interactive \
  --name uptime-kuma \
  --port "$UPTIME_KUMA_PORT" \
  --protocol https \
  --auth-modes org \
  --device-id "$device_id"
edgible app list
```

## Verify

`uptime-kuma` uses `org`.

```bash
curl -sS -o /dev/null -w '%{http_code} %{redirect_url}\n' "https://<uptime-kuma hostname>"
```

That prints `302` and an `edgible.com/application-access/` address, so the org sign-in is in front. Open the hostname in a browser and sign in. The first visit creates the Uptime Kuma admin.

The rest of the setup is in the [Uptime Kuma docs](https://github.com/louislam/uptime-kuma/wiki).

## Tear down

Four steps, in this order. Step 1 runs wherever `edgible` is logged in. Steps 2 to 4 run on the machine that runs the containers. Steps 2 and 3 read `card.env`, so keep it until step 4.

### 1. Unpublish

```bash
edgible app delete uptime-kuma --yes
```

### 2. Stop

```bash
docker compose --env-file uptime-kuma/card.env -f uptime-kuma/docker-compose.yml down
```

### 3. Delete the data

Skip this step to keep the data. The loop copies each volume to a `.tgz` file in this directory first.

```bash
for volume in $(docker volume ls -q --filter label=com.docker.compose.project=uptime-kuma); do
  docker run --rm -v "$volume:/data:ro" -v "$PWD:/backup" alpine tar -czf "/backup/$volume.tgz" -C /data .
done
docker compose --env-file uptime-kuma/card.env -f uptime-kuma/docker-compose.yml down --volumes
```

### 4. Remove the card

```bash
rm -rf uptime-kuma
```
