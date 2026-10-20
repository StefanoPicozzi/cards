# wordpress

## Why

WordPress runs a large share of the web, and most of it sits with a host you pay every month. [WordPress](https://wordpress.org) runs just as well on a machine you own, with the database beside it.

## What

One app, `wordpress`, on the place `wordpress`, on `none`: it is a public site. Its admin, `/wp-admin`, is on the same hostname, because WordPress sends every request to its one address; Edgible's auth is per hostname, so the admin cannot be put behind `org` on its own. WordPress's login protects it, and the admin password is generated, not chosen.

WordPress keeps its address in its settings, so `WP_HOME` and `WP_SITEURL` are `https://wordpress.<ORG_LABEL>.<EDGIBLE_DOMAIN>`, or `WORDPRESS_URL` on your own domain. A fresh WordPress hands its admin to whoever opens the install page first, so this card installs it from the command line before it is published, with the `wordpress-cli` service, which runs only when asked.

The images are `wordpress:7.1.3-php8.3-apache`, `mariadb:11.8.9`, and `wordpress:cli-2.12.0-php8.3`. To use it in a card, copy the three services, the `x-wordpress-env` block, the two volumes, and the `WORDPRESS_` lines.

Themes, plugins and uploads live in the volume `wordpress-files`, and posts, pages and users in `wordpress-db-data`. Minimum recommended for the place `wordpress`: 384 MB of memory and 2 GB of disk, on an arm64 or amd64 machine, with no GPU.

The Compose file is [docker-compose.yml](docker-compose.yml), the settings [card.env](card.env), the card [card.yml](card.yml), and the last test [test.yml](test.yml).

## How

Five steps. Edit [card.env](card.env) before you start.

### 1. Fetch

```bash
mkdir -p wordpress
curl -fsSL https://github.com/edgible-org/cards/archive/refs/heads/main.tar.gz \
  | tar -xz --strip-components=2 -C wordpress cards-main/wordpress
```

### 2. Edit card.env

Set `DEVICE` to a name `edgible device list` prints, `ORG_LABEL` to the part after the app name in a hostname `edgible app list` prints, and `WORDPRESS_ADMIN_EMAIL` to your address. The two passwords are generated in the next step.

```bash
nano wordpress/card.env
```

### 3. Check

```bash
curl -fsSLo check-env.py https://raw.githubusercontent.com/edgible-org/card-kit/main/check-env.py
python3 check-env.py wordpress
```

It fills each empty secret and moves a taken port, as lines to paste. Run it again until it says `no conflicts`.

### 4. Start

```bash
docker compose --env-file wordpress/card.env -f wordpress/docker-compose.yml up -d --wait
docker compose --env-file wordpress/card.env -f wordpress/docker-compose.yml ps
```

`--wait` returns when each service is running, and healthy when it has a healthcheck. Then install WordPress, before Publish, so its install page is never public:

```bash
sh wordpress/prepare.sh
```

[prepare.sh](prepare.sh) is:

```sh
#!/bin/sh
# Prepare for the wordpress card: install WordPress, so its install page is never public.
# Run it after Start and before Publish, from the directory that holds wordpress/:
#   sh wordpress/prepare.sh
set -eu
cd "$(dirname "$0")"
set -a; . ./card.env; set +a
COMPOSE=${COMPOSE:-docker compose --env-file card.env -f docker-compose.yml}

$COMPOSE --profile cli run --rm -T wordpress-cli \
  wp core install --url="${WORDPRESS_URL:-https://wordpress.$ORG_LABEL.${EDGIBLE_DOMAIN:-edgible.app}}" --title="My site" \
  --admin_user=admin --admin_password="$WORDPRESS_ADMIN_PASSWORD" --admin_email="$WORDPRESS_ADMIN_EMAIL" --skip-email
```

It prints `Success: WordPress installed successfully.` The admin user is `admin`, and its password is `WORDPRESS_ADMIN_PASSWORD` in `card.env`.

### 5. Publish

```bash
set -euo pipefail
set -a
. wordpress/card.env
set +a
device_id=$(edgible device list --json | jq -er --arg name "$DEVICE" '
  map(select(.name == $name))
  | if length == 1 then .[0].id
    else error("need exactly one device named " + $name + " (" + (map(.status + " " + .id) | join(", ")) + ")")
    end
')
edgible app create existing \
  --non-interactive \
  --name wordpress \
  --port "$WORDPRESS_PORT" \
  --protocol https \
  --auth-modes none \
  --device-id "$device_id"
edgible app list
```

## Verify

`wordpress` uses `none`.

```bash
curl -sS -o /dev/null -w '%{http_code}\n' "https://<wordpress hostname>"
```

That prints `200`: the installed site. An uninstalled one would answer `302` to its install page. Open `https://<wordpress hostname>/wp-admin` and sign in as `admin` with `WORDPRESS_ADMIN_PASSWORD`.

The rest of the setup is in the [WordPress docs](https://wordpress.org/documentation/).

## Tear down

Four steps, in this order. Step 1 runs wherever `edgible` is logged in. Steps 2 to 4 run on the machine that runs the containers. Steps 2 and 3 read `card.env`, so keep it until step 4.

### 1. Unpublish

```bash
edgible app delete wordpress --yes
```

### 2. Stop

```bash
docker compose --env-file wordpress/card.env -f wordpress/docker-compose.yml down
```

### 3. Delete the data

Skip this step to keep the data. The loop copies each volume to a `.tgz` file in this directory first.

```bash
for volume in $(docker volume ls -q --filter label=com.docker.compose.project=wordpress); do
  docker run --rm -v "$volume:/data:ro" -v "$PWD:/backup" alpine tar -czf "/backup/$volume.tgz" -C /data .
done
docker compose --env-file wordpress/card.env -f wordpress/docker-compose.yml down --volumes
```

### 4. Remove the card

```bash
rm -rf wordpress
```
