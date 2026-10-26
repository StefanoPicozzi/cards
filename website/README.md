# website

## Why

A site, the editor for its pages, the count of who read it, and a check that it is still up are usually services someone else runs. This card keeps them on machines you own. Strangers can open the site and the tracking script. The editor, the dashboard, and the monitor ask for an org login.

## What

`site` is a Vite React app, open to anyone. nginx serves the static build. The sample page is in those files, so the same build can be uploaded to S3. On this card, nginx forwards `/api` to Strapi, and a reload shows an edit from the editor. `strapi` is the editor behind an org login, and it needs Postgres. The editor stays on its own hostname. `analytics` is the Umami tracking script, also open. `umami` is that same process with its dashboard behind an org login, and it needs its own Postgres. Those four share the place `web`, so they run on one serving device. `status` is Uptime Kuma behind an org login, on the place `monitor`, which can be a second serving device. A monitor on the same machine as the site cannot report that machine going down.

The Compose files are [docker-compose.yml](docker-compose.yml), [umami-compose.yml](umami-compose.yml), and [kuma-compose.yml](kuma-compose.yml). They read the host ports and the secrets from [card.env](card.env). The Vite app is [site](site). The Strapi project is [strapi](strapi). The card is [card.yml](card.yml).

## How

Six steps. Edit [card.env](card.env) before you start. The Compose files read that file.

### 1. Fetch

On the machine that will run the containers, fetch this card. Running this again replaces `card.env`, including the device name and any password you filled in.

```bash
mkdir -p website
curl -fsSL https://github.com/edgible-org/cards/archive/refs/heads/main.tar.gz \
  | tar -xz --strip-components=2 -C website cards-main/website
```

### 2. Edit card.env

Open `website/card.env` and follow the comments in that file.

```bash
nano website/card.env
```

### 3. Check

Check this machine before anything starts. The check reads `card.env` and looks for what the card would collide with: a host port, a container name, a Compose project, a leftover volume, a device name, or an app name. Each conflict prints its remedy. The report ends with those remedies as lines to paste into a shell: they fill empty secrets and change ports in `card.env`, keeping the old copy as `card.env.bak`. A line that stops or deletes something starts with `#`, so it runs only if you remove the `#`. Run the check again until it says `no conflicts`. It needs `python3` and Docker, and it uses `edgible` when that is installed.

```bash
curl -fsSLo check-env.py https://raw.githubusercontent.com/edgible-org/card-kit/main/check-env.py
python3 check-env.py website -f docker-compose.yml -f umami-compose.yml
```

On the machine for place `monitor`, check the file that runs there:

```bash
python3 check-env.py website -f kuma-compose.yml
```

When both places are one machine, leave out `-f` and the check covers all three files.

### 4. Start the site and Umami

Place `web` runs these two Compose files. The Vite site and Strapi images are built from this card.

```bash
docker compose --env-file website/card.env -f website/docker-compose.yml up -d --wait --build
docker compose --env-file website/card.env -f website/umami-compose.yml pull
docker compose --env-file website/card.env -f website/umami-compose.yml up -d --wait
```

The first start downloads the app's images from the registries named in the Compose file, which takes longer for a larger app. `pull` does that download on its own, so you can see it. The time is the download, not Edgible, and it happens once: later starts and upgrades reuse the images on the machine and fetch only what changed. `--wait` returns when each service is running, and healthy when it has a healthcheck. A healthcheck comes from the Compose file or from the image. `ps` shows `(healthy)` in the status of each service that has one:

```bash
docker compose --env-file website/card.env -f website/docker-compose.yml ps
docker compose --env-file website/card.env -f website/umami-compose.yml ps
```

If `--wait` stops with `unhealthy`, `logs <service>` with the same `--env-file` and `-f` usually says why.

### 5. Start the monitor

On the machine for place `monitor`, fetch this card the same way and edit `card.env` there. Then:

```bash
docker compose --env-file website/card.env -f website/kuma-compose.yml pull
docker compose --env-file website/card.env -f website/kuma-compose.yml up -d --wait
```

The first start downloads the app's images from the registries named in the Compose file, which takes longer for a larger app. `pull` does that download on its own, so you can see it. The time is the download, not Edgible, and it happens once: later starts and upgrades reuse the images on the machine and fetch only what changed. `--wait` returns when each service is running, and healthy when it has a healthcheck. A healthcheck comes from the Compose file or from the image. `ps` shows `(healthy)` in the status of each service that has one:

```bash
docker compose --env-file website/card.env -f website/kuma-compose.yml ps
```

If `--wait` stops with `unhealthy`, `logs <service>` with the same `--env-file` and `-f` usually says why.

When both places are the same machine, run the `up` command in the same directory. That file reads `STATUS_PORT`.

### 6. Publish

`jq` reads each device's id out of `edgible device list`.

```bash
set -euo pipefail
set -a
. website/card.env
set +a
device_id() {
  edgible device list --json | jq -er --arg name "$1" '
    map(select(.name == $name))
    | if length == 1 then .[0].id
      else error("need exactly one device named " + $name + " (" + (map(.status + " " + .id) | join(", ")) + ")")
      end
  '
}
web_id=$(device_id "$WEB_DEVICE")
monitor_id=$(device_id "$MONITOR_DEVICE")
edgible app create existing \
  --non-interactive \
  --name site \
  --port "$SITE_PORT" \
  --protocol https \
  --auth-modes none \
  --device-id "$web_id"
edgible app create existing \
  --non-interactive \
  --name strapi \
  --port "$STRAPI_PORT" \
  --protocol https \
  --auth-modes org \
  --device-id "$web_id"
edgible app create existing \
  --non-interactive \
  --name analytics \
  --port "$UMAMI_PORT" \
  --protocol https \
  --auth-modes none \
  --device-id "$web_id"
edgible app create existing \
  --non-interactive \
  --name umami \
  --port "$UMAMI_PORT" \
  --protocol https \
  --auth-modes org \
  --device-id "$web_id"
edgible app create existing \
  --non-interactive \
  --name status \
  --port "$STATUS_PORT" \
  --protocol https \
  --auth-modes org \
  --device-id "$monitor_id"
edgible app list
```

`edgible app list` shows `site` and `analytics` with `none`, and `strapi`, `umami`, and `status` with `org`.

## Verify

`edgible app list` prints each hostname. Each app answers the way its auth mode says: `none` with the app, `org` with a redirect to the Edgible sign-in, and `api-key` with `401` until a key is sent. This checks the card. The rest of each app's setup is in that app's docs.

`site` uses `none`.

```bash
curl -fsS "https://<site hostname>" | grep -o "Served from a box I own."
```

That prints the sentence. It is the sample Page in Strapi, so the site reached Strapi through `/api`. Edit the Page in the editor and reload the site.

`strapi` uses `org`.

```bash
curl -sS -o /dev/null -w '%{http_code} %{redirect_url}\n' "https://<strapi hostname>"
```

That prints `302` and an `edgible.com/application-access/` address, so the org sign-in is in front. Open the hostname in a browser and sign in. The first visit creates the Strapi admin. The rest of the setup is in the [Strapi docs](https://docs.strapi.io).

`analytics` uses `none`.

```bash
curl -fsS "https://<analytics hostname>/script.js" | head -c 60
```

That prints the start of the tracking script, not the Edgible sign-in.

`umami` uses `org`.

```bash
curl -sS -o /dev/null -w '%{http_code} %{redirect_url}\n' "https://<umami hostname>"
```

That prints `302` and an `edgible.com/application-access/` address, so the org sign-in is in front. Open the hostname in a browser and sign in. Umami starts with the account `admin` and the password `umami`. Change that password first. The rest of the setup is in the [Umami docs](https://docs.umami.is/docs).

`status` uses `org`.

```bash
curl -sS -o /dev/null -w '%{http_code} %{redirect_url}\n' "https://<status hostname>"
```

That prints `302` and an `edgible.com/application-access/` address, so the org sign-in is in front. Open the hostname in a browser and sign in. The first visit creates the Uptime Kuma admin. The rest of the setup is in the [Uptime Kuma docs](https://github.com/louislam/uptime-kuma/wiki).

## Tear down

Four steps, in this order. Step 1 runs wherever `edgible` is logged in. Steps 2 to 4 run on the machine for each place. Steps 2 and 3 read `card.env`, so keep it until step 4.

### 1. Unpublish

Delete the apps first, so no hostname points at a stopped container, and the names are free if you set the card up again.

```bash
edgible app delete site --yes
edgible app delete strapi --yes
edgible app delete analytics --yes
edgible app delete umami --yes
edgible app delete status --yes
```

### 2. Stop

This stops and removes the containers. The volumes stay, so Start brings the card back with its data.

On the machine for place `web`:

```bash
docker compose --env-file website/card.env -f website/docker-compose.yml down
docker compose --env-file website/card.env -f website/umami-compose.yml down
```

On the machine for place `monitor`:

```bash
docker compose --env-file website/card.env -f website/kuma-compose.yml down
```

### 3. Delete the data

Skip this step to keep the data. It cannot be undone. The loop first copies each volume to a `.tgz` file in this directory. The containers are stopped, so each copy is whole.

On the machine for place `web`:

```bash
for volume in $(docker volume ls -q --filter label=com.docker.compose.project=site); do
  docker run --rm -v "$volume:/data:ro" -v "$PWD:/backup" alpine tar -czf "/backup/$volume.tgz" -C /data .
done
for volume in $(docker volume ls -q --filter label=com.docker.compose.project=umami); do
  docker run --rm -v "$volume:/data:ro" -v "$PWD:/backup" alpine tar -czf "/backup/$volume.tgz" -C /data .
done
docker compose --env-file website/card.env -f website/docker-compose.yml down --volumes
docker compose --env-file website/card.env -f website/umami-compose.yml down --volumes
```

On the machine for place `monitor`:

```bash
for volume in $(docker volume ls -q --filter label=com.docker.compose.project=status); do
  docker run --rm -v "$volume:/data:ro" -v "$PWD:/backup" alpine tar -czf "/backup/$volume.tgz" -C /data .
done
docker run --rm -v "$PWD/website/data:/data:ro" -v "$PWD:/backup" alpine tar -czf "/backup/status-data.tgz" -C /data .
docker compose --env-file website/card.env -f website/kuma-compose.yml down --volumes
docker run --rm -v "$PWD/website:/card" alpine rm -rf "/card/data"
```

Uptime Kuma keeps its data in the folder `website/data`, not in a volume, so the `monitor` step copies that folder to `status-data.tgz` and then removes it. Both run in a container, because the folder belongs to the container's user.

To bring a copy back, keep the `card.env` it was made with, because the databases in it expect those passwords. `create` makes the containers and the volumes without starting them. Unpack each copy into its volume, then Start.

```bash
docker compose --env-file website/card.env -f website/docker-compose.yml create
docker compose --env-file website/card.env -f website/umami-compose.yml create
docker compose --env-file website/card.env -f website/kuma-compose.yml create
docker run --rm -v "<volume>:/data" -v "$PWD:/backup" alpine tar -xzf "/backup/<volume>.tgz" -C /data
docker run --rm -v "$PWD/website/data:/data" -v "$PWD:/backup" alpine tar -xzf "/backup/status-data.tgz" -C /data
```

### 4. Remove the card

`card.env` holds the passwords, and `card.env.bak` holds the copy from before the check edited it. If you kept the volumes in step 3, keep `card.env` too. The databases in those volumes expect its passwords.

```bash
docker image rm website-site:latest website-strapi:latest
rm -rf website
```

The card built those two images. The images it pulled stay, because other containers may use them. `docker image prune` removes the ones nothing uses.
