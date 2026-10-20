# umami

## Why

Knowing whether anyone reads your site usually means handing every visitor to an analytics company. [Umami](https://umami.is) counts page views without cookies or personal data, and keeps the database on a machine you own.

## What

One process on two hostnames. `umami` is the dashboard, behind `org`. `analytics` serves the tracking script and takes page views, on `none`, because every visitor's browser has to reach it. Both are port `3000` on the place `umami`; list `umami` first so `UMAMI_PORT` is named after it. Postgres runs beside it as `umami-db`.

The `analytics` hostname serves the whole Umami process, so its login page is public too. Umami's own password protects it, which is why Start changes the default password before anything is published.

To use it in a card, copy the `umami-secrets`, `umami` and `umami-db` services, both volumes, and the `secrets:` section of [card.yml](card.yml), then put the tracking snippet from the dashboard into your site with the `analytics` hostname.

Page views, sites and accounts live in the volume `umami-db-data`.

No password or key is in `card.env`. At first start `umami-secrets` makes the four that card.yml's `secrets:` declares on the machine, one file each in the volume `umami-secrets`, and never changes them after. The database reads its password from that file, and Umami starts through a loader that reads them. They never leave the machine, and nothing else needs to know them. The one a person needs, the admin's password, you see with:

```bash
docker compose --env-file umami/card.env -f umami/docker-compose.yml run --rm --no-deps umami-secrets show UMAMI_ADMIN_PASSWORD
``` Minimum recommended for the place `umami`: 384 MB of memory and 1.5 GB of disk, on an arm64 or amd64 machine, with no GPU.

The Compose file is [docker-compose.yml](docker-compose.yml), the settings [card.env](card.env), the card [card.yml](card.yml), and the last test [test.yml](test.yml).

## How

Five steps. Edit [card.env](card.env) before you start.

### 1. Fetch

```bash
mkdir -p umami
curl -fsSL https://github.com/edgible-org/cards/archive/refs/heads/main.tar.gz \
  | tar -xz --strip-components=2 -C umami cards-main/umami
```

### 2. Edit card.env

Set `DEVICE` to a name `edgible device list` prints. There are no secrets to fill: Start makes them on the machine.

```bash
nano umami/card.env
```

### 3. Check

```bash
curl -fsSLo check-env.py https://raw.githubusercontent.com/edgible-org/card-kit/main/check-env.py
python3 check-env.py umami
```

It moves a taken port, as lines to paste. Run it again until it says `no conflicts`.

### 4. Start

```bash
docker compose --env-file umami/card.env -f umami/docker-compose.yml up -d --wait
docker compose --env-file umami/card.env -f umami/docker-compose.yml ps
```

`--wait` returns when each service is running, and healthy when it has a healthcheck. `umami-secrets` makes the secrets first and exits. Umami starts with the account `admin` and the password `umami`, and the `analytics` hostname will make its login page public. Change that password now, before Publish:

```bash
sh umami/prepare.sh
```

[prepare.sh](prepare.sh) is:

```sh
#!/bin/sh
# Prepare for the umami card: change the default password, admin / umami, before the login page is public.
# Run it after Start and before Publish, from the directory that holds umami/:
#   sh umami/prepare.sh
set -eu
cd "$(dirname "$0")"
set -a; . ./card.env; set +a
COMPOSE=${COMPOSE:-docker compose --env-file card.env -f docker-compose.yml}

# The new password is the human secret umami-secrets made on this machine.
UMAMI_ADMIN_PASSWORD=$($COMPOSE run --rm --no-deps umami-secrets show UMAMI_ADMIN_PASSWORD)

B="http://127.0.0.1:$UMAMI_PORT"
H='Content-Type: application/json'
token=$(curl -fsS -X POST "$B/api/auth/login" -H "$H" -d '{"username":"admin","password":"umami"}' \
  | sed -n 's/.*"token":"\([^"]*\)".*/\1/p')
curl -fsS -X POST "$B/api/me/password" -H "$H" -H "Authorization: Bearer $token" \
  -d "{\"currentPassword\":\"umami\",\"newPassword\":\"$UMAMI_ADMIN_PASSWORD\"}" >/dev/null
echo "admin's password is now UMAMI_ADMIN_PASSWORD"
```

It prints `admin's password is now UMAMI_ADMIN_PASSWORD`. Sign in as `admin` with that password, which the `show` command in What prints.

### 5. Publish

```bash
set -euo pipefail
set -a
. umami/card.env
set +a
device_id=$(edgible device list --json | jq -er --arg name "$DEVICE" '
  map(select(.name == $name))
  | if length == 1 then .[0].id
    else error("need exactly one device named " + $name + " (" + (map(.status + " " + .id) | join(", ")) + ")")
    end
')
edgible app create existing \
  --non-interactive \
  --name umami \
  --port "$UMAMI_PORT" \
  --protocol https \
  --auth-modes org \
  --device-id "$device_id"
edgible app create existing \
  --non-interactive \
  --name analytics \
  --port "$UMAMI_PORT" \
  --protocol https \
  --auth-modes none \
  --device-id "$device_id"
edgible app list
```

## Verify

`umami` uses `org`.

```bash
curl -sS -o /dev/null -w '%{http_code} %{redirect_url}\n' "https://<umami hostname>"
```

That prints `302` and an `edgible.com/application-access/` address, so the org sign-in is in front. Open the hostname in a browser, sign in, then sign in to Umami with the password you set in Start.

`analytics` uses `none`.

```bash
curl -sS -o /dev/null -w '%{http_code}\n' "https://<analytics hostname>"
```

That prints `200`. Fetch `/script.js` on it to see the tracking script, with no login.

The rest of the setup is in the [Umami docs](https://umami.is/docs).

## Tear down

Four steps, in this order. Step 1 runs wherever `edgible` is logged in. Steps 2 to 4 run on the machine that runs the containers. Steps 2 and 3 read `card.env`, so keep it until step 4.

### 1. Unpublish

```bash
edgible app delete umami --yes
edgible app delete analytics --yes
```

### 2. Stop

```bash
docker compose --env-file umami/card.env -f umami/docker-compose.yml down
```

### 3. Delete the data

Skip this step to keep the data. The loop copies each volume to a `.tgz` file in this directory first. `umami-secrets.tgz` holds the passwords and keys: keep it as safe as the data, since the data needs it.

```bash
for volume in $(docker volume ls -q --filter label=com.docker.compose.project=umami); do
  docker run --rm -v "$volume:/data:ro" -v "$PWD:/backup" alpine tar -czf "/backup/$volume.tgz" -C /data .
done
docker compose --env-file umami/card.env -f umami/docker-compose.yml down --volumes
```

### 4. Remove the card

```bash
rm -rf umami
```
