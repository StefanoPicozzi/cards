# wiki-js

## Why

A team wiki is where a team writes down how it does things, and hosted ones (Notion, Confluence) charge per seat and keep your pages on their servers. [Wiki.js](https://js.wiki) is an open-source wiki with a visual and a Markdown editor, a page tree, search, page history, groups with per-page access rules, and optional sync of its pages to a Git repository. This card runs it on a machine you own, through Edgible.

## What

One app, `wiki-js`, on `org`, so only members of your Edgible organization reach it. Everyone who reads or edits the wiki is a person in a browser, so the Edgible sign-in is the first door and Wiki.js's own login the second. Two containers run it: Wiki.js and PostgreSQL for its pages, uploads and accounts. People outside your organization cannot reach it. For a public knowledge base for customers, publish with `none` instead and let guests read only the pages you choose, which is a different choice from this card's. Use Wiki.js groups and page rules to keep confidential pages to the people who should see them.

Pages, uploads and accounts are in the volume `wiki-js-db-data`, and the keys the card made are in `wiki-js-secrets`. Copy both; the keys unlock the database. Minimum recommended for the place `wiki-js`: 1 GB of memory and 3 GB of disk, on an arm64 or amd64 machine, with no GPU.

The Compose file is [docker-compose.yml](docker-compose.yml), the settings [card.env](card.env), the card [card.yml](card.yml).

## How

Five steps. Edit [card.env](card.env) before you start.

### 1. Fetch

```bash
mkdir -p wiki-js
curl -fsSL https://github.com/edgible-org/cards/archive/refs/heads/main.tar.gz \
  | tar -xz --strip-components=2 -C wiki-js cards-main/wiki-js
```

### 2. Edit card.env

Set `DEVICE` to a name `edgible device list` prints, `ORG_LABEL` to the label in your hostnames, and `WIKI_JS_ADMIN_EMAIL` to your own email, which becomes the admin. Change `WIKI_JS_PORT` only if 3000 is taken.

```bash
nano wiki-js/card.env
```

### 3. Check

```bash
curl -fsSLo check-env.py https://raw.githubusercontent.com/edgible-org/card-kit/main/check-env.py
python3 check-env.py wiki-js
```

It moves a taken port, as lines to paste. Run it again until it says `no conflicts`.

### 4. Start

```bash
docker compose --env-file wiki-js/card.env -f wiki-js/docker-compose.yml pull
docker compose --env-file wiki-js/card.env -f wiki-js/docker-compose.yml up -d --wait
docker compose --env-file wiki-js/card.env -f wiki-js/docker-compose.yml ps
```

The first start downloads the app's images from the registries named in the Compose file, which takes longer for a larger app. `pull` does that download on its own, so you can see it. The time is the download, not Edgible, and it happens once: later starts and upgrades reuse the images on the machine and fetch only what changed. `--wait` returns when each service is running, and healthy when it has a healthcheck. Here that means Wiki.js and its database are healthy. `prepare.sh` finishes Wiki.js's setup wizard and makes the admin on this machine, so the setup page is never open to a visitor.

```bash
sh wiki-js/prepare.sh
```

[prepare.sh](prepare.sh) is:

```sh
#!/bin/sh
# Prepare for the wiki-js card: finish the setup and make the admin before the setup page is public.
# Run it after Start and before Publish, from the directory that holds wiki-js/:
#   sh wiki-js/prepare.sh
set -eu
cd "$(dirname "$0")"
set -a; . ./card.env; set +a
COMPOSE=${COMPOSE:-docker compose --env-file card.env -f docker-compose.yml}

# The admin's password is the human secret wiki-js-secrets made on this machine.
WIKI_JS_ADMIN_PASSWORD=$($COMPOSE run --rm --no-deps wiki-js-secrets show WIKI_JS_ADMIN_PASSWORD)
WIKI_JS_SITE_URL=${WIKI_JS_URL:-https://wiki-js.${ORG_LABEL:?set ORG_LABEL in card.env}.${EDGIBLE_DOMAIN:-edgible.app}}

# Wiki.js shows a setup wizard to the first visitor; this finishes it, then waits for the wiki to restart.
$COMPOSE exec -T -e WIKI_JS_ADMIN_PASSWORD="$WIKI_JS_ADMIN_PASSWORD" \
  -e WIKI_JS_ADMIN_EMAIL="$WIKI_JS_ADMIN_EMAIL" -e WIKI_JS_SITE_URL="$WIKI_JS_SITE_URL" wiki-js node -e '
const B = "http://127.0.0.1:3000";
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
(async () => {
  const r = await fetch(B + "/finalize", {
    method: "POST",
    headers: {"Content-Type": "application/json"},
    body: JSON.stringify({
      adminEmail: process.env.WIKI_JS_ADMIN_EMAIL,
      adminPassword: process.env.WIKI_JS_ADMIN_PASSWORD,
      adminPasswordConfirm: process.env.WIKI_JS_ADMIN_PASSWORD,
      siteUrl: process.env.WIKI_JS_SITE_URL,
      telemetry: false,
    }),
  });
  const body = await r.text();
  if (!r.ok || body.includes("\"ok\":false")) { console.error("setup answered " + r.status + ": " + body); process.exit(1); }
  for (let i = 0; i < 60; i++) {
    await sleep(2000);
    try {
      const h = await fetch(B + "/healthz");
      if (h.ok && !(await h.text()).trimStart().startsWith("<")) return;
    } catch (e) {}
  }
  console.error("the wiki did not come back after setup");
  process.exit(1);
})();
'
echo "the setup is finished; the admin signs in with WIKI_JS_ADMIN_EMAIL and WIKI_JS_ADMIN_PASSWORD"
```

The admin signs in with `WIKI_JS_ADMIN_EMAIL`. Show the password with the `show` command in Verify, and change it in Wiki.js's administration area after the first sign-in.

### 5. Publish

```bash
set -euo pipefail
set -a
. wiki-js/card.env
set +a
device_id=$(edgible device list --json | jq -er --arg name "$DEVICE" '
  map(select(.name == $name))
  | if length == 1 then .[0].id
    else error("need exactly one device named " + $name + " (" + (map(.status + " " + .id) | join(", ")) + ")")
    end
')
edgible app create existing \
  --non-interactive \
  --name wiki-js \
  --port "$WIKI_JS_PORT" \
  --protocol https \
  --auth-modes org \
  --device-id "$device_id"
edgible app list
```

**Without Edgible:** only Publish is Edgible's. The app listens on `127.0.0.1` at the port in `card.env`, so any reverse proxy or tunnel on the machine, such as Caddy, nginx, Cloudflare Tunnel or Tailscale, can publish it instead, and sign-in is then that tool's to provide. Every other step stays the same.

## Verify

`wiki-js` uses `org`.

```bash
curl -sS -o /dev/null -w '%{http_code} %{redirect_url}\n' "https://<wiki-js hostname>"
```

That prints `302` and an `edgible.com/application-access/` address, so the org sign-in is in front. The check proves the Edgible sign-in stands in front of the wiki. Then sign in as the admin and add your team from Administration, Users, and set who may see what under Groups.

The rest of the setup is in the [Wiki.js docs docs](https://docs.requarks.io).

## Tear down

Four steps, in this order. Step 1 runs wherever `edgible` is logged in. Steps 2 to 4 run on the machine that runs the containers. Steps 2 and 3 read `card.env`, so keep it until step 4.

### 1. Unpublish

```bash
edgible app delete wiki-js --yes
```

### 2. Stop

```bash
docker compose --env-file wiki-js/card.env -f wiki-js/docker-compose.yml down
```

### 3. Delete the data

Skip this step to keep the data. The loop copies each volume to a `.tgz` file in this directory first.

```bash
for volume in $(docker volume ls -q --filter label=com.docker.compose.project=wiki-js); do
  docker run --rm -v "$volume:/data:ro" -v "$PWD:/backup" alpine tar -czf "/backup/$volume.tgz" -C /data .
done
docker compose --env-file wiki-js/card.env -f wiki-js/docker-compose.yml down --volumes
```

### 4. Remove the card

```bash
rm -rf wiki-js
```
