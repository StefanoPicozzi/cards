# vaultwarden

## Why

A password manager is the one service whose data you most want on a machine you own. [Vaultwarden](https://github.com/dani-garcia/vaultwarden) is a small server that the official Bitwarden apps, browser extensions and web vault all talk to.

## What

One app, `vaultwarden`, on the place `vaultwarden`, on `none`. That is deliberate: the Bitwarden phone apps, desktop apps and browser extensions cannot get past an Edgible sign-in, so `org` would lock them out. Vaultwarden's own protections take its place: every vault is encrypted with its owner's master password, sign-ups are off (`SIGNUPS_ALLOWED: "false"`), so nobody can create an account unless you invite them, and the `/admin` page needs `VAULTWARDEN_ADMIN_TOKEN`.

Vaultwarden must know its own address, so `DOMAIN` is `https://vaultwarden.<ORG_LABEL>.<EDGIBLE_DOMAIN>`, or `VAULTWARDEN_URL` on your own domain. The image is `vaultwarden/server:1.37.4`, with its own healthcheck.

The admin token is a long random string the card makes on the machine at first start, in the volume `vaultwarden-secrets`; it never leaves the machine. Vaultwarden prints a notice recommending an Argon2 hash of it instead.

Vaults, attachments and settings live in the volume `vaultwarden-data`. Back it up; it holds everyone's encrypted vault. Minimum recommended for the place `vaultwarden`: 256 MB of memory and 1.5 GB of disk, on an arm64, amd64 or 32-bit arm machine, with no GPU.

The Compose file is [docker-compose.yml](docker-compose.yml), the settings [card.env](card.env), the card [card.yml](card.yml), and the last test [test.yml](test.yml).

## How

Five steps. Edit [card.env](card.env) before you start.

### 1. Fetch

```bash
mkdir -p vaultwarden
curl -fsSL https://github.com/edgible-org/cards/archive/refs/heads/main.tar.gz \
  | tar -xz --strip-components=2 -C vaultwarden cards-main/vaultwarden
```

### 2. Edit card.env

Set `DEVICE` to a name `edgible device list` prints, and `ORG_LABEL` to the part after the app name in a hostname `edgible app list` prints. There is no token to fill: Start makes it on the machine.

```bash
nano vaultwarden/card.env
```

### 3. Check

```bash
curl -fsSLo check-env.py https://raw.githubusercontent.com/edgible-org/card-kit/main/check-env.py
python3 check-env.py vaultwarden
```

It moves a taken port, as lines to paste. Run it again until it says `no conflicts`.

### 4. Start

```bash
docker compose --env-file vaultwarden/card.env -f vaultwarden/docker-compose.yml pull
docker compose --env-file vaultwarden/card.env -f vaultwarden/docker-compose.yml up -d --wait
docker compose --env-file vaultwarden/card.env -f vaultwarden/docker-compose.yml ps
```

The first start downloads the app's images from the registries named in the Compose file: about 91 MB, under a minute on a typical home connection. `pull` does that download on its own, so you can see it. The time is the download, not Edgible, and it happens once: later starts and upgrades reuse the images on the machine and fetch only what changed. `--wait` returns when each service is running, and healthy when it has a healthcheck. The image's own healthcheck applies.

### 5. Publish

```bash
set -euo pipefail
set -a
. vaultwarden/card.env
set +a
device_id=$(edgible device list --json | jq -er --arg name "$DEVICE" '
  map(select(.name == $name))
  | if length == 1 then .[0].id
    else error("need exactly one device named " + $name + " (" + (map(.status + " " + .id) | join(", ")) + ")")
    end
')
edgible app create existing \
  --non-interactive \
  --name vaultwarden \
  --port "$VAULTWARDEN_PORT" \
  --protocol https \
  --auth-modes none \
  --device-id "$device_id"
edgible app list
```

## Verify

`vaultwarden` uses `none`.

```bash
curl -sS -o /dev/null -w '%{http_code}\n' "https://<vaultwarden hostname>"
```

That prints `200`: the web vault, with no Edgible sign-in, as the apps need. Open `https://<vaultwarden hostname>/admin`, enter the admin token (`docker compose --env-file vaultwarden/card.env -f vaultwarden/docker-compose.yml run --rm --no-deps vaultwarden-secrets show VAULTWARDEN_ADMIN_TOKEN` prints it), and invite yourself under **Users**. With no mail server set up, the invited address can then create its account on the web vault. Then point a Bitwarden app at `https://<vaultwarden hostname>` as a self-hosted server.

The rest of the setup is in the [Vaultwarden docs](https://github.com/dani-garcia/vaultwarden/wiki).

## Tear down

Four steps, in this order. Step 1 runs wherever `edgible` is logged in. Steps 2 to 4 run on the machine that runs the containers. Steps 2 and 3 read `card.env`, so keep it until step 4.

### 1. Unpublish

```bash
edgible app delete vaultwarden --yes
```

### 2. Stop

```bash
docker compose --env-file vaultwarden/card.env -f vaultwarden/docker-compose.yml down
```

### 3. Delete the data

Skip this step to keep the data. The loop copies each volume to a `.tgz` file in this directory first. `vaultwarden-secrets.tgz` holds the card's passwords and keys: keep it as safe as the data, which needs them.

```bash
for volume in $(docker volume ls -q --filter label=com.docker.compose.project=vaultwarden); do
  docker run --rm -v "$volume:/data:ro" -v "$PWD:/backup" alpine tar -czf "/backup/$volume.tgz" -C /data .
done
docker compose --env-file vaultwarden/card.env -f vaultwarden/docker-compose.yml down --volumes
```

### 4. Remove the card

```bash
rm -rf vaultwarden
```
