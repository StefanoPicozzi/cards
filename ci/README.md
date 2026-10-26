# ci

## Why

Code, reviews and CI usually sit on someone else's forge, and the build minutes are rented. This card runs [Gitea](https://about.gitea.com), a complete Git forge with Actions, on a machine you own, and its CI runner on a second machine, so builds use your own hardware.

## What

Two places. `forge` runs Gitea and its Postgres, and publishes two hostnames: `gitea` for the web, the API, and Git over HTTPS, and `gitea-ssh` for Git over SSH, a TCP app on port `22222`. `runner` runs Gitea's [act_runner](https://docs.gitea.com/usage/actions/act-runner) and publishes nothing: it connects out to the `gitea` hostname, takes jobs, and runs each one in a container.

The runner has a machine of its own on purpose. A job runs whatever its workflow says, and the runner starts jobs through the Docker socket, which gives it full control of the machine it is on. Kept away from Gitea, a bad or compromised workflow can harm only the runner's machine, not your repositories, and a heavy build does not slow Gitea down. For a small, trusted setup, both places can be the same machine.

Both hostnames are on `none`, as in the gitea card: `git`, the runner, API tokens and webhooks cannot get past an Edgible sign-in. Registration is off, the web installer is never served, and the admin is made from the command line before anything is public. Gitea and the runner share `GITEA_RUNNER_TOKEN` from `card.env`, so the runner registers itself.

Built from the [gitea card](../gitea), plus the runner.

Repositories and settings live in the volume `gitea-data`, users and issues in `gitea-db-data`, both on place `forge`; the runner keeps its registration in `gitea-runner-data`. The runner's numbers are for the jobs it runs, not the runner itself, which needs little: each job is a container with its own image and caches, so give that machine room for your builds. Minimum recommended for the place `forge`: 384 MB of memory and 1.5 GB of disk, on an arm64 or amd64 machine, with no GPU. Minimum recommended for the place `runner`: 2 GB of memory and 10 GB of disk, on an arm64 or amd64 machine, with no GPU.

The Compose file is [docker-compose.yml](docker-compose.yml), the settings [card.env](card.env), the card [card.yml](card.yml), and the last test [test.yml](test.yml).

## How

Six steps. Edit [card.env](card.env) before you start.

### 1. Fetch

```bash
mkdir -p ci
curl -fsSL https://github.com/edgible-org/cards/archive/refs/heads/main.tar.gz \
  | tar -xz --strip-components=2 -C ci cards-main/ci
```

On each machine that runs a place, fetch the card and set up `card.env` the same way: the places share its settings.

### 2. Edit card.env

Set `FORGE_DEVICE` and `RUNNER_DEVICE` to names `edgible device list` prints (the same name if both places are one machine), `ORG_LABEL` to the part after the app name in a hostname `edgible app list` prints, and `GITEA_ADMIN_EMAIL` to your address. The four secrets are generated in the next step. Copy the finished `card.env` to the runner's machine as well.

```bash
nano ci/card.env
```

### 3. Check

```bash
curl -fsSLo check-env.py https://raw.githubusercontent.com/edgible-org/card-kit/main/check-env.py
python3 check-env.py ci
```

It fills each empty secret and moves a taken port, as lines to paste. Run it again until it says `no conflicts`.

### 4. Start

On the machine for place `forge`:

```bash
docker compose --env-file ci/card.env -f ci/docker-compose.yml pull
docker compose --env-file ci/card.env -f ci/docker-compose.yml up -d --wait
docker compose --env-file ci/card.env -f ci/docker-compose.yml ps
```

The first start downloads the app's images from the registries named in the Compose file: about 203 MB once unpacked, a minute or two on a typical home connection. `pull` does that download on its own, so you can see it. The time is the download, not Edgible, and it happens once: later starts and upgrades reuse the images on the machine and fetch only what changed. `--wait` returns when each service is running, and healthy when it has a healthcheck. Then make the admin on place `forge`, before Publish:

```bash
sh ci/prepare.sh
```

[prepare.sh](prepare.sh) is:

```sh
#!/bin/sh
# Prepare for the ci card: make Gitea's admin on place forge, before Publish.
# Run it on the forge machine after Start and before Publish, from the directory that holds ci/:
#   sh ci/prepare.sh
set -eu
cd "$(dirname "$0")"
set -a; . ./card.env; set +a
COMPOSE=${COMPOSE:-docker compose --env-file card.env -f docker-compose.yml}

$COMPOSE exec -T -u git gitea \
  gitea admin user create --admin --username gitadmin \
  --password "$GITEA_ADMIN_PASSWORD" --email "$GITEA_ADMIN_EMAIL" --must-change-password=false
```

It prints `New user 'gitadmin' has been successfully created!` Gitea reserves the name `admin`, so the admin is `gitadmin`.

### 5. Publish

```bash
set -euo pipefail
set -a
. ci/card.env
set +a
device_id() {
  edgible device list --json | jq -er --arg name "$1" '
    map(select(.name == $name))
    | if length == 1 then .[0].id
      else error("need exactly one device named " + $name + " (" + (map(.status + " " + .id) | join(", ")) + ")")
      end
  '
}
forge_id=$(device_id "$FORGE_DEVICE")
edgible app create existing \
  --non-interactive \
  --name gitea \
  --port "$GITEA_PORT" \
  --protocol https \
  --auth-modes none \
  --device-id "$forge_id"
edgible app create existing \
  --non-interactive \
  --name gitea-ssh \
  --port "$GITEA_SSH_PORT" \
  --protocol tcp \
  --auth-modes none \
  --device-id "$forge_id"
edgible app list
```

### 6. Start the runner

On the machine for place `runner`. Its services connect out to what Publish published, so they start now.

```bash
docker compose --env-file ci/card.env -f ci/runner-compose.yml pull
docker compose --env-file ci/card.env -f ci/runner-compose.yml up -d --wait
docker compose --env-file ci/card.env -f ci/runner-compose.yml ps
```

The runner registers with Gitea at the `gitea` hostname, with `GITEA_RUNNER_TOKEN`. It mounts the Docker socket, so it controls this machine's Docker: run it only on a machine where that is acceptable.

## Verify

`gitea` uses `none`.

```bash
curl -sS -o /dev/null -w '%{http_code}\n' "https://<gitea hostname>"
```

That prints `200`. Sign in as `gitadmin` with `GITEA_ADMIN_PASSWORD`. Then check the runner, from any machine:

```bash
set -a; . ci/card.env; set +a
sh ci/etc/verify-ci.sh runner
sh ci/etc/verify-ci.sh workflow
```

The first says `a runner is online`. The second makes a private repository, `ci-check`, with a one-step workflow, and says `the workflow ran to success` once the runner has run it; give it a minute and run it again if it does not yet.


`gitea-ssh` is a TCP app on port `22222`, with no auth mode.

Check it answers as an SSH server with `nc -w 5 <gitea-ssh hostname> 22222 </dev/null | head -1`, which prints a line starting `SSH-2.0-`.


The rest of the setup is in the [Gitea Actions docs](https://docs.gitea.com/usage/actions/overview).

## Tear down

Four steps, in this order. Step 1 runs wherever `edgible` is logged in. Steps 2 to 4 run on the machine for each place. Steps 2 and 3 read `card.env`, so keep it until step 4.

### 1. Unpublish

```bash
edgible app delete gitea --yes
edgible app delete gitea-ssh --yes
```

### 2. Stop

On the machine for place `runner`:

```bash
docker compose --env-file ci/card.env -f ci/runner-compose.yml down
```

On the machine for place `forge`:

```bash
docker compose --env-file ci/card.env -f ci/docker-compose.yml down
```

### 3. Delete the data

Skip this step to keep the data. The loop copies each volume to a `.tgz` file in this directory first.

On the machine for place `runner`:

```bash
for volume in $(docker volume ls -q --filter label=com.docker.compose.project=ci-runner); do
  docker run --rm -v "$volume:/data:ro" -v "$PWD:/backup" alpine tar -czf "/backup/$volume.tgz" -C /data .
done
docker compose --env-file ci/card.env -f ci/runner-compose.yml down --volumes
```

On the machine for place `forge`:

```bash
for volume in $(docker volume ls -q --filter label=com.docker.compose.project=ci-forge); do
  docker run --rm -v "$volume:/data:ro" -v "$PWD:/backup" alpine tar -czf "/backup/$volume.tgz" -C /data .
done
docker compose --env-file ci/card.env -f ci/docker-compose.yml down --volumes
```

### 4. Remove the card

```bash
rm -rf ci
```
