# otter-wiki

## Why

A team wiki is where a team writes down how it does things, and hosted ones (Notion, Confluence) charge per seat and keep your pages on their servers. [Otter Wiki](https://otterwiki.com) is a small, fast wiki written in Markdown, with a page index, attachments, search, and a Git history of every change. This card runs it on a machine you own, through Edgible.

## What

One app, `otter-wiki`, on `org`, so only members of your Edgible organization reach it. Everyone who reads or edits the wiki is a person in a browser, so the Edgible sign-in is the first door and the wiki's own account, which names the author of each change, is the second. Reading and writing both need that account. One container runs it, with its pages in a Git repository and its accounts in a small database, both in one volume. People outside your organization cannot reach it. For a public knowledge base for customers, publish with `none` instead and set `READ_ACCESS` to `ANONYMOUS` in the Compose file, which is a different choice from this card's. Use the admin's user list to approve who may edit.

The pages, history, accounts and uploads are in the volume `otter-wiki-data`, and the key the card made is in `otter-wiki-secrets`. Copy both. Minimum recommended for the place `otter-wiki`: 256 MB of memory and 1.5 GB of disk, on an arm64 or amd64 machine, with no GPU.

The pages and their Git history, the accounts and the uploaded files are in the volume `otter-wiki-data`. The key that signs sessions is in `otter-wiki-secrets`. Minimum recommended for the place `otter-wiki`: 256 MB of memory and 1.5 GB of disk, on an arm64 or amd64 machine, with no GPU.

The Compose file is [docker-compose.yml](docker-compose.yml), the settings [card.env](card.env), the card [card.yml](card.yml).

## How

Five steps. Edit [card.env](card.env) before you start.

### 1. Fetch

```bash
mkdir -p otter-wiki
curl -fsSL https://github.com/edgible-org/cards/archive/refs/heads/main.tar.gz \
  | tar -xz --strip-components=2 -C otter-wiki cards-main/otter-wiki
```

### 2. Edit card.env

Set `DEVICE` to a name `edgible device list` prints, `ORG_LABEL` to the label in your hostnames, and `OTTER_WIKI_ADMIN_EMAIL` to your own email. Change `OTTER_WIKI_PORT` only if 8080 is taken.

```bash
nano otter-wiki/card.env
```

### 3. Check

```bash
curl -fsSLo check-env.py https://raw.githubusercontent.com/edgible-org/card-kit/main/check-env.py
python3 check-env.py otter-wiki
```

It moves a taken port, as lines to paste. Run it again until it says `no conflicts`.

### 4. Start

```bash
docker compose --env-file otter-wiki/card.env -f otter-wiki/docker-compose.yml pull
docker compose --env-file otter-wiki/card.env -f otter-wiki/docker-compose.yml up -d --wait
docker compose --env-file otter-wiki/card.env -f otter-wiki/docker-compose.yml ps
```

The first start downloads the app's images from the registries named in the Compose file, which takes longer for a larger app. `pull` does that download on its own, so you can see it. The time is the download, not Edgible, and it happens once: later starts and upgrades reuse the images on the machine and fetch only what changed. `--wait` returns when each service is running, and healthy when it has a healthcheck. Here that means Otter Wiki answers its health check. There is nothing to prepare: no one is an admin until the account with `OTTER_WIKI_ADMIN_EMAIL` registers, and only members of your Edgible organization can reach the sign-up page once the app is published.

### 5. Publish

```bash
set -euo pipefail
set -a
. otter-wiki/card.env
set +a
device_id=$(edgible device list --json | jq -er --arg name "$DEVICE" '
  map(select(.name == $name))
  | if length == 1 then .[0].id
    else error("need exactly one device named " + $name + " (" + (map(.status + " " + .id) | join(", ")) + ")")
    end
')
edgible app create existing \
  --non-interactive \
  --name otter-wiki \
  --port "$OTTER_WIKI_PORT" \
  --protocol https \
  --auth-modes org \
  --device-id "$device_id"
edgible app list
```

**Without Edgible:** only Publish is Edgible's. The app listens on `127.0.0.1` at the port in `card.env`, so any reverse proxy or tunnel on the machine, such as Caddy, nginx, Cloudflare Tunnel or Tailscale, can publish it instead, and sign-in is then that tool's to provide. Every other step stays the same.

## Verify

`otter-wiki` uses `org`.

```bash
curl -sS -o /dev/null -w '%{http_code} %{redirect_url}\n' "https://<otter-wiki hostname>"
```

That prints `302` and an `edgible.com/application-access/` address, so the org sign-in is in front. Open the hostname, sign in to Edgible, then choose Register in the wiki. Register with the email in `OTTER_WIKI_ADMIN_EMAIL` first: that account is the admin, with a Settings page for users and permissions. Without the wiki's own account the pages are not shown.

The rest of the setup is in the [Otter Wiki docs](https://otterwiki.com/Configuration).

## Tear down

Four steps, in this order. Step 1 runs wherever `edgible` is logged in. Steps 2 to 4 run on the machine that runs the containers. Steps 2 and 3 read `card.env`, so keep it until step 4.

### 1. Unpublish

```bash
edgible app delete otter-wiki --yes
```

### 2. Stop

```bash
docker compose --env-file otter-wiki/card.env -f otter-wiki/docker-compose.yml down
```

### 3. Delete the data

Skip this step to keep the data. The loop copies each volume to a `.tgz` file in this directory first.

```bash
for volume in $(docker volume ls -q --filter label=com.docker.compose.project=otter-wiki); do
  docker run --rm -v "$volume:/data:ro" -v "$PWD:/backup" alpine tar -czf "/backup/$volume.tgz" -C /data .
done
docker compose --env-file otter-wiki/card.env -f otter-wiki/docker-compose.yml down --volumes
```

### 4. Remove the card

```bash
rm -rf otter-wiki
```
