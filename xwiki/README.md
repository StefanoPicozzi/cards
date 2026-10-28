# xwiki

## Why

A team wiki is where a group writes down how it does things. Confluence and Notion rent that space to you by the seat. [XWiki](https://www.xwiki.org) is a mature open-source wiki you run yourself: structured pages, page hierarchies, rights per space and page, and an extension system that adds what you need, so the knowledge stays on your own machine.

## What

One app, `xwiki`, on `org`: its people are your team, signed in to Edgible in a browser, and XWiki has no phone or desktop client that would need to get past that sign-in. It runs with its own PostgreSQL database in the same Compose project. Use XWiki's own users and rights, set in the app, for who sees which spaces. For a public knowledge base, this card is not enough: publishing on `none` would also open the wiki's sign-in and admin pages to the internet.

The pages are in the volume `xwiki-db-data` (PostgreSQL), and attachments, extensions and configuration are in `xwiki-data`. The database password is in `xwiki-secrets`. Back up all three together. Minimum recommended for the place `xwiki`: 2 GB of memory and 4 GB of disk, on an arm64 or amd64 machine, with no GPU.

The Compose file is [docker-compose.yml](docker-compose.yml), the settings [card.env](card.env), the card [card.yml](card.yml).

## How

Five steps. Edit [card.env](card.env) before you start.

### 1. Fetch

```bash
mkdir -p xwiki
curl -fsSL https://github.com/edgible-org/cards/archive/refs/heads/main.tar.gz \
  | tar -xz --strip-components=2 -C xwiki cards-main/xwiki
```

### 2. Edit card.env

Set `DEVICE` to a name `edgible device list` prints, and `ORG_LABEL` to the part after the app name in a hostname `edgible app list` prints. Change `XWIKI_PORT` only if 8080 is taken.

```bash
nano xwiki/card.env
```

### 3. Check

```bash
curl -fsSLo check-env.py https://raw.githubusercontent.com/edgible-org/card-kit/main/check-env.py
python3 check-env.py xwiki
```

It moves a taken port, as lines to paste. Run it again until it says `no conflicts`.

### 4. Start

```bash
docker compose --env-file xwiki/card.env -f xwiki/docker-compose.yml pull
docker compose --env-file xwiki/card.env -f xwiki/docker-compose.yml up -d --wait
docker compose --env-file xwiki/card.env -f xwiki/docker-compose.yml ps
```

The first start downloads the app's images from the registries named in the Compose file, which takes longer for a larger app. `pull` does that download on its own, so you can see it. The time is the download, not Edgible, and it happens once: later starts and upgrades reuse the images on the machine and fetch only what changed. `--wait` returns when each service is running, and healthy when it has a healthcheck. The first start is slow: XWiki creates its database and unpacks itself, which takes a few minutes, and `up --wait` waits for it. There is no `prepare.sh`: XWiki makes its first admin in a setup wizard in the browser. Only members of your Edgible organization can reach it once published, and the first of them to open it makes the admin account, so open it yourself straight after Publish.

### 5. Publish

```bash
set -euo pipefail
set -a
. xwiki/card.env
set +a
device_id=$(edgible device list --json | jq -er --arg name "$DEVICE" '
  map(select(.name == $name))
  | if length == 1 then .[0].id
    else error("need exactly one device named " + $name + " (" + (map(.status + " " + .id) | join(", ")) + ")")
    end
')
edgible app create existing \
  --non-interactive \
  --name xwiki \
  --port "$XWIKI_PORT" \
  --protocol https \
  --auth-modes org \
  --device-id "$device_id"
edgible app list
```

**Without Edgible:** only Publish is Edgible's. The app listens on `127.0.0.1` at the port in `card.env`, so any reverse proxy or tunnel on the machine, such as Caddy, nginx, Cloudflare Tunnel or Tailscale, can publish it instead, and sign-in is then that tool's to provide. Every other step stays the same.

## Verify

`xwiki` uses `org`.

```bash
curl -sS -o /dev/null -w '%{http_code} %{redirect_url}\n' "https://<xwiki hostname>"
```

That prints `302` and an `edgible.com/application-access/` address, so the org sign-in is in front. Open the address. After the Edgible sign-in, XWiki shows its wizard: make the admin account, then install the Standard flavor, which downloads from XWiki's extension repository.

The rest of the setup is in the [XWiki administration docs](https://www.xwiki.org/xwiki/bin/view/Documentation/AdminGuide/).

## Tear down

Four steps, in this order. Step 1 runs wherever `edgible` is logged in. Steps 2 to 4 run on the machine that runs the containers. Steps 2 and 3 read `card.env`, so keep it until step 4.

### 1. Unpublish

```bash
edgible app delete xwiki --yes
```

### 2. Stop

```bash
docker compose --env-file xwiki/card.env -f xwiki/docker-compose.yml down
```

### 3. Delete the data

Skip this step to keep the data. The loop copies each volume to a `.tgz` file in this directory first.

```bash
for volume in $(docker volume ls -q --filter label=com.docker.compose.project=xwiki); do
  docker run --rm -v "$volume:/data:ro" -v "$PWD:/backup" alpine tar -czf "/backup/$volume.tgz" -C /data .
done
docker compose --env-file xwiki/card.env -f xwiki/docker-compose.yml down --volumes
```

### 4. Remove the card

```bash
rm -rf xwiki
```
