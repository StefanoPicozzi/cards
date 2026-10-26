# assistant

## Why

Asking questions of your own documents usually means handing those files to someone else's chat. This card keeps the documents and the model on a machine you own. The chat asks for an org login. The model asks for an API key, so another machine you own can call it, and a stranger cannot.

## What

Both apps are the place `desk`, so they stay on one serving device. `assistant` is Open WebUI on port `8088`, behind an org login. `ollama` is the chat model and the embedding model on port `11434`, behind an API key. Open WebUI calls Ollama on the machine, not through the public hostname. The document index stays inside Open WebUI.

Port `8088` is the host port. The website card already uses `8080` for nginx. The Compose file is [docker-compose.yml](docker-compose.yml). It reads the host ports from [card.env](card.env). The sample document is [etc/sample-help.pdf](etc/sample-help.pdf). The card is [card.yml](card.yml).

## How

Six steps. Edit [card.env](card.env) before you start. [docker-compose.yml](docker-compose.yml) reads the host ports from that file.

### 1. Fetch

On the machine that will run the containers, fetch this card. Running this again replaces `card.env`, including the device name and any password you filled in.

```bash
mkdir -p assistant
curl -fsSL https://github.com/edgible-org/cards/archive/refs/heads/main.tar.gz \
  | tar -xz --strip-components=2 -C assistant cards-main/assistant
```

### 2. Edit card.env

Open `assistant/card.env` and follow the comments in that file.

```bash
nano assistant/card.env
```

### 3. Check

Check this machine before anything starts. The check reads `card.env` and looks for what the card would collide with: a host port, a container name, a Compose project, a leftover volume, a device name, or an app name. Each conflict prints its remedy. The report ends with those remedies as lines to paste into a shell: they fill empty secrets and change ports in `card.env`, keeping the old copy as `card.env.bak`. A line that stops or deletes something starts with `#`, so it runs only if you remove the `#`. Run the check again until it says `no conflicts`. It needs `python3` and Docker, and it uses `edgible` when that is installed.

```bash
curl -fsSLo check-env.py https://raw.githubusercontent.com/edgible-org/card-kit/main/check-env.py
python3 check-env.py assistant
```

### 4. Start

```bash
docker compose --env-file assistant/card.env -f assistant/docker-compose.yml pull
docker compose --env-file assistant/card.env -f assistant/docker-compose.yml up -d --wait
```

The first start downloads the app's images from the registries named in the Compose file, which takes longer for a larger app. `pull` does that download on its own, so you can see it. The time is the download, not Edgible, and it happens once: later starts and upgrades reuse the images on the machine and fetch only what changed. `--wait` returns when each service is running, and healthy when it has a healthcheck. A healthcheck comes from the Compose file or from the image. `ps` shows `(healthy)` in the status of each service that has one:

```bash
docker compose --env-file assistant/card.env -f assistant/docker-compose.yml ps
```

If `--wait` stops with `unhealthy`, `logs <service>` with the same `--env-file` and `-f` usually says why.

### 5. Pull the models

`qwen2.5:7b` is the chat model. `nomic-embed-text` is the embedding model. The pulls are large and stay on this machine.

```bash
docker exec ollama ollama pull qwen2.5:7b
docker exec ollama ollama pull nomic-embed-text
```

### 6. Publish

`jq` reads that device's id out of `edgible device list`.

```bash
set -euo pipefail
set -a
. assistant/card.env
set +a
device_id=$(edgible device list --json | jq -er --arg name "$DEVICE" '
  map(select(.name == $name))
  | if length == 1 then .[0].id
    else error("need exactly one device named " + $name + " (" + (map(.status + " " + .id) | join(", ")) + ")")
    end
')
edgible app create existing \
  --non-interactive \
  --name assistant \
  --port "$ASSISTANT_PORT" \
  --protocol https \
  --auth-modes org \
  --device-id "$device_id"
edgible app create existing \
  --non-interactive \
  --name ollama \
  --port "$OLLAMA_PORT" \
  --protocol https \
  --auth-modes api-key \
  --device-id "$device_id"
edgible app list
```

`edgible app list` shows `assistant` with `org` and `ollama` with `api-key`.

## Verify

`edgible app list` prints each hostname. Each app answers the way its auth mode says: `none` with the app, `org` with a redirect to the Edgible sign-in, and `api-key` with `401` until a key is sent. This checks the card. The rest of each app's setup is in that app's docs.

`assistant` uses `org`.

```bash
curl -sS -o /dev/null -w '%{http_code} %{redirect_url}\n' "https://<assistant hostname>"
```

That prints `302` and an `edgible.com/application-access/` address, so the org sign-in is in front. Open the hostname in a browser and sign in. The first visit creates the Open WebUI admin. Upload `assistant/etc/sample-help.pdf` and ask what the support hours are. The answer is weekdays 9 to 5, so the chat reached the model and read the document. The rest of the setup is in the [Open WebUI docs](https://docs.openwebui.com).

`ollama` uses `api-key`. Without a key, it answers `401`.

```bash
curl -sS -o /dev/null -w '%{http_code}\n' "https://<ollama hostname>/api/tags"
```

Create a key. The secret is shown once. The app id is the one `edgible app list` prints for `ollama`.

```bash
edgible app api-keys create --app-id <ollama-app-id> --name caller
```

```bash
curl -fsS "https://<ollama hostname>/api/tags" -H "Authorization: Bearer <secret>"
```

A response means the hostname accepted the key. The rest of the setup is in the [Ollama docs](https://docs.ollama.com).

## Tear down

Four steps, in this order. Step 1 runs wherever `edgible` is logged in. Steps 2 to 4 run on the machine that runs the containers. Steps 2 and 3 read `card.env`, so keep it until step 4.

### 1. Unpublish

Delete the apps first, so no hostname points at a stopped container, and the names are free if you set the card up again.

```bash
edgible app delete assistant --yes
edgible app delete ollama --yes
```

### 2. Stop

This stops and removes the containers. The volumes stay, so Start brings the card back with its data.

```bash
docker compose --env-file assistant/card.env -f assistant/docker-compose.yml down
```

### 3. Delete the data

Skip this step to keep the data. It cannot be undone. The loop first copies each volume to a `.tgz` file in this directory. The containers are stopped, so each copy is whole.

```bash
for volume in $(docker volume ls -q --filter label=com.docker.compose.project=assistant); do
  docker run --rm -v "$volume:/data:ro" -v "$PWD:/backup" alpine tar -czf "/backup/$volume.tgz" -C /data .
done
docker compose --env-file assistant/card.env -f assistant/docker-compose.yml down --volumes
```

To bring a copy back, keep the `card.env` it was made with, because the databases in it expect those passwords. `create` makes the containers and the volumes without starting them. Unpack each copy into its volume, then Start.

```bash
docker compose --env-file assistant/card.env -f assistant/docker-compose.yml create
docker run --rm -v "<volume>:/data" -v "$PWD:/backup" alpine tar -xzf "/backup/<volume>.tgz" -C /data
```

### 4. Remove the card

`card.env` holds the passwords, and `card.env.bak` holds the copy from before the check edited it. If you kept the volumes in step 3, keep `card.env` too. The databases in those volumes expect its passwords.

```bash
rm -rf assistant
```
