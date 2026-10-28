---
app: miniflux
project: https://github.com/miniflux/v2
cards: [miniflux]
status: draft
found: 2026-10-28
sent:
---

# Add a `HEALTHCHECK` to the Docker images

**Request.** A `HEALTHCHECK` in `packaging/docker/alpine/Dockerfile` and `distroless/Dockerfile`
that runs the binary's own check:

```
HEALTHCHECK --interval=10s --timeout=5s --start-period=10s --retries=6 \
  CMD ["/usr/bin/miniflux", "-healthcheck", "auto"]
```

**Why.** Miniflux already has the check (`-healthcheck`, where `auto` guesses the endpoint), and
the image does not use it. Without a `HEALTHCHECK`, `docker ps` shows the container as running as
soon as the process starts, and anything that waits for "healthy" (`docker compose up --wait`, an
orchestrator, a monitor) has no signal until each user writes the check. The binary is the only
thing in the distroless image, so a user cannot add `curl` there.

**What we do now.** The [miniflux card](https://github.com/edgible-org/cards/tree/main/miniflux)
declares a check in its Compose file, and its regression waits on it.

**Checked.** Miniflux 2.3.3 (image `miniflux/miniflux:2.3.3`, which has no healthcheck by
`docker inspect`); the Dockerfiles on `main` at `d5c529b` have no `HEALTHCHECK`.
