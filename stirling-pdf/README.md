# stirling-pdf

## Why

Merging, splitting, compressing, converting, or reading the text out of a PDF usually means uploading it to someone's website. [Stirling-PDF](https://github.com/Stirling-Tools/Stirling-PDF) does all of that on a machine you own, so the documents never leave it. This card puts it behind your org login.

## What

One app, `stirling-pdf`, on the place `stirling-pdf`, behind `org`. Edgible's login is in front, so Stirling-PDF's own login stays off (`SECURITY_ENABLELOGIN: "false"`).

The image is `stirlingtools/stirling-pdf:3.1.0`, about 1.1 GB, with OCR and office-document conversion. The `3.1.0-ultra-lite` tag is about 360 MB and leaves those out; change the image line if that is all you need.

It keeps settings in the volume `stirling-pdf-config`, OCR languages in `stirling-pdf-tessdata`, and logs in `stirling-pdf-logs`. Documents you process are not stored. Minimum recommended for the place `stirling-pdf`: 2 GB of memory and 2.5 GB of disk, on an arm64 or amd64 machine, with no GPU.

To use it in a card, copy the `stirling-pdf` service and its three volumes into the card's Compose file, and `STIRLING_PDF_PORT` into its `card.env`. The Compose file is [docker-compose.yml](docker-compose.yml), the settings [card.env](card.env), the card [card.yml](card.yml), and the last test [test.yml](test.yml).

## How

Five steps. Edit [card.env](card.env) before you start.

### 1. Fetch

```bash
mkdir -p stirling-pdf
curl -fsSL https://github.com/edgible-org/cards/archive/refs/heads/main.tar.gz \
  | tar -xz --strip-components=2 -C stirling-pdf cards-main/stirling-pdf
```

### 2. Edit card.env

Set `DEVICE` to a name `edgible device list` prints.

```bash
nano stirling-pdf/card.env
```

### 3. Check

```bash
curl -fsSLo check-env.py https://raw.githubusercontent.com/edgible-org/card-kit/main/check-env.py
python3 check-env.py stirling-pdf
```

Fix what it reports, and run it again until it says `no conflicts`.

### 4. Start

```bash
docker compose --env-file stirling-pdf/card.env -f stirling-pdf/docker-compose.yml pull
docker compose --env-file stirling-pdf/card.env -f stirling-pdf/docker-compose.yml up -d --wait
docker compose --env-file stirling-pdf/card.env -f stirling-pdf/docker-compose.yml ps
```

The first start downloads the app's images from the registries named in the Compose file: about 1.1 GB, a few minutes on a typical home connection. `pull` does that download on its own, so you can see it. The time is the download, not Edgible, and it happens once: later starts and upgrades reuse the images on the machine and fetch only what changed. `--wait` returns when the service is healthy, and `ps` shows `(healthy)`.

### 5. Publish

```bash
set -euo pipefail
set -a
. stirling-pdf/card.env
set +a
device_id=$(edgible device list --json | jq -er --arg name "$DEVICE" '
  map(select(.name == $name))
  | if length == 1 then .[0].id
    else error("need exactly one device named " + $name + " (" + (map(.status + " " + .id) | join(", ")) + ")")
    end
')
edgible app create existing \
  --non-interactive \
  --name stirling-pdf \
  --port "$STIRLING_PDF_PORT" \
  --protocol https \
  --auth-modes org \
  --device-id "$device_id"
edgible app list
```

## Verify

`stirling-pdf` uses `org`.

```bash
curl -sS -o /dev/null -w '%{http_code} %{redirect_url}\n' "https://<stirling-pdf hostname>"
```

That prints `302` and an `edgible.com/application-access/` address, so the org sign-in is in front. Open the hostname in a browser and sign in. Stirling-PDF opens with no second login. The rest of the setup is in the [Stirling-PDF docs](https://docs.stirlingpdf.com).

## Tear down

Four steps, in this order. Step 1 runs wherever `edgible` is logged in. Steps 2 to 4 run on the machine that runs the container. Steps 2 and 3 read `card.env`, so keep it until step 4.

### 1. Unpublish

```bash
edgible app delete stirling-pdf --yes
```

### 2. Stop

```bash
docker compose --env-file stirling-pdf/card.env -f stirling-pdf/docker-compose.yml down
```

### 3. Delete the data

Skip this step to keep the settings. The loop copies each volume to a `.tgz` file in this directory first.

```bash
for volume in $(docker volume ls -q --filter label=com.docker.compose.project=stirling-pdf); do
  docker run --rm -v "$volume:/data:ro" -v "$PWD:/backup" alpine tar -czf "/backup/$volume.tgz" -C /data .
done
docker compose --env-file stirling-pdf/card.env -f stirling-pdf/docker-compose.yml down --volumes
```

### 4. Remove the card

```bash
rm -rf stirling-pdf
```
