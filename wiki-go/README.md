# wiki-go

## Why

A team wiki is where a team writes down how it does things, and hosted ones (Notion, Confluence) charge per seat and keep your pages on their servers. [Wiki-Go](https://leomoon.com/downloads/web-apps/wiki-go/) is a small open-source wiki that keeps pages as Markdown files, with no database to run. It has admin, editor and viewer roles, user groups, and rules that make a page or folder public, private or restricted to a group. This card runs it on a machine you own, through Edgible.

## What

One app, `wiki-go`, on `org`, so only members of your Edgible organization reach it. Everyone who reads or edits the team wiki is a person in a browser, so the Edgible sign-in is the first door and Wiki-Go's own login the second. One container runs it, as the image's own non-root user. People outside your organization cannot reach it. For a public knowledge base for customers, publish with `none` instead, which is a different choice from this card's: Wiki-Go's access rules then decide what a visitor without an account sees, so set them before you publish. Use Wiki-Go's roles and groups to keep confidential pages to the people who should see them. Wiki-Go starts with the user `admin` and the password `admin`, so `prepare.sh` replaces that password before the wiki is public. Wiki-Go counts failed sign-ins by address and sees the Edgible gateway's address for everyone, so a run of failures from anyone can lock sign-in for a while.

Pages, uploads, users and settings are all files in the volume `wiki-go-data`, and the admin's password the card made is in `wiki-go-secrets`. Copy both. Minimum recommended for the place `wiki-go`: 256 MB of memory and 1 GB of disk, on an arm64 or amd64 machine, with no GPU.

The Compose file is [docker-compose.yml](docker-compose.yml), the settings [card.env](card.env), the card [card.yml](card.yml).

## How

Five steps. Edit [card.env](card.env) before you start.

### 1. Fetch

```bash
mkdir -p wiki-go
curl -fsSL https://github.com/edgible-org/cards/archive/refs/heads/main.tar.gz \
  | tar -xz --strip-components=2 -C wiki-go cards-main/wiki-go
```

### 2. Edit card.env

Set `DEVICE` to a name `edgible device list` prints. Change `WIKI_GO_PORT` only if 8080 is taken.

```bash
nano wiki-go/card.env
```

### 3. Check

```bash
curl -fsSLo check-env.py https://raw.githubusercontent.com/edgible-org/card-kit/main/check-env.py
python3 check-env.py wiki-go
```

It moves a taken port, as lines to paste. Run it again until it says `no conflicts`.

### 4. Start

```bash
docker compose --env-file wiki-go/card.env -f wiki-go/docker-compose.yml pull
docker compose --env-file wiki-go/card.env -f wiki-go/docker-compose.yml up -d --wait
docker compose --env-file wiki-go/card.env -f wiki-go/docker-compose.yml ps
```

The first start downloads the app's images from the registries named in the Compose file, which takes longer for a larger app. `pull` does that download on its own, so you can see it. The time is the download, not Edgible, and it happens once: later starts and upgrades reuse the images on the machine and fetch only what changed. `--wait` returns when each service is running, and healthy when it has a healthcheck. Here that means Wiki-Go answers on its sign-in page. `prepare.sh` replaces the default admin password with the one the card made on this machine, so the wiki is never public with `admin` / `admin`.

```bash
sh wiki-go/prepare.sh
```

[prepare.sh](prepare.sh) is:

```sh
#!/bin/sh
# Prepare for the wiki-go card: replace the default admin password before the wiki is public.
# Wiki-Go starts with the user admin and the password admin; this sets the password the card made.
# Run it after Start and before Publish, from the directory that holds wiki-go/:
#   sh wiki-go/prepare.sh
set -eu
cd "$(dirname "$0")"
set -a; . ./card.env; set +a
COMPOSE=${COMPOSE:-docker compose --env-file card.env -f docker-compose.yml}

# The admin's password is the human secret wiki-go-secrets made on this machine.
WIKI_GO_ADMIN_PASSWORD=$($COMPOSE run --rm --no-deps wiki-go-secrets show WIKI_GO_ADMIN_PASSWORD)

$COMPOSE exec -T -e WIKI_GO_ADMIN_PASSWORD="$WIKI_GO_ADMIN_PASSWORD" wiki-go bash -s <<'EOF'
set -eu
B=http://127.0.0.1:8080
H='Content-Type: application/json'
hdr=$(mktemp)
login() {
  curl -s -D "$hdr" -o /dev/null -w '%{http_code}' -X POST "$B/api/login" -H "$H" \
    -d "{\"username\":\"admin\",\"password\":\"$1\"}"
}
if [ "$(login admin)" != 200 ]; then
  if [ "$(login "$WIKI_GO_ADMIN_PASSWORD")" = 200 ]; then
    echo "the admin password is already set"; exit 0
  fi
  echo "admin signs in with neither the default password nor the card's"; exit 1
fi
token=$(sed -n 's/^[Ss]et-[Cc]ookie: session_token=\([^;]*\).*/\1/p' "$hdr" | head -n 1)
code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$B/api/password" -H "$H" \
  -H "Cookie: session_token=$token" \
  -d "{\"current_password\":\"admin\",\"new_password\":\"$WIKI_GO_ADMIN_PASSWORD\"}")
[ "$code" = 200 ] || { echo "setting the password answered $code"; exit 1; }
EOF
echo "the default password is replaced; admin signs in with the user admin and WIKI_GO_ADMIN_PASSWORD"
```

The admin signs in as the user `admin`, with the password `show` prints (see Verify). Change it in Wiki-Go after the first sign-in if you like; the card's copy only made the first one.

### 5. Publish

```bash
set -euo pipefail
set -a
. wiki-go/card.env
set +a
device_id=$(edgible device list --json | jq -er --arg name "$DEVICE" '
  map(select(.name == $name))
  | if length == 1 then .[0].id
    else error("need exactly one device named " + $name + " (" + (map(.status + " " + .id) | join(", ")) + ")")
    end
')
edgible app create existing \
  --non-interactive \
  --name wiki-go \
  --port "$WIKI_GO_PORT" \
  --protocol https \
  --auth-modes org \
  --device-id "$device_id"
edgible app list
```

**Without Edgible:** only Publish is Edgible's. The app listens on `127.0.0.1` at the port in `card.env`, so any reverse proxy or tunnel on the machine, such as Caddy, nginx, Cloudflare Tunnel or Tailscale, can publish it instead, and sign-in is then that tool's to provide. Every other step stays the same.

## Verify

`wiki-go` uses `org`.

```bash
curl -sS -o /dev/null -w '%{http_code} %{redirect_url}\n' "https://<wiki-go hostname>"
```

That prints `302` and an `edgible.com/application-access/` address, so the org sign-in is in front. The check proves the Edgible sign-in stands in front of the wiki. Then sign in as `admin` with the password from the command below, and add your team under Users in the admin settings. Wiki-Go has no email invitations: you make each account and give its password.

The rest of the setup is in the [Wiki-Go docs](https://github.com/leomoon-studios/wiki-go#readme).

## Tear down

Four steps, in this order. Step 1 runs wherever `edgible` is logged in. Steps 2 to 4 run on the machine that runs the containers. Steps 2 and 3 read `card.env`, so keep it until step 4.

### 1. Unpublish

```bash
edgible app delete wiki-go --yes
```

### 2. Stop

```bash
docker compose --env-file wiki-go/card.env -f wiki-go/docker-compose.yml down
```

### 3. Delete the data

Skip this step to keep the data. The loop copies each volume to a `.tgz` file in this directory first.

```bash
for volume in $(docker volume ls -q --filter label=com.docker.compose.project=wiki-go); do
  docker run --rm -v "$volume:/data:ro" -v "$PWD:/backup" alpine tar -czf "/backup/$volume.tgz" -C /data .
done
docker compose --env-file wiki-go/card.env -f wiki-go/docker-compose.yml down --volumes
```

### 4. Remove the card

```bash
rm -rf wiki-go
```
