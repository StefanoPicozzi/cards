# cards

Edgible cards let a self-hosted setup be shared and reproduced. A card records the programs, the images, the ports, the auth mode on each hostname, and which apps share a serving device. Someone else fetches that card, edits `card.env`, starts the containers, and publishes the apps. The card leaves out device names, hostnames, and the organization id, so the next person maps each place to a serving device they have.

Browse the cards, and the needs they answer, on the catalog site: [cards.edgible.org](https://cards.edgible.org). It is rebuilt from this repo after every change and every regression.

[![The catalog site: search the cards by app, need, or the service you are leaving, and filter by category](.github/catalog.png)](https://cards.edgible.org)

If a card helps you, **star this repo**: it is how other people find the cards, and how we see which ones matter.

Why cards exist, and what they promise, is in [ABOUT.md](ABOUT.md). How the whole system works, including every automated job and where its results go, is in [HOW-IT-WORKS.md](HOW-IT-WORKS.md). Each morning's summary of those jobs, and anything that needs a person, is in the pinned [Daily report](https://github.com/edgible-org/cards/issues?q=is%3Aissue+label%3Areport) issue.

Each top-level directory with a `card.yml` in it is one card, and its README is how to run it. There are two types:

- **App cards** run one self-hosted app, such as Gitea or Umami, ready on its own or as a building block. Every app card is tested end to end on a real Edgible serving device, and tested again when it changes and when Edgible releases a new version.
- **Pattern cards** wire several apps together for a purpose, sometimes across several machines, such as a Git server with a CI runner. A pattern is built from app cards.

App cards used to live in Edgible/starters, as starters. That repo is archived, and everything is here now.

## App cards

| Card | What | Status |
| --- | --- | --- |
| [gitea](gitea) | Gitea, your own Git forge, with Git over HTTPS and SSH | [![gitea status](https://img.shields.io/endpoint?url=https%3A%2F%2Fraw.githubusercontent.com%2Fedgible-org%2Fcards%2Ftest-status%2Fgitea.json)](https://github.com/edgible-org/cards/blob/test-status/status.json) |
| [immich](immich) | Immich, your photo and video library, for its phone apps and the web | [![immich status](https://img.shields.io/endpoint?url=https%3A%2F%2Fraw.githubusercontent.com%2Fedgible-org%2Fcards%2Ftest-status%2Fimmich.json)](https://github.com/edgible-org/cards/blob/test-status/status.json) |
| [jellyfin](jellyfin) | Jellyfin, your films, shows and music, streamed to its apps and the web | [![jellyfin status](https://img.shields.io/endpoint?url=https%3A%2F%2Fraw.githubusercontent.com%2Fedgible-org%2Fcards%2Ftest-status%2Fjellyfin.json)](https://github.com/edgible-org/cards/blob/test-status/status.json) |
| [linkding](linkding) | linkding, a minimal bookmark manager, for your browsers and its extension | [![linkding status](https://img.shields.io/endpoint?url=https%3A%2F%2Fraw.githubusercontent.com%2Fedgible-org%2Fcards%2Ftest-status%2Flinkding.json)](https://github.com/edgible-org/cards/blob/test-status/status.json) |
| [mcp-bridge](mcp-bridge) | Any stdio MCP server, published over Streamable HTTP for your AI assistants | [![mcp-bridge status](https://img.shields.io/endpoint?url=https%3A%2F%2Fraw.githubusercontent.com%2Fedgible-org%2Fcards%2Ftest-status%2Fmcp-bridge.json)](https://github.com/edgible-org/cards/blob/test-status/status.json) |
| [mcp-signin](mcp-signin) | Sign in with Edgible in front of any MCP server, so Claude on the web and phone can use it | [![mcp-signin status](https://img.shields.io/endpoint?url=https%3A%2F%2Fraw.githubusercontent.com%2Fedgible-org%2Fcards%2Ftest-status%2Fmcp-signin.json)](https://github.com/edgible-org/cards/blob/test-status/status.json) |
| [minecraft](minecraft) | A Minecraft server for friends on PC over TCP and on phones over UDP, one world | [![minecraft status](https://img.shields.io/endpoint?url=https%3A%2F%2Fraw.githubusercontent.com%2Fedgible-org%2Fcards%2Ftest-status%2Fminecraft.json)](https://github.com/edgible-org/cards/blob/test-status/status.json) |
| [miniflux](miniflux) | Miniflux, the minimalist feed reader, behind your org login | [![miniflux status](https://img.shields.io/endpoint?url=https%3A%2F%2Fraw.githubusercontent.com%2Fedgible-org%2Fcards%2Ftest-status%2Fminiflux.json)](https://github.com/edgible-org/cards/blob/test-status/status.json) |
| [ollama-mac](ollama-mac) | Ollama on an Apple Silicon Mac, natively on its GPU, as an API behind a key | [![ollama-mac status](https://img.shields.io/endpoint?url=https%3A%2F%2Fraw.githubusercontent.com%2Fedgible-org%2Fcards%2Ftest-status%2Follama-mac.json)](https://github.com/edgible-org/cards/blob/test-status/status.json) |
| [openclaw](openclaw) | OpenClaw, the open-source AI agent, with its Control UI behind your organisation's sign-in | [![openclaw status](https://img.shields.io/endpoint?url=https%3A%2F%2Fraw.githubusercontent.com%2Fedgible-org%2Fcards%2Ftest-status%2Fopenclaw.json)](https://github.com/edgible-org/cards/blob/test-status/status.json) |
| [owncloud](owncloud) | ownCloud Infinite Scale, your files and shares, for its desktop and phone apps and the web | [![owncloud status](https://img.shields.io/endpoint?url=https%3A%2F%2Fraw.githubusercontent.com%2Fedgible-org%2Fcards%2Ftest-status%2Fowncloud.json)](https://github.com/edgible-org/cards/blob/test-status/status.json) |
| [static-site](static-site) | A static website from a tarball URL, served by Caddy and kept up to date | [![static-site status](https://img.shields.io/endpoint?url=https%3A%2F%2Fraw.githubusercontent.com%2Fedgible-org%2Fcards%2Ftest-status%2Fstatic-site.json)](https://github.com/edgible-org/cards/blob/test-status/status.json) |
| [stirling-pdf](stirling-pdf) | Stirling-PDF, the PDF toolbox, behind your org login | [![stirling-pdf status](https://img.shields.io/endpoint?url=https%3A%2F%2Fraw.githubusercontent.com%2Fedgible-org%2Fcards%2Ftest-status%2Fstirling-pdf.json)](https://github.com/edgible-org/cards/blob/test-status/status.json) |
| [umami](umami) | Umami analytics, the dashboard behind org and the tracking script open | [![umami status](https://img.shields.io/endpoint?url=https%3A%2F%2Fraw.githubusercontent.com%2Fedgible-org%2Fcards%2Ftest-status%2Fumami.json)](https://github.com/edgible-org/cards/blob/test-status/status.json) |
| [uptime-kuma](uptime-kuma) | Uptime Kuma, the uptime monitor, behind your org login | [![uptime-kuma status](https://img.shields.io/endpoint?url=https%3A%2F%2Fraw.githubusercontent.com%2Fedgible-org%2Fcards%2Ftest-status%2Fuptime-kuma.json)](https://github.com/edgible-org/cards/blob/test-status/status.json) |
| [vaultwarden](vaultwarden) | Vaultwarden, a Bitwarden-compatible password server, for your own apps and browsers | [![vaultwarden status](https://img.shields.io/endpoint?url=https%3A%2F%2Fraw.githubusercontent.com%2Fedgible-org%2Fcards%2Ftest-status%2Fvaultwarden.json)](https://github.com/edgible-org/cards/blob/test-status/status.json) |
| [wordpress](wordpress) | WordPress with MariaDB, installed before it goes public | [![wordpress status](https://img.shields.io/endpoint?url=https%3A%2F%2Fraw.githubusercontent.com%2Fedgible-org%2Fcards%2Ftest-status%2Fwordpress.json)](https://github.com/edgible-org/cards/blob/test-status/status.json) |

## Pattern cards

| Card | What | Status |
| --- | --- | --- |
| [accounts](accounts) | Sign-up and sign-in for your visitors, and the console that manages them | not tested yet |
| [assistant](assistant) | Chat that answers from your own documents, and the model that runs it | not tested yet |
| [ci](ci) | Your own Git forge with CI, and the runner on a machine of its own | [![ci status](https://img.shields.io/endpoint?url=https%3A%2F%2Fraw.githubusercontent.com%2Fedgible-org%2Fcards%2Ftest-status%2Fci.json)](https://github.com/edgible-org/cards/blob/test-status/status.json) |
| [edgible-agent](edgible-agent) | Your own AI agent that looks after your Edgible apps, from your phone | [![edgible-agent status](https://img.shields.io/endpoint?url=https%3A%2F%2Fraw.githubusercontent.com%2Fedgible-org%2Fcards%2Ftest-status%2Fedgible-agent.json)](https://github.com/edgible-org/cards/blob/test-status/status.json) |
| [edgible-connector](edgible-connector) | Edgible in Claude's web, desktop and phone apps, signed in with Edgible | [![edgible-connector status](https://img.shields.io/endpoint?url=https%3A%2F%2Fraw.githubusercontent.com%2Fedgible-org%2Fcards%2Ftest-status%2Fedgible-connector.json)](https://github.com/edgible-org/cards/blob/test-status/status.json) |
| [litellm](litellm) | Metered model API and its admin, one LiteLLM process | not tested yet |
| [n8n](n8n) | Locked editor and open webhook hostname, one n8n process | not tested yet |
| [website](website) | Public React site, its editor, open tracker, locked dashboard, locked monitor | not tested yet |

The status is the latest lifecycle test of each card, on a real Edgible serving device, and the Edgible version it ran on. A green badge with the current version means it works today. A pattern with no test yet has been run by its author, but not by the regression.

## What a card is

The format, its conventions, and the tools that check and test a card are in [edgible-org/card-kit](https://github.com/edgible-org/card-kit#what-a-card-is). `metadata.type` in `card.yml` says which type a card is. An app card also follows these rules, and `check-cards` checks them:

- **One app.** The app may sit on more than one hostname, such as Umami's dashboard and its tracking script, and it brings its own database or cache. It does not bring a second app.
- **Names that say whose they are.** Every variable, service, and volume is prefixed with the app: `GITEA_DB_PASSWORD`, a service `gitea-db`, a volume `gitea-db-data`. No `container_name`. Two app cards then drop into one Compose file without a clash.
- **Pinned images.** Each image is the exact version that passed `test.yml`. A newer version replaces it only once it passes too.
- **`test.yml`, always, with `result: pass`.** It is committed only when the result, a step, or the images change ([the rule](https://github.com/edgible-org/card-kit#test-results)).
- **A short README.** Why is what the app is, with a link to its docs. What is its services, its hostnames, and what it needs to be combined into a pattern. How, Verify, and Tear down are as in any card.

A pattern card says in its README which app cards it was built from.

## Choosing the auth mode

The auth mode belongs to each hostname, and the right one depends on who calls it.

| Caller | Auth mode |
| --- | --- |
| A person in a browser, for an admin or personal interface | `org` |
| An app's own phone app, desktop client, or browser extension, which cannot get past an Edgible sign-in | `none`, with the app's own login as the protection, and the card says so |
| Another machine calling an API | `api-key` |
| The public, such as a site, a tracking script, or a webhook | `none` |
| A game, SSH, or another `tcp` or `udp` service | `none`, the only mode those take; the app's own checks decide who gets in |

`org` is not automatically the safe choice. A card on `org` that its own phone app cannot reach does not work, and the README is where the trade-off is written down.

## What is not an app card

Some apps should not be put on a public hostname at all, however popular they are. The agent skips them and says why:

- Services that would serve anyone and can be abused: an open DNS resolver such as Pi-hole, an open mail relay, an open proxy.
- Apps with no maintained container image.
- Apps whose project is archived.

## Reviewing a card

A person reviews every card before it is merged. The agent cannot judge these, so the pull request lists them:

- [ ] Default passwords are changed or generated, and the README says how to sign in the first time.
- [ ] Every secret is empty in git, with a `# Generate with:` comment.
- [ ] The auth mode of each hostname suits its callers, by the table above.
- [ ] The README says where the data lives, and Tear down backs it up before deleting it.
- [ ] `test.yml` passes, and its images are the ones in the Compose files. An app card must have one.
- [ ] Nothing names a device, a hostname, or an organization.

## Using app cards in a pattern

Copy the services of each app card into your pattern's Compose file, and their lines into its `card.env`. The prefixes keep them apart. Then add what only you know: how the apps reach each other, which place each runs in, and the story in Why. Say in the README which app cards it was built from.

## Tools and tests

The format and the tools are in [edgible-org/card-kit](https://github.com/edgible-org/card-kit). Every pull request runs `check-cards --fresh`, which fails a card whose files changed since its `test.yml`: run `test-card` and commit the new one. The lifecycle tests run with `test-cards` on an Edgible serving device, from `main` only, never from a pull request. They test every card that carries `test.yml`, write the status to the [`test-status` branch](https://github.com/edgible-org/cards/tree/test-status), and never commit to `main`; a failing card gets an issue.

## Contributing

How to add a card, fix one, or ask for one is in [CONTRIBUTING.md](CONTRIBUTING.md).

## License

Everything in this repo is under the [MIT License](LICENSE). A card you contribute is shared under the same license. The apps a card runs keep their own licenses.
