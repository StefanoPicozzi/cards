---
app: ollama
project: https://github.com/ollama/ollama
status: draft
found: 2026-10-27
sent:
---

# A setting for extra allowed `Host` names

**Request.** A setting, for example `OLLAMA_ALLOWED_HOSTS`, listing host names that may reach a
server bound to a loopback address, beside the built-in `localhost`, `*.local`, `*.internal`,
`*.localhost` and the machine's own name.

**Why.** When Ollama listens on a loopback address, `allowedHostsMiddleware` in `server/routes.go`
answers `403` to any request whose `Host` is not one of those. That is a sensible guard against
DNS rebinding. It also means a reverse proxy or tunnel that forwards the public host name gets
`403` on every call, and `OLLAMA_ORIGINS` does not help, since that only controls CORS. The ways
round it today are to listen on every address, which exposes the API to the whole network, or to
rewrite `Host` in a proxy in front. A setting would let someone who has put authentication in front
name their host and keep Ollama on loopback.

**What we do now.** The [ollama-osx card](https://github.com/edgible-org/cards/tree/main/ollama-osx)
keeps Ollama on 127.0.0.1 and runs a small Caddy proxy in front that sets `Host` to `localhost` and
passes on only the routes a client needs.

**Checked.** Ollama 0.40.4 (the card's pin); source read on `main` at `8ec9ecd`. No open or closed
issue found asking for this when searched on 2026-10-27. If one exists, comment there instead.
