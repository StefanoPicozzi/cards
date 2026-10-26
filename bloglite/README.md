# bloglite

## Why

A blog on Medium or Substack lives under that platform's terms, feed and fees. [bloglite](https://github.com/rikhuijzer/bloglite) is a small micro-blog with Markdown, syntax highlighting, math and image uploads, which you publish to from your phone or laptop, on a machine you own. It has no newsletter emails and no paid members: it suits a personal or project blog, not a replacement for Substack's mailing list or paywall.

## What

One app, `bloglite`, on `none`. A blog is public, so readers need no Edgible sign-in, and the owner's own login in bloglite, from `BLOGLITE_ADMIN_USER` and a password the card makes on the machine, protects publishing. bloglite has no sign-up page and no first-visit setup, so the owner exists from the first start and no `prepare.sh` is needed. The image is `zot.huijzer.xyz/bloglite:3.1.0`, from the author's own registry, and it runs on arm64 and amd64. From 3.1.0 bloglite reads its password from a file (`BLOGLITE_PASSWORD_FILE`), which is why the image, with no shell, can keep it out of the environment and out of the Compose file. A small service, `bloglite-secrets`, makes that file at first start in the volume `bloglite-secrets`. The Compose file uses the image's own health command. The image has no shell, so a second, tiny container, `bloglite-tools` (Alpine), only runs the data fingerprint by reading the blog over the Compose network.

Posts, uploads and settings live in a SQLite database in the volume `bloglite-data`, at `/data`. Back it up. Minimum recommended for the place `bloglite`: 128 MB of memory and 1 GB of disk, on an arm64 or amd64 machine, with no GPU.

The Compose file is [docker-compose.yml](docker-compose.yml), the settings [card.env](card.env), the card [card.yml](card.yml).

## How

Five steps. Edit [card.env](card.env) before you start.

### 1. Fetch

```bash
mkdir -p bloglite
curl -fsSL https://github.com/edgible-org/cards/archive/refs/heads/main.tar.gz \
  | tar -xz --strip-components=2 -C bloglite cards-main/bloglite
```

### 2. Edit card.env

Set `DEVICE` to a name `edgible device list` prints, and `ORG_LABEL` to the part after the app name in a hostname `edgible app list` prints. There is no password to fill: Start makes the owner's on the machine. Set `BLOGLITE_DOMAIN` only if you publish on your own domain.

```bash
nano bloglite/card.env
```

### 3. Check

```bash
curl -fsSLo check-env.py https://raw.githubusercontent.com/edgible-org/card-kit/main/check-env.py
python3 check-env.py bloglite
```

It moves a taken port, as lines to paste. Run it again until it says `no conflicts`.

### 4. Start

```bash
docker compose --env-file bloglite/card.env -f bloglite/docker-compose.yml pull
docker compose --env-file bloglite/card.env -f bloglite/docker-compose.yml up -d --wait
docker compose --env-file bloglite/card.env -f bloglite/docker-compose.yml ps
```

The first start downloads the app's images from the registries named in the Compose file: about 10 MB once unpacked, under a minute on a typical home connection. `pull` does that download on its own, so you can see it. The time is the download, not Edgible, and it happens once: later starts and upgrades reuse the images on the machine and fetch only what changed. `--wait` returns when each service is running, and healthy when it has a healthcheck. Here that means bloglite is running and its health command passes.

### 5. Publish

```bash
set -euo pipefail
set -a
. bloglite/card.env
set +a
device_id=$(edgible device list --json | jq -er --arg name "$DEVICE" '
  map(select(.name == $name))
  | if length == 1 then .[0].id
    else error("need exactly one device named " + $name + " (" + (map(.status + " " + .id) | join(", ")) + ")")
    end
')
edgible app create existing \
  --non-interactive \
  --name bloglite \
  --port "$BLOGLITE_PORT" \
  --protocol https \
  --auth-modes none \
  --device-id "$device_id"
edgible app list
```

**Without Edgible:** only Publish is Edgible's. The app listens on `127.0.0.1` at the port in `card.env`, so any reverse proxy or tunnel on the machine, such as Caddy, nginx, Cloudflare Tunnel or Tailscale, can publish it instead, and sign-in is then that tool's to provide. Every other step stays the same.

## Verify

`bloglite` uses `none`.

```bash
curl -sS -o /dev/null -w '%{http_code}\n' "https://<bloglite hostname>"
```

The public blog, with no Edgible sign-in. Open `/login` and sign in as `BLOGLITE_ADMIN_USER` with the password `bloglite-secrets` made on the machine at first start, then write a first post. See it with:

```bash
docker compose --env-file bloglite/card.env -f bloglite/docker-compose.yml run --rm --no-deps bloglite-secrets show BLOGLITE_ADMIN_PASSWORD
```

If you ran an earlier version of this card, its `BLOGLITE_ADMIN_PASSWORD` line in `card.env` is no longer read: the first start after the update makes a new password, so show it with the command above.

The rest of the setup is in the [bloglite docs](https://github.com/rikhuijzer/bloglite).

## Tear down

Four steps, in this order. Step 1 runs wherever `edgible` is logged in. Steps 2 to 4 run on the machine that runs the containers. Steps 2 and 3 read `card.env`, so keep it until step 4.

### 1. Unpublish

```bash
edgible app delete bloglite --yes
```

### 2. Stop

```bash
docker compose --env-file bloglite/card.env -f bloglite/docker-compose.yml down
```

### 3. Delete the data

Skip this step to keep the data. The loop copies each volume to a `.tgz` file in this directory first.

```bash
for volume in $(docker volume ls -q --filter label=com.docker.compose.project=bloglite); do
  docker run --rm -v "$volume:/data:ro" -v "$PWD:/backup" alpine tar -czf "/backup/$volume.tgz" -C /data .
done
docker compose --env-file bloglite/card.env -f bloglite/docker-compose.yml down --volumes
```

### 4. Remove the card

```bash
rm -rf bloglite
```
