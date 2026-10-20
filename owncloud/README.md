# owncloud

## Why

Your files, synced and shared from a server you control, instead of a hosted file service. [ownCloud Infinite Scale](https://owncloud.dev/ocis/) is the current ownCloud, with a web interface, WebDAV, and desktop and phone apps.

## What

One ownCloud Infinite Scale process, with its built-in sign-in, search and storage, so there is no separate database. The hostname is open (auth mode none), because the desktop and phone apps and WebDAV clients cannot get past an Edgible sign-in; ownCloud's own login protects it, and there is no public sign-up, so only accounts the admin creates can sign in.

The config and keys are in the volume owncloud-config, and the files and users in owncloud-data. Both matter. The admin password the card makes on the machine is only read the first time. Minimum recommended for the place `owncloud`: 1 GB of memory and 3 GB of disk, on an arm64 or amd64 machine, with no GPU.

The Compose file is [docker-compose.yml](docker-compose.yml), the settings [card.env](card.env), the card [card.yml](card.yml).

## How

Five steps. Edit [card.env](card.env) before you start.

### 1. Fetch

```bash
mkdir -p owncloud
curl -fsSL https://github.com/edgible-org/cards/archive/refs/heads/main.tar.gz \
  | tar -xz --strip-components=2 -C owncloud cards-main/owncloud
```

### 2. Edit card.env

Set DEVICE and ORG_LABEL. There is no password to fill: Start makes the admin's on the machine. Leave OWNCLOUD_URL empty unless you use your own domain.

```bash
nano owncloud/card.env
```

### 3. Check

```bash
curl -fsSLo check-env.py https://raw.githubusercontent.com/edgible-org/card-kit/main/check-env.py
python3 check-env.py owncloud
```

It moves a taken port, as lines to paste. Run it again until it says `no conflicts`.

### 4. Start

```bash
docker compose --env-file owncloud/card.env -f owncloud/docker-compose.yml up -d --wait
docker compose --env-file owncloud/card.env -f owncloud/docker-compose.yml ps
```

`--wait` returns when each service is running, and healthy when it has a healthcheck. The first start makes the config and the admin with the password the card made, so nobody can claim the admin by getting there first. No prepare step is needed.

### 5. Publish

```bash
set -euo pipefail
set -a
. owncloud/card.env
set +a
device_id=$(edgible device list --json | jq -er --arg name "$DEVICE" '
  map(select(.name == $name))
  | if length == 1 then .[0].id
    else error("need exactly one device named " + $name + " (" + (map(.status + " " + .id) | join(", ")) + ")")
    end
')
edgible app create existing \
  --non-interactive \
  --name owncloud \
  --port "$OWNCLOUD_PORT" \
  --protocol https \
  --auth-modes none \
  --device-id "$device_id"
edgible app list
```

## Verify

`owncloud` uses `none`.

```bash
curl -sS -o /dev/null -w '%{http_code}\n' "https://<owncloud hostname>"
```

The hostname shows ownCloud's sign-in page. Sign in as admin, with the password the card made (`docker compose --env-file owncloud/card.env -f owncloud/docker-compose.yml run --rm --no-deps owncloud-secrets show OWNCLOUD_ADMIN_PASSWORD` prints it), then add users in the admin settings; there is no public sign-up.

The rest of the setup is in the [ownCloud Infinite Scale docs](https://doc.owncloud.com/ocis/next/).

## Tear down

Four steps, in this order. Step 1 runs wherever `edgible` is logged in. Steps 2 to 4 run on the machine that runs the containers. Steps 2 and 3 read `card.env`, so keep it until step 4.

### 1. Unpublish

```bash
edgible app delete owncloud --yes
```

### 2. Stop

```bash
docker compose --env-file owncloud/card.env -f owncloud/docker-compose.yml down
```

### 3. Delete the data

Skip this step to keep the data. The loop copies each volume to a `.tgz` file in this directory first. `owncloud-secrets.tgz` holds the card's passwords and keys: keep it as safe as the data, which needs them.

```bash
for volume in $(docker volume ls -q --filter label=com.docker.compose.project=owncloud); do
  docker run --rm -v "$volume:/data:ro" -v "$PWD:/backup" alpine tar -czf "/backup/$volume.tgz" -C /data .
done
docker compose --env-file owncloud/card.env -f owncloud/docker-compose.yml down --volumes
```

### 4. Remove the card

```bash
rm -rf owncloud
```
