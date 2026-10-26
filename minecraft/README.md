# minecraft

## Why

A Minecraft server for friends usually means renting one, or opening a port on your router. This card runs [Paper](https://papermc.io), a Java server, on a machine you own, with [Geyser and Floodgate](https://geysermc.org) so friends on phones and consoles join the same world as friends on PC. The guide [A game server on Edgible](https://guides.edgible.com/guides/game-server-on-edgible/index.html) walks through the same server step by step.

## What

One container, [itzg/minecraft-server](https://docker-minecraft-server.readthedocs.io), on place `minecraft`, and two apps from it: `mc-java` for Java Edition over TCP on port `25565`, and `mc-bedrock` for Bedrock Edition over UDP on port `29132`, which Geyser answers and translates.

A TCP or UDP app has no auth mode: anyone who has the hostname can reach the port. So the game decides who plays. Online mode checks every Java player's account, the whitelist is on and enforced, and Geyser uses Floodgate, so Bedrock players sign in with their Xbox account and must be on Floodgate's whitelist. Both lists start empty, so no one gets in until you add them.

The server does not start until you accept the [Minecraft EULA](https://www.minecraft.net/eula) in `card.env`.

The world, the plugins and both whitelists live in the volume `minecraft-data`. The world grows as people explore, so give it room beyond the minimum. Minimum recommended for the place `minecraft`: 4 GB of memory and 2 GB of disk, on an arm64 or amd64 machine, with no GPU.

The Compose file is [docker-compose.yml](docker-compose.yml), the settings [card.env](card.env), the card [card.yml](card.yml), and the last test [test.yml](test.yml).

## How

Five steps. Edit [card.env](card.env) before you start.

### 1. Fetch

```bash
mkdir -p minecraft
curl -fsSL https://github.com/edgible-org/cards/archive/refs/heads/main.tar.gz \
  | tar -xz --strip-components=2 -C minecraft cards-main/minecraft
```

### 2. Edit card.env

Set `DEVICE` to a name `edgible device list` prints. Read the EULA and set `MINECRAFT_EULA` to `TRUE`. Change `MINECRAFT_MOTD` if you like; keep its quotes. Nothing here is secret.

```bash
nano minecraft/card.env
```

### 3. Check

```bash
curl -fsSLo check-env.py https://raw.githubusercontent.com/edgible-org/card-kit/main/check-env.py
python3 check-env.py minecraft
```

It fills each empty secret and moves a taken port, as lines to paste. Run it again until it says `no conflicts`.

### 4. Start

```bash
docker compose --env-file minecraft/card.env -f minecraft/docker-compose.yml pull
docker compose --env-file minecraft/card.env -f minecraft/docker-compose.yml up -d --wait
docker compose --env-file minecraft/card.env -f minecraft/docker-compose.yml ps
```

The first start downloads the app's images from the registries named in the Compose file: about 351 MB once unpacked, a minute or two on a typical home connection. `pull` does that download on its own, so you can see it. The time is the download, not Edgible, and it happens once: later starts and upgrades reuse the images on the machine and fetch only what changed. `--wait` returns when each service is running, and healthy when it has a healthcheck. The first start downloads the server and both plugins, which takes a minute or two. Then switch Geyser to Floodgate sign-in, before Publish:

```bash
sh minecraft/prepare.sh
```

[prepare.sh](prepare.sh) is:

```sh
#!/bin/sh
# Prepare for the minecraft card: switch Geyser to Floodgate sign-in, so Bedrock players sign in with Xbox.
# Run it after Start and before Publish, from the directory that holds minecraft/:
#   sh minecraft/prepare.sh
set -eu
cd "$(dirname "$0")"
set -a; . ./card.env; set +a
COMPOSE=${COMPOSE:-docker compose --env-file card.env -f docker-compose.yml}

$COMPOSE exec -T minecraft \
  sed -i 's/auth-type: online/auth-type: floodgate/' /data/plugins/Geyser-Spigot/config.yml
$COMPOSE restart minecraft
$COMPOSE up -d --wait
```

Then add the players, yourself too:

```bash
docker compose --env-file minecraft/card.env -f minecraft/docker-compose.yml exec minecraft rcon-cli whitelist add <java-name>
docker compose --env-file minecraft/card.env -f minecraft/docker-compose.yml exec minecraft rcon-cli fwhitelist add <gamertag>
```

`rcon-cli` sends a command to the running server, so adding a friend later needs no restart.

### 5. Publish

```bash
set -euo pipefail
set -a
. minecraft/card.env
set +a
device_id=$(edgible device list --json | jq -er --arg name "$DEVICE" '
  map(select(.name == $name))
  | if length == 1 then .[0].id
    else error("need exactly one device named " + $name + " (" + (map(.status + " " + .id) | join(", ")) + ")")
    end
')
edgible app create existing \
  --non-interactive \
  --name mc-java \
  --port "$MC_JAVA_PORT" \
  --protocol tcp \
  --auth-modes none \
  --device-id "$device_id"
edgible app create existing \
  --non-interactive \
  --name mc-bedrock \
  --port "$MC_BEDROCK_PORT" \
  --protocol udp \
  --auth-modes none \
  --device-id "$device_id"
edgible app list
```

## Verify

`mc-java` is a TCP app on port `25565`, with no auth mode.

From any machine with Docker, `mc-monitor` speaks Java's status protocol:

```bash
docker run --rm itzg/mc-monitor status --host <mc-java hostname> --port 25565
```

That prints `version=Paper` and the MOTD. In Minecraft Java Edition, add the server `<mc-java hostname>:25565`.


`mc-bedrock` is a UDP app on port `29132`, with no auth mode.

```bash
docker run --rm itzg/mc-monitor status-bedrock --host <mc-bedrock hostname> --port 29132
```

That prints a version. In Bedrock Edition, add a server with the `mc-bedrock` hostname and port `29132`.


The rest of the setup is in the [Docker Minecraft Server docs](https://docker-minecraft-server.readthedocs.io).

## Tear down

Four steps, in this order. Step 1 runs wherever `edgible` is logged in. Steps 2 to 4 run on the machine that runs the containers. Steps 2 and 3 read `card.env`, so keep it until step 4.

### 1. Unpublish

```bash
edgible app delete mc-java --yes
edgible app delete mc-bedrock --yes
```

### 2. Stop

```bash
docker compose --env-file minecraft/card.env -f minecraft/docker-compose.yml down
```

### 3. Delete the data

Skip this step to keep the data. The loop copies each volume to a `.tgz` file in this directory first.

```bash
for volume in $(docker volume ls -q --filter label=com.docker.compose.project=minecraft); do
  docker run --rm -v "$volume:/data:ro" -v "$PWD:/backup" alpine tar -czf "/backup/$volume.tgz" -C /data .
done
docker compose --env-file minecraft/card.env -f minecraft/docker-compose.yml down --volumes
```

### 4. Remove the card

```bash
rm -rf minecraft
```
