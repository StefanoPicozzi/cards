# linkding

## Why

Bookmarks kept in one browser's sync are tied to that browser and that company. [linkding](https://github.com/sissbruecker/linkding) is a small, fast bookmark manager with tags, search, and a browser extension, that keeps your bookmarks on a machine you own.

## What

One app, `linkding`, on the place `linkding`, on `none`. That is deliberate: the linkding browser extension and the community phone apps call its API with a token, and cannot get past an Edgible sign-in, so `org` would lock them out. linkding's own login takes its place: it has no sign-up page, so the only account is the admin made from `LINKDING_ADMIN_USER` and `LINKDING_ADMIN_PASSWORD` on first start, and the admin adds anyone else under **Admin**. Logins and saves come from the public hostname, so `LD_CSRF_TRUSTED_ORIGINS` is `https://linkding.<ORG_LABEL>.<EDGIBLE_DOMAIN>`, or `LINKDING_URL` on your own domain. The image is `ghcr.io/sissbruecker/linkding:1.47.0`, from GitHub's registry, with its own healthcheck. Its `-plus` variant adds Chromium for saving pages as HTML snapshots, at several times the size.

Bookmarks, tags, users and settings live in the SQLite database in the volume `linkding-data`. Back it up. Minimum recommended for the place `linkding`: 384 MB of memory and 1.5 GB of disk, on an arm64, amd64 or 32-bit arm machine, with no GPU.

The Compose file is [docker-compose.yml](docker-compose.yml), the settings [card.env](card.env), the card [card.yml](card.yml), and the last test [test.yml](test.yml).

## How

Five steps. Edit [card.env](card.env) before you start.

### 1. Fetch

```bash
mkdir -p linkding
curl -fsSL https://github.com/edgible-org/cards/archive/refs/heads/main.tar.gz \
  | tar -xz --strip-components=2 -C linkding cards-main/linkding
```

### 2. Edit card.env

Set `DEVICE` to a name `edgible device list` prints, and `ORG_LABEL` to the part after the app name in a hostname `edgible app list` prints. The admin password is generated in the next step.

```bash
nano linkding/card.env
```

### 3. Check

```bash
curl -fsSLo check-env.py https://raw.githubusercontent.com/edgible-org/card-kit/main/check-env.py
python3 check-env.py linkding
```

It fills each empty secret and moves a taken port, as lines to paste. Run it again until it says `no conflicts`.

### 4. Start

```bash
docker compose --env-file linkding/card.env -f linkding/docker-compose.yml up -d --wait
docker compose --env-file linkding/card.env -f linkding/docker-compose.yml ps
```

`--wait` returns when each service is running, and healthy when it has a healthcheck. The admin is made on first start, from `card.env`, so there is no setup page for a stranger to find once it is published.

### 5. Publish

```bash
set -euo pipefail
set -a
. linkding/card.env
set +a
device_id=$(edgible device list --json | jq -er --arg name "$DEVICE" '
  map(select(.name == $name))
  | if length == 1 then .[0].id
    else error("need exactly one device named " + $name + " (" + (map(.status + " " + .id) | join(", ")) + ")")
    end
')
edgible app create existing \
  --non-interactive \
  --name linkding \
  --port "$LINKDING_PORT" \
  --protocol https \
  --auth-modes none \
  --device-id "$device_id"
edgible app list
```

## Verify

`linkding` uses `none`.

```bash
curl -sS -o /dev/null -w '%{http_code}\n' "https://<linkding hostname>"
```

The login page, with no Edgible sign-in, as the browser extension needs. Sign in as `LINKDING_ADMIN_USER` with `LINKDING_ADMIN_PASSWORD`, and change the password under **Settings**. For the browser extension, copy the REST API token from **Settings → Integrations**.

The rest of the setup is in the [linkding docs](https://linkding.link).

## Tear down

Four steps, in this order. Step 1 runs wherever `edgible` is logged in. Steps 2 to 4 run on the machine that runs the containers. Steps 2 and 3 read `card.env`, so keep it until step 4.

### 1. Unpublish

```bash
edgible app delete linkding --yes
```

### 2. Stop

```bash
docker compose --env-file linkding/card.env -f linkding/docker-compose.yml down
```

### 3. Delete the data

Skip this step to keep the data. The loop copies each volume to a `.tgz` file in this directory first.

```bash
for volume in $(docker volume ls -q --filter label=com.docker.compose.project=linkding); do
  docker run --rm -v "$volume:/data:ro" -v "$PWD:/backup" alpine tar -czf "/backup/$volume.tgz" -C /data .
done
docker compose --env-file linkding/card.env -f linkding/docker-compose.yml down --volumes
```

### 4. Remove the card

```bash
rm -rf linkding
```
