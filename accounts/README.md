# accounts

## Why

A site or an app with members needs sign-up, sign-in, a reset for a lost password, and a list of who signed up. That list usually lives with a service someone else runs. This card keeps it on a machine you own. Your visitors sign in on the open hostname. You manage them on a console behind an org login.

The org login protects pages for you and your team. This card is the login for the people who use what you built.

## What

`accounts` is Logto, open to anyone. It serves the sign-in and sign-up pages, and it is the OpenID Connect provider your apps send visitors to. `accounts-admin` is that same process with the Logto console behind an org login. In the console you add your apps, choose how visitors sign in, and manage users. Both share the place `identity`, so they run on one serving device.

Logto keeps all its state in Postgres: users, apps, sign-in settings, sessions, and the keys that sign its tokens. That is the one volume `logto-db-data`. The Logto container holds nothing, and a `pg_dump` of the `logto` database is the whole install. Each user has a `customData` JSON object for small facts about that person, such as a plan or a preference. Keep secrets and the records of your app out of it.

The Compose file is [docker-compose.yml](docker-compose.yml). It reads the host ports, the database password, and `ORG_LABEL` from [card.env](card.env). Logto writes its public URLs into every redirect and token, so it is told them before it starts: the sign-in hostname is `accounts` plus that label, and the console hostname is `accounts-admin` plus that label. On your own domain, `ACCOUNTS_URL` and `ACCOUNTS_ADMIN_URL` replace them. Each start seeds an empty database and applies the database changes for the Logto version in that file. The card is [card.yml](card.yml).

## How

Five steps. Edit [card.env](card.env) before you start. The Compose file reads that file.

### 1. Fetch

On the machine that will run the containers, fetch this card. Running this again replaces `card.env`, including the device name, the password, and the URLs you filled in.

```bash
mkdir -p accounts
curl -fsSL https://github.com/edgible-org/cards/archive/refs/heads/main.tar.gz \
  | tar -xz --strip-components=2 -C accounts cards-main/accounts
```

### 2. Edit card.env

Open `accounts/card.env` and follow the comments in that file.

```bash
nano accounts/card.env
```

### 3. Check

Check this machine before anything starts. The check reads `card.env` and looks for what the card would collide with: a host port, a container name, a Compose project, a leftover volume, a device name, or an app name. Each conflict prints its remedy. The report ends with those remedies as lines to paste into a shell: they fill empty secrets and change ports in `card.env`, keeping the old copy as `card.env.bak`. A line that stops or deletes something starts with `#`, so it runs only if you remove the `#`. Run the check again until it says `no conflicts`. It needs `python3` and Docker, and it uses `edgible` when that is installed.

```bash
curl -fsSLo check-env.py https://raw.githubusercontent.com/edgible-org/card-kit/main/check-env.py
python3 check-env.py accounts
```

### 4. Start

```bash
docker compose --env-file accounts/card.env -f accounts/docker-compose.yml pull
docker compose --env-file accounts/card.env -f accounts/docker-compose.yml up -d --wait
```

The first start downloads the app's images from the registries named in the Compose file, which takes longer for a larger app. `pull` does that download on its own, so you can see it. The time is the download, not Edgible, and it happens once: later starts and upgrades reuse the images on the machine and fetch only what changed. `--wait` returns when each service is running, and healthy when it has a healthcheck. A healthcheck comes from the Compose file or from the image. `ps` shows `(healthy)` in the status of each service that has one:

```bash
docker compose --env-file accounts/card.env -f accounts/docker-compose.yml ps
```

If `--wait` stops with `unhealthy`, `logs <service>` with the same `--env-file` and `-f` usually says why.

### 5. Publish

`jq` reads that device's id out of `edgible device list`.

```bash
set -euo pipefail
set -a
. accounts/card.env
set +a
device_id=$(edgible device list --json | jq -er --arg name "$DEVICE" '
  map(select(.name == $name))
  | if length == 1 then .[0].id
    else error("need exactly one device named " + $name + " (" + (map(.status + " " + .id) | join(", ")) + ")")
    end
')
edgible app create existing \
  --non-interactive \
  --name accounts \
  --port "$ACCOUNTS_PORT" \
  --protocol https \
  --auth-modes none \
  --device-id "$device_id"
edgible app create existing \
  --non-interactive \
  --name accounts-admin \
  --port "$ACCOUNTS_ADMIN_PORT" \
  --protocol https \
  --auth-modes org \
  --device-id "$device_id"
edgible app list
```

`edgible app list` shows `accounts` with `none` and `accounts-admin` with `org`.

## Verify

`edgible app list` prints each hostname. Each app answers the way its auth mode says: `none` with the app, `org` with a redirect to the Edgible sign-in, and `api-key` with `401` until a key is sent. This checks the card. The rest of each app's setup is in that app's docs.

`accounts` uses `none`.

```bash
curl -fsS "https://<accounts hostname>/oidc/.well-known/openid-configuration" | jq -r .issuer
```

That prints `https://<accounts hostname>/oidc`. If it prints `localhost` or another hostname, `ORG_LABEL` in `card.env` does not match the hostname `edgible app list` prints.

`accounts-admin` uses `org`.

```bash
curl -sS -o /dev/null -w '%{http_code} %{redirect_url}\n' "https://<accounts-admin hostname>"
```

That prints `302` and an `edgible.com/application-access/` address, so the org sign-in is in front. Open the hostname in a browser and sign in. Then open `/console` on it. The first visit creates the Logto admin. Add an application for your site there. Its settings give the values your site needs to send visitors to `accounts`. The rest of the setup is in the [Logto docs](https://docs.logto.io).

## Tear down

Four steps, in this order. Step 1 runs wherever `edgible` is logged in. Steps 2 to 4 run on the machine that runs the containers. Steps 2 and 3 read `card.env`, so keep it until step 4.

### 1. Unpublish

Delete the apps first, so no hostname points at a stopped container, and the names are free if you set the card up again.

```bash
edgible app delete accounts --yes
edgible app delete accounts-admin --yes
```

### 2. Stop

This stops and removes the containers. The volumes stay, so Start brings the card back with its data.

```bash
docker compose --env-file accounts/card.env -f accounts/docker-compose.yml down
```

### 3. Delete the data

Skip this step to keep the data. It cannot be undone. The loop first copies each volume to a `.tgz` file in this directory. The containers are stopped, so each copy is whole.

```bash
for volume in $(docker volume ls -q --filter label=com.docker.compose.project=accounts); do
  docker run --rm -v "$volume:/data:ro" -v "$PWD:/backup" alpine tar -czf "/backup/$volume.tgz" -C /data .
done
docker compose --env-file accounts/card.env -f accounts/docker-compose.yml down --volumes
```

To bring a copy back, keep the `card.env` it was made with, because the databases in it expect those passwords. `create` makes the containers and the volumes without starting them. Unpack each copy into its volume, then Start.

```bash
docker compose --env-file accounts/card.env -f accounts/docker-compose.yml create
docker run --rm -v "<volume>:/data" -v "$PWD:/backup" alpine tar -xzf "/backup/<volume>.tgz" -C /data
```

### 4. Remove the card

`card.env` holds the passwords, and `card.env.bak` holds the copy from before the check edited it. If you kept the volumes in step 3, keep `card.env` too. The databases in those volumes expect its passwords.

```bash
rm -rf accounts
```
