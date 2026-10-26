# static-site

## Why

A static site, such as a project's docs, a catalog, or a small business's pages built by a site generator, is usually handed to a hosting service: GitHub Pages, Netlify, Cloudflare Pages, or an S3 bucket. This card serves it from a machine you own instead, through Edgible, and keeps it up to date from wherever the site is built, with no hosting account and no inbound port. [Caddy](https://caddyserver.com) serves the files.

## What

One app, `static-site`, on `none`, because a public site is for anyone. Two containers run it. `static-site-sync` downloads the site as a `.tar.gz` from `STATIC_SITE_SOURCE` every `STATIC_SITE_EVERY` seconds, and puts a new version live only when it downloaded in full, changed, has no paths that reach outside its folder, and has an `index.html` at its top. Going live is one rename, so a visitor never sees half a site, and anything wrong leaves the live site as it is. It runs as its image's own user, not root. `static-site` is Caddy on port `8080`, serving that copy read-only, with its admin API off and no certificate of its own: Edgible gives the site its hostname and HTTPS. A page the site does not have gets the site's own `404.html` when it has one, or, for a single-page app with its own routes, the page `STATIC_SITE_FALLBACK` names, such as `/index.html`, with status 200. The source can be any URL that serves a `.tar.gz`: a branch archive from GitHub, GitLab, or your own Gitea, or a file on any web server. Build the site wherever you like, such as in CI, and publish the build to that branch or URL.

The live version and the one before it live in the volume `static-site-www`. Nothing in it needs a backup: the source has the site. Minimum recommended for the place `static-site`: 256 MB of memory and 1.5 GB of disk, on an arm64, amd64 or 32-bit arm machine, with no GPU.

The Compose file is [docker-compose.yml](docker-compose.yml), the settings [card.env](card.env), the card [card.yml](card.yml), and the last test [test.yml](test.yml).

## How

Five steps. Edit [card.env](card.env) before you start.

### 1. Fetch

```bash
mkdir -p static-site
curl -fsSL https://github.com/edgible-org/cards/archive/refs/heads/main.tar.gz \
  | tar -xz --strip-components=2 -C static-site cards-main/static-site
```

### 2. Edit card.env

Set `DEVICE` to a name `edgible device list` prints, and `STATIC_SITE_SOURCE` to the URL of the site's `.tar.gz`. Keep `STATIC_SITE_STRIP=1` for a Git host's branch archive, which puts everything in one top folder, and set it to `0` for a tarball made from inside the site's folder. Set `STATIC_SITE_FALLBACK=/index.html` when the site is a single-page app with its own routes, such as a React app with React Router, so that opening one of its pages directly works. Change `STATIC_SITE_PORT` only if 8080 is taken.

```bash
nano static-site/card.env
```

### 3. Check

```bash
curl -fsSLo check-env.py https://raw.githubusercontent.com/edgible-org/card-kit/main/check-env.py
python3 check-env.py static-site
```

It fills each empty secret and moves a taken port, as lines to paste. Run it again until it says `no conflicts`.

### 4. Start

```bash
docker compose --env-file static-site/card.env -f static-site/docker-compose.yml pull
docker compose --env-file static-site/card.env -f static-site/docker-compose.yml up -d --wait
docker compose --env-file static-site/card.env -f static-site/docker-compose.yml ps
```

The first start downloads the app's images from the registries named in the Compose file: about 35 MB, under a minute on a typical home connection. `pull` does that download on its own, so you can see it. The time is the download, not Edgible, and it happens once: later starts and upgrades reuse the images on the machine and fetch only what changed. `--wait` returns when each service is running, and healthy when it has a healthcheck. Here that means the first copy of the site is in place and Caddy serves it, so it fails when the source cannot be downloaded or has no `index.html` at its top. Then `docker compose --env-file static-site/card.env -f static-site/docker-compose.yml logs static-site-sync` says why.

### 5. Publish

```bash
set -euo pipefail
set -a
. static-site/card.env
set +a
device_id=$(edgible device list --json | jq -er --arg name "$DEVICE" '
  map(select(.name == $name))
  | if length == 1 then .[0].id
    else error("need exactly one device named " + $name + " (" + (map(.status + " " + .id) | join(", ")) + ")")
    end
')
edgible app create existing \
  --non-interactive \
  --name static-site \
  --port "$STATIC_SITE_PORT" \
  --protocol https \
  --auth-modes none \
  --device-id "$device_id"
edgible app list
```

## Verify

`static-site` uses `none`.

```bash
curl -sS -o /dev/null -w '%{http_code}\n' "https://<static-site hostname>"
```

A new version of the site goes live within `STATIC_SITE_EVERY` seconds of reaching the source, and the sync container logs `live:` with its hash. To serve the site on your own domain, publish with `--hostnames`, and point that name at Edgible as its docs say.

The rest of the setup is in the [Caddy file server docs](https://caddyserver.com/docs/caddyfile/directives/file_server).

## Tear down

Four steps, in this order. Step 1 runs wherever `edgible` is logged in. Steps 2 to 4 run on the machine that runs the containers. Steps 2 and 3 read `card.env`, so keep it until step 4.

### 1. Unpublish

```bash
edgible app delete static-site --yes
```

### 2. Stop

```bash
docker compose --env-file static-site/card.env -f static-site/docker-compose.yml down
```

### 3. Delete the data

Skip this step to keep the data. The loop copies each volume to a `.tgz` file in this directory first.

```bash
for volume in $(docker volume ls -q --filter label=com.docker.compose.project=static-site); do
  docker run --rm -v "$volume:/data:ro" -v "$PWD:/backup" alpine tar -czf "/backup/$volume.tgz" -C /data .
done
docker compose --env-file static-site/card.env -f static-site/docker-compose.yml down --volumes
```

### 4. Remove the card

```bash
rm -rf static-site
```
