---
app: ech0
project: https://github.com/lin-snow/Ech0
status: draft
found: 2026-10-27
sent:
---

# Add a `HEALTHCHECK` to the image

**Request.** A `HEALTHCHECK` in `docker/Dockerfile`, for example on `/api/hello`, which the server
already answers.

**Why.** Without one, `docker ps` shows the container as running as soon as the process starts,
and anything that waits for "healthy" (`docker compose up --wait`, an orchestrator, a monitor) has
no signal until each user writes a check of their own. The final image is Alpine, so BusyBox
`wget` is available and no extra package is needed, for example:

```
HEALTHCHECK --interval=10s --timeout=5s --start-period=10s --retries=6 \
  CMD wget -qO /dev/null http://127.0.0.1:6277/api/hello || exit 1
```

**What we do now.** The [ech0 card](https://github.com/edgible-org/cards/tree/main/ech0) declares
the same check in its Compose file, and its regression waits on it.

**Checked.** Ech0 v5.8.0; `docker/Dockerfile` and `docker/build.Dockerfile` on `main` at `f2da207`
have no `HEALTHCHECK`.
