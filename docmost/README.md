# docmost

## Why

A team wiki is where a team writes down how it does things, and hosted ones (Notion, Confluence) charge per seat and keep your pages on their servers. [Docmost](https://docmost.com) is an open-source wiki with spaces, page trees, real-time editing, comments, diagrams, and permissions per space and group. This card runs it on a machine you own, through Edgible.

## What

One app, `docmost`, on `org`, so only members of your Edgible organization reach it. Everyone who reads or edits the wiki is a person in a browser, so the Edgible sign-in is the first door and Docmost's own login the second. Three containers run it: Docmost, PostgreSQL for its pages and accounts, and Redis for live editing. People outside your organization cannot reach it. For a public knowledge base for customers, publish with `none` instead and keep sign-up closed, which is a different choice from this card's. Use Docmost's spaces and roles to keep confidential pages to the people who should see them.

Pages and accounts are in the volume `docmost-db-data`, uploaded files in `docmost-data`, and the keys the card made in `docmost-secrets`. Copy all three; the keys unlock the database. Minimum recommended for the place `docmost`: 1 GB of memory and 3 GB of disk, on an arm64 or amd64 machine, with no GPU.

The Compose file is [docker-compose.yml](docker-compose.yml), the settings [card.env](card.env), the card [card.yml](card.yml).

## How

Five steps. Edit [card.env](card.env) before you start.

### 1. Fetch

```bash
mkdir -p docmost
curl -fsSL https://github.com/edgible-org/cards/archive/refs/heads/main.tar.gz \
  | tar -xz --strip-components=2 -C docmost cards-main/docmost
```

### 2. Edit card.env

Set `DEVICE` to a name `edgible device list` prints, `ORG_LABEL` to the label in your hostnames, and `DOCMOST_ADMIN_EMAIL` to your own email, which becomes the admin. Change `DOCMOST_PORT` only if 3000 is taken.

```bash
nano docmost/card.env
```

### 3. Check

```bash
curl -fsSLo check-env.py https://raw.githubusercontent.com/edgible-org/card-kit/main/check-env.py
python3 check-env.py docmost
```

It moves a taken port, as lines to paste. Run it again until it says `no conflicts`.

### 4. Start

```bash
docker compose --env-file docmost/card.env -f docmost/docker-compose.yml pull
docker compose --env-file docmost/card.env -f docmost/docker-compose.yml up -d --wait
docker compose --env-file docmost/card.env -f docmost/docker-compose.yml ps
```

The first start downloads the app's images from the registries named in the Compose file, which takes longer for a larger app. `pull` does that download on its own, so you can see it. The time is the download, not Edgible, and it happens once: later starts and upgrades reuse the images on the machine and fetch only what changed. `--wait` returns when each service is running, and healthy when it has a healthcheck. Here that means Docmost, its database and Redis are healthy. `prepare.sh` makes the workspace and its admin on this machine, so the setup page is never open to a visitor.

```bash
sh docmost/prepare.sh
```

[prepare.sh](prepare.sh) is:

```sh
#!/bin/sh
# Prepare for the docmost card: make the workspace and its admin before the setup page is public.
# Run it after Start and before Publish, from the directory that holds docmost/:
#   sh docmost/prepare.sh
set -eu
cd "$(dirname "$0")"
set -a; . ./card.env; set +a
COMPOSE=${COMPOSE:-docker compose --env-file card.env -f docker-compose.yml}

# The admin's password is the human secret docmost-secrets made on this machine.
DOCMOST_ADMIN_PASSWORD=$($COMPOSE run --rm --no-deps docmost-secrets show DOCMOST_ADMIN_PASSWORD)

# Docmost lets the first visitor to /setup make the workspace; this takes that place.
$COMPOSE exec -T -e DOCMOST_ADMIN_PASSWORD="$DOCMOST_ADMIN_PASSWORD" \
  -e DOCMOST_ADMIN_EMAIL="$DOCMOST_ADMIN_EMAIL" -e DOCMOST_WORKSPACE="${DOCMOST_WORKSPACE:-Team wiki}" docmost node -e '
fetch("http://127.0.0.1:3000/api/auth/setup", {
  method: "POST",
  headers: {"Content-Type": "application/json"},
  body: JSON.stringify({
    workspaceName: process.env.DOCMOST_WORKSPACE,
    name: "Admin",
    email: process.env.DOCMOST_ADMIN_EMAIL,
    password: process.env.DOCMOST_ADMIN_PASSWORD,
  }),
}).then(async (r) => {
  if (!r.ok) { console.error("setup answered " + r.status + ": " + await r.text()); process.exit(1); }
}).catch((e) => { console.error(String(e)); process.exit(1); });
'
echo "the workspace is made; the admin signs in with DOCMOST_ADMIN_EMAIL and DOCMOST_ADMIN_PASSWORD"
```

The admin signs in with `DOCMOST_ADMIN_EMAIL`. Show the password with the `show` command in Verify, and change it in Docmost's settings after the first sign-in.

### 5. Publish

```bash
set -euo pipefail
set -a
. docmost/card.env
set +a
device_id=$(edgible device list --json | jq -er --arg name "$DEVICE" '
  map(select(.name == $name))
  | if length == 1 then .[0].id
    else error("need exactly one device named " + $name + " (" + (map(.status + " " + .id) | join(", ")) + ")")
    end
')
edgible app create existing \
  --non-interactive \
  --name docmost \
  --port "$DOCMOST_PORT" \
  --protocol https \
  --auth-modes org \
  --device-id "$device_id"
edgible app list
```

**Without Edgible:** only Publish is Edgible's. The app listens on `127.0.0.1` at the port in `card.env`, so any reverse proxy or tunnel on the machine, such as Caddy, nginx, Cloudflare Tunnel or Tailscale, can publish it instead, and sign-in is then that tool's to provide. Every other step stays the same.

## Verify

`docmost` uses `org`.

```bash
curl -sS -o /dev/null -w '%{http_code} %{redirect_url}\n' "https://<docmost hostname>"
```

That prints `302` and an `edgible.com/application-access/` address, so the org sign-in is in front. The check proves the Edgible sign-in stands in front of the wiki. Then sign in as the admin and invite your team from Settings, Members. Docmost sends invitations by email only when you configure mail in its settings; without it, copy each invitation link from the members page.

The rest of the setup is in the [Docmost docs](https://docmost.com/docs).

## Tear down

Four steps, in this order. Step 1 runs wherever `edgible` is logged in. Steps 2 to 4 run on the machine that runs the containers. Steps 2 and 3 read `card.env`, so keep it until step 4.

### 1. Unpublish

```bash
edgible app delete docmost --yes
```

### 2. Stop

```bash
docker compose --env-file docmost/card.env -f docmost/docker-compose.yml down
```

### 3. Delete the data

Skip this step to keep the data. The loop copies each volume to a `.tgz` file in this directory first.

```bash
for volume in $(docker volume ls -q --filter label=com.docker.compose.project=docmost); do
  docker run --rm -v "$volume:/data:ro" -v "$PWD:/backup" alpine tar -czf "/backup/$volume.tgz" -C /data .
done
docker compose --env-file docmost/card.env -f docmost/docker-compose.yml down --volumes
```

### 4. Remove the card

```bash
rm -rf docmost
```
