# Run a card without Edgible

A card is a Docker Compose file, pinned images, and a `card.env` you edit. Edgible is the easiest way to put one on the internet, but it is not required to run one. This page says how to run a card on your own server, and what you take on yourself when you do.

## How

1. **A machine with Docker and Compose** (`docker compose version`). Any Linux server, a mini PC or a Mac will do.
2. **Fetch the card.** Clone this repo, or copy the card's folder, and read its README's Why and What.
3. **Edit `card.env`.** Set the host port each app listens on, and the address people will use: the card's `<APP>_URL` (such as `GITEA_URL=https://git.example.org`). With the address set you can leave `ORG_LABEL` empty. Secrets are made on the machine at first start; you do not write them. The README says which other lines to fill in.
4. **Start it:** `docker compose --env-file card.env -f docker-compose.yml up -d --wait`, as the card's README says. Each app listens on `127.0.0.1:<port>`, so nothing is reachable from outside yet.
5. **Put a reverse proxy in front** (Caddy, Traefik or nginx) that terminates HTTPS for your domain and forwards to that port. Point your domain's DNS at the machine, and open ports 80 and 443 on it, or use a tunnel you already trust. The README's Verify section lists the hostnames the card expects, and which ones must stay open (an app's phone client, a webhook).
6. **Check it.** Run the card's Verify steps against your address. `check-env` still checks ports and sizing on the machine; it skips the Edgible device and app checks when there is no `edgible` CLI.

Some cards also publish a non-HTTP service, such as SSH for Gitea or a game port. You forward those yourself, and the card's address setting for them (`GITEA_SSH_DOMAIN`) tells the app what to advertise.

## What Edgible does for you, and what you do instead

| | With Edgible | Without it |
| --- | --- | --- |
| Reaching the app from outside | A hostname and certificate for each app. The device connects out, so you open nothing on your router | A domain, DNS records, a reverse proxy, certificate renewal, and ports opened or a tunnel |
| Who may open a hostname | An auth mode per hostname: `org` puts your Edgible sign-in in front, `none` leaves it to the app | Your own sign-in in front of each `org` hostname (an auth proxy or single sign-on), and the app's own login for the rest |
| Several machines | Apps on different devices under one organisation, and a card's places assigned to devices | You run the card where you choose and wire the machines together yourself |
| Seeing and moving what runs | One list of your apps, and tools that move an app to another machine | `docker compose ls` on each machine, and your own copy of the data |
| Confidence in the card | The same lifecycle test every card passes on a real Edgible device | You test it yourself; the card's Verify and Tear down steps still apply |

## What stays the same

- The images and versions are the card's pins, and the nightly image scan applies to them.
- Secrets are made on your machine and never leave it.
- `data:` in `card.yml` says what each volume holds, so you can back it up with your usual tool.

## What we do not promise

The test badges in the README are measured on Edgible devices. A card that passes there has not been tested behind your proxy. If you hit something that is specific to running without Edgible, tell us in an issue: it is the best way to make this page better.
