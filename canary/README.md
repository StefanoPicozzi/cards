# canary

## Why

Before you blame an app, check the path to it. This card is a smoke test for Edgible: one tiny container, [whoami](https://github.com/traefik/whoami) from Traefik, published once on each auth mode. If the canary answers, a device, its agent and Edgible's gateway work, and a problem lies with the app. If it does not, look at Edgible first. It takes under a minute, needs no settings beyond the device, and keeps no data, so it suits a new device, a check after an upgrade, and the first run of a nightly regression.

## What

Three apps, `canary` on `none`, `canary-org` on `org` and `canary-key` on `api-key`, are one whoami process on one port, so one run checks every auth mode. whoami answers each request with its name (`canary`) and the headers it received, which shows what Edgible forwards, such as the X-Forwarded headers. Anyone can read the open hostname, which only echoes their own request back, and anyone can make its `/health` path report an error, so do not leave it published: Tear down removes it.

The canary keeps no data and has no volume. Minimum recommended for the place `canary`: 256 MB of memory and 1.5 GB of disk, on an arm64, amd64 or 32-bit arm machine, with no GPU.

The Compose file is [docker-compose.yml](docker-compose.yml), the settings [card.env](card.env), the card [card.yml](card.yml), and the last test [test.yml](test.yml).

## How

Five steps. Edit [card.env](card.env) before you start.

### 1. Fetch

```bash
mkdir -p canary
curl -fsSL https://github.com/edgible-org/cards/archive/refs/heads/main.tar.gz \
  | tar -xz --strip-components=2 -C canary cards-main/canary
```

### 2. Edit card.env

Set `DEVICE` to a name `edgible device list` prints. Change `CANARY_PORT` only if 8095 is taken.

```bash
nano canary/card.env
```

### 3. Check

```bash
curl -fsSLo check-env.py https://raw.githubusercontent.com/edgible-org/card-kit/main/check-env.py
python3 check-env.py canary
```

It fills each empty secret and moves a taken port, as lines to paste. Run it again until it says `no conflicts`.

### 4. Start

```bash
docker compose --env-file canary/card.env -f canary/docker-compose.yml pull
docker compose --env-file canary/card.env -f canary/docker-compose.yml up -d --wait
docker compose --env-file canary/card.env -f canary/docker-compose.yml ps
```

The first start downloads the app's images from the registries named in the Compose file: about 5 MB, under a minute on a typical home connection. `pull` does that download on its own, so you can see it. The time is the download, not Edgible, and it happens once: later starts and upgrades reuse the images on the machine and fetch only what changed. `--wait` returns when each service is running, and healthy when it has a healthcheck. 

### 5. Publish

```bash
set -euo pipefail
set -a
. canary/card.env
set +a
device_id=$(edgible device list --json | jq -er --arg name "$DEVICE" '
  map(select(.name == $name))
  | if length == 1 then .[0].id
    else error("need exactly one device named " + $name + " (" + (map(.status + " " + .id) | join(", ")) + ")")
    end
')
edgible app create existing \
  --non-interactive \
  --name canary \
  --port "$CANARY_PORT" \
  --protocol https \
  --auth-modes none \
  --device-id "$device_id"
edgible app create existing \
  --non-interactive \
  --name canary-org \
  --port "$CANARY_PORT" \
  --protocol https \
  --auth-modes org \
  --device-id "$device_id"
edgible app create existing \
  --non-interactive \
  --name canary-key \
  --port "$CANARY_PORT" \
  --protocol https \
  --auth-modes api-key \
  --device-id "$device_id"
edgible app list
```

## Verify

`canary` uses `none`.

```bash
curl -sS -o /dev/null -w '%{http_code}\n' "https://<canary hostname>"
```

The open hostname answers with `Name: canary` and the request's headers.

`canary-org` uses `org`.

```bash
curl -sS -o /dev/null -w '%{http_code} %{redirect_url}\n' "https://<canary-org hostname>"
```

That prints `302` and an `edgible.com/application-access/` address, so the org sign-in is in front. The org hostname redirects to the Edgible sign-in.

`canary-key` uses `api-key`. Without a key, it answers `401`.

```bash
curl -sS -o /dev/null -w '%{http_code}\n' "https://<canary-key hostname>"
```

The api-key hostname answers 401 until a key is sent.

The rest of the setup is in the [whoami docs](https://github.com/traefik/whoami).

## Tear down

Four steps, in this order. Step 1 runs wherever `edgible` is logged in. Steps 2 to 4 run on the machine that runs the containers. Steps 2 and 3 read `card.env`, so keep it until step 4.

### 1. Unpublish

```bash
edgible app delete canary --yes
edgible app delete canary-org --yes
edgible app delete canary-key --yes
```

### 2. Stop

```bash
docker compose --env-file canary/card.env -f canary/docker-compose.yml down
```

### 3. Delete the data

Skip this step to keep the data. The loop copies each volume to a `.tgz` file in this directory first.

```bash
for volume in $(docker volume ls -q --filter label=com.docker.compose.project=canary); do
  docker run --rm -v "$volume:/data:ro" -v "$PWD:/backup" alpine tar -czf "/backup/$volume.tgz" -C /data .
done
docker compose --env-file canary/card.env -f canary/docker-compose.yml down --volumes
```

### 4. Remove the card

```bash
rm -rf canary
```
