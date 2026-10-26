# rallly

## Why

Arranging a time that suits everyone usually means a Doodle poll, with its ads and its paywall for the features a club needs. [Rallly](https://rallly.co) does the same job: you propose dates and times, share a link, and everyone votes, with no account. The polls and the votes stay on a machine you own.

## What

One app, `rallly`, on `none`, with Postgres beside it as `rallly-db`. The people who vote are members, players and customers, who are not in your Edgible organization, so `org` would lock them out. A voter needs only the poll's link. The organizers who create polls sign in with the app's own login, a code emailed to them, and `RALLLY_ALLOWED_EMAILS` limits that to the addresses you list, so nobody else can register. That login needs a mail server: set the `RALLLY_SMTP_` lines. Anyone holding a poll's link can see its votes and names, so share links only with the people it is for.

Polls, votes and accounts live in the volume `rallly-db-data`. Minimum recommended for the place `rallly`: 512 MB of memory and 2 GB of disk, on an arm64 or amd64 machine, with no GPU.

The Compose file is [docker-compose.yml](docker-compose.yml), the settings [card.env](card.env), the card [card.yml](card.yml).

## How

Five steps. Edit [card.env](card.env) before you start.

### 1. Fetch

```bash
mkdir -p rallly
curl -fsSL https://github.com/Edgible/cards/archive/refs/heads/main.tar.gz \
  | tar -xz --strip-components=2 -C rallly cards-main/rallly
```

### 2. Edit card.env

Set `DEVICE` to a name `edgible device list` prints, `ORG_LABEL` to the label in your hostnames, `RALLLY_ALLOWED_EMAILS` to the organizers' addresses, and the `RALLLY_SMTP_` lines to a mail server. The database password and session secret need nothing: Start makes them on the machine.

```bash
nano rallly/card.env
```

### 3. Check

```bash
curl -fsSLo check-env.py https://raw.githubusercontent.com/edgible-org/card-kit/main/check-env.py
python3 check-env.py rallly
```

It moves a taken port, as lines to paste. Run it again until it says `no conflicts`.

### 4. Start

```bash
docker compose --env-file rallly/card.env -f rallly/docker-compose.yml pull
docker compose --env-file rallly/card.env -f rallly/docker-compose.yml up -d --wait
docker compose --env-file rallly/card.env -f rallly/docker-compose.yml ps
```

The first start downloads the app's images from the registries named in the Compose file: about 420 MB, a minute or two on a typical home connection. `pull` does that download on its own, so you can see it. The time is the download, not Edgible, and it happens once: later starts and upgrades reuse the images on the machine and fetch only what changed. `--wait` returns when each service is running, and healthy when it has a healthcheck. Rallly has no setup page and no default account, so nothing needs preparing before Publish.

### 5. Publish

```bash
set -euo pipefail
set -a
. rallly/card.env
set +a
device_id=$(edgible device list --json | jq -er --arg name "$DEVICE" '
  map(select(.name == $name))
  | if length == 1 then .[0].id
    else error("need exactly one device named " + $name + " (" + (map(.status + " " + .id) | join(", ")) + ")")
    end
')
edgible app create existing \
  --non-interactive \
  --name rallly \
  --port "$RALLLY_PORT" \
  --protocol https \
  --auth-modes none \
  --device-id "$device_id"
edgible app list
```

## Verify

`rallly` uses `none`.

```bash
curl -sS -o /dev/null -w '%{http_code}\n' "https://<rallly hostname>"
```

Open the hostname, enter an address from `RALLLY_ALLOWED_EMAILS`, and enter the code Rallly emails you. Create a poll, open its link in a private window, and vote with no account. An address that is not on the list is refused.

The rest of the setup is in the [Rallly docs](https://support.rallly.co/self-hosting).

## Tear down

Four steps, in this order. Step 1 runs wherever `edgible` is logged in. Steps 2 to 4 run on the machine that runs the containers. Steps 2 and 3 read `card.env`, so keep it until step 4.

### 1. Unpublish

```bash
edgible app delete rallly --yes
```

### 2. Stop

```bash
docker compose --env-file rallly/card.env -f rallly/docker-compose.yml down
```

### 3. Delete the data

Skip this step to keep the data. The loop copies each volume to a `.tgz` file in this directory first. `rallly-secrets.tgz` holds the card's passwords and keys: keep it as safe as the data, which needs them.

```bash
for volume in $(docker volume ls -q --filter label=com.docker.compose.project=rallly); do
  docker run --rm -v "$volume:/data:ro" -v "$PWD:/backup" alpine tar -czf "/backup/$volume.tgz" -C /data .
done
docker compose --env-file rallly/card.env -f rallly/docker-compose.yml down --volumes
```

### 4. Remove the card

```bash
rm -rf rallly
```
