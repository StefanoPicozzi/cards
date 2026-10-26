# jellyfin

## Why

Films, shows and music you already own shouldn't need a subscription to watch. [Jellyfin](https://jellyfin.org) is a free media server that streams your own library to its TV, phone and desktop apps and to any browser, from a machine you own.

## What

One app, `jellyfin`, on the place `jellyfin`, on `none`. That is deliberate: Jellyfin's TV, phone and desktop apps cannot get past an Edgible sign-in, so `org` would stop them playing. Jellyfin's own login protects it, and nobody can sign up: the setup wizard makes the admin from the command line before anything is public, and the admin adds everyone else.

It runs one service, `jellyfin`, from the image Jellyfin publishes, pinned to `12.2.20261005-225228`. Your media folder is mounted read-only, so Jellyfin never changes your files. Hardware transcoding is optional: on Linux with an Intel or AMD GPU, uncomment the `devices:` lines in the Compose file. Without it, Jellyfin transcodes on the CPU, or not at all when the app plays the file as it is.

To use it in a card, copy the `jellyfin-secrets` and `jellyfin` services, the three volumes, card.yml's `secrets:`, and the `JELLYFIN_` lines.

Settings, users and watch history live in the volume `jellyfin-config`, and artwork and transcodes in `jellyfin-cache`. Back up `jellyfin-config`; the cache rebuilds. Your media stays in `JELLYFIN_MEDIA_DIR`, outside Docker. The memory below is Jellyfin's own documented minimum, which is higher than an empty test library measures; transcoding several streams wants more. The disk is for Jellyfin itself, not your media. Minimum recommended for the place `jellyfin`: 4 GB of memory and 10 GB of disk, on an arm64 or amd64 machine, with a GPU if you have one (it runs without).

The Compose file is [docker-compose.yml](docker-compose.yml), the settings [card.env](card.env), the card [card.yml](card.yml), and the last test [test.yml](test.yml).

## How

Five steps. Edit [card.env](card.env) before you start.

### 1. Fetch

```bash
mkdir -p jellyfin
curl -fsSL https://github.com/edgible-org/cards/archive/refs/heads/main.tar.gz \
  | tar -xz --strip-components=2 -C jellyfin cards-main/jellyfin
```

### 2. Edit card.env

Set `DEVICE` to a name `edgible device list` prints, and `JELLYFIN_MEDIA_DIR` to the full path of the folder that holds your media. Keep that folder outside `jellyfin/`, because the last Tear down step deletes `jellyfin/`. There is no password to fill: Start makes the admin's on the machine.

```bash
nano jellyfin/card.env
```

### 3. Check

```bash
curl -fsSLo check-env.py https://raw.githubusercontent.com/edgible-org/card-kit/main/check-env.py
python3 check-env.py jellyfin
```

It moves a taken port, as lines to paste. Run it again until it says `no conflicts`.

### 4. Start

```bash
docker compose --env-file jellyfin/card.env -f jellyfin/docker-compose.yml pull
docker compose --env-file jellyfin/card.env -f jellyfin/docker-compose.yml up -d --wait
docker compose --env-file jellyfin/card.env -f jellyfin/docker-compose.yml ps
```

The first start downloads the app's images from the registries named in the Compose file: about 424 MB, a minute or two on a typical home connection. `pull` does that download on its own, so you can see it. The time is the download, not Edgible, and it happens once: later starts and upgrades reuse the images on the machine and fetch only what changed. `--wait` returns when each service is running, and healthy when it has a healthcheck. Then finish Jellyfin's setup wizard, before Publish, so it is never public. Until the wizard is finished, anyone who reaches Jellyfin can make the admin:

```bash
sh jellyfin/prepare.sh
```

[prepare.sh](prepare.sh) is:

```sh
#!/bin/sh
# Prepare for the jellyfin card: finish Jellyfin's setup wizard, so it is never public.
# Run it after Start and before Publish, from the directory that holds jellyfin/:
#   sh jellyfin/prepare.sh
set -eu
cd "$(dirname "$0")"
set -a; . ./card.env; set +a
COMPOSE=${COMPOSE:-docker compose --env-file card.env -f docker-compose.yml}

# The card made this password on this machine at Start (jellyfin-secrets).
JELLYFIN_ADMIN_PASSWORD=$($COMPOSE run --rm --no-deps jellyfin-secrets show JELLYFIN_ADMIN_PASSWORD)

B="http://127.0.0.1:$JELLYFIN_PORT"
H='Content-Type: application/json'
curl -fsS -X POST "$B/Startup/Configuration" -H "$H" \
  -d '{"UICulture":"en-US","MetadataCountryCode":"US","PreferredMetadataLanguage":"en"}'
curl -fsS "$B/Startup/User" >/dev/null
curl -fsS -X POST "$B/Startup/User" -H "$H" \
  -d "{\"Name\":\"$JELLYFIN_ADMIN_USER\",\"Password\":\"$JELLYFIN_ADMIN_PASSWORD\"}"
curl -fsS -X POST "$B/Startup/RemoteAccess" -H "$H" \
  -d '{"EnableRemoteAccess":true,"EnableAutomaticPortMapping":false}'
curl -fsS -X POST "$B/Startup/Complete"
```

It prints nothing when it works.

### 5. Publish

```bash
set -euo pipefail
set -a
. jellyfin/card.env
set +a
device_id=$(edgible device list --json | jq -er --arg name "$DEVICE" '
  map(select(.name == $name))
  | if length == 1 then .[0].id
    else error("need exactly one device named " + $name + " (" + (map(.status + " " + .id) | join(", ")) + ")")
    end
')
edgible app create existing \
  --non-interactive \
  --name jellyfin \
  --port "$JELLYFIN_PORT" \
  --protocol https \
  --auth-modes none \
  --device-id "$device_id"
edgible app list
```

## Verify

`jellyfin` uses `none`.

```bash
curl -sS -o /dev/null -w '%{http_code}\n' "https://<jellyfin hostname>"
```

That prints `302`: Jellyfin sending you to its web app, with no Edgible sign-in, as its apps need. Sign in with `JELLYFIN_ADMIN_USER` and the password the card made (`docker compose --env-file jellyfin/card.env -f jellyfin/docker-compose.yml run --rm --no-deps jellyfin-secrets show JELLYFIN_ADMIN_PASSWORD` prints it), and add a library pointing at `/media`. In a Jellyfin app, set the server to `https://<jellyfin hostname>` and sign in the same way.

The rest of the setup is in the [Jellyfin docs](https://jellyfin.org/docs).

## Tear down

Four steps, in this order. Step 1 runs wherever `edgible` is logged in. Steps 2 to 4 run on the machine that runs the containers. Steps 2 and 3 read `card.env`, so keep it until step 4.

### 1. Unpublish

```bash
edgible app delete jellyfin --yes
```

### 2. Stop

```bash
docker compose --env-file jellyfin/card.env -f jellyfin/docker-compose.yml down
```

### 3. Delete the data

Skip this step to keep the data. The loop copies each volume to a `.tgz` file in this directory first. `jellyfin-secrets.tgz` holds the card's passwords and keys: keep it as safe as the data, which needs them.

```bash
for volume in $(docker volume ls -q --filter label=com.docker.compose.project=jellyfin); do
  docker run --rm -v "$volume:/data:ro" -v "$PWD:/backup" alpine tar -czf "/backup/$volume.tgz" -C /data .
done
docker compose --env-file jellyfin/card.env -f jellyfin/docker-compose.yml down --volumes
```

### 4. Remove the card

```bash
rm -rf jellyfin
```
