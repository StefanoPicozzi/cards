# teamdesk

## Why

A small team needs one place to book rooms, hand out tasks and post announcements, and a shared spreadsheet or chat thread gets double-booked. [Teamdesk](https://github.com/stefano-edgible/claude-code-workshop-teamdesk) does it with one SQLite file on a machine you own, and no hosted service or account. It is a small tutorial-style app, written to be read and changed, not a replacement for a full booking system.

## What

One app, `teamdesk`, on `org`. Teamdesk has no sign-in of its own, and anyone who reaches it can act as any member of the team, so it must not be open to the internet. `org` lets in only members of your Edgible organisation, who pick who they are on the page. The image is `ghcr.io/stefano-edgible/teamdesk:1.0.0`, from the author's own registry, built from the app's `Dockerfile` for arm64 and amd64, and runs as a non-root user on Bun.

Everything lives in one SQLite file, `/data/teamdesk.db`, in the volume `teamdesk-data`. Back it up. The first start creates the tables, and the address in `TEAMDESK_ADMIN_EMAIL` becomes the first admin, who adds the rest of the team. Minimum recommended for the place `teamdesk`: 256 MB of memory and 1.5 GB of disk, on an arm64 or amd64 machine, with no GPU.

The Compose file is [docker-compose.yml](docker-compose.yml), the settings [card.env](card.env), the card [card.yml](card.yml), and the last test [test.yml](test.yml).

## How

Five steps. Edit [card.env](card.env) before you start.

### 1. Fetch

```bash
mkdir -p teamdesk
curl -fsSL https://github.com/edgible-org/cards/archive/refs/heads/main.tar.gz \
  | tar -xz --strip-components=2 -C teamdesk cards-main/teamdesk
```

### 2. Edit card.env

Set `TEAMDESK_ADMIN_EMAIL` to the email you sign in to Edgible with (`edgible whoami` prints it) and `TEAMDESK_ADMIN_NAME` to your name.

```bash
nano teamdesk/card.env
```

### 3. Check

```bash
curl -fsSLo check-env.py https://raw.githubusercontent.com/edgible-org/card-kit/main/check-env.py
python3 check-env.py teamdesk
```

It fills each empty secret and moves a taken port, as lines to paste. Run it again until it says `no conflicts`.

### 4. Start

```bash
docker compose --env-file teamdesk/card.env -f teamdesk/docker-compose.yml pull
docker compose --env-file teamdesk/card.env -f teamdesk/docker-compose.yml up -d --wait
docker compose --env-file teamdesk/card.env -f teamdesk/docker-compose.yml ps
```

The first start downloads the app's images from the registries named in the Compose file: about 155 MB once unpacked, a minute or two on a typical home connection. `pull` does that download on its own, so you can see it. The time is the download, not Edgible, and it happens once: later starts and upgrades reuse the images on the machine and fetch only what changed. `--wait` returns when each service is running, and healthy when it has a healthcheck. 

### 5. Publish

```bash
set -euo pipefail
set -a
. teamdesk/card.env
set +a
device_id=$(edgible device list --json | jq -er --arg name "$DEVICE" '
  map(select(.name == $name))
  | if length == 1 then .[0].id
    else error("need exactly one device named " + $name + " (" + (map(.status + " " + .id) | join(", ")) + ")")
    end
')
edgible app create existing \
  --non-interactive \
  --name teamdesk \
  --port "$TEAMDESK_PORT" \
  --protocol https \
  --auth-modes org \
  --device-id "$device_id"
edgible app list
```

**Without Edgible:** only Publish is Edgible's. The app listens on `127.0.0.1` at the port in `card.env`, so any reverse proxy or tunnel on the machine, such as Caddy, nginx, Cloudflare Tunnel or Tailscale, can publish it instead, and sign-in is then that tool's to provide. Every other step stays the same.

## Verify

`teamdesk` uses `org`.

```bash
curl -sS -o /dev/null -w '%{http_code} %{redirect_url}\n' "https://<teamdesk hostname>"
```

That prints `302` and an `edgible.com/application-access/` address, so the org sign-in is in front. Open the address and sign in to Edgible. Teamdesk opens on its home page, which has no member picker. Open Team, where the "Acting as" menu (on Team, Rooms, Bookings and Tasks) already shows the admin from `TEAMDESK_ADMIN_EMAIL`, add the rest of the team there, then add a room under Rooms.

The rest of the setup is in the [Teamdesk docs](https://github.com/stefano-edgible/claude-code-workshop-teamdesk).

## Customising

The card runs a published image, so a change to the app means a new image. You build it on the machine that runs the card, and name it in `card.env`.

The source of `teamdesk` is [github.com/stefano-edgible/claude-code-workshop-teamdesk](https://github.com/stefano-edgible/claude-code-workshop-teamdesk). Its image is built from `Dockerfile`. Tag `v1.0.0` is the code the pinned image was built from.

1. Fork the repository and clone it, then `git checkout v1.0.0`. The fork is yours to keep: a pull request to the repository is how a change reaches everyone.
2. Change it, and try the change with `bun install && bun run dev`, which runs the app from source without a container. Its own README and the files it points to say how the code is laid out.
3. Build the image on the machine that runs the card, from the clone:

   ```bash
   docker build -t teamdesk:custom .
   ```

   `teamdesk:custom` exists only on that machine, which is all the card needs. To run it on another machine, or on a different CPU, push it to a registry you control instead, and build for each CPU the machine has (`docker buildx build --platform linux/amd64,linux/arm64 --push`).
4. Back the card up, because a new version can change the data in a way that cannot be undone (see the card-kit README for `backup-card`).
5. In `teamdesk/card.env`, set `TEAMDESK_IMAGE=teamdesk:custom` (or your registry's name), then start it again:

   ```bash
   docker compose --env-file teamdesk/card.env -f teamdesk/docker-compose.yml up -d --wait
   ```

   The data stays in its volume. Run the Verify step again.

To go back, remove the `TEAMDESK_IMAGE` line, restore the backup if the data changed, and start again.

A feature is usually a table in `packages/db/src/schema.ts`, a query module, a service in `packages/services`, a thin tRPC router and a route. The repository's `CLAUDE.md` lists the rules. After a schema change run `cd packages/db && bun run generate` and commit `migrations/`: the app applies pending migrations when it starts, so existing data is upgraded in place, and cannot be downgraded.

The Compose file stays as published, so a later upgrade of the card keeps your image: your `card.env` line is a setting to keep, not a file to overwrite.

## Tear down

Four steps, in this order. Step 1 runs wherever `edgible` is logged in. Steps 2 to 4 run on the machine that runs the containers. Steps 2 and 3 read `card.env`, so keep it until step 4.

### 1. Unpublish

```bash
edgible app delete teamdesk --yes
```

### 2. Stop

```bash
docker compose --env-file teamdesk/card.env -f teamdesk/docker-compose.yml down
```

### 3. Delete the data

Skip this step to keep the data. The loop copies each volume to a `.tgz` file in this directory first.

```bash
for volume in $(docker volume ls -q --filter label=com.docker.compose.project=teamdesk); do
  docker run --rm -v "$volume:/data:ro" -v "$PWD:/backup" alpine tar -czf "/backup/$volume.tgz" -C /data .
done
docker compose --env-file teamdesk/card.env -f teamdesk/docker-compose.yml down --volumes
```

### 4. Remove the card

```bash
rm -rf teamdesk
```
