# leafwiki

## Why

A team wiki is where a team writes down how it does things, and hosted ones (Notion, Confluence) charge per seat and keep your pages on their servers. [LeafWiki](https://github.com/perber/leafwiki) is a small, fast wiki for people who think in folders: pages sit in a tree, are written in Markdown, and are kept as plain files on disk, so they are easy to back up and to take with you. It has admin, editor, and viewer roles. This card runs it on a machine you own, through Edgible.

## What

One app, `leafwiki`, on `org`, so only members of your Edgible organization reach it. Everyone who reads or edits the wiki is a person in a browser, so the Edgible sign-in is the first door and LeafWiki's own login the second. One container runs it, with no database: the pages are files. People outside your organization cannot reach it. LeafWiki serves plain HTTP on the machine, because Edgible ends HTTPS in front of it, so the card sets `LEAFWIKI_ALLOW_INSECURE`. For a public knowledge base for customers, publish with `none` instead and set `LEAFWIKI_PUBLIC_ACCESS=true` in the Compose file, so anyone can read and only your editors can change pages; that is a different choice from this card's. Use viewer, editor, and admin roles to decide who may change what.

The pages and uploads are files in the volume `leafwiki-data`, and the key and admin password the card made are in `leafwiki-secrets`. Copy both. Minimum recommended for the place `leafwiki`: 256 MB of memory and 1 GB of disk, on an arm64 or amd64 machine, with no GPU.

The Compose file is [docker-compose.yml](docker-compose.yml), the settings [card.env](card.env), the card [card.yml](card.yml).

## How

Five steps. Edit [card.env](card.env) before you start.

### 1. Fetch

```bash
mkdir -p leafwiki
curl -fsSL https://github.com/edgible-org/cards/archive/refs/heads/main.tar.gz \
  | tar -xz --strip-components=2 -C leafwiki cards-main/leafwiki
```

### 2. Edit card.env

Set `DEVICE` to a name `edgible device list` prints, `ORG_LABEL` to the label in your hostnames, and `LEAFWIKI_ADMIN_EMAIL` to your own email. Change `LEAFWIKI_PORT` only if 8080 is taken.

```bash
nano leafwiki/card.env
```

### 3. Check

```bash
curl -fsSLo check-env.py https://raw.githubusercontent.com/edgible-org/card-kit/main/check-env.py
python3 check-env.py leafwiki
```

It moves a taken port, as lines to paste. Run it again until it says `no conflicts`.

### 4. Start

```bash
docker compose --env-file leafwiki/card.env -f leafwiki/docker-compose.yml pull
docker compose --env-file leafwiki/card.env -f leafwiki/docker-compose.yml up -d --wait
docker compose --env-file leafwiki/card.env -f leafwiki/docker-compose.yml ps
```

The first start downloads the app's images from the registries named in the Compose file, which takes longer for a larger app. `pull` does that download on its own, so you can see it. The time is the download, not Edgible, and it happens once: later starts and upgrades reuse the images on the machine and fetch only what changed. `--wait` returns when each service is running, and healthy when it has a healthcheck. LeafWiki makes its admin, named `admin`, at its first start from the password the card made on this machine, so no setup page is ever public and no prepare step is needed.

### 5. Publish

```bash
set -euo pipefail
set -a
. leafwiki/card.env
set +a
device_id=$(edgible device list --json | jq -er --arg name "$DEVICE" '
  map(select(.name == $name))
  | if length == 1 then .[0].id
    else error("need exactly one device named " + $name + " (" + (map(.status + " " + .id) | join(", ")) + ")")
    end
')
edgible app create existing \
  --non-interactive \
  --name leafwiki \
  --port "$LEAFWIKI_PORT" \
  --protocol https \
  --auth-modes org \
  --device-id "$device_id"
edgible app list
```

**Without Edgible:** only Publish is Edgible's. The app listens on `127.0.0.1` at the port in `card.env`, so any reverse proxy or tunnel on the machine, such as Caddy, nginx, Cloudflare Tunnel or Tailscale, can publish it instead, and sign-in is then that tool's to provide. Every other step stays the same.

## Verify

`leafwiki` uses `org`.

```bash
curl -sS -o /dev/null -w '%{http_code} %{redirect_url}\n' "https://<leafwiki hostname>"
```

That prints `302` and an `edgible.com/application-access/` address, so the org sign-in is in front. The check proves the Edgible sign-in stands in front of the wiki. Then sign in as `admin` with the password shown by the command below, change it in LeafWiki, and add your team under users. Show the password on the machine with `docker compose --env-file leafwiki/card.env -f leafwiki/docker-compose.yml run --rm --no-deps leafwiki-secrets show LEAFWIKI_ADMIN_PASSWORD`.

The rest of the setup is in the [LeafWiki docs](https://github.com/perber/leafwiki).

## Tear down

Four steps, in this order. Step 1 runs wherever `edgible` is logged in. Steps 2 to 4 run on the machine that runs the containers. Steps 2 and 3 read `card.env`, so keep it until step 4.

### 1. Unpublish

```bash
edgible app delete leafwiki --yes
```

### 2. Stop

```bash
docker compose --env-file leafwiki/card.env -f leafwiki/docker-compose.yml down
```

### 3. Delete the data

Skip this step to keep the data. The loop copies each volume to a `.tgz` file in this directory first.

```bash
for volume in $(docker volume ls -q --filter label=com.docker.compose.project=leafwiki); do
  docker run --rm -v "$volume:/data:ro" -v "$PWD:/backup" alpine tar -czf "/backup/$volume.tgz" -C /data .
done
docker compose --env-file leafwiki/card.env -f leafwiki/docker-compose.yml down --volumes
```

### 4. Remove the card

```bash
rm -rf leafwiki
```
