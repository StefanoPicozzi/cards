# club-noticeboard

## Why

A club or committee needs one place for notices (fixtures, closures, AGM dates) that every member can read without yet another account, and that only the committee can change. A group chat buries them and a shared document lets anyone edit. [Club noticeboard](https://github.com/StefanoPicozzi/club-noticeboard) is a deliberately small Flask and SQLite app for exactly that, on a machine the club controls. It has no member accounts, comments or email: it suits a noticeboard, not a forum or a mailing list.

## What

One app, `club-noticeboard`, on `none`. Members are not in your Edgible organisation, so readers need no Edgible sign-in, and the committee's own password protects posting and deleting. There is one committee password, shared by the committee, and no sign-up page. A small service, `club-noticeboard-secrets`, makes that password and the key that signs the login cookie at first start, as files in the volume `club-noticeboard-secrets`, and the app reads them from there (`ADMIN_PASSWORD_FILE`, `SECRET_KEY_FILE`), so neither is in `card.env` or the environment. The image is `ghcr.io/stefanopicozzi/club-noticeboard:1.0.0`, for arm64 and amd64; it runs as a user other than root and its own healthcheck calls `/healthz`. Its forms carry a CSRF token and the login cookie is sent over HTTPS only.

The notices are one SQLite file, `/app/data/notices.db`, in the volume `club-noticeboard-data`. Back it up with the secrets volume. Minimum recommended for the place `club-noticeboard`: 256 MB of memory and 1.5 GB of disk, on an arm64 or amd64 machine, with no GPU.

The Compose file is [docker-compose.yml](docker-compose.yml), the settings [card.env](card.env), the card [card.yml](card.yml), and the last test [test.yml](test.yml).

## How

Five steps. Edit [card.env](card.env) before you start.

### 1. Fetch

```bash
mkdir -p club-noticeboard
curl -fsSL https://github.com/edgible-org/cards/archive/refs/heads/main.tar.gz \
  | tar -xz --strip-components=2 -C club-noticeboard cards-main/club-noticeboard
```

### 2. Edit card.env

Set `DEVICE` to a name `edgible device list` prints, and `CLUB_NOTICEBOARD_CLUB_NAME` to the club's name. There is no password to fill in: Start makes the committee's on the machine.

```bash
nano club-noticeboard/card.env
```

### 3. Check

```bash
curl -fsSLo check-env.py https://raw.githubusercontent.com/edgible-org/card-kit/main/check-env.py
python3 check-env.py club-noticeboard
```

It moves a taken port, as lines to paste. Run it again until it says `no conflicts`.

### 4. Start

```bash
docker compose --env-file club-noticeboard/card.env -f club-noticeboard/docker-compose.yml pull
docker compose --env-file club-noticeboard/card.env -f club-noticeboard/docker-compose.yml up -d --wait
docker compose --env-file club-noticeboard/card.env -f club-noticeboard/docker-compose.yml ps
```

The first start downloads the app's images from the registries named in the Compose file: about 54 MB, under a minute on a typical home connection. `pull` does that download on its own, so you can see it. The time is the download, not Edgible, and it happens once: later starts and upgrades reuse the images on the machine and fetch only what changed. `--wait` returns when each service is running, and healthy when it has a healthcheck. The committee password exists from the first start, so there is no first-visit setup and no `prepare.sh`. To see it, on the machine, run `docker compose --env-file club-noticeboard/card.env -f club-noticeboard/docker-compose.yml run --rm --no-deps club-noticeboard-secrets show CLUB_NOTICEBOARD_ADMIN_PASSWORD`, and give it to the committee.

### 5. Publish

```bash
set -euo pipefail
set -a
. club-noticeboard/card.env
set +a
device_id=$(edgible device list --json | jq -er --arg name "$DEVICE" '
  map(select(.name == $name))
  | if length == 1 then .[0].id
    else error("need exactly one device named " + $name + " (" + (map(.status + " " + .id) | join(", ")) + ")")
    end
')
edgible app create existing \
  --non-interactive \
  --name club-noticeboard \
  --port "$CLUB_NOTICEBOARD_PORT" \
  --protocol https \
  --auth-modes none \
  --device-id "$device_id"
edgible app list
```

**Without Edgible:** only Publish is Edgible's. The app listens on `127.0.0.1` at the port in `card.env`, so any reverse proxy or tunnel on the machine, such as Caddy, nginx, Cloudflare Tunnel or Tailscale, can publish it instead, and sign-in is then that tool's to provide. Every other step stays the same.

## Verify

`club-noticeboard` uses `none`.

```bash
curl -sS -o /dev/null -w '%{http_code}\n' "https://<club-noticeboard hostname>"
```

The noticeboard answers on its hostname with no Edgible sign-in, and the card's check signs in as the committee at `/login`, posts a notice and deletes it, and checks that a wrong password is refused.

The rest of the setup is in the [Club noticeboard docs](https://github.com/StefanoPicozzi/club-noticeboard).

## Customising

The card runs a published image, so a change to the app means a new image. You build it on the machine that runs the card, and name it in `card.env`.

The source of `club-noticeboard` is [github.com/StefanoPicozzi/club-noticeboard](https://github.com/StefanoPicozzi/club-noticeboard). Its image is built from `Dockerfile`. Tag `v1.0.0` is the code the pinned image was built from.

1. Fork the repository and clone it, then `git checkout v1.0.0`. The fork is yours to keep: a pull request to the repository is how a change reaches everyone.
2. Change it, and try the change with `pip install -r requirements.txt && ADMIN_PASSWORD=dev SECRET_KEY=dev SESSION_COOKIE_SECURE=0 DB_PATH=./data/notices.db flask --app app run`, which runs the app from source without a container. Its own README and the files it points to say how the code is laid out.
3. Build the image on the machine that runs the card, from the clone:

   ```bash
   docker build -t club-noticeboard:custom .
   ```

   `club-noticeboard:custom` exists only on that machine, which is all the card needs. To run it on another machine, or on a different CPU, push it to a registry you control instead, and build for each CPU the machine has (`docker buildx build --platform linux/amd64,linux/arm64 --push`).
4. Back the card up, because a new version can change the data in a way that cannot be undone (see the card-kit README for `backup-card`).
5. In `club-noticeboard/card.env`, set `CLUB_NOTICEBOARD_IMAGE=club-noticeboard:custom` (or your registry's name), then start it again:

   ```bash
   docker compose --env-file club-noticeboard/card.env -f club-noticeboard/docker-compose.yml up -d --wait
   ```

   The data stays in its volume. Run the Verify step again.

To go back, remove the `CLUB_NOTICEBOARD_IMAGE` line, restore the backup if the data changed, and start again.

The app is one file, `app.py`, with its templates inline. It creates its table on first use, so a change that alters the table needs its own migration step; back up first.

The Compose file stays as published, so a later upgrade of the card keeps your image: your `card.env` line is a setting to keep, not a file to overwrite.

## Tear down

Four steps, in this order. Step 1 runs wherever `edgible` is logged in. Steps 2 to 4 run on the machine that runs the containers. Steps 2 and 3 read `card.env`, so keep it until step 4.

### 1. Unpublish

```bash
edgible app delete club-noticeboard --yes
```

### 2. Stop

```bash
docker compose --env-file club-noticeboard/card.env -f club-noticeboard/docker-compose.yml down
```

### 3. Delete the data

Skip this step to keep the data. The loop copies each volume to a `.tgz` file in this directory first.

```bash
for volume in $(docker volume ls -q --filter label=com.docker.compose.project=club-noticeboard); do
  docker run --rm -v "$volume:/data:ro" -v "$PWD:/backup" alpine tar -czf "/backup/$volume.tgz" -C /data .
done
docker compose --env-file club-noticeboard/card.env -f club-noticeboard/docker-compose.yml down --volumes
```

### 4. Remove the card

```bash
rm -rf club-noticeboard
```
